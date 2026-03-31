# ==============================================================================
# SEGMENT HTML REPORT - SVG CHART BUILDER
# ==============================================================================
# Builds SVG charts for the segmentation HTML report.
# Design language: Turas muted palette, rounded corners, no gradients.
# Version: 11.0
# ==============================================================================


#' Build Segment Sizes Horizontal Bar Chart (SVG)
#'
#' Horizontal bar chart showing segment sizes sorted by size descending.
#' Each bar displays segment name on the left, bar on the right with n count
#' and percentage at the end.
#'
#' @param html_data List from data transformer (must contain segment_sizes data frame)
#' @param brand_colour Brand colour hex string
#' @return htmltools::HTML string containing SVG, or empty string if no data
#' @keywords internal
build_seg_sizes_chart <- function(html_data, brand_colour = "#323367") {

  sizes <- html_data$segment_sizes
  if (is.null(sizes) || nrow(sizes) == 0) {
    return(htmltools::HTML(""))
  }

  # Sort descending by count
  sizes <- sizes[order(-sizes$n), , drop = FALSE]
  n <- nrow(sizes)

  bar_height <- 32
  gap <- 10
  label_width <- 180
  chart_width <- 650
  bar_area_width <- chart_width - label_width - 100
  total_height <- n * (bar_height + gap) + 20

  max_pct <- max(sizes$pct, na.rm = TRUE)
  if (max_pct == 0) max_pct <- 1

  # Gridlines
  grid_lines <- ""
  grid_step <- if (max_pct > 40) 20 else if (max_pct > 20) 10 else 5
  for (g in seq(0, 100, by = grid_step)) {
    if (g > max_pct * 1.15) break
    x_pos <- label_width + (g / max(max_pct * 1.15, 1)) * bar_area_width
    grid_lines <- paste0(grid_lines, sprintf(
      '<line x1="%.1f" y1="5" x2="%.1f" y2="%.0f" stroke="#e2e8f0" stroke-width="1"/>\n',
      x_pos, x_pos, total_height - 5
    ))
    grid_lines <- paste0(grid_lines, sprintf(
      '<text x="%.1f" y="12" text-anchor="middle" font-size="10" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#94a3b8" font-weight="400">%d%%</text>\n',
      x_pos, g
    ))
  }

  # Bars
  bars <- ""
  for (i in seq_len(n)) {
    row <- sizes[i, ]
    y <- 18 + (i - 1) * (bar_height + gap)
    bar_w <- max(2, (row$pct / max(max_pct * 1.15, 1)) * bar_area_width)
    opacity <- max(0.5, 1.0 - (i - 1) * 0.15)

    seg_label <- htmltools::htmlEscape(row$segment_name %||% paste0("Segment ", row$segment_id))

    # Segment name label
    bars <- paste0(bars, sprintf(
      '<text x="%.0f" y="%.1f" text-anchor="end" font-size="12" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#334155" font-weight="400" dominant-baseline="central">%s</text>\n',
      label_width - 10, y + bar_height / 2, seg_label
    ))

    # Bar rect (with toggle group for show/hide)
    group_id <- sprintf("seg-bar-%d", i)
    bars <- paste0(bars, sprintf(
      '<rect x="%.0f" y="%.1f" width="%.1f" height="%d" rx="4" fill="%s" opacity="%.2f" data-seg-bar-group="%s"/>\n',
      label_width, y, bar_w, bar_height, brand_colour, opacity, group_id
    ))

    # Value label: n count and percentage
    value_text <- sprintf("n=%d (%.0f%%)", row$n, row$pct)
    bars <- paste0(bars, sprintf(
      '<text x="%.1f" y="%.1f" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#334155" font-weight="500" dominant-baseline="central" data-seg-label-group="%s">%s</text>\n',
      label_width + bar_w + 8, y + bar_height / 2, group_id, value_text
    ))
  }

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="seg-chart seg-sizes-chart" role="img" aria-label="Segment sizes bar chart showing %d segments">\n%s\n%s\n</svg>',
    chart_width, total_height, n, grid_lines, bars
  )

  htmltools::HTML(svg)
}


