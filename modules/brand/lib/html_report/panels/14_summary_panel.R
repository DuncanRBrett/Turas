# ==============================================================================
# BRAND MODULE - EXECUTIVE SUMMARY PANEL
# ==============================================================================
# Per-category executive summary with two dropdowns (Category + Brand) at the
# top. Renders a layered dashboard:
#   1. Category context strip (4 neutral chips: avg purchases / avg brands /
#      top channel / top pack — graceful drop when missing)
#   2. Headline sentence (auto-seeded from metrics)
#   3. Focal strip (5 metric cards with cat-avg under, MMS rank badge)
#   4. Diagnostic strip (Top-3 attribute chips + Top-3 CEP chips with delta)
#   5. Analyst commentary (markdown editor — ported from tracker)
#   6. Closing "all categories at a glance" mini-card strip (core cats only)
#   7. Collapsible educational callout
#
# Data flow: pre-compute a per-(cat, brand) payload in R, embed as JSON, JS
# reads dropdown values + payload to render the dashboard. No re-render of
# heavy chart elements — just card values + chip labels.
#
# JS: js/brand_summary_panel.js
# CSS: build_summary_panel_styles(brand_colour) — injected via panel_styles
# ==============================================================================

BRAND_SUMMARY_PANEL_VERSION <- "1.0"


# ==============================================================================
# PUBLIC: build_brand_summary_panel
# ==============================================================================

#' Build the Executive Summary panel HTML
#'
#' @param results List. Top-level brand results (results$results$categories).
#' @param config List. Brand config.
#'
#' @return Character. Complete summary panel HTML fragment.
#' @export
build_brand_summary_panel <- function(results, config) {
  cats <- results$results$categories %||% list()
  if (length(cats) == 0) return(.brsum_empty_panel())

  deep_cats <- .brsum_deep_cats(cats)
  if (length(deep_cats) == 0) return(.brsum_empty_panel())

  default_cat   <- deep_cats[[1]]
  focal_brand   <- config$focal_brand %||% ""
  focal_colour  <- config$colour_focal %||% "#1A5276"
  brand_colours <- .brsum_brand_colour_map(results, config)

  payload <- .brsum_build_payload(deep_cats, cats, results, config,
                                  brand_colours, focal_colour)
  payload$default_category <- default_cat
  payload$default_brand    <- focal_brand
  payload$focal_colour     <- focal_colour

  json_payload <- .brsum_json(payload)

  closing_strip_html <- .brsum_closing_strip(deep_cats, payload, focal_brand)

  # Wrapper carries the JSON and default selections; JS picks them up on init.
  paste(
    '<div class="br-panel active" id="panel-summary">',
      sprintf('<div class="brsum-root" data-default-cat="%s" data-default-brand="%s" data-focal-colour="%s">',
              .brsum_esc(default_cat), .brsum_esc(focal_brand),
              .brsum_esc(focal_colour)),
        sprintf('<script type="application/json" class="brsum-data">%s</script>',
                json_payload),
        .brsum_header(),
        .brsum_dropdown_bar(payload),
        '<div class="brsum-dashboard" data-brsum-fade>',
          .brsum_focal_context_strip(),
          .brsum_card_grid_skeleton(),
        '</div>',
        .brsum_insight_editor(),
        closing_strip_html,
        .brsum_educational_callout(),
      '</div>',
    '</div>',
    sep = "\n"
  )
}


# ==============================================================================
# PUBLIC: build_summary_panel_styles
# ==============================================================================

