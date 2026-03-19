# ==============================================================================
# INTEGRATION TESTS: HIERARCHICAL BAYES ESTIMATION PIPELINE
# ==============================================================================
#
# Tests the HB estimation path (bayesm-based) including:
#   - Data preparation for bayesm
#   - HB estimation via estimate_choice_model(method = "hb")
#   - Individual betas matrix dimensions
#   - Convergence diagnostics structure
#   - RLH computation and quality
#   - Choice-set validation catches bad data
#
# IMPORTANT: All tests skip_if_not_installed("bayesm") since HB is optional.
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

  # Load synthetic data generators
  fixture_path <- file.path(
    turas_root, "modules", "conjoint", "tests",
    "fixtures", "synthetic_data", "generate_conjoint_test_data.R"
  )
  if (file.exists(fixture_path)) source(fixture_path, local = TRUE)

  # ============================================================================
  # TEST 1: prepare_bayesm_data produces valid structure
  # ============================================================================
  test_that("HB: prepare_bayesm_data returns correct structure", {
    skip_if_not_installed("bayesm")

    synth <- generate_synthetic_cbc(
      n_respondents = 20, n_tasks = 6, n_alts = 3, seed = 42
    )

    # Simulate what load_conjoint_data returns
    data_list <- list(
      data = synth$data,
      n_respondents = synth$n_respondents,
      n_choice_sets = synth$n_respondents * synth$n_tasks,
      has_none = FALSE,
      none_info = NULL,
      validation = list(warnings = character(0), info = character(0))
    )

    bayesm_data <- prepare_bayesm_data(data_list, synth$config, verbose = FALSE)

    # Structure checks
    expect_true(is.list(bayesm_data))
    expect_true("lgtdata" %in% names(bayesm_data))
    expect_true("p" %in% names(bayesm_data))
    expect_true("n_parameters" %in% names(bayesm_data))
    expect_true("attribute_map" %in% names(bayesm_data))
    expect_true("respondent_ids" %in% names(bayesm_data))

    # Number of respondents
    expect_equal(length(bayesm_data$lgtdata), 20)

    # Alternatives per choice set
    expect_equal(bayesm_data$p, 3)

    # Each respondent element should have y and X
    resp1 <- bayesm_data$lgtdata[[1]]
    expect_true("y" %in% names(resp1))
    expect_true("X" %in% names(resp1))
    expect_equal(length(resp1$y), 6)  # n_tasks
    expect_equal(nrow(resp1$X), 6 * 3)  # n_tasks * n_alts

    # y values should be 1-indexed integers within [1, n_alts]
    expect_true(all(resp1$y >= 1 & resp1$y <= 3))
  })

  # ============================================================================
  # TEST 2: Full HB estimation produces individual betas
  # ============================================================================
  test_that("HB: estimate_choice_model with method='hb' returns individual_betas", {
    skip_if_not_installed("bayesm")

    # Use small sample and few iterations for speed
    synth <- generate_synthetic_cbc(
      n_respondents = 15, n_tasks = 6, n_alts = 3, seed = 99
    )

    data_list <- list(
      data = synth$data,
      n_respondents = synth$n_respondents,
      n_choice_sets = synth$n_respondents * synth$n_tasks,
      has_none = FALSE,
      none_info = NULL,
      validation = list(warnings = character(0), info = character(0))
    )

    # Override config for minimal HB run
    config <- synth$config
    config$estimation_method <- "hb"
    config$hb_iterations <- 200
    config$hb_burnin <- 50
    config$hb_thin <- 1
    config$hb_ncomp <- 1

    result <- estimate_choice_model(data_list, config, verbose = FALSE)

    # Method should be HB
    expect_equal(result$method, "hierarchical_bayes")

    # individual_betas: matrix with n_respondents rows, n_parameters cols
    expect_true(!is.null(result$individual_betas))
    expect_true(is.matrix(result$individual_betas))
    expect_equal(nrow(result$individual_betas), 15)  # n_respondents
    expect_equal(ncol(result$individual_betas), result$n_parameters)

    # Column names should be present
    expect_true(!is.null(colnames(result$individual_betas)))

    # Aggregate coefficients should also be present
    expect_true(length(result$coefficients) > 0)
    expect_true(is.numeric(result$coefficients))
  })

  # ============================================================================
  # TEST 3: Convergence diagnostics structure
  # ============================================================================
  test_that("HB: convergence diagnostics have expected fields", {
    skip_if_not_installed("bayesm")

    synth <- generate_synthetic_cbc(
      n_respondents = 15, n_tasks = 6, n_alts = 3, seed = 42
    )

    data_list <- list(
      data = synth$data,
      n_respondents = synth$n_respondents,
      n_choice_sets = synth$n_respondents * synth$n_tasks,
      has_none = FALSE,
      none_info = NULL,
      validation = list(warnings = character(0), info = character(0))
    )

    config <- synth$config
    config$estimation_method <- "hb"
    config$hb_iterations <- 200
    config$hb_burnin <- 50
    config$hb_thin <- 1
    config$hb_ncomp <- 1

    result <- estimate_choice_model(data_list, config, verbose = FALSE)

    conv <- result$convergence

    expect_true(is.list(conv))
    expect_true("converged" %in% names(conv))
    expect_true(is.logical(conv$converged))
  })

  # ============================================================================
  # TEST 4: RLH is computed and above chance
  # ============================================================================
  test_that("HB: respondent RLH is computed and above chance level", {
    skip_if_not_installed("bayesm")

    synth <- generate_synthetic_cbc(
      n_respondents = 20, n_tasks = 8, n_alts = 3, seed = 42
    )

    data_list <- list(
      data = synth$data,
      n_respondents = synth$n_respondents,
      n_choice_sets = synth$n_respondents * synth$n_tasks,
      has_none = FALSE,
      none_info = NULL,
      validation = list(warnings = character(0), info = character(0))
    )

    config <- synth$config
    config$estimation_method <- "hb"
    config$hb_iterations <- 300
    config$hb_burnin <- 100
    config$hb_thin <- 1
    config$hb_ncomp <- 1

    result <- estimate_choice_model(data_list, config, verbose = FALSE)

    # Respondent quality should be present
    expect_true(!is.null(result$respondent_quality))

    quality <- result$respondent_quality

    # Should have RLH values
    if ("rlh" %in% names(quality)) {
      rlh_values <- quality$rlh

      expect_true(is.numeric(rlh_values))
      expect_equal(length(rlh_values), 20)

      # Chance level for 3 alternatives = 1/3 ~ 0.333
      chance_level <- 1 / 3

      # Average RLH should be above chance (data generated from known utilities)
      mean_rlh <- mean(rlh_values, na.rm = TRUE)
      expect_gt(mean_rlh, chance_level,
                label = sprintf("Mean RLH (%.3f) should exceed chance (%.3f)",
                                mean_rlh, chance_level))
    }
  })

  # ============================================================================
  # TEST 5: HB settings are preserved in result
  # ============================================================================
  test_that("HB: hb_settings field records MCMC parameters", {
    skip_if_not_installed("bayesm")

    synth <- generate_synthetic_cbc(
      n_respondents = 10, n_tasks = 4, n_alts = 3, seed = 7
    )

    data_list <- list(
      data = synth$data,
      n_respondents = synth$n_respondents,
      n_choice_sets = synth$n_respondents * synth$n_tasks,
      has_none = FALSE,
      none_info = NULL,
      validation = list(warnings = character(0), info = character(0))
    )

    config <- synth$config
    config$estimation_method <- "hb"
    config$hb_iterations <- 150
    config$hb_burnin <- 30
    config$hb_thin <- 1
    config$hb_ncomp <- 1

    result <- estimate_choice_model(data_list, config, verbose = FALSE)

    expect_true(!is.null(result$hb_settings))
    expect_equal(result$hb_settings$iterations, 150)
    expect_equal(result$hb_settings$burnin, 30)
    expect_equal(result$hb_settings$thin, 1)
    expect_equal(result$hb_settings$ncomp, 1)
  })

  # ============================================================================
  # TEST 6: Choice-set validation catches inconsistent alternatives
  # ============================================================================
  test_that("HB: prepare_bayesm_data catches inconsistent choice set sizes", {
    skip_if_not_installed("bayesm")

    synth <- generate_synthetic_cbc(
      n_respondents = 10, n_tasks = 4, n_alts = 3, seed = 42
    )

    # Corrupt the data: remove one row from a choice set
    bad_data <- synth$data
    # Find a task_id and remove one alternative
    first_task <- bad_data$task_id[1]
    rows_in_first_task <- which(bad_data$task_id == first_task)
    bad_data <- bad_data[-rows_in_first_task[1], ]

    data_list <- list(
      data = bad_data,
      n_respondents = synth$n_respondents,
      n_choice_sets = synth$n_respondents * synth$n_tasks,
      has_none = FALSE,
      none_info = NULL,
      validation = list(warnings = character(0), info = character(0))
    )

    # Should raise an error about inconsistent alternatives
    expect_error(
      prepare_bayesm_data(data_list, synth$config, verbose = FALSE),
      regexp = NULL  # any error is acceptable
    )
  })

  # ============================================================================
  # TEST 7: attribute_map links columns to attribute-level pairs
  # ============================================================================
  test_that("HB: attribute_map correctly maps columns to attribute-level pairs", {
    skip_if_not_installed("bayesm")

    synth <- generate_synthetic_cbc(
      n_respondents = 10, n_tasks = 4, n_alts = 3, seed = 42
    )

    data_list <- list(
      data = synth$data,
      n_respondents = synth$n_respondents,
      n_choice_sets = synth$n_respondents * synth$n_tasks,
      has_none = FALSE,
      none_info = NULL,
      validation = list(warnings = character(0), info = character(0))
    )

    bayesm_data <- prepare_bayesm_data(data_list, synth$config, verbose = FALSE)

    am <- bayesm_data$attribute_map

    expect_true(is.list(am))
    expect_gt(length(am), 0)

    # Each entry should have attribute and level
    for (entry in am) {
      expect_true("attribute" %in% names(entry))
      expect_true("level" %in% names(entry))
      expect_true(entry$attribute %in% synth$config$attributes$AttributeName)
    }
  })

} # end turas_root guard
