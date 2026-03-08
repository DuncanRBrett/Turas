# ==============================================================================
# TEST SUITE FOR UTILS.R
# ==============================================================================
# Comprehensive tests for utility functions
# Tests edge cases, error conditions, and normal operation
# ==============================================================================

# Source the utils file
source("../R/utils.R")

# ==============================================================================
# TEST: format_decimal()
# ==============================================================================

test_format_decimal <- function() {
  cat("\n=== Testing format_decimal() ===\n")

  # Test 1: Period separator (default)
  result <- format_decimal(c(0.456, 1.234), decimal_sep = ".", digits = 2)
  expected <- c("0.46", "1.23")
  stopifnot(all(result == expected))
  cat("✓ Period separator works correctly\n")

  # Test 2: Comma separator
  result <- format_decimal(c(0.456, 1.234), decimal_sep = ",", digits = 2)
  expected <- c("0,46", "1,23")
  stopifnot(all(result == expected))
  cat("✓ Comma separator works correctly\n")

  # Test 3: Different decimal places
  result <- format_decimal(0.123456, decimal_sep = ".", digits = 4)
  expected <- "0.1235"  # Rounded
  stopifnot(result == expected)
  cat("✓ Decimal places parameter works\n")

  # Test 4: Zero value
  result <- format_decimal(0, decimal_sep = ",", digits = 2)
  expected <- "0,00"
  stopifnot(result == expected)
  cat("✓ Zero value handled correctly\n")

  # Test 5: Negative value
  result <- format_decimal(-0.456, decimal_sep = ",", digits = 2)
  expected <- "-0,46"
  stopifnot(result == expected)
  cat("✓ Negative values handled correctly\n")

  # Test 6: Error on non-numeric input
  error_caught <- FALSE
  tryCatch(
    format_decimal("not a number"),
    error = function(e) {
      error_caught <<- TRUE
      stopifnot(grepl("must be numeric", e$message))
    }
  )
  stopifnot(error_caught)
  cat("✓ Error correctly thrown for non-numeric input\n")

  # Test 7: Error on invalid separator
  error_caught <- FALSE
  tryCatch(
    format_decimal(0.5, decimal_sep = ";"),
    error = function(e) {
      error_caught <<- TRUE
      stopifnot(grepl("must be either '.' or ','", e$message))
    }
  )
  stopifnot(error_caught)
  cat("✓ Error correctly thrown for invalid separator\n")

  cat("✓ All format_decimal() tests passed!\n")
}


# ==============================================================================
# TEST: format_output_df()
# ==============================================================================

test_format_output_df <- function() {
  cat("\n=== Testing format_output_df() ===\n")

  # Test 1: Basic formatting
  df <- data.frame(
    Question = "Q1",
    Base_n = 1000L,
    Proportion = 0.456,
    CI_Lower = 0.423,
    CI_Upper = 0.489
  )

  result <- format_output_df(df, decimal_sep = ",", digits = 2, exclude_cols = "Base_n")

  # Base_n should remain numeric, others should be character with comma
  stopifnot(is.numeric(result$Base_n))
  stopifnot(result$Base_n == 1000)
  stopifnot(is.character(result$Proportion))
  stopifnot(result$Proportion == "0,46")
  stopifnot(result$CI_Lower == "0,42")
  cat("✓ Data frame formatting works correctly\n")

  # Test 2: Exclude multiple columns
  result <- format_output_df(df, decimal_sep = ".",
                             exclude_cols = c("Base_n", "Proportion"))
  stopifnot(is.numeric(result$Base_n))
  stopifnot(is.numeric(result$Proportion))
  stopifnot(is.character(result$CI_Lower))
  cat("✓ Multiple excluded columns handled correctly\n")

  cat("✓ All format_output_df() tests passed!\n")
}


# ==============================================================================
# TEST: validate_proportion()
# ==============================================================================

