# ==============================================================================
# CATEGORICAL KEY DRIVER - VARIABLE IMPORTANCE
# ==============================================================================
#
# Calculate and format variable importance scores using Wald chi-square tests.
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================

#' Calculate Variable Importance
#'
#' Uses Type II Wald chi-square tests to calculate importance scores.
#'
#' @param model_result Model results from run_catdriver_model()
#' @param config Configuration list
#' @return Data frame with importance metrics
#' @export
calculate_importance <- function(model_result, config) {

  model <- model_result$model

  # The car dependency is checked OUTSIDE the fallback handler. It used to sit
  # inside a tryCatch whose error branch called the z-squared fallback, and a
  # TRS refusal is an error condition, so a missing package silently became a
  # different statistic instead of a refusal. Every refusal raised anywhere
  # below the car::Anova call had the same fate.
  if (model_result$model_type == "multinomial_logistic") {
    # The multinomial path uses likelihood-ratio refits, not car::Anova, so it
    # must not be gated on a package it never calls. Its refusals travel because
    # it is called outside the fallback handler below.
    return(calculate_multinomial_importance(model_result, config))
  }

  if (!requireNamespace("car", quietly = TRUE)) {
    catdriver_refuse(
      reason = "PKG_CAR_MISSING",
      title = "REQUIRED PACKAGE MISSING",
      problem = "Package 'car' is required for variable importance calculation but is not installed.",
      why_it_matters = "Variable importance uses likelihood-ratio chi-square tests from car::Anova.",
      fix = "Install the package with: install.packages('car')"
    )
  }

  anova_result <- tryCatch(
    # car::Anova refits the model for each term, so a weighted binomial repeats
    # the "non-integer #successes" warning once per driver. Same muffler, same
    # reason as the fit sites.
    cd_muffle_noninteger_successes(car::Anova(model, type = "II")),
    turas_refusal = function(e) stop(e),   # a refusal is not a reason to fall back
    error = function(e) {
      cat(sprintf("   [WARNING] car::Anova failed: %s. Falling back to z-squared shares.\n",
                  conditionMessage(e)))
      structure(list(reason = conditionMessage(e)), class = "cd_anova_failed")
    }
  )

  if (inherits(anova_result, "cd_anova_failed")) {
    importance_df <- calculate_fallback_importance(model_result, config)

    # The fallback aggregates dummy terms back to their drivers, and it can only
    # do that with a term mapping. It used to be called without one, so the
    # Importance Summary listed twelve per-level rows like
    # "service_qualityExcellent" and the run separately reported that every
    # configured driver was missing from the table. A table nobody can read is
    # not a fallback, so if the mapping did not resolve, refuse.
    unresolved <- setdiff(importance_df$variable, config$driver_vars)
    if (length(unresolved) > 0) {
      catdriver_refuse(
        reason = "CALC_IMPORTANCE_FALLBACK_UNMAPPED",
        title = "IMPORTANCE COULD NOT BE REPORTED BY DRIVER",
        problem = paste0(
          "car::Anova failed (", anova_result$reason,
          ") and the fallback could not aggregate its coefficients back to drivers: ",
          paste(utils::head(unresolved, 8), collapse = ", "),
          if (length(unresolved) > 8) ", ..." else ""
        ),
        why_it_matters = paste0(
          "The fallback would otherwise report one row per dummy coefficient, which is not ",
          "driver importance and cannot be compared with any other run."
        ),
        fix = paste0(
          "Check that the 'car' package is installed and current: install.packages('car').\n",
          "If it is, simplify the model (fewer drivers, or collapse rare levels) and run again."
        )
      )
    }
    # D5: the output says which statistic produced it, and the run says so too.
    importance_df$method <- "z-squared share (Wald, car::Anova unavailable)"
    attr(importance_df, "cd_importance_degraded") <- paste0(
      "Driver importance used a z-squared Wald share instead of likelihood-ratio ",
      "chi-squares, because car::Anova failed: ", anova_result$reason,
      ". The two statistics are not the same and the shares are not comparable with other runs."
    )
    return(importance_df)
  }

  # Process Anova results
  importance_df <- process_anova_results(anova_result, config)

  # Which statistic car::Anova returned is a property of the model class, not of
  # this module: glm gives a likelihood-ratio chi-square (column "LR Chisq"),
  # clm gives a WALD chi-square (column "Chisq"), and polr gives LR again. An
  # earlier version of this line stamped every path as likelihood-ratio on the
  # strength of having checked glm, which is the same dishonest provenance the
  # stamp exists to prevent: on the ordinal demo the Wald figure is 120.4 where
  # the likelihood-ratio one is 135.4. Read the column and say what it is.
  importance_df$method <- .cd_anova_method_label(anova_result, model_result)

  importance_df
}


