# ==============================================================================
# KEY DRIVER CONFIG LOADER
# ==============================================================================

#' Load Key Driver Configuration
#'
#' Loads and validates key driver analysis configuration.
#'
#' @param config_file Path to configuration Excel file
#' @return List with validated configuration
#' @keywords internal
load_keydriver_config <- function(config_file) {

  if (!file.exists(config_file)) {
    stop("Configuration file not found: ", config_file, call. = FALSE)
  }

  # Load settings
  settings <- openxlsx::read.xlsx(config_file, sheet = "Settings")
  settings_list <- setNames(as.list(settings$Value), settings$Setting)

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

  list(
    settings = settings_list,
    outcome_var = outcome_vars,
    driver_vars = driver_vars,
    variables = variables
  )
}
