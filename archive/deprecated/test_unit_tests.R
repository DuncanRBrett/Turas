# ==============================================================================
# UNIT TESTS - TURAS CONJOINT ANALYSIS MODULE
# ==============================================================================
#
# Comprehensive unit tests for all core functions
#
# Test Categories:
# 1. Helper Functions
# 2. Configuration Loading
# 3. Data Validation
# 4. None Option Handling
# 5. Model Estimation
# 6. Utilities Calculation
# 7. Market Simulator
# 8. Output Generation
#
# ==============================================================================

# Setup - Find Turas root dynamically
script_dir <- tryCatch({
  dirname(sys.frame(1)$ofile)
}, error = function(e) {
  # When run through Rscript, try to detect from working directory
  cwd <- getwd()
  # Check if we're in a module directory
  if (basename(cwd) == "conjoint" && dir.exists("tests")) {
    file.path(cwd, "tests")
  } else {
    cwd
  }
})

# Navigate to Turas root from various starting points
find_turas_root <- function(start_dir) {
  # Try multiple strategies
  candidates <- c(
    # If we're in modules/conjoint/tests
    if (basename(dirname(start_dir)) == "conjoint") {
      dirname(dirname(dirname(start_dir)))
    } else { NULL },
    # If we're in modules/conjoint
    if (basename(start_dir) == "conjoint" && basename(dirname(start_dir)) == "modules") {
      dirname(dirname(start_dir))
    } else { NULL },
    # If we're already in tests directory
    if (basename(start_dir) == "tests" && dir.exists(file.path(dirname(start_dir), "R"))) {
      dirname(dirname(dirname(start_dir)))
    } else { NULL },
    # Current directory
    start_dir
  )

  for (candidate in candidates) {
    if (!is.null(candidate) && dir.exists(file.path(candidate, "modules", "conjoint"))) {
      return(candidate)
    }
  }

  return(NULL)
}

turas_root <- find_turas_root(script_dir)

# Verify we found Turas root
if (is.null(turas_root) || !dir.exists(file.path(turas_root, "modules", "conjoint"))) {
  stop("Cannot find Turas root directory. Current dir: ", getwd(),
       ", Script dir: ", script_dir)
}

setwd(turas_root)

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

# ==============================================================================
# TEST FRAMEWORK
# ==============================================================================

test_count <- 0
pass_count <- 0
fail_count <- 0

test_that <- function(description, code) {
  test_count <<- test_count + 1

  result <- tryCatch({
    code
    TRUE
  }, error = function(e) {
    cat(sprintf("  ✗ %s\n    Error: %s\n", description, conditionMessage(e)))
    FALSE
  })

  if (result) {
    pass_count <<- pass_count + 1
    cat(sprintf("  ✓ %s\n", description))
  } else {
    fail_count <<- fail_count + 1
  }

  invisible(result)
}

expect_equal <- function(actual, expected, tolerance = 1e-6, msg = NULL) {
  if (is.numeric(actual) && is.numeric(expected)) {
    if (!isTRUE(all.equal(actual, expected, tolerance = tolerance))) {
      if (!is.null(msg)) {
        stop(sprintf("%s: Expected %s, got %s", msg, expected, actual))
      } else {
        stop(sprintf("Expected %s, got %s", expected, actual))
      }
    }
  } else {
    if (!identical(actual, expected)) {
      if (!is.null(msg)) {
        stop(sprintf("%s: Expected %s, got %s", msg, expected, actual))
      } else {
        stop(sprintf("Expected %s, got %s", expected, actual))
      }
    }
  }
  invisible(TRUE)
}

expect_true <- function(condition, msg = NULL) {
  if (!isTRUE(condition)) {
    if (!is.null(msg)) {
      stop(msg)
    } else {
      stop("Condition is not TRUE")
    }
  }
  invisible(TRUE)
}

