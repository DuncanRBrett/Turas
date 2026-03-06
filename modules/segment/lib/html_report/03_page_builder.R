# ==============================================================================
# SEGMENT HTML REPORT - PAGE BUILDER
# ==============================================================================
# Assembles the complete HTML page from tables, charts, and section content.
# Design system: Turas muted palette, clean typography, seg- CSS prefix.
# Version: 11.0
# ==============================================================================


#' Build Complete Segment HTML Page
#'
#' Assembles all report components into a single browsable HTML page.
#'
#' @param html_data Transformed data from transform_segment_for_html()
#' @param tables Named list of htmltools table objects
#' @param charts Named list of htmltools SVG chart objects
#' @param config Configuration list
#' @return htmltools::browsable tagList
#' @keywords internal
build_seg_html_page <- function(html_data, tables, charts, config) {

  brand_colour <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"
  report_title <- config$report_title %||% html_data$analysis_name

  # Build CSS
  css <- build_seg_css(brand_colour, accent_colour)

  # Determine section visibility from config flags
  show_rules <- isTRUE(config$html_show_rules) &&
    !is.null(html_data$enhanced$classification_rules)
  show_cards <- isTRUE(config$html_show_cards %||% TRUE) &&
    !is.null(html_data$enhanced$segment_cards)
  show_gmm <- (html_data$method %in% c("gmm", "mclust")) &&
    !is.null(html_data$gmm_membership)
  show_exec <- isTRUE(config$html_show_exec_summary %||% TRUE)
  show_overview <- isTRUE(config$html_show_overview %||% TRUE)
  show_validation <- isTRUE(config$html_show_validation %||% TRUE)
  show_importance <- isTRUE(config$html_show_importance %||% TRUE) &&
    !is.null(html_data$variable_importance)
  show_profiles <- isTRUE(config$html_show_profiles %||% TRUE) &&
    !is.null(html_data$profile_data)
  show_vulnerability <- !is.null(html_data$vulnerability)
  show_overlap <- !is.null(html_data$centers) && html_data$k > 1
  show_golden_questions <- !is.null(html_data$golden_questions) &&
    !is.null(html_data$golden_questions$top_questions)
  show_guide <- isTRUE(config$html_show_guide %||% TRUE)

  # Build sections config for nav (analysis sections only; pinned views is a report-level tab)
  sections_config <- list(
    `exec-summary` = list(label = "Summary", show = show_exec),
    overview       = list(label = "Overview", show = show_overview),
    validation     = list(label = "Validation", show = show_validation),
    overlap        = list(label = "Overlap", show = show_overlap),
    importance     = list(label = "Importance", show = show_importance),
    `golden-questions` = list(label = "Golden Questions", show = show_golden_questions),
    profiles       = list(label = "Profiles", show = show_profiles),
    rules          = list(label = "Rules", show = show_rules),
    cards          = list(label = "Segment Cards", show = show_cards),
    vulnerability  = list(label = "Vulnerability", show = show_vulnerability),
    gmm            = list(label = "GMM Membership", show = show_gmm),
    guide          = list(label = "Guide", show = show_guide)
  )

  # Build sections
  header_section <- build_seg_header(html_data, config, brand_colour, report_title)
  nav <- build_seg_section_nav(brand_colour, sections_config)
  action_bar <- build_seg_action_bar(report_title)

  exec_summary_section <- if (show_exec) {
    build_seg_exec_summary_section(html_data, brand_colour)
  }
  overview_section <- if (show_overview) {
    build_seg_overview_section(tables, charts, html_data)
  }
  validation_section <- if (show_validation) {
    build_seg_validation_section(tables, charts, html_data)
  }
  importance_section <- if (show_importance) {
    build_seg_importance_section(tables, charts, html_data)
  }
  profiles_section <- if (show_profiles) {
    build_seg_profiles_section(tables, charts, html_data)
  }
  rules_section <- if (show_rules) {
    build_seg_rules_section(tables, html_data)
  }
  cards_section <- if (show_cards) {
    build_seg_cards_section(html_data)
  }
  overlap_section <- if (show_overlap) {
    build_seg_overlap_section(charts, html_data)
  }
  golden_questions_section <- if (show_golden_questions) {
    build_seg_golden_questions_section(charts, html_data)
  }
  vulnerability_section <- if (show_vulnerability) {
    build_seg_vulnerability_section(html_data)
  }
  gmm_section <- if (show_gmm) {
    build_seg_gmm_section(tables, html_data)
  }
  guide_section <- if (show_guide) {
    build_seg_guide_section(brand_colour)
  }
  footer_section <- build_seg_footer(config)

  # Pinned Views section
  pinned_section <- htmltools::tags$div(
    class = "seg-section",
    id = "seg-pinned-section",
    `data-seg-section` = "pinned-views",
    htmltools::tags$div(
      class = "seg-pinned-panel-header",
      htmltools::tags$div(class = "seg-pinned-panel-title",
                          "Pinned Views"),
      htmltools::tags$div(
        class = "seg-pinned-panel-actions",
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segAddSection()",
          "+ Add Section"
        ),
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segExportAllPinnedPNG()",
          "Export All as PNG"
        ),
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segPrintPinnedViews()",
          "Print / PDF"
        ),
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segClearAllPinned()",
          "Clear All"
        )
      )
    ),
    htmltools::tags$div(
      id = "seg-pinned-empty",
      class = "seg-pinned-empty",
      htmltools::tags$div(class = "seg-pinned-empty-icon", style = "font-size:32px; color:#94a3b8;",
                          "\U0001F4CC"),
      htmltools::tags$div("No pinned views yet."),
      htmltools::tags$div(
        style = "font-size:12px;margin-top:4px;",
        "Click the pin icon on any section to save it here for export."
      )
    ),
    htmltools::tags$div(id = "seg-pinned-cards-container")
  )

  # Hidden insight store
  insight_store <- htmltools::tags$textarea(
    class = "seg-insight-store",
    id = "seg-insight-store",
    `data-seg-prefix` = "",
    style = "display:none;",
    "{}"
  )

  # Hidden pinned views data store
  pinned_store <- htmltools::tags$script(
    id = "seg-pinned-views-data",
    type = "application/json",
    "[]"
  )

  # Read JS files
  js_files <- c("seg_utils.js", "seg_navigation.js",
                "seg_pinned_views.js", "seg_slide_export.js")
  js_tags <- lapply(js_files, function(fname) {
    js_path <- file.path(.seg_html_report_dir, "js", fname)
    js_content <- if (file.exists(js_path)) {
      paste(readLines(js_path, warn = FALSE), collapse = "\n")
    } else {
      sprintf("/* %s not found */", fname)
    }
    htmltools::tags$script(htmltools::HTML(js_content))
  })

  # Report Hub metadata
  source_filename <- basename(config$output_file %||%
                               config$report_title %||% "Segment_Report")
  hub_meta <- htmltools::tagList(
    htmltools::tags$meta(name = "turas-report-type", content = "segment"),
    htmltools::tags$meta(name = "turas-module-version", content = "11.0"),
    htmltools::tags$meta(name = "turas-source-filename", content = source_filename)
  )

  # Report-level tab bar (Analysis | Pinned Views)
  report_tab_bar <- htmltools::tags$div(
    class = "seg-report-tabs",
    htmltools::tags$button(
      class = "seg-report-tab-btn active",
      `data-tab` = "analysis",
      "Analysis"
    ),
    htmltools::tags$button(
      class = "seg-report-tab-btn",
      `data-tab` = "pinned",
      "Pinned Views",
      htmltools::tags$span(
        id = "seg-pin-count-badge",
        class = "seg-pin-count-badge",
        style = "display:none;"
      )
    )
  )

  # Assemble page
  page <- htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "utf-8"),
      htmltools::tags$meta(name = "viewport",
                           content = "width=device-width, initial-scale=1"),
      htmltools::tags$title(report_title),
      hub_meta,
      htmltools::tags$style(htmltools::HTML(css))
    ),
    htmltools::tags$body(
      class = "seg-body",
      header_section,
      action_bar,
      report_tab_bar,
      nav,
      htmltools::tags$main(
        class = "seg-main",
        # Analysis tab content
        htmltools::tags$div(
          id = "seg-analysis-tab",
          class = "seg-content",
          exec_summary_section,
          overview_section,
          validation_section,
          overlap_section,
          importance_section,
          golden_questions_section,
          profiles_section,
          rules_section,
          cards_section,
          vulnerability_section,
          gmm_section,
          guide_section,
          footer_section
        ),
        # Pinned Views tab content (hidden by default)
        htmltools::tags$div(
          id = "seg-pinned-tab",
          class = "seg-content",
          style = "display:none;",
          pinned_section,
          footer_section
        ),
        insight_store,
        pinned_store
      ),
      js_tags
    )
  )

  htmltools::browsable(page)
}


# ==============================================================================
# CSS BUILDER
# ==============================================================================

#' Build Segment Report CSS
#'
#' Generates the complete stylesheet for the segmentation HTML report.
#' Uses CSS variables for brand consistency. Replaces BRAND_COLOUR and
#' ACCENT_COLOUR placeholders via gsub().
#'
#' @param brand_colour Brand colour hex string
#' @param accent_colour Accent colour hex string
#' @return Character string of CSS
#' @keywords internal
build_seg_css <- function(brand_colour = "#323367", accent_colour = "#CC9900") {
  css <- '
/* ==== SEGMENT REPORT CSS ==== */
/* seg- namespace for Report Hub safety */
/* Aligned with shared Turas design system */

:root {
  /* Brand colours */
  --seg-brand: BRAND_COLOUR;
  --seg-accent: ACCENT_COLOUR;

  /* Module variables */
  --seg-text: #1e293b;
  --seg-text-muted: #64748b;
  --seg-text-faint: #94a3b8;
  --seg-bg: #f8f7f5;
  --seg-card: #ffffff;
  --seg-border: #e2e8f0;
  --seg-success: #059669;
  --seg-warning: #F59E0B;
  --seg-danger: #c0392b;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

.seg-body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background: var(--seg-bg);
  color: var(--seg-text);
  line-height: 1.5;
  font-size: 13px;
}

/* ================================================================ */
/* HORIZONTAL SECTION NAV BAR                                        */
/* Sticky below header, full-width, underline active indicator       */
/* ================================================================ */

.seg-section-nav {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--seg-card);
  border-bottom: 2px solid var(--seg-border);
  display: flex;
  align-items: center;
  gap: 0;
  padding: 0 24px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.seg-section-nav a {
  display: inline-flex;
  align-items: center;
  padding: 12px 20px;
  color: var(--seg-text-muted);
  text-decoration: none;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  border-bottom: 3px solid transparent;
  cursor: pointer;
  transition: all 0.15s ease;
}

.seg-section-nav a:hover {
  color: var(--seg-brand);
  background: #f8fafc;
}

.seg-section-nav a.active {
  color: var(--seg-brand);
  border-bottom-color: var(--seg-brand);
}

/* ================================================================ */
/* REPORT-LEVEL TABS (Analysis | Pinned Views)                       */
/* ================================================================ */

.seg-report-tabs {
  display: flex;
  align-items: center;
  gap: 0;
  padding: 0 24px;
  background: var(--seg-card);
  border-bottom: 1px solid var(--seg-border);
}

.seg-report-tab-btn {
  padding: 10px 24px;
  font-size: 13px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--seg-text-muted);
  background: none;
  border: none;
  border-bottom: 3px solid transparent;
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s;
}

