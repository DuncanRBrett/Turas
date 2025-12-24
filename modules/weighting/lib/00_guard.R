# ==============================================================================
# WEIGHTING MODULE - TRS GUARD (No Silent Failures)
# ==============================================================================
# Implements TURAS Reliability Standard (TRS) v1.0 for weighting module
# All validation happens upfront before any calculations
# Part of TURAS Weighting Module v1.0
# ==============================================================================

# Try to load shared TRS infrastructure if available
.load_trs_infrastructure <- function() {
  turas_root <- tryCatch({
    # Try environment variable first
    root <- Sys.getenv("TURAS_ROOT", "")
    if (nzchar(root) && dir.exists(file.path(root, "modules"))) {
      return(root)
    }

    # Try to find from current location
    wd <- getwd()
    for (i in 0:5) {
      check <- if (i == 0) wd else dirname(wd)
      if (dir.exists(file.path(check, "modules", "shared"))) {
        return(check)
      }
      wd <- dirname(wd)
    }
    return(NULL)
  }, error = function(e) NULL)

  if (!is.null(turas_root)) {
    trs_file <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
    log_file <- file.path(turas_root, "modules", "shared", "lib", "turas_log.R")

    if (file.exists(trs_file) && !exists("turas_refuse", mode = "function")) {
      source(trs_file, local = FALSE)
    }
    if (file.exists(log_file) && !exists("turas_log", mode = "function")) {
      source(log_file, local = FALSE)
    }
  }
}

# Load TRS on source
.load_trs_infrastructure()

# ==============================================================================
# WEIGHTING-SPECIFIC REFUSE FUNCTION
# ==============================================================================

#' Refuse with Weighting Module Context
#'
#' Wrapper for turas_refuse that adds weighting module context.
#' Falls back to standard stop() if TRS infrastructure not available.
#'
#' @param code TRS refusal code (must start with valid prefix)
#' @param title Short title
#' @param problem Description of what went wrong
#' @param why_it_matters Analytical impact
#' @param how_to_fix Steps to resolve
#' @param ... Additional arguments passed to turas_refuse
#' @export
weighting_refuse <- function(code, title, problem, why_it_matters, how_to_fix, ...) {
  if (exists("turas_refuse", mode = "function")) {
    turas_refuse(
      code = code,
      title = title,
      problem = problem,
      why_it_matters = why_it_matters,
      how_to_fix = how_to_fix,
      module = "WEIGHTING",
      ...
    )
  } else {
    # Fallback: standard stop with formatted message
    msg <- paste0(
      "\n", strrep("=", 70), "\n",
      "  [REFUSE] ", code, ": ", title, "\n",
      strrep("=", 70), "\n\n",
      "Problem:\n  ", problem, "\n\n",
      "Why it matters:\n  ", why_it_matters, "\n\n",
      "How to fix:\n  ",
      if (length(how_to_fix) > 1) {
        paste(paste0("  ", seq_along(how_to_fix), ". ", how_to_fix), collapse = "\n")
      } else {
        how_to_fix
      },
      "\n\n", strrep("=", 70), "\n"
    )
    stop(msg, call. = FALSE)
  }
}

# ==============================================================================
# INPUT VALIDATION GUARDS
# ==============================================================================

#' Guard: Validate Config File Exists
#' @keywords internal
guard_config_file <- function(config_file) {
  if (is.null(config_file) || !is.character(config_file) || length(config_file) != 1) {
    weighting_refuse(
      code = "CFG_INVALID_PATH",
      title = "Invalid Configuration Path",
      problem = "Config file path must be a single character string.",
      why_it_matters = "Cannot locate configuration without valid path.",
      how_to_fix = "Provide the path to your Weight_Config.xlsx file."
    )
  }

  if (!file.exists(config_file)) {
    weighting_refuse(
      code = "IO_CONFIG_NOT_FOUND",
      title = "Configuration File Not Found",
      problem = sprintf("Config file not found: %s", config_file),
      why_it_matters = "Cannot proceed without configuration file.",
      how_to_fix = c(
        "Check that the file path is correct",
        "Ensure the file exists at the specified location",
        sprintf("Current working directory: %s", getwd())
      )
    )
  }

  invisible(TRUE)
}

#' Guard: Validate Required Sheet Exists
#' @keywords internal
guard_required_sheet <- function(config_file, sheet_name, available_sheets) {
  if (!sheet_name %in% available_sheets) {
    weighting_refuse(
      code = "CFG_MISSING_SHEET",
      title = "Required Sheet Missing",
      problem = sprintf("The '%s' sheet is required but not found in config file.", sheet_name),
      why_it_matters = "Configuration is incomplete without this sheet.",
      how_to_fix = c(
        sprintf("Add a '%s' sheet to your config file", sheet_name),
        "Use the template generator to create a valid config file"
      ),
      expected = sheet_name,
      observed = available_sheets
    )
  }
  invisible(TRUE)
}

