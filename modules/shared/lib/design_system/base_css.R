# ==============================================================================
# TURAS DESIGN SYSTEM - BASE CSS GENERATOR
# ==============================================================================
# Generates the shared base CSS used by all Turas HTML reports.
# This replaces the duplicated CSS reset, typography, and common component
# styles that were previously defined independently in each module.
#
# Each module's page builder calls turas_base_css() and prepends it to
# their module-specific styles. Module-specific styles override as needed.
#
# FUNCTIONS:
# - turas_base_css()        - Complete shared CSS (fonts + tokens + base)
# - turas_typography_css()  - Typography rules only
# - turas_component_css()   - Common component styles (cards, buttons, etc.)
# - turas_callout_css()     - Callout & insight styling
# - turas_print_css()       - Shared print media styles
#
# VERSION: 1.0.0
# ==============================================================================


#' Generate Complete Turas Base CSS
#'
#' Returns the full shared CSS string: font-face declarations, CSS custom
#' properties, typography, common components, callouts, and print styles.
#' Each module prepends this to their own stylesheet.
#'
#' @param brand_colour Character. Module brand hex colour
#' @param accent_colour Character. Module accent colour
#' @param prefix Character. CSS variable prefix (default "t")
#' @param include_font Logical. Whether to include embedded Inter font
#'   (default TRUE). Set FALSE if font is already loaded (e.g., in hub
#'   where the shell provides it).
#' @return Character string of CSS
#' @export
turas_base_css <- function(brand_colour = "#323367",
                           accent_colour = "#CC9900",
                           prefix = "t",
                           include_font = TRUE) {

  parts <- c()

  # 1. Font face (if requested)
  if (include_font) {
    font_css <- tryCatch(
      turas_font_face_css(),
      error = function(e) "/* Font embed unavailable - using system fallback */"
    )
    parts <- c(parts, font_css)
  }

  # 2. CSS custom properties
  parts <- c(parts, turas_css_variables(brand_colour, accent_colour, prefix))

  # 3. Reset & typography
  parts <- c(parts, turas_typography_css(brand_colour))

  # 4. Common components
  parts <- c(parts, turas_component_css(brand_colour, accent_colour))

  # 5. Table system
  parts <- c(parts, turas_table_css())

  # 6. Callout & insight styles
  parts <- c(parts, turas_callout_css(brand_colour))

  # 7. Interaction refinements (progressive disclosure)
  parts <- c(parts, turas_interaction_css(brand_colour))

  # 8. Entry animations
  parts <- c(parts, turas_animation_css())

  # 9. Print styles
  parts <- c(parts, turas_print_css())

  paste(parts, collapse = "\n\n")
}


