# ==============================================================================
# BRAND MODULE - CATEGORY BUYING PANEL CSS
# ==============================================================================
# Returns a <style> block for the Category Buying (Dirichlet) panel.
# Follows the same inline-CSS pattern as 03_funnel_panel_styling.R.
#
# VERSION: 2.0
# ==============================================================================

BRAND_CB_STYLING_VERSION <- "2.0"


#' Return the CSS bundle for the Category Buying panel
#'
#' @return Character. A \code{<style>} HTML tag containing panel CSS.
#' @keywords internal
cb_panel_css <- function() {
paste0(
'<style>
/* === Category Buying Panel === */
.cb-panel { font-family: system-ui, -apple-system, sans-serif; }
.cb-kpi-strip {
  display: flex; gap: 12px; flex-wrap: wrap; margin: 0 0 20px;
}
.cb-kpi-chip {
  background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 8px;
  padding: 10px 18px; min-width: 130px;
}
.cb-kpi-chip.green  { background: #f0fdf4; border-color: #bbf7d0; }
.cb-kpi-chip.amber  { background: #fffbeb; border-color: #fde68a; }
.cb-kpi-chip.muted  { background: #f8fafc; border-color: #e2e8f0; }
.cb-kpi-val  { font-size: 22px; font-weight: 700; color: #1A5276; }
.cb-kpi-val.green   { color: #166534; }
.cb-kpi-val.amber   { color: #92400e; }
.cb-kpi-val.muted   { color: #334155; }
.cb-kpi-label { font-size: 11px; color: #64748b; margin-top: 2px; }
.cb-section-title {
  font-size: 14px; font-weight: 600; color: #334155; margin: 20px 0 8px;
}
.cb-subtitle {
  font-size: 11px; color: #94a3b8; margin: -4px 0 12px; font-style: italic;
}
.cb-toggle-bar { display: flex; gap: 6px; margin-bottom: 10px; flex-wrap: wrap; }
.cb-toggle-btn {
  background: #f1f5f9; border: 1px solid #e2e8f0; border-radius: 6px;
  padding: 4px 12px; font-size: 12px; cursor: pointer; color: #334155;
  transition: all 0.15s;
}
.cb-toggle-btn.active { background: #1a2744; color: #fff; border-color: #1a2744; }

/* Norms table */
.cb-norms-wrap { overflow-x: auto; margin: 8px 0 20px; }
.cb-norms-table { width: 100%; border-collapse: collapse; font-size: 12px; }
.cb-norms-table th {
  background: #1a2744; color: #fff; padding: 6px 8px;
  text-align: center; font-weight: 600; white-space: nowrap; text-transform: none;
}
.cb-norms-table td {
  padding: 5px 8px; border-bottom: 1px solid #f1f5f9;
  text-align: right; font-size: 12px;
}
.cb-norms-table td.brand-col { text-align: left; font-weight: 500; }
.cb-norms-table tr.focal-row { background: #eff6ff; font-weight: 600; }
.cb-dev-pos { color: #166534; }
.cb-dev-neg { color: #991b1b; }
.cb-dev-large-pos { background: #dcfce7; color: #166534; font-weight: 600; }
.cb-dev-large-neg { background: #fee2e2; color: #991b1b; font-weight: 600; }

/* Heatmap (DoP) */
.cb-heatmap-wrap { overflow-x: auto; margin: 8px 0 20px; }
.cb-heatmap-table { border-collapse: collapse; font-size: 11px; }
.cb-heatmap-table th, .cb-heatmap-table td {
  padding: 4px 8px; border: 1px solid #e2e8f0;
}
.cb-heatmap-table th {
  background: #1a2744; color: #fff; font-weight: 600;
  text-align: center; text-transform: none;
}

/* Collapsible */
.cb-details-toggle {
  font-size: 12px; color: #64748b; cursor: pointer; text-decoration: underline;
  border: none; background: none; padding: 0; margin: 16px 0 8px; display: block;
}
.cb-details-content { display: none; }
.cb-details-content.open { display: block; }

/* Refusal block */
.cb-refused {
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px;
  padding: 12px 16px; margin: 8px 0 16px; font-size: 12px; color: #991b1b;
}

/* Focal brand dropdown (MA-style focus bar) */
.cb-focus-bar {
  display: flex; align-items: center; gap: 10px;
  margin: 6px 0 10px; padding: 8px 12px;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px;
}
.cb-focus-label {
  font-size: 11px; font-weight: 700; color: #475569;
  letter-spacing: 0.3px; white-space: nowrap;
}
.cb-focus-select {
  font-size: 13px; font-weight: 600; color: #1a2744;
  padding: 5px 10px; border: 1px solid #cbd5e1; border-radius: 6px;
  background: #fff; cursor: pointer; min-width: 180px;
}
.cb-focus-select:focus { outline: 2px solid var(--cb-focal-colour, #1A5276); outline-offset: 1px; }
.cb-panel.cb-on-context .cb-focus-bar { display: none; }

/* Panel-level brand picker */
.cb-brand-picker, .cb-ctl-row {
  display: flex; gap: 6px; flex-wrap: wrap; align-items: center; margin: 0 0 14px;
}
/* Hide the panel-level brand picker while the (category-level) Context tab
   is active — it has no focal-brand interactions. */
.cb-panel.cb-on-context .cb-brand-picker { display: none; }
/* Title-case variant of the control label (for the brand picker) */
.cb-ctl-label.cb-ctl-label-title {
  text-transform: none; letter-spacing: 0.2px;
  font-size: 12px; color: #475569;
}
/* Legacy focal chip (kept for backwards compat) */
.cb-focal-chip {
  background: #f1f5f9; border: 1px solid #e2e8f0; border-radius: 20px;
  padding: 4px 14px; font-size: 12px; cursor: pointer; color: #334155;
  transition: all 0.15s;
}
.cb-focal-chip.active {
  background: var(--cb-focal-colour, #1A5276); color: #fff;
  border-color: var(--cb-focal-colour, #1A5276);
}

/* Focal badge */
.cb-focal-badge, .fn-focal-badge {
  display: inline-block; font-size: 9px; font-weight: 700; letter-spacing: 0.05em;
  background: var(--cb-focal-colour, #1A5276); color: #fff; border-radius: 3px;
  padding: 1px 5px; margin-left: 6px; vertical-align: middle; font-style: normal;
}

.cb-perf-range {
  font-size: 9px; color: #94a3b8; font-style: normal; margin-top: 1px;
  font-weight: 400; white-space: nowrap;
}
.cb-sort-arr { font-size: 10px; opacity: 0.7; margin-left: 2px; }

/* Category Context tables */
.cb-context-tables {
  display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin: 16px 0;
}
@media (max-width: 560px) { .cb-context-tables { grid-template-columns: 1fr; } }
.cb-ctx-subtitle {
  font-size: 12px; font-weight: 600; color: #475569;
  margin: 0 0 6px; padding-bottom: 4px; border-bottom: 1px solid #e2e8f0;
}
.cb-ctx-stat {
  font-size: 12px; color: #334155; margin: 0 0 6px;
  padding: 4px 8px; background: #f0fdf4; border-radius: 4px;
  border-left: 3px solid #4ade80;
}
.cb-ctx-table { width: 100%; border-collapse: collapse; font-size: 12px; }
.cb-ctx-table th {
  background: #f1f5f9; color: #334155; padding: 5px 8px;
  text-align: left; font-weight: 600; border-bottom: 2px solid #e2e8f0;
}
.cb-ctx-table td {
  padding: 4px 8px; border-bottom: 1px solid #f1f5f9; font-size: 12px;
}

',
'/* Brand Performance Summary table (header style matches Brand Attitude) */
.cb-brand-freq-wrap { overflow-x: auto; margin: 8px 0 20px; }
.cb-brand-freq-table { width: 100%; border-collapse: separate;
  border-spacing: 0; font-size: 12px; }
/* High-specificity + !important so report-hub / page-builder th rules
   (which set uppercase + light background) cannot win. */
.cb-panel .cb-brand-freq-table thead tr th,
.cb-panel .cb-brand-freq-table th {
  background: #1e293b !important; background-color: #1e293b !important;
  color: #fff !important;
  padding: 8px 10px !important;
  text-align: center !important;
  font-weight: 600 !important; font-size: 11px !important;
  letter-spacing: 0.3px !important;
  text-transform: none !important;
  white-space: normal !important;
  border-bottom: 2px solid #0f172a !important;
  cursor: default;
}
.cb-panel .cb-brand-freq-table thead tr th:first-child,
.cb-panel .cb-brand-freq-table th:first-child { text-align: left !important; }
.cb-panel .cb-brand-freq-table th.cb-sort-th { cursor: pointer; user-select: none; }
.cb-panel .cb-brand-freq-table th.cb-sort-th:hover {
  background: #334155 !important; background-color: #334155 !important;
}
.cb-brand-freq-table .cb-sort-arr {
  display: inline-block; min-width: 14px; margin-left: 4px;
  font-size: 10px; color: rgba(255,255,255,0.6);
}
.cb-brand-freq-table th.cb-sort-th:hover .cb-sort-arr { color: #e2e8f0; }
.cb-brand-freq-table td {
  padding: 5px 8px; border-bottom: 1px solid #f1f5f9;
  text-align: right; font-size: 12px;
}
.cb-brand-freq-table td.brand-col { text-align: left; font-weight: 500; }
.cb-brand-freq-table tr.focal-row {
  background: #eff6ff; font-weight: 600;
  border-left: 3px solid var(--cb-focal-colour, #1A5276);
}
.cb-brand-freq-table tr.cbp-avg-row {
  font-style: italic; color: #475569; background: #f8fafc;
}
.cb-brand-freq-table tr.cbp-brand-row:hover { background: #f8fafc; }

/* MA-style sort indicator button inside the header */
.cb-brand-freq-table .ct-sort-indicator {
  background: transparent; border: none; color: rgba(255, 255, 255, 0.6);
  cursor: pointer; padding: 0 2px; margin-left: 4px; font-size: 11px;
  line-height: 1; transition: color 0.15s;
}
.cb-brand-freq-table .ct-sort-indicator:hover,
.cb-brand-freq-table .ct-sort-indicator[data-cb-sort-dir="asc"],
.cb-brand-freq-table .ct-sort-indicator[data-cb-sort-dir="desc"] {
  color: #e2e8f0;
}
.cb-brand-freq-table .ct-sort-indicator[data-cb-sort-dir="asc"]::after  { content: " \\25B2"; font-size: 9px; }
.cb-brand-freq-table .ct-sort-indicator[data-cb-sort-dir="desc"]::after { content: " \\25BC"; font-size: 9px; }
.cb-brand-freq-table .ct-header-text { display: inline-block; }

/* CI band under the Category avg cells (\u00b11 SD spread across brands) */
.cb-ci-band {
  display: block; margin-top: 2px; font-size: 9px; color: #94a3b8;
  font-style: italic; font-weight: 400; white-space: nowrap;
}

/* Heatmap cells (off by default; flip data-cb-heatmap="on" on the table) */
.cb-brand-freq-table[data-cb-heatmap="on"] td.cb-hm-above {
  background: rgba(5, 150, 105, 0.16) !important; color: #065f46;
}
.cb-brand-freq-table[data-cb-heatmap="on"] td.cb-hm-below {
  background: rgba(220, 38, 38, 0.14) !important; color: #991b1b;
}
.cb-brand-freq-table[data-cb-heatmap="on"] td.cb-hm-near {
  background: rgba(251, 191, 36, 0.18) !important; color: #92400e;
}

/* Brand Summary chart area (Show chart toggle) */
.cb-brands-chart-area { margin: 4px 0 12px; }
.cb-brands-chart-ctl {
  display: flex; align-items: center; gap: 8px;
  margin: 0 0 6px; padding: 6px 10px;
  background: #f1f5f9; border: 1px solid #e2e8f0;
  border-radius: 6px; font-size: 11px;
}
.cb-brands-chart-ctl-label {
  font-size: 11px; font-weight: 600; color: #475569;
  text-transform: uppercase; letter-spacing: 0.3px;
}
.cb-brands-chart-col {
  font-size: 12px; padding: 3px 8px; border: 1px solid #cbd5e1;
  border-radius: 4px; background: #fff; color: #1a2744; cursor: pointer;
}
.cb-brands-chart {
  display: flex; flex-direction: column; gap: 6px; padding: 10px 12px;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px;
}
.cb-brands-chart-row {
  display: grid; grid-template-columns: 140px 1fr; gap: 8px;
  align-items: center; font-size: 11px;
}
.cb-brands-chart-label {
  font-size: 11px; color: #334155; text-align: right;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap; padding-right: 6px;
}
.cb-brands-chart-label.focal { font-weight: 700; color: #1a2744; }
.cb-brands-chart-bar-track {
  flex: 1; height: 16px; background: #eef2f7; border-radius: 3px;
  overflow: hidden; position: relative;
}
.cb-brands-chart-bar {
  height: 100%; background: var(--cb-focal-colour, #1A5276);
  display: flex; align-items: center; justify-content: flex-end;
  padding-right: 6px; color: #fff; font-size: 10px; font-weight: 600;
  min-width: 18px;
}
.cb-brands-chart-avg-line {
  position: absolute; top: 0; bottom: 0; width: 1px;
  background: #0f172a; opacity: 0.5;
}
.cb-brands-chart-title {
  font-size: 11px; font-weight: 600; color: #475569;
  text-transform: uppercase; letter-spacing: 0.3px; margin-bottom: 2px;
}

',
'/* === Sub-tab navigation === */
.cb-subnav {
  display: flex; gap: 0; border-bottom: 2px solid #e2e8f0; margin: 16px 0;
}
.cb-subtab-btn {
  background: none; border: none; border-bottom: 3px solid transparent;
  margin-bottom: -2px; padding: 9px 16px; font-size: 13px; font-weight: 500;
  color: #94a3b8; cursor: pointer; transition: all 0.15s;
}
.cb-subtab-btn:hover { color: #64748b; }
.cb-subtab-btn.active {
  color: #1a2744; border-bottom-color: #1a2744; font-weight: 600;
}
.cb-subtab[hidden] { display: none !important; }

/* Controls bar */
.cb-controls-bar {
  display: flex; flex-wrap: wrap; align-items: center; gap: 10px 14px;
  margin-bottom: 12px; padding: 8px 10px;
  background: #f8fafc; border: 1px solid #eef2f7; border-radius: 8px;
}
.cb-ctl-group { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
.cb-ctl-label {
  font-size: 11px; font-weight: 600; color: #64748b;
  text-transform: uppercase; letter-spacing: 0.4px; white-space: nowrap;
}
.toggle-label, .cb-controls-bar .toggle-label {
  font-size: 12px; color: #334155; display: inline-flex;
  align-items: center; gap: 6px; cursor: pointer;
}
.toggle-label input { margin: 0; }

/* col-chip — palette-coloured brand chips */
.col-chip {
  font-size: 11px; padding: 3px 9px; border-radius: 12px;
  border: 1px solid var(--brand-chip-color, #64748b);
  background: var(--brand-chip-color, #64748b);
  color: #fff; cursor: pointer; transition: all 0.12s; font-weight: 500;
}
.col-chip:hover { filter: brightness(0.88); }
.col-chip.col-chip-off {
  background: #f1f5f9 !important; color: #94a3b8 !important;
  border-color: #e2e8f0 !important;
}
.ma-chip-row, .col-chip-bar {
  display: flex; flex-wrap: wrap; gap: 4px; align-items: center;
}

/* Emphasis chips (segment filters: All | Seg1 | Seg2 …) */
.col-chip.cb-rel-seg-chip {
  background: #f1f5f9 !important; border-color: #e2e8f0 !important;
  color: #334155 !important;
}
.col-chip.cb-rel-seg-chip.active {
  background: #1a2744 !important; color: #fff !important;
  border-color: #1a2744 !important;
}
.cb-emphasis-row {
  display: flex; flex-wrap: wrap; align-items: center; gap: 4px 6px;
  margin: 10px 0 8px; font-size: 11px; color: #64748b;
}

/* Brand Attitude-style table used for Loyalty & Distribution tabs */
.cb-panel .ct-table {
  width: 100%; border-collapse: collapse; font-size: 12px;
}
.cb-panel .ct-table .ct-th {
  background: #1a2744; color: #fff; padding: 6px 10px;
  font-weight: 600; white-space: nowrap; text-align: center;
  font-size: 11px; text-transform: none;
}
.cb-panel .ct-table .ct-th.ct-label-col {
  text-align: left; min-width: 140px;
}
.cb-panel .ct-table .ct-td {
  padding: 5px 10px; border-bottom: 1px solid #f1f5f9;
  text-align: right; font-size: 12px; vertical-align: middle;
}
.cb-panel .ct-table .ct-td.ct-label-col {
  text-align: left; font-weight: 500;
  background: #f8fafc; border-right: 1px solid #e2e8f0;
}
.cb-panel .ct-table .fn-row-focal .ct-td.ct-label-col {
  color: var(--cb-focal-colour, #1A5276);
  border-left: 3px solid var(--cb-focal-colour, #1A5276);
  font-weight: 700;
}
.cb-panel .ct-table .fn-row-avg-all .ct-td {
  background: #eff1f5 !important; font-style: italic; color: #475569;
}
.cb-panel .ct-table tr:hover .ct-td { background: #f8fafc; }
.cb-panel .ct-table .fn-row-avg-all:hover .ct-td { background: #eaecf2 !important; }
.cb-rel-section { overflow-x: auto; margin-bottom: 12px; }

/* Brand Attitude-style stacked bar chart */
.fn-rel-chart-area { margin: 4px 0 16px; }
.fn-rel-bar-row {
  display: flex; align-items: center; gap: 10px; min-height: 30px; padding: 2px 0;
}
.fn-rel-bar-row-focal .fn-rel-bar-track { height: 28px; }
.fn-rel-bar-row-avg .fn-rel-bar-label { font-style: italic; color: #64748b; }
.fn-rel-bar-label {
  width: 172px; min-width: 172px; font-size: 12px; font-weight: 500;
  color: #334155; text-align: right; padding-right: 8px;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.fn-rel-bar-area { flex: 1; display: flex; min-width: 0; }
.fn-rel-bar-track {
  flex: 1; display: flex; height: 24px; border-radius: 4px;
  overflow: hidden; background: #f1f5f9;
}
.fn-rel-seg {
  height: 100%; transition: background-color 0.18s;
  display: flex; align-items: center; justify-content: center;
  overflow: hidden; white-space: nowrap;
}

/* Row greyout (legacy matrix table) */
.cb-row-inactive { opacity: 0.4; }
.cb-row-inactive .cb-row-label-text { text-decoration: line-through; }
.cb-row-toggle { display: flex; align-items: center; gap: 5px; cursor: pointer; }
.cb-row-active-cb { margin: 0; cursor: pointer; }
.cb-row-label-text { cursor: pointer; }

/* Legacy matrix table (brands-as-columns format, kept for backwards compat) */
.cb-matrix-section { overflow-x: auto; margin-bottom: 12px; }
.cb-matrix-table {
  width: 100%; border-collapse: collapse; font-size: 12px; min-width: 400px;
}
.cb-matrix-table th {
  background: #1a2744; color: #fff; padding: 6px 10px;
  font-weight: 600; white-space: nowrap; text-align: center;
  font-size: 11px; text-transform: none;
}
.cb-matrix-table th.cb-focal-th { background: #1A5276; }
.cb-matrix-table td {
  padding: 5px 10px; border-bottom: 1px solid #f1f5f9;
  text-align: right; font-size: 12px;
}
.cb-matrix-table td.ct-label-col { text-align: left; }
.cb-matrix-table td.cb-focal-td {
  box-shadow: inset 2px 0 0 #1A5276, inset -2px 0 0 #1A5276; background: #eff6ff;
}

/* Dot chart section (legacy) */
.cb-chart-section { margin: 8px 0 16px; }
.cb-dot-chart { width: 100%; display: block; }
.ma-bar-gridline { stroke: #f1f5f9; stroke-width: 1; }
.ma-bar-label    { font-size: 9px; fill: #94a3b8; }
.ma-bar-group-label { font-size: 11px; fill: #334155; font-weight: 500; }
.ma-bar-cat-avg  { stroke: #94a3b8; stroke-width: 1.5; stroke-dasharray: 4 3; }
</style>'
)
}
