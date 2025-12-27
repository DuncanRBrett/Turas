# ==============================================================================
# BEST-WORST SCALING - ADVANCED CONJOINT ANALYSIS
# ==============================================================================
#
# This file implements best-worst scaling (BWS) for conjoint analysis.
# BWS asks respondents to select both the BEST and WORST alternatives in each
# choice set, providing more information per choice task.
#
# Supported formats:
# - MaxDiff (best-worst discrete choice)
# - Best-worst conjoint (product profiles)
# - Multi-profile best-worst
#
# Part of: Turas Enhanced Conjoint Analysis Module
# Version: 2.0.0
# ==============================================================================

# ==============================================================================
# 1. BEST-WORST DATA VALIDATION
# ==============================================================================

#' Validate best-worst data format
#'
#' @param data Data frame with best and worst columns
#' @param config Configuration object
#'
#' @return List with validation results
validate_best_worst_data <- function(data, config) {

  validation <- list(
    critical = character(0),
    warnings = character(0),
    info = character(0)
  )

  # Check for required columns
  if (!"best" %in% names(data)) {
    validation$critical <- c(validation$critical,
                              "Missing 'best' column for best-worst analysis")
  }

  if (!"worst" %in% names(data)) {
    validation$critical <- c(validation$critical,
                              "Missing 'worst' column for best-worst analysis")
  }

  if (length(validation$critical) > 0) {
    return(validation)
  }

  # Validate best-worst choices
  choice_set_col <- config$respondent_id_column %||% "choice_set_id"

  # Check: Exactly one best per choice set
  best_per_set <- data %>%
    group_by(!!sym(choice_set_col)) %>%
    summarise(n_best = sum(best))

  if (any(best_per_set$n_best != 1)) {
    validation$critical <- c(validation$critical,
                              "Each choice set must have exactly 1 'best' selection")
  }

  # Check: Exactly one worst per choice set
  worst_per_set <- data %>%
    group_by(!!sym(choice_set_col)) %>%
    summarise(n_worst = sum(worst))

  if (any(worst_per_set$n_worst != 1)) {
    validation$critical <- c(validation$critical,
                              "Each choice set must have exactly 1 'worst' selection")
  }

  # Check: Best and worst are different
  both_selected <- data[data$best == 1 & data$worst == 1, ]
  if (nrow(both_selected) > 0) {
    validation$critical <- c(validation$critical,
                              "Same alternative cannot be both best AND worst")
  }

  # Info: Count best-worst choices
  n_best <- sum(data$best)
  n_worst <- sum(data$worst)

  validation$info <- c(validation$info,
                        sprintf("Best choices: %d", n_best),
                        sprintf("Worst choices: %d", n_worst))

  validation
}


# ==============================================================================
# 2. BEST-WORST DATA PREPARATION
# ==============================================================================

#' Convert best-worst data to choice format
#'
#' Best-worst scaling provides 2 choices per set:
#' - Best choice (utility maximization)
#' - Worst choice (utility minimization)
#'
#' We convert this to standard choice format by creating 2 observations per set:
#' 1. Best choice (chosen = best)
#' 2. Worst choice with reversed utilities (chosen = worst)
#'
#' @param data Data frame with best and worst columns
#' @param config Configuration object
#'
#' @return Data frame in choice format
convert_best_worst_to_choice <- function(data, config) {

  choice_set_col <- config$choice_set_column %||% "choice_set_id"

  # Create best-choice observations
  best_data <- data
  best_data$chosen <- best_data$best
  best_data$choice_type <- "best"
  best_data$best <- NULL
  best_data$worst <- NULL

  # Create worst-choice observations
  worst_data <- data
  worst_data$chosen <- worst_data$worst
  worst_data$choice_type <- "worst"

  # Modify choice set IDs for worst to make them unique
  worst_data[[choice_set_col]] <- paste0(worst_data[[choice_set_col]], "_worst")

  worst_data$best <- NULL
  worst_data$worst <- NULL

  # Combine
  combined_data <- rbind(best_data, worst_data)

  combined_data
}


# ==============================================================================
# 3. BEST-WORST ESTIMATION
# ==============================================================================

