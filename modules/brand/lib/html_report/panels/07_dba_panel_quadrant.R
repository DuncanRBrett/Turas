# ==============================================================================
# BRAND MODULE - DBA PANEL: QUADRANT VIEW SUB-TAB
# ==============================================================================
# Renders the Romaniuk Fame x Uniqueness 2x2 scatter as inline SVG.
# Quadrants are labelled with their Romaniuk action verb. Threshold lines
# come from the engine's configurable thresholds (default 50/50). Each
# asset shows as a focal-colour dot with its asset code label above.
#
# Accessibility: the SVG includes role + aria-label + a screen-reader
# fallback list of the same data. Asset shape is conveyed by quadrant
# position, NOT colour alone (asset_code label sits above each dot).
#
# VERSION: 1.0
# ==============================================================================

BRAND_DBA_PANEL_QUADRANT_VERSION <- "1.0"

# Drawing constants — kept here, not in the renderer body, so they are
# easy to find and tweak.
.DBA_Q_W       <- 640L      # SVG view width (px in the viewBox)
.DBA_Q_H       <- 460L      # SVG view height
.DBA_Q_PAD_L   <- 56L       # left padding for y-axis labels
.DBA_Q_PAD_R   <- 24L       # right padding
.DBA_Q_PAD_T   <- 28L       # top padding
.DBA_Q_PAD_B   <- 56L       # bottom padding for x-axis labels


#' Build the DBA quadrant-view sub-tab HTML
#'
#' @param panel_data List from \code{build_dba_panel_data()} (PASS state).
#' @param focal_colour Character. Hex colour for asset dots.
#'
#' @return Character. HTML fragment containing the SVG scatter and a
#'   short descriptive note. Returns a friendly empty-state when the
#'   panel data has no assets (engine should have used placeholder mode
#'   in that case, but this is a defensive fallback).
#'
#' @export
build_dba_quadrant_html <- function(panel_data, focal_colour) {
  assets <- panel_data$assets %||% list()
  if (length(assets) == 0L) {
    return('<div class="dba-quadrant-empty"><p>No DBA assets to display.</p></div>')
  }

  fame_threshold <- 100 * (panel_data$meta$fame_threshold %||%
                            DBA_DEFAULT_FAME_THRESHOLD)
  unique_threshold <- 100 * (panel_data$meta$uniqueness_threshold %||%
                              DBA_DEFAULT_UNIQUENESS_THRESHOLD)

  svg <- .dba_quadrant_svg(assets, fame_threshold, unique_threshold,
                             focal_colour)
  legend <- .dba_quadrant_legend()
  fallback <- .dba_quadrant_a11y_table(assets)

  paste0(
    '<div class="dba-quadrant-wrap">',
    sprintf('<div class="dba-quadrant-chart" role="img" aria-label="DBA Fame by Uniqueness scatter — %d assets">',
            length(assets)),
    svg,
    '</div>',
    legend,
    fallback,
    '</div>'
  )
}


# ==============================================================================
# Internal: build the SVG document body
# ==============================================================================

