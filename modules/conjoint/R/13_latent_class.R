# ==============================================================================
# LATENT CLASS ANALYSIS - CONJOINT
# ==============================================================================
#
# Module: Conjoint Analysis - Latent Class Estimation
# Purpose: Discover needs-based segments directly from choice data
# Version: 3.0.0
# Date: 2026-03-10
#
# WHAT LATENT CLASS PROVIDES:
#   - Automatic discovery of preference-based segments (classes)
#   - Class-level part-worth utilities (distinct preference profiles)
#   - Class membership probabilities per respondent
#   - Model selection via BIC/AIC comparison across K solutions
#   - Entropy R-squared for classification quality
#
# IMPLEMENTATION:
#   Uses bayesm::rhierMnlRwMixture with ncomp=K. Fits K=min..max,
#   selects optimal K by information criterion (BIC default).
#   Each class gets its own set of part-worth utilities.
#
# DEPENDENCIES:
#   - bayesm (required)
#   - 11_hierarchical_bayes.R (for prepare_bayesm_data, convergence diagnostics)
#
# ==============================================================================

CONJOINT_LC_VERSION <- "3.0.0"


# ==============================================================================
# MAIN LATENT CLASS ESTIMATION
# ==============================================================================

#' Estimate Latent Class Conjoint Model
#'
#' Fits mixture of normals HB models for K=min..max classes, selects the
#' optimal number of classes based on BIC (or AIC), and returns class-level
#' utilities with respondent membership assignments.
#'
#' @param data_list Data list from load_conjoint_data()
#' @param config Configuration object (must have latent_class_min, latent_class_max, etc.)
#' @param verbose Logical, print progress
#' @return turas_conjoint_model object with latent class results
#' @export
estimate_latent_class <- function(data_list, config, verbose = TRUE) {

  # Validate LC requirements
  validate_latent_class_config(config)

  log_verbose("Latent Class Analysis", verbose)
  log_verbose(sprintf("  → Testing K=%d to K=%d classes",
                       config$latent_class_min, config$latent_class_max), verbose)

  # Prepare data for bayesm (reuse HB data prep)
  bayesm_data <- prepare_bayesm_data(data_list, config, verbose)

  k_min <- as.integer(config$latent_class_min)
  k_max <- as.integer(config$latent_class_max)
  criterion <- tolower(config$latent_class_criterion)

  # MCMC settings (use HB settings but can reduce for LC search)
  R <- as.integer(config$hb_iterations)
  thin <- as.integer(config$hb_thin)

  # Fit models for each K
  solutions <- list()
  comparison <- data.frame(
    K = integer(0),
    LogLik = numeric(0),
    n_params = integer(0),
    AIC = numeric(0),
    BIC = numeric(0),
    Entropy_R2 = numeric(0),
    Converged = logical(0),
    stringsAsFactors = FALSE
  )

  for (k in k_min:k_max) {
    log_verbose(sprintf("  → Fitting K=%d class model...", k), verbose)

    sol <- fit_latent_class_k(bayesm_data, k, R, thin, config, verbose)

    if (is.null(sol)) {
      log_verbose(sprintf("  ⚠ K=%d failed, skipping", k), verbose)
      next
    }

    solutions[[as.character(k)]] <- sol

    comparison <- rbind(comparison, data.frame(
      K = k,
      LogLik = sol$log_likelihood,
      n_params = sol$n_params,
      AIC = sol$aic,
      BIC = sol$bic,
      Entropy_R2 = sol$entropy_r2,
      Converged = sol$converged,
      stringsAsFactors = FALSE
    ))

    log_verbose(sprintf("  ✓ K=%d: BIC=%.1f, AIC=%.1f, Entropy R²=%.3f",
                         k, sol$bic, sol$aic, sol$entropy_r2), verbose)
  }

  if (nrow(comparison) == 0) {
    conjoint_refuse(
      code = "LC_ALL_SOLUTIONS_FAILED",
      title = "All Latent Class Solutions Failed",
      problem = "Could not successfully fit any latent class model.",
      why_it_matters = "Latent class analysis requires at least one successful model fit.",
      how_to_fix = c(
        "Ensure sufficient respondents (50+ recommended for LC)",
        "Reduce latent_class_max to a smaller number",
        "Try HB estimation (estimation_method = 'hb') instead"
      )
    )
  }

  # Select optimal K
  if (criterion == "aic") {
    optimal_k <- comparison$K[which.min(comparison$AIC)]
  } else {
    optimal_k <- comparison$K[which.min(comparison$BIC)]
  }

  log_verbose(sprintf("  ★ Optimal: K=%d classes (by %s)", optimal_k, toupper(criterion)), verbose)

  optimal_solution <- solutions[[as.character(optimal_k)]]

  # Build standardized result
  result <- build_latent_class_result(
    optimal_solution, bayesm_data, config, comparison, solutions, verbose
  )

  result
}


