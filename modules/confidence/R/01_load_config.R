# ==============================================================================
# CONFIG LOADER V1.0.0
# ==============================================================================
# Functions for loading and validating confidence analysis configuration
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# V1.0.0 - Initial release (2025-11-12)
#          - Load confidence_config.xlsx (3 sheets)
#          - Comprehensive input validation
#          - Question limit enforcement (200 max)
#          - Decimal separator validation
#
# DEPENDENCIES:
# - readxl (for Excel file reading)
# - utils.R (for validation helpers)
# ==============================================================================

CONFIG_LOADER_VERSION <- "1.0.0"

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

# Load required packages
if (!require("readxl", quietly = TRUE)) {
  stop("Package 'readxl' is required but not installed. Please install it with: install.packages('readxl')", call. = FALSE)
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

# ==============================================================================
# MAIN CONFIG LOADING FUNCTION
# ==============================================================================

#' Load confidence analysis configuration
#'
#' Reads and parses the confidence_config.xlsx file containing three sheets:
#' - File_Paths: Paths to input/output files
#' - Study_Settings: Study-level settings (DEFF, confidence level, etc.)
#' - Question_Analysis: Question-level analysis specifications (up to 200)
#'
#' @param config_path Character. Path to confidence_config.xlsx file
#'
#' @return Named list with three elements:
#'   \describe{
#'     \item{file_paths}{Data frame from File_Paths sheet}
#'     \item{study_settings}{Data frame from Study_Settings sheet}
#'     \item{question_analysis}{Data frame from Question_Analysis sheet (max 200 rows)}
#'   }
#'
#' @examples
#' config <- load_confidence_config("examples/confidence_config.xlsx")
#' names(config)  # Returns: "file_paths", "study_settings", "question_analysis"
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
load_confidence_config <- function(config_path) {
  # Validate config file exists
  if (!file.exists(config_path)) {
    stop(sprintf("Config file not found: %s", config_path), call. = FALSE)
  }

  # Validate file extension
  if (!grepl("\\.xlsx$", tolower(config_path))) {
    stop(sprintf("Config file must be .xlsx format: %s", config_path), call. = FALSE)
  }

  # Load each sheet
  cat(sprintf("Loading configuration from: %s\n", config_path))

  file_paths <- load_file_paths_sheet(config_path)
  study_settings <- load_study_settings_sheet(config_path)
  question_analysis <- load_question_analysis_sheet(config_path)
  population_margins <- load_population_margins_sheet(config_path)

  cat(sprintf("✓ Configuration loaded successfully\n"))
  if (!is.null(file_paths)) {
    cat(sprintf("  - File paths: %d parameters\n", nrow(file_paths)))
  } else {
    cat("  - File paths: (optional sheet not provided)\n")
  }
  cat(sprintf("  - Study settings: %d parameters\n", nrow(study_settings)))
  cat(sprintf("  - Question analysis: %d questions (max 200)\n", nrow(question_analysis)))
  if (!is.null(population_margins)) {
    cat(sprintf("  - Population margins: %d targets\n", nrow(population_margins)))
  } else {
    cat("  - Population margins: (optional sheet not provided)\n")
  }

  # Convert file_paths and study_settings to named lists for easier access
  file_paths_list <- if (!is.null(file_paths)) {
    as.list(setNames(as.character(file_paths$Value), file_paths$Parameter))
  } else {
    list()  # Empty list if no File_Paths sheet
  }
  study_settings_list <- as.list(setNames(study_settings$Value, study_settings$Setting))

  # Return structured config object
  config <- list(
    file_paths = file_paths_list,
    study_settings = study_settings_list,
    question_analysis = question_analysis,
    population_margins = population_margins,
    config_file_path = config_path
  )

  return(config)
}


# ==============================================================================
# SHEET-SPECIFIC LOADERS
# ==============================================================================

#' Load File_Paths sheet
#'
#' @param config_path Character. Path to config file
#' @return Data frame with Parameter and Value columns
#' @keywords internal
load_file_paths_sheet <- function(config_path) {
  sheet_name <- "File_Paths"

  # Check if sheet exists
  available_sheets <- readxl::excel_sheets(config_path)
  if (!sheet_name %in% available_sheets) {
    # Return NULL if File_Paths sheet doesn't exist (optional sheet)
    return(NULL)
  }

  # Read sheet
  df <- tryCatch(
    readxl::read_excel(config_path, sheet = sheet_name),
    error = function(e) {
      stop(sprintf("Failed to read '%s' sheet: %s", sheet_name, e$message), call. = FALSE)
    }
  )

  # Validate structure
  required_cols <- c("Parameter", "Value")
  if (!all(required_cols %in% names(df))) {
    stop(sprintf(
      "'%s' sheet must have columns: %s",
      sheet_name,
      paste(required_cols, collapse = ", ")
    ), call. = FALSE)
  }

  # Required parameters (simplified for standalone module)
  required_params <- c(
    "Data_File",
    "Output_File"
  )

  # Check all required parameters present
  missing_params <- setdiff(required_params, df$Parameter)
  if (length(missing_params) > 0) {
    stop(sprintf(
      "'%s' sheet missing required parameters: %s",
      sheet_name,
      paste(missing_params, collapse = ", ")
    ), call. = FALSE)
  }

  return(df)
}


#' Load Study_Settings sheet
#'
#' @param config_path Character. Path to config file
#' @return Data frame with Setting, Value, and Valid_Values columns
#' @keywords internal
load_study_settings_sheet <- function(config_path) {
  sheet_name <- "Study_Settings"

  # Read sheet
  df <- tryCatch(
    readxl::read_excel(config_path, sheet = sheet_name),
    error = function(e) {
      stop(sprintf("Failed to read '%s' sheet: %s", sheet_name, e$message), call. = FALSE)
    }
  )

  # Validate structure
  required_cols <- c("Setting", "Value")
  if (!all(required_cols %in% names(df))) {
    stop(sprintf(
      "'%s' sheet must have columns: %s",
      sheet_name,
      paste(required_cols, collapse = ", ")
    ), call. = FALSE)
  }

  # Required settings (using readable PascalCase names)
  required_settings <- c(
    "Calculate_Effective_N",
    "Multiple_Comparison_Adjustment",
    "Multiple_Comparison_Method",
    "Bootstrap_Iterations",
    "Confidence_Level",
    "Decimal_Separator"
  )

  # Check all required settings present
  missing_settings <- setdiff(required_settings, df$Setting)
  if (length(missing_settings) > 0) {
    stop(sprintf(
      "'%s' sheet missing required settings: %s",
      sheet_name,
      paste(missing_settings, collapse = ", ")
    ), call. = FALSE)
  }

  return(df)
}


#' Load Question_Analysis sheet
#'
#' @param config_path Character. Path to config file
#' @return Data frame with question analysis specifications (max 200 rows)
#' @keywords internal
load_question_analysis_sheet <- function(config_path) {
  sheet_name <- "Question_Analysis"

  # Read sheet
  df <- tryCatch(
    readxl::read_excel(config_path, sheet = sheet_name),
    error = function(e) {
      stop(sprintf("Failed to read '%s' sheet: %s", sheet_name, e$message), call. = FALSE)
    }
  )

  # Validate structure - required columns
  required_cols <- c(
    "Question_ID",
    "Statistic_Type",
    "Run_MOE",
    "Run_Bootstrap",
    "Run_Credible"
  )

  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "'%s' sheet missing required columns: %s",
      sheet_name,
      paste(missing_cols, collapse = ", ")
    ), call. = FALSE)
  }

  # Remove completely empty rows
  df <- df[!is.na(df$Question_ID) & df$Question_ID != "", ]

  # Check question limit (200 max)
  n_questions <- nrow(df)
  if (n_questions > 200) {
    stop(sprintf(
      "Question limit exceeded: %d questions specified (maximum 200)",
      n_questions
    ), call. = FALSE)
  }

  if (n_questions == 0) {
    stop("'Question_Analysis' sheet contains no questions", call. = FALSE)
  }

  return(df)
}


