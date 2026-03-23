# ==============================================================================
# KEYDRIVER HTML REPORT - CHART BUILDER
# ==============================================================================
# SVG chart generators for keydriver HTML report.
# All charts are inline SVG, no external dependencies required.
# ==============================================================================
#
# Design language (Turas design system):
#   - Rounded corners rx="4" on bars
#   - Muted palette, soft charcoal labels (#64748b)
#   - Font-weight 500 for values, 400 for labels
#   - Faint gridlines (#e2e8f0), no outer box on charts
#   - NO gradients, drop shadows, or hover lift animations
#
# All CSS classes/IDs use `kd-` prefix for Report Hub namespace isolation.
# ==============================================================================

# Null-coalescing operator guard
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Design Tokens
.kd_font_family <- "'Inter', system-ui, -apple-system, 'Segoe UI', sans-serif"
.kd_label_colour <- "#64748b"
.kd_value_colour <- "#334155"
.kd_grid_colour  <- "#e2e8f0"
.kd_muted_colour <- "#94a3b8"


# ==============================================================================
# SVG HELPERS
# ==============================================================================

#' @keywords internal
.kd_html_escape <- function(x) {
  if (is.null(x) || length(x) == 0) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x <- gsub("'", "&#39;", x, fixed = TRUE)
  x
}

#' Truncate label to fit within pixel width (approximate 6px/char at 11px font)
#' @keywords internal
.kd_truncate_label <- function(text, max_chars = 28) {
  if (is.null(text) || is.na(text)) return("")
  text <- as.character(text)
  if (nchar(text) <= max_chars) return(text)
  paste0(substr(text, 1, max_chars - 1), "\u2026")
}

#' @keywords internal
.kd_svg_text <- function(x, y, text, size = 11, fill = .kd_label_colour,
                         weight = "400", anchor = "start", baseline = NULL) {
  bl <- if (!is.null(baseline)) sprintf(' dominant-baseline="%s"', baseline) else ""
  sprintf('<text x="%.1f" y="%.1f" text-anchor="%s" font-size="%d" fill="%s" font-weight="%s"%s>%s</text>',
          x, y, anchor, as.integer(size), fill, weight, bl, .kd_html_escape(text))
}

#' @keywords internal
.kd_svg_bar <- function(x, y, w, h, fill, opacity = 1.0, rx = 4) {
  sprintf('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%d" fill="%s" opacity="%.2f"/>',
          x, y, w, h, as.integer(rx), fill, opacity)
}

#' @keywords internal
.kd_svg_line <- function(x1, y1, x2, y2, stroke = .kd_grid_colour,
                         width = 1, dash = NULL, opacity = 1.0) {
  d <- if (!is.null(dash)) sprintf(' stroke-dasharray="%s"', dash) else ""
  sprintf('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%.1f"%s opacity="%.2f"/>',
          x1, y1, x2, y2, stroke, width, d, opacity)
}

#' @keywords internal
.kd_svg_circle <- function(cx, cy, r, fill, stroke = "white", sw = 1.5) {
  sprintf('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="%.1f"/>',
          cx, cy, r, fill, stroke, sw)
}

#' Blend hex colour toward white by opacity factor (0=white, 1=full)
#' @keywords internal
.kd_mute_colour <- function(hex, alpha = 0.2) {
  r <- strtoi(substr(hex, 2, 3), 16L)
  g <- strtoi(substr(hex, 4, 5), 16L)
  b <- strtoi(substr(hex, 6, 7), 16L)
  if (is.na(r)) r <- 128L; if (is.na(g)) g <- 128L; if (is.na(b)) b <- 128L
  sprintf("#%02x%02x%02x",
          as.integer(r * alpha + 255 * (1 - alpha)),
          as.integer(g * alpha + 255 * (1 - alpha)),
          as.integer(b * alpha + 255 * (1 - alpha)))
}

#' Nice step size for axis gridlines (~4-8 gridlines)
#' @keywords internal
.kd_nice_step <- function(range_val) {
  if (is.na(range_val) || range_val <= 0) return(1)
  rough <- range_val / 5
  mag <- 10^floor(log10(rough))
  res <- rough / mag
  if (res <= 1.5) return(mag)
  if (res <= 3.5) return(2 * mag)
  if (res <= 7.5) return(5 * mag)
  10 * mag
}


# ==============================================================================
# 1. IMPORTANCE BAR CHART
# ==============================================================================

