# ==============================================================================
# TurasTracker HTML Report - Overview Heatmap Builder
# ==============================================================================
# Builds an interactive overview heatmap: questions (rows) x waves (columns)
# with colour-coded cells, sparklines, and delta chips.
# Spec reference: TURAS_TRACKER_REPORT_SPEC.md §4.1 (View 1)
# VERSION: 1.0.0
# ==============================================================================


#' Build Overview Heatmap Section
#'
#' Creates the interactive heatmap grid that replaces the summary metrics table.
#' Shows one metric per question, grouped by section, with colour intensity,
#' sparklines at row-end, and delta chips.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param config List. Tracker configuration
#' @return htmltools::HTML object
#' @export
build_overview_heatmap <- function(html_data, config) {

  waves <- html_data$waves
  wave_labels <- html_data$wave_labels
  segments <- html_data$segments
  n_waves <- length(waves)
  if (n_waves < 2 || length(html_data$metric_rows) == 0) {
    return(htmltools::tags$div())
  }

  latest_wave <- waves[n_waves]
  brand_colour <- get_setting(config, "brand_colour", default = "#323367") %||% "#323367"

  # ---- Read heatmap threshold settings ----
  hm_thresholds <- list(
    pct   = list(green = as.numeric(get_setting(config, "heatmap_pct_green",   default = "70")),
                 amber = as.numeric(get_setting(config, "heatmap_pct_amber",   default = "50"))),
    mean5 = list(green = as.numeric(get_setting(config, "heatmap_mean5_green", default = "4.0")),
                 amber = as.numeric(get_setting(config, "heatmap_mean5_amber", default = "3.0"))),
    mean10= list(green = as.numeric(get_setting(config, "heatmap_mean10_green",default = "7.0")),
                 amber = as.numeric(get_setting(config, "heatmap_mean10_amber",default = "5.0"))),
    nps   = list(green = as.numeric(get_setting(config, "heatmap_nps_green",   default = "30")),
                 amber = as.numeric(get_setting(config, "heatmap_nps_amber",   default = "0"))),
    pct_response = list(green = as.numeric(get_setting(config, "heatmap_response_green", default = "50")),
                        amber = as.numeric(get_setting(config, "heatmap_response_amber", default = "25")))
  )

  # Serialize thresholds as JSON for JS
  thresholds_json <- jsonlite::toJSON(hm_thresholds, auto_unbox = TRUE)

  # ---- Legend ----
  legend_html <- c(
    '<div class="hm-legend-toggle">',
    '<button class="hm-wave-action" onclick="var lg=document.getElementById(\'hm-scale-legend\');lg.style.display=lg.style.display===\'none\'?\'flex\':\'none\';this.textContent=lg.style.display===\'none\'?\'Show Legend\':\'Hide Legend\'">Hide Legend</button>',
    '</div>',
    '<div class="hm-legend" id="hm-scale-legend">',
    '<span class="hm-legend-title">Scale:</span>',
    sprintf('<span class="hm-legend-item"><span class="hm-legend-swatch hm-swatch-green"></span> %s+%% / %s+ mean / %s+ NPS</span>',
      hm_thresholds$pct$green, hm_thresholds$mean5$green, hm_thresholds$nps$green),
    sprintf('<span class="hm-legend-item"><span class="hm-legend-swatch hm-swatch-amber"></span> %s\u2013%s%% / %s\u2013%s mean / %s\u2013%s NPS</span>',
      hm_thresholds$pct$amber, hm_thresholds$pct$green,
      hm_thresholds$mean5$amber, hm_thresholds$mean5$green,
      hm_thresholds$nps$amber, hm_thresholds$nps$green),
    sprintf('<span class="hm-legend-item"><span class="hm-legend-swatch hm-swatch-red"></span> &lt;%s%% / &lt;%s mean / &lt;%s NPS</span>',
      hm_thresholds$pct$amber, hm_thresholds$mean5$amber, hm_thresholds$nps$amber),
    '<span class="hm-legend-item"><span class="hm-legend-swatch" style="background:rgba(37,99,171,0.25)"></span> %% Response (blue = magnitude)</span>',
    '</div>'
  )

  # ---- Banner selector ----
  banner_html <- c('<div class="hm-controls">')
  banner_html <- c(banner_html, '<div class="hm-control-group">')
  banner_html <- c(banner_html, '<label class="hm-control-label">Segment:</label>')
  banner_html <- c(banner_html, '<select class="hm-select" id="hm-banner-select" onchange="hmSwitchBanner(this.value)">')
  for (seg in segments) {
    banner_html <- c(banner_html, sprintf(
      '<option value="%s">%s</option>',
      htmltools::htmlEscape(seg), htmltools::htmlEscape(seg)
    ))
  }
  banner_html <- c(banner_html, '</select>')
  banner_html <- c(banner_html, '</div>')

  # ---- Value display mode ----
  banner_html <- c(banner_html, '<div class="hm-control-group">')
  banner_html <- c(banner_html, '<label class="hm-control-label">Display:</label>')
  banner_html <- c(banner_html, '<div class="hm-mode-chips">')
  banner_html <- c(banner_html, '<button class="hm-mode-chip active" data-mode="absolute" onclick="hmSwitchMode(\'absolute\')">Absolute</button>')
  banner_html <- c(banner_html, '<button class="hm-mode-chip" data-mode="vs-prev" onclick="hmSwitchMode(\'vs-prev\')">vs Previous</button>')
  banner_html <- c(banner_html, '<button class="hm-mode-chip" data-mode="vs-base" onclick="hmSwitchMode(\'vs-base\')">vs Baseline</button>')
  banner_html <- c(banner_html, '<span class="hm-mode-note" id="hm-mode-note" style="display:none;font-size:11px;color:#94a3b8;margin-left:8px;">Showing absolute change (pp for %%, points for means/NPS)</span>')
  banner_html <- c(banner_html, '</div>')
  banner_html <- c(banner_html, '</div>')

  # ---- Sort controls ----
  banner_html <- c(banner_html, '<div class="hm-control-group">')
  banner_html <- c(banner_html, '<label class="hm-control-label">Sort:</label>')
  banner_html <- c(banner_html, '<select class="hm-select" id="hm-sort-select" onchange="hmSort(this.value)">')
  banner_html <- c(banner_html, '<option value="original">Original Order</option>')
  banner_html <- c(banner_html, '<option value="value-desc">Current Value (High to Low)</option>')
  banner_html <- c(banner_html, '<option value="change-desc">Largest Change First</option>')
  banner_html <- c(banner_html, '</select>')
  banner_html <- c(banner_html, '</div>')

  # Export button for Mode A heatmap
  banner_html <- c(banner_html, '<div class="hm-control-group">')
  banner_html <- c(banner_html, '<button class="export-btn" onclick="exportSummaryExcel()">&#x2B73; Export Excel</button>')
  banner_html <- c(banner_html, '</div>')

  banner_html <- c(banner_html, '</div>')

  # ---- Wave chip bar ----
  # Show toggleable chips for each wave; default last 3 active
  wave_chip_html <- c('<div class="hm-wave-chips" id="hm-wave-chips">')
  wave_chip_html <- c(wave_chip_html, '<label class="hm-control-label" style="margin-right:6px;">Waves:</label>')
  default_active_start <- max(1, n_waves - 2)  # last 3 waves active by default
  for (w_idx in seq_along(waves)) {
    active_class <- if (w_idx >= default_active_start) " active" else ""
    wave_chip_html <- c(wave_chip_html, sprintf(
      '<button class="hm-wave-chip%s" data-wave="%s" onclick="hmToggleWave(\'%s\',this)">%s</button>',
      active_class,
      htmltools::htmlEscape(waves[w_idx]),
      htmltools::htmlEscape(waves[w_idx]),
      htmltools::htmlEscape(wave_labels[w_idx])
    ))
  }
  # Show All / Last 3 quick actions
  wave_chip_html <- c(wave_chip_html,
    '<span class="hm-wave-actions">',
    '<button class="hm-wave-action" onclick="hmWaveShowAll()">All</button>',
    sprintf('<button class="hm-wave-action" onclick="hmWaveShowLast(3)">Last 3</button>'),
    '</span>'
  )
  wave_chip_html <- c(wave_chip_html, '</div>')

  # ---- Build heatmap grid ----
  # Classify and order metrics by type group, then by section within type
  type_labels <- list(mean = "Means / Ratings", pct = "Percentages / Box Scores",
                       pct_response = "% Response", nps = "NPS", other = "Other")
  type_order <- c("mean", "pct", "pct_response", "nps", "other")

  metric_data_types <- vapply(html_data$metric_rows, function(mr) {
    if (!is.null(mr$data_type)) mr$data_type else classify_data_type(mr$metric_name)
  }, character(1))

  present_types <- unique(metric_data_types)
  present_types <- type_order[type_order %in% present_types]
  show_type_headers <- length(present_types) > 1

  grid_html <- c()
  grid_html <- c(grid_html, '<div class="hm-grid-wrap">')
  grid_html <- c(grid_html, '<table class="hm-table" id="hm-overview-table">')

  # Header row
  grid_html <- c(grid_html, '<thead><tr>')
  grid_html <- c(grid_html, '<th class="hm-th hm-label-col">Metric</th>')
  for (i in seq_len(n_waves)) {
    grid_html <- c(grid_html, sprintf(
      '<th class="hm-th hm-wave-col">%s</th>',
      htmltools::htmlEscape(wave_labels[i])
    ))
  }
  grid_html <- c(grid_html, '<th class="hm-th hm-spark-col">Trend</th>')
  grid_html <- c(grid_html, '<th class="hm-th hm-delta-col">Change</th>')
  grid_html <- c(grid_html, '</tr></thead>')

  grid_html <- c(grid_html, '<tbody>')

  for (type_key in present_types) {
    type_indices <- which(metric_data_types == type_key)
    if (length(type_indices) == 0) next

    # Type group header
    if (show_type_headers) {
      grid_html <- c(grid_html, sprintf(
        '<tr class="hm-type-header"><td colspan="%d">%s</td></tr>',
        n_waves + 3,
        htmltools::htmlEscape(type_labels[[type_key]] %||% type_key)
      ))
    }

    # Section tracking within type group
    current_section <- ""
    for (mi in type_indices) {
      mr <- html_data$metric_rows[[mi]]
      section <- if (is.null(mr$section) || is.na(mr$section) || mr$section == "") "" else mr$section

      # Section header within type group
      if (section != "" && section != current_section) {
        current_section <- section
        grid_html <- c(grid_html, sprintf(
          '<tr class="hm-section-header"><td colspan="%d">%s</td></tr>',
          n_waves + 3,
          htmltools::htmlEscape(section)
        ))
      }

      # Build the metric row with data for all segments embedded as JSON
      seg_name <- segments[1]  # Default to first segment (Total)
      cells <- mr$segment_cells[[seg_name]]

      # Collect all segment data for this metric (embedded as JSON for JS switching)
      all_seg_data <- list()
      for (seg in segments) {
        seg_cells <- mr$segment_cells[[seg]]
        if (is.null(seg_cells)) next
        seg_wave_data <- list()
        for (wid in waves) {
          cell <- seg_cells[[wid]]
          if (is.null(cell)) {
            seg_wave_data[[wid]] <- list(
              value = NA, display = "&mdash;",
              change_prev = NA, change_base = NA,
              sig_prev = NA, sig_base = NA, n = NA
            )
          } else {
            seg_wave_data[[wid]] <- list(
              value = if (is.null(cell$value) || is.na(cell$value)) NA else cell$value,
              display = cell$display_value,
              change_prev = if (is.null(cell$change_vs_prev) || is.na(cell$change_vs_prev)) NA else cell$change_vs_prev,
              change_base = if (is.null(cell$change_vs_base) || is.na(cell$change_vs_base)) NA else cell$change_vs_base,
              sig_prev = if (is.null(cell$sig_vs_prev)) NA else cell$sig_vs_prev,
              sig_base = if (is.null(cell$sig_vs_base)) NA else cell$sig_vs_base,
              n = if (is.null(cell$n) || is.na(cell$n)) NA else cell$n
            )
          }
        }
        all_seg_data[[seg]] <- seg_wave_data
      }

      seg_json <- jsonlite::toJSON(all_seg_data, auto_unbox = TRUE, na = "null", digits = 4)

      # Get latest value for initial delta chip
      latest_cell <- if (!is.null(cells)) cells[[latest_wave]] else NULL
      latest_val <- if (!is.null(latest_cell) && !is.null(latest_cell$value) && !is.na(latest_cell$value)) latest_cell$value else NA
      latest_change <- if (!is.null(latest_cell) && !is.null(latest_cell$change_vs_prev) && !is.na(latest_cell$change_vs_prev)) latest_cell$change_vs_prev else NA

      # Build sparkline from Total segment values
      spark_vals <- vapply(waves, function(wid) {
        cell <- if (!is.null(cells)) cells[[wid]] else NULL
        if (!is.null(cell) && !is.null(cell$value) && !is.na(cell$value)) cell$value else NA_real_
      }, numeric(1))
      sparkline_svg <- build_sparkline_svg(spark_vals, width = 80, height = 24, colour = brand_colour)

      # Delta chip
      delta_html <- ""
      if (!is.na(latest_change)) {
        delta_class <- if (latest_change > 0) "hm-delta-up" else if (latest_change < 0) "hm-delta-down" else "hm-delta-flat"
        is_pct <- grepl("(pct|box|range|proportion|category|any)", mr$metric_name)
        delta_display <- if (is_pct) {
          sprintf("%+.0fpp", latest_change)
        } else if (mr$metric_name %in% c("nps_score", "nps")) {
          sprintf("%+.0f", latest_change)
        } else {
          sprintf("%+.2f", latest_change)
        }
        # Add significance marker
        sig_marker <- ""
        if (!is.null(latest_cell$sig_vs_prev) && isTRUE(latest_cell$sig_vs_prev)) {
          sig_marker <- " *"
        }
        delta_html <- sprintf('<span class="hm-delta %s">%s%s</span>',
                               delta_class, delta_display, sig_marker)
      }

      # Emit the row
      grid_html <- c(grid_html, sprintf(
        '<tr class="hm-metric-row" data-metric-id="%s" data-metric-type="%s" data-metric-name="%s" data-seg-data=\'%s\' data-sort-order="%s" onclick="hmDrillDown(\'%s\')">',
        mr$metric_id, type_key, mr$metric_name,
        gsub("'", "&#39;", as.character(seg_json)),
        mr$sort_order %||% mi,
        mr$metric_id
      ))

      # Label cell
      grid_html <- c(grid_html, sprintf(
        '<td class="hm-td hm-label-col"><span class="hm-metric-label">%s</span></td>',
        htmltools::htmlEscape(mr$metric_label)
      ))

      # Value cells (default: absolute values for Total segment)
      for (wid in waves) {
        cell <- if (!is.null(cells)) cells[[wid]] else NULL
        val <- if (!is.null(cell) && !is.null(cell$value) && !is.na(cell$value)) cell$value else NA
        display <- if (!is.null(cell)) cell$display_value else "&mdash;"

        # Compute background colour using green/amber/red thresholds
        bg_style <- ""
        if (!is.na(val)) {
          bg_style <- heatmap_cell_style(val, type_key, brand_colour, hm_thresholds)
        }

        grid_html <- c(grid_html, sprintf(
          '<td class="hm-td hm-value-cell" data-wave="%s" data-value="%s" style="%s">%s</td>',
          wid,
          if (!is.na(val)) format(val, digits = 4) else "",
          bg_style,
          display
        ))
      }

      # Sparkline cell
      grid_html <- c(grid_html, sprintf(
        '<td class="hm-td hm-spark-cell">%s</td>', sparkline_svg
      ))

      # Delta chip cell
      grid_html <- c(grid_html, sprintf(
        '<td class="hm-td hm-delta-cell">%s</td>', delta_html
      ))

      grid_html <- c(grid_html, '</tr>')
    }
  }

  grid_html <- c(grid_html, '</tbody></table></div>')

  # Combine everything
  parts <- c(
    sprintf('<div class="hm-overview-section" data-thresholds=\'%s\'>',
            gsub("'", "&#39;", as.character(thresholds_json))),
    '<h3 class="summary-insight-title">Overview Heatmap</h3>',
    '<p class="dash-section-sub">Click any row to view detailed metrics. Cells are coloured green/amber/red by configurable thresholds.</p>',
    paste(legend_html, collapse = "\n"),
    paste(banner_html, collapse = "\n"),
    paste(wave_chip_html, collapse = "\n"),
    paste(grid_html, collapse = "\n"),
    '</div>'
  )

  htmltools::HTML(paste(parts, collapse = "\n"))
}


