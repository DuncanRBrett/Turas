# ==============================================================================
# BRAND MODULE - BRAND SELECTOR WIDGET (R-side HTML helpers)
# Builds the trigger button HTML and the static colour-legend strip used by
# every brand panel that has migrated from chip-strip to dropdown selection.
# Pairs with brand_selector_dropdown.js (window.BrandSelector) and
# 00_brand_selector_styling.R (CSS bundle).
# ==============================================================================


#' Build the trigger button HTML for a brand-selector dropdown
#'
#' The button renders as: \code{[icon] Filter brands (n/N) ▾}. Total brand
#' count comes from \code{length(brands)}; the visible count is rendered by
#' JS at runtime from the initial-hidden set.
#'
#' @param panel_id Character. Unique id used by JS to find this trigger
#'   (e.g. \code{"demographics"}, \code{"funnel-awareness"}).
#' @param n_total Integer. Total number of brands; the visible-count badge
#'   will start at \code{n_total} (i.e. all brands shown) unless JS later
#'   updates it.
#' @param label Character. Optional text override for the trigger label.
#'   Default \code{"Filter brands"}.
#' @return Character. A single HTML string (no surrounding container).
#' @export
build_brand_selector_trigger <- function(panel_id,
                                         n_total,
                                         label = "Filter brands") {
  if (!is.character(panel_id) || length(panel_id) != 1L ||
      is.na(panel_id) || !nzchar(panel_id)) {
    stop("build_brand_selector_trigger: panel_id must be a non-empty string")
  }
  if (!is.numeric(n_total) || length(n_total) != 1L ||
      is.na(n_total) || n_total < 0) {
    stop("build_brand_selector_trigger: n_total must be a non-negative number")
  }
  sprintf(
    paste0(
      '<button type="button" class="bs-trigger" ',
      'data-bs-panel="%s" aria-haspopup="true" aria-expanded="false">',
      '<span class="bs-trigger-icon" aria-hidden="true">&#x25A4;</span>',
      '<span class="bs-trigger-text">%s</span>',
      '<span class="bs-trigger-count">(%d/%d)</span>',
      '<span class="bs-trigger-caret" aria-hidden="true">&#x25BE;</span>',
      '</button>'
    ),
    .bs_html_esc(panel_id),
    .bs_html_esc(label),
    as.integer(n_total),
    as.integer(n_total)
  )
}


#' Build the static colour-legend strip displayed below a chart
#'
#' Non-interactive — a flex row of swatch+label pairs, one per brand. Brands
#' in the \code{hidden} set render with a "hidden" modifier class so the
#' colour reference fades when the user has filtered them out. Re-render
#' from JS whenever the hidden set changes (or use the JS DOM update path).
#'
#' @param brands List of brand records, each with \code{code}, \code{label},
#'   and \code{color} fields.
#' @param hidden Character. Brand codes currently hidden. Default empty.
#' @return Character. A single HTML \code{<div>} string.
#' @export
build_brand_selector_legend <- function(brands, hidden = character(0)) {
  if (!is.list(brands)) {
    stop("build_brand_selector_legend: brands must be a list")
  }
  if (length(brands) == 0L) return("")
  hidden <- as.character(hidden)
  items <- vapply(brands, function(b) {
    code  <- as.character(b$code  %||% "")
    label <- as.character(b$label %||% code)
    color <- as.character(b$color %||% "#94a3b8")
    is_hidden <- code %in% hidden
    sprintf(
      paste0(
        '<span class="bs-legend-item%s" data-bs-brand="%s">',
        '<span class="bs-legend-swatch" style="background:%s"></span>',
        '<span class="bs-legend-label">%s</span></span>'),
      if (is_hidden) " bs-legend-item-hidden" else "",
      .bs_html_esc(code),
      .bs_html_esc(color),
      .bs_html_esc(label)
    )
  }, character(1L))
  paste0('<div class="bs-legend" data-bs-legend>', paste(items, collapse = ""), '</div>')
}


#' Wrap a brand-selector trigger and adjacent quick-action chips in a toolbar row
#'
#' Convenience helper: produces a flex row containing an optional label, the
#' trigger HTML, and any extra chip HTML strings (e.g. a "Cat avg" toggle).
#'
#' @param trigger_html Character. Output of \code{build_brand_selector_trigger}.
#' @param extra_chips Character vector. Additional HTML strings rendered after
#'   the trigger (e.g. Cat-avg chip).
#' @param label Character. Optional left-side label (e.g. \code{"BRANDS:"}).
#'   Empty string suppresses the label.
#' @return Character. A single HTML \code{<div>} string.
#' @export
build_brand_selector_toolbar_row <- function(trigger_html,
                                             extra_chips = character(0),
                                             label = "") {
  parts <- c()
  if (nzchar(label)) {
    parts <- c(parts, sprintf('<span class="bs-toolbar-label">%s</span>',
                              .bs_html_esc(label)))
  }
  parts <- c(parts, trigger_html, extra_chips)
  paste0('<div class="bs-toolbar-row">', paste(parts, collapse = ""), '</div>')
}


#' HTML escape a string for safe interpolation into attributes / text.
#' @keywords internal
.bs_html_esc <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;",  x, fixed = TRUE)
  x <- gsub(">", "&gt;",  x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}