#' Build Silhouette per Cluster Bar Chart (SVG)
#'
#' Horizontal bar chart showing silhouette score per cluster. Bars are
#' colour-coded: green for >= 0.5, brand for 0.25-0.5, warning for < 0.25.
#' A dashed reference line is drawn at 0.25.
#'
#' @param html_data List from data transformer (must contain sil_per_cluster)
#' @param brand_colour Brand colour hex string
#' @return htmltools::HTML string containing SVG, or empty string if no data
#' @keywords internal
build_seg_silhouette_chart <- function(html_data, brand_colour = "#323367") {

  sil_data <- html_data$sil_per_cluster
  if (is.null(sil_data)) {
    return(htmltools::HTML(""))
  }

  # Normalise input: accept named vector, data frame, or list
  if (is.numeric(sil_data) && !is.null(names(sil_data))) {
    cluster_ids <- names(sil_data)
    sil_values <- as.numeric(sil_data)
  } else if (is.data.frame(sil_data)) {
    # Expect columns: cluster (or id), sil (or silhouette or avg_sil)
    id_col <- intersect(names(sil_data), c("cluster", "id", "segment_id", "Cluster"))[1]
    val_col <- intersect(names(sil_data), c("sil", "silhouette", "avg_sil", "avg_silhouette", "Silhouette"))[1]
    if (is.na(id_col) || is.na(val_col)) return(htmltools::HTML(""))
    cluster_ids <- as.character(sil_data[[id_col]])
    sil_values <- as.numeric(sil_data[[val_col]])
  } else if (is.list(sil_data)) {
    cluster_ids <- names(sil_data)
    sil_values <- vapply(sil_data, function(x) as.numeric(x[1]), numeric(1))
  } else {
    return(htmltools::HTML(""))
  }

  n <- length(sil_values)
  if (n == 0) return(htmltools::HTML(""))

  bar_height <- 28
  gap <- 8
  label_width <- 120
  chart_width <- 550
  bar_area_width <- chart_width - label_width - 80
  total_height <- n * (bar_height + gap) + 40

  max_sil <- max(sil_values, 0.5, na.rm = TRUE)
  scale_max <- min(1.0, max_sil * 1.15)

  # Segment names for labels
  seg_names <- html_data$segment_names

  # Gridlines
  grid_lines <- ""
  for (g in seq(0, 1.0, by = 0.25)) {
    if (g > scale_max) break
    x_pos <- label_width + (g / scale_max) * bar_area_width
    grid_lines <- paste0(grid_lines, sprintf(
      '<line x1="%.1f" y1="20" x2="%.1f" y2="%.0f" stroke="#e2e8f0" stroke-width="1"/>\n',
      x_pos, x_pos, total_height - 5
    ))
    grid_lines <- paste0(grid_lines, sprintf(
      '<text x="%.1f" y="15" text-anchor="middle" font-size="10" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#94a3b8" font-weight="400">%.2f</text>\n',
      x_pos, g
    ))
  }

  # Reference line at 0.25
  ref_x <- label_width + (0.25 / scale_max) * bar_area_width
  ref_line <- sprintf(
    '<line x1="%.1f" y1="20" x2="%.1f" y2="%.0f" stroke="#d97706" stroke-width="1.5" stroke-dasharray="6,3"/>\n',
    ref_x, ref_x, total_height - 5
  )
  ref_label <- sprintf(
    '<text x="%.1f" y="%.0f" text-anchor="middle" font-size="9" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#d97706" font-weight="400">threshold</text>\n',
    ref_x, total_height
  )

  # Bars
  bars <- ""
  for (i in seq_len(n)) {
    val <- sil_values[i]
    if (is.na(val)) val <- 0
    y <- 25 + (i - 1) * (bar_height + gap)
    bar_w <- max(2, (val / scale_max) * bar_area_width)

    # Colour coding by silhouette quality
    bar_colour <- if (val >= 0.5) {
      "#059669"
    } else if (val >= 0.25) {
      brand_colour
    } else {
      "#d97706"
    }

    # Cluster label
    cluster_label <- if (!is.null(seg_names) && i <= length(seg_names)) {
      htmltools::htmlEscape(seg_names[i])
    } else if (!is.null(cluster_ids) && i <= length(cluster_ids)) {
      htmltools::htmlEscape(paste0("Cluster ", cluster_ids[i]))
    } else {
      paste0("Cluster ", i)
    }

    bars <- paste0(bars, sprintf(
      '<text x="%.0f" y="%.1f" text-anchor="end" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#334155" font-weight="400" dominant-baseline="central">%s</text>\n',
      label_width - 8, y + bar_height / 2, cluster_label
    ))

    bars <- paste0(bars, sprintf(
      '<rect x="%.0f" y="%.1f" width="%.1f" height="%d" rx="4" fill="%s" opacity="0.85"/>\n',
      label_width, y, bar_w, bar_height, bar_colour
    ))

    bars <- paste0(bars, sprintf(
      '<text x="%.1f" y="%.1f" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#334155" font-weight="500" dominant-baseline="central">%.3f</text>\n',
      label_width + bar_w + 6, y + bar_height / 2, val
    ))
  }

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="seg-chart seg-silhouette-chart" role="img" aria-label="Silhouette score per cluster bar chart">\n%s\n%s%s\n%s\n</svg>',
    chart_width, total_height + 5, grid_lines, ref_line, ref_label, bars
  )

  htmltools::HTML(svg)
}


