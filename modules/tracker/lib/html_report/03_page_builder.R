# ==============================================================================
# TurasTracker HTML Report - Page Builder
# ==============================================================================
# Assembles the complete HTML page with CSS, JS, 4-tab layout.
# Tabs: Summary | Metrics by Segment | Segment Overview | Pinned Views
# VERSION: 2.0.0
# ==============================================================================


#' Build Tracker HTML Page
#'
#' Assembles the complete HTML page from tables, charts, and controls.
#' Uses a 4-tab layout: Summary, Metrics by Segment, Segment Overview, Pinned Views.
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

    # Tab navigation
    build_report_tab_nav(brand_colour),

    # ---- TAB PANELS ----
    htmltools::tags$div(class = "tk-tab-panels", `data-report-module` = "tracker",

      # Tab 1: Summary
      htmltools::tags$div(id = "tab-summary", class = "tab-panel active",
        build_summary_tab(html_data, config)
      ),

      # Tab 2: Metrics by Segment
      htmltools::tags$div(id = "tab-metrics", class = "tab-panel",
        build_metrics_tab(html_data, charts, config)
      ),

      # Tab 3: Segment Overview
      htmltools::tags$div(id = "tab-overview", class = "tab-panel",
        htmltools::tags$div(class = "tk-layout",
          build_overview_sidebar(html_data, config),
          htmltools::tags$main(class = "tk-content",
            build_controls(html_data, config),
            htmltools::tags$div(class = "tk-main-area",
              htmltools::tags$div(class = "tk-table-panel", table_html),
              htmltools::tags$div(class = "tk-chart-panel",
                id = "tk-chart-panel",
                style = "display:none",
                build_chart_containers(html_data, charts, config)
              )
            ),
            # Overview actions: Pin + Export + Insight
            htmltools::tags$div(class = "overview-actions-bar",
              htmltools::tags$button(class = "tk-btn",
                onclick = "pinOverviewView()",
                htmltools::HTML("&#x1F4CC; Pin Current View")),
              htmltools::tags$button(class = "tk-btn",
                onclick = "exportOverviewSlide()",
                htmltools::HTML("&#x1F4F8; Export Slide"))
            ),
            htmltools::tags$div(class = "insight-area",
              htmltools::tags$button(class = "insight-toggle",
                onclick = "toggleOverviewInsight()", "+ Add Insight"),
              htmltools::tags$div(class = "insight-container", style = "display:none",
                htmltools::tags$div(class = "insight-editor",
                  contenteditable = "true",
                  `data-placeholder` = "Type overview insight here...",
                  id = "overview-insight-editor",
                  oninput = ""),
                htmltools::tags$button(class = "insight-dismiss",
                  title = "Delete insight",
                  onclick = "dismissOverviewInsight()",
                  htmltools::HTML("&times;"))
              )
            )
          )
        )
      ),

      # Tab 4: Pinned Views
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

    # JavaScript
    htmltools::tags$script(htmltools::HTML(build_tracker_javascript(html_data)))
  )

  htmltools::browsable(page)
}


# ==============================================================================
# TAB NAVIGATION
# ==============================================================================

#' Build Report Tab Navigation
#' @keywords internal
build_report_tab_nav <- function(brand_colour) {

  htmltools::tags$div(class = "report-tabs",
    htmltools::tags$button(
      class = "report-tab active",
      onclick = "switchReportTab('summary')",
      `data-tab` = "summary",
      "Summary"
    ),
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('metrics')",
      `data-tab` = "metrics",
      "Metrics by Segment"
    ),
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('overview')",
      `data-tab` = "overview",
      "Segment Overview"
    ),
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


# ==============================================================================
# SUMMARY TAB
# ==============================================================================

#' Build Summary Tab Content
#' @keywords internal
build_summary_tab <- function(html_data, config) {

  project_name <- html_data$metadata$project_name %||% "Tracking Report"
  n_metrics <- html_data$n_metrics
  n_waves <- length(html_data$waves)
  n_segments <- length(html_data$segments)
  baseline_label <- html_data$wave_lookup[html_data$baseline_wave]

  htmltools::tags$div(class = "summary-tab-content",
    htmltools::tags$div(class = "summary-stats-row",
      htmltools::tags$div(class = "summary-stat-card",
        htmltools::tags$div(class = "stat-number", n_metrics),
        htmltools::tags$div(class = "stat-label", "Metrics")
      ),
      htmltools::tags$div(class = "summary-stat-card",
        htmltools::tags$div(class = "stat-number", n_waves),
        htmltools::tags$div(class = "stat-label", "Waves")
      ),
      htmltools::tags$div(class = "summary-stat-card",
        htmltools::tags$div(class = "stat-number", n_segments),
        htmltools::tags$div(class = "stat-label", if (n_segments > 1) "Segments" else "Segment")
      ),
      htmltools::tags$div(class = "summary-stat-card",
        htmltools::tags$div(class = "stat-number", paste0(baseline_label)),
        htmltools::tags$div(class = "stat-label", "Baseline")
      )
    ),

    # Background & Method insight box (above metrics table)
    htmltools::tags$div(class = "summary-insight-box", id = "summary-section-background",
      htmltools::tags$div(class = "summary-section-controls",
        htmltools::tags$button(class = "tk-btn tk-btn-sm",
          onclick = "pinSummarySection('background')",
          htmltools::HTML("&#x1F4CC; Pin")),
        htmltools::tags$button(class = "tk-btn tk-btn-sm",
          onclick = "exportSummarySlide('background')",
          htmltools::HTML("&#x1F4F8; Export Slide"))
      ),
      htmltools::tags$h3(class = "summary-insight-title", "Background & Method"),
      htmltools::tags$div(
        class = "insight-editor summary-editor",
        contenteditable = "true",
        `data-placeholder` = "Add background and methodology notes here...",
        id = "summary-background-editor"
      )
    ),

    # Summary insight box (above metrics table)
    htmltools::tags$div(class = "summary-insight-box", id = "summary-section-findings",
      htmltools::tags$div(class = "summary-section-controls",
        htmltools::tags$button(class = "tk-btn tk-btn-sm",
          onclick = "pinSummarySection('findings')",
          htmltools::HTML("&#x1F4CC; Pin")),
        htmltools::tags$button(class = "tk-btn tk-btn-sm",
          onclick = "exportSummarySlide('findings')",
          htmltools::HTML("&#x1F4F8; Export Slide"))
      ),
      htmltools::tags$h3(class = "summary-insight-title", "Summary"),
      htmltools::tags$div(
        class = "insight-editor summary-editor",
        contenteditable = "true",
        `data-placeholder` = "Add key findings and summary here...",
        id = "summary-findings-editor"
      )
    ),

    # Metric type filter chips (only if more than one type present)
    htmltools::HTML(build_summary_type_filter(html_data)),

    # Action buttons bar
    htmltools::tags$div(class = "summary-actions",
      htmltools::tags$button(class = "export-btn",
        onclick = "exportSummaryExcel()",
        htmltools::HTML("&#x1F4CA; Export Excel")),
      htmltools::tags$button(class = "export-btn",
        onclick = "pinSummaryTable()",
        htmltools::HTML("&#x1F4CC; Pin Table")),
      htmltools::tags$button(class = "export-btn",
        onclick = "exportSummaryTableSlide()",
        htmltools::HTML("&#x1F4F8; Export Slide"))
    ),

    # Metrics Overview table (Total segment by wave) — at bottom
    build_summary_metrics_table(html_data)
  )
}


#' Build Summary Tab Type Filter Chips
#' @keywords internal
build_summary_type_filter <- function(html_data) {
  metric_types_present <- unique(vapply(html_data$metric_rows, function(mr) {
    classify_metric_type(mr$metric_name)
  }, character(1)))

  if (length(metric_types_present) <= 1) return("")

  type_label_map <- list(mean = "Mean / Rating", pct = "% / Top Box", nps = "NPS", other = "Other")
  chips <- c('<div class="summary-type-filter">')
  chips <- c(chips,
    '<button class="summary-type-chip active" data-type-filter="all" onclick="filterSummaryByType(\'all\')">All</button>'
  )
  for (mt in c("mean", "pct", "nps", "other")) {
    if (mt %in% metric_types_present) {
      chips <- c(chips, sprintf(
        '<button class="summary-type-chip" data-type-filter="%s" onclick="filterSummaryByType(\'%s\')">%s</button>',
        mt, mt, type_label_map[[mt]]
      ))
    }
  }
  chips <- c(chips, '</div>')
  paste(chips, collapse = "\n")
}


