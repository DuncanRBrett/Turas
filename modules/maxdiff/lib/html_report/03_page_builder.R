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

# Source the shared design system (TURAS_ROOT-aware)
local({
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) turas_root <- getwd()
  ds_dir <- file.path(turas_root, "modules", "shared", "lib", "design_system")
  if (!dir.exists(ds_dir)) ds_dir <- file.path("modules", "shared", "lib", "design_system")
  if (!exists("turas_base_css", mode = "function") && dir.exists(ds_dir)) {
    source(file.path(ds_dir, "design_tokens.R"), local = FALSE)
    source(file.path(ds_dir, "font_embed.R"), local = FALSE)
    source(file.path(ds_dir, "base_css.R"), local = FALSE)
  }
  # Source callout registry
  callout_dir <- file.path(turas_root, "modules", "shared", "lib", "callouts")
  if (!dir.exists(callout_dir)) callout_dir <- file.path("modules", "shared", "lib", "callouts")
  if (!exists("turas_callout", mode = "function") && dir.exists(callout_dir)) {
    source(file.path(callout_dir, "callout_registry.R"), local = FALSE)
  }
})


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
  pin_icon <- "&#x1F4CC;"
  sprintf(
    '<div class="pin-btn-wrapper">
  <button class="pin-btn" data-panel="%s" onclick="window._mdTogglePin(\'%s\')" title="Pin to Views">%s</button>
  <div class="pin-mode-popover" style="display:none;">
    <button class="pin-mode-option" onclick="window._mdExecutePin(\'%s\',\'all\')">Table + Chart + Insight</button>
    <button class="pin-mode-option" onclick="window._mdExecutePin(\'%s\',\'chart_insight\')">Chart + Insight</button>
    <button class="pin-mode-option" onclick="window._mdExecutePin(\'%s\',\'table_insight\')">Table + Insight</button>
  </div>
</div>',
    panel_id, panel_id, pin_icon, panel_id, panel_id, panel_id
  )
}


# ==============================================================================
# PANEL TOOLBAR (Pin + Insight buttons for each panel)
# ==============================================================================

build_panel_toolbar <- function(panel_id, insights_list = NULL) {
  export_btn <- sprintf(
    '<button class="md-export-btn" onclick="window._mdExportPanel(\'%s\')" title="Export table data to Excel"><svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M2 14h12M8 2v9M4 7l4 4 4-4"/></svg> Export Excel</button>',
    panel_id)
  paste0(
    '<div class="md-panel-toolbar">',
    build_pin_button(panel_id),
    export_btn,
    '</div>',
    build_insight_area(panel_id, insights_list)
  )
}


# ==============================================================================
# SEGMENT DROPDOWN BUILDER
# ==============================================================================

