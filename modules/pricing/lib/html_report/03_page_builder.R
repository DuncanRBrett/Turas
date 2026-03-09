# ==============================================================================
# TURAS PRICING MODULE - HTML REPORT PAGE BUILDER (Layer 4)
# ==============================================================================
#
# Purpose: Assemble complete self-contained HTML document from transformed
#          data, tables, and charts.
# Pattern: Follows confidence module 4-layer architecture
# Version: 1.0.0
# ==============================================================================

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

#' Build Complete Pricing HTML Report Page
#'
#' @param html_data Transformed data from data transformer
#' @param tables List of HTML table strings from table builder
#' @param charts List of SVG chart strings from chart builder
#' @param config Configuration list
#' @return Complete HTML document as character string
#' @keywords internal
build_pricing_page <- function(html_data, tables, charts, config) {

  brand <- config$brand_colour %||% "#1e3a5f"
  if (is.na(brand) || !nzchar(trimws(brand))) brand <- "#1e3a5f"
  accent <- "#2aa198"
  currency <- config$currency_symbol %||% "$"
  project_name <- config$project_name %||% "Pricing Analysis"
  method <- html_data$meta$method

  # Determine which tabs to show
  tabs <- list()
  tabs[["summary"]] <- "Summary"
  if (!is.null(html_data$van_westendorp)) tabs[["vw"]] <- "Van Westendorp"
  if (!is.null(html_data$gabor_granger)) tabs[["gg"]] <- "Gabor-Granger"
  if (!is.null(html_data$monadic)) tabs[["monadic"]] <- "Monadic"
  if (!is.null(html_data$segments)) tabs[["segments"]] <- "Segments"
  if (!is.null(html_data$recommendation)) tabs[["recommendation"]] <- "Recommendation"

  # Build page sections
  meta_tags <- build_pricing_meta_tags(html_data, config)
  css <- build_pricing_css(brand, accent)
  header <- build_pricing_header(project_name, html_data$meta, brand)
  tab_nav <- build_pricing_tab_nav(tabs)

  # Build content panels
  panels <- character(0)
  panels <- c(panels, build_summary_panel(html_data, tables, charts))

  if (!is.null(html_data$van_westendorp)) {
    panels <- c(panels, build_vw_panel(html_data$van_westendorp, tables, charts))
  }
  if (!is.null(html_data$gabor_granger)) {
    panels <- c(panels, build_gg_panel(html_data$gabor_granger, tables, charts, currency))
  }
  if (!is.null(html_data$monadic)) {
    panels <- c(panels, build_monadic_panel(html_data$monadic, tables, charts, currency))
  }
  if (!is.null(html_data$segments)) {
    panels <- c(panels, build_segments_panel(html_data$segments, tables, charts))
  }
  if (!is.null(html_data$recommendation)) {
    panels <- c(panels, build_recommendation_panel(html_data$recommendation, tables))
  }

  footer <- build_pricing_footer()
  js <- build_pricing_js()

  # Assemble complete HTML
  sprintf(
    '<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  %s
  <title>%s - Pricing Report</title>
  <style>%s</style>
</head>
<body>
  %s
  <div class="pr-container">
    %s
    <div class="pr-content">
      %s
    </div>
  </div>
  %s
  <script>%s</script>
</body>
</html>',
    meta_tags,
    htmlEscape(project_name),
    css,
    header,
    tab_nav,
    paste(panels, collapse = "\n"),
    footer,
    js
  )
}

htmlEscape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}


# ==============================================================================
# META TAGS
# ==============================================================================

build_pricing_meta_tags <- function(html_data, config) {
  method <- html_data$meta$method
  rec_price <- ""
  conf <- ""
  if (!is.null(html_data$recommendation)) {
    rec <- html_data$recommendation$recommendation
    rec_price <- sprintf("%.2f", rec$price)
    conf <- rec$confidence %||% ""
  }

  tags <- c(
    '<meta name="turas-report-type" content="pricing">',
    sprintf('<meta name="turas-generated" content="%s">', html_data$meta$generated),
    sprintf('<meta name="turas-total-n" content="%d">', html_data$meta$n_valid),
    sprintf('<meta name="turas-analysis-method" content="%s">', method),
    sprintf('<meta name="turas-optimal-price" content="%s">', rec_price),
    sprintf('<meta name="turas-confidence" content="%s">', conf),
    sprintf('<meta name="turas-source-filename" content="%s">',
            htmlEscape(config$project_name %||% "Pricing_Report"))
  )
  paste(tags, collapse = "\n  ")
}


# ==============================================================================
# CSS
# ==============================================================================