.dba_quadrant_svg <- function(assets, fame_threshold, unique_threshold,
                                focal_colour) {

  plot_x0 <- .DBA_Q_PAD_L
  plot_y0 <- .DBA_Q_H - .DBA_Q_PAD_B
  plot_w  <- .DBA_Q_W - .DBA_Q_PAD_L - .DBA_Q_PAD_R
  plot_h  <- .DBA_Q_H - .DBA_Q_PAD_T - .DBA_Q_PAD_B

  # Map data % (0-100) to SVG coords. X = uniqueness, Y = fame.
  # Y axis is inverted: 0% at bottom, 100% at top.
  to_x <- function(pct) plot_x0 + plot_w * (pct / 100)
  to_y <- function(pct) plot_y0 - plot_h * (pct / 100)

  parts <- character(0)

  # Background frame
  parts <- c(parts, sprintf(
    '<rect x="%d" y="%d" width="%d" height="%d" fill="#fbfaf6" stroke="#d9d4c5" stroke-width="1"/>',
    plot_x0, .DBA_Q_PAD_T, plot_w, plot_h))

  # Quadrant labels (positioned in each corner, aligned to that corner)
  parts <- c(parts, .dba_quadrant_corner_labels(plot_x0, plot_y0,
                                                  plot_w, plot_h,
                                                  fame_threshold,
                                                  unique_threshold,
                                                  to_x, to_y))

  # Threshold lines (drawn ABOVE quadrant labels)
  parts <- c(parts, sprintf(
    '<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#9c9587" stroke-width="1" stroke-dasharray="4 4"/>',
    plot_x0, round(to_y(fame_threshold)),
    plot_x0 + plot_w, round(to_y(fame_threshold))))
  parts <- c(parts, sprintf(
    '<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#9c9587" stroke-width="1" stroke-dasharray="4 4"/>',
    round(to_x(unique_threshold)), .DBA_Q_PAD_T,
    round(to_x(unique_threshold)), plot_y0))

  # Axes
  parts <- c(parts, .dba_quadrant_axes(plot_x0, plot_y0, plot_w, plot_h))

  # Asset dots
  for (a in assets) {
    if (is.na(a$fame_pct) || is.na(a$unique_pct)) next
    cx <- round(to_x(a$unique_pct))
    cy <- round(to_y(a$fame_pct))
    parts <- c(parts, sprintf(
      '<g class="dba-dot-group" data-asset-code="%s"><circle cx="%d" cy="%d" r="7" fill="%s" stroke="#1f2933" stroke-width="1.2"/><text x="%d" y="%d" text-anchor="middle" font-size="11" fill="#1f2933" font-weight="600">%s</text></g>',
      .dba_esc(a$asset_code), cx, cy, .dba_esc(focal_colour),
      cx, cy - 14L, .dba_esc(a$asset_code)))
  }

  sprintf(
    '<svg viewBox="0 0 %d %d" preserveAspectRatio="xMidYMid meet" xmlns="http://www.w3.org/2000/svg" class="dba-quadrant-svg">%s</svg>',
    .DBA_Q_W, .DBA_Q_H, paste(parts, collapse = ""))
}


# ==============================================================================
# Internal: quadrant corner labels (Romaniuk's framework verbs)
# ==============================================================================

.dba_quadrant_corner_labels <- function(plot_x0, plot_y0, plot_w, plot_h,
                                          fame_threshold, unique_threshold,
                                          to_x, to_y) {
  # Pad inside each quadrant a bit
  pad <- 8L
  ul_x <- plot_x0 + pad
  ul_y <- .DBA_Q_PAD_T + 16L
  ur_x <- plot_x0 + plot_w - pad
  ur_y <- ul_y
  ll_x <- ul_x
  ll_y <- plot_y0 - pad
  lr_x <- ur_x
  lr_y <- ll_y

  paste0(
    sprintf('<text x="%d" y="%d" text-anchor="start" font-size="11" font-weight="600" fill="#7d756a" letter-spacing="0.4">AVOID ALONE</text>',
             ul_x, ul_y),
    sprintf('<text x="%d" y="%d" text-anchor="end" font-size="11" font-weight="600" fill="#7d756a" letter-spacing="0.4">USE OR LOSE</text>',
             ur_x, ur_y),
    sprintf('<text x="%d" y="%d" text-anchor="start" font-size="11" font-weight="600" fill="#7d756a" letter-spacing="0.4">IGNORE OR TEST</text>',
             ll_x, ll_y),
    sprintf('<text x="%d" y="%d" text-anchor="end" font-size="11" font-weight="600" fill="#7d756a" letter-spacing="0.4">INVEST TO BUILD</text>',
             lr_x, lr_y)
  )
}


# ==============================================================================
# Internal: axes + tick labels
# ==============================================================================