#' Build Key Driver Importance Bar Chart (SVG)
#'
#' Horizontal bar chart sorted by rank. Top 3 bars use brand colour;
#' others use a muted (20% opacity) version.
#'
#' @param importance List of entries with rank, driver, label, pct, top3
#' @param brand_colour Brand colour hex string
#' @return htmltools::tags$div wrapping SVG, or NULL
#' @keywords internal
build_kd_importance_chart <- function(importance, brand_colour = "#323367") {

  if (is.null(importance) || length(importance) == 0) return(NULL)

  n <- length(importance)
  bar_h <- 28; gap <- 6; lbl_w <- 200; chart_w <- 700
  bar_area <- chart_w - lbl_w - 70
  total_h <- n * (bar_h + gap) + 40

  max_pct <- max(vapply(importance, function(d) as.numeric(d$pct %||% 0), numeric(1)), na.rm = TRUE)
  if (is.na(max_pct) || max_pct == 0) max_pct <- 1
  scale_max <- max(max_pct * 1.1, 1)
  muted <- .kd_mute_colour(brand_colour, 0.20)

  s <- sprintf('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="kd-chart kd-importance-chart" role="img" aria-label="Driver importance bar chart" style="font-family:%s;">',
               chart_w, total_h, .kd_font_family)

  # Gridlines
  for (g in seq(0, 100, by = 25)) {
    if (g > scale_max) break
    xp <- lbl_w + (g / scale_max) * bar_area
    s <- paste0(s, "\n", .kd_svg_line(xp, 20, xp, total_h - 5))
    s <- paste0(s, "\n", .kd_svg_text(xp, 15, sprintf("%d%%", g), size = 10,
                                       fill = .kd_muted_colour, anchor = "middle"))
  }

  # Bars
  for (i in seq_along(importance)) {
    d <- importance[[i]]
    y <- 25 + (i - 1) * (bar_h + gap)
    pv <- as.numeric(d$pct %||% 0)
    bw <- max(2, (pv / scale_max) * bar_area)
    t3 <- isTRUE(d$top3)
    fill <- if (t3) brand_colour else muted
    op <- if (t3) 1.0 else 0.90

    s <- paste0(s, sprintf('\n<g class="kd-importance-row" data-kd-rank="%d" data-kd-pct="%.1f" data-kd-top3="%s">',
                           as.integer(d$rank %||% i), pv, if (t3) "yes" else "no"))
    s <- paste0(s, "\n", .kd_svg_text(lbl_w - 8, y + bar_h/2, .kd_truncate_label(as.character(d$label %||% "")),
                                       size = 12, fill = .kd_value_colour, anchor = "end", baseline = "central"))
    s <- paste0(s, "\n", .kd_svg_bar(lbl_w, y, bw, bar_h, fill, op))
    s <- paste0(s, "\n", .kd_svg_text(lbl_w + bw + 6, y + bar_h/2, sprintf("%.0f%%", pv),
                                       size = 11, fill = .kd_value_colour, weight = "500",
                                       anchor = "start", baseline = "central"))
    s <- paste0(s, "\n</g>")
  }

  s <- paste0(s, "\n</svg>")
  htmltools::tags$div(class = "kd-chart-container", htmltools::HTML(s))
}


# ==============================================================================
# 2. METHOD AGREEMENT CHART (Bump / Rank Comparison)
# ==============================================================================

