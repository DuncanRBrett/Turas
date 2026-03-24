#' Page Assembler (iframe approach)
#'
#' Assembles the final combined HTML document using iframe isolation.
#' Each report's complete HTML is stored as a JSON-encoded string and
#' loaded into an iframe via srcdoc at runtime. This guarantees that
#' reports behave identically to their standalone versions.

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
})

#' Assemble the Combined Report HTML
#'
#' @param config Validated config from guard
#' @param parsed_reports List of parsed report objects (with raw_html)
#' @param overview_html HTML for the overview front page
#' @param navigation_html HTML for the Level 1 navigation
#' @return Complete HTML document string
assemble_hub_html <- function(config, parsed_reports, overview_html, navigation_html) {

  # Guard: htmltools is required for HTML escaping throughout assembly
  if (!requireNamespace("htmltools", quietly = TRUE)) {
    return(list(
      status = "REFUSED",
      code = "PKG_MISSING_HTMLTOOLS",
      message = "Package 'htmltools' is required for HTML assembly but is not installed.",
      how_to_fix = "Install it with: install.packages('htmltools')"
    ))
  }

  # Guard: base64enc is required for report embedding
  if (!requireNamespace("base64enc", quietly = TRUE)) {
    return(list(
      status = "REFUSED",
      code = "PKG_MISSING_BASE64ENC",
      message = "Package 'base64enc' is required for report embedding but is not installed.",
      how_to_fix = "Install it with: install.packages('base64enc')"
    ))
  }

  parts <- character(0)

  # --- DOCTYPE and head ---
  cat("  [hub-version: iframe-b64] Assembling with base64 iframe encoding\n")
  parts <- c(parts, '<!DOCTYPE html>')
  parts <- c(parts, '<!-- hub-version: iframe-b64 -->')
  parts <- c(parts, '<html lang="en">')
  parts <- c(parts, '<head>')
  parts <- c(parts, '  <meta charset="UTF-8"/>')
  parts <- c(parts, '  <meta name="viewport" content="width=device-width, initial-scale=1"/>')
  parts <- c(parts, '  <meta name="turas-report-type" content="hub"/>')
  parts <- c(parts, sprintf('  <meta name="turas-original-filename" content="%s"/>',
                             htmltools::htmlEscape(config$original_filename %||% "")))
  parts <- c(parts, sprintf('  <title>%s</title>',
                             htmltools::htmlEscape(config$settings$project_title)))

  # --- CSS: hub styles only (report styles live inside iframes) ---
  hub_css <- build_hub_css(config)
  parts <- c(parts, sprintf('  <style>\n%s\n  </style>', hub_css))

  parts <- c(parts, '</head>')

  # --- Body ---
  parts <- c(parts, '<body>')

  # --- Hub header ---
  parts <- c(parts, build_hub_header(config))

  # --- Navigation ---
  parts <- c(parts, navigation_html)

  # --- Overview panel ---
  parts <- c(parts, '<div class="hub-panel active" data-hub-panel="overview">')
  parts <- c(parts, overview_html)
  parts <- c(parts, '</div>')

  # --- Report panels (each contains an iframe) ---
  for (parsed in parsed_reports) {
    key <- parsed$report_key
    parts <- c(parts, sprintf(
      '<div class="hub-panel" data-hub-panel="%s">
  <iframe id="hub-iframe-%s" class="hub-report-iframe" allow="clipboard-write *"></iframe>
  <div class="hub-iframe-loading" id="hub-loading-%s">
    <div class="hub-loading-spinner"></div>
    <div class="hub-loading-text">Loading report...</div>
  </div>
</div>',
      key, key, key
    ))
  }

  # --- Unified pinned views panel ---
  parts <- c(parts, build_pinned_panel())

  # --- About panel (if any about fields configured) ---
  about_html <- build_hub_about_panel(config)
  if (nzchar(about_html)) {
    parts <- c(parts, about_html)
  }

  # --- Report HTML data (base64-encoded, for iframe srcdoc) ---
  # Base64 uses only A-Za-z0-9+/= characters, so it cannot interfere
  # with HTML parsing (no < > / that could form closing tags).
  # The ~33% size overhead is the cost of guaranteed roundtrip safety
  # through unlimited create → edit → save → reopen cycles.
  for (parsed in parsed_reports) {
    b64_html <- base64enc::base64encode(charToRaw(enc2utf8(parsed$raw_html)))
    cat(sprintf("    Base64-encoded %s: %s -> %s\n",
                parsed$report_key,
                format_file_size(nchar(parsed$raw_html)),
                format_file_size(nchar(b64_html))))

    parts <- c(parts, paste0(
      '<script type="text/plain" data-encoding="base64" id="hub-report-',
      parsed$report_key, '">',
      b64_html,
      '</script>'
    ))
  }

  # --- Hub-level pinned data store ---
  parts <- c(parts, '<script type="application/json" id="hub-pinned-data">[]</script>')

  # --- JavaScript ---
  # Hub JS (navigation, pinned views, init)
  hub_js <- build_hub_js(config)
  parts <- c(parts, sprintf('<script>\n%s\n</script>', hub_js))

  # Initialization script
  report_keys <- vapply(parsed_reports, function(p) p$report_key, character(1))
  init_js <- build_init_js(report_keys)
  parts <- c(parts, sprintf('<script>\n%s\n</script>', init_js))

  # --- Close ---
  parts <- c(parts, '</body>')
  parts <- c(parts, '</html>')

  return(paste(parts, collapse = "\n"))
}


