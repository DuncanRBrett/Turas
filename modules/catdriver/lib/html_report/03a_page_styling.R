# ==============================================================================
# CATDRIVER HTML REPORT - PAGE STYLING
# ==============================================================================
# CSS stylesheet generation for the categorical driver HTML report.
# Uses the shared Turas Design System for base styles.
# Extracted from 03_page_builder.R for maintainability.
# ==============================================================================

build_cd_css <- function(brand_colour, accent_colour) {
  # Shared base CSS (Inter font, tokens, typography, common components)
  shared_css <- tryCatch(
    turas_base_css(brand_colour, accent_colour, prefix = "cd"),
    error = function(e) ""
  )

  css <- '
/* ==== CATDRIVER REPORT CSS ==== */
/* cd- namespace for Report Hub safety */
/* Aligned with shared Turas design system (tabs/tracker) */

:root {
  /* Brand colours */
  --cd-brand: BRAND_COLOUR;
  --cd-accent: ACCENT_COLOUR;

  /* Module variables */
  --cd-text: #1e293b;
  --cd-text-muted: #64748b;
  --cd-text-faint: #94a3b8;
  --cd-bg: #f8f7f5;
  --cd-bg-muted: #f8f9fa;
  --cd-bg-subtle: #f0f4f8;
  --cd-card: #ffffff;
  --cd-border: #e2e8f0;
  --cd-border-subtle: #f0f0f0;
  --cd-success: #059669;
  --cd-warning: #F59E0B;
  --cd-danger: #c0392b;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

.cd-body {
  font-family: inherit;
  background: var(--cd-bg);
  color: var(--cd-text);
  line-height: 1.5;
  font-size: 13px;
}

/* ================================================================ */
/* HORIZONTAL SECTION NAV BAR — matches tabs/tracker .report-tabs   */
/* Sticky below header, full-width, underline active indicator      */
/* ================================================================ */

.cd-section-nav {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--cd-card);
  border-bottom: 2px solid var(--cd-border);
  display: flex;
  align-items: center;
  gap: 0;
  padding: 0 24px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.cd-section-nav a {
  display: inline-flex;
  align-items: center;
  padding: 12px 20px;
  color: var(--cd-text-muted);
  text-decoration: none;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  border-bottom: 3px solid transparent;
  cursor: pointer;
  transition: all 0.15s ease;
}

.cd-section-nav a:hover {
  color: var(--cd-brand);
  background: #f8fafc;
}

.cd-section-nav a.active {
  color: var(--cd-brand);
  border-bottom-color: var(--cd-brand);
}

/* ================================================================ */
/* MAIN CONTENT — full-width, no sidebar offset                     */
/* ================================================================ */

.cd-main {
  min-width: 0;
}

.cd-content {
  max-width: 1100px;
  margin: 0 auto;
  padding: 24px 32px;
}

/* ================================================================ */
/* HEADER — matches tabs/tracker gradient banner with logo + badges */
/* ================================================================ */

.cd-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
  padding: 24px 32px;
  border-bottom: 3px solid var(--cd-brand);
}

.cd-header-inner {
  max-width: 1100px;
  margin: 0 auto;
  font-family: inherit;
}

.cd-header-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.cd-header-branding {
  display: flex;
  align-items: center;
  gap: 16px;
}

.cd-header-logo-container {
  width: 72px;
  height: 72px;
  border-radius: 12px;
  background: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.cd-header-logo-container img {
  height: 56px;
  width: 56px;
  object-fit: contain;
}

.cd-header-module-name {
  color: #ffffff;
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: -0.3px;
}

.cd-header-module-sub {
  color: rgba(255,255,255,0.50);
  font-size: 12px;
  font-weight: 400;
  margin-top: 2px;
}

.cd-header-title {
  color: #ffffff;
  font-size: 22px;
  font-weight: 700;
  letter-spacing: -0.3px;
  margin-top: 16px;
  line-height: 1.2;
}

.cd-header-prepared {
  color: rgba(255,255,255,0.65);
  font-size: 13px;
  font-weight: 400;
  margin-top: 4px;
  line-height: 1.3;
}

.cd-header-badges {
  display: inline-flex;
  align-items: center;
  margin-top: 12px;
  border: 1px solid rgba(255,255,255,0.15);
  border-radius: 6px;
  background: rgba(255,255,255,0.05);
}

.cd-header-badge {
  display: inline-flex;
  align-items: center;
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(255,255,255,0.85);
}

.cd-header-badge-val {
  color: rgba(255,255,255,1);
  font-weight: 700;
}

.cd-header-badge-sep {
  width: 1px;
  height: 16px;
  background: rgba(255,255,255,0.20);
  flex-shrink: 0;
}

/* ================================================================ */
/* SECTIONS (card style)                                            */
/* ================================================================ */

.cd-section {
  background: var(--cd-card);
  border: 1px solid var(--cd-border);
  border-radius: 8px;
  padding: 24px 28px;
  margin-bottom: 20px;
}

/* Page-based navigation: hide all sections, show only active */
.cd-content .cd-section {
  display: none;
}
.cd-content .cd-section.cd-page-active {
  display: block;
}

.cd-section-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--cd-brand);
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--cd-brand);
}

