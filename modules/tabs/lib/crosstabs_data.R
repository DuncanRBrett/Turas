# ==============================================================================
# MODULE: crosstabs_data.R
# ==============================================================================
# Purpose: Load survey data, setup weighting, load composites, run validation
#
# This module handles:
# - Loading survey data (with smart CSV caching)
# - Setting up and validating weights
# - Loading composite metric definitions
# - Running comprehensive validation checks
#
# Version: 10.0
# TRS Compliance: v1.0
# ==============================================================================

# ==============================================================================
# DATA LOADING
# ==============================================================================

#' Load survey data for crosstabs
#'
#' @param config Configuration object from Settings sheet
#' @param survey_structure Survey structure object
#' @param project_root Project root directory
#' @return Survey data frame
#' @export
load_crosstabs_data <- function(config, survey_structure, project_root) {
  log_message("Loading survey data...", "INFO")

  data_file <- get_config_value(survey_structure$project, "data_file", required = TRUE)
  data_file_path <- resolve_path(project_root, data_file)

  if (!file.exists(data_file_path)) {
    # TRS Refusal: IO_DATA_FILE_NOT_FOUND
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

  survey_data <- load_survey_data_smart(data_file_path, project_root)
  validate_data_frame(survey_data, NULL, 1)

  log_message(sprintf("✓ Loaded %d responses", nrow(survey_data)), "INFO")

  return(survey_data)
}

# ==============================================================================
# WEIGHTING SETUP
# ==============================================================================

#' Setup and validate weights for crosstabs
#'
#' @param survey_data Survey data frame
#' @param config_obj Configuration object
#' @return List with master_weights vector, effective_n, and is_weighted flag
#' @export
setup_crosstabs_weights <- function(survey_data, config_obj) {
  is_weighted <- config_obj$apply_weighting

  if (is_weighted) {
    master_weights <- get_weight_vector(survey_data, config_obj$weight_variable)
    validate_weights(master_weights, nrow(survey_data))
    summarize_weights(master_weights, paste("Weight:", config_obj$weight_variable))
    effective_n <- round(calculate_effective_n(master_weights), 0)
  } else {
    master_weights <- rep(1, nrow(survey_data))
    effective_n <- nrow(survey_data)
    log_message("✓ Analysis will be unweighted", "INFO")
  }

  return(list(
    master_weights = master_weights,
    effective_n = effective_n,
    is_weighted = is_weighted
  ))
}

# ==============================================================================
# COMPOSITE DEFINITIONS
# ==============================================================================

#' Load composite metric definitions
#'
#' @param structure_file_path Path to survey structure file
#' @return Composite definitions data frame or NULL
#' @export
load_crosstabs_composites <- function(structure_file_path) {
  composite_defs <- load_composite_definitions(structure_file_path)

  if (!is.null(composite_defs) && nrow(composite_defs) > 0) {
    log_message(sprintf("Loaded %d composite metric(s)", nrow(composite_defs)), "INFO")
  } else {
    log_message("No composite metrics defined", "INFO")
  }

  return(composite_defs)
}

# ==============================================================================
# VALIDATION
# ==============================================================================

#' Run comprehensive validation for crosstabs
#'
#' @param survey_structure Survey structure object
#' @param survey_data Survey data frame
#' @param config_obj Configuration object
#' @param composite_defs Composite definitions data frame
#' @return Error log data frame
#' @export
run_crosstabs_validation <- function(survey_structure, survey_data, config_obj, composite_defs) {
  log_message("Running comprehensive validation...", "INFO")

  error_log <- run_all_validations(survey_structure, survey_data, config_obj)

  if (nrow(error_log) > 0) {
    log_message(sprintf("⚠  Found %d validation issues", nrow(error_log)), "WARNING")
  }

  # Validate composites if defined
  if (!is.null(composite_defs) && nrow(composite_defs) > 0) {
    log_message("Validating composite definitions...", "INFO")

    validation_result <- validate_composite_definitions(
      composite_defs = composite_defs,
      questions_df = survey_structure$questions,
      survey_data = survey_data
    )

    if (!validation_result$is_valid) {
      # TRS Refusal: CFG_COMPOSITE_VALIDATION_FAILED
      tabs_refuse(
        code = "CFG_COMPOSITE_VALIDATION_FAILED",
        title = "Composite Definition Validation Failed",
        problem = "One or more composite metric definitions are invalid.",
        why_it_matters = "Invalid composites will produce incorrect or missing results.",
        how_to_fix = c(
          "Review the composite definitions in your config",
          "Ensure all referenced questions exist",
          "Check formula syntax is correct"
        ),
        details = paste(validation_result$errors, collapse = "\n")
      )
    }

    if (length(validation_result$warnings) > 0) {
      for (warn in validation_result$warnings) {
        warning(warn, call. = FALSE)
      }
    }

    log_message("✓ Composite definitions validated", "INFO")
  }

  return(error_log)
}

# ==============================================================================
# END OF MODULE: crosstabs_data.R
# ==============================================================================