test_validate_proportion <- function() {
  cat("\n=== Testing validate_proportion() ===\n")

  # Test 1: Valid proportion
  result <- validate_proportion(0.5)
  stopifnot(result == TRUE)
  cat("✓ Valid proportion accepted\n")

  # Test 2: Boundary values
  validate_proportion(0)
  validate_proportion(1)
  cat("✓ Boundary values (0 and 1) accepted\n")

  # Test 3: Error on value > 1
  error_caught <- FALSE
  tryCatch(
    validate_proportion(1.5),
    error = function(e) {
      error_caught <<- TRUE
      stopifnot(grepl("must be between 0 and 1", e$message))
    }
  )
  stopifnot(error_caught)
  cat("✓ Error thrown for value > 1\n")

  # Test 4: Error on negative value
  error_caught <- FALSE
  tryCatch(
    validate_proportion(-0.1),
    error = function(e) {
      error_caught <<- TRUE
    }
  )
  stopifnot(error_caught)
  cat("✓ Error thrown for negative value\n")

  # Test 5: Error on NA
  error_caught <- FALSE
  tryCatch(
    validate_proportion(NA_real_),  # Use NA_real_ to ensure it's numeric NA
    error = function(e) {
      error_caught <<- TRUE
      stopifnot(grepl("NA values", e$message))
    }
  )
  stopifnot(error_caught)
  cat("✓ Error thrown for NA value\n")

  cat("✓ All validate_proportion() tests passed!\n")
}


# ==============================================================================
# TEST: validate_sample_size()
# ==============================================================================

test_validate_sample_size <- function() {
  cat("\n=== Testing validate_sample_size() ===\n")

  # Test 1: Valid sample size
  validate_sample_size(100)
  cat("✓ Valid sample size accepted\n")

  # Test 2: Minimum boundary
  validate_sample_size(1)
  cat("✓ Minimum sample size (1) accepted\n")

  # Test 3: Custom minimum
  validate_sample_size(50, min_n = 30)
  cat("✓ Custom minimum works\n")

  # Test 4: Error on zero
  error_caught <- FALSE
  tryCatch(
    validate_sample_size(0),
    error = function(e) {
      error_caught <<- TRUE
      stopifnot(grepl("must be >= 1", e$message))
    }
  )
  stopifnot(error_caught)
  cat("✓ Error thrown for n=0\n")

  # Test 5: Error on negative
  error_caught <- FALSE
  tryCatch(
    validate_sample_size(-5),
    error = function(e) {
      error_caught <<- TRUE
    }
  )
  stopifnot(error_caught)
  cat("✓ Error thrown for negative n\n")

  # Test 6: Error on non-integer
  error_caught <- FALSE
  tryCatch(
    validate_sample_size(10.5),
    error = function(e) {
      error_caught <<- TRUE
      stopifnot(grepl("must be an integer", e$message))
    }
  )
  stopifnot(error_caught)
  cat("✓ Error thrown for non-integer n\n")

  cat("✓ All validate_sample_size() tests passed!\n")
}


# ==============================================================================
# TEST: validate_conf_level()
# ==============================================================================

test_validate_conf_level <- function() {
  cat("\n=== Testing validate_conf_level() ===\n")

  # Test 1: Valid confidence levels
  validate_conf_level(0.95)
  validate_conf_level(0.90)
  validate_conf_level(0.99)
  cat("✓ Standard confidence levels accepted\n")

  # Test 2: Error on invalid value
  error_caught <- FALSE
  tryCatch(
    validate_conf_level(0.85),
    error = function(e) {
      error_caught <<- TRUE
      stopifnot(grepl("must be one of", e$message))
    }
  )
  stopifnot(error_caught)
  cat("✓ Error thrown for non-standard confidence level\n")

  # Test 3: Error on value >= 1
  error_caught <- FALSE
  tryCatch(
    validate_conf_level(1.0),
    error = function(e) {
      error_caught <<- TRUE
      stopifnot(grepl("must be between 0 and 1", e$message))
    }
  )
  stopifnot(error_caught)
  cat("✓ Error thrown for conf_level >= 1\n")

  # Test 4: Custom allowed values
  validate_conf_level(0.85, allowed_values = c(0.85, 0.90, 0.95))
  cat("✓ Custom allowed values work\n")

  cat("✓ All validate_conf_level() tests passed!\n")
}


# ==============================================================================
# TEST: validate_decimal_separator()
# ==============================================================================

