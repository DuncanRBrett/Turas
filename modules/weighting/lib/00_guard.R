# ==============================================================================
# WEIGHTING MODULE - TRS GUARD (No Silent Failures)
# ==============================================================================
# Implements TURAS Reliability Standard (TRS) v1.0 for weighting module
# All validation happens upfront before any calculations
# Part of TURAS Weighting Module v3.0
#
# REQUIRES: Shared TRS infrastructure must be loaded before this file is sourced.
#           See run_weighting.R::load_shared_infrastructure()
# ==============================================================================

# ==============================================================================
# WEIGHTING-SPECIFIC REFUSE FUNCTION
# ==============================================================================

#' Refuse with Weighting Module Context
#'
#' Wrapper for turas_refuse that adds weighting module context.
#' Shared TRS infrastructure MUST be loaded before calling this function.
#'
#' @param code TRS refusal code (must start with valid prefix)
#' @param title Short title
#' @param problem Description of what went wrong
#' @param why_it_matters Analytical impact
#' @param how_to_fix Steps to resolve
#' @param ... Additional arguments passed to turas_refuse
#' @export
weighting_refuse <- function(code, title, problem, why_it_matters, how_to_fix, ...) {
  turas_refuse(
    code = code,
    title = title,
    problem = problem,
    why_it_matters = why_it_matters,
    how_to_fix = how_to_fix,
    module = "WEIGHTING",
    ...
  )
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

# Tolerance constant for rim target sums (percentage points)
RIM_TARGET_SUM_TOLERANCE <- 0.5

#' Guard: Validate Rim Targets Sum to 100
#' @keywords internal
guard_rim_targets_sum <- function(variable, categories, percentages) {
  total <- sum(percentages, na.rm = TRUE)
  if (abs(total - 100) > RIM_TARGET_SUM_TOLERANCE) {
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

#' Guard: Validate survey Package Available
#' @keywords internal
guard_survey_available <- function() {
  if (!requireNamespace("survey", quietly = TRUE)) {
    weighting_refuse(
      code = "PKG_SURVEY_MISSING",
      title = "Required Package Not Installed",
      problem = "The 'survey' package is required for rim weighting but is not installed.",
      why_it_matters = "Rim weighting uses survey::calibrate() for robust calibration.",
      how_to_fix = c(
        "Install the package: install.packages('survey')",
        "Then re-run your weighting analysis"
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
# LOOKUP-FILE INTEGRITY GUARDS
# ==============================================================================
# The weighting module's deliverable is a lookup file of respondent IDs and
# weight columns, which tabs merges back onto the survey data. Two things must
# hold for that merge to be safe, and neither was checked.

#' Validate the Respondent ID Column
#'
#' Refuses when the ID column cannot key the merge back into the survey data:
#' when it is missing, when it is entirely blank, or when it repeats.
#'
#' A duplicated ID is the dangerous one. tabs joins the lookup file on this
#' column, so a repeat makes the join fan out — one weight row matching several
#' respondents, or several weight rows matching one — and the weights land on
#' the wrong people. The merged file looks perfectly well-formed afterwards, so
#' nothing downstream can catch it.
#'
#' @param data Data frame, the survey data as loaded
#' @param id_column Character, resolved ID column name
#' @param auto_detected Logical, TRUE when the column was defaulted to column 1
#'   rather than named in the config. The advice differs: a defaulted column that
#'   repeats usually means it is not an ID at all.
#' @return TRUE invisibly if the column can key the merge; refuses otherwise
#' @export
validate_id_column <- function(data, id_column, auto_detected = FALSE) {

  if (is.null(id_column) || is.na(id_column) || !nzchar(id_column)) {
    weighting_refuse(
      code = "CFG_MISSING_ID_COLUMN",
      title = "No respondent ID column",
      problem = "id_column is not set and no column could be defaulted to.",
      why_it_matters = "The lookup file is keyed on the respondent ID so tabs can merge the weights back. Without one there is nothing to merge on.",
      how_to_fix = "Set id_column in the General sheet to the column holding the respondent identifier."
    )
  }

  if (!id_column %in% names(data)) {
    weighting_refuse(
      code = "CFG_INVALID_ID_COLUMN",
      title = "Respondent ID column not found",
      problem = sprintf("id_column '%s' is not a column in the data.", id_column),
      why_it_matters = "The lookup file is keyed on the respondent ID so tabs can merge the weights back.",
      how_to_fix = sprintf("Set id_column in the General sheet to one of: %s",
                           paste(head(names(data), 15), collapse = ", "))
    )
  }

  ids <- data[[id_column]]

  n_missing <- sum(is.na(ids) | !nzchar(trimws(as.character(ids))))
  if (n_missing > 0) {
    weighting_refuse(
      code = "DATA_MISSING_ID",
      title = "Some respondents have no ID",
      problem = sprintf("%d of %d rows have a missing or blank value in id_column '%s'.",
                        n_missing, nrow(data), id_column),
      why_it_matters = "A row with no ID cannot be matched back to a respondent, so its weight either goes nowhere or attaches to whichever other row shares the blank.",
      how_to_fix = sprintf("Fill in '%s' for every row, or remove those rows from the data before weighting.", id_column)
    )
  }

  dup_ids <- unique(ids[duplicated(ids)])
  if (length(dup_ids) > 0) {
    n_rows_affected <- sum(ids %in% dup_ids)

    how <- if (auto_detected) {
      sprintf("id_column was not set in the General sheet, so it defaulted to the first column ('%s') — and that column repeats, which usually means it is not a respondent identifier. Set id_column explicitly to the column holding the respondent ID.", id_column)
    } else {
      sprintf("Make '%s' unique before weighting: de-duplicate the data, or point id_column at a column that identifies each respondent exactly once.", id_column)
    }

    weighting_refuse(
      code = "DATA_DUPLICATE_IDS",
      title = "Respondent IDs are not unique",
      problem = sprintf("id_column '%s' has %d repeated value%s across %d of %d rows. First few: %s",
                        id_column, length(dup_ids), if (length(dup_ids) == 1) "" else "s",
                        n_rows_affected, nrow(data),
                        paste(head(as.character(dup_ids), 5), collapse = ", ")),
      why_it_matters = "tabs merges this lookup file onto the survey data by respondent ID. A repeated ID makes that join fan out — one weight row matching several respondents, or several matching one — so weights land on the wrong people. The merged file looks well-formed afterwards, so nothing downstream can detect it.",
      how_to_fix = how
    )
  }

  invisible(TRUE)
}

#' Validate Weight Column Names Against the Data
#'
#' Refuses when a weight_name would overwrite a column that already exists.
#' The weight is attached with \code{data[[weight_name]] <- weights}, which
#' silently replaces an existing column — and if the name matches the ID column
#' it destroys the merge key before the file is written.
#'
#' @param data Data frame, the survey data as loaded
#' @param weight_names Character vector of weight names from the config
#' @param id_column Character, resolved ID column name
#' @return TRUE invisibly if the names are safe; refuses otherwise
#' @export
validate_weight_names <- function(data, weight_names, id_column) {

  hits_id <- weight_names[weight_names == id_column]
  if (length(hits_id) > 0) {
    weighting_refuse(
      code = "CFG_WEIGHT_NAME_IS_ID",
      title = "A weight is named after the ID column",
      problem = sprintf("weight_name '%s' is the same as id_column '%s'.",
                        hits_id[1], id_column),
      why_it_matters = "The weight is written into the data under that name, so it would overwrite the respondent IDs before the lookup file is saved — leaving a file whose key column contains weights.",
      how_to_fix = "Rename the weight in Weight_Specifications to something other than the ID column."
    )
  }

  hits_col <- intersect(weight_names, names(data))
  if (length(hits_col) > 0) {
    weighting_refuse(
      code = "CFG_WEIGHT_NAME_COLLISION",
      title = "A weight would overwrite an existing column",
      problem = sprintf("These weight_names already exist as columns in the data: %s",
                        paste(sprintf("'%s'", hits_col), collapse = ", ")),
      why_it_matters = "The weight is attached with data[[weight_name]] <- weights, which replaces the existing column without a word. If that column was a previously calculated weight, the run would quietly ship the new one under the old one's name.",
      how_to_fix = "Rename the weight in Weight_Specifications, or remove the existing column from the data file first. If you are deliberately recalculating a weight, write to a new name and retire the old column."
    )
  }

  invisible(TRUE)
}
