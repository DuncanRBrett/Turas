# ==============================================================================
# KEYDRIVER HTML REPORT - SECTION BUILDERS
# ==============================================================================
# Content section builders for each report section/tab.
#
# Extracted from 03_page_builder.R for maintainability.
#
# FUNCTIONS:
# - build_kd_exec_summary_section()  - Executive summary
# - build_kd_importance_section()    - Importance rankings
# - build_kd_method_section()        - Method comparison
# - build_kd_effect_size_section()   - Effect sizes
# - build_kd_correlation_section()   - Correlation matrix
# - build_kd_quadrant_section()      - Priority quadrant
# - build_kd_shap_section()          - SHAP analysis
# - build_kd_diagnostics_section()   - Model diagnostics
# - build_kd_bootstrap_section()     - Bootstrap CIs
# - build_kd_segment_section()       - Segment comparison
# - build_kd_interpretation_guide()  - Guide section
# - build_kd_pinned_panel()          - Pinned views
# ==============================================================================

# ==============================================================================
# EXECUTIVE SUMMARY SECTION
# ==============================================================================

#' Build Executive Summary Section
#'
#' Key findings from html_data narrative, model confidence callout, and
#' top-3 driver callout cards.
#'
#' @param html_data Transformed HTML data
#' @param config Configuration list
#' @return htmltools tag
#' @keywords internal
build_kd_exec_summary_section <- function(html_data, config = list()) {

  model_info <- html_data$model_info

  # --- Model confidence callout ---
  confidence_html <- NULL
  r2 <- model_info$r_squared
  if (!is.null(r2) && !is.na(r2)) {
    r2_pct <- round(r2 * 100, 1)
    n_drv  <- model_info$n_drivers %||% html_data$n_drivers %||% 0

    if (r2 >= 0.75) {
      conf_class <- "kd-confidence-excellent"
      conf_text <- sprintf(
        "Excellent model fit (R\u00B2 = %.3f). The %d drivers explain %.1f%% of variation in the outcome.",
        r2, n_drv, r2_pct)
    } else if (r2 >= 0.50) {
      conf_class <- "kd-confidence-good"
      conf_text <- sprintf(
        "Good model fit (R\u00B2 = %.3f). The %d drivers explain %.1f%% of variation in the outcome.",
        r2, n_drv, r2_pct)
    } else if (r2 >= 0.25) {
      conf_class <- "kd-confidence-moderate"
      conf_text <- sprintf(
        "Moderate model fit (R\u00B2 = %.3f). The %d drivers explain %.1f%% of variation. Other unmeasured factors may also play a role.",
        r2, n_drv, r2_pct)
    } else {
      conf_class <- "kd-confidence-limited"
      conf_text <- sprintf(
        "Limited model fit (R\u00B2 = %.3f). The %d drivers explain only %.1f%% of variation. Key unmeasured factors likely influence the outcome.",
        r2, n_drv, r2_pct)
    }

    confidence_html <- htmltools::tags$div(
      class = paste("kd-model-confidence", conf_class),
      htmltools::tags$strong("Model Confidence: "), conf_text
    )
  }

  # --- Top 3 driver callout cards ---
  driver_cards <- NULL
  if (!is.null(html_data$importance) && length(html_data$importance) > 0) {
    top_n <- min(3, length(html_data$importance))
    driver_cards <- lapply(html_data$importance[1:top_n], function(d) {
      pct_text <- if (!is.null(d$pct) && !is.na(d$pct)) {
        sprintf("%.0f%% relative importance", d$pct)
      } else {
        "Top ranked driver"
      }
      htmltools::tags$div(
        class = "kd-callout",
        htmltools::tags$div(class = "kd-callout-title",
                            sprintf("#%d %s", d$rank, d$label)),
        htmltools::tags$div(class = "kd-callout-text", pct_text)
      )
    })
  }

  # --- Narrative insights ---
  narrative <- html_data$narrative
  narrative_html <- NULL
  if (!is.null(narrative) && length(narrative$insights) > 0) {
    insight_items <- lapply(narrative$insights, function(txt) {
      htmltools::tags$li(class = "kd-key-insight-item", txt)
    })
    narrative_html <- htmltools::tags$div(
      style = "margin-bottom:16px;",
      htmltools::tags$h3(class = "kd-key-insights-heading", "Key Insights"),
      htmltools::tags$ul(style = "padding-left:20px;", insight_items)
    )
  }

  # --- Key findings ---
  findings_html <- NULL
  if (!is.null(narrative) && !is.null(narrative$key_findings) &&
      length(narrative$key_findings) > 0) {
    finding_items <- lapply(narrative$key_findings, function(f) {
      if (is.list(f)) {
        dir <- f$direction %||% "neutral"
        if (identical(dir, "positive")) {
          icon   <- "\u2191"
          colour <- "var(--kd-success)"
        } else if (identical(dir, "negative")) {
          icon   <- "\u2193"
          colour <- "var(--kd-danger)"
        } else {
          icon   <- "\u2022"
          colour <- "var(--kd-brand)"
        }
        f_text <- f$text %||% ""
      } else {
        icon   <- "\u2022"
        colour <- "var(--kd-text-muted)"
        f_text <- as.character(f)
      }
      htmltools::tags$div(
        class = "kd-finding-item",
        htmltools::tags$span(class = "kd-finding-icon",
                             style = sprintf("color:%s;", colour), icon),
        htmltools::tags$span(class = "kd-finding-text", f_text)
      )
    })
    findings_html <- htmltools::tags$div(
      class = "kd-finding-box",
      htmltools::tags$h3(class = "kd-top-drivers-label",
                         "Standout Findings"),
      finding_items
    )
  }

  # --- Assemble section ---
  title_row    <- build_kd_section_title_row("Executive Summary", "exec-summary")
  insight_area <- build_kd_insight_area("exec-summary", config = config)

  htmltools::tags$div(
    class = "kd-section kd-page-active", id = "kd-exec-summary",
    `data-kd-section` = "exec-summary",
    title_row, insight_area,
    confidence_html, narrative_html, driver_cards, findings_html
  )
}


