# ==============================================================================
# TurasTracker HTML Report - Segment Overview Builder
# ==============================================================================
# Components for the Segment Overview tab: sidebar, selector, controls,
# chart containers. Extracted from 03_page_builder.R for maintainability.
# VERSION: 3.0.0
# ==============================================================================


#' Build Overview Sidebar
#'
#' Shows segment list for quick switching (replaces old metric sidebar).
#' Each segment is a clickable item that switches the dropdown and table.
#' Supports grouped segments with expandable sections.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param config List. Tracker configuration
#' @return htmltools tag
#' @keywords internal
build_overview_sidebar <- function(html_data, config) {

  segments <- html_data$segments
  segment_group_info <- derive_segment_groups(segments)
  brand_colour <- get_setting(config, "brand_colour", default = "#323367") %||% "#323367"
  segment_colours <- get_segment_colours(segments, brand_colour)

  items <- c()

  # Helper: escape segment name for JS string inside onclick attribute
  js_escape_seg <- function(name) gsub("'", "\\\\'", htmltools::htmlEscape(name))

  # Standalone segments (Total)
  for (seg_name in segment_group_info$standalone) {
    s_idx <- match(seg_name, segments)
    seg_colour <- segment_colours[s_idx]
    active_class <- if (s_idx == 1) " active" else ""
    items <- c(items, sprintf(
      '<a class="tk-sidebar-item tk-seg-sidebar-item%s" data-segment="%s" href="#" onclick="switchSegment(\'%s\');return false;"><span class="tk-seg-dot" style="background:%s"></span>%s</a>',
      active_class, htmltools::htmlEscape(seg_name),
      js_escape_seg(seg_name), seg_colour,
      htmltools::htmlEscape(seg_name)
    ))
  }

  # Grouped segments — group header is clickable to show all segments in the group
  for (group_name in names(segment_group_info$groups)) {
    group_segs <- segment_group_info$groups[[group_name]]

    # Comma-separated list of segment names for JS
    group_segs_escaped <- paste(vapply(group_segs, js_escape_seg, character(1)), collapse = ",")

    items <- c(items, sprintf(
      '<div class="tk-sidebar-section" data-group-segments="%s" onclick="showBannerGroup(\'%s\',this);return false;" title="Show all %s segments">%s</div>',
      htmltools::htmlEscape(paste(group_segs, collapse = ",")),
      htmltools::htmlEscape(group_name),
      htmltools::htmlEscape(group_name),
      htmltools::htmlEscape(group_name)
    ))

    for (seg_name in group_segs) {
      s_idx <- match(seg_name, segments)
      seg_colour <- segment_colours[s_idx]
      display_label <- sub(paste0("^", group_name, "_"), "", seg_name)
      items <- c(items, sprintf(
        '<a class="tk-sidebar-item tk-seg-sidebar-item" data-segment="%s" data-group="%s" href="#" onclick="switchSegment(\'%s\');return false;"><span class="tk-seg-dot" style="background:%s"></span>%s</a>',
        htmltools::htmlEscape(seg_name),
        htmltools::htmlEscape(group_name),
        js_escape_seg(seg_name), seg_colour,
        htmltools::htmlEscape(display_label)
      ))
    }
  }

  htmltools::tags$aside(class = "tk-sidebar",
    htmltools::tags$div(class = "tk-sidebar-inner",
      htmltools::tags$div(class = "tk-sidebar-nav-card",
        htmltools::tags$div(class = "tk-sidebar-header",
          sprintf("Segments (%d)", length(segments))
        ),
        htmltools::tags$div(class = "tk-sidebar-nav-scroll",
          htmltools::tags$nav(class = "tk-sidebar-nav",
            htmltools::HTML(paste(items, collapse = "\n"))
          )
        )
      ),
      # Legend box (matching crosstabs pattern)
      htmltools::tags$div(class = "legend-box",
        htmltools::tags$div(class = "legend-title", "Legend"),
        htmltools::tags$div(class = "legend-item",
          htmltools::tags$span(class = "tk-sig tk-sig-up", "\u25B2"),
          htmltools::tags$span("Significantly higher than previous wave")
        ),
        htmltools::tags$div(class = "legend-item",
          htmltools::tags$span(class = "tk-sig tk-sig-down", "\u25BC"),
          htmltools::tags$span("Significantly lower than previous wave")
        ),
        htmltools::tags$div(class = "legend-item",
          htmltools::tags$span(style = "color:#94a3b8;font-size:12px", "3.80"),
          htmltools::tags$span("Low base \u2014 values in grey (n<30)")
        ),
        htmltools::tags$div(class = "legend-item",
          htmltools::tags$span(style = "color:#e8614d;font-weight:700;font-size:11px", "\u26A0 28"),
          htmltools::tags$span("Low base warning in base row (n<30)")
        )
      )
    )
  )
}


