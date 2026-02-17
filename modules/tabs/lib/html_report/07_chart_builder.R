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
get_semantic_colour <- function(label, index = 1, n_total = 3, brand_colour = "#323367") {

  label_lower <- tolower(trimws(label))

  # Sentiment / satisfaction spectrum
  # Red (negative) -> Amber (moderate negative) -> Grey (neutral) -> Green (positive)
  # Muted, professional tones — not garish primaries
  semantic_map <- list(
    # Strong negative (muted red)
    "negative"              = "#c0695c",
    "terrible or not good"  = "#c0695c",
    "poor (1-3)"            = "#c0695c",
    "poor"                  = "#c0695c",
    "below average or poor" = "#c0695c",
    "dissatisfied (1-5)"    = "#c0695c",
    "detractor (0-6)"       = "#c0695c",
    "detractor"             = "#c0695c",
    "do not trust"          = "#c0695c",
    "would switch"          = "#c0695c",
    "strongly disagree"     = "#c0695c",
    "very dissatisfied"     = "#c0695c",

    # Moderate negative (warm amber)
    "below average"         = "#cf8a7c",
    "dissatisfied"          = "#cf8a7c",
    "disagree"              = "#cf8a7c",

    # Neutral / middle (warm amber/gold — distinct from DK/NA grey)
    "neutral"               = "#e8c170",
    "average"               = "#e8c170",
    "average (4-6)"         = "#e8c170",
    "undecided"             = "#e8c170",
    "passive (7-8)"         = "#e8c170",
    "passive"               = "#e8c170",
    "some trust"            = "#e8c170",
    "neither agree nor disagree" = "#e8c170",
    "average satisfaction"  = "#e8c170",
    "average satisfaction (6-8)" = "#e8c170",

    # Moderate positive (muted green)
    "satisfied"             = "#68a67d",
    "above average"         = "#68a67d",
    "agree"                 = "#68a67d",
    "good"                  = "#68a67d",

    # Strong positive (rich green)
    "positive"              = "#3d8b5e",
    "good or excellent"     = "#3d8b5e",
    "good or excellent (7-10)" = "#3d8b5e",
    "excellent"             = "#3d8b5e",
    "very satisfied (9-10)" = "#3d8b5e",
    "very satisfied"        = "#3d8b5e",
    "promoter (9-10)"       = "#3d8b5e",
    "promoter"              = "#3d8b5e",
    "fully trust"           = "#3d8b5e",
    "would not switch"      = "#3d8b5e",
    "strongly agree"        = "#3d8b5e",

    # DK / NA / Not applicable (light silver-grey — clearly distinct from amber neutral)
    "dk"                    = "#d4d4d4",
    "na"                    = "#d4d4d4",
    "dk/na"                 = "#d4d4d4",
    "dk / na"               = "#d4d4d4",
    "don't know"            = "#d4d4d4",
    "not applicable"        = "#d4d4d4",
    "n/a"                   = "#d4d4d4",
    "refused"               = "#d4d4d4",
    "prefer not to say"     = "#d4d4d4",
    "other"                 = "#c5c0b8"
  )

  colour <- semantic_map[[label_lower]]
  if (!is.null(colour)) return(colour)

  # Fallback: use brand colour with varying lightness
  # Parse brand colour (with validation)
  r <- strtoi(substr(brand_colour, 2, 3), 16L)
  g <- strtoi(substr(brand_colour, 4, 5), 16L)
  b <- strtoi(substr(brand_colour, 6, 7), 16L)
  if (is.na(r) || is.na(g) || is.na(b)) {
    r <- 50L; g <- 51L; b <- 103L  # fallback: #323367
  }

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
    legend_text <- items$label[i]
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
    # Derive display name from key (e.g., "TOTAL::Total" -> "Total")
    parts <- strsplit(key, "::", fixed = TRUE)[[1]]
    display <- if (length(parts) >= 2) parts[2] else key
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
  chart_bar_colour <- config_obj$chart_bar_colour %||% "#323367"

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
                            "^refused$", "^prefer not to say$", "^other$")
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
        n_total = nrow(chart_items), brand_colour = brand_colour
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

  # Add semantic colours for stacked charts
  if (chart_data$chart_type == "stacked") {
    chart_data$colours <- sapply(seq_along(all_col_data$labels), function(i) {
      get_semantic_colour(
        all_col_data$labels[i], index = i,
        n_total = length(all_col_data$labels), brand_colour = brand_colour
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
