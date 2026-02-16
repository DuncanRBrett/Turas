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
# SEMANTIC COLOUR PALETTE
# ==============================================================================

#' Get semantic colour for a box category label
#'
#' Returns a colour appropriate for common category names.
#' Falls back to brand colour variations for unknown labels.
#'
#' @param label Character, the category label
#' @param index Integer, position in category list (for fallback)
#' @param n_total Integer, total number of categories
#' @param brand_colour Character, hex brand colour
#' @return Character, hex colour
#' @keywords internal
get_semantic_colour <- function(label, index = 1, n_total = 3, brand_colour = "#0d8a8a") {

  label_lower <- tolower(trimws(label))

  # Sentiment / satisfaction spectrum
  # Palette: muted brick-red | pale warm stone | brand teal
  semantic_map <- list(
    # Negative end (muted brick-red)
    "negative"              = "#c0695c",
    "terrible or not good"  = "#c0695c",
    "poor (1-3)"            = "#c0695c",
    "poor"                  = "#c0695c",
    "below average or poor" = "#c0695c",
    "below average"         = "#cf8a7c",
    "dissatisfied"          = "#c0695c",
    "detractor (0-6)"       = "#c0695c",
    "detractor"             = "#c0695c",
    "do not trust"          = "#c0695c",
    "would switch"          = "#c0695c",

    # Neutral / middle (pale warm stone — fades into background)
    "neutral"               = "#d5cfc7",
    "average"               = "#d5cfc7",
    "average (4-6)"         = "#d5cfc7",
    "undecided"             = "#d5cfc7",
    "passive (7-8)"         = "#d5cfc7",
    "passive"               = "#d5cfc7",
    "some trust"            = "#d5cfc7",

    # Positive end (brand teal)
    "positive"              = "#0d8a8a",
    "good or excellent"     = "#0d8a8a",
    "good or excellent (7-10)" = "#0d8a8a",
    "excellent"             = "#0d8a8a",
    "satisfied"             = "#0d8a8a",
    "promoter (9-10)"       = "#0d8a8a",
    "promoter"              = "#0d8a8a",
    "fully trust"           = "#0d8a8a",
    "would not switch"      = "#0d8a8a"
  )

  colour <- semantic_map[[label_lower]]
  if (!is.null(colour)) return(colour)

  # Fallback: use brand colour with varying lightness
  # Parse brand colour
  r <- strtoi(substr(brand_colour, 2, 3), 16L)
  g <- strtoi(substr(brand_colour, 4, 5), 16L)
  b <- strtoi(substr(brand_colour, 6, 7), 16L)

  # Generate shades from light to dark
  if (n_total <= 1) return(brand_colour)
  frac <- (index - 1) / (n_total - 1)  # 0 = lightest, 1 = darkest
  mix <- 0.3 + frac * 0.7  # Range from 30% to 100% of brand colour

  fr <- round(255 - (255 - r) * mix)
  fg <- round(255 - (255 - g) * mix)
  fb <- round(255 - (255 - b) * mix)

  sprintf("#%02x%02x%02x", fr, fg, fb)
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
  legend_row_gap <- 18
  legend_positions <- list()
  leg_x <- label_margin
  leg_row <- 0
  for (i in seq_len(nrow(items))) {
    legend_text <- sprintf("%s (%g%%)", items$label[i], round(items$value[i]))
    item_width <- nchar(legend_text) * 6 + 30
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

    # Label + percentage inside the segment (only if wide enough)
    label_text <- sprintf("%s %s", label, pct_text)
    text_width_approx <- nchar(label_text) * 6.5  # rough estimate

    if (seg_width > text_width_approx + 12) {
      # Fits inside
      text_x <- x_offset + seg_width / 2
      text_y <- bar_y + bar_height / 2
      svg_parts <- c(svg_parts, sprintf(
        '<text x="%g" y="%g" text-anchor="middle" dominant-baseline="central" fill="%s" font-size="11" font-weight="600">%s</text>',
        text_x, text_y, text_fill, htmltools::htmlEscape(label_text)
      ))
    } else if (seg_width > 28) {
      # Only percentage fits
      text_x <- x_offset + seg_width / 2
      text_y <- bar_y + bar_height / 2
      svg_parts <- c(svg_parts, sprintf(
        '<text x="%g" y="%g" text-anchor="middle" dominant-baseline="central" fill="%s" font-size="11" font-weight="600">%s</text>',
        text_x, text_y, text_fill, htmltools::htmlEscape(pct_text)
      ))
    }

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
build_horizontal_bars_svg <- function(items, brand_colour = "#0d8a8a",
                                      chart_width = 680) {

  if (nrow(items) == 0) return("")

  bar_height <- 24
  bar_gap <- 6
  # Dynamic label width based on longest label (~6.2px per char at 11px font)
  max_label_chars <- max(nchar(items$label), na.rm = TRUE)
  label_width <- max(160, ceiling(max_label_chars * 6.2) + 16)
  value_width <- 45
  bar_area_width <- chart_width - label_width - value_width - 20
  # If labels are very long, widen the SVG to keep bars usable
  if (bar_area_width < 200) {
    chart_width <- label_width + value_width + 20 + 300
    bar_area_width <- 300
  }
  top_margin <- 4
  total_height <- top_margin + nrow(items) * (bar_height + bar_gap)
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

#' Build Chart for a Single Question
#'
#' Determines the appropriate chart type and builds an inline SVG chart.
#' Uses BoxCategory from Survey Structure to decide what to chart.
#'
#' @param question_data List from transform_single_question()
#' @param options_df Data frame, Options sheet from Survey Structure
#' @param config_obj Configuration object
#' @return htmltools::HTML object with SVG chart, or NULL if not chartable
#' @export
build_question_chart <- function(question_data, options_df, config_obj) {

  if (is.null(question_data) || is.null(question_data$table_data)) {
    return(NULL)
  }

  q_code <- question_data$q_code
  q_type <- question_data$question_type %||% "Unknown"
  table_data <- question_data$table_data
  brand_colour <- config_obj$brand_colour %||% "#0d8a8a"

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
        # Get unique categories preserving display order
        seen <- character(0)
        for (bc in box_cats) {
          bc <- trimws(bc)
          if (!bc %in% seen) seen <- c(seen, bc)
        }
        box_cat_labels <- seen
        use_box_categories <- TRUE
      }
    }
  }

  # ------------------------------------------------------------------
  # STEP 2: Extract chart data from table_data (Total column only)
  # ------------------------------------------------------------------

  # Find the Total column key (first internal key = TOTAL::Total)
  internal_keys <- grep("^\\.", names(table_data), value = TRUE, invert = TRUE)
  total_key <- internal_keys[1]  # First key is always Total

  if (is.null(total_key) || !total_key %in% names(table_data)) {
    return(NULL)
  }

  chart_items <- data.frame(
    label = character(0),
    value = numeric(0),
    stringsAsFactors = FALSE
  )

  if (use_box_categories) {
    # Chart the box category rows
    for (cat_label in box_cat_labels) {
      # Find matching row in table_data
      # Box categories are classified as "net" type in the transformer
      matching_rows <- which(
        table_data$.row_label == cat_label &
        table_data$.row_type %in% c("net", "category")
      )

      if (length(matching_rows) > 0) {
        row_idx <- matching_rows[1]
        val <- suppressWarnings(as.numeric(table_data[[total_key]][row_idx]))
        if (!is.na(val)) {
          chart_items <- rbind(chart_items, data.frame(
            label = cat_label,
            value = abs(val),  # Use absolute value for display
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  } else {
    # Chart individual category rows (not net, not mean, not base)
    cat_rows <- which(table_data$.row_type == "category")
    for (row_idx in cat_rows) {
      label <- table_data$.row_label[row_idx]
      val <- suppressWarnings(as.numeric(table_data[[total_key]][row_idx]))
      if (!is.na(val) && val >= 0) {
        chart_items <- rbind(chart_items, data.frame(
          label = label,
          value = val,
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  if (nrow(chart_items) == 0) return(NULL)

  # ------------------------------------------------------------------
  # STEP 3: Determine chart type and build SVG
  # ------------------------------------------------------------------

  is_ordinal <- q_type %in% c("Likert", "Rating", "NPS") || use_box_categories
  svg_markup <- ""

  if (is_ordinal && nrow(chart_items) >= 2) {
    # Stacked horizontal bar — add colours
    chart_items$colour <- sapply(seq_len(nrow(chart_items)), function(i) {
      get_semantic_colour(
        chart_items$label[i],
        index = i,
        n_total = nrow(chart_items),
        brand_colour = brand_colour
      )
    })
    svg_markup <- build_stacked_bar_svg(chart_items, chart_id = gsub("[^a-zA-Z0-9]", "-", q_code))
  } else {
    # Horizontal bar chart
    svg_markup <- build_horizontal_bars_svg(chart_items, brand_colour)
  }

  if (nchar(svg_markup) == 0) return(NULL)

  htmltools::HTML(svg_markup)
}
