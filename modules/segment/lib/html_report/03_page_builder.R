# ==============================================================================
# SEGMENT HTML REPORT - PAGE BUILDER
# ==============================================================================
# Assembles the complete HTML page from tables, charts, and section content.
# Design system: Turas muted palette, clean typography, seg- CSS prefix.
# Version: 11.0
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
  # Source callout registry
  callout_dir <- file.path(turas_root, "modules", "shared", "lib", "callouts")
  if (!dir.exists(callout_dir)) callout_dir <- file.path("modules", "shared", "lib", "callouts")
  if (!exists("turas_callout", mode = "function") && dir.exists(callout_dir)) {
    source(file.path(callout_dir, "callout_registry.R"), local = FALSE)
    # Prime callout cache with TURAS_ROOT-resolved path (avoids getwd() issues)
    json_path <- file.path(callout_dir, "callouts.json")
    if (file.exists(json_path) && is.null(.callout_cache$data)) {
      tryCatch({
        cdata <- jsonlite::fromJSON(json_path, simplifyVector = FALSE)
        cdata[["_meta"]] <- NULL
        .callout_cache$data <- cdata
      }, error = function(e) NULL)
    }
  }
})


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

  # Store config insights for use by build_seg_insight_area
  .seg_config_insights <<- config$insights

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
                          "\U0001F4CC Pinned Views"),
      htmltools::tags$div(
        class = "seg-pinned-panel-actions",
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segAddSection()",
          "\u2795 Add Section"
        ),
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segExportAllPinnedPNG()",
          "\U0001F4E5 Export All as PNG"
        ),
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segPrintPinnedViews()",
          "\U0001F5B6 Print / PDF"
        ),
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segClearAllPinned()",
          "\U0001F5D1 Clear All"
        )
      )
    ),
    htmltools::tags$div(
      id = "seg-pinned-empty",
      class = "seg-pinned-empty",
      htmltools::tags$div(class = "seg-pinned-empty-icon", "\U0001F4CC"),
      htmltools::tags$div("No pinned views yet.")
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

  # Report-level tab bar — shared convention (report-tabs / report-tab)
  save_icon <- htmltools::HTML('<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:-1px;margin-right:5px;"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>')

  report_tab_bar <- htmltools::tags$div(
    class = "report-tabs",
    htmltools::tags$button(
      class = "report-tab active",
      `data-tab` = "analysis",
      onclick = "switchReportTab('analysis')",
      "Analysis"
    ),
    htmltools::tags$button(
      class = "report-tab",
      `data-tab` = "pinned",
      onclick = "switchReportTab('pinned')",
      "Pinned Views",
      htmltools::tags$span(
        id = "seg-pin-count-badge",
        class = "seg-pin-count-badge",
        style = "display:none;"
      )
    ),
    htmltools::tags$button(
      class = "report-tab",
      `data-tab` = "slides",
      onclick = "switchReportTab('slides')",
      "Added Slides",
      htmltools::tags$span(
        id = "seg-slide-count-badge",
        class = "seg-pin-count-badge",
        style = "display:none;"
      )
    ),
    htmltools::tags$button(
      class = "report-tab",
      `data-tab` = "about",
      onclick = "switchReportTab('about')",
      "About"
    ),
    htmltools::tags$button(
      class = "report-tab seg-save-tab",
      onclick = "segSaveReportHTML()",
      save_icon, "Save Report"
    ),
    htmltools::tags$button(
      class = "seg-help-btn",
      onclick = "toggleHelpOverlay()",
      title = "Show help guide",
      "?"
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
        # Analysis tab — active by default
        htmltools::tags$div(
          id = "tab-analysis",
          class = "tab-panel active seg-content",
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
        # Pinned Views tab
        htmltools::tags$div(
          id = "tab-pinned",
          class = "tab-panel seg-content",
          pinned_section,
          footer_section
        ),
        # Slides tab
        htmltools::tags$div(
          id = "tab-slides",
          class = "tab-panel seg-content",
          build_seg_slides_section(config),
          footer_section
        ),
        # About tab
        htmltools::tags$div(
          id = "tab-about",
          class = "tab-panel seg-content",
          build_seg_about_section(config, html_data),
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

/* Reset provided by turas_base_css() — only module overrides below */

.seg-body {
  background: var(--seg-bg);
  color: var(--seg-text);
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
/* REPORT-LEVEL TABS — shared convention (report-tabs / report-tab)  */
/* ================================================================ */

.report-tabs {
  display: flex;
  align-items: center;
  gap: 0;
  padding: 0 24px;
  background: var(--seg-card);
  border-bottom: 1px solid var(--seg-border);
  box-shadow: 0 1px 2px rgba(0,0,0,0.02);
}

.report-tab {
  padding: 14px 24px;
  font-size: 13px;
  font-weight: 600;
  color: var(--seg-text-muted);
  background: transparent;
  border: none;
  border-bottom: 2px solid transparent;
  cursor: pointer;
  font-family: inherit;
  letter-spacing: 0.1px;
  transition: all 0.15s;
}

.report-tab:hover:not(.active) {
  color: var(--seg-brand);
  background: #fafbfc;
}

.report-tab.active {
  color: var(--seg-brand);
  border-bottom-color: var(--seg-brand);
}

.seg-save-tab {
  margin-left: auto;
  color: var(--seg-brand);
  border-bottom-color: transparent !important;
}

.seg-help-btn {
  width: 28px; height: 28px; border-radius: 50%;
  border: 1.5px solid var(--seg-border);
  background: transparent; color: var(--seg-text-muted);
  font-size: 14px; font-weight: 700; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  margin-left: 8px; transition: all 0.15s;
}
.seg-help-btn:hover { border-color: var(--seg-brand); color: var(--seg-brand); }

/* Tab panel visibility — shared convention */
.tab-panel { display: none; }
.tab-panel.active { display: block; }

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
  letter-spacing: 0.4px;
  padding: 12px 16px;
  text-align: left;
  border-bottom: 2px solid var(--seg-border);
  vertical-align: bottom;
  white-space: normal;
}

.seg-th-num { text-align: center; }
.seg-th-bar { text-align: left; min-width: 150px; }
.seg-th-rank { text-align: center; width: 50px; }

.seg-td {
  padding: 10px 16px;
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

/* Heatmap cell tinting — all numeric, centred, tabular figures */
.seg-td-high { background: #dcfce7; text-align: center; font-variant-numeric: tabular-nums; }
.seg-td-mod-high { background: #eff6ff; text-align: center; font-variant-numeric: tabular-nums; }
.seg-td-mod-low { background: #fef3c7; text-align: center; font-variant-numeric: tabular-nums; }
.seg-td-low { background: #fee2e2; text-align: center; font-variant-numeric: tabular-nums; }

/* Label column — explicitly left-aligned */
.seg-td-label { text-align: left; }
.seg-th-label { text-align: left; }

/* Profile & overlap tables — all cells centred except labels */
.seg-profile-table td,
.seg-overlap-table td { text-align: center; font-variant-numeric: tabular-nums; }
.seg-profile-table td.seg-td-label,
.seg-overlap-table td.seg-td-label { text-align: left; }

/* Heatmap legend strip */
.seg-heatmap-legend {
  display: flex; gap: 20px; align-items: center;
  margin: 12px 0 16px; font-size: 12px; color: var(--seg-text-muted);
}
.seg-heatmap-legend-item { display: inline-flex; align-items: center; gap: 6px; }
.seg-heatmap-legend-swatch {
  display: inline-block; width: 16px; height: 16px;
  border-radius: 3px; border: 1px solid var(--seg-border);
}

/* Overlap table — symmetrical matrix layout */
.seg-overlap-table .seg-td-label { font-weight: 600; color: var(--seg-brand); background: #f8fafc; }

/* Pairwise assessment cards */
.seg-pair-insights { margin-top: 20px; }
.seg-pair-insights-title {
  font-weight: 600; color: var(--seg-brand);
  margin-bottom: 10px; font-size: 14px;
}
.seg-pair-insight {
  padding: 10px 14px; margin: 6px 0;
  border-radius: 6px; font-size: 13px; line-height: 1.5;
}

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

.seg-chart-wrapper {
  position: relative;
  margin-bottom: 8px;
}

.seg-table-wrapper {
  margin-bottom: 8px;
}

/* Pin button — absolute on charts, inline on tables */
.seg-component-pin {
  background: rgba(255,255,255,0.85);
  border: 1px solid var(--seg-border);
  border-radius: 4px;
  padding: 2px 8px;
  font-size: 11px;
  font-weight: 500;
  color: var(--seg-text-faint);
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s;
}

/* Chart wrappers: pin floats over content */
.seg-chart-wrapper .seg-component-pin {
  position: absolute; top: 4px; right: 4px; z-index: 10;
  opacity: 0;
}
.seg-chart-wrapper:hover .seg-component-pin { opacity: 1; }

.seg-component-pin:hover,
.seg-table-export:hover {
  border-color: var(--seg-brand);
  color: var(--seg-brand);
  background: rgba(255,255,255,0.95);
}

.seg-component-pin.seg-pin-btn-active {
  background: var(--seg-brand);
  color: white;
  border-color: var(--seg-brand);
}

/* Table toolbar — right-aligned row above table, visible on hover */
.seg-table-toolbar {
  display: flex;
  justify-content: flex-end;
  gap: 6px;
  margin-bottom: 4px;
  opacity: 0;
  transition: opacity 0.15s;
}
.seg-table-wrapper:hover .seg-table-toolbar { opacity: 1; }

/* Table export button — same style as pin */
.seg-table-export {
  background: rgba(255,255,255,0.85);
  border: 1px solid var(--seg-border);
  border-radius: 4px;
  padding: 2px 8px;
  font-size: 11px;
  font-weight: 500;
  color: var(--seg-text-faint);
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s;
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
  border: 1px solid var(--seg-border);
  border-radius: 6px;
  padding: 12px 16px;
  border-left: 3px solid var(--seg-brand);
}

.seg-fit-card-value {
  font-size: 18px;
  font-weight: 700;
  color: var(--seg-text);
  font-variant-numeric: tabular-nums;
}

.seg-fit-card-label {
  font-size: 12px;
  font-weight: 600;
  color: var(--seg-text-muted);
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
  color: var(--seg-text-faint);
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
  padding: 12px;
  border: 1px dashed rgba(50,51,103,0.4);
  border-radius: 4px;
  font-size: 13px;
  font-family: inherit;
  line-height: 1.5;
  color: var(--seg-text);
  outline: none;
  transition: border-color 0.15s, background 0.15s, box-shadow 0.15s;
}

.seg-insight-editor:focus {
  border-style: solid;
  border-color: var(--seg-brand);
  background: #f0f4ff;
  box-shadow: inset 0 1px 4px rgba(50,51,103,0.10);
}

.seg-insight-hint {
  font-size: 11px;
  color: var(--seg-text-faint);
  margin-top: 4px;
  font-style: italic;
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
  border: 1px solid var(--seg-border);
  border-radius: 6px;
  padding: 4px 10px;
  font-size: 14px;
  cursor: pointer;
  color: var(--seg-text-faint);
  transition: all 0.15s;
  flex-shrink: 0;
}

.seg-pin-btn:hover {
  border-color: var(--seg-brand);
  color: var(--seg-brand);
  background: rgba(50,51,103,0.03);
}

.seg-pin-btn.seg-pin-btn-active {
  background: var(--seg-brand);
  color: white;
  border-color: var(--seg-brand);
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
  .report-tabs { display: none !important; }
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

  # Prepend shared design system CSS
  shared_css <- tryCatch(turas_base_css(brand_colour, accent_colour, prefix = "seg"), error = function(e) "")
  css <- paste0(shared_css, "\n", css)

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

  # --- Top row: [logo] TURAS SEGMENTATION / subtitle [client logo] ---
  branding_left <- htmltools::tags$div(
    class = "seg-header-branding",
    logo_el,
    htmltools::tags$div(
      htmltools::tags$div(class = "seg-header-module-name", "TURAS Segmentation"),
      htmltools::tags$div(class = "seg-header-module-sub", "Survey Analytics Platform")
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
      title = "Pin to Views",
      "\U0001F4CC"
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
build_seg_insight_area <- function(section_key, pre_text = NULL) {
  # Auto-lookup from config insights if not explicitly passed
  if (is.null(pre_text) && exists(".seg_config_insights", envir = .GlobalEnv)) {
    insights <- get(".seg_config_insights", envir = .GlobalEnv)
    if (!is.null(insights) && length(insights) > 0) {
      # Try exact match, then with hyphens replaced by spaces/underscores
      key_variants <- c(section_key, gsub("-", " ", section_key), gsub("-", "_", section_key))
      for (kv in key_variants) {
        if (kv %in% names(insights) && nzchar(insights[kv])) {
          pre_text <- unname(insights[kv])
          break
        }
      }
    }
  }
  has_pre <- !is.null(pre_text) && nzchar(trimws(pre_text))
  # Apply basic markdown formatting to pre-populated insights
  pre_html <- if (has_pre) {
    txt <- pre_text
    txt <- gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", txt, perl = TRUE)
    txt <- gsub("\\*(.+?)\\*", "<em>\\1</em>", txt, perl = TRUE)
    txt <- gsub("^- (.+)", "<li>\\1</li>", txt, perl = TRUE)
    txt <- gsub("\n", "<br/>", txt)
    htmltools::HTML(txt)
  } else {
    NULL
  }
  htmltools::tags$div(
    class = "seg-insight-area",
    `data-seg-insight-section` = section_key,
    htmltools::tags$button(
      class = "seg-insight-toggle",
      id = paste0("seg-insight-toggle-", section_key),
      onclick = sprintf("segToggleInsight('%s')", section_key),
      style = if (has_pre) "display:none;" else "",
      "\u270E Add Insight"
    ),
    htmltools::tags$div(
      class = "seg-insight-container",
      id = paste0("seg-insight-container-", section_key),
      style = if (has_pre) "display:block;" else "",
      htmltools::tags$div(
        class = "seg-insight-editor",
        contenteditable = "true",
        `data-placeholder` = "Type your insight or comment here...",
        oninput = sprintf("segSyncInsight('%s')", section_key),
        if (has_pre) pre_html
      ),
      htmltools::tags$div(
        class = "seg-insight-hint",
        "Your notes will appear on exported slides"
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
build_seg_component_pin_btn <- function(section_key, component, prefix = "") {
  label <- if (component == "chart") "\U0001F4CC Chart" else "\U0001F4CC Table"
  htmltools::tags$button(
    class = "seg-component-pin",
    `data-seg-pin-section` = section_key,
    `data-seg-pin-component` = component,
    onclick = sprintf("segPinComponent('%s','%s','%s')", section_key, component, prefix),
    title = sprintf("Pin %s only", component),
    label
  )
}


#' Build Table Toolbar
#'
#' Creates a toolbar row with export and pin buttons that appears on hover
#' above a table wrapper. Keeps buttons out of the table header area.
#'
#' @param section_key Section identifier
#' @param prefix Optional prefix for pin component
#' @return htmltools tag — a div.seg-table-toolbar containing both buttons
#' @keywords internal
build_seg_table_toolbar <- function(section_key, prefix = "") {
  htmltools::tags$div(
    class = "seg-table-toolbar",
    htmltools::tags$button(
      class = "seg-table-export",
      onclick = sprintf("segExportTableCSV(this, '%s')", section_key),
      title = "Export table to Excel (CSV)",
      htmltools::HTML("&#x1F4E5; Excel")
    ),
    htmltools::tags$button(
      class = "seg-component-pin",
      `data-seg-pin-section` = section_key,
      `data-seg-pin-component` = "table",
      onclick = sprintf("segPinComponent('%s','table','%s')", section_key, prefix),
      title = "Pin table only",
      "\U0001F4CC Table"
    )
  )
}

#' Build Table Export-Only Toolbar
#'
#' Creates a toolbar row with just an export button (no pin) for tables
#' that don't have a pin button.
#'
#' @param section_key Section identifier
#' @return htmltools tag
#' @keywords internal
build_seg_table_export_toolbar <- function(section_key) {
  htmltools::tags$div(
    class = "seg-table-toolbar",
    htmltools::tags$button(
      class = "seg-table-export",
      onclick = sprintf("segExportTableCSV(this, '%s')", section_key),
      title = "Export table to Excel (CSV)",
      htmltools::HTML("&#x1F4E5; Excel")
    )
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

  # Help overlay
  help_overlay <- htmltools::tags$div(
    id = "seg-help-overlay",
    style = paste0(
      "display:none; position:fixed; top:0; left:0; width:100%; height:100%; ",
      "background:rgba(0,0,0,0.5); z-index:10000; justify-content:center; align-items:center;"
    ),
    onclick = "if(event.target===this) segToggleHelp();",
    htmltools::tags$div(
      style = paste0(
        "background:#fff; border-radius:12px; max-width:560px; width:90%; max-height:80vh; ",
        "overflow-y:auto; padding:28px; position:relative; box-shadow:0 8px 32px rgba(0,0,0,0.2);"
      ),
      htmltools::tags$button(
        style = paste0(
          "position:absolute; top:12px; right:16px; background:none; border:none; ",
          "font-size:22px; color:#94a3b8; cursor:pointer;"
        ),
        onclick = "segToggleHelp()",
        "\u00D7"
      ),
      htmltools::tags$h3(
        style = "color:var(--seg-brand); margin:0 0 16px; font-size:18px;",
        "\u2753 Navigating This Report"
      ),
      htmltools::tags$div(
        style = "font-size:13px; color:#334155; line-height:1.7;",
        htmltools::HTML(paste0(
          "<p><strong>Tabs</strong> \u2014 Switch between <em>Analysis</em> (main results), ",
          "<em>Pinned Views</em> (saved charts for presentations), <em>Slides</em> (custom ",
          "presentation slides with images), and <em>About</em> (analyst &amp; project details).</p>",
          "<p><strong>Section Nav</strong> \u2014 Click any section name (Summary, Overview, etc.) ",
          "to jump directly to that section. The active section is highlighted.</p>",
          "<p><strong>Pin Button</strong> <span style='color:var(--seg-brand);'>\U0001F4CC</span> \u2014 ",
          "Click the pin icon on any chart or table to save it to Pinned Views for export.</p>",
          "<p><strong>Add Insight</strong> <span style='color:var(--seg-brand);'>\u270E</span> \u2014 ",
          "Click to add your own notes or commentary to any section. Insights are saved ",
          "when you save the report.</p>",
          "<p><strong>Variable Importance</strong> \u2014 Click the \u00D7 on any bar to hide ",
          "it for presentations. Click the + to restore, or use 'Show all'.</p>",
          "<p><strong>Golden Questions</strong> \u2014 Use checkboxes to see how classification ",
          "accuracy changes as questions are added or removed.</p>",
          "<p><strong>Save Report</strong> \u2014 Downloads the current report as a self-contained ",
          "HTML file. All your insights, pins, and edits are preserved. Open the saved file ",
          "in any browser.</p>",
          "<p><strong>Slides</strong> \u2014 Create presentation slides with titles, text, and ",
          "uploaded images. Pre-configure slides from the Excel config (Slides sheet).</p>"
        ))
      )
    )
  )

  htmltools::tagList(
    help_overlay,
    htmltools::tags$div(
      class = "seg-action-bar",
      htmltools::tags$button(
        style = paste0(
          "background:none; border:1px solid #d1d5db; border-radius:50%; ",
          "width:32px; height:32px; cursor:pointer; color:#64748b; font-size:16px; ",
          "font-weight:700; margin-right:8px; line-height:1;"
        ),
        onclick = "segToggleHelp()",
        title = "Help",
        "?"
      ),
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

  # Method explainer callout (for the layperson)
  method_callout <- .build_method_callout(html_data$method %||% "kmeans", html_data$k %||% 0)

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
    method_callout,
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
      build_seg_table_toolbar("overview"),
      tables$overview
    )
  }

  # Bar visibility toggles for presentation mode
  # Must match chart sort order (descending by n)
  toggle_bar <- NULL
  if (!is.null(html_data$segment_sizes) && nrow(html_data$segment_sizes) > 0) {
    sorted_sizes <- html_data$segment_sizes[order(-html_data$segment_sizes$n), , drop = FALSE]
    toggle_btns <- lapply(seq_len(nrow(sorted_sizes)), function(i) {
      seg_name <- sorted_sizes$segment_name[i] %||%
                  paste0("Segment ", sorted_sizes$segment_id[i])
      group_id <- sprintf("seg-bar-%d", i)
      htmltools::tags$button(
        class = "seg-bar-toggle-btn",
        style = paste0("font-size:11px; padding:3px 10px; margin:2px 4px; border:1px solid #d1d5db;",
                       "border-radius:12px; background:#fff; cursor:pointer; color:#334155;",
                       "transition:opacity 0.2s;"),
        onclick = sprintf("segToggleBarGroup(this,'%s')", group_id),
        seg_name
      )
    })
    toggle_bar <- htmltools::tags$div(
      style = "margin-top:8px; text-align:center;",
      htmltools::tags$span(
        style = "font-size:10px; color:#94a3b8; margin-right:8px;",
        "Click to show/hide:"
      ),
      toggle_btns
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
    toggle_bar,
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
                          sprintf("%.0f%%", bss_pct)),
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
      build_seg_table_toolbar("validation"),
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
      ),
      htmltools::tags$p(
        style = "font-size:11px; color:#94a3b8; font-style:italic; margin-top:8px;",
        "Thresholds based on Kaufman & Rousseeuw (1990), ",
        htmltools::tags$em("Finding Groups in Data: An Introduction to Cluster Analysis."),
        " Wiley."
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

  # Chart wrapper — X buttons are inline on each bar in the SVG
  chart_el <- NULL
  if (!is.null(charts$importance)) {
    chart_el <- htmltools::tags$div(
      class = "seg-chart-wrapper",
      build_seg_component_pin_btn("importance", "chart"),
      charts$importance,
      htmltools::tags$div(
        style = "text-align:right; margin-top:4px;",
        htmltools::tags$button(
          style = paste0(
            "font-size:11px; padding:4px 12px; border:1px solid #d1d5db; ",
            "border-radius:6px; background:#fff; cursor:pointer; color:#64748b;"
          ),
          onclick = "segShowAllBars(this)",
          "Show all"
        )
      )
    )
  }

  # Table wrapper
  table_el <- NULL
  if (!is.null(tables$importance)) {
    table_el <- htmltools::tags$div(
      class = "seg-table-wrapper",
      build_seg_table_toolbar("importance"),
      tables$importance
    )
  }

  # Question Reduction analysis — shows which variables can be dropped
  # without losing segment discrimination power
  reduction_el <- NULL
  vi <- html_data$variable_importance
  # Use eta_squared if available, fall back to importance_pct or f_statistic
  vi_col <- if (!is.null(vi) && "eta_squared" %in% names(vi)) "eta_squared"
            else if (!is.null(vi) && "importance_pct" %in% names(vi)) "importance_pct"
            else if (!is.null(vi) && "f_statistic" %in% names(vi)) "f_statistic"
            else NULL
  if (!is.null(vi) && nrow(vi) > 1 && !is.null(vi_col)) {
    imp <- vi[order(-vi[[vi_col]]), ]
    cumulative <- cumsum(imp[[vi_col]]) / sum(imp[[vi_col]])
    # Find how many variables capture 90% of discrimination
    n_for_90 <- which(cumulative >= 0.90)[1]
    if (is.na(n_for_90)) n_for_90 <- nrow(imp)
    n_total <- nrow(imp)
    n_reducible <- n_total - n_for_90

    if (n_reducible > 0) {
      reduction_el <- htmltools::tags$div(
        class = "seg-subsection",
        style = "margin-top:24px; padding:16px; background:#f8fafc; border-radius:8px; border:1px solid #e2e8f0;",
        htmltools::tags$h4(
          style = "margin:0 0 8px; font-size:14px; font-weight:600; color:var(--seg-brand);",
          "Question Reduction"
        ),
        htmltools::tags$p(
          style = "margin:0; font-size:13px; color:#475569; line-height:1.5;",
          htmltools::HTML(sprintf(
            "The top %d variable%s capture%s 90%% of total segment discrimination power. ",
            n_for_90,
            if (n_for_90 == 1) "" else "s",
            if (n_for_90 == 1) "s" else ""
          )),
          htmltools::HTML(sprintf(
            "The remaining %d variable%s contribute%s less than 10%% and could potentially ",
            n_reducible,
            if (n_reducible == 1) "" else "s",
            if (n_reducible == 1) "s" else ""
          )),
          htmltools::HTML(
            "be removed in future waves to reduce survey length without materially affecting segment discrimination."
          )
        )
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
      htmltools::HTML(paste0(
        "Variables ranked by their contribution to segment differentiation. ",
        "The percentage shows each variable&rsquo;s share of the total discriminating power &mdash; ",
        "a variable with 25% contributes one quarter of the total distinction between segments. ",
        "Based on one-way ANOVA effect sizes (eta-squared)."
      ))
    ),
    chart_el,
    table_el,
    reduction_el
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
      build_seg_table_toolbar("profiles"),
      tables$profiles
    )
  }

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-profiles",
    `data-seg-section` = "profiles",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      "Mean scores for each variable by segment. Cells are colour-coded: blue indicates above-average scores, amber/red indicates below-average scores relative to the overall sample mean."
    ),
    chart_el,
    table_el
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
      build_seg_table_toolbar("rules"),
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
      sprintf("%.0f%% (%s) - Rules correctly classify this proportion of observations into their segments.",
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

  title_row <- build_seg_section_title_row("Segment Distinctiveness", "overlap")
  insight_area <- build_seg_insight_area("overlap")

  # Build clean heatmap table using standard seg-td-* classes
  centers <- html_data$centers
  overlap_table <- NULL
  pair_insights <- NULL

  if (!is.null(centers)) {
    if (!is.matrix(centers)) {
      centers <- tryCatch(as.matrix(centers), error = function(e) NULL)
    }
    if (!is.null(centers) && nrow(centers) >= 2) {
      k <- nrow(centers)
      seg_names <- html_data$segment_names %||% paste0("Segment ", seq_len(k))
      dist_matrix <- as.matrix(stats::dist(centers, method = "euclidean"))
      max_dist <- max(dist_matrix, na.rm = TRUE)
      if (max_dist == 0) max_dist <- 1

      # Build table header
      th_cells <- list(htmltools::tags$th(class = "seg-th seg-th-label", ""))
      for (j in seq_len(k)) {
        th_cells[[j + 1]] <- htmltools::tags$th(
          class = "seg-th seg-th-num",
          seg_names[j]
        )
      }
      header_row <- do.call(htmltools::tags$tr, th_cells)

      # Build table rows — use index-score heatmap classes
      # High distance (>70% of max) = good separation = seg-td-high (green)
      # Moderate-high (50-70%) = seg-td-mod-high (blue)
      # Moderate-low (30-50%) = seg-td-mod-low (amber)
      # Low distance (<30%) = overlapping = seg-td-low (red)
      table_rows <- lapply(seq_len(k), function(i) {
        cells <- list(htmltools::tags$td(
          class = "seg-td seg-td-label",
          htmltools::tags$strong(seg_names[i])
        ))
        for (j in seq_len(k)) {
          if (i == j) {
            cells[[j + 1]] <- htmltools::tags$td(
              class = "seg-td seg-td-num",
              style = "background:#f1f5f9; color:#94a3b8;",
              "\u2014"
            )
          } else {
            raw_dist <- dist_matrix[i, j]
            norm_val <- raw_dist / max_dist
            # Map normalised distance to heatmap class
            td_class <- if (norm_val >= 0.7) {
              "seg-td seg-td-high"
            } else if (norm_val >= 0.5) {
              "seg-td seg-td-mod-high"
            } else if (norm_val >= 0.3) {
              "seg-td seg-td-mod-low"
            } else {
              "seg-td seg-td-low"
            }
            cells[[j + 1]] <- htmltools::tags$td(
              class = td_class,
              sprintf("%.2f", raw_dist)
            )
          }
        }
        do.call(htmltools::tags$tr, c(list(class = "seg-tr"), cells))
      })

      overlap_table <- htmltools::tags$div(
        class = "seg-table-wrapper",
        build_seg_table_toolbar("overlap"),
        htmltools::tags$table(
          class = "seg-table seg-overlap-table",
          htmltools::tags$thead(header_row),
          htmltools::tags$tbody(table_rows)
        )
      )

      # Generate pair-level insights
      pairs <- list()
      for (i in seq_len(k - 1)) {
        for (j in (i + 1):k) {
          norm_val <- dist_matrix[i, j] / max_dist
          pairs[[length(pairs) + 1]] <- list(
            seg_a = seg_names[i], seg_b = seg_names[j],
            dist = dist_matrix[i, j], norm = norm_val
          )
        }
      }
      pairs <- pairs[order(sapply(pairs, function(p) p$norm))]

      insight_items <- lapply(pairs, function(p) {
        if (p$norm < 0.3) {
          td_class <- "seg-td-low"
          text <- sprintf(
            "%s and %s are very similar (distance: %.2f). Consider whether these should be merged.",
            p$seg_a, p$seg_b, p$dist
          )
        } else if (p$norm < 0.5) {
          td_class <- "seg-td-mod-low"
          text <- sprintf(
            "%s and %s show moderate separation (distance: %.2f). Distinguishable but share characteristics.",
            p$seg_a, p$seg_b, p$dist
          )
        } else {
          td_class <- "seg-td-high"
          text <- sprintf(
            "%s and %s are well separated (distance: %.2f).",
            p$seg_a, p$seg_b, p$dist
          )
        }
        htmltools::tags$div(
          class = paste0("seg-pair-insight ", td_class),
          text
        )
      })

      pair_insights <- htmltools::tags$div(
        class = "seg-pair-insights",
        htmltools::tags$div(
          class = "seg-pair-insights-title",
          "Pairwise Assessment"
        ),
        insight_items
      )
    }
  }

  # Colour key using standard heatmap classes
  colour_key <- htmltools::tags$div(
    class = "seg-heatmap-legend",
    htmltools::tags$span(class = "seg-heatmap-legend-item",
      htmltools::tags$span(class = "seg-heatmap-legend-swatch seg-td-low"),
      "Overlapping"
    ),
    htmltools::tags$span(class = "seg-heatmap-legend-item",
      htmltools::tags$span(class = "seg-heatmap-legend-swatch seg-td-mod-low"),
      "Moderate"
    ),
    htmltools::tags$span(class = "seg-heatmap-legend-item",
      htmltools::tags$span(class = "seg-heatmap-legend-swatch seg-td-mod-high"),
      "Good"
    ),
    htmltools::tags$span(class = "seg-heatmap-legend-item",
      htmltools::tags$span(class = "seg-heatmap-legend-swatch seg-td-high"),
      "Distinct"
    )
  )

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-overlap",
    `data-seg-section` = "overlap",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      htmltools::HTML(paste0(
        "Euclidean distances between segment centres in standardised space. ",
        "Larger values indicate more distinct segments. Very low distances suggest ",
        "two segments may be too similar to justify keeping them separate."
      ))
    ),
    colour_key,
    overlap_table,
    pair_insights
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
  accuracy_colour <- if (accuracy >= 80) "var(--seg-success)" else if (accuracy >= 60) "var(--seg-warning)" else "var(--seg-danger)"

  # Check for incremental accuracy data
  has_incremental <- !is.null(gq$incremental_accuracy) ||
    !is.null(gq$top_questions$cumulative_accuracy)
  inc_acc <- if (!is.null(gq$top_questions$cumulative_accuracy)) {
    gq$top_questions$cumulative_accuracy
  } else if (!is.null(gq$incremental_accuracy)) {
    gq$incremental_accuracy
  } else {
    NULL
  }

  summary_box <- htmltools::tags$div(
    class = "seg-finding-box",
    htmltools::tags$div(
      class = "seg-finding-item",
      htmltools::tags$span(class = "seg-finding-icon",
                          style = sprintf("color:%s;", accuracy_colour), "\u25CF"),
      htmltools::tags$span(class = "seg-finding-text",
                          sprintf("Random Forest classification accuracy: %.0f%% using all %d questions (OOB error rate: %.0f%%)",
                                  accuracy, n_top, 100 - accuracy))
    ),
    if (!is.null(inc_acc) && length(inc_acc) >= 1) {
      htmltools::tags$div(
        class = "seg-finding-item",
        htmltools::tags$span(class = "seg-finding-icon",
                            style = "color:var(--seg-accent);", "\u25B6"),
        htmltools::tags$span(class = "seg-finding-text",
                            sprintf("Top 1 question alone achieves %.0f%% accuracy. Toggle questions below to see the impact of each.",
                                    inc_acc[1] * 100))
      )
    }
  )

  chart_el <- if (!is.null(charts$golden_questions)) {
    htmltools::tags$div(
      class = "seg-chart-wrapper",
      build_seg_component_pin_btn("golden-questions", "chart"),
      htmltools::tags$div(class = "seg-chart", charts$golden_questions)
    )
  }

  # Interactive questions table with toggle checkboxes
  tq <- gq$top_questions
  question_labels <- html_data$question_labels

  header <- htmltools::tags$tr(
    htmltools::tags$th("", class = "seg-th", style = "width:36px; text-align:center;"),
    htmltools::tags$th("Rank", class = "seg-th seg-th-rank", style = "width:50px;"),
    htmltools::tags$th("Variable", class = "seg-th"),
    htmltools::tags$th("Importance", class = "seg-th seg-th-num", style = "width:90px;"),
    htmltools::tags$th("Accuracy with this question", class = "seg-th seg-th-num", style = "width:160px;")
  )

  rows <- lapply(seq_len(nrow(tq)), function(i) {
    var_name <- tq$variable[i]
    label <- if (!is.null(question_labels) && var_name %in% names(question_labels)) {
      question_labels[[var_name]]
    } else {
      var_name
    }

    cum_acc_text <- if (!is.null(inc_acc) && i <= length(inc_acc) && !is.na(inc_acc[i])) {
      sprintf("%.0f%%", inc_acc[i] * 100)
    } else {
      "\u2014"
    }
    # Show delta from previous level
    delta_text <- if (!is.null(inc_acc) && i > 1 && i <= length(inc_acc) &&
                      !is.na(inc_acc[i]) && !is.na(inc_acc[i - 1])) {
      delta <- (inc_acc[i] - inc_acc[i - 1]) * 100
      sprintf(" (+%.1f pp)", delta)
    } else {
      ""
    }

    htmltools::tags$tr(
      class = "seg-tr seg-gq-row",
      `data-gq-rank` = i,
      htmltools::tags$td(
        class = "seg-td", style = "text-align:center; vertical-align:middle;",
        htmltools::tags$input(
          type = "checkbox", checked = "checked",
          class = "seg-gq-checkbox",
          style = "width:16px; height:16px; cursor:pointer; accent-color:var(--seg-brand);",
          onchange = "segToggleGoldenQuestion(this)"
        )
      ),
      htmltools::tags$td(
        class = "seg-td seg-td-rank",
        htmltools::tags$span(
          style = if (i == 1) "color:var(--seg-accent);font-weight:700;" else "",
          as.character(i)
        )
      ),
      htmltools::tags$td(
        class = "seg-td",
        htmltools::tags$div(style = "font-weight:500;", label),
        if (label != var_name) {
          htmltools::tags$div(
            style = "font-size:11px;color:var(--seg-text-faint);",
            var_name
          )
        }
      ),
      htmltools::tags$td(
        class = "seg-td seg-td-num",
        sprintf("%.0f%%", tq$pct_of_total[i])
      ),
      htmltools::tags$td(
        class = "seg-td seg-td-num seg-gq-accuracy-cell",
        htmltools::tags$span(class = "seg-gq-cum-acc", cum_acc_text),
        htmltools::tags$span(
          style = "font-size:10px; color:#64748b;",
          delta_text
        )
      )
    )
  })

  # Accuracy summary bar that updates dynamically
  accuracy_summary <- htmltools::tags$div(
    class = "seg-gq-accuracy-summary",
    id = "seg-gq-accuracy-bar",
    style = paste0(
      "margin:12px 0; padding:12px 20px; background:linear-gradient(135deg, #f8fafc, #f0f4ff); ",
      "border-radius:8px; border:1px solid #e2e8f0; display:flex; align-items:center; ",
      "justify-content:space-between; gap:16px;"
    ),
    htmltools::tags$div(
      style = "display:flex; align-items:center; gap:10px;",
      htmltools::tags$span(style = "font-size:13px; color:#64748b;", "Selected questions:"),
      htmltools::tags$span(
        id = "seg-gq-count",
        style = "font-size:18px; font-weight:700; color:var(--seg-brand);",
        as.character(n_top)
      ),
      htmltools::tags$span(style = "font-size:13px; color:#64748b;",
                          sprintf("of %d", n_top))
    ),
    htmltools::tags$div(
      style = "display:flex; align-items:center; gap:10px;",
      htmltools::tags$span(style = "font-size:13px; color:#64748b;", "Estimated accuracy:"),
      htmltools::tags$span(
        id = "seg-gq-accuracy-val",
        style = sprintf("font-size:18px; font-weight:700; color:%s;", accuracy_colour),
        sprintf("%.0f%%", accuracy)
      )
    )
  )

  questions_table <- htmltools::tags$div(
    class = "seg-table-wrapper",
    build_seg_table_toolbar("golden-questions"),
    accuracy_summary,
    htmltools::tags$table(
      class = "seg-table",
      id = "seg-gq-table",
      htmltools::tags$thead(header),
      htmltools::tags$tbody(rows)
    )
  )

  # Store incremental data as JSON for JS
  inc_data_tag <- if (!is.null(inc_acc)) {
    htmltools::tags$script(
      type = "application/json",
      id = "seg-gq-incremental-data",
      sprintf('[%s]', paste(sprintf('%.4f', inc_acc), collapse = ','))
    )
  }

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-golden-questions",
    `data-seg-section` = "golden-questions",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "seg-section-intro",
      htmltools::HTML(paste0(
        "Golden questions are the survey items that best predict segment membership, ",
        "identified using Random Forest variable importance (MeanDecreaseAccuracy). ",
        "Use the checkboxes to see how accuracy changes as questions are added or removed &mdash; ",
        "this helps determine the minimum number of questions needed for a short-form screener."
      ))
    ),
    # Callout explaining difference between importance % and golden question %
    htmltools::tags$div(
      style = paste0(
        "margin:12px 0 16px; padding:12px 16px; background:#f8fafc; ",
        "border-left:3px solid var(--seg-brand); border-radius:0 4px 4px 0; ",
        "font-size:12px; line-height:1.6; color:#475569;"
      ),
      htmltools::tags$strong(style = "color:var(--seg-brand);",
                            "Why do these percentages differ from Variable Importance? "),
      htmltools::HTML(paste0(
        "Variable Importance (above) uses ANOVA eta-squared &mdash; ",
        "it measures how much each variable <em>explains the differences</em> between segments. ",
        "Golden Questions use Random Forest MeanDecreaseAccuracy &mdash; ",
        "it measures how much each variable <em>helps predict</em> which segment a respondent belongs to. ",
        "A variable can be a strong differentiator (high importance) but less useful as a standalone ",
        "predictor if its effect is shared with correlated variables, or vice versa. ",
        "Both perspectives are valuable: importance tells you <em>what defines</em> the segments, ",
        "golden questions tell you <em>what identifies</em> them."
      ))
    ),
    summary_box,
    chart_el,
    questions_table,
    inc_data_tag
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

  status_colour <- if (overall_pct > 30) "var(--seg-danger)" else if (overall_pct > 15) "var(--seg-warning)" else "var(--seg-success)"
  status_label <- if (overall_pct > 30) "High" else if (overall_pct > 15) "Moderate" else "Low"

  summary_box <- htmltools::tags$div(
    class = "seg-finding-box",
    htmltools::tags$div(
      class = "seg-finding-item",
      htmltools::tags$span(class = "seg-finding-icon",
                          style = sprintf("color:%s;", status_colour), "\u25CF"),
      htmltools::tags$span(class = "seg-finding-text",
                          sprintf("%s vulnerability: %.0f%% of respondents are borderline (confidence < %.1f)",
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

  # Map generic segment labels to actual segment names
  seg_names <- html_data$segment_names
  if (!is.null(seg_names) && !is.null(seg_summary) && nrow(seg_summary) == length(seg_names)) {
    seg_summary$segment <- seg_names
  }

  seg_table <- NULL
  if (!is.null(seg_summary) && nrow(seg_summary) > 0) {
    header <- htmltools::tags$tr(
      htmltools::tags$th("Segment", class = "seg-th"),
      htmltools::tags$th("n", class = "seg-th seg-th-num"),
      htmltools::tags$th("Vulnerable", class = "seg-th seg-th-num"),
      htmltools::tags$th("% Vulnerable", class = "seg-th seg-th-num"),
      htmltools::tags$th("Avg Confidence", class = "seg-th seg-th-num")
    )

    rows <- lapply(seq_len(nrow(seg_summary)), function(i) {
      row <- seg_summary[i, ]
      pct_vuln <- round(row$pct_vulnerable, 1)
      bar_colour <- if (pct_vuln > 30) "var(--seg-danger)" else if (pct_vuln > 15) "var(--seg-warning)" else "var(--seg-success)"

      htmltools::tags$tr(
        htmltools::tags$td(row$segment, class = "seg-td"),
        htmltools::tags$td(format(row$n, big.mark = ","), class = "seg-td seg-td-num"),
        htmltools::tags$td(format(row$n_vulnerable, big.mark = ","), class = "seg-td seg-td-num"),
        htmltools::tags$td(
          class = "seg-td seg-td-num",
          htmltools::tags$span(
            style = sprintf("color:%s; font-weight:500;", bar_colour),
            sprintf("%.0f%%", pct_vuln)
          )
        ),
        htmltools::tags$td(sprintf("%.2f", row$avg_confidence), class = "seg-td seg-td-num")
      )
    })

    seg_table <- htmltools::tags$div(
      class = "seg-table-wrapper",
      build_seg_table_toolbar("vulnerability"),
      htmltools::tags$table(
        class = "seg-table",
        htmltools::tags$thead(header),
        htmltools::tags$tbody(rows)
      )
    )
  }

  # Switching matrix with % display and count toggle
  sw_matrix <- vuln$switching_matrix
  matrix_el <- NULL
  if (!is.null(sw_matrix) && nrow(sw_matrix) > 0) {
    k <- nrow(sw_matrix)
    seg_names_for_matrix <- html_data$segment_names %||% (rownames(sw_matrix) %||% paste0("Seg ", 1:k))

    # Compute row percentages
    row_totals <- rowSums(sw_matrix, na.rm = TRUE)

    m_header <- htmltools::tags$tr(
      htmltools::tags$th("From \\ To", class = "seg-th"),
      lapply(seg_names_for_matrix, function(s) htmltools::tags$th(s, class = "seg-th seg-th-num"))
    )

    m_rows <- lapply(seq_len(k), function(i) {
      cells <- lapply(seq_len(k), function(j) {
        val <- sw_matrix[i, j]
        row_total <- row_totals[i]
        pct <- if (row_total > 0 && i != j) round(100 * val / row_total, 0) else 0

        bg <- if (i == j) "#f8fafc" else if (val > 0) {
          intensity <- min(val / max(sw_matrix[sw_matrix > 0], na.rm = TRUE), 1)
          sprintf("rgba(239, 68, 68, %.2f)", intensity * 0.3)
        } else {
          "transparent"
        }

        if (i == j) {
          htmltools::tags$td(
            class = "seg-td seg-td-num",
            style = sprintf("background:%s;", bg),
            "-"
          )
        } else {
          htmltools::tags$td(
            class = "seg-td seg-td-num",
            style = sprintf("background:%s;", bg),
            htmltools::tags$span(class = "seg-sw-pct", sprintf("%d%%", pct)),
            htmltools::tags$span(class = "seg-sw-count",
                                style = "display:none; font-size:10px; color:#94a3b8;",
                                sprintf(" (%d)", val))
          )
        }
      })
      htmltools::tags$tr(
        htmltools::tags$td(seg_names_for_matrix[i], class = "seg-td", style = "font-weight:500;"),
        cells
      )
    })

    matrix_el <- htmltools::tags$div(
      class = "seg-table-wrapper",
      build_seg_table_export_toolbar("switching-matrix"),
      htmltools::tags$h4(class = "seg-subsection-title", "Switching Matrix"),
      htmltools::tags$p(class = "seg-section-intro", style = "font-size:12px;",
                        "Percentage of borderline respondents in each segment (rows) who would switch to another segment (columns)."),
      htmltools::tags$div(
        style = "display:flex; align-items:center; gap:8px; margin:6px 0 10px;",
        htmltools::tags$label(
          style = "font-size:12px; color:#64748b; display:flex; align-items:center; gap:6px; cursor:pointer;",
          htmltools::tags$input(
            type = "checkbox",
            style = "accent-color:var(--seg-brand); cursor:pointer;",
            onchange = "document.querySelectorAll('.seg-sw-count').forEach(function(el){el.style.display=this.checked?'inline':'none'}.bind(this))"
          ),
          "Show counts"
        )
      ),
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
      build_seg_table_toolbar("gmm"),
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
                            sprintf("Average maximum membership probability: %.0f%%", avg_prob))
      ),
      if (uncertain_pct > 0) {
        htmltools::tags$div(
          class = "seg-finding-item",
          htmltools::tags$span(class = "seg-finding-icon",
                              style = "color:var(--seg-warning);", "\u26A0"),
          htmltools::tags$span(class = "seg-finding-text",
                              sprintf("%.0f%% of respondents have uncertain membership (max probability < 70%%)", uncertain_pct))
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

  # Use callout registry for interpretation guide and how-it-works
  interp_callout <- if (exists("turas_callout", mode = "function")) {
    turas_callout("segment", "interpretation_guide")
  } else {
    ""
  }
  how_callout <- if (exists("turas_callout", mode = "function")) {
    turas_callout("segment", "how_it_works")
  } else {
    ""
  }

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-guide",
    `data-seg-section` = "guide",
    title_row,
    htmltools::HTML(interp_callout),
    htmltools::HTML(how_callout)
  )
}


# ==============================================================================
# FOOTER
# ==============================================================================

#' Build Footer
# ==============================================================================
# METHOD CALLOUT (layperson explanation)
# ==============================================================================

#' Build Method Callout
#'
#' A plain-language explanation of the clustering method used, appropriate
#' for non-technical stakeholders. Includes when to use, strengths, and
#' limitations.
#'
#' @param method Character, clustering method name
#' @param k Integer, number of segments
#' @return htmltools tag or NULL
#' @keywords internal
.build_method_callout <- function(method, k) {

  method_lower <- tolower(method)

  if (method_lower %in% c("kmeans", "k-means")) {
    title <- "About K-Means Clustering"
    icon <- "\U0001F3AF"
    description <- sprintf(paste0(
      "K-Means groups respondents into %d segments by finding natural patterns in the data. ",
      "It works by placing %d centre points and assigning each respondent to their nearest centre, ",
      "then adjusting the centres until the groups stabilise. Think of it as finding %d ",
      "\"tribes\" of similar people in your data."
    ), k, k, k)
    strengths <- c(
      "Fast and efficient, even with large datasets (thousands of respondents)",
      "Produces clearly defined, non-overlapping segments",
      "Easy to interpret \u2014 each respondent belongs to exactly one segment",
      "Well-established method with decades of proven use in market research"
    )
    considerations <- c(
      "Assumes segments are roughly similar in size and shape",
      "Results can vary slightly between runs (mitigated by multiple starts)",
      "Requires you to specify the number of segments in advance",
      "Works best with continuous, numeric data (e.g., rating scales)"
    )
    when_to_use <- "K-Means is the most widely used segmentation method in market research. It is the recommended starting point for most projects, especially when working with rating-scale survey data and when you need clearly interpretable, actionable segments."

  } else if (method_lower %in% c("hclust", "hierarchical")) {
    title <- "About Hierarchical Clustering"
    icon <- "\U0001F333"
    description <- sprintf(paste0(
      "Hierarchical clustering builds a tree-like structure (dendrogram) showing how respondents ",
      "group together at different levels of similarity. The tree is then cut at a level that ",
      "produces %d segments. Unlike K-Means, it reveals the natural hierarchy of relationships ",
      "in the data \u2014 showing which segments are most similar to each other."
    ), k)
    strengths <- c(
      "Reveals the natural structure of relationships between groups",
      "No need to specify the number of segments upfront \u2014 the dendrogram guides the decision",
      "Can handle different cluster shapes and sizes",
      "Deterministic \u2014 same data always produces the same result"
    )
    considerations <- c(
      "Can be slow with very large datasets (>5,000 respondents)",
      "Once a respondent is assigned to a group, the decision cannot be reversed",
      "Sensitive to outliers \u2014 extreme respondents can distort the tree",
      "Multiple linkage methods exist (Ward, complete, average) \u2014 choice affects results"
    )
    when_to_use <- "Hierarchical clustering is particularly useful when you want to understand the relationships between segments, when the natural number of segments is unclear, or when you need a deterministic result that does not change between runs."

  } else if (method_lower %in% c("gmm", "mclust", "gaussian")) {
    title <- "About Gaussian Mixture Models (GMM)"
    icon <- "\U0001F52C"
    description <- sprintf(paste0(
      "GMM assumes the data is generated by %d overlapping bell-curve distributions (Gaussians). ",
      "Rather than assigning each respondent to a single hard segment, GMM calculates the ",
      "probability of belonging to each segment. A respondent might be 70%% likely in Segment A ",
      "and 30%% likely in Segment B. This captures the reality that people do not always fit ",
      "neatly into one box."
    ), k)
    strengths <- c(
      "Provides probability-based (soft) assignments \u2014 captures uncertainty",
      "Can detect segments of different sizes and shapes",
      "Handles overlapping segments naturally",
      "Statistical model selection criteria (BIC) can guide the number of segments"
    )
    considerations <- c(
      "More complex to interpret than K-Means (probabilities vs. hard assignments)",
      "Requires larger sample sizes to estimate reliably",
      "Can be sensitive to the initial starting values",
      "May overfit with too many variables relative to sample size"
    )
    when_to_use <- "GMM is ideal when you expect segments to overlap, when you want to quantify the uncertainty of each respondent's assignment, or when you need a statistically rigorous model that can handle non-spherical cluster shapes."

  } else {
    return(NULL)
  }

  # Build the callout
  strength_items <- lapply(strengths, function(s) {
    htmltools::tags$li(style = "margin-bottom:4px;", s)
  })
  consideration_items <- lapply(considerations, function(c) {
    htmltools::tags$li(style = "margin-bottom:4px;", c)
  })

  htmltools::tags$div(
    style = paste0(
      "background:linear-gradient(135deg, #f8fafc, #f0f4ff); border:1px solid #e2e8f0; ",
      "border-radius:8px; padding:20px; margin:16px 0; line-height:1.6;"
    ),
    htmltools::tags$div(
      style = "display:flex; align-items:center; gap:10px; margin-bottom:10px;",
      htmltools::tags$span(style = "font-size:22px;", icon),
      htmltools::tags$span(
        style = "font-size:15px; font-weight:600; color:var(--seg-brand);",
        title
      )
    ),
    htmltools::tags$p(
      style = "font-size:13px; color:#334155; margin:0 0 12px;",
      description
    ),
    htmltools::tags$div(
      style = "display:grid; grid-template-columns:1fr 1fr; gap:16px; margin-bottom:12px;",
      htmltools::tags$div(
        htmltools::tags$div(
          style = "font-size:12px; font-weight:600; color:#16a34a; margin-bottom:6px;",
          "\u2705 Strengths"
        ),
        htmltools::tags$ul(
          style = "margin:0; padding-left:18px; font-size:12px; color:#334155;",
          strength_items
        )
      ),
      htmltools::tags$div(
        htmltools::tags$div(
          style = "font-size:12px; font-weight:600; color:#d97706; margin-bottom:6px;",
          "\u26A0\uFE0F Considerations"
        ),
        htmltools::tags$ul(
          style = "margin:0; padding-left:18px; font-size:12px; color:#334155;",
          consideration_items
        )
      )
    ),
    htmltools::tags$div(
      style = paste0(
        "font-size:12px; color:var(--seg-brand); font-style:italic; ",
        "border-top:1px solid #e2e8f0; padding-top:10px; margin-top:4px;"
      ),
      htmltools::tags$strong("When to use: "),
      when_to_use
    )
  )
}


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
    sprintf("Generated by TURAS Segmentation Module v11.1 | %s",
            format(Sys.time(), "%d %B %Y %H:%M")),
    htmltools::tags$br(),
    prepared
  )
}


# ==============================================================================
# SLIDES SECTION
# ==============================================================================

#' Build Slides Section
#'
#' Provides a slides workspace where users can add custom slides with
#' titles, text content, and images. Slides can be pre-configured from
#' the Excel config (Slides sheet) or added interactively.
#'
#' @param config Configuration list
#' @return htmltools tag
#' @keywords internal
build_seg_slides_section <- function(config) {

  pre_slides <- config$slides

  # Build pre-configured slides from config
  pre_slide_els <- NULL
  if (!is.null(pre_slides) && length(pre_slides) > 0) {
    pre_slide_els <- lapply(seq_along(pre_slides), function(i) {
      sl <- pre_slides[[i]]
      img_el <- NULL
      if (nzchar(sl$image_path) && file.exists(sl$image_path)) {
        ext <- tolower(tools::file_ext(sl$image_path))
        mime <- switch(ext, png = "image/png", jpg = "image/jpeg",
                       jpeg = "image/jpeg", gif = "image/gif", "image/png")
        img_data <- base64enc::base64encode(sl$image_path)
        img_el <- htmltools::tags$div(
          class = "seg-slide-image",
          style = "margin:12px 0;",
          htmltools::tags$img(
            src = sprintf("data:%s;base64,%s", mime, img_data),
            style = "max-width:100%; border-radius:6px; border:1px solid #e2e8f0;"
          )
        )
      }
      htmltools::tags$div(
        class = "seg-slide-card",
        `data-slide-index` = i,
        style = paste0(
          "background:#fff; border:1px solid #e2e8f0; border-radius:8px; ",
          "padding:20px; margin-bottom:16px; position:relative;"
        ),
        htmltools::tags$div(
          style = "position:absolute; top:8px; right:12px; display:flex; gap:6px;",
          htmltools::tags$button(
            style = paste0(
              "background:none; border:1px solid #d1d5db; border-radius:4px; ",
              "color:#64748b; font-size:12px; cursor:pointer; padding:2px 8px;"
            ),
            onclick = "segPinSlide(this)",
            title = "Pin to Views",
            "\U0001F4CC"
          ),
          htmltools::tags$button(
            class = "seg-slide-remove-btn",
            style = paste0(
              "background:none; border:none; ",
              "color:#94a3b8; font-size:18px; cursor:pointer; padding:4px;"
            ),
            onclick = "this.closest('.seg-slide-card').remove(); segUpdateSlideCount();",
            "\u00D7"
          )
        ),
        htmltools::tags$div(
          class = "seg-slide-title",
          contenteditable = "true",
          style = paste0(
            "font-size:16px; font-weight:600; color:var(--seg-brand); margin-bottom:8px; ",
            "border-bottom:2px solid var(--seg-brand); padding-bottom:6px; outline:none;"
          ),
          `data-placeholder` = "Slide title...",
          sl$title
        ),
        htmltools::tags$div(
          class = "seg-slide-content",
          contenteditable = "true",
          style = paste0(
            "font-size:13px; color:#334155; line-height:1.6; min-height:60px; ",
            "outline:none; border:1px dashed transparent; padding:8px; border-radius:4px;"
          ),
          `data-placeholder` = "Add slide content...",
          htmltools::HTML(gsub("\n", "<br/>", htmltools::htmlEscape(sl$content)))
        ),
        img_el,
        htmltools::tags$div(
          style = "margin-top:8px; text-align:right;",
          htmltools::tags$label(
            style = paste0(
              "font-size:11px; color:#64748b; cursor:pointer; padding:4px 10px; ",
              "border:1px solid #d1d5db; border-radius:4px; display:inline-block;"
            ),
            "\U0001F4F7 Add Image",
            htmltools::tags$input(
              type = "file", accept = "image/*",
              style = "display:none;",
              onchange = "segSlideImageUpload(this)"
            )
          )
        )
      )
    })
  }

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-slides-section",
    htmltools::tags$div(
      class = "seg-section-title-row",
      htmltools::tags$h2(class = "seg-section-title", "\U0001F4CA Slides"),
      htmltools::tags$div(
        style = "display:flex; gap:8px;",
        htmltools::tags$button(
          style = paste0(
            "font-size:12px; padding:6px 14px; border:1px solid var(--seg-brand); ",
            "border-radius:6px; background:var(--seg-brand); color:#fff; cursor:pointer;"
          ),
          onclick = "segAddSlide()",
          "\u2795 Add Slide"
        ),
        htmltools::tags$button(
          style = paste0(
            "font-size:12px; padding:6px 14px; border:1px solid #d1d5db; ",
            "border-radius:6px; background:#fff; color:#334155; cursor:pointer;"
          ),
          onclick = "segExportAllSlidesPNG()",
          "\U0001F4E5 Export All as PNG"
        )
      )
    ),
    htmltools::tags$hr(style = "border:none; border-top:3px solid var(--seg-brand); margin:8px 0 16px;"),
    htmltools::tags$p(
      style = "font-size:13px; color:#64748b; margin-bottom:16px;",
      "Create presentation slides with custom titles, content, and images. ",
      "Slides can be pre-configured in the Excel config (Slides sheet) or added here. ",
      "Click the image button on any slide to upload a chart or screenshot."
    ),
    htmltools::tags$div(
      id = "seg-slides-container",
      pre_slide_els
    ),
    if (is.null(pre_slide_els) || length(pre_slide_els) == 0) {
      htmltools::tags$div(
        id = "seg-slides-empty",
        style = paste0(
          "text-align:center; padding:40px; color:#94a3b8; ",
          "border:2px dashed #e2e8f0; border-radius:8px; margin:20px 0;"
        ),
        htmltools::tags$div(style = "font-size:32px; margin-bottom:8px;", "\U0001F4CA"),
        htmltools::tags$div("No slides yet. Click 'Add Slide' to create one."),
        htmltools::tags$div(
          style = "font-size:12px; margin-top:8px;",
          "Or add a 'Slides' sheet to your config Excel with Title, Content, and Image columns."
        )
      )
    }
  )
}


# ==============================================================================
# ABOUT SECTION
# ==============================================================================

#' Build About Section
#'
#' Displays analyst details, project information, and methodology notes.
#' Content comes from the config (About sheet) and analysis metadata.
#'
#' @param config Configuration list
#' @param html_data Transformed HTML data
#' @return htmltools tag
#' @keywords internal
build_seg_about_section <- function(config, html_data) {

  about <- config$about %||% list()

  # Safe accessor for named vectors/lists (avoids subscript out of bounds)
  .safe_get <- function(x, key, default = "") {
    if (is.null(x) || length(x) == 0) return(default)
    if (key %in% names(x)) {
      val <- unname(x[key])
      if (is.null(val) || is.na(val) || !nzchar(val)) default else val
    } else {
      default
    }
  }

  analyst <- .safe_get(about, "analyst", config$analyst_name %||% "Not specified")
  company <- .safe_get(about, "company", .safe_get(about, "organisation", ""))
  email <- .safe_get(about, "email")
  project <- .safe_get(about, "project", config$project_name %||% "")
  client <- .safe_get(about, "client")
  date <- .safe_get(about, "date", format(Sys.Date(), "%d %B %Y"))
  notes <- .safe_get(about, "notes", .safe_get(about, "methodology", ""))
  confidentiality <- .safe_get(about, "confidentiality")

  # Build detail rows
  detail_row <- function(label, value) {
    if (is.null(value) || !nzchar(trimws(value))) return(NULL)
    htmltools::tags$tr(
      htmltools::tags$td(
        style = "padding:10px 16px; font-weight:600; color:var(--seg-brand); width:180px; vertical-align:top;",
        label
      ),
      htmltools::tags$td(
        style = "padding:10px 16px; color:#334155;",
        value
      )
    )
  }

  # Method summary
  method_text <- sprintf(
    "%s clustering with k=%d on %d observations (%d variables). Average silhouette: %.3f.",
    toupper(html_data$method %||% "kmeans"),
    html_data$k %||% 0,
    html_data$n_observations %||% 0,
    length(html_data$variable_importance$variable %||% character(0)),
    html_data$diagnostics$silhouette_avg %||% 0
  )

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-about-section",
    htmltools::tags$div(
      class = "seg-section-title-row",
      htmltools::tags$h2(class = "seg-section-title", "About This Report")
    ),
    htmltools::tags$hr(style = "border:none; border-top:3px solid var(--seg-brand); margin:8px 0 16px;"),

    # Analyst / Project details card
    htmltools::tags$div(
      style = paste0(
        "background:#fff; border:1px solid #e2e8f0; border-radius:8px; ",
        "padding:0; margin-bottom:20px; overflow:hidden;"
      ),
      htmltools::tags$div(
        style = paste0(
          "background:linear-gradient(135deg, var(--seg-brand), #434380); color:#fff; ",
          "padding:16px 20px; font-size:15px; font-weight:600;"
        ),
        "Report Details"
      ),
      htmltools::tags$table(
        style = "width:100%; border-collapse:collapse;",
        detail_row("Analyst", analyst),
        detail_row("Company", company),
        detail_row("Email", email),
        detail_row("Project", project),
        detail_row("Client", client),
        detail_row("Date", date),
        detail_row("Method", method_text),
        detail_row("Confidentiality", confidentiality)
      )
    ),

    # Notes / methodology
    if (nzchar(trimws(notes))) {
      htmltools::tags$div(
        style = paste0(
          "background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; ",
          "padding:20px; margin-bottom:20px;"
        ),
        htmltools::tags$div(
          style = "font-weight:600; color:var(--seg-brand); margin-bottom:8px; font-size:14px;",
          "Methodology Notes"
        ),
        htmltools::tags$div(
          style = "font-size:13px; color:#334155; line-height:1.7; white-space:pre-wrap;",
          notes
        )
      )
    },

    # Editable notes area
    htmltools::tags$div(
      style = paste0(
        "background:#fff; border:1px solid #e2e8f0; border-radius:8px; ",
        "padding:20px; margin-bottom:20px;"
      ),
      htmltools::tags$div(
        style = "font-weight:600; color:var(--seg-brand); margin-bottom:8px; font-size:14px;",
        "Additional Notes"
      ),
      htmltools::tags$div(
        class = "seg-about-notes-editor",
        contenteditable = "true",
        style = paste0(
          "min-height:80px; padding:12px; border:1px dashed rgba(50,51,103,0.3); ",
          "border-radius:4px; font-size:13px; color:#334155; line-height:1.6; outline:none;"
        ),
        `data-placeholder` = "Add any additional notes about this analysis..."
      )
    ),

    # Software info
    htmltools::tags$div(
      style = paste0(
        "background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; ",
        "padding:16px 20px; font-size:12px; color:#94a3b8; line-height:1.6;"
      ),
      htmltools::tags$div(
        style = "font-weight:600; color:#64748b; margin-bottom:4px;",
        "Software"
      ),
      sprintf("TURAS Segmentation Module v%s | R %s | Generated %s",
              "11.1",
              paste(R.version$major, R.version$minor, sep = "."),
              format(Sys.time(), "%d %B %Y %H:%M:%S"))
    )
  )
}
