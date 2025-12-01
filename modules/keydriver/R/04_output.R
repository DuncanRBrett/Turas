# ==============================================================================
# KEY DRIVER OUTPUT WRITER
# ==============================================================================

#' Calculate VIF (Variance Inflation Factor)
#' @keywords internal
calculate_vif <- function(model) {
  # Get model matrix (excluding intercept)
  X <- stats::model.matrix(model)[, -1, drop = FALSE]

  # Calculate VIF for each predictor
  vif_vals <- numeric(ncol(X))
  names(vif_vals) <- colnames(X)

  for (i in seq_len(ncol(X))) {
    # Regress predictor i on all other predictors
    r_squared <- summary(stats::lm(X[, i] ~ X[, -i]))$r.squared
    vif_vals[i] <- 1 / (1 - r_squared)
  }

  vif_vals
}


#' Write Key Driver Results to Excel
#'
#' @keywords internal
write_keydriver_output <- function(importance, model, correlations, config, output_file) {

  wb <- openxlsx::createWorkbook()

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    fontColour = "#FFFFFF",
    fgFill = "#4472C4",
    halign = "left",
    valign = "center",
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )

  # ----------------------------------------------------------------------
  # Sheet 1: Importance Summary
  # ----------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Importance Summary")

  summary_cols <- c("Driver", "Label", "Shapley_Value", "Relative_Weight",
                    "Beta_Weight", "Beta_Coefficient", "Correlation", "Average_Rank")

  if (all(summary_cols %in% names(importance))) {
    summary_data <- importance[, summary_cols, drop = FALSE]
    names(summary_data) <- c("Driver", "Label", "Shapley (%)", "Rel. Weight (%)",
                             "Beta Weight (%)", "Beta Coef", "Correlation (r)", "Avg Rank")
  } else {
    # Fallback if column names differ
    summary_data <- importance
  }

  openxlsx::writeData(wb, "Importance Summary", summary_data, startRow = 1)
  openxlsx::addStyle(wb, "Importance Summary", header_style, rows = 1,
                     cols = 1:ncol(summary_data), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Importance Summary", cols = 1:ncol(summary_data),
                         widths = "auto")

  # ----------------------------------------------------------------------
  # Sheet 2: Detailed Rankings
  # ----------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Method Rankings")

  ranking_cols <- c("Driver", "Label", "Shapley_Rank", "RelWeight_Rank",
                    "Beta_Rank", "Corr_Rank", "Average_Rank")

  if (all(ranking_cols %in% names(importance))) {
    ranking_data <- importance[, ranking_cols, drop = FALSE]
    names(ranking_data) <- c("Driver", "Label", "Shapley Rank", "Rel. Weight Rank",
                             "Beta Rank", "Corr Rank", "Average Rank")
  } else {
    ranking_data <- importance
  }

  openxlsx::writeData(wb, "Method Rankings", ranking_data, startRow = 1)
  openxlsx::addStyle(wb, "Method Rankings", header_style, rows = 1,
                     cols = 1:ncol(ranking_data), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Method Rankings", cols = 1:ncol(ranking_data),
                         widths = "auto")

  # ----------------------------------------------------------------------
  # Sheet 3: Model Summary + VIF Diagnostics
  # ----------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Model Summary")

  model_summary <- data.frame(
    Metric = c("R-Squared", "Adj R-Squared", "F-Statistic", "P-Value", "RMSE", "N"),
    Value = c(
      summary(model)$r.squared,
      summary(model)$adj.r.squared,
      summary(model)$fstatistic[1],
      pf(summary(model)$fstatistic[1],
         summary(model)$fstatistic[2],
         summary(model)$fstatistic[3],
         lower.tail = FALSE),
      sqrt(mean(residuals(model)^2)),
      nobs(model)
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Model Summary", model_summary, startRow = 1)
  openxlsx::addStyle(wb, "Model Summary", header_style, rows = 1,
                     cols = 1:2, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Model Summary", cols = 1:2, widths = "auto")

  # Add VIF diagnostics
  tryCatch({
    vif_vals <- calculate_vif(model)
    vif_df <- data.frame(
      Driver = names(vif_vals),
      VIF = as.numeric(vif_vals),
      stringsAsFactors = FALSE
    )
    vif_df$Warning <- ifelse(vif_df$VIF > 10, "High VIF (>10)",
                             ifelse(vif_df$VIF > 5, "Moderate VIF (>5)", "OK"))

    openxlsx::writeData(wb, "Model Summary", "VIF Diagnostics",
                       startRow = nrow(model_summary) + 3, startCol = 1)
    openxlsx::writeData(wb, "Model Summary", vif_df,
                       startRow = nrow(model_summary) + 4, startCol = 1)
    openxlsx::addStyle(wb, "Model Summary", header_style,
                      rows = nrow(model_summary) + 4,
                      cols = 1:3, gridExpand = TRUE)
  }, error = function(e) {
    # VIF calculation failed, skip
    NULL
  })

  # ----------------------------------------------------------------------
  # Sheet 4: Correlation Matrix
  # ----------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Correlations")
  cor_df <- as.data.frame(correlations)
  cor_df <- cbind(Variable = rownames(cor_df), cor_df)
  rownames(cor_df) <- NULL

  openxlsx::writeData(wb, "Correlations", cor_df, startRow = 1)
  openxlsx::addStyle(wb, "Correlations", header_style, rows = 1,
                     cols = 1:ncol(cor_df), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Correlations", cols = 1:ncol(cor_df), widths = "auto")

  # ----------------------------------------------------------------------
  # Sheet 5: Charts (Shapley impact bar chart)
  # ----------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Charts")

  if ("Shapley_Value" %in% names(importance)) {
    # Small data frame for chart
    chart_data <- importance[order(importance$Shapley_Value, decreasing = TRUE),
                             c("Driver", "Label", "Shapley_Value"), drop = FALSE]
    names(chart_data) <- c("Driver", "Label", "Shapley_Percent")

    openxlsx::writeData(wb, "Charts", chart_data, startRow = 1, startCol = 1)

    # Build the bar plot and insert it below the table
    plot_row_start <- nrow(chart_data) + 4

    # Create temporary file for plot
    plot_file <- tempfile(fileext = ".png")

    # Use Label if available, otherwise Driver
    labels <- ifelse(
      is.na(chart_data$Label) | chart_data$Label == "",
      chart_data$Driver,
      chart_data$Label
    )

    # Create and save plot
    grDevices::png(filename = plot_file, width = 800, height = 600, res = 100)
    graphics::par(mar = c(5, 14, 4, 2))  # Extra left margin for labels
    graphics::barplot(
      height = chart_data$Shapley_Percent,
      names.arg = labels,
      horiz = TRUE,
      las = 1,
      col = "#4472C4",
      xlab = "Shapley Impact (%)",
      main = "Key Driver Impact (Shapley Values)"
    )
    grDevices::dev.off()

    # Insert the saved plot
    openxlsx::insertImage(
      wb,
      sheet = "Charts",
      file = plot_file,
      startRow = plot_row_start,
      startCol = 1,
      width = 7,
      height = 5,
      units = "in"
    )

    # Clean up temp file
    unlink(plot_file)
  } else {
    openxlsx::writeData(wb, "Charts",
                       "Shapley_Value column not found; chart not generated.",
                       startRow = 1, startCol = 1)
  }

  # ----------------------------------------------------------------------
  # Sheet 6: README / Methodology
  # ----------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "README")

  readme_text <- c(
    "TURAS KEY DRIVER ANALYSIS - OUTPUT FILE",
    "",
    paste("Analysis Date:", Sys.Date()),
    paste("Outcome Variable:", config$outcome_var),
    paste("Number of Drivers:", length(config$driver_vars)),
    paste("Weight Variable:", ifelse(is.null(config$weight_var), "None (unweighted)", config$weight_var)),
    paste("Sample Size:", nobs(model)),
    paste("Model R-Squared:", round(summary(model)$r.squared, 3)),
    "",
    "=== IMPORTANCE METRICS ===",
    "",
    "1. Shapley Value (%)",
    "   - Game theory approach for fair R² allocation",
    "   - Considers all possible combinations of drivers",
    "   - Most robust method; recommended for prioritization",
    "",
    "2. Relative Weight (%)",
    "   - Johnson's method using orthogonal decomposition",
    "   - Handles multicollinearity well",
    "   - Always non-negative and sums to 100%",
    "",
    "3. Beta Weight (%)",
    "   - Based on absolute value of standardized regression coefficients",
    "   - Traditional approach; easy to interpret",
    "   - Can be unstable with high multicollinearity",
    "",
    "4. Beta Coefficient",
    "   - Signed standardized regression coefficient",
    "   - Shows direction of relationship (positive/negative)",
    "   - Values in standard deviation units",
    "",
    "5. Correlation (r)",
    "   - Simple Pearson correlation with outcome",
    "   - Signed value showing direction",
    "   - Does not account for other variables",
    "",
    "=== INTERPRETATION GUIDELINES ===",
    "",
    "Importance Scores:",
    "  - >20%: Major driver (high priority)",
    "  - 10-20%: Moderate driver (secondary priority)",
    "  - <10%: Minor driver (limited impact)",
    "",
    "VIF (Variance Inflation Factor):",
    "  - VIF < 5: Low multicollinearity",
    "  - VIF 5-10: Moderate multicollinearity",
    "  - VIF > 10: High multicollinearity (consider removing driver)",
    "",
    "Method Consensus:",
    "  - High consensus (all methods agree): Strong evidence",
    "  - Low consensus (methods disagree): Investigate further",
    "",
    "=== ASSUMPTIONS & LIMITATIONS ===",
    "",
    "Assumptions:",
    "  - Linear relationships between drivers and outcome",
    "  - Independent observations",
    "  - No severe multicollinearity (VIF < 10 recommended)",
    "",
    "Limitations:",
    "  - Cannot detect non-linear relationships",
    "  - Assumes additive effects (no interactions)",
    "  - Correlation ≠ causation",
    "  - Missing data handled via listwise deletion",
    "",
    "=== SHEETS IN THIS WORKBOOK ===",
    "",
    "1. Importance Summary - All importance metrics in one view",
    "2. Method Rankings - Rank positions from each method",
    "3. Model Summary - R², F-stat, RMSE, VIF diagnostics",
    "4. Correlations - Full correlation matrix",
    "5. Charts - Visual representation of driver impact",
    "6. README - This documentation",
    "",
    "=== REFERENCES ===",
    "",
    "Shapley, L. S. (1953). A value for n-person games.",
    "Johnson, J. W. (2000). A heuristic method for estimating relative weights.",
    "Tonidandel, S., & LeBreton, J. M. (2011). Relative importance analysis.",
    "",
    "For questions or support, contact the Turas development team."
  )

  readme_df <- data.frame(Content = readme_text, stringsAsFactors = FALSE)
  openxlsx::writeData(wb, "README", readme_df, startRow = 1, startCol = 1,
                     colNames = FALSE)
  openxlsx::setColWidths(wb, "README", cols = 1, widths = 100)

  # Save workbook
  openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
}
