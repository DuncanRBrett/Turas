# ==============================================================================
# TurasTracker HTML Report - Summary Tab Builder
# ==============================================================================
# Builds the Summary/Dashboard tab: KPI hero cards, wave pulse bar,
# significance heatmap, metrics overview table, and sig changes cards.
# Extracted from 03_page_builder.R for maintainability.
# VERSION: 3.0.0
# ==============================================================================


#' Build Summary Tab Content
#'
#' Assembles the full Summary tab with metadata strip, KPI hero cards,
#' wave pulse bar, significant changes, and metrics overview table.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param config List. Tracker configuration
#' @return htmltools tag
#' @keywords internal
build_summary_tab <- function(html_data, config) {

  project_name <- html_data$metadata$project_name %||% "Tracking Report"
  n_metrics <- html_data$n_metrics
  n_waves <- length(html_data$waves)
  n_segments <- length(html_data$segments)
  baseline_label <- html_data$wave_lookup[html_data$baseline_wave]
  latest_wave_id <- html_data$waves[n_waves]
  latest_wave_label <- html_data$wave_lookup[latest_wave_id]

  # Get latest wave sample size from first metric Total segment
  latest_n <- NA
  if (length(html_data$metric_rows) > 0) {
    total_seg <- html_data$segments[1]
    for (mr in html_data$metric_rows) {
      cell <- mr$segment_cells[[total_seg]][[latest_wave_id]]
      if (!is.null(cell) && !is.na(cell$n)) {
        latest_n <- cell$n
        break
      }
    }
  }

  # Fieldwork period (from config)
  fieldwork_start <- get_setting(config, "fieldwork_start", default = NULL)
  fieldwork_end <- get_setting(config, "fieldwork_end", default = NULL)
  fieldwork_text <- ""
  if (!is.null(fieldwork_start) && !is.null(fieldwork_end)) {
    fieldwork_text <- sprintf("%s \u2013 %s", fieldwork_start, fieldwork_end)
  }

  htmltools::tags$div(class = "summary-tab-content",

    # ---- 1. Metadata Strip (4 cards matching tabs dash-meta-strip) ----
    build_metadata_strip(n_metrics, n_waves, latest_n, fieldwork_text,
                          baseline_label, latest_wave_label),

    # ---- 2. Background & Method insight box ----
    htmltools::tags$div(class = "summary-insight-box", id = "summary-section-background",
      htmltools::tags$div(class = "summary-section-controls",
        htmltools::tags$button(class = "turas-action-btn",
          onclick = "pinSummarySection('background')",
          htmltools::HTML("&#x1F4CC; Pin to Views")),
        htmltools::tags$button(class = "turas-action-btn",
          onclick = "exportSummarySlide('background')",
          htmltools::HTML("&#x1F4F7; Export Slide"))
      ),
      htmltools::tags$h3(class = "summary-insight-title", "Background & Method"),
      htmltools::tags$div(
        class = "insight-editor summary-editor",
        contenteditable = "true",
        `data-placeholder` = "Add background and methodology notes here...",
        id = "summary-background-editor"
      )
    ),

    # ---- 3. Summary insight box ----
    htmltools::tags$div(class = "summary-insight-box", id = "summary-section-findings",
      htmltools::tags$div(class = "summary-section-controls",
        htmltools::tags$button(class = "turas-action-btn",
          onclick = "pinSummarySection('findings')",
          htmltools::HTML("&#x1F4CC; Pin to Views")),
        htmltools::tags$button(class = "turas-action-btn",
          onclick = "exportSummarySlide('findings')",
          htmltools::HTML("&#x1F4F7; Export Slide"))
      ),
      htmltools::tags$h3(class = "summary-insight-title", "Summary"),
      htmltools::tags$div(
        class = "insight-editor summary-editor",
        contenteditable = "true",
        `data-placeholder` = "Add key findings and summary here...",
        id = "summary-findings-editor"
      )
    ),

    # ---- 4. KPI Hero Cards with section header ----
    htmltools::tags$div(class = "summary-section-header",
      htmltools::tags$h3(class = "summary-section-title", "Key Metrics at a Glance"),
      htmltools::tags$p(class = "dash-section-sub",
        htmltools::HTML(sprintf(
          "Latest wave values (%s) with change vs previous wave. Border colour: <span style='color:#4a7c6f;font-weight:600'>green</span> = significant increase, <span style='color:#c9a96e;font-weight:600'>amber</span> = stable, <span style='color:#b85450;font-weight:600'>red</span> = significant decrease.",
          htmltools::htmlEscape(latest_wave_label)
        ))
      ),
      htmltools::tags$div(class = "kpi-card-controls",
        htmltools::tags$button(class = "turas-action-btn", onclick = "toggleAllKpiCards()",
          htmltools::HTML("&#x1F441; Show/Hide All")),
        htmltools::tags$button(class = "turas-action-btn", onclick = "pinVisibleKpiCards()",
          htmltools::HTML("&#x1F4CC; Pin Visible Cards"))
      )
    ),
    build_kpi_hero_cards(html_data, config),

    # ---- 5. Wave-over-Wave Pulse Bar ----
    build_wave_pulse_bar(html_data),

    # ---- 5b. Significant changes callout (from shared registry) ----
    if (exists("turas_callout", mode = "function")) {
      htmltools::HTML(turas_callout("tracker", "significant_changes", collapsed = TRUE))
    },

    # ---- 6. Significant Changes Section (collapsible, first 6 visible) ----
    build_sig_changes_section(html_data),

    # ---- 7. Significance Heatmap Matrix (collapsed by default) ----
    build_sig_heatmap(html_data, config)
  )
}


