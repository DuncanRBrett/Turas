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
  confidence_refuse(
    code = "PKG_READXL_MISSING",
    title = "Required Package Not Installed",
    problem = "Package 'readxl' is required but not installed",
    why_it_matters = "The readxl package is required to read Excel data files.",
    how_to_fix = "Install the package with: install.packages('readxl')"
  )
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
    confidence_refuse(
      code = "IO_DATA_FILE_NOT_FOUND",
      title = "Data File Not Found",
      problem = sprintf("Data file not found: %s", data_file_path),
      why_it_matters = "Survey data is required for confidence interval calculations.",
      how_to_fix = c(
        "Verify the data file path in the config is correct",
        "Ensure the file exists in the specified location"
      )
    )
  }

  # Detect file format
  file_ext <- tolower(tools::file_ext(data_file_path))

  if (!file_ext %in% c("csv", "xlsx", "xls")) {
    confidence_refuse(
      code = "IO_UNSUPPORTED_FORMAT",
      title = "Unsupported File Format",
      problem = sprintf("Unsupported file format: .%s", file_ext),
      why_it_matters = "Only CSV and Excel formats are supported for data files.",
      how_to_fix = c(
        "Convert the data file to one of these formats: .csv, .xlsx, .xls",
        "Update the Data_File path in config to point to a supported format"
      ),
      observed = file_ext,
      expected = c("csv", "xlsx", "xls")
    )
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
      confidence_refuse(
        code = "IO_UNSUPPORTED_FORMAT",
        title = "Unsupported File Extension",
        problem = sprintf("Unsupported file extension: .%s", file_ext),
        why_it_matters = "Only supported file formats can be loaded.",
        how_to_fix = "Use a supported format: .csv, .xlsx, or .xls"
      )
    )
  }, error = function(e) {
    confidence_refuse(
      code = "IO_DATA_LOAD_FAILED",
      title = "Failed to Load Data File",
      problem = sprintf("Failed to load data file: %s - %s", basename(data_file_path), conditionMessage(e)),
      why_it_matters = "Survey data must be successfully loaded before analysis can proceed.",
      how_to_fix = c(
        "Verify file is not corrupted",
        "Ensure file is not open in Excel",
        "Check file has data (not empty)",
        "For CSV: verify correct delimiter and encoding"
      )
    )
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
    confidence_refuse(
      code = "DATA_INVALID_TYPE",
      title = "Invalid Data Type",
      problem = "Survey data must be a data frame",
      why_it_matters = "Analysis requires properly structured tabular data.",
      how_to_fix = "Ensure the data file is properly formatted as a table"
    )
  }

  # Check has rows
  if (nrow(survey_data) == 0) {
    confidence_refuse(
      code = "DATA_NO_ROWS",
      title = "Data File is Empty",
      problem = "Survey data has no rows",
      why_it_matters = "Analysis requires at least one respondent.",
      how_to_fix = "Ensure the data file contains response data"
    )
  }

  # Check has columns
  if (ncol(survey_data) == 0) {
    confidence_refuse(
      code = "DATA_NO_COLUMNS",
      title = "Data File Has No Columns",
      problem = "Survey data has no columns",
      why_it_matters = "Analysis requires question variables.",
      how_to_fix = "Ensure the data file contains variable columns"
    )
  }

  # Check required questions exist
  if (!is.null(required_questions) && length(required_questions) > 0) {
    missing_questions <- setdiff(required_questions, names(survey_data))

    if (length(missing_questions) > 0) {
      confidence_refuse(
        code = "DATA_MISSING_QUESTIONS",
        title = "Required Questions Not Found in Data",
        problem = "One or more required question columns are missing from the data file",
        why_it_matters = "All specified questions must exist in the data for analysis.",
        how_to_fix = c(
          "Verify question IDs in the config match column names in the data",
          "Check for typos in question IDs",
          "Ensure all required columns are present in the data file"
        ),
        expected = required_questions,
        observed = names(survey_data),
        missing = missing_questions,
        details = sprintf("Available columns: %s", paste(head(names(survey_data), 20), collapse = ", "))
      )
    }
  }

  # Check weight variable exists (if specified)
  if (!is.null(weight_variable) && weight_variable != "") {
    if (!weight_variable %in% names(survey_data)) {
      confidence_refuse(
        code = "DATA_WEIGHT_NOT_FOUND",
        title = "Weight Variable Not Found",
        problem = sprintf("Weight variable '%s' not found in data", weight_variable),
        why_it_matters = "The specified weight variable must exist for weighted analysis.",
        how_to_fix = c(
          sprintf("Verify that column '%s' exists in the data file", weight_variable),
          "Check for typos in the weight variable name",
          "Or remove weight_variable from config for unweighted analysis"
        ),
        expected = weight_variable,
        observed = names(survey_data),
        details = sprintf("Available columns: %s", paste(head(names(survey_data), 20), collapse = ", "))
      )
    }

    # Validate weight variable is numeric
    if (!is.numeric(survey_data[[weight_variable]])) {
      confidence_refuse(
        code = "DATA_WEIGHT_NOT_NUMERIC",
        title = "Weight Variable Must Be Numeric",
        problem = sprintf("Weight variable '%s' must be numeric (found: %s)", weight_variable, class(survey_data[[weight_variable]])[1]),
        why_it_matters = "Weights must be numeric values for proper calculation.",
        how_to_fix = sprintf("Convert the '%s' column to numeric type in the data file", weight_variable)
      )
    }

    # Check for negative weights
    valid_weights <- survey_data[[weight_variable]][!is.na(survey_data[[weight_variable]])]
    if (any(valid_weights < 0)) {
      confidence_refuse(
        code = "DATA_NEGATIVE_WEIGHTS",
        title = "Weight Variable Contains Negative Values",
        problem = sprintf("Weight variable '%s' contains negative values", weight_variable),
        why_it_matters = "Design weights cannot be negative - they represent sampling probability inversions.",
        how_to_fix = c(
          "Check the weighting calculation for errors",
          "Ensure all weights are positive or zero",
          "Verify the correct weight variable was specified"
        )
      )
    }

    # TRS INFO: Zero weights
    n_zero <- sum(valid_weights == 0, na.rm = TRUE)
    if (n_zero > 0) {
      message(sprintf(
        "[TRS INFO] CONF_WEIGHT_ZEROS: Weight variable '%s' contains %d zero values (these will be excluded from analysis)",
        weight_variable,
        n_zero
      ))
    }

    # TRS INFO: NA weights
    n_na <- sum(is.na(survey_data[[weight_variable]]))
    if (n_na > 0) {
      message(sprintf(
        "[TRS INFO] CONF_WEIGHT_NAS: Weight variable '%s' contains %d NA values (these will be excluded from analysis)",
        weight_variable,
        n_na
      ))
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
    confidence_refuse(
      code = "CFG_MISSING_QUESTION_ID_COLUMN",
      title = "Missing Question_ID Column",
      problem = "question_analysis_df must have 'Question_ID' column",
      why_it_matters = "Question IDs are required to identify which variables to analyze.",
      how_to_fix = "Ensure the Question_Analysis sheet has a 'Question_ID' column"
    )
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
    # TRS INFO: Unable to read weight configuration
    message(sprintf("[TRS INFO] Could not read weight variable from config: %s - assuming unweighted data",
                   e$message))
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