expect_error <- function(code, pattern = NULL) {
  error_caught <- FALSE
  tryCatch({
    code
  }, error = function(e) {
    error_caught <<- TRUE
    if (!is.null(pattern)) {
      if (!grepl(pattern, conditionMessage(e))) {
        stop(sprintf("Error message '%s' does not match pattern '%s'",
                     conditionMessage(e), pattern))
      }
    }
  })

  if (!error_caught) {
    stop("Expected an error but none was raised")
  }
  invisible(TRUE)
}

# ==============================================================================
# CATEGORY 1: HELPER FUNCTIONS
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("CATEGORY 1: HELPER FUNCTIONS\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

test_that("Null coalescing operator %||% works correctly", {
  expect_equal(NULL %||% 5, 5)
  expect_equal(10 %||% 5, 10)
  expect_equal(NA %||% 5, NA)
})

test_that("safe_logical converts values correctly", {
  expect_true(safe_logical("TRUE"))
  expect_true(safe_logical("true"))
  expect_true(safe_logical(TRUE))
  expect_true(!safe_logical("FALSE"))
  expect_true(!safe_logical(FALSE))
  expect_true(!safe_logical(NA, default = FALSE))
  expect_true(safe_logical(NA, default = TRUE))
})

test_that("parse_level_names handles various formats", {
  expect_equal(length(parse_level_names("A, B, C")), 3)
  expect_equal(parse_level_names("A, B, C")[1], "A")
  expect_equal(length(parse_level_names("Single")), 1)
})

test_that("calculate_ci produces correct intervals", {
  ci <- calculate_ci(estimate = 1.0, std_error = 0.2, confidence_level = 0.95)
  expect_true(ci$lower < 1.0)
  expect_true(ci$upper > 1.0)
  expect_true((ci$upper - ci$lower) > 0)
})

test_that("get_significance_stars returns correct symbols", {
  expect_equal(get_significance_stars(0.0001), "***")
  expect_equal(get_significance_stars(0.005), "**")
  expect_equal(get_significance_stars(0.03), "*")
  expect_equal(get_significance_stars(0.1), "ns")
})

test_that("zero_center_utilities works correctly", {
  utils <- c(1.0, 0.5, -0.5, -1.0)
  centered <- zero_center_utilities(utils)
  expect_equal(mean(centered), 0, tolerance = 1e-10)
  expect_equal(length(centered), length(utils))
})

# ==============================================================================
# CATEGORY 2: CONFIGURATION LOADING
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("CATEGORY 2: CONFIGURATION LOADING\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

test_that("load_conjoint_config reads example config successfully", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )
  expect_true(!is.null(config))
  expect_true("attributes" %in% names(config))
  expect_true(nrow(config$attributes) > 0)
})

test_that("config has required fields", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )
  expect_true(!is.null(config$analysis_type))
  expect_true(!is.null(config$estimation_method))
  expect_true(!is.null(config$data_file))
  expect_true(!is.null(config$output_file))
})

test_that("config validation catches errors", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )
  # Should not have critical errors
  expect_true(length(config$validation$critical) == 0)
})

# ==============================================================================
# CATEGORY 3: DATA VALIDATION
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("CATEGORY 3: DATA VALIDATION\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

test_that("load_conjoint_data reads CSV files", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  data_list <- load_conjoint_data(
    "modules/conjoint/examples/sample_cbc_data.csv",
    config,
    verbose = FALSE
  )

  expect_true(!is.null(data_list$data))
  expect_true(nrow(data_list$data) > 0)
})

test_that("data validation detects required columns", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  data_list <- load_conjoint_data(
    "modules/conjoint/examples/sample_cbc_data.csv",
    config,
    verbose = FALSE
  )

  # Should not have critical validation errors
  expect_true(length(data_list$validation$critical) == 0)
})

test_that("data statistics are calculated correctly", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  data_list <- load_conjoint_data(
    "modules/conjoint/examples/sample_cbc_data.csv",
    config,
    verbose = FALSE
  )

  expect_true(data_list$n_respondents > 0)
  expect_true(data_list$n_choice_sets > 0)
  expect_true(data_list$n_alternatives_per_set > 0)
})

