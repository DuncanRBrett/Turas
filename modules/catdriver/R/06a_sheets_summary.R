# ==============================================================================
# CATEGORICAL KEY DRIVER - SUMMARY OUTPUT SHEETS
# ==============================================================================
#
# Executive summary and importance sheets.
# Extracted from 06_output.R for maintainability.
#
# Version: 2.0
# ==============================================================================

#' Add Executive Summary Sheet
#'
#' @param wb Workbook
#' @param results Analysis results
#' @param config Configuration
#' @param styles Style list
#' @keywords internal
add_executive_summary_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "Executive Summary")

  # Generate summary text
  summary_lines <- generate_executive_summary(results, config)

  # Write as text rows
  row <- 1

  for (line in summary_lines) {
    openxlsx::writeData(wb, "Executive Summary", line, startRow = row, startCol = 1)

    # Apply styles based on content
    if (grepl("^KEY DRIVER|^===|^TOP DRIVERS|^KEY INSIGHTS|^MODEL FIT|^CAUTIONS", line)) {
      openxlsx::addStyle(wb, "Executive Summary", styles$section, rows = row, cols = 1)
    } else if (grepl("^[0-9]+\\.", line)) {
      openxlsx::addStyle(wb, "Executive Summary", styles$subheader, rows = row, cols = 1)
    }

    row <- row + 1
  }

  # Set column width
  openxlsx::setColWidths(wb, "Executive Summary", cols = 1, widths = 100)
}


#' Generate Executive Summary Text
#'
#' @param results Analysis results
#' @param config Configuration
#' @return Character vector of summary lines
#' @keywords internal
generate_executive_summary <- function(results, config) {

  lines <- character(0)

  # Header
  analysis_name <- config$analysis_name %||% "Categorical Key Driver Analysis"
  lines <- c(lines, toupper(analysis_name))
  lines <- c(lines, paste(rep("=", nchar(analysis_name)), collapse = ""))
  lines <- c(lines, "")

  # Basic info
  outcome_info <- results$prep_data$outcome_info
  model_type_label <- switch(outcome_info$type,
    binary = "Binary Logistic Regression",
    ordinal = "Ordinal Logistic Regression (Proportional Odds)",
    nominal = "Multinomial Logistic Regression"
  )

  lines <- c(lines,
    sprintf("Outcome: %s (%d categories: %s)",
            config$outcome_label,
            outcome_info$n_categories,
            paste(outcome_info$categories, collapse = ", ")))

  lines <- c(lines,
    sprintf("Sample: %d respondents (of %d total, %s%% complete)",
            results$diagnostics$complete_n,
            results$diagnostics$original_n,
            results$diagnostics$pct_complete))

  lines <- c(lines, sprintf("Model: %s", model_type_label))

  # Weight status
  if (!is.null(results$weight_diagnostics)) {
    wd <- results$weight_diagnostics
    lines <- c(lines,
      sprintf("Weighting: %s (effective n=%d, %.0f%% of actual)",
              config$weight_var, round(wd$effective_n),
              round(wd$effective_n / results$diagnostics$analysis_n * 100)))
  } else {
    lines <- c(lines, "Weighting: None (unweighted analysis)")
  }

  lines <- c(lines, "")

  # Model confidence statement
  fit <- results$model_result$fit_statistics
  if (!is.na(fit$mcfadden_r2)) {
    r2_pct <- round(fit$mcfadden_r2 * 100, 1)
    if (fit$mcfadden_r2 >= 0.4) {
      lines <- c(lines,
        sprintf("MODEL CONFIDENCE: EXCELLENT - The %d measured factors explain %.1f%% of the variation in %s. This is a strong model with high predictive value.",
                length(config$driver_vars), r2_pct, config$outcome_label))
    } else if (fit$mcfadden_r2 >= 0.2) {
      lines <- c(lines,
        sprintf("MODEL CONFIDENCE: GOOD - The %d measured factors explain %.1f%% of the variation in %s. The model captures meaningful patterns in the data.",
                length(config$driver_vars), r2_pct, config$outcome_label))
    } else if (fit$mcfadden_r2 >= 0.1) {
      lines <- c(lines,
        sprintf("MODEL CONFIDENCE: MODERATE - The %d measured factors explain %.1f%% of the variation in %s. Other unmeasured factors likely also play a role.",
                length(config$driver_vars), r2_pct, config$outcome_label))
    } else {
      lines <- c(lines,
        sprintf("MODEL CONFIDENCE: LIMITED - The %d measured factors explain only %.1f%% of the variation in %s. Key drivers not captured in this data likely influence the outcome.",
                length(config$driver_vars), r2_pct, config$outcome_label))
    }
    lines <- c(lines, "")
  }

  # Top drivers
  lines <- c(lines, "TOP DRIVERS (by importance):")
  lines <- c(lines, "")

  importance_df <- results$importance
  n_top <- min(5, nrow(importance_df))

  for (i in 1:n_top) {
    row <- importance_df[i, ]

    sig_marker <- if (!is.null(row$significance) && row$significance != "") {
      paste0(" ", row$significance)
    } else {
      ""
    }

    lines <- c(lines,
      sprintf("%d. %s (%s%% of explained variation%s)",
              i, row$label, row$importance_pct, sig_marker))

    # Try to generate insight for top 3
    if (i <= 3) {
      insight <- generate_driver_insight(row, results, config)
      if (!is.null(insight)) {
        lines <- c(lines, paste("   ->", insight))
      }
    }

    lines <- c(lines, "")
  }

  # Key insights
  lines <- c(lines, "KEY INSIGHTS:")

  insights <- generate_key_insights(results, config)
  for (insight in insights) {
    lines <- c(lines, paste0("* ", insight))
  }
  lines <- c(lines, "")

  # Model fit details
  lines <- c(lines, "MODEL FIT:")

  if (!is.na(fit$mcfadden_r2)) {
    r2_interp <- interpret_pseudo_r2(fit$mcfadden_r2)
    lines <- c(lines,
      sprintf("* McFadden R2 = %.3f (%s)", fit$mcfadden_r2, tolower(r2_interp)))
  }
  if (!is.na(fit$aic)) {
    lines <- c(lines, sprintf("* AIC = %.1f", fit$aic))
  }
  if (!is.na(fit$lr_statistic)) {
    lines <- c(lines,
      sprintf("* LR test: chi2(%d) = %.1f, p %s",
              fit$lr_df, fit$lr_statistic, format_pvalue(fit$lr_pvalue)))
  }
  lines <- c(lines, "")

  # Cautions
  if (length(results$diagnostics$warnings) > 0) {
    lines <- c(lines, "CAUTIONS:")
    for (warn in results$diagnostics$warnings[1:min(5, length(results$diagnostics$warnings))]) {
      lines <- c(lines, paste0("* ", warn))
    }
  }

  lines
}


