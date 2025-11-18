# ==============================================================================
# KEY DRIVER OUTPUT WRITER
# ==============================================================================

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

  # Sheet 1: Importance Summary
  openxlsx::addWorksheet(wb, "Importance Summary")

  summary_cols <- c("Driver", "Label", "Shapley_Value", "Relative_Weight",
                    "Beta_Weight", "Correlation", "Average_Rank")
  summary_data <- importance[, summary_cols]
  names(summary_data) <- c("Driver", "Label", "Shapley (%)", "Rel. Weight (%)",
                           "Beta Weight (%)", "Correlation (r)", "Avg Rank")

  openxlsx::writeData(wb, "Importance Summary", summary_data, startRow = 1)
  openxlsx::addStyle(wb, "Importance Summary", header_style, rows = 1,
                     cols = 1:ncol(summary_data), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Importance Summary", cols = 1:ncol(summary_data),
                         widths = "auto")

  # Sheet 2: Detailed Rankings
  openxlsx::addWorksheet(wb, "Method Rankings")
  ranking_cols <- c("Driver", "Label", "Shapley_Rank", "RelWeight_Rank",
                    "Beta_Rank", "Corr_Rank", "Average_Rank")
  ranking_data <- importance[, ranking_cols]
  names(ranking_data) <- c("Driver", "Label", "Shapley Rank", "Rel. Weight Rank",
                           "Beta Rank", "Corr Rank", "Average Rank")

  openxlsx::writeData(wb, "Method Rankings", ranking_data, startRow = 1)
  openxlsx::addStyle(wb, "Method Rankings", header_style, rows = 1,
                     cols = 1:ncol(ranking_data), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Method Rankings", cols = 1:ncol(ranking_data),
                         widths = "auto")

  # Sheet 3: Model Summary
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

  # Sheet 4: Correlation Matrix
  openxlsx::addWorksheet(wb, "Correlations")
  cor_df <- as.data.frame(correlations)
  cor_df <- cbind(Variable = rownames(cor_df), cor_df)
  rownames(cor_df) <- NULL

  openxlsx::writeData(wb, "Correlations", cor_df, startRow = 1)
  openxlsx::addStyle(wb, "Correlations", header_style, rows = 1,
                     cols = 1:ncol(cor_df), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Correlations", cols = 1:ncol(cor_df), widths = "auto")

  # Save workbook
  openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
}