.seg-report-tab-btn:hover {
  color: var(--seg-brand);
  background: #f8fafc;
}

.seg-report-tab-btn.active {
  color: var(--seg-brand);
  border-bottom-color: var(--seg-accent);
}

/* ================================================================ */
/* MAIN CONTENT                                                      */
/* ================================================================ */

.seg-main {
  min-width: 0;
}

.seg-content {
  max-width: 1100px;
  margin: 0 auto;
  padding: 24px 32px;
}

/* ================================================================ */
/* HEADER — gradient banner with badges                              */
/* ================================================================ */

.seg-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
  padding: 24px 32px;
  border-bottom: 3px solid var(--seg-brand);
}

.seg-header-inner {
  max-width: 1100px;
  margin: 0 auto;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

.seg-header-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.seg-header-branding {
  display: flex;
  align-items: center;
  gap: 16px;
}

.seg-header-logo-container {
  width: 72px;
  height: 72px;
  border-radius: 12px;
  background: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.seg-header-logo-container img {
  height: 56px;
  width: 56px;
  object-fit: contain;
}

.seg-header-module-name {
  color: #ffffff;
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: -0.3px;
}

.seg-header-module-sub {
  color: rgba(255,255,255,0.50);
  font-size: 12px;
  font-weight: 400;
  margin-top: 2px;
}

.seg-header-title {
  color: #ffffff;
  font-size: 22px;
  font-weight: 700;
  letter-spacing: -0.3px;
  margin-top: 16px;
  line-height: 1.2;
}

.seg-header-prepared {
  color: rgba(255,255,255,0.65);
  font-size: 13px;
  font-weight: 400;
  margin-top: 4px;
  line-height: 1.3;
}

.seg-header-badges {
  display: inline-flex;
  align-items: center;
  margin-top: 12px;
  border: 1px solid rgba(255,255,255,0.15);
  border-radius: 6px;
  background: rgba(255,255,255,0.05);
}

.seg-header-badge {
  display: inline-flex;
  align-items: center;
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(255,255,255,0.85);
}

.seg-header-badge-val {
  color: rgba(255,255,255,1);
  font-weight: 700;
}

.seg-header-badge-sep {
  width: 1px;
  height: 16px;
  background: rgba(255,255,255,0.20);
  flex-shrink: 0;
}

/* ================================================================ */
/* SECTIONS (card style)                                             */
/* ================================================================ */

.seg-section {
  background: var(--seg-card);
  border: 1px solid var(--seg-border);
  border-radius: 8px;
  padding: 24px 28px;
  margin-bottom: 20px;
}

.seg-section-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--seg-brand);
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--seg-brand);
}

.seg-section-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--seg-brand);
}

.seg-section-title-row .seg-section-title {
  margin-bottom: 0;
  padding-bottom: 0;
  border-bottom: none;
}

.seg-section-intro {
  color: var(--seg-text-muted);
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.5;
}

/* ================================================================ */
/* TABLES                                                            */
/* ================================================================ */

.seg-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.seg-th {
  background: #f0f1f8;
  color: var(--seg-text-muted);
  font-weight: 600;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  padding: 10px 12px;
  text-align: left;
  border-bottom: 2px solid var(--seg-border);
  vertical-align: bottom;
  white-space: normal;
}

.seg-th-num { text-align: center; }
.seg-th-bar { text-align: left; min-width: 150px; }
.seg-th-rank { text-align: center; width: 50px; }

.seg-td {
  padding: 8px 12px;
  border-bottom: 1px solid #f0f0f0;
  vertical-align: middle;
  color: var(--seg-text);
  font-variant-numeric: tabular-nums;
  transition: background-color 0.15s;
}

.seg-td-num { text-align: center; font-variant-numeric: tabular-nums; }
.seg-td-rank { text-align: center; font-weight: 600; color: var(--seg-brand); }

