#' Front Page Builder
#'
#' Generates the Overview tab content: report index cards with rich
#' metadata and combined executive summary areas.

#' Build the Overview Front Page HTML
#'
#' @param config Validated config from guard
#' @param parsed_reports List of parsed report objects
#' @return HTML string for the overview panel
build_front_page <- function(config, parsed_reports) {

  parts <- character(0)
  parts <- c(parts, '<div class="hub-overview">')

  # --- Report index cards (no meta strip — info is in header + cards) ---
  parts <- c(parts, '<div class="hub-report-cards">')
  for (parsed in parsed_reports) {
    parts <- c(parts, build_report_card(parsed))
  }
  parts <- c(parts, '</div>')

  # --- Hub-level executive summary (from config, if provided) ---
  if (!is.null(config$settings$executive_summary)) {
    parts <- c(parts, build_hub_text_section(
      id = "executive-summary",
      label = "Executive Summary",
      content = config$settings$executive_summary
    ))
  }

  # --- Hub-level background text (from config, if provided) ---
  if (!is.null(config$settings$background_text)) {
    parts <- c(parts, build_hub_text_section(
      id = "background",
      label = "Background & Methodology",
      content = config$settings$background_text
    ))
  }

  # --- Combined summary area (per-report summaries) ---
  parts <- c(parts, build_summary_area(parsed_reports))

  # --- Hub-level qualitative slides (always shown — user can add dynamically) ---
  slides <- if (!is.null(config$slides)) config$slides else list()
  parts <- c(parts, build_hub_slides_section(slides))

  parts <- c(parts, '</div>')

  return(paste(parts, collapse = "\n"))
}


#' Build a Report Index Card
#'
#' Each card clearly identifies its type (Tracker / Crosstabs) and shows
#' rich statistics extracted from the report metadata.
#'
#' @param parsed Parsed report object
#' @return HTML string for one card
build_report_card <- function(parsed) {
  key <- parsed$report_key
  type <- parsed$report_type
  meta <- parsed$metadata

  label <- meta$project_title
  if (is.null(label)) label <- key

  # Type badge
  badge_map <- list(
    tracker    = list(css = "hub-card-type-tracker",    label = "Tracker"),
    tabs       = list(css = "hub-card-type-crosstabs",  label = "Crosstabs"),
    confidence = list(css = "hub-card-type-confidence",  label = "Confidence"),
    catdriver  = list(css = "hub-card-type-analysis",    label = "Driver Analysis"),
    keydriver  = list(css = "hub-card-type-analysis",    label = "Key Drivers"),
    weighting  = list(css = "hub-card-type-analysis",    label = "Weighting"),
    maxdiff    = list(css = "hub-card-type-maxdiff",     label = "MaxDiff"),
    conjoint   = list(css = "hub-card-type-conjoint",    label = "Conjoint"),
    pricing    = list(css = "hub-card-type-pricing",     label = "Pricing"),
    segment    = list(css = "hub-card-type-segment",     label = "Segmentation")
  )
  badge_info <- badge_map[[type]]
  if (is.null(badge_info)) badge_info <- badge_map[["tabs"]]  # fallback
  type_badge <- sprintf(
    '<span class="hub-card-type-badge %s">%s</span>',
    badge_info$css, badge_info$label
  )

  # Build stats lines
  stats_lines <- character(0)
  if (type == "tracker") {
    # Prefer meta-tag values, fall back to badge_bar regex
    n_metrics <- meta$n_metrics
    n_waves <- meta$n_waves
    n_segments <- meta$n_segments
    baseline <- meta$baseline_label
    latest <- meta$latest_label

    # Fallback: parse badge bar for older reports without meta tags
    if (is.null(n_metrics) && !is.null(meta$badge_bar)) {
      nums <- regmatches(meta$badge_bar,
                         gregexpr("<strong>(\\d+)</strong>", meta$badge_bar))[[1]]
      if (length(nums) >= 1) n_metrics <- gsub("<[^>]+>", "", nums[1])
      if (length(nums) >= 2) n_waves <- gsub("<[^>]+>", "", nums[2])
      if (length(nums) >= 3) n_segments <- gsub("<[^>]+>", "", nums[3])
    }

    if (!is.null(n_metrics)) stats_lines <- c(stats_lines, sprintf("%s Metrics", n_metrics))
    if (!is.null(n_waves)) stats_lines <- c(stats_lines, sprintf("%s Waves", n_waves))
    if (!is.null(n_segments)) stats_lines <- c(stats_lines, sprintf("%s Segments", n_segments))

    # Wave range line (e.g., "2023 - Baseline, 2025 - Latest Wave")
    wave_parts <- character(0)
    if (!is.null(baseline) && nzchar(baseline)) {
      wave_parts <- c(wave_parts, sprintf("%s - Baseline", htmltools::htmlEscape(baseline)))
    }
    if (!is.null(latest) && nzchar(latest)) {
      wave_parts <- c(wave_parts, sprintf("%s - Latest Wave", htmltools::htmlEscape(latest)))
    }
    wave_range_html <- ""
    if (length(wave_parts) > 0) {
      wave_range_html <- sprintf(
        '<div class="hub-report-card-wave-range">%s</div>',
        paste(wave_parts, collapse = ", ")
      )
    }
  } else {
    # Crosstabs: use meta-tag values
    total_n <- meta$total_n
    n_questions <- meta$n_questions
    n_banner <- meta$n_banner_groups
    weighted <- meta$weighted
    fieldwork <- meta$fieldwork

    if (!is.null(total_n) && nzchar(total_n)) {
      stats_lines <- c(stats_lines, sprintf("n=%s", format(as.numeric(total_n), big.mark = ",")))
    }
    if (!is.null(n_questions) && nzchar(n_questions)) {
      stats_lines <- c(stats_lines, sprintf("%s Questions", n_questions))
    }
    if (!is.null(n_banner) && nzchar(n_banner)) {
      stats_lines <- c(stats_lines, sprintf("%s Banner Group%s", n_banner,
                                             if (n_banner != "1") "s" else ""))
    }
    if (!is.null(weighted) && nzchar(weighted)) {
      stats_lines <- c(stats_lines, if (weighted == "true") "Weighted" else "Unweighted")
    }
    if (!is.null(fieldwork) && nzchar(fieldwork)) {
      stats_lines <- c(stats_lines, sprintf("Fieldwork %s", htmltools::htmlEscape(fieldwork)))
    }

    wave_range_html <- ""
  }

  stats_html <- paste(stats_lines, collapse = " &middot; ")

  sprintf(
    '<div class="hub-report-card" onclick="ReportHub.switchReport(\'%s\')">
  %s
  <div class="hub-report-card-label">%s</div>
  <div class="hub-report-card-stats">%s</div>
  %s
  <span class="hub-report-card-link">View Report &rarr;</span>
</div>',
    key,
    type_badge,
    htmltools::htmlEscape(label),
    stats_html,
    wave_range_html
  )
}


