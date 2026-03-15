# ==============================================================================
# TurasTracker HTML Report - Page Styling
# ==============================================================================
# CSS loading, brand colour substitution, and minification.
# Extracted from 03_page_builder.R for maintainability.
# VERSION: 3.0.0
# ==============================================================================


# Directory for standalone JS files (shared with 03_page_builder.R)
.tracker_js_dir <- (function() {
  if (exists(".tracker_lib_dir", envir = globalenv())) {
    file.path(get(".tracker_lib_dir", envir = globalenv()), "html_report", "js")
  } else {
    .ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
    if (is.null(.ofile) || !nzchar(.ofile %||% "")) {
      file.path(".", "js")
    } else {
      file.path(dirname(.ofile), "js")
    }
  }
})()


#' Minify JavaScript (R-based, no external dependencies)
#'
#' Strips block comments, line comments, and collapses whitespace.
#' Preserves string literals and regex patterns.
#'
#' @param js Character. JavaScript source code
#' @return Character. Minified JavaScript
#' @keywords internal
minify_js <- function(js) {
  # Strip block comments (/* ... */) — non-greedy
  js <- gsub("/\\*[\\s\\S]*?\\*/", "", js, perl = TRUE)
  # Strip line comments (// ...) but NOT inside strings
  # Only strip // at start of line or after whitespace (safe heuristic)
  js <- gsub("(^|[[:space:]])//[^\n]*", "\\1", js, perl = TRUE)
  # Collapse multiple blank lines to single newline
  js <- gsub("\n{3,}", "\n\n", js, perl = TRUE)
  # Remove leading/trailing whitespace per line (preserve indentation minimally)
  lines <- strsplit(js, "\n", fixed = TRUE)[[1]]
  lines <- trimws(lines, which = "right")
  # Remove blank lines entirely
  lines <- lines[nzchar(trimws(lines))]
  paste(lines, collapse = "\n")
}


#' Minify CSS (R-based, no external dependencies)
#'
#' Strips comments, collapses whitespace, and removes unnecessary newlines.
#'
#' @param css Character. CSS source code
#' @return Character. Minified CSS
#' @keywords internal
minify_css <- function(css) {
  # Strip block comments
  css <- gsub("/\\*[\\s\\S]*?\\*/", "", css, perl = TRUE)
  # Collapse whitespace around { } ; : ,
  css <- gsub("\\s*\\{\\s*", "{", css, perl = TRUE)
  css <- gsub("\\s*\\}\\s*", "}", css, perl = TRUE)
  css <- gsub("\\s*;\\s*", ";", css, perl = TRUE)
  css <- gsub("\\s*:\\s*", ":", css, perl = TRUE)
  css <- gsub("\\s*,\\s*", ",", css, perl = TRUE)
  # Collapse multiple whitespace to single space
  css <- gsub("\\s+", " ", css, perl = TRUE)
  # Remove space after { and before }
  css <- gsub("\\{ ", "{", css, fixed = TRUE)
  css <- gsub(" \\}", "}", css, fixed = TRUE)
  # Remove trailing semicolons before }
  css <- gsub(";}", "}", css, fixed = TRUE)
  trimws(css)
}


#' Build Tracker CSS
#'
#' Reads the external CSS file, substitutes brand/accent colours,
#' and returns minified CSS string.
#'
#' @param brand_colour Character. Brand colour hex code
#' @param accent_colour Character. Accent colour hex code
#' @return Character. Minified CSS string
#' @keywords internal
build_tracker_css <- function(brand_colour, accent_colour) {
  # CSS lives in assets/tracker_styles.css (extracted for maintainability)
  css_dir <- file.path(.tracker_js_dir, "..", "assets")
  css_path <- file.path(css_dir, "tracker_styles.css")

  if (!file.exists(css_path)) {
    cat(sprintf("  [WARN] CSS file not found: %s\n", css_path))
    return("")
  }

  css <- paste(readLines(css_path, warn = FALSE), collapse = "\n")
  css <- gsub("BRAND_COLOUR", brand_colour, css, fixed = TRUE)
  css <- gsub("ACCENT_COLOUR", accent_colour, css, fixed = TRUE)
  minify_css(css)
}


#' Read a Tracker JS File
#'
#' @param filename Character. JS filename to read from the js/ directory
#' @return Character. File contents, or empty string if not found
#' @keywords internal
read_tracker_js_file <- function(filename) {
  js_path <- file.path(.tracker_js_dir, filename)
  if (!file.exists(js_path)) {
    cat(sprintf("  [WARN] JavaScript file not found: %s\n", js_path))
    return("")
  }
  paste(readLines(js_path, warn = FALSE), collapse = "\n")
}


#' Build Tracker JavaScript
#'
#' Reads JS files from the js/ directory, embeds data variables,
#' and returns combined minified JavaScript string.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @return Character. Combined and minified JavaScript
#' @keywords internal
build_tracker_javascript <- function(html_data) {

  js_parts <- c()

  # Embed segment data as JSON
  segments_json <- jsonlite::toJSON(html_data$segments, auto_unbox = TRUE)
  js_parts <- c(js_parts, sprintf("var SEGMENTS = %s;", segments_json))
  js_parts <- c(js_parts, sprintf("var BASELINE_WAVE = %s;",
                                    jsonlite::toJSON(html_data$baseline_wave, auto_unbox = TRUE)))
  js_parts <- c(js_parts, sprintf("var N_WAVES = %d;", length(html_data$waves)))

  # Embed segment group structure for hierarchical chip selector
  segment_groups <- derive_segment_groups(html_data$segments)
  segment_groups_json <- jsonlite::toJSON(segment_groups, auto_unbox = TRUE)
  js_parts <- c(js_parts, sprintf("var SEGMENT_GROUPS = %s;", segment_groups_json))

  # Metric nav filter functions loaded from external JS file (first in list)
  js_files <- c("metric_nav_filter.js",
                 "tab_navigation.js", "metrics_view.js", "pinned_views.js",
                 "core_navigation.js", "chart_controls.js",
                 "chart_tooltip.js", "qualitative_slides.js",
                 "annotations.js",
                 "table_export.js", "slide_export.js")

  for (js_file in js_files) {
    js_content <- read_tracker_js_file(js_file)
    if (nzchar(js_content)) {
      js_parts <- c(js_parts, sprintf("\n/* === %s === */\n%s", js_file, js_content))
    } else {
      js_parts <- c(js_parts, sprintf("\n/* === %s === NOT FOUND */", js_file))
    }
  }

  js_combined <- paste(js_parts, collapse = "\n")
  minify_js(js_combined)
}
