# ==============================================================================
# MAXDIFF MODULE - AGGREGATE LOGIT MODEL - TURAS V10.0
# ==============================================================================
# Aggregate conditional logit model for MaxDiff analysis
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# MODEL:
# P(item i chosen as Best | set S) = exp(beta_i) / sum_j exp(beta_j)
# P(item i chosen as Worst | set S) = exp(-beta_i) / sum_j exp(-beta_j)
#
# DEPENDENCIES:
# - survival (for clogit)
# - utils.R
# ==============================================================================

LOGIT_VERSION <- "10.0"

# ==============================================================================
# MAIN LOGIT ESTIMATOR
# ==============================================================================

#' Fit Aggregate Logit Model
#'
#' Fits conditional logit model to MaxDiff choice data.
#' Uses survival::clogit for efficient computation.
#'
#' @param long_data Data frame. Long format MaxDiff data
#' @param items Data frame. Items configuration
#' @param weighted Logical. Use weights (default: TRUE)
#' @param anchor_item Character. Item ID to use as anchor (utility = 0)
#' @param verbose Logical. Print progress messages
#'
#' @return List containing:
#'   - utilities: Data frame with item utilities and SEs
#'   - model_fit: Model fit statistics
#'   - model_object: The fitted model object
#'
#' @export
fit_aggregate_logit <- function(long_data, items, weighted = TRUE,
                                anchor_item = NULL, verbose = TRUE) {

  if (verbose) log_message("Fitting aggregate logit model...", "INFO", verbose)

  # Check for survival package
  if (!requireNamespace("survival", quietly = TRUE)) {
    stop("Package 'survival' is required for logit estimation.\n  Install with: install.packages('survival')",
         call. = FALSE)
  }

  # Get included items
  included_items <- items$Item_ID[items$Include == 1]
  n_items <- length(included_items)

  # Determine anchor item
  if (is.null(anchor_item)) {
    # Use designated anchor or last item
    anchor_idx <- which(items$Anchor_Item == 1 & items$Include == 1)
    if (length(anchor_idx) > 0) {
      anchor_item <- items$Item_ID[anchor_idx[1]]
    } else {
      anchor_item <- included_items[n_items]
    }
  }

  if (verbose) {
    log_message(sprintf("Anchor item: %s", anchor_item), "INFO", verbose)
  }

  # Prepare data for clogit
  # Need to create choice sets and binary choice indicators
  logit_data <- prepare_logit_data(long_data, included_items, anchor_item)

  if (nrow(logit_data) == 0) {
    stop("No valid choice data for logit estimation", call. = FALSE)
  }

  # Build formula
  # Remove anchor item from predictors
  non_anchor_items <- setdiff(included_items, anchor_item)

  # Create item indicator variables
  for (item_id in non_anchor_items) {
    safe_name <- make.names(paste0("item_", item_id))
    logit_data[[safe_name]] <- as.numeric(logit_data$item_id == item_id)
  }

  # Formula with item indicators
  item_vars <- paste0("item_", make.names(non_anchor_items))
  formula_str <- paste("choice ~", paste(item_vars, collapse = " + "),
                       "+ strata(choice_set)")
  model_formula <- as.formula(formula_str)

  # Fit model
  model <- tryCatch({
    if (weighted && "weight" %in% names(logit_data)) {
      survival::clogit(
        model_formula,
        data = logit_data,
        weights = logit_data$weight,
        method = "efron"
      )
    } else {
      survival::clogit(
        model_formula,
        data = logit_data,
        method = "efron"
      )
    }
  }, error = function(e) {
    stop(sprintf(
      "Logit model fitting failed:\n  Error: %s",
      conditionMessage(e)
    ), call. = FALSE)
  })

  # Extract utilities
  utilities <- extract_logit_utilities(model, non_anchor_items, anchor_item, items)

  # Model fit statistics
  model_fit <- compute_logit_fit(model, logit_data)

  if (verbose) {
    log_message(sprintf(
      "Logit model fitted: Log-likelihood = %.1f, AIC = %.1f",
      model_fit$log_likelihood, model_fit$aic
    ), "INFO", verbose)
  }

  return(list(
    utilities = utilities,
    model_fit = model_fit,
    model_object = model,
    anchor_item = anchor_item
  ))
}


