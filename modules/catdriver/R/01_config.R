# ==============================================================================
# CATEGORICAL KEY DRIVER - CONFIGURATION LOADER
# ==============================================================================
#
# Loads and validates configuration from Excel files.
# Enforces explicit declaration of all analysis parameters.
#
# All user-fixable config issues use catdriver_refuse() for clean refusals.
# Only true internal bugs use stop().
#
# Version: 2.0
# Date: December 2024
#
# ==============================================================================

#' Load Categorical Key Driver Configuration
#'
#' Loads and validates configuration from an Excel file with required sheets:
#' - Settings: Analysis parameters
#' - Variables: Outcome and driver variable definitions
#' - Driver_Settings: Per-driver type and handling specifications
#'
#' @param config_file Path to configuration Excel file
#' @param project_root Optional project root directory (defaults to config file directory)
#' @return List with validated configuration
#' @export
load_catdriver_config <- function(config_file, project_root = NULL) {

  # Validate config file exists
  if (!file.exists(config_file)) {
    catdriver_refuse(
      reason = "CFG_FILE_NOT_FOUND",
      title = "CONFIG FILE NOT FOUND",
      problem = paste0("Configuration file not found: ", config_file),
      why_it_matters = "Cannot load analysis configuration without the config file.",
      fix = "Check the file path is correct and the file exists."
    )
  }

  # Set project root to config file directory if not specified
  if (is.null(project_root)) {
    project_root <- dirname(config_file)
  }
  project_root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)

  # Get available sheets
  available_sheets <- tryCatch(
    openxlsx::getSheetNames(config_file),
    error = function(e) {
      catdriver_refuse(
        reason = "CFG_FILE_INVALID",
        title = "CANNOT READ CONFIG FILE",
        problem = paste0("Cannot read Excel file: ", config_file),
        why_it_matters = "The configuration file must be a valid Excel (.xlsx) file.",
        fix = "Ensure the file is a valid .xlsx file and is not open in Excel.",
        details = paste0("Error: ", e$message)
      )
    }
  )

  # ===========================================================================
  # LOAD SETTINGS SHEET (REQUIRED)
  # ===========================================================================

  if (!"Settings" %in% available_sheets) {
    catdriver_refuse(
      reason = "CFG_SETTINGS_SHEET_MISSING",
      title = "SETTINGS SHEET MISSING",
      problem = "Required sheet 'Settings' not found in config file.",
      why_it_matters = "The Settings sheet defines essential analysis parameters.",
      fix = "Add a 'Settings' sheet with 'Setting' and 'Value' columns.",
      details = paste0("Available sheets: ", paste(available_sheets, collapse = ", "))
    )
  }

  settings_df <- openxlsx::read.xlsx(config_file, sheet = "Settings")

  # Validate settings structure
  if (!all(c("Setting", "Value") %in% names(settings_df))) {
    catdriver_refuse(
      reason = "CFG_SETTINGS_STRUCTURE_INVALID",
      title = "SETTINGS SHEET STRUCTURE INVALID",
      problem = "Settings sheet must have 'Setting' and 'Value' columns.",
      why_it_matters = "Cannot parse settings without the correct column structure.",
      fix = "Ensure Settings sheet has columns named exactly 'Setting' and 'Value'.",
      details = paste0("Found columns: ", paste(names(settings_df), collapse = ", "))
    )
  }

  # Convert to named list
  settings <- setNames(as.list(settings_df$Value), settings_df$Setting)

  # ===========================================================================
  # EXTRACT AND VALIDATE FILE PATHS
  # ===========================================================================

  data_file <- get_setting(settings, "data_file", NULL)
  output_file <- get_setting(settings, "output_file", NULL)

  # Validate required paths
  if (is.null(data_file) || is.na(data_file) || !nzchar(data_file)) {
    catdriver_refuse(
      reason = "CFG_DATA_FILE_MISSING",
      title = "DATA FILE SETTING MISSING",
      problem = "Required setting 'data_file' not found in Settings sheet.",
      why_it_matters = "Cannot run analysis without knowing which data file to use.",
      fix = "Add a row with Setting='data_file' and Value='path/to/your/data.csv'."
    )
  }

  if (is.null(output_file) || is.na(output_file) || !nzchar(output_file)) {
    catdriver_refuse(
      reason = "CFG_OUTPUT_FILE_MISSING",
      title = "OUTPUT FILE SETTING MISSING",
      problem = "Required setting 'output_file' not found in Settings sheet.",
      why_it_matters = "Cannot save results without knowing where to write them.",
      fix = "Add a row with Setting='output_file' and Value='path/to/results.xlsx'."
    )
  }

  # Resolve relative paths
  data_file <- resolve_path(project_root, data_file)
  output_file <- resolve_path(project_root, output_file)

  # Validate data file exists
  if (!file.exists(data_file)) {
    catdriver_refuse(
      reason = "CFG_DATA_FILE_NOT_FOUND",
      title = "DATA FILE NOT FOUND",
      problem = paste0("Data file not found: ", data_file),
      why_it_matters = "Cannot run analysis without the data file.",
      fix = "Check that the 'data_file' path in Settings sheet is correct."
    )
  }

  # Ensure output directory exists
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # ===========================================================================
  # LOAD VARIABLES SHEET (REQUIRED)
  # ===========================================================================

  if (!"Variables" %in% available_sheets) {
    catdriver_refuse(
      reason = "CFG_VARIABLES_SHEET_MISSING",
      title = "VARIABLES SHEET MISSING",
      problem = "Required sheet 'Variables' not found in config file.",
      why_it_matters = "The Variables sheet defines outcome and driver variables.",
      fix = "Add a 'Variables' sheet with columns: VariableName, Type, Label, Order.",
      details = paste0("Available sheets: ", paste(available_sheets, collapse = ", "))
    )
  }

  variables_df <- openxlsx::read.xlsx(config_file, sheet = "Variables")

  # Validate variables structure
  required_cols <- c("VariableName", "Type", "Label")
  missing_cols <- setdiff(required_cols, names(variables_df))

  if (length(missing_cols) > 0) {
    catdriver_refuse(
      reason = "CFG_VARIABLES_COLUMNS_MISSING",
      title = "VARIABLES SHEET COLUMNS MISSING",
      problem = paste0("Variables sheet missing required columns: ", paste(missing_cols, collapse = ", ")),
      why_it_matters = "Cannot identify variables without the correct column structure.",
      fix = "Ensure Variables sheet has columns: VariableName, Type, Label (and optionally Order).",
      details = paste0("Found columns: ", paste(names(variables_df), collapse = ", "))
    )
  }

  # Clean up any whitespace
  variables_df$VariableName <- trimws(variables_df$VariableName)
  variables_df$Type <- trimws(variables_df$Type)
  variables_df$Label <- trimws(variables_df$Label)

  # ===========================================================================
  # LOAD DRIVER_SETTINGS SHEET (REQUIRED FOR V2.0)
  # ===========================================================================

  driver_settings <- NULL

  if ("Driver_Settings" %in% available_sheets) {
    driver_settings <- openxlsx::read.xlsx(config_file, sheet = "Driver_Settings")

    # Validate structure
    if (!all(c("driver", "type") %in% names(driver_settings))) {
      catdriver_refuse(
        reason = "CFG_DRIVER_SETTINGS_COLUMNS_MISSING",
        title = "DRIVER_SETTINGS COLUMNS MISSING",
        problem = "Driver_Settings sheet must have 'driver' and 'type' columns.",
        why_it_matters = "Cannot determine driver types without these columns.",
        fix = "Add 'driver' and 'type' columns to the Driver_Settings sheet.",
        details = paste0("Found columns: ", paste(names(driver_settings), collapse = ", "))
      )
    }

    # Clean up
    driver_settings$driver <- trimws(driver_settings$driver)
    driver_settings$type <- trimws(tolower(driver_settings$type))

    # Add optional columns with defaults
    if (!"levels_order" %in% names(driver_settings)) {
      driver_settings$levels_order <- NA
    }
    if (!"reference_level" %in% names(driver_settings)) {
      driver_settings$reference_level <- NA
    }
    if (!"missing_strategy" %in% names(driver_settings)) {
      driver_settings$missing_strategy <- "missing_as_level"
    }
    if (!"rare_level_policy" %in% names(driver_settings)) {
      driver_settings$rare_level_policy <- NA  # Will use global default
    }
  }

  # ===========================================================================
  # EXTRACT VARIABLE DEFINITIONS
  # ===========================================================================

  # Outcome variable (exactly 1 required)
  outcome_rows <- variables_df$Type == "Outcome"
  outcome_vars <- variables_df$VariableName[outcome_rows]

  if (length(outcome_vars) == 0) {
    catdriver_refuse(
      reason = "CFG_OUTCOME_VAR_MISSING",
      title = "OUTCOME VARIABLE NOT DEFINED",
      problem = "No outcome variable defined in Variables sheet.",
      why_it_matters = "Every analysis needs an outcome variable to predict.",
      fix = "Set Type='Outcome' for exactly one variable in the Variables sheet."
    )
  }

  if (length(outcome_vars) > 1) {
    warning("Multiple outcome variables found. Using first: ", outcome_vars[1])
    outcome_vars <- outcome_vars[1]
  }

  outcome_var <- outcome_vars[1]
  outcome_label <- variables_df$Label[variables_df$VariableName == outcome_var][1]
  outcome_order <- get_variable_order(variables_df, outcome_var)

  # Driver variables (1+ required)
  driver_rows <- variables_df$Type == "Driver"
  driver_vars <- variables_df$VariableName[driver_rows]

  if (length(driver_vars) == 0) {
    catdriver_refuse(
      reason = "CFG_DRIVER_VARS_MISSING",
      title = "NO DRIVER VARIABLES DEFINED",
      problem = "No driver variables defined in Variables sheet.",
      why_it_matters = "Key driver analysis requires at least one predictor variable.",
      fix = "Set Type='Driver' for one or more predictor variables in the Variables sheet."
    )
  }

  # Get driver labels and orders
  driver_labels <- setNames(
    variables_df$Label[driver_rows],
    driver_vars
  )

  driver_orders <- lapply(driver_vars, function(v) {
    get_variable_order(variables_df, v)
  })
  names(driver_orders) <- driver_vars

  # ===========================================================================
  # TRS VALIDATION: Detect conflicting order specs (Variables vs Driver_Settings)
  # ===========================================================================
  # If both Variables.Order and Driver_Settings.levels_order are specified for
  # the same driver and they differ, refuse - this is a configuration error.

  if (!is.null(driver_settings) && is.data.frame(driver_settings) && nrow(driver_settings) > 0) {
    for (drv in driver_vars) {
      variables_order <- driver_orders[[drv]]
      settings_idx <- which(driver_settings$driver == drv)

      if (length(settings_idx) > 0) {
        settings_order_raw <- driver_settings$levels_order[settings_idx[1]]

        # Parse settings_order if it exists
        if (!is.null(settings_order_raw) && !is.na(settings_order_raw) && nzchar(trimws(settings_order_raw))) {
          settings_order <- trimws(strsplit(settings_order_raw, ";")[[1]])

          # Both are specified - check for conflict
          if (!is.null(variables_order) && length(variables_order) > 0) {
            if (!identical(variables_order, settings_order)) {
              catdriver_refuse(
                reason = "CFG_ORDER_SPEC_CONFLICT",
                title = "CONFLICTING ORDER SPECIFICATIONS",
                problem = paste0("Driver '", drv, "' has different Order specifications in Variables sheet and Driver_Settings."),
                why_it_matters = paste0(
                  "Different order specs change factor level interpretation. ",
                  "Driver_Settings.levels_order takes precedence, but having conflicting specs is confusing and error-prone."
                ),
                fix = c(
                  "Option 1: Remove the Order column entry in Variables sheet for this driver",
                  "Option 2: Make Variables.Order match Driver_Settings.levels_order exactly",
                  "Recommended: Use Driver_Settings.levels_order as the single source of truth"
                ),
                details = paste0(
                  "Variables.Order: ", paste(variables_order, collapse = ";"), "\n",
                  "Driver_Settings.levels_order: ", paste(settings_order, collapse = ";")
                )
              )
            }
          }
        }
      }
    }
  }

  # Weight variable (optional)
  weight_rows <- variables_df$Type == "Weight"
  weight_var <- if (any(weight_rows)) {
    variables_df$VariableName[weight_rows][1]
  } else {
    NULL
  }

  # ===========================================================================
  # EXTRACT SETTINGS WITH DEFAULTS
  # ===========================================================================

  # Outcome type - REQUIRED (no auto-detection)
  outcome_type <- tolower(get_setting(settings, "outcome_type", "auto"))

  # Multinomial settings
  multinomial_mode <- get_setting(settings, "multinomial_mode", NULL)
  target_outcome_level <- get_setting(settings, "target_outcome_level", NULL)

  # Reference category
  reference_category <- get_setting(settings, "reference_category", NULL)

  # Rare level policy
  rare_level_policy <- get_setting(settings, "rare_level_policy", "warn_only")
  rare_level_threshold <- as_numeric_setting(
    get_setting(settings, "rare_level_threshold", 10), 10
  )
  rare_cell_threshold <- as_numeric_setting(
    get_setting(settings, "rare_cell_threshold", 5), 5
  )

  # Allow missing reference
  allow_missing_reference <- as_logical_setting(
    get_setting(settings, "allow_missing_reference", FALSE), FALSE
  )

  config <- list(
    # File paths
    config_file = normalizePath(config_file, winslash = "/", mustWork = FALSE),
    project_root = project_root,
    data_file = data_file,
    output_file = output_file,

    # Analysis name
    analysis_name = get_setting(settings, "analysis_name", "Categorical Key Driver Analysis"),

    # Outcome variable
    outcome_var = outcome_var,
    outcome_label = outcome_label,
    outcome_order = outcome_order,
    outcome_type = outcome_type,

    # Multinomial settings
    multinomial_mode = multinomial_mode,
    target_outcome_level = target_outcome_level,

    # Driver variables
    driver_vars = driver_vars,
    driver_labels = driver_labels,
    driver_orders = driver_orders,
    driver_settings = driver_settings,

    # Weight variable
    weight_var = weight_var,

    # Full variables definition
    variables = variables_df,

    # Reference category
    reference_category = reference_category,
    allow_missing_reference = allow_missing_reference,

    # Rare level handling
    rare_level_policy = rare_level_policy,
    rare_level_threshold = rare_level_threshold,
    rare_cell_threshold = rare_cell_threshold,

    # Analysis settings
    min_sample_size = as_numeric_setting(get_setting(settings, "min_sample_size", 30), 30),
    confidence_level = as_numeric_setting(get_setting(settings, "confidence_level", 0.95), 0.95),
    missing_threshold = as_numeric_setting(get_setting(settings, "missing_threshold", 50), 50),
    detailed_output = as_logical_setting(get_setting(settings, "detailed_output", TRUE), TRUE),

    # Raw settings for reference
    settings = settings
  )

  # Validate settings ranges
  if (config$confidence_level <= 0 || config$confidence_level >= 1) {
    catdriver_refuse(
      reason = "CFG_CONFIDENCE_LEVEL_INVALID",
      title = "INVALID CONFIDENCE LEVEL",
      problem = paste0("confidence_level=", config$confidence_level, " is out of range."),
      why_it_matters = "Confidence level must be a probability between 0 and 1.",
      fix = "Set confidence_level to a value like 0.95 for 95% confidence intervals."
    )
  }

  if (config$min_sample_size < 1) {
    catdriver_refuse(
      reason = "CFG_MIN_SAMPLE_SIZE_INVALID",
      title = "INVALID MINIMUM SAMPLE SIZE",
      problem = paste0("min_sample_size=", config$min_sample_size, " is invalid."),
      why_it_matters = "Minimum sample size must be at least 1.",
      fix = "Set min_sample_size to a positive integer (recommended: 30 or more)."
    )
  }

  if (config$missing_threshold < 0 || config$missing_threshold > 100) {
    catdriver_refuse(
      reason = "CFG_MISSING_THRESHOLD_INVALID",
      title = "INVALID MISSING THRESHOLD",
      problem = paste0("missing_threshold=", config$missing_threshold, " is out of range."),
      why_it_matters = "Missing threshold must be a percentage between 0 and 100.",
      fix = "Set missing_threshold to a value between 0 and 100."
    )
  }

  # Validate rare_level_policy
  valid_rare_policies <- c("warn_only", "collapse_to_other", "drop_level", "error")
  if (!config$rare_level_policy %in% valid_rare_policies) {
    catdriver_refuse(
      reason = "CFG_RARE_LEVEL_POLICY_INVALID",
      title = "INVALID RARE LEVEL POLICY",
      problem = paste0("rare_level_policy='", config$rare_level_policy, "' is not recognized."),
      why_it_matters = "Unknown policy cannot be applied to rare categories.",
      fix = paste0("Set rare_level_policy to one of: ", paste(valid_rare_policies, collapse = ", "))
    )
  }

  config
}


