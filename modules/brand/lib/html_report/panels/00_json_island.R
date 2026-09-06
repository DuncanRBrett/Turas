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
