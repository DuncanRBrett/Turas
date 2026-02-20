# ==============================================================================
# TurasTracker HTML Report - Page Builder
# ==============================================================================
# Assembles the complete HTML page with CSS, JS, sidebar, controls.
# Follows the Turas Tabs page_builder.R pattern.
# VERSION: 1.0.0
# ==============================================================================


#' Build Tracker HTML Page
#'
#' Assembles the complete HTML page from tables, charts, and controls.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param table_html htmltools::HTML. Table from build_tracking_table()
#' @param charts List. Line chart SVGs from build_line_chart()
#' @param config List. Tracker configuration
#' @return htmltools::browsable tagList
#' @export
build_tracker_page <- function(html_data, table_html, charts, config) {

  brand_colour <- get_setting(config, "brand_colour", default = "#323367") %||% "#323367"
  accent_colour <- get_setting(config, "accent_colour", default = "#CC9900") %||% "#CC9900"
  project_name <- get_setting(config, "project_name", default = "Tracking Report") %||% "Tracking Report"

  page <- htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "UTF-8"),
      htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1.0"),
      htmltools::tags$title(paste0(project_name, " - Tracking Report")),
      htmltools::tags$meta(name = "turas-report-type", content = "tracker"),
      htmltools::tags$meta(name = "turas-generated", content = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")),
      htmltools::tags$style(htmltools::HTML(build_tracker_css(brand_colour, accent_colour)))
    ),

    # Header
    build_tracker_header(html_data, config, brand_colour),

    # Main layout
    htmltools::tags$div(class = "tk-layout",

      # Sidebar
      build_tracker_sidebar(html_data, config),

      # Content area
      htmltools::tags$main(class = "tk-content",

        # Banner segment tabs
        build_segment_tabs(html_data, config, brand_colour),

        # Controls
        build_controls(html_data, config),

        # Table + Charts container
        htmltools::tags$div(class = "tk-main-area",
          htmltools::tags$div(class = "tk-table-panel", table_html),
          htmltools::tags$div(class = "tk-chart-panel",
            id = "tk-chart-panel",
            style = "display:none",
            build_chart_containers(html_data, charts, config)
          )
        )
      )
    ),

    # Footer
    build_tracker_footer(html_data, config),

    # Help overlay
    build_help_overlay(),

    # JavaScript
    htmltools::tags$script(htmltools::HTML(build_tracker_javascript(html_data)))
  )

  htmltools::browsable(page)
}


# ==============================================================================
# HEADER
# ==============================================================================

#' @keywords internal
build_tracker_header <- function(html_data, config, brand_colour) {

  project_name <- html_data$metadata$project_name %||% "Tracking Report"
  company_name <- get_setting(config, "company_name", default = "") %||% ""
  n_metrics <- html_data$n_metrics
  n_waves <- length(html_data$waves)
  n_segments <- length(html_data$segments)

  # Logos (base64 embedded)
  researcher_logo <- ""
  client_logo <- ""
  logo_path <- get_setting(config, "researcher_logo_path", default = NULL)
  if (!is.null(logo_path) && file.exists(logo_path)) {
    logo_b64 <- base64enc::dataURI(file = logo_path, mime = "image/png")
    researcher_logo <- sprintf('<img src="%s" alt="Logo" class="tk-logo"/>', logo_b64)
  }
  client_logo_path <- get_setting(config, "client_logo_path", default = NULL)
  if (!is.null(client_logo_path) && file.exists(client_logo_path)) {
    clogo_b64 <- base64enc::dataURI(file = client_logo_path, mime = "image/png")
    client_logo <- sprintf('<img src="%s" alt="Client Logo" class="tk-logo"/>', clogo_b64)
  }

  htmltools::tags$header(class = "tk-header", style = sprintf("background-color:%s", brand_colour),
    htmltools::tags$div(class = "tk-header-left",
      htmltools::HTML(researcher_logo),
      htmltools::tags$div(class = "tk-header-text",
        htmltools::tags$h1(class = "tk-header-title", project_name),
        htmltools::tags$span(class = "tk-header-subtitle", "Tracking Report")
      )
    ),
    htmltools::tags$div(class = "tk-header-right",
      htmltools::tags$div(class = "tk-header-stats",
        htmltools::tags$span(paste0(n_metrics, " metrics")),
        htmltools::tags$span(class = "tk-header-sep", "|"),
        htmltools::tags$span(paste0(n_waves, " waves")),
        htmltools::tags$span(class = "tk-header-sep", "|"),
        htmltools::tags$span(paste0(n_segments, " segment", if (n_segments > 1) "s" else ""))
      ),
      htmltools::HTML(client_logo)
    )
  )
}


