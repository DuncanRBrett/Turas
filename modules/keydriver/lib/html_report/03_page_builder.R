# ==============================================================================
# KEYDRIVER HTML REPORT - PAGE BUILDER
# ==============================================================================
# Assembles all components (tables, charts, CSS, JS) into a complete
# self-contained HTML page using htmltools.
# ==============================================================================

# Null-coalescing operator (existence guard)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}


#' Build Complete Keydriver HTML Page
#'
#' Assembles all report components into a single browsable HTML page.
#' The page is fully self-contained (CSS, JS, charts, tables inlined).
#' Sections that have no data are silently omitted.
#'
#' @param html_data Transformed data from transform_keydriver_for_html()
#' @param tables Named list of htmltools table objects
#' @param charts Named list of htmltools SVG chart objects
#' @param config Configuration list
#' @return htmltools::browsable tagList
#' @keywords internal
build_kd_html_page <- function(html_data, tables, charts, config) {

  brand_colour  <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"
  report_title  <- config$report_title %||% html_data$analysis_name %||%
    "Key Driver Analysis"

  # Build CSS
  css <- build_kd_css(config)

  # Build sections
  header_section <- build_kd_header(html_data, config)
  action_bar     <- build_kd_action_bar(report_title)
  nav            <- build_kd_nav(html_data)

  exec_summary_section  <- build_kd_exec_summary_section(html_data, config)
  importance_section    <- build_kd_importance_section(charts, tables, html_data)
  method_section        <- build_kd_method_section(charts, tables)
  effect_size_section   <- build_kd_effect_size_section(charts, tables,
                                                         html_data)
  correlation_section   <- build_kd_correlation_section(charts, tables)
  quadrant_section      <- build_kd_quadrant_section(charts, tables, html_data)
  shap_section          <- build_kd_shap_section(html_data)
  diagnostics_section   <- build_kd_diagnostics_section(tables, html_data)
  bootstrap_section     <- build_kd_bootstrap_section(charts, tables,
                                                       html_data)
  segment_section       <- build_kd_segment_section(tables, html_data)
  interpretation_section <- build_kd_interpretation_guide()
  pinned_section        <- build_kd_pinned_panel()
  footer_section        <- build_kd_footer(config)

  # Hidden pinned views data store
  pinned_store <- htmltools::tags$script(
    id = "kd-pinned-views-data",
    type = "application/json",
    "[]"
  )

  # Read JS files
  js_tags <- build_kd_js(.kd_html_report_dir)

  # Report Hub metadata
  source_filename <- basename(config$output_file %||%
                               config$report_title %||% "Keydriver_Report")
  hub_meta <- htmltools::tagList(
    htmltools::tags$meta(name = "turas-report-type", content = "keydriver"),
    htmltools::tags$meta(name = "turas-module-version", content = "1.0"),
    htmltools::tags$meta(name = "turas-source-filename", content = source_filename)
  )

  # Assemble page
  page <- htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "utf-8"),
      htmltools::tags$meta(
        name = "viewport",
        content = "width=device-width, initial-scale=1"
      ),
      htmltools::tags$title(report_title),
      hub_meta,
      htmltools::tags$style(htmltools::HTML(css))
    ),
    htmltools::tags$body(
      class = "kd-body",
      header_section,
      action_bar,
      nav,
      htmltools::tags$main(
        class = "kd-main",
        htmltools::tags$div(
          class = "kd-content",
          exec_summary_section,
          importance_section,
          method_section,
          effect_size_section,
          correlation_section,
          quadrant_section,
          shap_section,
          diagnostics_section,
          bootstrap_section,
          segment_section,
          interpretation_section,
          pinned_section,
          footer_section,
          pinned_store
        )
      ),
      js_tags
    )
  )

  htmltools::browsable(page)
}


# ==============================================================================
# CSS BUILDER
# ==============================================================================

#' Build Keydriver CSS
#'
#' Generates the complete stylesheet aligned with the shared Turas design system.
#' Uses CSS variables for brand consistency across modules.
#' All classes use kd- prefix for Report Hub namespace isolation.
#'
#' @param config Configuration list with brand_colour, accent_colour
#' @return Character string of CSS
#' @keywords internal
build_kd_css <- function(config) {

  brand_colour  <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"

  css <- '
/* ==== KEYDRIVER REPORT CSS ==== */
/* kd- namespace for Report Hub safety */
/* Aligned with shared Turas design system (tabs/tracker/catdriver) */

:root {
  /* Brand colours */
  --kd-brand: BRAND_COLOUR;
  --kd-accent: ACCENT_COLOUR;

  /* Shared Turas design tokens */
  --ct-brand: BRAND_COLOUR;
  --ct-accent: ACCENT_COLOUR;
  --ct-text-primary: #1e293b;
  --ct-text-secondary: #64748b;
  --ct-bg-surface: #ffffff;
  --ct-bg-muted: #f8f9fa;
  --ct-border: #e2e8f0;

  /* Module variables */
  --kd-text: #1e293b;
  --kd-text-muted: #64748b;
  --kd-text-faint: #94a3b8;
  --kd-bg: #f8f7f5;
  --kd-card: #ffffff;
  --kd-border: #e2e8f0;
  --kd-success: #059669;
  --kd-warning: #F59E0B;
  --kd-danger: #c0392b;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

.kd-body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background: var(--kd-bg);
  color: var(--kd-text);
  line-height: 1.5;
  font-size: 13px;
}

/* ================================================================ */
/* HORIZONTAL SECTION NAV BAR                                        */
/* Sticky below header, full-width, underline active indicator       */
/* ================================================================ */

.kd-section-nav {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--kd-card);
  border-bottom: 2px solid var(--kd-border);
  display: flex;
  align-items: center;
  gap: 0;
  padding: 0 24px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.kd-section-nav a {
  display: inline-flex;
  align-items: center;
  padding: 12px 20px;
  color: var(--kd-text-muted);
  text-decoration: none;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  border-bottom: 3px solid transparent;
  cursor: pointer;
  transition: all 0.15s ease;
}

.kd-section-nav a:hover {
  color: var(--kd-brand);
  background: #f8fafc;
}

.kd-section-nav a.active {
  color: var(--kd-brand);
  border-bottom-color: var(--kd-brand);
}

/* ================================================================ */
/* MAIN CONTENT                                                      */
/* ================================================================ */

.kd-main {
  min-width: 0;
}

.kd-content {
  max-width: 1100px;
  margin: 0 auto;
  padding: 24px 32px;
}

/* ================================================================ */
/* HEADER                                                            */
/* ================================================================ */

.kd-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
  padding: 24px 32px;
  border-bottom: 3px solid var(--kd-brand);
}

