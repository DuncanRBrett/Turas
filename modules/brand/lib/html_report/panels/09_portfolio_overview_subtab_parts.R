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
    '<th class="pfo-th-num" title="% of all respondents who bought in this category in the recall window">Cat. usage</th>',
    '<th class="pfo-th-num" title="Mean number of brands the average category buyer is aware of">Avg brands aware</th>',
    '<th class="pfo-th-num" title="% of category buyers aware of the focal brand">Focal awareness</th>',
    '<th class="pfo-th-num" title="Focal brand\u2019s awareness rank within the category">Rank</th>',
    '<th class="pfo-th-num" title="Awareness pp gap from the category leader">Gap to leader</th>',
    '<th class="pfo-th-num" title="% of focal-cat deep-dive sample who bought the focal brand (deep-dive cats only)">% who bought</th>',
    '<th class="pfo-th-num" title="Share of category requirements \u2014 % of the focal brand buyer\u2019s category purchases that go to the focal brand (deep-dive cats only)">Loyalty (SCR)</th>',
    '<th class="pfo-th-num" title="Focal brand\u2019s share of total category volume in the deep-dive sample (deep-dive cats only)">Volume share</th>',
    '<th class="pfo-th-num" title="Mean number of times the focal brand was purchased per focal-brand buyer in the recall window">Avg purchases</th>',
    '</tr></thead><tbody>', body, '</tbody></table></div>',
    '<p class="pfo-table-note">',
    '<strong>Awareness columns</strong> (Avg brands aware / Focal awareness / Rank / Gap) use the ',
    '<em>category-buyer base</em> for each row \u2014 every respondent who said they bought in that category. ',
    '<strong>Behaviour columns</strong> (% who bought / Loyalty (SCR) / Volume share / Avg purchases) only populate for ',
    '<em>deep-dive categories</em>, and use the smaller focal-cat sample. ',
    'See the &ldquo;Why awareness here can differ from the per-category deep-dive numbers&rdquo; note at the top of this panel ',
    'for why a brand\u2019s awareness in this table can read differently from its per-category deep-dive view.',
    '</p>'
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

  # Mean number of brands a category buyer is aware of. Each brand
  # awareness column is a 0/1 indicator, so the per-buyer mean of the
  # set size equals sum(brand_awareness_pct) / 100. Uses only brands
  # whose awareness was actually measured (non-NA), which is the right
  # interpretation when the questionnaire skipped brands not in the
  # category's BrandList.
  avg_brands_aware <- if (length(valid) > 0)
                        sum(valid, na.rm = TRUE) / 100
                      else NA_real_

  list(
    cat_code         = c$cat_code,
    cat_name         = c$cat_name,
    depth            = c$analysis_depth %||% "awareness_only",
    cat_usage_pct    = c$cat_usage_pct,
    avg_brands_aware = avg_brands_aware,
    focal_aware      = focal_aware,
    rank             = rank_val,
    n_brands         = n_brands_ranked,
    gap              = gap,
    pen_pct          = if (!is.null(dd)) dd$penetration_pct else NA_real_,
    scr_pct          = if (!is.null(dd)) dd$scr_pct         else NA_real_,
    vol_pct          = if (!is.null(dd)) dd$vol_share_pct   else NA_real_,
    freq             = if (!is.null(dd)) dd$freq_mean       else NA_real_
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
           '<td class="pfo-td-num%s">%s</td>',
           '<td class="pfo-td-num pfo-td-focal">%s</td>',
           '<td class="pfo-td-num">%s</td>',
           '<td class="pfo-td-num">%s</td>',
           '<td class="pfo-td-num%s">%s</td>',
           '<td class="pfo-td-num%s">%s</td>',
           '<td class="pfo-td-num%s">%s</td>',
           '<td class="pfo-td-num%s">%s</td></tr>'),
    .pf_esc(r$cat_name), depth_pill,
    fmt_pct(r$cat_usage_pct),
    na_cls(r$avg_brands_aware), fmt_num(r$avg_brands_aware, 1),
    fmt_pct(r$focal_aware),
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

  # Balanced layout: an exact 4 wraps into 2x2 instead of 3+1; small N gets
  # one row; large N falls back to auto-fit so the cards stay readable.
  n <- length(deep)
  col_style <- if (n == 4) 'grid-template-columns: repeat(2, 1fr);'
               else if (n >= 1 && n <= 3) sprintf('grid-template-columns: repeat(%d, 1fr);', n)
               else if (n >= 5 && n <= 6) 'grid-template-columns: repeat(3, 1fr);'
               else ''

  paste0(
    '<h3 class="pfo-section-title">Deep-dive competitive context</h3>',
    sprintf('<div class="pfo-deep-grid" style="%s">', col_style),
    cards, '</div>'
  )
}

