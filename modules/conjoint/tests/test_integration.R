# ==============================================================================
# INTEGRATION TESTS - TURAS CONJOINT ANALYSIS MODULE
# ==============================================================================
#
# End-to-end integration tests for complete workflows
#
# Test Scenarios:
# 1. Full Analysis Pipeline
# 2. Different Estimation Methods
# 3. Edge Cases and Error Handling
# 4. Market Simulator Integration
# 5. Output Validation
#
# ==============================================================================

# Setup
setwd("/home/user/Turas")

suppressPackageStartupMessages({
  library(mlogit)
  library(survival)
  library(openxlsx)
  library(dplyr)
  library(tidyr)
})

# Source all modules
source("modules/conjoint/R/99_helpers.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/09_none_handling.R")
source("modules/conjoint/R/02_data.R")
source("modules/conjoint/R/03_estimation.R")
source("modules/conjoint/R/04_utilities.R")
source("modules/conjoint/R/05_simulator.R")
source("modules/conjoint/R/08_market_simulator.R")
source("modules/conjoint/R/07_output.R")
source("modules/conjoint/R/00_main.R")

# Test framework
test_count <- 0
pass_count <- 0
fail_count <- 0

test_scenario <- function(description, code) {
  test_count <<- test_count + 1
  cat(sprintf("\n[Test %d] %s\n", test_count, description))
  cat(rep("-", 80), "\n", sep = "")

  result <- tryCatch({
    code
    cat("  ✓ PASS\n")
    pass_count <<- pass_count + 1
    TRUE
  }, error = function(e) {
    cat(sprintf("  ✗ FAIL: %s\n", conditionMessage(e)))
    fail_count <<- fail_count + 1
    FALSE
  })

  invisible(result)
}

# ==============================================================================
# SCENARIO 1: FULL ANALYSIS PIPELINE
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("SCENARIO 1: FULL ANALYSIS PIPELINE\n")
cat(rep("=", 80), "\n", sep = "")

test_scenario("Complete conjoint analysis with example data", {
  results <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  # Verify structure
  stopifnot(!is.null(results))
  stopifnot("utilities" %in% names(results))
  stopifnot("importance" %in% names(results))
  stopifnot("diagnostics" %in% names(results))
  stopifnot("model_result" %in% names(results))

  # Verify utilities
  stopifnot(nrow(results$utilities) > 0)
  stopifnot(all(c("Attribute", "Level", "Utility") %in% names(results$utilities)))

  # Verify importance sums to 100
  total_importance <- sum(results$importance$Importance)
  stopifnot(abs(total_importance - 100) < 0.01)

  # Verify output file was created
  stopifnot(file.exists(results$config$output_file))

  cat("    - Utilities calculated:", nrow(results$utilities), "\n")
  cat("    - Attributes analyzed:", nrow(results$importance), "\n")
  cat("    - Model converged:", results$model_result$convergence$converged, "\n")
})

test_scenario("Analysis produces valid utilities (zero-centered)", {
  results <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  # Check each attribute is zero-centered
  for (attr in unique(results$utilities$Attribute)) {
    attr_utils <- results$utilities$Utility[results$utilities$Attribute == attr]
    mean_util <- mean(attr_utils)

    stopifnot(abs(mean_util) < 1e-6)

    cat(sprintf("    - %s: mean utility = %.10f (zero-centered)\n",
                attr, mean_util))
  }
})

test_scenario("Analysis produces confidence intervals", {
  results <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  stopifnot("CI_Lower" %in% names(results$utilities))
  stopifnot("CI_Upper" %in% names(results$utilities))

  # CIs should contain the point estimate
  n_valid_cis <- sum(results$utilities$CI_Lower <= results$utilities$Utility &
                     results$utilities$CI_Upper >= results$utilities$Utility,
                     na.rm = TRUE)

  cat(sprintf("    - Valid CIs: %d/%d\n", n_valid_cis, nrow(results$utilities)))

  # At least 90% should be valid
  stopifnot(n_valid_cis / nrow(results$utilities) > 0.9)
})

# ==============================================================================
# SCENARIO 2: DIFFERENT ESTIMATION METHODS
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("SCENARIO 2: DIFFERENT ESTIMATION METHODS\n")
cat(rep("=", 80), "\n", sep = "")

test_scenario("Auto method selection works", {
  results_auto <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  stopifnot(!is.null(results_auto$model_result$method))
  stopifnot(results_auto$model_result$method %in% c("mlogit", "clogit"))

  cat(sprintf("    - Selected method: %s\n", results_auto$model_result$method))
  cat(sprintf("    - Convergence: %s\n",
              results_auto$model_result$convergence$converged))
})

