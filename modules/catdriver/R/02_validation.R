# ==============================================================================
# CATEGORICAL KEY DRIVER - DATA LOADING & VALIDATION
# ==============================================================================
#
# Functions for loading survey data and validating it for analysis.
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================

#' Load Survey Data for Categorical Key Driver Analysis
#'
#' Loads data from various formats (CSV, Excel, SPSS) and performs
#' initial validation.
#'
#' @param data_file Path to data file
#' @param config Configuration list (for variable validation)
#' @return Data frame ready for analysis
#' @export
load_catdriver_data <- function(data_file, config = NULL) {

  # Validate file exists
  if (!file.exists(data_file)) {
    catdriver_refuse(
      reason = "DATA_FILE_NOT_FOUND",
      title = "DATA FILE NOT FOUND",
      problem = paste0("Data file not found: ", data_file),
      why_it_matters = "Cannot run analysis without the data file.",
      fix = "Check that the file path is correct and the file exists."
    )
  }

  # Detect file format
  file_ext <- tolower(tools::file_ext(data_file))

  # Load based on format
  data <- tryCatch({
    switch(file_ext,
      "csv" = load_csv_data(data_file),
      "xlsx" = load_excel_data(data_file),
      "xls" = load_excel_data(data_file),
      "sav" = load_spss_data(data_file),
      "dta" = load_stata_data(data_file),
      catdriver_refuse(
        reason = "DATA_FILE_FORMAT_UNSUPPORTED",
        title = "UNSUPPORTED FILE FORMAT",
        problem = paste0("File format '.", file_ext, "' is not supported."),
        why_it_matters = "Can only load data from supported file formats.",
        fix = "Convert your data to one of: csv, xlsx, xls, sav, dta"
      )
    )
  }, error = function(e) {
    # Check if this is already a catdriver_refusal
    if (inherits(e, "catdriver_refusal")) {
      stop(e)  # Re-throw catdriver_refusal
    }
    catdriver_refuse(
      reason = "DATA_FILE_LOAD_FAILED",
      title = "FAILED TO LOAD DATA FILE",
      problem = paste0("Could not load data file: ", data_file),
      why_it_matters = "Cannot run analysis without successfully loading the data.",
      fix = "Check that the file is valid and not corrupted.",
      details = paste0("Error: ", e$message)
    )
  })

  # Validate data frame
  if (!is.data.frame(data)) {
    catdriver_refuse(
      reason = "DATA_NOT_DATAFRAME",
      title = "INVALID DATA FORMAT",
      problem = "Data file did not produce a valid data frame.",
      why_it_matters = "Analysis requires tabular data.",
      fix = "Ensure your data file contains properly formatted tabular data."
    )
  }

  if (nrow(data) == 0) {
    catdriver_refuse(
      reason = "DATA_EMPTY",
      title = "DATA FILE IS EMPTY",
      problem = "Data file contains 0 rows.",
      why_it_matters = "Cannot run analysis on empty data.",
      fix = "Ensure your data file contains data rows (not just headers)."
    )
  }

  # Validate against config if provided
  if (!is.null(config)) {
    validate_config_against_data(config, data)
  }

  data
}


#' Load CSV Data
#'
#' @param file_path Path to CSV file
#' @return Data frame
#' @keywords internal
load_csv_data <- function(file_path) {
  # Try data.table for speed if available
  if (requireNamespace("data.table", quietly = TRUE)) {
    data <- data.table::fread(file_path, data.table = FALSE)
  } else {
    data <- read.csv(file_path, stringsAsFactors = FALSE)
  }
  data
}


#' Load Excel Data
#'
#' @param file_path Path to Excel file
#' @return Data frame
#' @keywords internal
load_excel_data <- function(file_path) {
  # Get sheet names
  sheets <- openxlsx::getSheetNames(file_path)

  # Use first sheet if "Data" doesn't exist
  sheet_name <- if ("Data" %in% sheets) "Data" else sheets[1]

  openxlsx::read.xlsx(file_path, sheet = sheet_name)
}


