# ==============================================================================
# CATEGORICAL KEY DRIVER - SUBGROUP COMPARISON EXCEL SHEETS
# ==============================================================================
#
# Adds subgroup comparison sheets to the Excel workbook when
# subgroup analysis is active. Three sheets:
#   1. Subgroup Summary — side-by-side importance ranks
#   2. Subgroup OR Comparison — odds ratios across groups
#   3. Subgroup Model Fit — per-group model statistics
#
# Called from 06_output.R when results$subgroup_active is TRUE.
#
# Version: 1.0
# ==============================================================================


#' Add All Subgroup Comparison Sheets
#'
#' Master function that adds all three subgroup comparison sheets (Summary,
#' OR Compare, Model Fit) to the workbook. Each sheet is wrapped in tryCatch
#' so that a failure in one does not prevent the others from being written.
#'
#' @param wb An openxlsx workbook object.
#' @param comparison List returned by build_subgroup_comparison(), containing
#'   importance_matrix, or_comparison, model_fit, insights, and group_names.
#' @param results List of full analysis results (passed through for context).
#' @param config Configuration list with subgroup_var and labels.
#' @param styles List of openxlsx style objects from create_output_styles().
#' @return NULL (called for side effects; sheets are added to \code{wb}).
#' @keywords internal
add_subgroup_sheets <- function(wb, comparison, results, config, styles) {

  if (is.null(comparison)) {
    cat("   [INFO] No subgroup comparison data - skipping subgroup sheets\n")
    return(invisible(NULL))
  }

  # Sheet 9: Subgroup Summary (importance rankings)
  tryCatch(
    add_subgroup_summary_sheet(wb, comparison, config, styles),
    error = function(e) cat("   [ERROR] Subgroup Summary sheet failed:", conditionMessage(e), "\n")
  )

  # Sheet 10: Subgroup OR Comparison
  tryCatch(
    add_subgroup_or_sheet(wb, comparison, config, styles),
    error = function(e) cat("   [ERROR] Subgroup OR Comparison sheet failed:", conditionMessage(e), "\n")
  )

  # Sheet 11: Subgroup Model Fit
  tryCatch(
    add_subgroup_model_fit_sheet(wb, comparison, config, styles),
    error = function(e) cat("   [ERROR] Subgroup Model Fit sheet failed:", conditionMessage(e), "\n")
  )

  cat("   [OK] Subgroup comparison sheets added\n")
  invisible(NULL)
}


