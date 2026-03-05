# ==============================================================================
# KEYDRIVER HTML REPORT - QUADRANT SECTION (IPA)
# ==============================================================================
# Generates pure SVG Importance-Performance Analysis (IPA) quadrant chart
# and supporting HTML summary for the keydriver HTML report.
# No ggplot2 dependency -- pure SVG string construction.
#
# Functions:
#   build_kd_quadrant_chart()        - SVG scatter quadrant plot
#   build_kd_quadrant_action_table() - Wrapper for quadrant action table
#   build_kd_quadrant_summary()      - HTML summary block
# ==============================================================================


# ==============================================================================
# QUADRANT CHART (PURE SVG)
# ==============================================================================

#' Build IPA Quadrant Chart as Inline SVG
#'
#' Creates a pure SVG importance-performance quadrant plot. Drivers are
#' positioned by Performance (x-axis) and Importance (y-axis) across four
#' shaded quadrants. No ggplot2 dependency.
#'
#' @param quadrant_data List with components:
#'   \describe{
#'     \item{data}{data.frame with columns: driver, importance_normalized,
#'       performance_normalized, quadrant}
#'     \item{config}{list with importance_threshold, performance_threshold,
#'       quadrant_1_name, quadrant_2_name, quadrant_3_name, quadrant_4_name}
#'     \item{action_table}{data.frame with columns: Driver, Quadrant,
#'       Priority, Action}
#'   }
#' @param config Configuration list (brand_colour, accent_colour, etc.)
#' @return \code{htmltools::HTML(svg_string)} or NULL if no data
#' @keywords internal
build_kd_quadrant_chart <- function(quadrant_data, config) {

  # --- Guard: NULL / empty data ---
  if (is.null(quadrant_data)) return(NULL)

  qd <- quadrant_data$data
  if (is.null(qd) || !is.data.frame(qd) || nrow(qd) == 0) {
    cat("[WARN] build_kd_quadrant_chart: no quadrant data to plot\n")
    return(NULL)
  }

  qcfg <- quadrant_data$config %||% list()

  # Required columns

  required_cols <- c("driver", "importance_normalized", "performance_normalized")
  missing_cols <- setdiff(required_cols, names(qd))
  if (length(missing_cols) > 0) {
    cat(sprintf("[WARN] build_kd_quadrant_chart: missing columns: %s\n",
                paste(missing_cols, collapse = ", ")))
    return(NULL)
  }

  # Drop rows with NA in critical columns
  valid <- !is.na(qd$importance_normalized) & !is.na(qd$performance_normalized)
  qd <- qd[valid, , drop = FALSE]
  if (nrow(qd) == 0) {
    cat("[WARN] build_kd_quadrant_chart: all rows have NA values\n")
    return(NULL)
  }

  # --- Layout constants ---
  svg_w <- 700
  svg_h <- 500
  margin_left   <- 60
  margin_right  <- 30
  margin_top    <- 30
  margin_bottom <- 50
  plot_w <- svg_w - margin_left - margin_right
  plot_h <- svg_h - margin_top - margin_bottom

  # --- Thresholds ---
  imp_thresh  <- qcfg$importance_threshold  %||% 50
  perf_thresh <- qcfg$performance_threshold %||% 50

  # --- Quadrant names ---
  q1_name <- toupper(qcfg$quadrant_1_name %||% "Concentrate Here")
  q2_name <- toupper(qcfg$quadrant_2_name %||% "Keep Up Good Work")
  q3_name <- toupper(qcfg$quadrant_3_name %||% "Low Priority")
  q4_name <- toupper(qcfg$quadrant_4_name %||% "Possible Overkill")

  # --- Data ranges (always 0-100 for normalized) ---
  x_min <- 0; x_max <- 100
  y_min <- 0; y_max <- 100

  # --- Brand colour ---
  brand_colour <- config$brand_colour %||% "#ec4899"

  # --- Helper: scale data value to pixel coordinate ---
  scale_x <- function(v) margin_left + (v - x_min) / (x_max - x_min) * plot_w
  scale_y <- function(v) margin_top + plot_h - (v - y_min) / (y_max - y_min) * plot_h

  # --- Font family ---
  font_family <- "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"

  # === BUILD SVG ===
  svg <- character(0)

  # Header
  svg <- c(svg, sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" role="img" aria-label="Importance-Performance Analysis quadrant chart" class="kd-quadrant-svg" style="font-family:%s;">',
    svg_w, svg_h, font_family
  ))

  # --- Quadrant background shading ---
  # Threshold pixel positions
  thresh_px <- scale_x(perf_thresh)
  thresh_py <- scale_y(imp_thresh)

  # Q1: upper-left (high importance, low performance) - light red
  svg <- c(svg, sprintf(
    '<rect x="%g" y="%g" width="%g" height="%g" fill="#fff5f5"/>',
    margin_left, margin_top,
    thresh_px - margin_left, thresh_py - margin_top
  ))

  # Q2: upper-right (high importance, high performance) - light green
  svg <- c(svg, sprintf(
    '<rect x="%g" y="%g" width="%g" height="%g" fill="#f0fff4"/>',
    thresh_px, margin_top,
    margin_left + plot_w - thresh_px, thresh_py - margin_top
  ))

  # Q3: lower-left (low importance, low performance) - light grey
  svg <- c(svg, sprintf(
    '<rect x="%g" y="%g" width="%g" height="%g" fill="#f7fafc"/>',
    margin_left, thresh_py,
    thresh_px - margin_left, margin_top + plot_h - thresh_py
  ))

  # Q4: lower-right (low importance, high performance) - light amber
  svg <- c(svg, sprintf(
    '<rect x="%g" y="%g" width="%g" height="%g" fill="#fffbeb"/>',
    thresh_px, thresh_py,
    margin_left + plot_w - thresh_px, margin_top + plot_h - thresh_py
  ))

  # --- Gridlines (faint, behind everything else) ---
  grid_ticks <- seq(0, 100, by = 20)
  for (tick in grid_ticks) {
    gx <- scale_x(tick)
    gy <- scale_y(tick)
    # Vertical gridline
    svg <- c(svg, sprintf(
      '<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="#e2e8f0" stroke-width="0.5"/>',
      gx, margin_top, gx, margin_top + plot_h
    ))
    # Horizontal gridline
    svg <- c(svg, sprintf(
      '<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="#e2e8f0" stroke-width="0.5"/>',
      margin_left, gy, margin_left + plot_w, gy
    ))
  }

  # --- Threshold lines (dashed) ---
  # Vertical: performance threshold
  svg <- c(svg, sprintf(
    '<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="6,4"/>',
    thresh_px, margin_top, thresh_px, margin_top + plot_h
  ))
  # Horizontal: importance threshold
  svg <- c(svg, sprintf(
    '<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="6,4"/>',
    margin_left, thresh_py, margin_left + plot_w, thresh_py
  ))

  # --- Plot border ---
  svg <- c(svg, sprintf(
    '<rect x="%g" y="%g" width="%g" height="%g" fill="none" stroke="#e2e8f0" stroke-width="0.5"/>',
    margin_left, margin_top, plot_w, plot_h
  ))

  # --- Quadrant labels (corner annotations) ---
  label_inset_x <- 8
  label_inset_y <- 14

  # Q1: upper-left corner
  svg <- c(svg, sprintf(
    '<text x="%g" y="%g" fill="#94a3b8" font-size="12" font-weight="600" text-anchor="start">%s</text>',
    margin_left + label_inset_x, margin_top + label_inset_y,
    htmltools::htmlEscape(q1_name)
  ))

  # Q2: upper-right corner
  svg <- c(svg, sprintf(
    '<text x="%g" y="%g" fill="#94a3b8" font-size="12" font-weight="600" text-anchor="end">%s</text>',
    margin_left + plot_w - label_inset_x, margin_top + label_inset_y,
    htmltools::htmlEscape(q2_name)
  ))

  # Q3: lower-left corner
  svg <- c(svg, sprintf(
    '<text x="%g" y="%g" fill="#94a3b8" font-size="12" font-weight="600" text-anchor="start">%s</text>',
    margin_left + label_inset_x, margin_top + plot_h - label_inset_x,
    htmltools::htmlEscape(q3_name)
  ))

  # Q4: lower-right corner
  svg <- c(svg, sprintf(
    '<text x="%g" y="%g" fill="#94a3b8" font-size="12" font-weight="600" text-anchor="end">%s</text>',
    margin_left + plot_w - label_inset_x, margin_top + plot_h - label_inset_x,
    htmltools::htmlEscape(q4_name)
  ))

  # --- Axis tick labels ---
  for (tick in grid_ticks) {
    gx <- scale_x(tick)
    gy <- scale_y(tick)
    # X-axis label (bottom)
    svg <- c(svg, sprintf(
      '<text x="%g" y="%g" fill="#64748b" font-size="10" font-weight="400" text-anchor="middle">%d</text>',
      gx, margin_top + plot_h + 16, tick
    ))
    # Y-axis label (left)
    svg <- c(svg, sprintf(
      '<text x="%g" y="%g" fill="#64748b" font-size="10" font-weight="400" text-anchor="end" dominant-baseline="central">%d</text>',
      margin_left - 8, gy, tick
    ))
  }

  # --- Axis titles ---
  # X-axis title (Performance)
  svg <- c(svg, sprintf(
    '<text x="%g" y="%g" fill="#64748b" font-size="12" font-weight="400" text-anchor="middle">Performance</text>',
    margin_left + plot_w / 2, svg_h - 6
  ))

  # Y-axis title (Importance) -- rotated
  svg <- c(svg, sprintf(
    '<text x="%g" y="%g" fill="#64748b" font-size="12" font-weight="400" text-anchor="middle" transform="rotate(-90, %g, %g)">Importance</text>',
    14, margin_top + plot_h / 2, 14, margin_top + plot_h / 2
  ))

  # --- Driver points and labels ---
  # Compute pixel positions for all drivers
  n <- nrow(qd)
  px <- numeric(n)
  py <- numeric(n)
  for (i in seq_len(n)) {
    px[i] <- scale_x(qd$performance_normalized[i])
    py[i] <- scale_y(qd$importance_normalized[i])
  }

  # Compute importance range for opacity scaling
  imp_range <- range(qd$importance_normalized, na.rm = TRUE)
  imp_span <- imp_range[2] - imp_range[1]

  # Parse brand colour for opacity blending
  br <- strtoi(substr(brand_colour, 2, 3), 16L)
  bg <- strtoi(substr(brand_colour, 4, 5), 16L)
  bb <- strtoi(substr(brand_colour, 6, 7), 16L)
  if (is.na(br) || is.na(bg) || is.na(bb)) {
    br <- 236L; bg <- 72L; bb <- 153L
  }

  # Draw circles
  point_radius <- 6
  for (i in seq_len(n)) {
    # Opacity based on importance (higher = more opaque)
    opacity <- if (imp_span > 0) {
      0.45 + 0.55 * (qd$importance_normalized[i] - imp_range[1]) / imp_span
    } else {
      0.75
    }

    svg <- c(svg, sprintf(
      '<circle cx="%g" cy="%g" r="%d" fill="%s" opacity="%.2f" stroke="#ffffff" stroke-width="1.5"/>',
      px[i], py[i], point_radius, brand_colour, opacity
    ))
  }

  # --- Label placement with collision avoidance ---
  placed_labels <- resolve_label_positions(qd$driver, px, py, point_radius,
                                           margin_left, margin_top,
                                           margin_left + plot_w,
                                           margin_top + plot_h)

  for (i in seq_len(nrow(placed_labels))) {
    svg <- c(svg, sprintf(
      '<text x="%g" y="%g" fill="#1e293b" font-size="11" font-weight="500" text-anchor="%s">%s</text>',
      placed_labels$lx[i], placed_labels$ly[i],
      placed_labels$anchor[i],
      htmltools::htmlEscape(placed_labels$label[i])
    ))
  }

  # Close SVG
  svg <- c(svg, '</svg>')

  htmltools::HTML(paste(svg, collapse = "\n"))
}


