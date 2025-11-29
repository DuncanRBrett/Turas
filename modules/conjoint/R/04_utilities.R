# ==============================================================================
# CONJOINT ANALYSIS - UTILITY CALCULATION
# ==============================================================================
#
# Module: Conjoint Analysis - Part-Worth Utilities
# Purpose: Calculate utilities, confidence intervals, and attribute importance
# Version: 2.0.0 (Enhanced Implementation)
# Date: 2025-11-26
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
  # Coefficient names have format: AttributeNameLevelName
  coef_pattern <- paste0("^", attr)
  attr_coef_indices <- grep(coef_pattern, names(coefs))

  if (length(attr_coef_indices) > 0) {
    # Extract level names from coefficient names
    coef_names <- names(coefs)[attr_coef_indices]
    level_names <- gsub(paste0("^", attr), "", coef_names)

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
  alts_per_set <- data %>%
    count(!!sym(config$choice_set_column)) %>%
    pull(n) %>%
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
calculate_hit_rate <- function(model_result, data, config) {

  # Get predictions
  tryCatch({
    if (model_result$method == "mlogit") {
      # Vectorized approach: compare predicted vs actual for all choice sets
      fitted_probs <- fitted(model_result$model, outcome = FALSE)

      # Get model data frame
      model_df <- model_result$model$model

      # Response variable (chosen TRUE/FALSE)
      chosen <- as.logical(model_df[[1]])

      # Get choice set IDs
      idx_df <- as.data.frame(dfidx::idx(model_df))
      chid <- idx_df[[1]]

      # For each choice set, find which alternative has max probability
      # and which was actually chosen
      predicted_choice <- tapply(fitted_probs, chid, which.max)
      actual_choice <- tapply(chosen, chid, which)

      # DEBUG: Print first few to see what we're comparing
      cat("\n[DEBUG] Hit Rate Calculation:\n")
      cat("  First 10 predicted:", head(predicted_choice, 10), "\n")
      cat("  First 10 actual:   ", head(actual_choice, 10), "\n")
      cat("  Match?:            ", head(predicted_choice, 10) == head(actual_choice, 10), "\n")

      # Count matches
      correct <- sum(predicted_choice == actual_choice, na.rm = TRUE)
      total <- length(unique(chid))

      cat("  Total: ", correct, "correct out of", total, "choice sets\n")

      hit_rate <- correct / total

    } else if (model_result$method == "clogit") {
      # clogit predictions
      pred_probs <- predict(model_result$model, type = "expected")

      choice_sets <- unique(data[[config$choice_set_column]])
      correct <- 0

      for (cs in choice_sets) {
        cs_rows <- which(data[[config$choice_set_column]] == cs)
        cs_probs <- pred_probs[cs_rows]
        predicted <- which.max(cs_probs)
        actual <- which(data[[config$chosen_column]][cs_rows] == 1)

        if (length(actual) > 0 && predicted == actual[1]) {
          correct <- correct + 1
        }
      }

      hit_rate <- correct / length(choice_sets)

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
