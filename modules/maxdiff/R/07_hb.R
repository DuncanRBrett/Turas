# ==============================================================================
# MAXDIFF MODULE - HIERARCHICAL BAYES ESTIMATION - TURAS V10.0
# ==============================================================================
# Hierarchical Bayes model for individual-level utility estimation
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# MODEL:
# beta_n ~ MVN(mu, Sigma)  - Individual utilities
# mu ~ MVN(0, 100*I)       - Population mean prior
# Sigma ~ LKJ(2) * half-t(3) - Correlation and scale priors
#
# DEPENDENCIES:
# - cmdstanr (for Stan interface)
# - utils.R
# ==============================================================================

HB_VERSION <- "10.0"

# ==============================================================================
# MAIN HB ESTIMATOR
# ==============================================================================

#' Fit Hierarchical Bayes Model
#'
#' Fits HB model to MaxDiff data using Stan for MCMC sampling.
#' Estimates individual-level utilities for each respondent.
#'
#' @param long_data Data frame. Long format MaxDiff data
#' @param items Data frame. Items configuration
#' @param config List. Configuration object with HB settings
#' @param verbose Logical. Print progress messages
#'
#' @return List containing:
#'   - population_utilities: Population-level utility means and SDs
#'   - individual_utilities: Respondent-level utilities
#'   - diagnostics: MCMC diagnostics
#'   - model_fit: Model fit statistics
#'
#' @export
fit_hb_model <- function(long_data, items, config, verbose = TRUE) {

  if (verbose) {
    cat("\n")
    log_message("FITTING HIERARCHICAL BAYES MODEL", "INFO", verbose)
    cat(paste(rep("-", 60), collapse = ""), "\n")
  }

  # Check for cmdstanr
  has_cmdstanr <- requireNamespace("cmdstanr", quietly = TRUE)

  if (!has_cmdstanr) {
    # TRS INFO: Optional package not available, using fallback
    message("[TRS INFO] cmdstanr package not available - using approximate HB method instead")
    message("[TRS INFO] For full HB estimation, install cmdstanr: https://mc-stan.org/cmdstanr/")
    return(fit_approximate_hb(long_data, items, config, verbose))
  }

  # Get HB settings
  output_settings <- config$output_settings
  n_iter <- output_settings$HB_Iterations
  n_warmup <- output_settings$HB_Warmup
  n_chains <- output_settings$HB_Chains
  seed <- config$project_settings$Seed

  if (verbose) {
    log_message(sprintf("Iterations: %d (warmup: %d)", n_iter, n_warmup), "INFO", verbose)
    log_message(sprintf("Chains: %d", n_chains), "INFO", verbose)
  }

  # Prepare Stan data
  stan_data <- prepare_stan_data(long_data, items)

  if (verbose) {
    log_message(sprintf(
      "Stan data: %d respondents, %d items, %d observations",
      stan_data$R, stan_data$J, stan_data$N
    ), "INFO", verbose)
  }

  # Get Stan model path
  stan_model_path <- get_stan_model_path()

  # Compile model
  if (verbose) log_message("Compiling Stan model...", "INFO", verbose)

  stan_model <- tryCatch({
    cmdstanr::cmdstan_model(stan_model_path)
  }, error = function(e) {
    message(sprintf(
      "[TRS INFO] MAXD_STAN_COMPILE_FAILED: Stan model compilation failed: %s - using approximate method",
      conditionMessage(e)
    ))
    return(NULL)
  })

  if (is.null(stan_model)) {
    return(fit_approximate_hb(long_data, items, config, verbose))
  }

  # Run MCMC
  if (verbose) log_message("Running MCMC sampling...", "INFO", verbose)

  fit <- tryCatch({
    stan_model$sample(
      data = stan_data,
      seed = seed,
      chains = n_chains,
      parallel_chains = min(n_chains, parallel::detectCores() - 1),
      iter_warmup = n_warmup,
      iter_sampling = n_iter,
      refresh = if (verbose) 500 else 0,
      show_messages = verbose
    )
  }, error = function(e) {
    message(sprintf(
      "[TRS PARTIAL] MAXD_MCMC_FAILED: MCMC sampling failed: %s - using approximate method",
      conditionMessage(e)
    ))
    return(NULL)
  })

  if (is.null(fit)) {
    return(fit_approximate_hb(long_data, items, config, verbose))
  }

  # Extract results
  results <- extract_hb_results(fit, stan_data, items, verbose)

  if (verbose) {
    log_message("HB model estimation complete", "INFO", verbose)
  }

  return(results)
}


