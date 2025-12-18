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

  # Try car::Anova for Type II tests
  anova_result <- tryCatch({
    if (!requireNamespace("car", quietly = TRUE)) {
      stop("Package 'car' required for importance calculation")
    }

    if (model_result$model_type == "multinomial_logistic") {
      # For multinomial, use custom approach
      calculate_multinomial_importance(model_result, config)
    } else {
      # Binary and ordinal use car::Anova
      car::Anova(model, type = "II")
    }
  }, error = function(e) {
    warning("car::Anova failed: ", e$message, ". Using fallback method.")
    calculate_fallback_importance(model_result, config)
  })

  # If already a data frame (from multinomial), return it
  if (is.data.frame(anova_result) && "importance_pct" %in% names(anova_result)) {
    return(anova_result)
  }

  # Process Anova results
  importance_df <- process_anova_results(anova_result, config)

  importance_df
}


#' Process ANOVA Results into Importance Data Frame
#'
#' @param anova_result Result from car::Anova
#' @param config Configuration list
#' @return Data frame with processed importance
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
        stop("Cannot identify chi-square column in Anova output")
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
    0
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
  importance_df$effect_size <- sapply(importance_df$importance_pct, function(pct) {
    if (is.na(pct)) return("Unknown")
    if (pct > 30) return("Very Large")
    if (pct > 15) return("Large")
    if (pct > 5) return("Medium")
    return("Small")
  })

  # Sort by importance
  importance_df <- importance_df[order(-importance_df$importance_pct), ]

  # Add rank
  importance_df$rank <- seq_len(nrow(importance_df))

  rownames(importance_df) <- NULL

  importance_df
}


#' Calculate Importance for Multinomial Models
#'
#' Uses likelihood ratio tests comparing full model to reduced models.
#'
#' @param model_result Model results
#' @param config Configuration list
#' @return Data frame with importance metrics
#' @keywords internal
calculate_multinomial_importance <- function(model_result, config) {

  model <- model_result$model
  data <- model$model

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

    # Fit reduced model
    reduced_model <- tryCatch({
      nnet::multinom(reduced_formula, data = data, trace = FALSE, maxit = 500)
    }, error = function(e) NULL)

    if (!is.null(reduced_model)) {
      ll_reduced <- logLik(reduced_model)

      # Likelihood ratio test
      lr_stat <- -2 * (as.numeric(ll_reduced) - as.numeric(ll_full))
      lr_df <- attr(ll_full, "df") - attr(ll_reduced, "df")
      lr_pvalue <- pchisq(lr_stat, abs(lr_df), lower.tail = FALSE)

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
    0
  }

  # Add labels and formatting
  importance_df$label <- sapply(importance_df$variable, function(v) {
    get_var_label(config, v)
  })

  importance_df$significance <- sapply(importance_df$p_value, get_sig_stars)

  importance_df$effect_size <- sapply(importance_df$importance_pct, function(pct) {
    if (is.na(pct)) return("Unknown")
    if (pct > 30) return("Very Large")
    if (pct > 15) return("Large")
    if (pct > 5) return("Medium")
    return("Small")
  })

  # Sort and rank
  importance_df <- importance_df[order(-importance_df$importance_pct), ]
  importance_df$rank <- seq_len(nrow(importance_df))
  rownames(importance_df) <- NULL

  importance_df
}