.pfo_deep_card_html <- function(c, focal_brand, focal_colour) {
  dd <- c$deep_dive
  focal_dd <- dd[[focal_brand]]
  if (is.null(focal_dd)) return("")

  # Three bases live in this card and the reader needs to see all three.
  #   * Broad awareness \u2014 % aware on the Portfolio engine's cat-buyer base
  #     (anyone who bought in the category, regardless of which deep-dive
  #     they were routed to). Wider denominator.
  #   * MPen + MMS \u2014 Mental Availability metrics on the deep-dive sample
  #     (respondents routed to THIS focal cat). MPen = % linking the brand
  #     to >= 1 CEP. MMS = brand's share of all CEP-brand associations.
  #   * Volume share / % bought / SCR \u2014 physical-behaviour metrics on the
  #     same deep-dive sample.
  # The base note at the bottom of the card spells this out.
  rows <- lapply(c$brand_codes, function(bc) {
    bdd <- dd[[bc]]
    list(
      code = bc,
      name = c$brand_names[[bc]] %||% bc,
      aware = c$awareness_pct[[bc]],
      mpen  = if (!is.null(bdd)) bdd$mpen_pct else NA_real_,
      mms   = if (!is.null(bdd)) bdd$mms_pct  else NA_real_,
      pen   = if (!is.null(bdd)) bdd$penetration_pct else NA_real_,
      scr   = if (!is.null(bdd)) bdd$scr_pct else NA_real_,
      vol   = if (!is.null(bdd)) bdd$vol_share_pct else NA_real_,
      is_focal = identical(bc, focal_brand)
    )
  })
  rows <- rows[order(-vapply(rows, function(r) r$aware %||% -1, numeric(1)))]
  top_n <- min(5L, length(rows))
  rows <- rows[seq_len(top_n)]

  fmt_pct1 <- function(v) if (is.na(v)) "\u2014" else sprintf("%.1f%%", v)
  fmt_pct0 <- function(v) if (is.na(v)) "\u2014" else sprintf("%.0f%%", v)

  rank_body <- paste(vapply(seq_along(rows), function(i) {
    r <- rows[[i]]
    cls <- if (r$is_focal) ' class="pfo-deep-focal"' else ""
    sprintf(
      paste0('<tr%s><td>#%d %s</td>',
             '<td class="pfo-td-num">%s</td>',
             '<td class="pfo-td-num">%s</td>',
             '<td class="pfo-td-num">%s</td>',
             '<td class="pfo-td-num">%s</td>',
             '<td class="pfo-td-num">%s</td></tr>'),
      cls, i, .pf_esc(r$name),
      fmt_pct0(r$aware),
      fmt_pct0(r$mpen),
      fmt_pct1(r$mms),
      fmt_pct0(r$vol),
      fmt_pct0(r$pen)
    )
  }, character(1)), collapse = "")

  focal_rank <- which(vapply(rows, function(r) r$is_focal, logical(1)))
  focal_rank_txt <- if (length(focal_rank) == 1) sprintf("#%d", focal_rank) else "Not top 5"

  # Base annotation. Three bases in one card \u2014 spell them out so readers
  # don't read the gap as a calculation error.
  cat_buyer_n <- c$n_buyers_uw %||% NA_integer_
  base_line <- if (!is.null(cat_buyer_n) && is.finite(cat_buyer_n) && cat_buyer_n > 0)
    sprintf("Broad awareness: %s category buyers (Portfolio engine base) &middot; MPen / MMS / Volume share / %% bought / Loyalty: focal-cat deep-dive sample",
            format(cat_buyer_n, big.mark = ","))
  else "Broad awareness uses category-buyer base; MPen / MMS / Volume share / % bought / Loyalty use the focal-cat deep-dive sample."

  focal_aware_val <- c$awareness_pct[[focal_brand]] %||% NA_real_

  sprintf(
    paste0('<div class="pfo-deep-card">',
           '<div class="pfo-deep-card-head"><span class="pfo-deep-card-title">%s</span>',
           '<span class="pfo-deep-card-rank">Focal: %s by awareness</span></div>',
           '<div class="pfo-deep-card-kpis">',
             '<div><span class="pfo-kpi-mini-v">%s</span><span class="pfo-kpi-mini-l">Broad awareness</span></div>',
             '<div><span class="pfo-kpi-mini-v">%s</span><span class="pfo-kpi-mini-l">MPen (deep-dive)</span></div>',
             '<div><span class="pfo-kpi-mini-v">%s</span><span class="pfo-kpi-mini-l">MMS</span></div>',
             '<div><span class="pfo-kpi-mini-v">%s</span><span class="pfo-kpi-mini-l">%% who bought</span></div>',
             '<div><span class="pfo-kpi-mini-v">%s</span><span class="pfo-kpi-mini-l">Volume share</span></div>',
             '<div><span class="pfo-kpi-mini-v">%s</span><span class="pfo-kpi-mini-l">Loyalty (SCR)</span></div>',
           '</div>',
           '<table class="pfo-deep-rank"><thead><tr>',
             '<th>Brand</th>',
             '<th class="pfo-td-num">Broad aware</th>',
             '<th class="pfo-td-num">MPen</th>',
             '<th class="pfo-td-num">MMS</th>',
             '<th class="pfo-td-num">Volume share</th>',
             '<th class="pfo-td-num">%% who bought</th>',
           '</tr></thead><tbody>%s</tbody></table>',
           '<p class="pfo-deep-card-base-note" style="font-size:10px;color:#94a3b8;margin:6px 0 0;line-height:1.4;">%s</p>',
           '</div>'),
    .pf_esc(c$cat_name), .pf_esc(focal_rank_txt),
    fmt_pct0(focal_aware_val),
    fmt_pct0(focal_dd$mpen_pct        %||% NA_real_),
    fmt_pct1(focal_dd$mms_pct         %||% NA_real_),
    fmt_pct0(focal_dd$penetration_pct %||% NA_real_),
    fmt_pct0(focal_dd$vol_share_pct   %||% NA_real_),
    fmt_pct0(focal_dd$scr_pct         %||% NA_real_),
    rank_body,
    base_line
  )
}
