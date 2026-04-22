# ==============================================================================
# BRAND MODULE - PORTFOLIO OVERVIEW SUBTAB RENDERER
# ==============================================================================
# Renders the focal-brand-centred Overview subtab for the Portfolio panel.
# Consumes the payload produced by build_portfolio_overview() (09h data file).
#
# Layout:
#   1. Focal brand picker chip bar
#   2. Hero KPI strip (4 cards, recomputed per focal brand)
#   3. Focal awareness ranked bar chart (one bar per category)
#   4. Category × focal brand summary table (depth-aware)
#   5. Deep-dive detail strip (only when at least one full-depth category)
#
# JSON blob is embedded so the JS module (brand_portfolio_overview.js) can
# swap content client-side on focal picker change without a round-trip.
#
# VERSION: 1.0
# ==============================================================================

PORTFOLIO_OVERVIEW_SUBTAB_VERSION <- "1.0"

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a


# ==============================================================================
# PUBLIC ENTRY POINT
# ==============================================================================

#' Render the Portfolio Overview subtab
#'
#' @param overview List. Output of \code{build_portfolio_overview()}.
#' @param focal_brand Character. Focal brand code (server-side initial render).
#' @param focal_colour Character. Hex colour for the focal brand.
#' @param about_text Character. Optional about-this-analysis text.
#' @return Character. HTML fragment.
#' @keywords internal
.pf_overview_subtab <- function(overview, focal_brand, focal_colour,
                                 about_text = "") {
  if (is.null(overview) || identical(overview$status, "REFUSED") ||
      length(overview$categories) == 0) {
    return('<p style="color:#94a3b8;padding:24px 0;">Overview data not available.</p>')
  }

  if (!nzchar(focal_brand)) focal_brand <- overview$focal_brand

  picker_html <- .pfo_picker(overview$brands, focal_brand, focal_colour)
  hero_html   <- .pfo_hero_host(overview, focal_brand, focal_colour)
  chart_html  <- .pfo_chart_host(overview, focal_brand, focal_colour)
  table_html  <- .pfo_table_host(overview, focal_brand, focal_colour)
  deep_html   <- .pfo_deep_host(overview, focal_brand, focal_colour)

  data_script <- sprintf(
    '<script type="application/json" id="pf-overview-data">%s</script>',
    .pfo_escape_json(.pfo_to_json(overview, focal_colour))
  )

  paste0(
    .pf_section_toolbar("pf-overview"),
    data_script,
    picker_html,
    '<div class="pfo-grid">',
      '<div class="pfo-hero-wrap" id="pfo-hero">', hero_html, '</div>',
      '<div class="pfo-chart-wrap" id="pfo-chart">', chart_html, '</div>',
      '<div class="pfo-table-wrap" id="pfo-table">', table_html, '</div>',
      '<div class="pfo-deep-wrap" id="pfo-deep">', deep_html, '</div>',
    '</div>',
    if (nzchar(about_text)) {
      sprintf('<div class="pf-about-drawer"><strong>About this view:</strong> %s</div>',
              .pf_esc(about_text))
    } else ""
  )
}


# ==============================================================================
# PICKER
# ==============================================================================

.pfo_picker <- function(brands, focal_brand, focal_colour) {
  if (is.null(brands) || nrow(brands) == 0) return("")

  chips <- paste(vapply(seq_len(nrow(brands)), function(i) {
    bc  <- brands$brand_code[i]
    lbl <- brands$brand_name[i]
    is_active <- identical(bc, focal_brand)
    style <- if (is_active) {
      sprintf('style="background:%s;border-color:%s;color:#fff;"',
              focal_colour, focal_colour)
    } else ""
    sprintf(
      '<button type="button" class="pfo-picker-chip%s" data-pfo-brand="%s" %s>%s</button>',
      if (is_active) " active" else "", .pf_esc(bc), style, .pf_esc(lbl)
    )
  }, character(1)), collapse = "")

  paste0(
    '<div class="pfo-picker" role="tablist" aria-label="Focal brand picker">',
      '<span class="pfo-picker-label">Focal brand</span>',
      '<div class="pfo-picker-chips">', chips, '</div>',
    '</div>'
  )
}


# ==============================================================================
# HERO KPI STRIP (4 cards)
# ==============================================================================

.pfo_hero_host <- function(overview, focal_brand, focal_colour) {
  k <- .pfo_compute_kpis(overview, focal_brand)
  .pfo_hero_cards(k, focal_colour)
}

.pfo_compute_kpis <- function(overview, focal_brand) {
  cats <- overview$categories
  if (length(cats) == 0) {
    return(list(n_cats_total = 0L, n_cats_aware = 0L, n_deep = 0L,
                avg_awareness = NA_real_, focal_brand = focal_brand))
  }

  aware_vals <- vapply(cats, function(c) {
    v <- c$awareness_pct[[focal_brand]]
    if (is.null(v) || !is.finite(v)) NA_real_ else as.numeric(v)
  }, numeric(1))

  is_deep    <- vapply(cats, function(c) identical(c$analysis_depth, "full"),
                       logical(1))
  n_aware    <- sum(!is.na(aware_vals) & aware_vals > 0)
  avg_aware  <- if (n_aware > 0) {
    mean(aware_vals[!is.na(aware_vals) & aware_vals > 0])
  } else NA_real_

  list(
    n_cats_total  = length(cats),
    n_cats_aware  = as.integer(n_aware),
    n_deep        = as.integer(sum(is_deep)),
    avg_awareness = avg_aware,
    focal_brand   = focal_brand
  )
}

