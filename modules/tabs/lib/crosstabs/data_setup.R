# ==============================================================================
# DATA_SETUP.R - TURAS V10.2 (Phase 4 Refactoring)
# ==============================================================================
# Extracted from run_crosstabs.R for better modularity
#
# PURPOSE: Survey structure, data, and weight setup
#
# FUNCTIONS:
#   - load_and_validate_structure() - Load and validate survey structure
#   - prepare_options_columns() - Prepare options dataframe columns
#   - load_composite_definitions_safe() - Load composite definitions safely
#   - load_and_validate_data() - Load and validate survey data
#   - setup_weights() - Configure weighting
#   - load_question_selection() - Load and validate question selection
#   - normalise_flag_column()   - Canonicalise a Y/N gate column
#
# DEPENDENCIES:
#   - data_loader.R (for load_survey_structure, load_survey_data_smart)
#   - validation_utils.R (for validate_data_frame)
#   - config_utils.R (for get_config_value)
#   - type_utils.R (for the .TABS_FLAG_*_TOKENS yes/no vocabulary)
#   - path_utils.R (for resolve_path)
#   - weighting.R (for get_weight_vector, validate_weights, etc.)
#   - composite_processor.R (for load_composite_definitions)
#   - 00_guard.R (for tabs_refuse)
#   - logging_utils.R (for log_message)
#
# ==============================================================================

# ==============================================================================
# Y/N GATE COLUMNS
# ==============================================================================

# The Selection sheet's Include / UseBanner / BannerBoxCategory / CreateIndex and
# the Options sheet's ShowInOutput / ExcludeFromIndex gate what reaches the
# deliverable. The engine reads them with an exact `== "Y"` test in a dozen
# places (data_setup.R, banner.R, standard_processor.R, cell_calculator.R,
# score_utils.R, composite_processor.R, microdata_writer.R) while several
# preflight validators read `toupper(...) == "Y"`. A lowercase "y" therefore
# passed validation and was then dropped in silence — one cell, one table quietly
# missing from a client workbook. Each sheet is read in exactly one place —
# load_question_selection() for Selection, prepare_options_columns() for
# Options — so normalising there closes the gap for every reader at once.
#
# The vocabulary matches what workbook_builder.R (create_index_summary) and
# excel_writer.R already accept, so the same word means the same thing in every
# corner of the module. It lives beside safe_logical() in type_utils.R
# (.TABS_FLAG_TRUE_TOKENS / .TABS_FLAG_FALSE_TOKENS) because the Y/N Settings
# cells validate against the same words (production review 2026-08, I3).

#' Normalise a Y/N Gate Column to Canonical "Y" / "N"
#'
#' Case- and whitespace-insensitive. A blank cell (NA or whitespace only) takes
#' \code{default}, which is how the templates document these columns. Any other
#' token refuses rather than defaulting: an unreadable gate value is the exact
#' condition that used to drop a question without a word, so it stops the run
#' where the operator can still fix the cell.
#'
#' @param values Raw column, any type
#' @param column Character, column name (for the refusal)
#' @param sheet Character, sheet the column lives on (for the refusal)
#' @param default Character, "Y" or "N" — the meaning of a blank cell
#' @param row_codes Optional character vector of QuestionCodes, same length as
#'   \code{values}, used to name the offending rows in the refusal
#' @return Character vector of "Y" / "N", same length as \code{values}
#' @export
normalise_flag_column <- function(values, column, sheet, default = "N",
                                  row_codes = NULL) {
  raw <- as.character(values)
  tokens <- toupper(trimws(raw))
  blank <- is.na(tokens) | !nzchar(tokens)

  result <- rep(NA_character_, length(tokens))
  result[blank] <- default
  result[!blank & tokens %in% .TABS_FLAG_TRUE_TOKENS] <- "Y"
  result[!blank & tokens %in% .TABS_FLAG_FALSE_TOKENS] <- "N"

  bad <- which(is.na(result))
  if (length(bad) > 0) {
    labels <- if (!is.null(row_codes) && length(row_codes) == length(tokens)) {
      sprintf("row %d (%s): '%s'", bad, as.character(row_codes)[bad], raw[bad])
    } else {
      sprintf("row %d: '%s'", bad, raw[bad])
    }
    tabs_refuse(
      code = "CFG_INVALID_FLAG_VALUE",
      title = paste0("Unrecognised ", column, " Value"),
      problem = sprintf(
        "The %s sheet's %s column contains %d value(s) that are neither yes nor no.",
        sheet, column, length(bad)
      ),
      why_it_matters = paste0(
        "This column decides what reaches the deliverable. A value Turas cannot ",
        "read would be treated as 'no' and the affected row would be dropped ",
        "without appearing anywhere in the output."
      ),
      how_to_fix = c(
        paste0("Open the ", sheet, " sheet and set ", column, " to Y or N"),
        "Leave the cell blank to accept the default",
        paste0("Accepted values (any case): ",
               paste(c(.TABS_FLAG_TRUE_TOKENS, .TABS_FLAG_FALSE_TOKENS),
                     collapse = ", "))
      ),
      expected = paste0("Y, N or blank (blank = ", default, ")"),
      observed = paste(labels, collapse = "; ")
    )
  }

  result
}


