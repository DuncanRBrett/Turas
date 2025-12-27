# ==============================================================================
# OUTPUT SHEET GENERATORS - TURAS V10.1
# ==============================================================================
# Sheet generators for Summary, Study Level, Representativeness, Methodology,
# Warnings, and Inputs sheets
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.1 - Extracted from 07_output.R (2025-12-27)
#          - Summary sheet with analysis overview
#          - Study-level statistics sheet
#          - Representativeness and weight diagnostics
#          - Methodology documentation sheet
#          - Warnings sheet
#          - Inputs/configuration sheet
#
# DEPENDENCIES:
# - openxlsx (for Excel writing)
# - output_formatting.R (for apply_numeric_formatting, format_decimal)
#
# FUNCTIONS:
# - add_summary_sheet(): Add summary/overview sheet
# - add_study_level_sheet(): Add study-level statistics sheet
# - add_representativeness_sheet(): Add representativeness diagnostics sheet
# - add_methodology_sheet(): Add methodology documentation sheet
# - add_warnings_sheet(): Add warnings and data quality sheet
# - add_inputs_sheet(): Add inputs/configuration sheet
# ==============================================================================

OUTPUT_SHEETS_VERSION <- "10.1"


# ==============================================================================
# SUMMARY SHEET
# ==============================================================================

