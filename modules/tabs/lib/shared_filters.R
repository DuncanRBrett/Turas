# ==============================================================================
# SHARED FILTER FUNCTIONS - TURAS V10.0
# ==============================================================================
# Extracted from shared_functions.R for better maintainability
# Provides filter expression handling and application
#
# CONTENTS:
# - Clean filter expressions (Unicode handling)
# - Security validation (prevent code injection)
# - Filter result validation
# - Apply filters with row tracking
#
# SECURITY NOTES:
# - Validates expressions before evaluation
# - Blocks dangerous patterns (system(), eval(), etc.)
# - Sanitizes Unicode and special characters
# - Uses isolated evaluation environment
# ==============================================================================

#' Clean Unicode and special characters from filter expression
#' @keywords internal
clean_filter_expression <- function(filter_expression) {
  # Clean Unicode and special characters
  filter_expression <- tryCatch({
    cleaned <- iconv(filter_expression, to = "ASCII//TRANSLIT", sub = "")
    if (is.na(cleaned)) filter_expression else cleaned
  }, error = function(e) filter_expression)

  # Replace Unicode spaces and quotes
  filter_expression <- gsub("[\u00A0\u2000-\u200B\u202F\u205F\u3000]", " ", filter_expression)
  filter_expression <- gsub("[\u2018\u2019\u201A\u201B]", "'", filter_expression)
  filter_expression <- gsub("[\u201C\u201D\u201E\u201F]", '"', filter_expression)
  filter_expression <- trimws(filter_expression)

  return(filter_expression)
}

#' Check filter expression for dangerous patterns
#' @keywords internal
check_filter_security <- function(filter_expression) {
  # Security: Check for dangerous characters
  if (grepl("[^A-Za-z0-9_$.()&|!<>= +*/,'\"\\[\\]%:-]", filter_expression)) {
    tabs_refuse(
      code = "ARG_UNSAFE_FILTER",
      title = "Unsafe Filter Characters",
      problem = sprintf("Filter contains potentially unsafe characters: '%s'", filter_expression),
      why_it_matters = "Filter expressions are evaluated as code and must be sanitized to prevent code injection.",
      how_to_fix = "Use only standard R operators and alphanumeric characters in your filter expression."
    )
  }

  # Check for dangerous patterns
  dangerous_patterns <- c(
    "system\\s*\\(", "eval\\s*\\(", "source\\s*\\(", "library\\s*\\(",
    "require\\s*\\(", "<-", "<<-", "->", "->>", "rm\\s*\\(",
    "file\\.", "sink\\s*\\(", "options\\s*\\(", "\\.GlobalEnv",
    "::", ":::", "get\\s*\\(", "assign\\s*\\(", "mget\\s*\\(", "do\\.call\\s*\\("
  )

  for (pattern in dangerous_patterns) {
    if (grepl(pattern, filter_expression, ignore.case = TRUE)) {
      tabs_refuse(
        code = "ARG_DANGEROUS_FILTER",
        title = "Dangerous Filter Pattern",
        problem = sprintf("Filter contains unsafe pattern: '%s' not allowed", gsub("\\\\s\\*\\\\\\(", "(", pattern)),
        why_it_matters = "This pattern could execute arbitrary code and poses a security risk.",
        how_to_fix = "Use only simple data filtering expressions (e.g., 'Age >= 18', 'Region == \"North\"')."
      )
    }
  }

  return(invisible(NULL))
}

