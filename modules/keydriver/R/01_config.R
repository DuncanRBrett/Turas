# ==============================================================================
# KEY DRIVER CONFIG LOADER
# ==============================================================================

#' Load Key Driver Configuration
#'
#' Loads and validates key driver analysis configuration.
#'
#' @param config_file Path to configuration Excel file
#' @param project_root Optional project root directory (defaults to config file directory)
#' @return List with validated configuration
#' @keywords internal
load_keydriver_config <- function(config_file, project_root = NULL) {

  if (!file.exists(config_file)) {
    stop("Configuration file not found: ", config_file, call. = FALSE)
  }

  # Set project root to config file directory if not specified
  if (is.null(project_root)) {
    project_root <- dirname(config_file)
  }

  # Load settings
  settings <- openxlsx::read.xlsx(config_file, sheet = "Settings")
  settings_list <- setNames(as.list(settings$Value), settings$Setting)

  # Extract and resolve file paths from settings
  data_file <- settings_list$data_file
  output_file <- settings_list$output_file

  # Resolve relative paths
  if (!is.null(data_file) && !is.na(data_file)) {
    if (!grepl("^(/|[A-Za-z]:)", data_file)) {
      # Relative path - resolve from project root
      data_file <- file.path(project_root, data_file)
    }
    data_file <- normalizePath(data_file, winslash = "/", mustWork = FALSE)
  }

  if (!is.null(output_file) && !is.na(output_file)) {
    if (!grepl("^(/|[A-Za-z]:)", output_file)) {
      # Relative path - resolve from project root
      output_file <- file.path(project_root, output_file)
    }
    output_file <- normalizePath(output_file, winslash = "/", mustWork = FALSE)
  }

  # Load variables definition
  variables <- openxlsx::read.xlsx(config_file, sheet = "Variables")

  # Validate variables sheet
  required_cols <- c("VariableName", "Type", "Label")
  missing_cols <- setdiff(required_cols, names(variables))
  if (length(missing_cols) > 0) {
    stop("Missing required columns in Variables sheet: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  # Extract outcome and driver variables
  outcome_vars <- variables$VariableName[variables$Type == "Outcome"]
  driver_vars <- variables$VariableName[variables$Type == "Driver"]

  if (length(outcome_vars) == 0) {
    stop("No outcome variable defined. Set Type='Outcome' for one variable.",
         call. = FALSE)
  }

  if (length(outcome_vars) > 1) {
    warning("Multiple outcome variables found. Using first: ", outcome_vars[1])
    outcome_vars <- outcome_vars[1]
  }

  if (length(driver_vars) == 0) {
    stop("No driver variables defined. Set Type='Driver' for independent variables.",
         call. = FALSE)
  }

  # Extract optional weight variable
  weight_vars <- variables$VariableName[variables$Type == "Weight"]
  weight_var <- if (length(weight_vars) == 0) {
    NULL
  } else {
    if (length(weight_vars) > 1) {
      warning("Multiple weight variables found. Using first: ", weight_vars[1])
    }
    weight_vars[1]
  }

  list(
    settings = settings_list,
    outcome_var = outcome_vars,
    driver_vars = driver_vars,
    weight_var = weight_var,
    variables = variables,
    data_file = data_file,
    output_file = output_file,
    project_root = project_root
  )
}
