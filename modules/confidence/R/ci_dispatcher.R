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

CI_DISPATCHER_VERSION <- "10.1"

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
  use_wilson_flag <- if ("Use_Wilson" %in% names(q_row)) q_row$Use_Wilson else NULL
  if (!is.null(use_wilson_flag) && !is.na(use_wilson_flag) && toupper(use_wilson_flag) == "Y") {
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
    result$bootstrap <- bootstrap_proportion_ci(
      data       = values,
      categories = categories,
      weights    = weights,
      B          = boot_iter,
      conf_level = conf_level
    )
  }

  # -------------------------------------------------------------------------
  # Bayesian Credible Interval (Beta-Binomial)
  # -------------------------------------------------------------------------
  run_cred_flag <- q_row$Run_Credible
  if (!is.null(run_cred_flag) && !is.na(run_cred_flag) && toupper(run_cred_flag) == "Y") {
    prior_mean <- if (!is.null(q_row$Prior_Mean) && !is.na(q_row$Prior_Mean)) q_row$Prior_Mean else NULL
    prior_n    <- if (!is.null(q_row$Prior_N) && !is.na(q_row$Prior_N)) q_row$Prior_N else NULL

    # Use effective n for weighted data
    n_bayes <- if (!is.null(weights)) n_eff else length(values)

    result$bayesian <- credible_interval_proportion(
      p          = p,
      n          = n_bayes,
      conf_level = conf_level,
      prior_mean = prior_mean,
      prior_n    = prior_n
    )
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
    result$bootstrap <- bootstrap_mean_ci(
      values     = values,
      weights    = weights,
      B          = boot_iter,
      conf_level = conf_level
    )
  }

  # -------------------------------------------------------------------------
  # Bayesian Credible Interval (Normal-Normal)
  # -------------------------------------------------------------------------
  run_cred_flag <- q_row$Run_Credible
  if (!is.null(run_cred_flag) && !is.na(run_cred_flag) && toupper(run_cred_flag) == "Y") {
    prior_mean <- if (!is.null(q_row$Prior_Mean) && !is.na(q_row$Prior_Mean)) q_row$Prior_Mean else NULL
    prior_sd   <- if (!is.null(q_row$Prior_SD) && !is.na(q_row$Prior_SD)) q_row$Prior_SD else NULL
    prior_n    <- if (!is.null(q_row$Prior_N) && !is.na(q_row$Prior_N)) q_row$Prior_N else NULL

    result$bayesian <- credible_interval_mean(
      values     = values,
      weights    = weights,
      conf_level = conf_level,
      prior_mean = prior_mean,
      prior_sd   = prior_sd,
      prior_n    = prior_n
    )
  }

  result$warnings <- warnings_list
  return(result)
}


# ==============================================================================
# NPS CI DISPATCH
# ==============================================================================

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
  n_eff <- nps_stats$n_eff
  nps_score <- nps_stats$nps_score
  pct_promoters <- nps_stats$pct_promoters
  pct_detractors <- nps_stats$pct_detractors

  # -------------------------------------------------------------------------
  # Normal Approximation (variance of difference formula)
  # -------------------------------------------------------------------------
  run_moe_flag <- q_row$Run_MOE
  if (!is.null(run_moe_flag) && !is.na(run_moe_flag) && toupper(run_moe_flag) == "Y") {
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
    prior_mean <- if (!is.null(q_row$Prior_Mean) && !is.na(q_row$Prior_Mean)) q_row$Prior_Mean else 0
    prior_sd   <- if (!is.null(q_row$Prior_SD) && !is.na(q_row$Prior_SD)) q_row$Prior_SD else 50  # Wide prior

    # Calculate SE for NPS
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

  result$warnings <- warnings_list
  return(result)
}