#' Build Key Driver Method Agreement Chart (SVG)
#'
#' Bump chart: driver ranks across methods. Top 3 (by mean rank) highlighted.
#'
#' @param method_comparison data.frame with Driver and Rank_* columns, or list
#' @param brand_colour Brand colour hex
#' @param accent_colour Accent colour hex
#' @return htmltools::tags$div wrapping SVG, or NULL
#' @keywords internal
build_kd_method_agreement_chart <- function(method_comparison,
                                            brand_colour = "#323367",
                                            accent_colour = "#f59e0b") {

  if (is.null(method_comparison)) return(NULL)

  # Normalise to list of {label, ranks}
  if (is.data.frame(method_comparison)) {
    if (nrow(method_comparison) == 0) return(NULL)
    rank_cols <- grep("^Rank_", names(method_comparison), value = TRUE)
    if (length(rank_cols) < 2) return(NULL)
    method_labels <- gsub("_", " ", gsub("^Rank_", "", rank_cols))
    entries <- lapply(seq_len(nrow(method_comparison)), function(i) {
      row <- method_comparison[i, , drop = FALSE]
      list(label = as.character(row$Driver %||% row$Label %||% ""),
           ranks = vapply(rank_cols, function(k) as.numeric(row[[k]]), numeric(1)))
    })
    avg_ranks <- rowMeans(as.matrix(method_comparison[, rank_cols, drop = FALSE]), na.rm = TRUE)
  } else if (is.list(method_comparison)) {
    if (length(method_comparison) == 0) return(NULL)
    rk <- grep("_Rank$|_rank$", names(method_comparison[[1]]), value = TRUE)
    if (length(rk) < 2) return(NULL)
    method_labels <- gsub("_", " ", gsub("_Rank$|_rank$", "", rk))
    n_d <- length(method_comparison)
    entries <- lapply(method_comparison, function(d) {
      list(label = as.character(d$label %||% d$Driver %||% ""),
           ranks = vapply(rk, function(k) as.numeric(d[[k]] %||% n_d), numeric(1)))
    })
    avg_ranks <- vapply(entries, function(d) mean(d$ranks, na.rm = TRUE), numeric(1))
  } else {
    return(NULL)
  }

  n_d <- length(entries); n_m <- length(method_labels)
  top3 <- order(avg_ranks)[seq_len(min(3, n_d))]

  # Layout
  lm <- 160; rm <- 40; cs <- 140
  cw <- lm + n_m * cs + rm; rh <- 30; tm <- 50; bm <- 20
  th <- tm + n_d * rh + bm
  col_x <- lm + (seq_len(n_m) - 1) * cs

  s <- sprintf('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="kd-chart kd-method-agreement-chart" role="img" aria-label="Method agreement bump chart" style="font-family:%s;">',
               cw, th, .kd_font_family)

  # Column headers + guide lines
  for (m in seq_len(n_m)) {
    s <- paste0(s, "\n", .kd_svg_text(col_x[m], 25, method_labels[m], size = 11,
                                       fill = .kd_value_colour, weight = "500", anchor = "middle"))
    s <- paste0(s, "\n", .kd_svg_line(col_x[m], 35, col_x[m], th - bm))
  }

  # Driver lines, dots, labels
  for (i in seq_along(entries)) {
    d <- entries[[i]]; is_t <- i %in% top3
    lc <- if (is_t) brand_colour else .kd_muted_colour
    lo <- if (is_t) 0.9 else 0.3; lw <- if (is_t) 2.5 else 1.2
    yp <- tm + (d$ranks - 1) * rh + rh / 2

    s <- paste0(s, "\n", .kd_svg_text(lm - 12, yp[1], d$label, size = 11,
                                       fill = if (is_t) .kd_value_colour else .kd_muted_colour,
                                       weight = if (is_t) "500" else "400",
                                       anchor = "end", baseline = "central"))

    for (m in seq_len(n_m - 1))
      s <- paste0(s, "\n", .kd_svg_line(col_x[m], yp[m], col_x[m+1], yp[m+1],
                                         stroke = lc, width = lw, opacity = lo))
    for (m in seq_len(n_m)) {
      dr <- if (is_t) 5 else 3; dop <- if (is_t) 1.0 else 0.4
      s <- paste0(s, sprintf('\n<circle cx="%.1f" cy="%.1f" r="%d" fill="%s" opacity="%.2f"/>',
                             col_x[m], yp[m], dr, lc, dop))
      if (is_t)
        s <- paste0(s, "\n", .kd_svg_text(col_x[m], yp[m], as.character(as.integer(d$ranks[m])),
                                           size = 8, fill = "white", weight = "600",
                                           anchor = "middle", baseline = "central"))
    }
  }

  s <- paste0(s, "\n</svg>")
  htmltools::tags$div(class = "kd-chart-container", htmltools::HTML(s))
}


# ==============================================================================
# 3. CORRELATION HEATMAP
# ==============================================================================