.seg-tr:nth-child(even) { background: #f9fafb; }
.seg-tr:hover { background: #f8fafc; }

/* Heatmap cell tinting - green=above average, red=below average */
.seg-td-high { background: #dcfce7; }
.seg-td-mod-high { background: #f0fdf4; }
.seg-td-mod-low { background: #fef2f2; }
.seg-td-low { background: #fee2e2; }

/* ================================================================ */
/* BADGES                                                            */
/* ================================================================ */

.seg-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.seg-badge-pass { background: #D1FAE5; color: #065F46; }
.seg-badge-warn { background: #FEF3C7; color: #92400E; }
.seg-badge-fail { background: #FEE2E2; color: #991B1B; }

/* ================================================================ */
/* STATUS BADGES                                                     */
/* ================================================================ */

.seg-status-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.seg-status-pass { background: #D1FAE5; color: #065F46; }
.seg-status-partial { background: #FEF3C7; color: #92400E; }
.seg-status-refused { background: #FEE2E2; color: #991B1B; }

/* ================================================================ */
/* EXECUTIVE SUMMARY — callout cards with left border                */
/* ================================================================ */

.seg-callout {
  background: #f8fafa;
  border-left: 3px solid var(--seg-brand);
  padding: 12px 16px;
  border-radius: 0 6px 6px 0;
  margin-bottom: 10px;
}

.seg-callout-title {
  font-weight: 600;
  font-size: 14px;
  margin-bottom: 4px;
  color: var(--seg-text);
}

.seg-callout-text {
  font-size: 13px;
  color: var(--seg-text-muted);
}

.seg-quality-banner {
  padding: 12px 16px;
  border-radius: 6px;
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.5;
}

.seg-quality-excellent { background: #D1FAE5; border-left: 4px solid var(--seg-success); }
.seg-quality-good { background: #DBEAFE; border-left: 4px solid #2563EB; }
.seg-quality-moderate { background: #FEF3C7; border-left: 4px solid var(--seg-warning); }
.seg-quality-limited { background: #FEE2E2; border-left: 4px solid var(--seg-danger); }

.seg-finding-box {
  margin-bottom: 16px;
  padding: 14px 16px;
  background: #f8f9fa;
  border-radius: 6px;
}

.seg-finding-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-bottom: 6px;
}

.seg-finding-icon {
  font-size: 16px;
  font-weight: 700;
  flex-shrink: 0;
}

.seg-finding-text {
  font-size: 13px;
  color: var(--seg-text);
  line-height: 1.4;
}

.seg-key-insights-heading {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--seg-text);
}

.seg-key-insight-item {
  color: var(--seg-text);
  font-size: 13px;
  margin-bottom: 6px;
  line-height: 1.5;
}

.seg-panel-heading-label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--seg-text);
}

/* ================================================================ */
/* IMPORTANCE BARS                                                   */
/* ================================================================ */

.seg-bar-container {
  height: 16px;
  background: #f1f5f9;
  border-radius: 8px;
  overflow: hidden;
}

.seg-bar-fill {
  height: 100%;
  border-radius: 8px;
  transition: width 0.3s ease;
}

/* ================================================================ */
/* CHARTS                                                            */
/* ================================================================ */

.seg-chart { width: 100%; max-width: 700px; height: auto; margin: 16px 0; display: block; }

.seg-chart-wrapper,
.seg-table-wrapper {
  position: relative;
  margin-bottom: 8px;
}

.seg-component-pin {
  position: absolute;
  top: 4px;
  right: 4px;
  z-index: 10;
  background: rgba(255,255,255,0.85);
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  padding: 2px 8px;
  font-size: 11px;
  font-weight: 500;
  color: #94a3b8;
  cursor: pointer;
  opacity: 0;
  transition: all 0.15s;
}

.seg-chart-wrapper:hover .seg-component-pin,
.seg-table-wrapper:hover .seg-component-pin {
  opacity: 1;
}

.seg-component-pin:hover {
  border-color: var(--seg-brand);
  color: var(--seg-brand);
  background: rgba(255,255,255,0.97);
  box-shadow: 0 1px 3px rgba(0,0,0,0.06);
}

.seg-component-pin.seg-pin-btn-active {
  background: var(--seg-brand);
  color: white;
  border-color: var(--seg-brand);
  opacity: 1;
  box-shadow: 0 1px 3px rgba(50,51,103,0.2);
}

/* ================================================================ */
/* SEGMENT ACTION CARDS                                              */
/* ================================================================ */

.seg-cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 16px;
  margin-top: 12px;
}

.seg-action-card {
  background: #f8f9fa;
  border: 1px solid var(--seg-border);
  border-radius: 8px;
  padding: 16px 20px;
  border-top: 3px solid var(--seg-brand);
  transition: box-shadow 0.15s;
}

.seg-action-card:hover {
  box-shadow: 0 2px 12px rgba(0,0,0,0.06);
}

.seg-action-card-name {
  font-size: 16px;
  font-weight: 700;
  color: var(--seg-brand);
  margin-bottom: 4px;
}

.seg-action-card-size {
  font-size: 12px;
  color: var(--seg-text-muted);
  margin-bottom: 10px;
}

.seg-action-card-label {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  color: var(--seg-text-faint);
  margin-bottom: 4px;
  margin-top: 10px;
}

.seg-action-card-text {
  font-size: 13px;
  color: var(--seg-text);
  line-height: 1.5;
}

.seg-action-card-list {
  font-size: 13px;
  color: var(--seg-text);
  padding-left: 16px;
  line-height: 1.6;
}

/* ================================================================ */
/* FIT STATISTIC CARDS (validation metrics)                          */
/* ================================================================ */

.seg-fit-cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
  margin-top: 8px;
}

.seg-fit-card {
  background: #f8f9fa;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 12px 16px;
  border-left: 3px solid var(--seg-brand);
}

.seg-fit-card-value {
  font-size: 18px;
  font-weight: 700;
  color: #1e293b;
  font-variant-numeric: tabular-nums;
}

.seg-fit-card-label {
  font-size: 12px;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  margin-top: 2px;
}

.seg-fit-card-quality {
  font-size: 11px;
  font-weight: 600;
  color: var(--seg-brand);
  margin-top: 4px;
}

.seg-fit-card-note {
  font-size: 11px;
  color: #94a3b8;
  line-height: 1.4;
  margin-top: 6px;
}

/* ================================================================ */
/* INSIGHT EDITORS — per-section editable text areas                  */
/* ================================================================ */

.seg-insight-area {
  margin-bottom: 12px;
}

.seg-insight-toggle {
  background: none;
  border: 1px dashed var(--seg-border);
  border-radius: 6px;
  padding: 6px 14px;
  font-size: 12px;
  font-weight: 500;
  color: var(--seg-text-muted);
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s;
}

.seg-insight-toggle:hover {
  border-color: var(--seg-brand);
  color: var(--seg-brand);
  background: rgba(50,51,103,0.03);
}

.seg-insight-container {
  display: none;
  margin-top: 8px;
  position: relative;
}

.seg-insight-editor {
  width: 100%;
  min-height: 60px;
  padding: 10px 14px;
  border: 1px solid var(--seg-border);
  border-radius: 6px;
  font-size: 13px;
  font-family: inherit;
  line-height: 1.5;
  color: var(--seg-text);
  outline: none;
  transition: border-color 0.15s;
}

.seg-insight-editor:focus {
  border-color: var(--seg-brand);
  box-shadow: 0 0 0 2px rgba(50,51,103,0.08);
}

.seg-insight-editor:empty::before {
  content: attr(data-placeholder);
  color: var(--seg-text-faint);
  pointer-events: none;
}

.seg-insight-dismiss {
  position: absolute;
  top: 4px;
  right: 4px;
  background: none;
  border: none;
  font-size: 14px;
  color: var(--seg-text-faint);
  cursor: pointer;
  padding: 2px 6px;
  border-radius: 4px;
  transition: all 0.15s;
}

.seg-insight-dismiss:hover {
  color: var(--seg-danger);
  background: rgba(192,57,43,0.06);
}

/* ================================================================ */
/* PIN BUTTON                                                        */
/* ================================================================ */

.seg-pin-btn {
  background: none;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  padding: 3px 8px;
  font-size: 14px;
  cursor: pointer;
  color: #94a3b8;
  transition: all 0.15s;
  flex-shrink: 0;
  margin-left: 8px;
}

.seg-pin-btn:hover {
  border-color: var(--seg-brand);
  color: var(--seg-brand);
  background: rgba(50,51,103,0.04);
  box-shadow: 0 1px 3px rgba(0,0,0,0.06);
}

.seg-pin-btn.seg-pin-btn-active {
  background: var(--seg-brand);
  color: white;
  border-color: var(--seg-brand);
  box-shadow: 0 1px 3px rgba(50,51,103,0.2);
}

/* ================================================================ */
/* PINNED VIEWS PANEL                                                */
/* ================================================================ */

.seg-pinned-panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}

.seg-pinned-panel-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--seg-brand);
}

.seg-pinned-panel-actions {
  display: flex;
  gap: 8px;
}

.seg-pinned-panel-btn {
  padding: 6px 14px;
  border: 1px solid var(--seg-border);
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  color: var(--seg-text-muted);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.seg-pinned-panel-btn:hover {
  border-color: var(--seg-brand);
  color: var(--seg-brand);
}

.seg-pinned-empty {
  text-align: center;
  padding: 48px 24px;
  color: var(--seg-text-faint);
  font-size: 14px;
}

.seg-pinned-empty-icon {
  font-size: 32px;
  margin-bottom: 8px;
  opacity: 0.4;
}

.seg-pinned-card {
  background: var(--seg-card);
  border: 1px solid var(--seg-border);
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 16px;
  transition: box-shadow 0.15s;
}

.seg-pinned-card:hover {
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}

.seg-pinned-card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 10px;
}

.seg-pinned-card-title {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.seg-pinned-card-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--seg-brand);
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.seg-pinned-card-section {
  font-size: 15px;
  font-weight: 600;
  color: var(--seg-text);
}

.seg-pinned-card-actions {
  display: flex;
  gap: 4px;
  flex-shrink: 0;
}

.seg-pinned-action-btn {
  background: none;
  border: 1px solid transparent;
  border-radius: 4px;
  padding: 3px 7px;
  font-size: 12px;
  cursor: pointer;
  color: var(--seg-text-faint);
  transition: all 0.15s;
}

.seg-pinned-action-btn:hover {
  border-color: var(--seg-border);
  color: var(--seg-text-muted);
  background: #f8f9fa;
}

.seg-pinned-remove-btn:hover {
  color: var(--seg-danger);
  background: rgba(192,57,43,0.06);
}

.seg-pinned-export-btn:hover {
  color: var(--seg-brand);
  background: rgba(50,51,103,0.04);
}

.seg-pinned-card-insight {
  padding: 10px 14px;
  border-left: 3px solid var(--seg-accent);
  background: #faf9f7;
  border-radius: 0 6px 6px 0;
  font-size: 13px;
  color: #475569;
  line-height: 1.5;
  margin-bottom: 10px;
}

.seg-pinned-card-chart {
  margin-top: 10px;
  overflow: visible;
}

.seg-pinned-card-chart svg {
  width: 100%;
  height: auto;
  display: block;
}

.seg-pinned-card-table {
  margin-top: 10px;
  overflow-x: auto;
  overflow-y: visible;
}

.seg-pinned-card-table table {
  width: 100%;
  font-size: 12px;
  table-layout: fixed;
}

.seg-pinned-card-table th,
.seg-pinned-card-table td {
  word-wrap: break-word;
  overflow-wrap: break-word;
}

/* ================================================================ */
/* SECTION DIVIDERS                                                  */
/* ================================================================ */

.seg-section-divider {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 0;
  margin: 8px 0;
  border-bottom: 2px solid var(--seg-brand);
}

.seg-section-divider-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--seg-brand);
  flex: 1;
  outline: none;
  min-width: 100px;
}

.seg-section-divider-title:focus {
  border-bottom: 1px dashed var(--seg-border);
}

.seg-section-divider-actions {
  display: flex;
  gap: 4px;
}

/* ================================================================ */
/* ACTION BAR                                                        */
/* ================================================================ */

.seg-action-bar {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  padding: 8px 24px;
  background: var(--seg-card);
  border-bottom: 1px solid var(--seg-border);
}

.seg-save-btn {
  padding: 7px 18px;
  border: 1px solid var(--seg-brand);
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  color: var(--seg-brand);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.seg-save-btn:hover {
  background: var(--seg-brand);
  color: white;
}

.seg-saved-badge {
  display: none;
  opacity: 0;
  transition: opacity 0.3s ease;
  font-size: 11px;
  color: var(--seg-text-faint);
  font-weight: 400;
}

.seg-pin-count-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  background: var(--seg-accent);
  color: white;
  border-radius: 9px;
  font-size: 10px;
  font-weight: 700;
  margin-left: 6px;
}

/* ================================================================ */
/* INTERPRETATION GUIDE — DO/DONT grid                               */
/* ================================================================ */

.seg-interp-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.seg-interp-list {
  font-size: 13px;
  color: var(--seg-text-muted);
  padding-left: 16px;
}

.seg-interp-list li { margin-bottom: 6px; line-height: 1.4; }

.seg-interp-note {
  margin-top: 16px;
  padding: 12px 16px;
  background: #f8fafa;
  border-radius: 6px;
  border-left: 3px solid var(--seg-brand);
  font-size: 12px;
  color: var(--seg-text-muted);
  line-height: 1.5;
}

/* ================================================================ */
/* FOOTER                                                            */
/* ================================================================ */

.seg-footer {
  text-align: center;
  padding: 24px;
  color: var(--seg-text-faint);
  font-size: 11px;
  border-top: 1px solid var(--seg-border);
  margin-top: 32px;
}

/* ================================================================ */
/* PRINT STYLES                                                      */
/* ================================================================ */

@media print {
  .seg-report-tabs { display: none !important; }
  .seg-section-nav { display: none !important; }
  .seg-action-bar { display: none !important; }
  .seg-pin-btn { display: none !important; }
  .seg-component-pin { display: none !important; }
  .seg-insight-toggle { display: none !important; }
  .seg-insight-area { display: none !important; }
  .seg-pinned-card-actions { display: none !important; }
  .seg-content { padding: 16px !important; max-width: none !important; }
  .seg-body { background: white; font-size: 11px; }
  .seg-section { break-inside: avoid; page-break-inside: avoid; border: none; box-shadow: none; }
  .seg-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .seg-header-inner { max-width: none !important; }
  .seg-header-inner * { color: #1a2744 !important; }
  .seg-header-module-name { font-size: 16px !important; }
  .seg-header-title { font-size: 14px !important; margin-top: 4px !important; }
  .seg-header-logo-container { width: 32px !important; height: 32px !important; }
  .seg-header-logo-container img { width: 28px !important; height: 28px !important; }
  .seg-chart { max-width: 500px; }
}

@media (max-width: 768px) {
  .seg-section-nav { padding: 0 12px; }
  .seg-section-nav a { padding: 10px 14px; font-size: 12px; }
  .seg-content { padding: 16px; }
  .seg-interp-grid { grid-template-columns: 1fr; }
  .seg-header { padding: 16px; }
  .seg-header-module-name { font-size: 20px; }
  .seg-header-title { font-size: 18px; }
  .seg-cards-grid { grid-template-columns: 1fr; }
}
'
  css <- gsub("BRAND_COLOUR", brand_colour, css, fixed = TRUE)
  css <- gsub("ACCENT_COLOUR", accent_colour, css, fixed = TRUE)
  css
}


# ==============================================================================
# SECTION NAVIGATION
# ==============================================================================

#' Build Section Navigation Bar
#'
#' Creates a sticky horizontal nav bar below the header with section links.
#' Only shows sections where show=TRUE in sections_config.
#'
#' @param brand_colour Brand colour hex string
#' @param sections_config Named list of list(label, show) entries
#' @return htmltools tag
#' @keywords internal
build_seg_section_nav <- function(brand_colour = "#323367", sections_config = list()) {

  links <- list()
  first <- TRUE
  for (key in names(sections_config)) {
    sec <- sections_config[[key]]
    if (!isTRUE(sec$show)) next

    active_class <- if (first) "active" else NULL
    first <- FALSE

    links <- c(links, list(
      htmltools::tags$a(
        href = paste0("#seg-", key),
        class = active_class,
        sec$label
      )
    ))
  }

  htmltools::tags$nav(
    class = "seg-section-nav",
    id = "seg-section-nav",
    links
  )
}


# ==============================================================================
# HEADER
# ==============================================================================

#' Build Header Section
#'
#' Creates the gradient banner header with module name, report title,
#' prepared-by text, and badge bar showing method, k, n, and date.
#'
#' @param html_data Transformed HTML data
#' @param config Configuration list
#' @param brand_colour Brand colour hex string
#' @param report_title Report title text
#' @return htmltools tag
#' @keywords internal
build_seg_header <- function(html_data, config, brand_colour, report_title) {

  method_label <- switch(tolower(html_data$method %||% "kmeans"),
    kmeans  = "K-Means",
    pam     = "PAM (K-Medoids)",
    hclust  = "Hierarchical",
    gmm     = "GMM (Gaussian Mixture)",
    mclust  = "GMM (Gaussian Mixture)",
    lca     = "Latent Class",
    html_data$method
  )

  # --- Researcher Logo ---
  logo_el <- NULL
  if (exists("resolve_logo_uri", mode = "function")) {
    logo_uri <- resolve_logo_uri(config$researcher_logo_path)
    if (!is.null(logo_uri) && nzchar(logo_uri)) {
      logo_el <- htmltools::tags$div(
        class = "seg-header-logo-container",
        htmltools::tags$img(
          src = logo_uri,
          alt = "Logo",
          style = "height:56px;width:56px;object-fit:contain;"
        )
      )
    }
  }

  # --- Client Logo ---
  client_logo_el <- NULL
  if (exists("resolve_logo_uri", mode = "function")) {
    client_logo_uri <- resolve_logo_uri(config$client_logo_path)
    if (!is.null(client_logo_uri) && nzchar(client_logo_uri)) {
      client_logo_el <- htmltools::tags$div(
        class = "seg-header-logo-container",
        style = "margin-left:auto;",
        htmltools::tags$img(
          src = client_logo_uri,
          alt = "Client Logo",
          style = "height:56px;width:56px;object-fit:contain;"
        )
      )
    }
  }

  # --- Top row: [logo] TURAS SEGMENTATION / method subtitle [client logo] ---
  method_subtitle <- sprintf("%s Cluster Analysis", method_label)

  branding_left <- htmltools::tags$div(
    class = "seg-header-branding",
    logo_el,
    htmltools::tags$div(
      htmltools::tags$div(class = "seg-header-module-name", "TURAS Segmentation"),
      htmltools::tags$div(class = "seg-header-module-sub", method_subtitle)
    ),
    client_logo_el
  )

  top_row <- htmltools::tags$div(
    class = "seg-header-top",
    branding_left
  )

  # --- Project title ---
  title_row <- htmltools::tags$div(
    class = "seg-header-title",
    report_title
  )

  # --- Prepared by / for text ---
  prepared_row <- NULL
  company_name <- config$company_name %||% "The Research Lamppost"
  client_name <- config$client_name %||% NULL
  researcher_name <- config$researcher_name %||% NULL
  prepared_parts <- c()

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
      class = "seg-header-prepared",
      htmltools::HTML(paste(prepared_parts, collapse = " "))
    )
  }

  # --- Badge bar ---
  badge_items <- list()

  # Method badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "seg-header-badge",
    htmltools::HTML(sprintf(
      '<span class="seg-header-badge-val">%s</span>',
      method_label
    ))
  )))

  # Segments badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "seg-header-badge",
    htmltools::HTML(sprintf(
      'Segments:&nbsp;<span class="seg-header-badge-val">%d</span>',
      html_data$k %||% 0L
    ))
  )))

  # Sample size badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "seg-header-badge",
    htmltools::HTML(sprintf(
      'n&nbsp;=&nbsp;<span class="seg-header-badge-val">%s</span>',
      format(html_data$n_observations %||% 0L, big.mark = ",")
    ))
  )))

  # Date badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "seg-header-badge",
    format(Sys.Date(), "Created %b %Y")
  )))

  # Interleave with separators
  badge_els <- list()
  for (i in seq_along(badge_items)) {
    if (i > 1) {
      badge_els <- c(badge_els, list(
        htmltools::tags$span(class = "seg-header-badge-sep")
      ))
    }
    badge_els <- c(badge_els, list(badge_items[[i]]))
  }

  badges_bar <- htmltools::tags$div(
    class = "seg-header-badges",
    badge_els
  )

  # --- Assemble header ---
  htmltools::tags$div(
    class = "seg-header",
    id = "seg-header",
    htmltools::tags$div(
      class = "seg-header-inner",
      top_row,
      title_row,
      prepared_row,
      badges_bar
    )
  )
}


