# ==============================================================================
# MODULE: crosstabs_config.R
# ==============================================================================
# Purpose: Load and validate configuration, survey structure, and question selection
#
# This module handles:
# - Loading configuration from Settings sheet
# - Loading survey structure (questions and options)
# - Loading question selection (which questions to analyze)
# - Building configuration object with all settings
# - Creating banner structure
# - Displaying configuration summary before processing
#
# Version: 10.0
# TRS Compliance: v1.0
# ==============================================================================

# ==============================================================================
# CONFIGURATION LOADING
# ==============================================================================

#' Load and validate configuration settings
#'
#' @param config_file Path to configuration file
#' @param project_root Project root directory
#' @return List containing config object, survey structure, and selection
#' @export
load_crosstabs_configuration <- function(config_file, project_root) {
  log_message("Loading configuration...", "INFO")
  config <- load_config_sheet(config_file, "Settings")

  # Build config object with all settings
  config_obj <- list(
    apply_weighting = safe_logical(get_config_value(config, "apply_weighting", FALSE)),
    weight_variable = get_config_value(config, "weight_variable", NULL),
    show_unweighted_n = safe_logical(get_config_value(config, "show_unweighted_n", TRUE)),
    show_effective_n = safe_logical(get_config_value(config, "show_effective_n", TRUE)),
    weight_label = get_config_value(config, "weight_label", "Weighted"),
    decimal_separator = get_config_value(config, "decimal_separator", "."),
    show_frequency = safe_logical(get_config_value(config, "show_frequency", TRUE)),
    show_percent_column = safe_logical(get_config_value(config, "show_percent_column", TRUE)),
    show_percent_row = safe_logical(get_config_value(config, "show_percent_row", FALSE)),
    boxcategory_frequency = safe_logical(get_config_value(config, "boxcategory_frequency", FALSE)),
    boxcategory_percent_column = safe_logical(get_config_value(config, "boxcategory_percent_column", TRUE)),
    boxcategory_percent_row = safe_logical(get_config_value(config, "boxcategory_percent_row", FALSE)),
    decimal_places_percent = safe_numeric(get_config_value(config, "decimal_places_percent", 0)),
    decimal_places_ratings = safe_numeric(get_config_value(config, "decimal_places_ratings", 1)),
    decimal_places_index = safe_numeric(get_config_value(config, "decimal_places_index", 1)),
    enable_significance_testing = safe_logical(get_config_value(config, "enable_significance_testing", TRUE)),
    alpha = safe_numeric(get_config_value(config, "alpha", DEFAULT_ALPHA)),
    significance_min_base = safe_numeric(get_config_value(config, "significance_min_base", DEFAULT_MIN_BASE)),
    bonferroni_correction = safe_logical(get_config_value(config, "bonferroni_correction", TRUE)),
    enable_checkpointing = safe_logical(get_config_value(config, "enable_checkpointing", TRUE)),
    zero_division_as_blank = safe_logical(get_config_value(config, "zero_division_as_blank", TRUE)),
    show_standard_deviation = safe_logical(get_config_value(config, "show_standard_deviation", FALSE)),
    test_net_differences = safe_logical(get_config_value(config, "test_net_differences", FALSE)),
    create_sample_composition = safe_logical(get_config_value(config, "create_sample_composition", FALSE)),
    enable_chi_square = safe_logical(get_config_value(config, "enable_chi_square", FALSE)),
    show_net_positive = safe_logical(get_config_value(config, "show_net_positive", FALSE)),
    show_numeric_median = safe_logical(get_config_value(config, "show_numeric_median", FALSE)),
    show_numeric_mode = safe_logical(get_config_value(config, "show_numeric_mode", FALSE)),
    show_numeric_outliers = safe_logical(get_config_value(config, "show_numeric_outliers", TRUE)),
    exclude_outliers_from_stats = safe_logical(get_config_value(config, "exclude_outliers_from_stats", FALSE)),
    outlier_method = get_config_value(config, "outlier_method", "IQR"),
    decimal_places_numeric = safe_numeric(get_config_value(config, "decimal_places_numeric", 1))
  )

  log_message("✓ Configuration loaded", "INFO")

  return(config_obj)
}

