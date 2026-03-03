# ==============================================================================
# CATDRIVER HTML REPORT - CHART BUILDER
# ==============================================================================
# Builds inline SVG charts for catdriver reports.
# Design language: rounded corners (rx=4), muted palette, soft charcoal
# labels (#64748b), faint gridlines, font-weight 500 values / 400 labels.
# NO gradients, drop shadows, or hover lift animations.
# ==============================================================================


#' Build Importance Bar Chart (SVG)
#'
#' Horizontal bar chart showing driver importance, sorted by rank.
#'
#' @param importance List of importance entries from transformer
#' @param brand_colour Brand colour hex string
#' @return htmltools::HTML string containing SVG
#' @keywords internal
build_cd_importance_chart <- function(importance, brand_colour = "#323367") {

  n <- length(importance)
  if (n == 0) return(NULL)

  bar_height <- 28
  gap <- 8
  label_width <- 200
  chart_width <- 600
  bar_area_width <- chart_width - label_width - 60
  total_height <- n * (bar_height + gap) + 40

  max_pct <- max(vapply(importance, function(d) d$importance_pct, numeric(1)))
  if (max_pct == 0) max_pct <- 1

  # Gridlines
  grid_lines <- ""
  for (g in seq(0, 100, by = 25)) {
    if (g > max_pct * 1.1) break
    x_pos <- label_width + (g / max(max_pct * 1.1, 1)) * bar_area_width
    grid_lines <- paste0(grid_lines, sprintf(
      '<line x1="%.1f" y1="20" x2="%.1f" y2="%.0f" stroke="#e2e8f0" stroke-width="1"/>\n',
      x_pos, x_pos, total_height - 5
    ))
    grid_lines <- paste0(grid_lines, sprintf(
      '<text x="%.1f" y="15" text-anchor="middle" font-size="10" fill="#94a3b8" font-weight="400">%d%%</text>\n',
      x_pos, g
    ))
  }

  # Bars
  bars <- ""
  for (i in seq_along(importance)) {
    d <- importance[[i]]
    y <- 25 + (i - 1) * (bar_height + gap)
    bar_w <- max(2, (d$importance_pct / max(max_pct * 1.1, 1)) * bar_area_width)

    # Colour intensity by rank
    opacity <- max(0.4, 1.0 - (i - 1) * 0.12)

    bars <- paste0(bars, sprintf(
      '<text x="%.0f" y="%.1f" text-anchor="end" font-size="12" fill="#334155" font-weight="400" dominant-baseline="central">%s</text>\n',
      label_width - 8, y + bar_height / 2, htmltools::htmlEscape(d$label)
    ))

    bars <- paste0(bars, sprintf(
      '<rect x="%.0f" y="%.1f" width="%.1f" height="%d" rx="4" fill="%s" opacity="%.2f"/>\n',
      label_width, y, bar_w, bar_height, brand_colour, opacity
    ))

    bars <- paste0(bars, sprintf(
      '<text x="%.1f" y="%.1f" font-size="11" fill="#334155" font-weight="500" dominant-baseline="central">%.1f%%</text>\n',
      label_width + bar_w + 6, y + bar_height / 2, d$importance_pct
    ))
  }

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="cd-chart cd-importance-chart" role="img" aria-label="Driver importance bar chart">\n%s\n%s\n</svg>',
    chart_width, total_height, grid_lines, bars
  )

  htmltools::HTML(svg)
}


