# ==============================================================================
# PROPORTION CONFIDENCE INTERVALS - TURAS V10.0
# ==============================================================================
# Functions for calculating confidence intervals for proportions
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-11-12)
#          - Margin of Error (normal approximation)
#          - Wilson score interval
#          - Bootstrap confidence intervals
#          - Bayesian credible intervals (Beta-Binomial)
#
# STATISTICAL METHODOLOGY:
# - Normal approximation: p ± z * sqrt(p(1-p)/n)
# - Wilson score: Agresti & Coull (1998) - better for small n, extreme p
# - Bootstrap: Percentile method with resampling
# - Bayesian: Beta-Binomial conjugate prior
#
# REFERENCES:
# - Agresti, A., & Coull, B. A. (1998). Approximate is better than "exact"
# - Wilson, E. B. (1927). Probable inference and statistical inference
# - Efron, B., & Tibshirani, R. J. (1994). An introduction to the bootstrap
#
# DEPENDENCIES:
# - utils.R
# - 03_study_level.R (for effective n with weights)
# ==============================================================================

PROPORTIONS_VERSION <- "10.0"

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
# MARGIN OF ERROR - NORMAL APPROXIMATION
# ==============================================================================

#' Calculate margin of error for proportion (normal approximation)
#'
#' Calculates confidence interval for proportion using normal approximation
#' to the binomial distribution. Standard method, but can be inaccurate for
#' small samples or extreme proportions (p near 0 or 1).
#'
#' FORMULA:
#'   SE = sqrt(p * (1-p) / n)
#'   MOE = z * SE
#'   CI = [p - MOE, p + MOE]
#'
#' WHEN TO USE:
#' - Large samples (n >= 30)
#' - Proportions away from extremes (0.1 < p < 0.9)
#' - For extreme proportions or small n, use Wilson score
#'
#' @param p Numeric. Observed proportion (0 to 1)
#' @param n Integer. Sample size (unweighted or effective n if weighted)
#' @param conf_level Numeric. Confidence level (default 0.95 for 95% CI)
#'
#' @return List with elements:
#'   \describe{
#'     \item{lower}{Lower confidence limit}
#'     \item{upper}{Upper confidence limit}
#'     \item{moe}{Margin of error}
#'     \item{se}{Standard error}
#'     \item{method}{"Normal approximation"}
#'   }
#'
#' @examples
#' # 45% awareness in sample of 1000
#' result <- calculate_proportion_ci_normal(p = 0.45, n = 1000, conf_level = 0.95)
#' # Returns: lower=0.42, upper=0.48, moe=0.03
#'
#' @references
#' Standard confidence interval for proportions
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
calculate_proportion_ci_normal <- function(p, n, conf_level = 0.95) {
  # Input validation
  validate_proportion(p, "p")
  validate_sample_size(n, "n")
  validate_conf_level(conf_level)

  # Calculate critical value (z-score)
  alpha <- 1 - conf_level
  z <- qnorm(1 - alpha/2)

  # Calculate standard error
  se <- sqrt(p * (1 - p) / n)

  # Calculate margin of error
  moe <- z * se

  # Calculate confidence limits (bounded by 0 and 1)
  lower <- max(0, p - moe)
  upper <- min(1, p + moe)

  # Issue warnings for problematic cases
  warnings <- character()

  if (n < 30) {
    warnings <- c(warnings, check_small_sample(n))
  }

  if (p < 0.10 || p > 0.90) {
    warnings <- c(warnings, check_extreme_proportion(p))
  }

  return(list(
    lower = lower,
    upper = upper,
    moe = moe,
    se = se,
    method = "Normal approximation",
    warnings = warnings
  ))
}


# ==============================================================================
# WILSON SCORE INTERVAL
# ==============================================================================

