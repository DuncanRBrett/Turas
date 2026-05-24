# ==============================================================================
# BRAND MODULE - DEMOGRAPHICS PANEL HTML RENDERER (matrix layout)
# ==============================================================================
# Lays out the per-category Demographics tab as a matrix per question:
#
#   Option label | Focal brand (selectable) | Cat avg | Brand A | …
#
# Demographics is a quick brand-vs-category-vs-other-brands comparison
# only. Detailed demographic exploration is the tabs module's job;
# confidence intervals were dropped to keep the read uncluttered.
#
# Global controls (panel header):
#   - Focal-brand picker (<select> dropdown — picks col 2)
#   - Show counts checkbox
#   - Heatmap checkbox
# Brand visibility: colour-coded chip strip; click to hide / show that brand's
#   matrix column without re-running the engine.
# Question visibility: chip strip; click to hide / show a question card.
#
# Per-question card carries its own pin / PNG / Excel toolbar and a table↔chart
# toggle. The chart view is a horizontal bar chart of focal-vs-cat-avg for each
# option, drawn inline as SVG.
#
# All split into three files to keep each <300 active lines:
#   11_demographics_panel.R         - orchestration + header + controls + CSS
#   11_demographics_panel_table.R   - per-question matrix table builder
#   11_demographics_panel_chart.R   - per-question SVG bar chart builder
#
# Engine output is unchanged (run_demographic_question + brand_cut). Synthetic
# Buyer status / Heaviness questions are appended upstream in
# .run_demographics_for_category (00_main.R).
#
# VERSION: 2.0 (matrix layout; supersedes the per-question card stack)
# ==============================================================================

BRAND_DEMOGRAPHICS_PANEL_VERSION <- "2.0"


# ==============================================================================
# PUBLIC API
# ==============================================================================

#' Build demographics panel HTML (matrix layout)
#'
#' @param panel_data List from \code{build_demographics_panel_data()}.
#' @param panel_id Character. Element id used to scope sub-element ids.
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
  brand_cols   <- .demo_brand_palette(panel_data, focal_colour)

  callout_html <- if (exists("turas_callout", mode = "function")) {
    turas_callout("brand", "demographics", collapsed = TRUE)
  } else ""

  paste0(
    sprintf('<div class="demo-panel" id="%s" data-focal-colour="%s">',
            panel_id, .demo_esc(focal_colour)),
    sprintf('<script type="application/json" class="demo-panel-data">%s</script>',
            json_payload),
    .demo_panel_header(panel_data),
    .demo_panel_global_controls(panel_data),
    .demo_panel_focal_picker(panel_data, brand_cols),
    .demo_panel_question_chips(panel_data),
    .demo_panel_card_grid(panel_data, panel_id, brand_cols),
    callout_html,
    '</div>'
  )
}


# ==============================================================================
# CSS — public helper, returned as a string for the orchestrator to wrap in
# <style> tags (mirrors the WOM / branded-reach panel pattern).
# ==============================================================================

