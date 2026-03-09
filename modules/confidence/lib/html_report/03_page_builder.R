# ==============================================================================
# CONFIDENCE HTML REPORT - PAGE BUILDER
# ==============================================================================
# Assembles the complete HTML page: CSS, header, tabs, content, JS.
# Self-contained — no external dependencies.
# Uses gsub() token replacement for colours (avoids sprintf 8192 limit).
# ==============================================================================

# Null-coalescing operator (canonical definition in utils.R)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

#' Build Complete Confidence Report HTML Page
#'
#' @param html_data List from transform_confidence_for_html()
#' @param tables List of HTML table strings
#' @param charts List of HTML chart strings
#' @param config List with brand_colour, accent_colour, logo, etc.
#' @param source_filename Character base filename for Save
#' @return Character string of complete HTML document
#' @keywords internal
build_confidence_page <- function(html_data, tables, charts, config,
                                   source_filename = "Confidence_Report") {
  # Robust colour extraction: handle NULL, NA, and empty strings
  brand <- config$brand_colour %||% "#1e3a5f"
  if (is.na(brand) || !nzchar(trimws(brand))) brand <- "#1e3a5f"
  accent <- config$accent_colour %||% "#2aa198"
  if (is.na(accent) || !nzchar(trimws(accent))) accent <- "#2aa198"

  meta_tags <- build_ci_meta_tags(html_data$summary, source_filename)
  css <- build_ci_css(brand, accent)
  header <- build_ci_header(html_data$summary, brand, config)
  nav <- build_ci_tab_nav()
  summary_panel <- build_ci_summary_panel(html_data, tables, charts)
  details_panel <- build_ci_details_panel(html_data, tables, charts, brand)
  notes_panel <- build_ci_notes_panel(html_data, config)
  footer <- build_ci_footer()
  js <- build_ci_js()

  paste0(
    '<!DOCTYPE html>\n<html lang="en">\n<head>\n',
    '<meta charset="UTF-8">\n',
    '<meta name="viewport" content="width=device-width, initial-scale=1">\n',
    meta_tags, '\n',
    '<title>Turas Confidence Analysis</title>\n',
    '<style>\n', css, '\n</style>\n',
    '</head>\n<body>\n',
    header, '\n',
    nav, '\n',
    '<div class="ci-content">\n',
    summary_panel, '\n',
    details_panel, '\n',
    notes_panel, '\n',
    '</div>\n',
    footer, '\n',
    '<script>\n', js, '\n</script>\n',
    '</body>\n</html>'
  )
}


# ==============================================================================
# META TAGS
# ==============================================================================

build_ci_meta_tags <- function(summary, source_filename) {
  paste0(
    '<meta name="turas-report-type" content="confidence">\n',
    '<meta name="turas-generated" content="', summary$generated, '">\n',
    '<meta name="turas-total-n" content="', summary$n_total %||% "", '">\n',
    '<meta name="turas-questions" content="', summary$n_questions %||% 0, '">\n',
    '<meta name="turas-confidence-level" content="', summary$confidence_level, '">\n',
    '<meta name="turas-weighted" content="', if (summary$is_weighted) "Yes" else "No", '">\n',
    '<meta name="turas-sampling-method" content="', summary$sampling_method %||% "Not_Specified", '">\n',
    '<meta name="turas-source-filename" content="', source_filename, '">'
  )
}


# ==============================================================================
# CSS
# ==============================================================================

build_ci_css <- function(brand, accent) {
  css <- '
* { margin: 0; padding: 0; box-sizing: border-box; }
:root {
  --ci-brand: BRAND;
  --ci-accent: ACCENT;
  --ci-text-primary: #1e293b;
  --ci-text-secondary: #64748b;
  --ci-bg-surface: #ffffff;
  --ci-bg-muted: #f8f9fa;
  --ci-border: #e2e8f0;
}
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  background: #f8f7f5;
  color: var(--ci-text-primary);
  line-height: 1.6;
}

/* Header */
.ci-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
  border-bottom: 3px solid BRAND;
  padding: 24px 32px 20px;
}
.ci-header-inner {
  max-width: 1200px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  gap: 20px;
}
.ci-header-logo {
  width: 56px; height: 56px;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.ci-header-text { flex: 1; }
.ci-header-title {
  color: #fff; font-size: 24px; font-weight: 700;
}
.ci-header-subtitle {
  color: rgba(255,255,255,0.5); font-size: 12px; margin-top: 2px;
}
.ci-header-project {
  color: #fff; font-size: 20px; font-weight: 700; margin-top: 4px;
}
.ci-header-prepared {
  color: rgba(255,255,255,0.65); font-size: 13px; margin-top: 4px;
}
.ci-header-badges {
  display: inline-flex; align-items: center;
  margin-top: 12px;
  border: 1px solid rgba(255,255,255,0.15);
  border-radius: 6px;
  background: rgba(255,255,255,0.05);
  overflow: hidden;
}
.ci-badge {
  padding: 4px 12px;
  color: rgba(255,255,255,0.85);
  font-size: 12px;
  font-weight: 600;
  white-space: nowrap;
}
.ci-badge-sep {
  width: 1px; height: 16px;
  background: rgba(255,255,255,0.20);
}
#ci-save-badge {
  display: none;
  padding: 6px 14px;
  color: rgba(255,255,255,0.85);
  font-size: 12px;
  font-weight: 500;
}