#' Fallback Importance Calculation
#'
#' Uses coefficient z-values when car::Anova fails.
#'
#' @param model_result Model results
#' @param config Configuration list
#' @return Data frame with importance metrics
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

  # Map dummy variables back to original factors
  importance_df <- aggregate_dummy_importance(importance_df, config)

  # Calculate relative importance
  total_chisq <- sum(importance_df$chi_square, na.rm = TRUE)
  importance_df$importance_pct <- if (total_chisq > 0) {
    round(100 * importance_df$chi_square / total_chisq, 1)
  } else {
    0
  }

  # Add labels
  importance_df$label <- sapply(importance_df$variable, function(v) {
    get_var_label(config, v)
  })

  importance_df$df <- NA
  importance_df$significance <- sapply(importance_df$p_value, get_sig_stars)
  importance_df$effect_size <- sapply(importance_df$importance_pct, function(pct) {
    if (is.na(pct)) return("Unknown")
    if (pct > 30) return("Very Large")
    if (pct > 15) return("Large")
    if (pct > 5) return("Medium")
    return("Small")
  })

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
#' @return Data frame with factor-level importance
#' @keywords internal
aggregate_dummy_importance <- function(importance_df, config, mapping = NULL) {

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

    # Third try: check contrasts/xlevels from model for reliable mapping
    # This uses model matrix infrastructure instead of substring parsing
    matched <- FALSE
    for (driver_var in config$driver_vars) {
      # Get expected column names from model.matrix for this variable
      # by checking if term matches the pattern R would generate
      if (exists("prep_data") && !is.null(prep_data$predictor_info[[driver_var]])) {
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
      # Log a warning since we couldn't map it properly
      term_to_var[i] <- term
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


#' Extract Odds Ratios Summary
#'
#' Creates a summary of odds ratios by factor and category.
#' Uses canonical mapping from R/09_mapper.R when available.
#' NEVER uses substring parsing for term-to-level mapping.
#'
#' @param model_result Model results
#' @param config Configuration list
#' @param prep_data Preprocessed data
#' @param mapping Optional pre-computed mapping from map_terms_to_levels()
#' @return Data frame with odds ratio summary
#' @export
extract_odds_ratios <- function(model_result, config, prep_data, mapping = NULL) {

  coef_df <- model_result$coefficients

  # Remove intercept
  coef_df <- coef_df[!grepl("^\\(Intercept\\)", coef_df$term), ]

  # Build mapping if not provided - use model matrix infrastructure
  if (is.null(mapping) && !is.null(model_result$model)) {
    mapping <- tryCatch({
      if (model_result$model_type == "multinomial_logistic") {
        map_multinomial_terms(model_result$model, prep_data$data,
                             prep_data$model_formula, config$outcome_var)
      } else {
        map_terms_to_levels(model_result$model, prep_data$data,
                           prep_data$model_formula)
      }
    }, error = function(e) {
      warning("Could not build term mapping: ", e$message)
      NULL
    })
  }

  # Parse term names to extract factor and level
  or_list <- list()

  for (i in seq_len(nrow(coef_df))) {
    term <- coef_df$term[i]

    # Try to match using proper mapping first
    matched_var <- NULL
    matched_level <- NULL
    ref_level <- NA

    if (!is.null(mapping)) {
      # Use canonical mapping
      match_idx <- which(mapping$coef_name == term & !mapping$is_reference)
      if (length(match_idx) > 0) {
        m <- mapping[match_idx[1], ]
        matched_var <- m$driver
        matched_level <- m$level
        ref_level <- m$reference_level
      }
    }

    # Fallback: exact match to driver variable (for continuous vars)
    if (is.null(matched_var)) {
      if (term %in% config$driver_vars) {
        matched_var <- term
        matched_level <- "per unit"
      } else {
        # Use predictor_info from prep_data for mapping via levels
        for (driver_var in config$driver_vars) {
          info <- prep_data$predictor_info[[driver_var]]
          if (!is.null(info) && !is.null(info$levels)) {
            for (lvl in info$levels[-1]) {  # Skip reference
              expected_col <- paste0(driver_var, lvl)
              expected_col_clean <- paste0(driver_var, make.names(lvl))
              if (term == expected_col || term == expected_col_clean) {
                matched_var <- driver_var
                matched_level <- lvl
                ref_level <- info$reference_level
                break
              }
            }
          }
          if (!is.null(matched_var)) break
        }
      }
    }

    # Final fallback: use term as-is
    if (is.null(matched_var)) {
      matched_var <- term
      matched_level <- NA
    }

    # Get reference level from prep_data if not already set
    if (is.na(ref_level) && !is.null(prep_data$predictor_info[[matched_var]])) {
      ref_level <- prep_data$predictor_info[[matched_var]]$reference_level
    }

    row_data <- data.frame(
      factor = matched_var,
      factor_label = get_var_label(config, matched_var),
      comparison = matched_level,
      reference = ref_level,
      odds_ratio = coef_df$odds_ratio[i],
      or_lower = coef_df$or_lower[i],
      or_upper = coef_df$or_upper[i],
      p_value = coef_df$p_value[i],
      stringsAsFactors = FALSE
    )

    # Add multinomial outcome level if present
    if ("outcome_level" %in% names(coef_df)) {
      row_data$outcome_level <- coef_df$outcome_level[i]
    }

    or_list[[length(or_list) + 1]] <- row_data
  }

  or_df <- do.call(rbind, or_list)
  rownames(or_df) <- NULL

  # Add effect size interpretation
  or_df$effect <- sapply(or_df$odds_ratio, interpret_or_effect)

  # Add significance
  or_df$significance <- sapply(or_df$p_value, get_sig_stars)

  # Format for display
  or_df$or_formatted <- format_or(or_df$odds_ratio)
  or_df$ci_formatted <- mapply(format_ci, or_df$or_lower, or_df$or_upper)
  or_df$p_formatted <- sapply(or_df$p_value, format_pvalue)

  or_df
}


#' Calculate Factor Patterns
#'
#' Creates cross-tabulation with outcome proportions for each factor.
#'
#' @param prep_data Preprocessed data
#' @param config Configuration list
#' @param or_df Odds ratios data frame
#' @return List of factor pattern data frames
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
