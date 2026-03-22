# ==============================================================================
# TURAS PRICING MODULE - HTML REPORT PAGE BUILDER (Layer 4)
# ==============================================================================
#
# Purpose: Assemble complete self-contained HTML document from transformed
#          data, tables, and charts.
# Pattern: Follows tabs module visual design system
# Version: 2.0.0
# ==============================================================================

# Source the shared design system (TURAS_ROOT-aware)
local({
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) turas_root <- getwd()
  ds_dir <- file.path(turas_root, "modules", "shared", "lib", "design_system")
  if (!dir.exists(ds_dir)) ds_dir <- file.path("modules", "shared", "lib", "design_system")
  if (!exists("turas_base_css", mode = "function") && dir.exists(ds_dir)) {
    source(file.path(ds_dir, "design_tokens.R"), local = FALSE)
    source(file.path(ds_dir, "font_embed.R"), local = FALSE)
    source(file.path(ds_dir, "base_css.R"), local = FALSE)
  }
})

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

# htmlEscape is defined in 99_html_report_main.R (sourced before this file)

#' Build Complete Pricing HTML Report Page
#'
#' @param html_data Transformed data from data transformer
#' @param tables List of HTML table strings from table builder
#' @param charts List of SVG chart strings from chart builder
#' @param config Configuration list
#' @param js_dir Path to directory containing JS files (pricing_navigation.js, etc.)
#' @param simulator_data List with pricing_json and config_json for simulator, or NULL
#' @return Complete HTML document as character string
#' @keywords internal
build_pricing_page <- function(html_data, tables, charts, config,
                                js_dir = NULL, simulator_data = NULL,
                                added_slides = NULL) {

  brand <- config$brand_colour %||% "#1e3a5f"
  if (is.na(brand) || !nzchar(trimws(brand))) brand <- "#1e3a5f"
  accent <- "#2aa198"
  currency <- config$currency_symbol %||% "$"
  project_name <- config$project_name %||% "Pricing Analysis"
  method <- html_data$meta$method
  unit_cost <- as.numeric(config$unit_cost %||% 0)

  has_simulator <- !is.null(simulator_data) &&
                   !is.null(simulator_data$pricing_json) &&
                   nzchar(simulator_data$pricing_json)

  # Determine which tabs to show
  tabs <- list()
  tabs[["summary"]] <- "Summary"
  if (!is.null(html_data$van_westendorp)) tabs[["vw"]] <- "Van Westendorp"
  if (!is.null(html_data$gabor_granger)) tabs[["gg"]] <- "Gabor-Granger"
  if (!is.null(html_data$monadic)) tabs[["monadic"]] <- "Monadic"
  if (!is.null(html_data$segments)) tabs[["segments"]] <- "Segments"
  if (!is.null(html_data$recommendation)) tabs[["recommendation"]] <- "Recommendation"
  if (has_simulator) tabs[["simulator"]] <- "Simulator"
  has_slides <- !is.null(added_slides) && length(added_slides) > 0
  tabs[["slides"]] <- "Added Slides"
  tabs[["pinned"]] <- "Pinned"
  tabs[["about"]] <- "About"

  # Extract insights from config (if available)
  insights <- config$insights %||% list()

  # Build page sections
  meta_tags <- build_pricing_meta_tags(html_data, config)
  css <- build_pricing_css(brand, accent, has_simulator)
  header <- build_pricing_header(project_name, html_data$meta, brand)
  dashboard <- build_dashboard_summary(html_data, config)
  tab_nav <- build_pricing_tab_nav(tabs)

  # Build content panels
  panels <- character(0)
  panels <- c(panels, build_summary_panel(html_data, tables, charts, insights))

  if (!is.null(html_data$van_westendorp)) {
    panels <- c(panels, build_vw_panel(html_data$van_westendorp, tables, charts, insights))
  }
  if (!is.null(html_data$gabor_granger)) {
    panels <- c(panels, build_gg_panel(html_data$gabor_granger, tables, charts, currency, insights))
  }
  if (!is.null(html_data$monadic)) {
    panels <- c(panels, build_monadic_panel(html_data$monadic, tables, charts, currency, insights))
  }
  if (!is.null(html_data$segments)) {
    panels <- c(panels, build_segments_panel(html_data$segments, tables, charts, insights))
  }
  if (!is.null(html_data$recommendation)) {
    panels <- c(panels, build_recommendation_panel(html_data$recommendation, tables, insights))
  }
  if (has_simulator) {
    panels <- c(panels, build_simulator_panel(unit_cost, simulator_data))
  }
  panels <- c(panels, build_added_slides_panel(added_slides))
  panels <- c(panels, build_pinned_views_panel())
  panels <- c(panels, build_about_panel(html_data, config))

  closing <- build_pricing_closing(config)
  js <- build_pricing_js(js_dir)

  # Simulator data script (embedded JSON for the simulator engine)
  sim_data_script <- ""
  if (has_simulator) {
    sim_data_script <- sprintf(
      '<script>\n  var PRICING_DATA = %s;\n  var PRICING_CONFIG = %s;\n</script>',
      simulator_data$pricing_json,
      simulator_data$config_json
    )
  }

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
  <div class="pr-outer">
    %s
    %s
    <div class="pr-content">
      %s
    </div>
  </div>
  %s
  %s
  <script>%s</script>
</body>
</html>',
    meta_tags,
    htmlEscape(project_name),
    css,
    header,
    dashboard,
    tab_nav,
    paste(panels, collapse = "\n"),
    closing,
    sim_data_script,
    js
  )
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
# CSS (Tabs-level visual quality)
# ==============================================================================