# ==============================================================================
# SECTION TITLE ROW — title + pin button
# ==============================================================================

#' Build Section Title Row
#'
#' Wraps a section title and pin button in a flex row.
#'
#' @param title_text Title text
#' @param section_key Section key for pinning
#' @param show_pin Whether to show the pin button (default TRUE)
#' @return htmltools tag
#' @keywords internal
build_seg_section_title_row <- function(title_text, section_key,
                                         show_pin = TRUE) {
  pin_btn <- if (show_pin) {
    htmltools::tags$button(
      class = "seg-pin-btn",
      `data-seg-pin-section` = section_key,
      onclick = sprintf("segPinSection('%s')", section_key),
      title = "Pin this section",
      "\U0001F4CC Pin"
    )
  }

  htmltools::tags$div(
    class = "seg-section-title-row",
    htmltools::tags$h2(class = "seg-section-title", title_text),
    pin_btn
  )
}


# ==============================================================================
# INSIGHT AREA — editable text per section
# ==============================================================================

#' Build Insight Area
#'
#' Creates the editable insight area: toggle button + hidden editor.
#'
#' @param section_key Section key string
#' @return htmltools tagList
#' @keywords internal
build_seg_insight_area <- function(section_key) {
  htmltools::tags$div(
    class = "seg-insight-area",
    `data-seg-insight-section` = section_key,
    htmltools::tags$button(
      class = "seg-insight-toggle",
      id = paste0("seg-insight-toggle-", section_key),
      onclick = sprintf("segToggleInsight('%s')", section_key),
      "+ Add Insight"
    ),
    htmltools::tags$div(
      class = "seg-insight-container",
      id = paste0("seg-insight-container-", section_key),
      htmltools::tags$div(
        class = "seg-insight-editor",
        contenteditable = "true",
        `data-placeholder` = "Type your insight or comment here...",
        oninput = sprintf("segSyncInsight('%s')", section_key)
      ),
      htmltools::tags$button(
        class = "seg-insight-dismiss",
        onclick = sprintf("segDismissInsight('%s')", section_key),
        "\u00D7"
      )
    )
  )
}


# ==============================================================================
# COMPONENT PIN BUTTON
# ==============================================================================