#' Build Combined Summary Area
#'
#' Creates editable summary sections for each report on the overview page.
#' With the iframe approach, we don't extract text from report content —
#' summaries are either provided via config or entered by the user.
#'
#' @param parsed_reports List of parsed report objects
#' @return HTML string
build_summary_area <- function(parsed_reports) {
  parts <- '<div class="hub-summary-area">'

  for (parsed in parsed_reports) {
    key <- parsed$report_key
    report_label <- parsed$metadata$project_title
    if (is.null(report_label)) report_label <- key

    label <- paste0(report_label, " \u2014 Summary")

    parts <- paste0(parts, sprintf(
      '<div class="hub-text-section hub-summary-section" id="hub-text-%s-summary">
  <div class="hub-summary-header">
    <div class="hub-summary-label">%s</div>
    <button class="hub-pin-summary-btn" onclick="ReportHub.pinHubText(\'%s-summary\')" title="Pin this section">\U0001F4CC Pin to Views</button>
  </div>
  <div class="hub-text-rendered hub-md-content" id="hub-text-rendered-%s-summary"
       ondblclick="ReportHub.toggleHubTextEdit(\'%s-summary\')">
    <p style="color:#94a3b8;font-style:italic">Double-click to add summary notes for this report</p>
  </div>
  <textarea class="hub-text-editor" id="hub-text-editor-%s-summary"
            style="display:none"
            onblur="ReportHub.finishHubTextEdit(\'%s-summary\')"></textarea>
</div>',
      key, htmltools::htmlEscape(label), key, key, key, key, key
    ))
  }

  parts <- paste0(parts, '</div>')
  return(parts)
}


## extract_summary_sections and extract_dash_textarea removed —
## iframe approach preserves report HTML as-is, no content extraction needed.