#' Name the Statistic car::Anova Returned
#'
#' @param anova_result The object returned by \code{car::Anova}.
#' @param model_result The model result, used to name the engine.
#' @return Single character string for the importance frame's method column.
#' @keywords internal
.cd_anova_method_label <- function(anova_result, model_result = NULL) {

  cols <- tryCatch(names(as.data.frame(anova_result)), error = function(e) character(0))
  engine <- model_result$engine_used %||% model_result$model_type %||% "model"

  statistic <- if (any(grepl("^LR", cols))) {
    "LR chi-square share"
  } else if (any(grepl("^Chisq$", cols))) {
    "Wald chi-square share"
  } else if (any(grepl("^F$", cols))) {
    "F-statistic share"
  } else {
    "chi-square share"
  }

  sprintf("%s (car::Anova type II on %s)", statistic, engine)
}


#' Process ANOVA Results into Importance Data Frame
#'
#' Transforms raw car::Anova output into a ranked importance data frame with
#' relative percentages, significance stars, and effect size classifications.
#'
#' @param anova_result Object returned by car::Anova (class "anova"), containing
#'   chi-square statistics and p-values for each predictor.
#' @param config Configuration list with driver variable names and labels.
#' @return Data frame with columns: variable, chi_square, df, p_value,
#'   importance_pct, label, significance, effect_size, rank.
#' @keywords internal
process_anova_results <- function(anova_result, config) {

  # Extract chi-square and p-values
  if (inherits(anova_result, "anova")) {
    # Standard Anova output
    anova_df <- as.data.frame(anova_result)

    # Find chi-square column (may be named differently)
    chisq_col <- grep("(Chisq|LR|Chi)", names(anova_df), value = TRUE, ignore.case = TRUE)
    pval_col <- grep("Pr", names(anova_df), value = TRUE)
    df_col <- grep("Df|df", names(anova_df), value = TRUE)

    if (length(chisq_col) == 0) {
      # Try to use first numeric column
      numeric_cols <- sapply(anova_df, is.numeric)
      if (any(numeric_cols)) {
        chisq_col <- names(anova_df)[which(numeric_cols)[1]]
      } else {
        catdriver_refuse(
          reason = "IMPORTANCE_ANOVA_UNEXPECTED",
          title = "UNEXPECTED ANOVA OUTPUT FORMAT",
          problem = "Cannot identify chi-square column in Anova output.",
          why_it_matters = "Variable importance calculation requires chi-square statistics from the Anova output.",
          fix = "This may indicate an incompatible version of the 'car' package. Try updating with: install.packages('car')",
          details = paste0("Columns found: ", paste(colnames(anova_df), collapse = ", "))
        )
      }
    }

    importance_df <- data.frame(
      variable = rownames(anova_df),
      chi_square = anova_df[[chisq_col[1]]],
      df = if (length(df_col) > 0) anova_df[[df_col[1]]] else NA,
      p_value = if (length(pval_col) > 0) anova_df[[pval_col[1]]] else NA,
      stringsAsFactors = FALSE
    )

  } else {
    # Fallback for non-standard output
    importance_df <- as.data.frame(anova_result)
    importance_df$variable <- rownames(importance_df)
  }

  # Remove residuals/intercept rows
  importance_df <- importance_df[!grepl("^(Residual|Intercept|\\(Intercept\\))", importance_df$variable), ]

  # Calculate relative importance
  total_chisq <- sum(importance_df$chi_square, na.rm = TRUE)
  importance_df$importance_pct <- if (total_chisq > 0) {
    round(100 * importance_df$chi_square / total_chisq, 1)
  } else {
    rep(0, nrow(importance_df))
  }

  # Add labels
  importance_df$label <- sapply(importance_df$variable, function(v) {
    get_var_label(config, v)
  })

  # Add significance stars
  importance_df$significance <- sapply(importance_df$p_value, get_sig_stars)

  # Calculate effect size category based on chi-square
  # Use Cohen's w approximation: w = sqrt(chi2/n)
  # But we'll use a simpler heuristic based on importance %
  importance_df$effect_size <- vapply(importance_df$importance_pct,
    classify_importance_effect, character(1))

  # Sort by importance
  importance_df <- importance_df[order(-importance_df$importance_pct), ]

  # Add rank
  importance_df$rank <- seq_len(nrow(importance_df))

  rownames(importance_df) <- NULL

  importance_df
}