# ==============================================================================
# IMPORTANCE SECTION
# ==============================================================================

#' Build Importance Summary Section
#'
#' Chart (if available) + table with pin button and filter bar.
#'
#' @param charts Chart list
#' @param tables Table list
#' @param html_data Transformed HTML data (for n_drivers)
#' @return htmltools tag
#' @keywords internal
build_kd_importance_section <- function(charts, tables, html_data, config = NULL) {

  n_drivers <- html_data$n_drivers %||% 0

  title_row    <- build_kd_section_title_row("Driver Importance", "importance")
  insight_area <- build_kd_insight_area("importance", config = config)

  # Filter bar for many drivers
  filter_bar <- NULL
  if (n_drivers > 5) {
    filter_bar <- build_kd_importance_filter_bar(n_drivers)
  }

  chart_wrapper <- if (!is.null(charts$importance)) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      charts$importance
    )
  }

  table_wrapper <- if (!is.null(tables$importance)) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      filter_bar,
      tables$importance
    )
  }

  # Methodology callout (from shared registry)
  methodology_callout <- htmltools::HTML(
    turas_callout("keydriver", "shapley_importance", collapsed = TRUE)
  )

  htmltools::tags$div(
    class = "kd-section", id = "kd-importance",
    `data-kd-section` = "importance",
    title_row, insight_area,
    htmltools::tags$p(
      class = "kd-section-intro",
      "Relative importance of each driver in explaining the outcome. Higher percentage means stronger relationship with the dependent variable."
    ),
    methodology_callout,
    chart_wrapper, table_wrapper
  )
}


#' Build Importance Filter Bar
#'
#' Threshold chip options: All | Top 3 | Top 5 | Top 8.
#'
#' @param n_drivers Number of drivers
#' @return htmltools tag
#' @keywords internal
build_kd_importance_filter_bar <- function(n_drivers = 0) {

  options <- list(
    list(label = "All",   mode = "all"),
    list(label = "Top 3", mode = "top-3"),
    list(label = "Top 5", mode = "top-5")
  )
  if (n_drivers > 8) {
    options <- c(options, list(list(label = "Top 8", mode = "top-8")))
  }

  chips <- lapply(options, function(opt) {
    active_class <- if (opt$mode == "all") " active" else ""
    htmltools::tags$button(
      class = paste0("kd-or-chip", active_class),
      `data-kd-imp-mode` = opt$mode,
      onclick = sprintf("kdFilterImportanceBars('%s')", opt$mode),
      opt$label
    )
  })

  htmltools::tags$div(
    class = "kd-or-chip-bar", id = "kd-importance-filter",
    style = "margin-top: 6px; margin-bottom: 2px;",
    htmltools::tags$span(
      style = "font-size:12px;color:#64748b;font-weight:500;margin-right:8px;",
      "Show:"
    ),
    chips
  )
}


# ==============================================================================
# METHOD COMPARISON SECTION
# ==============================================================================

#' Build Method Comparison Section
#'
#' Agreement chart + rank comparison table.
#'
#' @param charts Chart list
#' @param tables Table list
#' @return htmltools tag
#' @keywords internal
build_kd_method_section <- function(charts, tables, html_data = NULL, config = NULL) {

  title_row    <- build_kd_section_title_row("Method Comparison",
                                              "method-comparison")
  insight_area <- build_kd_insight_area("method-comparison", config = config)

  # Method explanation callout (from shared registry)
  method_callout <- htmltools::HTML(
    turas_callout("keydriver", "method_comparison", collapsed = TRUE)
  )

  chart_wrapper <- if (!is.null(charts$method_agreement)) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      charts$method_agreement
    )
  }

  table_wrapper <- if (!is.null(tables$method_comparison)) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      tables$method_comparison
    )
  }

  htmltools::tags$div(
    class = "kd-section", id = "kd-method-comparison",
    `data-kd-section` = "method-comparison",
    title_row, insight_area,
    htmltools::tags$p(
      class = "kd-section-intro",
      "Comparison of driver rankings across different analytical methods. Consistent rankings across methods provide stronger evidence of true driver importance."
    ),
    method_callout,
    chart_wrapper, table_wrapper
  )
}


# ==============================================================================
# EFFECT SIZES SECTION
# ==============================================================================

