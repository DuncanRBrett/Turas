# ==============================================================================
# MAXDIFF MODULE - UTILITY FUNCTIONS - TURAS V10.1
# ==============================================================================
# Common utility functions for MaxDiff analysis
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.1 - Uses consolidated shared utilities (2025-12)
# Turas v10.0 - Initial release (2025-12)
#
# SHARED UTILITIES: Core functions available from /modules/shared/lib/
# Local versions retained for backward compatibility.
# ==============================================================================

MAXDIFF_UTILS_VERSION <- "10.1"

# Load shared utilities if available
if (!exists("safe_numeric", mode = "function")) {
  .maxdiff_utils_dir <- tryCatch({
    dirname(sys.frame(1)$ofile)
  }, error = function(e) getwd())

  .shared_lib_path <- file.path(dirname(dirname(.maxdiff_utils_dir)), "shared", "lib")
  if (!dir.exists(.shared_lib_path)) {
    .shared_lib_path <- file.path(getwd(), "modules", "shared", "lib")
  }

  if (dir.exists(.shared_lib_path) && file.exists(file.path(.shared_lib_path, "data_utils.R"))) {
    source(file.path(.shared_lib_path, "data_utils.R"), local = FALSE)
    source(file.path(.shared_lib_path, "logging_utils.R"), local = FALSE)
  }

  if (exists(".maxdiff_utils_dir")) rm(.maxdiff_utils_dir)
  if (exists(".shared_lib_path")) rm(.shared_lib_path)
}

# ==============================================================================
# SAFE VALUE CHECKING (handles vectors)
# ==============================================================================

#' Safely check if value is missing (NULL, empty, or scalar NA)
#'
#' This function safely handles vectors, avoiding the
#' "length > 1 in coercion to logical(1)" error.
#'
#' @param x Value to check
#' @return Logical. TRUE if x is NULL, length 0, or a single NA value
#' @keywords internal
is_missing_value <- function(x) {
  is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x[1]))
}

#' Safely check if scalar value is NA (handles vectors)
#'
#' @param x Value to check
#' @return Logical. TRUE if x is scalar NA
#' @keywords internal
is_scalar_na <- function(x) {
  length(x) == 1 && is.na(x[1])
}

# ==============================================================================
# LOGGING AND PROGRESS
# ==============================================================================

#' Log message with timestamp
#'
#' @param message Character. Message to log
#' @param level Character. Log level: INFO, WARN, ERROR
#' @param verbose Logical. Print message if TRUE
#'
#' @keywords internal
log_message <- function(message, level = "INFO", verbose = TRUE) {
  if (!verbose) return(invisible(NULL))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  prefix <- switch(level,
    "INFO" = "  ",
    "WARN" = "  [WARNING] ",
    "ERROR" = "  [ERROR] ",
    "  "
  )

  cat(sprintf("%s%s\n", prefix, message))
  invisible(NULL)
}


#' Log progress with percentage
#'
#' @param current Integer. Current item number
#' @param total Integer. Total items
#' @param message Character. Context message
#' @param verbose Logical. Print if TRUE
#'
#' @keywords internal
log_progress <- function(current, total, message = "Progress", verbose = TRUE) {
  if (!verbose) return(invisible(NULL))

  pct <- round((current / total) * 100)
  cat(sprintf("  %s: %d/%d (%.0f%%)\n", message, current, total, pct))
  invisible(NULL)
}


# ==============================================================================
# VALIDATION UTILITIES
# ==============================================================================

#' Validate that a value is in allowed set
#'
#' @param value Value to check
#' @param allowed Character vector of allowed values
#' @param param_name Character. Parameter name for error message
#' @param case_sensitive Logical. Case-sensitive comparison
#'
#' @return The validated value (possibly transformed)
#' @keywords internal
validate_option <- function(value, allowed, param_name, case_sensitive = FALSE) {
  if (is_missing_value(value)) {
    maxdiff_refuse(
      code = "CFG_PARAMETER_MISSING",
      title = "Required Parameter Missing",
      problem = sprintf("Parameter '%s' is required but was NULL or NA", param_name),
      why_it_matters = "Configuration parameter is required for analysis",
      how_to_fix = sprintf("Provide a value for %s in configuration", param_name)
    )
  }
  # Take first element if vector
  if (length(value) > 1) value <- value[1]

  check_value <- if (case_sensitive) value else toupper(value)
  check_allowed <- if (case_sensitive) allowed else toupper(allowed)

  if (!check_value %in% check_allowed) {
    maxdiff_refuse(
      code = "CFG_INVALID_OPTION",
      title = "Invalid Configuration Option",
      problem = sprintf("Invalid value for %s: '%s'", param_name, value),
      why_it_matters = "Parameter must be one of the allowed values",
      how_to_fix = sprintf("Use one of the allowed values: %s", paste(allowed, collapse = ", ")),
      expected = paste(allowed, collapse = ", "),
      observed = value
    )
  }

  return(value)
}