# ==============================================================================
# Explorer Data Blob Builder
# ==============================================================================

#' Build Master JSON Data Blob for Explorer Tab
#'
#' Serialises all metric/segment/wave data into a single JSON structure
#' that the Explorer JS module reads for Mode B (Segments for Question).
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param config List. Tracker configuration
#' @return Character. JSON string
#' @keywords internal
build_explorer_data_json <- function(html_data, config) {
  waves <- html_data$waves
  wave_labels <- html_data$wave_labels
  segments <- html_data$segments

  # Read thresholds (same as build_overview_heatmap)
  hm_thresholds <- list(
    pct    = list(green = as.numeric(get_setting(config, "heatmap_pct_green", default = "70")),
                  amber = as.numeric(get_setting(config, "heatmap_pct_amber", default = "50"))),
    mean5  = list(green = as.numeric(get_setting(config, "heatmap_mean5_green", default = "4.0")),
                  amber = as.numeric(get_setting(config, "heatmap_mean5_amber", default = "3.0"))),
    mean10 = list(green = as.numeric(get_setting(config, "heatmap_mean10_green", default = "7.0")),
                  amber = as.numeric(get_setting(config, "heatmap_mean10_amber", default = "5.0"))),
    nps    = list(green = as.numeric(get_setting(config, "heatmap_nps_green", default = "30")),
                  amber = as.numeric(get_setting(config, "heatmap_nps_amber", default = "0"))),
    pct_response = list(green = as.numeric(get_setting(config, "heatmap_response_green", default = "50")),
                        amber = as.numeric(get_setting(config, "heatmap_response_amber", default = "25")))
  )

  metrics_list <- lapply(seq_along(html_data$metric_rows), function(i) {
    mr <- html_data$metric_rows[[i]]
    type_key <- if (!is.null(mr$data_type)) mr$data_type else classify_data_type(mr$metric_name)

    # Build segment data
    seg_data <- list()
    for (seg in segments) {
      seg_cells <- mr$segment_cells[[seg]]
      if (is.null(seg_cells)) next
      wave_data <- list()
      for (wid in waves) {
        cell <- seg_cells[[wid]]
        if (is.null(cell)) {
          wave_data[[wid]] <- list(
            value = NA, display = "&mdash;",
            change_prev = NA, change_base = NA,
            sig_prev = FALSE, sig_base = FALSE, n = NA
          )
        } else {
          wave_data[[wid]] <- list(
            value = if (!is.null(cell$value) && !is.na(cell$value)) cell$value else NA,
            display = if (!is.null(cell$display_value)) cell$display_value else "&mdash;",
            change_prev = if (!is.null(cell$change_vs_prev) && !is.na(cell$change_vs_prev)) cell$change_vs_prev else NA,
            change_base = if (!is.null(cell$change_vs_base) && !is.na(cell$change_vs_base)) cell$change_vs_base else NA,
            sig_prev = isTRUE(cell$sig_vs_prev),
            sig_base = isTRUE(cell$sig_vs_base),
            n = if (!is.null(cell$n) && !is.na(cell$n)) cell$n else NA
          )
        }
      }
      seg_data[[seg]] <- wave_data
    }

    list(
      id = mr$metric_id,
      label = mr$metric_label,
      name = mr$metric_name,
      type = type_key,
      section = if (!is.null(mr$section) && !is.na(mr$section)) mr$section else "",
      sortOrder = if (!is.null(mr$sort_order)) mr$sort_order else i,
      data = seg_data
    )
  })

  blob <- list(
    waves = I(waves),            # I() forces JSON array even for length-1
    waveLabels = I(wave_labels),
    segments = I(segments),
    metrics = metrics_list,
    thresholds = hm_thresholds
  )

  jsonlite::toJSON(blob, auto_unbox = TRUE, na = "null", digits = 6)
}


