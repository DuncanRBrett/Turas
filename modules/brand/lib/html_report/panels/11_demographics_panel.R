# ==============================================================================
# BRAND MODULE - DEMOGRAPHICS PANEL HTML RENDERER
# ==============================================================================
# Emits the Demographics tab's HTML fragment. Layout:
#
#   [Header card with question chips: toggle each question on/off]
#   [Sub-tab nav]: Total | Buyer vs non-buyer | Light/Med/Heavy buyer | By brand
#   [Per-question card]:
#     - Question label
#     - Chart (horizontal bar showing the active distribution)
#     - Heatmap-style table (option x cut), with optional CI overlay
#     - Per-card pin + PNG buttons
#
# All panel state lives in the JSON payload at <script class="demo-panel-data">.
# Interactions (sub-tab switch, question show/hide, brand picker, CI toggle,
# heatmap re-render) are handled by brand_demographics_panel.js.
#
# VERSION: 1.0
# ==============================================================================

BRAND_DEMOGRAPHICS_PANEL_VERSION <- "1.0"


#' Build demographics panel HTML
#'
#' @param panel_data List from \code{build_demographics_panel_data()}.
#' @param panel_id Character. Element id (e.g. "demo-panel"). Used to scope
#'   sub-element ids and JS dispatch.
#' @param focal_colour Character. Hex colour for focal-brand highlights.
#' @return Character. Single HTML fragment.
#' @export
build_demographics_panel_html <- function(panel_data,
                                           panel_id = "demo-panel",
                                           focal_colour = "#1A5276") {

  if (is.null(panel_data) ||
      identical(panel_data$meta$status %||% "", "REFUSED") ||
      identical(panel_data$meta$status %||% "", "EMPTY") ||
      length(panel_data$questions) == 0L) {
    return(.demo_panel_empty_state(panel_data))
  }

  panel_id     <- gsub("[^A-Za-z0-9_-]", "-", panel_id)
  json_payload <- .demo_panel_json(panel_data, focal_colour)

  paste0(
    sprintf(
      '<div class="demo-panel" id="%s" data-focal-colour="%s">',
      panel_id, .demo_esc(focal_colour)),
    sprintf('<script type="application/json" class="demo-panel-data">%s</script>',
            json_payload),
    .demo_panel_header(panel_data),
    .demo_panel_chip_row(panel_data, panel_id),
    .demo_panel_subnav(panel_data, panel_id),
    .demo_panel_question_grid(panel_data, panel_id, focal_colour),
    .demo_panel_insight_box(),
    '</div>'
  )
}


# ==============================================================================
# EMPTY STATE
# ==============================================================================

.demo_panel_empty_state <- function(pd) {
  msg <- (pd$meta$message) %||%
         "No demographic questions configured. Add demo.* roles to the QuestionMap sheet in Survey_Structure.xlsx."
  sprintf(
    '<div class="demo-panel-empty" style="padding:32px;text-align:center;color:#94a3b8;font-size:14px;">%s</div>',
    .demo_esc(msg))
}


# ==============================================================================
# HEADER + QUESTION CHIPS
# ==============================================================================

.demo_panel_header <- function(pd) {
  scope_lbl <- pd$meta$scope_label %||% "Total sample"
  n_total   <- pd$meta$n_total
  base_lbl  <- if (!is.null(n_total) && !is.na(n_total))
    sprintf("Base: n = %s", format(n_total, big.mark = ","))
  else "Base: full respondent set"
  sprintf(
    '<header class="demo-panel-header">
       <div class="demo-panel-header-title">Demographics &mdash; %s</div>
       <div class="demo-panel-header-sub">%s &middot; %d question%s</div>
     </header>',
    .demo_esc(scope_lbl), .demo_esc(base_lbl),
    pd$meta$n_questions %||% length(pd$questions),
    if ((pd$meta$n_questions %||% 0L) == 1L) "" else "s")
}


.demo_panel_chip_row <- function(pd, panel_id) {
  chips <- vapply(seq_along(pd$questions), function(i) {
    q <- pd$questions[[i]]
    label <- q$short_label %||% q$question_text %||% q$role
    sprintf(
      '<button type="button" class="demo-q-chip active" data-demo-q-idx="%d" title="%s">%s</button>',
      i - 1L, .demo_esc(q$question_text %||% label), .demo_esc(label))
  }, character(1L))
  paste0(
    '<div class="demo-chip-row">',
    '<span class="demo-chip-row-label">Show:</span>',
    paste(chips, collapse = ""),
    '</div>'
  )
}


# ==============================================================================
# SUB-TAB NAV (Total | Buyer cut | Tier cut | By brand)
# ==============================================================================
# Sub-tabs are advisory: the per-question card already shows the relevant
# table for the active sub-tab. Tabs that have no data (e.g. tier_cut when
# buyer-heaviness wasn't computed) render disabled rather than missing —
# the user always sees the same nav layout across studies.

