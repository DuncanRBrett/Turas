# ==============================================================================
# HTML REPORT - DASHBOARD BUILDER (V10.8)
# ==============================================================================
# Summary dashboard component builders.
# JavaScript is in 06a_dashboard_js.R.
# CSS and colour helpers are in 06b_dashboard_styling.R.
# Both files are auto-sourced by 99_html_report_main.R.
# ==============================================================================

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
      gauges <- build_gauge_section(metrics, brand_colour, type_label, thresholds, config_obj)

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
  if (length(dashboard_data$sig_findings) > 0) {
    sig_section <- build_sig_findings_section(
      dashboard_data$sig_findings, brand_colour
    )
  } else {
    sig_section <- htmltools::tags$div(class = "dash-section",
      id = "dash-sec-sig-findings",
      htmltools::tags$div(class = "dash-section-title", "Significant Findings"),
      htmltools::tags$div(class = "dash-section-sub",
        "Columns significantly higher than others on headline metrics"
      ),
      htmltools::tags$div(class = "dash-sig-empty",
        "There are no significant findings"
      )
    )
  }

  # 2A: Embed metadata as data attributes for JS slide export
  project_title <- config_obj$project_title %||% ""
  company_name <- config_obj$company_name %||% ""
  fieldwork_dates <- config_obj$fieldwork_dates %||% ""

  htmltools::tags$div(
    id = "tab-summary",
    class = "tab-panel active",
    `data-project-title` = project_title,
    `data-fieldwork` = fieldwork_dates,
    `data-company` = company_name,
    `data-brand-colour` = brand_colour,
    htmltools::tags$div(
      class = "dash-container",
      meta_strip,
      colour_legend,
      build_dashboard_text_boxes(brand_colour, config_obj),
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
# COMPONENT: DASHBOARD TEXT BOXES
# ==============================================================================

#' Build Dashboard Text Boxes
#'
#' Two editable text areas at the top of the dashboard:
#' 1. Background & Method — for context about the study
#' 2. Executive Summary — for key findings and recommendations
#'
#' Each has a pin button to save content to Pinned Views.
#'
#' @param brand_colour Character hex colour
#' @return htmltools::tagList
#' @keywords internal
build_dashboard_text_boxes <- function(brand_colour, config_obj = list()) {

  bc <- brand_colour %||% "#323367"

  build_one_box <- function(box_id, title, placeholder, prefill = NULL) {
    # Pre-populated content (raw markdown from config Comments sheet)
    raw_md <- if (!is.null(prefill) && nzchar(trimws(prefill))) {
      trimws(prefill)
    } else {
      NULL
    }

    htmltools::tags$div(
      class = "dash-text-box",
      style = sprintf("border-left: 3px solid %s;", bc),
      htmltools::tags$div(
        class = "dash-text-box-header",
        htmltools::tags$span(class = "dash-text-box-title", title),
        htmltools::tags$button(
          class = "dash-export-btn dash-pin-text-btn",
          onclick = sprintf("pinDashboardText('%s')", box_id),
          htmltools::HTML("&#128204; Pin to Views")
        )
      ),
      htmltools::tags$div(
        id = paste0("dash-text-", box_id),
        class = "dash-text-content",
        # Textarea for editing raw markdown (hidden unless .editing)
        htmltools::tags$textarea(
          class = "dash-md-editor",
          placeholder = placeholder,
          if (!is.null(raw_md)) raw_md
        ),
        # Rendered markdown display (visible unless .editing)
        htmltools::tags$div(
          class = "dash-md-rendered",
          ondblclick = sprintf("toggleDashEdit('%s')", box_id)
        ),
        # Hidden store for persistence on save
        htmltools::tags$textarea(
          class = "dash-md-store",
          style = "display:none;",
          if (!is.null(raw_md)) raw_md
        )
      )
    )
  }

  htmltools::tagList(
    build_one_box(
      "background",
      "Background & Method",
      "Enter background, method, sample details...",
      prefill = config_obj$background_text
    ),
    build_one_box(
      "execsummary",
      "Executive Summary",
      "Enter key findings and recommendations...",
      prefill = config_obj$executive_summary
    )
  )
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
build_gauge_section <- function(metrics, brand_colour, section_label, thresholds,
                                config_obj = list()) {

  # --- 1F: Sort gauges by Total value (configurable) ---
  # Config values: "desc" (highest first), "asc" (lowest first), "original" (no sort)
  sort_mode <- tolower(as.character(config_obj$dashboard_sort_gauges %||% "desc"))
  # Backwards-compatible: legacy TRUE → "desc", FALSE → "original"
  if (sort_mode %in% c("true", "1")) sort_mode <- "desc"
  if (sort_mode %in% c("false", "0")) sort_mode <- "original"

  total_vals <- sapply(metrics, function(m) {
    v <- m$values[["TOTAL::Total"]]
    if (is.null(v)) return(-Inf)
    v <- suppressWarnings(as.numeric(as.character(v)))
    if (is.na(v)) -Inf else v
  })
  # Track original indices for JS re-sort to "original" order
  original_indices <- seq_along(metrics)
  if (sort_mode != "original" && length(metrics) > 1) {
    sort_order <- order(total_vals, decreasing = (sort_mode == "desc"))
    metrics <- metrics[sort_order]
    total_vals <- total_vals[sort_order]
    original_indices <- original_indices[sort_order]
  }

  # --- Pre-compute tier info for 1A, 1C, 1E ---
  n_metrics <- length(metrics)
  gauge_colours <- character(n_metrics)
  for (i in seq_along(metrics)) {
    v <- total_vals[i]
    if (is.finite(v)) {
      gauge_colours[i] <- get_gauge_colour(v, metrics[[i]]$metric_type, thresholds)
    } else {
      gauge_colours[i] <- "#94a3b8"
    }
  }

  # 1E: Count tiers
  n_green <- sum(gauge_colours == "#4a7c6f")
  n_amber <- sum(gauge_colours == "#c9a96e")
  n_red <- sum(gauge_colours == "#b85450")

  # 1C: Find best/worst indices (only when 3+ metrics with valid values)
  finite_mask <- is.finite(total_vals)
  best_idx <- NA_integer_
  worst_idx <- NA_integer_
  if (sum(finite_mask) >= 3) {
    finite_vals <- total_vals
    finite_vals[!finite_mask] <- NA_real_
    best_idx <- which.max(finite_vals)
    worst_idx <- which.min(finite_vals)
  }

  # 1D: Hero mode for single-item sections
  is_hero <- (n_metrics == 1)

  # --- Build gauge cards ---
  gauge_cards <- lapply(seq_along(metrics), function(i) {
    metric <- metrics[[i]]
    total_val <- total_vals[i]
    if (!is.finite(total_val)) total_val <- NA_real_
    colour <- gauge_colours[i]

    # Build SVG gauge (1D: larger for hero)
    gauge_svg <- build_svg_gauge(total_val, metric$metric_type,
                                  brand_colour, thresholds, is_hero = is_hero)

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

    q_label <- metric$question_text
    display_val <- format_gauge_value(total_val, metric$metric_type)

    # 1A: Colour-coded left border
    card_style <- sprintf("border-left: 3px solid %s;", colour)

    # 1D: Hero class
    card_class <- if (is_hero) "dash-gauge-card dash-gauge-hero" else "dash-gauge-card"

    # 1C: Best/Worst badge
    callout_badge <- NULL
    if (!is.na(best_idx) && i == best_idx) {
      callout_badge <- htmltools::tags$span(
        class = "dash-callout-badge dash-callout-best", "Highest")
    } else if (!is.na(worst_idx) && i == worst_idx) {
      callout_badge <- htmltools::tags$span(
        class = "dash-callout-badge dash-callout-worst", "Lowest")
    }

    # 1G: Rank indicator
    rank_el <- NULL
    if (n_metrics > 1) {
      rank_el <- htmltools::tags$span(class = "dash-gauge-rank",
                                       paste0("#", i))
    }

    htmltools::tags$div(
      class = card_class,
      style = card_style,
      `data-q-code` = metric$q_code,
      `data-value` = display_val,
      `data-value-num` = if (is.finite(total_val)) as.character(total_val) else "",
      `data-original-idx` = as.character(original_indices[i]),
      `data-q-text` = metric$question_text,
      onclick = "toggleGaugeExclude(this)",
      callout_badge,
      htmltools::tags$span(class = type_class, type_label),
      htmltools::HTML(gauge_svg),
      htmltools::tags$div(
        class = "dash-gauge-label",
        htmltools::tags$span(class = "dash-gauge-qcode", metric$q_code),
        q_label
      ),
      rank_el
    )
  })

  section_id <- gsub("[^a-zA-Z0-9]", "-", tolower(section_label))

  # 1E: Build tier count badges for section header
  tier_badges <- htmltools::tagList(
    if (n_green > 0) htmltools::tags$span(
      class = "dash-tier-pill dash-tier-green",
      paste0(n_green, " Strong")),
    if (n_amber > 0) htmltools::tags$span(
      class = "dash-tier-pill dash-tier-amber",
      paste0(n_amber, " Moderate")),
    if (n_red > 0) htmltools::tags$span(
      class = "dash-tier-pill dash-tier-red",
      paste0(n_red, " Concern"))
  )

  # Sort toggle button label based on initial sort mode
  sort_icon <- switch(sort_mode,
    "asc"      = "&#9650; Low\u2192High",
    "original" = "&#9679; Original",
                 "&#9660; High\u2192Low"  # default "desc"
  )

  htmltools::tags$div(
    class = "dash-section",
    `data-section-type` = section_label,
    id = paste0("dash-sec-", section_id),
    htmltools::tags$div(class = "dash-section-title",
      htmltools::HTML(htmltools::htmlEscape(section_label)),
      tier_badges,
      htmltools::tags$button(
        class = "dash-export-btn",
        style = "margin-left:12px;",
        onclick = sprintf("pinGaugeSection('%s')", section_id),
        htmltools::HTML("&#x1F4CC; Pin to Views")
      ),
      htmltools::tags$button(
        class = "dash-export-btn dash-slide-export-btn",
        style = "margin-left:6px;",
        onclick = sprintf("exportDashboardSlide('%s')", section_id),
        htmltools::HTML("&#x1F4F7; Export Slide")
      ),
      htmltools::tags$button(
        class = "dash-export-btn dash-sort-btn",
        style = "margin-left:6px;",
        onclick = sprintf("cycleSortGauges('%s')", section_id),
        htmltools::HTML(sort_icon)
      )
    ),
    htmltools::tags$div(class = "dash-gauges",
                        `data-sort-mode` = sort_mode,
                        gauge_cards)
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
  if (is.null(value) || !is.numeric(value) || is.na(value)) return("N/A")
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
build_svg_gauge <- function(value, metric_type, brand_colour, thresholds,
                            is_hero = FALSE) {

  # Gauge dimensions: compact default, larger for hero

  if (is_hero) {
    svg_w <- 240; svg_h <- 144; font_size <- 32
  } else {
    svg_w <- 130; svg_h <- 78; font_size <- 28
  }

  # Coerce to numeric to prevent character values reaching math operations
  if (!is.numeric(value)) value <- suppressWarnings(as.numeric(as.character(value)))
  if (is.na(value)) {
    # Return a simple N/A gauge
    return(paste0(
      '<svg viewBox="0 0 200 120" width="', svg_w, '" height="', svg_h, '">',
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
    '<svg viewBox="0 0 200 120" width="', svg_w, '" height="', svg_h, '">',
    '<path d="M 20 100 A 80 80 0 0 1 180 100" fill="none" ',
    'stroke="#e2e8f0" stroke-width="12" stroke-linecap="round"/>',
    '<path d="M 20 100 A 80 80 0 0 1 180 100" fill="none" ',
    'stroke="GAUGE_COLOUR" stroke-width="12" stroke-linecap="round" ',
    'stroke-dasharray="FILL_LEN REMAINDER"/>',
    '<text x="100" y="92" text-anchor="middle" ',
    'font-size="', font_size, '" font-weight="700" fill="GAUGE_COLOUR">DISP_VAL</text>',
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
    js_esc(safe_id), js_esc(section_label)
  ))
  html <- paste0(html, '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">')
  html <- paste0(html, '<path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/>')
  html <- paste0(html, '<line x1="12" y1="15" x2="12" y2="3"/></svg> Export Excel</button>')
  html <- paste0(html, '</div>')
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

  cards <- lapply(seq_along(sig_findings), function(i) {
    f <- sig_findings[[i]]
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

    # Show: "10 - Restaurants (9.7) is sig. higher than 12 - Supermarket (9.1). The Total is 9.4"
    finding_text <- sprintf(
      "%s (%s) is sig. higher than %s. The Total is %s",
      f$column_label, col_val_display, comparisons_text, total_val_display
    )

    # Full question text (no truncation — CSS handles wrapping)
    q_text <- f$question_text %||% ""

    # Unique ID for toggle/pin targeting
    sig_id <- sprintf("sig-%s-%s-%d",
      gsub("[^a-zA-Z0-9]", "", f$q_code %||% ""),
      gsub("[^a-zA-Z0-9]", "", f$banner_group %||% ""), i)

    htmltools::tags$div(
      class = "dash-sig-card",
      `data-sig-id` = sig_id,
      # Action bar: toggle visibility + pin individual finding
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
          title = "Pin this finding",
          onclick = sprintf("pinSigCard('%s')", sig_id),
          htmltools::HTML("&#x1F4CC;")
        )
      ),
      # Card content (hidden when toggled off)
      htmltools::tags$div(
        class = "sig-card-content",
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
    )
  })

  htmltools::tags$div(
    class = "dash-section",
    id = "dash-sec-sig-findings",
    htmltools::tags$div(class = "dash-section-title",
      "Significant Findings",
      htmltools::tags$button(
        class = "dash-export-btn",
        style = "margin-left:12px;",
        onclick = "pinVisibleSigFindings()",
        htmltools::HTML("&#x1F4CC; Pin All Visible")
      ),
      htmltools::tags$button(
        class = "dash-export-btn dash-slide-export-btn",
        style = "margin-left:6px;",
        onclick = "exportSigFindingsSlide()",
        htmltools::HTML("&#x1F4F7; Export Slide")
      )
    ),
    htmltools::tags$div(class = "dash-section-sub",
      "Columns significantly higher than others on headline metrics. Click the eye to hide, pin to save individual findings."
    ),
    htmltools::tags$div(class = "dash-sig-grid", cards),
    # State store for toggle visibility persistence
    htmltools::tags$script(type = "application/json", id = "sig-card-states", "{}")
  )
}