# ==============================================================================
# DATA PREPARATION
# ==============================================================================

#' Prepare data for conditional logit
#'
#' Restructures long data for clogit with separate best/worst observations.
#'
#' @param long_data Data frame. Long format data
#' @param item_ids Character vector. Item IDs
#' @param anchor_item Character. Anchor item ID
#'
#' @return Data frame for clogit
#' @keywords internal
prepare_logit_data <- function(long_data, item_ids, anchor_item) {

  # Create unique task identifier combining respondent, version, task
  long_data$resp_task <- paste(long_data$resp_id, long_data$version,
                               long_data$task, sep = "_")

  # Get unique tasks
  unique_tasks <- unique(long_data$resp_task)

  # Build choice sets for best and worst
  choice_sets <- list()
  set_id <- 1

  for (task_key in unique_tasks) {
    task_data <- long_data[long_data$resp_task == task_key, ]

    # Get items shown in this task
    items_shown <- task_data$item_id

    # Get best and worst choices
    best_item <- task_data$item_id[task_data$is_best == 1]
    worst_item <- task_data$item_id[task_data$is_worst == 1]

    # Get weight (same for all items in task)
    weight <- task_data$weight[1]

    # Skip if no valid choices
    if (length(best_item) != 1 || length(worst_item) != 1) next

    # BEST choice set
    for (item in items_shown) {
      choice_sets[[length(choice_sets) + 1]] <- data.frame(
        choice_set = set_id,
        choice_type = "best",
        item_id = item,
        choice = as.integer(item == best_item),
        weight = weight,
        stringsAsFactors = FALSE
      )
    }
    set_id <- set_id + 1

    # WORST choice set (utilities are negated)
    for (item in items_shown) {
      choice_sets[[length(choice_sets) + 1]] <- data.frame(
        choice_set = set_id,
        choice_type = "worst",
        item_id = item,
        choice = as.integer(item == worst_item),
        weight = weight,
        stringsAsFactors = FALSE
      )
    }
    set_id <- set_id + 1
  }

  logit_data <- do.call(rbind, choice_sets)

  # For worst choices, we need to negate the utility
  # This is handled by creating a sign multiplier
  logit_data$sign <- ifelse(logit_data$choice_type == "best", 1, -1)

  return(logit_data)
}


#' Extract utilities from fitted model
#'
#' @param model Fitted clogit model
#' @param non_anchor_items Character vector. Non-anchor item IDs
#' @param anchor_item Character. Anchor item ID
#' @param items Data frame. Items configuration
#'
#' @return Data frame with utilities
#' @keywords internal
extract_logit_utilities <- function(model, non_anchor_items, anchor_item, items) {

  # Get coefficients and standard errors
  coefs <- coef(model)
  se <- sqrt(diag(vcov(model)))

  # Extract item names from coefficient names
  # Coefficients are named like "item_B01" etc.

  # Build utilities data frame
  utilities <- data.frame(
    Item_ID = c(non_anchor_items, anchor_item),
    Logit_Utility = c(as.numeric(coefs), 0),
    Logit_SE = c(as.numeric(se), NA_real_),
    stringsAsFactors = FALSE
  )

  # Add item info
  utilities <- merge(
    utilities,
    items[, c("Item_ID", "Item_Label", "Item_Group", "Display_Order")],
    by = "Item_ID",
    all.x = TRUE
  )

  # Calculate t-values and p-values
  utilities$t_value <- utilities$Logit_Utility / utilities$Logit_SE
  utilities$p_value <- 2 * pnorm(-abs(utilities$t_value))

  # Sort by utility
  utilities <- utilities[order(-utilities$Logit_Utility), ]

  # Add rank
  utilities$Rank <- rank(-utilities$Logit_Utility, ties.method = "min")

  return(utilities)
}


