# ==============================================================================
# CATEGORICAL KEY DRIVER - HARD ERROR GUARDS
# ==============================================================================
#
# Guards that produce hard errors (REFUSE TO RUN).
# These validate critical requirements before analysis.
#
# Related modules:
#   - 08_guard.R: Core guard framework and refusal mechanism
#   - 08b_guards_soft.R: Soft warning guards
#
# Version: 2.0
# ==============================================================================

#' Guard: Validate Outcome Type Declaration
#'
#' REFUSES if outcome type not explicitly declared.
#'
#' @param config Configuration list
#' @keywords internal
guard_require_outcome_type <- function(config) {
  outcome_type <- config$outcome_type

  if (is.null(outcome_type) || outcome_type == "auto") {
    catdriver_refuse(
      title = "OUTCOME TYPE NOT DECLARED",
      problem = "The 'outcome_type' setting is missing or set to 'auto'.",
      why_it_matters = "Auto-detection can select the wrong model type, producing misleading results.",
      fix = "Add 'outcome_type' to the Settings sheet.\nValid values: binary, ordinal, multinomial"
    )
  }

  valid_types <- c("binary", "ordinal", "multinomial")
  if (!outcome_type %in% valid_types) {
    catdriver_refuse(
      title = "INVALID OUTCOME TYPE",
      problem = paste0("outcome_type='", outcome_type, "' is not recognized."),
      why_it_matters = "Unknown outcome types cannot be analyzed.",
      fix = paste0("Change outcome_type to one of: ", paste(valid_types, collapse = ", "))
    )
  }

  invisible(TRUE)
}


#' Guard: Validate Outcome Levels Match Config
#'
#' HARD ERROR if data outcome levels don't match config declaration.
#'
#' @param data Data frame
#' @param config Configuration list
#' @keywords internal
guard_outcome_levels_match <- function(data, config) {
  outcome_var <- config$outcome_var
  data_levels <- unique(as.character(na.omit(data[[outcome_var]])))

  # If order is specified, check match
  if (!is.null(config$outcome_order) && length(config$outcome_order) > 0) {
    config_levels <- config$outcome_order

    # Check all data levels are in config
    missing_from_config <- setdiff(data_levels, config_levels)
    if (length(missing_from_config) > 0) {
      stop(
        "\n",
        "=== CATDRIVER HARD ERROR ===\n",
        "Outcome levels in data do not match config declaration.\n\n",
        "LEVELS IN DATA NOT IN CONFIG:\n",
        paste("  -", missing_from_config, collapse = "\n"), "\n\n",
        "CONFIG DECLARED LEVELS:\n",
        paste("  -", config_levels, collapse = "\n"), "\n\n",
        "FIX: Update the 'Order' column in Variables sheet to include all levels.\n",
        call. = FALSE
      )
    }

    # Check config levels exist in data
    missing_from_data <- setdiff(config_levels, data_levels)
    if (length(missing_from_data) > 0) {
      warning(
        "Config declares outcome levels not found in data: ",
        paste(missing_from_data, collapse = ", "),
        "\nThese levels will be ignored."
      )
    }
  }

  # Check category count matches outcome type
  n_categories <- length(data_levels)
  outcome_type <- config$outcome_type

  if (outcome_type == "binary" && n_categories != 2) {
    stop(
      "\n",
      "=== CATDRIVER HARD ERROR ===\n",
      "Outcome declared as 'binary' but has ", n_categories, " categories.\n\n",
      "CATEGORIES FOUND: ", paste(data_levels, collapse = ", "), "\n\n",
      "FIX: Either:\n",
      "  1. Change outcome_type to 'ordinal' or 'multinomial', OR\n",
      "  2. Recode your outcome to have exactly 2 categories\n",
      call. = FALSE
    )
  }

  if (outcome_type %in% c("ordinal", "multinomial") && n_categories < 3) {
    stop(
      "\n",
      "=== CATDRIVER HARD ERROR ===\n",
      "Outcome declared as '", outcome_type, "' but has only ", n_categories, " categories.\n\n",
      "FIX: Change outcome_type to 'binary' for 2-category outcomes.\n",
      call. = FALSE
    )
  }

  invisible(TRUE)
}


