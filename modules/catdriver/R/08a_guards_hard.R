# ==============================================================================
# CATEGORICAL KEY DRIVER - HARD ERROR GUARDS
# ==============================================================================
#
# Guards that produce hard errors (REFUSE TO RUN).
# These validate critical requirements before analysis.
#
# All guards use catdriver_refuse() for clean, intentional refusals.
# No stop() calls - refusals should look deliberate, not like crashes.
# TRS v1.0: No warnings for degraded output - use PARTIAL status instead.
#
# Related modules:
#   - 08_guard.R: Core guard framework and refusal mechanism
#   - 08b_guards_soft.R: Soft warning guards
#
# Version: 1.1 (TRS Hardening)
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
      reason = "CFG_OUTCOME_TYPE_MISSING",
      title = "OUTCOME TYPE NOT DECLARED",
      problem = "The 'outcome_type' setting is missing or set to 'auto'.",
      why_it_matters = "Auto-detection can select the wrong model type, producing misleading results.",
      fix = "Add 'outcome_type' to the Settings sheet.\nValid values: binary, ordinal, multinomial"
    )
  }

  valid_types <- c("binary", "ordinal", "multinomial")
  if (!outcome_type %in% valid_types) {
    catdriver_refuse(
      reason = "CFG_OUTCOME_TYPE_INVALID",
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
#' REFUSES if data outcome levels don't match config declaration.
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
      catdriver_refuse(
        reason = "CFG_OUTCOME_LEVELS_MISMATCH",
        title = "OUTCOME LEVELS MISMATCH",
        problem = "Outcome levels in data do not match config declaration.",
        why_it_matters = "Analysis cannot proceed with undeclared outcome categories.",
        fix = "Update the 'Order' column in Variables sheet to include all levels.",
        details = paste0(
          "LEVELS IN DATA NOT IN CONFIG:\n  ",
          paste(missing_from_config, collapse = ", "), "\n\n",
          "CONFIG DECLARED LEVELS:\n  ",
          paste(config_levels, collapse = ", ")
        )
      )
    }

    # TRS v1.0: Config levels missing from data is INFO, not warning
    # These levels will simply be ignored - this is not a degraded output
    missing_from_data <- setdiff(config_levels, data_levels)
    if (length(missing_from_data) > 0) {
      cat("   [INFO] Config declares outcome levels not found in data: ",
          paste(missing_from_data, collapse = ", "), "\n", sep = "")
      cat("   [INFO] These levels will be ignored.\n")
    }
  }

  # Check category count matches outcome type
  n_categories <- length(data_levels)
  outcome_type <- config$outcome_type

  if (outcome_type == "binary" && n_categories != 2) {
    catdriver_refuse(
      reason = "CFG_OUTCOME_COUNT_MISMATCH",
      title = "OUTCOME TYPE / CATEGORY COUNT MISMATCH",
      problem = paste0("Outcome declared as 'binary' but has ", n_categories, " categories."),
      why_it_matters = "Binary logistic regression requires exactly 2 outcome categories.",
      fix = paste0(
        "Either:\n",
        "  1. Change outcome_type to 'ordinal' or 'multinomial', OR\n",
        "  2. Recode your outcome to have exactly 2 categories"
      ),
      details = paste0("CATEGORIES FOUND: ", paste(data_levels, collapse = ", "))
    )
  }

  if (outcome_type %in% c("ordinal", "multinomial") && n_categories < 3) {
    catdriver_refuse(
      reason = "CFG_OUTCOME_COUNT_MISMATCH",
      title = "OUTCOME TYPE / CATEGORY COUNT MISMATCH",
      problem = paste0("Outcome declared as '", outcome_type, "' but has only ", n_categories, " categories."),
      why_it_matters = paste0(outcome_type, " models require 3+ categories."),
      fix = "Change outcome_type to 'binary' for 2-category outcomes."
    )
  }

  invisible(TRUE)
}