# ==============================================================================
# SIDEBAR
# ==============================================================================

#' @keywords internal
build_tracker_sidebar <- function(html_data, config) {

  # Build metric list grouped by section
  items <- c()
  current_section <- ""

  for (i in seq_along(html_data$metric_rows)) {
    mr <- html_data$metric_rows[[i]]
    section <- if (is.na(mr$section) || mr$section == "") "(Ungrouped)" else mr$section

    if (section != current_section) {
      current_section <- section
      items <- c(items, sprintf(
        '<div class="tk-sidebar-section">%s</div>',
        htmltools::htmlEscape(section)
      ))
    }

    items <- c(items, sprintf(
      '<a class="tk-sidebar-item" href="#%s" data-metric-id="%s" onclick="selectMetric(\'%s\');return false;">%s</a>',
      mr$metric_id, mr$metric_id, mr$metric_id,
      htmltools::htmlEscape(mr$metric_label)
    ))
  }

  htmltools::tags$aside(class = "tk-sidebar",
    htmltools::tags$div(class = "tk-sidebar-search",
      htmltools::tags$input(
        type = "text",
        class = "tk-search-input",
        placeholder = "Search metrics...",
        oninput = "filterMetrics(this.value)"
      )
    ),
    htmltools::tags$nav(class = "tk-sidebar-nav",
      htmltools::HTML(paste(items, collapse = "\n"))
    )
  )
}


# ==============================================================================
# SEGMENT TABS
# ==============================================================================

#' @keywords internal
build_segment_tabs <- function(html_data, config, brand_colour) {
  segments <- html_data$segments

  if (length(segments) <= 1) return(htmltools::tags$div())

  tabs <- c()
  for (seg_idx in seq_along(segments)) {
    seg_name <- segments[seg_idx]
    active_class <- if (seg_idx == 1) " tk-tab-active" else ""
    tabs <- c(tabs, sprintf(
      '<button class="tk-segment-tab%s" data-segment="%s" onclick="switchSegment(\'%s\')">%s</button>',
      active_class,
      htmltools::htmlEscape(seg_name),
      htmltools::htmlEscape(seg_name),
      htmltools::htmlEscape(seg_name)
    ))
  }

  # "All Segments" tab to compare
  tabs <- c(tabs, sprintf(
    '<button class="tk-segment-tab" data-segment="__ALL__" onclick="switchSegment(\'__ALL__\')">All Segments</button>'
  ))

  htmltools::tags$div(class = "tk-segment-tabs",
    htmltools::HTML(paste(tabs, collapse = "\n"))
  )
}


# ==============================================================================
# CONTROLS
# ==============================================================================