#' Calculate Wilson score confidence interval for proportion
#'
#' Calculates confidence interval using Wilson score method. More accurate
#' than normal approximation, especially for small samples or extreme
#' proportions. Recommended as default method.
#'
#' ADVANTAGES:
#' - Works well for small samples (n < 50)
#' - Handles extreme proportions (p near 0 or 1)
#' - Never produces intervals outside [0,1]
#' - Generally more accurate coverage than normal approximation
#'
#' FORMULA:
#'   center = (p + z²/(2n)) / (1 + z²/n)
#'   margin = z * sqrt(p(1-p)/n + z²/(4n²)) / (1 + z²/n)
#'   CI = [center - margin, center + margin]
#'
#' @param p Numeric. Observed proportion (0 to 1)
#' @param n Integer. Sample size (unweighted or effective n if weighted)
#' @param conf_level Numeric. Confidence level (default 0.95)
#'
#' @return List with elements:
#'   \describe{
#'     \item{lower}{Lower confidence limit}
#'     \item{upper}{Upper confidence limit}
#'     \item{center}{Wilson center point (slightly shifted from p)}
#'     \item{method}{"Wilson score"}
#'   }
#'
#' @examples
#' # 5% incidence in sample of 200 (extreme proportion)
#' result <- calculate_proportion_ci_wilson(p = 0.05, n = 200)
#' # Returns more accurate interval than normal approximation
#'
#' @references
#' Wilson, E. B. (1927). Probable inference, the law of succession,
#' and statistical inference. JASA, 22(158), 209-212.
#'
#' Agresti, A., & Coull, B. A. (1998). Approximate is better than "exact"
#' for interval estimation of binomial proportions. The American Statistician,
#' 52(2), 119-126.
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
calculate_proportion_ci_wilson <- function(p, n, conf_level = 0.95) {
  # Input validation
  validate_proportion(p, "p")
  validate_sample_size(n, "n")
  validate_conf_level(conf_level)

  # Calculate critical value
  alpha <- 1 - conf_level
  z <- qnorm(1 - alpha/2)

  # Wilson score formula components
  z_squared <- z^2
  denominator <- 1 + z_squared / n

  # Center point (adjusted from p)
  center <- (p + z_squared / (2 * n)) / denominator

  # Margin
  margin <- z * sqrt((p * (1 - p) + z_squared / (4 * n)) / n) / denominator

  # Confidence limits
  lower <- center - margin
  upper <- center + margin

  # Ensure bounds (should be within [0,1] by construction, but be safe)
  lower <- max(0, lower)
  upper <- min(1, upper)

  return(list(
    lower = lower,
    upper = upper,
    center = center,
    method = "Wilson score",
    warnings = character()
  ))
}


# ==============================================================================
# BOOTSTRAP CONFIDENCE INTERVALS
# ==============================================================================

