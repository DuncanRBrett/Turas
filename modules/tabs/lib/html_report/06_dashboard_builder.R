# ==============================================================================
# HTML REPORT - DASHBOARD BUILDER (V10.4.3)
# ==============================================================================
# Builds the summary dashboard HTML components: metadata strip, gauges,
# heatmap grid (with Excel export), and significance findings cards.
#
# V10.4.3 Changes:
#   - Sig findings resolve letter codes to column names + values
#     (e.g., "sig. higher than Cape Town (+42)" instead of "sig. higher than B")
#   - Banner group display labels (e.g., "Campus") instead of Q codes ("Q002")
#   - Full question text with CSS wrapping — no more truncation
#
# V10.4.2 Changes:
#   - Configurable colour breaks via Settings sheet
#   - Configurable scale for Mean and Index (0-10 or 0-100 etc.)
#   - build_colour_thresholds() creates threshold object from config
#   - All colour helpers now accept thresholds parameter
#   - Colour legend shows actual configured thresholds
#   - Sig findings show column value vs Total for context
#
# V10.4.1 Changes:
#   - Multi-section rendering: each metric type gets own gauges + heatmap
#   - Removed banner chips from gauge cards (Total value only)
#   - Added Excel export button per heatmap grid
#   - Sig findings now show question text
#   - Custom metric type support (e.g., "Good or excellent")
#
# All CSS is contained in build_dashboard_css().
# Uses htmltools for structure, gsub for variable injection.
# ==============================================================================


# ==============================================================================
# COLOUR THRESHOLDS (built once from config, passed everywhere)
# ==============================================================================

#' Build Colour Thresholds from Config
#'
#' Reads dashboard_scale_*, dashboard_green_*, dashboard_amber_* from config
#' and builds a structured thresholds list. Defaults are sensible so existing
#' configs work without changes.
#'
#' @param config_obj Configuration object from build_config_object()
#' @return List with net, mean, index, custom sub-lists (each: green, amber, scale)
#' @keywords internal
build_colour_thresholds <- function(config_obj) {
  list(
    net = list(
      green = config_obj$dashboard_green_net %||% 30,
      amber = config_obj$dashboard_amber_net %||% 0,
      scale = 200  # NET/NPS is always -100 to +100
    ),
    mean = list(
      green = config_obj$dashboard_green_mean %||% 7,
      amber = config_obj$dashboard_amber_mean %||% 5,
      scale = config_obj$dashboard_scale_mean %||% 10
    ),
    index = list(
      green = config_obj$dashboard_green_index %||% 7,
      amber = config_obj$dashboard_amber_index %||% 5,
      scale = config_obj$dashboard_scale_index %||% 10
    ),
    custom = list(
      green = config_obj$dashboard_green_custom %||% 60,
      amber = config_obj$dashboard_amber_custom %||% 40,
      scale = 100  # Custom labels are always percentages
    )
  )
}


#' Get Thresholds for a Specific Metric Type
#'
#' Maps metric_type string to the correct threshold sub-list.
#'
#' @param metric_type Character: "net_positive", "nps_score", "average",
#'        "index", "custom"
#' @param thresholds List from build_colour_thresholds()
#' @return List with green, amber, scale
#' @keywords internal
get_thresholds_for_type <- function(metric_type, thresholds) {
  switch(metric_type,
    "net_positive" = thresholds$net,
    "nps_score"    = thresholds$net,
    "average"      = thresholds$mean,
    "index"        = thresholds$index,
    "custom"       = thresholds$custom,
    thresholds$mean  # fallback
  )
}


# ==============================================================================
# MAIN: BUILD DASHBOARD PANEL
# ==============================================================================

#' Build Complete Dashboard Panel
#'
#' Assembles all dashboard components into a single tab panel div.
#' Iterates metric_sections from the transformer, creating a separate
#' gauge section + heatmap for each metric type.
#'
#' @param dashboard_data List from transform_for_dashboard()
#' @param config_obj Configuration object
#' @return htmltools::tags$div with id="tab-summary"
#' @export
build_dashboard_panel <- function(dashboard_data, config_obj) {

  brand_colour <- config_obj$brand_colour %||% "#323367"
  banner_info <- dashboard_data$banner_info
  metric_sections <- dashboard_data$metric_sections

  # Build colour thresholds once from config
  thresholds <- build_colour_thresholds(config_obj)

  # Build components
  meta_strip <- build_metadata_strip(dashboard_data$metadata, brand_colour)

  # Colour legend (uses actual thresholds + custom label from config)
  colour_legend <- build_colour_legend(thresholds, config_obj)

  # Build per-section content: each metric type gets gauges + heatmap
  section_blocks <- list()

  if (length(metric_sections) > 0) {
    for (i in seq_along(metric_sections)) {
      section <- metric_sections[[i]]
      type_label <- section$type_label
      metrics <- section$metrics

      if (length(metrics) == 0) next

      # Build gauges for this section
      gauges <- build_gauge_section(metrics, brand_colour, type_label, thresholds)

      # Build heatmap for this section
      section_id <- paste0("hm-section-", i)
      heatmap <- build_heatmap_grid(
        metrics, banner_info, config_obj, thresholds,
        section_label = type_label, section_id = section_id
      )

      section_blocks[[length(section_blocks) + 1]] <- htmltools::tagList(
        gauges, heatmap
      )
    }
  }

  if (length(section_blocks) == 0) {
    section_blocks <- list(htmltools::tags$div(
      class = "dash-empty-msg",
      "No headline metrics detected. Configure dashboard_metrics in Settings ",
      "(e.g., \"NET POSITIVE, Mean\") to select which metric types to display."
    ))
  }

  # Significant findings (across all metrics)
  sig_section <- NULL
  if (length(dashboard_data$sig_findings) > 0) {
    sig_section <- build_sig_findings_section(
      dashboard_data$sig_findings, brand_colour
    )
  }

  htmltools::tags$div(
    id = "tab-summary",
    class = "tab-panel active",
    htmltools::tags$div(
      class = "dash-container",
      meta_strip,
      colour_legend,
      section_blocks,
      sig_section,
      build_heatmap_export_js(),
      build_dashboard_interaction_js(),
      htmltools::tags$div(
        class = "dash-footer-note",
        htmltools::HTML(paste0(
          "&darr; Switch to <strong>Crosstabs</strong> tab for detailed question-by-question analysis &darr;"
        ))
      )
    )
  )
}


# ==============================================================================
# COMPONENT: METADATA STRIP
# ==============================================================================