#' Build a Hub-Level Text Section (Executive Summary or Background)
#'
#' Creates an editable text section with a pin button, pre-populated
#' with content from the hub config. Supports markdown syntax.
#'
#' @param id Section identifier (e.g., "executive-summary", "background")
#' @param label Display label
#' @param content Text content (supports markdown syntax)
#' @return HTML string
build_hub_text_section <- function(id, label, content) {
  # Escape content for safe embedding in the textarea (markdown source)
  escaped_content <- htmltools::htmlEscape(content)

  sprintf(
    '<div class="hub-text-section" id="hub-text-%s">
  <div class="hub-summary-header">
    <div class="hub-summary-label">%s</div>
    <button class="hub-pin-summary-btn" onclick="ReportHub.pinHubText(\'%s\')" title="Pin this section">\U0001F4CC Pin to Views</button>
  </div>
  <div class="hub-text-rendered hub-md-content" id="hub-text-rendered-%s"
       ondblclick="ReportHub.toggleHubTextEdit(\'%s\')"></div>
  <textarea class="hub-text-editor" id="hub-text-editor-%s"
            style="display:none"
            onblur="ReportHub.finishHubTextEdit(\'%s\')">%s</textarea>
</div>',
    id, htmltools::htmlEscape(label), id, id, id, id, id, escaped_content
  )
}


#' Build Hub-Level Qualitative Slides Section
#'
#' Creates slide cards from hub config, each with a title + markdown body,
#' editable via double-click, and pinnable to the pinned views.
#'
#' @param slides List of slide objects from config (id, title, content, order)
#' @return HTML string
build_hub_slides_section <- function(slides) {
  parts <- character(0)
  parts <- c(parts, '<div class="hub-slides-section">')
  parts <- c(parts, '<div class="hub-slides-header">')
  parts <- c(parts, '  <div class="hub-summary-label">Insights & Analysis</div>')
  parts <- c(parts, '  <button class="hub-add-slide-btn" onclick="ReportHub.addHubSlide()">+ Add Insight</button>')
  parts <- c(parts, '</div>')
  parts <- c(parts, '<div class="hub-slides-grid" id="hub-slides-grid">')

  for (slide in slides) {
    escaped_content <- htmltools::htmlEscape(slide$content)
    escaped_title <- htmltools::htmlEscape(slide$title)

    # Image data (if provided via config)
    image_data <- if (!is.null(slide$image_data) && nzchar(slide$image_data %||% "")) slide$image_data else ""
    img_preview_style <- if (nzchar(image_data)) "" else "display:none;"
    img_src <- if (nzchar(image_data)) image_data else ""

    parts <- c(parts, sprintf(
      '<div class="hub-slide-card" data-slide-id="%s">
  <div class="hub-slide-title-row">
    <input class="hub-slide-title" value="%s"
           onchange="ReportHub.updateHubSlideTitle(\'%s\', this.value)">
    <button class="hub-slide-img-btn" onclick="ReportHub.triggerHubSlideImage(\'%s\')" title="Add image">&#x1F5BC;</button>
    <button class="hub-pin-summary-btn" onclick="ReportHub.pinHubSlide(\'%s\')" title="Pin this slide">\U0001F4CC Pin</button>
    <button class="hub-slide-remove-btn" onclick="ReportHub.removeHubSlide(\'%s\')" title="Remove this slide">\u00D7</button>
  </div>
  <div class="hub-slide-img-preview" style="%s">
    <img class="hub-slide-img-thumb" src="%s">
    <button class="hub-slide-img-remove" onclick="ReportHub.removeHubSlideImage(\'%s\')" title="Remove image">&times;</button>
  </div>
  <input type="file" class="hub-slide-img-input" accept="image/*" style="display:none;"
         onchange="ReportHub.handleHubSlideImage(\'%s\', this)">
  <div class="hub-slide-rendered hub-md-content" data-slide-id="%s"
       ondblclick="ReportHub.toggleHubSlideEdit(\'%s\')"></div>
  <textarea class="hub-slide-editor" data-slide-id="%s"
            style="display:none"
            onblur="ReportHub.finishHubSlideEdit(\'%s\')">%s</textarea>
  <textarea class="hub-slide-img-store" style="display:none;">%s</textarea>
</div>',
      slide$id, escaped_title, slide$id,
      slide$id,
      slide$id, slide$id,
      img_preview_style, img_src, slide$id,
      slide$id,
      slide$id, slide$id, slide$id, slide$id,
      escaped_content,
      htmltools::htmlEscape(image_data)
    ))
  }

  parts <- c(parts, '</div>')
  parts <- c(parts, '</div>')

  return(paste(parts, collapse = "\n"))
}