.demo_panel_subnav <- function(pd, panel_id) {
  has_buyer <- any(vapply(pd$questions,
    function(q) !is.null(q$buyer_cut), logical(1L)))
  has_tier  <- any(vapply(pd$questions,
    function(q) !is.null(q$tier_cut),  logical(1L)))
  has_brand <- any(vapply(pd$questions,
    function(q) length(q$brand_cut) > 0L, logical(1L)))

  tabs <- list(
    list(key = "total", label = "Total",                enabled = TRUE),
    list(key = "buyer", label = "Buyer vs non-buyer",   enabled = has_buyer),
    list(key = "tier",  label = "Light / Medium / Heavy", enabled = has_tier),
    list(key = "brand", label = "By brand",             enabled = has_brand)
  )
  btns <- vapply(tabs, function(t) {
    cls <- "demo-subtab-btn"
    if (t$key == "total") cls <- paste(cls, "active")
    if (!t$enabled)       cls <- paste(cls, "disabled")
    sprintf(
      '<button type="button" class="%s" data-demo-tab="%s"%s>%s</button>',
      cls, t$key,
      if (!t$enabled) ' disabled aria-disabled="true"' else "",
      .demo_esc(t$label))
  }, character(1L))
  sprintf('<nav class="demo-subnav" data-scope="%s">%s</nav>',
          .demo_esc(panel_id), paste(btns, collapse = ""))
}


# ==============================================================================
# QUESTION CARD GRID
# ==============================================================================

.demo_panel_question_grid <- function(pd, panel_id, focal_colour) {
  cards <- vapply(seq_along(pd$questions), function(i) {
    .demo_panel_question_card(pd$questions[[i]], i - 1L, panel_id,
                               focal_colour, pd)
  }, character(1L))
  sprintf('<div class="demo-card-grid">%s</div>', paste(cards, collapse = ""))
}


.demo_panel_question_card <- function(q, idx, panel_id, focal_colour, pd) {
  section_id <- sprintf("section-%s-q%d", panel_id, idx)
  brand_picker <- .demo_panel_brand_picker(pd, panel_id, idx)

  # Initial body uses the Total distribution (a horizontal bar chart + table).
  # Subsequent renders are JS-driven from the JSON payload.
  body <- .demo_panel_total_body(q, focal_colour, pd$config$decimal_places %||% 0L)

  sprintf(
    '<article class="demo-card br-element-section" id="%s" data-section="%s" data-demo-q-idx="%d">
       <header class="demo-card-header">
         <div class="demo-card-titlebar">
           <h3 class="demo-card-title br-element-title">%s</h3>
           %s
         </div>
         <div class="demo-card-sub">%s &middot; n = %s</div>
       </header>
       %s
       <div class="demo-card-body" data-pin-as-table>
         %s
       </div>
     </article>',
    .demo_esc(section_id), .demo_esc(section_id), idx,
    .demo_esc(q$short_label %||% q$question_text),
    .demo_panel_card_toolbar(section_id),
    .demo_esc(q$question_text %||% ""),
    .demo_int(q$n_total),
    brand_picker,
    body)
}


.demo_panel_total_body <- function(q, focal_colour, dp) {
  rows <- q$total$rows %||% list()
  if (length(rows) == 0L) {
    return('<div class="demo-empty">No responses for this question.</div>')
  }
  max_pct <- max(vapply(rows, function(r) r$pct %||% 0, numeric(1L)), na.rm = TRUE)
  if (!is.finite(max_pct) || max_pct <= 0) max_pct <- 1
  bars <- vapply(rows, function(r) {
    pct      <- r$pct %||% NA_real_
    bar_w    <- if (is.finite(pct)) max(2, 100 * pct / max_pct) else 0
    pct_disp <- .demo_pct(pct, dp)
    ci_lo    <- .demo_pct(r$ci_lower %||% NA_real_, dp)
    ci_hi    <- .demo_pct(r$ci_upper %||% NA_real_, dp)
    sprintf(
      '<tr>
         <td class="demo-row-label">%s</td>
         <td class="demo-row-bar"><div class="demo-row-bar-fill" style="width:%.1f%%;background-color:%s"></div></td>
         <td class="demo-row-pct">%s</td>
         <td class="demo-row-ci" data-ci-text="%s &ndash; %s">[%s &ndash; %s]</td>
         <td class="demo-row-n">%s</td>
       </tr>',
      .demo_esc(r$label %||% r$code), bar_w, .demo_esc(focal_colour),
      pct_disp, ci_lo, ci_hi, ci_lo, ci_hi, .demo_int(r$n))
  }, character(1L))
  sprintf(
    '<table class="demo-table demo-table-total">
       <thead><tr>
         <th>Option</th><th></th><th>%%</th><th class="demo-ci-col">95%% CI</th><th>n</th>
       </tr></thead>
       <tbody>%s</tbody>
     </table>',
    paste(bars, collapse = ""))
}


