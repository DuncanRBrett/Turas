# ==============================================================================
# KEYDRIVER HTML REPORT - PAGE STYLING
# ==============================================================================
# CSS stylesheet generation for the key driver HTML report.
# Uses the shared Turas Design System for base styles and layers
# keydriver-specific styles on top.
#
# Extracted from 03_page_builder.R for maintainability.
# ==============================================================================

# ==============================================================================
# CSS BUILDER
# ==============================================================================

#' Build Keydriver CSS
#'
#' Generates the complete stylesheet aligned with the shared Turas design system.
#' Uses CSS variables for brand consistency across modules.
#' All classes use kd- prefix for Report Hub namespace isolation.
#'
#' @param config Configuration list with brand_colour, accent_colour
#' @return Character string of CSS
#' @keywords internal
build_kd_css <- function(config) {

  brand_colour  <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"

  # Shared base CSS (Inter font, tokens, typography, common components)
  shared_css <- tryCatch(
    turas_base_css(brand_colour, accent_colour, prefix = "kd"),
    error = function(e) ""
  )

  css <- '
/* ==== KEYDRIVER REPORT CSS ==== */
/* kd- namespace for Report Hub safety */
/* Aligned with shared Turas design system (tabs/tracker/catdriver) */

:root {
  /* Brand colours */
  --kd-brand: BRAND_COLOUR;
  --kd-accent: ACCENT_COLOUR;

  /* Module variables */
  --kd-text: #1e293b;
  --kd-text-muted: #64748b;
  --kd-text-faint: #94a3b8;
  --kd-bg: #f8f7f5;
  --kd-bg-muted: #f8f9fa;
  --kd-bg-subtle: #f0f4f8;
  --kd-card: #ffffff;
  --kd-border: #e2e8f0;
  --kd-border-subtle: #f0f0f0;
  --kd-success: #059669;
  --kd-warning: #F59E0B;
  --kd-danger: #c0392b;
}

.kd-body, .kd-body * { box-sizing: border-box; margin: 0; padding: 0; }

.kd-body {
  font-family: inherit;
  background: var(--kd-bg);
  color: var(--kd-text);
  line-height: 1.5;
  font-size: 13px;
}

/* Skip-to-content link (accessibility) */
.kd-skip-link {
  position: absolute;
  top: -100px;
  left: 8px;
  z-index: 9999;
  background: var(--kd-brand);
  color: #fff;
  padding: 8px 16px;
  border-radius: 0 0 6px 6px;
  font-size: 13px;
  font-weight: 600;
  text-decoration: none;
  transition: top 0.2s;
}
.kd-skip-link:focus {
  top: 0;
}

/* ================================================================ */
/* HORIZONTAL SECTION NAV BAR                                        */
/* Sticky below header, full-width, underline active indicator       */
/* ================================================================ */

.kd-section-nav {
  position: sticky;
  top: 47px;
  z-index: 90;
  background: var(--kd-card);
  border-bottom: 2px solid var(--kd-border);
  display: flex;
  align-items: center;
  gap: 0;
  padding: 0 24px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.kd-section-nav a {
  display: inline-flex;
  align-items: center;
  padding: 12px 20px;
  color: var(--kd-text-muted);
  text-decoration: none;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  border-bottom: 3px solid transparent;
  cursor: pointer;
  transition: all 0.15s ease;
}

.kd-section-nav a:hover {
  color: var(--kd-brand);
  background: #f8fafc;
}

.kd-section-nav a.active {
  color: var(--kd-brand);
  border-bottom-color: var(--kd-brand);
}

/* Page-switching: sections hidden by default, shown when active */
.kd-content .kd-section {
  display: none;
}

.kd-content .kd-section.kd-page-active {
  display: block;
}

/* Pinned section always visible within its tab panel */
#kd-tab-pinned .kd-section {
  display: block;
}

/* ================================================================ */
/* MAIN CONTENT                                                      */
/* ================================================================ */

.kd-main {
  min-width: 0;
}

.kd-content {
  max-width: 1100px;
  margin: 0 auto;
  padding: 24px 32px;
}

/* ================================================================ */
/* HEADER                                                            */
/* ================================================================ */

.kd-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
  padding: 24px 32px;
  border-bottom: 3px solid var(--kd-brand);
}