#' Guard: Validate Data File Exists
#' @keywords internal
guard_data_file <- function(data_file) {
  if (is.null(data_file) || !file.exists(data_file)) {
    weighting_refuse(
      code = "IO_DATA_NOT_FOUND",
      title = "Survey Data File Not Found",
      problem = sprintf("Data file not found: %s", data_file),
      why_it_matters = "Cannot calculate weights without survey data.",
      how_to_fix = c(
        "Check that the data_file path in General settings is correct",
        "Paths are resolved relative to the config file location",
        "Verify the file exists and is readable"
      )
    )
  }
  invisible(TRUE)
}

#' Guard: Validate Required Columns Exist
#' @keywords internal
guard_required_columns <- function(df, required_cols, sheet_name) {
  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    weighting_refuse(
      code = "CFG_MISSING_COLUMNS",
      title = "Required Columns Missing",
      problem = sprintf("Sheet '%s' missing required columns.", sheet_name),
      why_it_matters = "Cannot parse configuration without required columns.",
      how_to_fix = c(
        sprintf("Add the missing columns to the '%s' sheet", sheet_name),
        "Refer to the Template Reference for required columns"
      ),
      expected = required_cols,
      observed = names(df),
      missing = missing
    )
  }
  invisible(TRUE)
}

#' Guard: Validate Variable Exists in Data
#' @keywords internal
guard_variable_exists <- function(data, variable, context) {
  if (!variable %in% names(data)) {
    weighting_refuse(
      code = "DATA_COLUMN_NOT_FOUND",
      title = "Variable Not Found in Data",
      problem = sprintf("Variable '%s' not found in survey data.", variable),
      why_it_matters = sprintf("Cannot calculate %s without this variable.", context),
      how_to_fix = c(
        "Check the variable name is spelled correctly",
        "Variable names are case-sensitive",
        "Verify the variable exists in your data file"
      ),
      expected = variable,
      observed = head(names(data), 20)
    )
  }
  invisible(TRUE)
}

#' Guard: Validate No Missing Values
#' @keywords internal
guard_no_missing_values <- function(data, variable, context) {
  n_missing <- sum(is.na(data[[variable]]))
  if (n_missing > 0) {
    pct <- round(100 * n_missing / nrow(data), 1)
    weighting_refuse(
      code = "DATA_MISSING_VALUES",
      title = "Missing Values Not Allowed",
      problem = sprintf("Variable '%s' has %d missing values (%.1f%%).",
                       variable, n_missing, pct),
      why_it_matters = sprintf("%s requires complete data for weighting variables.", context),
      how_to_fix = c(
        "Remove rows with missing values before weighting",
        "Impute missing values before weighting",
        "Create a 'Missing' category if appropriate"
      ),
      details = sprintf("Missing count: %d of %d rows", n_missing, nrow(data))
    )
  }
  invisible(TRUE)
}

#' Guard: Validate Rim Targets Sum to 100
#' @keywords internal
guard_rim_targets_sum <- function(variable, categories, percentages) {
  total <- sum(percentages, na.rm = TRUE)
  if (abs(total - 100) > 0.1) {
    weighting_refuse(
      code = "CFG_INVALID_RIM_TARGETS",
      title = "Rim Targets Do Not Sum to 100",
      problem = sprintf("Targets for variable '%s' sum to %.2f%%, not 100%%.",
                       variable, total),
      why_it_matters = "Rim targets must represent complete marginal distribution.",
      how_to_fix = c(
        "Adjust target percentages to sum to exactly 100",
        sprintf("Current sum: %.2f%%", total)
      ),
      details = paste(
        sprintf("%s: %.1f%%", categories, percentages),
        collapse = ", "
      )
    )
  }
  invisible(TRUE)
}

#' Guard: Validate anesrake Package Available
#' @keywords internal
guard_anesrake_available <- function() {
  if (!requireNamespace("anesrake", quietly = TRUE)) {
    weighting_refuse(
      code = "PKG_ANESRAKE_MISSING",
      title = "Required Package Not Installed",
      problem = "The 'anesrake' package is required for rim weighting but is not installed.",
      why_it_matters = "Rim weighting uses anesrake for iterative proportional fitting.",
      how_to_fix = c(
        "Install the package: install.packages('anesrake')",
        "Then re-run your weighting analysis"
      )
    )
  }
  invisible(TRUE)
}

