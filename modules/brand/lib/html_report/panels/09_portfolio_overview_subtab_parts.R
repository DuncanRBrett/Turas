# ==============================================================================
# BRAND MODULE - PORTFOLIO OVERVIEW SUBTAB: TABLE + DEEP-DIVE PARTS
# ==============================================================================
# Helpers kept in a separate file to keep the main subtab renderer
# (09_portfolio_overview_subtab.R) under the 300-line active-line limit.
#
# Exports: pfo_render_table(), pfo_render_deep_strip()
# ==============================================================================

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a


# ==============================================================================
# SUMMARY TABLE
# ==============================================================================

#' Render the overview summary table (one row per category)
#' @keywords internal
pfo_render_table <- function(overview, focal_brand, focal_colour) {
  cats <- overview$categories
  if (length(cats) == 0) return("")

  rows <- lapply(cats, function(c) .pfo_table_row_record(c, focal_brand))

  rows <- rows[order(-vapply(rows, function(r) {
    if (is.na(r$focal_aware)) -1 else r$focal_aware
  }, numeric(1)))]

  body <- paste(vapply(rows, .pfo_table_row_html, character(1)), collapse = "")

  paste0(
    '<h3 class="pfo-section-title">Category detail</h3>',
    '<div class="pfo-table-scroll"><table class="pfo-table">',
    '<thead><tr>',
    '<th class="pfo-th-cat">Category</th>',
    '<th class="pfo-th-depth">Type</th>',
    '<th class="pfo-th-num">Cat. usage</th>',
    '<th class="pfo-th-num">Focal awareness</th>',
    '<th class="pfo-th-num">Rank</th>',
    '<th class="pfo-th-num">Gap to leader</th>',
    '<th class="pfo-th-num">Penetration</th>',
    '<th class="pfo-th-num">SCR</th>',
    '<th class="pfo-th-num">Vol share</th>',
    '<th class="pfo-th-num">Freq</th>',
    '</tr></thead><tbody>', body, '</tbody></table></div>',
    '<p class="pfo-table-note">Rank = focal brand\u2019s position on awareness within the category. Gap = pct-point distance from the category leader. Penetration/SCR/Vol/Freq available for deep-dive categories only.</p>'
  )
}

.pfo_table_row_record <- function(c, focal_brand) {
  aware_vec <- vapply(c$brand_codes, function(bc) {
    v <- c$awareness_pct[[bc]]
    if (is.null(v) || !is.finite(v)) NA_real_ else as.numeric(v)
  }, numeric(1))
  names(aware_vec) <- c$brand_codes

  focal_aware <- aware_vec[[focal_brand]] %||% NA_real_
  valid       <- aware_vec[!is.na(aware_vec)]
  rank_val    <- if (length(valid) > 0 && !is.na(focal_aware)) {
    as.integer(sum(valid > focal_aware)) + 1L
  } else NA_integer_
  n_brands_ranked <- length(valid)
  leader_val  <- if (length(valid) > 0) max(valid) else NA_real_
  gap         <- if (!is.na(focal_aware) && !is.na(leader_val)) {
    leader_val - focal_aware
  } else NA_real_

  dd <- if (!is.null(c$deep_dive) && !is.null(c$deep_dive[[focal_brand]])) {
    c$deep_dive[[focal_brand]]
  } else NULL

  list(
    cat_code      = c$cat_code,
    cat_name      = c$cat_name,
    depth         = c$analysis_depth %||% "awareness_only",
    cat_usage_pct = c$cat_usage_pct,
    focal_aware   = focal_aware,
    rank          = rank_val,
    n_brands      = n_brands_ranked,
    gap           = gap,
    pen_pct       = if (!is.null(dd)) dd$penetration_pct else NA_real_,
    scr_pct       = if (!is.null(dd)) dd$scr_pct         else NA_real_,
    vol_pct       = if (!is.null(dd)) dd$vol_share_pct   else NA_real_,
    freq          = if (!is.null(dd)) dd$freq_mean       else NA_real_
  )
}