build_pricing_css <- function(brand, accent) {
  # Use token replacement to avoid sprintf 8192 char limit
  css <- '
:root {
  --pr-brand: BRAND_TOKEN;
  --pr-accent: ACCENT_TOKEN;
  --pr-text-primary: #1e293b;
  --pr-text-secondary: #64748b;
  --pr-bg-surface: #ffffff;
  --pr-bg-muted: #f8f9fa;
  --pr-border: #e2e8f0;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  font-size: 14px;
  line-height: 1.6;
  color: var(--pr-text-primary);
  background: var(--pr-bg-muted);
}

.pr-header {
  background: var(--pr-brand);
  color: white;
  padding: 24px 32px;
}
.pr-header h1 { font-size: 22px; font-weight: 600; margin-bottom: 4px; }
.pr-header .pr-meta { font-size: 12px; opacity: 0.8; }
.pr-header .pr-meta span { margin-right: 16px; }

.pr-container { max-width: 900px; margin: 0 auto; padding: 0 16px; }

.pr-tab-nav {
  display: flex;
  gap: 0;
  background: white;
  border-bottom: 2px solid var(--pr-border);
  overflow-x: auto;
  margin-top: 16px;
  border-radius: 8px 8px 0 0;
}
.pr-tab-btn {
  padding: 10px 18px;
  border: none;
  background: none;
  font-size: 13px;
  font-weight: 500;
  color: var(--pr-text-secondary);
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-bottom: -2px;
  white-space: nowrap;
  transition: color 0.15s, border-color 0.15s;
}
.pr-tab-btn:hover { color: var(--pr-brand); }
.pr-tab-btn.active {
  color: var(--pr-brand);
  border-bottom-color: var(--pr-brand);
  font-weight: 600;
}

.pr-content { background: white; border-radius: 0 0 8px 8px; padding: 24px 28px; margin-bottom: 24px; }

.pr-panel { display: none; }
.pr-panel.active { display: block; }

.pr-section { margin-bottom: 28px; }
.pr-section h2 { font-size: 17px; font-weight: 600; color: var(--pr-brand); margin-bottom: 12px; border-bottom: 1px solid var(--pr-border); padding-bottom: 6px; }
.pr-section h3 { font-size: 14px; font-weight: 600; color: var(--pr-text-primary); margin: 16px 0 8px; }

/* Callout boxes */
.pr-callout-result {
  background: #eff6ff;
  border-left: 4px solid var(--pr-brand);
  padding: 12px 16px;
  margin: 10px 0;
  border-radius: 0 6px 6px 0;
  font-size: 13px;
  line-height: 1.5;
}
.pr-callout-method {
  background: #f8f9fa;
  border-left: 4px solid #94a3b8;
  padding: 12px 16px;
  margin: 10px 0;
  border-radius: 0 6px 6px 0;
  font-size: 13px;
  line-height: 1.5;
  color: var(--pr-text-secondary);
}
.pr-callout-sampling {
  background: #fefce8;
  border-left: 4px solid #f59e0b;
  padding: 12px 16px;
  margin: 10px 0;
  border-radius: 0 6px 6px 0;
  font-size: 13px;
  line-height: 1.5;
}

/* Tables */
.pr-table {
  width: 100%;
  border-collapse: collapse;
  margin: 12px 0;
  font-size: 13px;
}
.pr-table-compact { font-size: 12px; }
.pr-th {
  background: var(--pr-bg-muted);
  padding: 8px 12px;
  text-align: left;
  font-weight: 600;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--pr-text-secondary);
  border-bottom: 2px solid var(--pr-border);
}
.pr-th.pr-num { text-align: right; }
.pr-th.pr-label-col { text-align: left; }
.pr-td {
  padding: 7px 12px;
  border-bottom: 1px solid var(--pr-border);
}
.pr-td.pr-num { text-align: right; font-variant-numeric: tabular-nums; }
.pr-td.pr-label-col { font-weight: 500; }
.pr-tr-section td { background: var(--pr-bg-muted); font-weight: 600; padding-top: 10px; }