# ==============================================================================
# SCENARIO 3: EDGE CASES AND ERROR HANDLING
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("SCENARIO 3: EDGE CASES AND ERROR HANDLING\n")
cat(rep("=", 80), "\n", sep = "")

test_scenario("Handles missing config file gracefully", {
  error_caught <- FALSE

  tryCatch({
    run_conjoint_analysis(
      config_file = "nonexistent_file.xlsx",
      verbose = FALSE
    )
  }, error = function(e) {
    error_caught <<- TRUE
    cat(sprintf("    - Caught expected error: %s\n",
                substr(conditionMessage(e), 1, 60)))
  })

  stopifnot(error_caught)
})

test_scenario("Handles missing data file gracefully", {
  # Create temp config with invalid data path
  temp_config <- tempfile(fileext = ".xlsx")

  wb <- createWorkbook()

  # Settings sheet
  addWorksheet(wb, "Settings")
  settings_data <- data.frame(
    Setting = c("analysis_type", "data_file", "output_file"),
    Value = c("choice", "nonexistent_data.csv", tempfile(fileext = ".xlsx")),
    Description = c("", "", ""),
    stringsAsFactors = FALSE
  )
  writeData(wb, "Settings", settings_data)

  # Attributes sheet
  addWorksheet(wb, "Attributes")
  attr_data <- data.frame(
    AttributeName = "Price",
    AttributeLabel = "Price",
    NumLevels = 2,
    Level1 = "$10",
    Level2 = "$20",
    stringsAsFactors = FALSE
  )
  writeData(wb, "Attributes", attr_data)

  saveWorkbook(wb, temp_config, overwrite = TRUE)

  error_caught <- FALSE

  tryCatch({
    run_conjoint_analysis(config_file = temp_config, verbose = FALSE)
  }, error = function(e) {
    error_caught <<- TRUE
    cat(sprintf("    - Caught expected error: %s\n",
                substr(conditionMessage(e), 1, 60)))
  })

  unlink(temp_config)
  stopifnot(error_caught)
})

# ==============================================================================
# SCENARIO 4: MARKET SIMULATOR INTEGRATION
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("SCENARIO 4: MARKET SIMULATOR INTEGRATION\n")
cat(rep("=", 80), "\n", sep = "")

test_scenario("Market simulator sheets are created when enabled", {
  results <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  wb <- loadWorkbook(results$config$output_file)
  sheet_names <- names(wb)

  has_market_sim <- "Market Simulator" %in% sheet_names
  has_sim_data <- "Simulator Data" %in% sheet_names

  cat(sprintf("    - Market Simulator sheet present: %s\n", has_market_sim))
  cat(sprintf("    - Simulator Data sheet present: %s\n", has_sim_data))

  stopifnot(has_market_sim)
  stopifnot(has_sim_data)
})

test_scenario("Market simulator produces valid share predictions", {
  results <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  # Create test products
  products <- list(
    list(
      Brand = "Apple",
      Price = "$299",
      Screen_Size = "6.7 inches",
      Battery_Life = "24 hours",
      Camera_Quality = "Excellent"
    ),
    list(
      Brand = "Samsung",
      Price = "$399",
      Screen_Size = "6.1 inches",
      Battery_Life = "18 hours",
      Camera_Quality = "Good"
    )
  )

  shares <- predict_market_shares(
    products = products,
    utilities = results$utilities,
    method = "logit"
  )

  total_share <- sum(shares$Share_Percent)

  cat(sprintf("    - Product 1 share: %.1f%%\n", shares$Share_Percent[1]))
  cat(sprintf("    - Product 2 share: %.1f%%\n", shares$Share_Percent[2]))
  cat(sprintf("    - Total share: %.1f%% (should be 100.0%%)\n", total_share))

  stopifnot(abs(total_share - 100) < 0.01)
  stopifnot(all(shares$Share_Percent >= 0))
  stopifnot(all(shares$Share_Percent <= 100))
})

test_scenario("Sensitivity analysis produces consistent results", {
  results <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  base_product <- list(
    Brand = "Apple",
    Price = "$299",
    Screen_Size = "6.7 inches",
    Battery_Life = "24 hours",
    Camera_Quality = "Excellent"
  )

  sens <- sensitivity_one_way(
    base_product = base_product,
    attribute = "Price",
    all_levels = c("$299", "$399", "$499", "$599"),
    utilities = results$utilities,
    other_products = list(),
    method = "logit"
  )

  # Should have one row per level
  stopifnot(nrow(sens) == 4)

  # Share change for current level should be 0
  current_row <- sens[sens$Is_Current, ]
  stopifnot(abs(current_row$Share_Change) < 0.01)

  cat(sprintf("    - Tested %d price levels\n", nrow(sens)))\n  cat(sprintf("    - Current level has 0 share change: %s\n",
              abs(current_row$Share_Change) < 0.01))
})