# ==============================================================================
# CONFIGURATION VALIDATION
# ==============================================================================

#' Validate complete configuration
#'
#' Performs comprehensive validation of all configuration values including:
#' - File paths exist and are readable
#' - Study settings are valid
#' - Question specifications are valid
#' - Question limit (200 max) is enforced
#' - At least one method (MOE/Bootstrap/Credible) is selected per question
#'
#' @param config List. Output from load_confidence_config()
#'
#' @return List with elements:
#'   \describe{
#'     \item{valid}{Logical. TRUE if all validation passed}
#'     \item{errors}{Character vector. Error messages (empty if valid)}
#'     \item{warnings}{Character vector. Warning messages}
#'   }
#'
#' @examples
#' config <- load_confidence_config("config.xlsx")
#' validation <- validate_config(config)
#' if (!validation$valid) {
#'   stop(paste(validation$errors, collapse = "\n"))
#' }
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
validate_config <- function(config) {
  errors <- character()
  warnings <- character()

  # Validate file paths
  file_path_result <- validate_file_paths(config$file_paths)
  errors <- c(errors, file_path_result$errors)
  warnings <- c(warnings, file_path_result$warnings)

  # Validate study settings
  study_settings_result <- validate_study_settings(config$study_settings)
  errors <- c(errors, study_settings_result$errors)
  warnings <- c(warnings, study_settings_result$warnings)

  # Validate question analysis
  question_result <- validate_question_analysis(config$question_analysis)
  errors <- c(errors, question_result$errors)
  warnings <- c(warnings, question_result$warnings)

  # Return validation result
  return(list(
    valid = length(errors) == 0,
    errors = errors,
    warnings = warnings
  ))
}


