# ==============================================================================
# HTML REPORT - PAGE STYLING (V11.0 - Design System)
# ==============================================================================
# CSS stylesheet generation for the HTML report.
# Now uses the shared Turas Design System for base styles (typography,
# tokens, font embedding, common components) and layers tabs-specific
# styles on top.
#
# FUNCTIONS:
# - build_css() - Main CSS stylesheet with brand colour substitution
# - build_print_css() - Print/PDF optimized @media print styles
#
# DEPENDENCIES:
# - modules/shared/lib/design_system/design_tokens.R
# - modules/shared/lib/design_system/font_embed.R
# - modules/shared/lib/design_system/base_css.R
# ==============================================================================

# Source the shared design system (TURAS_ROOT-aware)
local({
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) turas_root <- getwd()
  ds_dir <- file.path(turas_root, "modules", "shared", "lib", "design_system")
  if (!dir.exists(ds_dir)) ds_dir <- file.path("modules", "shared", "lib", "design_system")
  if (!exists("turas_base_css", mode = "function") && dir.exists(ds_dir)) {
    source(file.path(ds_dir, "design_tokens.R"), local = FALSE)
    source(file.path(ds_dir, "font_embed.R"), local = FALSE)
    source(file.path(ds_dir, "base_css.R"), local = FALSE)
  }
})