#' Build Effect Sizes Section
#'
#' Only rendered if effect_sizes data is available.
#'
#' @param charts Chart list
#' @param tables Table list
#' @param html_data Transformed HTML data
#' @return htmltools tag or NULL
#' @keywords internal
build_kd_effect_size_section <- function(charts, tables, html_data, config = NULL) {

  if (is.null(html_data$effect_sizes)) return(NULL)

  title_row    <- build_kd_section_title_row("Effect Sizes", "effect-sizes")
  insight_area <- build_kd_insight_area("effect-sizes", config = config)

  chart_wrapper <- if (!is.null(charts$effect_sizes)) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      charts$effect_sizes
    )
  }

  table_wrapper <- if (!is.null(tables$effect_sizes)) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      tables$effect_sizes
    )
  }

  # Cohen's f-squared benchmark callout (from shared registry)
  benchmark_callout <- htmltools::HTML(
    turas_callout("keydriver", "effect_sizes", collapsed = TRUE)
  )

  htmltools::tags$div(
    class = "kd-section", id = "kd-effect-sizes",
    `data-kd-section` = "effect-sizes",
    title_row, insight_area,
    htmltools::tags$p(
      class = "kd-section-intro",
      "Standardised effect sizes provide a scale-free measure of each driver's practical impact. Larger absolute values indicate stronger practical significance."
    ),
    benchmark_callout,
    chart_wrapper, table_wrapper
  )
}


# ==============================================================================
# CORRELATION MATRIX SECTION
# ==============================================================================

#' Build Correlation Matrix Section
#'
#' Heatmap chart + correlation table.
#'
#' @param charts Chart list
#' @param tables Table list
#' @return htmltools tag
#' @keywords internal
build_kd_correlation_section <- function(charts, tables,
                                          display_mode = "heatmap", config = NULL) {

  title_row    <- build_kd_section_title_row("Correlation Matrix", "correlations")
  insight_area <- build_kd_insight_area("correlations", config = config)

  chart_wrapper <- if (!is.null(charts$correlation_heatmap) &&
                       display_mode %in% c("heatmap", "both")) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      charts$correlation_heatmap
    )
  }

  table_wrapper <- if (!is.null(tables$correlations) &&
                       display_mode %in% c("table", "both")) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      tables$correlations
    )
  }

  # Correlation interpretation callout (from shared registry)
  corr_callout <- htmltools::HTML(
    turas_callout("keydriver", "correlation_matrix", collapsed = TRUE)
  )

  htmltools::tags$div(
    class = "kd-section", id = "kd-correlations",
    `data-kd-section` = "correlations",
    title_row, insight_area,
    htmltools::tags$p(
      class = "kd-section-intro",
      "Bivariate correlations between all drivers and the outcome. High inter-driver correlations may indicate multicollinearity. See VIF diagnostics for formal assessment."
    ),
    corr_callout,
    chart_wrapper, table_wrapper
  )
}


# ==============================================================================
# QUADRANT / IPA SECTION
# ==============================================================================

#' Build Quadrant (IPA) Section
#'
#' Only rendered if quadrant data is available.
#'
#' @param charts Chart list
#' @param tables Table list
#' @param html_data Transformed HTML data
#' @return htmltools tag or NULL
#' @keywords internal
build_kd_quadrant_section <- function(charts, tables, html_data, config = NULL) {

  if (!isTRUE(html_data$has_quadrant)) return(NULL)

  title_row    <- build_kd_section_title_row("Importance-Performance Quadrant",
                                              "quadrant")
  insight_area <- build_kd_insight_area("quadrant", config = config)

  chart_wrapper <- if (!is.null(charts$quadrant)) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      charts$quadrant
    )
  }

  table_wrapper <- if (!is.null(tables$quadrant_actions)) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      tables$quadrant_actions
    )
  }

  # Priority order callout (from shared registry)
  priority_callout <- htmltools::HTML(
    turas_callout("keydriver", "priority_quadrant", collapsed = TRUE)
  )

  # Action legend callout
  action_legend <- htmltools::tags$div(
    class = "kd-callout", style = "margin-top:4px;",
    htmltools::tags$div(class = "kd-callout-title", "Action Guide"),
    htmltools::tags$div(
      style = "display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin:10px 0;",
      htmltools::tags$div(
        style = "text-align:center;padding:8px;background:#fee2e2;border-radius:6px;",
        htmltools::tags$div(style = "font-weight:700;font-size:12px;color:#991b1b;",
                            "IMPROVE"),
        htmltools::tags$div(style = "font-size:10px;color:#991b1b;line-height:1.4;",
                            "High importance, low performance. Focus improvement here.")
      ),
      htmltools::tags$div(
        style = "text-align:center;padding:8px;background:#dcfce7;border-radius:6px;",
        htmltools::tags$div(style = "font-weight:700;font-size:12px;color:#166534;",
                            "MAINTAIN"),
        htmltools::tags$div(style = "font-size:10px;color:#166534;line-height:1.4;",
                            "High importance, high performance. Protect these strengths.")
      ),
      htmltools::tags$div(
        style = "text-align:center;padding:8px;background:#f1f5f9;border-radius:6px;",
        htmltools::tags$div(style = "font-weight:700;font-size:12px;color:#64748b;",
                            "MONITOR"),
        htmltools::tags$div(style = "font-size:10px;color:#64748b;line-height:1.4;",
                            "Low importance, low performance. Watch but low urgency.")
      ),
      htmltools::tags$div(
        style = "text-align:center;padding:8px;background:#dbeafe;border-radius:6px;",
        htmltools::tags$div(style = "font-weight:700;font-size:12px;color:#1e40af;",
                            "ASSESS"),
        htmltools::tags$div(style = "font-size:10px;color:#1e40af;line-height:1.4;",
                            "Low importance, high performance. Consider reallocating resources.")
      )
    )
  )

  htmltools::tags$div(
    class = "kd-section", id = "kd-quadrant",
    `data-kd-section` = "quadrant",
    title_row, insight_area,
    htmltools::tags$p(
      class = "kd-section-intro",
      paste0(
        "Importance-Performance Analysis maps each driver by its statistical ",
        "importance (y-axis) and current performance score (x-axis). Drivers ",
        "in the upper-left quadrant are high importance but low performance ",
        "\u2014 priority improvement areas."
      )
    ),
    priority_callout,
    chart_wrapper, action_legend, table_wrapper
  )
}