# ==============================================================================
# METADATA STRIP
# ==============================================================================

#' Build Metadata Strip
#'
#' Four-card metadata strip matching the tabs dash-meta-strip pattern.
#' Cards have brand-coloured left borders, large values, and uppercase labels.
#'
#' @param n_metrics Integer. Number of tracked metrics
#' @param n_waves Integer. Number of waves
#' @param latest_n Integer or NA. Sample size for latest wave
#' @param fieldwork_text Character. Fieldwork period text
#' @param baseline_label Character. Baseline wave label
#' @param latest_label Character. Latest wave label
#' @return htmltools tag
#' @keywords internal
build_metadata_strip <- function(n_metrics, n_waves, latest_n, fieldwork_text,
                                  baseline_label, latest_label) {

  n_display <- if (!is.na(latest_n)) formatC(latest_n, format = "d", big.mark = ",") else "\u2014"

  htmltools::tags$div(class = "tk-meta-strip",
    htmltools::tags$div(class = "tk-meta-card",
      htmltools::tags$div(class = "tk-meta-value", n_metrics),
      htmltools::tags$div(class = "tk-meta-label", "Metrics Tracked")
    ),
    htmltools::tags$div(class = "tk-meta-card",
      htmltools::tags$div(class = "tk-meta-value", n_waves),
      htmltools::tags$div(class = "tk-meta-label", "Waves")
    ),
    htmltools::tags$div(class = "tk-meta-card",
      htmltools::tags$div(class = "tk-meta-value", htmltools::HTML(sprintf("n=%s", n_display))),
      htmltools::tags$div(class = "tk-meta-label", sprintf("Latest (%s)", latest_label))
    ),
    htmltools::tags$div(class = "tk-meta-card",
      htmltools::tags$div(class = "tk-meta-value",
        if (nzchar(fieldwork_text)) fieldwork_text else sprintf("%s \u2192 %s", baseline_label, latest_label)),
      htmltools::tags$div(class = "tk-meta-label",
        if (nzchar(fieldwork_text)) "Fieldwork" else "Baseline \u2192 Latest")
    )
  )
}


# ==============================================================================
# KPI HERO CARDS
# ==============================================================================