#' Load SPSS Data
#'
#' @param file_path Path to .sav file
#' @return Data frame
#' @keywords internal
load_spss_data <- function(file_path) {
  if (!requireNamespace("haven", quietly = TRUE)) {
    catdriver_refuse(
      reason = "PKG_HAVEN_MISSING",
      title = "REQUIRED PACKAGE MISSING",
      problem = "Package 'haven' is required to read SPSS files (.sav) but is not installed.",
      why_it_matters = "Cannot load SPSS data without the haven package.",
      fix = "Install the package by running: install.packages('haven')"
    )
  }

  data <- haven::read_sav(file_path)

  # Convert haven_labelled to factors where appropriate
  for (col in names(data)) {
    if (inherits(data[[col]], "haven_labelled")) {
      labels <- attr(data[[col]], "labels")
      if (!is.null(labels)) {
        data[[col]] <- haven::as_factor(data[[col]])
      } else {
        data[[col]] <- as.vector(data[[col]])
      }
    }
  }

  as.data.frame(data)
}


#' Load Stata Data
#'
#' @param file_path Path to .dta file
#' @return Data frame
#' @keywords internal
load_stata_data <- function(file_path) {
  if (!requireNamespace("haven", quietly = TRUE)) {
    catdriver_refuse(
      reason = "PKG_HAVEN_MISSING",
      title = "REQUIRED PACKAGE MISSING",
      problem = "Package 'haven' is required to read Stata files (.dta) but is not installed.",
      why_it_matters = "Cannot load Stata data without the haven package.",
      fix = "Install the package by running: install.packages('haven')"
    )
  }

  data <- haven::read_dta(file_path)

  # Convert labelled variables
  for (col in names(data)) {
    if (inherits(data[[col]], "haven_labelled")) {
      labels <- attr(data[[col]], "labels")
      if (!is.null(labels)) {
        data[[col]] <- haven::as_factor(data[[col]])
      } else {
        data[[col]] <- as.vector(data[[col]])
      }
    }
  }

  as.data.frame(data)
}


# ==============================================================================
# DATA VALIDATION FUNCTIONS
# ==============================================================================

