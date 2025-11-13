# ==============================================================================
# DATA LOADER V1.0.0
# ==============================================================================
# Functions for loading and validating survey data
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# V1.0.0 - Initial release (2025-11-12)
#          - Load CSV and XLSX data files
#          - Validate data structure and question IDs
#          - Handle weight variables
#          - Fast CSV loading with data.table (optional)
#
# DEPENDENCIES:
# - readxl (for Excel files)
# - data.table (optional, for fast CSV loading)
# - utils.R
# ==============================================================================

DATA_LOADER_VERSION <- "1.0.0"

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

if (!require("readxl", quietly = TRUE)) {
  stop("Package 'readxl' is required. Install with: install.packages('readxl')", call. = FALSE)
}

# Source utils
source_if_exists <- function(file_path) {
  if (file.exists(file_path)) {
    source(file_path)
  } else if (file.exists(file.path("R", file_path))) {
    source(file.path("R", file_path))
  } else if (file.exists(file.path("..", "R", file_path))) {
    source(file.path("..", "R", file_path))
  }
}

source_if_exists("utils.R")

# Helper: Check if package is available
is_package_available <- function(pkg_name) {
  requireNamespace(pkg_name, quietly = TRUE)
}

# ==============================================================================
# MAIN DATA LOADING FUNCTION
# ==============================================================================

#' Load survey data file
#'
#' Loads survey data from CSV or XLSX file format.
#' Automatically detects format from file extension.
#' For CSV files, uses data.table::fread if available (10x faster than base R).
#'
#' @param data_file_path Character. Path to data file (.csv, .xlsx, or .xls)
#' @param required_questions Character vector. Question IDs that must be present in data
#' @param weight_variable Character. Name of weight variable (NULL if unweighted). Optional.
#' @param verbose Logical. Print loading messages (default TRUE)
#'
#' @return Data frame with survey data
#'
#' @examples
#' data <- load_survey_data("data/wave1.csv", required_questions = c("Q1", "Q2", "Q3"))
#' data <- load_survey_data("data/wave1.xlsx", required_questions = c("Q1"),
#'                          weight_variable = "weight")
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
load_survey_data <- function(data_file_path,
                              required_questions = NULL,
                              weight_variable = NULL,
                              verbose = TRUE) {

  # Validate file exists
  if (!file.exists(data_file_path)) {
    stop(sprintf("Data file not found: %s", data_file_path), call. = FALSE)
  }

  # Detect file format
  file_ext <- tolower(tools::file_ext(data_file_path))

  if (!file_ext %in% c("csv", "xlsx", "xls")) {
    stop(sprintf(
      "Unsupported file format: .%s\nSupported formats: .csv, .xlsx, .xls",
      file_ext
    ), call. = FALSE)
  }

  if (verbose) {
    cat(sprintf("Loading survey data from: %s\n", basename(data_file_path)))
    cat(sprintf("  Format: %s\n", toupper(file_ext)))
  }

  # Load data based on format
  survey_data <- load_data_file(data_file_path, file_ext, verbose)

  if (verbose) {
    cat(sprintf("  ✓ Loaded: %d rows × %d columns\n", nrow(survey_data), ncol(survey_data)))
  }

  # Validate data structure
  validate_survey_data(survey_data, required_questions, weight_variable)

  if (verbose) {
    cat("  ✓ Data validation passed\n")
  }

  return(survey_data)
}


# ==============================================================================
# FILE FORMAT LOADERS
# ==============================================================================