# ==============================================================================
# SURVEY STRUCTURE
# ==============================================================================

#' Load and Validate Survey Structure
#'
#' Loads the survey structure file and validates required columns exist.
#'
#' @param structure_file_path Character, path to structure file
#' @param project_root Character, project root directory
#' @return List, survey structure with questions, options, project sheets
#' @export
load_and_validate_structure <- function(structure_file_path, project_root) {
  log_message("Loading survey structure...", "INFO")

  survey_structure <- load_survey_structure(structure_file_path, project_root)

  # Validate required columns
  validate_data_frame(survey_structure$questions,
                      c("QuestionCode", "QuestionText", "Variable_Type"), 1)
  validate_data_frame(survey_structure$options,
                      c("QuestionCode", "OptionText"), 0)

  log_message("Survey structure loaded", "INFO")

  survey_structure
}


#' Prepare Options Columns
#'
#' Ensures options dataframe has required columns with correct types and defaults.
#'
#' @param options Data frame, options sheet
#' @return Data frame, options with prepared columns
#' @export
prepare_options_columns <- function(options) {
  # Ensure ShowInOutput column exists
  if (!"ShowInOutput" %in% names(options)) {
    options$ShowInOutput <- NA_character_
  }

  # Ensure ExcludeFromIndex column exists
  if (!"ExcludeFromIndex" %in% names(options)) {
    options$ExcludeFromIndex <- NA_character_
  }

  # Canonicalise to "Y"/"N" and apply defaults. Blank means show the option and
  # count it in the index; anything unreadable refuses rather than silently
  # hiding a response option or dropping it from an index.
  row_codes <- if ("QuestionCode" %in% names(options)) {
    as.character(options$QuestionCode)
  } else {
    NULL
  }
  options$ShowInOutput <- normalise_flag_column(
    options$ShowInOutput, "ShowInOutput", "Options",
    default = "Y", row_codes = row_codes)
  options$ExcludeFromIndex <- normalise_flag_column(
    options$ExcludeFromIndex, "ExcludeFromIndex", "Options",
    default = "N", row_codes = row_codes)

  # Convert Index_Weight to numeric for Likert index calculations
  if ("Index_Weight" %in% names(options)) {
    options$Index_Weight <- as.numeric(options$Index_Weight)
  }

  # Convert DisplayOrder to numeric for proper sorting
  if ("DisplayOrder" %in% names(options)) {
    options$DisplayOrder <- as.numeric(options$DisplayOrder)
  }

  options
}


#' Load Composite Definitions Safely
#'
#' Loads composite metric definitions from the structure file.
#'
#' @param structure_file_path Character, path to structure file
#' @return Data frame, composite definitions (or NULL if none)
#' @export
load_composite_definitions_safe <- function(structure_file_path) {
  composite_defs <- load_composite_definitions(structure_file_path)

  if (!is.null(composite_defs) && nrow(composite_defs) > 0) {
    log_message(sprintf("Loaded %d composite metric(s)", nrow(composite_defs)), "INFO")
  } else {
    log_message("No composite metrics defined", "INFO")
  }

  composite_defs
}


# ==============================================================================
# SURVEY DATA
# ==============================================================================

#' Load and Validate Survey Data
#'
#' Loads the survey data file and validates it.
#'
#' @param survey_structure List, survey structure with project info
#' @param project_root Character, project root directory
#' @return Data frame, survey data
#' @export
load_and_validate_data <- function(survey_structure, project_root) {
  log_message("Loading survey data...", "INFO")

  # Get data file path from project sheet
  data_file <- get_config_value(survey_structure$project, "data_file", required = TRUE)
  data_file <- normalize_path_separators(data_file)
  data_file_path <- resolve_path(project_root, data_file)

  # Validate file exists
  if (!file.exists(data_file_path)) {
    tabs_refuse(
      code = "IO_DATA_FILE_NOT_FOUND",
      title = "Data File Not Found",
      problem = paste0("Cannot find data file: ", basename(data_file_path)),
      why_it_matters = "The analysis requires survey data to produce crosstabs.",
      how_to_fix = c(
        "Check that the data_file path in Project sheet is correct",
        "Verify the file exists at the specified location"
      ),
      details = paste0("Expected path: ", data_file_path)
    )
  }

  # Load data
  survey_data <- load_survey_data_smart(data_file_path, project_root)
  validate_data_frame(survey_data, NULL, 1)

  log_message(sprintf("Loaded %d responses", nrow(survey_data)), "INFO")

  survey_data
}


# ==============================================================================
# WEIGHTING
# ==============================================================================