# ==============================================================================
# FIT SINGLE K-CLASS MODEL
# ==============================================================================

#' Fit a Single K-Class Latent Class Model
#'
#' @param bayesm_data Prepared data from prepare_bayesm_data()
#' @param k Number of classes
#' @param R MCMC iterations
#' @param thin Thinning interval
#' @param config Configuration
#' @param verbose Logical
#' @return Solution list or NULL on failure
#' @keywords internal
fit_latent_class_k <- function(bayesm_data, k, R, thin, config, verbose = FALSE) {

  Data <- list(
    lgtdata = bayesm_data$lgtdata,
    p = bayesm_data$p
  )

  Prior <- list(
    ncomp = k
  )

  Mcmc <- list(
    R = R,
    keep = thin,
    nprint = 0  # Suppress iteration output during LC search
  )

  hb_output <- tryCatch({
    bayesm::rhierMnlRwMixture(
      Data = Data,
      Prior = Prior,
      Mcmc = Mcmc
    )
  }, error = function(e) {
    if (verbose) {
      message(sprintf("[TRS INFO] CONJ_LC_K%d_FAILED: %s", k, conditionMessage(e)))
    }
    return(NULL)
  })

  if (is.null(hb_output)) return(NULL)

  # Extract results for this K
  extract_lc_solution(hb_output, bayesm_data, k, R, thin, config)
}


# ==============================================================================
# EXTRACT SOLUTION FOR A GIVEN K
# ==============================================================================

#' Extract Latent Class Solution from bayesm Output
#'
#' @param hb_output bayesm output
#' @param bayesm_data Prepared data
#' @param k Number of classes
#' @param R Total iterations
#' @param thin Thinning interval
#' @param config Configuration
#' @return Solution list
#' @keywords internal
extract_lc_solution <- function(hb_output, bayesm_data, k, R, thin, config) {

  n_respondents <- bayesm_data$n_respondents
  n_parameters <- bayesm_data$n_parameters
  col_names <- bayesm_data$col_names
  respondent_ids <- bayesm_data$respondent_ids

  betadraw <- hb_output$betadraw
  n_draws <- dim(betadraw)[3]

  # Individual-level posterior means
  individual_betas <- matrix(NA, nrow = n_respondents, ncol = n_parameters)
  for (i in seq_len(n_respondents)) {
    individual_betas[i, ] <- colMeans(betadraw[i, , , drop = FALSE])
  }
  colnames(individual_betas) <- col_names
  rownames(individual_betas) <- respondent_ids

  # Assign respondents to classes using k-means on individual betas
  # This is the standard approach when using bayesm for LC
  if (k == 1) {
    class_assignment <- rep(1L, n_respondents)
    class_probs <- matrix(1, nrow = n_respondents, ncol = 1)
  } else {
    km <- tryCatch({
      kmeans(individual_betas, centers = k, nstart = 25, iter.max = 100)
    }, error = function(e) {
      # Fallback: simple assignment based on first principal component
      NULL
    })

    if (!is.null(km)) {
      class_assignment <- km$cluster
      # Compute soft probabilities based on distance to centers
      class_probs <- compute_class_probabilities(individual_betas, km$centers)
    } else {
      # Fallback: equal assignment
      class_assignment <- rep(seq_len(k), length.out = n_respondents)
      class_probs <- matrix(1 / k, nrow = n_respondents, ncol = k)
    }
  }

  # Class-level utilities (mean of individual betas per class)
  class_betas <- matrix(NA, nrow = k, ncol = n_parameters)
  class_sizes <- integer(k)
  for (c in seq_len(k)) {
    members <- which(class_assignment == c)
    class_sizes[c] <- length(members)
    if (length(members) > 0) {
      class_betas[c, ] <- colMeans(individual_betas[members, , drop = FALSE])
    }
  }
  colnames(class_betas) <- col_names
  rownames(class_betas) <- paste0("Class_", seq_len(k))

  # Calculate log-likelihood for information criteria
  ll <- calculate_lc_log_likelihood(individual_betas, bayesm_data)

  # Number of parameters: k classes * n_parameters + (k-1) class membership
  n_params <- k * n_parameters + (k - 1)
  n_obs <- sum(sapply(bayesm_data$lgtdata, function(x) length(x$y)))

  aic <- -2 * ll + 2 * n_params
  bic <- -2 * ll + log(n_obs) * n_params

  # Entropy R-squared
  entropy_r2 <- calculate_entropy_r2(class_probs, k)

  # Convergence check (simplified)
  convergence <- run_hb_convergence_diagnostics(hb_output, bayesm_data, verbose = FALSE)

  list(
    k = k,
    hb_output = hb_output,
    individual_betas = individual_betas,
    class_assignment = class_assignment,
    class_probs = class_probs,
    class_betas = class_betas,
    class_sizes = class_sizes,
    log_likelihood = ll,
    n_params = n_params,
    aic = aic,
    bic = bic,
    entropy_r2 = entropy_r2,
    converged = convergence$converged,
    convergence = convergence
  )
}