#' Load data file (internal dispatch function)
#' @keywords internal
load_data_file <- function(data_file_path, file_ext, verbose) {
  survey_data <- tryCatch({
    switch(file_ext,
      "xlsx" = {
        readxl::read_excel(data_file_path)
      },
      "xls" = {
        readxl::read_excel(data_file_path)
      },
      "csv" = {
        # Use data.table for fast loading if available
        if (is_package_available("data.table")) {
          if (verbose) cat("  Using data.table::fread() for fast loading...\n")
          data.table::fread(data_file_path, data.table = FALSE)
        } else {
          if (verbose) cat("  Using base R read.csv()...\n")
          read.csv(data_file_path, stringsAsFactors = FALSE, check.names = FALSE)
        }
      },
      stop(sprintf("Unsupported file extension: .%s", file_ext))
    )
  }, error = function(e) {
    stop(sprintf(
      "Failed to load data file\nFile: %s\nError: %s\n\nTroubleshooting:\n  1. Verify file is not corrupted\n  2. Ensure file is not open in Excel\n  3. Check file has data (not empty)\n  4. For CSV: verify correct delimiter and encoding",
      basename(data_file_path),
      conditionMessage(e)
    ), call. = FALSE)
  })

  # Convert to standard data.frame if needed
  if (!is.data.frame(survey_data)) {
    survey_data <- as.data.frame(survey_data)
  }

  return(survey_data)
}


# ==============================================================================
# DATA VALIDATION
# ==============================================================================

#' Validate survey data structure
#'
#' Checks data has required columns, valid structure, and sufficient rows
#'
#' @param survey_data Data frame. Survey data
#' @param required_questions Character vector. Question IDs that must exist
#' @param weight_variable Character. Weight variable name (NULL if unweighted)
#'
#' @return Logical. TRUE if valid (invisible)
#'
#' @keywords internal
validate_survey_data <- function(survey_data, required_questions, weight_variable) {
  # Check it's a data frame
  if (!is.data.frame(survey_data)) {
    stop("Survey data must be a data frame", call. = FALSE)
  }

  # Check has rows
  if (nrow(survey_data) == 0) {
    stop("Survey data has no rows", call. = FALSE)
  }

  # Check has columns
  if (ncol(survey_data) == 0) {
    stop("Survey data has no columns", call. = FALSE)
  }

  # Check required questions exist
  if (!is.null(required_questions) && length(required_questions) > 0) {
    missing_questions <- setdiff(required_questions, names(survey_data))

    if (length(missing_questions) > 0) {
      stop(sprintf(
        "Required question(s) not found in data: %s\n\nAvailable columns:\n  %s",
        paste(missing_questions, collapse = ", "),
        paste(head(names(survey_data), 20), collapse = ", ")
      ), call. = FALSE)
    }
  }

  # Check weight variable exists (if specified)
  if (!is.null(weight_variable) && weight_variable != "") {
    if (!weight_variable %in% names(survey_data)) {
      stop(sprintf(
        "Weight variable '%s' not found in data\n\nAvailable columns:\n  %s",
        weight_variable,
        paste(head(names(survey_data), 20), collapse = ", ")
      ), call. = FALSE)
    }

    # Validate weight variable is numeric
    if (!is.numeric(survey_data[[weight_variable]])) {
      stop(sprintf(
        "Weight variable '%s' must be numeric (found: %s)",
        weight_variable,
        class(survey_data[[weight_variable]])[1]
      ), call. = FALSE)
    }

    # Check for negative weights
    valid_weights <- survey_data[[weight_variable]][!is.na(survey_data[[weight_variable]])]
    if (any(valid_weights < 0)) {
      stop(sprintf(
        "Weight variable '%s' contains negative values (design weights cannot be negative)",
        weight_variable
      ), call. = FALSE)
    }

    # Warn about zero weights
    n_zero <- sum(valid_weights == 0, na.rm = TRUE)
    if (n_zero > 0) {
      warning(sprintf(
        "Weight variable '%s' contains %d zero values (these will be excluded from analysis)",
        weight_variable,
        n_zero
      ), call. = FALSE)
    }

    # Warn about NA weights
    n_na <- sum(is.na(survey_data[[weight_variable]]))
    if (n_na > 0) {
      warning(sprintf(
        "Weight variable '%s' contains %d NA values (these will be excluded from analysis)",
        weight_variable,
        n_na
      ), call. = FALSE)
    }
  }

  invisible(TRUE)
}


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Extract unique question IDs from config
#'
#' Gets list of unique question IDs from question analysis configuration
#'
#' @param question_analysis_df Data frame. Question analysis configuration
#'
#' @return Character vector. Unique question IDs
#'
#' @keywords internal
extract_required_questions <- function(question_analysis_df) {
  if (!"Question_ID" %in% names(question_analysis_df)) {
    stop("question_analysis_df must have 'Question_ID' column", call. = FALSE)
  }

  question_ids <- unique(question_analysis_df$Question_ID)
  question_ids <- question_ids[!is.na(question_ids) & question_ids != ""]

  return(question_ids)
}