#' Build Variable Importance Bar Chart (SVG)
#'
#' Horizontal bar chart showing variable importance (eta-squared or F-statistic)
#' sorted by importance descending with opacity fade by rank.
#'
#' @param html_data List from data transformer (must contain variable_importance)
#' @param brand_colour Brand colour hex string
#' @return htmltools::HTML string containing SVG, or empty string if no data
#' @keywords internal
build_seg_importance_chart <- function(html_data, brand_colour = "#323367") {

  vi <- html_data$variable_importance
  if (is.null(vi) || nrow(vi) == 0) {
    return(htmltools::HTML(""))
  }

  # Determine which metric to display
  has_eta <- "eta_squared" %in% names(vi)
  has_f <- "f_statistic" %in% names(vi)
  has_pct <- "importance_pct" %in% names(vi)

  # Use importance_pct if available, else eta_squared, else f_statistic
  if (has_pct) {
    metric_vals <- vi$importance_pct
    metric_label <- "Importance (%)"
    fmt <- function(v) sprintf("%.0f%%", v)
  } else if (has_eta) {
    metric_vals <- vi$eta_squared
    metric_label <- "Eta-squared"
    fmt <- function(v) sprintf("%.4f", v)
  } else if (has_f) {
    metric_vals <- vi$f_statistic
    metric_label <- "F-statistic"
    fmt <- function(v) sprintf("%.1f", v)
  } else {
    return(htmltools::HTML(""))
  }

  # Resolve labels: prefer question_labels mapping
  labels <- vi$variable
  ql <- html_data$question_labels
  if (!is.null(ql) && is.list(ql)) {
    labels <- vapply(labels, function(v) {
      lbl <- ql[[v]]
      if (!is.null(lbl) && nzchar(lbl)) lbl else v
    }, character(1), USE.NAMES = FALSE)
  }

  # Ensure sorted descending (should be, but enforce)
  ord <- order(-metric_vals)
  metric_vals <- metric_vals[ord]
  labels <- labels[ord]
  n <- length(metric_vals)

  bar_height <- 28
  gap <- 8
  label_width <- 220
  chart_width <- 700
  bar_area_width <- chart_width - label_width - 80
  total_height <- n * (bar_height + gap) + 40

  max_val <- max(metric_vals, na.rm = TRUE)
  if (max_val == 0) max_val <- 1

  # Gridlines
  grid_lines <- ""
  if (has_pct) {
    grid_step <- if (max_val > 40) 20 else if (max_val > 20) 10 else 5
    grid_seq <- seq(0, 100, by = grid_step)
  } else if (has_eta) {
    grid_step <- if (max_val > 0.5) 0.25 else if (max_val > 0.2) 0.1 else 0.05
    grid_seq <- seq(0, 1, by = grid_step)
  } else {
    grid_step <- max(1, round(max_val / 5))
    grid_seq <- seq(0, max_val * 1.2, by = grid_step)
  }

  for (g in grid_seq) {
    if (g > max_val * 1.15) break
    x_pos <- label_width + (g / max(max_val * 1.15, 0.001)) * bar_area_width
    grid_lines <- paste0(grid_lines, sprintf(
      '<line x1="%.1f" y1="20" x2="%.1f" y2="%.0f" stroke="#e2e8f0" stroke-width="1"/>\n',
      x_pos, x_pos, total_height - 5
    ))
    grid_label <- if (has_pct) sprintf("%d%%", as.integer(g))
                  else if (has_eta) sprintf("%.2f", g)
                  else sprintf("%.0f", g)
    grid_lines <- paste0(grid_lines, sprintf(
      '<text x="%.1f" y="15" text-anchor="middle" font-size="10" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#94a3b8" font-weight="400">%s</text>\n',
      x_pos, grid_label
    ))
  }

  # Bars with inline X close button
  bars <- ""
  x_btn_size <- 18  # clickable area for X button
  for (i in seq_len(n)) {
    val <- metric_vals[i]
    if (is.na(val)) val <- 0
    y <- 25 + (i - 1) * (bar_height + gap)
    bar_w <- max(2, (val / max(max_val * 1.15, 0.001)) * bar_area_width)
    opacity <- max(0.4, 1.0 - (i - 1) * 0.08)

    # Truncate long labels
    lbl <- labels[i]
    if (nchar(lbl) > 35) lbl <- paste0(substr(lbl, 1, 33), "\u2026")

    group_id <- sprintf("imp-bar-%d", i)

    # Label text
    bars <- paste0(bars, sprintf(
      '<text x="%.0f" y="%.1f" text-anchor="end" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#334155" font-weight="400" dominant-baseline="central" data-seg-label-group="%s">%s</text>\n',
      label_width - 8, y + bar_height / 2, group_id, htmltools::htmlEscape(lbl)
    ))

    # Bar rect
    bars <- paste0(bars, sprintf(
      '<rect x="%.0f" y="%.1f" width="%.1f" height="%d" rx="4" fill="%s" opacity="%.2f" data-seg-bar-group="%s"/>\n',
      label_width, y, bar_w, bar_height, brand_colour, opacity, group_id
    ))

    # Value text
    val_x <- label_width + bar_w + 6
    bars <- paste0(bars, sprintf(
      '<text x="%.1f" y="%.1f" font-size="10" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#334155" font-weight="500" dominant-baseline="central" data-seg-label-group="%s">%s</text>\n',
      val_x, y + bar_height / 2, group_id, fmt(val)
    ))

    # X close button (circle + x) at far right of bar
    x_centre <- chart_width - 20
    y_centre <- y + bar_height / 2
    bars <- paste0(bars, sprintf(paste0(
      '<g class="seg-bar-x-btn" data-seg-target-group="%s" style="cursor:pointer;" onclick="segToggleBarByX(this,\'%s\')">\n',
      '  <circle cx="%.0f" cy="%.1f" r="9" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1"/>\n',
      '  <text x="%.0f" y="%.1f" text-anchor="middle" dominant-baseline="central" font-size="11" ',
      'font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#94a3b8" font-weight="600">\u00D7</text>\n',
      '</g>\n'
    ), group_id, group_id, x_centre, y_centre, x_centre, y_centre))
  }

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="seg-chart seg-importance-chart" role="img" aria-label="Variable importance bar chart showing %s">\n%s\n%s\n</svg>',
    chart_width, total_height, metric_label, grid_lines, bars
  )

  htmltools::HTML(svg)
}