.pfo_table_row_html <- function(r) {
  depth_pill <- if (identical(r$depth, "full"))
    '<span class="pfo-pill pfo-pill-deep">Deep-dive</span>' else
    '<span class="pfo-pill pfo-pill-aware">Awareness</span>'

  fmt_pct <- function(v) if (is.null(v) || is.na(v)) "\u2014" else
    sprintf("%.0f%%", v)
  fmt_num <- function(v, d = 1) if (is.null(v) || is.na(v)) "\u2014" else
    sprintf(paste0("%.", d, "f"), v)
  fmt_rank <- function(r) {
    if (is.null(r$rank) || is.na(r$rank)) return("\u2014")
    sprintf("#%d of %d", r$rank, r$n_brands)
  }
  fmt_gap <- function(v) {
    if (is.null(v) || is.na(v)) return("\u2014")
    if (v <= 0.5) return('<span class="pfo-gap-leader">Leader</span>')
    sprintf("\u2212%.0f pp", v)
  }

  na_cls <- function(v) if (is.null(v) || is.na(v)) " pfo-td-na" else ""

  sprintf(
    paste0('<tr><td class="pfo-td-cat">%s</td>',
           '<td>%s</td>',
           '<td class="pfo-td-num">%s</td>',
           '<td class="pfo-td-num pfo-td-focal">%s</td>',
           '<td class="pfo-td-num">%s</td>',
           '<td class="pfo-td-num">%s</td>',
           '<td class="pfo-td-num%s">%s</td>',
           '<td class="pfo-td-num%s">%s</td>',
           '<td class="pfo-td-num%s">%s</td>',
           '<td class="pfo-td-num%s">%s</td></tr>'),
    .pf_esc(r$cat_name), depth_pill,
    fmt_pct(r$cat_usage_pct), fmt_pct(r$focal_aware),
    fmt_rank(r), fmt_gap(r$gap),
    na_cls(r$pen_pct), fmt_pct(r$pen_pct),
    na_cls(r$scr_pct), fmt_pct(r$scr_pct),
    na_cls(r$vol_pct), fmt_pct(r$vol_pct),
    na_cls(r$freq),    fmt_num(r$freq, 1)
  )
}


# ==============================================================================
# DEEP-DIVE STRIP (competitive context for each deep-dive category)
# ==============================================================================

#' Render deep-dive category cards showing focal brand's competitive position
#' @keywords internal
pfo_render_deep_strip <- function(overview, focal_brand, focal_colour) {
  cats <- overview$categories
  deep <- Filter(function(c) identical(c$analysis_depth, "full") &&
                   !is.null(c$deep_dive), cats)
  if (length(deep) == 0) return("")

  cards <- paste(vapply(deep, function(c) {
    .pfo_deep_card_html(c, focal_brand, focal_colour)
  }, character(1)), collapse = "")

  paste0(
    '<h3 class="pfo-section-title">Deep-dive competitive context</h3>',
    '<div class="pfo-deep-grid">', cards, '</div>'
  )
}

.pfo_deep_card_html <- function(c, focal_brand, focal_colour) {
  dd <- c$deep_dive
  focal_dd <- dd[[focal_brand]]
  if (is.null(focal_dd)) return("")

  # Build ranked list of top 5 competitors by SCR
  rows <- lapply(c$brand_codes, function(bc) {
    bdd <- dd[[bc]]
    if (is.null(bdd)) return(NULL)
    list(
      code = bc,
      name = c$brand_names[[bc]] %||% bc,
      pen  = bdd$penetration_pct,
      scr  = bdd$scr_pct,
      vol  = bdd$vol_share_pct,
      is_focal = identical(bc, focal_brand)
    )
  })
  rows <- Filter(Negate(is.null), rows)
  rows <- rows[order(-vapply(rows, function(r) r$scr %||% -1, numeric(1)))]
  top_n <- min(5L, length(rows))
  rows <- rows[seq_len(top_n)]

  rank_body <- paste(vapply(seq_along(rows), function(i) {
    r <- rows[[i]]
    cls <- if (r$is_focal) ' class="pfo-deep-focal"' else ""
    sprintf(
      '<tr%s><td>#%d %s</td><td class="pfo-td-num">%s</td><td class="pfo-td-num">%s</td></tr>',
      cls, i, .pf_esc(r$name),
      if (is.na(r$scr)) "\u2014" else sprintf("%.0f%%", r$scr),
      if (is.na(r$pen)) "\u2014" else sprintf("%.0f%%", r$pen)
    )
  }, character(1)), collapse = "")

  focal_rank <- which(vapply(rows, function(r) r$is_focal, logical(1)))
  focal_rank_txt <- if (length(focal_rank) == 1) sprintf("#%d", focal_rank) else "Not top 5"

  sprintf(
    paste0('<div class="pfo-deep-card">',
           '<div class="pfo-deep-card-head"><span class="pfo-deep-card-title">%s</span>',
           '<span class="pfo-deep-card-rank">Focal: %s by SCR</span></div>',
           '<div class="pfo-deep-card-kpis"><div><span class="pfo-kpi-mini-v">%s</span><span class="pfo-kpi-mini-l">SCR</span></div>',
           '<div><span class="pfo-kpi-mini-v">%s</span><span class="pfo-kpi-mini-l">Penetration</span></div>',
           '<div><span class="pfo-kpi-mini-v">%s</span><span class="pfo-kpi-mini-l">Vol share</span></div></div>',
           '<table class="pfo-deep-rank"><tbody>%s</tbody></table>',
           '</div>'),
    .pf_esc(c$cat_name), .pf_esc(focal_rank_txt),
    if (is.na(focal_dd$scr_pct %||% NA)) "\u2014" else sprintf("%.0f%%", focal_dd$scr_pct),
    if (is.na(focal_dd$penetration_pct %||% NA)) "\u2014" else sprintf("%.0f%%", focal_dd$penetration_pct),
    if (is.na(focal_dd$vol_share_pct %||% NA)) "\u2014" else sprintf("%.0f%%", focal_dd$vol_share_pct),
    rank_body
  )
}