.cd-section-intro {
  color: var(--cd-text-muted);
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.5;
}
.cd-effect-legend {
  font-size: 11px; color: #64748b; background: #f8fafc;
  border: 1px solid #e2e8f0; border-radius: 6px;
  padding: 8px 14px; margin-bottom: 14px; line-height: 1.6;
}
.cd-effect-tag {
  display: inline-block; background: #e2e8f0; border-radius: 3px;
  padding: 1px 6px; font-weight: 600; color: #334155; font-size: 10px;
}

/* ================================================================ */
/* MODEL FIT STATISTIC CARDS                                        */
/* ================================================================ */

.cd-fit-cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
  margin-top: 8px;
}

.cd-fit-card {
  background: var(--cd-bg-muted);
  border: 1px solid var(--cd-border);
  border-radius: 6px;
  padding: 12px 16px;
  border-left: 3px solid var(--cd-brand);
}

.cd-fit-card-value {
  font-size: 18px;
  font-weight: 700;
  color: var(--cd-text);
  font-variant-numeric: tabular-nums;
}

.cd-fit-card-label {
  font-size: 12px;
  font-weight: 600;
  color: var(--cd-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.3px;
  margin-top: 2px;
}

.cd-fit-card-quality {
  font-size: 11px;
  font-weight: 600;
  color: var(--cd-brand);
  margin-top: 4px;
}

.cd-fit-card-verdict {
  display: inline-block;
  font-size: 12px;
  font-weight: 700;
  padding: 3px 10px;
  border-radius: 4px;
  margin-top: 6px;
  letter-spacing: 0.3px;
}
.cd-fit-card-verdict.cd-verdict-yes {
  background: #ecfdf5;
  color: #059669;
  border: 1px solid #a7f3d0;
}
.cd-fit-card-verdict.cd-verdict-no {
  background: #fef2f2;
  color: #dc2626;
  border: 1px solid #fecaca;
}

.cd-fit-card-note {
  font-size: 11px;
  color: var(--cd-text-faint);
  line-height: 1.4;
  margin-top: 6px;
}

/* ================================================================ */
/* STATUS BADGES                                                    */
/* ================================================================ */

.cd-status-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.cd-status-pass { background: #D1FAE5; color: #065F46; }
.cd-status-partial { background: #FEF3C7; color: #92400E; }
.cd-status-refused { background: #FEE2E2; color: #991B1B; }

/* ================================================================ */
/* TABLES — matches tabs/tracker ct-th/ct-td pattern                */
/* ================================================================ */

.cd-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

th.cd-th {
  background: var(--cd-bg-muted, #f8f9fa);
  color: var(--cd-text-muted);
  font-weight: 600;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  padding: 12px 16px;
  text-align: left;
  border-bottom: 2px solid var(--cd-border);
  vertical-align: bottom;
  white-space: normal;
}

.cd-th-num, .cd-th-sig, .cd-th-effect, .cd-th-status { text-align: center; }
.cd-th-bar { text-align: left; min-width: 150px; }
.cd-th-rank { text-align: center; width: 50px; }

td.cd-td {
  padding: 10px 16px;
  border-bottom: 1px solid var(--cd-border-subtle, #f0f0f0);
  vertical-align: middle;
  color: var(--cd-text);
  font-variant-numeric: tabular-nums;
  transition: background-color 0.15s;
}

.cd-td-num { text-align: center; font-variant-numeric: tabular-nums; }
.cd-td-rank { text-align: center; font-weight: 600; color: var(--cd-brand); }
.cd-td-sig { text-align: center; }
.cd-td-effect { text-align: center; }
.cd-td-status { text-align: center; }
.cd-td-interp { font-size: 12px; color: var(--cd-text-muted); }

.cd-tr:nth-child(even) { background: var(--cd-bg-muted, #f9fafb); }
.cd-tr:hover { background: var(--cd-bg-subtle, #f8fafc); }
.cd-tr-reference { background: #f0fdf4; }
.cd-tr-reference:hover { background: #ecfdf5; }

/* ================================================================ */
/* IMPORTANCE BARS                                                  */
/* ================================================================ */

.cd-bar-container {
  height: 16px;
  background: var(--cd-bg-subtle, #f1f5f9);
  border-radius: 8px;
  overflow: hidden;
}

.cd-bar-fill {
  height: 100%;
  border-radius: 8px;
  transition: width 0.3s ease;
}

/* ================================================================ */
/* SIGNIFICANCE — matches tabs/tracker sig badge style              */
/* ================================================================ */

.cd-sig-strong {
  color: var(--cd-success);
  font-weight: 700;
  font-size: 9px;
  font-family: ui-monospace, "Cascadia Code", Consolas, monospace;
  background: rgba(5,150,105,0.08);
  border-radius: 3px;
  padding: 0 4px;
  display: inline-block;
}

.cd-sig-moderate {
  color: #92400E;
  font-weight: 600;
  font-size: 9px;
  font-family: ui-monospace, "Cascadia Code", Consolas, monospace;
  background: rgba(146,64,14,0.08);
  border-radius: 3px;
  padding: 0 4px;
  display: inline-block;
}

.cd-sig-none {
  color: var(--cd-text-faint);
  font-size: 11px;
}

/* ================================================================ */
/* EFFECT COLOUR CLASSES                                            */
/* ================================================================ */

.cd-effect-pos { background: #D1FAE5; color: #065F46; border-radius: 4px; padding: 1px 6px; }
.cd-effect-neg { background: #FEE2E2; color: #991B1B; border-radius: 4px; padding: 1px 6px; }
.cd-effect-mod { background: #FEF3C7; color: #92400E; border-radius: 4px; padding: 1px 6px; }
.cd-effect-none { }

/* ================================================================ */
/* DIAGNOSTIC BADGES                                                */
/* ================================================================ */

.cd-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
}

.cd-badge-pass { background: #D1FAE5; color: #065F46; }
.cd-badge-warn { background: #FEF3C7; color: #92400E; }
.cd-badge-fail { background: #FEE2E2; color: #991B1B; }

/* ================================================================ */
/* EXECUTIVE SUMMARY — top-driver cards with left border            */
/* Educational callouts now use shared .t-callout from base_css     */
/* ================================================================ */

.cd-callout {
  background: #f8fafa;
  border-left: 3px solid var(--cd-brand);
  padding: 12px 16px;
  border-radius: 0 6px 6px 0;
  margin-bottom: 10px;
}

.cd-callout-title {
  font-weight: 600;
  font-size: 14px;
  margin-bottom: 4px;
  color: var(--cd-text);
}

.cd-callout-text {
  font-size: 13px;
  color: var(--cd-text-muted);
}

/* Sample info bar — n= and weighting status */
.cd-sample-info-bar {
  display: flex; gap: 8px; align-items: center; margin-bottom: 12px;
}
.cd-sample-badge, .cd-weight-badge {
  display: inline-block; padding: 4px 12px; border-radius: 4px;
  font-size: 12px; font-weight: 600; line-height: 1;
}
.cd-sample-badge {
  background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0;
}
.cd-weight-badge {
  background: #fef3c7; color: #92400e; border: 1px solid #fcd34d;
}
.cd-weight-badge.cd-weight-on {
  background: #dbeafe; color: #1e40af; border: 1px solid #93c5fd;
}

.cd-model-confidence {
  padding: 12px 16px;
  border-radius: 6px;
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.5;
}

.cd-confidence-excellent { background: #D1FAE5; border-left: 4px solid var(--cd-success); }
.cd-confidence-good { background: #DBEAFE; border-left: 4px solid #2563EB; }
.cd-confidence-moderate { background: #FEF3C7; border-left: 4px solid var(--cd-warning); }
.cd-confidence-limited { background: #FEE2E2; border-left: 4px solid var(--cd-danger); }

/* ================================================================ */
/* CHARTS                                                           */
/* ================================================================ */

.cd-chart, .cd-forest-plot { width: 100%; max-width: 700px; height: auto; margin: 16px 0; display: block; }

/* ================================================================ */
/* FACTOR PICKER — pill tabs                                        */
/* ================================================================ */

.cd-factor-tabs {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 16px;
}

.cd-factor-tab {
  padding: 6px 14px;
  border: 1px solid var(--cd-border);
  border-radius: 20px;
  font-size: 12px;
  font-weight: 500;
  color: var(--cd-text-muted);
  cursor: pointer;
  background: white;
  transition: all 0.15s;
}

.cd-factor-tab:hover { border-color: var(--cd-brand); color: var(--cd-brand); }
.cd-factor-tab.active { background: var(--cd-brand); color: white; border-color: var(--cd-brand); }

.cd-factor-panel { display: none; }
.cd-factor-panel.active { display: block; }

/* ================================================================ */
/* INTERPRETATION GUIDE — DO/DON T grid                             */
/* ================================================================ */

.cd-interp-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.cd-interp-list {
  font-size: 13px;
  color: var(--cd-text-muted);
  padding-left: 16px;
}

.cd-interp-list li { margin-bottom: 6px; line-height: 1.4; }

.cd-interp-note {
  margin-top: 16px;
  padding: 12px 16px;
  background: #f8fafa;
  border-radius: 6px;
  border-left: 3px solid var(--cd-brand);
  font-size: 12px;
  color: var(--cd-text-muted);
  line-height: 1.5;
}

/* ================================================================ */
/* FOOTER                                                           */
/* ================================================================ */

.cd-footer {
  text-align: center;
  padding: 24px;
  color: var(--cd-text-faint);
  font-size: 11px;
  border-top: 1px solid var(--cd-border);
  margin-top: 32px;
}

/* ================================================================ */
/* EXECUTIVE SUMMARY — CSS class versions of inline styles          */
/* ================================================================ */

.cd-key-insights-heading {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--cd-text);
}

.cd-key-insight-item {
  color: var(--cd-text);
  font-size: 13px;
  margin-bottom: 6px;
  line-height: 1.5;
}

.cd-finding-box {
  margin-bottom: 16px;
  padding: 14px 16px;
  background: var(--cd-bg-muted);
  border-radius: 6px;
}

.cd-finding-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-bottom: 6px;
}

.cd-finding-icon {
  font-size: 16px;
  font-weight: 700;
  flex-shrink: 0;
}

.cd-finding-text {
  font-size: 13px;
  color: var(--cd-text);
  line-height: 1.4;
}

.cd-top-drivers-label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 10px;
  color: var(--cd-text);
}

.cd-panel-heading-label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--cd-text);
}

/* ================================================================ */
/* INSIGHT EDITORS — per-section editable text areas                 */
/* ================================================================ */

.cd-insight-area {
  margin-bottom: 12px;
}

.cd-insight-toggle {
  background: none;
  border: 1px dashed var(--cd-border);
  border-radius: 6px;
  padding: 6px 14px;
  font-size: 12px;
  font-weight: 500;
  color: var(--cd-text-muted);
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s;
}

.cd-insight-toggle:hover {
  border-color: var(--cd-brand);
  color: var(--cd-brand);
  background: rgba(50,51,103,0.03);
}

.cd-insight-container {
  display: none;
  margin-top: 8px;
  position: relative;
}

.cd-insight-editor {
  width: 100%;
  min-height: 60px;
  padding: 10px 14px;
  border: 1px solid var(--cd-border);
  border-radius: 6px;
  font-size: 13px;
  font-family: inherit;
  line-height: 1.5;
  color: var(--cd-text);
  outline: none;
  transition: border-color 0.15s;
}

.cd-insight-editor:focus {
  border-color: var(--cd-brand);
  box-shadow: 0 0 0 2px rgba(50,51,103,0.08);
}

.cd-insight-editor:empty::before {
  content: attr(data-placeholder);
  color: var(--cd-text-faint);
  pointer-events: none;
}

.cd-insight-dismiss {
  position: absolute;
  top: 4px;
  right: 4px;
  background: none;
  border: none;
  font-size: 14px;
  color: var(--cd-text-faint);
  cursor: pointer;
  padding: 2px 6px;
  border-radius: 4px;
  transition: all 0.15s;
}

.cd-insight-dismiss:hover {
  color: var(--cd-danger);
  background: rgba(192,57,43,0.06);
}

/* ================================================================ */
/* SECTION TITLE ROW — title + pin button in flex row                */
/* ================================================================ */

.cd-section-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--cd-brand);
}

.cd-section-title-row .cd-section-title {
  margin-bottom: 0;
  padding-bottom: 0;
  border-bottom: none;
}

.cd-pin-btn {
  background: none;
  border: 1px solid var(--cd-border);
  border-radius: 6px;
  padding: 4px 10px;
  font-size: 14px;
  cursor: pointer;
  color: var(--cd-text-faint);
  transition: all 0.15s;
  flex-shrink: 0;
}

.cd-pin-btn:hover {
  border-color: var(--cd-brand);
  color: var(--cd-brand);
  background: rgba(50,51,103,0.03);
}

.cd-pin-btn.cd-pin-btn-active {
  background: var(--cd-brand);
  color: white;
  border-color: var(--cd-brand);
}

/* PIN COUNT BADGE — small count in nav link                         */
/* ================================================================ */

.cd-pin-count-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  font-size: 10px;
  font-weight: 700;
  line-height: 1;
  color: white;
  background: var(--cd-brand, #323367);
  border-radius: 9px;
  margin-left: 4px;
  vertical-align: middle;
}

/* ================================================================ */
/* CHART/TABLE WRAPPERS — containers with component pin buttons      */
/* ================================================================ */

.cd-chart-wrapper,
.cd-table-wrapper {
  position: relative;
  margin-bottom: 8px;
}

/* Table export bar — CSV / Excel buttons */
.cd-table-export-bar {
  position: absolute;
  top: 4px;
  right: 4px;
  z-index: 10;
  display: flex;
  gap: 4px;
  opacity: 0;
  transition: opacity 0.15s;
}
.cd-table-wrapper:hover .cd-table-export-bar {
  opacity: 1;
}
.cd-table-export-btn {
  background: rgba(255,255,255,0.92);
  border: 1px solid var(--cd-border);
  border-radius: 4px;
  padding: 3px 10px;
  font-size: 11px;
  font-weight: 500;
  color: var(--cd-text-faint);
  cursor: pointer;
  font-family: inherit;
  line-height: 1;
}
.cd-table-export-btn:hover {
  border-color: var(--cd-brand);
  color: var(--cd-brand);
  background: rgba(255,255,255,0.98);
}

/* Pin popover — now injected by shared turas_pins_popover.js */

/* Drag-and-drop reordering for pinned cards */
.cd-pin-dragging,
.turas-pin-dragging { opacity: 0.4; }
.cd-pin-drop-target,
.turas-pin-drop-target {
  outline: 2px dashed var(--cd-brand);
  outline-offset: -2px;
}

/* Drag cursor for pinned cards and section dividers */
.cd-pinned-card[draggable="true"],
.cd-pinned-card[data-pin-drag-idx],
.cd-section-divider[draggable="true"] {
  cursor: grab;
}
.cd-pinned-card[draggable="true"]:active,
.cd-pinned-card[data-pin-drag-idx]:active,
.cd-section-divider[draggable="true"]:active {
  cursor: grabbing;
}

/* ================================================================ */
/* OR FACTOR CHIP BAR — filter pills above odds ratio table          */
/* ================================================================ */

.cd-or-chip-bar {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 14px;
}

.cd-or-chip {
  padding: 5px 12px;
  border: 1px solid var(--cd-border);
  border-radius: 20px;
  font-size: 12px;
  font-weight: 500;
  color: var(--cd-text-muted);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.cd-or-chip:hover {
  border-color: var(--cd-brand);
  color: var(--cd-brand);
}

.cd-or-chip.active {
  background: var(--cd-brand);
  color: white;
  border-color: var(--cd-brand);
}

/* ================================================================ */
/* PINNED VIEWS PANEL — card grid for pinned sections                */
/* ================================================================ */

.cd-pinned-panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}

.cd-pinned-panel-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--cd-brand);
}

.cd-pinned-panel-actions {
  display: flex;
  gap: 8px;
}

.cd-pinned-panel-btn {
  padding: 6px 14px;
  border: 1px solid var(--cd-border);
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  color: var(--cd-text-muted);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.cd-pinned-panel-btn:hover {
  border-color: var(--cd-brand);
  color: var(--cd-brand);
}

.cd-pinned-empty {
  text-align: center;
  padding: 48px 24px;
  color: var(--cd-text-faint);
  font-size: 14px;
}

.cd-pinned-empty-icon {
  font-size: 32px;
  margin-bottom: 8px;
  opacity: 0.4;
}

.cd-pinned-card {
  background: var(--cd-card);
  border: 1px solid var(--cd-border);
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 16px;
  transition: box-shadow 0.15s;
}

.cd-pinned-card:hover {
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}

.cd-pinned-card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 10px;
}

.cd-pinned-card-title {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.cd-pinned-card-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--cd-brand);
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.cd-pinned-card-section {
  font-size: 15px;
  font-weight: 600;
  color: var(--cd-text);
}

.cd-pinned-card-actions {
  display: flex;
  gap: 4px;
  flex-shrink: 0;
}

.cd-pinned-action-btn {
  background: none;
  border: 1px solid transparent;
  border-radius: 4px;
  padding: 3px 7px;
  font-size: 12px;
  cursor: pointer;
  color: var(--cd-text-faint);
  transition: all 0.15s;
}

.cd-pinned-action-btn:hover {
  border-color: var(--cd-border);
  color: var(--cd-text-muted);
  background: #f8f9fa;
}

.cd-pinned-remove-btn:hover {
  color: var(--cd-danger);
  background: rgba(192,57,43,0.06);
}

.cd-pinned-export-btn:hover {
  color: var(--cd-brand);
  background: rgba(50,51,103,0.04);
}

.cd-pinned-card-insight {
  padding: 10px 14px;
  border-left: 3px solid var(--cd-accent);
  background: #faf9f7;
  border-radius: 0 6px 6px 0;
  font-size: 13px;
  color: #475569;
  line-height: 1.5;
  margin-bottom: 10px;
}

.cd-pinned-insight-rendered { min-height: 1em; cursor: text; }
.cd-pinned-insight-rendered:empty::before {
  content: attr(data-placeholder); color: #94a3b8; font-style: italic;
}
.cd-pinned-insight-editor {
  width: 100%; border: 1px solid #cbd5e1; border-radius: 4px;
  padding: 8px 12px; font-size: 13px; font-family: inherit;
  line-height: 1.5; resize: vertical; min-height: 60px;
}

.cd-pinned-card-chart {
  margin-top: 10px;
  overflow: visible;
}

.cd-pinned-card-chart svg {
  width: 100%;
  height: auto;
  display: block;
}

.cd-pinned-card-table {
  margin-top: 10px;
  overflow-x: auto;
  overflow-y: visible;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
}

.cd-pinned-card-table table {
  width: 100%;
  font-size: 12px;
  border-collapse: collapse;
  font-variant-numeric: tabular-nums;
}

.cd-pinned-card-table th {
  padding: 10px 14px;
  font-weight: 600;
  font-size: 11px;
  letter-spacing: 0.3px;
  text-align: center;
  color: #e2e8f0;
  background: #1a2744;
  border-bottom: 2px solid #0f1b30;
  white-space: nowrap;
  vertical-align: bottom;
}

.cd-pinned-card-table th:first-child {
  text-align: left;
}

.cd-pinned-card-table td {
  padding: 8px 14px;
  text-align: center;
  color: #334155;
  border-bottom: 1px solid #f0f1f3;
  word-wrap: break-word;
  overflow-wrap: break-word;
}

.cd-pinned-card-table td:first-child {
  text-align: left;
  font-weight: 500;
  color: #1e293b;
}

.cd-pinned-card-table tbody tr:nth-child(even) td {
  background: #f9fafb;
}

.cd-pinned-card-table tbody tr:hover td {
  background: #f1f5f9;
}

/* ================================================================ */
/* SECTION DIVIDERS — editable headers between pinned cards          */
/* ================================================================ */

.cd-section-divider, .cd-pinned-section-divider {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 0;
  margin: 8px 0;
  border-bottom: 2px solid var(--cd-brand);
}

.cd-section-divider-title, .cd-pinned-section-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--cd-brand);
  flex: 1;
  outline: none;
  min-width: 100px;
}

.cd-section-divider-title:focus, .cd-pinned-section-title:focus {
  border-bottom: 1px dashed var(--cd-border);
}

.cd-section-divider-actions, .cd-pinned-section-actions {
  display: flex;
  gap: 4px;
}

/* ================================================================ */
/* ACTION BAR — Save button strip                                    */
/* ================================================================ */

.cd-action-bar {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  padding: 8px 24px;
  background: var(--cd-card);
  border-bottom: 1px solid var(--cd-border);
}

.cd-save-btn {
  padding: 7px 18px;
  border: 1px solid var(--cd-brand);
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  color: var(--cd-brand);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.cd-save-btn:hover {
  background: var(--cd-brand);
  color: white;
}

.cd-saved-badge {
  display: none;
  font-size: 11px;
  color: var(--cd-text-faint);
  font-weight: 400;
}

/* ================================================================ */
/* PRINT STYLES                                                     */
/* ================================================================ */

@media print {
  .cd-section-nav { display: none !important; }
  .cd-content { padding: 16px !important; max-width: none !important; }
  .cd-body { background: white; font-size: 11px; }
  .cd-section { break-inside: avoid; page-break-inside: avoid; border: none; box-shadow: none; }
  .cd-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .cd-header-inner { max-width: none !important; }
  .cd-header-inner * { color: #1a2744 !important; }
  .cd-header-module-name { font-size: 16px !important; }
  .cd-header-title { font-size: 14px !important; margin-top: 4px !important; }
  .cd-header-logo-container { width: 32px !important; height: 32px !important; }
  .cd-header-logo-container img { width: 28px !important; height: 28px !important; }
  .cd-factor-tabs { display: none !important; }
  .cd-factor-panel { display: block !important; margin-bottom: 16px; }
  .cd-chart, .cd-forest-plot { max-width: 500px; }
  /* Hide interactive elements in print */
  .cd-insight-area { display: none !important; }
  .cd-pin-btn { display: none !important; }
  .cd-pin-popover { display: none !important; }
  .cd-or-chip-bar { display: none !important; }
  .cd-action-bar { display: none !important; }
  .cd-pinned-card-actions { display: none !important; }
}

@media (max-width: 768px) {
  .cd-section-nav { padding: 0 12px; }
  .cd-section-nav a { padding: 10px 14px; font-size: 12px; }
  .cd-content { padding: 16px; }
  .cd-interp-grid { grid-template-columns: 1fr; }
  .cd-header { padding: 16px; }
  .cd-header-module-name { font-size: 20px; }
  .cd-header-title { font-size: 18px; }
}

/* ---- Qualitative Slides ---- */
.cd-qual-slide-card {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 8px;
  margin-bottom: 12px; overflow: hidden; transition: box-shadow 200ms;
}
.cd-qual-slide-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
.cd-qual-slide-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 10px 16px; background: #f8fafc; border-bottom: 1px solid #e2e8f0;
}
.cd-qual-slide-title {
  font-size: 14px; font-weight: 600; color: #1e293b;
  outline: none; min-width: 120px;
}
.cd-qual-slide-title:focus { border-bottom: 2px solid BRAND_COLOUR; }
.cd-qual-slide-actions { display: flex; gap: 4px; }
.cd-qual-slide-actions .export-btn,
.cd-qual-btn {
  background: none; border: 1px solid #e2e8f0; border-radius: 4px;
  padding: 3px 7px; font-size: 13px; cursor: pointer; color: #475569;
}
.cd-qual-slide-actions .export-btn:hover,
.cd-qual-btn:hover { background: #f1f5f9; }
.cd-qual-md-editor {
  display: none; width: 100%; min-height: 120px; padding: 12px 16px;
  border: none; outline: none; font-family: monospace; font-size: 13px;
  line-height: 1.6; resize: vertical; box-sizing: border-box;
}
.cd-qual-slide-card.editing .cd-qual-md-editor { display: block; }
.cd-qual-slide-card.editing .cd-qual-md-rendered { display: none; }
.cd-qual-md-rendered {
  padding: 12px 16px; font-size: 13px; line-height: 1.7; color: #334155;
  min-height: 40px; cursor: text;
}
.cd-qual-md-rendered h2 { font-size: 15px; font-weight: 700; margin: 8px 0 4px; color: #1e293b; }
.cd-qual-md-rendered ul { margin: 4px 0; padding-left: 20px; }
.cd-qual-md-rendered blockquote {
  border-left: 3px solid BRAND_COLOUR; margin: 8px 0; padding: 4px 12px;
  color: #475569; font-style: italic;
}
.cd-qual-img-preview {
  padding: 8px 16px; position: relative;
}
.cd-qual-img-thumb {
  max-width: 100%; max-height: 300px; border-radius: 6px;
  border: 1px solid #e2e8f0;
}
.cd-qual-img-remove {
  position: absolute; top: 12px; right: 20px; background: rgba(0,0,0,0.5);
  color: #fff; border: none; border-radius: 50%; width: 24px; height: 24px;
  font-size: 14px; cursor: pointer; line-height: 24px; text-align: center;
}
.cd-qual-img-remove:hover { background: rgba(220,38,38,0.8); }

/* ================================================================ */
/* HELP OVERLAY MODALS                                              */
/* ================================================================ */

/* Help ? button in the nav bar */
.cd-help-btn-nav {
  width: 26px; height: 26px; border-radius: 50%; border: 1.5px solid #cbd5e1;
  background: transparent; color: #64748b; font-size: 13px; font-weight: 700;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  margin-left: auto; flex-shrink: 0; font-family: inherit;
}
.cd-help-btn-nav:hover { border-color: BRAND_COLOUR; color: BRAND_COLOUR; }

/* Help overlay — full-screen modal */
.cd-help-overlay {
  display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.6); z-index: 9999; cursor: pointer;
}
.cd-help-overlay.active { display: flex; align-items: center; justify-content: center; }
.cd-help-card {
  background: #fff; border-radius: 12px; padding: 28px 32px; max-width: 640px; width: 92%;
  max-height: 85vh; overflow-y: auto;
  box-shadow: 0 20px 60px rgba(0,0,0,0.3); cursor: default;
}
.cd-help-card h2 { font-size: 20px; margin-bottom: 4px; color: BRAND_COLOUR; }
.cd-help-card .cd-help-subtitle { font-size: 12px; color: #94a3b8; margin-bottom: 20px; }
.cd-help-card h3 {
  font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px;
  color: #94a3b8; margin: 18px 0 8px; padding-top: 14px; border-top: 1px solid #f1f5f9;
}
.cd-help-card h3:first-of-type { border-top: none; padding-top: 0; margin-top: 8px; }
.cd-help-card ul { list-style: none; padding: 0; margin: 0; }
.cd-help-card li {
  padding: 5px 0; font-size: 13px; color: #374151; line-height: 1.4;
}
.cd-help-card .cd-help-key {
  display: inline-block; background: #f1f5f9; border-radius: 4px;
  padding: 2px 8px; font-weight: 600; color: BRAND_COLOUR; margin-right: 8px;
  font-size: 11px; min-width: 100px; text-align: center;
}
.cd-help-card .cd-help-dismiss {
  margin-top: 18px; text-align: center; color: #94a3b8; font-size: 12px;
}
.cd-help-card .cd-help-tip {
  font-size: 12px; color: #64748b; background: #f8fafc; border-radius: 6px;
  padding: 10px 14px; margin-top: 14px; line-height: 1.5;
}
.cd-help-card .cd-help-tip strong { color: BRAND_COLOUR; }

@media print {
  .cd-help-btn-nav { display: none !important; }
  .cd-help-overlay { display: none !important; }
}
'
  css <- gsub("BRAND_COLOUR", brand_colour, css, fixed = TRUE)
  css <- gsub("ACCENT_COLOUR", accent_colour, css, fixed = TRUE)
  css <- paste0(shared_css, "\n\n/* === CATDRIVER MODULE STYLES === */\n", css)
  css
}


#' Build Horizontal Section Navigation Bar
#'
#' Creates a sticky horizontal nav bar below the header with section links.
#' Matches tabs/tracker .report-tabs pattern — underline indicator on active.
#' Zero side-space cost; works identically standalone and in Report Hub.
#'
#' @param brand_colour Brand colour hex string
#' @return htmltools tag
#' @keywords internal
