# ==============================================================================
# HTML REPORT - PAGE BUILDER (V10.3.2)
# ==============================================================================
# Assembles the complete HTML page structure: header, sidebar, controls,
# table containers, footer, CSS, and JavaScript.
# Uses plain HTML tables — no reactable, no htmlwidgets.
# ==============================================================================

# File-level helper: escape strings for safe insertion into JS single-quoted literals
js_esc <- function(s) gsub("'", "\\\\'", gsub("\\\\", "\\\\\\\\", as.character(s)))


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
                            dashboard_html = NULL, charts = list(),
                            source_filename = NULL,
                            qualitative_slides = NULL) {

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    return(list(
      status = "REFUSED",
      code = "PKG_MISSING_JSONLITE",
      message = "Required package 'jsonlite' is not installed",
      how_to_fix = "Install it with: install.packages('jsonlite')"
    ))
  }

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

  # Build source-filename meta tag (used by saveReportHTML for _Updated.html naming)
  source_meta <- if (!is.null(source_filename) && nzchar(source_filename)) {
    htmltools::tags$meta(name = "turas-source-filename", content = source_filename)
  }

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
              onclick = "addSection()",
              "\u2795 Add Section"
            ),
            htmltools::tags$button(
              class = "export-btn",
              onclick = "exportAllPinnedSlides()",
              "\U0001F4E4 Export All Slides"
            ),
            htmltools::tags$button(
              class = "export-btn",
              onclick = "printPinnedViews()",
              "\U0001F5A8 Print / Save PDF"
            ),
            htmltools::tags$button(
              class = "export-btn",
              onclick = "saveReportHTML()",
              "\U0001F4BE Save Report"
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

    # Hub-extraction metadata
    hub_meta <- htmltools::tagList(
      htmltools::tags$meta(name = "turas-report-type", content = "tabs"),
      htmltools::tags$meta(name = "turas-total-n",
                           content = if (!is.na(html_data$total_n)) as.character(round(html_data$total_n)) else ""),
      htmltools::tags$meta(name = "turas-questions", content = as.character(html_data$n_questions)),
      htmltools::tags$meta(name = "turas-banner-groups",
                           content = as.character(length(html_data$banner_groups))),
      htmltools::tags$meta(name = "turas-weighted",
                           content = if (isTRUE(config_obj$apply_weighting)) "true" else "false"),
      htmltools::tags$meta(name = "turas-fieldwork",
                           content = config_obj$fieldwork_dates %||% "")
    )

    page <- htmltools::tagList(
      htmltools::tags$head(
        htmltools::tags$meta(charset = "UTF-8"),
        htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
        source_meta,
        hub_meta,
        htmltools::tags$title(project_title),
        build_css(brand_colour, accent_colour),
        build_dashboard_css(brand_colour),
        build_print_css()
      ),
      build_header(project_title, brand_colour, html_data$total_n, html_data$n_questions,
                         company_name = config_obj$company_name %||% "The Research Lamppost",
                         client_name = config_obj$client_name,
                         researcher_logo_uri = config_obj$researcher_logo_uri,
                         apply_weighting = isTRUE(config_obj$apply_weighting)),
      build_report_tab_nav(brand_colour, has_qualitative = TRUE,
                           has_about = any(nzchar(c(
                             config_obj$analyst_name, config_obj$analyst_email,
                             config_obj$analyst_phone, config_obj$verbatim_filename,
                             config_obj$closing_notes)))),
      dashboard_html,
      crosstab_panel,
      build_qualitative_panel(qualitative_slides, brand_colour),
      build_about_panel(config_obj),
      pinned_panel,
      build_help_overlay(),
      build_javascript(html_data, brand_colour),
      build_tab_javascript()
    )
  } else {
    # No dashboard: original layout unchanged

    # Hub-extraction metadata
    hub_meta <- htmltools::tagList(
      htmltools::tags$meta(name = "turas-report-type", content = "tabs"),
      htmltools::tags$meta(name = "turas-total-n",
                           content = if (!is.na(html_data$total_n)) as.character(round(html_data$total_n)) else ""),
      htmltools::tags$meta(name = "turas-questions", content = as.character(html_data$n_questions)),
      htmltools::tags$meta(name = "turas-banner-groups",
                           content = as.character(length(html_data$banner_groups))),
      htmltools::tags$meta(name = "turas-weighted",
                           content = if (isTRUE(config_obj$apply_weighting)) "true" else "false"),
      htmltools::tags$meta(name = "turas-fieldwork",
                           content = config_obj$fieldwork_dates %||% "")
    )

    page <- htmltools::tagList(
      htmltools::tags$head(
        htmltools::tags$meta(charset = "UTF-8"),
        htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
        source_meta,
        hub_meta,
        htmltools::tags$title(project_title),
        build_css(brand_colour, accent_colour),
        build_print_css()
      ),
      build_header(project_title, brand_colour, html_data$total_n, html_data$n_questions,
                         company_name = config_obj$company_name %||% "The Research Lamppost",
                         client_name = config_obj$client_name,
                         researcher_logo_uri = config_obj$researcher_logo_uri,
                         apply_weighting = isTRUE(config_obj$apply_weighting)),
      crosstab_content,
      build_closing_section(config_obj),
      build_help_overlay(),
      build_javascript(html_data, brand_colour)
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

      /* === TABS === */
      .tab-panel { display: block !important; }
      #tab-summary { display: none !important; }
      #tab-pinned { display: none !important; }

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


#' Build Report Tab Navigation (Summary / Crosstabs)
#'
#' @param brand_colour Character hex colour
#' @return htmltools::tags$div
#' @keywords internal
build_report_tab_nav <- function(brand_colour, has_qualitative = FALSE, has_about = FALSE) {
  qual_tab <- if (has_qualitative) {
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('qualitative')",
      `data-tab` = "qualitative",
      "\U0001F4DD Added Slides"
    )
  }

  about_tab <- if (has_about) {
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('about')",
      `data-tab` = "about",
      "\u2139\uFE0F About"
    )
  }

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
    qual_tab,
    about_tab,
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('pinned')",
      `data-tab` = "pinned",
      "\U0001F4CC Pinned Views",
      htmltools::tags$span(class = "pin-count-badge", id = "pin-count-badge", style = paste0("display:none;margin-left:4px;background:", brand_colour, ";color:#fff;font-size:10px;padding:1px 6px;border-radius:8px;"), "0")
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

      // When switching to crosstabs, rebuild column chips & chart pickers
      // (they may have been built while the panel was hidden)
      if (tabName === "crosstabs") {
        window.dispatchEvent(new Event("resize"));
        if (typeof buildColumnChips === "function") buildColumnChips(currentGroup);
        if (typeof buildChartPickersForGroup === "function") buildChartPickersForGroup(currentGroup);
      }
    }
  '
  htmltools::tags$script(htmltools::HTML(js))
}


