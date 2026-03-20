# ==============================================================================
# MAXDIFF HTML REPORT - PAGE BUILDER - TURAS V11.2
# ==============================================================================
# Assembles the full HTML document from tables, charts, and data.
# Unified architecture: Overview, Preference Scores, Item Analysis,
# Head-to-Head, Portfolio (TURF), Diagnostics, Added Slides,
# Pinned Views, About.
#
# Every analytical tab has: Pin button + Add Insight (markdown editor).
# Header has: Save Report button + Help button.
# JS interactivity loaded from inline script (self-contained).
# ==============================================================================

# htmlEscape() and %||% are defined in 01_data_transformer.R (loaded first)


# ==============================================================================
# LOGO RESOLUTION
# ==============================================================================

#' Resolve a file path to a base64 data URI
#'
#' @param logo_path File path to an image
#' @return Base64 data URI string, or NULL if unavailable
#' @keywords internal
md_resolve_logo_uri <- function(logo_path) {
  if (is.null(logo_path) || !nzchar(logo_path)) return(NULL)
  if (!file.exists(logo_path)) return(NULL)
  tryCatch({
    ext <- tolower(tools::file_ext(logo_path))
    mime <- switch(ext,
      png = "image/png",
      jpg = , jpeg = "image/jpeg",
      svg = "image/svg+xml",
      gif = "image/gif",
      "image/png"
    )
    raw_data <- readBin(logo_path, "raw", file.info(logo_path)$size)
    b64 <- if (requireNamespace("base64enc", quietly = TRUE)) {
      base64enc::base64encode(raw_data)
    } else if (requireNamespace("jsonlite", quietly = TRUE)) {
      jsonlite::base64_enc(raw_data)
    } else {
      return(NULL)
    }
    paste0("data:", mime, ";base64,", b64)
  }, error = function(e) NULL)
}


# ==============================================================================
# PANEL IMAGES HELPER
# ==============================================================================

build_panel_images <- function(images_list, panel_name) {
  if (is.null(images_list)) return("")
  panel_images <- images_list[[panel_name]]
  if (is.null(panel_images)) return("")
  if (!is.null(panel_images$path)) panel_images <- list(panel_images)

  img_blocks <- vapply(panel_images, function(img) {
    uri <- md_resolve_logo_uri(img$path)
    if (is.null(uri)) return("")
    caption_html <- ""
    if (!is.null(img$caption) && nzchar(img$caption)) {
      caption_html <- sprintf(
        '<div class="md-image-caption">%s</div>', htmlEscape(img$caption))
    }
    sprintf(
      '<div class="md-image-container"><img src="%s" alt="%s" class="md-embedded-image"/>%s</div>',
      uri, htmlEscape(img$caption %||% "Embedded image"), caption_html)
  }, character(1))
  paste(img_blocks[nzchar(img_blocks)], collapse = "\n")
}


# ==============================================================================
# INSIGHT AREA BUILDER
# ==============================================================================

#' Build an insight area for a panel
#'
#' @param panel_id Panel identifier (e.g. "overview", "preferences")
#' @param insights_list Named list of insights from config (keyed by panel_id)
#' @return HTML string
#' @keywords internal
build_insight_area <- function(panel_id, insights_list = NULL) {

  # Config-provided insight for this panel
  config_entries <- "[]"
  initial_text <- ""
  if (!is.null(insights_list) && !is.null(insights_list[[panel_id]])) {
    entries <- insights_list[[panel_id]]
    if (is.character(entries) && length(entries) == 1) {
      entries <- list(list(banner = NA, text = entries))
    }
    config_entries <- tryCatch(
      jsonlite::toJSON(entries, auto_unbox = TRUE),
      error = function(e) "[]"
    )
    initial_text <- if (length(entries) > 0 && !is.null(entries[[1]]$text)) entries[[1]]$text else ""
  }

  has_initial <- nzchar(initial_text)
  container_display <- if (has_initial) "block" else "none"
  toggle_text <- if (has_initial) "- Hide Insight" else "+ Add Insight"
  editor_display <- if (has_initial) "none" else "block"
  rendered_display <- if (has_initial) "block" else "none"

  sprintf(
    '<div class="insight-area" data-panel="%s">
  <script type="application/json" class="insight-comments-data">%s</script>
  <button class="insight-toggle" onclick="window._mdToggleInsight(\'%s\')">%s</button>
  <div class="insight-container" style="display:%s;">
    <textarea class="insight-md-editor" data-panel="%s" placeholder="Type key insight here... (supports **bold**, *italic*, - bullets)"
              style="display:%s;">%s</textarea>
    <div class="insight-md-rendered" data-panel="%s" ondblclick="window._mdToggleInsightEdit(\'%s\')"
         style="display:%s;"></div>
    <button class="insight-dismiss" onclick="window._mdDismissInsight(\'%s\')">&times;</button>
  </div>
  <textarea class="insight-store" data-panel="%s" style="display:none;"></textarea>
</div>',
    panel_id, config_entries, panel_id, toggle_text,
    container_display, panel_id, editor_display,
    htmlEscape(initial_text), panel_id, panel_id,
    rendered_display, panel_id, panel_id
  )
}


# ==============================================================================
# PIN BUTTON BUILDER
# ==============================================================================

build_pin_button <- function(panel_id) {
  sprintf(
    '<div class="pin-btn-wrapper">
  <button class="pin-btn" data-panel="%s" onclick="window._mdTogglePin(\'%s\')" title="Pin this view">\U0001F4CC</button>
  <div class="pin-mode-popover" style="display:none;">
    <button class="pin-mode-option" onclick="window._mdExecutePin(\'%s\',\'all\')">Table + Chart + Insight</button>
    <button class="pin-mode-option" onclick="window._mdExecutePin(\'%s\',\'chart_insight\')">Chart + Insight</button>
    <button class="pin-mode-option" onclick="window._mdExecutePin(\'%s\',\'table_insight\')">Table + Insight</button>
  </div>
</div>',
    panel_id, panel_id, panel_id, panel_id, panel_id
  )
}


# ==============================================================================
# PANEL TOOLBAR (Pin + Insight buttons for each panel)
# ==============================================================================

