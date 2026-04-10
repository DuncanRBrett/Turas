# ==============================================================================
# HTML REPORT - DASHBOARD STYLING (V10.8)
# ==============================================================================
# CSS and colour system for the summary dashboard.
# Extracted from 06_dashboard_builder.R for modularity.
#
# FUNCTIONS:
# - build_dashboard_css() - Dashboard CSS with brand colour substitution
# - get_gauge_colour() - Value → traffic light hex colour
# - get_heatmap_bg_style() - Value → inline CSS background style
# - get_heatmap_tier() - Value → tier string ("green"/"amber"/"red")
#
# DEPENDENCIES: None (pure CSS/colour generation)
# ==============================================================================

# ==============================================================================
# COMPONENT: DASHBOARD CSS
# ==============================================================================

#' Build Dashboard CSS
#'
#' @param brand_colour Character hex colour
#' @return htmltools::tags$style
#' @export
build_dashboard_css <- function(brand_colour) {

  bc <- brand_colour %||% "#323367"

  css_text <- '
    /* === REPORT TAB NAVIGATION === */
    .report-tabs {
      display: flex; align-items: center; gap: 0; max-width: 1400px; margin: 0 auto;
      padding: 0 32px; background: #fff;
      border-bottom: 1px solid #e2e8f0;
      position: sticky; top: 0; z-index: 60;
    }
    .report-tab {
      padding: 12px 20px 10px; font-size: 14px; font-weight: 500;
      color: #64748b; background: none; border: none;
      cursor: pointer; border-bottom: 3px solid transparent;
      transition: color 0.15s ease, border-color 0.15s ease;
      white-space: nowrap;
    }
    .report-tab:hover { color: #1e293b; }
    .report-tab.active {
      color: BRAND; border-bottom-color: BRAND;
    }
    .tab-panel { display: none; }
    .tab-panel.active { display: block; }

    /* === DASHBOARD CONTAINER === */
    .dash-container {
      max-width: 1400px; margin: 0 auto; padding: 24px 32px;
    }
    .dash-section { margin-bottom: 24px; }
    .dash-section-title {
      font-size: 14px; font-weight: 700; color: #1a2744;
      margin-bottom: 4px; padding-bottom: 6px;
      border-bottom: 2px solid #e2e8f0;
    }
    .dash-section-sub {
      font-size: 12px; color: #94a3b8; margin-bottom: 16px;
    }
    .dash-empty-msg {
      background: #fef3cd; border: 1px solid #ffc107; border-radius: 8px;
      padding: 20px; font-size: 13px; color: #664d03; margin: 24px 0;
    }
    .dash-footer-note {
      text-align: center; padding: 16px; font-size: 12px;
      color: #94a3b8; border-top: 1px solid #e2e8f0; margin-top: 8px;
    }

    /* === METADATA STRIP === */
    .dash-meta-strip {
      display: grid; grid-template-columns: repeat(4, 1fr);
      gap: 16px; margin-bottom: 24px;
    }
    .dash-meta-card {
      background: #fff; border-radius: 8px;
      border: 1px solid #e2e8f0; padding: 16px 20px;
      border-left: 4px solid BRAND;
    }
    .dash-meta-value {
      font-size: 24px; font-weight: 700; color: #1a2744;
      font-variant-numeric: tabular-nums;
    }
    .dash-meta-label {
      font-size: 11px; color: #64748b; margin-top: 4px;
      text-transform: uppercase; letter-spacing: 0.5px; font-weight: 600;
    }
    .dash-meta-sub {
      font-size: 11px; color: #94a3b8; margin-top: 4px;
    }

    /* === COLOUR LEGEND === */
    .dash-legend {
      display: flex; align-items: center; gap: 16px; flex-wrap: wrap;
      padding: 10px 16px; margin-bottom: 20px;
      background: #f8fafc; border-radius: 6px; border: 1px solid #e2e8f0;
      font-size: 11px; color: #64748b;
    }
    .dash-legend-title { font-weight: 700; color: #1a2744; }
    .dash-legend-item { display: inline-flex; align-items: center; gap: 5px; }
    .dash-legend-dot {
      width: 10px; height: 10px; border-radius: 50%; display: inline-block;
    }
    .dash-legend-green { background: #4a7c6f; }
    .dash-legend-amber { background: #c9a96e; }
    .dash-legend-red { background: #b85450; }

    /* === GAUGES === */
    .dash-gauges {
      display: flex; flex-wrap: wrap; gap: 16px; margin-bottom: 16px;
    }
    .dash-gauge-card {
      background: #fff; border-radius: 8px; border: 1px solid #e2e8f0;
      padding: 14px 16px; min-width: 170px; flex: 1; max-width: 240px;
      text-align: center; cursor: pointer; transition: all 0.2s;
      position: relative;
    }
    .dash-gauge-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
    .dash-gauge-card.dash-gauge-excluded {
      opacity: 0.3; filter: grayscale(1);
      border-style: dashed;
    }
    .dash-gauge-label {
      font-size: 11px; color: #1e293b; margin-top: 6px; line-height: 1.4;
      white-space: normal; word-wrap: break-word; overflow-wrap: break-word;
    }
    .dash-gauge-qcode {
      font-size: 10px; font-weight: 700; color: BRAND;
      margin-right: 4px;
    }
    .dash-type-badge {
      display: inline-block; font-size: 9px; font-weight: 700;
      padding: 2px 8px; border-radius: 3px; letter-spacing: 0.5px;
      margin-bottom: 6px;
    }
    .dash-type-net_positive { background: rgba(74,124,111,0.1); color: #4a7c6f; }
    .dash-type-nps_score { background: rgba(__BRAND_R__,__BRAND_G__,__BRAND_B__,0.1); color: BRAND; }
    .dash-type-average { background: rgba(201,169,110,0.1); color: #96783a; }
    .dash-type-index { background: rgba(99,102,241,0.1); color: #4f46e5; }
    .dash-type-custom { background: rgba(100,116,139,0.1); color: #475569; }

    /* === CALLOUT BADGES (Best/Worst) === */
    .dash-callout-badge {
      position: absolute; top: 6px; right: 6px;
      font-size: 9px; font-weight: 700; padding: 2px 8px;
      border-radius: 10px; letter-spacing: 0.3px;
    }
    .dash-callout-best {
      background: rgba(74,124,111,0.12); color: #4a7c6f;
      border: 1px solid rgba(74,124,111,0.25);
    }
    .dash-callout-worst {
      background: rgba(184,84,80,0.10); color: #b85450;
      border: 1px solid rgba(184,84,80,0.25);
    }

    /* === HERO CARD (single-metric section) === */
    .dash-gauge-hero {
      max-width: 480px; min-width: 300px;
      display: flex; flex-direction: row; align-items: center;
      gap: 20px; padding: 16px 24px; text-align: left;
    }
    .dash-gauge-hero svg { flex-shrink: 0; }
    .dash-gauge-hero .dash-gauge-label {
      font-size: 13px; margin-top: 0;
    }
    .dash-gauge-hero .dash-type-badge { margin-bottom: 4px; }

    /* === TIER PILLS (section header) === */
    .dash-tier-pill {
      display: inline-block; font-size: 10px; font-weight: 600;
      padding: 2px 10px; border-radius: 10px; margin-left: 8px;
      vertical-align: middle;
    }
    .dash-tier-green {
      background: rgba(74,124,111,0.10); color: #4a7c6f;
    }
    .dash-tier-amber {
      background: rgba(201,169,110,0.10); color: #96783a;
    }
    .dash-tier-red {
      background: rgba(184,84,80,0.10); color: #b85450;
    }

    /* === RANK INDICATOR === */
    .dash-gauge-rank {
      position: absolute; bottom: 6px; right: 8px;
      font-size: 10px; font-weight: 700; color: #cbd5e1;
      font-variant-numeric: tabular-nums;
    }

    /* === SORT TOGGLE === */
    .dash-sort-btn { font-size: 11px; padding: 4px 10px; }

    /* === DASHBOARD TEXT BOXES === */
    .dash-text-box {
      background: #fff; border-radius: 8px; border: 1px solid #e2e8f0;
      padding: 14px 18px; margin-bottom: 16px;
    }
    .dash-text-box-header {
      display: flex; justify-content: space-between; align-items: center;
      margin-bottom: 8px;
    }
    .dash-text-box-title {
      font-size: 12px; font-weight: 700; color: #1a2744;
      text-transform: uppercase; letter-spacing: 0.5px;
    }
    .dash-text-content { position: relative; }
    .dash-md-editor {
      width: 100%; min-height: 80px; padding: 10px 12px; font-size: 14px;
      line-height: 1.6; color: #1e293b; border: 1px solid #e2e8f0;
      border-radius: 6px; outline: none; font-family: inherit;
      resize: vertical; box-sizing: border-box;
    }
    .dash-md-editor:focus {
      border-color: BRAND; box-shadow: 0 0 0 2px rgba(__BRAND_R__,__BRAND_G__,__BRAND_B__,0.08);
    }
    .dash-md-rendered {
      font-size: 14px; line-height: 1.7; color: #1e293b; padding: 4px 0;
      min-height: 40px; cursor: pointer;
    }
    .dash-md-rendered:empty::after {
      content: "+ Add text";
      display: inline-flex;
      align-items: center;
      padding: 4px 12px;
      border-radius: 20px;
      border: 1.5px dashed #cbd5e1;
      color: #94a3b8;
      font-size: 12px;
      font-weight: 400;
      font-style: normal;
      cursor: pointer;
    }
    .dash-md-rendered h2 { font-size: 15px; font-weight: 600; margin: 10px 0 5px; color: #1e293b; }
    .dash-md-rendered p { margin: 5px 0; }
    .dash-md-rendered blockquote {
      border-left: 3px solid BRAND; padding: 6px 12px; margin: 6px 0;
      background: #f8fafc; font-style: italic; color: #475569;
    }
    .dash-md-rendered ul { padding-left: 20px; margin: 5px 0; }
    .dash-md-rendered li { margin-bottom: 3px; }
    .dash-md-rendered strong { font-weight: 700; }
    .dash-md-rendered em { font-style: italic; }
    .dash-text-content.editing .dash-md-editor { display: block; }
    .dash-text-content.editing .dash-md-rendered { display: none; }
    .dash-text-content:not(.editing) .dash-md-editor { display: none; }

    /* === HEATMAP GRID === */
    .dash-heatmap-header {
      display: flex; justify-content: space-between; align-items: center;
      margin-bottom: 4px;
    }
    .dash-collapse-chevron { font-size: 12px; color: #94a3b8; margin-right: 4px; transition: transform 0.2s; }
    .dash-collapsed .dash-heatmap,
    .dash-collapsed .dash-section-sub,
    .dash-collapsed .dash-heatmap-controls { display: none; }
    .dash-collapsed .dash-heatmap-header { margin-bottom: 0; }
    .dash-collapse-hint { display: none; font-size: 12px; color: #94a3b8; margin-left: 6px; font-style: italic; }
    .dash-collapsed .dash-collapse-hint { display: inline; }
    .dash-heatmap-controls {
      display: flex; align-items: center; justify-content: space-between;
      margin-bottom: 8px; flex-wrap: wrap; gap: 8px;
    }
    .dash-heatmap-controls .dash-legend { margin-bottom: 0; flex: 1; }
    .dash-export-btn {
      display: inline-flex; align-items: center; gap: 6px;
      padding: 6px 14px; font-size: 12px; font-weight: 600;
      color: BRAND; background: rgba(__BRAND_R__,__BRAND_G__,__BRAND_B__,0.06);
      border: 1px solid rgba(__BRAND_R__,__BRAND_G__,__BRAND_B__,0.2); border-radius: 6px;
      cursor: pointer; transition: all 0.15s;
    }
    .dash-export-btn:hover {
      background: rgba(__BRAND_R__,__BRAND_G__,__BRAND_B__,0.12); border-color: BRAND;
    }
    .dash-heatmap {
      border-radius: 8px; overflow-x: auto; border: 1px solid #e2e8f0;
      background: #fff; padding-bottom: 2px; margin-bottom: 8px;
    }
    .dash-hm-table {
      width: 100%; border-collapse: collapse; font-size: 12px;
      font-variant-numeric: tabular-nums; margin-bottom: 4px;
    }
    .dash-hm-header1 { border-bottom: 2px solid #1a2744; }
    .dash-hm-header2 { border-bottom: 1px solid #e2e8f0; }
    .dash-hm-th {
      padding: 6px 10px; text-align: center; font-weight: 600;
      font-size: 11px; color: #64748b; white-space: nowrap;
    }
    .dash-hm-group-header {
      font-size: 10px; text-transform: uppercase; letter-spacing: 1px;
      color: BRAND; border-left: 2px solid #e2e8f0;
    }
    .dash-hm-total-header {
      background: rgba(26,39,68,0.04); font-weight: 700; color: #1a2744;
    }
    .dash-hm-td {
      padding: 8px 10px; text-align: center; font-weight: 500;
      border-bottom: 1px solid #e2e8f0; transition: background 0.15s;
    }
    .dash-hm-td.dash-hm-label {
      text-align: left; min-width: 240px; max-width: 400px;
      font-weight: 500; color: #1a2744;
      position: sticky; left: 0; background: #fff; z-index: 1;
      border-right: 1px solid #e2e8f0;
      white-space: normal; word-wrap: break-word; overflow-wrap: break-word;
      line-height: 1.4;
    }
    .dash-hm-td.dash-hm-total {
      background: rgba(26,39,68,0.04); font-weight: 700; color: #1a2744;
    }
    .dash-hm-row:hover .dash-hm-td { background: rgba(__BRAND_R__,__BRAND_G__,__BRAND_B__,0.03); }
    .dash-hm-row:hover .dash-hm-td.dash-hm-label { background: rgba(__BRAND_R__,__BRAND_G__,__BRAND_B__,0.03); }
    .dash-hm-row:hover .dash-hm-td.dash-hm-total { background: rgba(26,39,68,0.06); }
    .dash-hm-qcode {
      font-size: 10px; color: BRAND; font-weight: 700; margin-right: 4px;
    }
    .dash-hm-type {
      font-size: 9px; font-weight: 700; padding: 1px 4px; border-radius: 2px;
      background: rgba(100,116,139,0.1); color: #64748b; margin-right: 4px;
    }
    .dash-hm-na { color: #cbd5e1; }

    /* === HEATMAP TIER COLOURS (driven by data-tier attribute) === */
    /* Specificity 0,3,0 matches .dash-hm-row:hover .dash-hm-td so that
       tier colours are preserved on row hover (same as when inline styles
       were used, since inline specificity always won). */
    .dash-hm-row .dash-hm-td[data-tier="green-strong"] {
      background-color: rgba(74,124,111,0.18); color: #4a7c6f; font-weight: 700;
    }
    .dash-hm-row .dash-hm-td[data-tier="green"] {
      background-color: rgba(74,124,111,0.10); color: #4a7c6f;
    }
    .dash-hm-row .dash-hm-td[data-tier="amber"] {
      background-color: rgba(201,169,110,0.15); color: #96783a;
    }
    .dash-hm-row .dash-hm-td[data-tier="red"] {
      background-color: rgba(184,84,80,0.12); color: #b85450;
    }

    /* === SEGMENT FILTER === */
    .sig-segment-filter {
      display: flex; align-items: center; gap: 10px;
      margin-bottom: 12px;
    }
    .sig-filter-label {
      font-size: 11px; font-weight: 700; color: #64748b;
      letter-spacing: 0.5px; text-transform: uppercase;
    }
    .sig-filter-select {
      font-size: 13px; padding: 6px 12px; border: 1px solid #e2e8f0;
      border-radius: 6px; background: #fff; color: #1e293b;
      cursor: pointer; outline: none; min-width: 160px;
    }
    .sig-filter-select:focus { border-color: #94a3b8; }
    .sig-filter-empty {
      padding: 16px 20px; font-size: 13px; color: #94a3b8;
      font-style: italic; text-align: center;
      background: #f8fafc; border-radius: 8px; border: 1px dashed #e2e8f0;
      display: none;
    }

    /* === SIGNIFICANT FINDINGS === */
    .dash-sig-grid {
      display: grid; grid-template-columns: 1fr 1fr; gap: 10px;
    }
    .dash-sig-card {
      background: #fff; border-radius: 8px; border: 1px solid #e2e8f0;
      padding: 12px 16px; border-left: 3px solid #4a7c6f;
      position: relative; transition: opacity 0.2s;
    }
    .dash-sig-card.sig-hidden .sig-card-content { display: none; }
    .dash-sig-card.sig-hidden {
      opacity: 0.4; border-left-color: #cbd5e1; min-height: 32px;
    }
    .sig-card-actions {
      position: absolute; top: 8px; right: 8px; display: flex; gap: 4px;
    }
    .sig-card-actions button {
      background: none; border: 1px solid #e2e8f0; border-radius: 4px;
      padding: 2px 6px; font-size: 11px; cursor: pointer; color: #64748b;
    }
    .sig-card-actions button:hover { border-color: #94a3b8; color: #1e293b; }
    .dash-sig-badges { display: flex; gap: 6px; margin-bottom: 4px; }
    .dash-sig-metric-badge {
      font-size: 9px; font-weight: 700; padding: 2px 6px; border-radius: 3px;
      background: rgba(26,39,68,0.06); color: #1a2744; letter-spacing: 0.5px;
    }
    .dash-sig-group-badge {
      font-size: 9px; font-weight: 600; padding: 2px 6px; border-radius: 3px;
      background: rgba(__BRAND_R__,__BRAND_G__,__BRAND_B__,0.08); color: BRAND;
    }
    .dash-sig-type-badge {
      font-size: 9px; font-weight: 600; padding: 2px 6px; border-radius: 3px;
      background: rgba(201,169,110,0.10); color: #96783a;
    }
    .dash-sig-question {
      font-size: 11px; color: #64748b; line-height: 1.3; margin-bottom: 4px;
      white-space: normal; word-wrap: break-word; overflow-wrap: break-word;
    }
    .dash-sig-text { font-size: 12px; color: #1e293b; line-height: 1.4; }
    .dash-sig-empty {
      padding: 16px 20px; font-size: 13px; color: #94a3b8;
      font-style: italic; text-align: center;
      background: #f8fafc; border-radius: 8px; border: 1px dashed #e2e8f0;
    }

    /* === RESPONSIVE === */
    @media (max-width: 768px) {
      .dash-meta-strip { grid-template-columns: repeat(2, 1fr); }
      .dash-sig-grid { grid-template-columns: 1fr; }
      .dash-container { padding: 16px; }
    }

    /* === PRINT === */
    @page { size: A4 landscape; margin: 10mm 12mm; }
    @media print {
      .dash-export-btn { display: none !important; }
      .dash-container { padding: 12px 0 !important; }
      .dash-section-title { font-size: 16px !important; }
      .dash-gauge-label { font-size: 13px !important; }
      .dash-gauge-value { font-size: 14px !important; }
      .dash-hm-td { font-size: 13px !important; padding: 4px 8px !important; }
      .dash-hm-th { font-size: 12px !important; padding: 4px 8px !important; }
      .dash-meta-value { font-size: 14px !important; }
      .dash-meta-label { font-size: 11px !important; }
      .dash-sig-text { font-size: 13px !important; }
      .dash-gauge-circle, .dash-gauge-card, .dash-hm-td, .dash-meta-card,
      .dash-sig-card, .dash-hm-th, .dash-callout-badge,
      .dash-tier-pill, .dash-type-badge {
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
    }
  '

  # Derive RGB components from brand colour for rgba() values
  # MUST replace __BRAND_R/G/B__ BEFORE bare "BRAND" — otherwise gsub("BRAND",...)
  # corrupts "__BRAND_R__" into "__#323367_R__"
  brand_rgb <- tryCatch(col2rgb(bc)[, 1], error = function(e) c(50, 51, 103))
  css_text <- gsub("__BRAND_R__", brand_rgb[1], css_text, fixed = TRUE)
  css_text <- gsub("__BRAND_G__", brand_rgb[2], css_text, fixed = TRUE)
  css_text <- gsub("__BRAND_B__", brand_rgb[3], css_text, fixed = TRUE)

  css_text <- gsub("BRAND", bc, css_text, fixed = TRUE)

  htmltools::tags$style(htmltools::HTML(css_text))
}


# ==============================================================================
# HELPER FUNCTIONS — CONFIGURABLE TRAFFIC LIGHT COLOUR SYSTEM
# ==============================================================================
# All colour helpers accept a `thresholds` parameter from
# build_colour_thresholds(). Each metric type has:
#   green — value >= this is green
#   amber — value >= this is amber (below green)
#   Below amber is red.
#
# Heatmap uses a 4-tier gradient: strong green (above ~1.15x green),
# light green (at green), amber, red.
# ==============================================================================

#' Get Gauge Colour Based on Value, Metric Type, and Thresholds
#'
#' Traffic light system: green (strong), amber (moderate), red (concern).
#'
#' @param value Numeric
#' @param metric_type Character
#' @param thresholds List from build_colour_thresholds()
#' @return Character hex colour
#' @keywords internal
get_gauge_colour <- function(value, metric_type, thresholds) {
  if (is.na(value)) return("#94a3b8")

  t <- get_thresholds_for_type(metric_type, thresholds)

  if (value >= t$green) return("#4a7c6f")  # Green (muted teal)
  if (value >= t$amber) return("#c9a96e")  # Amber (warm sand)
  return("#b85450")                         # Red (dusty rose)
}



#' Get Heatmap Background Style for a Cell
#'
#' 4-tier gradient for visual richness:
#'   - Strong green: value well above green threshold
#'   - Light green: at or just above green threshold
#'   - Amber: between amber and green
#'   - Red: below amber
#'
#' The "strong green" tier kicks in at ~1.15x the green threshold
#' (or green + 15% of the range above green, depending on metric type).
#'
#' @param value Numeric
#' @param metric_type Character
#' @param thresholds List from build_colour_thresholds()
#' @return Character CSS style string (inline background-color)
#' @keywords internal
get_heatmap_bg_style <- function(value, metric_type, thresholds) {
  if (is.na(value)) return("")

  t <- get_thresholds_for_type(metric_type, thresholds)

  # Compute strong-green cutoff: ~midway between green and scale max
  # For NET: green=30, strong~= green + (100-green)*0.4 = 58
  # For Mean(10): green=7, strong ~= 7 + (10-7)*0.33 = 8
  # For Custom(%): green=60, strong ~= 60 + (100-60)*0.25 = 70
  if (metric_type %in% c("net_positive", "nps_score")) {
    strong_green <- t$green + (100 - t$green) * 0.4
  } else {
    strong_green <- t$green + (t$scale - t$green) * 0.33
  }

  if (value >= strong_green) {
    return("background-color: rgba(74,124,111,0.18); color: #4a7c6f; font-weight: 700;")
  }
  if (value >= t$green) {
    return("background-color: rgba(74,124,111,0.10); color: #4a7c6f;")
  }
  if (value >= t$amber) {
    return("background-color: rgba(201,169,110,0.15); color: #96783a;")
  }
  return("background-color: rgba(184,84,80,0.12); color: #b85450;")
}


#' Get Heatmap Colour Tier for a Cell
#'
#' Returns "green-strong", "green", "amber", or "red" — used as a data-tier
#' attribute for CSS styling and client-side Excel export. The 4-tier system
#' matches the visual heatmap gradient exactly:
#'   - green-strong: value well above green threshold (bold, higher opacity)
#'   - green: at or just above green threshold
#'   - amber: between amber and green thresholds
#'   - red: below amber threshold
#'
#' @param value Numeric
#' @param metric_type Character
#' @param thresholds List from build_colour_thresholds()
#' @return Character: "green-strong", "green", "amber", or "red"
#' @keywords internal
get_heatmap_tier <- function(value, metric_type, thresholds) {
  if (is.na(value)) return("")
  t <- get_thresholds_for_type(metric_type, thresholds)

  if (value >= t$green) {
    # Strong-green cutoff uses same logic as get_heatmap_bg_style()
    if (metric_type %in% c("net_positive", "nps_score")) {
      strong_green <- t$green + (100 - t$green) * 0.4
    } else {
      strong_green <- t$green + (t$scale - t$green) * 0.33
    }
    if (value >= strong_green) return("green-strong")
    return("green")
  }
  if (value >= t$amber) return("amber")
  return("red")
}


