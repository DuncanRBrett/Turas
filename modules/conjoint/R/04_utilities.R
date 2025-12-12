# ==============================================================================
# CONJOINT ANALYSIS - UTILITY CALCULATION
# ==============================================================================
#
# Module: Conjoint Analysis - Part-Worth Utilities
# Purpose: Calculate utilities, confidence intervals, and attribute importance
# Version: 2.1.0 (Phase 1 - Alchemer Integration)
# Date: 2025-12-12
#
# NOTE: Handles attribute names with special characters (e.g., "I+G") by
#       escaping regex patterns when matching coefficient names.
#
# ==============================================================================

#' Calculate Part-Worth Utilities
#'
#' Extracts and processes part-worth utilities from estimated model
#' Includes confidence intervals, significance testing, and interpretation
#'
#' @param model_result Model result from estimate_choice_model()
#' @param config Configuration list
#' @param verbose Logical, print progress
#' @return Data frame with utilities
#' @export
calculate_utilities <- function(model_result, config, verbose = TRUE) {

  log_verbose("Calculating part-worth utilities...", verbose)

  # Extract coefficients and standard errors
  coefs <- model_result$coefficients
  std_errors <- model_result$std_errors

  # Handle NA coefficients
  if (any(is.na(coefs))) {
    warning(create_warning(
      "UTILITIES",
      sprintf("%d coefficients are NA (likely due to perfect separation)", sum(is.na(coefs))),
      "These will be set to 0. Check your data quality."
    ), call. = FALSE)
    coefs[is.na(coefs)] <- 0
    std_errors[is.na(std_errors)] <- 0
  }

  # Build utilities data frame
  utilities_list <- list()

  for (attr in config$attributes$AttributeName) {
    attr_utils <- extract_attribute_utilities(
      attr, coefs, std_errors, config, model_result
    )
    utilities_list[[attr]] <- attr_utils
  }

  utilities <- do.call(rbind, utilities_list)
  rownames(utilities) <- NULL

  # Add interpretation
  utilities$Interpretation <- mapply(
    interpret_utility,
    utilities$Utility,
    utilities$p_value,
    utilities$is_baseline,
    SIMPLIFY = TRUE
  )

  log_verbose(sprintf("  ✓ Calculated %d part-worth utilities", nrow(utilities)), verbose)

  utilities
}


#' Extract Utilities for One Attribute
#'
#' @keywords internal
extract_attribute_utilities <- function(attr, coefs, std_errors, config, model_result) {

  # Get all levels for this attribute
  all_levels <- get_attribute_levels(config, attr)
  n_levels <- length(all_levels)

  # Initialize vectors
  utilities <- rep(0, n_levels)
  ses <- rep(0, n_levels)
  is_baseline <- rep(FALSE, n_levels)

  names(utilities) <- all_levels
  names(ses) <- all_levels

  # Find coefficients for this attribute
  # Coefficient names have format: AttributeNameLevelName or `AttributeName`LevelName
  # Need to escape special regex characters in attribute name

  # Create pattern that matches either escaped or unescaped attribute name
  # e.g., for "I+G", match both "I+GPresent" and "`I+G`Present"
  # Use character class [``] for backtick to avoid regex parsing issues
  attr_escaped <- gsub("([+*?^${}()|\\[\\]\\\\.])", "\\\\\\1", attr)
  coef_pattern <- paste0("^[`]?", attr_escaped, "[`]?")
  attr_coef_indices <- grep(coef_pattern, names(coefs))

  if (length(attr_coef_indices) > 0) {
    # Extract level names from coefficient names
    coef_names <- names(coefs)[attr_coef_indices]
    # Remove both escaped and unescaped attribute name prefix
    level_names <- gsub(paste0("^[`]?", attr_escaped, "[`]?"), "", coef_names)

    # Assign coefficients
    for (i in seq_along(level_names)) {
      level <- level_names[i]
      if (level %in% names(utilities)) {
        utilities[level] <- coefs[attr_coef_indices[i]]
        ses[level] <- std_errors[attr_coef_indices[i]]
      }
    }
  }

  # Mark baseline level
  # In R's factor coding, first level (reference) has coefficient = 0
  baseline_level <- all_levels[1]
  is_baseline[names(utilities) == baseline_level] <- TRUE

  # Zero-center utilities within attribute
  utilities_raw <- utilities
  utilities <- zero_center_utilities(utilities)

  # Calculate confidence intervals
  ci_lower <- rep(NA_real_, n_levels)
  ci_upper <- rep(NA_real_, n_levels)
  p_values <- rep(NA_real_, n_levels)

  for (i in seq_along(all_levels)) {
    if (!is_baseline[i]) {
      # Calculate CI using raw (pre-centered) coefficient and SE
      ci <- calculate_ci(
        utilities_raw[i],
        ses[i],
        config$confidence_level
      )
      ci_lower[i] <- ci["lower"] - mean(utilities_raw)  # Adjust for centering
      ci_upper[i] <- ci["upper"] - mean(utilities_raw)

      # Calculate p-value
      p_values[i] <- calculate_p_value(utilities_raw[i], ses[i])
    }
  }

  # Create data frame
  data.frame(
    Attribute = attr,
    Level = all_levels,
    Utility = utilities,
    Std_Error = ses,
    CI_Lower = ci_lower,
    CI_Upper = ci_upper,
    p_value = p_values,
    Significance = sapply(p_values, get_significance_stars),
    is_baseline = is_baseline,
    stringsAsFactors = FALSE
  )
}


