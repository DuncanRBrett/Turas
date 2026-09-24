# ==============================================================================
# CI DISPATCHER - TURAS V10.1 (Phase 1 Refactoring)
# ==============================================================================
# Unified confidence interval calculation dispatch
# Extracted from 00_main.R to reduce duplication
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.1 - Refactoring release (2025-12-29)
#          - Extracted CI dispatch logic from process_*_question functions
#          - Unified handling of Run_MOE, Use_Wilson, Run_Bootstrap, Run_Credible flags
#          - Delegates to existing CI calculation functions
#
# DEPENDENCIES:
# - 04_proportions.R (proportion CI functions)
# - 05_means.R (mean CI functions)
# - utils.R (validation helpers)
# ==============================================================================

CI_DISPATCHER_VERSION <- "10.2"

# Safe extraction of optional numeric config fields
# Handles character, numeric, NA, NULL, and empty string inputs
safe_extract_numeric <- function(value) {
  if (is.null(value) || length(value) == 0) return(NULL)
  if (is.numeric(value) && !is.na(value)) return(value)
  if (is.na(value)) return(NULL)
  val_str <- as.character(value)
  if (!nzchar(trimws(val_str))) return(NULL)
  suppressWarnings(as.numeric(val_str))
}

# The Study_Settings random_seed, or NULL when blank or absent. The template
# promises it makes the bootstrap reproducible; until 2026-09-24 it was
# validated and never passed on, so every run gave different intervals. Each
# bootstrap reseeds with it, so a question's interval does not depend on which
# questions ran before it.
config_bootstrap_seed <- function(config) {
  seed <- safe_extract_numeric(config$study_settings$random_seed)
  if (is.null(seed) || is.na(seed)) return(NULL)
  as.integer(seed)
}

# ==============================================================================
# PROPORTION CI DISPATCH
# ==============================================================================

#' Dispatch proportion CI calculations based on config flags
#'
#' Calculates confidence intervals for a proportion based on the flags
#' specified in the question configuration row. Delegates to the
#' appropriate CI calculation functions from 04_proportions.R.
#'
#' @param p Numeric. Observed proportion (0 to 1)
#' @param n_eff Numeric. Effective sample size
#' @param values Vector. Original cleaned values (for bootstrap)
#' @param categories Vector. Categories for "success"
#' @param weights Numeric vector or NULL. Cleaned weights (for bootstrap)
#' @param q_row Data frame row. Question configuration row
#' @param config List. Full configuration object
#'
#' @return List with CI results for each enabled method:
#'   \describe{
#'     \item{moe}{MOE/normal approximation results (if Run_MOE = "Y")}
#'     \item{wilson}{Wilson score results (if Use_Wilson = "Y")}
#'     \item{bootstrap}{Bootstrap results (if Run_Bootstrap = "Y")}
#'     \item{bayesian}{Bayesian results (if Run_Credible = "Y")}
#'     \item{warnings}{Character vector of any warnings}
#'   }
#'
#' @keywords internal
dispatch_proportion_ci <- function(p, n_eff, values, categories, weights,
                                    q_row, config) {
  result <- list()
  warnings_list <- character()

  conf_level <- as.numeric(config$study_settings$Confidence_Level)
  q_id <- q_row$Question_ID

  # -------------------------------------------------------------------------
  # MOE (Normal Approximation)
  # -------------------------------------------------------------------------
  run_moe_flag <- q_row$Run_MOE
  if (!is.null(run_moe_flag) && !is.na(run_moe_flag) && toupper(run_moe_flag) == "Y") {
    if (!is.na(n_eff) && n_eff > 0) {
      result$moe <- calculate_proportion_ci_normal(p, n_eff, conf_level)
    } else {
      warnings_list <- c(warnings_list,
        sprintf("Question %s: Effective n <= 0, MOE CI not calculated", q_id))
    }
  }

  # -------------------------------------------------------------------------
  # Wilson Score Interval
  # -------------------------------------------------------------------------
  run_wilson_flag <- if ("Run_Wilson" %in% names(q_row)) q_row$Run_Wilson else NULL
  if (!is.null(run_wilson_flag) && !is.na(run_wilson_flag) && toupper(run_wilson_flag) == "Y") {
    if (!is.na(n_eff) && n_eff > 0) {
      result$wilson <- calculate_proportion_ci_wilson(p, n_eff, conf_level)
    } else {
      warnings_list <- c(warnings_list,
        sprintf("Question %s: Effective n <= 0, Wilson CI not calculated", q_id))
    }
  }

  # -------------------------------------------------------------------------
  # Bootstrap CI
  # -------------------------------------------------------------------------
  run_boot_flag <- q_row$Run_Bootstrap
  if (!is.null(run_boot_flag) && !is.na(run_boot_flag) && toupper(run_boot_flag) == "Y") {
    boot_iter <- as.integer(config$study_settings$Bootstrap_Iterations)
    tryCatch({
      result$bootstrap <- bootstrap_proportion_ci(
        data       = values,
        categories = categories,
        weights    = weights,
        B          = boot_iter,
        conf_level = conf_level,
        seed       = config_bootstrap_seed(config)
      )
    }, error = function(e) {
      warnings_list <<- c(warnings_list,
        sprintf("Question %s: Bootstrap CI failed - %s", q_id, conditionMessage(e)))
    })
  }

  # -------------------------------------------------------------------------
  # Bayesian Credible Interval (Beta-Binomial)
  # -------------------------------------------------------------------------
  run_cred_flag <- q_row$Run_Credible
  if (!is.null(run_cred_flag) && !is.na(run_cred_flag) && toupper(run_cred_flag) == "Y") {
    prior_mean <- safe_extract_numeric(q_row$Prior_Mean)
    prior_n    <- safe_extract_numeric(q_row$Prior_N)

    # Validate prior_mean is in valid range for proportion (0-1)
    if (!is.null(prior_mean) && (is.na(prior_mean) || prior_mean < 0 || prior_mean > 1)) {
      warnings_list <- c(warnings_list,
        sprintf("Question %s: Prior_Mean=%.2f invalid for proportion (must be 0-1), Bayesian CI skipped", q_id, prior_mean))
    } else {
      # Use effective n for weighted data
      n_bayes <- if (!is.null(weights)) n_eff else length(values)

      tryCatch({
        result$bayesian <- credible_interval_proportion(
          p          = p,
          n          = n_bayes,
          conf_level = conf_level,
          prior_mean = prior_mean,
          prior_n    = prior_n
        )
      }, error = function(e) {
        warnings_list <<- c(warnings_list,
          sprintf("Question %s: Bayesian CI failed - %s", q_id, conditionMessage(e)))
      })
    }
  }

  result$warnings <- warnings_list
  return(result)
}


