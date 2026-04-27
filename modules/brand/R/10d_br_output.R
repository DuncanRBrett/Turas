# ==============================================================================
# BRAND MODULE - BRANDED REACH: PANEL DATA ASSEMBLY
# ==============================================================================
# Shapes the engine output (per-ad metrics, misattribution, media mix) into
# the panel-data structure consumed by the HTML renderer
# (lib/html_report/panels/10_branded_reach_panel.R).
#
# Mirrors the WOM panel-data contract: a list with meta, ads, misattribution,
# media_mix and config sub-lists, ready for jsonlite::toJSON.
#
# VERSION: 1.0
# ==============================================================================

BRAND_BRANDED_REACH_OUTPUT_VERSION <- "1.0"


#' Assemble branded-reach panel data for HTML render
#'
#' @param result List from \code{run_branded_reach()}.
#' @param category_label Character. Friendly category name (e.g. "Spices").
#' @param focal_brand Character. Focal brand code.
#' @param focal_colour Character. Hex colour for focal-brand highlights.
#' @param decimal_places Integer. Display precision for percentages.
#' @param wave_label Character. Optional wave label for the panel header.
#'
#' @return List ready for the HTML panel renderer.
#'
#' @export
build_branded_reach_panel_data <- function(result,
                                            category_label = "",
                                            focal_brand = "",
                                            focal_colour = "#1A5276",
                                            decimal_places = 0L,
                                            wave_label = "") {

  if (is.null(result) || identical(result$status, "REFUSED")) {
    return(list(
      meta = list(status = "REFUSED",
                   message = result$message %||% "No branded-reach data"),
      ads = list(), misattribution = list(), media_mix = list()
    ))
  }

  ads <- result$ads %||% list()

  list(
    meta = list(
      status         = "PASS",
      category_label = category_label,
      focal_brand    = focal_brand,
      focal_colour   = focal_colour,
      wave_label     = wave_label,
      n_assets       = length(ads),
      n_respondents  = result$meta$n_respondents %||% NA_integer_,
      cat_code       = result$meta$cat_code %||% NA_character_,
      weighted       = isTRUE(result$meta$weighted)
    ),
    ads             = ads,
    misattribution  = result$misattribution %||% list(),
    media_mix       = result$media_mix %||% list(),
    config = list(
      decimal_places = as.integer(decimal_places %||% 0L),
      focal_colour   = focal_colour
    )
  )
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Branded reach output loaded (v%s)",
                  BRAND_BRANDED_REACH_OUTPUT_VERSION))
}
