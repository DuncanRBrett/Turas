# ==============================================================================
# CATEGORICAL KEY DRIVER - OUTPUT GENERATION
# ==============================================================================
#
# Creates formatted Excel output with multiple sheets.
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================

#' Generate Excel Output
#'
#' Creates a formatted Excel workbook with all analysis results.
#'
#' @param results Full analysis results list
#' @param config Configuration list
#' @param output_file Path to output Excel file
#' @return Path to created file (invisibly)
#' @export
write_catdriver_output <- function(results, config, output_file) {

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Define styles
  styles <- create_output_styles(wb)

  # Sheet 1: Executive Summary
  add_executive_summary_sheet(wb, results, config, styles)

  # Sheet 2: Importance Summary
  add_importance_sheet(wb, results, config, styles)

  # Sheet 3: Factor Patterns
  add_patterns_sheet(wb, results, config, styles)

  # Sheet 4: Model Summary
  add_model_summary_sheet(wb, results, config, styles)

  # Sheet 5: Odds Ratios (if detailed output)
  if (config$detailed_output) {
    add_odds_ratios_sheet(wb, results, config, styles)
  }

  # Sheet 6: Diagnostics (if detailed output)
  if (config$detailed_output) {
    add_diagnostics_sheet(wb, results, config, styles)
  }

  # Save workbook
  openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)

  invisible(output_file)
}


#' Create Output Styles
#'
#' @param wb Workbook object
#' @return List of style objects
#' @keywords internal
create_output_styles <- function(wb) {

  list(
    # Header style - blue background
    header = openxlsx::createStyle(
      fontColour = "#FFFFFF",
      fgFill = "#4472C4",
      halign = "center",
      valign = "center",
      textDecoration = "bold",
      border = "TopBottomLeftRight",
      borderColour = "#2F5496"
    ),

    # Sub-header style
    subheader = openxlsx::createStyle(
      fgFill = "#D6DCE4",
      halign = "left",
      textDecoration = "bold",
      border = "TopBottomLeftRight"
    ),

    # Title style
    title = openxlsx::createStyle(
      fontSize = 16,
      textDecoration = "bold",
      halign = "left"
    ),

    # Section title
    section = openxlsx::createStyle(
      fontSize = 12,
      textDecoration = "bold",
      halign = "left",
      border = "bottom",
      borderColour = "#4472C4"
    ),

    # Normal text
    normal = openxlsx::createStyle(
      halign = "left",
      valign = "center"
    ),

    # Number format
    number = openxlsx::createStyle(
      halign = "right",
      numFmt = "0.00"
    ),

    # Percentage format
    pct = openxlsx::createStyle(
      halign = "right",
      numFmt = "0.0%"
    ),

    # Integer format
    integer = openxlsx::createStyle(
      halign = "right",
      numFmt = "0"
    ),

    # Reference row (gray background)
    reference = openxlsx::createStyle(
      fgFill = "#E2EFDA",
      halign = "left"
    ),

    # Warning style
    warning = openxlsx::createStyle(
      fgFill = "#FFF2CC",
      halign = "left"
    ),

    # Success style
    success = openxlsx::createStyle(
      fgFill = "#C6EFCE",
      halign = "left"
    ),

    # Error style
    error = openxlsx::createStyle(
      fgFill = "#FFC7CE",
      halign = "left"
    )
  )
}


# ==============================================================================
# SHEET 1: EXECUTIVE SUMMARY
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
  lines <- c(lines, "KEY DRIVER ANALYSIS SUMMARY")
  lines <- c(lines, "===========================")
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
  lines <- c(lines, "")

  # Top drivers
  lines <- c(lines, "TOP DRIVERS (by importance):")
  lines <- c(lines, "")

  importance_df <- results$importance
  n_top <- min(5, nrow(importance_df))

  for (i in 1:n_top) {
    row <- importance_df[i, ]

    lines <- c(lines,
      sprintf("%d. %s (%s%% of explained variation)",
              i, row$label, row$importance_pct))

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

  # Model fit
  lines <- c(lines, "MODEL FIT:")
  fit <- results$model_result$fit_statistics

  if (!is.na(fit$mcfadden_r2)) {
    r2_pct <- round(fit$mcfadden_r2 * 100, 1)
    r2_interp <- interpret_pseudo_r2(fit$mcfadden_r2)
    lines <- c(lines,
      sprintf("* The model explains %s%% of variation in %s",
              r2_pct, config$outcome_label))
    lines <- c(lines, sprintf("* This is a %s", tolower(r2_interp)))
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


# ==============================================================================
# SHEET 2: IMPORTANCE SUMMARY
# ==============================================================================

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

  names(df) <- c("Rank", "Factor", "Label", "Importance %", "Chi-Square",
                 "P-Value", "Sig.", "Effect Size")

  # Format numeric columns
  df$`Chi-Square` <- round(df$`Chi-Square`, 2)
  df$`P-Value` <- sapply(df$`P-Value`, format_pvalue)

  # Write data
  openxlsx::writeData(wb, "Importance Summary", df, startRow = 1, startCol = 1,
                      headerStyle = styles$header)

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


# ==============================================================================
# SHEET 3: FACTOR PATTERNS
# ==============================================================================

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

    out_df$`95% CI` <- ifelse(pattern_df$is_reference, "-",
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


# ==============================================================================
# SHEET 4: MODEL SUMMARY
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


# ==============================================================================
# SHEET 5: ODDS RATIOS (DETAILED)
# ==============================================================================

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


# ==============================================================================
# SHEET 6: DIAGNOSTICS
# ==============================================================================

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


#' Print Console Summary
#'
#' Prints a summary of results to console.
#'
#' @param results Analysis results
#' @param config Configuration
#' @export
print_console_summary <- function(results, config) {

  summary_lines <- generate_executive_summary(results, config)

  cat("\n")
  for (line in summary_lines) {
    cat(line, "\n")
  }
  cat("\n")
}
