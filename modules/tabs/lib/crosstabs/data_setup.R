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
#
# DEPENDENCIES:
#   - data_loader.R (for load_survey_structure, load_survey_data_smart)
#   - validation_utils.R (for validate_data_frame)
#   - config_utils.R (for get_config_value)
#   - path_utils.R (for resolve_path)
#   - weighting.R (for get_weight_vector, validate_weights, etc.)
#   - composite_processor.R (for load_composite_definitions)
#   - 00_guard.R (for tabs_refuse)
#   - logging_utils.R (for log_message)
#
# ==============================================================================

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

  # Convert to character if not already
  options$ShowInOutput <- as.character(options$ShowInOutput)
  options$ExcludeFromIndex <- as.character(options$ExcludeFromIndex)

  # Apply defaults
  options$ShowInOutput[is.na(options$ShowInOutput)] <- "Y"
  options$ExcludeFromIndex[is.na(options$ExcludeFromIndex)] <- "N"

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

  # Load selection sheet
  selection_df <- tryCatch({
    readxl::read_excel(config_file, sheet = "Selection", col_types = "text")
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

  # Ensure optional columns exist and are character type
  for (col in c("Include", "UseBanner", "BannerBoxCategory", "CreateIndex", "BaseFilter")) {
    if (!col %in% names(selection_df)) {
      selection_df[[col]] <- NA_character_
    } else {
      selection_df[[col]] <- as.character(selection_df[[col]])
    }
  }

  # Apply defaults
  selection_df$Include[is.na(selection_df$Include)] <- "N"
  selection_df$UseBanner[is.na(selection_df$UseBanner)] <- "N"
  selection_df$BannerBoxCategory[is.na(selection_df$BannerBoxCategory)] <- "N"
  selection_df$CreateIndex[is.na(selection_df$CreateIndex)] <- "N"

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
