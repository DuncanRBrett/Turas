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
      build_header(project_title, brand_colour, html_data$total_n, html_data$n_questions),
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
      build_header(project_title, brand_colour, html_data$total_n, html_data$n_questions),
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
      .export-btn, .export-chart-btn, .search-box, .toggle-label,
      .print-btn { display: none !important; }
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
      .ct-table { font-size: 10px !important; }
      .ct-th, .ct-td { padding: 3px 6px !important; }
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
build_header <- function(project_title, brand_colour, total_n, n_questions) {
  meta_parts <- c()
  if (!is.na(total_n)) {
    total_n_display <- round(as.numeric(total_n))
    meta_parts <- c(meta_parts, sprintf("n=%s", format(total_n_display, big.mark = ",")))
  }
  if (!is.na(n_questions)) meta_parts <- c(meta_parts, sprintf("%d Questions", n_questions))

  htmltools::tags$div(
    class = "header",
    htmltools::tags$div(
      class = "header-inner",
      htmltools::tags$div(
        class = "header-left",
        htmltools::tags$div(
          htmltools::tags$div(class = "header-brand", "The Research Lamppost \u00B7 Turas Analytics"),
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

  containers <- lapply(seq_along(questions), function(i) {
    q <- questions[[i]]
    q_code <- q$q_code
    q_text <- q$question_text
    stat_label <- q$primary_stat

    # Build chart div (hidden by default, toggled via JS)
    # data-q-title carries the question text for chart export (title injection)
    chart_div <- NULL
    if (!is.null(charts[[q_code]])) {
      chart_div <- htmltools::tags$div(
        class = "chart-wrapper",
        style = "display:none;",
        `data-q-code` = q_code,
        `data-q-title` = q_text,
        charts[[q_code]]
      )
    }

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
        if (!is.null(charts[[q_code]])) {
          htmltools::tags$button(
            class = "export-btn export-chart-btn",
            style = "margin-left:8px;display:none",
            onclick = sprintf("exportChartPNG('%s')", q_code),
            "\U0001F4CA Export Chart"
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
#' Plain vanilla JavaScript — no HTMLWidgets, no React, no external deps.
#'
#' @param html_data The transformed data
#' @return htmltools::tags$script
build_javascript <- function(html_data) {
  group_codes <- sapply(html_data$banner_groups, function(g) g$banner_code)

  # Use gsub instead of sprintf to avoid % escaping issues in JS regex patterns
  js_code <- '
    // Banner group codes
    var bannerGroups = BANNER_GROUPS_JSON;
    var currentGroup = bannerGroups[0] || "";
    var heatmapEnabled = true;

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
    }

    // Heatmap toggle — reads data-heatmap attribute from cells
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
    }

    // Chart toggle
    function toggleChart(enabled) {
      document.querySelectorAll(".chart-wrapper").forEach(function(div) {
        div.style.display = enabled ? "block" : "none";
      });
      document.querySelectorAll(".export-chart-btn").forEach(function(btn) {
        btn.style.display = enabled ? "inline-block" : "none";
      });
    }

    // Chart PNG export — injects question title, renders via canvas, downloads PNG
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
      var titleText = qCodeLabel + " — " + qTitle;
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

    // Excel export (Excel XML Spreadsheet format — .xls)
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
            // Percentage — store as number
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

    // Initialize on DOM ready
    document.addEventListener("DOMContentLoaded", function() {
      if (bannerGroups.length > 0) {
        switchBannerGroup(bannerGroups[0], null);
      }
      toggleHeatmap(true);
    });
  '

  js_code <- gsub("BANNER_GROUPS_JSON",
                   jsonlite::toJSON(unname(group_codes), auto_unbox = FALSE),
                   js_code, fixed = TRUE)

  htmltools::tags$script(htmltools::HTML(js_code))
}


# Null-coalescing operator
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