build_pricing_css <- function(brand, accent, has_simulator = FALSE) {
  shared_css <- tryCatch(turas_base_css(brand, accent, prefix = "pr"), error = function(e) "")
  css <- '
:root {
  --pr-brand: BRAND_TOKEN;
  --pr-accent: ACCENT_TOKEN;
  --pr-text-primary: #1e293b;
  --pr-text-secondary: #64748b;
  --pr-bg-surface: #ffffff;
  --pr-bg-muted: #f8fafc;
  --pr-border: #e2e8f0;
  /* Simulator aliases */
  --sim-brand: BRAND_TOKEN;
  --sim-accent: ACCENT_TOKEN;
  --sim-text: #1e293b;
  --sim-text-muted: #64748b;
  --sim-bg: #f8fafc;
  --sim-surface: #ffffff;
  --sim-border: #e2e8f0;
  --sim-red: #e74c3c;
  --sim-green: #27ae60;
  --sim-amber: #f39c12;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  font-size: 14px;
  line-height: 1.6;
  color: var(--pr-text-primary);
  background: #f1f5f9;
}

/* ── Header (gradient, matching tabs module) ── */
.pr-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
  border-bottom: 3px solid var(--pr-brand);
  color: white;
  padding: 24px 32px;
}
.pr-header-inner {
  max-width: 1200px;
  margin: 0 auto;
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.pr-header h1 { font-size: 22px; font-weight: 600; margin-bottom: 4px; }
.pr-header .pr-meta { font-size: 12px; opacity: 0.8; }
.pr-header .pr-meta span { margin-right: 16px; }
.pr-header-actions { display: flex; gap: 8px; }
.pr-header .pr-btn-print {
  padding: 6px 14px;
  border: 1px solid rgba(255,255,255,0.3);
  border-radius: 6px;
  background: rgba(255,255,255,0.1);
  color: white;
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.15s;
}
.pr-header .pr-btn-print:hover { background: rgba(255,255,255,0.2); }
.pr-header .pr-btn-save {
  padding: 6px 14px; border: 1px solid rgba(255,255,255,0.3); border-radius: 6px;
  background: rgba(255,255,255,0.15); color: white; font-size: 12px; font-weight: 500;
  cursor: pointer; transition: background 0.15s;
}
.pr-header .pr-btn-save:hover { background: rgba(255,255,255,0.25); }
.pr-save-badge { color: rgba(255,255,255,0.7); font-size: 11px; margin-left: 4px; }

/* ── Outer container ── */
.pr-outer { max-width: 1200px; margin: 0 auto; padding: 0 32px; }

/* ── Dashboard Summary Panel ── */
.pr-dashboard {
  display: flex;
  gap: 14px;
  flex-wrap: wrap;
  margin: 20px 0 0;
}
.pr-gauge-card {
  flex: 1;
  min-width: 170px;
  max-width: 260px;
  background: white;
  border-radius: 8px;
  border: 1px solid var(--pr-border);
  border-left: 4px solid var(--pr-brand);
  padding: 14px 16px;
  text-align: center;
  transition: box-shadow 0.2s;
}
.pr-gauge-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
.pr-gauge-value {
  font-size: 24px;
  font-weight: 700;
  color: var(--pr-brand);
  font-variant-numeric: tabular-nums;
  line-height: 1.2;
}
.pr-gauge-label {
  font-size: 11px;
  color: var(--pr-text-secondary);
  margin-top: 4px;
  line-height: 1.3;
}
.pr-gauge-sub {
  font-size: 10px;
  color: var(--pr-text-secondary);
  margin-top: 2px;
  opacity: 0.8;
}

/* ── Metadata strip ── */
.pr-meta-strip {
  background: #f8fafc;
  border: 1px solid var(--pr-border);
  border-radius: 6px;
  padding: 8px 16px;
  margin: 12px 0 0;
  font-size: 11px;
  color: var(--pr-text-secondary);
  display: flex;
  gap: 20px;
  flex-wrap: wrap;
}
.pr-meta-strip strong { color: var(--pr-text-primary); font-weight: 600; }

/* ── Tab navigation ── */
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

/* ── Content area ── */
.pr-content {
  background: white;
  border-radius: 0 0 8px 8px;
  padding: 28px 32px;
  margin-bottom: 24px;
  border: 1px solid var(--pr-border);
  border-top: none;
}

.pr-panel { display: none; }
.pr-panel.active { display: block; }

/* ── Sections ── */
.pr-section { margin-bottom: 28px; }
.pr-section h2 {
  font-size: 17px;
  font-weight: 600;
  color: var(--pr-text-primary);
  margin-bottom: 14px;
  padding-bottom: 8px;
  padding-left: 12px;
  border-left: 4px solid var(--pr-brand);
  border-bottom: 1px solid var(--pr-border);
}
.pr-section h3 {
  font-size: 14px;
  font-weight: 600;
  color: var(--pr-text-primary);
  margin: 18px 0 8px;
}

/* ── Callout boxes ── */
.pr-callout-result {
  background: #eff6ff;
  border-left: 4px solid var(--pr-brand);
  padding: 14px 18px;
  margin: 12px 0;
  border-radius: 0 8px 8px 0;
  font-size: 13px;
  line-height: 1.6;
}
.pr-callout-method {
  background: #f8fafc;
  border-left: 4px solid #94a3b8;
  padding: 14px 18px;
  margin: 12px 0;
  border-radius: 0 8px 8px 0;
  font-size: 13px;
  line-height: 1.6;
  color: var(--pr-text-secondary);
}
.pr-callout-sampling {
  background: #fffbeb;
  border-left: 4px solid #f59e0b;
  padding: 14px 18px;
  margin: 12px 0;
  border-radius: 0 8px 8px 0;
  font-size: 13px;
  line-height: 1.6;
}

/* ── Tables ── */
.pr-table {
  width: 100%;
  border-collapse: collapse;
  margin: 14px 0;
  font-size: 13px;
}
.pr-table-compact { font-size: 12px; }
.pr-th {
  background: var(--pr-bg-muted);
  padding: 10px 14px;
  text-align: left;
  font-weight: 600;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  color: var(--pr-text-secondary);
  border-bottom: 2px solid var(--pr-border);
}
.pr-th.pr-num { text-align: right; }
.pr-th.pr-label-col { text-align: left; }
.pr-td {
  padding: 8px 14px;
  border-bottom: 1px solid var(--pr-border);
}
.pr-td.pr-num { text-align: right; font-variant-numeric: tabular-nums; }
.pr-td.pr-label-col { font-weight: 500; }
.pr-tr-section td { background: var(--pr-bg-muted); font-weight: 600; padding-top: 12px; }

/* Table hover */
.pr-table tbody tr:hover { background: #f8fafc; }

/* Heatmap cells */
.pr-heat-high { background: #dcfce7; }
.pr-heat-med  { background: #fef3c7; }
.pr-heat-low  { background: #fee2e2; }
.pr-row-optimal { font-weight: 600; border-left: 3px solid var(--pr-brand); }

/* ── Badges ── */
.pr-badge-good { background: #dcfce7; color: #166534; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
.pr-badge-warn { background: #fef3c7; color: #92400e; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
.pr-badge-poor { background: #fee2e2; color: #991b1b; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
.pr-badge-elastic { background: #fee2e2; color: #991b1b; padding: 2px 8px; border-radius: 10px; font-size: 11px; }
.pr-badge-inelastic { background: #dcfce7; color: #166534; padding: 2px 8px; border-radius: 10px; font-size: 11px; }
.pr-badge-unitary { background: #fef3c7; color: #92400e; padding: 2px 8px; border-radius: 10px; font-size: 11px; }

/* ── Chart containers ── */
.pr-chart-container {
  margin: 16px 0;
  padding: 16px;
  background: var(--pr-bg-muted);
  border-radius: 8px;
  border: 1px solid var(--pr-border);
  position: relative;
}
.pr-chart-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--pr-text-secondary);
  margin-bottom: 10px;
  text-align: center;
}
.pr-chart-export {
  position: absolute;
  top: 12px;
  right: 12px;
  padding: 4px 10px;
  border: 1px solid var(--pr-border);
  border-radius: 4px;
  background: white;
  color: var(--pr-text-secondary);
  font-size: 10px;
  cursor: pointer;
  transition: border-color 0.15s;
}
.pr-chart-export:hover { border-color: var(--pr-brand); color: var(--pr-brand); }

/* ── Summary metric cards ── */
.pr-metrics { display: flex; gap: 12px; flex-wrap: wrap; margin: 16px 0; }
.pr-metric-card {
  flex: 1;
  min-width: 140px;
  background: var(--pr-bg-muted);
  border-radius: 8px;
  padding: 14px 16px;
  text-align: center;
  border: 1px solid var(--pr-border);
}
.pr-metric-value { font-size: 20px; font-weight: 700; color: var(--pr-brand); }
.pr-metric-label { font-size: 11px; color: var(--pr-text-secondary); margin-top: 2px; }

/* ── Closing section ── */
.pr-closing {
  max-width: 1200px;
  margin: 0 auto 32px;
  padding: 0 32px;
}
.pr-closing-divider { height: 1px; background: var(--pr-border); margin-bottom: 24px; }
.pr-closing-content {
  background: #f8fafc;
  border-radius: 8px;
  padding: 24px;
  border: 1px solid var(--pr-border);
  text-align: center;
}
.pr-closing-brand {
  font-size: 13px;
  font-weight: 600;
  color: var(--pr-text-primary);
  margin-bottom: 6px;
}
.pr-closing-info {
  font-size: 11px;
  color: var(--pr-text-secondary);
  line-height: 1.5;
}

/* ── SVG tooltip ── */
.pr-tooltip {
  position: fixed;
  pointer-events: none;
  background: #1e293b;
  color: white;
  padding: 6px 10px;
  border-radius: 4px;
  font-size: 11px;
  font-family: -apple-system, BlinkMacSystemFont, sans-serif;
  white-space: nowrap;
  z-index: 1000;
  opacity: 0;
  transition: opacity 0.12s;
  box-shadow: 0 2px 6px rgba(0,0,0,0.2);
}
.pr-tooltip.visible { opacity: 1; }

/* ── Added Slides ── */
.pr-slides-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
}
.pr-slides-hint {
  font-size: 12px;
  color: var(--pr-text-secondary);
  margin-top: 2px;
}
.pr-slides-actions { display: flex; gap: 8px; }
.pr-slides-md-help {
  background: var(--pr-bg-muted);
  border: 1px solid var(--pr-border);
  border-radius: 6px;
  padding: 10px 16px;
  margin-bottom: 16px;
  font-size: 11px;
  color: var(--pr-text-secondary);
  line-height: 1.6;
}
.pr-slides-md-help code {
  background: #e2e8f0;
  padding: 1px 5px;
  border-radius: 3px;
  font-size: 11px;
}
.pr-slide-card {
  background: #fff;
  border: 1px solid var(--pr-border);
  border-radius: 8px;
  padding: 20px;
  margin-bottom: 16px;
}
.pr-slide-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 12px;
}
.pr-slide-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--pr-text-primary);
  outline: none;
  min-width: 200px;
  border-bottom: 1px dashed transparent;
}
.pr-slide-title:focus {
  border-bottom-color: var(--pr-border);
}
.pr-slide-actions {
  display: flex;
  gap: 4px;
  flex-shrink: 0;
}
.pr-slide-img-preview {
  position: relative;
  display: inline-block;
  margin-bottom: 12px;
  border: 1px solid var(--pr-border);
  border-radius: 6px;
  overflow: hidden;
  max-width: 100%;
}
.pr-slide-img-thumb {
  display: block;
  max-width: 100%;
  max-height: 300px;
  object-fit: contain;
}
.pr-slide-img-remove {
  position: absolute;
  top: 6px;
  right: 6px;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  border: none;
  background: rgba(0,0,0,0.5);
  color: #fff;
  font-size: 16px;
  line-height: 22px;
  text-align: center;
  cursor: pointer;
  opacity: 0;
  transition: opacity 0.2s;
}
.pr-slide-img-preview:hover .pr-slide-img-remove { opacity: 1; }
.pr-slide-md-editor {
  width: 100%;
  min-height: 100px;
  padding: 12px;
  font-size: 13px;
  border: 1px solid var(--pr-border);
  border-radius: 6px;
  font-family: monospace;
  resize: vertical;
  display: none;
  box-sizing: border-box;
}
.pr-slide-card.editing .pr-slide-md-editor { display: block; }
.pr-slide-card.editing .pr-slide-md-rendered { display: none; }
.pr-slide-card:not(.editing) .pr-slide-md-editor { display: none; }
.pr-slide-md-rendered {
  font-size: 14px;
  line-height: 1.7;
  color: var(--pr-text-primary);
  padding: 4px 0;
  min-height: 24px;
  cursor: pointer;
}
.pr-slide-md-rendered:empty::after {
  content: "Click to add content";
  color: #cbd5e1;
  font-style: italic;
  font-size: 13px;
}
.pr-slide-md-rendered h2 { font-size: 16px; font-weight: 600; margin: 12px 0 6px; color: var(--pr-text-primary); }
.pr-slide-md-rendered p { margin: 6px 0; }
.pr-slide-md-rendered blockquote {
  border-left: 3px solid var(--pr-brand);
  padding: 8px 16px;
  margin: 8px 0;
  background: var(--pr-bg-muted);
  font-style: italic;
  color: #475569;
}
.pr-slide-md-rendered ul { padding-left: 20px; margin: 6px 0; }
.pr-slide-md-rendered li { margin-bottom: 4px; }
.pr-slide-md-rendered strong { font-weight: 700; }
.pr-slide-md-rendered em { font-style: italic; }

/* ── Print CSS (comprehensive, matching tabs module) ── */
@page { size: A4 landscape; margin: 10mm 12mm; }

@media print {
  body {
    background: white !important;
    font-size: 12px;
    line-height: 1.4;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }

  .pr-header {
    padding: 10px 0 8px 0 !important;
    background: none !important;
    border-bottom: 2px solid #1a2744 !important;
    border-top: none !important;
    page-break-after: avoid;
  }
  .pr-header h1 { color: #1a2744 !important; font-size: 18px; }
  .pr-header .pr-meta { color: #64748b !important; opacity: 1 !important; }
  .pr-header .pr-btn-print, .pr-header .pr-btn-save, .pr-save-badge { display: none !important; }

  .pr-outer { max-width: none !important; padding: 0 !important; }
  .pr-content { border: none !important; padding: 12px 0 !important; }

  .pr-tab-nav { display: none !important; }
  .pr-panel { display: block !important; page-break-inside: avoid; margin-bottom: 16px; }
  #panel-pinned, #panel-slides, #panel-simulator .sim-battle { display: none !important; }

  .pr-dashboard { page-break-after: avoid; }
  .pr-gauge-card { border-left-color: #1a2744 !important; box-shadow: none !important; }

  .pr-chart-container { page-break-inside: avoid; border: 1px solid #e2e8f0 !important; }
  .pr-chart-export { display: none !important; }

  .pr-table { page-break-inside: avoid; font-size: 11px; }
  .pr-table tbody tr:hover { background: transparent !important; }

  .pr-callout-result, .pr-callout-method, .pr-callout-sampling {
    page-break-inside: avoid;
  }

  .pr-closing { page-break-before: avoid; }

  svg { max-width: 100% !important; }
}

/* ── Responsive ── */
@media (max-width: 768px) {
  .pr-outer { padding: 0 16px; }
  .pr-content { padding: 16px; }
  .pr-dashboard { flex-direction: column; }
  .pr-gauge-card { max-width: none; }
  .pr-metrics { flex-direction: column; }
  .pr-tab-btn { padding: 8px 12px; font-size: 12px; }
  .pr-header-inner { flex-direction: column; gap: 8px; }
}

/* ══ SIMULATOR (embedded tab) ══ */
#panel-simulator .sim-grid {
  display: grid;
  grid-template-columns: 300px 1fr;
  gap: 16px;
  margin-top: 16px;
}
#panel-simulator .sim-controls {
  background: var(--sim-surface);
  border-radius: 8px;
  padding: 20px;
  border: 1px solid var(--sim-border);
}
#panel-simulator .sim-controls h3 {
  font-size: 13px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--sim-text-muted);
  margin-bottom: 16px;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--sim-border);
  border-left: none;
}
#panel-simulator .sim-control-group { margin-bottom: 18px; }
#panel-simulator .sim-control-label {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  font-size: 12px;
  font-weight: 600;
  color: var(--sim-text);
  margin-bottom: 6px;
}
#panel-simulator .sim-control-value {
  font-size: 16px;
  font-weight: 700;
  color: var(--sim-brand);
  font-variant-numeric: tabular-nums;
}
#panel-simulator input[type="range"] {
  -webkit-appearance: none;
  width: 100%;
  height: 6px;
  background: var(--sim-border);
  border-radius: 3px;
  outline: none;
  cursor: pointer;
}
#panel-simulator input[type="range"]::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 18px; height: 18px;
  border-radius: 50%;
  background: var(--sim-brand);
  cursor: pointer;
  border: 2px solid white;
  box-shadow: 0 1px 3px rgba(0,0,0,0.2);
}
#panel-simulator input[type="range"]::-moz-range-thumb {
  width: 18px; height: 18px;
  border-radius: 50%;
  background: var(--sim-brand);
  cursor: pointer;
  border: 2px solid white;
}
#panel-simulator .sim-range-labels {
  display: flex;
  justify-content: space-between;
  font-size: 10px;
  color: var(--sim-text-muted);
  margin-top: 2px;
}
#panel-simulator .sim-price-input-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 8px;
}
#panel-simulator .sim-price-input-row input[type="number"] {
  width: 90px;
  padding: 4px 8px;
  border: 1px solid var(--sim-border);
  border-radius: 4px;
  font-size: 13px;
  font-variant-numeric: tabular-nums;
  text-align: right;
}
#panel-simulator .sim-results {
  background: var(--sim-surface);
  border-radius: 8px;
  padding: 20px;
  border: 1px solid var(--sim-border);
}
#panel-simulator .sim-metrics {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
  gap: 12px;
  margin-bottom: 20px;
}
#panel-simulator .sim-metric {
  background: var(--sim-bg);
  border-radius: 8px;
  padding: 14px;
  text-align: center;
}
#panel-simulator .sim-metric-value {
  font-size: 22px;
  font-weight: 700;
  color: var(--sim-brand);
  font-variant-numeric: tabular-nums;
}
#panel-simulator .sim-metric-label {
  font-size: 11px;
  color: var(--sim-text-muted);
  margin-top: 2px;
}
#panel-simulator .sim-metric-delta {
  font-size: 11px;
  font-weight: 600;
  margin-top: 4px;
}
#panel-simulator .sim-metric-delta.positive { color: var(--sim-green); }
#panel-simulator .sim-metric-delta.negative { color: var(--sim-red); }
#panel-simulator .sim-chart-area {
  margin: 16px 0;
  background: var(--sim-bg);
  border-radius: 8px;
  padding: 16px;
}
#panel-simulator .sim-chart-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--sim-text-muted);
  margin-bottom: 8px;
}
#panel-simulator .sim-scenarios { margin-top: 16px; }
#panel-simulator .sim-scenario-grid {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}
#panel-simulator .sim-scenario-card {
  flex: 1;
  min-width: 140px;
  background: var(--sim-surface);
  border: 2px solid var(--sim-border);
  border-radius: 8px;
  padding: 12px;
  cursor: pointer;
  transition: border-color 0.15s, box-shadow 0.15s;
  text-align: center;
}
#panel-simulator .sim-scenario-card:hover {
  border-color: var(--sim-brand);
  box-shadow: 0 2px 8px rgba(30,58,95,0.1);
}
#panel-simulator .sim-scenario-card.active {
  border-color: var(--sim-brand);
  background: #eff6ff;
}
#panel-simulator .sim-scenario-name { font-size: 13px; font-weight: 600; color: var(--sim-brand); }
#panel-simulator .sim-scenario-price { font-size: 18px; font-weight: 700; color: var(--sim-text); margin: 4px 0; }
#panel-simulator .sim-scenario-desc { font-size: 11px; color: var(--sim-text-muted); }
#panel-simulator .sim-battle { display: none; margin-top: 16px; }
#panel-simulator .sim-battle.active { display: block; }
#panel-simulator .sim-battle-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
#panel-simulator .sim-battle-column {
  background: var(--sim-surface);
  border-radius: 8px;
  padding: 16px;
  border: 1px solid var(--sim-border);
}
#panel-simulator .sim-battle-column h4 {
  font-size: 14px;
  font-weight: 600;
  color: var(--sim-brand);
  margin-bottom: 12px;
  padding-bottom: 6px;
  border-bottom: 1px solid var(--sim-border);
}
#panel-simulator .sim-btn {
  padding: 7px 14px;
  border: 1px solid var(--sim-border);
  border-radius: 6px;
  background: var(--sim-surface);
  color: var(--sim-text);
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
}
#panel-simulator .sim-btn:hover { background: var(--sim-bg); border-color: var(--sim-brand); }
#panel-simulator .sim-btn-primary {
  background: var(--sim-brand);
  color: white;
  border-color: var(--sim-brand);
}
#panel-simulator .sim-btn-primary:hover { opacity: 0.9; }
#panel-simulator .sim-segment-toggle {
  display: flex;
  gap: 0;
  border: 1px solid var(--sim-border);
  border-radius: 6px;
  overflow: hidden;
  margin-bottom: 16px;
}
#panel-simulator .sim-segment-btn {
  padding: 6px 12px;
  border: none;
  background: var(--sim-surface);
  color: var(--sim-text-muted);
  font-size: 12px;
  cursor: pointer;
  border-right: 1px solid var(--sim-border);
}
#panel-simulator .sim-segment-btn:last-child { border-right: none; }
#panel-simulator .sim-segment-btn.active {
  background: var(--sim-brand);
  color: white;
  font-weight: 600;
}
#panel-simulator .sim-actions {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
}

