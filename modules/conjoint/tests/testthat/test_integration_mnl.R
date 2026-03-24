# ==============================================================================
# INTEGRATION TESTS: END-TO-END MNL PIPELINE
# ==============================================================================
#
# Tests the full conjoint analysis pipeline from config+data to output files.
# Uses the v3 demo config and data that ship with the module.
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

  # Paths to demo fixtures
  demo_config <- file.path(turas_root, "examples", "conjoint", "v3_demo", "demo_config.xlsx")
  demo_data   <- file.path(turas_root, "examples", "conjoint", "v3_demo", "demo_data.csv")

  # ============================================================================
  # TEST 1: Full pipeline produces PASS / PARTIAL status
  # ============================================================================
  test_that("MNL end-to-end: run_conjoint_analysis returns PASS or PARTIAL", {
    skip_if(!file.exists(demo_config), "Demo config not found")
    skip_if(!file.exists(demo_data), "Demo data not found")
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = demo_config,
      data_file   = demo_data,
      output_file = output_file,
      verbose     = FALSE
    )

    # Status must be PASS or PARTIAL (not REFUSED)
    if (result$status == "REFUSED") {
      cat("\n[DIAG] REFUSED code:", result$code, "\n")
      cat("[DIAG] REFUSED message:", result$message, "\n")
      cat("[DIAG] REFUSED how_to_fix:", result$how_to_fix %||% "N/A", "\n")
      cat("[DIAG] getwd():", getwd(), "\n")
      cat("[DIAG] turas_root:", turas_root, "\n")
      cat("[DIAG] demo_config exists:", file.exists(demo_config), "\n")
      cat("[DIAG] demo_data exists:", file.exists(demo_data), "\n")
    }
    expect_true(result$status %in% c("PASS", "PARTIAL"),
                info = sprintf("Expected PASS/PARTIAL, got: %s", result$status))

    # Clean up
    unlink(output_file)
  })

  # ============================================================================
  # TEST 2: Utilities data frame structure
  # ============================================================================
  test_that("MNL end-to-end: utilities have Attribute, Level, Utility, SE columns", {
    skip_if(!file.exists(demo_config), "Demo config not found")
    skip_if(!file.exists(demo_data), "Demo data not found")
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = demo_config,
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
    skip_if(!file.exists(demo_config), "Demo config not found")
    skip_if(!file.exists(demo_data), "Demo data not found")
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = demo_config,
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
    skip_if(!file.exists(demo_config), "Demo config not found")
    skip_if(!file.exists(demo_data), "Demo data not found")
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = demo_config,
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
    skip_if(!file.exists(demo_config), "Demo config not found")
    skip_if(!file.exists(demo_data), "Demo data not found")
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = demo_config,
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
  test_that("MNL end-to-end: HTML report is created", {
    skip_if(!file.exists(demo_config), "Demo config not found")
    skip_if(!file.exists(demo_data), "Demo data not found")
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = demo_config,
      data_file   = demo_data,
      output_file = output_file,
      verbose     = FALSE
    )

    # HTML report path is derived from output file
    html_path <- sub("\\.xlsx$", "_report.html", output_file)

    # If the config enables HTML report generation, verify it was created
    if (isTRUE(result$config$generate_html_report)) {
      expect_true(file.exists(html_path),
                  info = "HTML report should be created when generate_html_report is TRUE")

      # File should have non-trivial size (> 1 KB)
      expect_gt(file.info(html_path)$size, 1000)
    }

    unlink(output_file)
    unlink(html_path)
  })

  # ============================================================================
  # TEST 7: Model result structure
  # ============================================================================
  test_that("MNL end-to-end: model_result has expected structure", {
    skip_if(!file.exists(demo_config), "Demo config not found")
    skip_if(!file.exists(demo_data), "Demo data not found")
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    output_file <- tempfile(fileext = ".xlsx")

    result <- run_conjoint_analysis(
      config_file = demo_config,
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
    skip_if(!file.exists(demo_config), "Demo config not found")
    skip_if(!file.exists(demo_data), "Demo data not found")
    skip_if_not_installed("mlogit")
    skip_if_not_installed("dfidx")

    out1 <- tempfile(fileext = ".xlsx")
    out2 <- tempfile(fileext = ".xlsx")

    r1 <- run_conjoint_analysis(
      config_file = demo_config, data_file = demo_data,
      output_file = out1, verbose = FALSE
    )
    r2 <- run_conjoint_analysis(
      config_file = demo_config, data_file = demo_data,
      output_file = out2, verbose = FALSE
    )

    expect_equal(r1$utilities$Utility, r2$utilities$Utility, tolerance = 1e-6)
    expect_equal(r1$importance$Importance, r2$importance$Importance, tolerance = 1e-6)

    unlink(c(out1, out2))
  })

} # end of turas_root guard