#' Guard: Validate Rim Weighting Convergence
#' @keywords internal
guard_rim_convergence <- function(converged, iterations, max_iterations, force_convergence) {
  if (!converged && !force_convergence) {
    weighting_refuse(
      code = "MODEL_RIM_NO_CONVERGENCE",
      title = "Rim Weighting Did Not Converge",
      problem = sprintf("Rim weighting did not converge after %d iterations.", iterations),
      why_it_matters = "Target margins will not be exactly achieved. Results may be biased.",
      how_to_fix = c(
        sprintf("Increase max_iterations (currently %d) in Advanced_Settings", max_iterations),
        "Relax convergence_tolerance (try 0.02 or higher)",
        "Reduce the number of rim variables (maximum 5 recommended)",
        "Set force_convergence=Y to accept approximate weights (use with caution)",
        "Check for impossible target combinations"
      )
    )
  }
  invisible(TRUE)
}

#' Guard: Validate Positive Population Sizes
#' @keywords internal
guard_positive_population <- function(strata, population_sizes) {
  invalid <- strata[population_sizes <= 0 | is.na(population_sizes)]
  if (length(invalid) > 0) {
    weighting_refuse(
      code = "CFG_INVALID_POPULATION",
      title = "Invalid Population Sizes",
      problem = "Population sizes must be positive numbers.",
      why_it_matters = "Cannot calculate design weights with zero or negative population.",
      how_to_fix = c(
        "Correct the population_size values in Design_Targets",
        "All values must be positive integers"
      ),
      details = sprintf("Invalid strata: %s", paste(invalid, collapse = ", "))
    )
  }
  invisible(TRUE)
}

#' Guard: Validate Categories Match Between Config and Data
#' @keywords internal
guard_categories_match <- function(config_categories, data_categories, variable, context) {
  missing_in_data <- setdiff(config_categories, data_categories)
  missing_in_config <- setdiff(data_categories, config_categories)

  if (length(missing_in_data) > 0) {
    weighting_refuse(
      code = "DATA_CATEGORY_MISMATCH",
      title = "Categories Not Found in Data",
      problem = sprintf("Categories in config for '%s' not found in data.", variable),
      why_it_matters = sprintf("Cannot calculate %s for non-existent categories.", context),
      how_to_fix = c(
        "Check category values match exactly (case-sensitive)",
        "Remove extra spaces from category values",
        "Verify categories exist in your data"
      ),
      expected = config_categories,
      observed = data_categories,
      missing = missing_in_data
    )
  }

  if (length(missing_in_config) > 0 && context == "rim weights") {
    weighting_refuse(
      code = "CFG_INCOMPLETE_TARGETS",
      title = "Missing Categories in Targets",
      problem = sprintf("Data categories for '%s' not covered in targets.", variable),
      why_it_matters = "All categories must have targets for rim weighting.",
      how_to_fix = c(
        "Add targets for all categories in the data",
        "Or recode data to collapse categories"
      ),
      expected = data_categories,
      observed = config_categories,
      unmapped = missing_in_config
    )
  }

  invisible(TRUE)
}

# ==============================================================================
# WEIGHTING MODULE LOG FUNCTION
# ==============================================================================

#' Log Message with Weighting Context
#'
#' @param level Log level: INFO, PARTIAL, REFUSE, DEBUG
#' @param message Log message
#' @param code Optional TRS code
#' @param verbose Print if TRUE
#' @export
weighting_log <- function(level, message, code = NULL, verbose = TRUE) {
  if (exists("turas_log", mode = "function")) {
    turas_log(level, "WEIGHTING", message, code = code, verbose = verbose)
  } else if (verbose) {
    prefix <- sprintf("[%s] WEIGHTING: ", level)
    if (!is.null(code)) prefix <- sprintf("[%s] %s: ", level, code)
    cat(prefix, message, "\n", sep = "")
  }
  invisible(NULL)
}

# ==============================================================================
# GUARD STATE FOR COLLECTING WARNINGS
# ==============================================================================

#' Initialize Weighting Guard State
#' @export
weighting_guard_init <- function() {
  if (exists("guard_init", mode = "function")) {
    guard_init("WEIGHTING")
  } else {
    list(
      module = "WEIGHTING",
      warnings = character(0),
      issues = character(0),
      timestamp = Sys.time()
    )
  }
}

#' Add Warning to Guard State
#' @export
weighting_guard_warn <- function(guard, message) {
  if (exists("guard_warn", mode = "function")) {
    guard_warn(guard, message)
  } else {
    guard$warnings <- c(guard$warnings, message)
  }
  invisible(guard)
}
