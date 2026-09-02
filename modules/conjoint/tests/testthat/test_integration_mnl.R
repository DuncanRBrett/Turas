# ==============================================================================
# INTEGRATION TESTS: END-TO-END MNL PIPELINE
# ==============================================================================
#
# Tests the full conjoint analysis pipeline from config+data to output files.
# Uses the example config and sample data committed under modules/conjoint/examples/.
#
# Coverage:
#   - run_conjoint_analysis() end-to-end
#   - Status = PASS or PARTIAL
#   - Utilities structure (Attribute, Level, Utility, SE)
#   - Importance sums to ~100%
#   - Diagnostics has fit_statistics
#   - Excel output file created
#   - HTML report created (if configured)
#
# ==============================================================================

# --- Locate project root and source module ----------------------------------
.find_turas_root <- function() {

  # Walk up from test file location to find project root.

  # When testthat runs, getwd() is set to the testthat/ directory
  # (e.g., modules/conjoint/tests/testthat), NOT the project root.
  # We must walk up parent directories to find the root marker.

  marker <- file.path("modules", "conjoint", "R", "00_main.R")

  # Strategy 1: Walk up from getwd()
  dir <- normalizePath(getwd(), winslash = "/")
  for (i in 1:8) {
    if (file.exists(file.path(dir, marker))) {
      return(dir)
    }
    parent <- dirname(dir)
    if (parent == dir) break
    dir <- parent
  }

  # Strategy 2: TURAS_ROOT environment variable
  env_root <- Sys.getenv("TURAS_ROOT", unset = "")
  if (nzchar(env_root) && file.exists(file.path(env_root, marker))) {
    return(normalizePath(env_root))
  }

  NULL
}

turas_root <- .find_turas_root()