#' Build Segment Profile Heatmap (SVG)
#'
#' Colour-coded means grid showing segment profiles. Rows are variables,
#' columns are segments. Cell colour interpolated from blue (low z-score)
#' through white (zero) to red (high z-score). Actual mean values displayed
#' in each cell.
#'
#' @param html_data List from data transformer (must contain centers and segment_names)
#' @param brand_colour Brand colour hex string (used for header background)
#' @param accent_colour Accent colour hex string (unused, kept for API consistency)
#' @return htmltools::HTML string containing SVG, or empty string if no data
#' @keywords internal
build_seg_heatmap_chart <- function(html_data, brand_colour = "#323367",
                                     accent_colour = "#CC9900") {

  centers <- html_data$centers
  if (is.null(centers)) return(htmltools::HTML(""))

  # centers is a matrix: rows = clusters, cols = variables
  if (!is.matrix(centers)) {
    centers <- tryCatch(as.matrix(centers), error = function(e) NULL)
    if (is.null(centers)) return(htmltools::HTML(""))
  }

  k <- nrow(centers)
  n_vars <- ncol(centers)
  if (k == 0 || n_vars == 0) return(htmltools::HTML(""))

  var_names <- colnames(centers) %||% paste0("V", seq_len(n_vars))
  seg_names <- html_data$segment_names %||% paste0("Seg ", seq_len(k))

  # Resolve variable display labels
  ql <- html_data$question_labels
  var_labels <- if (!is.null(ql) && is.list(ql)) {
    vapply(var_names, function(v) {
      lbl <- ql[[v]]
      if (!is.null(lbl) && nzchar(lbl)) lbl else v
    }, character(1), USE.NAMES = FALSE)
  } else {
    var_names
  }

  cell_width <- 90
  cell_height <- 32
  label_width <- 200
  header_height <- 36
  chart_width <- label_width + k * cell_width + 10
  total_height <- header_height + n_vars * cell_height + 10

  # Compute z-scores per variable (across clusters) for colour mapping
  z_matrix <- matrix(0, nrow = k, ncol = n_vars)
  for (j in seq_len(n_vars)) {
    col_vals <- centers[, j]
    col_mean <- mean(col_vals, na.rm = TRUE)
    col_sd <- stats::sd(col_vals, na.rm = TRUE)
    if (!is.na(col_sd) && col_sd > 0) {
      z_matrix[, j] <- (col_vals - col_mean) / col_sd
    }
  }

  # Colour interpolation: blue (-) -> white (0) -> red (+)
  z_to_colour <- function(z) {
    z <- max(-3, min(3, z))  # clamp
    if (z >= 0) {
      # White to red
      intensity <- min(1, z / 2.5)
      r <- 255
      g <- round(255 * (1 - intensity * 0.7))
      b <- round(255 * (1 - intensity * 0.8))
    } else {
      # White to blue
      intensity <- min(1, abs(z) / 2.5)
      r <- round(255 * (1 - intensity * 0.8))
      g <- round(255 * (1 - intensity * 0.6))
      b <- 255
    }
    sprintf("#%02x%02x%02x", r, g, b)
  }

  # Determine text colour for contrast
  text_colour_for_z <- function(z) {
    if (abs(z) > 2.0) "#ffffff" else "#334155"
  }

  # Header row
  header <- ""
  for (seg_i in seq_len(k)) {
    x <- label_width + (seg_i - 1) * cell_width
    # Header background
    header <- paste0(header, sprintf(
      '<rect x="%.0f" y="0" width="%d" height="%d" rx="4" fill="%s" opacity="0.12"/>\n',
      x, cell_width, header_height, brand_colour
    ))
    # Segment name
    seg_label <- htmltools::htmlEscape(seg_names[seg_i])
    if (nchar(seg_label) > 12) seg_label <- paste0(substr(seg_label, 1, 11), "\u2026")
    header <- paste0(header, sprintf(
      '<text x="%.1f" y="%.1f" text-anchor="middle" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="%s" font-weight="500" dominant-baseline="central">%s</text>\n',
      x + cell_width / 2, header_height / 2, brand_colour, seg_label
    ))
  }

  # Data cells
  cells <- ""
  for (var_i in seq_len(n_vars)) {
    y <- header_height + (var_i - 1) * cell_height

    # Variable label
    vlbl <- var_labels[var_i]
    if (nchar(vlbl) > 30) vlbl <- paste0(substr(vlbl, 1, 28), "\u2026")
    cells <- paste0(cells, sprintf(
      '<text x="%.0f" y="%.1f" text-anchor="end" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#334155" font-weight="400" dominant-baseline="central">%s</text>\n',
      label_width - 8, y + cell_height / 2, htmltools::htmlEscape(vlbl)
    ))

    for (seg_i in seq_len(k)) {
      x <- label_width + (seg_i - 1) * cell_width
      z_val <- z_matrix[seg_i, var_i]
      bg_colour <- z_to_colour(z_val)
      txt_colour <- text_colour_for_z(z_val)
      mean_val <- centers[seg_i, var_i]

      # Cell background
      cells <- paste0(cells, sprintf(
        '<rect x="%.0f" y="%.0f" width="%d" height="%d" rx="4" fill="%s" stroke="#f1f5f9" stroke-width="1"/>\n',
        x, y, cell_width, cell_height, bg_colour
      ))

      # Mean value text — consistent 1dp for alignment
      mean_text <- if (is.na(mean_val)) {
        "NA"
      } else if (abs(mean_val) >= 100) {
        sprintf("%.0f", mean_val)
      } else {
        sprintf("%.1f", mean_val)
      }

      cells <- paste0(cells, sprintf(
        '<text x="%.1f" y="%.1f" text-anchor="middle" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="%s" font-weight="500" dominant-baseline="central">%s</text>\n',
        x + cell_width / 2, y + cell_height / 2, txt_colour, mean_text
      ))
    }

    # Faint row separator
    if (var_i < n_vars) {
      sep_y <- y + cell_height
      cells <- paste0(cells, sprintf(
        '<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" stroke="#f1f5f9" stroke-width="1"/>\n',
        label_width, sep_y, label_width + k * cell_width, sep_y
      ))
    }
  }

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %.0f %.0f" class="seg-chart seg-heatmap-chart" role="img" aria-label="Segment profile heatmap with %d variables across %d segments">\n%s\n%s\n</svg>',
    chart_width, total_height, n_vars, k, header, cells
  )

  htmltools::HTML(svg)
}


