# ==============================================================================
# SEGMENT HTML REPORT - PAGE STYLING
# ==============================================================================
# CSS stylesheet generation for the segmentation HTML report.
# Uses the shared Turas Design System for base styles and layers
# segment-specific styles on top.
#
# Extracted from 03_page_builder.R for maintainability.
#
# FUNCTIONS:
# - build_seg_css() - Main CSS stylesheet with brand colour substitution
#
# DEPENDENCIES:
# - modules/shared/lib/design_system/design_tokens.R
# - modules/shared/lib/design_system/font_embed.R
# - modules/shared/lib/design_system/base_css.R
# ==============================================================================

# ==============================================================================
# CSS BUILDER
# ==============================================================================

#' Build Segment Report CSS
#'
#' Generates the complete stylesheet for the segmentation HTML report.
#' Uses CSS variables for brand consistency. Replaces BRAND_COLOUR and
#' ACCENT_COLOUR placeholders via gsub().
#'
#' @param brand_colour Brand colour hex string
#' @param accent_colour Accent colour hex string
#' @return Character string of CSS
#' @keywords internal
build_seg_css <- function(brand_colour = "#323367", accent_colour = "#CC9900") {
  css <- '
/* ==== SEGMENT REPORT CSS ==== */
/* seg- namespace for Report Hub safety */
/* Aligned with shared Turas design system */

:root {
  /* Brand colours */
  --seg-brand: BRAND_COLOUR;
  --seg-accent: ACCENT_COLOUR;

  /* Module variables */
  --seg-text: #1e293b;
  --seg-text-muted: #64748b;
  --seg-text-faint: #94a3b8;
  --seg-bg: #f8f7f5;
  --seg-card: #ffffff;
  --seg-border: #e2e8f0;
  --seg-success: #059669;
  --seg-warning: #F59E0B;
  --seg-danger: #c0392b;
}

/* Reset provided by turas_base_css() — only module overrides below */

.seg-body {
  background: var(--seg-bg);
  color: var(--seg-text);
}

/* ================================================================ */
/* HORIZONTAL SECTION NAV BAR                                        */
/* Sticky below header, full-width, underline active indicator       */
/* ================================================================ */

.seg-section-nav {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--seg-card);
  border-bottom: 2px solid var(--seg-border);
  display: flex;
  align-items: center;
  gap: 0;
  padding: 0 24px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.seg-section-nav a {
  display: inline-flex;
  align-items: center;
  padding: 12px 20px;
  color: var(--seg-text-muted);
  text-decoration: none;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  border-bottom: 3px solid transparent;
  cursor: pointer;
  transition: all 0.15s ease;
}

.seg-section-nav a:hover {
  color: var(--seg-brand);
  background: #f8fafc;
}

.seg-section-nav a.active {
  color: var(--seg-brand);
  border-bottom-color: var(--seg-brand);
}

/* ================================================================ */
/* REPORT-LEVEL TABS — shared convention (report-tabs / report-tab)  */
/* ================================================================ */

.report-tabs {
  display: flex;
  align-items: center;
  gap: 0;
  padding: 0 24px;
  background: var(--seg-card);
  border-bottom: 1px solid var(--seg-border);
  box-shadow: 0 1px 2px rgba(0,0,0,0.02);
}

.report-tab {
  padding: 14px 24px;
  font-size: 13px;
  font-weight: 600;
  color: var(--seg-text-muted);
  background: transparent;
  border: none;
  border-bottom: 2px solid transparent;
  cursor: pointer;
  font-family: inherit;
  letter-spacing: 0.1px;
  transition: all 0.15s;
}

.report-tab:hover:not(.active) {
  color: var(--seg-brand);
  background: #fafbfc;
}

.report-tab.active {
  color: var(--seg-brand);
  border-bottom-color: var(--seg-brand);
}

.seg-save-tab {
  margin-left: auto;
  color: var(--seg-brand);
  border-bottom-color: transparent !important;
}

.seg-help-btn {
  width: 28px; height: 28px; border-radius: 50%;
  border: 1.5px solid var(--seg-border);
  background: transparent; color: var(--seg-text-muted);
  font-size: 14px; font-weight: 700; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  margin-left: 8px; transition: all 0.15s;
}
.seg-help-btn:hover { border-color: var(--seg-brand); color: var(--seg-brand); }

/* Tab panel visibility — shared convention */
.tab-panel { display: none; }
.tab-panel.active { display: block; }

/* ================================================================ */
/* MAIN CONTENT                                                      */
/* ================================================================ */

.seg-main {
  min-width: 0;
}

.seg-content {
  max-width: 1100px;
  margin: 0 auto;
  padding: 24px 32px;
}

/* ================================================================ */
/* HEADER — gradient banner with badges                              */
/* ================================================================ */

.seg-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
  padding: 24px 32px;
  border-bottom: 3px solid var(--seg-brand);
}