# ==============================================================================
# LABEL COLLISION AVOIDANCE
# ==============================================================================

#' Resolve Label Positions to Avoid Overlap
#'
#' For each driver point, tries four placement positions (right, above,
#' below, left) and picks the first that does not overlap already-placed
#' labels. Falls back to right placement if all four collide.
#'
#' @param labels Character vector of driver names
#' @param px Numeric vector of point x pixel coords
#' @param py Numeric vector of point y pixel coords
#' @param r Point radius in pixels
#' @param plot_x_min Minimum x of plot area
#' @param plot_y_min Minimum y of plot area
#' @param plot_x_max Maximum x of plot area
#' @param plot_y_max Maximum y of plot area
#' @return data.frame with columns: label, lx, ly, anchor
#' @keywords internal
resolve_label_positions <- function(labels, px, py, r,
                                     plot_x_min, plot_y_min,
                                     plot_x_max, plot_y_max) {

  n <- length(labels)
  offset <- r + 6  # distance from centre of point to label origin
  char_w <- 6.2    # approximate width per character at 11px
  label_h <- 13    # approximate label height

  out <- data.frame(
    label  = labels,
    lx     = numeric(n),
    ly     = numeric(n),
    anchor = character(n),
    stringsAsFactors = FALSE
  )

  # Track placed bounding boxes: list of (x_min, y_min, x_max, y_max)
  placed <- vector("list", 0)

  for (i in seq_len(n)) {
    text_w <- nchar(labels[i]) * char_w

    # Candidate positions: (x, y, anchor, bbox)
    candidates <- list(
      # Right
      list(
        x = px[i] + offset,
        y = py[i] + 4,
        anchor = "start",
        bbox = c(px[i] + offset, py[i] - label_h / 2,
                 px[i] + offset + text_w, py[i] + label_h / 2)
      ),
      # Above
      list(
        x = px[i],
        y = py[i] - offset,
        anchor = "middle",
        bbox = c(px[i] - text_w / 2, py[i] - offset - label_h,
                 px[i] + text_w / 2, py[i] - offset)
      ),
      # Below
      list(
        x = px[i],
        y = py[i] + offset + label_h,
        anchor = "middle",
        bbox = c(px[i] - text_w / 2, py[i] + offset,
                 px[i] + text_w / 2, py[i] + offset + label_h)
      ),
      # Left
      list(
        x = px[i] - offset,
        y = py[i] + 4,
        anchor = "end",
        bbox = c(px[i] - offset - text_w, py[i] - label_h / 2,
                 px[i] - offset, py[i] + label_h / 2)
      )
    )

    chosen <- NULL
    for (cand in candidates) {
      bb <- cand$bbox
      # Skip if out of plot bounds
      if (bb[1] < plot_x_min || bb[3] > plot_x_max ||
          bb[2] < plot_y_min || bb[4] > plot_y_max) {
        next
      }
      # Check overlap with placed labels
      has_overlap <- FALSE
      for (pb in placed) {
        if (bb[1] < pb[3] && bb[3] > pb[1] && bb[2] < pb[4] && bb[4] > pb[2]) {
          has_overlap <- TRUE
          break
        }
      }
      if (!has_overlap) {
        chosen <- cand
        break
      }
    }

    # Fallback: use first candidate (right) if nothing else works
    if (is.null(chosen)) {
      chosen <- candidates[[1]]
    }

    out$lx[i]     <- chosen$x
    out$ly[i]     <- chosen$y
    out$anchor[i] <- chosen$anchor
    placed[[length(placed) + 1]] <- chosen$bbox
  }

  out
}