#' Build Component Pin Button
#'
#' Small ghost-style pin button for individual chart/table pinning.
#'
#' @param section_key Section key
#' @param component Component type: "chart" or "table"
#' @return htmltools tag
#' @keywords internal
build_seg_component_pin_btn <- function(section_key, component) {
  comp_label <- if (component == "chart") "\u2295 Chart" else "\u2295 Table"
  htmltools::tags$button(
    class = "seg-component-pin",
    `data-seg-pin-section` = section_key,
    `data-seg-pin-component` = component,
    onclick = sprintf("segPinComponent('%s','%s')", section_key, component),
    title = sprintf("Pin %s only", component),
    comp_label
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
build_seg_action_bar <- function(report_title = "Segment Report") {
  htmltools::tags$div(
    class = "seg-action-bar",
    htmltools::tags$span(
      class = "seg-saved-badge",
      id = "seg-saved-badge"
    ),
    htmltools::tags$button(
      class = "seg-save-btn",
      onclick = "segSaveReportHTML()",
      "\U0001F4BE Save Report"
    )
  )
}


# ==============================================================================
# EXECUTIVE SUMMARY SECTION
# ==============================================================================

#' Build Executive Summary Section
#'
#' Displays a quality banner, key findings, and segment overview callouts.
#'
#' @param html_data Transformed HTML data
#' @param brand_colour Brand colour hex string
#' @return htmltools tag
#' @keywords internal
build_seg_exec_summary_section <- function(html_data, brand_colour) {

  diag <- html_data$diagnostics

  # Quality banner based on silhouette score
  quality_html <- NULL
  avg_sil <- diag$avg_silhouette
  if (!is.null(avg_sil) && !is.na(avg_sil)) {
    if (avg_sil >= 0.50) {
      q_class <- "seg-quality-excellent"
      q_text <- sprintf(
        "Strong cluster structure (avg. silhouette = %.3f). The %d segments are well-separated and internally cohesive.",
        avg_sil, html_data$k
      )
    } else if (avg_sil >= 0.35) {
      q_class <- "seg-quality-good"
      q_text <- sprintf(
        "Good cluster structure (avg. silhouette = %.3f). The %d segments show reasonable separation with some overlap.",
        avg_sil, html_data$k
      )
    } else if (avg_sil >= 0.25) {
      q_class <- "seg-quality-moderate"
      q_text <- sprintf(
        "Moderate cluster structure (avg. silhouette = %.3f). The %d segments show partial overlap. Consider reviewing the number of segments.",
        avg_sil, html_data$k
      )
    } else {
      q_class <- "seg-quality-limited"
      q_text <- sprintf(
        "Weak cluster structure (avg. silhouette = %.3f). The %d segments have substantial overlap. Consider a different k or method.",
        avg_sil, html_data$k
      )
    }

    quality_html <- htmltools::tags$div(
      class = paste("seg-quality-banner", q_class),
      htmltools::tags$strong("Segmentation Quality: "),
      q_text
    )
  }

  # Executive summary findings (from enhanced analysis)
  exec <- html_data$exec_summary
  findings_html <- NULL
  if (!is.null(exec) && is.list(exec)) {
    finding_items <- list()

    # Key findings text
    if (!is.null(exec$key_findings) && length(exec$key_findings) > 0) {
      for (finding in exec$key_findings) {
        finding_items <- c(finding_items, list(
          htmltools::tags$div(
            class = "seg-finding-item",
            htmltools::tags$span(class = "seg-finding-icon",
                                style = "color:var(--seg-brand);", "\u2022"),
            htmltools::tags$span(class = "seg-finding-text", finding)
          )
        ))
      }
    }

    # Summary text
    if (!is.null(exec$summary) && nzchar(exec$summary %||% "")) {
      finding_items <- c(list(
        htmltools::tags$div(
          class = "seg-finding-item",
          htmltools::tags$span(class = "seg-finding-icon",
                              style = "color:var(--seg-brand);", "\u25B6"),
          htmltools::tags$span(class = "seg-finding-text",
                              style = "font-weight:600;", exec$summary)
        )
      ), finding_items)
    }

    if (length(finding_items) > 0) {
      findings_html <- htmltools::tags$div(
        class = "seg-finding-box",
        htmltools::tags$h3(class = "seg-key-insights-heading", "Key Findings"),
        finding_items
      )
    }
  }

  # Segment size overview callouts
  sizes <- html_data$segment_sizes
  size_callouts <- NULL
  if (!is.null(sizes) && nrow(sizes) > 0) {
    callout_items <- lapply(seq_len(nrow(sizes)), function(i) {
      row <- sizes[i, ]
      htmltools::tags$div(
        class = "seg-callout",
        htmltools::tags$div(class = "seg-callout-title",
                            sprintf("%s (n=%s, %s%%)",
                                    row$segment_name,
                                    format(row$n, big.mark = ","),
                                    row$pct)),
        if (!is.null(html_data$segment_names) &&
            length(html_data$segment_names) >= row$segment_id) {
          htmltools::tags$div(class = "seg-callout-text",
                              sprintf("Segment %d of %d", row$segment_id, html_data$k))
        }
      )
    })
    size_callouts <- htmltools::tagList(callout_items)
  }

  # Build section
  title_row <- build_seg_section_title_row("Executive Summary", "exec-summary")
  insight_area <- build_seg_insight_area("exec-summary")

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-exec-summary",
    `data-seg-section` = "exec-summary",
    title_row,
    insight_area,
    quality_html,
    findings_html,
    size_callouts
  )
}


# ==============================================================================
# OVERVIEW SECTION
# ==============================================================================

#' Build Overview Section
#'
#' Displays segment sizes bar chart and overview table.
#'
#' @param tables Named list of table objects
#' @param charts Named list of chart objects
#' @param html_data Transformed HTML data
#' @return htmltools tag
#' @keywords internal
build_seg_overview_section <- function(tables, charts, html_data) {

  title_row <- build_seg_section_title_row("Segment Overview", "overview")
  insight_area <- build_seg_insight_area("overview")

  # Chart wrapper
  chart_el <- NULL
  if (!is.null(charts$overview)) {
    chart_el <- htmltools::tags$div(
      class = "seg-chart-wrapper",
      build_seg_component_pin_btn("overview", "chart"),
      charts$overview
    )
  }

  # Table wrapper
  table_el <- NULL
  if (!is.null(tables$overview)) {
    table_el <- htmltools::tags$div(
      class = "seg-table-wrapper",
      build_seg_component_pin_btn("overview", "table"),
      tables$overview
    )
  }

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-overview",
    `data-seg-section` = "overview",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      sprintf("Overview of the %d segments identified using %s clustering on %s observations.",
              html_data$k %||% 0,
              html_data$method %||% "k-means",
              format(html_data$n_observations %||% 0, big.mark = ","))
    ),
    chart_el,
    table_el
  )
}


# ==============================================================================
# VALIDATION SECTION
# ==============================================================================

#' Build Validation Section
#'
#' Displays silhouette chart, validation metrics table, and quality interpretation.
#'
#' @param tables Named list of table objects
#' @param charts Named list of chart objects
#' @param html_data Transformed HTML data
#' @return htmltools tag
#' @keywords internal
build_seg_validation_section <- function(tables, charts, html_data) {

  title_row <- build_seg_section_title_row("Cluster Validation", "validation")
  insight_area <- build_seg_insight_area("validation")

  diag <- html_data$diagnostics

  # Validation metric cards
  fit_cards <- list()

  # Average silhouette card
  if (!is.null(diag$avg_silhouette) && !is.na(diag$avg_silhouette)) {
    sil_val <- diag$avg_silhouette
    sil_label <- if (sil_val >= 0.50) "Strong"
                 else if (sil_val >= 0.35) "Good"
                 else if (sil_val >= 0.25) "Moderate"
                 else "Weak"

    fit_cards <- c(fit_cards, list(htmltools::tags$div(
      class = "seg-fit-card",
      htmltools::tags$div(class = "seg-fit-card-value",
                          sprintf("%.3f", sil_val)),
      htmltools::tags$div(class = "seg-fit-card-label",
                          "Average Silhouette"),
      htmltools::tags$div(class = "seg-fit-card-quality", sil_label),
      htmltools::tags$div(class = "seg-fit-card-note",
                          "Measures how similar objects are to their own cluster vs. other clusters. Range: -1 to 1. Values > 0.5 indicate strong structure.")
    )))
  }

  # Between-SS / Total-SS card
  if (!is.null(diag$betweenss_totss) && !is.na(diag$betweenss_totss)) {
    bss_val <- diag$betweenss_totss
    bss_pct <- round(bss_val * 100, 1)
    bss_label <- if (bss_val >= 0.70) "Excellent"
                 else if (bss_val >= 0.50) "Good"
                 else if (bss_val >= 0.30) "Moderate"
                 else "Limited"

    fit_cards <- c(fit_cards, list(htmltools::tags$div(
      class = "seg-fit-card",
      htmltools::tags$div(class = "seg-fit-card-value",
                          sprintf("%.1f%%", bss_pct)),
      htmltools::tags$div(class = "seg-fit-card-label",
                          "Between-SS / Total-SS"),
      htmltools::tags$div(class = "seg-fit-card-quality", bss_label),
      htmltools::tags$div(class = "seg-fit-card-note",
                          "Proportion of total variance explained by cluster separation. Higher values mean clusters account for more of the data variation.")
    )))
  }

  # Number of variables card
  if (!is.null(diag$n_variables) && !is.na(diag$n_variables)) {
    fit_cards <- c(fit_cards, list(htmltools::tags$div(
      class = "seg-fit-card",
      htmltools::tags$div(class = "seg-fit-card-value",
                          sprintf("%d", diag$n_variables)),
      htmltools::tags$div(class = "seg-fit-card-label",
                          "Clustering Variables"),
      htmltools::tags$div(class = "seg-fit-card-note",
                          "Number of variables used in the clustering algorithm. More variables can capture complexity but may introduce noise.")
    )))
  }

  fit_html <- if (length(fit_cards) > 0) {
    htmltools::tags$div(
      style = "margin-bottom:16px;",
      htmltools::tags$h3(class = "seg-panel-heading-label",
                         "Validation Metrics"),
      htmltools::tags$div(class = "seg-fit-cards-grid", fit_cards)
    )
  }

  # Silhouette chart
  chart_el <- NULL
  if (!is.null(charts$silhouette)) {
    chart_el <- htmltools::tags$div(
      class = "seg-chart-wrapper",
      build_seg_component_pin_btn("validation", "chart"),
      charts$silhouette
    )
  }

  # Validation table
  table_el <- NULL
  if (!is.null(tables$validation)) {
    table_el <- htmltools::tags$div(
      class = "seg-table-wrapper",
      build_seg_component_pin_btn("validation", "table"),
      tables$validation
    )
  }

  # Quality interpretation
  interp_html <- NULL
  avg_sil <- diag$avg_silhouette
  if (!is.null(avg_sil) && !is.na(avg_sil)) {
    interp_items <- list(
      htmltools::tags$tr(
        htmltools::tags$td(class = "seg-td", style = "font-weight:600;", "0.71 - 1.00"),
        htmltools::tags$td(class = "seg-td", "Strong structure"),
        htmltools::tags$td(class = "seg-td seg-td-high", "Clusters are well-separated and clearly defined")
      ),
      htmltools::tags$tr(
        htmltools::tags$td(class = "seg-td", style = "font-weight:600;", "0.51 - 0.70"),
        htmltools::tags$td(class = "seg-td", "Reasonable structure"),
        htmltools::tags$td(class = "seg-td seg-td-mod-high", "Good separation with minor overlap")
      ),
      htmltools::tags$tr(
        htmltools::tags$td(class = "seg-td", style = "font-weight:600;", "0.26 - 0.50"),
        htmltools::tags$td(class = "seg-td", "Weak structure"),
        htmltools::tags$td(class = "seg-td seg-td-mod-low", "Clusters overlap significantly; consider alternative k")
      ),
      htmltools::tags$tr(
        htmltools::tags$td(class = "seg-td", style = "font-weight:600;", "\u2264 0.25"),
        htmltools::tags$td(class = "seg-td", "No structure"),
        htmltools::tags$td(class = "seg-td seg-td-low", "Data may not have natural groupings at this k")
      )
    )

    interp_html <- htmltools::tags$div(
      style = "margin-top:16px;",
      htmltools::tags$h3(class = "seg-panel-heading-label",
                         "Silhouette Score Interpretation"),
      htmltools::tags$table(
        class = "seg-table",
        htmltools::tags$thead(
          htmltools::tags$tr(
            htmltools::tags$th(class = "seg-th", "Range"),
            htmltools::tags$th(class = "seg-th", "Interpretation"),
            htmltools::tags$th(class = "seg-th", "Meaning")
          )
        ),
        htmltools::tags$tbody(interp_items)
      )
    )
  }

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-validation",
    `data-seg-section` = "validation",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      "Cluster validation metrics assess how well-defined and separated the segments are. Higher silhouette scores indicate better-defined clusters."
    ),
    fit_html,
    chart_el,
    table_el,
    interp_html
  )
}


# ==============================================================================
# IMPORTANCE SECTION
# ==============================================================================