# ==============================================================================
# Explorer Tab Builder
# ==============================================================================

#' Build Heatmap Explorer Tab
#'
#' Creates the Explorer tab panel containing Mode A (Questions for Segment,
#' relocated from Summary) and Mode B (Segments for Question, new).
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param config List. Tracker configuration
#' @return htmltools tag
#' @export
build_explorer_tab <- function(html_data, config) {

  # Type labels for metric dropdown grouping
  type_labels <- list(mean = "Means / Ratings", pct = "Percentages / Box Scores",
                       pct_response = "% Response", nps = "NPS", other = "Other")
  type_order <- c("mean", "pct", "pct_response", "nps", "other")

  # Build metric selector options grouped by type
  metric_options <- c()
  metric_data_types <- vapply(html_data$metric_rows, function(mr) {
    if (!is.null(mr$data_type)) mr$data_type else classify_data_type(mr$metric_name)
  }, character(1))

  present_types <- type_order[type_order %in% unique(metric_data_types)]
  first_metric_id <- NULL

  for (type_key in present_types) {
    type_indices <- which(metric_data_types == type_key)
    if (length(type_indices) == 0) next
    label <- type_labels[[type_key]] %||% type_key
    metric_options <- c(metric_options, sprintf('<optgroup label="%s">', htmltools::htmlEscape(label)))
    for (mi in type_indices) {
      mr <- html_data$metric_rows[[mi]]
      if (is.null(first_metric_id)) first_metric_id <- mr$metric_id
      metric_options <- c(metric_options, sprintf(
        '<option value="%s">%s</option>',
        htmltools::htmlEscape(mr$metric_id),
        htmltools::htmlEscape(mr$metric_label)
      ))
    }
    metric_options <- c(metric_options, '</optgroup>')
  }

  # Master data blob
  data_json <- build_explorer_data_json(html_data, config)

  # Heatmap callout (from shared registry)
  heatmap_callout <- if (exists("turas_callout", mode = "function")) {
    htmltools::HTML(turas_callout("tracker", "heatmap", collapsed = TRUE))
  }

  htmltools::tags$div(id = "tab-explorer", class = "tab-panel",
    style = "padding: 20px 24px;",

    heatmap_callout,

    # Mode toggle
    htmltools::tags$div(class = "explorer-mode-toggle",
      htmltools::tags$button(
        class = "explorer-mode-btn active",
        `data-mode` = "mode-a",
        onclick = "explorerSwitchMode('mode-a')",
        "Questions for Segment"
      ),
      htmltools::tags$button(
        class = "explorer-mode-btn",
        `data-mode` = "mode-b",
        onclick = "explorerSwitchMode('mode-b')",
        "Segments for Question"
      )
    ),

    # Mode A container — existing heatmap
    htmltools::tags$div(id = "explorer-mode-a",
      build_overview_heatmap(html_data, config)
    ),

    # Mode B container — JS-rendered
    htmltools::tags$div(id = "explorer-mode-b", style = "display:none",
      htmltools::tags$div(class = "hm-controls-bar",
        htmltools::tags$label(class = "hm-control-label",
          "Metric: ",
          htmltools::HTML(paste0(
            '<select class="hm-select" id="hm-b-metric-select" onchange="explorerSelectMetric(this.value)">',
            paste(metric_options, collapse = "\n"),
            '</select>'
          ))
        ),
        htmltools::tags$div(class = "hm-mode-chips",
          htmltools::tags$button(
            class = "hm-mode-chip active", `data-mode` = "absolute",
            onclick = "explorerBSwitchMode('absolute')", "Absolute"),
          htmltools::tags$button(
            class = "hm-mode-chip", `data-mode` = "vs-prev",
            onclick = "explorerBSwitchMode('vs-prev')", "vs Previous"),
          htmltools::tags$button(
            class = "hm-mode-chip", `data-mode` = "vs-base",
            onclick = "explorerBSwitchMode('vs-base')", "vs Baseline")
        ),
        htmltools::tags$label(class = "hm-control-label",
          "Sort: ",
          htmltools::HTML(
            '<select class="hm-select" id="hm-b-sort-select" onchange="explorerBSort(this.value)">
              <option value="original">Original Order</option>
              <option value="alpha">Alphabetical</option>
              <option value="value-desc">Value (High to Low)</option>
              <option value="change-desc">Largest Change First</option>
            </select>'
          )
        ),
        # Export button for Mode B
        htmltools::tags$button(class = "export-btn",
          onclick = "explorerExportExcel()",
          htmltools::HTML("&#x2B73; Export Excel"))
      ),
      htmltools::tags$div(id = "hm-b-table-container")
    ),

    # Selection bar (sticky bottom)
    htmltools::tags$div(class = "explorer-selection-bar",
      id = "explorer-selection-bar",
      style = "display:none",
      htmltools::tags$span(id = "explorer-selection-count", "0 selected"),
      htmltools::tags$button(class = "export-btn",
        style = "background:var(--brand);color:#fff;border-color:var(--brand);",
        onclick = "explorerVisualise()",
        htmltools::HTML("Visualise &#x2192;")),
      htmltools::tags$button(class = "export-btn",
        onclick = "explorerClearSelection()",
        "Clear")
    ),

    # Master data blob
    htmltools::HTML(sprintf(
      '<script type="application/json" id="hm-explorer-data">%s</script>',
      as.character(data_json)
    ))
  )
}


