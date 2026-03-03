# ==============================================================================
# CATDRIVER HTML REPORT - PAGE BUILDER
# ==============================================================================
# Assembles all components into a self-contained HTML page.
# All IDs and classes use cd- prefix for Report Hub namespace safety.
# Design: aligned with Turas shared design system (tabs/tracker modules).
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

  brand_colour <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"
  report_title <- config$report_title %||% html_data$analysis_name

  # Build CSS
  css <- build_cd_css(brand_colour, accent_colour)

  # Build sections
  header_section <- build_cd_header(html_data, config, brand_colour, report_title)
  exec_summary_section <- build_cd_exec_summary(html_data, brand_colour)
  importance_section <- build_cd_importance_section(tables, charts, brand_colour)
  patterns_section <- build_cd_patterns_section(html_data, tables)
  or_section <- build_cd_or_section(tables, charts, html_data$has_bootstrap,
                                     odds_ratios = html_data$odds_ratios)
  diagnostics_section <- build_cd_diagnostics_section(tables, html_data)
  interpretation_section <- build_cd_interpretation_section(brand_colour)
  footer_section <- build_cd_footer()

  # Horizontal section nav bar
  nav <- build_cd_section_nav(brand_colour)

  # Action bar (save button)
  action_bar <- build_cd_action_bar(report_title)

  # Hidden insight store (single report mode — no prefix)
  insight_store <- htmltools::tags$textarea(
    class = "cd-insight-store",
    id = "cd-insight-store",
    `data-cd-prefix` = "",
    style = "display:none;",
    "{}"
  )

  # Hidden pinned views data store
  pinned_store <- htmltools::tags$script(
    id = "cd-pinned-views-data",
    type = "application/json",
    "[]"
  )

  # Read JS files
  js_files <- c("cd_utils.js", "cd_navigation.js", "cd_insights.js",
                 "cd_pinned_views.js", "cd_slide_export.js")
  js_tags <- lapply(js_files, function(fname) {
    js_path <- file.path(.cd_html_report_dir, "js", fname)
    js_content <- if (file.exists(js_path)) {
      paste(readLines(js_path, warn = FALSE), collapse = "\n")
    } else {
      sprintf("/* %s not found */", fname)
    }
    htmltools::tags$script(htmltools::HTML(js_content))
  })

  # Report Hub metadata
  source_filename <- basename(config$output_file %||%
                               config$report_title %||% "Catdriver_Report")
  hub_meta <- htmltools::tagList(
    htmltools::tags$meta(name = "turas-report-type", content = "catdriver"),
    htmltools::tags$meta(name = "turas-module-version", content = "1.1"),
    htmltools::tags$meta(name = "turas-source-filename", content = source_filename)
  )

  # Assemble page — linear layout (no sidebar)
  # Header → action bar → sticky nav bar → content → footer
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
      header_section,
      action_bar,
      nav,
      htmltools::tags$main(
        class = "cd-main",
        htmltools::tags$div(
          class = "cd-content",
          exec_summary_section,
          importance_section,
          patterns_section,
          or_section,
          diagnostics_section,
          interpretation_section,
          footer_section,
          insight_store,
          pinned_store
        )
      ),
      js_tags
    )
  )

  htmltools::browsable(page)
}


#' Build Catdriver CSS
#'
#' Generates the complete stylesheet aligned with the shared Turas design system.
#' Uses CSS variables for brand consistency across modules.
#'
#' @param brand_colour Brand colour hex string
#' @param accent_colour Accent colour hex string
#' @return Character string of CSS
#' @keywords internal
build_cd_css <- function(brand_colour, accent_colour) {
  css <- '
/* ==== CATDRIVER REPORT CSS ==== */
/* cd- namespace for Report Hub safety */
/* Aligned with shared Turas design system (tabs/tracker) */

:root {
  /* Brand colours */
  --cd-brand: BRAND_COLOUR;
  --cd-accent: ACCENT_COLOUR;

  /* Shared Turas design tokens */
  --ct-brand: BRAND_COLOUR;
  --ct-accent: ACCENT_COLOUR;
  --ct-text-primary: #1e293b;
  --ct-text-secondary: #64748b;
  --ct-bg-surface: #ffffff;
  --ct-bg-muted: #f8f9fa;
  --ct-border: #e2e8f0;

  /* Module variables */
  --cd-text: #1e293b;
  --cd-text-muted: #64748b;
  --cd-text-faint: #94a3b8;
  --cd-bg: #f8f7f5;
  --cd-card: #ffffff;
  --cd-border: #e2e8f0;
  --cd-success: #059669;
  --cd-warning: #F59E0B;
  --cd-danger: #c0392b;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

.cd-body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background: var(--cd-bg);
  color: var(--cd-text);
  line-height: 1.5;
  font-size: 13px;
}

/* ================================================================ */
/* HORIZONTAL SECTION NAV BAR — matches tabs/tracker .report-tabs   */
/* Sticky below header, full-width, underline active indicator      */
/* ================================================================ */

.cd-section-nav {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--cd-card);
  border-bottom: 2px solid var(--cd-border);
  display: flex;
  align-items: center;
  gap: 0;
  padding: 0 24px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.cd-section-nav a {
  display: inline-flex;
  align-items: center;
  padding: 12px 20px;
  color: var(--cd-text-muted);
  text-decoration: none;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  border-bottom: 3px solid transparent;
  cursor: pointer;
  transition: all 0.15s ease;
}

.cd-section-nav a:hover {
  color: var(--cd-brand);
  background: #f8fafc;
}

.cd-section-nav a.active {
  color: var(--cd-brand);
  border-bottom-color: var(--cd-brand);
}

/* ================================================================ */
/* MAIN CONTENT — full-width, no sidebar offset                     */
/* ================================================================ */

.cd-main {
  min-width: 0;
}

.cd-content {
  max-width: 1100px;
  margin: 0 auto;
  padding: 24px 32px;
}

/* ================================================================ */
/* HEADER — matches tabs/tracker gradient banner with logo + badges */
/* ================================================================ */

.cd-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
  padding: 24px 32px;
  border-bottom: 3px solid var(--cd-brand);
}