.seg-header-inner {
  max-width: 1100px;
  margin: 0 auto;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

.seg-header-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.seg-header-branding {
  display: flex;
  align-items: center;
  gap: 16px;
}

.seg-header-logo-container {
  width: 72px;
  height: 72px;
  border-radius: 12px;
  background: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.seg-header-logo-container img {
  height: 56px;
  width: 56px;
  object-fit: contain;
}

.seg-header-module-name {
  color: #ffffff;
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: -0.3px;
}

.seg-header-module-sub {
  color: rgba(255,255,255,0.50);
  font-size: 12px;
  font-weight: 400;
  margin-top: 2px;
}

.seg-header-title {
  color: #ffffff;
  font-size: 22px;
  font-weight: 700;
  letter-spacing: -0.3px;
  margin-top: 16px;
  line-height: 1.2;
}

.seg-header-prepared {
  color: rgba(255,255,255,0.65);
  font-size: 13px;
  font-weight: 400;
  margin-top: 4px;
  line-height: 1.3;
}

.seg-header-badges {
  display: inline-flex;
  align-items: center;
  margin-top: 12px;
  border: 1px solid rgba(255,255,255,0.15);
  border-radius: 6px;
  background: rgba(255,255,255,0.05);
}

.seg-header-badge {
  display: inline-flex;
  align-items: center;
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(255,255,255,0.85);
}

.seg-header-badge-val {
  color: rgba(255,255,255,1);
  font-weight: 700;
}

.seg-header-badge-sep {
  width: 1px;
  height: 16px;
  background: rgba(255,255,255,0.20);
  flex-shrink: 0;
}

/* ================================================================ */
/* SECTIONS (card style)                                             */
/* ================================================================ */

.seg-section {
  background: var(--seg-card);
  border: 1px solid var(--seg-border);
  border-radius: 8px;
  padding: 24px 28px;
  margin-bottom: 20px;
}

.seg-section-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--seg-brand);
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--seg-brand);
}

.seg-section-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--seg-brand);
}

.seg-section-title-row .seg-section-title {
  margin-bottom: 0;
  padding-bottom: 0;
  border-bottom: none;
}

.seg-section-intro {
  color: var(--seg-text-muted);
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.5;
}

/* ================================================================ */
/* TABLES                                                            */
/* ================================================================ */

.seg-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.seg-th {
  background: #f0f1f8;
  color: var(--seg-text-muted);
  font-weight: 600;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  padding: 12px 16px;
  text-align: left;
  border-bottom: 2px solid var(--seg-border);
  vertical-align: bottom;
  white-space: normal;
}

.seg-th-num { text-align: center; }
.seg-th-bar { text-align: left; min-width: 150px; }
.seg-th-rank { text-align: center; width: 50px; }

.seg-td {
  padding: 10px 16px;
  border-bottom: 1px solid #f0f0f0;
  vertical-align: middle;
  color: var(--seg-text);
  font-variant-numeric: tabular-nums;
  transition: background-color 0.15s;
}

.seg-td-num { text-align: center; font-variant-numeric: tabular-nums; }
.seg-td-rank { text-align: center; font-weight: 600; color: var(--seg-brand); }

