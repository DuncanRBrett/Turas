# ==============================================================================
# CONFIDENCE ANALYSIS - QUESTION PROCESSING MODULE
# ==============================================================================
# Handles question-level processing for all statistic types:
# - Proportion questions (with categories)
# - Mean questions (numeric data)
# - NPS questions (promoters, passives, detractors)
#
# Each processor function:
# 1. Validates question data
# 2. Handles weighting if applicable
# 3. Calculates point estimates
# 4. Computes confidence intervals (MOE, Wilson, Bootstrap, Bayesian)
# 5. Collects and returns warnings
#
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.1 - Extracted from 00_main.R for maintainability (2025-12-27)
#
# USAGE:
# This file is sourced automatically by 00_main.R at load time.
# Functions are called by main_workflow.R during question processing.
#
# DEPENDENCIES:
# - utils.R (parse_codes, validate_sample_size)
# - 04_proportions.R (CI calculation functions)
# - 05_means.R (CI calculation functions)
# ==============================================================================

PROCESSING_VERSION <- "10.1"

# ==============================================================================
# PROPORTION QUESTION PROCESSING
# ==============================================================================

#' Process proportion question
#'
#' Analyzes a single proportion question, calculating the proportion of
#' respondents in specified categories and computing various confidence intervals.
#'
#' WORKFLOW:
#' 1. Validate question exists in data
#' 2. Extract and validate weights (if applicable)
#' 3. Parse categories from config
#' 4. Clean and align values and weights
#' 5. Calculate observed proportion and effective n
#' 6. Compute confidence intervals per config flags (MOE, Wilson, Bootstrap, Bayesian)
#'
#' @param q_row Data frame row. Configuration for this question
#' @param survey_data Data frame. Survey data with all questions
#' @param weight_var Character. Name of weight variable (NULL for unweighted)
#' @param config List. Full configuration including study_settings
#' @param warnings_list Character vector. Existing warnings to append to
#'
#' @return List with:
#'   - result: List of statistics and CIs (or NULL if failed)
#'   - warnings: Updated warnings vector
#'
#' @keywords internal
process_proportion_question <- function(q_row, survey_data, weight_var, config, warnings_list) {
  q_id <- q_row$Question_ID
  result <- list()

  tryCatch({
    # -------------------------------------------------------------------------
    # 1. Check question exists
    # -------------------------------------------------------------------------
    if (!q_id %in% names(survey_data)) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: Not found in data", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    values <- survey_data[[q_id]]

    # -------------------------------------------------------------------------
    # 2. Get weights (if applicable)
    # -------------------------------------------------------------------------
    weights <- NULL
    if (!is.null(weight_var) && nzchar(weight_var) && weight_var %in% names(survey_data)) {
      weights <- survey_data[[weight_var]]
    }

    # -------------------------------------------------------------------------
    # 3. Parse categories and basic validation
    # -------------------------------------------------------------------------
    categories <- parse_codes(q_row$Categories)
    if (length(categories) == 0) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: No categories specified", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    # -------------------------------------------------------------------------
    # 4. Clean and align values and weights
    # -------------------------------------------------------------------------
    # Start with non-missing values
    valid_value_idx <- !is.na(values)

    if (!is.null(weights)) {
      # Keep only respondents with a valid answer AND valid weight
      weights_raw <- weights
      good_idx <- valid_value_idx & !is.na(weights_raw) & weights_raw > 0

      values_valid  <- values[good_idx]
      weights_valid <- weights_raw[good_idx]

      if (length(values_valid) == 0) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: No valid cases after applying weights", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    } else {
      values_valid  <- values[valid_value_idx]
      weights_valid <- NULL

      if (length(values_valid) == 0) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: No valid (non-missing) responses", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    }

    # -------------------------------------------------------------------------
    # 5. Calculate observed proportion and effective n
    # -------------------------------------------------------------------------
    in_category <- values_valid %in% categories

    if (!is.null(weights_valid)) {
      total_w   <- sum(weights_valid)
      success_w <- sum(weights_valid[in_category])

      if (isTRUE(total_w <= 0)) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Total weight is zero or negative", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }

      p      <- success_w / total_w
      n_eff  <- calculate_effective_n(weights_valid)
      n_raw  <- length(values_valid)
    } else {
      p      <- mean(in_category)
      n_eff  <- length(values_valid)
      n_raw  <- length(values_valid)
    }

    # Basic sanity check
    if (is.na(p)) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: Proportion could not be calculated (NA)", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    # -------------------------------------------------------------------------
    # 6. Store core stats for this question
    # -------------------------------------------------------------------------
    result$category   <- paste(categories, collapse = ",")
    result$proportion <- p
    result$n          <- n_raw
    result$n_eff      <- n_eff

    # -------------------------------------------------------------------------
    # 7. Confidence intervals according to config
    # -------------------------------------------------------------------------
    conf_level <- as.numeric(config$study_settings$Confidence_Level)

    # Margin of error (normal approximation using effective n)
    run_moe_flag <- q_row$Run_MOE
    if (!is.null(run_moe_flag) &&
        !is.na(run_moe_flag) &&
        toupper(run_moe_flag) == "Y") {
      if (!is.na(n_eff) && n_eff > 0) {
        result$moe <- calculate_proportion_ci_normal(p, n_eff, conf_level)
      } else {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Effective n <= 0, MOE CI not calculated", q_id)
        )
      }
    }

    # Wilson interval (using Use_Wilson flag)
    # Check if Use_Wilson column exists (backward compatibility with old configs)
    use_wilson_flag <- if ("Use_Wilson" %in% names(q_row)) q_row$Use_Wilson else NULL
    if (!is.null(use_wilson_flag) &&
        !is.na(use_wilson_flag) &&
        toupper(use_wilson_flag) == "Y") {
      if (!is.na(n_eff) && n_eff > 0) {
        result$wilson <- calculate_proportion_ci_wilson(p, n_eff, conf_level)
      } else {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Effective n <= 0, Wilson CI not calculated", q_id)
        )
      }
    }

    # Bootstrap CI
    run_boot_flag <- q_row$Run_Bootstrap
    if (!is.null(run_boot_flag) &&
        !is.na(run_boot_flag) &&
        toupper(run_boot_flag) == "Y") {
      boot_iter <- as.integer(config$study_settings$Bootstrap_Iterations)
      result$bootstrap <- bootstrap_proportion_ci(
        data       = values_valid,
        categories = categories,
        weights    = weights_valid,
        B          = boot_iter,
        conf_level = conf_level
      )
    }

    # Bayesian CI (Beta-Binomial)
    run_cred_flag <- q_row$Run_Credible
    if (!is.null(run_cred_flag) &&
        !is.na(run_cred_flag) &&
        toupper(run_cred_flag) == "Y") {
      prior_mean <- if (!is.na(q_row$Prior_Mean)) q_row$Prior_Mean else NULL
      prior_n    <- if (!is.na(q_row$Prior_N))    q_row$Prior_N    else NULL

      # Use effective n for weighted data, raw n otherwise
      n_bayes <- if (!is.null(weights_valid)) n_eff else length(values_valid)

      result$bayesian <- credible_interval_proportion(
        p          = p,
        n          = n_bayes,
        conf_level = conf_level,
        prior_mean = prior_mean,
        prior_n    = prior_n
      )
    }

  }, error = function(e) {
    warnings_list <- c(
      warnings_list,
      sprintf("Question %s: %s", q_id, conditionMessage(e))
    )
  })

  return(list(result = result, warnings = warnings_list))
}


