# ==============================================================================
# CATDRIVER HTML REPORT - PAGE BUILDER
# ==============================================================================
# Assembles all components into a self-contained HTML page.
# All IDs and classes use cd- prefix for Report Hub namespace safety.
# Design: muted palette, clean typography, authoritative tone.
# ==============================================================================

#' Build Complete Catdriver HTML Page
#'
#' Assembles all report components into a single browsable HTML page.
#'
#' @param html_data Transformed data from transform_catdriver_for_html()
#' @param tables Named list of htmltools table objects
#' @param charts Named list of htmltools SVG chart objects
#' @param config Configuration list
#' @return htmltools::browsable tagList
#' @keywords internal
build_cd_html_page <- function(html_data, tables, charts, config) {

  brand_colour <- config$brand_colour %||% "#2563EB"
  accent_colour <- config$accent_colour %||% "#10B981"
  report_title <- config$report_title %||% html_data$analysis_name

  # Build CSS
  css <- build_cd_css(brand_colour, accent_colour)

  # Build sections
  header_section <- build_cd_header(html_data, brand_colour, report_title)
  exec_summary_section <- build_cd_exec_summary(html_data, brand_colour)
  importance_section <- build_cd_importance_section(tables, charts, brand_colour)
  patterns_section <- build_cd_patterns_section(html_data, tables)
  or_section <- build_cd_or_section(tables, charts, html_data$has_bootstrap)
  diagnostics_section <- build_cd_diagnostics_section(tables, html_data)
  interpretation_section <- build_cd_interpretation_section()
  footer_section <- build_cd_footer()

  # Navigation sidebar
  nav <- build_cd_nav()

  # JS
  js_path <- file.path(.cd_html_report_dir, "js", "cd_navigation.js")
  js_content <- if (file.exists(js_path)) {
    paste(readLines(js_path, warn = FALSE), collapse = "\n")
  } else {
    "/* cd_navigation.js not found */"
  }

  # Report Hub metadata
  hub_meta <- htmltools::tagList(
    htmltools::tags$meta(name = "turas-report-type", content = "catdriver"),
    htmltools::tags$meta(name = "turas-module-version", content = "1.1")
  )

  # Assemble page
  page <- htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "utf-8"),
      htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      htmltools::tags$title(report_title),
      hub_meta,
      htmltools::tags$style(htmltools::HTML(css))
    ),
    htmltools::tags$body(
      class = "cd-body",
      htmltools::tags$div(
        class = "cd-layout",
        nav,
        htmltools::tags$main(
          class = "cd-main",
          header_section,
          exec_summary_section,
          importance_section,
          patterns_section,
          or_section,
          diagnostics_section,
          interpretation_section,
          footer_section
        )
      ),
      htmltools::tags$script(htmltools::HTML(js_content))
    )
  )

  htmltools::browsable(page)
}


#' Build Catdriver CSS
#' @keywords internal
build_cd_css <- function(brand_colour, accent_colour) {
  sprintf('
/* ==== CATDRIVER REPORT CSS ==== */
/* cd- namespace for Report Hub safety */

:root {
  --cd-brand: %s;
  --cd-accent: %s;
  --cd-text: #1e293b;
  --cd-text-muted: #64748b;
  --cd-bg: #f8fafc;
  --cd-card: #ffffff;
  --cd-border: #e2e8f0;
  --cd-success: #10B981;
  --cd-warning: #F59E0B;
  --cd-danger: #EF4444;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

.cd-body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background: var(--cd-bg);
  color: var(--cd-text);
  line-height: 1.6;
  font-size: 14px;
}

.cd-layout {
  display: flex;
  min-height: 100vh;
}

/* Navigation */
.cd-nav {
  position: fixed;
  top: 0;
  left: 0;
  width: 220px;
  height: 100vh;
  background: var(--cd-card);
  border-right: 1px solid var(--cd-border);
  padding: 20px 0;
  overflow-y: auto;
  z-index: 100;
}

.cd-nav-title {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--cd-text-muted);
  padding: 0 16px 12px;
}

.cd-nav a {
  display: block;
  padding: 8px 16px;
  color: var(--cd-text-muted);
  text-decoration: none;
  font-size: 13px;
  font-weight: 400;
  border-left: 3px solid transparent;
  transition: color 0.15s, border-color 0.15s;
}

.cd-nav a:hover,
.cd-nav a.active {
  color: var(--cd-brand);
  border-left-color: var(--cd-brand);
  background: rgba(37, 99, 235, 0.04);
}

/* Main content */
.cd-main {
  margin-left: 220px;
  flex: 1;
  padding: 32px 40px;
  max-width: 1100px;
}

/* Sections */
.cd-section {
  background: var(--cd-card);
  border: 1px solid var(--cd-border);
  border-radius: 8px;
  padding: 28px 32px;
  margin-bottom: 24px;
}

.cd-section-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--cd-text);
  margin-bottom: 16px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--cd-brand);
}