.kd-header-inner {
  max-width: 1100px;
  margin: 0 auto;
  font-family: inherit;
}

.kd-header-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.kd-header-branding {
  display: flex;
  align-items: center;
  gap: 16px;
}

.kd-header-logo-container {
  width: 72px;
  height: 72px;
  border-radius: 12px;
  background: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.kd-header-logo-container img {
  height: 56px;
  width: 56px;
  object-fit: contain;
}

.kd-header-module-name {
  color: #ffffff;
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: -0.3px;
}

.kd-header-module-sub {
  color: rgba(255,255,255,0.50);
  font-size: 12px;
  font-weight: 400;
  margin-top: 2px;
}

.kd-header-title {
  color: #ffffff;
  font-size: 22px;
  font-weight: 700;
  letter-spacing: -0.3px;
  margin-top: 16px;
  line-height: 1.2;
}

.kd-header-prepared {
  color: rgba(255,255,255,0.65);
  font-size: 13px;
  font-weight: 400;
  margin-top: 4px;
  line-height: 1.3;
}

.kd-header-badges {
  display: inline-flex;
  align-items: center;
  margin-top: 12px;
  border: 1px solid rgba(255,255,255,0.15);
  border-radius: 6px;
  background: rgba(255,255,255,0.05);
}

.kd-header-badge {
  display: inline-flex;
  align-items: center;
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(255,255,255,0.85);
}

.kd-header-badge-val {
  color: rgba(255,255,255,1);
  font-weight: 700;
}

.kd-header-badge-sep {
  width: 1px;
  height: 16px;
  background: rgba(255,255,255,0.20);
  flex-shrink: 0;
}

/* ================================================================ */
/* SECTIONS (card style)                                             */
/* ================================================================ */

.kd-section {
  background: var(--kd-card);
  border: 1px solid var(--kd-border);
  border-radius: 8px;
  padding: 24px 28px;
  margin-bottom: 20px;
}

.kd-section-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--kd-brand);
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--kd-brand);
}

.kd-section-intro {
  color: var(--kd-text-muted);
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.5;
}

/* ================================================================ */
/* SECTION TITLE ROW — title + pin button in flex row                */
/* ================================================================ */

.kd-section-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
  padding-bottom: 8px;
  border-bottom: 2px solid var(--kd-brand);
}

.kd-section-title-row .kd-section-title {
  margin-bottom: 0;
  padding-bottom: 0;
  border-bottom: none;
}

/* ================================================================ */
/* PIN BUTTONS                                                       */
/* ================================================================ */

.kd-pin-btn {
  background: none;
  border: 1px solid var(--kd-border);
  border-radius: 6px;
  padding: 4px 10px;
  font-size: 14px;
  cursor: pointer;
  color: var(--kd-text-faint);
  transition: all 0.15s;
  flex-shrink: 0;
}

.kd-pin-btn:hover {
  border-color: var(--kd-brand);
  color: var(--kd-brand);
  background: rgba(50,51,103,0.03);
}

.kd-pin-btn.kd-pin-btn-active {
  background: var(--kd-brand);
  color: white;
  border-color: var(--kd-brand);
}

/* ================================================================ */
/* CHART/TABLE WRAPPERS                                              */
/* ================================================================ */

.kd-chart-wrapper,
.kd-table-wrapper {
  position: relative;
  margin-bottom: 8px;
}

/* Pin mode popover */
.kd-pin-popover {
  position: absolute;
  top: 100%;
  right: 0;
  z-index: 1000;
  background: white;
  border: 1px solid var(--kd-border);
  border-radius: 6px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.12);
  padding: 4px 0;
  min-width: 140px;
  margin-top: 4px;
}

.kd-pin-popover-item {
  display: block;
  width: 100%;
  padding: 8px 14px;
  border: none;
  background: none;
  font-size: 12px;
  font-weight: 500;
  color: var(--kd-text-primary);
  cursor: pointer;
  text-align: left;
  font-family: inherit;
  transition: background 0.1s;
}