# ==============================================================================
# SCENARIO 5: OUTPUT VALIDATION
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("SCENARIO 5: OUTPUT VALIDATION\n")
cat(rep("=", 80), "\n", sep = "")

test_scenario("Excel output contains all required sheets", {
  results <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  wb <- loadWorkbook(results$config$output_file)
  sheet_names <- names(wb)

  required_sheets <- c(
    "Executive Summary",
    "Attribute Importance",
    "Part-Worth Utilities",
    "Model Diagnostics"
  )

  missing_sheets <- setdiff(required_sheets, sheet_names)

  cat(sprintf("    - Total sheets: %d\n", length(sheet_names)))
  cat(sprintf("    - Required sheets present: %d/%d\n",
              length(required_sheets) - length(missing_sheets),
              length(required_sheets)))

  if (length(missing_sheets) > 0) {
    cat(sprintf("    - Missing sheets: %s\n",
                paste(missing_sheets, collapse = ", ")))
  }

  stopifnot(length(missing_sheets) == 0)
})

test_scenario("Excel sheets contain data (not empty)", {
  results <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  wb <- loadWorkbook(results$config$output_file)

  # Check utilities sheet
  utilities_sheet <- readWorkbook(wb, "Part-Worth Utilities",
                                   colNames = TRUE,
                                   skipEmptyRows = FALSE)

  stopifnot(nrow(utilities_sheet) > 0)

  cat(sprintf("    - Utilities sheet rows: %d\n", nrow(utilities_sheet)))

  # Check importance sheet
  importance_sheet <- readWorkbook(wb, "Attribute Importance",
                                    colNames = TRUE,
                                    skipEmptyRows = FALSE)

  stopifnot(nrow(importance_sheet) > 0)

  cat(sprintf("    - Importance sheet rows: %d\n", nrow(importance_sheet)))
})

test_scenario("Simulator data sheet has correct structure", {
  results <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  wb <- loadWorkbook(results$config$output_file)

  # Read simulator data
  sim_data <- readWorkbook(wb, "Simulator Data",
                            colNames = TRUE,
                            skipEmptyRows = FALSE)

  # Should have columns: Level, Attribute, Utility
  required_cols <- c("Level", "Attribute", "Utility")
  missing_cols <- setdiff(required_cols, names(sim_data))

  cat(sprintf("    - Simulator data rows: %d\n", nrow(sim_data)))
  cat(sprintf("    - Columns: %s\n", paste(names(sim_data)[1:3], collapse = ", ")))

  stopifnot(length(missing_cols) == 0)
  stopifnot(nrow(sim_data) == nrow(results$utilities))
})

# ==============================================================================
# SCENARIO 6: ROBUSTNESS TESTS
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("SCENARIO 6: ROBUSTNESS TESTS\n")
cat(rep("=", 80), "\n", sep = "")

test_scenario("Analysis handles data with perfect choice patterns", {
  # This tests robustness when some levels are always/never chosen

  results <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  # Check for warnings about perfect separation
  has_warnings <- length(results$data_info$validation$warnings) > 0

  cat(sprintf("    - Validation warnings: %d\n",
              length(results$data_info$validation$warnings)))
  cat(sprintf("    - Analysis completed: %s\n",
              !is.null(results$utilities)))

  # Analysis should complete even with warnings
  stopifnot(!is.null(results$utilities))
})

test_scenario("Multiple runs produce consistent results", {
  # Run analysis twice and compare results

  results1 <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  results2 <- run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  # Utilities should be identical
  utils_match <- all.equal(
    results1$utilities$Utility,
    results2$utilities$Utility,
    tolerance = 1e-6
  )

  cat(sprintf("    - Utilities match: %s\n", isTRUE(utils_match)))

  # Importance should be identical
  imp_match <- all.equal(
    results1$importance$Importance,
    results2$importance$Importance,
    tolerance = 1e-6
  )

  cat(sprintf("    - Importance match: %s\n", isTRUE(imp_match)))

  stopifnot(isTRUE(utils_match))
  stopifnot(isTRUE(imp_match))
})

# ==============================================================================
# TEST SUMMARY
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("INTEGRATION TEST SUMMARY\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

cat(sprintf("Total scenarios:  %d\n", test_count))
cat(sprintf("Passed:           %d (%.1f%%)\n", pass_count,
            pass_count / test_count * 100))
cat(sprintf("Failed:           %d (%.1f%%)\n", fail_count,
            fail_count / test_count * 100))
cat("\n")

if (fail_count == 0) {
  cat("✓ ALL INTEGRATION TESTS PASSED!\n\n")
} else {
  cat(sprintf("✗ %d TESTS FAILED\n\n", fail_count))
  stop("Some tests failed")
}
