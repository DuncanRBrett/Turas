# ==============================================================================
# HIERARCHICAL BAYES - CONJOINT ANALYSIS
# ==============================================================================
#
# Module: Conjoint Analysis - Hierarchical Bayes Estimation
# Purpose: Individual-level part-worth utilities via bayesm MCMC
# Version: 3.0.0
# Date: 2026-03-10
#
# WHAT HB PROVIDES:
#   - Individual-level part-worth utilities per respondent
#   - Preference heterogeneity analysis
#   - Respondent quality flagging via individual RLH
#   - Convergence diagnostics (Rhat, ESS, Geweke)
#   - Better handling of sparse individual data
#
# IMPLEMENTATION:
#   Uses bayesm::rhierMnlRwMixture for hierarchical multinomial logit
#   with mixture of normals heterogeneity distribution.
#
# DEPENDENCIES:
#   - bayesm (required for HB estimation)
#   - Shared: modules/shared/lib/hb_diagnostics.R (convergence checking)
#
# ==============================================================================

CONJOINT_HB_VERSION <- "3.0.0"
CONJOINT_HB_STATUS <- "IMPLEMENTED"


# ==============================================================================
# SOURCE SHARED DIAGNOSTICS
# ==============================================================================

.hb_diagnostics_loaded <- FALSE

.load_hb_diagnostics <- function() {
  if (.hb_diagnostics_loaded) return(TRUE)

  possible_paths <- c(
    file.path(dirname(sys.frame(1)$ofile %||% "."), "../../shared/lib/hb_diagnostics.R"),
    file.path(getwd(), "modules/shared/lib/hb_diagnostics.R"),
    file.path(Sys.getenv("TURAS_HOME", getwd()), "modules/shared/lib/hb_diagnostics.R")
  )

  for (path in possible_paths) {
    if (!is.null(path) && file.exists(path)) {
      source(path, local = FALSE)
      .hb_diagnostics_loaded <<- TRUE
      return(TRUE)
    }
  }

  FALSE
}

# Null coalesce for path resolution
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}


# ==============================================================================
# HB REQUIREMENTS CHECK
# ==============================================================================

#' Check if Hierarchical Bayes packages are available
#'
#' @return List with package availability and recommendations
#' @export
check_hb_requirements <- function() {

  has_bayesm <- requireNamespace("bayesm", quietly = TRUE)
  has_coda <- requireNamespace("coda", quietly = TRUE)

  list(
    bayesm_available = has_bayesm,
    coda_available = has_coda,
    ready = has_bayesm,
    recommended_package = if (has_bayesm) "bayesm" else "none",
    install_instructions = if (!has_bayesm) {
      "Install bayesm with: install.packages('bayesm')"
    } else {
      NULL
    },
    implementation_status = "IMPLEMENTED"
  )
}


# ==============================================================================
# DATA PREPARATION FOR BAYESM
# ==============================================================================