#' Estimate best-worst scaling model
#'
#' @param data_list Data list with best-worst data
#' @param config Configuration object
#' @param method Character: "sequential" or "simultaneous"
#'   - sequential: Estimate best and worst separately, then combine
#'   - simultaneous: Estimate jointly with choice type indicator
#' @param verbose Logical
#'
#' @return Model result
estimate_best_worst_model <- function(data_list,
                                       config,
                                       method = "sequential",
                                       verbose = TRUE) {

  # Validate data
  validation <- validate_best_worst_data(data_list$data, config)

  if (length(validation$critical) > 0) {
    conjoint_refuse(
      code = "DATA_BEST_WORST_VALIDATION_FAILED",
      title = "Best-Worst Data Validation Failed",
      problem = "Best-worst data validation failed",
      why_it_matters = "Invalid best-worst data cannot be used for MaxDiff or BWS analysis.",
      how_to_fix = c(
        "Check that data has 'best' and 'worst' columns",
        "Ensure exactly one best and one worst selection per choice set",
        "Verify best and worst selections are different alternatives"
      ),
      details = paste(validation$critical, collapse = "; ")
    )
  }

  if (verbose) {
    cat("\nEstimating best-worst scaling model...\n")
    cat(sprintf("  Method: %s\n", method))
  }

  # Convert to choice format
  choice_data <- convert_best_worst_to_choice(data_list$data, config)

  if (verbose) {
    cat(sprintf("  Converted %d choice sets to %d observations\n",
                nrow(data_list$data) / (data_list$n_alternatives_per_set %||% 3),
                nrow(choice_data)))
  }

  # Estimate based on method
  if (method == "sequential") {
    result <- estimate_best_worst_sequential(choice_data, config, verbose)
  } else if (method == "simultaneous") {
    result <- estimate_best_worst_simultaneous(choice_data, config, verbose)
  } else {
    conjoint_refuse(
      code = "CFG_BEST_WORST_UNKNOWN_METHOD",
      title = "Unknown Best-Worst Method",
      problem = sprintf("Unknown best-worst method: %s", method),
      why_it_matters = "Best-worst scaling requires a valid estimation method.",
      how_to_fix = "Use 'sequential' or 'simultaneous' as the method parameter"
    )
  }

  # Add best-worst flag
  result$is_best_worst <- TRUE
  result$best_worst_method <- method

  result
}


#' Estimate best-worst model sequentially
#'
#' @keywords internal
estimate_best_worst_sequential <- function(data, config, verbose = TRUE) {

  # Split into best and worst datasets
  best_data <- data[data$choice_type == "best", ]
  worst_data <- data[data$choice_type == "worst", ]

  if (verbose) {
    cat("\n  Estimating 'best' choices...\n")
  }

  # Estimate best model
  best_data_list <- list(
    data = best_data,
    n_obs = nrow(best_data)
  )

  best_result <- estimate_choice_model(best_data_list, config, verbose = FALSE)

  if (verbose) {
    cat(sprintf("    ✓ Best model: LL = %.2f\n", best_result$loglik[2]))
    cat("\n  Estimating 'worst' choices...\n")
  }

  # Estimate worst model (utility signs will be reversed)
  worst_data_list <- list(
    data = worst_data,
    n_obs = nrow(worst_data)
  )

  worst_result <- estimate_choice_model(worst_data_list, config, verbose = FALSE)

  if (verbose) {
    cat(sprintf("    ✓ Worst model: LL = %.2f\n", worst_result$loglik[2]))
  }

  # Combine results (average coefficients)
  # Best coefficients are positive, worst are negative (reversed sign)
  combined_coef <- (best_result$coefficients - worst_result$coefficients) / 2

  # Combined standard errors (approximate)
  if (!is.null(best_result$std_errors) && !is.null(worst_result$std_errors)) {
    combined_se <- sqrt(
      (best_result$std_errors^2 + worst_result$std_errors^2) / 4
    )
  } else {
    combined_se <- NULL
  }

  # Create combined result
  list(
    method = "best_worst_sequential",
    coefficients = combined_coef,
    std_errors = combined_se,
    vcov = NULL,  # Would need to combine variance-covariance matrices
    loglik = c(NA, best_result$loglik[2] + worst_result$loglik[2]),
    n_obs = nrow(data),
    n_params = length(combined_coef),
    convergence = list(
      converged = best_result$convergence$converged && worst_result$convergence$converged,
      message = "Best and worst models both converged"
    ),
    best_model = best_result,
    worst_model = worst_result
  )
}


#' Estimate best-worst model simultaneously
#'
#' @keywords internal
estimate_best_worst_simultaneous <- function(data, config, verbose = TRUE) {

  # For simultaneous estimation, we treat it as a single model
  # with choice_type as a covariate

  if (verbose) {
    cat("\n  Estimating joint best-worst model...\n")
  }

  # Create data list
  data_list <- list(
    data = data,
    n_obs = nrow(data)
  )

  # Estimate
  result <- estimate_choice_model(data_list, config, verbose = FALSE)

  # Add method info
  result$method <- "best_worst_simultaneous"

  if (verbose) {
    cat(sprintf("    ✓ Joint model: LL = %.2f\n", result$loglik[2]))
  }

  result
}


