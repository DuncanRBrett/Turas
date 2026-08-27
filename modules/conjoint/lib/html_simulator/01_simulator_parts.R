# ==============================================================================
# CONJOINT MARKET SIMULATOR - STANDALONE PAGE
# ==============================================================================
#
# The simulator is a tool, not report content. It was folded into the combined
# HTML report in March 2026; when that report is retired the simulator has to
# survive on its own, which is what this file is.
#
# Everything here was lifted from the retired report layer, unchanged in
# behaviour: the CSS builder, the simulator panel markup, the data transformer
# and the JSON island. The engine, UI and chart JS are the same three files the
# report shipped. What is gone is the report around them.
#
# Self-contained: one HTML file, no external requests.
# ==============================================================================

CONJOINT_SIMULATOR_VERSION <- "4.0.0"

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}


#' Escape Text For HTML
#'
#' @keywords internal
.html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}

# ==============================================================================
# STYLES
# ==============================================================================
#
# This is the retired report's stylesheet, brought across whole. It carries
# rules for elements the standalone simulator never renders — the report's
# header nav, its tables, its pin buttons. Trimming it would mean deciding, for
# every rule, whether the simulator's runtime-generated markup needs it, and
# getting that wrong shows up as a broken layout in a client's hands. The whole
# file is about 90 KB; the risk is not worth the kilobytes.
# ==============================================================================