#' Guard: Require Multinomial Reporting Mode
#'
#' REFUSES if multinomial outcome without explicit reporting mode.
#' ONLY enforced when outcome_type == "multinomial".
#'
#' @param config Configuration list
#' @keywords internal
guard_require_multinomial_mode <- function(config) {
  # A1: Only check multinomial settings for multinomial outcomes
  if (config$outcome_type != "multinomial") {
    return(invisible(TRUE))
  }

  multinomial_mode <- config$multinomial_mode
  valid_modes <- c("baseline_category", "all_pairwise", "one_vs_all", "per_outcome")

  if (is.null(multinomial_mode) || !nzchar(multinomial_mode) || !multinomial_mode %in% valid_modes) {
    catdriver_refuse(
      reason = "CFG_MULTINOMIAL_MODE_MISSING",
      title = "MULTINOMIAL MODE REQUIRED",
      problem = "Outcome type is multinomial but multinomial_mode is missing or invalid.",
      why_it_matters = "Multinomial models produce multiple sets of odds ratios. We refuse to guess which one you want.",
      fix = paste0(
        "Add 'multinomial_mode' to Settings sheet.\n",
        "VALID VALUES:\n",
        "  - 'baseline_category': Compare all levels to one reference (default)\n",
        "  - 'per_outcome': Report ORs for each outcome level separately\n",
        "  - 'all_pairwise': Compare every pair of levels\n",
        "  - 'one_vs_all': Compare each level vs. all others (requires target_outcome_level)"
      )
    )
  }

  if (multinomial_mode == "one_vs_all") {
    target_level <- config$target_outcome_level
    if (is.null(target_level) || is.na(target_level) || !nzchar(target_level)) {
      catdriver_refuse(
        reason = "CFG_TARGET_OUTCOME_MISSING",
        title = "TARGET OUTCOME LEVEL REQUIRED",
        problem = "multinomial_mode is 'one_vs_all' but target_outcome_level is missing.",
        why_it_matters = "one_vs_all mode needs to know which outcome category to treat as 'success'.",
        fix = "Add 'target_outcome_level' to Settings sheet with the desired outcome category."
      )
    }
  }

  invisible(TRUE)
}


#' Guard: Require Driver Settings
#'
#' REFUSES if DRIVER_SETTINGS sheet missing or incomplete.
#'
#' @param config Configuration list
#' @keywords internal
guard_require_driver_settings <- function(config) {
  driver_settings <- config$driver_settings

  if (is.null(driver_settings) || nrow(driver_settings) == 0) {
    catdriver_refuse(
      reason = "CFG_DRIVER_SETTINGS_MISSING",
      title = "DRIVER_SETTINGS SHEET REQUIRED",
      problem = "The Driver_Settings sheet is missing or empty.",
      why_it_matters = "We refuse to guess how to treat your predictors. Explicit declaration prevents silent misinterpretation.",
      fix = paste0(
        "Add a 'Driver_Settings' sheet with these columns:\n\n",
        "REQUIRED COLUMNS:\n",
        "  - driver: Variable name (must match Variables sheet)\n",
        "  - type: categorical, ordinal, or control_only\n\n",
        "OPTIONAL COLUMNS:\n",
        "  - levels_order: Semicolon-separated level order\n",
        "  - reference_level: Reference category\n",
        "  - missing_strategy: drop_row, missing_as_level, error_if_missing\n",
        "  - rare_level_policy: warn_only, collapse_to_other, drop_level, error"
      )
    )
  }

  # Check all drivers have settings
  missing_drivers <- setdiff(config$driver_vars, driver_settings$driver)
  if (length(missing_drivers) > 0) {
    catdriver_refuse(
      reason = "CFG_DRIVER_SETTINGS_INCOMPLETE",
      title = "MISSING DRIVER_SETTINGS",
      problem = paste0("Missing settings for ", length(missing_drivers), " driver variable(s)."),
      why_it_matters = "All driver variables must have explicit type declarations.",
      fix = "Add rows for these drivers in Driver_Settings sheet.",
      details = paste0("MISSING DRIVERS:\n  ", paste(missing_drivers, collapse = "\n  "))
    )
  }

  # Check type column is valid (now includes control_only, excludes continuous)
  valid_types <- c("categorical", "ordinal", "binary", "control_only")
  invalid_rows <- which(!driver_settings$type %in% valid_types)

  if (length(invalid_rows) > 0) {
    invalid_info <- paste0(
      driver_settings$driver[invalid_rows], " = '",
      driver_settings$type[invalid_rows], "'"
    )
    catdriver_refuse(
      reason = "CFG_DRIVER_TYPE_INVALID",
      title = "INVALID DRIVER TYPE",
      problem = "One or more drivers have invalid types in Driver_Settings.",
      why_it_matters = "Only categorical, ordinal, binary, and control_only types are allowed for drivers.",
      fix = paste0(
        "Change the type to one of: ", paste(valid_types, collapse = ", "), "\n\n",
        "NOTE: Continuous predictors are not supported as 'drivers' in this module.\n",
        "      Use 'control_only' for covariates or the continuous driver module."
      ),
      details = paste0("INVALID ENTRIES:\n  ", paste(invalid_info, collapse = "\n  "))
    )
  }

  # E1: Check for continuous drivers (not allowed)
  continuous_drivers <- driver_settings$driver[driver_settings$type == "continuous"]
  if (length(continuous_drivers) > 0) {
    catdriver_refuse(
      reason = "CFG_CONTINUOUS_DRIVER_NOT_ALLOWED",
      title = "CONTINUOUS DRIVERS NOT ALLOWED",
      problem = paste0(length(continuous_drivers), " driver(s) are declared as 'continuous'."),
      why_it_matters = paste0(
        "The categorical key driver module is designed for categorical predictors.\n",
        "Continuous predictors require the continuous driver module for proper handling."
      ),
      fix = paste0(
        "Either:\n",
        "  1. Change type to 'control_only' to include as covariate (excluded from driver reports)\n",
        "  2. Bin the variable into categories and use 'ordinal' type\n",
        "  3. Use the continuous driver module instead"
      ),
      details = paste0("CONTINUOUS DRIVERS:\n  ", paste(continuous_drivers, collapse = "\n  "))
    )
  }

  invisible(TRUE)
}