# ==============================================================================
# MEAN QUESTION PROCESSING
# ==============================================================================

#' Process mean question
#'
#' Analyzes a single mean question, calculating the mean of numeric responses
#' and computing various confidence intervals.
#'
#' WORKFLOW:
#' 1. Validate question exists and is numeric
#' 2. Handle smart numeric conversion for text-formatted numbers
#' 3. Extract and validate weights (if applicable)
#' 4. Clean and align values and weights
#' 5. Calculate mean, SD, and effective n
#' 6. Compute confidence intervals per config flags (t-dist, Bootstrap, Bayesian)
#'
#' @param q_row Data frame row. Configuration for this question
#' @param survey_data Data frame. Survey data with all questions
#' @param weight_var Character. Name of weight variable (NULL for unweighted)
#' @param config List. Full configuration including study_settings
#' @param warnings_list Character vector. Existing warnings to append to
#'
#' @return List with:
#'   - result: List of statistics and CIs (or NULL if failed)
#'   - warnings: Updated warnings vector
#'
#' @keywords internal
process_mean_question <- function(q_row, survey_data, weight_var, config, warnings_list) {
  q_id <- q_row$Question_ID
  result <- list()

  tryCatch({
    # -------------------------------------------------------------------------
    # 1. Check question exists
    # -------------------------------------------------------------------------
    if (!q_id %in% names(survey_data)) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: Not found in data", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    values <- survey_data[[q_id]]

    # Attempt to convert to numeric if not already numeric
    # (handles case where numeric data is stored as character/text in source file)
    if (!is.numeric(values)) {
      # Try conversion
      values_converted <- suppressWarnings(as.numeric(values))

      # Smart conversion check that handles questions with low response due to routing
      n_total <- length(values)

      # Count NAs in original data (routing/skip logic)
      n_was_na_before <- sum(is.na(values) | trimws(as.character(values)) == "")

      # Count valid numbers after conversion
      n_valid_after_conversion <- sum(!is.na(values_converted))

      # Count how many non-missing values we had
      n_non_missing_before <- n_total - n_was_na_before

      # If we have at least 10 valid numbers AND didn't lose more than 20% in conversion, accept it
      # This handles: (1) routed questions with low n, (2) text-formatted numeric columns
      if (n_valid_after_conversion >= 10 && n_non_missing_before > 0) {
        conversion_success_rate <- n_valid_after_conversion / n_non_missing_before
        if (conversion_success_rate >= 0.80) {
          values <- values_converted
        } else {
          # Most non-missing values couldn't convert - truly non-numeric
          warnings_list <- c(
            warnings_list,
            sprintf("Question %s: Non-numeric values for mean analysis (only %d/%d non-missing values convertible)",
                    q_id, n_valid_after_conversion, n_non_missing_before)
          )
          return(list(result = NULL, warnings = warnings_list))
        }
      } else {
        # Too few responses or all missing
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Insufficient numeric data for mean analysis (only %d valid values)",
                  q_id, n_valid_after_conversion)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    }

    # -------------------------------------------------------------------------
    # 2. Get weights (if applicable)
    # -------------------------------------------------------------------------
    weights <- NULL
    if (!is.null(weight_var) && nzchar(weight_var) && weight_var %in% names(survey_data)) {
      weights <- survey_data[[weight_var]]
    }

    # -------------------------------------------------------------------------
    # 3. Clean and align values and weights
    # -------------------------------------------------------------------------
    # Start with non-missing numeric values
    valid_value_idx <- !is.na(values) & is.finite(values)

    if (!is.null(weights)) {
      weights_raw <- weights
      # Keep only respondents with valid value AND valid weight
      good_idx <- valid_value_idx & !is.na(weights_raw) & weights_raw > 0

      values_valid  <- values[good_idx]
      weights_valid <- weights_raw[good_idx]

      if (length(values_valid) == 0) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: No valid cases after applying weights", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    } else {
      values_valid  <- values[valid_value_idx]
      weights_valid <- NULL

      if (length(values_valid) == 0) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: No valid (non-missing) numeric responses", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    }

    # -------------------------------------------------------------------------
    # 4. Calculate mean, SD and effective n
    # -------------------------------------------------------------------------
    if (!is.null(weights_valid) && length(weights_valid) > 0) {
      # Weighted mean
      total_w <- sum(weights_valid)
      if (isTRUE(total_w <= 0)) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Total weight is zero or negative", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }

      mean_val <- sum(values_valid * weights_valid) / total_w

      # Weighted variance (population estimator, consistent with effective n)
      weighted_var <- sum(weights_valid * (values_valid - mean_val)^2) / total_w
      sd_val       <- sqrt(weighted_var)

      n_eff <- calculate_effective_n(weights_valid)
      n_raw <- length(values_valid)
    } else {
      # Unweighted
      mean_val <- mean(values_valid)
      sd_val   <- sd(values_valid)
      n_eff    <- length(values_valid)
      n_raw    <- length(values_valid)
      weights_valid <- NULL  # be explicit
    }

    result$mean  <- mean_val
    result$sd    <- sd_val
    result$n     <- n_raw
    result$n_eff <- n_eff

    # -------------------------------------------------------------------------
    # 5. Confidence intervals according to config
    # -------------------------------------------------------------------------
    conf_level <- as.numeric(config$study_settings$Confidence_Level)

    # t-distribution CI (uses n_eff internally in calculate_mean_ci)
    run_moe_flag <- q_row$Run_MOE
    if (!is.null(run_moe_flag) &&
        !is.na(run_moe_flag) &&
        toupper(run_moe_flag) == "Y") {
      result$t_dist <- calculate_mean_ci(
        values     = values_valid,
        weights    = weights_valid,
        conf_level = conf_level
      )
    }

    # Bootstrap CI
    run_boot_flag <- q_row$Run_Bootstrap
    if (!is.null(run_boot_flag) &&
        !is.na(run_boot_flag) &&
        toupper(run_boot_flag) == "Y") {
      boot_iter <- as.integer(config$study_settings$Bootstrap_Iterations)
      result$bootstrap <- bootstrap_mean_ci(
        values     = values_valid,
        weights    = weights_valid,
        B          = boot_iter,
        conf_level = conf_level
      )
    }

    # Bayesian CI for the mean
    run_cred_flag <- q_row$Run_Credible
    if (!is.null(run_cred_flag) &&
        !is.na(run_cred_flag) &&
        toupper(run_cred_flag) == "Y") {
      prior_mean <- if (!is.na(q_row$Prior_Mean)) q_row$Prior_Mean else NULL
      prior_sd   <- if (!is.na(q_row$Prior_SD))   q_row$Prior_SD   else NULL
      prior_n    <- if (!is.na(q_row$Prior_N))    q_row$Prior_N    else NULL

      result$bayesian <- credible_interval_mean(
        values     = values_valid,
        weights    = weights_valid,
        conf_level = conf_level,
        prior_mean = prior_mean,
        prior_sd   = prior_sd,
        prior_n    = prior_n
      )
    }

  }, error = function(e) {
    warnings_list <- c(
      warnings_list,
      sprintf("Question %s: %s", q_id, conditionMessage(e))
    )
  })

  return(list(result = result, warnings = warnings_list))
}


# ==============================================================================
# NPS QUESTION PROCESSING
# ==============================================================================

#' Process NPS question
#'
#' Analyzes a single NPS (Net Promoter Score) question, calculating the
#' percentage of promoters and detractors, computing NPS, and various CIs.
#'
#' NPS = % Promoters - % Detractors
#'
#' WORKFLOW:
#' 1. Validate question exists and is numeric
#' 2. Extract and validate weights (if applicable)
#' 3. Parse promoter and detractor codes from config
#' 4. Clean and align values and weights
#' 5. Calculate NPS components (% promoters, % detractors, % passives)
#' 6. Compute confidence intervals per config flags (Normal, Bootstrap, Bayesian)
#'
#' @param q_row Data frame row. Configuration for this question
#' @param survey_data Data frame. Survey data with all questions
#' @param weight_var Character. Name of weight variable (NULL for unweighted)
#' @param config List. Full configuration including study_settings
#' @param warnings_list Character vector. Existing warnings to append to
#'
#' @return List with:
#'   - result: List of statistics and CIs (or NULL if failed)
#'   - warnings: Updated warnings vector
#'
#' @keywords internal
process_nps_question <- function(q_row, survey_data, weight_var, config, warnings_list) {
  q_id <- q_row$Question_ID
  result <- list()

  tryCatch({
    # -------------------------------------------------------------------------
    # 1. Check question exists
    # -------------------------------------------------------------------------
    if (!q_id %in% names(survey_data)) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: Not found in data", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    values <- survey_data[[q_id]]

    # Require numeric for NPS analysis
    if (!is.numeric(values)) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: Non-numeric values for NPS analysis", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    # -------------------------------------------------------------------------
    # 2. Get weights (if applicable)
    # -------------------------------------------------------------------------
    weights <- NULL
    if (!is.null(weight_var) && nzchar(weight_var) && weight_var %in% names(survey_data)) {
      weights <- survey_data[[weight_var]]
    }

    # -------------------------------------------------------------------------
    # 3. Parse promoter and detractor codes
    # -------------------------------------------------------------------------
    promoter_codes <- parse_codes(q_row$Promoter_Codes)
    detractor_codes <- parse_codes(q_row$Detractor_Codes)

    if (length(promoter_codes) == 0) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: No promoter codes specified", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    if (length(detractor_codes) == 0) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: No detractor codes specified", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    # -------------------------------------------------------------------------
    # 4. Clean and align values and weights
    # -------------------------------------------------------------------------
    # Start with non-missing numeric values
    valid_value_idx <- !is.na(values) & is.finite(values)

    if (!is.null(weights)) {
      weights_raw <- weights
      # Keep only respondents with valid answer AND valid weight
      good_idx <- valid_value_idx & !is.na(weights_raw) & weights_raw > 0

      values_valid  <- values[good_idx]
      weights_valid <- weights_raw[good_idx]

      if (length(values_valid) == 0) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: No valid cases after applying weights", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    } else {
      values_valid  <- values[valid_value_idx]
      weights_valid <- NULL

      if (length(values_valid) == 0) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: No valid (non-missing) responses", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    }

    # -------------------------------------------------------------------------
    # 5. Calculate NPS components
    # -------------------------------------------------------------------------
    is_promoter  <- values_valid %in% promoter_codes
    is_detractor <- values_valid %in% detractor_codes

    if (!is.null(weights_valid)) {
      total_w <- sum(weights_valid)

      if (isTRUE(total_w <= 0)) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Total weight is zero or negative", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }

      pct_promoters  <- 100 * sum(weights_valid[is_promoter]) / total_w
      pct_detractors <- 100 * sum(weights_valid[is_detractor]) / total_w
      n_eff <- calculate_effective_n(weights_valid)
      n_raw <- length(values_valid)
    } else {
      pct_promoters  <- 100 * mean(is_promoter)
      pct_detractors <- 100 * mean(is_detractor)
      n_eff <- length(values_valid)
      n_raw <- length(values_valid)
    }

    nps_score <- pct_promoters - pct_detractors

    # -------------------------------------------------------------------------
    # 6. Store core stats
    # -------------------------------------------------------------------------
    result$nps_score       <- nps_score
    result$pct_promoters   <- pct_promoters
    result$pct_detractors  <- pct_detractors
    result$pct_passives    <- 100 - pct_promoters - pct_detractors
    result$n               <- n_raw
    result$n_eff           <- n_eff
    result$promoter_codes  <- paste(promoter_codes, collapse = ",")
    result$detractor_codes <- paste(detractor_codes, collapse = ",")

    # -------------------------------------------------------------------------
    # 7. Confidence intervals according to config
    # -------------------------------------------------------------------------
    conf_level <- as.numeric(config$study_settings$Confidence_Level)

    # Normal approximation (using variance of difference formula)
    run_moe_flag <- q_row$Run_MOE
    if (!is.null(run_moe_flag) &&
        !is.na(run_moe_flag) &&
        toupper(run_moe_flag) == "Y") {
      if (!is.na(n_eff) && n_eff > 0) {
        # Convert percentages to proportions for variance calculation
        p_prom <- pct_promoters / 100
        p_detr <- pct_detractors / 100

        # Variance of difference (assuming independence)
        var_prom <- p_prom * (1 - p_prom) / n_eff
        var_detr <- p_detr * (1 - p_detr) / n_eff
        se_nps <- sqrt(var_prom + var_detr) * 100  # Convert back to percentage scale

        z <- qnorm(1 - (1 - conf_level) / 2)
        moe <- z * se_nps

        result$moe_normal <- list(
          lower = nps_score - moe,
          upper = nps_score + moe,
          se = se_nps
        )
      } else {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Effective n <= 0, MOE CI not calculated", q_id)
        )
      }
    }

    # Bootstrap CI
    run_boot_flag <- q_row$Run_Bootstrap
    if (!is.null(run_boot_flag) &&
        !is.na(run_boot_flag) &&
        toupper(run_boot_flag) == "Y") {
      boot_iter <- as.integer(config$study_settings$Bootstrap_Iterations)

      # Bootstrap NPS
      B <- boot_iter
      validate_sample_size(B, "B", min_n = 1000)

      n <- length(values_valid)
      boot_nps <- numeric(B)

      for (b in 1:B) {
        boot_idx <- sample(1:n, size = n, replace = TRUE)
        boot_values <- values_valid[boot_idx]

        if (!is.null(weights_valid)) {
          boot_weights <- weights_valid[boot_idx]
          total_w_boot <- sum(boot_weights)

          if (total_w_boot > 0) {
            is_prom_boot <- boot_values %in% promoter_codes
            is_detr_boot <- boot_values %in% detractor_codes

            pct_prom_boot <- 100 * sum(boot_weights[is_prom_boot]) / total_w_boot
            pct_detr_boot <- 100 * sum(boot_weights[is_detr_boot]) / total_w_boot

            boot_nps[b] <- pct_prom_boot - pct_detr_boot
          } else {
            boot_nps[b] <- NA
          }
        } else {
          is_prom_boot <- boot_values %in% promoter_codes
          is_detr_boot <- boot_values %in% detractor_codes

          pct_prom_boot <- 100 * mean(is_prom_boot)
          pct_detr_boot <- 100 * mean(is_detr_boot)

          boot_nps[b] <- pct_prom_boot - pct_detr_boot
        }
      }

      # Remove any NAs from bootstrap
      boot_nps <- boot_nps[!is.na(boot_nps)]

      if (length(boot_nps) > 0) {
        alpha <- 1 - conf_level
        result$bootstrap <- list(
          lower = quantile(boot_nps, alpha / 2, names = FALSE),
          upper = quantile(boot_nps, 1 - alpha / 2, names = FALSE)
        )
      } else {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Bootstrap failed (all NA)", q_id)
        )
      }
    }

    # Bayesian CI (using normal approximation for NPS)
    run_cred_flag <- q_row$Run_Credible
    if (!is.null(run_cred_flag) &&
        !is.na(run_cred_flag) &&
        toupper(run_cred_flag) == "Y") {
      prior_mean <- if (!is.na(q_row$Prior_Mean)) q_row$Prior_Mean else 0
      prior_sd   <- if (!is.na(q_row$Prior_SD))   q_row$Prior_SD   else 50  # Wide prior if not specified

      # Use normal approximation for NPS posterior
      # Likelihood: NPS ~ Normal(nps_score, se_nps^2)
      # Prior: NPS ~ Normal(prior_mean, prior_sd^2)

      p_prom <- pct_promoters / 100
      p_detr <- pct_detractors / 100
      var_prom <- p_prom * (1 - p_prom) / n_eff
      var_detr <- p_detr * (1 - p_detr) / n_eff
      se_nps <- sqrt(var_prom + var_detr) * 100

      # Posterior (normal-normal conjugate)
      precision_prior <- 1 / (prior_sd^2)
      precision_data  <- 1 / (se_nps^2)
      precision_post  <- precision_prior + precision_data

      mean_post <- (precision_prior * prior_mean + precision_data * nps_score) / precision_post
      sd_post   <- sqrt(1 / precision_post)

      # Credible interval
      alpha <- 1 - conf_level
      result$bayesian <- list(
        lower = qnorm(alpha / 2, mean = mean_post, sd = sd_post),
        upper = qnorm(1 - alpha / 2, mean = mean_post, sd = sd_post),
        posterior_mean = mean_post,
        posterior_sd = sd_post
      )
    }

  }, error = function(e) {
    warnings_list <- c(
      warnings_list,
      sprintf("Question %s: %s", q_id, conditionMessage(e))
    )
  })

  return(list(result = result, warnings = warnings_list))
}

# ==============================================================================
# MODULE METADATA
# ==============================================================================

if (exists("VERBOSE_LOAD") && VERBOSE_LOAD) {
  message(sprintf("  ✓ Processing module loaded (v%s)", PROCESSING_VERSION))
}