#' @keywords internal
build_controls <- function(html_data, config) {

  htmltools::tags$div(class = "tk-controls",
    # View toggles
    htmltools::tags$div(class = "tk-control-group",
      htmltools::tags$label(class = "tk-toggle",
        htmltools::tags$input(type = "checkbox", id = "toggle-vs-prev",
                               onchange = "toggleChangeRows('vs-prev')"),
        htmltools::tags$span(class = "tk-toggle-label", "Show vs Previous")
      ),
      htmltools::tags$label(class = "tk-toggle",
        htmltools::tags$input(type = "checkbox", id = "toggle-vs-base",
                               onchange = "toggleChangeRows('vs-base')"),
        htmltools::tags$span(class = "tk-toggle-label", "Show vs Baseline")
      ),
      htmltools::tags$label(class = "tk-toggle",
        htmltools::tags$input(type = "checkbox", id = "toggle-sparklines",
                               checked = "checked",
                               onchange = "toggleSparklines()"),
        htmltools::tags$span(class = "tk-toggle-label", "Sparklines")
      )
    ),

    # Chart / Table toggle
    htmltools::tags$div(class = "tk-control-group",
      htmltools::tags$button(class = "tk-btn tk-btn-view tk-btn-active",
                              id = "btn-table-view",
                              onclick = "switchView('table')", "Table"),
      htmltools::tags$button(class = "tk-btn tk-btn-view",
                              id = "btn-chart-view",
                              onclick = "switchView('chart')", "Charts")
    ),

    # Group by
    htmltools::tags$div(class = "tk-control-group",
      htmltools::tags$span(class = "tk-control-label", "Group by:"),
      htmltools::tags$select(class = "tk-select", id = "group-by-select",
                              onchange = "switchGroupBy(this.value)",
        htmltools::tags$option(value = "section", selected = "selected", "Section"),
        htmltools::tags$option(value = "metric_type", "Metric Type"),
        htmltools::tags$option(value = "question", "Question")
      )
    ),

    # Export buttons
    htmltools::tags$div(class = "tk-control-group tk-export-group",
      htmltools::tags$button(class = "tk-btn tk-btn-export",
                              onclick = "exportCSV()", "Export CSV"),
      htmltools::tags$button(class = "tk-btn tk-btn-export",
                              onclick = "exportExcel()", "Export Excel"),
      htmltools::tags$button(class = "tk-btn",
                              onclick = "toggleHelpOverlay()", "?")
    )
  )
}


# ==============================================================================
# CHART CONTAINERS
# ==============================================================================

#' @keywords internal
build_chart_containers <- function(html_data, charts, config) {

  containers <- c()
  for (i in seq_along(charts)) {
    if (is.null(charts[[i]])) next

    mr <- html_data$metric_rows[[i]]
    section <- if (is.na(mr$section) || mr$section == "") "(Ungrouped)" else mr$section

    containers <- c(containers, sprintf(
      '<div class="tk-chart-container" data-metric-id="%s" data-section="%s">',
      mr$metric_id, htmltools::htmlEscape(section)
    ))
    containers <- c(containers, sprintf(
      '<h3 class="tk-chart-title">%s</h3>',
      htmltools::htmlEscape(mr$metric_label)
    ))
    containers <- c(containers, as.character(charts[[i]]))
    containers <- c(containers, sprintf(
      '<div class="tk-chart-actions"><button class="tk-btn tk-btn-sm" onclick="exportChartPNG(\'%s\')">Export PNG</button></div>',
      mr$metric_id
    ))
    containers <- c(containers, '</div>')
  }

  htmltools::HTML(paste(containers, collapse = "\n"))
}


# ==============================================================================
# FOOTER
# ==============================================================================

#' @keywords internal
build_tracker_footer <- function(html_data, config) {

  company_name <- get_setting(config, "company_name", default = "") %||% ""
  baseline_label <- html_data$wave_lookup[html_data$baseline_wave]

  htmltools::tags$footer(class = "tk-footer",
    htmltools::tags$div(class = "tk-footer-info",
      htmltools::tags$span(sprintf("Baseline: %s (%s)", html_data$baseline_wave, baseline_label)),
      htmltools::tags$span(class = "tk-footer-sep", "|"),
      htmltools::tags$span(sprintf("Confidence: %s%%", round(html_data$metadata$confidence_level * 100))),
      htmltools::tags$span(class = "tk-footer-sep", "|"),
      htmltools::tags$span(sprintf("Generated: %s", format(html_data$metadata$generated_at, "%d %b %Y %H:%M")))
    ),
    if (nzchar(company_name)) {
      htmltools::tags$div(class = "tk-footer-credit",
        htmltools::tags$span(paste0("Prepared by ", company_name)),
        htmltools::tags$span(" | Powered by Turas Analytics")
      )
    }
  )
}


# ==============================================================================
# HELP OVERLAY
# ==============================================================================