#' Build CSS Stylesheet
#'
#' @param brand_colour Character hex colour
#' @return htmltools::tags$style
build_css <- function(brand_colour, accent_colour = "#CC9900") {
  # Use gsub instead of sprintf to avoid R's 8192 char format string limit
  bc <- brand_colour
  ac <- accent_colour

  # --- Shared base CSS (Inter font, tokens, typography, common components) ---
  base_css <- tryCatch(
    turas_base_css(brand_colour, accent_colour, prefix = "ct"),
    error = function(e) ""
  )

  # --- Tabs-specific CSS (overrides and additions) ---
  css_layout <- '
    /* === TABS-SPECIFIC OVERRIDES === */
    .header {
      background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
      padding: 24px 32px;
      border-bottom: 3px solid BRAND;
    }
    .header-inner {
      max-width: 1400px;
      margin: 0 auto;
    }
    .main-layout {
      max-width: 1400px;
      margin: 0 auto;
      padding: 20px 32px;
      display: flex;
      gap: 24px;
    }
    .sidebar {
      width: 280px;
      flex-shrink: 0;
    }
    .sidebar-inner {
      position: sticky;
      top: 20px;
    }
    .search-box {
      width: 100%;
      padding: 10px 14px;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      font-size: 13px;
      font-family: inherit;
      outline: none;
      background: #ffffff;
      margin-bottom: 16px;
      transition: border-color 0.15s;
    }
    .search-box:focus { border-color: BRAND; }
    .question-list {
      background: #ffffff;
      border-radius: 8px;
      border: 1px solid #e2e8f0;
      overflow: hidden;
    }
    .question-list-header {
      padding: 10px 14px;
      border-bottom: 1px solid #e2e8f0;
      font-size: 11px;
      font-weight: 600;
      color: #64748b;
      letter-spacing: 1px;
      text-transform: uppercase;
    }
    .question-list-scroll {
      max-height: calc(100vh - 220px);
      overflow-y: auto;
      scrollbar-width: thin;
      scrollbar-color: #cbd5e1 transparent;
    }
    .question-list-scroll::-webkit-scrollbar { width: 6px; }
    .question-list-scroll::-webkit-scrollbar-track { background: transparent; }
    .question-list-scroll::-webkit-scrollbar-thumb {
      background: #cbd5e1; border-radius: 3px;
    }
    .question-item {
      padding: 10px 14px;
      cursor: pointer;
      border-bottom: 1px solid #e2e8f0;
      border-left: 3px solid transparent;
      transition: all 0.15s ease;
    }
    .question-item:hover { background: #f8fafc; }
    .question-item.active {
      background: #f0f4f8;
      border-left-color: BRAND;
    }
    .question-item-code {
      font-size: 10px;
      font-weight: 700;
      color: #94a3b8;
      letter-spacing: 0.5px;
      margin-bottom: 2px;
    }
    .question-item.active .question-item-code { color: BRAND; }
    .question-item-text {
      font-size: 12px;
      color: #1e293b;
      line-height: 1.35;
    }
    .question-item.active .question-item-text { font-weight: 600; color: #1a2744; }

    /* === SIDEBAR CATEGORY GROUPS === */
    .sidebar-category-group { border-bottom: 1px solid #f1f5f9; }
    .sidebar-category-group:last-child { border-bottom: none; }
    .sidebar-category-header {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 8px 14px;
      cursor: pointer;
      background: #f8fafc;
      border-bottom: 1px solid #e2e8f0;
      user-select: none;
      transition: background 0.15s;
    }
    .sidebar-category-header:hover { background: #f0f4f8; }
    .sidebar-category-chevron {
      font-size: 8px;
      color: #94a3b8;
      transition: transform 0.2s ease;
      display: inline-block;
    }
    .sidebar-category-group.collapsed .sidebar-category-chevron {
      transform: rotate(-90deg);
    }
    .sidebar-category-name {
      font-size: 11px;
      font-weight: 700;
      color: BRAND;
      letter-spacing: 0.3px;
      text-transform: uppercase;
    }
    .sidebar-category-count {
      font-size: 10px;
      color: #94a3b8;
      font-weight: 500;
    }
    .sidebar-category-items {
      transition: max-height 0.3s ease;
      overflow: hidden;
    }
    .sidebar-category-group.collapsed .sidebar-category-items {
      max-height: 0 !important;
      overflow: hidden;
    }

    .content-area { flex: 1; min-width: 0; }
    .controls-bar {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 16px;
      flex-wrap: wrap;
    }
    .banner-tabs {
      display: flex;
      gap: 0;
      background: #ffffff;
      border-radius: 6px;
      border: 1px solid #e2e8f0;
      overflow: hidden;
      margin-bottom: 12px;
      position: sticky;
      top: 43px;
      z-index: 55;
    }
    .banner-tab {
      padding: 8px 16px;
      border: none;
      background: transparent;
      color: #1e293b;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      font-family: inherit;
      border-right: 1px solid #e2e8f0;
      transition: all 0.15s ease;
    }
    .banner-tab:last-child { border-right: none; }
    .banner-tab.active { background: #1a2744; color: #ffffff; }
    .banner-tab:hover:not(.active) { background: #f8fafc; }
    .toggle-label {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      color: #64748b;
      cursor: pointer;
      user-select: none;
      padding: 5px 12px;
      border: 1px solid #e2e8f0;
      border-radius: 16px;
      background: #fff;
      transition: all 0.15s;
    }
    .toggle-label:hover { border-color: #94a3b8; }
    .toggle-label:has(input:checked),
    .toggle-label.checked {
      background: #f0f4f8; border-color: BRAND; color: #1e293b;
    }
    .toggle-label input { accent-color: BRAND; }
    .question-container { display: none; }
    .question-container.active { display: block; }
    .question-title-card {
      background: #ffffff;
      border-radius: 8px;
      border: 1px solid #e2e8f0;
      padding: 16px 20px;
      margin-bottom: 16px;
    }
    .question-title-row {
      display: flex;
      align-items: baseline;
      gap: 10px;
    }
    .q-collapse-btn {
      background: none; border: none; cursor: pointer; font-size: 10px;
      color: #94a3b8; padding: 2px 4px; transition: transform 0.2s;
      flex-shrink: 0; line-height: 1;
    }
    .q-collapse-btn:hover { color: #64748b; }
    .question-container.q-collapsed .q-collapse-btn { transform: rotate(-90deg); }
    .question-container.q-collapsed .table-wrapper,
    .question-container.q-collapsed .chart-wrapper,
    .question-container.q-collapsed .insight-area,
    .question-container.q-collapsed .table-actions { display: none; }
    .question-code {
      font-size: 11px;
      font-weight: 500;
      color: #94a3b8;
      font-family: inherit;
      letter-spacing: 0.3px;
    }
    .question-text {
      font-size: 16px;
      font-weight: 600;
      color: #1a2744;
      line-height: 1.4;
    }
    .question-meta {
      margin-top: 6px;
      font-size: 11px;
      color: #94a3b8;
    }
    .question-meta strong { color: BRAND; }
    .table-wrapper {
      border-radius: 8px;
      overflow-x: auto;
      border: 1px solid #e2e8f0;
      background: #ffffff;
    }
    .table-actions {
      display: flex;
      justify-content: flex-end;
      padding: 8px 16px;
      background: #f8f7f5;
      border-top: 1px solid #e2e8f0;
    }
    .export-btn {
      padding: 6px 14px;
      border: 1px solid #e2e8f0;
      border-radius: 4px;
      background: #ffffff;
      color: #64748b;
      font-size: 11px;
      font-weight: 600;
      cursor: pointer;
      font-family: inherit;
      transition: all 0.15s;
    }
    .export-btn:hover { background: #f8fafc; color: #1e293b; }
    .slide-menu-item:hover { background: #f1f5f9; }
    /* Unified export dropdown */
    .export-menu-item {
      display: block; width: 100%; text-align: left; padding: 8px 14px;
      border: none; background: none; cursor: pointer; font-size: 12px;
      font-family: inherit; color: #374151; transition: background 0.1s;
    }
    .export-menu-item:hover { background: #f1f5f9; }
    .export-menu-sep { height: 1px; background: #e2e8f0; margin: 4px 0; }
    .export-menu-label {
      padding: 6px 14px 2px; font-size: 10px; font-weight: 600;
      color: #94a3b8; text-transform: uppercase; letter-spacing: 0.5px;
    }
    /* Display options dropdown items */
    .display-opt-item { display: block; padding: 4px 0; }
    /* Drag and drop */
    .pin-dragging { opacity: 0.4 !important; }
    .pin-drop-target { outline: 2px dashed BRAND; outline-offset: 4px; }
    [draggable="true"]:active { cursor: grabbing; }
    /* Pin overflow menu */
    .pin-overflow-item:hover { background: #f1f5f9; }
    /* Section dividers (pinned views) */
    .section-divider { display: flex; align-items: center; gap: 12px; padding: 12px 0; margin: 8px 0; border-bottom: 2px solid BRAND; }
    .section-divider-title { font-size: 16px; font-weight: 600; color: BRAND; flex: 1; outline: none; min-width: 100px; }
    .section-divider-title:focus { border-bottom: 1px dashed #e2e8f0; }
    .section-divider-actions { display: flex; gap: 4px; }
    /* Pinned view cards */
    .pinned-card {
      background: #ffffff; border: 1px solid #e8e5e0; border-radius: 8px;
      padding: 20px 24px; margin-bottom: 16px;
      page-break-inside: avoid;
    }
    .pinned-card-title { font-size: 18px; font-weight: 600; color: #1e293b; margin-bottom: 2px; }
    .pinned-card-subtitle { font-size: 13px; font-weight: 400; color: #94a3b8; }
    .pinned-card-code { font-size: 11px; font-weight: 500; color: #94a3b8; margin-bottom: 4px; }
    .pinned-card-insight {
      margin-bottom: 12px; padding: 14px 20px;
      border-left: 3px solid BRAND; background: #f8fafa;
      border-radius: 0 6px 6px 0;
      font-size: 14px; line-height: 1.6; color: #1e293b;
    }
    .pinned-card-chart { margin-bottom: 12px; }
    .pinned-card-chart svg { width: 100%; height: auto; }
    .pinned-card-table { overflow-x: auto; }
    .footer {
      margin-top: 16px;
      padding: 12px 16px;
      text-align: center;
      font-size: 10px;
      color: #94a3b8;
    }
    .legend-box {
      margin-top: 16px;
      background: #ffffff;
      border-radius: 8px;
      border: 1px solid #e2e8f0;
      padding: 14px;
    }
    .legend-title {
      font-size: 11px;
      font-weight: 600;
      color: #64748b;
      letter-spacing: 1px;
      text-transform: uppercase;
      margin-bottom: 10px;
    }
    .legend-item {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 12px;
      margin-bottom: 6px;
    }
    .sig-badge-legend {
      display: inline-block;
      font-size: 9px;
      font-weight: 700;
      color: #059669;
      background: rgba(5,150,105,0.08);
      border-radius: 3px;
      padding: 1px 4px;
      font-family: ui-monospace, Consolas, monospace;
    }
  '

  css_tables <- '
    /* ---- Crosstab Table Styles (Phase 3 - Premium) ---- */

    /* Table container — card with subtle depth */
    .table-wrapper {
      background: #ffffff;
      border-radius: 8px;
      border: 1px solid #e5e7eb;
      box-shadow: 0 1px 3px rgba(0,0,0,0.04), 0 1px 2px rgba(0,0,0,0.02);
      overflow: hidden;
      -webkit-overflow-scrolling: touch;
      padding-bottom: 1px;
    }

    .ct-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
      color: #1e293b;
      table-layout: auto;
      line-height: 1.5;
    }
    .ct-table.ct-cols-hidden { width: auto; }

    /* --- Header: dark, authoritative --- */
    /* !important needed to override shared design system th[class*="-th"] rules */
    .ct-table .ct-th {
      padding: 12px 16px !important;
      text-align: center !important;
      font-weight: 600 !important;
      font-size: 11px !important;
      text-transform: none !important;
      letter-spacing: 0.5px !important;
      border-bottom: none !important;
      background: #1a2744 !important;
      color: #e2e8f0 !important;
      white-space: normal !important;
      min-width: 80px;
      max-width: 160px;
      vertical-align: bottom !important;
    }
    .ct-table .ct-th.ct-label-col {
      text-align: left !important;
      min-width: 180px;
      max-width: 320px;
      white-space: normal !important;
      word-wrap: break-word;
      position: sticky;
      left: 0;
      background: #1a2744 !important;
      z-index: 2;
      color: #e2e8f0 !important;
    }

    /* --- Data cells --- */
    .ct-td {
      padding: 10px 16px;
      text-align: center;
      border-bottom: 1px solid #f0f1f3;
      white-space: nowrap;
      color: #334155;
      font-size: 13px;
      transition: background-color 0.15s ease;
    }
    .ct-td.ct-label-col {
      text-align: left;
      font-weight: 500;
      color: #1e293b;
      white-space: normal;
      word-wrap: break-word;
      max-width: 320px;
      position: sticky;
      left: 0;
      background: #ffffff;
      z-index: 1;
      border-right: 1px solid #e5e7eb;
    }

    /* --- Zebra striping for data rows --- */
    tr.ct-row-category:nth-child(even) > .ct-td { background: #f9fafb; }
    tr.ct-row-category:nth-child(even) > .ct-td.ct-label-col { background: #f9fafb; }

    /* --- Header text and letter badges --- */
    .ct-table .ct-header-text {
      font-size: 11px;
      line-height: 1.3;
      color: #e2e8f0 !important;
    }
    .ct-table .ct-letter {
      display: inline-block;
      font-size: 9px;
      color: rgba(255,255,255,0.6) !important;
      margin-top: 4px;
      font-weight: 700;
      font-family: ui-monospace, Consolas, monospace;
      letter-spacing: 0;
    }

    /* --- Total column header: gold accent text on dark bg --- */
    .ct-table .ct-th.bg-total .ct-header-text {
      color: #e8c56d !important;
    }

    /* --- Base row: understated, structural --- */
    .ct-row-base { background: #f8f9fa; }
    .ct-row-base .ct-td {
      font-weight: 600;
      font-size: 12px;
      color: #64748b;
      border-bottom: 2px solid #e2e8f0;
      border-top: none;
      padding-top: 8px;
      padding-bottom: 8px;
    }
    .ct-row-base .ct-td.ct-label-col {
      background: #f8f9fa;
      color: #64748b;
      font-size: 12px;
      letter-spacing: 0.3px;
    }

    /* --- NET rows: warm tint, strong --- */
    .ct-row-net { background: #faf8f5; }
    .ct-row-net .ct-td { font-weight: 600; color: #1e293b; }
    .ct-row-net .ct-label-col {
      font-weight: 700;
      color: #1e293b;
      background: #faf8f5;
      border-left: 3px solid BRAND;
      padding-left: 13px;
    }

    /* --- Mean / index rows: subtle distinction --- */
    .ct-row-mean { background: #faf8f4; }
    .ct-row-mean .ct-td { font-style: italic; color: #475569; font-weight: 500; }
    .ct-row-mean .ct-label-col {
      background: #faf8f4;
      font-style: italic;
      border-left: 3px solid #c9a96e;
      padding-left: 13px;
    }

    /* Separator lines between sections */
    .ct-row-category + .ct-row-net > .ct-td { border-top: 2px solid #e2e8f0; }
    .ct-row-net + .ct-row-mean > .ct-td { border-top: 1px solid #e2e8f0; }
    .ct-row-category + .ct-row-mean > .ct-td { border-top: 2px solid #e2e8f0; }

    /* --- Row hover: clear highlight --- */
    tr.ct-row-category:hover > td { background: #eef2f7; }
    tr.ct-row-category:hover > td.ct-label-col { background: #eef2f7; }

    /* --- Row exclusion --- */
    .ct-row-excluded { opacity: 0.3; }
    .ct-row-excluded .ct-label-col { text-decoration: line-through; }
    .ct-label-col .row-exclude-btn {
      display: none; cursor: pointer; border: none; background: none;
      color: #94a3b8; font-size: 12px; margin-left: 4px; padding: 0 2px;
      vertical-align: middle;
    }
    tr.ct-row-category:hover .ct-label-col .row-exclude-btn,
    tr.ct-row-net:hover .ct-label-col .row-exclude-btn { display: inline; }
    tr.ct-row-excluded .ct-label-col .row-exclude-btn { display: inline; color: #dc2626; }

    /* --- Data values --- */
    .ct-val { font-variant-numeric: tabular-nums; color: #334155; }
    .ct-val-net { font-weight: 700; color: #1e293b; }
    .ct-na { color: #d1d5db; font-size: 12px; }
    .ct-base-n { font-variant-numeric: tabular-nums; }
    .ct-low-base { color: #e8614d; font-weight: 700; }
    .ct-mean-val { font-variant-numeric: tabular-nums; }
    .ct-index-desc { font-size: 9px; font-style: normal; color: #94a3b8; font-weight: 400; margin-top: 2px; }

    /* --- Significance markers: refined badge --- */
    .ct-sig {
      display: inline-block;
      font-size: 8px;
      font-weight: 700;
      color: #047857;
      background: rgba(5,150,105,0.1);
      border-radius: 3px;
      padding: 1px 4px;
      margin-left: 3px;
      font-family: ui-monospace, Consolas, monospace;
      vertical-align: middle;
      letter-spacing: 0.3px;
    }

    /* --- Frequency annotations --- */
    .ct-freq {
      display: none;
      font-size: 10px;
      color: #94a3b8;
      margin-top: 2px;
    }
    .show-freq .ct-freq { display: block; }
    .ct-low-base-dim { opacity: 0.45; }
    .ct-heatmap-cell { transition: background-color 0.15s ease; }

    /* Banner group column visibility */
    .bg-total { /* always visible */ }

    /* Last row bottom border */
    .ct-table tbody tr:last-child td {
      border-bottom: none;
      padding-bottom: 10px;
    }

    /* Print button */
    .print-btn {
      padding: 6px 14px;
      border: 1px solid #e2e8f0;
      border-radius: 4px;
      background: #ffffff;
      color: #64748b;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      font-family: inherit;
      transition: all 0.15s;
    }
    .print-btn:hover { background: #f8fafc; color: #1e293b; }

    /* Chart wrapper */
    .chart-wrapper {
      padding: 20px 20px 12px;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      margin-top: 8px;
    }
    .chart-wrapper svg {
      width: 100%;
      max-width: 700px;
      height: auto;
      display: block;
      margin: 0 auto;
    }
    .chart-bar-group { transition: transform 0.3s ease; }

    /* Chart column picker (inside chart-wrapper) */
    .chart-col-picker {
      display: flex; align-items: center; gap: 6px;
      padding: 0 0 12px 0; flex-wrap: wrap;
    }

    /* Column toggle chip bar */
    .col-chip-bar {
      display: flex; align-items: center; gap: 6px;
      padding: 8px 12px; background: #fff;
      border: 1px solid #e2e8f0; border-radius: 6px;
      margin-bottom: 12px; flex-wrap: wrap;
    }
    .col-chip-label {
      font-size: 11px; font-weight: 600; color: #64748b; margin-right: 4px;
    }
    .col-chip {
      padding: 6px 14px; border: 1px solid #e2e8f0; border-radius: 16px;
      background: #f0fafa; color: #1e293b; font-size: 11px; font-weight: 500;
      cursor: pointer; font-family: inherit; transition: all 0.15s;
    }
    .col-chip:hover { border-color: BRAND; }
    .col-chip.active { background: BRAND; color: #ffffff; border-color: BRAND; }
    .col-chip-off {
      background: #f8f9fa; color: #94a3b8;
      text-decoration: line-through; opacity: 0.5;
    }
    .col-chip-off:hover { opacity: 0.7; }
    .col-chip-more { background: #f1f5f9; color: #64748b; border-style: dashed; font-weight: 600; }

    /* Column sort indicators */
    .ct-sort-indicator {
      font-size: 10px; color: #94a3b8; margin-left: 2px;
    }
    .ct-sort-indicator.ct-sort-active {
      color: BRAND; font-weight: 700;
    }
    th.ct-data-col[data-col-key] { cursor: pointer; user-select: none; }
    th.ct-data-col[data-col-key]:hover { background: #eef2f7; }

    /* Key insight callout */
    .insight-area { margin-top: 0; }
    .insight-toggle {
      padding: 6px 14px; border: 1px dashed #cbd5e1; border-radius: 6px;
      background: transparent; color: #94a3b8; font-size: 12px; font-weight: 500;
      cursor: pointer; font-family: inherit; transition: all 0.15s;
      width: 100%;
    }
    .insight-toggle:hover { border-color: BRAND; color: BRAND; }
    .insight-md-editor {
      width: 100%; min-height: 60px; padding: 12px 16px; font-size: 14px;
      border: 1px solid #e2e8f0; border-radius: 6px; font-family: inherit;
      resize: vertical; box-sizing: border-box; line-height: 1.6;
      color: #1e293b; outline: none;
    }
    .insight-md-editor:focus { border-color: BRAND; }
    .insight-md-rendered {
      font-size: 14px; line-height: 1.7; color: #1e293b; padding: 0;
      min-height: 24px; cursor: pointer;
    }
    .insight-md-rendered:empty::after {
      content: "+";
      display: flex;
      align-items: center;
      justify-content: center;
      width: 24px;
      height: 24px;
      border-radius: 50%;
      border: 1.5px dashed #cbd5e1;
      color: #cbd5e1;
      font-size: 14px;
      font-weight: 400;
      font-style: normal;
    }
    .insight-md-rendered h2 { font-size: 15px; font-weight: 600; margin: 8px 0 4px; color: #1e293b; }
    .insight-md-rendered p { margin: 4px 0; }
    .insight-md-rendered blockquote {
      border-left: 3px solid BRAND; padding: 6px 12px; margin: 6px 0;
      background: #f0fafa; font-style: italic; color: #475569;
    }
    .insight-md-rendered ul { padding-left: 20px; margin: 4px 0; }
    .insight-md-rendered li { margin-bottom: 2px; }
    .insight-md-rendered strong { font-weight: 700; }
    .insight-md-rendered em { font-style: italic; }
    .insight-container.editing .insight-md-editor { display: block; }
    .insight-container.editing .insight-md-rendered { display: none; }
    .insight-container:not(.editing) .insight-md-editor { display: none; }
    .insight-dismiss {
      position: absolute; top: 6px; right: 8px; border: none; background: none;
      color: #cbd5e1; font-size: 14px; cursor: pointer; padding: 2px 6px;
      line-height: 1; border-radius: 3px;
    }
    .insight-dismiss:hover { color: #64748b; background: #e2e8f0; }
    /* Edit mode indicator — shows when content has been edited */
    .insight-container.edited::before {
      content: "KEY INSIGHT • edited";
    }
    .insight-container.editing {
      border-left-color: #f59e0b;
    }
    .closing-notes-editor.edited {
      border-color: #f59e0b;
    }
    .closing-notes-editor:focus {
      border-color: BRAND;
      box-shadow: 0 0 0 2px rgba(50,51,103,0.08);
    }
    /* Hover hints for editable content */
    .insight-md-rendered:not(:empty) { cursor: pointer; position: relative; }
    .insight-md-rendered:not(:empty):hover::after {
      content: "Double-click to edit"; position: absolute; top: -2px; right: 4px;
      font-size: 10px; color: #94a3b8; font-weight: 500; pointer-events: none;
    }
    .closing-notes-editor:hover::after {
      content: "Click to edit"; position: absolute; top: 4px; right: 8px;
      font-size: 10px; color: #94a3b8; font-weight: 500; pointer-events: none;
    }
    .closing-notes-editor { position: relative; }
    .insight-container {
      border-left: 3px solid BRAND; background: #f8fafa;
      border-radius: 0 6px 6px 0;
      padding: 14px 20px; position: relative;
    }
    .insight-container::before {
      content: "KEY INSIGHT"; display: block;
      font-size: 9px; font-weight: 700; letter-spacing: 1.5px;
      color: #94a3b8; margin-bottom: 6px;
      font-variant: small-caps;
    }
    /* Help overlay */
    .help-overlay {
      display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.6); z-index: 9999; cursor: pointer;
    }
    .help-overlay.active { display: flex; align-items: center; justify-content: center; }
    .help-card {
      background: #fff; border-radius: 12px; padding: 28px 32px; max-width: 640px; width: 92%;
      max-height: 85vh; overflow-y: auto;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3); cursor: default;
    }
    .help-card h2 { font-size: 20px; margin-bottom: 4px; color: BRAND; }
    .help-card .help-subtitle { font-size: 12px; color: #94a3b8; margin-bottom: 20px; }
    .help-card h3 {
      font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px;
      color: #94a3b8; margin: 18px 0 8px; padding-top: 14px; border-top: 1px solid #f1f5f9;
    }
    .help-card h3:first-of-type { border-top: none; padding-top: 0; margin-top: 8px; }
    .help-card ul { list-style: none; padding: 0; margin: 0; }
    .help-card li {
      padding: 5px 0; font-size: 13px; color: #374151; line-height: 1.4;
    }
    .help-card .help-key {
      display: inline-block; background: #f1f5f9; border-radius: 4px;
      padding: 2px 8px; font-weight: 600; color: BRAND; margin-right: 8px;
      font-size: 11px; min-width: 100px; text-align: center;
    }
    .help-card .help-dismiss {
      margin-top: 18px; text-align: center; color: #94a3b8; font-size: 12px;
    }
    .help-section { transition: opacity 0.2s; }
    .help-card .help-tip {
      font-size: 12px; color: #64748b; background: #f8fafc; border-radius: 6px;
      padding: 10px 14px; margin-top: 14px; line-height: 1.5;
    }
    .help-card .help-tip strong { color: BRAND; }
  '

  css_closing <- '
    /* === CLOSING SECTION (V10.7.0) === */
    .closing-section {
      max-width: 1400px; margin: 32px auto 0; padding: 0 32px 32px;
    }
    .closing-divider {
      height: 1px; background: #e2e8f0; margin-bottom: 24px;
    }
    .closing-content {
      background: #f8fafc; border-radius: 8px; padding: 24px;
      border: 1px solid #e2e8f0;
    }
    .closing-contact-grid {
      display: flex; gap: 32px; flex-wrap: wrap; margin-bottom: 16px;
    }
    .closing-contact-item { display: flex; flex-direction: column; }
    .closing-label {
      font-size: 10px; font-weight: 700; text-transform: uppercase;
      letter-spacing: 0.5px; color: #94a3b8; margin-bottom: 2px;
    }
    .closing-value { font-size: 14px; color: #1e293b; font-weight: 500; }
    .closing-link { color: BRAND; text-decoration: none; }
    .closing-link:hover { text-decoration: underline; }
    .closing-verbatim {
      display: flex; flex-direction: column; margin-bottom: 16px;
      padding: 12px 16px; background: #fff; border-radius: 6px;
      border: 1px dashed #e2e8f0;
    }
    .closing-notes-section { margin-top: 12px; }
    .closing-notes-editor {
      font-size: 14px; line-height: 1.7; color: #1e293b; padding: 12px;
      background: #fff; border-radius: 6px; border: 1px solid #e2e8f0;
      min-height: 40px; outline: none;
    }
    .closing-notes-editor:empty::before {
      content: attr(data-placeholder); color: #94a3b8;
    }

    /* === PIN MODE POPOVER === */
    .pin-mode-popover {
      background: #fff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.12);
      padding: 4px 0;
      min-width: 190px;
      display: flex;
      flex-direction: column;
      animation: fadeInPopover 0.15s ease;
    }
    @keyframes fadeInPopover {
      from { opacity: 0; transform: translateY(-4px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .pin-mode-title {
      padding: 6px 14px 4px;
      font-size: 10px;
      font-weight: 700;
      color: #94a3b8;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      border-bottom: 1px solid #f1f5f9;
      margin-bottom: 2px;
    }
    .pin-mode-option {
      display: block;
      width: 100%;
      padding: 8px 14px;
      border: none;
      background: none;
      text-align: left;
      font-size: 12px;
      font-weight: 500;
      color: #1e293b;
      cursor: pointer;
      font-family: inherit;
      transition: background 0.1s;
    }
    .pin-mode-option:hover {
      background: #f0f4f8;
      color: BRAND;
    }
    .pin-mode-option:last-child { border-radius: 0 0 8px 8px; }
    .pin-mode-disabled { color: #cbd5e1; cursor: default; }
    .pin-mode-disabled:hover { background: none; color: #cbd5e1; }
  '

  css_qualitative <- '
    /* === QUALITATIVE SLIDES (V10.7.0) === */
    .qual-slide-card {
      background: #fff; border: 1px solid #e2e8f0; border-radius: 8px;
      padding: 20px; margin-bottom: 16px;
    }
    .qual-slide-header {
      display: flex; align-items: flex-start; justify-content: space-between;
      margin-bottom: 12px;
    }
    .qual-slide-title {
      font-size: 16px; font-weight: 600; color: #1e293b;
      outline: none; min-width: 200px; border-bottom: 1px dashed transparent;
    }
    .qual-slide-title:focus { border-bottom-color: #e2e8f0; }
    .qual-slide-actions { display: flex; gap: 4px; flex-shrink: 0; }
    .qual-img-preview {
      position: relative; display: inline-block; margin-bottom: 12px;
      border: 1px solid #e2e8f0; border-radius: 6px; overflow: hidden;
      max-width: 100%;
    }
    .qual-img-thumb {
      display: block; max-width: 100%; max-height: 300px; object-fit: contain;
    }
    .qual-img-remove {
      position: absolute; top: 6px; right: 6px; width: 24px; height: 24px;
      border-radius: 50%; border: none; background: rgba(0,0,0,0.5); color: #fff;
      font-size: 16px; line-height: 22px; text-align: center; cursor: pointer;
      opacity: 0; transition: opacity 0.2s;
    }
    .qual-img-preview:hover .qual-img-remove { opacity: 1; }
    .qual-md-editor {
      width: 100%; min-height: 100px; padding: 12px; font-size: 13px;
      border: 1px solid #e2e8f0; border-radius: 6px; font-family: monospace;
      resize: vertical; display: none; box-sizing: border-box;
    }
    .qual-slide-card.editing .qual-md-editor { display: block; }
    .qual-slide-card.editing .qual-md-rendered { display: none; }
    .qual-slide-card:not(.editing) .qual-md-editor { display: none; }
    .qual-md-rendered {
      font-size: 14px; line-height: 1.7; color: #1e293b; padding: 4px 0;
      min-height: 24px; cursor: pointer;
    }
    .qual-md-rendered:empty::after {
      content: "Click to add content";
      color: #cbd5e1;
      font-style: italic;
      font-size: 13px;
    }
    .qual-md-rendered h2 { font-size: 16px; font-weight: 600; margin: 12px 0 6px; color: #1e293b; }
    .qual-md-rendered p { margin: 6px 0; }
    .qual-md-rendered blockquote {
      border-left: 3px solid BRAND; padding: 8px 16px; margin: 8px 0;
      background: #f8fafc; font-style: italic; color: #475569;
    }
    .qual-md-rendered ul { padding-left: 20px; margin: 6px 0; }
    .qual-md-rendered li { margin-bottom: 4px; }
    .qual-md-rendered strong { font-weight: 700; }
    .qual-md-rendered em { font-style: italic; }
  '

  # Replace BRAND and ACCENT placeholders with actual colours
  tabs_css <- paste0(css_layout, css_tables, css_closing, css_qualitative)
  tabs_css <- gsub("ACCENT", ac, tabs_css, fixed = TRUE)
  tabs_css <- gsub("BRAND", bc, tabs_css, fixed = TRUE)

  # Combine: shared base CSS first, then tabs-specific overrides
  css_text <- paste0(base_css, "\n\n/* === TABS MODULE STYLES === */\n", tabs_css)

  htmltools::tags$style(htmltools::HTML(css_text))
}


#' Build Print CSS
#'
#' @return htmltools::tags$style
build_print_css <- function() {
  htmltools::tags$style(htmltools::HTML('
    @page { size: A4 landscape; margin: 10mm 12mm; }

    @media print {
      /* === HIDE INTERACTIVE ELEMENTS === */
      .sidebar, .controls-bar, .table-actions,
      .export-btn, .export-chart-btn, .export-slide-btn, .slide-export-group,
      .slide-menu, .search-box, .pin-btn,
      .toggle-label, .print-btn, .col-chip-bar, .ct-sort-indicator,
      .insight-toggle, .insight-dismiss, .insight-md-editor,
      .dash-md-editor,
      .chart-col-picker, .help-overlay, .help-btn,
      .report-tabs, .row-exclude-btn { display: none !important; }
      .insight-md-rendered, .dash-md-rendered { display: block !important; }

      /* === LAYOUT RESET === */
      body {
        background: white !important;
        font-size: 16px;
        line-height: 1.4;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
      .main-layout {
        display: block !important;
        padding: 0 !important;
        max-width: none !important;
      }
      .content-area {
        width: 100% !important;
        max-width: none !important;
      }

      /* === HEADER - COMPACT === */
      .header {
        padding: 8px 0 6px 0 !important;
        background: none !important;
        border-bottom: 2px solid #1a2744 !important;
        page-break-after: avoid;
      }
      .header-inner {
        max-width: none !important;
      }
      .header-inner * { color: #1a2744 !important; }
      .header-inner div[style*="font-size:13px"][style*="uppercase"] {
        font-size: 11px !important; font-weight: 700 !important;
      }
      .header-title {
        font-size: 16px !important; margin-top: 4px !important;
      }
      .header-inner div[style*="font-size:12px"],
      .header-inner div[style*="font-size:13px"] {
        font-size: 10px !important;
      }
      .header-inner div[style*="width:64px"] {
        width: 32px !important; height: 32px !important;
      }
      .header-logo {
        height: 28px !important; width: 28px !important;
      }

      /* === QUESTION CONTAINERS === */
      .question-container {
        display: block !important;
        page-break-inside: avoid;
        page-break-after: always;
        margin-bottom: 0;
      }
      .question-container:last-child { page-break-after: auto; }

      /* === QUESTION TITLE CARD === */
      .question-title-card {
        padding: 6px 0 !important;
        border: none !important;
        border-bottom: 1px solid #e2e8f0 !important;
        margin-bottom: 8px !important;
        background: none !important;
        border-radius: 0 !important;
      }
      .question-text { font-size: 16px !important; }
      .question-code { font-size: 13px !important; }
      .question-meta { font-size: 11px !important; }

      /* === TABLE WRAPPER === */
      .table-wrapper {
        border: none !important;
        border-radius: 0 !important;
        overflow: visible !important;
      }

      /* === TABLE - DEFAULT TIER (1-6 data columns) === */
      .ct-table {
        font-size: 15px !important;
        width: 100% !important;
        table-layout: auto !important;
      }
      .ct-th {
        font-size: 14px !important;
        padding: 6px 10px !important;
        border-bottom: 2px solid #1a2744 !important;
        background: #f8f9fa !important;
        min-width: 0 !important;
        max-width: none !important;
      }
      .ct-td {
        padding: 5px 10px !important;
        border-bottom: 1px solid #e0e0e0 !important;
        min-width: 0 !important;
        max-width: none !important;
      }
      .ct-th.ct-label-col, .ct-td.ct-label-col {
        position: static !important;
        max-width: none !important;
        text-align: left !important;
      }
      .ct-th { white-space: normal !important; word-wrap: break-word !important; overflow-wrap: break-word !important; }
      .ct-td.ct-label-col { white-space: normal !important; word-wrap: break-word !important; overflow-wrap: break-word !important; }
      .ct-th.ct-label-col { min-width: 200px !important; }
      .ct-td.ct-label-col { font-size: 14px !important; }

      /* === TIER 2: MEDIUM (7-10 data columns) === */
      .ct-table.print-cols-medium { font-size: 14px !important; }
      .print-cols-medium .ct-th { font-size: 13px !important; padding: 5px 8px !important; }
      .print-cols-medium .ct-td { padding: 4px 8px !important; }
      .print-cols-medium .ct-th.ct-label-col { min-width: 180px !important; }
      .print-cols-medium .ct-td.ct-label-col { font-size: 13px !important; }

      /* === TIER 3: COMPACT (11-14 data columns) === */
      .ct-table.print-cols-compact { font-size: 13px !important; }
      .print-cols-compact .ct-th { font-size: 12px !important; padding: 4px 6px !important; }
      .print-cols-compact .ct-td { padding: 3px 6px !important; }
      .print-cols-compact .ct-th.ct-label-col { min-width: 150px !important; }
      .print-cols-compact .ct-td.ct-label-col { font-size: 12px !important; }
      .print-cols-compact .ct-sig { font-size: 8px !important; }

      /* === TIER 4: DENSE (15+ data columns) === */
      .ct-table.print-cols-dense { font-size: 12px !important; }
      .print-cols-dense .ct-th { font-size: 11px !important; padding: 3px 5px !important; }
      .print-cols-dense .ct-td { padding: 3px 5px !important; }
      .print-cols-dense .ct-th.ct-label-col { min-width: 130px !important; }
      .print-cols-dense .ct-td.ct-label-col { font-size: 11px !important; }
      .print-cols-dense .ct-sig { font-size: 7px !important; }
      .print-cols-dense .ct-freq { font-size: 9px !important; }

      /* === SIG BADGES (simplified for print) === */
      .ct-sig {
        font-size: 9px !important;
        background: none !important;
        color: #059669 !important;
        padding: 0 !important;
        margin-left: 2px !important;
      }
      .ct-freq { font-size: 10px !important; color: #666 !important; }

      /* === LOW BASE - ensure visible in print === */
      .ct-low-base-dim { opacity: 1 !important; }

      /* === COLOR PRESERVATION === */
      .ct-heatmap-cell, .ct-row-net, .ct-row-base, .ct-row-mean,
      .ct-th, .banner-tab.active {
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }

      /* === BANNER TAB INDICATOR === */
      .banner-tabs {
        display: flex !important;
        border: none !important;
        background: none !important;
        margin-bottom: 4px !important;
      }
      .banner-tab { display: none !important; }
      .banner-tab.active {
        display: inline-block !important;
        background: #1a2744 !important;
        color: #fff !important;
        font-size: 11px !important;
        padding: 3px 10px !important;
        border-radius: 3px !important;
      }

      /* === CHARTS === */
      .chart-wrapper {
        page-break-inside: avoid;
        margin-top: 8px;
      }

      /* === TABS — JS sets inline display before window.print() === */
      #tab-summary, #tab-crosstabs, #tab-qualitative { display: block !important; }
      #tab-about, #tab-pinned { display: none !important; }

      /* === FOOTER === */
      .footer {
        font-size: 9px !important;
        padding: 4px 0 !important;
        border-top: 1px solid #ccc;
        margin-top: 8px;
      }

      /* === PINNED CARDS === */
      .pinned-card {
        page-break-after: always;
        page-break-inside: avoid;
        border: none !important;
        box-shadow: none !important;
        padding: 16px 0 !important;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
      .pinned-card:last-child { page-break-after: auto; }

      /* === CLOSING SECTION (inside About tab panel) === */
    }
  '))
}
