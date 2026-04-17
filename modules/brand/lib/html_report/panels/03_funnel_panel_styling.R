# ==============================================================================
# BRAND MODULE - FUNNEL PANEL CSS BUNDLE
# ==============================================================================
# Shared visual tokens copied from tabs + tracker so the brand funnel panel
# looks part of the same family. Emitted as a single <style> block on
# first panel include (the call site guards against duplicate injection).
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


#' Raw CSS body (easier to edit as a heredoc, no R interpolation)
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

/* Header banner — matches tabs gradient */
.fn-panel-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
  color: #fff;
  padding: 20px 28px;
  border-bottom: 3px solid var(--fn-brand);
  border-radius: 8px 8px 0 0;
  margin-bottom: 18px;
}
.fn-panel-header .fn-panel-title {
  font-size: 22px; font-weight: 700; margin: 0 0 4px 0;
  letter-spacing: 0.2px; color: #ffffff;
}
.fn-panel-sub {
  font-size: 13px; color: #cbd5e1; font-weight: 500;
}
.fn-panel-sub strong { color: #fff; font-weight: 700; }

/* Controls strip */
.fn-controls {
  display: flex; flex-wrap: wrap; gap: 12px 20px;
  padding: 14px 18px; background: #f8fafc;
  border: 1px solid #e2e8f0; border-radius: 8px;
  margin-bottom: 20px;
}
.fn-ctl-group { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
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
.fn-focus-select:focus { outline: 2px solid var(--fn-brand); outline-offset: 1px; }
.fn-chip-group { gap: 4px; }
.fn-chip-row { display: flex; flex-wrap: wrap; gap: 4px; padding: 0; border: none; margin: 0; background: transparent; }
.fn-toggles { gap: 10px; }
.fn-toggle {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 12px; color: #1e293b; cursor: pointer;
}
.fn-toggle input { cursor: pointer; }
.fn-sep {
  display: inline-block; width: 1px; height: 18px;
  background: #e2e8f0;
}
.fn-export-btn {
  padding: 6px 12px; font-size: 11px; font-weight: 600;
  background: var(--fn-brand); color: #fff;
  border: none; border-radius: 6px; cursor: pointer;
  letter-spacing: 0.3px;
}
.fn-export-btn:hover { filter: brightness(0.92); }

/* Chip style — matches tabs .col-chip */
.fn-chip-row .col-chip,
.fn-seg-picker .col-chip {
  padding: 5px 12px; border: 1px solid #e2e8f0; border-radius: 16px;
  background: #f0fafa; color: #1e293b; font-size: 11px; font-weight: 500;
  cursor: pointer; font-family: inherit; transition: all 0.15s;
}
.fn-chip-row .col-chip:hover { border-color: var(--fn-brand); }
.fn-chip-row .col-chip-off {
  background: #f8f9fa; color: #94a3b8;
  text-decoration: line-through; opacity: 0.55;
}
.fn-seg-chip.active {
  background: var(--fn-brand); color: #fff; border-color: var(--fn-brand);
}

/* Section chrome */
.fn-section { margin-bottom: 24px; }
.fn-section-title {
  font-size: 14px; font-weight: 700; color: #1e293b;
  margin: 0 0 12px 0; text-transform: uppercase; letter-spacing: 0.8px;
  display: flex; align-items: center; gap: 6px;
}
.fn-insight-marker {
  color: #f59e0b; font-size: 9px;
}

/* Cards */
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
.fn-card-compare {
  font-size: 11px; color: #64748b; line-height: 1.3;
}
.fn-card-compare strong { color: #1e293b; font-weight: 600; }
.fn-card-base { font-size: 10px; color: #94a3b8; margin-top: 4px; }
.fn-sig { font-size: 11px; font-weight: 700; padding: 1px 6px; border-radius: 3px; }
.fn-sig-up   { color: #059669; background: rgba(5,150,105,0.1); }
.fn-sig-down { color: #c0392b; background: rgba(192,57,43,0.1); }

/* Table */
.fn-table-wrap { overflow-x: auto; background: #fff;
  border: 1px solid #e2e8f0; border-radius: 8px; padding: 4px; }
.fn-table { width: 100%; border-collapse: collapse; font-size: 12px; }
.fn-table th, .fn-table td { padding: 8px 10px; text-align: center; }
.fn-table thead th {
  background: #f8fafc; border-bottom: 2px solid #e2e8f0;
  color: #1e293b; font-weight: 700; text-transform: uppercase;
  font-size: 10px; letter-spacing: 0.6px;
}
.fn-th-brand { text-align: left !important; min-width: 140px; }
.fn-th-rowlabel {
  text-align: left; background: #f8fafc; font-weight: 600;
  color: #1e293b; min-width: 140px; border-right: 1px solid #e2e8f0;
}
.fn-row-focal .fn-th-rowlabel {
  color: var(--fn-brand); background: rgba(26,82,118,0.04);
  border-left: 3px solid var(--fn-brand);
}
.fn-focal-badge {
  display: inline-block; font-size: 9px; font-weight: 700;
  background: var(--fn-brand); color: #fff; padding: 1px 5px;
  border-radius: 3px; margin-left: 4px; text-transform: uppercase;
  letter-spacing: 0.5px;
}
.fn-row-avg-all {
  background: #f5f6f8;
}
.fn-row-avg-all .fn-th-rowlabel {
  font-style: italic; color: #475569;
  background: #f1f3f6;
}
.fn-row-avg-all .fn-td {
  background-image: linear-gradient(#f5f6f8 0%, #f5f6f8 100%) !important;
  background-blend-mode: multiply;
}
.fn-td { font-variant-numeric: tabular-nums; position: relative; }
.fn-pct-primary { font-weight: 600; display: block; line-height: 1.15; }
.fn-pct-count { font-size: 10px; color: #64748b; display: none; margin-top: 2px; }
.fn-panel.fn-show-counts .fn-pct-count { display: block; }
.fn-td-empty { color: #cbd5e1; }

/* Base row — shows n= per stage, inherits ct-table base row styling */
.fn-row-base { background: #f8fafc; border-bottom: 1px solid #e2e8f0; }
.fn-row-base .fn-th-rowlabel-base {
  font-weight: 700; color: #475569; background: #f8fafc;
}
.fn-td-base .fn-base-n {
  font-size: 11px; font-weight: 600; color: #475569;
  font-variant-numeric: tabular-nums;
}
.fn-td-base-warn .fn-base-n,
.fn-td-warn .fn-pct-primary {
  color: #c0392b;
}
.fn-warn {
  display: inline-block; margin-left: 3px; color: #c0392b;
  font-size: 11px;
}

/* In-cell up/down sig badge — superscript-style, compact */
.fn-td .fn-sig {
  display: inline-block; margin-left: 4px;
  font-size: 10px; font-weight: 700;
  padding: 0; background: transparent;
  vertical-align: top; line-height: 1;
}

/* Header chrome: label + help + sort, all inline */
.fn-table thead th {
  position: sticky; top: 0;
}
.fn-th-stage, .fn-th-brand {
  white-space: nowrap;
}
.fn-th-label { margin-right: 4px; }
.fn-help-btn, .fn-sort-btn {
  display: inline-flex; align-items: center; justify-content: center;
  width: 18px; height: 18px; padding: 0; margin-left: 2px;
  border: 1px solid transparent; border-radius: 4px; background: transparent;
  color: #94a3b8; font-size: 10px; font-weight: 700;
  cursor: pointer; font-family: inherit;
}
.fn-help-btn:hover, .fn-sort-btn:hover {
  background: #e2e8f0; color: #1e293b;
}
.fn-sort-btn[data-fn-sort-dir="asc"]::after  { content: "\u2191"; font-size: 10px; margin-left: 1px; color: var(--fn-brand); }
.fn-sort-btn[data-fn-sort-dir="desc"]::after { content: "\u2193"; font-size: 10px; margin-left: 1px; color: var(--fn-brand); }
.fn-sort-btn[data-fn-sort-dir="asc"],
.fn-sort-btn[data-fn-sort-dir="desc"] {
  background: rgba(26,82,118,0.08); color: var(--fn-brand);
}

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

/* Show-chart toggle controls chart section visibility */
.fn-panel.fn-hide-chart .fn-chart-section { display: none; }

/* Slope chart + relationship */
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

/* About drawer */
.fn-about { margin-top: 16px; background: #f8fafc; border: 1px solid #e2e8f0;
  border-radius: 6px; padding: 10px 14px; }
.fn-about-summary { font-size: 12px; font-weight: 600; color: #475569;
  cursor: pointer; }
.fn-about-body { padding-top: 8px; font-size: 12px; color: #475569;
  line-height: 1.5; }
.fn-about-item { margin: 4px 0; }
.fn-about-item strong { color: #1e293b; }

/* Empty / missing states */
.fn-panel-empty { padding: 24px; background: #f8fafc; color: #64748b;
  border-radius: 8px; text-align: center; }

@media print {
  .fn-controls, .fn-export-btn { display: none !important; }
  .fn-panel-header { background: #1a2744 !important; }
}
'
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