#' Generate Typography CSS
#'
#' @param brand_colour Character hex colour
#' @return Character CSS string
#' @keywords internal
turas_typography_css <- function(brand_colour = "#323367") {
  sprintf('
    /* === TURAS TYPOGRAPHY === */
    * { margin: 0; padding: 0; box-sizing: border-box; }

    body {
      font-family: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #f8f7f5;
      color: #1e293b;
      line-height: 1.5;
      font-size: 13px;
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
      text-rendering: optimizeLegibility;
      font-feature-settings: "kern" 1, "liga" 1, "calt" 1;
    }

    /* Headings */
    h1, h2, h3, h4, h5, h6 {
      font-family: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      font-weight: 600;
      line-height: 1.25;
      color: #1e293b;
      letter-spacing: -0.2px;
    }

    /* Tabular numbers for data */
    .t-tabular, td, .ct-val, .ct-base-n, .ct-mean-val {
      font-variant-numeric: tabular-nums;
    }

    /* Monospace for codes and badges */
    code, .t-mono, .ct-letter, .ct-sig, .sig-badge-legend {
      font-family: ui-monospace, "SF Mono", Consolas, "Liberation Mono", monospace;
    }

    /* Small caps for labels */
    .t-caps {
      font-size: 10px;
      font-weight: 600;
      letter-spacing: 1.2px;
      text-transform: uppercase;
      color: #94a3b8;
    }

    /* Section labels (above content sections) */
    .t-section-label {
      font-size: 10px;
      font-weight: 600;
      letter-spacing: 1.2px;
      text-transform: uppercase;
      color: #94a3b8;
      margin-bottom: 8px;
    }

    /* Body text */
    p, li {
      line-height: 1.65;
      color: #1e293b;
    }

    /* Links */
    a {
      color: %s;
      text-decoration: none;
    }
    a:hover {
      text-decoration: underline;
    }
  ', brand_colour)
}


#' Generate Common Component CSS
#'
#' Shared styles for cards, buttons, headers, and structural elements
#' used across all modules.
#'
#' @param brand_colour Character hex colour
#' @param accent_colour Character hex colour
#' @return Character CSS string
#' @keywords internal
turas_component_css <- function(brand_colour = "#323367",
                                accent_colour = "#CC9900") {
  sprintf('
    /* === TURAS COMMON COMPONENTS === */

    /* Report header */
    .header, .t-header {
      background: linear-gradient(135deg, #1a2744 0%%, #2a3f5f 100%%);
      padding: 24px 32px;
      border-bottom: 3px solid %s;
    }
    .header-inner, .t-header-inner {
      max-width: 1400px;
      margin: 0 auto;
      font-family: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }

    /* Main layout */
    .main-layout, .t-main-layout {
      max-width: 1400px;
      margin: 0 auto;
      padding: 20px 32px;
      display: flex;
      gap: 24px;
    }

    /* Content cards */
    .t-card {
      background: #ffffff;
      border-radius: 8px;
      border: 1px solid #e2e8f0;
      padding: 20px 24px;
    }

    .t-card-sm {
      background: #ffffff;
      border-radius: 6px;
      border: 1px solid #e2e8f0;
      padding: 14px 16px;
    }

    /* Buttons - primary */
    .t-btn {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 14px;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      background: #ffffff;
      color: #64748b;
      font-size: 12px;
      font-weight: 500;
      cursor: pointer;
      font-family: inherit;
      transition: all 0.15s ease;
      line-height: 1.4;
    }
    .t-btn:hover {
      border-color: %s;
      color: %s;
      background: #f8fafc;
    }

    /* Buttons - ghost (used for toolbar actions) */
    .t-btn-ghost {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 4px 8px;
      border: none;
      border-radius: 4px;
      background: transparent;
      color: #94a3b8;
      font-size: 11px;
      font-weight: 500;
      cursor: pointer;
      font-family: inherit;
      transition: all 0.15s ease;
    }
    .t-btn-ghost:hover {
      background: #f0f4f8;
      color: #64748b;
    }

    /* Stat badge (header stats) */
    .t-stat-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 4px 12px;
      background: rgba(255,255,255,0.1);
      border-radius: 20px;
      font-size: 12px;
      color: rgba(255,255,255,0.85);
      font-weight: 500;
    }

    /* Table wrapper */
    .table-wrapper, .t-table-wrap {
      border-radius: 8px;
      overflow-x: auto;
      border: 1px solid #e2e8f0;
      background: #ffffff;
      -webkit-overflow-scrolling: touch;
    }

    /* Footer */
    .footer, .t-footer {
      margin-top: 16px;
      padding: 16px;
      text-align: center;
      font-size: 10px;
      color: #94a3b8;
      letter-spacing: 0.3px;
    }

    /* Scrollbar styling */
    ::-webkit-scrollbar { width: 6px; height: 6px; }
    ::-webkit-scrollbar-track { background: transparent; }
    ::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 3px; }
    ::-webkit-scrollbar-thumb:hover { background: #94a3b8; }

    /* Pill toggle (checkbox labels) */
    .toggle-label, .t-toggle {
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
      font-weight: 500;
    }
    .toggle-label:hover, .t-toggle:hover { border-color: #94a3b8; }
    .toggle-label:has(input:checked),
    .toggle-label.checked,
    .t-toggle.active {
      background: #f0f4f8;
      border-color: %s;
      color: #1e293b;
    }
    .toggle-label input, .t-toggle input { accent-color: %s; }

    /* Help button */
    .help-btn, .t-help-btn {
      width: 26px;
      height: 26px;
      border-radius: 50%%;
      border: 1.5px solid #cbd5e1;
      background: transparent;
      color: #64748b;
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.15s;
      flex-shrink: 0;
    }
    .help-btn:hover, .t-help-btn:hover {
      border-color: %s;
      color: %s;
    }

    /* Help overlay modal */
    .help-overlay, .t-help-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.5);
      z-index: 10000;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    /* Export button (table actions) */
    .export-btn, .t-export-btn {
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
    .export-btn:hover, .t-export-btn:hover {
      background: #f8fafc;
      color: #1e293b;
    }

    /* Save/print header buttons */
    .t-header-btn {
      background: rgba(255, 255, 255, 0.12);
      color: #fff;
      border: 1px solid rgba(255, 255, 255, 0.2);
      border-radius: 6px;
      padding: 6px 14px;
      font-size: 12px;
      font-weight: 500;
      cursor: pointer;
      transition: background 0.15s ease;
      font-family: inherit;
    }
    .t-header-btn:hover {
      background: rgba(255, 255, 255, 0.22);
    }
  ', brand_colour,
    brand_colour, brand_colour,
    brand_colour, brand_colour,
    brand_colour, brand_colour)
}


#' Generate Callout & Insight CSS
#' Generate Shared Table CSS
#'
#' Standardised table styling applied across all modules. Module-specific
#' CSS can override these defaults as needed. Uses attribute selectors and
#' low-specificity class names so module CSS (with prefixed classes) wins.
#'
#' @return Character CSS string
#' @keywords internal
turas_table_css <- function() {
  '
    /* === TURAS TABLE SYSTEM === */

    /* --- Table container (card wrapper) --- */
    .t-table-wrap {
      background: #ffffff;
      border-radius: 8px;
      border: 1px solid #e2e8f0;
      overflow: hidden;
      margin-bottom: 16px;
    }
    .t-table-scroll {
      overflow-x: auto;
      -webkit-overflow-scrolling: touch;
    }

    /* --- Base table --- */
    table[class*="-table"] {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
      line-height: 1.5;
      font-variant-numeric: tabular-nums;
      -webkit-font-feature-settings: "tnum";
      font-feature-settings: "tnum";
    }

    /* --- Header cells --- */
    table[class*="-table"] thead th,
    th[class*="-th"] {
      padding: 10px 14px;
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.4px;
      color: #64748b;
      background: #f8f9fa;
      border-bottom: 2px solid #e2e8f0;
      text-align: left;
      white-space: nowrap;
      position: relative;
    }

    /* Numeric header alignment */
    th[class*="-th-num"],
    th[class*="-th-val"],
    th[class*="-th-pct"],
    th[class*="-th-score"] {
      text-align: right;
    }
    th[class*="-th-center"] {
      text-align: center;
    }

    /* --- Data cells --- */
    table[class*="-table"] tbody td,
    td[class*="-td"] {
      padding: 8px 14px;
      border-bottom: 1px solid #f0f0f0;
      vertical-align: middle;
      color: #334155;
      transition: background-color 0.15s ease;
    }

    /* Numeric cell alignment */
    td[class*="-num"],
    td[class*="-val"],
    td[class*="-pct"],
    td[class*="-score"] {
      text-align: right;
      font-variant-numeric: tabular-nums;
    }
    td[class*="-center"] {
      text-align: center;
    }

    /* Label column (first column) */
    td[class*="-label"] {
      font-weight: 500;
      color: #1e293b;
    }

    /* --- Row hover --- */
    table[class*="-table"] tbody tr:hover {
      background-color: #f8fafc;
    }

    /* --- Zebra striping (opt-in via .t-striped) --- */
    table.t-striped tbody tr:nth-child(even) {
      background-color: #f9fafb;
    }
    table.t-striped tbody tr:nth-child(even):hover {
      background-color: #f1f5f9;
    }

    /* --- Base row (question label row in crosstabs) --- */
    tr[class*="-row-base"],
    tr[class*="-base-row"] {
      border-top: 2px solid #e2e8f0;
      background: #fafbfc;
    }
    tr[class*="-row-base"] td,
    tr[class*="-base-row"] td {
      font-weight: 600;
      font-size: 11px;
      color: #64748b;
    }

    /* --- Section header rows --- */
    tr[class*="-section-row"] td,
    tr[class*="-row-header"] td {
      font-weight: 600;
      font-size: 12px;
      color: #1e293b;
      padding-top: 14px;
      background: #f8f9fa;
      border-bottom: 2px solid #e2e8f0;
    }

    /* --- Heatmap cells (standardised 4-level scale) --- */
    .t-heat-high, [class*="-heat-high"] {
      background-color: #dcfce7 !important;
      color: #166534;
    }
    .t-heat-med-high, [class*="-heat-med-high"] {
      background-color: #eff6ff !important;
      color: #1e40af;
    }
    .t-heat-med-low, [class*="-heat-med-low"] {
      background-color: #fef3c7 !important;
      color: #92400e;
    }
    .t-heat-low, [class*="-heat-low"] {
      background-color: #fee2e2 !important;
      color: #991b1b;
    }

    /* --- Significance badges --- */
    [class*="-sig"] {
      display: inline-block;
      font-size: 10px;
      font-weight: 600;
      padding: 1px 5px;
      border-radius: 3px;
      margin-left: 4px;
      vertical-align: middle;
      line-height: 1.4;
    }
    [class*="-sig-up"], .t-sig-up {
      background: #dcfce7;
      color: #166534;
    }
    [class*="-sig-down"], .t-sig-down {
      background: #fee2e2;
      color: #991b1b;
    }

    /* --- Status badges --- */
    [class*="-badge"] {
      display: inline-block;
      font-size: 10px;
      font-weight: 600;
      padding: 2px 8px;
      border-radius: 10px;
      letter-spacing: 0.2px;
    }
    [class*="-badge-good"], [class*="-badge-pass"] {
      background: #dcfce7;
      color: #166534;
    }
    [class*="-badge-warn"], [class*="-badge-moderate"] {
      background: #fef3c7;
      color: #92400e;
    }
    [class*="-badge-poor"], [class*="-badge-fail"] {
      background: #fee2e2;
      color: #991b1b;
    }

    /* --- Sortable column headers --- */
    [class*="-sortable"],
    th[data-col-key] {
      cursor: pointer;
      user-select: none;
    }
    [class*="-sortable"]:hover,
    th[data-col-key]:hover {
      background: #eef2f7;
    }
    /* Sort indicator (idle state: ⇅, active: ▲ or ▼) */
    [class*="-sort-indicator"],
    .sort-arrow {
      font-size: 10px;
      color: #94a3b8;
      margin-left: 3px;
      vertical-align: middle;
    }
    [class*="-sort-active"],
    .sort-arrow {
      color: var(--brand, #323367);
      font-weight: 700;
    }
    /* CSS-based sort arrows (tracker pattern) */
    [class*="-sortable"].sort-asc::after {
      content: " \25B2";
      font-size: 9px;
      color: var(--brand, #323367);
    }
    [class*="-sortable"].sort-desc::after {
      content: " \25BC";
      font-size: 9px;
      color: var(--brand, #323367);
    }

    /* --- Low-base dimming --- */
    [class*="-low-base-dim"] {
      opacity: 0.5;
    }
    [class*="-low-base-dim"]:hover {
      opacity: 0.8;
    }

    /* --- Sticky first column (for wide tables) --- */
    [class*="-sticky-col"] {
      position: sticky;
      left: 0;
      z-index: 2;
      background: inherit;
    }

    /* --- Compact table variant --- */
    table.t-compact th {
      padding: 6px 10px;
      font-size: 10px;
    }
    table.t-compact td {
      padding: 5px 10px;
      font-size: 12px;
    }

    /* --- Print table styles --- */
    @media print {
      table[class*="-table"] {
        font-size: 11px;
        page-break-inside: auto;
      }
      table[class*="-table"] tr {
        page-break-inside: avoid;
      }
      table[class*="-table"] tbody tr:hover {
        background-color: transparent;
      }
      [class*="-low-base-dim"] {
        opacity: 0.5 !important;
      }
    }
  '
}


#'
#' Styles for three distinct content types:
#' 1. Callouts (platform-generated educational guidance)
#' 2. Insights (analyst-written commentary, editable)
#' 3. Added slides (externally sourced curated content)
#'
#' @param brand_colour Character hex colour
#' @return Character CSS string
#' @keywords internal
turas_callout_css <- function(brand_colour = "#323367") {
  sprintf('
    /* === CALLOUTS (Platform guidance - not included in pins/exports) === */
    .t-callout {
      background: #f8fafa;
      border-left: 3px solid #94a3b8;
      border-radius: 0 6px 6px 0;
      padding: 14px 18px;
      margin-bottom: 16px;
      position: relative;
    }
    .t-callout-header {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 6px;
      cursor: pointer;
      user-select: none;
    }
    .t-callout-icon {
      width: 18px;
      height: 18px;
      border-radius: 50%%;
      background: #e2e8f0;
      color: #64748b;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 11px;
      font-weight: 700;
      flex-shrink: 0;
    }
    .t-callout-title {
      font-size: 12px;
      font-weight: 600;
      color: #64748b;
      letter-spacing: 0.3px;
    }
    .t-callout-key {
      font-size: 9px;
      font-weight: 500;
      color: #b0b8c4;
      background: #f1f5f9;
      padding: 1px 6px;
      border-radius: 3px;
      letter-spacing: 0.3px;
      white-space: nowrap;
      margin-left: auto;
    }
    .t-callout-chevron {
      font-size: 8px;
      color: #94a3b8;
      transition: transform 0.2s ease;
      flex-shrink: 0;
    }
    .t-callout.collapsed .t-callout-chevron {
      transform: rotate(-90deg);
    }
    .t-callout-body {
      font-size: 13px;
      line-height: 1.65;
      color: #475569;
      overflow: hidden;
      transition: max-height 0.3s ease, opacity 0.2s ease;
    }
    .t-callout.collapsed .t-callout-body {
      max-height: 0;
      opacity: 0;
      margin: 0;
      padding: 0;
    }

    /* === INSIGHTS (Analyst-written, editable, included in pins) === */
    .insight-container, .t-insight {
      border-left: 3px solid %s;
      background: linear-gradient(135deg, #f8fafa 0%%, #fafbfc 100%%);
      border-radius: 0 8px 8px 0;
      padding: 14px 20px;
      margin-bottom: 16px;
      position: relative;
      transition: box-shadow 0.2s ease;
    }
    .insight-container:hover, .t-insight:hover {
      box-shadow: 0 1px 4px rgba(0,0,0,0.04);
    }
    .insight-container::before, .t-insight::before {
      content: "KEY INSIGHT";
      display: block;
      font-size: 9px;
      font-weight: 700;
      letter-spacing: 1.5px;
      color: #94a3b8;
      margin-bottom: 6px;
      font-variant: small-caps;
    }

    /* Insight editor (write mode) */
    .insight-md-editor, .t-insight-editor {
      width: 100%%;
      min-height: 48px;
      padding: 10px 14px;
      font-size: 13px;
      border: 1px dashed transparent;
      border-radius: 6px;
      font-family: inherit;
      resize: vertical;
      box-sizing: border-box;
      line-height: 1.6;
      color: #1e293b;
      outline: none;
      background: transparent;
      transition: border-color 0.15s, background 0.15s;
    }
    .insight-md-editor:hover, .t-insight-editor:hover {
      border-color: #e2e8f0;
      background: rgba(255,255,255,0.5);
    }
    .insight-md-editor:focus, .t-insight-editor:focus {
      border-color: %s;
      background: rgba(255,255,255,0.8);
    }

    /* Insight rendered content (read mode) */
    .insight-md-rendered, .t-insight-rendered {
      font-size: 13px;
      font-weight: 500;
      line-height: 1.6;
      color: #1e293b;
      min-height: 20px;
      cursor: text;
    }
    /* Empty insight - subtle prompt */
    .insight-md-rendered:empty::after,
    .t-insight-rendered:empty::after {
      content: "+";
      display: flex;
      align-items: center;
      justify-content: center;
      width: 24px;
      height: 24px;
      border-radius: 50%%;
      border: 1.5px dashed #cbd5e1;
      color: #cbd5e1;
      font-size: 14px;
      font-weight: 400;
    }

    /* === ADDED SLIDES (External curated content, pinnable) === */
    .qual-slide-card, .t-slide-card {
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 20px 24px;
      margin-bottom: 16px;
      transition: box-shadow 0.15s ease;
    }
    .qual-slide-card:hover, .t-slide-card:hover {
      box-shadow: 0 2px 8px rgba(0,0,0,0.04);
    }
    .qual-slide-title, .t-slide-title {
      font-size: 16px;
      font-weight: 600;
      color: #1e293b;
      border: none;
      background: transparent;
      outline: none;
      width: 100%%;
      margin-bottom: 10px;
      font-family: inherit;
      line-height: 1.3;
    }
    .qual-slide-body, .t-slide-body {
      border: 1px solid transparent;
      border-radius: 6px;
      padding: 10px 14px;
      min-height: 80px;
      font-size: 13px;
      line-height: 1.65;
      outline: none;
      font-family: inherit;
      color: #1e293b;
      transition: border-color 0.15s;
    }
    .qual-slide-body:focus, .t-slide-body:focus {
      border-color: %s;
    }

    /* Slide image container */
    .qual-img-preview, .t-slide-img {
      border-radius: 6px;
      overflow: hidden;
      margin-bottom: 12px;
    }
    .qual-img-preview img, .t-slide-img img {
      max-width: 100%%;
      height: auto;
      display: block;
      border-radius: 4px;
    }

    /* Pinned view cards */
    .pinned-card, .t-pin-card {
      background: #ffffff;
      border: 1px solid #e8e5e0;
      border-radius: 8px;
      padding: 20px 24px;
      margin-bottom: 16px;
      page-break-inside: avoid;
    }
    .pinned-card-title, .t-pin-title {
      font-size: 18px;
      font-weight: 600;
      color: #1e293b;
      margin-bottom: 2px;
    }
    .pinned-card-insight, .t-pin-insight {
      margin-bottom: 12px;
      padding: 14px 20px;
      border-left: 3px solid %s;
      background: linear-gradient(135deg, #f0f5f5 0%%, #f8fafa 100%%);
      border-radius: 0 8px 8px 0;
      font-size: 14px;
      line-height: 1.6;
      color: #1e293b;
    }
  ', brand_colour,
    brand_colour,
    brand_colour,
    brand_colour)
}


#' Generate Interaction CSS
#'
#' Progressive disclosure: controls appear on hover, actions fade in
#' contextually rather than being always visible.
#'
#' @param brand_colour Character hex colour
#' @return Character CSS string
#' @keywords internal
turas_interaction_css <- function(brand_colour = "#323367") {
  sprintf('
    /* === PROGRESSIVE DISCLOSURE === */

    /* Section action buttons (pin, export) - visible on hover */
    .t-section-actions {
      opacity: 0;
      transition: opacity 0.2s ease;
      display: flex;
      gap: 4px;
    }
    .t-section:hover .t-section-actions,
    .t-section:focus-within .t-section-actions {
      opacity: 1;
    }

    /* Row exclude buttons - existing pattern, kept */
    .row-exclude-btn {
      display: none;
      cursor: pointer;
      border: none;
      background: none;
      color: #94a3b8;
      font-size: 12px;
      margin-left: 4px;
      padding: 0 2px;
      vertical-align: middle;
    }
    tr:hover .row-exclude-btn { display: inline; }
    tr.ct-row-excluded .row-exclude-btn { display: inline; color: #dc2626; }

    /* Pin count badge */
    .pin-count-badge, .t-pin-badge {
      display: none;
      margin-left: 4px;
      background: %s;
      color: #fff;
      font-size: 10px;
      padding: 1px 6px;
      border-radius: 8px;
      font-weight: 600;
    }
  ', brand_colour)
}


#' Generate Animation CSS
#'
#' Subtle entry animations for charts and content sections.
#' Pure CSS, degrades gracefully (content simply appears without animation).
#'
#' @return Character CSS string
#' @keywords internal
turas_animation_css <- function() {
  '
    /* === ENTRY ANIMATIONS === */
    @keyframes t-fadeIn {
      from { opacity: 0; transform: translateY(4px); }
      to   { opacity: 1; transform: translateY(0); }
    }
    @keyframes t-barGrow {
      from { transform: scaleX(0); }
      to   { transform: scaleX(1); }
    }
    @keyframes t-barGrowV {
      from { transform: scaleY(0); }
      to   { transform: scaleY(1); }
    }

    /* Applied via class on content sections */
    .t-animate-in {
      animation: t-fadeIn 0.3s ease-out;
    }

    /* Chart bar animation (horizontal) */
    .t-bar-animate {
      animation: t-barGrow 0.4s ease-out;
      transform-origin: left center;
    }

    /* Chart bar animation (vertical) */
    .t-bar-animate-v {
      animation: t-barGrowV 0.4s ease-out;
      transform-origin: center bottom;
    }

    /* Prefer reduced motion */
    @media (prefers-reduced-motion: reduce) {
      .t-animate-in,
      .t-bar-animate,
      .t-bar-animate-v {
        animation: none;
      }
    }
  '
}


#' Generate Print CSS
#'
#' Shared @media print styles for clean PDF/print output.
#' Hides interactive controls, sets white backgrounds.
#'
#' @return Character CSS string
#' @keywords internal
turas_print_css <- function() {
  '
    /* === PRINT STYLES === */
    @media print {
      body { background: #ffffff; }
      .header, .t-header { background: #1a2744 !important; -webkit-print-color-adjust: exact; print-color-adjust: exact; }

      /* Hide interactive elements */
      .sidebar, .search-box, .controls-bar, .banner-tabs,
      .toggle-label, .export-btn, .help-btn, .help-overlay,
      .t-section-actions, .row-exclude-btn, .pin-count-badge,
      .t-callout, .report-tabs, .t-toggle, .t-btn,
      .table-actions, .print-btn { display: none !important; }

      /* Clean backgrounds */
      .main-layout, .t-main-layout { max-width: 100%; padding: 0 20px; }
      .content-area { width: 100%; }

      /* Show all question containers for print */
      .question-container { display: block !important; page-break-inside: avoid; }
      .pinned-card, .t-pin-card { page-break-inside: avoid; }

      /* Disable animations */
      * { animation: none !important; transition: none !important; }
    }
  '
}
