# ==============================================================================
# BRAND MODULE - AUDIENCE LENS PANEL HTML RENDERER
# ==============================================================================
# Renders the per-category Audience Lens tab. Three internal sub-tabs:
#   1) Banner       — total + every audience side-by-side, all 14 metrics
#   2) Audiences    — per-audience deck-ready cards (single-audience scorecards)
#   3) Pairs        — pair audience side-by-side cards with GROW/FIX/DEFEND
#
# Each card carries a per-card pin + PNG button (brand_pins.js shared toolbar).
# All CSS uses portable selectors with !important on layout-critical rules so
# the TurasPins inliner can reproduce the cards in pinned + PNG output.
#
# VERSION: 1.0
# ==============================================================================

BRAND_AUDIENCE_LENS_PANEL_VERSION <- "1.0"


#' Build audience-lens panel HTML
#'
#' @param panel_data List from \code{build_audience_lens_panel_data()}.
#' @param category_code Character. Used to scope element ids on the page.
#' @param focal_colour Character. Hex colour for focal accents.
#' @return Character. Single HTML fragment.
#' @export
build_audience_lens_panel_html <- function(panel_data,
                                            category_code = "cat",
                                            focal_colour = "#1A5276") {
  if (is.null(panel_data) ||
      length(panel_data$cards %||% list()) == 0) {
    return('<div class="al-panel-empty" style="padding:32px;text-align:center;color:#94a3b8;font-size:14px;">No audiences configured for this category. Set <code>AudienceLens_Use</code> on the Categories sheet and add rows to the AudienceLens sheet of Survey_Structure.xlsx.</div>')
  }

  panel_id     <- paste0("al-panel-", category_code)
  json_payload <- .al_panel_json(panel_data, focal_colour)

  paste0(
    sprintf(
      '<div class="al-panel" id="%s" data-cat-code="%s" data-focal-colour="%s">',
      panel_id, .al_esc(category_code), .al_esc(focal_colour)),
    sprintf('<script type="application/json" class="al-panel-data">%s</script>',
            json_payload),
    .al_panel_subnav(category_code),
    .al_panel_subtab_banner(panel_data, category_code, focal_colour),
    .al_panel_subtab_audiences(panel_data, category_code, focal_colour),
    .al_panel_subtab_pairs(panel_data, category_code, focal_colour),
    .al_panel_insight_box(),
    '</div>'
  )
}


# ==============================================================================
# SUB-TAB NAV
# ==============================================================================

.al_panel_subnav <- function(cat_code) {
  tabs <- list(
    list(key = "banner",    label = "Banner table"),
    list(key = "audiences", label = "Per-audience cards"),
    list(key = "pairs",     label = "Pair scorecards")
  )
  btns <- paste(vapply(tabs, function(t) {
    active <- if (identical(t$key, "banner")) " active" else ""
    sprintf(
      '<button type="button" class="al-subtab-btn%s" data-al-tab="%s">%s</button>',
      active, t$key, .al_esc(t$label))
  }, character(1)), collapse = "")
  sprintf('<nav class="al-subnav" data-al-scope="%s">%s</nav>',
          .al_esc(cat_code), btns)
}


# ==============================================================================
# BANNER TABLE
# ==============================================================================