#' Build Elbow Chart for Exploration Mode (SVG)
#'
#' Line chart showing within-cluster sum of squares by k value.
#' The recommended k is highlighted with an accent circle.
#'
#' @param html_data List from data transformer (exploration mode, must contain metrics_df)
#' @param brand_colour Brand colour hex string
#' @return htmltools::HTML string containing SVG, or empty string if no data
#' @keywords internal
build_seg_elbow_chart <- function(html_data, brand_colour = "#323367") {

  metrics_df <- html_data$metrics_df
  if (is.null(metrics_df)) return(htmltools::HTML(""))

  # Find within-SS column
  wss_col <- intersect(names(metrics_df), c("tot_withinss", "tot.withinss", "withinss", "within_ss"))[1]
  k_col <- intersect(names(metrics_df), c("k", "K", "n_clusters"))[1]
  if (is.na(wss_col) || is.na(k_col)) return(htmltools::HTML(""))

  k_vals <- as.numeric(metrics_df[[k_col]])
  wss_vals <- as.numeric(metrics_df[[wss_col]])

  # Remove NAs
  valid <- !is.na(k_vals) & !is.na(wss_vals)
  k_vals <- k_vals[valid]
  wss_vals <- wss_vals[valid]
  if (length(k_vals) < 2) return(htmltools::HTML(""))

  # Sort by k
  ord <- order(k_vals)
  k_vals <- k_vals[ord]
  wss_vals <- wss_vals[ord]

  chart_width <- 500
  chart_height <- 300
  margin_left <- 80
  margin_right <- 30
  margin_top <- 30
  margin_bottom <- 50
  plot_w <- chart_width - margin_left - margin_right
  plot_h <- chart_height - margin_top - margin_bottom

  # Scale functions
  k_min <- min(k_vals)
  k_max <- max(k_vals)
  wss_min <- min(wss_vals) * 0.9
  wss_max <- max(wss_vals) * 1.05
  k_range <- max(k_max - k_min, 1)
  wss_range <- max(wss_max - wss_min, 1)

  to_x <- function(k) margin_left + (k - k_min) / k_range * plot_w
  to_y <- function(wss) margin_top + (1 - (wss - wss_min) / wss_range) * plot_h

  # Recommended k
  rec_k <- NULL
  if (!is.null(html_data$recommendation)) {
    rec_k <- html_data$recommendation$recommended_k %||%
             html_data$recommendation$k %||% NULL
  }

  # Gridlines (horizontal)
  grid_lines <- ""
  n_grid <- 5
  wss_step <- wss_range / n_grid
  for (i in 0:n_grid) {
    wss_g <- wss_min + i * wss_step
    gy <- to_y(wss_g)
    grid_lines <- paste0(grid_lines, sprintf(
      '<line x1="%.0f" y1="%.1f" x2="%.0f" y2="%.1f" stroke="#e2e8f0" stroke-width="1"/>\n',
      margin_left, gy, chart_width - margin_right, gy
    ))
    # Y-axis label
    label_val <- if (wss_g >= 10000) sprintf("%.0fk", wss_g / 1000)
                 else if (wss_g >= 1000) sprintf("%.1fk", wss_g / 1000)
                 else sprintf("%.0f", wss_g)
    grid_lines <- paste0(grid_lines, sprintf(
      '<text x="%.0f" y="%.1f" text-anchor="end" font-size="10" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#94a3b8" font-weight="400" dominant-baseline="central">%s</text>\n',
      margin_left - 8, gy, label_val
    ))
  }

  # X-axis labels
  x_labels <- ""
  for (k in k_vals) {
    kx <- to_x(k)
    x_labels <- paste0(x_labels, sprintf(
      '<text x="%.1f" y="%.0f" text-anchor="middle" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#64748b" font-weight="400">%d</text>\n',
      kx, chart_height - margin_bottom + 18, as.integer(k)
    ))
    # Tick mark
    x_labels <- paste0(x_labels, sprintf(
      '<line x1="%.1f" y1="%.0f" x2="%.1f" y2="%.0f" stroke="#cbd5e1" stroke-width="1"/>\n',
      kx, margin_top + plot_h, kx, margin_top + plot_h + 4
    ))
  }

  # Axis titles
  x_title <- sprintf(
    '<text x="%.1f" y="%.0f" text-anchor="middle" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#64748b" font-weight="400">Number of clusters (k)</text>\n',
    margin_left + plot_w / 2, chart_height - 5
  )
  y_title <- sprintf(
    '<text x="12" y="%.1f" text-anchor="middle" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#64748b" font-weight="400" transform="rotate(-90, 12, %.1f)">Within-SS</text>\n',
    margin_top + plot_h / 2, margin_top + plot_h / 2
  )

  # Line path
  path_points <- vapply(seq_along(k_vals), function(i) {
    sprintf("%.1f,%.1f", to_x(k_vals[i]), to_y(wss_vals[i]))
  }, character(1))
  line_path <- sprintf(
    '<polyline points="%s" fill="none" stroke="%s" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>\n',
    paste(path_points, collapse = " "), brand_colour
  )

  # Points
  points <- ""
  for (i in seq_along(k_vals)) {
    px <- to_x(k_vals[i])
    py <- to_y(wss_vals[i])

    is_rec <- !is.null(rec_k) && k_vals[i] == rec_k

    if (is_rec) {
      # Highlight ring for recommended k
      points <- paste0(points, sprintf(
        '<circle cx="%.1f" cy="%.1f" r="10" fill="none" stroke="#CC9900" stroke-width="2" opacity="0.5"/>\n',
        px, py
      ))
      points <- paste0(points, sprintf(
        '<circle cx="%.1f" cy="%.1f" r="5" fill="#CC9900" stroke="white" stroke-width="1.5"/>\n',
        px, py
      ))
      # Label
      points <- paste0(points, sprintf(
        '<text x="%.1f" y="%.1f" text-anchor="middle" font-size="9" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#CC9900" font-weight="500">recommended</text>\n',
        px, py - 16
      ))
    } else {
      points <- paste0(points, sprintf(
        '<circle cx="%.1f" cy="%.1f" r="4" fill="%s" stroke="white" stroke-width="1.5"/>\n',
        px, py, brand_colour
      ))
    }
  }

  # Plot area border
  border <- sprintf(
    '<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" fill="none" stroke="#e2e8f0" stroke-width="1"/>\n',
    margin_left, margin_top, plot_w, plot_h
  )

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" class="seg-chart seg-elbow-chart" role="img" aria-label="Elbow chart showing within-cluster sum of squares by number of clusters">\n%s%s\n%s\n%s\n%s%s%s\n</svg>',
    chart_width, chart_height, grid_lines, border, line_path, points, x_labels, x_title, y_title
  )

  htmltools::HTML(svg)
}


