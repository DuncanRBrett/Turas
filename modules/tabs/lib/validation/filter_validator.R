# ==============================================================================
# FILTER VALIDATOR MODULE
# ==============================================================================
# Module name: filter_validator
# Purpose: Validation for base filter expressions ensuring safety and correctness
# Extracted from validation.R for better modularity
# VERSION HISTORY: V10.1 - Extracted from validation.R (2025)

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

# Source shared functions
if (!exists("log_issue")) {
  script_dir <- dirname(sys.frame(1)$ofile)
  if (is.null(script_dir) || is.na(script_dir)) script_dir <- getwd()
  source(file.path(dirname(script_dir), "shared_functions.R"), local = FALSE)
}

# ==============================================================================
# BASE FILTER VALIDATION (V9.9.2)
# ==============================================================================

#' Validate base filter expression for safety and correctness
#'
#' CHECKS PERFORMED:
#' - Expression is valid R code
#' - Expression returns logical vector
#' - Vector length matches data
#' - Filter retains at least some rows
#' - No unsafe characters or operations
#'
#' V9.9.2 ENHANCEMENTS:
#' - Allows %in% and : operators (common in filters)
#' - Hardened dangerous patterns (::, :::, get, assign, mget, do.call)
#' - Uses enclos = parent.frame() for safer evaluation
#'
#' DESIGN: Comprehensive security checks before evaluating user-provided code
#'
#' @param filter_expression R expression as string
#' @param survey_data Survey data frame
#' @param question_code Question code for logging (optional)
#' @return List with $valid (logical) and $message (character)
#' @export
#' @examples
#' if (!result$valid) stop(result$message)
validate_base_filter <- function(filter_expression, survey_data, question_code = "") {
  # Input validation
  if (!is.data.frame(survey_data)) {
    return(list(
      valid = FALSE,
      message = "survey_data must be a data frame"
    ))
  }

  if (nrow(survey_data) == 0) {
    return(list(
      valid = FALSE,
      message = "survey_data is empty (0 rows)"
    ))
  }

  # Empty/null filter is valid (no filtering)
  if (is.na(filter_expression) || is.null(filter_expression) || filter_expression == "") {
    return(list(valid = TRUE, message = "No filter"))
  }

  # Must be character
  if (!is.character(filter_expression)) {
    return(list(
      valid = FALSE,
      message = sprintf("Filter must be character string, got: %s", class(filter_expression)[1])
    ))
  }

  # Clean Unicode characters and special quotes
  filter_expression <- tryCatch({
    # Convert to ASCII, replacing non-ASCII with closest match
    cleaned <- iconv(filter_expression, to = "ASCII//TRANSLIT", sub = "")
    if (is.na(cleaned)) filter_expression else cleaned
  }, error = function(e) filter_expression)

  # Replace various Unicode spaces with regular space
  filter_expression <- gsub("[\u00A0\u2000-\u200B\u202F\u205F\u3000]", " ", filter_expression)

  # Replace smart quotes with regular quotes
  filter_expression <- gsub("[\u2018\u2019\u201A\u201B]", "'", filter_expression)
  filter_expression <- gsub("[\u201C\u201D\u201E\u201F]", '"', filter_expression)

  # Trim whitespace
  filter_expression <- trimws(filter_expression)

  # V9.9.2: Check for potentially unsafe characters (NOW INCLUDES % and :)
  # Allow: letters, numbers, underscore, $, ., (), &, |, !, <, >, =, +, -, *, /, ,, quotes, [], space, %, :
  if (grepl("[^A-Za-z0-9_$.()&|!<>= +*/,'\"\\[\\]%:-]", filter_expression)) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Filter contains potentially unsafe characters: '%s'. Use only standard operators and column names.",
        filter_expression
      )
    ))
  }

  # V9.9.2: Enhanced dangerous patterns list
  dangerous_patterns <- c(
    "system\\s*\\(",    # system calls
    "eval\\s*\\(",      # eval (nested)
    "source\\s*\\(",    # sourcing code
    "library\\s*\\(",   # loading packages
    "require\\s*\\(",   # loading packages
    "<-",               # assignment
    "<<-",              # global assignment
    "->",               # right assignment
    "->>",              # right global assignment
    "rm\\s*\\(",        # removing objects
    "file\\.",          # file operations
    "sink\\s*\\(",      # sink
    "options\\s*\\(",   # changing options
    "\\.GlobalEnv",     # accessing global env
    "::",               # namespace access (V9.9.2)
    ":::",              # internal namespace access (V9.9.2)
    "get\\s*\\(",       # get function (V9.9.2)
    "assign\\s*\\(",    # assign function (V9.9.2)
    "mget\\s*\\(",      # mget function (V9.9.2)
    "do\\.call\\s*\\(" # do.call function (V9.9.2)
  )

  for (pattern in dangerous_patterns) {
    if (grepl(pattern, filter_expression, ignore.case = TRUE)) {
      return(list(
        valid = FALSE,
        message = sprintf(
          "Filter contains unsafe pattern: '%s' not allowed",
          gsub("\\\\s\\*\\\\\\(", "(", pattern)
        )
      ))
    }
  }

  # Try to evaluate filter
  tryCatch({
    # V9.9.2: Use enclos = parent.frame() for safer name resolution
    filter_result <- eval(
      parse(text = filter_expression),
      envir = survey_data,
      enclos = parent.frame()
    )

    # Check return type
    if (!is.logical(filter_result)) {
      return(list(
        valid = FALSE,
        message = sprintf(
          "Filter must return logical vector, got: %s. Use logical operators (==, !=, <, >, &, |, %%in%%).",
          class(filter_result)[1]
        )
      ))
    }

    # Check length
    if (length(filter_result) != nrow(survey_data)) {
      return(list(
        valid = FALSE,
        message = sprintf(
          "Filter returned %d values but data has %d rows. Check column names and operations.",
          length(filter_result),
          nrow(survey_data)
        )
      ))
    }

    # Check how many rows retained (excluding NAs)
    n_retained <- sum(filter_result, na.rm = TRUE)
    n_total <- nrow(survey_data)
    pct_retained <- round(100 * n_retained / n_total, 1)

    if (n_retained == 0) {
      return(list(
        valid = FALSE,
        message = sprintf(
          "Filter retains 0 rows (filters out all data). Expression: '%s'",
          filter_expression
        )
      ))
    }

    # Check for too many NAs in filter result
    n_na <- sum(is.na(filter_result))
    pct_na <- round(100 * n_na / n_total, 1)

    message_parts <- c(
      sprintf("Filter OK: %d of %d rows (%.1f%%)", n_retained, n_total, pct_retained)
    )

    if (n_na > 0) {
      message_parts <- c(
        message_parts,
        sprintf("%d NA values (%.1f%%) treated as FALSE", n_na, pct_na)
      )
    }

    return(list(
      valid = TRUE,
      message = paste(message_parts, collapse = "; ")
    ))

  }, error = function(e) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Filter evaluation failed: %s. Check column names and syntax. Expression: '%s'",
        conditionMessage(e),
        filter_expression
      )
    ))
  })
}