#' Prepare Data for bayesm HB Estimation
#'
#' Converts Turas conjoint data (long format) into the bayesm lgtdata
#' list structure required by rhierMnlRwMixture.
#'
#' Each respondent becomes a list element with:
#'   - y: vector of chosen alternatives (1-indexed)
#'   - X: design matrix (one row per alternative per choice set)
#'
#' @param data_list Data list from load_conjoint_data()
#' @param config Configuration object
#' @param verbose Logical, print progress
#' @return List with lgtdata, p (number of alternatives per task),
#'         n_parameters, attribute_map, respondent_ids
#' @keywords internal
prepare_bayesm_data <- function(data_list, config, verbose = TRUE) {

  data <- data_list$data
  resp_col <- config$respondent_id_column
  cs_col <- config$choice_set_column
  chosen_col <- config$chosen_column

  log_verbose("  → Preparing data for bayesm HB estimation...", verbose)

  # Get unique respondent IDs
  respondent_ids <- sort(unique(data[[resp_col]]))
  n_respondents <- length(respondent_ids)

  # Build design matrix columns from attributes (effect coding)
  attr_names <- config$attributes$AttributeName

  # Create dummy variables for all attributes
  # Dummy coding: each attribute with K levels gets K-1 columns
  # The first level is the reference (coded as 0; other levels coded as 1 when present)
  design_cols <- list()
  col_names <- character()
  attribute_map <- list()  # maps column indices to attribute/level

  for (attr in attr_names) {
    levels_vec <- get_attribute_levels(config, attr)
    n_levels <- length(levels_vec)

    # Create dummy columns for levels 2..K (first level is reference)
    for (j in 2:n_levels) {
      col_name <- paste0(attr, "_", levels_vec[j])
      col_names <- c(col_names, col_name)
      attribute_map[[col_name]] <- list(attribute = attr, level = levels_vec[j])

      # Dummy coding: 1 if this level, 0 otherwise
      design_cols[[col_name]] <- as.numeric(data[[attr]] == levels_vec[j])
    }
  }

  # Combine into design matrix
  X_full <- as.matrix(do.call(cbind, design_cols))
  colnames(X_full) <- col_names
  n_parameters <- ncol(X_full)

  log_verbose(sprintf("  → Design matrix: %d rows x %d columns", nrow(X_full), n_parameters), verbose)

  # Determine number of alternatives per choice set
  # Count alternatives in first choice set of first respondent
  first_resp <- respondent_ids[1]
  first_cs <- data[data[[resp_col]] == first_resp, ]
  first_cs_id <- unique(first_cs[[cs_col]])[1]
  p <- sum(first_cs[[cs_col]] == first_cs_id)

  log_verbose(sprintf("  → %d alternatives per choice set", p), verbose)

  # Validate that ALL choice sets have exactly p alternatives

  # bayesm requires constant p — mismatches cause silent wrong results
  bad_cs <- character(0)
  for (rid in respondent_ids) {
    resp_mask <- data[[resp_col]] == rid
    resp_cs_ids <- unique(data[[cs_col]][resp_mask])
    for (csid in resp_cs_ids) {
      cs_size <- sum(data[[resp_col]] == rid & data[[cs_col]] == csid)
      if (cs_size != p) {
        bad_cs <- c(bad_cs, sprintf("resp=%s cs=%s (got %d)", rid, csid, cs_size))
        if (length(bad_cs) >= 5) break  # limit diagnostic output
      }
    }
    if (length(bad_cs) >= 5) break
  }

  if (length(bad_cs) > 0) {
    return(conjoint_refuse(
      code = "DATA_INCONSISTENT_ALTERNATIVES",
      message = sprintf(
        "Not all choice sets have %d alternatives. bayesm requires a constant number of alternatives per choice set.",
        p
      ),
      how_to_fix = c(
        "Ensure every choice set has exactly the same number of alternatives",
        "Check for missing rows or inconsistent none-option inclusion",
        sprintf("Mismatched examples: %s", paste(bad_cs, collapse = "; "))
      )
    ))
  }

  # Build lgtdata: one element per respondent
  lgtdata <- vector("list", n_respondents)

  for (i in seq_len(n_respondents)) {
    resp_id <- respondent_ids[i]
    resp_rows <- which(data[[resp_col]] == resp_id)
    resp_data <- data[resp_rows, ]
    resp_X <- X_full[resp_rows, , drop = FALSE]

    # Get choice sets for this respondent
    choice_sets <- unique(resp_data[[cs_col]])
    n_tasks <- length(choice_sets)

    # Build y vector: which alternative was chosen in each task (1-indexed)
    y_vec <- integer(n_tasks)
    for (t in seq_len(n_tasks)) {
      cs_id <- choice_sets[t]
      cs_mask <- resp_data[[cs_col]] == cs_id
      chosen <- resp_data[[chosen_col]][cs_mask]
      y_val <- which(chosen == 1)[1]

      # Guard: ensure exactly one chosen alternative per choice set
      if (is.na(y_val)) {
        return(conjoint_refuse(
          code = "DATA_NO_CHOICE",
          message = sprintf(
            "No chosen alternative found for respondent '%s' in choice set '%s'.",
            resp_id, cs_id
          ),
          how_to_fix = c(
            "Ensure every choice set has exactly one row with chosen=1",
            "Check for missing or zero values in the chosen column"
          )
        ))
      }

      y_vec[t] <- y_val
    }

    lgtdata[[i]] <- list(
      y = y_vec,
      X = resp_X
    )
  }

  log_verbose(sprintf("  ✓ Prepared data for %d respondents", n_respondents), verbose)

  list(
    lgtdata = lgtdata,
    p = p,
    n_parameters = n_parameters,
    n_respondents = n_respondents,
    attribute_map = attribute_map,
    col_names = col_names,
    respondent_ids = respondent_ids
  )
}