#' Build Key Driver Correlation Heatmap (SVG)
#'
#' Diverging colour scale: negative=red (#ef4444), zero=white, positive=blue (#3b82f6).
#' Strong correlations |r| > 0.7 get white text.
#'
#' @param correlations Matrix or list of {driver1, driver2, correlation}
#' @param brand_colour Brand colour hex (unused; diverging scale is fixed)
#' @return htmltools::tags$div wrapping SVG, or NULL
#' @keywords internal
build_kd_correlation_heatmap <- function(correlations, brand_colour = "#323367") {

  if (is.null(correlations)) return(NULL)

  # Convert to matrix
  if (is.matrix(correlations)) {
    cor_mat <- correlations; var_names <- rownames(cor_mat)
    if (is.null(var_names)) return(NULL)
  } else if (is.list(correlations) && !is.data.frame(correlations)) {
    all_vars <- unique(c(
      vapply(correlations, function(e) as.character(e$driver1 %||% ""), character(1)),
      vapply(correlations, function(e) as.character(e$driver2 %||% ""), character(1))))
    all_vars <- all_vars[nzchar(all_vars)]
    if (length(all_vars) < 2) return(NULL)
    n <- length(all_vars)
    cor_mat <- matrix(NA_real_, n, n, dimnames = list(all_vars, all_vars))
    diag(cor_mat) <- 1.0
    for (e in correlations) {
      d1 <- as.character(e$driver1 %||% ""); d2 <- as.character(e$driver2 %||% "")
      v <- as.numeric(e$correlation %||% NA)
      if (nzchar(d1) && nzchar(d2) && d1 %in% all_vars && d2 %in% all_vars) {
        cor_mat[d1, d2] <- v; cor_mat[d2, d1] <- v
      }
    }
    var_names <- all_vars
  } else if (is.data.frame(correlations)) {
    nc <- vapply(correlations, is.numeric, logical(1))
    if (sum(nc) < 2) return(NULL)
    cor_mat <- as.matrix(correlations[, nc, drop = FALSE])
    var_names <- colnames(cor_mat)
    if (is.null(var_names) || nrow(cor_mat) != ncol(cor_mat)) return(NULL)
  } else {
    return(NULL)
  }

  n <- length(var_names)
  if (n < 2) return(NULL)

  # Truncate long labels for readability
  max_label <- 20
  display_names <- vapply(var_names, function(v) {
    if (nchar(v) > max_label) paste0(substr(v, 1, max_label - 1), "\u2026") else v
  }, character(1))

  cs <- 44; lm <- 140; rm <- 100
  cw <- lm + n * cs + 20; ch <- rm + n * cs + 20

  # Red (#ef4444=239,68,68) <-> white <-> blue (#3b82f6=59,130,246)
  cor2col <- function(r) {
    if (is.na(r)) return("#f8fafc")
    r <- max(-1, min(1, r)); int <- abs(r)
    if (r >= 0) sprintf("#%02x%02x%02x", as.integer(255 - int*(255-59)),
                        as.integer(255 - int*(255-130)), as.integer(255 - int*(255-246)))
    else sprintf("#%02x%02x%02x", as.integer(255 - int*(255-239)),
                 as.integer(255 - int*(255-68)), as.integer(255 - int*(255-68)))
  }

  s <- sprintf('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" class="kd-chart kd-correlation-heatmap" role="img" aria-label="Correlation heatmap" style="font-family:%s;">',
               cw, ch, .kd_font_family)

  # Rotated column headers
  for (j in seq_len(n)) {
    xc <- lm + (j - 1) * cs + cs / 2
    s <- paste0(s, sprintf('\n<text x="%.1f" y="%.1f" text-anchor="start" font-size="11" fill="%s" font-weight="500" transform="rotate(-45,%.1f,%.1f)">%s</text>',
                           xc, rm - 8, .kd_label_colour, xc, rm - 8, .kd_html_escape(display_names[j])))
  }

  # Row labels + cells
  for (i in seq_len(n)) {
    yt <- rm + (i - 1) * cs; yc <- yt + cs / 2
    s <- paste0(s, "\n", .kd_svg_text(lm - 10, yc, display_names[i], size = 11,
                                       fill = .kd_label_colour, anchor = "end", baseline = "central"))
    for (j in seq_len(n)) {
      xl <- lm + (j - 1) * cs; xc <- xl + cs / 2
      v <- cor_mat[i, j]; fill <- cor2col(v)
      s <- paste0(s, sprintf('\n<rect x="%.0f" y="%.0f" width="%d" height="%d" fill="%s" stroke="white" stroke-width="1"/>',
                             xl, yt, cs, cs, fill))
      if (!is.na(v)) {
        tf <- if (abs(v) > 0.7) "white" else .kd_value_colour
        s <- paste0(s, "\n", .kd_svg_text(xc, yc, sprintf("%.2f", v), size = 10,
                                           fill = tf, weight = "500", anchor = "middle", baseline = "central"))
      }
    }
  }

  s <- paste0(s, "\n</svg>")
  htmltools::tags$div(class = "kd-chart-container", htmltools::HTML(s))
}


# ==============================================================================
# 4. EFFECT SIZE CHART
# ==============================================================================