#' Guard: Require Multinomial Reporting Mode
#'
#' HARD ERROR if multinomial outcome without explicit reporting mode.
#'
#' @param config Configuration list
#' @keywords internal
guard_require_multinomial_mode <- function(config) {
  if (config$outcome_type != "multinomial") {
    return(invisible(TRUE))
  }

  multinomial_mode <- config$multinomial_mode
  valid_modes <- c("baseline_category", "all_pairwise", "one_vs_all")

  if (is.null(multinomial_mode) || !multinomial_mode %in% valid_modes) {
    stop(
      "\n",
      "=== CATDRIVER HARD ERROR ===\n",
      "Multinomial outcome requires explicit reporting mode.\n\n",
      "REQUIRED: Add 'multinomial_mode' to Settings sheet.\n",
      "VALID VALUES:\n",
      "  - 'baseline_category': Compare all levels to one reference (default)\n",
      "  - 'all_pairwise': Compare every pair of levels\n",
      "  - 'one_vs_all': Compare each level vs. all others (requires target_outcome_level)\n\n",
      "WHY: Multinomial models produce multiple sets of odds ratios.\n",
      "     We refuse to guess which one you want to see.\n",
      call. = FALSE
    )
  }

  if (multinomial_mode == "one_vs_all") {
    target_level <- config$target_outcome_level
    if (is.null(target_level) || is.na(target_level) || !nzchar(target_level)) {
      stop(
        "\n",
        "=== CATDRIVER HARD ERROR ===\n",
        "one_vs_all mode requires target_outcome_level.\n\n",
        "REQUIRED: Add 'target_outcome_level' to Settings sheet.\n",
        "VALUE: The outcome category you want to treat as 'success'.\n",
        call. = FALSE
      )
    }
  }

  invisible(TRUE)
}


#' Guard: Require Driver Settings
#'
#' HARD ERROR if DRIVER_SETTINGS sheet missing or incomplete.
#'
#' @param config Configuration list
#' @keywords internal
guard_require_driver_settings <- function(config) {
  driver_settings <- config$driver_settings

  if (is.null(driver_settings) || nrow(driver_settings) == 0) {
    stop(
      "\n",
      "=== CATDRIVER HARD ERROR ===\n",
      "DRIVER_SETTINGS sheet is required.\n\n",
      "REQUIRED COLUMNS:\n",
      "  - driver: Variable name\n",
      "  - type: categorical, ordinal, or continuous\n\n",
      "OPTIONAL COLUMNS:\n",
      "  - levels_order: Semicolon-separated level order\n",
      "  - reference_level: Reference category\n",
      "  - missing_strategy: drop_row, missing_as_level, error_if_missing\n",
      "  - rare_level_policy: warn_only, collapse_to_other, drop_level, error\n\n",
      "WHY: We refuse to guess how to treat your predictors.\n",
      "     Explicit declaration prevents silent misinterpretation.\n",
      call. = FALSE
    )
  }

  # Check all drivers have settings
  missing_drivers <- setdiff(config$driver_vars, driver_settings$driver)
  if (length(missing_drivers) > 0) {
    stop(
      "\n",
      "=== CATDRIVER HARD ERROR ===\n",
      "Missing DRIVER_SETTINGS for drivers:\n",
      paste("  -", missing_drivers, collapse = "\n"), "\n\n",
      "FIX: Add rows for these drivers in DRIVER_SETTINGS sheet.\n",
      call. = FALSE
    )
  }

  # Check type column is valid
  invalid_types <- driver_settings$type[!driver_settings$type %in% c("categorical", "ordinal", "continuous")]
  if (length(invalid_types) > 0) {
    stop(
      "\n",
      "=== CATDRIVER HARD ERROR ===\n",
      "Invalid driver types in DRIVER_SETTINGS: ",
      paste(unique(invalid_types), collapse = ", "), "\n\n",
      "VALID VALUES: categorical, ordinal, continuous\n",
      call. = FALSE
    )
  }

  invisible(TRUE)
}


