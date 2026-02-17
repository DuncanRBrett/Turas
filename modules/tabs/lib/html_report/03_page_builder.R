# ==============================================================================
# HTML REPORT - PAGE BUILDER (V10.3.2)
# ==============================================================================
# Assembles the complete HTML page structure: header, sidebar, controls,
# table containers, footer, CSS, and JavaScript.
# Uses plain HTML tables — no reactable, no htmlwidgets.
# ==============================================================================


#' Build Complete HTML Page
#'
#' Assembles all components into a single browsable HTML page.
#'
#' @param html_data List from transform_for_html()
#' @param tables Named list of htmltools::HTML table objects (keyed by q_code)
#' @param config_obj Configuration object
#' @return htmltools::browsable tagList
#' @export
build_html_page <- function(html_data, tables, config_obj,
                            dashboard_html = NULL, charts = list()) {

  brand_colour <- config_obj$brand_colour %||% "#0d8a8a"
  project_title <- config_obj$project_title %||% "Crosstab Report"
  min_base <- config_obj$significance_min_base %||% 30
  has_any_sig <- any(sapply(html_data$questions, function(q) q$stats$has_sig))
  has_any_freq <- any(sapply(html_data$questions, function(q) q$stats$has_freq))
  has_any_pct <- any(sapply(html_data$questions, function(q) q$stats$has_col_pct || q$stats$has_row_pct))

  # Build crosstab content (always needed)
  crosstab_content <- htmltools::tags$div(
    class = "main-layout",
    id = "main-content",
    build_sidebar(html_data$questions, has_any_sig, brand_colour),
    htmltools::tags$div(
      class = "content-area",
      build_banner_tabs(html_data$banner_groups, brand_colour),
      build_controls(has_any_freq, has_any_pct, has_any_sig, brand_colour,
                     has_charts = length(charts) > 0),
      build_question_containers(html_data$questions, tables, html_data$banner_groups,
                                config_obj, charts = charts),
      build_footer(config_obj, min_base)
    )
  )

  if (!is.null(dashboard_html)) {
    # Dashboard mode: two tabs (Summary + Crosstabs)
    crosstab_panel <- htmltools::tags$div(
      id = "tab-crosstabs",
      class = "tab-panel",
      crosstab_content
    )

    page <- htmltools::tagList(
      htmltools::tags$head(
        htmltools::tags$meta(charset = "UTF-8"),
        htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
        htmltools::tags$title(project_title),
        build_css(brand_colour),
        build_dashboard_css(brand_colour),
        build_print_css()
      ),
      build_header(project_title, brand_colour, html_data$total_n, html_data$n_questions,
                         company_name = config_obj$company_name %||% "The Research Lamppost"),
      build_report_tab_nav(brand_colour),
      dashboard_html,
      crosstab_panel,
      build_javascript(html_data),
      build_tab_javascript()
    )
  } else {
    # No dashboard: original layout unchanged
    page <- htmltools::tagList(
      htmltools::tags$head(
        htmltools::tags$meta(charset = "UTF-8"),
        htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
        htmltools::tags$title(project_title),
        build_css(brand_colour),
        build_print_css()
      ),
      build_header(project_title, brand_colour, html_data$total_n, html_data$n_questions,
                         company_name = config_obj$company_name %||% "The Research Lamppost"),
      crosstab_content,
      build_javascript(html_data)
    )
  }

  htmltools::browsable(page)
}