#' Build Key Driver Effect Size Chart (SVG)
#'
#' Horizontal bars with dashed benchmark lines (Small/Medium/Large).
#' Large=brand, Medium=accent, Small=#94a3b8, Negligible=#cbd5e1.
#'
#' @param effect_sizes data.frame or list with driver, effect_value, effect_size
#' @param brand_colour Brand colour hex
#' @param accent_colour Accent colour hex
#' @return htmltools::tags$div wrapping SVG, or NULL
#' @keywords internal
build_kd_effect_size_chart <- function(effect_sizes,
                                       brand_colour = "#323367",
                                       accent_colour = "#f59e0b") {

  if (is.null(effect_sizes)) return(NULL)

  # Normalise to list of {label, effect_value, category}
  if (is.data.frame(effect_sizes)) {
    if (nrow(effect_sizes) == 0) return(NULL)
    entries <- lapply(seq_len(nrow(effect_sizes)), function(i) {
      r <- effect_sizes[i, , drop = FALSE]
      list(label = as.character(r$driver %||% r$Driver %||% r$label %||% ""),
           effect_value = as.numeric(r$effect_value %||% r$Effect_Value %||% 0),
           category = as.character(r$effect_size %||% r$Effect_Size %||% r$category %||% ""))
    })
  } else if (is.list(effect_sizes)) {
    if (length(effect_sizes) == 0) return(NULL)
    entries <- lapply(effect_sizes, function(d) {
      list(label = as.character(d$label %||% d$driver %||% d$Driver %||% ""),
           effect_value = as.numeric(d$effect_value %||% d$Effect_Value %||% 0),
           category = as.character(d$effect_size %||% d$Effect_Size %||% d$category %||% ""))
    })
  } else { return(NULL) }

  n <- length(entries); if (n == 0) return(NULL)

  bar_h <- 28; gap <- 8; lbl_w <- 200; chart_w <- 700
  bar_area <- chart_w - lbl_w - 100; total_h <- n * (bar_h + gap) + 55

  max_v <- max(vapply(entries, function(d) abs(d$effect_value), numeric(1)), na.rm = TRUE)
  if (is.na(max_v) || max_v == 0) max_v <- 1
  sc <- max_v * 1.2

  cat_col <- function(cat) {
    cl <- tolower(cat %||% "")
    if (grepl("large", cl))  return(brand_colour)
    if (grepl("medium", cl)) return(accent_colour)
    if (grepl("small", cl))  return("#94a3b8")
    "#cbd5e1"
  }

  s <- sprintf('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="kd-chart kd-effect-size-chart" role="img" aria-label="Effect size chart" style="font-family:%s;">',
               chart_w, total_h, .kd_font_family)

  # Benchmarks (dashed vertical)
  for (bm in list(list(l="Small", v=0.02), list(l="Medium", v=0.15), list(l="Large", v=0.35))) {
    if (bm$v <= sc) {
      xp <- lbl_w + (bm$v / sc) * bar_area
      s <- paste0(s, "\n", .kd_svg_line(xp, 30, xp, total_h - 15, stroke = .kd_muted_colour,
                                         width = 1.5, dash = "5,3", opacity = 0.6))
      s <- paste0(s, "\n", .kd_svg_text(xp, 22, bm$l, size = 9, fill = .kd_muted_colour, anchor = "middle"))
    }
  }

  # Zero baseline
  s <- paste0(s, "\n", .kd_svg_line(lbl_w, 30, lbl_w, total_h - 15))

  # Bars
  for (i in seq_along(entries)) {
    d <- entries[[i]]; y <- 35 + (i-1) * (bar_h + gap)
    ev <- abs(d$effect_value); bw <- max(2, (ev / sc) * bar_area)
    bc <- cat_col(d$category)

    s <- paste0(s, sprintf('\n<g class="kd-effect-row" data-kd-driver="%s">', .kd_html_escape(d$label)))
    s <- paste0(s, "\n", .kd_svg_text(lbl_w - 8, y + bar_h/2, .kd_truncate_label(d$label), size = 12,
                                       fill = .kd_value_colour, anchor = "end", baseline = "central"))
    s <- paste0(s, "\n", .kd_svg_bar(lbl_w, y, bw, bar_h, bc, 0.85))
    vt <- if (nzchar(d$category)) sprintf("%.3f (%s)", ev, d$category) else sprintf("%.3f", ev)
    s <- paste0(s, "\n", .kd_svg_text(lbl_w + bw + 6, y + bar_h/2, vt, size = 10,
                                       fill = .kd_value_colour, weight = "500",
                                       anchor = "start", baseline = "central"))
    s <- paste0(s, "\n</g>")
  }

  s <- paste0(s, "\n</svg>")
  htmltools::tags$div(class = "kd-chart-container", htmltools::HTML(s))
}


# ==============================================================================
# 5. BOOTSTRAP CONFIDENCE INTERVAL CHART (Forest Plot)
# ==============================================================================