#' Build Metadata Strip (4 cards)
#'
#' @param metadata List from extract_dashboard_metadata
#' @param brand_colour Character hex colour
#' @return htmltools::tags$div
#' @keywords internal
build_metadata_strip <- function(metadata, brand_colour) {

  total_n_display <- if (!is.null(metadata$total_n) && !is.na(metadata$total_n)) {
    format(round(metadata$total_n), big.mark = ",")
  } else {
    "N/A"
  }

  fieldwork_display <- if (!is.null(metadata$fieldwork_dates) &&
                           nchar(metadata$fieldwork_dates) > 0) {
    metadata$fieldwork_dates
  } else {
    "Not specified"
  }

  banner_sub <- if (metadata$banner_group_count > 0) {
    paste(metadata$banner_group_names, collapse = " \u00B7 ")
  } else {
    ""
  }

  cards <- list(
    list(value = total_n_display, label = "Total Respondents"),
    list(value = fieldwork_display, label = "Fieldwork"),
    list(value = as.character(metadata$n_questions), label = "Questions Analysed"),
    list(value = as.character(metadata$banner_group_count), label = "Banner Groups")
  )

  card_tags <- lapply(seq_along(cards), function(i) {
    card <- cards[[i]]
    subtitle <- if (i == 4 && nchar(banner_sub) > 0) {
      htmltools::tags$div(class = "dash-meta-sub", banner_sub)
    } else {
      NULL
    }

    htmltools::tags$div(
      class = "dash-meta-card",
      htmltools::tags$div(class = "dash-meta-value", card$value),
      htmltools::tags$div(class = "dash-meta-label", card$label),
      subtitle
    )
  })

  htmltools::tags$div(class = "dash-meta-strip", card_tags)
}


# ==============================================================================
# COMPONENT: COLOUR LEGEND
# ==============================================================================

#' Build Colour Legend Strip
#'
#' Shows the traffic light thresholds using actual configured values.
#' Dynamically includes only the metric types that are actually configured.
#'
#' @param thresholds List from build_colour_thresholds()
#' @param config_obj Configuration object (for dashboard_metrics and custom labels)
#' @return htmltools::HTML
#' @keywords internal
build_colour_legend <- function(thresholds, config_obj = NULL) {

  # Determine which metric types are active from dashboard_metrics config
  metrics_str <- if (!is.null(config_obj)) {
    config_obj$dashboard_metrics %||% "NET POSITIVE"
  } else {
    "NET POSITIVE"
  }

  # Parse the comma-separated metrics list
  metrics_list <- trimws(unlist(strsplit(as.character(metrics_str), ",")))
  metrics_lower <- tolower(metrics_list)

  has_net <- any(metrics_lower %in% c("net positive", "nps score", "nps"))
  has_mean <- any(metrics_lower %in% c("mean", "average"))
  # Custom = anything that is not net/nps/mean/index
  known_types <- c("net positive", "nps score", "nps", "mean", "average", "index")
  custom_labels <- metrics_list[!metrics_lower %in% known_types]
  has_custom <- length(custom_labels) > 0
  custom_label <- if (has_custom) custom_labels[1] else NULL

  # Build threshold strings for each active metric type
  build_tier <- function(label, parts) {
    paste0(
      '<span class="dash-legend-item">',
      sprintf('<span class="dash-legend-dot dash-legend-%s"></span>', label),
      paste(parts, collapse = ""),
      '</span>'
    )
  }

  # Strong tier parts
  strong_parts <- character(0)
  if (has_net) strong_parts <- c(strong_parts, sprintf('NET\u2265%+d', as.integer(thresholds$net$green)))
  if (has_mean) strong_parts <- c(strong_parts, sprintf('Mean\u2265%.1f', thresholds$mean$green))
  if (has_custom && !is.null(custom_label)) {
    strong_parts <- c(strong_parts, sprintf('%s\u2265%d%%', htmltools::htmlEscape(custom_label), as.integer(thresholds$custom$green)))
  }

  # Moderate tier parts
  moderate_parts <- character(0)
  if (has_net) moderate_parts <- c(moderate_parts, sprintf('NET\u2265%+d', as.integer(thresholds$net$amber)))
  if (has_mean) moderate_parts <- c(moderate_parts, sprintf('Mean\u2265%.1f', thresholds$mean$amber))
  if (has_custom && !is.null(custom_label)) {
    moderate_parts <- c(moderate_parts, sprintf('%s\u2265%d%%', htmltools::htmlEscape(custom_label), as.integer(thresholds$custom$amber)))
  }

  # Concern tier parts
  concern_parts <- character(0)
  if (has_net) concern_parts <- c(concern_parts, sprintf('NET&lt;%+d', as.integer(thresholds$net$amber)))
  if (has_mean) concern_parts <- c(concern_parts, sprintf('Mean&lt;%.1f', thresholds$mean$amber))
  if (has_custom && !is.null(custom_label)) {
    concern_parts <- c(concern_parts, sprintf('%s&lt;%d%%', htmltools::htmlEscape(custom_label), as.integer(thresholds$custom$amber)))
  }

  html <- paste0(
    '<div class="dash-legend">',
    '<span class="dash-legend-title">Colour Key:</span>',
    '<span class="dash-legend-item">',
    '<span class="dash-legend-dot dash-legend-green"></span>',
    sprintf('Strong (%s)', paste(strong_parts, collapse = " / ")),
    '</span>',
    '<span class="dash-legend-item">',
    '<span class="dash-legend-dot dash-legend-amber"></span>',
    sprintf('Moderate (%s)', paste(moderate_parts, collapse = " / ")),
    '</span>',
    '<span class="dash-legend-item">',
    '<span class="dash-legend-dot dash-legend-red"></span>',
    sprintf('Concern (%s)', paste(concern_parts, collapse = " / ")),
    '</span>',
    '</div>'
  )

  htmltools::HTML(html)
}


# ==============================================================================
# COMPONENT: KEY SCORE GAUGES
# ==============================================================================

#' Build Key Score Gauges Section
#'
#' Shows Total value only (no banner chips). Each metric type section
#' gets its own gauge row with a section title.
#'
#' @param metrics List of metric objects (for one section)
#' @param brand_colour Character hex colour
#' @param section_label Character, the metric type label (e.g., "NET POSITIVE")
#' @param thresholds List from build_colour_thresholds()
#' @return htmltools::tags$div
#' @keywords internal
build_gauge_section <- function(metrics, brand_colour, section_label, thresholds) {

  gauge_cards <- lapply(metrics, function(metric) {
    total_val <- metric$values[["TOTAL::Total"]]
    if (is.null(total_val) || is.na(total_val)) total_val <- NA_real_

    # Build SVG gauge
    gauge_svg <- build_svg_gauge(total_val, metric$metric_type,
                                  brand_colour, thresholds)

    # Type badge
    type_label <- switch(metric$metric_type,
      "net_positive" = "NET POSITIVE",
      "nps_score" = "NPS",
      "average" = "MEAN",
      "index" = "INDEX",
      "custom" = toupper(metric$metric_label),
      toupper(metric$metric_type)
    )

    type_class <- paste0("dash-type-badge dash-type-", metric$metric_type)

    # Full question label (CSS handles wrapping)
    q_label <- metric$question_text

    # Store display value for slide export
    display_val <- format_gauge_value(total_val, metric$metric_type)

    htmltools::tags$div(
      class = "dash-gauge-card",
      `data-q-code` = metric$q_code,
      `data-value` = display_val,
      `data-q-text` = metric$question_text,
      onclick = "toggleGaugeExclude(this)",
      htmltools::tags$span(class = type_class, type_label),
      htmltools::HTML(gauge_svg),
      htmltools::tags$div(
        class = "dash-gauge-label",
        htmltools::tags$span(class = "dash-gauge-qcode", metric$q_code),
        q_label
      )
    )
  })

  section_id <- gsub("[^a-zA-Z0-9]", "-", tolower(section_label))

  htmltools::tags$div(
    class = "dash-section",
    `data-section-type` = section_label,
    id = paste0("dash-sec-", section_id),
    htmltools::tags$div(class = "dash-section-title",
      htmltools::HTML(htmltools::htmlEscape(section_label)),
      htmltools::tags$button(
        class = "dash-export-btn dash-slide-export-btn",
        style = "margin-left:12px;",
        onclick = sprintf("exportDashboardSlide('%s')", section_id),
        htmltools::HTML("&#128196; Export Slide")
      )
    ),
    htmltools::tags$div(class = "dash-gauges", gauge_cards)
  )
}