/* Tab Navigation */
.report-tabs {
  display: flex; align-items: center;
  background: #fff;
  border-bottom: 2px solid var(--ci-border);
  padding: 0 24px;
  max-width: 1200px;
  margin: 0 auto;
}
.report-tab {
  padding: 12px 24px;
  border: none; background: transparent;
  color: var(--ci-text-primary);
  font-size: 14px; font-weight: 600;
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
.ci-save-tab {
  margin-left: auto;
  color: BRAND;
  border-bottom-color: transparent !important;
}
.ci-save-tab:hover { background: #f0f9ff; }

/* Content */
.ci-content {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px 24px;
}
.tab-panel { display: none; }
.tab-panel.active { display: block; }

/* Cards */
.ci-card {
  background: var(--ci-bg-surface);
  border-radius: 8px;
  border: 1px solid var(--ci-border);
  padding: 24px;
  margin-bottom: 20px;
}
.ci-card h3 {
  font-size: 16px; font-weight: 700;
  color: var(--ci-text-primary);
  margin-bottom: 16px;
  padding-bottom: 8px;
  border-bottom: 2px solid BRAND;
}

/* Callouts */
.ci-callout {
  background: #f0f9ff;
  border: 1px solid #bae6fd;
  border-left: 3px solid BRAND;
  border-radius: 6px;
  padding: 12px 16px;
  margin-bottom: 16px;
  font-size: 12px;
  line-height: 1.7;
  color: #334155;
}
.ci-callout strong { color: #1e293b; }

.ci-callout-warning {
  background: #fff7ed;
  border: 1px solid #fed7aa;
  border-left: 3px solid #f59e0b;
}
.ci-callout-result {
  border-left: 3px solid BRAND;
  margin-bottom: 8px;
}
.ci-callout-method {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-left: 3px solid #94a3b8;
  margin-bottom: 8px;
  font-size: 11.5px;
}
.ci-callout-method p { margin: 0 0 6px 0; }
.ci-callout-method p:last-child { margin-bottom: 0; }
.ci-callout-sampling {
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-left: 3px solid #f59e0b;
  font-size: 11.5px;
}

/* Tables */
.ci-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
  margin-bottom: 16px;
}
.ci-table thead th {
  background: var(--ci-bg-muted);
  padding: 8px 12px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--ci-text-secondary);
  border-bottom: 2px solid var(--ci-border);
  text-align: left;
}
.ci-table tbody td {
  padding: 8px 12px;
  border-bottom: 1px solid var(--ci-border);
  vertical-align: middle;
}
.ci-table tbody tr:hover { background: #fafbfc; }
.ci-num {
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.ci-table thead th.ci-num {
  text-align: right;
}
.ci-label-col { font-weight: 600; color: var(--ci-text-primary); }
.ci-table-compact { font-size: 12px; }
.ci-table-compact td { padding: 6px 10px; }
.ci-row-highlight { background: #f8f9fa; }

/* Quality Badges */
.ci-quality-good { color: #27ae60; font-weight: 700; }
.ci-quality-warn { color: #f39c12; font-weight: 700; }
.ci-quality-poor { color: #e74c3c; font-weight: 700; }
.ci-diff-good { color: #27ae60; font-weight: 600; }
.ci-diff-warn { color: #f39c12; font-weight: 600; }
.ci-diff-poor { color: #e74c3c; font-weight: 600; }

/* Question Navigation (Details Tab) */
.ci-nav {
  display: flex; flex-wrap: wrap; gap: 6px;
  margin-bottom: 20px;
}
.ci-nav-btn {
  padding: 8px 16px;
  border: 1px solid var(--ci-border);
  border-radius: 6px;
  background: var(--ci-bg-surface);
  color: var(--ci-text-primary);
  font-size: 12px; font-weight: 600;
  cursor: pointer;
  transition: all 0.15s;
  font-family: inherit;
}
.ci-nav-btn:hover { background: #f8fafc; border-color: BRAND; }
.ci-nav-btn.active {
  background: BRAND; color: #fff;
  border-color: BRAND;
}
.ci-detail-panel { display: none; }
.ci-detail-panel.active { display: block; }

/* Comments */
.ci-comments-box {
  width: 100%;
  min-height: 120px;
  padding: 12px 16px;
  border: 1px solid var(--ci-border);
  border-radius: 6px;
  font-family: inherit;
  font-size: 13px;
  line-height: 1.6;
  color: var(--ci-text-primary);
  background: #fff;
  resize: vertical;
}
.ci-comments-box:focus {
  outline: none;
  border-color: BRAND;
  box-shadow: 0 0 0 2px rgba(30,58,95,0.10);
}

/* Footer */
.ci-footer {
  max-width: 1200px;
  margin: 0 auto;
  padding: 16px 24px;
  text-align: center;
  font-size: 11px;
  color: #94a3b8;
  border-top: 1px solid #e2e8f0;
}

/* Stats row */
.ci-stats-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 16px;
  margin-bottom: 20px;
}
.ci-stat-card {
  background: var(--ci-bg-surface);
  border: 1px solid var(--ci-border);
  border-radius: 8px;
  padding: 16px;
  text-align: center;
}
.ci-stat-value {
  font-size: 28px; font-weight: 700;
  color: BRAND;
}
.ci-stat-label {
  font-size: 11px; font-weight: 600;
  color: var(--ci-text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-top: 4px;
}

/* Method docs */
.ci-method-doc {
  background: var(--ci-bg-muted);
  border: 1px solid var(--ci-border);
  border-radius: 6px;
  padding: 16px;
  margin-bottom: 12px;
}
.ci-method-doc h4 {
  font-size: 14px; font-weight: 700;
  color: var(--ci-text-primary);
  margin-bottom: 8px;
}
.ci-method-doc p {
  font-size: 12px; line-height: 1.7;
  color: #334155;
  margin-bottom: 8px;
}
.ci-method-doc p:last-child { margin-bottom: 0; }

/* Print */
@media print {
  .report-tabs, .ci-save-tab, .ci-nav { display: none !important; }
  .tab-panel { display: block !important; page-break-inside: avoid; }
  .ci-detail-panel { display: block !important; }
  .ci-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
}
'

  # Token replacement (avoids sprintf 8192 char limit)
  css <- gsub("BRAND", brand, css, fixed = TRUE)
  css <- gsub("ACCENT", accent, css, fixed = TRUE)
  css
}


# ==============================================================================
# HEADER
# ==============================================================================

build_ci_header <- function(summary, brand, config) {
  # Logo: custom or fallback SVG checkmark
  logo_html <- '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="40" height="40"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>'

  if (!is.null(config$logo_file) && file.exists(config$logo_file)) {
    tryCatch({
      ext <- tolower(tools::file_ext(config$logo_file))
      mime <- switch(ext, png = "image/png", jpg = "image/jpeg",
                     jpeg = "image/jpeg", svg = "image/svg+xml", "image/png")
      b64 <- base64enc::base64encode(config$logo_file)
      logo_html <- sprintf(
        '<img src="data:%s;base64,%s" alt="Logo" style="max-width:40px; max-height:40px; object-fit:contain;"/>',
        mime, b64
      )
    }, error = function(e) NULL)
  }

  # Prepared by/for
  prepared <- ""
  researcher <- config$researcher_name %||% config$company_name %||% ""
  client <- config$client_name %||% ""
  if (nzchar(researcher) && nzchar(client)) {
    prepared <- sprintf('<div class="ci-header-prepared">Prepared by %s for %s</div>',
                         htmlEscape(researcher), htmlEscape(client))
  } else if (nzchar(researcher)) {
    prepared <- sprintf('<div class="ci-header-prepared">Prepared by %s</div>',
                         htmlEscape(researcher))
  } else if (nzchar(client)) {
    prepared <- sprintf('<div class="ci-header-prepared">Prepared for %s</div>',
                         htmlEscape(client))
  }

  # Badges (using separator divs matching weighting module pattern)
  sep <- '<div class="ci-badge-sep"></div>'
  badge_items <- character()
  if (!is.na(summary$n_total)) {
    badge_items <- c(badge_items, sprintf('<span class="ci-badge">n = %s</span>',
                                 format(summary$n_total, big.mark = ",")))
  }
  badge_items <- c(badge_items, sprintf('<span class="ci-badge">%d Questions</span>', summary$n_questions))
  badge_items <- c(badge_items, sprintf('<span class="ci-badge">%d%% Confidence</span>',
                               round(summary$confidence_level * 100)))
  if (summary$is_weighted) {
    badge_items <- c(badge_items, '<span class="ci-badge">Weighted</span>')
  }
  # Sampling method badge (skip if Not_Specified)
  sm <- summary$sampling_method %||% "Not_Specified"
  if (!is.na(sm) && nzchar(sm) && sm != "Not_Specified") {
    sm_label <- switch(sm,
      "Random" = "Random Sample",
      "Stratified" = "Stratified Random",
      "Cluster" = "Cluster Sample",
      "Quota" = "Quota Sample",
      "Online_Panel" = "Online Panel",
      "Self_Selected" = "Self-Selected",
      "Census" = "Census",
      sm  # fallback to raw value
    )
    badge_items <- c(badge_items, sprintf('<span class="ci-badge">%s</span>',
                                           htmlEscape(sm_label)))
  }
  # Generated date
  gen_date <- tryCatch(
    format(as.POSIXct(summary$generated), "%b %Y"),
    error = function(e) format(Sys.time(), "%b %Y")
  )
  badge_items <- c(badge_items, sprintf('<span class="ci-badge">Generated %s</span>', gen_date))
  badge_items <- c(badge_items, '<span id="ci-save-badge"></span>')
  badges <- paste(badge_items, collapse = sep)

  sprintf(
    '<div class="ci-header">
      <div class="ci-header-inner">
        <div class="ci-header-logo">%s</div>
        <div class="ci-header-text">
          <div class="ci-header-title">Turas Confidence Analysis</div>
          <div class="ci-header-subtitle">Statistical confidence interval report</div>
          <div class="ci-header-project">%s</div>
          %s
          <div class="ci-header-badges">%s</div>
        </div>
      </div>
    </div>',
    logo_html,
    htmlEscape(summary$project_name),
    prepared,
    badges
  )
}


# ==============================================================================
# TAB NAVIGATION
# ==============================================================================

build_ci_tab_nav <- function() {
  '<div class="report-tabs">
    <button class="report-tab active" data-tab="summary" onclick="switchReportTab(\'summary\')">Summary</button>
    <button class="report-tab" data-tab="details" onclick="switchReportTab(\'details\')">Question Details</button>
    <button class="report-tab" data-tab="notes" onclick="switchReportTab(\'notes\')">Method Notes</button>
    <button class="report-tab ci-save-tab" onclick="saveReportHTML()">Save Report</button>
  </div>'
}


# ==============================================================================
# SUMMARY PANEL
# ==============================================================================

build_ci_summary_panel <- function(html_data, tables, charts) {
  summary <- html_data$summary
  parts <- character()

  # Stats cards
  stat_cards <- character()
  if (!is.na(summary$n_total)) {
    stat_cards <- c(stat_cards, sprintf(
      '<div class="ci-stat-card"><div class="ci-stat-value">%s</div><div class="ci-stat-label">Sample Size</div></div>',
      format(summary$n_total, big.mark = ",")
    ))
  }
  if (summary$is_weighted && !is.na(summary$n_effective)) {
    stat_cards <- c(stat_cards, sprintf(
      '<div class="ci-stat-card"><div class="ci-stat-value">%s</div><div class="ci-stat-label">Effective N</div></div>',
      format(summary$n_effective, big.mark = ",")
    ))
  }
  stat_cards <- c(stat_cards, sprintf(
    '<div class="ci-stat-card"><div class="ci-stat-value">%d</div><div class="ci-stat-label">Questions</div></div>',
    summary$n_questions
  ))
  if (summary$is_weighted && !is.na(summary$deff)) {
    stat_cards <- c(stat_cards, sprintf(
      '<div class="ci-stat-card"><div class="ci-stat-value">%.2f</div><div class="ci-stat-label">Design Effect</div></div>',
      summary$deff
    ))
  }
  parts <- c(parts, sprintf('<div class="ci-stats-row">%s</div>', paste(stat_cards, collapse = "\n")))

  # Study-level card (if weighted)
  if (summary$is_weighted && nzchar(tables$study_level %||% "")) {
    deff_val <- summary$deff %||% 1
    efficiency <- if (!is.na(deff_val) && deff_val > 0) round(100 / deff_val, 1) else NA

    callout_text <- sprintf(
      '<strong>What these numbers mean:</strong> The Design Effect (DEFF) of %.2f means weighting reduces your effective sample from %s to %s. ',
      deff_val,
      format(summary$n_total, big.mark = ","),
      format(summary$n_effective, big.mark = ",")
    )
    if (!is.na(efficiency)) {
      if (efficiency >= 85) {
        callout_text <- paste0(callout_text, sprintf("An efficiency of %.0f%% is excellent &mdash; weighting has minimal impact on your results.", efficiency))
      } else if (efficiency >= 70) {
        callout_text <- paste0(callout_text, sprintf("An efficiency of %.0f%% is acceptable, though precision is somewhat reduced by weighting.", efficiency))
      } else {
        callout_text <- paste0(callout_text, sprintf("<strong>Warning:</strong> An efficiency of %.0f%% means weighting significantly reduces statistical power. Consider whether your weighting scheme is appropriate.", efficiency))
      }
    }
    callout_text <- paste0(callout_text,
      " <strong>Important:</strong> These calculations assume a probability-based sample design. If respondents were not randomly selected, the design effect only captures the impact of weighting, not the full extent of sampling bias."
    )

    parts <- c(parts, sprintf(
      '<div class="ci-card"><h3>Study-Level Statistics</h3><div class="ci-callout">%s</div>%s</div>',
      callout_text, tables$study_level
    ))
  }

  # Summary table
  if (nzchar(tables$summary %||% "")) {
    parts <- c(parts, sprintf(
      '<div class="ci-card"><h3>Results Overview</h3>
        <div class="ci-callout">This table shows all questions analysed with their confidence intervals and quality assessments. The Quality column indicates whether the sample is large enough for reliable estimates. Click the <strong>Question Details</strong> tab above for full method comparisons and explanations.</div>
        %s
      </div>',
      tables$summary
    ))
  }

  # Forest plot
  if (nzchar(charts$forest_plot %||% "")) {
    parts <- c(parts, sprintf(
      '<div class="ci-card"><h3>Confidence Interval Overview</h3>
        <div class="ci-callout">Each dot shows the estimated value, and the horizontal bar shows the confidence interval. Shorter bars indicate more precise estimates. If a bar is very wide, the true value is uncertain &mdash; a larger sample would narrow it.</div>
        %s
      </div>',
      charts$forest_plot
    ))
  }

  # Representativeness
  if (nzchar(tables$representativeness %||% "")) {
    parts <- c(parts, sprintf(
      '<div class="ci-card"><h3>Sample Representativeness</h3>
        <div class="ci-callout"><strong>Reading this table:</strong> Green (&lt;2pp) means the weighted sample closely matches the target population. Amber (2&ndash;5pp) is a moderate departure. Red (&gt;5pp) means a significant gap between sample and population, which may affect the accuracy of estimates for that subgroup. <strong>Note:</strong> Representativeness checks only verify known demographic quotas &mdash; they cannot detect biases in unmeasured characteristics.</div>
        %s
      </div>',
      tables$representativeness
    ))
  }

  sprintf('<div id="tab-summary" class="tab-panel active">%s</div>',
          paste(parts, collapse = "\n"))
}


# ==============================================================================
# DETAILS PANEL
# ==============================================================================

build_ci_details_panel <- function(html_data, tables, charts, brand) {
  questions <- html_data$questions
  if (length(questions) == 0) {
    return('<div id="tab-details" class="tab-panel"><div class="ci-card"><p>No question results to display.</p></div></div>')
  }

  conf_level <- html_data$methodology$confidence_level

  # Question nav buttons
  nav_buttons <- character()
  q_ids <- names(questions)
  for (i in seq_along(q_ids)) {
    active <- if (i == 1) " active" else ""
    q_display <- questions[[q_ids[i]]]$display_label %||% q_ids[i]
    nav_buttons <- c(nav_buttons, sprintf(
      '<button class="ci-nav-btn%s" data-question="%s" onclick="switchQuestionDetail(\'%s\')">%s</button>',
      active, q_ids[i], q_ids[i], htmlEscape(q_display)
    ))
  }
  nav_html <- sprintf('<div class="ci-nav">%s</div>', paste(nav_buttons, collapse = "\n"))

  # Per-question detail panels
  panels <- character()
  for (i in seq_along(q_ids)) {
    q <- questions[[q_ids[i]]]
    active <- if (i == 1) " active" else ""

    panel_parts <- character()

    # Callout (structured HTML from callout generator — already has its own divs)
    panel_parts <- c(panel_parts, q$callout)

    # Quality badge
    badge_class <- paste0("ci-quality-", q$quality$badge)
    badge_label <- switch(q$quality$badge, good = "Good", warn = "Caution", poor = "Poor")
    type_label <- switch(q$type, proportion = "Proportion", mean = "Mean", nps = "NPS")

    panel_parts <- c(panel_parts, sprintf(
      '<p style="margin-bottom:16px;">Type: <strong>%s</strong> | Quality: <span class="%s"><strong>%s</strong></span> | Effective N: <strong>%s</strong></p>',
      type_label, badge_class, badge_label,
      if (!is.na(q$n_eff)) format(q$n_eff, big.mark = ",") else "N/A"
    ))

    # Method comparison table (use pre-built from orchestrator if available)
    detail_key <- paste0("detail_", q_ids[i])
    detail_table <- tables[[detail_key]] %||% ""
    if (!nzchar(detail_table)) {
      # Fallback: build on demand if not pre-built
      detail_table <- if (q$type == "proportion") {
        build_proportion_detail_table(q$results, conf_level)
      } else if (q$type == "mean") {
        build_mean_detail_table(q$results, conf_level)
      } else if (q$type == "nps") {
        build_nps_detail_table(q$results, conf_level)
      } else ""
    }

    if (nzchar(detail_table)) {
      panel_parts <- c(panel_parts, detail_table)
    }

    # Method comparison chart (use pre-built from orchestrator if available)
    chart_key <- paste0("methods_", q_ids[i])
    method_chart <- charts[[chart_key]] %||% ""
    if (!nzchar(method_chart)) {
      # Fallback: build on demand if not pre-built
      method_chart <- build_method_comparison_chart(q, brand)
    }
    if (nzchar(method_chart)) {
      panel_parts <- c(panel_parts, method_chart)
    }

    q_display <- q$display_label %||% q_ids[i]
    panels <- c(panels, sprintf(
      '<div id="ci-detail-%s" class="ci-detail-panel%s"><div class="ci-card"><h3>%s</h3>%s</div></div>',
      q_ids[i], active, htmlEscape(q_display),
      paste(panel_parts, collapse = "\n")
    ))
  }

  sprintf('<div id="tab-details" class="tab-panel">%s\n%s</div>',
          nav_html, paste(panels, collapse = "\n"))
}


# ==============================================================================
# NOTES PANEL
# ==============================================================================

build_ci_notes_panel <- function(html_data, config) {
  parts <- character()
  methods_used <- html_data$methodology$methods_used
  conf_level <- html_data$methodology$confidence_level
  boot_iter <- html_data$methodology$bootstrap_iterations

  # Method documentation
  parts <- c(parts, '<div class="ci-card"><h3>Statistical Methods</h3>')

  # Coverage probability explanation
  parts <- c(parts, sprintf(
    '<div class="ci-callout"><strong>What "%d%% confidence" means:</strong> A %d%% confidence interval is constructed so that, across many hypothetical repetitions of the same survey using the same sampling method, approximately %d%% of the resulting intervals would contain the true population parameter. It does <em>not</em> mean there is a %d%% probability that <em>this particular</em> interval contains the truth &mdash; the true value is fixed, and the interval either contains it or does not. The %d%% refers to the long-run reliability of the <em>procedure</em>, not to any single result. This distinction matters because a single interval from a biased sample can be precise yet wrong.</div>',
    round(conf_level * 100), round(conf_level * 100), round(conf_level * 100),
    round(conf_level * 100), round(conf_level * 100)
  ))

  if ("Normal Approximation (MOE)" %in% methods_used || "Normal Approximation" %in% methods_used) {
    parts <- c(parts, sprintf(
      '<div class="ci-method-doc">
        <h4>Margin of Error (Wald / Normal Approximation)</h4>
        <p><strong>Formula:</strong> p&#770;&nbsp;&plusmn;&nbsp;z<sub>&alpha;/2</sub>&nbsp;&times;&nbsp;&radic;(p&#770;(1&minus;p&#770;)&nbsp;/&nbsp;n), where z<sub>&alpha;/2</sub>&nbsp;=&nbsp;%.3f for %d%% confidence. For weighted data, n is replaced by n<sub>eff</sub> (Kish, 1965).</p>
        <p><strong>What it does:</strong> Estimates the maximum likely distance between the sample proportion and the true population proportion. This is the standard "plus or minus" figure reported in polls and surveys.</p>
        <p><strong>When it works well:</strong> Large samples (n&nbsp;&gt;&nbsp;30) with proportions between roughly 20%% and 80%%. Coverage probability is close to nominal in this range.</p>
        <p><strong>When it breaks down:</strong> At extreme proportions (below 5%% or above 95%%), the Wald interval has poor coverage &mdash; actual coverage can drop well below the stated confidence level. It can also produce intervals that extend below 0%% or above 100%%, which are logically impossible. For these cases, the Wilson score method is preferred.</p>
        <p><strong>Key assumption:</strong> Simple random sampling (or design-adjusted effective n). Not appropriate for clustered, stratified, or non-probability samples without modification.</p>
        <p><strong>Reference:</strong> This is the classical Wald interval. See Brown, Cai &amp; DasGupta (2001), "Interval estimation for a binomial proportion," <em>Statistical Science</em>, 16(2), for a thorough comparison of interval methods.</p>
      </div>',
      qnorm(1 - (1 - conf_level) / 2), round(conf_level * 100)
    ))
  }

  if ("Wilson Score" %in% methods_used) {
    parts <- c(parts, sprintf(
      '<div class="ci-method-doc">
        <h4>Wilson Score Interval</h4>
        <p><strong>Formula:</strong> The interval is obtained by inverting the score test for the binomial proportion. The centre is shifted from p&#770; toward 0.5 by the factor z<sup>2</sup>/(n&nbsp;+&nbsp;z<sup>2</sup>), and the width is: (1/(1&nbsp;+&nbsp;z<sup>2</sup>/n))&nbsp;&times;&nbsp;(p&#770;&nbsp;+&nbsp;z<sup>2</sup>/(2n)&nbsp;&plusmn;&nbsp;z&nbsp;&times;&nbsp;&radic;(p&#770;(1&minus;p&#770;)/n&nbsp;+&nbsp;z<sup>2</sup>/(4n<sup>2</sup>))), where z<sub>&alpha;/2</sub>&nbsp;=&nbsp;%.3f.</p>
        <p><strong>What it does:</strong> Produces confidence intervals for proportions that are guaranteed to lie within [0,&nbsp;1] and have near-nominal coverage probability even at extreme proportions and small sample sizes.</p>
        <p><strong>When it works well:</strong> All proportion scenarios, but especially at extremes (p&nbsp;&lt;&nbsp;0.10 or p&nbsp;&gt;&nbsp;0.90) and with sample sizes under 100. Agresti &amp; Coull (1998) recommend it as a default replacement for the Wald interval.</p>
        <p><strong>When it breaks down:</strong> Like all frequentist proportion methods, it still assumes independent Bernoulli trials from a random sample. It does not correct for clustering, stratification, or selection bias.</p>
        <p><strong>Key assumption:</strong> Random sampling with independent observations. The improvement over the Wald method is purely mathematical &mdash; it does not address sampling design issues.</p>
        <p><strong>References:</strong> Wilson, E.B. (1927), "Probable inference, the law of succession, and statistical inference," <em>Journal of the American Statistical Association</em>, 22(158). Agresti, A. &amp; Coull, B.A. (1998), "Approximate is better than exact for interval estimation of binomial proportions," <em>The American Statistician</em>, 52(2).</p>
      </div>',
      qnorm(1 - (1 - conf_level) / 2)
    ))
  }

  if ("Bootstrap" %in% methods_used) {
    parts <- c(parts, sprintf(
      '<div class="ci-method-doc">
        <h4>Bootstrap Confidence Interval</h4>
        <p><strong>Procedure:</strong> The original sample of n observations is resampled with replacement %s times. For each resample, the statistic of interest (proportion, mean, or NPS) is recalculated. The confidence interval is taken from the &alpha;/2 and 1&minus;&alpha;/2 percentiles of the bootstrap distribution (the "percentile method").</p>
        <p><strong>What it does:</strong> Estimates the sampling distribution of a statistic empirically, without assuming any particular parametric form. This is especially valuable when the statistic has a complex or unknown distribution (e.g., NPS, ratios, differences).</p>
        <p><strong>When it works well:</strong> Moderate to large samples where the data may be skewed, heavy-tailed, multimodal, or bounded. Performs well when parametric assumptions (normality, symmetry) are questionable. With sufficient iterations, the percentile bootstrap achieves good coverage for most smooth statistics.</p>
        <p><strong>When it breaks down:</strong> (1)&nbsp;Very small samples (n&nbsp;&lt;&nbsp;15): the bootstrap distribution is too coarse to accurately represent the sampling distribution. (2)&nbsp;Biased samples: the bootstrap faithfully reproduces any selection bias in the original data &mdash; it cannot correct for non-random sampling. (3)&nbsp;Clustered or dependent data: standard bootstrap assumes independent observations; for panel or clustered data, a block bootstrap or cluster bootstrap is needed.</p>
        <p><strong>Percentile vs. BCa:</strong> This report uses the percentile method for simplicity and interpretability. The bias-corrected and accelerated (BCa) method can improve coverage when the bootstrap distribution is skewed, but adds computational complexity and can be unstable with small samples.</p>
        <p><strong>Key assumption:</strong> The sample is representative of the population, and observations are independent.</p>
        <p><strong>Reference:</strong> Efron, B. &amp; Tibshirani, R.J. (1993), <em>An Introduction to the Bootstrap</em>, Chapman &amp; Hall.</p>
      </div>',
      format(boot_iter, big.mark = ",")
    ))
  }

  if ("Bayesian Credible" %in% methods_used) {
    parts <- c(parts, sprintf(
      '<div class="ci-method-doc">
        <h4>Bayesian Credible Interval</h4>
        <p><strong>For proportions:</strong> Uses Beta-Binomial conjugacy. Given x successes in n trials with a Beta(&alpha;<sub>0</sub>,&nbsp;&beta;<sub>0</sub>) prior, the posterior is Beta(x&nbsp;+&nbsp;&alpha;<sub>0</sub>,&nbsp;n&minus;x&nbsp;+&nbsp;&beta;<sub>0</sub>). The credible interval is taken from the &alpha;/2 and 1&minus;&alpha;/2 quantiles of this posterior. A weakly informative Jeffreys prior (Beta(0.5,&nbsp;0.5)) is commonly used.</p>
        <p><strong>For means:</strong> Uses a Normal-Inverse-Gamma conjugate model. With weakly informative priors, the posterior mean interval converges to the frequentist t-distribution interval.</p>
        <p><strong>What it does:</strong> Produces an interval with a direct probabilistic interpretation: there is a %d%% posterior probability that the true parameter lies within the stated bounds (given the data and the prior). This is often the interpretation people <em>intuitively</em> give to frequentist intervals, even though it is only strictly valid in the Bayesian framework.</p>
        <p><strong>When it works well:</strong> Tracking studies where previous waves provide defensible prior information. Small samples where prior knowledge can stabilise estimates. Also useful when the direct probabilistic interpretation is important for decision-making.</p>
        <p><strong>When it breaks down:</strong> An informative prior that conflicts with the truth will bias the posterior, especially in small samples where the data cannot overwhelm the prior. With large samples, the prior is washed out and Bayesian and frequentist intervals converge (Bernstein&ndash;von Mises theorem). With uninformative priors, Bayesian and frequentist results are nearly identical.</p>
        <p><strong>Key assumption:</strong> The model is correctly specified and the prior is defensible. Random sampling is still assumed.</p>
        <p><strong>References:</strong> Gelman, A. et al. (2013), <em>Bayesian Data Analysis</em>, 3rd ed., CRC Press. For proportions: Agresti, A. &amp; Min, Y. (2005), "Frequentist performance of Bayesian confidence intervals for comparing proportions in 2&times;2 contingency tables," <em>Biometrics</em>, 61(2).</p>
      </div>',
      round(conf_level * 100)
    ))
  }

  if ("t-Distribution" %in% methods_used) {
    parts <- c(parts,
      '<div class="ci-method-doc">
        <h4>t-Distribution Confidence Interval (for Means)</h4>
        <p><strong>Formula:</strong> x&#772;&nbsp;&plusmn;&nbsp;t<sub>&alpha;/2,&thinsp;n&minus;1</sub>&nbsp;&times;&nbsp;s&nbsp;/&nbsp;&radic;n, where t<sub>&alpha;/2,&thinsp;n&minus;1</sub> is the critical value from the t-distribution with n&minus;1 degrees of freedom. For weighted data, n is replaced by n<sub>eff</sub> and s by the Bessel-corrected weighted standard deviation.</p>
        <p><strong>What it does:</strong> Accounts for the additional uncertainty that arises from estimating the population standard deviation from the sample (rather than knowing it). The t-distribution has heavier tails than the normal, producing wider intervals that are appropriate when the true SD is unknown.</p>
        <p><strong>When it works well:</strong> (1)&nbsp;Data is approximately normally distributed, at any sample size. (2)&nbsp;Data is non-normal but the sample is large (n&nbsp;&gt;&nbsp;30), where the Central Limit Theorem ensures the sampling distribution of the mean is approximately normal. Coverage is remarkably robust to non-normality for n&nbsp;&gt;&nbsp;40.</p>
        <p><strong>When it breaks down:</strong> Heavily skewed or heavy-tailed distributions with small samples (n&nbsp;&lt;&nbsp;20). In such cases, the actual coverage can deviate from nominal. Common examples: income data, time-to-completion data, data with floor/ceiling effects. Bootstrap intervals are more appropriate here.</p>
        <p><strong>Weighted variance:</strong> For weighted data, the Bessel-corrected weighted variance is s<sup>2</sup><sub>w</sub>&nbsp;=&nbsp;&Sigma;w<sub>i</sub>(x<sub>i</sub>&minus;x&#772;<sub>w</sub>)<sup>2</sup>&nbsp;/&nbsp;(&Sigma;w&nbsp;&minus;&nbsp;&Sigma;w<sup>2</sup>/&Sigma;w), which provides an unbiased estimate of the population variance under reliability (frequency) weighting.</p>
        <p><strong>Key assumption:</strong> Random sampling, independent observations, approximate normality or large sample. For weighted data, weights are treated as reliability (frequency) weights, not probability weights (for which the survey package approach is more appropriate).</p>
        <p><strong>Reference:</strong> Student [W.S. Gosset] (1908), "The probable error of a mean," <em>Biometrika</em>, 6(1). For weighted variance: Cochran, W.G. (1977), <em>Sampling Techniques</em>, 3rd ed., Wiley.</p>
      </div>'
    )
  }

  # Effective sample size documentation (always show if weighted)
  if (html_data$summary$is_weighted) {
    parts <- c(parts,
      '<div class="ci-method-doc">
        <h4>Effective Sample Size (Design Effect)</h4>
        <p><strong>Formula:</strong> n<sub>eff</sub>&nbsp;=&nbsp;(&Sigma;w<sub>i</sub>)<sup>2</sup>&nbsp;/&nbsp;&Sigma;w<sub>i</sub><sup>2</sup>. The design effect is DEFF&nbsp;=&nbsp;n&nbsp;/&nbsp;n<sub>eff</sub>&nbsp;=&nbsp;1&nbsp;+&nbsp;CV<sup>2</sup>(w), where CV(w) is the coefficient of variation of the weights.</p>
        <p><strong>What it means:</strong> When survey responses carry unequal weights, some observations contribute more to the estimate than others. The effective sample size is the number of equally-weighted observations that would give the same precision as the actual weighted sample. A DEFF of 1.0 means weights are equal (no efficiency loss); a DEFF of 2.0 means the weighted sample is only as precise as an unweighted sample half its size.</p>
        <p><strong>Interpretation guide:</strong> DEFF&nbsp;&lt;&nbsp;1.5 (efficiency&nbsp;&gt;&nbsp;67%): acceptable for most purposes. DEFF&nbsp;1.5&ndash;2.0 (efficiency&nbsp;50&ndash;67%): weighting is having a meaningful impact on precision; consider whether the weighting scheme can be simplified. DEFF&nbsp;&gt;&nbsp;2.0 (efficiency&nbsp;&lt;&nbsp;50%): weighting is severely reducing precision; review the weighting targets and consider collapsing categories.</p>
        <p><strong>Key limitation:</strong> The Kish formula measures only the precision loss from unequal weights. It does not capture clustering effects (for which a separate design effect adjustment would be needed) or non-response bias.</p>
        <p><strong>Reference:</strong> Kish, L. (1965), <em>Survey Sampling</em>, Wiley. Kish, L. (1992), "Weighting for unequal P<sub>i</sub>," <em>Journal of Official Statistics</em>, 8(2).</p>
      </div>'
    )
  }

  parts <- c(parts, '</div>')

  # General warnings callout — enhanced with precision vs accuracy framework
  parts <- c(parts,
    '<div class="ci-card"><h3>Understanding Limitations</h3>
      <div class="ci-callout ci-callout-warning">
        <strong>Precision is not accuracy.</strong> A confidence interval measures <em>precision</em> &mdash; how repeatable the estimate would be across many samples drawn the same way. It does not measure <em>accuracy</em> &mdash; how close the estimate is to the truth. If your sample systematically over- or under-represents certain groups (selection bias), the interval can be very narrow (precise) but centred on the wrong value (inaccurate). Always assess whether your sample is representative before treating these intervals as definitive.
      </div>
      <div class="ci-callout ci-callout-warning">
        <strong>Sources of error not captured.</strong> Confidence intervals reflect only <em>sampling error</em> &mdash; the variability due to observing a finite sample rather than the entire population. They do not account for: non-response bias (systematic differences between respondents and non-respondents), measurement error (ambiguous questions, social desirability, acquiescence bias), coverage error (populations that cannot be reached by the sampling frame), or processing errors (coding mistakes, data entry errors). In practice, these non-sampling errors often exceed sampling error, especially in large surveys where the margin of error is small but operational biases persist.
      </div>
      <div class="ci-callout ci-callout-warning">
        <strong>Multiple comparisons.</strong> When many questions are analysed simultaneously, some intervals will fail to contain the true value by chance alone. At 95% confidence, roughly 1 in 20 intervals is expected to miss. If you are comparing results across many subgroups or questions, consider whether an adjustment for multiple testing (e.g., Bonferroni or Benjamini-Hochberg) is appropriate for your use case.
      </div>
    </div>'
  )

  # Warnings from analysis
  warnings <- html_data$warnings
  if (length(warnings) > 0) {
    warning_items <- paste(
      sapply(warnings, function(w) sprintf('<li>%s</li>', htmlEscape(w))),
      collapse = "\n"
    )
    parts <- c(parts, sprintf(
      '<div class="ci-card"><h3>Analysis Warnings</h3><ul style="margin-left:20px; font-size:13px;">%s</ul></div>',
      warning_items
    ))
  }

  # Comments box
  parts <- c(parts,
    '<div class="ci-card">
      <h3>Comments</h3>
      <p style="font-size:12px; color:#64748b; margin-bottom:12px;">Add your comments below. These will be saved when you use the Save Report button.</p>
      <textarea class="ci-comments-box" id="analyst-comments" placeholder="Add your comments, observations, or notes here..."></textarea>
    </div>'
  )

  sprintf('<div id="tab-notes" class="tab-panel">%s</div>', paste(parts, collapse = "\n"))
}


# ==============================================================================
# FOOTER
# ==============================================================================

build_ci_footer <- function() {
  sprintf(
    '<div class="ci-footer">Generated by Turas Confidence &middot; %s &middot; The Research Lamppost (Pty) Ltd</div>',
    format(Sys.time(), "%Y-%m-%d %H:%M")
  )
}


# ==============================================================================
# JAVASCRIPT
# ==============================================================================

build_ci_js <- function() {
  js_dir <- get0(".confidence_html_report_dir", envir = globalenv())

  if (!is.null(js_dir)) {
    js_path <- file.path(js_dir, "js", "confidence_navigation.js")
    if (file.exists(js_path)) {
      return(paste(readLines(js_path, warn = FALSE), collapse = "\n"))
    }
  }

  # Inline fallback
  '
function switchReportTab(tabName) {
  document.querySelectorAll(".report-tab").forEach(function(btn) {
    btn.classList.toggle("active", btn.getAttribute("data-tab") === tabName);
  });
  document.querySelectorAll(".tab-panel").forEach(function(panel) { panel.classList.remove("active"); });
  var target = document.getElementById("tab-" + tabName);
  if (target) target.classList.add("active");
}
function switchQuestionDetail(questionId) {
  document.querySelectorAll(".ci-nav-btn").forEach(function(btn) {
    btn.classList.toggle("active", btn.getAttribute("data-question") === questionId);
  });
  document.querySelectorAll(".ci-detail-panel").forEach(function(panel) { panel.classList.remove("active"); });
  var target = document.getElementById("ci-detail-" + questionId);
  if (target) target.classList.add("active");
}
function saveReportHTML() {
  var meta = document.querySelector("meta[name=turas-source-filename]");
  var baseName = meta ? meta.getAttribute("content") : "Confidence_Report";
  document.querySelectorAll("textarea").forEach(function(ta) { ta.textContent = ta.value; });
  var html = document.documentElement.outerHTML;
  var blob = new Blob(["<!DOCTYPE html>\\n" + html], { type: "text/html" });
  var url = URL.createObjectURL(blob);
  var a = document.createElement("a"); a.href = url; a.download = baseName + "_Updated.html";
  document.body.appendChild(a); a.click(); document.body.removeChild(a); URL.revokeObjectURL(url);
}
document.addEventListener("DOMContentLoaded", function() { switchReportTab("summary"); });
'
}


# ==============================================================================
# UTILITY
# ==============================================================================

# htmlEscape: canonical definition in 02_table_builder.R
if (!exists("htmlEscape", mode = "function")) {
  htmlEscape <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub('"', "&quot;", x, fixed = TRUE)
    x
  }
}