#' Get Variable Order Specification
#'
#' Extracts and parses the Order column for a variable.
#'
#' @param variables_df Variables data frame
#' @param var_name Variable name to look up
#' @return Character vector of ordered categories, or NULL if not specified
#' @keywords internal
get_variable_order <- function(variables_df, var_name) {
  # Check if Order column exists
  if (!"Order" %in% names(variables_df)) {
    return(NULL)
  }

  row_idx <- which(variables_df$VariableName == var_name)
  if (length(row_idx) == 0) {
    return(NULL)
  }

  order_spec <- variables_df$Order[row_idx[1]]

  # Handle empty or NA
  if (is.null(order_spec) || is.na(order_spec) || !nzchar(trimws(order_spec))) {
    return(NULL)
  }

  # Parse semicolon-separated values
  categories <- strsplit(order_spec, ";")[[1]]
  categories <- trimws(categories)
  categories <- categories[nzchar(categories)]

  if (length(categories) == 0) {
    return(NULL)
  }

  categories
}


#' Get Driver Setting
#'
#' Retrieves a specific setting for a driver variable.
#'
#' @param config Configuration list
#' @param driver_var Driver variable name
#' @param setting_name Setting name to retrieve
#' @param default Default value if not found
#' @return Setting value or default
#' @export
get_driver_setting <- function(config, driver_var, setting_name, default = NULL) {
  if (is.null(config$driver_settings)) {
    return(default)
  }

  ds <- config$driver_settings
  row_idx <- which(ds$driver == driver_var)

  if (length(row_idx) == 0) {
    return(default)
  }

  if (!setting_name %in% names(ds)) {
    return(default)
  }

  val <- ds[[setting_name]][row_idx[1]]

  if (is.null(val) || is.na(val)) {
    return(default)
  }

  val
}