#' Build a segment filter dropdown for an analytical panel
#'
#' @param panel_id Character. Panel identifier for data binding
#' @param segment_filter List. Output of transform_segment_filter_options()
#'
#' @return HTML string with a dropdown, or "" if no segments
#' @keywords internal
build_segment_dropdown <- function(panel_id, segment_filter) {

  if (is.null(segment_filter) || is.null(segment_filter$variables) || length(segment_filter$variables) == 0) {
    return("")
  }

  options_html <- '<option value="all" selected>All Respondents</option>'

  for (seg_var in names(segment_filter$variables)) {
    sv <- segment_filter$variables[[seg_var]]
    group_label <- gsub("_", " ", seg_var)
    options_html <- paste0(options_html,
      sprintf('\n<optgroup label="%s">', htmlEscape(group_label)))
    for (lvl in sv$levels) {
      n_text <- if (!is.na(lvl$n)) sprintf(" (n=%s)", format(lvl$n, big.mark = ",")) else ""
      options_html <- paste0(options_html,
        sprintf('\n<option value="%s:%s">%s%s</option>',
                htmlEscape(seg_var), htmlEscape(lvl$value),
                htmlEscape(lvl$label), n_text))
    }
    options_html <- paste0(options_html, '\n</optgroup>')
  }

  sprintf(
    '<div class="md-segment-filter">
  <label>Segment:
    <select class="md-segment-select" data-panel="%s" onchange="window._mdFilterSegment(this)">%s</select>
  </label>
</div>',
    panel_id, options_html)
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
  has_turf <- !is.null(html_data$turf)
  has_simulator <- !is.null(simulator_html) && nzchar(simulator_html)
  segment_filter <- html_data$segment_filter

  # Build panels (segment dropdown passed to analytical panels)
  overview_panel   <- build_overview_panel(html_data, tables, charts, insights)
  pref_panel       <- if (has_preferences) build_preferences_panel(html_data, tables, charts, insights, segment_filter) else ""
  items_panel      <- if (has_items) build_items_panel(html_data, tables, charts, insights, segment_filter) else ""
  h2h_panel        <- if (has_h2h) build_h2h_panel(html_data, tables, charts, insights, segment_filter) else ""
  turf_panel       <- if (has_turf) build_turf_panel(html_data, tables, charts, insights) else ""
  diag_panel       <- build_diagnostics_panel(html_data, tables, charts, insights)
  about_panel      <- build_md_about_panel(html_data$meta, config, html_data$methodology)
  help_overlay     <- build_md_help_overlay()
  pinned_panel     <- build_pinned_views_panel()

  # Simulator panel (embedded iframe)
  # Only show H2H + Portfolio tabs in simulator; all other tabs belong in main menu
  simulator_panel <- ""
  if (has_simulator) {
    # Inject CSS+JS into simulator to hide unwanted tabs and default to H2H
    # Pins tab removed from simulator HTML — pins forward to main report via postMessage
    sim_hide_injection <- paste0(
      '<style>',
      '[data-tab="overview"],[data-tab="shares"],[data-tab="diagnostics"],[data-tab="about"]{display:none!important}',
      '#panel-overview,#panel-shares,#panel-diagnostics,#panel-about{display:none!important}',
      '</style>',
      '<script>',
      'window.addEventListener("load",function(){',
      'setTimeout(function(){',
      'var h2hBtn=document.querySelector(\'[data-tab="h2h"]\');',
      'if(h2hBtn){h2hBtn.click();}',
      '},200);',
      '});',
      '</script>'
    )
    # Insert injection before </head> in simulator HTML
    sim_modified <- sub("</head>", paste0(sim_hide_injection, "</head>"), simulator_html, fixed = TRUE)
    sim_escaped <- gsub("&", "&amp;", sim_modified, fixed = TRUE)
    sim_escaped <- gsub("\"", "&quot;", sim_escaped, fixed = TRUE)
    simulator_panel <- sprintf(
      '<div class="md-panel" id="panel-simulator">
<iframe srcdoc="%s" style="width:100%%;border:none;border-radius:8px;min-height:85vh;" onload="this.style.height=(this.contentWindow.document.body.scrollHeight+40)+\'px\'"></iframe>
</div>', sim_escaped)
  }

  # Added Slides panel — config-imported slides + interactive add/edit
  slides_df <- config$slides %||% config$custom_slides %||% NULL
  imported_slides_html <- ""
  if (!is.null(slides_df) && is.data.frame(slides_df) && nrow(slides_df) > 0) {
    slide_blocks <- character()
    for (i in seq_len(nrow(slides_df))) {
      slide <- as.list(slides_df[i, , drop = FALSE])
      slide_blocks <- c(slide_blocks, build_custom_slide_panel(slide, config))
    }
    imported_slides_html <- paste(slide_blocks, collapse = "\n<hr style='border:none;border-top:1px solid #e2e8f0;margin:24px 0;'/>\n")
  }
  added_slides_panel <- sprintf(
    '<div class="md-panel" id="panel-added-slides">
  <div class="md-section">
    <h2>Added Slides</h2>
    <button class="md-btn-secondary" onclick="window._mdAddSlide()" style="margin-bottom:16px;">+ Add Slide</button>
    %s
    <div id="md-slides-container"></div>
    <p id="md-slides-empty" class="md-empty" style="text-align:center;color:#94a3b8;padding:20px 0;">No slides added yet. Click the button above to create a slide with markdown and images.</p>
  </div>
</div>', imported_slides_html)

  # Build tab navigation
  tab_buttons <- '<button class="md-tab-btn active" data-tab="overview">Overview</button>'
  if (has_preferences) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="preferences">Preference Scores</button>')
  if (has_items) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="items">Item Analysis</button>')
  if (has_h2h) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="h2h">Head-to-Head</button>')
  if (has_turf) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="turf">Portfolio (TURF)</button>')
  tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="diagnostics">Diagnostics</button>')
  if (has_simulator) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="simulator">Simulator</button>')
  # Added Slides tab — always present; shows custom slides or empty state
  tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="added-slides">Added Slides</button>')
  tab_buttons <- paste0(tab_buttons,
    '\n<button class="md-tab-btn" data-tab="pinned">Pinned Views <span class="pin-count-badge" id="pin-count-badge" style="display:none;">0</span></button>',
    '\n<button class="md-tab-btn" data-tab="about">About</button>')

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
    diag_panel,
    simulator_panel,
    added_slides_panel,
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

  # How to read this report — pull from registry for consistency
  how_to_read <- tryCatch(
    {
      callout_html <- turas_callout("maxdiff", "how_to_read")
      if (nzchar(callout_html)) {
        sprintf('<div class="md-card" style="margin-top:20px;">%s</div>', callout_html)
      } else ""
    },
    error = function(e) ""
  )

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
<div id="md-pinned-toolbar" class="pinned-header-actions">
<button class="md-btn-secondary" onclick="TurasPins.addSection()">&#x2795; Add Section</button>
<button class="md-export-btn" onclick="window._mdExportAllPinned()"><svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M2 14h12M8 2v9M4 7l4 4 4-4"/></svg> Export All as PNG</button>
<button class="md-btn-secondary" onclick="window._mdSaveReport()">Save Report</button>
</div>
</div>
<div id="md-pinned-cards-container"></div>
<div id="md-pinned-empty" style="text-align:center;padding:60px 20px;color:#94a3b8;">
<div style="font-size:36px;margin-bottom:12px;">&#128204;</div>
<div style="font-size:14px;">No pinned views yet.</div>
<div style="font-size:12px;margin-top:6px;">Use the pin button on any tab to capture a view</div>
</div>
<script type="application/json" id="md-pinned-views-data">[]</script>
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

  # SVG icons for stat cards
  icon_items <- '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>'
  icon_respondents <- '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>'
  icon_top <- '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>'
  icon_range <- '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M18 20V10"/><path d="M12 20V4"/><path d="M6 20v-6"/></svg>'

  # Info callout at top — dynamic summary + registry "how to read"
  info_callout <- sprintf(
    '<div class="md-callout md-callout-method" style="margin-bottom:16px;">
<strong>MaxDiff Analysis</strong> &mdash; %s items evaluated by %s respondents using %s estimation.
This report presents preference shares, item rankings, and comparative analysis.</div>',
    s$n_items %||% "0",
    format(as.integer(s$n_total %||% 0), big.mark = ","),
    htmlEscape(s$method_label %||% ""))
  # Registry callout: How to Read (collapsible)
  how_to_read_callout <- tryCatch(
    turas_callout("maxdiff", "how_to_read", collapsed = TRUE),
    error = function(e) ""
  )
  info_callout <- paste0(info_callout, "\n", how_to_read_callout)

  # Build 4 stat cards: Items, Respondents, Top Share, Share Range
  top_share_val <- if (!is.null(s$top_share) && !is.na(s$top_share)) paste0(s$top_share, "%") else "N/A"
  share_range_val <- if (!is.null(s$share_range) && !is.na(s$share_range)) paste0(s$share_range, "pp") else "N/A"

  card1 <- sprintf(
    '<div class="md-stat-card"><div class="md-stat-icon">%s</div><div class="md-stat-body"><div class="md-stat-value">%s</div><div class="md-stat-label">Items Tested</div></div></div>',
    icon_items, s$n_items %||% "0")

  card2 <- sprintf(
    '<div class="md-stat-card"><div class="md-stat-icon">%s</div><div class="md-stat-body"><div class="md-stat-value">%s</div><div class="md-stat-label">Respondents</div></div></div>',
    icon_respondents, format(as.integer(s$n_total %||% 0), big.mark = ","))

  card3 <- sprintf(
    '<div class="md-stat-card"><div class="md-stat-icon">%s</div><div class="md-stat-body"><div class="md-stat-value">%s</div><div class="md-stat-label">Top Share</div><div class="md-stat-sub">%s</div></div></div>',
    icon_top, top_share_val, htmlEscape(s$top_item %||% ""))

  card4 <- sprintf(
    '<div class="md-stat-card"><div class="md-stat-icon">%s</div><div class="md-stat-body"><div class="md-stat-value">%s</div><div class="md-stat-label">Share Range</div><div class="md-stat-sub">Top &ndash; Bottom</div></div></div>',
    icon_range, share_range_val)

  metrics <- sprintf('<div class="md-stat-grid">%s%s%s%s</div>', card1, card2, card3, card4)

  # TOP ITEMS bar chart
  chart_html <- ""
  if (!is.null(charts$preference_chart)) {
    chart_html <- sprintf(
      '<div class="md-chart-container"><div class="md-chart-title">Top Items</div>%s</div>',
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
    toolbar, info_callout, metrics, chart_html, images_html)
}


build_preferences_panel <- function(html_data, tables, charts, insights = NULL, segment_filter = NULL) {

  callout <- html_data$preferences$callout %||% ""
  pref_table <- tables$preference_scores %||% ""
  seg_pref_container <- tables$seg_pref_container %||% ""
  toolbar <- build_panel_toolbar("preferences", insights)
  seg_dropdown <- build_segment_dropdown("preferences", segment_filter)

  pin_icon <- "&#x1F4CC;"

  # Sub-tab 1: Preference Shares — chart wrapped in segment container
  shares_chart_html <- ""
  if (!is.null(charts$preference_chart)) {
    main_chart_block <- sprintf(
      '<div class="md-chart-wrapper"><button class="md-chart-pin-btn" onclick="window._mdPinChart(this,\'Preference Shares\')" title="Pin chart">%s</button><div class="md-chart-container"><div class="md-chart-title">Preference Shares</div>%s</div></div>',
      pin_icon, charts$preference_chart)

    # Build per-segment chart variants
    seg_chart_divs <- ""
    if (!is.null(charts$segment_preference_charts) && length(charts$segment_preference_charts) > 0) {
      seg_parts <- character()
      for (seg_key in names(charts$segment_preference_charts)) {
        entry <- charts$segment_preference_charts[[seg_key]]
        seg_svg <- entry$svg
        seg_n <- entry$n
        n_label <- if (!is.na(seg_n)) sprintf(
          '<div class="md-segment-n-label" style="text-align:right;font-size:13px;color:#64748b;margin-bottom:4px;font-weight:500;">n = %s</div>',
          format(as.integer(seg_n), big.mark = ",")) else ""
        seg_chart_block <- sprintf(
          '<div class="md-chart-wrapper"><div class="md-chart-container"><div class="md-chart-title">Preference Shares</div>%s</div></div>',
          seg_svg)
        seg_parts <- c(seg_parts, sprintf(
          '<div data-segment="%s" style="display:none;">%s%s</div>',
          htmlEscape(seg_key), n_label, seg_chart_block))
      }
      seg_chart_divs <- paste(seg_parts, collapse = "\n")
    }

    # Wrap main + segment charts in a segment-filterable container
    if (nzchar(seg_chart_divs)) {
      shares_chart_html <- sprintf(
        '<div class="md-segment-tables"><div data-segment="all" style="display:block;">%s</div>%s</div>',
        main_chart_block, seg_chart_divs)
    } else {
      shares_chart_html <- main_chart_block
    }
  }

  # Sub-tab 2: Individual Utility — bar chart and distribution chart in separate segment containers
  utils_chart_html <- ""
  dist_chart_html <- ""
  if (!is.null(charts$preference_detail_chart)) {
    main_utils_block <- sprintf(
      '<div class="md-chart-wrapper"><button class="md-chart-pin-btn" onclick="window._mdPinChart(this,\'Utility Scores\')" title="Pin chart">%s</button><div class="md-chart-container"><div class="md-chart-title">Utility Scores (0&ndash;100 Scale)</div>%s</div></div>',
      pin_icon, charts$preference_detail_chart)

    # Build per-segment utility bar chart variants
    seg_util_divs <- ""
    if (!is.null(charts$segment_utility_charts) && length(charts$segment_utility_charts) > 0) {
      seg_parts <- character()
      for (seg_key in names(charts$segment_utility_charts)) {
        entry <- charts$segment_utility_charts[[seg_key]]
        n_label <- if (!is.na(entry$n)) sprintf(
          '<div class="md-segment-n-label" style="text-align:right;font-size:13px;color:#64748b;margin-bottom:4px;font-weight:500;">n = %s</div>',
          format(as.integer(entry$n), big.mark = ",")) else ""
        seg_chart_block <- sprintf(
          '<div class="md-chart-wrapper"><div class="md-chart-container"><div class="md-chart-title">Utility Scores (0&ndash;100 Scale)</div>%s</div></div>',
          entry$svg)
        seg_parts <- c(seg_parts, sprintf(
          '<div data-segment="%s" style="display:none;">%s%s</div>',
          htmlEscape(seg_key), n_label, seg_chart_block))
      }
      seg_util_divs <- paste(seg_parts, collapse = "\n")
    }

    # Wrap utility bar chart in segment container
    if (nzchar(seg_util_divs)) {
      utils_chart_html <- sprintf(
        '<div class="md-segment-tables"><div data-segment="all" style="display:block;">%s</div>%s</div>',
        main_utils_block, seg_util_divs)
    } else {
      utils_chart_html <- main_utils_block
    }

    # Distribution chart — separate segment container
    if (!is.null(charts$utility_distribution)) {
      main_dist_block <- sprintf(
        '<div class="md-chart-wrapper"><button class="md-chart-pin-btn" onclick="window._mdPinChart(this,\'Utility Distributions\')" title="Pin chart">%s</button><div class="md-chart-container"><div class="md-chart-title">Individual Utility Distributions</div>%s</div></div>',
        pin_icon, charts$utility_distribution)

      seg_dist_divs <- ""
      if (!is.null(charts$segment_distribution_charts) && length(charts$segment_distribution_charts) > 0) {
        seg_parts <- character()
        for (seg_key in names(charts$segment_distribution_charts)) {
          entry <- charts$segment_distribution_charts[[seg_key]]
          n_label <- if (!is.na(entry$n)) sprintf(
            '<div class="md-segment-n-label" style="text-align:right;font-size:13px;color:#64748b;margin-bottom:4px;font-weight:500;">n = %s</div>',
            format(as.integer(entry$n), big.mark = ",")) else ""
          seg_chart_block <- sprintf(
            '<div class="md-chart-wrapper"><div class="md-chart-container"><div class="md-chart-title">Individual Utility Distributions</div>%s</div></div>',
            entry$svg)
          seg_parts <- c(seg_parts, sprintf(
            '<div data-segment="%s" style="display:none;">%s%s</div>',
            htmlEscape(seg_key), n_label, seg_chart_block))
        }
        seg_dist_divs <- paste(seg_parts, collapse = "\n")
      }

      if (nzchar(seg_dist_divs)) {
        dist_chart_html <- sprintf(
          '<div class="md-segment-tables"><div data-segment="all" style="display:block;">%s</div>%s</div>',
          main_dist_block, seg_dist_divs)
      } else {
        dist_chart_html <- main_dist_block
      }
    }
  }

  # Sub-tab 3: Anchored MaxDiff — chart wrapped in segment container with per-segment anchor charts
  anchor_chart_html <- ""
  if (!is.null(charts$anchor_threshold) && nzchar(charts$anchor_threshold)) {
    main_anchor_block <- sprintf(
      '<div class="md-chart-wrapper"><button class="md-chart-pin-btn" onclick="window._mdPinChart(this,\'Anchor Threshold\')" title="Pin chart">%s</button><div class="md-chart-container"><div class="md-chart-title">Anchored MaxDiff &mdash; Must-Have Threshold</div>%s</div></div>',
      pin_icon, charts$anchor_threshold)

    # Build per-segment anchor threshold chart variants
    seg_anchor_divs <- ""
    if (!is.null(charts$segment_anchor_charts) && length(charts$segment_anchor_charts) > 0) {
      seg_parts <- character()
      for (seg_key in names(charts$segment_anchor_charts)) {
        entry <- charts$segment_anchor_charts[[seg_key]]
        n_label <- if (!is.na(entry$n)) sprintf(
          '<div class="md-segment-n-label" style="text-align:right;font-size:13px;color:#64748b;margin-bottom:4px;font-weight:500;">n = %s</div>',
          format(as.integer(entry$n), big.mark = ",")) else ""
        seg_chart_block <- sprintf(
          '<div class="md-chart-wrapper"><div class="md-chart-container"><div class="md-chart-title">Anchored MaxDiff &mdash; Must-Have Threshold</div>%s</div></div>',
          entry$svg)
        seg_parts <- c(seg_parts, sprintf(
          '<div data-segment="%s" style="display:none;">%s%s</div>',
          htmlEscape(seg_key), n_label, seg_chart_block))
      }
      seg_anchor_divs <- paste(seg_parts, collapse = "\n")
    }

    # Wrap in segment-filterable container
    if (nzchar(seg_anchor_divs)) {
      anchor_chart_html <- sprintf(
        '<div class="md-segment-tables"><div data-segment="all" style="display:block;">%s</div>%s</div>',
        main_anchor_block, seg_anchor_divs)
    } else {
      anchor_chart_html <- main_anchor_block
    }
  }

  images_html <- build_panel_images(html_data$images, "preferences")

  # Determine which sub-tabs to show
  has_shares <- !is.null(charts$preference_chart) || nzchar(pref_table)
  has_utility <- !is.null(charts$preference_detail_chart) || !is.null(charts$utility_distribution)
  has_anchor <- !is.null(charts$anchor_threshold) && nzchar(charts$anchor_threshold)

  # Build sub-tab nav
  subtab_nav <- '<div class="md-subtab-nav">'
  subtab_nav <- paste0(subtab_nav,
    '<button class="md-subtab-btn active" data-group="pref" data-subtab="shares" onclick="window._mdSwitchSubtab(this)">Preference Shares</button>')
  if (has_utility) {
    subtab_nav <- paste0(subtab_nav,
      '<button class="md-subtab-btn" data-group="pref" data-subtab="utility" onclick="window._mdSwitchSubtab(this)">Individual Utility</button>')
  }
  if (has_anchor) {
    subtab_nav <- paste0(subtab_nav,
      '<button class="md-subtab-btn" data-group="pref" data-subtab="anchor" onclick="window._mdSwitchSubtab(this)">Anchored MaxDiff</button>')
  }
  subtab_nav <- paste0(subtab_nav, '</div>')

  # Build sub-panels — each includes segment table container for segment filtering
  shares_panel <- sprintf(
    '<div class="md-subpanel active" data-group="pref" data-subpanel="shares">%s%s</div>',
    shares_chart_html, pref_table)

  utility_panel <- ""
  if (has_utility) {
    utility_panel <- sprintf(
      '<div class="md-subpanel" data-group="pref" data-subpanel="utility">%s%s%s</div>',
      utils_chart_html, dist_chart_html, seg_pref_container)
  }

  anchor_panel <- ""
  if (has_anchor) {
    anchor_panel <- sprintf(
      '<div class="md-subpanel" data-group="pref" data-subpanel="anchor">%s%s</div>',
      anchor_chart_html, seg_pref_container)
  }

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
    %s
  </div>
</div>',
    toolbar, seg_dropdown, callout, subtab_nav, shares_panel, utility_panel, anchor_panel, images_html)
}


build_items_panel <- function(html_data, tables, charts, insights = NULL, segment_filter = NULL) {

  callout <- html_data$items$callout %||% ""
  count_table <- tables$count_scores %||% ""
  seg_counts_container <- tables$seg_counts_container %||% ""
  toolbar <- build_panel_toolbar("items", insights)
  seg_dropdown <- build_segment_dropdown("items", segment_filter)

  pin_icon <- "&#x1F4CC;"

  # Build diverging chart wrapped in segment container
  diverging_chart_html <- ""
  if (!is.null(charts$diverging_chart)) {
    main_div_block <- sprintf(
      '<div class="md-chart-wrapper"><button class="md-chart-pin-btn" onclick="window._mdPinChart(this,\'Best vs Worst\')" title="Pin chart">%s</button><div class="md-chart-container"><div class="md-chart-title">Best vs Worst Selection Frequency</div>%s</div></div>',
      pin_icon, charts$diverging_chart)

    seg_div_parts <- ""
    if (!is.null(charts$segment_diverging_charts) && length(charts$segment_diverging_charts) > 0) {
      parts <- character()
      for (sk in names(charts$segment_diverging_charts)) {
        entry <- charts$segment_diverging_charts[[sk]]
        n_label <- if (!is.na(entry$n)) sprintf(
          '<div style="text-align:right;font-size:13px;color:#64748b;margin-bottom:4px;font-weight:500;">n = %s</div>',
          format(as.integer(entry$n), big.mark = ",")) else ""
        seg_block <- sprintf(
          '<div class="md-chart-wrapper"><div class="md-chart-container"><div class="md-chart-title">Best vs Worst Selection Frequency</div>%s</div></div>',
          entry$svg)
        parts <- c(parts, sprintf(
          '<div data-segment="%s" style="display:none;">%s%s</div>',
          htmlEscape(sk), n_label, seg_block))
      }
      seg_div_parts <- paste(parts, collapse = "\n")
    }

    if (nzchar(seg_div_parts)) {
      diverging_chart_html <- sprintf(
        '<div class="md-segment-tables"><div data-segment="all" style="display:block;">%s</div>%s</div>',
        main_div_block, seg_div_parts)
    } else {
      diverging_chart_html <- main_div_block
    }
  }

  # Build strategy quadrant chart wrapped in segment container
  quadrant_chart_html <- ""
  if (!is.null(charts$strategy_quadrant)) {
    main_quad_block <- sprintf(
      '<div class="md-chart-wrapper"><button class="md-chart-pin-btn" onclick="window._mdPinChart(this,\'Strategy Quadrant\')" title="Pin chart">%s</button><div class="md-chart-container"><div class="md-chart-title">Item Strategy Quadrant</div>%s</div></div>',
      pin_icon, charts$strategy_quadrant)

    seg_quad_parts <- ""
    if (!is.null(charts$segment_quadrant_charts) && length(charts$segment_quadrant_charts) > 0) {
      parts <- character()
      for (sk in names(charts$segment_quadrant_charts)) {
        entry <- charts$segment_quadrant_charts[[sk]]
        n_label <- if (!is.na(entry$n)) sprintf(
          '<div style="text-align:right;font-size:13px;color:#64748b;margin-bottom:4px;font-weight:500;">n = %s</div>',
          format(as.integer(entry$n), big.mark = ",")) else ""
        seg_block <- sprintf(
          '<div class="md-chart-wrapper"><div class="md-chart-container"><div class="md-chart-title">Item Strategy Quadrant</div>%s</div></div>',
          entry$svg)
        parts <- c(parts, sprintf(
          '<div data-segment="%s" style="display:none;">%s%s</div>',
          htmlEscape(sk), n_label, seg_block))
      }
      seg_quad_parts <- paste(parts, collapse = "\n")
    }

    if (nzchar(seg_quad_parts)) {
      quadrant_chart_html <- sprintf(
        '<div class="md-segment-tables"><div data-segment="all" style="display:block;">%s</div>%s</div>',
        main_quad_block, seg_quad_parts)
    } else {
      quadrant_chart_html <- main_quad_block
    }
  }

  images_html <- build_panel_images(html_data$images, "items")

  # Registry callout: Item Analysis (reading the table)
  count_callout <- tryCatch(
    turas_callout("maxdiff", "item_analysis"),
    error = function(e) ""
  )

  has_diverging <- nzchar(diverging_chart_html)
  has_quadrant <- nzchar(quadrant_chart_html)

  # Build sub-tab nav
  subtab_nav <- '<div class="md-subtab-nav">'
  subtab_nav <- paste0(subtab_nav,
    '<button class="md-subtab-btn active" data-group="items" data-subtab="bw" onclick="window._mdSwitchSubtab(this)">Best vs Worst</button>')
  if (has_quadrant) {
    subtab_nav <- paste0(subtab_nav,
      '<button class="md-subtab-btn" data-group="items" data-subtab="quadrant" onclick="window._mdSwitchSubtab(this)">Strategy Quadrant</button>')
  }
  subtab_nav <- paste0(subtab_nav,
    '<button class="md-subtab-btn" data-group="items" data-subtab="detailed" onclick="window._mdSwitchSubtab(this)">Detailed Scores</button>')
  subtab_nav <- paste0(subtab_nav, '</div>')

  # Sub-panels — charts in segment containers, plus segment table fallback
  bw_panel <- sprintf(
    '<div class="md-subpanel active" data-group="items" data-subpanel="bw">%s%s</div>',
    diverging_chart_html, seg_counts_container)

  quadrant_panel <- ""
  if (has_quadrant) {
    quadrant_panel <- sprintf(
      '<div class="md-subpanel" data-group="items" data-subpanel="quadrant">%s%s</div>',
      quadrant_chart_html, seg_counts_container)
  }

  detailed_panel <- sprintf(
    '<div class="md-subpanel" data-group="items" data-subpanel="detailed">%s%s</div>',
    count_callout, count_table)

  sprintf(
    '<div class="md-panel" id="panel-items">
  <div class="md-section">
    <h2>Item Analysis</h2>
    %s
    %s
    %s
    %s
    %s
    %s
    %s
    %s
  </div>
</div>',
    toolbar, seg_dropdown, callout, subtab_nav, bw_panel, quadrant_panel, detailed_panel, images_html)
}


build_h2h_panel <- function(html_data, tables, charts, insights = NULL, segment_filter = NULL) {

  callout <- html_data$head_to_head$callout %||% ""
  h2h_table <- tables$head_to_head %||% ""
  toolbar <- build_panel_toolbar("h2h", insights)
  seg_dropdown <- build_segment_dropdown("h2h", segment_filter)

  sprintf(
    '<div class="md-panel" id="panel-h2h">
  <div class="md-section">
    <h2>Head-to-Head Comparison</h2>
    %s
    %s
    %s
    %s
  </div>
</div>',
    toolbar, seg_dropdown, callout, h2h_table)
}


build_turf_panel <- function(html_data, tables, charts, insights = NULL) {

  callout <- html_data$turf$callout %||% ""
  turf_table <- tables$turf %||% ""
  toolbar <- build_panel_toolbar("turf", insights)

  pin_icon <- "&#x1F4CC;"
  turf_chart <- ""
  if (!is.null(charts$turf_chart)) {
    turf_chart <- sprintf(
      '<div class="md-chart-wrapper"><button class="md-chart-pin-btn" onclick="window._mdPinChart(this,\'TURF Reach Curve\')" title="Pin chart">%s</button><div class="md-chart-container"><div class="md-chart-title">Incremental Reach Curve</div>%s</div></div>',
      pin_icon, charts$turf_chart)
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
  toolbar <- build_panel_toolbar("diagnostics", insights)

  d <- html_data$diagnostics
  meta <- html_data$meta

  # Helper to build a stat card with icon
  stat_card <- function(icon, value, label, sublabel = "") {
    sub_html <- if (nzchar(sublabel)) sprintf('<div class="md-stat-sub">%s</div>', sublabel) else ""
    sprintf(
      '<div class="md-stat-card"><div class="md-stat-icon">%s</div><div class="md-stat-body"><div class="md-stat-value">%s</div><div class="md-stat-label">%s</div>%s</div></div>',
      icon, value, label, sub_html)
  }

  # Icons
  ic_grid <- '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>'
  ic_users <- '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>'
  ic_list <- '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg>'
  ic_trend <- '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>'

  # --- Section 1: MODEL SUMMARY (4 stat cards) ---
  method_label <- htmlEscape(meta$method %||% "N/A")
  model_cards <- paste0(
    stat_card(ic_grid, sprintf("<strong>Method</strong><br/>%s", method_label), "", ""),
    stat_card(ic_users, format(as.integer(d$n_total %||% 0), big.mark = ","), "Respondents"),
    stat_card(ic_grid, as.character(d$n_items %||% 0), "Items"),
    stat_card(ic_list, as.character(d$n_segments %||% 0), "Segments"))

  model_section <- sprintf(
    '<h3 style="font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;color:var(--md-text-secondary);margin:16px 0 10px;">Model Summary</h3><div class="md-stat-grid">%s</div>',
    model_cards)

  # --- Section 2: POPULATION UTILITY STATISTICS (4 stat cards) ---
  pop_section <- ""
  ps <- d$pop_stats
  if (!is.null(ps)) {
    pop_cards <- paste0(
      stat_card(ic_list, as.character(ps$utility_range), "Utility Range", "Max &ndash; Min"),
      stat_card(ic_grid, as.character(ps$mean_utility), "Mean Utility"),
      stat_card(ic_list, as.character(ps$utility_sd), "Utility SD", "Population spread"),
      stat_card(ic_trend, as.character(ps$discrimination), "Discrimination", "Range &divide; Items"))
    pop_section <- sprintf(
      '<h3 style="font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;color:var(--md-text-secondary);margin:20px 0 10px;">Population Utility Statistics</h3><div class="md-stat-grid">%s</div>',
      pop_cards)
  }

  # --- Section 3: MODEL QUALITY INDICATORS (4 stat cards) ---
  quality_section <- ""
  qi <- d$quality_indicators
  if (!is.null(qi)) {
    quality_cards <- paste0(
      stat_card(ic_trend, paste0(qi$mean_max_share, "%"), "Mean Max Share", sprintf("Chance = %s%%", qi$chance_level)),
      stat_card(ic_trend, paste0(qi$sharpness_ratio, "x"), "Sharpness Ratio", "vs chance level"),
      stat_card(ic_list, as.character(qi$entropy_ratio), "Entropy Ratio", "Lower = sharper (0&ndash;1)"),
      stat_card(ic_users, as.character(qi$heterogeneity), "Heterogeneity", "Avg SD from population"))
    quality_section <- sprintf(
      '<h3 style="font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;color:var(--md-text-secondary);margin:20px 0 10px;">Model Quality Indicators</h3><div class="md-stat-grid">%s</div>',
      quality_cards)
  }

  # --- Section 4: RESPONDENT UTILITY DISTRIBUTION (3 stat cards) ---
  resp_section <- ""
  rs <- d$respondent_stats
  if (!is.null(rs)) {
    resp_cards <- paste0(
      stat_card(ic_list, as.character(rs$mean_range), "Mean Util Range", "Per respondent"),
      stat_card(ic_list, as.character(rs$min_range), "Min Util Range", "Least discriminating"),
      stat_card(ic_list, as.character(rs$max_range), "Max Util Range", "Most discriminating"))
    resp_section <- sprintf(
      '<h3 style="font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;color:var(--md-text-secondary);margin:20px 0 10px;">Respondent Utility Distribution</h3><div class="md-stat-grid">%s</div>',
      resp_cards)
  }

  # --- Section 5: ITEM-LEVEL DIAGNOSTICS TABLE ---
  item_table_section <- ""
  idt <- d$item_diag_table
  if (!is.null(idt) && nrow(idt) > 0) {
    # Build table HTML
    rows <- vapply(seq_len(nrow(idt)), function(i) {
      r <- idt[i, ]
      # Highlight top pop utility in brand colour
      pop_style <- if (i == 1) ' style="color:var(--md-brand);font-weight:600;"' else ""
      sprintf('<tr><td class="md-td md-label-col">%s</td><td class="md-td md-num"%s>%s</td><td class="md-td md-num">%s</td><td class="md-td md-num">%s</td><td class="md-td md-num">%s</td><td class="md-td md-num">%s</td></tr>',
        htmlEscape(r$Item_Label), pop_style, r$Pop_Utility, r$Indiv_Mean, r$Indiv_SD, r$Min, r$Max)
    }, character(1))

    item_table_section <- sprintf(
      '<h3 style="font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;color:var(--md-text-secondary);margin:20px 0 10px;">Item-Level Diagnostics</h3>
<table class="md-table">
<thead><tr><th class="md-th md-label-col">Item</th><th class="md-th md-num">Pop. Utility</th><th class="md-th md-num">Indiv. Mean</th><th class="md-th md-num">Indiv. SD</th><th class="md-th md-num">Min</th><th class="md-th md-num">Max</th></tr></thead>
<tbody>%s</tbody>
</table>', paste(rows, collapse = "\n"))
  }

  # Methodology as collapsible
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
    %s
    %s
    %s
    %s
  </div>
</div>',
    toolbar, callout, model_section, pop_section, quality_section, resp_section, item_table_section, method_section, images_html)
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
/* Reset and body font provided by turas_base_css(); module overrides below */
body { font-size: 14px; -webkit-font-smoothing: antialiased; }

/* === HEADER === */
.md-header {
  background: linear-gradient(135deg, color-mix(in srgb, BRAND_TOKEN 80%, #000) 0%, color-mix(in srgb, BRAND_TOKEN 60%, #1a2744) 100%);
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

/* === OVERVIEW STAT CARDS (with icons) === */
.md-stat-grid { display: flex; gap: 14px; margin-bottom: 18px; flex-wrap: wrap; }
.md-stat-card {
  flex: 1; min-width: 150px; background: white; border-radius: 10px; padding: 16px 18px;
  display: flex; align-items: flex-start; gap: 12px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.06); border: 1px solid var(--md-border);
}
.md-stat-icon { color: var(--md-brand); opacity: 0.7; flex-shrink: 0; margin-top: 2px; }
.md-stat-body { flex: 1; min-width: 0; }
.md-stat-value { font-size: 22px; font-weight: 700; color: var(--md-brand); line-height: 1.2; }
.md-stat-label { font-size: 11px; color: var(--md-text-secondary); margin-top: 3px; text-transform: uppercase; letter-spacing: 0.3px; font-weight: 500; }
.md-stat-sub { font-size: 11px; color: var(--md-text-secondary); margin-top: 2px; font-style: italic; }

/* === KEY FINDINGS === */
.md-key-findings { margin-bottom: 18px; }
.md-key-findings h3 { font-size: 13px; font-weight: 600; color: var(--md-text-secondary); text-transform: uppercase; letter-spacing: 0.4px; margin-bottom: 10px; }
.md-findings-grid { display: flex; gap: 12px; flex-wrap: wrap; }
.md-finding-card {
  flex: 1; min-width: 180px; display: flex; align-items: center; gap: 10px;
  padding: 12px 16px; border-radius: 8px; background: #f8fafc; border: 1px solid var(--md-border);
}
.md-finding-best { border-left: 3px solid #16a34a; }
.md-finding-worst { border-left: 3px solid #dc2626; }
.md-finding-icon { flex-shrink: 0; color: var(--md-text-secondary); }
.md-finding-best .md-finding-icon { color: #16a34a; }
.md-finding-worst .md-finding-icon { color: #dc2626; }
.md-finding-body { min-width: 0; }
.md-finding-label { font-size: 10px; color: var(--md-text-secondary); text-transform: uppercase; letter-spacing: 0.3px; font-weight: 600; }
.md-finding-value { font-size: 14px; font-weight: 600; color: var(--md-text-primary); margin-top: 2px; overflow: hidden; text-overflow: ellipsis; }

/* === SEGMENT FILTER === */
.md-segment-filter { margin: 8px 0 12px; }
.md-segment-filter label { font-size: 12px; font-weight: 600; color: var(--md-text-secondary); text-transform: uppercase; letter-spacing: 0.3px; }
.md-segment-select {
  padding: 5px 10px; border: 1px solid var(--md-border); border-radius: 6px;
  font-size: 13px; color: var(--md-text-primary); background: white;
  cursor: pointer; margin-left: 6px; min-width: 180px;
}
.md-segment-select:focus { outline: none; border-color: var(--md-brand); box-shadow: 0 0 0 2px rgba(50,51,103,0.1); }
.md-segment-tables > div { display: none; }
.md-segment-tables > div[data-segment="all"] { display: block; }

/* === CHARTS === */
.md-chart-container { background: var(--md-bg-muted); border-radius: 8px; padding: 12px; margin: 12px 0; }
.md-chart-title { font-size: 13px; font-weight: 600; color: var(--md-text-secondary); text-align: center; margin-bottom: 8px; }

/* === TABLES === */
.md-table { width: 100%; border-collapse: collapse; font-size: 13px; margin: 8px 0; }
.md-table-compact { font-size: 12px; }
.md-table .md-th, .md-th { background: var(--md-bg-muted); padding: 12px 16px; text-align: left; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.4px; color: var(--md-text-secondary); border-bottom: 2px solid var(--md-border); cursor: pointer; user-select: none; }
.md-th:hover { background: #eef2f7; }
.md-th .sort-arrow { font-size: 10px; margin-left: 4px; opacity: 0.5; }
.md-th.md-num { text-align: right; }
.md-th.md-label-col { text-align: left; }
.md-table .md-td, .md-td { padding: 10px 16px; border-bottom: 1px solid var(--md-border); vertical-align: middle; }
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
.pinned-views-container { max-width: 1400px; margin: 0 auto; }
.pinned-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; }
.pinned-header h2 { font-size: 18px; font-weight: 700; color: var(--md-brand); }
.pinned-header-actions { display: flex; gap: 8px; }

/* Pinned card — tabs-quality styling (md-pinned prefix from TurasPins) */
.md-pinned-card {
  background: #ffffff; border: 1px solid #e8e5e0; border-radius: 8px;
  padding: 20px 24px; margin-bottom: 16px; page-break-inside: avoid;
}
.md-pinned-card-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px; }
.md-pinned-card-title { font-size: 18px; font-weight: 600; color: #1e293b; margin-bottom: 2px; }
.md-pinned-card-subtitle { font-size: 13px; font-weight: 400; color: #94a3b8; }
.md-pinned-card-actions { display: flex; gap: 4px; flex-shrink: 0; }

/* Insight area — brand-accented left border */
.md-pinned-card-insight {
  margin-bottom: 12px; padding: 14px 20px;
  border-left: 3px solid var(--md-accent, #CC9900); background: #f8fafa;
  border-radius: 0 6px 6px 0; font-size: 14px; line-height: 1.6; color: #1e293b;
}
.md-pinned-card-insight:empty { display: none; }
.md-pinned-card-insight[data-placeholder]:empty::before {
  content: attr(data-placeholder); color: #94a3b8; font-style: italic;
}

/* Chart area */
.md-pinned-card-chart { margin-bottom: 12px; }
.md-pinned-card-chart svg { width: 100%; height: auto; }

/* Table area — full width, polished */
.md-pinned-card-table { overflow-x: auto; margin-bottom: 8px; }
.md-pinned-card-table table {
  width: 100% !important; border-collapse: collapse; font-size: 13px;
}
.md-pinned-card-table th {
  padding: 8px 12px; text-align: left; font-size: 11px; font-weight: 600;
  text-transform: uppercase; letter-spacing: 0.3px; color: #64748b;
  background: #f8fafc; border-bottom: 2px solid #e2e8f0; max-width: none;
}
.md-pinned-card-table td {
  padding: 8px 12px; border-bottom: 1px solid #f1f5f9; color: #334155; max-width: none;
}
.md-pinned-card-table tr:last-child td { border-bottom: none; }
.md-pinned-card-table tr:hover td { background: #f8fafc; }

/* Drag & drop */
.md-pinned-card[draggable="true"]:active { cursor: grabbing; }
.pin-dragging { opacity: 0.4 !important; }
.pin-drop-target { outline: 2px dashed var(--md-brand); outline-offset: 4px; }

/* Section dividers */
.md-pinned-section-divider {
  display: flex; align-items: center; gap: 12px; padding: 12px 0;
  margin: 8px 0; border-bottom: 2px solid var(--md-brand);
}
.md-pinned-section-title {
  font-size: 16px; font-weight: 600; color: var(--md-brand);
  flex: 1; outline: none; min-width: 100px;
}
.md-pinned-section-title:focus { border-bottom: 1px dashed #e2e8f0; }
.md-pinned-section-actions { display: flex; gap: 4px; }
.md-pinned-remove-btn {
  background: none; border: 1px solid #e2e8f0; border-radius: 4px;
  cursor: pointer; font-size: 16px; line-height: 1; padding: 2px 6px; color: #94a3b8;
}
.md-pinned-remove-btn:hover { background: #fee2e2; color: #dc2626; border-color: #fecaca; }
.md-pinned-action-btn {
  background: none; border: 1px solid #e2e8f0; border-radius: 4px;
  cursor: pointer; font-size: 11px; padding: 2px 6px; color: #64748b;
}
.md-pinned-action-btn:hover { background: #f1f5f9; }
/* Insight editing */
.md-pinned-insight-rendered { min-height: 1em; cursor: text; }
.md-pinned-insight-rendered:empty::before {
  content: attr(data-placeholder); color: #94a3b8; font-style: italic;
}
.md-pinned-insight-editor {
  width: 100%; border: 1px solid #cbd5e1; border-radius: 4px;
  padding: 8px 12px; font-size: 13px; font-family: inherit;
  line-height: 1.5; resize: vertical; min-height: 60px;
}

/* Overflow menu */
.pin-overflow-item:hover { background: #f1f5f9; }

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

/* === H2H HEATMAP TABLE (segment-profile style) === */
.md-h2h-legend {
  display: flex; flex-wrap: wrap; gap: 12px; align-items: center;
  margin-bottom: 10px; padding: 8px 12px;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px;
  font-size: 12px; color: #475569;
}
.md-h2h-legend-title { font-weight: 600; color: #1e293b; margin-right: 4px; }
.md-h2h-legend-item { display: inline-flex; align-items: center; gap: 4px; }
.md-h2h-legend-swatch {
  display: inline-block; width: 16px; height: 16px;
  border-radius: 3px; border: 1px solid #e2e8f0;
}
.md-h2h-wrapper { overflow-x: auto; margin: 8px 0; }
.md-h2h-table { border-collapse: collapse; width: 100%; table-layout: fixed; font-size: 13px; font-family: inherit; }
.md-h2h-table th, .md-h2h-table td { border: 1px solid #e2e8f0; }
.md-h2h-label-col {
  text-align: left; font-weight: 600; font-size: 12px;
  padding: 10px 14px; width: 160px; white-space: nowrap;
  background: #f8fafc; color: #1e293b;
}
.md-h2h-col-header {
  text-align: center; vertical-align: bottom; background: #f8fafc;
  font-size: 11px; font-weight: 600; color: #1e293b;
  padding: 8px 6px; white-space: normal; word-wrap: break-word;
  overflow-wrap: break-word;
  line-height: 1.3;
}
.md-h2h-row-label {
  text-align: left; font-weight: 500; font-size: 12px;
  padding: 8px 14px; white-space: normal; word-wrap: break-word;
  color: #1e293b; background: #fafbfc;
}
.md-h2h-cell {
  text-align: center; font-size: 12px; font-variant-numeric: tabular-nums;
  padding: 8px 6px; font-weight: 500;
}
/* Heatmap tinting — matches segment profile pattern */
.md-h2h-win-strong { background: #dcfce7; color: #166534; }
.md-h2h-win { background: #eff6ff; color: #1e40af; }
.md-h2h-lose { background: #fef3c7; color: #92400e; }
.md-h2h-lose-strong { background: #fee2e2; color: #991b1b; }
.md-h2h-neutral { background: #ffffff; color: #64748b; }
.md-h2h-self { background: #f1f5f9; color: #94a3b8; font-style: italic; }

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

/* === ADDED SLIDES === */
.md-slide-card {
  background: white; border-radius: 8px; padding: 20px; margin-bottom: 16px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.06); border: 1px solid var(--md-border);
}
.md-slide-header {
  display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;
}
.md-slide-title {
  font-size: 14px; font-weight: 600; color: var(--md-text-primary);
  border: none; background: transparent; flex: 1; padding: 4px 8px;
  border-bottom: 1px dashed var(--md-border);
}
.md-slide-title:focus { outline: none; border-bottom-color: var(--md-brand); }
.md-slide-actions { display: flex; gap: 4px; }
.md-slide-btn {
  width: 28px; height: 28px; border-radius: 4px; border: 1px solid var(--md-border);
  background: white; cursor: pointer; display: flex; align-items: center;
  justify-content: center; font-size: 12px; color: var(--md-text-secondary);
}
.md-slide-btn:hover { background: var(--md-bg-muted); }
.md-slide-btn.remove:hover { background: #fee2e2; color: #dc2626; border-color: #fecaca; }
.md-slide-md-editor {
  width: 100%; min-height: 100px; border: 1px solid var(--md-border); border-radius: 6px;
  padding: 10px 12px; font-family: inherit; font-size: 13px; line-height: 1.5;
  resize: vertical; color: var(--md-text-primary);
}
.md-slide-md-editor:focus { outline: none; border-color: var(--md-brand); }
.md-slide-md-rendered {
  font-size: 13px; line-height: 1.6; color: var(--md-text-primary); cursor: pointer;
  min-height: 40px; padding: 8px 0;
}
.md-slide-md-rendered p { margin-bottom: 6px; }
.md-slide-md-rendered strong { font-weight: 600; }
.md-slide-md-rendered ul { padding-left: 1.2em; margin: 4px 0; }
.md-slide-img-preview {
  margin-top: 12px; text-align: center; position: relative;
}
.md-slide-img-preview img {
  max-width: 100%; max-height: 400px; border-radius: 6px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.08);
}
.md-slide-img-remove {
  position: absolute; top: 4px; right: 4px; width: 24px; height: 24px;
  border-radius: 50%; background: rgba(0,0,0,0.5); color: white; border: none;
  cursor: pointer; font-size: 14px; display: flex; align-items: center;
  justify-content: center; line-height: 1;
}
.md-slide-img-remove:hover { background: rgba(220,38,38,0.8); }

/* === EXPORT BUTTON === */
.md-export-btn {
  display: inline-flex; align-items: center; gap: 4px; padding: 5px 12px;
  border-radius: 5px; border: 1px solid var(--md-border); background: white;
  color: var(--md-text-secondary); font-size: 12px; font-weight: 500;
  cursor: pointer; transition: all 200ms;
}
.md-export-btn:hover { background: var(--md-bg-muted); color: var(--md-text-primary); border-color: #cbd5e1; }
.md-export-btn svg { flex-shrink: 0; }

/* === CHART PIN BUTTON === */
.md-chart-wrapper { position: relative; }
.md-chart-pin-btn {
  position: absolute; top: 6px; right: 6px; width: 28px; height: 28px;
  border-radius: 4px; border: 1px solid var(--md-border); background: rgba(255,255,255,0.9);
  cursor: pointer; font-size: 14px; display: flex; align-items: center;
  justify-content: center; opacity: 0; transition: opacity 200ms;
  z-index: 5;
}
.md-chart-wrapper:hover .md-chart-pin-btn { opacity: 1; }
.md-chart-pin-btn:hover { background: white; border-color: var(--md-brand); }

/* === CUSTOM SLIDES === */
.md-slide-content { font-size: 14px; line-height: 1.7; color: var(--md-text-primary); }

/* === SUB-TAB NAVIGATION === */
.md-subtab-nav {
  display: flex; gap: 0; border-bottom: 2px solid var(--md-border);
  margin-bottom: 16px; margin-top: 4px;
}
.md-subtab-btn {
  background: transparent; border: none; padding: 8px 16px; font-size: 12px; font-weight: 500;
  color: var(--md-text-secondary); cursor: pointer; border-bottom: 2px solid transparent;
  margin-bottom: -2px; white-space: nowrap; transition: all 200ms;
}
.md-subtab-btn:hover { color: var(--md-brand); }
.md-subtab-btn.active { color: var(--md-brand); border-bottom-color: var(--md-brand); font-weight: 600; }
.md-subpanel { display: none; }
.md-subpanel.active { display: block; }

/* === DIAGNOSTICS RICH LAYOUT === */
.md-diag-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 20px; }
.md-diag-card {
  background: white; border-radius: 8px; padding: 18px 20px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.06); border: 1px solid var(--md-border);
}
.md-diag-card h4 {
  font-size: 12px; font-weight: 600; color: var(--md-text-secondary);
  text-transform: uppercase; letter-spacing: 0.3px; margin-bottom: 12px;
  padding-bottom: 6px; border-bottom: 1px solid var(--md-border);
}
.md-diag-card.full-width { grid-column: 1 / -1; }
.md-diag-row {
  display: flex; justify-content: space-between; align-items: center;
  padding: 5px 0; font-size: 13px;
}
.md-diag-row-label { color: var(--md-text-secondary); }
.md-diag-row-value { font-weight: 600; color: var(--md-text-primary); font-variant-numeric: tabular-nums; }

/* === FOOTER === */
.md-footer { text-align: center; padding: 20px 40px; color: #94a3b8; font-size: 11px; border-top: 1px solid var(--md-border); }

/* === RESPONSIVE === */
@media (max-width: 768px) {
  .md-header, .md-tab-nav, .md-container, .md-footer { padding-left: 16px; padding-right: 16px; }
  .md-metrics { flex-direction: column; }
  .md-stat-grid { flex-direction: column; }
  .md-findings-grid { flex-direction: column; }
  .md-diag-grid { grid-template-columns: 1fr; }
  .md-tab-btn { padding: 8px 10px; font-size: 12px; }
  .md-subtab-btn { padding: 6px 10px; font-size: 11px; }
}'

  css <- gsub("BRAND_TOKEN", brand, css, fixed = TRUE)
  css <- gsub("ACCENT_TOKEN", accent, css, fixed = TRUE)

  # Prepend shared design system CSS
  shared_css <- tryCatch(turas_base_css(brand, accent, prefix = "md"), error = function(e) "")
  css <- paste0(shared_css, "\n", css)

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
