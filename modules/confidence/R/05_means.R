# ==============================================================================
# MEAN CONFIDENCE INTERVALS - TURAS V10.0
# ==============================================================================
# Functions for calculating confidence intervals for means
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-11-12)
#          - Standard t-distribution confidence intervals
#          - Bootstrap confidence intervals
#          - Bayesian credible intervals (Normal-Normal conjugate)
#
# STATISTICAL METHODOLOGY:
# - t-distribution: mean ± t * (SD / sqrt(n))
# - Bootstrap: Percentile method with resampling
# - Bayesian: Normal-Normal conjugate prior
#
# REFERENCES:
# - Standard statistical textbooks for t-distribution
# - Efron & Tibshirani (1994) for bootstrap
# - Gelman et al. (2013) for Bayesian methods
#
# DEPENDENCIES:
# - utils.R
# - 03_study_level.R (for effective n with weights)
# ==============================================================================

MEANS_VERSION <- "10.0"

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

source_if_exists <- function(file_path) {
  if (file.exists(file_path)) {
    source(file_path)
  } else if (file.exists(file.path("R", file_path))) {
    source(file.path("R", file_path))
  } else if (file.exists(file.path("..", "R", file_path))) {
    source(file.path("..", "R", file_path))
  }
}

source_if_exists("utils.R")
source_if_exists("03_study_level.R")

# ==============================================================================
# STANDARD CONFIDENCE INTERVAL (t-distribution)
# ==============================================================================

#' Calculate confidence interval for mean using t-distribution
#'
#' Calculates confidence interval for a mean using Student's t-distribution.
#' Standard method for continuous data. Uses effective sample size for
#' weighted data.
#'
#' FORMULA:
#'   SE = SD / sqrt(n)
#'   t_crit = qt(1 - alpha/2, df = n-1)
#'   CI = mean ± t_crit * SE
#'
#' ASSUMPTIONS:
#' - Data approximately normally distributed (or large n by CLT)
#' - For small samples (n < 30), normality more important
#' - For weighted data, uses effective n for degrees of freedom
#'
#' @param values Numeric vector. Data values
#' @param weights Numeric vector. Survey weights (NULL for unweighted)
#' @param conf_level Numeric. Confidence level (default 0.95)
#'
#' @return List with elements:
#'   \describe{
#'     \item{mean}{Sample mean (weighted if weights provided)}
#'     \item{sd}{Standard deviation}
#'     \item{se}{Standard error}
#'     \item{lower}{Lower confidence limit}
#'     \item{upper}{Upper confidence limit}
#'     \item{df}{Degrees of freedom}
#'     \item{t_crit}{Critical t-value}
#'     \item{n_actual}{Actual sample size}
#'     \item{n_effective}{Effective sample size (for weighted data)}
#'     \item{method}{"t-distribution"}
#'   }
#'
#' @examples
#' # Unweighted satisfaction ratings (0-10 scale)
#' ratings <- c(8, 7, 9, 6, 8, 7, 9, 8, 7, 10)
#' result <- calculate_mean_ci(ratings)
#'
#' # Weighted data
#' result <- calculate_mean_ci(ratings, weights = weights_vector)
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
calculate_mean_ci <- function(values, weights = NULL, conf_level = 0.95) {
  # Input validation
  if (!is.numeric(values)) {
    stop("values must be numeric", call. = FALSE)
  }

  # Remove NA values
  if (any(is.na(values))) {
    if (is.null(weights)) {
      valid_idx <- !is.na(values)
      values <- values[valid_idx]
      warning(sprintf("Removed %d NA values", sum(!valid_idx)), call. = FALSE)
    } else {
      valid_idx <- !is.na(values) & !is.na(weights)
      values <- values[valid_idx]
      weights <- weights[valid_idx]
      warning(sprintf("Removed %d NA values", sum(!valid_idx)), call. = FALSE)
    }
  }

  validate_conf_level(conf_level)

  n_actual <- length(values)
  if (n_actual < 2) {
    stop("Need at least 2 values to calculate confidence interval", call. = FALSE)
  }

  # Determine if weighted
  is_weighted <- !is.null(weights) && length(weights) > 0

  # Calculate mean and SD
  if (is_weighted) {
    if (length(weights) != n_actual) {
      stop("weights must have same length as values", call. = FALSE)
    }

    # Weighted mean
    mean_val <- sum(values * weights) / sum(weights)

    # Weighted SD (population estimator - consistent with effective n approach)
    weighted_var <- sum(weights * (values - mean_val)^2) / sum(weights)
    sd_val <- sqrt(weighted_var)

    # Effective sample size for degrees of freedom
    n_eff <- calculate_effective_n(weights)
  } else {
    mean_val <- mean(values)
    sd_val <- sd(values)
    n_eff <- n_actual
  }

  # Standard error
  se <- sd_val / sqrt(n_eff)

  # Degrees of freedom
  df <- n_eff - 1

  # Critical t-value
  alpha <- 1 - conf_level
  t_crit <- qt(1 - alpha/2, df = df)

  # Confidence interval
  lower <- mean_val - t_crit * se
  upper <- mean_val + t_crit * se

  # Warnings
  warnings <- character()
  if (n_actual < 30) {
    warnings <- c(warnings, check_small_sample(n_actual))
  }

  return(list(
    mean = mean_val,
    sd = sd_val,
    se = se,
    lower = lower,
    upper = upper,
    df = df,
    t_crit = t_crit,
    n_actual = n_actual,
    n_effective = n_eff,
    is_weighted = is_weighted,
    method = sprintf("t-distribution (df=%d)", df),
    warnings = warnings
  ))
}