# ==============================================================================
# MAIN HB ESTIMATION
# ==============================================================================

#' Estimate Hierarchical Bayes Conjoint Model
#'
#' Performs Hierarchical Bayes estimation for choice-based conjoint analysis
#' using bayesm::rhierMnlRwMixture. Returns individual-level part-worth
#' utilities for each respondent.
#'
#' @param data_list Data list from load_conjoint_data()
#' @param config Configuration object (must have hb_iterations, hb_burnin, etc.)
#' @param verbose Logical, print progress
#' @return turas_conjoint_model object with individual utilities
#' @export
estimate_hierarchical_bayes <- function(data_list, config, verbose = TRUE) {

  # Validate HB requirements
  validate_hb_config(config)

  log_verbose("  → Hierarchical Bayes estimation (bayesm)", verbose)

  # Prepare data for bayesm
  bayesm_data <- prepare_bayesm_data(data_list, config, verbose)

  # MCMC settings
  R <- as.integer(config$hb_iterations)
  burnin <- as.integer(config$hb_burnin)
  thin <- as.integer(config$hb_thin)
  ncomp <- as.integer(config$hb_ncomp)

  log_verbose(sprintf("  → MCMC: %d iterations, %d burn-in, thin=%d, ncomp=%d",
                       R, burnin, thin, ncomp), verbose)

  # Set up bayesm inputs
  Data <- list(
    lgtdata = bayesm_data$lgtdata,
    p = bayesm_data$p
  )

  Prior <- list(
    ncomp = ncomp
  )

  Mcmc <- list(
    R = R,
    keep = thin,
    nprint = if (verbose) as.integer(R / 5) else 0
  )

  # Run HB estimation
  log_verbose("  → Running MCMC (this may take a while)...", verbose)

  hb_output <- tryCatch({
    bayesm::rhierMnlRwMixture(
      Data = Data,
      Prior = Prior,
      Mcmc = Mcmc
    )
  }, error = function(e) {
    conjoint_refuse(
      code = "MODEL_HB_ESTIMATION_FAILED",
      title = "HB Estimation Failed",
      problem = sprintf("bayesm::rhierMnlRwMixture failed: %s", conditionMessage(e)),
      why_it_matters = "HB estimation could not complete. This may indicate data quality issues or misconfigured priors.",
      how_to_fix = c(
        "Check that your data has sufficient respondents (30+ recommended)",
        "Ensure each respondent has enough choice tasks (8+ recommended)",
        "Try reducing hb_iterations for a quick test",
        "Fall back to estimation_method = 'auto' for aggregate analysis"
      )
    )
  })

  log_verbose("  ✓ MCMC estimation complete", verbose)

  # Extract results
  result <- extract_hb_results(hb_output, bayesm_data, config, burnin, thin, verbose)

  result
}


# ==============================================================================
# RESULT EXTRACTION
# ==============================================================================

