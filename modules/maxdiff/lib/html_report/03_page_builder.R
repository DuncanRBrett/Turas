# ==============================================================================
# MAXDIFF HTML REPORT - PAGE BUILDER - TURAS V11.1
# ==============================================================================
# Assembles the full HTML document from tables, charts, and data.
# Matches Turas platform standard: dark gradient header, logo, branding,
# badge bar, tab navigation, about panel, help overlay.
# All output is a self-contained HTML string — no htmltools dependency.
# ==============================================================================

# htmlEscape() and %||% are defined in 01_data_transformer.R (loaded first by 99_html_report_main.R)


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
      return(NULL)  # No base64 encoder available
    }
    paste0("data:", mime, ";base64,", b64)
  }, error = function(e) NULL)
}


# ==============================================================================
# PANEL IMAGES HELPER
# ==============================================================================

#' Build embedded images HTML for a specific panel
#'
#' Checks html_data$images for images keyed to the given panel name,
#' converts each to base64, and wraps in a styled container with caption.
#'
#' @param images_list Named list where keys are panel names and values are
#'   lists with \code{path} and optional \code{caption}
#' @param panel_name Character string identifying the panel (e.g. "summary")
#'
#' @return Character string of HTML, or "" if no images for this panel
#' @keywords internal
build_panel_images <- function(images_list, panel_name) {
  if (is.null(images_list)) return("")
  panel_images <- images_list[[panel_name]]
  if (is.null(panel_images)) return("")

  # Normalise: if a single image (list with $path), wrap in a list

  if (!is.null(panel_images$path)) {
    panel_images <- list(panel_images)
  }

  img_blocks <- vapply(panel_images, function(img) {
    uri <- md_resolve_logo_uri(img$path)
    if (is.null(uri)) return("")
    caption_html <- ""
    if (!is.null(img$caption) && nzchar(img$caption)) {
      caption_html <- sprintf(
        '<div class="md-image-caption">%s</div>',
        htmlEscape(img$caption)
      )
    }
    sprintf(
      '<div class="md-image-container"><img src="%s" alt="%s" class="md-embedded-image"/>%s</div>',
      uri,
      htmlEscape(img$caption %||% "Embedded image"),
      caption_html
    )
  }, character(1))

  paste(img_blocks[nzchar(img_blocks)], collapse = "\n")
}


# ==============================================================================
# CUSTOM SLIDE BUILDER
# ==============================================================================

