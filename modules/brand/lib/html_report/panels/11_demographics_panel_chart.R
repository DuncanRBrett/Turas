# ==============================================================================
# BRAND MODULE - DEMOGRAPHICS PANEL: PER-QUESTION SVG CHART
# ==============================================================================
# Pure HTML / SVG builder for the chart view of a single demographic question.
# Layout: one row per option, with a horizontal bar showing the focal brand
# value and a vertical marker showing a reference baseline. Per-brand cells
# are NOT shown in the chart view to keep it readable — the matrix table is
# the place to see all brands at once. The chart is for the focal brand vs
# its reference baseline.
#
# Two modes (mirror the matrix table's cell-metric toggle):
#   "penetration" (default) — bar = % of THIS option who buy focal; marker
#                              = focal's cat-wide penetration. Reading: bar
#                              longer than marker = focal over-performs in
#                              this demographic.
#   "share"                 — bar = % of focal buyers in THIS option (audience
#                              share); marker = % of cat respondents in this
#                              option (cat avg). Reading: bar longer than
#                              marker = focal's audience over-represented in
#                              this demographic vs the population.
#
# Design choices:
#   - SVG-free: pure HTML/CSS bars (gradient div + marker line), no inline SVG
#     so the markup is a fraction of the size and renders identically when
#     pinned (TurasPin clones the DOM, no SVG sandboxing required).
#   - Bar widths normalised to the largest pct value in the row (focal or
#     marker), so a 50% option doesn't get drowned out by a 90% option.
#   - Focal value is the bar fill, marker is a vertical reference line.
#
# VERSION: 2.0
# ==============================================================================

BRAND_DEMOGRAPHICS_PANEL_CHART_VERSION <- "2.0"

# Minimum bar fill width so 0% bars are still visibly present (otherwise the
# row looks like the chart didn't render). 2% of the available width.
.DEMO_CHART_MIN_BAR_WIDTH_PCT <- 2


# ==============================================================================
# PUBLIC API
# ==============================================================================

#' Build the per-question chart view (focal vs reference baseline)
#'
#' @param question_payload List. One entry from \code{panel_data$questions}.
#' @param focal_brand Character. Brand code whose value is the bar fill.
#' @param brand_colours Named list. brand_code -> hex colour.
#' @param panel_data List. Full panel data (used for focal colour fallback).
#' @param decimal_places Integer. Display precision for percentages.
#' @param metric Character. \code{"penetration"} (default) or \code{"share"}.
#'   Controls which engine output drives the bar values and what the marker
#'   represents. See file header.
#' @return Character. HTML fragment for the chart view.
#' @export
build_demographics_matrix_chart <- function(question_payload, focal_brand,
                                             brand_colours, panel_data,
                                             decimal_places = 0L,
                                             metric = "penetration") {
  q     <- question_payload
  rows  <- q$total$rows %||% list()
  if (length(rows) == 0L) {
    return('<div class="demo-empty">No responses for this question.</div>')
  }

  focal_colour <- brand_colours[[focal_brand]] %||%
                   panel_data$meta$focal_colour %||% "#1A5276"

  ctx <- .demo_chart_mode_ctx(q, focal_brand, metric)
  scale_max <- .demo_chart_scale_max(rows, ctx)

  # One row per option — buyer view only. The non-buyer cell value in pen
  # mode is the complement (100 − buyer) and tells you nothing the buyer
  # row doesn't already, while visually crushing the buyer bars. Detail
  # buyer-vs-non-buyer is in the table.
  bars <- vapply(rows, function(r) {
    .demo_chart_row(r, ctx, scale_max, focal_colour, decimal_places)
  }, character(1L))

  legend <- .demo_chart_legend(ctx, focal_brand, focal_colour)

  paste0(
    '<div class="demo-chart-wrap">',
    paste(bars, collapse = ""),
    legend,
    '</div>')
}


# Legend: focal swatch + primary-marker label + optional secondary-marker
# label (penetration mode only — focal brand's cat-wide overall pen).
.demo_chart_legend <- function(ctx, focal_brand, focal_colour) {
  primary_marker_html <- sprintf(
    '<span><span class="demo-chart-legend-swatch-line"></span>%s</span>',
    .demo_chart_esc(ctx$marker_label))

  secondary_marker_html <- if (identical(ctx$mode, "penetration") &&
                                is.finite(ctx$overall_pen)) {
    sprintf(
      '<span><span class="demo-chart-legend-swatch-line-dashed"></span>%s</span>',
      .demo_chart_esc(ctx$overall_marker_label))
  } else ""

  sprintf(
    '<div class="demo-chart-legend">
       <span><span class="demo-chart-legend-swatch" style="background:%s"></span>%s</span>
       %s
       %s
     </div>',
    .demo_chart_esc(focal_colour),
    .demo_chart_esc(focal_brand %||% "focal"),
    primary_marker_html,
    secondary_marker_html)
}