# ==============================================================================
# SHAP SUMMARY SECTION
# ==============================================================================

#' Build SHAP Summary Section
#'
#' Brief SHAP importance info. Only rendered if SHAP data available.
#'
#' @param html_data Transformed HTML data
#' @return htmltools tag or NULL
#' @keywords internal
build_kd_shap_section <- function(html_data, charts = list(), config = NULL) {

  if (!isTRUE(html_data$has_shap)) return(NULL)

  title_row    <- build_kd_section_title_row("SHAP Importance", "shap-summary")
  insight_area <- build_kd_insight_area("shap-summary", config = config)

  # SHAP chart (from charts list, built in orchestrator)
  chart_wrapper <- if (!is.null(charts$shap_importance)) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      charts$shap_importance
    )
  }

  # Collapsible explanation
  shap_note <- htmltools::tags$details(
    style = "margin-top:12px;",
    htmltools::tags$summary(
      style = "cursor:pointer;font-weight:600;font-size:12px;color:var(--kd-text-muted);",
      "What is SHAP?"
    ),
    htmltools::tags$div(
      class = "kd-callout", style = "margin-top:8px;",
      htmltools::tags$div(
        class = "kd-callout-text",
        paste0(
          "SHAP (SHapley Additive exPlanations) values provide a game-theoretic ",
          "approach to feature importance. They decompose each prediction into ",
          "additive contributions from each driver, accounting for interactions ",
          "between variables. Values are computed using the shapr package and ",
          "represent the mean absolute SHAP contribution across all observations."
        )
      )
    )
  )

  # SHAP vs driver importance callout
  shap_diff_callout <- htmltools::tags$div(
    class = "kd-callout",
    htmltools::tags$div(class = "kd-callout-title",
                        "Why do SHAP values differ from driver importance?"),
    htmltools::tags$div(
      class = "kd-callout-text",
      paste0(
        "The driver importance section uses a linear regression model (Shapley value ",
        "decomposition of R\u00B2), which assumes each driver has a constant, additive ",
        "effect on the outcome. SHAP values are derived from an XGBoost model that ",
        "captures non-linear relationships and interaction effects between drivers. ",
        "Because of this, a driver may rank differently in SHAP analysis \u2014 for example, ",
        "a driver with a modest linear correlation but strong non-linear or threshold ",
        "effects will appear more important in SHAP. When both methods agree on a ",
        "driver's importance, confidence is high. Discrepancies highlight drivers ",
        "worth investigating for non-linear effects or interactions."
      )
    )
  )

  htmltools::tags$div(
    class = "kd-section", id = "kd-shap-summary",
    `data-kd-section` = "shap-summary",
    title_row, insight_area,
    htmltools::tags$p(
      class = "kd-section-intro",
      paste0(
        "SHAP-based feature importance shows each driver's contribution to the ",
        "model's predictions, accounting for interactions between variables."
      )
    ),
    shap_diff_callout,
    chart_wrapper,
    shap_note
  )
}


# ==============================================================================
# MODEL DIAGNOSTICS SECTION
# ==============================================================================