# ==============================================================================
# MEAN CI DISPATCH
# ==============================================================================

#' Dispatch mean CI calculations based on config flags
#'
#' Calculates confidence intervals for a mean based on the flags
#' specified in the question configuration row. Delegates to the
#' appropriate CI calculation functions from 05_means.R.
#'
#' @param mean_val Numeric. Observed mean
#' @param sd_val Numeric. Standard deviation
#' @param n_eff Numeric. Effective sample size
#' @param values Numeric vector. Cleaned values
#' @param weights Numeric vector or NULL. Cleaned weights
#' @param q_row Data frame row. Question configuration row
#' @param config List. Full configuration object
#'
#' @return List with CI results for each enabled method:
#'   \describe{
#'     \item{t_dist}{t-distribution results (if Run_MOE = "Y")}
#'     \item{bootstrap}{Bootstrap results (if Run_Bootstrap = "Y")}
#'     \item{bayesian}{Bayesian results (if Run_Credible = "Y")}
#'     \item{warnings}{Character vector of any warnings}
#'   }
#'
#' @keywords internal
dispatch_mean_ci <- function(mean_val, sd_val, n_eff, values, weights,
                              q_row, config) {
  result <- list()
  warnings_list <- character()

  conf_level <- as.numeric(config$study_settings$Confidence_Level)
  q_id <- q_row$Question_ID

  # -------------------------------------------------------------------------
  # t-Distribution CI (via calculate_mean_ci)
  # -------------------------------------------------------------------------
  run_moe_flag <- q_row$Run_MOE
  if (!is.null(run_moe_flag) && !is.na(run_moe_flag) && toupper(run_moe_flag) == "Y") {
    result$t_dist <- calculate_mean_ci(
      values     = values,
      weights    = weights,
      conf_level = conf_level
    )
  }

  # -------------------------------------------------------------------------
  # Bootstrap CI
  # -------------------------------------------------------------------------
  run_boot_flag <- q_row$Run_Bootstrap
  if (!is.null(run_boot_flag) && !is.na(run_boot_flag) && toupper(run_boot_flag) == "Y") {
    boot_iter <- as.integer(config$study_settings$Bootstrap_Iterations)
    tryCatch({
      result$bootstrap <- bootstrap_mean_ci(
        values     = values,
        weights    = weights,
        B          = boot_iter,
        conf_level = conf_level,
        seed       = config_bootstrap_seed(config)
      )
    }, error = function(e) {
      warnings_list <<- c(warnings_list,
        sprintf("Question %s: Bootstrap mean CI failed - %s", q_id, conditionMessage(e)))
    })
  }

  # -------------------------------------------------------------------------
  # Bayesian Credible Interval (Normal-Normal)
  # -------------------------------------------------------------------------
  run_cred_flag <- q_row$Run_Credible
  if (!is.null(run_cred_flag) && !is.na(run_cred_flag) && toupper(run_cred_flag) == "Y") {
    prior_mean <- safe_extract_numeric(q_row$Prior_Mean)
    prior_sd   <- safe_extract_numeric(q_row$Prior_SD)
    prior_n    <- safe_extract_numeric(q_row$Prior_N)

    tryCatch({
      result$bayesian <- credible_interval_mean(
        values     = values,
        weights    = weights,
        conf_level = conf_level,
        prior_mean = prior_mean,
        prior_sd   = prior_sd,
        prior_n    = prior_n
      )
    }, error = function(e) {
      warnings_list <<- c(warnings_list,
        sprintf("Question %s: Bayesian mean CI failed - %s", q_id, conditionMessage(e)))
    })
  }

  result$warnings <- warnings_list
  return(result)
}