.cd-header-inner {
  max-width: 1100px;
  margin: 0 auto;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

.cd-header-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.cd-header-branding {
  display: flex;
  align-items: center;
  gap: 16px;
}

.cd-header-logo-container {
  width: 72px;
  height: 72px;
  border-radius: 12px;
  background: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.cd-header-logo-container img {
  height: 56px;
  width: 56px;
  object-fit: contain;
}

.cd-header-module-name {
  color: #ffffff;
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: -0.3px;
}

.cd-header-module-sub {
  color: rgba(255,255,255,0.50);
  font-size: 12px;
  font-weight: 400;
  margin-top: 2px;
}

.cd-header-title {
  color: #ffffff;
  font-size: 22px;
  font-weight: 700;
  letter-spacing: -0.3px;
  margin-top: 16px;
  line-height: 1.2;
}

.cd-header-prepared {
  color: rgba(255,255,255,0.65);
  font-size: 13px;
  font-weight: 400;
  margin-top: 4px;
  line-height: 1.3;
}

.cd-header-badges {
  display: inline-flex;
  align-items: center;
  margin-top: 12px;
  border: 1px solid rgba(255,255,255,0.15);
  border-radius: 6px;
  background: rgba(255,255,255,0.05);
}

.cd-header-badge {
  display: inline-flex;
  align-items: center;
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(255,255,255,0.85);
}

.cd-header-badge-val {
  color: rgba(255,255,255,1);
  font-weight: 700;
}

.cd-header-badge-sep {
  width: 1px;
  height: 16px;
  background: rgba(255,255,255,0.20);
  flex-shrink: 0;
}

/* ================================================================ */
/* SECTIONS (card style)                                            */
/* ================================================================ */

.cd-section {
  background: var(--cd-card);
  border: 1px solid var(--cd-border);
  border-radius: 8px;
  padding: 24px 28px;
  margin-bottom: 20px;
}

.cd-section-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--cd-brand);
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--cd-brand);
}

.cd-section-intro {
  color: var(--cd-text-muted);
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.5;
}

/* ================================================================ */
/* STATUS BADGES                                                    */
/* ================================================================ */

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

/* ================================================================ */
/* TABLES — matches tabs/tracker ct-th/ct-td pattern                */
/* ================================================================ */

.cd-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.cd-th {
  background: var(--ct-bg-muted);
  color: var(--cd-text-muted);
  font-weight: 600;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  padding: 8px 10px;
  text-align: left;
  border-bottom: 2px solid var(--cd-border);
  vertical-align: bottom;
  white-space: normal;
}

.cd-th-num, .cd-th-sig, .cd-th-effect, .cd-th-status { text-align: center; }
.cd-th-bar { text-align: left; min-width: 150px; }
.cd-th-rank { text-align: center; width: 50px; }

