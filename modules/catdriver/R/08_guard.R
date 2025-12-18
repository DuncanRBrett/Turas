# ==============================================================================
# CATEGORICAL KEY DRIVER - TURASGUARD LAYER
# ==============================================================================
#
# Validation and error enforcement layer. Implements "no silent failures"
# philosophy with explicit hard errors and soft warnings.
#
# Version: 2.0
# Date: December 2024
#
# ==============================================================================

# ==============================================================================
# GUARD STATE TRACKING
# ==============================================================================

#' Initialize Guard State
#'
#' Creates a new guard state object to track warnings and issues.
#'
#' @return Guard state list
#' @export
guard_init <- function() {
  list(
    warnings = character(0),
    soft_failures = list(),
    fallback_used = FALSE,
    fallback_reason = NULL,
    stability_flags = character(0),
    collapsed_levels = list(),
    dropped_predictors = character(0),
    missing_handled = list()
  )
}

#' Add Warning to Guard State
#'
#' @param guard Guard state object
#' @param message Warning message
#' @param category Warning category
#' @return Updated guard state
#' @keywords internal
guard_warn <- function(guard, message, category = "general") {
  guard$warnings <- c(guard$warnings, message)
  guard$soft_failures[[category]] <- c(guard$soft_failures[[category]], message)
  guard
}

#' Add Stability Flag
#'
#' @param guard Guard state object
#' @param flag Stability flag text
#' @return Updated guard state
#' @keywords internal
guard_flag_stability <- function(guard, flag) {
  guard$stability_flags <- unique(c(guard$stability_flags, flag))
  guard
}


# ==============================================================================
# HARD ERRORS - REFUSE TO RUN
# ==============================================================================