# Resolve the chart's data source and marker semantics for the requested
# metric mode. Returns a list with:
#   focal_entry   — long-list entry whose cells hold the bar values
#   option_avg    — code -> {code, pct} map for the per-row marker (the
#                    PER-OPTION baseline — typical brand pen in pen mode,
#                    demographic size in share mode). Replaces the previous
#                    global_marker idea so the marker can vary per row.
#   marker_label  — short legend label
#   footnote      — optional context string (used for "focal overall: 16%")
.demo_chart_mode_ctx <- function(q, focal_brand, metric) {
  if (identical(metric, "share")) {
    # Share-mode marker = per-row cat-avg (% of cat in option). Non-buyer
    # row reads its bar value from brand_nonbuyer_cut (a separate share-of-
    # audience distribution for the focal's non-buyers).
    return(list(
      mode             = "share",
      focal_entry      = .demo_chart_focal_entry(q$brand_cut, focal_brand),
      nonbuyer_entry   = .demo_chart_focal_entry(q$brand_nonbuyer_cut,
                                                  focal_brand),
      option_avg       = NULL,   # share mode reads r$pct directly per row
      marker_label     = "cat avg",
      overall_pen      = NA_real_,
      overall_marker_label = "",
      footnote         = ""
    ))
  }
  # default: penetration. Two markers per row:
  #   primary (per-row)  = mean brand pen in that option (the typical brand)
  #   secondary (global) = focal's cat-wide overall pen — same X every row,
  #                         rendered as a dashed lighter line so the two are
  #                         visually distinct.
  total_pen_focal <- q$brand_total_penetration[[focal_brand]]
  overall_pen <- if (is.null(total_pen_focal)) NA_real_
                 else as.numeric(total_pen_focal$pct)
  list(
    mode                = "penetration",
    focal_entry         = .demo_chart_focal_entry(q$brand_penetration_long,
                                                   focal_brand),
    nonbuyer_entry      = NULL,  # pen mode derives non-buyer as 100 - buyer
    option_avg          = q$option_avg_penetration %||% list(),
    marker_label        = "avg brand pen in option",
    overall_pen         = overall_pen,
    overall_marker_label = if (is.finite(overall_pen))
                             sprintf("%s overall pen (%.1f%%)",
                                     focal_brand %||% "focal", overall_pen)
                           else "",
    footnote            = ""
  )
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


# Normalise bar widths against the largest value VISIBLE on the chart for
# the active mode. Critical: we don't include values that aren't drawn,
# otherwise bars get visually squashed by an invisible reference. Pen mode
# draws focal bars + per-row primary marker + global overall-pen marker;
# share mode draws focal bars + per-row primary marker (r$pct).
.demo_chart_scale_max <- function(rows, ctx) {
  vals <- numeric(0)
  if (!is.null(ctx$focal_entry)) {
    vals <- c(vals, vapply(ctx$focal_entry$cells,
                            function(c) c$pct %||% 0, numeric(1L)))
  }
  vals <- c(vals, vapply(rows, function(r) {
    .demo_chart_marker_pct(ctx, r) %||% 0
  }, numeric(1L)))
  if (identical(ctx$mode, "penetration") && is.finite(ctx$overall_pen)) {
    vals <- c(vals, ctx$overall_pen)
  }
  m <- if (length(vals)) max(vals, na.rm = TRUE) else 0
  if (!is.finite(m) || m <= 0) 100 else m
}


# Per-row marker value lookup. Pen mode = ctx$option_avg[code]$pct; share
# mode = r$pct (the row's overall cat-avg). NA when the option isn't in
# the map.
.demo_chart_marker_pct <- function(ctx, r) {
  if (identical(ctx$mode, "share")) return(r$pct %||% NA_real_)
  oa <- ctx$option_avg %||% list()
  entry <- oa[[as.character(r$code %||% "")]]
  if (is.null(entry)) return(NA_real_)
  as.numeric(entry$pct %||% NA_real_)
}


# Render one chart row for an option. Layout: option name + role chip on
# the left (role is always "buyer" — the chart is a buyer-only view);
# horizontal bar with primary + optional secondary markers; numeric bar
# value on the right. The primary marker carries a visible value label
# above it so the baseline value is legible without hovering.
.demo_chart_row <- function(r, ctx, scale_max, focal_colour, dp) {
  focal_pct  <- .demo_chart_focal_pct(ctx$focal_entry, r$code)
  marker_pct <- .demo_chart_marker_pct(ctx, r)

  bar_w <- if (is.finite(focal_pct))
    max(.DEMO_CHART_MIN_BAR_WIDTH_PCT, 100 * focal_pct / scale_max)
  else 0

  marker_html <- ""
  marker_value_html <- ""
  if (is.finite(marker_pct)) {
    marker_l <- 100 * marker_pct / scale_max
    marker_html <- sprintf(
      '<div class="demo-chart-bar-marker" style="left:%.1f%%;" title="%s %s"></div>',
      marker_l,
      .demo_chart_esc(ctx$marker_label),
      .demo_chart_pct(marker_pct, dp))
    marker_value_html <- sprintf(
      '<div class="demo-chart-bar-marker-value" style="left:%.1f%%;">%s</div>',
      marker_l, .demo_chart_pct(marker_pct, dp))
  }

  overall_marker_html <- ""
  if (identical(ctx$mode, "penetration") && is.finite(ctx$overall_pen)) {
    overall_l <- 100 * ctx$overall_pen / scale_max
    overall_marker_html <- sprintf(
      '<div class="demo-chart-bar-marker-overall" style="left:%.1f%%;" title="%s"></div>',
      overall_l, .demo_chart_esc(ctx$overall_marker_label))
  }

  sprintf(
    '<div class="demo-chart-row">
       <div class="demo-chart-row-label">
         <span class="demo-chart-opt-name">%s</span><span class="demo-chart-role">buyer</span>
       </div>
       <div class="demo-chart-bar">
         %s
         <div class="demo-chart-bar-fill" style="width:%.1f%%;background:%s"></div>
         %s%s
       </div>
       <div class="demo-chart-row-value">%s</div>
     </div>',
    .demo_chart_esc(r$label %||% r$code),
    marker_value_html,
    bar_w, .demo_chart_esc(focal_colour),
    marker_html, overall_marker_html,
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