#' Calculate bootstrap confidence interval for proportion
#'
#' Calculates confidence interval using bootstrap resampling. Works with
#' weighted and unweighted data. Uses percentile method.
#'
#' BOOTSTRAP PROCEDURE:
#' 1. Resample data with replacement (B times)
#' 2. Calculate proportion for each resample
#' 3. Use quantiles of bootstrap distribution as CI
#'
#' ADVANTAGES:
#' - Makes no distributional assumptions
#' - Handles weighted data naturally
#' - Can capture asymmetry in sampling distribution
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
#' @param data Vector. Data values (typically binary: 0/1 or response codes)
#' @param categories Vector. Categories to count as "success" (e.g., c(1) or c(4,5))
#' @param weights Vector. Survey weights (NULL for unweighted)
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
#'     \item{boot_mean}{Bootstrap mean (should be close to observed p)}
#'     \item{boot_samples}{Vector of all bootstrap proportions (for diagnostics)}
#'     \item{method}{"Bootstrap (percentile)" or "Bootstrap (percentile, parallel)"}
#'   }
#'
#' @examples
#' # Unweighted
#' data <- c(rep(1, 450), rep(0, 550))  # 45% success
#' result <- bootstrap_proportion_ci(data, categories = 1, B = 5000)
#'
#' # Weighted with parallel processing
#' result <- bootstrap_proportion_ci(data, categories = c(4,5),
#'                                    weights = weights_vector, B = 10000,
#'                                    parallel = TRUE)
#'
#' @references
#' Efron, B., & Tibshirani, R. J. (1994). An introduction to the bootstrap.
#' CRC press.
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
bootstrap_proportion_ci <- function(data, categories, weights = NULL,
                                    B = 5000, conf_level = 0.95, seed = NULL,
                                    parallel = FALSE) {
  # Input validation
  if (!is.numeric(data) && !is.character(data) && !is.factor(data)) {
    stop("data must be numeric, character, or factor", call. = FALSE)
  }

  if (length(data) == 0) {
    stop("data is empty", call. = FALSE)
  }

  validate_sample_size(B, "B", min_n = 1000)
  validate_conf_level(conf_level)

  # Set seed if specified (for reproducibility)
  if (!is.null(seed)) {
    set.seed(seed)
  }

  n <- length(data)
  is_weighted <- !is.null(weights) && length(weights) > 0

  # Validate weights if provided
  if (is_weighted) {
    if (length(weights) != n) {
      stop("weights must have same length as data", call. = FALSE)
    }
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
    boot_chunk <- function(indices, data, categories, weights, is_weighted, n, seed_base) {
      if (!is.null(seed_base)) set.seed(seed_base + indices[1])
      results <- numeric(length(indices))
      for (j in seq_along(indices)) {
        boot_indices <- sample(1:n, size = n, replace = TRUE)
        boot_data <- data[boot_indices]
        if (is_weighted) {
          boot_weights <- weights[boot_indices]
          in_category <- boot_data %in% categories
          results[j] <- sum(boot_weights[in_category]) / sum(boot_weights)
        } else {
          in_category <- boot_data %in% categories
          results[j] <- mean(in_category)
        }
      }
      results
    }

    # Run parallel bootstrap
    boot_results <- future.apply::future_lapply(
      chunks, boot_chunk,
      data = data, categories = categories, weights = weights,
      is_weighted = is_weighted, n = n, seed_base = seed,
      future.seed = TRUE
    )
    boot_proportions <- unlist(boot_results)
    method <- "Bootstrap (percentile, parallel)"

  } else {
    # ---------------------------------------------------------------------------
    # SEQUENTIAL BOOTSTRAP (default)
    # ---------------------------------------------------------------------------
    boot_proportions <- numeric(B)

    for (i in 1:B) {
      boot_indices <- sample(1:n, size = n, replace = TRUE)
      boot_data <- data[boot_indices]

      if (is_weighted) {
        boot_weights <- weights[boot_indices]
        in_category <- boot_data %in% categories
        boot_proportions[i] <- sum(boot_weights[in_category]) / sum(boot_weights)
      } else {
        in_category <- boot_data %in% categories
        boot_proportions[i] <- mean(in_category)
      }
    }
    method <- "Bootstrap (percentile)"
  }

  # Calculate percentile confidence interval
  alpha <- 1 - conf_level
  lower <- quantile(boot_proportions, alpha/2, names = FALSE)
  upper <- quantile(boot_proportions, 1 - alpha/2, names = FALSE)

  # Calculate bootstrap statistics
  boot_se <- sd(boot_proportions)
  boot_mean <- mean(boot_proportions)

  return(list(
    lower = lower,
    upper = upper,
    boot_se = boot_se,
    boot_mean = boot_mean,
    boot_samples = boot_proportions,
    method = method,
    B = B,
    warnings = character()
  ))
}


# ==============================================================================
# BAYESIAN CREDIBLE INTERVALS
# ==============================================================================