#' Guard: Validate Outcome Type Declaration
#'
#' HARD ERROR if outcome type not explicitly declared.
#'
#' @param config Configuration list
#' @keywords internal
guard_require_outcome_type <- function(config) {
  outcome_type <- config$outcome_type

  if (is.null(outcome_type) || outcome_type == "auto") {
    stop(
      "\n",
      "=== CATDRIVER HARD ERROR ===\n",
      "Outcome type must be explicitly declared in config.\n\n",
      "REQUIRED: Add 'outcome_type' to Settings sheet.\n",
      "VALID VALUES: binary, ordinal, multinomial\n\n",
      "WHY: Auto-detection can produce incorrect model selection.\n",
      "     Explicit declaration ensures you get the analysis you intend.\n",
      call. = FALSE
    )
  }

  valid_types <- c("binary", "ordinal", "multinomial")
  if (!outcome_type %in% valid_types) {
    stop(
      "\n",
      "=== CATDRIVER HARD ERROR ===\n",
      "Invalid outcome_type: '", outcome_type, "'\n\n",
      "VALID VALUES: ", paste(valid_types, collapse = ", "), "\n",
      call. = FALSE
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


# ==============================================================================
# SOFT FAILURES - WARNINGS IN OUTPUT
# ==============================================================================

#' Guard: Check Fallback Estimator Used
#'
#' SOFT FAILURE - warns but continues.
#'
#' @param guard Guard state object
#' @param used Logical - was fallback used?
#' @param reason Reason for fallback
#' @return Updated guard state
#' @keywords internal
guard_check_fallback <- function(guard, used, reason = NULL) {
  if (used) {
    guard$fallback_used <- TRUE
    guard$fallback_reason <- reason
    guard <- guard_warn(guard,
      paste("Fallback estimator used:", reason),
      "model_estimation"
    )
    guard <- guard_flag_stability(guard, "Fallback estimator used")
  }
  guard
}


#' Guard: Check Collapsing Extent
#'
#' SOFT FAILURE if heavy collapsing performed.
#'
#' @param guard Guard state object
#' @param collapsed_levels List of collapsed levels by variable
#' @return Updated guard state
#' @keywords internal
guard_check_collapsing <- function(guard, collapsed_levels) {
  if (length(collapsed_levels) > 0) {
    guard$collapsed_levels <- collapsed_levels

    total_collapsed <- sum(sapply(collapsed_levels, length))

    if (total_collapsed > 0) {
      msg <- sprintf("Collapsed %d rare levels across %d predictors",
                     total_collapsed, length(collapsed_levels))
      guard <- guard_warn(guard, msg, "data_preparation")

      # Heavy collapsing if >20% of original levels
      # (simplified check - would need original counts)
      if (total_collapsed > 5) {
        guard <- guard_flag_stability(guard, "Heavy level collapsing performed")
      }
    }
  }
  guard
}


#' Guard: Check Sample Size Adequacy
#'
#' SOFT FAILURE if sample size concerning.
#'
#' @param guard Guard state object
#' @param n_obs Number of observations
#' @param n_params Number of parameters
#' @param outcome_type Outcome type
#' @return Updated guard state
#' @keywords internal
guard_check_sample_size <- function(guard, n_obs, n_params, outcome_type) {
  # Events per parameter rule
  epp <- n_obs / n_params

  if (epp < 10) {
    guard <- guard_warn(guard,
      sprintf("Low events-per-parameter ratio (%.1f). Recommend >= 10 for stable estimates.", epp),
      "sample_size"
    )
    guard <- guard_flag_stability(guard, "Low events-per-parameter ratio")
  }

  if (n_obs < 100) {
    guard <- guard_warn(guard,
      sprintf("Small sample size (N=%d). Results may have wide confidence intervals.", n_obs),
      "sample_size"
    )
  }

  guard
}


#' Guard: Check Proportional Odds Assumption
#'
#' SOFT FAILURE if PO assumption questionable.
#'
#' @param guard Guard state object
#' @param po_check Proportional odds check result
#' @return Updated guard state
#' @keywords internal
guard_check_proportional_odds <- function(guard, po_check) {
  if (!is.null(po_check) && po_check$checked) {
    if (po_check$status == "WARNING") {
      guard <- guard_warn(guard,
        po_check$interpretation,
        "model_assumptions"
      )
      guard <- guard_flag_stability(guard, "Proportional odds assumption may be violated")
    }
  }
  guard
}


#' Guard: Check Multicollinearity
#'
#' SOFT FAILURE if high multicollinearity.
#'
#' @param guard Guard state object
#' @param vif_check VIF check result
#' @return Updated guard state
#' @keywords internal
guard_check_multicollinearity <- function(guard, vif_check) {
  if (!is.null(vif_check) && vif_check$checked) {
    if (vif_check$status == "WARNING") {
      guard <- guard_warn(guard,
        vif_check$interpretation,
        "model_assumptions"
      )
      guard <- guard_flag_stability(guard, "High multicollinearity detected")
    }
  }
  guard
}


# ==============================================================================
# DIRECTION SANITY CHECK (TRIP-WIRE)
# ==============================================================================

#' Guard: Direction Sanity Check
#'
#' Verifies that OR directions align with raw data patterns.
#' Stops if systematic reversal detected.
#'
#' @param guard Guard state object
#' @param prep_data Preprocessed data
#' @param model_result Model results
#' @param config Configuration
#' @return Updated guard state (or stops on error)
#' @keywords internal
guard_direction_sanity <- function(guard, prep_data, model_result, config) {

  # Only check for ordinal outcomes (where direction matters most)
  if (prep_data$outcome_info$type != "ordinal") {
    return(guard)
  }

  outcome_var <- config$outcome_var
  outcome_levels <- levels(prep_data$data[[outcome_var]])
  n_levels <- length(outcome_levels)

  # Get top driver(s)
  coefs <- model_result$coefficients
  if (is.null(coefs) || nrow(coefs) == 0) {
    return(guard)
  }

  # For each driver, check if OR direction matches raw proportion pattern
  mismatches <- 0
  checked <- 0

  for (driver_var in config$driver_vars[1:min(3, length(config$driver_vars))]) {
    driver_data <- prep_data$data[[driver_var]]
    if (!is.factor(driver_data)) next

    driver_levels <- levels(driver_data)
    if (length(driver_levels) < 2) next

    ref_level <- driver_levels[1]

    # Calculate raw proportion in highest outcome category
    outcome_data <- prep_data$data[[outcome_var]]
    high_level <- outcome_levels[n_levels]

    # Reference group proportion in high
    ref_prop <- mean(outcome_data[driver_data == ref_level] == high_level, na.rm = TRUE)

    # Check other levels
    for (level in driver_levels[-1]) {
      level_prop <- mean(outcome_data[driver_data == level] == high_level, na.rm = TRUE)

      # Find matching coefficient
      term_pattern <- paste0("^", driver_var, level)
      matching_rows <- grepl(term_pattern, coefs$term, fixed = FALSE)

      if (any(matching_rows)) {
        or_val <- coefs$odds_ratio[which(matching_rows)[1]]

        if (!is.na(or_val) && !is.na(level_prop) && !is.na(ref_prop)) {
          checked <- checked + 1

          # Check direction consistency
          # If level has higher proportion in high outcome, OR should be > 1
          # If level has lower proportion, OR should be < 1
          prop_diff <- level_prop - ref_prop

          if ((prop_diff > 0.05 && or_val < 0.8) || (prop_diff < -0.05 && or_val > 1.25)) {
            mismatches <- mismatches + 1
          }
        }
      }
    }
  }

  # If majority of checked comparisons mismatch, likely reversal
  if (checked > 2 && mismatches / checked > 0.5) {
    stop(
      "\n",
      "=== CATDRIVER HARD ERROR ===\n",
      "Direction sanity check FAILED.\n\n",
      "Odds ratio directions do not align with raw data patterns.\n",
      "This usually means the outcome ordering is reversed.\n\n",
      "OUTCOME ORDER IN CONFIG: ", paste(outcome_levels, collapse = " < "), "\n\n",
      "FIX: Check the 'Order' column for your outcome variable.\n",
      "     Ensure Low values are listed BEFORE High values.\n",
      "     For satisfaction: 'Dissatisfied; Neutral; Satisfied'\n",
      "     NOT: 'Satisfied; Neutral; Dissatisfied'\n",
      call. = FALSE
    )
  }

  guard
}


# ==============================================================================
# COMPREHENSIVE VALIDATION
# ==============================================================================

#' Run All Pre-Analysis Guards
#'
#' Validates config and data before analysis begins.
#'
#' @param config Configuration list
#' @param data Data frame
#' @return Guard state object
#' @export
guard_pre_analysis <- function(config, data) {
  guard <- guard_init()

  # Hard error checks
  guard_require_outcome_type(config)
  guard_outcome_levels_match(data, config)
  guard_require_multinomial_mode(config)
  guard_require_driver_settings(config)

  guard
}


#' Run All Post-Model Guards
#'
#' Validates model results and adds appropriate warnings.
#'
#' @param guard Guard state object
#' @param prep_data Preprocessed data
#' @param model_result Model results
#' @param config Configuration
#' @return Updated guard state
#' @export
guard_post_model <- function(guard, prep_data, model_result, config) {
  # Reference category check
  guard_reference_not_missing(config, prep_data)

  # Direction sanity
  guard <- guard_direction_sanity(guard, prep_data, model_result, config)

  # Sample size checks
  n_obs <- nrow(prep_data$data)
  n_params <- prep_data$n_terms
  guard <- guard_check_sample_size(guard, n_obs, n_params, config$outcome_type)

  # Proportional odds check (ordinal only)
  if (!is.null(model_result$proportional_odds)) {
    guard <- guard_check_proportional_odds(guard, model_result$proportional_odds)
  }

  guard
}


#' Get Guard Summary for Output
#'
#' Creates summary of all warnings and flags for output.
#'
#' @param guard Guard state object
#' @return List with summary info
#' @export
guard_summary <- function(guard) {
  has_issues <- length(guard$warnings) > 0 ||
                length(guard$stability_flags) > 0 ||
                guard$fallback_used

  list(
    has_issues = has_issues,
    n_warnings = length(guard$warnings),
    warnings = guard$warnings,
    stability_flags = guard$stability_flags,
    fallback_used = guard$fallback_used,
    fallback_reason = guard$fallback_reason,
    use_with_caution = length(guard$stability_flags) > 0
  )
}