.kd-pin-popover-item:hover:not(:disabled) {
  background: #f1f5f9;
  color: var(--kd-brand);
}

/* Drag-and-drop states */
.kd-pin-dragging {
  opacity: 0.4;
}

.kd-pin-drop-target,
.turas-pin-drop-target {
  outline: 2px dashed var(--kd-brand);
  outline-offset: -2px;
}

.kd-pin-dragging,
.turas-pin-dragging {
  opacity: 0.4;
}

.kd-pinned-card[draggable="true"],
.kd-section-divider[draggable="true"],
.kd-pinned-card[data-pin-drag-idx] {
  cursor: grab;
}

.kd-pinned-card[draggable="true"]:active,
.kd-section-divider[draggable="true"]:active,
.kd-pinned-card[data-pin-drag-idx]:active {
  cursor: grabbing;
}

/* ================================================================ */
/* TABLE EXPORT BAR                                                  */
/* ================================================================ */

.kd-table-export-bar {
  position: absolute;
  top: 4px;
  right: 4px;
  z-index: 10;
  display: flex;
  gap: 4px;
  opacity: 0;
  transition: opacity 0.15s;
}

.kd-table-wrapper:hover .kd-table-export-bar {
  opacity: 1;
}

.kd-table-export-btn {
  background: rgba(255,255,255,0.92);
  border: 1px solid var(--kd-border);
  border-radius: 4px;
  padding: 2px 8px;
  font-size: 10px;
  font-weight: 600;
  font-family: inherit;
  color: var(--kd-text-faint);
  cursor: pointer;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  transition: all 0.15s;
}

.kd-table-export-btn:hover {
  border-color: var(--kd-brand);
  color: var(--kd-brand);
  background: rgba(255,255,255,0.98);
}

/* ================================================================ */
/* TABLES                                                            */
/* ================================================================ */

.kd-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

