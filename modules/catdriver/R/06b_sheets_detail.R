# ==============================================================================
# CATEGORICAL KEY DRIVER - DETAILED OUTPUT SHEETS
# ==============================================================================
#
# Model summary, odds ratios, and diagnostics sheets.
# Extracted from 06_output.R for maintainability.
#
# Version: 2.0
# ==============================================================================

#' Add Model Summary Sheet
#'
#' @param wb Workbook
#' @param results Analysis results
#' @param config Configuration
#' @param styles Style list
#' @keywords internal
add_model_summary_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "Model Summary")

  model_result <- results$model_result
  fit <- model_result$fit_statistics

  # Build summary data frame
  summary_data <- data.frame(
    Metric = character(0),
    Value = character(0),
    Interpretation = character(0),
    stringsAsFactors = FALSE
  )

  # Model type
  model_type_label <- switch(model_result$outcome_type,
    binary = "Binary Logistic Regression",
    ordinal = "Ordinal Logistic Regression (Proportional Odds)",
    nominal = "Multinomial Logistic Regression"
  )

  summary_data <- rbind(summary_data, data.frame(
    Metric = "Model Type", Value = model_type_label, Interpretation = ""
  ))

  summary_data <- rbind(summary_data, data.frame(
    Metric = "Outcome Variable",
    Value = paste0(config$outcome_label, " (", config$outcome_var, ")"),
    Interpretation = ""
  ))

  # Sample size
  summary_data <- rbind(summary_data, data.frame(
    Metric = "Original Sample Size",
    Value = as.character(results$diagnostics$original_n),
    Interpretation = ""
  ))

  summary_data <- rbind(summary_data, data.frame(
    Metric = "Complete Cases Used",
    Value = sprintf("%d (%s%%)", results$diagnostics$complete_n, results$diagnostics$pct_complete),
    Interpretation = if (results$diagnostics$pct_complete >= 90) "Good - minimal data loss" else "Some data excluded due to missing values"
  ))

  summary_data <- rbind(summary_data, data.frame(
    Metric = "Number of Predictors",
    Value = sprintf("%d factors (%d terms)", length(config$driver_vars), results$prep_data$n_terms),
    Interpretation = ""
  ))

  # Fit statistics
  if (!is.na(fit$mcfadden_r2)) {
    summary_data <- rbind(summary_data, data.frame(
      Metric = "McFadden Pseudo-R2",
      Value = sprintf("%.3f", fit$mcfadden_r2),
      Interpretation = interpret_pseudo_r2(fit$mcfadden_r2)
    ))
  }

  summary_data <- rbind(summary_data, data.frame(
    Metric = "AIC",
    Value = sprintf("%.1f", fit$aic),
    Interpretation = ""
  ))

  if (!is.na(fit$lr_statistic)) {
    summary_data <- rbind(summary_data, data.frame(
      Metric = "LR Test vs Null",
      Value = sprintf("chi2(%d) = %.1f, p %s", fit$lr_df, fit$lr_statistic, format_pvalue(fit$lr_pvalue)),
      Interpretation = if (fit$lr_pvalue < 0.05) "Model significantly better than null" else "Model not significantly better than null"
    ))
  }

  # Convergence
  summary_data <- rbind(summary_data, data.frame(
    Metric = "Convergence",
    Value = if (model_result$convergence) "Yes" else "No/Warning",
    Interpretation = if (model_result$convergence) "Model converged normally" else "Check results carefully"
  ))

  # Write to sheet
  openxlsx::writeData(wb, "Model Summary", summary_data,
                      startRow = 1, startCol = 1,
                      headerStyle = styles$header)

  openxlsx::setColWidths(wb, "Model Summary", cols = 1:3, widths = c(25, 40, 45))

  # Add pseudo-R2 interpretation guide
  start_row <- nrow(summary_data) + 4

  openxlsx::writeData(wb, "Model Summary", "Pseudo-R2 Interpretation Guide:",
                      startRow = start_row, startCol = 1)
  openxlsx::addStyle(wb, "Model Summary", styles$section,
                     rows = start_row, cols = 1)

  r2_guide <- data.frame(
    `McFadden R2` = c("0.4+", "0.2 - 0.4", "0.1 - 0.2", "< 0.1"),
    Interpretation = c("Excellent fit", "Good fit", "Moderate fit", "Limited explanatory power"),
    check.names = FALSE
  )

  openxlsx::writeData(wb, "Model Summary", r2_guide,
                      startRow = start_row + 1, startCol = 1,
                      headerStyle = styles$subheader)
}


