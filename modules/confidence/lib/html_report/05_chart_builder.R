# ==============================================================================
# CONFIDENCE HTML REPORT - CHART BUILDER
# ==============================================================================
# Builds SVG visualizations for confidence intervals.
# Forest plot for overview, method comparison for detail views.
# ==============================================================================

#' Build Forest Plot SVG (All Questions Overview)
#'
#' Shows estimate + CI bar for each question. Proportions shown as
#' percentages (0-100%), means as raw values.
#'
#' @param questions Named list from transform_confidence_for_html()
#' @param brand_colour Character hex colour
#' @return Character string of SVG HTML
#' @keywords internal
build_ci_forest_plot <- function(questions, brand_colour = "#1e3a5f") {
  prop_qs <- Filter(function(q) q$type == "proportion", questions)
  mean_qs <- Filter(function(q) q$type == "mean", questions)
  nps_qs <- Filter(function(q) q$type == "nps", questions)

  svg_parts <- character()

  # Build proportion forest plot
  if (length(prop_qs) > 0) {
    svg_parts <- c(svg_parts, build_forest_svg(prop_qs, brand_colour,
                                                 "Proportion Questions", TRUE))
  }

  # Build mean forest plot
  if (length(mean_qs) > 0) {
    svg_parts <- c(svg_parts, build_forest_svg(mean_qs, brand_colour,
                                                 "Mean Questions", FALSE))
  }

  # Build NPS forest plot
  if (length(nps_qs) > 0) {
    svg_parts <- c(svg_parts, build_forest_svg(nps_qs, brand_colour,
                                                 "NPS Questions", FALSE))
  }

  paste(svg_parts, collapse = "\n")
}


#' Build a single forest plot SVG
#' @keywords internal
build_forest_svg <- function(questions, brand_colour, title, is_proportion) {
  n_items <- length(questions)
  if (n_items == 0) return("")

  # Layout
  margin_left <- 200
  margin_right <- 60
  margin_top <- 40
  margin_bottom <- 30
  row_height <- 32
  chart_width <- 760
  chart_height <- margin_top + n_items * row_height + margin_bottom

  plot_w <- chart_width - margin_left - margin_right

  # Determine axis range
  all_lower <- sapply(questions, function(q) q$ci_lower)
  all_upper <- sapply(questions, function(q) q$ci_upper)
  all_est <- sapply(questions, function(q) q$estimate)

  valid <- !is.na(all_lower) & !is.na(all_upper) & !is.na(all_est)
  if (!any(valid)) return("")

  if (is_proportion) {
    x_min <- max(0, min(all_lower[valid]) - 0.05)
    x_max <- min(1, max(all_upper[valid]) + 0.05)
  } else {
    range_vals <- c(all_lower[valid], all_upper[valid])
    x_range <- max(range_vals) - min(range_vals)
    x_min <- min(range_vals) - x_range * 0.1
    x_max <- max(range_vals) + x_range * 0.1
  }

  scale_x <- function(val) {
    margin_left + (val - x_min) / (x_max - x_min) * plot_w
  }

  # Build SVG elements
  elements <- character()

  # Title
  elements <- c(elements, sprintf(
    '<text x="%.0f" y="20" font-size="13" font-weight="600" fill="#1e293b">%s</text>',
    margin_left, title
  ))

  # Gridlines (5 lines)
  n_grid <- 5
  for (i in 0:n_grid) {
    gv <- x_min + i * (x_max - x_min) / n_grid
    gx <- scale_x(gv)
    gy_top <- margin_top
    gy_bot <- margin_top + n_items * row_height

    elements <- c(elements, sprintf(
      '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e2e8f0" stroke-width="1"/>',
      gx, gy_top, gx, gy_bot
    ))

    label_val <- if (is_proportion) sprintf("%.0f%%", gv * 100) else sprintf("%.1f", gv)
    elements <- c(elements, sprintf(
      '<text x="%.1f" y="%d" font-size="10" fill="#64748b" text-anchor="middle">%s</text>',
      gx, gy_bot + 16, label_val
    ))
  }

  # Data rows
  q_list <- unname(questions)
  for (i in seq_along(q_list)) {
    q <- q_list[[i]]
    y <- margin_top + (i - 0.5) * row_height

    # Label
    label <- q$display_label %||% q$question_id
    if (nchar(label) > 30) label <- paste0(substr(label, 1, 28), "...")
    elements <- c(elements, sprintf(
      '<text x="%d" y="%.1f" font-size="11" fill="#1e293b" text-anchor="end" dominant-baseline="middle">%s</text>',
      margin_left - 8, y, htmlEscape(label)
    ))

    if (is.na(q$ci_lower) || is.na(q$ci_upper) || is.na(q$estimate)) next

    # CI bar (line)
    x1 <- scale_x(q$ci_lower)
    x2 <- scale_x(q$ci_upper)
    elements <- c(elements, sprintf(
      '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="3" opacity="0.6" stroke-linecap="round"/>',
      x1, y, x2, y, brand_colour
    ))

    # End caps
    elements <- c(elements, sprintf(
      '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="2"/>',
      x1, y - 5, x1, y + 5, brand_colour
    ))
    elements <- c(elements, sprintf(
      '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="2"/>',
      x2, y - 5, x2, y + 5, brand_colour
    ))

    # Estimate dot
    xp <- scale_x(q$estimate)
    elements <- c(elements, sprintf(
      '<circle cx="%.1f" cy="%.1f" r="5" fill="%s" stroke="white" stroke-width="1.5"/>',
      xp, y, brand_colour
    ))

    # Value label
    val_label <- if (is_proportion) sprintf("%.1f%%", q$estimate * 100) else sprintf("%.2f", q$estimate)
    elements <- c(elements, sprintf(
      '<text x="%.1f" y="%.1f" font-size="10" fill="#64748b" font-weight="500" dominant-baseline="middle">%s</text>',
      x2 + 8, y, val_label
    ))
  }

  sprintf(
    '<svg viewBox="0 0 %d %d" style="font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Roboto,sans-serif; width:100%%; max-width:720px; height:auto; display:block; margin:0 auto;" role="img" aria-label="%s forest plot">
      %s
    </svg>',
    chart_width, chart_height, htmlEscape(title),
    paste(elements, collapse = "\n")
  )
}


