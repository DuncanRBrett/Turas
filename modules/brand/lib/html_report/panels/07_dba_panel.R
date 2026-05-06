# ==============================================================================
# BRAND MODULE - DBA PANEL HTML RENDERER (orchestrator)
# ==============================================================================
# Project-level Distinctive Brand Assets panel. Two sub-tabs share the
# section-root for pin/PNG capture:
#
#   - Quadrant view  — Romaniuk Fame x Uniqueness scatter (07_dba_panel_quadrant.R)
#   - Asset Detail   — per-asset cards with Wilson CIs   (07_dba_panel_detail.R)
#
# When the engine emits a placeholder result (no DBA assets configured),
# the orchestrator delegates to build_shared_placeholder_card() so all
# brand-module placeholders render identically.
#
# Interaction JS: js/brand_dba_panel.js (sub-tab switching). Wired in
# 99_html_report_main.R alongside other panel JS files.
#
# VERSION: 1.0
# ==============================================================================

BRAND_DBA_PANEL_VERSION <- "1.0"


#' Build the project-level DBA panel HTML fragment
#'
#' @param panel_data List from \code{build_dba_panel_data()}.
#' @param scope_id Character. DOM id for the section root (default
#'   "section-dba"). Used by TurasPins to scope a panel-level pin.
#' @param focal_colour Character. Hex colour for focal-brand highlights.
#' @param wave_label Character. Optional wave label shown in placeholder
#'   badge.
#'
#' @return Character. A single HTML fragment.
#'
#' @export
build_dba_panel_html <- function(panel_data,
                                  scope_id     = "section-dba",
                                  focal_colour = NULL,
                                  wave_label   = "") {

  if (is.null(panel_data) || is.null(panel_data$meta)) {
    return(.dba_panel_empty_state(scope_id))
  }

  if (identical(panel_data$meta$status, "REFUSED")) {
    return(.dba_panel_refused_state(scope_id, panel_data$meta$message))
  }

  # Placeholder mode → delegate to the shared helper for visual parity
  if (isTRUE(panel_data$meta$placeholder)) {
    note <- panel_data$meta$note %||% "Data not yet collected for DBA"
    return(build_shared_placeholder_card(
      scope_id  = scope_id,
      title     = "Distinctive Brand Assets",
      note      = note,
      badge     = if (nzchar(wave_label)) wave_label else "",
      next_step = "Add DBA_Assets to the Survey_Structure and run the DBA battery in the next wave to populate this panel."
    ))
  }

  if (is.null(focal_colour) || !nzchar(focal_colour)) {
    focal_colour <- panel_data$meta$focal_colour %||% "#1A5276"
  }

  panel_id <- "dba-panel"
  json_payload <- .dba_panel_json(panel_data, focal_colour)

  paste0(
    sprintf(
      '<section class="dba-panel" id="%s" data-section="%s" data-focal-colour="%s" style="--dba-brand:%s">',
      .dba_esc(scope_id), .dba_esc(scope_id),
      .dba_esc(focal_colour), .dba_esc(focal_colour)),
    sprintf('<div class="dba-panel-body" id="%s">', panel_id),
    sprintf('<script type="application/json" class="dba-panel-data">%s</script>',
            json_payload),
    .dba_subnav(),
    .dba_quadrant_section(panel_data, focal_colour),
    .dba_detail_section(panel_data, focal_colour),
    .dba_insight_box(panel_data),
    '</div>',
    '</section>'
  )
}


# ==============================================================================
# Sub-nav
# ==============================================================================

.dba_subnav <- function() {
  tabs <- list(
    list(key = "quadrant", label = "Quadrant view"),
    list(key = "detail",   label = "Asset detail")
  )
  btns <- paste(vapply(tabs, function(t) {
    active <- if (identical(t$key, "quadrant")) " active" else ""
    sprintf(
      '<button type="button" class="dba-subtab-btn%s" data-dba-tab="%s">%s</button>',
      active, t$key, .dba_esc(t$label))
  }, character(1)), collapse = "")
  sprintf('<nav class="dba-subnav" role="tablist">%s</nav>', btns)
}


# ==============================================================================
# Section wrappers — actual rendering lives in 07_dba_panel_quadrant.R
# and 07_dba_panel_detail.R. Wrappers here only manage the show/hide
# default state.
# ==============================================================================

.dba_quadrant_section <- function(panel_data, focal_colour) {
  body <- if (exists("build_dba_quadrant_html", mode = "function"))
    build_dba_quadrant_html(panel_data, focal_colour) else ""
  sprintf(
    '<div class="dba-subtab" data-dba-tab="quadrant">%s</div>', body)
}

.dba_detail_section <- function(panel_data, focal_colour) {
  body <- if (exists("build_dba_detail_html", mode = "function"))
    build_dba_detail_html(panel_data, focal_colour) else ""
  sprintf(
    '<div class="dba-subtab" data-dba-tab="detail" hidden>%s</div>', body)
}


# ==============================================================================
# Insight box
# ==============================================================================

.dba_insight_box <- function(panel_data) {
  insights <- panel_data$insights %||% list()
  if (length(insights) == 0L) return("")

  items <- paste(vapply(insights, function(it) {
    verb <- .dba_esc(it$verb %||% "")
    txt  <- .dba_esc(it$text %||% "")
    sprintf(
      '<li class="dba-insight-item"><span class="dba-insight-verb">%s</span><span class="dba-insight-text">%s</span></li>',
      verb, txt)
  }, character(1)), collapse = "")

  sprintf(
'<div class="dba-insight-box">
  <h4 class="dba-insight-title">What this is telling you</h4>
  <ul class="dba-insight-list">%s</ul>
</div>',
    items)
}


# ==============================================================================
# JSON payload — the renderer hands this to JS for chart redraw / re-pin
# ==============================================================================

.dba_panel_json <- function(panel_data, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    return("{}")
  }
  jsonlite::toJSON(panel_data,
                   auto_unbox = TRUE, na = "null", pretty = FALSE,
                   digits = 4)
}


# ==============================================================================
# Empty / refused states (rare — used when panel_data is malformed)
# ==============================================================================

.dba_panel_empty_state <- function(scope_id) {
  sprintf(
    '<section class="dba-panel-empty" id="%s" data-section="%s"><p>DBA panel data unavailable.</p></section>',
    .dba_esc(scope_id), .dba_esc(scope_id))
}

.dba_panel_refused_state <- function(scope_id, message) {
  msg <- if (is.null(message) || !nzchar(message))
    "DBA could not be calculated for this project." else message
  sprintf(
    '<section class="dba-panel-empty" id="%s" data-section="%s"><p>%s</p></section>',
    .dba_esc(scope_id), .dba_esc(scope_id), .dba_esc(msg))
}


# ==============================================================================
# HTML escape helper
# ==============================================================================

.dba_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;",  x, fixed = TRUE)
  x <- gsub("<", "&lt;",   x, fixed = TRUE)
  x <- gsub(">", "&gt;",   x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand DBA panel orchestrator loaded (v%s)",
                  BRAND_DBA_PANEL_VERSION))
}