# ==============================================================================
# BOOTSTRAP CONFIDENCE INTERVAL FOR MEANS
# ==============================================================================

#' Calculate bootstrap confidence interval for mean
#'
#' Calculates confidence interval using bootstrap resampling. Works with
#' weighted and unweighted data. Uses percentile method.
#'
#' BOOTSTRAP PROCEDURE:
#' 1. Resample data with replacement (B times)
#' 2. Calculate mean for each resample (weighted if applicable)
#' 3. Use quantiles of bootstrap distribution as CI
#'
#' ADVANTAGES:
#' - Makes no distributional assumptions
#' - Handles weighted data naturally
#' - Can capture asymmetry in sampling distribution
#' - Works well for skewed data
#'
#' PARALLEL PROCESSING:
#' When parallel = TRUE and B >= 5000, bootstrap iterations are computed
#' in parallel using the future/future.apply framework. This can significantly
#' speed up calculations for large B values (e.g., 10,000 iterations).
#'
#' Requirements for parallel processing:
#' - future and future.apply packages installed
#' - B >= 5000 iterations (overhead not worth it for fewer)
#'
#' @param values Numeric vector. Data values
#' @param weights Numeric vector. Survey weights (NULL for unweighted)
#' @param B Integer. Number of bootstrap iterations (default 5000)
#' @param conf_level Numeric. Confidence level (default 0.95)
#' @param seed Integer. Random seed for reproducibility (optional)
#' @param parallel Logical. If TRUE, use parallel processing. Default FALSE.
#'
#' @return List with elements:
#'   \describe{
#'     \item{lower}{Lower confidence limit}
#'     \item{upper}{Upper confidence limit}
#'     \item{boot_se}{Bootstrap standard error}
#'     \item{boot_mean}{Bootstrap mean (should be close to observed mean)}
#'     \item{boot_samples}{Vector of all bootstrap means (for diagnostics)}
#'     \item{method}{"Bootstrap (percentile)" or "Bootstrap (percentile, parallel)"}
#'   }
#'
#' @examples
#' # Unweighted
#' ratings <- rnorm(1000, mean = 7.5, sd = 1.8)
#' result <- bootstrap_mean_ci(ratings, B = 5000)
#'
#' # Weighted with parallel processing
#' result <- bootstrap_mean_ci(ratings, weights = weights_vector, B = 10000,
#'                              parallel = TRUE)
#'
#' @references
#' Efron, B., & Tibshirani, R. J. (1994). An introduction to the bootstrap.
#' CRC press.
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
bootstrap_mean_ci <- function(values, weights = NULL, B = 5000,
                              conf_level = 0.95, seed = NULL,
                              parallel = FALSE) {
  # Input validation
  if (!is.numeric(values)) {
    stop("values must be numeric", call. = FALSE)
  }

  # Remove NA values
  if (any(is.na(values))) {
    if (is.null(weights)) {
      valid_idx <- !is.na(values)
      values <- values[valid_idx]
    } else {
      valid_idx <- !is.na(values) & !is.na(weights)
      values <- values[valid_idx]
      weights <- weights[valid_idx]
    }
  }

  n <- length(values)
  if (n < 2) {
    stop("Need at least 2 values for bootstrap", call. = FALSE)
  }

  validate_sample_size(B, "B", min_n = 1000)
  validate_conf_level(conf_level)

  # Set seed if specified
  if (!is.null(seed)) {
    set.seed(seed)
  }

  is_weighted <- !is.null(weights) && length(weights) > 0

  if (is_weighted && length(weights) != n) {
    stop("weights must have same length as values", call. = FALSE)
  }

  # ---------------------------------------------------------------------------
  # PARALLEL BOOTSTRAP (for high B values)
  # ---------------------------------------------------------------------------
  use_parallel <- FALSE
  if (parallel && B >= 5000) {
    if (requireNamespace("future", quietly = TRUE) &&
        requireNamespace("future.apply", quietly = TRUE)) {
      use_parallel <- TRUE
    }
  }

  if (use_parallel) {
    # Set up parallel plan if not already configured
    current_plan <- future::plan()
    if (!inherits(current_plan, c("multisession", "multicore", "cluster"))) {
      n_workers <- min(4, parallel::detectCores() - 1)
      old_plan <- future::plan(future::multisession, workers = n_workers)
      on.exit(future::plan(old_plan), add = TRUE)
    }

    # Split B into chunks for parallel processing
    n_workers <- future::nbrOfWorkers()
    chunk_size <- ceiling(B / n_workers)
    chunks <- split(1:B, ceiling(seq_along(1:B) / chunk_size))

    # Define bootstrap function for a chunk
    boot_chunk <- function(indices, values, weights, is_weighted, n, seed_base) {
      if (!is.null(seed_base)) set.seed(seed_base + indices[1])
      results <- numeric(length(indices))
      for (j in seq_along(indices)) {
        boot_indices <- sample(1:n, size = n, replace = TRUE)
        boot_values <- values[boot_indices]
        if (is_weighted) {
          boot_weights <- weights[boot_indices]
          results[j] <- sum(boot_values * boot_weights) / sum(boot_weights)
        } else {
          results[j] <- mean(boot_values)
        }
      }
      results
    }

    # Run parallel bootstrap
    boot_results <- future.apply::future_lapply(
      chunks, boot_chunk,
      values = values, weights = weights,
      is_weighted = is_weighted, n = n, seed_base = seed,
      future.seed = TRUE
    )
    boot_means <- unlist(boot_results)
    method <- "Bootstrap (percentile, parallel)"

  } else {
    # ---------------------------------------------------------------------------
    # SEQUENTIAL BOOTSTRAP (default)
    # ---------------------------------------------------------------------------
    boot_means <- numeric(B)

    for (i in 1:B) {
      boot_indices <- sample(1:n, size = n, replace = TRUE)
      boot_values <- values[boot_indices]

      if (is_weighted) {
        boot_weights <- weights[boot_indices]
        boot_means[i] <- sum(boot_values * boot_weights) / sum(boot_weights)
      } else {
        boot_means[i] <- mean(boot_values)
      }
    }
    method <- "Bootstrap (percentile)"
  }

  # Calculate percentile confidence interval
  alpha <- 1 - conf_level
  lower <- quantile(boot_means, alpha/2, names = FALSE)
  upper <- quantile(boot_means, 1 - alpha/2, names = FALSE)

  # Bootstrap statistics
  boot_se <- sd(boot_means)
  boot_mean <- mean(boot_means)

  return(list(
    lower = lower,
    upper = upper,
    boot_se = boot_se,
    boot_mean = boot_mean,
    boot_samples = boot_means,
    method = method,
    B = B,
    warnings = character()
  ))
}


