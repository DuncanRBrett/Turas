# ==============================================================================
# HTML REPORT - CHART BUILDER (V10.5.0)
# ==============================================================================
# Generates presentation-ready inline SVG charts for crosstab questions.
# - Stacked horizontal bar for ordinal questions (Likert, Rating, NPS)
# - Horizontal bar chart for nominal questions (Single_Response)
# - Uses BoxCategory from Survey Structure when available
# - Total column only
# - Zero external dependencies — pure SVG markup
# ==============================================================================


# ==============================================================================
# COLOUR PALETTE PRESETS
# ==============================================================================
# Five configurable presets for semantic (sentiment) chart colours.
# Each preset defines 5 sentiment stops + DK/NA + Other.
# Presets are designed for board-ready presentations: desaturated,
# sophisticated tones that communicate sentiment without looking like
# traffic lights.
#
# Presets: "warm" (default), "cool", "research", "teal", "red", "brand"
#   warm     — earth tones: dusty rose through sage/teal
#   cool     — muted burgundy through deep teal
#   research — purple-green diverging (colorblind-safe)
#   teal     — monochromatic teal gradient, light to dark
#   red      — monochromatic red gradient, Coca-Cola-inspired muted red
#   brand    — monochromatic gradient generated from brand_colour
# Config field: chart_palette_preset
# Individual overrides: chart_negative_colour, chart_neutral_colour, etc.
# ==============================================================================


#' Get palette colours for a preset
#'
#' Returns a named list of 7 semantic colours for the given preset.
#' Supports individual overrides from config.
#'
#' @param preset Character: "warm", "cool", "research", "teal", "red", or "brand"
#' @param overrides Named list of individual colour overrides (optional).
#'   For "brand" preset, must include \code{brand_colour} hex value.
#' @return Named list with: negative, mod_negative, neutral, mod_positive,
#'         positive, dk_na, other
#' @keywords internal
get_palette_colours <- function(preset = "warm", overrides = NULL) {

  palettes <- list(
    # Warm earth tones — dusty rose through sage/teal
    warm = list(
      negative     = "#b85450",
      mod_negative = "#d4918e",
      neutral      = "#c9a96e",
      mod_positive = "#7daa8c",
      positive     = "#4a7c6f",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    ),
    # Cool professional — muted burgundy through deep teal
    cool = list(
      negative     = "#a65461",
      mod_negative = "#c78f93",
      neutral      = "#94a3b8",
      mod_positive = "#6f9fa8",
      positive     = "#3d7a8a",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    ),
    # Purple-green diverging — research/academic standard (colorblind-safe)
    research = list(
      negative     = "#8e4585",
      mod_negative = "#b891b5",
      neutral      = "#b8b8b8",
      mod_positive = "#7daa8c",
      positive     = "#3d7a5f",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    ),
    # Monochromatic teal — light-to-dark single-hue gradient, muted
    teal = list(
      negative     = "#d4edea",
      mod_negative = "#a3d5cf",
      neutral      = "#6dbfb8",
      mod_positive = "#4a9e95",
      positive     = "#2d7a72",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    ),
    # Monochromatic red — Coca-Cola-inspired, muted (hue ~4°, sat 45%)
    red = list(
      negative     = "#e8cbcb",
      mod_negative = "#cfa0a0",
      neutral      = "#b07272",
      mod_positive = "#8f4d4d",
      positive     = "#6e2b2b",
      dk_na        = "#d1cdc7",
      other        = "#c5c0b8"
    )
  )

  preset_lower <- tolower(preset)

  # "brand" preset: generate monochromatic gradient from brand_colour

  if (preset_lower == "brand") {
    brand_hex <- if (!is.null(overrides$brand_colour) && nzchar(overrides$brand_colour)) {
      overrides$brand_colour
    } else {
      "#323367"  # fallback
    }
    pal <- .generate_mono_palette(brand_hex)
  } else {
    # Select preset (fall back to warm if unrecognised)
    pal <- palettes[[preset_lower]]
    if (is.null(pal)) pal <- palettes[["warm"]]
  }

  # Apply individual overrides from config
  if (!is.null(overrides)) {
    override_map <- list(
      chart_negative_colour     = "negative",
      chart_mod_negative_colour = "mod_negative",
      chart_neutral_colour      = "neutral",
      chart_mod_positive_colour = "mod_positive",
      chart_positive_colour     = "positive",
      chart_dk_colour           = "dk_na"
    )
    for (cfg_key in names(override_map)) {
      if (!is.null(overrides[[cfg_key]]) && nzchar(overrides[[cfg_key]])) {
        pal[[ override_map[[cfg_key]] ]] <- overrides[[cfg_key]]
      }
    }
  }

  pal
}