#' Validate numeric value is within range
#'
#' @param value Numeric value to check
#' @param param_name Character. Parameter name
#' @param min_val Numeric. Minimum value (inclusive)
#' @param max_val Numeric. Maximum value (inclusive)
#' @param allow_na Logical. Allow NA values
#'
#' @return The validated value
#' @keywords internal
validate_numeric_range <- function(value, param_name,
                                   min_val = -Inf, max_val = Inf,
                                   allow_na = FALSE) {
  if (is.null(value) || length(value) == 0) {
    maxdiff_refuse(
      code = "CFG_PARAMETER_MISSING",
      title = "Required Parameter Missing",
      problem = sprintf("Parameter '%s' is required but was NULL", param_name),
      why_it_matters = "Numeric parameter is required for configuration",
      how_to_fix = sprintf("Provide a numeric value for %s", param_name)
    )
  }

  # Take first element if vector
  if (length(value) > 1) value <- value[1]

  if (is.na(value)) {
    if (allow_na) return(value)
    maxdiff_refuse(
      code = "CFG_PARAMETER_NA",
      title = "Parameter is NA",
      problem = sprintf("Parameter '%s' is required but was NA", param_name),
      why_it_matters = "Valid numeric value is required",
      how_to_fix = sprintf("Provide a non-NA value for %s", param_name)
    )
  }

  if (!is.numeric(value)) {
    maxdiff_refuse(
      code = "CFG_PARAMETER_WRONG_TYPE",
      title = "Invalid Parameter Type",
      problem = sprintf("Parameter '%s' must be numeric, got: %s", param_name, class(value)),
      why_it_matters = "Numeric type is required for this parameter",
      how_to_fix = sprintf("Provide a numeric value for %s", param_name),
      expected = "numeric",
      observed = class(value)
    )
  }

  if (value < min_val || value > max_val) {
    maxdiff_refuse(
      code = "CFG_PARAMETER_OUT_OF_RANGE",
      title = "Parameter Out of Range",
      problem = sprintf("Parameter '%s' = %s is outside valid range", param_name, value),
      why_it_matters = "Parameter must be within specified bounds",
      how_to_fix = sprintf("Set %s between %s and %s", param_name, min_val, max_val),
      expected = sprintf("[%s, %s]", min_val, max_val),
      observed = sprintf("%s", value)
    )
  }

  return(value)
}


#' Validate positive integer
#'
#' @param value Value to check
#' @param param_name Character. Parameter name
#' @param min_val Integer. Minimum value (default: 1)
#'
#' @return Integer value
#' @keywords internal
validate_positive_integer <- function(value, param_name, min_val = 1) {
  if (is_missing_value(value)) {
    maxdiff_refuse(
      code = "CFG_PARAMETER_MISSING",
      title = "Required Parameter Missing",
      problem = sprintf("Parameter '%s' is required but was NULL or NA", param_name),
      why_it_matters = "Integer parameter is required for configuration",
      how_to_fix = sprintf("Provide an integer value for %s", param_name)
    )
  }

  # Take first element if vector
  if (length(value) > 1) value <- value[1]

  value <- suppressWarnings(as.integer(value))

  if (is.na(value)) {
    maxdiff_refuse(
      code = "CFG_PARAMETER_NOT_INTEGER",
      title = "Parameter Not an Integer",
      problem = sprintf("Parameter '%s' must be an integer", param_name),
      why_it_matters = "Integer type is required for this parameter",
      how_to_fix = sprintf("Provide a valid integer value for %s", param_name)
    )
  }

  if (value < min_val) {
    maxdiff_refuse(
      code = "CFG_PARAMETER_TOO_SMALL",
      title = "Parameter Value Too Small",
      problem = sprintf("Parameter '%s' = %d is below minimum allowed", param_name, value),
      why_it_matters = sprintf("Parameter must be >= %d", min_val),
      how_to_fix = sprintf("Set %s to at least %d", param_name, min_val),
      expected = sprintf(">= %d", min_val),
      observed = sprintf("%d", value)
    )
  }

  return(value)
}