th.kd-th {
  background: var(--kd-bg-muted, #f8f9fa);
  color: var(--kd-text-muted);
  font-weight: 600;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  padding: 12px 16px;
  text-align: left;
  border-bottom: 2px solid var(--kd-border);
  vertical-align: bottom;
  white-space: normal;
}

.kd-th-num, .kd-th-sig, .kd-th-effect, .kd-th-status { text-align: center; }
.kd-th-bar { text-align: left; min-width: 150px; }
.kd-th-rank { text-align: center; width: 50px; }

td.kd-td {
  padding: 10px 16px;
  border-bottom: 1px solid var(--kd-border-subtle, #f0f0f0);
  vertical-align: middle;
  color: var(--kd-text);
  font-variant-numeric: tabular-nums;
  transition: background-color 0.15s;
}

.kd-td-num { text-align: center; font-variant-numeric: tabular-nums; }
.kd-td-rank { text-align: center; font-weight: 600; color: var(--kd-brand); }
.kd-td-sig { text-align: center; }
.kd-td-effect { text-align: center; }
.kd-td-status { text-align: center; }
.kd-td-interp { font-size: 12px; color: var(--kd-text-muted); }
.kd-td-label { font-weight: 500; }

/* Sortable column headers */
.kd-sortable {
  cursor: pointer;
  user-select: none;
  position: relative;
}
.kd-sortable:hover { color: var(--kd-brand); }
.kd-sortable::after {
  content: "\\2195";
  margin-left: 4px;
  opacity: 0.35;
  font-size: 10px;
}
.kd-sort-asc::after { content: "\\25B2"; opacity: 0.8; }
.kd-sort-desc::after { content: "\\25BC"; opacity: 0.8; }

.kd-tr:nth-child(even) { background: var(--kd-bg-muted, #f9fafb); }
.kd-tr:hover { background: var(--kd-bg-subtle, #f8fafc); }

/* ================================================================ */
/* IMPORTANCE BARS                                                   */
/* ================================================================ */

.kd-bar-container {
  height: 16px;
  background: var(--kd-bg-subtle, #f1f5f9);
  border-radius: 8px;
  overflow: hidden;
}

.kd-bar-fill {
  height: 100%;
  border-radius: 8px;
  transition: width 0.3s ease;
}

/* ================================================================ */
/* SIGNIFICANCE BADGES                                               */
/* ================================================================ */

.kd-sig-strong {
  color: var(--kd-success);
  font-weight: 700;
  font-size: 9px;
  font-family: ui-monospace, "Cascadia Code", Consolas, monospace;
  background: rgba(5,150,105,0.08);
  border-radius: 3px;
  padding: 0 4px;
  display: inline-block;
}

.kd-sig-moderate {
  color: #92400E;
  font-weight: 600;
  font-size: 9px;
  font-family: ui-monospace, "Cascadia Code", Consolas, monospace;
  background: rgba(146,64,14,0.08);
  border-radius: 3px;
  padding: 0 4px;
  display: inline-block;
}

.kd-sig-none {
  color: var(--kd-text-faint);
  font-size: 11px;
}

/* ================================================================ */
/* EFFECT COLOUR CLASSES                                             */
/* ================================================================ */

.kd-effect-pos { background: #D1FAE5; color: #065F46; border-radius: 4px; padding: 1px 6px; }
.kd-effect-neg { background: #FEE2E2; color: #991B1B; border-radius: 4px; padding: 1px 6px; }
.kd-effect-mod { background: #FEF3C7; color: #92400E; border-radius: 4px; padding: 1px 6px; }
.kd-effect-none { }

/* ================================================================ */
/* DIAGNOSTIC BADGES                                                 */
/* ================================================================ */

.kd-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
}

.kd-badge-pass { background: #D1FAE5; color: #065F46; }
.kd-badge-warn { background: #FEF3C7; color: #92400E; }
.kd-badge-fail { background: #FEE2E2; color: #991B1B; }

/* ================================================================ */
/* STATUS BADGES                                                     */
/* ================================================================ */

.kd-status-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.kd-status-pass { background: #D1FAE5; color: #065F46; }
.kd-status-partial { background: #FEF3C7; color: #92400E; }
.kd-status-refused { background: #FEE2E2; color: #991B1B; }

/* ================================================================ */
/* EXECUTIVE SUMMARY — top-driver cards with left border             */
/* Educational callouts now use shared .t-callout from base_css      */
/* ================================================================ */

.kd-callout {
  background: #f8fafa;
  border-left: 3px solid var(--kd-brand);
  padding: 12px 16px;
  border-radius: 0 6px 6px 0;
  margin-bottom: 10px;
}

.kd-callout-title {
  font-weight: 600;
  font-size: 14px;
  margin-bottom: 4px;
  color: var(--kd-text);
}

.kd-callout-text {
  font-size: 13px;
  color: var(--kd-text-muted);
}

.kd-model-confidence {
  padding: 12px 16px;
  border-radius: 6px;
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.5;
}

.kd-confidence-excellent { background: #D1FAE5; border-left: 4px solid var(--kd-success); }
.kd-confidence-good { background: #DBEAFE; border-left: 4px solid #2563EB; }
.kd-confidence-moderate { background: #FEF3C7; border-left: 4px solid var(--kd-warning); }
.kd-confidence-limited { background: #FEE2E2; border-left: 4px solid var(--kd-danger); }

/* ================================================================ */
/* FIT STATISTIC CARDS                                               */
/* ================================================================ */

.kd-fit-cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
  margin-top: 8px;
}

.kd-fit-card {
  background: var(--kd-bg-muted);
  border: 1px solid var(--kd-border);
  border-radius: 6px;
  padding: 12px 16px;
  border-left: 3px solid var(--kd-brand);
}

.kd-fit-card-value {
  font-size: 18px;
  font-weight: 700;
  color: var(--kd-text);
  font-variant-numeric: tabular-nums;
}

.kd-fit-card-label {
  font-size: 12px;
  font-weight: 600;
  color: var(--kd-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.3px;
  margin-top: 2px;
}

.kd-fit-card-quality {
  font-size: 11px;
  font-weight: 600;
  color: var(--kd-brand);
  margin-top: 4px;
}

.kd-fit-card-note {
  font-size: 11px;
  color: var(--kd-text-faint);
  line-height: 1.4;
  margin-top: 6px;
}

/* ================================================================ */
/* CHARTS                                                            */
/* ================================================================ */

.kd-chart, .kd-importance-chart {
  width: 100%;
  max-width: 700px;
  height: auto;
  margin: 16px 0;
  display: block;
}

/* ================================================================ */
/* FILTER BAR — chip pills                                           */
/* ================================================================ */

.kd-or-chip-bar {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 14px;
}

.kd-or-chip {
  padding: 5px 12px;
  border: 1px solid var(--kd-border);
  border-radius: 20px;
  font-size: 12px;
  font-weight: 500;
  color: var(--kd-text-muted);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.kd-or-chip:hover {
  border-color: var(--kd-brand);
  color: var(--kd-brand);
}

.kd-or-chip.active {
  background: var(--kd-brand);
  color: white;
  border-color: var(--kd-brand);
}

/* ================================================================ */
/* KEY INSIGHTS                                                      */
/* ================================================================ */

.kd-key-insights-heading {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--kd-text);
}

.kd-key-insight-item {
  color: var(--kd-text);
  font-size: 13px;
  margin-bottom: 6px;
  line-height: 1.5;
}

.kd-finding-box {
  margin-bottom: 16px;
  padding: 14px 16px;
  background: var(--kd-bg-muted);
  border-radius: 6px;
}

.kd-finding-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-bottom: 6px;
}

.kd-finding-icon {
  font-size: 16px;
  font-weight: 700;
  flex-shrink: 0;
}

.kd-finding-text {
  font-size: 13px;
  color: var(--kd-text);
  line-height: 1.4;
}

.kd-top-drivers-label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 10px;
  color: var(--kd-text);
}

.kd-panel-heading-label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--kd-text);
}

/* ================================================================ */
/* INSIGHT EDITORS                                                   */
/* ================================================================ */

.kd-insight-area {
  margin-bottom: 12px;
}

.kd-insight-toggle {
  background: none;
  border: 1px dashed var(--kd-border);
  border-radius: 6px;
  padding: 6px 14px;
  font-size: 12px;
  font-weight: 500;
  color: var(--kd-text-muted);
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s;
}

.kd-insight-toggle:hover {
  border-color: var(--kd-brand);
  color: var(--kd-brand);
  background: rgba(50,51,103,0.03);
}

.kd-insight-container {
  display: none;
  margin-top: 8px;
  position: relative;
}

.kd-insight-editor {
  width: 100%;
  min-height: 60px;
  padding: 10px 14px;
  border: 1px solid var(--kd-border);
  border-radius: 6px;
  font-size: 13px;
  font-family: inherit;
  line-height: 1.5;
  color: var(--kd-text);
  outline: none;
  transition: border-color 0.15s;
}

.kd-insight-editor:focus {
  border-color: var(--kd-brand);
  box-shadow: 0 0 0 2px rgba(50,51,103,0.08);
}

.kd-insight-editor:empty::before {
  content: attr(data-placeholder);
  color: var(--kd-text-faint);
  pointer-events: none;
}

.kd-insight-dismiss {
  position: absolute;
  top: 4px;
  right: 4px;
  background: none;
  border: none;
  font-size: 14px;
  color: var(--kd-text-faint);
  cursor: pointer;
  padding: 2px 6px;
  border-radius: 4px;
  transition: all 0.15s;
}

.kd-insight-dismiss:hover {
  color: var(--kd-danger);
  background: rgba(192,57,43,0.06);
}

/* ================================================================ */
/* INTERPRETATION GUIDE — DO/DON T grid                              */
/* ================================================================ */

.kd-interp-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.kd-interp-list {
  font-size: 13px;
  color: var(--kd-text-muted);
  padding-left: 16px;
}

.kd-interp-list li { margin-bottom: 6px; line-height: 1.4; }

.kd-interp-note {
  margin-top: 16px;
  padding: 12px 16px;
  background: #f8fafa;
  border-radius: 6px;
  border-left: 3px solid var(--kd-brand);
  font-size: 12px;
  color: var(--kd-text-muted);
  line-height: 1.5;
}

/* ================================================================ */
/* REPORT-LEVEL TAB BAR (Analysis | Pinned Views)                    */
/* ================================================================ */

.kd-report-tabs {
  display: flex;
  gap: 0;
  background: white;
  border-bottom: 2px solid #e2e8f0;
  padding: 0 32px;
  position: sticky;
  top: 0;
  z-index: 100;
}

.kd-report-tab {
  padding: 12px 24px;
  border: none;
  background: none;
  font-size: 14px;
  font-weight: 600;
  color: var(--kd-text-muted);
  cursor: pointer;
  font-family: inherit;
  border-bottom: 3px solid transparent;
  margin-bottom: -2px;
  transition: color 0.15s, border-color 0.15s;
}

.kd-report-tab:hover {
  color: var(--kd-brand);
}

.kd-report-tab.active {
  color: var(--kd-brand);
  border-bottom-color: var(--kd-brand);
}

.kd-pin-count-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  margin-left: 6px;
  background: var(--kd-brand);
  color: #fff;
  font-size: 10px;
  font-weight: 700;
  border-radius: 9px;
}

.kd-tab-panel {
  display: none;
}

.kd-tab-panel.active {
  display: block;
}

/* ================================================================ */
/* PINNED VIEWS PANEL                                                */
/* ================================================================ */

.kd-pinned-panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}

.kd-pinned-panel-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--kd-brand);
}

.kd-pinned-panel-actions {
  display: flex;
  gap: 8px;
}

.kd-pinned-panel-btn {
  padding: 6px 14px;
  border: 1px solid var(--kd-border);
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  color: var(--kd-text-muted);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.kd-pinned-panel-btn:hover {
  border-color: var(--kd-brand);
  color: var(--kd-brand);
}

.kd-pinned-empty {
  text-align: center;
  padding: 48px 24px;
  color: var(--kd-text-faint);
  font-size: 14px;
}

.kd-pinned-empty-icon {
  font-size: 32px;
  margin-bottom: 8px;
  opacity: 0.4;
}

/* ================================================================ */
/* QUALITATIVE SLIDES                                                */
/* ================================================================ */

.kd-qual-slides-container { margin-bottom: 16px; }

.kd-qual-slide-card {
  background: var(--kd-card);
  border: 1px solid var(--kd-border);
  border-radius: 8px;
  padding: 12px 16px;
  margin-bottom: 10px;
}

.kd-qual-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.kd-qual-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--kd-text);
  outline: none;
  padding: 2px 4px;
  border-radius: 4px;
  min-width: 100px;
}

.kd-qual-title:focus {
  background: #f1f5f9;
}

.kd-qual-actions { display: flex; gap: 4px; }

.kd-qual-btn {
  padding: 3px 8px;
  border: 1px solid var(--kd-border);
  border-radius: 4px;
  font-size: 12px;
  cursor: pointer;
  background: white;
  color: var(--kd-text-muted);
  transition: all 0.15s;
}

.kd-qual-btn:hover { border-color: var(--kd-brand); color: var(--kd-brand); }

.kd-qual-delete:hover { border-color: #ef4444; color: #ef4444; }

.kd-qual-img-preview {
  position: relative;
  margin-bottom: 8px;
  max-width: 400px;
}

.kd-qual-img-thumb {
  max-width: 100%;
  border-radius: 6px;
  border: 1px solid var(--kd-border);
}

.kd-qual-img-remove {
  position: absolute;
  top: 4px;
  right: 4px;
  background: rgba(0,0,0,0.6);
  color: white;
  border: none;
  border-radius: 50%;
  width: 22px;
  height: 22px;
  font-size: 14px;
  cursor: pointer;
  line-height: 1;
}

.kd-qual-md-editor {
  width: 100%;
  padding: 8px 10px;
  border: 1px solid var(--kd-border);
  border-radius: 6px;
  font-size: 13px;
  font-family: inherit;
  resize: vertical;
  color: var(--kd-text);
  line-height: 1.5;
}

.kd-qual-md-editor:focus {
  outline: none;
  border-color: var(--kd-brand);
}

.kd-pinned-card {
  background: var(--kd-card);
  border: 1px solid var(--kd-border);
  border-radius: 8px;
  padding: 10px 14px;
  margin-bottom: 12px;
  transition: box-shadow 0.15s;
}

.kd-pinned-card:hover {
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}

.kd-pinned-card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 6px;
}

.kd-pinned-card-title {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.kd-pinned-card-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--kd-brand);
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.kd-pinned-card-section {
  font-size: 15px;
  font-weight: 600;
  color: var(--kd-text);
}

.kd-pinned-card-actions {
  display: flex;
  gap: 4px;
  flex-shrink: 0;
}

.kd-pinned-action-btn {
  background: none;
  border: 1px solid transparent;
  border-radius: 4px;
  padding: 3px 7px;
  font-size: 12px;
  cursor: pointer;
  color: var(--kd-text-faint);
  transition: all 0.15s;
}

.kd-pinned-action-btn:hover {
  border-color: var(--kd-border);
  color: var(--kd-text-muted);
  background: #f8f9fa;
}

.kd-pinned-remove-btn:hover {
  color: var(--kd-danger);
  background: rgba(192,57,43,0.06);
}

.kd-pinned-export-btn:hover {
  color: var(--kd-brand);
  background: rgba(50,51,103,0.04);
}

.kd-pinned-card-insight {
  padding: 8px 12px;
  border-left: 3px solid var(--kd-accent);
  background: #faf9f7;
  border-radius: 0 6px 6px 0;
  font-size: 13px;
  color: #475569;
  line-height: 1.4;
  margin-bottom: 6px;
}

.kd-pinned-card-chart {
  margin-top: 6px;
  overflow: visible;
}

.kd-pinned-card-chart svg {
  width: 100%;
  height: auto;
  display: block;
}

.kd-pinned-card-table {
  margin-top: 6px;
  overflow-x: auto;
  overflow-y: visible;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
}

.kd-pinned-card-table table {
  width: 100%;
  font-size: 12px;
  border-collapse: collapse;
  font-variant-numeric: tabular-nums;
}

.kd-pinned-card-table th {
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

.kd-pinned-card-table th:first-child {
  text-align: left;
}

.kd-pinned-card-table td {
  padding: 8px 14px;
  text-align: center;
  color: #334155;
  border-bottom: 1px solid #f0f1f3;
  word-wrap: break-word;
  overflow-wrap: break-word;
}

.kd-pinned-card-table td:first-child {
  text-align: left;
  font-weight: 500;
  color: #1e293b;
}

.kd-pinned-card-table tbody tr:nth-child(even) td {
  background: #f9fafb;
}

.kd-pinned-card-table tbody tr:hover td {
  background: #f1f5f9;
}

/* ================================================================ */
/* SEGMENT COMPARISON CONTROLS                                       */
/* ================================================================ */

.kd-seg-controls {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 12px;
  margin-bottom: 16px;
  padding: 10px 14px;
  background: #f8fafc;
  border: 1px solid var(--kd-border);
  border-radius: 8px;
}

.kd-seg-chips {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
}

.kd-seg-sort {
  display: flex;
  align-items: center;
}

.kd-seg-sort-select {
  padding: 4px 8px;
  border: 1px solid var(--kd-border);
  border-radius: 5px;
  font-size: 12px;
  font-family: inherit;
  color: var(--kd-text);
  background: white;
  cursor: pointer;
}

.kd-seg-sort-select:focus {
  outline: none;
  border-color: var(--kd-brand);
}

/* ================================================================ */
/* SECTION DIVIDERS                                                  */
/* ================================================================ */

.kd-section-divider {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 0;
  margin: 8px 0;
  border-bottom: 2px solid var(--kd-brand);
}

.kd-section-divider-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--kd-brand);
  flex: 1;
  outline: none;
  min-width: 100px;
}

.kd-section-divider-title:focus {
  border-bottom: 1px dashed var(--kd-border);
}

.kd-section-divider-actions {
  display: flex;
  gap: 4px;
}

/* ================================================================ */
/* ACTION BAR — Save button strip                                    */
/* ================================================================ */

.kd-action-bar {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  padding: 8px 24px;
  background: var(--kd-card);
  border-bottom: 1px solid var(--kd-border);
}

.kd-save-btn {
  padding: 7px 18px;
  border: 1px solid var(--kd-brand);
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  color: var(--kd-brand);
  cursor: pointer;
  background: white;
  font-family: inherit;
  transition: all 0.15s;
}

.kd-save-btn:hover {
  background: var(--kd-brand);
  color: white;
}

.kd-saved-badge {
  display: none;
  font-size: 11px;
  color: var(--kd-text-faint);
  font-weight: 400;
}

/* ================================================================ */
/* FOOTER                                                            */
/* ================================================================ */

.kd-footer {
  text-align: center;
  padding: 24px;
  color: var(--kd-text-faint);
  font-size: 11px;
  border-top: 1px solid var(--kd-border);
  margin-top: 32px;
}

/* ================================================================ */
/* CORRELATION HEATMAP                                               */
/* ================================================================ */

.kd-corr-pos { background: #D1FAE5; }
.kd-corr-neg { background: #FEE2E2; }
.kd-corr-neutral { background: #f8f9fa; }

/* ================================================================ */
/* QUADRANT SECTION                                                  */
/* ================================================================ */

.kd-quadrant-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin: 12px 0;
  font-size: 12px;
  color: var(--kd-text-muted);
}

.kd-quadrant-legend-item {
  display: flex;
  align-items: center;
  gap: 4px;
}

.kd-quadrant-swatch {
  width: 14px;
  height: 14px;
  border-radius: 3px;
  border: 1px solid rgba(0,0,0,0.08);
}

/* ================================================================ */
/* DIAGNOSTICS TABLE                                                 */
/* ================================================================ */

.kd-diagnostics-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.kd-diagnostics-table td {
  padding: 8px 12px;
  border-bottom: 1px solid #f0f0f0;
}

/* ================================================================ */
/* PRINT STYLES                                                      */
/* ================================================================ */

@media print {
  .kd-section-nav { display: none !important; }
  .kd-report-tabs { display: none !important; }
  .kd-tab-panel { display: block !important; }
  .kd-content { padding: 16px !important; max-width: none !important; }
  .kd-body { background: white; font-size: 11px; }
  .kd-section { break-inside: avoid; page-break-inside: avoid; border: none; box-shadow: none; }
  .kd-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .kd-header-inner { max-width: none !important; }
  .kd-header-inner * { color: #1a2744 !important; }
  .kd-header-module-name { font-size: 16px !important; }
  .kd-header-title { font-size: 14px !important; margin-top: 4px !important; }
  .kd-header-logo-container { width: 32px !important; height: 32px !important; }
  .kd-header-logo-container img { width: 28px !important; height: 28px !important; }
  .kd-chart, .kd-importance-chart { max-width: 500px; }
  .kd-insight-area { display: none !important; }
  .kd-pin-btn { display: none !important; }
  .kd-pin-popover { display: none !important; }
  .kd-or-chip-bar { display: none !important; }
  .kd-action-bar { display: none !important; }
  .kd-pinned-card-actions { display: none !important; }
}

@media (max-width: 768px) {
  .kd-section-nav { padding: 0 12px; }
  .kd-section-nav a { padding: 10px 14px; font-size: 12px; }
  .kd-content { padding: 16px; }
  .kd-interp-grid { grid-template-columns: 1fr; }
  .kd-header { padding: 16px; }
  .kd-header-module-name { font-size: 20px; }
  .kd-header-title { font-size: 18px; }
}
'
  css <- gsub("BRAND_COLOUR", brand_colour, css, fixed = TRUE)
  css <- gsub("ACCENT_COLOUR", accent_colour, css, fixed = TRUE)
  css <- paste0(shared_css, "\n\n/* === KEYDRIVER MODULE STYLES === */\n", css)
  css
}