#' Guard: Validate Reference Category Not Missing
#'
#' REFUSES if reference category is "Missing" without explicit permission.
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
      # IMPORTANT: Use word boundaries (\b) for short patterns to prevent false positives
      # e.g., "na" would incorrectly match "Finance" without word boundaries
      ref_lower <- tolower(ref_level)

      # Short patterns that need word boundaries (could be substrings of valid levels)
      missing_patterns_bounded <- c("^na$", "^n/a$", "^dk$", "^rf$", "\\bna\\b", "\\bn/a\\b")
      # Longer patterns safe to match as substrings
      missing_patterns_substring <- c("missing", "not answered", "not stated", "unknown",
                                       "refused", "decline", "prefer not", "no response")

      is_missing_ref <- any(sapply(missing_patterns_bounded, function(p) {
        grepl(p, ref_lower)
      })) || any(sapply(missing_patterns_substring, function(p) {
        grepl(p, ref_lower, fixed = TRUE)
      }))

      if (is_missing_ref) {
        catdriver_refuse(
          reason = "CFG_REFERENCE_IS_MISSING",
          title = "REFERENCE CATEGORY IS MISSING INDICATOR",
          problem = paste0("Reference category for '", var_name, "' appears to be a missing indicator."),
          why_it_matters = "Comparing to 'Missing' produces uninterpretable results.",
          fix = paste0(
            "Either:\n",
            "  1. Specify a non-missing reference_level in Driver_Settings, OR\n",
            "  2. Set 'allow_missing_reference = TRUE' in Settings (not recommended)"
          ),
          details = paste0("Reference level: '", ref_level, "'")
        )
      }
    }
  }

  invisible(TRUE)
}