#' Generate monochromatic palette from a single hex colour
#'
#' Produces 5 gradient stops from light (90% lightness) to dark (30% lightness)
#' at the same hue/saturation, desaturated slightly for a muted look.
#'
#' @param hex Character, hex colour (e.g. "#323367")
#' @return Named list with negative, mod_negative, neutral, mod_positive,
#'         positive, dk_na, other
#' @keywords internal
.generate_mono_palette <- function(hex) {
  # Parse hex to RGB (0-255)
  hex_clean <- sub("^#", "", hex)
  r <- strtoi(substr(hex_clean, 1, 2), 16L) / 255
  g <- strtoi(substr(hex_clean, 3, 4), 16L) / 255
  b <- strtoi(substr(hex_clean, 5, 6), 16L) / 255

  # RGB -> HSL
  cmax <- max(r, g, b)
  cmin <- min(r, g, b)
  delta <- cmax - cmin

  # Lightness
  l <- (cmax + cmin) / 2

  # Saturation
  if (delta == 0) {
    s <- 0
    h <- 0
  } else {
    s <- if (l < 0.5) delta / (cmax + cmin) else delta / (2 - cmax - cmin)
    h <- if (cmax == r) {
      60 * (((g - b) / delta) %% 6)
    } else if (cmax == g) {
      60 * ((b - r) / delta + 2)
    } else {
      60 * ((r - g) / delta + 4)
    }
    if (h < 0) h <- h + 360
  }

  # Desaturate slightly for muted look (cap at 45%)
  s_muted <- min(s, 0.45)

  # Generate 5 lightness stops: light → dark
  lightness_stops <- c(0.88, 0.74, 0.58, 0.44, 0.30)

  hsl_to_hex <- function(h, s, l) {
    c_val <- (1 - abs(2 * l - 1)) * s
    x <- c_val * (1 - abs((h / 60) %% 2 - 1))
    m <- l - c_val / 2
    if (h < 60)       { r1 <- c_val; g1 <- x;     b1 <- 0 }
    else if (h < 120) { r1 <- x;     g1 <- c_val; b1 <- 0 }
    else if (h < 180) { r1 <- 0;     g1 <- c_val; b1 <- x }
    else if (h < 240) { r1 <- 0;     g1 <- x;     b1 <- c_val }
    else if (h < 300) { r1 <- x;     g1 <- 0;     b1 <- c_val }
    else              { r1 <- c_val; g1 <- 0;     b1 <- x }
    ri <- round((r1 + m) * 255)
    gi <- round((g1 + m) * 255)
    bi <- round((b1 + m) * 255)
    sprintf("#%02x%02x%02x", ri, gi, bi)
  }

  colours <- vapply(lightness_stops, function(lv) hsl_to_hex(h, s_muted, lv), character(1))

  list(
    negative     = colours[1],
    mod_negative = colours[2],
    neutral      = colours[3],
    mod_positive = colours[4],
    positive     = colours[5],
    dk_na        = "#d1cdc7",
    other        = "#c5c0b8"
  )
}


#' Parse hex colour to RGB vector
#'
#' @param hex Character, hex colour string (e.g., "#b85450")
#' @return Integer vector of length 3 (R, G, B)
#' @keywords internal
hex_to_rgb <- function(hex) {
  c(
    strtoi(substr(hex, 2, 3), 16L),
    strtoi(substr(hex, 4, 5), 16L),
    strtoi(substr(hex, 6, 7), 16L)
  )
}


# ==============================================================================
# SEMANTIC COLOUR PALETTE
# ==============================================================================