#' Generate Driver Insight
#'
#' @param driver_row Row from importance data frame
#' @param results Analysis results
#' @param config Configuration
#' @return Character insight or NULL
#' @keywords internal
generate_driver_insight <- function(driver_row, results, config) {

  var_name <- driver_row$variable
  patterns <- results$factor_patterns[[var_name]]

  if (is.null(patterns)) {
    return(NULL)
  }

  pattern_df <- patterns$patterns

  # Find category with highest OR
  non_ref <- pattern_df[!pattern_df$is_reference, ]
  if (nrow(non_ref) == 0) {
    return(NULL)
  }

  max_or_idx <- which.max(non_ref$odds_ratio)
  max_cat <- non_ref$category[max_or_idx]
  max_or <- non_ref$odds_ratio[max_or_idx]
  ref_cat <- patterns$reference

  # Check for valid OR (handle NA and values <= 1)
  if (length(max_or) == 0 || is.na(max_or) || max_or <= 1) {
    return(NULL)
  }

  sprintf("%s respondents are %.1fx more likely to report higher %s compared to %s respondents.",
          max_cat, max_or, config$outcome_label, ref_cat)
}


#' Generate Key Insights
#'
#' @param results Analysis results
#' @param config Configuration
#' @return Character vector of insights
#' @keywords internal
generate_key_insights <- function(results, config) {

  insights <- character(0)

  # Insight about dominant driver
  if (nrow(results$importance) > 0) {
    top_driver <- results$importance[1, ]
    if (top_driver$importance_pct > 30) {
      insights <- c(insights,
        sprintf("%s is the dominant predictor - interventions targeting this factor may have the greatest impact.",
                top_driver$label))
    }
  }

  # Insight about model fit
  fit <- results$model_result$fit_statistics
  if (!is.na(fit$mcfadden_r2) && fit$mcfadden_r2 < 0.15) {
    insights <- c(insights,
      "Model explanatory power is limited. Other unmeasured factors may influence the outcome.")
  }

  # Insight about data quality
  if (results$diagnostics$pct_complete < 80) {
    insights <- c(insights,
      sprintf("%.0f%% of respondents excluded due to missing data. Investigate patterns in missingness.",
              100 - results$diagnostics$pct_complete))
  }

  if (length(insights) == 0) {
    insights <- c(insights, "Analysis completed successfully. Review factor patterns for detailed insights.")
  }

  insights
}