#' Build CSS Stylesheet
#'
#' @param brand_colour Character hex colour
#' @return htmltools::tags$style
build_css <- function(brand_colour) {
  # Use gsub instead of sprintf to avoid R's 8192 char format string limit
  bc <- brand_colour

  css_layout <- '
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
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .header-brand {
      color: rgba(255,255,255,0.5);
      font-size: 11px;
      letter-spacing: 2px;
      text-transform: uppercase;
      font-weight: 600;
      margin-bottom: 4px;
    }
    .header-title {
      color: #ffffff;
      font-size: 22px;
      font-weight: 700;
      letter-spacing: -0.3px;
    }
    .header-meta {
      color: rgba(255,255,255,0.6);
      font-size: 12px;
      margin-top: 4px;
    }
    .header-left {
      display: flex;
      align-items: center;
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
      max-height: 500px;
      overflow-y: auto;
    }
    .question-item {
      padding: 10px 14px;
      cursor: pointer;
      border-bottom: 1px solid #e2e8f0;
      border-left: 3px solid transparent;
      transition: all 0.12s ease;
    }
    .question-item:hover { background: #f8fafc; }
    .question-item.active {
      background: #e6f5f5;
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
      transition: all 0.12s ease;
    }
    .banner-tab:last-child { border-right: none; }
    .banner-tab.active { background: #1a2744; color: #ffffff; }
    .banner-tab:hover:not(.active) { background: #f8fafc; }
    .toggle-label {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      color: #64748b;
      cursor: pointer;
      user-select: none;
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
      font-size: 13px;
      font-weight: 700;
      color: BRAND;
      font-family: ui-monospace, "Cascadia Code", Consolas, monospace;
      letter-spacing: 0.5px;
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
      transition: all 0.12s;
    }
    .export-btn:hover { background: #f8fafc; color: #1e293b; }
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
      font-size: 12px;
      table-layout: auto;
    }
    .ct-th {
      padding: 8px 10px;
      text-align: center;
      font-weight: 600;
      font-size: 11px;
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
      padding: 6px 10px;
      text-align: center;
      border-bottom: 1px solid #f0f0f0;
      white-space: nowrap;
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
    .ct-row-net { background: #f5f0e8; }
    .ct-row-net .ct-label-col { font-weight: 700; color: #5c4a2a; background: #f5f0e8; }
    .ct-row-mean .ct-label-col { background: #fef9e7; }
    /* Separator line between individual items and NET/summary rows */
    .ct-row-category + .ct-row-net > .ct-td { border-top: 2px solid #cbd5e1; }
    /* Separator line between NET rows and mean/index rows */
    .ct-row-net + .ct-row-mean > .ct-td { border-top: 2px solid #cbd5e1; }
    .ct-row-category + .ct-row-mean > .ct-td { border-top: 2px solid #cbd5e1; }
    .ct-row-mean { background: #fef9e7; }
    .ct-row-mean .ct-td { font-style: italic; color: #6b5c1e; }
    .ct-val { font-variant-numeric: tabular-nums; }
    .ct-val-net { font-weight: 700; }
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
      transition: all 0.12s;
    }
    .print-btn:hover { background: #f8fafc; color: #1e293b; }

    /* Chart wrapper */
    .chart-wrapper {
      padding: 20px 20px 12px;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-top: none;
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
      padding: 4px 10px; border: 1px solid #e2e8f0; border-radius: 16px;
      background: #f0fafa; color: #1e293b; font-size: 11px; font-weight: 500;
      cursor: pointer; font-family: inherit; transition: all 0.12s;
    }
    .col-chip:hover { border-color: BRAND; }
    .col-chip-off {
      background: #f1f5f9; color: #94a3b8;
      text-decoration: line-through; opacity: 0.6;
    }
    .col-chip-off:hover { opacity: 0.8; }

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
      padding: 5px 12px; border: 1px dashed #cbd5e1; border-radius: 4px;
      background: transparent; color: #94a3b8; font-size: 11px; font-weight: 500;
      cursor: pointer; font-family: inherit; transition: all 0.15s;
      width: 100%;
    }
    .insight-toggle:hover { border-color: BRAND; color: BRAND; }
    .insight-editor {
      border-left: 3px solid BRAND; background: #f8fafa;
      padding: 12px 16px; font-size: 13px; line-height: 1.6;
      border-radius: 0 6px 6px 0; min-height: 40px; outline: none;
      color: #1e293b; position: relative;
    }
    .insight-editor:empty::before {
      content: attr(data-placeholder); color: #b0bec5; font-style: italic;
    }
    .insight-dismiss {
      position: absolute; top: 6px; right: 8px; border: none; background: none;
      color: #cbd5e1; font-size: 14px; cursor: pointer; padding: 2px 6px;
      line-height: 1; border-radius: 3px;
    }
    .insight-dismiss:hover { color: #64748b; background: #e2e8f0; }
    .insight-container {
      border: 1px solid #e2e8f0; border-top: none; background: #f8fafa;
      padding: 10px 16px; position: relative;
    }
  '

  # Replace BRAND placeholder with actual brand colour
  css_text <- paste0(css_layout, css_tables)
  css_text <- gsub("BRAND", bc, css_text, fixed = TRUE)

  htmltools::tags$style(htmltools::HTML(css_text))
}


#' Build Print CSS
#'
#' @return htmltools::tags$style
build_print_css <- function() {
  htmltools::tags$style(htmltools::HTML('
    @media print {
      .sidebar, .controls-bar, .banner-tabs, .table-actions,
      .export-btn, .export-chart-btn, .export-slide-btn, .search-box,
      .toggle-label, .print-btn, .col-chip-bar, .ct-sort-indicator,
      .insight-toggle, .insight-dismiss,
      .chart-col-picker { display: none !important; }
      .insight-container:has(.insight-editor:not(:empty)) { display: block !important; }
      .main-layout { display: block !important; padding: 0 !important; }
      .content-area { width: 100% !important; }
      .question-container { display: block !important; page-break-inside: avoid; margin-bottom: 24px; page-break-after: always; }
      .question-container:last-child { page-break-after: auto; }
      .header { padding: 12px 16px; }
      .question-title-card { padding: 8px 12px; }
      body { background: white; }
      .table-wrapper { border: 1px solid #ccc; overflow: visible !important; }
      .ct-td.ct-label-col, .ct-th.ct-label-col { position: static; }
      .ct-low-base-dim { opacity: 1 !important; }
      .report-tabs { display: none !important; }
      .tab-panel { display: block !important; }
      #tab-summary { display: none !important; }
      .chart-wrapper { page-break-inside: avoid; }
      .ct-table { font-size: 11px !important; }
      .ct-th, .ct-td { padding: 4px 8px !important; }
      .question-text { font-size: 14px !important; }
      .question-code { font-size: 12px !important; }
      .banner-tabs { display: flex !important; }
      .banner-tab { display: none !important; }
      .banner-tab.active { display: inline-block !important; background: #1a2744 !important; color: #fff !important; font-size: 10px !important; padding: 4px 10px !important; }
    }
  '))
}


#' Build Report Tab Navigation (Summary / Crosstabs)
#'
#' @param brand_colour Character hex colour
#' @return htmltools::tags$div
#' @keywords internal
build_report_tab_nav <- function(brand_colour) {
  htmltools::tags$div(
    class = "report-tabs",
    htmltools::tags$button(
      class = "report-tab active",
      onclick = "switchReportTab('summary')",
      `data-tab` = "summary",
      "\U0001F4CA Summary"
    ),
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('crosstabs')",
      `data-tab` = "crosstabs",
      "\U0001F4CB Crosstabs"
    )
  )
}


#' Build Tab Switching JavaScript
#'
#' @return htmltools::tags$script
#' @keywords internal
build_tab_javascript <- function() {
  js <- '
    function switchReportTab(tabName) {
      document.querySelectorAll(".report-tab").forEach(function(btn) {
        btn.classList.toggle("active", btn.getAttribute("data-tab") === tabName);
      });
      document.querySelectorAll(".tab-panel").forEach(function(panel) {
        panel.classList.remove("active");
      });
      var target = document.getElementById("tab-" + tabName);
      if (target) target.classList.add("active");

      // When switching to crosstabs, trigger resize for any sticky columns
      if (tabName === "crosstabs") {
        window.dispatchEvent(new Event("resize"));
      }
    }
  '
  htmltools::tags$script(htmltools::HTML(js))
}


#' Build Header
#'
#' @param project_title Character
#' @param brand_colour Character
#' @param total_n Numeric or NA
#' @param n_questions Integer
#' @return htmltools::div
build_header <- function(project_title, brand_colour, total_n, n_questions,
                         company_name = "The Research Lamppost") {
  meta_parts <- c()
  if (!is.na(total_n)) {
    total_n_display <- round(as.numeric(total_n))
    meta_parts <- c(meta_parts, sprintf("n=%s", format(total_n_display, big.mark = ",")))
  }
  if (!is.na(n_questions)) meta_parts <- c(meta_parts, sprintf("%d Questions", n_questions))

  brand_label <- paste0(company_name, " \u00B7 Turas Analytics")

  htmltools::tags$div(
    class = "header",
    htmltools::tags$div(
      class = "header-inner",
      htmltools::tags$div(
        class = "header-left",
        htmltools::tags$div(
          htmltools::tags$div(class = "header-brand", brand_label),
          htmltools::tags$h1(class = "header-title", project_title),
          htmltools::tags$div(class = "header-meta",
            paste(c("Interactive Crosstab Explorer", meta_parts), collapse = " \u00B7 "))
        )
      ),
      htmltools::tags$div(
        style = "text-align:right",
        htmltools::tags$div(style = "color:rgba(255,255,255,0.4);font-size:10px",
          "Generated by Turas")
      )
    )
  )
}


#' Build Sidebar with Question Navigator
#'
#' @param questions List of transformed question data
#' @param has_sig Logical
#' @param brand_colour Character
#' @return htmltools::div
build_sidebar <- function(questions, has_sig = FALSE, brand_colour = "#0d8a8a") {
  q_items <- lapply(seq_along(questions), function(i) {
    q <- questions[[i]]
    q_code <- q$q_code
    q_text <- q$question_text
    if (nchar(q_text) > 80) q_text <- paste0(substr(q_text, 1, 80), "...")

    htmltools::tags$div(
      class = if (i == 1) "question-item active" else "question-item",
      `data-index` = i - 1,
      `data-search` = tolower(paste(q_code, q_text)),
      onclick = sprintf("selectQuestion(%d)", i - 1),
      htmltools::tags$div(class = "question-item-code", q_code),
      htmltools::tags$div(class = "question-item-text", q_text)
    )
  })

  sidebar_content <- list(
    htmltools::tags$input(
      type = "text",
      class = "search-box",
      placeholder = "Search questions...",
      oninput = "filterQuestions(this.value)"
    ),
    htmltools::tags$div(
      class = "question-list",
      htmltools::tags$div(class = "question-list-header",
        sprintf("Questions (%d)", length(questions))),
      htmltools::tags$div(class = "question-list-scroll", q_items)
    )
  )

  # Legend
  if (has_sig) {
    sidebar_content <- c(sidebar_content, list(
      htmltools::tags$div(
        class = "legend-box",
        htmltools::tags$div(class = "legend-title", "Legend"),
        htmltools::tags$div(class = "legend-item",
          htmltools::tags$span(class = "sig-badge-legend", "\u25B2AB"),
          htmltools::tags$span("Significantly higher than columns")
        ),
        htmltools::tags$div(class = "legend-item",
          htmltools::tags$span(style = "color:#e8614d;font-weight:700;font-size:11px", "\u26A0 28"),
          htmltools::tags$span("Low base warning (n<30)")
        )
      )
    ))
  }

  htmltools::tags$div(
    class = "sidebar",
    htmltools::tags$div(class = "sidebar-inner", sidebar_content)
  )
}


#' Build Banner Group Tab Buttons
#'
#' @param banner_groups Named list of banner groups
#' @param brand_colour Character
#' @return htmltools::div
build_banner_tabs <- function(banner_groups, brand_colour = "#0d8a8a") {
  tabs <- lapply(seq_along(banner_groups), function(i) {
    grp_name <- names(banner_groups)[i]
    grp <- banner_groups[[i]]
    htmltools::tags$button(
      class = if (i == 1) "banner-tab active" else "banner-tab",
      `data-group` = grp$banner_code,
      `data-banner-name` = grp_name,
      onclick = sprintf("switchBannerGroup('%s', this)", grp$banner_code),
      grp_name
    )
  })

  htmltools::tags$div(class = "banner-tabs", tabs)
}


#' Build Toggle Controls
#'
#' @param has_any_freq Logical
#' @param has_any_pct Logical
#' @param has_any_sig Logical
#' @param brand_colour Character
#' @return htmltools::div
build_controls <- function(has_any_freq, has_any_pct, has_any_sig,
                           brand_colour = "#0d8a8a", has_charts = FALSE) {
  controls <- list()

  if (has_any_pct) {
    controls <- c(controls, list(
      htmltools::tags$label(class = "toggle-label",
        htmltools::tags$input(type = "checkbox", checked = NA, onchange = "toggleHeatmap(this.checked)"),
        "Heatmap"
      )
    ))
  }

  if (has_any_freq && has_any_pct) {
    controls <- c(controls, list(
      htmltools::tags$label(class = "toggle-label",
        htmltools::tags$input(type = "checkbox", onchange = "toggleFrequency(this.checked)"),
        "Show count"
      )
    ))
  }

  if (has_charts) {
    controls <- c(controls, list(
      htmltools::tags$label(class = "toggle-label",
        htmltools::tags$input(type = "checkbox", onchange = "toggleChart(this.checked)"),
        "Chart"
      )
    ))
  }

  # Print button always available
  controls <- c(controls, list(
    htmltools::tags$button(
      class = "print-btn",
      onclick = "printReport()",
      "\U0001F5A8 Print Report"
    )
  ))

  htmltools::tags$div(
    class = "controls-bar",
    htmltools::tags$div(style = "flex:1"),
    controls
  )
}


#' Build Key Insight Area
#'
#' Creates an editable insight callout for a question. Supports multi-banner
#' comments: comment_entries is a list of list(banner, text) objects.
#' The initial text shown is the first matching entry for the active banner,
#' or the first global (banner=NULL) entry. All entries are embedded as JSON
#' for JS to switch on banner change.
#'
#' @param q_code Character, question code
#' @param comment_entries List of list(banner, text), or NULL
#' @param first_banner Character, name of the first active banner group
#' @return htmltools::tags$div
#' @keywords internal
build_insight_area <- function(q_code, comment_entries = NULL,
                               first_banner = "") {
  # Determine initial comment to show
  initial_text <- NULL
  if (!is.null(comment_entries) && length(comment_entries) > 0) {
    # Try banner-specific first, then global
    for (entry in comment_entries) {
      if (!is.null(entry$banner) && entry$banner == first_banner) {
        initial_text <- entry$text
        break
      }
    }
    if (is.null(initial_text)) {
      for (entry in comment_entries) {
        if (is.null(entry$banner)) {
          initial_text <- entry$text
          break
        }
      }
    }
  }
  has_comment <- !is.null(initial_text) && nzchar(trimws(initial_text))

  # Embed all comments as JSON for banner switching
  comments_json <- if (!is.null(comment_entries) && length(comment_entries) > 0) {
    as.character(jsonlite::toJSON(comment_entries, auto_unbox = TRUE))
  } else {
    NULL
  }

  htmltools::tags$div(
    class = "insight-area",
    `data-q-code` = q_code,
    if (!is.null(comments_json)) htmltools::tagList(
      htmltools::tags$script(
        type = "application/json",
        class = "insight-comments-data",
        htmltools::HTML(comments_json)
      )
    ),
    # Toggle button (hidden when comment is pre-filled)
    htmltools::tags$button(
      class = "insight-toggle",
      style = if (has_comment) "display:none;" else NULL,
      onclick = sprintf("toggleInsight('%s')", q_code),
      if (has_comment) "Edit Insight" else "+ Add Insight"
    ),
    # Editable callout container
    htmltools::tags$div(
      class = "insight-container",
      style = if (!has_comment) "display:none;" else NULL,
      htmltools::tags$div(
        class = "insight-editor",
        contenteditable = "true",
        `data-placeholder` = "Type key insight here\u2026",
        `data-q-code` = q_code,
        if (has_comment) initial_text
      ),
      htmltools::tags$button(
        class = "insight-dismiss",
        title = "Delete insight",
        onclick = sprintf("dismissInsight('%s')", q_code),
        "\u00D7"
      )
    )
  )
}


#' Build Question Containers
#'
#' Creates a container div for each question holding its title and table.
#'
#' @param questions List of transformed question data
#' @param tables Named list of htmltools::HTML table objects
#' @param banner_groups Named list of banner groups
#' @param config_obj Configuration
#' @return htmltools::tagList
build_question_containers <- function(questions, tables, banner_groups,
                                      config_obj, charts = list()) {

  first_group_name <- if (length(banner_groups) > 0) names(banner_groups)[1] else ""

  comments <- config_obj$comments  # Named list or NULL

  containers <- lapply(seq_along(questions), function(i) {
    q <- questions[[i]]
    q_code <- q$q_code
    q_text <- q$question_text
    stat_label <- q$primary_stat

    # Build chart div (hidden by default, toggled via JS)
    # charts[[q_code]] is a list with $svg and $chart_data, or NULL
    chart_div <- NULL
    chart_result <- charts[[q_code]]
    has_chart <- !is.null(chart_result)
    if (has_chart) {
      # Embed chart data as JSON for JS-driven multi-column rendering
      chart_json <- jsonlite::toJSON(chart_result$chart_data,
                                      auto_unbox = TRUE, digits = 4)
      chart_div <- htmltools::tags$div(
        class = "chart-wrapper",
        style = "display:none;",
        `data-q-code` = q_code,
        `data-q-title` = q_text,
        `data-chart-data` = as.character(chart_json),
        chart_result$svg
      )
    }

    # Build insight area (pre-filled from config if available)
    comment_entries <- if (!is.null(comments)) comments[[q_code]] else NULL
    insight_div <- build_insight_area(q_code, comment_entries,
                                      first_banner = first_group_name)

    htmltools::tags$div(
      class = if (i == 1) "question-container active" else "question-container",
      id = paste0("q-container-", i - 1),
      htmltools::tags$div(
        class = "question-title-card",
        htmltools::tags$div(class = "question-title-row",
          htmltools::tags$span(class = "question-code", q_code),
          htmltools::tags$span(class = "question-text", q_text)
        ),
        htmltools::tags$div(class = "question-meta",
          htmltools::HTML(sprintf("Banner: <strong class=\"banner-name-label\">%s</strong> &middot; Showing %s",
                                  first_group_name, stat_label))
        ),
        if (!is.na(q$base_filter) && nchar(q$base_filter %||% "") > 0) {
          htmltools::tags$div(
            style = "margin-top:4px;font-size:11px;color:#e8614d;font-weight:600",
            sprintf("Filter: %s", q$base_filter)
          )
        }
      ),
      htmltools::tags$div(class = "table-wrapper",
        tables[[q_code]]
      ),
      chart_div,
      insight_div,
      htmltools::tags$div(class = "table-actions",
        htmltools::tags$button(
          class = "export-btn",
          onclick = sprintf("exportExcel('%s')", q_code),
          "\u2B73 Export Excel"
        ),
        htmltools::tags$button(
          class = "export-btn",
          style = "margin-left:8px",
          onclick = sprintf("exportCSV('%s')", q_code),
          "\u2B73 Export CSV"
        ),
        if (has_chart) {
          htmltools::tags$button(
            class = "export-btn export-chart-btn",
            style = "margin-left:8px;display:none",
            onclick = sprintf("exportChartPNG('%s')", q_code),
            "\U0001F4CA Export Chart"
          )
        },
        if (has_chart) {
          htmltools::tags$button(
            class = "export-btn export-slide-btn",
            style = "margin-left:8px;display:none",
            onclick = sprintf("exportSlidePNG('%s')", q_code),
            "\U0001F4C4 Export Slide"
          )
        }
      )
    )
  })

  htmltools::tagList(containers)
}


#' Build Footer
#'
#' @param config_obj Configuration
#' @param min_base Numeric
#' @return htmltools::div
build_footer <- function(config_obj, min_base = 30) {
  parts <- c()
  if (isTRUE(config_obj$enable_significance_testing)) {
    parts <- c(parts, "Significance testing: Column proportions z-test")
    if (isTRUE(config_obj$bonferroni_correction)) {
      parts <- c(parts, "with Bonferroni correction")
    }
    alpha <- config_obj$alpha %||% 0.05
    parts <- c(parts, sprintf("p<%.2f", alpha))
  }
  parts <- c(parts, sprintf("Minimum base n=%d", min_base))
  parts <- c(parts, "Generated by Turas Analytics")

  htmltools::tags$div(class = "footer", paste(parts, collapse = " \u00B7 "))
}


#' Build JavaScript for Interactivity
#'
#' Assembles all JS from focused helper functions into a single script tag.
#' Plain vanilla JavaScript — no HTMLWidgets, no React, no external deps.
#'
#' @param html_data The transformed data
#' @return htmltools::tags$script
build_javascript <- function(html_data) {
  group_codes <- sapply(html_data$banner_groups, function(g) g$banner_code)

  js_full <- paste0(
    build_js_core_navigation(),
    build_js_chart_picker(),
    build_js_slide_export(),
    build_js_table_export_and_init()
  )

  js_full <- gsub("BANNER_GROUPS_JSON",
                   jsonlite::toJSON(unname(group_codes), auto_unbox = FALSE),
                   js_full, fixed = TRUE)

  htmltools::tags$script(htmltools::HTML(js_full))
}


#' Build Core Navigation JavaScript
#'
#' Global state, question navigation, banner switching, heatmap toggle,
#' frequency toggle, print, chart toggle, and insight/comment system.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_core_navigation <- function() {
  '
    // Banner group codes
    var bannerGroups = BANNER_GROUPS_JSON;
    var currentGroup = bannerGroups[0] || "";
    var heatmapEnabled = true;
    var hiddenColumns = {};
    var sortState = {};
    var originalRowOrder = {};

    // Question navigation
    function selectQuestion(index) {
      document.querySelectorAll(".question-container").forEach(function(el) {
        el.classList.remove("active");
      });
      var container = document.getElementById("q-container-" + index);
      if (container) container.classList.add("active");

      document.querySelectorAll(".question-item").forEach(function(el) {
        el.classList.toggle("active", parseInt(el.getAttribute("data-index")) === index);
      });
    }

    // Search filter
    function filterQuestions(term) {
      var lower = term.toLowerCase();
      document.querySelectorAll(".question-item").forEach(function(el) {
        var searchText = el.getAttribute("data-search") || "";
        el.style.display = searchText.indexOf(lower) >= 0 ? "" : "none";
      });
    }

    // Banner group switching
    function switchBannerGroup(groupCode, btn) {
      currentGroup = groupCode;

      // Update tab buttons
      var activeName = "";
      document.querySelectorAll(".banner-tab").forEach(function(el) {
        var isActive = el.getAttribute("data-group") === groupCode;
        el.classList.toggle("active", isActive);
        if (isActive) activeName = el.getAttribute("data-banner-name") || el.textContent;
      });

      // Update banner name labels under each question title
      if (activeName) {
        document.querySelectorAll(".banner-name-label").forEach(function(el) {
          el.textContent = activeName;
        });
      }

      // Show/hide columns by banner group CSS class
      // Total columns (bg-total) are always visible
      bannerGroups.forEach(function(code) {
        var cols = document.querySelectorAll(".bg-" + code);
        cols.forEach(function(col) {
          col.style.display = (code === groupCode) ? "" : "none";
        });
      });

      // Reset sort when switching banner groups
      sortState = {};
      document.querySelectorAll(".ct-sort-indicator").forEach(function(ind) {
        ind.textContent = " \\u21C5";
        ind.classList.remove("ct-sort-active");
      });
      Object.keys(originalRowOrder).forEach(function(tableId) {
        var table = document.getElementById(tableId);
        if (!table) return;
        var tbody = table.querySelector("tbody");
        if (!tbody) return;
        originalRowOrder[tableId].forEach(function(row) {
          tbody.appendChild(row);
        });
        sortChartBars(table, null);
      });

      // Build column toggle chips for this group
      buildColumnChips(groupCode);

      // Rebuild chart column pickers for new banner group
      buildChartPickersForGroup(groupCode);

      // Update insight text for new banner group
      updateInsightsForBanner(activeName);

      // Re-apply hidden columns for this group
      if (hiddenColumns[groupCode]) {
        Object.keys(hiddenColumns[groupCode]).forEach(function(colKey) {
          document.querySelectorAll("th[data-col-key=\\"" + colKey + "\\"], td[data-col-key=\\"" + colKey + "\\"]").forEach(function(el) {
            el.style.display = "none";
          });
        });
      }
    }

    // Heatmap toggle - reads data-heatmap attribute from cells
    function toggleHeatmap(enabled) {
      heatmapEnabled = enabled;
      document.querySelectorAll(".ct-heatmap-cell").forEach(function(td) {
        if (enabled) {
          var colour = td.getAttribute("data-heatmap");
          if (colour) td.style.backgroundColor = colour;
        } else {
          td.style.backgroundColor = "";
        }
      });
    }

    // Frequency toggle
    function toggleFrequency(enabled) {
      var main = document.getElementById("main-content");
      if (enabled) {
        main.classList.add("show-freq");
      } else {
        main.classList.remove("show-freq");
      }
    }

    // ---- PRINT REPORT ----
    // Shows all questions for the active banner and triggers browser print
    function printReport() {
      // Remember which question was active
      var activeContainer = document.querySelector(".question-container.active");
      var activeIndex = activeContainer ? activeContainer.id.replace("q-container-", "") : "0";

      // Show all question containers for print
      var allContainers = document.querySelectorAll(".question-container");
      allContainers.forEach(function(el) {
        el.classList.add("active");
        el.style.display = "block";
      });

      // Show charts if they have content
      document.querySelectorAll(".chart-wrapper").forEach(function(div) {
        if (div.querySelector("svg")) {
          div.style.display = "block";
        }
      });

      // Show insights that have content
      var insightStates = [];
      document.querySelectorAll(".insight-container").forEach(function(container) {
        var editor = container.querySelector(".insight-editor");
        var hadContent = editor && editor.textContent.trim() !== "";
        insightStates.push({ el: container, was: container.style.display });
        if (hadContent) container.style.display = "block";
      });

      // Trigger print
      window.print();

      // Restore original state after print dialog closes
      allContainers.forEach(function(el) {
        el.classList.remove("active");
        el.style.display = "";
      });
      var restoreEl = document.getElementById("q-container-" + activeIndex);
      if (restoreEl) restoreEl.classList.add("active");

      // Restore chart visibility based on chart toggle state
      var chartCheckbox = document.querySelector("input[onchange*=toggleChart]");
      var chartsOn = chartCheckbox && chartCheckbox.checked;
      document.querySelectorAll(".chart-wrapper").forEach(function(div) {
        div.style.display = chartsOn ? "block" : "none";
      });

      // Restore insight visibility
      insightStates.forEach(function(state) {
        state.el.style.display = state.was;
      });
    }

    // Chart toggle
    function toggleChart(enabled) {
      document.querySelectorAll(".chart-wrapper").forEach(function(div) {
        div.style.display = enabled ? "block" : "none";
      });
      document.querySelectorAll(".export-chart-btn").forEach(function(btn) {
        btn.style.display = enabled ? "inline-block" : "none";
      });
      document.querySelectorAll(".export-slide-btn").forEach(function(btn) {
        btn.style.display = enabled ? "inline-block" : "none";
      });
    }

    // ---- Key Insight ----
    function toggleInsight(qCode) {
      var area = document.querySelector(".insight-area[data-q-code=\\"" + qCode + "\\"]");
      if (!area) return;
      var container = area.querySelector(".insight-container");
      var btn = area.querySelector(".insight-toggle");
      if (!container) return;
      var isHidden = container.style.display === "none";
      container.style.display = isHidden ? "block" : "none";
      if (btn) {
        btn.style.display = isHidden ? "none" : "block";
      }
      if (isHidden) {
        var editor = container.querySelector(".insight-editor");
        if (editor) {
          editor.focus();
          // Mark as user-edited on input so banner switch does not overwrite
          if (!editor.getAttribute("data-has-listener")) {
            editor.addEventListener("input", function() {
              editor.setAttribute("data-user-edited", "1");
            });
            editor.setAttribute("data-has-listener", "1");
          }
        }
      }
    }

    function dismissInsight(qCode) {
      var area = document.querySelector(".insight-area[data-q-code=\\"" + qCode + "\\"]");
      if (!area) return;
      var container = area.querySelector(".insight-container");
      var btn = area.querySelector(".insight-toggle");
      var editor = area.querySelector(".insight-editor");
      // Clear content entirely and hide
      if (editor) editor.innerHTML = "";
      if (container) container.style.display = "none";
      if (btn) {
        btn.style.display = "block";
        btn.textContent = "+ Add Insight";
      }
    }

    // Update insight editors when banner group changes
    function updateInsightsForBanner(bannerName) {
      document.querySelectorAll(".insight-area").forEach(function(area) {
        var scriptEl = area.querySelector("script.insight-comments-data");
        if (!scriptEl) return;
        var comments;
        try { comments = JSON.parse(scriptEl.textContent); } catch(e) { return; }
        if (!comments || !comments.length) return;
        var editor = area.querySelector(".insight-editor");
        if (!editor) return;
        // If user has typed custom text, do not overwrite
        if (editor.getAttribute("data-user-edited")) return;
        // Find matching comment: banner-specific first, then global
        var match = null;
        for (var i = 0; i < comments.length; i++) {
          if (comments[i].banner && comments[i].banner === bannerName) {
            match = comments[i].text; break;
          }
        }
        if (!match) {
          for (var i = 0; i < comments.length; i++) {
            if (!comments[i].banner) { match = comments[i].text; break; }
          }
        }
        var container = area.querySelector(".insight-container");
        var btn = area.querySelector(".insight-toggle");
        if (match) {
          editor.textContent = match;
          if (container) container.style.display = "block";
          if (btn) btn.style.display = "none";
        } else {
          editor.innerHTML = "";
          if (container) container.style.display = "none";
          if (btn) { btn.style.display = "block"; btn.textContent = "+ Add Insight"; }
        }
      });
    }

  '
}


#' Build Chart Column Picker JavaScript
#'
#' Chart column picker, multi-column stacked/horizontal SVG builders,
#' HSL colour utilities, and chart PNG export.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_chart_picker <- function() {
  '
    // ---- Chart Column Picker ----
    var chartColumnState = {}; // qCode -> { colKey: true/false }

    // Get column keys that belong to the active banner group (+ Total)
    function getChartKeysForGroup(chartData, groupCode) {
      var allKeys = Object.keys(chartData.columns);
      var totalKey = allKeys[0]; // First key is always Total

      // Find keys belonging to this banner group by checking table column classes
      var groupKeys = [totalKey];
      var seen = {};
      seen[totalKey] = true;
      document.querySelectorAll("th.ct-data-col.bg-" + groupCode + "[data-col-key]").forEach(function(th) {
        var key = th.getAttribute("data-col-key");
        if (!seen[key] && chartData.columns[key]) {
          seen[key] = true;
          groupKeys.push(key);
        }
      });
      return groupKeys;
    }

    function initChartColumnPickers() {
      buildChartPickersForGroup(currentGroup);
    }

    function buildChartPickersForGroup(groupCode) {
      // Remove existing pickers
      document.querySelectorAll(".chart-col-picker").forEach(function(el) { el.remove(); });

      document.querySelectorAll(".chart-wrapper[data-chart-data]").forEach(function(wrapper) {
        var qCode = wrapper.getAttribute("data-q-code");
        var data = JSON.parse(wrapper.getAttribute("data-chart-data"));
        if (!data || !data.columns) return;

        var keys = getChartKeysForGroup(data, groupCode);
        if (keys.length === 0) return;

        // Always init state so JS rebuild renders priority metrics
        chartColumnState[qCode] = {};
        chartColumnState[qCode][keys[0]] = true;

        // Only show column picker when multiple columns available
        if (keys.length > 1) {
          var bar = document.createElement("div");
          bar.className = "chart-col-picker";
          bar.setAttribute("data-q-code", qCode);

          var lbl = document.createElement("span");
          lbl.className = "col-chip-label";
          lbl.textContent = "Chart:";
          bar.appendChild(lbl);

          keys.forEach(function(key, idx) {
            var chip = document.createElement("button");
            chip.className = "col-chip" + (idx === 0 ? "" : " col-chip-off");
            chip.setAttribute("data-col-key", key);
            chip.textContent = data.columns[key].display;
            chip.onclick = function() {
              toggleChartColumn(qCode, key, chip);
            };
            bar.appendChild(chip);
          });

          var svg = wrapper.querySelector("svg");
          if (svg) wrapper.insertBefore(bar, svg);
        }

        // Always rebuild chart via JS (renders priority metrics etc.)
        rebuildChartSVG(qCode);
      });
    }

    function toggleChartColumn(qCode, colKey, chipEl) {
      if (!chartColumnState[qCode]) chartColumnState[qCode] = {};
      var isOn = !!chartColumnState[qCode][colKey];
      if (isOn) {
        // Prevent deselecting the last column
        var activeCount = Object.keys(chartColumnState[qCode]).filter(function(k) {
          return chartColumnState[qCode][k];
        }).length;
        if (activeCount <= 1) return;
        delete chartColumnState[qCode][colKey];
        chipEl.classList.add("col-chip-off");
      } else {
        chartColumnState[qCode][colKey] = true;
        chipEl.classList.remove("col-chip-off");
      }
      rebuildChartSVG(qCode);
    }

    function rebuildChartSVG(qCode) {
      var wrapper = document.querySelector(".chart-wrapper[data-q-code=\\"" + qCode + "\\"]");
      if (!wrapper) return;
      var data = JSON.parse(wrapper.getAttribute("data-chart-data"));
      if (!data) return;

      var selectedKeys = Object.keys(chartColumnState[qCode] || {}).filter(function(k) {
        return chartColumnState[qCode][k];
      });
      if (selectedKeys.length === 0) return;

      var oldSvg = wrapper.querySelector("svg");
      if (!oldSvg) return;

      var svgMarkup = "";
      if (data.chart_type === "stacked") {
        svgMarkup = buildMultiStackedSVG(data, selectedKeys, qCode);
      } else {
        svgMarkup = buildMultiHorizontalSVG(data, selectedKeys);
      }

      if (!svgMarkup) return;
      var temp = document.createElement("div");
      temp.innerHTML = svgMarkup;
      var newSvg = temp.querySelector("svg");
      if (newSvg) oldSvg.replaceWith(newSvg);
    }

    // Build multi-column stacked bar SVG (one bar per selected column)
    function buildMultiStackedSVG(data, selectedKeys, qCode) {
      var barH = 36, barGap = 8, labelMargin = 10;
      var hasPM = data.priority_metric && data.priority_metric.label;
      var pmDecimals = (hasPM && data.priority_metric.decimals != null) ? data.priority_metric.decimals : 1;
      var metricW = hasPM ? 90 : 0;
      var barW = 680;
      var headerH = hasPM ? 20 : 4;
      // Calculate label column width for column names
      var maxLabelLen = 0;
      selectedKeys.forEach(function(k) {
        var len = (data.columns[k].display || "").length;
        if (len > maxLabelLen) maxLabelLen = len;
      });
      var colLabelW = Math.max(60, maxLabelLen * 7 + 16);
      var barStartX = colLabelW;
      var barUsable = barW - colLabelW - labelMargin - metricW;

      var barCount = selectedKeys.length;
      var legendY = headerH + barCount * (barH + barGap) + 16;
      var labels = data.labels || [];
      var colours = data.colours || [];

      // Pre-calculate legend layout
      var legPositions = [], legX = labelMargin, legRow = 0;
      for (var li = 0; li < labels.length; li++) {
        var legText = labels[li] + " (" + Math.round(data.columns[selectedKeys[0]].values[li]) + "%)";
        var itemW = legText.length * 6 + 30;
        if (legX + itemW > barW - labelMargin && li > 0) { legRow++; legX = labelMargin; }
        legPositions.push({ x: legX, row: legRow, text: legText });
        legX += itemW;
      }
      var legendRows = legRow + 1;
      var totalH = legendY + legendRows * 18 + 8;

      var clipId = "mc-clip-" + qCode.replace(/[^a-zA-Z0-9]/g, "-");
      var p = [];
      p.push("<svg xmlns=\\"http://www.w3.org/2000/svg\\" viewBox=\\"0 0 " + barW + " " + totalH + "\\" role=\\"img\\" aria-label=\\"Distribution chart\\" style=\\"font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;\\">");

      // Priority metric header (right-aligned, above bars)
      if (hasPM) {
        p.push("<text x=\\"" + (barW - labelMargin) + "\\" y=\\"" + 14 + "\\" text-anchor=\\"end\\" fill=\\"#94a3b8\\" font-size=\\"9\\" font-weight=\\"600\\">" + escapeHtml(data.priority_metric.label) + "</text>");
      }

      selectedKeys.forEach(function(key, ki) {
        var y = headerH + ki * (barH + barGap);
        var vals = data.columns[key].values;
        var total = 0;
        vals.forEach(function(v) { total += v; });
        if (total <= 0) return;

        var cid = clipId + "-" + ki;
        p.push("<defs><clipPath id=\\"" + cid + "\\"><rect x=\\"" + barStartX + "\\" y=\\"" + y + "\\" width=\\"" + barUsable + "\\" height=\\"" + barH + "\\" rx=\\"5\\" ry=\\"5\\"/></clipPath></defs>");

        // Column label
        p.push("<text x=\\"" + (colLabelW - 8) + "\\" y=\\"" + (y + barH / 2) + "\\" text-anchor=\\"end\\" dominant-baseline=\\"central\\" fill=\\"#374151\\" font-size=\\"11\\" font-weight=\\"600\\">" + escapeHtml(data.columns[key].display) + "</text>");

        // Segments
        var xOff = barStartX;
        for (var si = 0; si < vals.length; si++) {
          var segW = (vals[si] / total) * barUsable;
          if (segW < 1) continue;
          p.push("<rect x=\\"" + xOff + "\\" y=\\"" + y + "\\" width=\\"" + segW + "\\" height=\\"" + barH + "\\" fill=\\"" + (colours[si] || "#999") + "\\" clip-path=\\"url(#" + cid + ")\\"/>");

          // Label inside if fits
          var pctText = Math.round(vals[si]) + "%";
          if (segW > 35) {
            var tFill = getLuminance(colours[si] || "#999") > 0.65 ? "#5c4a3a" : "#ffffff";
            p.push("<text x=\\"" + (xOff + segW / 2) + "\\" y=\\"" + (y + barH / 2) + "\\" text-anchor=\\"middle\\" dominant-baseline=\\"central\\" fill=\\"" + tFill + "\\" font-size=\\"11\\" font-weight=\\"600\\">" + pctText + "</text>");
          }
          xOff += segW;
        }

        // Priority metric value -- styled pill to the right of bar
        if (hasPM) {
          var pmVals = data.priority_metric.values || {};
          var pmVal = pmVals[key];
          if (pmVal != null) {
            var pmText = pmVal.toFixed(pmDecimals);
            var pmBoxX = barW - metricW + 4;
            var pmBoxW = metricW - 14;
            var pmBoxY = y + 4;
            var pmBoxH = barH - 8;
            p.push("<rect x=\\"" + pmBoxX + "\\" y=\\"" + pmBoxY + "\\" width=\\"" + pmBoxW + "\\" height=\\"" + pmBoxH + "\\" rx=\\"4\\" fill=\\"#f0fafa\\" stroke=\\"#d0e8e8\\" stroke-width=\\"1\\"/>");
            p.push("<text x=\\"" + (pmBoxX + pmBoxW / 2) + "\\" y=\\"" + (y + barH / 2) + "\\" text-anchor=\\"middle\\" dominant-baseline=\\"central\\" fill=\\"#1a2744\\" font-size=\\"13\\" font-weight=\\"700\\">" + pmText + "</text>");
          }
        }
      });

      // Legend (uses first selected column values for display)
      var firstVals = data.columns[selectedKeys[0]].values;
      for (var li = 0; li < labels.length; li++) {
        var pos = legPositions[li];
        var legY = legendY + pos.row * 18;
        var legLabel = labels[li] + " (" + Math.round(firstVals[li]) + "%)";
        p.push("<circle cx=\\"" + (pos.x + 4.5) + "\\" cy=\\"" + (legY + 5) + "\\" r=\\"4.5\\" fill=\\"" + (colours[li] || "#999") + "\\"/>");
        p.push("<text x=\\"" + (pos.x + 13) + "\\" y=\\"" + (legY + 9) + "\\" fill=\\"#64748b\\" font-size=\\"10.5\\">" + escapeHtml(legLabel) + "</text>");
      }

      p.push("</svg>");
      return p.join("\\n");
    }

    // Wrap long label into 2 lines at nearest space to midpoint
    function wrapLabel(label, maxChars) {
      if (label.length <= maxChars) return [label];
      var mid = Math.floor(label.length / 2);
      var bestSplit = -1, bestDist = label.length;
      for (var i = 0; i < label.length; i++) {
        if (label[i] === " " && Math.abs(i - mid) < bestDist) {
          bestDist = Math.abs(i - mid);
          bestSplit = i;
        }
      }
      if (bestSplit === -1) return [label];
      return [label.substring(0, bestSplit), label.substring(bestSplit + 1)];
    }

    // Distinct colour palette from brand colour using HSL rotation
    function getDistinctPalette(brandHex, count) {
      var r = parseInt(brandHex.substr(1, 2), 16) / 255;
      var g = parseInt(brandHex.substr(3, 2), 16) / 255;
      var b = parseInt(brandHex.substr(5, 2), 16) / 255;
      var mx = Math.max(r, g, b), mn = Math.min(r, g, b);
      var h = 0, s = 0, l = (mx + mn) / 2;
      if (mx !== mn) {
        var d = mx - mn;
        s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
        if (mx === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
        else if (mx === g) h = ((b - r) / d + 2) / 6;
        else h = ((r - g) / d + 4) / 6;
      }
      var palette = [];
      var offsets = [0, 35, 190, 60, 150];
      for (var i = 0; i < count; i++) {
        var oh = ((h * 360 + (offsets[i] || i * 72)) % 360) / 360;
        var os = i === 0 ? s : Math.max(0.35, s * 0.8);
        var ol = i === 0 ? l : Math.min(0.55, l + 0.05);
        palette.push(hslToHex(oh, os, ol));
      }
      return palette;
    }

    function hslToHex(h, s, l) {
      var r2, g2, b2;
      if (s === 0) { r2 = g2 = b2 = l; }
      else {
        var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        var pp = 2 * l - q;
        r2 = hue2rgb(pp, q, h + 1/3);
        g2 = hue2rgb(pp, q, h);
        b2 = hue2rgb(pp, q, h - 1/3);
      }
      return "#" + ((1 << 24) + (Math.round(r2 * 255) << 16) + (Math.round(g2 * 255) << 8) + Math.round(b2 * 255)).toString(16).slice(1);
    }

    function hue2rgb(p, q, t) {
      if (t < 0) t += 1; if (t > 1) t -= 1;
      if (t < 1/6) return p + (q - p) * 6 * t;
      if (t < 1/2) return q;
      if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
      return p;
    }

    // Build multi-column horizontal bar SVG (grouped bars per category)
    function buildMultiHorizontalSVG(data, selectedKeys) {
      var labels = data.labels || [];
      var nCols = selectedKeys.length;
      var hasPM = data.priority_metric && data.priority_metric.label;
      var pmDecimals = (hasPM && data.priority_metric.decimals != null) ? data.priority_metric.decimals : 1;
      var barH = 22, subGap = 3, groupGap = 12;
      var wrapThreshold = 30;

      // Wrap labels and calculate widths
      var wrappedLabels = labels.map(function(l) { return wrapLabel(l, wrapThreshold); });
      var maxLine1 = 0, hasWrapped = false;
      wrappedLabels.forEach(function(lines) {
        if (lines[0].length > maxLine1) maxLine1 = lines[0].length;
        if (lines.length > 1) hasWrapped = true;
      });
      var labelW = Math.max(160, maxLine1 * 6.2 + 16);
      var valueW = 45, chartW = 680;
      var barAreaW = chartW - labelW - valueW - 20;
      if (barAreaW < 200) { chartW = labelW + valueW + 20 + 300; barAreaW = 300; }

      // Find max value across selected columns
      var maxVal = 0;
      selectedKeys.forEach(function(key) {
        data.columns[key].values.forEach(function(v) {
          if (v > maxVal) maxVal = v;
        });
      });
      if (maxVal <= 0) maxVal = 1;

      var groupH = nCols * (barH + subGap) - subGap;
      var wrapExtra = hasWrapped ? 10 : 0;
      var topMargin = 4;
      var barsH = topMargin;

      // Pre-calculate group positions accounting for wrapped labels
      var groupPositions = [];
      wrappedLabels.forEach(function(lines) {
        groupPositions.push(barsH);
        var extra = lines.length > 1 ? 10 : 0;
        barsH += groupH + groupGap + extra;
      });

      // Add space for priority metric pill strip below bars
      var metricStripH = (hasPM && nCols > 0) ? 36 : 0;
      var totalH = barsH + metricStripH;

      // Distinct colour palette for columns
      var bc = data.brand_colour || "#0d8a8a";
      var colColours = nCols > 1 ? getDistinctPalette(bc, nCols) : [bc];

      var p = [];
      p.push("<svg xmlns=\\"http://www.w3.org/2000/svg\\" viewBox=\\"0 0 " + chartW + " " + totalH + "\\" role=\\"img\\" aria-label=\\"Bar chart\\" style=\\"font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;\\">");

      labels.forEach(function(label, li) {
        var groupY = groupPositions[li];
        var lines = wrappedLabels[li];

        selectedKeys.forEach(function(key, ki) {
          var y = groupY + ki * (barH + subGap);
          var val = data.columns[key].values[li] || 0;
          var barW = Math.max((val / maxVal) * barAreaW, 2);
          var pctText = Math.round(val) + "%";
          var colour = colColours[ki];

          // Category label only on first bar of group -- with wrapping
          if (ki === 0) {
            if (lines.length === 1) {
              p.push("<text x=\\"" + (labelW - 8) + "\\" y=\\"" + (y + barH / 2) + "\\" text-anchor=\\"end\\" dominant-baseline=\\"central\\" fill=\\"#374151\\" font-size=\\"11\\" font-weight=\\"500\\">" + escapeHtml(lines[0]) + "</text>");
            } else {
              p.push("<text x=\\"" + (labelW - 8) + "\\" text-anchor=\\"end\\" fill=\\"#374151\\" font-size=\\"11\\" font-weight=\\"500\\">");
              p.push("<tspan x=\\"" + (labelW - 8) + "\\" y=\\"" + (y + barH / 2 - 6) + "\\">" + escapeHtml(lines[0]) + "</tspan>");
              p.push("<tspan x=\\"" + (labelW - 8) + "\\" dy=\\"13\\">" + escapeHtml(lines[1]) + "</tspan>");
              p.push("</text>");
            }
          }

          p.push("<rect x=\\"" + labelW + "\\" y=\\"" + y + "\\" width=\\"" + barW + "\\" height=\\"" + barH + "\\" rx=\\"3\\" fill=\\"" + colour + "\\" opacity=\\"0.85\\"/>");
          p.push("<text x=\\"" + (labelW + barW + 8) + "\\" y=\\"" + (y + barH / 2) + "\\" dominant-baseline=\\"central\\" fill=\\"#64748b\\" font-size=\\"11\\" font-weight=\\"600\\">" + pctText + "</text>");

          // Column name label (small, after percentage, only if multiple columns)
          if (nCols > 1) {
            var afterPct = labelW + barW + 8 + pctText.length * 7 + 6;
            p.push("<text x=\\"" + afterPct + "\\" y=\\"" + (y + barH / 2) + "\\" dominant-baseline=\\"central\\" fill=\\"#94a3b8\\" font-size=\\"9\\">" + escapeHtml(data.columns[key].display) + "</text>");
          }
        });
      });

      // Priority metric pill strip below chart
      if (hasPM) {
        var pmY = barsH + 4;
        p.push("<line x1=\\"" + labelW + "\\" x2=\\"" + (chartW - 10) + "\\" y1=\\"" + (pmY - 2) + "\\" y2=\\"" + (pmY - 2) + "\\" stroke=\\"#e2e8f0\\" stroke-width=\\"1\\"/>");
        // Metric label
        p.push("<text x=\\"" + (labelW - 8) + "\\" y=\\"" + (pmY + 16) + "\\" text-anchor=\\"end\\" fill=\\"#94a3b8\\" font-size=\\"9\\" font-weight=\\"600\\">" + escapeHtml(data.priority_metric.label) + "</text>");
        // Pill badges for each column
        var pillX = labelW;
        selectedKeys.forEach(function(key, ki) {
          var pmVals = data.priority_metric.values || {};
          var pmVal = pmVals[key];
          if (pmVal != null) {
            var pmText = escapeHtml(data.columns[key].display) + " " + pmVal.toFixed(pmDecimals);
            var pillW = pmText.length * 6.5 + 16;
            p.push("<rect x=\\"" + pillX + "\\" y=\\"" + (pmY + 2) + "\\" width=\\"" + pillW + "\\" height=\\"" + 22 + "\\" rx=\\"11\\" fill=\\"#f0fafa\\" stroke=\\"#d0e8e8\\" stroke-width=\\"1\\"/>");
            p.push("<text x=\\"" + (pillX + pillW / 2) + "\\" y=\\"" + (pmY + 16) + "\\" text-anchor=\\"middle\\" fill=\\"#1a2744\\" font-size=\\"10\\" font-weight=\\"600\\">" + pmText + "</text>");
            pillX += pillW + 8;
          }
        });
      }

      p.push("</svg>");
      return p.join("\\n");
    }

    function escapeHtml(s) {
      return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function getLuminance(hex) {
      var r = parseInt(hex.substr(1, 2), 16);
      var g = parseInt(hex.substr(3, 2), 16);
      var b = parseInt(hex.substr(5, 2), 16);
      return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    }

    function blendColour(hex, mix) {
      var r = parseInt(hex.substr(1, 2), 16);
      var g = parseInt(hex.substr(3, 2), 16);
      var b = parseInt(hex.substr(5, 2), 16);
      var fr = Math.round(255 - (255 - r) * mix);
      var fg = Math.round(255 - (255 - g) * mix);
      var fb = Math.round(255 - (255 - b) * mix);
      return "#" + ((1 << 24) + (fr << 16) + (fg << 8) + fb).toString(16).slice(1);
    }

    // Chart PNG export - injects question title, renders via canvas, downloads PNG
    function exportChartPNG(qCode) {
      var container = document.querySelector(".question-container.active");
      if (!container) return;
      var wrapper = container.querySelector(".chart-wrapper");
      if (!wrapper) return;
      var origSvg = wrapper.querySelector("svg");
      if (!origSvg) return;

      var qTitle = wrapper.getAttribute("data-q-title") || "";
      var qCodeLabel = wrapper.getAttribute("data-q-code") || qCode;

      // Clone SVG so we can modify without affecting the page
      var svgClone = origSvg.cloneNode(true);

      // Parse original viewBox
      var vb = svgClone.getAttribute("viewBox").split(" ").map(Number);
      var origW = vb[2], origH = vb[3];

      // Title dimensions
      var titleFontSize = 14;
      var titlePadding = 12;
      var titleLineHeight = titleFontSize * 1.3;
      // Title block: qCode + question text
      var titleText = qCodeLabel + " - " + qTitle;
      var titleBlockH = titlePadding + titleLineHeight + titlePadding;

      // Expand viewBox to accommodate title at top
      var newH = origH + titleBlockH;
      svgClone.setAttribute("viewBox", "0 0 " + origW + " " + newH);

      // Shift all existing content down by titleBlockH
      var gWrap = document.createElementNS("http://www.w3.org/2000/svg", "g");
      gWrap.setAttribute("transform", "translate(0," + titleBlockH + ")");
      while (svgClone.firstChild) {
        gWrap.appendChild(svgClone.firstChild);
      }
      svgClone.appendChild(gWrap);

      // Add white background
      var bgRect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
      bgRect.setAttribute("x", "0");
      bgRect.setAttribute("y", "0");
      bgRect.setAttribute("width", origW);
      bgRect.setAttribute("height", newH);
      bgRect.setAttribute("fill", "#ffffff");
      svgClone.insertBefore(bgRect, svgClone.firstChild);

      // Add title text
      var titleEl = document.createElementNS("http://www.w3.org/2000/svg", "text");
      titleEl.setAttribute("x", "10");
      titleEl.setAttribute("y", String(titlePadding + titleFontSize));
      titleEl.setAttribute("fill", "#1e293b");
      titleEl.setAttribute("font-size", String(titleFontSize));
      titleEl.setAttribute("font-weight", "600");
      titleEl.setAttribute("font-family", "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif");
      titleEl.textContent = titleText;
      // Insert after background, before content group
      svgClone.insertBefore(titleEl, gWrap);

      // Render to canvas at 3x for crisp PNG (presentation quality)
      var scale = 3;
      var canvasW = origW * scale;
      var canvasH = newH * scale;

      var svgData = new XMLSerializer().serializeToString(svgClone);
      var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
      var url = URL.createObjectURL(svgBlob);

      var img = new Image();
      img.onload = function() {
        var canvas = document.createElement("canvas");
        canvas.width = canvasW;
        canvas.height = canvasH;
        var ctx = canvas.getContext("2d");
        ctx.fillStyle = "#ffffff";
        ctx.fillRect(0, 0, canvasW, canvasH);
        ctx.drawImage(img, 0, 0, canvasW, canvasH);
        URL.revokeObjectURL(url);

        canvas.toBlob(function(blob) {
          downloadBlob(blob, qCode + "_chart.png");
        }, "image/png");
      };
      img.src = url;
    }

  '
}


#' Build Slide Export JavaScript
#'
#' Presentation-quality SVG slide builder with title, base, chart,
#' metrics strip, and insight — rendered to PNG at 3x resolution.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_slide_export <- function() {
  '
    // ---- Slide PNG Export ----
    // Builds a presentation-quality SVG slide with title, base, chart,
    // metrics strip, and insight -- then renders to PNG at 3x resolution.
    function exportSlidePNG(qCode) {
      var container = document.querySelector(".question-container.active");
      if (!container) return;
      var wrapper = container.querySelector(".chart-wrapper");
      if (!wrapper) return;
      var chartSvg = wrapper.querySelector("svg");
      if (!chartSvg) return;

      var qTitle = wrapper.getAttribute("data-q-title") || "";
      var qCodeLabel = wrapper.getAttribute("data-q-code") || qCode;
      var ns = "http://www.w3.org/2000/svg";
      var W = 960, fontFamily = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";

      // ---- Gather data from DOM (pre-calculated, no recalculation) ----
      // Base size
      var baseText = "";
      var baseRow = container.querySelector("tr.ct-row-base");
      if (baseRow) {
        var baseCells = baseRow.querySelectorAll("td:not([style*=none])");
        if (baseCells.length > 1) baseText = "Base: n=" + baseCells[1].textContent.trim();
      }

      // Metrics (mean, index, NPS from table)
      var metrics = [];
      container.querySelectorAll("tr.ct-row-mean").forEach(function(row) {
        var labelCell = row.querySelector("td.ct-label-col");
        var dataCells = row.querySelectorAll("td:not(.ct-label-col):not([style*=none])");
        if (labelCell && dataCells.length > 0) {
          var label = labelCell.textContent.trim();
          var val = dataCells[0].textContent.trim().split("\\n")[0].trim();
          if (val && val !== "-") metrics.push(label + ": " + val);
        }
      });

      // Insight text
      var insightText = "";
      var insightEditor = container.querySelector(".insight-editor");
      if (insightEditor) insightText = insightEditor.textContent.trim();

      // ---- Calculate slide layout ----
      var pad = 28;
      var titleY = pad + 16;
      var metaY = titleY + 18;
      var chartTop = metaY + 22;

      // Clone chart SVG and measure
      var chartClone = chartSvg.cloneNode(true);
      var chartVB = chartClone.getAttribute("viewBox").split(" ").map(Number);
      var chartOrigW = chartVB[2], chartOrigH = chartVB[3];
      var chartScale = (W - pad * 2) / chartOrigW;
      var chartDisplayH = chartOrigH * chartScale;

      var metricsY = chartTop + chartDisplayH + 16;
      var metricsH = metrics.length > 0 ? 32 : 0;
      var insightY = metricsY + metricsH + (metricsH > 0 ? 8 : 0);
      var insightH = insightText ? 40 : 0;
      var totalH = insightY + insightH + pad;

      // ---- Build slide SVG ----
      var svg = document.createElementNS(ns, "svg");
      svg.setAttribute("xmlns", ns);
      svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
      svg.setAttribute("style", "font-family:" + fontFamily + ";");

      // White background
      var bg = document.createElementNS(ns, "rect");
      bg.setAttribute("width", W); bg.setAttribute("height", totalH);
      bg.setAttribute("fill", "#ffffff");
      svg.appendChild(bg);

      // Title
      var title = document.createElementNS(ns, "text");
      title.setAttribute("x", pad); title.setAttribute("y", titleY);
      title.setAttribute("fill", "#1a2744"); title.setAttribute("font-size", "16");
      title.setAttribute("font-weight", "700");
      title.textContent = qCodeLabel + " - " + qTitle;
      svg.appendChild(title);

      // Base + banner meta
      var meta = document.createElementNS(ns, "text");
      meta.setAttribute("x", pad); meta.setAttribute("y", metaY);
      meta.setAttribute("fill", "#94a3b8"); meta.setAttribute("font-size", "11");
      meta.textContent = baseText;
      svg.appendChild(meta);

      // Chart (embedded via <g> transform)
      var chartG = document.createElementNS(ns, "g");
      chartG.setAttribute("transform", "translate(" + pad + "," + chartTop + ") scale(" + chartScale + ")");
      // Move all children from clone into group
      while (chartClone.firstChild) chartG.appendChild(chartClone.firstChild);
      svg.appendChild(chartG);

      // Metrics strip
      if (metrics.length > 0) {
        var metricsStr = metrics.join("  |  ");
        var mText = document.createElementNS(ns, "text");
        mText.setAttribute("x", pad); mText.setAttribute("y", metricsY + 18);
        mText.setAttribute("fill", "#5c4a2a"); mText.setAttribute("font-size", "12");
        mText.setAttribute("font-weight", "600");
        mText.textContent = metricsStr;
        svg.appendChild(mText);

        // Subtle line above metrics
        var mLine = document.createElementNS(ns, "line");
        mLine.setAttribute("x1", pad); mLine.setAttribute("x2", W - pad);
        mLine.setAttribute("y1", metricsY); mLine.setAttribute("y2", metricsY);
        mLine.setAttribute("stroke", "#e2e8f0"); mLine.setAttribute("stroke-width", "1");
        svg.appendChild(mLine);
      }

      // Insight callout
      if (insightText) {
        // Accent line
        var iLine = document.createElementNS(ns, "line");
        iLine.setAttribute("x1", pad); iLine.setAttribute("x2", W - pad);
        iLine.setAttribute("y1", insightY); iLine.setAttribute("y2", insightY);
        iLine.setAttribute("stroke", "#e2e8f0"); iLine.setAttribute("stroke-width", "1");
        svg.appendChild(iLine);

        // Teal accent bar
        var iBar = document.createElementNS(ns, "rect");
        iBar.setAttribute("x", pad); iBar.setAttribute("y", insightY + 4);
        iBar.setAttribute("width", "3"); iBar.setAttribute("height", "24");
        iBar.setAttribute("fill", "#0d8a8a"); iBar.setAttribute("rx", "1.5");
        svg.appendChild(iBar);

        var iText = document.createElementNS(ns, "text");
        iText.setAttribute("x", pad + 12); iText.setAttribute("y", insightY + 22);
        iText.setAttribute("fill", "#374151"); iText.setAttribute("font-size", "12");
        iText.setAttribute("font-style", "italic");
        iText.textContent = insightText;
        svg.appendChild(iText);
      }

      // ---- Render SVG to PNG at 3x ----
      var scale = 3;
      var svgData = new XMLSerializer().serializeToString(svg);
      var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
      var url = URL.createObjectURL(svgBlob);

      var img = new Image();
      img.onload = function() {
        var canvas = document.createElement("canvas");
        canvas.width = W * scale;
        canvas.height = totalH * scale;
        var ctx = canvas.getContext("2d");
        ctx.fillStyle = "#ffffff";
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        URL.revokeObjectURL(url);
        canvas.toBlob(function(blob) {
          downloadBlob(blob, qCode + "_slide.png");
        }, "image/png");
      };
      img.src = url;
    }

  '
}


#' Build Table Export and Init JavaScript
#'
#' Table data extraction, CSV/Excel export, column toggle chips,
#' column sort, downloadBlob utility, and DOMContentLoaded init.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_table_export_and_init <- function() {
  '
    // Extract table data as 2D array (shared by CSV and Excel export)
    function extractTableData(qCode) {
      var activeContainer = document.querySelector(".question-container.active");
      if (!activeContainer) return null;
      var table = activeContainer.querySelector("table.ct-table");
      if (!table) return null;

      var data = [];
      var rows = table.querySelectorAll("tr");
      rows.forEach(function(row) {
        var cells = row.querySelectorAll("th, td");
        var rowData = [];
        cells.forEach(function(cell) {
          if (cell.style.display === "none") return;
          var clone = cell.cloneNode(true);
          var freqs = clone.querySelectorAll(".ct-freq");
          freqs.forEach(function(f) { f.remove(); });
          var sigs = clone.querySelectorAll(".ct-sig");
          sigs.forEach(function(s) { s.remove(); });
          rowData.push(clone.textContent.trim());
        });
        if (rowData.length > 0) data.push(rowData);
      });
      return data;
    }

    // CSV export
    function exportCSV(qCode) {
      var data = extractTableData(qCode);
      if (!data) return;

      var csv = data.map(function(row) {
        return row.map(function(cell) {
          var text = cell.replace(/,/g, "");
          if (text.indexOf(",") >= 0 || text.indexOf("\\n") >= 0 || text.indexOf("\\"") >= 0) {
            text = "\\"" + text.replace(/"/g, "\\"\\"") + "\\"";
          }
          return text;
        }).join(",");
      }).join("\\n");

      var blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
      downloadBlob(blob, qCode + "_crosstab.csv");
    }

    // Excel export (Excel XML Spreadsheet format - .xls)
    function exportExcel(qCode) {
      var data = extractTableData(qCode);
      if (!data) return;

      // Get question title
      var activeContainer = document.querySelector(".question-container.active");
      var qTitle = "";
      if (activeContainer) {
        var titleEl = activeContainer.querySelector(".question-text");
        if (titleEl) qTitle = titleEl.textContent.trim();
      }

      var xml = [];
      xml.push("<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>");
      xml.push("<?mso-application progid=\\"Excel.Sheet\\"?>");
      xml.push("<Workbook xmlns=\\"urn:schemas-microsoft-com:office:spreadsheet\\"");
      xml.push(" xmlns:ss=\\"urn:schemas-microsoft-com:office:spreadsheet\\">");
      xml.push("<Styles>");
      xml.push("<Style ss:ID=\\"header\\"><Font ss:Bold=\\"1\\" ss:Size=\\"11\\"/>");
      xml.push("<Interior ss:Color=\\"#F8F9FA\\" ss:Pattern=\\"Solid\\"/></Style>");
      xml.push("<Style ss:ID=\\"title\\"><Font ss:Bold=\\"1\\" ss:Size=\\"12\\"/></Style>");
      xml.push("<Style ss:ID=\\"normal\\"><Font ss:Size=\\"11\\"/></Style>");
      xml.push("</Styles>");
      xml.push("<Worksheet ss:Name=\\"" + escapeXml(qCode) + "\\">");
      xml.push("<Table>");

      // Title row
      if (qTitle) {
        xml.push("<Row>");
        xml.push("<Cell ss:StyleID=\\"title\\"><Data ss:Type=\\"String\\">" +
                  escapeXml(qCode + " - " + qTitle) + "</Data></Cell>");
        xml.push("</Row>");
        xml.push("<Row></Row>");
      }

      data.forEach(function(row, rowIdx) {
        xml.push("<Row>");
        row.forEach(function(cell) {
          var styleId = rowIdx === 0 ? "header" : "normal";
          // Try to detect numeric values
          var num = parseFloat(cell.replace(/[,%]/g, ""));
          var isNum = !isNaN(num) && cell.match(/^[\\d,\\.%\\s\\-]+$/);
          if (isNum && cell.indexOf("%") >= 0) {
            // Percentage - store as number
            xml.push("<Cell ss:StyleID=\\"" + styleId + "\\"><Data ss:Type=\\"Number\\">" +
                      num + "</Data></Cell>");
          } else if (isNum && cell.trim() !== "") {
            xml.push("<Cell ss:StyleID=\\"" + styleId + "\\"><Data ss:Type=\\"Number\\">" +
                      num + "</Data></Cell>");
          } else {
            xml.push("<Cell ss:StyleID=\\"" + styleId + "\\"><Data ss:Type=\\"String\\">" +
                      escapeXml(cell) + "</Data></Cell>");
          }
        });
        xml.push("</Row>");
      });

      xml.push("</Table></Worksheet></Workbook>");

      var blob = new Blob([xml.join("\\n")], {
        type: "application/vnd.ms-excel;charset=utf-8"
      });
      downloadBlob(blob, qCode + "_crosstab.xls");
    }

    function escapeXml(s) {
      return s.replace(/&/g, "&amp;").replace(/</g, "&lt;")
              .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }

    function downloadBlob(blob, filename) {
      var url = URL.createObjectURL(blob);
      var a = document.createElement("a");
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    }

    // ---- Column Toggle ----

    function buildColumnChips(groupCode) {
      var existing = document.getElementById("col-chip-bar");
      if (existing) existing.remove();

      var headers = document.querySelectorAll(
        "th.ct-data-col.bg-" + groupCode + "[data-col-key]"
      );
      var seen = {};
      var columns = [];
      headers.forEach(function(th) {
        var key = th.getAttribute("data-col-key");
        if (!seen[key]) {
          seen[key] = true;
          var label = th.querySelector(".ct-header-text");
          columns.push({ key: key, label: label ? label.textContent.trim() : key });
        }
      });

      if (columns.length <= 1) return;

      if (!hiddenColumns[groupCode]) hiddenColumns[groupCode] = {};

      var bar = document.createElement("div");
      bar.id = "col-chip-bar";
      bar.className = "col-chip-bar";

      var lbl = document.createElement("span");
      lbl.className = "col-chip-label";
      lbl.textContent = "Columns:";
      bar.appendChild(lbl);

      columns.forEach(function(col) {
        var chip = document.createElement("button");
        chip.className = "col-chip";
        chip.setAttribute("data-col-key", col.key);
        chip.textContent = col.label;
        if (hiddenColumns[groupCode][col.key]) chip.classList.add("col-chip-off");
        chip.onclick = function() { toggleColumn(groupCode, col.key, chip); };
        bar.appendChild(chip);
      });

      var bannerTabs = document.querySelector(".banner-tabs");
      if (bannerTabs) {
        bannerTabs.parentNode.insertBefore(bar, bannerTabs.nextSibling);
      }
    }

    function toggleColumn(groupCode, colKey, chipEl) {
      if (!hiddenColumns[groupCode]) hiddenColumns[groupCode] = {};
      var isHidden = !!hiddenColumns[groupCode][colKey];

      if (isHidden) {
        delete hiddenColumns[groupCode][colKey];
        chipEl.classList.remove("col-chip-off");
        document.querySelectorAll("th[data-col-key=\\"" + colKey + "\\"], td[data-col-key=\\"" + colKey + "\\"]").forEach(function(el) {
          el.style.display = "";
        });
      } else {
        hiddenColumns[groupCode][colKey] = true;
        chipEl.classList.add("col-chip-off");
        document.querySelectorAll("th[data-col-key=\\"" + colKey + "\\"], td[data-col-key=\\"" + colKey + "\\"]").forEach(function(el) {
          el.style.display = "none";
        });
      }
    }

    // ---- Column Sort ----

    function initSortHeaders() {
      document.querySelectorAll("th.ct-data-col[data-col-key]").forEach(function(th) {
        var indicator = document.createElement("span");
        indicator.className = "ct-sort-indicator";
        indicator.textContent = " \\u21C5";
        th.appendChild(indicator);

        th.addEventListener("click", function() {
          var table = th.closest("table.ct-table");
          if (!table) return;
          sortByColumn(table, th.getAttribute("data-col-key"), th);
        });
      });
    }

    function sortByColumn(table, colKey, clickedTh) {
      var tbody = table.querySelector("tbody");
      if (!tbody) return;
      var tableId = table.id;

      if (!originalRowOrder[tableId]) {
        originalRowOrder[tableId] = Array.from(tbody.querySelectorAll("tr"));
      }

      if (!sortState[tableId]) sortState[tableId] = { colKey: null, direction: "none" };
      var state = sortState[tableId];
      var newDir;
      if (state.colKey !== colKey) {
        newDir = "desc";
      } else if (state.direction === "desc") {
        newDir = "asc";
      } else if (state.direction === "asc") {
        newDir = "none";
      } else {
        newDir = "desc";
      }
      state.colKey = colKey;
      state.direction = newDir;

      // Reset all indicators in this table
      table.querySelectorAll(".ct-sort-indicator").forEach(function(ind) {
        ind.textContent = " \\u21C5";
        ind.classList.remove("ct-sort-active");
      });

      var indicator = clickedTh.querySelector(".ct-sort-indicator");
      if (indicator) {
        if (newDir === "desc") {
          indicator.textContent = " \\u2193";
          indicator.classList.add("ct-sort-active");
        } else if (newDir === "asc") {
          indicator.textContent = " \\u2191";
          indicator.classList.add("ct-sort-active");
        }
      }

      if (newDir === "none") {
        originalRowOrder[tableId].forEach(function(row) { tbody.appendChild(row); });
        sortChartBars(table, null);
        return;
      }

      // Separate sortable (category, not net) vs pinned rows
      var allRows = Array.from(tbody.querySelectorAll("tr"));
      var sortable = [];
      var pinnedPositions = {};

      allRows.forEach(function(row, idx) {
        if (row.classList.contains("ct-row-category") &&
            !row.classList.contains("ct-row-net")) {
          sortable.push({ row: row, origIdx: idx });
        } else {
          pinnedPositions[idx] = row;
        }
      });

      // Get sort values
      sortable.forEach(function(item) {
        var cell = item.row.querySelector("td[data-col-key=\\"" + colKey + "\\"]");
        var raw = cell ? cell.getAttribute("data-sort-val") : null;
        var val = raw !== null ? parseFloat(raw) : NaN;
        item.sortVal = isNaN(val) ? null : val;
      });

      // Stable sort with null always last
      sortable.sort(function(a, b) {
        if (a.sortVal === null && b.sortVal === null) return a.origIdx - b.origIdx;
        if (a.sortVal === null) return 1;
        if (b.sortVal === null) return -1;
        var diff = (newDir === "desc") ? b.sortVal - a.sortVal : a.sortVal - b.sortVal;
        return diff !== 0 ? diff : a.origIdx - b.origIdx;
      });

      // Rebuild: pinned rows at original positions, sorted rows fill gaps
      var result = new Array(allRows.length);
      var keys = Object.keys(pinnedPositions);
      for (var k = 0; k < keys.length; k++) {
        result[parseInt(keys[k])] = pinnedPositions[keys[k]];
      }
      var si = 0;
      for (var i = 0; i < result.length; i++) {
        if (!result[i]) {
          result[i] = sortable[si].row;
          si++;
        }
      }

      result.forEach(function(row) { tbody.appendChild(row); });

      // Sort chart bars to match table sort order
      var sortedLabels = sortable.map(function(item) {
        var labelCell = item.row.querySelector("td.ct-label-col");
        return labelCell ? labelCell.textContent.trim() : "";
      });
      sortChartBars(table, sortedLabels);
    }

    // Reorder horizontal bar chart to match table sort
    function sortChartBars(table, sortedLabels) {
      var container = table.closest(".question-container");
      if (!container) return;
      var svg = container.querySelector(".chart-wrapper svg");
      if (!svg) return;
      var barGroups = svg.querySelectorAll("g.chart-bar-group");
      if (barGroups.length === 0) return;

      // Read bar spacing from first two groups in current DOM order
      // (positions are always recalculated, so DOM-first = visual-first)
      var groups = Array.from(barGroups);
      if (groups.length < 2) return;
      var getY = function(g) {
        var t = g.getAttribute("transform");
        return parseFloat(t.replace(/[^\\d.\\-]/g, " ").trim().split(/\\s+/)[1] || "0");
      };
      var y0 = getY(groups[0]);
      var y1 = getY(groups[1]);
      var barStep = y1 - y0;

      if (sortedLabels === null) {
        // Reset to original order using data-bar-index
        groups.sort(function(a, b) {
          return parseInt(a.getAttribute("data-bar-index")) - parseInt(b.getAttribute("data-bar-index"));
        });
        groups.forEach(function(g, i) {
          g.setAttribute("transform", "translate(0," + (y0 + i * barStep) + ")");
          svg.appendChild(g);
        });
        return;
      }

      // Build label -> group map
      var labelMap = {};
      groups.forEach(function(g) {
        var label = g.getAttribute("data-bar-label");
        if (label) labelMap[label] = g;
      });

      // Reorder: sorted labels first, then any unmatched groups keep position
      var ordered = [];
      sortedLabels.forEach(function(label) {
        if (labelMap[label]) {
          ordered.push(labelMap[label]);
          delete labelMap[label];
        }
      });
      // Append any remaining unmatched groups
      Object.keys(labelMap).forEach(function(key) {
        ordered.push(labelMap[key]);
      });

      // Apply new positions
      ordered.forEach(function(g, i) {
        g.setAttribute("transform", "translate(0," + (y0 + i * barStep) + ")");
        svg.appendChild(g);
      });
    }

    // Initialize on DOM ready
    document.addEventListener("DOMContentLoaded", function() {
      if (bannerGroups.length > 0) {
        switchBannerGroup(bannerGroups[0], null);
      }
      toggleHeatmap(true);
      initSortHeaders();
      initChartColumnPickers();
      // Auto-show insights that have content (from config or save-as)
      document.querySelectorAll(".insight-editor").forEach(function(editor) {
        if (editor.textContent.trim()) {
          var cont = editor.closest(".insight-container");
          if (cont) cont.style.display = "block";
          var area = editor.closest(".insight-area");
          if (area) {
            var btn = area.querySelector(".insight-toggle");
            if (btn) btn.style.display = "none";
          }
        }
      });
    });
  '
}