#' Build Summary Metrics Table
#'
#' Compact read-only table showing Total segment values by wave.
#' Displayed on the Summary tab for a quick overview of all metrics.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @return htmltools::HTML object
#' @keywords internal
build_summary_metrics_table <- function(html_data, min_base = 30L) {

  seg_name <- html_data$segments[1]  # Total (or first segment)
  waves <- html_data$waves
  wave_labels <- html_data$wave_labels

  parts <- c()
  parts <- c(parts, '<div class="summary-metrics-table-wrap">')
  parts <- c(parts, '<h3 class="summary-insight-title">Metrics Overview</h3>')
  parts <- c(parts, '<table class="tk-table summary-metrics-table" id="summary-metrics-table">')

  # Header
  parts <- c(parts, '<thead><tr>')
  parts <- c(parts, '<th class="tk-th tk-label-col">Metric</th>')
  for (wl in wave_labels) {
    parts <- c(parts, sprintf('<th class="tk-th">%s</th>', htmltools::htmlEscape(wl)))
  }
  parts <- c(parts, '</tr></thead>')

  # Body
  parts <- c(parts, '<tbody>')
  total_cols <- 1 + length(waves)

  # Base (n=) row at TOP — use max n across ALL metrics per wave
  # so base always reflects the total sample for that segment
  if (length(html_data$metric_rows) > 0) {
    parts <- c(parts, '<tr class="tk-base-row">')
    parts <- c(parts, '<td class="tk-td tk-label-col tk-base-label">Base (n=)</td>')
    for (wid in waves) {
      max_n <- NA_integer_
      for (mr in html_data$metric_rows) {
        cell <- mr$segment_cells[[seg_name]][[wid]]
        if (!is.null(cell) && !is.na(cell$n)) {
          if (is.na(max_n) || cell$n > max_n) max_n <- cell$n
        }
      }
      if (!is.na(max_n) && max_n < min_base) {
        n_display <- sprintf('<span class="tk-low-base">%s &#x26A0;</span>', max_n)
      } else {
        n_display <- if (!is.na(max_n)) as.character(max_n) else ""
      }
      parts <- c(parts, sprintf('<td class="tk-td tk-base-cell">%s</td>', n_display))
    }
    parts <- c(parts, '</tr>')
  }

  # Reorder metrics: grouped sections first, "(Ungrouped)" at bottom
  grouped_metrics <- list()
  ungrouped_metrics <- list()
  for (mr in html_data$metric_rows) {
    section <- if (is.na(mr$section) || mr$section == "") "(Ungrouped)" else mr$section
    if (section == "(Ungrouped)") {
      ungrouped_metrics <- c(ungrouped_metrics, list(mr))
    } else {
      grouped_metrics <- c(grouped_metrics, list(mr))
    }
  }
  ordered_metrics <- c(grouped_metrics, ungrouped_metrics)

  current_section <- ""
  for (mr in ordered_metrics) {
    section <- if (is.na(mr$section) || mr$section == "") "(Ungrouped)" else mr$section
    if (section != current_section) {
      current_section <- section
      parts <- c(parts, sprintf(
        '<tr class="tk-section-row"><td colspan="%d" class="tk-section-cell">%s</td></tr>',
        total_cols, htmltools::htmlEscape(section)
      ))
    }

    m_type <- classify_metric_type(mr$metric_name)
    cells <- mr$segment_cells[[seg_name]]
    parts <- c(parts, sprintf(
      '<tr class="tk-metric-row" data-metric-type="%s">', m_type
    ))
    parts <- c(parts, sprintf(
      '<td class="tk-td tk-label-col"><span class="tk-metric-label">%s</span></td>',
      htmltools::htmlEscape(mr$metric_label)
    ))

    for (wid in waves) {
      cell <- cells[[wid]]
      val_display <- if (!is.null(cell)) cell$display_value else "&mdash;"
      # Dim cells with low base
      low_base_class <- ""
      if (!is.null(cell) && !is.na(cell$n) && cell$n < min_base) {
        low_base_class <- " tk-low-base-dim"
      }
      parts <- c(parts, sprintf('<td class="tk-td tk-value-cell%s">%s</td>', low_base_class, val_display))
    }
    parts <- c(parts, '</tr>')
  }

  parts <- c(parts, '</tbody></table></div>')
  htmltools::HTML(paste(parts, collapse = "\n"))
}


# ==============================================================================
# METRICS BY SEGMENT TAB
# ==============================================================================

#' Build Metrics by Segment Tab
#' @keywords internal
build_metrics_tab <- function(html_data, charts, config) {

  brand_colour <- get_setting(config, "brand_colour", default = "#323367") %||% "#323367"
  segments <- html_data$segments
  segment_colours <- get_segment_colours(segments, brand_colour)

  # Build metric navigation sidebar
  metric_nav <- build_metric_nav_list(html_data)

  # Build per-metric panels
  metric_panels <- build_metric_panels(html_data, charts, config, segments, segment_colours)

  # Global significance toggle
  sig_toggle <- htmltools::tags$div(class = "mv-global-controls",
    htmltools::tags$label(class = "tk-toggle",
      htmltools::tags$input(type = "checkbox", id = "toggle-sig-global",
                             onchange = "toggleSignificance()"),
      htmltools::tags$span(class = "tk-toggle-label", "Hide Significance Indicators")
    )
  )

  # Build metric type filter chips (only if more than one type exists)
  metric_types_present <- unique(vapply(html_data$metric_rows, function(mr) {
    classify_metric_type(mr$metric_name)
  }, character(1)))

  type_filter_html <- ""
  if (length(metric_types_present) > 1) {
    type_label_map <- list(mean = "Mean / Rating", pct = "% / Top Box", nps = "NPS", other = "Other")
    type_chips <- c('<div class="mv-type-filter">')
    type_chips <- c(type_chips,
      '<button class="mv-type-chip active" data-type-filter="all" onclick="filterMetricType(\'all\')">All</button>'
    )
    for (mt in c("mean", "pct", "nps", "other")) {
      if (mt %in% metric_types_present) {
        type_chips <- c(type_chips, sprintf(
          '<button class="mv-type-chip" data-type-filter="%s" onclick="filterMetricType(\'%s\')">%s</button>',
          mt, mt, type_label_map[[mt]]
        ))
      }
    }
    type_chips <- c(type_chips, '</div>')
    type_filter_html <- paste(type_chips, collapse = "\n")
  }

  n_metrics <- length(html_data$metric_rows)

  htmltools::tags$div(class = "metrics-tab-layout",
    htmltools::tags$aside(class = "mv-sidebar",
      htmltools::tags$div(class = "mv-sidebar-inner",
        htmltools::tags$div(class = "mv-sidebar-search",
          htmltools::tags$input(
            type = "text",
            class = "tk-search-input",
            placeholder = "Search metrics...",
            oninput = "filterMetricNav(this.value)"
          )
        ),
        htmltools::HTML(type_filter_html),
        sig_toggle,
        htmltools::tags$div(class = "mv-sidebar-nav-wrap",
          htmltools::tags$div(class = "mv-sidebar-nav-header",
            sprintf("Metrics (%d)", n_metrics)
          ),
          htmltools::tags$div(class = "mv-sidebar-nav-scroll",
            htmltools::tags$nav(class = "mv-sidebar-nav",
              htmltools::HTML(metric_nav)
            )
          )
        )
      )
    ),
    htmltools::tags$main(class = "mv-content",
      htmltools::HTML(metric_panels)
    )
  )
}


#' Derive Segment Groups from Segment Names
#'
#' Splits segments into hierarchical groups based on the prefix before
#' the first underscore. "Total" is placed in its own standalone group.
#'
#' @param segments Character vector of segment names
#' @return List with: standalone (character vector), groups (named list of character vectors)
#' @keywords internal
derive_segment_groups <- function(segments) {
  standalone <- character(0)
  groups <- list()

  for (seg in segments) {
    if (seg == "Total") {
      standalone <- c(standalone, seg)
      next
    }
    # Split on first underscore only
    underscore_pos <- regexpr("_", seg, fixed = TRUE)
    if (underscore_pos > 0) {
      group_name <- substr(seg, 1, underscore_pos - 1)
    } else {
      group_name <- seg
    }
    if (is.null(groups[[group_name]])) groups[[group_name]] <- character(0)
    groups[[group_name]] <- c(groups[[group_name]], seg)
  }

  list(standalone = standalone, groups = groups)
}


#' Classify a Metric Name into a Display Type
#'
#' Maps internal metric_name values to human-readable filter categories.
#'
#' @param metric_name Character. The metric name (e.g., "mean", "top2_box", "nps_score")
#' @return Character. Display type key: "mean", "pct", "nps", or "other"
#' @keywords internal
classify_metric_type <- function(metric_name) {
  if (metric_name == "mean") return("mean")
  if (metric_name %in% c("nps_score", "nps", "promoters_pct", "passives_pct", "detractors_pct")) return("nps")
  if (grepl("(pct|box|range|proportion|category|any)", metric_name)) return("pct")
  "other"
}


