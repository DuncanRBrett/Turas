# ==============================================================================
# TURAS PRICING MODULE - OUTPUT GENERATION
# ==============================================================================
#
# Purpose: Generate Excel output files with analysis results
# Version: 12.0
# Date: 2025-12-11
#
# ==============================================================================

#' Write Pricing Analysis Output
#'
#' Generates comprehensive Excel output file with analysis results.
#' Includes NMS results, segment analysis, price ladder, and recommendation synthesis.
#'
#' @param results Analysis results
#' @param plots List of plot objects
#' @param validation Validation results
#' @param config Configuration list
#' @param output_file Path for output file
#' @param segment_results Optional segment analysis results
#' @param ladder_results Optional price ladder results
#' @param synthesis Optional recommendation synthesis
#'
#' @return Invisible path to output file
#'
#' @keywords internal
write_pricing_output <- function(results, plots, validation, config, output_file,
                                 segment_results = NULL, ladder_results = NULL,
                                 synthesis = NULL, run_result = NULL) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    pricing_refuse(
      code = "PKG_OPENXLSX_MISSING",
      title = "Required Package Missing",
      problem = "Package 'openxlsx' is not installed",
      why_it_matters = "Cannot write Excel output files without openxlsx package",
      how_to_fix = "Install the package: install.packages('openxlsx')"
    )
  }

  # Create output directory if needed
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir) && output_dir != ".") {
    dir.create(output_dir, recursive = TRUE)
  }

  wb <- openxlsx::createWorkbook()

  # ---------------------------------------------------------------------------
  # Formula injection protection (OWASP CSV Injection)
  # Inline fallback using vapply+substr (not regex, per Phase 3 re-review R3)
  # ---------------------------------------------------------------------------
  pricing_escape_cell <- if (exists("turas_excel_escape", mode = "function")) {
    turas_excel_escape
  } else {
    function(x) {
      if (!is.character(x)) return(x)
      vapply(x, function(val) {
        if (is.na(val) || nchar(val) == 0L) return(val)
        first_char <- substr(val, 1, 1)
        if (first_char %in% c("=", "+", "-", "@", "\t", "\r", "\n")) {
          paste0("'", val)
        } else {
          val
        }
      }, character(1), USE.NAMES = FALSE)
    }
  }

  pricing_escape_df <- function(df) {
    if (!is.data.frame(df)) return(df)
    # Escape column names
    nm <- names(df)
    names(df) <- pricing_escape_cell(nm)
    # Escape character columns
    for (col in seq_along(df)) {
      if (is.character(df[[col]])) {
        df[[col]] <- pricing_escape_cell(df[[col]])
      }
    }
    df
  }

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
  cs <- config$currency_symbol %||% "$"
  currency_style <- openxlsx::createStyle(numFmt = paste0(cs, "#,##0.00"))

  method <- tolower(config$analysis_method)

  # --------------------------------------------------------------------------
  # Summary Sheet
  # --------------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Summary")

  summary_items <- c(
    "Project Name",
    "Analysis Method",
    "Analysis Date",
    "Total Respondents",
    "Valid Respondents",
    "Excluded Cases"
  )

  summary_values <- c(
    config$project_name %||% "Pricing Analysis",
    config$analysis_method,
    format(Sys.time(), "%Y-%m-%d %H:%M"),
    validation$n_total,
    validation$n_valid,
    validation$n_excluded
  )

  # Add weight statistics if available
  if (!is.null(validation$weight_summary)) {
    ws <- validation$weight_summary
    summary_items <- c(summary_items,
                      "",
                      "WEIGHTING",
                      "Weighting Applied",
                      "Effective Sample Size",
                      "Weight Range",
                      "Weight Mean (SD)")
    summary_values <- c(summary_values,
                       "",
                       "",
                       "Yes",
                       sprintf("%.1f", ws$n_valid),
                       sprintf("%.2f - %.2f", ws$min, ws$max),
                       sprintf("%.2f (%.2f)", ws$mean, ws$sd))
  } else {
    summary_items <- c(summary_items, "", "WEIGHTING", "Weighting Applied")
    summary_values <- c(summary_values, "", "", "No")
  }

  summary_data <- data.frame(
    Item = summary_items,
    Value = summary_values,
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Summary", pricing_escape_df(summary_data), headerStyle = header_style)
  openxlsx::addStyle(wb, "Summary", subheader_style, rows = which(summary_items == "WEIGHTING") + 1, cols = 1:2)
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

    openxlsx::writeData(wb, "VW_Price_Points", pricing_escape_df(price_points_df), headerStyle = header_style)
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

    openxlsx::writeData(wb, "VW_Price_Points", pricing_escape_df(range_data),
                        startRow = range_start_row, headerStyle = header_style)
    openxlsx::addStyle(wb, "VW_Price_Points", currency_style,
                       rows = (range_start_row + 1):(range_start_row + 2),
                       cols = 2:3, gridExpand = TRUE)

    # Confidence Intervals (if calculated)
    if (!is.null(vw_results$confidence_intervals)) {
      openxlsx::addWorksheet(wb, "VW_Confidence_Intervals")
      openxlsx::writeData(wb, "VW_Confidence_Intervals",
                          pricing_escape_df(vw_results$confidence_intervals), headerStyle = header_style)
      openxlsx::addStyle(wb, "VW_Confidence_Intervals", currency_style,
                         rows = 2:5, cols = 2:5, gridExpand = TRUE)
      openxlsx::setColWidths(wb, "VW_Confidence_Intervals", cols = 1:5, widths = "auto")
    }

    # Descriptives
    openxlsx::addWorksheet(wb, "VW_Descriptives")
    openxlsx::writeData(wb, "VW_Descriptives",
                        pricing_escape_df(vw_results$descriptives), headerStyle = header_style)
    openxlsx::setColWidths(wb, "VW_Descriptives", cols = 1:7, widths = "auto")

    # Curves data (for custom charting)
    openxlsx::addWorksheet(wb, "VW_Curves")
    openxlsx::writeData(wb, "VW_Curves", pricing_escape_df(vw_results$curves), headerStyle = header_style)
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
                        pricing_escape_df(gg_results$demand_curve), headerStyle = header_style)
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
                        pricing_escape_df(gg_results$revenue_curve), headerStyle = header_style)
    openxlsx::setColWidths(wb, "GG_Revenue_Curve", cols = 1:6, widths = "auto")

    # Optimal Price - Revenue
    if (!is.null(gg_results$optimal_price)) {
      openxlsx::addWorksheet(wb, "GG_Optimal_Revenue")

      optimal_df <- data.frame(
        Metric = c("Revenue-Maximizing Price", "Purchase Intent", "Revenue Index"),
        Value = c(
          gg_results$optimal_price$price,
          gg_results$optimal_price$purchase_intent,
          gg_results$optimal_price$revenue_index
        ),
        stringsAsFactors = FALSE
      )

      openxlsx::writeData(wb, "GG_Optimal_Revenue", pricing_escape_df(optimal_df), headerStyle = header_style)
      openxlsx::addStyle(wb, "GG_Optimal_Revenue", currency_style, rows = 2, cols = 2)
      openxlsx::addStyle(wb, "GG_Optimal_Revenue", percent_style, rows = 3, cols = 2)
      openxlsx::setColWidths(wb, "GG_Optimal_Revenue", cols = 1:2, widths = c(25, 20))
    }

    # Optimal Price - Profit
    if (!is.null(gg_results$optimal_price_profit)) {
      openxlsx::addWorksheet(wb, "GG_Optimal_Profit")

      profit_metrics <- c("Profit-Maximizing Price", "Purchase Intent", "Profit Index", "Margin", "Revenue Index")
      profit_values <- c(
        gg_results$optimal_price_profit$price,
        gg_results$optimal_price_profit$purchase_intent,
        gg_results$optimal_price_profit$profit_index,
        gg_results$optimal_price_profit$margin,
        gg_results$optimal_price_profit$revenue_index
      )

      profit_df <- data.frame(
        Metric = profit_metrics,
        Value = profit_values,
        stringsAsFactors = FALSE
      )

      openxlsx::writeData(wb, "GG_Optimal_Profit", pricing_escape_df(profit_df), headerStyle = header_style)
      openxlsx::addStyle(wb, "GG_Optimal_Profit", currency_style, rows = c(2, 5), cols = 2)
      openxlsx::addStyle(wb, "GG_Optimal_Profit", percent_style, rows = 3, cols = 2)
      openxlsx::setColWidths(wb, "GG_Optimal_Profit", cols = 1:2, widths = c(25, 20))

      # Add comparison section
      comparison_start <- nrow(profit_df) + 3
      openxlsx::writeData(wb, "GG_Optimal_Profit", "REVENUE VS PROFIT COMPARISON",
                          startRow = comparison_start)
      openxlsx::addStyle(wb, "GG_Optimal_Profit", subheader_style,
                         rows = comparison_start, cols = 1:2)

      comp_df <- data.frame(
        Objective = c("Revenue-Maximizing", "Profit-Maximizing"),
        Price = c(gg_results$optimal_price$price, gg_results$optimal_price_profit$price),
        Intent = c(gg_results$optimal_price$purchase_intent, gg_results$optimal_price_profit$purchase_intent),
        Revenue = c(gg_results$optimal_price$revenue_index, gg_results$optimal_price_profit$revenue_index),
        Profit = c(NA, gg_results$optimal_price_profit$profit_index),
        stringsAsFactors = FALSE
      )

      openxlsx::writeData(wb, "GG_Optimal_Profit", pricing_escape_df(comp_df),
                          startRow = comparison_start + 2, headerStyle = header_style)
      openxlsx::addStyle(wb, "GG_Optimal_Profit", currency_style,
                         rows = (comparison_start + 3):(comparison_start + 4), cols = 2)
      openxlsx::addStyle(wb, "GG_Optimal_Profit", percent_style,
                         rows = (comparison_start + 3):(comparison_start + 4), cols = 3)
    }

    # Elasticity
    if (!is.null(gg_results$elasticity)) {
      openxlsx::addWorksheet(wb, "GG_Elasticity")
      openxlsx::writeData(wb, "GG_Elasticity",
                          pricing_escape_df(gg_results$elasticity), headerStyle = header_style)
      openxlsx::setColWidths(wb, "GG_Elasticity", cols = 1:7, widths = "auto")
    }

    # Confidence Intervals
    if (!is.null(gg_results$confidence_intervals)) {
      openxlsx::addWorksheet(wb, "GG_Confidence_Intervals")
      openxlsx::writeData(wb, "GG_Confidence_Intervals",
                          pricing_escape_df(gg_results$confidence_intervals), headerStyle = header_style)
      openxlsx::setColWidths(wb, "GG_Confidence_Intervals", cols = 1:5, widths = "auto")
    }
  }

  # --------------------------------------------------------------------------
  # Monadic Results
  # --------------------------------------------------------------------------
  if (method == "monadic") {

    # Demand Curve
    openxlsx::addWorksheet(wb, "Mon_Demand_Curve")
    openxlsx::writeData(wb, "Mon_Demand_Curve",
                        pricing_escape_df(results$demand_curve), headerStyle = header_style)
    openxlsx::addStyle(wb, "Mon_Demand_Curve", currency_style,
                       rows = 2:(nrow(results$demand_curve) + 1),
                       cols = 1, gridExpand = TRUE)
    openxlsx::setColWidths(wb, "Mon_Demand_Curve",
                           cols = 1:ncol(results$demand_curve), widths = "auto")

    # Observed Data
    openxlsx::addWorksheet(wb, "Mon_Observed_Data")
    openxlsx::writeData(wb, "Mon_Observed_Data",
                        pricing_escape_df(results$observed_data), headerStyle = header_style)
    openxlsx::setColWidths(wb, "Mon_Observed_Data",
                           cols = 1:ncol(results$observed_data), widths = "auto")

    # Optimal Price
    openxlsx::addWorksheet(wb, "Mon_Optimal_Price")
    opt_df <- data.frame(
      Metric = c("Revenue-Maximizing Price", "Predicted Intent", "Revenue Index"),
      Value = c(
        results$optimal_price$price,
        results$optimal_price$predicted_intent,
        results$optimal_price$revenue_index
      ),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(wb, "Mon_Optimal_Price", pricing_escape_df(opt_df), headerStyle = header_style)
    openxlsx::addStyle(wb, "Mon_Optimal_Price", currency_style, rows = 2, cols = 2)
    openxlsx::addStyle(wb, "Mon_Optimal_Price", percent_style, rows = 3, cols = 2)
    openxlsx::setColWidths(wb, "Mon_Optimal_Price", cols = 1:2, widths = c(25, 20))

    current_row <- nrow(opt_df) + 3

    # Profit optimal (if available)
    if (!is.null(results$optimal_price_profit)) {
      openxlsx::writeData(wb, "Mon_Optimal_Price", "PROFIT-MAXIMIZING",
                          startRow = current_row)
      openxlsx::addStyle(wb, "Mon_Optimal_Price", subheader_style,
                         rows = current_row, cols = 1:2)
      profit_df <- data.frame(
        Metric = c("Profit-Maximizing Price", "Predicted Intent", "Profit Index"),
        Value = c(
          results$optimal_price_profit$price,
          results$optimal_price_profit$predicted_intent,
          results$optimal_price_profit$profit_index
        ),
        stringsAsFactors = FALSE
      )
      openxlsx::writeData(wb, "Mon_Optimal_Price", pricing_escape_df(profit_df),
                          startRow = current_row + 2, headerStyle = header_style)
      openxlsx::addStyle(wb, "Mon_Optimal_Price", currency_style,
                         rows = current_row + 3, cols = 2)
      openxlsx::addStyle(wb, "Mon_Optimal_Price", percent_style,
                         rows = current_row + 4, cols = 2)
      current_row <- current_row + nrow(profit_df) + 4
    }

    # Model Summary
    openxlsx::addWorksheet(wb, "Mon_Model_Summary")
    ms <- results$model_summary
    model_df <- data.frame(
      Metric = c("Model Type", "Observations", "AIC",
                 "Null Deviance", "Residual Deviance", "Pseudo R-squared",
                 "Price Coefficient p-value"),
      Value = c(
        ms$model_type,
        ms$n_observations,
        sprintf("%.1f", ms$aic),
        sprintf("%.2f", ms$null_deviance),
        sprintf("%.2f", ms$residual_deviance),
        sprintf("%.4f", ms$pseudo_r2),
        sprintf("%.6f", ms$price_coefficient_p)
      ),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(wb, "Mon_Model_Summary", pricing_escape_df(model_df), headerStyle = header_style)
    openxlsx::setColWidths(wb, "Mon_Model_Summary", cols = 1:2, widths = c(25, 20))

    # Elasticity
    if (!is.null(results$elasticity) && nrow(results$elasticity) > 0) {
      openxlsx::addWorksheet(wb, "Mon_Elasticity")
      openxlsx::writeData(wb, "Mon_Elasticity",
                          pricing_escape_df(results$elasticity), headerStyle = header_style)
      openxlsx::setColWidths(wb, "Mon_Elasticity",
                             cols = 1:ncol(results$elasticity), widths = "auto")
    }

    # Confidence Intervals
    if (!is.null(results$confidence_intervals)) {
      ci <- results$confidence_intervals
      openxlsx::addWorksheet(wb, "Mon_Confidence_Intervals")

      ci_rows <- list()
      if (!is.null(ci$optimal_price_ci)) {
        ci_rows$rev <- data.frame(
          Metric = "Revenue-Optimal Price CI",
          Lower = ci$optimal_price_ci[1],
          Upper = ci$optimal_price_ci[2],
          stringsAsFactors = FALSE
        )
      }
      if (!is.null(ci$optimal_profit_price_ci)) {
        ci_rows$profit <- data.frame(
          Metric = "Profit-Optimal Price CI",
          Lower = ci$optimal_profit_price_ci[1],
          Upper = ci$optimal_profit_price_ci[2],
          stringsAsFactors = FALSE
        )
      }

      if (length(ci_rows) > 0) {
        ci_df <- do.call(rbind, ci_rows)
        openxlsx::writeData(wb, "Mon_Confidence_Intervals", pricing_escape_df(ci_df),
                            headerStyle = header_style)
        openxlsx::addStyle(wb, "Mon_Confidence_Intervals", currency_style,
                           rows = 2:(nrow(ci_df) + 1), cols = 2:3,
                           gridExpand = TRUE)
        openxlsx::setColWidths(wb, "Mon_Confidence_Intervals",
                               cols = 1:3, widths = c(25, 15, 15))
      }

      # Demand curve CI band
      if (!is.null(ci$demand_curve_ci)) {
        ci_start <- if (length(ci_rows) > 0) nrow(ci_df) + 4 else 1
        openxlsx::writeData(wb, "Mon_Confidence_Intervals", "DEMAND CURVE CI BAND",
                            startRow = ci_start)
        openxlsx::addStyle(wb, "Mon_Confidence_Intervals", subheader_style,
                           rows = ci_start, cols = 1:3)
        openxlsx::writeData(wb, "Mon_Confidence_Intervals", pricing_escape_df(ci$demand_curve_ci),
                            startRow = ci_start + 2, headerStyle = header_style)
      }
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

    openxlsx::writeData(wb, "Validation", pricing_escape_df(val_summary), headerStyle = header_style)
    current_row <- nrow(val_summary) + 2

    # Add exclusion breakdown if available
    if (!is.null(validation$exclusion_reasons) && length(validation$exclusion_reasons) > 0) {
      openxlsx::writeData(wb, "Validation", "EXCLUSION BREAKDOWN",
                          startRow = current_row)
      openxlsx::addStyle(wb, "Validation", subheader_style,
                         rows = current_row, cols = 1:2)
      current_row <- current_row + 2

      # Count exclusion reasons
      excluded_data <- validation$data[validation$data$excluded, ]
      if (!is.null(excluded_data) && nrow(excluded_data) > 0) {
        reason_counts <- table(excluded_data$exclusion_reason)
        reason_df <- data.frame(
          Reason = names(reason_counts),
          Count = as.numeric(reason_counts),
          stringsAsFactors = FALSE
        )

        openxlsx::writeData(wb, "Validation", pricing_escape_df(reason_df),
                            startRow = current_row, headerStyle = header_style)
        current_row <- current_row + nrow(reason_df) + 3
      }
    }

    # Add monotonicity violations if present
    if (!is.null(validation$monotonicity_violations)) {
      mv <- validation$monotonicity_violations
      openxlsx::writeData(wb, "Validation", "MONOTONICITY VIOLATIONS",
                          startRow = current_row)
      openxlsx::addStyle(wb, "Validation", subheader_style,
                         rows = current_row, cols = 1:2)
      current_row <- current_row + 1

      mono_summary <- data.frame(
        Item = c("Total Violations", "Violation Rate", "Action Taken"),
        Value = c(
          mv$n_violations,
          sprintf("%.1f%%", mv$violation_rate * 100),
          config$vw_monotonicity_behavior %||% "flag_only"
        ),
        stringsAsFactors = FALSE
      )

      openxlsx::writeData(wb, "Validation", pricing_escape_df(mono_summary), startRow = current_row)
      current_row <- current_row + nrow(mono_summary) + 2
    }

    # Add warnings list
    if (length(validation$warnings) > 0) {
      openxlsx::writeData(wb, "Validation", "VALIDATION WARNINGS",
                          startRow = current_row)
      openxlsx::addStyle(wb, "Validation", subheader_style,
                         rows = current_row, cols = 1)
      current_row <- current_row + 2

      for (i in seq_along(validation$warnings)) {
        openxlsx::writeData(wb, "Validation",
                            pricing_escape_cell(paste0(i, ". ", validation$warnings[[i]])),
                            startRow = current_row)
        current_row <- current_row + 1
      }
    }

    openxlsx::setColWidths(wb, "Validation", cols = 1:2, widths = c(30, 60))
  }

  # --------------------------------------------------------------------------
  # PHASE 3: WTP Distribution (if available)
  # --------------------------------------------------------------------------
  if (!is.null(results$wtp_distribution)) {
    wtp <- results$wtp_distribution

    # WTP Summary
    if (!is.null(wtp$summary)) {
      openxlsx::addWorksheet(wb, "WTP_Summary")

      wtp_summary_df <- data.frame(
        Metric = c("Sample Size", "Weighted N", "Mean WTP", "Median WTP",
                   "Standard Deviation", "Min WTP", "Max WTP"),
        Value = c(
          wtp$summary$n,
          wtp$summary$weighted_n,
          wtp$summary$mean,
          wtp$summary$median,
          wtp$summary$sd,
          wtp$summary$min,
          wtp$summary$max
        ),
        stringsAsFactors = FALSE
      )

      openxlsx::writeData(wb, "WTP_Summary", pricing_escape_df(wtp_summary_df), headerStyle = header_style)
      openxlsx::addStyle(wb, "WTP_Summary", currency_style,
                         rows = 4:8, cols = 2, gridExpand = TRUE)
      openxlsx::setColWidths(wb, "WTP_Summary", cols = 1:2, widths = c(25, 20))
    }

    # WTP Percentiles
    if (!is.null(wtp$percentiles)) {
      openxlsx::addWorksheet(wb, "WTP_Percentiles")

      pct_df <- data.frame(
        Percentile = names(wtp$percentiles),
        Price = as.numeric(wtp$percentiles),
        stringsAsFactors = FALSE
      )

      openxlsx::writeData(wb, "WTP_Percentiles", pricing_escape_df(pct_df), headerStyle = header_style)
      openxlsx::addStyle(wb, "WTP_Percentiles", currency_style,
                         rows = 2:(nrow(pct_df) + 1), cols = 2)
      openxlsx::setColWidths(wb, "WTP_Percentiles", cols = 1:2, widths = c(15, 20))
    }

    # WTP Distribution Data
    if (!is.null(wtp$distribution)) {
      openxlsx::addWorksheet(wb, "WTP_Distribution")
      openxlsx::writeData(wb, "WTP_Distribution", pricing_escape_df(wtp$distribution), headerStyle = header_style)
      openxlsx::setColWidths(wb, "WTP_Distribution", cols = 1:ncol(wtp$distribution), widths = "auto")
    }
  }

  # --------------------------------------------------------------------------
  # PHASE 3: Competitive Scenarios (if available)
  # --------------------------------------------------------------------------
  if (!is.null(results$competitive_scenarios)) {
    scenarios <- results$competitive_scenarios

    openxlsx::addWorksheet(wb, "Competitive_Scenarios")
    openxlsx::writeData(wb, "Competitive_Scenarios", pricing_escape_df(scenarios), headerStyle = header_style)

    # Format share column as percentage
    share_col <- which(names(scenarios) == "share")
    if (length(share_col) > 0) {
      openxlsx::addStyle(wb, "Competitive_Scenarios", percent_style,
                         rows = 2:(nrow(scenarios) + 1), cols = share_col)
    }

    # Format price column as currency
    price_col <- which(names(scenarios) == "price")
    if (length(price_col) > 0) {
      openxlsx::addStyle(wb, "Competitive_Scenarios", currency_style,
                         rows = 2:(nrow(scenarios) + 1), cols = price_col)
    }

    openxlsx::setColWidths(wb, "Competitive_Scenarios",
                           cols = 1:ncol(scenarios), widths = "auto")
  }

  # --------------------------------------------------------------------------
  # PHASE 3: Constrained Optimization (if available)
  # --------------------------------------------------------------------------
  if (!is.null(results$constrained_optimization)) {
    opt <- results$constrained_optimization

    openxlsx::addWorksheet(wb, "Constrained_Optimization")

    # Optimal result
    opt_df <- data.frame(
      Metric = c("Optimal Price", "Purchase Intent", "Volume", "Revenue Index", "Profit Index",
                 "Feasible", "Objective"),
      Value = c(
        opt$price,
        opt$purchase_intent,
        opt$volume %||% NA,
        opt$revenue_index %||% NA,
        opt$profit_index %||% NA,
        ifelse(opt$feasible, "Yes", "No"),
        opt$objective %||% ""
      ),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Constrained_Optimization", pricing_escape_df(opt_df), headerStyle = header_style)
    openxlsx::addStyle(wb, "Constrained_Optimization", currency_style, rows = 2, cols = 2)
    openxlsx::addStyle(wb, "Constrained_Optimization", percent_style, rows = 3, cols = 2)
    openxlsx::setColWidths(wb, "Constrained_Optimization", cols = 1:2, widths = c(25, 20))

    # Add constraints applied
    if (!is.null(opt$constraints_applied)) {
      constraint_start <- nrow(opt_df) + 3
      openxlsx::writeData(wb, "Constrained_Optimization", "CONSTRAINTS APPLIED",
                          startRow = constraint_start)
      openxlsx::addStyle(wb, "Constrained_Optimization", subheader_style,
                         rows = constraint_start, cols = 1:2)

      const_df <- data.frame(
        Constraint = names(opt$constraints_applied),
        Value = as.character(opt$constraints_applied),
        stringsAsFactors = FALSE
      )

      openxlsx::writeData(wb, "Constrained_Optimization", pricing_escape_df(const_df),
                          startRow = constraint_start + 2, headerStyle = header_style)
    }
  }

  # --------------------------------------------------------------------------
  # NMS Results (Newton-Miller-Smith extension)
  # --------------------------------------------------------------------------
  if (method %in% c("van_westendorp", "both")) {
    vw_results <- if (method == "both") results$van_westendorp else results

    if (!is.null(vw_results$nms_results)) {
      openxlsx::addWorksheet(wb, "VW_NMS_Results")

      nms_df <- data.frame(
        Metric = c("Trial Optimal Price", "Revenue Optimal Price"),
        Price = c(
          vw_results$nms_results$trial_optimal,
          vw_results$nms_results$revenue_optimal
        ),
        Description = c(
          "Price maximizing trial/adoption",
          "Price maximizing expected revenue"
        ),
        stringsAsFactors = FALSE
      )

      openxlsx::writeData(wb, "VW_NMS_Results", pricing_escape_df(nms_df), headerStyle = header_style)
      openxlsx::addStyle(wb, "VW_NMS_Results", currency_style,
                         rows = 2:3, cols = 2, gridExpand = TRUE)
      openxlsx::setColWidths(wb, "VW_NMS_Results", cols = 1:3, widths = c(25, 15, 35))

      # Add NMS data if available
      if (!is.null(vw_results$nms_results$data)) {
        nms_data_start <- 6
        openxlsx::writeData(wb, "VW_NMS_Results", "NMS CURVE DATA",
                            startRow = nms_data_start)
        openxlsx::addStyle(wb, "VW_NMS_Results", subheader_style,
                           rows = nms_data_start, cols = 1)
        openxlsx::writeData(wb, "VW_NMS_Results", pricing_escape_df(vw_results$nms_results$data),
                            startRow = nms_data_start + 2, headerStyle = header_style)
      }
    }
  }

  # --------------------------------------------------------------------------
  # Segment Analysis Results
  # --------------------------------------------------------------------------
  if (!is.null(segment_results)) {
    openxlsx::addWorksheet(wb, "Segment_Comparison")

    # Write comparison table
    openxlsx::writeData(wb, "Segment_Comparison", pricing_escape_df(segment_results$comparison_table),
                        headerStyle = header_style)
    openxlsx::setColWidths(wb, "Segment_Comparison",
                           cols = 1:ncol(segment_results$comparison_table),
                           widths = "auto")

    # Add insights
    if (length(segment_results$insights) > 0) {
      insight_start <- nrow(segment_results$comparison_table) + 4
      openxlsx::writeData(wb, "Segment_Comparison", "KEY SEGMENT INSIGHTS",
                          startRow = insight_start)
      openxlsx::addStyle(wb, "Segment_Comparison", subheader_style,
                         rows = insight_start, cols = 1)

      for (i in seq_along(segment_results$insights)) {
        openxlsx::writeData(wb, "Segment_Comparison",
                            pricing_escape_cell(paste0(i, ". ", segment_results$insights[i])),
                            startRow = insight_start + 1 + i)
      }
    }
  }

  # --------------------------------------------------------------------------
  # Price Ladder Results
  # --------------------------------------------------------------------------
  if (!is.null(ladder_results)) {
    openxlsx::addWorksheet(wb, "Price_Ladder")

    # Write tier table
    openxlsx::writeData(wb, "Price_Ladder", pricing_escape_df(ladder_results$tier_table),
                        headerStyle = header_style)
    openxlsx::addStyle(wb, "Price_Ladder", currency_style,
                       rows = 2:(nrow(ladder_results$tier_table) + 1),
                       cols = 2, gridExpand = TRUE)
    openxlsx::setColWidths(wb, "Price_Ladder",
                           cols = 1:ncol(ladder_results$tier_table),
                           widths = "auto")

    # Add notes
    if (length(ladder_results$notes) > 0) {
      notes_start <- nrow(ladder_results$tier_table) + 4
      openxlsx::writeData(wb, "Price_Ladder", "LADDER NOTES",
                          startRow = notes_start)
      openxlsx::addStyle(wb, "Price_Ladder", subheader_style,
                         rows = notes_start, cols = 1)

      for (i in seq_along(ladder_results$notes)) {
        openxlsx::writeData(wb, "Price_Ladder",
                            pricing_escape_cell(paste0("* ", ladder_results$notes[i])),
                            startRow = notes_start + 1 + i)
      }
    }

    # Add diagnostics
    if (!is.null(ladder_results$diagnostics)) {
      diag_start <- notes_start + length(ladder_results$notes) + 4
      openxlsx::writeData(wb, "Price_Ladder", "LADDER DIAGNOSTICS",
                          startRow = diag_start)
      openxlsx::addStyle(wb, "Price_Ladder", subheader_style,
                         rows = diag_start, cols = 1)

      diag_df <- data.frame(
        Item = c("Anchor Price", "Anchor Source", "Anchor Tier",
                 "Floor Price", "Ceiling Price", "Rounding Applied"),
        Value = c(
          sprintf("%s%.2f", cs, ladder_results$diagnostics$anchor_price),
          ladder_results$diagnostics$anchor_source,
          ladder_results$diagnostics$anchor_tier,
          sprintf("%s%.2f", cs, ladder_results$diagnostics$floor_price),
          sprintf("%s%.2f", cs, ladder_results$diagnostics$ceiling_price),
          ladder_results$diagnostics$rounding_applied
        ),
        stringsAsFactors = FALSE
      )
      openxlsx::writeData(wb, "Price_Ladder", pricing_escape_df(diag_df),
                          startRow = diag_start + 2, headerStyle = header_style)
    }
  }

  # --------------------------------------------------------------------------
  # Recommendation Synthesis
  # --------------------------------------------------------------------------
  if (!is.null(synthesis)) {
    openxlsx::addWorksheet(wb, "Recommendation")

    # Primary recommendation
    rec_df <- data.frame(
      Item = c("Recommended Price", "Confidence Level", "Confidence Score", "Source"),
      Value = c(
        sprintf("%s%.2f", config$currency_symbol %||% "$", synthesis$recommendation$price),
        synthesis$recommendation$confidence,
        sprintf("%.0f%%", synthesis$recommendation$confidence_score * 100),
        synthesis$recommendation$source
      ),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Recommendation", "PRIMARY RECOMMENDATION",
                        startRow = 1)
    openxlsx::addStyle(wb, "Recommendation", subheader_style, rows = 1, cols = 1:2)
    openxlsx::writeData(wb, "Recommendation", pricing_escape_df(rec_df),
                        startRow = 3, headerStyle = header_style)
    openxlsx::setColWidths(wb, "Recommendation", cols = 1:2, widths = c(25, 40))

    current_row <- 3 + nrow(rec_df) + 2

    # Acceptable range
    if (!is.null(synthesis$acceptable_range)) {
      openxlsx::writeData(wb, "Recommendation", "ACCEPTABLE RANGE",
                          startRow = current_row)
      openxlsx::addStyle(wb, "Recommendation", subheader_style,
                         rows = current_row, cols = 1:2)
      current_row <- current_row + 1

      range_df <- data.frame(
        Boundary = c("Floor (PMC)", "Ceiling (PME)"),
        Price = c(
          sprintf("%s%.2f", config$currency_symbol %||% "$", synthesis$acceptable_range$lower),
          sprintf("%s%.2f", config$currency_symbol %||% "$", synthesis$acceptable_range$upper)
        ),
        Note = c(synthesis$acceptable_range$lower_desc, synthesis$acceptable_range$upper_desc),
        stringsAsFactors = FALSE
      )
      openxlsx::writeData(wb, "Recommendation", pricing_escape_df(range_df),
                          startRow = current_row + 1, headerStyle = header_style)
      current_row <- current_row + nrow(range_df) + 3
    }

    # Evidence table
    if (!is.null(synthesis$evidence_table)) {
      openxlsx::writeData(wb, "Recommendation", "SUPPORTING EVIDENCE",
                          startRow = current_row)
      openxlsx::addStyle(wb, "Recommendation", subheader_style,
                         rows = current_row, cols = 1:4)
      openxlsx::writeData(wb, "Recommendation", pricing_escape_df(synthesis$evidence_table),
                          startRow = current_row + 2, headerStyle = header_style)
      current_row <- current_row + nrow(synthesis$evidence_table) + 4
    }

    # Confidence factors
    if (!is.null(synthesis$recommendation$confidence_score)) {
      openxlsx::writeData(wb, "Recommendation", "CONFIDENCE FACTORS",
                          startRow = current_row)
      openxlsx::addStyle(wb, "Recommendation", subheader_style,
                         rows = current_row, cols = 1)
      current_row <- current_row + 1

      # Get confidence object from synthesis if available
      if (!is.null(synthesis$method_prices)) {
        # Factors would be in a confidence object - write what we have
        openxlsx::writeData(wb, "Recommendation",
                            "See executive summary for detailed confidence assessment",
                            startRow = current_row + 1)
      }
      current_row <- current_row + 4
    }

    # Risks
    if (!is.null(synthesis$risks)) {
      if (length(synthesis$risks$downside) > 0) {
        openxlsx::writeData(wb, "Recommendation", "KEY RISKS",
                            startRow = current_row)
        openxlsx::addStyle(wb, "Recommendation", subheader_style,
                           rows = current_row, cols = 1)
        for (i in seq_along(synthesis$risks$downside)) {
          openxlsx::writeData(wb, "Recommendation",
                              pricing_escape_cell(paste0("* ", synthesis$risks$downside[i])),
                              startRow = current_row + i)
        }
        current_row <- current_row + length(synthesis$risks$downside) + 3
      }
    }

    # Executive Summary sheet
    openxlsx::addWorksheet(wb, "Executive_Summary")
    summary_lines <- strsplit(synthesis$executive_summary, "\n")[[1]]
    for (i in seq_along(summary_lines)) {
      openxlsx::writeData(wb, "Executive_Summary", pricing_escape_cell(summary_lines[i]), startRow = i)
    }
    openxlsx::setColWidths(wb, "Executive_Summary", cols = 1, widths = 80)
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

  openxlsx::writeData(wb, "Configuration", pricing_escape_df(config_df), headerStyle = header_style)
  openxlsx::setColWidths(wb, "Configuration", cols = 1:2, widths = c(25, 50))

  # --------------------------------------------------------------------------
  # TRS Run_Status Sheet (TRS v1.0)
  # --------------------------------------------------------------------------
  if (!is.null(run_result)) {
    if (exists("turas_write_run_status_sheet", mode = "function")) {
      turas_write_run_status_sheet(wb, run_result)
    }
  }

  # --------------------------------------------------------------------------
  # Save Workbook (TRS v1.0: Use atomic save if available)
  # --------------------------------------------------------------------------
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_file, run_result = run_result, module = "PRICE")
    if (!save_result$success) {
      pricing_refuse(
        code = "IO_SAVE_FAILED",
        title = "Failed to Save Excel File",
        problem = sprintf("Could not write output file: %s", save_result$error),
        why_it_matters = "Results cannot be saved and will be lost",
        how_to_fix = c(
          "Check write permissions for the output directory",
          "Ensure the file is not open in another program",
          "Verify sufficient disk space is available"
        ),
        observed = sprintf("Error: %s", save_result$error),
        expected = sprintf("File saved to: %s", output_file)
      )
    }
  } else {
    openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
  }

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
    write.csv(pp_df, pp_file, row.names = FALSE, fileEncoding = "UTF-8")
    saved_files <- c(saved_files, pp_file)

    # Curves
    curves_file <- file.path(output_dir, "vw_curves.csv")
    write.csv(vw$curves, curves_file, row.names = FALSE, fileEncoding = "UTF-8")
    saved_files <- c(saved_files, curves_file)
  }

  if (method %in% c("gabor_granger", "both")) {
    gg <- if (method == "both") results$gabor_granger else results

    # Demand curve
    demand_file <- file.path(output_dir, "gg_demand_curve.csv")
    write.csv(gg$demand_curve, demand_file, row.names = FALSE, fileEncoding = "UTF-8")
    saved_files <- c(saved_files, demand_file)

    # Revenue curve
    revenue_file <- file.path(output_dir, "gg_revenue_curve.csv")
    write.csv(gg$revenue_curve, revenue_file, row.names = FALSE, fileEncoding = "UTF-8")
    saved_files <- c(saved_files, revenue_file)
  }

  return(saved_files)
}