# ==============================================================================
# SURVEY STRUCTURE LOADING
# ==============================================================================

#' Load and prepare survey structure
#'
#' @param structure_file_path Path to survey structure file
#' @param project_root Project root directory
#' @return List with questions, options, and project metadata
#' @export
load_crosstabs_survey_structure <- function(structure_file_path, project_root) {
  if (!file.exists(structure_file_path)) {
    # TRS Refusal: IO_STRUCTURE_FILE_NOT_FOUND
    tabs_refuse(
      code = "IO_STRUCTURE_FILE_NOT_FOUND",
      title = "Survey Structure File Not Found",
      problem = paste0("Cannot find survey structure file: ", basename(structure_file_path)),
      why_it_matters = "The survey structure defines questions and options needed for crosstabs.",
      how_to_fix = c(
        "Check that the structure_file path in Settings is correct",
        "Verify Survey_Structure.xlsx exists in your project folder"
      ),
      details = paste0("Expected path: ", structure_file_path)
    )
  }

  log_message("Loading survey structure...", "INFO")
  survey_structure <- load_survey_structure(structure_file_path, project_root)

  validate_data_frame(survey_structure$questions, c("QuestionCode", "QuestionText", "Variable_Type"), 1)
  validate_data_frame(survey_structure$options, c("QuestionCode", "OptionText"), 0)

  # Apply ShowInOutput default to the actual options dataframe
  if (!"ShowInOutput" %in% names(survey_structure$options)) {
    survey_structure$options$ShowInOutput <- NA_character_
  }
  if (!"ExcludeFromIndex" %in% names(survey_structure$options)) {
    survey_structure$options$ExcludeFromIndex <- NA_character_
  }

  # Convert to character if not already (handles any type mismatches)
  survey_structure$options$ShowInOutput <- as.character(survey_structure$options$ShowInOutput)
  survey_structure$options$ExcludeFromIndex <- as.character(survey_structure$options$ExcludeFromIndex)

  # Apply defaults
  survey_structure$options$ShowInOutput[is.na(survey_structure$options$ShowInOutput)] <- "Y"
  survey_structure$options$ExcludeFromIndex[is.na(survey_structure$options$ExcludeFromIndex)] <- "N"

  # Convert Index_Weight to numeric for Likert index calculations
  if ("Index_Weight" %in% names(survey_structure$options)) {
    survey_structure$options$Index_Weight <- as.numeric(survey_structure$options$Index_Weight)
  }

  # Convert DisplayOrder to numeric for proper sorting
  if ("DisplayOrder" %in% names(survey_structure$options)) {
    survey_structure$options$DisplayOrder <- as.numeric(survey_structure$options$DisplayOrder)
  }

  log_message("✓ Survey structure loaded", "INFO")

  return(survey_structure)
}

# ==============================================================================
# QUESTION SELECTION LOADING
# ==============================================================================

