# ==============================================================================
# BRAND MODULE - MA PANEL CSS BUNDLE
# ==============================================================================
# Styles specific to the Mental Availability panel. Reuses ct-* and
# toggle/segmented-control classes from tabs/funnel where possible;
# only MA-specific deltas live here.
# ==============================================================================


#' Return the CSS for the MA panel as a single string.
#'
#' @param focal_colour Character. Hex colour used for focal accents.
#' @return Character. CSS block (no surrounding <style>).
#' @export
build_ma_panel_styles <- function(focal_colour = "#1A5276") {

  tmpl <- '
.ma-panel { --ma-brand: %FOCAL%; position: relative; background: #fff;
            border: 1px solid #e2e8f0; border-radius: 10px;
            padding: 18px 20px; margin-bottom: 20px; }
.ma-panel-empty { padding: 24px; color: #94a3b8;
                  background: #f8f9fa; border-radius: 8px; }

/* Sub-tab nav */
.ma-subnav { display: flex; gap: 0; border-bottom: 1px solid #e2e8f0;
             margin-bottom: 16px; }
.ma-subtab-btn { background: none; border: none;
                 border-bottom: 2px solid transparent;
                 padding: 10px 16px; font-size: 13px; font-weight: 500;
                 color: #94a3b8; cursor: pointer; transition: all 0.15s; }
.ma-subtab-btn:hover { color: #64748b; }
.ma-subtab-btn.active { color: var(--ma-brand);
                        border-bottom-color: var(--ma-brand);
                        font-weight: 600; }
.ma-subtab[hidden] { display: none; }

/* Focus bar */
.ma-focus-bar { display: flex; align-items: center; gap: 10px;
                margin-bottom: 12px; padding: 8px 0;
                border-bottom: 1px dashed #e2e8f0; }
.ma-focus-bar .ma-ctl-label { font-size: 11px; font-weight: 600;
                              color: #64748b; text-transform: uppercase;
                              letter-spacing: 0.4px; }
.ma-focus-select { font-size: 12px; padding: 5px 10px; border-radius: 6px;
                   border: 1px solid #cbd5e1; background: #fff;
                   cursor: pointer; }
.ma-pin-dropdown-btn { font-size: 12px; padding: 5px 10px; border-radius: 6px;
                       border: 1px solid #cbd5e1; background: #fff;
                       cursor: pointer; margin-left: auto; }
.ma-pin-dropdown-btn:hover { background: #f8f9fa; }
.ma-chart-select-btn { font-size: 12px; padding: 5px 10px; border-radius: 6px;
                       border: 1px solid #cbd5e1; background: #fff;
                       color: #334155; cursor: pointer; }
.ma-chart-select-btn[aria-pressed="true"] { background: var(--ma-brand); color: #fff;
                       border-color: var(--ma-brand); }
.ma-chart-select-btn[aria-pressed="false"] { color: #94a3b8; }

/* Controls bar */
.ma-controls { display: flex; flex-direction: column; gap: 8px;
               margin-bottom: 12px; padding: 8px 10px;
               background: #f8fafc; border: 1px solid #eef2f7;
               border-radius: 8px; }
.ma-meta-row { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; }
.ma-controls .ma-ctl-label { font-size: 11px; font-weight: 600;
                              color: #64748b; text-transform: uppercase;
                              letter-spacing: 0.4px; margin-right: 8px; }
.ma-controls .toggle-label { font-size: 12px; color: #334155;
                             display: inline-flex; align-items: center;
                             gap: 6px; cursor: pointer; }
.ma-controls .toggle-label input { margin: 0; }

/* Chips (brand picker) */
.ma-chip-row { display: flex; flex-wrap: wrap; gap: 4px; align-items: center; }
.col-chip { font-size: 11px; padding: 3px 9px; border-radius: 12px;
            border: 1px solid var(--brand-chip-color, #64748b);
            background: var(--brand-chip-color, #64748b);
            color: #fff; cursor: pointer; transition: all 0.12s;
            font-weight: 500; }
.col-chip:hover { filter: brightness(0.88); }
.col-chip.col-chip-off { background: #f1f5f9 !important; color: #94a3b8 !important;
                         border-color: #e2e8f0 !important; }

/* Base mode segmented */
.ma-panel .sig-level-switcher { display: inline-flex; align-items: center; gap: 4px; }
.ma-panel .sig-level-label { font-size: 11px; font-weight: 600; color: #64748b;
  white-space: nowrap; text-transform: uppercase; letter-spacing: 0.4px; }
.ma-panel .sig-btn { font-size: 11px; font-weight: 500; padding: 5px 10px;
  border: 1px solid #e2e8f0; background: #fff; color: #1e293b;
  cursor: pointer; font-family: inherit; line-height: 1.4;
  transition: background 0.1s, color 0.1s; }
.ma-panel .sig-btn:first-of-type { border-radius: 4px 0 0 4px; }
.ma-panel .sig-btn:last-of-type  { border-radius: 0 4px 4px 0; border-left: none; }
.ma-panel .sig-btn.sig-btn-active { background: var(--ma-brand); color: #fff;
  border-color: var(--ma-brand); font-weight: 600; }
.ma-panel .sig-btn:hover:not(.sig-btn-active) { background: #e2e8f0; }

/* Table wrap (horizontal scroll for many brands) */
.ma-table-wrap { overflow-x: auto; margin: 0 -4px; padding: 0 4px 2px; }
.ma-ct-table { min-width: 720px; border-collapse: separate;
               border-spacing: 0; width: 100%; font-size: 12px; }
.ma-ct-table th.ct-th {
  background: #1e293b; color: #fff; font-weight: 600; font-size: 11px;
  letter-spacing: 0.3px; padding: 8px 10px; border-bottom: 2px solid #0f172a;
  text-align: center; white-space: normal; text-transform: none;
  position: sticky; top: 0; z-index: 2; }
.ma-ct-table th.ct-label-col { text-align: left; }
.ma-ct-table th .ct-header-text { display: flex; flex-direction: column;
                                   align-items: center; gap: 3px;
                                   text-align: center; }
.ma-ct-table .ct-sort-indicator {
  display: inline-flex; align-items: center; justify-content: center;
  width: 18px; height: 18px; padding: 0;
  background: transparent; border: 1px solid transparent; border-radius: 4px;
  font-size: 10px; color: rgba(255,255,255,0.35); cursor: pointer;
  margin-left: 2px; }
.ma-ct-table .ct-sort-indicator:hover { background: rgba(255,255,255,0.1); color: #e2e8f0; }

.ma-ct-th-focal { background: %FOCAL% !important; color: #fff; }
.ma-focal-badge { display: inline-block; background: rgba(255,255,255,0.22);
                  color: #fff; font-size: 9px; font-weight: 800;
                  letter-spacing: 0.6px; padding: 1px 5px; border-radius: 3px; }
.ma-ct-th-catavg { background: #334155 !important; font-style: italic; }

.ma-ct-table td.ct-td { padding: 7px 10px; border-bottom: 1px solid #f0f0f0;
                         color: #334155; text-align: center;
                         vertical-align: middle; }
.ma-ct-table td.ct-label-col { text-align: left; font-weight: 500;
                                white-space: normal; max-width: 260px; }
.ma-ct-table tr.ma-row:hover td { background: #f8f9fb; }
.ma-ct-table tr.ma-row-summary td { background: #f8fafc !important;
                                     font-weight: 600; color: #334155;
                                     border-top: 2px solid #e2e8f0; }
.ma-td-focal { box-shadow: inset 3px 0 0 0 %FOCAL%,
                           inset -3px 0 0 0 %FOCAL%;
               background: rgba(26,82,118,0.05); }
.ma-td-focal .ct-val { font-weight: 700; }
.ma-td-catavg { background: #f8fafc; font-style: italic; color: #64748b; }
.ma-td-brand-avg { font-weight: 600; }

.ma-heatmap-cell { transition: background-color 0.18s ease; position: relative; }
.ma-heatmap-cell .ct-val { position: relative; z-index: 1; font-weight: 500; }
.ma-matrix-section.ma-heatmap-off .ma-heatmap-cell { background: transparent !important; }

/* CI band colouring (default heatmap mode) */
.ma-matrix-section[data-ma-heatmap-mode="ci"] .ma-heatmap-cell.ma-ci-above  { background: rgba(5, 150, 105, 0.18) !important; }
.ma-matrix-section[data-ma-heatmap-mode="ci"] .ma-heatmap-cell.ma-ci-within { background: rgba(245, 158, 11, 0.15) !important; }
.ma-matrix-section[data-ma-heatmap-mode="ci"] .ma-heatmap-cell.ma-ci-below  { background: rgba(220, 38, 38, 0.18) !important; }

/* Brand-count text baseline — visible only when "Show count" is on */
.ma-n-primary { display: none; font-size: 10.5px; color: #64748b;
                font-variant-numeric: tabular-nums; margin-top: 2px; }
.ma-matrix-section.ma-show-counts .ma-n-primary { display: block; }

/* Cat-avg column marker */
.ma-ct-th-catavg { background: #334155 !important; font-style: italic; }
.ma-td-catavg { background: #f1f5f9 !important; font-style: italic;
                color: #334155; border-left: 2px solid #e2e8f0;
                border-right: 2px solid #e2e8f0; }
.ma-td-catavg .ct-val { font-weight: 700; color: #1e293b; }
.ma-ci-hint { display: block; font-size: 10px; color: #94a3b8; margin-top: 1px; }
/* Cat-avg CI mini-bar (funnel-style) on Brand Attitude table — same visual
   contract as the Metrics tab. Keep cell compact but give the bar breathing room. */
.ma-td-catavg.ma-td-catavg-ci { padding-bottom: 6px; vertical-align: top; }
.ma-td-catavg.ma-td-catavg-ci .ct-val { display: block; }

/* Base row (top of tbody, replaces base column) */
.ma-row-base td.ct-td { background: #f0f4f8; font-size: 10px; color: #64748b;
                        font-style: italic; border-bottom: 1px solid #dde3eb; }
.ma-row-base td.ct-label-col { font-weight: 600; }

/* Row label — clickable toggle to grey out */
.ma-row-label { padding-left: 8px; max-width: 300px; }
.ma-row-toggle { display: flex; align-items: flex-start; gap: 6px;
                 cursor: pointer; }
.ma-row-toggle input { margin: 2px 0 0; flex-shrink: 0; }
.ma-row-label-text { font-weight: 500; color: #334155;
                     white-space: normal; line-height: 1.35; }
.ma-row.ma-row-inactive { opacity: 0.45; }
.ma-row.ma-row-inactive .ma-row-label-text { text-decoration: line-through; }
.ma-row.ma-row-inactive td.ma-heatmap-cell { background: #f8fafc !important;
                                              color: #94a3b8; }

/* Significance arrows (z-test vs cat avg) */
.ma-sig { display: inline-block; font-size: 11px; font-weight: 700;
          margin-left: 3px; vertical-align: baseline; }
.ma-sig.ma-sig-up   { color: #059669; }
.ma-sig.ma-sig-down { color: #c0392b; }

/* Low-base dim */
.ma-ct-table .ma-low-base-dim .ct-val { color: #c0392b; opacity: 0.6; }

/* Chart chip bar + legend */
.ma-chart-chip-bar { margin-bottom: 6px; }
/* Chart legend (HTML div hidden — legend now rendered inside SVG) */
.ma-chart-legend { display: none; }
.ma-legend-item { display: inline-flex; align-items: center; gap: 5px;
                  font-size: 11px; color: #334155; }
.ma-legend-dot { display: inline-block; width: 9px; height: 9px;
                 border-radius: 50%; flex-shrink: 0; }
.ma-legend-name { white-space: nowrap; }

/* Section titles */
.ma-section { margin-bottom: 16px; }
.ma-section-title { font-size: 15px; font-weight: 700; color: #1e293b;
                    margin: 4px 0 12px; }
.ma-subsection-title { font-size: 13px; font-weight: 600; color: #334155;
                       margin: 20px 0 6px; }
.ma-subsection-note  { font-size: 11.5px; color: #64748b; margin: 0 0 10px; }

/* Hero card strip */
.ma-hero-strip { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                 gap: 12px; margin-bottom: 18px; }
.ma-hero-card { background: #fff; border: 1px solid #e2e8f0;
                border-left-width: 4px; border-radius: 8px;
                padding: 12px 14px; }
.ma-hero-card .tk-hero-label { font-size: 11px; color: #64748b;
                                text-transform: uppercase; letter-spacing: 0.4px;
                                font-weight: 600; }
.ma-hero-card .tk-hero-value { font-size: 28px; font-weight: 700;
                                margin: 4px 0 2px; letter-spacing: -0.5px; }
.ma-hero-compare { font-size: 11.5px; color: #64748b; }
.ma-hero-compare strong { color: #334155; }
.ma-hero-leader { font-size: 11px; color: #94a3b8; margin-top: 4px; }
.ma-hero-leader-focal { color: #059669; font-weight: 700;
                         text-transform: uppercase; letter-spacing: 0.4px; }

/* CEP ranking list */
.ma-rank-list { display: flex; flex-direction: column; gap: 6px;
                margin-top: 6px; }
.ma-rank-row  { display: grid; grid-template-columns: 34px 1fr 2fr;
                align-items: center; gap: 10px; font-size: 12px; }
.ma-rank-rank { font-weight: 700; color: #64748b; text-align: right; }
.ma-rank-label { color: #334155; overflow: hidden; text-overflow: ellipsis;
                 white-space: nowrap; }
.ma-rank-bar-track { position: relative; height: 20px; background: #f1f5f9;
                     border-radius: 4px; overflow: hidden; }
.ma-rank-bar-fill  { height: 100%; border-radius: 4px 0 0 4px; opacity: 0.85; }
.ma-rank-bar-value { position: absolute; right: 8px; top: 50%;
                     transform: translateY(-50%); font-size: 11px;
                     font-weight: 600; color: #1e293b; }

/* Add insight strip */
.ma-add-insight-strip { text-align: right; margin: 8px 0 2px; }
.ma-add-insight-btn   { background: none; border: 1px dashed #cbd5e1;
                        color: #64748b; font-size: 12px; padding: 4px 10px;
                        border-radius: 6px; cursor: pointer; }
.ma-add-insight-btn:hover { border-color: var(--ma-brand); color: var(--ma-brand); }

/* Bar chart */
.ma-chart-section { margin-top: 14px; padding: 10px 0 4px;
                    border-top: 1px dashed #e2e8f0; }
.ma-chart-section[hidden] { display: none; }
.ma-bar-chart { width: 100%; display: block; font-family: inherit; }
.ma-bar-chart .ma-bar { cursor: default; transition: opacity 0.15s; }
.ma-bar-chart .ma-bar-label { font-size: 11px; fill: #334155; }
.ma-bar-chart .ma-bar-value { font-size: 10.5px; fill: #1e293b;
                              font-variant-numeric: tabular-nums;
                              pointer-events: none; }
.ma-bar-chart .ma-bar-axis { stroke: #cbd5e1; stroke-width: 1; }
.ma-bar-chart .ma-bar-gridline { stroke: #f1f5f9; stroke-width: 1; }
.ma-bar-chart .ma-bar-group-label { font-size: 12px; fill: #1e293b;
                                    font-weight: 600; }
.ma-bar-chart .ma-bar-cat-avg { stroke: #64748b; stroke-width: 1.5;
                                stroke-dasharray: 3 3; }
.ma-bar-chart .ma-bar-legend { font-family: inherit; }

/* Full-width insight box — breaks out of panel padding to span full width */
.ma-insight-box { width: calc(100% + 40px); margin: 12px -20px 0;
                  padding: 10px 20px;
                  background: #f8fafc; border: 1px solid #e2e8f0;
                  border-left: 3px solid var(--ma-brand);
                  border-radius: 0; box-sizing: border-box; }
.ma-insight-box-header { display: flex; align-items: center;
                          justify-content: space-between;
                          margin-bottom: 4px; }
.ma-insight-box-title { font-size: 11px; font-weight: 700;
                         letter-spacing: 0.5px; color: var(--ma-brand);
                         text-transform: uppercase; }
.ma-insight-box-clear { background: none; border: none; cursor: pointer;
                         font-size: 18px; color: #94a3b8; line-height: 1; }
.ma-insight-box-clear:hover { color: #dc2626; }
.ma-insight-box-text { width: 100%; min-height: 42px; padding: 6px 8px;
                        background: #fff; border: 1px solid #e2e8f0;
                        border-radius: 4px; font-size: 13px;
                        font-family: inherit; color: #1e293b;
                        resize: vertical; }
.ma-insight-box-text:focus { outline: 2px solid var(--ma-brand);
                              outline-offset: -1px; border-color: var(--ma-brand); }

/* Metrics table — focal row (always above cat avg) */
.ma-metrics-focal-row td.ct-label-col {
  font-weight: 700; border-left: 3px solid %FOCAL%; }
.ma-metrics-focal-row td.ct-label-col .ma-focal-badge {
  background: %FOCAL%; margin-left: 6px; }

/* Metrics table — category average row */
.ma-metrics-cat-avg td.ct-td {
  background: #f1f5f9 !important; font-style: italic; font-weight: 600; }
.ma-metrics-cat-avg td.ct-label-col { color: #334155; }

/* Metrics table — base row */
.ma-metrics-base td.ct-td {
  background: #f0f4f8; font-size: 11px; color: #64748b;
  font-style: italic; border-bottom: 1px solid #dde3eb; }
.ma-metrics-base td.ct-label-col { font-weight: 600; }

/* Metrics sort button (in dark header) */
.ma-metric-sort-btn {
  display: inline-flex; align-items: center; justify-content: center;
  width: 18px; height: 18px; padding: 0; background: transparent;
  border: 1px solid transparent; border-radius: 4px; font-size: 10px;
  color: rgba(255,255,255,0.40); cursor: pointer; margin-left: 2px;
  vertical-align: middle; }
.ma-metric-sort-btn:hover { background: rgba(255,255,255,0.12); color: #e2e8f0; }
.ma-metric-sort-btn[data-sort-dir="asc"],
.ma-metric-sort-btn[data-sort-dir="desc"] {
  color: #fff; background: rgba(255,255,255,0.18); border-color: rgba(255,255,255,0.25); }
.ma-metrics-table th.ct-th { min-width: 110px; }
.ma-metrics-table th.ct-label-col { min-width: 160px; text-align: left; }

/* About drawer — formula dl */
.ma-about-formulas { margin-top: 10px; }
.ma-formula-dl { margin: 4px 0 0; display: grid;
  grid-template-columns: max-content 1fr; gap: 2px 12px; }
.ma-formula-dl dt { font-weight: 700; color: #1e293b; white-space: nowrap;
                    padding: 2px 0; align-self: start; }
.ma-formula-dl dd { margin: 0; color: #64748b; padding: 2px 0; }

/* CI range bar inside cat-avg metric cells */
.ma-metrics-cat-avg td.ct-td { padding-bottom: 5px; }
.ma-ci-bar-wrap {
  position: relative; height: 6px; background: #dde3eb;
  border-radius: 3px; margin: 4px 0 2px; overflow: visible; }
.ma-ci-bar-range {
  position: absolute; height: 100%; border-radius: 3px;
  background: linear-gradient(90deg,rgba(71,85,105,0.25),rgba(71,85,105,0.5)); }
.ma-ci-bar-tick {
  position: absolute; width: 2px; height: 140%; top: -20%;
  background: #475569; border-radius: 1px; transform: translateX(-50%); }
.ma-ci-limits {
  display: flex; justify-content: space-between; font-size: 9px;
  color: #94a3b8; margin-top: 1px; font-variant-numeric: tabular-nums; }
.ma-ci-limits span { line-height: 1; }

/* Show n count in metric cells */
.ma-n-metrics { display: none; font-size: 10px; color: #94a3b8;
                font-variant-numeric: tabular-nums; margin-top: 2px;
                font-weight: 400; font-style: normal; }
.ma-metrics-section.ma-show-counts-metrics .ma-n-metrics { display: block; }

[data-ma-chart-id][hidden] { display: none !important; }

/* Chart section callouts */
.ma-chart-callout {
  margin: 0 0 8px; font-size: 11.5px; color: #64748b; }
.ma-chart-callout > summary {
  cursor: pointer; font-size: 11px; font-weight: 600; color: #94a3b8;
  list-style: none; user-select: none; }
.ma-chart-callout > summary::-webkit-details-marker { display: none; }
.ma-chart-callout > summary::before { content: "\\25B8 "; }
.ma-chart-callout[open] > summary::before { content: "\\25BE "; }
.ma-chart-callout p { margin: 6px 0 0; padding: 8px 10px;
  background: #f8fafc; border-left: 2px solid #e2e8f0; border-radius: 0 4px 4px 0; }

/* CEP ranking section */
.ma-rank-section { margin-top: 18px; padding-top: 14px; border-top: 1px dashed #e2e8f0; }
.ma-rank-section[hidden] { display: none !important; }

/* Metrics charts area — stacked full-width */
.ma-metrics-charts { display: flex; flex-direction: column; gap: 20px;
                     margin: 18px 0; }
.ma-scatter-wrap, .ma-bars-wrap {
  width: 100%; background: #fafbfc; border: 1px solid #eef2f7;
  border-radius: 8px; padding: 12px 14px; box-sizing: border-box; }
.ma-scatter-wrap[hidden], .ma-bars-wrap[hidden] { display: none !important; }
.ma-scatter-svg, .ma-bars-svg {
  width: 100%; display: block; font-family: inherit; }

/* About drawer */
.ma-about { margin-top: 18px; border-top: 1px dashed #e2e8f0; padding-top: 10px; }
.ma-about-summary { font-size: 12px; font-weight: 600; color: #64748b;
                    cursor: pointer; padding: 4px 0; list-style: none; }
.ma-about-summary::-webkit-details-marker { display: none; }
.ma-about-summary::before { content: "\\25B8 "; }
.ma-about[open] .ma-about-summary::before { content: "\\25BE "; }
.ma-about-body { font-size: 12px; color: #475569; line-height: 1.55;
                 padding: 6px 0 0; }
.ma-about-item { margin: 0 0 6px; }
.ma-about-item strong { color: #334155; }

@media print {
  .ma-subnav, .ma-controls, .ma-focus-bar, .ma-add-insight-strip { display: none !important; }
  .ma-subtab[hidden] { display: block !important; }
}
'

  tmpl <- gsub("%FOCAL%", focal_colour, tmpl, fixed = TRUE)
  paste0('<style class="ma-panel-styles">', tmpl, '</style>')
}
