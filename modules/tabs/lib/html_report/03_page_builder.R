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

  brand_colour <- config_obj$brand_colour %||% "#323367"
  accent_colour <- config_obj$accent_colour %||% "#CC9900"
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

    pinned_panel <- htmltools::tags$div(
      id = "tab-pinned",
      class = "tab-panel",
      htmltools::tags$div(
        class = "pinned-views-container",
        style = "max-width:1400px;margin:0 auto;padding:20px 32px;",
        htmltools::tags$div(
          class = "pinned-header",
          style = "display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;",
          htmltools::tags$div(
            htmltools::tags$h2(style = "font-size:18px;font-weight:700;color:#1e293b;margin-bottom:4px;", "Pinned Views"),
            htmltools::tags$p(style = "font-size:12px;color:#64748b;", "Pin questions from the Crosstabs tab to create a curated set of key findings.")
          ),
          htmltools::tags$div(
            style = "display:flex;gap:8px;",
            htmltools::tags$button(
              class = "export-btn",
              onclick = "exportAllPinnedSlides()",
              "\U0001F4E4 Export All Slides"
            ),
            htmltools::tags$button(
              class = "export-btn",
              onclick = "printPinnedViews()",
              "\U0001F5A8 Print / Save PDF"
            )
          )
        ),
        htmltools::tags$div(id = "pinned-cards-container"),
        htmltools::tags$div(
          id = "pinned-empty-state",
          style = "text-align:center;padding:60px 20px;color:#94a3b8;",
          htmltools::tags$div(style = "font-size:36px;margin-bottom:12px;", "\U0001F4CC"),
          htmltools::tags$div(style = "font-size:14px;font-weight:600;", "No pinned views yet"),
          htmltools::tags$div(style = "font-size:12px;margin-top:4px;",
            "Click the pin icon on any question in the Crosstabs tab to add it here.")
        ),
        htmltools::tags$script(type = "application/json", id = "pinned-views-data", "[]")
      )
    )

    page <- htmltools::tagList(
      htmltools::tags$head(
        htmltools::tags$meta(charset = "UTF-8"),
        htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
        htmltools::tags$title(project_title),
        build_css(brand_colour, accent_colour),
        build_dashboard_css(brand_colour),
        build_print_css()
      ),
      build_header(project_title, brand_colour, html_data$total_n, html_data$n_questions,
                         company_name = config_obj$company_name %||% "The Research Lamppost",
                         client_name = config_obj$client_name,
                         logo_data_uri = config_obj$logo_data_uri),
      build_report_tab_nav(brand_colour),
      dashboard_html,
      crosstab_panel,
      pinned_panel,
      build_help_overlay(),
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
        build_css(brand_colour, accent_colour),
        build_print_css()
      ),
      build_header(project_title, brand_colour, html_data$total_n, html_data$n_questions,
                         company_name = config_obj$company_name %||% "The Research Lamppost",
                         client_name = config_obj$client_name,
                         logo_data_uri = config_obj$logo_data_uri),
      crosstab_content,
      build_help_overlay(),
      build_javascript(html_data)
    )
  }

  htmltools::browsable(page)
}


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
    .slide-menu-item:hover { background: #f1f5f9; }
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
    /* Help overlay */
    .help-overlay {
      display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.6); z-index: 9999; cursor: pointer;
    }
    .help-overlay.active { display: flex; align-items: center; justify-content: center; }
    .help-card {
      background: #fff; border-radius: 12px; padding: 32px; max-width: 480px; width: 90%;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3); cursor: default;
    }
    .help-card h2 { font-size: 18px; margin-bottom: 16px; color: BRAND; }
    .help-card ul { list-style: none; padding: 0; }
    .help-card li {
      padding: 8px 0; border-bottom: 1px solid #f1f5f9; font-size: 13px; color: #374151;
    }
    .help-card li:last-child { border-bottom: none; }
    .help-card .help-key {
      display: inline-block; background: #f1f5f9; border-radius: 4px;
      padding: 2px 8px; font-weight: 600; color: BRAND; margin-right: 8px;
      font-size: 12px; min-width: 90px; text-align: center;
    }
    .help-card .help-dismiss {
      margin-top: 16px; text-align: center; color: #94a3b8; font-size: 12px;
    }
  '

  # Replace BRAND and ACCENT placeholders with actual colours
  css_text <- paste0(css_layout, css_tables)
  css_text <- gsub("ACCENT", ac, css_text, fixed = TRUE)
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
      .export-btn, .export-chart-btn, .export-slide-btn, .slide-export-group,
      .slide-menu, .search-box, .pin-btn,
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
      #tab-pinned { display: none !important; }
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
    ),
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('pinned')",
      `data-tab` = "pinned",
      "\U0001F4CC Pinned Views",
      htmltools::tags$span(class = "pin-count-badge", id = "pin-count-badge", style = "display:none;margin-left:4px;background:#323367;color:#fff;font-size:10px;padding:1px 6px;border-radius:8px;", "0")
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
                         company_name = "The Research Lamppost",
                         client_name = NULL,
                         logo_data_uri = NULL) {
  meta_parts <- c()
  if (!is.na(total_n)) {
    total_n_display <- round(as.numeric(total_n))
    meta_parts <- c(meta_parts, sprintf("n=%s", format(total_n_display, big.mark = ",")))
  }
  if (!is.na(n_questions)) meta_parts <- c(meta_parts, sprintf("%d Questions", n_questions))

  brand_label <- paste0(company_name, " \u00B7 Turas Analytics")

  # Build logo element if available
  logo_el <- NULL
  if (!is.null(logo_data_uri) && nzchar(logo_data_uri)) {
    logo_el <- htmltools::tags$img(
      src = logo_data_uri,
      alt = company_name,
      class = "header-logo",
      style = "height:36px;width:auto;margin-right:12px;vertical-align:middle;opacity:0.9;"
    )
  }

  # Build client name element if provided
  client_el <- NULL
  if (!is.null(client_name) && nzchar(client_name)) {
    client_el <- htmltools::tags$div(
      class = "header-client",
      style = "color:rgba(255,255,255,0.7);font-size:11px;margin-top:2px;",
      paste0("Prepared for ", client_name)
    )
  }

  htmltools::tags$div(
    class = "header",
    htmltools::tags$div(
      class = "header-inner",
      htmltools::tags$div(
        class = "header-left",
        style = "display:flex;align-items:center;",
        logo_el,
        htmltools::tags$div(
          htmltools::tags$div(class = "header-brand", brand_label),
          htmltools::tags$h1(class = "header-title", project_title),
          client_el,
          htmltools::tags$div(class = "header-meta",
            paste(c("Interactive Crosstab Explorer", meta_parts), collapse = " \u00B7 "))
        )
      ),
      htmltools::tags$div(
        style = "text-align:right;display:flex;flex-direction:column;align-items:flex-end;gap:4px;",
        htmltools::tags$button(
          class = "help-btn",
          onclick = "toggleHelpOverlay()",
          title = "Show help guide",
          style = paste0(
            "width:28px;height:28px;border-radius:50%;border:1.5px solid rgba(255,255,255,0.5);",
            "background:transparent;color:rgba(255,255,255,0.8);font-size:14px;font-weight:700;",
            "cursor:pointer;display:flex;align-items:center;justify-content:center;"
          ),
          "?"
        ),
        htmltools::tags$div(style = "color:rgba(255,255,255,0.4);font-size:10px",
          "Generated by Turas")
      )
    )
  )
}


#' Build Help Overlay
#'
#' Creates a modal overlay with a quick-reference guide to interactive features.
#' Shown on first visit (via localStorage) and toggled via the ? button.
#'
#' @return htmltools::tags$div
#' @keywords internal
build_help_overlay <- function() {
  htmltools::tags$div(
    class = "help-overlay",
    id = "help-overlay",
    onclick = "toggleHelpOverlay()",
    htmltools::tags$div(
      class = "help-card",
      onclick = "event.stopPropagation()",
      htmltools::tags$h2("Quick Guide"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Column headers"), "Click to sort rows by that column"),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Banner tabs"), "Switch between cross-tabulation groups"),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Column chips"), "Show/hide individual columns in the table"),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Chart toggle"), "Show or hide chart visualisations"),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Chart chips"), "Compare columns side-by-side in charts"),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\u2715 on rows"), "Hover any data row to exclude it from the chart"),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "+ Add Insight"), "Add a text note to any question"),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Save Report"), "Download HTML with your insights embedded"),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Export buttons"), "Download chart PNG, slide PNG, CSV, or Excel")
      ),
      htmltools::tags$div(class = "help-dismiss", "Click anywhere to close")
    )
  )
}


