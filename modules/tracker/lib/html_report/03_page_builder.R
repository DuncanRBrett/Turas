# ==============================================================================
# TurasTracker HTML Report - Page Builder (Orchestrator)
# ==============================================================================
# Assembles the complete HTML page from sub-modules.
# Split files:
#   03a_page_styling.R   - CSS/JS loading, minification, brand substitution
#   03b_page_components.R - Header, footer, help overlay, about, pinned, qual
#   03c_summary_builder.R - Summary/Dashboard tab (KPI heroes, pulse, heatmap)
#   03f_heatmap_builder.R - Explorer tab (heatmap table with drill-down)
# VERSION: 3.1.0
# ==============================================================================

# Source the callout registry (TURAS_ROOT-aware)
local({
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) turas_root <- getwd()
  callout_dir <- file.path(turas_root, "modules", "shared", "lib", "callouts")
  if (!dir.exists(callout_dir)) callout_dir <- file.path("modules", "shared", "lib", "callouts")
  if (!exists("turas_callout", mode = "function") && dir.exists(callout_dir)) {
    source(file.path(callout_dir, "callout_registry.R"), local = FALSE)
  }
})


#' Build Tracker HTML Page
#'
#' Assembles the complete HTML page from tables, charts, and controls.
#' Uses a 4-tab layout: Summary, Explorer, Added Slides, Pinned Views.
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

  # Build About panel (analyst details, verbatim ref, closing notes)
  about_panel <- build_tracker_about_panel(config)
  has_about <- !is.null(about_panel)

  page <- htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "UTF-8"),
      htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1.0"),
      htmltools::tags$title(paste0(project_name, " - Tracking Report")),
      htmltools::tags$meta(name = "turas-report-type", content = "tracker"),
      htmltools::tags$meta(name = "turas-generated", content = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")),
      # Hub-extraction metadata
      htmltools::tags$meta(name = "turas-metrics", content = as.character(html_data$n_metrics)),
      htmltools::tags$meta(name = "turas-waves", content = as.character(length(html_data$waves))),
      htmltools::tags$meta(name = "turas-segments", content = as.character(length(html_data$segments))),
      htmltools::tags$meta(name = "turas-baseline-label",
                           content = html_data$wave_lookup[html_data$baseline_wave] %||% ""),
      htmltools::tags$meta(name = "turas-latest-label",
                           content = html_data$wave_lookup[html_data$waves[length(html_data$waves)]] %||% ""),
      htmltools::tags$style(htmltools::HTML(build_tracker_css(brand_colour, accent_colour)))
    ),

    # Header
    build_tracker_header(html_data, config, brand_colour),

    # Tab navigation
    build_report_tab_nav(brand_colour, has_about = has_about),

    # ---- TAB PANELS ----
    htmltools::tags$div(class = "tk-tab-panels", `data-report-module` = "tracker",

      # Tab 1: Summary / Dashboard
      htmltools::tags$div(id = "tab-summary", class = "tab-panel active",
        build_summary_tab(html_data, config)
      ),

      # Tab 2: Heatmap Explorer
      build_explorer_tab(html_data, config),

      # Tab 3: Visualise (populated dynamically from Explorer)
      htmltools::tags$div(id = "tab-visualise", class = "tab-panel",
        htmltools::tags$div(id = "visualise-placeholder", class = "visualise-empty",
          htmltools::tags$h3("Select metrics or segments in the Explorer, then click Visualise."),
          htmltools::tags$p(class = "dash-section-sub",
            "Use the Explorer tab to select rows, then click the Visualise button to see detailed charts and comparisons here.")
        ),
        htmltools::tags$div(id = "visualise-content", style = "display:none")
      ),

      # Tab 5: Added Slides (qualitative panel)
      htmltools::tags$div(id = "tab-slides", class = "tab-panel",
        build_qualitative_panel()
      ),

      # Tab 5: About (analyst details, verbatim, notes)
      about_panel,

      # Tab 6: Pinned Views
      htmltools::tags$div(id = "tab-pinned", class = "tab-panel",
        build_pinned_tab()
      )
    ),

    # Footer
    build_tracker_footer(html_data, config),

    # Help overlay
    build_help_overlay(),

    # Pinned views data store
    htmltools::tags$script(type = "application/json", id = "pinned-views-data", "[]"),

    # Annotations data store (pre-configured from config + interactive)
    htmltools::tags$script(type = "application/json", id = "tk-annotations-data",
      build_annotations_json(config)
    ),

    # JavaScript
    htmltools::tags$script(htmltools::HTML(build_tracker_javascript(html_data, config)))
  )

  htmltools::browsable(page)
}


