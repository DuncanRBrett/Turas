# ==============================================================================
# BRAND MODULE - DBA PANEL: ASSET DETAIL SUB-TAB
# ==============================================================================
# Renders one card per DBA asset. Each card shows:
#   - Asset image (or placeholder graphic when path is missing)
#   - Asset label + asset code
#   - Quadrant badge with the recommended action
#   - Fame % with Wilson 95% CI band
#   - Uniqueness % with Wilson 95% CI band
#
# Cards are sized to fit a 2-column grid on wide screens, single column
# on narrow. Each card root carries data-section so TurasPins can scope
# a per-asset pin.
#
# VERSION: 1.0
# ==============================================================================

BRAND_DBA_PANEL_DETAIL_VERSION <- "1.0"


#' Build the DBA Asset Detail sub-tab HTML
#'
#' @param panel_data List from \code{build_dba_panel_data()} (PASS state).
#' @param focal_colour Character. Hex colour for focal-brand highlights
#'   (drives the CI band fill).
#'
#' @return Character. HTML fragment.
#'
#' @export
build_dba_detail_html <- function(panel_data, focal_colour) {
  assets <- panel_data$assets %||% list()
  if (length(assets) == 0L) {
    return('<div class="dba-detail-empty"><p>No DBA assets to display.</p></div>')
  }

  cards <- paste(vapply(assets, function(a) .dba_detail_card(a, focal_colour),
                          character(1)), collapse = "")
  paste0('<div class="dba-detail-grid">', cards, '</div>')
}


# ==============================================================================
# Internal: a single asset card
# ==============================================================================

.dba_detail_card <- function(asset, focal_colour) {
  card_id <- sprintf("section-dba-asset-%s",
                     .dba_safe_id(asset$asset_code))
  quadrant <- asset$quadrant %||% "Ignore or Test"

  sprintf(
'<article class="dba-detail-card" id="%s" data-section="%s" data-asset-code="%s">
  <header class="dba-detail-header">
    <h3 class="dba-detail-title">%s</h3>
    <span class="dba-detail-code">%s</span>
  </header>
  %s
  <div class="dba-detail-quadrant" data-quadrant="%s">
    <span class="dba-detail-quadrant-badge">%s</span>
    <p class="dba-detail-action">%s</p>
  </div>
  %s
  %s
  <footer class="dba-detail-footer">Wilson 95%% confidence intervals on n = %d respondents.</footer>
</article>',
    .dba_esc(card_id),
    .dba_esc(card_id),
    .dba_esc(asset$asset_code),
    .dba_esc(asset$asset_label %||% asset$asset_code),
    .dba_esc(asset$asset_code),
    .dba_detail_image(asset),
    .dba_esc(quadrant),
    .dba_esc(quadrant),
    .dba_esc(asset$action %||% ""),
    .dba_detail_metric_row("Fame %",       asset$fame_pct,
                            asset$fame_lo,  asset$fame_hi,
                            asset$fame_n,   focal_colour,
                            "Recognised the asset"),
    .dba_detail_metric_row("Uniqueness %", asset$unique_pct,
                            asset$unique_lo, asset$unique_hi,
                            asset$unique_n,  focal_colour,
                            "Of recognisers, attributed correctly"),
    as.integer(asset$n_respondents %||% 0L)
  )
}


# ==============================================================================
# Internal: image (or placeholder when missing)
# ==============================================================================

.dba_detail_image <- function(asset) {
  path <- asset$image_path
  if (is.null(path) || is.na(path) || !nzchar(path)) {
    return(.dba_detail_image_placeholder(asset))
  }
  sprintf(
'<div class="dba-detail-image-wrap">
  <img src="%s" alt="%s" class="dba-detail-image" loading="lazy"/>
</div>',
    .dba_esc(path),
    .dba_esc(asset$asset_label %||% asset$asset_code))
}