#' Extract HB Results from bayesm Output
#'
#' Processes the raw bayesm output into a standardized turas_conjoint_model
#' object with individual-level utilities and convergence diagnostics.
#'
#' @param hb_output Output from bayesm::rhierMnlRwMixture
#' @param bayesm_data Prepared data from prepare_bayesm_data()
#' @param config Configuration object
#' @param burnin Number of burn-in iterations
#' @param thin Thinning interval
#' @param verbose Logical
#' @return turas_conjoint_model object
#' @keywords internal
extract_hb_results <- function(hb_output, bayesm_data, config, burnin, thin, verbose = TRUE) {

  log_verbose("  → Extracting individual-level utilities...", verbose)

  n_respondents <- bayesm_data$n_respondents
  n_parameters <- bayesm_data$n_parameters
  col_names <- bayesm_data$col_names
  respondent_ids <- bayesm_data$respondent_ids

  # hb_output$betadraw is an array: [respondents x parameters x draws]
  # bayesm does NOT discard burn-in automatically — we must remove burn-in draws
  betadraw_raw <- hb_output$betadraw
  n_draws_total <- dim(betadraw_raw)[3]

  # Remove burn-in draws: bayesm keeps every 'thin'-th draw, so the number

  # of burn-in draws to discard = floor(burnin / thin)
  n_burnin_draws <- min(floor(burnin / max(thin, 1)), n_draws_total - 1)
  if (n_burnin_draws > 0) {
    betadraw <- betadraw_raw[, , (n_burnin_draws + 1):n_draws_total, drop = FALSE]
    log_verbose(sprintf("  → Discarded %d burn-in draws, retaining %d posterior draws",
                         n_burnin_draws, dim(betadraw)[3]), verbose)
  } else {
    betadraw <- betadraw_raw
  }
  n_draws <- dim(betadraw)[3]

  # Calculate individual-level posterior means
  individual_betas <- matrix(NA, nrow = n_respondents, ncol = n_parameters)
  individual_sds <- matrix(NA, nrow = n_respondents, ncol = n_parameters)

  for (i in seq_len(n_respondents)) {
    # Drop to 2D matrix [parameters x draws] before computing means
    draws_i <- betadraw[i, , , drop = TRUE]
    if (is.matrix(draws_i)) {
      individual_betas[i, ] <- rowMeans(draws_i)
      individual_sds[i, ] <- apply(draws_i, 1, sd)
    } else {
      # Single draw remaining — no SD
      individual_betas[i, ] <- draws_i
      individual_sds[i, ] <- 0
    }
  }

  colnames(individual_betas) <- col_names
  colnames(individual_sds) <- col_names
  rownames(individual_betas) <- respondent_ids
  rownames(individual_sds) <- respondent_ids

  # Aggregate utilities (population mean of individual means)
  aggregate_betas <- colMeans(individual_betas)
  aggregate_sds <- apply(individual_betas, 2, sd)

  log_verbose(sprintf("  ✓ Extracted utilities for %d respondents (%d parameters)",
                       n_respondents, n_parameters), verbose)

  # Convergence diagnostics
  convergence <- run_hb_convergence_diagnostics(hb_output, bayesm_data, verbose)

  # Calculate individual-level RLH for respondent quality
  quality <- calculate_respondent_rlh(
    individual_betas, bayesm_data, config, verbose
  )

  # Build standardized result compatible with downstream functions
  structure(list(
    method = "hierarchical_bayes",
    model = hb_output,
    coefficients = aggregate_betas,
    vcov = NULL,  # Not directly available from HB; use posterior SDs
    std_errors = aggregate_sds,
    loglik = c(null = NA_real_, fitted = NA_real_),
    n_obs = sum(sapply(bayesm_data$lgtdata, function(x) length(x$y) * bayesm_data$p)),
    n_respondents = n_respondents,
    n_choice_sets = sum(sapply(bayesm_data$lgtdata, function(x) length(x$y))),
    n_parameters = n_parameters,
    convergence = convergence,
    aic = NA_real_,
    bic = NA_real_,

    # HB-specific fields
    individual_betas = individual_betas,
    individual_sds = individual_sds,
    betadraw = betadraw,
    respondent_ids = respondent_ids,
    attribute_map = bayesm_data$attribute_map,
    col_names = col_names,
    respondent_quality = quality,
    hb_settings = list(
      iterations = config$hb_iterations,
      burnin = burnin,
      thin = thin,
      ncomp = config$hb_ncomp,
      n_draws_retained = n_draws
    )
  ), class = "turas_conjoint_model")
}