#' Calculate Importance for Multinomial Models
#'
#' Uses likelihood ratio tests comparing the full multinomial model to reduced
#' models (each with one predictor removed) to compute per-variable importance.
#' Falls back to equal importance if model data cannot be extracted.
#'
#' @param model_result List returned by run_catdriver_model(), must contain
#'   \code{model} (fitted multinom object) and optionally \code{analysis_data}.
#' @param config Configuration list with \code{driver_vars} and \code{outcome_var}.
#' @return Data frame with columns: variable, chi_square, df, p_value,
#'   importance_pct, label, significance, effect_size, rank.
#' @keywords internal
calculate_multinomial_importance <- function(model_result, config) {

  model <- model_result$model

  # The reduced models must be refitted on exactly the rows the full model used
  # and with exactly the same weights. 04b stores that frame as estimation_data
  # (with the weight column ..catdriver_wt.. when the run is weighted).
  #
  # This used to refit on analysis_data, the raw frame with no weight column,
  # so a weighted full log-likelihood was compared with an unweighted reduced
  # one. Coordinator-verified in the July 2026 review: chi-square of -282.1 for
  # a real driver, which then divided into importance_pct as a NEGATIVE share.
  data <- model_result$estimation_data
  weight_col <- model_result$weight_column
  if (is.null(data)) {
    data <- model_result$analysis_data
    if (is.null(data)) data <- tryCatch(model.frame(model), error = function(e) NULL)
    if (is.null(data)) data <- model$model
    weight_col <- NULL
  }

  if (is.null(data)) {
    # This used to write every driver an equal share of 100 per cent, with ranks
    # and "Unknown" effect sizes, behind a console [WARN]. Those numbers were
    # invented: they describe no model and no data.
    catdriver_refuse(
      reason = "CALC_IMPORTANCE_DATA_UNAVAILABLE",
      title = "MULTINOMIAL IMPORTANCE CANNOT BE COMPUTED",
      problem = "The data the multinomial model was fitted on could not be recovered, so no reduced model can be refitted.",
      why_it_matters = paste0(
        "Importance for a multinomial model comes from refitting the model without each driver. ",
        "Earlier versions filled the table with an equal share for every driver instead, which ",
        "looked like a result and was not one."
      ),
      fix = paste0(
        "Re-run the analysis. If it happens again, the multinomial fit did not return its ",
        "estimation data: reduce the number of outcome levels or drivers and try again."
      )
    )
  }

  weighted_refit <- !is.null(weight_col) && weight_col %in% names(data)
  if (weighted_refit && !identical(weight_col, "..catdriver_wt..")) {
    data[["..catdriver_wt.."]] <- data[[weight_col]]
  }

  importance_method <- if (weighted_refit) {
    "LR-test share (weighted multinomial refits)"
  } else {
    "LR-test share (multinomial refits)"
  }

  # Get full model log-likelihood
  ll_full <- logLik(model)

  # Calculate importance for each predictor by comparing to reduced model
  importance_list <- list()

  for (var_name in config$driver_vars) {
    # Build reduced formula (without this variable)
    other_vars <- setdiff(config$driver_vars, var_name)

    if (length(other_vars) > 0) {
      reduced_formula <- as.formula(paste(config$outcome_var, "~",
                                          paste(other_vars, collapse = " + ")))
    } else {
      reduced_formula <- as.formula(paste(config$outcome_var, "~ 1"))
    }

    # Fit reduced model on the same rows, with the same weights
    reduced_model <- tryCatch({
      if (weighted_refit) {
        nnet::multinom(reduced_formula, data = data, weights = ..catdriver_wt..,
                       trace = FALSE, maxit = 500)
      } else {
        nnet::multinom(reduced_formula, data = data, trace = FALSE, maxit = 500)
      }
    }, error = function(e) NULL)

    if (!is.null(reduced_model)) {
      ll_reduced <- logLik(reduced_model)

      # Likelihood ratio test. A correctly nested pair cannot give a negative
      # statistic; if one appears the two fits are not comparable and the value
      # must not reach an importance share.
      lr_stat <- -2 * (as.numeric(ll_reduced) - as.numeric(ll_full))
      lr_df <- attr(ll_full, "df") - attr(ll_reduced, "df")
      if (is.finite(lr_stat) && lr_stat < 0) {
        if (lr_stat < -1e-6) {
          cat(sprintf("   [WARN] Reduced model for '%s' fitted better than the full model (LR = %.3f); importance for this driver is not available\n",
                      var_name, lr_stat))
          lr_stat <- NA_real_
        } else {
          lr_stat <- 0  # numerical noise around a driver that adds nothing
        }
      }
      lr_pvalue <- if (is.na(lr_stat)) NA_real_ else pchisq(lr_stat, abs(lr_df), lower.tail = FALSE)

      importance_list[[var_name]] <- data.frame(
        variable = var_name,
        chi_square = lr_stat,
        df = abs(lr_df),
        p_value = lr_pvalue,
        stringsAsFactors = FALSE
      )
    } else {
      importance_list[[var_name]] <- data.frame(
        variable = var_name,
        chi_square = NA,
        df = NA,
        p_value = NA,
        stringsAsFactors = FALSE
      )
    }
  }

  importance_df <- do.call(rbind, importance_list)
  rownames(importance_df) <- NULL

  # Calculate relative importance
  total_chisq <- sum(importance_df$chi_square, na.rm = TRUE)
  importance_df$importance_pct <- if (total_chisq > 0) {
    round(100 * importance_df$chi_square / total_chisq, 1)
  } else {
    rep(0, nrow(importance_df))
  }

  # Add labels and formatting
  importance_df$label <- sapply(importance_df$variable, function(v) {
    get_var_label(config, v)
  })

  importance_df$significance <- sapply(importance_df$p_value, get_sig_stars)

  importance_df$effect_size <- vapply(importance_df$importance_pct,
    classify_importance_effect, character(1))

  # D5: every importance row says how it was computed.
  importance_df$method <- importance_method

  # Sort and rank
  importance_df <- importance_df[order(-importance_df$importance_pct), ]
  importance_df$rank <- seq_len(nrow(importance_df))
  rownames(importance_df) <- NULL

  importance_df
}