#' Build Model Diagnostics Section
#'
#' Model summary table + VIF table + fit statistic cards.
#'
#' @param tables Table list
#' @param html_data Transformed HTML data
#' @return htmltools tag
#' @keywords internal
build_kd_diagnostics_section <- function(tables, html_data, config = NULL) {

  model_info <- html_data$model_info

  # --- Model fit statistic cards ---
  fit_cards <- list()

  # R-squared
  r2 <- model_info$r_squared
  if (!is.null(r2) && !is.na(r2)) {
    r2_label <- if (r2 >= 0.75) "Excellent"
                else if (r2 >= 0.50) "Good"
                else if (r2 >= 0.25) "Moderate"
                else "Limited"
    fit_cards <- c(fit_cards, list(htmltools::tags$div(
      class = "kd-fit-card",
      htmltools::tags$div(class = "kd-fit-card-value",
                          sprintf("%.3f", r2)),
      htmltools::tags$div(class = "kd-fit-card-label",
                          htmltools::HTML("R\u00B2")),
      htmltools::tags$div(class = "kd-fit-card-quality", r2_label),
      htmltools::tags$div(class = "kd-fit-card-note",
        paste0("Proportion of variance in the outcome explained by the ",
               "drivers. Higher values indicate better model fit."))
    )))
  }

  # Adjusted R-squared
  adj_r2 <- model_info$adj_r_squared
  if (!is.null(adj_r2) && !is.na(adj_r2)) {
    fit_cards <- c(fit_cards, list(htmltools::tags$div(
      class = "kd-fit-card",
      htmltools::tags$div(class = "kd-fit-card-value",
                          sprintf("%.3f", adj_r2)),
      htmltools::tags$div(class = "kd-fit-card-label",
                          htmltools::HTML("Adjusted R\u00B2")),
      htmltools::tags$div(class = "kd-fit-card-note",
        paste0("R\u00B2 adjusted for the number of predictors. Penalises ",
               "adding drivers that do not meaningfully improve prediction."))
    )))
  }

  # F-statistic
  f_stat <- model_info$f_statistic
  p_val  <- model_info$p_value
  if (!is.null(f_stat) && !is.na(f_stat)) {
    sig_text <- if (!is.null(p_val) && !is.na(p_val) && p_val < 0.05) {
      "Model is statistically significant"
    } else {
      "Model is not statistically significant"
    }
    p_formatted <- if (!is.null(p_val) && !is.na(p_val)) {
      if (p_val < 0.001) "p < 0.001" else sprintf("p = %.3f", p_val)
    } else { "" }

    fit_cards <- c(fit_cards, list(htmltools::tags$div(
      class = "kd-fit-card",
      htmltools::tags$div(class = "kd-fit-card-value",
                          sprintf("F = %.2f", f_stat)),
      htmltools::tags$div(class = "kd-fit-card-label", p_formatted),
      htmltools::tags$div(class = "kd-fit-card-quality", sig_text),
      htmltools::tags$div(class = "kd-fit-card-note",
        paste0("Tests whether the drivers collectively predict the outcome ",
               "better than chance alone."))
    )))
  }

  # RMSE
  rmse <- model_info$rmse
  if (!is.null(rmse) && !is.na(rmse)) {
    fit_cards <- c(fit_cards, list(htmltools::tags$div(
      class = "kd-fit-card",
      htmltools::tags$div(class = "kd-fit-card-value",
                          sprintf("%.3f", rmse)),
      htmltools::tags$div(class = "kd-fit-card-label", "RMSE"),
      htmltools::tags$div(class = "kd-fit-card-note",
        paste0("Root Mean Square Error. Lower values indicate better ",
               "prediction accuracy. Compare to the standard deviation ",
               "of the outcome variable for context."))
    )))
  }

  fit_html <- if (length(fit_cards) > 0) {
    htmltools::tags$div(
      style = "margin-top:16px;",
      htmltools::tags$h3(class = "kd-panel-heading-label",
                         "Model Fit Statistics"),
      htmltools::tags$div(class = "kd-fit-cards-grid", fit_cards)
    )
  }

  title_row    <- build_kd_section_title_row("Model Diagnostics", "diagnostics")
  insight_area <- build_kd_insight_area("diagnostics", config = config)

  # Model summary table
  model_summary_el <- if (!is.null(tables$model_summary)) {
    htmltools::tags$div(
      style = "margin-bottom:16px;",
      htmltools::tags$h3(class = "kd-panel-heading-label", "Model Summary"),
      tables$model_summary
    )
  }

  # VIF diagnostics table
  vif_el <- if (!is.null(tables$vif)) {
    htmltools::tags$div(
      style = "margin-top:16px;",
      htmltools::tags$h3(class = "kd-panel-heading-label",
                         "Variance Inflation Factors (VIF)"),
      htmltools::tags$p(
        class = "kd-section-intro",
        paste0("VIF measures multicollinearity between drivers. VIF > 5 ",
               "suggests moderate concern; VIF > 10 indicates severe ",
               "multicollinearity.")
      ),
      tables$vif
    )
  }

  # --- Verdict banner ---
  verdict_html <- NULL
  if (!is.null(r2) && !is.na(r2)) {
    is_sig <- !is.null(p_val) && !is.na(p_val) && p_val < 0.05

    # Check for severe multicollinearity (VIF > 10)
    has_severe_vif <- FALSE
    vif_warning <- ""
    vif_vals <- html_data$vif_values
    if (!is.null(vif_vals) && is.data.frame(vif_vals) && "VIF" %in% names(vif_vals)) {
      max_vif <- max(vif_vals$VIF, na.rm = TRUE)
      if (!is.na(max_vif) && max_vif > 10) {
        has_severe_vif <- TRUE
        high_vif_drivers <- vif_vals$Driver[vif_vals$VIF > 10]
        vif_warning <- sprintf(
          " Note: severe multicollinearity detected (VIF > 10 for %s). Individual driver importance estimates may be unreliable.",
          paste(high_vif_drivers, collapse = ", ")
        )
      }
    }

    if (r2 >= 0.50 && is_sig && !has_severe_vif) {
      verdict_text  <- "Reliable"
      verdict_desc  <- "The model explains a substantial share of variance and is statistically significant. Results can be used with confidence for decision-making."
      verdict_bg    <- "#dcfce7"; verdict_border <- "#22c55e"; verdict_fg <- "#166534"
    } else if (r2 >= 0.50 && is_sig && has_severe_vif) {
      verdict_text  <- "Directionally Reliable"
      verdict_desc  <- paste0(
        "The model explains a substantial share of variance and is significant, but severe multicollinearity undermines individual driver estimates.",
        vif_warning
      )
      verdict_bg    <- "#dbeafe"; verdict_border <- "#3b82f6"; verdict_fg <- "#1e40af"
    } else if (r2 >= 0.25 && is_sig) {
      verdict_text  <- "Directionally Reliable"
      verdict_desc  <- paste0(
        "The model explains a moderate share of variance and is significant. Rankings are directionally sound but exact percentages should be interpreted with care.",
        vif_warning
      )
      verdict_bg    <- "#dbeafe"; verdict_border <- "#3b82f6"; verdict_fg <- "#1e40af"
    } else if (r2 >= 0.10 && is_sig) {
      verdict_text  <- "Interpret with Caution"
      verdict_desc  <- paste0(
        "The model has limited explanatory power. Driver rankings may be indicative but should be corroborated with other evidence before acting.",
        vif_warning
      )
      verdict_bg    <- "#fef9c3"; verdict_border <- "#eab308"; verdict_fg <- "#854d0e"
    } else {
      verdict_text  <- "Exploratory Only"
      verdict_desc  <- if (!is_sig) {
        paste0("The model is not statistically significant. These results should be treated as exploratory and not used for decision-making.", vif_warning)
      } else {
        paste0("The model explains very little variance. Results are exploratory and should be validated with additional data.", vif_warning)
      }
      verdict_bg    <- "#fef2f2"; verdict_border <- "#ef4444"; verdict_fg <- "#991b1b"
    }

    verdict_html <- htmltools::tags$div(
      style = sprintf(
        "padding:16px 20px;margin-bottom:20px;border-radius:8px;background:%s;border-left:4px solid %s;",
        verdict_bg, verdict_border
      ),
      htmltools::tags$div(
        style = sprintf("font-size:16px;font-weight:700;color:%s;margin-bottom:4px;", verdict_fg),
        verdict_text
      ),
      htmltools::tags$div(
        style = sprintf("font-size:13px;color:%s;line-height:1.5;", verdict_fg),
        verdict_desc
      )
    )
  }

  htmltools::tags$div(
    class = "kd-section", id = "kd-diagnostics",
    `data-kd-section` = "diagnostics",
    title_row, insight_area,
    verdict_html,
    model_summary_el, fit_html, vif_el
  )
}


