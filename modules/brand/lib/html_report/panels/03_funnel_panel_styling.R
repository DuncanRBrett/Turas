# ==============================================================================
# BRAND MODULE - FUNNEL PANEL CSS BUNDLE
# ==============================================================================
# Core table/chrome classes (ct-*) are lifted from the tabs module CSS so the
# funnel panel looks visually identical to a tabs crosstab card. The tabs
# module's own <style> block is NOT included in the brand report, so this
# bundle must carry its own copy of the classes it uses.
#
# Funnel-specific styles (fn-*) are layered on top for things tabs doesn't
# express: sub-tab nav, focus dropdown, stage popovers, relationship bars.
# ==============================================================================


#' Return the <style> block with funnel panel CSS
#'
#' @param brand_colour Character. Hex colour string used as the CSS
#'   \code{--fn-brand} variable.
#' @return Character. A single \code{<style>...</style>} string.
#' @export
build_funnel_panel_styles <- function(brand_colour = "#1A5276") {
  css <- gsub("--FN-BRAND--", brand_colour, .fn_panel_css_body(), fixed = TRUE)
  paste0('<style class="fn-panel-styles">', css, '</style>')
}


#' Raw CSS body (heredoc, no R interpolation).
#' @keywords internal
.fn_panel_css_body <- function() {
'/* === FUNNEL PANEL === */
.fn-panel {
  --fn-brand: --FN-BRAND--;
  font-family: Inter, system-ui, -apple-system, sans-serif;
  color: #1e293b;
  max-width: 1400px;
  margin: 0 auto;
  padding: 0;
}

/* -------------------------------------------------------------------------- */
/* Title card + sub-tab nav                                                   */
/* -------------------------------------------------------------------------- */
.fn-title-card {
  background: #fff;
  border: 1px solid #e2e8f0; border-radius: 8px;
  padding: 14px 18px; margin-bottom: 12px;
}
.fn-title-card-top {
  display: flex; align-items: center; justify-content: space-between;
}
.fn-title {
  margin: 0; font-size: 15px; font-weight: 700; color: #1e293b;
  letter-spacing: 0.2px; display: flex; align-items: center; gap: 6px;
}
.fn-title-caret { font-size: 10px; color: #94a3b8; cursor: pointer; }
.fn-title-sub {
  margin-top: 4px; font-size: 12px; color: #64748b;
}
.fn-title-sub strong { color: #1e293b; font-weight: 700; }
.fn-pin-btn.pin-btn {
  width: 28px; height: 28px; padding: 0; cursor: pointer;
  border: 1px solid #e2e8f0; border-radius: 6px; background: #fff;
  font-size: 14px;
}
.fn-pin-btn.pin-btn:hover { border-color: var(--fn-brand); }

.fn-subnav {
  display: flex; gap: 0; border-bottom: 1px solid #e2e8f0;
  margin-bottom: 14px;
}
.fn-subtab-btn {
  padding: 8px 16px; background: transparent; border: none;
  font-size: 13px; font-weight: 600; color: #64748b;
  cursor: pointer; font-family: inherit;
  border-bottom: 2px solid transparent; margin-bottom: -1px;
}
.fn-subtab-btn:hover:not(.active) { color: #1e293b; }
.fn-subtab-btn.active {
  color: var(--fn-brand);
  border-bottom-color: var(--fn-brand);
}
.fn-subtab[hidden] { display: none; }

/* -------------------------------------------------------------------------- */
/* Controls — tabs .toggle-label pill toggles, sig-level-switcher segmented  */
/* -------------------------------------------------------------------------- */
.fn-focus-bar {
  display: flex; align-items: center; gap: 10px;
  padding: 10px 14px; background: #f8fafc;
  border: 1px solid #e2e8f0; border-radius: 8px;
  margin-bottom: 14px;
}
.fn-ctl-label {
  font-size: 11px; font-weight: 600; color: #64748b;
  text-transform: uppercase; letter-spacing: 0.6px;
}
.fn-focus-select {
  padding: 6px 28px 6px 12px;
  border: 1px solid #e2e8f0; border-radius: 6px;
  background: #fff; font-family: inherit; font-size: 12px;
  color: #1e293b; cursor: pointer;
}

.fn-controls.controls-bar {
  display: flex; flex-wrap: wrap; align-items: center; gap: 10px 14px;
  padding: 10px 14px; background: #f8fafc;
  border: 1px solid #e2e8f0; border-radius: 8px;
  margin-bottom: 10px;
}
.fn-controls .fn-ctl-group {
  display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
}
.fn-chip-row.col-chip-bar {
  display: flex; flex-wrap: wrap; gap: 4px;
  padding: 0; border: none; margin: 0; background: transparent;
}
.fn-chip-row .col-chip {
  padding: 5px 12px; border: 1px solid #e2e8f0; border-radius: 16px;
  background: #f0fafa; color: #1e293b; font-size: 11px; font-weight: 500;
  cursor: pointer; font-family: inherit; transition: all 0.15s;
}
.fn-chip-row .col-chip:hover { border-color: var(--fn-brand); }
.fn-chip-row .col-chip-off {
  background: #f8f9fa; color: #94a3b8;
  text-decoration: line-through; opacity: 0.55;
}

/* Tabs .toggle-label — pill with checkbox, checked-state filled */
.fn-panel .toggle-label {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 12px; color: #64748b;
  padding: 5px 12px; border: 1px solid #e2e8f0; border-radius: 16px;
  background: #fff; cursor: pointer; transition: all 0.15s;
  font-family: inherit;
}
.fn-panel .toggle-label:hover { border-color: #94a3b8; }
.fn-panel .toggle-label:has(input:checked) {
  background: #f0f4f8; border-color: var(--fn-brand); color: #1e293b;
}
.fn-panel .toggle-label input { accent-color: var(--fn-brand); cursor: pointer; }

/* Tabs .sig-level-switcher segmented button */
.fn-panel .sig-level-switcher {
  display: inline-flex; align-items: center; gap: 4px;
}
.fn-panel .sig-level-label {
  font-size: 11px; color: #64748b; white-space: nowrap; font-weight: 600;
  text-transform: uppercase; letter-spacing: 0.4px;
}
.fn-panel .sig-btn {
  font-size: 11px; font-weight: 500;
  padding: 5px 10px; border: 1px solid #e2e8f0; background: #fff;
  color: #1e293b; cursor: pointer; font-family: inherit;
  line-height: 1.4; transition: background 0.1s, color 0.1s;
}
.fn-panel .sig-btn:first-of-type { border-radius: 4px 0 0 4px; }
.fn-panel .sig-btn:last-of-type  { border-radius: 0 4px 4px 0; border-left: none; }
.fn-panel .sig-btn-active {
  background: var(--fn-brand); color: #fff; border-color: var(--fn-brand);
}
.fn-panel .sig-btn:hover:not(.sig-btn-active) { background: #e2e8f0; }

/* Tabs .export-btn — icon + dropdown caret */
.fn-panel .export-btn {
  padding: 5px 12px; font-size: 11px; font-weight: 600;
  background: #fff; color: var(--fn-brand);
  border: 1px solid var(--fn-brand); border-radius: 6px;
  cursor: pointer; font-family: inherit;
  display: inline-flex; align-items: center; gap: 4px;
}
.fn-panel .export-btn:hover { background: var(--fn-brand); color: #fff; }

/* -------------------------------------------------------------------------- */
/* TABLE — lifted from tabs ct-* classes (03a_page_styling.R)                 */
/* -------------------------------------------------------------------------- */
.fn-panel .ct-table {
  width: 100%; border-collapse: collapse;
  font-size: 12px; font-family: Inter, system-ui, -apple-system, sans-serif;
  line-height: 1.5; background: #fff;
  border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden;
}
.fn-table-wrap { overflow-x: auto; }

/* Header: dark, authoritative — matches tabs */
.fn-panel .ct-table .ct-th {
  padding: 12px 16px; text-align: center;
  background: #1a2744; color: #fff;
  font-weight: 700; font-size: 10px;
  text-transform: uppercase; letter-spacing: 0.6px;
  vertical-align: bottom; border-bottom: 2px solid #1a2744;
  white-space: nowrap;
}
.fn-panel .ct-table .ct-th.ct-label-col {
  text-align: left; min-width: 180px;
}
.fn-panel .ct-table .ct-header-text {
  font-size: 11px; line-height: 1.3; color: #e2e8f0;
  display: inline-block; margin-right: 4px;
}

/* Data cells */
.fn-panel .ct-table .ct-td {
  padding: 10px 14px; text-align: center;
  border-bottom: 1px solid #f1f5f9;
  font-variant-numeric: tabular-nums; position: relative;
}
.fn-panel .ct-table .ct-td.ct-label-col {
  text-align: left; font-weight: 600; color: #1e293b;
  min-width: 180px; background: #f8fafc; border-right: 1px solid #e2e8f0;
}
.fn-panel .ct-table tbody tr:last-child td { border-bottom: none; }

/* Base row — understated, structural (tabs pattern) */
.fn-panel .ct-row-base { background: #f8f9fa; }
.fn-panel .ct-row-base .ct-td {
  font-weight: 600; font-size: 12px; color: #475569;
  padding-top: 10px; padding-bottom: 10px;
}
.fn-panel .ct-row-base .ct-td.ct-label-col {
  background: #f8f9fa; color: #64748b;
}
.fn-panel .ct-low-base { color: #e8614d; font-weight: 700; }
.fn-panel .ct-base-n { font-variant-numeric: tabular-nums; }
.fn-panel .ct-na { color: #d1d5db; font-size: 12px; }

/* Focal row — left-border accent + tinted label */
.fn-panel .fn-row-focal .ct-td.ct-label-col {
  color: var(--fn-brand); background: rgba(26,82,118,0.04);
  border-left: 3px solid var(--fn-brand); font-weight: 700;
}
.fn-focal-badge {
  display: inline-block; font-size: 9px; font-weight: 700;
  background: var(--fn-brand); color: #fff; padding: 1px 5px;
  border-radius: 3px; margin-left: 4px; letter-spacing: 0.5px;
}

/* Category average row — italic, muted band */
.fn-panel .fn-row-avg-all { background: #fafbfc; }
.fn-panel .fn-row-avg-all .ct-td.ct-label-col {
  font-style: italic; color: #475569; background: #f1f3f6;
}

/* Heatmap — applied via inline background-color from data-heatmap (JS).
   Toggle OFF clears the style via panel class. */
.fn-panel .ct-heatmap-cell { transition: background-color 0.15s ease; }
.fn-panel.fn-heatmap-off .ct-heatmap-cell { background-color: transparent !important; }

/* Low-base dim — cell pct muted to signal small base */
.fn-panel .ct-low-base-dim .ct-val { opacity: 0.5; color: #c0392b; }

/* Primary value + count annotation (tabs .ct-val + .ct-freq pattern) */
.fn-panel .ct-val { font-weight: 600; font-size: 13px; color: #1e293b; }
.fn-panel .ct-freq {
  display: none; font-size: 10px; color: #94a3b8; margin-top: 2px;
}
.fn-panel.show-freq .ct-freq { display: block; }

/* Sig badges — match tabs .ct-sig */
.fn-panel .ct-sig {
  display: inline-block; margin-left: 4px;
  font-size: 9px; font-weight: 700; line-height: 1;
  vertical-align: top;
}
.fn-panel .fn-sig-up   { color: #059669; }
.fn-panel .fn-sig-down { color: #c0392b; }

/* Sort indicator — matches tabs .ct-sort-indicator */
.fn-panel .ct-sort-indicator {
  display: inline-flex; align-items: center; justify-content: center;
  width: 18px; height: 18px; padding: 0;
  background: transparent; border: 1px solid transparent; border-radius: 4px;
  font-size: 10px; color: #94a3b8; cursor: pointer; font-family: inherit;
  margin-left: 2px;
}
.fn-panel .ct-sort-indicator:hover { background: rgba(255,255,255,0.08); color: #fff; }
.fn-panel .ct-sort-indicator[data-fn-sort-dir="asc"],
.fn-panel .ct-sort-indicator[data-fn-sort-dir="desc"] {
  color: var(--fn-brand); font-weight: 700;
  background: #fff;
}
.fn-panel .ct-sort-indicator[data-fn-sort-dir="asc"]::after  { content: "↑"; margin-left: 1px; font-size: 10px; }
.fn-panel .ct-sort-indicator[data-fn-sort-dir="desc"]::after { content: "↓"; margin-left: 1px; font-size: 10px; }

/* Help "?" button on stage headers */
.fn-help-btn {
  display: inline-flex; align-items: center; justify-content: center;
  width: 18px; height: 18px; padding: 0; margin-left: 2px;
  border: 1px solid transparent; border-radius: 50%; background: rgba(255,255,255,0.1);
  color: #e2e8f0; font-size: 10px; font-weight: 700;
  cursor: pointer; font-family: inherit;
}
.fn-help-btn:hover { background: rgba(255,255,255,0.25); color: #fff; }

/* Help popover */
.fn-help-popover {
  position: absolute; z-index: 30;
  max-width: 320px; min-width: 220px;
  padding: 10px 14px;
  background: #ffffff; color: #1e293b;
  border: 1px solid #e2e8f0; border-radius: 8px;
  box-shadow: 0 6px 18px rgba(15, 23, 42, 0.12);
  font-size: 12px; line-height: 1.45;
}
.fn-help-popover-title {
  font-size: 11px; font-weight: 700; color: var(--fn-brand);
  text-transform: uppercase; letter-spacing: 0.6px;
  margin-bottom: 6px;
}
.fn-help-popover-body { color: #334155; }

/* + Add Insight strip (tabs pattern) */
.fn-add-insight-strip {
  margin-top: 8px; padding: 8px;
  border: 1px dashed #cbd5e1; border-radius: 6px; text-align: center;
}
.fn-add-insight-btn {
  background: transparent; border: none; cursor: pointer;
  font-family: inherit; font-size: 12px; color: #64748b; font-weight: 500;
}
.fn-add-insight-btn:hover { color: var(--fn-brand); }

/* -------------------------------------------------------------------------- */
/* RELATIONSHIP TABLE — focal column + category-avg column                    */
/* -------------------------------------------------------------------------- */
/* Focal column header: accent underline so it reads as "primary" column */
.fn-panel .fn-rel-th-focal {
  border-bottom: 3px solid var(--fn-brand);
}
/* Focal column cells: same light tint as the focal row in the funnel table */
.fn-panel .fn-rel-td-focal {
  background: rgba(26, 82, 118, 0.04) !important;
}
/* Category avg column: italic, muted — mirrors fn-row-avg-all row in funnel */
.fn-panel .fn-rel-th-avg em { font-style: italic; opacity: 0.85; }
.fn-panel .fn-rel-td-avg {
  background: #fafbfc !important;
  color: #475569;
  font-style: italic;
}

/* -------------------------------------------------------------------------- */
/* CARDS (unchanged from earlier)                                             */
/* -------------------------------------------------------------------------- */
.fn-section { margin-bottom: 20px; }
.fn-section-title {
  font-size: 14px; font-weight: 700; color: #1e293b;
  margin: 0 0 12px 0; text-transform: uppercase; letter-spacing: 0.8px;
  display: flex; align-items: center; gap: 6px;
}
.fn-insight-marker { color: #f59e0b; font-size: 9px; }
.fn-cards-group-label {
  font-size: 11px; font-weight: 600; color: #64748b;
  text-transform: uppercase; letter-spacing: 0.8px;
  margin: 4px 0 8px 2px;
}
.fn-card-strip.tk-hero-strip {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: 12px; margin-bottom: 16px;
}
.fn-card.tk-hero-card {
  background: #fff; border: 1px solid #e2e8f0; border-left: 4px solid #94a3b8;
  border-radius: 8px; padding: 14px 16px;
}
.fn-card .tk-hero-label {
  font-size: 11px; font-weight: 600; color: #64748b;
  margin-bottom: 8px; line-height: 1.3;
  text-transform: uppercase; letter-spacing: 0.6px;
}
.fn-card-row { display: flex; align-items: baseline; gap: 10px; margin-bottom: 6px; }
.fn-card .tk-hero-value {
  font-size: 26px; font-weight: 700;
  font-variant-numeric: tabular-nums; line-height: 1.1;
}
.fn-card-compare { font-size: 11px; color: #64748b; line-height: 1.3; }
.fn-card-compare strong { color: #1e293b; font-weight: 600; }
.fn-card-base { font-size: 10px; color: #94a3b8; margin-top: 4px; }
.fn-sig { font-size: 11px; font-weight: 700; padding: 1px 6px; border-radius: 3px; }
.fn-sig-up   { color: #059669; background: rgba(5,150,105,0.1); }
.fn-sig-down { color: #c0392b; background: rgba(192,57,43,0.1); }

/* -------------------------------------------------------------------------- */
/* Slope chart + relationship                                                 */
/* -------------------------------------------------------------------------- */
.fn-chart-wrap { background: #fff; border: 1px solid #e2e8f0;
  border-radius: 8px; padding: 14px; }
.fn-slope-svg { display: block; max-width: 100%; height: auto; }

.fn-relationship-section .fn-seg-picker { margin-bottom: 12px; }
.fn-relationship-bars { background: #fff; border: 1px solid #e2e8f0;
  border-radius: 8px; padding: 12px 16px; }
.fn-bar-row { display: grid; grid-template-columns: 160px 1fr;
  align-items: center; gap: 10px; margin-bottom: 8px; }
.fn-bar-label { font-size: 12px; font-weight: 500; color: #1e293b; }
.fn-bar-row-focal .fn-bar-label { font-weight: 700; color: var(--fn-brand); }
.fn-bar-track { display: flex; height: 22px; border-radius: 4px; overflow: hidden;
  background: #f1f5f9; }
.fn-seg { transition: opacity 0.2s; }
.fn-panel[data-fn-emphasis-active="1"] .fn-seg { opacity: 0.22; }
.fn-panel[data-fn-emphasis-active="1"] .fn-seg.fn-seg-active { opacity: 1; }

.fn-seg-chip.active {
  background: var(--fn-brand); color: #fff; border-color: var(--fn-brand);
}

/* -------------------------------------------------------------------------- */
/* About drawer + empty states                                                */
/* -------------------------------------------------------------------------- */
.fn-about { margin-top: 16px; background: #f8fafc; border: 1px solid #e2e8f0;
  border-radius: 6px; padding: 10px 14px; }
.fn-about-summary { font-size: 12px; font-weight: 600; color: #475569;
  cursor: pointer; }
.fn-about-body { padding-top: 8px; font-size: 12px; color: #475569;
  line-height: 1.5; }
.fn-about-item { margin: 4px 0; }
.fn-about-item strong { color: #1e293b; }

.fn-panel-empty { padding: 24px; background: #f8fafc; color: #64748b;
  border-radius: 8px; text-align: center; }

@media print {
  .fn-controls, .fn-export-btn, .fn-subnav, .fn-pin-btn { display: none !important; }
  .fn-subtab[hidden] { display: block !important; }
}
'
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