@media print {
  #panel-simulator .sim-btn,
  #panel-simulator .sim-actions,
  #panel-simulator input[type="range"],
  #panel-simulator .sim-price-input-row { display: none !important; }
  #panel-simulator .sim-battle { display: none !important; }
  #panel-simulator .sim-control-value { font-size: 18px !important; }
  #panel-simulator .sim-chart-area { break-inside: avoid; }
}

@media (max-width: 768px) {
  #panel-simulator .sim-grid { grid-template-columns: 1fr; }
  #panel-simulator .sim-battle-grid { grid-template-columns: 1fr; }
  #panel-simulator .sim-metrics { grid-template-columns: repeat(2, 1fr); }
}

/* ── Simulator Callouts ── */
.pr-sim-callouts {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 10px; margin-bottom: 20px;
}
.pr-sim-callout {
  background: #f8fafc; border-left: 3px solid BRAND_TOKEN; padding: 10px 14px;
  font-size: 12px; line-height: 1.5; color: #475569; border-radius: 0 6px 6px 0;
}
.pr-sim-callout strong { color: #1e293b; }

/* ── Section Headers with Export Toolbar ── */
.pr-section-header { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.pr-section-header h2 { margin: 0; }
.pr-export-toolbar { display: flex; gap: 6px; flex-shrink: 0; }
.pr-export-btn {
  background: #f1f5f9; border: 1px solid #e2e8f0; color: #64748b; padding: 4px 10px;
  border-radius: 4px; cursor: pointer; font-size: 11px; transition: all 0.2s;
}
.pr-export-btn:hover { border-color: BRAND_TOKEN; color: BRAND_TOKEN; }
.pr-pin-btn {
  background: #f1f5f9; border: 1px solid #e2e8f0; color: #64748b; padding: 4px 12px;
  border-radius: 4px; cursor: pointer; font-size: 12px; transition: all 0.2s;
}
.pr-pin-btn:hover { border-color: BRAND_TOKEN; color: BRAND_TOKEN; }
.pr-pin-btn.pinned { background: BRAND_TOKEN; color: white; border-color: BRAND_TOKEN; }

/* ── Pin Badge ── */
.pr-pin-badge {
  display: inline-flex; align-items: center; justify-content: center;
  background: BRAND_TOKEN; color: white; font-size: 10px; font-weight: 600;
  min-width: 16px; height: 16px; border-radius: 8px; margin-left: 4px; padding: 0 4px;
}

/* ── Pinned Views Panel ── */
.pr-pinned-empty { text-align: center; padding: 48px 24px; color: #94a3b8; }
.pr-pinned-empty-icon { font-size: 36px; margin-bottom: 12px; }
.pr-pinned-empty-text { font-size: 16px; font-weight: 500; color: #64748b; }
.pr-pinned-empty-hint { font-size: 13px; margin-top: 8px; }
.pinned-card {
  border: 1px solid #e2e8f0; border-radius: 8px; margin-bottom: 16px;
  overflow: hidden; background: white;
}
.pinned-card-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 10px 14px; background: #f8fafc; border-bottom: 1px solid #e2e8f0;
}
.pinned-card-title { font-weight: 600; font-size: 14px; color: #1e293b; }
.pinned-card-actions { display: flex; gap: 4px; }
.pinned-move-btn, .pinned-remove-btn {
  background: none; border: 1px solid #e2e8f0; color: #64748b; width: 26px; height: 26px;
  border-radius: 4px; cursor: pointer; font-size: 14px; display: flex; align-items: center;
  justify-content: center;
}
.pinned-move-btn:hover { border-color: BRAND_TOKEN; color: BRAND_TOKEN; }
.pinned-remove-btn:hover { border-color: #ef4444; color: #ef4444; }
.pinned-card-chart { padding: 12px; }
.pinned-card-chart svg { max-width: 100%; height: auto; }
.pinned-card-table { padding: 0 12px 12px; overflow-x: auto; }
.pinned-card-table .pr-table { font-size: 12px; }
.pinned-card-insight {
  padding: 10px 14px; background: #f8fafc; border-top: 1px solid #e2e8f0;
  font-size: 13px; color: #475569; font-style: italic;
}
.pr-pinned-actions { margin-top: 16px; }
.pr-btn-secondary {
  background: white; border: 1px solid #e2e8f0; color: #475569; padding: 8px 16px;
  border-radius: 6px; cursor: pointer; font-size: 13px;
}
.pr-btn-secondary:hover { border-color: BRAND_TOKEN; color: BRAND_TOKEN; }

/* ── Insight Areas ── */
.pr-insight-area { margin-top: 24px; border-top: 1px solid #e2e8f0; padding-top: 16px; }
.pr-insight-toggle {
  background: none; border: 1px dashed #cbd5e1; color: #64748b; padding: 6px 14px;
  border-radius: 6px; cursor: pointer; font-size: 13px; transition: all 0.2s;
}
.pr-insight-toggle:hover { border-color: BRAND_TOKEN; color: BRAND_TOKEN; }
.pr-insight-container { display: none; position: relative; margin-top: 10px; }
.pr-insight-container.visible { display: block; }
.pr-insight-editor {
  min-height: 60px; padding: 12px 36px 12px 12px; border: 1px solid #e2e8f0;
  border-radius: 6px; font-size: 13px; line-height: 1.5; color: #334155;
  outline: none; transition: border-color 0.2s;
}
.pr-insight-editor:focus { border-color: BRAND_TOKEN; box-shadow: 0 0 0 2px rgba(30,58,95,0.08); }
.pr-insight-editor:empty::before {
  content: attr(data-placeholder); color: #94a3b8; pointer-events: none;
}
.pr-insight-dismiss {
  position: absolute; top: 8px; right: 8px; background: none; border: none;
  color: #94a3b8; font-size: 18px; cursor: pointer; line-height: 1; padding: 2px 6px;
}
.pr-insight-dismiss:hover { color: #ef4444; }

/* ── About Panel ── */
.pr-about-table { max-width: 500px; }
.pr-about-table td { padding: 8px 16px 8px 0; border-bottom: 1px solid #f1f5f9; }
.pr-about-label { font-weight: 500; color: #64748b; white-space: nowrap; }
.pr-callout-method {
  background: #f8fafc; border-left: 3px solid BRAND_TOKEN; padding: 14px 18px;
  margin: 12px 0 24px; font-size: 13px; line-height: 1.6; color: #475569; border-radius: 0 6px 6px 0;
}
.pr-about-branding {
  display: flex; align-items: center; gap: 14px; margin-top: 32px;
  padding-top: 24px; border-top: 1px solid #e2e8f0;
}
.pr-about-logo { width: 40px; height: 40px; border-radius: 8px; flex-shrink: 0; }
.pr-about-platform-name { font-weight: 600; font-size: 14px; color: #1e293b; }
.pr-about-platform-desc { font-size: 12px; color: #94a3b8; margin-top: 2px; }

@media print {
  .pr-insight-toggle, .pr-insight-dismiss { display: none !important; }
  .pr-insight-container.visible { display: block !important; border: none; }
  .pr-insight-editor { border: none; padding: 0; min-height: 0; }
  .pr-insight-editor:empty { display: none; }
  .pr-export-toolbar, .pr-export-btn, .pr-pin-btn { display: none !important; }
  .pr-btn-save, .pr-save-badge { display: none !important; }
  .pr-pinned-actions { display: none !important; }
  .pinned-card-actions { display: none !important; }
}
'

  css <- gsub("BRAND_TOKEN", brand, css, fixed = TRUE)
  css <- gsub("ACCENT_TOKEN", accent, css, fixed = TRUE)
  paste0(shared_css, "\n", css)
}


# ==============================================================================
# HEADER (gradient, matching tabs module)
# ==============================================================================

build_pricing_header <- function(project_name, meta, brand) {
  method_label <- switch(tolower(meta$method %||% "unknown"),
    "van_westendorp" = "Van Westendorp PSM",
    "gabor_granger" = "Gabor-Granger",
    "monadic" = "Monadic",
    "both" = "VW + Gabor-Granger",
    "Pricing"
  )

  sprintf(
    '<div class="pr-header">
       <div class="pr-header-inner">
         <div>
           <h1>%s</h1>
           <div class="pr-meta">
             <span>%s</span>
             <span>n = %s</span>
             <span>Generated: %s</span>
           </div>
         </div>
         <div class="pr-header-actions">
           <button class="pr-btn-save" onclick="saveReportHTML()">Save Report</button>
           <span class="pr-save-badge" id="save-badge" style="display:none"></span>
           <button class="pr-btn-print" onclick="window.print()">Print / PDF</button>
         </div>
       </div>
     </div>',
    htmlEscape(project_name),
    htmlEscape(method_label),
    format(meta$n_valid, big.mark = ","),
    meta$generated
  )
}


# ==============================================================================
# DASHBOARD SUMMARY (gauge cards + metadata strip)
# ==============================================================================

build_dashboard_summary <- function(html_data, config) {
  summary <- html_data$summary
  currency <- config$currency_symbol %||% "$"
  method <- html_data$meta$method

  cards <- character(0)

  # Recommended price
  if (!is.null(summary$recommended_price)) {
    cards <- c(cards, sprintf(
      '<div class="pr-gauge-card">
         <div class="pr-gauge-value">%s</div>
         <div class="pr-gauge-label">Recommended Price</div>
       </div>',
      summary$recommended_price
    ))
  }

  # Confidence
  if (!is.null(summary$confidence_level)) {
    score_text <- ""
    if (!is.null(summary$confidence_score)) {
      score_text <- sprintf('<div class="pr-gauge-sub">Score: %.0f%%</div>',
                            summary$confidence_score * 100)
    }
    cards <- c(cards, sprintf(
      '<div class="pr-gauge-card">
         <div class="pr-gauge-value">%s</div>
         <div class="pr-gauge-label">Confidence</div>
         %s
       </div>',
      htmlEscape(summary$confidence_level), score_text
    ))
  }

  # Acceptable range (from VW or synthesis)
  range_text <- NULL
  if (!is.null(html_data$recommendation$acceptable_range)) {
    ar <- html_data$recommendation$acceptable_range
    range_text <- sprintf("%s%.2f - %s%.2f", currency, ar$lower, currency, ar$upper)
  } else if (!is.null(html_data$van_westendorp)) {
    ar <- html_data$van_westendorp$acceptable_range
    if (!is.null(ar)) {
      range_text <- sprintf("%s%.2f - %s%.2f", currency, ar$lower, currency, ar$upper)
    }
  }
  if (!is.null(range_text)) {
    cards <- c(cards, sprintf(
      '<div class="pr-gauge-card">
         <div class="pr-gauge-value" style="font-size:18px;">%s</div>
         <div class="pr-gauge-label">Acceptable Range</div>
       </div>',
      range_text
    ))
  }

  # Valid respondents
  cards <- c(cards, sprintf(
    '<div class="pr-gauge-card">
       <div class="pr-gauge-value">%s</div>
       <div class="pr-gauge-label">Valid Respondents</div>
     </div>',
    format(summary$n_valid, big.mark = ",")
  ))

  # Metadata strip
  method_label <- switch(tolower(method),
    "van_westendorp" = "Van Westendorp PSM",
    "gabor_granger" = "Gabor-Granger Demand Analysis",
    "monadic" = "Monadic Price Testing",
    "both" = "Combined VW + Gabor-Granger",
    "Pricing Analysis"
  )

  weighted_text <- if (isTRUE(config$is_weighted)) "Weighted" else "Unweighted"

  meta_strip <- sprintf(
    '<div class="pr-meta-strip">
       <span><strong>Method:</strong> %s</span>
       <span><strong>n:</strong> %s</span>
       <span><strong>Weighting:</strong> %s</span>
       <span><strong>Generated:</strong> %s</span>
     </div>',
    htmlEscape(method_label),
    format(summary$n_valid, big.mark = ","),
    weighted_text,
    html_data$meta$generated
  )

  sprintf(
    '<div class="pr-dashboard">%s</div>\n%s',
    paste(cards, collapse = "\n"),
    meta_strip
  )
}


# ==============================================================================
# TAB NAVIGATION
# ==============================================================================

build_pricing_tab_nav <- function(tabs) {
  buttons <- character(0)
  idx <- 1
  first <- TRUE
  for (id in names(tabs)) {
    active_class <- if (first) " active" else ""
    badge <- if (id == "pinned") '<span class="pr-pin-badge" id="pin-badge" style="display:none">0</span>' else ""
    buttons <- c(buttons, sprintf(
      '<button class="pr-tab-btn%s" data-tab="%s" data-index="%d">%s%s</button>',
      active_class, id, idx, htmlEscape(tabs[[id]]), badge
    ))
    first <- FALSE
    idx <- idx + 1
  }

  sprintf('<div class="pr-tab-nav">%s</div>', paste(buttons, collapse = "\n"))
}


# ==============================================================================
# CONTENT PANELS
# ==============================================================================

build_summary_panel <- function(html_data, tables, charts, insights = list()) {
  summary <- html_data$summary

  sprintf(
    '<div class="pr-panel active" id="panel-summary">
       <div class="pr-section">
         <div class="pr-section-header"><h2>Overview</h2>%s</div>
         %s
         %s
       </div>
     </div>',
    build_export_toolbar("summary"),
    summary$callout %||% "",
    build_insight_area("summary", insights$summary)
  )
}


build_vw_panel <- function(vw_data, tables, charts, insights = list()) {
  sprintf(
    '<div class="pr-panel" id="panel-vw">
       <div class="pr-section">
         <div class="pr-section-header"><h2>Van Westendorp Price Sensitivity</h2>%s</div>
         %s
         <h3>Price Points</h3>
         %s
         %s
         %s
         %s
       </div>
     </div>',
    build_export_toolbar("vw"),
    vw_data$callout %||% "",
    tables$vw_price_points %||% "",
    if (!is.null(charts$vw_curves) && nzchar(charts$vw_curves)) {
      sprintf('<div class="pr-chart-container"><div class="pr-chart-title">Price Sensitivity Curves</div><button class="pr-chart-export" onclick="TurasCharts.exportSVG(this)">PNG</button>%s</div>', charts$vw_curves)
    } else "",
    if (!is.null(tables$vw_ci) && nzchar(tables$vw_ci)) {
      sprintf('<h3>Confidence Intervals</h3>%s', tables$vw_ci)
    } else "",
    build_insight_area("van_westendorp", insights$van_westendorp)
  )
}


build_gg_panel <- function(gg_data, tables, charts, currency, insights = list()) {
  sprintf(
    '<div class="pr-panel" id="panel-gg">
       <div class="pr-section">
         <div class="pr-section-header"><h2>Gabor-Granger Demand Analysis</h2>%s</div>
         %s
         <h3>Optimal Price</h3>
         %s
         %s
         <h3>Demand Schedule</h3>
         %s
         %s
         %s
         %s
       </div>
     </div>',
    build_export_toolbar("gg"),
    gg_data$callout %||% "",
    tables$gg_optimal %||% "",
    if (!is.null(charts$gg_demand) && nzchar(charts$gg_demand)) {
      sprintf('<div class="pr-chart-container"><div class="pr-chart-title">Demand &amp; Revenue Curves</div><button class="pr-chart-export" onclick="TurasCharts.exportSVG(this)">PNG</button>%s</div>', charts$gg_demand)
    } else "",
    tables$gg_demand %||% "",
    if (!is.null(tables$gg_elasticity) && nzchar(tables$gg_elasticity)) {
      sprintf('<h3>Price Elasticity</h3>%s', tables$gg_elasticity)
    } else "",
    if (!is.null(charts$gg_elasticity) && nzchar(charts$gg_elasticity)) {
      sprintf('<div class="pr-chart-container"><div class="pr-chart-title">Elasticity by Price</div><button class="pr-chart-export" onclick="TurasCharts.exportSVG(this)">PNG</button>%s</div>', charts$gg_elasticity)
    } else "",
    build_insight_area("gabor_granger", insights$gabor_granger)
  )
}


build_monadic_panel <- function(monadic_data, tables, charts, currency, insights = list()) {
  sprintf(
    '<div class="pr-panel" id="panel-monadic">
       <div class="pr-section">
         <div class="pr-section-header"><h2>Monadic Price Testing</h2>%s</div>
         %s
         <h3>Optimal Price</h3>
         %s
         %s
         <h3>Model Summary</h3>
         %s
         <h3>Observed Data</h3>
         %s
         %s
         %s
       </div>
     </div>',
    build_export_toolbar("monadic"),
    monadic_data$callout %||% "",
    tables$monadic_optimal %||% "",
    if (!is.null(charts$monadic_demand) && nzchar(charts$monadic_demand)) {
      sprintf('<div class="pr-chart-container"><div class="pr-chart-title">Demand Curve (Logistic Model)</div><button class="pr-chart-export" onclick="TurasCharts.exportSVG(this)">PNG</button>%s</div>', charts$monadic_demand)
    } else "",
    tables$monadic_model %||% "",
    tables$monadic_observed %||% "",
    if (!is.null(charts$monadic_elasticity) && nzchar(charts$monadic_elasticity)) {
      sprintf('<h3>Price Elasticity</h3><div class="pr-chart-container"><div class="pr-chart-title">Elasticity by Price</div><button class="pr-chart-export" onclick="TurasCharts.exportSVG(this)">PNG</button>%s</div>', charts$monadic_elasticity)
    } else "",
    build_insight_area("monadic", insights$monadic)
  )
}


build_segments_panel <- function(segment_data, tables, charts, insights = list()) {
  sprintf(
    '<div class="pr-panel" id="panel-segments">
       <div class="pr-section">
         <div class="pr-section-header"><h2>Segment Analysis</h2>%s</div>
         %s
         %s
         %s
         %s
       </div>
     </div>',
    build_export_toolbar("segments"),
    segment_data$callout %||% "",
    tables$segment_comparison %||% "",
    if (!is.null(charts$segment_comparison) && nzchar(charts$segment_comparison)) {
      sprintf('<div class="pr-chart-container"><div class="pr-chart-title">Segment Price Comparison</div><button class="pr-chart-export" onclick="TurasCharts.exportSVG(this)">PNG</button>%s</div>', charts$segment_comparison)
    } else "",
    build_insight_area("segments", insights$segments)
  )
}


build_recommendation_panel <- function(rec_data, tables, insights = list()) {
  sprintf(
    '<div class="pr-panel" id="panel-recommendation">
       <div class="pr-section">
         <div class="pr-section-header"><h2>Recommendation</h2>%s</div>
         %s
         %s
         %s
       </div>
     </div>',
    build_export_toolbar("recommendation"),
    rec_data$callout %||% "",
    if (!is.null(tables$evidence) && nzchar(tables$evidence)) {
      sprintf('<h3>Supporting Evidence</h3>%s', tables$evidence)
    } else "",
    build_insight_area("recommendation", insights$recommendation)
  )
}


# ==============================================================================
# PINNED VIEWS PANEL
# ==============================================================================

# ==============================================================================
# ADDED SLIDES PANEL (config-driven + interactive slide creation)
# ==============================================================================

#' Build the Added Slides panel
#'
#' Renders initial slides from config (if any) and provides interactive
#' slide creation with markdown editing, image upload, reordering, and pinning.
#'
#' @param slides List of slide objects from load_added_slides(), or NULL
#' @return HTML string for the slides panel
#' @keywords internal
build_added_slides_panel <- function(slides = NULL) {

  # Build initial slide cards from config data
  slide_cards_html <- ""
  if (!is.null(slides) && length(slides) > 0) {
    cards <- vapply(slides, function(s) {
      build_slide_card(s$id, s$title, s$content, s$image_data)
    }, character(1))
    slide_cards_html <- paste(cards, collapse = "\n")
  }

  has_slides <- !is.null(slides) && length(slides) > 0
  empty_display <- if (has_slides) "display:none;" else ""

  sprintf(
    '<div class="pr-panel" id="panel-slides">
       <div class="pr-section">
         <div class="pr-slides-header">
           <div>
             <h2 style="border:none;padding:0;margin:0 0 4px;">Added Slides</h2>
             <p class="pr-slides-hint">Open-ended findings, quotes, and narrative content. Double-click to edit, use markdown for formatting.</p>
           </div>
           <div class="pr-slides-actions">
             <button class="pr-btn-secondary" onclick="addPrSlide()">+ Add Slide</button>
           </div>
         </div>
         <div class="pr-slides-md-help">
           <span style="font-weight:600;color:#475569;">Formatting: </span>
           <code>**bold**</code> &middot;
           <code>*italic*</code> &middot;
           <code>## Heading</code> &middot;
           <code>- bullet</code> &middot;
           <code>&gt; quote</code>
         </div>
         <div id="pr-slides-container">%s</div>
         <div id="pr-slides-empty" style="%stext-align:center;padding:60px 20px;color:#94a3b8;">
           <div style="font-size:36px;margin-bottom:12px;">&#128221;</div>
           <div style="font-size:14px;font-weight:600;">No slides yet</div>
           <div style="font-size:12px;margin-top:4px;">Click &ldquo;Add Slide&rdquo; to create narrative content, or add an &ldquo;AddedSlides&rdquo; sheet to your config Excel.</div>
         </div>
       </div>
     </div>',
    slide_cards_html,
    empty_display
  )
}


#' Build a single slide card
#'
#' @param slide_id Unique ID for the slide
#' @param title Slide title text
#' @param content_md Markdown content
#' @param image_data Base64 data URI for embedded image, or NULL
#' @return HTML string for one slide card
#' @keywords internal
build_slide_card <- function(slide_id, title, content_md, image_data = NULL) {

  has_img <- !is.null(image_data) && nzchar(image_data %||% "")
  img_display <- if (has_img) "" else "display:none;"
  img_src <- if (has_img) image_data else ""

  # Escape content for safe embedding in HTML textarea
  safe_title <- htmlEscape(title)
  safe_content <- htmlEscape(content_md)

  sprintf(
    '<div class="pr-slide-card" data-slide-id="%s">
       <div class="pr-slide-header">
         <div class="pr-slide-title" contenteditable="true">%s</div>
         <div class="pr-slide-actions">
           <button class="pr-export-btn" title="Add image" onclick="triggerPrSlideImage(\'%s\')">&#x1F5BC;</button>
           <button class="pr-export-btn" title="Pin to Views" onclick="pinPrSlide(\'%s\')">&#x1F4CC;</button>
           <button class="pr-export-btn" title="Move up" onclick="movePrSlide(\'%s\',\'up\')">&#x25B2;</button>
           <button class="pr-export-btn" title="Move down" onclick="movePrSlide(\'%s\',\'down\')">&#x25BC;</button>
           <button class="pr-export-btn" title="Remove slide" style="color:#e8614d;" onclick="removePrSlide(\'%s\')">&#x2715;</button>
         </div>
       </div>
       <div class="pr-slide-img-preview" style="%s">
         <img class="pr-slide-img-thumb" src="%s"/>
         <button class="pr-slide-img-remove" onclick="removePrSlideImage(\'%s\')" title="Remove image">&times;</button>
       </div>
       <input type="file" class="pr-slide-img-input" accept="image/*" style="display:none;" onchange="handlePrSlideImage(\'%s\', this)">
       <textarea class="pr-slide-md-editor" rows="6" placeholder="Enter markdown content... (**bold**, *italic*, &gt; quote, - bullet, ## heading)">%s</textarea>
       <div class="pr-slide-md-rendered"></div>
       <textarea class="pr-slide-md-store" style="display:none;">%s</textarea>
       <textarea class="pr-slide-img-store" style="display:none;">%s</textarea>
     </div>',
    slide_id,
    safe_title,
    slide_id, slide_id, slide_id, slide_id, slide_id,
    img_display,
    img_src,
    slide_id,
    slide_id,
    safe_content,
    safe_content,
    if (has_img) img_src else ""
  )
}


build_pinned_views_panel <- function() {
  '<div class="pr-panel" id="panel-pinned">
     <div class="pr-section">
       <h2>Pinned Views</h2>
       <div id="pinned-empty-state" class="pr-pinned-empty">
         <div class="pr-pinned-empty-icon">&#128204;</div>
         <div class="pr-pinned-empty-text">No pinned views yet.</div>
         <div class="pr-pinned-empty-hint">Click the Pin button on any section to capture it here for curation and export.</div>
       </div>
       <div id="pinned-cards-container"></div>
       <div class="pr-pinned-actions" style="display:none" id="pinned-bulk-actions">
         <button class="pr-btn-secondary" onclick="exportAllPinned()">Export All as PNG</button>
       </div>
     </div>
     <script id="pinned-views-data" type="application/json">[]</script>
   </div>'
}


# ==============================================================================
# EXPORT TOOLBAR (per-panel pin + export buttons)
# ==============================================================================

build_export_toolbar <- function(section_id) {
  sprintf(
    '<div class="pr-export-toolbar">
       <button class="pr-export-btn" onclick="exportChartPNG(\'%s\')" title="Export chart as PNG">Export PNG</button>
       <button class="pr-export-btn" onclick="exportTableExcel(\'%s\')" title="Export table as Excel">Export Excel</button>
       <button class="pr-export-btn" onclick="exportSlidePNG(\'%s\')" title="Export as slide">Export Slide</button>
       <button class="pr-pin-btn" data-section="%s" onclick="togglePin(\'%s\')" title="Pin to Views">\U0001F4CC Pin to Views</button>
     </div>',
    section_id, section_id, section_id, section_id, section_id
  )
}


# ==============================================================================
# INSIGHT AREA (editable per-section comments)
# ==============================================================================

build_insight_area <- function(section_id, initial_text = NULL) {
  if (is.null(initial_text) || is.na(initial_text)) initial_text <- ""
  initial_text <- as.character(initial_text)

  config_json <- if (nzchar(trimws(initial_text))) {
    sprintf('{"text":"%s"}', gsub('"', '\\\\"', gsub('\n', '\\\\n', initial_text)))
  } else '{"text":""}'

  has_text <- nzchar(trimws(initial_text))

  sprintf(
    '<div class="pr-insight-area" data-section="%s">
       <script class="pr-insight-config-data" type="application/json">%s</script>
       <button class="pr-insight-toggle" onclick="toggleInsight(\'%s\')">%s</button>
       <div class="pr-insight-container%s">
         <div class="pr-insight-editor" contenteditable="true" data-section="%s" data-placeholder="Add your insight or commentary here...">%s</div>
         <button class="pr-insight-dismiss" onclick="dismissInsight(\'%s\')" title="Clear insight">&times;</button>
       </div>
       <textarea class="pr-insight-store" data-section="%s" style="display:none">%s</textarea>
     </div>',
    section_id,
    config_json,
    section_id,
    if (has_text) "Edit Insight" else "+ Add Insight",
    if (has_text) " visible" else "",
    section_id,
    htmlEscape(initial_text),
    section_id,
    section_id,
    htmlEscape(initial_text)
  )
}


# ==============================================================================
# ABOUT PANEL
# ==============================================================================

build_about_panel <- function(html_data, config) {
  project_name <- config$project_name %||% "Pricing Analysis"
  method <- html_data$meta$method
  brand <- config$brand_colour %||% "#1e3a5f"
  currency <- config$currency_symbol %||% "$"
  analyst <- config$analyst_name %||% ""
  company <- config$company_name %||% config$client_name %||% ""

  # Method description
  method_desc <- switch(tolower(method),
    "van_westendorp" = "Van Westendorp Price Sensitivity Meter (PSM) identifies acceptable price ranges through four price perception questions.",
    "gabor_granger" = "Gabor-Granger analysis measures purchase intent at specific price points to construct a demand curve and identify the revenue-maximising price.",
    "monadic" = "Monadic price testing uses randomised cell design where each respondent evaluates a single price point, with logistic regression modelling the demand curve.",
    "both" = "Combined Van Westendorp PSM and Gabor-Granger analysis provides complementary price sensitivity insights from both methodologies.",
    "Pricing analysis using the configured methodology."
  )

  # Diagnostics
  n_total <- html_data$meta$n_total %||% 0
  n_valid <- html_data$meta$n_valid %||% n_total
  date_generated <- format(Sys.time(), "%d %B %Y at %H:%M")

  # Build info rows
  info_rows <- sprintf(
    '<tr><td class="pr-about-label">Project</td><td>%s</td></tr>
     <tr><td class="pr-about-label">Analysis Method</td><td>%s</td></tr>
     <tr><td class="pr-about-label">Currency</td><td>%s</td></tr>
     <tr><td class="pr-about-label">Total Respondents</td><td>%s</td></tr>
     <tr><td class="pr-about-label">Valid Responses</td><td>%s</td></tr>
     <tr><td class="pr-about-label">Generated</td><td>%s</td></tr>',
    htmlEscape(project_name),
    htmlEscape(gsub("_", " ", method)),
    htmlEscape(currency),
    format(n_total, big.mark = ","),
    format(n_valid, big.mark = ","),
    date_generated
  )

  if (nzchar(analyst)) {
    info_rows <- paste0(info_rows, sprintf(
      '<tr><td class="pr-about-label">Analyst</td><td>%s</td></tr>',
      htmlEscape(analyst)
    ))
  }
  if (nzchar(company)) {
    info_rows <- paste0(info_rows, sprintf(
      '<tr><td class="pr-about-label">Organisation</td><td>%s</td></tr>',
      htmlEscape(company)
    ))
  }

  sprintf(
    '<div class="pr-panel" id="panel-about">
       <div class="pr-section">
         <h2>About This Report</h2>
         <table class="pr-table pr-about-table">
           <tbody>%s</tbody>
         </table>
         <h3>Methodology</h3>
         <div class="pr-callout-method">%s</div>
         <div class="pr-about-branding">
           <div class="pr-about-logo" style="background-color:%s"></div>
           <div class="pr-about-platform">
             <div class="pr-about-platform-name">TURAS Analytics Platform</div>
             <div class="pr-about-platform-desc">Pricing Research Module</div>
           </div>
         </div>
       </div>
     </div>',
    info_rows,
    method_desc,
    brand
  )
}


# ==============================================================================
# SIMULATOR PANEL (embedded within consolidated report)
# ==============================================================================

build_simulator_panel <- function(unit_cost, simulator_data) {
  has_segments <- isTRUE(simulator_data$has_segments)

  profit_card <- if (unit_cost > 0) {
    '<div class="sim-metric" id="sim-profit-card">
       <div class="sim-metric-value" id="sim-profit-value">--</div>
       <div class="sim-metric-label">Profit Index</div>
     </div>'
  } else ""

  segment_section <- if (has_segments) {
    '<div id="sim-segment-section">
       <div class="sim-segment-toggle" id="sim-segment-buttons"></div>
     </div>'
  } else '<div id="sim-segment-section" style="display:none;"></div>'

  profit_callout <- if (unit_cost > 0) {
    '<div class="pr-sim-callout"><strong>Profit Index</strong> = (Price - Unit Cost) &times; Purchase Intent. Shows relative profitability at each price point.</div>'
  } else ""

  segment_callout <- if (has_segments) {
    '<div class="pr-sim-callout"><strong>Segment Toggle</strong> &mdash; Switch between customer segments to see how price sensitivity varies across groups.</div>'
  } else ""

  sprintf(
    '<div class="pr-panel" id="panel-simulator">
       <div class="pr-section">
         <h2>Interactive Simulator</h2>

         <div class="pr-sim-callouts">
           <div class="pr-sim-callout"><strong>Purchase Intent</strong> &mdash; The estimated percentage of customers willing to buy at the selected price.</div>
           <div class="pr-sim-callout"><strong>Revenue Index</strong> = Price &times; Purchase Intent. Identifies the price that maximises total revenue.</div>
           %s
           <div class="pr-sim-callout"><strong>Battle Mode</strong> &mdash; Compare two pricing scenarios side by side to evaluate trade-offs.</div>
           %s
         </div>

         <div class="sim-actions">
           <button class="sim-btn" id="sim-battle-toggle">Battle Mode</button>
           <button class="sim-btn sim-btn-primary" onclick="PricingSimulator.exportPNG()">Export PNG</button>
         </div>

         %s

         <div class="sim-grid">
           <!-- Controls Panel -->
           <div class="sim-controls">
             <h3>Price Controls</h3>
             <div class="sim-control-group">
               <div class="sim-control-label">
                 <span>Price</span>
                 <span class="sim-control-value" id="sim-current-price">--</span>
               </div>
               <input type="range" id="sim-price-slider">
               <div class="sim-range-labels">
                 <span id="sim-range-min"></span>
                 <span id="sim-range-max"></span>
               </div>
               <div class="sim-price-input-row">
                 <label style="font-size:11px;color:var(--sim-text-muted);">Set price:</label>
                 <input type="number" id="sim-price-input" step="0.01">
               </div>
             </div>

             <div id="sim-scenarios-section" class="sim-scenarios">
               <h3>Preset Scenarios</h3>
               <div class="sim-scenario-grid" id="sim-scenario-cards"></div>
             </div>
           </div>

           <!-- Results Panel -->
           <div class="sim-results">
             <div class="sim-metrics">
               <div class="sim-metric">
                 <div class="sim-metric-value" id="sim-intent-value">--</div>
                 <div class="sim-metric-label">Purchase Intent</div>
               </div>
               <div class="sim-metric">
                 <div class="sim-metric-value" id="sim-revenue-value">--</div>
                 <div class="sim-metric-label">Revenue Index</div>
                 <div id="sim-revenue-delta" class="sim-metric-delta"></div>
               </div>
               <div class="sim-metric">
                 <div class="sim-metric-value" id="sim-volume-value">--</div>
                 <div class="sim-metric-label">Volume Index</div>
               </div>
               %s
             </div>

             <div class="sim-chart-area">
               <div class="sim-chart-title">Demand &amp; Revenue Curves</div>
               <div id="sim-chart-svg"></div>
             </div>
           </div>
         </div>

         <!-- Battle Mode Section -->
         <div class="sim-battle" id="sim-battle-section">
           <div class="sim-battle-grid">
             <div class="sim-battle-column">
               <h4>Scenario A</h4>
               <div class="sim-control-group">
                 <div class="sim-control-label"><span>Price</span><span class="sim-control-value" id="sim-battle-price-0">--</span></div>
                 <input type="range" id="sim-battle-slider-0">
               </div>
               <div class="sim-metrics">
                 <div class="sim-metric"><div class="sim-metric-value" id="sim-battle-intent-0">--</div><div class="sim-metric-label">Intent</div></div>
                 <div class="sim-metric"><div class="sim-metric-value" id="sim-battle-revenue-0">--</div><div class="sim-metric-label">Revenue</div></div>
               </div>
             </div>
             <div class="sim-battle-column">
               <h4>Scenario B</h4>
               <div class="sim-control-group">
                 <div class="sim-control-label"><span>Price</span><span class="sim-control-value" id="sim-battle-price-1">--</span></div>
                 <input type="range" id="sim-battle-slider-1">
               </div>
               <div class="sim-metrics">
                 <div class="sim-metric"><div class="sim-metric-value" id="sim-battle-intent-1">--</div><div class="sim-metric-label">Intent</div></div>
                 <div class="sim-metric"><div class="sim-metric-value" id="sim-battle-revenue-1">--</div><div class="sim-metric-label">Revenue</div></div>
               </div>
             </div>
           </div>
         </div>

       </div>
     </div>',
    profit_callout,
    segment_callout,
    segment_section,
    profit_card
  )
}


# ==============================================================================
# CLOSING SECTION
# ==============================================================================

build_pricing_closing <- function(config) {
  analyst <- config$analyst_name %||% ""
  analyst_line <- if (nzchar(analyst)) {
    sprintf('<div class="pr-closing-info">Analyst: %s</div>', htmlEscape(analyst))
  } else ""

  sprintf(
    '<div class="pr-closing">
       <div class="pr-closing-divider"></div>
       <div class="pr-closing-content">
         <div class="pr-closing-brand">Powered by TURAS Analytics Platform</div>
         <div class="pr-closing-info">Pricing Research Module &middot; Generated %s</div>
         <div class="pr-closing-info">Confidential &mdash; For internal use only</div>
         %s
       </div>
     </div>',
    format(Sys.Date(), "%B %Y"),
    analyst_line
  )
}


# ==============================================================================
# JAVASCRIPT (loaded from external files, embedded inline)
# ==============================================================================

build_pricing_js <- function(js_dir = NULL) {
  # Read JS from external files when available, fall back to inline
  js_parts <- character(0)

  if (!is.null(js_dir) && dir.exists(js_dir)) {
    js_files <- c("pricing_simulator.js", "pricing_insights.js", "pricing_pins.js", "pricing_slides.js", "pricing_exports.js", "pricing_navigation.js")
    for (jf in js_files) {
      jpath <- file.path(js_dir, jf)
      if (file.exists(jpath)) {
        js_parts <- c(js_parts, paste(readLines(jpath, warn = FALSE), collapse = "\n"))
      }
    }
  }

  # If we loaded at least the navigation JS from files, return combined
  if (length(js_parts) > 0) {
    return(paste(js_parts, collapse = "\n\n"))
  }

  # Fallback: inline JS (navigation + chart export only, no simulator)
  '
  (function() {
    "use strict";
    var tabs = document.querySelectorAll(".pr-tab-btn");
    var panels = document.querySelectorAll(".pr-panel");
    function switchTab(target) {
      tabs.forEach(function(t) { t.classList.remove("active"); });
      panels.forEach(function(p) { p.classList.remove("active"); });
      for (var i = 0; i < tabs.length; i++) {
        if (tabs[i].getAttribute("data-tab") === target) { tabs[i].classList.add("active"); break; }
      }
      var panel = document.getElementById("panel-" + target);
      if (panel) panel.classList.add("active");
    }
    tabs.forEach(function(tab) {
      tab.addEventListener("click", function() { switchTab(this.getAttribute("data-tab")); });
    });
    document.addEventListener("keydown", function(e) {
      if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;
      var tabArr = Array.prototype.slice.call(tabs);
      var currentIdx = -1;
      for (var i = 0; i < tabArr.length; i++) {
        if (tabArr[i].classList.contains("active")) { currentIdx = i; break; }
      }
      if (e.key >= "1" && e.key <= "9") { var idx = parseInt(e.key) - 1; if (idx < tabArr.length) switchTab(tabArr[idx].getAttribute("data-tab")); return; }
      if (e.key === "ArrowLeft" && currentIdx > 0) switchTab(tabArr[currentIdx - 1].getAttribute("data-tab"));
      else if (e.key === "ArrowRight" && currentIdx < tabArr.length - 1) switchTab(tabArr[currentIdx + 1].getAttribute("data-tab"));
    });
    var tooltip = document.createElement("div"); tooltip.className = "pr-tooltip"; document.body.appendChild(tooltip);
    document.addEventListener("mouseover", function(e) { var el = e.target.closest("[data-tooltip]"); if (el) { tooltip.textContent = el.getAttribute("data-tooltip"); tooltip.classList.add("visible"); } });
    document.addEventListener("mousemove", function(e) { if (tooltip.classList.contains("visible")) { tooltip.style.left = (e.clientX + 12) + "px"; tooltip.style.top = (e.clientY - 28) + "px"; } });
    document.addEventListener("mouseout", function(e) { if (e.target.closest("[data-tooltip]")) tooltip.classList.remove("visible"); });
    window.PricingNav = { switchTab: switchTab };
  })();
  var TurasCharts = {
    exportSVG: function(btn) {
      var container = btn.parentElement; var svgEl = container.querySelector("svg");
      if (!svgEl) { alert("No chart found"); return; }
      var svgData = new XMLSerializer().serializeToString(svgEl);
      var canvas = document.createElement("canvas"); var ctx = canvas.getContext("2d"); var img = new Image();
      img.onload = function() { canvas.width = img.width * 2; canvas.height = img.height * 2; ctx.scale(2, 2); ctx.fillStyle = "white"; ctx.fillRect(0, 0, img.width, img.height); ctx.drawImage(img, 0, 0); ctx.font = "10px sans-serif"; ctx.fillStyle = "#94a3b8"; ctx.fillText("TURAS Pricing Report", 10, img.height - 8); var link = document.createElement("a"); link.download = "pricing_chart.png"; link.href = canvas.toDataURL("image/png"); link.click(); };
      img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgData)));
    }
  };
  '
}
