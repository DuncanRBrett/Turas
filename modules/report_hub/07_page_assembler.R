#' Page Assembler
#'
#' Assembles the final combined HTML document from all parsed,
#' rewritten components: header, navigation, content panels,
#' CSS, JS, and the unified pinned views panel.

#' Assemble the Combined Report HTML
#'
#' @param config Validated config from guard
#' @param parsed_reports List of parsed and namespace-rewritten report objects
#' @param overview_html HTML for the overview front page
#' @param navigation_html HTML for the two-tier navigation
#' @return Complete HTML document string
assemble_hub_html <- function(config, parsed_reports, overview_html, navigation_html) {

  parts <- character(0)

  # --- DOCTYPE and head ---
  parts <- c(parts, '<!DOCTYPE html>')
  parts <- c(parts, '<html lang="en">')
  parts <- c(parts, '<head>')
  parts <- c(parts, '  <meta charset="UTF-8"/>')
  parts <- c(parts, '  <meta name="viewport" content="width=device-width, initial-scale=1"/>')
  parts <- c(parts, '  <meta name="turas-report-type" content="hub"/>')
  parts <- c(parts, sprintf('  <title>%s</title>',
                             htmltools::htmlEscape(config$settings$project_title)))

  # --- CSS: hub styles first, then per-report styles ---
  hub_css <- build_hub_css(config)
  parts <- c(parts, sprintf('  <style>\n%s\n  </style>', hub_css))

  for (parsed in parsed_reports) {
    for (css_block in parsed$css_blocks) {
      parts <- c(parts, sprintf('  <style>/* %s styles */\n%s\n  </style>',
                                 parsed$report_key, css_block$content))
    }
  }

  parts <- c(parts, '</head>')

  # --- Body ---
  parts <- c(parts, sprintf('<body style="background:%s">', '#f8f7f5'))

  # --- Hub header ---
  parts <- c(parts, build_hub_header(config))

  # --- Navigation ---
  parts <- c(parts, navigation_html)

  # --- Overview panel ---
  parts <- c(parts, '<div class="hub-panel active" data-hub-panel="overview">')
  parts <- c(parts, overview_html)
  parts <- c(parts, '</div>')

  # --- Report panels ---
  for (parsed in parsed_reports) {
    key <- parsed$report_key
    parts <- c(parts, sprintf('<div class="hub-panel" data-hub-panel="%s">', key))

    # Include report-specific content panels
    for (panel_name in names(parsed$content_panels)) {
      parts <- c(parts, parsed$content_panels[[panel_name]])
    }

    # Include footer if present
    if (nzchar(parsed$footer)) {
      parts <- c(parts, parsed$footer)
    }

    # Include help overlay if present (extracted separately from content panels)
    if (!is.null(parsed$help_overlay) && nzchar(parsed$help_overlay)) {
      parts <- c(parts, parsed$help_overlay)
    }

    parts <- c(parts, '</div>')
  }

  # --- Unified pinned views panel ---
  parts <- c(parts, build_pinned_panel())

  # --- About panel (if any about fields configured) ---
  about_html <- build_hub_about_panel(config)
  if (nzchar(about_html)) {
    parts <- c(parts, about_html)
  }

  # --- Data scripts ---
  # Unified pinned data store (pass report configs for source labels)
  merged_pins <- merge_pinned_data(parsed_reports, config$reports)
  parts <- c(parts, sprintf(
    '<script type="application/json" id="hub-pinned-data">%s</script>',
    merged_pins
  ))

  # Per-report data scripts (banner groups, segments, etc.)
  for (parsed in parsed_reports) {
    for (ds in parsed$data_scripts) {
      # Skip pinned-views-data (now unified)
      if (!is.null(ds$id) && grepl("pinned-views-data", ds$id)) next
      parts <- c(parts, sprintf('%s%s</script>', ds$open_tag, ds$content))
    }
  }

  # --- JavaScript ---
  # Hub JS first
  hub_js <- build_hub_js()
  parts <- c(parts, sprintf('<script>\n%s\n</script>', hub_js))

  # Per-report namespaced JS
  for (parsed in parsed_reports) {
    parts <- c(parts, sprintf('<script>/* %s JS */\n%s\n</script>',
                               parsed$report_key, parsed$wrapped_js))
  }

  # Initialization script
  init_js <- build_init_js(parsed_reports)
  parts <- c(parts, sprintf('<script>\n%s\n</script>', init_js))

  # --- Close ---
  parts <- c(parts, '</body>')
  parts <- c(parts, '</html>')

  return(paste(parts, collapse = "\n"))
}