#' Calculate Bayesian credible interval for proportion
#'
#' Calculates Bayesian credible interval using Beta-Binomial conjugate prior.
#' Can use uninformed prior (Beta(1,1) = uniform) or informed prior from
#' previous data.
#'
#' BAYESIAN APPROACH:
#' - Prior: Beta(α₀, β₀) distribution for proportion
#' - Likelihood: Binomial(n, p)
#' - Posterior: Beta(α₀ + successes, β₀ + failures)
#' - Credible interval: quantiles of posterior distribution
#'
#' UNINFORMED PRIOR:
#' - Beta(1, 1) = Uniform(0, 1)
#' - Equal weight to all proportions
#' - Posterior dominated by data
#'
#' INFORMED PRIOR:
#' - Beta(α₀, β₀) where α₀ = prior_mean * prior_n, β₀ = (1-prior_mean) * prior_n
#' - prior_n represents "strength" of prior belief
#' - Useful for tracking studies (use previous wave as prior)
#'
#' @param p Numeric. Observed proportion
#' @param n Integer. Sample size
#' @param conf_level Numeric. Credibility level (default 0.95)
#' @param prior_mean Numeric. Prior proportion (NULL for uninformed prior)
#' @param prior_n Integer. Prior "sample size" - strength of prior belief
#'
#' @return List with elements:
#'   \describe{
#'     \item{lower}{Lower credible limit}
#'     \item{upper}{Upper credible limit}
#'     \item{post_mean}{Posterior mean}
#'     \item{prior_alpha}{Prior Beta alpha parameter}
#'     \item{prior_beta}{Prior Beta beta parameter}
#'     \item{post_alpha}{Posterior Beta alpha parameter}
#'     \item{post_beta}{Posterior Beta beta parameter}
#'     \item{prior_type}{"Uninformed" or "Informed"}
#'     \item{method}{"Bayesian (Beta-Binomial)"}
#'   }
#'
#' @examples
#' # Uninformed prior
#' result <- credible_interval_proportion(p = 0.45, n = 1000)
#'
#' # Informed prior from pilot (42% in n=450)
#' result <- credible_interval_proportion(p = 0.45, n = 1000,
#'                                        prior_mean = 0.42, prior_n = 450)
#'
#' @references
#' Gelman, A., et al. (2013). Bayesian data analysis (3rd ed.).
#' Chapman and Hall/CRC.
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
credible_interval_proportion <- function(p, n, conf_level = 0.95,
                                         prior_mean = NULL, prior_n = NULL) {
  # Input validation
  validate_proportion(p, "p")
  validate_sample_size(n, "n")
  validate_conf_level(conf_level)

  # Determine prior type and parameters
  use_uninformed <- is.null(prior_mean)

  if (use_uninformed) {
    # Uninformed prior: Beta(1, 1) = Uniform(0, 1)
    alpha_prior <- 1
    beta_prior <- 1
    prior_type <- "Uninformed"
  } else {
    # Informed prior
    validate_proportion(prior_mean, "prior_mean")

    # Default prior_n to 100 if not specified
    if (is.null(prior_n)) {
      prior_n <- 100
      warning("prior_n not specified, using default: 100", call. = FALSE)
    } else {
      validate_sample_size(prior_n, "prior_n")
    }

    # Convert prior proportion and sample size to Beta parameters
    alpha_prior <- prior_mean * prior_n
    beta_prior <- (1 - prior_mean) * prior_n
    prior_type <- "Informed"
  }

  # Calculate successes and failures from observed data
  successes <- round(p * n)
  failures <- n - successes

  # Posterior parameters (Beta conjugate update)
  alpha_post <- alpha_prior + successes
  beta_post <- beta_prior + failures

  # Posterior mean
  post_mean <- alpha_post / (alpha_post + beta_post)

  # Credible interval (quantiles of posterior Beta distribution)
  alpha <- 1 - conf_level
  lower <- qbeta(alpha/2, alpha_post, beta_post)
  upper <- qbeta(1 - alpha/2, alpha_post, beta_post)

  return(list(
    lower = lower,
    upper = upper,
    post_mean = post_mean,
    prior_alpha = alpha_prior,
    prior_beta = beta_prior,
    post_alpha = alpha_post,
    post_beta = beta_post,
    prior_type = prior_type,
    prior_mean = prior_mean,
    prior_n = prior_n,
    method = "Bayesian (Beta-Binomial)",
    warnings = character()
  ))
}