#' Validate file path exists
#'
#' @param path Character. File path
#' @param param_name Character. Parameter name for error message
#' @param must_exist Logical. File must exist
#' @param extensions Character vector. Allowed file extensions (e.g., c("xlsx", "csv"))
#'
#' @return Normalized file path
#' @keywords internal
validate_file_path <- function(path, param_name, must_exist = TRUE, extensions = NULL) {
  if (is.null(path) || length(path) == 0) {
    maxdiff_refuse(
      code = "CFG_PATH_MISSING",
      title = "File Path Missing",
      problem = sprintf("Parameter '%s' is required but was empty or NA", param_name),
      why_it_matters = "File path is required to locate input/output files",
      how_to_fix = sprintf("Provide a valid file path for %s", param_name)
    )
  }

  # Take first element if vector
  if (length(path) > 1) path <- path[1]

  if (is.na(path) || !nzchar(trimws(path))) {
    maxdiff_refuse(
      code = "CFG_PATH_EMPTY",
      title = "Empty File Path",
      problem = sprintf("Parameter '%s' is required but was empty or NA", param_name),
      why_it_matters = "Valid file path is required",
      how_to_fix = sprintf("Provide a non-empty file path for %s", param_name)
    )
  }

  path <- normalizePath(path, mustWork = FALSE)

  if (must_exist && !file.exists(path)) {
    maxdiff_refuse(
      code = "IO_FILE_NOT_FOUND",
      title = "File Not Found",
      problem = sprintf("File not found for %s", param_name),
      why_it_matters = "Required file must exist to proceed",
      how_to_fix = c(
        "Check file path is correct",
        "Verify file exists at specified location",
        "Check for typos in file name or path"
      ),
      details = sprintf("Path: %s", path)
    )
  }

  if (!is.null(extensions)) {
    ext <- tolower(tools::file_ext(path))
    if (!ext %in% tolower(extensions)) {
      maxdiff_refuse(
        code = "IO_INVALID_FILE_EXTENSION",
        title = "Invalid File Extension",
        problem = sprintf("File '%s' has wrong extension", basename(path)),
        why_it_matters = "File must have correct extension for its type",
        how_to_fix = sprintf("Use file with extension: %s", paste(extensions, collapse = ", ")),
        expected = paste(extensions, collapse = ", "),
        observed = ext,
        details = sprintf("Path: %s", path)
      )
    }
  }

  return(path)
}


#' Validate directory path exists
#'
#' @param path Character. Directory path
#' @param param_name Character. Parameter name
#' @param create Logical. Create directory if it doesn't exist
#'
#' @return Normalized directory path
#' @keywords internal
validate_directory_path <- function(path, param_name, create = TRUE) {
  if (is.null(path) || length(path) == 0) {
    maxdiff_refuse(
      code = "CFG_PATH_MISSING",
      title = "Directory Path Missing",
      problem = sprintf("Parameter '%s' is required but was empty or NA", param_name),
      why_it_matters = "Directory path is required for output location",
      how_to_fix = sprintf("Provide a valid directory path for %s", param_name)
    )
  }

  # Take first element if vector
  if (length(path) > 1) path <- path[1]

  if (is.na(path) || !nzchar(trimws(path))) {
    maxdiff_refuse(
      code = "CFG_PATH_EMPTY",
      title = "Empty Directory Path",
      problem = sprintf("Parameter '%s' is required but was empty or NA", param_name),
      why_it_matters = "Valid directory path is required",
      how_to_fix = sprintf("Provide a non-empty directory path for %s", param_name)
    )
  }

  path <- normalizePath(path, mustWork = FALSE)

  if (!dir.exists(path)) {
    if (create) {
      tryCatch({
        dir.create(path, recursive = TRUE)
      }, error = function(e) {
        maxdiff_refuse(
          code = "IO_DIRECTORY_CREATE_FAILED",
          title = "Failed to Create Directory",
          problem = sprintf("Cannot create directory for %s: %s", param_name, conditionMessage(e)),
          why_it_matters = "Output directory must be created to save results",
          how_to_fix = c(
            "Check write permissions for parent directory",
            "Verify path is valid and accessible",
            "Ensure no file exists with same name as directory"
          ),
          details = sprintf("Path: %s\nError: %s", path, conditionMessage(e))
        )
      })
    } else {
      maxdiff_refuse(
        code = "IO_DIRECTORY_NOT_FOUND",
        title = "Directory Not Found",
        problem = sprintf("Directory not found for %s", param_name),
        why_it_matters = "Required directory must exist",
        how_to_fix = c(
          "Check directory path is correct",
          "Create directory manually",
          "Enable automatic directory creation"
        ),
        details = sprintf("Path: %s", path)
      )
    }
  }

  return(path)
}