#' Build KPI Hero Cards
#'
#' Large, prominent KPI summary cards showing latest value, trend direction,
#' change from previous wave, and mini sparkline for each tracked metric.
#' Provides the "5-second rule" executive overview.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param config List. Tracker configuration
#' @return htmltools tag
#' @keywords internal
build_kpi_hero_cards <- function(html_data, config) {

  if (length(html_data$metric_rows) == 0) return(htmltools::tags$div())

  total_seg <- html_data$segments[1]
  waves <- html_data$waves
  n_waves <- length(waves)
  latest_wave <- waves[n_waves]
  prev_wave <- if (n_waves >= 2) waves[n_waves - 1] else NULL
  brand_colour <- get_setting(config, "brand_colour", default = "#323367") %||% "#323367"

  # Filter to hero metrics if configured
  hero_filter <- get_setting(config, "dashboard_hero_metrics", default = NULL)
  hero_metric_ids <- NULL
  if (!is.null(hero_filter) && nzchar(hero_filter)) {
    hero_metric_ids <- trimws(strsplit(hero_filter, ",")[[1]])
  }

  # Classify metrics by type for grouping
  type_labels <- list(mean = "Means / Ratings", pct = "Percentages / Box Scores",
                       nps = "NPS", other = "Other")
  type_order <- c("mean", "pct", "nps", "other")

  # Build card data with type info
  card_list <- list()
  for (mr in html_data$metric_rows) {
    if (!is.null(hero_metric_ids) && !(mr$metric_id %in% hero_metric_ids)) next

    cells <- mr$segment_cells[[total_seg]]
    if (is.null(cells)) next
    latest_cell <- cells[[latest_wave]]
    if (is.null(latest_cell)) next

    m_type <- if (!is.null(mr$data_type)) mr$data_type else classify_data_type(mr$metric_name)
    current_val <- latest_cell$display_value
    is_pct <- grepl("(pct|box|range|proportion|category|any)", mr$metric_name)

    # Change from previous wave
    change_html <- ""
    change_num <- 0
    is_positive <- FALSE
    is_negative <- FALSE
    if (!is.null(prev_wave)) {
      if (!is.null(latest_cell$change_vs_prev) && !is.na(latest_cell$change_vs_prev)) {
        change_num <- latest_cell$change_vs_prev
        is_sig <- isTRUE(latest_cell$sig_vs_prev)

        if (change_num > 0) {
          is_positive <- TRUE
          arrow <- "\u25B2"
          change_text <- if (is_pct) sprintf("+%.1f pp", change_num) else sprintf("+%.2f", change_num)
        } else if (change_num < 0) {
          is_negative <- TRUE
          arrow <- "\u25BC"
          change_text <- if (is_pct) sprintf("%.1f pp", change_num) else sprintf("%.2f", change_num)
        } else {
          arrow <- "\u2192"
          change_text <- "No change"
        }

        trend_class <- if (is_positive) "tk-hero-trend-up" else if (is_negative) "tk-hero-trend-down" else "tk-hero-trend-stable"
        sig_badge <- if (is_sig) '<span class="tk-hero-sig">*</span>' else ""
        change_html <- sprintf(
          '<div class="%s"><span class="tk-hero-arrow">%s</span> %s%s</div>',
          trend_class, arrow, htmltools::htmlEscape(change_text), sig_badge
        )
      }
    }

    # Mini sparkline
    sparkline_svg <- ""
    sparkline_vals <- vapply(waves, function(wid) {
      cell <- cells[[wid]]
      if (!is.null(cell) && !is.na(cell$value)) cell$value else NA_real_
    }, numeric(1))
    if (sum(!is.na(sparkline_vals)) >= 2) {
      sparkline_svg <- build_sparkline_svg(sparkline_vals, width = 80, height = 24, colour = brand_colour)
    }

    # Traffic light border colour — based on TREND direction
    border_colour <- "#c9a96e"  # default: amber/stable
    if (!is.null(prev_wave)) {
      if (!is.null(latest_cell$change_vs_prev) && !is.na(latest_cell$change_vs_prev)) {
        is_sig <- isTRUE(latest_cell$sig_vs_prev)
        if (is_sig && latest_cell$change_vs_prev > 0) {
          border_colour <- "#4a7c6f"
        } else if (is_sig && latest_cell$change_vs_prev < 0) {
          border_colour <- "#b85450"
        }
      }
    }

    # Value colour: reflect direction (not always brand colour)
    value_colour_class <- if (is_positive) "tk-hero-val-up" else if (is_negative) "tk-hero-val-down" else "tk-hero-val-neutral"

    card_list <- c(card_list, list(list(
      type = m_type,
      metric_id = mr$metric_id,
      card = htmltools::tags$div(class = paste("tk-hero-card", "kpi-card-item"),
        `data-metric-type` = m_type,
        `data-metric-id` = mr$metric_id,
        style = sprintf("border-left-color: %s", border_colour),
        htmltools::tags$div(class = "kpi-card-header",
          htmltools::tags$div(class = "tk-hero-label", mr$metric_label),
          htmltools::tags$button(class = "kpi-card-hide-btn", title = "Hide card",
            onclick = sprintf("hideKpiCard('%s')", mr$metric_id),
            htmltools::HTML("&times;"))
        ),
        htmltools::tags$div(class = "tk-hero-body",
          htmltools::tags$div(class = paste("tk-hero-value", value_colour_class),
            htmltools::HTML(current_val)),
          htmltools::HTML(change_html)
        ),
        htmltools::tags$div(class = "tk-hero-sparkline", htmltools::HTML(sparkline_svg))
      )
    )))
  }

  if (length(card_list) == 0) return(htmltools::tags$div())

  # Group by type
  present_types <- unique(vapply(card_list, function(c) c$type, character(1)))
  present_types <- type_order[type_order %in% present_types]
  show_headers <- length(present_types) > 1

  groups <- list()
  for (type_key in present_types) {
    type_cards <- Filter(function(c) c$type == type_key, card_list)
    type_cards_tags <- lapply(type_cards, function(c) c$card)

    if (show_headers) {
      groups <- c(groups, list(
        htmltools::tags$div(class = "kpi-type-group",
          htmltools::tags$div(class = "kpi-type-header",
            onclick = "toggleKpiTypeGroup(this)",
            style = "cursor:pointer;",
            htmltools::tags$span(class = "kpi-type-chevron",
              htmltools::HTML("&#x25BC;")),
            type_labels[[type_key]] %||% type_key),
          htmltools::tags$div(class = "tk-hero-strip", type_cards_tags)
        )
      ))
    } else {
      groups <- c(groups, list(
        htmltools::tags$div(class = "tk-hero-strip", type_cards_tags)
      ))
    }
  }

  htmltools::tags$div(class = "kpi-hero-section", id = "kpi-hero-section", groups)
}


