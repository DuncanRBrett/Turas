#' HTML Report Parser (iframe approach)
#'
#' Reads a Turas HTML report file and extracts lightweight metadata
#' for the overview page. The full HTML is preserved as-is for iframe
#' embedding — no DOM extraction or manipulation needed.

#' Parse a Turas HTML Report for Hub Embedding
#'
#' Reads an HTML file and extracts only what the hub shell needs:
#' report type, metadata for overview cards, and the raw HTML string
#' for iframe srcdoc embedding. The report HTML is never modified.
#'
#' @param report_path Path to a Turas-generated HTML report file.
#' @param report_key Unique identifier for this report in the hub.
#'
#' @return TRS-compliant list with:
#'   \describe{
#'     \item{status}{"PASS" or "REFUSED"}
#'     \item{result}{List with report_key, report_type, metadata, raw_html}
#'     \item{message}{Summary of what was parsed}
#'   }
#'
#' @keywords internal
parse_html_report <- function(report_path, report_key) {

  if (!file.exists(report_path)) {
    return(list(
      status = "REFUSED",
      code = "IO_FILE_NOT_FOUND",
      message = sprintf("Report file not found: %s", report_path),
      how_to_fix = "Check the file path in the config Excel file."
    ))
  }

  # Read full file
  lines <- readLines(report_path, warn = FALSE, encoding = "UTF-8")
  html <- paste(lines, collapse = "\n")

  # --- Detect report type ---
  report_type <- detect_report_type(html)
  if (is.null(report_type)) {
    return(list(
      status = "REFUSED",
      code = "DATA_INVALID",
      message = sprintf("Cannot detect report type for: %s", basename(report_path)),
      how_to_fix = "The file must be a Turas-generated HTML report (tracker, tabs, catdriver, keydriver, weighting, confidence, maxdiff, conjoint, segment, or pricing)."
    ))
  }

  # --- Extract metadata from meta tags (for overview cards) ---
  metadata <- extract_meta_tags(html)

  # --- File size for diagnostics ---
  file_size <- file.info(report_path)$size

  return(list(
    status = "PASS",
    result = list(
      report_key = report_key,
      report_type = report_type,
      metadata = metadata,
      raw_html = html,
      file_size = file_size
    ),
    message = sprintf("Parsed %s report (%s)",
                      report_type,
                      format_file_size(file_size))
  ))
}


#' Detect Report Type from HTML Content
#'
#' Checks for an explicit meta tag first, then falls back to
#' structural markers for older reports.
#'
#' @param html Full HTML string
#' @return Report type string or NULL
#' @keywords internal
detect_report_type <- function(html) {
  # Check for explicit meta tag first (all modern Turas reports include this)
  for (type in c("tracker", "tabs", "catdriver", "keydriver", "weighting",
                  "confidence", "maxdiff", "conjoint", "segment", "pricing")) {
    pattern <- sprintf('<meta\\s+name="turas-report-type"\\s+content="%s"', type)
    if (grepl(pattern, html)) return(type)
  }
  # Fallback: detect by structural markers (older reports without meta tag)
  if (grepl('id="tab-crosstabs"', html, fixed = TRUE)) return("tabs")
  if (grepl('id="tab-metrics"', html, fixed = TRUE) &&
      grepl('id="tab-overview"', html, fixed = TRUE)) return("tracker")
  if (grepl('class="tk-header"', html, fixed = TRUE)) return("tracker")
  if (grepl('class="ci-header"', html, fixed = TRUE)) return("confidence")
  if (grepl('class="wt-header"', html, fixed = TRUE)) return("weighting")
  if (grepl('class="md-header"', html, fixed = TRUE) &&
      grepl('Turas MaxDiff', html, fixed = TRUE)) return("maxdiff")
  if (grepl('class="cj-header"', html, fixed = TRUE)) return("conjoint")
  if (grepl('class="seg-header"', html, fixed = TRUE)) return("segment")
  if (grepl('class="pr-header"', html, fixed = TRUE)) return("pricing")
  if (grepl('class="cd-header"', html, fixed = TRUE)) return("catdriver")
  if (grepl('class="kd-header"', html, fixed = TRUE)) return("keydriver")

  message("Report hub: could not detect report type.")
  return(NULL)
}


#' Extract Metadata from HTML Meta Tags
#'
#' Pulls key metadata from Turas meta tags for use in overview cards.
#' Works across all report types.
#'
#' @param html Full HTML string
#' @return Named list of metadata values
#' @keywords internal
extract_meta_tags <- function(html) {
  meta <- list()

  # Helper to extract a meta tag value
  get_meta <- function(name) {
    pattern <- sprintf('<meta\\s+name="%s"\\s+content="([^"]*)"', name)
    m <- regmatches(html, regexpr(pattern, html, perl = TRUE))
    if (length(m) > 0 && nzchar(m)) {
      return(sub(pattern, "\\1", m, perl = TRUE))
    }
    return(NULL)
  }

  # Common metadata
  meta$project_title <- get_meta("turas-project-title")
  meta$report_type <- get_meta("turas-report-type")
  meta$source_filename <- get_meta("turas-source-filename")

  # Tracker-specific
  meta$n_metrics <- get_meta("turas-n-metrics")
  meta$n_waves <- get_meta("turas-n-waves")
  meta$n_segments <- get_meta("turas-n-segments")
  meta$baseline_label <- get_meta("turas-baseline-label")
  meta$latest_label <- get_meta("turas-latest-label")

  # Crosstabs-specific
  meta$total_n <- get_meta("turas-total-n")
  meta$n_questions <- get_meta("turas-n-questions")
  meta$n_banner_groups <- get_meta("turas-n-banner-groups")
  meta$weighted <- get_meta("turas-weighted")
  meta$fieldwork <- get_meta("turas-fieldwork")

  # Fallback: extract title from <title> tag if no meta title
  if (is.null(meta$project_title)) {
    title_match <- regmatches(html, regexpr("<title>([^<]+)</title>", html, perl = TRUE))
    if (length(title_match) > 0 && nzchar(title_match)) {
      raw_title <- sub("<title>([^<]+)</title>", "\\1", title_match, perl = TRUE)
      # Decode common HTML entities so they don't get double-escaped later
      raw_title <- gsub("&mdash;", "\u2014", raw_title, fixed = TRUE)
      raw_title <- gsub("&ndash;", "\u2013", raw_title, fixed = TRUE)
      raw_title <- gsub("&amp;", "&", raw_title, fixed = TRUE)
      raw_title <- gsub("&lt;", "<", raw_title, fixed = TRUE)
      raw_title <- gsub("&gt;", ">", raw_title, fixed = TRUE)
      raw_title <- gsub("&quot;", "\"", raw_title, fixed = TRUE)
      raw_title <- gsub("&#39;", "'", raw_title, fixed = TRUE)
      meta$project_title <- raw_title
    }
  }

  return(meta)
}


#' Format File Size for Display
#'
#' @param bytes File size in bytes
#' @return Human-readable string
#' @keywords internal
format_file_size <- function(bytes) {
  if (bytes < 1024) return(sprintf("%d B", bytes))
  if (bytes < 1024^2) return(sprintf("%.1f KB", bytes / 1024))
  return(sprintf("%.1f MB", bytes / 1024^2))
}