test_validate_decimal_separator <- function() {
  cat("\n=== Testing validate_decimal_separator() ===\n")

  # Test 1: Valid separators
  validate_decimal_separator(".")
  validate_decimal_separator(",")
  cat("✓ Valid separators accepted\n")

  # Test 2: Error on invalid separator
  error_caught <- FALSE
  tryCatch(
    validate_decimal_separator(";"),
    error = function(e) {
      error_caught <<- TRUE
      stopifnot(grepl("must be either '.' or ','", e$message))
    }
  )
  stopifnot(error_caught)
  cat("✓ Error thrown for invalid separator\n")

  cat("✓ All validate_decimal_separator() tests passed!\n")
}


# ==============================================================================
# TEST: validate_question_limit()
# ==============================================================================

test_validate_question_limit <- function() {
  cat("\n=== Testing validate_question_limit() ===\n")

  # Test 1: Valid question count
  validate_question_limit(50)
  validate_question_limit(200)
  cat("✓ Valid question counts accepted\n")

  # Test 2: Error on exceeding limit
  error_caught <- FALSE
  tryCatch(
    validate_question_limit(201),
    error = function(e) {
      error_caught <<- TRUE
      stopifnot(grepl("Question limit exceeded", e$message))
      stopifnot(grepl("201 questions", e$message))
      stopifnot(grepl("maximum 200", e$message))
    }
  )
  stopifnot(error_caught)
  cat("✓ Error thrown for exceeding 200 question limit\n")

  # Test 3: Custom maximum
  validate_question_limit(150, max_questions = 150)
  cat("✓ Custom maximum works\n")

  # Test 4: Error on zero questions
  error_caught <- FALSE
  tryCatch(
    validate_question_limit(0),
    error = function(e) {
      error_caught <<- TRUE
      stopifnot(grepl("must be at least 1", e$message))
    }
  )
  stopifnot(error_caught)
  cat("✓ Error thrown for 0 questions\n")

  cat("✓ All validate_question_limit() tests passed!\n")
}


# ==============================================================================
# TEST: check_small_sample()
# ==============================================================================

test_check_small_sample <- function() {
  cat("\n=== Testing check_small_sample() ===\n")

  # Test 1: Very small sample (n < 30)
  warning_msg <- check_small_sample(25)
  stopifnot(grepl("Very small base", warning_msg))
  stopifnot(grepl("n=25", warning_msg))
  cat("✓ Very small sample warning works\n")

  # Test 2: Small sample (30 <= n < 50)
  warning_msg <- check_small_sample(40)
  stopifnot(grepl("Small base", warning_msg))
  stopifnot(!grepl("Very", warning_msg))
  cat("✓ Small sample warning works\n")

  # Test 3: Adequate sample (n >= 50)
  warning_msg <- check_small_sample(100)
  stopifnot(warning_msg == "")
  cat("✓ No warning for adequate sample\n")

  # Test 4: Custom thresholds
  warning_msg <- check_small_sample(60, threshold_critical = 50, threshold_warning = 70)
  stopifnot(grepl("Small base", warning_msg))
  cat("✓ Custom thresholds work\n")

  cat("✓ All check_small_sample() tests passed!\n")
}


# ==============================================================================
# TEST: check_extreme_proportion()
# ==============================================================================

test_check_extreme_proportion <- function() {
  cat("\n=== Testing check_extreme_proportion() ===\n")

  # Test 1: Extreme low proportion
  warning_msg <- check_extreme_proportion(0.05)
  stopifnot(grepl("Extreme proportion", warning_msg))
  stopifnot(grepl("0.050", warning_msg))
  cat("✓ Low extreme proportion detected\n")

  # Test 2: Extreme high proportion
  warning_msg <- check_extreme_proportion(0.95)
  stopifnot(grepl("Extreme proportion", warning_msg))
  cat("✓ High extreme proportion detected\n")

  # Test 3: Normal proportion
  warning_msg <- check_extreme_proportion(0.50)
  stopifnot(warning_msg == "")
  cat("✓ No warning for normal proportion\n")

  # Test 4: Boundary case (exactly at threshold)
  warning_msg <- check_extreme_proportion(0.10, threshold = 0.10)
  stopifnot(warning_msg == "")
  cat("✓ Boundary handled correctly\n")

  cat("✓ All check_extreme_proportion() tests passed!\n")
}


