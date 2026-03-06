# ==============================================================================
# WEIGHTING HTML REPORT - PAGE BUILDER
# ==============================================================================
# Assembles the complete HTML page: CSS, header, tab navigation,
# content panels, footer, and JavaScript.
#
# Follows Turas visual conventions from tabs/tracker modules:
# - Muted palette, rounded corners, soft charcoal labels
# - BRAND/ACCENT token replacement via gsub()
# - Self-contained single-file HTML
# ==============================================================================

#' Build Complete HTML Page
#'
#' Assembles all components into a browsable htmltools tag list.
#'
#' @param html_data List from transform_for_html()
#' @param tables List of HTML table strings (summary, per-weight)
#' @param charts List of SVG chart strings
#' @param config List with brand_colour, accent_colour, etc.
#' @param source_filename Character, base filename for Save
#' @return htmltools tagList (browsable)
#' @keywords internal
build_weighting_page <- function(html_data, tables, charts, config,
                                  source_filename = NULL) {

  brand <- config$brand_colour %||% "#1e3a5f"
  accent <- config$accent_colour %||% "#2aa198"

  # Build CSS
  css_tag <- build_weighting_css(brand, accent)

  # Build meta tags for hub integration
  meta_tags <- build_meta_tags(html_data, source_filename)

  # Build header
  header_html <- build_weighting_header(html_data$summary, brand)

  # Build tab navigation
  tab_nav <- build_report_tab_nav(brand)

  # Build tab panels
  summary_panel <- build_summary_panel(html_data, tables$summary_table)
  details_panel <- build_details_panel(html_data, tables, charts)
  notes_panel <- build_notes_panel(html_data)

  # Build footer
  footer_html <- build_weighting_footer(html_data$summary)

  # Load JS
  js_tag <- build_weighting_js()

  # Assemble page
  htmltools::browsable(htmltools::tagList(
    htmltools::tags$meta(charset = "UTF-8"),
    htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    htmltools::tags$title(paste("Turas Weighting Report -",
                                 html_data$summary$project_name)),
    meta_tags,
    css_tag,
    htmltools::HTML(header_html),
    htmltools::HTML(tab_nav),
    htmltools::tags$div(class = "wt-content",
      htmltools::HTML(summary_panel),
      htmltools::HTML(details_panel),
      htmltools::HTML(notes_panel)
    ),
    htmltools::HTML(footer_html),
    js_tag
  ))
}


# ==============================================================================
# META TAGS
# ==============================================================================