#' Validate file paths
#' @keywords internal
validate_file_paths <- function(file_paths_df) {
  errors <- character()
  warnings <- character()

  # If file_paths_df is empty (File_Paths sheet was optional), return valid
  if (is.null(file_paths_df) || length(file_paths_df) == 0) {
    return(list(errors = errors, warnings = warnings))
  }

  # Convert to named list for easier access
  paths <- setNames(file_paths_df$Value, file_paths_df$Parameter)

  # Check input data file exists
  data_file <- paths[["Data_File"]]

  if (is.na(data_file) || data_file == "") {
    errors <- c(errors, "'Data_File' cannot be empty")
  } else if (!file.exists(data_file)) {
    errors <- c(errors, sprintf("'Data_File' not found: %s", data_file))
  }

  # Check output file parent directory exists
  output_file <- paths[["Output_File"]]
  if (!is.na(output_file) && output_file != "") {
    output_dir <- dirname(output_file)
    if (output_dir != "." && !dir.exists(output_dir)) {
      warnings <- c(warnings, sprintf(
        "Output directory does not exist: %s (will be created)",
        output_dir
      ))
    }
  } else {
    errors <- c(errors, "'output_file' cannot be empty")
  }

  return(list(errors = errors, warnings = warnings))
}


#' Validate study settings
#' @keywords internal
validate_study_settings <- function(study_settings_df) {
  errors <- character()
  warnings <- character()

  # Convert to named list
  settings <- setNames(study_settings_df$Value, study_settings_df$Setting)

  # Validate Calculate_Effective_N
  calc_eff <- toupper(as.character(settings[["Calculate_Effective_N"]]))
  if (!calc_eff %in% c("Y", "N")) {
    errors <- c(errors, "Calculate_Effective_N must be 'Y' or 'N'")
  }

  # Validate Multiple_Comparison_Adjustment
  multi_comp <- toupper(as.character(settings[["Multiple_Comparison_Adjustment"]]))
  if (!multi_comp %in% c("Y", "N")) {
    errors <- c(errors, "Multiple_Comparison_Adjustment must be 'Y' or 'N'")
  }

  # Validate Multiple_Comparison_Method (only if Multiple_Comparison_Adjustment = Y)
  if (multi_comp == "Y") {
    adj_method <- as.character(settings[["Multiple_Comparison_Method"]])
    if (!adj_method %in% c("Bonferroni", "Holm", "FDR")) {
      errors <- c(errors, "Multiple_Comparison_Method must be 'Bonferroni', 'Holm', or 'FDR'")
    }
  }

  # Validate Bootstrap_Iterations
  boot_iter <- suppressWarnings(as.numeric(settings[["Bootstrap_Iterations"]]))
  if (is.na(boot_iter)) {
    errors <- c(errors, "Bootstrap_Iterations must be numeric")
  } else if (boot_iter < 1000 || boot_iter > 10000) {
    errors <- c(errors, "Bootstrap_Iterations must be between 1000 and 10000")
  }

  # Validate Confidence_Level
  conf_level <- suppressWarnings(as.numeric(settings[["Confidence_Level"]]))
  if (is.na(conf_level)) {
    errors <- c(errors, "Confidence_Level must be numeric")
  } else if (!conf_level %in% c(0.90, 0.95, 0.99)) {
    errors <- c(errors, "Confidence_Level must be 0.90, 0.95, or 0.99")
  }

  # Validate Decimal_Separator
  dec_sep <- as.character(settings[["Decimal_Separator"]])
  if (!dec_sep %in% c(".", ",")) {
    errors <- c(errors, "Decimal_Separator must be '.' or ','")
  }

  # Validate random_seed (optional)
  if ("random_seed" %in% study_settings_df$Setting) {
    seed <- settings[["random_seed"]]
    if (!is.na(seed) && seed != "") {
      seed_num <- suppressWarnings(as.numeric(seed))
      if (is.na(seed_num)) {
        errors <- c(errors, "random_seed must be numeric or empty")
      }
    }
  }

  return(list(errors = errors, warnings = warnings))
}


