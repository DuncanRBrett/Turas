# ==============================================================================
# BRAND MODULE - PORTFOLIO OVERVIEW SUBTAB: TABLE PARTS
# ==============================================================================
# Helpers kept in a separate file to keep the main subtab renderer
# (09_portfolio_overview_subtab.R) under the 300-line active-line limit.
#
# Exports: pfo_render_table().
#
# History: a pfo_render_deep_strip() helper used to live here, emitting a
# "Deep-dive competitive context" 4-card grid below the table. It was
# removed 2026-05-24 because the cards mixed broad awareness (full sample)
# with MPen / MMS / SCR / vol share / % bought (focal-cat deep-dive
# sample) inside one card with no visual base signal. The per-category
# Footprint sub-tab carries the deep-dive metrics against a clean base.
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


# Deep-dive cards renderer removed 2026-05-24. The 4-card "Deep-dive
# competitive context" grid was retired because it mixed bases (broad
# awareness on full sample; MPen / MMS / SCR / vol share / % bought on
# the focal-cat deep-dive sample) inside one card with no visual signal,
# encouraging unreconcilable comparisons. The per-category Footprint
# sub-tab carries the same metrics against a clean base. See git
# history (commit removing pfo_render_deep_strip) for the original
# implementation if it ever needs to be revived.