#' Calculate Attribute Importance
#'
#' Calculates relative importance as % of total utility range
#'
#' @param utilities Utilities data frame from calculate_utilities()
#' @param config Configuration list
#' @param verbose Logical, print progress
#' @return Data frame with importance scores
#' @export
calculate_attribute_importance <- function(utilities, config, verbose = TRUE) {

  log_verbose("Calculating attribute importance...", verbose)

  # Calculate range for each attribute
  ranges <- utilities %>%
    group_by(Attribute) %>%
    summarise(
      Range = max(Utility) - min(Utility),
      .groups = "drop"
    )

  # Calculate importance as % of total range
  total_range <- sum(ranges$Range)

  if (total_range == 0) {
    warning(create_warning(
      "IMPORTANCE",
      "Total utility range is zero - cannot calculate importance",
      "Check your model estimation results"
    ), call. = FALSE)

    ranges$Importance <- 0
  } else {
    ranges$Importance <- (ranges$Range / total_range) * 100
  }

  # Add rank
  ranges$Rank <- rank(-ranges$Importance, ties.method = "first")

  # Add interpretation
  ranges$Interpretation <- sapply(ranges$Importance, interpret_importance)

  # Sort by importance
  ranges <- ranges[order(-ranges$Importance), ]
  rownames(ranges) <- NULL

  log_verbose("  ✓ Importance scores calculated", verbose)

  ranges
}


#' Calculate Model Diagnostics
#'
#' Comprehensive model fit statistics and diagnostics
#'
#' @param model_result Model result from estimate_choice_model()
#' @param data_list Data list from load_conjoint_data()
#' @param utilities Utilities data frame
#' @param importance Importance data frame
#' @param config Configuration list
#' @param verbose Logical, print progress
#' @return List with diagnostic statistics
#' @export
calculate_model_diagnostics <- function(model_result, data_list, utilities,
                                       importance, config, verbose = TRUE) {

  log_verbose("Calculating model diagnostics...", verbose)

  data <- data_list$data

  diagnostics <- list()

  # Method-specific fit statistics
  if (model_result$method %in% c("mlogit", "clogit")) {
    # Choice-based diagnostics
    diagnostics$fit_statistics <- calculate_choice_fit_stats(
      model_result, data, config
    )
  } else if (model_result$method == "ols_rating") {
    # Rating-based diagnostics
    diagnostics$fit_statistics <- list(
      r_squared = model_result$r_squared,
      adj_r_squared = model_result$adj_r_squared,
      rmse = model_result$rmse,
      n_obs = model_result$n_obs
    )
  }

  # Attribute-level diagnostics
  diagnostics$attribute_diagnostics <- calculate_attribute_diagnostics(
    utilities, importance, config
  )

  # Data quality indicators
  diagnostics$data_quality <- list(
    n_respondents = data_list$n_respondents,
    n_choice_sets = data_list$n_choice_sets,
    has_none_option = data_list$has_none,
    validation_warnings = length(data_list$validation$warnings),
    validation_info = length(data_list$validation$info)
  )

  # Convergence info
  diagnostics$convergence <- model_result$convergence

  # Model quality assessment
  if (model_result$method %in% c("mlogit", "clogit")) {
    mcfadden_r2 <- diagnostics$fit_statistics$mcfadden_r2
    diagnostics$quality_assessment <- assess_mcfadden_r2(mcfadden_r2)
  }

  log_verbose("  ✓ Diagnostics calculated", verbose)

  diagnostics
}