# ==============================================================================
# STRING UTILITIES
# ==============================================================================

#' Parse yes/no string to logical
#'
#' @param value Character or logical value
#' @param default Logical. Default if parsing fails
#'
#' @return Logical value
#' @keywords internal
parse_yes_no <- function(value, default = FALSE) {
  if (is_missing_value(value)) return(default)
  # Take first element if vector
  if (length(value) > 1) value <- value[1]
  if (is.logical(value)) return(value)

  value_upper <- toupper(trimws(as.character(value)))

  if (value_upper %in% c("Y", "YES", "TRUE", "1", "T")) return(TRUE)
  if (value_upper %in% c("N", "NO", "FALSE", "0", "F")) return(FALSE)

  return(default)
}


#' Safe conversion to numeric with default
#'
#' @param value Value to convert
#' @param default Default if conversion fails
#'
#' @return Numeric value or default
#' @keywords internal
safe_numeric <- function(value, default = NA_real_) {
  if (is.null(value) || length(value) == 0) return(default)
  # Take first element if vector
  if (length(value) > 1) value <- value[1]
  if (is.na(value)) return(default)

  result <- suppressWarnings(as.numeric(value))

  if (is.na(result)) return(default)
  return(result)
}


#' Safe conversion to integer with default
#'
#' @param value Value to convert
#' @param default Default if conversion fails
#'
#' @return Integer value or default
#' @keywords internal
safe_integer <- function(value, default = NA_integer_) {
  # Handle NULL or empty
  if (is.null(value) || length(value) == 0) {
    return(as.integer(default))
  }

  # Handle NA (check first element if vector)
  if (length(value) == 1 && is.na(value[1])) {
    return(as.integer(default))
  }

  # Try conversion
  result <- suppressWarnings(as.integer(value))

  # Handle conversion failure
  if (length(result) == 0 || is.na(result[1])) {
    return(as.integer(default))
  }

  return(result)
}


#' Clean and normalize Item_ID
#'
#' @param item_id Character. Item ID to clean
#'
#' @return Cleaned item ID
#' @keywords internal
clean_item_id <- function(item_id) {
  if (is_missing_value(item_id)) return(NA_character_)
  # Take first element if vector
  if (length(item_id) > 1) item_id <- item_id[1]

  # Remove leading/trailing whitespace
  cleaned <- trimws(as.character(item_id))

  # Return empty as NA
  if (!nzchar(cleaned)) return(NA_character_)

  return(cleaned)
}


# ==============================================================================
# DATA FRAME UTILITIES
# ==============================================================================

#' Get column value safely with default
#'
#' @param df Data frame
#' @param col_name Character. Column name
#' @param row_idx Integer. Row index (default: 1)
#' @param default Default value if not found
#'
#' @return Value or default
#' @keywords internal
get_col_value <- function(df, col_name, row_idx = 1, default = NA) {
  if (!col_name %in% names(df)) return(default)
  if (row_idx > nrow(df)) return(default)

  value <- df[[col_name]][row_idx]

  if (is_missing_value(value)) return(default)
  return(value)
}


#' Check if column exists and has non-NA values
#'
#' @param df Data frame
#' @param col_name Character. Column name
#'
#' @return Logical
#' @keywords internal
has_valid_column <- function(df, col_name) {
  if (!col_name %in% names(df)) return(FALSE)
  if (all(is.na(df[[col_name]]))) return(FALSE)
  return(TRUE)
}


# ==============================================================================
# MAXDIFF-SPECIFIC UTILITIES
# ==============================================================================