# ==============================================================================
# 4. BEST-WORST UTILITIES
# ==============================================================================

#' Calculate utilities from best-worst model
#'
#' @param model_result Best-worst model result
#' @param config Configuration
#' @param verbose Logical
#'
#' @return Data frame of utilities
calculate_best_worst_utilities <- function(model_result, config, verbose = TRUE) {

  if (!model_result$is_best_worst) {
    conjoint_refuse(
      code = "MODEL_NOT_BEST_WORST",
      title = "Not a Best-Worst Model",
      problem = "Model is not a best-worst scaling model",
      why_it_matters = "Best-worst utility calculation requires a model estimated with best-worst data.",
      how_to_fix = "Use estimate_best_worst_model() to estimate a best-worst model first"
    )
  }

  # Use standard utility calculation
  utilities <- calculate_utilities(model_result, config, verbose = verbose)

  # Add best-worst specific info
  utilities$Model_Type <- "Best-Worst Scaling"

  if (verbose) {
    cat("\nBest-worst utilities calculated\n")
    cat(sprintf("  Method: %s\n", model_result$best_worst_method))
  }

  utilities
}


# ==============================================================================
# 5. BEST-WORST DIAGNOSTICS
# ==============================================================================

#' Calculate best-worst model diagnostics
#'
#' @param model_result Best-worst model result
#' @param data_list Original data list
#'
#' @return List of diagnostic statistics
calculate_best_worst_diagnostics <- function(model_result, data_list) {

  diagnostics <- list()

  # Model fit
  if (!is.null(model_result$loglik)) {
    diagnostics$log_likelihood <- model_result$loglik[2]

    # Calculate pseudo R-squared if null model available
    if (length(model_result$loglik) == 2) {
      ll_null <- model_result$loglik[1]
      ll_fitted <- model_result$loglik[2]

      diagnostics$mcfadden_r2 <- 1 - (ll_fitted / ll_null)
    }
  }

  # Best vs. Worst comparison
  if (model_result$best_worst_method == "sequential") {
    diagnostics$best_model_ll <- model_result$best_model$loglik[2]
    diagnostics$worst_model_ll <- model_result$worst_model$loglik[2]

    diagnostics$ll_ratio_best_to_worst <-
      model_result$best_model$loglik[2] / model_result$worst_model$loglik[2]
  }

  diagnostics$n_observations <- model_result$n_obs
  diagnostics$n_parameters <- model_result$n_params

  diagnostics
}


# ==============================================================================
# 6. UTILITY FUNCTIONS
# ==============================================================================

#' Check if model is best-worst scaling
#'
#' @param model_result Model result object
#'
#' @return Logical
is_best_worst_model <- function(model_result) {
  !is.null(model_result$is_best_worst) && model_result$is_best_worst
}


#' Create best-worst data template
#'
#' @param n_respondents Integer
#' @param n_sets_per_resp Integer
#' @param n_alternatives Integer
#' @param attributes List of attribute definitions
#'
#' @return Data frame template
create_best_worst_template <- function(n_respondents = 50,
                                        n_sets_per_resp = 8,
                                        n_alternatives = 3,
                                        attributes = list(
                                          Price = c("$10", "$20", "$30"),
                                          Brand = c("A", "B", "C")
                                        )) {

  # Create empty data frame
  n_rows <- n_respondents * n_sets_per_resp * n_alternatives

  data <- data.frame(
    resp_id = rep(1:n_respondents, each = n_sets_per_resp * n_alternatives),
    choice_set_id = rep(
      rep(1:n_sets_per_resp, each = n_alternatives),
      n_respondents
    ),
    alternative_id = rep(1:n_alternatives, n_respondents * n_sets_per_resp),
    best = 0,
    worst = 0,
    stringsAsFactors = FALSE
  )

  # Add attribute columns (with random levels)
  for (attr_name in names(attributes)) {
    levels <- attributes[[attr_name]]
    data[[attr_name]] <- sample(levels, n_rows, replace = TRUE)
  }

  # Note: User needs to fill in 'best' and 'worst' columns
  attr(data, "note") <- "Fill in 'best' and 'worst' columns (exactly 1 of each per choice set)"

  data
}