#' Build a custom slide panel from config$slides row
#'
#' @param slide A single-row list/data.frame with Title, Content,
#'   and optional Image_Path
#' @param config Module configuration
#'
#' @return Character string of panel HTML
#' @keywords internal
build_custom_slide_panel <- function(slide, config) {

  title <- htmlEscape(slide$Title %||% "Custom Slide")
  content <- slide$Content %||% ""
  slide_id <- tolower(gsub("[^a-z0-9]", "-", tolower(slide$Title %||% "slide"), perl = TRUE))
  slide_id <- paste0("custom-", slide_id)

  # Embed image if provided
  image_html <- ""
  img_path <- slide$Image_Path %||% ""
  if (nzchar(img_path)) {
    uri <- md_resolve_logo_uri(img_path)
    if (!is.null(uri)) {
      image_html <- sprintf(
        '<div class="md-image-container"><img src="%s" alt="%s" class="md-embedded-image"/></div>',
        uri, title
      )
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
    slide_id, title, content, image_html
  )
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
#'
#' @return Single HTML string (complete document)
#' @keywords internal
build_maxdiff_page <- function(html_data, tables, charts, config) {

  brand <- html_data$meta$brand_colour %||% "#323367"
  accent <- html_data$meta$accent_colour %||% "#CC9900"
  # Humanize project name: replace underscores with spaces for display
  raw_name <- html_data$meta$project_name %||% "MaxDiff Analysis"
  project_name <- htmlEscape(gsub("_", " ", raw_name))

  css <- build_md_css(brand, accent)
  print_css <- build_md_print_css()
  meta_tags <- build_md_meta(html_data)
  header <- build_md_header(html_data, config)

  # Determine which tabs to show
  has_preferences <- !is.null(html_data$preferences$scores)
  has_items <- !is.null(html_data$items$count_data)
  has_segments <- !is.null(html_data$segments)
  has_turf <- !is.null(html_data$turf)
  has_methodology <- !is.null(html_data$methodology)

  # Build panels
  summary_panel <- build_summary_panel(html_data, tables, charts)
  pref_panel <- if (has_preferences) build_preferences_panel(html_data, tables, charts) else ""
  items_panel <- if (has_items) build_items_panel(html_data, tables, charts) else ""
  segments_panel <- if (has_segments) build_segments_panel(html_data, tables, charts) else ""
  turf_panel <- if (has_turf) build_turf_panel(html_data, tables, charts) else ""
  methodology_panel <- if (has_methodology) build_methodology_panel(html_data) else ""
  diag_panel <- build_diagnostics_panel(html_data, tables, charts)
  about_panel <- build_md_about_panel(html_data$meta, config)
  help_overlay <- build_md_help_overlay()

  # Build custom slide panels from config$slides or config$custom_slides
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
        slide_id, htmlEscape(slide$Title %||% "Slide")
      ))
    }
  }

  # Build tab navigation - core tabs first
  tab_buttons <- '<button class="md-tab-btn active" data-tab="summary">Summary</button>'
  if (has_preferences) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="preferences">Preference Scores</button>')
  if (has_items) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="items">Item Analysis</button>')
  if (has_turf) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="turf">Portfolio (TURF)</button>')
  if (has_segments) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="segments">Segments</button>')
  if (has_methodology) tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="methodology">Methodology</button>')
  tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="diagnostics">Diagnostics</button>')

  # Insert custom slide tab buttons (before About)
  if (length(custom_tab_buttons) > 0) {
    tab_buttons <- paste0(tab_buttons, "\n", paste(custom_tab_buttons, collapse = "\n"))
  }

  tab_buttons <- paste0(tab_buttons, '\n<button class="md-tab-btn" data-tab="about">About</button>')

  js <- build_md_js()

  # Combine custom panels into single string
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
</div>
%s
<footer class="md-footer">Generated by TURAS Analytics Platform &middot; MaxDiff Module v11.1 &middot; %s</footer>
<script>%s</script>
</body>
</html>',
    meta_tags,
    project_name,
    css,
    print_css,
    header,
    tab_buttons,
    summary_panel,
    pref_panel,
    items_panel,
    turf_panel,
    segments_panel,
    methodology_panel,
    diag_panel,
    custom_panels_html,
    about_panel,
    help_overlay,
    format(Sys.Date(), "%B %Y"),
    js
  )
}


# ==============================================================================
# HEADER BUILDER
# ==============================================================================

#' Build the Turas-standard gradient header for MaxDiff reports
#'
#' @param html_data Structured data from transform_maxdiff_for_html()
#' @param config Module configuration
#' @return Character string of header HTML
#' @keywords internal
build_md_header <- function(html_data, config) {

  meta <- html_data$meta
  summary <- html_data$summary

  # --- Logo ---
  logo_html <- ""
  logo_uri <- md_resolve_logo_uri(meta$researcher_logo_path)
  if (!is.null(logo_uri) && nzchar(logo_uri)) {
    logo_html <- sprintf(
      '<div style="width:72px;height:72px;border-radius:12px;display:flex;align-items:center;justify-content:center;flex-shrink:0;"><img src="%s" alt="Logo" class="md-header-logo"/></div>',
      logo_uri
    )
  }

  # --- Help button ---
  help_btn <- '<button class="md-help-btn" onclick="toggleHelpOverlay()" title="Show help guide">?</button>'

  # --- Prepared by line ---
  prepared_parts <- character()
  company <- meta$company_name %||% ""
  researcher <- meta$researcher_name %||% ""
  client <- meta$client_name %||% ""

  if (nzchar(company)) {
    if (nzchar(researcher)) {
      prepared_parts <- c(prepared_parts, sprintf(
        'Prepared by <strong>%s</strong> (%s)',
        htmlEscape(researcher), htmlEscape(company)
      ))
    } else {
      prepared_parts <- c(prepared_parts, sprintf(
        'Prepared by <strong>%s</strong>', htmlEscape(company)
      ))
    }
  }
  if (nzchar(client)) {
    prepared_parts <- c(prepared_parts, sprintf(
      'for <strong>%s</strong>', htmlEscape(client)
    ))
  }
  prepared_html <- if (length(prepared_parts) > 0) {
    sprintf('<div class="md-header-prepared">%s</div>', paste(prepared_parts, collapse = " "))
  } else ""

  # --- Badge bar ---
  badges <- character()
  badges <- c(badges, sprintf(
    '<span class="md-badge-item">%s</span>',
    toupper(meta$method %||% "Analysis")
  ))
  if (!is.null(meta$n_total) && meta$n_total > 0) {
    badges <- c(badges, sprintf(
      '<span class="md-badge-item">n&nbsp;=&nbsp;<strong>%s</strong></span>',
      format(meta$n_total, big.mark = ",")
    ))
  }
  badges <- c(badges, sprintf(
    '<span class="md-badge-item"><strong>%s</strong>&nbsp;Items</span>',
    meta$n_items %||% "0"
  ))
  if (!is.null(summary$top_item) && nzchar(summary$top_item) && summary$top_item != "N/A") {
    badges <- c(badges, sprintf(
      '<span class="md-badge-item">Top:&nbsp;<strong>%s</strong></span>',
      htmlEscape(summary$top_item)
    ))
  }
  badges <- c(badges, sprintf(
    '<span class="md-badge-item" id="md-header-date">Created %s</span>',
    format(Sys.Date(), "%b %Y")
  ))
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
    logo_html, help_btn,
    htmlEscape(gsub("_", " ", meta$project_name %||% "MaxDiff Analysis")),
    prepared_html, badge_html
  )
}