#' Get Variable Label
#'
#' Retrieves the human-readable label for a variable from config.
#'
#' @param config Configuration list
#' @param var_name Variable name
#' @return Character label, or variable name if no label defined
#' @export
get_var_label <- function(config, var_name) {
  if (var_name == config$outcome_var) {
    return(config$outcome_label)
  }

  if (var_name %in% names(config$driver_labels)) {
    label <- config$driver_labels[[var_name]]
    if (!is.null(label) && !is.na(label) && nzchar(label)) {
      return(label)
    }
  }

  # Fall back to variable name
  var_name
}


#' Validate Configuration Against Data
#'
#' Checks that all configured variables exist in the data.
#'
#' @param config Configuration list
#' @param data Data frame to validate against
#' @return TRUE if valid (refuses with error otherwise)
#' @keywords internal
validate_config_against_data <- function(config, data) {
  data_cols <- names(data)

  # Check outcome variable
  if (!config$outcome_var %in% data_cols) {
    catdriver_refuse(
      reason = "CFG_OUTCOME_VAR_NOT_IN_DATA",
      title = "OUTCOME VARIABLE NOT FOUND IN DATA",
      problem = paste0("Outcome variable '", config$outcome_var, "' not found in data."),
      why_it_matters = "Cannot run analysis when the outcome variable doesn't exist in the data.",
      fix = "Check that the variable name in Variables sheet matches a column in your data file.",
      details = paste0("Available columns: ", paste(head(data_cols, 10), collapse = ", "),
                       if (length(data_cols) > 10) paste0(" ... (", length(data_cols) - 10, " more)") else "")
    )
  }

  # Check driver variables
  missing_drivers <- setdiff(config$driver_vars, data_cols)
  if (length(missing_drivers) > 0) {
    catdriver_refuse(
      reason = "CFG_DRIVER_VARS_NOT_IN_DATA",
      title = "DRIVER VARIABLES NOT FOUND IN DATA",
      problem = paste0("Driver variable(s) not found in data: ", paste(missing_drivers, collapse = ", ")),
      why_it_matters = "Cannot analyze drivers that don't exist in the data.",
      fix = "Check that variable names in Variables sheet match columns in your data file.",
      details = paste0("Available columns: ", paste(head(data_cols, 10), collapse = ", "),
                       if (length(data_cols) > 10) paste0(" ... (", length(data_cols) - 10, " more)") else "")
    )
  }

  # Check weight variable
  if (!is.null(config$weight_var) && !config$weight_var %in% data_cols) {
    warning("Weight variable '", config$weight_var, "' not found in data. ",
            "Proceeding without weights.")
  }

  invisible(TRUE)
}


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Get Setting Value
#'
#' @param settings Named list of settings
#' @param name Setting name
#' @param default Default value
#' @return Setting value or default
#' @keywords internal
get_setting <- function(settings, name, default = NULL) {
  if (name %in% names(settings)) {
    val <- settings[[name]]
    if (!is.null(val) && !is.na(val)) {
      return(val)
    }
  }
  default
}