# ==============================================================================
# BOOTSTRAP CI SECTION
# ==============================================================================

#' Build Bootstrap Confidence Intervals Section
#'
#' Forest plot + CI table. Only rendered if bootstrap data available.
#'
#' @param charts Chart list
#' @param tables Table list
#' @param html_data Transformed HTML data
#' @return htmltools tag or NULL
#' @keywords internal
build_kd_bootstrap_section <- function(charts, tables, html_data,
                                        display_mode = "summary", config = NULL) {

  if (!isTRUE(html_data$has_bootstrap)) return(NULL)

  title_row    <- build_kd_section_title_row("Bootstrap Confidence Intervals",
                                              "bootstrap-ci")
  insight_area <- build_kd_insight_area("bootstrap-ci", config = config)

  chart_wrapper <- if (!is.null(charts$bootstrap_ci) &&
                       display_mode %in% c("summary", "full")) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      charts$bootstrap_ci
    )
  }

  table_wrapper <- if (!is.null(tables$bootstrap_ci) &&
                       display_mode %in% c("table", "full")) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      tables$bootstrap_ci
    )
  }

  htmltools::tags$div(
    class = "kd-section", id = "kd-bootstrap-ci",
    `data-kd-section` = "bootstrap-ci",
    title_row, insight_area,
    htmltools::tags$p(
      class = "kd-section-intro",
      paste0(
        "Bootstrap resampling provides non-parametric confidence intervals ",
        "for driver coefficients. Narrow intervals indicate stable estimates; ",
        "wide intervals suggest sensitivity to sample composition."
      )
    ),
    chart_wrapper, table_wrapper
  )
}


# ==============================================================================
# SEGMENT COMPARISON SECTION
# ==============================================================================

#' Build Segment Comparison Section
#'
#' Only rendered if segment comparison data is available.
#'
#' @param tables Table list
#' @param html_data Transformed HTML data
#' @return htmltools tag or NULL
#' @keywords internal
build_kd_segment_section <- function(charts, tables, html_data, config = NULL) {

  if (is.null(html_data$segment_comparison)) return(NULL)

  title_row    <- build_kd_section_title_row("Segment Comparison",
                                              "segment-comparison")
  insight_area <- build_kd_insight_area("segment-comparison", config = config)

  # Extract segment names for chip bar
  seg_data <- html_data$segment_comparison
  seg_df <- if (is.data.frame(seg_data)) seg_data
            else if (is.list(seg_data) && !is.null(seg_data$comparison_matrix))
              seg_data$comparison_matrix
            else NULL

  seg_names <- character(0)
  if (!is.null(seg_df) && is.data.frame(seg_df)) {
    pct_cols  <- grep("_Pct$", names(seg_df), value = TRUE)
    rank_cols <- grep("_Rank$", names(seg_df), value = TRUE)
    all_seg   <- sub("_Pct$", "", pct_cols)
    seg_names <- all_seg[paste0(all_seg, "_Rank") %in% rank_cols]
  }

  # Segment show/hide chips + sort control
  control_bar <- NULL
  if (length(seg_names) > 0) {
    # Chips — "All" chip + one per segment + Total
    all_names <- c("Total", seg_names)
    chip_list <- list(
      htmltools::tags$button(
        class = "kd-or-chip active",
        `data-kd-seg-chip` = "all",
        onclick = "kdToggleAllSegments(true)",
        "All"
      )
    )
    for (sn in all_names) {
      chip_list <- c(chip_list, list(
        htmltools::tags$button(
          class = "kd-or-chip active",
          `data-kd-seg-chip` = sn,
          onclick = sprintf("kdToggleSegment('%s')", sn),
          sn
        )
      ))
    }

    # Sort dropdown
    sort_options <- list(
      htmltools::tags$option(value = "default", "Original order")
    )
    for (sn in all_names) {
      sort_options <- c(sort_options, list(
        htmltools::tags$option(value = sn, paste0("Sort by ", sn, " %"))
      ))
    }

    control_bar <- htmltools::tags$div(
      class = "kd-seg-controls",
      id = "kd-seg-controls",
      htmltools::tags$div(
        class = "kd-seg-chips",
        htmltools::tags$span(
          style = "font-size:11px;font-weight:600;color:var(--kd-text-muted);margin-right:8px;",
          "Show:"
        ),
        chip_list
      ),
      htmltools::tags$div(
        class = "kd-seg-sort",
        htmltools::tags$label(
          `for` = "kd-seg-sort-select",
          style = "font-size:11px;font-weight:600;color:var(--kd-text-muted);margin-right:6px;",
          "Sort:"
        ),
        htmltools::tags$select(
          id = "kd-seg-sort-select",
          class = "kd-seg-sort-select",
          onchange = "kdSortSegmentTable(this.value)",
          sort_options
        )
      )
    )
  }

  chart_wrapper <- if (!is.null(charts$segment_comparison)) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      charts$segment_comparison
    )
  }

  table_wrapper <- if (!is.null(tables$segment_comparison)) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      tables$segment_comparison
    )
  }

  htmltools::tags$div(
    class = "kd-section", id = "kd-segment-comparison",
    `data-kd-section` = "segment-comparison",
    title_row, insight_area,
    htmltools::tags$p(
      class = "kd-section-intro",
      paste0(
        "Driver importance compared across customer segments. Large rank ",
        "differences suggest that different segments are motivated by different ",
        "factors, which may warrant segment-specific strategies."
      )
    ),
    control_bar,
    chart_wrapper, table_wrapper
  )
}