#' Build Key Driver Bootstrap CI Chart (SVG)
#'
#' Forest plot: point estimates with CI whiskers. Sorted descending by point estimate.
#'
#' @param bootstrap_ci data.frame or list with driver, point_estimate, ci_lower, ci_upper
#' @param brand_colour Brand colour hex
#' @param accent_colour Accent colour hex
#' @return htmltools::tags$div wrapping SVG, or NULL
#' @keywords internal
build_kd_bootstrap_ci_chart <- function(bootstrap_ci,
                                        brand_colour = "#323367",
                                        accent_colour = "#f59e0b") {

  if (is.null(bootstrap_ci)) return(NULL)

  # Normalise
  if (is.data.frame(bootstrap_ci)) {
    if (nrow(bootstrap_ci) == 0) return(NULL)
    entries <- lapply(seq_len(nrow(bootstrap_ci)), function(i) {
      r <- bootstrap_ci[i, , drop = FALSE]
      list(label  = as.character(r$driver %||% r$Driver %||% r$label %||% ""),
           method = as.character(r$method %||% r$Method %||% ""),
           pe = as.numeric(r$point_estimate %||% r$Point_Estimate %||% r$estimate %||% r$PE %||% 0),
           lo = as.numeric(r$ci_lower %||% r$CI_Lower %||% r$lower %||% r$LCI %||% 0),
           hi = as.numeric(r$ci_upper %||% r$CI_Upper %||% r$upper %||% r$UCI %||% 0))
    })
  } else if (is.list(bootstrap_ci)) {
    if (length(bootstrap_ci) == 0) return(NULL)
    entries <- lapply(bootstrap_ci, function(d) {
      list(label  = as.character(d$label %||% d$driver %||% d$Driver %||% ""),
           method = as.character(d$method %||% d$Method %||% ""),
           pe = as.numeric(d$point_estimate %||% d$Point_Estimate %||% d$estimate %||% 0),
           lo = as.numeric(d$ci_lower %||% d$CI_Lower %||% d$lower %||% 0),
           hi = as.numeric(d$ci_upper %||% d$CI_Upper %||% d$upper %||% 0))
    })
  } else { return(NULL) }

  # If multiple methods, keep only the first method (most common)
  methods <- vapply(entries, function(d) d$method, character(1))
  unique_methods <- unique(methods[methods != ""])
  if (length(unique_methods) > 1) {
    keep_method <- unique_methods[1]
    entries <- entries[methods == keep_method]
  }

  # Sort descending by point estimate
  entries <- entries[order(-vapply(entries, function(d) d$pe, numeric(1)))]
  n <- length(entries); if (n == 0) return(NULL)

  rh <- 28; gap <- 8; lbl_w <- 200; chart_w <- 700
  pa <- chart_w - lbl_w - 60; total_h <- n * (rh + gap) + 50

  all_lo <- vapply(entries, function(d) d$lo, numeric(1))
  all_hi <- vapply(entries, function(d) d$hi, numeric(1))
  ax_min <- min(0, min(all_lo, na.rm = TRUE) * 1.1)
  ax_max <- max(all_hi, na.rm = TRUE) * 1.15
  if (is.na(ax_max) || ax_max == 0) ax_max <- 1
  ax_rng <- ax_max - ax_min; if (ax_rng == 0) ax_rng <- 1

  to_x <- function(v) lbl_w + ((v - ax_min) / ax_rng) * pa

  s <- sprintf('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="kd-chart kd-bootstrap-ci-chart" role="img" aria-label="Bootstrap confidence interval forest plot" style="font-family:%s;">',
               chart_w, total_h, .kd_font_family)

  # Gridlines
  gs <- .kd_nice_step(ax_rng)
  for (g in seq(ceiling(ax_min/gs)*gs, floor(ax_max/gs)*gs, by = gs)) {
    gx <- to_x(g)
    s <- paste0(s, "\n", .kd_svg_line(gx, 25, gx, total_h - 10))
    s <- paste0(s, "\n", .kd_svg_text(gx, 18, format(g, digits = 2, nsmall = if (gs < 1) 1 else 0),
                                       size = 9, fill = .kd_muted_colour, anchor = "middle"))
  }

  # Zero reference line
  if (ax_min <= 0 && ax_max >= 0)
    s <- paste0(s, "\n", .kd_svg_line(to_x(0), 25, to_x(0), total_h - 10,
                                       stroke = .kd_muted_colour, width = 1.5, dash = "4,3"))

  # Whiskers + points
  for (i in seq_along(entries)) {
    d <- entries[[i]]; yc <- 30 + (i-1) * (rh + gap) + rh/2
    xp <- to_x(d$pe); xl <- to_x(d$lo); xh <- to_x(d$hi)

    s <- paste0(s, sprintf('\n<g class="kd-ci-row" data-kd-driver="%s">', .kd_html_escape(d$label)))
    s <- paste0(s, "\n", .kd_svg_text(lbl_w - 8, yc, .kd_truncate_label(d$label), size = 11,
                                       fill = .kd_value_colour, anchor = "end", baseline = "central"))
    # CI line
    s <- paste0(s, "\n", .kd_svg_line(xl, yc, xh, yc, stroke = brand_colour, width = 1.5, opacity = 0.6))
    # Caps
    s <- paste0(s, "\n", .kd_svg_line(xl, yc-5, xl, yc+5, stroke = brand_colour, width = 1.5, opacity = 0.6))
    s <- paste0(s, "\n", .kd_svg_line(xh, yc-5, xh, yc+5, stroke = brand_colour, width = 1.5, opacity = 0.6))
    # Point
    s <- paste0(s, "\n", .kd_svg_circle(xp, yc, 4, brand_colour))
    # Value label
    s <- paste0(s, "\n", .kd_svg_text(xp, yc - 10, sprintf("%.2f", d$pe), size = 9,
                                       fill = .kd_label_colour, weight = "500", anchor = "middle"))
    s <- paste0(s, "\n</g>")
  }

  s <- paste0(s, "\n</svg>")
  htmltools::tags$div(class = "kd-chart-container", htmltools::HTML(s))
}


