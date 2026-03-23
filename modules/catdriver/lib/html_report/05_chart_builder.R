# ==============================================================================
# CATDRIVER HTML REPORT - CHART BUILDER
# ==============================================================================
# Builds inline SVG charts for catdriver reports.
# Design language: rounded corners (rx=4), muted palette, soft charcoal
# labels (#64748b), faint gridlines, font-weight 500 values / 400 labels.
# NO gradients, drop shadows, or hover lift animations.
# ==============================================================================


# --- Design token constants (aligned with shared design system) ---
.cd_font_family  <- "'Inter', system-ui, -apple-system, 'Segoe UI', sans-serif"
.cd_label_colour <- "#64748b"
.cd_value_colour <- "#334155"
.cd_grid_colour  <- "#e2e8f0"
.cd_muted_colour <- "#94a3b8"


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
      '<line x1="%.1f" y1="20" x2="%.1f" y2="%.0f" stroke="%s" stroke-width="1"/>\n',
      x_pos, x_pos, total_height - 5, .cd_grid_colour
    ))
    grid_lines <- paste0(grid_lines, sprintf(
      '<text x="%.1f" y="15" text-anchor="middle" font-size="10" fill="%s" font-weight="400">%d%%</text>\n',
      x_pos, .cd_muted_colour, g
    ))
  }

  # Bars — each wrapped in <g class="cd-importance-row"> for filtering
  bars <- ""
  for (i in seq_along(importance)) {
    d <- importance[[i]]
    y <- 25 + (i - 1) * (bar_height + gap)
    bar_w <- max(2, (d$importance_pct / max(max_pct * 1.1, 1)) * bar_area_width)

    # Colour intensity by rank
    opacity <- max(0.4, 1.0 - (i - 1) * 0.12)

    # Determine significance from p-value or significance stars
    is_sig <- if (!is.null(d$p_value) && !is.na(d$p_value)) {
      d$p_value < 0.05
    } else if (!is.null(d$significance) && nchar(d$significance) > 0) {
      grepl("\\*", d$significance)
    } else {
      d$importance_pct >= 2.0
    }

    # Open group with data attributes for filtering
    bars <- paste0(bars, sprintf(
      '<g class="cd-importance-row" data-cd-rank="%d" data-cd-pct="%.1f" data-cd-sig="%s">\n',
      i, d$importance_pct, if (is_sig) "yes" else "no"
    ))

    bars <- paste0(bars, sprintf(
      '<text x="%.0f" y="%.1f" text-anchor="end" font-size="12" fill="%s" font-weight="400" dominant-baseline="central">%s</text>\n',
      label_width - 8, y + bar_height / 2, .cd_value_colour, htmltools::htmlEscape(d$label)
    ))

    bars <- paste0(bars, sprintf(
      '<rect x="%.0f" y="%.1f" width="%.1f" height="%d" rx="4" fill="%s" opacity="%.2f"/>\n',
      label_width, y, bar_w, bar_height, brand_colour, opacity
    ))

    bars <- paste0(bars, sprintf(
      '<text x="%.1f" y="%.1f" font-size="11" fill="%s" font-weight="500" dominant-baseline="central">%.1f%%</text>\n',
      label_width + bar_w + 6, y + bar_height / 2, .cd_value_colour, d$importance_pct
    ))

    bars <- paste0(bars, '</g>\n')
  }

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="cd-chart cd-importance-chart" role="img" aria-label="Driver importance bar chart" style="font-family:%s;">\n%s\n%s\n</svg>',
    chart_width, total_height, .cd_font_family, grid_lines, bars
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

  # Use reasonable bounds — dynamic cap based on data spread
  # If most ORs are modest but a few are extreme, cap at a sensible level
  # to keep the majority readable. Extreme values get off-scale notation.
  or_median <- stats::median(or_vals, na.rm = TRUE)
  or_p90 <- stats::quantile(or_vals, 0.90, na.rm = TRUE, names = FALSE)
  # Cap at: max of (3× the 90th percentile, 20) but never above max_val if all are modest
  dynamic_cap <- max(20, or_p90 * 3)
  min_or <- max(0.1, min(or_vals, na.rm = TRUE) * 0.5)
  max_or <- min(dynamic_cap, max(or_vals, na.rm = TRUE) * 1.5)

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
    '<line x1="%.1f" y1="25" x2="%.1f" y2="%.0f" stroke="%s" stroke-width="1.5" stroke-dasharray="4,3"/>\n',
    ref_x, ref_x, total_height - 10, .cd_muted_colour
  )
  ref_label <- sprintf(
    '<text x="%.1f" y="18" text-anchor="middle" font-size="10" fill="%s" font-weight="400">OR = 1.0</text>\n',
    ref_x, .cd_muted_colour
  )

  # Zone labels
  less_x <- label_width + plot_area_width * 0.15
  more_x <- label_width + plot_area_width * 0.85
  zone_labels <- sprintf(
    '<text x="%.0f" y="%.0f" text-anchor="middle" font-size="9" fill="%s" font-style="italic">Lower likelihood</text>\n',
    less_x, total_height - 2, .cd_muted_colour
  )
  zone_labels <- paste0(zone_labels, sprintf(
    '<text x="%.0f" y="%.0f" text-anchor="middle" font-size="9" fill="%s" font-style="italic">Higher likelihood</text>\n',
    more_x, total_height - 2, .cd_muted_colour
  ))

  # Points and whiskers — each row wrapped in <g data-cd-factor="...">
  points <- ""
  for (i in seq_along(odds_ratios)) {
    r <- odds_ratios[[i]]
    y_center <- 30 + (i - 1) * (row_height + gap) + row_height / 2

    # Wrap each row in a group with factor label for chip filtering
    factor_label <- htmltools::htmlEscape(r$factor_label %||% "")
    points <- paste0(points, sprintf(
      '<g class="cd-forest-row" data-cd-factor="%s">\n',
      factor_label
    ))

    # Label — wrap long labels to two lines, splitting at "vs" for readability
    label_text <- sprintf("%s vs %s", r$comparison, r$reference)
    label_x <- label_width - 8
    vs_pos <- regexpr(" vs ", label_text, fixed = TRUE)

    if (nchar(label_text) > 32 && vs_pos > 0) {
      # Split at "vs" for natural two-line break
      # If comparison is short (< 15 chars), keep "vs" on line 1 for balance
      if (vs_pos <= 15) {
        line1 <- trimws(substr(label_text, 1, vs_pos + 2))   # "X vs"
        line2 <- trimws(substr(label_text, vs_pos + 4, nchar(label_text)))
      } else {
        line1 <- trimws(substr(label_text, 1, vs_pos - 1))
        line2 <- paste0("vs ", trimws(substr(label_text, vs_pos + 4, nchar(label_text))))
      }
      points <- paste0(points, sprintf(
        '<text x="%.0f" y="%.1f" text-anchor="end" font-size="11" fill="%s" font-weight="400"><tspan x="%.0f" dy="-0.5em">%s</tspan><tspan x="%.0f" dy="1.2em">%s</tspan></text>\n',
        label_x, y_center, .cd_value_colour, label_x, htmltools::htmlEscape(line1),
        label_x, htmltools::htmlEscape(line2)
      ))
    } else {
      points <- paste0(points, sprintf(
        '<text x="%.0f" y="%.1f" text-anchor="end" font-size="11" fill="%s" font-weight="400" dominant-baseline="central">%s</text>\n',
        label_x, y_center, .cd_value_colour, htmltools::htmlEscape(label_text)
      ))
    }

    or_val <- r$or_value
    if (!is.na(or_val)) {
      x_center <- to_x(or_val)

      # Detect off-scale values (beyond visible plot area)
      plot_right <- label_width + plot_area_width
      plot_left <- label_width
      off_scale_right <- or_val > max_or
      off_scale_left <- or_val < min_or

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
        x_lo <- max(plot_left, min(plot_right, x_lo))
        x_hi <- max(plot_left, min(plot_right, x_hi))

        ci_off_right <- ci_parts$upper > max_or
        ci_off_left <- ci_parts$lower < min_or

        points <- paste0(points, sprintf(
          '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="1.5" opacity="0.6"/>\n',
          x_lo, y_center, x_hi, y_center, brand_colour
        ))
        # Whisker caps — only draw cap if CI bound is within scale
        if (!ci_off_left) {
          points <- paste0(points, sprintf(
            '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="1.5" opacity="0.6"/>\n',
            x_lo, y_center - 4, x_lo, y_center + 4, brand_colour
          ))
        }
        if (!ci_off_right) {
          points <- paste0(points, sprintf(
            '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="1.5" opacity="0.6"/>\n',
            x_hi, y_center - 4, x_hi, y_center + 4, brand_colour
          ))
        }

        # Arrow indicators when CI extends beyond scale
        if (ci_off_right) {
          points <- paste0(points, sprintf(
            '<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s" opacity="0.5"/>\n',
            plot_right - 1, y_center,
            plot_right - 7, y_center - 4,
            plot_right - 7, y_center + 4,
            brand_colour
          ))
        }
        if (ci_off_left) {
          points <- paste0(points, sprintf(
            '<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s" opacity="0.5"/>\n',
            plot_left + 1, y_center,
            plot_left + 7, y_center - 4,
            plot_left + 7, y_center + 4,
            brand_colour
          ))
        }
      }

      # Point — clamp to plot area if off-scale
      x_clamped <- max(plot_left, min(plot_right, x_center))
      dot_colour <- if (or_val > 1.0) accent_colour else "#EF4444"

      if (off_scale_right || off_scale_left) {
        # Off-scale: draw a small diamond marker at the edge
        points <- paste0(points, sprintf(
          '<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s" stroke="white" stroke-width="1"/>\n',
          x_clamped, y_center - 5,
          x_clamped + 5, y_center,
          x_clamped, y_center + 5,
          x_clamped - 5, y_center,
          dot_colour
        ))
        # Off-scale OR value with arrow notation
        or_display <- if (or_val >= 100) sprintf("%.0f", or_val)
                      else if (or_val >= 10) sprintf("%.1f", or_val)
                      else sprintf("%.2f", or_val)
        arrow <- if (off_scale_right) "\u2192 " else "\u2190 "
        anchor <- if (off_scale_right) "end" else "start"
        label_x_pos <- if (off_scale_right) x_clamped - 8 else x_clamped + 8
        points <- paste0(points, sprintf(
          '<text x="%.1f" y="%.1f" font-size="10" fill="%s" font-weight="600" text-anchor="%s" dominant-baseline="central">%s%s</text>\n',
          label_x_pos, y_center - 10, dot_colour, anchor, arrow, or_display
        ))
      } else {
        # Normal: standard circle point
        points <- paste0(points, sprintf(
          '<circle cx="%.1f" cy="%.1f" r="4" fill="%s" stroke="white" stroke-width="1.5"/>\n',
          x_center, y_center, dot_colour
        ))
        # OR value label
        points <- paste0(points, sprintf(
          '<text x="%.1f" y="%.1f" font-size="10" fill="%s" font-weight="500" dominant-baseline="central">%.2f</text>\n',
          x_center + 8, y_center - 10, .cd_label_colour, or_val
        ))
      }
    }

    # Close group
    points <- paste0(points, '</g>\n')
  }

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="cd-chart cd-forest-plot" role="img" aria-label="Odds ratio forest plot" style="font-family:%s;">\n%s%s%s%s\n</svg>',
    chart_width, total_height, .cd_font_family, ref_line, ref_label, zone_labels, points
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


