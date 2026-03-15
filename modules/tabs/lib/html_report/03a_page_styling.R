# ==============================================================================
# HTML REPORT - PAGE STYLING (V10.8)
# ==============================================================================
# CSS stylesheet generation for the HTML report.
# Extracted from 03_page_builder.R for modularity.
#
# FUNCTIONS:
# - build_css() - Main CSS stylesheet with brand colour substitution
# - build_print_css() - Print/PDF optimized @media print styles
#
# DEPENDENCIES: None (pure CSS generation, no R function calls)
# ==============================================================================

#' Build CSS Stylesheet
#'
#' @param brand_colour Character hex colour
#' @return htmltools::tags$style
build_css <- function(brand_colour, accent_colour = "#CC9900") {
  # Use gsub instead of sprintf to avoid R's 8192 char format string limit
  bc <- brand_colour
  ac <- accent_colour

  css_layout <- '
    :root {
      --ct-brand: BRAND;
      --brand-colour: BRAND;
      --ct-accent: ACCENT;
      --ct-text-primary: #1e293b;
      --ct-text-secondary: #64748b;
      --ct-bg-surface: #ffffff;
      --ct-bg-muted: #f8f9fa;
      --ct-border: #e2e8f0;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #f8f7f5;
      color: #1e293b;
      line-height: 1.5;
    }
    .header {
      background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
      padding: 24px 32px;
      border-bottom: 3px solid BRAND;
    }
    .header-inner {
      max-width: 1400px;
      margin: 0 auto;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
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
    .content-area { flex: 1; min-width: 0; }
    .controls-bar {
      display: flex;
      align-items: center;
      gap: 16px;
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
    /* ---- Crosstab Table Styles ---- */
    .ct-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
      color: #1e293b;
      table-layout: auto;
    }
    .ct-th {
      padding: 8px 12px;
      text-align: center;
      font-weight: 600;
      font-size: 12px;
      border-bottom: 2px solid #e2e8f0;
      background: #f8f9fa;
      white-space: normal;
      min-width: 80px;
      max-width: 160px;
      vertical-align: bottom;
    }
    .ct-th.ct-label-col {
      text-align: left;
      min-width: 180px;
      max-width: 320px;
      white-space: normal;
      word-wrap: break-word;
      position: sticky;
      left: 0;
      background: #f8f9fa;
      z-index: 2;
    }
    .ct-td {
      padding: 8px 12px;
      text-align: center;
      border-bottom: 1px solid #f0f0f0;
      white-space: nowrap;
      color: #1e293b;
      font-size: 13px;
      transition: background-color 0.15s;
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
    }
    .ct-header-text {
      font-size: 11px;
      line-height: 1.3;
    }
    .ct-letter {
      font-size: 9px;
      color: #94a3b8;
      margin-top: 2px;
      font-weight: 700;
      font-family: ui-monospace, Consolas, monospace;
    }
    .ct-row-base { background: #fafbfc; }
    .ct-row-base .ct-td { font-weight: 600; color: #64748b; border-bottom: 2px solid #e2e8f0; }
    .ct-row-net { background: #f5f3ef; }
    .ct-row-net .ct-label-col { font-weight: 700; color: #1e293b; background: #f5f3ef; }
    .ct-row-mean .ct-label-col { background: #faf8f4; }
    /* Separator line between individual items and NET/summary rows */
    .ct-row-category + .ct-row-net > .ct-td { border-top: 2px solid #cbd5e1; }
    /* Separator line between NET rows and mean/index rows */
    .ct-row-net + .ct-row-mean > .ct-td { border-top: 2px solid #cbd5e1; }
    .ct-row-category + .ct-row-mean > .ct-td { border-top: 2px solid #cbd5e1; }
    .ct-row-mean { background: #faf8f4; }
    .ct-row-mean .ct-td { font-style: italic; color: #475569; }
    /* Row hover */
    tr.ct-row-category:hover td { background: #f8f9fb; }
    tr.ct-row-category:hover td.ct-label-col { background: #f8f9fb; }
    /* Row exclusion from chart */
    .ct-row-excluded { opacity: 0.35; }
    .ct-row-excluded .ct-label-col { text-decoration: line-through; }
    .ct-label-col .row-exclude-btn {
      display: none; cursor: pointer; border: none; background: none;
      color: #94a3b8; font-size: 12px; margin-left: 4px; padding: 0 2px;
      vertical-align: middle;
    }
    tr.ct-row-category:hover .ct-label-col .row-exclude-btn,
    tr.ct-row-net:hover .ct-label-col .row-exclude-btn { display: inline; }
    tr.ct-row-excluded .ct-label-col .row-exclude-btn { display: inline; color: #dc2626; }
    .ct-val { font-variant-numeric: tabular-nums; color: #1e293b; }
    .ct-val-net { font-weight: 700; color: #1e293b; }
    .ct-na { color: #cbd5e1; }
    .ct-base-n { font-variant-numeric: tabular-nums; }
    .ct-low-base { color: #e8614d; font-weight: 700; }
    .ct-mean-val { font-variant-numeric: tabular-nums; }
    .ct-index-desc { font-size: 9px; font-style: normal; color: #94a3b8; font-weight: 400; margin-top: 2px; }
    .ct-sig {
      display: inline-block;
      font-size: 9px;
      font-weight: 700;
      color: #059669;
      background: rgba(5,150,105,0.08);
      border-radius: 3px;
      padding: 0 3px;
      margin-left: 4px;
      font-family: ui-monospace, Consolas, monospace;
      vertical-align: middle;
    }
    .ct-freq {
      display: none;
      font-size: 10px;
      color: #94a3b8;
      margin-top: 1px;
    }
    .show-freq .ct-freq { display: block; }
    .ct-low-base-dim { opacity: 0.45; }
    .ct-heatmap-cell { transition: background-color 0.15s; }

    /* Banner group column visibility - Total always visible */
    .bg-total { /* always visible */ }

    /* Safari fix: ensure last row is fully visible */
    .table-wrapper {
      -webkit-overflow-scrolling: touch;
      padding-bottom: 1px;
    }
    .ct-table tbody tr:last-child td {
      border-bottom: 2px solid #e2e8f0;
      padding-bottom: 8px;
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
      content: "Click to add insight (supports **bold**, *italic*, - bullets, ## headings)";
      color: #b0bec5; font-style: italic;
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
      content: "Double-click to add content..."; color: #94a3b8; font-style: italic;
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
  css_text <- paste0(css_layout, css_tables, css_closing, css_qualitative)
  css_text <- gsub("ACCENT", ac, css_text, fixed = TRUE)
  css_text <- gsub("BRAND", bc, css_text, fixed = TRUE)

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