# NOTE: build_kd_quadrant_chart() is defined in 06_quadrant_section.R
# (with label collision avoidance and proper IPA axis orientation).
# Do NOT define it here to avoid duplicate function definitions.


# ==============================================================================
# SHAP IMPORTANCE CHART
# ==============================================================================

#' Build SHAP Importance Horizontal Bar Chart
#'
#' @param shap_importance Data frame with driver and importance_pct columns
#' @param brand_colour Brand colour for bars
#' @return htmltools tag or NULL
#' @keywords internal
build_kd_shap_importance_chart <- function(shap_importance, brand_colour = "#323367") {

  if (is.null(shap_importance) || !is.data.frame(shap_importance)) return(NULL)
  if (nrow(shap_importance) == 0) return(NULL)

  # Standardise column names
  if (!"driver" %in% names(shap_importance) && "Driver" %in% names(shap_importance)) {
    shap_importance$driver <- shap_importance$Driver
  }
  pct_col <- intersect(c("importance_pct", "SHAP_Importance", "pct", "Importance"),
                        names(shap_importance))[1]
  if (is.na(pct_col)) return(NULL)
  shap_importance$pct_val <- as.numeric(shap_importance[[pct_col]])

  # Sort descending
  shap_importance <- shap_importance[order(-shap_importance$pct_val), ]

  n  <- nrow(shap_importance)
  bh <- 26; gap <- 8; rs <- bh + gap
  ml <- 160; mr <- 60; mt <- 20; mb <- 10
  cw <- 440
  tw <- ml + cw + mr
  th <- mt + n * rs + mb

  max_val <- max(shap_importance$pct_val, na.rm = TRUE)
  if (max_val <= 0) max_val <- 1

  s <- sprintf('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="100%%" style="max-width:%dpx;display:block;" role="img" aria-label="SHAP importance bar chart">', tw, th, tw)

  for (i in seq_len(n)) {
    row <- shap_importance[i, ]
    label <- .kd_truncate_label(as.character(row$driver))
    val   <- row$pct_val
    bw    <- max(2, (val / max_val) * cw)
    by    <- mt + (i - 1) * rs
    alpha <- 0.5 + 0.5 * (val / max_val)

    s <- paste0(s, "\n", .kd_svg_text(ml - 8, by + bh / 2 + 4, label,
                                       size = 11, fill = .kd_label_colour,
                                       weight = "500", anchor = "end"))
    s <- paste0(s, "\n", .kd_svg_bar(ml, by, bw, bh, brand_colour, alpha))
    s <- paste0(s, "\n", .kd_svg_text(ml + bw + 6, by + bh / 2 + 4,
                                       sprintf("%.0f%%", val),
                                       size = 11, fill = .kd_value_colour,
                                       weight = "600"))
  }

  s <- paste0(s, "\n</svg>")
  htmltools::tags$div(class = "kd-chart-container", htmltools::HTML(s))
}


# ==============================================================================
# SEGMENT COMPARISON CHART
# ==============================================================================