#' Guard: Validate Term-Level Mapping
#'
#' REFUSES if any term cannot be mapped to a driver/level.
#'
#' @param mapping Term mapping data frame
#' @param model_terms Model term names
#' @keywords internal
guard_term_mapping_complete <- function(mapping, model_terms) {
  # Remove intercept
  model_terms <- model_terms[!grepl("^\\(Intercept\\)$", model_terms)]

  if (is.null(mapping) || nrow(mapping) == 0) {
    catdriver_refuse(
      reason = "CFG_MAPPING_FAILED",
      title = "TERM-TO-LEVEL MAPPING FAILED",
      problem = "Could not create mapping between model terms and factor levels.",
      why_it_matters = "Without proper mapping, odds ratios cannot be correctly attributed to categories.",
      fix = "This is an internal error. Please check that factor levels don't contain unusual characters.",
      details = "Mapping returned NULL or empty data frame."
    )
  }

  # Check all terms are mapped
  mapped_terms <- mapping$design_col
  unmapped <- setdiff(model_terms, mapped_terms)

  if (length(unmapped) > 0) {
    catdriver_refuse(
      reason = "CFG_MAPPING_INCOMPLETE",
      title = "INCOMPLETE TERM MAPPING",
      problem = paste0(length(unmapped), " model term(s) could not be mapped to factor levels."),
      why_it_matters = "All model coefficients must be traceable to specific category comparisons.",
      fix = "Check that level names don't contain special characters that could confuse the mapper.",
      details = paste0("UNMAPPED TERMS:\n  ", paste(unmapped, collapse = "\n  "))
    )
  }

  invisible(TRUE)
}


#' Guard: Model Fit Success
#'
#' REFUSES if model fails and no fallback available.
#'
#' @param model_result Model result (may be error)
#' @param fallback_available Logical indicating fallback was attempted
#' @keywords internal
guard_model_fit_success <- function(model_result, fallback_available = FALSE) {
  if (inherits(model_result, "error")) {
    if (fallback_available) {
      catdriver_refuse(
        reason = "MODEL_FIT_FAILED",
        title = "MODEL FITTING FAILED",
        problem = "Model fitting failed. Fallback estimator also failed.",
        why_it_matters = "Cannot produce results without a fitted model.",
        fix = paste0(
          "Simplify the model by:\n",
          "  - Collapsing rare categories\n",
          "  - Removing highly correlated predictors\n",
          "  - Increasing sample size"
        ),
        details = paste0(
          "ERROR: ", model_result$message, "\n\n",
          "LIKELY CAUSES:\n",
          "  - Perfect separation (predictor perfectly predicts outcome)\n",
          "  - Severe multicollinearity\n",
          "  - Insufficient observations for model complexity"
        )
      )
    } else {
      catdriver_refuse(
        reason = "MODEL_FIT_FAILED",
        title = "MODEL FITTING FAILED",
        problem = "Model fitting failed.",
        why_it_matters = "Cannot produce results without a fitted model.",
        fix = "Check the error message below and adjust your data or configuration.",
        details = paste0("ERROR: ", model_result$message)
      )
    }
  }

  invisible(TRUE)
}


#' Guard: Validate Ordinal Levels Order
#'
#' REFUSES if ordinal driver missing levels_order specification.
#'
#' @param config Configuration list
#' @keywords internal
guard_ordinal_levels_order <- function(config) {
  driver_settings <- config$driver_settings

  if (is.null(driver_settings)) {
    return(invisible(TRUE))
  }

  ordinal_drivers <- driver_settings$driver[driver_settings$type == "ordinal"]

  for (driver_var in ordinal_drivers) {
    levels_order <- get_driver_setting(config, driver_var, "levels_order", NULL)

    if (is.null(levels_order) || is.na(levels_order) || !nzchar(levels_order)) {
      catdriver_refuse(
        reason = "CFG_ORDINAL_ORDER_MISSING",
        title = "ORDINAL LEVELS ORDER REQUIRED",
        problem = paste0("Driver '", driver_var, "' is declared as ordinal but has no levels_order."),
        why_it_matters = "Ordinal models require knowing the ordering of categories (e.g., Low < Medium < High).",
        fix = paste0(
          "Add 'levels_order' in Driver_Settings for '", driver_var, "'.\n",
          "Format: Semicolon-separated from lowest to highest (e.g., 'Low;Medium;High')"
        )
      )
    }
  }

  invisible(TRUE)
}