# ==============================================================================
# ABOUT PANEL
# ==============================================================================

#' Build About panel with analyst contact details
#'
#' @param meta Meta list from html_data
#' @param config Module configuration
#' @return Character string of About panel HTML
#' @keywords internal
build_md_about_panel <- function(meta, config) {

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
        f$label, val_html
      ))
    }
  }
  contact_html <- if (length(contact_rows) > 0) {
    sprintf('<div class="md-about-grid">%s</div>', paste(contact_rows, collapse = "\n"))
  } else ""

  # Generation info
  gen_info <- sprintf(
    '<div class="md-about-grid">
<div class="md-about-label">Generated</div><div class="md-about-value">%s</div>
<div class="md-about-label">Module</div><div class="md-about-value">MaxDiff v11.1</div>
<div class="md-about-label">Method</div><div class="md-about-value">%s</div>
</div>',
    meta$generated %||% format(Sys.Date(), "%Y-%m-%d"),
    meta$method %||% "N/A"
  )

  sprintf(
    '<div class="md-panel" id="panel-about">
<div class="md-card">
<h2>About This Report</h2>
<div class="md-about-section">
%s
<div style="margin-top:16px;">%s</div>
</div>
</div>
</div>',
    contact_html, gen_info
  )
}


# ==============================================================================
# HELP OVERLAY
# ==============================================================================

#' Build help overlay for MaxDiff report
#' @return Character string of help overlay HTML
#' @keywords internal
build_md_help_overlay <- function() {
  '
<div class="md-help-overlay" id="md-help-overlay" onclick="toggleHelpOverlay()">
<div class="md-help-card" onclick="event.stopPropagation()">
<h2>Quick Guide</h2>
<ul>
<li><span class="md-help-key">Tab navigation</span>Switch between report sections</li>
<li><span class="md-help-key">Summary</span>Overview metrics and key finding</li>
<li><span class="md-help-key">Preference Scores</span>Utility values and preference shares</li>
<li><span class="md-help-key">Item Analysis</span>Best/worst selection frequencies</li>
<li><span class="md-help-key">Portfolio (TURF)</span>Optimal item set for maximum reach</li>
<li><span class="md-help-key">Segments</span>Preference differences across groups</li>
<li><span class="md-help-key">Diagnostics</span>Model fit and convergence checks</li>
<li><span class="md-help-key">About</span>Report metadata and analyst details</li>
</ul>
<div class="md-help-dismiss">Click anywhere to close</div>
</div>
</div>'
}


# ==============================================================================
# PANEL BUILDERS
# ==============================================================================

build_summary_panel <- function(html_data, tables, charts) {

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
    htmlEscape(s$top_item %||% "N/A")
  )

  # Summary chart (preference shares)
  chart_html <- ""
  if (!is.null(charts$preference_chart)) {
    chart_html <- sprintf(
      '<div class="md-chart-container"><div class="md-chart-title">Preference Shares</div>%s</div>',
      charts$preference_chart
    )
  }

  # Check for custom images for this panel
  images_html <- build_panel_images(html_data$images, "summary")

  sprintf(
    '<div class="md-panel active" id="panel-summary">
      <div class="md-section">
        <h2>Overview</h2>
        %s
        %s
        %s
        %s
      </div>
    </div>',
    metrics, s$callout %||% "", chart_html, images_html
  )
}