#' Get semantic colour for a box category label
#'
#' Returns a colour appropriate for common category names using the
#' selected palette preset. Falls back to gradient interpolation for
#' unknown labels.
#'
#' @param label Character, the category label
#' @param index Integer, position in category list (for fallback)
#' @param n_total Integer, total number of categories
#' @param brand_colour Character, hex brand colour (unused, kept for API compat)
#' @param palette Named list from get_palette_colours()
#' @return Character, hex colour
#' @keywords internal
get_semantic_colour <- function(label, index = 1, n_total = 3,
                                brand_colour = "#323367", palette = NULL) {

  # Default to warm palette if none provided
  if (is.null(palette)) palette <- get_palette_colours("warm")

  label_lower <- tolower(trimws(label))

  # Sentiment / satisfaction spectrum
  # Desaturated, sophisticated tones — boardroom-ready, not traffic-light
  semantic_map <- list(
    # Strong negative
    "negative"              = palette$negative,
    "terrible or not good"  = palette$negative,
    "poor (1-3)"            = palette$negative,
    "poor"                  = palette$negative,
    "below average or poor" = palette$negative,
    "dissatisfied (1-5)"    = palette$negative,
    "detractor (0-6)"       = palette$negative,
    "detractor"             = palette$negative,
    "do not trust"          = palette$negative,
    "would switch"          = palette$negative,
    "strongly disagree"     = palette$negative,
    "very dissatisfied"     = palette$negative,

    # Moderate negative
    "below average"         = palette$mod_negative,
    "dissatisfied"          = palette$mod_negative,
    "disagree"              = palette$mod_negative,

    # Neutral / middle
    "neutral"               = palette$neutral,
    "average"               = palette$neutral,
    "average (4-6)"         = palette$neutral,
    "undecided"             = palette$neutral,
    "passive (7-8)"         = palette$neutral,
    "passive"               = palette$neutral,
    "some trust"            = palette$neutral,
    "neither agree nor disagree" = palette$neutral,
    "average satisfaction"  = palette$neutral,
    "average satisfaction (6-8)" = palette$neutral,

    # Moderate positive
    "satisfied"             = palette$mod_positive,
    "above average"         = palette$mod_positive,
    "agree"                 = palette$mod_positive,
    "good"                  = palette$mod_positive,

    # Strong positive
    "positive"              = palette$positive,
    "good or excellent"     = palette$positive,
    "good or excellent (7-10)" = palette$positive,
    "excellent"             = palette$positive,
    "very satisfied (9-10)" = palette$positive,
    "very satisfied"        = palette$positive,
    "promoter (9-10)"       = palette$positive,
    "promoter"              = palette$positive,
    "fully trust"           = palette$positive,
    "would not switch"      = palette$positive,
    "strongly agree"        = palette$positive,

    # DK / NA / Not applicable
    "dk"                    = palette$dk_na,
    "na"                    = palette$dk_na,
    "dk/na"                 = palette$dk_na,
    "dk / na"               = palette$dk_na,
    "don't know"            = palette$dk_na,
    "not applicable"        = palette$dk_na,
    "n/a"                   = palette$dk_na,
    "refused"               = palette$dk_na,
    "prefer not to say"     = palette$dk_na,
    "other"                 = palette$other
  )

  colour <- semantic_map[[label_lower]]
  if (!is.null(colour)) return(colour)

  # Fallback: divergent gradient for unknown ordinal labels.
  # Assumes items are ordered negative-to-positive (standard for Likert/Rating).
  # Uses the 5 palette stops as gradient anchors.
  if (n_total <= 1) return(palette$neutral)

  frac <- (index - 1) / (n_total - 1)  # 0.0 = most negative, 1.0 = most positive

  # 5-stop gradient anchors derived from active palette
  anchors <- list(
    hex_to_rgb(palette$negative),      # 0.00
    hex_to_rgb(palette$mod_negative),   # 0.25
    hex_to_rgb(palette$neutral),        # 0.50
    hex_to_rgb(palette$mod_positive),   # 0.75
    hex_to_rgb(palette$positive)        # 1.00
  )
  stops <- c(0, 0.25, 0.5, 0.75, 1.0)

  # Find the two anchor stops that bracket this position
  seg <- 1
  for (s in seq_along(stops)) {
    if (frac >= stops[s]) seg <- s
  }
  if (seg >= length(stops)) seg <- length(stops) - 1

  # Interpolate between the two anchors
  t <- (frac - stops[seg]) / (stops[seg + 1] - stops[seg])
  t <- max(0, min(1, t))
  a1 <- anchors[[seg]]
  a2 <- anchors[[seg + 1]]

  fr <- round(a1[1] + (a2[1] - a1[1]) * t)
  fg <- round(a1[2] + (a2[2] - a1[2]) * t)
  fb <- round(a1[3] + (a2[3] - a1[3]) * t)

  sprintf("#%02x%02x%02x", fr, fg, fb)
}