#' Generate Heatmap Cell Background Style (Green/Amber/Red)
#'
#' Computes an inline CSS background-color for a heatmap cell using
#' configurable green/amber/red thresholds. Values at or above the green
#' threshold get green, between amber and green get amber, below amber get red.
#'
#' @param val Numeric. The cell value
#' @param data_type Character. "mean", "pct", "nps", or "other"
#' @param brand_colour Character. Hex colour string (unused, kept for API compat)
#' @param thresholds List. Threshold settings with green/amber for each type
#' @return Character. CSS style string
#' @keywords internal
heatmap_cell_style <- function(val, data_type, brand_colour, thresholds = NULL) {
  # Default thresholds if not provided
  if (is.null(thresholds)) {
    thresholds <- list(
      pct    = list(green = 70, amber = 50),
      mean5  = list(green = 4.0, amber = 3.0),
      mean10 = list(green = 7.0, amber = 5.0),
      nps    = list(green = 30, amber = 0)
    )
  }

  # pct_response uses a blue sequential scale — descriptive proportions,

  # not evaluative metrics, so green/red "good/bad" is inappropriate
  if (data_type == "pct_response") {
    frac <- min(1, max(0, val / 100))
    opacity <- 0.06 + frac * 0.34
    return(sprintf("background:rgba(37,99,171,%.2f)", opacity))  # blue sequential
  }

  # Determine which threshold set to use for evaluative metrics
  if (data_type == "pct") {
    thr <- thresholds$pct
  } else if (data_type == "nps") {
    thr <- thresholds$nps
  } else if (data_type == "mean") {
    thr <- if (val <= 5.5) thresholds$mean5 else thresholds$mean10
  } else {
    # "other" — use brand colour fallback
    r <- strtoi(substr(brand_colour, 2, 3), 16)
    g <- strtoi(substr(brand_colour, 4, 5), 16)
    b <- strtoi(substr(brand_colour, 6, 7), 16)
    return(sprintf("background:rgba(%d,%d,%d,0.12)", r, g, b))
  }

  green_thr <- thr$green
  amber_thr <- thr$amber

  if (val >= green_thr) {
    # Green zone — stronger opacity for higher values
    range_above <- green_thr  # distance within green zone
    if (data_type == "pct") {
      frac <- min(1, (val - green_thr) / (100 - green_thr + 0.01))
    } else if (data_type == "nps") {
      frac <- min(1, (val - green_thr) / (100 - green_thr + 0.01))
    } else {
      scale_max <- if (val <= 5.5) 5 else 10
      frac <- min(1, (val - green_thr) / (scale_max - green_thr + 0.01))
    }
    opacity <- 0.12 + frac * 0.20
    return(sprintf("background:rgba(5,150,105,%.2f)", opacity))  # green
  } else if (val >= amber_thr) {
    # Amber zone
    frac <- min(1, (val - amber_thr) / (green_thr - amber_thr + 0.01))
    opacity <- 0.12 + (1 - frac) * 0.15  # darker at bottom of amber
    return(sprintf("background:rgba(217,159,42,%.2f)", opacity))  # amber/gold
  } else {
    # Red zone — stronger opacity for lower values
    if (data_type == "pct") {
      frac <- min(1, (amber_thr - val) / (amber_thr + 0.01))
    } else if (data_type == "nps") {
      frac <- min(1, (amber_thr - val) / (amber_thr + 100 + 0.01))
    } else {
      frac <- min(1, (amber_thr - val) / (amber_thr - 1 + 0.01))
    }
    opacity <- 0.12 + frac * 0.20
    return(sprintf("background:rgba(192,57,43,%.2f)", opacity))  # red
  }
}


