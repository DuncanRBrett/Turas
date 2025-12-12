# ==============================================================================
# TURAS KEY DRIVER - SHAP EXPORT FUNCTIONS
# ==============================================================================
#
# Purpose: Export SHAP results to Excel and image files
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================

#' Export SHAP Results to Excel
#'
#' Writes SHAP analysis results to Excel workbook.
#'
#' @param shap_results Results from run_shap_analysis()
#' @param wb openxlsx workbook object (optional - creates new if NULL)
#' @param output_file Path to output Excel file (used if wb is NULL)
#' @return Updated workbook object
#' @keywords internal
export_shap_to_excel <- function(shap_results, wb = NULL, output_file = NULL) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' required for Excel export.", call. = FALSE)
  }

  # Create workbook if not provided
  create_new <- is.null(wb)
  if (create_new) {
    wb <- openxlsx::createWorkbook()
  }

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    fontColour = "#FFFFFF",
    fgFill = "#ec4899",  # Pink for SHAP sheets
    halign = "left",
    valign = "center",
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )

  # ----------------------------------------------------------------------
  # Sheet: SHAP_Importance
  # ----------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "SHAP_Importance")

  importance <- shap_results$importance
  if (!is.null(importance)) {
    # Format columns
    export_importance <- data.frame(
      Driver = importance$driver,
      Mean_SHAP = round(importance$mean_shap, 4),
      Importance_Pct = round(importance$importance_pct, 1),
      Rank = importance$rank,
      Std_Dev = round(importance$std_shap, 4),
      Min = round(importance$min_shap, 4),
      Max = round(importance$max_shap, 4),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "SHAP_Importance", export_importance, startRow = 1)
    openxlsx::addStyle(wb, "SHAP_Importance", header_style, rows = 1,
                       cols = 1:ncol(export_importance), gridExpand = TRUE)
    openxlsx::setColWidths(wb, "SHAP_Importance", cols = 1:ncol(export_importance),
                           widths = "auto")
  }

  # ----------------------------------------------------------------------
  # Sheet: SHAP_Model_Diagnostics
  # ----------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "SHAP_Model_Diagnostics")

  diagnostics <- shap_results$diagnostics
  if (!is.null(diagnostics)) {
    diag_df <- data.frame(
      Metric = c("Model Type", "Number of Trees", "R-squared", "RMSE", "MAE",
                 "CV Best Score", "Sample Size"),
      Value = c(
        diagnostics$model_type,
        diagnostics$n_trees,
        round(diagnostics$r_squared, 4),
        round(diagnostics$rmse, 4),
        round(diagnostics$mae, 4),
        if (!is.null(diagnostics$cv_best_score)) round(diagnostics$cv_best_score, 4) else "N/A",
        diagnostics$sample_size
      ),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "SHAP_Model_Diagnostics", diag_df, startRow = 1)
    openxlsx::addStyle(wb, "SHAP_Model_Diagnostics", header_style, rows = 1,
                       cols = 1:2, gridExpand = TRUE)
    openxlsx::setColWidths(wb, "SHAP_Model_Diagnostics", cols = 1:2, widths = "auto")
  }

  # ----------------------------------------------------------------------
  # Sheet: SHAP_Segment_Comparison (if available)
  # ----------------------------------------------------------------------
  if (!is.null(shap_results$segments) && !is.null(shap_results$segments$comparison)) {

    openxlsx::addWorksheet(wb, "SHAP_Segment_Comparison")

    comparison_table <- shap_results$segments$comparison$table
    if (!is.null(comparison_table)) {
      openxlsx::writeData(wb, "SHAP_Segment_Comparison", comparison_table, startRow = 1)
      openxlsx::addStyle(wb, "SHAP_Segment_Comparison", header_style, rows = 1,
                         cols = 1:ncol(comparison_table), gridExpand = TRUE)
      openxlsx::setColWidths(wb, "SHAP_Segment_Comparison",
                             cols = 1:ncol(comparison_table), widths = "auto")
    }
  }

  # ----------------------------------------------------------------------
  # Sheet: SHAP_Interactions (if available)
  # ----------------------------------------------------------------------
  if (!is.null(shap_results$interactions)) {

    openxlsx::addWorksheet(wb, "SHAP_Interactions")

    top_pairs <- shap_results$interactions$top_pairs
    if (!is.null(top_pairs)) {
      top_pairs$interaction_strength <- round(top_pairs$interaction_strength, 4)
      openxlsx::writeData(wb, "SHAP_Interactions", top_pairs, startRow = 1)
      openxlsx::addStyle(wb, "SHAP_Interactions", header_style, rows = 1,
                         cols = 1:3, gridExpand = TRUE)
      openxlsx::setColWidths(wb, "SHAP_Interactions", cols = 1:3, widths = "auto")
    }
  }

  # Save if new workbook
  if (create_new && !is.null(output_file)) {
    openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
  }

  invisible(wb)
}