#' Build Multi-Metric Panel for Exploration Mode (SVG)
#'
#' Line chart showing silhouette score by k value. The recommended k is
#' highlighted with an accent marker.
#'
#' @param html_data List from data transformer (exploration mode, must contain metrics_df)
#' @param brand_colour Brand colour hex string
#' @param accent_colour Accent colour hex string
#' @return htmltools::HTML string containing SVG, or empty string if no data
#' @keywords internal
build_seg_metrics_chart <- function(html_data, brand_colour = "#323367",
                                     accent_colour = "#CC9900") {

  metrics_df <- html_data$metrics_df
  if (is.null(metrics_df)) return(htmltools::HTML(""))

  # Find silhouette column
  sil_col <- intersect(names(metrics_df), c("avg_silhouette", "silhouette", "avg_sil", "sil"))[1]
  k_col <- intersect(names(metrics_df), c("k", "K", "n_clusters"))[1]
  if (is.na(sil_col) || is.na(k_col)) return(htmltools::HTML(""))

  k_vals <- as.numeric(metrics_df[[k_col]])
  sil_vals <- as.numeric(metrics_df[[sil_col]])

  # Remove NAs
  valid <- !is.na(k_vals) & !is.na(sil_vals)
  k_vals <- k_vals[valid]
  sil_vals <- sil_vals[valid]
  if (length(k_vals) < 2) return(htmltools::HTML(""))

  # Sort by k
  ord <- order(k_vals)
  k_vals <- k_vals[ord]
  sil_vals <- sil_vals[ord]

  chart_width <- 500
  chart_height <- 250
  margin_left <- 60
  margin_right <- 30
  margin_top <- 30
  margin_bottom <- 50
  plot_w <- chart_width - margin_left - margin_right
  plot_h <- chart_height - margin_top - margin_bottom

  # Scale functions
  k_min <- min(k_vals)
  k_max <- max(k_vals)
  sil_min <- max(0, min(sil_vals) * 0.85)
  sil_max <- min(1.0, max(sil_vals) * 1.1)
  k_range <- max(k_max - k_min, 1)
  sil_range <- max(sil_max - sil_min, 0.01)

  to_x <- function(k) margin_left + (k - k_min) / k_range * plot_w
  to_y <- function(s) margin_top + (1 - (s - sil_min) / sil_range) * plot_h

  # Recommended k
  rec_k <- NULL
  if (!is.null(html_data$recommendation)) {
    rec_k <- html_data$recommendation$recommended_k %||%
             html_data$recommendation$k %||% NULL
  }

  # Gridlines (horizontal)
  grid_lines <- ""
  grid_step <- if (sil_range > 0.5) 0.2 else if (sil_range > 0.2) 0.1 else 0.05
  for (g in seq(0, 1, by = grid_step)) {
    if (g < sil_min || g > sil_max) next
    gy <- to_y(g)
    grid_lines <- paste0(grid_lines, sprintf(
      '<line x1="%.0f" y1="%.1f" x2="%.0f" y2="%.1f" stroke="#e2e8f0" stroke-width="1"/>\n',
      margin_left, gy, chart_width - margin_right, gy
    ))
    grid_lines <- paste0(grid_lines, sprintf(
      '<text x="%.0f" y="%.1f" text-anchor="end" font-size="10" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#94a3b8" font-weight="400" dominant-baseline="central">%.2f</text>\n',
      margin_left - 6, gy, g
    ))
  }

  # X-axis labels
  x_labels <- ""
  for (k in k_vals) {
    kx <- to_x(k)
    x_labels <- paste0(x_labels, sprintf(
      '<text x="%.1f" y="%.0f" text-anchor="middle" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#64748b" font-weight="400">%d</text>\n',
      kx, chart_height - margin_bottom + 18, as.integer(k)
    ))
    x_labels <- paste0(x_labels, sprintf(
      '<line x1="%.1f" y1="%.0f" x2="%.1f" y2="%.0f" stroke="#cbd5e1" stroke-width="1"/>\n',
      kx, margin_top + plot_h, kx, margin_top + plot_h + 4
    ))
  }

  # Axis titles
  x_title <- sprintf(
    '<text x="%.1f" y="%.0f" text-anchor="middle" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#64748b" font-weight="400">Number of clusters (k)</text>\n',
    margin_left + plot_w / 2, chart_height - 5
  )
  y_title <- sprintf(
    '<text x="10" y="%.1f" text-anchor="middle" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#64748b" font-weight="400" transform="rotate(-90, 10, %.1f)">Avg Silhouette</text>\n',
    margin_top + plot_h / 2, margin_top + plot_h / 2
  )

  # Line path
  path_points <- vapply(seq_along(k_vals), function(i) {
    sprintf("%.1f,%.1f", to_x(k_vals[i]), to_y(sil_vals[i]))
  }, character(1))
  line_path <- sprintf(
    '<polyline points="%s" fill="none" stroke="%s" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>\n',
    paste(path_points, collapse = " "), brand_colour
  )

  # Points
  points <- ""
  for (i in seq_along(k_vals)) {
    px <- to_x(k_vals[i])
    py <- to_y(sil_vals[i])

    is_rec <- !is.null(rec_k) && k_vals[i] == rec_k

    if (is_rec) {
      # Highlight ring
      points <- paste0(points, sprintf(
        '<circle cx="%.1f" cy="%.1f" r="10" fill="none" stroke="%s" stroke-width="2" opacity="0.5"/>\n',
        px, py, accent_colour
      ))
      points <- paste0(points, sprintf(
        '<circle cx="%.1f" cy="%.1f" r="5" fill="%s" stroke="white" stroke-width="1.5"/>\n',
        px, py, accent_colour
      ))
      # Value label
      points <- paste0(points, sprintf(
        '<text x="%.1f" y="%.1f" text-anchor="middle" font-size="9" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="%s" font-weight="500">%.3f</text>\n',
        px, py - 16, accent_colour, sil_vals[i]
      ))
      # "recommended" label
      points <- paste0(points, sprintf(
        '<text x="%.1f" y="%.1f" text-anchor="middle" font-size="8" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="%s" font-weight="400">recommended</text>\n',
        px, py - 25, accent_colour
      ))
    } else {
      points <- paste0(points, sprintf(
        '<circle cx="%.1f" cy="%.1f" r="4" fill="%s" stroke="white" stroke-width="1.5"/>\n',
        px, py, brand_colour
      ))
      # Value label
      points <- paste0(points, sprintf(
        '<text x="%.1f" y="%.1f" text-anchor="middle" font-size="9" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#64748b" font-weight="500">%.3f</text>\n',
        px, py - 10, sil_vals[i]
      ))
    }
  }

  # Plot area border
  border <- sprintf(
    '<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" fill="none" stroke="#e2e8f0" stroke-width="1"/>\n',
    margin_left, margin_top, plot_w, plot_h
  )

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" class="seg-chart seg-metrics-chart" role="img" aria-label="Average silhouette score by number of clusters">\n%s%s\n%s\n%s\n%s%s%s\n</svg>',
    chart_width, chart_height, grid_lines, border, line_path, points, x_labels, x_title, y_title
  )

  htmltools::HTML(svg)
}