#' Fallback Importance Calculation
#'
#' Uses squared z-values from individual coefficients as a proxy for chi-square
#' statistics when car::Anova fails. Aggregates dummy variable importance back
#' to the original factor level using aggregate_dummy_importance().
#'
#' @param model_result List returned by run_catdriver_model(), must contain
#'   \code{coefficients} data frame with \code{term}, \code{z_value}, and
#'   \code{p_value} columns.
#' @param config Configuration list with \code{driver_vars} and label accessors.
#' @return Data frame with columns: variable, chi_square, p_value,
#'   importance_pct, label, df, significance, effect_size, rank.
#' @keywords internal
calculate_fallback_importance <- function(model_result, config) {

  coef_df <- model_result$coefficients

  # Remove intercept
  coef_df <- coef_df[!grepl("^\\(Intercept\\)", coef_df$term), ]

  # For models with multiple outcomes (multinomial), aggregate
  if ("outcome_level" %in% names(coef_df)) {
    # Aggregate across outcome levels - use max chi-square
    coef_df$chi_square <- coef_df$z_value^2

    importance_df <- aggregate(
      chi_square ~ term,
      data = coef_df,
      FUN = function(x) sum(x, na.rm = TRUE)
    )
    names(importance_df) <- c("variable", "chi_square")

    # Get p-value (use minimum across levels)
    pval_df <- aggregate(
      p_value ~ term,
      data = coef_df,
      FUN = function(x) min(x, na.rm = TRUE)
    )
    importance_df$p_value <- pval_df$p_value[match(importance_df$variable, pval_df$term)]

  } else {
    # Single outcome - use z-value squared as chi-square
    importance_df <- data.frame(
      variable = coef_df$term,
      chi_square = coef_df$z_value^2,
      p_value = coef_df$p_value,
      stringsAsFactors = FALSE
    )
  }

  # Map dummy variables back to original factors. Without a mapping this
  # aggregation cannot resolve a term like "service_qualityExcellent", so build
  # one from the model itself where the module's own mapper can read it.
  mapping <- tryCatch({
    data <- model_result$estimation_data %||% model_result$analysis_data
    formula <- model_result$formula
    if (is.null(data) || is.null(formula)) stop("no frame to map against")
    if (identical(model_result$model_type, "multinomial_logistic")) {
      map_multinomial_terms(model_result$model, data, formula, config$outcome_var)
    } else {
      map_terms_to_levels(model_result$model, data, formula)
    }
  }, error = function(e) NULL)

  importance_df <- aggregate_dummy_importance(importance_df, config, mapping = mapping)

  # Calculate relative importance
  total_chisq <- sum(importance_df$chi_square, na.rm = TRUE)
  importance_df$importance_pct <- if (total_chisq > 0) {
    round(100 * importance_df$chi_square / total_chisq, 1)
  } else {
    rep(0, nrow(importance_df))
  }

  # Add labels
  importance_df$label <- sapply(importance_df$variable, function(v) {
    get_var_label(config, v)
  })

  importance_df$df <- NA
  importance_df$significance <- sapply(importance_df$p_value, get_sig_stars)
  importance_df$effect_size <- vapply(importance_df$importance_pct,
    classify_importance_effect, character(1))

  # Sort and rank
  importance_df <- importance_df[order(-importance_df$importance_pct), ]
  importance_df$rank <- seq_len(nrow(importance_df))
  rownames(importance_df) <- NULL

  importance_df
}