#' Add Importance Sheet
#'
#' @param wb Workbook
#' @param results Analysis results
#' @param config Configuration
#' @param styles Style list
#' @keywords internal
add_importance_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "Importance Summary")

  # Prepare data
  df <- results$importance[, c("rank", "variable", "label", "importance_pct",
                               "chi_square", "p_value", "significance", "effect_size")]

  # Column names with model-based labels for transparency
  names(df) <- c("Rank", "Factor", "Label", "Importance %", "Chi-Square",
                 "P-Value (model-based)", "Sig.", "Effect Size")

  # Format numeric columns
  df$`Chi-Square` <- round(df$`Chi-Square`, 2)
  df$`P-Value (model-based)` <- sapply(df$`P-Value (model-based)`, format_pvalue)

  # Write data
  openxlsx::writeData(wb, "Importance Summary", df, startRow = 1, startCol = 1,
                      headerStyle = styles$header)

  # Apply significance-based row highlighting
  sig_strong <- openxlsx::createStyle(fgFill = "#C6EFCE")  # green for *** and **
  sig_moderate <- openxlsx::createStyle(fgFill = "#FFF2CC")  # amber for *
  sig_none <- openxlsx::createStyle(fgFill = "#FCE4EC")  # light red for n.s.

  for (i in seq_len(nrow(df))) {
    sig_val <- trimws(df$Sig.[i])
    row_style <- if (grepl("\\*\\*", sig_val)) sig_strong
                 else if (grepl("\\*", sig_val)) sig_moderate
                 else sig_none

    openxlsx::addStyle(wb, "Importance Summary", row_style,
                       rows = i + 1, cols = 7)  # Sig. column
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Importance Summary",
                         cols = 1:ncol(df),
                         widths = c(6, 20, 30, 12, 12, 12, 8, 12))

  # Add interpretation guide below
  start_row <- nrow(df) + 4

  guide_df <- data.frame(
    `Importance %` = c("> 30%", "15-30%", "5-15%", "< 5%"),
    Interpretation = c("Dominant driver - primary focus",
                      "Major driver - significant influence",
                      "Moderate driver - worth considering",
                      "Minor driver - limited impact"),
    check.names = FALSE
  )

  openxlsx::writeData(wb, "Importance Summary", "Interpretation Guide:",
                      startRow = start_row, startCol = 1)
  openxlsx::addStyle(wb, "Importance Summary", styles$section,
                     rows = start_row, cols = 1)

  openxlsx::writeData(wb, "Importance Summary", guide_df,
                      startRow = start_row + 1, startCol = 1,
                      headerStyle = styles$subheader)
}


#' Add Factor Patterns Sheet
#'
#' @param wb Workbook
#' @param results Analysis results
#' @param config Configuration
#' @param styles Style list
#' @keywords internal
add_patterns_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "Factor Patterns")

  current_row <- 1

  for (var_name in config$driver_vars) {
    patterns <- results$factor_patterns[[var_name]]
    if (is.null(patterns)) next

    # Write factor title
    openxlsx::writeData(wb, "Factor Patterns",
                        paste0(patterns$label, " (", var_name, ")"),
                        startRow = current_row, startCol = 1)
    openxlsx::addStyle(wb, "Factor Patterns", styles$section,
                       rows = current_row, cols = 1)
    current_row <- current_row + 1

    # Prepare pattern data
    pattern_df <- patterns$patterns

    # Build output columns
    out_df <- data.frame(
      Category = pattern_df$category,
      N = pattern_df$n,
      `% of Total` = paste0(pattern_df$pct_of_total, "%"),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )

    # Add outcome proportion columns
    outcome_cols <- grep("^pct_", names(pattern_df), value = TRUE)
    for (col in outcome_cols) {
      level_name <- sub("^pct_", "", col)
      out_df[[level_name]] <- paste0(pattern_df[[col]], "%")
    }

    # Add OR columns
    out_df$`OR vs Ref` <- ifelse(pattern_df$is_reference, "1.00 (ref)",
                                 format_or(pattern_df$odds_ratio))

    out_df$`95% CI (model-based)` <- ifelse(pattern_df$is_reference, "-",
                              mapply(format_ci, pattern_df$or_lower, pattern_df$or_upper))

    out_df$Effect <- pattern_df$effect

    # Write data
    openxlsx::writeData(wb, "Factor Patterns", out_df,
                        startRow = current_row, startCol = 1,
                        headerStyle = styles$header)

    # Highlight reference row
    ref_row <- which(pattern_df$is_reference) + current_row
    if (length(ref_row) > 0) {
      openxlsx::addStyle(wb, "Factor Patterns", styles$reference,
                         rows = ref_row, cols = 1:ncol(out_df),
                         gridExpand = TRUE)
    }

    current_row <- current_row + nrow(out_df) + 3
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Factor Patterns", cols = 1:10, widths = "auto")
}