#' Generate Diverging Heatmap Cell Style for Change Values
#'
#' @param change_val Numeric. The change value
#' @param is_sig Logical. Whether the change is significant
#' @return Character. CSS style string
#' @keywords internal
heatmap_change_style <- function(change_val, is_sig) {
  if (is.na(change_val)) return("")

  # Blue/coral-red diverging palette (matches JS changeCellStyle)
  if (change_val > 0) {
    r <- 37; g <- 99; b <- 171  # #2563ab blue
  } else if (change_val < 0) {
    r <- 200; g <- 70; b <- 55  # #c84637 coral-red
  } else {
    return("")
  }

  # Intensity based on magnitude — more striking range
  magnitude <- abs(change_val)
  intensity <- min(1, magnitude / 10)  # 10pp or 10 points = max intensity
  opacity <- 0.10 + intensity * 0.30
  if (isTRUE(is_sig)) opacity <- opacity + 0.12  # significant boost

  style <- sprintf("background:rgba(%d,%d,%d,%.2f)", r, g, b, opacity)
  # Significant changes get bold text + left accent border
  if (isTRUE(is_sig)) {
    style <- paste0(style, sprintf(";font-weight:700;border-left:3px solid rgba(%d,%d,%d,0.7)", r, g, b))
  }
  style
}