#' Validate Data for Categorical Key Driver Analysis
#'
#' Performs comprehensive validation of data and produces a diagnostic report.
#'
#' @param data Data frame to validate
#' @param config Configuration list
#' @return List with validation results and diagnostics
#' @export
validate_catdriver_data <- function(data, config) {

  diagnostics <- list(
    original_n = nrow(data),
    complete_n = NA,
    pct_complete = NA,
    missing_summary = NULL,
    outcome_info = NULL,
    driver_info = list(),
    small_cells = list(),
    warnings = character(0),
    errors = character(0),
    passed = TRUE
  )

  # ==========================================================================
  # CHECK MISSING DATA
  # ==========================================================================

  # Get analysis variables
  analysis_vars <- c(config$outcome_var, config$driver_vars)
  if (!is.null(config$weight_var) && config$weight_var %in% names(data)) {
    analysis_vars <- c(analysis_vars, config$weight_var)
  }

  # Calculate missing per variable
  missing_summary <- data.frame(
    Variable = analysis_vars,
    Label = sapply(analysis_vars, function(v) get_var_label(config, v)),
    N_Total = nrow(data),
    N_Missing = sapply(analysis_vars, function(v) sum(is.na(data[[v]]))),
    stringsAsFactors = FALSE
  )
  missing_summary$Pct_Missing <- round(100 * missing_summary$N_Missing / missing_summary$N_Total, 1)
  missing_summary$N_Valid <- missing_summary$N_Total - missing_summary$N_Missing

  diagnostics$missing_summary <- missing_summary

  # Check for high missing rates
  high_missing <- missing_summary$Pct_Missing > config$missing_threshold
  if (any(high_missing)) {
    high_vars <- missing_summary$Variable[high_missing]
    diagnostics$warnings <- c(diagnostics$warnings,
      paste0("High missing data (>", config$missing_threshold, "%) in: ",
             paste(high_vars, collapse = ", ")))
  }

  # ==========================================================================
  # CALCULATE EFFECTIVE ANALYZABLE N (strategy-aware)
  # ==========================================================================
  #
  # We do NOT use complete.cases() to determine if we have enough data.
  # Instead, we compute the minimum rows that will remain AFTER applying
  # the per-variable missing strategy:
  #
  # - Outcome missing: always dropped
  # - Driver with drop_row strategy: dropped
  # - Driver with missing_as_level strategy: kept (not counted against N)
  # - Driver with error_if_missing: will hard-error later if any missing
  #
  # This prevents rejecting valid runs where drivers use missing_as_level.

  # Start with rows that have non-missing outcome (these are always required)
  outcome_valid_mask <- !is.na(data[[config$outcome_var]])
  effective_n <- sum(outcome_valid_mask)

  # For each driver, only subtract if strategy is "drop_row"
  for (driver_var in config$driver_vars) {
    strategy <- get_driver_setting(config, driver_var, "missing_strategy", "drop_row")

    if (strategy == "drop_row") {
      # These rows will be dropped - but only if outcome is also valid
      # (outcome missing rows are already excluded)
      driver_missing_in_valid <- is.na(data[[driver_var]]) & outcome_valid_mask
      effective_n <- effective_n - sum(driver_missing_in_valid)
      # Update mask for next driver (cumulative exclusion)
      outcome_valid_mask <- outcome_valid_mask & !is.na(data[[driver_var]])
    }
    # For "missing_as_level" and "error_if_missing", don't subtract
    # (missing_as_level keeps rows; error_if_missing will hard-stop later)
  }

  diagnostics$complete_n <- effective_n
  diagnostics$pct_complete <- round(100 * effective_n / diagnostics$original_n, 1)

  # Check minimum sample size against effective N
  if (effective_n < config$min_sample_size) {
    diagnostics$errors <- c(diagnostics$errors,
      paste0("Insufficient analyzable cases after applying missing strategy: ",
             effective_n, " (minimum ", config$min_sample_size, " required)"))
    diagnostics$passed <- FALSE
  }

  # ==========================================================================
  # VALIDATE OUTCOME VARIABLE
  # ==========================================================================

  outcome_data <- data[[config$outcome_var]]
  outcome_clean <- na.omit(outcome_data)

  outcome_info <- list(
    variable = config$outcome_var,
    label = config$outcome_label,
    n_total = length(outcome_data),
    n_valid = length(outcome_clean),
    n_categories = length(unique(outcome_clean)),
    categories = sort(unique(as.character(outcome_clean))),
    counts = table(outcome_clean)
  )

  # Validate category count
  if (outcome_info$n_categories < 2) {
    diagnostics$errors <- c(diagnostics$errors,
      "Outcome variable must have at least 2 categories")
    diagnostics$passed <- FALSE
  }

  # Check for rare categories
  rare_cats <- names(outcome_info$counts)[outcome_info$counts < 10]
  if (length(rare_cats) > 0) {
    diagnostics$warnings <- c(diagnostics$warnings,
      paste0("Outcome has rare categories (<10 obs): ",
             paste(rare_cats, collapse = ", ")))
  }

  diagnostics$outcome_info <- outcome_info

  # ==========================================================================
  # VALIDATE DRIVER VARIABLES
  # ==========================================================================

  for (driver_var in config$driver_vars) {
    driver_data <- data[[driver_var]]
    driver_clean <- na.omit(driver_data)

    driver_info <- list(
      variable = driver_var,
      label = get_var_label(config, driver_var),
      n_valid = length(driver_clean),
      n_categories = length(unique(driver_clean)),
      categories = sort(unique(as.character(driver_clean))),
      counts = table(driver_clean),
      is_numeric = is.numeric(driver_data),
      is_categorical = is_categorical(driver_data)
    )

    # Check for zero variance
    if (driver_info$n_categories < 2) {
      diagnostics$warnings <- c(diagnostics$warnings,
        paste0("Driver '", driver_var, "' has zero variance (only 1 value)"))
    }

    # Check for high cardinality
    if (driver_info$n_categories > 20 && driver_info$is_categorical) {
      diagnostics$warnings <- c(diagnostics$warnings,
        paste0("Driver '", driver_var, "' has ", driver_info$n_categories,
               " categories. Consider grouping."))
    }

    # Check for rare categories in categorical drivers
    if (driver_info$is_categorical) {
      rare_driver_cats <- names(driver_info$counts)[driver_info$counts < 10]
      if (length(rare_driver_cats) > 0 && length(rare_driver_cats) < driver_info$n_categories) {
        diagnostics$warnings <- c(diagnostics$warnings,
          paste0("Driver '", driver_var, "' has rare categories (<10 obs): ",
                 paste(head(rare_driver_cats, 3), collapse = ", "),
                 if (length(rare_driver_cats) > 3) paste0(" +", length(rare_driver_cats) - 3, " more") else ""))
      }
    }

    diagnostics$driver_info[[driver_var]] <- driver_info
  }

  # ==========================================================================

  # CHECK CROSS-TABULATION FOR SMALL CELLS
  # ==========================================================================

  # Build strategy-aware mask: include rows that will be analyzed
  # (outcome non-missing, and drivers either non-missing or use missing_as_level)
  analyzable_mask <- !is.na(data[[config$outcome_var]])

  for (driver_var in config$driver_vars) {
    strategy <- get_driver_setting(config, driver_var, "missing_strategy", "drop_row")
    if (strategy == "drop_row") {
      # These rows will be dropped, so exclude from analysis
      analyzable_mask <- analyzable_mask & !is.na(data[[driver_var]])
    }
    # For missing_as_level, rows are kept (mask unchanged)
    # For error_if_missing, we'll hard-stop later if any missing
  }

  data_complete <- data[analyzable_mask, , drop = FALSE]

  for (driver_var in config$driver_vars) {
    if (is_categorical(data_complete[[driver_var]])) {
      tab <- table(data_complete[[driver_var]], data_complete[[config$outcome_var]])
      small_cell_check <- detect_small_cells(tab, threshold = 5)

      if (small_cell_check$has_small_cells) {
        diagnostics$small_cells[[driver_var]] <- small_cell_check
        diagnostics$warnings <- c(diagnostics$warnings,
          paste0("Small cells (<5) in ", driver_var, " x ", config$outcome_var,
                 " cross-tabulation"))
      }
    }
  }

  # ==========================================================================
  # CALCULATE EVENTS PER PREDICTOR (for binary outcomes)
  # ==========================================================================

  if (outcome_info$n_categories == 2) {
    # Count minority class
    min_events <- min(outcome_info$counts)

    # Count predictor terms (approximate)
    n_terms <- sum(sapply(config$driver_vars, function(v) {
      if (is_categorical(data[[v]])) {
        max(1, length(unique(na.omit(data[[v]]))) - 1)
      } else {
        1
      }
    }))

    events_per_predictor <- min_events / n_terms

    if (events_per_predictor < 10) {
      diagnostics$warnings <- c(diagnostics$warnings,
        paste0("Low events per predictor: ", round(events_per_predictor, 1),
               " (recommend 10+). Consider reducing number of predictors."))
    }

    diagnostics$events_per_predictor <- events_per_predictor
  }

  # ==========================================================================
  # CHECK WEIGHT VARIABLE
  # ==========================================================================

  if (!is.null(config$weight_var)) {
    if (!config$weight_var %in% names(data)) {
      diagnostics$warnings <- c(diagnostics$warnings,
        paste0("Weight variable '", config$weight_var, "' not found. Proceeding unweighted."))
    } else {
      weights <- data[[config$weight_var]]

      if (!is.numeric(weights)) {
        diagnostics$warnings <- c(diagnostics$warnings,
          "Weight variable is not numeric. Proceeding unweighted.")
      } else if (any(weights < 0, na.rm = TRUE)) {
        diagnostics$warnings <- c(diagnostics$warnings,
          "Weight variable contains negative values. These will be treated as 0.")
      } else if (all(is.na(weights))) {
        diagnostics$warnings <- c(diagnostics$warnings,
          "Weight variable is entirely missing. Proceeding unweighted.")
      }
    }
  }

  diagnostics
}