#' Build Probability Lift Diverging Bar Chart (SVG)
#'
#' Horizontal diverging bar chart showing probability lift per category,
#' grouped by driver. Bars extend left (negative) or right (positive)
#' from a centre zero line. Reference categories are omitted.
#'
#' @param probability_lifts Named list of per-driver lift data (from transformer)
#' @param brand_colour Brand colour hex string (used for positive bars)
#' @param accent_colour Accent colour hex string (unused, kept for consistency)
#' @return htmltools::HTML string containing SVG, or NULL if no data
#' @keywords internal
build_cd_probability_lift_chart <- function(probability_lifts,
                                             brand_colour = "#323367",
                                             accent_colour = "#CC9900") {

  if (is.null(probability_lifts) || length(probability_lifts) == 0) return(NULL)

  # Flatten all non-reference categories across drivers
  rows <- list()
  for (var_name in names(probability_lifts)) {
    pl <- probability_lifts[[var_name]]
    non_ref <- Filter(function(c) !isTRUE(c$is_reference), pl$categories)
    if (length(non_ref) > 0) {
      ref_label <- if (!is.null(pl$reference) && nzchar(pl$reference)) pl$reference else NULL
      driver_label <- pl$label
      rows <- c(rows, list(list(type = "header", label = driver_label,
                                reference = ref_label, driver = driver_label)))
      for (cat in non_ref) {
        rows <- c(rows, list(list(
          type = "bar",
          label = cat$level,
          lift_pct = cat$lift_pct,
          prob = cat$mean_prob,
          driver = driver_label
        )))
      }
    }
  }

  if (length(rows) == 0) return(NULL)

  # Layout — wider chart for better axis readability
  bar_height <- 24
  header_height <- 28
  gap <- 6
  label_width <- 200
  chart_width <- 900
  bar_area_width <- chart_width - label_width - 60
  half_bar <- bar_area_width / 2
  zero_x <- label_width + half_bar

  # Calculate height
  total_height <- 30  # top padding
  for (r in rows) {
    if (r$type == "header") total_height <- total_height + header_height + gap
    else total_height <- total_height + bar_height + gap
  }
  total_height <- total_height + 20  # bottom padding

  # Find max absolute lift for scaling
  all_lifts <- vapply(rows, function(r) {
    if (r$type == "bar") abs(r$lift_pct) else 0
  }, numeric(1))
  max_lift <- max(all_lifts, 5, na.rm = TRUE)  # minimum scale of 5pp

  # Scale function: lift_pct → bar width in pixels
  to_width <- function(lift_pct) {
    abs(lift_pct) / max_lift * half_bar * 0.9
  }

  # Build SVG elements
  elements <- ""

  # Zero line
  elements <- paste0(elements, sprintf(
    '<line x1="%.1f" y1="25" x2="%.1f" y2="%.0f" stroke="%s" stroke-width="1" stroke-dasharray="4,3"/>\n',
    zero_x, zero_x, total_height - 15, .cd_muted_colour
  ))
  elements <- paste0(elements, sprintf(
    '<text x="%.1f" y="18" text-anchor="middle" font-size="10" fill="%s" font-weight="400">0 pp</text>\n',
    zero_x, .cd_muted_colour
  ))

  # Gridlines at regular intervals
  grid_steps <- if (max_lift > 20) seq(10, max_lift, by = 10)
                else if (max_lift > 10) seq(5, max_lift, by = 5)
                else seq(2, max_lift, by = 2)
  for (g in grid_steps) {
    w <- to_width(g)
    # Right side gridline
    gx_right <- zero_x + w
    if (gx_right <= chart_width - 20) {
      elements <- paste0(elements, sprintf(
        '<line x1="%.1f" y1="25" x2="%.1f" y2="%.0f" stroke="%s" stroke-width="1"/>\n',
        gx_right, gx_right, total_height - 15, .cd_grid_colour
      ))
      elements <- paste0(elements, sprintf(
        '<text x="%.1f" y="18" text-anchor="middle" font-size="9" fill="%s">+%g</text>\n',
        gx_right, .cd_muted_colour, g
      ))
    }
    # Left side gridline
    gx_left <- zero_x - w
    if (gx_left >= label_width) {
      elements <- paste0(elements, sprintf(
        '<line x1="%.1f" y1="25" x2="%.1f" y2="%.0f" stroke="%s" stroke-width="1"/>\n',
        gx_left, gx_left, total_height - 15, .cd_grid_colour
      ))
      elements <- paste0(elements, sprintf(
        '<text x="%.1f" y="18" text-anchor="middle" font-size="9" fill="%s">-%g</text>\n',
        gx_left, .cd_muted_colour, g
      ))
    }
  }

  # Draw rows — each wrapped in <g data-cd-factor="..."> for chip filtering
  y_pos <- 30
  for (r in rows) {
    driver_attr <- htmltools::htmlEscape(r$driver %||% "")

    if (r$type == "header") {
      elements <- paste0(elements, sprintf(
        '<g class="cd-lift-row cd-lift-header" data-cd-factor="%s">\n', driver_attr))

      # Driver group header with reference category annotation
      header_label <- htmltools::htmlEscape(r$label)
      if (!is.null(r$reference)) {
        ref_text <- htmltools::htmlEscape(r$reference)
        header_label <- sprintf(
          '%s <tspan font-size="9" fill="%s" font-weight="400">(ref: %s)</tspan>',
          header_label, .cd_muted_colour, ref_text
        )
      }
      elements <- paste0(elements, sprintf(
        '<text x="%d" y="%.1f" font-size="11" fill="%s" font-weight="600">%s</text>\n',
        8, y_pos + header_height / 2 + 2, brand_colour, header_label
      ))
      # Subtle separator line
      elements <- paste0(elements, sprintf(
        '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="%s" stroke-width="1"/>\n',
        label_width, y_pos + header_height, chart_width - 20, y_pos + header_height, .cd_grid_colour
      ))
      elements <- paste0(elements, '</g>\n')
      y_pos <- y_pos + header_height + gap
    } else {
      elements <- paste0(elements, sprintf(
        '<g class="cd-lift-row cd-lift-bar" data-cd-factor="%s">\n', driver_attr))

      # Bar row
      lift <- r$lift_pct
      bar_w <- to_width(lift)
      bar_colour <- if (lift >= 0) brand_colour else "#EF4444"
      bar_opacity <- max(0.5, min(1.0, abs(lift) / max_lift + 0.3))

      # Category label
      elements <- paste0(elements, sprintf(
        '<text x="%.0f" y="%.1f" text-anchor="end" font-size="11" fill="%s" font-weight="400" dominant-baseline="central">%s</text>\n',
        label_width - 8, y_pos + bar_height / 2, .cd_value_colour, htmltools::htmlEscape(r$label)
      ))

      if (lift >= 0) {
        # Positive: bar extends right from zero
        elements <- paste0(elements, sprintf(
          '<rect x="%.1f" y="%.1f" width="%.1f" height="%d" rx="4" fill="%s" opacity="%.2f"/>\n',
          zero_x, y_pos, bar_w, bar_height, bar_colour, bar_opacity
        ))
        # Value label to the right of bar
        elements <- paste0(elements, sprintf(
          '<text x="%.1f" y="%.1f" font-size="10" fill="%s" font-weight="500" dominant-baseline="central">+%.1f pp</text>\n',
          zero_x + bar_w + 4, y_pos + bar_height / 2, bar_colour, lift
        ))
      } else {
        # Negative: bar extends left from zero
        bar_x <- zero_x - bar_w
        elements <- paste0(elements, sprintf(
          '<rect x="%.1f" y="%.1f" width="%.1f" height="%d" rx="4" fill="%s" opacity="%.2f"/>\n',
          bar_x, y_pos, bar_w, bar_height, bar_colour, bar_opacity
        ))
        # Value label to the left of bar
        elements <- paste0(elements, sprintf(
          '<text x="%.1f" y="%.1f" text-anchor="end" font-size="10" fill="%s" font-weight="500" dominant-baseline="central">%.1f pp</text>\n',
          bar_x - 4, y_pos + bar_height / 2, bar_colour, lift
        ))
      }

      elements <- paste0(elements, '</g>\n')
      y_pos <- y_pos + bar_height + gap
    }
  }

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="cd-chart cd-lift-chart" role="img" aria-label="Probability lift diverging bar chart" style="font-family:%s;">\n%s\n</svg>',
    chart_width, total_height, .cd_font_family, elements
  )

  htmltools::HTML(svg)
}