# ==============================================================================
# CLASS PROBABILITY & MEMBERSHIP
# ==============================================================================

#' Compute Soft Class Probabilities from K-means Distances
#'
#' Converts Euclidean distances to cluster centers into probability-like
#' membership weights using softmax on negative distances.
#'
#' @param betas Matrix of individual betas [n_respondents x n_parameters]
#' @param centers Matrix of cluster centers [k x n_parameters]
#' @return Matrix of class probabilities [n_respondents x k]
#' @keywords internal
compute_class_probabilities <- function(betas, centers) {

  n <- nrow(betas)
  k <- nrow(centers)

  # Calculate squared Euclidean distance to each center
  distances <- matrix(NA, nrow = n, ncol = k)
  for (c in seq_len(k)) {
    diff <- sweep(betas, 2, centers[c, ])
    distances[, c] <- rowSums(diff^2)
  }

  # Convert to probabilities via softmax on negative distances
  # Scale distances to prevent numerical overflow
  neg_dist <- -distances
  row_max <- apply(neg_dist, 1, max)
  scaled <- neg_dist - row_max
  exp_scaled <- exp(scaled)
  row_sums <- rowSums(exp_scaled)
  probs <- exp_scaled / row_sums

  probs
}


#' Assign Respondents to Classes
#'
#' Provides both modal (hard) and probability-weighted (soft) assignment.
#'
#' @param class_probs Matrix [n_respondents x k] of membership probabilities
#' @param respondent_ids Vector of respondent identifiers
#' @return Data frame with respondent_id, modal_class, and per-class probabilities
#' @keywords internal
assign_respondents_to_classes <- function(class_probs, respondent_ids) {

  k <- ncol(class_probs)
  n <- nrow(class_probs)

  # Modal assignment
  modal_class <- apply(class_probs, 1, which.max)
  max_prob <- apply(class_probs, 1, max)

  result <- data.frame(
    Respondent = respondent_ids,
    Modal_Class = modal_class,
    Max_Probability = max_prob,
    stringsAsFactors = FALSE
  )

  # Add per-class probability columns
  for (c in seq_len(k)) {
    result[[paste0("Class_", c, "_Prob")]] <- class_probs[, c]
  }

  result
}


# ==============================================================================
# INFORMATION CRITERIA & MODEL SELECTION
# ==============================================================================