# ==============================================================================
# CATEGORY 4: NONE OPTION HANDLING
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("CATEGORY 4: NONE OPTION HANDLING\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

test_that("detect_none_option works on data without none", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  data_list <- load_conjoint_data(
    "modules/conjoint/examples/sample_cbc_data.csv",
    config,
    verbose = FALSE
  )

  none_info <- detect_none_option(data_list$data, config)

  # Example data doesn't have none option
  expect_true(!is.null(none_info))
  expect_true(!is.null(none_info$has_none))
})

# ==============================================================================
# CATEGORY 5: MODEL ESTIMATION
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("CATEGORY 5: MODEL ESTIMATION\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

test_that("estimate_choice_model runs successfully", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  data_list <- load_conjoint_data(
    "modules/conjoint/examples/sample_cbc_data.csv",
    config,
    verbose = FALSE
  )

  model_result <- estimate_choice_model(data_list, config, verbose = FALSE)

  expect_true(!is.null(model_result))
  expect_true(!is.null(model_result$coefficients))
  expect_true(length(model_result$coefficients) > 0)
})

test_that("model estimation produces convergence info", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  data_list <- load_conjoint_data(
    "modules/conjoint/examples/sample_cbc_data.csv",
    config,
    verbose = FALSE
  )

  model_result <- estimate_choice_model(data_list, config, verbose = FALSE)

  expect_true(!is.null(model_result$convergence))
  expect_true(!is.null(model_result$convergence$converged))
})

# ==============================================================================
# CATEGORY 6: UTILITIES CALCULATION
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("CATEGORY 6: UTILITIES CALCULATION\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

test_that("calculate_utilities produces data frame", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  data_list <- load_conjoint_data(
    "modules/conjoint/examples/sample_cbc_data.csv",
    config,
    verbose = FALSE
  )

  model_result <- estimate_choice_model(data_list, config, verbose = FALSE)
  utilities <- calculate_utilities(model_result, config, verbose = FALSE)

  expect_true(is.data.frame(utilities))
  expect_true(nrow(utilities) > 0)
  expect_true("Attribute" %in% names(utilities))
  expect_true("Level" %in% names(utilities))
  expect_true("Utility" %in% names(utilities))
})

test_that("utilities are zero-centered within attributes", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  data_list <- load_conjoint_data(
    "modules/conjoint/examples/sample_cbc_data.csv",
    config,
    verbose = FALSE
  )

  model_result <- estimate_choice_model(data_list, config, verbose = FALSE)
  utilities <- calculate_utilities(model_result, config, verbose = FALSE)

  # Check each attribute is zero-centered
  for (attr in unique(utilities$Attribute)) {
    attr_utils <- utilities$Utility[utilities$Attribute == attr]
    mean_util <- mean(attr_utils)
    expect_equal(mean_util, 0, tolerance = 1e-6,
                 msg = sprintf("Attribute %s not zero-centered", attr))
  }
})

test_that("calculate_attribute_importance produces valid results", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  data_list <- load_conjoint_data(
    "modules/conjoint/examples/sample_cbc_data.csv",
    config,
    verbose = FALSE
  )

  model_result <- estimate_choice_model(data_list, config, verbose = FALSE)
  utilities <- calculate_utilities(model_result, config, verbose = FALSE)
  importance <- calculate_attribute_importance(utilities, config, verbose = FALSE)

  expect_true(is.data.frame(importance))
  expect_true(nrow(importance) > 0)
  expect_true("Importance" %in% names(importance))

  # Importance should sum to 100
  expect_equal(sum(importance$Importance), 100, tolerance = 0.01)

  # All importance values should be positive
  expect_true(all(importance$Importance > 0))
})