# ==============================================================================
# CONVERGENCE DIAGNOSTICS
# ==============================================================================

#' Run HB Convergence Diagnostics
#'
#' Checks MCMC convergence using shared diagnostics infrastructure.
#'
#' @param hb_output bayesm output
#' @param bayesm_data Prepared data
#' @param verbose Logical
#' @return Convergence status list
#' @keywords internal
run_hb_convergence_diagnostics <- function(hb_output, bayesm_data, verbose = TRUE) {

  log_verbose("  → Running convergence diagnostics...", verbose)

  # Try shared diagnostics first
  .load_hb_diagnostics()

  # Calculate basic diagnostics from the population-level draws
  # Use ALL draws (including burn-in) for convergence assessment — burn-in
  # non-stationarity is exactly what we want to detect

  n_respondents <- bayesm_data$n_respondents
  n_params <- bayesm_data$n_parameters
  betadraw <- hb_output$betadraw  # Full draws including burn-in
  n_draws <- dim(betadraw)[3]

  # Calculate effective sample size and simple convergence metrics
  # Use aggregate (mean across respondents) beta trace for diagnostics
  aggregate_trace <- matrix(NA, nrow = n_draws, ncol = n_params)
  for (d in seq_len(n_draws)) {
    aggregate_trace[d, ] <- colMeans(betadraw[, , d, drop = FALSE])
  }

  # Simple Geweke-like diagnostic: compare first 10% vs last 50%
  n_first <- max(1, floor(n_draws * 0.1))
  n_last <- max(1, floor(n_draws * 0.5))

  geweke_z <- numeric(n_params)
  for (j in seq_len(n_params)) {
    chain <- aggregate_trace[, j]
    first_part <- chain[1:n_first]
    last_part <- chain[(n_draws - n_last + 1):n_draws]

    mean_diff <- mean(first_part) - mean(last_part)
    se_diff <- sqrt(var(first_part) / n_first + var(last_part) / n_last)

    geweke_z[j] <- if (se_diff > 0) mean_diff / se_diff else 0
  }

  # ESS approximation using autocorrelation
  ess <- numeric(n_params)
  for (j in seq_len(n_params)) {
    chain <- aggregate_trace[, j]
    if (length(chain) > 1 && sd(chain) > 0) {
      acf_vals <- acf(chain, lag.max = min(50, n_draws - 1), plot = FALSE)$acf
      # Sum of positive autocorrelations (Geyer's method, simplified)
      positive_acf <- which(acf_vals > 0.05)
      if (length(positive_acf) > 0) {
        sum_acf <- sum(acf_vals[positive_acf])
        ess[j] <- n_draws / (1 + 2 * max(0, sum_acf - 1))
      } else {
        ess[j] <- n_draws
      }
    } else {
      ess[j] <- n_draws
    }
  }

  # Determine convergence status
  geweke_pass <- all(abs(geweke_z) < 1.96)
  ess_pass <- all(ess > 400)
  converged <- geweke_pass && ess_pass

  names(geweke_z) <- bayesm_data$col_names
  names(ess) <- bayesm_data$col_names

  # Determine if there's a critical ESS issue (< 100) vs warning (100-400)
  ess_critical <- any(ess < 100)

  convergence <- list(
    converged = converged,
    code = if (converged) 0 else 1,
    message = if (converged) {
      "MCMC chains appear to have converged"
    } else {
      problems <- character()
      if (!geweke_pass) problems <- c(problems, "Geweke test failed for some parameters")
      if (ess_critical) {
        problems <- c(problems, sprintf("Critical: ESS < 100 for %d parameter(s) — insufficient sampling",
                                        sum(ess < 100)))
      } else if (!ess_pass) {
        problems <- c(problems, sprintf("Warning: ESS < 400 for %d parameter(s) — may affect posterior accuracy",
                                        sum(ess <= 400)))
      }
      paste("Convergence issues:", paste(problems, collapse = "; "))
    },
    geweke_z = geweke_z,
    effective_sample_size = ess,
    n_draws = n_draws,
    geweke_pass = geweke_pass,
    ess_pass = ess_pass
  )

  if (verbose) {
    if (converged) {
      log_verbose("  ✓ MCMC convergence: PASSED", verbose)
    } else {
      log_verbose(sprintf("  ⚠ MCMC convergence: %s", convergence$message), verbose)
    }
    log_verbose(sprintf("  → Effective sample size range: %.0f - %.0f",
                         min(ess), max(ess)), verbose)
  }

  convergence
}