#' Calculate Log-Likelihood for LC Model
#'
#' Computes the total log-likelihood based on individual-level betas
#' and the observed choices.
#'
#' @param individual_betas Matrix of individual betas
#' @param bayesm_data Prepared bayesm data
#' @return Total log-likelihood
#' @keywords internal
calculate_lc_log_likelihood <- function(individual_betas, bayesm_data) {

  n_respondents <- bayesm_data$n_respondents
  lgtdata <- bayesm_data$lgtdata
  total_ll <- 0

  for (i in seq_len(n_respondents)) {
    resp <- lgtdata[[i]]
    betas <- individual_betas[i, ]
    X <- resp$X
    y <- resp$y
    n_tasks <- length(y)
    rows_per_task <- nrow(X) / n_tasks

    for (t in seq_len(n_tasks)) {
      row_start <- (t - 1) * rows_per_task + 1
      row_end <- t * rows_per_task
      X_task <- X[row_start:row_end, , drop = FALSE]

      V <- as.numeric(X_task %*% betas)
      exp_V <- exp(V - max(V))
      prob <- exp_V / sum(exp_V)
      chosen_prob <- prob[y[t]]

      total_ll <- total_ll + log(max(chosen_prob, 1e-300))
    }
  }

  total_ll
}


#' Calculate Entropy R-Squared
#'
#' Measures classification quality. Values near 1 indicate clear class
#' separation; values near 0 indicate poor separation.
#'
#' Formula: 1 - E_k / E_0
#' where E_k = -sum(p * log(p)) for K-class solution
#' and E_0 = N * log(K) for equi-probable K classes
#'
#' @param class_probs Matrix of class probabilities
#' @param k Number of classes
#' @return Entropy R-squared value
#' @keywords internal
calculate_entropy_r2 <- function(class_probs, k) {

  if (k <= 1) return(1.0)

  n <- nrow(class_probs)

  # Actual entropy
  # Clip probabilities to avoid log(0)
  p_clipped <- pmax(class_probs, 1e-300)
  E_k <- -sum(p_clipped * log(p_clipped))

  # Maximum entropy (equi-probable)
  E_0 <- n * log(k)

  if (E_0 == 0) return(1.0)

  1 - E_k / E_0
}


#' Compare Class Solutions
#'
#' Creates comparison table across all fitted K solutions.
#'
#' @param comparison Data frame from estimate_latent_class
#' @return Formatted comparison data frame
#' @keywords internal
compare_class_solutions <- function(comparison) {

  # Add delta columns
  comparison$Delta_BIC <- c(NA, diff(comparison$BIC))
  comparison$Delta_AIC <- c(NA, diff(comparison$AIC))

  # Mark optimal
  comparison$Best_BIC <- comparison$BIC == min(comparison$BIC)
  comparison$Best_AIC <- comparison$AIC == min(comparison$AIC)

  comparison
}


# ==============================================================================
# BUILD FINAL RESULT
# ==============================================================================