#' Export SHAP Plots to Files
#'
#' Saves all SHAP plots as PNG and optionally PDF files.
#'
#' @param plots List of ggplot objects from generate_shap_plots()
#' @param output_dir Directory to save plots
#' @param prefix Filename prefix
#' @param formats Character vector of formats ("png", "pdf")
#' @param width Plot width in inches
#' @param height Plot height in inches
#' @param dpi Resolution for PNG files
#' @keywords internal
export_shap_plots <- function(plots, output_dir, prefix = "shap",
                              formats = c("png"), width = 10, height = 8,
                              dpi = 300) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    warning("Package 'ggplot2' required for plot export.")
    return(invisible(NULL))
  }

  # Create output directory if needed
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  saved_files <- character()

  for (name in names(plots)) {
    p <- plots[[name]]

    if (is.null(p)) next

    if (inherits(p, "list")) {
      # Nested list (e.g., dependence plots)
      for (subname in names(p)) {
        sub_p <- p[[subname]]

        if (inherits(sub_p, "ggplot") || inherits(sub_p, "patchwork")) {
          files <- save_plot(
            sub_p,
            file.path(output_dir, paste0(prefix, "_", name, "_", subname)),
            formats, width, height, dpi
          )
          saved_files <- c(saved_files, files)
        }
      }
    } else if (inherits(p, "ggplot") || inherits(p, "patchwork")) {
      files <- save_plot(
        p,
        file.path(output_dir, paste0(prefix, "_", name)),
        formats, width, height, dpi
      )
      saved_files <- c(saved_files, files)
    }
  }

  invisible(saved_files)
}


#' Save Single Plot
#'
#' Saves a ggplot object to specified formats.
#'
#' @param p ggplot or patchwork object
#' @param path_without_ext File path without extension
#' @param formats Vector of formats
#' @param width Width in inches
#' @param height Height in inches
#' @param dpi DPI for raster formats
#' @return Vector of saved file paths
#' @keywords internal
save_plot <- function(p, path_without_ext, formats = c("png"),
                      width = 10, height = 8, dpi = 300) {

  saved <- character()

  if ("png" %in% formats) {
    filepath <- paste0(path_without_ext, ".png")
    tryCatch({
      ggplot2::ggsave(
        filepath,
        plot = p,
        width = width,
        height = height,
        dpi = dpi
      )
      saved <- c(saved, filepath)
    }, error = function(e) {
      warning(sprintf("Could not save %s: %s", filepath, e$message))
    })
  }

  if ("pdf" %in% formats) {
    filepath <- paste0(path_without_ext, ".pdf")
    tryCatch({
      ggplot2::ggsave(
        filepath,
        plot = p,
        width = width,
        height = height
      )
      saved <- c(saved, filepath)
    }, error = function(e) {
      warning(sprintf("Could not save %s: %s", filepath, e$message))
    })
  }

  saved
}


#' Insert SHAP Charts into Excel Workbook
#'
#' Adds SHAP visualizations to an Excel worksheet.
#'
#' @param wb openxlsx workbook object
#' @param plots List of ggplot objects
#' @param sheet_name Name for the charts sheet
#' @return Updated workbook object
#' @keywords internal
insert_shap_charts_to_excel <- function(wb, plots, sheet_name = "SHAP_Charts") {

  # Add worksheet if it doesn't exist
  sheet_names <- openxlsx::sheets(wb)
  if (!sheet_name %in% sheet_names) {
    openxlsx::addWorksheet(wb, sheet_name)
  }

  row_pos <- 1
  chart_list <- list()

  # Determine which plots to include
  priority_plots <- c("importance_bar", "importance_beeswarm", "importance_combined")

  for (plot_name in priority_plots) {
    if (plot_name %in% names(plots) && !is.null(plots[[plot_name]])) {
      chart_list[[plot_name]] <- plots[[plot_name]]
    }
  }

  # Insert each chart
  for (name in names(chart_list)) {
    p <- chart_list[[name]]

    # Save to temp file
    temp_file <- tempfile(fileext = ".png")

    tryCatch({
      ggplot2::ggsave(temp_file, plot = p, width = 10, height = 7, dpi = 150)

      # Add label
      openxlsx::writeData(wb, sheet_name,
                          data.frame(Chart = gsub("_", " ", toupper(name))),
                          startRow = row_pos, startCol = 1)

      # Insert image
      openxlsx::insertImage(
        wb,
        sheet = sheet_name,
        file = temp_file,
        startRow = row_pos + 1,
        startCol = 1,
        width = 8,
        height = 5.5,
        units = "in"
      )

      row_pos <- row_pos + 25  # Space for next chart

    }, error = function(e) {
      warning(sprintf("Could not insert chart %s: %s", name, e$message))
    })
  }

  invisible(wb)
}