#' Get Categorical Colour for Non-Ordinal Questions
#'
#' Returns a colour from a muted qualitative palette for nominal data
#' (e.g. regions, brands) where order has no meaning. Uses a Tableau-inspired
#' set of distinguishable, desaturated tones.
#'
#' @param index Integer, 1-based position in the category list
#' @param n_total Integer, total number of categories (unused, reserved)
#' @return Character, hex colour string
#' @keywords internal
get_categorical_colour <- function(index, n_total = 10) {
  # Muted qualitative palette — 10 distinguishable tones

  cat_palette <- c(
    "#5b7e9a",  # steel blue
    "#c47f5a",  # warm terracotta
    "#6a9a7b",  # sage green
    "#9b6b8a",  # dusty plum
    "#b8a04c",  # muted gold
    "#7a8e9e",  # grey-blue
    "#c27878",  # dusty rose
    "#5a8a8a",  # teal
    "#a89060",  # warm khaki
    "#8a7aaa"   # muted lavender
  )
  cat_palette[((index - 1) %% length(cat_palette)) + 1]
}


# ==============================================================================
# STACKED HORIZONTAL BAR (ORDINAL QUESTIONS)
# ==============================================================================

#' Build Stacked Horizontal Bar SVG
#'
#' Creates a single stacked horizontal bar showing category distribution.
#' Used for Likert, Rating, and NPS questions.
#'
#' @param items Data frame with columns: label, value (percentage), colour
#' @param bar_width Numeric, total SVG width
#' @return Character, SVG markup
#' @keywords internal
build_stacked_bar_svg <- function(items, bar_width = 680, chart_id = NULL) {

  if (nrow(items) == 0) return("")

  # Generate unique clip-path ID to avoid collisions across multiple inline SVGs
  if (is.null(chart_id)) {
    chart_id <- paste0(sample(c(letters, 0:9), 8, replace = TRUE), collapse = "")
  }
  clip_id <- paste0("bar-clip-", chart_id)

  bar_height <- 36
  bar_y <- 8
  bar_rx <- 5
  legend_y_start <- bar_y + bar_height + 24
  legend_item_h <- 16
  label_margin <- 10  # left margin for the bar area
  usable_width <- bar_width - (label_margin * 2)

  # Pre-calculate legend layout to determine total height (may wrap to multiple rows)
  # Legend includes percentage values for clarity
  legend_row_gap <- 18
  legend_positions <- list()
  leg_x <- label_margin
  leg_row <- 0
  total_for_pct <- sum(items$value, na.rm = TRUE)
  for (i in seq_len(nrow(items))) {
    pct_val <- if (total_for_pct > 0) round(items$value[i]) else 0
    legend_text <- sprintf("%s (%g%%)", items$label[i], pct_val)
    item_width <- nchar(legend_text) * 5.8 + 30  # ~5.8px per char at 10.5px font
    # Wrap to next row if this item would overflow
    if (leg_x + item_width > bar_width - label_margin && i > 1) {
      leg_row <- leg_row + 1
      leg_x <- label_margin
    }
    legend_positions[[i]] <- list(x = leg_x, row = leg_row, text = legend_text)
    leg_x <- leg_x + item_width
  }
  legend_rows <- leg_row + 1
  total_height <- legend_y_start + (legend_rows * legend_row_gap) + 8

  # Normalise values to sum to 100 (handle rounding)
  total <- sum(items$value, na.rm = TRUE)
  if (total <= 0) return("")

  svg_parts <- character(0)

  # SVG header
  svg_parts <- c(svg_parts, sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" role="img" aria-label="Distribution chart" style="font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Roboto,sans-serif;">',
    bar_width, total_height
  ))

  # Single rounded clip-path for the whole bar — segments are flat rects inside
  svg_parts <- c(svg_parts, sprintf(
    '<defs><clipPath id="%s"><rect x="%d" y="%d" width="%g" height="%d" rx="%d" ry="%d"/></clipPath></defs>',
    clip_id, label_margin, bar_y, usable_width, bar_height, bar_rx, bar_rx
  ))

  # Build bar segments (flat rects clipped by the rounded bar shape)
  x_offset <- label_margin
  seg_edges <- numeric(0)  # track segment boundaries for separator lines
  for (i in seq_len(nrow(items))) {
    pct <- items$value[i]
    seg_width <- (pct / total) * usable_width
    colour <- items$colour[i]
    label <- items$label[i]
    pct_text <- sprintf("%g%%", round(pct))

    if (seg_width < 1) next

    # Skip tiny segments (< 3% of total) — they render as visual noise.
    # Data is still shown in the legend with percentages.
    pct_of_total <- (pct / total) * 100
    if (pct_of_total < 3) {
      x_offset <- x_offset + seg_width
      if (i < nrow(items)) seg_edges <- c(seg_edges, x_offset)
      next
    }

    # Bar segment rect (clipped by rounded bar shape)
    svg_parts <- c(svg_parts, sprintf(
      '<rect x="%g" y="%d" width="%g" height="%d" fill="%s" clip-path="url(#%s)"/>',
      x_offset, bar_y, seg_width, bar_height, colour, clip_id
    ))

    # Determine text colour — dark text on pale backgrounds, white on dark
    cr <- strtoi(substr(colour, 2, 3), 16L)
    cg <- strtoi(substr(colour, 4, 5), 16L)
    cb <- strtoi(substr(colour, 6, 7), 16L)
    luminance <- (0.299 * cr + 0.587 * cg + 0.114 * cb) / 255
    text_fill <- if (luminance > 0.65) "#5c4a3a" else "#ffffff"

    # Percentage label inside the segment (category names are in the legend)
    # pct_of_total already computed above (for the < 3% skip check)
    text_x <- x_offset + seg_width / 2
    text_y <- bar_y + bar_height / 2

    if (pct_of_total >= 8) {
      # Show percentage inside segment (legend identifies the category)
      svg_parts <- c(svg_parts, sprintf(
        '<text x="%g" y="%g" text-anchor="middle" dominant-baseline="central" fill="%s" font-size="12" font-weight="500" style="font-variant-numeric:tabular-nums">%s</text>',
        text_x, text_y, text_fill, htmltools::htmlEscape(pct_text)
      ))
    }
    # Segments 3-8%: visible rect but no label (rely on legend)

    x_offset <- x_offset + seg_width
    if (i < nrow(items)) seg_edges <- c(seg_edges, x_offset)
  }

  # White separator lines between segments (drawn after all rects, also clipped)
  for (sep_x in seg_edges) {
    svg_parts <- c(svg_parts, sprintf(
      '<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#ffffff" stroke-width="1.5" clip-path="url(#%s)"/>',
      sep_x, bar_y, sep_x, bar_y + bar_height, clip_id
    ))
  }

  # Legend below the bar (uses pre-calculated positions with row wrapping)
  for (i in seq_len(nrow(items))) {
    colour <- items$colour[i]
    pos <- legend_positions[[i]]
    legend_y <- legend_y_start + pos$row * legend_row_gap

    # Colour dot swatch (circle)
    svg_parts <- c(svg_parts, sprintf(
      '<circle cx="%g" cy="%g" r="4.5" fill="%s"/>',
      pos$x + 4.5, legend_y + 5, colour
    ))

    # Label text
    svg_parts <- c(svg_parts, sprintf(
      '<text x="%g" y="%g" fill="#64748b" font-size="10.5">%s</text>',
      pos$x + 13, legend_y + 9, htmltools::htmlEscape(pos$text)
    ))
  }

  svg_parts <- c(svg_parts, '</svg>')
  paste(svg_parts, collapse = "\n")
}