#' Build Odds Ratio Forest Plot (SVG)
#'
#' Dot plot showing OR with confidence interval whiskers, reference line at 1.0.
#'
#' @param odds_ratios List of OR entries from transformer
#' @param brand_colour Brand colour hex string
#' @param accent_colour Accent colour hex string
#' @return htmltools::HTML string containing SVG
#' @keywords internal
build_cd_forest_plot <- function(odds_ratios, brand_colour = "#323367",
                                  accent_colour = "#CC9900") {

  n <- length(odds_ratios)
  if (n == 0) return(NULL)

  row_height <- 26
  gap <- 6
  label_width <- 220
  chart_width <- 700
  plot_area_width <- chart_width - label_width - 40
  total_height <- n * (row_height + gap) + 50

  # Determine axis range (log scale for OR)
  or_vals <- vapply(odds_ratios, function(r) {
    if (is.na(r$or_value)) 1.0 else r$or_value
  }, numeric(1))

  # Use reasonable bounds
  min_or <- max(0.1, min(or_vals, na.rm = TRUE) * 0.5)
  max_or <- min(20, max(or_vals, na.rm = TRUE) * 1.5)

  # Log scale mapping
  log_min <- log(min_or)
  log_max <- log(max_or)
  log_range <- log_max - log_min
  if (log_range == 0) log_range <- 1

  to_x <- function(or_val) {
    if (is.na(or_val) || or_val <= 0) return(label_width + plot_area_width / 2)
    label_width + ((log(or_val) - log_min) / log_range) * plot_area_width
  }

  # Reference line at OR = 1.0
  ref_x <- to_x(1.0)
  ref_line <- sprintf(
    '<line x1="%.1f" y1="25" x2="%.1f" y2="%.0f" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="4,3"/>\n',
    ref_x, ref_x, total_height - 10
  )
  ref_label <- sprintf(
    '<text x="%.1f" y="18" text-anchor="middle" font-size="10" fill="#94a3b8" font-weight="400">OR = 1.0</text>\n',
    ref_x
  )

  # Zone labels
  less_x <- label_width + plot_area_width * 0.15
  more_x <- label_width + plot_area_width * 0.85
  zone_labels <- sprintf(
    '<text x="%.0f" y="%.0f" text-anchor="middle" font-size="9" fill="#94a3b8" font-style="italic">Lower likelihood</text>\n',
    less_x, total_height - 2
  )
  zone_labels <- paste0(zone_labels, sprintf(
    '<text x="%.0f" y="%.0f" text-anchor="middle" font-size="9" fill="#94a3b8" font-style="italic">Higher likelihood</text>\n',
    more_x, total_height - 2
  ))

  # Points and whiskers
  points <- ""
  for (i in seq_along(odds_ratios)) {
    r <- odds_ratios[[i]]
    y_center <- 30 + (i - 1) * (row_height + gap) + row_height / 2

    # Label
    label_text <- sprintf("%s vs %s", r$comparison, r$reference)
    if (nchar(label_text) > 30) label_text <- paste0(substr(label_text, 1, 27), "...")

    points <- paste0(points, sprintf(
      '<text x="%.0f" y="%.1f" text-anchor="end" font-size="11" fill="#334155" font-weight="400" dominant-baseline="central">%s</text>\n',
      label_width - 8, y_center, htmltools::htmlEscape(label_text)
    ))

    or_val <- r$or_value
    if (is.na(or_val)) next

    x_center <- to_x(or_val)

    # CI whiskers (if available, parse from ci_formatted)
    ci_parts <- tryCatch({
      ci_text <- r$ci_formatted
      nums <- as.numeric(regmatches(ci_text, gregexpr("[0-9]+\\.?[0-9]*", ci_text))[[1]])
      if (length(nums) >= 2) list(lower = nums[1], upper = nums[2]) else NULL
    }, error = function(e) NULL)

    if (!is.null(ci_parts)) {
      x_lo <- to_x(ci_parts$lower)
      x_hi <- to_x(ci_parts$upper)
      # Clamp to plot area
      x_lo <- max(label_width, min(label_width + plot_area_width, x_lo))
      x_hi <- max(label_width, min(label_width + plot_area_width, x_hi))

      points <- paste0(points, sprintf(
        '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="1.5" opacity="0.6"/>\n',
        x_lo, y_center, x_hi, y_center, brand_colour
      ))
      # Whisker caps
      points <- paste0(points, sprintf(
        '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="1.5" opacity="0.6"/>\n',
        x_lo, y_center - 4, x_lo, y_center + 4, brand_colour
      ))
      points <- paste0(points, sprintf(
        '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="1.5" opacity="0.6"/>\n',
        x_hi, y_center - 4, x_hi, y_center + 4, brand_colour
      ))
    }

    # Point
    dot_colour <- if (or_val > 1.0) accent_colour else "#EF4444"
    points <- paste0(points, sprintf(
      '<circle cx="%.1f" cy="%.1f" r="4" fill="%s" stroke="white" stroke-width="1.5"/>\n',
      x_center, y_center, dot_colour
    ))

    # OR value label
    points <- paste0(points, sprintf(
      '<text x="%.1f" y="%.1f" font-size="10" fill="#64748b" font-weight="500" dominant-baseline="central">%.2f</text>\n',
      x_center + 8, y_center - 10, or_val
    ))
  }

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="cd-chart cd-forest-plot" role="img" aria-label="Odds ratio forest plot">\n%s%s%s%s\n</svg>',
    chart_width, total_height, ref_line, ref_label, zone_labels, points
  )

  htmltools::HTML(svg)
}


#' Build Outcome Distribution Chart (SVG)
#'
#' Simple bar chart showing the outcome variable category distribution.
#'
#' @param model_info Model info from transformer
#' @param accent_colour Accent colour hex string
#' @return htmltools::HTML string containing SVG or NULL
#' @keywords internal
build_cd_outcome_chart <- function(model_info, accent_colour = "#CC9900") {

  categories <- model_info$outcome_categories
  n_cats <- length(categories)
  if (n_cats == 0) return(NULL)

  # We don't have raw distribution data in model_info, so this chart

  # is only rendered if we can derive it. For now, return NULL to skip.
  # Future: pass outcome distribution from prep_data.
  return(NULL)
}
