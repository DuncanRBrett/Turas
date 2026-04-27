# ==============================================================================
# BRAND MODULE - DEMOGRAPHICS PANEL: PER-QUESTION SVG CHART
# ==============================================================================
# Pure HTML / SVG builder for the chart view of a single demographic question.
# Layout: one row per option, with a horizontal bar showing the focal brand %
# and a vertical marker showing the cat-avg %. Per-brand cells are NOT shown
# in the chart view to keep it readable — the matrix table is the place to
# see all brands at once. The chart is for the focal brand vs reference.
#
# Design choices:
#   - SVG-free: pure HTML/CSS bars (gradient div + marker line), no inline SVG
#     so the markup is a fraction of the size and renders identically when
#     pinned (TurasPin clones the DOM, no SVG sandboxing required).
#   - Bar widths normalised to the largest pct value in the row (focal or
#     cat-avg), so a 50% option doesn't get drowned out by a 90% option.
#   - Focal value is the bar fill, cat-avg is a vertical reference marker.
#
# VERSION: 1.0
# ==============================================================================

BRAND_DEMOGRAPHICS_PANEL_CHART_VERSION <- "1.0"

# Minimum bar fill width so 0% bars are still visibly present (otherwise the
# row looks like the chart didn't render). 2% of the available width.
.DEMO_CHART_MIN_BAR_WIDTH_PCT <- 2


# ==============================================================================
# PUBLIC API
# ==============================================================================

#' Build the per-question chart view (focal vs cat-avg horizontal bars)
#'
#' @param question_payload List. One entry from \code{panel_data$questions}.
#' @param focal_brand Character. Brand code whose value is the bar fill.
#' @param brand_colours Named list. brand_code -> hex colour.
#' @param panel_data List. Full panel data (used for focal colour fallback).
#' @param decimal_places Integer. Display precision for percentages.
#' @return Character. HTML fragment for the chart view.
#' @export
build_demographics_matrix_chart <- function(question_payload, focal_brand,
                                             brand_colours, panel_data,
                                             decimal_places = 0L) {
  q     <- question_payload
  rows  <- q$total$rows %||% list()
  if (length(rows) == 0L) {
    return('<div class="demo-empty">No responses for this question.</div>')
  }

  focal_colour <- brand_colours[[focal_brand]] %||%
                   panel_data$meta$focal_colour %||% "#1A5276"

  focal_entry <- .demo_chart_focal_entry(q$brand_cut, focal_brand)
  scale_max   <- .demo_chart_scale_max(rows, focal_entry)

  bars <- vapply(rows, function(r) {
    .demo_chart_row(r, focal_entry, scale_max, focal_colour, decimal_places)
  }, character(1L))

  legend <- sprintf(
    '<div class="demo-chart-legend">
       <span><span class="demo-chart-legend-swatch" style="background:%s"></span>%s</span>
       <span>Marker: cat avg</span>
     </div>',
    .demo_chart_esc(focal_colour),
    .demo_chart_esc(focal_brand %||% "focal"))

  paste0(
    '<div class="demo-chart-wrap">',
    paste(bars, collapse = ""),
    legend,
    '</div>')
}


# ==============================================================================
# INTERNAL: ROW BUILDERS
# ==============================================================================

# Pull the focal-brand brand_cut entry from the question payload. Returns
# NULL when the focal brand has no per-brand cells (e.g. focal not in the
# category brand list — which would be a config error upstream).
.demo_chart_focal_entry <- function(brand_cut, focal_brand) {
  if (is.null(brand_cut) || length(brand_cut) == 0L) return(NULL)
  for (b in brand_cut) {
    if (identical(b$brand_code, focal_brand)) return(b)
  }
  NULL
}


# Normalise bar widths against the largest value visible on the chart.
# Considers the cat-avg (rows) AND the focal cell so neither overflows.
.demo_chart_scale_max <- function(rows, focal_entry) {
  cat_max <- max(vapply(rows, function(r) r$pct %||% 0, numeric(1L)),
                  na.rm = TRUE)
  focal_max <- if (is.null(focal_entry)) 0 else
    max(vapply(focal_entry$cells, function(c) c$pct %||% 0,
                numeric(1L)), na.rm = TRUE)
  m <- max(c(cat_max, focal_max), na.rm = TRUE)
  if (!is.finite(m) || m <= 0) 100 else m
}


.demo_chart_row <- function(r, focal_entry, scale_max, focal_colour, dp) {
  cat_pct   <- r$pct %||% NA_real_
  focal_pct <- .demo_chart_focal_pct(focal_entry, r$code)

  bar_w <- if (is.finite(focal_pct))
    max(.DEMO_CHART_MIN_BAR_WIDTH_PCT, 100 * focal_pct / scale_max)
  else 0
  marker_l <- if (is.finite(cat_pct))
    100 * cat_pct / scale_max
  else NA_real_
  marker_html <- if (!is.na(marker_l))
    sprintf('<div class="demo-chart-bar-marker" style="left:%.1f%%;" title="Cat avg %s"></div>',
            marker_l, .demo_chart_pct(cat_pct, dp))
  else ""

  sprintf(
    '<div class="demo-chart-row">
       <div class="demo-chart-row-label">%s</div>
       <div class="demo-chart-bar">
         <div class="demo-chart-bar-fill" style="width:%.1f%%;background:%s"></div>
         %s
       </div>
       <div class="demo-chart-row-value">%s</div>
     </div>',
    .demo_chart_esc(r$label %||% r$code),
    bar_w, .demo_chart_esc(focal_colour),
    marker_html,
    .demo_chart_pct(focal_pct, dp))
}


.demo_chart_focal_pct <- function(focal_entry, code) {
  if (is.null(focal_entry)) return(NA_real_)
  for (c in focal_entry$cells) if (identical(c$code, code)) return(c$pct)
  NA_real_
}


# ==============================================================================
# INTERNAL: FORMAT HELPERS
# ==============================================================================

.demo_chart_pct <- function(v, dp) {
  if (is.null(v) || is.na(v) || !is.finite(v)) return("&mdash;")
  sprintf("%.*f%%", as.integer(dp), v)
}


.demo_chart_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
