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

/* DoP table: group header above column labels */
.cb-dop-table .cb-dop-grouphdr th.cb-dop-group-lbl {
  background: #1a2744; color: #fff; font-weight: 600;
  font-size: 11px; letter-spacing: 0; text-transform: none;
  padding: 6px 8px; border-bottom: 1px solid #334155;
}
.cb-dop-table th.cb-dop-row-hdr { background: #1a2744; }
.cb-dop-table th.cb-dop-col-hdr {
  background: #1a2744; color: #fff; text-transform: none;
  font-weight: 600; font-size: 11px; letter-spacing: 0;
}
.cb-dop-table .cb-dop-row-lbl {
  background: #f8fafc; color: #1a2744; font-weight: 500;
  text-align: left; white-space: nowrap;
}
.cb-dop-table .cb-dop-diag {
  background: #e2e8f0; color: #94a3b8;
}
/* Average row first — italic, subtle backdrop */
.cb-dop-table tr.cb-dop-avg-row .cb-dop-avg-cell {
  background: #eff1f5; color: #475569; font-style: italic; font-weight: 500;
}
.cb-dop-table tr.cb-dop-avg-row .cb-dop-row-lbl {
  background: #eff1f5; color: #475569; font-style: italic;
}
/* Traffic-light heatmap — CI band (col avg ± 1 SD) */
.cb-dop-table td.cb-dop-cell.cb-dop-above {
  background: rgba(5, 150, 105, 0.22); color: #065f46; font-weight: 600;
}
.cb-dop-table td.cb-dop-cell.cb-dop-near {
  background: rgba(251, 191, 36, 0.22); color: #92400e;
}
.cb-dop-table td.cb-dop-cell.cb-dop-below {
  background: rgba(220, 38, 38, 0.20); color: #991b1b; font-weight: 600;
}
/* Focal row subtle emphasis */
.cb-dop-table tr.focal-row .cb-dop-row-lbl {
  border-left: 3px solid var(--cb-focal-colour, #1A5276);
  color: var(--cb-focal-colour, #1A5276); font-weight: 700;
}
/* DoP toolbar — reuse generic controls-bar look */
.cb-dop-section .cb-controls-bar {
  display: flex; gap: 14px; align-items: center; flex-wrap: wrap;
  margin: 4px 0 8px;
}
/* Cell values: %, and hidden n=X that the Show counts toggle reveals */
.cb-dop-table .cb-dop-cell .cb-val-pct {
  display: block; font-weight: 600; font-variant-numeric: tabular-nums;
}
.cb-dop-table .cb-dop-cell .cb-val-n {
  display: block; font-size: 10px; color: inherit; opacity: 0.75;
  font-weight: 400; margin-top: 1px; font-variant-numeric: tabular-nums;
}
.cb-dop-table .cb-dop-cell .cb-val-n[hidden] { display: none; }
/* Heatmap OFF → strip traffic-light colouring, keep text centred/readable */
.cb-dop-table[data-cb-heatmap="off"] td.cb-dop-cell {
  background: #ffffff !important; color: #334155 !important; font-weight: 500 !important;
}
/* Category avg CI mini-bar (funnel-style formatting) */
.cb-dop-table .cb-dop-avg-cell.cb-dop-avg-ci { padding-bottom: 6px; }
.cb-dop-table .cb-dop-avg-ci .cb-val-pct {
  display: block; font-weight: 700; color: #1e293b; font-size: 13px;
  font-variant-numeric: tabular-nums;
}
.cb-dop-table .cb-dop-avg-ci .ma-ci-bar-wrap {
  position: relative; height: 6px; background: #dde3eb;
  border-radius: 3px; margin: 4px 0 2px; overflow: visible;
}
.cb-dop-table .cb-dop-avg-ci .ma-ci-bar-range {
  position: absolute; height: 100%; border-radius: 3px;
  background: linear-gradient(90deg, rgba(71,85,105,0.25), rgba(71,85,105,0.5));
}
.cb-dop-table .cb-dop-avg-ci .ma-ci-bar-tick {
  position: absolute; width: 2px; height: 140%; top: -20%;
  background: #475569; border-radius: 1px; transform: translateX(-50%);
}
.cb-dop-table .cb-dop-avg-ci .ma-ci-limits {
  display: flex; justify-content: space-between; font-size: 9px;
  color: #94a3b8; margin-top: 1px; font-variant-numeric: tabular-nums;
}
.cb-dop-table .cb-dop-avg-ci .ma-ci-limits span { line-height: 1; }

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
/* Funnel-style CI mini-bar on the Brand Summary Category avg row. Reuses the
   same .ma-ci-bar-* classes as the Metrics tab, DoP, and Brand Attitude. */
.cb-brand-freq-table td.cb-avg-td.cb-avg-td-ci {
  padding-bottom: 6px; vertical-align: top; text-align: center;
}
.cb-brand-freq-table td.cb-avg-td.cb-avg-td-ci .cb-val-pct {
  display: block; font-weight: 700; color: #1e293b; font-size: 13px;
  font-variant-numeric: tabular-nums; font-style: normal;
}
.cb-brand-freq-table td.cb-avg-td.cb-avg-td-ci .ma-ci-bar-wrap {
  position: relative; height: 6px; background: #dde3eb;
  border-radius: 3px; margin: 4px 0 2px; overflow: visible;
}
.cb-brand-freq-table td.cb-avg-td.cb-avg-td-ci .ma-ci-bar-range {
  position: absolute; height: 100%; border-radius: 3px;
  background: linear-gradient(90deg, rgba(71,85,105,0.25), rgba(71,85,105,0.5));
}
.cb-brand-freq-table td.cb-avg-td.cb-avg-td-ci .ma-ci-bar-tick {
  position: absolute; width: 2px; height: 140%; top: -20%;
  background: #475569; border-radius: 1px; transform: translateX(-50%);
}
.cb-brand-freq-table td.cb-avg-td.cb-avg-td-ci .ma-ci-limits {
  display: flex; justify-content: space-between; font-size: 9px;
  color: #94a3b8; margin-top: 1px; font-variant-numeric: tabular-nums;
  font-style: normal;
}
.cb-brand-freq-table td.cb-avg-td.cb-avg-td-ci .ma-ci-limits span { line-height: 1; }

/* Funnel-style CI mini-bar on the Loyalty & Purchase Distribution Category avg
   row (.cb-rel-table). Same visual contract as Brand Summary / DoP / MA. */
.cb-panel .cb-rel-table td.cb-avg-seg-ci {
  padding-bottom: 6px; vertical-align: top; text-align: center;
}
.cb-panel .cb-rel-table td.cb-avg-seg-ci .cb-val-pct {
  display: block; font-weight: 700; color: #1e293b; font-size: 13px;
  font-variant-numeric: tabular-nums; font-style: normal;
}
.cb-panel .cb-rel-table td.cb-avg-seg-ci .ma-ci-bar-wrap {
  position: relative; height: 6px; background: #dde3eb;
  border-radius: 3px; margin: 4px 0 2px; overflow: visible;
}
.cb-panel .cb-rel-table td.cb-avg-seg-ci .ma-ci-bar-range {
  position: absolute; height: 100%; border-radius: 3px;
  background: linear-gradient(90deg, rgba(71,85,105,0.25), rgba(71,85,105,0.5));
}
.cb-panel .cb-rel-table td.cb-avg-seg-ci .ma-ci-bar-tick {
  position: absolute; width: 2px; height: 140%; top: -20%;
  background: #475569; border-radius: 1px; transform: translateX(-50%);
}
.cb-panel .cb-rel-table td.cb-avg-seg-ci .ma-ci-limits {
  display: flex; justify-content: space-between; font-size: 9px;
  color: #94a3b8; margin-top: 1px; font-variant-numeric: tabular-nums;
  font-style: normal;
}
.cb-panel .cb-rel-table td.cb-avg-seg-ci .ma-ci-limits span { line-height: 1; }
',
'
/* Heatmap cells (off by default; flip data-cb-heatmap="on" on the table) */
.cb-brand-freq-table[data-cb-heatmap="on"] td.cb-hm-above,
.cb-panel .ct-table[data-cb-heatmap="on"] td.cb-hm-above {
  background: rgba(5, 150, 105, 0.16) !important; color: #065f46;
}
.cb-brand-freq-table[data-cb-heatmap="on"] td.cb-hm-below,
.cb-panel .ct-table[data-cb-heatmap="on"] td.cb-hm-below {
  background: rgba(220, 38, 38, 0.14) !important; color: #991b1b;
}
.cb-brand-freq-table[data-cb-heatmap="on"] td.cb-hm-near,
.cb-panel .ct-table[data-cb-heatmap="on"] td.cb-hm-near {
  background: rgba(251, 191, 36, 0.18) !important; color: #92400e;
}

/* Loyalty/Dist segment cells: % is primary, n=X shown below when show-counts on */
.cb-panel .ct-table .cb-seg-cell { line-height: 1.25; }
.cb-panel .ct-table .cb-seg-cell .cb-val-pct {
  display: block; font-weight: 600;
}
.cb-panel .ct-table .cb-seg-cell .cb-val-n {
  display: block; font-size: 10px; color: #94a3b8;
  font-weight: 400; margin-top: 1px;
}
.cb-panel .ct-table .cb-seg-cell .cb-val-n[hidden] { display: none; }
.cb-panel .ct-table .cb-avg-row .cb-ci-band {
  display: inline-block; margin-left: 4px; font-size: 9px;
  color: #94a3b8; font-style: italic; font-weight: 400;
}
.cb-panel .ct-table .cb-col-buyers,
.cb-panel .ct-table .cb-col-base {
  font-variant-numeric: tabular-nums;
  color: #475569;
  background: #fcfcfd;
  border-right: 1px solid #eef2f7;
}
.cb-panel .ct-table th.cb-col-buyers,
.cb-panel .ct-table th.cb-col-base {
  background: #1a2744; color: #fff;
}

/* Sortable headers (loyalty/dist + DoP tables) */
.cb-panel .ct-table thead th.cb-sortable,
.cb-panel .cb-dop-table thead th.cb-sortable {
  cursor: pointer; user-select: none; position: relative;
}
.cb-panel .ct-table thead th.cb-sortable:hover,
.cb-panel .cb-dop-table thead th.cb-sortable:hover { background: #233255; }
.cb-panel .ct-table thead th.cb-sortable .cb-sort-ind,
.cb-panel .cb-dop-table thead th.cb-sortable .cb-sort-ind {
  display: inline-block; width: 10px; margin-left: 4px;
  font-size: 9px; color: #cbd5e1; opacity: 0.85;
}
/* Neutral dual-arrow glyph at rest shows sortable affordance */
.cb-panel .ct-table thead th.cb-sortable[data-cb-sort-dir="none"] .cb-sort-ind::after,
.cb-panel .cb-dop-table thead th.cb-sortable[data-cb-sort-dir="none"] .cb-sort-ind::after {
  content: "\\2B83"; font-size: 10px; opacity: 0.55;
}
.cb-panel .ct-table thead th.cb-sortable[data-cb-sort-dir="asc"]  .cb-sort-ind::after,
.cb-panel .cb-dop-table thead th.cb-sortable[data-cb-sort-dir="asc"]  .cb-sort-ind::after { content: "\\25B2"; }
.cb-panel .ct-table thead th.cb-sortable[data-cb-sort-dir="desc"] .cb-sort-ind::after,
.cb-panel .cb-dop-table thead th.cb-sortable[data-cb-sort-dir="desc"] .cb-sort-ind::after { content: "\\25BC"; }
.cb-panel .ct-table thead th.cb-sortable[data-cb-sort-dir="asc"]  .cb-sort-ind,
.cb-panel .ct-table thead th.cb-sortable[data-cb-sort-dir="desc"] .cb-sort-ind,
.cb-panel .cb-dop-table thead th.cb-sortable[data-cb-sort-dir="asc"]  .cb-sort-ind,
.cb-panel .cb-dop-table thead th.cb-sortable[data-cb-sort-dir="desc"] .cb-sort-ind { opacity: 1; color: #fff; }

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
  display: flex; flex-direction: row; align-items: center; flex-wrap: wrap;
  gap: 10px 14px; margin-bottom: 12px; padding: 8px 10px;
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
.col-chip.col-chip-off,
.cb-panel .col-chip-bar .fn-rel-brand-chip.col-chip-off,
.cb-panel .col-chip-bar .fn-rel-brand-chip.col-chip-off.active {
  background: #f1f5f9 !important;
  background-color: #f1f5f9 !important;
  color: #94a3b8 !important;
  border-color: #e2e8f0 !important;
  text-decoration: line-through !important;
  opacity: 0.6 !important;
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

/* Info callout (column definitions) */
.cb-panel details.cb-info-callout {
  margin: 6px 0 12px; background: #f8fafc;
  border: 1px solid #e2e8f0; border-radius: 8px;
  padding: 6px 12px; font-size: 12px; color: #334155;
}
.cb-panel details.cb-info-callout > summary {
  cursor: pointer; font-weight: 600; color: #1a2744;
  list-style: none; padding: 4px 0;
}
.cb-panel details.cb-info-callout > summary::-webkit-details-marker { display: none; }
.cb-panel details.cb-info-callout[open] > summary { margin-bottom: 4px; }
.cb-panel details.cb-info-callout .cb-info-body ul {
  margin: 4px 0 6px 18px; padding: 0; line-height: 1.55;
}
.cb-panel details.cb-info-callout .cb-info-body li { margin: 2px 0; }

/* Toolbar-relocated pin/export buttons inside the brands controls bar */
.cb-panel .cb-controls-bar .cb-toolbar-relocated {
  margin-left: auto; display: inline-flex; gap: 6px; align-items: center;
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
  overflow: visible; white-space: nowrap; position: relative;
}
.fn-rel-seg-lbl {
  font-size: 11px; font-weight: 700; color: #fff;
  padding: 0 4px; text-shadow: 0 0 2px rgba(0,0,0,0.45);
  white-space: nowrap;
}
/* Tiny segments: keep the label INSIDE the segment. Tighten font and
   let it overflow the coloured block horizontally so e.g. "4%" is still
   legible without floating above the track. */
.fn-rel-seg-tiny { min-width: 6px; overflow: visible; }
.fn-rel-seg-lbl-tiny {
  font-size: 9px; font-weight: 700; color: #fff;
  text-shadow: 0 0 3px rgba(0,0,0,0.7), 0 0 2px rgba(0,0,0,0.55);
  padding: 0 1px; white-space: nowrap;
  pointer-events: none;
}

/* Emphasis chips — active state uses the segment colour (set via inline
   data-cb-seg-color → CSS custom prop applied in JS). */
.col-chip.cb-rel-seg-chip[data-cb-seg-color].active {
  background: var(--brand-chip-color) !important;
  border-color: var(--brand-chip-color) !important;
  color: #fff !important;
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

/* === Shopper Behaviour sub-tab — fitting overrides =====================
   These rules drop the .cb-panel ancestor on purpose: when sections
   are captured for pin / PNG export the cloned HTML lives outside
   .cb-panel, so any panel-scoped rule stops applying. Selectors here
   key off classes / data-attributes that travel with the captured
   element. !important is used to beat the design-system base rule
   (th[class*="-th"] { text-transform: uppercase; white-space: nowrap; })
   which would otherwise win in the pin context where the scoped panel
   override no longer applies. */

/* Compact KPI-chip variant used by Shopper Behaviour summary chips.
   Smaller value font for long channel / pack-size labels and a wrap-
   friendly width cap. Used both inline on the Context tab and when
   the chip strip is captured into a pin. */
.cb-kpi-chip.cb-kpi-chip-text {
  min-width: 150px; max-width: 240px; padding: 8px 14px;
}
.cb-kpi-chip.cb-kpi-chip-text .cb-kpi-val {
  font-size: 14px !important; line-height: 1.25; font-weight: 600;
  white-space: normal !important;
  overflow-wrap: break-word; word-break: keep-all;
}
.cb-kpi-chip.cb-kpi-chip-text .cb-kpi-label {
  white-space: normal !important; line-height: 1.2;
}

/* Shopper section column headers: wrap multi-word labels and keep them
   at sensible width regardless of capture context. The brand label
   column is intentionally kept nowrap as a clean row stub. */
.cb-rel-section[data-cb-scope^="shop_"] .ct-table .ct-th {
  white-space: normal !important; text-transform: none !important;
  line-height: 1.25; max-width: 110px;
  word-break: keep-all; overflow-wrap: break-word; hyphens: auto;
  letter-spacing: 0 !important;
}
.cb-rel-section[data-cb-scope^="shop_"] .ct-table .ct-th .cb-th-label {
  white-space: normal !important; display: inline-block; max-width: 100%;
  text-transform: none !important;
}
.cb-rel-section[data-cb-scope^="shop_"] .ct-table .ct-th.ct-label-col {
  max-width: none; min-width: 130px; white-space: nowrap !important;
}
</style>'
)
}