# ==============================================================================
# QUADRANT ACTION TABLE (WRAPPER)
# ==============================================================================

#' Build Quadrant Action Table
#'
#' Wrapper/alias for the quadrant action table. The table is typically
#' already built by \code{02_table_builder.R}. This function adds
#' quadrant-specific formatting or returns NULL if data is absent.
#'
#' @param quadrant_data List with \code{$action_table} data.frame
#'   (columns: Driver, Quadrant, Priority, Action)
#' @return \code{htmltools::HTML} formatted table or NULL
#' @keywords internal
build_kd_quadrant_action_table <- function(quadrant_data) {

  if (is.null(quadrant_data)) return(NULL)

  action_tbl <- quadrant_data$action_table
  if (is.null(action_tbl) || !is.data.frame(action_tbl) || nrow(action_tbl) == 0) {
    return(NULL)
  }

  # Quadrant colour map for row badge styling
  quadrant_colours <- list(
    "Concentrate Here"  = "#ef4444",
    "Keep Up Good Work" = "#22c55e",
    "Low Priority"      = "#94a3b8",
    "Possible Overkill" = "#f59e0b"
  )

  font_family <- "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"

  # Build table HTML
  rows_html <- character(0)
  for (i in seq_len(nrow(action_tbl))) {
    row <- action_tbl[i, ]

    # Resolve quadrant name from available columns
    quad_name <- ""
    if ("Quadrant" %in% names(row)) {
      quad_name <- as.character(row$Quadrant)
    } else if ("Zone" %in% names(row)) {
      quad_name <- as.character(row$Zone)
    }

    badge_col <- quadrant_colours[[quad_name]] %||% "#94a3b8"

    driver_text <- if ("Driver" %in% names(row)) {
      htmltools::htmlEscape(as.character(row$Driver))
    } else {
      ""
    }

    priority_text <- if ("Priority" %in% names(row)) {
      htmltools::htmlEscape(as.character(row$Priority))
    } else {
      ""
    }

    action_text <- if ("Action" %in% names(row)) {
      htmltools::htmlEscape(as.character(row$Action))
    } else if ("Recommended Action" %in% names(row)) {
      htmltools::htmlEscape(as.character(row[["Recommended Action"]]))
    } else {
      ""
    }

    row_html <- sprintf(
      '<tr class="kd-quadrant-action-row"><td class="kd-quadrant-action-cell" style="font-weight:500;">%s</td><td class="kd-quadrant-action-cell"><span class="kd-quadrant-badge" style="background-color:%s;color:#fff;padding:2px 8px;border-radius:3px;font-size:10px;font-weight:600;">%s</span></td><td class="kd-quadrant-action-cell" style="text-align:center;">%s</td><td class="kd-quadrant-action-cell" style="font-size:12px;color:#475569;">%s</td></tr>',
      driver_text, badge_col,
      htmltools::htmlEscape(quad_name),
      priority_text, action_text
    )

    rows_html <- c(rows_html, row_html)
  }

  table_html <- sprintf(
    '<table class="kd-quadrant-action-table" style="width:100%%;border-collapse:collapse;font-family:%s;font-size:13px;"><thead><tr style="border-bottom:2px solid #e2e8f0;"><th class="kd-quadrant-action-th" style="text-align:left;padding:8px 12px;color:#64748b;font-weight:600;font-size:11px;">Driver</th><th class="kd-quadrant-action-th" style="text-align:left;padding:8px 12px;color:#64748b;font-weight:600;font-size:11px;">Zone</th><th class="kd-quadrant-action-th" style="text-align:center;padding:8px 12px;color:#64748b;font-weight:600;font-size:11px;">Priority</th><th class="kd-quadrant-action-th" style="text-align:left;padding:8px 12px;color:#64748b;font-weight:600;font-size:11px;">Action</th></tr></thead><tbody>%s</tbody></table>',
    font_family,
    paste(rows_html, collapse = "\n")
  )

  htmltools::HTML(table_html)
}