# ==============================================================================
# INTERPRETATION GUIDE
# ==============================================================================

#' Build Interpretation Guide Section
#'
#' Static help content explaining how to read the report.
#'
#' @return htmltools tag
#' @keywords internal
build_kd_interpretation_guide <- function() {

  title_row <- build_kd_section_title_row(
    "How to Interpret These Results", "interpretation", show_pin = FALSE
  )

  htmltools::tags$div(
    class = "kd-section", id = "kd-interpretation",
    `data-kd-section` = "interpretation",
    title_row,
    htmltools::tags$div(
      class = "kd-interp-grid",
      htmltools::tags$div(
        htmltools::tags$h3(
          class = "kd-panel-heading-label",
          style = "color:var(--kd-success);", "DO"
        ),
        htmltools::tags$ul(
          class = "kd-interp-list",
          htmltools::tags$li("Focus on drivers that rank consistently high across multiple methods"),
          htmltools::tags$li("Use relative importance percentages to prioritise resources"),
          htmltools::tags$li("Check the correlation matrix for highly correlated driver pairs"),
          htmltools::tags$li("Validate key findings with qualitative research or experiments"),
          htmltools::tags$li("Consider bootstrap CIs to assess estimate stability")
        )
      ),
      htmltools::tags$div(
        htmltools::tags$h3(
          class = "kd-panel-heading-label",
          style = "color:var(--kd-danger);", "DON'T"
        ),
        htmltools::tags$ul(
          class = "kd-interp-list",
          htmltools::tags$li("Make causal claims without experimental evidence"),
          htmltools::tags$li("Over-interpret small differences in importance percentages"),
          htmltools::tags$li("Ignore multicollinearity warnings from VIF diagnostics"),
          htmltools::tags$li("Treat a single method's ranking as definitive"),
          htmltools::tags$li("Assume results generalise to different populations")
        )
      )
    ),
    htmltools::tags$div(
      class = "kd-interp-note",
      htmltools::tags$strong("Note: "),
      paste0(
        "Key driver analysis identifies statistical associations, not causal ",
        "relationships. Correlation-based importance may differ from ",
        "regression-based importance when drivers are intercorrelated. Use ",
        "multiple methods to triangulate findings."
      )
    )
  )
}


# ==============================================================================
# PINNED VIEWS PANEL
# ==============================================================================