#' Build Hub CSS from Template File
#'
#' Reads the hub stylesheet from the assets/hub_styles.css file and
#' substitutes colour tokens (BRAND_COLOUR, ACCENT_COLOUR) with the
#' values specified in the hub config. Falls back to a minimal inline
#' CSS string if the file cannot be found.
#'
#' @param config Validated config list from \code{guard_validate_hub_config()}.
#'   Must contain \code{config$settings$brand_colour} and
#'   \code{config$settings$accent_colour} (both optional, with defaults).
#'
#' @return A single CSS string with colour tokens replaced, ready for
#'   embedding in a \code{<style>} tag.
build_hub_css <- function(config) {
  css_path <- file.path(dirname(sys.frame(1)$ofile %||% "."), "assets", "hub_styles.css")

  # Fallback: try relative to module root
  if (!file.exists(css_path)) {
    css_path <- file.path("modules", "report_hub", "assets", "hub_styles.css")
  }

  if (file.exists(css_path)) {
    css <- paste(readLines(css_path, warn = FALSE), collapse = "\n")
  } else {
    # Inline fallback (minimal)
    css <- ":root { --hub-brand: #323367; --hub-accent: #CC9900; }"
  }

  # Substitute colour tokens
  brand <- config$settings$brand_colour %||% "#323367"
  accent <- config$settings$accent_colour %||% "#CC9900"

  css <- gsub("BRAND_COLOUR", brand, css, fixed = TRUE)
  css <- gsub("ACCENT_COLOUR", accent, css, fixed = TRUE)

  return(css)
}


#' Build Hub Header HTML
#'
#' Generates the top-level header bar for the combined report hub.
#' The header includes the project title, a "Prepared by / for" subtitle,
#' a "Powered by Turas Analytics" line, a creation date (which the client-side
#' JS updates to "Last saved {date}" on save), Save and Print action buttons,
#' and an optional base64-encoded logo image.
#'
#' Header layout:
#' \itemize{
#'   \item Title (project_title)
#'   \item Subtitle line 1: "Prepared by \{company_name\} for \{client_name\}"
#'   \item Subtitle line 2: "Powered by Turas Analytics"
#'   \item Date line: "Created \{date\}" (updates to "Last saved \{date\}" on save)
#' }
#'
#' @param config Validated config list from \code{guard_validate_hub_config()}.
#'   Uses \code{config$settings$project_title}, \code{config$settings$company_name},
#'   \code{config$settings$client_name}, and \code{config$settings$logo_path}.
#'
#' @return A single HTML string containing the complete hub header \code{<div>}.
build_hub_header <- function(config) {
  logo_html <- ""
  if (!is.null(config$settings$logo_path) && file.exists(config$settings$logo_path)) {
    # Read and base64 encode the logo
    logo_raw <- readBin(config$settings$logo_path, "raw",
                        file.info(config$settings$logo_path)$size)
    logo_ext <- tolower(tools::file_ext(config$settings$logo_path))
    mime <- switch(logo_ext,
                   png = "image/png",
                   jpg = , jpeg = "image/jpeg",
                   svg = "image/svg+xml",
                   "image/png")
    logo_b64 <- base64enc::base64encode(logo_raw)
    logo_html <- sprintf(
      '<div class="hub-logo"><img src="data:%s;base64,%s" alt="Logo"></div>',
      mime, logo_b64
    )
  }

  # Build "Prepared by X for Y" line
  prepared_parts <- character(0)
  company <- config$settings$company_name
  client <- config$settings$client_name
  if (!is.null(company) && nzchar(company)) {
    prepared_parts <- c(prepared_parts, sprintf("Prepared by <strong>%s</strong>",
                                                 htmltools::htmlEscape(company)))
  }
  if (!is.null(client) && nzchar(client)) {
    prepared_parts <- c(prepared_parts, sprintf("for <strong>%s</strong>",
                                                 htmltools::htmlEscape(client)))
  }
  prepared_line <- paste(prepared_parts, collapse = " ")

  # Date line: "Created {date}" — JS will update to "Last saved ..." on save

  created_date <- format(Sys.Date(), "%d %b %Y")

  sprintf(
    '<div class="hub-header">
  <div class="hub-header-inner">
    %s
    <div class="hub-header-text">
      <div class="hub-header-title">%s</div>
      <div class="hub-header-subtitle">%s</div>
      <div class="hub-header-subtitle hub-header-powered">Powered by Turas Analytics</div>
    </div>
    <div class="hub-header-right">
      <div class="hub-header-date" id="hub-header-date">Created %s</div>
      <div class="hub-header-actions">
        <button class="hub-save-btn" onclick="ReportHub.saveReportHTML()">Save Report</button>
        <button class="hub-print-btn" onclick="ReportHub.printReport()">Print</button>
      </div>
    </div>
  </div>
</div>',
    logo_html,
    htmltools::htmlEscape(config$settings$project_title),
    prepared_line,
    htmltools::htmlEscape(created_date)
  )
}