#' Build Variable Importance Section
#'
#' Displays variable importance bars and table showing which variables
#' best differentiate the segments (based on eta-squared from ANOVA).
#'
#' @param tables Named list of table objects
#' @param charts Named list of chart objects
#' @param html_data Transformed HTML data
#' @return htmltools tag
#' @keywords internal
build_seg_importance_section <- function(tables, charts, html_data) {

  title_row <- build_seg_section_title_row("Variable Importance", "importance")
  insight_area <- build_seg_insight_area("importance")

  # Chart wrapper
  chart_el <- NULL
  if (!is.null(charts$importance)) {
    chart_el <- htmltools::tags$div(
      class = "seg-chart-wrapper",
      build_seg_component_pin_btn("importance", "chart"),
      charts$importance
    )
  }

  # Table wrapper
  table_el <- NULL
  if (!is.null(tables$importance)) {
    table_el <- htmltools::tags$div(
      class = "seg-table-wrapper",
      build_seg_component_pin_btn("importance", "table"),
      tables$importance
    )
  }

  # Interpretation callout — adapts to the metric available
  vi <- html_data$variable_importance
  metric_type <- if (!is.null(vi) && "importance_metric" %in% names(vi)) {
    vi$importance_metric[1]
  } else if (!is.null(vi) && "eta_squared" %in% names(vi)) {
    "eta_squared"
  } else {
    "f_statistic"
  }

  if (metric_type == "eta_squared") {
    callout_title <- "Understanding Eta-squared (&eta;&sup2;)"
    callout_body <- paste0(
      "Eta-squared measures the proportion of total variance in each variable explained by segment membership. Values range from 0 to 1:<br>",
      "<span style='display:inline-block;width:10px;height:10px;background:#dcfce7;border:1px solid #86efac;border-radius:2px;margin-right:4px;'></span> ",
      "<strong>&gt; 0.14</strong> = Large effect &mdash; strong differentiator<br>",
      "<span style='display:inline-block;width:10px;height:10px;background:#fef9c3;border:1px solid #fde047;border-radius:2px;margin-right:4px;'></span> ",
      "<strong>0.06 &ndash; 0.14</strong> = Medium effect &mdash; moderate differentiator<br>",
      "<span style='display:inline-block;width:10px;height:10px;background:#fee2e2;border:1px solid #fca5a5;border-radius:2px;margin-right:4px;'></span> ",
      "<strong>&lt; 0.06</strong> = Small effect &mdash; weak differentiator"
    )
  } else {
    callout_title <- "Understanding Variable Importance"
    callout_body <- paste0(
      "The chart shows each variable's share of total segment discrimination (as a percentage of total F-statistic). ",
      "The F-statistic from one-way ANOVA tests whether segment means differ significantly &mdash; higher F = greater difference between segments.<br><br>",
      "The percentage shows each variable's <strong>relative contribution</strong> to distinguishing the segments. ",
      "Variables at the top contribute most; those at the bottom contribute least and are candidates for removal."
    )
  }

  eta_callout <- htmltools::tags$div(
    class = "seg-callout-box",
    style = "background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:12px 16px; margin-bottom:16px; font-size:13px; color:#475569;",
    htmltools::tags$div(
      style = "margin-bottom:8px;",
      htmltools::tags$strong(htmltools::HTML(callout_title))
    ),
    htmltools::tags$div(
      style = "line-height:1.6;",
      htmltools::HTML(callout_body)
    )
  )

  # Question reduction analysis
  reduction_el <- NULL
  vi <- html_data$variable_importance
  if (!is.null(vi) && "cumulative_pct" %in% names(vi) && nrow(vi) > 1) {
    total_vars <- nrow(vi)
    thresholds <- c(80, 90, 95)
    reduction_items <- list()

    for (thresh in thresholds) {
      n_needed <- which(vi$cumulative_pct >= thresh)[1]
      if (!is.na(n_needed)) {
        actual_pct <- vi$cumulative_pct[n_needed]
        reduction_items <- c(reduction_items, list(
          htmltools::tags$div(
            style = "margin-bottom:4px;",
            htmltools::HTML(sprintf(
              "&bull; Top <strong>%d</strong> variable%s capture <strong>%.0f%%</strong> of segment discrimination",
              n_needed, if (n_needed > 1) "s" else "", actual_pct
            ))
          )
        ))
      }
    }

    if (length(reduction_items) > 0) {
      # Find the sweet spot: fewest questions for >= 90%
      n_for_90 <- which(vi$cumulative_pct >= 90)[1]
      recommendation <- if (!is.na(n_for_90) && n_for_90 < total_vars) {
        htmltools::tags$div(
          style = "margin-top:8px; padding-top:8px; border-top:1px solid #e2e8f0; font-weight:500; color:#334155;",
          htmltools::HTML(sprintf(
            "&rarr; You could reduce the questionnaire to <strong>%d item%s</strong> (from %d) and retain %.0f%% accuracy in segment assignment.",
            n_for_90, if (n_for_90 > 1) "s" else "", total_vars, vi$cumulative_pct[n_for_90]
          ))
        )
      }

      reduction_el <- htmltools::tags$div(
        class = "seg-callout-box",
        style = "background:#fffbeb; border:1px solid #fde68a; border-radius:8px; padding:12px 16px; margin-bottom:16px; font-size:13px; color:#475569;",
        htmltools::tags$div(
          style = "margin-bottom:8px;",
          htmltools::tags$strong("Question Reduction Analysis")
        ),
        htmltools::tags$div(style = "line-height:1.8;", reduction_items),
        recommendation
      )
    }
  }

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-importance",
    `data-seg-section` = "importance",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      "Variables ranked by their ability to differentiate segments, based on one-way ANOVA. Higher values indicate the variable contributes more to distinguishing the segments."
    ),
    eta_callout,
    chart_el,
    reduction_el,
    table_el
  )
}


# ==============================================================================
# PROFILES SECTION
# ==============================================================================

#' Build Segment Profiles Section
#'
#' Displays the profile heatmap and detailed profile table showing
#' mean scores per segment per variable.
#'
#' @param tables Named list of table objects
#' @param charts Named list of chart objects
#' @param html_data Transformed HTML data
#' @return htmltools tag
#' @keywords internal
build_seg_profiles_section <- function(tables, charts, html_data) {

  title_row <- build_seg_section_title_row("Segment Profiles", "profiles")
  insight_area <- build_seg_insight_area("profiles")

  # Heatmap chart
  chart_el <- NULL
  if (!is.null(charts$profiles)) {
    chart_el <- htmltools::tags$div(
      class = "seg-chart-wrapper",
      build_seg_component_pin_btn("profiles", "chart"),
      charts$profiles
    )
  }

  # Profile table
  table_el <- NULL
  if (!is.null(tables$profiles)) {
    table_el <- htmltools::tags$div(
      class = "seg-table-wrapper",
      build_seg_component_pin_btn("profiles", "table"),
      tables$profiles
    )
  }

  # F-statistic and color footnote
  footnote_el <- htmltools::tags$div(
    class = "seg-callout-box",
    style = "background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:12px 16px; margin-top:12px; font-size:12px; color:#64748b; line-height:1.6;",
    htmltools::HTML(paste0(
      "<strong>Table guide:</strong> ",
      "Cells are colour-coded relative to the overall mean: ",
      "<span style='display:inline-block;width:10px;height:10px;background:#dcfce7;border:1px solid #86efac;border-radius:2px;margin:0 2px;'></span> green = above average, ",
      "<span style='display:inline-block;width:10px;height:10px;background:#fee2e2;border:1px solid #fca5a5;border-radius:2px;margin:0 2px;'></span> red = below average. ",
      "<strong>F-statistic</strong>: from one-way ANOVA testing whether segment means differ significantly. ",
      "Higher F = greater difference between segments. Values &gt; 4 typically indicate statistically significant differences (p &lt; 0.05). ",
      "<strong>&eta;&sup2;</strong>: proportion of variance explained by segment membership (see Variable Importance for interpretation)."
    ))
  )

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-profiles",
    `data-seg-section` = "profiles",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      "Mean scores for each variable by segment. Cells are colour-coded: green indicates above-average scores, red indicates below-average scores relative to the overall sample mean."
    ),
    chart_el,
    table_el,
    footnote_el
  )
}


# ==============================================================================
# RULES SECTION
# ==============================================================================

#' Build Classification Rules Section
#'
#' Displays classification/decision rules if available from the enhanced analysis.
#'
#' @param tables Named list of table objects
#' @param html_data Transformed HTML data
#' @return htmltools tag
#' @keywords internal
build_seg_rules_section <- function(tables, html_data) {

  title_row <- build_seg_section_title_row("Classification Rules", "rules")
  insight_area <- build_seg_insight_area("rules")

  rules <- html_data$enhanced$classification_rules

  # Rules table
  table_el <- NULL
  if (!is.null(tables$rules)) {
    table_el <- htmltools::tags$div(
      class = "seg-table-wrapper",
      build_seg_component_pin_btn("rules", "table"),
      tables$rules
    )
  }

  # Accuracy info
  accuracy_html <- NULL
  if (!is.null(rules$accuracy) && !is.na(rules$accuracy)) {
    acc_pct <- round(rules$accuracy * 100, 1)
    acc_label <- if (acc_pct >= 90) "Excellent"
                 else if (acc_pct >= 80) "Good"
                 else if (acc_pct >= 70) "Moderate"
                 else "Limited"

    acc_class <- if (acc_pct >= 90) "seg-quality-excellent"
                 else if (acc_pct >= 80) "seg-quality-good"
                 else if (acc_pct >= 70) "seg-quality-moderate"
                 else "seg-quality-limited"

    accuracy_html <- htmltools::tags$div(
      class = paste("seg-quality-banner", acc_class),
      style = "margin-bottom:16px;",
      htmltools::tags$strong("Classification Accuracy: "),
      sprintf("%.1f%% (%s) - Rules correctly classify this proportion of observations into their segments.",
              acc_pct, acc_label)
    )
  }

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-rules",
    `data-seg-section` = "rules",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      "Decision rules derived from the segmentation that can be used to classify new respondents into segments. These rules use simple threshold-based logic on the clustering variables."
    ),
    accuracy_html,
    table_el
  )
}


# ==============================================================================
# SEGMENT CARDS SECTION
# ==============================================================================