#' @keywords internal
build_meta_tags <- function(html_data, source_filename = NULL) {
  tags <- htmltools::tagList(
    htmltools::tags$meta(name = "turas-report-type", content = "weighting"),
    htmltools::tags$meta(name = "turas-generated",
                          content = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")),
    htmltools::tags$meta(name = "turas-weights",
                          content = as.character(html_data$summary$n_weights)),
    htmltools::tags$meta(name = "turas-total-n",
                          content = as.character(html_data$summary$n_records))
  )

  if (!is.null(source_filename) && nzchar(source_filename)) {
    tags <- htmltools::tagList(tags,
      htmltools::tags$meta(name = "turas-source-filename", content = source_filename)
    )
  }

  tags
}


# ==============================================================================
# CSS
# ==============================================================================

#' @keywords internal
build_weighting_css <- function(brand_colour, accent_colour) {
  css_text <- '
:root {
  --wt-brand: BRAND;
  --wt-accent: ACCENT;
  --wt-text-primary: #1e293b;
  --wt-text-secondary: #64748b;
  --wt-bg-surface: #ffffff;
  --wt-bg-muted: #f8f9fa;
  --wt-border: #e2e8f0;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background: #f8f7f5;
  color: var(--wt-text-primary);
  line-height: 1.5;
}

/* Header */
.wt-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
  border-bottom: 3px solid BRAND;
  padding: 24px 32px 20px;
}
.wt-header-inner {
  max-width: 1200px;
  margin: 0 auto;
}
.wt-header-top {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 12px;
}
.wt-header-logo {
  width: 56px;
  height: 56px;
  background: rgba(255,255,255,0.08);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.wt-header-logo svg {
  width: 32px;
  height: 32px;
}
.wt-header-title {
  color: #fff;
  font-size: 24px;
  font-weight: 700;
}
.wt-header-subtitle {
  color: rgba(255,255,255,0.50);
  font-size: 12px;
  font-weight: 400;
  letter-spacing: 0.5px;
  text-transform: uppercase;
}
.wt-header-project {
  color: #fff;
  font-size: 20px;
  font-weight: 700;
  margin-bottom: 12px;
}
.wt-header-badges {
  display: inline-flex;
  align-items: center;
  border: 1px solid rgba(255,255,255,0.15);
  border-radius: 6px;
  background: rgba(255,255,255,0.05);
  overflow: hidden;
}
.wt-badge {
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(255,255,255,0.85);
  white-space: nowrap;
}
.wt-badge-sep {
  width: 1px;
  height: 16px;
  background: rgba(255,255,255,0.20);
}

/* Tab Navigation */
.report-tabs {
  display: flex;
  align-items: center;
  background: #fff;
  border-bottom: 2px solid #e2e8f0;
  padding: 0 24px;
  max-width: 1200px;
  margin: 0 auto;
}
.report-tab {
  padding: 12px 24px;
  border: none;
  background: transparent;
  color: #1e293b;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  border-bottom: 3px solid transparent;
  transition: all 0.15s;
  font-family: inherit;
}
.report-tab:hover:not(.active) {
  background: #f8f8f8;
  color: BRAND;
}
.report-tab.active {
  color: BRAND;
  border-bottom-color: BRAND;
}
.tab-panel { display: none; }
.tab-panel.active { display: block; }

/* Content Area */
.wt-content {
  max-width: 1200px;
  margin: 0 auto;
  padding: 24px;
}

/* Cards */
.wt-card {
  background: #fff;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  padding: 24px;
  margin-bottom: 20px;
}
.wt-card h3 {
  font-size: 16px;
  font-weight: 700;
  color: #1e293b;
  margin-bottom: 16px;
  padding-bottom: 8px;
  border-bottom: 2px solid BRAND;
}

/* Tables */
.wt-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}
.wt-table thead th {
  background: #f8f9fa;
  color: #64748b;
  font-weight: 600;
  text-transform: uppercase;
  font-size: 11px;
  letter-spacing: 0.5px;
  padding: 10px 12px;
  text-align: left;
  border-bottom: 2px solid #e2e8f0;
}
.wt-table tbody td {
  padding: 8px 12px;
  border-bottom: 1px solid #f1f5f9;
}
.wt-table tbody tr:hover {
  background: #f8fafb;
}
.wt-num {
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.wt-label-col {
  font-weight: 600;
  color: #1e293b;
}
.wt-table-compact {
  font-size: 12px;
}
.wt-table-compact td:first-child {
  color: #64748b;
  font-weight: 500;
}

/* Quality badges */
.quality-good {
  color: #27ae60;
  font-weight: 700;
  text-align: center;
}
.quality-warn {
  color: #f39c12;
  font-weight: 700;
  text-align: center;
}
.quality-poor {
  color: #e74c3c;
  font-weight: 700;
  text-align: center;
}

/* Diff badges (margins table) */
.diff-good { color: #27ae60; font-weight: 600; }
.diff-warn { color: #f39c12; font-weight: 600; }
.diff-poor { color: #e74c3c; font-weight: 600; }

/* Diagnostics grid */
.wt-diag-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 16px;
}
.wt-diag-card {
  background: #f8f9fa;
  border-radius: 6px;
  padding: 16px;
  border: 1px solid #e2e8f0;
}
.wt-diag-card h4 {
  font-size: 13px;
  font-weight: 700;
  color: BRAND;
  margin-bottom: 10px;
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

/* Weight detail nav */
.wt-nav {
  display: flex;
  gap: 8px;
  margin-bottom: 20px;
  flex-wrap: wrap;
}
.wt-nav-btn {
  padding: 8px 16px;
  border: 1px solid #e2e8f0;
  background: #fff;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s;
  font-family: inherit;
  color: #64748b;
}
.wt-nav-btn:hover:not(.active) {
  background: #f8f9fa;
  border-color: BRAND;
  color: BRAND;
}
.wt-nav-btn.active {
  background: BRAND;
  border-color: BRAND;
  color: #fff;
}
.wt-detail-panel { display: none; }
.wt-detail-panel.active { display: block; }

/* Stats row */
.wt-stats-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 16px;
  margin-bottom: 20px;
}
.wt-stat-card {
  background: #f8f9fa;
  border-radius: 6px;
  padding: 16px;
  text-align: center;
  border: 1px solid #e2e8f0;
}
.wt-stat-value {
  font-size: 28px;
  font-weight: 700;
  color: BRAND;
}
.wt-stat-label {
  font-size: 12px;
  color: #64748b;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  margin-top: 4px;
}

/* Trimming info */
.wt-trim-info {
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-radius: 6px;
  padding: 12px 16px;
  margin-top: 16px;
  font-size: 13px;
  color: #92400e;
}
.wt-trim-info strong {
  color: #78350f;
}

/* Notes panel */
.wt-note-section {
  margin-bottom: 24px;
}
.wt-note-section h4 {
  font-size: 14px;
  font-weight: 700;
  color: BRAND;
  margin-bottom: 8px;
  padding-bottom: 4px;
  border-bottom: 1px solid #e2e8f0;
}
.wt-note-item {
  padding: 8px 0;
  font-size: 13px;
  color: #374151;
  line-height: 1.6;
  border-bottom: 1px solid #f1f5f9;
}
.wt-note-item:last-child {
  border-bottom: none;
}

/* Method auto-doc */
.wt-method-doc {
  background: #f8f9fa;
  border-radius: 6px;
  padding: 20px;
  border: 1px solid #e2e8f0;
  margin-bottom: 20px;
}
.wt-method-doc h4 {
  font-size: 14px;
  font-weight: 700;
  color: BRAND;
  margin-bottom: 12px;
}
.wt-method-doc p {
  font-size: 13px;
  color: #374151;
  line-height: 1.7;
  margin-bottom: 8px;
}
.wt-method-doc ul {
  margin: 8px 0 8px 20px;
  font-size: 13px;
  color: #374151;
}
.wt-method-doc li {
  margin-bottom: 4px;
}

/* Footer */
.wt-footer {
  max-width: 1200px;
  margin: 0 auto;
  padding: 16px 24px;
  text-align: center;
  color: #94a3b8;
  font-size: 11px;
  border-top: 1px solid #e2e8f0;
}

/* Save button */
.wt-save-btn {
  position: fixed;
  bottom: 20px;
  right: 20px;
  padding: 10px 20px;
  background: BRAND;
  color: #fff;
  border: none;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  box-shadow: 0 2px 8px rgba(0,0,0,0.15);
  transition: opacity 0.2s;
  font-family: inherit;
}
.wt-save-btn:hover { opacity: 0.9; }

@media print {
  .report-tabs, .wt-nav, .wt-save-btn { display: none !important; }
  .tab-panel, .wt-detail-panel { display: block !important; }
  .wt-header { break-after: avoid; }
  .wt-card { break-inside: avoid; page-break-inside: avoid; }
  body { background: #fff; }
}
'

  # Token replacement via gsub (avoids sprintf 8192-char limit)
  css_text <- gsub("ACCENT", accent_colour, css_text, fixed = TRUE)
  css_text <- gsub("BRAND", brand_colour, css_text, fixed = TRUE)

  htmltools::tags$style(htmltools::HTML(css_text))
}


# ==============================================================================
# HEADER
# ==============================================================================

#' @keywords internal
build_weighting_header <- function(summary, brand_colour) {
  # Scale icon (weighing scales)
  scale_icon <- '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v18"/><path d="M5 7l7-4 7 4"/><path d="M5 7l-2 8h4l-2-8z"/><path d="M19 7l-2 8h4l-2-8z"/></svg>'

  badges <- sprintf(
    '<div class="wt-header-badges">
      <span class="wt-badge">n = %s</span>
      <span class="wt-badge-sep"></span>
      <span class="wt-badge">%d Weight%s</span>
      <span class="wt-badge-sep"></span>
      <span class="wt-badge">Generated %s</span>
    </div>',
    format(summary$n_records, big.mark = ","),
    summary$n_weights,
    if (summary$n_weights != 1) "s" else "",
    format(Sys.Date(), "%b %Y")
  )

  sprintf(
    '<div class="wt-header">
      <div class="wt-header-inner">
        <div class="wt-header-top">
          <div class="wt-header-logo">%s</div>
          <div>
            <div class="wt-header-title">Turas Weighting</div>
            <div class="wt-header-subtitle">Sample Weighting Report</div>
          </div>
        </div>
        <div class="wt-header-project">%s</div>
        %s
      </div>
    </div>',
    scale_icon,
    htmlEscape(summary$project_name),
    badges
  )
}


# ==============================================================================
# TAB NAVIGATION
# ==============================================================================

#' @keywords internal
build_report_tab_nav <- function(brand_colour) {
  '<div class="report-tabs">
    <button class="report-tab active" data-tab="summary" onclick="switchReportTab(\'summary\')">Summary</button>
    <button class="report-tab" data-tab="details" onclick="switchReportTab(\'details\')">Weight Details</button>
    <button class="report-tab" data-tab="notes" onclick="switchReportTab(\'notes\')">Method Notes</button>
  </div>'
}


# ==============================================================================
# SUMMARY TAB
# ==============================================================================

#' @keywords internal
build_summary_panel <- function(html_data, summary_table) {
  summary <- html_data$summary

  # Stats cards
  stats <- sprintf(
    '<div class="wt-stats-row">
      <div class="wt-stat-card">
        <div class="wt-stat-value">%s</div>
        <div class="wt-stat-label">Records</div>
      </div>
      <div class="wt-stat-card">
        <div class="wt-stat-value">%d</div>
        <div class="wt-stat-label">Weight%s</div>
      </div>
      <div class="wt-stat-card">
        <div class="wt-stat-value">%s</div>
        <div class="wt-stat-label">Weight Names</div>
      </div>
    </div>',
    format(summary$n_records, big.mark = ","),
    summary$n_weights,
    if (summary$n_weights != 1) "s" else "",
    paste(summary$weight_names, collapse = ", ")
  )

  sprintf(
    '<div id="tab-summary" class="tab-panel active">
      %s
      <div class="wt-card">
        <h3>All Weights Overview</h3>
        %s
      </div>
    </div>',
    stats,
    if (nzchar(summary_table %||% "")) summary_table else "<p>No summary data available.</p>"
  )
}


# ==============================================================================
# DETAILS TAB
# ==============================================================================

#' @keywords internal
build_details_panel <- function(html_data, tables, charts) {
  weight_details <- html_data$weight_details
  if (length(weight_details) == 0) {
    return('<div id="tab-details" class="tab-panel"><p>No weight details available.</p></div>')
  }

  # Build weight navigation buttons
  nav_buttons <- ""
  first <- TRUE
  for (detail in weight_details) {
    wid <- sanitise_id(detail$weight_name)
    active <- if (first) " active" else ""
    nav_buttons <- paste0(nav_buttons, sprintf(
      '<button class="wt-nav-btn%s" data-weight="%s" onclick="switchWeightDetail(\'%s\')">%s</button>\n',
      active, wid, wid, htmlEscape(detail$weight_name)
    ))
    first <- FALSE
  }
  nav_html <- sprintf('<div class="wt-nav">%s</div>', nav_buttons)

  # Build per-weight detail panels
  panels <- ""
  first <- TRUE
  for (detail in weight_details) {
    wid <- sanitise_id(detail$weight_name)
    active <- if (first) " active" else ""

    panel_content <- ""

    # Method badge
    panel_content <- paste0(panel_content, sprintf(
      '<p style="margin-bottom:16px;"><strong>Method:</strong> <span style="display:inline-block; padding:2px 10px; background:#f0f9ff; border:1px solid #bae6fd; border-radius:4px; font-size:12px; font-weight:600; color:#0369a1;">%s</span></p>',
      htmlEscape(toupper(detail$method))
    ))

    # Chart (histogram)
    chart_key <- detail$weight_name
    if (!is.null(charts[[chart_key]]) && nzchar(charts[[chart_key]])) {
      panel_content <- paste0(panel_content, sprintf(
        '<div class="wt-card"><h3>Distribution</h3>%s</div>',
        charts[[chart_key]]
      ))
    }

    # Diagnostics table
    diag_key <- paste0("diagnostics_", detail$weight_name)
    if (!is.null(tables[[diag_key]]) && nzchar(tables[[diag_key]])) {
      panel_content <- paste0(panel_content, sprintf(
        '<div class="wt-card"><h3>Diagnostics</h3>%s</div>',
        tables[[diag_key]]
      ))
    }

    # Margins table (rim weights)
    margins_key <- paste0("margins_", detail$weight_name)
    if (!is.null(tables[[margins_key]]) && nzchar(tables[[margins_key]])) {
      panel_content <- paste0(panel_content, sprintf(
        '<div class="wt-card">%s</div>',
        tables[[margins_key]]
      ))
    }

    # Stratum table (design weights)
    stratum_key <- paste0("stratum_", detail$weight_name)
    if (!is.null(tables[[stratum_key]]) && nzchar(tables[[stratum_key]])) {
      panel_content <- paste0(panel_content, sprintf(
        '<div class="wt-card">%s</div>',
        tables[[stratum_key]]
      ))
    }

    # Cell table (cell weights)
    cell_key <- paste0("cell_", detail$weight_name)
    if (!is.null(tables[[cell_key]]) && nzchar(tables[[cell_key]])) {
      panel_content <- paste0(panel_content, sprintf(
        '<div class="wt-card">%s</div>',
        tables[[cell_key]]
      ))
    }

    # Trimming info
    if (!is.null(detail$trimming)) {
      trim <- detail$trimming
      panel_content <- paste0(panel_content, sprintf(
        '<div class="wt-trim-info">
          <strong>Trimming Applied:</strong> %s method. %d weight%s trimmed (%.1f%% of cases).
        </div>',
        htmlEscape(trim$method %||% "unknown"),
        trim$n_trimmed %||% 0,
        if ((trim$n_trimmed %||% 0) != 1) "s" else "",
        (trim$pct_trimmed %||% 0)
      ))
    }

    panels <- paste0(panels, sprintf(
      '<div id="wt-detail-%s" class="wt-detail-panel%s">%s</div>\n',
      wid, active, panel_content
    ))
    first <- FALSE
  }

  sprintf(
    '<div id="tab-details" class="tab-panel">%s%s</div>',
    nav_html, panels
  )
}


# ==============================================================================
# NOTES TAB
# ==============================================================================

#' @keywords internal
build_notes_panel <- function(html_data) {
  content <- ""

  # Auto-generated method documentation
  method_doc <- build_method_documentation(html_data$weight_details)
  if (nzchar(method_doc)) {
    content <- paste0(content, sprintf(
      '<div class="wt-card"><h3>Method Documentation</h3>%s</div>',
      method_doc
    ))
  }

  # User-supplied notes
  notes <- html_data$notes
  if (!is.null(notes) && is.data.frame(notes) && nrow(notes) > 0) {
    notes_html <- ""
    sections <- unique(notes$Section)
    for (section in sections) {
      section_notes <- notes[notes$Section == section, ]
      items <- ""
      for (j in seq_len(nrow(section_notes))) {
        items <- paste0(items, sprintf(
          '<div class="wt-note-item">%s</div>\n',
          htmlEscape(section_notes$Note[j])
        ))
      }
      notes_html <- paste0(notes_html, sprintf(
        '<div class="wt-note-section"><h4>%s</h4>%s</div>',
        htmlEscape(section), items
      ))
    }
    content <- paste0(content, sprintf(
      '<div class="wt-card"><h3>Analyst Notes</h3>%s</div>',
      notes_html
    ))
  }

  if (!nzchar(content)) {
    content <- '<div class="wt-card"><h3>Method Notes</h3><p style="color:#64748b;">No method notes or analyst assumptions have been provided.</p></div>'
  }

  sprintf('<div id="tab-notes" class="tab-panel">%s</div>', content)
}


#' Build Auto-Generated Method Documentation
#'
#' @param weight_details List of per-weight detail structures
#' @return Character, HTML string
#' @keywords internal
build_method_documentation <- function(weight_details) {
  if (length(weight_details) == 0) return("")

  docs <- ""
  for (detail in weight_details) {
    method <- tolower(detail$method)
    wn <- htmlEscape(detail$weight_name)
    diag <- detail$diagnostics

    method_desc <- switch(method,
      "design" = sprintf(
        '<div class="wt-method-doc">
          <h4>%s (Design Weight)</h4>
          <p>Design weights correct for unequal selection probabilities in stratified sampling.
          Each stratum receives a weight proportional to its share in the population relative to
          its share in the sample: <em>w = (Population N / Total Pop) / (Sample N / Total Sample)</em>.</p>
        </div>', wn),
      "rim" = , "rake" = sprintf(
        '<div class="wt-method-doc">
          <h4>%s (Rim / Raking Weight)</h4>
          <p>Rim weights (also known as raking or iterative proportional fitting) adjust the sample
          to match known population margins on multiple variables simultaneously. The algorithm
          iteratively adjusts weights until convergence, using <code>survey::calibrate()</code>.</p>
          %s
        </div>', wn,
        if (!is.null(detail$rim_variables)) {
          paste0("<p><strong>Rim variables:</strong> ",
                 paste(htmlEscape(detail$rim_variables), collapse = ", "), "</p>")
        } else ""
      ),
      "cell" = sprintf(
        '<div class="wt-method-doc">
          <h4>%s (Cell / Interlocked Weight)</h4>
          <p>Cell weights adjust the sample to match the joint (cross-tabulated) population
          distribution across two or more variables. Each unique combination of variable levels
          receives a weight: <em>w = (target%% &times; N) / cell count</em>.</p>
          %s
        </div>', wn,
        if (!is.null(detail$cell_variables)) {
          paste0("<p><strong>Cell variables:</strong> ",
                 paste(htmlEscape(detail$cell_variables), collapse = " &times; "), "</p>")
        } else ""
      ),
      sprintf(
        '<div class="wt-method-doc">
          <h4>%s (%s)</h4>
          <p>Weight calculated using the %s method.</p>
        </div>', wn, htmlEscape(detail$method), htmlEscape(method))
    )

    # Add key diagnostics
    if (!is.null(diag)) {
      method_desc <- paste0(method_desc, sprintf(
        '<ul>
          <li>Total N: %d | Effective N: %d (Efficiency: %.1f%%)</li>
          <li>Design Effect: %.2f | Weight range: %.4f to %.4f</li>
          <li>Quality Assessment: <strong>%s</strong></li>
        </ul>',
        diag$sample_size$n_total,
        diag$effective_sample$effective_n,
        diag$effective_sample$efficiency,
        diag$effective_sample$design_effect,
        diag$distribution$min,
        diag$distribution$max,
        diag$quality$status
      ))
    }

    docs <- paste0(docs, method_desc)
  }

  docs
}


# ==============================================================================
# FOOTER
# ==============================================================================

#' @keywords internal
build_weighting_footer <- function(summary) {
  sprintf(
    '<div class="wt-footer">
      Generated by Turas Weighting &middot; %s &middot; The Research Lamppost (Pty) Ltd
    </div>
    <button class="wt-save-btn" onclick="saveReportHTML()">Save Report</button>',
    htmlEscape(summary$generated)
  )
}


# ==============================================================================
# JAVASCRIPT
# ==============================================================================

#' @keywords internal
build_weighting_js <- function() {
  # Read the external JS file
  js_dir <- NULL

  # Try to find js/ relative to this file
  if (exists(".weighting_html_report_dir", envir = globalenv())) {
    js_dir <- file.path(get(".weighting_html_report_dir", envir = globalenv()), "js")
  }

  if (is.null(js_dir) || !dir.exists(js_dir)) {
    # Fallback: try relative to the calling script
    ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
    if (!is.null(ofile)) {
      js_dir <- file.path(dirname(ofile), "js")
    }
  }

  js_content <- ""
  if (!is.null(js_dir) && dir.exists(js_dir)) {
    js_files <- list.files(js_dir, pattern = "\\.js$", full.names = TRUE)
    for (f in js_files) {
      js_content <- paste0(js_content, "\n// === ", basename(f), " ===\n",
                            paste(readLines(f, warn = FALSE), collapse = "\n"))
    }
  }

  if (!nzchar(js_content)) {
    # Inline fallback if JS files can't be found
    js_content <- '
function switchReportTab(tabName) {
  document.querySelectorAll(".report-tab").forEach(function(btn) {
    btn.classList.toggle("active", btn.getAttribute("data-tab") === tabName);
  });
  document.querySelectorAll(".tab-panel").forEach(function(panel) {
    panel.classList.remove("active");
  });
  var target = document.getElementById("tab-" + tabName);
  if (target) target.classList.add("active");
}
function switchWeightDetail(weightId) {
  document.querySelectorAll(".wt-nav-btn").forEach(function(btn) {
    btn.classList.toggle("active", btn.getAttribute("data-weight") === weightId);
  });
  document.querySelectorAll(".wt-detail-panel").forEach(function(panel) {
    panel.classList.remove("active");
  });
  var target = document.getElementById("wt-detail-" + weightId);
  if (target) target.classList.add("active");
}
function saveReportHTML() {
  var meta = document.querySelector("meta[name=\\"turas-source-filename\\"]");
  var baseName = meta ? meta.getAttribute("content") : "Weighting_Report";
  var blob = new Blob(["<!DOCTYPE html>\\n" + document.documentElement.outerHTML], {type:"text/html"});
  var url = URL.createObjectURL(blob);
  var a = document.createElement("a");
  a.href = url; a.download = baseName + "_Updated.html";
  document.body.appendChild(a); a.click(); document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
document.addEventListener("DOMContentLoaded", function() { switchReportTab("summary"); });
'
  }

  htmltools::tags$script(htmltools::HTML(js_content))
}


# ==============================================================================
# HELPERS
# ==============================================================================

#' Sanitise a string for use as an HTML ID
#' @keywords internal
sanitise_id <- function(x) {
  gsub("[^a-zA-Z0-9]", "-", tolower(x))
}