.cd-td {
  padding: 8px 12px;
  border-bottom: 1px solid #f0f0f0;
  vertical-align: middle;
  color: var(--cd-text);
  transition: background-color 0.15s;
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

/* ================================================================ */
/* IMPORTANCE BARS                                                  */
/* ================================================================ */

.cd-bar-container {
  height: 16px;
  background: #f1f5f9;
  border-radius: 8px;
  overflow: hidden;
}

.cd-bar-fill {
  height: 100%;
  border-radius: 8px;
  transition: width 0.3s ease;
}

/* ================================================================ */
/* SIGNIFICANCE — matches tabs/tracker sig badge style              */
/* ================================================================ */

.cd-sig-strong {
  color: var(--cd-success);
  font-weight: 700;
  font-size: 9px;
  font-family: ui-monospace, "Cascadia Code", Consolas, monospace;
  background: rgba(5,150,105,0.08);
  border-radius: 3px;
  padding: 0 4px;
  display: inline-block;
}

.cd-sig-moderate {
  color: #92400E;
  font-weight: 600;
  font-size: 9px;
  font-family: ui-monospace, "Cascadia Code", Consolas, monospace;
  background: rgba(146,64,14,0.08);
  border-radius: 3px;
  padding: 0 4px;
  display: inline-block;
}

.cd-sig-none {
  color: var(--cd-text-faint);
  font-size: 11px;
}

/* ================================================================ */
/* EFFECT COLOUR CLASSES                                            */
/* ================================================================ */

.cd-effect-pos { background: #D1FAE5; color: #065F46; border-radius: 4px; padding: 1px 6px; }
.cd-effect-neg { background: #FEE2E2; color: #991B1B; border-radius: 4px; padding: 1px 6px; }
.cd-effect-mod { background: #FEF3C7; color: #92400E; border-radius: 4px; padding: 1px 6px; }
.cd-effect-none { }

/* ================================================================ */
/* DIAGNOSTIC BADGES                                                */
/* ================================================================ */

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

/* ================================================================ */
/* EXECUTIVE SUMMARY — callout cards with left border               */
/* ================================================================ */

.cd-callout {
  background: #f8fafa;
  border-left: 3px solid var(--cd-brand);
  padding: 12px 16px;
  border-radius: 0 6px 6px 0;
  margin-bottom: 10px;
}

.cd-callout-title {
  font-weight: 600;
  font-size: 14px;
  margin-bottom: 4px;
  color: var(--cd-text);
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
  line-height: 1.5;
}

.cd-confidence-excellent { background: #D1FAE5; border-left: 4px solid var(--cd-success); }
.cd-confidence-good { background: #DBEAFE; border-left: 4px solid #2563EB; }
.cd-confidence-moderate { background: #FEF3C7; border-left: 4px solid var(--cd-warning); }
.cd-confidence-limited { background: #FEE2E2; border-left: 4px solid var(--cd-danger); }

/* ================================================================ */
/* CHARTS                                                           */
/* ================================================================ */

.cd-chart { width: 100%; max-width: 700px; height: auto; margin: 16px 0; }

/* ================================================================ */
/* FACTOR PICKER — pill tabs                                        */
/* ================================================================ */

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

/* ================================================================ */
/* INTERPRETATION GUIDE — DO/DON T grid                             */
/* ================================================================ */

.cd-interp-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.cd-interp-list {
  font-size: 13px;
  color: var(--cd-text-muted);
  padding-left: 16px;
}

.cd-interp-list li { margin-bottom: 6px; line-height: 1.4; }

.cd-interp-note {
  margin-top: 16px;
  padding: 12px 16px;
  background: #f8fafa;
  border-radius: 6px;
  border-left: 3px solid var(--cd-brand);
  font-size: 12px;
  color: var(--cd-text-muted);
  line-height: 1.5;
}

/* ================================================================ */
/* FOOTER                                                           */
/* ================================================================ */

.cd-footer {
  text-align: center;
  padding: 24px;
  color: var(--cd-text-faint);
  font-size: 11px;
  border-top: 1px solid var(--cd-border);
  margin-top: 32px;
}

/* ================================================================ */
/* EXECUTIVE SUMMARY — CSS class versions of inline styles          */
/* ================================================================ */

.cd-key-insights-heading {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--cd-text);
}

.cd-key-insight-item {
  color: var(--cd-text);
  font-size: 13px;
  margin-bottom: 6px;
  line-height: 1.5;
}

.cd-finding-box {
  margin-bottom: 16px;
  padding: 14px 16px;
  background: var(--ct-bg-muted);
  border-radius: 6px;
}

.cd-finding-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-bottom: 6px;
}

.cd-finding-icon {
  font-size: 16px;
  font-weight: 700;
  flex-shrink: 0;
}

.cd-finding-text {
  font-size: 13px;
  color: var(--cd-text);
  line-height: 1.4;
}

.cd-top-drivers-label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 10px;
  color: var(--cd-text);
}

.cd-panel-heading-label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--cd-text);
}

/* ================================================================ */
/* INSIGHT EDITORS — per-section editable text areas                 */
/* ================================================================ */

.cd-insight-area {
  margin-bottom: 12px;
}

.cd-insight-toggle {
  background: none;
  border: 1px dashed var(--cd-border);
  border-radius: 6px;
  padding: 6px 14px;
  font-size: 12px;
  font-weight: 500;
  color: var(--cd-text-muted);
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s;
}

.cd-insight-toggle:hover {
  border-color: var(--cd-brand);
  color: var(--cd-brand);
  background: rgba(50,51,103,0.03);
}

.cd-insight-container {
  display: none;
  margin-top: 8px;
  position: relative;
}

.cd-insight-editor {
  width: 100%;
  min-height: 60px;
  padding: 10px 14px;
  border: 1px solid var(--cd-border);
  border-radius: 6px;
  font-size: 13px;
  font-family: inherit;
  line-height: 1.5;
  color: var(--cd-text);
  outline: none;
  transition: border-color 0.15s;
}

.cd-insight-editor:focus {
  border-color: var(--cd-brand);
  box-shadow: 0 0 0 2px rgba(50,51,103,0.08);
}

.cd-insight-editor:empty::before {
  content: attr(data-placeholder);
  color: var(--cd-text-faint);
  pointer-events: none;
}

.cd-insight-dismiss {
  position: absolute;
  top: 4px;
  right: 4px;
  background: none;
  border: none;
  font-size: 14px;
  color: var(--cd-text-faint);
  cursor: pointer;
  padding: 2px 6px;
  border-radius: 4px;
  transition: all 0.15s;
}

.cd-insight-dismiss:hover {
  color: var(--cd-danger);
  background: rgba(192,57,43,0.06);
}

/* ================================================================ */
/* SECTION TITLE ROW — title + pin button in flex row                */
/* ================================================================ */

.cd-section-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--cd-brand);
}

.cd-section-title-row .cd-section-title {
  margin-bottom: 0;
  padding-bottom: 0;
  border-bottom: none;
}

.cd-pin-btn {
  background: none;
  border: 1px solid var(--cd-border);
  border-radius: 6px;
  padding: 4px 10px;
  font-size: 14px;
  cursor: pointer;
  color: var(--cd-text-faint);
  transition: all 0.15s;
  flex-shrink: 0;
}

.cd-pin-btn:hover {
  border-color: var(--cd-brand);
  color: var(--cd-brand);
  background: rgba(50,51,103,0.03);
}

.cd-pin-btn.cd-pin-btn-active {
  background: var(--cd-brand);
  color: white;
  border-color: var(--cd-brand);
}

/* ================================================================ */
/* OR FACTOR CHIP BAR — filter pills above odds ratio table          */
/* ================================================================ */

.cd-or-chip-bar {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 14px;
}

.cd-or-chip {
  padding: 5px 12px;
  border: 1px solid var(--cd-border);
  border-radius: 20px;
  font-size: 12px;
  font-weight: 500;
  color: var(--cd-text-muted);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.cd-or-chip:hover {
  border-color: var(--cd-brand);
  color: var(--cd-brand);
}

.cd-or-chip.active {
  background: var(--cd-brand);
  color: white;
  border-color: var(--cd-brand);
}

/* ================================================================ */
/* PINNED VIEWS PANEL — card grid for pinned sections                */
/* ================================================================ */

.cd-pinned-panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}

.cd-pinned-panel-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--cd-brand);
}