#' Load question selection from config file
#'
#' @param config_file Path to configuration file
#' @return Data frame with selected questions
#' @export
load_question_selection <- function(config_file) {
  log_message("Loading question selection...", "INFO")

  selection_df <- tryCatch({
    readxl::read_excel(config_file, sheet = "Selection", col_types = "text")
  }, error = function(e) {
    # TRS Refusal: IO_SELECTION_SHEET_FAILED
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

  validate_data_frame(selection_df, c("QuestionCode"), 1)

  # Ensure optional columns exist and are character type before assignment
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

  crosstab_questions <- selection_df[selection_df$Include == "Y", ]

  if (nrow(crosstab_questions) == 0) {
    # TRS Refusal: CFG_NO_QUESTIONS_SELECTED
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

  log_message(sprintf("✓ Found %d questions to analyze", nrow(crosstab_questions)), "INFO")

  return(list(
    all_questions = selection_df,
    selected_questions = crosstab_questions
  ))
}

# ==============================================================================
# CONFIGURATION SUMMARY
# ==============================================================================

#' Estimate Runtime Based on Dataset Size
#'
#' Provides an estimate of how long processing will take based on documented
#' benchmarks. Helps users plan for long-running analyses.
#'
#' @param n_questions Integer, number of questions to process
#' @param n_respondents Integer, number of respondents in data
#' @param n_banner_cols Integer, number of banner columns (default: 5)
#' @return Character, formatted time estimate
#' @export
estimate_runtime <- function(n_questions, n_respondents, n_banner_cols = 5) {
  # Based on documented benchmarks: ~2.5 sec per 20 questions / 500 respondents / 5 banner cols
  base_time_sec <- (n_respondents / 500) * (n_questions / 20) * (n_banner_cols / 5) * 2.5

  if (base_time_sec < 60) {
    return(sprintf("~%.0f seconds", base_time_sec))
  } else if (base_time_sec < 3600) {
    return(sprintf("~%.1f minutes", base_time_sec / 60))
  } else {
    return(sprintf("~%.1f hours", base_time_sec / 3600))
  }
}

#' Print Configuration Summary Before Processing
#'
#' Displays a summary of the analysis configuration before starting processing.
#' Helps users verify settings and estimate processing time.
#'
#' @param config_obj List, configuration object
#' @param n_questions Integer, number of questions to process
#' @param n_respondents Integer, number of respondents
#' @param n_banner_cols Integer, number of banner columns
#' @return Invisible NULL
#' @export
print_config_summary <- function(config_obj, n_questions, n_respondents, n_banner_cols) {
  cat("\n")
  cat(strrep("=", 60), "\n")
  cat("ANALYSIS CONFIGURATION\n")
  cat(strrep("=", 60), "\n")
  cat(sprintf("  Questions to process:    %d\n", n_questions))
  cat(sprintf("  Respondents:             %d\n", n_respondents))
  cat(sprintf("  Banner columns:          %d\n", n_banner_cols))
  cat(sprintf("  Weighting:               %s\n",
              if(config_obj$apply_weighting) config_obj$weight_variable else "None"))
  cat(sprintf("  Significance testing:    %s\n",
              if(config_obj$enable_significance_testing)
                sprintf("Yes (alpha=%.3f)", config_obj$alpha) else "No"))
  cat(sprintf("  Estimated time:          %s\n",
              estimate_runtime(n_questions, n_respondents, n_banner_cols)))
  cat(strrep("=", 60), "\n\n")

  invisible(NULL)
}

# ==============================================================================
# BANNER STRUCTURE CREATION
# ==============================================================================

#' Create banner structure from selection
#'
#' @param selection_df Data frame with question selection
#' @param survey_structure Survey structure object
#' @return Banner info object or NULL
#' @export
create_crosstabs_banner <- function(selection_df, survey_structure) {
  log_message("Creating banner structure...", "INFO")

  banner_info <- safe_execute(
    create_banner_structure(selection_df, survey_structure),
    default = NULL,
    error_msg = "Failed to create banner structure"
  )

  if (is.null(banner_info)) {
    # TRS Refusal: CFG_BANNER_CREATION_FAILED
    tabs_refuse(
      code = "CFG_BANNER_CREATION_FAILED",
      title = "Failed to Create Banner Structure",
      problem = "Could not create banner structure from configuration.",
      why_it_matters = "Crosstabs require a valid banner to break down results by segments.",
      how_to_fix = c(
        "Check that at least one question has UseBanner='Y' in Selection sheet",
        "Verify banner question has valid options defined",
        "Check that banner question exists in the data"
      )
    )
  }

  log_message(sprintf("✓ Banner: %d columns", length(banner_info$columns)), "INFO")

  return(banner_info)
}

# ==============================================================================
# END OF MODULE: crosstabs_config.R
# ==============================================================================
