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
      ads = list(), misattribution = list(), media_mix = list(),
      insights = list()
    ))
  }

  ads      <- result$ads %||% list()
  misattr  <- result$misattribution %||% list()
  mediamx  <- result$media_mix %||% list()

  insights <- .br_build_insights(ads, misattr, mediamx,
                                  focal_brand = focal_brand)

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
    misattribution  = misattr,
    media_mix       = mediamx,
    insights        = insights,
    config = list(
      decimal_places = as.integer(decimal_places %||% 0L),
      focal_colour   = focal_colour
    )
  )
}


# ==============================================================================
# Internal: insight callouts for the panel insight strip
# ==============================================================================
# Computes auto-generated insights from per-ad metrics + misattribution +
# media-mix tables. Renderer surfaces these at the top of each sub-tab as
# small (verb, text) chips alongside the editable analyst-insight box.

.br_build_insights <- function(ads, misattribution, media_mix, focal_brand) {
  insights <- list()
  if (length(ads) == 0L) return(insights)

  # Best branded-reach ad (highest branded_reach_pct)
  br_pcts <- vapply(ads, function(a)
    suppressWarnings(as.numeric(a$branded_reach_pct %||% NA_real_)),
    numeric(1))
  if (any(!is.na(br_pcts))) {
    i <- which.max(br_pcts)
    if (length(i) == 1L && is.finite(br_pcts[[i]])) {
      best <- ads[[i]]
      insights[[length(insights) + 1L]] <- list(
        verb = "Best",
        text = sprintf("%s leads on branded reach (%.0f%% of category respondents).",
                        best$asset_label %||% best$asset_code,
                        100 * br_pcts[[i]])
      )
    }
  }

  # Worst misattribution leak — highest single-competitor share among
  # respondents-who-saw-it across all ads.
  leak <- .br_worst_misattribution(ads, misattribution, focal_brand)
  if (!is.null(leak)) {
    insights[[length(insights) + 1L]] <- list(
      verb = "Watch",
      text = sprintf("%s is leaking credit to %s (%.0f%% of viewers picked them).",
                      leak$asset_label, leak$competitor_label,
                      100 * leak$pct)
    )
  }

  # Dominant media channel across ads (highest average pct_of_seen)
  ch <- .br_dominant_channel(media_mix)
  if (!is.null(ch)) {
    insights[[length(insights) + 1L]] <- list(
      verb = "Channel",
      text = sprintf("%s is the most-cited channel (%.0f%% of viewers, averaged across ads).",
                      ch$label, 100 * ch$avg_pct)
    )
  }

  # Average branding efficiency (% who saw and correctly attributed)
  bg_pcts <- vapply(ads, function(a)
    suppressWarnings(as.numeric(a$branding_pct %||% NA_real_)),
    numeric(1))
  bg_pcts <- bg_pcts[is.finite(bg_pcts)]
  if (length(bg_pcts) > 0L) {
    avg <- mean(bg_pcts)
    insights[[length(insights) + 1L]] <- list(
      verb = "Branding",
      text = sprintf("Average branding efficiency: %.0f%% of viewers correctly attribute the ad.",
                      100 * avg)
    )
  }

  insights
}


.br_worst_misattribution <- function(ads, misattribution, focal_brand) {
  if (length(misattribution) == 0L) return(NULL)
  worst <- NULL
  worst_pct <- 0
  for (asset_id in names(misattribution)) {
    df <- misattribution[[asset_id]]
    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) next
    # Drop the focal row, the DK row, and the OTHER row to find the
    # single competitor pulling the most credit.
    competitors <- df[!isTRUE(df$is_correct) &
                       !df$BrandCode %in% c("DK", "OTHER"), , drop = FALSE]
    if (nrow(competitors) == 0L) next
    top <- competitors[which.max(competitors$pct_of_seen), , drop = FALSE]
    if (!is.finite(top$pct_of_seen)) next
    if (top$pct_of_seen > worst_pct) {
      ad <- Filter(function(a) identical(a$asset_code, asset_id), ads)[[1]]
      worst <- list(
        asset_label      = ad$asset_label %||% asset_id,
        competitor_label = top$BrandLabel %||% top$BrandCode,
        pct              = top$pct_of_seen
      )
      worst_pct <- top$pct_of_seen
    }
  }
  worst
}


.br_dominant_channel <- function(media_mix) {
  if (length(media_mix) == 0L) return(NULL)
  agg <- list()
  for (asset_id in names(media_mix)) {
    df <- media_mix[[asset_id]]
    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) next
    for (i in seq_len(nrow(df))) {
      mc <- as.character(df$MediaCode[i])
      ml <- as.character(df$MediaLabel[i] %||% df$MediaCode[i])
      pct <- df$pct_of_seen[i]
      if (!is.finite(pct)) next
      if (is.null(agg[[mc]])) agg[[mc]] <- list(label = ml, sum = 0, n = 0L)
      agg[[mc]]$sum <- agg[[mc]]$sum + pct
      agg[[mc]]$n <- agg[[mc]]$n + 1L
    }
  }
  if (length(agg) == 0L) return(NULL)
  avgs <- vapply(agg, function(a) a$sum / max(1L, a$n), numeric(1))
  best <- which.max(avgs)
  if (length(best) != 1L || !is.finite(avgs[[best]])) return(NULL)
  list(label = agg[[best]]$label, avg_pct = avgs[[best]])
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Branded reach output loaded (v%s)",
                  BRAND_BRANDED_REACH_OUTPUT_VERSION))
}