#' Build Segment Overlap Heatmap (SVG)
#'
#' K x K heatmap showing pairwise segment similarity based on centroid
#' distances. Cells coloured from green (distinct, large distance) to red
#' (overlapping, small distance). Diagonal cells are shaded dark as
#' self-comparisons.
#'
#' @param html_data List from data transformer (must contain centers and segment_names)
#' @param brand_colour Brand colour hex string
#' @return htmltools::HTML string containing SVG, or empty string if no data
#' @keywords internal
build_seg_overlap_heatmap <- function(html_data, brand_colour = "#323367") {

  centers <- html_data$centers
  if (is.null(centers)) return(htmltools::HTML(""))

  if (!is.matrix(centers)) {
    centers <- tryCatch(as.matrix(centers), error = function(e) NULL)
    if (is.null(centers)) return(htmltools::HTML(""))
  }

  k <- nrow(centers)
  if (k < 2) return(htmltools::HTML(""))

  seg_names <- html_data$segment_names %||% paste0("Seg ", seq_len(k))

  # Compute pairwise Euclidean distances between centroids
  dist_matrix <- as.matrix(stats::dist(centers, method = "euclidean"))
  max_dist <- max(dist_matrix, na.rm = TRUE)
  if (max_dist == 0) max_dist <- 1
  norm_matrix <- dist_matrix / max_dist

  # Layout constants
  cell_size <- 80
  font_fam <- "'Inter', system-ui, -apple-system, 'Segoe UI', sans-serif"

  # Row label width: measure longest segment name (approx 6.5px per char at 12px)
  max_label_chars <- max(nchar(seg_names))
  label_width <- max(100, min(200, max_label_chars * 7 + 16))

  # Column headers: horizontal text above cells — need height for wrapped names
  header_height <- 40
  grid_top <- header_height
  grid_width <- k * cell_size
  chart_width <- label_width + grid_width + 20
  grid_height <- k * cell_size

  # Colour mapping: low distance (overlapping) = red, high distance = green
  overlap_colour <- function(norm_val) {
    if (is.na(norm_val)) return("#f1f5f9")
    v <- max(0, min(1, norm_val))
    if (v >= 0.7) return("#dcfce7")
    if (v >= 0.5) return("#eff6ff")
    if (v >= 0.3) return("#fef3c7")
    "#fee2e2"
  }

  # Column headers — horizontal, centred above each column
  header <- ""
  for (j in seq_len(k)) {
    cx <- label_width + (j - 1) * cell_size + cell_size / 2
    seg_label <- htmltools::htmlEscape(seg_names[j])
    header <- paste0(header, sprintf(
      '<text x="%.1f" y="%.0f" text-anchor="middle" font-size="11" font-family="%s" fill="%s" font-weight="600">%s</text>\n',
      cx, grid_top - 12, font_fam, brand_colour, seg_label
    ))
  }

  # Data cells + row labels
  cells <- ""
  for (i in seq_len(k)) {
    y <- grid_top + (i - 1) * cell_size

    # Row label — right-aligned before grid
    row_label <- htmltools::htmlEscape(seg_names[i])
    cells <- paste0(cells, sprintf(
      '<text x="%.0f" y="%.1f" text-anchor="end" font-size="12" font-family="%s" fill="#334155" font-weight="500" dominant-baseline="central">%s</text>\n',
      label_width - 12, y + cell_size / 2, font_fam, row_label
    ))

    for (j in seq_len(k)) {
      x <- label_width + (j - 1) * cell_size

      if (i == j) {
        bg_colour <- "#e2e8f0"
        value_text <- "\u2014"
        txt_colour <- "#94a3b8"
        font_size <- "13"
      } else {
        norm_val <- norm_matrix[i, j]
        bg_colour <- overlap_colour(norm_val)
        value_text <- sprintf("%.2f", dist_matrix[i, j])
        txt_colour <- if (norm_val < 0.3) "#991b1b" else "#1e293b"
        font_size <- "13"
      }

      cells <- paste0(cells, sprintf(
        '<rect x="%.0f" y="%.0f" width="%d" height="%d" rx="6" fill="%s" stroke="#ffffff" stroke-width="2"/>\n',
        x, y, cell_size, cell_size, bg_colour
      ))

      cells <- paste0(cells, sprintf(
        '<text x="%.1f" y="%.1f" text-anchor="middle" font-size="%s" font-family="%s" fill="%s" font-weight="600" dominant-baseline="central">%s</text>\n',
        x + cell_size / 2, y + cell_size / 2, font_size, font_fam, txt_colour, value_text
      ))
    }
  }

  # Legend — centred below the grid
  legend_y <- grid_top + grid_height + 16
  swatch_w <- 14

  legend_items <- list(
    list(colour = "#fee2e2", label = "Overlapping"),
    list(colour = "#fef3c7", label = "Moderate"),
    list(colour = "#eff6ff", label = "Good separation"),
    list(colour = "#dcfce7", label = "Distinct")
  )

  # Calculate total legend width to centre it
  legend_total_w <- 0
  for (item in legend_items) {
    legend_total_w <- legend_total_w + swatch_w + 6 + nchar(item$label) * 6.5 + 20
  }
  lx <- label_width + (grid_width - legend_total_w) / 2
  if (lx < 10) lx <- 10

  legend <- ""
  for (item in legend_items) {
    legend <- paste0(legend, sprintf(
      '<rect x="%.0f" y="%.0f" width="%d" height="%d" rx="3" fill="%s" stroke="#e2e8f0" stroke-width="1"/>\n',
      lx, legend_y, swatch_w, swatch_w, item$colour
    ))
    legend <- paste0(legend, sprintf(
      '<text x="%.0f" y="%.0f" font-size="11" font-family="%s" fill="#64748b" dominant-baseline="central">%s</text>\n',
      lx + swatch_w + 6, legend_y + swatch_w / 2, font_fam, item$label
    ))
    lx <- lx + swatch_w + 6 + nchar(item$label) * 6.5 + 20
  }

  total_height <- legend_y + swatch_w + 16
  chart_width <- max(chart_width, lx + 20)

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %.0f %.0f" class="seg-chart seg-overlap-heatmap" role="img" aria-label="Segment overlap heatmap showing pairwise Euclidean distances between %d segments">\n%s\n%s\n%s\n</svg>',
    chart_width, total_height, k, header, cells, legend
  )

  htmltools::HTML(svg)
}