# ==============================================================================
# QUADRANT SUMMARY BLOCK
# ==============================================================================

#' Build Quadrant Summary HTML Block
#'
#' Returns a compact HTML summary showing the number of drivers per
#' quadrant and the top-priority driver name.
#'
#' @param quadrant_data List with \code{$data} data.frame and
#'   \code{$action_table} data.frame
#' @return \code{htmltools::tags$div()} block or NULL
#' @keywords internal
build_kd_quadrant_summary <- function(quadrant_data) {

  if (is.null(quadrant_data)) return(NULL)

  qd <- quadrant_data$data
  if (is.null(qd) || !is.data.frame(qd) || nrow(qd) == 0) {
    return(NULL)
  }

  qcfg <- quadrant_data$config %||% list()

  # Count drivers per quadrant
  q_names <- c(
    "1" = qcfg$quadrant_1_name %||% "Concentrate Here",
    "2" = qcfg$quadrant_2_name %||% "Keep Up Good Work",
    "3" = qcfg$quadrant_3_name %||% "Low Priority",
    "4" = qcfg$quadrant_4_name %||% "Possible Overkill"
  )

  # Quadrant colours matching the chart shading
  q_badge_colours <- c(
    "1" = "#ef4444",
    "2" = "#22c55e",
    "3" = "#94a3b8",
    "4" = "#f59e0b"
  )

  quadrant_col <- if ("quadrant" %in% names(qd)) qd$quadrant else NULL
  if (is.null(quadrant_col)) {
    cat("[WARN] build_kd_quadrant_summary: no 'quadrant' column in data\n")
    return(NULL)
  }

  counts <- table(factor(quadrant_col, levels = 1:4))

  # Build count badges
  count_items <- lapply(as.character(1:4), function(q) {
    htmltools::tags$div(
      class = "kd-quadrant-summary-item",
      style = "display:inline-block;margin-right:16px;margin-bottom:8px;",
      htmltools::tags$span(
        class = "kd-quadrant-summary-badge",
        style = sprintf(
          "display:inline-block;background-color:%s;color:#fff;padding:2px 8px;border-radius:3px;font-size:11px;font-weight:600;margin-right:6px;",
          q_badge_colours[q]
        ),
        as.character(counts[q])
      ),
      htmltools::tags$span(
        class = "kd-quadrant-summary-label",
        style = "font-size:12px;color:#475569;font-weight:400;",
        q_names[q]
      )
    )
  })

  # Top priority driver
  top_driver <- NULL
  action_tbl <- quadrant_data$action_table
  if (!is.null(action_tbl) && is.data.frame(action_tbl) && nrow(action_tbl) > 0) {
    if ("Driver" %in% names(action_tbl)) {
      top_driver <- as.character(action_tbl$Driver[1])
    }
  }
  # Fallback: find driver in Q1 with highest importance
  if (is.null(top_driver) && any(quadrant_col == 1)) {
    q1_rows <- qd[quadrant_col == 1, , drop = FALSE]
    if (nrow(q1_rows) > 0 && "importance_normalized" %in% names(q1_rows)) {
      top_idx <- which.max(q1_rows$importance_normalized)
      top_driver <- as.character(q1_rows$driver[top_idx])
    }
  }

  top_driver_block <- if (!is.null(top_driver)) {
    htmltools::tags$div(
      class = "kd-quadrant-summary-top",
      style = "margin-top:10px;padding:8px 12px;background-color:#fef2f2;border-left:3px solid #ef4444;border-radius:3px;",
      htmltools::tags$span(
        style = "font-size:11px;color:#64748b;font-weight:600;text-transform:uppercase;",
        "Top Priority: "
      ),
      htmltools::tags$span(
        style = "font-size:13px;color:#1e293b;font-weight:500;",
        top_driver
      )
    )
  } else {
    NULL
  }

  htmltools::tags$div(
    class = "kd-quadrant-summary",
    style = "padding:12px 0;",
    htmltools::tags$div(
      class = "kd-quadrant-summary-counts",
      style = "margin-bottom:4px;",
      count_items
    ),
    top_driver_block
  )
}


# ==============================================================================
# NULL-COALESCING OPERATOR GUARD
# ==============================================================================

#' @keywords internal
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