#' Validate question analysis specifications
#' @keywords internal
validate_question_analysis <- function(question_df) {
  errors <- character()
  warnings <- character()

  n_questions <- nrow(question_df)

  # Validate each question row
  for (i in 1:n_questions) {
    row <- question_df[i, ]
    q_id <- row$Question_ID

    # Validate Question_ID
    if (is.na(q_id) || q_id == "") {
      errors <- c(errors, sprintf("Row %d: Question_ID cannot be empty", i))
      next
    }

    # Validate Statistic_Type
    stat_type <- tolower(as.character(row$Statistic_Type))
    if (!stat_type %in% c("proportion", "mean", "nps")) {
      errors <- c(errors, sprintf(
        "%s: Statistic_Type must be 'proportion', 'mean', or 'nps'",
        q_id
      ))
    }

    # Validate Categories (required for proportion, must be empty for mean/nps)
    if (stat_type == "proportion") {
      if (is.na(row$Categories) || row$Categories == "") {
        errors <- c(errors, sprintf(
          "%s: Categories required for Statistic_Type='proportion'",
          q_id
        ))
      }
    }

    # Validate NPS codes (required for nps type)
    if (stat_type == "nps") {
      if (is.na(row$Promoter_Codes) || row$Promoter_Codes == "") {
        errors <- c(errors, sprintf("%s: Promoter_Codes required for NPS", q_id))
      }
      if (is.na(row$Detractor_Codes) || row$Detractor_Codes == "") {
        errors <- c(errors, sprintf("%s: Detractor_Codes required for NPS", q_id))
      }
    }

    # Validate at least one method selected
    run_moe <- toupper(as.character(row$Run_MOE))
    run_boot <- toupper(as.character(row$Run_Bootstrap))
    run_cred <- toupper(as.character(row$Run_Credible))

    if (!any(c(run_moe, run_boot, run_cred) == "Y")) {
      errors <- c(errors, sprintf(
        "%s: At least one method (Run_MOE, Run_Bootstrap, Run_Credible) must be 'Y'",
        q_id
      ))
    }

    # Validate Run_* columns
    for (col in c("Run_MOE", "Run_Bootstrap", "Run_Credible", "Use_Wilson")) {
      if (col %in% names(row)) {
        val <- toupper(as.character(row[[col]]))
        if (!is.na(val) && val != "" && !val %in% c("Y", "N")) {
          errors <- c(errors, sprintf("%s: %s must be 'Y' or 'N'", q_id, col))
        }
      }
    }

    # Validate priors (if Run_Credible = Y and Prior_Mean specified)
    if (run_cred == "Y" && !is.na(row$Prior_Mean) && row$Prior_Mean != "") {
      prior_mean <- suppressWarnings(as.numeric(row$Prior_Mean))
      if (is.na(prior_mean)) {
        errors <- c(errors, sprintf("%s: Prior_Mean must be numeric", q_id))
      } else {
        # Validate prior_mean range based on statistic type
        if (stat_type == "proportion" && (prior_mean < 0 || prior_mean > 1)) {
          errors <- c(errors, sprintf(
            "%s: Prior_Mean for proportion must be between 0 and 1",
            q_id
          ))
        }
        if (stat_type == "nps" && (prior_mean < -100 || prior_mean > 100)) {
          errors <- c(errors, sprintf(
            "%s: Prior_Mean for NPS must be between -100 and 100",
            q_id
          ))
        }
        # For means and NPS, Prior_SD is required
        if (stat_type %in% c("mean", "nps")) {
          if (is.na(row$Prior_SD) || row$Prior_SD == "") {
            errors <- c(errors, sprintf(
              "%s: Prior_SD required when Prior_Mean specified for %s",
              q_id,
              stat_type
            ))
          } else {
            prior_sd <- suppressWarnings(as.numeric(row$Prior_SD))
            if (is.na(prior_sd) || prior_sd <= 0) {
              errors <- c(errors, sprintf(
                "%s: Prior_SD must be positive numeric",
                q_id
              ))
            }
          }
        }
      }
    }
  }

  return(list(errors = errors, warnings = warnings))
}