#' Create unique task identifier
#'
#' @param version Integer. Design version
#' @param task Integer. Task number
#'
#' @return Character. Task identifier
#' @keywords internal
make_task_id <- function(version, task) {
  sprintf("V%d_T%d", version, task)
}


#' Parse task identifier
#'
#' @param task_id Character. Task identifier (e.g., "V1_T3")
#'
#' @return Named list with version and task numbers
#' @keywords internal
parse_task_id <- function(task_id) {
  parts <- regmatches(task_id, regexec("^V(\\d+)_T(\\d+)$", task_id))[[1]]

  if (length(parts) != 3) {
    return(list(version = NA_integer_, task = NA_integer_))
  }

  list(
    version = as.integer(parts[2]),
    task = as.integer(parts[3])
  )
}


#' Calculate effective sample size from weights (Kish formula)
#'
#' @param weights Numeric vector of weights
#'
#' @return Numeric. Effective sample size
#' @keywords internal
calculate_effective_n <- function(weights) {
  if (is.null(weights) || length(weights) == 0) return(0)

  weights <- weights[!is.na(weights) & weights > 0]

  if (length(weights) == 0) return(0)

  sum_w <- sum(weights)
  sum_w2 <- sum(weights^2)

  if (sum_w2 == 0) return(0)

  return((sum_w^2) / sum_w2)
}


#' Calculate design effect from weights
#'
#' @param weights Numeric vector of weights
#'
#' @return Numeric. Design effect
#' @keywords internal
calculate_deff <- function(weights) {
  if (is.null(weights) || length(weights) == 0) return(1)

  weights <- weights[!is.na(weights) & weights > 0]

  if (length(weights) == 0) return(1)

  n <- length(weights)
  eff_n <- calculate_effective_n(weights)

  if (eff_n == 0) return(NA_real_)

  return(n / eff_n)
}


#' Rescale utilities to specified scale
#'
#' @param utilities Numeric vector of raw utilities
#' @param method Character. Rescaling method: "RAW", "0_100", or "PROBABILITY"
#'
#' @return Numeric vector of rescaled utilities
#' @keywords internal
rescale_utilities <- function(utilities, method = "0_100") {
  if (length(utilities) == 0) return(numeric(0))

  method <- toupper(method)

  if (method == "RAW") {
    return(utilities)
  }

  if (method == "0_100") {
    min_u <- min(utilities, na.rm = TRUE)
    max_u <- max(utilities, na.rm = TRUE)

    if (max_u == min_u) {
      return(rep(50, length(utilities)))
    }

    return(100 * (utilities - min_u) / (max_u - min_u))
  }

  if (method == "PROBABILITY") {
    # Softmax transformation
    exp_u <- exp(utilities - max(utilities, na.rm = TRUE))  # Subtract max for numerical stability
    return(100 * exp_u / sum(exp_u, na.rm = TRUE))
  }

  message(sprintf("[TRS INFO] MAXD_UNKNOWN_RESCALE: Unknown rescale method: %s - using RAW", method))
  return(utilities)
}


#' Rank utilities (1 = highest utility)
#'
#' @param utilities Numeric vector of utilities
#'
#' @return Integer vector of ranks
#' @keywords internal
rank_utilities <- function(utilities) {
  if (length(utilities) == 0) return(integer(0))

  # Higher utility = lower rank (rank 1 = best)
  rank(-utilities, ties.method = "min", na.last = "keep")
}


# ==============================================================================
# PREFERENCE SHARE CALCULATION
# ==============================================================================