build_panel_toolbar <- function(panel_id, insights_list = NULL) {
  paste0(
    '<div class="md-panel-toolbar">',
    build_pin_button(panel_id),
    '</div>',
    build_insight_area(panel_id, insights_list)
  )
}


# ==============================================================================
# CUSTOM SLIDE BUILDER
# ==============================================================================

build_custom_slide_panel <- function(slide, config) {
  title <- htmlEscape(slide$Title %||% "Custom Slide")
  content <- slide$Content %||% ""
  slide_id <- tolower(gsub("[^a-z0-9]", "-", tolower(slide$Title %||% "slide"), perl = TRUE))
  slide_id <- paste0("custom-", slide_id)

  image_html <- ""
  img_path <- slide$Image_Path %||% ""
  if (nzchar(img_path)) {
    uri <- md_resolve_logo_uri(img_path)
    if (!is.null(uri)) {
      image_html <- sprintf(
        '<div class="md-image-container"><img src="%s" alt="%s" class="md-embedded-image"/></div>',
        uri, title)
    }
  }

  sprintf(
    '<div class="md-panel" id="panel-%s">
  <div class="md-section">
    <h2>%s</h2>
    <div class="md-slide-content">%s</div>
    %s
  </div>
</div>',
    slide_id, title, content, image_html)
}


# ==============================================================================
# MAIN PAGE BUILDER
# ==============================================================================