#' Build Segment Selector Dropdown
#'
#' Renders a dropdown to switch between segments in the Segment Overview
#' table. Shows one segment at a time.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param config List. Tracker configuration
#' @param brand_colour Character. Brand colour hex code
#' @return htmltools tag
#' @keywords internal
build_segment_selector <- function(html_data, config, brand_colour) {
  segments <- html_data$segments

  if (length(segments) <= 1) return(htmltools::tags$div())

  options <- c()
  for (seg_name in segments) {
    options <- c(options, sprintf(
      '<option value="%s">%s</option>',
      htmltools::htmlEscape(seg_name),
      htmltools::htmlEscape(seg_name)
    ))
  }

  htmltools::tags$div(class = "tk-segment-selector",
    htmltools::tags$label(class = "tk-control-label", "Segment:"),
    htmltools::tags$select(
      class = "tk-select tk-segment-select",
      id = "segment-selector",
      onchange = "switchSegment(this.value)",
      htmltools::HTML(paste(options, collapse = "\n"))
    )
  )
}


#' Build Controls for Segment Overview Tab
#'
#' Renders the control bar with search filter, metric type filter chips,
#' change row toggles, view switcher, group/sort selectors, and export buttons.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param config List. Tracker configuration
#' @return htmltools tag
#' @keywords internal
build_controls <- function(html_data, config) {

  # Build metric type filter chips for Segment Overview
  metric_types_present <- unique(vapply(html_data$metric_rows, function(mr) {
    classify_metric_type(mr$metric_name)
  }, character(1)))

  type_filter_html <- ""
  if (length(metric_types_present) > 1) {
    type_label_map <- list(mean = "Mean / Rating", pct = "% / Top Box", nps = "NPS", other = "Other")
    type_chips <- c('<div class="tk-control-group tk-overview-type-filter">')
    type_chips <- c(type_chips,
      '<button class="mv-type-chip tk-overview-type-chip active" data-type-filter="all" onclick="filterOverviewByType(\'all\')">All</button>'
    )
    for (mt in c("mean", "pct", "nps", "other")) {
      if (mt %in% metric_types_present) {
        type_chips <- c(type_chips, sprintf(
          '<button class="mv-type-chip tk-overview-type-chip" data-type-filter="%s" onclick="filterOverviewByType(\'%s\')">%s</button>',
          mt, mt, type_label_map[[mt]]
        ))
      }
    }
    type_chips <- c(type_chips, '</div>')
    type_filter_html <- paste(type_chips, collapse = "\n")
  }

  htmltools::tags$div(class = "tk-controls",
    # Row search filter
    htmltools::tags$div(class = "tk-control-group",
      htmltools::tags$input(
        type = "text",
        class = "tk-search-input tk-overview-search",
        placeholder = "Filter rows...",
        oninput = "filterOverviewRows(this.value)"
      )
    ),

    # Metric type filter
    htmltools::HTML(type_filter_html),

    htmltools::tags$div(class = "tk-control-group",
      htmltools::tags$label(class = "tk-toggle",
        htmltools::tags$input(type = "checkbox", id = "toggle-vs-prev",
                               onchange = "toggleChangeRows('vs-prev')"),
        htmltools::tags$span(class = "tk-toggle-label", "vs Previous")
      ),
      htmltools::tags$label(class = "tk-toggle",
        htmltools::tags$input(type = "checkbox", id = "toggle-vs-base",
                               onchange = "toggleChangeRows('vs-base')"),
        htmltools::tags$span(class = "tk-toggle-label", "vs Baseline")
      ),
      htmltools::tags$label(class = "tk-toggle",
        htmltools::tags$input(type = "checkbox", id = "toggle-sparklines",
                               checked = "checked",
                               onchange = "toggleSparklines()"),
        htmltools::tags$span(class = "tk-toggle-label", "Sparklines")
      )
    ),

    htmltools::tags$div(class = "tk-control-group",
      htmltools::tags$button(class = "tk-btn tk-btn-view tk-btn-active",
                              id = "btn-table-view",
                              onclick = "switchView('table')", "Table"),
      htmltools::tags$button(class = "tk-btn tk-btn-view",
                              id = "btn-chart-view",
                              onclick = "switchView('chart')", "Charts")
    ),

    htmltools::tags$div(class = "tk-control-group",
      htmltools::tags$span(class = "tk-control-label", "Group by:"),
      htmltools::tags$select(class = "tk-select", id = "group-by-select",
                              onchange = "switchGroupBy(this.value)",
        htmltools::tags$option(value = "section", selected = "selected", "Section"),
        htmltools::tags$option(value = "metric_type", "Metric Type"),
        htmltools::tags$option(value = "question", "Question")
      )
    ),

    htmltools::tags$div(class = "tk-control-group",
      htmltools::tags$span(class = "tk-control-label", "Sort by:"),
      htmltools::tags$select(class = "tk-select", id = "sort-by-select",
                              onchange = "sortOverviewBy(this.value)",
        htmltools::tags$option(value = "original", selected = "selected", "Original Order"),
        htmltools::tags$option(value = "metric_name", "Metric Name (A\u2192Z)"),
        htmltools::tags$option(value = "metric_name_desc", "Metric Name (Z\u2192A)")
      )
    ),

    # Hidden rows indicator (shown when rows are greyed out)
    htmltools::tags$div(class = "tk-control-group", id = "hidden-rows-indicator",
      style = "display:none",
      htmltools::tags$span(class = "tk-control-label", id = "hidden-rows-count", "0 greyed out"),
      htmltools::tags$button(class = "tk-btn tk-btn-sm",
                              onclick = "showAllHiddenRows()", "Show All")
    ),

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


#' Build Chart Containers for Segment Overview Tab
#'
#' Renders the chart panel with header, action buttons, and combined
#' chart container. Content is populated dynamically by JavaScript.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param charts List. Pre-built chart SVGs
#' @param config List. Tracker configuration
#' @return htmltools HTML
#' @keywords internal
build_chart_containers <- function(html_data, charts, config) {

  # Chart panel header with selection count and action buttons
  containers <- c()
  containers <- c(containers, '<div class="tk-chart-header">')
  containers <- c(containers, '<span class="tk-chart-count" id="tk-chart-count">Charts (0 selected)</span>')
  containers <- c(containers, '<div class="tk-chart-header-actions">')
  containers <- c(containers, '<button class="export-btn" onclick="exportChartPNG(\'combined\')">&#x1F4F8; Export PNG</button>')
  containers <- c(containers, '<button class="export-btn" onclick="pinSelectedCharts()">&#x1F4CC; Pin Charts</button>')
  containers <- c(containers, '</div>')
  containers <- c(containers, '</div>')

  # Single combined chart container (JS will render a multi-line SVG here)
  containers <- c(containers, '<div id="tk-combined-chart" class="tk-chart-container" style="padding:20px;background:var(--card);border-radius:8px;border:1px solid var(--border);">')
  containers <- c(containers, '<p style="color:#888;text-align:center;padding:40px;">Select metrics from the table to add them to the chart.</p>')
  containers <- c(containers, '</div>')

  htmltools::HTML(paste(containers, collapse = "\n"))
}