#' Prepare Data for Analysis
#'
#' Applies per-variable missing data strategy as specified in Driver_Settings.
#' DOES NOT use blanket complete.cases() deletion.
#'
#' Missing data strategy per variable (from Driver_Settings sheet):
#' - outcome missing: ALWAYS drop the row
#' - driver missing with "drop_row": drop the row
#' - driver missing with "missing_as_level": recode to "Missing" level
#' - driver missing with "error_if_missing": hard error if any missing
#'
#' @param data Raw data frame
#' @param config Configuration list
#' @param diagnostics Validation diagnostics
#' @return List with analysis-ready data and metadata
#' @keywords internal
prepare_analysis_data <- function(data, config, diagnostics) {

  n_original <- nrow(data)
  missing_report <- list()

  # ==========================================================================
  # STEP 1: Handle outcome variable (ALWAYS drop rows with missing outcome)
  # ==========================================================================

  outcome_missing <- is.na(data[[config$outcome_var]])
  n_outcome_missing <- sum(outcome_missing)

  if (n_outcome_missing > 0) {
    data <- data[!outcome_missing, , drop = FALSE]
    missing_report$outcome <- list(
      variable = config$outcome_var,
      strategy = "drop_row",
      n_missing = n_outcome_missing,
      action = "dropped"
    )
  }

  # ==========================================================================
  # STEP 2: Handle each driver variable per its missing_strategy
  # ==========================================================================

  for (driver_var in config$driver_vars) {
    # Get per-variable strategy from Driver_Settings
    strategy <- get_driver_setting(config, driver_var, "missing_strategy", "drop_row")

    driver_missing <- is.na(data[[driver_var]])
    n_missing <- sum(driver_missing)

    if (n_missing == 0) {
      # No missing - nothing to do
      next
    }

    if (strategy == "error_if_missing") {
      # Policy refusal - explicit choice to not allow missing values
      catdriver_refuse(
        reason = "DATA_MISSING_NOT_ALLOWED",
        title = "MISSING VALUES NOT ALLOWED",
        problem = paste0("Variable '", driver_var, "' has ", n_missing, " missing value(s)."),
        why_it_matters = paste0("The missing_strategy for this variable is 'error_if_missing', ",
                                "which requires complete data."),
        fix = paste0("Either:\n",
                     "  1. Fix the missing values in your data, OR\n",
                     "  2. Change missing_strategy to 'drop_row' or 'missing_as_level' in Driver_Settings")
      )

    } else if (strategy == "missing_as_level") {
      # Recode missing to "Missing" level
      var_data <- data[[driver_var]]

      if (!is.factor(var_data)) {
        var_data <- factor(var_data)
      }

      # Add "Missing" as a level and recode NAs
      levels(var_data) <- c(levels(var_data), "Missing")
      var_data[is.na(var_data)] <- "Missing"
      data[[driver_var]] <- var_data

      missing_report[[driver_var]] <- list(
        variable = driver_var,
        strategy = "missing_as_level",
        n_missing = n_missing,
        action = "recoded to 'Missing' level"
      )

    } else {
      # Default: drop_row
      data <- data[!driver_missing, , drop = FALSE]

      missing_report[[driver_var]] <- list(
        variable = driver_var,
        strategy = "drop_row",
        n_missing = n_missing,
        action = "dropped"
      )
    }
  }

  # ==========================================================================
  # STEP 3: Handle weights
  # ==========================================================================

  has_weights <- FALSE
  weights <- rep(1, nrow(data))

  if (!is.null(config$weight_var) && config$weight_var %in% names(data)) {
    w <- data[[config$weight_var]]
    if (is.numeric(w) && !all(is.na(w))) {
      has_weights <- TRUE
      w[is.na(w)] <- 1
      w[w < 0] <- 0
      weights <- w
    }
  }

  # ==========================================================================
  # STEP 4: Compile result
  # ==========================================================================

  n_complete <- nrow(data)
  n_excluded <- n_original - n_complete

  list(
    data = data,
    weights = weights,
    has_weights = has_weights,
    n_original = n_original,
    n_complete = n_complete,
    n_excluded = n_excluded,
    missing_report = missing_report
  )
}