#' Load Population_Margins sheet (optional)
#'
#' Loads population margin targets for representativeness checking.
#' This sheet is OPTIONAL - if not present, no margin comparison will be performed.
#'
#' @param config_path Character. Path to config file
#' @return Data frame with Population_Margins, or NULL if sheet doesn't exist
#'
#' Expected columns:
#' - Variable: Variable name in dataset (e.g., "Gender", "Age_Group")
#' - Category_Label: Human-readable label (e.g., "Male", "18-24")
#' - Category_Code: Code as it appears in data (e.g., "1", "M")
#' - Target_Prop: Target proportion (0-1, not percentage)
#' - Include: "Y"/"N" to enable/disable this margin
#'
#' @keywords internal
load_population_margins_sheet <- function(config_path) {
  sheet_name <- "Population_Margins"

  # Check if sheet exists (optional sheet)
  sheet_names <- tryCatch(
    readxl::excel_sheets(config_path),
    error = function(e) character(0)
  )

  if (!sheet_name %in% sheet_names) {
    return(NULL)  # Sheet not present, return NULL silently
  }

  # Read sheet
  df <- tryCatch(
    readxl::read_excel(config_path, sheet = sheet_name),
    error = function(e) {
      warning(sprintf(
        "Failed to read '%s' sheet: %s\nMargin comparison will be skipped.",
        sheet_name,
        conditionMessage(e)
      ))
      return(NULL)
    }
  )

  if (is.null(df) || nrow(df) == 0) {
    return(NULL)
  }

  # Validate required columns
  required_cols <- c("Variable", "Category_Label", "Target_Prop")
  missing_cols <- setdiff(required_cols, names(df))

  if (length(missing_cols) > 0) {
    warning(sprintf(
      "'%s' sheet missing required columns: %s\nMargin comparison will be skipped.",
      sheet_name,
      paste(missing_cols, collapse = ", ")
    ))
    return(NULL)
  }

  # Add optional columns if missing
  if (!"Category_Code" %in% names(df)) {
    df$Category_Code <- df$Category_Label  # Default to label if no code
  }

  if (!"Include" %in% names(df)) {
    df$Include <- "Y"  # Default to include all if not specified
  }

  # Filter to only included rows
  df <- df[!is.na(df$Include) & toupper(df$Include) == "Y", , drop = FALSE]

  if (nrow(df) == 0) {
    return(NULL)  # No targets to include
  }

  # Validate Target_Prop values
  errors <- character()

  for (i in seq_len(nrow(df))) {
    row <- df[i, ]
    var <- as.character(row$Variable)
    cat_label <- as.character(row$Category_Label)

    # Check Target_Prop is numeric and in range [0, 1]
    target_prop <- suppressWarnings(as.numeric(row$Target_Prop))

    if (is.na(target_prop)) {
      errors <- c(errors, sprintf(
        "%s - %s: Target_Prop must be numeric (got '%s')",
        var, cat_label, row$Target_Prop
      ))
    } else if (target_prop < 0 || target_prop > 1) {
      errors <- c(errors, sprintf(
        "%s - %s: Target_Prop must be between 0 and 1 (got %.3f)",
        var, cat_label, target_prop
      ))
    }

    # Convert to numeric
    df$Target_Prop[i] <- target_prop
  }

  # Stop if validation errors
  if (length(errors) > 0) {
    stop(sprintf(
      "Population_Margins validation errors:\n%s",
      paste("  -", errors, collapse = "\n")
    ), call. = FALSE)
  }

  # Convert Category_Code to character (handles both numeric and text)
  df$Category_Code <- as.character(df$Category_Code)
  df$Category_Label <- as.character(df$Category_Label)
  df$Variable <- as.character(df$Variable)

  # Validation: Check that proportions sum to ~1 for each variable
  var_sums <- tapply(df$Target_Prop, df$Variable, sum)
  for (var_name in names(var_sums)) {
    sum_val <- var_sums[var_name]
    if (abs(sum_val - 1.0) > 0.01) {
      warning(sprintf(
        "Population_Margins: Variable '%s' proportions sum to %.3f (should be 1.0)",
        var_name, sum_val
      ))
    }
  }

  return(df)
}


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Get setting value from study settings
#'
#' Retrieves a setting value by name from study settings data frame
#'
#' @param study_settings_df Data frame. Study settings
#' @param setting_name Character. Name of setting
#' @param default Any. Default value if setting not found
#'
#' @return Setting value (type depends on setting)
#'
#' @keywords internal
get_setting_value <- function(study_settings_df, setting_name, default = NULL) {
  idx <- which(study_settings_df$Setting == setting_name)

  if (length(idx) == 0) {
    return(default)
  }

  value <- study_settings_df$Value[idx[1]]

  # Handle NA or empty string
  if (is.na(value) || value == "") {
    return(default)
  }

  return(value)
}


#' Get file path from file paths data frame
#'
#' @param file_paths_df Data frame. File paths
#' @param param_name Character. Parameter name
#'
#' @return Character. File path
#'
#' @keywords internal
get_file_path <- function(file_paths_df, param_name) {
  idx <- which(file_paths_df$Parameter == param_name)

  if (length(idx) == 0) {
    stop(sprintf("File path parameter not found: %s", param_name), call. = FALSE)
  }

  return(file_paths_df$Value[idx[1]])
}