# ==============================================================================
# STAN DATA PREPARATION
# ==============================================================================

#' Prepare data for Stan model
#'
#' @param long_data Data frame. Long format data
#' @param items Data frame. Items configuration
#'
#' @return List of Stan data
#' @keywords internal
prepare_stan_data <- function(long_data, items) {

  # Get included items
  included_items <- items$Item_ID[items$Include == 1]
  J <- length(included_items)

  # Create item index mapping
  item_to_idx <- setNames(seq_along(included_items), included_items)

  # Get anchor item
  anchor_idx <- which(items$Anchor_Item == 1 & items$Include == 1)
  if (length(anchor_idx) > 0) {
    anchor_item <- items$Item_ID[anchor_idx[1]]
    anchor_item_idx <- item_to_idx[anchor_item]
  } else {
    anchor_item_idx <- J  # Use last item as anchor
  }

  # Get unique respondents and create index
  respondents <- unique(long_data$resp_id)
  R <- length(respondents)
  resp_to_idx <- setNames(seq_along(respondents), respondents)

  # Get unique tasks (choices) where we have both best and worst
  tasks <- unique(long_data[, c("resp_id", "version", "task")])

  # Build observation data
  obs_list <- list()
  items_per_task <- NULL

  for (i in seq_len(nrow(tasks))) {
    resp_id <- tasks$resp_id[i]
    version <- tasks$version[i]
    task <- tasks$task[i]

    task_data <- long_data[
      long_data$resp_id == resp_id &
        long_data$version == version &
        long_data$task == task,
    ]

    # Get items shown
    items_shown <- task_data$item_id
    K <- length(items_shown)

    if (is.null(items_per_task)) {
      items_per_task <- K
    }

    # Get choices
    best_item <- task_data$item_id[task_data$is_best == 1]
    worst_item <- task_data$item_id[task_data$is_worst == 1]

    if (length(best_item) != 1 || length(worst_item) != 1) next

    # Convert to indices
    resp_idx <- resp_to_idx[as.character(resp_id)]
    shown_idx <- item_to_idx[items_shown]
    best_idx <- which(items_shown == best_item)
    worst_idx <- which(items_shown == worst_item)

    # BEST choice observation
    obs_list[[length(obs_list) + 1]] <- list(
      resp = resp_idx,
      choice = best_idx,
      shown = shown_idx,
      is_best = 1L
    )

    # WORST choice observation
    obs_list[[length(obs_list) + 1]] <- list(
      resp = resp_idx,
      choice = worst_idx,
      shown = shown_idx,
      is_best = 0L
    )
  }

  N <- length(obs_list)
  K <- items_per_task

  # Build arrays
  resp_array <- integer(N)
  choice_array <- integer(N)
  shown_matrix <- matrix(0L, nrow = N, ncol = K)
  is_best_array <- integer(N)

  for (i in seq_along(obs_list)) {
    obs <- obs_list[[i]]
    resp_array[i] <- obs$resp
    choice_array[i] <- obs$choice
    shown_matrix[i, ] <- obs$shown
    is_best_array[i] <- obs$is_best
  }

  list(
    N = N,
    R = R,
    J = J,
    K = K,
    resp = resp_array,
    choice = choice_array,
    shown = shown_matrix,
    is_best = is_best_array,
    anchor_item = anchor_item_idx,
    item_ids = included_items,
    resp_ids = respondents
  )
}