#' Build complete MaxDiff HTML report page
#'
#' @param html_data Structured data from transform_maxdiff_for_html()
#' @param tables Named list of HTML table strings
#' @param charts Named list of SVG chart strings
#' @param config Module configuration
#' @param simulator_html Optional simulator HTML for embedding
#' @param js_code JavaScript code string to inline
#'
#' @return Single HTML string (complete document)
#' @keywords internal
build_maxdiff_page <- function(html_data, tables, charts, config,
                               simulator_html = NULL, js_code = "") {

  brand <- html_data$meta$brand_colour %||% "#323367"
  accent <- html_data$meta$accent_colour %||% "#CC9900"
  raw_name <- html_data$meta$project_name %||% "MaxDiff Analysis"
  project_name <- htmlEscape(gsub("_", " ", raw_name))
  insights <- html_data$insights

  css <- build_md_css(brand, accent)
  print_css <- build_md_print_css()
  meta_tags <- build_md_meta(html_data)
  header <- build_md_header(html_data, config)

  # Determine which tabs to show
  has_preferences <- !is.null(html_data$preferences$scores)
  has_items <- !is.null(html_data$items$count_data)
  has_h2h <- !is.null(html_data$head_to_head)
  has_segments <- !is.null(html_data$segments)
  has_turf <- !is.null(html_data$turf)
  has_simulator <- !is.null(simulator_html) && nzchar(simulator_html)

  # Build panels
  overview_panel   <- build_overview_panel(html_data, tables, charts, insights)
  pref_panel       <- if (has_preferences) build_preferences_panel(html_data, tables, charts, insights) else ""
  items_panel      <- if (has_items) build_items_panel(html_data, tables, charts, insights) else ""
  h2h_panel        <- if (has_h2h) build_h2h_panel(html_data, tables, charts, insights) else ""
  turf_panel       <- if (has_turf) build_turf_panel(html_data, tables, charts, insights) else ""
  segments_panel   <- if (has_segments) build_segments_panel(html_data, tables, charts, insights) else ""
  diag_panel       <- build_diagnostics_panel(html_data, tables, charts, insights)
  about_panel      <- build_md_about_panel(html_data$meta, config, html_data$methodology)
  help_overlay     <- build_md_help_overlay()
  pinned_panel     <- build_pinned_views_panel()

  # Simulator panel (embedded iframe)
  simulator_panel <- ""
  if (has_simulator) {
    sim_escaped <- gsub("&", "&amp;", simulator_html, fixed = TRUE)
    sim_escaped <- gsub("\"", "&quot;", sim_escaped, fixed = TRUE)
    simulator_panel <- sprintf(
      '<div class="md-panel" id="panel-simulator">
<iframe srcdoc="%s" style="width:100%%;border:none;border-radius:8px;min-height:85vh;" onload="this.style.height=(this.contentWindow.document.body.scrollHeight+40)+\'px\'"></iframe>
</div>', sim_escaped)
  }

  # Custom slide panels
  slides_df <- config$slides %||% config$custom_slides %||% NULL
  custom_panels <- character()
  custom_tab_buttons <- character()
  if (!is.null(slides_df) && is.data.frame(slides_df) && nrow(slides_df) > 0) {
    for (i in seq_len(nrow(slides_df))) {
      slide <- as.list(slides_df[i, , drop = FALSE])
      slide_id <- tolower(gsub("[^a-z0-9]", "-", tolower(slide$Title %||% "slide"), perl = TRUE))
      slide_id <- paste0("custom-", slide_id)
      custom_panels <- c(custom_panels, build_custom_slide_panel(slide, config))
      custom_tab_buttons <- c(custom_tab_buttons, sprintf(
        '<button class="md-tab-btn" data-tab="%s">%s</button>',
        slide_id, htmlEscape(slide$Title %||% "Slide")))
    }
  }

  # Build tab navigation
  tab_buttons <- '<button class="md-tab-btn active" data-tab="overview">Overview</button>'
  if (has_preferences) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="preferences">Preference Scores</button>')
  if (has_items) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="items">Item Analysis</button>')
  if (has_h2h) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="h2h">Head-to-Head</button>')
  if (has_turf) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="turf">Portfolio (TURF)</button>')
  if (has_segments) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="segments">Segments</button>')
  tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="diagnostics">Diagnostics</button>')
  if (has_simulator) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="simulator">Simulator</button>')
  if (length(custom_tab_buttons) > 0) {
    tab_buttons <- paste0(tab_buttons, "\n", paste(custom_tab_buttons, collapse = "\n"))
  }
  tab_buttons <- paste0(tab_buttons,
    '\n<button class="md-tab-btn" data-tab="pinned">Pinned Views <span class="pin-count-badge" id="pin-count-badge" style="display:none;">0</span></button>',
    '\n<button class="md-tab-btn" data-tab="about">About</button>')

  custom_panels_html <- paste(custom_panels, collapse = "\n")

  # Assemble page
  sprintf('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
%s
<title>%s - MaxDiff Report</title>
<style>%s</style>
<style>%s</style>
</head>
<body>
%s
<div class="md-tab-nav">%s</div>
<div class="md-container">
%s
%s
%s
%s
%s
%s
%s
%s
%s
%s
%s
</div>
%s
<footer class="md-footer">Generated by TURAS Analytics Platform &middot; MaxDiff Module v11.2 &middot; %s</footer>
<script>%s</script>
</body>
</html>',
    meta_tags,
    project_name,
    css,
    print_css,
    header,
    tab_buttons,
    overview_panel,
    pref_panel,
    items_panel,
    h2h_panel,
    turf_panel,
    segments_panel,
    diag_panel,
    simulator_panel,
    custom_panels_html,
    pinned_panel,
    about_panel,
    help_overlay,
    format(Sys.Date(), "%B %Y"),
    js_code
  )
}


# ==============================================================================
# HEADER BUILDER
# ==============================================================================

build_md_header <- function(html_data, config) {

  meta <- html_data$meta
  summary <- html_data$summary

  # Logo
  logo_html <- ""
  logo_uri <- md_resolve_logo_uri(meta$researcher_logo_path)
  if (!is.null(logo_uri) && nzchar(logo_uri)) {
    logo_html <- sprintf(
      '<div style="width:72px;height:72px;border-radius:12px;display:flex;align-items:center;justify-content:center;flex-shrink:0;"><img src="%s" alt="Logo" class="md-header-logo"/></div>',
      logo_uri)
  }

  # Header buttons (help + save)
  header_btns <- paste0(
    '<div class="md-header-buttons">',
    '<button class="md-save-btn" onclick="window._mdSaveReport()" title="Save report to disk">',
    '<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M2 14h12M8 2v9M4 7l4 4 4-4"/></svg>',
    ' Save Report</button>',
    '<button class="md-help-btn" onclick="window._mdToggleHelp()" title="Quick guide">?</button>',
    '</div>')

  # Prepared by line
  prepared_parts <- character()
  company <- meta$company_name %||% ""
  researcher <- meta$researcher_name %||% ""
  client <- meta$client_name %||% ""

  if (nzchar(company)) {
    if (nzchar(researcher)) {
      prepared_parts <- c(prepared_parts, sprintf('Prepared by <strong>%s</strong> (%s)', htmlEscape(researcher), htmlEscape(company)))
    } else {
      prepared_parts <- c(prepared_parts, sprintf('Prepared by <strong>%s</strong>', htmlEscape(company)))
    }
  }
  if (nzchar(client)) {
    prepared_parts <- c(prepared_parts, sprintf('for <strong>%s</strong>', htmlEscape(client)))
  }
  prepared_html <- if (length(prepared_parts) > 0) {
    sprintf('<div class="md-header-prepared">%s</div>', paste(prepared_parts, collapse = " "))
  } else ""

  # Badge bar
  badges <- character()
  badges <- c(badges, sprintf('<span class="md-badge-item">%s</span>', toupper(meta$method %||% "Analysis")))
  if (!is.null(meta$n_total) && meta$n_total > 0) {
    badges <- c(badges, sprintf('<span class="md-badge-item">n&nbsp;=&nbsp;<strong>%s</strong></span>', format(meta$n_total, big.mark = ",")))
  }
  badges <- c(badges, sprintf('<span class="md-badge-item"><strong>%s</strong>&nbsp;Items</span>', meta$n_items %||% "0"))
  if (!is.null(summary$top_item) && nzchar(summary$top_item) && summary$top_item != "N/A") {
    badges <- c(badges, sprintf('<span class="md-badge-item">Top:&nbsp;<strong>%s</strong></span>', htmlEscape(summary$top_item)))
  }
  badges <- c(badges, sprintf('<span class="md-badge-item" id="md-header-date">Created %s</span>', format(Sys.Date(), "%b %Y")))
  badge_html <- paste(badges, collapse = '<span class="md-badge-sep"></span>')

  sprintf(
    '<header class="md-header">
<div class="md-header-inner">
<div class="md-header-top">
<div class="md-header-branding">%s
<div class="md-header-titles">
<h1>Turas MaxDiff</h1>
<div class="md-header-subtitle">MaxDiff Analysis Report</div>
</div>
</div>
%s
</div>
<div class="md-header-title">%s</div>
%s
<div class="md-badge-bar">%s</div>
</div>
</header>',
    logo_html, header_btns,
    htmlEscape(gsub("_", " ", meta$project_name %||% "MaxDiff Analysis")),
    prepared_html, badge_html
  )
}


# ==============================================================================
# ABOUT PANEL (with methodology folded in)
# ==============================================================================

build_md_about_panel <- function(meta, config, methodology = NULL) {

  # Contact grid
  contact_rows <- character()
  fields <- list(
    list(val = meta$researcher_name %||% "", label = "Analyst"),
    list(val = config$project_settings$Analyst_Email %||% "", label = "Email"),
    list(val = config$project_settings$Analyst_Phone %||% "", label = "Phone"),
    list(val = meta$client_name %||% "", label = "Client"),
    list(val = meta$company_name %||% "", label = "Company")
  )
  for (f in fields) {
    if (nzchar(f$val)) {
      val_html <- if (f$label == "Email") {
        sprintf('<a href="mailto:%s">%s</a>', htmlEscape(f$val), htmlEscape(f$val))
      } else htmlEscape(f$val)
      contact_rows <- c(contact_rows, sprintf(
        '<div class="md-about-label">%s</div><div class="md-about-value">%s</div>',
        f$label, val_html))
    }
  }
  contact_html <- if (length(contact_rows) > 0) {
    sprintf('<div class="md-about-grid">%s</div>', paste(contact_rows, collapse = "\n"))
  } else ""

  # Generation info
  gen_info <- sprintf(
    '<div class="md-about-grid">
<div class="md-about-label">Generated</div><div class="md-about-value">%s</div>
<div class="md-about-label">Module</div><div class="md-about-value">MaxDiff v11.2</div>
<div class="md-about-label">Method</div><div class="md-about-value">%s</div>
</div>',
    meta$generated %||% format(Sys.Date(), "%Y-%m-%d"),
    meta$method %||% "N/A")

  # How to read this report
  how_to_read <- '
<div class="md-card" style="margin-top:20px;">
<h3>How to Read This Report</h3>
<div style="font-size:13px;line-height:1.6;color:#334155;">
<p><strong>MaxDiff (Maximum Difference Scaling)</strong> measures how strongly people prefer one thing over another.
Respondents repeatedly chose the best and worst from small sets of items, forcing real trade-offs rather than allowing everything to be rated highly.</p>
<p><strong>Preference Scores</strong> show each item on a 0&ndash;100 scale. Higher means more preferred. Preference shares show the probability of each item being chosen.</p>
<p><strong>Item Analysis</strong> shows how often each item was picked as best vs worst. The BW Score captures the balance.</p>
<p><strong>Head-to-Head</strong> shows win rates when pairs of items are compared directly.</p>
<p><strong>Portfolio (TURF)</strong> identifies the smallest set of items that appeals to the widest audience.</p>
<p><strong>Diagnostics</strong> confirms the statistical model ran correctly. Green badges = good.</p>
</div>
</div>'

  # Methodology section (folded into About)
  method_html <- ""
  if (!is.null(methodology)) {
    method_html <- sprintf('
<div class="md-card" style="margin-top:20px;">
<h3>Methodology</h3>
<div style="font-size:13px;line-height:1.6;color:#334155;">
<p>%s</p>
<p>%s</p>
<p>%s</p>
<div style="margin-top:8px;">%s</div>
</div>
</div>',
      methodology$overview %||% "",
      methodology$method_detail %||% "",
      methodology$design_detail %||% "",
      methodology$assumptions %||% "")
  }

  sprintf(
    '<div class="md-panel" id="panel-about">
<div class="md-card">
<h2>About This Report</h2>
<div class="md-about-section">
%s
<div style="margin-top:16px;">%s</div>
</div>
</div>
%s
%s
</div>',
    contact_html, gen_info, how_to_read, method_html)
}


# ==============================================================================
# PINNED VIEWS PANEL
# ==============================================================================

build_pinned_views_panel <- function() {
  '<div class="md-panel" id="panel-pinned">
<div class="pinned-views-container">
<div class="pinned-header">
<h2>Pinned Views</h2>
<div class="pinned-header-actions">
<button class="md-btn-secondary" onclick="window._mdSaveReport()">Save Report</button>
</div>
</div>
<div id="pinned-cards-container"></div>
<div id="pinned-empty-state" style="text-align:center;padding:60px 20px;color:#94a3b8;">
<div style="font-size:36px;margin-bottom:12px;">&#128204;</div>
<div style="font-size:14px;">No pinned views yet</div>
<div style="font-size:12px;margin-top:6px;">Use the pin button on any tab to capture a view</div>
</div>
<script type="application/json" id="pinned-views-data">[]</script>
</div>
</div>'
}


# ==============================================================================
# HELP OVERLAY
# ==============================================================================

build_md_help_overlay <- function() {
  '
<div class="md-help-overlay" id="md-help-overlay" onclick="window._mdToggleHelp()">
<div class="md-help-card" onclick="event.stopPropagation()">
<h2>Quick Guide</h2>
<ul>
<li><span class="md-help-key">Tab navigation</span>Switch between report sections</li>
<li><span class="md-help-key">Save Report</span>Downloads the report with your insights and pins</li>
<li><span class="md-help-key">Pin button</span>Capture a snapshot of any tab for your presentation</li>
<li><span class="md-help-key">Add Insight</span>Write notes on any tab (supports markdown)</li>
<li><span class="md-help-key">Table sorting</span>Click any column header to sort</li>
<li><span class="md-help-key">Double-click insight</span>Toggle between edit and preview mode</li>
</ul>
<div class="md-help-dismiss">Click anywhere to close</div>
</div>
</div>'
}


# ==============================================================================
# PANEL BUILDERS
# ==============================================================================

build_overview_panel <- function(html_data, tables, charts, insights = NULL) {

  s <- html_data$summary

  # KPI cards
  metrics <- sprintf(
    '<div class="md-metrics">
  <div class="md-metric-card">
    <div class="md-metric-value">%s</div>
    <div class="md-metric-label">Respondents</div>
  </div>
  <div class="md-metric-card">
    <div class="md-metric-value">%s</div>
    <div class="md-metric-label">Items Tested</div>
  </div>
  <div class="md-metric-card">
    <div class="md-metric-value">%s</div>
    <div class="md-metric-label">Method</div>
  </div>
  <div class="md-metric-card">
    <div class="md-metric-value" style="font-size:15px">%s</div>
    <div class="md-metric-label">Top Item</div>
  </div>
</div>',
    s$n_total %||% "0",
    s$n_items %||% "0",
    htmlEscape(s$method_label %||% ""),
    htmlEscape(s$top_item %||% "N/A"))

  # Preference shares chart in overview
  chart_html <- ""
  if (!is.null(charts$preference_chart)) {
    chart_html <- sprintf(
      '<div class="md-chart-container"><div class="md-chart-title">Preference Shares</div>%s</div>',
      charts$preference_chart)
  }

  images_html <- build_panel_images(html_data$images, "overview")
  toolbar <- build_panel_toolbar("overview", insights)

  sprintf(
    '<div class="md-panel active" id="panel-overview">
  <div class="md-section">
    <h2>Overview</h2>
    %s
    %s
    %s
    %s
    %s
  </div>
</div>',
    toolbar, metrics, s$callout %||% "", chart_html, images_html)
}


build_preferences_panel <- function(html_data, tables, charts, insights = NULL) {

  callout <- html_data$preferences$callout %||% ""
  pref_table <- tables$preference_scores %||% ""
  toolbar <- build_panel_toolbar("preferences", insights)

  # Dual view: shares (primary) + utilities (toggle)
  shares_chart <- ""
  utils_chart <- ""
  toggle_btn <- ""

  if (!is.null(charts$preference_chart) || !is.null(charts$preference_detail_chart)) {
    if (!is.null(charts$preference_chart)) {
      shares_chart <- sprintf(
        '<div id="md-pref-shares-view"><div class="md-chart-container"><div class="md-chart-title">Preference Shares</div>%s</div></div>',
        charts$preference_chart)
    }
    if (!is.null(charts$preference_detail_chart)) {
      utils_chart <- sprintf(
        '<div id="md-pref-utils-view" style="display:none;"><div class="md-chart-container"><div class="md-chart-title">Utility Scores (0&ndash;100 Scale)</div>%s</div></div>',
        charts$preference_detail_chart)
    }
    toggle_btn <- '<button id="md-utility-toggle" class="md-btn-secondary" data-showing="shares" style="margin:8px 0;">Show Raw Utilities</button>'
  }

  images_html <- build_panel_images(html_data$images, "preferences")

  sprintf(
    '<div class="md-panel" id="panel-preferences">
  <div class="md-section">
    <h2>Preference Scores</h2>
    %s
    %s
    %s
    %s
    %s
    %s
    %s
  </div>
</div>',
    toolbar, callout, toggle_btn, shares_chart, utils_chart, pref_table, images_html)
}


build_items_panel <- function(html_data, tables, charts, insights = NULL) {

  callout <- html_data$items$callout %||% ""
  count_table <- tables$count_scores %||% ""
  toolbar <- build_panel_toolbar("items", insights)

  diverging_chart <- ""
  if (!is.null(charts$diverging_chart)) {
    diverging_chart <- sprintf(
      '<div class="md-chart-container"><div class="md-chart-title">Best vs Worst Selection Frequency</div>%s</div>',
      charts$diverging_chart)
  }

  # Item Strategy Quadrant
  quadrant_chart <- ""
  if (!is.null(charts$strategy_quadrant)) {
    quadrant_chart <- sprintf(
      '<div class="md-chart-container"><div class="md-chart-title">Item Strategy Quadrant</div>%s</div>',
      charts$strategy_quadrant)
  }

  images_html <- build_panel_images(html_data$images, "items")

  sprintf(
    '<div class="md-panel" id="panel-items">
  <div class="md-section">
    <h2>Item Analysis</h2>
    %s
    %s
    %s
    %s
    <h3>Detailed Count Scores</h3>
    %s
    %s
  </div>
</div>',
    toolbar, callout, diverging_chart, quadrant_chart, count_table, images_html)
}


build_h2h_panel <- function(html_data, tables, charts, insights = NULL) {

  callout <- html_data$head_to_head$callout %||% ""
  h2h_table <- tables$head_to_head %||% ""
  toolbar <- build_panel_toolbar("h2h", insights)

  sprintf(
    '<div class="md-panel" id="panel-h2h">
  <div class="md-section">
    <h2>Head-to-Head Comparison</h2>
    %s
    %s
    %s
  </div>
</div>',
    toolbar, callout, h2h_table)
}


build_turf_panel <- function(html_data, tables, charts, insights = NULL) {

  callout <- html_data$turf$callout %||% ""
  turf_table <- tables$turf %||% ""
  toolbar <- build_panel_toolbar("turf", insights)

  turf_chart <- ""
  if (!is.null(charts$turf_chart)) {
    turf_chart <- sprintf(
      '<div class="md-chart-container"><div class="md-chart-title">Incremental Reach Curve</div>%s</div>',
      charts$turf_chart)
  }

  images_html <- build_panel_images(html_data$images, "turf")

  sprintf(
    '<div class="md-panel" id="panel-turf">
  <div class="md-section">
    <h2>Portfolio Optimization (TURF)</h2>
    %s
    %s
    %s
    <h3>Greedy Selection Order</h3>
    %s
    %s
  </div>
</div>',
    toolbar, callout, turf_chart, turf_table, images_html)
}


build_segments_panel <- function(html_data, tables, charts, insights = NULL) {

  callout <- html_data$segments$callout %||% ""
  seg_table <- tables$segments %||% ""
  toolbar <- build_panel_toolbar("segments", insights)

  seg_chart_html <- ""
  if (!is.null(charts$segment_chart) && nzchar(charts$segment_chart)) {
    seg_chart_html <- sprintf(
      '<div class="md-chart-container"><div class="md-chart-title">Segment Comparison</div>%s</div>',
      charts$segment_chart)
  }

  images_html <- build_panel_images(html_data$images, "segments")

  sprintf(
    '<div class="md-panel" id="panel-segments">
  <div class="md-section">
    <h2>Segment Analysis</h2>
    %s
    %s
    %s
    <h3>Detailed Scores by Segment</h3>
    %s
    %s
  </div>
</div>',
    toolbar, callout, seg_chart_html, seg_table, images_html)
}


build_diagnostics_panel <- function(html_data, tables, charts, insights = NULL) {

  callout <- html_data$diagnostics$callout %||% ""
  diag_table <- tables$diagnostics %||% ""
  toolbar <- build_panel_toolbar("diagnostics", insights)

  # Methodology folded in as collapsible section
  method_section <- ""
  if (!is.null(html_data$methodology)) {
    m <- html_data$methodology
    method_section <- sprintf('
<div class="md-collapsible" style="margin-top:16px;">
  <div class="md-collapsible-header">
    <span class="md-collapse-arrow">&#9654;</span>
    <strong>Methodology &amp; Assumptions</strong>
  </div>
  <div class="md-collapsible-body" style="display:none;">
    <div class="md-card" style="margin-top:8px;font-size:13px;line-height:1.6;">
      <p><strong>What is MaxDiff?</strong> %s</p>
      <p style="margin-top:8px;"><strong>Estimation Method:</strong> %s</p>
      <p style="margin-top:8px;"><strong>Study Design:</strong> %s</p>
      <div style="margin-top:8px;"><strong>Key Assumptions:</strong>%s</div>
    </div>
  </div>
</div>',
      m$overview %||% "", m$method_detail %||% "",
      m$design_detail %||% "", m$assumptions %||% "")
  }

  images_html <- build_panel_images(html_data$images, "diagnostics")

  sprintf(
    '<div class="md-panel" id="panel-diagnostics">
  <div class="md-section">
    <h2>Diagnostics</h2>
    %s
    %s
    %s
    %s
    %s
  </div>
</div>',
    toolbar, callout, diag_table, method_section, images_html)
}


# ==============================================================================
# TURAS META TAGS
# ==============================================================================

build_md_meta <- function(html_data) {
  m <- html_data$meta
  s <- html_data$summary
  tags <- c(
    '<meta name="turas-report-type" content="maxdiff">',
    sprintf('<meta name="turas-generated" content="%s">', m$generated %||% ""),
    sprintf('<meta name="turas-total-n" content="%s">', m$n_total %||% ""),
    sprintf('<meta name="turas-estimation-method" content="%s">', m$method %||% ""),
    sprintf('<meta name="turas-items" content="%s">', m$n_items %||% ""),
    sprintf('<meta name="turas-top-item" content="%s">', htmlEscape(s$top_item %||% "")),
    sprintf('<meta name="turas-source-filename" content="%s">', htmlEscape(m$project_name %||% ""))
  )
  paste(tags, collapse = "\n  ")
}


# ==============================================================================
# CSS
# ==============================================================================

build_md_css <- function(brand, accent) {
  css <- ':root {
  --md-brand: BRAND_TOKEN;
  --md-accent: ACCENT_TOKEN;
  --md-text-primary: #1e293b;
  --md-text-secondary: #64748b;
  --md-bg-surface: #ffffff;
  --md-bg-muted: #f8f9fa;
  --md-border: #e2e8f0;
}
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8f7f5; color: var(--md-text-primary); line-height: 1.6; font-size: 14px; -webkit-font-smoothing: antialiased; }