#' Guard: Validate Reference Category Not Missing
#'
#' HARD ERROR if reference category is "Missing" without explicit permission.
#'
#' @param config Configuration list
#' @param prep_data Preprocessed data with reference info
#' @keywords internal
guard_reference_not_missing <- function(config, prep_data) {
  allow_missing_ref <- isTRUE(config$allow_missing_reference)

  if (allow_missing_ref) {
    return(invisible(TRUE))
  }

  # Check each predictor's reference
  for (var_name in names(prep_data$predictor_info)) {
    info <- prep_data$predictor_info[[var_name]]
    ref_level <- info$reference_level

    if (!is.null(ref_level)) {
      # Check if reference is a missing indicator
      missing_patterns <- c("missing", "not answered", "n/a", "na", "unknown", "refuse")
      is_missing_ref <- any(sapply(missing_patterns, function(p) {
        grepl(p, tolower(ref_level))
      }))

      if (is_missing_ref) {
        stop(
          "\n",
          "=== CATDRIVER HARD ERROR ===\n",
          "Reference category appears to be 'Missing' for: ", var_name, "\n",
          "Reference level: '", ref_level, "'\n\n",
          "WHY: Comparing to 'Missing' produces uninterpretable results.\n\n",
          "FIX: Either:\n",
          "  1. Specify a non-missing reference_level in DRIVER_SETTINGS, OR\n",
          "  2. Set 'allow_missing_reference = TRUE' in Settings (not recommended)\n",
          call. = FALSE
        )
      }
    }
  }

  invisible(TRUE)
}


#' Guard: Validate Term-Level Mapping
#'
#' HARD ERROR if any term cannot be mapped to a driver/level.
#'
#' @param mapping Term mapping data frame
#' @param model_terms Model term names
#' @keywords internal
guard_term_mapping_complete <- function(mapping, model_terms) {
  # Remove intercept
  model_terms <- model_terms[!grepl("^\\(Intercept\\)$", model_terms)]

  if (is.null(mapping) || nrow(mapping) == 0) {
    stop(
      "\n",
      "=== CATDRIVER HARD ERROR ===\n",
      "Term-to-level mapping failed completely.\n\n",
      "This is an internal error. Please report this issue.\n",
      call. = FALSE
    )
  }

  # Check all terms are mapped
  mapped_terms <- mapping$design_col
  unmapped <- setdiff(model_terms, mapped_terms)

  if (length(unmapped) > 0) {
    stop(
      "\n",
      "=== CATDRIVER HARD ERROR ===\n",
      "Could not map model terms to factor levels:\n",
      paste("  -", unmapped, collapse = "\n"), "\n\n",
      "This may occur with unusual factor level names.\n",
      "Check that level names don't contain special characters.\n",
      call. = FALSE
    )
  }

  invisible(TRUE)
}


#' Guard: Model Fit Success
#'
#' HARD ERROR if model fails and no fallback available.
#'
#' @param model_result Model result (may be error)
#' @param fallback_available Logical indicating fallback was attempted
#' @keywords internal
guard_model_fit_success <- function(model_result, fallback_available = FALSE) {
  if (inherits(model_result, "error")) {
    if (fallback_available) {
      stop(
        "\n",
        "=== CATDRIVER HARD ERROR ===\n",
        "Model fitting failed. Fallback estimator also failed.\n\n",
        "ERROR: ", model_result$message, "\n\n",
        "LIKELY CAUSES:\n",
        "  - Perfect separation (predictor perfectly predicts outcome)\n",
        "  - Severe multicollinearity\n",
        "  - Insufficient observations for model complexity\n\n",
        "FIX: Simplify model by:\n",
        "  - Collapsing rare categories\n",
        "  - Removing highly correlated predictors\n",
        "  - Increasing sample size\n",
        call. = FALSE
      )
    } else {
      stop(
        "\n",
        "=== CATDRIVER HARD ERROR ===\n",
        "Model fitting failed.\n\n",
        "ERROR: ", model_result$message, "\n",
        call. = FALSE
      )
    }
  }

  invisible(TRUE)
}