# ==============================================================================
# BAYESIAN CREDIBLE INTERVAL FOR MEANS
# ==============================================================================

#' Calculate Bayesian credible interval for mean
#'
#' Calculates Bayesian credible interval using Normal-Normal conjugate prior.
#' Can use uninformed prior or informed prior from previous data.
#'
#' BAYESIAN APPROACH:
#' - Prior: Normal(μ₀, σ₀²) distribution for mean
#' - Likelihood: Normal(μ, σ²) data
#' - Posterior: Normal distribution (conjugate update)
#' - Credible interval: quantiles of posterior distribution
#'
#' UNINFORMED PRIOR:
#' - Large variance (non-informative)
#' - Posterior dominated by data
#'
#' INFORMED PRIOR:
#' - Normal(prior_mean, prior_sd²) with prior_n observations
#' - Useful for tracking studies (use previous wave as prior)
#' - Posterior is weighted average of prior and data
#'
#' @param values Numeric vector. Data values
#' @param weights Numeric vector. Survey weights (NULL for unweighted)
#' @param conf_level Numeric. Credibility level (default 0.95)
#' @param prior_mean Numeric. Prior mean (NULL for uninformed prior)
#' @param prior_sd Numeric. Prior standard deviation (required if prior_mean specified)
#' @param prior_n Integer. Prior "sample size" - strength of prior belief
#'
#' @return List with elements:
#'   \describe{
#'     \item{lower}{Lower credible limit}
#'     \item{upper}{Upper credible limit}
#'     \item{post_mean}{Posterior mean}
#'     \item{post_sd}{Posterior standard deviation}
#'     \item{prior_type}{"Uninformed" or "Informed"}
#'     \item{method}{"Bayesian (Normal-Normal)"}
#'   }
#'
#' @examples
#' # Uninformed prior
#' ratings <- rnorm(1000, mean = 7.5, sd = 1.8)
#' result <- credible_interval_mean(ratings)
#'
#' # Informed prior from previous wave (mean=7.2, SD=1.9, n=500)
#' result <- credible_interval_mean(ratings,
#'                                  prior_mean = 7.2,
#'                                  prior_sd = 1.9,
#'                                  prior_n = 500)
#'
#' @references
#' Gelman, A., et al. (2013). Bayesian data analysis (3rd ed.).
#' Chapman and Hall/CRC.
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
credible_interval_mean <- function(values, weights = NULL, conf_level = 0.95,
                                   prior_mean = NULL, prior_sd = NULL,
                                   prior_n = NULL) {
  # Input validation
  if (!is.numeric(values)) {
    stop("values must be numeric", call. = FALSE)
  }

  # Remove NA values
  if (any(is.na(values))) {
    if (is.null(weights)) {
      valid_idx <- !is.na(values)
      values <- values[valid_idx]
    } else {
      valid_idx <- !is.na(values) & !is.na(weights)
      values <- values[valid_idx]
      weights <- weights[valid_idx]
    }
  }

  n_actual <- length(values)
  if (n_actual < 2) {
    stop("Need at least 2 values to calculate credible interval", call. = FALSE)
  }

  validate_conf_level(conf_level)

  # Calculate sample statistics
  is_weighted <- !is.null(weights) && length(weights) > 0

  if (is_weighted) {
    mean_data <- sum(values * weights) / sum(weights)
    weighted_var <- sum(weights * (values - mean_data)^2) / sum(weights)
    sd_data <- sqrt(weighted_var)
    n_eff <- calculate_effective_n(weights)
  } else {
    mean_data <- mean(values)
    sd_data <- sd(values)
    n_eff <- n_actual
  }

  # Data precision
  tau_data <- n_eff / (sd_data^2)

  # Determine prior type
  use_uninformed <- is.null(prior_mean)

  if (use_uninformed) {
    # Uninformed prior: posterior dominated by data
    post_mean <- mean_data
    post_var <- sd_data^2 / n_eff
    post_sd <- sqrt(post_var)
    prior_type <- "Uninformed"
  } else {
    # Informed prior
    if (is.null(prior_sd)) {
      stop("prior_sd is required when prior_mean is specified", call. = FALSE)
    }

    if (!is.numeric(prior_mean) || !is.numeric(prior_sd)) {
      stop("prior_mean and prior_sd must be numeric", call. = FALSE)
    }

    if (prior_sd <= 0) {
      stop("prior_sd must be positive", call. = FALSE)
    }

    # Default prior_n to 100 if not specified
    if (is.null(prior_n)) {
      prior_n <- 100
      warning("prior_n not specified, using default: 100", call. = FALSE)
    } else {
      validate_sample_size(prior_n, "prior_n")
    }

    # Prior precision
    tau_prior <- prior_n / (prior_sd^2)

    # Posterior precision (sum of precisions)
    tau_post <- tau_prior + tau_data

    # Posterior mean (precision-weighted average)
    post_mean <- (tau_prior * prior_mean + tau_data * mean_data) / tau_post

    # Posterior variance
    post_var <- 1 / tau_post
    post_sd <- sqrt(post_var)

    prior_type <- "Informed"
  }

  # Credible interval (using normal approximation)
  alpha <- 1 - conf_level
  z <- qnorm(1 - alpha/2)
  lower <- post_mean - z * post_sd
  upper <- post_mean + z * post_sd

  return(list(
    lower = lower,
    upper = upper,
    post_mean = post_mean,
    post_sd = post_sd,
    prior_type = prior_type,
    prior_mean = prior_mean,
    prior_sd = prior_sd,
    prior_n = prior_n,
    data_mean = mean_data,
    data_sd = sd_data,
    method = "Bayesian (Normal-Normal)",
    warnings = character()
  ))
}