.dba_detail_image_placeholder <- function(asset) {
  sprintf(
'<div class="dba-detail-image-wrap dba-detail-image-placeholder" aria-label="No image available for %s">
  <svg viewBox="0 0 80 60" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    <rect x="2" y="2" width="76" height="56" rx="4" fill="none" stroke="#c8c1b1" stroke-width="1.5" stroke-dasharray="4 3"/>
    <circle cx="28" cy="26" r="6" fill="none" stroke="#c8c1b1" stroke-width="1.5"/>
    <path d="M2 50 L28 30 L50 44 L78 22" fill="none" stroke="#c8c1b1" stroke-width="1.5"/>
  </svg>
  <span class="dba-detail-image-placeholder-label">%s</span>
</div>',
    .dba_esc(asset$asset_label %||% asset$asset_code),
    .dba_esc(asset$asset_code))
}


# ==============================================================================
# Internal: metric row with CI band
# ==============================================================================

.dba_detail_metric_row <- function(label, pct, lo, hi, n,
                                     focal_colour, helper) {
  if (is.null(pct) || is.na(pct)) {
    return(sprintf(
'<div class="dba-detail-metric">
  <div class="dba-detail-metric-label">%s</div>
  <div class="dba-detail-metric-empty">No responses</div>
  <div class="dba-detail-metric-helper">%s</div>
</div>',
      .dba_esc(label), .dba_esc(helper)))
  }

  pct_safe <- max(0, min(100, pct))
  lo_safe <- if (is.null(lo) || is.na(lo)) pct_safe else max(0, min(100, lo))
  hi_safe <- if (is.null(hi) || is.na(hi)) pct_safe else max(0, min(100, hi))
  band_w <- max(0, hi_safe - lo_safe)

  sprintf(
'<div class="dba-detail-metric">
  <div class="dba-detail-metric-label">%s</div>
  <div class="dba-detail-metric-row">
    <div class="dba-detail-metric-value" style="color:%s">%.0f%%</div>
    <div class="dba-detail-metric-bar" role="img" aria-label="%s %.0f%% (95%% CI %.0f%% to %.0f%%)">
      <div class="dba-detail-metric-bar-track">
        <div class="dba-detail-metric-bar-band" style="left:%.1f%%;width:%.1f%%;background:%s"></div>
        <div class="dba-detail-metric-bar-point" style="left:%.1f%%;background:%s"></div>
      </div>
      <div class="dba-detail-metric-ci">95%% CI: %.0f%% &ndash; %.0f%%, n = %d</div>
    </div>
  </div>
  <div class="dba-detail-metric-helper">%s</div>
</div>',
    .dba_esc(label),
    .dba_esc(focal_colour), pct_safe,
    .dba_esc(label), pct_safe, lo_safe, hi_safe,
    lo_safe, band_w, .dba_detail_band_colour(focal_colour),
    pct_safe, .dba_esc(focal_colour),
    lo_safe, hi_safe, as.integer(n %||% 0L),
    .dba_esc(helper))
}


# ==============================================================================
# Internal: derive a softer band colour from the focal colour (hex → rgba)
# ==============================================================================

.dba_detail_band_colour <- function(focal_colour) {
  if (is.null(focal_colour) || !nzchar(focal_colour) ||
      !grepl("^#[0-9A-Fa-f]{6}$", focal_colour)) {
    return("rgba(26,82,118,0.18)")
  }
  r <- strtoi(substr(focal_colour, 2, 3), 16L)
  g <- strtoi(substr(focal_colour, 4, 5), 16L)
  b <- strtoi(substr(focal_colour, 6, 7), 16L)
  sprintf("rgba(%d,%d,%d,0.18)", r, g, b)
}


# ==============================================================================
# Internal: safe DOM id from an asset code
# ==============================================================================

.dba_safe_id <- function(x) {
  if (is.null(x)) return("unknown")
  out <- gsub("[^A-Za-z0-9_-]", "-", as.character(x))
  if (!nzchar(out)) out <- "unknown"
  out
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
  message(sprintf("TURAS>Brand DBA asset detail loaded (v%s)",
                  BRAND_DBA_PANEL_DETAIL_VERSION))
}