#' @keywords internal
build_help_overlay <- function() {

  htmltools::tags$div(id = "tk-help-overlay", class = "tk-help-overlay",
                       style = "display:none",
    htmltools::tags$div(class = "tk-help-content",
      htmltools::tags$h2("Tracking Report Help"),
      htmltools::tags$button(class = "tk-help-close", onclick = "toggleHelpOverlay()",
                              htmltools::HTML("&times;")),
      htmltools::tags$div(class = "tk-help-body",
        htmltools::tags$h3("Navigation"),
        htmltools::tags$p("Use the sidebar to jump to specific metrics. Use the search box to filter."),
        htmltools::tags$h3("Segments"),
        htmltools::tags$p("Click segment tabs to show data for different banner groups. 'All Segments' shows all columns side by side."),
        htmltools::tags$h3("Change Rows"),
        htmltools::tags$p("Toggle 'vs Previous' and 'vs Baseline' to show change sub-rows with significance indicators."),
        htmltools::tags$h3("Significance Indicators"),
        htmltools::tags$ul(
          htmltools::tags$li(htmltools::HTML("<span class='sig-up'>&#x2191;</span> Significant increase")),
          htmltools::tags$li(htmltools::HTML("<span class='sig-down'>&#x2193;</span> Significant decrease")),
          htmltools::tags$li(htmltools::HTML("<span class='not-sig'>&#x2192;</span> No significant change"))
        ),
        htmltools::tags$h3("Export"),
        htmltools::tags$p("Export the visible table as CSV or Excel. Export charts as PNG images.")
      )
    )
  )
}


# ==============================================================================
# CSS
# ==============================================================================

#' Build Tracker CSS
#' @keywords internal
build_tracker_css <- function(brand_colour, accent_colour) {

  css <- '
/* === TURAS TRACKER HTML REPORT === */
:root {
  --brand: BRAND_COLOUR;
  --accent: ACCENT_COLOUR;
  --bg: #f8f7f5;
  --card: #ffffff;
  --text: #2c2c2c;
  --text-muted: #888;
  --border: #e2e2e2;
  --section-bg: #f0f4e8;
  --change-bg: #fafafa;
  --sidebar-w: 260px;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--text); font-size: 14px; line-height: 1.5; }