.cd-pinned-panel-actions {
  display: flex;
  gap: 8px;
}

.cd-pinned-panel-btn {
  padding: 6px 14px;
  border: 1px solid var(--cd-border);
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  color: var(--cd-text-muted);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.cd-pinned-panel-btn:hover {
  border-color: var(--cd-brand);
  color: var(--cd-brand);
}

.cd-pinned-empty {
  text-align: center;
  padding: 48px 24px;
  color: var(--cd-text-faint);
  font-size: 14px;
}

.cd-pinned-empty-icon {
  font-size: 32px;
  margin-bottom: 8px;
  opacity: 0.4;
}

.cd-pinned-card {
  background: var(--cd-card);
  border: 1px solid var(--cd-border);
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 16px;
  transition: box-shadow 0.15s;
}

.cd-pinned-card:hover {
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}

.cd-pinned-card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 10px;
}

.cd-pinned-card-title {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.cd-pinned-card-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--cd-brand);
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.cd-pinned-card-section {
  font-size: 15px;
  font-weight: 600;
  color: var(--cd-text);
}

.cd-pinned-card-actions {
  display: flex;
  gap: 4px;
  flex-shrink: 0;
}

.cd-pinned-action-btn {
  background: none;
  border: 1px solid transparent;
  border-radius: 4px;
  padding: 3px 7px;
  font-size: 12px;
  cursor: pointer;
  color: var(--cd-text-faint);
  transition: all 0.15s;
}

.cd-pinned-action-btn:hover {
  border-color: var(--cd-border);
  color: var(--cd-text-muted);
  background: #f8f9fa;
}

.cd-pinned-remove-btn:hover {
  color: var(--cd-danger);
  background: rgba(192,57,43,0.06);
}

.cd-pinned-export-btn:hover {
  color: var(--cd-brand);
  background: rgba(50,51,103,0.04);
}

.cd-pinned-card-insight {
  padding: 10px 14px;
  border-left: 3px solid var(--cd-accent);
  background: #faf9f7;
  border-radius: 0 6px 6px 0;
  font-size: 13px;
  color: #475569;
  line-height: 1.5;
  margin-bottom: 10px;
}

.cd-pinned-card-chart {
  margin-top: 8px;
  max-height: 300px;
  overflow: hidden;
}

.cd-pinned-card-chart svg {
  max-width: 100%;
  height: auto;
}

/* ================================================================ */
/* ACTION BAR — Save button strip                                    */
/* ================================================================ */

.cd-action-bar {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  padding: 8px 24px;
  background: var(--cd-card);
  border-bottom: 1px solid var(--cd-border);
}