# ==============================================================================
# HORIZONTAL BAR CHART (NOMINAL QUESTIONS)
# ==============================================================================

#' Build Horizontal Bar Chart SVG
#'
#' Creates individual horizontal bars for each category.
#' Used for Single_Response questions without ordered categories.
#'
#' @param items Data frame with columns: label, value (percentage)
#' @param brand_colour Character, hex brand colour
#' @param chart_width Numeric, total SVG width
#' @return Character, SVG markup
#' @keywords internal
build_horizontal_bars_svg <- function(items, brand_colour = "#323367",
                                      chart_width = 680) {

  if (nrow(items) == 0) return("")

  bar_height <- 24
  bar_gap <- 6
  # Dynamic label width based on longest label (~6.2px per char at 11px font)
  max_label_chars <- max(nchar(items$label), na.rm = TRUE)
  label_width <- max(160, ceiling(max_label_chars * 6.2) + 16)
  value_width <- 45
  right_pad <- 50  # space for percentage text beyond bar end
  bar_area_width <- chart_width - label_width - value_width - right_pad
  # If labels are very long, widen the SVG to keep bars usable
  if (bar_area_width < 200) {
    chart_width <- label_width + value_width + right_pad + 300
    bar_area_width <- 300
  }
  top_margin <- 4
  bottom_pad <- 8
  total_height <- top_margin + nrow(items) * (bar_height + bar_gap) + bottom_pad
  max_val <- max(items$value, na.rm = TRUE)
  if (max_val <= 0) max_val <- 1

  svg_parts <- character(0)

  svg_parts <- c(svg_parts, sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" role="img" aria-label="Bar chart" style="font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Roboto,sans-serif;">',
    chart_width, total_height
  ))

  for (i in seq_len(nrow(items))) {
    y <- top_margin + (i - 1) * (bar_height + bar_gap)
    label <- items$label[i]
    val <- items$value[i]
    pct_text <- sprintf("%g%%", round(val))
    bar_w <- max((val / max_val) * bar_area_width, 2)

    # Wrap each bar in a <g> with data attributes for JS sort
    svg_parts <- c(svg_parts, sprintf(
      '<g class="chart-bar-group" data-bar-label="%s" data-bar-value="%g" data-bar-index="%d" transform="translate(0,%g)">',
      htmltools::htmlEscape(label), val, i - 1L, y
    ))

    # Category label (right-aligned in label area)
    svg_parts <- c(svg_parts, sprintf(
      '<text x="%d" y="%g" text-anchor="end" dominant-baseline="central" fill="#374151" font-size="11" font-weight="500">%s</text>',
      label_width - 8, bar_height / 2, htmltools::htmlEscape(label)
    ))

    # Bar
    svg_parts <- c(svg_parts, sprintf(
      '<rect x="%d" y="0" width="%g" height="%d" rx="3" fill="%s" opacity="0.85"/>',
      label_width, bar_w, bar_height, brand_colour
    ))

    # Value label (right of bar)
    svg_parts <- c(svg_parts, sprintf(
      '<text x="%g" y="%g" dominant-baseline="central" fill="#64748b" font-size="11" font-weight="600">%s</text>',
      label_width + bar_w + 8, bar_height / 2, pct_text
    ))

    svg_parts <- c(svg_parts, '</g>')
  }

  svg_parts <- c(svg_parts, '</svg>')
  paste(svg_parts, collapse = "\n")
}