#' Add summary sheet to workbook (internal)
#' @keywords internal
add_summary_sheet <- function(wb, study_stats, prop_results, mean_results,
                               nps_results, config, warnings, decimal_sep) {

  openxlsx::addWorksheet(wb, "Summary")

  # Title
  row <- 1
  openxlsx::writeData(wb, "Summary", "TURAS CONFIDENCE ANALYSIS - SUMMARY",
                      startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Summary",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 2

  # Analysis Info
  openxlsx::writeData(wb, "Summary", "Analysis Information",
                      startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Summary",
                     style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 1

  info_df <- data.frame(
    Setting = c("Date", "Module Version", "Confidence Level", "Decimal Separator"),
    Value = c(
      format(Sys.Date(), "%Y-%m-%d"),
      OUTPUT_VERSION,
      ifelse(!is.null(config$confidence_level),
             format_decimal(config$confidence_level, decimal_sep, 2),
             "0.95"),
      decimal_sep
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Summary", info_df, startCol = 1, startRow = row,
                      colNames = TRUE, rowNames = FALSE)
  row <- row + nrow(info_df) + 2

  # Study-Level Summary
  if (!is.null(study_stats) && nrow(study_stats) > 0) {
    openxlsx::writeData(wb, "Summary", "Study-Level Statistics",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Summary",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                       rows = row, cols = 1)
    row <- row + 1

    # Write numeric data (not converted to strings)
    openxlsx::writeData(wb, "Summary", study_stats, startCol = 1, startRow = row,
                        colNames = TRUE, rowNames = FALSE)

    # Apply Excel number formatting to preserve numeric values
    apply_numeric_formatting(wb, "Summary", row + 1, 1, study_stats, decimal_sep)

    row <- row + nrow(study_stats) + 2
  }

  # Results Summary
  openxlsx::writeData(wb, "Summary", "Results Summary",
                      startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Summary",
                     style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 1

  summary_df <- data.frame(
    Metric = c("Proportions Analyzed", "Means Analyzed", "NPS Analyzed", "Total Questions"),
    Count = c(
      length(prop_results),
      length(mean_results),
      length(nps_results),
      length(prop_results) + length(mean_results) + length(nps_results)
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Summary", summary_df, startCol = 1, startRow = row,
                      colNames = TRUE, rowNames = FALSE)
  row <- row + nrow(summary_df) + 2

  # Warnings Summary
  if (length(warnings) > 0) {
    openxlsx::writeData(wb, "Summary", "⚠ Warnings",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Summary",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold",
                                                     fontColour = "#FF0000"),
                       rows = row, cols = 1)
    row <- row + 1

    openxlsx::writeData(wb, "Summary",
                        sprintf("%d warnings detected - see Warnings sheet for details",
                                length(warnings)),
                        startCol = 1, startRow = row)
  } else {
    openxlsx::writeData(wb, "Summary", "✓ No Warnings",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Summary",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold",
                                                     fontColour = "#008000"),
                       rows = row, cols = 1)
  }

  # Auto-size columns
  openxlsx::setColWidths(wb, "Summary", cols = 1:2, widths = "auto")
}


# ==============================================================================
# STUDY LEVEL SHEET
# ==============================================================================

#' Add study-level statistics sheet (internal)
#' @keywords internal
add_study_level_sheet <- function(wb, study_stats, decimal_sep) {

  openxlsx::addWorksheet(wb, "Study_Level")

  # Title
  openxlsx::writeData(wb, "Study_Level", "STUDY-LEVEL STATISTICS",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Study_Level",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  # Write numeric data (not converted to strings)
  openxlsx::writeData(wb, "Study_Level", study_stats, startCol = 1, startRow = 3,
                      colNames = TRUE, rowNames = FALSE)

  # Apply Excel number formatting to preserve numeric values
  apply_numeric_formatting(wb, "Study_Level", 4, 1, study_stats, decimal_sep)

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "Study_Level", header_style, rows = 3,
                     cols = 1:ncol(study_stats), gridExpand = TRUE)

  # Interpretation notes
  row <- 3 + nrow(study_stats) + 2
  openxlsx::writeData(wb, "Study_Level", "INTERPRETATION:", startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Study_Level",
                     style = openxlsx::createStyle(textDecoration = "bold"),
                     rows = row, cols = 1)

  row <- row + 1
  notes <- c(
    "DEFF (Design Effect):",
    "  1.00 = No loss of precision from weighting",
    "  1.05-1.20 = Modest loss (5-20%)",
    "  1.20-2.00 = Moderate loss (20-50%)",
    "  >2.00 = Substantial loss (>50%)",
    "",
    "Weight CV (Coefficient of Variation):",
    "  <0.20 = Modest variation",
    "  0.20-0.30 = Moderate variation",
    "  >0.30 = High variation"
  )

  for (note in notes) {
    openxlsx::writeData(wb, "Study_Level", note, startCol = 1, startRow = row)
    row <- row + 1
  }

  # Auto-size columns
  openxlsx::setColWidths(wb, "Study_Level", cols = 1:ncol(study_stats), widths = "auto")
}


# ==============================================================================
# REPRESENTATIVENESS & WEIGHTS SHEET
# ==============================================================================

#' Add representativeness and weight diagnostics sheet (internal)
#' @keywords internal
add_representativeness_sheet <- function(wb, study_stats, decimal_sep) {

  # Extract margin comparison and weight concentration from attributes
  margin_comp <- attr(study_stats, "margin_comparison")
  weight_conc <- attr(study_stats, "weight_concentration")

  # Skip if no data to show
  if (is.null(margin_comp) && is.null(weight_conc)) {
    return(invisible(wb))
  }

  openxlsx::addWorksheet(wb, "Representativeness_Weights")

  row <- 1

  # Title
  openxlsx::writeData(wb, "Representativeness_Weights",
                      "REPRESENTATIVENESS & WEIGHT DIAGNOSTICS",
                      startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Representativeness_Weights",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 2

  # Block A: Weight Concentration Diagnostics
  if (!is.null(weight_conc) && nrow(weight_conc) > 0) {
    openxlsx::writeData(wb, "Representativeness_Weights",
                        "A. Weight Distribution & Concentration",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Representativeness_Weights",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                       rows = row, cols = 1)
    row <- row + 1

    openxlsx::writeData(wb, "Representativeness_Weights",
                        weight_conc,
                        startCol = 1, startRow = row,
                        colNames = TRUE, rowNames = FALSE)

    # Apply numeric formatting
    apply_numeric_formatting(wb, "Representativeness_Weights",
                             row + 1, 1, weight_conc, decimal_sep)

    # Header style
    header_style <- openxlsx::createStyle(
      fontSize = 11,
      textDecoration = "bold",
      fgFill = "#4F81BD",
      fontColour = "#FFFFFF",
      border = "TopBottomLeftRight"
    )
    openxlsx::addStyle(wb, "Representativeness_Weights", header_style,
                       rows = row, cols = 1:ncol(weight_conc), gridExpand = TRUE)

    row <- row + nrow(weight_conc) + 2

    # Interpretation notes for weight concentration
    openxlsx::writeData(wb, "Representativeness_Weights",
                        "Interpretation:",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Representativeness_Weights",
                       style = openxlsx::createStyle(textDecoration = "bold"),
                       rows = row, cols = 1)
    row <- row + 1

    notes_conc <- c(
      "Weight Concentration (Top 5% Share):",
      "  LOW (< 15%): Healthy weight distribution",
      "  MODERATE (15-25%): Acceptable concentration",
      "  HIGH (> 25%): Concerning - few cases dominate weighted sample"
    )

    for (note in notes_conc) {
      openxlsx::writeData(wb, "Representativeness_Weights", note,
                          startCol = 1, startRow = row)
      row <- row + 1
    }

    row <- row + 2
  }

  # Block B: Margin Comparison (Target vs Actual)
  if (!is.null(margin_comp) && nrow(margin_comp) > 0) {
    openxlsx::writeData(wb, "Representativeness_Weights",
                        "B. Population Margin Comparison (Target vs Weighted Sample)",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Representativeness_Weights",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                       rows = row, cols = 1)
    row <- row + 1

    openxlsx::writeData(wb, "Representativeness_Weights",
                        margin_comp,
                        startCol = 1, startRow = row,
                        colNames = TRUE, rowNames = FALSE)

    # Apply numeric formatting
    apply_numeric_formatting(wb, "Representativeness_Weights",
                             row + 1, 1, margin_comp, decimal_sep)

    # Header style
    header_style <- openxlsx::createStyle(
      fontSize = 11,
      textDecoration = "bold",
      fgFill = "#4F81BD",
      fontColour = "#FFFFFF",
      border = "TopBottomLeftRight"
    )
    openxlsx::addStyle(wb, "Representativeness_Weights", header_style,
                       rows = row, cols = 1:ncol(margin_comp), gridExpand = TRUE)

    # Conditional formatting on Flag column
    flag_col <- which(colnames(margin_comp) == "Flag")
    if (length(flag_col) == 1) {
      n_rows <- nrow(margin_comp)

      # RED flag formatting
      openxlsx::conditionalFormatting(
        wb, "Representativeness_Weights",
        cols = flag_col,
        rows = (row + 1):(row + n_rows),
        type = "contains",
        rule = "RED",
        style = openxlsx::createStyle(fontColour = "#9C0006", bgFill = "#FFC7CE")
      )

      # AMBER flag formatting
      openxlsx::conditionalFormatting(
        wb, "Representativeness_Weights",
        cols = flag_col,
        rows = (row + 1):(row + n_rows),
        type = "contains",
        rule = "AMBER",
        style = openxlsx::createStyle(fontColour = "#9C5700", bgFill = "#FFEB9C")
      )

      # GREEN flag formatting
      openxlsx::conditionalFormatting(
        wb, "Representativeness_Weights",
        cols = flag_col,
        rows = (row + 1):(row + n_rows),
        type = "contains",
        rule = "GREEN",
        style = openxlsx::createStyle(fontColour = "#006100", bgFill = "#C6EFCE")
      )
    }

    row <- row + nrow(margin_comp) + 2

    # Interpretation notes for margin comparison
    openxlsx::writeData(wb, "Representativeness_Weights",
                        "Interpretation:",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Representativeness_Weights",
                       style = openxlsx::createStyle(textDecoration = "bold"),
                       rows = row, cols = 1)
    row <- row + 1

    notes_margin <- c(
      "Difference from Target (in percentage points):",
      "  GREEN: |Difference| < 2pp - Excellent representativeness",
      "  AMBER: |Difference| 2-5pp - Acceptable, minor deviation",
      "  RED: |Difference| >= 5pp - Concerning, substantial deviation",
      "",
      "Diff_pp = Weighted_Sample_Pct - Target_Pct",
      "Positive values: Over-represented vs target",
      "Negative values: Under-represented vs target"
    )

    for (note in notes_margin) {
      openxlsx::writeData(wb, "Representativeness_Weights", note,
                          startCol = 1, startRow = row)
      row <- row + 1
    }
  }

  # Auto-size columns
  openxlsx::setColWidths(wb, "Representativeness_Weights", cols = 1:12, widths = "auto")

  invisible(wb)
}


# ==============================================================================
# METHODOLOGY SHEET
# ==============================================================================

#' Add methodology documentation sheet (internal)
#' @keywords internal
add_methodology_sheet <- function(wb) {

  openxlsx::addWorksheet(wb, "Methodology")

  # Title
  openxlsx::writeData(wb, "Methodology", "STATISTICAL METHODOLOGY",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Methodology",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  row <- 3

  # Methodology content
  methodology_text <- c(
    "PROPORTIONS:",
    "",
    "1. Normal Approximation (Margin of Error)",
    "   Formula: MOE = z * sqrt(p*(1-p)/n)",
    "   Use: Large samples (n*p >= 10 and n*(1-p) >= 10)",
    "   Confidence Interval: [p - MOE, p + MOE]",
    "",
    "2. Wilson Score Interval",
    "   Better for extreme proportions (p < 0.1 or p > 0.9)",
    "   Automatically provides asymmetric intervals",
    "   Recommended for small samples or extreme proportions",
    "",
    "3. Bootstrap",
    "   Non-parametric resampling method (5000-10000 iterations)",
    "   No distributional assumptions required",
    "   Percentile method for confidence intervals",
    "",
    "4. Bayesian (Beta-Binomial)",
    "   Posterior: Beta(alpha + x, beta + n - x)",
    "   Uninformed prior: Beta(1,1) = Uniform(0,1)",
    "   Informed prior: Beta from previous wave data",
    "",
    "MEANS:",
    "",
    "1. t-Distribution",
    "   Formula: CI = mean ± t(df) * SE",
    "   SE = sd / sqrt(n_eff)",
    "   Accounts for design effect in weighted data",
    "",
    "2. Bootstrap",
    "   Resampling with replacement (5000-10000 iterations)",
    "   Preserves survey weights if applicable",
    "   Percentile method for confidence intervals",
    "",
    "3. Bayesian (Normal-Normal Conjugate)",
    "   Prior: N(mu0, sigma0²/n0)",
    "   Posterior: Precision-weighted combination of prior and data",
    "   Uninformed: very weak prior (large prior variance)",
    "   Informed: from previous wave statistics",
    "",
    "NET PROMOTER SCORE (NPS):",
    "",
    "Formula: NPS = %Promoters - %Detractors",
    "  Scale: -100 to +100",
    "  Promoters: High scores (typically 9-10 on 0-10 scale)",
    "  Detractors: Low scores (typically 0-6)",
    "  Passives: Middle scores (7-8, not included in NPS)",
    "",
    "1. Normal Approximation",
    "   Variance of difference formula:",
    "   Var(NPS) = Var(prom) + Var(detr)",
    "   SE = sqrt(p_prom*(1-p_prom)/n + p_detr*(1-p_detr)/n) * 100",
    "   Uses n_eff for weighted data",
    "",
    "2. Bootstrap",
    "   Resampling with replacement (5000-10000 iterations)",
    "   Preserves survey weights if applicable",
    "   Percentile method for confidence intervals",
    "",
    "3. Bayesian",
    "   Normal approximation to NPS distribution",
    "   Prior: N(mu0, sigma0²)",
    "   Posterior combines prior and data (precision-weighted)",
    "",
    "WEIGHTING:",
    "",
    "Design Effect (DEFF): DEFF = 1 + CV²",
    "  where CV = coefficient of variation of weights",
    "",
    "Effective Sample Size: n_eff = (Σw)² / Σw²",
    "  Kish (1965) approximation",
    "",
    "Standard errors use effective n for weighted data",
    "",
    "REFERENCES:",
    "",
    "Kish, L. (1965). Survey Sampling. Wiley.",
    "Agresti, A., & Coull, B. A. (1998). Approximate is better than exact.",
    "Wilson, E. B. (1927). Probable inference and statistical inference.",
    "Efron, B., & Tibshirani, R. J. (1994). An Introduction to the Bootstrap."
  )

  for (line in methodology_text) {
    openxlsx::writeData(wb, "Methodology", line, startCol = 1, startRow = row)
    row <- row + 1
  }

  # Auto-size column
  openxlsx::setColWidths(wb, "Methodology", cols = 1, widths = 80)
}


# ==============================================================================
# WARNINGS SHEET
# ==============================================================================

#' Add warnings sheet (internal)
#' @keywords internal
add_warnings_sheet <- function(wb, warnings) {

  openxlsx::addWorksheet(wb, "Warnings")

  # Title
  openxlsx::writeData(wb, "Warnings", "WARNINGS AND DATA QUALITY NOTES",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Warnings",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  row <- 3

  if (length(warnings) == 0) {
    openxlsx::writeData(wb, "Warnings", "✓ No warnings detected",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Warnings",
                       style = openxlsx::createStyle(fontSize = 12, fontColour = "#008000"),
                       rows = row, cols = 1)
  } else {
    # Write warnings
    warnings_df <- data.frame(
      Number = seq_along(warnings),
      Warning = warnings,
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Warnings", warnings_df, startCol = 1, startRow = row,
                        colNames = TRUE, rowNames = FALSE)

    # Header style
    header_style <- openxlsx::createStyle(
      fontSize = 11,
      textDecoration = "bold",
      fgFill = "#FF6B6B",
      fontColour = "#FFFFFF"
    )
    openxlsx::addStyle(wb, "Warnings", header_style, rows = row,
                       cols = 1:2, gridExpand = TRUE)

    # Auto-size columns
    openxlsx::setColWidths(wb, "Warnings", cols = 1:2, widths = "auto")
  }
}


# ==============================================================================
# INPUTS SHEET
# ==============================================================================

#' Add inputs/configuration sheet (internal)
#' @keywords internal
add_inputs_sheet <- function(wb, config, decimal_sep) {

  openxlsx::addWorksheet(wb, "Inputs")

  # Title
  openxlsx::writeData(wb, "Inputs", "INPUT CONFIGURATION",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Inputs",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  row <- 3

  # Study Settings
  openxlsx::writeData(wb, "Inputs", "Study Settings:", startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Inputs",
                     style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 1

  settings_df <- data.frame(
    Setting = c(
      "Confidence Level",
      "Bootstrap Iterations",
      "Multiple Comparison Adjustment",
      "Decimal Separator",
      "Calculate Effective Sample Size"
    ),
    Value = c(
      ifelse(!is.null(config$confidence_level),
             format_decimal(config$confidence_level, decimal_sep, 2), "0.95"),
      ifelse(!is.null(config$bootstrap_iterations),
             as.character(config$bootstrap_iterations), "5000"),
      ifelse(!is.null(config$multiple_comparison_method),
             config$multiple_comparison_method, "None"),
      decimal_sep,
      ifelse(!is.null(config$calculate_effective_n),
             ifelse(config$calculate_effective_n, "Yes", "No"), "Yes")
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Inputs", settings_df, startCol = 1, startRow = row,
                      colNames = TRUE, rowNames = FALSE)

  # Auto-size columns
  openxlsx::setColWidths(wb, "Inputs", cols = 1:2, widths = "auto")
}
