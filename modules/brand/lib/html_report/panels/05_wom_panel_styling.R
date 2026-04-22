# ==============================================================================
# BRAND MODULE - WOM PANEL STYLING
# ==============================================================================
# Minimal CSS bundle for the Word of Mouth panel. Reuses ct-*, fn-*, and
# ma-* classes from tabs / funnel / MA where possible; adds only the new
# wom-* rules required for the focus bar, column grouping, and insight box.
# ==============================================================================


#' Build the WOM panel style block.
#'
#' @param focal_colour Character. Hex colour for focal accents.
#' @return Character HTML string (`<style>...</style>`).
#' @export
build_wom_panel_styles <- function(focal_colour = "#1A5276") {
  sprintf(
'<style class="wom-panel-styles">
/* Panel shell */
.wom-panel { margin: 0; padding: 0; }
.wom-panel-empty {
  padding: 24px; color: #94a3b8; font-size: 13px; text-align: center;
  border: 1px dashed #e2e8f0; border-radius: 8px; background: #f8fafc;
}

/* Focus bar */
.wom-focus-bar {
  display: flex; align-items: center; gap: 10px;
  padding: 8px 12px; margin: 0 0 8px;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px;
}
.wom-ctl-label {
  font-size: 12px; font-weight: 600; color: #334155;
}
.wom-ctl-label-title {
  text-transform: uppercase; letter-spacing: 0.3px; color: #64748b;
  font-size: 11px;
}
.wom-focus-select {
  font-size: 13px; padding: 4px 8px;
  border: 1px solid #cbd5e1; border-radius: 6px;
  background: #ffffff; color: #0f172a; min-width: 180px;
}
.wom-chart-controls {
  display: inline-flex; align-items: center; gap: 12px;
  margin-left: auto;
}
.wom-toggle-label {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 12px; font-weight: 500; color: #334155;
  cursor: pointer; user-select: none;
}
.wom-toggle-label input[type="checkbox"] { cursor: pointer; }

/* Heard / Said segmented control */
.wom-variant-seg {
  display: inline-flex; border: 1px solid #cbd5e1; border-radius: 6px;
  background: #ffffff; overflow: hidden;
}
.wom-variant-seg .wom-variant-btn {
  font-size: 12px; font-weight: 600; color: #475569;
  padding: 4px 10px; background: #ffffff; border: 0;
  cursor: pointer; user-select: none;
  border-right: 1px solid #e2e8f0;
}
.wom-variant-seg .wom-variant-btn:last-child { border-right: 0; }
.wom-variant-seg .wom-variant-btn:hover { background: #f1f5f9; }
.wom-variant-seg .wom-variant-btn.active {
  background: #1a2744; color: #ffffff;
}
.wom-chart-controls[aria-disabled="true"] .wom-variant-seg,
.wom-chart-controls[aria-disabled="true"] .wom-variant-seg .wom-variant-btn {
  opacity: 0.5; pointer-events: none;
}

/* Brand picker: coloured show/hide chips */
.wom-brand-picker {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 8px 12px; margin: 0 0 12px;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px;
  flex-wrap: wrap;
}
.wom-brand-picker .col-chip-bar {
  display: flex; flex-wrap: wrap; gap: 6px;
}
.wom-brand-picker .wom-brand-chip {
  font-size: 12px; font-weight: 600; padding: 4px 10px;
  border-radius: 999px; cursor: pointer; border: 1px solid transparent;
  opacity: 1; transition: opacity 0.15s ease, filter 0.15s ease;
}
.wom-brand-picker .wom-brand-chip:not(.active) {
  background: #ffffff !important; color: #94a3b8 !important;
  border-color: #cbd5e1 !important;
  text-decoration: line-through; filter: none; opacity: 0.65;
}
.wom-brand-picker .wom-brand-chip .fn-focal-badge {
  margin-left: 6px; font-size: 9px; padding: 1px 5px;
  background: rgba(255,255,255,0.25); border-radius: 4px;
  letter-spacing: 0.3px;
}

/* Hidden brand rows */
.wom-table tr.wom-row-hidden { display: none; }

/* Header: dark navy bar, non-uppercase — matches funnel/brand-attitude style */
.wom-panel .ct-table .ct-th {
  padding: 12px 14px; text-align: center;
  background: #1a2744; color: #fff;
  font-weight: 600; font-size: 11px;
  text-transform: none; letter-spacing: 0.2px;
  vertical-align: bottom; border-bottom: 2px solid #1a2744;
  white-space: nowrap;
}
.wom-panel .ct-table .ct-th.ct-label-col {
  text-align: left; min-width: 180px; background: #1a2744;
}

/* Sortable headers: indicator + hover — applies to Brand and every data col */
.wom-table th.wom-sortable { user-select: none; cursor: pointer; }
.wom-table th.wom-sortable:hover { background: #243558; }
.wom-table th.wom-sortable .wom-sort-ind {
  display: inline-block; width: 10px; margin-left: 6px;
  opacity: 0.55; font-size: 10px;
}
.wom-table th.wom-sortable[data-wom-sort-dir="asc"]  .wom-sort-ind::before { content: "\\2191"; opacity: 1; }
.wom-table th.wom-sortable[data-wom-sort-dir="desc"] .wom-sort-ind::before { content: "\\2193"; opacity: 1; }
.wom-table th.wom-sortable[data-wom-sort-dir="none"] .wom-sort-ind::before { content: "\\2195"; }

/* Data cell + column-group table shaping */
.wom-table th, .wom-table td { vertical-align: middle; }
.wom-table .wom-th {
  font-size: 11px; font-weight: 600; text-align: center;
  line-height: 1.25; padding: 12px 6px;
}
.wom-table .wom-td-pct,
.wom-table .wom-td-net,
.wom-table .wom-td-freq,
.wom-table .wom-td-avg {
  text-align: center;
}

/* Subtle group dividers before Net heard / Said / Net said / Pos freq */
.wom-table .wom-th[data-wom-col="net_heard"],
.wom-table .wom-th[data-wom-col="shared_pos"],
.wom-table .wom-th[data-wom-col="net_said"],
.wom-table .wom-th[data-wom-col="pos_freq"],
.wom-table td[data-wom-col="net_heard"],
.wom-table td[data-wom-col="shared_pos"],
.wom-table td[data-wom-col="net_said"],
.wom-table td[data-wom-col="pos_freq"] {
  border-left: 1px solid #e2e8f0;
}

/* Net columns get an italic treatment so they read as derived */
.wom-table .wom-th-net {
  font-style: italic; color: #e2e8f0;
}
.wom-table .wom-td-net .ct-val { font-weight: 600; }

/* Heatmap: green (above) / amber (near) / red (below) relative to cat avg ±1 SD.
   Matches the cat_buying panel palette. */
.wom-table td.wom-hm-above {
  background: rgba(5, 150, 105, 0.16) !important; color: #065f46;
}
.wom-table td.wom-hm-below {
  background: rgba(220, 38, 38, 0.14) !important; color: #991b1b;
}
.wom-table td.wom-hm-near {
  background: rgba(251, 191, 36, 0.18) !important; color: #92400e;
}
/* Focal row keeps its tint but preserves heatmap colour of the value */
.wom-table tr.wom-row-focal td.wom-hm-above { background: rgba(5, 150, 105, 0.22) !important; }
.wom-table tr.wom-row-focal td.wom-hm-below { background: rgba(220, 38, 38, 0.20) !important; }
.wom-table tr.wom-row-focal td.wom-hm-near  { background: rgba(251, 191, 36, 0.24) !important; }

/* Cat-avg row CI bar — inherit ma-ci-bar-wrap sizing from MA panel CSS.
   Ensure the CI column reads as a secondary row (same as fn-row-avg-all). */
.wom-table .wom-row-avg td.ct-label-col em {
  color: #475569; font-weight: 500;
}

/* Focal row left-border rail (mirror fn-row-focal) */
.wom-table .wom-row-focal td:first-child {
  box-shadow: inset 3px 0 0 var(--fn-row-accent, %s);
}

/* Chart section — shown only when Show chart toggle is on */
.wom-chart-section {
  margin-top: 14px;
  padding: 14px 14px 10px;
  background: #ffffff;
  border: 1px solid #e2e8f0; border-radius: 8px;
}
.wom-chart-variant[hidden] { display: none !important; }
.wom-chart-svg {
  display: block; width: 100%%; height: auto;
}
.wom-chart-placeholder {
  padding: 36px 20px; text-align: center;
  color: #94a3b8; font-size: 12px;
  border: 1px dashed #cbd5e1; border-radius: 8px;
  background: #f8fafc;
}

/* Insight box — margin tidy-up when stacked below the table */
.wom-insight-box { margin-top: 14px; }
</style>',
    focal_colour)
}