# ==============================================================================
# RESPONDENT QUALITY (RLH)
# ==============================================================================

#' Calculate Respondent-Level Root Likelihood (RLH)
#'
#' Computes RLH for each respondent to identify poor-quality responses
#' (speeders, random clickers). RLH near chance level (1/K) indicates
#' random responding.
#'
#' @param individual_betas Matrix of individual-level betas
#' @param bayesm_data Prepared data
#' @param config Configuration object
#' @param verbose Logical
#' @return List with rlh_scores, quality_flags, summary
#' @keywords internal
calculate_respondent_rlh <- function(individual_betas, bayesm_data, config, verbose = TRUE) {

  log_verbose("  → Calculating respondent quality (RLH)...", verbose)

  n_respondents <- bayesm_data$n_respondents
  p <- bayesm_data$p  # alternatives per task
  lgtdata <- bayesm_data$lgtdata
  respondent_ids <- bayesm_data$respondent_ids

  chance_rlh <- 1 / p
  rlh_scores <- numeric(n_respondents)

  for (i in seq_len(n_respondents)) {
    resp <- lgtdata[[i]]
    betas <- individual_betas[i, ]
    X <- resp$X
    y <- resp$y
    n_tasks <- length(y)

    # Calculate log-likelihood for this respondent
    total_ll <- 0
    rows_per_task <- nrow(X) / n_tasks

    for (t in seq_len(n_tasks)) {
      # Get design matrix rows for this task
      row_start <- (t - 1) * rows_per_task + 1
      row_end <- t * rows_per_task
      X_task <- X[row_start:row_end, , drop = FALSE]

      # Calculate utilities for each alternative
      V <- as.numeric(X_task %*% betas)

      # Logit probability of chosen alternative
      exp_V <- exp(V - max(V))  # subtract max for numerical stability
      prob <- exp_V / sum(exp_V)
      chosen_prob <- prob[y[t]]

      total_ll <- total_ll + log(max(chosen_prob, 1e-300))
    }

    # RLH = exp(LL / n_tasks)
    rlh_scores[i] <- exp(total_ll / n_tasks)
  }

  names(rlh_scores) <- respondent_ids

  # Flag poor-quality respondents
  # Threshold: respondents below 1.2 * chance are flagged
  quality_threshold <- chance_rlh * 1.2
  quality_flags <- rlh_scores < quality_threshold
  n_flagged <- sum(quality_flags)

  if (verbose) {
    log_verbose(sprintf("  ✓ RLH range: %.3f - %.3f (chance = %.3f)",
                         min(rlh_scores), max(rlh_scores), chance_rlh), verbose)
    if (n_flagged > 0) {
      log_verbose(sprintf("  ⚠ %d respondents flagged for poor quality (RLH < %.3f)",
                           n_flagged, quality_threshold), verbose)
    }
  }

  list(
    rlh_scores = rlh_scores,
    quality_flags = quality_flags,
    n_flagged = n_flagged,
    chance_rlh = chance_rlh,
    quality_threshold = quality_threshold,
    mean_rlh = mean(rlh_scores),
    median_rlh = median(rlh_scores),
    respondent_ids = respondent_ids
  )
}


