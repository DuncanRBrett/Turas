# ==============================================================================
# BRAND REPORT - JSON DATA ISLAND ESCAPING (shared by every panel)
# ==============================================================================
# Every panel embeds its payload as <script type="application/json">...</script>.
# The HTML parser ends such an element at the first "</script" it meets, and
# "<!--" followed by "<script" inside it enters the script double-escaped
# state, after which the island's own closing tag no longer closes it and the
# next island or the renderer bundle is swallowed. A respondent pasting an
# HTML email into an open-end, or a brand label containing "</", is enough.
#
# Escaping every "<" as the JSON unicode escape \u003c makes "</", "<!--" and
# "<script" unformable inside the island while JSON.parse() returns the
# identical string. Mirrors the tabs v2 report (build_report_v2.R) and the
# hardened TurasPins store (OPUS-0). Production review 2026-07-12, M3.
# ==============================================================================

#' Escape a JSON string for embedding in a <script type="application/json">
#'
#' @param json Character scalar, JSON text from jsonlite::toJSON or similar.
#' @return The same JSON with every "<" written as the escape "\\u003c".
#' @keywords internal
.br_json_island <- function(json) {
  if (is.null(json)) return("")
  gsub("<", "\\u003c", as.character(json), fixed = TRUE)
}


# ==============================================================================
# COMPARISON SLOT
# ==============================================================================
# A headline number is only readable next to something. Today that something
# is always the category average or a Dirichlet expected value; when wave
# comparison is built it becomes "change since the last wave" for the same
# numbers. So the comparison is rendered as a slot that names its source in
# an attribute, never as a sentence baked into the card, and swapping the
# source later is a change of what fills the slot rather than a rewrite of
# every card.
#
# data-compare-source values in use:
#   category-average    the mean across brands in this category
#   dirichlet-expected  the Dirichlet model's expected value for this brand
#   none                nothing to compare against on this figure
#
# The module carries a `wave` config field and a `tracker_ids` flag but
# renders no wave comparison. Nothing here computes one.

#' Render one comparison slot
#'
#' @param label Character. What the comparison is, in plain words. Shown.
#' @param value Character. The already formatted comparison figure, or an
#'   empty string for an empty slot, which renders as an en dash.
#' @param source Character. Machine-readable source key, see the list above.
#' @param extra_class Character. Optional extra class on the wrapper, so a
#'   panel can keep the styling hook it already had.
#' @return Character. One HTML fragment.
#' @keywords internal
br_compare_slot <- function(label, value, source = "category-average",
                            extra_class = "") {
  esc <- function(x) {
    if (is.null(x) || length(x) == 0L) x <- ""
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;",  x, fixed = TRUE)
    x <- gsub(">", "&gt;",  x, fixed = TRUE)
    gsub('"', "&quot;", x, fixed = TRUE)
  }
  shown <- if (!is.null(value) && length(value) > 0L &&
               nzchar(as.character(value))) as.character(value) else "\u2013"
  cls <- paste(c("br-compare-slot", if (nzchar(extra_class)) extra_class),
               collapse = " ")
  sprintf(paste0(
    '<div class="%s" data-compare-slot data-compare-source="%s">',
    '<span class="br-compare-label">%s</span> ',
    '<span class="br-compare-value">%s</span></div>'),
    cls, esc(source), esc(label), esc(shown))
}