# ==============================================================================
# TEST: parse_codes()
# ==============================================================================

test_parse_codes <- function() {
  cat("\n=== Testing parse_codes() ===\n")

  # Test 1: Numeric codes
  result <- parse_codes("1,2,3")
  expected <- c(1, 2, 3)
  stopifnot(all(result == expected))
  stopifnot(is.numeric(result))
  cat("✓ Numeric codes parsed correctly\n")

  # Test 2: Character codes
  result <- parse_codes("A,B,C")
  expected <- c("A", "B", "C")
  stopifnot(all(result == expected))
  stopifnot(is.character(result))
  cat("✓ Character codes parsed correctly\n")

  # Test 3: Codes with spaces
  result <- parse_codes("1, 2, 3")
  expected <- c(1, 2, 3)
  stopifnot(all(result == expected))
  cat("✓ Whitespace trimmed correctly\n")

  # Test 4: Single code
  result <- parse_codes("5")
  expected <- 5
  stopifnot(result == expected)
  cat("✓ Single code handled correctly\n")

  # Test 5: Empty string
  result <- parse_codes("")
  stopifnot(is.null(result))
  cat("✓ Empty string returns NULL\n")

  # Test 6: NA value
  result <- parse_codes(NA)
  stopifnot(is.null(result))
  cat("✓ NA returns NULL\n")

  cat("✓ All parse_codes() tests passed!\n")
}


# ==============================================================================
# TEST: safe_divide()
# ==============================================================================

test_safe_divide <- function() {
  cat("\n=== Testing safe_divide() ===\n")

  # Test 1: Normal division
  result <- safe_divide(10, 2)
  stopifnot(result == 5)
  cat("✓ Normal division works\n")

  # Test 2: Division by zero with NA
  result <- safe_divide(10, 0, na_on_zero = TRUE)
  stopifnot(is.na(result))
  cat("✓ Division by zero returns NA (na_on_zero=TRUE)\n")

  # Test 3: Division by zero with Inf
  result <- safe_divide(10, 0, na_on_zero = FALSE)
  stopifnot(is.infinite(result))
  cat("✓ Division by zero returns Inf (na_on_zero=FALSE)\n")

  # Test 4: Vector operations
  result <- safe_divide(c(10, 20, 30), c(2, 0, 5), na_on_zero = TRUE)
  expected <- c(5, NA, 6)
  stopifnot(result[1] == expected[1])
  stopifnot(is.na(result[2]))
  stopifnot(result[3] == expected[3])
  cat("✓ Vector division works correctly\n")

  cat("✓ All safe_divide() tests passed!\n")
}


# ==============================================================================
# TEST: Module info functions
# ==============================================================================

test_module_info <- function() {
  cat("\n=== Testing module info functions ===\n")

  # Test 1: Version function
  version <- get_confidence_module_version()
  stopifnot(is.character(version))
  stopifnot(nchar(version) > 0)
  cat(sprintf("✓ Module version: %s\n", version))

  # Test 2: Print info (just check it doesn't error)
  print_confidence_module_info()
  cat("✓ Module info printed successfully\n")

  cat("✓ All module info tests passed!\n")
}


# ==============================================================================
# RUN ALL TESTS
# ==============================================================================

run_all_tests <- function() {
  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════╗\n")
  cat("║         CONFIDENCE MODULE - UTILS TEST SUITE             ║\n")
  cat("╚═══════════════════════════════════════════════════════════╝\n")

  test_format_decimal()
  test_format_output_df()
  test_validate_proportion()
  test_validate_sample_size()
  test_validate_conf_level()
  test_validate_decimal_separator()
  test_validate_question_limit()
  test_check_small_sample()
  test_check_extreme_proportion()
  test_parse_codes()
  test_safe_divide()
  test_module_info()

  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════╗\n")
  cat("║              ✓ ALL TESTS PASSED!                         ║\n")
  cat("╚═══════════════════════════════════════════════════════════╝\n")
  cat("\n")
}

# Run tests if this file is executed directly
if (!interactive()) {
  run_all_tests()
}