#' Add Subgroup Summary Sheet
#'
#' Writes the "Subgroup Summary" sheet showing side-by-side driver importance
#' rankings and percentages across subgroups. Highlights universal drivers
#' in green and segment-specific drivers in amber.
#'
#' @param wb An openxlsx workbook object.
#' @param comparison List returned by build_subgroup_comparison(), containing
#'   importance_matrix (with classification column), group_names, subgroup_var,
#'   and insights.
#' @param config Configuration list (reserved for future label customisation).
#' @param styles List of openxlsx style objects from create_output_styles().
#' @return NULL (called for side effects).
#' @keywords internal
add_subgroup_summary_sheet <- function(wb, comparison, config, styles) {

  sheet_name <- "Subgroup Summary"
  openxlsx::addWorksheet(wb, sheet_name)

  imp_matrix <- comparison$importance_matrix
  if (is.null(imp_matrix) || nrow(imp_matrix) == 0) {
    openxlsx::writeData(wb, sheet_name, "No importance data available for subgroup comparison.", startRow = 1)
    return(invisible(NULL))
  }

  # Title
  openxlsx::writeData(wb, sheet_name,
    sprintf("Subgroup Comparison: Driver Importance by %s",
            comparison$subgroup_var %||% "Subgroup"),
    startRow = 1
  )

  if (!is.null(styles$title)) {
    openxlsx::addStyle(wb, sheet_name, style = styles$title, rows = 1, cols = 1)
  }

  # Insights
  insights <- comparison$insights
  if (length(insights) > 0) {
    for (i in seq_along(insights)) {
      openxlsx::writeData(wb, sheet_name, insights[i], startRow = 2 + i)
    }
  }

  data_start_row <- 3 + length(insights) + 1

  # Build display table
  display_cols <- c("variable", "label")
  for (grp in comparison$group_names) {
    display_cols <- c(display_cols, paste0(grp, "_rank"), paste0(grp, "_pct"))
  }
  display_cols <- c(display_cols, "max_rank_diff", "classification")

  # Filter to columns that exist
  available_cols <- intersect(display_cols, names(imp_matrix))
  display_df <- imp_matrix[, available_cols, drop = FALSE]

  # Rename columns for readability
  col_names <- names(display_df)
  col_names <- gsub("_rank$", " Rank", col_names)
  col_names <- gsub("_pct$", " %", col_names)
  col_names[col_names == "variable"] <- "Variable"
  col_names[col_names == "label"] <- "Label"
  col_names[col_names == "max_rank_diff"] <- "Max Rank Diff"
  col_names[col_names == "classification"] <- "Classification"
  names(display_df) <- col_names

  openxlsx::writeData(wb, sheet_name, display_df, startRow = data_start_row, headerStyle = styles$header)

  # Apply number formatting to pct columns
  pct_cols <- grep(" %$", names(display_df))
  if (length(pct_cols) > 0) {
    pct_style <- openxlsx::createStyle(numFmt = "0.0")
    for (col in pct_cols) {
      openxlsx::addStyle(wb, sheet_name, pct_style,
        rows = (data_start_row + 1):(data_start_row + nrow(display_df)),
        cols = col, gridExpand = TRUE)
    }
  }

  # Highlight universal drivers with green background
  universal_rows <- which(imp_matrix$classification == "Universal")
  if (length(universal_rows) > 0) {
    green_style <- openxlsx::createStyle(fgFill = "#d1fae5")
    for (row_idx in universal_rows) {
      openxlsx::addStyle(wb, sheet_name, green_style,
        rows = data_start_row + row_idx,
        cols = seq_len(ncol(display_df)),
        gridExpand = TRUE, stack = TRUE)
    }
  }

  # Highlight segment-specific drivers with amber
  seg_rows <- which(imp_matrix$classification == "Segment-Specific")
  if (length(seg_rows) > 0) {
    amber_style <- openxlsx::createStyle(fgFill = "#fef3c7")
    for (row_idx in seg_rows) {
      openxlsx::addStyle(wb, sheet_name, amber_style,
        rows = data_start_row + row_idx,
        cols = seq_len(ncol(display_df)),
        gridExpand = TRUE, stack = TRUE)
    }
  }

  # Auto-width columns
  openxlsx::setColWidths(wb, sheet_name, cols = seq_len(ncol(display_df)),
                          widths = "auto")

  invisible(NULL)
}