#' Format Metric Display Value
#'
#' Formats a numeric metric value for display in gauges, heatmaps, and
#' significance finding cards. Handles NET/NPS (signed integer), custom
#' (percentage), and mean/index (1 decimal place).
#'
#' @param value Numeric value (may be NULL or NA)
#' @param metric_type Character: "net_positive", "nps_score", "average",
#'        "index", or "custom"
#' @return Character display string
#' @keywords internal
format_gauge_value <- function(value, metric_type) {
  if (is.null(value) || is.na(value)) return("N/A")
  if (metric_type %in% c("net_positive", "nps_score")) {
    paste0(ifelse(value >= 0, "+", ""), round(value))
  } else if (metric_type == "custom") {
    paste0(round(value), "%")
  } else {
    format(round(value, 1), nsmall = 1)
  }
}


#' Build SVG Semi-Circle Gauge
#'
#' @param value Numeric, the metric value
#' @param metric_type Character: "net_positive", "nps_score", "average",
#'        "index", or "custom"
#' @param brand_colour Character hex colour
#' @param thresholds List from build_colour_thresholds()
#' @return Character string of SVG markup
#' @keywords internal
build_svg_gauge <- function(value, metric_type, brand_colour, thresholds) {

  if (is.na(value)) {
    # Return a simple N/A gauge
    return(paste0(
      '<svg viewBox="0 0 200 120" width="160" height="96">',
      '<path d="M 20 100 A 80 80 0 0 1 180 100" fill="none" ',
      'stroke="#e2e8f0" stroke-width="12" stroke-linecap="round"/>',
      '<text x="100" y="92" text-anchor="middle" ',
      'font-size="22" font-weight="700" fill="#94a3b8">N/A</text>',
      '</svg>'
    ))
  }

  # Get thresholds for this metric type
  t <- get_thresholds_for_type(metric_type, thresholds)

  # Compute fill fraction based on scale
  if (metric_type %in% c("net_positive", "nps_score")) {
    # Range: -100 to +100 (always fixed)
    fill_frac <- min(max((value + 100) / 200, 0), 1)
  } else {
    # Use configured scale (e.g., 10 for 0-10, 100 for 0-100)
    fill_frac <- min(max(value / t$scale, 0), 1)
  }

  # Arc geometry
  r <- 80
  arc_length <- pi * r  # ~251.33
  fill_length <- round(fill_frac * arc_length, 2)
  remainder <- round(arc_length - fill_length + 1, 2)

  # Colour (from thresholds)
  colour <- get_gauge_colour(value, metric_type, thresholds)

  disp <- format_gauge_value(value, metric_type)

  # Build SVG
  svg <- paste0(
    '<svg viewBox="0 0 200 120" width="160" height="96">',
    '<path d="M 20 100 A 80 80 0 0 1 180 100" fill="none" ',
    'stroke="#e2e8f0" stroke-width="12" stroke-linecap="round"/>',
    '<path d="M 20 100 A 80 80 0 0 1 180 100" fill="none" ',
    'stroke="GAUGE_COLOUR" stroke-width="12" stroke-linecap="round" ',
    'stroke-dasharray="FILL_LEN REMAINDER"/>',
    '<text x="100" y="92" text-anchor="middle" ',
    'font-size="28" font-weight="700" fill="GAUGE_COLOUR">DISP_VAL</text>',
    '</svg>'
  )

  svg <- gsub("GAUGE_COLOUR", colour, svg, fixed = TRUE)
  svg <- gsub("FILL_LEN", as.character(fill_length), svg, fixed = TRUE)
  svg <- gsub("REMAINDER", as.character(remainder), svg, fixed = TRUE)
  svg <- gsub("DISP_VAL", htmltools::htmlEscape(disp), svg, fixed = TRUE)

  svg
}


# ==============================================================================
# COMPONENT: HEATMAP GRID
# ==============================================================================