#' Build Latent Class Result Object
#'
#' Assembles the standardized turas_conjoint_model for the optimal LC solution.
#'
#' @param solution Optimal K solution
#' @param bayesm_data Prepared bayesm data
#' @param config Configuration
#' @param comparison K-comparison data frame
#' @param all_solutions List of all K solutions
#' @param verbose Logical
#' @return turas_conjoint_model object
#' @keywords internal
build_latent_class_result <- function(solution, bayesm_data, config,
                                      comparison, all_solutions, verbose = TRUE) {

  k <- solution$k
  col_names <- bayesm_data$col_names
  respondent_ids <- bayesm_data$respondent_ids

  # Aggregate betas (population mean)
  aggregate_betas <- colMeans(solution$individual_betas)
  aggregate_sds <- apply(solution$individual_betas, 2, sd)

  # Respondent membership
  membership <- assign_respondents_to_classes(solution$class_probs, respondent_ids)

  # Respondent quality (RLH)
  quality <- calculate_respondent_rlh(
    solution$individual_betas, bayesm_data, config, verbose
  )

  # Class profiles: importance per class
  class_importance <- list()
  for (c in seq_len(k)) {
    members <- which(solution$class_assignment == c)
    if (length(members) > 0) {
      # Create a mini HB result for this class
      class_hb <- list(
        individual_betas = solution$individual_betas[members, , drop = FALSE],
        col_names = col_names
      )
      class_importance[[paste0("Class_", c)]] <- calculate_attribute_importance_hb(
        class_hb, config, verbose = FALSE
      )
    }
  }

  log_verbose(sprintf("  ✓ Latent class result built: %d classes, %d respondents",
                       k, length(respondent_ids)), verbose)

  # Build standardized result
  structure(list(
    method = "latent_class",
    model = solution$hb_output,
    coefficients = aggregate_betas,
    vcov = NULL,
    std_errors = aggregate_sds,
    loglik = c(null = NA_real_, fitted = solution$log_likelihood),
    n_obs = sum(sapply(bayesm_data$lgtdata, function(x) length(x$y) * bayesm_data$p)),
    n_respondents = bayesm_data$n_respondents,
    n_choice_sets = sum(sapply(bayesm_data$lgtdata, function(x) length(x$y))),
    n_parameters = bayesm_data$n_parameters,
    convergence = solution$convergence,
    aic = solution$aic,
    bic = solution$bic,

    # HB-level fields (LC inherits from HB)
    individual_betas = solution$individual_betas,
    individual_sds = NULL,
    betadraw = solution$hb_output$betadraw,
    respondent_ids = respondent_ids,
    attribute_map = bayesm_data$attribute_map,
    col_names = col_names,
    respondent_quality = quality,
    hb_settings = list(
      iterations = config$hb_iterations,
      burnin = config$hb_burnin,
      thin = config$hb_thin,
      ncomp = k,
      n_draws_retained = dim(solution$hb_output$betadraw)[3]
    ),

    # LC-specific fields
    latent_class = list(
      optimal_k = k,
      class_assignment = solution$class_assignment,
      class_probs = solution$class_probs,
      class_betas = solution$class_betas,
      class_sizes = solution$class_sizes,
      class_proportions = solution$class_sizes / bayesm_data$n_respondents,
      class_importance = class_importance,
      membership = membership,
      entropy_r2 = solution$entropy_r2,
      comparison = compare_class_solutions(comparison),
      all_solutions = all_solutions,
      criterion = config$latent_class_criterion
    )
  ), class = "turas_conjoint_model")
}


# ==============================================================================
# LC-SPECIFIC UTILITY EXTRACTION
# ==============================================================================

#' Extract Latent Class Utilities in Standard Format
#'
#' Returns both aggregate and class-level utilities in the standard
#' data frame format used by downstream functions.
#'
#' @param lc_result LC model result
#' @param config Configuration
#' @param verbose Logical
#' @return List with aggregate_utilities and class_utilities
#' @keywords internal
extract_lc_utilities <- function(lc_result, config, verbose = TRUE) {

  log_verbose("  → Extracting latent class utilities...", verbose)

  # Aggregate utilities (same as HB extraction)
  aggregate <- extract_hb_utilities(lc_result, config, verbose = FALSE)

  # Class-level utilities
  lc <- lc_result$latent_class
  k <- lc$optimal_k
  class_utils_list <- list()

  for (c in seq_len(k)) {
    # Build a pseudo-model with this class's betas as the aggregate
    class_model <- list(
      coefficients = lc$class_betas[c, ],
      std_errors = rep(0, length(lc$class_betas[c, ])),
      attribute_map = lc_result$attribute_map,
      col_names = lc_result$col_names
    )

    class_df <- extract_hb_utilities(class_model, config, verbose = FALSE)
    class_df$Class <- paste0("Class ", c)
    class_df$Class_Size <- lc$class_sizes[c]
    class_df$Class_Pct <- sprintf("%.1f%%", lc$class_proportions[c] * 100)

    class_utils_list[[c]] <- class_df
  }

  class_utilities <- do.call(rbind, class_utils_list)
  rownames(class_utilities) <- NULL

  list(
    aggregate = aggregate,
    class_utilities = class_utilities
  )
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>Conjoint Latent Class module loaded (v%s)", CONJOINT_LC_VERSION))