#' Build Golden Questions Importance Chart (SVG)
#'
#' Horizontal bar chart showing Random Forest variable importance for
#' predicting segment membership. Bars show MeanDecreaseAccuracy with
#' accuracy badge in header.
#'
#' @param html_data List from data transformer (must contain golden_questions)
#' @param brand_colour Brand colour hex string
#' @return htmltools::HTML string containing SVG, or empty string if no data
#' @keywords internal
build_seg_golden_questions_chart <- function(html_data, brand_colour = "#323367") {

  gq <- html_data$golden_questions
  if (is.null(gq) || is.null(gq$top_questions)) return(htmltools::HTML(""))

  tq <- gq$top_questions
  if (nrow(tq) == 0) return(htmltools::HTML(""))

  n <- nrow(tq)
  accuracy <- gq$accuracy %||% NA_real_

  bar_height <- 32
  gap <- 10
  label_width <- 220
  chart_width <- 700
  bar_area_width <- chart_width - label_width - 80
  header_space <- 35
  total_height <- header_space + n * (bar_height + gap) + 20

  # Use importance_pct if available, else raw importance
  if ("importance_pct" %in% names(tq)) {
    vals <- tq$importance_pct
    fmt <- function(v) sprintf("%.0f%%", v)
  } else if ("importance" %in% names(tq)) {
    vals <- tq$importance
    fmt <- function(v) sprintf("%.2f", v)
  } else {
    return(htmltools::HTML(""))
  }

  max_val <- max(vals, na.rm = TRUE)
  if (max_val == 0) max_val <- 1

  # Resolve labels
  labels <- tq$variable
  ql <- html_data$question_labels
  if (!is.null(ql) && is.list(ql)) {
    labels <- vapply(labels, function(v) {
      lbl <- ql[[v]]
      if (!is.null(lbl) && nzchar(lbl)) lbl else v
    }, character(1), USE.NAMES = FALSE)
  }

  # Header: accuracy badge
  acc_text <- if (!is.na(accuracy)) sprintf("OOB Accuracy: %.0f%%", accuracy * 100) else ""
  header <- sprintf(
    '<text x="%.0f" y="18" font-size="12" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="%s" font-weight="600">%s</text>\n',
    label_width, brand_colour, acc_text
  )

  # Gridlines
  grid_lines <- ""
  grid_step <- if (max_val > 40) 20 else if (max_val > 20) 10 else 5
  for (g in seq(0, 100, by = grid_step)) {
    if (g > max_val * 1.15) break
    x_pos <- label_width + (g / max(max_val * 1.15, 1)) * bar_area_width
    grid_lines <- paste0(grid_lines, sprintf(
      '<line x1="%.1f" y1="%.0f" x2="%.1f" y2="%.0f" stroke="#e2e8f0" stroke-width="1"/>\n',
      x_pos, header_space, x_pos, total_height - 5
    ))
  }

  # Bars
  bars <- ""
  accent <- "#CC9900"

  for (i in seq_len(n)) {
    val <- vals[i]
    if (is.na(val)) val <- 0
    y <- header_space + (i - 1) * (bar_height + gap)
    bar_w <- max(2, (val / max(max_val * 1.15, 1)) * bar_area_width)

    bar_colour <- if (i == 1) accent else brand_colour
    opacity <- max(0.4, 1.0 - (i - 1) * 0.12)

    # Rank badge
    bars <- paste0(bars, sprintf(
      '<text x="8" y="%.1f" font-size="10" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#94a3b8" font-weight="500" dominant-baseline="central">#%d</text>\n',
      y + bar_height / 2, i
    ))

    # Label
    lbl <- labels[i]
    if (nchar(lbl) > 35) lbl <- paste0(substr(lbl, 1, 33), "\u2026")
    bars <- paste0(bars, sprintf(
      '<text x="%.0f" y="%.1f" text-anchor="end" font-size="11" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#334155" font-weight="400" dominant-baseline="central">%s</text>\n',
      label_width - 8, y + bar_height / 2, htmltools::htmlEscape(lbl)
    ))

    # Bar
    bars <- paste0(bars, sprintf(
      '<rect x="%.0f" y="%.1f" width="%.1f" height="%d" rx="4" fill="%s" opacity="%.2f"/>\n',
      label_width, y, bar_w, bar_height, bar_colour, opacity
    ))

    # Value
    bars <- paste0(bars, sprintf(
      '<text x="%.1f" y="%.1f" font-size="10" font-family="\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif" fill="#334155" font-weight="500" dominant-baseline="central">%s</text>\n',
      label_width + bar_w + 6, y + bar_height / 2, fmt(val)
    ))
  }

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="seg-chart seg-golden-questions-chart" role="img" aria-label="Golden questions importance chart showing top %d predictive variables">\n%s\n%s\n%s\n</svg>',
    chart_width, total_height, n, header, grid_lines, bars
  )

  htmltools::HTML(svg)
}