#' Build demographics panel CSS
#' @param focal_colour Character. Hex colour for focal accents.
#' @return Character. CSS string (no <style> tags).
#' @export
# SIZE-EXCEPTION: single CSS string template with one substitution. Decomposing
# would split related rules across functions and obscure the cascade. Mirrors
# the same pattern used in build_branded_reach_panel_styles().
build_demographics_panel_styles <- function(focal_colour = "#1A5276") {
  template <- "
.demo-panel { font: 13px/1.45 system-ui, -apple-system, Segoe UI, sans-serif; color: #1e293b; }
.demo-panel-empty { font-style: italic; }

.demo-panel-header { margin: 4px 0 12px; padding: 12px 14px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; }
.demo-panel-header-title { font-weight: 600; font-size: 14px; color: #0f172a; }
.demo-panel-header-sub   { font-size: 11px; color: #64748b; margin-top: 2px; }

.demo-control-bar { display: flex; flex-wrap: wrap; gap: 18px; align-items: center; margin: 8px 0 12px; padding: 8px 12px; background: #fff; border: 1px solid #e2e8f0; border-radius: 8px; }
.demo-control-label { font-size: 11px; color: #64748b; text-transform: uppercase; letter-spacing: .4px; margin-right: 6px; }
.demo-control-check { display: inline-flex; align-items: center; gap: 4px; font-size: 12px; color: #334155; cursor: pointer; user-select: none; }
.demo-control-check input { cursor: pointer; }

.demo-chip-row { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; margin: 6px 0 10px; padding: 0 4px; }
.demo-chip-row-label { font-size: 11px; color: #64748b; margin-right: 4px; }
.demo-q-chip {
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 14px;
  padding: 4px 10px; font-size: 11px; color: #475569; cursor: pointer;
  display: inline-flex; align-items: center; gap: 5px;
}
.demo-q-chip:hover { background: #f1f5f9; }
.demo-q-chip.active { background: __FOCAL__; color: #fff; border-color: __FOCAL__; }
.demo-q-chip:not(.active) { opacity: 0.55; text-decoration: line-through; }
/* Brand swatch — still used in matrix table headers (legacy class name kept) */
.demo-brand-chip-swatch { width: 10px; height: 10px; border-radius: 50%; display: inline-block; }

.demo-focal-row { align-items: center; }
.demo-focal-select {
  font: inherit; font-size: 12px; color: #1e293b;
  background: #fff; border: 1px solid #cbd5e1; border-radius: 6px;
  padding: 4px 8px; cursor: pointer; min-width: 140px;
}
.demo-focal-select:focus { outline: 2px solid __FOCAL__; outline-offset: 1px; }

.demo-control-sep { width: 1px; height: 16px; background: #e2e8f0; flex-shrink: 0; }
.demo-view-all-btn {
  background: #fff; border: 1px solid #cbd5e1; border-radius: 14px;
  padding: 4px 11px; font-size: 11px; color: #475569; cursor: pointer;
  text-transform: none !important; white-space: nowrap !important;
}
.demo-view-all-btn:hover { background: #f1f5f9; border-color: #94a3b8; }
.demo-view-all-btn.active { background: __FOCAL__; border-color: __FOCAL__; color: #fff !important; }

.demo-card-grid { display: flex; flex-direction: column; gap: 16px; }
.demo-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 14px 16px; box-shadow: 0 1px 2px rgba(0,0,0,.03); position: relative; }
.demo-card.hidden { display: none; }
.demo-card-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 8px; }
.demo-card-titlebar { flex: 1; min-width: 0; }
.demo-card-title { font-weight: 600; font-size: 14px; color: #0f172a; margin: 0; line-height: 1.3; }
.demo-card-sub { font-size: 11px; color: #64748b; margin-top: 3px; }
.demo-card-toolbar { display: flex; gap: 4px; flex-shrink: 0; align-items: center; }
.demo-card-tool {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 6px; cursor: pointer;
  padding: 3px 7px; font-size: 12px; line-height: 1; color: #64748b;
  transition: background-color .12s, border-color .12s, color .12s;
}
.demo-card-tool:hover { background: #f1f5f9; border-color: #cbd5e1; color: #0f172a; }
.demo-card-tool.active { background: __FOCAL__; border-color: __FOCAL__; color: #fff; }
.demo-card-tool.pin-flash { background: __FOCAL__; border-color: __FOCAL__; color: #fff; }

/* Matrix table — matches the brand-panel convention used by Cat Buying,
   Funnel and the MA focal view: dark navy header, white text, tabular
   numerics, left-aligned label column. */
.demo-matrix-wrap { overflow-x: auto; }
.demo-matrix {
  width: 100%; border-collapse: collapse; font-size: 12.5px;
  min-width: 480px; font-variant-numeric: tabular-nums;
  color: #1e293b;
}
.demo-matrix thead th {
  background: #1f2a44; color: #fff; font-weight: 600;
  padding: 9px 10px; text-align: center; vertical-align: middle;
  font-size: 11.5px; letter-spacing: 0.2px; line-height: 1.3;
  white-space: normal; min-width: 80px;
}
.demo-matrix thead th:first-child {
  text-align: left; padding-left: 14px; min-width: 140px;
}
.demo-matrix thead th .demo-brand-chip-swatch {
  background: rgba(255,255,255,0.85); border: 1px solid rgba(255,255,255,0.6);
}
.demo-matrix thead th .demo-th-sub {
  display: block; font-weight: 400; font-size: 10px; color: #cbd5e1;
  margin-top: 2px; text-transform: none;
}
.demo-matrix tbody td {
  padding: 7px 10px; border-bottom: 1px solid #eef0f3;
  text-align: center; vertical-align: middle;
}
.demo-matrix tbody td:first-child {
  text-align: left; padding-left: 14px;
  color: #1e293b; font-weight: 500;
}
.demo-matrix tbody tr:nth-child(even) td { background: #fafbfc; }
.demo-col-focal { font-weight: 600; color: __FOCAL__; }
.demo-matrix tbody td.demo-col-focal { background: rgba(26, 82, 118, 0.08) !important; }
.demo-col-catavg { color: #475569; font-style: italic; }
.demo-matrix tbody td.demo-col-catavg { background: #f5f7fb !important; }
.demo-cell-n { font-size: 10px; color: #94a3b8; margin-left: 4px; font-weight: normal; }
.demo-na { color: #cbd5e1; font-style: italic; }

/* Two-row option layout: a Buyer row and a Non-buyer row per demographic
 * option. Background colour on each cell shows over/under-indexing vs the
 * Cat avg baseline (blue = over, red = under). The Non-buyer row is the
 * comparison; styled lighter / italic so the Buyer row is the dominant read.
 * Show / hide the Non-buyer rows via the .demo-hide-nonbuyer panel modifier. */
.demo-matrix tbody tr.demo-row-buyer    td { border-bottom: 1px solid #f1f5f9; }
.demo-matrix tbody tr.demo-row-nonbuyer td { border-bottom: 2px solid #e2e8f0; }
.demo-matrix tbody tr.demo-row-nonbuyer td:not(.demo-cell-blank):not(.demo-opt-label) {
  font-style: italic; font-size: 11.5px; color: #64748b; font-weight: 400;
}
.demo-matrix tbody tr.demo-row-nonbuyer td .demo-cell-n { font-style: normal; }

/* Option label cell — option name (primary) + role chip (buyer/non-buyer).
 * Both pieces are always shown so each row is self-identifying when the
 * other row type is toggled off. */
.demo-opt-label .demo-opt-name {
  display: block; color: #1e293b; font-weight: 500; font-size: 12px;
  line-height: 1.2;
}
.demo-opt-label .demo-opt-role {
  display: block; color: #64748b; font-size: 10px; font-weight: 500;
  text-transform: uppercase; letter-spacing: 0.4px; line-height: 1.2;
  margin-top: 1px;
}
.demo-opt-label .demo-opt-role-nonbuyer {
  color: #94a3b8; font-style: italic;
}
.demo-cell-blank { background: transparent !important; }

/* Strip the prior zebra striping — alternating colour at half-option
 * boundaries was visually confusing. Subtle borders group the two rows of
 * each option instead. */
.demo-matrix tbody tr:nth-child(even) td { background: inherit; }

/* Row toggles. Panel root carries .demo-hide-buyer / .demo-hide-nonbuyer
 * when each control is off; CSS hides the matching rows. When one row is
 * hidden the remaining row's bottom border lightens so the single-row look
 * is intentional. */
.demo-panel.demo-hide-nonbuyer .demo-row-nonbuyer { display: none; }
.demo-panel.demo-hide-nonbuyer .demo-row-buyer td { border-bottom: 1px solid #eef0f3; }
.demo-panel.demo-hide-buyer    .demo-row-buyer    { display: none; }
.demo-panel.demo-hide-buyer    .demo-row-nonbuyer td { border-bottom: 1px solid #eef0f3; }

/* Chart view */
.demo-chart-wrap { padding: 22px 4px 8px; }
.demo-chart-row {
  display: grid; grid-template-columns: 130px 1fr 80px;
  gap: 8px; align-items: center;
  padding: 14px 0 4px;   /* top space leaves room for the marker-value label */
  font-size: 12px;
}
.demo-chart-row-label { color: #1e293b; line-height: 1.15; }
.demo-chart-opt-name { display: block; font-weight: 500; }
.demo-chart-role {
  display: block; font-size: 10px; color: #64748b; text-transform: uppercase;
  letter-spacing: 0.4px; margin-top: 1px;
}
.demo-chart-role-nonbuyer { color: #94a3b8; font-style: italic; }
.demo-chart-bar { background: #f1f5f9; border-radius: 4px; height: 18px; position: relative; overflow: visible; }
.demo-chart-bar-fill { height: 100%; background: __FOCAL__; opacity: 0.85; }
/* Primary marker — typical brand pen in this option (varies row by row). */
.demo-chart-bar-marker { position: absolute; top: -2px; bottom: -2px; width: 2px; background: #475569; z-index: 2; }
/* Visible value label sitting just above the primary marker. */
.demo-chart-bar-marker-value {
  position: absolute; top: -14px;
  transform: translateX(-50%);
  font-size: 10px; color: #475569; font-weight: 500;
  white-space: nowrap; line-height: 1;
  z-index: 3;
}
/* Secondary marker — focal's cat-wide overall pen. Same X on every row, so
 * we style it as a dashed faded line to distinguish from the primary. */
.demo-chart-bar-marker-overall {
  position: absolute; top: -2px; bottom: -2px; width: 0; z-index: 1;
  border-left: 2px dashed #94a3b8;
}
.demo-chart-legend-swatch-line {
  display: inline-block; width: 12px; height: 0; border-top: 2px solid #475569;
  margin-right: 4px; vertical-align: middle;
}
.demo-chart-legend-swatch-line-dashed {
  display: inline-block; width: 12px; height: 0; border-top: 2px dashed #94a3b8;
  margin-right: 4px; vertical-align: middle;
}
.demo-chart-row-value { text-align: right; font-variant-numeric: tabular-nums; font-weight: 600; }
.demo-chart-legend { display: flex; gap: 14px; align-items: center; font-size: 11px; color: #64748b; margin-top: 8px; padding-left: 130px; flex-wrap: wrap; }
.demo-chart-legend-swatch { display: inline-block; width: 12px; height: 8px; border-radius: 2px; margin-right: 4px; vertical-align: middle; background: __FOCAL__; opacity: 0.85; }
.demo-chart-legend-footnote { color: #94a3b8; font-style: italic; font-size: 10.5px; margin-left: auto; }


.demo-empty { padding: 18px; text-align: center; color: #94a3b8; font-style: italic; font-size: 12px; }
"
  gsub("__FOCAL__", focal_colour, template, fixed = TRUE)
}


# ==============================================================================
# INTERNAL: HEADER + CONTROL ROWS
# ==============================================================================

.demo_panel_empty_state <- function(pd) {
  msg <- (pd$meta$message) %||%
         "No demographic questions configured. Add demo.* roles to the QuestionMap sheet in Survey_Structure.xlsx."
  sprintf(
    '<div class="demo-panel-empty" style="padding:32px;text-align:center;color:#94a3b8;font-size:14px;">%s</div>',
    .demo_esc(msg))
}


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


.demo_panel_global_controls <- function(pd) {
  paste0(
    '<div class="demo-control-bar">',
    '<span class="demo-control-label">Cells:</span>',
    '<label class="demo-control-check" title="% of respondents in this demographic option who buy this brand. Cells sum to 100% (buyer + non-buyer) within each option. Best for finding where a brand over- or under-performs."><input type="radio" name="demo-metric" data-demo-metric="penetration" checked> % who buy</label>',
    '<label class="demo-control-check" title="% of this brand’s buyers who fall in this option. Brand column sums to 100%. Best for describing what a brand’s buyer audience looks like demographically."><input type="radio" name="demo-metric" data-demo-metric="share"> % of buyers</label>',
    '<span class="demo-control-sep"></span>',
    '<span class="demo-control-label">Baseline:</span>',
    '<label class="demo-control-check" title="Compare focal brand against the CATEGORY-BUYER average for this question. Best for spotting what is distinctive about this brand within its category — the academic default (Romaniuk / Ehrenberg-Bass)."><input type="radio" name="demo-baseline" data-demo-baseline="cat" checked> Cat avg</label>',
    '<label class="demo-control-check" title="Compare focal brand against the WHOLE SCREENED SAMPLE for this question. Best for cross-category reads (same denominator across all categories) and for population-relative skews."><input type="radio" name="demo-baseline" data-demo-baseline="study"> Total sample</label>',
    '<span class="demo-control-sep"></span>',
    '<span class="demo-control-label">Show:</span>',
    '<label class="demo-control-check"><input type="checkbox" data-demo-toggle="counts"> n counts</label>',
    '<label class="demo-control-check"><input type="checkbox" data-demo-toggle="heatmap" checked> Heatmap</label>',
    '<label class="demo-control-check" title="Show the per-brand buyer row for each option"><input type="checkbox" data-demo-toggle="buyer" checked> Buyer row</label>',
    '<label class="demo-control-check" title="Show the per-brand non-buyer row for each option"><input type="checkbox" data-demo-toggle="nonbuyer" checked> Non-buyer row</label>',
    '<span class="demo-control-sep"></span>',
    '<span class="demo-control-label">View all:</span>',
    '<button type="button" class="demo-view-all-btn active" data-demo-action="allTables" title="Show all questions as tables">&#x2261; Tables</button>',
    '<button type="button" class="demo-view-all-btn" data-demo-action="allCharts" title="Show all questions as charts">&#x1F4CA; Charts</button>',
    '</div>'
  )
}


# Focal-brand picker + brand-visibility dropdown — sit on a single toolbar
# row. The <select> picks which brand fills column 2 ("Focal") of every
# per-question matrix; the BrandSelector trigger to its right opens the
# checkbox popover that hides / shows brand columns across the whole panel.
# Pairing them keeps the controls compact and avoids redundant labels.
.demo_panel_focal_picker <- function(pd, brand_cols) {
  bcs <- pd$brands$codes  %||% character(0)
  bls <- pd$brands$labels %||% bcs
  if (length(bcs) == 0L) return("")
  focal <- pd$meta$focal_brand %||% ""
  default_code <- if (focal %in% bcs) focal else bcs[1]
  options_html <- vapply(seq_along(bcs), function(i) {
    sel <- if (identical(bcs[i], default_code)) ' selected' else ''
    sprintf('<option value="%s"%s>%s</option>',
            .demo_esc(bcs[i]), sel, .demo_esc(bls[i]))
  }, character(1L))
  trigger_html <- build_brand_selector_trigger(
    panel_id = "demographics",
    n_total  = length(bcs),
    label    = "Filter brands"
  )
  paste0(
    '<div class="demo-chip-row demo-focal-row">',
    '<label class="demo-chip-row-label" for="demo-focal-select">Focal brand:</label>',
    '<select id="demo-focal-select" class="demo-focal-select" data-demo-focal-select>',
    paste(options_html, collapse = ""),
    '</select>',
    trigger_html,
    '</div>')
}


.demo_panel_question_chips <- function(pd) {
  chips <- vapply(seq_along(pd$questions), function(i) {
    q <- pd$questions[[i]]
    label <- q$short_label %||% q$question_text %||% q$role
    sprintf(
      '<button type="button" class="demo-q-chip active" data-demo-q-idx="%d" title="%s">%s</button>',
      i - 1L, .demo_esc(q$question_text %||% label), .demo_esc(label))
  }, character(1L))
  paste0(
    '<div class="demo-chip-row">',
    '<span class="demo-chip-row-label">Questions:</span>',
    paste(chips, collapse = ""),
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: PER-QUESTION CARD GRID
# ==============================================================================

.demo_panel_card_grid <- function(pd, panel_id, brand_cols) {
  cards <- vapply(seq_along(pd$questions), function(i) {
    .demo_panel_question_card(pd$questions[[i]], i - 1L, panel_id, pd, brand_cols)
  }, character(1L))
  sprintf('<div class="demo-card-grid">%s</div>', paste(cards, collapse = ""))
}


.demo_panel_question_card <- function(q, idx, panel_id, pd, brand_cols) {
  section_id <- sprintf("section-%s-q%d", panel_id, idx)
  dp <- pd$config$decimal_places %||% 0L
  focal <- pd$meta$focal_brand %||% ""

  # Initial paint uses the default metric ("penetration") — matches the
  # default state of the cell-metric radio at the top of the panel. The JS
  # rebuilds both views when the user switches mode.
  table_html <- build_demographics_matrix_table(q, focal, brand_cols, pd, dp)
  chart_html <- build_demographics_matrix_chart(q, focal, brand_cols, pd, dp,
                                                  metric = "penetration")

  sprintf(
    '<article class="demo-card br-element-section" id="%s" data-section="%s" data-demo-q-idx="%d">
       <header class="demo-card-header">
         <div class="demo-card-titlebar">
           <h3 class="demo-card-title br-element-title">%s</h3>
           <div class="demo-card-sub">%s &middot; n = %s</div>
         </div>
         %s
       </header>
       <div class="demo-card-body">
         <div class="demo-card-view demo-card-view-table" data-pin-as-table>%s</div>
         <div class="demo-card-view demo-card-view-chart" data-pin-as-chart hidden>%s</div>
       </div>
     </article>',
    .demo_esc(section_id), .demo_esc(section_id), idx,
    .demo_esc(q$short_label %||% q$question_text),
    .demo_esc(q$question_text %||% ""),
    .demo_int(q$n_total),
    .demo_panel_card_toolbar(section_id),
    table_html, chart_html
  )
}


.demo_panel_card_toolbar <- function(section_id) {
  sprintf(
    '<div class="demo-card-toolbar" data-section="%s">
       <button type="button" class="demo-card-tool demo-view-table active" data-demo-view="table" title="Table view">&#x2261;</button>
       <button type="button" class="demo-card-tool demo-view-chart" data-demo-view="chart" title="Chart view">&#x1F4CA;</button>
       <button type="button" class="br-pin-btn demo-card-tool" data-section="%s" onclick="brTogglePin(\'%s\')" title="Pin this card">&#x1F4CC;</button>
       <button type="button" class="br-png-btn demo-card-tool" onclick="brExportPng(\'%s\',this)" title="Export PNG">&#x1F5BC;</button>
       <button type="button" class="demo-card-tool" onclick="_brExportPanel(\'%s\')" title="Export Excel">&#x1F4E5;</button>
     </div>',
    .demo_esc(section_id), .demo_esc(section_id),
    .demo_esc(section_id), .demo_esc(section_id), .demo_esc(section_id))
}


# ==============================================================================
# INTERNAL: PALETTE + JSON + ESCAPE HELPERS
# ==============================================================================

# Build a name->hex map for every brand. Falls back to a stable rotating
# palette when the brand_colours list doesn't cover all brands. Focal hex
# overrides the palette for the focal brand entry.
.demo_brand_palette <- function(pd, focal_colour) {
  bcs    <- pd$brands$codes   %||% character(0)
  pal    <- pd$brands$colours %||% list()
  focal  <- pd$meta$focal_brand %||% ""
  fallback <- c("#1A5276", "#B7950B", "#196F3D", "#7E5109",
                 "#6C3483", "#1E8449", "#A04000", "#5D6D7E",
                 "#922B21", "#4A235A")
  out <- list()
  fb_i <- 1L
  for (bc in bcs) {
    if (!is.null(pal[[bc]]) && nzchar(pal[[bc]])) {
      out[[bc]] <- pal[[bc]]
    } else if (identical(bc, focal) && nzchar(focal_colour)) {
      out[[bc]] <- focal_colour
    } else {
      out[[bc]] <- fallback[((fb_i - 1L) %% length(fallback)) + 1L]
      fb_i <- fb_i + 1L
    }
  }
  out
}


.demo_panel_json <- function(pd, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  jsonlite::toJSON(pd, auto_unbox = TRUE, na = "null", null = "null",
                   pretty = FALSE, digits = 6)
}


.demo_int <- function(v) {
  if (is.null(v) || is.na(v) || !is.finite(v)) return("&mdash;")
  format(as.integer(round(v)), big.mark = ",")
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


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