#' Validate filter evaluation result
#' @keywords internal
validate_filter_result <- function(filter_result, data, filter_expression) {
  # Check return type
  if (!is.logical(filter_result)) {
    tabs_refuse(
      code = "DATA_INVALID_FILTER_RESULT",
      title = "Invalid Filter Result Type",
      problem = sprintf("Filter must return logical vector, got: %s", class(filter_result)[1]),
      why_it_matters = "Filter expressions must evaluate to TRUE/FALSE for each row to determine inclusion.",
      how_to_fix = "Ensure your filter expression uses comparison operators (==, !=, <, >, <=, >=, &, |) that return logical values."
    )
  }

  # Check length
  if (length(filter_result) != nrow(data)) {
    tabs_refuse(
      code = "DATA_FILTER_LENGTH_MISMATCH",
      title = "Filter Length Mismatch",
      problem = sprintf("Filter returned %d values but data has %d rows", length(filter_result), nrow(data)),
      why_it_matters = "Filter must evaluate to one TRUE/FALSE value per data row for proper subsetting.",
      how_to_fix = "Check that your filter expression references column names correctly and doesn't use aggregation functions."
    )
  }

  # Replace NAs with FALSE
  filter_result[is.na(filter_result)] <- FALSE

  # Check if any rows retained
  n_retained <- sum(filter_result)
  if (n_retained == 0) {
    warning(sprintf(
      "Filter retains 0 rows (filters out all data): '%s'",
      filter_expression
    ), call. = FALSE)
  }

  return(filter_result)
}

#' Apply base filter to survey data
#'
#' USAGE: Filter data for specific question analysis
#' DESIGN: Returns filtered data with .original_row tracking
#' SECURITY: Uses same validation as validate_base_filter()
#'
#' @param data Data frame, survey data
#' @param filter_expression Character, R expression for filtering
#' @return Data frame, filtered subset with .original_row column
#' @export
#' @examples
#' # Filter to adults only
#' filtered <- apply_base_filter(survey_data, "Age >= 18")
#'
#' # Filter with multiple conditions
#' filtered <- apply_base_filter(survey_data, "Age >= 18 & Region == 'North'")
apply_base_filter <- function(data, filter_expression) {
  # Validate inputs
  if (!is.data.frame(data) || nrow(data) == 0) {
    tabs_refuse(
      code = "ARG_INVALID_DATA",
      title = "Invalid Data Argument",
      problem = "data must be a non-empty data frame",
      why_it_matters = "Filter operations require valid data to process.",
      how_to_fix = "Ensure you pass a non-empty data frame to apply_base_filter()."
    )
  }

  # Empty/null filter = return all data with row indices
  if (is.null(filter_expression) || is.na(filter_expression) ||
      trimws(filter_expression) == "") {
    data$.original_row <- seq_len(nrow(data))
    return(data)
  }

  # Validate filter is safe
  if (!is.character(filter_expression) || length(filter_expression) != 1) {
    tabs_refuse(
      code = "ARG_INVALID_FILTER_TYPE",
      title = "Invalid Filter Expression Type",
      problem = "filter_expression must be a single character string",
      why_it_matters = "Filter expressions must be text strings containing R code to evaluate.",
      how_to_fix = "Pass a single character string (e.g., 'Age >= 18') not a vector or other type."
    )
  }

  # Clean and validate filter expression (delegated to helpers)
  filter_expression <- clean_filter_expression(filter_expression)
  check_filter_security(filter_expression)

  # Apply filter
  tryCatch({
    # Evaluate filter expression
    filter_result <- eval(
      parse(text = filter_expression),
      envir = data,
      enclos = parent.frame()
    )

    # Validate and clean result (delegated to helper)
    filter_result <- validate_filter_result(filter_result, data, filter_expression)

    # Create filtered dataset with original row tracking
    original_rows <- which(filter_result)
    filtered_data <- data[filter_result, , drop = FALSE]
    filtered_data$.original_row <- original_rows

    return(filtered_data)

  }, error = function(e) {
    tabs_refuse(
      code = "DATA_FILTER_EVAL_FAILED",
      title = "Filter Evaluation Failed",
      problem = sprintf("Filter evaluation failed: %s", conditionMessage(e)),
      why_it_matters = "The filter expression could not be evaluated against the data.",
      how_to_fix = sprintf("Expression: '%s'. Check that column names exist in the data and syntax is valid R code.", filter_expression)
    )
  })
}

# ==============================================================================
# END OF SHARED_FILTERS.R
# ==============================================================================