# ==============================================================================
# UNIFIED PROPORTION ANALYSIS FUNCTION
# ==============================================================================

#' Calculate all confidence methods for a proportion
#'
#' Convenience function that calculates all requested confidence methods
#' for a proportion. Handles data preparation and method dispatch.
#'
#' @param data Vector. Raw data
#' @param categories Vector. Categories to count as "success"
#' @param weights Vector. Survey weights (NULL for unweighted)
#' @param conf_level Numeric. Confidence level (default 0.95)
#' @param methods Character vector. Which methods to run:
#'   c("moe", "wilson", "bootstrap", "bayesian")
#' @param use_wilson_if_extreme Logical. Automatically use Wilson for p<0.1 or p>0.9
#' @param bootstrap_iterations Integer. Number of bootstrap iterations
#' @param prior_mean Numeric. Prior proportion for Bayesian
#' @param prior_n Integer. Prior sample size for Bayesian
#' @param seed Integer. Random seed for bootstrap
#'
#' @return List with results from each requested method
#'
#' @examples
#' data <- sample(1:5, 1000, replace = TRUE)
#' results <- analyze_proportion(
#'   data,
#'   categories = c(4, 5),
#'   methods = c("moe", "wilson", "bootstrap"),
#'   bootstrap_iterations = 5000
#' )
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
analyze_proportion <- function(data, categories, weights = NULL,
                               conf_level = 0.95,
                               methods = c("moe", "wilson", "bootstrap", "bayesian"),
                               use_wilson_if_extreme = TRUE,
                               bootstrap_iterations = 5000,
                               prior_mean = NULL, prior_n = NULL,
                               seed = NULL) {
  # Calculate observed proportion
  is_weighted <- !is.null(weights) && length(weights) > 0

  if (is_weighted) {
    in_category <- data %in% categories
    valid_weights <- weights[!is.na(data) & !is.na(weights)]
    valid_in_category <- in_category[!is.na(data) & !is.na(weights)]

    p <- sum(valid_weights[valid_in_category]) / sum(valid_weights)
    n_actual <- length(valid_weights)
    n_eff <- calculate_effective_n(valid_weights)
  } else {
    in_category <- data %in% categories
    valid_data <- in_category[!is.na(data)]

    p <- mean(valid_data)
    n_actual <- length(valid_data)
    n_eff <- n_actual
  }

  # Initialize results list
  results <- list(
    proportion = p,
    n_actual = n_actual,
    n_effective = n_eff,
    categories = categories,
    is_weighted = is_weighted
  )

  # Determine which MOE method to use
  moe_method <- "moe"
  if ("moe" %in% methods || "wilson" %in% methods) {
    if (use_wilson_if_extreme && (p < 0.10 || p > 0.90)) {
      moe_method <- "wilson"
      results$moe_method_reason <- "Extreme proportion - Wilson recommended"
    }
  }

  # Calculate MOE (normal or Wilson)
  if ("moe" %in% methods && moe_method == "moe") {
    results$moe <- calculate_proportion_ci_normal(p, n_eff, conf_level)
  }

  if ("wilson" %in% methods || moe_method == "wilson") {
    results$wilson <- calculate_proportion_ci_wilson(p, n_eff, conf_level)
  }

  # Calculate Bootstrap
  if ("bootstrap" %in% methods) {
    results$bootstrap <- bootstrap_proportion_ci(
      data, categories, weights,
      B = bootstrap_iterations,
      conf_level = conf_level,
      seed = seed
    )
  }

  # Calculate Bayesian
  if ("bayesian" %in% methods) {
    results$bayesian <- credible_interval_proportion(
      p, n_eff, conf_level,
      prior_mean = prior_mean,
      prior_n = prior_n
    )
  }

  return(results)
}