#' Get weight variable from config
#'
#' Extracts weight variable name from crosstab config or survey structure
#'
#' @param config_file_path Character. Path to crosstab config file
#'
#' @return Character. Weight variable name, or NULL if unweighted
#'
#' @examples
#' weight_var <- get_weight_variable("config/tabs_config.xlsx")
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
get_weight_variable <- function(config_file_path) {
  # Try to read Settings sheet from crosstab config
  weight_var <- tryCatch({
    settings_df <- readxl::read_excel(config_file_path, sheet = "Settings")

    # Look for weight_variable setting
    if ("Setting" %in% names(settings_df) && "Value" %in% names(settings_df)) {
      weight_idx <- which(settings_df$Setting == "weight_variable")
      if (length(weight_idx) > 0) {
        weight_value <- settings_df$Value[weight_idx[1]]
        if (!is.na(weight_value) && weight_value != "") {
          return(as.character(weight_value))
        }
      }
    }

    # No weight variable found
    return(NULL)
  }, error = function(e) {
    # If can't read config, assume unweighted
    warning(sprintf(
      "Could not read weight variable from config: %s\nAssuming unweighted data",
      e$message
    ), call. = FALSE)
    return(NULL)
  })

  return(weight_var)
}


#' Check data quality
#'
#' Performs basic data quality checks and returns summary
#'
#' @param survey_data Data frame. Survey data
#' @param question_ids Character vector. Question IDs to check
#'
#' @return List with data quality summary
#'
#' @examples
#' quality <- check_data_quality(data, c("Q1", "Q2", "Q3"))
#' print(quality$summary)
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
check_data_quality <- function(survey_data, question_ids) {
  quality_summary <- list()

  # Overall stats
  quality_summary$total_rows <- nrow(survey_data)
  quality_summary$total_cols <- ncol(survey_data)

  # Check each question
  question_quality <- data.frame(
    Question_ID = character(),
    Missing_N = integer(),
    Missing_Pct = numeric(),
    Unique_Values = integer(),
    stringsAsFactors = FALSE
  )

  for (q_id in question_ids) {
    if (q_id %in% names(survey_data)) {
      values <- survey_data[[q_id]]
      n_missing <- sum(is.na(values))
      pct_missing <- n_missing / length(values) * 100
      n_unique <- length(unique(values[!is.na(values)]))

      question_quality <- rbind(question_quality, data.frame(
        Question_ID = q_id,
        Missing_N = n_missing,
        Missing_Pct = round(pct_missing, 1),
        Unique_Values = n_unique,
        stringsAsFactors = FALSE
      ))
    }
  }

  quality_summary$question_quality <- question_quality

  # Flag high missing data
  high_missing <- question_quality[question_quality$Missing_Pct > 10, ]
  if (nrow(high_missing) > 0) {
    quality_summary$warnings <- sprintf(
      "High missing data (>10%%) in: %s",
      paste(high_missing$Question_ID, collapse = ", ")
    )
  } else {
    quality_summary$warnings <- character()
  }

  return(quality_summary)
}


#' Print data quality summary
#'
#' @param quality_summary List. Output from check_data_quality()
#'
#' @export
print_data_quality <- function(quality_summary) {
  cat("\n=== DATA QUALITY SUMMARY ===\n")
  cat(sprintf("Total respondents: %d\n", quality_summary$total_rows))
  cat(sprintf("Total variables: %d\n", quality_summary$total_cols))

  cat("\nQuestion-level quality:\n")
  print(quality_summary$question_quality, row.names = FALSE)

  if (length(quality_summary$warnings) > 0) {
    cat("\n⚠ WARNINGS:\n")
    for (warn in quality_summary$warnings) {
      cat(sprintf("  - %s\n", warn))
    }
  } else {
    cat("\n✓ No data quality issues detected\n")
  }
}