/* Badges */
.pr-badge-good { background: #dcfce7; color: #166534; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
.pr-badge-warn { background: #fef3c7; color: #92400e; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
.pr-badge-poor { background: #fee2e2; color: #991b1b; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
.pr-badge-elastic { background: #fee2e2; color: #991b1b; padding: 2px 8px; border-radius: 10px; font-size: 11px; }
.pr-badge-inelastic { background: #dcfce7; color: #166534; padding: 2px 8px; border-radius: 10px; font-size: 11px; }
.pr-badge-unitary { background: #fef3c7; color: #92400e; padding: 2px 8px; border-radius: 10px; font-size: 11px; }

/* Chart container */
.pr-chart-container { margin: 16px 0; padding: 12px; background: var(--pr-bg-muted); border-radius: 8px; }
.pr-chart-title { font-size: 13px; font-weight: 600; color: var(--pr-text-secondary); margin-bottom: 8px; text-align: center; }

/* Key metric cards */
.pr-metrics { display: flex; gap: 12px; flex-wrap: wrap; margin: 16px 0; }
.pr-metric-card {
  flex: 1;
  min-width: 140px;
  background: var(--pr-bg-muted);
  border-radius: 8px;
  padding: 14px 16px;
  text-align: center;
}
.pr-metric-value { font-size: 20px; font-weight: 700; color: var(--pr-brand); }
.pr-metric-label { font-size: 11px; color: var(--pr-text-secondary); margin-top: 2px; }

/* Footer */
.pr-footer {
  text-align: center;
  padding: 16px;
  font-size: 11px;
  color: var(--pr-text-secondary);
  margin-bottom: 32px;
}

/* Print styles */
@media print {
  .pr-tab-nav { display: none; }
  .pr-panel { display: block !important; page-break-inside: avoid; }
  .pr-header { background: white !important; color: var(--pr-brand) !important; border-bottom: 2px solid var(--pr-brand); }
  body { background: white; }
}

/* Responsive */
@media (max-width: 600px) {
  .pr-content { padding: 16px; }
  .pr-metrics { flex-direction: column; }
  .pr-tab-btn { padding: 8px 12px; font-size: 12px; }
}
'

  css <- gsub("BRAND_TOKEN", brand, css, fixed = TRUE)
  css <- gsub("ACCENT_TOKEN", accent, css, fixed = TRUE)
  css
}


# ==============================================================================
# HEADER
# ==============================================================================

build_pricing_header <- function(project_name, meta, brand) {
  sprintf(
    '<div class="pr-header">
       <h1>%s</h1>
       <div class="pr-meta">
         <span>%s</span>
         <span>n = %s</span>
         <span>Generated: %s</span>
       </div>
     </div>',
    htmlEscape(project_name),
    htmlEscape(meta$method),
    format(meta$n_valid, big.mark = ","),
    meta$generated
  )
}


# ==============================================================================
# TAB NAVIGATION
# ==============================================================================

build_pricing_tab_nav <- function(tabs) {
  buttons <- character(0)
  first <- TRUE
  for (id in names(tabs)) {
    active_class <- if (first) " active" else ""
    buttons <- c(buttons, sprintf(
      '<button class="pr-tab-btn%s" data-tab="%s">%s</button>',
      active_class, id, htmlEscape(tabs[[id]])
    ))
    first <- FALSE
  }

  sprintf('<div class="pr-tab-nav">%s</div>', paste(buttons, collapse = "\n"))
}


# ==============================================================================
# CONTENT PANELS
# ==============================================================================

build_summary_panel <- function(html_data, tables, charts) {
  summary <- html_data$summary
  currency <- html_data$meta$currency

  # Metric cards
  cards <- character(0)
  if (!is.null(summary$recommended_price)) {
    cards <- c(cards, sprintf(
      '<div class="pr-metric-card"><div class="pr-metric-value">%s</div><div class="pr-metric-label">Recommended Price</div></div>',
      summary$recommended_price
    ))
  }
  if (!is.null(summary$confidence_level)) {
    cards <- c(cards, sprintf(
      '<div class="pr-metric-card"><div class="pr-metric-value">%s</div><div class="pr-metric-label">Confidence</div></div>',
      summary$confidence_level
    ))
  }
  cards <- c(cards, sprintf(
    '<div class="pr-metric-card"><div class="pr-metric-value">%s</div><div class="pr-metric-label">Valid Respondents</div></div>',
    format(summary$n_valid, big.mark = ",")
  ))
  cards <- c(cards, sprintf(
    '<div class="pr-metric-card"><div class="pr-metric-value">%s</div><div class="pr-metric-label">Method</div></div>',
    gsub("_", " ", html_data$meta$method)
  ))

  sprintf(
    '<div class="pr-panel active" id="panel-summary">
       <div class="pr-section">
         <h2>Overview</h2>
         <div class="pr-metrics">%s</div>
         %s
       </div>
     </div>',
    paste(cards, collapse = "\n"),
    summary$callout %||% ""
  )
}


build_vw_panel <- function(vw_data, tables, charts) {
  sprintf(
    '<div class="pr-panel" id="panel-vw">
       <div class="pr-section">
         <h2>Van Westendorp Price Sensitivity</h2>
         %s
         <h3>Price Points</h3>
         %s
         %s
         %s
       </div>
     </div>',
    vw_data$callout %||% "",
    tables$vw_price_points %||% "",
    if (!is.null(charts$vw_curves) && nzchar(charts$vw_curves)) {
      sprintf('<div class="pr-chart-container"><div class="pr-chart-title">Price Sensitivity Curves</div>%s</div>', charts$vw_curves)
    } else "",
    if (!is.null(tables$vw_ci) && nzchar(tables$vw_ci)) {
      sprintf('<h3>Confidence Intervals</h3>%s', tables$vw_ci)
    } else ""
  )
}


build_gg_panel <- function(gg_data, tables, charts, currency) {
  sprintf(
    '<div class="pr-panel" id="panel-gg">
       <div class="pr-section">
         <h2>Gabor-Granger Demand Analysis</h2>
         %s
         <h3>Optimal Price</h3>
         %s
         %s
         %s
         %s
       </div>
     </div>',
    gg_data$callout %||% "",
    tables$gg_optimal %||% "",
    if (!is.null(charts$gg_demand) && nzchar(charts$gg_demand)) {
      sprintf('<div class="pr-chart-container"><div class="pr-chart-title">Demand &amp; Revenue Curves</div>%s</div>', charts$gg_demand)
    } else "",
    if (!is.null(tables$gg_elasticity) && nzchar(tables$gg_elasticity)) {
      sprintf('<h3>Price Elasticity</h3>%s', tables$gg_elasticity)
    } else "",
    if (!is.null(charts$gg_elasticity) && nzchar(charts$gg_elasticity)) {
      sprintf('<div class="pr-chart-container"><div class="pr-chart-title">Elasticity by Price</div>%s</div>', charts$gg_elasticity)
    } else ""
  )
}


build_monadic_panel <- function(monadic_data, tables, charts, currency) {
  sprintf(
    '<div class="pr-panel" id="panel-monadic">
       <div class="pr-section">
         <h2>Monadic Price Testing</h2>
         %s
         <h3>Optimal Price</h3>
         %s
         %s
         <h3>Model Summary</h3>
         %s
         <h3>Observed Data</h3>
         %s
         %s
       </div>
     </div>',
    monadic_data$callout %||% "",
    tables$monadic_optimal %||% "",
    if (!is.null(charts$monadic_demand) && nzchar(charts$monadic_demand)) {
      sprintf('<div class="pr-chart-container"><div class="pr-chart-title">Demand Curve (Logistic Model)</div>%s</div>', charts$monadic_demand)
    } else "",
    tables$monadic_model %||% "",
    tables$monadic_observed %||% "",
    if (!is.null(charts$monadic_elasticity) && nzchar(charts$monadic_elasticity)) {
      sprintf('<h3>Price Elasticity</h3><div class="pr-chart-container"><div class="pr-chart-title">Elasticity by Price</div>%s</div>', charts$monadic_elasticity)
    } else ""
  )
}


build_segments_panel <- function(segment_data, tables, charts) {
  sprintf(
    '<div class="pr-panel" id="panel-segments">
       <div class="pr-section">
         <h2>Segment Analysis</h2>
         %s
         %s
         %s
       </div>
     </div>',
    segment_data$callout %||% "",
    tables$segment_comparison %||% "",
    if (!is.null(charts$segment_comparison) && nzchar(charts$segment_comparison)) {
      sprintf('<div class="pr-chart-container"><div class="pr-chart-title">Segment Price Comparison</div>%s</div>', charts$segment_comparison)
    } else ""
  )
}


build_recommendation_panel <- function(rec_data, tables) {
  sprintf(
    '<div class="pr-panel" id="panel-recommendation">
       <div class="pr-section">
         <h2>Recommendation</h2>
         %s
         %s
       </div>
     </div>',
    rec_data$callout %||% "",
    if (!is.null(tables$evidence) && nzchar(tables$evidence)) {
      sprintf('<h3>Supporting Evidence</h3>%s', tables$evidence)
    } else ""
  )
}


# ==============================================================================
# FOOTER
# ==============================================================================

build_pricing_footer <- function() {
  sprintf(
    '<div class="pr-footer">
       Generated by TURAS Analytics Platform &middot; Pricing Research Module &middot; %s
     </div>',
    format(Sys.Date(), "%B %Y")
  )
}


# ==============================================================================
# JAVASCRIPT (Tab Switching)
# ==============================================================================

build_pricing_js <- function() {
  '
  (function() {
    var tabs = document.querySelectorAll(".pr-tab-btn");
    var panels = document.querySelectorAll(".pr-panel");

    tabs.forEach(function(tab) {
      tab.addEventListener("click", function() {
        var target = this.getAttribute("data-tab");

        tabs.forEach(function(t) { t.classList.remove("active"); });
        panels.forEach(function(p) { p.classList.remove("active"); });

        this.classList.add("active");
        var panel = document.getElementById("panel-" + target);
        if (panel) panel.classList.add("active");
      });
    });
  })();
  '
}
