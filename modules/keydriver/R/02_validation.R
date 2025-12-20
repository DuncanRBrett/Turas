# ==============================================================================
# KEY DRIVER DATA VALIDATION
# ==============================================================================
#
# Version: Turas v10.2 (TRS Integration)
# Date: 2025-12
#
# TRS v1.0 integration: Refusal framework for data validation errors.
# All user-fixable issues produce actionable refusals, not crashes.
#
# ==============================================================================

#' Load Key Driver Data
#'
#' Loads and validates data for key driver analysis.
#'
#' @param data_file Path to data file
#' @param config Configuration list
#' @return List with validated data
#' @keywords internal
load_keydriver_data <- function(data_file, config) {

  if (!file.exists(data_file)) {
    keydriver_refuse(
      code = "IO_DATA_NOT_FOUND",
      title = "Data File Not Found",
      problem = paste0("Data file does not exist: ", data_file),
      why_it_matters = "Key driver analysis requires respondent data to analyze.",
      how_to_fix = c(
        "Check that the file path is correct",
        "Ensure the file exists at the specified location",
        "Check for typos in the file name"
      )
    )
  }

  # Detect file type and load
  file_ext <- tolower(tools::file_ext(data_file))

  data <- switch(file_ext,
    "csv" = utils::read.csv(data_file, stringsAsFactors = FALSE),
    "xlsx" = openxlsx::read.xlsx(data_file),
    "sav" = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        keydriver_refuse(
          code = "PKG_HAVEN_REQUIRED",
          title = "Package 'haven' Required",
          problem = "The 'haven' package is required to read SPSS files but is not installed.",
          why_it_matters = "Cannot load .sav files without the haven package.",
          how_to_fix = "Install the haven package: install.packages('haven')"
        )
      }
      haven::read_sav(data_file)
    },
    "dta" = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        keydriver_refuse(
          code = "PKG_HAVEN_REQUIRED",
          title = "Package 'haven' Required",
          problem = "The 'haven' package is required to read Stata files but is not installed.",
          why_it_matters = "Cannot load .dta files without the haven package.",
          how_to_fix = "Install the haven package: install.packages('haven')"
        )
      }
      haven::read_dta(data_file)
    },
    keydriver_refuse(
      code = "DATA_UNSUPPORTED_FORMAT",
      title = "Unsupported File Format",
      problem = paste0("File format '.", file_ext, "' is not supported."),
      why_it_matters = "Key driver analysis can only read supported data formats.",
      how_to_fix = c(
        "Convert your data to a supported format:",
        "  - .csv (CSV file)",
        "  - .xlsx (Excel file)",
        "  - .sav (SPSS file, requires 'haven' package)",
        "  - .dta (Stata file, requires 'haven' package)"
      )
    )
  )

  # Convert to data frame
  data <- as.data.frame(data)

  # Get weight variable if specified
  weight_var <- config$weight_var

  # Build variable list: outcome + drivers + weight (if present)
  base_vars <- c(config$outcome_var, config$driver_vars)
  all_vars <- unique(c(base_vars, weight_var))

  # Validate required variables exist
  missing_vars <- setdiff(base_vars, names(data))
  if (length(missing_vars) > 0) {
    keydriver_refuse(
      code = "DATA_VARIABLES_NOT_FOUND",
      title = "Required Variables Not Found in Data",
      problem = paste0(length(missing_vars), " variable(s) specified in config are not in the data file."),
      why_it_matters = "Cannot run analysis without all specified variables.",
      how_to_fix = c(
        "Check that variable names in config match data column names exactly",
        "Variable names are case-sensitive",
        "Check for extra spaces in column names"
      ),
      expected = base_vars,
      observed = names(data),
      missing = missing_vars
    )
  }

  # Check weight variable exists if specified
  if (!is.null(weight_var) && !weight_var %in% names(data)) {
    keydriver_refuse(
      code = "DATA_WEIGHT_NOT_FOUND",
      title = "Weight Variable Not Found",
      problem = paste0("Weight variable '", weight_var, "' not found in data."),
      why_it_matters = "Cannot apply weighting without the weight variable.",
      how_to_fix = c(
        "Check that the weight variable name matches exactly",
        "Or remove the weight variable from your config if not needed"
      ),
      expected = weight_var,
      observed = names(data)
    )
  }

  # Select only relevant variables
  data <- data[, all_vars, drop = FALSE]

  # Convert outcome and drivers to numeric if needed
  for (var in base_vars) {
    if (!is.numeric(data[[var]])) {
      data[[var]] <- as.numeric(as.character(data[[var]]))
    }
  }

  # Convert weight to numeric if specified
  if (!is.null(weight_var)) {
    if (!is.numeric(data[[weight_var]])) {
      data[[weight_var]] <- as.numeric(as.character(data[[weight_var]]))
    }
  }

  # Define complete cases:
  #  - all base_vars non-missing
  #  - weight non-missing and > 0 (if weight is used)
  complete_cases <- stats::complete.cases(data[, base_vars, drop = FALSE])

  if (!is.null(weight_var)) {
    w <- data[[weight_var]]
    valid_w <- !is.na(w) & w > 0
    complete_cases <- complete_cases & valid_w
  }

  n_complete <- sum(complete_cases)
  n_missing <- nrow(data) - n_complete

  # Note: Missing data warning is now handled by caller (logged, not warning())

  # Sample size rule based on number of drivers
  # Rule of thumb: n >= max(30, 10 * number_of_drivers)
  n_drivers <- length(config$driver_vars)
  min_n <- max(30L, 10L * n_drivers)

  if (n_complete < min_n) {
    keydriver_refuse(
      code = "DATA_INSUFFICIENT_SAMPLE",
      title = "Insufficient Sample Size",
      problem = sprintf("Only %d complete cases available. Need at least %d for %d drivers.",
                       n_complete, min_n, n_drivers),
      why_it_matters = "Insufficient sample size produces unreliable importance estimates.",
      how_to_fix = c(
        "Increase sample size (collect more data)",
        "Reduce number of drivers",
        "Address missing data issues",
        paste0("Rule: need at least 10 cases per driver, minimum 30")
      ),
      details = sprintf("Complete cases: %d | Required: %d | Drivers: %d",
                       n_complete, min_n, n_drivers)
    )
  }

  # Filter to complete cases
  data <- data[complete_cases, , drop = FALSE]

  # Zero-variance checks after filtering
  sds <- vapply(base_vars, function(v) stats::sd(data[[v]], na.rm = TRUE), numeric(1))
  zero_var <- sds == 0

  if (any(zero_var)) {
    offending <- base_vars[zero_var]
    keydriver_refuse(
      code = "DATA_ZERO_VARIANCE",
      title = "Variables Have Zero Variance",
      problem = paste0(length(offending), " variable(s) have zero variance (all values identical)."),
      why_it_matters = "Variables with no variance cannot predict anything and will cause model failures.",
      how_to_fix = c(
        "Remove these variables from your analysis",
        "Or check your data for issues",
        "These variables have identical values for all respondents"
      ),
      missing = offending
    )
  }

  list(
    data = data,
    n_respondents = nrow(data),
    n_complete = n_complete,
    n_missing = n_missing
  )
}