#' Aggregate Dummy Variable Importance to Original Factor
#'
#' Uses the canonical mapper (R/09_mapper.R) when available, falls back
#' to model.matrix introspection for reliable term-to-variable mapping.
#' NEVER uses substring parsing.
#'
#' @param importance_df Data frame with term-level importance
#' @param config Configuration list
#' @param mapping Optional pre-computed mapping from map_terms_to_levels()
#' @param prep_data Optional preprocessing results with predictor_info for fallback mapping
#' @return Data frame with factor-level importance
#' @keywords internal
aggregate_dummy_importance <- function(importance_df, config, mapping = NULL, prep_data = NULL) {

  # Match terms to original variables using proper introspection
  term_to_var <- character(nrow(importance_df))

  for (i in seq_len(nrow(importance_df))) {
    term <- importance_df$variable[i]

    # First try: use mapping if available
    if (!is.null(mapping)) {
      match_idx <- which(mapping$coef_name == term | mapping$design_col == term)
      if (length(match_idx) > 0) {
        term_to_var[i] <- mapping$driver[match_idx[1]]
        next
      }
    }

    # Second try: exact match to driver variable names
    if (term %in% config$driver_vars) {
      term_to_var[i] <- term
      next
    }

    # Third try: check contrasts/xlevels from prep_data for reliable mapping
    # This uses model matrix infrastructure instead of substring parsing
    matched <- FALSE
    for (driver_var in config$driver_vars) {
      # Get expected column names from model.matrix for this variable
      # by checking if term matches the pattern R would generate
      if (!is.null(prep_data) && !is.null(prep_data$predictor_info[[driver_var]])) {
        levels_vec <- prep_data$predictor_info[[driver_var]]$levels
        if (!is.null(levels_vec)) {
          for (lvl in levels_vec[-1]) {  # Skip reference
            expected_col <- paste0(driver_var, lvl)
            expected_col_clean <- paste0(driver_var, make.names(lvl))
            if (term == expected_col || term == expected_col_clean) {
              term_to_var[i] <- driver_var
              matched <- TRUE
              break
            }
          }
        }
        if (matched) break
      }
    }

    if (!matched) {
      # Final fallback: keep term as-is (it's likely already the variable name)
      term_to_var[i] <- term
      log_message(sprintf("Could not map term '%s' to a driver variable - using term as-is", term), "warn")
    }
  }

  importance_df$original_var <- term_to_var

  # Aggregate by original variable
  agg_df <- aggregate(
    chi_square ~ original_var,
    data = importance_df,
    FUN = sum,
    na.rm = TRUE
  )
  names(agg_df) <- c("variable", "chi_square")

  # Get min p-value for each variable
  pval_agg <- aggregate(
    p_value ~ original_var,
    data = importance_df,
    FUN = function(x) min(x, na.rm = TRUE)
  )

  agg_df$p_value <- pval_agg$p_value[match(agg_df$variable, pval_agg$original_var)]

  agg_df
}