#' Add Odds Ratios Sheet
#'
#' @param wb Workbook
#' @param results Analysis results
#' @param config Configuration
#' @param styles Style list
#' @keywords internal
add_odds_ratios_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "Odds Ratios")

  or_df <- results$odds_ratios

  # Select columns for output
  out_cols <- c("factor_label", "comparison", "reference",
                "or_formatted", "ci_formatted", "p_formatted", "significance", "effect")

  # Handle multinomial (has outcome_level column)
  if ("outcome_level" %in% names(or_df)) {
    out_cols <- c("outcome_level", out_cols)
  }

  out_df <- or_df[, out_cols, drop = FALSE]

  # Rename columns
  col_names <- c("Factor", "Comparison", "Reference", "Odds Ratio",
                 "95% CI", "P-Value", "Sig.", "Effect")
  if ("outcome_level" %in% names(or_df)) {
    col_names <- c("Outcome Level", col_names)
  }
  names(out_df) <- col_names

  # Write data
  openxlsx::writeData(wb, "Odds Ratios", out_df,
                      startRow = 1, startCol = 1,
                      headerStyle = styles$header)

  openxlsx::setColWidths(wb, "Odds Ratios", cols = 1:ncol(out_df), widths = "auto")

  # Add OR interpretation guide
  start_row <- nrow(out_df) + 4

  openxlsx::writeData(wb, "Odds Ratios", "Odds Ratio Interpretation Guide:",
                      startRow = start_row, startCol = 1)
  openxlsx::addStyle(wb, "Odds Ratios", styles$section,
                     rows = start_row, cols = 1)

  or_guide <- data.frame(
    `Odds Ratio` = c("0.9 - 1.1", "0.67 - 0.9 or 1.1 - 1.5", "0.5 - 0.67 or 1.5 - 2.0",
                    "0.33 - 0.5 or 2.0 - 3.0", "< 0.33 or > 3.0"),
    Effect = c("Negligible", "Small", "Medium", "Large", "Very Large"),
    Interpretation = c("No meaningful difference",
                      "Minor difference, may not be actionable",
                      "Meaningful difference worth attention",
                      "Substantial difference, high priority",
                      "Major difference, investigate thoroughly"),
    check.names = FALSE
  )

  openxlsx::writeData(wb, "Odds Ratios", or_guide,
                      startRow = start_row + 1, startCol = 1,
                      headerStyle = styles$subheader)
}