# ==============================================================================
# WAVE-OVER-WAVE PULSE BAR
# ==============================================================================

#' Build Wave-over-Wave Pulse Bar
#'
#' A compact horizontal strip summarising the latest wave transition.
#' Shows counts of significant increases, decreases, and stable metrics
#' for instant executive "pulse check".
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @return htmltools tag
#' @keywords internal
build_wave_pulse_bar <- function(html_data) {

  waves <- html_data$waves
  n_waves <- length(waves)
  if (n_waves < 2) return(htmltools::tags$div())

  latest_wave <- waves[n_waves]
  prev_wave <- waves[n_waves - 1]
  latest_label <- html_data$wave_lookup[latest_wave]
  prev_label <- html_data$wave_lookup[prev_wave]

  # Count significant changes across Total segment (or all segments)
  sig_up <- 0L
  sig_down <- 0L
  stable <- 0L
  total_metrics <- 0L

  total_seg <- html_data$segments[1]
  for (mr in html_data$metric_rows) {
    cells <- mr$segment_cells[[total_seg]]
    if (is.null(cells)) next
    cell <- cells[[latest_wave]]
    if (is.null(cell)) next
    total_metrics <- total_metrics + 1L

    if (isTRUE(cell$sig_vs_prev) && !is.null(cell$change_vs_prev) && !is.na(cell$change_vs_prev)) {
      if (cell$change_vs_prev > 0) sig_up <- sig_up + 1L
      else sig_down <- sig_down + 1L
    } else {
      stable <- stable + 1L
    }
  }

  htmltools::tags$div(class = "tk-pulse-bar",
    htmltools::tags$div(class = "tk-pulse-label",
      htmltools::HTML(sprintf("%s &rarr; %s",
        htmltools::htmlEscape(prev_label),
        htmltools::htmlEscape(latest_label)
      ))
    ),
    if (sig_up > 0) {
      htmltools::tags$span(class = "tk-pulse-badge tk-pulse-up",
        sprintf("\u25B2 %d significant increase%s", sig_up, if (sig_up > 1) "s" else ""))
    },
    if (sig_down > 0) {
      htmltools::tags$span(class = "tk-pulse-badge tk-pulse-down",
        sprintf("\u25BC %d significant decrease%s", sig_down, if (sig_down > 1) "s" else ""))
    },
    htmltools::tags$span(class = "tk-pulse-badge tk-pulse-stable",
      sprintf("%d stable", stable))
  )
}