# ==============================================================================
# MAIN CHART BUILDER
# ==============================================================================

#' Extract Chart Row Indices
#'
#' Identifies which rows in table_data should be charted, based on
#' box categories (if available) or individual category rows.
#'
#' @param table_data Data frame from transform_single_question()
#' @param box_cat_labels Character vector of box category labels, or NULL
#' @return Integer vector of row indices
#' @keywords internal
get_chart_row_indices <- function(table_data, box_cat_labels = NULL) {
  if (!is.null(box_cat_labels)) {
    indices <- integer(0)
    for (cat_label in box_cat_labels) {
      matching <- which(
        table_data$.row_label == cat_label &
        table_data$.row_type %in% c("net", "category")
      )
      if (length(matching) > 0) indices <- c(indices, matching[1])
    }
    indices
  } else {
    which(table_data$.row_type == "category")
  }
}


#' Extract Chart Data for All Columns
#'
#' Reads pre-calculated values from table_data for all internal keys.
#' Returns a structured list suitable for JSON embedding and JS chart rendering.
#'
#' @param table_data Data frame from transform_single_question()
#' @param row_indices Integer vector from get_chart_row_indices()
#' @param use_box_categories Logical, whether items are box categories
#' @return List with items (labels) and columns (keyed by internal key)
#' @keywords internal
extract_all_column_chart_data <- function(table_data, row_indices, use_box_categories) {
  # Get internal keys (non-dot-prefixed columns)
  internal_keys <- grep("^\\.", names(table_data), value = TRUE, invert = TRUE)
  if (length(internal_keys) == 0 || length(row_indices) == 0) return(NULL)

  # Extract labels from the matching rows
  labels <- table_data$.row_label[row_indices]

  # Build column data: one entry per internal key, values aligned with labels
  columns <- list()
  for (key in internal_keys) {
    vals <- suppressWarnings(as.numeric(table_data[[key]][row_indices]))
    if (use_box_categories) vals <- abs(vals)
    # Replace NA with 0 for charting
    vals[is.na(vals)] <- 0
    # Derive display name from key (e.g., "TOTAL::Total" -> "Total",
    # "Q002::BOXCAT::Online campus" -> "Online campus")
    parts <- strsplit(key, "::", fixed = TRUE)[[1]]
    display <- if (length(parts) >= 2) parts[length(parts)] else key
    columns[[key]] <- list(display = display, values = vals)
  }

  list(labels = labels, columns = columns)
}