#' Build Heatmap Grid for a Metric Section
#'
#' Compact table showing metrics across ALL banner groups, with
#' an Export to Excel button.
#'
#' @param metrics List of metric objects (for one section)
#' @param banner_info Banner structure
#' @param config_obj Configuration
#' @param thresholds List from build_colour_thresholds()
#' @param section_label Character, label for the section header
#' @param section_id Character, unique ID for this heatmap (for export)
#' @return htmltools::HTML (table string)
#' @keywords internal
build_heatmap_grid <- function(metrics, banner_info, config_obj, thresholds,
                                section_label = "Heatmap",
                                section_id = "hm-section-1") {

  if (length(metrics) == 0) return(NULL)

  brand_colour <- config_obj$brand_colour %||% "#323367"

  # Build column structure: Total + each banner group's columns
  col_structure <- list()  # list of list(key, label, group)

  # Total column
  col_structure[[1]] <- list(
    key = "TOTAL::Total",
    label = "Total",
    group = "TOTAL",
    is_total = TRUE
  )

  # Each banner group
  group_spans <- list()  # list of list(name, ncols) for header row 1

  banner_code_to_label <- build_banner_code_to_label(banner_info)

  if (!is.null(banner_info$banner_info)) {
    for (grp_name in names(banner_info$banner_info)) {
      grp <- banner_info$banner_info[[grp_name]]
      grp_keys <- grp$internal_keys
      grp_labels <- if (!is.null(grp$columns)) {
        grp$columns
      } else if (!is.null(banner_info$key_to_display)) {
        sapply(grp_keys, function(k) banner_info$key_to_display[[k]] %||% k)
      } else {
        grp_keys
      }

      # Use display label (e.g. "Campus") instead of code (e.g. "Q002")
      grp_display <- if (grp_name %in% names(banner_code_to_label)) {
        banner_code_to_label[grp_name]
      } else {
        grp_name
      }

      group_spans[[length(group_spans) + 1]] <- list(
        name = grp_display,
        ncols = length(grp_keys)
      )

      for (i in seq_along(grp_keys)) {
        col_structure[[length(col_structure) + 1]] <- list(
          key = grp_keys[i],
          label = grp_labels[i],
          group = grp_name,
          is_total = FALSE
        )
      }
    }
  }

  # Sanitised section_id for HTML
  safe_id <- gsub("[^a-zA-Z0-9_-]", "-", section_id)

  # Build table HTML as string
  html <- sprintf(
    '<div class="dash-section"><div class="dash-heatmap-header"><div class="dash-section-title">%s</div>',
    htmltools::htmlEscape(section_label)
  )
  html <- paste0(html, sprintf(
    '<button class="dash-export-btn" onclick="exportHeatmapExcel(\'%s\', \'%s\')">',
    safe_id, htmltools::htmlEscape(section_label)
  ))
  html <- paste0(html, '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">')
  html <- paste0(html, '<path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/>')
  html <- paste0(html, '<line x1="12" y1="15" x2="12" y2="3"/></svg> Export Excel</button></div>')
  html <- paste0(html, '<div class="dash-section-sub">All metrics across all banner groups &middot; Colour indicates strength</div>')
  html <- paste0(html, sprintf('<div class="dash-heatmap"><table class="dash-hm-table" id="%s">', safe_id))

  # --- Header Row 1: group names ---
  html <- paste0(html, '<thead><tr class="dash-hm-header1">')
  html <- paste0(html, '<th class="dash-hm-th dash-hm-label">Metric</th>')
  html <- paste0(html, '<th class="dash-hm-th dash-hm-total-header">Total</th>')
  for (gs in group_spans) {
    html <- paste0(html, sprintf(
      '<th class="dash-hm-th dash-hm-group-header" colspan="%d">%s</th>',
      gs$ncols, htmltools::htmlEscape(gs$name)
    ))
  }
  html <- paste0(html, '</tr>')

  # --- Header Row 2: individual column labels ---
  html <- paste0(html, '<tr class="dash-hm-header2">')
  html <- paste0(html, '<th class="dash-hm-th dash-hm-label"></th>')
  html <- paste0(html, '<th class="dash-hm-th dash-hm-total-header"></th>')
  for (cs in col_structure[-1]) {  # skip total (already in row 1)
    html <- paste0(html, sprintf(
      '<th class="dash-hm-th">%s</th>',
      htmltools::htmlEscape(cs$label)
    ))
  }
  html <- paste0(html, '</tr></thead>')

  # --- Data Rows ---
  html <- paste0(html, '<tbody>')
  for (metric in metrics) {

    # Type badge for the label cell
    type_short <- switch(metric$metric_type,
      "net_positive" = "NET",
      "nps_score" = "NPS",
      "average" = "MEAN",
      "index" = "IDX",
      "custom" = "",
      ""
    )

    # Full metric label (CSS handles wrapping)
    label <- metric$question_text

    type_badge_html <- if (nchar(type_short) > 0) {
      sprintf('<span class="dash-hm-type">%s</span> ', htmltools::htmlEscape(type_short))
    } else {
      ""
    }

    html <- paste0(html, '<tr class="dash-hm-row">')
    html <- paste0(html, sprintf(
      '<td class="dash-hm-td dash-hm-label"><span class="dash-hm-qcode">%s</span> %s%s</td>',
      htmltools::htmlEscape(metric$q_code),
      type_badge_html,
      htmltools::htmlEscape(label)
    ))

    # Value cells
    for (cs in col_structure) {
      val <- metric$values[[cs$key]]
      is_total <- isTRUE(cs$is_total)

      if (is.null(val) || is.na(val)) {
        html <- paste0(html, sprintf(
          '<td class="dash-hm-td%s"><span class="dash-hm-na">&mdash;</span></td>',
          if (is_total) " dash-hm-total" else ""
        ))
      } else {
        disp <- format_gauge_value(val, metric$metric_type)

        bg_style <- get_heatmap_bg_style(val, metric$metric_type, thresholds)
        tier <- get_heatmap_tier(val, metric$metric_type, thresholds)
        total_class <- if (is_total) " dash-hm-total" else ""

        html <- paste0(html, sprintf(
          '<td class="dash-hm-td%s" style="%s" data-tier="%s">%s</td>',
          total_class, bg_style, tier, htmltools::htmlEscape(disp)
        ))
      }
    }

    html <- paste0(html, '</tr>')
  }
  html <- paste0(html, '</tbody></table></div></div>')

  htmltools::HTML(html)
}


# ==============================================================================
# COMPONENT: HEATMAP EXCEL EXPORT JAVASCRIPT
# ==============================================================================