# ==============================================================================
# SIGNIFICANCE HEATMAP MATRIX
# ==============================================================================

#' Build Significance Heatmap Matrix
#'
#' A compact grid showing metrics (rows) x segments (columns), with cells
#' colour-coded by the direction and significance of the latest wave change.
#' Provides "at a glance" pattern spotting for executives.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param config List. Tracker configuration
#' @return htmltools tag or empty div if single wave
#' @keywords internal
build_sig_heatmap <- function(html_data, config) {

  waves <- html_data$waves
  n_waves <- length(waves)
  if (n_waves < 2) return(htmltools::tags$div())

  latest_wave <- waves[n_waves]
  segments <- html_data$segments

  # Build matrix: rows = metrics, cols = segments
  parts <- c()
  parts <- c(parts, '<div class="tk-heatmap-section">')
  parts <- c(parts, '<div class="summary-collapse-header collapsed" onclick="toggleSummarySection(\'heatmap\')">')
  parts <- c(parts, '<span class="section-chevron">&#x25B6;</span>')
  parts <- c(parts, '<h3 class="summary-insight-title" style="margin:0;display:inline">Significance Matrix</h3>')
  parts <- c(parts, '<span class="summary-collapse-hint">Click to expand</span>')
  parts <- c(parts, '</div>')
  parts <- c(parts, '<div class="summary-collapse-body collapsed" id="summary-section-heatmap">')
  parts <- c(parts, '<div class="tk-sig-matrix-controls">')
  parts <- c(parts, '<p class="dash-section-sub" style="margin:0">Latest wave change direction by metric and segment. Green = significant increase, Red = significant decrease, Grey = no significant change.</p>')
  parts <- c(parts, '<button class="turas-action-btn" onclick="exportSigMatrixExcel()">&#x1F4E5; Export to Excel</button>')
  parts <- c(parts, '</div>')
  parts <- c(parts, '<div class="tk-heatmap-wrap">')
  parts <- c(parts, '<table class="tk-table tk-heatmap-table">')

  # Header
  parts <- c(parts, '<thead><tr>')
  parts <- c(parts, '<th class="tk-th tk-label-col tk-sticky-col">Metric</th>')
  for (seg in segments) {
    # Truncate long segment names for header
    display <- if (nchar(seg) > 20) paste0(substr(seg, 1, 18), "\u2026") else seg
    parts <- c(parts, sprintf('<th class="tk-th" title="%s">%s</th>',
      htmltools::htmlEscape(seg), htmltools::htmlEscape(display)))
  }
  parts <- c(parts, '</tr></thead>')

  # Body — group rows by data type for visual separation
  # Classify each metric into type groups
  type_labels <- list(mean = "Means / Ratings", pct = "Percentages / Box Scores",
                       nps = "NPS", other = "Other")
  classify_hm_type <- function(metric_name) {
    if (metric_name %in% c("nps_score", "nps", "promoters_pct", "passives_pct", "detractors_pct")) return("nps")
    if (grepl("(pct|box|range|proportion|category|any)", metric_name)) return("pct")
    if (metric_name == "mean" || grepl("(mean|index|composite)", metric_name)) return("mean")
    "other"
  }

  # Build ordered list of type groups present
  type_order <- c("mean", "pct", "nps", "other")
  metric_types <- vapply(html_data$metric_rows, function(mr) classify_hm_type(mr$metric_name), character(1))
  present_types <- unique(metric_types)
  present_types <- type_order[type_order %in% present_types]
  show_type_headers <- length(present_types) > 1  # only show headers if multiple types

  parts <- c(parts, '<tbody>')
  for (type_key in present_types) {
    type_indices <- which(metric_types == type_key)
    if (length(type_indices) == 0) next

    # Insert type group header row if multiple types present
    if (show_type_headers) {
      parts <- c(parts, sprintf(
        '<tr class="tk-heatmap-type-header"><td class="tk-td" colspan="%d" style="background:#f8fafc;font-weight:600;font-size:12px;color:#475569;text-transform:uppercase;letter-spacing:0.04em;padding:10px 12px 6px;">%s</td></tr>',
        length(segments) + 1,
        htmltools::htmlEscape(type_labels[[type_key]] %||% type_key)
      ))
    }

    for (mi in type_indices) {
      mr <- html_data$metric_rows[[mi]]

    parts <- c(parts, '<tr class="tk-heatmap-row">')
    parts <- c(parts, sprintf(
      '<td class="tk-td tk-label-col tk-sticky-col">%s</td>',
      htmltools::htmlEscape(mr$metric_label)
    ))

    is_pct <- grepl("(pct|box|range|proportion|category|any)", mr$metric_name)

    for (seg in segments) {
      cells <- mr$segment_cells[[seg]]
      cell <- if (!is.null(cells)) cells[[latest_wave]] else NULL

      if (is.null(cell) || is.null(cell$change_vs_prev) || is.na(cell$change_vs_prev)) {
        # No data
        parts <- c(parts, '<td class="tk-td tk-heatmap-cell tk-heatmap-na">&mdash;</td>')
      } else {
        # Format the change value (not the raw value)
        change_val <- cell$change_vs_prev
        if (is_pct) {
          change_display <- sprintf("%+.1f pp", change_val)
        } else {
          change_display <- sprintf("%+.2f", change_val)
        }

        if (isTRUE(cell$sig_vs_prev) && change_val > 0) {
          # Significant increase
          parts <- c(parts, sprintf(
            '<td class="tk-td tk-heatmap-cell tk-heatmap-up" title="%s &rarr; %s (significant increase)">%s</td>',
            htmltools::htmlEscape(cell$display_value),
            htmltools::htmlEscape(change_display),
            htmltools::htmlEscape(change_display)
          ))
        } else if (isTRUE(cell$sig_vs_prev) && change_val < 0) {
          # Significant decrease
          parts <- c(parts, sprintf(
            '<td class="tk-td tk-heatmap-cell tk-heatmap-down" title="%s &rarr; %s (significant decrease)">%s</td>',
            htmltools::htmlEscape(cell$display_value),
            htmltools::htmlEscape(change_display),
            htmltools::htmlEscape(change_display)
          ))
        } else {
          # No significant change
          parts <- c(parts, sprintf(
            '<td class="tk-td tk-heatmap-cell tk-heatmap-stable" title="%s (no significant change)">%s</td>',
            htmltools::htmlEscape(cell$display_value),
            htmltools::htmlEscape(change_display)
          ))
        }
      }
    }
    parts <- c(parts, '</tr>')
    }  # end for mi in type_indices
  }  # end for type_key in present_types

  parts <- c(parts, '</tbody></table></div>')
  parts <- c(parts, '</div>')  # close summary-collapse-body
  parts <- c(parts, '</div>')  # close tk-heatmap-section
  htmltools::HTML(paste(parts, collapse = "\n"))
}