# ==============================================================================
# NPS CI DISPATCH
# ==============================================================================

#' Standard Error of an NPS Score (NPS points)
#'
#' NPS = 100 x (p_p - p_d), two shares of the SAME respondents, so their
#' covariance is -p_p p_d / n and
#'   Var(NPS / 100) = [p_p(1 - p_p) + p_d(1 - p_d) + 2 p_p p_d] / n
#'                  = [(p_p + p_d) - (p_p - p_d)^2] / n.
#' This is the formula docs/AUTHORITATIVE_GUIDE.md gives and the tracker uses.
#' The code used to drop the covariance ("assuming independence"), which made
#' every normal and Bayesian NPS interval too narrow: 18% at 50% promoters and
#' 20% detractors (review 2026-09-24).
#'
#' @param pct_promoters Numeric. Promoter share, 0-100
#' @param pct_detractors Numeric. Detractor share, 0-100
#' @param n_eff Numeric. Effective sample size (may be fractional)
#' @return Numeric. Standard error on the NPS scale (-100 to 100)
#' @keywords internal
nps_standard_error <- function(pct_promoters, pct_detractors, n_eff) {
  p_prom <- pct_promoters / 100
  p_detr <- pct_detractors / 100
  sqrt(((p_prom + p_detr) - (p_prom - p_detr)^2) / n_eff) * 100
}