/* Header */
.cd-header {
  background: var(--cd-brand);
  color: white;
  border-radius: 8px;
  padding: 32px;
  margin-bottom: 24px;
}

.cd-header h1 {
  font-size: 24px;
  font-weight: 700;
  margin-bottom: 8px;
}

.cd-header-meta {
  display: flex;
  gap: 24px;
  flex-wrap: wrap;
  font-size: 13px;
  opacity: 0.9;
  margin-top: 12px;
}

.cd-header-meta span {
  display: flex;
  align-items: center;
  gap: 4px;
}

.cd-model-badge {
  display: inline-block;
  background: rgba(255,255,255,0.2);
  padding: 2px 10px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 500;
}

/* Status badge */
.cd-status-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.cd-status-pass { background: #D1FAE5; color: #065F46; }
.cd-status-partial { background: #FEF3C7; color: #92400E; }
.cd-status-refused { background: #FEE2E2; color: #991B1B; }

/* Tables */
.cd-table {
  width: 100%%;
  border-collapse: collapse;
  font-size: 13px;
}

.cd-th {
  background: #f1f5f9;
  color: var(--cd-text-muted);
  font-weight: 600;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  padding: 10px 12px;
  text-align: left;
  border-bottom: 2px solid var(--cd-border);
}

.cd-th-num, .cd-th-sig, .cd-th-effect, .cd-th-status { text-align: center; }
.cd-th-bar { text-align: left; min-width: 150px; }
.cd-th-rank { text-align: center; width: 50px; }

.cd-td {
  padding: 8px 12px;
  border-bottom: 1px solid #f1f5f9;
  vertical-align: middle;
}

.cd-td-num { text-align: center; font-variant-numeric: tabular-nums; }
.cd-td-rank { text-align: center; font-weight: 600; color: var(--cd-brand); }
.cd-td-sig { text-align: center; }
.cd-td-effect { text-align: center; }
.cd-td-status { text-align: center; }
.cd-td-interp { font-size: 12px; color: var(--cd-text-muted); }

.cd-tr:hover { background: #f8fafc; }
.cd-tr-reference { background: #f0fdf4; }
.cd-tr-reference:hover { background: #ecfdf5; }

/* Bar container for importance */
.cd-bar-container {
  height: 16px;
  background: #f1f5f9;
  border-radius: 8px;
  overflow: hidden;
}

.cd-bar-fill {
  height: 100%%;
  border-radius: 8px;
  transition: width 0.3s ease;
}

/* Significance classes */
.cd-sig-strong { color: #065F46; font-weight: 600; }
.cd-sig-moderate { color: #92400E; font-weight: 500; }
.cd-sig-none { color: #94a3b8; }

/* Effect colour classes */
.cd-effect-pos { background: #D1FAE5; color: #065F46; border-radius: 4px; }
.cd-effect-neg { background: #FEE2E2; color: #991B1B; border-radius: 4px; }
.cd-effect-mod { background: #FEF3C7; color: #92400E; border-radius: 4px; }

/* Status badges in diagnostics */
.cd-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
}

.cd-badge-pass { background: #D1FAE5; color: #065F46; }
.cd-badge-warn { background: #FEF3C7; color: #92400E; }
.cd-badge-fail { background: #FEE2E2; color: #991B1B; }

/* Executive summary callout cards */
.cd-callout {
  background: #f0f9ff;
  border-left: 4px solid var(--cd-brand);
  padding: 16px 20px;
  border-radius: 0 6px 6px 0;
  margin-bottom: 12px;
}

.cd-callout-title {
  font-weight: 600;
  font-size: 14px;
  margin-bottom: 4px;
}

.cd-callout-text {
  font-size: 13px;
  color: var(--cd-text-muted);
}

.cd-model-confidence {
  padding: 12px 16px;
  border-radius: 6px;
  margin-bottom: 16px;
  font-size: 13px;
}

.cd-confidence-excellent { background: #D1FAE5; border-left: 4px solid #10B981; }
.cd-confidence-good { background: #DBEAFE; border-left: 4px solid #2563EB; }
.cd-confidence-moderate { background: #FEF3C7; border-left: 4px solid #F59E0B; }
.cd-confidence-limited { background: #FEE2E2; border-left: 4px solid #EF4444; }

/* Charts */
.cd-chart { width: 100%%; max-width: 700px; height: auto; margin: 16px 0; }

/* Factor picker */
.cd-factor-tabs {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 16px;
}

.cd-factor-tab {
  padding: 6px 14px;
  border: 1px solid var(--cd-border);
  border-radius: 20px;
  font-size: 12px;
  font-weight: 500;
  color: var(--cd-text-muted);
  cursor: pointer;
  background: white;
  transition: all 0.15s;
}

.cd-factor-tab:hover { border-color: var(--cd-brand); color: var(--cd-brand); }
.cd-factor-tab.active { background: var(--cd-brand); color: white; border-color: var(--cd-brand); }

.cd-factor-panel { display: none; }
.cd-factor-panel.active { display: block; }

/* Footer */
.cd-footer {
  text-align: center;
  padding: 24px;
  color: var(--cd-text-muted);
  font-size: 11px;
  border-top: 1px solid var(--cd-border);
  margin-top: 32px;
}

/* Print styles */
@media print {
  .cd-nav { display: none; }
  .cd-main { margin-left: 0; padding: 16px; }
  .cd-section { break-inside: avoid; page-break-inside: avoid; }
  .cd-header { background: var(--cd-brand) !important; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .cd-factor-tabs { display: none; }
  .cd-factor-panel { display: block !important; margin-bottom: 16px; }
}
', brand_colour, accent_colour)
}


#' Build Navigation Sidebar
#' @keywords internal
build_cd_nav <- function() {
  htmltools::tags$nav(
    class = "cd-nav",
    id = "cd-nav",
    htmltools::tags$div(class = "cd-nav-title", "REPORT SECTIONS"),
    htmltools::tags$a(href = "#cd-header", "Overview", class = "active"),
    htmltools::tags$a(href = "#cd-exec-summary", "Executive Summary"),
    htmltools::tags$a(href = "#cd-importance", "Driver Importance"),
    htmltools::tags$a(href = "#cd-patterns", "Factor Patterns"),
    htmltools::tags$a(href = "#cd-odds-ratios", "Odds Ratios"),
    htmltools::tags$a(href = "#cd-diagnostics", "Diagnostics"),
    htmltools::tags$a(href = "#cd-interpretation", "Interpretation Guide")
  )
}


#' Build Header Section
#' @keywords internal
build_cd_header <- function(html_data, brand_colour, report_title) {

  model_info <- html_data$model_info
  diag <- html_data$diagnostics

  model_label <- switch(model_info$outcome_type,
    binary = "Binary Logistic",
    ordinal = "Ordinal Logistic",
    nominal = "Multinomial Logistic",
    model_info$outcome_type
  )

  status_class <- switch(html_data$run_status,
    "PASS" = "cd-status-pass",
    "PARTIAL" = "cd-status-partial",
    "cd-status-refused"
  )

  weight_text <- if (!is.null(model_info$weight_var) && nzchar(model_info$weight_var %||% "")) {
    sprintf("Weighted (%s)", model_info$weight_var)
  } else {
    "Unweighted"
  }

  htmltools::tags$div(
    class = "cd-header",
    id = "cd-header",
    htmltools::tags$h1(report_title),
    htmltools::tags$div(
      sprintf("Outcome: %s (%d categories)", model_info$outcome_label, model_info$n_categories)
    ),
    htmltools::tags$div(
      class = "cd-header-meta",
      htmltools::tags$span(htmltools::tags$span(class = "cd-model-badge", model_label)),
      htmltools::tags$span(sprintf("n = %d", diag$complete_n)),
      htmltools::tags$span(sprintf("%d drivers", model_info$n_drivers)),
      htmltools::tags$span(weight_text),
      htmltools::tags$span(htmltools::tags$span(class = paste("cd-status-badge", status_class),
                                                 html_data$run_status)),
      htmltools::tags$span(format(Sys.time(), "%d %B %Y"))
    )
  )
}


#' Build Executive Summary Section
#' @keywords internal
build_cd_exec_summary <- function(html_data, brand_colour) {

  fit <- html_data$model_info$fit_statistics

  # Model confidence callout
  confidence_html <- NULL
  if (!is.null(fit) && !is.na(fit$mcfadden_r2)) {
    r2 <- fit$mcfadden_r2
    r2_pct <- round(r2 * 100, 1)

    if (r2 >= 0.4) {
      conf_class <- "cd-confidence-excellent"
      conf_text <- sprintf("Excellent model fit (R2 = %.3f). The %d measured factors explain %.1f%% of variation.",
                           r2, html_data$model_info$n_drivers, r2_pct)
    } else if (r2 >= 0.2) {
      conf_class <- "cd-confidence-good"
      conf_text <- sprintf("Good model fit (R2 = %.3f). The %d measured factors explain %.1f%% of variation.",
                           r2, html_data$model_info$n_drivers, r2_pct)
    } else if (r2 >= 0.1) {
      conf_class <- "cd-confidence-moderate"
      conf_text <- sprintf("Moderate model fit (R2 = %.3f). The %d measured factors explain %.1f%% of variation. Other unmeasured factors may also play a role.",
                           r2, html_data$model_info$n_drivers, r2_pct)
    } else {
      conf_class <- "cd-confidence-limited"
      conf_text <- sprintf("Limited model fit (R2 = %.3f). The %d measured factors explain only %.1f%% of variation. Key unmeasured factors likely influence the outcome.",
                           r2, html_data$model_info$n_drivers, r2_pct)
    }

    confidence_html <- htmltools::tags$div(
      class = paste("cd-model-confidence", conf_class),
      htmltools::tags$strong("Model Confidence: "),
      conf_text
    )
  }

  # Top 3 driver callout cards
  top_n <- min(3, length(html_data$importance))
  driver_cards <- lapply(html_data$importance[1:top_n], function(d) {
    htmltools::tags$div(
      class = "cd-callout",
      htmltools::tags$div(class = "cd-callout-title",
                          sprintf("#%d %s", d$rank, d$label)),
      htmltools::tags$div(class = "cd-callout-text",
                          sprintf("%.1f%% of explained variation | %s %s",
                                  d$importance_pct, d$p_formatted, d$significance))
    )
  })

  htmltools::tags$div(
    class = "cd-section",
    id = "cd-exec-summary",
    htmltools::tags$h2(class = "cd-section-title", "Executive Summary"),
    confidence_html,
    driver_cards,
    # Degraded warnings
    if (html_data$degraded && length(html_data$degraded_reasons) > 0) {
      htmltools::tags$div(
        class = "cd-model-confidence cd-confidence-limited",
        htmltools::tags$strong("Degraded Output: "),
        paste(html_data$degraded_reasons, collapse = "; ")
      )
    }
  )
}


#' Build Importance Section
#' @keywords internal
build_cd_importance_section <- function(tables, charts, brand_colour) {
  htmltools::tags$div(
    class = "cd-section",
    id = "cd-importance",
    htmltools::tags$h2(class = "cd-section-title", "Driver Importance"),
    htmltools::tags$p(
      style = "color:var(--cd-text-muted);margin-bottom:16px;font-size:13px;",
      "Relative importance of each driver in explaining the outcome, based on chi-square contribution. Higher percentage means stronger statistical relationship."
    ),
    if (!is.null(charts$importance)) charts$importance,
    tables$importance
  )
}


#' Build Patterns Section with Factor Picker
#' @keywords internal
build_cd_patterns_section <- function(html_data, tables) {

  pattern_names <- names(html_data$patterns)
  if (length(pattern_names) == 0) return(NULL)

  # Factor picker tabs
  tabs <- lapply(seq_along(pattern_names), function(i) {
    var_name <- pattern_names[i]
    label <- html_data$patterns[[var_name]]$label
    active_class <- if (i == 1) " active" else ""
    safe_id <- gsub("[^a-zA-Z0-9_]", "-", var_name)

    htmltools::tags$button(
      class = paste0("cd-factor-tab", active_class),
      onclick = sprintf("cdShowFactor('%s')", safe_id),
      `data-factor` = safe_id,
      label
    )
  })

  # Factor panels
  panels <- lapply(seq_along(pattern_names), function(i) {
    var_name <- pattern_names[i]
    safe_id <- gsub("[^a-zA-Z0-9_]", "-", var_name)
    active_class <- if (i == 1) " active" else ""
    label <- html_data$patterns[[var_name]]$label
    ref <- html_data$patterns[[var_name]]$reference

    htmltools::tags$div(
      class = paste0("cd-factor-panel", active_class),
      id = paste0("cd-panel-", safe_id),
      htmltools::tags$h3(
        style = "font-size:15px;font-weight:600;margin-bottom:8px;",
        sprintf("%s (reference: %s)", label, ref)
      ),
      tables$patterns[[var_name]]
    )
  })

  htmltools::tags$div(
    class = "cd-section",
    id = "cd-patterns",
    htmltools::tags$h2(class = "cd-section-title", "Factor Patterns"),
    htmltools::tags$p(
      style = "color:var(--cd-text-muted);margin-bottom:16px;font-size:13px;",
      "Category-level breakdown showing how each level of a driver relates to the outcome. Odds ratios > 1.0 indicate higher likelihood compared to the reference category."
    ),
    htmltools::tags$div(class = "cd-factor-tabs", tabs),
    panels
  )
}


#' Build Odds Ratios Section
#' @keywords internal
build_cd_or_section <- function(tables, charts, has_bootstrap) {
  bootstrap_note <- if (has_bootstrap) {
    htmltools::tags$p(
      style = "color:var(--cd-text-muted);font-size:12px;margin-top:8px;",
      "Bootstrap columns show resampled estimates. Sign stability indicates the percentage of bootstrap samples where the OR remained on the same side of 1.0."
    )
  }

  htmltools::tags$div(
    class = "cd-section",
    id = "cd-odds-ratios",
    htmltools::tags$h2(class = "cd-section-title", "Odds Ratios"),
    htmltools::tags$p(
      style = "color:var(--cd-text-muted);margin-bottom:16px;font-size:13px;",
      "Detailed coefficient table showing the odds ratio for each factor level compared to its reference category. OR > 1 means higher likelihood; OR < 1 means lower likelihood."
    ),
    if (!is.null(charts$forest)) charts$forest,
    tables$odds_ratios,
    bootstrap_note
  )
}


#' Build Diagnostics Section
#' @keywords internal
build_cd_diagnostics_section <- function(tables, html_data) {

  # Warning list
  warnings_html <- NULL
  if (length(html_data$diagnostics$warnings) > 0) {
    warning_items <- lapply(html_data$diagnostics$warnings, function(w) {
      htmltools::tags$li(style = "color:var(--cd-text-muted);font-size:13px;", w)
    })
    warnings_html <- htmltools::tags$div(
      style = "margin-top:16px;",
      htmltools::tags$h3(style = "font-size:14px;font-weight:600;margin-bottom:8px;", "Warnings"),
      htmltools::tags$ul(style = "padding-left:20px;", warning_items)
    )
  }

  # Model fit stats
  fit <- html_data$model_info$fit_statistics
  fit_items <- list()
  if (!is.null(fit)) {
    if (!is.na(fit$mcfadden_r2)) {
      fit_items <- c(fit_items, list(sprintf("McFadden R2: %.3f", fit$mcfadden_r2)))
    }
    if (!is.na(fit$aic)) {
      fit_items <- c(fit_items, list(sprintf("AIC: %.1f", fit$aic)))
    }
    if (!is.na(fit$lr_statistic)) {
      fit_items <- c(fit_items, list(
        sprintf("LR test: chi2(%d) = %.1f, p %s",
                fit$lr_df, fit$lr_statistic, format_pvalue(fit$lr_pvalue))
      ))
    }
  }

  fit_html <- if (length(fit_items) > 0) {
    htmltools::tags$div(
      style = "margin-top:16px;",
      htmltools::tags$h3(style = "font-size:14px;font-weight:600;margin-bottom:8px;", "Model Fit Statistics"),
      htmltools::tags$div(
        style = "display:flex;gap:24px;flex-wrap:wrap;",
        lapply(fit_items, function(item) {
          htmltools::tags$span(style = "font-size:13px;color:var(--cd-text-muted);", item)
        })
      )
    )
  }

  htmltools::tags$div(
    class = "cd-section",
    id = "cd-diagnostics",
    htmltools::tags$h2(class = "cd-section-title", "Model Diagnostics"),
    tables$diagnostics,
    fit_html,
    warnings_html
  )
}


#' Build Interpretation Guide Section
#' @keywords internal
build_cd_interpretation_section <- function() {
  htmltools::tags$div(
    class = "cd-section",
    id = "cd-interpretation",
    htmltools::tags$h2(class = "cd-section-title", "How to Interpret These Results"),
    htmltools::tags$div(
      style = "display:grid;grid-template-columns:1fr 1fr;gap:20px;",
      htmltools::tags$div(
        htmltools::tags$h3(style = "font-size:14px;font-weight:600;color:var(--cd-success);margin-bottom:8px;", "DO"),
        htmltools::tags$ul(
          style = "font-size:13px;color:var(--cd-text-muted);padding-left:16px;",
          htmltools::tags$li("Focus on large effects (OR > 2.0 or < 0.5) that are practically meaningful"),
          htmltools::tags$li("Consider the ranking of drivers rather than exact OR values"),
          htmltools::tags$li("Validate key findings with qualitative research or experiments"),
          htmltools::tags$li("Report uncertainty ranges when presenting to stakeholders")
        )
      ),
      htmltools::tags$div(
        htmltools::tags$h3(style = "font-size:14px;font-weight:600;color:var(--cd-danger);margin-bottom:8px;", "DON'T"),
        htmltools::tags$ul(
          style = "font-size:13px;color:var(--cd-text-muted);padding-left:16px;",
          htmltools::tags$li("Treat odds ratios as precise population parameters"),
          htmltools::tags$li("Make causal claims without experimental evidence"),
          htmltools::tags$li("Over-interpret small differences (OR 1.1 vs 1.2)"),
          htmltools::tags$li("Ignore multicollinearity or convergence warnings")
        )
      )
    ),
    htmltools::tags$div(
      style = "margin-top:16px;padding:12px 16px;background:#f0f9ff;border-radius:6px;border-left:4px solid var(--cd-brand);font-size:12px;color:var(--cd-text-muted);",
      htmltools::tags$strong("Note: "),
      "Odds ratios show association, not causation. With non-probability samples, p-values and confidence intervals should be treated as approximate indicators rather than strict inferential bounds."
    )
  )
}


#' Build Footer
#' @keywords internal
build_cd_footer <- function() {
  htmltools::tags$div(
    class = "cd-footer",
    sprintf("Generated by TURAS Categorical Key Driver Module v1.1 | %s",
            format(Sys.time(), "%d %B %Y %H:%M")),
    htmltools::tags$br(),
    "The Research LampPost (Pty) Ltd"
  )
}