#' Setup Weights
#'
#' Configures weighting based on config settings.
#' Returns weight vector and effective N.
#'
#' @param survey_data Data frame, survey data
#' @param config_obj List, configuration object
#' @return List with master_weights, effective_n, and is_weighted
#' @export
setup_weights <- function(survey_data, config_obj) {
  is_weighted <- config_obj$apply_weighting

  if (is_weighted) {
    master_weights <- get_weight_vector(survey_data, config_obj$weight_variable)
    validate_weights(master_weights, nrow(survey_data))
    summarize_weights(master_weights, paste("Weight:", config_obj$weight_variable))
    effective_n <- round(calculate_effective_n(master_weights), 0)
  } else {
    master_weights <- rep(1, nrow(survey_data))
    effective_n <- nrow(survey_data)
    log_message("Analysis will be unweighted", "INFO")
  }

  list(
    master_weights = master_weights,
    effective_n = effective_n,
    is_weighted = is_weighted
  )
}


# ==============================================================================
# QUESTION SELECTION
# ==============================================================================

#' Load Question Selection
#'
#' Loads the Selection sheet from the config file and filters to selected questions.
#'
#' @param config_file Character, path to config file
#' @return List with selection_df and crosstab_questions
#' @export
load_question_selection <- function(config_file) {
  log_message("Loading question selection...", "INFO")

  # Load selection sheet (auto-detect header row for template format)
  selection_df <- tryCatch({
    .read_table_sheet(config_file, "Selection",
                      required_cols = c("QuestionCode"))
  }, error = function(e) {
    tabs_refuse(
      code = "IO_SELECTION_SHEET_FAILED",
      title = "Failed to Load Selection Sheet",
      problem = "Could not read the Selection sheet from configuration file.",
      why_it_matters = "The Selection sheet specifies which questions to analyze.",
      how_to_fix = c(
        "Verify the config file exists and is not corrupted",
        "Check that a 'Selection' sheet exists in the file",
        "Ensure the file is not open in another application"
      ),
      details = conditionMessage(e)
    )
  })

  # Validate required column
  validate_data_frame(selection_df, c("QuestionCode"), 1)

  # Ensure optional columns exist and are character type. CommentSheet/CommentLink
  # are the V12 qualitative jump columns on the open-end rows (CommentSheet = the
  # comment-workbook sheet that codes this open-end; CommentLink = the closed
  # question/composite it explains) — see qual_build_links().
  for (col in c("Include", "UseBanner", "BannerBoxCategory", "CreateIndex", "BaseFilter", "FilterLabel", "Category", "CategoryOrder", "Theme", "KeyShare", "AreaSummary", "CommentSheet", "CommentLink")) {
    if (!col %in% names(selection_df)) {
      selection_df[[col]] <- NA_character_
    } else {
      selection_df[[col]] <- as.character(selection_df[[col]])
    }
  }

  # Canonicalise the gate columns to "Y"/"N" and apply defaults. Every downstream
  # reader — the engine's exact `== "Y"` tests and preflight's `toupper()` ones —
  # then sees the same value, so a lowercase "y" can no longer pass validation
  # and be dropped by the engine.
  for (flag in c("Include", "UseBanner", "BannerBoxCategory", "CreateIndex")) {
    selection_df[[flag]] <- normalise_flag_column(
      selection_df[[flag]], flag, "Selection",
      default = "N", row_codes = selection_df$QuestionCode)
  }

  # Filter to included questions
  crosstab_questions <- selection_df[selection_df$Include == "Y", ]

  if (nrow(crosstab_questions) == 0) {
    tabs_refuse(
      code = "CFG_NO_QUESTIONS_SELECTED",
      title = "No Questions Selected for Analysis",
      problem = "No questions have Include='Y' in the Selection sheet.",
      why_it_matters = "At least one question must be selected to produce crosstabs.",
      how_to_fix = c(
        "Open your config file",
        "In the Selection sheet, set Include='Y' for questions to analyze",
        "Save and re-run"
      ),
      details = paste0("Total questions in selection: ", nrow(selection_df))
    )
  }

  log_message(sprintf("Found %d questions to analyze", nrow(crosstab_questions)), "INFO")

  list(
    selection_df = selection_df,
    crosstab_questions = crosstab_questions
  )
}


# ==============================================================================
# FULL DATA SETUP
# ==============================================================================

#' Load All Crosstabs Data
#'
#' Main entry point for loading all data needed for crosstabs analysis.
#'
#' @param config_result List, result from load_crosstabs_config()
#' @return List with all data components
#' @export
load_crosstabs_data <- function(config_result) {
  # Load survey structure
  survey_structure <- load_and_validate_structure(
    config_result$structure_file_path,
    config_result$project_root
  )

  # Prepare options columns
  survey_structure$options <- prepare_options_columns(survey_structure$options)

  # Load composite definitions
  composite_defs <- load_composite_definitions_safe(config_result$structure_file_path)

  # Load survey data
  survey_data <- load_and_validate_data(survey_structure, config_result$project_root)

  # Setup weights
  weight_result <- setup_weights(survey_data, config_result$config_obj)

  # Load question selection
  selection_result <- load_question_selection(config_result$config_file)

  list(
    survey_structure = survey_structure,
    survey_data = survey_data,
    composite_defs = composite_defs,
    master_weights = weight_result$master_weights,
    effective_n = weight_result$effective_n,
    is_weighted = weight_result$is_weighted,
    selection_df = selection_result$selection_df,
    crosstab_questions = selection_result$crosstab_questions
  )
}