#' Build Segment Comparison Grouped Bar Chart
#'
#' @param segment_comparison Data frame with Driver and per-segment _Pct columns
#' @param brand_colour Brand colour
#' @param accent_colour Accent colour
#' @return htmltools tag or NULL
#' @keywords internal
build_kd_segment_comparison_chart <- function(segment_comparison,
                                              brand_colour = "#323367",
                                              accent_colour = "#CC9900") {

  if (is.null(segment_comparison) || length(segment_comparison) == 0) return(NULL)

  # Accept either a data.frame or a list with $comparison_matrix
  if (!is.data.frame(segment_comparison)) {
    if (is.list(segment_comparison) && !is.null(segment_comparison$comparison_matrix)) {
      segment_comparison <- segment_comparison$comparison_matrix
    } else {
      return(NULL)
    }
  }
  if (nrow(segment_comparison) == 0) return(NULL)

  # Extract segment names from _Pct columns
  pct_cols  <- grep("_Pct$", names(segment_comparison), value = TRUE)
  rank_cols <- grep("_Rank$", names(segment_comparison), value = TRUE)
  all_seg   <- sub("_Pct$", "", pct_cols)
  seg_names <- all_seg[paste0(all_seg, "_Rank") %in% rank_cols]
  if (length(seg_names) == 0) return(NULL)

  # Include Total (Mean_Pct) as a pseudo-segment
  has_total <- "Mean_Pct" %in% names(segment_comparison)
  all_names <- if (has_total) c("Total", seg_names) else seg_names
  nt <- length(all_names)
  drivers <- as.character(segment_comparison$Driver)
  nd <- length(drivers)

  # Colour palette for segments — Total gets a neutral charcoal
  seg_palette <- c("#4f86c6", "#e07b39", "#6ba368", "#c75b7a",
                    "#8e7cc3", "#d4a843", "#5ca4a9", "#d4587a")
  total_col <- "#64748b"
  seg_cols <- if (has_total) {
    c(total_col, rep_len(seg_palette, length(seg_names)))
  } else {
    rep_len(seg_palette, length(seg_names))
  }

  sb <- 18; sg <- 2
  group_h <- nt * sb + (nt - 1) * sg
  group_gap <- 14
  ml <- 160; mr <- 60; mt <- 30; mb <- 10
  cw <- 400
  tw <- ml + cw + mr
  th <- mt + nd * (group_h + group_gap) + mb

  # Find max value for scaling
  max_val <- 0
  for (seg in seg_names) {
    col_name <- paste0(seg, "_Pct")
    if (col_name %in% names(segment_comparison)) {
      v <- as.numeric(segment_comparison[[col_name]])
      max_val <- max(max_val, v, na.rm = TRUE)
    }
  }
  if (has_total) {
    v <- as.numeric(segment_comparison$Mean_Pct)
    max_val <- max(max_val, v, na.rm = TRUE)
  }
  if (max_val <= 0) max_val <- 1

  s <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" class="kd-segment-chart" viewBox="0 0 %d %d" width="100%%" style="max-width:%dpx;display:block;" role="img" aria-label="Segment comparison grouped bar chart">',
    tw, th, tw)

  # Legend row
  lx <- ml
  for (si in seq_len(nt)) {
    s <- paste0(s, sprintf('\n<rect x="%.0f" y="6" width="12" height="12" rx="2" fill="%s" data-kd-seg-legend="%s"/>',
                           lx, seg_cols[si], all_names[si]))
    s <- paste0(s, "\n", .kd_svg_text(lx + 16, 16, all_names[si],
                                       size = 10, fill = .kd_label_colour,
                                       weight = "500"))
    lx <- lx + nchar(all_names[si]) * 7 + 32
  }

  for (di in seq_len(nd)) {
    gy <- mt + (di - 1) * (group_h + group_gap)
    # Driver group
    s <- paste0(s, sprintf('\n<g class="kd-seg-driver-group" data-kd-driver="%s">',
                           htmltools::htmlEscape(drivers[di])))
    # Driver label
    s <- paste0(s, "\n", .kd_svg_text(ml - 8, gy + group_h / 2 + 4,
                                       .kd_truncate_label(drivers[di]), size = 11,
                                       fill = .kd_label_colour,
                                       weight = "500", anchor = "end"))
    # Separator line
    if (di > 1) {
      sep_y <- gy - group_gap / 2
      s <- paste0(s, sprintf('\n<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" stroke="%s" stroke-width="0.5"/>',
                             ml, sep_y, ml + cw, sep_y, .kd_grid_colour))
    }

    for (si in seq_len(nt)) {
      seg_name <- all_names[si]
      col_name <- if (seg_name == "Total") "Mean_Pct" else paste0(seg_name, "_Pct")
      val <- if (col_name %in% names(segment_comparison)) {
        as.numeric(segment_comparison[[col_name]][di])
      } else 0
      if (is.na(val)) val <- 0

      by <- gy + (si - 1) * (sb + sg)
      bw <- max(2, (val / max_val) * cw)

      s <- paste0(s, sprintf('\n<g class="kd-seg-bar" data-kd-segment="%s">', seg_name))
      s <- paste0(s, "\n", .kd_svg_bar(ml, by, bw, sb, seg_cols[si], 0.85))
      s <- paste0(s, "\n", .kd_svg_text(ml + bw + 5, by + sb / 2 + 4,
                                         sprintf("%.0f%%", val),
                                         size = 9, fill = .kd_value_colour,
                                         weight = "500"))
      s <- paste0(s, "\n</g>")
    }
    s <- paste0(s, "\n</g>")
  }

  s <- paste0(s, "\n</svg>")
  htmltools::tags$div(class = "kd-chart-container", htmltools::HTML(s))
}