.cd-save-btn {
  padding: 7px 18px;
  border: 1px solid var(--cd-brand);
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  color: var(--cd-brand);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.cd-save-btn:hover {
  background: var(--cd-brand);
  color: white;
}

.cd-saved-badge {
  display: none;
  font-size: 11px;
  color: var(--cd-text-faint);
  font-weight: 400;
}

/* ================================================================ */
/* PRINT STYLES                                                     */
/* ================================================================ */

@media print {
  .cd-section-nav { display: none !important; }
  .cd-content { padding: 16px !important; max-width: none !important; }
  .cd-body { background: white; font-size: 11px; }
  .cd-section { break-inside: avoid; page-break-inside: avoid; border: none; box-shadow: none; }
  .cd-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .cd-header-inner { max-width: none !important; }
  .cd-header-inner * { color: #1a2744 !important; }
  .cd-header-module-name { font-size: 16px !important; }
  .cd-header-title { font-size: 14px !important; margin-top: 4px !important; }
  .cd-header-logo-container { width: 32px !important; height: 32px !important; }
  .cd-header-logo-container img { width: 28px !important; height: 28px !important; }
  .cd-factor-tabs { display: none !important; }
  .cd-factor-panel { display: block !important; margin-bottom: 16px; }
  .cd-chart { max-width: 500px; }
  /* Hide interactive elements in print */
  .cd-insight-area { display: none !important; }
  .cd-pin-btn { display: none !important; }
  .cd-or-chip-bar { display: none !important; }
  .cd-action-bar { display: none !important; }
  .cd-pinned-card-actions { display: none !important; }
}

@media (max-width: 768px) {
  .cd-section-nav { padding: 0 12px; }
  .cd-section-nav a { padding: 10px 14px; font-size: 12px; }
  .cd-content { padding: 16px; }
  .cd-interp-grid { grid-template-columns: 1fr; }
  .cd-header { padding: 16px; }
  .cd-header-module-name { font-size: 20px; }
  .cd-header-title { font-size: 18px; }
}
'
  css <- gsub("BRAND_COLOUR", brand_colour, css, fixed = TRUE)
  css <- gsub("ACCENT_COLOUR", accent_colour, css, fixed = TRUE)
  css
}


#' Build Horizontal Section Navigation Bar
#'
#' Creates a sticky horizontal nav bar below the header with section links.
#' Matches tabs/tracker .report-tabs pattern — underline indicator on active.
#' Zero side-space cost; works identically standalone and in Report Hub.
#'
#' @param brand_colour Brand colour hex string
#' @return htmltools tag
#' @keywords internal
build_cd_section_nav <- function(brand_colour = "#323367", id_prefix = "") {
  htmltools::tags$nav(
    class = "cd-section-nav",
    id = paste0(id_prefix, "cd-section-nav"),
    htmltools::tags$a(href = paste0("#", id_prefix, "cd-exec-summary"), "Summary", class = "active"),
    htmltools::tags$a(href = paste0("#", id_prefix, "cd-importance"), "Importance"),
    htmltools::tags$a(href = paste0("#", id_prefix, "cd-patterns"), "Patterns"),
    htmltools::tags$a(href = paste0("#", id_prefix, "cd-odds-ratios"), "Odds Ratios"),
    htmltools::tags$a(href = paste0("#", id_prefix, "cd-diagnostics"), "Diagnostics"),
    htmltools::tags$a(href = paste0("#", id_prefix, "cd-interpretation"), "Guide")
  )
}


#' Build Header Section
#'
#' Creates the gradient banner header matching tabs/tracker design.
#' Includes logo, module name, project title, prepared-by text, and badge bar.
#'
#' @param html_data Transformed HTML data
#' @param config Configuration list (for logos, company name)
#' @param brand_colour Brand colour hex string
#' @param report_title Report title text
#' @return htmltools tag
#' @keywords internal
build_cd_header <- function(html_data, config, brand_colour, report_title, id_prefix = "") {

  model_info <- html_data$model_info
  diag <- html_data$diagnostics

  model_label <- switch(model_info$outcome_type,
    binary = "Binary Logistic",
    ordinal = "Ordinal Logistic",
    nominal = "Multinomial Logistic",
    model_info$outcome_type
  )

  weight_text <- if (!is.null(model_info$weight_var) && nzchar(model_info$weight_var %||% "")) {
    "Weighted"
  } else {
    "Unweighted"
  }

  # --- Logo ---
  logo_el <- NULL
  logo_uri <- resolve_logo_uri(config$researcher_logo_path)
  if (!is.null(logo_uri) && nzchar(logo_uri)) {
    logo_el <- htmltools::tags$div(
      class = "cd-header-logo-container",
      htmltools::tags$img(
        src = logo_uri,
        alt = "Logo",
        style = "height:56px;width:56px;object-fit:contain;"
      )
    )
  }

  # --- Top row: [logo] Turas Catdriver / subtitle ---
  branding_left <- htmltools::tags$div(
    class = "cd-header-branding",
    logo_el,
    htmltools::tags$div(
      htmltools::tags$div(class = "cd-header-module-name", "Turas Catdriver"),
      htmltools::tags$div(class = "cd-header-module-sub", "Categorical Key Driver Analysis")
    )
  )

  top_row <- htmltools::tags$div(
    class = "cd-header-top",
    branding_left
  )

  # --- Project title ---
  title_row <- htmltools::tags$div(
    class = "cd-header-title",
    report_title
  )

  # --- Prepared by / for text ---
  prepared_row <- NULL
  company_name <- config$company_name %||% "The Research Lamppost"
  client_name <- config$client_name %||% NULL
  prepared_parts <- c()
  if (!is.null(company_name) && nzchar(company_name)) {
    prepared_parts <- c(prepared_parts, sprintf(
      'Prepared by <span style="font-weight:600;">%s</span>',
      htmltools::htmlEscape(company_name)
    ))
  }
  if (!is.null(client_name) && nzchar(client_name)) {
    prepared_parts <- c(prepared_parts, sprintf(
      'for <span style="font-weight:600;">%s</span>',
      htmltools::htmlEscape(client_name)
    ))
  }
  if (length(prepared_parts) > 0) {
    prepared_row <- htmltools::tags$div(
      class = "cd-header-prepared",
      htmltools::HTML(paste(prepared_parts, collapse = " "))
    )
  }

  # --- Badge bar ---
  badge_items <- list()

  # Model type badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "cd-header-badge",
    htmltools::HTML(sprintf(
      '<span class="cd-header-badge-val">%s</span>&nbsp;Model',
      model_label
    ))
  )))

  # Sample size badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "cd-header-badge",
    htmltools::HTML(sprintf(
      'n&nbsp;=&nbsp;<span class="cd-header-badge-val">%s</span>',
      format(diag$complete_n, big.mark = ",")
    ))
  )))

  # Drivers badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "cd-header-badge",
    htmltools::HTML(sprintf(
      '<span class="cd-header-badge-val">%d</span>&nbsp;Drivers',
      model_info$n_drivers
    ))
  )))

  # Weight status badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "cd-header-badge", weight_text
  )))

  # Date badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "cd-header-badge",
    format(Sys.Date(), "Created %b %Y")
  )))

  # Interleave with separators
  badge_els <- list()
  for (i in seq_along(badge_items)) {
    if (i > 1) {
      badge_els <- c(badge_els, list(htmltools::tags$span(class = "cd-header-badge-sep")))
    }
    badge_els <- c(badge_els, list(badge_items[[i]]))
  }

  badges_bar <- htmltools::tags$div(
    class = "cd-header-badges",
    badge_els
  )

  # --- Assemble header ---
  htmltools::tags$div(
    class = "cd-header",
    id = paste0(id_prefix, "cd-header"),
    htmltools::tags$div(
      class = "cd-header-inner",
      top_row,
      title_row,
      prepared_row,
      badges_bar
    )
  )
}