#' Build the Unified Pinned Views Panel HTML
#'
#' @return HTML string
build_pinned_panel <- function() {
  '<div class="hub-panel" data-hub-panel="pinned">
  <div class="hub-pinned-panel">
    <div class="hub-pinned-toolbar" id="hub-pinned-toolbar" style="display:none;">
      <button class="hub-toolbar-btn" onclick="ReportHub.addSection()">+ Add Section</button>
      <button class="hub-toolbar-btn" onclick="ReportHub.exportAllPins()">Export All as PNGs</button>
      <button class="hub-toolbar-btn" onclick="window.print()">Print / PDF</button>
    </div>
    <div id="hub-pinned-cards"></div>
    <div id="hub-pinned-empty" class="hub-pinned-empty">
      No pinned views yet. Pin items from the Tracker or Crosstabs reports to build your curated collection.
    </div>
  </div>
</div>'
}


#' Merge Pinned Data from All Reports
#'
#' @param parsed_reports List of parsed report objects
#' @param report_configs List of report config objects (with $key and $label)
#' @return JSON string of merged pinned items
merge_pinned_data <- function(parsed_reports, report_configs = NULL) {
  all_pins <- list()

  # Build key -> label lookup from config
  label_map <- list()
  if (!is.null(report_configs)) {
    for (rc in report_configs) {
      label_map[[rc$key]] <- rc$label
    }
  }

  for (parsed in parsed_reports) {
    pins_json <- parsed$pinned_data
    if (is.null(pins_json) || pins_json == "[]") next

    pins <- tryCatch(
      jsonlite::fromJSON(pins_json, simplifyVector = FALSE),
      error = function(e) {
        message(sprintf("Report hub: failed to parse pinned data for '%s': %s",
                        parsed$report_key, e$message))
        list()
      }
    )

    for (pin in pins) {
      pin$source <- parsed$report_key
      pin$type <- "pin"
      # Add human-readable source label from config
      if (!is.null(label_map[[parsed$report_key]])) {
        pin$sourceLabel <- label_map[[parsed$report_key]]
      }
      all_pins <- c(all_pins, list(pin))
    }
  }

  if (length(all_pins) == 0) return("[]")
  return(jsonlite::toJSON(all_pins, auto_unbox = TRUE))
}


#' Build Hub JavaScript from Source Files
#'
#' Reads and concatenates the hub-level JavaScript source files from the
#' \code{js/} directory within the report_hub module. The files loaded are:
#' \code{hub_id_resolver.js}, \code{hub_navigation.js}, and \code{hub_pinned.js}.
#' Falls back to a relative path if the script-relative path cannot be resolved.
#'
#' @return A single JavaScript string containing all hub JS code, ready for
#'   embedding in a \code{<script>} tag.
build_hub_js <- function() {
  js_dir <- file.path(dirname(sys.frame(1)$ofile %||% "."), "js")

  # Fallback path
  if (!dir.exists(js_dir)) {
    js_dir <- file.path("modules", "report_hub", "js")
  }

  js_files <- c("hub_id_resolver.js", "hub_navigation.js", "hub_pinned.js")
  js_parts <- character(0)

  for (f in js_files) {
    fpath <- file.path(js_dir, f)
    if (file.exists(fpath)) {
      js_parts <- c(js_parts, paste(readLines(fpath, warn = FALSE), collapse = "\n"))
    }
  }

  return(paste(js_parts, collapse = "\n\n"))
}


#' Build Initialization JavaScript
#'
#' Generates a \code{DOMContentLoaded} event handler that initialises all
#' hub components in the correct order: hub navigation, per-report init
#' calls (TrackerReport or TabsReport), hub-level text sections and
#' qualitative slides rendering, and pinned views hydration.
#'
#' @param parsed_reports List of parsed and namespace-rewritten report objects.
#'   Each element must have a \code{report_type} field (either \code{"tracker"}
#'   or \code{"tabs"}) to determine which namespace init function to call.
#'
#' @return A JavaScript string containing a \code{DOMContentLoaded} event
#'   listener with all initialisation calls, ready for embedding in a
#'   \code{<script>} tag.
build_init_js <- function(parsed_reports) {
  init_calls <- character(0)

  # Initialize hub navigation
  init_calls <- c(init_calls, "ReportHub.initNavigation();")

  # Initialize each report
  for (parsed in parsed_reports) {
    ns_name <- if (parsed$report_type == "tracker") "TrackerReport" else "TabsReport"
    init_calls <- c(init_calls, sprintf(
      "if (typeof %s !== 'undefined' && %s.init) { %s.init(); }",
      ns_name, ns_name, ns_name
    ))
  }

  # Render hub-level text sections (executive summary, background)
  init_calls <- c(init_calls, "if (ReportHub.renderHubTextSections) ReportHub.renderHubTextSections();")

  # Render hub-level qualitative slides
  init_calls <- c(init_calls, "if (ReportHub.renderHubSlides) ReportHub.renderHubSlides();")

  # Hydrate pinned views
  init_calls <- c(init_calls, "ReportHub.hydratePinnedViews();")

  sprintf(
    'document.addEventListener("DOMContentLoaded", function() {\n  %s\n});',
    paste(init_calls, collapse = "\n  ")
  )
}


#' Null-coalescing operator
#' @param x LHS
#' @param y RHS (default)
#' @return x if not NULL, else y
`%||%` <- function(x, y) if (is.null(x)) y else x
