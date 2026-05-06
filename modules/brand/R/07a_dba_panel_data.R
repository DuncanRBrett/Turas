# ==============================================================================
# BRAND MODULE - DBA PANEL DATA SHAPER
# ==============================================================================
# Transforms run_dba() engine output into the JSON-payload-ready structure
# the DBA HTML panel consumes. Adds Wilson 95% confidence intervals to
# Fame % and Uniqueness %, enriches with quadrant-aware insight callouts,
# and computes a recommended-action verb per asset.
#
# Engine output shape (07_dba.R) carries dba_metrics + metrics_summary.
# This shaper does NOT recompute metrics — it only adds derived fields
# the renderer needs (CI bounds, action verbs, sorted asset order).
#
# VERSION: 1.0
# ==============================================================================

BRAND_DBA_PANEL_DATA_VERSION <- "1.0"

# Wilson interval z for 95% confidence
.DBA_WILSON_Z95 <- 1.959964

# Quadrant → recommended action mapping (Romaniuk's framework)
.DBA_ACTIONS <- list(
  "Use or Lose"     = "Maintain consistent use across all touchpoints.",
  "Avoid Alone"     = "Pair with stronger assets — never use as sole brand cue.",
  "Invest to Build" = "Increase exposure; the asset earns when seen.",
  "Ignore or Test"  = "Replace, retire, or run a creative test."
)


#' Build DBA panel data for HTML render
#'
#' Shapes engine output into a list ready for jsonlite::toJSON. Adds Wilson
#' 95% CIs to Fame % and Uniqueness %, attaches recommended actions, and
#' produces the insight-callouts the panel surfaces in its insight box.
#'
#' @param result List from \code{run_dba()}.
#' @param category_label Character. Optional project-level label (e.g.
#'   "All categories"); not used when DBA is brand-level but accepted for
#'   future per-category extension.
#' @param focal_brand Character. Focal brand code.
#' @param focal_colour Character. Hex colour for focal-brand highlights.
#' @param decimal_places Integer. Display precision for percentages.
#' @param wave_label Character. Optional wave label for the panel header.
#' @param image_paths Optional named character. Maps AssetCode → image
#'   path (relative to the report directory). When NULL, the renderer
#'   uses a placeholder graphic.
#'
#' @return List with elements:
#'   \item{meta}{Status, focal brand/colour, n_assets, n_respondents,
#'     fame_threshold, uniqueness_threshold, placeholder flag.}
#'   \item{assets}{Per-asset list with Fame/Uniqueness % + CI bounds + n,
#'     quadrant, action recommendation, image path.}
#'   \item{insights}{List of (verb, text) callouts for the insight box.}
#'   \item{config}{Decimal places + focal colour, used by renderer.}
#'
#' Returns a meta-only "REFUSED" payload when result is missing/refused;
#' returns a placeholder-flagged payload when result$placeholder is TRUE.
#'
#' @examples
#' \dontrun{
#'   result <- run_dba(data, structure, focal_brand = "IPK")
#'   panel  <- build_dba_panel_data(result, focal_brand = "IPK")
#'   if (panel$meta$status == "PASS") str(panel$assets[[1]])
#' }
#'
#' @export
build_dba_panel_data <- function(result,
                                  category_label = "",
                                  focal_brand    = "",
                                  focal_colour   = "#1A5276",
                                  decimal_places = 0L,
                                  wave_label     = "",
                                  image_paths    = NULL) {

  if (is.null(result) || identical(result$status, "REFUSED")) {
    return(.dba_panel_refused(result, focal_brand, focal_colour))
  }

  if (isTRUE(result$placeholder)) {
    return(.dba_panel_placeholder(result, focal_brand, focal_colour,
                                    wave_label, decimal_places))
  }

  metrics <- result$dba_metrics
  if (is.null(metrics) || nrow(metrics) == 0L) {
    return(.dba_panel_placeholder(result, focal_brand, focal_colour,
                                    wave_label, decimal_places))
  }

  fame_threshold <- as.numeric(result$metrics_summary$fame_threshold %||%
                                 DBA_DEFAULT_FAME_THRESHOLD)
  unique_threshold <- as.numeric(result$metrics_summary$uniqueness_threshold %||%
                                   DBA_DEFAULT_UNIQUENESS_THRESHOLD)

  assets <- lapply(seq_len(nrow(metrics)), function(i) {
    .dba_asset_payload(metrics[i, , drop = FALSE], image_paths,
                        result$n_respondents)
  })

  insights <- .dba_build_insights(metrics, result$metrics_summary,
                                    fame_threshold, unique_threshold)

  list(
    meta = list(
      status               = "PASS",
      placeholder          = FALSE,
      category_label       = category_label,
      focal_brand          = focal_brand,
      focal_colour         = focal_colour,
      wave_label           = wave_label,
      n_assets             = nrow(metrics),
      n_respondents        = as.integer(result$n_respondents %||% 0L),
      fame_threshold       = fame_threshold,
      uniqueness_threshold = unique_threshold
    ),
    assets   = assets,
    insights = insights,
    config = list(
      decimal_places = as.integer(decimal_places %||% 0L),
      focal_colour   = focal_colour
    )
  )
}