#' @keywords internal
build_conjoint_css <- function(brand, accent) {

  # Shared base CSS (Inter font, tokens, typography, common components)
  shared_css <- tryCatch(
    turas_base_css(brand, accent, prefix = "cj"),
    error = function(e) ""
  )
  css_root <- sprintf(':root { --cj-brand: %s; --cj-accent: %s; --cj-note-border: %s; --cj-note-text: #92700c; --cj-note-bg: #fffbeb; --cj-note-ring: #fbbf24; }', brand, accent, accent)
  css <- paste0(css_root, '

/* === HEADER === */
.cj-header {
  background: linear-gradient(135deg, #1a2744, #2a3f5f);
  color: white;
  padding: 24px 40px 20px;
  border-bottom: 3px solid var(--cj-brand);
}
.cj-header-inner { display:flex; flex-direction:column; max-width:1400px; margin:0 auto; }
.cj-header-top { display:flex; align-items:center; justify-content:space-between; }
.cj-header-branding { display:flex; align-items:center; gap:16px; }
.cj-header-logo { height:56px; width:56px; object-fit:contain; border-radius:8px; }
.cj-header-titles h1 { font-size:24px; font-weight:700; letter-spacing:-0.3px; line-height:1.2; }
.cj-header-subtitle { color:rgba(255,255,255,0.5); font-size:12px; margin-top:2px; }
.cj-study-name { color:#ffffff; font-size:20px; font-weight:700; letter-spacing:-0.3px; margin-top:14px; }
.cj-prepared-by { color:rgba(255,255,255,0.65); font-size:13px; margin-top:4px; }
.cj-prepared-by strong { font-weight:600; }

/* Badge bar */
.cj-badge-bar {
  display:inline-flex; align-items:center; margin-top:12px;
  border:1px solid rgba(255,255,255,0.15); border-radius:6px;
  background:rgba(255,255,255,0.05);
}
.cj-badge-item { display:inline-flex; align-items:center; padding:4px 12px; font-size:12px; font-weight:600; color:rgba(255,255,255,0.85); }
.cj-badge-item strong { color:#fff; font-weight:700; }
.cj-badge-sep { width:1px; height:16px; background:rgba(255,255,255,0.20); flex-shrink:0; }

/* Help button */
.cj-help-btn {
  width:28px; height:28px; border-radius:50%; border:1.5px solid rgba(255,255,255,0.5);
  background:transparent; color:rgba(255,255,255,0.8); font-size:14px; font-weight:700;
  cursor:pointer; display:flex; align-items:center; justify-content:center;
  transition:all 0.15s ease;
}
.cj-help-btn:hover { background:rgba(255,255,255,0.1); }

/* === TAB NAVIGATION === */
.cj-report-tabs {
  display:flex; gap:0; background:white; border-bottom:2px solid #e2e8f0;
  padding:0 40px; position:sticky; top:0; z-index:100;
}
.cj-report-tab {
  padding:12px 20px; font-size:13px; font-weight:500; color:#64748b;
  cursor:pointer; border:none; border-bottom:3px solid transparent;
  background:none; transition:all 0.15s ease;
}
.cj-report-tab:hover { color:var(--cj-brand); }
.cj-report-tab.active { color:var(--cj-brand); border-bottom-color:var(--cj-brand); }
.cj-nav-utils { margin-left:auto; display:flex; align-items:center; gap:6px; padding-right:4px; }
.cj-nav-util-btn { padding:6px 14px; font-size:12px; font-weight:500; color:#64748b; background:#f8fafc; border:1px solid #e2e8f0; border-radius:6px; cursor:pointer; font-family:inherit; transition:all 0.15s ease; }
.cj-nav-util-btn:hover { color:var(--cj-brand); border-color:var(--cj-brand); background:#fff; }

/* === MAIN CONTENT === */
.cj-panels-wrap { max-width:1400px; margin:0 auto; padding:24px 40px 60px; }
.cj-panel { display:none; }
.cj-panel.active { display:block; }

/* === CARDS === */
.cj-card {
  background:white; border:1px solid #e2e8f0; border-radius:8px; padding:24px; margin-bottom:20px;
  box-shadow:0 1px 3px rgba(0,0,0,0.06); transition:all 0.15s ease;
}
.cj-card:hover { box-shadow:0 2px 8px rgba(0,0,0,0.08); }
.cj-card h2 { font-size:16px; font-weight:600; color:#1e293b; margin-bottom:16px; }
.cj-card h3 { font-size:14px; font-weight:600; color:#1e293b; margin-bottom:12px; }

/* === KPI ROW === */
.cj-kpi-row { display:flex; gap:16px; margin-bottom:20px; flex-wrap:wrap; }
.cj-kpi {
  background:white; border:1px solid #e2e8f0; border-radius:8px; padding:16px 20px; min-width:140px;
  box-shadow:0 1px 3px rgba(0,0,0,0.06); text-align:center; flex:1; transition:all 0.15s ease;
}
.cj-kpi:hover { box-shadow:0 2px 8px rgba(0,0,0,0.08); }
.cj-kpi-value { font-size:24px; font-weight:700; color:var(--cj-brand); }
.cj-kpi-label { font-size:11px; color:#64748b; margin-top:4px; }

/* === UTILITIES SIDEBAR LAYOUT === */
.cj-util-layout { display:flex; gap:24px; }
.cj-util-sidebar {
  width:260px; flex-shrink:0; position:sticky; top:60px; align-self:flex-start;
  max-height:calc(100vh - 80px); overflow-y:auto;
  background:white; border:1px solid #e2e8f0; border-radius:8px; box-shadow:0 1px 3px rgba(0,0,0,0.06); padding:16px;
}
.cj-util-sidebar-header { font-size:12px; font-weight:600; color:#64748b; text-transform:uppercase; letter-spacing:0.05em; margin-bottom:12px; }
.cj-util-search {
  width:100%; padding:8px 12px; border:1px solid #e2e8f0; border-radius:6px;
  font-size:12px; margin-bottom:12px; outline:none; transition:all 0.15s ease;
}
.cj-util-search:focus { border-color:var(--cj-brand); }
.cj-util-item {
  padding:8px 12px; border-radius:6px; cursor:pointer; font-size:13px;
  color:#1e293b; transition:all 0.15s ease; margin-bottom:2px;
}
.cj-util-item:hover { background:#f1f5f9; }
.cj-util-item.active { background:var(--cj-brand); color:white; font-weight:500; }
.cj-util-item-count { font-size:11px; color:#64748b; float:right; }
.cj-util-item.active .cj-util-item-count { color:rgba(255,255,255,0.7); }
.cj-util-content { flex:1; min-width:0; }
.cj-attr-detail { display:none; }
.cj-attr-detail.active { display:block; }

/* === TABLES === */
.cj-table { width:100%; border-collapse:collapse; font-size:13px; }
.cj-table th { text-align:left; padding:12px 16px; border-bottom:2px solid #e2e8f0; color:#64748b; font-weight:600; font-size:11px; text-transform:uppercase; letter-spacing:0.4px; }
.cj-table th.cj-num-header { text-align:right; }
.cj-table td { padding:10px 16px; border-bottom:1px solid #f1f5f9; }
.cj-label-col { font-weight:400; color:#334155; }
.cj-num { font-variant-numeric:tabular-nums; text-align:right; }
.cj-positive { color:#16a34a; font-weight:500; }
.cj-negative { color:#dc2626; font-weight:500; }
.cj-baseline { color:#64748b; font-size:11px; font-weight:400; }
.cj-highlight-row { background:#f0fdf4; }
.cj-bar-cell { width:200px; }
.cj-bar { height:18px; background:var(--cj-brand); border-radius:4px; opacity:0.75; transition:width 200ms; }

/* === CHART CONTAINERS === */
.cj-chart-container { margin:16px 0; }
.cj-chart-wrap { margin:8px 0; }
.cj-chart-wrap svg { display:block; }

/* === EXPORT BUTTONS === */
.cj-export-bar { display:flex; gap:8px; margin-bottom:16px; flex-wrap:wrap; }
.cj-export-btn {
  display:inline-flex; align-items:center; gap:4px; padding:6px 12px;
  font-size:11px; font-weight:500; border:1px solid #e2e8f0; border-radius:6px;
  background:white; color:#64748b; cursor:pointer; transition:all 0.15s ease;
}
.cj-export-btn:hover { border-color:var(--cj-brand); color:var(--cj-brand); }

/* === INSIGHT AREAS === */
.cj-insight-area { margin-top:16px; border-top:1px solid #f1f5f9; padding-top:12px; }
.cj-insight-toggle {
  font-size:12px; color:var(--cj-brand); cursor:pointer; font-weight:500;
  background:none; border:none; padding:4px 0; transition:all 0.15s ease;
}
.cj-insight-toggle:hover { text-decoration:underline; }
.cj-insight-body { display:none; margin-top:8px; }
.cj-insight-body.open { display:block; }
.cj-insight-editor {
  min-height:60px; padding:12px; border:1px solid #e2e8f0; border-radius:6px;
  font-size:13px; line-height:1.5; color:#1e293b; outline:none; transition:all 0.15s ease;
}
.cj-insight-editor:focus { border-color:var(--cj-brand); box-shadow:0 0 0 2px rgba(50,51,103,0.1); }
.cj-insight-editor:empty::before {
  content:attr(data-placeholder); color:#64748b; font-style:italic;
}

/* === ATTRIBUTE-LEVEL STICKY NOTES === */
.cj-attr-note { margin-top:14px; border-top:1px solid #f1f5f9; padding-top:10px; }
.cj-attr-note-toggle {
  display:inline-flex; align-items:center; gap:6px; cursor:pointer;
  font-size:12px; color:#64748b; font-weight:500; padding:4px 8px;
  border-radius:4px; transition:all 0.2s ease; background:none; border:none;
}
.cj-attr-note-toggle:hover { background:#f1f5f9; color:var(--cj-brand); }
.cj-attr-note-toggle.has-note { color:var(--cj-brand); }
.cj-attr-note-toggle.has-note .cj-attr-note-label { font-weight:600; }
.cj-attr-note-icon { font-size:14px; }
.cj-attr-note-body {
  margin-top:8px; animation:cj-note-fadein 0.2s ease;
}
@keyframes cj-note-fadein { from { opacity:0; transform:translateY(-4px); } to { opacity:1; transform:translateY(0); } }
.cj-attr-note-editor {
  min-height:48px; padding:10px 12px; border:1.5px solid #e2e8f0; border-radius:6px;
  font-size:12px; line-height:1.6; color:#1e293b; outline:none;
  background:#fefce8; transition:all 0.2s ease;
}
.cj-attr-note-editor:focus { border-color:var(--cj-brand); box-shadow:0 0 0 2px rgba(50,51,103,0.08); background:#fffef5; }
.cj-attr-note-editor:empty::before {
  content:attr(data-placeholder); color:#a3a3a3; font-style:italic;
}

/* === PIN BUTTON (emoji style, matches tabs) === */
.cj-pin-btn {
  background:none; border:1px solid #e2e8f0; border-radius:4px;
  cursor:pointer; font-size:14px; padding:3px 8px;
  color:#64748b; transition:all 0.15s ease; position:relative;
}
.cj-pin-btn:hover { border-color:var(--cj-brand); color:var(--cj-brand); }
.cj-pin-btn.pinned { color:var(--cj-brand); border-color:var(--cj-brand); }

/* PIN POPOVER — now injected by shared turas_pins_popover.js */

/* === PINNED CARD HEADER + OVERFLOW MENU === */
.cj-pinned-card-header { display:flex; justify-content:space-between; align-items:center; margin-bottom:8px; }
.cj-pinned-menu {
  position:absolute; top:calc(100% + 4px); right:0; z-index:200;
  background:#fff; border:1px solid #e2e8f0; border-radius:8px;
  box-shadow:0 4px 16px rgba(0,0,0,0.12); padding:6px 0; min-width:170px;
}

/* === PIN BOUNCE ANIMATION === */
@keyframes cj-pin-bounce {
  0%   { transform:scale(1); }
  30%  { transform:scale(1.25); }
  60%  { transform:scale(0.9); }
  100% { transform:scale(1); }
}
.cj-pin-btn.bounce { animation:cj-pin-bounce 400ms ease; }

/* === TOAST NOTIFICATION === */
.cj-toast {
  position:fixed; top:20px; right:20px; z-index:2000;
  background:#1e293b; color:#fff; padding:10px 20px;
  border-radius:8px; font-size:13px; font-weight:500;
  box-shadow:0 4px 12px rgba(0,0,0,0.15);
  transform:translateX(120%); opacity:0;
  transition:transform 300ms cubic-bezier(0.4,0,0.2,1), opacity 300ms ease;
  pointer-events:none;
}
.cj-toast.visible { transform:translateX(0); opacity:1; }

/* === TAB BADGE === */
.cj-tab-badge {
  display:inline-flex; align-items:center; justify-content:center;
  min-width:18px; height:18px; padding:0 5px; border-radius:9px;
  background:var(--cj-brand); color:#fff; font-size:10px; font-weight:700;
  margin-left:6px; vertical-align:middle;
}

/* === SIMULATOR CALLOUTS (mode-switched) === */
.cj-sim-callout { display:none; }
.cj-sim-callout.active { display:block; }

/* === SLIDES PANEL === */
.cj-slides-container { min-height:200px; }
.cj-slide-tabs {
  display:flex; gap:0; border-bottom:2px solid #e2e8f0; margin-bottom:16px;
  overflow-x:auto; -webkit-overflow-scrolling:touch;
}
.cj-slide-tab {
  padding:8px 16px; font-size:12px; font-weight:500; color:#64748b;
  cursor:pointer; border:none; border-bottom:2px solid transparent;
  background:none; white-space:nowrap; transition:all 200ms;
  margin-bottom:-2px;
}
.cj-slide-tab:hover { color:var(--cj-brand); }
.cj-slide-tab.active { color:var(--cj-brand); border-bottom-color:var(--cj-brand); font-weight:600; }
.cj-slide-card {
  background:white; border-radius:8px; padding:20px; margin-bottom:16px;
  box-shadow:0 1px 3px rgba(0,0,0,0.06); position:relative;
  border-left:3px solid var(--cj-brand); display:none;
}
.cj-slide-card.active { display:block; }
.cj-slide-header {
  display:flex; align-items:center; justify-content:space-between; margin-bottom:12px;
  padding-bottom:10px; border-bottom:1px solid #f1f5f9;
}
.cj-slide-title-input {
  font-size:15px; font-weight:600; color:#1e293b; border:none; border-bottom:1.5px solid transparent;
  background:transparent; outline:none; padding:2px 0; flex:1; margin-right:12px;
  transition:border-color 200ms;
}
.cj-slide-title-input:focus { border-bottom-color:var(--cj-brand); }
.cj-slide-title-input::placeholder { color:#64748b; font-style:italic; }
.cj-slide-editor-layout { display:flex; gap:16px; }
.cj-slide-editor-layout textarea {
  flex:1; min-height:200px; padding:12px; border:1px solid #e2e8f0; border-radius:6px;
  font-size:13px; line-height:1.6; font-family:ui-monospace,SFMono-Regular,Menlo,monospace;
  color:#334155; outline:none; resize:vertical;
}
.cj-slide-editor-layout textarea:focus { border-color:var(--cj-brand); box-shadow:0 0 0 2px rgba(50,51,103,0.1); }
.cj-slide-preview {
  flex:1; min-height:200px; padding:12px 16px; border:1px solid #e2e8f0;
  border-radius:6px; background:#fafbfc; font-size:13px; line-height:1.6;
  color:#334155; overflow-y:auto;
}
.cj-slide-preview h1 { font-size:20px; font-weight:700; color:#1e293b; margin:16px 0 8px; }
.cj-slide-preview h2 { font-size:17px; font-weight:600; color:#1e293b; margin:14px 0 6px; }
.cj-slide-preview h3 { font-size:14px; font-weight:600; color:#334155; margin:12px 0 4px; }
.cj-slide-preview p { margin-bottom:8px; }
.cj-slide-preview ul, .cj-slide-preview ol { margin:8px 0 8px 20px; }
.cj-slide-preview li { margin-bottom:4px; }
.cj-slide-preview blockquote { border-left:3px solid #e2e8f0; padding-left:12px; margin:8px 0; color:#64748b; font-style:italic; }
.cj-slide-preview code { background:#f1f5f9; padding:1px 4px; border-radius:3px; font-size:12px; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; }
.cj-slide-preview hr { border:none; border-top:1px solid #e2e8f0; margin:12px 0; }
.cj-slide-actions { display:flex; gap:6px; flex-shrink:0; }
.cj-slide-empty { text-align:center; padding:60px 20px; color:#64748b; }

/* === PINNED VIEWS (tabs-quality styling) === */
.cj-pinned-container { min-height:200px; max-width:1400px; margin:0 auto; }
.cj-pinned-header { display:flex; align-items:center; justify-content:space-between; margin-bottom:20px; }
.cj-pinned-empty { text-align:center; padding:60px 20px; color:#64748b; }
.cj-pinned-empty-icon { font-size:36px; margin-bottom:12px; }

/* Pinned card — matches tabs module quality */
.cj-pinned-card {
  background:#ffffff; border:1px solid #e8e5e0; border-radius:8px;
  padding:20px 24px; margin-bottom:16px; page-break-inside:avoid;
}
.cj-pinned-card-header { display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:10px; }
.cj-pinned-card-title { font-size:18px; font-weight:600; color:#1e293b; margin-bottom:2px; }
.cj-pinned-card-subtitle { font-size:13px; font-weight:400; color:#94a3b8; }
.cj-pinned-card-actions { display:flex; gap:4px; flex-shrink:0; }

/* Insight area — brand-accented left border */
.cj-pinned-card-insight {
  margin-bottom:12px; padding:14px 20px;
  border-left:3px solid var(--cj-brand,#323367); background:#f8fafa;
  border-radius:0 6px 6px 0; font-size:14px; line-height:1.6; color:#1e293b;
}
.cj-pinned-card-insight:empty { display:none; }
.cj-pinned-card-insight[data-placeholder]:empty::before {
  content:attr(data-placeholder); color:#94a3b8; font-style:italic;
}

/* Chart area */
.cj-pinned-card-chart { margin-bottom:12px; }
.cj-pinned-card-chart svg { width:100%; height:auto; }

/* Table area — full width, polished */
.cj-pinned-card-table { overflow-x:auto; margin-bottom:8px; }
.cj-pinned-card-table table { width:100% !important; border-collapse:collapse; font-size:13px; }
.cj-pinned-card-table th {
  padding:8px 12px; text-align:left; font-size:11px; font-weight:600;
  text-transform:uppercase; letter-spacing:0.3px; color:#64748b;
  background:#f8fafc; border-bottom:2px solid #e2e8f0; max-width:none;
}
.cj-pinned-card-table td {
  padding:8px 12px; border-bottom:1px solid #f1f5f9; color:#334155; max-width:none;
}
.cj-pinned-card-table tr:last-child td { border-bottom:none; }
.cj-pinned-card-table tr:hover td { background:#f8fafc; }

/* Drag & drop */
.cj-pinned-card[draggable="true"]:active { cursor:grabbing; }
.pin-dragging { opacity:0.4 !important; }
.pin-drop-target { outline:2px dashed var(--cj-brand,#323367); outline-offset:4px; }

/* Section dividers */
.cj-pinned-section-divider {
  display:flex; align-items:center; gap:12px; padding:12px 0;
  margin:8px 0; border-bottom:2px solid var(--cj-brand,#323367);
}
.cj-pinned-section-title {
  font-size:16px; font-weight:600; color:var(--cj-brand,#323367);
  flex:1; outline:none; min-width:100px;
}
.cj-pinned-section-title:focus { border-bottom:1px dashed #e2e8f0; }
.cj-pinned-section-actions { display:flex; gap:4px; }
.cj-pinned-remove-btn {
  background:none; border:1px solid #e2e8f0; border-radius:4px;
  cursor:pointer; font-size:16px; line-height:1; padding:2px 6px; color:#94a3b8;
}
.cj-pinned-remove-btn:hover { background:#fee2e2; color:#dc2626; border-color:#fecaca; }
.cj-pinned-action-btn {
  background:none; border:1px solid #e2e8f0; border-radius:4px;
  cursor:pointer; font-size:11px; padding:2px 6px; color:#64748b;
}
.cj-pinned-action-btn:hover { background:#f1f5f9; }

/* Overflow menu */
.pin-overflow-item:hover { background:#f1f5f9; }

/* === SIMULATOR === */
.cj-sim-grid-container { margin-bottom:0; }
.cj-sim-grid-scroll { overflow-x:auto; }
.cj-sim-grid {
  width:100%; border-collapse:collapse; font-size:12px;
}
.cj-sim-grid th, .cj-sim-grid td { padding:6px 10px; text-align:left; vertical-align:middle; }
.cj-sim-grid thead th { border-bottom:2px solid #e2e8f0; }
.cj-sim-grid tbody tr { border-bottom:1px solid #f1f5f9; }
.cj-sim-grid tbody tr:last-child { border-bottom:none; }
.cj-sim-grid-attr { min-width:40px; }
.cj-sim-grid-attr-label { font-size:12px; color:#64748b; font-weight:500; white-space:nowrap; min-width:120px; }
.cj-sim-grid-prod-header { min-width:150px; }
.cj-sim-grid-cell { min-width:140px; }
.cj-sim-grid-actions { display:flex; gap:2px; margin-top:2px; }
.cj-sim-grid-action { background:none; border:none; color:#94a3b8; cursor:pointer; font-size:13px; padding:1px 4px; border-radius:3px; transition:color 0.15s; }
.cj-sim-grid-action:hover { color:#ef4444; }
.cj-sim-grid-add { width:40px; text-align:center; vertical-align:middle; }
.cj-sim-add-col-btn {
  width:32px; height:32px; border-radius:50%; border:2px dashed #cbd5e1;
  background:none; color:#94a3b8; font-size:18px; cursor:pointer; transition:all 0.15s;
  display:inline-flex; align-items:center; justify-content:center;
}
.cj-sim-add-col-btn:hover { border-color:var(--cj-brand); color:var(--cj-brand); }
.cj-sim-product-name {
  font-size:12px; font-weight:600; color:#1e293b; border:none; border-bottom:1.5px solid transparent;
  background:transparent; outline:none; padding:2px 0; width:130px; transition:border-color 0.15s ease;
}
.cj-sim-product-name:focus { border-bottom-color:var(--cj-brand); }
.cj-sim-select {
  width:100%; padding:5px 8px; border:1px solid #e2e8f0; border-radius:4px;
  font-size:12px; outline:none; transition:all 0.15s ease; font-family:inherit;
}
.cj-sim-select:focus { border-color:var(--cj-brand); }
.cj-sim-add-btn {
  display:inline-flex; align-items:center; gap:4px; padding:8px 16px;
  font-size:12px; font-weight:500; border:1px solid #e2e8f0; border-radius:6px;
  background:white; color:var(--cj-brand); cursor:pointer; transition:all 0.15s ease;
}
.cj-sim-add-btn:hover { background:var(--cj-brand); color:white; }
.cj-sim-results { min-height:100px; }
.cj-sim-share-bar { margin:8px 0; }
.cj-sim-bar-bg { height:28px; background:#f1f5f9; border-radius:4px; overflow:hidden; position:relative; }
.cj-sim-bar-fill { height:100%; border-radius:4px; transition:width 300ms; display:flex; align-items:center; justify-content:flex-end; padding-right:8px; color:white; font-size:11px; font-weight:600; }
.cj-sim-mode-btns { display:flex; gap:8px; margin-bottom:16px; }
.cj-sim-mode-btn {
  padding:6px 14px; font-size:12px; font-weight:500; border:1px solid #e2e8f0;
  border-radius:6px; background:white; color:#64748b; cursor:pointer; transition:all 0.15s ease;
}
.cj-sim-mode-btn.active { background:var(--cj-brand); color:white; border-color:var(--cj-brand); }

/* === ABOUT PAGE === */
.cj-about-section { max-width:700px; }
.cj-about-grid { display:grid; grid-template-columns:120px 1fr; gap:8px 16px; margin-bottom:16px; }
.cj-about-label { font-size:12px; font-weight:500; color:#64748b; text-transform:uppercase; letter-spacing:0.05em; }
.cj-about-value { font-size:13px; color:#334155; }
.cj-about-value a { color:var(--cj-brand); text-decoration:none; }
.cj-about-value a:hover { text-decoration:underline; }
.cj-about-notes {
  min-height:80px; padding:12px; border:1px solid #e2e8f0; border-radius:6px;
  font-size:13px; line-height:1.5; outline:none; margin-top:8px;
}
.cj-about-notes:focus { border-color:var(--cj-brand); }
.cj-about-notes:empty::before { content:attr(data-placeholder); color:#64748b; font-style:italic; }

/* === HELP OVERLAY === */
.cj-help-overlay {
  display:none; position:fixed; top:0; right:0; bottom:0; left:0; background:rgba(0,0,0,0.5);
  z-index:1000; align-items:center; justify-content:center;
}
.cj-help-overlay.open { display:flex; }
.cj-help-card {
  background:white; border-radius:12px; padding:32px; max-width:500px; width:90%;
  box-shadow:0 20px 60px rgba(0,0,0,0.2);
}
.cj-help-card h2 { font-size:18px; font-weight:700; color:#1e293b; margin-bottom:16px; }
.cj-help-card ul { list-style:none; padding:0; }
.cj-help-card li { padding:6px 0; font-size:13px; color:#334155; display:flex; gap:8px; }
.cj-help-key { font-weight:600; color:var(--cj-brand); min-width:120px; flex-shrink:0; }
.cj-help-dismiss { text-align:center; margin-top:20px; font-size:12px; color:#64748b; }

/* === STATUS INDICATORS === */
.cj-status-pass { color:#16a34a; font-weight:600; }
.cj-status-fail { color:#dc2626; font-weight:600; }

/* === FOOTER === */
.cj-footer { text-align:center; padding:20px 40px; color:#64748b; font-size:11px; border-top:1px solid #e2e8f0; }

/* === RESPONSIVE === */
@media (max-width:768px) {
  .cj-header, .cj-report-tabs, .cj-panels-wrap, .cj-footer { padding-left:16px; padding-right:16px; }
  .cj-kpi-row { flex-direction:column; }
  .cj-util-layout { flex-direction:column; }
  .cj-util-sidebar { width:100%; position:static; max-height:none; }
  .cj-sim-grid-scroll { -webkit-overflow-scrolling:touch; }
}
')
  css <- paste0(shared_css, "\n\n/* === CONJOINT MODULE STYLES === */\n", css)
  css
}


# ==============================================================================
# PANEL HELPERS
# ==============================================================================

#' Callout box, using the shared design system when it is loaded
#'
#' @keywords internal
.build_callout <- function(title, body_html, collapsed = FALSE) {
  if (exists("turas_callout_html", mode = "function")) {
    return(turas_callout_html(title = title, body = body_html, collapsed = collapsed))
  }
  sprintf(
    '<div class="t-callout"><div class="t-callout-body"><strong>%s</strong> %s</div></div>',
    .html_escape(title), body_html
  )
}


#' No insight editor in the standalone tool
#'
#' The report carried an editable insight box under each panel. A simulator on
#' its own is a tool the reader drives, not a document they annotate, and the
#' editor's persistence belonged to the report's save machinery. Returns
#' nothing rather than a box that cannot be saved.
#'
#' @keywords internal
build_insight_area <- function(...) ""


# ==============================================================================
# SIMULATOR DATA
# ==============================================================================

#' Build simulator JSON-ready data from utilities and config
#' @keywords internal
.build_simulator_data <- function(utilities, importance, model_result, config, report_config = list()) {
  if (is.null(utilities)) return(NULL)

  # Build attribute list with levels and utilities
  attr_names <- unique(utilities$Attribute)
  attributes <- lapply(attr_names, function(attr) {
    attr_utils <- utilities[utilities$Attribute == attr, , drop = FALSE]
    levels_list <- lapply(seq_len(nrow(attr_utils)), function(i) {
      list(
        name    = as.character(attr_utils$Level[i]),
        utility = as.numeric(attr_utils$Utility[i])
      )
    })
    imp_val <- if (!is.null(importance)) {
      imp_row <- importance[importance$Attribute == attr, ]
      if (nrow(imp_row) > 0) imp_row$Importance[1] else 0
    } else 0

    list(name = attr, levels = levels_list, importance = imp_val)
  })

  sim_data <- list(
    meta = list(
      project_name      = config$project_name %||% "Conjoint Simulator",
      estimation_method = model_result$method %||% "mlogit",
      n_respondents     = model_result$n_respondents %||% NA,
      default_customers = as.numeric(config$default_customers %||%
                                     report_config$default_customers %||% 1000),
      currency_symbol   = config$currency_symbol %||% "$",
      generated         = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    ),
    attributes = attributes,
    individual = list(),
    classes    = list()
  )

  # Default products from config (pre-defined simulator products)
  sim_products <- report_config$simulator_products %||% config$simulator_products %||% NULL
  if (!is.null(sim_products) && is.list(sim_products) && length(sim_products) > 0) {
    default_products <- lapply(sim_products, function(prod) {
      levels <- as.list(prod[setdiff(names(prod), "name")])
      list(name = prod$name %||% "Product", levels = levels)
    })
    sim_data$defaultProducts <- default_products
  }

  # Individual betas for RFC (if HB)
  if (!is.null(model_result$individual_betas)) {
    sim_data$individual <- list(has_data = TRUE)
    # Individual betas can be very large; include summary statistics only
    # to keep file size manageable
  }

  # Latent class data
  if (!is.null(model_result$latent_class)) {
    lc <- model_result$latent_class
    sim_data$classes <- list(
      n_classes = lc$optimal_k %||% 0,
      sizes     = lc$class_sizes %||% list()
    )
  }

  sim_data
}

#' Convert simulator data to JSON string
#' @keywords internal
simulator_data_to_json <- function(sim_data) {
  if (is.null(sim_data)) return("{}")
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::toJSON(sim_data, auto_unbox = TRUE, pretty = FALSE, digits = 6)
  } else {
    # Minimal fallback: just utilities
    "{}"
  }
}

# ==============================================================================
# PANEL MARKUP
# ==============================================================================


# ==============================================================================
# SIMULATOR PANEL
# ==============================================================================

#' @keywords internal
build_simulator_panel <- function(html_data, brand) {

  if (is.null(html_data$simulator_data)) {

    # A suppressed simulator is a decision with a reason, not an absence.
    # Saying "no simulator data available" where the real answer is "this
    # model cannot be simulated honestly" leaves the reader to guess.
    if (isTRUE(html_data$simulator_suppressed)) {
      reason <- html_data$simulator_suppressed_reason %||%
        paste0("The simulator is not available for this model.")
      return(paste0(
        '<div class="cj-panel" role="tabpanel" id="panel-simulator"><div class="cj-card">',
        '<h2 style="margin-top:0;">Market Simulator</h2>',
        '<p><strong>Not included for this study.</strong></p>',
        '<p>', .html_escape(reason), '</p>',
        '</div></div>'
      ))
    }

    return('<div class="cj-panel" role="tabpanel" id="panel-simulator"><div class="cj-card"><p>No simulator data available.</p></div></div>')
  }

  # Mode-switched callouts
  sim_callout_shares <- .build_callout("Market Shares",
    "<p>Market share simulation predicts each product\u2019s share of preference using the configured attribute levels. Configure products on the left and see predicted shares update on the right.</p><p><strong>No-Purchase Option:</strong> The \u2018Include No-Purchase\u2019 checkbox adds a \u2018do nothing\u2019 alternative.</p>
<details style=\"margin-top:10px;\"><summary style=\"cursor:pointer;font-weight:600;font-size:12px;color:#323367;\">How does share calculation work?</summary>
<div style=\"margin-top:8px;font-size:12px;line-height:1.7;\">
<p>Each product\u2019s <strong>total utility</strong> is the sum of its part-worth utilities across all attributes. For example, if Brand=PremiumX has utility +0.30 and Price=$199 has utility +0.50, the product\u2019s total utility is 0.80.</p>
<p><strong>Logit (MNL):</strong> Shares are computed as: Share(i) = exp(U<sub>i</sub>) / \u03a3 exp(U<sub>j</sub>). This distributes preference proportionally \u2014 a product with twice the exponentiated utility gets roughly twice the share. The exponential function means utility differences are amplified non-linearly: a 0.5 utility advantage translates to a larger share advantage than a linear model would predict.</p>
<p><strong>RFC:</strong> Adds random noise (Gumbel-distributed) to each utility, then counts which product \u201cwins\u201d across thousands of draws. With aggregate utilities this approximates Logit; with individual betas it captures preference heterogeneity.</p>
<p><strong>Scale Factor:</strong> Multiplies all utilities before computing shares. A factor &gt;1 amplifies differences (dominant products get even more share); &lt;1 compresses them (shares become more equal). Use to calibrate against known market data.</p>
</div></details>")
  sim_callout_sensitivity <- .build_callout("Sensitivity Analysis",
    "<p>Sensitivity analysis reveals <strong>how much market share changes</strong> when you switch between levels of a single attribute, while keeping everything else constant.</p><p><strong>Tip:</strong> Compare sensitivity across attributes to find the most impactful levers for your product strategy.</p>
<details style=\"margin-top:10px;\"><summary style=\"cursor:pointer;font-weight:600;font-size:12px;color:#323367;\">How does sensitivity work?</summary>
<div style=\"margin-top:8px;font-size:12px;line-height:1.7;\">
<p>For the selected product and attribute, the simulator cycles through every level of that attribute while holding all other attributes constant. At each level, it recalculates the full market share for all products.</p>
<p>The result is a curve showing: <em>if we change just this one attribute, how does our share move?</em> Steep slopes indicate high sensitivity \u2014 that attribute is a powerful lever. Flat curves mean changes to that attribute have little competitive impact.</p>
<p><strong>Price sensitivity</strong> is particularly useful: the resulting curve is a demand curve, showing how market share declines as price increases. The slope of this curve at any point approximates the price elasticity of demand.</p>
<p><strong>Interpreting the chart:</strong> The x-axis shows attribute levels; the y-axis shows the focal product\u2019s predicted market share. Competitors\u2019 configurations remain fixed.</p>
</div></details>")
  sim_callout_sov <- .build_callout("Source of Volume",
    "<p>Source of Volume shows where a new product draws its market share from \u2014 which competitors lose the most when a new entrant appears.</p>
<details style=\"margin-top:10px;\"><summary style=\"cursor:pointer;font-weight:600;font-size:12px;color:#323367;\">How does source of volume work?</summary>
<div style=\"margin-top:8px;font-size:12px;line-height:1.7;\">
<p>The analysis runs in two steps:</p>
<ol style=\"margin:4px 0 4px 16px;\">
<li><strong>Baseline:</strong> Calculate market shares for existing products only (without the new product)</li>
<li><strong>Test:</strong> Add the new product and recalculate shares for all products (including the new one)</li>
</ol>
<p>The difference between baseline and test shares for each existing product shows how much share it lost to the new entrant. Products that are most similar to the new product (in terms of attribute levels) lose the most share \u2014 this is the IIA (Independence of Irrelevant Alternatives) property of the logit model.</p>
<p><strong>Reading the chart:</strong> Negative bars show share lost by existing products; the positive bar shows the new product\u2019s gained share. The total volume is conserved \u2014 what the new product gains exactly equals what competitors collectively lose.</p>
</div></details>")

  sim_callout_revenue <- .build_callout("Revenue Simulator",
    "<p>Revenue simulation shows how much revenue each product configuration would generate, by combining market share, price, and a hypothetical customer base.</p><p><strong>Revenue = Price \u00d7 Share% \u00d7 Customers</strong></p><p>Adjust the customer count to match your market size. A product with lower market share but higher price can generate more revenue than a cheaper product with higher share \u2014 this is the key insight.</p>
<details style=\"margin-top:10px;\"><summary style=\"cursor:pointer;font-weight:600;font-size:12px;color:#323367;\">Why revenue matters more than share</summary>
<div style=\"margin-top:8px;font-size:12px;line-height:1.7;\">
<p>Market share tells you which product people prefer. Revenue tells you which product makes money. A product at $10 with 59% share generates $5,900 in revenue per 1000 customers. A product at $6 with 41% share generates only $2,460. Leadership cares about revenue, not preference.</p>
</div></details>")

  sim_callouts <- sprintf(
    '<div id="cj-sim-callout-shares" class="cj-sim-callout active">%s</div>
<div id="cj-sim-callout-revenue" class="cj-sim-callout">%s</div>
<div id="cj-sim-callout-sensitivity" class="cj-sim-callout">%s</div>
<div id="cj-sim-callout-sov" class="cj-sim-callout">%s</div>',
    sim_callout_shares, sim_callout_revenue, sim_callout_sensitivity, sim_callout_sov
  )

  # Simulator export bar
  sim_export <- '<div class="cj-export-bar">
<button class="cj-export-btn" onclick="exportSimulatorExcel()">Excel</button>
<button class="cj-export-btn" onclick="cjExportPNG(\'simulator\', this)">Export PNG</button>
</div>'

  insight <- build_insight_area("simulator", html_data$insights)
  pin_sim <- ""

  sprintf(
    '<div class="cj-panel" role="tabpanel" id="panel-simulator">
<div class="cj-card">
<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px;">
<h2 style="margin-bottom:0;">Market Simulator</h2>
<div style="display:flex;gap:8px;">%s %s</div>
</div>
%s
<p style="font-size:12px;color:#64748b;margin-bottom:16px;">Configure product profiles and compare predicted market shares.</p>
<div class="cj-sim-grid-container">
<div class="cj-sim-grid-scroll" id="cj-sim-products"></div>
</div>
</div>
<div class="cj-card" style="margin-top:0;">
<div class="cj-sim-mode-btns">
<button class="cj-sim-mode-btn active" onclick="switchSimMode(\'shares\')">Market Shares</button>
<button class="cj-sim-mode-btn" onclick="switchSimMode(\'revenue\')">Revenue</button>
<button class="cj-sim-mode-btn" onclick="switchSimMode(\'sensitivity\')">Sensitivity</button>
<button class="cj-sim-mode-btn" onclick="switchSimMode(\'sov\')">Source of Volume</button>
</div>
<div class="cj-sim-results" id="cj-sim-results">
<div style="text-align:center;padding:40px;color:#94a3b8;">
<div style="font-size:18px;">Add products to see predicted shares</div>
</div>
</div>
</div>
%s
</div>',
    pin_sim, sim_export, sim_callouts, insight
  )
}
