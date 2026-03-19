# ==============================================================================
# TESTS: GUARD LAYER FUNCTIONS (00_guard.R)
# ==============================================================================
#
# Tests the TRS guard layer for the conjoint module including:
#   - conjoint_status_refuse returns correct structure
#   - guard_check_data_exists with NULL and empty data
#   - validate_conjoint_convergence with converged and non-converged results
#   - conjoint_guard_init and guard state management
#   - conjoint_status_pass and conjoint_status_partial
#
# ==============================================================================

# --- Locate project root and source module ----------------------------------
.find_turas_root <- function() {
  candidates <- c(
    getwd(),
    Sys.getenv("TURAS_ROOT", unset = ""),
    tryCatch(file.path(dirname(dirname(testthat::test_path())), "..", ".."),
             error = function(e) "")
  )
  for (cand in candidates) {
    if (nzchar(cand) && file.exists(file.path(cand, "modules", "conjoint", "R", "00_main.R"))) {
      return(normalizePath(cand))
    }
  }
  NULL
}

turas_root <- .find_turas_root()

if (is.null(turas_root)) {
  test_that("project root found (skip guard)", {
    skip("Cannot locate Turas project root")
  })
} else {

  old_wd <- setwd(turas_root)
  on.exit(setwd(old_wd), add = TRUE)

  source(file.path(turas_root, "modules", "conjoint", "R", "00_main.R"))

  # ============================================================================
  # TEST 1: conjoint_status_refuse returns correct TRS structure
  # ============================================================================
  test_that("conjoint_status_refuse: returns REFUSED status with code and message", {
    skip_if(!exists("conjoint_status_refuse", mode = "function"),
            "conjoint_status_refuse not loaded")

    result <- conjoint_status_refuse(
      code = "DATA_INVALID",
      reason = "Test refusal reason"
    )

    expect_true(is.list(result))
    expect_equal(result$status, "REFUSED")
    expect_equal(result$module, "CONJOINT")
    expect_equal(result$code, "DATA_INVALID")
    expect_true("message" %in% names(result))
    expect_true("how_to_fix" %in% names(result))
  })

  # ============================================================================
  # TEST 2: conjoint_status_refuse with default reason
  # ============================================================================
  test_that("conjoint_status_refuse: uses default message when reason is NULL", {
    skip_if(!exists("conjoint_status_refuse", mode = "function"),
            "conjoint_status_refuse not loaded")

    result <- conjoint_status_refuse(code = "TEST_CODE")

    expect_equal(result$status, "REFUSED")
    expect_true(nchar(result$message) > 0,
                info = "Default message should be non-empty")
  })

  # ============================================================================
  # TEST 3: guard_check_data_exists refuses NULL data
  # ============================================================================
  test_that("guard_check_data_exists: refuses NULL data", {
    skip_if(!exists("guard_check_data_exists", mode = "function"),
            "guard_check_data_exists not loaded")

    # conjoint_refuse calls stop(), so expect_error should catch it
    expect_error(
      guard_check_data_exists(NULL),
      regexp = "DATA_INSUFFICIENT_CHOICES|Insufficient|choice"
    )
  })

  # ============================================================================
  # TEST 4: guard_check_data_exists refuses empty data frame
  # ============================================================================
  test_that("guard_check_data_exists: refuses empty data frame", {
    skip_if(!exists("guard_check_data_exists", mode = "function"),
            "guard_check_data_exists not loaded")

    empty_df <- data.frame()

    expect_error(
      guard_check_data_exists(empty_df),
      regexp = "DATA_INSUFFICIENT_CHOICES|Insufficient|choice"
    )
  })

  # ============================================================================
  # TEST 5: guard_check_data_exists passes with valid data
  # ============================================================================
  test_that("guard_check_data_exists: passes with non-empty data", {
    skip_if(!exists("guard_check_data_exists", mode = "function"),
            "guard_check_data_exists not loaded")

    valid_df <- data.frame(x = 1:10, y = rnorm(10))

    # Should not raise an error
    result <- guard_check_data_exists(valid_df)
    expect_true(result)
  })

  # ============================================================================
  # TEST 6: validate_conjoint_convergence passes with converged model
  # ============================================================================
  test_that("validate_conjoint_convergence: passes with converged model", {
    skip_if(!exists("validate_conjoint_convergence", mode = "function"),
            "validate_conjoint_convergence not loaded")

    converged_model <- list(
      convergence = list(converged = TRUE, code = 0, message = "Success")
    )

    result <- validate_conjoint_convergence(converged_model)
    expect_true(result)
  })

  # ============================================================================
  # TEST 7: validate_conjoint_convergence refuses non-converged model
  # ============================================================================
  test_that("validate_conjoint_convergence: refuses non-converged model", {
    skip_if(!exists("validate_conjoint_convergence", mode = "function"),
            "validate_conjoint_convergence not loaded")

    non_converged_model <- list(
      convergence = list(converged = FALSE, code = 1, message = "Did not converge")
    )

    # conjoint_refuse calls stop(), so this should error
    expect_error(
      validate_conjoint_convergence(non_converged_model),
      regexp = "MODEL_DID_NOT_CONVERGE|converge"
    )
  })

  # ============================================================================
  # TEST 8: validate_conjoint_convergence refuses NULL model
  # ============================================================================
  test_that("validate_conjoint_convergence: refuses NULL model_result", {
    skip_if(!exists("validate_conjoint_convergence", mode = "function"),
            "validate_conjoint_convergence not loaded")

    expect_error(
      validate_conjoint_convergence(NULL),
      regexp = "MODEL_FIT_FAILED|estimation"
    )
  })

  # ============================================================================
  # TEST 9: conjoint_guard_init creates proper guard state
  # ============================================================================
  test_that("conjoint_guard_init: creates guard state with conjoint-specific fields", {
    skip_if(!exists("conjoint_guard_init", mode = "function"),
            "conjoint_guard_init not loaded")

    guard <- conjoint_guard_init()

    expect_true(is.list(guard))
    expect_equal(guard$module, "CONJOINT")

    # Conjoint-specific fields
    expect_true("design_issues" %in% names(guard))
    expect_true("estimation_warnings" %in% names(guard))
    expect_true("convergence_status" %in% names(guard))
    expect_true("attribute_issues" %in% names(guard))
    expect_true("none_option_included" %in% names(guard))

    # Should start clean
    expect_equal(length(guard$design_issues), 0)
    expect_equal(length(guard$estimation_warnings), 0)
    expect_null(guard$convergence_status)
    expect_false(guard$none_option_included)
  })

  # ============================================================================
  # TEST 10: Guard state accumulates warnings correctly
  # ============================================================================
  test_that("guard_record_estimation_warning: accumulates warnings", {
    skip_if(!exists("conjoint_guard_init", mode = "function"),
            "conjoint_guard_init not loaded")
    skip_if(!exists("guard_record_estimation_warning", mode = "function"),
            "guard_record_estimation_warning not loaded")

    guard <- conjoint_guard_init()

    guard <- guard_record_estimation_warning(guard, "Warning 1")
    guard <- guard_record_estimation_warning(guard, "Warning 2")

    expect_equal(length(guard$estimation_warnings), 2)
    expect_equal(guard$estimation_warnings[1], "Warning 1")
    expect_equal(guard$estimation_warnings[2], "Warning 2")
  })

  # ============================================================================
  # TEST 11: Guard convergence recording
  # ============================================================================
  test_that("guard_record_convergence: records convergence status", {
    skip_if(!exists("conjoint_guard_init", mode = "function"),
            "conjoint_guard_init not loaded")
    skip_if(!exists("guard_record_convergence", mode = "function"),
            "guard_record_convergence not loaded")

    guard <- conjoint_guard_init()

    # Record converged
    guard <- guard_record_convergence(guard, converged = TRUE, iterations = 5000)
    expect_true(guard$convergence_status$converged)
    expect_equal(guard$convergence_status$iterations, 5000)

    # Record non-converged (should flag stability)
    guard2 <- conjoint_guard_init()
    guard2 <- guard_record_convergence(guard2, converged = FALSE, iterations = 10000)
    expect_false(guard2$convergence_status$converged)
    expect_false(guard2$stable, info = "Non-converged should flag stability")
  })

  # ============================================================================
  # TEST 12: conjoint_status_pass returns correct structure
  # ============================================================================
  test_that("conjoint_status_pass: returns PASS status with details", {
    skip_if(!exists("conjoint_status_pass", mode = "function"),
            "conjoint_status_pass not loaded")

    result <- conjoint_status_pass(
      n_attributes = 4,
      n_respondents = 200,
      model_type = "mlogit"
    )

    expect_equal(result$status, "PASS")
    expect_equal(result$module, "CONJOINT")
    expect_true(!is.null(result$details))
    expect_equal(result$details$attributes, 4)
    expect_equal(result$details$respondents, 200)
    expect_equal(result$details$model_type, "mlogit")
  })

  # ============================================================================
  # TEST 13: conjoint_status_partial includes degraded reasons
  # ============================================================================
  test_that("conjoint_status_partial: returns PARTIAL with degradation info", {
    skip_if(!exists("conjoint_status_partial", mode = "function"),
            "conjoint_status_partial not loaded")

    result <- conjoint_status_partial(
      degraded_reasons = c("Low model fit", "Design imbalance"),
      affected_outputs = c("market_simulator", "predictions"),
      estimation_warnings = c("Some respondents had low variation")
    )

    expect_equal(result$status, "PARTIAL")
    expect_equal(result$module, "CONJOINT")
    expect_equal(length(result$degraded_reasons), 2)
    expect_true(!is.null(result$details))
    expect_equal(length(result$details$estimation_warnings), 1)
  })

  # ============================================================================
  # TEST 14: conjoint_determine_status gives PASS for clean guard
  # ============================================================================
  test_that("conjoint_determine_status: PASS for clean guard state", {
    skip_if(!exists("conjoint_determine_status", mode = "function"),
            "conjoint_determine_status not loaded")
    skip_if(!exists("conjoint_guard_init", mode = "function"),
            "conjoint_guard_init not loaded")

    guard <- conjoint_guard_init()
    guard <- guard_record_convergence(guard, converged = TRUE)

    status <- conjoint_determine_status(
      guard,
      n_attributes = 4,
      n_respondents = 100,
      model_type = "mlogit",
      mcfadden_r2 = 0.35
    )

    expect_equal(status$status, "PASS")
  })

  # ============================================================================
  # TEST 15: conjoint_determine_status gives PARTIAL for poor fit
  # ============================================================================
  test_that("conjoint_determine_status: PARTIAL for poor model fit", {
    skip_if(!exists("conjoint_determine_status", mode = "function"),
            "conjoint_determine_status not loaded")
    skip_if(!exists("conjoint_guard_init", mode = "function"),
            "conjoint_guard_init not loaded")

    guard <- conjoint_guard_init()
    guard <- guard_record_convergence(guard, converged = TRUE)

    status <- conjoint_determine_status(
      guard,
      n_attributes = 4,
      n_respondents = 100,
      model_type = "mlogit",
      mcfadden_r2 = 0.05  # Very poor fit
    )

    expect_equal(status$status, "PARTIAL")
    expect_true(any(grepl("Poor model fit", status$degraded_reasons)))
  })

} # end turas_root guard