#' Add Diagnostics Sheet
#'
#' @param wb Workbook
#' @param results Analysis results
#' @param config Configuration
#' @param styles Style list
#' @keywords internal
add_diagnostics_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "Diagnostics")

  diag <- results$diagnostics
  current_row <- 1

  # Section 1: Data Quality Checks
  openxlsx::writeData(wb, "Diagnostics", "Data Quality Checks",
                      startRow = current_row, startCol = 1)
  openxlsx::addStyle(wb, "Diagnostics", styles$section,
                     rows = current_row, cols = 1)
  current_row <- current_row + 1

  checks <- data.frame(
    Check = character(0),
    Status = character(0),
    Details = character(0),
    `Action Required` = character(0),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  # Sample size check
  checks <- rbind(checks, data.frame(
    Check = "Sample size",
    Status = if (diag$complete_n >= config$min_sample_size) "PASS" else "FAIL",
    Details = sprintf("N=%d (min %d required)", diag$complete_n, config$min_sample_size),
    `Action Required` = if (diag$complete_n >= config$min_sample_size) "None" else "Increase sample or reduce predictors",
    check.names = FALSE
  ))

  # Complete cases check
  checks <- rbind(checks, data.frame(
    Check = "Complete cases",
    Status = if (diag$pct_complete >= 70) "PASS" else if (diag$pct_complete >= 50) "WARNING" else "FAIL",
    Details = sprintf("%s%% complete (%d/%d)", diag$pct_complete, diag$complete_n, diag$original_n),
    `Action Required` = if (diag$pct_complete >= 70) "None" else "Investigate missing data",
    check.names = FALSE
  ))

  # Convergence check
  checks <- rbind(checks, data.frame(
    Check = "Model convergence",
    Status = if (results$model_result$convergence) "PASS" else "WARNING",
    Details = if (results$model_result$convergence) "Converged normally" else "Did not fully converge",
    `Action Required` = if (results$model_result$convergence) "None" else "Simplify model",
    check.names = FALSE
  ))

  # Small cells check
  has_small_cells <- length(diag$small_cells) > 0
  checks <- rbind(checks, data.frame(
    Check = "Small cells",
    Status = if (!has_small_cells) "PASS" else "WARNING",
    Details = if (!has_small_cells) "No cells < 5 observations" else sprintf("%d predictors with small cells", length(diag$small_cells)),
    `Action Required` = if (!has_small_cells) "None" else "Consider collapsing categories",
    check.names = FALSE
  ))

  openxlsx::writeData(wb, "Diagnostics", checks,
                      startRow = current_row, startCol = 1,
                      headerStyle = styles$header)

  # Apply conditional formatting
  for (i in 1:nrow(checks)) {
    row_num <- current_row + i
    status <- checks$Status[i]

    style <- switch(status,
      "PASS" = styles$success,
      "WARNING" = styles$warning,
      "FAIL" = styles$error,
      styles$normal
    )

    openxlsx::addStyle(wb, "Diagnostics", style,
                       rows = row_num, cols = 2)
  }

  current_row <- current_row + nrow(checks) + 3

  # Section 2: Missing Data Summary
  openxlsx::writeData(wb, "Diagnostics", "Missing Data Summary",
                      startRow = current_row, startCol = 1)
  openxlsx::addStyle(wb, "Diagnostics", styles$section,
                     rows = current_row, cols = 1)
  current_row <- current_row + 1

  if (!is.null(diag$missing_summary)) {
    miss_df <- diag$missing_summary[, c("Variable", "Label", "N_Missing", "Pct_Missing")]
    names(miss_df) <- c("Variable", "Label", "N Missing", "% Missing")
    miss_df$`% Missing` <- paste0(miss_df$`% Missing`, "%")

    openxlsx::writeData(wb, "Diagnostics", miss_df,
                        startRow = current_row, startCol = 1,
                        headerStyle = styles$subheader)

    current_row <- current_row + nrow(miss_df) + 3
  }

  # Section 3: Warnings
  if (length(diag$warnings) > 0) {
    openxlsx::writeData(wb, "Diagnostics", "Warnings",
                        startRow = current_row, startCol = 1)
    openxlsx::addStyle(wb, "Diagnostics", styles$section,
                       rows = current_row, cols = 1)
    current_row <- current_row + 1

    for (warn in diag$warnings) {
      openxlsx::writeData(wb, "Diagnostics", paste0("- ", warn),
                          startRow = current_row, startCol = 1)
      openxlsx::addStyle(wb, "Diagnostics", styles$warning,
                         rows = current_row, cols = 1)
      current_row <- current_row + 1
    }
  }

  openxlsx::setColWidths(wb, "Diagnostics", cols = 1:4, widths = c(20, 15, 40, 30))
}