# ==============================================================================
# Internal: per-asset payload (with Wilson CIs + action recommendation)
# ==============================================================================

.dba_asset_payload <- function(row, image_paths, n_respondents) {
  asset_code  <- as.character(row$AssetCode)
  asset_label <- as.character(row$AssetLabel %||% asset_code)
  quadrant    <- as.character(row$Quadrant %||% "Ignore or Test")

  fame_pct   <- as.numeric(row$Fame_Pct)
  unique_pct <- as.numeric(row$Uniqueness_Pct)
  fame_n     <- as.integer(row$Fame_n %||% 0L)
  unique_n   <- as.integer(row$Uniqueness_n %||% 0L)
  n_resp     <- as.integer(n_respondents %||% 0L)

  fame_ci   <- .dba_wilson_ci(fame_n, n_resp)
  # Uniqueness denominator is the recogniser count (Fame_n), not full n.
  unique_ci <- .dba_wilson_ci(unique_n, fame_n)

  image_path <- if (!is.null(image_paths) && asset_code %in% names(image_paths))
    image_paths[[asset_code]] else NA_character_

  list(
    asset_code   = asset_code,
    asset_label  = asset_label,
    image_path   = image_path,
    fame_pct     = fame_pct,
    fame_lo      = fame_ci$lo,
    fame_hi      = fame_ci$hi,
    fame_n       = fame_n,
    unique_pct   = unique_pct,
    unique_lo    = unique_ci$lo,
    unique_hi    = unique_ci$hi,
    unique_n     = unique_n,
    n_respondents = n_resp,
    quadrant     = quadrant,
    action       = .DBA_ACTIONS[[quadrant]] %||%
                     "Review usage; data inconclusive."
  )
}


# ==============================================================================
# Internal: Wilson 95% CI for a proportion (k of n successes)
# ==============================================================================
# Returns lower + upper bounds in PERCENT (0-100), rounded to 1 dp.
# Returns NA bounds when n is 0 (no respondents to estimate from).

.dba_wilson_ci <- function(k, n) {
  if (is.na(n) || is.na(k) || n <= 0L) {
    return(list(lo = NA_real_, hi = NA_real_))
  }
  k <- max(0, min(k, n))
  p <- k / n
  z <- .DBA_WILSON_Z95
  z2 <- z * z
  denom <- 1 + z2 / n
  centre <- (p + z2 / (2 * n)) / denom
  margin <- (z * sqrt(p * (1 - p) / n + z2 / (4 * n * n))) / denom
  list(
    lo = round(max(0, centre - margin) * 100, 1),
    hi = round(min(1, centre + margin) * 100, 1)
  )
}


# ==============================================================================
# Internal: insight callouts for the panel insight box
# ==============================================================================

