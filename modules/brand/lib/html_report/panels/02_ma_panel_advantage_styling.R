# ==============================================================================
# BRAND MODULE - MA PANEL: MENTAL ADVANTAGE STYLING
# ==============================================================================
# CSS specific to the Mental Advantage sub-tab. Lives alongside
# 02_ma_panel_styling.R which carries the rest of the MA panel CSS;
# kept separate so each file stays well under the 300-line budget.
#
# Design language:
#   - Diverging palette centred on 0pp: red (build) -> grey (maintain)
#     -> green (defend). Threshold lines at the cell colour boundaries.
#   - Quadrant chart: focal-coloured bubbles, four implicit zones tinted
#     subtly so the strategic frame reads even without labels.
#   - Action list: three vertical cards, each scoped to a decision class
#     so the colour appears on the heading and the left rail.
# ==============================================================================


#' Return the Mental Advantage sub-tab CSS as a single style block.
#' @param focal_colour Character. Hex colour for focal accents.
#' @return Character. <style>...</style> block.
#' @export
build_ma_advantage_styles <- function(focal_colour = "#1A5276") {

  tmpl <- '
.ma-advantage-section { margin-top: 4px; }
.ma-adv-empty .ma-adv-empty-msg {
  padding: 22px 18px; color: #64748b; background: #f8fafc;
  border: 1px solid #e2e8f0; border-radius: 8px; }

/* Intro panel — laymans overview */
.ma-adv-intro { margin: 4px 0 14px; }
.ma-adv-intro-callout {
  border: 1px solid #dbe7f5; background: #f3f8fd;
  border-left: 4px solid %FOCAL%;
  border-radius: 8px; padding: 8px 14px;
  font-size: 12.5px; color: #1e293b; }
.ma-adv-intro-callout > summary {
  cursor: pointer; font-size: 13px; font-weight: 700; color: #0f172a;
  list-style: none; padding: 4px 0; user-select: none; }
.ma-adv-intro-callout > summary::-webkit-details-marker { display: none; }
.ma-adv-intro-callout > summary::before { content: "\\25B8 "; color: %FOCAL%; }
.ma-adv-intro-callout[open] > summary::before { content: "\\25BE "; }
.ma-adv-intro-body { margin-top: 8px; line-height: 1.55; max-width: 78ch; }
.ma-adv-intro-body p { margin: 0 0 8px; }
.ma-adv-intro-body em { color: #475569; }
.ma-adv-intro-list { margin: 6px 0 8px; padding-left: 18px; }
.ma-adv-intro-list li { margin: 3px 0; }
.ma-adv-intro-list strong { color: #1e293b; }
.ma-adv-intro-source { font-size: 11px; color: #64748b; margin-top: 8px !important; }

/* Chip row for brand-column visibility (matches existing MA tabs) */
.ma-adv-chip-bar {
  display: flex; align-items: center; flex-wrap: wrap;
  gap: 8px; margin: 0 0 12px; padding: 6px 10px;
  background: #f8fafc; border: 1px solid #eef2f7;
  border-radius: 6px; }
.ma-adv-chip-bar .ma-ctl-label {
  font-size: 11px; font-weight: 600; color: #64748b;
  text-transform: uppercase; letter-spacing: 0.4px;
  margin-right: 6px; }

/* X-axis dropdown */
.ma-adv-xaxis-wrap {
  display: inline-flex; align-items: center; gap: 6px; }
.ma-adv-xaxis-select {
  font-size: 11.5px; padding: 4px 8px; border-radius: 4px;
  border: 1px solid #cbd5e1; background: #fff;
  color: #1e293b; cursor: pointer; }

/* Stim/base toggle reuse sig-level-switcher styling — the MA panel CSS
   already defines those buttons; only spacing adjustments here. */
.ma-adv-controls { margin-bottom: 14px; }
.ma-adv-controls .ma-meta-row { gap: 14px; }
.ma-adv-stim-switcher,
.ma-adv-base-switcher { margin-right: 8px; }

/* Three-view layout: stack vertically, each gets full width. */
.ma-adv-views { display: flex; flex-direction: column; gap: 22px; }
.ma-adv-view { background: #fff; border: 1px solid #e2e8f0;
  border-radius: 8px; padding: 14px 16px; }
.ma-adv-view-header { display: flex; align-items: center;
  gap: 16px; margin-bottom: 8px; }
.ma-adv-view-header .ma-subsection-title { margin: 0; }

/* ============== STRATEGIC QUADRANT ============== */
.ma-adv-quadrant-svg {
  width: 100%; display: block; height: 420px; font-family: inherit; }
.ma-adv-quadrant-svg .ma-adv-q-bg {
  fill: rgba(241, 245, 249, 0.5); }
.ma-adv-quadrant-svg .ma-adv-q-axis {
  stroke: #94a3b8; stroke-width: 1.5; }
.ma-adv-quadrant-svg .ma-adv-q-grid {
  stroke: #eef2f7; stroke-width: 1; }
.ma-adv-quadrant-svg .ma-adv-q-zero {
  stroke: #475569; stroke-width: 1.6; }
.ma-adv-quadrant-svg .ma-adv-q-thresh {
  stroke: #94a3b8; stroke-width: 1.2; stroke-dasharray: 5 4; }
.ma-adv-quadrant-svg .ma-adv-q-zone-defend {
  fill: rgba(5, 150, 105, 0.05); }
.ma-adv-quadrant-svg .ma-adv-q-zone-build {
  fill: rgba(220, 38, 38, 0.05); }
.ma-adv-quadrant-svg .ma-adv-q-axis-label {
  font-size: 11px; fill: #475569; font-weight: 600; }
.ma-adv-quadrant-svg .ma-adv-q-zone-label {
  font-size: 9px; fill: #94a3b8; font-weight: 700;
  letter-spacing: 0.6px; text-transform: uppercase; }
.ma-adv-quadrant-svg .ma-adv-q-tick { font-size: 9px; fill: #94a3b8; }
.ma-adv-quadrant-svg .ma-adv-q-bubble {
  stroke-width: 1.5; transition: opacity 0.15s; }
.ma-adv-quadrant-svg .ma-adv-q-bubble-defend {
  fill: rgba(5, 150, 105, 0.78); stroke: #047857; }
.ma-adv-quadrant-svg .ma-adv-q-bubble-build {
  fill: rgba(220, 38, 38, 0.78); stroke: #b91c1c; }
.ma-adv-quadrant-svg .ma-adv-q-bubble-maintain {
  fill: rgba(148, 163, 184, 0.78); stroke: #64748b; }
.ma-adv-quadrant-svg .ma-adv-q-bubble-na {
  fill: rgba(226, 232, 240, 0.6); stroke: #cbd5e1; }
.ma-adv-quadrant-svg .ma-adv-q-bubble-sig {
  stroke-width: 2.5; }
.ma-adv-quadrant-svg .ma-adv-q-label {
  font-size: 10px; fill: #1e293b; pointer-events: none; }

/* ============== DIVERGING MATRIX ============== */
.ma-adv-matrix-wrap { overflow-x: auto; padding: 0 4px 2px; }
table.ma-adv-matrix {
  border-collapse: separate; border-spacing: 0; width: 100%;
  font-size: 12px; min-width: 560px; }
.ma-adv-matrix th {
  background: #1e293b; color: #fff; font-weight: 600; font-size: 11px;
  letter-spacing: 0.3px; padding: 8px 10px; text-align: center;
  border-bottom: 2px solid #0f172a; white-space: normal; }
.ma-adv-matrix th.ma-adv-matrix-th-stim {
  text-align: left; min-width: 200px; }
.ma-adv-matrix th.ma-adv-matrix-th-focal {
  background: %FOCAL%; }
.ma-adv-matrix td {
  padding: 7px 10px; border-bottom: 1px solid #f0f0f0;
  text-align: center; vertical-align: middle;
  font-variant-numeric: tabular-nums; font-weight: 600;
  position: relative;
  background-clip: padding-box;
  background-origin: padding-box; }
/* Defeat any global table rule that whites out cell backgrounds (e.g.
   striped-row themes) so MA score colours always paint full-cell. The JS
   sets background-color inline; this rule keeps it from being overridden. */
.ma-adv-matrix td[style*="background-color"] {
  background-image: none !important; }
/* Hide brand columns when their chip is toggled off */
.ma-adv-matrix col.ma-adv-col-hidden,
.ma-adv-matrix th.ma-adv-col-hidden,
.ma-adv-matrix td.ma-adv-col-hidden { display: none !important; }

/* Per-row checkbox: when unchecked, the row stays in the table but is
   greyed out and struck through, matching the brand-attributes tab so
   the user can re-check to restore. The chart drops the bubble. */
.ma-adv-matrix tr.ma-adv-row-inactive td { opacity: 0.45; }
.ma-adv-matrix tr.ma-adv-row-inactive .ma-adv-row-stim-label {
  text-decoration: line-through; color: #94a3b8; }
.ma-adv-matrix tr.ma-adv-row-inactive td[data-ma-adv-cell-bg] {
  background-color: #f8fafc !important;
  background-image: none !important;
  color: #94a3b8 !important; }
.ma-adv-row-toggle {
  display: inline-flex; align-items: center; gap: 6px;
  cursor: pointer; }
.ma-adv-row-toggle input { margin: 0; }
.ma-adv-row-stim-label { line-height: 1.35; }

/* X-axis range inputs (next to the chart) */
.ma-adv-quadrant-rangebar {
  display: flex; align-items: center; flex-wrap: wrap;
  gap: 10px; margin: 4px 0 12px; padding: 6px 10px;
  background: #fafbfc; border: 1px solid #eef2f7;
  border-radius: 6px; font-size: 11.5px; }
.ma-adv-quadrant-rangebar .ma-ctl-label {
  font-size: 11px; font-weight: 600; color: #64748b;
  text-transform: uppercase; letter-spacing: 0.4px; }
.ma-adv-xrange-label {
  display: inline-flex; align-items: center; gap: 6px;
  color: #475569; font-weight: 500; }
.ma-adv-xrange-input {
  width: 70px; font-size: 12px; padding: 4px 6px;
  border-radius: 4px; border: 1px solid #cbd5e1;
  background: #fff; color: #1e293b;
  font-variant-numeric: tabular-nums; }
.ma-adv-xrange-reset {
  font-size: 11.5px; padding: 4px 10px;
  border-radius: 4px; border: 1px solid #cbd5e1;
  background: #fff; color: #475569; cursor: pointer; }
.ma-adv-xrange-reset:hover { background: #f1f5f9; }
.ma-adv-rangebar-sep {
  color: #cbd5e1; font-weight: 400; user-select: none;
  margin: 0 2px; }
.ma-adv-matrix td.ma-adv-matrix-stim {
  text-align: left; font-weight: 500; color: #334155;
  white-space: normal; max-width: 260px; }
.ma-adv-matrix td.ma-adv-matrix-focal {
  box-shadow: inset 3px 0 0 0 %FOCAL%, inset -3px 0 0 0 %FOCAL%; }
.ma-adv-matrix td .ma-adv-cell-counts {
  display: none; font-size: 10px; font-weight: 400;
  color: #475569; margin-top: 2px; }
.ma-adv-matrix-wrap.ma-adv-show-counts td .ma-adv-cell-counts {
  display: block; }
/* Significance is shown via the chart bubble outline + the tooltip; per
   Duncan, the matrix cells must NOT change formatting based on significance. */

/* ============== ACTION LIST ============== */
.ma-adv-action-cols {
  display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 14px;
  margin-top: 8px; }
@media (max-width: 900px) {
  .ma-adv-action-cols { grid-template-columns: 1fr; }
}
.ma-adv-action-col {
  background: #fafbfc; border: 1px solid #eef2f7;
  border-radius: 8px; padding: 12px; min-height: 140px; }
.ma-adv-action-col.ma-adv-defend {
  border-left: 4px solid #059669; }
.ma-adv-action-col.ma-adv-build {
  border-left: 4px solid #dc2626; }
.ma-adv-action-col.ma-adv-maintain {
  border-left: 4px solid #94a3b8; }
.ma-adv-col-head {
  display: flex; align-items: baseline; justify-content: space-between;
  margin-bottom: 8px; padding-bottom: 6px;
  border-bottom: 1px dashed #e2e8f0; }
.ma-adv-col-title {
  font-size: 13px; font-weight: 700; letter-spacing: 0.3px;
  text-transform: uppercase; }
.ma-adv-defend  .ma-adv-col-title { color: #059669; }
.ma-adv-build   .ma-adv-col-title { color: #dc2626; }
.ma-adv-maintain .ma-adv-col-title { color: #475569; }
.ma-adv-col-count {
  font-size: 11px; color: #94a3b8; font-weight: 600;
  font-variant-numeric: tabular-nums; }
ol.ma-adv-action-list {
  list-style: none; padding: 0; margin: 0;
  display: flex; flex-direction: column; gap: 6px; }
.ma-adv-action-row {
  display: grid; grid-template-columns: 1fr auto;
  gap: 6px 10px; padding: 6px 8px;
  background: #fff; border: 1px solid #eef2f7; border-radius: 6px;
  font-size: 12px; align-items: baseline; }
.ma-adv-action-label {
  color: #1e293b; font-weight: 500; line-height: 1.35; }
.ma-adv-action-score {
  font-weight: 700; font-variant-numeric: tabular-nums;
  white-space: nowrap; }
.ma-adv-defend  .ma-adv-action-score { color: #059669; }
.ma-adv-build   .ma-adv-action-score { color: #dc2626; }
.ma-adv-maintain .ma-adv-action-score { color: #475569; }
.ma-adv-action-meta {
  grid-column: 1 / -1; font-size: 10.5px; color: #64748b;
  font-style: italic; margin-top: 2px; }
.ma-adv-action-empty {
  padding: 10px 4px; color: #94a3b8; font-size: 11.5px;
  font-style: italic; text-align: center; }

/* ============== LEGEND ============== */
.ma-adv-legend {
  display: flex; flex-wrap: wrap; gap: 14px; align-items: center;
  padding: 8px 12px; background: #fafbfc;
  border: 1px solid #eef2f7; border-radius: 6px;
  font-size: 11.5px; color: #475569; }
.ma-adv-legend-item {
  display: inline-flex; align-items: center; gap: 6px; }
.ma-adv-legend-swatch {
  display: inline-block; width: 14px; height: 14px;
  border-radius: 3px; border: 1px solid rgba(0,0,0,0.08); }
.ma-adv-legend-defend   { background: rgba(5, 150, 105, 0.55); }
.ma-adv-legend-maintain { background: rgba(148, 163, 184, 0.45); }
.ma-adv-legend-build    { background: rgba(220, 38, 38, 0.55); }
.ma-adv-legend-sig {
  display: inline-block; width: 14px; height: 14px;
  text-align: center; font-weight: 700; color: #0f172a;
  font-size: 16px; line-height: 14px; }

/* ============== HOVER TOOLTIP ============== */
.ma-adv-tooltip {
  position: fixed; z-index: 9000; pointer-events: none;
  background: #0f172a; color: #f8fafc;
  padding: 8px 10px; border-radius: 6px;
  font-size: 11.5px; line-height: 1.45;
  box-shadow: 0 6px 18px rgba(15,23,42,0.25);
  max-width: 280px; transform: translate(-50%, -110%); }
.ma-adv-tooltip[hidden] { display: none; }
.ma-adv-tooltip strong {
  color: #fff; font-size: 12px; display: block;
  margin-bottom: 3px; }
.ma-adv-tooltip .ma-adv-tooltip-row {
  display: flex; justify-content: space-between;
  gap: 12px; }
.ma-adv-tooltip .ma-adv-tooltip-key {
  color: #cbd5e1; }
.ma-adv-tooltip .ma-adv-tooltip-val {
  color: #fff; font-variant-numeric: tabular-nums; }
.ma-adv-tooltip .ma-adv-tooltip-decision {
  margin-top: 4px; padding-top: 4px;
  border-top: 1px solid rgba(255,255,255,0.15);
  font-weight: 700; }
.ma-adv-tooltip .ma-adv-tooltip-defend  { color: #34d399; }
.ma-adv-tooltip .ma-adv-tooltip-build   { color: #f87171; }
.ma-adv-tooltip .ma-adv-tooltip-maintain { color: #cbd5e1; }
.ma-adv-q-bubble { cursor: pointer; }

/* ============== VERTICAL DIVIDER LINE IN QUADRANT ============== */
.ma-adv-quadrant-svg .ma-adv-q-vmid {
  stroke: #475569; stroke-width: 1.6;
  stroke-dasharray: 4 3; opacity: 0.65; }
.ma-adv-quadrant-svg .ma-adv-q-vmid-label {
  font-size: 9px; fill: #475569; font-weight: 600; }

/* ============== HIDE QUADRANT WHEN UNCHECKED ============== */
.ma-adv-quadrant-view[hidden] { display: none !important; }

/* Suppress the panel-wide "About Mental Availability" drawer when the
   advantage tab is the active sub-tab. The advantage tab has its own
   "What is Mental Advantage?" callout at the bottom of its own subtab. */
.ma-panel.ma-active-advantage .ma-about-availability { display: none !important; }

/* Static "Base:" notation (Romaniuk — total respondents only) replaces
   the previous toggle. Lives in the controls bar. */
.ma-adv-base-notation {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 4px 10px; border-radius: 4px;
  background: #f8fafc; border: 1px solid #e2e8f0;
  font-size: 11px; color: #475569; }
.ma-adv-base-notation .ma-adv-base-value {
  font-weight: 600; color: #1e293b; }

/* Static "Bubbles sized by: % total" reminder near the chart range bar. */
.ma-adv-base-status {
  margin-left: auto; font-size: 11px; color: #475569;
  font-style: italic; padding: 4px 10px;
  background: #fff; border: 1px solid #e2e8f0; border-radius: 4px; }

@media print {
  .ma-adv-controls { display: none !important; }
  .ma-adv-views { gap: 12px; }
  .ma-adv-tooltip { display: none !important; }
}
'

  tmpl <- gsub("%FOCAL%", focal_colour, tmpl, fixed = TRUE)
  paste0('<style class="ma-advantage-styles">', tmpl, '</style>')
}