# ==============================================================================
# UNIFIED MEAN ANALYSIS FUNCTION
# ==============================================================================

#' Calculate all confidence methods for a mean
#'
#' Convenience function that calculates all requested confidence methods
#' for a mean. Handles data preparation and method dispatch.
#'
#' @param values Numeric vector. Data values
#' @param weights Numeric vector. Survey weights (NULL for unweighted)
#' @param conf_level Numeric. Confidence level (default 0.95)
#' @param methods Character vector. Which methods to run:
#'   c("standard", "bootstrap", "bayesian")
#' @param bootstrap_iterations Integer. Number of bootstrap iterations
#' @param prior_mean Numeric. Prior mean for Bayesian
#' @param prior_sd Numeric. Prior SD for Bayesian
#' @param prior_n Integer. Prior sample size for Bayesian
#' @param seed Integer. Random seed for bootstrap
#'
#' @return List with results from each requested method
#'
#' @examples
#' ratings <- rnorm(1000, mean = 7.5, sd = 1.8)
#' results <- analyze_mean(
#'   ratings,
#'   methods = c("standard", "bootstrap", "bayesian"),
#'   bootstrap_iterations = 5000,
#'   prior_mean = 7.2,
#'   prior_sd = 1.9,
#'   prior_n = 500
#' )
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
analyze_mean <- function(values, weights = NULL, conf_level = 0.95,
                        methods = c("standard", "bootstrap", "bayesian"),
                        bootstrap_iterations = 5000,
                        prior_mean = NULL, prior_sd = NULL, prior_n = NULL,
                        seed = NULL) {
  # Remove NA values upfront
  if (any(is.na(values))) {
    if (is.null(weights)) {
      valid_idx <- !is.na(values)
      values <- values[valid_idx]
    } else {
      valid_idx <- !is.na(values) & !is.na(weights)
      values <- values[valid_idx]
      weights <- weights[valid_idx]
    }
  }

  is_weighted <- !is.null(weights) && length(weights) > 0

  # Calculate basic statistics
  if (is_weighted) {
    mean_val <- sum(values * weights) / sum(weights)
    weighted_var <- sum(weights * (values - mean_val)^2) / sum(weights)
    sd_val <- sqrt(weighted_var)
    n_actual <- length(values)
    n_eff <- calculate_effective_n(weights)
  } else {
    mean_val <- mean(values)
    sd_val <- sd(values)
    n_actual <- length(values)
    n_eff <- n_actual
  }

  # Initialize results
  results <- list(
    mean = mean_val,
    sd = sd_val,
    n_actual = n_actual,
    n_effective = n_eff,
    is_weighted = is_weighted
  )

  # Calculate standard CI
  if ("standard" %in% methods) {
    results$standard <- calculate_mean_ci(values, weights, conf_level)
  }

  # Calculate bootstrap CI
  if ("bootstrap" %in% methods) {
    results$bootstrap <- bootstrap_mean_ci(
      values, weights,
      B = bootstrap_iterations,
      conf_level = conf_level,
      seed = seed
    )
  }

  # Calculate Bayesian CI
  if ("bayesian" %in% methods) {
    results$bayesian <- credible_interval_mean(
      values, weights, conf_level,
      prior_mean = prior_mean,
      prior_sd = prior_sd,
      prior_n = prior_n
    )
  }

  return(results)
}