#' Convert utilities to preference shares (MNL-based)
#'
#' Converts individual-level HB utilities to preference shares that sum
#' to 100%. Uses the multinomial logit (MNL) share formula:
#'   share_i = exp(U_i) / sum(exp(U_j))
#' Applied at individual level and then averaged.
#'
#' @param individual_utils Matrix or data frame. Rows = respondents, cols = items.
#' @param aggregate_utils Named numeric vector. Aggregate utilities (used if no
#'   individual utils available). Falls back to softmax on these.
#'
#' @return Named numeric vector of preference shares (sum to 100)
#'
#' @export
compute_preference_shares <- function(individual_utils = NULL, aggregate_utils = NULL) {

  if (!is.null(individual_utils) && nrow(individual_utils) > 0) {
    utils_mat <- as.matrix(individual_utils)
    n_resp <- nrow(utils_mat)
    n_items <- ncol(utils_mat)

    # Compute shares per respondent (softmax), then average
    shares_mat <- matrix(0, nrow = n_resp, ncol = n_items)
    for (i in seq_len(n_resp)) {
      row_utils <- utils_mat[i, ]
      # Subtract max for numerical stability
      exp_u <- exp(row_utils - max(row_utils, na.rm = TRUE))
      shares_mat[i, ] <- exp_u / sum(exp_u, na.rm = TRUE)
    }

    avg_shares <- colMeans(shares_mat, na.rm = TRUE) * 100
    names(avg_shares) <- colnames(utils_mat)
    return(avg_shares)
  }

  if (!is.null(aggregate_utils) && length(aggregate_utils) > 0) {
    # Softmax on aggregate utilities
    exp_u <- exp(aggregate_utils - max(aggregate_utils, na.rm = TRUE))
    shares <- (exp_u / sum(exp_u, na.rm = TRUE)) * 100
    names(shares) <- names(aggregate_utils)
    return(shares)
  }

  return(numeric(0))
}


#' Compute head-to-head choice probability
#'
#' Given two items, computes the probability that a respondent would
#' choose item A over item B using individual-level MNL shares.
#'
#' @param individual_utils Matrix or data frame of individual utilities
#' @param item_a Character. Item_ID for item A
#' @param item_b Character. Item_ID for item B
#'
#' @return List with prob_a, prob_b (percentages summing to 100)
#'
#' @export
compute_head_to_head <- function(individual_utils, item_a, item_b) {

  if (is.null(individual_utils) || nrow(individual_utils) == 0) {
    return(list(prob_a = 50, prob_b = 50))
  }

  utils_mat <- as.matrix(individual_utils)
  col_names <- colnames(utils_mat)

  idx_a <- match(item_a, col_names)
  idx_b <- match(item_b, col_names)

  if (is.na(idx_a) || is.na(idx_b)) {
    return(list(prob_a = 50, prob_b = 50))
  }

  # For each respondent: P(A) = exp(U_A) / (exp(U_A) + exp(U_B))
  diff <- utils_mat[, idx_a] - utils_mat[, idx_b]
  prob_a_per_resp <- 1 / (1 + exp(-diff))  # logistic function
  avg_prob_a <- mean(prob_a_per_resp, na.rm = TRUE)

  list(
    prob_a = round(avg_prob_a * 100, 1),
    prob_b = round((1 - avg_prob_a) * 100, 1)
  )
}


# ==============================================================================
# ITEM DISCRIMINATION ANALYSIS
# ==============================================================================

#' Classify items by discrimination (consensus vs polarizing)
#'
#' Analyzes variance of individual-level HB utilities to identify:
#' - Universal favorites: high mean, low variance (everyone likes it)
#' - Universal rejects: low mean, low variance (everyone dislikes it)
#' - Polarizing: high variance (love-it-or-hate-it)
#' - Moderate: everything else
#'
#' @param individual_utils Matrix or data frame. Rows = respondents, cols = items.
#' @param items Data frame with Item_ID and Item_Label
#'
#' @return Data frame with Item_ID, Item_Label, Mean_Utility, SD_Utility,
#'   CV_Utility, Classification, Classification_Label
#'
#' @export
classify_item_discrimination <- function(individual_utils, items = NULL) {

  if (is.null(individual_utils) || nrow(individual_utils) == 0) {
    return(data.frame(
      Item_ID = character(0), Item_Label = character(0),
      Mean_Utility = numeric(0), SD_Utility = numeric(0),
      Classification = character(0), stringsAsFactors = FALSE
    ))
  }

  utils_mat <- as.matrix(individual_utils)
  item_ids <- colnames(utils_mat)

  # Compute per-item statistics
  means <- colMeans(utils_mat, na.rm = TRUE)
  sds <- apply(utils_mat, 2, sd, na.rm = TRUE)

  # Thresholds: median splits on mean and SD across items
  median_mean <- median(means, na.rm = TRUE)
  median_sd <- median(sds, na.rm = TRUE)

  # Classify
  classification <- character(length(item_ids))
  label <- character(length(item_ids))

  for (j in seq_along(item_ids)) {
    high_mean <- means[j] > median_mean
    high_sd <- sds[j] > median_sd

    if (high_mean && !high_sd) {
      classification[j] <- "UNIVERSAL_FAVORITE"
      label[j] <- "Universal Favorite"
    } else if (!high_mean && !high_sd) {
      classification[j] <- "UNIVERSAL_REJECT"
      label[j] <- "Low Priority"
    } else if (high_sd) {
      classification[j] <- "POLARIZING"
      label[j] <- "Polarizing"
    } else {
      classification[j] <- "MODERATE"
      label[j] <- "Moderate"
    }
  }

  result <- data.frame(
    Item_ID = item_ids,
    Mean_Utility = round(means, 4),
    SD_Utility = round(sds, 4),
    Classification = classification,
    Classification_Label = label,
    stringsAsFactors = FALSE
  )

  # Add item labels if available
  if (!is.null(items) && "Item_ID" %in% names(items) && "Item_Label" %in% names(items)) {
    result <- merge(
      result,
      items[, c("Item_ID", "Item_Label")],
      by = "Item_ID",
      all.x = TRUE,
      sort = FALSE
    )
  } else {
    result$Item_Label <- result$Item_ID
  }

  # Sort by mean utility descending
  result <- result[order(-result$Mean_Utility), ]
  rownames(result) <- NULL

  return(result)
}