#' Build Heatmap Excel Export JavaScript
#'
#' Client-side Excel export using XML Spreadsheet format, same approach
#' as the crosstab export in 03_page_builder.R.
#'
#' @return htmltools::tags$script
#' @keywords internal
build_heatmap_export_js <- function() {

  js <- '
    function exportHeatmapExcel(tableId, sheetName) {
      var table = document.getElementById(tableId);
      if (!table) return;

      var rows = table.querySelectorAll("tr");
      if (rows.length === 0) return;

      var xml = [];
      xml.push("<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>");
      xml.push("<?mso-application progid=\\"Excel.Sheet\\"?>");
      xml.push("<Workbook xmlns=\\"urn:schemas-microsoft-com:office:spreadsheet\\"");
      xml.push(" xmlns:ss=\\"urn:schemas-microsoft-com:office:spreadsheet\\">");
      xml.push("<Styles>");
      xml.push("<Style ss:ID=\\"header\\"><Font ss:Bold=\\"1\\" ss:Size=\\"11\\"/>");
      xml.push("<Interior ss:Color=\\"#F8F9FA\\" ss:Pattern=\\"Solid\\"/></Style>");
      xml.push("<Style ss:ID=\\"title\\"><Font ss:Bold=\\"1\\" ss:Size=\\"12\\"/></Style>");
      xml.push("<Style ss:ID=\\"normal\\"><Font ss:Size=\\"11\\"/></Style>");
      xml.push("<Style ss:ID=\\"green\\"><Font ss:Size=\\"11\\" ss:Color=\\"#059669\\"/>");
      xml.push("<Interior ss:Color=\\"#D1FAE5\\" ss:Pattern=\\"Solid\\"/></Style>");
      xml.push("<Style ss:ID=\\"amber\\"><Font ss:Size=\\"11\\" ss:Color=\\"#B45309\\"/>");
      xml.push("<Interior ss:Color=\\"#FEF3C7\\" ss:Pattern=\\"Solid\\"/></Style>");
      xml.push("<Style ss:ID=\\"red\\"><Font ss:Size=\\"11\\" ss:Color=\\"#DC2626\\"/>");
      xml.push("<Interior ss:Color=\\"#FEE2E2\\" ss:Pattern=\\"Solid\\"/></Style>");
      xml.push("</Styles>");

      var safeName = sheetName.replace(/[\\[\\]\\\\\\/?*]/g, "").substring(0, 31);
      xml.push("<Worksheet ss:Name=\\"" + escapeHeatmapXml(safeName) + "\\">");
      xml.push("<Table>");

      rows.forEach(function(row, rowIdx) {
        xml.push("<Row>");
        var cells = row.querySelectorAll("th, td");
        cells.forEach(function(cell) {
          var colspan = cell.getAttribute("colspan");
          var text = cell.textContent.trim();
          var isHeader = cell.tagName === "TH" || rowIdx < 2;
          var styleId = isHeader ? "header" : "normal";

          // Read colour tier from data attribute (inline style colours are
          // normalised to rgb(r, g, b) by browsers, making string matching unreliable)
          if (!isHeader) {
            var tier = cell.getAttribute("data-tier");
            if (tier === "green" || tier === "amber" || tier === "red") {
              styleId = tier;
            }
          }

          // Handle colspan by merging
          var mergeAttr = "";
          if (colspan && parseInt(colspan) > 1) {
            mergeAttr = " ss:MergeAcross=\\"" + (parseInt(colspan) - 1) + "\\"";
          }

          // Try numeric detection
          var cleaned = text.replace(/[+%,]/g, "").trim();
          var num = parseFloat(cleaned);
          var isNum = !isNaN(num) && cleaned.match(/^[\\-]?[\\d\\.]+$/);

          if (isNum && text.trim() !== "" && text.trim() !== "\\u2014") {
            xml.push("<Cell ss:StyleID=\\"" + styleId + "\\"" + mergeAttr +
                      "><Data ss:Type=\\"Number\\">" + num + "</Data></Cell>");
          } else {
            xml.push("<Cell ss:StyleID=\\"" + styleId + "\\"" + mergeAttr +
                      "><Data ss:Type=\\"String\\">" + escapeHeatmapXml(text) + "</Data></Cell>");
          }
        });
        xml.push("</Row>");
      });

      xml.push("</Table></Worksheet></Workbook>");

      var blob = new Blob([xml.join("\\n")], {
        type: "application/vnd.ms-excel;charset=utf-8"
      });
      var url = URL.createObjectURL(blob);
      var a = document.createElement("a");
      a.href = url;
      a.download = safeName.replace(/\\s+/g, "_") + "_heatmap.xls";
      document.body.appendChild(a);
      a.click();
      setTimeout(function() { document.body.removeChild(a); URL.revokeObjectURL(url); }, 100);
    }

    function escapeHeatmapXml(s) {
      return s.replace(/&/g, "&amp;").replace(/</g, "&lt;")
              .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }
  '

  htmltools::tags$script(htmltools::HTML(js))
}


#' Build Dashboard Slide Export & Gauge Toggle JavaScript
#'
#' @return htmltools::tags$script
#' @keywords internal
build_dashboard_interaction_js <- function() {
  js <- '
    function toggleGaugeExclude(card) {
      card.classList.toggle("dash-gauge-excluded");
    }

    function exportDashboardSlide(sectionId) {
      var section = document.getElementById("dash-sec-" + sectionId);
      if (!section) return;
      var cards = section.querySelectorAll(".dash-gauge-card:not(.dash-gauge-excluded)");
      if (cards.length === 0) { alert("No gauges to export (all excluded)"); return; }

      var ns = "http://www.w3.org/2000/svg";
      var font = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
      var W = 1000, pad = 30;
      var perRow = 5, cardW = 170, cardH = 150, gapX = 14, gapY = 18;
      var maxPerSlide = 20;
      var totalCards = cards.length;
      var slideCount = Math.ceil(totalCards / maxPerSlide);

      for (var si = 0; si < slideCount; si++) {
        var startIdx = si * maxPerSlide;
        var endIdx = Math.min(startIdx + maxPerSlide, totalCards);
        var slideCards = Array.from(cards).slice(startIdx, endIdx);
        var rows = Math.ceil(slideCards.length / perRow);
        var titleH = 40;
        var gridH = rows * (cardH + gapY);
        var totalH = pad + titleH + gridH + pad;

        var svg = document.createElementNS(ns, "svg");
        svg.setAttribute("xmlns", ns);
        svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
        svg.setAttribute("style", "font-family:" + font + ";");

        // White bg
        var bg = document.createElementNS(ns, "rect");
        bg.setAttribute("width", W); bg.setAttribute("height", totalH);
        bg.setAttribute("fill", "#ffffff");
        svg.appendChild(bg);

        // Title bar with accent line
        var accent = document.createElementNS(ns, "rect");
        accent.setAttribute("x", pad); accent.setAttribute("y", pad);
        accent.setAttribute("width", "4"); accent.setAttribute("height", "22");
        accent.setAttribute("rx", "2"); accent.setAttribute("fill", "#323367");
        svg.appendChild(accent);

        var title = document.createElementNS(ns, "text");
        var sectionTitle = section.querySelector(".dash-section-title");
        var titleText = sectionTitle ? sectionTitle.textContent.replace("Export Slide", "").trim() : sectionId;
        if (slideCount > 1) titleText += " (" + (si + 1) + " of " + slideCount + ")";
        title.setAttribute("x", pad + 12); title.setAttribute("y", pad + 17);
        title.setAttribute("fill", "#1a2744"); title.setAttribute("font-size", "16");
        title.setAttribute("font-weight", "700");
        title.textContent = titleText;
        svg.appendChild(title);

        // Gauge cards -- built from scratch, no cloning
        var gridStartX = (W - (perRow * cardW + (perRow - 1) * gapX)) / 2;
        slideCards.forEach(function(card, ci) {
          var col = ci % perRow;
          var row = Math.floor(ci / perRow);
          var cx = gridStartX + col * (cardW + gapX);
          var cy = pad + titleH + row * (cardH + gapY);
          var midX = cx + cardW / 2;

          // Card background
          var cardBg = document.createElementNS(ns, "rect");
          cardBg.setAttribute("x", cx); cardBg.setAttribute("y", cy);
          cardBg.setAttribute("width", cardW); cardBg.setAttribute("height", cardH);
          cardBg.setAttribute("rx", "8"); cardBg.setAttribute("fill", "#f8fafc");
          cardBg.setAttribute("stroke", "#e2e8f0"); cardBg.setAttribute("stroke-width", "1");
          svg.appendChild(cardBg);

          // Extract gauge colour and fill from the existing card SVG
          var gaugeColour = "#059669";
          var fillFrac = 0.5;
          var gaugeEl = card.querySelector("svg");
          if (gaugeEl) {
            var paths = gaugeEl.querySelectorAll("path");
            if (paths.length >= 2) {
              gaugeColour = paths[1].getAttribute("stroke") || gaugeColour;
              var da = paths[1].getAttribute("stroke-dasharray") || "";
              var daParts = da.split(/[\\s,]+/);
              if (daParts.length >= 1) {
                var fillLen = parseFloat(daParts[0]) || 0;
                fillFrac = Math.min(fillLen / 251.33, 1);
              }
            }
          }

          // Draw mini gauge arc (radius 40, centered in upper card area)
          var gr = 40, gStroke = 8;
          var gCx = midX, gCy = cy + 58;
          var arcLen = Math.PI * gr;
          var fillDash = (fillFrac * arcLen).toFixed(1);
          var gapDash = (arcLen - fillFrac * arcLen + 1).toFixed(1);

          // Background arc (grey)
          var bgArc = document.createElementNS(ns, "path");
          var arcD = "M " + (gCx - gr) + " " + gCy + " A " + gr + " " + gr + " 0 0 1 " + (gCx + gr) + " " + gCy;
          bgArc.setAttribute("d", arcD); bgArc.setAttribute("fill", "none");
          bgArc.setAttribute("stroke", "#e2e8f0"); bgArc.setAttribute("stroke-width", gStroke);
          bgArc.setAttribute("stroke-linecap", "round");
          svg.appendChild(bgArc);

          // Coloured arc
          var fgArc = document.createElementNS(ns, "path");
          fgArc.setAttribute("d", arcD); fgArc.setAttribute("fill", "none");
          fgArc.setAttribute("stroke", gaugeColour); fgArc.setAttribute("stroke-width", gStroke);
          fgArc.setAttribute("stroke-linecap", "round");
          fgArc.setAttribute("stroke-dasharray", fillDash + " " + gapDash);
          svg.appendChild(fgArc);

          // Value text (bold, centred below arc)
          var val = card.getAttribute("data-value") || "";
          var valEl = document.createElementNS(ns, "text");
          valEl.setAttribute("x", midX); valEl.setAttribute("y", gCy - 6);
          valEl.setAttribute("text-anchor", "middle"); valEl.setAttribute("fill", gaugeColour);
          valEl.setAttribute("font-size", "16"); valEl.setAttribute("font-weight", "700");
          valEl.textContent = val;
          svg.appendChild(valEl);

          // Q code (small, teal)
          var qCode = card.getAttribute("data-q-code") || "";
          var qcEl = document.createElementNS(ns, "text");
          qcEl.setAttribute("x", midX); qcEl.setAttribute("y", gCy + 16);
          qcEl.setAttribute("text-anchor", "middle"); qcEl.setAttribute("fill", "#323367");
          qcEl.setAttribute("font-size", "10"); qcEl.setAttribute("font-weight", "700");
          qcEl.textContent = qCode;
          svg.appendChild(qcEl);

          // Question text (multi-line wrapping, no truncation)
          var qText = card.getAttribute("data-q-text") || "";
          var maxCharsPerLine = Math.floor((cardW - 12) / 5);
          var tLines = [];
          if (qText.length <= maxCharsPerLine) {
            tLines = [qText];
          } else {
            var words = qText.split(" ");
            var current = "";
            for (var wi = 0; wi < words.length; wi++) {
              var test = current ? current + " " + words[wi] : words[wi];
              if (test.length > maxCharsPerLine && current) {
                tLines.push(current);
                current = words[wi];
              } else {
                current = test;
              }
            }
            if (current) tLines.push(current);
            if (tLines.length > 4) tLines = tLines.slice(0, 4);
          }
          tLines.forEach(function(tLine, tli) {
            var tEl = document.createElementNS(ns, "text");
            tEl.setAttribute("x", midX);
            tEl.setAttribute("y", gCy + 30 + tli * 11);
            tEl.setAttribute("text-anchor", "middle");
            tEl.setAttribute("fill", "#64748b");
            tEl.setAttribute("font-size", "8.5");
            tEl.textContent = tLine;
            svg.appendChild(tEl);
          });
        });

        // Render to PNG at 3x
        var scale = 3;
        var svgData = new XMLSerializer().serializeToString(svg);
        var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
        var url = URL.createObjectURL(svgBlob);
        var img = new Image();
        img.onerror = (function(blobUrl) {
          return function() {
            URL.revokeObjectURL(blobUrl);
            alert("Dashboard export failed. Your browser may not support this operation. Try Chrome or Edge.");
          };
        })(url);
        img.onload = (function(slideIdx, svgW, svgH, blobUrl) {
          return function() {
            var canvas = document.createElement("canvas");
            canvas.width = svgW * scale; canvas.height = svgH * scale;
            var ctx = canvas.getContext("2d");
            ctx.fillStyle = "#ffffff";
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            URL.revokeObjectURL(blobUrl);
            canvas.toBlob(function(blob) {
              var suffix = slideCount > 1 ? "_" + (slideIdx + 1) : "";
              var a = document.createElement("a");
              a.href = URL.createObjectURL(blob);
              a.download = sectionId + "_dashboard" + suffix + ".png";
              document.body.appendChild(a); a.click();
              document.body.removeChild(a);
              URL.revokeObjectURL(a.href);
            }, "image/png");
          };
        })(si, W, totalH, url);
        img.src = url;
      }
    }
  '
  htmltools::tags$script(htmltools::HTML(js))
}


# ==============================================================================
# COMPONENT: SIGNIFICANT FINDINGS
# ==============================================================================

#' Build Significant Findings Section
#'
#' Shows question text and column value vs Total for context.
#'
#' @param sig_findings List from extract_sig_findings
#' @param brand_colour Character hex colour
#' @return htmltools::tags$div
#' @keywords internal
build_sig_findings_section <- function(sig_findings, brand_colour) {

  if (length(sig_findings) == 0) return(NULL)

  cards <- lapply(sig_findings, function(f) {
    col_val_display <- format_gauge_value(f$value, f$metric_type)
    total_val_display <- format_gauge_value(f$total_value, f$metric_type)

    # Resolve comparison letters to "Cape Town (+42), Pretoria (+38)"
    comparisons_text <- f$sig_letters  # fallback: raw letters
    if (!is.null(f$resolved_comparisons) && length(f$resolved_comparisons) > 0) {
      comp_parts <- sapply(f$resolved_comparisons, function(comp) {
        comp_val_display <- format_gauge_value(comp$value, f$metric_type)
        paste0(comp$name, " (", comp_val_display, ")")
      })
      comparisons_text <- paste(comp_parts, collapse = ", ")
    }

    # Metric descriptor (e.g., "Good or excellent", "NET POSITIVE", "Mean")
    metric_desc <- f$metric_label %||% ""

    # Show: "Good or excellent: 3rd yr 67% vs Total 59% — sig. higher than Honours (53%)"
    finding_text <- sprintf(
      "%s %s vs Total %s \u2014 sig. higher than %s",
      f$column_label, col_val_display, total_val_display, comparisons_text
    )

    # Full question text (no truncation — CSS handles wrapping)
    q_text <- f$question_text %||% ""

    htmltools::tags$div(
      class = "dash-sig-card",
      htmltools::tags$div(
        class = "dash-sig-badges",
        htmltools::tags$span(class = "dash-sig-metric-badge", f$q_code),
        htmltools::tags$span(class = "dash-sig-group-badge", f$banner_group),
        if (nchar(metric_desc) > 0) {
          htmltools::tags$span(class = "dash-sig-type-badge", metric_desc)
        }
      ),
      if (nchar(q_text) > 0) {
        htmltools::tags$div(class = "dash-sig-question", q_text)
      },
      htmltools::tags$div(class = "dash-sig-text", finding_text)
    )
  })

  htmltools::tags$div(
    class = "dash-section",
    htmltools::tags$div(class = "dash-section-title", "Significant Findings"),
    htmltools::tags$div(class = "dash-section-sub",
      "Columns significantly higher than others on headline metrics"
    ),
    htmltools::tags$div(class = "dash-sig-grid", cards)
  )
}


# ==============================================================================
# COMPONENT: DASHBOARD CSS
# ==============================================================================

#' Build Dashboard CSS
#'
#' @param brand_colour Character hex colour
#' @return htmltools::tags$style
#' @export
build_dashboard_css <- function(brand_colour) {

  bc <- brand_colour %||% "#323367"

  css_text <- '
    /* === REPORT TAB NAVIGATION === */
    .report-tabs {
      display: flex; gap: 0; max-width: 1400px; margin: 0 auto;
      padding: 0 32px; background: #fff;
      border-bottom: 2px solid #e2e8f0;
    }
    .report-tab {
      padding: 12px 28px; font-size: 14px; font-weight: 600;
      color: #64748b; background: none; border: none;
      cursor: pointer; border-bottom: 3px solid transparent;
      margin-bottom: -2px; transition: all 0.15s;
    }
    .report-tab:hover { color: #1a2744; }
    .report-tab.active {
      color: BRAND; border-bottom-color: BRAND;
    }
    .tab-panel { display: none; }
    .tab-panel.active { display: block; }

    /* === DASHBOARD CONTAINER === */
    .dash-container {
      max-width: 1400px; margin: 0 auto; padding: 24px 32px;
    }
    .dash-section { margin-bottom: 24px; }
    .dash-section-title {
      font-size: 14px; font-weight: 700; color: #1a2744;
      margin-bottom: 4px;
    }
    .dash-section-sub {
      font-size: 12px; color: #94a3b8; margin-bottom: 16px;
    }
    .dash-empty-msg {
      background: #fef3cd; border: 1px solid #ffc107; border-radius: 8px;
      padding: 20px; font-size: 13px; color: #664d03; margin: 24px 0;
    }
    .dash-footer-note {
      text-align: center; padding: 16px; font-size: 12px;
      color: #94a3b8; border-top: 1px solid #e2e8f0; margin-top: 8px;
    }

    /* === METADATA STRIP === */
    .dash-meta-strip {
      display: grid; grid-template-columns: repeat(4, 1fr);
      gap: 16px; margin-bottom: 24px;
    }
    .dash-meta-card {
      background: #fff; border-radius: 8px;
      border: 1px solid #e2e8f0; padding: 16px 20px;
      border-left: 4px solid BRAND;
    }
    .dash-meta-value {
      font-size: 24px; font-weight: 700; color: #1a2744;
      font-variant-numeric: tabular-nums;
    }
    .dash-meta-label {
      font-size: 11px; color: #64748b; margin-top: 4px;
      text-transform: uppercase; letter-spacing: 0.5px; font-weight: 600;
    }
    .dash-meta-sub {
      font-size: 11px; color: #94a3b8; margin-top: 4px;
    }

    /* === COLOUR LEGEND === */
    .dash-legend {
      display: flex; align-items: center; gap: 16px; flex-wrap: wrap;
      padding: 10px 16px; margin-bottom: 20px;
      background: #f8fafc; border-radius: 6px; border: 1px solid #e2e8f0;
      font-size: 11px; color: #64748b;
    }
    .dash-legend-title { font-weight: 700; color: #1a2744; }
    .dash-legend-item { display: inline-flex; align-items: center; gap: 5px; }
    .dash-legend-dot {
      width: 10px; height: 10px; border-radius: 50%; display: inline-block;
    }
    .dash-legend-green { background: #059669; }
    .dash-legend-amber { background: #d97706; }
    .dash-legend-red { background: #dc2626; }

    /* === GAUGES === */
    .dash-gauges {
      display: flex; flex-wrap: wrap; gap: 16px; margin-bottom: 16px;
    }
    .dash-gauge-card {
      background: #fff; border-radius: 8px; border: 1px solid #e2e8f0;
      padding: 16px; min-width: 220px; flex: 1; max-width: 320px;
      text-align: center; cursor: pointer; transition: all 0.2s;
    }
    .dash-gauge-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
    .dash-gauge-card.dash-gauge-excluded {
      opacity: 0.3; filter: grayscale(1);
      border-style: dashed;
    }
    .dash-gauge-label {
      font-size: 12px; color: #1e293b; margin-top: 8px; line-height: 1.4;
      white-space: normal; word-wrap: break-word; overflow-wrap: break-word;
    }
    .dash-gauge-qcode {
      font-size: 11px; font-weight: 700; color: BRAND;
      margin-right: 4px;
    }
    .dash-type-badge {
      display: inline-block; font-size: 9px; font-weight: 700;
      padding: 2px 8px; border-radius: 3px; letter-spacing: 0.5px;
      margin-bottom: 8px;
    }
    .dash-type-net_positive { background: rgba(5,150,105,0.1); color: #059669; }
    .dash-type-nps_score { background: rgba(13,138,138,0.1); color: BRAND; }
    .dash-type-average { background: rgba(217,119,6,0.1); color: #b45309; }
    .dash-type-index { background: rgba(99,102,241,0.1); color: #4f46e5; }
    .dash-type-custom { background: rgba(100,116,139,0.1); color: #475569; }

    /* === HEATMAP GRID === */
    .dash-heatmap-header {
      display: flex; justify-content: space-between; align-items: center;
      margin-bottom: 4px;
    }
    .dash-export-btn {
      display: inline-flex; align-items: center; gap: 6px;
      padding: 6px 14px; font-size: 12px; font-weight: 600;
      color: BRAND; background: rgba(13,138,138,0.06);
      border: 1px solid rgba(13,138,138,0.2); border-radius: 6px;
      cursor: pointer; transition: all 0.15s;
    }
    .dash-export-btn:hover {
      background: rgba(13,138,138,0.12); border-color: BRAND;
    }
    .dash-heatmap {
      border-radius: 8px; overflow-x: auto; border: 1px solid #e2e8f0;
      background: #fff; padding-bottom: 2px; margin-bottom: 8px;
    }
    .dash-hm-table {
      width: 100%; border-collapse: collapse; font-size: 12px;
      font-variant-numeric: tabular-nums; margin-bottom: 4px;
    }
    .dash-hm-header1 { border-bottom: 2px solid #1a2744; }
    .dash-hm-header2 { border-bottom: 1px solid #e2e8f0; }
    .dash-hm-th {
      padding: 6px 10px; text-align: center; font-weight: 600;
      font-size: 11px; color: #64748b; white-space: nowrap;
    }
    .dash-hm-group-header {
      font-size: 10px; text-transform: uppercase; letter-spacing: 1px;
      color: BRAND; border-left: 2px solid #e2e8f0;
    }
    .dash-hm-total-header {
      background: rgba(26,39,68,0.04); font-weight: 700; color: #1a2744;
    }
    .dash-hm-td {
      padding: 8px 10px; text-align: center; font-weight: 500;
      border-bottom: 1px solid #e2e8f0; transition: background 0.15s;
    }
    .dash-hm-td.dash-hm-label {
      text-align: left; min-width: 240px; max-width: 400px;
      font-weight: 500; color: #1a2744;
      position: sticky; left: 0; background: #fff; z-index: 1;
      border-right: 1px solid #e2e8f0;
      white-space: normal; word-wrap: break-word; overflow-wrap: break-word;
      line-height: 1.4;
    }
    .dash-hm-td.dash-hm-total {
      background: rgba(26,39,68,0.04); font-weight: 700; color: #1a2744;
    }
    .dash-hm-row:hover .dash-hm-td { background: rgba(13,138,138,0.03); }
    .dash-hm-row:hover .dash-hm-td.dash-hm-label { background: rgba(13,138,138,0.03); }
    .dash-hm-row:hover .dash-hm-td.dash-hm-total { background: rgba(26,39,68,0.06); }
    .dash-hm-qcode {
      font-size: 10px; color: BRAND; font-weight: 700; margin-right: 4px;
    }
    .dash-hm-type {
      font-size: 9px; font-weight: 700; padding: 1px 4px; border-radius: 2px;
      background: rgba(100,116,139,0.1); color: #64748b; margin-right: 4px;
    }
    .dash-hm-na { color: #cbd5e1; }

    /* === SIGNIFICANT FINDINGS === */
    .dash-sig-grid {
      display: grid; grid-template-columns: 1fr 1fr; gap: 10px;
    }
    .dash-sig-card {
      background: #fff; border-radius: 8px; border: 1px solid #e2e8f0;
      padding: 12px 16px; border-left: 3px solid #059669;
    }
    .dash-sig-badges { display: flex; gap: 6px; margin-bottom: 4px; }
    .dash-sig-metric-badge {
      font-size: 9px; font-weight: 700; padding: 2px 6px; border-radius: 3px;
      background: rgba(26,39,68,0.06); color: #1a2744; letter-spacing: 0.5px;
    }
    .dash-sig-group-badge {
      font-size: 9px; font-weight: 600; padding: 2px 6px; border-radius: 3px;
      background: rgba(13,138,138,0.08); color: BRAND;
    }
    .dash-sig-type-badge {
      font-size: 9px; font-weight: 600; padding: 2px 6px; border-radius: 3px;
      background: rgba(217,119,6,0.10); color: #b45309;
    }
    .dash-sig-question {
      font-size: 11px; color: #64748b; line-height: 1.3; margin-bottom: 4px;
      white-space: normal; word-wrap: break-word; overflow-wrap: break-word;
    }
    .dash-sig-text { font-size: 12px; color: #1e293b; line-height: 1.4; }

    /* === RESPONSIVE === */
    @media (max-width: 768px) {
      .dash-meta-strip { grid-template-columns: repeat(2, 1fr); }
      .dash-sig-grid { grid-template-columns: 1fr; }
      .dash-container { padding: 16px; }
    }

    /* === PRINT === */
    @media print {
      .dash-export-btn { display: none !important; }
      .dash-gauge-circle, .dash-hm-td, .dash-meta-card,
      .dash-sig-card, .dash-hm-th {
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
    }
  '

  css_text <- gsub("BRAND", bc, css_text, fixed = TRUE)

  htmltools::tags$style(htmltools::HTML(css_text))
}


# ==============================================================================
# HELPER FUNCTIONS — CONFIGURABLE TRAFFIC LIGHT COLOUR SYSTEM
# ==============================================================================
# All colour helpers accept a `thresholds` parameter from
# build_colour_thresholds(). Each metric type has:
#   green — value >= this is green
#   amber — value >= this is amber (below green)
#   Below amber is red.
#
# Heatmap uses a 4-tier gradient: strong green (above ~1.15x green),
# light green (at green), amber, red.
# ==============================================================================

#' Get Gauge Colour Based on Value, Metric Type, and Thresholds
#'
#' Traffic light system: green (strong), amber (moderate), red (concern).
#'
#' @param value Numeric
#' @param metric_type Character
#' @param thresholds List from build_colour_thresholds()
#' @return Character hex colour
#' @keywords internal
get_gauge_colour <- function(value, metric_type, thresholds) {
  if (is.na(value)) return("#94a3b8")

  t <- get_thresholds_for_type(metric_type, thresholds)

  if (value >= t$green) return("#059669")  # Green
  if (value >= t$amber) return("#d97706")  # Amber
  return("#dc2626")                         # Red
}



#' Get Heatmap Background Style for a Cell
#'
#' 4-tier gradient for visual richness:
#'   - Strong green: value well above green threshold
#'   - Light green: at or just above green threshold
#'   - Amber: between amber and green
#'   - Red: below amber
#'
#' The "strong green" tier kicks in at ~1.15x the green threshold
#' (or green + 15% of the range above green, depending on metric type).
#'
#' @param value Numeric
#' @param metric_type Character
#' @param thresholds List from build_colour_thresholds()
#' @return Character CSS style string (inline background-color)
#' @keywords internal
get_heatmap_bg_style <- function(value, metric_type, thresholds) {
  if (is.na(value)) return("")

  t <- get_thresholds_for_type(metric_type, thresholds)

  # Compute strong-green cutoff: ~midway between green and scale max
  # For NET: green=30, strong~= green + (100-green)*0.4 = 58
  # For Mean(10): green=7, strong ~= 7 + (10-7)*0.33 = 8
  # For Custom(%): green=60, strong ~= 60 + (100-60)*0.25 = 70
  if (metric_type %in% c("net_positive", "nps_score")) {
    strong_green <- t$green + (100 - t$green) * 0.4
  } else {
    strong_green <- t$green + (t$scale - t$green) * 0.33
  }

  if (value >= strong_green) {
    return("background-color: rgba(5,150,105,0.18); color: #059669; font-weight: 700;")
  }
  if (value >= t$green) {
    return("background-color: rgba(5,150,105,0.10); color: #059669;")
  }
  if (value >= t$amber) {
    return("background-color: rgba(217,119,6,0.10); color: #b45309;")
  }
  return("background-color: rgba(220,38,38,0.12); color: #dc2626;")
}


#' Get Heatmap Colour Tier for a Cell
#'
#' Returns "green", "amber", or "red" — used as a data-tier attribute so the
#' client-side Excel export can read tier without parsing normalised rgb() strings.
#'
#' @param value Numeric
#' @param metric_type Character
#' @param thresholds List from build_colour_thresholds()
#' @return Character: "green", "amber", or "red"
#' @keywords internal
get_heatmap_tier <- function(value, metric_type, thresholds) {
  if (is.na(value)) return("")
  t <- get_thresholds_for_type(metric_type, thresholds)
  if (value >= t$green) return("green")
  if (value >= t$amber) return("amber")
  return("red")
}