#' Generate Missing Data Report
#'
#' Creates a formatted summary of missing data for output.
#'
#' @param diagnostics Validation diagnostics
#' @return Character string with formatted report
#' @export
format_missing_report <- function(diagnostics) {
  lines <- character(0)

  lines <- c(lines, "Missing data detected:")
  lines <- c(lines, sprintf("- Original sample: %d respondents",
                           diagnostics$original_n))
  lines <- c(lines, sprintf("- Complete cases: %d respondents (%s%%)",
                           diagnostics$complete_n, diagnostics$pct_complete))
  lines <- c(lines, sprintf("- Excluded: %d respondents (%s%%)",
                           diagnostics$original_n - diagnostics$complete_n,
                           round(100 - diagnostics$pct_complete, 1)))

  # Variables with highest missing
  if (!is.null(diagnostics$missing_summary)) {
    ms <- diagnostics$missing_summary
    ms <- ms[order(-ms$Pct_Missing), ]
    ms <- ms[ms$Pct_Missing > 0, ]

    if (nrow(ms) > 0) {
      lines <- c(lines, "")
      lines <- c(lines, "Variables with missing data:")
      for (i in 1:min(5, nrow(ms))) {
        lines <- c(lines, sprintf("- %s: %s%% missing",
                                 ms$Variable[i], ms$Pct_Missing[i]))
      }
    }
  }

  paste(lines, collapse = "\n")
}