# ==============================================================================
# ANCHORED MAXDIFF SUPPORT
# ==============================================================================

#' Process anchor data from survey responses
#'
#' Calculates anchor rates per item from respondent-level anchor
#' selections (which items they consider "must-haves").
#'
#' @param raw_data Data frame. Full survey data
#' @param anchor_variable Character. Column name containing anchor selections
#' @param items Data frame. Item definitions with Item_ID column
#' @param id_variable Character. Respondent ID column name
#' @param anchor_format Character. Format of anchor data:
#'   "BINARY_COLUMNS" - one column per item (1 = must-have)
#'   "COMMA_SEPARATED" - single column with comma-separated Item_IDs
#'
#' @return Data frame with Item_ID, Anchor_Count, Anchor_Rate, Is_Must_Have
#'
#' @export
process_anchor_data <- function(raw_data, anchor_variable, items,
                                id_variable = NULL,
                                anchor_format = "COMMA_SEPARATED",
                                anchor_threshold = 0.50) {

  if (is.null(anchor_variable) || !nzchar(anchor_variable)) {
    return(NULL)
  }

  active_items <- items$Item_ID[items$Include == 1]
  n_resp <- nrow(raw_data)

  if (toupper(anchor_format) == "COMMA_SEPARATED") {
    if (!anchor_variable %in% names(raw_data)) {
      message(sprintf("[TRS INFO] MAXD_ANCHOR_COL_MISSING: Anchor variable '%s' not found in data",
                      anchor_variable))
      return(NULL)
    }

    anchor_col <- as.character(raw_data[[anchor_variable]])
    anchor_counts <- setNames(rep(0L, length(active_items)), active_items)

    for (i in seq_len(n_resp)) {
      if (is.na(anchor_col[i]) || !nzchar(trimws(anchor_col[i]))) next
      selected <- trimws(unlist(strsplit(anchor_col[i], ",")))
      for (item_id in selected) {
        if (item_id %in% active_items) {
          anchor_counts[item_id] <- anchor_counts[item_id] + 1L
        }
      }
    }

  } else if (toupper(anchor_format) == "BINARY_COLUMNS") {
    anchor_counts <- setNames(rep(0L, length(active_items)), active_items)
    for (item_id in active_items) {
      col_name <- paste0(anchor_variable, "_", item_id)
      if (col_name %in% names(raw_data)) {
        vals <- suppressWarnings(as.integer(raw_data[[col_name]]))
        anchor_counts[item_id] <- sum(vals == 1, na.rm = TRUE)
      }
    }
  } else {
    return(NULL)
  }

  anchor_rates <- anchor_counts / n_resp

  result <- data.frame(
    Item_ID = active_items,
    Anchor_Count = as.integer(anchor_counts[active_items]),
    Anchor_Rate = round(anchor_rates[active_items], 3),
    Is_Must_Have = anchor_rates[active_items] >= anchor_threshold,
    stringsAsFactors = FALSE
  )

  # Add labels
  if ("Item_Label" %in% names(items)) {
    result <- merge(result, items[, c("Item_ID", "Item_Label")],
                    by = "Item_ID", all.x = TRUE, sort = FALSE)
  }

  return(result)
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff utils module loaded (v%s)", MAXDIFF_UTILS_VERSION))