# Skip entire file if we cannot locate the project
if (is.null(turas_root)) {
  test_that("project root found (skip guard)", {
    skip("Cannot locate Turas project root")
  })
} else {

  # Ensure working directory is project root so module path resolution works
  old_wd <- setwd(turas_root)
  on.exit(setwd(old_wd), add = TRUE)

  # Fix random seed for reproducible MNL estimation
  set.seed(42)

  # Source module (loads all functions into global env)
  source(file.path(turas_root, "modules", "conjoint", "R", "00_main.R"))

  # Paths to the committed example fixture (50 respondents, 8 tasks, 3 alts,
  # 5 attributes). These files are in the repo, so a missing one is a broken
  # checkout, not an environmental skip.
  demo_config <- file.path(turas_root, "modules", "conjoint", "examples", "example_config.xlsx")
  demo_data   <- file.path(turas_root, "modules", "conjoint", "examples", "sample_cbc_data.csv")

  # The shipped example asks for HB (so a fresh user gets every deliverable).
  # These tests are about the MNL path, so they run an MNL copy of it: the
  # same Attributes, estimation_method = auto, no simulator or tabs export.
  make_mnl_config <- function(src) {
    if (!file.exists(src)) return(src)
    settings <- openxlsx::read.xlsx(src, sheet = "Settings", skipEmptyRows = FALSE)
    attrs <- openxlsx::read.xlsx(src, sheet = "Attributes", skipEmptyRows = FALSE)
    settings$Value[settings$Setting == "estimation_method"] <- "auto"
    # The loader validates data_file from the config before any override
    # applies, and the copy lives in a temp dir, so point it at the data.
    settings$Value[settings$Setting == "data_file"] <- demo_data
    settings$Value[settings$Setting == "output_file"] <- tempfile(fileext = ".xlsx")
    drop <- settings$Setting %in% c("generate_html_simulator", "generate_tabs_export",
                                    "tabs_question_code", "generate_stats_pack",
                                    "generate_market_simulator")
    settings <- settings[!drop, , drop = FALSE]
    out <- tempfile("mnl_config_", fileext = ".xlsx")
    wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(wb, "Settings")
    openxlsx::writeData(wb, "Settings", settings)
    openxlsx::addWorksheet(wb, "Attributes")
    openxlsx::writeData(wb, "Attributes", attrs)
    openxlsx::saveWorkbook(wb, out, overwrite = TRUE)
    out
  }
  mnl_config <- make_mnl_config(demo_config)

  test_that("MNL end-to-end: the committed example fixture is present", {
    expect_true(file.exists(demo_config), info = demo_config)
    expect_true(file.exists(demo_data), info = demo_data)
  })

  # ============================================================================
  # TEST 1: Full pipeline produces PASS / PARTIAL status
  # ============================================================================
  test_that("MNL end-to-end: run_conjoint_analysis returns PASS or PARTIAL", {
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = mnl_config,
      data_file   = demo_data,
      output_file = output_file,
      verbose     = FALSE
    )

    # Status must be PASS or PARTIAL (not REFUSED)
    expect_true(result$status %in% c("PASS", "PARTIAL"),
                info = sprintf("Expected PASS/PARTIAL, got: %s (code: %s, msg: %s)",
                               result$status, result$code %||% "NA", result$message %||% "NA"))

    # Clean up
    unlink(output_file)
  })

  # ============================================================================
  # TEST 2: Utilities data frame structure
  # ============================================================================
  test_that("MNL end-to-end: utilities have Attribute, Level, Utility, SE columns", {
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = mnl_config,
      data_file   = demo_data,
      output_file = output_file,
      verbose     = FALSE
    )

    utils_df <- result$utilities

    # Must be a data frame
    expect_true(is.data.frame(utils_df))

    # Required columns
    expect_true("Attribute" %in% names(utils_df))
    expect_true("Level"     %in% names(utils_df))
    expect_true("Utility"   %in% names(utils_df))
    expect_true("Std_Error" %in% names(utils_df))

    # Must have rows
    expect_gt(nrow(utils_df), 0)

    # Utility and Std_Error should be numeric
    expect_true(is.numeric(utils_df$Utility))
    expect_true(is.numeric(utils_df$Std_Error))

    # There should be multiple attributes
    expect_gte(length(unique(utils_df$Attribute)), 2)

    unlink(output_file)
  })

  # ============================================================================
  # TEST 3: Importance sums to ~100%
  # ============================================================================
  test_that("MNL end-to-end: importance sums to approximately 100", {
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = mnl_config,
      data_file   = demo_data,
      output_file = output_file,
      verbose     = FALSE
    )

    importance <- result$importance

    expect_true(is.data.frame(importance))
    expect_true("Attribute"  %in% names(importance))
    expect_true("Importance" %in% names(importance))
    expect_gt(nrow(importance), 0)

    # Sum should be ~100 (tolerance for rounding)
    expect_equal(sum(importance$Importance), 100, tolerance = 0.5)

    # All individual importances should be non-negative
    expect_true(all(importance$Importance >= 0))

    unlink(output_file)
  })

  # ============================================================================
  # TEST 4: Diagnostics has fit_statistics
  # ============================================================================
  test_that("MNL end-to-end: diagnostics contain fit_statistics", {
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = mnl_config,
      data_file   = demo_data,
      output_file = output_file,
      verbose     = FALSE
    )

    diag <- result$diagnostics

    expect_true(is.list(diag))
    expect_true("fit_statistics" %in% names(diag))

    fit <- diag$fit_statistics
    expect_true(is.list(fit))

    # McFadden R-squared should be present and in [0, 1]
    expect_true("mcfadden_r2" %in% names(fit))
    expect_true(is.numeric(fit$mcfadden_r2))
    expect_gte(fit$mcfadden_r2, 0)
    expect_lte(fit$mcfadden_r2, 1)

    # Hit rate should be present
    expect_true("hit_rate" %in% names(fit))

    # Convergence info
    expect_true("convergence" %in% names(diag))

    unlink(output_file)
  })

  # ============================================================================
  # TEST 5: Excel output file is created
  # ============================================================================
  test_that("MNL end-to-end: Excel output file is created", {
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = mnl_config,
      data_file   = demo_data,
      output_file = output_file,
      verbose     = FALSE
    )

    # File should exist on disk
    expect_true(file.exists(output_file))

    # Should be a valid workbook with expected sheets
    wb <- openxlsx::loadWorkbook(output_file)
    sheet_names <- names(wb)

    expect_true("Part-Worth Utilities" %in% sheet_names)
    expect_true("Attribute Importance" %in% sheet_names)

    unlink(output_file)
  })

  # ============================================================================
  # TEST 6: HTML report is created when configured
  # ============================================================================
  test_that("MNL end-to-end: the standalone simulator matches its setting", {
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = mnl_config,
      data_file   = demo_data,
      output_file = output_file,
      verbose     = FALSE
    )

    # The module's own combined HTML report was retired 2026-08-27. What a run
    # can still produce on its own is the standalone market simulator, and it
    # must match its setting: written when asked for, absent when not.
    sim_path <- sub("\\.xlsx$", "_simulator.html", output_file)
    sim_enabled <- isTRUE(result$config$generate_html_simulator)
    expect_type(result$config$generate_html_simulator, "logical")

    if (sim_enabled) {
      expect_true(file.exists(sim_path))
      expect_gt(file.info(sim_path)$size, 1000)
    } else {
      expect_false(file.exists(sim_path))
    }

    # And the retired setting is gone from the config object entirely.
    expect_null(result$config$generate_html_report)

    unlink(output_file)
    unlink(sim_path)
  })

  # ============================================================================
  # TEST 7: Model result structure
  # ============================================================================
  test_that("MNL end-to-end: model_result has expected structure", {
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = mnl_config,
      data_file   = demo_data,
      output_file = output_file,
      verbose     = FALSE
    )

    mr <- result$model_result

    # Method should be mlogit or clogit (auto selects one)
    expect_true(mr$method %in% c("mlogit", "clogit"))

    # Convergence structure
    expect_true(is.list(mr$convergence))
    expect_true("converged" %in% names(mr$convergence))
    expect_true(mr$convergence$converged)

    # Coefficients
    expect_true(length(mr$coefficients) > 0)
    expect_true(is.numeric(mr$coefficients))

    # Sample info
    expect_true(mr$n_respondents > 0)
    expect_true(mr$n_obs > 0)

    unlink(output_file)
  })

  # ============================================================================
  # TEST 8: Repeated runs are deterministic
  # ============================================================================
  test_that("MNL end-to-end: repeated runs produce identical utilities", {
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    out1 <- tempfile(fileext = ".xlsx")
    out2 <- tempfile(fileext = ".xlsx")

    r1 <- run_conjoint_analysis(
      config_file = mnl_config, data_file = demo_data,
      output_file = out1, verbose = FALSE
    )
    r2 <- run_conjoint_analysis(
      config_file = mnl_config, data_file = demo_data,
      output_file = out2, verbose = FALSE
    )

    expect_equal(r1$utilities$Utility, r2$utilities$Utility, tolerance = 1e-6)
    expect_equal(r1$importance$Importance, r2$importance$Importance, tolerance = 1e-6)

    unlink(c(out1, out2))
  })

} # end of turas_root guard