# extract_odds_ratios() was deleted 2026-09-18. It was deprecated at v2.0 and
# called by nothing; extract_odds_ratios_mapped() in 09_mapper.R is the live
# one and maps coefficients through the model matrix rather than by parsing
# coefficient names.



#' Calculate Factor Patterns
#'
#' Creates cross-tabulation tables showing outcome proportions for each level
#' of each categorical driver variable, along with matched odds ratios.
#' Produces the data underlying the "Factor Patterns" Excel sheet.
#'
#' @param prep_data List returned by preprocess_catdriver_data(), containing
#'   \code{data} (data frame with prepared factors) and \code{outcome_info}.
#' @param config Configuration list with \code{outcome_var}, \code{driver_vars},
#'   and label accessors.
#' @param or_df Data frame of odds ratios (from extract_odds_ratios_mapped()),
#'   with columns: factor, comparison, odds_ratio, or_lower, or_upper, effect.
#' @return Named list keyed by driver variable name, each element containing:
#'   \item{variable}{Character, variable name}
#'   \item{label}{Character, display label}
#'   \item{reference}{Character, reference level name}
#'   \item{patterns}{Data frame with category, n, pct_of_total, outcome
#'     proportions, odds_ratio, or_lower, or_upper, effect, is_reference}
#' @export
calculate_factor_patterns <- function(prep_data, config, or_df) {

  data <- prep_data$data
  outcome_var <- config$outcome_var
  outcome_levels <- levels(data[[outcome_var]])

  patterns <- list()

  for (driver_var in config$driver_vars) {

    driver_data <- data[[driver_var]]

    # Skip non-categorical
    if (!is.factor(driver_data) && !is.character(driver_data)) {
      next
    }

    # Cross-tabulation
    tab <- safe_crosstab(driver_data, data[[outcome_var]])

    # Build pattern data frame
    pattern_df <- data.frame(
      category = names(tab$row_totals),
      n = as.integer(tab$row_totals),
      stringsAsFactors = FALSE
    )

    pattern_df$pct_of_total <- round(100 * pattern_df$n / sum(pattern_df$n), 1)

    # Add outcome proportions
    for (level in outcome_levels) {
      col_name <- paste0("pct_", level)
      pattern_df[[col_name]] <- round(100 * tab$proportions[, level], 1)
    }

    # Add odds ratios
    ref_level <- levels(driver_data)[1]
    pattern_df$is_reference <- pattern_df$category == ref_level

    # Match ORs to categories
    pattern_df$odds_ratio <- NA
    pattern_df$or_lower <- NA
    pattern_df$or_upper <- NA
    pattern_df$effect <- NA

    for (i in seq_len(nrow(pattern_df))) {
      cat <- pattern_df$category[i]

      if (pattern_df$is_reference[i]) {
        pattern_df$odds_ratio[i] <- 1.00
        pattern_df$effect[i] <- "-"
      } else {
        # Find matching OR
        or_match <- or_df[or_df$factor == driver_var &
                         or_df$comparison == cat, ]

        if (nrow(or_match) > 0) {
          pattern_df$odds_ratio[i] <- or_match$odds_ratio[1]
          pattern_df$or_lower[i] <- or_match$or_lower[1]
          pattern_df$or_upper[i] <- or_match$or_upper[1]
          pattern_df$effect[i] <- or_match$effect[1]
        }
      }
    }

    patterns[[driver_var]] <- list(
      variable = driver_var,
      label = get_var_label(config, driver_var),
      reference = ref_level,
      patterns = pattern_df
    )
  }

  patterns
}
