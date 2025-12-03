# Assertion Helper Functions for TURAS Regression Tests
#
# These functions provide simple wrappers around testthat expectations
# for comparing actual module outputs against golden values.
#
# Author: TURAS Development Team
# Version: 1.0
# Date: 2025-12-02

#' Compare numeric value with tolerance
#'
#' Checks if an actual numeric value matches an expected value within
#' a specified tolerance. Uses testthat::expect_equal() internally.
#'
#' @param name Character. Descriptive name for the check
#' @param actual Numeric. Actual value from module output
#' @param expected Numeric. Expected value from golden file
#' @param tolerance Numeric. Acceptable absolute difference (default: 0.01)
#' @return Invisible TRUE if passes, throws error if fails
#' @export
#' @examples
#' check_numeric("Mean satisfaction", actual = 7.42, expected = 7.42, tolerance = 0.01)
check_numeric <- function(name, actual, expected, tolerance = 0.01) {
  if (!requireNamespace("testthat", quietly = TRUE)) {
    stop("Package 'testthat' is required. Install it with: install.packages('testthat')")
  }

  # Handle NA values
  if (is.na(actual) && is.na(expected)) {
    return(invisible(TRUE))
  }

  if (is.na(actual) || is.na(expected)) {
    stop("Value mismatch for '", name, "': ",
         "actual = ", actual, ", expected = ", expected)
  }

  # Perform check
  testthat::expect_equal(
    actual,
    expected,
    tolerance = tolerance,
    label = sprintf("actual (%s)", format(actual, digits = 6)),
    expected.label = sprintf("expected (%s)", format(expected, digits = 6)),
    info = name
  )

  invisible(TRUE)
}

#' Compare logical value (exact match)
#'
#' Checks if an actual logical value exactly matches an expected value.
#' Uses testthat::expect_identical() internally.
#'
#' @param name Character. Descriptive name for the check
#' @param actual Logical. Actual value from module output
#' @param expected Logical. Expected value from golden file
#' @return Invisible TRUE if passes, throws error if fails
#' @export
#' @examples
#' check_logical("Significance flag", actual = TRUE, expected = TRUE)
check_logical <- function(name, actual, expected) {
  if (!requireNamespace("testthat", quietly = TRUE)) {
    stop("Package 'testthat' is required. Install it with: install.packages('testthat')")
  }

  # Handle NA values
  if (is.na(actual) && is.na(expected)) {
    return(invisible(TRUE))
  }

  # Perform check
  testthat::expect_identical(
    actual,
    expected,
    label = sprintf("actual (%s)", as.character(actual)),
    expected.label = sprintf("expected (%s)", as.character(expected)),
    info = name
  )

  invisible(TRUE)
}

#' Compare integer value (exact match)
#'
#' Checks if an actual integer value exactly matches an expected value.
#' Coerces both values to integer before comparison.
#'
#' @param name Character. Descriptive name for the check
#' @param actual Numeric/Integer. Actual value from module output
#' @param expected Numeric/Integer. Expected value from golden file
#' @return Invisible TRUE if passes, throws error if fails
#' @export
#' @examples
#' check_integer("Base size", actual = 50, expected = 50)
check_integer <- function(name, actual, expected) {
  if (!requireNamespace("testthat", quietly = TRUE)) {
    stop("Package 'testthat' is required. Install it with: install.packages('testthat')")
  }

  # Handle NA values
  if (is.na(actual) && is.na(expected)) {
    return(invisible(TRUE))
  }

  # Coerce to integer
  actual_int <- as.integer(round(actual))
  expected_int <- as.integer(round(expected))

  # Perform check
  testthat::expect_equal(
    actual_int,
    expected_int,
    label = sprintf("actual (%d)", actual_int),
    expected.label = sprintf("expected (%d)", expected_int),
    info = name
  )

  invisible(TRUE)
}

#' Compare character/string value (exact match)
#'
#' Checks if an actual character value exactly matches an expected value.
#' Case-sensitive comparison.
#'
#' @param name Character. Descriptive name for the check
#' @param actual Character. Actual value from module output
#' @param expected Character. Expected value from golden file
#' @return Invisible TRUE if passes, throws error if fails
#' @export
#' @examples
#' check_string("Output format", actual = "Excel", expected = "Excel")
check_string <- function(name, actual, expected) {
  if (!requireNamespace("testthat", quietly = TRUE)) {
    stop("Package 'testthat' is required. Install it with: install.packages('testthat')")
  }

  # Perform check
  testthat::expect_identical(
    as.character(actual),
    as.character(expected),
    label = sprintf("actual ('%s')", actual),
    expected.label = sprintf("expected ('%s')", expected),
    info = name
  )

  invisible(TRUE)
}

#' Run all checks from a golden values structure
#'
#' Iterates through all checks in a golden values list and executes
#' the appropriate comparison function based on the check type.
#'
#' @param checks List. List of check specifications from golden file
#' @param extractor Function. Function that extracts values from output
#'   Should accept (output, check_name) and return the actual value
#' @param output Any. The module output object to extract values from
#' @return Invisible TRUE if all pass, throws error on first failure
#' @export
#' @examples
#' run_all_checks(golden$checks, extract_tabs_value, tabs_output)
run_all_checks <- function(checks, extractor, output) {
  if (!is.list(checks) || length(checks) == 0) {
    stop("Checks must be a non-empty list")
  }

  for (check in checks) {
    # Validate check structure
    if (is.null(check$name) || is.null(check$type) || is.null(check$value)) {
      stop("Invalid check structure. Each check must have 'name', 'type', and 'value'.")
    }

    # Extract actual value
    actual <- extractor(output, check$name)

    # Run appropriate comparison
    if (check$type == "numeric") {
      tolerance <- if (!is.null(check$tolerance)) check$tolerance else 0.01
      check_numeric(check$description, actual, check$value, tolerance)
    } else if (check$type == "logical") {
      check_logical(check$description, actual, check$value)
    } else if (check$type == "integer") {
      check_integer(check$description, actual, check$value)
    } else if (check$type == "character" || check$type == "string") {
      check_string(check$description, actual, check$value)
    } else {
      stop("Unknown check type: ", check$type, " for check: ", check$name)
    }
  }

  invisible(TRUE)
}