build_preferences_panel <- function(html_data, tables, charts) {

  callout <- html_data$preferences$callout %||% ""
  pref_table <- tables$preference_scores %||% ""
  pref_chart <- ""
  if (!is.null(charts$preference_detail_chart)) {
    pref_chart <- sprintf(
      '<div class="md-chart-container"><div class="md-chart-title">Utility Scores (0-100 Scale)</div>%s</div>',
      charts$preference_detail_chart
    )
  }

  # Check for custom images for this panel
  images_html <- build_panel_images(html_data$images, "preferences")

  sprintf(
    '<div class="md-panel" id="panel-preferences">
      <div class="md-section">
        <h2>Preference Scores</h2>
        %s
        %s
        %s
        %s
      </div>
    </div>',
    callout, pref_chart, pref_table, images_html
  )
}


build_items_panel <- function(html_data, tables, charts) {

  callout <- html_data$items$callout %||% ""
  count_table <- tables$count_scores %||% ""
  diverging_chart <- ""
  if (!is.null(charts$diverging_chart)) {
    diverging_chart <- sprintf(
      '<div class="md-chart-container"><div class="md-chart-title">Best vs Worst Selection Frequency</div>%s</div>',
      charts$diverging_chart
    )
  }

  # Check for custom images for this panel
  images_html <- build_panel_images(html_data$images, "items")

  sprintf(
    '<div class="md-panel" id="panel-items">
      <div class="md-section">
        <h2>Item Analysis</h2>
        %s
        %s
        <h3>Detailed Count Scores</h3>
        %s
        %s
      </div>
    </div>',
    callout, diverging_chart, count_table, images_html
  )
}


build_turf_panel <- function(html_data, tables, charts) {

  callout <- html_data$turf$callout %||% ""
  turf_table <- tables$turf %||% ""
  turf_chart <- ""
  if (!is.null(charts$turf_chart)) {
    turf_chart <- sprintf(
      '<div class="md-chart-container"><div class="md-chart-title">Incremental Reach Curve</div>%s</div>',
      charts$turf_chart
    )
  }

  # Check for custom images for this panel
  images_html <- build_panel_images(html_data$images, "turf")

  sprintf(
    '<div class="md-panel" id="panel-turf">
      <div class="md-section">
        <h2>Portfolio Optimization (TURF)</h2>
        %s
        %s
        <h3>Greedy Selection Order</h3>
        %s
        %s
      </div>
    </div>',
    callout, turf_chart, turf_table, images_html
  )
}


build_segments_panel <- function(html_data, tables, charts) {

  callout <- html_data$segments$callout %||% ""
  seg_table <- tables$segments %||% ""

  # Segment chart (grouped bar chart)
  seg_chart_html <- ""
  if (!is.null(charts$segment_chart) && nzchar(charts$segment_chart)) {
    seg_chart_html <- sprintf(
      '<div class="md-chart-container"><div class="md-chart-title">Segment Comparison</div>%s</div>',
      charts$segment_chart
    )
  }

  # Check for custom images for this panel
  images_html <- build_panel_images(html_data$images, "segments")

  sprintf(
    '<div class="md-panel" id="panel-segments">
      <div class="md-section">
        <h2>Segment Analysis</h2>
        %s
        %s
        <h3>Detailed Scores by Segment</h3>
        %s
        %s
      </div>
    </div>',
    callout, seg_chart_html, seg_table, images_html
  )
}


build_diagnostics_panel <- function(html_data, tables, charts) {

  callout <- html_data$diagnostics$callout %||% ""
  diag_table <- tables$diagnostics %||% ""

  # Check for custom images for this panel
  images_html <- build_panel_images(html_data$images, "diagnostics")

  sprintf(
    '<div class="md-panel" id="panel-diagnostics">
      <div class="md-section">
        <h2>Model Diagnostics</h2>
        %s
        %s
        %s
      </div>
    </div>',
    callout, diag_table, images_html
  )
}


