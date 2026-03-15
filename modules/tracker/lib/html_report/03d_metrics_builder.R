# ==============================================================================
# TurasTracker HTML Report - Metrics by Segment Tab Builder
# ==============================================================================
# Builds the "Metrics by Segment" tab: sidebar navigation, per-metric
# panels with segment chips, wave chips, tables, charts, and insights.
# Extracted from 03_page_builder.R for maintainability.
# VERSION: 3.0.0
# ==============================================================================


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


#' Build Metrics by Segment Tab
#'
#' Assembles the complete Metrics by Segment tab with sidebar navigation,
#' metric type filter, global controls, and per-metric panels.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param charts List. Line chart SVGs from build_line_chart()
#' @param config List. Tracker configuration
#' @return htmltools tag
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
    ),
    htmltools::tags$main(class = "mv-content",
      # Sticky breadcrumb showing current metric context
      htmltools::tags$div(class = "mv-breadcrumb", id = "mv-breadcrumb",
        htmltools::tags$span("Metric:"),
        htmltools::tags$span(class = "mv-breadcrumb-metric", id = "mv-breadcrumb-metric", ""),
        htmltools::tags$span(class = "mv-breadcrumb-sep", "|"),
        htmltools::tags$span(id = "mv-breadcrumb-segments", "")
      ),
      # Comparison chart container (hidden until compare mode activated)
      htmltools::tags$div(id = "mv-comparison-chart", style = "display:none"),
      htmltools::HTML(metric_panels)
    )
  )
}


#' Build Metric Navigation List
#'
#' Groups metrics by section. Ungrouped metrics are placed at the bottom
#' of the list rather than at the top.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @return Character. HTML string for sidebar navigation
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
#'
#' Generates one panel per tracked metric, each containing segment chips,
#' wave chips, chart segment chips, controls, table, chart area, and insight.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param charts List. Line chart SVGs
#' @param config List. Tracker configuration
#' @param segments Character vector. Segment names
#' @param segment_colours Character vector. Colour per segment
#' @return Character. Combined HTML string for all metric panels
#' @keywords internal
build_metric_panels <- function(html_data, charts, config, segments, segment_colours) {

  brand_colour <- get_setting(config, "brand_colour", default = "#323367") %||% "#323367"
  min_base <- 30L
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
      '<div class="tk-metric-panel%s" id="mv-%s" data-metric-id="%s">',
      active_class, mr$metric_id, htmltools::htmlEscape(mr$metric_id)
    ))

    # Title — question text as prominent heading, metric label as subtitle context
    # Inspired by best-practice chart labelling: question as bold title, metric type below
    q_raw <- mr$question_text
    q_display <- ""
    if (!is.null(q_raw) && !is.na(q_raw) && nzchar(q_raw) && q_raw != "NA") {
      q_display <- q_raw
    } else if (!is.null(mr$question_type) && tolower(mr$question_type) == "composite") {
      q_display <- "Composite Metric"
    }

    if (nzchar(q_display) && q_display != mr$metric_label) {
      # Question text as bold title, metric_label as subtitle context
      panel_parts <- c(panel_parts, sprintf(
        '<h2 class="mv-metric-title">%s</h2><p class="mv-metric-subtitle">%s</p>',
        htmltools::htmlEscape(q_display),
        htmltools::htmlEscape(mr$metric_label)
      ))
    } else {
      # Just the metric label as title (no redundant subtitle)
      panel_parts <- c(panel_parts, sprintf(
        '<h2 class="mv-metric-title">%s</h2>',
        htmltools::htmlEscape(mr$metric_label)
      ))
    }

    # Segment chips — grouped by category (matching crosstab col-chip-bar)
    scroll_class <- if (length(segments) > 8) " mv-segment-chips-scrollable" else ""
    panel_parts <- c(panel_parts, sprintf('<div class="mv-segment-chips mv-segment-grouped%s">', scroll_class))
    panel_parts <- c(panel_parts, '<span class="mv-segment-chips-label">Segments:</span>')

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

    # "+ Segments" toggle (only if there are grouped segments)
    if (length(segment_group_info$groups) > 0) {
      panel_parts <- c(panel_parts,
        '<button class="mv-groups-toggle" onclick="toggleSegmentGroups(this)">+ Segments</button>'
      )
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

    # Chart segment chips (independent chart-only toggle, hidden until chart shown)
    panel_parts <- c(panel_parts, '<div class="mv-chart-segment-chips" style="display:none">')
    panel_parts <- c(panel_parts, '<span class="mv-wave-chips-label">Chart:</span>')
    for (s_idx in seq_along(segments)) {
      seg_name <- segments[s_idx]
      seg_colour <- segment_colours[s_idx]
      panel_parts <- c(panel_parts, sprintf(
        '<button class="tk-segment-chip active" data-segment="%s" style="--chip-color:%s" onclick="toggleChartSegment(\'%s\',\'%s\',this)">%s</button>',
        htmltools::htmlEscape(seg_name),
        seg_colour,
        mr$metric_id, htmltools::htmlEscape(seg_name),
        htmltools::htmlEscape(seg_name)
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
      '<button class="export-btn" onclick="exportMetricExcel(\'%s\')" title="Export to Excel">&#x2B73; Export Excel</button>',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, sprintf(
      '<button class="export-btn" onclick="copyChartToClipboard(\'%s\')" title="Copy chart to clipboard">&#x1F4CB; Copy Chart</button>',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, sprintf(
      '<button class="export-btn" onclick="pinMetricView(\'%s\')" title="Pin this view">&#x1F4CC; Pin</button>',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, sprintf(
      '<button class="export-btn" onclick="toggleSlideMenu(\'%s\')" title="Export as slide">&#x1F4F8; Export Slide &#x25BE;</button>',
      mr$metric_id
    ))

    # Slide export dropdown menu (hidden by default)
    panel_parts <- c(panel_parts, sprintf(
      '<div class="tk-slide-menu" id="slide-menu-%s" style="display:none">',
      mr$metric_id
    ))
    panel_parts <- c(panel_parts, sprintf(
      '<button class="tk-slide-menu-item" onclick="exportSlidePNG(\'%s\',\'chart\')">Chart Only</button>', mr$metric_id))
    panel_parts <- c(panel_parts, sprintf(
      '<button class="tk-slide-menu-item" onclick="exportSlidePNG(\'%s\',\'table\')">Table Only</button>', mr$metric_id))
    panel_parts <- c(panel_parts, sprintf(
      '<button class="tk-slide-menu-item" onclick="exportSlidePNG(\'%s\',\'both\')">Chart + Table</button>', mr$metric_id))
    panel_parts <- c(panel_parts, sprintf(
      '<button class="tk-slide-menu-item" onclick="exportSlidePNG(\'%s\',\'insight\')">Chart + Insight</button>', mr$metric_id))
    panel_parts <- c(panel_parts, '</div>')

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
#' @param mr List. Single metric row from html_data$metric_rows
#' @param html_data List. Output from transform_tracker_for_html()
#' @param sparkline_data List. Sparkline values per segment
#' @param segments Character vector. Segment names
#' @param segment_colours Character vector. Colour per segment
#' @param brand_colour Character. Brand colour hex
#' @param min_base Integer. Minimum base for low-base warnings
#' @return Character. HTML table string
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
        paste0(cell$display_value, cell$sig_badge), n_display
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