#' Build Pinned Views Panel
#'
#' Container for pinned items with export controls.
#'
#' @return htmltools tag
#' @keywords internal
build_kd_pinned_panel <- function(config = list()) {

  # --- Build config-driven slide cards from CustomSlides sheet ---
  config_slides <- NULL
  cs <- config$custom_slides
  if (!is.null(cs) && is.data.frame(cs) && nrow(cs) > 0) {
    config_slides <- lapply(seq_len(nrow(cs)), function(i) {
      slide_id <- paste0("kd-cfgslide-", i)
      title   <- as.character(cs$slide_title[i] %||% "Slide")
      content <- as.character(cs$slide_content[i] %||% "")
      img_path <- if ("image_path" %in% names(cs)) as.character(cs$image_path[i]) else NA

      # Convert image to base64 if path exists
      img_data <- ""
      img_preview_style <- "display:none;"
      if (!is.na(img_path) && nzchar(img_path)) {
        full_path <- if (file.exists(img_path)) {
          img_path
        } else if (!is.null(config$project_root)) {
          file.path(config$project_root, img_path)
        } else {
          NULL
        }
        if (!is.null(full_path) && file.exists(full_path)) {
          raw <- readBin(full_path, "raw", file.info(full_path)$size)
          ext <- tolower(tools::file_ext(full_path))
          mime <- switch(ext,
            "png" = "image/png", "jpg" = "image/jpeg",
            "jpeg" = "image/jpeg", "gif" = "image/gif",
            "image/png")
          img_data <- paste0("data:", mime, ";base64,", base64enc::base64encode(raw))
          img_preview_style <- ""
        }
      }

      htmltools::tags$div(
        class = "kd-qual-slide-card",
        `data-slide-id` = slide_id,
        htmltools::tags$div(
          class = "kd-qual-header",
          htmltools::tags$div(class = "kd-qual-title", contenteditable = "true", title),
          htmltools::tags$div(
            class = "kd-qual-actions",
            htmltools::tags$button(
              class = "kd-qual-btn", title = "Add image",
              onclick = sprintf("kdTriggerQualImage('%s')", slide_id),
              "\U0001F4F7"
            ),
            htmltools::tags$button(
              class = "kd-qual-btn", title = "Pin to Views",
              onclick = sprintf("kdPinQualSlide('%s')", slide_id),
              "\U0001F4CC"
            ),
            htmltools::tags$button(
              class = "kd-qual-btn", title = "Move up",
              onclick = sprintf("kdMoveQualSlide('%s',-1)", slide_id),
              htmltools::HTML("&uarr;")
            ),
            htmltools::tags$button(
              class = "kd-qual-btn", title = "Move down",
              onclick = sprintf("kdMoveQualSlide('%s',1)", slide_id),
              htmltools::HTML("&darr;")
            ),
            htmltools::tags$button(
              class = "kd-qual-btn kd-qual-delete", title = "Delete slide",
              onclick = sprintf("kdRemoveQualSlide('%s')", slide_id),
              htmltools::HTML("&times;")
            )
          )
        ),
        htmltools::tags$div(
          class = "kd-qual-img-preview", style = img_preview_style,
          htmltools::tags$img(class = "kd-qual-img-thumb", src = img_data, alt = "Slide image"),
          htmltools::tags$button(
            class = "kd-qual-img-remove",
            onclick = sprintf("kdRemoveQualImage('%s')", slide_id),
            htmltools::HTML("&times;")
          )
        ),
        htmltools::tags$input(
          type = "file", class = "kd-qual-img-input",
          accept = "image/*", style = "display:none",
          onchange = sprintf("kdHandleQualImage('%s',this)", slide_id)
        ),
        htmltools::tags$textarea(
          class = "kd-qual-md-editor", rows = "4",
          placeholder = "Enter commentary here (plain text or markdown)...",
          content
        ),
        htmltools::tags$textarea(
          class = "kd-qual-img-store", style = "display:none",
          img_data
        )
      )
    })
  }

  # Inline section — same approach as catdriver/tabs modules
  htmltools::tags$div(
    class = "kd-section", id = "kd-pinned-section",
    `data-kd-section` = "pinned-views",
    htmltools::tags$div(
      class = "kd-pinned-panel-header",
      htmltools::tags$div(class = "kd-pinned-panel-title",
                          "\U0001F4CC Pinned Views"),
      htmltools::tags$div(
        class = "kd-pinned-panel-actions",
        htmltools::tags$button(
          class = "kd-pinned-panel-btn",
          onclick = "kdAddSection()",
          "\u2795 Add Section"
        ),
        htmltools::tags$button(
          class = "kd-pinned-panel-btn",
          onclick = "kdAddQualSlide()",
          "\U0001F4DD Add Slide"
        ),
        htmltools::tags$button(
          class = "kd-pinned-panel-btn",
          onclick = "kdExportAllPinnedPNG()",
          "\U0001F4E5 Export All as PNG"
        ),
        htmltools::tags$button(
          class = "kd-pinned-panel-btn",
          onclick = "kdPrintPinnedViews()",
          "\U0001F5B6 Print / PDF"
        ),
        htmltools::tags$button(
          class = "kd-pinned-panel-btn",
          onclick = "kdClearAllPinned()",
          "\U0001F5D1 Clear All"
        )
      )
    ),
    htmltools::tags$div(
      id = "kd-pinned-empty", class = "kd-pinned-empty",
      htmltools::tags$div(class = "kd-pinned-empty-icon", "\U0001F4CC"),
      htmltools::tags$div("No pinned views yet.")
    ),
    htmltools::tags$div(
      id = "kd-qual-slides-container", class = "kd-qual-slides-container",
      config_slides
    ),
    htmltools::tags$div(id = "kd-pinned-cards-container")
  )
}


# ==============================================================================
# FOOTER
# ==============================================================================

#' Build Footer
#'
#' Footer with Turas branding and generation timestamp.
#'
#' @param config Configuration list (optional, for company/client name)
#' @return htmltools tag
#' @keywords internal
build_kd_footer <- function(config = list()) {
  company_name <- config$company_name %||% "The Research LampPost (Pty) Ltd"
  client_name  <- config$client_name %||% NULL

  prepared <- company_name
  if (!is.null(client_name) && nzchar(client_name)) {
    prepared <- sprintf("%s | Prepared for %s", prepared, client_name)
  }

  htmltools::tags$div(
    class = "kd-footer",
    sprintf("Generated by TURAS Key Driver Module v1.0 | %s",
            format(Sys.time(), "%d %B %Y %H:%M")),
    htmltools::tags$br(),
    prepared
  )
}


# ==============================================================================