#' Build Segment Action Cards Section
#'
#' Displays executive-ready segment summary cards with strengths,
#' pain points, and recommended actions.
#'
#' @param html_data Transformed HTML data
#' @return htmltools tag
#' @keywords internal
build_seg_cards_section <- function(html_data) {

  title_row <- build_seg_section_title_row("Segment Action Cards", "cards")
  insight_area <- build_seg_insight_area("cards")

  cards_data <- html_data$enhanced$segment_cards
  if (is.null(cards_data)) {
    return(htmltools::tags$div(
      class = "seg-section",
      id = "seg-cards",
      `data-seg-section` = "cards",
      title_row,
      insight_area,
      htmltools::tags$p(class = "seg-section-intro",
                        "Segment cards not available.")
    ))
  }

  # Build individual cards
  card_els <- lapply(cards_data, function(card) {
    # Strengths list
    strengths_el <- NULL
    if (!is.null(card$strengths) && length(card$strengths) > 0) {
      strengths_items <- lapply(card$strengths, function(s) {
        htmltools::tags$li(s)
      })
      strengths_el <- htmltools::tagList(
        htmltools::tags$div(class = "seg-action-card-label", "Strengths"),
        htmltools::tags$ul(class = "seg-action-card-list", strengths_items)
      )
    }

    # Pain points list
    pain_el <- NULL
    if (!is.null(card$pain_points) && length(card$pain_points) > 0) {
      pain_items <- lapply(card$pain_points, function(p) {
        htmltools::tags$li(p)
      })
      pain_el <- htmltools::tagList(
        htmltools::tags$div(class = "seg-action-card-label", "Pain Points"),
        htmltools::tags$ul(class = "seg-action-card-list", pain_items)
      )
    }

    # Actions list
    actions_el <- NULL
    if (!is.null(card$actions) && length(card$actions) > 0) {
      action_items <- lapply(card$actions, function(a) {
        htmltools::tags$li(a)
      })
      actions_el <- htmltools::tagList(
        htmltools::tags$div(class = "seg-action-card-label", "Recommended Actions"),
        htmltools::tags$ul(class = "seg-action-card-list", action_items)
      )
    }

    # Description
    desc_el <- NULL
    if (!is.null(card$description) && nzchar(card$description %||% "")) {
      desc_el <- htmltools::tags$div(
        class = "seg-action-card-text",
        card$description
      )
    }

    # Size info
    size_text <- ""
    if (!is.null(card$n) && !is.null(card$pct)) {
      size_text <- sprintf("n = %s (%s%%)",
                           format(card$n, big.mark = ","), card$pct)
    } else if (!is.null(card$n)) {
      size_text <- sprintf("n = %s", format(card$n, big.mark = ","))
    }

    htmltools::tags$div(
      class = "seg-action-card",
      htmltools::tags$div(class = "seg-action-card-name",
                          card$name %||% card$segment_name %||% "Segment"),
      if (nzchar(size_text)) {
        htmltools::tags$div(class = "seg-action-card-size", size_text)
      },
      desc_el,
      strengths_el,
      pain_el,
      actions_el
    )
  })

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-cards",
    `data-seg-section` = "cards",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      "Executive-ready summaries for each segment highlighting defining characteristics, strengths, pain points, and recommended actions."
    ),
    htmltools::tags$div(class = "seg-cards-grid", card_els)
  )
}


# ==============================================================================
# SEGMENT OVERLAP SECTION
# ==============================================================================

#' Build Segment Overlap Section
#'
#' Displays centroid distance heatmap showing pairwise segment similarity.
#'
#' @param charts Named list of chart objects
#' @param html_data Transformed HTML data
#' @return htmltools tag
#' @keywords internal
build_seg_overlap_section <- function(charts, html_data) {

  title_row <- build_seg_section_title_row("Segment Overlap", "overlap")
  insight_area <- build_seg_insight_area("overlap")

  chart_el <- if (!is.null(charts$overlap)) {
    htmltools::tags$div(
      class = "seg-chart-wrapper",
      build_seg_component_pin_btn("overlap", "chart"),
      htmltools::tags$div(class = "seg-chart", charts$overlap)
    )
  }

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-overlap",
    `data-seg-section` = "overlap",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      "Similarity between segment centroids. Higher percentages indicate segments that are more alike (potentially overlapping); lower percentages indicate well-separated, distinct segments."
    ),
    htmltools::tags$div(
      class = "seg-callout-box",
      style = "background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:12px 16px; margin-bottom:16px; font-size:13px; color:#475569;",
      htmltools::tags$strong("How to read: "),
      "Each cell shows how similar two segments are (0% = completely different, 100% = identical). ",
      "Red/orange cells suggest those segments may not be well-differentiated and could potentially be merged. ",
      "Green cells confirm the segments are distinct from each other."
    ),
    chart_el
  )
}


# ==============================================================================
# GOLDEN QUESTIONS SECTION
# ==============================================================================

#' Build Golden Questions Section
#'
#' Displays the top discriminating variables identified by Random Forest,
#' with importance bar chart and summary metrics.
#'
#' @param charts Named list of chart objects
#' @param html_data Transformed HTML data
#' @return htmltools tag
#' @keywords internal
build_seg_golden_questions_section <- function(charts, html_data) {

  title_row <- build_seg_section_title_row("Golden Questions", "golden-questions")
  insight_area <- build_seg_insight_area("golden-questions")

  gq <- html_data$golden_questions

  # Summary metrics
  accuracy <- round(gq$accuracy * 100, 1)
  n_top <- nrow(gq$top_questions)
  accuracy_colour <- if (accuracy >= 80) "#22c55e" else if (accuracy >= 60) "#f59e0b" else "#ef4444"

  summary_box <- htmltools::tags$div(
    class = "seg-finding-box",
    htmltools::tags$div(
      class = "seg-finding-item",
      htmltools::tags$span(class = "seg-finding-icon",
                          style = sprintf("color:%s;", accuracy_colour), "\u25CF"),
      htmltools::tags$span(class = "seg-finding-text",
                          sprintf("Random Forest classification accuracy: %.1f%% (OOB error rate: %.1f%%)",
                                  accuracy, 100 - accuracy))
    ),
    htmltools::tags$div(
      class = "seg-finding-item",
      htmltools::tags$span(class = "seg-finding-icon",
                          style = "color:var(--seg-accent);", "\u2605"),
      htmltools::tags$span(class = "seg-finding-text",
                          sprintf("Top %d variables that best predict segment membership shown below",
                                  n_top))
    )
  )

  chart_el <- if (!is.null(charts$golden_questions)) {
    htmltools::tags$div(
      class = "seg-chart-wrapper",
      build_seg_component_pin_btn("golden-questions", "chart"),
      htmltools::tags$div(class = "seg-chart", charts$golden_questions)
    )
  }

  # Questions table
  tq <- gq$top_questions
  question_labels <- html_data$question_labels

  header <- htmltools::tags$tr(
    htmltools::tags$th("Rank", class = "seg-th seg-th-rank"),
    htmltools::tags$th("Variable", class = "seg-th"),
    htmltools::tags$th("Importance", class = "seg-th seg-th-num")
  )

  rows <- lapply(seq_len(nrow(tq)), function(i) {
    var_name <- tq$variable[i]
    label <- if (!is.null(question_labels) && var_name %in% names(question_labels)) {
      question_labels[[var_name]]
    } else {
      var_name
    }

    htmltools::tags$tr(
      class = "seg-tr",
      htmltools::tags$td(
        class = "seg-td seg-td-rank",
        htmltools::tags$span(
          style = if (i == 1) "color:var(--seg-accent);font-weight:700;" else "",
          as.character(i)
        )
      ),
      htmltools::tags$td(
        class = "seg-td",
        htmltools::tags$div(
          style = "font-weight:500;",
          label
        ),
        if (label != var_name) {
          htmltools::tags$div(
            style = "font-size:11px;color:var(--seg-text-faint);",
            var_name
          )
        }
      ),
      htmltools::tags$td(
        class = "seg-td seg-td-num",
        sprintf("%.1f", tq$importance[i])
      )
    )
  })

  questions_table <- htmltools::tags$div(
    class = "seg-table-wrapper",
    build_seg_component_pin_btn("golden-questions", "table"),
    htmltools::tags$table(
      class = "seg-table",
      htmltools::tags$thead(header),
      htmltools::tags$tbody(rows)
    )
  )

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-golden-questions",
    `data-seg-section` = "golden-questions",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      "Golden questions are the survey items that best predict segment membership. These are identified using Random Forest variable importance (MeanDecreaseAccuracy). Use these questions for quick segment assignment in future research."
    ),
    summary_box,
    chart_el,
    questions_table
  )
}


# ==============================================================================
# VULNERABILITY / SWITCHING SECTION
# ==============================================================================