#' Dispatch NPS CI calculations based on config flags
#'
#' Calculates confidence intervals for NPS score based on the flags
#' specified in the question configuration row.
#'
#' @param nps_stats List. NPS statistics from calculate_nps_stats()
#' @param values Numeric vector. Cleaned values
#' @param promoter_codes Numeric vector. Promoter codes
#' @param detractor_codes Numeric vector. Detractor codes
#' @param weights Numeric vector or NULL. Cleaned weights
#' @param q_row Data frame row. Question configuration row
#' @param config List. Full configuration object
#'
#' @return List with CI results for each enabled method:
#'   \describe{
#'     \item{moe_normal}{Normal approximation results (if Run_MOE = "Y")}
#'     \item{bootstrap}{Bootstrap results (if Run_Bootstrap = "Y")}
#'     \item{bayesian}{Bayesian results (if Run_Credible = "Y")}
#'     \item{warnings}{Character vector of any warnings}
#'   }
#'
#' @keywords internal
dispatch_nps_ci <- function(nps_stats, values, promoter_codes, detractor_codes,
                            weights, q_row, config) {
  result <- list()
  warnings_list <- character()

  conf_level <- as.numeric(config$study_settings$Confidence_Level)
  q_id <- q_row$Question_ID
  # The exact effective n sizes the interval; n_eff is the rounded display copy
  n_eff <- if (!is.null(nps_stats$n_eff_exact)) nps_stats$n_eff_exact else nps_stats$n_eff
  nps_score <- nps_stats$nps_score
  pct_promoters <- nps_stats$pct_promoters
  pct_detractors <- nps_stats$pct_detractors

  # -------------------------------------------------------------------------
  # Normal Approximation (variance of difference formula)
  # -------------------------------------------------------------------------
  run_moe_flag <- q_row$Run_MOE
  if (!is.null(run_moe_flag) && !is.na(run_moe_flag) && toupper(run_moe_flag) == "Y") {
    if (!is.na(n_eff) && n_eff > 0) {
      se_nps <- nps_standard_error(pct_promoters, pct_detractors, n_eff)

      z <- qnorm(1 - (1 - conf_level) / 2)
      moe <- z * se_nps

      result$moe_normal <- list(
        lower = nps_score - moe,
        upper = nps_score + moe,
        se = se_nps
      )
    } else {
      warnings_list <- c(warnings_list,
        sprintf("Question %s: Effective n <= 0, MOE CI not calculated", q_id))
    }
  }

  # -------------------------------------------------------------------------
  # Bootstrap CI
  # -------------------------------------------------------------------------
  run_boot_flag <- q_row$Run_Bootstrap
  if (!is.null(run_boot_flag) && !is.na(run_boot_flag) && toupper(run_boot_flag) == "Y") {
    boot_iter <- as.integer(config$study_settings$Bootstrap_Iterations)
    validate_sample_size(boot_iter, "B", min_n = 1000)

    n <- length(values)
    boot_nps <- numeric(boot_iter)
    boot_seed <- config_bootstrap_seed(config)
    if (!is.null(boot_seed)) set.seed(boot_seed)

    for (b in 1:boot_iter) {
      boot_idx <- sample(1:n, size = n, replace = TRUE)
      boot_values <- values[boot_idx]

      if (!is.null(weights)) {
        boot_weights <- weights[boot_idx]
        total_w_boot <- sum(boot_weights)

        if (isTRUE(total_w_boot > 0)) {
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
      warnings_list <- c(warnings_list,
        sprintf("Question %s: Bootstrap failed (all NA)", q_id))
    }
  }

  # -------------------------------------------------------------------------
  # Bayesian Credible Interval (using normal approximation for NPS)
  # -------------------------------------------------------------------------
  run_cred_flag <- q_row$Run_Credible
  if (!is.null(run_cred_flag) && !is.na(run_cred_flag) && toupper(run_cred_flag) == "Y") {
    prior_mean <- safe_extract_numeric(q_row$Prior_Mean)
    if (is.null(prior_mean)) prior_mean <- 0
    prior_sd   <- safe_extract_numeric(q_row$Prior_SD)
    if (is.null(prior_sd)) prior_sd <- 50  # Wide prior

    se_nps <- nps_standard_error(pct_promoters, pct_detractors, n_eff)

    if (isTRUE(se_nps == 0)) {
      # Every respondent in one group: the data precision 1/SE^2 is infinite,
      # the update below returned NaN (review 2026-09-24), and the posterior
      # is a point mass on the observed score.
      mean_post <- nps_score
      sd_post   <- 0
    } else {
      # Posterior (normal-normal conjugate)
      precision_prior <- 1 / (prior_sd^2)
      precision_data  <- 1 / (se_nps^2)
      precision_post  <- precision_prior + precision_data

      mean_post <- (precision_prior * prior_mean + precision_data * nps_score) / precision_post
      sd_post   <- sqrt(1 / precision_post)
    }

    # Credible interval
    alpha <- 1 - conf_level
    result$bayesian <- list(
      lower = qnorm(alpha / 2, mean = mean_post, sd = sd_post),
      upper = qnorm(1 - alpha / 2, mean = mean_post, sd = sd_post),
      # post_mean / post_sd: the names the proportion and mean calculators
      # use and the writers read. `posterior_mean` never reached NPS_Detail
      # (review 2026-09-24).
      post_mean = mean_post,
      post_sd = sd_post
    )
  }

  # A zero standard error (every respondent a promoter, a detractor or a
  # passive) gives zero-width normal and Bayesian intervals. Say so.
  if (!is.na(n_eff) && n_eff > 0 &&
      isTRUE(nps_standard_error(pct_promoters, pct_detractors, n_eff) == 0) &&
      (!is.null(result$moe_normal) || !is.null(result$bayesian))) {
    warnings_list <- c(warnings_list, sprintf(
      "Question %s: NPS standard error is zero (every respondent falls in one group), so the normal and Bayesian intervals have zero width",
      q_id))
  }

  result$warnings <- warnings_list
  return(result)
}
