#' Front Page Builder
#'
#' Generates the Overview tab content: project metadata strip,
#' report index cards, and combined executive summary areas.

#' Build the Overview Front Page HTML
#'
#' @param config Validated config from guard
#' @param parsed_reports List of parsed report objects
#' @return HTML string for the overview panel
build_front_page <- function(config, parsed_reports) {

  parts <- character(0)
  parts <- c(parts, '<div class="hub-overview">')

  # --- Metadata strip ---
  parts <- c(parts, build_meta_strip(config, parsed_reports))

  # --- Report index cards ---
  parts <- c(parts, '<div class="hub-report-cards">')
  for (parsed in parsed_reports) {
    parts <- c(parts, build_report_card(parsed))
  }
  parts <- c(parts, '</div>')

  # --- Combined summary area ---
  parts <- c(parts, build_summary_area(parsed_reports))

  parts <- c(parts, '</div>')

  return(paste(parts, collapse = "\n"))
}


#' Build Metadata Strip
#'
#' @param config Validated config
#' @param parsed_reports Parsed reports
#' @return HTML string
build_meta_strip <- function(config, parsed_reports) {
  badges <- character(0)

  # Client name
  if (!is.null(config$settings$client_name) && nzchar(config$settings$client_name)) {
    badges <- c(badges, sprintf(
      '<div class="hub-meta-badge">Prepared for <strong>%s</strong></div>',
      htmltools::htmlEscape(config$settings$client_name)
    ))
  }

  # Company
  badges <- c(badges, sprintf(
    '<div class="hub-meta-badge">By <strong>%s</strong></div>',
    htmltools::htmlEscape(config$settings$company_name)
  ))

  # Per-report stats

  for (parsed in parsed_reports) {
    meta <- parsed$metadata
    if (parsed$report_type == "tracker") {
      # Extract stats from badge bar HTML if available
      if (!is.null(meta$badge_bar)) {
        nums <- regmatches(meta$badge_bar,
                           gregexpr("<strong>(\\d+)</strong>", meta$badge_bar))[[1]]
        if (length(nums) >= 3) {
          n_metrics <- gsub("<[^>]+>", "", nums[1])
          n_waves <- gsub("<[^>]+>", "", nums[2])
          n_segments <- gsub("<[^>]+>", "", nums[3])
          badges <- c(badges, sprintf(
            '<div class="hub-meta-badge">Tracker: <strong>%s</strong> Metrics, <strong>%s</strong> Waves</div>',
            n_metrics, n_waves
          ))
        }
      }
    } else {
      # Tabs: extract from metadata
      if (!is.null(meta$fieldwork) && nzchar(meta$fieldwork)) {
        badges <- c(badges, sprintf(
          '<div class="hub-meta-badge">Fieldwork: <strong>%s</strong></div>',
          htmltools::htmlEscape(meta$fieldwork)
        ))
      }
    }
  }

  # Generation date
  badges <- c(badges, sprintf(
    '<div class="hub-meta-badge" id="hub-date-badge">Generated <strong>%s</strong></div>',
    format(Sys.Date(), "%b %Y")
  ))

  return(sprintf('<div class="hub-meta-strip">\n  %s\n</div>',
                 paste(badges, collapse = "\n  ")))
}


#' Build a Report Index Card
#'
#' @param parsed Parsed report object
#' @return HTML string for one card
build_report_card <- function(parsed) {
  key <- parsed$report_key
  type <- parsed$report_type
  meta <- parsed$metadata

  label <- meta$project_title
  if (is.null(label)) label <- key

  stats_lines <- character(0)
  if (type == "tracker") {
    if (!is.null(meta$badge_bar)) {
      nums <- regmatches(meta$badge_bar,
                         gregexpr("<strong>(\\d+)</strong>", meta$badge_bar))[[1]]
      if (length(nums) >= 3) {
        stats_lines <- c(stats_lines,
                         sprintf("%s Metrics", gsub("<[^>]+>", "", nums[1])),
                         sprintf("%s Waves", gsub("<[^>]+>", "", nums[2])),
                         sprintf("%s Segments", gsub("<[^>]+>", "", nums[3])))
      }
    }
  } else {
    n_panels <- length(parsed$content_panels)
    stats_lines <- c(stats_lines, sprintf("%d sections", n_panels))
    if (!is.null(meta$fieldwork)) {
      stats_lines <- c(stats_lines, sprintf("Fieldwork: %s", meta$fieldwork))
    }
  }

  stats_html <- paste(stats_lines, collapse = " &middot; ")

  sprintf(
    '<div class="hub-report-card" onclick="ReportHub.switchReport(\'%s\')">
  <div class="hub-report-card-label">%s</div>
  <div class="hub-report-card-stats">%s</div>
  <span class="hub-report-card-link">View Report &rarr;</span>
</div>',
    key,
    htmltools::htmlEscape(label),
    stats_html
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
  <div class="hub-summary-label">%s</div>
  <div class="hub-summary-editor" contenteditable="true" data-placeholder="Add summary for %s..." data-source="%s">%s</div>
</div>',
      htmltools::htmlEscape(label),
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