.kd-header-inner {
  max-width: 1100px;
  margin: 0 auto;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

.kd-header-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.kd-header-branding {
  display: flex;
  align-items: center;
  gap: 16px;
}

.kd-header-logo-container {
  width: 72px;
  height: 72px;
  border-radius: 12px;
  background: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.kd-header-logo-container img {
  height: 56px;
  width: 56px;
  object-fit: contain;
}

.kd-header-module-name {
  color: #ffffff;
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: -0.3px;
}

.kd-header-module-sub {
  color: rgba(255,255,255,0.50);
  font-size: 12px;
  font-weight: 400;
  margin-top: 2px;
}

.kd-header-title {
  color: #ffffff;
  font-size: 22px;
  font-weight: 700;
  letter-spacing: -0.3px;
  margin-top: 16px;
  line-height: 1.2;
}

.kd-header-prepared {
  color: rgba(255,255,255,0.65);
  font-size: 13px;
  font-weight: 400;
  margin-top: 4px;
  line-height: 1.3;
}

.kd-header-badges {
  display: inline-flex;
  align-items: center;
  margin-top: 12px;
  border: 1px solid rgba(255,255,255,0.15);
  border-radius: 6px;
  background: rgba(255,255,255,0.05);
}

.kd-header-badge {
  display: inline-flex;
  align-items: center;
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(255,255,255,0.85);
}

.kd-header-badge-val {
  color: rgba(255,255,255,1);
  font-weight: 700;
}

.kd-header-badge-sep {
  width: 1px;
  height: 16px;
  background: rgba(255,255,255,0.20);
  flex-shrink: 0;
}

/* ================================================================ */
/* SECTIONS (card style)                                             */
/* ================================================================ */

.kd-section {
  background: var(--kd-card);
  border: 1px solid var(--kd-border);
  border-radius: 8px;
  padding: 24px 28px;
  margin-bottom: 20px;
}

.kd-section-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--kd-brand);
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--kd-brand);
}

.kd-section-intro {
  color: var(--kd-text-muted);
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.5;
}

/* ================================================================ */
/* SECTION TITLE ROW — title + pin button in flex row                */
/* ================================================================ */

.kd-section-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--kd-brand);
}

.kd-section-title-row .kd-section-title {
  margin-bottom: 0;
  padding-bottom: 0;
  border-bottom: none;
}

/* ================================================================ */
/* PIN BUTTONS                                                       */
/* ================================================================ */

.kd-pin-btn {
  background: none;
  border: 1px solid var(--kd-border);
  border-radius: 6px;
  padding: 4px 10px;
  font-size: 14px;
  cursor: pointer;
  color: var(--kd-text-faint);
  transition: all 0.15s;
  flex-shrink: 0;
}

.kd-pin-btn:hover {
  border-color: var(--kd-brand);
  color: var(--kd-brand);
  background: rgba(50,51,103,0.03);
}

.kd-pin-btn.kd-pin-btn-active {
  background: var(--kd-brand);
  color: white;
  border-color: var(--kd-brand);
}

/* ================================================================ */
/* CHART/TABLE WRAPPERS                                              */
/* ================================================================ */

.kd-chart-wrapper,
.kd-table-wrapper {
  position: relative;
  margin-bottom: 8px;
}

.kd-component-pin {
  position: absolute;
  top: 4px;
  right: 4px;
  z-index: 10;
  background: rgba(255,255,255,0.85);
  border: 1px solid var(--kd-border);
  border-radius: 4px;
  padding: 2px 8px;
  font-size: 11px;
  font-weight: 500;
  color: var(--kd-text-faint);
  cursor: pointer;
  font-family: inherit;
  opacity: 0;
  transition: all 0.15s;
}

.kd-chart-wrapper:hover .kd-component-pin,
.kd-table-wrapper:hover .kd-component-pin {
  opacity: 1;
}

.kd-component-pin:hover {
  border-color: var(--kd-brand);
  color: var(--kd-brand);
  background: rgba(255,255,255,0.95);
}

.kd-component-pin.kd-pin-btn-active {
  background: var(--kd-brand);
  color: white;
  border-color: var(--kd-brand);
  opacity: 1;
}

/* ================================================================ */
/* TABLES                                                            */
/* ================================================================ */

.kd-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.kd-th {
  background: var(--ct-bg-muted);
  color: var(--kd-text-muted);
  font-weight: 600;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  padding: 8px 10px;
  text-align: left;
  border-bottom: 2px solid var(--kd-border);
  vertical-align: bottom;
  white-space: normal;
}

.kd-th-num, .kd-th-sig, .kd-th-effect, .kd-th-status { text-align: center; }
.kd-th-bar { text-align: left; min-width: 150px; }
.kd-th-rank { text-align: center; width: 50px; }

.kd-td {
  padding: 8px 12px;
  border-bottom: 1px solid #f0f0f0;
  vertical-align: middle;
  color: var(--kd-text);
  font-variant-numeric: tabular-nums;
  transition: background-color 0.15s;
}

.kd-td-num { text-align: center; font-variant-numeric: tabular-nums; }
.kd-td-rank { text-align: center; font-weight: 600; color: var(--kd-brand); }
.kd-td-sig { text-align: center; }
.kd-td-effect { text-align: center; }
.kd-td-status { text-align: center; }
.kd-td-interp { font-size: 12px; color: var(--kd-text-muted); }
.kd-td-label { font-weight: 500; }