.al_panel_subtab_banner <- function(pd, cat_code, focal_colour) {
  total <- pd$total
  audiences <- pd$cards   # one card per rendered audience (in declared order)

  # Build header rows: a "PAIR" bracket above pair members, then the audience
  # name + base size row.
  pair_header <- .al_banner_pair_header_row(audiences)
  ah_row <- .al_banner_audience_header_row(total, audiences)
  base_row <- .al_banner_base_size_row(total, audiences)

  body_rows <- character(0)
  for (group in pd$banner_groups) {
    body_rows <- c(body_rows, sprintf(
      '<tr class="al-banner-group-row"><td colspan="%d" class="al-banner-group-cell">%s</td></tr>',
      length(audiences) + 2L, .al_esc(group$group)))
    for (row in group$rows) {
      cells <- vapply(seq_along(row$cells), function(i) {
        cell <- row$cells[[i]]
        au <- audiences[[i]]
        cls <- .al_banner_cell_class(cell, au)
        sprintf('<td class="al-banner-cell %s" title="n=%s">%s</td>',
                cls,
                if (cell$buyer_base_na) "—" else
                  format(cell$n_base, big.mark = ","),
                .al_esc(cell$formatted))
      }, character(1))
      body_rows <- c(body_rows, sprintf(
        '<tr class="al-banner-data-row"><th class="al-banner-metric-label">%s</th><td class="al-banner-cell al-banner-total-cell">%s</td>%s</tr>',
        .al_esc(row$metric_label),
        .al_esc(row$total$formatted),
        paste(cells, collapse = "")))
    }
  }

  thead <- paste(c(
    if (nzchar(pair_header)) sprintf('<tr class="al-banner-pair-row">%s</tr>', pair_header),
    sprintf('<tr class="al-banner-aud-row">%s</tr>', ah_row),
    sprintf('<tr class="al-banner-base-row">%s</tr>', base_row)
  ), collapse = "")

  section_id <- .al_section_id(cat_code, "banner")
  sprintf(
    '<section class="al-subtab al-subtab-active" data-al-tab="banner">
       <header class="al-subtab-header">
         <p class="al-blurb">Focal brand performance across %d audience(s). Sig at %d%% within pair shown via a/b superscripts; vs Total via c. †: brand-buyer-base metrics are N/A on the non-buyer side.</p>
       </header>
       <article class="al-banner-card al-card-section" id="section-%s" data-section="%s">
         <div class="al-banner-card-titlebar">
           <h3 class="al-banner-card-title al-card-title">Audience banner — %s</h3>
           %s
         </div>
         <div class="al-banner-table-wrap" data-pin-as-table>
           <table class="al-banner-table">
             <thead>%s</thead>
             <tbody>%s</tbody>
           </table>
         </div>
         <div class="al-banner-foot">%s</div>
       </article>
     </section>',
    length(audiences),
    as.integer(round(100 * (1 - (pd$meta$thresholds$alpha %||% 0.10)))),
    .al_esc(section_id), .al_esc(section_id),
    .al_esc(pd$meta$category_label %||% pd$meta$cat_code %||% ""),
    .al_card_toolbar(section_id),
    thead, paste(body_rows, collapse = ""),
    .al_banner_footnote(audiences))
}


.al_banner_pair_header_row <- function(audiences) {
  pids <- vapply(audiences, function(a) a$audience$pair_id %||% "", character(1))
  any_pair <- any(nzchar(pids))
  if (!any_pair) return("")
  cells <- character(0)
  cells <- c(cells, '<th class="al-banner-pair-blank"></th>')   # metric col
  cells <- c(cells, '<th class="al-banner-pair-blank"></th>')   # total col

  i <- 1
  while (i <= length(audiences)) {
    pid <- pids[i]
    if (nzchar(pid)) {
      # Find run-length of this pair id
      end <- i
      while (end < length(audiences) && pids[end + 1L] == pid) end <- end + 1L
      span <- end - i + 1L
      cells <- c(cells, sprintf(
        '<th class="al-banner-pair-bracket" colspan="%d">PAIR · %s</th>',
        span, .al_esc(pid)))
      i <- end + 1L
    } else {
      cells <- c(cells, '<th class="al-banner-pair-blank"></th>')
      i <- i + 1L
    }
  }
  paste(cells, collapse = "")
}


.al_banner_audience_header_row <- function(total, audiences) {
  cells <- '<th class="al-banner-metric-h"></th>'
  cells <- c(cells, '<th class="al-banner-aud-h al-banner-total-h">Total</th>')
  cells <- c(cells, vapply(audiences, function(a) {
    sprintf('<th class="al-banner-aud-h" data-pair-role="%s">%s</th>',
            .al_esc(a$audience$pair_role %||% ""),
            .al_esc(a$audience$label))
  }, character(1)))
  paste(cells, collapse = "")
}


.al_banner_base_size_row <- function(total, audiences) {
  cells <- '<td class="al-banner-base-blank"></td>'
  cells <- c(cells, sprintf('<td class="al-banner-base">n=%s</td>',
                             format(total$n_unweighted, big.mark = ",")))
  cells <- c(cells, vapply(audiences, function(a) {
    badge <- if (identical(a$base_state, "low_base"))
      ' <span class="al-low-base-badge" title="Low base">low base</span>' else ""
    sprintf('<td class="al-banner-base">n=%s%s</td>',
            format(a$n_unweighted, big.mark = ","),
            badge)
  }, character(1)))
  paste(cells, collapse = "")
}