#' Add Subgroup OR Comparison Sheet
#'
#' Writes the "Subgroup OR Compare" sheet showing odds ratio values, confidence
#' intervals, and p-values across subgroups for each driver level. Highlights
#' notable rows where the OR ratio across groups exceeds 2.0.
#'
#' @param wb An openxlsx workbook object.
#' @param comparison List returned by build_subgroup_comparison(), containing
#'   or_comparison data frame and group_names.
#' @param config Configuration list (reserved for future label customisation).
#' @param styles List of openxlsx style objects from create_output_styles().
#' @return NULL (called for side effects).
#' @keywords internal
add_subgroup_or_sheet <- function(wb, comparison, config, styles) {

  sheet_name <- "Subgroup OR Compare"
  openxlsx::addWorksheet(wb, sheet_name)

  or_comp <- comparison$or_comparison
  if (is.null(or_comp) || nrow(or_comp) == 0) {
    openxlsx::writeData(wb, sheet_name, "No odds ratio comparison data available.", startRow = 1)
    return(invisible(NULL))
  }

  # Title
  openxlsx::writeData(wb, sheet_name,
    sprintf("Subgroup Comparison: Odds Ratios by %s",
            comparison$subgroup_var %||% "Subgroup"),
    startRow = 1
  )

  if (!is.null(styles$title)) {
    openxlsx::addStyle(wb, sheet_name, style = styles$title, rows = 1, cols = 1)
  }

  # Build display table — select key columns
  display_cols <- c("driver", "label", "level")
  for (grp in comparison$group_names) {
    display_cols <- c(display_cols, paste0(grp, "_or"), paste0(grp, "_p"))
  }
  display_cols <- c(display_cols, "or_ratio", "notable")

  available_cols <- intersect(display_cols, names(or_comp))
  display_df <- or_comp[, available_cols, drop = FALSE]

  # Rename columns
  col_names <- names(display_df)
  col_names <- gsub("_or$", " OR", col_names)
  col_names <- gsub("_p$", " p-value", col_names)
  col_names[col_names == "driver"] <- "Driver"
  col_names[col_names == "label"] <- "Label"
  col_names[col_names == "level"] <- "Level"
  col_names[col_names == "or_ratio"] <- "OR Ratio"
  col_names[col_names == "notable"] <- "Notable"
  names(display_df) <- col_names

  openxlsx::writeData(wb, sheet_name, display_df, startRow = 3, headerStyle = styles$header)

  # Highlight notable rows
  notable_rows <- which(or_comp$notable == "Yes")
  if (length(notable_rows) > 0) {
    highlight <- openxlsx::createStyle(fgFill = "#fee2e2")
    for (row_idx in notable_rows) {
      openxlsx::addStyle(wb, sheet_name, highlight,
        rows = 3 + row_idx,
        cols = seq_len(ncol(display_df)),
        gridExpand = TRUE, stack = TRUE)
    }
  }

  openxlsx::setColWidths(wb, sheet_name, cols = seq_len(ncol(display_df)),
                          widths = "auto")

  invisible(NULL)
}


#' Add Subgroup Model Fit Sheet
#'
#' Writes the "Subgroup Model Fit" sheet with one row per subgroup showing
#' sample size, McFadden R2, AIC, convergence status, run status, and
#' the estimation engine used.
#'
#' @param wb An openxlsx workbook object.
#' @param comparison List returned by build_subgroup_comparison(), containing
#'   model_fit data frame and subgroup_var.
#' @param config Configuration list (reserved for future label customisation).
#' @param styles List of openxlsx style objects from create_output_styles().
#' @return NULL (called for side effects).
#' @keywords internal
add_subgroup_model_fit_sheet <- function(wb, comparison, config, styles) {

  sheet_name <- "Subgroup Model Fit"
  openxlsx::addWorksheet(wb, sheet_name)

  model_fit <- comparison$model_fit
  if (is.null(model_fit) || nrow(model_fit) == 0) {
    openxlsx::writeData(wb, sheet_name, "No model fit data available.", startRow = 1)
    return(invisible(NULL))
  }

  # Title
  openxlsx::writeData(wb, sheet_name,
    sprintf("Subgroup Model Fit: %s", comparison$subgroup_var %||% "Subgroup"),
    startRow = 1
  )

  if (!is.null(styles$title)) {
    openxlsx::addStyle(wb, sheet_name, style = styles$title, rows = 1, cols = 1)
  }

  # Rename columns
  display_df <- model_fit
  names(display_df) <- c("Subgroup", "N", "McFadden R2", "AIC",
                           "Convergence", "Status", "Engine")

  openxlsx::writeData(wb, sheet_name, display_df, startRow = 3, headerStyle = styles$header)

  openxlsx::setColWidths(wb, sheet_name, cols = seq_len(ncol(display_df)),
                          widths = "auto")

  invisible(NULL)
}
