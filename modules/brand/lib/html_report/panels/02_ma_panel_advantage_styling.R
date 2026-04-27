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

/* Intro text */
.ma-adv-intro { margin: 4px 0 12px; }
.ma-adv-intro-text { font-size: 12px; color: #475569;
  margin: 4px 0 0; line-height: 1.55; max-width: 64ch; }

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
  position: relative; }
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
.ma-adv-matrix .ma-adv-sig-dot::after {
  content: " \\2022"; font-weight: 700; color: #0f172a; }
.ma-adv-matrix-wrap:not(.ma-adv-show-sig) .ma-adv-sig-dot::after {
  content: ""; }

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

@media print {
  .ma-adv-controls { display: none !important; }
  .ma-adv-views { gap: 12px; }
}
'

  tmpl <- gsub("%FOCAL%", focal_colour, tmpl, fixed = TRUE)
  paste0('<style class="ma-advantage-styles">', tmpl, '</style>')
}