#' Build Chart for a Single Question
#'
#' Determines the appropriate chart type and builds an inline SVG chart.
#' Also extracts chart data for ALL columns and returns it as a JSON-ready
#' structure for JS-driven multi-column chart rendering.
#'
#' @param question_data List from transform_single_question()
#' @param options_df Data frame, Options sheet from Survey Structure
#' @param config_obj Configuration object
#' @return List with svg (htmltools::HTML) and chart_data (list for JSON),
#'         or NULL if not chartable
#' @export
build_question_chart <- function(question_data, options_df, config_obj) {

  if (is.null(question_data) || is.null(question_data$table_data)) {
    return(NULL)
  }

  # Validate options_df structure if provided
  if (!is.null(options_df) && !is.data.frame(options_df)) {
    cat(sprintf("  [WARNING] build_question_chart: options_df is not a data.frame for %s\n",
                question_data$q_code %||% "unknown"))
    return(NULL)
  }

  q_code <- question_data$q_code
  q_type <- question_data$question_type %||% "Unknown"
  table_data <- question_data$table_data
  brand_colour <- config_obj$brand_colour %||% "#323367"
  chart_bar_colour <- config_obj$chart_bar_colour %||% brand_colour

  # Build palette from preset + any individual overrides
  palette_preset <- config_obj$chart_palette_preset %||% "warm"
  chart_palette <- get_palette_colours(palette_preset, overrides = config_obj)

  # Skip composite metrics (they only have a summary row)
  if (q_type == "Composite") return(NULL)

  # ------------------------------------------------------------------
  # STEP 1: Determine what to chart — box categories or individual items
  # ------------------------------------------------------------------

  use_box_categories <- FALSE
  box_cat_labels <- NULL

  if (!is.null(options_df) && "BoxCategory" %in% names(options_df)) {
    q_options <- options_df[options_df$QuestionCode == q_code, , drop = FALSE]
    if (nrow(q_options) > 0) {
      box_cats <- q_options$BoxCategory
      box_cats <- box_cats[!is.na(box_cats) & nzchar(trimws(box_cats))]
      if (length(box_cats) > 0) {
        seen <- character(0)
        for (bc in box_cats) {
          bc <- trimws(bc)
          if (!bc %in% seen) seen <- c(seen, bc)
        }
        # Filter out DK/NA-only box categories -- these are not substantive
        # chart categories and should not trigger stacked bar mode
        dk_na_patterns <- c("^dk$", "^na$", "^dk/na$", "^dk / na$",
                            "^don't know$", "^not applicable$", "^n/a$",
                            "^refused$", "^prefer not to say$",
                            "^other$")  # "Other" is non-substantive like DK/NA: a catch-all, not a real category
        substantive <- vapply(seen, function(lbl) {
          !any(grepl(paste(dk_na_patterns, collapse = "|"),
                     tolower(trimws(lbl))))
        }, logical(1))
        if (sum(substantive) >= 2) {
          box_cat_labels <- seen
          use_box_categories <- TRUE
        }
        # If only DK/NA categories exist, fall through to individual rows
      }
    }
  }

  # ------------------------------------------------------------------
  # STEP 2: Identify chart rows and extract data for ALL columns
  # ------------------------------------------------------------------

  row_indices <- get_chart_row_indices(table_data, box_cat_labels)
  if (length(row_indices) == 0) return(NULL)

  all_col_data <- extract_all_column_chart_data(
    table_data, row_indices, use_box_categories
  )
  if (is.null(all_col_data)) return(NULL)

  # Verify at least some non-zero values exist
  total_key <- names(all_col_data$columns)[1]
  total_vals <- all_col_data$columns[[total_key]]$values
  if (all(total_vals == 0)) return(NULL)

  # ------------------------------------------------------------------
  # STEP 3: Build initial SVG (Total column only) and chart metadata
  # ------------------------------------------------------------------

  is_ordinal <- q_type %in% c("Likert", "Rating", "NPS") || use_box_categories

  # Build chart_items for the initial Total-only SVG
  chart_items <- data.frame(
    label = all_col_data$labels,
    value = total_vals,
    stringsAsFactors = FALSE
  )
  chart_items <- chart_items[chart_items$value > 0, , drop = FALSE]
  if (nrow(chart_items) == 0) return(NULL)

  svg_markup <- ""
  if (is_ordinal && nrow(chart_items) >= 2) {
    chart_items$colour <- sapply(seq_len(nrow(chart_items)), function(i) {
      get_semantic_colour(
        chart_items$label[i], index = i,
        n_total = nrow(chart_items), brand_colour = brand_colour,
        palette = chart_palette
      )
    })
    svg_markup <- build_stacked_bar_svg(
      chart_items, chart_id = gsub("[^a-zA-Z0-9]", "-", q_code)
    )
  } else {
    svg_markup <- build_horizontal_bars_svg(chart_items, chart_bar_colour)
  }

  if (nchar(svg_markup) == 0) return(NULL)

  # Build chart data for JSON embedding (JS reads this to rebuild charts)
  chart_data <- list(
    chart_type = if (is_ordinal && nrow(chart_items) >= 2) "stacked" else "horizontal",
    labels = all_col_data$labels,
    brand_colour = brand_colour,
    chart_bar_colour = chart_bar_colour,
    columns = all_col_data$columns
  )

  # Add semantic colours for stacked charts (using active palette)
  if (chart_data$chart_type == "stacked") {
    chart_data$colours <- sapply(seq_along(all_col_data$labels), function(i) {
      get_semantic_colour(
        all_col_data$labels[i], index = i,
        n_total = length(all_col_data$labels), brand_colour = brand_colour,
        palette = chart_palette
      )
    })
  }

  # ------------------------------------------------------------------
  # STEP 4: Extract priority metric per column (if configured)
  # ------------------------------------------------------------------
  # Supports comma-separated cascade: "Mean, NPS Score" tries Mean first,

  # falls back to NPS Score if Mean row not found for this question.
  priority_metric_cfg <- config_obj$priority_metric
  if (!is.null(priority_metric_cfg) && nzchar(trimws(priority_metric_cfg))) {
    metric_candidates <- trimws(strsplit(priority_metric_cfg, ",")[[1]])
    internal_keys <- grep("^\\.", names(table_data), value = TRUE, invert = TRUE)
    mean_rows <- which(table_data$.row_type == "mean")

    # Try each candidate in priority order -- use first match
    match_idx <- NULL
    for (candidate in metric_candidates) {
      for (mi in mean_rows) {
        if (grepl(candidate, table_data$.row_label[mi], ignore.case = TRUE)) {
          match_idx <- mi
          break
        }
      }
      if (!is.null(match_idx)) break
    }

    if (!is.null(match_idx)) {
      metric_vals <- list()
      for (key in internal_keys) {
        val <- suppressWarnings(as.numeric(table_data[[key]][match_idx]))
        metric_vals[[key]] <- if (!is.na(val)) val else NULL
      }
      # Determine decimal places from config (match metric type)
      metric_decimals <- config_obj$decimal_places_ratings %||% 1
      chart_data$priority_metric <- list(
        label = table_data$.row_label[match_idx],
        values = metric_vals,
        decimals = metric_decimals
      )
    }
  }

  list(
    svg = htmltools::HTML(svg_markup),
    chart_data = chart_data
  )
}