#' Build Method Comparison Chart (Per Question)
#'
#' Horizontal bar chart comparing CI widths across methods for a single question.
#'
#' @param q List. Transformed question object
#' @param brand_colour Character hex colour
#' @return Character string of SVG HTML
#' @keywords internal
build_method_comparison_chart <- function(q, brand_colour = "#1e3a5f") {
  result <- q$results
  is_prop <- q$type == "proportion"

  methods <- list()
  if (!is.null(result$moe)) {
    methods[["Normal"]] <- list(lower = result$moe$lower, upper = result$moe$upper)
  }
  if (!is.null(result$wilson)) {
    methods[["Wilson"]] <- list(lower = result$wilson$lower, upper = result$wilson$upper)
  }
  if (!is.null(result$t_dist)) {
    methods[["t-Dist"]] <- list(lower = result$t_dist$lower, upper = result$t_dist$upper)
  }
  if (!is.null(result$bootstrap)) {
    methods[["Bootstrap"]] <- list(lower = result$bootstrap$lower, upper = result$bootstrap$upper)
  }
  if (!is.null(result$bayesian)) {
    methods[["Bayesian"]] <- list(lower = result$bayesian$lower, upper = result$bayesian$upper)
  }
  if (!is.null(result$moe_normal)) {
    methods[["Normal"]] <- list(lower = result$moe_normal$lower, upper = result$moe_normal$upper)
  }

  n_methods <- length(methods)
  if (n_methods < 2) return("")

  # Layout
  margin_left <- 80
  margin_right <- 60
  margin_top <- 10
  row_height <- 28
  chart_width <- 500
  chart_height <- margin_top + n_methods * row_height + 10
  plot_w <- chart_width - margin_left - margin_right

  # Determine axis range
  all_lower <- sapply(methods, function(m) m$lower)
  all_upper <- sapply(methods, function(m) m$upper)

  if (is_prop) {
    x_min <- max(0, min(all_lower) - 0.02)
    x_max <- min(1, max(all_upper) + 0.02)
  } else {
    rng <- max(all_upper) - min(all_lower)
    x_min <- min(all_lower) - rng * 0.1
    x_max <- max(all_upper) + rng * 0.1
  }

  scale_x <- function(val) margin_left + (val - x_min) / (x_max - x_min) * plot_w

  elements <- character()
  colours <- generate_palette(n_methods, brand_colour)

  method_names <- names(methods)
  for (i in seq_along(methods)) {
    m <- methods[[i]]
    y <- margin_top + (i - 0.5) * row_height

    # Label
    elements <- c(elements, sprintf(
      '<text x="%d" y="%.1f" font-size="11" fill="#1e293b" text-anchor="end" dominant-baseline="middle">%s</text>',
      margin_left - 8, y, method_names[i]
    ))

    # CI bar
    x1 <- scale_x(m$lower)
    x2 <- scale_x(m$upper)
    elements <- c(elements, sprintf(
      '<rect x="%.1f" y="%.1f" width="%.1f" height="14" rx="4" fill="%s" opacity="0.75"/>',
      x1, y - 7, max(1, x2 - x1), colours[i]
    ))

    # Width label
    width_val <- if (is_prop) sprintf("%.1f pp", (m$upper - m$lower) * 100)
                 else sprintf("%.2f", m$upper - m$lower)
    elements <- c(elements, sprintf(
      '<text x="%.1f" y="%.1f" font-size="9" fill="#64748b" font-weight="500" dominant-baseline="middle">%s</text>',
      x2 + 4, y, width_val
    ))
  }

  # Estimate line
  est <- q$estimate
  if (!is.na(est)) {
    xe <- scale_x(est)
    elements <- c(elements, sprintf(
      '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e74c3c" stroke-width="1.5" stroke-dasharray="4,3"/>',
      xe, margin_top - 2, xe, margin_top + n_methods * row_height + 2
    ))
  }

  sprintf(
    '<svg viewBox="0 0 %d %d" style="font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Roboto,sans-serif; width:100%%; max-width:520px; height:auto; display:block; margin:8px auto;" role="img" aria-label="Method comparison chart">
      %s
    </svg>',
    chart_width, chart_height,
    paste(elements, collapse = "\n")
  )
}