# ==============================================================================
# ANNOTATIONS CONFIG
# ==============================================================================

#' Build Annotations JSON from Config
#'
#' Reads pre-configured annotations from the tracker config and serialises
#' them as JSON for the hidden annotations store. Config field:
#' \code{annotations} — a data frame or list of annotations with columns:
#' metric_id, wave_id, segment (optional), text, colour (optional).
#'
#' @param config List. Tracker configuration
#' @return Character. JSON string (empty array if no annotations configured)
#' @keywords internal
build_annotations_json <- function(config) {
  ann_data <- get_setting(config, "annotations", default = NULL)
  if (is.null(ann_data)) return("[]")

  # Support data frame or list of lists
  if (is.data.frame(ann_data)) {
    ann_list <- lapply(seq_len(nrow(ann_data)), function(i) {
      row <- ann_data[i, , drop = FALSE]
      list(
        metricId = as.character(row$metric_id %||% row$metricId %||% ""),
        waveId = as.character(row$wave_id %||% row$waveId %||% ""),
        segment = as.character(row$segment %||% "Total"),
        text = as.character(row$text %||% ""),
        colour = as.character(row$colour %||% row$color %||% "#64748b")
      )
    })
  } else if (is.list(ann_data)) {
    ann_list <- lapply(ann_data, function(a) {
      list(
        metricId = as.character(a$metric_id %||% a$metricId %||% ""),
        waveId = as.character(a$wave_id %||% a$waveId %||% ""),
        segment = as.character(a$segment %||% "Total"),
        text = as.character(a$text %||% ""),
        colour = as.character(a$colour %||% a$color %||% "#64748b")
      )
    })
  } else {
    return("[]")
  }

  # Filter out empty annotations
  ann_list <- Filter(function(a) nzchar(a$text) && nzchar(a$metricId), ann_list)
  if (length(ann_list) == 0) return("[]")

  jsonlite::toJSON(ann_list, auto_unbox = TRUE)
}


# ==============================================================================
# TAB NAVIGATION
# ==============================================================================

#' Build Report Tab Navigation
#'
#' Renders the tab bar with Summary, Explorer, Added Slides, About (optional),
#' and Pinned Views tabs. Includes Save/Print action buttons pushed to the right.
#'
#' @param brand_colour Character. Brand colour hex code
#' @param has_about Logical. Whether the About tab should be shown
#' @return htmltools tag
#' @keywords internal
build_report_tab_nav <- function(brand_colour, has_about = FALSE) {

  about_tab <- if (has_about) {
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('about')",
      `data-tab` = "about",
      "About"
    )
  }

  htmltools::tags$div(class = "report-tabs",
    htmltools::tags$button(
      class = "report-tab active",
      onclick = "switchReportTab('summary')",
      `data-tab` = "summary",
      "Summary"
    ),
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('explorer')",
      `data-tab` = "explorer",
      "Explorer"
    ),
    htmltools::tags$button(
      class = "report-tab tab-disabled",
      onclick = "switchReportTab('visualise')",
      `data-tab` = "visualise",
      id = "tab-btn-visualise",
      title = "Select metrics in Explorer, then click Visualise",
      "Visualise"
    ),
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('slides')",
      `data-tab` = "slides",
      "Added Slides"
    ),
    about_tab,
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('pinned')",
      `data-tab` = "pinned",
      htmltools::tagList(
        "Pinned Views",
        htmltools::tags$span(
          class = "pin-count-badge",
          id = "pin-count-badge",
          style = "display:none",
          "0"
        )
      )
    ),
    # Help button — in tab strip so it's accessible in combined reports
    htmltools::tags$button(
      class = "tk-help-btn",
      onclick = "toggleHelpOverlay()",
      title = "Show help guide",
      style = paste0(
        "width:26px;height:26px;border-radius:50%;border:1.5px solid #cbd5e1;",
        "background:transparent;color:#64748b;font-size:13px;font-weight:700;",
        "cursor:pointer;display:flex;align-items:center;justify-content:center;",
        "margin-left:auto;flex-shrink:0;"
      ),
      "?"
    ),
    # Spacer pushes action buttons to the right
    htmltools::tags$div(style = "flex:1"),
    # Save Report + Print buttons (body-level, not in header)
    htmltools::tags$div(class = "tk-tab-actions",
      htmltools::tags$button(
        class = "export-btn",
        onclick = "saveReportHTML()",
        "\U0001F4BE Save Report"
      ),
      htmltools::tags$button(
        class = "export-btn",
        onclick = "printReport()",
        "\U0001F5A8 Print"
      )
    )
  )
}