#' Calculate Choice Model Fit Statistics
#'
#' @keywords internal
calculate_choice_fit_stats <- function(model_result, data, config) {

  ll_null <- model_result$loglik["null"]
  ll_fitted <- model_result$loglik["fitted"]
  n_params <- model_result$n_parameters

  # McFadden R²
  mcfadden_r2 <- 1 - (ll_fitted / ll_null)

  # Adjusted McFadden R²
  adj_mcfadden_r2 <- 1 - ((ll_fitted - n_params) / ll_null)

  # Calculate hit rate
  hit_rate <- calculate_hit_rate(model_result, data, config)

  # Chance rate (1 / avg alternatives per choice set)
  # Group by BOTH respondent and choice set to get correct count
  alts_per_set <- data %>%
    group_by(!!sym(config$respondent_id_column), !!sym(config$choice_set_column)) %>%
    summarise(n_alts = n(), .groups = "drop") %>%
    pull(n_alts) %>%
    mean()

  chance_rate <- 1 / alts_per_set

  list(
    mcfadden_r2 = mcfadden_r2,
    adj_mcfadden_r2 = adj_mcfadden_r2,
    log_likelihood_null = ll_null,
    log_likelihood_fitted = ll_fitted,
    aic = model_result$aic,
    bic = model_result$bic,
    hit_rate = hit_rate,
    chance_rate = chance_rate,
    improvement_over_chance = hit_rate / chance_rate,
    n_parameters = n_params,
    n_obs = model_result$n_obs
  )
}


