# ==============================================================================
# TURAS PRICING MODULE - OUTPUT GENERATION
# ==============================================================================
#
# Purpose: Generate Excel output files with analysis results
# Version: 1.0.0
# Date: 2025-11-18
#
# ==============================================================================

#' Write Pricing Analysis Output
#'
#' Generates comprehensive Excel output file with analysis results.
#'
#' @param results Analysis results
#' @param plots List of plot objects
#' @param validation Validation results
#' @param config Configuration list
#' @param output_file Path for output file
#'
#' @return Invisible path to output file
#'
#' @keywords internal
write_pricing_output <- function(results, plots, validation, config, output_file) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required for Excel output", call. = FALSE)
  }

  # Create output directory if needed
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir) && output_dir != ".") {
    dir.create(output_dir, recursive = TRUE)
  }

  wb <- openxlsx::createWorkbook()

  # Define styles
  header_style <- openxlsx::createStyle(
    fontColour = "#FFFFFF",
    fgFill = "#003D5C",
    halign = "left",
    textDecoration = "bold"
  )

  subheader_style <- openxlsx::createStyle(
    fgFill = "#E8E8E8",
    textDecoration = "bold"
  )

  number_style <- openxlsx::createStyle(numFmt = "0.00")
  percent_style <- openxlsx::createStyle(numFmt = "0.0%")
  currency_style <- openxlsx::createStyle(numFmt = "$#,##0.00")

  method <- tolower(config$analysis_method)

  # --------------------------------------------------------------------------
  # Summary Sheet
  # --------------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Summary")

  summary_data <- data.frame(
    Item = c(
      "Project Name",
      "Analysis Method",
      "Analysis Date",
      "Total Respondents",
      "Valid Respondents",
      "Excluded Cases"
    ),
    Value = c(
      config$project_name %||% "Pricing Analysis",
      config$analysis_method,
      format(Sys.time(), "%Y-%m-%d %H:%M"),
      validation$n_total,
      validation$n_valid,
      validation$n_excluded
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Summary", summary_data, headerStyle = header_style)
  openxlsx::setColWidths(wb, "Summary", cols = 1:2, widths = c(25, 40))

  # --------------------------------------------------------------------------
  # Van Westendorp Results
  # --------------------------------------------------------------------------
  if (method %in% c("van_westendorp", "both")) {

    vw_results <- if (method == "both") results$van_westendorp else results

    # Price Points sheet
    openxlsx::addWorksheet(wb, "VW_Price_Points")

    price_points_df <- data.frame(
      Metric = c("PMC", "OPP", "IDP", "PME"),
      Description = c(
        "Point of Marginal Cheapness",
        "Optimal Price Point",
        "Indifference Price Point",
        "Point of Marginal Expensiveness"
      ),
      Price = c(
        vw_results$price_points$PMC,
        vw_results$price_points$OPP,
        vw_results$price_points$IDP,
        vw_results$price_points$PME
      ),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "VW_Price_Points", price_points_df, headerStyle = header_style)
    openxlsx::addStyle(wb, "VW_Price_Points", currency_style,
                       rows = 2:5, cols = 3, gridExpand = TRUE)
    openxlsx::setColWidths(wb, "VW_Price_Points", cols = 1:3, widths = c(10, 35, 15))

    # Add ranges below price points
    range_start_row <- nrow(price_points_df) + 3

    range_data <- data.frame(
      Range = c("Acceptable Range", "Optimal Range"),
      Lower = c(vw_results$acceptable_range$lower, vw_results$optimal_range$lower),
      Upper = c(vw_results$acceptable_range$upper, vw_results$optimal_range$upper),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "VW_Price_Points", range_data,
                        startRow = range_start_row, headerStyle = header_style)
    openxlsx::addStyle(wb, "VW_Price_Points", currency_style,
                       rows = (range_start_row + 1):(range_start_row + 2),
                       cols = 2:3, gridExpand = TRUE)

    # Confidence Intervals (if calculated)
    if (!is.null(vw_results$confidence_intervals)) {
      openxlsx::addWorksheet(wb, "VW_Confidence_Intervals")
      openxlsx::writeData(wb, "VW_Confidence_Intervals",
                          vw_results$confidence_intervals, headerStyle = header_style)
      openxlsx::addStyle(wb, "VW_Confidence_Intervals", currency_style,
                         rows = 2:5, cols = 2:5, gridExpand = TRUE)
      openxlsx::setColWidths(wb, "VW_Confidence_Intervals", cols = 1:5, widths = "auto")
    }

    # Descriptives
    openxlsx::addWorksheet(wb, "VW_Descriptives")
    openxlsx::writeData(wb, "VW_Descriptives",
                        vw_results$descriptives, headerStyle = header_style)
    openxlsx::setColWidths(wb, "VW_Descriptives", cols = 1:7, widths = "auto")

    # Curves data (for custom charting)
    openxlsx::addWorksheet(wb, "VW_Curves")
    openxlsx::writeData(wb, "VW_Curves", vw_results$curves, headerStyle = header_style)
    openxlsx::setColWidths(wb, "VW_Curves", cols = 1:7, widths = "auto")
  }

  # --------------------------------------------------------------------------
  # Gabor-Granger Results
  # --------------------------------------------------------------------------
  if (method %in% c("gabor_granger", "both")) {

    gg_results <- if (method == "both") results$gabor_granger else results

    # Demand Curve sheet
    openxlsx::addWorksheet(wb, "GG_Demand_Curve")
    openxlsx::writeData(wb, "GG_Demand_Curve",
                        gg_results$demand_curve, headerStyle = header_style)
    openxlsx::addStyle(wb, "GG_Demand_Curve", currency_style,
                       rows = 2:(nrow(gg_results$demand_curve) + 1),
                       cols = 1, gridExpand = TRUE)
    openxlsx::addStyle(wb, "GG_Demand_Curve", percent_style,
                       rows = 2:(nrow(gg_results$demand_curve) + 1),
                       cols = 4, gridExpand = TRUE)
    openxlsx::setColWidths(wb, "GG_Demand_Curve", cols = 1:4, widths = "auto")

    # Revenue Curve sheet
    openxlsx::addWorksheet(wb, "GG_Revenue_Curve")
    openxlsx::writeData(wb, "GG_Revenue_Curve",
                        gg_results$revenue_curve, headerStyle = header_style)
    openxlsx::setColWidths(wb, "GG_Revenue_Curve", cols = 1:6, widths = "auto")

    # Optimal Price
    if (!is.null(gg_results$optimal_price)) {
      openxlsx::addWorksheet(wb, "GG_Optimal_Price")

      optimal_df <- data.frame(
        Metric = c("Optimal Price", "Purchase Intent", "Revenue Index"),
        Value = c(
          gg_results$optimal_price$price,
          gg_results$optimal_price$purchase_intent,
          gg_results$optimal_price$revenue_index
        ),
        stringsAsFactors = FALSE
      )

      openxlsx::writeData(wb, "GG_Optimal_Price", optimal_df, headerStyle = header_style)
      openxlsx::setColWidths(wb, "GG_Optimal_Price", cols = 1:2, widths = c(20, 20))
    }

    # Elasticity
    if (!is.null(gg_results$elasticity)) {
      openxlsx::addWorksheet(wb, "GG_Elasticity")
      openxlsx::writeData(wb, "GG_Elasticity",
                          gg_results$elasticity, headerStyle = header_style)
      openxlsx::setColWidths(wb, "GG_Elasticity", cols = 1:7, widths = "auto")
    }

    # Confidence Intervals
    if (!is.null(gg_results$confidence_intervals)) {
      openxlsx::addWorksheet(wb, "GG_Confidence_Intervals")
      openxlsx::writeData(wb, "GG_Confidence_Intervals",
                          gg_results$confidence_intervals, headerStyle = header_style)
      openxlsx::setColWidths(wb, "GG_Confidence_Intervals", cols = 1:5, widths = "auto")
    }
  }

  # --------------------------------------------------------------------------
  # Validation Details
  # --------------------------------------------------------------------------
  if (validation$n_warnings > 0 || validation$n_excluded > 0) {
    openxlsx::addWorksheet(wb, "Validation")

    val_summary <- data.frame(
      Item = c("Total Respondents", "Valid Respondents", "Excluded Cases", "Warnings"),
      Value = c(
        validation$n_total,
        validation$n_valid,
        validation$n_excluded,
        validation$n_warnings
      ),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Validation", val_summary, headerStyle = header_style)

    # Add warnings list
    if (length(validation$warnings) > 0) {
      warning_start <- nrow(val_summary) + 3
      openxlsx::writeData(wb, "Validation", "Validation Warnings:",
                          startRow = warning_start)
      openxlsx::addStyle(wb, "Validation", subheader_style,
                         rows = warning_start, cols = 1)

      for (i in seq_along(validation$warnings)) {
        openxlsx::writeData(wb, "Validation",
                            paste0(i, ". ", validation$warnings[[i]]),
                            startRow = warning_start + i)
      }
    }

    openxlsx::setColWidths(wb, "Validation", cols = 1:2, widths = c(30, 60))
  }

  # --------------------------------------------------------------------------
  # Configuration Sheet
  # --------------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Configuration")

  config_items <- list(
    "Project Name" = config$project_name %||% "Pricing Analysis",
    "Analysis Method" = config$analysis_method,
    "Data File" = config$data_file %||% "",
    "Currency Symbol" = config$currency_symbol %||% "$"
  )

  config_df <- data.frame(
    Setting = names(config_items),
    Value = unlist(config_items),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Configuration", config_df, headerStyle = header_style)
  openxlsx::setColWidths(wb, "Configuration", cols = 1:2, widths = c(25, 50))

  # --------------------------------------------------------------------------
  # Save Workbook
  # --------------------------------------------------------------------------
  openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)

  # Save plots to same directory
  if (length(plots) > 0) {
    plot_dir <- file.path(dirname(output_file), "plots")
    saved_plots <- save_pricing_plots(plots, plot_dir, config)
    if (length(saved_plots) > 0) {
      cat(sprintf("   Plots saved to: %s\n", plot_dir))
    }
  }

  invisible(output_file)
}


#' Export Results to CSV
#'
#' Exports key results to CSV format for further analysis.
#'
#' @param results Pricing analysis results
#' @param output_dir Output directory
#' @param config Configuration
#'
#' @return Vector of saved file paths
#'
#' @export
export_pricing_csv <- function(results, output_dir, config) {

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  saved_files <- character(0)

  method <- tolower(config$analysis_method)

  if (method %in% c("van_westendorp", "both")) {
    vw <- if (method == "both") results$van_westendorp else results

    # Price points
    pp_file <- file.path(output_dir, "vw_price_points.csv")
    pp_df <- data.frame(
      metric = c("PMC", "OPP", "IDP", "PME"),
      price = c(vw$price_points$PMC, vw$price_points$OPP,
                vw$price_points$IDP, vw$price_points$PME)
    )
    write.csv(pp_df, pp_file, row.names = FALSE)
    saved_files <- c(saved_files, pp_file)

    # Curves
    curves_file <- file.path(output_dir, "vw_curves.csv")
    write.csv(vw$curves, curves_file, row.names = FALSE)
    saved_files <- c(saved_files, curves_file)
  }

  if (method %in% c("gabor_granger", "both")) {
    gg <- if (method == "both") results$gabor_granger else results

    # Demand curve
    demand_file <- file.path(output_dir, "gg_demand_curve.csv")
    write.csv(gg$demand_curve, demand_file, row.names = FALSE)
    saved_files <- c(saved_files, demand_file)

    # Revenue curve
    revenue_file <- file.path(output_dir, "gg_revenue_curve.csv")
    write.csv(gg$revenue_curve, revenue_file, row.names = FALSE)
    saved_files <- c(saved_files, revenue_file)
  }

  return(saved_files)
}