#' Build Metric Navigation List
#'
#' Groups metrics by section. Ungrouped metrics are placed at the bottom
#' of the list rather than at the top.
#'
#' @keywords internal
build_metric_nav_list <- function(html_data) {

  # Collect items into grouped vs ungrouped buckets
  grouped_items <- c()
  ungrouped_items <- c()
  current_section <- ""
  first_metric_idx <- NULL

  for (i in seq_along(html_data$metric_rows)) {
    mr <- html_data$metric_rows[[i]]
    section <- if (is.na(mr$section) || mr$section == "") "(Ungrouped)" else mr$section
    is_ungrouped <- (section == "(Ungrouped)")

    if (is.null(first_metric_idx)) first_metric_idx <- i

    item_html <- c()

    if (section != current_section) {
      current_section <- section
      item_html <- c(item_html, sprintf(
        '<div class="mv-nav-section">%s</div>',
        htmltools::htmlEscape(section)
      ))
    }

    active_class <- if (i == first_metric_idx) " active" else ""
    m_type <- classify_metric_type(mr$metric_name)
    item_html <- c(item_html, sprintf(
      '<a class="tk-metric-nav-item%s" data-metric-id="%s" data-metric-type="%s" href="#" onclick="selectTrackerMetric(\'%s\');return false;">%s</a>',
      active_class, mr$metric_id, m_type, mr$metric_id,
      htmltools::htmlEscape(mr$metric_label)
    ))

    if (is_ungrouped) {
      ungrouped_items <- c(ungrouped_items, item_html)
    } else {
      grouped_items <- c(grouped_items, item_html)
    }
  }

  # Output grouped sections first, then ungrouped at bottom
  paste(c(grouped_items, ungrouped_items), collapse = "\n")
}


