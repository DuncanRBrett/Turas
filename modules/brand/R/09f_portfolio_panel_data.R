# ==============================================================================
# BRAND MODULE - PORTFOLIO PANEL DATA BUILDER (§6.2)
# ==============================================================================
# Packages run_portfolio() output into a JSON-safe payload consumed by the
# HTML panel builder. Mirrors the shape of build_ma_panel_data().
#
# Phases 2-5 progressively populate the payload; later phases add
# constellation, strength, and extension blocks.
# ==============================================================================


#' Build portfolio panel data payload
#'
#' Packages the \code{run_portfolio()} result into a JSON-safe list for
#' the HTML panel builder. The \code{meta} block is always present. Analysis
#' blocks are populated as each phase ships (footprint in Phase 2,
#' constellation in Phase 4, etc.).
#'
#' @param portfolio_result List. Output from \code{run_portfolio()}.
#' @param config List. Loaded brand config.
#' @param structure List. Loaded survey structure (optional in tests).
#'
#' @return List with:
#'   \item{meta}{Named list: focal_brand, timeframe, n_total, n_weighted,
#'     wave, min_base, suppressed_cats.}
#'   \item{footprint}{List or NULL. Footprint matrix fields.}
#'   \item{clutter}{List or NULL. Clutter quadrant fields.}
#'   \item{about}{Named list: per-subtab methodology notes.}
#'
#' @export
build_portfolio_panel_data <- function(portfolio_result, config,
                                       structure = NULL) {
  if (is.null(portfolio_result) ||
      identical(portfolio_result$status, "REFUSED")) {
    return(list(meta = list(), footprint = NULL, clutter = NULL,
                about = .portfolio_about_text()))
  }

  meta <- list(
    focal_brand    = portfolio_result$focal_brand %||% config$focal_brand %||% "",
    timeframe      = portfolio_result$timeframe %||% "3m",
    n_total        = portfolio_result$n_total %||% 0L,
    n_weighted     = portfolio_result$n_weighted %||% 0,
    wave           = config$wave %||% 1L,
    min_base       = config$portfolio_min_base %||% 30L,
    suppressed_cats = portfolio_result$suppressions$low_base_cats %||%
                      character(0)
  )

  footprint_block <- .portfolio_footprint_block(portfolio_result)
  clutter_block   <- .portfolio_clutter_block(portfolio_result)

  list(
    meta      = meta,
    footprint = footprint_block,
    clutter   = clutter_block,
    about     = .portfolio_about_text()
  )
}


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

.portfolio_footprint_block <- function(portfolio_result) {
  fp <- portfolio_result$footprint_matrix
  if (is.null(fp) || !is.data.frame(fp) || nrow(fp) == 0) return(NULL)

  bases <- portfolio_result$bases$per_category
  list(
    matrix_df       = fp,
    bases_df        = if (!is.null(bases) && nrow(bases) > 0) bases
                      else data.frame(),
    suppressed_cats = portfolio_result$suppressions$low_base_cats %||%
                      character(0)
  )
}

.portfolio_clutter_block <- function(portfolio_result) {
  cl <- portfolio_result$clutter
  if (is.null(cl) || is.null(cl$clutter_df) || nrow(cl$clutter_df) == 0) {
    return(NULL)
  }
  list(
    clutter_df      = cl$clutter_df,
    ref_x           = cl$ref_x,
    ref_y           = cl$ref_y,
    suppressed_cats = cl$suppressed_cats %||% character(0)
  )
}

.portfolio_about_text <- function() {
  list(
    footprint = paste(
      "Footprint Heatmap: Each cell shows the % of buyers in a category who",
      "are aware of a brand. Denominator = screener-qualified buyers for that",
      "category (SQ2 for 3-month window, SQ1 for 13-month). A dash (\u2014) means",
      "the brand was not measured in that category — not that awareness is 0%."
    ),
    clutter = paste(
      "Clutter Quadrant: x-axis = how many brands a typical category buyer",
      "knows (awareness set size). y-axis = focal brand's share of all brand",
      "awareness in the category. Reference lines: median awareness set size",
      "(vertical) and median fair share (1/k) across categories (horizontal).",
      "Quadrant labels are interpretive — the underlying values are shown in",
      "the table below."
    ),
    constellation = paste(
      "Competitive Constellation: edges represent Jaccard similarity of",
      "co-awareness across the brand universe. Node size = total aware",
      "respondents. Layout: Fruchterman-Reingold."
    ),
    extension = paste(
      "Permission-to-Extend: lift = P(aware of focal | bought category C) /",
      "P(aware of focal | baseline). Baseline controlled by",
      "portfolio_extension_baseline config key. Two-proportion z-test with",
      "auto-fallback to Fisher exact when expected cell count < 5.",
      "Benjamini-Hochberg FDR correction applied across all categories."
    )
  )
}
