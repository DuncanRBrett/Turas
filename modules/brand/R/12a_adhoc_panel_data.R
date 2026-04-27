# ==============================================================================
# BRAND MODULE - AD HOC: PANEL DATA ASSEMBLY
# ==============================================================================
# Shapes ad hoc engine output for the HTML panel renderer
# (lib/html_report/panels/12_adhoc_panel.R).
#
# An ad hoc panel is grouped by SCOPE (one tab per scope: ALL + each
# category that has at least one ad hoc question). Within each scope we
# carry the per-question payload (mirrors demographics: total + brand_cut,
# but no buyer / tier cuts).
#
# VERSION: 1.0
# ==============================================================================

BRAND_ADHOC_OUTPUT_VERSION <- "1.0"


#' Assemble ad hoc panel data for HTML render
#'
#' @param questions List. One element per ad hoc question:
#'   list(role, column, question_text, short_label, variable_type, scope,
#'        codes, labels, result, brand_codes, brand_labels, n_scope_base).
#' @param focal_brand Character. Focal brand code (initial picker selection).
#' @param focal_colour Character. Hex colour for focal-brand highlights.
#' @param brand_colours List. Optional brand-keyed hex colour map.
#' @param decimal_places Integer. Display precision for percentages.
#' @param wave_label Character. Optional wave label for the panel header.
#'
#' @return List ready for the HTML panel renderer.
#'
#' @export
build_adhoc_panel_data <- function(questions,
                                    focal_brand    = "",
                                    focal_colour   = "#1A5276",
                                    brand_colours  = list(),
                                    decimal_places = 0L,
                                    wave_label     = "") {

  if (is.null(questions) || length(questions) == 0L) {
    return(list(
      meta = list(status = "EMPTY",
                   message = "No ad hoc questions configured."),
      scopes = list()
    ))
  }

  # Group by scope (ALL or category code) so the renderer can show one
  # sub-tab per scope. Order: ALL first, then categories alphabetically.
  scopes_seen <- unique(vapply(questions, function(q) q$scope %||% "ALL",
                                character(1L)))
  scopes_seen <- c(intersect("ALL", scopes_seen),
                    sort(setdiff(scopes_seen, "ALL")))

  kept    <- list()
  skipped <- character(0)

  scopes <- lapply(scopes_seen, function(sc) {
    q_in_scope <- Filter(function(q) (q$scope %||% "ALL") == sc, questions)
    qs <- list()
    for (q in q_in_scope) {
      res <- q$result
      if (is.null(res) || identical(res$status, "REFUSED")) {
        skipped <<- c(skipped, q$role %||% q$column %||% "(unknown)")
        next
      }
      qs[[length(qs) + 1L]] <- .adhoc_panel_one_question(q)
    }
    list(
      scope_code   = sc,
      scope_label  = if (sc == "ALL") "All respondents" else sc,
      n_questions  = length(qs),
      brand_codes  = if (length(q_in_scope) > 0L)
        as.character(q_in_scope[[1L]]$brand_codes %||% character(0))
        else character(0),
      brand_labels = if (length(q_in_scope) > 0L)
        as.character(q_in_scope[[1L]]$brand_labels %||% character(0))
        else character(0),
      n_scope_base = if (length(q_in_scope) > 0L)
        as.integer(q_in_scope[[1L]]$n_scope_base %||% NA_integer_)
        else NA_integer_,
      questions    = qs
    )
  })

  list(
    meta = list(
      status        = "PASS",
      focal_brand   = focal_brand,
      focal_colour  = focal_colour,
      wave_label    = wave_label,
      n_scopes      = length(scopes),
      n_questions   = sum(vapply(scopes, function(s) s$n_questions, integer(1L))),
      n_skipped     = length(skipped),
      skipped_roles = skipped
    ),
    brand_colours = brand_colours,
    scopes        = scopes,
    config = list(
      decimal_places = as.integer(decimal_places %||% 0L),
      focal_colour   = focal_colour
    )
  )
}


.adhoc_panel_one_question <- function(q) {
  res <- q$result
  brand_long <- if (!exists(".demo_panel_brand_long", mode = "function"))
    list() else .demo_panel_brand_long(res$brand_cut, q$codes %||%
      vapply(res$total$Code, as.character, character(1L)))
  total_long <- if (!exists(".demo_panel_dist", mode = "function"))
    list() else .demo_panel_dist(res$total)

  list(
    role          = q$role,
    column        = q$column,
    scope         = q$scope %||% "ALL",
    question_text = q$question_text,
    short_label   = q$short_label %||% q$question_text,
    variable_type = res$variable_type %||% q$variable_type %||% "Single_Response",
    codes         = q$codes %||%
                     vapply(res$total$Code, as.character, character(1L)),
    labels        = q$labels %||%
                     vapply(res$total$Label, as.character, character(1L)),
    n_total       = res$n_total,
    n_respondents = res$n_respondents,
    weighted      = isTRUE(res$weighted),
    conf_level    = res$conf_level %||% 0.95,
    bin_edges     = res$bin_edges,
    total         = total_long,
    brand_cut     = brand_long
  )
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Ad Hoc output loaded (v%s)",
                  BRAND_ADHOC_OUTPUT_VERSION))
}