#' Build Sidebar with Question Navigator
#'
#' @param questions List of transformed question data
#' @param has_sig Logical
#' @param brand_colour Character
#' @return htmltools::div
build_sidebar <- function(questions, has_sig = FALSE, brand_colour = "#323367") {
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
build_banner_tabs <- function(banner_groups, brand_colour = "#323367") {
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
                           brand_colour = "#323367", has_charts = FALSE) {
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

  # Save Report button (saves HTML with insights embedded)
  controls <- c(controls, list(
    htmltools::tags$button(
      class = "print-btn",
      onclick = "saveReportHTML()",
      style = "margin-right:6px;",
      "\U0001F4BE Save Report"
    )
  ))

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
  # Determine initial comment to show for the first (active) banner
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

  # Embed all comments as JSON for banner switching (config-provided defaults)
  comments_json <- if (!is.null(comment_entries) && length(comment_entries) > 0) {
    as.character(jsonlite::toJSON(comment_entries, auto_unbox = TRUE))
  } else {
    NULL
  }

  # Build the per-banner JSON store from config comment entries
  # Format: { "Banner Name": "text", ... }
  store_obj <- list()
  if (!is.null(comment_entries) && length(comment_entries) > 0) {
    for (entry in comment_entries) {
      banner_key <- if (!is.null(entry$banner) && nzchar(entry$banner)) {
        entry$banner
      } else {
        first_banner  # Global comments go under the first banner
      }
      if (nzchar(banner_key) && !is.null(entry$text) && nzchar(trimws(entry$text))) {
        store_obj[[banner_key]] <- entry$text
      }
    }
  }
  store_json <- if (length(store_obj) > 0) {
    as.character(jsonlite::toJSON(store_obj, auto_unbox = TRUE))
  } else {
    ""
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
        oninput = sprintf("syncInsight('%s')", q_code),
        if (has_comment) initial_text
      ),
      htmltools::tags$button(
        class = "insight-dismiss",
        title = "Delete insight",
        onclick = sprintf("dismissInsight('%s')", q_code),
        "\u00D7"
      )
    ),
    # Hidden textarea persists per-banner insights as JSON: { "banner": "text", ... }
    htmltools::tags$textarea(
      class = "insight-store",
      `data-q-code` = q_code,
      style = "display:none;",
      store_json
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
          style = "display:flex;align-items:center;",
          htmltools::tags$span(class = "question-code", q_code),
          htmltools::tags$span(class = "question-text", style = "flex:1;", q_text),
          htmltools::tags$button(
            class = "pin-btn",
            `data-q-code` = q_code,
            onclick = sprintf("togglePin('%s')", q_code),
            title = "Pin this view",
            style = paste0(
              "background:none;border:1px solid #e2e8f0;border-radius:4px;cursor:pointer;",
              "font-size:14px;padding:3px 8px;margin-left:8px;color:#94a3b8;transition:all 0.15s;"
            ),
            "\U0001F4CC"
          )
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
          htmltools::tags$div(
            class = "slide-export-group",
            style = "display:none;position:relative;margin-left:8px;",
            htmltools::tags$button(
              class = "export-btn export-slide-btn",
              onclick = sprintf("toggleSlideMenu('%s')", q_code),
              "\U0001F4C4 Export Slide \u25BE"
            ),
            htmltools::tags$div(
              class = "slide-menu",
              id = sprintf("slide-menu-%s", gsub("[^a-zA-Z0-9]", "-", q_code)),
              style = "display:none;position:absolute;top:100%;right:0;background:#fff;border:1px solid #e2e8f0;border-radius:6px;box-shadow:0 4px 12px rgba(0,0,0,0.1);z-index:100;min-width:160px;padding:4px 0;",
              htmltools::tags$button(
                class = "slide-menu-item",
                style = "display:block;width:100%;text-align:left;padding:8px 14px;border:none;background:none;cursor:pointer;font-size:12px;font-family:inherit;",
                onclick = sprintf("exportSlidePNG('%s','chart_table')", q_code),
                "Chart + Table"
              ),
              htmltools::tags$button(
                class = "slide-menu-item",
                style = "display:block;width:100%;text-align:left;padding:8px 14px;border:none;background:none;cursor:pointer;font-size:12px;font-family:inherit;",
                onclick = sprintf("exportSlidePNG('%s','chart')", q_code),
                "Chart Only"
              ),
              htmltools::tags$button(
                class = "slide-menu-item",
                style = "display:block;width:100%;text-align:left;padding:8px 14px;border:none;background:none;cursor:pointer;font-size:12px;font-family:inherit;",
                onclick = sprintf("exportSlidePNG('%s','table')", q_code),
                "Table Only"
              )
            )
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
    build_js_pinned_views(),
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
      // Save all current insight editor text under the OLD banner before switching
      var oldBannerName = getActiveBannerName();
      document.querySelectorAll(".insight-area").forEach(function(area) {
        var editor = area.querySelector(".insight-editor");
        if (!editor) return;
        var text = editor.textContent.trim();
        var storeObj = getInsightStore(area);
        if (text) {
          storeObj[oldBannerName] = text;
        } else {
          delete storeObj[oldBannerName];
        }
        setInsightStore(area, storeObj);
      });

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

      // Reset sort and row exclusions when switching banner groups
      sortState = {};
      excludedRows = {};
      if (window._chartExclusions) window._chartExclusions = {};
      document.querySelectorAll(".ct-row-excluded").forEach(function(row) {
        row.classList.remove("ct-row-excluded");
        var btn = row.querySelector(".row-exclude-btn");
        if (btn) btn.textContent = "\\u2715";
      });
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

    // ---- HELP OVERLAY ----
    function toggleHelpOverlay() {
      var overlay = document.getElementById("help-overlay");
      if (!overlay) return;
      overlay.classList.toggle("active");
      if (!overlay.classList.contains("active")) {
        try { localStorage.setItem("turas-help-seen", "1"); } catch(e) {}
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
      document.querySelectorAll(".slide-export-group").forEach(function(grp) {
        grp.style.display = enabled ? "inline-block" : "none";
      });
    }

    // ---- Utility: extract label text from a td, ignoring button elements ----
    function getLabelText(cell) {
      var clone = cell.cloneNode(true);
      var btns = clone.querySelectorAll(".row-exclude-btn");
      btns.forEach(function(b) { b.remove(); });
      return clone.textContent.trim();
    }

    // ---- Row Exclusion from Chart ----
    var excludedRows = {};  // keyed by tableId -> Set of labels

    function toggleRowExclusion(row) {
      var table = row.closest("table.ct-table");
      if (!table) return;
      var tableId = table.id;
      if (!excludedRows[tableId]) excludedRows[tableId] = {};
      var labelCell = row.querySelector("td.ct-label-col");
      if (!labelCell) return;
      var label = getLabelText(labelCell);
      var isExcluded = row.classList.toggle("ct-row-excluded");
      if (isExcluded) {
        excludedRows[tableId][label] = true;
      } else {
        delete excludedRows[tableId][label];
      }
      // Update button icon
      var btn = row.querySelector(".row-exclude-btn");
      if (btn) btn.textContent = isExcluded ? "\\u25CB" : "\\u2715";
      // Rebuild chart with exclusions applied
      var container = table.closest(".question-container");
      if (container) {
        var wrapper = container.querySelector(".chart-wrapper[data-q-code]");
        if (wrapper) {
          var qCode = wrapper.getAttribute("data-q-code");
          rebuildChartWithExclusions(qCode, excludedRows[tableId]);
        }
      }
    }

    function rebuildChartWithExclusions(qCode, excluded) {
      if (typeof rebuildChartSVG === "function") {
        // Store exclusions so rebuildChartSVG can read them
        if (!window._chartExclusions) window._chartExclusions = {};
        window._chartExclusions[qCode] = excluded || {};
        rebuildChartSVG(qCode);
      }
    }

    // ---- Key Insight (per-banner) ----
    // Each question stores insights as JSON: { "bannerName": "text", ... }
    // in the hidden textarea.insight-store. This allows separate insights
    // per banner group on the same question.

    // Get the display name of the currently active banner group
    function getActiveBannerName() {
      var activeTab = document.querySelector(".banner-tab.active");
      if (activeTab) return activeTab.getAttribute("data-banner-name") || activeTab.textContent.trim();
      return "_default";
    }

    // Read the per-banner JSON store for a question
    function getInsightStore(area) {
      var store = area.querySelector("textarea.insight-store");
      if (!store || !store.value || !store.value.trim()) return {};
      try {
        var parsed = JSON.parse(store.value);
        // Handle legacy plain-text stores (upgrade to per-banner format)
        if (typeof parsed === "string") {
          var legacy = {};
          legacy[getActiveBannerName()] = parsed;
          return legacy;
        }
        return parsed;
      } catch(e) {
        // Legacy plain text — wrap under current banner
        if (store.value.trim()) {
          var legacy = {};
          legacy[getActiveBannerName()] = store.value.trim();
          return legacy;
        }
        return {};
      }
    }

    // Write the per-banner JSON store for a question
    function setInsightStore(area, obj) {
      var store = area.querySelector("textarea.insight-store");
      if (!store) return;
      // Remove empty entries
      var clean = {};
      for (var k in obj) {
        if (obj.hasOwnProperty(k) && obj[k] && obj[k].trim()) {
          clean[k] = obj[k].trim();
        }
      }
      store.value = Object.keys(clean).length > 0 ? JSON.stringify(clean) : "";
    }

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
        if (editor) editor.focus();
      }
    }

    function dismissInsight(qCode) {
      var area = document.querySelector(".insight-area[data-q-code=\\"" + qCode + "\\"]");
      if (!area) return;
      var container = area.querySelector(".insight-container");
      var btn = area.querySelector(".insight-toggle");
      var editor = area.querySelector(".insight-editor");
      // Clear content for current banner and hide
      if (editor) editor.innerHTML = "";
      if (container) container.style.display = "none";
      if (btn) {
        btn.style.display = "block";
        btn.textContent = "+ Add Insight";
      }
      // Remove this banner entry from the store
      syncInsight(qCode);
    }

    // Sync insight editor text into hidden store under the current banner key
    function syncInsight(qCode) {
      var area = document.querySelector(".insight-area[data-q-code=\\"" + qCode + "\\"]");
      if (!area) return;
      var editor = area.querySelector(".insight-editor");
      if (!editor) return;
      var bannerName = getActiveBannerName();
      var storeObj = getInsightStore(area);
      var text = editor.textContent.trim();
      if (text) {
        storeObj[bannerName] = text;
      } else {
        delete storeObj[bannerName];
      }
      setInsightStore(area, storeObj);
    }

    // Sync ALL insights into their hidden stores (called before save)
    function syncAllInsights() {
      document.querySelectorAll(".insight-area").forEach(function(area) {
        var editor = area.querySelector(".insight-editor");
        if (!editor) return;
        var qCode = area.getAttribute("data-q-code");
        if (qCode) syncInsight(qCode);
      });
    }

    // Save the entire HTML report (with insights embedded) as a standalone file
    function saveReportHTML() {
      syncAllInsights();

      // Before serializing, clear editor contenteditable (data lives in textarea store)
      // The hydrate function will restore editors from stores on re-open
      document.querySelectorAll(".insight-area").forEach(function(area) {
        var store = area.querySelector("textarea.insight-store");
        var editor = area.querySelector(".insight-editor");
        var container = area.querySelector(".insight-container");
        var btn = area.querySelector(".insight-toggle");
        var storeObj = getInsightStore(area);
        var hasAny = Object.keys(storeObj).length > 0;
        // Show the insight container if any banner has content
        if (hasAny) {
          var bannerName = getActiveBannerName();
          var currentText = storeObj[bannerName] || "";
          if (editor) editor.textContent = currentText;
          if (container) container.style.display = currentText ? "block" : "none";
          if (btn) btn.style.display = currentText ? "none" : "block";
        } else {
          if (editor) editor.innerHTML = "";
          if (container) container.style.display = "none";
          if (btn) { btn.style.display = "block"; btn.textContent = "+ Add Insight"; }
        }
      });

      // Clean DOM to prevent bloat on repeated save-open-save cycles
      // Remove elements that get rebuilt on DOMContentLoaded
      var removedPickers = [];
      document.querySelectorAll(".chart-col-picker").forEach(function(el) {
        removedPickers.push({ parent: el.parentNode, next: el.nextSibling, el: el });
        el.remove();
      });
      var removedIndicators = [];
      document.querySelectorAll(".ct-sort-indicator").forEach(function(el) {
        removedIndicators.push({ parent: el.parentNode, el: el });
        el.remove();
      });

      // Serialize the full page
      var html = "<!DOCTYPE html>\\n" + document.documentElement.outerHTML;
      var blob = new Blob([html], { type: "text/html;charset=utf-8" });
      var title = document.querySelector(".header-title");
      var fname = title ? title.textContent.replace(/[^a-zA-Z0-9 ]/g, "").replace(/\\s+/g, "_") : "Report";
      downloadBlob(blob, fname + "_with_insights.html");

      // Restore DOM elements for continued use
      removedPickers.forEach(function(item) {
        if (item.next) {
          item.parent.insertBefore(item.el, item.next);
        } else {
          item.parent.appendChild(item.el);
        }
      });
      removedIndicators.forEach(function(item) {
        item.parent.appendChild(item.el);
      });
    }

    // Hydrate insight editors from hidden textareas (when opening a saved HTML)
    function hydrateInsights() {
      var bannerName = getActiveBannerName();
      document.querySelectorAll(".insight-area").forEach(function(area) {
        var storeObj = getInsightStore(area);
        if (Object.keys(storeObj).length === 0) return;
        var text = storeObj[bannerName] || "";
        var editor = area.querySelector(".insight-editor");
        var container = area.querySelector(".insight-container");
        var btn = area.querySelector(".insight-toggle");
        if (text && editor) {
          editor.textContent = text;
          if (container) container.style.display = "block";
          if (btn) btn.style.display = "none";
        }
      });
    }

    // Update insight editors when banner group changes
    // Note: saving under the old banner is done in switchBannerGroup BEFORE
    // the active tab changes, so here we only need to load the new banner text.
    function updateInsightsForBanner(bannerName) {
      document.querySelectorAll(".insight-area").forEach(function(area) {
        var storeObj = getInsightStore(area);
        // Also merge in config-provided comments if store has no entry for this banner
        var scriptEl = area.querySelector("script.insight-comments-data");
        if (scriptEl && !storeObj[bannerName]) {
          try {
            var comments = JSON.parse(scriptEl.textContent);
            if (comments && comments.length) {
              for (var i = 0; i < comments.length; i++) {
                if (comments[i].banner && comments[i].banner === bannerName) {
                  storeObj[bannerName] = comments[i].text;
                  break;
                }
              }
              if (!storeObj[bannerName]) {
                for (var i = 0; i < comments.length; i++) {
                  if (!comments[i].banner) {
                    storeObj[bannerName] = comments[i].text;
                    break;
                  }
                }
              }
            }
          } catch(e) { /* ignore parse errors */ }
        }

        var text = storeObj[bannerName] || "";
        var editor = area.querySelector(".insight-editor");
        var container = area.querySelector(".insight-container");
        var btn = area.querySelector(".insight-toggle");
        if (text) {
          if (editor) editor.textContent = text;
          if (container) container.style.display = "block";
          if (btn) btn.style.display = "none";
        } else {
          if (editor) editor.innerHTML = "";
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

      // Apply row exclusions: filter out excluded labels from chart data
      var excluded = (window._chartExclusions && window._chartExclusions[qCode]) || {};
      var filteredData = data;
      if (Object.keys(excluded).length > 0) {
        // Deep-copy data to avoid mutating the original
        filteredData = JSON.parse(JSON.stringify(data));
        var keepIdx = [];
        for (var i = 0; i < filteredData.labels.length; i++) {
          if (!excluded[filteredData.labels[i]]) keepIdx.push(i);
        }
        filteredData.labels = keepIdx.map(function(i) { return data.labels[i]; });
        // Filter colours array too (used by stacked charts)
        if (filteredData.colours) {
          filteredData.colours = keepIdx.map(function(i) { return data.colours[i]; });
        }
        Object.keys(filteredData.columns).forEach(function(key) {
          filteredData.columns[key].values = keepIdx.map(function(i) {
            return data.columns[key].values[i];
          });
        });
        if (filteredData.priority_metric && filteredData.priority_metric.values) {
          var pmv = {};
          Object.keys(filteredData.priority_metric.values).forEach(function(key) {
            // Priority metric values are per-column, not per-row, so keep as-is
            pmv[key] = filteredData.priority_metric.values[key];
          });
          filteredData.priority_metric.values = pmv;
        }
      }

      var oldSvg = wrapper.querySelector("svg");
      if (!oldSvg) return;

      var svgMarkup = "";
      if (filteredData.chart_type === "stacked") {
        svgMarkup = buildMultiStackedSVG(filteredData, selectedKeys, qCode);
      } else {
        svgMarkup = buildMultiHorizontalSVG(filteredData, selectedKeys);
      }

      if (!svgMarkup) return;
      var temp = document.createElement("div");
      temp.innerHTML = svgMarkup;
      var newSvg = temp.querySelector("svg");
      if (newSvg) oldSvg.replaceWith(newSvg);

      // Re-apply table sort order to the newly built chart
      var container = wrapper.closest(".question-container");
      if (container) {
        var table = container.querySelector("table.ct-table");
        if (table && sortState[table.id] && sortState[table.id].direction !== "none") {
          var tbody = table.querySelector("tbody");
          if (tbody) {
            var sortedLabels = [];
            tbody.querySelectorAll("tr.ct-row-category:not(.ct-row-net)").forEach(function(row) {
              var labelCell = row.querySelector("td.ct-label-col");
              if (labelCell) sortedLabels.push(getLabelText(labelCell));
            });
            sortChartBars(table, sortedLabels);
          }
        }
      }
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

      // Priority metric header (centred above metric pill box)
      if (hasPM) {
        var pmHeaderX = (barW - metricW + 4) + (metricW - 14) / 2;
        p.push("<text x=\\"" + pmHeaderX + "\\" y=\\"" + 14 + "\\" text-anchor=\\"middle\\" fill=\\"#94a3b8\\" font-size=\\"9\\" font-weight=\\"600\\">" + escapeHtml(data.priority_metric.label) + "</text>");
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
      var valueW = 45;
      // Right padding: percentage text (~35px) + column name (~80px for multi-col) + gap
      var rightPad = nCols > 1 ? 130 : 50;
      var chartW = 680;
      var barAreaW = chartW - labelW - valueW - rightPad;
      if (barAreaW < 200) { chartW = labelW + valueW + rightPad + 300; barAreaW = 300; }

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

      // Distinct colour palette for columns — use chart_bar_colour for horizontal bars
      var bc = data.chart_bar_colour || data.brand_colour || "#323367";
      var colColours = nCols > 1 ? getDistinctPalette(bc, nCols) : [bc];

      var p = [];
      p.push("<svg xmlns=\\"http://www.w3.org/2000/svg\\" viewBox=\\"0 0 " + chartW + " " + totalH + "\\" role=\\"img\\" aria-label=\\"Bar chart\\" style=\\"font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;\\">");

      labels.forEach(function(label, li) {
        var groupY = groupPositions[li];
        var lines = wrappedLabels[li];

        // Wrap each category group in <g> with data attributes for sort sync
        p.push("<g class=\\"chart-bar-group\\" data-bar-label=\\"" + escapeHtml(label) + "\\" data-bar-index=\\"" + li + "\\" transform=\\"translate(0," + groupY + ")\\">");

        selectedKeys.forEach(function(key, ki) {
          var y = ki * (barH + subGap);
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

        p.push("</g>");
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
    // ---- Slide PNG Export (Enhanced) ----
    // Modes: "chart" (chart only), "table" (table only), "chart_table" (both side by side)
    // PowerPoint landscape: 1280x720 base, rendered at 3x for high-res output.

    function wrapTextLines(text, maxWidth, charWidth) {
      if (!text) return [];
      var maxChars = Math.floor(maxWidth / charWidth);
      if (text.length <= maxChars) return [text];
      var words = text.split(" ");
      var lines = [], current = "";
      for (var i = 0; i < words.length; i++) {
        var test = current ? current + " " + words[i] : words[i];
        if (test.length > maxChars && current) {
          lines.push(current);
          current = words[i];
        } else {
          current = test;
        }
      }
      if (current) lines.push(current);
      return lines;
    }

    function createWrappedText(ns, lines, x, startY, lineHeight, attrs) {
      var el = document.createElementNS(ns, "text");
      el.setAttribute("x", x);
      for (var key in attrs) { el.setAttribute(key, attrs[key]); }
      for (var i = 0; i < lines.length; i++) {
        var tspan = document.createElementNS(ns, "tspan");
        tspan.setAttribute("x", x);
        tspan.setAttribute("y", startY + i * lineHeight);
        tspan.textContent = lines[i];
        el.appendChild(tspan);
      }
      return { element: el, height: lines.length * lineHeight };
    }

    // Toggle slide export dropdown menu
    function toggleSlideMenu(qCode) {
      var menuId = "slide-menu-" + qCode.replace(/[^a-zA-Z0-9]/g, "-");
      var menu = document.getElementById(menuId);
      if (!menu) return;
      var isOpen = menu.style.display !== "none";
      // Close all slide menus first
      document.querySelectorAll(".slide-menu").forEach(function(m) { m.style.display = "none"; });
      if (!isOpen) {
        menu.style.display = "block";
        // Close on outside click
        setTimeout(function() {
          document.addEventListener("click", function closeMenu(e) {
            if (!menu.contains(e.target)) {
              menu.style.display = "none";
              document.removeEventListener("click", closeMenu);
            }
          });
        }, 10);
      }
    }

    // Extract visible table data as array of rows for SVG rendering
    function extractSlideTableData(container) {
      var table = container.querySelector("table.ct-table");
      if (!table) return null;
      var rows = [];
      var headerRow = [];
      // Header: get visible columns
      table.querySelectorAll("thead th").forEach(function(th) {
        if (th.style.display === "none" || th.offsetParent === null) return;
        var text = th.querySelector(".ct-header-text");
        headerRow.push(text ? text.textContent.trim() : th.textContent.trim().split("\\n")[0].trim());
      });
      rows.push({ cells: headerRow, type: "header" });

      // Body rows: skip excluded rows, get visible columns
      table.querySelectorAll("tbody tr").forEach(function(tr) {
        if (tr.classList.contains("ct-row-excluded")) return;
        var cells = [];
        var isBase = tr.classList.contains("ct-row-base");
        var isMean = tr.classList.contains("ct-row-mean");
        var isNet = tr.classList.contains("ct-row-net");
        tr.querySelectorAll("td").forEach(function(td) {
          if (td.style.display === "none" || td.offsetParent === null) return;
          var text = td.textContent.trim().split("\\n")[0].trim();
          // Clean up exclusion button text
          text = text.replace(/[\\u2715\\u25CB]/g, "").trim();
          cells.push(text);
        });
        if (cells.length > 0) {
          rows.push({ cells: cells, type: isBase ? "base" : (isMean ? "mean" : (isNet ? "net" : "data")) });
        }
      });
      return rows;
    }

    // Render table data into SVG elements at (x, y) with maxWidth
    function renderTableSVG(ns, svgParent, tableData, x, y, maxWidth) {
      if (!tableData || tableData.length === 0) return 0;
      var nCols = tableData[0].cells.length;
      if (nCols === 0) return 0;

      var rowH = 18, headerH = 22, fontSize = 9, padX = 6;
      // Calculate column widths: first col gets more space
      var firstColW = Math.min(Math.max(maxWidth * 0.3, 120), 200);
      var dataColW = nCols > 1 ? (maxWidth - firstColW) / (nCols - 1) : maxWidth;

      var curY = y;
      tableData.forEach(function(row, ri) {
        var isHeader = row.type === "header";
        var rH = isHeader ? headerH : rowH;

        // Row background
        var bgRect = document.createElementNS(ns, "rect");
        bgRect.setAttribute("x", x); bgRect.setAttribute("y", curY);
        bgRect.setAttribute("width", maxWidth); bgRect.setAttribute("height", rH);
        if (isHeader) {
          bgRect.setAttribute("fill", "#1a2744");
        } else if (row.type === "base") {
          bgRect.setAttribute("fill", "#fafbfc");
        } else if (row.type === "mean") {
          bgRect.setAttribute("fill", "#fef9e7");
        } else if (row.type === "net") {
          bgRect.setAttribute("fill", "#f5f0e8");
        } else if (ri % 2 === 0) {
          bgRect.setAttribute("fill", "#ffffff");
        } else {
          bgRect.setAttribute("fill", "#f9fafb");
        }
        svgParent.appendChild(bgRect);

        // Cell text
        row.cells.forEach(function(cellText, ci) {
          var cellX = ci === 0 ? x + padX : x + firstColW + (ci - 1) * dataColW + padX;
          var textEl = document.createElementNS(ns, "text");
          textEl.setAttribute("x", cellX);
          textEl.setAttribute("y", curY + rH / 2 + 1);
          textEl.setAttribute("dominant-baseline", "central");
          textEl.setAttribute("font-size", fontSize);
          textEl.setAttribute("fill", isHeader ? "#ffffff" : (ci === 0 ? "#374151" : "#1e293b"));
          if (isHeader || row.type === "net" || ci === 0) textEl.setAttribute("font-weight", "600");
          if (row.type === "mean") textEl.setAttribute("font-style", "italic");
          // Truncate long text to fit column
          var maxChars = Math.floor((ci === 0 ? firstColW : dataColW) / (fontSize * 0.55));
          textEl.textContent = cellText.length > maxChars ? cellText.substring(0, maxChars - 1) + "\\u2026" : cellText;
          svgParent.appendChild(textEl);
        });

        // Row border
        var borderLine = document.createElementNS(ns, "line");
        borderLine.setAttribute("x1", x); borderLine.setAttribute("x2", x + maxWidth);
        borderLine.setAttribute("y1", curY + rH); borderLine.setAttribute("y2", curY + rH);
        borderLine.setAttribute("stroke", "#e2e8f0"); borderLine.setAttribute("stroke-width", "0.5");
        svgParent.appendChild(borderLine);

        curY += rH;
      });

      return curY - y;
    }

    function exportSlidePNG(qCode, mode) {
      mode = mode || "chart";
      var container = document.querySelector(".question-container.active");
      if (!container) return;
      var wrapper = container.querySelector(".chart-wrapper");
      // Close the menu
      document.querySelectorAll(".slide-menu").forEach(function(m) { m.style.display = "none"; });

      var ns = "http://www.w3.org/2000/svg";
      var W = 1280, fontFamily = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
      var pad = 28;
      var usableW = W - pad * 2;

      var qTitle = wrapper ? wrapper.getAttribute("data-q-title") || "" : "";
      var qCodeLabel = wrapper ? wrapper.getAttribute("data-q-code") || qCode : qCode;

      // Gather base, banner, metrics, insight
      var baseText = "";
      var baseRow = container.querySelector("tr.ct-row-base");
      if (baseRow) {
        var baseCells = baseRow.querySelectorAll("td:not([style*=none])");
        if (baseCells.length > 1) baseText = "Base: n=" + baseCells[1].textContent.trim();
      }

      // Banner name
      var bannerLabel = "";
      var activeBannerTab = document.querySelector(".banner-tab.active");
      if (activeBannerTab) bannerLabel = activeBannerTab.textContent.trim();

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
      try {
        if (wrapper) {
          var chartDataStr = wrapper.getAttribute("data-chart-data");
          if (chartDataStr) {
            var cd = JSON.parse(chartDataStr);
            if (cd.priority_metric && cd.priority_metric.label) {
              var pmL = cd.priority_metric.label.toLowerCase();
              metrics = metrics.filter(function(m) { return m.toLowerCase().indexOf(pmL) !== 0; });
            }
          }
        }
      } catch(e) {}

      var insightText = "";
      var insightEditor = container.querySelector(".insight-editor");
      if (insightEditor) insightText = insightEditor.textContent.trim();

      // ---- Layout calculations ----
      var titleFullText = qCodeLabel + " - " + qTitle;
      var titleLines = wrapTextLines(titleFullText, usableW, 9.5);
      var titleLineH = 20;
      var titleStartY = pad + 16;
      var titleBlockH = titleLines.length * titleLineH;

      var metaText = [baseText, bannerLabel ? "Banner: " + bannerLabel : ""].filter(function(s) { return s; }).join(" \\u00B7 ");
      var metaY = titleStartY + titleBlockH + 4;
      var contentTop = metaY + 18;

      // Determine content area dimensions based on mode
      var showChart = mode === "chart" || mode === "chart_table";
      var showTable = mode === "table" || mode === "chart_table";

      var chartSvg = wrapper ? wrapper.querySelector("svg") : null;
      var tableData = showTable ? extractSlideTableData(container) : null;

      // Content layout
      var contentH = 0;
      var chartClone, chartVB, chartOrigW, chartOrigH, chartScale, chartDisplayH;
      var chartAreaW, tableAreaW, chartX, tableX;

      if (mode === "chart_table" && chartSvg && tableData) {
        // Side by side: table left, chart right
        tableAreaW = Math.floor(usableW * 0.48);
        chartAreaW = usableW - tableAreaW - 16;
        tableX = pad;
        chartX = pad + tableAreaW + 16;

        chartClone = chartSvg.cloneNode(true);
        chartVB = chartClone.getAttribute("viewBox").split(" ").map(Number);
        chartOrigW = chartVB[2]; chartOrigH = chartVB[3];
        chartScale = chartAreaW / chartOrigW;
        chartDisplayH = chartOrigH * chartScale;

        var tableH = tableData.length * 18 + 4;
        contentH = Math.max(chartDisplayH, tableH);
      } else if (showChart && chartSvg) {
        chartClone = chartSvg.cloneNode(true);
        chartVB = chartClone.getAttribute("viewBox").split(" ").map(Number);
        chartOrigW = chartVB[2]; chartOrigH = chartVB[3];
        chartScale = usableW / chartOrigW;
        chartDisplayH = chartOrigH * chartScale;
        chartX = pad;
        chartAreaW = usableW;
        contentH = chartDisplayH;
      } else if (showTable && tableData) {
        tableX = pad;
        tableAreaW = usableW;
        contentH = tableData.length * 18 + 4;
      } else {
        return;
      }

      var metricsY = contentTop + contentH + 12;
      var metricsH = metrics.length > 0 ? 28 : 0;

      var insightLines = wrapTextLines(insightText, usableW - 16, 7);
      var insightLineH = 17;
      var insightY = metricsY + metricsH + (metricsH > 0 ? 8 : 0);
      var insightBlockH = insightLines.length > 0 ? insightLines.length * insightLineH + 10 : 0;

      var totalH = insightY + insightBlockH + pad;

      // ---- Build slide SVG ----
      var svg = document.createElementNS(ns, "svg");
      svg.setAttribute("xmlns", ns);
      svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
      svg.setAttribute("style", "font-family:" + fontFamily + ";");

      var bg = document.createElementNS(ns, "rect");
      bg.setAttribute("width", W); bg.setAttribute("height", totalH);
      bg.setAttribute("fill", "#ffffff");
      svg.appendChild(bg);

      // Title
      var titleResult = createWrappedText(ns, titleLines, pad, titleStartY, titleLineH,
        { fill: "#1a2744", "font-size": "16", "font-weight": "700" });
      svg.appendChild(titleResult.element);

      // Meta (base + banner)
      var metaEl = document.createElementNS(ns, "text");
      metaEl.setAttribute("x", pad); metaEl.setAttribute("y", metaY);
      metaEl.setAttribute("fill", "#94a3b8"); metaEl.setAttribute("font-size", "11");
      metaEl.textContent = metaText;
      svg.appendChild(metaEl);

      // Table
      if (showTable && tableData) {
        renderTableSVG(ns, svg, tableData, tableX, contentTop, tableAreaW);
      }

      // Chart
      if (showChart && chartClone) {
        var chartG = document.createElementNS(ns, "g");
        chartG.setAttribute("transform", "translate(" + chartX + "," + contentTop + ") scale(" + chartScale + ")");
        while (chartClone.firstChild) chartG.appendChild(chartClone.firstChild);
        svg.appendChild(chartG);
      }

      // Metrics strip
      if (metrics.length > 0) {
        var mLine = document.createElementNS(ns, "line");
        mLine.setAttribute("x1", pad); mLine.setAttribute("x2", W - pad);
        mLine.setAttribute("y1", metricsY); mLine.setAttribute("y2", metricsY);
        mLine.setAttribute("stroke", "#e2e8f0"); mLine.setAttribute("stroke-width", "1");
        svg.appendChild(mLine);
        var mText = document.createElementNS(ns, "text");
        mText.setAttribute("x", pad); mText.setAttribute("y", metricsY + 16);
        mText.setAttribute("fill", "#5c4a2a"); mText.setAttribute("font-size", "11");
        mText.setAttribute("font-weight", "600");
        mText.textContent = metrics.join("  |  ");
        svg.appendChild(mText);
      }

      // Insight
      if (insightLines.length > 0) {
        var iLine = document.createElementNS(ns, "line");
        iLine.setAttribute("x1", pad); iLine.setAttribute("x2", W - pad);
        iLine.setAttribute("y1", insightY); iLine.setAttribute("y2", insightY);
        iLine.setAttribute("stroke", "#e2e8f0"); iLine.setAttribute("stroke-width", "1");
        svg.appendChild(iLine);
        var accentH = Math.max(24, insightLines.length * insightLineH);
        var iBar = document.createElementNS(ns, "rect");
        iBar.setAttribute("x", pad); iBar.setAttribute("y", insightY + 4);
        iBar.setAttribute("width", "3"); iBar.setAttribute("height", accentH);
        iBar.setAttribute("fill", "#323367"); iBar.setAttribute("rx", "1.5");
        svg.appendChild(iBar);
        var insResult = createWrappedText(ns, insightLines, pad + 12, insightY + 18, insightLineH,
          { fill: "#374151", "font-size": "12", "font-style": "italic" });
        svg.appendChild(insResult.element);
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
          var suffix = mode === "chart" ? "_chart" : (mode === "table" ? "_table" : "");
          downloadBlob(blob, qCode + "_slide" + suffix + ".png");
        }, "image/png");
      };
      img.src = url;
    }

    // ---- Export All Insights as Standalone HTML ----
    // Exports ALL insights across ALL banners, grouped by question
    function exportInsightsHTML() {
      // First sync current editor text into stores
      syncAllInsights();

      var insights = [];
      document.querySelectorAll(".insight-area").forEach(function(area) {
        var storeObj = getInsightStore(area);
        var bannerKeys = Object.keys(storeObj);
        if (bannerKeys.length === 0) return;
        var qCode = area.getAttribute("data-q-code") || "";
        var container = area.closest(".question-container");
        var wrapper = container ? container.querySelector(".chart-wrapper") : null;
        var qTitle = wrapper ? wrapper.getAttribute("data-q-title") : "";
        bannerKeys.forEach(function(banner) {
          if (storeObj[banner] && storeObj[banner].trim()) {
            insights.push({ code: qCode, title: qTitle, banner: banner, text: storeObj[banner].trim() });
          }
        });
      });

      if (insights.length === 0) {
        alert("No insights to export. Add insights to questions first.");
        return;
      }

      var projectTitle = document.querySelector(".header-title");
      var pTitle = projectTitle ? projectTitle.textContent : "Report";
      var now = new Date().toLocaleDateString();

      var html = "<!DOCTYPE html><html><head><meta charset=\\"UTF-8\\">";
      html += "<title>Insights - " + pTitle + "</title>";
      html += "<style>";
      html += "body{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;max-width:800px;margin:40px auto;padding:0 20px;color:#1e293b;line-height:1.6;}";
      html += "h1{font-size:20px;margin-bottom:4px;}";
      html += ".meta{color:#64748b;font-size:12px;margin-bottom:32px;}";
      html += ".insight{margin-bottom:24px;padding:16px;border-left:3px solid #323367;background:#f8f9fb;border-radius:0 6px 6px 0;}";
      html += ".q-code{font-weight:700;color:#323367;font-size:13px;}";
      html += ".q-title{font-size:13px;color:#64748b;margin-bottom:8px;}";
      html += ".banner-label{font-size:11px;color:#94a3b8;font-style:italic;margin-bottom:6px;}";
      html += ".q-text{font-size:14px;}";
      html += "@media print{body{margin:20px;}.insight{break-inside:avoid;}}";
      html += "</style></head><body>";
      html += "<h1>Key Insights</h1>";
      html += "<div class=\\"meta\\">" + pTitle + " &middot; " + now + " &middot; " + insights.length + " insight" + (insights.length > 1 ? "s" : "") + "</div>";

      insights.forEach(function(item) {
        html += "<div class=\\"insight\\">";
        html += "<div class=\\"q-code\\">" + item.code + "</div>";
        html += "<div class=\\"q-title\\">" + item.title + "</div>";
        html += "<div class=\\"banner-label\\">Banner: " + item.banner + "</div>";
        html += "<div class=\\"q-text\\">" + item.text + "</div>";
        html += "</div>";
      });

      html += "</body></html>";

      var blob = new Blob([html], { type: "text/html;charset=utf-8" });
      downloadBlob(blob, "Insights_" + pTitle.replace(/[^a-zA-Z0-9]/g, "_") + ".html");
    }

  '
}


#' Build Pinned Views JavaScript
#'
#' Pin/unpin questions, render pinned view cards, reorder, persist to JSON,
#' export all pinned views as individual slide PNGs.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_pinned_views <- function() {
  '
    // ---- Pinned Views ----
    var pinnedViews = [];

    function updatePinBadge() {
      var badge = document.getElementById("pin-count-badge");
      if (badge) {
        badge.textContent = pinnedViews.length;
        badge.style.display = pinnedViews.length > 0 ? "inline" : "none";
      }
      var empty = document.getElementById("pinned-empty-state");
      var cards = document.getElementById("pinned-cards-container");
      if (empty) empty.style.display = pinnedViews.length === 0 ? "block" : "none";
      if (cards) cards.style.display = pinnedViews.length > 0 ? "block" : "none";
    }

    function savePinnedData() {
      var store = document.getElementById("pinned-views-data");
      if (store) store.textContent = JSON.stringify(pinnedViews);
    }

    function togglePin(qCode) {
      var idx = pinnedViews.findIndex(function(p) { return p.qCode === qCode && p.bannerGroup === currentGroup; });
      if (idx >= 0) {
        pinnedViews.splice(idx, 1);
        updatePinButton(qCode, false);
      } else {
        var pin = captureCurrentView(qCode);
        if (pin) {
          pinnedViews.push(pin);
          updatePinButton(qCode, true);
        }
      }
      savePinnedData();
      renderPinnedCards();
      updatePinBadge();
    }

    function updatePinButton(qCode, isPinned) {
      document.querySelectorAll(".pin-btn[data-q-code=\\"" + qCode + "\\"]").forEach(function(btn) {
        btn.style.color = isPinned ? "#323367" : "#94a3b8";
        btn.style.borderColor = isPinned ? "#323367" : "#e2e8f0";
        btn.title = isPinned ? "Unpin this view" : "Pin this view";
      });
    }

    function captureCurrentView(qCode) {
      var container = document.querySelector(".question-container .chart-wrapper[data-q-code=\\"" + qCode + "\\"]");
      if (!container) container = document.querySelector(".chart-wrapper[data-q-code=\\"" + qCode + "\\"]");
      var qContainer = container ? container.closest(".question-container") : null;
      if (!qContainer) return null;

      var wrapper = qContainer.querySelector(".chart-wrapper");
      var qTitle = wrapper ? wrapper.getAttribute("data-q-title") || "" : "";
      var chartDataStr = wrapper ? wrapper.getAttribute("data-chart-data") : null;

      // Capture selected chart columns
      var selectedCols = [];
      if (chartColumnState[qCode]) {
        selectedCols = Object.keys(chartColumnState[qCode]).filter(function(k) {
          return chartColumnState[qCode][k];
        });
      }

      // Capture excluded rows
      var excludedRows = [];
      if (window._chartExclusions && window._chartExclusions[qCode]) {
        excludedRows = Object.keys(window._chartExclusions[qCode]);
      }

      // Capture insight text
      var insightText = "";
      var editor = qContainer.querySelector(".insight-editor");
      if (editor) insightText = editor.textContent.trim();

      // Capture table sort state
      var table = qContainer.querySelector("table.ct-table");
      var tableSortState = null;
      if (table && sortState[table.id] && sortState[table.id].direction !== "none") {
        tableSortState = { colKey: sortState[table.id].colKey, direction: sortState[table.id].direction };
      }

      // Capture visible table HTML (clone, remove hidden cols and excluded rows)
      var tableClone = table ? table.cloneNode(true) : null;
      if (tableClone) {
        // Remove hidden columns
        tableClone.querySelectorAll("[style*=\\"display: none\\"], [style*=\\"display:none\\"]").forEach(function(el) { el.remove(); });
        // Remove excluded rows
        tableClone.querySelectorAll(".ct-row-excluded").forEach(function(el) { el.remove(); });
        // Remove sort indicators and exclude buttons
        tableClone.querySelectorAll(".ct-sort-indicator, .row-exclude-btn").forEach(function(el) { el.remove(); });
      }

      // Capture chart SVG
      var chartSvg = wrapper ? wrapper.querySelector("svg") : null;
      var chartSvgStr = chartSvg ? new XMLSerializer().serializeToString(chartSvg) : "";

      // Get active banner label
      var bannerLabel = "";
      var activeBannerTab = document.querySelector(".banner-tab.active");
      if (activeBannerTab) bannerLabel = activeBannerTab.textContent.trim();

      // Get base text
      var baseText = "";
      var baseRow = qContainer.querySelector("tr.ct-row-base");
      if (baseRow) {
        var baseCells = baseRow.querySelectorAll("td:not([style*=none])");
        if (baseCells.length > 1) baseText = "n=" + baseCells[1].textContent.trim();
      }

      return {
        id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
        qCode: qCode,
        qTitle: qTitle,
        bannerGroup: currentGroup,
        bannerLabel: bannerLabel,
        selectedColumns: selectedCols,
        excludedRows: excludedRows,
        insightText: insightText,
        sortState: tableSortState,
        tableHtml: tableClone ? tableClone.outerHTML : "",
        chartSvg: chartSvgStr,
        baseText: baseText,
        timestamp: Date.now(),
        order: pinnedViews.length
      };
    }

    function renderPinnedCards() {
      var container = document.getElementById("pinned-cards-container");
      if (!container) return;
      container.innerHTML = "";

      pinnedViews.forEach(function(pin, idx) {
        var card = document.createElement("div");
        card.className = "pinned-card";
        card.setAttribute("data-pin-id", pin.id);
        card.style.cssText = "background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:20px;margin-bottom:16px;";

        // Header with title, banner, base, controls
        var header = document.createElement("div");
        header.style.cssText = "display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:12px;";
        var titleDiv = document.createElement("div");
        titleDiv.innerHTML = "<div style=\\"font-size:11px;color:#323367;font-weight:700;\\">" + escapeHtml(pin.qCode) + "</div>" +
          "<div style=\\"font-size:14px;font-weight:600;color:#1e293b;\\">" + escapeHtml(pin.qTitle) + "</div>" +
          "<div style=\\"font-size:11px;color:#94a3b8;margin-top:2px;\\">Banner: " + escapeHtml(pin.bannerLabel) +
          (pin.baseText ? " \\u00B7 Base: " + escapeHtml(pin.baseText) : "") + "</div>";
        header.appendChild(titleDiv);

        var controls = document.createElement("div");
        controls.style.cssText = "display:flex;gap:4px;flex-shrink:0;";
        if (idx > 0) {
          var upBtn = document.createElement("button");
          upBtn.className = "export-btn";
          upBtn.style.cssText = "padding:3px 8px;font-size:11px;";
          upBtn.textContent = "\\u25B2";
          upBtn.title = "Move up";
          upBtn.onclick = function() { movePinned(idx, idx - 1); };
          controls.appendChild(upBtn);
        }
        if (idx < pinnedViews.length - 1) {
          var downBtn = document.createElement("button");
          downBtn.className = "export-btn";
          downBtn.style.cssText = "padding:3px 8px;font-size:11px;";
          downBtn.textContent = "\\u25BC";
          downBtn.title = "Move down";
          downBtn.onclick = function() { movePinned(idx, idx + 1); };
          controls.appendChild(downBtn);
        }
        var removeBtn = document.createElement("button");
        removeBtn.className = "export-btn";
        removeBtn.style.cssText = "padding:3px 8px;font-size:11px;color:#e8614d;";
        removeBtn.textContent = "\\u2715";
        removeBtn.title = "Remove pin";
        removeBtn.onclick = function() { removePinned(pin.id, pin.qCode); };
        controls.appendChild(removeBtn);
        header.appendChild(controls);
        card.appendChild(header);

        // Content: table and chart side by side
        var content = document.createElement("div");
        content.style.cssText = "display:flex;gap:16px;align-items:flex-start;";

        if (pin.tableHtml) {
          var tableDiv = document.createElement("div");
          tableDiv.style.cssText = "flex:1;overflow-x:auto;font-size:11px;";
          tableDiv.innerHTML = pin.tableHtml;
          // Scale down table for compact display
          var tbl = tableDiv.querySelector("table");
          if (tbl) tbl.style.cssText = "font-size:10px;width:100%;";
          content.appendChild(tableDiv);
        }

        if (pin.chartSvg) {
          var chartDiv = document.createElement("div");
          chartDiv.style.cssText = "flex:1;";
          chartDiv.innerHTML = pin.chartSvg;
          content.appendChild(chartDiv);
        }
        card.appendChild(content);

        // Insight
        if (pin.insightText) {
          var insightDiv = document.createElement("div");
          insightDiv.style.cssText = "margin-top:12px;padding:10px 14px;border-left:3px solid #323367;background:#f8f9fb;border-radius:0 6px 6px 0;font-size:12px;color:#374151;font-style:italic;";
          insightDiv.textContent = pin.insightText;
          card.appendChild(insightDiv);
        }

        container.appendChild(card);
      });
    }

    function movePinned(fromIdx, toIdx) {
      if (toIdx < 0 || toIdx >= pinnedViews.length) return;
      var item = pinnedViews.splice(fromIdx, 1)[0];
      pinnedViews.splice(toIdx, 0, item);
      savePinnedData();
      renderPinnedCards();
    }

    function removePinned(pinId, qCode) {
      pinnedViews = pinnedViews.filter(function(p) { return p.id !== pinId; });
      updatePinButton(qCode, pinnedViews.some(function(p) { return p.qCode === qCode; }));
      savePinnedData();
      renderPinnedCards();
      updatePinBadge();
    }

    function hydratePinnedViews() {
      var store = document.getElementById("pinned-views-data");
      if (!store) return;
      try {
        var data = JSON.parse(store.textContent);
        if (Array.isArray(data) && data.length > 0) {
          pinnedViews = data;
          renderPinnedCards();
          updatePinBadge();
          // Update pin buttons
          pinnedViews.forEach(function(pin) {
            updatePinButton(pin.qCode, true);
          });
        }
      } catch(e) {}
    }

    function exportAllPinnedSlides() {
      if (pinnedViews.length === 0) {
        alert("No pinned views to export.");
        return;
      }
      var ns = "http://www.w3.org/2000/svg";
      var W = 1280, fontFamily = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
      var pad = 28;

      pinnedViews.forEach(function(pin, idx) {
        var usableW = W - pad * 2;
        var titleFullText = pin.qCode + " - " + pin.qTitle;
        var titleLines = wrapTextLines(titleFullText, usableW, 9.5);
        var titleLineH = 20;
        var titleStartY = pad + 16;
        var titleBlockH = titleLines.length * titleLineH;
        var metaText = "Base: " + (pin.baseText || "—") + " \\u00B7 Banner: " + (pin.bannerLabel || "");
        var metaY = titleStartY + titleBlockH + 4;
        var contentTop = metaY + 18;

        // Parse chart SVG to get dimensions
        var chartH = 0, hasChart = false;
        var chartTemp = null;
        if (pin.chartSvg) {
          var tempDiv = document.createElement("div");
          tempDiv.innerHTML = pin.chartSvg;
          chartTemp = tempDiv.querySelector("svg");
          if (chartTemp) {
            hasChart = true;
            var vb = chartTemp.getAttribute("viewBox");
            if (vb) {
              var parts = vb.split(" ").map(Number);
              var cScale = (usableW * 0.5) / parts[2];
              chartH = parts[3] * cScale;
            }
          }
        }

        // Approximate table height
        var tableH = 0;
        if (pin.tableHtml) {
          var countRows = (pin.tableHtml.match(/<tr/g) || []).length;
          tableH = countRows * 18 + 4;
        }

        var contentH = Math.max(chartH, tableH, 100);

        // Insight
        var insightLines = wrapTextLines(pin.insightText, usableW - 16, 7);
        var insightLineH = 17;
        var insightY = contentTop + contentH + 16;
        var insightBlockH = insightLines.length > 0 ? insightLines.length * insightLineH + 10 : 0;
        var totalH = insightY + insightBlockH + pad;

        var svg = document.createElementNS(ns, "svg");
        svg.setAttribute("xmlns", ns);
        svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
        svg.setAttribute("style", "font-family:" + fontFamily + ";");

        var bg = document.createElementNS(ns, "rect");
        bg.setAttribute("width", W); bg.setAttribute("height", totalH);
        bg.setAttribute("fill", "#ffffff");
        svg.appendChild(bg);

        var titleResult = createWrappedText(ns, titleLines, pad, titleStartY, titleLineH,
          { fill: "#1a2744", "font-size": "16", "font-weight": "700" });
        svg.appendChild(titleResult.element);

        var metaEl = document.createElementNS(ns, "text");
        metaEl.setAttribute("x", pad); metaEl.setAttribute("y", metaY);
        metaEl.setAttribute("fill", "#94a3b8"); metaEl.setAttribute("font-size", "11");
        metaEl.textContent = metaText;
        svg.appendChild(metaEl);

        // Render table from stored HTML
        if (pin.tableHtml) {
          var tDiv = document.createElement("div");
          tDiv.innerHTML = pin.tableHtml;
          var tRows = extractSlideTableData({ querySelector: function(sel) { return tDiv.querySelector(sel); }, querySelectorAll: function(sel) { return tDiv.querySelectorAll(sel); } });
          if (tRows) {
            var tableW = hasChart ? usableW * 0.48 : usableW;
            renderTableSVG(ns, svg, tRows, pad, contentTop, tableW);
          }
        }

        // Embed chart
        if (hasChart && chartTemp) {
          var chartClone = chartTemp.cloneNode(true);
          var cvb = chartClone.getAttribute("viewBox").split(" ").map(Number);
          var chartAreaW = pin.tableHtml ? usableW * 0.5 : usableW;
          var chartX = pin.tableHtml ? pad + usableW * 0.5 + 8 : pad;
          var cScale2 = chartAreaW / cvb[2];
          var cG = document.createElementNS(ns, "g");
          cG.setAttribute("transform", "translate(" + chartX + "," + contentTop + ") scale(" + cScale2 + ")");
          while (chartClone.firstChild) cG.appendChild(chartClone.firstChild);
          svg.appendChild(cG);
        }

        // Insight
        if (insightLines.length > 0) {
          var iL = document.createElementNS(ns, "line");
          iL.setAttribute("x1", pad); iL.setAttribute("x2", W - pad);
          iL.setAttribute("y1", insightY); iL.setAttribute("y2", insightY);
          iL.setAttribute("stroke", "#e2e8f0"); iL.setAttribute("stroke-width", "1");
          svg.appendChild(iL);
          var aH = Math.max(24, insightLines.length * insightLineH);
          var iB = document.createElementNS(ns, "rect");
          iB.setAttribute("x", pad); iB.setAttribute("y", insightY + 4);
          iB.setAttribute("width", "3"); iB.setAttribute("height", aH);
          iB.setAttribute("fill", "#323367"); iB.setAttribute("rx", "1.5");
          svg.appendChild(iB);
          var insRes = createWrappedText(ns, insightLines, pad + 12, insightY + 18, insightLineH,
            { fill: "#374151", "font-size": "12", "font-style": "italic" });
          svg.appendChild(insRes.element);
        }

        // Render to PNG with delay between downloads
        var scale = 3;
        var svgData = new XMLSerializer().serializeToString(svg);
        var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
        var url = URL.createObjectURL(svgBlob);
        var slideNum = String(idx + 1).padStart(2, "0");

        (function(slideUrl, sNum, qc) {
          var sImg = new Image();
          sImg.onload = function() {
            var canvas = document.createElement("canvas");
            canvas.width = W * scale; canvas.height = totalH * scale;
            var ctx = canvas.getContext("2d");
            ctx.fillStyle = "#ffffff";
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.drawImage(sImg, 0, 0, canvas.width, canvas.height);
            URL.revokeObjectURL(slideUrl);
            canvas.toBlob(function(blob) {
              downloadBlob(blob, "pin_" + sNum + "_" + qc + "_slide.png");
            }, "image/png");
          };
          sImg.src = slideUrl;
        })(url, slideNum, pin.qCode);
      });
    }

    // ---- Print Pinned Views to PDF ----
    // Builds a temporary print layout with one pinned view per page,
    // triggers window.print() (user can save to PDF), then restores DOM.
    function printPinnedViews() {
      if (pinnedViews.length === 0) {
        alert("No pinned views to print. Pin questions from the Crosstabs tab first.");
        return;
      }

      // Create a print overlay container
      var overlay = document.createElement("div");
      overlay.id = "pinned-print-overlay";
      overlay.style.cssText = "position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:white;overflow:auto;";

      // Add print-specific styles
      var printStyle = document.createElement("style");
      printStyle.id = "pinned-print-style";
      printStyle.textContent = "@media print { " +
        "body > *:not(#pinned-print-overlay) { display: none !important; } " +
        "#pinned-print-overlay { position: static !important; overflow: visible !important; } " +
        ".pinned-print-page { page-break-after: always; padding: 20px 32px; box-sizing: border-box; } " +
        ".pinned-print-page:last-child { page-break-after: auto; } " +
        ".pinned-print-header { margin-bottom: 16px; } " +
        ".pinned-print-qcode { font-size: 12px; font-weight: 700; color: #323367; } " +
        ".pinned-print-title { font-size: 16px; font-weight: 600; color: #1e293b; margin: 2px 0; } " +
        ".pinned-print-meta { font-size: 11px; color: #64748b; } " +
        ".pinned-print-content { display: flex; gap: 20px; align-items: flex-start; margin-top: 12px; } " +
        ".pinned-print-table { flex: 1; overflow: visible; font-size: 11px; } " +
        ".pinned-print-table table { width: 100%; border-collapse: collapse; font-size: 10px; } " +
        ".pinned-print-table th, .pinned-print-table td { padding: 3px 6px; border: 1px solid #ddd; text-align: left; } " +
        ".pinned-print-table th { background: #f1f5f9; font-weight: 600; font-size: 9px; } " +
        ".pinned-print-chart { flex: 1; } " +
        ".pinned-print-chart svg { width: 100%; height: auto; } " +
        ".pinned-print-insight { margin-top: 12px; padding: 10px 14px; border-left: 3px solid #323367; " +
        "  background: #f8f9fb; border-radius: 0 6px 6px 0; font-size: 12px; color: #374151; font-style: italic; } " +
        ".pinned-print-page-num { text-align: right; font-size: 9px; color: #94a3b8; margin-top: 8px; } " +
        "} " +
        "@media screen { " +
        "#pinned-print-overlay .pinned-print-page { " +
        "  max-width: 900px; margin: 20px auto; padding: 32px; " +
        "  border: 1px solid #e2e8f0; border-radius: 8px; background: #fff; " +
        "  box-shadow: 0 1px 3px rgba(0,0,0,0.1); } " +
        ".pinned-print-content { display: flex; gap: 20px; } " +
        ".pinned-print-table { flex: 1; overflow-x: auto; } " +
        ".pinned-print-table table { font-size: 10px; width: 100%; border-collapse: collapse; } " +
        ".pinned-print-table th, .pinned-print-table td { padding: 3px 6px; border: 1px solid #ddd; } " +
        ".pinned-print-table th { background: #f1f5f9; font-weight: 600; font-size: 9px; } " +
        ".pinned-print-chart { flex: 1; } " +
        ".pinned-print-chart svg { width: 100%; height: auto; } " +
        ".pinned-print-insight { margin-top: 12px; padding: 10px 14px; border-left: 3px solid #323367; " +
        "  background: #f8f9fb; font-size: 12px; color: #374151; font-style: italic; } " +
        "}";
      document.head.appendChild(printStyle);

      // Get project title for header
      var projectTitle = document.querySelector(".header-title");
      var pTitle = projectTitle ? projectTitle.textContent : "Report";

      // Build one page per pinned view
      pinnedViews.forEach(function(pin, idx) {
        var page = document.createElement("div");
        page.className = "pinned-print-page";

        // Header
        var hdr = document.createElement("div");
        hdr.className = "pinned-print-header";
        hdr.innerHTML = "<div class=\\"pinned-print-qcode\\">" + escapeHtml(pin.qCode) + "</div>" +
          "<div class=\\"pinned-print-title\\">" + escapeHtml(pin.qTitle) + "</div>" +
          "<div class=\\"pinned-print-meta\\">Banner: " + escapeHtml(pin.bannerLabel) +
          (pin.baseText ? " \\u00B7 Base: " + escapeHtml(pin.baseText) : "") +
          " \\u00B7 " + escapeHtml(pTitle) + "</div>";
        page.appendChild(hdr);

        // Content: table + chart
        var content = document.createElement("div");
        content.className = "pinned-print-content";

        if (pin.tableHtml) {
          var tableDiv = document.createElement("div");
          tableDiv.className = "pinned-print-table";
          tableDiv.innerHTML = pin.tableHtml;
          content.appendChild(tableDiv);
        }

        if (pin.chartSvg) {
          var chartDiv = document.createElement("div");
          chartDiv.className = "pinned-print-chart";
          chartDiv.innerHTML = pin.chartSvg;
          content.appendChild(chartDiv);
        }
        page.appendChild(content);

        // Insight
        if (pin.insightText) {
          var insDiv = document.createElement("div");
          insDiv.className = "pinned-print-insight";
          insDiv.textContent = pin.insightText;
          page.appendChild(insDiv);
        }

        // Page number
        var pgNum = document.createElement("div");
        pgNum.className = "pinned-print-page-num";
        pgNum.textContent = (idx + 1) + " of " + pinnedViews.length;
        page.appendChild(pgNum);

        overlay.appendChild(page);
      });

      document.body.appendChild(overlay);

      // Clean up function
      function cleanupPrintOverlay() {
        var ov = document.getElementById("pinned-print-overlay");
        if (ov) ov.remove();
        var ps = document.getElementById("pinned-print-style");
        if (ps) ps.remove();
      }

      // Listen for afterprint event (reliable in modern browsers)
      var cleaned = false;
      function onAfterPrint() {
        if (cleaned) return;
        cleaned = true;
        window.removeEventListener("afterprint", onAfterPrint);
        cleanupPrintOverlay();
      }
      window.addEventListener("afterprint", onAfterPrint);

      // Small delay to let browser render, then print
      setTimeout(function() {
        window.print();
        // Fallback cleanup if afterprint does not fire (some browsers)
        setTimeout(function() {
          if (!cleaned) {
            cleaned = true;
            cleanupPrintOverlay();
          }
        }, 2000);
      }, 300);
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
        // Skip if already initialized (e.g., from saved HTML re-open)
        if (th.querySelector(".ct-sort-indicator")) return;

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
        return labelCell ? getLabelText(labelCell) : "";
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
      // Hydrate insights from hidden textareas (for saved HTML re-open)
      hydrateInsights();
      // Hydrate pinned views from hidden JSON store
      hydratePinnedViews();
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
      // Show help overlay on first visit
      try {
        if (!localStorage.getItem("turas-help-seen")) {
          toggleHelpOverlay();
        }
      } catch(e) {}
    });
  '
}