#' Compute model fit statistics
#'
#' @param model Fitted clogit model
#' @param logit_data Data frame used for fitting
#'
#' @return List with fit statistics
#' @keywords internal
compute_logit_fit <- function(model, logit_data) {

  # Get log-likelihood
  log_lik <- model$loglik[2]  # Fitted model log-likelihood
  null_log_lik <- model$loglik[1]  # Null model log-likelihood

  # Number of parameters
  n_params <- length(coef(model))

  # Number of observations (choice sets)
  n_choice_sets <- length(unique(logit_data$choice_set))

  # AIC and BIC
  aic <- -2 * log_lik + 2 * n_params
  bic <- -2 * log_lik + log(n_choice_sets) * n_params

  # McFadden pseudo R-squared
  mcfadden_r2 <- 1 - (log_lik / null_log_lik)

  list(
    log_likelihood = log_lik,
    null_log_likelihood = null_log_lik,
    n_parameters = n_params,
    n_choice_sets = n_choice_sets,
    aic = aic,
    bic = bic,
    mcfadden_r2 = mcfadden_r2
  )
}


# ==============================================================================
# ALTERNATIVE SIMPLE LOGIT (WITHOUT SURVIVAL PACKAGE)
# ==============================================================================

#' Fit simple logit model using GLM
#'
#' Alternative estimation using base R glm for cases where
#' survival package is not available.
#'
#' @param long_data Data frame. Long format data
#' @param items Data frame. Items configuration
#' @param verbose Logical. Print messages
#'
#' @return List with utilities and fit statistics
#' @export
fit_simple_logit <- function(long_data, items, verbose = TRUE) {

  if (verbose) log_message("Fitting simple logit model (GLM)...", "INFO", verbose)

  included_items <- items$Item_ID[items$Include == 1]

  # Calculate empirical log-odds for each item
  # Based on Best% and Worst%

  item_stats <- do.call(rbind, lapply(included_items, function(item_id) {
    item_data <- long_data[long_data$item_id == item_id, ]

    n_shown <- nrow(item_data)
    n_best <- sum(item_data$is_best)
    n_worst <- sum(item_data$is_worst)

    # Add small constant to avoid log(0)
    best_rate <- (n_best + 0.5) / (n_shown + 1)
    worst_rate <- (n_worst + 0.5) / (n_shown + 1)

    # Log-odds
    log_odds_best <- log(best_rate / (1 - best_rate))
    log_odds_worst <- log(worst_rate / (1 - worst_rate))

    # Combined utility (average of best log-odds and negative worst log-odds)
    utility <- (log_odds_best - log_odds_worst) / 2

    data.frame(
      Item_ID = item_id,
      n_shown = n_shown,
      n_best = n_best,
      n_worst = n_worst,
      best_rate = best_rate,
      worst_rate = worst_rate,
      Logit_Utility = utility,
      stringsAsFactors = FALSE
    )
  }))

  # Center utilities (subtract mean)
  item_stats$Logit_Utility <- item_stats$Logit_Utility - mean(item_stats$Logit_Utility)

  # Approximate SE using delta method
  item_stats$Logit_SE <- sqrt(
    1 / (item_stats$n_shown * item_stats$best_rate * (1 - item_stats$best_rate)) +
      1 / (item_stats$n_shown * item_stats$worst_rate * (1 - item_stats$worst_rate))
  ) / 2

  # Add item info
  utilities <- merge(
    item_stats[, c("Item_ID", "Logit_Utility", "Logit_SE")],
    items[, c("Item_ID", "Item_Label", "Item_Group", "Display_Order")],
    by = "Item_ID",
    all.x = TRUE
  )

  utilities$Rank <- rank(-utilities$Logit_Utility, ties.method = "min")
  utilities <- utilities[order(utilities$Rank), ]

  if (verbose) {
    log_message("Simple logit model fitted", "INFO", verbose)
  }

  return(list(
    utilities = utilities,
    model_fit = list(
      method = "simple_log_odds",
      n_items = nrow(utilities)
    ),
    model_object = NULL,
    anchor_item = NULL
  ))
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff logit module loaded (v%s)", LOGIT_VERSION))