# ==============================================================================
# BRAND PICKER (per-card, only when brand_cut is available)
# ==============================================================================
# A small chip strip lets the user select which brand's distribution shows
# in the "By brand" sub-tab. Hidden until the brand sub-tab is active.

.demo_panel_brand_picker <- function(pd, panel_id, idx) {
  bcs <- pd$brands$codes  %||% character(0)
  bls <- pd$brands$labels %||% bcs
  if (length(bcs) == 0L) return("")
  focal <- pd$meta$focal_brand %||% ""
  if (focal %in% bcs) {
    bcs <- c(focal, setdiff(bcs, focal))
    bls <- bls[match(bcs, pd$brands$codes)]
  }
  chips <- vapply(seq_along(bcs), function(i) {
    active <- if (i == 1L) " active" else ""
    sprintf('<button type="button" class="demo-brand-chip%s" data-demo-brand="%s">%s</button>',
            active, .demo_esc(bcs[i]), .demo_esc(bls[i]))
  }, character(1L))
  sprintf(
    '<div class="demo-brand-picker" hidden data-demo-q-idx="%d">
       <span class="demo-brand-picker-label">Brand:</span>
       %s
     </div>', idx, paste(chips, collapse = ""))
}


# ==============================================================================
# CARD TOOLBAR (pin + PNG)
# ==============================================================================

.demo_panel_card_toolbar <- function(section_id) {
  sprintf(
    '<div class="demo-card-toolbar" data-section="%s">
       <button type="button" class="br-pin-btn demo-card-pin" data-section="%s" onclick="brTogglePin(\'%s\')" title="Pin this card">&#x1F4CC;</button>
       <button type="button" class="br-png-btn demo-card-png" onclick="brExportPng(\'%s\',this)" title="Export PNG of this card">&#x1F5BC;</button>
       <button type="button" class="demo-ci-btn" data-section="%s" title="Toggle 95%% CI display">CI</button>
     </div>',
    .demo_esc(section_id), .demo_esc(section_id),
    .demo_esc(section_id), .demo_esc(section_id), .demo_esc(section_id))
}


# ==============================================================================
# INSIGHT BOX
# ==============================================================================

.demo_panel_insight_box <- function() {
  '<section class="demo-insight-box ma-insight-box">
     <div class="ma-insight-box-header">
       <span class="ma-insight-box-title">Insight</span>
       <button type="button" class="ma-insight-box-clear" data-demo-action="clear-insight" title="Clear">&#215;</button>
     </div>
     <textarea class="ma-insight-box-text" placeholder="Headline insight for the Demographics tab&hellip;"></textarea>
   </section>'
}


# ==============================================================================
# HELPERS (formatters + JSON + escape)
# ==============================================================================

.demo_pct <- function(v, dp) {
  if (is.null(v) || is.na(v) || !is.finite(v)) return('<span class="demo-na">&mdash;</span>')
  sprintf("%.*f%%", as.integer(dp), v)
}

.demo_int <- function(v) {
  if (is.null(v) || is.na(v) || !is.finite(v)) return("&mdash;")
  format(as.integer(round(v)), big.mark = ",")
}

.demo_panel_json <- function(pd, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  jsonlite::toJSON(pd, auto_unbox = TRUE, na = "null", null = "null",
                   pretty = FALSE, digits = 6)
}

.demo_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


# ==============================================================================
# CSS
# ==============================================================================

#' Build demographics panel CSS
#' @param focal_colour Character. Hex colour for focal accents.
#' @return Character. CSS string (no <style> tags).
#' @export
build_demographics_panel_styles <- function(focal_colour = "#1A5276") {
  template <- "
.demo-panel { font: 13px/1.45 system-ui, -apple-system, Segoe UI, sans-serif; color: #1e293b; }
.demo-panel-empty { font-style: italic; }

.demo-panel-header { margin: 4px 0 12px; padding: 12px 14px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; }
.demo-panel-header-title { font-weight: 600; font-size: 14px; color: #0f172a; }
.demo-panel-header-sub   { font-size: 11px; color: #64748b; margin-top: 2px; }

.demo-chip-row { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; margin: 6px 0 12px; }
.demo-chip-row-label { font-size: 11px; color: #64748b; margin-right: 4px; }
.demo-q-chip { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 14px; padding: 4px 10px; font-size: 11px; color: #475569; cursor: pointer; }
.demo-q-chip:hover { background: #f1f5f9; }
.demo-q-chip.active { background: __FOCAL__; color: #fff; border-color: __FOCAL__; }
.demo-q-chip:not(.active) { opacity: 0.55; }

.demo-subnav { display: flex; gap: 4px; margin: 4px 0 16px; border-bottom: 1px solid #e2e8f0; padding-bottom: 6px; }
.demo-subtab-btn { background: none; border: 1px solid transparent; padding: 6px 12px; border-radius: 6px; cursor: pointer; font-size: 12px; color: #64748b; }
.demo-subtab-btn:hover:not(.disabled) { background: #f1f5f9; }
.demo-subtab-btn.active { background: __FOCAL__; color: #fff; border-color: __FOCAL__; }
.demo-subtab-btn.disabled { color: #cbd5e1; cursor: not-allowed; opacity: 0.6; }

.demo-card-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(420px, 1fr)); gap: 16px; }
.demo-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 14px; box-shadow: 0 1px 2px rgba(0,0,0,.03); position: relative; }
.demo-card.hidden { display: none; }
.demo-card-header { margin-bottom: 10px; }
.demo-card-titlebar { display: flex; align-items: flex-start; justify-content: space-between; gap: 8px; }
.demo-card-title { font-weight: 600; font-size: 14px; color: #0f172a; margin: 0; line-height: 1.3; }
.demo-card-sub   { font-size: 11px; color: #64748b; margin-top: 4px; }

.demo-card-toolbar { display: flex; gap: 4px; flex-shrink: 0; opacity: .35; transition: opacity .15s; }
.demo-card:hover .demo-card-toolbar,
.demo-card-toolbar:focus-within { opacity: 1; }
.demo-card-pin, .demo-card-png, .demo-ci-btn {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 6px; cursor: pointer;
  padding: 3px 7px; font-size: 12px; line-height: 1; color: #64748b;
  transition: background-color .12s, border-color .12s, color .12s;
}
.demo-card-pin:hover, .demo-card-png:hover, .demo-ci-btn:hover {
  background: #f1f5f9; border-color: #cbd5e1; color: #0f172a;
}
.demo-card-pin.pin-flash { background: __FOCAL__; border-color: __FOCAL__; color: #fff; }
.demo-ci-btn.active { background: __FOCAL__; border-color: __FOCAL__; color: #fff; }

.demo-brand-picker { display: flex; flex-wrap: wrap; gap: 4px; align-items: center; margin: 8px 0; padding: 6px 8px; background: #f8fafc; border-radius: 6px; }
.demo-brand-picker-label { font-size: 11px; color: #64748b; margin-right: 4px; }
.demo-brand-chip { background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 3px 9px; font-size: 11px; color: #475569; cursor: pointer; }
.demo-brand-chip:hover { background: #f1f5f9; }
.demo-brand-chip.active { background: __FOCAL__; color: #fff; border-color: __FOCAL__; }

.demo-table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 12px; }
.demo-table th, .demo-table td { padding: 5px 8px; border-bottom: 1px solid #f1f5f9; text-align: left; vertical-align: middle; }
.demo-table th { font-weight: 600; color: #64748b; font-size: 11px; text-transform: uppercase; letter-spacing: .4px; }
.demo-row-label { width: 32%; color: #1e293b; }
.demo-row-bar   { width: 38%; }
.demo-row-bar-fill { height: 10px; border-radius: 6px; opacity: .85; }
.demo-row-pct   { text-align: right; font-variant-numeric: tabular-nums; width: 60px; }
.demo-row-ci    { text-align: right; font-variant-numeric: tabular-nums; width: 110px; color: #94a3b8; font-size: 11px; }
.demo-row-n     { text-align: right; font-variant-numeric: tabular-nums; width: 60px; color: #94a3b8; }

/* CI column hidden by default; toggled visible by demo-ci-btn JS handler */
.demo-table .demo-ci-col, .demo-table .demo-row-ci { display: none; }
.demo-card.show-ci .demo-table .demo-ci-col,
.demo-card.show-ci .demo-table .demo-row-ci { display: table-cell; }

/* Heatmap cells (used in by-brand sub-tab) — diverging blue-to-red around row mean. */
.demo-heat-cell { text-align: right; font-variant-numeric: tabular-nums; padding: 4px 8px; min-width: 56px; border-radius: 3px; }
.demo-heat-cell.focal-col { font-weight: 700; }

.demo-na { color: #cbd5e1; font-style: italic; }
.demo-empty { padding: 18px; text-align: center; color: #94a3b8; font-style: italic; font-size: 12px; }
.demo-insight-box { margin-top: 18px; }
"
  gsub("__FOCAL__", focal_colour, template, fixed = TRUE)
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