#' Resolve Logo URI
#'
#' Converts a file path to a base64 data URI for self-contained HTML.
#' Accepts NULL, file paths, or already-formed data: URIs.
#'
#' @param logo_path File path or URI string
#' @return Character data URI or NULL
#' @keywords internal
resolve_logo_uri <- function(logo_path) {
  if (is.null(logo_path) || !nzchar(logo_path %||% "")) return(NULL)

  # Already a URI
  if (grepl("^(data:|https?://)", logo_path)) return(logo_path)

  # File path — convert to base64
  if (!file.exists(logo_path)) return(NULL)

  if (!requireNamespace("base64enc", quietly = TRUE)) {
    message("base64enc package required for logo embedding. Install with: install.packages('base64enc')")
    return(NULL)
  }

  ext <- tolower(tools::file_ext(logo_path))
  mime_type <- switch(ext,
    png = "image/png",
    jpg = , jpeg = "image/jpeg",
    svg = "image/svg+xml",
    gif = "image/gif",
    "image/png"  # default
  )

  tryCatch({
    base64enc::dataURI(file = logo_path, mime = mime_type)
  }, error = function(e) {
    message(sprintf("Failed to encode logo '%s': %s", logo_path, e$message))
    NULL
  })
}


#' Build Executive Summary Section
#' @keywords internal
build_cd_exec_summary <- function(html_data, brand_colour, id_prefix = "") {

  fit <- html_data$model_info$fit_statistics

  # Model confidence callout
  confidence_html <- NULL
  if (!is.null(fit) && !is.na(fit$mcfadden_r2)) {
    r2 <- fit$mcfadden_r2
    r2_pct <- round(r2 * 100, 1)

    if (r2 >= 0.4) {
      conf_class <- "cd-confidence-excellent"
      conf_text <- sprintf("Excellent model fit (R\u00B2 = %.3f). The %d measured factors explain %.1f%% of variation in the outcome.",
                           r2, html_data$model_info$n_drivers, r2_pct)
    } else if (r2 >= 0.2) {
      conf_class <- "cd-confidence-good"
      conf_text <- sprintf("Good model fit (R\u00B2 = %.3f). The %d measured factors explain %.1f%% of variation in the outcome.",
                           r2, html_data$model_info$n_drivers, r2_pct)
    } else if (r2 >= 0.1) {
      conf_class <- "cd-confidence-moderate"
      conf_text <- sprintf("Moderate model fit (R\u00B2 = %.3f). The %d measured factors explain %.1f%% of variation. Other unmeasured factors may also play a role.",
                           r2, html_data$model_info$n_drivers, r2_pct)
    } else {
      conf_class <- "cd-confidence-limited"
      conf_text <- sprintf("Limited model fit (R\u00B2 = %.3f). The %d measured factors explain only %.1f%% of variation. Key unmeasured factors likely influence the outcome.",
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

  # Narrative insights
  narrative <- html_data$narrative
  narrative_html <- NULL
  if (!is.null(narrative) && length(narrative$insights) > 0) {
    insight_items <- lapply(narrative$insights, function(txt) {
      htmltools::tags$li(class = "cd-key-insight-item", txt)
    })
    narrative_html <- htmltools::tags$div(
      style = "margin-bottom:16px;",
      htmltools::tags$h3(class = "cd-key-insights-heading", "Key Insights"),
      htmltools::tags$ul(style = "padding-left:20px;", insight_items)
    )
  }

  # Key findings (extreme ORs)
  findings_html <- NULL
  if (!is.null(narrative) && length(narrative$key_findings) > 0) {
    finding_items <- lapply(narrative$key_findings, function(f) {
      icon <- if (f$direction == "positive") "\u2191" else "\u2193"
      colour <- if (f$direction == "positive") "var(--cd-success)" else "var(--cd-danger)"
      htmltools::tags$div(
        class = "cd-finding-item",
        htmltools::tags$span(
          class = "cd-finding-icon",
          style = sprintf("color:%s;", colour),
          icon
        ),
        htmltools::tags$span(class = "cd-finding-text", f$text)
      )
    })
    findings_html <- htmltools::tags$div(
      class = "cd-finding-box",
      htmltools::tags$h3(class = "cd-top-drivers-label", "Standout Findings"),
      finding_items
    )
  }

  # Section title + pin + insight
  title_row <- build_cd_section_title_row("Executive Summary", "exec-summary",
                                           id_prefix = id_prefix)
  insight_area <- build_cd_insight_area("exec-summary", id_prefix = id_prefix)

  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-exec-summary"),
    `data-cd-section` = "exec-summary",
    title_row,
    insight_area,
    confidence_html,
    narrative_html,
    driver_cards,
    findings_html,
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
build_cd_importance_section <- function(tables, charts, brand_colour, id_prefix = "") {
  title_row <- build_cd_section_title_row("Driver Importance", "importance",
                                           id_prefix = id_prefix)
  insight_area <- build_cd_insight_area("importance", id_prefix = id_prefix)

  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-importance"),
    `data-cd-section` = "importance",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "cd-section-intro",
      "Relative importance of each driver in explaining the outcome, based on chi-square contribution. Higher percentage means stronger statistical relationship."
    ),
    if (!is.null(charts$importance)) charts$importance,
    tables$importance
  )
}


#' Build Patterns Section with Factor Picker
#' @keywords internal
build_cd_patterns_section <- function(html_data, tables, id_prefix = "") {

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
      onclick = sprintf("cdShowFactor('%s','%s')", safe_id, id_prefix),
      `data-factor` = paste0(id_prefix, safe_id),
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
      id = paste0(id_prefix, "cd-panel-", safe_id),
      htmltools::tags$h3(
        class = "cd-panel-heading-label",
        sprintf("%s (reference: %s)", label, ref)
      ),
      tables$patterns[[var_name]]
    )
  })

  title_row <- build_cd_section_title_row("Factor Patterns", "patterns",
                                           id_prefix = id_prefix)
  insight_area <- build_cd_insight_area("patterns", id_prefix = id_prefix)

  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-patterns"),
    `data-cd-section` = "patterns",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "cd-section-intro",
      "Category-level breakdown showing how each level of a driver relates to the outcome. Odds ratios > 1.0 indicate higher likelihood compared to the reference category."
    ),
    htmltools::tags$div(class = "cd-factor-tabs", tabs),
    panels
  )
}