#' Build Vulnerability Analysis Section
#'
#' Displays segment switching vulnerability analysis including per-segment
#' confidence scores, vulnerability rates, and switching matrix.
#'
#' @param html_data Transformed HTML data (must contain $vulnerability)
#' @return htmltools tag
#' @keywords internal
build_seg_vulnerability_section <- function(html_data) {

  title_row <- build_seg_section_title_row("Segment Vulnerability", "vulnerability")
  insight_area <- build_seg_insight_area("vulnerability")

  vuln <- html_data$vulnerability
  if (is.null(vuln)) {
    return(htmltools::tags$div(
      class = "seg-section",
      id = "seg-vulnerability",
      `data-seg-section` = "vulnerability",
      title_row,
      insight_area,
      htmltools::tags$p(class = "seg-section-intro",
                        "Vulnerability analysis not available.")
    ))
  }

  # Overall summary metrics
  overall_pct <- round(vuln$overall_pct_vulnerable, 1)
  overall_conf <- round(vuln$overall_avg_confidence, 2)
  threshold <- vuln$threshold %||% 0.3

  status_colour <- if (overall_pct > 30) "#ef4444" else if (overall_pct > 15) "#f59e0b" else "#22c55e"
  status_label <- if (overall_pct > 30) "High" else if (overall_pct > 15) "Moderate" else "Low"

  summary_box <- htmltools::tags$div(
    class = "seg-finding-box",
    htmltools::tags$div(
      class = "seg-finding-item",
      htmltools::tags$span(class = "seg-finding-icon",
                          style = sprintf("color:%s;", status_colour), "\u25CF"),
      htmltools::tags$span(class = "seg-finding-text",
                          sprintf("%s vulnerability: %.1f%% of respondents are borderline (confidence < %.1f)",
                                  status_label, overall_pct, threshold))
    ),
    htmltools::tags$div(
      class = "seg-finding-item",
      htmltools::tags$span(class = "seg-finding-icon",
                          style = "color:var(--seg-brand);", "\u25B6"),
      htmltools::tags$span(class = "seg-finding-text",
                          sprintf("Average assignment confidence: %.2f (1.0 = perfectly assigned)", overall_conf))
    )
  )

  # Per-segment vulnerability table
  seg_summary <- vuln$segment_summary
  seg_table <- NULL
  if (!is.null(seg_summary) && nrow(seg_summary) > 0) {
    header <- htmltools::tags$tr(
      htmltools::tags$th("Segment", class = "seg-th"),
      htmltools::tags$th("n", class = "seg-th seg-th-num"),
      htmltools::tags$th("Vulnerable", class = "seg-th seg-th-num"),
      htmltools::tags$th("% Vulnerable", class = "seg-th seg-th-num"),
      htmltools::tags$th("Avg Confidence", class = "seg-th seg-th-num"),
      htmltools::tags$th("Borderline Confidence", class = "seg-th seg-th-num")
    )

    rows <- lapply(seq_len(nrow(seg_summary)), function(i) {
      row <- seg_summary[i, ]
      pct_vuln <- round(row$pct_vulnerable, 1)
      bar_colour <- if (pct_vuln > 30) "#ef4444" else if (pct_vuln > 15) "#f59e0b" else "#22c55e"

      # Borderline confidence: lower = more likely to switch
      avg_vuln_conf <- if ("avg_vuln_confidence" %in% names(row)) row$avg_vuln_confidence else NA_real_
      vuln_display <- if (is.na(avg_vuln_conf)) "-" else sprintf("%.2f", avg_vuln_conf)
      vuln_colour <- if (is.na(avg_vuln_conf)) "#64748b"
                     else if (avg_vuln_conf < 0.10) "#ef4444"
                     else if (avg_vuln_conf < 0.20) "#f59e0b"
                     else "#64748b"

      htmltools::tags$tr(
        htmltools::tags$td(row$segment, class = "seg-td"),
        htmltools::tags$td(format(row$n, big.mark = ","), class = "seg-td seg-td-num"),
        htmltools::tags$td(format(row$n_vulnerable, big.mark = ","), class = "seg-td seg-td-num"),
        htmltools::tags$td(
          class = "seg-td seg-td-num",
          htmltools::tags$span(
            style = sprintf("color:%s; font-weight:500;", bar_colour),
            sprintf("%.1f%%", pct_vuln)
          )
        ),
        htmltools::tags$td(sprintf("%.2f", row$avg_confidence), class = "seg-td seg-td-num"),
        htmltools::tags$td(
          class = "seg-td seg-td-num",
          htmltools::tags$span(
            style = sprintf("color:%s; font-weight:500;", vuln_colour),
            vuln_display
          )
        )
      )
    })

    seg_table <- htmltools::tags$div(
      class = "seg-table-wrapper",
      build_seg_component_pin_btn("vulnerability", "table"),
      htmltools::tags$table(
        class = "seg-table",
        htmltools::tags$thead(header),
        htmltools::tags$tbody(rows)
      )
    )
  }

  # Switching matrix
  sw_matrix <- vuln$switching_matrix
  matrix_el <- NULL
  if (!is.null(sw_matrix) && nrow(sw_matrix) > 0) {
    k <- nrow(sw_matrix)
    seg_names <- rownames(sw_matrix) %||% paste0("Seg ", 1:k)

    m_header <- htmltools::tags$tr(
      htmltools::tags$th("From \\ To", class = "seg-th"),
      lapply(seg_names, function(s) htmltools::tags$th(s, class = "seg-th seg-th-num"))
    )

    m_rows <- lapply(seq_len(k), function(i) {
      cells <- lapply(seq_len(k), function(j) {
        val <- sw_matrix[i, j]
        bg <- if (i == j) "#f8fafc" else if (val > 0) {
          intensity <- min(val / max(sw_matrix[sw_matrix > 0], na.rm = TRUE), 1)
          sprintf("rgba(239, 68, 68, %.2f)", intensity * 0.3)
        } else {
          "transparent"
        }
        htmltools::tags$td(
          class = "seg-td seg-td-num",
          style = sprintf("background:%s;", bg),
          if (i == j) "-" else as.character(val)
        )
      })
      htmltools::tags$tr(
        htmltools::tags$td(seg_names[i], class = "seg-td", style = "font-weight:500;"),
        cells
      )
    })

    matrix_el <- htmltools::tags$div(
      class = "seg-table-wrapper",
      htmltools::tags$h4(class = "seg-subsection-title", "Switching Matrix"),
      htmltools::tags$p(class = "seg-section-intro", style = "font-size:12px;",
                        "Number of vulnerable respondents in each segment (rows) who would switch to another segment (columns). Only includes respondents below the confidence threshold."),
      build_seg_component_pin_btn("vulnerability", "matrix"),
      htmltools::tags$table(
        class = "seg-table",
        htmltools::tags$thead(m_header),
        htmltools::tags$tbody(m_rows)
      )
    )
  }

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-vulnerability",
    `data-seg-section` = "vulnerability",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      "Identifies respondents whose segment assignments are borderline - they sit near the boundary between segments and could potentially switch with small changes in their responses."
    ),
    summary_box,
    seg_table,
    matrix_el
  )
}


# ==============================================================================
# GMM MEMBERSHIP SECTION
# ==============================================================================

#' Build GMM Membership Section
#'
#' Displays membership probabilities for GMM/Mclust methods.
#'
#' @param tables Named list of table objects
#' @param html_data Transformed HTML data
#' @return htmltools tag
#' @keywords internal
build_seg_gmm_section <- function(tables, html_data) {

  title_row <- build_seg_section_title_row("GMM Membership Probabilities", "gmm")
  insight_area <- build_seg_insight_area("gmm")

  # GMM membership table
  table_el <- NULL
  if (!is.null(tables$gmm)) {
    table_el <- htmltools::tags$div(
      class = "seg-table-wrapper",
      build_seg_component_pin_btn("gmm", "table"),
      tables$gmm
    )
  }

  # Membership summary
  gmm_data <- html_data$gmm_membership
  summary_html <- NULL
  if (!is.null(gmm_data) && !is.null(gmm_data$avg_max_prob)) {
    avg_prob <- round(gmm_data$avg_max_prob * 100, 1)
    uncertain_pct <- round((gmm_data$n_uncertain %||% 0) /
                           (html_data$n_observations %||% 1) * 100, 1)

    summary_html <- htmltools::tags$div(
      class = "seg-finding-box",
      htmltools::tags$div(
        class = "seg-finding-item",
        htmltools::tags$span(class = "seg-finding-icon",
                            style = "color:var(--seg-brand);", "\u25B6"),
        htmltools::tags$span(class = "seg-finding-text",
                            sprintf("Average maximum membership probability: %.1f%%", avg_prob))
      ),
      if (uncertain_pct > 0) {
        htmltools::tags$div(
          class = "seg-finding-item",
          htmltools::tags$span(class = "seg-finding-icon",
                              style = "color:var(--seg-warning);", "\u26A0"),
          htmltools::tags$span(class = "seg-finding-text",
                              sprintf("%.1f%% of respondents have uncertain membership (max probability < 70%%)", uncertain_pct))
        )
      }
    )
  }

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-gmm",
    `data-seg-section` = "gmm",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      "Gaussian Mixture Model membership probabilities show how confidently each respondent is assigned to their segment. Higher probabilities indicate clearer segment membership."
    ),
    summary_html,
    table_el
  )
}


# ==============================================================================
# INTERPRETATION GUIDE SECTION
# ==============================================================================

#' Build Interpretation Guide Section
#'
#' Static content with DO/DON'T guidelines for interpreting segmentation results.
#'
#' @param brand_colour Brand colour hex string
#' @return htmltools tag
#' @keywords internal
build_seg_guide_section <- function(brand_colour = "#323367") {

  title_row <- build_seg_section_title_row("How to Interpret These Results",
                                            "guide",
                                            show_pin = FALSE)

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-guide",
    `data-seg-section` = "guide",
    title_row,
    htmltools::tags$div(
      class = "seg-interp-grid",
      htmltools::tags$div(
        htmltools::tags$h3(
          class = "seg-panel-heading-label",
          style = "color:var(--seg-success);",
          "DO"
        ),
        htmltools::tags$ul(
          class = "seg-interp-list",
          htmltools::tags$li("Use segment profiles to understand the defining characteristics of each group"),
          htmltools::tags$li("Validate segments with qualitative research or external data before acting on them"),
          htmltools::tags$li("Focus on large, actionable differences between segments rather than small variations"),
          htmltools::tags$li("Consider multiple validation metrics together (silhouette, between-SS, variable importance)"),
          htmltools::tags$li("Re-run segmentation periodically to check if the segment structure remains stable")
        )
      ),
      htmltools::tags$div(
        htmltools::tags$h3(
          class = "seg-panel-heading-label",
          style = "color:var(--seg-danger);",
          "DON'T"
        ),
        htmltools::tags$ul(
          class = "seg-interp-list",
          htmltools::tags$li("Treat segments as fixed, immutable groups \u2014 they are statistical constructs"),
          htmltools::tags$li("Over-interpret small sample segments (n < 30) as reliable market groups"),
          htmltools::tags$li("Assume segment membership is binary \u2014 respondents may sit on boundaries"),
          htmltools::tags$li("Ignore validation metrics; a poor silhouette score means the structure is unreliable"),
          htmltools::tags$li("Use segments from non-representative samples to make population-level claims")
        )
      )
    ),
    htmltools::tags$div(
      class = "seg-interp-note",
      htmltools::tags$strong("Note: "),
      "Cluster analysis finds structure in data, but the practical meaning and actionability of segments depends on domain knowledge. Always name and interpret segments in context of your research objectives."
    )
  )
}


# ==============================================================================
# FOOTER
# ==============================================================================

#' Build Footer
#'
#' @param config Configuration list
#' @return htmltools tag
#' @keywords internal
build_seg_footer <- function(config = list()) {
  company_name <- config$company_name %||% "The Research LampPost (Pty) Ltd"
  client_name <- config$client_name %||% NULL

  prepared <- company_name
  if (!is.null(client_name) && nzchar(client_name)) {
    prepared <- sprintf("%s | Prepared for %s", prepared, client_name)
  }

  htmltools::tags$div(
    class = "seg-footer",
    sprintf("Generated by TURAS Segmentation Module v11.0 | %s",
            format(Sys.time(), "%d %B %Y %H:%M")),
    htmltools::tags$br(),
    prepared
  )
}