#' Build Hub-Level About Panel
#'
#' Creates the About tab content for the consolidated report, showing
#' analyst contact info, appendices references, and editable notes.
#' Mirrors the individual report About tab pattern.
#'
#' @param config Validated config from guard
#' @return HTML string for the about panel (empty string if no about fields set)
build_hub_about_panel <- function(config) {
  s <- config$settings

  # Check if any about field is set
  has_content <- any(!sapply(
    list(s$analyst_name, s$analyst_email, s$analyst_phone, s$appendices, s$notes),
    is.null
  ))
  if (!has_content) return("")

  parts <- character(0)
  parts <- c(parts, '<div class="hub-panel" data-hub-panel="about">')
  parts <- c(parts, '<div class="hub-about-section">')

  # --- Contact grid ---
  contact_items <- character(0)
  if (!is.null(s$analyst_name)) {
    contact_items <- c(contact_items, sprintf(
      '<div class="hub-about-contact-item"><span class="hub-about-label">Analyst</span><span class="hub-about-value">%s</span></div>',
      htmltools::htmlEscape(s$analyst_name)
    ))
  }
  if (!is.null(s$analyst_email)) {
    # Split on semicolons/commas to make each email a separate mailto link
    emails_raw <- trimws(unlist(strsplit(s$analyst_email, "[;,]")))
    emails_raw <- emails_raw[nzchar(emails_raw)]
    if (length(emails_raw) > 0) {
      email_links <- vapply(emails_raw, function(e) {
        e <- trimws(e)
        sprintf('<a class="hub-about-link" href="mailto:%s">%s</a>',
                htmltools::htmlEscape(e), htmltools::htmlEscape(e))
      }, character(1))
      email_html <- paste(email_links, collapse = '<br>')
      contact_items <- c(contact_items, sprintf(
        '<div class="hub-about-contact-item"><span class="hub-about-label">Email</span><span class="hub-about-value">%s</span></div>',
        email_html
      ))
    }
  }
  if (!is.null(s$analyst_phone)) {
    contact_items <- c(contact_items, sprintf(
      '<div class="hub-about-contact-item"><span class="hub-about-label">Phone</span><span class="hub-about-value">%s</span></div>',
      htmltools::htmlEscape(s$analyst_phone)
    ))
  }
  if (length(contact_items) > 0) {
    parts <- c(parts, '<div class="hub-about-contact-grid">')
    parts <- c(parts, contact_items)
    parts <- c(parts, '</div>')
  }

  # --- Appendices ---
  if (!is.null(s$appendices)) {
    parts <- c(parts, sprintf(
      '<div class="hub-about-appendices"><span class="hub-about-label">Appendices</span><span class="hub-about-value">%s</span></div>',
      htmltools::htmlEscape(s$appendices)
    ))
  }

  # --- Notes (editable markdown) ---
  notes_content <- if (!is.null(s$notes)) s$notes else ""
  escaped_notes <- htmltools::htmlEscape(notes_content)
  parts <- c(parts, sprintf(
    '<div class="hub-about-notes">
  <span class="hub-about-label">Notes</span>
  <div class="hub-about-notes-rendered hub-md-content" id="hub-about-notes-rendered"
       ondblclick="ReportHub.toggleHubAboutNotesEdit()"></div>
  <textarea class="hub-about-notes-editor" id="hub-about-notes-editor"
            style="display:none"
            onblur="ReportHub.finishHubAboutNotesEdit()">%s</textarea>
</div>',
    escaped_notes
  ))

  # --- Export section (Save/Print with helper text) ---
  parts <- c(parts, '<div class="hub-about-export">')
  parts <- c(parts, '<div class="closing-divider"></div>')
  parts <- c(parts, '<div class="closing-content">')
  parts <- c(parts, '<div class="closing-label" style="margin-bottom:12px;">Export</div>')
  parts <- c(parts, '<div style="display:flex;gap:10px;flex-wrap:wrap;">')
  parts <- c(parts, '<button class="export-btn" onclick="ReportHub.saveReportHTML()" style="font-size:13px;padding:8px 18px;">\U0001F4BE Save Report</button>')
  parts <- c(parts, '<button class="export-btn" onclick="ReportHub.printReport()" style="font-size:13px;padding:8px 18px;">\U0001F5A8 Print Report</button>')
  parts <- c(parts, '</div>')
  parts <- c(parts, '<p style="font-size:11px;color:#94a3b8;margin-top:8px;line-height:1.5;">')
  parts <- c(parts, 'Save embeds all edits (insights, notes, slides) into the HTML file. ')
  parts <- c(parts, 'Print outputs the visible panels to PDF.</p>')
  parts <- c(parts, '</div>')
  parts <- c(parts, '</div>')

  parts <- c(parts, '</div>')  # close hub-about-section
  parts <- c(parts, '</div>')  # close hub-panel

  return(paste(parts, collapse = "\n"))
}