#' Generate a palette of n colours from a brand colour
#' @keywords internal
generate_palette <- function(n, brand_colour) {
  # Convert hex to HSL-ish and rotate hue
  hex_to_rgb <- function(hex) {
    hex <- sub("^#", "", hex)
    c(
      strtoi(substr(hex, 1, 2), 16L),
      strtoi(substr(hex, 3, 4), 16L),
      strtoi(substr(hex, 5, 6), 16L)
    )
  }

  rgb_to_hex <- function(r, g, b) {
    sprintf("#%02x%02x%02x", round(r), round(g), round(b))
  }

  base_rgb <- hex_to_rgb(brand_colour)
  colours <- character(n)
  colours[1] <- brand_colour

  if (n > 1) {
    for (i in 2:n) {
      shift <- (i - 1) * 40
      r <- (base_rgb[1] + shift) %% 256
      g <- (base_rgb[2] + shift * 1.3) %% 256
      b <- (base_rgb[3] + shift * 0.7) %% 256
      # Keep saturation reasonable
      avg <- (r + g + b) / 3
      r <- round(r * 0.7 + avg * 0.3)
      g <- round(g * 0.7 + avg * 0.3)
      b <- round(b * 0.7 + avg * 0.3)
      colours[i] <- rgb_to_hex(min(255, r), min(255, g), min(255, b))
    }
  }
  colours
}


# htmlEscape: canonical definition in 02_table_builder.R
if (!exists("htmlEscape", mode = "function")) {
  htmlEscape <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub('"', "&quot;", x, fixed = TRUE)
    x
  }
}

# Null-coalescing operator (canonical definition in utils.R)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