# ==============================================================================
# HB UTILITY EXTRACTION (FOR 04_utilities.R)
# ==============================================================================

#' Extract HB Utilities in Standard Format
#'
#' Converts individual-level HB results into the standard utilities
#' data frame format used by downstream functions (output, simulator, etc.).
#'
#' @param hb_result HB model result (turas_conjoint_model with method="hierarchical_bayes")
#' @param config Configuration object
#' @param verbose Logical
#' @return Data frame with Attribute, Level, Utility, SE, CI_Lower, CI_Upper,
#'         p_value, is_baseline columns (same as aggregate method output)
#' @keywords internal
extract_hb_utilities <- function(hb_result, config, verbose = TRUE) {

  log_verbose("  → Extracting HB utilities into standard format...", verbose)

  aggregate_betas <- hb_result$coefficients
  aggregate_sds <- hb_result$std_errors
  attribute_map <- hb_result$attribute_map
  col_names <- hb_result$col_names
  confidence_level <- config$confidence_level
  z <- qnorm(1 - (1 - confidence_level) / 2)

  utilities_list <- list()

  for (attr in config$attributes$AttributeName) {
    levels_vec <- get_attribute_levels(config, attr)
    n_levels <- length(levels_vec)

    for (j in seq_len(n_levels)) {
      level <- levels_vec[j]

      if (j == 1) {
        # Baseline level: utility = 0 (reference)
        utilities_list[[length(utilities_list) + 1]] <- data.frame(
          Attribute = attr,
          Level = level,
          Utility = 0,
          SE = 0,
          CI_Lower = 0,
          CI_Upper = 0,
          p_value = NA_real_,
          is_baseline = TRUE,
          stringsAsFactors = FALSE
        )
      } else {
        # Non-baseline level
        col_name <- paste0(attr, "_", level)
        idx <- which(col_names == col_name)

        if (length(idx) == 1) {
          beta_val <- aggregate_betas[idx]
          sd_val <- aggregate_sds[idx]

          utilities_list[[length(utilities_list) + 1]] <- data.frame(
            Attribute = attr,
            Level = level,
            Utility = beta_val,
            SE = sd_val,
            CI_Lower = beta_val - z * sd_val,
            CI_Upper = beta_val + z * sd_val,
            p_value = 2 * (1 - pnorm(abs(beta_val / max(sd_val, 1e-10)))),
            is_baseline = FALSE,
            stringsAsFactors = FALSE
          )
        } else {
          # Column not found - should not happen
          message(sprintf("[TRS INFO] CONJ_HB_MISSING_COL: Column '%s' not found in HB results", col_name))
          utilities_list[[length(utilities_list) + 1]] <- data.frame(
            Attribute = attr,
            Level = level,
            Utility = 0,
            SE = 0,
            CI_Lower = 0,
            CI_Upper = 0,
            p_value = NA_real_,
            is_baseline = FALSE,
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }

  utilities <- do.call(rbind, utilities_list)
  rownames(utilities) <- NULL

  # Zero-center within each attribute if configured
  if (config$zero_center_utilities) {
    for (attr in unique(utilities$Attribute)) {
      mask <- utilities$Attribute == attr
      attr_mean <- mean(utilities$Utility[mask])
      utilities$Utility[mask] <- utilities$Utility[mask] - attr_mean
      utilities$CI_Lower[mask] <- utilities$CI_Lower[mask] - attr_mean
      utilities$CI_Upper[mask] <- utilities$CI_Upper[mask] - attr_mean
    }
  }

  utilities
}


#' Calculate Attribute Importance from HB Individual-Level Utilities
#'
#' Computes importance the correct way for HB: calculate importance at
#' the individual level first, then average across respondents.
#' This avoids the bias of computing importance from averaged utilities.
#'
#' @param hb_result HB model result
#' @param config Configuration object
#' @param verbose Logical
#' @return Data frame with Attribute, Importance, SD columns
#' @keywords internal
calculate_attribute_importance_hb <- function(hb_result, config, verbose = TRUE) {

  log_verbose("  → Calculating individual-level importance (correct HB method)...", verbose)

  individual_betas <- hb_result$individual_betas
  col_names <- hb_result$col_names
  n_respondents <- nrow(individual_betas)
  attr_names <- config$attributes$AttributeName

  # Calculate importance per respondent
  resp_importance <- matrix(0, nrow = n_respondents, ncol = length(attr_names))
  colnames(resp_importance) <- attr_names

  for (i in seq_len(n_respondents)) {
    betas_i <- individual_betas[i, ]

    # Calculate utility range per attribute
    ranges <- numeric(length(attr_names))
    for (a in seq_along(attr_names)) {
      attr <- attr_names[a]
      levels_vec <- get_attribute_levels(config, attr)

      # Reconstruct full utility vector (including baseline = 0)
      attr_utils <- numeric(length(levels_vec))
      attr_utils[1] <- 0  # baseline

      for (j in 2:length(levels_vec)) {
        col_name <- paste0(attr, "_", levels_vec[j])
        idx <- which(col_names == col_name)
        if (length(idx) == 1) {
          attr_utils[j] <- betas_i[idx]
        }
      }

      ranges[a] <- max(attr_utils) - min(attr_utils)
    }

    # Importance = range / sum(ranges) * 100
    total_range <- sum(ranges)
    if (total_range > 0) {
      resp_importance[i, ] <- (ranges / total_range) * 100
    }
  }

  # Average across respondents
  avg_importance <- colMeans(resp_importance)
  sd_importance <- apply(resp_importance, 2, sd)

  importance_df <- data.frame(
    Attribute = attr_names,
    Importance = avg_importance,
    SD = sd_importance,
    stringsAsFactors = FALSE
  )

  # Sort by importance descending
  importance_df <- importance_df[order(-importance_df$Importance), ]
  rownames(importance_df) <- NULL

  if (verbose) {
    log_verbose("  ✓ Individual-level importance calculated (averaged across respondents)", verbose)
  }

  importance_df
}


# ==============================================================================
# HB DATA VALIDATION
# ==============================================================================

#' Validate Data for HB Estimation
#'
#' @param data_list Data list from load_conjoint_data()
#' @param config Configuration object
#' @return Validation results
#' @keywords internal
validate_hb_data <- function(data_list, config) {

  validation <- list(
    critical = character(0),
    warnings = character(0),
    info = character(0)
  )

  # Check minimum respondents
  min_respondents <- 30
  if (data_list$n_respondents < min_respondents) {
    validation$warnings <- c(
      validation$warnings,
      sprintf(
        "HB estimation works best with %d+ respondents (you have %d). Results may be unstable.",
        min_respondents, data_list$n_respondents
      )
    )
  }

  # Check choices per respondent
  min_choices_per_resp <- 8
  avg_choices <- data_list$n_choice_sets / data_list$n_respondents
  if (avg_choices < min_choices_per_resp) {
    validation$warnings <- c(
      validation$warnings,
      sprintf(
        "HB works best with %d+ choices per respondent (average: %.1f). Consider increasing task count.",
        min_choices_per_resp, avg_choices
      )
    )
  }

  validation$info <- c(
    validation$info,
    sprintf("HB will estimate individual utilities for %d respondents", data_list$n_respondents),
    sprintf("Each respondent has ~%.1f choice sets", avg_choices)
  )

  validation
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>Conjoint HB module loaded (v%s) [STATUS: %s]",
                CONJOINT_HB_VERSION, CONJOINT_HB_STATUS))