.dba_quadrant_axes <- function(plot_x0, plot_y0, plot_w, plot_h) {
  plot_x1 <- plot_x0 + plot_w
  plot_y1 <- .DBA_Q_PAD_T

  # X-axis (Uniqueness)
  parts <- character(0)
  parts <- c(parts, sprintf(
    '<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#1f2933" stroke-width="1.5"/>',
    plot_x0, plot_y0, plot_x1, plot_y0))
  for (p in c(0, 25, 50, 75, 100)) {
    x <- plot_x0 + plot_w * (p / 100)
    parts <- c(parts, sprintf(
      '<line x1="%.0f" y1="%d" x2="%.0f" y2="%d" stroke="#1f2933" stroke-width="1"/>',
      x, plot_y0, x, plot_y0 + 4))
    parts <- c(parts, sprintf(
      '<text x="%.0f" y="%d" text-anchor="middle" font-size="10" fill="#1f2933">%d</text>',
      x, plot_y0 + 18, p))
  }
  parts <- c(parts, sprintf(
    '<text x="%d" y="%d" text-anchor="middle" font-size="12" font-weight="600" fill="#1f2933">Uniqueness %%</text>',
    round(plot_x0 + plot_w / 2), plot_y0 + 38))

  # Y-axis (Fame)
  parts <- c(parts, sprintf(
    '<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#1f2933" stroke-width="1.5"/>',
    plot_x0, plot_y0, plot_x0, plot_y1))
  for (p in c(0, 25, 50, 75, 100)) {
    y <- plot_y0 - plot_h * (p / 100)
    parts <- c(parts, sprintf(
      '<line x1="%d" y1="%.0f" x2="%d" y2="%.0f" stroke="#1f2933" stroke-width="1"/>',
      plot_x0 - 4, y, plot_x0, y))
    parts <- c(parts, sprintf(
      '<text x="%d" y="%.0f" text-anchor="end" font-size="10" fill="#1f2933" dominant-baseline="middle">%d</text>',
      plot_x0 - 8, y, p))
  }
  parts <- c(parts, sprintf(
    '<text transform="translate(%d,%d) rotate(-90)" text-anchor="middle" font-size="12" font-weight="600" fill="#1f2933">Fame %%</text>',
    plot_x0 - 38, round(plot_y1 + plot_h / 2)))

  paste(parts, collapse = "")
}


# ==============================================================================
# Internal: legend (text — what each axis means)
# ==============================================================================

.dba_quadrant_legend <- function() {
'<dl class="dba-quadrant-legend">
  <div><dt>Fame</dt><dd>% of respondents who recognised the asset.</dd></div>
  <div><dt>Uniqueness</dt><dd>% of recognisers who correctly attributed it to the focal brand.</dd></div>
</dl>'
}


# ==============================================================================
# Internal: screen-reader-accessible data table
# ==============================================================================

.dba_quadrant_a11y_table <- function(assets) {
  rows <- paste(vapply(assets, function(a) {
    sprintf('<tr><td>%s</td><td>%.0f%%</td><td>%.0f%%</td><td>%s</td></tr>',
             .dba_esc(a$asset_label %||% a$asset_code),
             a$fame_pct, a$unique_pct,
             .dba_esc(a$quadrant))
  }, character(1)), collapse = "")
  sprintf(
'<table class="dba-quadrant-sr-only">
  <caption>DBA assets with Fame, Uniqueness, and assigned quadrant.</caption>
  <thead><tr><th>Asset</th><th>Fame</th><th>Uniqueness</th><th>Quadrant</th></tr></thead>
  <tbody>%s</tbody>
</table>',
    rows)
}


if (!exists(".dba_esc")) {
  .dba_esc <- function(x) {
    if (is.null(x)) return("")
    x <- as.character(x)
    x <- gsub("&", "&amp;",  x, fixed = TRUE)
    x <- gsub("<", "&lt;",   x, fixed = TRUE)
    x <- gsub(">", "&gt;",   x, fixed = TRUE)
    x <- gsub('"', "&quot;", x, fixed = TRUE)
    x
  }
}

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand DBA quadrant view loaded (v%s)",
                  BRAND_DBA_PANEL_QUADRANT_VERSION))
}
