# ==============================================================================
# CATEGORICAL KEY DRIVER - SOFT WARNING GUARDS
# ==============================================================================
#
# Guards that produce warnings but allow analysis to continue.
# These track potential issues without blocking execution.
#
# Related modules:
#   - 08_guard.R: Core guard framework and refusal mechanism
#   - 08a_guards_hard.R: Hard error guards
#
# Version: 2.0
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

      # Heavy collapsing if >5 levels collapsed
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