#' CSS for the Executive Summary panel
#'
#' @param brand_colour Character. Hex focal-brand colour.
#' @return Character. CSS string.
#' @export
build_summary_panel_styles <- function(brand_colour = "#1A5276") {
  # NOTE: built via gsub template (not sprintf) because the full CSS is
  # >8K chars, which trips R's sprintf 8192-char fmt limit.
  # Single placeholder token: %FOCAL%
  template <- '
.brsum-root { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
  color: #1e293b; width: 100%; }

/* ---- Header ---- */
.brsum-header { margin: 0 0 20px; }
.brsum-eyebrow { font-size: 11px; font-weight: 600; color: #94a3b8;
  text-transform: uppercase; letter-spacing: 0.8px; }
.brsum-title { font-size: 28px; font-weight: 700; color: #0f172a;
  margin: 4px 0 0; line-height: 1.2; letter-spacing: -0.01em; }
.brsum-subtitle { font-size: 14px; color: #64748b; margin: 6px 0 0; }

/* ---- Dropdown bar (sticky) ---- */
.brsum-dropdown-bar { position: sticky; top: 56px; z-index: 30;
  background: #f8f7f5; padding: 14px 0; margin: 0 0 28px;
  border-bottom: 1px solid #e2e8f0;
  display: flex; gap: 20px; flex-wrap: wrap; align-items: center; }
.brsum-dropdown-group { display: flex; align-items: center; gap: 10px; }
.brsum-dropdown-label { font-size: 11px; font-weight: 600; color: #64748b;
  text-transform: uppercase; letter-spacing: 0.5px; }
.brsum-dropdown { font-size: 14px; padding: 9px 14px;
  border: 1px solid #cbd5e1; border-radius: 6px; background: #fff;
  color: #1e293b; cursor: pointer; min-width: 220px; font-weight: 500;
  transition: border-color 0.15s, box-shadow 0.15s; }
.brsum-dropdown:hover { border-color: %FOCAL%; }
.brsum-dropdown:focus { outline: none; border-color: %FOCAL%;
  box-shadow: 0 0 0 3px rgba(26,82,118,0.15); }

/* ---- Dashboard fade ---- */
[data-brsum-fade] { transition: opacity 200ms ease; }
[data-brsum-fade].brsum-fading { opacity: 0; }

/* ---- Strip wrappers (legacy — Analyst commentary + closing strip still use the title style) ---- */
.brsum-strip { margin: 0 0 36px; }
.brsum-strip-title { font-size: 11px; font-weight: 700; color: #475569;
  text-transform: uppercase; letter-spacing: 1px; margin: 0 0 14px;
  display: flex; align-items: center; gap: 10px; }
.brsum-strip-title::after { content: ""; flex: 1; height: 1px;
  background: linear-gradient(to right, #e2e8f0, transparent); }

/* ---- Focal context header strip ---- */
/* Single line at the top of the dashboard naming the focal brand and
   category. Each card below relies on this for context, so cards do not
   repeat the focal name in their headers. */
.brsum-focal-context {
  display: flex; align-items: baseline; gap: 8px;
  padding: 12px 18px; margin: 0 0 18px;
  background: linear-gradient(135deg, %FOCAL% 0%, color-mix(in srgb, %FOCAL% 85%, #1e293b) 100%);
  border-radius: 10px; color: #fff;
  flex-wrap: wrap;
}
.brsum-fc-eyebrow {
  font-size: 9px; font-weight: 700; letter-spacing: 1.4px;
  text-transform: uppercase; color: rgba(255, 255, 255, 0.75);
  background: rgba(255, 255, 255, 0.18);
  padding: 3px 8px; border-radius: 999px;
}
.brsum-fc-brand {
  font-size: 22px; font-weight: 700; letter-spacing: -0.01em;
  color: #fff;
}
.brsum-fc-divider { color: rgba(255, 255, 255, 0.45); font-size: 18px; }
.brsum-fc-cat {
  font-size: 16px; font-weight: 500;
  color: rgba(255, 255, 255, 0.92);
}

/* ---- Card grid (11 cards, 2 per row, full-width spans for dot plots) ---- */
.brsum-card-grid {
  display: grid; grid-template-columns: repeat(2, 1fr); gap: 16px;
  margin: 0 0 28px;
}
.brsum-card-wide { grid-column: 1 / -1; }
.brsum-card {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 10px;
  padding: 16px 18px;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  display: flex; flex-direction: column; min-width: 0;
}
.brsum-card-header {
  display: flex; align-items: baseline; justify-content: space-between;
  gap: 12px; flex-wrap: wrap;
  border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-bottom: 12px;
}
.brsum-card-title {
  font-size: 13px; font-weight: 600; color: #1a2744;
  margin: 0; letter-spacing: 0.1px;
}
.brsum-card-meta {
  font-size: 10px; font-weight: 500; color: #94a3b8;
  font-variant-numeric: tabular-nums;
}
.brsum-card-body { flex: 1 1 auto; min-height: 56px; }
.brsum-card-empty {
  font-size: 12px; color: #94a3b8; font-style: italic;
  padding: 8px 0;
}

/* ---- Stat rows (Category context card) ---- */
.brsum-stat-rows { display: flex; flex-direction: column; gap: 14px; }

.brsum-stat-group { display: flex; flex-direction: column; gap: 4px; }
.brsum-stat-group-head {
  display: flex; align-items: center; gap: 6px;
  font-size: 10px; font-weight: 700; letter-spacing: 0.6px;
  text-transform: uppercase; color: #475569;
  padding-bottom: 4px;
  border-bottom: 1px solid #e2e8f0;
}
.brsum-stat-group-icon {
  width: 14px; height: 14px; display: inline-flex;
  align-items: center; justify-content: center; color: #1A5276;
}
.brsum-stat-group-icon svg { width: 14px; height: 14px; stroke: currentColor; fill: none; }

.brsum-stat-row {
  display: grid; grid-template-columns: 1fr auto; align-items: center;
  column-gap: 12px; padding: 6px 0;
  border-bottom: 1px dashed #f1f5f9;
}
.brsum-stat-group .brsum-stat-row:last-child { border-bottom: 0; }
.brsum-stat-row.is-empty .brsum-stat-value { color: #cbd5e1; }
.brsum-stat-row.is-empty .brsum-stat-sub   { font-style: italic; }

.brsum-stat-label {
  font-size: 12.5px; color: #1e293b; font-weight: 500; line-height: 1.3;
}
.brsum-stat-label-help {
  display: inline-block; width: 12px; height: 12px;
  border-radius: 50%; border: 1px solid #cbd5e1; color: #94a3b8;
  font-size: 9px; font-weight: 700; text-align: center; line-height: 10px;
  margin-left: 4px; cursor: help;
}
.brsum-stat-value {
  display: flex; flex-direction: column; align-items: flex-end;
  font-variant-numeric: tabular-nums;
}
.brsum-stat-value-num {
  font-size: 18px; font-weight: 700; color: #1e293b; line-height: 1.1;
}
.brsum-stat-value-text {
  font-size: 13px; font-weight: 600; color: #1e293b; line-height: 1.2;
  text-align: right;
}
.brsum-stat-sub {
  font-size: 10.5px; color: #94a3b8; font-weight: 500;
  line-height: 1.2; margin-top: 2px;
}

/* ---- Value chips (MA metrics, Brand summary, WOM cards) ---- */
.brsum-vchip-grid {
  display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px;
}
.brsum-vchip-grid-single {
  grid-template-columns: 1fr;
}
.brsum-vchip {
  background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 8px;
  padding: 12px 14px; min-width: 0;
}
.brsum-vchip-label {
  font-size: 10px; font-weight: 600; color: #94a3b8;
  text-transform: uppercase; letter-spacing: 0.5px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.brsum-vchip-value {
  font-size: 26px; font-weight: 700; line-height: 1.1;
  margin: 4px 0 6px; letter-spacing: -0.01em;
  font-variant-numeric: tabular-nums;
}
.brsum-vchip-catavg {
  font-size: 11px; color: #64748b;
}
.brsum-vchip-catavg span {
  color: #334155; font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.brsum-vchip-leader {
  font-size: 10px; color: #94a3b8; margin-top: 4px;
}
.brsum-vchip-leader.brsum-leader-on {
  color: #047857; font-weight: 700; letter-spacing: 0.4px;
  text-transform: uppercase;
}
@media (max-width: 480px) {
  .brsum-vchip-grid { grid-template-columns: 1fr; }
}

/* ---- Word of mouth card (Heard / Said split with positive / negative / net rows) ---- */
.brsum-wom-grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: 14px;
}
.brsum-wom-col {
  display: flex; flex-direction: column;
  border: 1px solid #f1f5f9; border-radius: 8px; padding: 12px;
  background: #fff;
}
.brsum-wom-col-title {
  font-size: 10px; font-weight: 700; letter-spacing: 1px;
  color: #94a3b8; text-transform: uppercase; margin-bottom: 8px;
}
.brsum-wom-row {
  display: grid; grid-template-columns: 1fr auto;
  align-items: center; gap: 12px;
  padding: 10px 0; border-bottom: 1px solid #f1f5f9;
}
.brsum-wom-row:last-child { border-bottom: 0; }
.brsum-wom-label {
  font-size: 13px; color: #1e293b; font-weight: 500;
}
.brsum-wom-vals {
  display: flex; flex-direction: column; align-items: flex-end; gap: 2px;
}
.brsum-wom-val {
  font-size: 22px; font-weight: 700; line-height: 1;
  font-variant-numeric: tabular-nums; color: #1e293b;
  letter-spacing: -0.01em;
}
.brsum-wom-catavg {
  font-size: 10px; color: #64748b;
  font-variant-numeric: tabular-nums;
}
.brsum-wom-pos .brsum-wom-val { color: #15803d; }
.brsum-wom-neg .brsum-wom-val { color: #dc2626; }
.brsum-wom-net {
  background: #f8fafc; border-radius: 6px;
  margin: 4px -8px 0; padding-left: 8px; padding-right: 8px;
  border-bottom: 0;
}
.brsum-wom-net .brsum-wom-label { font-weight: 700; }
.brsum-wom-net .brsum-wom-val { color: #15803d; }
@media (max-width: 480px) {
  .brsum-wom-grid { grid-template-columns: 1fr; }
}

/* ---- Mini-funnel cards (Brand funnel / Brand attitude / Loyalty / Purchase dist) ---- */
/* Two side-by-side cards: focal first, cat avg second. Mirrors the brand
   funnel sub-tab\'s mini-funnel idiom (.fn-mf-*) but scoped to brsum. */
.brsum-mf-row {
  display: flex; gap: 10px; align-items: stretch; flex-wrap: nowrap;
}
.brsum-mf-card {
  flex: 1 1 0; min-width: 0;
  background: #fff; border: 1px solid #e2e8f0; border-radius: 8px;
  border-left: 4px solid #e2e8f0;
  padding: 10px 12px;
}
.brsum-mf-avg { font-style: italic; }
.brsum-mf-title {
  font-size: 11px; font-weight: 700; color: #1e293b; text-align: center;
  margin-bottom: 8px; white-space: nowrap; overflow: hidden;
  text-overflow: ellipsis; font-style: normal;
  display: flex; justify-content: center; align-items: center; gap: 6px;
}
.brsum-mf-badge {
  font-size: 8px; font-weight: 800; letter-spacing: 0.6px;
  background: %FOCAL%; color: #fff;
  padding: 1px 5px; border-radius: 3px;
}
.brsum-mf-stages { display: flex; flex-direction: column; gap: 6px; }
.brsum-mf-stage  { display: flex; flex-direction: column; align-items: center; }
.brsum-mf-bar-bg {
  width: 100%; background: #f1f5f9; border-radius: 3px; height: 16px;
  overflow: hidden;
}
.brsum-mf-bar {
  height: 100%; border-radius: 3px;
  transition: width 0.3s ease;
}
.brsum-mf-label {
  font-size: 9px; color: #94a3b8; text-align: center; margin-top: 2px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  max-width: 100%;
}
.brsum-mf-pct { font-weight: 700; color: #475569;
  font-variant-numeric: tabular-nums; }

/* ---- Duplication of purchase card ---- */
.brsum-dop-grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: 12px;
}
.brsum-dop-coltitle {
  font-size: 11px; font-weight: 600; color: #1a2744; margin-bottom: 6px;
  display: flex; flex-direction: column; gap: 2px;
}
.brsum-dop-hint {
  font-size: 9px; font-weight: 400; color: #94a3b8; font-style: italic;
}
.brsum-dop-list {
  list-style: none; margin: 0; padding: 0;
  display: flex; flex-direction: column; gap: 4px;
}
.brsum-dop-item {
  display: grid; grid-template-columns: 1fr auto auto auto;
  align-items: baseline; gap: 6px;
  padding: 5px 8px; border-radius: 5px; font-size: 11px;
  font-variant-numeric: tabular-nums;
}
.brsum-dop-item.is-partner {
  background: rgba(5, 150, 105, 0.10);
  border: 1px solid rgba(5, 150, 105, 0.25);
}
.brsum-dop-item.is-rival {
  background: rgba(220, 38, 38, 0.08);
  border: 1px solid rgba(220, 38, 38, 0.22);
}
.brsum-dop-brand { font-weight: 600; color: #1e293b; }
.brsum-dop-actual { font-weight: 600; color: #1e293b; }
.brsum-dop-item.is-partner .brsum-dop-dev { font-weight: 700; color: #065f46; }
.brsum-dop-item.is-rival   .brsum-dop-dev { font-weight: 700; color: #991b1b; }
.brsum-dop-vs { font-size: 9px; color: #94a3b8; }
.brsum-dop-empty {
  padding: 5px 8px; font-size: 10px; color: #94a3b8; font-style: italic;
}
@media (max-width: 480px) {
  .brsum-dop-grid { grid-template-columns: 1fr; }
  /* On narrow screens the two mini-funnel cards stack vertically */
  .brsum-mf-row { flex-wrap: wrap; }
  .brsum-mf-card { flex-basis: 100%; }
}

/* ---- Dot plot card (CEP + Brand attributes, full-width) ---- */
.brsum-dot-legend {
  display: flex; align-items: center; gap: 12px;
  font-size: 11px; color: #64748b; margin-bottom: 8px;
}
.brsum-legend-dot {
  display: inline-block; width: 10px; height: 10px; border-radius: 999px;
  vertical-align: middle; margin-right: 4px;
}
.brsum-legend-name { font-weight: 600; color: #334155; margin-right: 4px; }
.brsum-dot-avg-marker {
  display: inline-block; width: 16px; height: 0;
  border-top: 1.5px dashed #94a3b8; vertical-align: middle;
  margin-right: 4px;
}
.brsum-dot-rows {
  display: flex; flex-direction: column; gap: 4px;
  padding: 4px 0;
}
.brsum-dot-row {
  display: grid;
  grid-template-columns: minmax(180px, 24%) 1fr 50px minmax(120px, auto);
  align-items: center; gap: 12px; min-height: 22px;
}
.brsum-dot-stim {
  font-size: 11px; font-weight: 600; color: #1e293b;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.brsum-dot-lane {
  position: relative; height: 22px;
}
.brsum-dot-track {
  position: absolute; left: 0; right: 0; top: 50%;
  height: 1px; background: #eef2f7; transform: translateY(-50%);
}
.brsum-dot-avg {
  position: absolute; top: 50%; transform: translate(-50%, -50%);
  width: 0; height: 14px;
  border-left: 1.5px dashed #94a3b8;
  pointer-events: visible;
}
.brsum-dot-focal {
  position: absolute; top: 50%; transform: translate(-50%, -50%);
  width: 11px; height: 11px; border-radius: 999px;
  background: #1A5276; border: 1.5px solid #fff;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.18);
  pointer-events: visible;
}
.brsum-dot-val {
  font-size: 11px; font-weight: 700;
  font-variant-numeric: tabular-nums; text-align: right;
}
.brsum-dot-meta { display: flex; justify-content: flex-end; }
.brsum-dec-badge {
  font-size: 9px; font-weight: 700; letter-spacing: 0.4px;
  text-transform: uppercase; padding: 3px 8px; border-radius: 999px;
  white-space: nowrap;
}
.brsum-dec-badge em {
  font-style: normal; font-weight: 600; opacity: 0.85;
}
.brsum-dec-defend {
  background: #dcfce7; color: #166534; border: 1px solid #86efac;
}
.brsum-dec-build {
  background: #fee2e2; color: #991b1b; border: 1px solid #fca5a5;
}
.brsum-dec-maintain {
  background: #f1f5f9; color: #475569; border: 1px solid #cbd5e1;
}
.brsum-dec-amplify {
  background: #fef3c7; color: #92400e; border: 1px solid #fcd34d;
}
.brsum-dec-na, .brsum-dec-skip {
  background: #f8fafc; color: #94a3b8; border: 1px solid #e2e8f0;
}
.brsum-dot-axis {
  position: relative; height: 16px; margin-top: 6px;
  margin-left: calc(180px + 12px); /* align to lane */
  margin-right: calc(50px + 120px + 24px);
  border-top: 1px solid #f1f5f9;
}
.brsum-dot-tick {
  position: absolute; top: 4px; transform: translateX(-50%);
  font-size: 9px; color: #94a3b8;
  font-variant-numeric: tabular-nums;
}
@media (max-width: 720px) {
  .brsum-dot-row {
    grid-template-columns: minmax(120px, 30%) 1fr 44px;
    /* hide the decision badge column on narrow screens */
  }
  .brsum-dot-meta { display: none; }
  .brsum-dot-axis { margin-left: calc(120px + 12px); margin-right: calc(44px + 12px); }
}

/* ---- Empty state inherited by chip lists (closing strip uses this) ---- */
.brsum-empty-note { font-size: 12px; color: #94a3b8; font-style: italic; }
.brsum-chip { display: inline-flex; align-items: center; gap: 8px;
  background: #f1f5f9; border: 1px solid #e2e8f0;
  padding: 6px 12px; border-radius: 999px; font-size: 13px;
  color: #1e293b; font-weight: 500; line-height: 1.2; }
.brsum-chip-delta { font-size: 11px; font-weight: 700; color: #0f766e;
  background: #d1fae5; padding: 2px 7px; border-radius: 999px;
  line-height: 1.2; }
.brsum-chip-delta.neg { color: #475569; background: #e2e8f0; }

/* ---- Insight editor (ported from tracker, scoped to brsum) ---- */
.brsum-insight-block { margin: 0 0 36px; }
.brsum-insight-toolbar { display: flex; align-items: center; gap: 6px;
  margin: 0 0 10px; flex-wrap: wrap; }
.brsum-insight-btn { padding: 5px 11px; font-size: 13px;
  background: #fff; border: 1px solid #cbd5e1; border-radius: 5px;
  cursor: pointer; color: #475569; min-width: 30px;
  transition: border-color 0.12s, color 0.12s; }
.brsum-insight-btn:hover { border-color: %FOCAL%; color: %FOCAL%; }
.brsum-insight-hint { font-size: 11px; color: #94a3b8; margin-left: 10px;
  font-style: italic; }
.brsum-insight-editor { width: 100%; min-height: 130px;
  border: 1px solid #cbd5e1; border-radius: 8px; padding: 14px 16px;
  font-size: 14px; line-height: 1.6; color: #1e293b;
  font-family: "SF Mono", "Menlo", "Consolas", monospace;
  resize: vertical; background: #fefefe; box-sizing: border-box; }
.brsum-insight-editor:focus { outline: none; border-color: %FOCAL%;
  box-shadow: 0 0 0 3px rgba(26,82,118,0.12); }
.brsum-insight-rendered { margin-top: 14px; padding: 16px 20px;
  border-left: 3px solid %FOCAL%; background: #f8fafa;
  border-radius: 0 8px 8px 0; font-size: 14px; line-height: 1.6;
  color: #1e293b; }
.brsum-insight-rendered:empty { display: none; }
.brsum-insight-rendered h2 { font-size: 15px; font-weight: 700;
  margin: 8px 0 6px; color: #0f172a; }
.brsum-insight-rendered ul { margin: 6px 0; padding-left: 22px; }
.brsum-insight-rendered blockquote { margin: 6px 0; padding: 4px 14px;
  border-left: 3px solid #cbd5e1; color: #475569; font-style: italic; }

/* ---- Closing strip (mini cards) ---- */
.brsum-closing { margin: 0 0 32px; padding-top: 28px;
  border-top: 1px solid #e2e8f0; }
.brsum-mini-grid { display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
.brsum-mini-card { background: #fff; border: 1px solid #e2e8f0;
  border-radius: 8px; padding: 14px 16px; cursor: pointer;
  transition: border-color 0.15s, transform 0.15s, box-shadow 0.15s; }
.brsum-mini-card:hover { border-color: %FOCAL%; transform: translateY(-1px);
  box-shadow: 0 2px 6px rgba(15,23,42,0.04); }
.brsum-mini-cat { font-size: 12px; font-weight: 600; color: #475569;
  margin: 0 0 10px; line-height: 1.3; }
.brsum-mini-row { display: flex; justify-content: space-between;
  font-size: 11px; color: #475569; margin: 3px 0; }
.brsum-mini-num { font-weight: 700; color: #1e293b; }

/* ---- Educational callout (collapsible) ---- */
.brsum-edu { margin: 48px 0 0; border-top: 1px solid #e2e8f0;
  padding-top: 18px; }
.brsum-edu-toggle { background: none; border: none; cursor: pointer;
  display: flex; align-items: center; gap: 10px;
  font-size: 12px; font-weight: 700; color: #475569;
  text-transform: uppercase; letter-spacing: 0.6px; padding: 6px 0; }
.brsum-edu-toggle:hover { color: %FOCAL%; }
.brsum-edu-arrow { display: inline-block; transition: transform 0.15s;
  font-size: 10px; color: #94a3b8; }
.brsum-edu.open .brsum-edu-arrow { transform: rotate(90deg); }
.brsum-edu-body { display: none; padding: 18px 22px; margin-top: 10px;
  background: #f8fafc; border-left: 3px solid %FOCAL%;
  border-radius: 0 8px 8px 0;
  font-size: 13px; line-height: 1.65; color: #334155; }
.brsum-edu.open .brsum-edu-body { display: block; }
.brsum-edu-body p { margin: 6px 0; }
.brsum-edu-body strong { color: #0f172a; }

/* ---- Responsive collapse ---- */
@media (max-width: 820px) {
  .brsum-card-grid { grid-template-columns: 1fr; }
}
@media (max-width: 600px) {
  .brsum-title { font-size: 22px; }
  .brsum-fc-brand { font-size: 18px; }
  .brsum-fc-cat { font-size: 14px; }
  .brsum-dropdown { min-width: 160px; }
  .brsum-dropdown-bar { position: static; }
}

/* ---- Print ---- */
@media print {
  .brsum-dropdown-bar, .brsum-insight-toolbar, .brsum-edu-toggle {
    display: none !important;
  }
  .brsum-edu-body { display: block !important; }
  [data-brsum-fade] { opacity: 1 !important; }
}
'
  gsub("%FOCAL%", brand_colour, template, fixed = TRUE)
}


# ==============================================================================
# INTERNAL: PAYLOAD CONSTRUCTION
# ==============================================================================

# Filter to "core" / deep-dive categories (those with funnel + MA data).
# Awareness-only categories are excluded from the dashboard's primary view.
.brsum_deep_cats <- function(cats) {
  out <- character(0)
  for (cn in names(cats)) {
    cr <- cats[[cn]]
    has_funnel <- !is.null(cr$funnel) &&
      !identical(cr$funnel$status, "REFUSED")
    has_ma <- !is.null(cr$mental_availability) &&
      !identical(cr$mental_availability$status, "REFUSED")
    if (has_funnel || has_ma) out <- c(out, cn)
  }
  out
}


# Build the JSON payload: per-category context + per-(cat, brand) snapshot.
.brsum_build_payload <- function(deep_cats, cats, results, config,
                                  brand_colours, focal_colour) {
  out <- list(categories = list())
  for (cn in deep_cats) {
    cr <- cats[[cn]]
    label_map <- .brsum_brand_label_map(cr, results, cn)
    brand_codes <- .brsum_brand_codes_for_cat(cr)
    if (length(brand_codes) == 0) next

    # Per-category context (4 chips)
    context <- .brsum_context_for_cat(cr)

    # CEP + attribute label tables for this category (used by diagnostic chips)
    cep_labels  <- .brsum_cep_labels_for_cat(results, cn)
    attr_labels <- .brsum_attr_labels_for_cat(results, cn, cr)

    # Per-brand snapshots
    brands <- list()
    for (bc in brand_codes) {
      brands[[bc]] <- .brsum_brand_snapshot(
        bc, cr, label_map, brand_colours, focal_colour,
        cep_labels = cep_labels, attr_labels = attr_labels,
        cat_name = cn, config = config)
    }

    # Mini-funnel data (per category): each block carries the cat-avg row
    # and a per-brand row map. Visual rendering is JS-side; R just exposes
    # the numbers.
    funnel_block       <- .brsum_funnel_minif(cr, brand_codes, label_map,
                                                config = config)
    attitude_block     <- .brsum_attitude_minif(cr, brand_codes, label_map)
    loyalty_block      <- .brsum_loyalty_minif(cr, brand_codes, label_map,
                                                config = config)
    purchase_block     <- .brsum_purchase_minif(cr, brand_codes, label_map,
                                                 config = config,
                                                 focal_brand = config$focal_brand)
    dop_block          <- .brsum_dop_minif(cr, brand_codes, label_map)
    cep_block          <- .brsum_dotplot_data(cr$mental_availability$cep_advantage,
                                               brand_codes, label_map,
                                               cep_labels,
                                               label_col = "CEPText",
                                               code_col  = "CEPCode")
    attrs_block        <- .brsum_dotplot_data(cr$mental_availability$attribute_advantage,
                                               brand_codes, label_map,
                                               attr_labels,
                                               label_col = "AttrText",
                                               code_col  = "AttrCode")

    out$categories[[cn]] <- list(
      label = cn,
      n_brands = length(brand_codes),
      context = context,
      brand_codes = brand_codes,
      brand_labels = unname(vapply(brand_codes,
                                    function(b) label_map[[b]] %||% b,
                                    character(1))),
      brands = brands,
      funnel        = funnel_block,
      attitude      = attitude_block,
      loyalty       = loyalty_block,
      purchase_dist = purchase_block,
      dop           = dop_block,
      cep           = cep_block,
      attrs         = attrs_block
    )
  }
  out
}


# ==============================================================================
# MINI-FUNNEL DATA HELPERS
# ==============================================================================
# Each helper returns a list with:
#   stage_keys / seg_codes  — character vector of segment IDs in display order
#   stage_labels / seg_labels — display labels
#   seg_colours              — fill colours per segment (only for stacked bars)
#   base_label               — what the percentages are computed against
#   cat_avg                  — numeric vector, one per segment, in 0..1
#   brands                   — named list (brand_code -> numeric vector,
#                              same length as seg_codes, in 0..1)
# JS reads these and renders two stacked rows (focal + cat avg).

# Brand funnel: per-stage % weighted of total respondents. Stage labels
# pull from the same config-driven resolver that the brand-funnel sub-tab
# uses, so the exec summary mini-funnel reads "Past 12 months / Past 3
# months" (etc.) instead of the raw stage_keys.
.brsum_funnel_minif <- function(cr, brand_codes, label_map, config = list()) {
  fn <- cr$funnel
  if (is.null(fn) || identical(fn$status, "REFUSED") ||
      is.null(fn$stages) || nrow(fn$stages) == 0) {
    return(list(available = FALSE))
  }
  st <- fn$stages
  stage_keys <- unique(as.character(st$stage_key))

  # Use the funnel-panel-data label resolver: applies Timeframe_Long /
  # Timeframe_Target overrides (e.g. "Past 12 months", "Past 3 months")
  # and falls back to the canonical stage names ("Aware", "Consider").
  stage_labels <- if (exists(".stage_labels_for", mode = "function")) {
    overrides <- if (exists(".stage_label_overrides", mode = "function"))
      .stage_label_overrides(config) else list()
    .stage_labels_for(stage_keys, overrides = overrides)
  } else {
    stage_keys
  }

  cat_avg <- vapply(stage_keys, function(k) {
    vals <- as.numeric(st$pct_weighted[st$stage_key == k])
    if (length(vals) == 0) NA_real_ else mean(vals, na.rm = TRUE)
  }, numeric(1))

  brands_map <- list()
  for (bc in brand_codes) {
    brands_map[[bc]] <- vapply(stage_keys, function(k) {
      v <- as.numeric(st$pct_weighted[st$stage_key == k & st$brand_code == bc])
      if (length(v) == 1) v else NA_real_
    }, numeric(1))
  }

  n_total <- as.numeric(fn$meta$n_unweighted %||% NA_real_)
  base_label <- .brsum_base_text(n_total, "total_respondents") %||%
    "% of total respondents"

  list(
    available    = TRUE,
    stage_keys   = stage_keys,
    stage_labels = unname(stage_labels),
    base_label   = base_label,
    cat_avg      = unname(cat_avg),
    brands       = brands_map
  )
}

# Brand attitude: 5 segments — Love / Prefer / Ambivalent / Reject /
# No opinion. Reads from cr$funnel$attitude_decomposition (long data
# frame with brand_code, attitude_role, pct columns) — pct is already a
# fraction of total respondents in the engine.
.brsum_attitude_minif <- function(cr, brand_codes, label_map) {
  fn <- cr$funnel
  att <- if (!is.null(fn)) fn$attitude_decomposition else NULL
  if (is.null(att) || !is.data.frame(att) || nrow(att) == 0) {
    return(list(available = FALSE))
  }
  seg_codes <- c("attitude.love", "attitude.prefer", "attitude.ambivalent",
                 "attitude.reject", "attitude.no_opinion")
  seg_labels <- c("Love", "Prefer", "Ambivalent", "Reject", "No opinion")
  seg_colours <- c("#2E7D32", "#81C784", "#F9A825", "#C62828", "#90A4AE")

  att$brand_code    <- as.character(att$brand_code)
  att$attitude_role <- as.character(att$attitude_role)

  brands_map <- list()
  for (bc in brand_codes) {
    sub <- att[att$brand_code == bc, , drop = FALSE]
    vals <- vapply(seg_codes, function(r) {
      hit <- which(sub$attitude_role == r)
      if (length(hit) == 0) return(NA_real_)
      v <- as.numeric(sub$pct[hit[1]])
      if (!is.finite(v)) NA_real_ else v
    }, numeric(1))
    brands_map[[bc]] <- unname(vals)
  }

  cat_avg <- vapply(seq_along(seg_codes), function(i) {
    vals <- vapply(brands_map, function(v) v[i], numeric(1))
    vals <- vals[is.finite(vals)]
    if (length(vals) == 0) NA_real_ else mean(vals)
  }, numeric(1))

  n_total <- as.numeric((cr$funnel$meta$n_unweighted %||%
    if ("base" %in% names(att) && nrow(att) > 0) att$base[1] else NA_real_))
  base_label <- .brsum_base_text(n_total, "total_respondents") %||%
    "% of total respondents"

  list(
    available   = TRUE,
    seg_codes   = seg_codes,
    seg_labels  = seg_labels,
    seg_colours = seg_colours,
    base_label  = base_label,
    cat_avg     = cat_avg,
    brands      = brands_map
  )
}

# Loyalty seg: 4 segments — Sole / Primary / Secondary / Not bought.
# Source values are % of category buyers; each brand's row sums to 100%
# of cat buyers. Cat avg is the unweighted mean per segment across brands.
.brsum_loyalty_minif <- function(cr, brand_codes, label_map, config = list()) {
  bh <- cr$buyer_heaviness
  if (is.null(bh) || identical(bh$status, "REFUSED")) {
    return(list(available = FALSE))
  }
  ls <- bh$brand_loyalty_segments
  if (is.null(ls) || nrow(ls) == 0) return(list(available = FALSE))
  seg_codes  <- c("sole", "primary", "secondary", "nobuy")
  seg_labels <- c("Sole", "Primary (>50% SCR)", "Secondary (≤50%)", "Not bought")
  seg_cols   <- c("Sole_Pct", "Primary_Pct", "Secondary_Pct", "NoBuy_Pct")
  seg_colours <- c("#15803D", "#65A30D", "#F59E0B", "#94A3B8")

  brands_map <- list()
  for (bc in brand_codes) {
    ri <- which(ls$BrandCode == bc)
    if (length(ri) == 1) {
      brands_map[[bc]] <- unname(vapply(seg_cols, function(cn) {
        v <- as.numeric(ls[[cn]][ri])
        if (!is.finite(v)) NA_real_ else v / 100
      }, numeric(1)))
    } else {
      brands_map[[bc]] <- rep(NA_real_, length(seg_codes))
    }
  }
  cat_avg <- vapply(seq_along(seg_codes), function(i) {
    vals <- vapply(brands_map, function(v) v[i], numeric(1))
    vals <- vals[is.finite(vals)]
    if (length(vals) == 0) NA_real_ else mean(vals)
  }, numeric(1))

  n_buy <- as.numeric(cr$dirichlet_norms$category_metrics$n_buyers %||% NA_real_)
  base_label <- .brsum_base_text(
    n_buy, "category_buyers",
    target_months = config$target_timeframe_months,
    longer_months = config$longer_timeframe_months) %||% "% of category buyers"

  list(
    available   = TRUE,
    seg_codes   = seg_codes,
    seg_labels  = seg_labels,
    seg_colours = seg_colours,
    base_label  = base_label,
    cat_avg     = cat_avg,
    brands      = brands_map
  )
}

# Purchase distribution: 4 segments — Light / Moderate / Regular / Frequent.
# Source values are % of brand buyers; each brand's row sums to 100% of
# its own buyers. Cat avg is the unweighted mean per segment across brands.
.brsum_purchase_minif <- function(cr, brand_codes, label_map,
                                    config = list(),
                                    focal_brand = NULL) {
  bh <- cr$buyer_heaviness
  if (is.null(bh) || identical(bh$status, "REFUSED")) {
    return(list(available = FALSE))
  }
  fd <- bh$brand_freq_dist
  if (is.null(fd) || nrow(fd) == 0) return(list(available = FALSE))
  seg_codes  <- c("freq1", "freq2", "freq3to5", "freq6plus")
  seg_labels <- c("Light (1×)", "Moderate (2×)",
                  "Regular (3–5×)", "Frequent (6+×)")
  seg_cols   <- c("Freq1_Pct", "Freq2_Pct", "Freq3to5_Pct", "Freq6plus_Pct")
  seg_colours <- c("#BFDBFE", "#60A5FA", "#2563EB", "#1E3A8A")

  brands_map <- list()
  for (bc in brand_codes) {
    ri <- which(fd$BrandCode == bc)
    if (length(ri) == 1) {
      brands_map[[bc]] <- unname(vapply(seg_cols, function(cn) {
        v <- as.numeric(fd[[cn]][ri])
        if (!is.finite(v)) NA_real_ else v / 100
      }, numeric(1)))
    } else {
      brands_map[[bc]] <- rep(NA_real_, length(seg_codes))
    }
  }

  # Per-brand base label — purchase distribution is "% of THIS brand's
  # buyers", so the n changes with the brand picker. The JS reads
  # base_by_brand[brandCode] when rendering.
  base_by_brand <- list()
  nt <- cr$dirichlet_norms$norms_table
  for (bc in brand_codes) {
    n_bb <- if (!is.null(nt) && "Brand_Buyers_n" %in% names(nt) &&
                bc %in% nt$BrandCode) {
      as.numeric(nt$Brand_Buyers_n[nt$BrandCode == bc])
    } else NA_real_
    base_by_brand[[bc]] <- .brsum_base_text(
      n_bb, "brand_buyers",
      target_months = config$target_timeframe_months,
      brand_label = label_map[[bc]] %||% bc) %||% "% of brand buyers"
  }

  cat_avg <- vapply(seq_along(seg_codes), function(i) {
    vals <- vapply(brands_map, function(v) v[i], numeric(1))
    vals <- vals[is.finite(vals)]
    if (length(vals) == 0) NA_real_ else mean(vals)
  }, numeric(1))

  list(
    available     = TRUE,
    seg_codes     = seg_codes,
    seg_labels    = seg_labels,
    seg_colours   = seg_colours,
    base_label    = base_by_brand[[focal_brand]] %||% "% of brand buyers",
    base_by_brand = base_by_brand,
    cat_avg       = cat_avg,
    brands        = brands_map
  )
}

# Mental Advantage dot plot data — shared between the CEP and the Brand
# attributes cards. Reads the matrix returned by
# calculate_mental_advantage() (advantage / actual / decision matrices)
# and exposes per-stim:
#   - focal_pct   : focal brand's % of n_respondents linking to the stim
#   - cat_avg_pct : unweighted mean across all brands of the % linked
#   - decision    : Defend / Build / Maintain / NA for the focal at that stim
#   - advantage_pp: focal advantage in pp (for the right-hand annotation)
.brsum_dotplot_data <- function(adv, brand_codes, label_map,
                                 labels_df = NULL,
                                 label_col = NULL,
                                 code_col  = NULL) {
  if (is.null(adv) || identical(adv$status, "REFUSED") ||
      is.null(adv$actual) || is.null(adv$advantage) ||
      is.null(adv$stim_codes) || is.null(adv$brand_codes) ||
      length(adv$stim_codes) == 0 || length(adv$brand_codes) == 0) {
    return(list(available = FALSE))
  }
  stims <- as.character(adv$stim_codes)
  bcs   <- as.character(adv$brand_codes)
  n_resp <- as.numeric(adv$n_respondents %||% NA_real_)
  if (!is.finite(n_resp) || n_resp <= 0) return(list(available = FALSE))

  # actual is a counts matrix (stim × brand). Convert to % of n_respondents.
  actual_pct  <- adv$actual / n_resp * 100
  cat_avg_pct <- rowMeans(actual_pct, na.rm = TRUE)

  # Resolve display labels for stims.
  resolve_label <- function(code) {
    if (!is.null(labels_df) && !is.null(code_col) && !is.null(label_col) &&
        code_col %in% names(labels_df) && label_col %in% names(labels_df)) {
      hit <- which(as.character(labels_df[[code_col]]) == code)
      if (length(hit) >= 1) {
        v <- as.character(labels_df[[label_col]][hit[1]])
        if (nzchar(v)) return(v)
      }
    }
    code
  }
  stim_labels <- vapply(stims, resolve_label, character(1))

  brands_map <- list()
  for (bc in brand_codes) {
    if (!bc %in% bcs) {
      brands_map[[bc]] <- list(
        focal_pct      = rep(NA_real_, length(stims)),
        decision       = rep(NA_character_, length(stims)),
        advantage_pp   = rep(NA_real_, length(stims))
      )
      next
    }
    bi <- which(bcs == bc)
    foc_pct  <- as.numeric(actual_pct[, bi])
    adv_pp   <- as.numeric(adv$advantage[, bi])
    dec_vec  <- as.character(adv$decision[, bi])
    # Friendly capitalisation for display
    dec_vec <- ifelse(is.na(dec_vec) | dec_vec == "" | dec_vec == "skip",
                      NA_character_,
                      tools::toTitleCase(tolower(dec_vec)))
    brands_map[[bc]] <- list(
      focal_pct    = foc_pct,
      decision     = dec_vec,
      advantage_pp = adv_pp
    )
  }
  base_label <- .brsum_base_text(n_resp, "total_respondents") %||% ""

  list(
    available   = TRUE,
    stim_codes  = stims,
    stim_labels = unname(stim_labels),
    cat_avg_pct = unname(as.numeric(cat_avg_pct)),
    base_label  = base_label,
    brands      = brands_map
  )
}


# Duplication of purchase: top-3 partition partners + top-3 rivals per
# brand (asymmetric deviation from each column's category average,
# matching the partition-card logic on the DoP sub-tab).
.brsum_dop_minif <- function(cr, brand_codes, label_map) {
  rep <- cr$repertoire
  if (is.null(rep) || identical(rep$status, "REFUSED") ||
      is.null(rep$crossover_matrix) ||
      !"BrandCode" %in% names(rep$crossover_matrix)) {
    return(list(available = FALSE))
  }
  obs <- rep$crossover_matrix
  rows <- as.character(obs$BrandCode)
  if (length(rows) < 3) return(list(available = FALSE))

  # Column averages excluding diagonal.
  col_avgs <- vapply(rows, function(col_b) {
    v <- suppressWarnings(as.numeric(obs[[col_b]]))
    if (length(v) != length(rows)) return(NA_real_)
    diag_idx <- which(rows == col_b)
    if (length(diag_idx) == 1) v[diag_idx] <- NA_real_
    mean(v, na.rm = TRUE)
  }, numeric(1))

  brands_map <- list()
  for (bc in brand_codes) {
    if (!bc %in% rows) {
      brands_map[[bc]] <- list(partners = list(), rivals = list(),
                                weak = TRUE, max_abs_dev = 0)
      next
    }
    fi <- which(rows == bc)
    rec <- lapply(seq_along(rows), function(j) {
      if (j == fi) return(NULL)
      col_b <- rows[j]
      o <- suppressWarnings(as.numeric(obs[fi, col_b]))
      a <- col_avgs[j]
      if (!is.finite(o) || !is.finite(a)) return(NULL)
      list(code = col_b, label = label_map[[col_b]] %||% col_b,
           obs = o, avg = a, dev = o - a)
    })
    rec <- Filter(Negate(is.null), rec)
    devs <- vapply(rec, function(x) x$dev, numeric(1))
    max_abs <- if (length(devs) > 0) max(abs(devs), na.rm = TRUE) else 0

    partners <- rec[order(-devs)]
    partners <- Filter(function(x) x$dev > 0, partners)
    partners <- utils::head(partners, 3L)

    rivals <- rec[order(devs)]
    rivals <- Filter(function(x) x$dev < 0, rivals)
    rivals <- utils::head(rivals, 3L)

    brands_map[[bc]] <- list(
      partners    = partners,
      rivals      = rivals,
      weak        = is.finite(max_abs) && max_abs < 5,
      max_abs_dev = max_abs
    )
  }

  list(available = TRUE, brands = brands_map)
}


# Brand codes from MA (preferred) or funnel.
.brsum_brand_codes_for_cat <- function(cr) {
  if (!is.null(cr$mental_availability$mms$BrandCode)) {
    return(as.character(cr$mental_availability$mms$BrandCode))
  }
  if (!is.null(cr$funnel$stages$brand_code)) {
    return(unique(as.character(cr$funnel$stages$brand_code)))
  }
  character(0)
}


# Map BrandCode -> BrandLabel using whatever sources are reachable. Falls
# back to the code itself when no label is available.
#
# Source priority:
#  1. `results$structure$brands` (Category + BrandCode + BrandLabel) — the
#     canonical label table on the Survey_Structure sheet.
#  2. `results$results$portfolio_overview$categories[[cat_code]]$brand_names`
#     — a named list (BrandCode -> BrandName) keyed by category code, not
#     category name.
.brsum_brand_label_map <- function(cr, results, cat_name) {
  out <- list()

  # Source 1: structure$brands filtered to this category.
  brands_df <- results$structure$brands
  if (!is.null(brands_df) && nrow(brands_df) > 0 &&
      "BrandCode" %in% names(brands_df) &&
      "BrandLabel" %in% names(brands_df)) {
    sub <- if ("Category" %in% names(brands_df)) {
      brands_df[brands_df$Category == cat_name, , drop = FALSE]
    } else brands_df
    for (i in seq_len(nrow(sub))) {
      bc <- as.character(sub$BrandCode[i])
      bl <- as.character(sub$BrandLabel[i])
      if (!is.na(bc) && nzchar(bc) && !is.na(bl) && nzchar(bl)) {
        out[[bc]] <- bl
      }
    }
  }

  # Source 2: portfolio_overview brand_names list, keyed by category CODE.
  # Resolve cat_name -> cat_code via structure$categories (or the brands
  # table itself, which carries CategoryCode).
  cat_code <- NULL
  if (!is.null(brands_df) && "Category" %in% names(brands_df) &&
      "CategoryCode" %in% names(brands_df)) {
    hits <- brands_df$CategoryCode[brands_df$Category == cat_name]
    if (length(hits) > 0) cat_code <- as.character(hits[1])
  }
  pov <- results$results$portfolio_overview
  if (!is.null(cat_code) && !is.null(pov$categories[[cat_code]]$brand_names)) {
    bn <- pov$categories[[cat_code]]$brand_names
    # `brand_names` may be a named list (BrandCode -> BrandName) or a data
    # frame with brand_code + brand_name columns.
    if (is.list(bn) && !is.data.frame(bn) && length(bn) > 0) {
      for (k in names(bn)) {
        if (is.null(out[[k]]) || identical(out[[k]], k)) {
          out[[k]] <- as.character(bn[[k]])
        }
      }
    } else if (is.data.frame(bn) && nrow(bn) > 0 &&
               !is.null(bn$brand_code) && !is.null(bn$brand_name)) {
      for (i in seq_len(nrow(bn))) {
        k <- as.character(bn$brand_code[i])
        if (is.null(out[[k]]) || identical(out[[k]], k)) {
          out[[k]] <- as.character(bn$brand_name[i])
        }
      }
    }
  }

  out
}


# Map BrandCode -> hex colour from config or panel data fallbacks.
.brsum_brand_colour_map <- function(results, config) {
  out <- list()
  bc <- config$brand_colours
  if (is.list(bc) || is.character(bc)) {
    for (k in names(bc)) out[[k]] <- as.character(bc[[k]])
  }
  out
}


# CEP labels for a category (data frame with CEPCode + CEPText). Source:
# `results$structure$ceps` filtered to the category. Returns NULL when the
# structure isn't available so the caller falls back to bare codes.
.brsum_cep_labels_for_cat <- function(results, cat_name) {
  ceps_all <- results$structure$ceps
  if (is.null(ceps_all) || nrow(ceps_all) == 0) return(NULL)
  if ("Category" %in% names(ceps_all)) {
    ceps_all[ceps_all$Category == cat_name, , drop = FALSE]
  } else {
    ceps_all
  }
}


# Attribute labels for a category. First try `results$structure$attributes`
# (raw survey structure); fall back to the MA result's own `attribute_labels`
# data frame (built when attribute_labels were threaded in).
.brsum_attr_labels_for_cat <- function(results, cat_name, cr) {
  attrs_all <- results$structure$attributes
  if (!is.null(attrs_all) && nrow(attrs_all) > 0) {
    if ("Category" %in% names(attrs_all)) {
      sub <- attrs_all[attrs_all$Category == cat_name, , drop = FALSE]
      if (nrow(sub) > 0) return(sub)
    } else {
      return(attrs_all)
    }
  }
  cr$mental_availability$attribute_labels
}


# Per-category context: eight category-level metrics.
# Brand-count metrics (avg # of brands at each funnel stage) sum the
# weighted per-brand penetrations — pct_weighted is in 0..1 so the sum
# is directly the average count of brands per respondent at that stage.
# Avg CEPs per respondent sums cep_penetration percentages and divides
# by 100. Returns NULL fields when the upstream engine didn't run.
.brsum_context_for_cat <- function(cr) {
  ctx <- list(
    avg_aware_brands     = NULL,
    avg_consider_brands  = NULL,
    avg_p12m_brands      = NULL,
    avg_p3m_brands       = NULL,
    avg_ceps             = NULL,
    avg_purchases        = NULL,
    top_channel          = NULL,
    top_pack             = NULL
  )

  # ---- Brand counts per funnel stage (weighted, all-respondents base)
  # Note: pct_weighted is in 0..1 of total respondents, so summing across
  # brands at a stage gives "average # of brands per respondent at that
  # stage" with non-buyers contributing 0. This deliberately differs
  # from repertoire-size on the Buying page (which uses a buyers-only
  # base). The base is surfaced in the row's tooltip so users don't
  # confuse the two reads.
  fn <- cr$funnel
  if (!is.null(fn) && !identical(fn$status, "REFUSED") &&
      !is.null(fn$stages) && nrow(fn$stages) > 0) {
    st <- fn$stages
    .stage_brand_count <- function(key) {
      vals <- as.numeric(st$pct_weighted[st$stage_key == key])
      if (length(vals) == 0) return(NA_real_)
      sum(vals, na.rm = TRUE)
    }
    aware_n <- .stage_brand_count("aware")
    cons_n  <- .stage_brand_count("consideration")
    p12m_n  <- .stage_brand_count("bought_long")
    p3m_n   <- .stage_brand_count("bought_target")
    base_note <- "Base: all respondents (non-buyers count as 0)."
    if (!is.na(aware_n) && is.finite(aware_n))
      ctx$avg_aware_brands <- list(value = sprintf("%.1f", aware_n),
                                    sub = "brands aware",
                                    tooltip = base_note)
    if (!is.na(cons_n) && is.finite(cons_n))
      ctx$avg_consider_brands <- list(value = sprintf("%.1f", cons_n),
                                       sub = "brands considered",
                                       tooltip = base_note)
    if (!is.na(p12m_n) && is.finite(p12m_n))
      ctx$avg_p12m_brands <- list(value = sprintf("%.1f", p12m_n),
                                   sub = "brands bought (long)",
                                   tooltip = paste0(base_note,
                                     " Differs from repertoire size on the Category Buying page, which is computed on category-buyers only."))
    if (!is.na(p3m_n) && is.finite(p3m_n))
      ctx$avg_p3m_brands <- list(value = sprintf("%.1f", p3m_n),
                                  sub = "brands bought (3m)",
                                  tooltip = paste0(base_note,
                                    " Differs from repertoire size on the Category Buying page, which is computed on category-buyers only."))
  }

  # ---- Avg CEPs per respondent
  # cep_penetration carries Penetration_Pct per CEP (0..100); summing
  # gives the average count of CEPs each respondent has linked to *any*
  # brand. Divide by 100 to convert from % share to count.
  ma <- cr$mental_availability
  if (!is.null(ma) && !is.null(ma$cep_penetration) &&
      nrow(ma$cep_penetration) > 0) {
    avg_ceps <- sum(as.numeric(ma$cep_penetration$Penetration_Pct),
                     na.rm = TRUE) / 100
    if (is.finite(avg_ceps))
      ctx$avg_ceps <- list(value = sprintf("%.1f", avg_ceps),
                            sub = "CEPs per respondent",
                            tooltip = "Sum of per-CEP penetration: counts each CEP a respondent linked to any brand.")
  }

  # ---- Avg purchases per respondent in the target period
  cbf <- cr$cat_buying_frequency
  if (!is.null(cbf) && !identical(cbf$status, "REFUSED") &&
      !is.null(cbf$mean_freq) && !is.na(cbf$mean_freq)) {
    ctx$avg_purchases <- list(
      value = sprintf("%.1f", cbf$mean_freq),
      sub   = cbf$frequency_unit %||% "per period",
      tooltip = "Mean purchase frequency from the cat_buying scale; non-buyers count as 0."
    )
  }

  # ---- Top channel (always emit a slot so the row is visible in the
  #      card; missing data renders as "—" rather than disappearing)
  loc <- cr$shopper_location
  if (!is.null(loc) && !identical(loc$status, "REFUSED") &&
      !is.null(loc$top$label) && !is.na(loc$top$label) &&
      nzchar(loc$top$label)) {
    ctx$top_channel <- list(
      value = as.character(loc$top$label),
      sub   = if (!is.null(loc$top$pct) && !is.na(loc$top$pct))
                sprintf("%.0f%% of buyers", loc$top$pct) else "",
      tooltip = "Most frequently picked purchase channel among category buyers."
    )
  } else {
    ctx$top_channel <- list(value = NA_character_, sub = "no shopper data",
                             tooltip = NULL)
  }

  # ---- Top pack
  pak <- cr$shopper_packsize
  if (!is.null(pak) && !identical(pak$status, "REFUSED") &&
      !is.null(pak$top$label) && !is.na(pak$top$label) &&
      nzchar(pak$top$label)) {
    ctx$top_pack <- list(
      value = as.character(pak$top$label),
      sub   = if (!is.null(pak$top$pct) && !is.na(pak$top$pct))
                sprintf("%.0f%% of buyers", pak$top$pct) else "",
      tooltip = "Most frequently picked pack size among category buyers."
    )
  } else {
    ctx$top_pack <- list(value = NA_character_, sub = "no shopper data",
                          tooltip = NULL)
  }

  ctx
}


# Build per-brand snapshot for one category.
.brsum_brand_snapshot <- function(brand_code, cr, label_map,
                                   brand_colours, focal_colour,
                                   cep_labels = NULL, attr_labels = NULL,
                                   cat_name = NA_character_,
                                   config = list()) {
  label <- label_map[[brand_code]] %||% brand_code
  colour <- brand_colours[[brand_code]] %||% focal_colour

  ma <- cr$mental_availability
  fn <- cr$funnel
  rep <- cr$repertoire
  wm <- cr$wom

  # ---- MMS + rank ----
  mms_value <- NA_real_
  mms_cat_avg <- NA_real_
  mms_rank <- NA_integer_
  n_brands <- NA_integer_
  if (!is.null(ma$mms) && nrow(ma$mms) > 0) {
    n_brands <- nrow(ma$mms)
    mms_cat_avg <- mean(ma$mms$MMS, na.rm = TRUE)
    if (brand_code %in% ma$mms$BrandCode) {
      mms_value <- ma$mms$MMS[ma$mms$BrandCode == brand_code]
      mms_rank <- which(order(-ma$mms$MMS) ==
                          which(ma$mms$BrandCode == brand_code))
    }
  }

  # ---- MPen ----
  mpen_value <- NA_real_
  mpen_cat_avg <- NA_real_
  if (!is.null(ma$mpen) && nrow(ma$mpen) > 0) {
    mpen_cat_avg <- mean(ma$mpen$MPen, na.rm = TRUE)
    if (brand_code %in% ma$mpen$BrandCode) {
      mpen_value <- ma$mpen$MPen[ma$mpen$BrandCode == brand_code]
    }
  }

  # ---- Funnel: bought_target ----
  bt_value <- NA_real_
  bt_cat_avg <- NA_real_
  if (!is.null(fn$stages) && nrow(fn$stages) > 0) {
    rows <- fn$stages[fn$stages$stage_key == "bought_target", , drop = FALSE]
    if (nrow(rows) > 0) {
      bt_cat_avg <- mean(rows$pct_weighted, na.rm = TRUE)
      hit <- rows$pct_weighted[rows$brand_code == brand_code]
      if (length(hit) == 1) bt_value <- hit
    }
  }

  # ---- Loyalty (Sole_Pct from repertoire profile) ----
  loy_value <- NA_real_
  loy_cat_avg <- NA_real_
  brp <- rep$brand_repertoire_profile
  if (!is.null(brp) && nrow(brp) > 0 && "Sole_Pct" %in% names(brp)) {
    loy_cat_avg <- mean(brp$Sole_Pct, na.rm = TRUE)
    if (brand_code %in% brp$BrandCode) {
      loy_value <- brp$Sole_Pct[brp$BrandCode == brand_code]
    }
  }

  # ---- Net WOM ----
  net_wom <- NA_real_
  net_wom_cat_avg <- NA_real_
  if (!is.null(wm$net_balance) && nrow(wm$net_balance) > 0 &&
      "Net_Received" %in% names(wm$net_balance)) {
    net_wom_cat_avg <- mean(wm$net_balance$Net_Received, na.rm = TRUE)
    if (brand_code %in% wm$net_balance$BrandCode) {
      net_wom <- wm$net_balance$Net_Received[
        wm$net_balance$BrandCode == brand_code]
    }
  }

  focal_metrics <- list(
    list(
      label = "MMS",
      value = .brsum_pct(mms_value, "%"),
      cat_avg = .brsum_pct(mms_cat_avg, "%"),
      rank = if (!is.na(mms_rank) && !is.na(n_brands))
                sprintf("Rank %d / %d", mms_rank, n_brands) else NA_character_
    ),
    list(label = "MPen", value = .brsum_pct(mpen_value, "%", scale = 100),
         cat_avg = .brsum_pct(mpen_cat_avg, "%", scale = 100), rank = NA_character_),
    list(label = "Bought target",
         value = .brsum_pct(bt_value, "%", scale = 100),
         cat_avg = .brsum_pct(bt_cat_avg, "%", scale = 100), rank = NA_character_),
    list(label = "Loyalty (Sole)",
         value = .brsum_pct(loy_value, "%", already_pct = TRUE),
         cat_avg = .brsum_pct(loy_cat_avg, "%", already_pct = TRUE),
         rank = NA_character_),
    list(label = "Net WOM",
         value = .brsum_signed(net_wom),
         cat_avg = .brsum_signed(net_wom_cat_avg), rank = NA_character_)
  )

  # ---- MA metrics card (4 chips: MPen, NS, MMS, SOM) ----
  # MPen and MMS already computed above. NS comes from ma$ns; SOM is
  # derived (MMS / MPen × 100) per the Romaniuk 2022 definition.
  ns_value   <- NA_real_
  ns_cat_avg <- NA_real_
  ns_leader  <- NA_character_
  if (!is.null(ma$ns) && nrow(ma$ns) > 0 && "NS" %in% names(ma$ns)) {
    ns_cat_avg <- mean(ma$ns$NS, na.rm = TRUE)
    if (brand_code %in% ma$ns$BrandCode)
      ns_value <- ma$ns$NS[ma$ns$BrandCode == brand_code]
    leader_idx <- which.max(ma$ns$NS)
    if (length(leader_idx) == 1)
      ns_leader <- as.character(ma$ns$BrandCode[leader_idx])
  }

  # SOM = MMS / MPen × 100 (share of mind vs share of awareness).
  som_for <- function(mms_v, mpen_v) {
    if (!is.finite(mms_v) || !is.finite(mpen_v) || mpen_v <= 0) NA_real_
    else (mms_v / mpen_v) * 100
  }
  som_value <- som_for(mms_value, mpen_value)
  som_cat_avg <- if (!is.null(ma$mms) && !is.null(ma$mpen) &&
                      nrow(ma$mms) > 0 && nrow(ma$mpen) > 0) {
    mer <- merge(ma$mms[, c("BrandCode", "MMS")],
                 ma$mpen[, c("BrandCode", "MPen")],
                 by = "BrandCode")
    s <- vapply(seq_len(nrow(mer)), function(i)
      som_for(mer$MMS[i], mer$MPen[i]), numeric(1))
    mean(s, na.rm = TRUE)
  } else NA_real_
  som_leader <- if (!is.null(ma$mms) && !is.null(ma$mpen)) {
    mer <- merge(ma$mms[, c("BrandCode", "MMS")],
                 ma$mpen[, c("BrandCode", "MPen")],
                 by = "BrandCode")
    s <- vapply(seq_len(nrow(mer)), function(i)
      som_for(mer$MMS[i], mer$MPen[i]), numeric(1))
    li <- which.max(s)
    if (length(li) == 1) as.character(mer$BrandCode[li]) else NA_character_
  } else NA_character_
  mpen_leader <- if (!is.null(ma$mpen) && nrow(ma$mpen) > 0) {
    li <- which.max(ma$mpen$MPen)
    if (length(li) == 1) as.character(ma$mpen$BrandCode[li]) else NA_character_
  } else NA_character_
  mms_leader <- if (!is.null(ma$mms) && nrow(ma$mms) > 0) {
    li <- which.max(ma$mms$MMS)
    if (length(li) == 1) as.character(ma$mms$BrandCode[li]) else NA_character_
  } else NA_character_

  ma_metrics <- list(
    list(key = "mpen", label = "Mental Penetration (MPen)",
         value = .brsum_pct(mpen_value, "%", scale = 100),
         cat_avg = .brsum_pct(mpen_cat_avg, "%", scale = 100),
         leader = label_map[[mpen_leader]] %||% mpen_leader,
         is_leader = !is.na(mpen_leader) && identical(mpen_leader, brand_code)),
    list(key = "ns", label = "Network Size (NS)",
         value = .brsum_num(ns_value, digits = 2),
         cat_avg = .brsum_num(ns_cat_avg, digits = 2),
         leader = label_map[[ns_leader]] %||% ns_leader,
         is_leader = !is.na(ns_leader) && identical(ns_leader, brand_code)),
    list(key = "mms", label = "Mental Market Share (MMS)",
         value = .brsum_pct(mms_value, "%"),
         cat_avg = .brsum_pct(mms_cat_avg, "%"),
         leader = label_map[[mms_leader]] %||% mms_leader,
         is_leader = !is.na(mms_leader) && identical(mms_leader, brand_code)),
    list(key = "som", label = "Share of Mind (SOM)",
         value = .brsum_pct(som_value, "%", already_pct = TRUE),
         cat_avg = .brsum_pct(som_cat_avg, "%", already_pct = TRUE),
         leader = label_map[[som_leader]] %||% som_leader,
         is_leader = !is.na(som_leader) && identical(som_leader, brand_code))
  )

  # ---- Brand summary card (Pen, Avg purchase, Vol share, SCR obs) ----
  # All four come from dirichlet_norms$norms_table for the focal brand;
  # cat avg is the unweighted mean across brands in the table.
  brand_summary_metrics <- list(
    list(key = "pen",       label = "Penetration",
         value = NA_character_, cat_avg = NA_character_),
    list(key = "buy_rate",  label = "Avg purchases / buyer",
         value = NA_character_, cat_avg = NA_character_),
    list(key = "vol_share", label = "Volume share",
         value = NA_character_, cat_avg = NA_character_),
    list(key = "scr_obs",   label = "SCR (observed)",
         value = NA_character_, cat_avg = NA_character_)
  )
  dn <- cr$dirichlet_norms
  if (!is.null(dn) && !identical(dn$status, "REFUSED") &&
      !is.null(dn$norms_table) && nrow(dn$norms_table) > 0) {
    nt <- dn$norms_table
    cat_mean_purch <- if (!is.null(dn$category_metrics$mean_purchases))
      as.numeric(dn$category_metrics$mean_purchases) else NA_real_
    vol_share_for <- function(pen, buy_rate) {
      if (!is.finite(pen) || !is.finite(buy_rate) || !is.finite(cat_mean_purch) ||
          cat_mean_purch == 0) return(NA_real_)
      buy_rate * (pen / 100) / cat_mean_purch * 100
    }
    pen_val   <- if (brand_code %in% nt$BrandCode)
      as.numeric(nt$Penetration_Obs_Pct[nt$BrandCode == brand_code]) else NA_real_
    buy_val   <- if (brand_code %in% nt$BrandCode)
      as.numeric(nt$BuyRate_Obs[nt$BrandCode == brand_code]) else NA_real_
    scr_val   <- if (brand_code %in% nt$BrandCode)
      as.numeric(nt$SCR_Obs_Pct[nt$BrandCode == brand_code]) else NA_real_
    vol_val   <- vol_share_for(pen_val, buy_val)
    pen_avg   <- mean(as.numeric(nt$Penetration_Obs_Pct), na.rm = TRUE)
    buy_avg   <- mean(as.numeric(nt$BuyRate_Obs),         na.rm = TRUE)
    scr_avg   <- mean(as.numeric(nt$SCR_Obs_Pct),         na.rm = TRUE)
    vol_avg   <- mean(vapply(seq_len(nrow(nt)), function(i)
      vol_share_for(as.numeric(nt$Penetration_Obs_Pct[i]),
                    as.numeric(nt$BuyRate_Obs[i])), numeric(1)), na.rm = TRUE)

    brand_summary_metrics[[1]]$value   <- .brsum_pct(pen_val, "%", already_pct = TRUE)
    brand_summary_metrics[[1]]$cat_avg <- .brsum_pct(pen_avg, "%", already_pct = TRUE)
    brand_summary_metrics[[2]]$value   <- .brsum_num(buy_val, digits = 1)
    brand_summary_metrics[[2]]$cat_avg <- .brsum_num(buy_avg, digits = 1)
    brand_summary_metrics[[3]]$value   <- .brsum_pct(vol_val, "%", already_pct = TRUE)
    brand_summary_metrics[[3]]$cat_avg <- .brsum_pct(vol_avg, "%", already_pct = TRUE)
    brand_summary_metrics[[4]]$value   <- .brsum_pct(scr_val, "%", already_pct = TRUE)
    brand_summary_metrics[[4]]$cat_avg <- .brsum_pct(scr_avg, "%", already_pct = TRUE)
  }

  # Combined card-level base: this card mixes two denominators
  # (penetration & volume share are over total respondents; avg purchases
  # & SCR are over the focal brand's buyers).  Showing both lets the
  # reader see exactly what each big number is anchored against.
  brand_summary_base <- ""
  if (!is.null(dn) && !is.null(dn$category_metrics)) {
    n_total <- as.numeric(dn$category_metrics$n_respondents %||% NA_real_)
    n_bb    <- if (!is.null(dn$norms_table) &&
                   "Brand_Buyers_n" %in% names(dn$norms_table) &&
                   brand_code %in% dn$norms_table$BrandCode) {
      as.numeric(dn$norms_table$Brand_Buyers_n[
        dn$norms_table$BrandCode == brand_code])
    } else NA_real_
    txt_total <- .brsum_base_text(n_total, "total_respondents")
    txt_bb    <- .brsum_base_text(
      n_bb, "brand_buyers",
      target_months = config$target_timeframe_months,
      brand_label = label)
    parts <- c(txt_total, txt_bb)
    parts <- parts[!vapply(parts, is.null, logical(1))]
    brand_summary_base <- paste(parts, collapse = " · ")
  }

  # ---- WOM card (Heard + Said breakdown: pos / neg / net for each) ----
  # Pulls from wom_metrics + net_balance. All values are pp; cat avg is
  # the unweighted mean across brands. Net = positive − negative.
  wom_card <- list(available = FALSE)
  wm_metrics <- if (!is.null(wm)) wm$wom_metrics else NULL
  wm_net     <- if (!is.null(wm)) wm$net_balance else NULL
  if (!is.null(wm_metrics) && nrow(wm_metrics) > 0 && brand_code %in% wm_metrics$BrandCode) {
    pick <- function(df, col) {
      if (is.null(df) || !col %in% names(df) || nrow(df) == 0) return(NA_real_)
      v <- as.numeric(df[[col]][df$BrandCode == brand_code])
      if (length(v) == 1) v else NA_real_
    }
    avg <- function(df, col) {
      if (is.null(df) || !col %in% names(df) || nrow(df) == 0) return(NA_real_)
      mean(as.numeric(df[[col]]), na.rm = TRUE)
    }
    fmt_pct1 <- function(x) {
      if (!is.finite(x)) "—" else sprintf("%.0f%%", x)
    }

    n_total_wom <- as.numeric(cr$funnel$meta$n_unweighted %||%
                              cr$dirichlet_norms$category_metrics$n_respondents %||%
                              NA_real_)
    wom_base <- .brsum_base_text(n_total_wom, "total_respondents") %||%
      "% of total respondents"

    wom_card <- list(
      available = TRUE,
      base_label = wom_base,
      heard = list(
        positive = list(label = "Heard positive",
                         value   = fmt_pct1(pick(wm_metrics, "ReceivedPos_Pct")),
                         cat_avg = fmt_pct1(avg(wm_metrics, "ReceivedPos_Pct")),
                         tone    = "pos"),
        negative = list(label = "Heard negative",
                         value   = fmt_pct1(pick(wm_metrics, "ReceivedNeg_Pct")),
                         cat_avg = fmt_pct1(avg(wm_metrics, "ReceivedNeg_Pct")),
                         tone    = "neg"),
        net      = list(label = "Net heard",
                         value   = .brsum_signed(pick(wm_net, "Net_Received")),
                         cat_avg = .brsum_signed(avg(wm_net, "Net_Received")))
      ),
      said = list(
        positive = list(label = "Said positive",
                         value   = fmt_pct1(pick(wm_metrics, "SharedPos_Pct")),
                         cat_avg = fmt_pct1(avg(wm_metrics, "SharedPos_Pct")),
                         tone    = "pos"),
        negative = list(label = "Said negative",
                         value   = fmt_pct1(pick(wm_metrics, "SharedNeg_Pct")),
                         cat_avg = fmt_pct1(avg(wm_metrics, "SharedNeg_Pct")),
                         tone    = "neg"),
        net      = list(label = "Net said",
                         value   = .brsum_signed(pick(wm_net, "Net_Shared")),
                         cat_avg = .brsum_signed(avg(wm_net, "Net_Shared")))
      )
    )
  }

  # ---- Diagnostic strip: top-3 attributes + top-3 CEPs by advantage ----
  # Prefer per-category labels passed in; fall back to MA's attribute_labels
  # field (built inside the engine when survey-structure attributes were
  # supplied).
  attr_label_df <- attr_labels %||% ma$attribute_labels
  attr_chips <- .brsum_top_advantage_chips(
    ma$attribute_advantage, brand_code, attr_label_df,
    label_col = "AttrText", code_col = "AttrCode")
  cep_chips  <- .brsum_top_advantage_chips(
    ma$cep_advantage, brand_code, cep_labels,
    label_col = "CEPText", code_col = "CEPCode")

  # Headline sentence (template-based, editable downstream)
  headline <- .brsum_headline_sentence(
    label, cat_name, mms_value, mms_rank, n_brands,
    mms_cat_avg)

  list(
    name = label,
    code = brand_code,
    colour = colour,
    headline = headline,
    focal_metrics = focal_metrics,
    diagnostic = list(attributes = attr_chips, ceps = cep_chips),
    ma_metrics = ma_metrics,
    brand_summary = brand_summary_metrics,
    brand_summary_base = brand_summary_base,
    wom = wom_card
  )
}


# Pull the top-N (default 3) stims with positive advantage for the given
# brand. `adv` is a `calculate_mental_advantage()` result list with fields
# `advantage` (matrix), `stim_codes`, `brand_codes`. `labels_df` is an
# optional data frame mapping codes to display labels.
.brsum_top_advantage_chips <- function(adv, brand_code, labels_df = NULL,
                                       label_col = "AttrText",
                                       code_col = "AttrCode", n = 3) {
  if (is.null(adv) || is.null(adv$advantage)) return(list())
  if (!brand_code %in% adv$brand_codes) return(list())
  vec <- adv$advantage[, brand_code, drop = TRUE]
  if (length(vec) == 0) return(list())
  # Top-N positive
  ord <- order(-vec)
  top_idx <- ord[seq_len(min(n, length(ord)))]
  out <- list()
  for (i in top_idx) {
    if (is.na(vec[i]) || vec[i] <= 0) next
    code <- names(vec)[i] %||% adv$stim_codes[i]
    lab <- code
    if (!is.null(labels_df) && code_col %in% names(labels_df) &&
        label_col %in% names(labels_df)) {
      m <- labels_df[[label_col]][match(code, labels_df[[code_col]])]
      if (!is.na(m) && nzchar(m)) lab <- m
    }
    out[[length(out) + 1L]] <- list(
      label = lab,
      delta = round(as.numeric(vec[i]), 1)
    )
  }
  out
}


# Headline sentence. Template-based. Inserts brand name + category position.
.brsum_headline_sentence <- function(brand_name, cat_name, mms, rank, n,
                                      mms_cat_avg) {
  bn <- brand_name %||% "This brand"
  cn <- if (is.null(cat_name) || is.na(cat_name)) "this category" else cat_name
  if (is.na(mms)) {
    return(sprintf("%s data not available for %s.", bn, cn))
  }

  rank_text <- if (!is.na(rank) && !is.na(n)) {
    if (rank == 1L) sprintf("the #1 brand in %s", cn)
    else if (rank == 2L) sprintf("the #2 brand in %s", cn)
    else if (rank == 3L) sprintf("the #3 brand in %s", cn)
    else sprintf("ranked %d of %d in %s", rank, n, cn)
  } else cn

  cmp <- if (!is.na(mms_cat_avg) && mms_cat_avg > 0) {
    delta <- mms - mms_cat_avg
    if (abs(delta) < 0.005) "in line with the category average"
    else if (delta > 0) sprintf("above the category average of %.0f%%",
                                 100 * mms_cat_avg)
    else sprintf("below the category average of %.0f%%",
                  100 * mms_cat_avg)
  } else ""

  sprintf("%s is %s with an MMS of %.0f%%%s.",
          bn, rank_text, 100 * mms,
          if (nzchar(cmp)) sprintf(", %s", cmp) else "")
}


# ==============================================================================
# INTERNAL: HTML BUILDERS
# ==============================================================================

.brsum_empty_panel <- function() {
  paste(
    '<div class="br-panel active" id="panel-summary">',
      '<div style="padding:48px;text-align:center;color:#64748b;">',
        '<p style="font-size:14px;">No deep-dive categories available for the executive summary.</p>',
      '</div>',
    '</div>',
    sep = "\n"
  )
}


.brsum_header <- function() {
  paste(
    '<div class="brsum-header">',
      '<div class="brsum-eyebrow">Executive Summary</div>',
      '<h1 class="brsum-title">How is this brand doing?</h1>',
      '<p class="brsum-subtitle">A category-by-category snapshot. Pick a category and a brand to see where it sits and why.</p>',
    '</div>',
    sep = "\n"
  )
}


.brsum_dropdown_bar <- function(payload) {
  cat_options <- vapply(names(payload$categories), function(cn) {
    sprintf('<option value="%s">%s</option>',
            .brsum_esc(cn), .brsum_esc(cn))
  }, character(1))

  # Brand options are populated dynamically by JS based on selected category;
  # we inject a placeholder.
  paste(
    '<div class="brsum-dropdown-bar">',
      '<div class="brsum-dropdown-group">',
        '<span class="brsum-dropdown-label">Category</span>',
        '<select class="brsum-dropdown" data-brsum-cat>',
          paste(cat_options, collapse = ""),
        '</select>',
      '</div>',
      '<div class="brsum-dropdown-group">',
        '<span class="brsum-dropdown-label">Brand</span>',
        '<select class="brsum-dropdown" data-brsum-brand></select>',
      '</div>',
    '</div>',
    sep = "\n"
  )
}


# ==============================================================================
# DASHBOARD SKELETON (v2 — card grid)
# ==============================================================================
# Layout (top → bottom):
#   1. Focal context strip — the chosen focal brand + category, displayed
#      once at the top so per-card headers don't have to repeat them.
#   2. Card grid — 11 cards, two per row, with the two dot-plots (CEP and
#      Brand attributes) spanning full width because they need horizontal
#      room. Card content is rendered by JS reading the JSON payload; this
#      function only emits empty containers + section labels.

.brsum_focal_context_strip <- function() {
  paste(
    '<div class="brsum-focal-context" data-brsum-focal-context>',
      '<span class="brsum-fc-eyebrow">FOCAL</span>',
      '<span class="brsum-fc-brand" data-brsum-fc-brand>&mdash;</span>',
      '<span class="brsum-fc-divider">&middot;</span>',
      '<span class="brsum-fc-cat" data-brsum-fc-cat>&mdash;</span>',
    '</div>',
    sep = "\n"
  )
}


.brsum_card_grid_skeleton <- function() {
  card <- function(key, title, wide = FALSE) {
    cls <- if (wide) ' brsum-card-wide' else ''
    paste0(
      '<section class="brsum-card brsum-card-', key, cls,
        '" data-brsum-card="', key, '">',
        '<header class="brsum-card-header">',
          '<h3 class="brsum-card-title">', title, '</h3>',
          '<span class="brsum-card-meta" data-brsum-card-meta="', key, '"></span>',
        '</header>',
        '<div class="brsum-card-body" data-brsum-card-body="', key, '"></div>',
      '</section>')
  }
  paste(
    '<div class="brsum-card-grid">',
      card("context",       "Category context"),
      card("ma_metrics",    "Mental Availability — headline metrics"),
      card("brand_summary", "Purchase behaviour"),
      card("funnel",        "Brand funnel"),
      card("attitude",      "Brand attitude"),
      card("loyalty",       "Loyalty segmentation"),
      card("purchase_dist", "Purchase distribution"),
      card("wom",           "Word of mouth"),
      card("dop",           "Duplication of purchase"),
      card("cep",           "Category Entry Points",  wide = TRUE),
      card("attrs",         "Brand attributes",       wide = TRUE),
    '</div>',
    sep = "\n"
  )
}


.brsum_insight_editor <- function() {
  paste(
    '<div class="brsum-insight-block">',
      '<div class="brsum-strip-title">Analyst commentary</div>',
      '<div class="brsum-insight-toolbar">',
        '<button class="brsum-insight-btn" title="Bold" onclick="brsumInsertMd(\'**\',\'**\')"><strong>B</strong></button>',
        '<button class="brsum-insight-btn" title="Italic" onclick="brsumInsertMd(\'*\',\'*\')"><em>I</em></button>',
        '<button class="brsum-insight-btn" title="Heading" onclick="brsumInsertMd(\'## \',\'\')">H2</button>',
        '<button class="brsum-insight-btn" title="Bullet" onclick="brsumInsertMd(\'- \',\'\')">&bull;</button>',
        '<button class="brsum-insight-btn" title="Quote" onclick="brsumInsertMd(\'&gt; \',\'\')">&ldquo;</button>',
        '<span class="brsum-insight-hint">**bold**, *italic*, ## heading, - bullet, &gt; quote</span>',
      '</div>',
      '<textarea class="brsum-insight-editor" id="brsum-insight-editor" rows="5" placeholder="Type the brand story for this category. The headline above is editable here." oninput="brsumRenderInsight()"></textarea>',
      '<div class="brsum-insight-rendered" id="brsum-insight-rendered"></div>',
    '</div>',
    sep = "\n"
  )
}


.brsum_closing_strip <- function(deep_cats, payload, focal_brand) {
  # Only show the "across all categories" strip when there are 2+ deep-dive
  # categories. Single-category reports (the common case) don't benefit from
  # this view — it just adds noise.
  if (length(deep_cats) < 2 || !nzchar(focal_brand)) return("")
  cards <- character(0)
  for (cn in deep_cats) {
    cat_payload <- payload$categories[[cn]]
    if (is.null(cat_payload)) next
    snap <- cat_payload$brands[[focal_brand]]
    if (is.null(snap)) next
    mms <- snap$focal_metrics[[1]]$value
    mpen <- snap$focal_metrics[[2]]$value
    bt   <- snap$focal_metrics[[3]]$value
    cards <- c(cards, sprintf(
      '<div class="brsum-mini-card" onclick="brsumSwitchCat(\'%s\')">
         <div class="brsum-mini-cat">%s</div>
         <div class="brsum-mini-row"><span>MMS</span><span class="brsum-mini-num">%s</span></div>
         <div class="brsum-mini-row"><span>MPen</span><span class="brsum-mini-num">%s</span></div>
         <div class="brsum-mini-row"><span>Bought-T</span><span class="brsum-mini-num">%s</span></div>
       </div>',
      .brsum_esc(cn), .brsum_esc(cn), .brsum_esc(mms),
      .brsum_esc(mpen), .brsum_esc(bt)
    ))
  }
  if (length(cards) == 0) return("")
  paste(
    '<div class="brsum-closing">',
      sprintf('<div class="brsum-strip-title">%s across all categories</div>',
              .brsum_esc(payload$categories[[deep_cats[1]]]$brands[[focal_brand]]$name %||% focal_brand)),
      '<div class="brsum-mini-grid">',
        paste(cards, collapse = "\n"),
      '</div>',
    '</div>',
    sep = "\n"
  )
}


.brsum_educational_callout <- function() {
  # Body sourced from the central callout registry
  # (modules/shared/lib/callouts/callouts.json -> brand.executive_summary).
  # Editable via the Callout Editor.
  if (exists("turas_callout", mode = "function")) {
    turas_callout("brand", "executive_summary", collapsed = TRUE)
  } else {
    ""
  }
}


# ==============================================================================
# INTERNAL: FORMATTING HELPERS
# ==============================================================================

# Builds an "n=400, total respondents" / "n=390, P3M category buyers" base
# label. Returns NULL when n is missing so callers can fall back to a plain
# base string. target_months / longer_months are pulled from config when
# available so the time-window prefix tracks operator settings.
.brsum_base_text <- function(n, base_kind = "total_respondents",
                              target_months = NULL, longer_months = NULL,
                              brand_label = NULL) {
  if (is.null(n) || !is.finite(n) || n <= 0) return(NULL)
  win_lbl <- function(m) {
    if (is.null(m) || !is.finite(m) || m <= 0) return("")
    paste0("P", as.integer(m), "M")
  }
  tm <- win_lbl(target_months %||% 3)
  lm <- win_lbl(longer_months %||% 12)
  base <- switch(base_kind,
    "total_respondents"     = "total respondents",
    "category_buyers"       = paste(tm, "category buyers"),
    "category_buyers_long"  = paste(lm, "category buyers"),
    "brand_buyers"          = if (!is.null(brand_label) && nzchar(brand_label))
        paste(tm, brand_label, "buyers") else paste(tm, "brand buyers"),
    base_kind
  )
  sprintf("n=%s, %s",
          format(as.integer(round(n)), big.mark = ",", scientific = FALSE),
          base)
}


# Pretty percentage formatter. Handles three input shapes:
#  - already_pct = TRUE: value is already in 0..100 scale (e.g. Sole_Pct)
#  - scale = 100: value is in 0..1, multiply by 100 (e.g. MPen)
#  - default: value is in 0..1 (e.g. MMS)
.brsum_pct <- function(x, suffix = "%", scale = 100,
                       already_pct = FALSE) {
  if (is.null(x) || is.na(x)) return("—")
  if (already_pct) return(sprintf("%.0f%s", x, suffix))
  sprintf("%.0f%s", x * scale, suffix)
}


# Signed-integer formatter (for net WOM)
.brsum_signed <- function(x) {
  if (is.null(x) || is.na(x)) return("—")
  if (x > 0) sprintf("+%.0f", x)
  else sprintf("%.0f", x)
}


# Plain numeric formatter (for NS, avg purchases — not a percentage)
.brsum_num <- function(x, digits = 1) {
  if (is.null(x) || is.na(x) || !is.finite(x)) return("—")
  sprintf(paste0("%.", as.integer(digits), "f"), x)
}


.brsum_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


.brsum_json <- function(payload) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null", null = "null",
                   pretty = FALSE, digits = 6)
}


# Local null-coalesce. Some R versions / module load orders may not have
# the global %||%, so define a local fallback.
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