#' Get path to Stan model file
#'
#' @return Character path to Stan model
#' @keywords internal
get_stan_model_path <- function() {

  # Look for Stan file in module directory
  possible_paths <- c(
    "stan/maxdiff_hb.stan",
    "../stan/maxdiff_hb.stan",
    "modules/maxdiff/stan/maxdiff_hb.stan",
    file.path(Sys.getenv("TURAS_ROOT"), "modules/maxdiff/stan/maxdiff_hb.stan")
  )

  for (path in possible_paths) {
    if (file.exists(path)) {
      return(normalizePath(path))
    }
  }

  stop(
    "Stan model file not found. Expected at:\n  ",
    paste(possible_paths, collapse = "\n  "),
    call. = FALSE
  )
}


# ==============================================================================
# RESULTS EXTRACTION
# ==============================================================================

#' Extract results from fitted HB model
#'
#' @param fit CmdStanMCMC object
#' @param stan_data Stan data list
#' @param items Items data frame
#' @param verbose Logical
#'
#' @return List with population and individual utilities
#' @keywords internal
extract_hb_results <- function(fit, stan_data, items, verbose = TRUE) {

  if (verbose) log_message("Extracting HB results...", "INFO", verbose)

  # Get summary
  summary_df <- fit$summary()

  # Population means (mu)
  mu_vars <- paste0("mu[", seq_len(stan_data$J), "]")
  mu_summary <- summary_df[summary_df$variable %in% mu_vars, ]

  # Build population utilities data frame
  population_utilities <- data.frame(
    Item_ID = stan_data$item_ids,
    HB_Utility_Mean = mu_summary$mean,
    HB_Utility_SD = mu_summary$sd,
    HB_Utility_Q5 = mu_summary$q5,
    HB_Utility_Q95 = mu_summary$q95,
    HB_Rhat = mu_summary$rhat,
    HB_ESS = mu_summary$ess_bulk,
    stringsAsFactors = FALSE
  )

  # Add item info
  population_utilities <- merge(
    population_utilities,
    items[, c("Item_ID", "Item_Label", "Item_Group", "Display_Order")],
    by = "Item_ID",
    all.x = TRUE
  )

  population_utilities$Rank <- rank(-population_utilities$HB_Utility_Mean,
                                    ties.method = "min")

  # Individual utilities (beta)
  # Extract draws for each respondent-item combination
  draws <- fit$draws(format = "df")

  individual_utilities <- extract_individual_utilities(
    draws, stan_data$R, stan_data$J,
    stan_data$item_ids, stan_data$resp_ids
  )

  # Diagnostics
  diagnostics <- list(
    n_divergences = sum(fit$sampler_diagnostics()[, "divergent__"]),
    max_treedepth_exceeded = sum(fit$sampler_diagnostics()[, "treedepth__"] >= 10),
    mean_rhat = mean(mu_summary$rhat, na.rm = TRUE),
    min_ess = min(mu_summary$ess_bulk, na.rm = TRUE)
  )

  if (verbose) {
    log_message(sprintf(
      "Diagnostics: %d divergences, mean Rhat = %.3f, min ESS = %.0f",
      diagnostics$n_divergences,
      diagnostics$mean_rhat,
      diagnostics$min_ess
    ), "INFO", verbose)

    if (diagnostics$n_divergences > 0) {
      log_message("WARNING: Divergent transitions detected", "WARN", verbose)
    }
  }

  list(
    population_utilities = population_utilities,
    individual_utilities = individual_utilities,
    diagnostics = diagnostics,
    model_fit = list(
      method = "cmdstanr",
      n_iter = fit$metadata()$iter_sampling,
      n_chains = fit$num_chains()
    )
  )
}