.al_banner_cell_class <- function(cell, audience) {
  classes <- character(0)
  if (isTRUE(cell$buyer_base_na)) classes <- c(classes, "al-cell-na")
  if (identical(audience$base_state, "low_base"))
    classes <- c(classes, "al-cell-low-base")
  if (!is.null(cell$delta_vs_total) && !is.na(cell$delta_vs_total) &&
      cell$delta_vs_total > 0)
    classes <- c(classes, "al-cell-positive")
  if (!is.null(cell$delta_vs_total) && !is.na(cell$delta_vs_total) &&
      cell$delta_vs_total < 0)
    classes <- c(classes, "al-cell-negative")
  paste(classes, collapse = " ")
}


.al_banner_footnote <- function(audiences) {
  any_buyer_base <- any(vapply(audiences, function(a) {
    any(vapply(a$rows, function(r) isTRUE(r$buyer_base_na), logical(1)))
  }, logical(1)))
  if (!any_buyer_base) return("")
  '<p class="al-banner-footnote">† Loyalty / Purchase distribution / Purchase frequency are defined on focal-brand buyers only. They are N/A on the non-buyer side of pair audiences by definition.</p>'
}


# ==============================================================================
# PER-AUDIENCE CARDS
# ==============================================================================

.al_panel_subtab_audiences <- function(pd, cat_code, focal_colour) {
  cards <- paste(vapply(pd$cards, function(c) {
    .al_audience_card(c, pd$meta, cat_code, focal_colour)
  }, character(1)), collapse = "")

  sprintf(
    '<section class="al-subtab" data-al-tab="audiences" hidden>
       <header class="al-subtab-header">
         <p class="al-blurb">Each audience as a deck-ready card: focal brand value vs total per metric. Click pin or PNG to capture for slides.</p>
       </header>
       <div class="al-card-grid">%s</div>
     </section>', cards)
}


.al_audience_card <- function(card, meta, cat_code, focal_colour) {
  section_id <- .al_section_id(cat_code, paste0("aud-", card$audience$id))

  base_lbl <- sprintf("Base: n=%s%s", format(card$n_unweighted, big.mark = ","),
                       if (identical(card$base_state, "low_base"))
                         " · low base" else "")

  rows <- paste(vapply(card$rows, function(r) {
    if (isTRUE(r$buyer_base_na)) {
      sprintf(
        '<tr class="al-audrow al-audrow-na"><td class="al-audrow-label">%s</td><td class="al-audrow-val">N/A †</td><td class="al-audrow-delta">—</td></tr>',
        .al_esc(r$metric_label))
    } else {
      sprintf(
        '<tr class="al-audrow"><td class="al-audrow-label">%s</td><td class="al-audrow-val">%s</td><td class="al-audrow-delta %s">%s</td></tr>',
        .al_esc(r$metric_label), .al_esc(r$value_formatted),
        if (!is.na(r$delta_vs_total) && r$delta_vs_total > 0) "al-delta-pos" else
          if (!is.na(r$delta_vs_total) && r$delta_vs_total < 0) "al-delta-neg" else "",
        .al_esc(r$delta_formatted))
    }
  }, character(1)), collapse = "")

  pair_label <- if (!is.null(card$audience$pair_id) &&
                      nzchar(card$audience$pair_id))
    sprintf(' <span class="al-aud-pair-tag">PAIR · %s · %s</span>',
            .al_esc(card$audience$pair_id),
            .al_esc(card$audience$pair_role %||% "")) else ""

  sprintf(
    '<article class="al-card al-card-section" id="section-%s" data-section="%s" data-aud-id="%s">
       <header class="al-card-header">
         <div class="al-card-titlebar">
           <h3 class="al-card-title">%s among %s%s</h3>
           %s
         </div>
         <div class="al-card-sub">%s</div>
       </header>
       <div class="al-card-body" data-pin-as-table>
         <table class="al-card-table">
           <thead><tr><th>Metric</th><th>%s</th><th>vs Total</th></tr></thead>
           <tbody>%s</tbody>
         </table>
       </div>
       <footer class="al-card-foot">Source: %s%s</footer>
     </article>',
    .al_esc(section_id), .al_esc(section_id), .al_esc(card$audience$id),
    .al_esc(meta$focal_brand %||% ""),
    .al_esc(card$audience$label),
    pair_label,
    .al_card_toolbar(section_id),
    .al_esc(base_lbl),
    .al_esc(meta$category_label %||% ""),
    rows,
    .al_esc(meta$category_label %||% ""),
    if (nzchar(meta$wave_label %||% ""))
      sprintf(" · Wave %s", .al_esc(meta$wave_label)) else "")
}


# ==============================================================================
# PAIR SCORECARDS
# ==============================================================================

.al_panel_subtab_pairs <- function(pd, cat_code, focal_colour) {
  if (length(pd$pair_cards %||% list()) == 0) {
    return('<section class="al-subtab" data-al-tab="pairs" hidden><div class="al-empty">No pair audiences declared for this category. Add a PairID + PairRole on the AudienceLens sheet to compare two cohorts side-by-side.</div></section>')
  }

  cards <- paste(vapply(pd$pair_cards, function(pc) {
    if (is.null(pc)) return("")
    .al_pair_card(pc, pd$meta, cat_code, focal_colour)
  }, character(1)), collapse = "")

  sprintf(
    '<section class="al-subtab" data-al-tab="pairs" hidden>
       <header class="al-subtab-header">
         <p class="al-blurb">Each pair compares two audiences side-by-side. Chips: <span class="al-chip al-chip-grow">GROW</span> recruitment lever · <span class="al-chip al-chip-fix">FIX</span> retention risk · <span class="al-chip al-chip-defend">DEFEND</span> own buyers lead AND focal leads category. †: brand-buyer-base metric, N/A on non-buyer side.</p>
       </header>
       <div class="al-pair-grid">%s</div>
     </section>', cards)
}


.al_pair_card <- function(pc, meta, cat_code, focal_colour) {
  section_id <- .al_section_id(cat_code, paste0("pair-", pc$pair_id))

  body_rows <- paste(vapply(seq_len(nrow(pc$rows)), function(i) {
    r <- pc$rows[i, , drop = FALSE]
    chip <- .al_render_chip(as.character(r$chip), as.character(r$chip_reason))
    sprintf(
      '<tr class="al-pair-row al-pair-row-%s%s"><td class="al-pair-metric">%s</td><td class="al-pair-total">%s</td><td class="al-pair-a">%s</td><td class="al-pair-b">%s</td><td class="al-pair-delta">%s</td><td class="al-pair-chip-cell">%s</td></tr>',
      .al_esc(r$chip_class),
      if (isTRUE(r$buyer_base)) " al-pair-row-na" else "",
      .al_esc(r$metric_label),
      .al_esc(r$value_total_fmt),
      .al_esc(r$value_a_fmt),
      .al_esc(r$value_b_fmt),
      .al_esc(r$delta_fmt),
      chip)
  }, character(1)), collapse = "")

  base_lbl <- sprintf("Base: n=%s %s / n=%s %s",
                       format(pc$n_a, big.mark = ","), .al_esc(pc$label_a),
                       format(pc$n_b, big.mark = ","), .al_esc(pc$label_b))

  insight <- pc$auto_insight %||% ""

  sprintf(
    '<article class="al-pair-card al-card-section" id="section-%s" data-section="%s" data-pair-id="%s">
       <header class="al-card-header">
         <div class="al-card-titlebar">
           <h3 class="al-card-title">%s vs %s — %s</h3>
           %s
         </div>
         <div class="al-card-sub">%s</div>
       </header>
       %s
       <div class="al-card-body" data-pin-as-table>
         <table class="al-pair-table">
           <thead><tr><th>Metric</th><th>Total</th><th>%s</th><th>%s</th><th>Δ</th><th>Chip</th></tr></thead>
           <tbody>%s</tbody>
         </table>
       </div>
       <footer class="al-card-foot">Source: %s%s</footer>
     </article>',
    .al_esc(section_id), .al_esc(section_id), .al_esc(pc$pair_id),
    .al_esc(pc$label_a), .al_esc(pc$label_b),
    .al_esc(meta$focal_brand %||% ""),
    .al_card_toolbar(section_id),
    base_lbl,
    if (nzchar(insight))
      sprintf('<aside class="al-pair-insight"><p>%s</p></aside>',
              .al_esc(insight)) else "",
    .al_esc(pc$label_a), .al_esc(pc$label_b),
    body_rows,
    .al_esc(meta$category_label %||% ""),
    if (nzchar(meta$wave_label %||% ""))
      sprintf(" · Wave %s", .al_esc(meta$wave_label)) else "")
}


.al_render_chip <- function(chip, reason) {
  if (is.na(chip) || !nzchar(chip) || identical(toupper(chip), "NONE")) {
    return('<span class="al-chip al-chip-none">—</span>')
  }
  cls <- paste0("al-chip al-chip-", tolower(chip))
  sprintf('<span class="%s" title="%s">%s</span>',
          cls, .al_esc(reason %||% ""), .al_esc(chip))
}


# ==============================================================================
# INSIGHT BOX (free-form note for the analyst, captured by pin)
# ==============================================================================

.al_panel_insight_box <- function() {
  '<section class="al-insight-box ma-insight-box" data-al-stim="audience-lens">
     <div class="ma-insight-box-header">
       <span class="ma-insight-box-title">Insight</span>
       <button type="button" class="ma-insight-box-clear" data-al-action="clear-insight" title="Clear">&#215;</button>
     </div>
     <textarea class="ma-insight-box-text" placeholder="Write the headline for this audience tab (one or two sentences)…"></textarea>
   </section>'
}


# ==============================================================================
# Per-card pin + PNG toolbar (mirrors branded-reach pattern; relies on
# brand_pins.js window.brTogglePin / window.brExportPng)
# ==============================================================================

.al_card_toolbar <- function(section_id) {
  sprintf(
    '<div class="al-card-toolbar" data-section="%s">
       <button class="br-pin-btn al-card-pin" data-section="%s" onclick="brTogglePin(\'%s\')" title="Pin this card">&#x1F4CC;</button>
       <button class="br-png-btn al-card-png" onclick="brExportPng(\'%s\',this)" title="Export PNG">&#x1F5BC;</button>
     </div>',
    .al_esc(section_id), .al_esc(section_id),
    .al_esc(section_id), .al_esc(section_id))
}


# ==============================================================================
# CSS — portable selectors with !important on layout-critical rules so the
# TurasPins inliner can reproduce cards in pin / PNG output.
# ==============================================================================

#' Build audience-lens panel CSS
#' @param focal_colour Character. Hex colour for focal accents.
#' @return Character. CSS string (no <style> tags).
#' @export
build_audience_lens_panel_styles <- function(focal_colour = "#1A5276") {
  template <- '
.al-panel { font: 13px/1.45 system-ui, -apple-system, Segoe UI, sans-serif; color: #1e293b; }
.al-panel-empty { font-style: italic; }

.al-subnav { display:flex; gap:6px; margin: 4px 0 16px; border-bottom: 1px solid #e2e8f0; padding-bottom: 6px; }
.al-subtab-btn { background:none; border:1px solid transparent; padding:6px 12px; border-radius:6px; cursor:pointer; font-size:12px; color:#64748b; }
.al-subtab-btn:hover { background:#f1f5f9; }
.al-subtab-btn.active { background: __FOCAL__; color:#fff; border-color: __FOCAL__; }

.al-subtab { padding-top: 4px; }
.al-subtab[hidden] { display: none !important; }
.al-subtab-header { margin-bottom: 12px; }
.al-blurb { font-size:12px; color:#64748b; margin: 0 0 14px; }
.al-empty { padding:24px; text-align:center; color:#94a3b8; font-style:italic; font-size:12px; }

/* === Banner table card =================================================== */
.al-banner-card, .al-card { background:#fff !important; border:1px solid #e2e8f0 !important; border-radius:10px !important; padding:14px !important; box-shadow: 0 1px 2px rgba(0,0,0,.03); position: relative; }
.al-banner-card-titlebar, .al-card-titlebar { display: flex !important; align-items: flex-start !important; justify-content: space-between !important; gap: 8px !important; margin-bottom: 8px !important; }
.al-banner-card-title, .al-card-title { font-weight: 600 !important; font-size: 14px !important; color:#0f172a !important; margin: 0 !important; line-height: 1.3 !important; text-transform: none !important; }
.al-card-sub { font-size: 11px; color:#64748b; margin-top: 4px; }
.al-card-foot { font-size: 11px; color:#94a3b8; margin-top: 10px; padding-top: 8px; border-top: 1px solid #f1f5f9; }

.al-banner-table-wrap { overflow-x: auto; margin-top: 8px; }
.al-banner-table { width: 100%; border-collapse: collapse; font-size: 12px; }
.al-banner-table th, .al-banner-table td { padding: 6px 10px; border-bottom: 1px solid #f1f5f9; text-align: left; vertical-align: middle; }

.al-banner-pair-row th { font-size: 9px; text-transform: uppercase; letter-spacing: .8px; font-weight: 600; color: #475569; padding: 4px 10px !important; border-bottom: 1px solid #cbd5e1 !important; text-align: center !important; }
.al-banner-pair-bracket { background: #f1f5f9 !important; border-left: 1px solid #cbd5e1 !important; border-right: 1px solid #cbd5e1 !important; }
.al-banner-pair-blank { border-bottom: none !important; }
.al-banner-aud-row th { font-weight: 600; font-size: 11px; color: #0f172a; text-transform: none; padding: 6px 10px; border-bottom: 1px solid #e2e8f0 !important; }
.al-banner-aud-row .al-banner-aud-h { text-align: right; }
.al-banner-aud-row .al-banner-total-h { background: #f8fafc; }

.al-banner-base-row td { font-size: 10px; color: #64748b; padding: 2px 10px 6px !important; text-align: right; border-bottom: 1px solid #e2e8f0 !important; }
.al-low-base-badge { display: inline-block; background: #fef3c7; color: #92400e; padding: 1px 6px; border-radius: 4px; font-size: 9px; margin-left: 4px; font-weight: 600; }

.al-banner-group-row td { background: __FOCAL__22 !important; font-size: 10px !important; font-weight: 700 !important; text-transform: uppercase !important; letter-spacing: .8px !important; color: __FOCAL__ !important; padding: 6px 10px !important; border-bottom: 1px solid __FOCAL__44 !important; }

.al-banner-data-row .al-banner-metric-label { font-weight: 500; color: #1e293b; padding-left: 18px !important; }
.al-banner-data-row .al-banner-cell { text-align: right; font-variant-numeric: tabular-nums; padding: 6px 10px; }
.al-banner-total-cell { background: #f8fafc; font-weight: 600; }
.al-cell-na { color: #cbd5e1 !important; font-style: italic !important; }
.al-cell-low-base { background: #fffbeb; }
.al-cell-positive { color: #166534; }
.al-cell-negative { color: #991b1b; }

.al-banner-footnote { font-size: 10px; color: #94a3b8; margin: 10px 0 0; font-style: italic; }
.al-banner-foot { margin-top: 10px; }

/* === Per-audience card =================================================== */
.al-card-grid, .al-pair-grid { display: grid !important; grid-template-columns: repeat(auto-fit, minmax(360px, 1fr)) !important; gap: 16px !important; }
.al-card-table, .al-pair-table { width: 100% !important; border-collapse: collapse !important; margin-top: 8px !important; font-size: 12px !important; }
.al-card-table th, .al-card-table td, .al-pair-table th, .al-pair-table td { padding: 5px 8px !important; border-bottom: 1px solid #f1f5f9 !important; text-align: left !important; vertical-align: middle !important; }
.al-card-table th, .al-pair-table th { font-weight: 600 !important; color:#64748b !important; font-size: 10px !important; text-transform: uppercase !important; letter-spacing:.4px !important; }
.al-audrow-label, .al-pair-metric { font-weight: 500; color: #1e293b; }
.al-audrow-val, .al-pair-total, .al-pair-a, .al-pair-b, .al-pair-delta { text-align: right !important; font-variant-numeric: tabular-nums !important; }
.al-audrow-na td { color: #cbd5e1 !important; font-style: italic !important; }
.al-delta-pos { color: #166534 !important; font-weight: 600 !important; }
.al-delta-neg { color: #991b1b !important; font-weight: 600 !important; }
.al-aud-pair-tag { display: inline-block; background: __FOCAL__15; color: __FOCAL__; padding: 1px 6px; border-radius: 4px; font-size: 9px; margin-left: 6px; font-weight: 600; letter-spacing: .5px; }

/* === Pair card =========================================================== */
.al-pair-card { background:#fff !important; border:1px solid __FOCAL__33 !important; border-radius:10px !important; padding:14px !important; box-shadow: 0 1px 4px rgba(0,0,0,.05); position: relative; }
.al-pair-insight { background: __FOCAL__15 !important; border-left: 3px solid __FOCAL__ !important; padding: 8px 12px !important; margin: 8px 0 4px !important; border-radius: 4px !important; }
.al-pair-insight p { margin: 0 !important; font-size: 12px !important; line-height: 1.45 !important; color: #0f172a !important; }
.al-pair-row-na td { color: #cbd5e1 !important; font-style: italic !important; }
.al-pair-chip-cell { text-align: center !important; }

.al-pair-row.al-pair-row-grow .al-pair-a { background: #dcfce780 !important; }
.al-pair-row.al-pair-row-fix  .al-pair-a { background: #fee2e280 !important; }
.al-pair-row.al-pair-row-defend .al-pair-a { background: #dbeafe80 !important; }

/* === Chips =============================================================== */
.al-chip { display:inline-block !important; padding: 2px 8px !important; border-radius: 12px !important; font-size: 10px !important; font-weight: 700 !important; letter-spacing: .5px !important; text-transform: uppercase !important; color: #fff !important; line-height: 1.4 !important; white-space: nowrap !important; }
.al-chip-grow   { background: #2C7A3D !important; }
.al-chip-fix    { background: #A8351F !important; }
.al-chip-defend { background: #0E3A8A !important; }
.al-chip-none   { background: transparent !important; color: #cbd5e1 !important; font-weight: 400 !important; }

/* === Per-card toolbar (pin / PNG) ======================================== */
.al-card-toolbar { display: flex !important; gap: 4px !important; flex-shrink: 0 !important; opacity: .35; transition: opacity .15s; }
.al-card:hover .al-card-toolbar,
.al-pair-card:hover .al-card-toolbar,
.al-banner-card:hover .al-card-toolbar,
.al-card-toolbar:focus-within { opacity: 1; }
.al-card-pin, .al-card-png {
  background:#fff; border:1px solid #e2e8f0; border-radius:6px; cursor:pointer;
  padding:3px 7px; font-size:13px; line-height:1; color:#64748b;
  transition: background-color .12s, border-color .12s, color .12s;
}
.al-card-pin:hover, .al-card-png:hover { background:#f1f5f9; border-color:#cbd5e1; color:#0f172a; }
.al-card-pin.pin-flash { background: __FOCAL__ !important; border-color: __FOCAL__ !important; color:#fff !important; }

/* === Insight box ========================================================= */
.al-insight-box { margin-top: 18px; }
'
  gsub("__FOCAL__", focal_colour, template, fixed = TRUE)
}


# ==============================================================================
# Helpers
# ==============================================================================

.al_section_id <- function(cat_code, suffix) {
  cat_id <- gsub("[^a-z0-9]", "-", tolower(as.character(cat_code %||% "cat")))
  sfx    <- gsub("[^a-z0-9]", "-", tolower(as.character(suffix %||% "")))
  sprintf("al-%s-%s", cat_id, sfx)
}


.al_panel_json <- function(pd, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  # v1: keep the payload minimal (schema + meta only). The full panel data
  # is server-rendered into the DOM, so duplicating it as JSON wastes bytes
  # without any consumer. v2 will populate the full payload here when
  # client-side re-render lands (comparator brand, wave-on-wave trend).
  payload <- list(
    schema_version = pd$schema_version,
    meta           = pd$meta,
    focal_colour   = focal_colour
  )
  jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null",
                   pretty = FALSE, digits = 6)
}


.al_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
