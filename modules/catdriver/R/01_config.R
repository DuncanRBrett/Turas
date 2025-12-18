# ==============================================================================
# CATEGORICAL KEY DRIVER - CONFIGURATION LOADER
# ==============================================================================
#
# Loads and validates configuration from Excel files.
# Enforces explicit declaration of all analysis parameters.
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
    stop("Configuration file not found: ", config_file,
         "\n\nPlease check the file path is correct.", call. = FALSE)
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
      stop("Cannot read Excel file: ", config_file,
           "\n\nError: ", e$message,
           "\n\nEnsure the file is a valid .xlsx file and is not open in Excel.",
           call. = FALSE)
    }
  )

  # ===========================================================================
  # LOAD SETTINGS SHEET (REQUIRED)
  # ===========================================================================

  if (!"Settings" %in% available_sheets) {
    stop("Required sheet 'Settings' not found in config file",
         "\n\nAvailable sheets: ", paste(available_sheets, collapse = ", "),
         call. = FALSE)
  }

  settings_df <- openxlsx::read.xlsx(config_file, sheet = "Settings")

  # Validate settings structure
  if (!all(c("Setting", "Value") %in% names(settings_df))) {
    stop("Settings sheet must have 'Setting' and 'Value' columns",
         "\n\nFound columns: ", paste(names(settings_df), collapse = ", "),
         call. = FALSE)
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
    stop("Required setting 'data_file' not found in Settings sheet",
         call. = FALSE)
  }

  if (is.null(output_file) || is.na(output_file) || !nzchar(output_file)) {
    stop("Required setting 'output_file' not found in Settings sheet",
         call. = FALSE)
  }

  # Resolve relative paths
  data_file <- resolve_path(project_root, data_file)
  output_file <- resolve_path(project_root, output_file)

  # Validate data file exists
  if (!file.exists(data_file)) {
    stop("Data file not found: ", data_file,
         "\n\nCheck that the path in Settings sheet is correct.",
         call. = FALSE)
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
    stop("Required sheet 'Variables' not found in config file",
         "\n\nAvailable sheets: ", paste(available_sheets, collapse = ", "),
         call. = FALSE)
  }

  variables_df <- openxlsx::read.xlsx(config_file, sheet = "Variables")

  # Validate variables structure
  required_cols <- c("VariableName", "Type", "Label")
  missing_cols <- setdiff(required_cols, names(variables_df))

  if (length(missing_cols) > 0) {
    stop("Variables sheet missing required columns: ",
         paste(missing_cols, collapse = ", "),
         "\n\nFound columns: ", paste(names(variables_df), collapse = ", "),
         call. = FALSE)
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
      stop("Driver_Settings sheet must have 'driver' and 'type' columns",
           "\n\nFound columns: ", paste(names(driver_settings), collapse = ", "),
           call. = FALSE)
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
    stop("No outcome variable defined in Variables sheet.",
         "\n\nSet Type='Outcome' for exactly one variable.",
         call. = FALSE)
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
    stop("No driver variables defined in Variables sheet.",
         "\n\nSet Type='Driver' for one or more predictor variables.",
         call. = FALSE)
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
    stop("confidence_level must be between 0 and 1 (e.g., 0.95 for 95%)",
         call. = FALSE)
  }

  if (config$min_sample_size < 1) {
    stop("min_sample_size must be at least 1", call. = FALSE)
  }

  if (config$missing_threshold < 0 || config$missing_threshold > 100) {
    stop("missing_threshold must be between 0 and 100", call. = FALSE)
  }

  # Validate rare_level_policy
  valid_rare_policies <- c("warn_only", "collapse_to_other", "drop_level", "error")
  if (!config$rare_level_policy %in% valid_rare_policies) {
    stop("rare_level_policy must be one of: ", paste(valid_rare_policies, collapse = ", "),
         "\n\nGot: ", config$rare_level_policy,
         call. = FALSE)
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
#' @return TRUE if valid (stops with error otherwise)
#' @keywords internal
validate_config_against_data <- function(config, data) {
  data_cols <- names(data)

  # Check outcome variable
  if (!config$outcome_var %in% data_cols) {
    stop("Outcome variable '", config$outcome_var, "' not found in data.",
         "\n\nAvailable columns: ", paste(head(data_cols, 10), collapse = ", "),
         if (length(data_cols) > 10) paste0(" ... (", length(data_cols) - 10, " more)") else "",
         call. = FALSE)
  }

  # Check driver variables
  missing_drivers <- setdiff(config$driver_vars, data_cols)
  if (length(missing_drivers) > 0) {
    stop("Driver variable(s) not found in data: ",
         paste(missing_drivers, collapse = ", "),
         "\n\nAvailable columns: ", paste(head(data_cols, 10), collapse = ", "),
         if (length(data_cols) > 10) paste0(" ... (", length(data_cols) - 10, " more)") else "",
         call. = FALSE)
  }

  # Check weight variable
  if (!is.null(config$weight_var) && !config$weight_var %in% data_cols) {
    warning("Weight variable '", config$weight_var, "' not found in data. ",
            "Proceeding without weights.")
  }

  invisible(TRUE)
}