.dba_build_insights <- function(metrics, summary,
                                  fame_threshold, unique_threshold) {
  insights <- list()
  n_total <- nrow(metrics)

  # Distribution callout
  use_or_lose <- sum(metrics$Quadrant == "Use or Lose")
  invest      <- sum(metrics$Quadrant == "Invest to Build")
  avoid_alone <- sum(metrics$Quadrant == "Avoid Alone")
  ignore      <- sum(metrics$Quadrant == "Ignore or Test")

  if (use_or_lose > 0) {
    insights[[length(insights) + 1L]] <- list(
      verb = "Anchor",
      text = sprintf("%d of %d assets sit in 'Use or Lose' — they are the brand's anchor identifiers.",
                      use_or_lose, n_total)
    )
  }
  if (avoid_alone > 0) {
    insights[[length(insights) + 1L]] <- list(
      verb = "Pair",
      text = sprintf("%d 'Avoid Alone' asset%s — high recognition but credit leaks; never use solo.",
                      avoid_alone, if (avoid_alone == 1) "" else "s")
    )
  }
  if (invest > 0) {
    insights[[length(insights) + 1L]] <- list(
      verb = "Invest",
      text = sprintf("%d 'Invest to Build' asset%s — strong attribution but low fame; expand exposure.",
                      invest, if (invest == 1) "" else "s")
    )
  }
  if (ignore > 0) {
    insights[[length(insights) + 1L]] <- list(
      verb = "Test",
      text = sprintf("%d 'Ignore or Test' asset%s — neither famous nor distinctive; replace or test.",
                      ignore, if (ignore == 1) "" else "s")
    )
  }

  # Strongest / weakest callout
  if (n_total > 1L) {
    strength <- metrics$Fame_Pct * metrics$Uniqueness_Pct / 100
    strongest <- metrics[which.max(strength), , drop = FALSE]
    weakest   <- metrics[which.min(strength), , drop = FALSE]
    insights[[length(insights) + 1L]] <- list(
      verb = "Lead",
      text = sprintf("Strongest asset: %s (Fame %.0f%%, Uniqueness %.0f%%).",
                      strongest$AssetLabel %||% strongest$AssetCode,
                      strongest$Fame_Pct, strongest$Uniqueness_Pct)
    )
    if (weakest$AssetCode != strongest$AssetCode) {
      insights[[length(insights) + 1L]] <- list(
        verb = "Watch",
        text = sprintf("Weakest asset: %s (Fame %.0f%%, Uniqueness %.0f%%).",
                        weakest$AssetLabel %||% weakest$AssetCode,
                        weakest$Fame_Pct, weakest$Uniqueness_Pct)
      )
    }
  }

  insights
}


# ==============================================================================
# Internal: refused / placeholder payload helpers
# ==============================================================================

.dba_panel_refused <- function(result, focal_brand, focal_colour) {
  list(
    meta = list(
      status       = "REFUSED",
      placeholder  = FALSE,
      message      = result$message %||% "DBA engine refused",
      focal_brand  = focal_brand,
      focal_colour = focal_colour
    ),
    assets = list(), insights = list(), config = list()
  )
}

.dba_panel_placeholder <- function(result, focal_brand, focal_colour,
                                     wave_label, decimal_places) {
  list(
    meta = list(
      status         = "PASS",
      placeholder    = TRUE,
      note           = result$note %||% DBA_PLACEHOLDER_NOTE,
      focal_brand    = focal_brand,
      focal_colour   = focal_colour,
      wave_label     = wave_label,
      n_assets       = 0L,
      n_respondents  = as.integer(result$n_respondents %||% 0L)
    ),
    assets   = list(),
    insights = list(),
    config = list(
      decimal_places = as.integer(decimal_places %||% 0L),
      focal_colour   = focal_colour
    )
  )
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand DBA panel-data shaper loaded (v%s)",
                  BRAND_DBA_PANEL_DATA_VERSION))
}