# ==============================================================================
# CATEGORY 7: MARKET SIMULATOR
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("CATEGORY 7: MARKET SIMULATOR\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

test_that("predict_market_shares produces valid shares", {
  # Create simple utilities
  utilities <- data.frame(
    Attribute = c("Price", "Price", "Brand", "Brand"),
    Level = c("Low", "High", "A", "B"),
    Utility = c(0.5, -0.5, 0.3, -0.3),
    stringsAsFactors = FALSE
  )

  products <- list(
    list(Price = "Low", Brand = "A"),
    list(Price = "High", Brand = "B")
  )

  shares <- predict_market_shares(products, utilities, method = "logit")

  expect_equal(nrow(shares), 2)
  expect_equal(sum(shares$Share_Percent), 100, tolerance = 0.01)
  expect_true(all(shares$Share_Percent >= 0))
  expect_true(all(shares$Share_Percent <= 100))
})

test_that("first-choice rule selects highest utility", {
  utilities <- data.frame(
    Attribute = c("Price", "Price", "Brand", "Brand"),
    Level = c("Low", "High", "A", "B"),
    Utility = c(0.5, -0.5, 0.3, -0.3),
    stringsAsFactors = FALSE
  )

  products <- list(
    list(Price = "Low", Brand = "A"),    # Utility = 0.8 (highest)
    list(Price = "High", Brand = "B")    # Utility = -0.8
  )

  shares <- predict_market_shares(products, utilities, method = "first_choice")

  expect_equal(shares$Share_Percent[1], 100)
  expect_equal(shares$Share_Percent[2], 0)
})

test_that("sensitivity_one_way produces correct structure", {
  utilities <- data.frame(
    Attribute = c("Price", "Price", "Price"),
    Level = c("Low", "Med", "High"),
    Utility = c(0.5, 0.0, -0.5),
    stringsAsFactors = FALSE
  )

  base_product <- list(Price = "Low")

  sens <- sensitivity_one_way(
    base_product = base_product,
    attribute = "Price",
    all_levels = c("Low", "Med", "High"),
    utilities = utilities,
    other_products = list(),
    method = "logit"
  )

  expect_equal(nrow(sens), 3)
  expect_true("Level" %in% names(sens))
  expect_true("Share_Percent" %in% names(sens))
  expect_true("Share_Change" %in% names(sens))
})

test_that("int2col converts numbers to Excel columns correctly", {
  expect_equal(int2col(1), "A")
  expect_equal(int2col(26), "Z")
  expect_equal(int2col(27), "AA")
  expect_equal(int2col(52), "AZ")
})

# ==============================================================================
# CATEGORY 8: OUTPUT GENERATION
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("CATEGORY 8: OUTPUT GENERATION\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

test_that("write_conjoint_output creates Excel file", {
  config <- load_conjoint_config(
    "modules/conjoint/examples/example_config.xlsx",
    verbose = FALSE
  )

  data_list <- load_conjoint_data(
    "modules/conjoint/examples/sample_cbc_data.csv",
    config,
    verbose = FALSE
  )

  model_result <- estimate_choice_model(data_list, config, verbose = FALSE)
  utilities <- calculate_utilities(model_result, config, verbose = FALSE)
  importance <- calculate_attribute_importance(utilities, config, verbose = FALSE)
  diagnostics <- calculate_model_diagnostics(model_result, data_list, utilities,
                                               importance, config, verbose = FALSE)

  test_output <- tempfile(fileext = ".xlsx")

  write_conjoint_output(
    utilities = utilities,
    importance = importance,
    diagnostics = diagnostics,
    model_result = model_result,
    config = config,
    data_info = data_list,
    output_file = test_output
  )

  expect_true(file.exists(test_output))

  # Verify can load workbook
  wb <- loadWorkbook(test_output)
  expect_true(length(names(wb)) > 0)

  # Clean up
  unlink(test_output)
})

# ==============================================================================
# TEST SUMMARY
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("TEST SUMMARY\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

cat(sprintf("Total tests:  %d\n", test_count))
cat(sprintf("Passed:       %d (%.1f%%)\n", pass_count,
            pass_count / test_count * 100))
cat(sprintf("Failed:       %d (%.1f%%)\n", fail_count,
            fail_count / test_count * 100))
cat("\n")

if (fail_count == 0) {
  cat("✓ ALL UNIT TESTS PASSED!\n\n")
} else {
  cat(sprintf("✗ %d TESTS FAILED\n\n", fail_count))
  stop("Some tests failed")
}
