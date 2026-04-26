# ==============================================================================
# BRAND MODULE - PORTFOLIO PANEL CSS (shell only)
# ==============================================================================
# Scoped to .pf-* prefix to avoid collisions with funnel (.fn-*) and MA (.ma-*).
# Overview-subtab-specific (.pfo-*) styles live in
# 09_portfolio_overview_subtab_styling.R and are loaded alongside this bundle
# by 99_html_report_main.R.
# ==============================================================================

#' Build portfolio panel CSS bundle
#'
#' @param focal_colour Character. Hex colour for the focal brand.
#' @return Character. CSS string.
#' @keywords internal
build_portfolio_panel_styles <- function(focal_colour = "#1A5276") {
  # Use a `%FOCAL%` template + gsub instead of sprintf — sprintf has an
  # 8192-char format-string limit that this bundle has now outgrown,
  # plus single-character `%` literals (in CSS comments etc.) crash
  # sprintf and silently drop the entire portfolio CSS.
  tmpl <- "
/* ---- Portfolio Panel ---- */
.pf-panel { width:100%; }
.pf-sub-nav {
  display: flex;
  gap: 4px;
  padding: 0 0 16px 0;
  border-bottom: 1px solid #e2e8f0;
  margin-bottom: 20px;
  flex-wrap: wrap;
}
.pf-sub-btn {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  color: #64748b;
  cursor: pointer;
  font-size: 12px;
  font-weight: 500;
  padding: 6px 14px;
  transition: all 0.15s;
}
.pf-sub-btn:hover { background: #f1f5f9; color: #1e293b; }
.pf-sub-btn.active {
  background: %FOCAL%;
  border-color: %FOCAL%;
  color: #fff;
  font-weight: 600;
}
.pf-subtab { display: none; }
.pf-subtab.active { display: block; }
.pf-hero-strip {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  margin-bottom: 24px;
}
.pf-kpi-card {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  flex: 1;
  min-width: 160px;
  padding: 14px 16px;
  text-align: center;
}
.pf-kpi-value {
  color: %FOCAL%;
  font-size: 28px;
  font-weight: 700;
  line-height: 1.1;
}
.pf-kpi-label {
  color: #64748b;
  font-size: 11px;
  margin-top: 4px;
}
.pf-about-drawer {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  color: #64748b;
  font-size: 11px;
  line-height: 1.6;
  margin-top: 16px;
  padding: 12px 16px;
}
.pf-suppression-note {
  background: #fefce8;
  border: 1px solid #fde68a;
  border-radius: 6px;
  color: #92400e;
  font-size: 11px;
  margin-top: 12px;
  padding: 8px 12px;
}
.pf-coming-soon {
  align-items: center;
  color: #94a3b8;
  display: flex;
  font-size: 13px;
  justify-content: center;
  min-height: 200px;
}
.pf-brand-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 16px;
}
.pf-brand-chip {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 20px;
  color: #64748b;
  cursor: pointer;
  font-size: 11px;
  font-weight: 500;
  padding: 4px 12px;
  transition: all 0.15s;
}
.pf-brand-chip:hover { background: #f1f5f9; color: #1e293b; }
.pf-brand-chip.active {
  background: %FOCAL%;
  border-color: %FOCAL%;
  color: #fff;
  font-weight: 600;
}

/* ---- Footprint table (new HTML view) ---- */
.pf-fp-controls {
  display: flex; flex-wrap: wrap; gap: 16px 24px; align-items: flex-start;
  margin: 4px 0 16px;
}
.pf-fp-ctl-group { display: flex; flex-direction: column; gap: 6px; min-width: 180px; }
.pf-fp-chips-group  { flex: 1 1 auto; min-width: 0; }
.pf-fp-toggles-group { flex: 0 0 auto; }
.pf-fp-ctl-label {
  font-size: 11px; font-weight: 600; color: #64748b;
  text-transform: uppercase; letter-spacing: 0.5px;
}
.pf-fp-focal-select {
  border: 1px solid #e2e8f0; border-radius: 6px; background: #fff;
  font-size: 13px; padding: 6px 10px; color: #1e293b; min-width: 200px;
}
.pf-fp-focal-select:focus { outline: 2px solid %FOCAL%; outline-offset: 1px; }
/* Brand row: focal pill + popover trigger. */
.pf-fp-brands-row {
  display: inline-flex; align-items: center; gap: 8px;
  flex-wrap: wrap; position: relative;
}
.pf-fp-focal-chip {
  display: inline-flex; align-items: center; gap: 6px;
  background: #fff; border: 1px solid #e2e8f0; border-radius: 16px;
  color: #1e293b; font-size: 12px; font-weight: 600;
  padding: 4px 10px;
}
.pf-fp-focal-chip-dot {
  display: inline-block; width: 10px; height: 10px; border-radius: 50%;
  flex-shrink: 0;
}
.pf-fp-pop-btn {
  display: inline-flex; align-items: center; gap: 8px;
  background: #fff; border: 1px solid #cbd5e1; border-radius: 8px;
  color: #1e293b; font-size: 12px; font-weight: 500;
  padding: 6px 12px; cursor: pointer; transition: all 0.15s;
}
.pf-fp-pop-btn:hover { background: #f8fafc; border-color: #94a3b8; }
.pf-fp-pop-btn[aria-expanded='true'] { border-color: %FOCAL%; box-shadow: 0 0 0 3px rgba(26,82,118,0.12); }
.pf-fp-pop-btn-count {
  font-size: 11px; color: #64748b; font-weight: 500;
}

/* Popover panel — sits below the trigger. The [hidden] override is
   essential: `display:flex` here would otherwise win over the browser's
   default [hidden] { display: none }, so toggling pop.hidden in JS would
   leave the panel permanently visible. */
.pf-fp-pop {
  position: absolute; top: calc(100% + 6px); left: 0; z-index: 30;
  min-width: 280px; max-width: 360px; max-height: 360px;
  background: #fff; border: 1px solid #cbd5e1; border-radius: 8px;
  box-shadow: 0 12px 32px rgba(15,23,42,0.18), 0 2px 6px rgba(15,23,42,0.08);
  display: flex; flex-direction: column; overflow: hidden;
}
.pf-fp-pop[hidden] { display: none !important; }
.pf-fp-pop-search {
  padding: 8px 10px 6px; border-bottom: 1px solid #f1f5f9;
}
.pf-fp-pop-input {
  width: 100%; box-sizing: border-box;
  border: 1px solid #e2e8f0; border-radius: 6px;
  padding: 6px 10px; font-size: 12px; color: #1e293b;
  background: #f8fafc;
}
.pf-fp-pop-input:focus { outline: 2px solid %FOCAL%; outline-offset: 1px; background: #fff; }
.pf-fp-pop-actions {
  display: flex; gap: 6px; padding: 6px 10px;
  border-bottom: 1px solid #f1f5f9; background: #f8fafc;
}
.pf-fp-pop-action {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 14px;
  font-size: 11px; font-weight: 500; color: #475569;
  padding: 3px 10px; cursor: pointer;
}
.pf-fp-pop-action:hover { background: #f1f5f9; color: #1e293b; }
.pf-fp-pop-list {
  overflow-y: auto; flex: 1 1 auto; padding: 4px 0;
}
.pf-fp-pop-item {
  display: flex; align-items: center; gap: 8px;
  padding: 6px 10px; cursor: pointer; font-size: 12px; color: #1e293b;
  transition: background 0.12s;
}
.pf-fp-pop-item:hover { background: #f8fafc; }
.pf-fp-pop-item-focal {
  background: #f8fafc; font-weight: 600;
  border-bottom: 1px solid #e2e8f0;
}
.pf-fp-pop-cb { margin: 0; flex-shrink: 0; }
.pf-fp-pop-dot {
  display: inline-block; width: 10px; height: 10px; border-radius: 50%;
  flex-shrink: 0;
}
.pf-fp-pop-name { flex: 1 1 auto; }

/* Category chip row. Smaller + tighter than brand chips. */
.pf-fp-cat-chips { display: flex; flex-wrap: wrap; gap: 4px; }
.pf-fp-cat-chip {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 14px;
  color: #475569; font-size: 11px; font-weight: 500;
  padding: 3px 10px; cursor: pointer; transition: all 0.12s;
  text-transform: lowercase;
}
.pf-fp-cat-chip:hover { background: #f8fafc; color: #1e293b; }
.pf-fp-cat-chip-on  { background: #fff; color: #1e293b; }
.pf-fp-cat-chip-off { background: #f1f5f9; color: #94a3b8; opacity: 0.55; }
.pf-fp-toggles { display: flex; flex-direction: column; gap: 4px; }
.pf-fp-toggles .toggle-label {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 12px; color: #475569; cursor: pointer;
}

/* ---- Header strip — solid navy, no per-cell breaks. ---- */
.pf-fp-table-wrap {
  width: 100%; overflow-x: auto;
  border: 1px solid #e2e8f0; border-radius: 8px;
  background: #fff;
}
.pf-fp-table {
  width: 100%; border-collapse: collapse; border-spacing: 0;
  font-size: 12px; table-layout: auto;
}
/* The <th> itself is the click target (no inner <button>) so the
   thead reads as one continuous navy bar — no native button-face
   leaking between cells. */
.pf-fp-table thead { background: #1a2744; }
.pf-fp-table thead tr { background: #1a2744; }
.pf-fp-table thead th {
  background: #1a2744; color: #fff;
  padding: 10px 8px; vertical-align: bottom;
  border: 0; border-bottom: 2px solid #0f172a;
  text-align: center; user-select: none;
}
.pf-fp-th-sort { cursor: pointer; transition: background 0.12s; }
.pf-fp-th-sort:hover { background: #243353; }
.pf-fp-th-sort:focus-visible { outline: 2px solid #93c5fd; outline-offset: -2px; }
.pf-fp-th-brand {
  text-align: left; min-width: 220px;
  padding: 10px 14px;
  position: sticky; left: 0; z-index: 2;
}
.pf-fp-th-inner {
  display: flex; flex-direction: column; align-items: center; gap: 2px;
  line-height: 1.25;
}
.pf-fp-th-brand .pf-fp-th-inner { align-items: flex-start; }
.pf-fp-th-label {
  font-size: 11px; font-weight: 600; letter-spacing: 0.3px;
  white-space: normal; line-height: 1.25;
  text-transform: lowercase;
}
.pf-fp-th-base {
  font-size: 10px; color: #cbd5e1; font-weight: 400; font-style: italic;
  margin-top: 2px;
}
.pf-fp-th-pen {
  font-size: 10px; color: #93c5fd; font-weight: 500;
  margin-top: 1px;
}
.pf-fp-th-pen:empty { display: none; }
.pf-fp-sort-ind {
  font-size: 11px; color: #cbd5e1; margin-top: 2px;
  letter-spacing: -0.5px;
}
.pf-fp-th-sort[data-pf-fp-active='1'] .pf-fp-sort-ind { color: #fff; }
.pf-fp-th-lowbase .pf-fp-th-label::after {
  content: ' \\2020'; color: #f59e0b; font-weight: 700;
}

/* ---- Body rows ---- */
.pf-fp-table tbody th.pf-fp-row-label {
  text-align: left; padding: 8px 14px; font-weight: 500;
  font-size: 12px; color: #1e293b; background: #fff;
  border-bottom: 1px solid #f1f5f9; white-space: nowrap;
  text-transform: lowercase;
  position: sticky; left: 0; z-index: 1;
  min-width: 220px;
}
.pf-fp-row-focal th.pf-fp-row-label {
  font-weight: 700; color: %FOCAL%;
  border-left: 3px solid %FOCAL%; background: #f8fafc;
}
.pf-fp-row-focal th.pf-fp-row-label .pf-fp-row-label-text { text-transform: lowercase; }
.pf-fp-row-other:hover td,
.pf-fp-row-other:hover th.pf-fp-row-label { background: #f3f6fa; }

.pf-fp-table td.pf-fp-td {
  padding: 7px 8px; text-align: center; vertical-align: middle;
  border-bottom: 1px solid #f1f5f9; font-variant-numeric: tabular-nums;
  font-weight: 500; min-width: 64px; line-height: 1.25;
}
.pf-fp-td-na { color: #cbd5e1; background: #fafafa; }

/* Categories-per-brand column — sits immediately right of the brand
   label as a portfolio-summary column, visually divided from the
   heatmap cells with a stronger right border. */
.pf-fp-th-cats {
  min-width: 92px;
  border-right: 2px solid #0f172a;
}
.pf-fp-td-cats {
  background: #f8fafc;
  font-weight: 600; color: #1e293b;
  font-variant-numeric: tabular-nums;
  border-right: 2px solid #cbd5e1;
}
.pf-fp-cats-num { font-size: 13px; }
.pf-fp-cats-of  { font-size: 10px; color: #94a3b8; margin-left: 1px; }

/* Cell content stack — percentage on top, optional count below. */
.pf-fp-pct { display: block; }
.pf-fp-n   { display: none; font-size: 10px; color: rgba(15,23,42,0.55); margin-top: 2px; }
.pf-fp-table-wrap.pf-fp-show-counts .pf-fp-n { display: block; }

/* Heat-cell colouring drives off two CSS custom properties so the
   Show-heatmap toggle can flip them in one place. */
.pf-fp-heat-cell {
  background: var(--pf-fp-bg, transparent);
  color:      var(--pf-fp-fg, #1e293b);
}
.pf-fp-table-wrap.pf-fp-heatmap-off .pf-fp-heat-cell {
  background: transparent !important;
  color:      #1e293b      !important;
}
.pf-fp-table-wrap.pf-fp-heatmap-off .pf-fp-n { color: #94a3b8; }

.pf-fp-suppressed-note {
  font-size: 11px; color: #94a3b8; margin: 8px 4px 0; font-style: italic;
}
"
  gsub("%FOCAL%", focal_colour, tmpl, fixed = TRUE)
}