.seg-tr:nth-child(even) { background: #f9fafb; }
.seg-tr:hover { background: #f8fafc; }

/* Heatmap cell tinting — all numeric, centred, tabular figures */
.seg-td-high { background: #dcfce7; text-align: center; font-variant-numeric: tabular-nums; }
.seg-td-mod-high { background: #eff6ff; text-align: center; font-variant-numeric: tabular-nums; }
.seg-td-mod-low { background: #fef3c7; text-align: center; font-variant-numeric: tabular-nums; }
.seg-td-low { background: #fee2e2; text-align: center; font-variant-numeric: tabular-nums; }

/* Label column — explicitly left-aligned */
.seg-td-label { text-align: left; }
.seg-th-label { text-align: left; }

/* Profile & overlap tables — all cells centred except labels */
.seg-profile-table td,
.seg-overlap-table td { text-align: center; font-variant-numeric: tabular-nums; }
.seg-profile-table td.seg-td-label,
.seg-overlap-table td.seg-td-label { text-align: left; }

/* Heatmap legend strip */
.seg-heatmap-legend {
  display: flex; gap: 20px; align-items: center;
  margin: 12px 0 16px; font-size: 12px; color: var(--seg-text-muted);
}
.seg-heatmap-legend-item { display: inline-flex; align-items: center; gap: 6px; }
.seg-heatmap-legend-swatch {
  display: inline-block; width: 16px; height: 16px;
  border-radius: 3px; border: 1px solid var(--seg-border);
}

/* Overlap table — symmetrical matrix layout */
.seg-overlap-table .seg-td-label { font-weight: 600; color: var(--seg-brand); background: #f8fafc; }

/* Pairwise assessment cards */
.seg-pair-insights { margin-top: 20px; }
.seg-pair-insights-title {
  font-weight: 600; color: var(--seg-brand);
  margin-bottom: 10px; font-size: 14px;
}
.seg-pair-insight {
  padding: 10px 14px; margin: 6px 0;
  border-radius: 6px; font-size: 13px; line-height: 1.5;
}

/* ================================================================ */
/* BADGES                                                            */
/* ================================================================ */

.seg-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.seg-badge-pass { background: #D1FAE5; color: #065F46; }
.seg-badge-warn { background: #FEF3C7; color: #92400E; }
.seg-badge-fail { background: #FEE2E2; color: #991B1B; }

/* ================================================================ */
/* STATUS BADGES                                                     */
/* ================================================================ */

.seg-status-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.seg-status-pass { background: #D1FAE5; color: #065F46; }
.seg-status-partial { background: #FEF3C7; color: #92400E; }
.seg-status-refused { background: #FEE2E2; color: #991B1B; }

/* ================================================================ */
/* EXECUTIVE SUMMARY — callout cards with left border                */
/* ================================================================ */

.seg-callout {
  background: #f8fafa;
  border-left: 3px solid var(--seg-brand);
  padding: 12px 16px;
  border-radius: 0 6px 6px 0;
  margin-bottom: 10px;
}

.seg-callout-title {
  font-weight: 600;
  font-size: 14px;
  margin-bottom: 4px;
  color: var(--seg-text);
}

.seg-callout-text {
  font-size: 13px;
  color: var(--seg-text-muted);
}

.seg-quality-banner {
  padding: 12px 16px;
  border-radius: 6px;
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.5;
}

.seg-quality-excellent { background: #D1FAE5; border-left: 4px solid var(--seg-success); }
.seg-quality-good { background: #DBEAFE; border-left: 4px solid #2563EB; }
.seg-quality-moderate { background: #FEF3C7; border-left: 4px solid var(--seg-warning); }
.seg-quality-limited { background: #FEE2E2; border-left: 4px solid var(--seg-danger); }

.seg-finding-box {
  margin-bottom: 16px;
  padding: 14px 16px;
  background: #f8f9fa;
  border-radius: 6px;
}

.seg-finding-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-bottom: 6px;
}

.seg-finding-icon {
  font-size: 16px;
  font-weight: 700;
  flex-shrink: 0;
}

.seg-finding-text {
  font-size: 13px;
  color: var(--seg-text);
  line-height: 1.4;
}

.seg-key-insights-heading {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--seg-text);
}

.seg-key-insight-item {
  color: var(--seg-text);
  font-size: 13px;
  margin-bottom: 6px;
  line-height: 1.5;
}

.seg-panel-heading-label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--seg-text);
}

/* ================================================================ */
/* IMPORTANCE BARS                                                   */
/* ================================================================ */

.seg-bar-container {
  height: 16px;
  background: #f1f5f9;
  border-radius: 8px;
  overflow: hidden;
}

.seg-bar-fill {
  height: 100%;
  border-radius: 8px;
  transition: width 0.3s ease;
}

/* ================================================================ */
/* CHARTS                                                            */
/* ================================================================ */

.seg-chart { width: 100%; max-width: 700px; height: auto; margin: 16px 0; display: block; }

.seg-chart-wrapper {
  position: relative;
  margin-bottom: 8px;
}

.seg-table-wrapper {
  margin-bottom: 8px;
}

/* Pin button — absolute on charts, inline on tables */
.seg-component-pin {
  background: rgba(255,255,255,0.85);
  border: 1px solid var(--seg-border);
  border-radius: 4px;
  padding: 2px 8px;
  font-size: 11px;
  font-weight: 500;
  color: var(--seg-text-faint);
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s;
}

/* Chart wrappers: pin floats over content */
.seg-chart-wrapper .seg-component-pin {
  position: absolute; top: 4px; right: 4px; z-index: 10;
  opacity: 0;
}
.seg-chart-wrapper:hover .seg-component-pin { opacity: 1; }

.seg-component-pin:hover,
.seg-table-export:hover {
  border-color: var(--seg-brand);
  color: var(--seg-brand);
  background: rgba(255,255,255,0.95);
}

.seg-component-pin.seg-pin-btn-active {
  background: var(--seg-brand);
  color: white;
  border-color: var(--seg-brand);
}

/* Table toolbar — right-aligned row above table, visible on hover */
.seg-table-toolbar {
  display: flex;
  justify-content: flex-end;
  gap: 6px;
  margin-bottom: 4px;
  opacity: 0;
  transition: opacity 0.15s;
}
.seg-table-wrapper:hover .seg-table-toolbar { opacity: 1; }

/* Table export button — same style as pin */
.seg-table-export {
  background: rgba(255,255,255,0.85);
  border: 1px solid var(--seg-border);
  border-radius: 4px;
  padding: 2px 8px;
  font-size: 11px;
  font-weight: 500;
  color: var(--seg-text-faint);
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s;
}

/* ================================================================ */
/* SEGMENT ACTION CARDS                                              */
/* ================================================================ */

.seg-cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 16px;
  margin-top: 12px;
}

.seg-action-card {
  background: #f8f9fa;
  border: 1px solid var(--seg-border);
  border-radius: 8px;
  padding: 16px 20px;
  border-top: 3px solid var(--seg-brand);
  transition: box-shadow 0.15s;
}

.seg-action-card:hover {
  box-shadow: 0 2px 12px rgba(0,0,0,0.06);
}

.seg-action-card-name {
  font-size: 16px;
  font-weight: 700;
  color: var(--seg-brand);
  margin-bottom: 4px;
}

.seg-action-card-size {
  font-size: 12px;
  color: var(--seg-text-muted);
  margin-bottom: 10px;
}

.seg-action-card-label {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  color: var(--seg-text-faint);
  margin-bottom: 4px;
  margin-top: 10px;
}

.seg-action-card-text {
  font-size: 13px;
  color: var(--seg-text);
  line-height: 1.5;
}

.seg-action-card-list {
  font-size: 13px;
  color: var(--seg-text);
  padding-left: 16px;
  line-height: 1.6;
}

/* ================================================================ */
/* FIT STATISTIC CARDS (validation metrics)                          */
/* ================================================================ */

.seg-fit-cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
  margin-top: 8px;
}

.seg-fit-card {
  background: #f8f9fa;
  border: 1px solid var(--seg-border);
  border-radius: 6px;
  padding: 12px 16px;
  border-left: 3px solid var(--seg-brand);
}

.seg-fit-card-value {
  font-size: 18px;
  font-weight: 700;
  color: var(--seg-text);
  font-variant-numeric: tabular-nums;
}

.seg-fit-card-label {
  font-size: 12px;
  font-weight: 600;
  color: var(--seg-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.3px;
  margin-top: 2px;
}

.seg-fit-card-quality {
  font-size: 11px;
  font-weight: 600;
  color: var(--seg-brand);
  margin-top: 4px;
}

.seg-fit-card-note {
  font-size: 11px;
  color: var(--seg-text-faint);
  line-height: 1.4;
  margin-top: 6px;
}

/* ================================================================ */
/* INSIGHT EDITORS — per-section editable text areas                  */
/* ================================================================ */

.seg-insight-area {
  margin-bottom: 12px;
}

.seg-insight-toggle {
  background: none;
  border: 1px dashed var(--seg-border);
  border-radius: 6px;
  padding: 6px 14px;
  font-size: 12px;
  font-weight: 500;
  color: var(--seg-text-muted);
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s;
}

.seg-insight-toggle:hover {
  border-color: var(--seg-brand);
  color: var(--seg-brand);
  background: rgba(50,51,103,0.03);
}

.seg-insight-container {
  display: none;
  margin-top: 8px;
  position: relative;
}

.seg-insight-editor {
  width: 100%;
  min-height: 60px;
  padding: 12px;
  border: 1px dashed rgba(50,51,103,0.4);
  border-radius: 4px;
  font-size: 13px;
  font-family: inherit;
  line-height: 1.5;
  color: var(--seg-text);
  outline: none;
  transition: border-color 0.15s, background 0.15s, box-shadow 0.15s;
}

.seg-insight-editor:focus {
  border-style: solid;
  border-color: var(--seg-brand);
  background: #f0f4ff;
  box-shadow: inset 0 1px 4px rgba(50,51,103,0.10);
}

.seg-insight-hint {
  font-size: 11px;
  color: var(--seg-text-faint);
  margin-top: 4px;
  font-style: italic;
}

.seg-insight-editor:empty::before {
  content: attr(data-placeholder);
  color: var(--seg-text-faint);
  pointer-events: none;
}

.seg-insight-dismiss {
  position: absolute;
  top: 4px;
  right: 4px;
  background: none;
  border: none;
  font-size: 14px;
  color: var(--seg-text-faint);
  cursor: pointer;
  padding: 2px 6px;
  border-radius: 4px;
  transition: all 0.15s;
}

.seg-insight-dismiss:hover {
  color: var(--seg-danger);
  background: rgba(192,57,43,0.06);
}

/* ================================================================ */
/* PIN BUTTON                                                        */
/* ================================================================ */

.seg-pin-btn {
  background: none;
  border: 1px solid var(--seg-border);
  border-radius: 6px;
  padding: 4px 10px;
  font-size: 14px;
  cursor: pointer;
  color: var(--seg-text-faint);
  transition: all 0.15s;
  flex-shrink: 0;
}

.seg-pin-btn:hover {
  border-color: var(--seg-brand);
  color: var(--seg-brand);
  background: rgba(50,51,103,0.03);
}

.seg-pin-btn.seg-pin-btn-active {
  background: var(--seg-brand);
  color: white;
  border-color: var(--seg-brand);
}

/* ================================================================ */
/* PINNED VIEWS PANEL                                                */
/* ================================================================ */

.seg-pinned-panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}

.seg-pinned-panel-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--seg-brand);
}

.seg-pinned-panel-actions {
  display: flex;
  gap: 8px;
}

.seg-pinned-panel-btn {
  padding: 6px 14px;
  border: 1px solid var(--seg-border);
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  color: var(--seg-text-muted);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.seg-pinned-panel-btn:hover {
  border-color: var(--seg-brand);
  color: var(--seg-brand);
}

.seg-pinned-empty {
  text-align: center;
  padding: 48px 24px;
  color: var(--seg-text-faint);
  font-size: 14px;
}

.seg-pinned-empty-icon {
  font-size: 32px;
  margin-bottom: 8px;
  opacity: 0.4;
}

.seg-pinned-card {
  background: var(--seg-card);
  border: 1px solid var(--seg-border);
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 16px;
  transition: box-shadow 0.15s;
}

.seg-pinned-card:hover {
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}

.seg-pinned-card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 10px;
}

.seg-pinned-card-title {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.seg-pinned-card-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--seg-brand);
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.seg-pinned-card-section {
  font-size: 15px;
  font-weight: 600;
  color: var(--seg-text);
}

.seg-pinned-card-actions {
  display: flex;
  gap: 4px;
  flex-shrink: 0;
}

.seg-pinned-action-btn {
  background: none;
  border: 1px solid transparent;
  border-radius: 4px;
  padding: 3px 7px;
  font-size: 12px;
  cursor: pointer;
  color: var(--seg-text-faint);
  transition: all 0.15s;
}

.seg-pinned-action-btn:hover {
  border-color: var(--seg-border);
  color: var(--seg-text-muted);
  background: #f8f9fa;
}

.seg-pinned-remove-btn:hover {
  color: var(--seg-danger);
  background: rgba(192,57,43,0.06);
}

.seg-pinned-export-btn:hover {
  color: var(--seg-brand);
  background: rgba(50,51,103,0.04);
}

.seg-pinned-card-insight {
  padding: 10px 14px;
  border-left: 3px solid var(--seg-accent);
  background: #faf9f7;
  border-radius: 0 6px 6px 0;
  font-size: 13px;
  color: #475569;
  line-height: 1.5;
  margin-bottom: 10px;
}

.seg-pinned-card-chart {
  margin-top: 10px;
  overflow: visible;
}

.seg-pinned-card-chart svg {
  width: 100%;
  height: auto;
  display: block;
}

.seg-pinned-card-table {
  margin-top: 10px;
  overflow-x: auto;
  overflow-y: visible;
}

.seg-pinned-card-table table {
  width: 100%;
  font-size: 12px;
  table-layout: fixed;
}

.seg-pinned-card-table th,
.seg-pinned-card-table td {
  word-wrap: break-word;
  overflow-wrap: break-word;
}

/* ================================================================ */
/* SECTION DIVIDERS                                                  */
/* ================================================================ */

.seg-section-divider {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 0;
  margin: 8px 0;
  border-bottom: 2px solid var(--seg-brand);
}

.seg-section-divider-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--seg-brand);
  flex: 1;
  outline: none;
  min-width: 100px;
}

.seg-section-divider-title:focus {
  border-bottom: 1px dashed var(--seg-border);
}

.seg-section-divider-actions {
  display: flex;
  gap: 4px;
}

/* ================================================================ */
/* ACTION BAR                                                        */
/* ================================================================ */

.seg-action-bar {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  padding: 8px 24px;
  background: var(--seg-card);
  border-bottom: 1px solid var(--seg-border);
}

.seg-save-btn {
  padding: 7px 18px;
  border: 1px solid var(--seg-brand);
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  color: var(--seg-brand);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.seg-save-btn:hover {
  background: var(--seg-brand);
  color: white;
}

.seg-saved-badge {
  display: none;
  opacity: 0;
  transition: opacity 0.3s ease;
  font-size: 11px;
  color: var(--seg-text-faint);
  font-weight: 400;
}

.seg-pin-count-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  background: var(--seg-accent);
  color: white;
  border-radius: 9px;
  font-size: 10px;
  font-weight: 700;
  margin-left: 6px;
}

/* ================================================================ */
/* INTERPRETATION GUIDE — DO/DONT grid                               */
/* ================================================================ */

.seg-interp-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.seg-interp-list {
  font-size: 13px;
  color: var(--seg-text-muted);
  padding-left: 16px;
}

.seg-interp-list li { margin-bottom: 6px; line-height: 1.4; }

.seg-interp-note {
  margin-top: 16px;
  padding: 12px 16px;
  background: #f8fafa;
  border-radius: 6px;
  border-left: 3px solid var(--seg-brand);
  font-size: 12px;
  color: var(--seg-text-muted);
  line-height: 1.5;
}

/* ================================================================ */
/* FOOTER                                                            */
/* ================================================================ */

.seg-footer {
  text-align: center;
  padding: 24px;
  color: var(--seg-text-faint);
  font-size: 11px;
  border-top: 1px solid var(--seg-border);
  margin-top: 32px;
}

/* ================================================================ */
/* PRINT STYLES                                                      */
/* ================================================================ */

@media print {
  .report-tabs { display: none !important; }
  .seg-section-nav { display: none !important; }
  .seg-action-bar { display: none !important; }
  .seg-pin-btn { display: none !important; }
  .seg-component-pin { display: none !important; }
  .seg-insight-toggle { display: none !important; }
  .seg-insight-area { display: none !important; }
  .seg-pinned-card-actions { display: none !important; }
  .seg-content { padding: 16px !important; max-width: none !important; }
  .seg-body { background: white; font-size: 11px; }
  .seg-section { break-inside: avoid; page-break-inside: avoid; border: none; box-shadow: none; }
  .seg-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .seg-header-inner { max-width: none !important; }
  .seg-header-inner * { color: #1a2744 !important; }
  .seg-header-module-name { font-size: 16px !important; }
  .seg-header-title { font-size: 14px !important; margin-top: 4px !important; }
  .seg-header-logo-container { width: 32px !important; height: 32px !important; }
  .seg-header-logo-container img { width: 28px !important; height: 28px !important; }
  .seg-chart { max-width: 500px; }
}

@media (max-width: 768px) {
  .seg-section-nav { padding: 0 12px; }
  .seg-section-nav a { padding: 10px 14px; font-size: 12px; }
  .seg-content { padding: 16px; }
  .seg-interp-grid { grid-template-columns: 1fr; }
  .seg-header { padding: 16px; }
  .seg-header-module-name { font-size: 20px; }
  .seg-header-title { font-size: 18px; }
  .seg-cards-grid { grid-template-columns: 1fr; }
}
'
  css <- gsub("BRAND_COLOUR", brand_colour, css, fixed = TRUE)
  css <- gsub("ACCENT_COLOUR", accent_colour, css, fixed = TRUE)

  # Prepend shared design system CSS
  shared_css <- tryCatch(turas_base_css(brand_colour, accent_colour, prefix = "seg"), error = function(e) "")
  css <- paste0(shared_css, "\n", css)

  css
}