#' Build Per-Metric Panels
#' @keywords internal
build_metric_panels <- function(html_data, charts, config, segments, segment_colours) {

  brand_colour <- get_setting(config, "brand_colour", default = "#323367") %||% "#323367"
  min_base <- as.integer(get_setting(config, "significance_min_base", default = 30) %||% 30)
  segment_group_info <- derive_segment_groups(segments)
  panels <- c()

  for (i in seq_along(html_data$metric_rows)) {
    mr <- html_data$metric_rows[[i]]
    chart_html <- if (i <= length(charts) && !is.null(charts[[i]])) as.character(charts[[i]]) else ""
    sparkline_data <- html_data$sparkline_data[[i]]
    active_class <- if (i == 1) " active" else ""

    panel_parts <- c()

    # Panel wrapper
    panel_parts <- c(panel_parts, sprintf(
      '<div class="tk-metric-panel%s" id="mv-%s">',
      active_class, mr$metric_id
    ))

    # Title
    q_text <- if (nzchar(mr$question_text)) paste0(" &mdash; ", htmltools::htmlEscape(mr$question_text)) else ""
    panel_parts <- c(panel_parts, sprintf(
      '<h2 class="mv-metric-title">%s<span class="mv-metric-subtitle">%s</span></h2>',
      htmltools::htmlEscape(mr$metric_label), q_text
    ))

    # Segment chips — grouped by category
    panel_parts <- c(panel_parts, '<div class="mv-segment-chips mv-segment-grouped">')

    # Standalone segments first (Total)
    for (seg_name in segment_group_info$standalone) {
      s_idx <- match(seg_name, segments)
      seg_colour <- segment_colours[s_idx]
      active_chip <- if (s_idx == 1) " active" else ""
      panel_parts <- c(panel_parts, sprintf(
        '<button class="tk-segment-chip%s" data-segment="%s" style="--chip-color:%s" onclick="toggleSegmentChip(\'%s\',\'%s\',this)">%s</button>',
        active_chip, htmltools::htmlEscape(seg_name), seg_colour,
        mr$metric_id, htmltools::htmlEscape(seg_name),
        htmltools::htmlEscape(seg_name)
      ))
    }

    # Grouped segments
    for (group_name in names(segment_group_info$groups)) {
      group_segs <- segment_group_info$groups[[group_name]]

      panel_parts <- c(panel_parts, sprintf(
        '<div class="mv-segment-group" data-group="%s">',
        htmltools::htmlEscape(group_name)
      ))

      # Group header button (expands/collapses group, toggles all children)
      panel_parts <- c(panel_parts, sprintf(
        '<button class="mv-segment-group-header" data-group="%s" onclick="toggleSegmentGroupExpand(\'%s\',\'%s\',this)">%s <span class="chevron">&#x25B6;</span></button>',
        htmltools::htmlEscape(group_name),
        mr$metric_id, htmltools::htmlEscape(group_name),
        htmltools::htmlEscape(group_name)
      ))

      # Individual chips inside the group
      panel_parts <- c(panel_parts, '<div class="mv-segment-group-chips">')
      for (seg_name in group_segs) {
        s_idx <- match(seg_name, segments)
        seg_colour <- segment_colours[s_idx]
        # Display the value part only (after group prefix)
        display_label <- sub(paste0("^", group_name, "_"), "", seg_name)
        panel_parts <- c(panel_parts, sprintf(
          '<button class="tk-segment-chip" data-segment="%s" data-group="%s" style="--chip-color:%s" onclick="toggleSegmentChip(\'%s\',\'%s\',this)">%s</button>',
          htmltools::htmlEscape(seg_name), htmltools::htmlEscape(group_name),
          seg_colour,
          mr$metric_id, htmltools::htmlEscape(seg_name),
          htmltools::htmlEscape(display_label)
        ))
      }
      panel_parts <- c(panel_parts, '</div>')  # close group-chips
      panel_parts <- c(panel_parts, '</div>')  # close segment-group
    }

    panel_parts <- c(panel_parts, '</div>')  # close mv-segment-chips

    # Wave chips (toggleable, all active by default)
    panel_parts <- c(panel_parts, '<div class="mv-wave-chips">')
    panel_parts <- c(panel_parts, '<span class="mv-wave-chips-label">Waves:</span>')
    for (w_idx in seq_along(html_data$waves)) {
      wid <- html_data$waves[w_idx]
      wlabel <- html_data$wave_labels[w_idx]
      panel_parts <- c(panel_parts, sprintf(
        '<button class="tk-wave-chip active" data-wave="%s" onclick="toggleWaveChip(\'%s\',\'%s\',this)">%s</button>',
        htmltools::htmlEscape(wid),
        mr$metric_id, htmltools::htmlEscape(wid),
        htmltools::htmlEscape(wlabel)
      ))
    }
    panel_parts <- c(panel_parts, '</div>')

    # Controls row: Show count + vs Prev/Base toggles + Show chart checkbox + Pin
    panel_parts <- c(panel_parts, sprintf('<div class="mv-controls">'))

    panel_parts <- c(panel_parts, '<div class="mv-control-group">')
    panel_parts <- c(panel_parts, sprintf(
      '<label class="tk-toggle"><input type="checkbox" onchange="toggleMetricCounts(\'%s\')"><span class="tk-toggle-label">Show count</span></label>',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, sprintf(
      '<label class="tk-toggle"><input type="checkbox" onchange="toggleMetricChangeRows(\'%s\',\'vs-prev\')"><span class="tk-toggle-label">vs Previous</span></label>',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, sprintf(
      '<label class="tk-toggle"><input type="checkbox" onchange="toggleMetricChangeRows(\'%s\',\'vs-base\')"><span class="tk-toggle-label">vs Baseline</span></label>',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, '</div>')

    # Show chart checkbox (shows chart underneath table)
    panel_parts <- c(panel_parts, '<div class="mv-control-group">')
    panel_parts <- c(panel_parts, sprintf(
      '<label class="tk-toggle"><input type="checkbox" class="mv-show-chart-cb" onchange="toggleShowChart(\'%s\',this.checked)"><span class="tk-toggle-label">Show chart</span></label>',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, '</div>')

    # Export + Pin + Slide buttons
    panel_parts <- c(panel_parts, sprintf(
      '<button class="export-btn" onclick="exportMetricExcel(\'%s\')" title="Export to Excel">&#x1F4CA; Export</button>',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, sprintf(
      '<button class="export-btn" onclick="pinMetricView(\'%s\')" title="Pin this view">&#x1F4CC; Pin</button>',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, sprintf(
      '<button class="export-btn" onclick="exportSlidePNG(\'%s\',\'table\')" title="Export as slide">&#x1F4F8; Export Slide</button>',
      mr$metric_id
    ))

    panel_parts <- c(panel_parts, '</div>')  # close controls

    # ---- Table Area ----
    panel_parts <- c(panel_parts, '<div class="mv-table-area">')
    panel_parts <- c(panel_parts, build_metric_table(mr, html_data, sparkline_data, segments, segment_colours, brand_colour, min_base))
    panel_parts <- c(panel_parts, '</div>')

    # ---- Chart Area ----
    panel_parts <- c(panel_parts, sprintf('<div class="mv-chart-area" style="display:none">%s</div>', chart_html))

    # ---- Insight Area ----
    panel_parts <- c(panel_parts, '<div class="insight-area">')
    panel_parts <- c(panel_parts, sprintf(
      '<button class="insight-toggle" onclick="toggleMetricInsight(\'%s\')">+ Add Insight</button>',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, '<div class="insight-container" style="display:none">')
    panel_parts <- c(panel_parts, sprintf(
      '<div class="insight-editor" contenteditable="true" data-placeholder="Type key insight here..." oninput="syncMetricInsight(\'%s\')"></div>',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, sprintf(
      '<button class="insight-dismiss" title="Delete insight" onclick="dismissMetricInsight(\'%s\')">&times;</button>',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, '</div>')
    panel_parts <- c(panel_parts, sprintf(
      '<textarea class="insight-store" style="display:none"></textarea>'
    ))
    panel_parts <- c(panel_parts, '</div>')

    panel_parts <- c(panel_parts, '</div>')  # close panel
    panels <- c(panels, paste(panel_parts, collapse = "\n"))
  }

  paste(panels, collapse = "\n")
}


#' Build Per-Metric Table (for Metrics by Segment tab)
#'
#' Layout: Columns = waves only (no segment duplication).
#' Rows = one row per segment (toggled by chips). n= shown inline under
#' the value (hidden by default, toggled with "Show count").
#' Wave columns can be hidden via wave chips.
#'
#' @keywords internal
build_metric_table <- function(mr, html_data, sparkline_data, segments, segment_colours, brand_colour, min_base = 30L) {

  waves <- html_data$waves
  wave_labels <- html_data$wave_labels
  n_waves <- length(waves)
  min_base <- as.integer(min_base)

  parts <- c()
  parts <- c(parts, '<div class="tk-table-wrapper">')
  parts <- c(parts, '<table class="tk-table mv-metric-table">')

  # ---- THEAD: Wave-only header (clickable for sorting) ----
  parts <- c(parts, '<thead>')
  parts <- c(parts, '<tr class="tk-wave-header-row">')
  parts <- c(parts, '<th class="tk-th tk-label-col">Segment</th>')

  for (w_idx in seq_along(waves)) {
    parts <- c(parts, sprintf(
      '<th class="tk-th tk-wave-header tk-sortable" data-wave="%s" data-col-index="%d" onclick="sortMetricTable(\'%s\',%d,this)" title="Click to sort">%s</th>',
      htmltools::htmlEscape(waves[w_idx]),
      w_idx,
      mr$metric_id, w_idx,
      htmltools::htmlEscape(wave_labels[w_idx])
    ))
  }
  parts <- c(parts, '</tr>')
  parts <- c(parts, '</thead>')

  # ---- TBODY: Single Total base row at top, then one row per segment ----
  parts <- c(parts, '<tbody>')

  # Base (n=) row at TOP — Total segment only (always visible)
  total_seg <- segments[1]  # Total is always first
  total_cells <- mr$segment_cells[[total_seg]]
  if (!is.null(total_cells)) {
    parts <- c(parts, '<tr class="tk-base-row">')
    parts <- c(parts, '<td class="tk-td tk-label-col tk-base-label">Base (n=)</td>')
    for (wid in waves) {
      cell <- total_cells[[wid]]
      n_val <- if (!is.null(cell) && !is.na(cell$n)) cell$n else NA
      if (!is.na(n_val) && n_val < min_base) {
        n_display <- sprintf('<span class="tk-low-base">%s &#x26A0;</span>', n_val)
      } else {
        n_display <- if (!is.na(n_val)) as.character(n_val) else ""
      }
      parts <- c(parts, sprintf(
        '<td class="tk-td tk-base-cell" data-wave="%s" data-n="%s">%s</td>',
        htmltools::htmlEscape(wid),
        if (!is.na(n_val)) n_val else "",
        n_display
      ))
    }
    parts <- c(parts, '</tr>')
  }

  for (s_idx in seq_along(segments)) {
    seg_name <- segments[s_idx]
    cells <- mr$segment_cells[[seg_name]]
    if (is.null(cells)) next

    seg_hidden <- if (s_idx > 1) " segment-hidden" else ""
    seg_colour <- segment_colours[s_idx]

    # Sparkline
    sparkline_svg <- ""
    if (!is.null(sparkline_data[[seg_name]])) {
      sparkline_svg <- build_sparkline_svg(sparkline_data[[seg_name]], colour = seg_colour)
    }

    # ---- Value row ----
    parts <- c(parts, sprintf(
      '<tr class="tk-metric-row%s" data-segment="%s">',
      seg_hidden, htmltools::htmlEscape(seg_name)
    ))
    # Label cell with colour dot and sparkline
    parts <- c(parts, sprintf(
      '<td class="tk-td tk-label-col"><span class="tk-seg-dot" style="background:%s"></span><span class="tk-metric-label">%s</span><span class="tk-sparkline-wrap">%s</span></td>',
      seg_colour, htmltools::htmlEscape(seg_name), sparkline_svg
    ))

    for (wid in waves) {
      cell <- cells[[wid]]
      if (is.null(cell)) {
        parts <- c(parts, sprintf(
          '<td class="tk-td tk-value-cell" data-wave="%s">&mdash;</td>',
          htmltools::htmlEscape(wid)
        ))
        next
      }
      # Value + n= frequency underneath (hidden by default)
      sort_val <- if (!is.na(cell$value)) cell$value else ""
      n_display <- if (!is.na(cell$n)) sprintf('<div class="tk-freq">n=%s</div>', cell$n) else ""
      low_base_class <- if (!is.na(cell$n) && cell$n < min_base) " tk-low-base-dim" else ""
      parts <- c(parts, sprintf(
        '<td class="tk-td tk-value-cell%s" data-wave="%s" data-segment="%s" data-sort-val="%s"><span class="tk-val">%s</span>%s</td>',
        low_base_class,
        htmltools::htmlEscape(wid),
        htmltools::htmlEscape(seg_name),
        sort_val,
        cell$display_value, n_display
      ))
    }
    parts <- c(parts, '</tr>')

    # ---- vs Previous change row ----
    parts <- c(parts, sprintf(
      '<tr class="tk-change-row tk-vs-prev%s" data-segment="%s">',
      seg_hidden, htmltools::htmlEscape(seg_name)
    ))
    parts <- c(parts, '<td class="tk-td tk-label-col tk-change-label">vs Prev</td>')
    for (wid in waves) {
      cell <- cells[[wid]]
      content <- ""
      if (!is.null(cell) && !cell$is_first_wave && nzchar(cell$display_vs_prev)) {
        content <- cell$display_vs_prev
      }
      parts <- c(parts, sprintf(
        '<td class="tk-td tk-change-cell" data-wave="%s" data-segment="%s">%s</td>',
        htmltools::htmlEscape(wid), htmltools::htmlEscape(seg_name), content
      ))
    }
    parts <- c(parts, '</tr>')

    # ---- vs Baseline change row ----
    parts <- c(parts, sprintf(
      '<tr class="tk-change-row tk-vs-base%s" data-segment="%s">',
      seg_hidden, htmltools::htmlEscape(seg_name)
    ))
    parts <- c(parts, '<td class="tk-td tk-label-col tk-change-label">vs Base</td>')
    for (wid in waves) {
      cell <- cells[[wid]]
      content <- ""
      if (!is.null(cell) && !cell$is_baseline && nzchar(cell$display_vs_base)) {
        content <- cell$display_vs_base
      }
      parts <- c(parts, sprintf(
        '<td class="tk-td tk-change-cell" data-wave="%s" data-segment="%s">%s</td>',
        htmltools::htmlEscape(wid), htmltools::htmlEscape(seg_name), content
      ))
    }
    parts <- c(parts, '</tr>')
  }

  parts <- c(parts, '</tbody>')
  parts <- c(parts, '</table>')
  parts <- c(parts, '</div>')

  paste(parts, collapse = "\n")
}


# ==============================================================================
# PINNED VIEWS TAB
# ==============================================================================

#' Build Pinned Views Tab
#' @keywords internal
build_pinned_tab <- function() {

  htmltools::tags$div(class = "pinned-tab-content",
    # Export toolbar (hidden when no pins)
    htmltools::tags$div(class = "pinned-toolbar", id = "pinned-toolbar",
                         style = "display:none",
      htmltools::tags$button(class = "tk-btn", onclick = "exportAllPinsPNG()",
                              htmltools::HTML("&#x1F4F8; Export All as PNGs")),
      htmltools::tags$button(class = "tk-btn", onclick = "printAllPins()",
                              htmltools::HTML("&#x1F5A8; Print / Save PDF")),
      htmltools::tags$button(class = "tk-btn", onclick = "saveReportHTML()",
                              htmltools::HTML("&#x1F4BE; Save Report HTML"))
    ),
    htmltools::tags$div(id = "pinned-cards-container"),
    htmltools::tags$div(
      id = "pinned-empty-state",
      class = "pinned-empty-state",
      htmltools::HTML("&#x1F4CC; No pinned views yet. Go to <strong>Metrics by Segment</strong> and click <strong>Pin</strong> to save a view here.")
    )
  )
}


# ==============================================================================
# HEADER
# ==============================================================================

#' @keywords internal
build_tracker_header <- function(html_data, config, brand_colour) {

  project_name <- html_data$metadata$project_name %||% "Tracking Report"
  company_name <- get_setting(config, "company_name", default = "") %||% ""
  client_name <- get_setting(config, "client_name", default = "") %||% ""
  n_metrics <- html_data$n_metrics
  n_waves <- length(html_data$waves)
  n_segments <- length(html_data$segments)
  created_date <- format(html_data$metadata$generated_at, "%b %Y")

  # Logos (base64 embedded)
  researcher_logo_html <- ""
  logo_path <- get_setting(config, "researcher_logo_path", default = NULL)
  if (!is.null(logo_path) && file.exists(logo_path)) {
    logo_b64 <- base64enc::dataURI(file = logo_path, mime = "image/png")
    researcher_logo_html <- sprintf(
      '<div class="tk-header-logo-wrap"><img src="%s" alt="Logo" class="tk-header-logo"/></div>',
      logo_b64
    )
  }

  # "Prepared by" line
  prepared_by <- ""
  if (nzchar(company_name) || nzchar(client_name)) {
    parts <- c()
    if (nzchar(company_name)) parts <- c(parts, sprintf("Prepared by <strong>%s</strong>", htmltools::htmlEscape(company_name)))
    if (nzchar(client_name)) parts <- c(parts, sprintf("for <strong>%s</strong>", htmltools::htmlEscape(client_name)))
    prepared_by <- paste(parts, collapse = " ")
  }

  # Stats badge bar
  badge_items <- c(
    sprintf('<span class="tk-badge-item"><strong>%d</strong> Metrics</span>', n_metrics),
    sprintf('<span class="tk-badge-item"><strong>%d</strong> Waves</span>', n_waves),
    sprintf('<span class="tk-badge-item"><strong>%d</strong> Segment%s</span>', n_segments, if (n_segments > 1) "s" else ""),
    sprintf('<span class="tk-badge-item" id="header-date-badge">Created %s</span>', htmltools::htmlEscape(created_date))
  )
  badge_bar <- paste(
    '<div class="tk-badge-bar">',
    paste(badge_items, collapse = '<span class="tk-badge-sep"></span>'),
    '</div>'
  )

  htmltools::tags$header(class = "tk-header",
    htmltools::tags$div(class = "tk-header-inner",
      # Top row: Logo + Branding ... Action buttons + Help
      htmltools::tags$div(class = "tk-header-top",
        htmltools::tags$div(class = "tk-header-brand",
          htmltools::HTML(researcher_logo_html),
          htmltools::tags$div(
            htmltools::tags$div(class = "tk-brand-name", "Turas Tracker"),
            htmltools::tags$div(class = "tk-brand-subtitle", "Interactive Tracking Report")
          )
        ),
        htmltools::tags$div(class = "tk-header-actions",
          htmltools::tags$button(class = "tk-help-btn",
                                  onclick = "toggleHelpOverlay()", "?")
        )
      ),
      # Project title
      htmltools::tags$div(class = "tk-header-project", project_name),
      # Prepared by line
      if (nzchar(prepared_by)) {
        htmltools::tags$div(class = "tk-header-prepared", htmltools::HTML(prepared_by))
      },
      # Stats badge bar
      htmltools::HTML(badge_bar)
    )
  )
}


# ==============================================================================
# SIDEBAR (for Segment Overview tab) — Shows segments for quick switching
# ==============================================================================

#' Build Overview Sidebar
#'
#' Shows segment list for quick switching (replaces old metric sidebar).
#' Each segment is a clickable item that switches the dropdown and table.
#'
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

  # Grouped segments
  for (group_name in names(segment_group_info$groups)) {
    group_segs <- segment_group_info$groups[[group_name]]

    items <- c(items, sprintf(
      '<div class="tk-sidebar-section">%s</div>',
      htmltools::htmlEscape(group_name)
    ))

    for (seg_name in group_segs) {
      s_idx <- match(seg_name, segments)
      seg_colour <- segment_colours[s_idx]
      display_label <- sub(paste0("^", group_name, "_"), "", seg_name)
      items <- c(items, sprintf(
        '<a class="tk-sidebar-item tk-seg-sidebar-item" data-segment="%s" href="#" onclick="switchSegment(\'%s\');return false;"><span class="tk-seg-dot" style="background:%s"></span>%s</a>',
        htmltools::htmlEscape(seg_name),
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
      )
    )
  )
}

# ==============================================================================
# SEGMENT SELECTOR (dropdown for Segment Overview tab)
# ==============================================================================

#' Build Segment Selector Dropdown
#'
#' Replaces the old tab bar with a single dropdown to switch between
#' segments in the Segment Overview table. Shows one segment at a time.
#'
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


# ==============================================================================
# CONTROLS (for Segment Overview tab)
# ==============================================================================

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


# ==============================================================================
# CHART CONTAINERS (for Segment Overview tab)
# ==============================================================================

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
        htmltools::tags$h3("Report Tabs"),
        htmltools::tags$ul(
          htmltools::tags$li(htmltools::tags$strong("Summary"), " \u2014 Key findings and methodology notes"),
          htmltools::tags$li(htmltools::tags$strong("Metrics by Segment"), " \u2014 Explore one metric at a time with segment chips and chart toggle"),
          htmltools::tags$li(htmltools::tags$strong("Segment Overview"), " \u2014 Full crosstab table with all metrics"),
          htmltools::tags$li(htmltools::tags$strong("Pinned Views"), " \u2014 Save and compare specific metric views")
        ),
        htmltools::tags$h3("Significance Indicators"),
        htmltools::tags$ul(
          htmltools::tags$li(htmltools::HTML("<span class='sig-up'>&#x2191;</span> Significant increase")),
          htmltools::tags$li(htmltools::HTML("<span class='sig-down'>&#x2193;</span> Significant decrease")),
          htmltools::tags$li(htmltools::HTML("<span class='not-sig'>&#x2192;</span> No significant change"))
        ),
        htmltools::tags$h3("Segment Chips"),
        htmltools::tags$p("Click segment chips to show or hide individual segments. Total is shown by default."),
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
/* === TURAS TRACKER HTML REPORT v2.1 === */
:root {
  --brand: BRAND_COLOUR;
  --accent: ACCENT_COLOUR;
  /* Shared Turas design tokens (aligned with Turas Tabs --ct-* prefix) */
  --ct-brand: BRAND_COLOUR;
  --ct-accent: ACCENT_COLOUR;
  --ct-text-primary: #1e293b;
  --ct-text-secondary: #64748b;
  --ct-bg-surface: #ffffff;
  --ct-bg-muted: #f8f9fa;
  --ct-border: #e2e8f0;
  /* Module variables */
  --bg: #f8f7f5;
  --card: #ffffff;
  --text: #1e293b;
  --text-muted: #64748b;
  --border: #e2e8f0;
  --section-bg: #f0f4e8;
  --change-bg: #fafafa;
  --sidebar-w: 280px;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--text); font-size: 14px; line-height: 1.5; }

/* Header — dark gradient matching Turas Tabs */
.tk-header { background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%); padding: 24px 32px; border-bottom: 3px solid var(--brand); color: #fff; }
.tk-header-inner { max-width: 1400px; margin: 0 auto; }
.tk-header-top { display: flex; align-items: center; justify-content: space-between; }
.tk-header-brand { display: flex; align-items: center; gap: 16px; }
.tk-header-logo-wrap { width: 72px; height: 72px; border-radius: 12px; background: transparent; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.tk-header-logo { height: 56px; width: 56px; object-fit: contain; }
.tk-brand-name { color: #fff; font-size: 28px; font-weight: 700; line-height: 1.2; letter-spacing: -0.3px; }
.tk-brand-subtitle { color: rgba(255,255,255,0.50); font-size: 12px; font-weight: 400; margin-top: 2px; }
.tk-help-btn { width: 28px; height: 28px; border-radius: 50%; border: 1.5px solid rgba(255,255,255,0.5); background: transparent; color: rgba(255,255,255,0.8); font-size: 14px; font-weight: 700; cursor: pointer; display: flex; align-items: center; justify-content: center; }
.tk-help-btn:hover { border-color: #fff; color: #fff; }
.tk-header-project { color: #fff; font-size: 22px; font-weight: 700; letter-spacing: -0.3px; margin-top: 16px; line-height: 1.2; }
.tk-header-prepared { color: rgba(255,255,255,0.65); font-size: 13px; font-weight: 400; margin-top: 4px; }
.tk-header-prepared strong { font-weight: 600; }
.tk-badge-bar { display: inline-flex; align-items: center; margin-top: 12px; border: 1px solid rgba(255,255,255,0.15); border-radius: 6px; background: rgba(255,255,255,0.05); }
.tk-badge-item { display: inline-flex; align-items: center; padding: 4px 12px; font-size: 12px; font-weight: 600; color: rgba(255,255,255,0.85); }
.tk-badge-item strong { color: #fff; font-weight: 700; margin-right: 4px; }
.tk-badge-sep { width: 1px; height: 16px; background: rgba(255,255,255,0.20); flex-shrink: 0; }

/* ---- REPORT TABS ---- */
.report-tabs { display: flex; align-items: center; gap: 0; background: var(--card); border-bottom: 2px solid var(--border); padding: 0 24px; }
.report-tab { padding: 12px 24px; border: none; background: transparent; color: var(--text); font-size: 14px; font-weight: 600; cursor: pointer; font-family: inherit; border-bottom: 3px solid transparent; transition: all 0.15s; }
.report-tab:hover:not(.active) { background: #f8f8f8; color: var(--brand); }
.report-tab.active { color: var(--brand); border-bottom-color: var(--brand); }
.pin-count-badge { display: inline-block; margin-left: 6px; padding: 1px 7px; border-radius: 10px; background: var(--brand); color: #fff; font-size: 11px; font-weight: 700; }
.tk-tab-actions { display: flex; gap: 8px; align-items: center; padding: 6px 0; }

/* ---- TAB PANELS ---- */
.tk-tab-panels { min-height: calc(100vh - 180px); }
.tab-panel { display: none; }
.tab-panel.active { display: block; }

/* ---- SUMMARY TAB ---- */
.summary-tab-content { max-width: 900px; margin: 0 auto; padding: 32px 24px; }
.summary-stats-row { display: flex; gap: 16px; margin-bottom: 32px; flex-wrap: wrap; }
.summary-stat-card { flex: 1; min-width: 140px; background: var(--card); border: 1px solid var(--border); border-radius: 10px; padding: 20px 16px; text-align: center; }
.stat-number { font-size: 28px; font-weight: 700; color: var(--brand); }
.stat-label { font-size: 13px; color: var(--text-muted); margin-top: 4px; }
.summary-insight-box { background: var(--card); border: 1px solid var(--border); border-radius: 10px; padding: 24px; margin-bottom: 20px; position: relative; }
.summary-insight-title { font-size: 16px; font-weight: 700; color: var(--brand); margin-bottom: 12px; }
.summary-editor { min-height: 80px; }
.summary-section-controls { float: right; display: flex; gap: 4px; }

/* ---- METRICS BY SEGMENT TAB ---- */
.metrics-tab-layout { display: flex; min-height: calc(100vh - 180px); }
.mv-sidebar { width: var(--sidebar-w); flex-shrink: 0; padding: 16px 0 0 0; }
.mv-sidebar-inner { position: sticky; top: 20px; }
.mv-sidebar-search { padding: 0 14px 12px; }
.tk-search-input { width: 100%; padding: 10px 14px; border: 1px solid var(--border); border-radius: 6px; font-size: 13px; background: var(--card); outline: none; transition: border-color 0.15s; font-family: inherit; }
.tk-search-input:focus { border-color: var(--brand); }
.mv-sidebar-nav-wrap { background: var(--card); border-radius: 8px; border: 1px solid var(--border); overflow: hidden; }
.mv-sidebar-nav-header { padding: 10px 14px; border-bottom: 1px solid var(--border); font-size: 11px; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 1px; }
.mv-sidebar-nav-scroll { max-height: 500px; overflow-y: auto; }
.mv-sidebar-nav { padding: 0; }
.mv-nav-section { padding: 10px 14px 4px; font-size: 11px; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 1px; }
.tk-metric-nav-item { display: block; padding: 10px 14px; font-size: 12px; color: var(--text); text-decoration: none; cursor: pointer; border-left: 3px solid transparent; border-bottom: 1px solid var(--border); transition: all 0.12s ease; line-height: 1.35; }
.tk-metric-nav-item:last-child { border-bottom: none; }
.tk-metric-nav-item:hover { background: #f8fafc; }
.tk-metric-nav-item.active { border-left-color: var(--brand); background: #e6f5f5; font-weight: 600; color: #1a2744; }
/* Metric type filter */
.mv-type-filter { display: flex; gap: 4px; padding: 8px 12px; border-bottom: 1px solid var(--border); flex-wrap: wrap; }
.mv-type-chip { padding: 3px 10px; border: 1.5px solid var(--border); background: var(--card); border-radius: 12px; font-size: 11px; font-weight: 600; cursor: pointer; transition: all 0.15s; color: var(--text-muted); font-family: inherit; }
.mv-type-chip:hover { border-color: var(--brand); }
.mv-type-chip.active { border-color: var(--brand); color: var(--brand); background: #f0f0ff; }
.mv-global-controls { padding: 10px 16px; border-bottom: 1px solid var(--border); }
.mv-content { flex: 1; padding: 24px; overflow-x: auto; }

/* Metric panel */
.tk-metric-panel { display: none; }
.tk-metric-panel.active { display: block; }
.mv-metric-title { font-size: 16px; font-weight: 700; color: var(--text); margin-bottom: 4px; }
.mv-metric-subtitle { font-size: 13px; font-weight: 400; color: var(--text-muted); }

/* Segment chips */
.mv-segment-chips { display: flex; gap: 8px; margin: 16px 0 8px; flex-wrap: wrap; }
.tk-segment-chip { padding: 6px 16px; border: 2px solid var(--border); background: var(--card); border-radius: 20px; font-size: 13px; font-weight: 600; cursor: pointer; transition: all 0.15s; color: var(--text-muted); font-family: inherit; }
.tk-segment-chip.active { border-color: var(--chip-color, var(--brand)); color: var(--chip-color, var(--brand)); background: #f8f8ff; }
.tk-segment-chip:hover { border-color: var(--chip-color, var(--brand)); }

/* Hierarchical segment groups */
.mv-segment-grouped { display: flex; gap: 12px; align-items: flex-start; flex-wrap: wrap; }
.mv-segment-group { display: flex; flex-direction: column; gap: 4px; }
.mv-segment-group-header { padding: 5px 14px; border: 2px solid var(--border); background: #f0f0f5; border-radius: 6px; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-muted); cursor: pointer; transition: all 0.15s; font-family: inherit; }
.mv-segment-group-header:hover { border-color: var(--brand); color: var(--brand); }
.mv-segment-group-header.active { background: #e8e8ff; border-color: var(--brand); color: var(--brand); }
.mv-segment-group-header .chevron { display: inline-block; font-size: 9px; margin-left: 4px; transition: transform 0.2s; }
.mv-segment-group.expanded .mv-segment-group-header .chevron { transform: rotate(90deg); }
.mv-segment-group-chips { display: none; gap: 6px; flex-wrap: wrap; padding-left: 4px; }
.mv-segment-group.expanded .mv-segment-group-chips { display: flex; }

/* Wave chips */
.mv-wave-chips { display: flex; gap: 6px; margin: 0 0 12px; flex-wrap: wrap; align-items: center; }
.mv-wave-chips-label { font-size: 12px; font-weight: 600; color: var(--text-muted); margin-right: 4px; }
.tk-wave-chip { padding: 4px 12px; border: 1.5px solid var(--border); background: var(--card); border-radius: 14px; font-size: 12px; font-weight: 500; cursor: pointer; transition: all 0.15s; color: var(--text-muted); font-family: inherit; }
.tk-wave-chip.active { border-color: #4682B4; color: #4682B4; background: #f0f6ff; font-weight: 600; }
.tk-wave-chip:not(.active) { opacity: 0.5; background: #f0f0f0; text-decoration: line-through; }
.tk-wave-chip:hover { border-color: #4682B4; }

/* Metric controls */
.mv-controls { display: flex; align-items: center; gap: 16px; flex-wrap: wrap; margin-bottom: 16px; }
.mv-control-group { display: flex; align-items: center; gap: 8px; }
.mv-pin-btn { margin-left: auto; }
.mv-pin-btn.pinned { background: var(--brand); color: #fff; border-color: var(--brand); }

/* Metric table area */
.mv-table-area { margin-bottom: 16px; }
.mv-chart-area { margin-top: 12px; margin-bottom: 16px; }

/* ---- SEGMENT OVERVIEW TAB ---- */
.tk-layout { display: flex; min-height: calc(100vh - 180px); }
.tk-sidebar { width: var(--sidebar-w); flex-shrink: 0; padding: 16px 0 0 14px; }
.tk-sidebar-inner { position: sticky; top: 20px; }
.tk-sidebar-nav-card { background: var(--card); border-radius: 8px; border: 1px solid var(--border); overflow: hidden; }
.tk-sidebar-nav-scroll { max-height: 500px; overflow-y: auto; }
.tk-sidebar-nav { padding: 0; }
.tk-sidebar-section { padding: 10px 14px 4px; font-size: 11px; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 1px; }
.tk-sidebar-item { display: block; padding: 10px 14px; font-size: 12px; color: var(--text); text-decoration: none; cursor: pointer; border-left: 3px solid transparent; border-bottom: 1px solid var(--border); transition: all 0.12s ease; }
.tk-sidebar-item:last-child { border-bottom: none; }
.tk-sidebar-item:hover { background: #f8fafc; }
.tk-sidebar-item.active { border-left-color: var(--brand); background: #e6f5f5; font-weight: 600; color: #1a2744; }
.tk-sidebar-item.hidden { display: none; }
.tk-content { flex: 1; padding: 20px 24px; overflow-x: auto; }

/* Segment selector dropdown (retained for possible future use) */
.tk-segment-selector { display: none; }

/* Segment header row removed from HTML (single-row header used instead) */

/* Segment sidebar items */
.tk-seg-sidebar-item { display: flex; align-items: center; gap: 8px; }
/* Overview actions bar (pin + export + insight) */
.overview-actions-bar { display: flex; gap: 8px; margin-top: 16px; padding: 10px 0; }
.tk-sidebar-header { padding: 10px 14px; font-size: 11px; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 1px; border-bottom: 1px solid var(--border); }

/* Summary metrics table */
.summary-metrics-table-wrap { background: var(--card); border: 1px solid var(--border); border-radius: 10px; padding: 24px; margin-bottom: 20px; overflow-x: auto; }
.summary-metrics-table { font-size: 13px; }
.summary-metrics-table .tk-section-cell { font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; color: #888; padding: 12px 16px 4px; border: none; background: none; }
.summary-type-filter { display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 12px; }
.summary-type-chip { padding: 5px 14px; border-radius: 16px; border: 1px solid var(--border); background: var(--card); font-size: 12px; cursor: pointer; color: var(--text-muted); transition: all 0.15s; }
.summary-type-chip:hover { border-color: var(--brand); color: var(--brand); }
.summary-type-chip.active { background: var(--brand); color: #fff; border-color: var(--brand); }
.summary-actions { display: flex; gap: 8px; margin-bottom: 12px; }

/* Controls */
.tk-controls { display: flex; align-items: center; gap: 16px; flex-wrap: wrap; margin-bottom: 16px; padding: 10px 16px; background: var(--card); border-radius: 8px; border: 1px solid var(--border); }
.tk-control-group { display: flex; align-items: center; gap: 8px; }
.tk-control-label { font-size: 12px; color: var(--text-muted); font-weight: 600; }
.tk-toggle { display: flex; align-items: center; gap: 6px; cursor: pointer; font-size: 12px; color: var(--text-muted); }
.tk-toggle input[type="checkbox"] { width: 16px; height: 16px; accent-color: var(--brand); }
.tk-toggle-label { user-select: none; }
.tk-btn { padding: 6px 14px; border: 1px solid var(--border); background: var(--card); border-radius: 6px; font-size: 12px; cursor: pointer; transition: all 0.15s; font-family: inherit; }
.tk-btn:hover { background: #f0f0f0; }
.tk-btn-view { border-radius: 0; }
.tk-btn-view:first-child { border-radius: 6px 0 0 6px; }
.tk-btn-view:last-child { border-radius: 0 6px 6px 0; }
.tk-btn-active { background: var(--brand); color: #fff; border-color: var(--brand); }
.tk-btn-sm { padding: 4px 10px; font-size: 11px; }
.tk-btn-export { background: #f8f8f8; }
.tk-select { padding: 6px 10px; border: 1px solid var(--border); border-radius: 6px; font-size: 12px; background: var(--card); }
.tk-export-group { margin-left: auto; }

/* Export button (shared Turas design — matches Turas Tabs .export-btn) */
.export-btn { display: inline-flex; align-items: center; gap: 4px; padding: 6px 14px; border: 1px solid var(--border); border-radius: 4px; background: #ffffff; color: var(--text-muted); font-size: 11px; font-weight: 600; cursor: pointer; font-family: inherit; transition: all 0.12s; white-space: nowrap; }
.export-btn:hover { background: #f8fafc; color: var(--text); }

/* Header action buttons (dark background variant) */
.tk-header-actions { display: flex; align-items: center; gap: 8px; }
.tk-header .export-btn { border-color: rgba(255,255,255,0.3); color: rgba(255,255,255,0.85); background: rgba(255,255,255,0.08); }
.tk-header .export-btn:hover { border-color: rgba(255,255,255,0.6); color: #fff; background: rgba(255,255,255,0.15); }

/* Low base warning */
.tk-low-base { color: #dc2626; font-weight: 700; }
.tk-low-base-dim { opacity: 0.45; }

/* Segment showing label */
.tk-segment-showing { font-size: 14px; color: var(--text); margin-bottom: 8px; padding: 4px 0; }
.tk-segment-showing strong { color: var(--brand); }

/* Segment indicator row */
.tk-segment-indicator-row { }
.tk-segment-indicator { height: 4px; padding: 0; border: none; }

/* ---- TABLE STYLES ---- */
.tk-table-wrapper { overflow-x: auto; border-radius: 8px; border: 1px solid var(--border); background: var(--card); }
.tk-table { width: 100%; border-collapse: collapse; font-size: 12px; }
.tk-th { padding: 8px 10px; text-align: center; font-size: 11px; font-weight: 600; border-bottom: 2px solid var(--border); white-space: nowrap; background: var(--ct-bg-muted); }
.tk-td { padding: 6px 10px; text-align: center; border-bottom: 1px solid #f0f0f0; }
.tk-label-col { text-align: left; min-width: 180px; max-width: 320px; }
.tk-sticky-col { position: sticky; left: 0; z-index: 2; background: var(--card); }
.tk-segment-header { font-size: 12px; letter-spacing: 0.3px; }
.tk-wave-header { font-size: 12px; background: #f8f8fc; }
.tk-value-cell { font-variant-numeric: tabular-nums; }

/* Section rows (collapsible) */
.tk-section-row { background: none; }
.tk-section-cell { padding: 14px 16px 8px; font-size: 12px; font-weight: 700; color: var(--brand); text-transform: uppercase; letter-spacing: 0.5px; background: var(--section-bg); border-bottom: 2px solid var(--border); cursor: pointer; user-select: none; }
.tk-section-cell:hover { background: #e5ebd8; }
.section-chevron { display: inline-block; font-size: 10px; transition: transform 0.2s; margin-right: 4px; }
.section-collapsed .section-chevron { transform: rotate(-90deg); }
tr.section-hidden { display: none !important; }

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

/* Significance toggle */
body.hide-significance .sig-up { color: inherit; font-weight: normal; }
body.hide-significance .sig-down { color: inherit; font-weight: normal; }
body.hide-significance .sig-arrow { display: none; }

/* Base row */
.tk-base-row { border-top: 2px solid var(--border); }
.tk-base-label { font-size: 11px; color: var(--text-muted); font-weight: 600; }
.tk-base-cell { font-size: 11px; color: var(--text-muted); }

/* n= frequency count (hidden by default, toggled) */
.tk-freq { display: none; font-size: 10px; color: #94a3b8; margin-top: 1px; }
.show-freq .tk-freq { display: block; }

/* Segment colour dot */
.tk-seg-dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 6px; vertical-align: middle; }

/* Sortable column headers */
.tk-sortable { cursor: pointer; user-select: none; }
.tk-sortable:hover { background: #eef; }
.tk-sortable.sort-asc::after { content: " \\25B2"; font-size: 9px; color: var(--brand); }
.tk-sortable.sort-desc::after { content: " \\25BC"; font-size: 9px; color: var(--brand); }

/* Wave column hide */
.wave-hidden { display: none !important; }

/* Sparklines */
.tk-sparkline { vertical-align: middle; }
body.hide-sparklines .tk-sparkline-wrap { display: none; }

/* Charts — additive selection */
.tk-chart-panel { padding: 16px 0; }
.tk-chart-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; padding: 8px 0; }
.tk-chart-count { font-size: 14px; font-weight: 600; color: var(--text); }
.tk-chart-header-actions { display: flex; gap: 8px; }
.tk-chart-container { margin-bottom: 32px; padding: 20px; background: var(--card); border-radius: 8px; border: 1px solid var(--border); }
.tk-chart-title { font-size: 15px; font-weight: 600; margin-bottom: 12px; color: var(--text); display: flex; align-items: center; gap: 8px; }
.tk-chart-remove-btn { background: none; border: 1px solid var(--border); border-radius: 50%; width: 22px; height: 22px; font-size: 14px; cursor: pointer; color: var(--text-muted); line-height: 1; }
.tk-chart-remove-btn:hover { background: #fee; color: #dc2626; border-color: #dc2626; }
.tk-chart-actions { margin-top: 12px; text-align: right; }
.tk-line-chart { max-width: 100%; height: auto; }
.tk-chart-point { cursor: pointer; }
.tk-add-chart-btn { background: none; border: 1px solid var(--border); border-radius: 4px; padding: 2px 6px; font-size: 11px; cursor: pointer; color: var(--text-muted); margin-left: 6px; transition: all 0.15s; }
.tk-add-chart-btn:hover { border-color: var(--brand); color: var(--brand); }
.tk-add-chart-btn.in-chart { background: var(--brand); color: #fff; border-color: var(--brand); }

/* Row filtered (type/text filter) */
.row-filtered { display: none !important; }

/* Latest wave highlight */
.tk-latest-wave { background: rgba(50,51,103,0.04); }

/* Sticky table headers */
.tk-table thead { position: sticky; top: 0; z-index: 10; }
.tk-table thead th { background: var(--card); }

/* Overview search input */
.tk-overview-search { width: 140px; padding: 5px 10px; border: 1px solid var(--border); border-radius: 6px; font-size: 12px; font-family: inherit; }
.tk-overview-type-filter { display: flex; gap: 4px; }

/* Segment column visibility */
.segment-hidden { display: none !important; }

/* Selected segment chip (for chart label focus) */
.tk-segment-chip.selected { box-shadow: 0 0 0 2px var(--chip-color, var(--brand)); }

/* Row hide eye icon (grey out instead of hide — click again to restore) */
.tk-row-hide-btn { background: none; border: none; cursor: pointer; font-size: 14px; padding: 0 4px; opacity: 0.3; transition: opacity 0.15s; line-height: 1; }
.tk-row-hide-btn:hover { opacity: 1; }
.tk-row-hide-btn.row-greyed { opacity: 1; color: #c0392b; }
.tk-metric-row.row-hidden-user { opacity: 0.25; }
.tk-metric-row.row-hidden-user td { background: #f5f5f5 !important; }
.tk-change-row.row-hidden-user { opacity: 0.25; }
.tk-change-row.row-hidden-user td { background: #f5f5f5 !important; }

/* Pinned toolbar */
.pinned-toolbar { display: flex; gap: 8px; padding: 16px 0; margin-bottom: 16px; border-bottom: 1px solid var(--border); flex-wrap: wrap; }
.pinned-toolbar .tk-btn { font-size: 13px; padding: 8px 16px; }

/* ---- INSIGHT STYLES ---- */
.insight-area { margin-top: 16px; }
.insight-toggle { padding: 6px 14px; border: 1px dashed #cbd5e1; border-radius: 6px; background: transparent; color: #94a3b8; font-size: 12px; font-weight: 500; cursor: pointer; width: 100%; text-align: left; font-family: inherit; }
.insight-toggle:hover { border-color: var(--brand); color: var(--brand); }
.insight-container { border: 1px solid var(--border); border-radius: 8px; background: #f8fafa; padding: 12px 16px; position: relative; }
.insight-editor { border-left: 3px solid var(--brand); background: #fefefe; padding: 12px 16px; font-size: 13px; line-height: 1.6; border-radius: 0 6px 6px 0; min-height: 50px; outline: none; color: var(--text); }
.insight-editor:empty::before { content: attr(data-placeholder); color: #aab; font-style: italic; }
.insight-dismiss { position: absolute; top: 8px; right: 8px; background: none; border: none; font-size: 20px; cursor: pointer; color: var(--text-muted); line-height: 1; }
.insight-dismiss:hover { color: #c0392b; }

/* ---- PINNED VIEWS ---- */
.pinned-tab-content { padding: 24px; max-width: 1000px; margin: 0 auto; }
.pinned-empty-state { text-align: center; padding: 60px 20px; color: var(--text-muted); font-size: 15px; }
.pinned-card { background: var(--card); border: 1px solid var(--border); border-radius: 10px; margin-bottom: 20px; overflow: hidden; }
.pinned-card-header { display: flex; justify-content: space-between; align-items: center; padding: 14px 20px; border-bottom: 1px solid var(--border); background: #f8f8fc; }
.pinned-card-title { font-size: 15px; font-weight: 700; color: var(--text); margin: 0; }
.pinned-card-actions { display: flex; gap: 6px; }
.pinned-card-chart { padding: 16px 20px; border-bottom: 1px solid var(--border); text-align: center; }
.pinned-card-chart svg { max-width: 100%; height: auto; }
.pinned-card-body { padding: 16px 20px; overflow-x: auto; }
.pinned-card-png { max-width: 100%; height: auto; border-radius: 4px; }
.pinned-card-insight { padding: 12px 20px; border-bottom: 1px solid var(--border); background: #f8fafa; border-left: 3px solid var(--brand); font-size: 13px; color: var(--text); }
.pinned-card-insight-area { padding: 8px 20px; border-bottom: 1px solid var(--border); }
.pinned-card-insight-editor { border-left: 3px solid var(--brand); background: #fefefe; padding: 8px 12px; font-size: 13px; line-height: 1.6; border-radius: 0 6px 6px 0; min-height: 36px; outline: none; color: var(--text); }
.pinned-card-insight-editor:empty::before { content: attr(data-placeholder); color: #aab; font-style: italic; }
.pinned-insight-toggle { padding: 4px 10px; border: 1px dashed #cbd5e1; border-radius: 4px; background: transparent; color: #94a3b8; font-size: 11px; cursor: pointer; width: 100%; text-align: left; font-family: inherit; }
.pinned-insight-toggle:hover { border-color: var(--brand); color: var(--brand); }
.pinned-card-meta { padding: 8px 20px; font-size: 11px; color: var(--text-muted); border-top: 1px solid #f0f0f0; }

/* ---- HELP OVERLAY ---- */
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

/* Print styles */
@media print {
  .tk-sidebar, .mv-sidebar, .tk-controls, .mv-controls, .tk-segment-tabs,
  .tk-chart-actions, .tk-help-overlay, .report-tabs, .mv-segment-chips,
  .insight-toggle, .insight-dismiss, .mv-pin-btn, .pinned-card-actions,
  .pinned-toolbar, .tk-segment-selector, .tk-row-hide-btn,
  .tk-tab-actions, .export-btn { display: none !important; }
  .tk-layout, .metrics-tab-layout { display: block; }
  .tk-content, .mv-content { padding: 0; }
  .tk-table-wrapper { border: none; overflow: visible; }
  .tk-sticky-col { position: static; }
  .tk-change-row.visible { display: table-row !important; }
  .tab-panel { display: block !important; page-break-before: always; }
  .tab-panel:first-child { page-break-before: auto; }
  .tk-header { padding: 8px 16px; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .tk-footer { position: fixed; bottom: 0; }
}

/* Print pinned views only (activated by JS class on body) */
@media print {
  body.print-pinned-only .tk-header, body.print-pinned-only .report-tabs,
  body.print-pinned-only .tab-panel:not(#tab-pinned),
  body.print-pinned-only .tk-footer { display: none !important; }
  body.print-pinned-only #tab-pinned { display: block !important; page-break-before: auto; }
  body.print-pinned-only .pinned-card { page-break-inside: avoid; margin-bottom: 24px; }
  body.print-pinned-only .pinned-card-chart svg { max-width: 100%; height: auto; }
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

  # Embed segment group structure for hierarchical chip selector
  segment_groups <- derive_segment_groups(html_data$segments)
  segment_groups_json <- jsonlite::toJSON(segment_groups, auto_unbox = TRUE)
  js_parts <- c(js_parts, sprintf("var SEGMENT_GROUPS = %s;", segment_groups_json))

  # Metric nav filter functions (inline, needed before JS files load)
  js_parts <- c(js_parts, '
var activeMetricTypeFilter = "all";

function filterMetricType(typeKey) {
  activeMetricTypeFilter = typeKey;
  document.querySelectorAll(".mv-type-chip").forEach(function(chip) {
    chip.classList.toggle("active", chip.getAttribute("data-type-filter") === typeKey);
  });
  applyMetricNavFilter();
}

function filterMetricNav(query) {
  window._metricSearchQuery = (query || "").toLowerCase();
  applyMetricNavFilter();
}

function applyMetricNavFilter() {
  var q = (window._metricSearchQuery || "").toLowerCase();
  var typeFilter = activeMetricTypeFilter || "all";

  document.querySelectorAll(".tk-metric-nav-item").forEach(function(item) {
    var textMatch = q === "" || item.textContent.toLowerCase().indexOf(q) >= 0;
    var typeMatch = typeFilter === "all" || item.getAttribute("data-metric-type") === typeFilter;
    item.style.display = (textMatch && typeMatch) ? "" : "none";
  });

  // Hide section headers with no visible items after them
  document.querySelectorAll(".mv-nav-section").forEach(function(section) {
    var next = section.nextElementSibling;
    var hasVisible = false;
    while (next && !next.classList.contains("mv-nav-section")) {
      if (next.classList.contains("tk-metric-nav-item") && next.style.display !== "none") {
        hasVisible = true;
        break;
      }
      next = next.nextElementSibling;
    }
    section.style.display = hasVisible ? "" : "none";
  });
}
')

  js_files <- c("tab_navigation.js", "metrics_view.js", "pinned_views.js",
                 "core_navigation.js", "chart_controls.js",
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
