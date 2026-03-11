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

  # --- Hub-level qualitative slides (from config, if provided) ---
  if (!is.null(config$slides) && length(config$slides) > 0) {
    parts <- c(parts, build_hub_slides_section(config$slides))
  }

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
  if (type == "tracker") {
    type_badge <- '<span class="hub-card-type-badge hub-card-type-tracker">Tracker</span>'
  } else {
    type_badge <- '<span class="hub-card-type-badge hub-card-type-crosstabs">Crosstabs</span>'
  }

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
#' Extracts editable summary text from each report's summary panel
#' and presents them as labelled editable sections.
#'
#' @param parsed_reports List of parsed report objects
#' @return HTML string
build_summary_area <- function(parsed_reports) {
  parts <- '<div class="hub-summary-area">'

  for (parsed in parsed_reports) {
    label <- if (parsed$report_type == "tracker") "Tracker Summary" else "Crosstabs Summary"
    key <- parsed$report_key

    # Try to extract existing summary text from contenteditable divs
    summary_text <- extract_summary_text(parsed)

    parts <- paste0(parts, sprintf(
      '<div class="hub-summary-section">
  <div class="hub-summary-header">
    <div class="hub-summary-label">%s</div>
    <button class="hub-pin-summary-btn" onclick="ReportHub.pinOverviewSummary(\'%s\')" title="Pin this summary">\U0001F4CC Pin to Views</button>
  </div>
  <div class="hub-summary-editor" contenteditable="true" data-placeholder="Add summary for %s..." data-source="%s">%s</div>
</div>',
      htmltools::htmlEscape(label),
      key,
      htmltools::htmlEscape(label),
      key,
      summary_text
    ))
  }

  parts <- paste0(parts, '</div>')
  return(parts)
}


#' Extract Summary Text from a Parsed Report
#'
#' Looks for contenteditable summary areas in the summary panel.
#'
#' @param parsed Parsed report object
#' @return Text content (HTML-safe)
extract_summary_text <- function(parsed) {
  # Look in the summary panel for contenteditable content
  summary_panel <- parsed$content_panels[["summary"]]
  if (is.null(summary_panel)) return("")

  # Try to find contenteditable divs with actual content
  # Match contenteditable="true">...content...</div>
  m <- gregexpr('contenteditable="true"[^>]*>([^<]+)<', summary_panel)[[1]]
  if (m[1] == -1) return("")

  # Return the first non-empty content found
  for (i in seq_along(m)) {
    len <- attr(m, "match.length")[i]
    match_str <- substr(summary_panel, m[i], m[i] + len - 1)
    content <- sub('contenteditable="true"[^>]*>([^<]+)<', '\\1', match_str)
    content <- trimws(content)
    if (nzchar(content) && !grepl("^(Add|Click|Type)", content)) {
      return(htmltools::htmlEscape(content))
    }
  }

  return("")
}


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
  parts <- c(parts, '</div>')
  parts <- c(parts, '<div class="hub-slides-grid" id="hub-slides-grid">')

  for (slide in slides) {
    escaped_content <- htmltools::htmlEscape(slide$content)
    escaped_title <- htmltools::htmlEscape(slide$title)

    parts <- c(parts, sprintf(
      '<div class="hub-slide-card" data-slide-id="%s">
  <div class="hub-slide-title-row">
    <input class="hub-slide-title" value="%s"
           onchange="ReportHub.updateHubSlideTitle(\'%s\', this.value)">
    <button class="hub-pin-summary-btn" onclick="ReportHub.pinHubSlide(\'%s\')" title="Pin this slide">\U0001F4CC Pin</button>
  </div>
  <div class="hub-slide-rendered hub-md-content" data-slide-id="%s"
       ondblclick="ReportHub.toggleHubSlideEdit(\'%s\')"></div>
  <textarea class="hub-slide-editor" data-slide-id="%s"
            style="display:none"
            onblur="ReportHub.finishHubSlideEdit(\'%s\')">%s</textarea>
</div>',
      slide$id, escaped_title, slide$id,
      slide$id, slide$id, slide$id, slide$id, slide$id,
      escaped_content
    ))
  }

  parts <- c(parts, '</div>')
  parts <- c(parts, '</div>')

  return(paste(parts, collapse = "\n"))
}