# ==============================================================================
# SIGNIFICANT CHANGES SECTION
# ==============================================================================

#' Build Significant Changes Section
#'
#' Scans all metrics x segments for the latest wave and shows cards
#' for any statistically significant wave-on-wave changes.
#' Matches crosstabs "Significant Findings" pattern.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @return htmltools tag or NULL if no significant changes
#' @keywords internal
build_sig_changes_section <- function(html_data) {

  latest_wave <- html_data$waves[length(html_data$waves)]
  prev_wave <- if (length(html_data$waves) >= 2) html_data$waves[length(html_data$waves) - 1] else NULL
  latest_label <- html_data$wave_lookup[latest_wave]
  prev_label <- if (!is.null(prev_wave)) html_data$wave_lookup[prev_wave] else ""

  findings <- list()

  for (mr in html_data$metric_rows) {
    for (seg_name in names(mr$segment_cells)) {
      cells <- mr$segment_cells[[seg_name]]
      cell <- cells[[latest_wave]]
      if (is.null(cell)) next
      if (is.null(cell$sig_vs_prev) || is.na(cell$sig_vs_prev) || !isTRUE(cell$sig_vs_prev)) next
      if (is.null(cell$change_vs_prev) || is.na(cell$change_vs_prev)) next

      direction <- if (cell$change_vs_prev > 0) "up" else "down"
      direction_label <- if (direction == "up") "increase" else "decrease"
      direction_symbol <- if (direction == "up") "\u25B2" else "\u25BC"

      # Get previous wave value for context
      prev_cell <- cells[[prev_wave]]
      prev_display <- if (!is.null(prev_cell)) prev_cell$display_value else ""

      # Format the raw numeric change as plain text (not HTML)
      change_num <- cell$change_vs_prev
      is_pct <- grepl("(pct|box|range|proportion|category|any)", mr$metric_name)
      change_text <- if (is_pct) {
        sprintf("%+.1f pp", change_num)
      } else {
        sprintf("%+.2f", change_num)
      }

      findings[[length(findings) + 1]] <- list(
        metric_label = mr$metric_label,
        section = if (!is.null(mr$section) && !is.na(mr$section) && nzchar(mr$section)) mr$section else "",
        segment = seg_name,
        direction = direction,
        direction_label = direction_label,
        direction_symbol = direction_symbol,
        current_value = cell$display_value,
        prev_value = prev_display,
        change = change_text
      )
    }
  }

  # Empty state: show message instead of hiding section entirely
  if (length(findings) == 0) {
    return(htmltools::tags$div(class = "dash-section", id = "summary-section-sig-changes",
      htmltools::tags$div(class = "dash-section-title", "Significant Changes"),
      htmltools::tags$div(class = "dash-section-sub",
        "Wave-on-wave changes that are statistically significant"
      ),
      htmltools::tags$div(class = "dash-sig-empty",
        "There are no significant findings"
      )
    ))
  }

  # Sort: increases first, then decreases
  findings <- findings[order(
    sapply(findings, function(f) if (f$direction == "up") 0 else 1),
    sapply(findings, function(f) f$metric_label)
  )]

  # Collect unique segments for filter dropdown
  sig_segments <- unique(sapply(findings, function(f) f$segment))

  cards <- lapply(seq_along(findings), function(i) {
    f <- findings[[i]]
    border_colour <- if (f$direction == "up") "#059669" else "#c0392b"
    sig_class <- paste0("tk-sig tk-sig-", f$direction)

    sig_id <- sprintf("sig-%s-%s-%d",
      gsub("[^a-zA-Z0-9]", "", f$metric_label %||% ""),
      gsub("[^a-zA-Z0-9]", "", f$segment %||% ""), i)

    htmltools::tags$div(
      class = "dash-sig-card",
      `data-sig-id` = sig_id,
      `data-segment` = f$segment,
      style = sprintf("border-left-color: %s", border_colour),
      # Action bar: toggle + pin
      htmltools::tags$div(
        class = "sig-card-actions",
        htmltools::tags$button(
          class = "sig-card-toggle-btn",
          title = "Toggle visibility",
          onclick = sprintf("toggleSigCard('%s')", sig_id),
          htmltools::HTML("&#x1F441;")
        ),
        htmltools::tags$button(
          class = "sig-card-pin-btn",
          title = "Pin to Views",
          onclick = sprintf("pinSigCard('%s')", sig_id),
          htmltools::HTML("&#x1F4CC;")
        )
      ),
      htmltools::tags$div(
        class = "sig-card-content",
        htmltools::tags$div(
          class = "dash-sig-badges",
          htmltools::tags$span(class = "dash-sig-metric-badge", f$metric_label),
          if (nzchar(f$section)) htmltools::tags$span(class = "dash-sig-group-badge", f$section),
          htmltools::tags$span(class = "dash-sig-segment-badge", f$segment)
        ),
        htmltools::tags$div(class = "dash-sig-text",
          htmltools::tags$span(class = sig_class, f$direction_symbol),
          sprintf(" Significant %s: %s \u2192 %s (%s)",
            f$direction_label, f$prev_value, f$current_value, f$change
          )
        )
      )
    )
  })

  # Build segment filter dropdown — include ALL segments (Total + banners), not just those with findings
  all_segments <- names(html_data$metric_rows[[1]]$segment_cells)
  seg_filter_options <- list(
    htmltools::tags$option(value = "all", "All Segments")
  )
  for (seg in all_segments) {
    seg_filter_options <- c(seg_filter_options, list(
      htmltools::tags$option(value = seg, seg)
    ))
  }

  htmltools::tags$div(class = "dash-section", id = "summary-section-sig-changes",
    htmltools::tags$div(class = "summary-section-controls",
      htmltools::tags$button(
        class = "turas-action-btn",
        onclick = "pinVisibleSigFindings()",
        htmltools::HTML("&#x1F4CC; Pin All Visible")
      ),
      htmltools::tags$button(
        class = "turas-action-btn",
        onclick = "exportSummarySlide('sig-changes')",
        htmltools::HTML("&#x1F4F7; Export Slide")
      )
    ),
    htmltools::tags$div(class = "dash-section-title", "Significant Changes"),
    htmltools::tags$div(class = "dash-section-sub",
      sprintf("Wave-on-wave changes that are statistically significant (%s vs %s). Click the eye to hide, pin to save individual findings.",
        latest_label, prev_label)
    ),
    # Segment filter (always shown)
    htmltools::tags$div(class = "sig-segment-filter",
      htmltools::tags$label(class = "hm-control-label", "Filter by Segment:"),
      htmltools::tags$select(class = "hm-select", id = "sig-segment-filter",
        onchange = "filterSigBySegment(this.value)",
        seg_filter_options
      )
    ),
    # Empty state message (hidden by default, shown by JS when filter yields no results)
    htmltools::tags$div(class = "dash-sig-empty sig-filter-empty", id = "sig-filter-empty",
      style = "display:none",
      "No significant changes for this segment"
    ),
    if (length(findings) > 6) {
      htmltools::tags$div(class = "dash-sig-grid sig-cards-collapsed", id = "sig-cards-grid", cards)
    } else {
      htmltools::tags$div(class = "dash-sig-grid", id = "sig-cards-grid", cards)
    },
    if (length(findings) > 6) {
      htmltools::tags$button(
        class = "sig-show-more", id = "sig-show-more-btn",
        onclick = "toggleSigCards()",
        sprintf("Show all %d findings", length(findings))
      )
    },
    htmltools::tags$script(type = "application/json", id = "sig-card-states", "{}")
  )
}


# ==============================================================================
# SUMMARY METRICS TABLE
# ==============================================================================

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
#' @param min_base Integer. Minimum base for low-base warnings
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
