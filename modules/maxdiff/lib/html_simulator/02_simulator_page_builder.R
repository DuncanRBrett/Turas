# ==============================================================================
# MAXDIFF SIMULATOR - PAGE BUILDER - TURAS V2.0
# ==============================================================================
# Assembles the interactive simulator HTML page with 5 tabs

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

htmlEscape <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

#' Build simulator HTML page
#'
#' @param sim_data List from build_simulator_data()
#' @param js_files Named list of JS file contents
#'
#' @return HTML string
#' @keywords internal
build_simulator_page <- function(sim_data, ...) {
  # Accept either old-style (3 positional JS args) or new-style (named list)
  args <- list(...)
  if (length(args) == 1 && is.list(args[[1]]) && !is.null(names(args[[1]]))) {
    js_files <- args[[1]]
  } else if (length(args) >= 3) {
    js_files <- list(
      engine = args[[1]],
      charts = args[[2]],
      ui = args[[3]]
    )
    if (length(args) >= 4) js_files$pins <- args[[4]]
    if (length(args) >= 5) js_files$export <- args[[5]]
  } else {
    js_files <- list()
  }

  brand <- sim_data$brand_colour %||% "#1e3a5f"
  project_name <- htmlEscape(sim_data$project_name %||% "MaxDiff Simulator")
  json_data <- jsonlite::toJSON(sim_data, auto_unbox = TRUE, digits = 4)

  # Build shared elements
  item_options <- build_item_options(sim_data$items)
  portfolio_checks <- build_portfolio_checks(sim_data$items)
  has_segments <- length(sim_data$segments) > 0

  seg_filter_shares <- if (has_segments) build_segment_filter_html("seg-filter-shares", sim_data$segments) else ""
  seg_filter_h2h <- if (has_segments) build_segment_filter_html("seg-filter-h2h", sim_data$segments) else ""
  seg_filter_turf <- if (has_segments) build_segment_filter_html("seg-filter-turf", sim_data$segments) else ""

  seg_table_btn <- if (has_segments) '<button id="seg-table-toggle" class="sim-btn sim-btn-outline">Show Segment Table</button>' else ""

  css <- build_simulator_css(brand)
  n_items <- sim_data$n_items %||% 0
  n_resp <- sim_data$n_respondents %||% 0

  # Build toolbar helper
  toolbar <- function(tab_id) {
    sprintf('<div class="sim-toolbar">
      <button class="sim-pin-btn sim-btn sim-btn-icon" data-pin-tab="%s" title="Pin this view">%s Pin</button>
      <button class="sim-export-png-btn sim-btn sim-btn-icon" data-export-tab="%s" title="Export as PNG">%s PNG</button>
      <button class="sim-export-excel-btn sim-btn sim-btn-icon" data-export-tab="%s" title="Export to Excel">%s Excel</button>
    </div>', tab_id, pin_icon(), tab_id, download_icon(), tab_id, table_icon())
  }

  pin_toolbar <- function(tab_id) {
    sprintf('<div class="sim-toolbar">
      <button class="sim-pin-btn sim-btn sim-btn-icon" data-pin-tab="%s" title="Pin this view">%s Pin</button>
    </div>', tab_id, pin_icon())
  }

  page <- sprintf('<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="turas-report-type" content="maxdiff-simulator">
  <title>%s - MaxDiff Simulator</title>
  <style>%s</style>
</head>
<body>
  <div class="sim-header">
    <h1>%s</h1>
    <div class="sim-meta"><span>Interactive MaxDiff Simulator</span><span>%d items &middot; %s respondents</span></div>
  </div>
  <div class="sim-container">
    <div class="sim-tab-nav">
      <button class="sim-tab-btn active" data-tab="overview">Overview</button>
      <button class="sim-tab-btn" data-tab="shares">Preference Shares</button>
      <button class="sim-tab-btn" data-tab="h2h">Head-to-Head</button>
      <button class="sim-tab-btn" data-tab="portfolio">Portfolio (TURF)</button>
      <button class="sim-tab-btn" data-tab="diagnostics">Diagnostics</button>
      <button class="sim-tab-btn" data-tab="pins">Pinned Views <span id="pin-badge" class="sim-pin-badge" style="display:none">0</span></button>
      <button class="sim-tab-btn" data-tab="about">About</button>
    </div>
    <div class="sim-content">

      <!-- OVERVIEW TAB -->
      <div class="sim-panel active" id="panel-overview">
        <div class="sim-panel-header">
          <h2>Overview</h2>
          %s
        </div>
        <div id="overview-callout"></div>
        <div id="overview-stats"></div>
        <h3 class="sim-section-title">Top Items</h3>
        <div id="overview-mini-chart"></div>
        <div class="sim-insight-block">
          <div class="sim-insight-label">Insight</div>
          <div class="sim-insight-editor" contenteditable="true" id="insight-overview" data-placeholder="Add overview insight or commentary..."></div>
        </div>
      </div>

      <!-- PREFERENCE SHARES TAB -->
      <div class="sim-panel" id="panel-shares">
        <div class="sim-panel-header">
          <h2>Preference Shares</h2>
          %s
        </div>
        <div id="shares-callout"></div>
        <div class="sim-shares-toolbar">
          %s
          %s
          <span id="shares-hidden-info" class="sim-hidden-info" style="display:none"></span>
          <button id="shares-show-all" class="sim-btn sim-btn-small" style="display:none">Show All</button>
        </div>
        <div id="shares-chart"></div>
        <div id="seg-table-container" style="display:none"></div>
        <div class="sim-insight-block">
          <div class="sim-insight-label">Insight</div>
          <div class="sim-insight-editor" contenteditable="true" id="insight-shares" data-placeholder="Add preference shares insight or commentary..."></div>
        </div>
      </div>

      <!-- HEAD-TO-HEAD TAB -->
      <div class="sim-panel" id="panel-h2h">
        <div class="sim-panel-header">
          <h2>Head-to-Head Comparator</h2>
          %s
        </div>
        <div id="h2h-callout"></div>
        %s
        <div id="h2h-slots"></div>
        <div class="sim-insight-block">
          <div class="sim-insight-label">Insight</div>
          <div class="sim-insight-editor" contenteditable="true" id="insight-h2h" data-placeholder="Add head-to-head insight or commentary..."></div>
        </div>
      </div>

      <!-- PORTFOLIO (TURF) TAB -->
      <div class="sim-panel" id="panel-portfolio">
        <div class="sim-panel-header">
          <h2>Portfolio Builder (TURF)</h2>
          %s
        </div>
        <div id="turf-callout"></div>
        %s
        <div class="sim-portfolio-controls">
          <div class="sim-portfolio-options">
            <label>Top-K threshold: <select id="turf-top-k">
              <option value="3" selected>Top 3</option>
              <option value="4">Top 4</option>
              <option value="5">Top 5</option>
            </select></label>
            <label>Max items: <select id="turf-max-items">
              <option value="3">3</option>
              <option value="5" selected>5</option>
              <option value="7">7</option>
              <option value="10">10</option>
            </select></label>
            <button id="turf-auto-optimize" class="sim-btn">Auto-Optimise</button>
          </div>
          <div id="turf-count" class="sim-turf-count">0 items selected</div>
        </div>
        <div class="sim-portfolio-grid">%s</div>
        <div id="turf-result"></div>
        <div id="turf-opt-result"></div>
        <div class="sim-insight-block">
          <div class="sim-insight-label">Insight</div>
          <div class="sim-insight-editor" contenteditable="true" id="insight-turf" data-placeholder="Add TURF insight or commentary..."></div>
        </div>
      </div>

      <!-- DIAGNOSTICS TAB -->
      <div class="sim-panel" id="panel-diagnostics">
        <div class="sim-panel-header">
          <h2>Diagnostics</h2>
          %s
        </div>
        <div id="diagnostics-callout"></div>
        <div id="diagnostics-content"></div>
        <div class="sim-insight-block">
          <div class="sim-insight-label">Insight</div>
          <div class="sim-insight-editor" contenteditable="true" id="insight-diagnostics" data-placeholder="Add diagnostics insight or commentary..."></div>
        </div>
      </div>

      <!-- PINNED VIEWS TAB -->
      <div class="sim-panel" id="panel-pins">
        <h2>Pinned Views</h2>
        <div id="pins-callout"></div>
        <div id="pins-container">
          <div class="sim-pins-empty">No pinned views yet. Pin views from other tabs to save them here.</div>
        </div>
        <div class="sim-pins-actions">
          <button id="pins-add-slide" class="sim-btn sim-btn-outline">+ Custom Slide</button>
          <button id="pins-add-section" class="sim-btn sim-btn-outline">+ Section Divider</button>
        </div>
      </div>

      <!-- ABOUT TAB -->
      <div class="sim-panel" id="panel-about">
        <h2>About</h2>
        <div id="about-content">%s</div>
      </div>

    </div>
  </div>
  <div class="sim-footer">TURAS MaxDiff Simulator v2.0 &middot; %s</div>
  <script type="application/json" id="sim-data">%s</script>
  %s
</body>
</html>',
    project_name,
    css,
    project_name,
    n_items,
    format(n_resp, big.mark = ","),
    pin_toolbar("overview"),
    toolbar("shares"),
    seg_filter_shares,
    seg_table_btn,
    toolbar("h2h"),
    seg_filter_h2h,
    toolbar("portfolio"),
    seg_filter_turf,
    portfolio_checks,
    pin_toolbar("diagnostics"),
    build_about_html(sim_data),
    format(Sys.Date(), "%%B %%Y"),
    json_data,
    build_js_tags(js_files)
  )

  page
}


#' Build item <option> tags
#' @keywords internal
build_item_options <- function(items) {
  paste(vapply(items, function(it) {
    sprintf('<option value="%s">%s</option>', htmlEscape(it$id), htmlEscape(it$label))
  }, character(1)), collapse = "\n")
}

#' Build portfolio checkbox labels
#' @keywords internal
build_portfolio_checks <- function(items) {
  paste(vapply(items, function(it) {
    sprintf(
      '<label class="sim-check-label"><input type="checkbox" class="sim-portfolio-check" value="%s"> %s</label>',
      htmlEscape(it$id), htmlEscape(it$label)
    )
  }, character(1)), collapse = "\n")
}

#' Build segment filter dropdown
#' @keywords internal
build_segment_filter_html <- function(id, segments) {
  seg_options <- paste(vapply(segments, function(s) {
    sprintf('<option value="%s:%s">%s</option>',
            htmlEscape(s$variable), htmlEscape(s$value), htmlEscape(s$label))
  }, character(1)), collapse = "\n")

  sprintf(
    '<div class="sim-filter"><label>Segment: <select id="%s"><option value="">All respondents</option>%s</select></label></div>',
    id, seg_options
  )
}

#' Build script tags for all JS files
#' @keywords internal
build_js_tags <- function(js_files) {
  # Order matters: engine, charts, pins, export, ui (ui last since it wires everything)
  order <- c("engine", "charts", "pins", "export", "ui")
  tags <- character(0)
  for (name in order) {
    if (!is.null(js_files[[name]]) && nchar(js_files[[name]]) > 0) {
      tags <- c(tags, sprintf("<script>%s</script>", js_files[[name]]))
    }
  }
  # Any extras not in the order
  extras <- setdiff(names(js_files), order)
  for (name in extras) {
    if (!is.null(js_files[[name]]) && nchar(js_files[[name]]) > 0) {
      tags <- c(tags, sprintf("<script>%s</script>", js_files[[name]]))
    }
  }
  paste(tags, collapse = "\n  ")
}

#' SVG icon helpers for toolbar
#' @keywords internal
pin_icon <- function() {
  '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="17" x2="12" y2="22"/><path d="M5 17h14v-1.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V6h1a2 2 0 0 0 0-4H8a2 2 0 0 0 0 4h1v4.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24Z"/></svg>'
}

download_icon <- function() {
  '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>'
}

table_icon <- function() {
  '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="3" y1="15" x2="21" y2="15"/><line x1="9" y1="3" x2="9" y2="21"/><line x1="15" y1="3" x2="15" y2="21"/></svg>'
}


#' Build About tab HTML content from sim_data
#'
#' Matches the tabs module closing-section pattern:
#' analyst, email, phone, appendices, and editable notes.
#' @keywords internal
build_about_html <- function(sim_data) {
  analyst <- htmlEscape(sim_data$analyst_name %||% "")
  email <- htmlEscape(sim_data$analyst_email %||% "")
  phone <- htmlEscape(sim_data$analyst_phone %||% "")
  appendices <- htmlEscape(sim_data$appendices %||% "")
  closing_notes <- sim_data$closing_notes %||% ""

  # Contact section
  contact_html <- ""
  contact_items <- ""
  if (nchar(analyst) > 0) contact_items <- paste0(contact_items,
    '<div class="sim-about-contact-item"><span class="sim-about-label">Analyst</span><span class="sim-about-value">', analyst, '</span></div>')
  if (nchar(email) > 0) contact_items <- paste0(contact_items,
    '<div class="sim-about-contact-item"><span class="sim-about-label">Email</span><a class="sim-about-value sim-about-link" href="mailto:', email, '">', email, '</a></div>')
  if (nchar(phone) > 0) contact_items <- paste0(contact_items,
    '<div class="sim-about-contact-item"><span class="sim-about-label">Phone</span><span class="sim-about-value">', phone, '</span></div>')
  if (nchar(contact_items) > 0) {
    contact_html <- sprintf('<div class="sim-about-card"><div class="sim-about-contact-grid">%s</div></div>', contact_items)
  }

  # Appendices section
  appendices_html <- ""
  if (nchar(appendices) > 0) {
    appendices_html <- sprintf(
      '<div class="sim-about-card"><div class="sim-about-detail"><span class="sim-about-label">Appendices</span><span class="sim-about-value">%s</span></div></div>',
      appendices
    )
  }

  # Notes section (editable)
  notes_html <- sprintf(
    '<div class="sim-about-card">
      <div class="sim-insight-label">Notes</div>
      <div class="sim-insight-editor" contenteditable="true" id="insight-about" data-placeholder="Add closing notes...">%s</div>
    </div>',
    htmlEscape(closing_notes)
  )

  paste0(
    '<div class="sim-about-section">',
    contact_html,
    appendices_html,
    notes_html,
    '</div>'
  )
}


build_simulator_css <- function(brand) {
  css <- ':root { --sim-brand: BRAND_TOKEN; --sim-brand-light: BRAND_TOKEN12; }
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8fafc; color: #1e293b; line-height: 1.5; font-size: 14px; }

/* Header */
.sim-header { background: var(--sim-brand); color: white; padding: 24px 32px; }
.sim-header h1 { font-size: 22px; font-weight: 600; letter-spacing: -0.01em; }
.sim-meta { display: flex; gap: 16px; font-size: 12px; opacity: 0.85; margin-top: 4px; }

/* Layout */
.sim-container { max-width: 960px; margin: 0 auto; padding: 0 20px; }
.sim-tab-nav { display: flex; background: white; border-bottom: 1px solid #e2e8f0; border-radius: 10px 10px 0 0; margin-top: 24px; overflow-x: auto; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
.sim-tab-btn { background: transparent; border: none; padding: 12px 18px; font-size: 13px; font-weight: 500; color: #64748b; cursor: pointer; border-bottom: 2px solid transparent; white-space: nowrap; transition: color 0.15s; position: relative; }
.sim-tab-btn:hover { color: #334155; }
.sim-tab-btn.active { color: var(--sim-brand); border-bottom-color: var(--sim-brand); }
.sim-content { background: white; border-radius: 0 0 10px 10px; padding: 28px 32px; min-height: 420px; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
.sim-panel { display: none; }
.sim-panel.active { display: block; }
.sim-panel h2 { font-size: 18px; font-weight: 600; color: var(--sim-brand); margin-bottom: 4px; }
.sim-panel h3 { font-size: 15px; font-weight: 600; color: #334155; margin: 20px 0 8px; }
.sim-section-title { font-size: 14px; font-weight: 600; color: #475569; margin: 20px 0 10px; text-transform: uppercase; letter-spacing: 0.05em; }
.sim-desc { font-size: 13px; color: #64748b; margin-bottom: 16px; }
.sim-panel-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px; }

/* Callout */
.sim-callout { display: flex; gap: 10px; padding: 12px 16px; background: #f0f7ff; border-left: 3px solid var(--sim-brand); border-radius: 0 6px 6px 0; margin-bottom: 20px; font-size: 13px; color: #475569; line-height: 1.6; }
.sim-callout-icon { flex-shrink: 0; margin-top: 1px; }
.sim-callout-text { flex: 1; }
.sim-callout-text strong { color: #1e293b; }

/* Buttons */
.sim-btn { background: var(--sim-brand); color: white; border: none; padding: 7px 16px; border-radius: 6px; font-size: 13px; font-weight: 500; cursor: pointer; transition: opacity 0.15s; display: inline-flex; align-items: center; gap: 5px; }
.sim-btn:hover { opacity: 0.88; }
.sim-btn-outline { background: transparent; color: var(--sim-brand); border: 1px solid #cbd5e1; }
.sim-btn-outline:hover { background: #f8fafc; border-color: var(--sim-brand); opacity: 1; }
.sim-btn-small { padding: 4px 10px; font-size: 12px; }
.sim-btn-icon { padding: 5px 12px; font-size: 12px; }
.sim-btn-icon svg { vertical-align: -2px; }

/* Toolbar */
.sim-toolbar { display: flex; gap: 6px; flex-shrink: 0; }

/* Filter */
.sim-filter { margin-bottom: 14px; }
.sim-filter select { padding: 5px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; background: white; }
.sim-shares-toolbar { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; margin-bottom: 14px; }

/* Share bars */
.sim-share-bars { margin: 8px 0; }
.sim-bar-row { display: flex; align-items: center; margin-bottom: 5px; transition: opacity 0.2s; }
.sim-bar-row.sim-bar-hidden { opacity: 0.3; }
.sim-eye-btn { background: none; border: none; cursor: pointer; color: #94a3b8; padding: 2px 6px 2px 0; flex-shrink: 0; transition: color 0.15s; }
.sim-eye-btn:hover { color: var(--sim-brand); }
.sim-bar-label { width: 170px; font-size: 12px; font-weight: 500; text-align: right; padding-right: 10px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: #334155; }
.sim-bar-track { flex: 1; height: 28px; background: #f1f5f9; border-radius: 4px; overflow: hidden; }
.sim-bar-fill { height: 100%; border-radius: 4px; transition: width 0.3s ease; }
.sim-bar-value { width: 58px; font-size: 12px; font-weight: 600; text-align: right; padding-left: 8px; color: #334155; }
.sim-hidden-info { font-size: 12px; color: #f59e0b; font-weight: 500; }

/* Mini bars (overview) */
.sim-mini-bars { margin: 4px 0; }
.sim-mini-row { display: flex; align-items: center; margin-bottom: 4px; }
.sim-mini-label { width: 140px; font-size: 11px; font-weight: 500; text-align: right; padding-right: 8px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: #475569; }
.sim-mini-track { flex: 1; height: 18px; background: #f1f5f9; border-radius: 3px; overflow: hidden; }
.sim-mini-fill { height: 100%; border-radius: 3px; }
.sim-mini-value { width: 50px; font-size: 11px; font-weight: 600; text-align: right; padding-left: 6px; color: #475569; }
.sim-mini-more { font-size: 11px; color: #94a3b8; text-align: center; margin-top: 4px; }

/* Stat cards */
.sim-stat-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 14px; margin: 16px 0; }
.sim-stat-card { display: flex; align-items: center; gap: 12px; padding: 16px 18px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; }
.sim-stat-icon { flex-shrink: 0; width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; background: white; border-radius: 8px; border: 1px solid #e2e8f0; }
.sim-stat-value { font-size: 22px; font-weight: 700; color: var(--sim-brand); line-height: 1.2; }
.sim-stat-label { font-size: 12px; font-weight: 500; color: #64748b; }
.sim-stat-sub { font-size: 11px; color: #94a3b8; margin-top: 1px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 130px; }

/* Head-to-head */
.sim-h2h-controls { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
.sim-h2h-controls select { padding: 6px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; flex: 1; background: white; }
.sim-vs { font-weight: 700; color: #94a3b8; font-size: 13px; }
.sim-h2h { margin: 8px 0 16px; }
.sim-h2h-bar { display: flex; height: 44px; border-radius: 6px; overflow: hidden; }
.sim-h2h-a, .sim-h2h-b { display: flex; align-items: center; justify-content: center; color: white; font-weight: 700; font-size: 16px; transition: width 0.3s; min-width: 40px; }
.sim-h2h-labels { display: flex; justify-content: space-between; margin-top: 6px; font-size: 12px; font-weight: 500; color: #475569; }
.sim-h2h-slot-controls { border-bottom: 1px solid #f1f5f9; padding-bottom: 14px; margin-bottom: 14px; }
.sim-h2h-slot-controls:last-of-type { border-bottom: none; }
.sim-h2h-slot-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; }
.sim-h2h-slot-num { font-size: 12px; font-weight: 600; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; }
.sim-h2h-remove-btn { background: none; border: none; cursor: pointer; color: #94a3b8; font-size: 20px; line-height: 1; padding: 2px 6px; border-radius: 4px; }
.sim-h2h-remove-btn:hover { color: #ef4444; background: #fef2f2; }
#h2h-add-btn { margin-top: 8px; }

/* Portfolio */
.sim-portfolio-controls { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; margin-bottom: 14px; }
.sim-portfolio-options { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
.sim-portfolio-options select { padding: 5px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; background: white; }
.sim-turf-count { font-size: 13px; color: #64748b; font-weight: 500; }
.sim-portfolio-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 4px; margin-bottom: 16px; }
.sim-check-label { display: flex; align-items: center; gap: 6px; font-size: 13px; padding: 7px 10px; border-radius: 6px; cursor: pointer; transition: background 0.1s; }
.sim-check-label:hover { background: #f8fafc; }

/* TURF gauge */
.sim-turf-gauge { display: flex; align-items: center; gap: 24px; margin: 16px 0; }
.sim-turf-stats { font-size: 13px; color: #64748b; }
.sim-turf-stats div { margin-bottom: 4px; }
.sim-turf-seg-label { font-weight: 500; color: var(--sim-brand); margin-top: 4px; }
.sim-turf-opt-list { margin-top: 14px; font-size: 13px; }
.sim-turf-opt-list ol { padding-left: 22px; }
.sim-turf-opt-list li { margin-bottom: 4px; }

/* Segment comparison table */
.sim-seg-table-wrap { overflow-x: auto; margin: 16px 0; }
.sim-seg-table { width: 100%; border-collapse: collapse; font-size: 12px; }
.sim-seg-table th { background: var(--sim-brand); color: white; padding: 8px 12px; text-align: right; font-weight: 500; white-space: nowrap; }
.sim-seg-table th:first-child { text-align: left; border-radius: 6px 0 0 0; }
.sim-seg-table th:last-child { border-radius: 0 6px 0 0; }
.sim-seg-table td { padding: 7px 12px; text-align: right; border-bottom: 1px solid #f1f5f9; }
.sim-seg-table .sim-seg-item { text-align: left; font-weight: 500; color: #334155; }
.sim-seg-table tr:hover { background: #fafbfc; }
.sim-seg-best { color: #059669; font-weight: 600; }
.sim-seg-worst { color: #dc2626; }

/* Pinned views */
.sim-pin-badge { display: inline-flex; align-items: center; justify-content: center; background: #ef4444; color: white; font-size: 10px; font-weight: 700; width: 18px; height: 18px; border-radius: 50%; margin-left: 4px; vertical-align: 1px; }
.sim-pins-empty { text-align: center; padding: 48px 20px; color: #94a3b8; font-size: 14px; }
.sim-pins-actions { display: flex; gap: 8px; margin-top: 16px; }
.sim-pin-card { border: 1px solid #e2e8f0; border-radius: 8px; margin-bottom: 14px; overflow: hidden; }
.sim-pin-card-header { display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; background: #f8fafc; border-bottom: 1px solid #e2e8f0; }
.sim-pin-card-title { font-size: 13px; font-weight: 600; color: #334155; }
.sim-pin-card-actions { display: flex; gap: 4px; }
.sim-pin-card-body { padding: 14px; }
.sim-pin-card-insight { margin-top: 10px; }
.sim-pin-insight-editor { border: 1px solid #e2e8f0; border-radius: 6px; padding: 10px 12px; min-height: 60px; font-size: 13px; line-height: 1.6; outline: none; }
.sim-pin-insight-editor:focus { border-color: var(--sim-brand); box-shadow: 0 0 0 2px rgba(30,58,95,0.1); }
.sim-pin-insight-editor:empty::before { content: "Add insight or commentary..."; color: #94a3b8; }
.sim-pin-section { padding: 14px; border-bottom: 2px solid var(--sim-brand); margin-bottom: 14px; }
.sim-pin-section-title { font-size: 16px; font-weight: 700; color: var(--sim-brand); border: none; background: transparent; outline: none; width: 100%; }
.sim-custom-slide { border: 1px dashed #cbd5e1; border-radius: 8px; padding: 16px; margin-bottom: 14px; }
.sim-custom-slide-title { font-size: 15px; font-weight: 600; color: #334155; border: none; background: transparent; outline: none; width: 100%; margin-bottom: 8px; }
.sim-custom-slide-body { border: 1px solid #e2e8f0; border-radius: 6px; padding: 10px 12px; min-height: 80px; font-size: 13px; line-height: 1.6; outline: none; }
.sim-custom-slide-body:focus { border-color: var(--sim-brand); box-shadow: 0 0 0 2px rgba(30,58,95,0.1); }
.sim-custom-slide-body:empty::before { content: "Write your content here... (supports **bold**, *italic*, - bullets)"; color: #94a3b8; }

/* Insight blocks */
.sim-insight-block { margin-top: 24px; padding-top: 16px; border-top: 1px solid #f1f5f9; }
.sim-insight-label { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: #94a3b8; margin-bottom: 6px; }
.sim-insight-editor { border: 1px solid #e2e8f0; border-radius: 6px; padding: 12px 14px; min-height: 48px; font-size: 13px; line-height: 1.7; color: #1e293b; outline: none; background: #fafbfc; transition: border-color 0.15s, box-shadow 0.15s; }
.sim-insight-editor:focus { border-color: var(--sim-brand); box-shadow: 0 0 0 2px rgba(30,58,95,0.08); background: white; }
.sim-insight-editor:empty::before { content: attr(data-placeholder); color: #94a3b8; }

/* Diagnostics */
.sim-diag-section { margin-bottom: 24px; }
.sim-diag-guide { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px 20px; }
.sim-diag-guide-item { font-size: 13px; color: #475569; margin-bottom: 10px; line-height: 1.6; }
.sim-diag-guide-item:last-child { margin-bottom: 0; }
.sim-diag-guide-item strong { color: #334155; }

/* About page */
.sim-about-section { }
.sim-about-card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 24px; margin-bottom: 20px; }
.sim-about-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 16px; }
.sim-about-detail { display: flex; flex-direction: column; }
.sim-about-label { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: #94a3b8; margin-bottom: 2px; }
.sim-about-value { font-size: 14px; color: #1e293b; font-weight: 500; }
.sim-about-meta { color: #94a3b8; font-weight: 400; }
.sim-about-link { color: var(--sim-brand); text-decoration: none; }
.sim-about-link:hover { text-decoration: underline; }
.sim-about-contact-grid { display: flex; gap: 32px; flex-wrap: wrap; }
.sim-about-contact-item { display: flex; flex-direction: column; }

/* Footer */
.sim-footer { text-align: center; padding: 24px; font-size: 11px; color: #94a3b8; }

/* Responsive */
@media (max-width: 640px) {
  .sim-content { padding: 16px; }
  .sim-bar-label { width: 110px; }
  .sim-panel-header { flex-direction: column; gap: 8px; }
  .sim-stat-grid { grid-template-columns: repeat(2, 1fr); }
  .sim-h2h-controls { flex-direction: column; }
}

/* Print */
@media print {
  .sim-tab-nav, .sim-toolbar, .sim-btn, .sim-eye-btn, .sim-filter, .sim-footer { display: none !important; }
  .sim-panel { display: block !important; page-break-inside: avoid; margin-bottom: 20px; }
  .sim-content { box-shadow: none; }
}'

  css <- gsub("BRAND_TOKEN12", paste0(brand, "12"), css, fixed = TRUE)
  gsub("BRAND_TOKEN", brand, css, fixed = TRUE)
}