/* === HEADER === */
.md-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
  color: white;
  padding: 24px 40px 20px;
  border-bottom: 3px solid BRAND_TOKEN;
}
.md-header-inner { display: flex; flex-direction: column; max-width: 1400px; margin: 0 auto; }
.md-header-top { display: flex; align-items: center; justify-content: space-between; }
.md-header-branding { display: flex; align-items: center; gap: 16px; }
.md-header-logo { height: 56px; width: 56px; object-fit: contain; border-radius: 8px; }
.md-header-titles h1 { font-size: 24px; font-weight: 700; letter-spacing: -0.3px; line-height: 1.2; }
.md-header-subtitle { color: rgba(255,255,255,0.5); font-size: 12px; margin-top: 2px; }
.md-header-title { color: #ffffff; font-size: 20px; font-weight: 700; letter-spacing: -0.3px; margin-top: 14px; }
.md-header-prepared { color: rgba(255,255,255,0.65); font-size: 13px; margin-top: 4px; }
.md-header-prepared strong { font-weight: 600; }
.md-header-buttons { display: flex; align-items: center; gap: 10px; }

/* Save button */
.md-save-btn {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 7px 16px; border-radius: 6px; border: 1.5px solid rgba(255,255,255,0.4);
  background: rgba(255,255,255,0.08); color: white; font-size: 13px; font-weight: 600;
  cursor: pointer; transition: all 200ms;
}
.md-save-btn:hover { background: rgba(255,255,255,0.18); border-color: rgba(255,255,255,0.7); }
.md-save-btn svg { flex-shrink: 0; }

/* Badge bar */
.md-badge-bar {
  display: inline-flex; align-items: center; margin-top: 12px;
  border: 1px solid rgba(255,255,255,0.15); border-radius: 6px;
  background: rgba(255,255,255,0.05);
}
.md-badge-item { display: inline-flex; align-items: center; padding: 4px 12px; font-size: 12px; font-weight: 600; color: rgba(255,255,255,0.85); }
.md-badge-item strong { color: #fff; font-weight: 700; }
.md-badge-sep { width: 1px; height: 16px; background: rgba(255,255,255,0.20); flex-shrink: 0; }

/* Help button */
.md-help-btn {
  width: 28px; height: 28px; border-radius: 50%; border: 1.5px solid rgba(255,255,255,0.5);
  background: transparent; color: rgba(255,255,255,0.8); font-size: 14px; font-weight: 700;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
}
.md-help-btn:hover { background: rgba(255,255,255,0.1); }

/* === TAB NAVIGATION === */
.md-tab-nav {
  display: flex; gap: 0; background: white; border-bottom: 2px solid var(--md-border);
  padding: 0 40px; position: sticky; top: 0; z-index: 100; overflow-x: auto;
}
.md-tab-btn {
  background: transparent; border: none; padding: 12px 20px; font-size: 13px; font-weight: 500;
  color: var(--md-text-secondary); cursor: pointer; border-bottom: 3px solid transparent;
  white-space: nowrap; transition: all 200ms;
}
.md-tab-btn:hover { color: var(--md-brand); }
.md-tab-btn.active { color: var(--md-brand); border-bottom-color: var(--md-brand); }

/* Pin count badge */
.pin-count-badge {
  display: inline-block; background: var(--md-accent); color: white;
  font-size: 10px; font-weight: 700; padding: 1px 6px; border-radius: 10px;
  margin-left: 4px; vertical-align: middle;
}

/* === MAIN CONTENT === */
.md-container { max-width: 1400px; margin: 0 auto; padding: 24px 40px 60px; }
.md-panel { display: none; }
.md-panel.active { display: block; }

/* === CARDS === */
.md-card {
  background: white; border-radius: 8px; padding: 24px; margin-bottom: 20px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.06);
}
.md-card h2 { font-size: 16px; font-weight: 600; color: var(--md-text-primary); margin-bottom: 16px; }
.md-card h3 { font-size: 14px; font-weight: 600; color: var(--md-text-primary); margin-bottom: 10px; }

/* === SECTIONS === */
.md-section { margin-bottom: 28px; }
.md-section h2 { font-size: 17px; font-weight: 600; color: var(--md-brand); margin-bottom: 12px; padding-bottom: 6px; border-bottom: 1px solid var(--md-border); }
.md-section h3 { font-size: 14px; font-weight: 600; color: var(--md-text-primary); margin: 16px 0 8px; }

/* === KPI CARDS === */
.md-metrics { display: flex; gap: 16px; margin-bottom: 16px; flex-wrap: wrap; }
.md-metric-card {
  flex: 1; min-width: 140px; background: white; border-radius: 8px; padding: 16px 20px;
  text-align: center; box-shadow: 0 1px 3px rgba(0,0,0,0.06);
}
.md-metric-value { font-size: 24px; font-weight: 700; color: var(--md-brand); }
.md-metric-label { font-size: 11px; color: var(--md-text-secondary); margin-top: 4px; text-transform: uppercase; letter-spacing: 0.3px; }

/* === CHARTS === */
.md-chart-container { background: var(--md-bg-muted); border-radius: 8px; padding: 12px; margin: 12px 0; }
.md-chart-title { font-size: 13px; font-weight: 600; color: var(--md-text-secondary); text-align: center; margin-bottom: 8px; }

/* === TABLES === */
.md-table { width: 100%; border-collapse: collapse; font-size: 13px; margin: 8px 0; }
.md-table-compact { font-size: 12px; }
.md-th { background: var(--md-bg-muted); padding: 8px 12px; text-align: left; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.4px; color: var(--md-text-secondary); border-bottom: 2px solid var(--md-border); cursor: pointer; user-select: none; }
.md-th:hover { background: #eef2f7; }
.md-th .sort-arrow { font-size: 10px; margin-left: 4px; opacity: 0.5; }
.md-th.md-num { text-align: right; }
.md-th.md-label-col { text-align: left; }
.md-td { padding: 7px 12px; border-bottom: 1px solid var(--md-border); vertical-align: middle; }
.md-td.md-num { text-align: right; font-variant-numeric: tabular-nums; }
.md-td.md-label-col { font-weight: 500; }
.md-tr-section td { background: var(--md-bg-muted); font-weight: 600; padding-top: 12px; border-bottom: 1px solid var(--md-border); }

/* Bar in cell */
.md-bar-cell { position: relative; min-height: 22px; display: flex; align-items: center; }
.md-bar-bg { position: absolute; left: 0; top: 0; height: 100%; background: var(--md-brand); opacity: 0.10; border-radius: 3px; }
.md-bar-label { position: relative; z-index: 1; padding-left: 4px; }

/* === STATUS BADGES === */
.md-badge-good { display: inline-block; background: #dcfce7; color: #166534; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 500; }
.md-badge-warn { display: inline-block; background: #fef3c7; color: #92400e; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 500; }
.md-badge-poor { display: inline-block; background: #fee2e2; color: #991b1b; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 500; }

/* === CALLOUTS (three-part pattern) === */
.md-callout { padding: 12px 16px; border-radius: 6px; margin: 12px 0; font-size: 13px; line-height: 1.6; }
.md-callout-result { background: #eff6ff; border-left: 4px solid #3b82f6; }
.md-callout-method { background: #f8fafc; border-left: 4px solid #94a3b8; }
.md-callout-sampling { background: #fffbeb; border-left: 4px solid #f59e0b; }
.md-callout-action { background: #f0fdf4; border-left: 4px solid #22c55e; }

.md-positive { color: #16a34a; }
.md-negative { color: #dc2626; }
.md-empty { color: var(--md-text-secondary); font-style: italic; padding: 12px 0; }

/* === SECONDARY BUTTON === */
.md-btn-secondary {
  display: inline-flex; align-items: center; gap: 4px; padding: 5px 14px;
  border-radius: 5px; border: 1px solid var(--md-border); background: white;
  color: var(--md-text-secondary); font-size: 12px; font-weight: 500; cursor: pointer;
  transition: all 150ms;
}
.md-btn-secondary:hover { background: var(--md-bg-muted); color: var(--md-text-primary); border-color: #cbd5e1; }

/* === PANEL TOOLBAR (pin + insight) === */
.md-panel-toolbar { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }

/* === PIN BUTTON === */
.pin-btn-wrapper { position: relative; }
.pin-btn {
  width: 32px; height: 32px; border-radius: 6px; border: 1px solid var(--md-border);
  background: white; cursor: pointer; display: flex; align-items: center;
  justify-content: center; font-size: 16px; transition: all 150ms;
}
.pin-btn:hover { background: var(--md-bg-muted); border-color: #cbd5e1; }
.pin-btn.pin-flash { background: #dcfce7; border-color: #86efac; }

.pin-mode-popover {
  position: absolute; top: 100%; left: 0; z-index: 200; margin-top: 4px;
  background: white; border: 1px solid var(--md-border); border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1); overflow: hidden; min-width: 200px;
}
.pin-mode-option {
  display: block; width: 100%; padding: 8px 14px; border: none; background: transparent;
  text-align: left; font-size: 12px; color: var(--md-text-primary); cursor: pointer;
}
.pin-mode-option:hover { background: var(--md-bg-muted); }

/* === INSIGHT AREA === */
.insight-area { margin-bottom: 12px; }
.insight-toggle {
  font-size: 12px; color: var(--md-text-secondary); background: transparent;
  border: none; cursor: pointer; padding: 4px 0; font-weight: 500;
}
.insight-toggle:hover { color: var(--md-brand); }
.insight-container {
  position: relative; background: white; border: 1px solid var(--md-border);
  border-left: 3px solid var(--md-accent); border-radius: 6px; padding: 12px 14px;
  margin-top: 6px;
}
.insight-md-editor {
  width: 100%; min-height: 80px; border: 1px solid var(--md-border); border-radius: 4px;
  padding: 8px 10px; font-family: inherit; font-size: 13px; line-height: 1.5;
  resize: vertical; color: var(--md-text-primary);
}
.insight-md-editor:focus { outline: none; border-color: var(--md-brand); }
.insight-md-rendered {
  font-size: 13px; line-height: 1.6; color: var(--md-text-primary); cursor: pointer;
  min-height: 20px;
}
.insight-md-rendered p { margin-bottom: 6px; }
.insight-md-rendered strong { font-weight: 600; }
.insight-md-rendered ul { padding-left: 1.2em; margin: 4px 0; }
.insight-dismiss {
  position: absolute; top: 6px; right: 8px; background: transparent;
  border: none; font-size: 16px; color: #94a3b8; cursor: pointer; line-height: 1;
}
.insight-dismiss:hover { color: #64748b; }

/* === PINNED VIEWS === */
.pinned-views-container { max-width: 1000px; }
.pinned-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; }
.pinned-header h2 { font-size: 17px; font-weight: 600; color: var(--md-brand); }
.pinned-header-actions { display: flex; gap: 8px; }

.pinned-card {
  background: white; border-radius: 8px; padding: 20px; margin-bottom: 16px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.06); border: 1px solid var(--md-border);
}
.pinned-card-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; }
.pinned-card-title { font-size: 14px; font-weight: 600; color: var(--md-text-primary); }
.pinned-card-actions { display: flex; gap: 4px; }
.pinned-action {
  width: 28px; height: 28px; border-radius: 4px; border: 1px solid var(--md-border);
  background: white; cursor: pointer; display: flex; align-items: center;
  justify-content: center; font-size: 12px; color: var(--md-text-secondary);
}
.pinned-action:hover { background: var(--md-bg-muted); }
.pinned-remove:hover { background: #fee2e2; color: #dc2626; border-color: #fecaca; }
.pinned-insight {
  background: #f8fafc; border-left: 3px solid var(--md-accent);
  padding: 10px 14px; border-radius: 4px; margin-bottom: 12px; font-size: 13px;
}
.pinned-chart { margin-bottom: 12px; }
.pinned-chart svg { width: 100%; height: auto; }
.pinned-table { overflow-x: auto; }
.pinned-table .md-table { font-size: 12px; }

/* === COLLAPSIBLE === */
.md-collapsible-header {
  cursor: pointer; padding: 8px 12px; background: var(--md-bg-muted);
  border-radius: 6px; font-size: 13px; color: var(--md-text-primary);
  display: flex; align-items: center; gap: 8px;
}
.md-collapsible-header:hover { background: #eef2f7; }
.md-collapse-arrow { font-size: 10px; color: var(--md-text-secondary); }
.md-collapsible-body { padding: 0 12px; }

/* === TOAST === */
.md-toast {
  position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%) translateY(20px);
  background: #1e293b; color: white; padding: 10px 24px; border-radius: 8px;
  font-size: 13px; font-weight: 500; opacity: 0; transition: all 300ms;
  z-index: 2000; pointer-events: none;
}
.md-toast-show { opacity: 1; transform: translateX(-50%) translateY(0); }

/* === H2H HEATMAP TABLE === */
.md-h2h-cell { text-align: center; font-size: 12px; font-variant-numeric: tabular-nums; }
.md-h2h-win { background: #dcfce7; color: #166534; }
.md-h2h-lose { background: #fee2e2; color: #991b1b; }
.md-h2h-neutral { background: #f1f5f9; color: #64748b; }
.md-h2h-self { background: #e2e8f0; color: #94a3b8; }

/* === ABOUT PAGE === */
.md-about-section { max-width: 700px; }
.md-about-grid { display: grid; grid-template-columns: 120px 1fr; gap: 8px 16px; margin-bottom: 16px; }
.md-about-label { font-size: 12px; font-weight: 500; color: var(--md-text-secondary); text-transform: uppercase; letter-spacing: 0.05em; }
.md-about-value { font-size: 13px; color: #334155; }
.md-about-value a { color: var(--md-brand); text-decoration: none; }
.md-about-value a:hover { text-decoration: underline; }

/* === HELP OVERLAY === */
.md-help-overlay {
  display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.5);
  z-index: 1000; align-items: center; justify-content: center;
}
.md-help-overlay.open { display: flex; }
.md-help-card {
  background: white; border-radius: 12px; padding: 32px; max-width: 500px; width: 90%;
  box-shadow: 0 20px 60px rgba(0,0,0,0.2);
}
.md-help-card h2 { font-size: 18px; font-weight: 700; color: #1e293b; margin-bottom: 16px; }
.md-help-card ul { list-style: none; padding: 0; }
.md-help-card li { padding: 6px 0; font-size: 13px; color: #334155; display: flex; gap: 8px; }
.md-help-key { font-weight: 600; color: var(--md-brand); min-width: 140px; flex-shrink: 0; }
.md-help-dismiss { text-align: center; margin-top: 20px; font-size: 12px; color: #94a3b8; }

/* === EMBEDDED IMAGES === */
.md-image-container { margin: 16px 0; text-align: center; }
.md-embedded-image { max-width: 100%; height: auto; border-radius: 6px; box-shadow: 0 1px 4px rgba(0,0,0,0.08); }
.md-image-caption { font-size: 12px; color: var(--md-text-secondary); margin-top: 6px; font-style: italic; }

/* === CUSTOM SLIDES === */
.md-slide-content { font-size: 14px; line-height: 1.7; color: var(--md-text-primary); }

/* === FOOTER === */
.md-footer { text-align: center; padding: 20px 40px; color: #94a3b8; font-size: 11px; border-top: 1px solid var(--md-border); }

/* === RESPONSIVE === */
@media (max-width: 768px) {
  .md-header, .md-tab-nav, .md-container, .md-footer { padding-left: 16px; padding-right: 16px; }
  .md-metrics { flex-direction: column; }
  .md-tab-btn { padding: 8px 10px; font-size: 12px; }
}'

  css <- gsub("BRAND_TOKEN", brand, css, fixed = TRUE)
  css <- gsub("ACCENT_TOKEN", accent, css, fixed = TRUE)
  css
}


# ==============================================================================
# PRINT CSS
# ==============================================================================

build_md_print_css <- function() {
  '@media print {
  .md-tab-nav { display: none !important; }
  .md-help-overlay { display: none !important; }
  .md-help-btn, .md-save-btn { display: none !important; }
  .md-panel-toolbar { display: none !important; }
  .insight-area { display: none !important; }
  .md-panel { display: block !important; page-break-inside: avoid; margin-bottom: 20px; }
  .md-header { background: white !important; color: var(--md-brand) !important; border-bottom: 2px solid var(--md-brand); }
  .md-header-title, .md-header-titles h1 { color: var(--md-brand) !important; }
  .md-header-prepared, .md-header-subtitle { color: #64748b !important; }
  .md-badge-bar { border-color: #e2e8f0 !important; }
  .md-badge-item { color: #334155 !important; }
  .md-badge-sep { background: #e2e8f0 !important; }
  body { background: white; }
  .md-container { max-width: 100%; padding: 0 20px; }
  #panel-pinned { display: none !important; }
  #panel-simulator { display: none !important; }
}'
}