#' Build Header
#'
#' Constructs the banner at the top of the HTML report. Layout:
#' - Top row: [researcher logo] "Turas Tabs" / subtitle ... [? help button]
#' - Study name (large, bold)
#' - Prepared by / for line
#' - Stats badge bar (n, questions, weighted/unweighted, updated date)
#'
#' @param project_title Character - study name from config
#' @param brand_colour Character - hex colour for accent border
#' @param total_n Numeric or NA - total sample size
#' @param n_questions Integer - number of questions
#' @param company_name Character - researcher / company name
#' @param client_name Character or NULL - client organisation
#' @param researcher_logo_uri Character or NULL - base64 data URI for logo
#' @param apply_weighting Logical - whether weighting was applied
#' @return htmltools::div
build_header <- function(project_title, brand_colour, total_n, n_questions,
                         company_name = "The Research Lamppost",
                         client_name = NULL,
                         researcher_logo_uri = NULL,
                         apply_weighting = FALSE) {

  # Researcher logo element (left of "Turas Tabs")
  logo_container_style <- paste0(
    "width:72px;height:72px;border-radius:12px;",
    "background:transparent;",
    "display:flex;align-items:center;justify-content:center;",
    "flex-shrink:0;"
  )
  logo_img_style <- paste0(
    "height:56px;width:56px;object-fit:contain;"
  )
  researcher_logo_el <- NULL
  if (!is.null(researcher_logo_uri) && nzchar(researcher_logo_uri)) {
    researcher_logo_el <- htmltools::tags$div(
      style = logo_container_style,
      htmltools::tags$img(
        src = researcher_logo_uri,
        alt = company_name,
        class = "header-logo",
        style = logo_img_style
      )
    )
  }

  # --- Top row: [logo] Turas Tabs / subtitle  ...  [?] ---
  branding_left <- htmltools::tags$div(
    style = "display:flex;align-items:center;gap:16px;",
    researcher_logo_el,
    htmltools::tags$div(
      htmltools::tags$div(
        style = "color:rgba(255,255,255,0.7);font-size:13px;font-weight:600;line-height:1.2;letter-spacing:0.5px;text-transform:uppercase;",
        "Turas Tabs"
      ),
      htmltools::tags$div(
        style = "color:rgba(255,255,255,0.40);font-size:11px;font-weight:400;margin-top:2px;",
        "Interactive Crosstab Explorer"
      )
    )
  )

  help_btn <- htmltools::tags$button(
    class = "help-btn",
    onclick = "toggleHelpOverlay()",
    title = "Show help guide",
    style = paste0(
      "width:28px;height:28px;border-radius:50%;border:1.5px solid rgba(255,255,255,0.5);",
      "background:transparent;color:rgba(255,255,255,0.8);font-size:14px;font-weight:700;",
      "cursor:pointer;display:flex;align-items:center;justify-content:center;"
    ),
    "?"
  )

  top_row <- htmltools::tags$div(
    style = "display:flex;align-items:center;justify-content:space-between;",
    branding_left,
    help_btn
  )

  # --- Study name ---
  study_row <- htmltools::tags$div(
    class = "header-title",
    style = "color:#ffffff;font-size:26px;font-weight:700;letter-spacing:-0.3px;margin-top:14px;line-height:1.2;",
    project_title
  )

  # --- Prepared by / for ---
  prepared_parts <- c()
  if (!is.null(company_name) && nzchar(company_name)) {
    prepared_parts <- c(prepared_parts, paste0(
      "Prepared by <span style=\"font-weight:600;\">",
      htmltools::htmlEscape(company_name), "</span>"
    ))
  }
  if (!is.null(client_name) && nzchar(client_name)) {
    prepared_parts <- c(prepared_parts, paste0(
      "for <span style=\"font-weight:600;\">",
      htmltools::htmlEscape(client_name), "</span>"
    ))
  }

  prepared_row <- NULL
  if (length(prepared_parts) > 0) {
    prepared_row <- htmltools::tags$div(
      style = "color:rgba(255,255,255,0.65);font-size:13px;font-weight:400;margin-top:4px;line-height:1.3;",
      htmltools::HTML(paste(prepared_parts, collapse = " "))
    )
  }

  # --- Stats badge bar ---
  badge_style <- paste0(
    "display:inline-flex;align-items:center;padding:5px 14px;",
    "font-size:12px;font-weight:600;color:rgba(255,255,255,0.85);",
    "font-variant-numeric:tabular-nums;"
  )
  separator_style <- paste0(
    "width:1px;height:16px;background:rgba(255,255,255,0.20);flex-shrink:0;"
  )

  badge_items <- list()

  # n badge

  if (!is.na(total_n)) {
    total_n_display <- round(as.numeric(total_n))
    badge_items <- c(badge_items, list(htmltools::tags$span(
      style = badge_style,
      htmltools::HTML(paste0("n&nbsp;=&nbsp;", format(total_n_display, big.mark = ",")))
    )))
  }

  # Questions badge
  if (!is.na(n_questions)) {
    badge_items <- c(badge_items, list(htmltools::tags$span(
      style = badge_style,
      htmltools::HTML(paste0("<span style=\"color:rgba(255,255,255,1);font-weight:700;\">",
                             n_questions, "</span>&nbsp;Questions"))
    )))
  }

  # Weighted / Unweighted badge
  weight_label <- if (isTRUE(apply_weighting)) "Weighted" else "Unweighted"
  badge_items <- c(badge_items, list(htmltools::tags$span(
    style = badge_style, weight_label
  )))

  # Created date badge (file generation date; JS updates to "Last saved …" on save)
  created_label <- format(Sys.Date(), "Created %b %Y")
  badge_items <- c(badge_items, list(htmltools::tags$span(
    id = "header-date-badge",
    style = badge_style, created_label
  )))

  # Interleave badges with separators
  badge_els <- list()
  for (i in seq_along(badge_items)) {
    if (i > 1) {
      badge_els <- c(badge_els, list(htmltools::tags$span(style = separator_style)))
    }
    badge_els <- c(badge_els, list(badge_items[[i]]))
  }

  stats_bar <- htmltools::tags$div(
    style = paste0(
      "display:inline-flex;align-items:center;margin-top:12px;",
      "border:1px solid rgba(255,255,255,0.15);border-radius:6px;",
      "background:rgba(255,255,255,0.05);"
    ),
    badge_els
  )

  # --- Assemble header ---
  htmltools::tags$div(
    class = "header",
    htmltools::tags$div(
      class = "header-inner",
      style = "display:flex;flex-direction:column;",
      top_row,
      study_row,
      prepared_row,
      stats_bar
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
      htmltools::tags$div(class = "help-subtitle", "Everything you need to know to use this report"),

      # --- Navigating ---
      htmltools::tags$h3("Navigating the Report"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Sidebar"),
          "Browse all questions. Type in the search box to filter."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Banner tabs"),
          "Switch between cross-tabulation groups (e.g. Total, Age, Region)."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Summary"),
          "Dashboard with key metrics, gauges, and significant findings."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Crosstabs"),
          "Full data tables with charts for every question.")
      ),

      # --- Tables ---
      htmltools::tags$h3("Working with Tables"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Column headers"),
          "Click any header to sort the table by that column."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Column chips"),
          "Toggle individual columns on or off to focus the view."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Heatmap"),
          "Tick the Heatmap checkbox to colour-code cells by value."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Show count"),
          "Tick to display raw frequencies alongside percentages.")
      ),

      # --- Charts ---
      htmltools::tags$h3("Charts"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Chart toggle"),
          "Tick the Chart checkbox to show or hide the chart."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Chart chips"),
          "Select which columns appear in the chart to compare groups."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\u2715 on rows"),
          "Hover a data row and click \u2715 to exclude it from the chart.")
      ),

      # --- Insights & Notes ---
      htmltools::tags$h3("Adding Insights"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "+ Add Insight"),
          "Click below any question to add your analysis or commentary."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Summary text"),
          "The Summary tab has editable text areas for Background and Executive Summary.")
      ),

      # --- Pinning ---
      htmltools::tags$h3("Pinning Key Findings"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\U0001F4CC Pin"),
          "Click the pin icon on any question to save it to your Pinned Views deck."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Pinned Views"),
          "A curated set of your key findings. Reorder with \u25B2\u25BC, remove with \u2715."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Section dividers"),
          "Use 'Add Section' in Pinned Views to organise pins into groups."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Summary pins"),
          "Pin gauge sections or sig findings from the Summary tab too.")
      ),

      # --- Added Slides ---
      htmltools::tags$h3("Added Slides"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Add Slide"),
          "Create narrative slides with formatted text (supports **bold**, *italic*, bullets, headings)."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\U0001F5BC Add image"),
          "Upload a chart, screenshot, or diagram to any slide. Images are resized automatically."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\U0001F4CC Pin slide"),
          "Pin an Added Slide to include it alongside your data findings in Pinned Views.")
      ),

      # --- Exporting ---
      htmltools::tags$h3("Exporting & Sharing"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Save Report"),
          "Downloads the HTML file with all your insights, pins, and edits preserved."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\U0001F4F7 Export PNG"),
          "Download any chart or pinned card as a high-resolution PNG image."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\U0001F4CB Copy"),
          "Copy a chart or pin to your clipboard, then paste straight into PowerPoint."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Print / PDF"),
          "Print your Pinned Views as a paginated document (one finding per page)."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "CSV / Excel"),
          "Export table data for any question in spreadsheet format.")
      ),

      # --- Tip ---
      htmltools::tags$div(class = "help-tip",
        htmltools::HTML(paste0(
          "<strong>Tip:</strong> This report is a live working document. ",
          "Add insights, pin key findings, create narrative slides, then <strong>Save</strong> ",
          "to keep everything. Re-open the saved file any time to continue where you left off. ",
          "Press <strong>?</strong> to show this guide again."
        ))
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
      onclick = sprintf("toggleInsight('%s')", js_esc(q_code)),
      if (has_comment) "Edit Insight" else "+ Add Insight"
    ),
    # Insight container with markdown editor/renderer (like qual slides)
    htmltools::tags$div(
      class = "insight-container",
      style = if (!has_comment) "display:none;" else NULL,
      # Textarea for editing raw markdown (hidden unless .editing)
      htmltools::tags$textarea(
        class = "insight-md-editor",
        `data-q-code` = q_code,
        placeholder = "Type key insight here\u2026 (supports **bold**, *italic*, - bullets, ## headings)",
        if (has_comment) initial_text
      ),
      # Rendered markdown display (visible unless .editing)
      htmltools::tags$div(
        class = "insight-md-rendered",
        `data-q-code` = q_code,
        ondblclick = sprintf("toggleInsightEdit('%s')", js_esc(q_code))
      ),
      htmltools::tags$button(
        class = "insight-dismiss",
        title = "Delete insight",
        onclick = sprintf("dismissInsight('%s')", js_esc(q_code)),
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
    has_chart <- !is.null(chart_result) &&
                 !is.null(chart_result$chart_data) &&
                 !is.null(chart_result$svg)
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
            onclick = sprintf("togglePin('%s')", js_esc(q_code)),
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
                                  htmltools::htmlEscape(first_group_name), htmltools::htmlEscape(stat_label %||% "")))
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
          onclick = sprintf("exportExcel('%s')", js_esc(q_code)),
          "\u2B73 Export Excel"
        ),
        htmltools::tags$button(
          class = "export-btn",
          style = "margin-left:8px",
          onclick = sprintf("exportCSV('%s')", js_esc(q_code)),
          "\u2B73 Export CSV"
        ),
        if (has_chart) {
          htmltools::tags$button(
            class = "export-btn export-chart-btn",
            style = "margin-left:8px;display:none",
            onclick = sprintf("exportChartPNG('%s')", js_esc(q_code)),
            "\U0001F4CA Export Chart"
          )
        },
        if (has_chart) {
          htmltools::tags$button(
            class = "export-btn export-chart-btn clipboard-btn",
            style = "margin-left:4px;display:none",
            title = "Copy chart to clipboard",
            onclick = sprintf("copyChartToClipboard('%s')", js_esc(q_code)),
            "\U0001F4CB Copy Chart"
          )
        },
        if (has_chart) {
          htmltools::tags$div(
            class = "slide-export-group",
            style = "display:none;position:relative;margin-left:8px;",
            htmltools::tags$button(
              class = "export-btn export-slide-btn",
              onclick = sprintf("toggleSlideMenu('%s')", js_esc(q_code)),
              "\U0001F4C4 Export Slide \u25BE"
            ),
            htmltools::tags$div(
              class = "slide-menu",
              id = sprintf("slide-menu-%s", gsub("[^a-zA-Z0-9]", "-", q_code)),
              style = "display:none;position:absolute;top:100%;right:0;background:#fff;border:1px solid #e2e8f0;border-radius:6px;box-shadow:0 4px 12px rgba(0,0,0,0.1);z-index:100;min-width:160px;padding:4px 0;",
              htmltools::tags$button(
                class = "slide-menu-item",
                style = "display:block;width:100%;text-align:left;padding:8px 14px;border:none;background:none;cursor:pointer;font-size:12px;font-family:inherit;",
                onclick = sprintf("exportSlidePNG('%s','chart_table')", js_esc(q_code)),
                "Chart + Table"
              ),
              htmltools::tags$button(
                class = "slide-menu-item",
                style = "display:block;width:100%;text-align:left;padding:8px 14px;border:none;background:none;cursor:pointer;font-size:12px;font-family:inherit;",
                onclick = sprintf("exportSlidePNG('%s','chart')", js_esc(q_code)),
                "Chart Only"
              ),
              htmltools::tags$button(
                class = "slide-menu-item",
                style = "display:block;width:100%;text-align:left;padding:8px 14px;border:none;background:none;cursor:pointer;font-size:12px;font-family:inherit;",
                onclick = sprintf("exportSlidePNG('%s','table')", js_esc(q_code)),
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


# ==============================================================================
# COMPONENT: QUALITATIVE SLIDES (V10.7.0)
# ==============================================================================

#' Build Qualitative Panel
#'
#' Creates a tab panel for qualitative/open-ended content slides.
#' Slides can be seeded from the config Excel and also added/edited in the browser.
#'
#' @param slides List of slide objects from load_qualitative_sheet(), or NULL
#' @param brand_colour Character hex colour
#' @return htmltools::tags$div
#' @keywords internal
build_qualitative_panel <- function(slides = NULL, brand_colour = "#323367") {
  # Render initial slides from config (if any)
  slide_cards <- if (!is.null(slides) && length(slides) > 0) {
    lapply(slides, function(s) {
      build_qual_slide_card(s$id, s$title, s$content, s$image_data)
    })
  }

  htmltools::tags$div(
    id = "tab-qualitative",
    class = "tab-panel",
    htmltools::tags$div(
      class = "qual-container",
      style = "max-width:1400px;margin:0 auto;padding:20px 32px;",
      htmltools::tags$div(
        class = "qual-header",
        style = "display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;",
        htmltools::tags$div(
          htmltools::tags$h2(style = "font-size:18px;font-weight:700;color:#1e293b;margin-bottom:4px;",
                             "Added Slides"),
          htmltools::tags$p(style = "font-size:12px;color:#64748b;",
                            "Open-ended findings, quotes, and narrative content. Double-click to edit, use markdown for formatting.")
        ),
        htmltools::tags$div(
          style = "display:flex;gap:8px;",
          htmltools::tags$button(class = "export-btn", onclick = "addQualSlide()",
                                 "\u2795 Add Slide"),
          htmltools::tags$button(class = "export-btn", onclick = "saveReportHTML()",
                                 "\U0001F4BE Save Report")
        )
      ),
      htmltools::tags$div(
        class = "qual-md-help",
        style = "background:#f8fafc;border:1px solid #e2e8f0;border-radius:6px;padding:10px 16px;margin-bottom:16px;font-size:11px;color:#64748b;line-height:1.6;",
        htmltools::tags$span(style = "font-weight:600;color:#475569;", "Formatting: "),
        htmltools::HTML(paste0(
          "<code>**bold**</code> &middot; ",
          "<code>*italic*</code> &middot; ",
          "<code>## Heading</code> &middot; ",
          "<code>- bullet</code> &middot; ",
          "<code>&gt; quote</code>"
        ))
      ),
      htmltools::tags$div(id = "qual-slides-container", slide_cards),
      htmltools::tags$div(
        id = "qual-empty-state",
        style = paste0(
          if (!is.null(slides) && length(slides) > 0) "display:none;" else "",
          "text-align:center;padding:60px 20px;color:#94a3b8;"
        ),
        htmltools::tags$div(style = "font-size:36px;margin-bottom:12px;", "\U0001F4DD"),
        htmltools::tags$div(style = "font-size:14px;font-weight:600;", "No slides yet"),
        htmltools::tags$div(style = "font-size:12px;margin-top:4px;",
          "Click 'Add Slide' to create narrative content, or add a 'Qualitative' sheet to your config Excel.")
      )
    )
  )
}


#' Build Single Qualitative Slide Card
#'
#' @param slide_id Character unique ID
#' @param title Character slide title
#' @param content_md Character markdown content
#' @param image_data Character base64 data URL for embedded image, or NULL
#' @return htmltools::tags$div
#' @keywords internal
build_qual_slide_card <- function(slide_id, title, content_md, image_data = NULL) {
  htmltools::tags$div(
    class = "qual-slide-card",
    `data-slide-id` = slide_id,
    htmltools::tags$div(
      class = "qual-slide-header",
      htmltools::tags$div(
        class = "qual-slide-title",
        contenteditable = "true",
        title
      ),
      htmltools::tags$div(
        class = "qual-slide-actions",
        htmltools::tags$button(class = "export-btn", title = "Add image",
                               onclick = sprintf("triggerQualImage('%s')", slide_id),
                               htmltools::HTML("&#x1F5BC;")),
        htmltools::tags$button(class = "export-btn", title = "Pin this slide",
                               onclick = sprintf("pinQualSlide('%s')", slide_id),
                               htmltools::HTML("&#x1F4CC;")),
        htmltools::tags$button(class = "export-btn", title = "Move up",
                               onclick = sprintf("moveQualSlide('%s','up')", slide_id),
                               htmltools::HTML("&#x25B2;")),
        htmltools::tags$button(class = "export-btn", title = "Move down",
                               onclick = sprintf("moveQualSlide('%s','down')", slide_id),
                               htmltools::HTML("&#x25BC;")),
        htmltools::tags$button(class = "export-btn", title = "Remove slide",
                               style = "color:#e8614d;",
                               onclick = sprintf("removeQualSlide('%s')", slide_id),
                               htmltools::HTML("&#x2715;"))
      )
    ),
    # Image preview (shown if image_data provided, hidden otherwise)
    htmltools::tags$div(class = "qual-img-preview",
      style = if (is.null(image_data) || !nzchar(image_data %||% "")) "display:none;" else "",
      htmltools::tags$img(class = "qual-img-thumb",
        src = if (!is.null(image_data) && nzchar(image_data %||% "")) image_data else ""),
      htmltools::tags$button(class = "qual-img-remove",
                             onclick = sprintf("removeQualImage('%s')", slide_id),
                             title = "Remove image",
                             htmltools::HTML("&times;"))
    ),
    # Hidden file input for image upload
    htmltools::tags$input(type = "file", class = "qual-img-input",
                          accept = "image/*", style = "display:none;",
                          onchange = sprintf("handleQualImage('%s', this)", slide_id)),
    # Markdown editor (shown when editing)
    htmltools::tags$textarea(
      class = "qual-md-editor",
      rows = "6",
      placeholder = "Enter markdown content... (**bold**, *italic*, > quote, - bullet, ## heading)",
      content_md
    ),
    # Rendered output (shown when not editing)
    htmltools::tags$div(class = "qual-md-rendered"),
    # Hidden stores for save persistence
    htmltools::tags$textarea(class = "qual-md-store", style = "display:none;", content_md),
    htmltools::tags$textarea(class = "qual-img-store", style = "display:none;",
      if (!is.null(image_data) && nzchar(image_data %||% "")) image_data else "")
  )
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


# ==============================================================================
# COMPONENT: CLOSING SECTION (V10.7.0)
# ==============================================================================

#' Build Closing Section
#'
#' Professional footer section with analyst contact details, verbatim file
#' reference, and editable closing notes. Only renders if at least one field
#' has content.
#'
#' @param config_obj Configuration object
#' @return htmltools::tags$div or NULL
#' @keywords internal
build_closing_section <- function(config_obj) {
  analyst_name     <- config_obj$analyst_name
  analyst_email    <- config_obj$analyst_email
  analyst_phone    <- config_obj$analyst_phone
  verbatim_file    <- config_obj$verbatim_filename
  closing_notes    <- config_obj$closing_notes

  has_content <- any(sapply(
    list(analyst_name, analyst_email, analyst_phone, verbatim_file, closing_notes),
    function(x) !is.null(x) && nzchar(trimws(x))
  ))
  if (!has_content) return(NULL)

  # Contact items
  contact_items <- list()
  if (!is.null(analyst_name) && nzchar(analyst_name)) {
    contact_items <- c(contact_items, list(
      htmltools::tags$div(class = "closing-contact-item",
        htmltools::tags$span(class = "closing-label", "Analyst"),
        htmltools::tags$span(class = "closing-value", analyst_name)
      )
    ))
  }
  if (!is.null(analyst_email) && nzchar(analyst_email)) {
    contact_items <- c(contact_items, list(
      htmltools::tags$div(class = "closing-contact-item",
        htmltools::tags$span(class = "closing-label", "Email"),
        htmltools::tags$a(class = "closing-value closing-link",
                          href = paste0("mailto:", analyst_email), analyst_email)
      )
    ))
  }
  if (!is.null(analyst_phone) && nzchar(analyst_phone)) {
    contact_items <- c(contact_items, list(
      htmltools::tags$div(class = "closing-contact-item",
        htmltools::tags$span(class = "closing-label", "Phone"),
        htmltools::tags$span(class = "closing-value", analyst_phone)
      )
    ))
  }

  # Verbatim reference
  verbatim_el <- NULL
  if (!is.null(verbatim_file) && nzchar(verbatim_file)) {
    verbatim_el <- htmltools::tags$div(class = "closing-verbatim",
      htmltools::tags$span(class = "closing-label", "Appendices"),
      htmltools::tags$span(class = "closing-value", verbatim_file)
    )
  }

  # Closing notes (editable in HTML)
  notes_content <- if (!is.null(closing_notes) && nzchar(closing_notes)) closing_notes else ""
  notes_el <- htmltools::tags$div(class = "closing-notes-section",
    htmltools::tags$div(class = "closing-label", "Notes"),
    htmltools::tags$div(
      class = "closing-notes-editor",
      contenteditable = "true",
      `data-placeholder` = "Add closing notes...",
      htmltools::HTML(notes_content)
    ),
    htmltools::tags$textarea(
      class = "closing-notes-store",
      style = "display:none;",
      notes_content
    )
  )

  htmltools::tags$div(
    class = "closing-section",
    id = "report-closing-section",
    htmltools::tags$div(class = "closing-divider"),
    htmltools::tags$div(class = "closing-content",
      if (length(contact_items) > 0) {
        htmltools::tags$div(class = "closing-contact-grid", contact_items)
      },
      verbatim_el,
      notes_el
    )
  )
}


#' Wrap Closing Section as an About Tab Panel
#'
#' @param config_obj Configuration object
#' @return htmltools::tags$div (tab-panel) or NULL
#' @keywords internal
build_about_panel <- function(config_obj) {
  content <- build_closing_section(config_obj)
  if (is.null(content)) return(NULL)
  htmltools::tags$div(id = "tab-about", class = "tab-panel", content)
}


#' Build JavaScript for Interactivity
#'
#' Assembles all JS from focused helper functions into a single script tag.
#' Plain vanilla JavaScript — no HTMLWidgets, no React, no external deps.
#'
#' @param html_data The transformed data
#' @return htmltools::tags$script
build_javascript <- function(html_data, brand_colour = "#323367") {
  group_codes <- sapply(html_data$banner_groups, function(g) g$banner_code)

  # Global brand colour variable — all JS files reference this instead of hardcoded hex
  brand_colour_js <- sprintf('var BRAND_COLOUR = "%s";\n', brand_colour)

  js_full <- paste0(
    brand_colour_js,
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


# ==============================================================================
# JS FILE LOADING HELPER
# ==============================================================================

# Directory for standalone JS files
.js_dir <- file.path(
  if (exists(".tabs_lib_dir", envir = globalenv())) {
    file.path(get(".tabs_lib_dir", envir = globalenv()), "html_report", "js")
  } else {
    # Fallback: attempt to determine path from the call stack. This is fragile
    # and only works when this file is directly source()'d. Set .tabs_lib_dir
    # in the calling environment before sourcing to avoid this path.
    .ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
    if (is.null(.ofile) || !nzchar(.ofile %||% "")) {
      warning(paste(
        "Cannot determine JS directory: .tabs_lib_dir is not set",
        "and sys.frame()$ofile is unavailable. JS files may not load.",
        "Set .tabs_lib_dir before sourcing run_crosstabs.R."
      ))
      file.path(".", "js")
    } else {
      file.path(dirname(.ofile), "js")
    }
  }
)

#' Read a JavaScript file and return its content as a string
#'
#' @param filename Character, name of the JS file (e.g. "core_navigation.js")
#' @return Character string of JavaScript code
#' @keywords internal
read_js_file <- function(filename) {
  js_path <- file.path(.js_dir, filename)
  if (!file.exists(js_path)) {
    cat(sprintf("  [ERROR] JavaScript file not found: %s\n", js_path))
    cat(sprintf("  Expected in: %s\n", .js_dir))
    return("")
  }
  paste(readLines(js_path, warn = FALSE), collapse = "\n")
}


#' Build Core Navigation JavaScript
#'
#' Global state, question navigation, banner switching, heatmap toggle,
#' frequency toggle, print, chart toggle, and insight/comment system.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_core_navigation <- function() {
  read_js_file("core_navigation.js")
}


#' Build Chart Column Picker JavaScript
#'
#' Chart column picker, multi-column stacked/horizontal SVG builders,
#' HSL colour utilities, and chart PNG export.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_chart_picker <- function() {
  read_js_file("chart_picker.js")
}


#' Build Slide Export JavaScript
#'
#' Presentation-quality SVG slide builder with title, base, chart,
#' metrics strip, and insight — rendered to PNG at 3x resolution.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_slide_export <- function() {
  read_js_file("slide_export.js")
}


#' Build Pinned Views JavaScript
#'
#' Pin/unpin questions, render pinned view cards, reorder, persist to JSON,
#' export all pinned views as individual slide PNGs.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_pinned_views <- function() {
  read_js_file("pinned_views.js")
}


#' Build Table Export and Init JavaScript
#'
#' Table data extraction, CSV/Excel export, column toggle chips,
#' column sort, downloadBlob utility, and DOMContentLoaded init.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_table_export_and_init <- function() {
  read_js_file("table_export_init.js")
}