/* Header */
.tk-header { display: flex; justify-content: space-between; align-items: center; padding: 16px 24px; color: #fff; }
.tk-header-left { display: flex; align-items: center; gap: 16px; }
.tk-header-right { display: flex; align-items: center; gap: 16px; }
.tk-header-title { font-size: 20px; font-weight: 700; margin: 0; }
.tk-header-subtitle { font-size: 13px; opacity: 0.85; }
.tk-header-stats { font-size: 12px; opacity: 0.9; display: flex; gap: 8px; align-items: center; }
.tk-header-sep { opacity: 0.5; }
.tk-logo { height: 40px; max-width: 120px; object-fit: contain; }

/* Layout */
.tk-layout { display: flex; min-height: calc(100vh - 140px); }

/* Sidebar */
.tk-sidebar { width: var(--sidebar-w); background: var(--card); border-right: 1px solid var(--border); overflow-y: auto; flex-shrink: 0; position: sticky; top: 0; height: 100vh; }
.tk-sidebar-search { padding: 12px; border-bottom: 1px solid var(--border); }
.tk-search-input { width: 100%; padding: 8px 12px; border: 1px solid var(--border); border-radius: 6px; font-size: 13px; outline: none; }
.tk-search-input:focus { border-color: var(--brand); }
.tk-sidebar-nav { padding: 8px 0; }
.tk-sidebar-section { padding: 10px 16px 4px; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; }
.tk-sidebar-item { display: block; padding: 6px 16px; font-size: 13px; color: var(--text); text-decoration: none; cursor: pointer; border-left: 3px solid transparent; transition: all 0.15s; }
.tk-sidebar-item:hover { background: #f5f5f5; }
.tk-sidebar-item.active { border-left-color: var(--brand); background: #f0f0ff; font-weight: 600; }
.tk-sidebar-item.hidden { display: none; }

/* Content */
.tk-content { flex: 1; padding: 20px 24px; overflow-x: auto; }

/* Segment tabs */
.tk-segment-tabs { display: flex; gap: 4px; margin-bottom: 16px; flex-wrap: wrap; }
.tk-segment-tab { padding: 8px 18px; border: 1px solid var(--border); background: var(--card); border-radius: 6px 6px 0 0; font-size: 13px; cursor: pointer; transition: all 0.15s; color: var(--text); }
.tk-segment-tab:hover { background: #f0f0f0; }
.tk-segment-tab.tk-tab-active { background: var(--brand); color: #fff; border-color: var(--brand); font-weight: 600; }

/* Controls */
.tk-controls { display: flex; align-items: center; gap: 16px; flex-wrap: wrap; margin-bottom: 16px; padding: 10px 16px; background: var(--card); border-radius: 8px; border: 1px solid var(--border); }
.tk-control-group { display: flex; align-items: center; gap: 8px; }
.tk-control-label { font-size: 12px; color: var(--text-muted); font-weight: 600; }
.tk-toggle { display: flex; align-items: center; gap: 6px; cursor: pointer; font-size: 13px; }
.tk-toggle input[type="checkbox"] { width: 16px; height: 16px; accent-color: var(--brand); }
.tk-toggle-label { user-select: none; }
.tk-btn { padding: 6px 14px; border: 1px solid var(--border); background: var(--card); border-radius: 6px; font-size: 12px; cursor: pointer; transition: all 0.15s; }
.tk-btn:hover { background: #f0f0f0; }
.tk-btn-view { border-radius: 0; }
.tk-btn-view:first-child { border-radius: 6px 0 0 6px; }
.tk-btn-view:last-child { border-radius: 0 6px 6px 0; }
.tk-btn-active { background: var(--brand); color: #fff; border-color: var(--brand); }
.tk-btn-sm { padding: 4px 10px; font-size: 11px; }
.tk-btn-export { background: #f8f8f8; }
.tk-select { padding: 6px 10px; border: 1px solid var(--border); border-radius: 6px; font-size: 12px; background: var(--card); }
.tk-export-group { margin-left: auto; }

/* Table */
.tk-table-wrapper { overflow-x: auto; border-radius: 8px; border: 1px solid var(--border); background: var(--card); }
.tk-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.tk-th { padding: 10px 14px; text-align: center; font-weight: 600; border-bottom: 2px solid var(--border); white-space: nowrap; }
.tk-td { padding: 8px 14px; text-align: center; border-bottom: 1px solid #f0f0f0; }
.tk-label-col { text-align: left; min-width: 220px; max-width: 300px; }
.tk-sticky-col { position: sticky; left: 0; z-index: 2; background: var(--card); }
.tk-segment-header { font-size: 12px; letter-spacing: 0.3px; }
.tk-wave-header { font-size: 12px; background: #f8f8fc; }
.tk-value-cell { font-variant-numeric: tabular-nums; }

/* Section rows */
.tk-section-row { background: none; }
.tk-section-cell { padding: 14px 16px 8px; font-size: 12px; font-weight: 700; color: var(--brand); text-transform: uppercase; letter-spacing: 0.5px; background: var(--section-bg); border-bottom: 2px solid var(--border); }

/* Metric rows */
.tk-metric-row { transition: background 0.1s; }
.tk-metric-row:hover { background: #fafafe; }
.tk-metric-label { font-weight: 600; margin-right: 8px; }
.tk-sparkline-wrap { display: inline-block; vertical-align: middle; margin-left: 4px; }

/* Change rows */
.tk-change-row { display: none; background: var(--change-bg); }
.tk-change-row.visible { display: table-row; }
.tk-change-label { font-size: 11px; color: var(--text-muted); font-style: italic; padding-left: 24px; }
.tk-change-cell { font-size: 12px; }

/* Significance styling */
.change-val { font-size: 12px; white-space: nowrap; }
.sig-up { color: #1a7a3a; font-weight: 600; }
.sig-down { color: #c0392b; font-weight: 600; }
.not-sig { color: #888; }
.sig-flat { color: #888; }
.sig-na { color: #bbb; }

/* Base row */
.tk-base-row { border-top: 2px solid var(--border); }
.tk-base-label { font-size: 11px; color: var(--text-muted); font-weight: 600; }
.tk-base-cell { font-size: 11px; color: var(--text-muted); }

/* Sparklines */
.tk-sparkline { vertical-align: middle; }
body.hide-sparklines .tk-sparkline-wrap { display: none; }

/* Charts */
.tk-chart-panel { padding: 16px 0; }
.tk-chart-container { margin-bottom: 32px; padding: 20px; background: var(--card); border-radius: 8px; border: 1px solid var(--border); }
.tk-chart-title { font-size: 15px; font-weight: 600; margin-bottom: 12px; color: var(--text); }
.tk-chart-actions { margin-top: 12px; text-align: right; }
.tk-line-chart { max-width: 100%; height: auto; }
.tk-chart-point { cursor: pointer; }

/* Help overlay */
.tk-help-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 1000; display: flex; align-items: center; justify-content: center; }
.tk-help-content { background: var(--card); border-radius: 12px; max-width: 600px; width: 90%; max-height: 80vh; overflow-y: auto; padding: 32px; position: relative; }
.tk-help-close { position: absolute; top: 12px; right: 16px; background: none; border: none; font-size: 24px; cursor: pointer; color: var(--text-muted); }
.tk-help-body h3 { margin: 16px 0 6px; font-size: 14px; color: var(--brand); }
.tk-help-body p { color: var(--text-muted); font-size: 13px; }
.tk-help-body ul { margin-left: 20px; color: var(--text-muted); font-size: 13px; }

/* Footer */
.tk-footer { padding: 16px 24px; border-top: 1px solid var(--border); background: var(--card); display: flex; justify-content: space-between; font-size: 12px; color: var(--text-muted); }
.tk-footer-sep { margin: 0 6px; opacity: 0.4; }
.tk-footer-credit { font-style: italic; }

/* Segment column visibility */
.segment-hidden { display: none !important; }

/* Print styles */
@media print {
  .tk-sidebar, .tk-controls, .tk-segment-tabs, .tk-chart-actions, .tk-help-overlay { display: none !important; }
  .tk-layout { display: block; }
  .tk-content { padding: 0; }
  .tk-table-wrapper { border: none; overflow: visible; }
  .tk-sticky-col { position: static; }
  .tk-change-row.visible { display: table-row !important; }
  .tk-header { padding: 8px 16px; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .tk-footer { position: fixed; bottom: 0; }
}
'

  # Replace colour placeholders
  css <- gsub("BRAND_COLOUR", brand_colour, css, fixed = TRUE)
  css <- gsub("ACCENT_COLOUR", accent_colour, css, fixed = TRUE)

  css
}


# ==============================================================================
# JAVASCRIPT
# ==============================================================================

# Directory for standalone JS files
.tracker_js_dir <- (function() {
  if (exists(".tracker_lib_dir", envir = globalenv())) {
    file.path(get(".tracker_lib_dir", envir = globalenv()), "html_report", "js")
  } else {
    .ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
    if (is.null(.ofile) || !nzchar(.ofile %||% "")) {
      file.path(".", "js")
    } else {
      file.path(dirname(.ofile), "js")
    }
  }
})()


#' Read a Tracker JS File
#' @keywords internal
read_tracker_js_file <- function(filename) {
  js_path <- file.path(.tracker_js_dir, filename)
  if (!file.exists(js_path)) {
    cat(sprintf("  [WARN] JavaScript file not found: %s\n", js_path))
    return("")
  }
  paste(readLines(js_path, warn = FALSE), collapse = "\n")
}


#' Build Tracker JavaScript
#'
#' Reads JS files from the js/ directory and inlines them.
#'
#' @keywords internal
build_tracker_javascript <- function(html_data) {

  js_parts <- c()

  # Embed segment data as JSON
  segments_json <- jsonlite::toJSON(html_data$segments, auto_unbox = TRUE)
  js_parts <- c(js_parts, sprintf("var SEGMENTS = %s;", segments_json))
  js_parts <- c(js_parts, sprintf("var BASELINE_WAVE = %s;",
                                    jsonlite::toJSON(html_data$baseline_wave, auto_unbox = TRUE)))
  js_parts <- c(js_parts, sprintf("var N_WAVES = %d;", length(html_data$waves)))

  js_files <- c("core_navigation.js", "chart_controls.js",
                 "table_export.js", "slide_export.js")

  for (js_file in js_files) {
    js_content <- read_tracker_js_file(js_file)
    if (nzchar(js_content)) {
      js_parts <- c(js_parts, sprintf("\n/* === %s === */\n%s", js_file, js_content))
    } else {
      js_parts <- c(js_parts, sprintf("\n/* === %s === NOT FOUND */", js_file))
    }
  }

  paste(js_parts, collapse = "\n")
}