build_methodology_panel <- function(html_data) {

  m <- html_data$methodology
  if (is.null(m)) return("")

  content <- m$content %||% ""

  sprintf(
    '<div class="md-panel" id="panel-methodology">
      <div class="md-section">
        <h2>Methodology</h2>
        <div class="md-card">%s</div>
      </div>
    </div>',
    content
  )
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
.md-th { background: var(--md-bg-muted); padding: 8px 12px; text-align: left; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.4px; color: var(--md-text-secondary); border-bottom: 2px solid var(--md-border); }
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

/* === CALLOUTS === */
.md-callout { padding: 12px 16px; border-radius: 6px; margin: 12px 0; font-size: 13px; line-height: 1.5; }
.md-callout-result { background: #eff6ff; border-left: 4px solid #3b82f6; }
.md-callout-method { background: #f8fafc; border-left: 4px solid #94a3b8; }
.md-callout-sampling { background: #fffbeb; border-left: 4px solid #f59e0b; }

.md-positive { color: #16a34a; }
.md-negative { color: #dc2626; }
.md-empty { color: var(--md-text-secondary); font-style: italic; padding: 12px 0; }

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

/* === TABLE SORTING === */
.md-th { cursor: pointer; user-select: none; }
.md-th:hover { background: #eef2f7; }
.md-th .sort-arrow { font-size: 10px; margin-left: 4px; opacity: 0.5; }

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
  .md-help-btn { display: none !important; }
  .md-panel { display: block !important; page-break-inside: avoid; margin-bottom: 20px; }
  .md-header { background: white !important; color: var(--md-brand) !important; border-bottom: 2px solid var(--md-brand); }
  .md-header-title, .md-header-titles h1 { color: var(--md-brand) !important; }
  .md-header-prepared, .md-header-subtitle { color: #64748b !important; }
  .md-badge-bar { border-color: #e2e8f0 !important; }
  .md-badge-item { color: #334155 !important; }
  .md-badge-sep { background: #e2e8f0 !important; }
  body { background: white; }
  .md-container { max-width: 100%; padding: 0 20px; }
}'
}


# ==============================================================================
# JAVASCRIPT
# ==============================================================================

build_md_js <- function() {
  '(function() {
  /* --- Tab navigation --- */
  var tabs = document.querySelectorAll(".md-tab-btn");
  var panels = document.querySelectorAll(".md-panel");
  tabs.forEach(function(tab) {
    tab.addEventListener("click", function() {
      var target = this.getAttribute("data-tab");
      tabs.forEach(function(t) { t.classList.remove("active"); });
      panels.forEach(function(p) { p.classList.remove("active"); });
      this.classList.add("active");
      var panel = document.getElementById("panel-" + target);
      if (panel) panel.classList.add("active");
    });
  });

  /* --- Table column sorting --- */
  document.querySelectorAll(".md-th").forEach(function(th) {
    th.addEventListener("click", function() {
      var table = this.closest(".md-table");
      if (!table) return;
      var headerRow = this.parentElement;
      var headers = Array.prototype.slice.call(headerRow.children);
      var colIdx = headers.indexOf(this);
      if (colIdx < 0) return;

      var tbody = table.querySelector("tbody") || table;
      var rows = Array.prototype.slice.call(tbody.querySelectorAll("tr")).filter(function(r) {
        return r.querySelector("td") && !r.classList.contains("md-tr-section");
      });
      if (rows.length === 0) return;

      /* Determine current sort direction */
      var currentDir = this.getAttribute("data-sort-dir");
      var newDir = (currentDir === "asc") ? "desc" : "asc";

      /* Clear all sort arrows in this table */
      headers.forEach(function(h) {
        h.setAttribute("data-sort-dir", "");
        var arrow = h.querySelector(".sort-arrow");
        if (arrow) arrow.remove();
      });

      /* Set new direction and arrow */
      this.setAttribute("data-sort-dir", newDir);
      var arrowSpan = document.createElement("span");
      arrowSpan.className = "sort-arrow";
      arrowSpan.textContent = (newDir === "asc") ? " \\u25B2" : " \\u25BC";
      this.appendChild(arrowSpan);

      /* Detect if column is numeric */
      var isNumeric = rows.every(function(row) {
        var cell = row.children[colIdx];
        if (!cell) return false;
        var txt = cell.textContent.replace(/[,%$\\s]/g, "").trim();
        return txt === "" || !isNaN(parseFloat(txt));
      });

      rows.sort(function(a, b) {
        var aCell = a.children[colIdx];
        var bCell = b.children[colIdx];
        var aVal = aCell ? aCell.textContent.trim() : "";
        var bVal = bCell ? bCell.textContent.trim() : "";

        if (isNumeric) {
          var aNum = parseFloat(aVal.replace(/[,%$\\s]/g, "")) || 0;
          var bNum = parseFloat(bVal.replace(/[,%$\\s]/g, "")) || 0;
          return (newDir === "asc") ? aNum - bNum : bNum - aNum;
        } else {
          var cmp = aVal.localeCompare(bVal);
          return (newDir === "asc") ? cmp : -cmp;
        }
      });

      /* Re-append sorted rows */
      rows.forEach(function(row) { tbody.appendChild(row); });
    });
  });
})();

/* --- Help overlay --- */
function toggleHelpOverlay() {
  var overlay = document.getElementById("md-help-overlay");
  if (overlay) overlay.classList.toggle("open");
}'
}