#' Build Odds Ratios Section
#' @keywords internal
build_cd_or_section <- function(tables, charts, has_bootstrap,
                                 id_prefix = "", odds_ratios = NULL) {
  bootstrap_note <- if (has_bootstrap) {
    htmltools::tags$p(
      style = "color:var(--cd-text-faint);font-size:12px;margin-top:8px;",
      "Bootstrap columns show resampled estimates. Sign stability indicates the percentage of bootstrap samples where the OR remained on the same side of 1.0."
    )
  }

  title_row <- build_cd_section_title_row("Odds Ratios", "odds-ratios",
                                           id_prefix = id_prefix)
  insight_area <- build_cd_insight_area("odds-ratios", id_prefix = id_prefix)

  # OR chip bar for factor filtering
  chip_bar <- build_cd_or_chip_bar(odds_ratios, id_prefix = id_prefix)

  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-odds-ratios"),
    `data-cd-section` = "odds-ratios",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "cd-section-intro",
      "Detailed coefficient table showing the odds ratio for each factor level compared to its reference category. OR > 1 means higher likelihood; OR < 1 means lower likelihood."
    ),
    if (!is.null(charts$forest)) charts$forest,
    chip_bar,
    tables$odds_ratios,
    bootstrap_note
  )
}


#' Build Diagnostics Section
#' @keywords internal
build_cd_diagnostics_section <- function(tables, html_data, id_prefix = "") {

  # Warning list
  warnings_html <- NULL
  if (length(html_data$diagnostics$warnings) > 0) {
    warning_items <- lapply(html_data$diagnostics$warnings, function(w) {
      htmltools::tags$li(class = "cd-key-insight-item", w)
    })
    warnings_html <- htmltools::tags$div(
      style = "margin-top:16px;",
      htmltools::tags$h3(class = "cd-panel-heading-label", "Warnings"),
      htmltools::tags$ul(style = "padding-left:20px;", warning_items)
    )
  }

  # Model fit stats
  fit <- html_data$model_info$fit_statistics
  fit_items <- list()
  if (!is.null(fit)) {
    if (!is.na(fit$mcfadden_r2)) {
      fit_items <- c(fit_items, list(sprintf("McFadden R\u00B2: %.3f", fit$mcfadden_r2)))
    }
    if (!is.na(fit$aic)) {
      fit_items <- c(fit_items, list(sprintf("AIC: %.1f", fit$aic)))
    }
    if (!is.na(fit$lr_statistic)) {
      fit_items <- c(fit_items, list(
        sprintf("LR test: \u03C7\u00B2(%d) = %.1f, p %s",
                fit$lr_df, fit$lr_statistic, format_pvalue(fit$lr_pvalue))
      ))
    }
  }

  fit_html <- if (length(fit_items) > 0) {
    htmltools::tags$div(
      style = "margin-top:16px;",
      htmltools::tags$h3(class = "cd-panel-heading-label", "Model Fit Statistics"),
      htmltools::tags$div(
        style = "display:flex;gap:24px;flex-wrap:wrap;",
        lapply(fit_items, function(item) {
          htmltools::tags$span(style = "font-size:13px;color:var(--cd-text-muted);", item)
        })
      )
    )
  }

  title_row <- build_cd_section_title_row("Model Diagnostics", "diagnostics",
                                           id_prefix = id_prefix)
  insight_area <- build_cd_insight_area("diagnostics", id_prefix = id_prefix)

  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-diagnostics"),
    `data-cd-section` = "diagnostics",
    title_row,
    insight_area,
    tables$diagnostics,
    fit_html,
    warnings_html
  )
}