#' Calculate Hit Rate
#'
#' Percentage of choices correctly predicted
#'
#' @keywords internal
#'
#' Assumptions:
#' - model_result$model is an mlogit model fitted on dfidx data with idx = (chid, alt)
#' - config$chosen_column is a 0/1 indicator of the chosen alternative per row
#' - Each choice set has exactly one chosen alt (or NA-handling kicks in)
#' - fitted(..., outcome = FALSE) returns a matrix (n_choice_sets × n_alternatives)
#'
calculate_hit_rate <- function(model_result, data, config) {

  tryCatch({
    if (model_result$method == "mlogit") {
      # Get fitted probabilities as MATRIX (choice sets × alternatives)
      # fitted(..., outcome = FALSE) returns a matrix with:
      #   - one row per choice set
      #   - one column per alternative
      #   - row sums = 1.0 (probabilities)
      fitted_mat <- fitted(model_result$model, outcome = FALSE)

      # Sanity check: verify it's a matrix and row sums are ~1.0
      if (!is.matrix(fitted_mat)) {
        stop("fitted() did not return a matrix as expected")
      }

      # Get actual choices from long-format data
      model_df <- model_result$model$model

      # Get choice column by name (future-proof vs positional indexing)
      choice_col_name <- config$chosen_column
      if (!choice_col_name %in% names(model_df)) {
        # Fallback: use first column if name not found
        choice_col_name <- names(model_df)[1]
      }
      chosen <- as.logical(model_df[[choice_col_name]])  # Choice indicator per row

      idx_df <- as.data.frame(dfidx::idx(model_df))
      chid <- idx_df[[1]]  # Choice set IDs

      # Compress to per-choice-set actual choice index
      # Defensive: handle edge cases where 0 or >1 alternatives are chosen
      actual_choice <- tapply(chosen, chid, function(x) {
        idx <- which(x)
        if (length(idx) == 0L) return(NA_integer_)  # No choice (dirty data)
        if (length(idx) > 1L) {
          warning(sprintf("Choice set has %d chosen alternatives; using first", length(idx)))
          idx <- idx[1L]
        }
        idx
      })
      actual_choice <- unlist(actual_choice)  # Ensure it's a vector, not a list

      # Get predicted choice index per choice set (row-wise max)
      # max.col returns the column index of the maximum value per row
      predicted_choice <- max.col(fitted_mat, ties.method = "first")

      # Align predictions and actuals
      # Row i of fitted_mat corresponds to choice set i
      chid_unique <- unique(chid)

      # If fitted_mat has rownames, use those for alignment; otherwise assume 1:N order
      if (!is.null(rownames(fitted_mat))) {
        # Preserve ordering of actual_choice while filtering to matched IDs
        chid_levels <- names(actual_choice)[names(actual_choice) %in% rownames(fitted_mat)]
        actual_vec <- actual_choice[chid_levels]
        pred_vec <- predicted_choice[match(chid_levels, rownames(fitted_mat))]
      } else {
        # Assume rows are in order of unique chid
        chid_levels <- as.character(chid_unique)
        actual_vec <- actual_choice[chid_levels]
        pred_vec <- predicted_choice
      }

      # Sanity checks: verify dimensions match before computing hit rate
      if (length(actual_vec) != nrow(fitted_mat)) {
        stop(sprintf(
          "Alignment error: %d actual choices != %d rows in fitted matrix",
          length(actual_vec), nrow(fitted_mat)
        ))
      }
      if (length(pred_vec) != length(actual_vec)) {
        stop(sprintf(
          "Alignment error: %d predictions != %d actual choices",
          length(pred_vec), length(actual_vec)
        ))
      }

      # Calculate hit rate
      correct <- sum(actual_vec == pred_vec, na.rm = TRUE)
      total <- length(actual_vec)
      hit_rate <- correct / total

      # Optional: Print diagnostic info (controlled by option)
      # Set with: options(conjoint.verbose_diagnostics = TRUE)
      if (getOption("conjoint.verbose_diagnostics", default = TRUE)) {
        cat("\n[HIT RATE CALCULATION]\n")
        cat("======================\n")
        cat(sprintf("Fitted matrix dimensions: %d choice sets × %d alternatives\n",
                    nrow(fitted_mat), ncol(fitted_mat)))
        cat(sprintf("Row sums (should all be ~1.0): %s\n",
                    paste(round(head(rowSums(fitted_mat), 3), 4), collapse = ", ")))

        # Show first 10 choice sets
        cat("\nFirst 10 choice sets (predicted vs actual):\n")
        cat(sprintf("%-8s %-10s %-10s %-8s\n", "Set", "Predicted", "Actual", "Match"))
        cat(strrep("-", 45), "\n")

        first_10 <- head(seq_along(chid_levels), 10)
        for (i in first_10) {
          cs_id <- chid_levels[i]
          pred <- pred_vec[i]
          act <- actual_vec[i]
          match <- if (pred == act) "YES" else "NO"
          cat(sprintf("%-8s %-10d %-10d %-8s\n", cs_id, pred, act, match))
        }

        cat(sprintf("\nTotal correct: %d / %d = %.1f%%\n", correct, total, 100 * hit_rate))
        cat(sprintf("Chance rate (1/%d alts): %.1f%%\n",
                    ncol(fitted_mat), 100 / ncol(fitted_mat)))
      }

      hit_rate

    } else if (model_result$method == "clogit") {
      # clogit predictions
      pred_probs <- predict(model_result$model, type = "expected")

      # Get unique choice sets (respondent × choice_set_id combinations)
      unique_sets <- data %>%
        select(!!sym(config$respondent_id_column), !!sym(config$choice_set_column)) %>%
        distinct()

      correct <- 0

      for (i in 1:nrow(unique_sets)) {
        resp <- unique_sets[[config$respondent_id_column]][i]
        cs <- unique_sets[[config$choice_set_column]][i]

        # Get rows for this specific respondent's choice set
        cs_rows <- which(
          data[[config$respondent_id_column]] == resp &
          data[[config$choice_set_column]] == cs
        )

        cs_probs <- pred_probs[cs_rows]
        predicted <- which.max(cs_probs)
        actual <- which(data[[config$chosen_column]][cs_rows] == 1)

        if (length(actual) > 0 && predicted == actual[1]) {
          correct <- correct + 1
        }
      }

      hit_rate <- correct / nrow(unique_sets)

    } else {
      hit_rate <- NA
    }

    hit_rate

  }, error = function(e) {
    warning(create_warning(
      "DIAGNOSTICS",
      sprintf("Could not calculate hit rate: %s", conditionMessage(e))
    ), call. = FALSE)
    return(NA)
  })
}


#' Calculate Attribute Diagnostics
#'
#' @keywords internal
calculate_attribute_diagnostics <- function(utilities, importance, config) {

  attr_diagnostics <- list()

  for (attr in config$attributes$AttributeName) {
    attr_utils <- utilities[utilities$Attribute == attr, ]

    # Count significant levels
    n_significant <- sum(attr_utils$p_value < 0.05, na.rm = TRUE)
    n_total <- nrow(attr_utils)

    # Get range and importance
    attr_range <- max(attr_utils$Utility) - min(attr_utils$Utility)
    attr_importance <- importance$Importance[importance$Attribute == attr]

    attr_diagnostics[[attr]] <- list(
      n_levels = n_total,
      n_significant = n_significant,
      pct_significant = (n_significant / n_total) * 100,
      range = attr_range,
      importance = attr_importance
    )
  }

  attr_diagnostics
}