#' Convert Setting to Numeric
#'
#' @param value Value to convert
#' @param default Default if conversion fails
#' @return Numeric value
#' @keywords internal
as_numeric_setting <- function(value, default) {
  if (is.null(value) || is.na(value)) {
    return(default)
  }
  result <- suppressWarnings(as.numeric(value))
  if (is.na(result)) {
    return(default)
  }
  result
}


#' Convert Setting to Logical
#'
#' @param value Value to convert
#' @param default Default if conversion fails
#' @return Logical value
#' @keywords internal
as_logical_setting <- function(value, default) {
  if (is.null(value) || is.na(value)) {
    return(default)
  }
  if (is.logical(value)) {
    return(value)
  }
  value_str <- tolower(as.character(value))
  if (value_str %in% c("true", "yes", "1", "t", "y")) {
    return(TRUE)
  }
  if (value_str %in% c("false", "no", "0", "f", "n")) {
    return(FALSE)
  }
  default
}


#' Resolve File Path
#'
#' Resolves a potentially relative path against a base directory.
#'
#' @param base_dir Base directory
#' @param file_path File path (may be relative or absolute)
#' @return Absolute file path
#' @keywords internal
resolve_path <- function(base_dir, file_path) {
  if (is.null(file_path) || is.na(file_path)) {
    return(file_path)
  }

  # Check if already absolute
  if (grepl("^(/|[A-Za-z]:)", file_path)) {
    return(normalizePath(file_path, winslash = "/", mustWork = FALSE))
  }

  # Resolve relative to base
  full_path <- file.path(base_dir, file_path)
  normalizePath(full_path, winslash = "/", mustWork = FALSE)
}