#' Build Interpretation Guide Section
#' @keywords internal
build_cd_interpretation_section <- function(brand_colour = "#323367", id_prefix = "") {
  title_row <- build_cd_section_title_row("How to Interpret These Results",
                                           "interpretation",
                                           id_prefix = id_prefix,
                                           show_pin = FALSE)

  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-interpretation"),
    `data-cd-section` = "interpretation",
    title_row,
    htmltools::tags$div(
      class = "cd-interp-grid",
      htmltools::tags$div(
        htmltools::tags$h3(
          class = "cd-panel-heading-label",
          style = "color:var(--cd-success);",
          "DO"
        ),
        htmltools::tags$ul(
          class = "cd-interp-list",
          htmltools::tags$li("Focus on large effects (OR > 2.0 or < 0.5) that are practically meaningful"),
          htmltools::tags$li("Consider the ranking of drivers rather than exact OR values"),
          htmltools::tags$li("Validate key findings with qualitative research or experiments"),
          htmltools::tags$li("Report uncertainty ranges when presenting to stakeholders")
        )
      ),
      htmltools::tags$div(
        htmltools::tags$h3(
          class = "cd-panel-heading-label",
          style = "color:var(--cd-danger);",
          "DON'T"
        ),
        htmltools::tags$ul(
          class = "cd-interp-list",
          htmltools::tags$li("Treat odds ratios as precise population parameters"),
          htmltools::tags$li("Make causal claims without experimental evidence"),
          htmltools::tags$li("Over-interpret small differences (OR 1.1 vs 1.2)"),
          htmltools::tags$li("Ignore multicollinearity or convergence warnings")
        )
      )
    ),
    htmltools::tags$div(
      class = "cd-interp-note",
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


# ==============================================================================
# INSIGHT AREA BUILDER — editable text per section
# ==============================================================================

#' Build Insight Area
#'
#' Creates the editable insight area: toggle button + hidden editor + store.
#'
#' @param section_key Section key string (e.g., "exec-summary", "importance")
#' @param id_prefix ID prefix for the panel
#' @return htmltools tagList
#' @keywords internal
build_cd_insight_area <- function(section_key, id_prefix = "") {
  htmltools::tags$div(
    class = "cd-insight-area",
    `data-cd-insight-section` = section_key,
    `data-cd-insight-prefix` = id_prefix,
    htmltools::tags$button(
      class = "cd-insight-toggle",
      id = paste0(id_prefix, "cd-insight-toggle-", section_key),
      onclick = sprintf("cdToggleInsight('%s','%s')", section_key, id_prefix),
      "+ Add Insight"
    ),
    htmltools::tags$div(
      class = "cd-insight-container",
      id = paste0(id_prefix, "cd-insight-container-", section_key),
      htmltools::tags$div(
        class = "cd-insight-editor",
        contenteditable = "true",
        `data-placeholder` = "Type your insight or comment here...",
        oninput = sprintf("cdSyncInsight('%s','%s')", section_key, id_prefix)
      ),
      htmltools::tags$button(
        class = "cd-insight-dismiss",
        onclick = sprintf("cdDismissInsight('%s','%s')", section_key, id_prefix),
        "\u00D7"
      )
    )
  )
}


# ==============================================================================
# SECTION TITLE ROW — title + pin button in flex row
# ==============================================================================

#' Build Section Title Row
#'
#' Wraps a section title and pin button in a flex row.
#'
#' @param title_text Title text
#' @param section_key Section key for pinning
#' @param id_prefix ID prefix for the panel
#' @param show_pin Whether to show the pin button
#' @return htmltools tag
#' @keywords internal
build_cd_section_title_row <- function(title_text, section_key, id_prefix = "",
                                        show_pin = TRUE) {
  pin_btn <- if (show_pin) {
    htmltools::tags$button(
      class = "cd-pin-btn",
      `data-cd-pin-section` = section_key,
      `data-cd-pin-prefix` = id_prefix,
      onclick = sprintf("cdPinSection('%s','%s')", section_key, id_prefix),
      title = "Pin this section",
      "\U0001F4CC"
    )
  }

  htmltools::tags$div(
    class = "cd-section-title-row",
    htmltools::tags$h2(class = "cd-section-title", title_text),
    pin_btn
  )
}


# ==============================================================================
# OR CHIP BAR — factor filter pills for odds ratios
# ==============================================================================

#' Build OR Chip Bar
#'
#' Generates pill buttons to filter OR table rows by factor.
#'
#' @param odds_ratios List of OR entries (from transformer)
#' @param id_prefix ID prefix
#' @return htmltools tag or NULL
#' @keywords internal
build_cd_or_chip_bar <- function(odds_ratios, id_prefix = "") {
  if (is.null(odds_ratios) || length(odds_ratios) == 0) return(NULL)

  # Extract unique factor labels
  factor_labels <- unique(vapply(odds_ratios, function(r) {
    r$factor_label %||% ""
  }, character(1)))
  factor_labels <- factor_labels[nzchar(factor_labels)]

  if (length(factor_labels) < 2) return(NULL)  # no point with 1 factor

  chips <- lapply(factor_labels, function(fl) {
    htmltools::tags$button(
      class = "cd-or-chip active",
      `data-cd-or-factor` = fl,
      onclick = sprintf("cdToggleOrFactor('%s','%s')",
                        gsub("'", "\\\\'", fl), id_prefix),
      fl
    )
  })

  htmltools::tags$div(class = "cd-or-chip-bar", chips)
}


# ==============================================================================
# ACTION BAR — Save button (for single-report mode)
# ==============================================================================

#' Build Action Bar
#'
#' Creates the save button strip.
#'
#' @param report_title Title for filename generation
#' @return htmltools tag
#' @keywords internal
build_cd_action_bar <- function(report_title = "Catdriver Report") {
  htmltools::tags$div(
    class = "cd-action-bar",
    htmltools::tags$span(
      class = "cd-saved-badge",
      id = "cd-saved-badge"
    ),
    htmltools::tags$button(
      class = "cd-save-btn",
      onclick = "cdSaveReportHTML()",
      "\U0001F4BE Save Report"
    )
  )
}