.pfo_hero_cards <- function(k, focal_colour) {
  fmt_n   <- function(x) if (is.null(x) || is.na(x)) "\u2014" else
    sprintf("%.0f%%", x)
  card <- function(value, label) sprintf(
    '<div class="pf-kpi-card"><div class="pf-kpi-value">%s</div><div class="pf-kpi-label">%s</div></div>',
    .pf_esc(value), .pf_esc(label)
  )

  paste0(
    '<div class="pf-hero-strip">',
      card(sprintf("%d of %d", k$n_cats_aware, k$n_cats_total),
           paste("Categories where", k$focal_brand, "has awareness")),
      card(fmt_n(k$avg_awareness),
           "Average awareness across categories with presence"),
      card(as.character(k$n_deep),
           "Deep-dive categories in the study"),
      card(as.character(k$n_cats_total),
           "Total categories tracked"),
    '</div>'
  )
}


# ==============================================================================
# RANKED BAR CHART
# ==============================================================================

.pfo_chart_host <- function(overview, focal_brand, focal_colour) {
  rows <- .pfo_rank_rows(overview, focal_brand)
  if (length(rows) == 0) {
    return('<p style="color:#94a3b8;padding:16px 0;">No awareness data to display.</p>')
  }

  max_val <- max(vapply(rows, function(r) r$value, numeric(1)), na.rm = TRUE)
  if (!is.finite(max_val) || max_val <= 0) max_val <- 100

  bars <- paste(vapply(rows, function(r) {
    pct <- if (is.finite(r$value)) r$value / max_val * 100 else 0
    depth_badge <- if (identical(r$depth, "full"))
      '<span class="pfo-depth-badge pfo-depth-full">Deep-dive</span>' else
      '<span class="pfo-depth-badge pfo-depth-aware">Awareness</span>'
    value_str <- if (is.finite(r$value)) sprintf("%.0f%%", r$value) else "—"
    sprintf(
      '<div class="pfo-bar-row"><div class="pfo-bar-label">%s%s</div><div class="pfo-bar-track"><div class="pfo-bar-fill" style="width:%.1f%%;background:%s;"></div></div><div class="pfo-bar-value">%s</div></div>',
      .pf_esc(r$cat_name), depth_badge, pct, focal_colour, value_str
    )
  }, character(1)), collapse = "")

  paste0(
    '<h3 class="pfo-section-title">Focal brand awareness ranked by category</h3>',
    '<div class="pfo-bars">', bars, '</div>'
  )
}

.pfo_rank_rows <- function(overview, focal_brand) {
  cats <- overview$categories
  if (length(cats) == 0) return(list())

  rows <- lapply(cats, function(c) {
    v <- c$awareness_pct[[focal_brand]]
    list(
      cat_code = c$cat_code,
      cat_name = c$cat_name,
      depth    = c$analysis_depth %||% "awareness_only",
      value    = if (is.null(v) || !is.finite(v)) NA_real_ else as.numeric(v)
    )
  })
  names(rows) <- NULL

  vals <- vapply(rows, function(r) if (is.na(r$value)) -1 else r$value, numeric(1))
  rows[order(-vals)]
}


# ==============================================================================
# SUMMARY TABLE + DEEP-DIVE STRIP  (see 09_portfolio_overview_subtab_parts.R)
# ==============================================================================

.pfo_table_host <- function(overview, focal_brand, focal_colour) {
  pfo_render_table(overview, focal_brand, focal_colour)
}

.pfo_deep_host <- function(overview, focal_brand, focal_colour) {
  pfo_render_deep_strip(overview, focal_brand, focal_colour)
}


# ==============================================================================
# JSON SERIALISER (payload for client-side rerender)
# ==============================================================================

.pfo_to_json <- function(overview, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")

  payload <- list(
    focal_colour = focal_colour,
    focal_brand  = overview$focal_brand %||% "",
    brands       = overview$brands,
    categories   = lapply(overview$categories, function(c) {
      list(
        cat_code       = c$cat_code,
        cat_name       = c$cat_name,
        analysis_depth = c$analysis_depth,
        cat_usage_pct  = c$cat_usage_pct,
        n_buyers_uw    = c$n_buyers_uw,
        total_n_uw     = c$total_n_uw,
        brand_codes    = c$brand_codes,
        brand_names    = c$brand_names,
        awareness_pct  = c$awareness_pct,
        deep_dive      = c$deep_dive
      )
    })
  )

  tryCatch(
    jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null",
                     na = "null", digits = 4),
    error = function(e) "{}"
  )
}

.pfo_escape_json <- function(s) {
  # Only the closing-script sequence needs escaping inside <script type="...">
  gsub("</script", "<\\/script", s, fixed = TRUE)
}