.kd-tr:nth-child(even) { background: #f9fafb; }
.kd-tr:hover { background: #f8fafc; }

/* ================================================================ */
/* IMPORTANCE BARS                                                   */
/* ================================================================ */

.kd-bar-container {
  height: 16px;
  background: #f1f5f9;
  border-radius: 8px;
  overflow: hidden;
}

.kd-bar-fill {
  height: 100%;
  border-radius: 8px;
  transition: width 0.3s ease;
}

/* ================================================================ */
/* SIGNIFICANCE BADGES                                               */
/* ================================================================ */

.kd-sig-strong {
  color: var(--kd-success);
  font-weight: 700;
  font-size: 9px;
  font-family: ui-monospace, "Cascadia Code", Consolas, monospace;
  background: rgba(5,150,105,0.08);
  border-radius: 3px;
  padding: 0 4px;
  display: inline-block;
}

.kd-sig-moderate {
  color: #92400E;
  font-weight: 600;
  font-size: 9px;
  font-family: ui-monospace, "Cascadia Code", Consolas, monospace;
  background: rgba(146,64,14,0.08);
  border-radius: 3px;
  padding: 0 4px;
  display: inline-block;
}

.kd-sig-none {
  color: var(--kd-text-faint);
  font-size: 11px;
}

/* ================================================================ */
/* EFFECT COLOUR CLASSES                                             */
/* ================================================================ */

.kd-effect-pos { background: #D1FAE5; color: #065F46; border-radius: 4px; padding: 1px 6px; }
.kd-effect-neg { background: #FEE2E2; color: #991B1B; border-radius: 4px; padding: 1px 6px; }
.kd-effect-mod { background: #FEF3C7; color: #92400E; border-radius: 4px; padding: 1px 6px; }
.kd-effect-none { }

/* ================================================================ */
/* DIAGNOSTIC BADGES                                                 */
/* ================================================================ */

.kd-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
}

.kd-badge-pass { background: #D1FAE5; color: #065F46; }
.kd-badge-warn { background: #FEF3C7; color: #92400E; }
.kd-badge-fail { background: #FEE2E2; color: #991B1B; }

/* ================================================================ */
/* STATUS BADGES                                                     */
/* ================================================================ */

.kd-status-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.kd-status-pass { background: #D1FAE5; color: #065F46; }
.kd-status-partial { background: #FEF3C7; color: #92400E; }
.kd-status-refused { background: #FEE2E2; color: #991B1B; }

/* ================================================================ */
/* EXECUTIVE SUMMARY — callout cards with left border                */
/* ================================================================ */

.kd-callout {
  background: #f8fafa;
  border-left: 3px solid var(--kd-brand);
  padding: 12px 16px;
  border-radius: 0 6px 6px 0;
  margin-bottom: 10px;
}

.kd-callout-title {
  font-weight: 600;
  font-size: 14px;
  margin-bottom: 4px;
  color: var(--kd-text);
}

.kd-callout-text {
  font-size: 13px;
  color: var(--kd-text-muted);
}

.kd-model-confidence {
  padding: 12px 16px;
  border-radius: 6px;
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.5;
}

.kd-confidence-excellent { background: #D1FAE5; border-left: 4px solid var(--kd-success); }
.kd-confidence-good { background: #DBEAFE; border-left: 4px solid #2563EB; }
.kd-confidence-moderate { background: #FEF3C7; border-left: 4px solid var(--kd-warning); }
.kd-confidence-limited { background: #FEE2E2; border-left: 4px solid var(--kd-danger); }

/* ================================================================ */
/* FIT STATISTIC CARDS                                               */
/* ================================================================ */

.kd-fit-cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
  margin-top: 8px;
}

.kd-fit-card {
  background: #f8f9fa;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 12px 16px;
  border-left: 3px solid var(--kd-brand);
}

.kd-fit-card-value {
  font-size: 18px;
  font-weight: 700;
  color: #1e293b;
  font-variant-numeric: tabular-nums;
}

.kd-fit-card-label {
  font-size: 12px;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  margin-top: 2px;
}

.kd-fit-card-quality {
  font-size: 11px;
  font-weight: 600;
  color: var(--kd-brand);
  margin-top: 4px;
}

.kd-fit-card-note {
  font-size: 11px;
  color: #94a3b8;
  line-height: 1.4;
  margin-top: 6px;
}

/* ================================================================ */
/* CHARTS                                                            */
/* ================================================================ */

.kd-chart, .kd-importance-chart {
  width: 100%;
  max-width: 700px;
  height: auto;
  margin: 16px 0;
  display: block;
}

/* ================================================================ */
/* FILTER BAR — chip pills                                           */
/* ================================================================ */

.kd-or-chip-bar {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 14px;
}

.kd-or-chip {
  padding: 5px 12px;
  border: 1px solid var(--kd-border);
  border-radius: 20px;
  font-size: 12px;
  font-weight: 500;
  color: var(--kd-text-muted);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.kd-or-chip:hover {
  border-color: var(--kd-brand);
  color: var(--kd-brand);
}

.kd-or-chip.active {
  background: var(--kd-brand);
  color: white;
  border-color: var(--kd-brand);
}

/* ================================================================ */
/* KEY INSIGHTS                                                      */
/* ================================================================ */

.kd-key-insights-heading {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--kd-text);
}

.kd-key-insight-item {
  color: var(--kd-text);
  font-size: 13px;
  margin-bottom: 6px;
  line-height: 1.5;
}

.kd-finding-box {
  margin-bottom: 16px;
  padding: 14px 16px;
  background: var(--ct-bg-muted);
  border-radius: 6px;
}

.kd-finding-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-bottom: 6px;
}

.kd-finding-icon {
  font-size: 16px;
  font-weight: 700;
  flex-shrink: 0;
}

.kd-finding-text {
  font-size: 13px;
  color: var(--kd-text);
  line-height: 1.4;
}

.kd-top-drivers-label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 10px;
  color: var(--kd-text);
}

.kd-panel-heading-label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--kd-text);
}

/* ================================================================ */
/* INSIGHT EDITORS                                                   */
/* ================================================================ */

.kd-insight-area {
  margin-bottom: 12px;
}

.kd-insight-toggle {
  background: none;
  border: 1px dashed var(--kd-border);
  border-radius: 6px;
  padding: 6px 14px;
  font-size: 12px;
  font-weight: 500;
  color: var(--kd-text-muted);
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s;
}

.kd-insight-toggle:hover {
  border-color: var(--kd-brand);
  color: var(--kd-brand);
  background: rgba(50,51,103,0.03);
}

.kd-insight-container {
  display: none;
  margin-top: 8px;
  position: relative;
}

.kd-insight-editor {
  width: 100%;
  min-height: 60px;
  padding: 10px 14px;
  border: 1px solid var(--kd-border);
  border-radius: 6px;
  font-size: 13px;
  font-family: inherit;
  line-height: 1.5;
  color: var(--kd-text);
  outline: none;
  transition: border-color 0.15s;
}

.kd-insight-editor:focus {
  border-color: var(--kd-brand);
  box-shadow: 0 0 0 2px rgba(50,51,103,0.08);
}

.kd-insight-editor:empty::before {
  content: attr(data-placeholder);
  color: var(--kd-text-faint);
  pointer-events: none;
}

.kd-insight-dismiss {
  position: absolute;
  top: 4px;
  right: 4px;
  background: none;
  border: none;
  font-size: 14px;
  color: var(--kd-text-faint);
  cursor: pointer;
  padding: 2px 6px;
  border-radius: 4px;
  transition: all 0.15s;
}

.kd-insight-dismiss:hover {
  color: var(--kd-danger);
  background: rgba(192,57,43,0.06);
}

/* ================================================================ */
/* INTERPRETATION GUIDE — DO/DON T grid                              */
/* ================================================================ */

.kd-interp-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.kd-interp-list {
  font-size: 13px;
  color: var(--kd-text-muted);
  padding-left: 16px;
}

.kd-interp-list li { margin-bottom: 6px; line-height: 1.4; }

.kd-interp-note {
  margin-top: 16px;
  padding: 12px 16px;
  background: #f8fafa;
  border-radius: 6px;
  border-left: 3px solid var(--kd-brand);
  font-size: 12px;
  color: var(--kd-text-muted);
  line-height: 1.5;
}

/* ================================================================ */
/* PINNED VIEWS PANEL                                                */
/* ================================================================ */

.kd-pinned-panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}

.kd-pinned-panel-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--kd-brand);
}

.kd-pinned-panel-actions {
  display: flex;
  gap: 8px;
}

.kd-pinned-panel-btn {
  padding: 6px 14px;
  border: 1px solid var(--kd-border);
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  color: var(--kd-text-muted);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.kd-pinned-panel-btn:hover {
  border-color: var(--kd-brand);
  color: var(--kd-brand);
}

.kd-pinned-empty {
  text-align: center;
  padding: 48px 24px;
  color: var(--kd-text-faint);
  font-size: 14px;
}

.kd-pinned-empty-icon {
  font-size: 32px;
  margin-bottom: 8px;
  opacity: 0.4;
}

.kd-pinned-card {
  background: var(--kd-card);
  border: 1px solid var(--kd-border);
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 16px;
  transition: box-shadow 0.15s;
}

.kd-pinned-card:hover {
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}

.kd-pinned-card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 10px;
}

.kd-pinned-card-title {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.kd-pinned-card-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--kd-brand);
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.kd-pinned-card-section {
  font-size: 15px;
  font-weight: 600;
  color: var(--kd-text);
}

.kd-pinned-card-actions {
  display: flex;
  gap: 4px;
  flex-shrink: 0;
}

.kd-pinned-action-btn {
  background: none;
  border: 1px solid transparent;
  border-radius: 4px;
  padding: 3px 7px;
  font-size: 12px;
  cursor: pointer;
  color: var(--kd-text-faint);
  transition: all 0.15s;
}

.kd-pinned-action-btn:hover {
  border-color: var(--kd-border);
  color: var(--kd-text-muted);
  background: #f8f9fa;
}

.kd-pinned-remove-btn:hover {
  color: var(--kd-danger);
  background: rgba(192,57,43,0.06);
}

.kd-pinned-export-btn:hover {
  color: var(--kd-brand);
  background: rgba(50,51,103,0.04);
}

.kd-pinned-card-insight {
  padding: 10px 14px;
  border-left: 3px solid var(--kd-accent);
  background: #faf9f7;
  border-radius: 0 6px 6px 0;
  font-size: 13px;
  color: #475569;
  line-height: 1.5;
  margin-bottom: 10px;
}

.kd-pinned-card-chart {
  margin-top: 10px;
  overflow: visible;
}

.kd-pinned-card-chart svg {
  width: 100%;
  height: auto;
  display: block;
}

.kd-pinned-card-table {
  margin-top: 10px;
  overflow-x: auto;
  overflow-y: visible;
}

.kd-pinned-card-table table {
  width: 100%;
  font-size: 12px;
  table-layout: fixed;
}

.kd-pinned-card-table th,
.kd-pinned-card-table td {
  word-wrap: break-word;
  overflow-wrap: break-word;
}

/* ================================================================ */
/* SECTION DIVIDERS                                                  */
/* ================================================================ */

.kd-section-divider {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 0;
  margin: 8px 0;
  border-bottom: 2px solid var(--kd-brand);
}

.kd-section-divider-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--kd-brand);
  flex: 1;
  outline: none;
  min-width: 100px;
}

.kd-section-divider-title:focus {
  border-bottom: 1px dashed var(--kd-border);
}

.kd-section-divider-actions {
  display: flex;
  gap: 4px;
}

/* ================================================================ */
/* ACTION BAR — Save button strip                                    */
/* ================================================================ */

.kd-action-bar {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  padding: 8px 24px;
  background: var(--kd-card);
  border-bottom: 1px solid var(--kd-border);
}

.kd-save-btn {
  padding: 7px 18px;
  border: 1px solid var(--kd-brand);
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  color: var(--kd-brand);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.kd-save-btn:hover {
  background: var(--kd-brand);
  color: white;
}

.kd-saved-badge {
  display: none;
  font-size: 11px;
  color: var(--kd-text-faint);
  font-weight: 400;
}

/* ================================================================ */
/* FOOTER                                                            */
/* ================================================================ */

.kd-footer {
  text-align: center;
  padding: 24px;
  color: var(--kd-text-faint);
  font-size: 11px;
  border-top: 1px solid var(--kd-border);
  margin-top: 32px;
}

/* ================================================================ */
/* CORRELATION HEATMAP                                               */
/* ================================================================ */

.kd-corr-pos { background: #D1FAE5; }
.kd-corr-neg { background: #FEE2E2; }
.kd-corr-neutral { background: #f8f9fa; }

/* ================================================================ */
/* QUADRANT SECTION                                                  */
/* ================================================================ */

.kd-quadrant-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin: 12px 0;
  font-size: 12px;
  color: var(--kd-text-muted);
}

.kd-quadrant-legend-item {
  display: flex;
  align-items: center;
  gap: 4px;
}

.kd-quadrant-swatch {
  width: 14px;
  height: 14px;
  border-radius: 3px;
  border: 1px solid rgba(0,0,0,0.08);
}

/* ================================================================ */
/* DIAGNOSTICS TABLE                                                 */
/* ================================================================ */

.kd-diagnostics-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.kd-diagnostics-table td {
  padding: 8px 12px;
  border-bottom: 1px solid #f0f0f0;
}

/* ================================================================ */
/* PRINT STYLES                                                      */
/* ================================================================ */

@media print {
  .kd-section-nav { display: none !important; }
  .kd-content { padding: 16px !important; max-width: none !important; }
  .kd-body { background: white; font-size: 11px; }
  .kd-section { break-inside: avoid; page-break-inside: avoid; border: none; box-shadow: none; }
  .kd-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .kd-header-inner { max-width: none !important; }
  .kd-header-inner * { color: #1a2744 !important; }
  .kd-header-module-name { font-size: 16px !important; }
  .kd-header-title { font-size: 14px !important; margin-top: 4px !important; }
  .kd-header-logo-container { width: 32px !important; height: 32px !important; }
  .kd-header-logo-container img { width: 28px !important; height: 28px !important; }
  .kd-chart, .kd-importance-chart { max-width: 500px; }
  .kd-insight-area { display: none !important; }
  .kd-pin-btn { display: none !important; }
  .kd-component-pin { display: none !important; }
  .kd-or-chip-bar { display: none !important; }
  .kd-action-bar { display: none !important; }
  .kd-pinned-card-actions { display: none !important; }
}

@media (max-width: 768px) {
  .kd-section-nav { padding: 0 12px; }
  .kd-section-nav a { padding: 10px 14px; font-size: 12px; }
  .kd-content { padding: 16px; }
  .kd-interp-grid { grid-template-columns: 1fr; }
  .kd-header { padding: 16px; }
  .kd-header-module-name { font-size: 20px; }
  .kd-header-title { font-size: 18px; }
}
'
  css <- gsub("BRAND_COLOUR", brand_colour, css, fixed = TRUE)
  css <- gsub("ACCENT_COLOUR", accent_colour, css, fixed = TRUE)
  css
}


# ==============================================================================
# HEADER BUILDER
# ==============================================================================

#' Build Header Section
#'
#' Creates the gradient banner header matching tabs/tracker/catdriver design.
#' Includes logo, module name, project title, prepared-by text, and badge bar.
#'
#' @param html_data Transformed HTML data
#' @param config Configuration list
#' @return htmltools tag
#' @keywords internal
build_kd_header <- function(html_data, config) {

  brand_colour  <- config$brand_colour %||% "#323367"
  report_title  <- config$report_title %||% html_data$analysis_name %||%
    "Key Driver Analysis"
  model_info    <- html_data$model_info

  # --- Researcher Logo ---
  logo_el <- NULL
  logo_uri <- kd_resolve_logo_uri(config$researcher_logo_path)
  if (!is.null(logo_uri) && nzchar(logo_uri)) {
    logo_el <- htmltools::tags$div(
      class = "kd-header-logo-container",
      htmltools::tags$img(
        src = logo_uri, alt = "Logo",
        style = "height:56px;width:56px;object-fit:contain;"
      )
    )
  }

  # --- Client Logo ---
  client_logo_el <- NULL
  client_logo_uri <- kd_resolve_logo_uri(config$client_logo_path)
  if (!is.null(client_logo_uri) && nzchar(client_logo_uri)) {
    client_logo_el <- htmltools::tags$div(
      class = "kd-header-logo-container",
      style = "margin-left:auto;",
      htmltools::tags$img(
        src = client_logo_uri, alt = "Client Logo",
        style = "height:56px;width:56px;object-fit:contain;"
      )
    )
  }

  # --- Top row ---
  branding_left <- htmltools::tags$div(
    class = "kd-header-branding",
    logo_el,
    htmltools::tags$div(
      htmltools::tags$div(class = "kd-header-module-name", "Turas Keydriver"),
      htmltools::tags$div(class = "kd-header-module-sub",
                          "Key Driver Correlation Analysis")
    ),
    client_logo_el
  )

  top_row <- htmltools::tags$div(class = "kd-header-top", branding_left)

  # --- Project title ---
  title_row <- htmltools::tags$div(class = "kd-header-title", report_title)

  # --- Prepared by / for text ---
  prepared_row <- NULL
  company_name    <- config$company_name %||% "The Research Lamppost"
  client_name     <- config$client_name %||% NULL
  researcher_name <- config$researcher_name %||% NULL
  prepared_parts  <- c()

  if (!is.null(company_name) && nzchar(company_name)) {
    if (!is.null(researcher_name) && nzchar(researcher_name)) {
      prepared_parts <- c(prepared_parts, sprintf(
        'Prepared by <span style="font-weight:600;">%s</span> (%s)',
        htmltools::htmlEscape(researcher_name),
        htmltools::htmlEscape(company_name)
      ))
    } else {
      prepared_parts <- c(prepared_parts, sprintf(
        'Prepared by <span style="font-weight:600;">%s</span>',
        htmltools::htmlEscape(company_name)
      ))
    }
  }
  if (!is.null(client_name) && nzchar(client_name)) {
    prepared_parts <- c(prepared_parts, sprintf(
      'for <span style="font-weight:600;">%s</span>',
      htmltools::htmlEscape(client_name)
    ))
  }
  if (length(prepared_parts) > 0) {
    prepared_row <- htmltools::tags$div(
      class = "kd-header-prepared",
      htmltools::HTML(paste(prepared_parts, collapse = " "))
    )
  }

  # --- Badge bar ---
  badge_items <- list()

  # R-squared
  r2 <- model_info$r_squared
  if (!is.null(r2) && !is.na(r2)) {
    badge_items <- c(badge_items, list(htmltools::tags$span(
      class = "kd-header-badge",
      htmltools::HTML(sprintf(
        'R\u00B2&nbsp;=&nbsp;<span class="kd-header-badge-val">%.3f</span>', r2
      ))
    )))
  }

  # Sample size
  n_obs <- model_info$n_obs
  if (!is.null(n_obs) && !is.na(n_obs)) {
    badge_items <- c(badge_items, list(htmltools::tags$span(
      class = "kd-header-badge",
      htmltools::HTML(sprintf(
        'n&nbsp;=&nbsp;<span class="kd-header-badge-val">%s</span>',
        format(n_obs, big.mark = ",")
      ))
    )))
  }

  # Drivers count
  n_drv <- model_info$n_drivers %||% html_data$n_drivers
  if (!is.null(n_drv) && !is.na(n_drv)) {
    badge_items <- c(badge_items, list(htmltools::tags$span(
      class = "kd-header-badge",
      htmltools::HTML(sprintf(
        '<span class="kd-header-badge-val">%d</span>&nbsp;Drivers', n_drv
      ))
    )))
  }

  # Methods count
  n_methods <- length(html_data$methods_available)
  if (n_methods > 0) {
    badge_items <- c(badge_items, list(htmltools::tags$span(
      class = "kd-header-badge",
      htmltools::HTML(sprintf(
        '<span class="kd-header-badge-val">%d</span>&nbsp;Methods', n_methods
      ))
    )))
  }

  # Date
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "kd-header-badge", format(Sys.Date(), "Created %b %Y")
  )))

  # Interleave with separators
  badge_els <- list()
  for (i in seq_along(badge_items)) {
    if (i > 1) {
      badge_els <- c(badge_els,
        list(htmltools::tags$span(class = "kd-header-badge-sep")))
    }
    badge_els <- c(badge_els, list(badge_items[[i]]))
  }

  badges_bar <- htmltools::tags$div(class = "kd-header-badges", badge_els)

  # --- Assemble ---
  htmltools::tags$div(
    class = "kd-header", id = "kd-header",
    htmltools::tags$div(
      class = "kd-header-inner",
      top_row, title_row, prepared_row, badges_bar
    )
  )
}


# ==============================================================================
# NAVIGATION BAR
# ==============================================================================

#' Build Horizontal Section Navigation Bar
#'
#' Creates a sticky horizontal nav bar with section links.
#' Conditionally includes tabs for optional sections.
#'
#' @param html_data Transformed HTML data (used to detect optional sections)
#' @return htmltools tag
#' @keywords internal
build_kd_nav <- function(html_data) {

  has_effect_sizes <- !is.null(html_data$effect_sizes)
  has_quadrant     <- isTRUE(html_data$has_quadrant)
  has_shap         <- isTRUE(html_data$has_shap)
  has_bootstrap    <- isTRUE(html_data$has_bootstrap)
  has_segments     <- !is.null(html_data$segment_comparison)

  links <- list(
    htmltools::tags$a(href = "#kd-exec-summary", "Summary", class = "active"),
    htmltools::tags$a(href = "#kd-importance", "Importance"),
    htmltools::tags$a(href = "#kd-method-comparison", "Methods")
  )

  if (has_effect_sizes) {
    links <- c(links, list(
      htmltools::tags$a(href = "#kd-effect-sizes", "Effect Sizes")))
  }

  links <- c(links, list(
    htmltools::tags$a(href = "#kd-correlations", "Correlations")))

  if (has_quadrant) {
    links <- c(links, list(
      htmltools::tags$a(href = "#kd-quadrant", "Quadrant")))
  }
  if (has_shap) {
    links <- c(links, list(
      htmltools::tags$a(href = "#kd-shap-summary", "SHAP")))
  }

  links <- c(links, list(
    htmltools::tags$a(href = "#kd-diagnostics", "Diagnostics")))

  if (has_bootstrap) {
    links <- c(links, list(
      htmltools::tags$a(href = "#kd-bootstrap-ci", "Bootstrap")))
  }
  if (has_segments) {
    links <- c(links, list(
      htmltools::tags$a(href = "#kd-segment-comparison", "Segments")))
  }

  links <- c(links, list(
    htmltools::tags$a(href = "#kd-interpretation", "Guide"),
    htmltools::tags$a(href = "#kd-pinned-section", "Pinned Views")
  ))

  htmltools::tags$nav(
    class = "kd-section-nav", id = "kd-section-nav", links
  )
}


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
        sprintf("%.1f%% relative importance", d$pct)
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
        icon   <- if (identical(f$direction, "positive")) "\u2191" else "\u2193"
        colour <- if (identical(f$direction, "positive")) {
          "var(--kd-success)"
        } else {
          "var(--kd-danger)"
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
  insight_area <- build_kd_insight_area("exec-summary")

  htmltools::tags$div(
    class = "kd-section", id = "kd-exec-summary",
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
build_kd_importance_section <- function(charts, tables, html_data) {

  n_drivers <- html_data$n_drivers %||% 0

  title_row    <- build_kd_section_title_row("Driver Importance", "importance")
  insight_area <- build_kd_insight_area("importance")

  # Filter bar for many drivers
  filter_bar <- NULL
  if (n_drivers > 5) {
    filter_bar <- build_kd_importance_filter_bar(n_drivers)
  }

  chart_wrapper <- if (!is.null(charts$importance)) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      build_kd_component_pin_btn("importance", "chart"),
      charts$importance
    )
  }

  table_wrapper <- if (!is.null(tables$importance)) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      build_kd_component_pin_btn("importance", "table"),
      filter_bar,
      tables$importance
    )
  }

  htmltools::tags$div(
    class = "kd-section", id = "kd-importance",
    `data-kd-section` = "importance",
    title_row, insight_area,
    htmltools::tags$p(
      class = "kd-section-intro",
      "Relative importance of each driver in explaining the outcome. Higher percentage means stronger relationship with the dependent variable."
    ),
    chart_wrapper, table_wrapper
  )
}


#' Build Importance Filter Bar
#'
#' Threshold chip options: All | Top 3 | Top 5 | Top 8 | Significant.
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
  options <- c(options, list(list(label = "Significant", mode = "significant")))

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
build_kd_method_section <- function(charts, tables) {

  title_row    <- build_kd_section_title_row("Method Comparison",
                                              "method-comparison")
  insight_area <- build_kd_insight_area("method-comparison")

  chart_wrapper <- if (!is.null(charts$method_agreement)) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      build_kd_component_pin_btn("method-comparison", "chart"),
      charts$method_agreement
    )
  }

  table_wrapper <- if (!is.null(tables$method_comparison)) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      build_kd_component_pin_btn("method-comparison", "table"),
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
build_kd_effect_size_section <- function(charts, tables, html_data) {

  if (is.null(html_data$effect_sizes)) return(NULL)

  title_row    <- build_kd_section_title_row("Effect Sizes", "effect-sizes")
  insight_area <- build_kd_insight_area("effect-sizes")

  chart_wrapper <- if (!is.null(charts$effect_sizes)) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      build_kd_component_pin_btn("effect-sizes", "chart"),
      charts$effect_sizes
    )
  }

  table_wrapper <- if (!is.null(tables$effect_sizes)) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      build_kd_component_pin_btn("effect-sizes", "table"),
      tables$effect_sizes
    )
  }

  htmltools::tags$div(
    class = "kd-section", id = "kd-effect-sizes",
    `data-kd-section` = "effect-sizes",
    title_row, insight_area,
    htmltools::tags$p(
      class = "kd-section-intro",
      "Standardised effect sizes provide a scale-free measure of each driver's practical impact. Larger absolute values indicate stronger practical significance."
    ),
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
build_kd_correlation_section <- function(charts, tables) {

  title_row    <- build_kd_section_title_row("Correlation Matrix", "correlations")
  insight_area <- build_kd_insight_area("correlations")

  chart_wrapper <- if (!is.null(charts$correlation_heatmap)) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      build_kd_component_pin_btn("correlations", "chart"),
      charts$correlation_heatmap
    )
  }

  table_wrapper <- if (!is.null(tables$correlations)) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      build_kd_component_pin_btn("correlations", "table"),
      tables$correlations
    )
  }

  htmltools::tags$div(
    class = "kd-section", id = "kd-correlations",
    `data-kd-section` = "correlations",
    title_row, insight_area,
    htmltools::tags$p(
      class = "kd-section-intro",
      "Bivariate correlations between all drivers and the outcome. High inter-driver correlations may indicate multicollinearity. See VIF diagnostics for formal assessment."
    ),
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
build_kd_quadrant_section <- function(charts, tables, html_data) {

  if (!isTRUE(html_data$has_quadrant)) return(NULL)

  title_row    <- build_kd_section_title_row("Importance-Performance Quadrant",
                                              "quadrant")
  insight_area <- build_kd_insight_area("quadrant")

  chart_wrapper <- if (!is.null(charts$quadrant)) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      build_kd_component_pin_btn("quadrant", "chart"),
      charts$quadrant
    )
  }

  table_wrapper <- if (!is.null(tables$quadrant_actions)) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      build_kd_component_pin_btn("quadrant", "table"),
      tables$quadrant_actions
    )
  }

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
    chart_wrapper, table_wrapper
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
build_kd_shap_section <- function(html_data) {

  if (!isTRUE(html_data$has_shap)) return(NULL)

  title_row    <- build_kd_section_title_row("SHAP Importance", "shap-summary")
  insight_area <- build_kd_insight_area("shap-summary")

  shap_note <- htmltools::tags$div(
    class = "kd-callout",
    htmltools::tags$div(class = "kd-callout-title",
                        "SHAP (SHapley Additive exPlanations)"),
    htmltools::tags$div(
      class = "kd-callout-text",
      paste0(
        "SHAP values provide a game-theoretic approach to feature importance. ",
        "They decompose each prediction into additive contributions from each ",
        "driver, accounting for interactions between variables. SHAP importance ",
        "is included in the main importance ranking and method comparison above."
      )
    )
  )

  method_note <- htmltools::tags$p(
    class = "kd-section-intro",
    style = "margin-top:12px;font-size:11px;font-style:italic;",
    paste0(
      "SHAP values are computed using the shapr package. The values represent ",
      "the mean absolute SHAP contribution of each driver across all observations."
    )
  )

  htmltools::tags$div(
    class = "kd-section", id = "kd-shap-summary",
    `data-kd-section` = "shap-summary",
    title_row, insight_area,
    htmltools::tags$p(
      class = "kd-section-intro",
      paste0(
        "SHAP-based feature importance was computed for this analysis. SHAP ",
        "values are reflected in the importance rankings and method comparison ",
        "sections above."
      )
    ),
    shap_note, method_note
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
build_kd_diagnostics_section <- function(tables, html_data) {

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
  insight_area <- build_kd_insight_area("diagnostics")

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

  htmltools::tags$div(
    class = "kd-section", id = "kd-diagnostics",
    `data-kd-section` = "diagnostics",
    title_row, insight_area,
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
build_kd_bootstrap_section <- function(charts, tables, html_data) {

  if (!isTRUE(html_data$has_bootstrap)) return(NULL)

  title_row    <- build_kd_section_title_row("Bootstrap Confidence Intervals",
                                              "bootstrap-ci")
  insight_area <- build_kd_insight_area("bootstrap-ci")

  chart_wrapper <- if (!is.null(charts$bootstrap_ci)) {
    htmltools::tags$div(
      class = "kd-chart-wrapper",
      build_kd_component_pin_btn("bootstrap-ci", "chart"),
      charts$bootstrap_ci
    )
  }

  table_wrapper <- if (!is.null(tables$bootstrap_ci)) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      build_kd_component_pin_btn("bootstrap-ci", "table"),
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
build_kd_segment_section <- function(tables, html_data) {

  if (is.null(html_data$segment_comparison)) return(NULL)

  title_row    <- build_kd_section_title_row("Segment Comparison",
                                              "segment-comparison")
  insight_area <- build_kd_insight_area("segment-comparison")

  table_wrapper <- if (!is.null(tables$segment_comparison)) {
    htmltools::tags$div(
      class = "kd-table-wrapper",
      build_kd_component_pin_btn("segment-comparison", "table"),
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
        "Driver importance compared across segments. Large rank differences ",
        "suggest that different segments are motivated by different factors."
      )
    ),
    table_wrapper
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
build_kd_pinned_panel <- function() {
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
      htmltools::tags$div("No pinned views yet."),
      htmltools::tags$div(
        style = "font-size:12px;margin-top:4px;",
        "Click the pin icon on any section to save it here for export."
      )
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
# ACTION BAR
# ==============================================================================

#' Build Action Bar
#'
#' Creates the save button strip.
#'
#' @param report_title Title for filename generation
#' @return htmltools tag
#' @keywords internal
build_kd_action_bar <- function(report_title = "Keydriver Report") {
  htmltools::tags$div(
    class = "kd-action-bar",
    htmltools::tags$span(
      class = "kd-saved-badge", id = "kd-saved-badge"
    ),
    htmltools::tags$button(
      class = "kd-save-btn",
      onclick = "kdSaveReportHTML()",
      "\U0001F4BE Save Report"
    )
  )
}


# ==============================================================================
# JAVASCRIPT INLINER
# ==============================================================================

#' Read and Inline JS Files
#'
#' Reads all required JS files from the js/ subdirectory and returns
#' them as inline script tags.
#'
#' @param html_report_dir Path to the html_report directory
#' @return htmltools tagList of script tags
#' @keywords internal
build_kd_js <- function(html_report_dir) {
  js_files <- c("kd_utils.js", "kd_navigation.js",
                 "kd_pinned_views.js", "kd_slide_export.js")

  js_tags <- lapply(js_files, function(fname) {
    js_path <- file.path(html_report_dir, "js", fname)
    js_content <- if (file.exists(js_path)) {
      paste(readLines(js_path, warn = FALSE), collapse = "\n")
    } else {
      cat(sprintf("    [WARN] JS file not found: %s\n", js_path))
      sprintf("/* %s not found */", fname)
    }
    htmltools::tags$script(htmltools::HTML(js_content))
  })

  htmltools::tagList(js_tags)
}


# ==============================================================================
# SECTION TITLE ROW — title + pin button
# ==============================================================================

#' Build Section Title Row
#'
#' Wraps a section title and pin button in a flex row.
#'
#' @param title Title text
#' @param section_key Section key for pinning
#' @param prefix ID prefix (default empty string)
#' @param show_pin Whether to show the pin button
#' @return htmltools tag
#' @keywords internal
build_kd_section_title_row <- function(title, section_key, prefix = "",
                                        show_pin = TRUE) {
  pin_btn <- if (show_pin) {
    htmltools::tags$button(
      class = "kd-pin-btn",
      `data-kd-pin-section` = section_key,
      `data-kd-pin-prefix` = prefix,
      onclick = sprintf("kdPinSection('%s','%s')", section_key, prefix),
      title = "Pin this section",
      "\U0001F4CC"
    )
  }

  htmltools::tags$div(
    class = "kd-section-title-row",
    htmltools::tags$h2(class = "kd-section-title", title),
    pin_btn
  )
}


# ==============================================================================
# COMPONENT PIN BUTTON
# ==============================================================================

#' Build Component Pin Button
#'
#' Small ghost-style pin button for individual chart/table pinning.
#'
#' @param section_key Section key (e.g., "importance", "correlations")
#' @param component Component type: "chart" or "table"
#' @param prefix ID prefix (default empty string)
#' @return htmltools tag
#' @keywords internal
build_kd_component_pin_btn <- function(section_key, component, prefix = "") {
  label <- if (component == "chart") "\U0001F4CC Chart" else "\U0001F4CC Table"
  htmltools::tags$button(
    class = "kd-component-pin",
    `data-kd-pin-section` = section_key,
    `data-kd-pin-prefix` = prefix,
    `data-kd-pin-component` = component,
    onclick = sprintf("kdPinComponent('%s','%s','%s')",
                      section_key, component, prefix),
    title = sprintf("Pin %s only", component),
    label
  )
}


# ==============================================================================
# INSIGHT AREA
# ==============================================================================

#' Build Insight Area
#'
#' Creates the editable insight area: toggle button + hidden editor.
#'
#' @param section_key Section key string (e.g., "exec-summary", "importance")
#' @param prefix ID prefix (default empty string)
#' @return htmltools tagList
#' @keywords internal
build_kd_insight_area <- function(section_key, prefix = "") {
  htmltools::tags$div(
    class = "kd-insight-area",
    `data-kd-insight-section` = section_key,
    `data-kd-insight-prefix` = prefix,
    htmltools::tags$button(
      class = "kd-insight-toggle",
      id = paste0(prefix, "kd-insight-toggle-", section_key),
      onclick = sprintf("kdToggleInsight('%s','%s')", section_key, prefix),
      "+ Add Insight"
    ),
    htmltools::tags$div(
      class = "kd-insight-container",
      id = paste0(prefix, "kd-insight-container-", section_key),
      htmltools::tags$div(
        class = "kd-insight-editor",
        contenteditable = "true",
        `data-placeholder` = "Type your insight or comment here...",
        oninput = sprintf("kdSyncInsight('%s','%s')", section_key, prefix)
      ),
      htmltools::tags$button(
        class = "kd-insight-dismiss",
        onclick = sprintf("kdDismissInsight('%s','%s')", section_key, prefix),
        "\u00D7"
      )
    )
  )
}


# ==============================================================================
# INSIGHT CALLOUT CARD
# ==============================================================================

#' Build Insight Callout Card
#'
#' An insight callout with left brand border.
#'
#' @param text Insight text
#' @return htmltools tag
#' @keywords internal
build_kd_insight_card <- function(text) {
  htmltools::tags$div(
    class = "kd-callout",
    htmltools::tags$div(class = "kd-callout-text", text)
  )
}


# ==============================================================================
# LOGO URI RESOLVER
# ==============================================================================

#' Resolve Logo URI
#'
#' Converts a file path to a base64 data URI for self-contained HTML.
#' Accepts NULL, file paths, or already-formed data: URIs.
#'
#' @param logo_path File path or URI string
#' @return Character data URI or NULL
#' @keywords internal
kd_resolve_logo_uri <- function(logo_path) {
  if (is.null(logo_path) || !nzchar(logo_path %||% "")) return(NULL)

  # Already a URI
  if (grepl("^(data:|https?://)", logo_path)) return(logo_path)

  # File path -- convert to base64
  if (!file.exists(logo_path)) return(NULL)

  if (!requireNamespace("base64enc", quietly = TRUE)) {
    cat("[WARN] base64enc package required for logo embedding. Install with: install.packages('base64enc')\n")
    return(NULL)
  }

  ext <- tolower(tools::file_ext(logo_path))
  mime_type <- switch(ext,
    png = "image/png",
    jpg = , jpeg = "image/jpeg",
    svg = "image/svg+xml",
    gif = "image/gif",
    "image/png"
  )

  tryCatch({
    base64enc::dataURI(file = logo_path, mime = mime_type)
  }, error = function(e) {
    cat(sprintf("[WARN] Failed to encode logo '%s': %s\n",
                logo_path, e$message))
    NULL
  })
}