#' Build Hub CSS from Template File
#'
#' @param config Validated config list
#' @return CSS string with colour tokens replaced
build_hub_css <- function(config) {
  # Resolve asset path: prefer explicit hub_dir from config (set by 00_main.R),
  # fall back to sys.frame detection, then hard-coded path.
  # This ensures correct resolution in Shiny, callr, and interactive sessions.
  hub_base <- config$hub_dir %||% dirname(sys.frame(1)$ofile %||% ".")
  css_path <- file.path(hub_base, "assets", "hub_styles.css")
  if (!file.exists(css_path)) {
    css_path <- file.path("modules", "report_hub", "assets", "hub_styles.css")
  }

  if (file.exists(css_path)) {
    css <- paste(readLines(css_path, warn = FALSE), collapse = "\n")
  } else {
    css <- ":root { --hub-brand: #323367; --hub-accent: #CC9900; }"
  }

  brand <- config$settings$brand_colour %||% "#323367"
  accent <- config$settings$accent_colour %||% "#CC9900"

  css <- gsub("BRAND_COLOUR", brand, css, fixed = TRUE)
  css <- gsub("ACCENT_COLOUR", accent, css, fixed = TRUE)

  # Prepend shared design system CSS (with font embed for the hub shell)
  shared_css <- turas_base_css(
    brand_colour = brand,
    accent_colour = accent,
    prefix = "t",
    include_font = TRUE
  )
  css <- paste(shared_css, css, sep = "\n\n")

  return(css)
}


#' Build Hub Header HTML
#'
#' @param config Validated config list
#' @return HTML string for the hub header
build_hub_header <- function(config) {
  logo_html <- ""
  if (!is.null(config$settings$logo_path) && file.exists(config$settings$logo_path)) {
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


#' Build the Unified Pinned Views Panel
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
      No pinned views yet. Pin charts, tables, or insights from any report tab &mdash; they will appear here as a curated collection.
    </div>
  </div>
</div>'
}


#' Build Hub JavaScript from Source Files
#'
#' @return JavaScript string
build_hub_js <- function(config = NULL) {
  # Resolve JS directory: prefer explicit hub_dir from config (set by 00_main.R),
  # fall back to sys.frame detection, then hard-coded path.
  hub_base <- if (!is.null(config)) config$hub_dir else NULL
  hub_base <- hub_base %||% dirname(sys.frame(1)$ofile %||% ".")
  js_dir <- file.path(hub_base, "js")
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
#' @param report_keys Character vector of report keys
#' @return JavaScript string
build_init_js <- function(report_keys) {
  # Build report keys array for JS
  keys_js <- paste(sprintf('"%s"', report_keys), collapse = ", ")

  sprintf(
    'document.addEventListener("DOMContentLoaded", function() {
  // Register report keys and initialize hub
  ReportHub.reportKeys = [%s];
  ReportHub.initNavigation();
  ReportHub.hydratePinnedViews();

  // Render hub-level markdown text sections
  if (ReportHub.renderHubTextSections) ReportHub.renderHubTextSections();
  if (ReportHub.renderHubSlides) ReportHub.renderHubSlides();
});',
    keys_js
  )
}


# %||% operator defined in 00_main.R (sourced first)