#' Extract individual-level utilities from draws
#'
#' @keywords internal
extract_individual_utilities <- function(draws, R, J, item_ids, resp_ids) {

  # Get column names for beta parameters
  beta_cols <- grep("^beta\\[", names(draws), value = TRUE)

  # Calculate posterior means for each respondent-item combination
  results <- list()

  for (r in seq_len(R)) {
    resp_utilities <- numeric(J)

    for (j in seq_len(J)) {
      col_name <- sprintf("beta[%d,%d]", r, j)
      if (col_name %in% beta_cols) {
        resp_utilities[j] <- mean(draws[[col_name]], na.rm = TRUE)
      }
    }

    results[[r]] <- data.frame(
      resp_id = resp_ids[r],
      t(resp_utilities),
      stringsAsFactors = FALSE
    )
    names(results[[r]])[-1] <- item_ids
  }

  do.call(rbind, results)
}


# ==============================================================================
# APPROXIMATE HB METHOD
# ==============================================================================

#' Fit approximate HB using empirical Bayes
#'
#' Used when cmdstanr is not available. Uses empirical Bayes
#' shrinkage based on respondent-level scores.
#'
#' @param long_data Data frame. Long format data
#' @param items Data frame. Items configuration
#' @param config List. Configuration object
#' @param verbose Logical. Print messages
#'
#' @return List with utilities (same structure as fit_hb_model)
#' @export
fit_approximate_hb <- function(long_data, items, config, verbose = TRUE) {

  if (verbose) log_message("Using approximate HB method (empirical Bayes)...", "INFO", verbose)

  included_items <- items$Item_ID[items$Include == 1]
  respondents <- unique(long_data$resp_id)
  n_resp <- length(respondents)
  n_items <- length(included_items)

  # Calculate respondent-level BW scores
  resp_scores <- compute_respondent_counts(long_data, items, verbose = FALSE)

  # Pivot to wide format
  resp_wide <- reshape(
    resp_scores[, c("resp_id", "item_id", "bw_score")],
    idvar = "resp_id",
    timevar = "item_id",
    direction = "wide"
  )
  names(resp_wide) <- gsub("bw_score\\.", "", names(resp_wide))

  # Calculate population mean and variance
  pop_mean <- colMeans(resp_wide[, -1], na.rm = TRUE)
  pop_var <- apply(resp_wide[, -1], 2, var, na.rm = TRUE)

  # Estimate individual variance (within-respondent noise)
  # Use average across items
  within_var <- mean(pop_var, na.rm = TRUE) / n_resp

  # Shrinkage factor (James-Stein type)
  shrinkage <- pop_var / (pop_var + within_var)

  # Apply shrinkage to individual scores
  individual_utilities <- resp_wide
  for (col in included_items) {
    if (col %in% names(individual_utilities)) {
      individual_utilities[[col]] <- pop_mean[col] +
        shrinkage[col] * (individual_utilities[[col]] - pop_mean[col])
    }
  }

  # Population utilities
  population_utilities <- data.frame(
    Item_ID = included_items,
    HB_Utility_Mean = pop_mean[included_items],
    HB_Utility_SD = sqrt(pop_var[included_items]),
    HB_Utility_Q5 = pop_mean[included_items] - 1.645 * sqrt(pop_var[included_items]),
    HB_Utility_Q95 = pop_mean[included_items] + 1.645 * sqrt(pop_var[included_items]),
    HB_Rhat = NA_real_,
    HB_ESS = NA_real_,
    stringsAsFactors = FALSE
  )

  # Add item info
  population_utilities <- merge(
    population_utilities,
    items[, c("Item_ID", "Item_Label", "Item_Group", "Display_Order")],
    by = "Item_ID",
    all.x = TRUE
  )

  population_utilities$Rank <- rank(-population_utilities$HB_Utility_Mean,
                                    ties.method = "min")

  if (verbose) {
    log_message("Approximate HB complete", "INFO", verbose)
  }

  list(
    population_utilities = population_utilities,
    individual_utilities = individual_utilities,
    diagnostics = list(
      method = "empirical_bayes",
      shrinkage_mean = mean(shrinkage, na.rm = TRUE)
    ),
    model_fit = list(
      method = "empirical_bayes_shrinkage",
      n_respondents = n_resp,
      n_items = n_items
    )
  )
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff HB module loaded (v%s)", HB_VERSION))
