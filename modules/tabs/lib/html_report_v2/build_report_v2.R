# ==============================================================================
# TABS — DATA-CENTRIC REPORT v2 BUNDLER (V11)
# ==============================================================================
# Inlines the vendored renderer (CSS + 29 JS modules + template) and a
# data-agg JSON island into a single self-contained *_report_v2.html — the
# productionised port of prototypes/report-redesign/fable/v2/build.R.
#
# This first cut bundles the aggregates island only; microdata, prior-wave
# and verification islands are inlined as `null` (the renderer's parseIsland
# tolerates this and degrades gracefully — no live filtering, no Tracking
# tab). Those islands arrive with the microdata + tracking-config sessions.
#
# Assets live under modules/tabs/lib/html_report_v2/assets/ (vendored from the
# prototype; see assets/README.md). Nothing here touches the classic
# Excel/HTML writers — this writes a separate new file only.
# ==============================================================================

# Shared v1 engine modules load first (00_namespace defines the TR namespace);
# the v2 modules (20+) follow. Mirrors build.R's explicit ordering.
.REPORT_V2_ENGINE_MODULES <- c(
  "00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js", "14_pptx_parts.js"
)

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}


#' Resolve the vendored v2 asset directory
#'
#' @return Absolute path to modules/tabs/lib/html_report_v2/assets
#' @export
report_v2_assets_dir <- function() {
  lib_dir <- get0(".tabs_lib_dir", ifnotfound = file.path("modules", "tabs", "lib"))
  file.path(lib_dir, "html_report_v2", "assets")
}


#' Bundle the renderer JS (engine modules first, then v2 modules sorted)
#'
#' @param assets_dir The vendored assets directory
#' @return A single JS string
#' @export
bundle_report_v2_js <- function(assets_dir = report_v2_assets_dir()) {
  js_dir <- file.path(assets_dir, "js")
  read_text <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")

  all_js <- sort(basename(list.files(js_dir, pattern = "\\.js$")))
  v2_js <- setdiff(all_js, .REPORT_V2_ENGINE_MODULES)
  ordered <- c(.REPORT_V2_ENGINE_MODULES, v2_js)

  missing <- ordered[!file.exists(file.path(js_dir, ordered))]
  if (length(missing) > 0) {
    stop(sprintf("[IO_REPORT_V2_JS_MISSING] renderer module(s) missing from %s: %s",
                 js_dir, paste(missing, collapse = ", ")))
  }

  bundle <- paste(vapply(file.path(js_dir, ordered), read_text, character(1)),
                  collapse = "\n\n")
  if (grepl("</script", bundle, fixed = TRUE)) {
    stop("[CFG_REPORT_V2_JS_EMBED] renderer JS contains '</script' — cannot inline safely.")
  }
  bundle
}


#' Build the self-contained v2 report HTML (pure — no file I/O)
#'
#' @param data_json The serialised data-agg JSON string (from serialize_data_layer)
#' @param config_obj The tabs config object (for the title)
#' @param assets_dir The vendored assets directory
#' @param generated A pre-formatted "generated" timestamp string
#' @return The complete HTML document as a single string
#' @export
build_report_v2_html <- function(data_json, config_obj,
                                  assets_dir = report_v2_assets_dir(),
                                  generated = format(Sys.time(), "%Y-%m-%d %H:%M %Z"),
                                  prev_json = NULL, micro_json = NULL, qual_json = NULL) {
  read_text <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")

  template_path <- file.path(assets_dir, "template.html")
  css_path <- file.path(assets_dir, "styles.css")
  for (p in c(template_path, css_path)) {
    if (!file.exists(p)) stop(sprintf("[IO_REPORT_V2_ASSET_MISSING] %s", p))
  }

  # Defend against "</" sequences inside embedded JSON breaking out of <script>
  escape_island <- function(txt) gsub("</", "<\\/", txt, fixed = TRUE)
  escape_html <- function(txt) {
    txt <- gsub("&", "&amp;", txt, fixed = TRUE)
    txt <- gsub("<", "&lt;", txt, fixed = TRUE)
    gsub(">", "&gt;", txt, fixed = TRUE)
  }

  # Single-pass template fill. Every {{TOKEN}} is resolved in ONE pass over the TEMPLATE, so
  # content inlined for one token is never re-scanned for another. escape_island() neutralises
  # "</" but NOT "{{...}}", so under a sequential replace a survey verbatim or option label
  # containing the literal "{{JS}}" (or any later token) would splice the JS bundle / another
  # island into a data island and corrupt the report. Scanning only the template fixes that.
  render_template <- function(template, tokens) {
    for (tok in names(tokens)) {
      if (!grepl(tok, template, fixed = TRUE)) {
        stop(sprintf("[CFG_REPORT_V2_TOKEN] template missing %s", tok))
      }
    }
    m <- gregexpr("\\{\\{[A-Za-z_]+\\}\\}", template)[[1]]
    if (identical(as.integer(m), -1L)) return(template)
    lens <- attr(m, "match.length")
    pieces <- vector("list", 2L * length(m) + 1L); p <- 0L; last <- 1L
    for (i in seq_along(m)) {
      start <- m[i]
      pieces[[p <- p + 1L]] <- substr(template, last, start - 1L)
      tok <- substr(template, start, start + lens[i] - 1L)
      pieces[[p <- p + 1L]] <- if (tok %in% names(tokens)) tokens[[tok]] else tok  # unknown left as-is
      last <- start + lens[i]
    }
    pieces[[p <- p + 1L]] <- substr(template, last, nchar(template))
    paste(pieces[seq_len(p)], collapse = "")
  }

  blank <- function(x) is.null(x) || length(x) == 0 ||
    (length(x) == 1 && (is.na(x) || !nzchar(as.character(x))))
  title <- if (!blank(config_obj$project_title)) config_obj$project_title
           else if (!blank(config_obj$project_name)) config_obj$project_name
           else "Turas Report"

  # Islands inline when supplied (anonymised indices/weights, scrubbed comments), else null so
  # the corresponding tab stays hidden (published-only / no Tracking / no Qualitative).
  micro_inlined <- if (!is.null(micro_json) && nzchar(micro_json) && micro_json != "null") {
    escape_island(micro_json)
  } else "null"
  prev_inlined <- if (!is.null(prev_json) && nzchar(prev_json)) escape_island(prev_json) else "null"
  qual_inlined <- if (!is.null(qual_json) && nzchar(qual_json) && qual_json != "null") {
    escape_island(qual_json)
  } else "null"

  html <- render_template(read_text(template_path), list(
    "{{TITLE}}"       = escape_html(as.character(title)),
    "{{GENERATED}}"   = generated,
    "{{CSS}}"         = read_text(css_path),
    "{{DATA_AGG}}"    = escape_island(data_json),
    "{{DATA_MICRO}}"  = micro_inlined,
    "{{DATA_PREV}}"   = prev_inlined,
    "{{DATA_VERIFY}}" = "null",
    "{{DATA_QUAL}}"   = qual_inlined,
    "{{JS}}"          = bundle_report_v2_js(assets_dir)
  ))

  if (grepl('(src|href)="https?://', html)) {
    stop("[CFG_REPORT_V2_EXTERNAL] bundled report references an external URL.")
  }
  html
}


#' Write the data-centric v2 report to a self-contained HTML file
#'
#' @param data_json Serialised data-agg JSON (from serialize_data_layer)
#' @param config_obj The tabs config object
#' @param output_path Destination .html path
#' @param assets_dir Vendored assets directory
#'
#' @return A list with structure:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{output_file}{Path written (if PASS)}
#'   \item{file_size_mb}{Size of the written file (if PASS)}
#'
#' @examples
#' \dontrun{
#'   dl <- build_data_layer(all_results, banner_info, config_obj)
#'   write_html_report_v2(serialize_data_layer(dl), config_obj, "report_v2.html")
#' }
#' @export
write_html_report_v2 <- function(data_json, config_obj, output_path,
                                 assets_dir = report_v2_assets_dir(),
                                 prev_json = NULL, micro_json = NULL, qual_json = NULL) {
  refuse <- function(code, message, how_to_fix) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code:", code, "\n")
    cat("Message:", message, "\n")
    cat("Fix:", how_to_fix, "\n")
    cat("==================\n\n")
    list(status = "REFUSED", code = code, message = message,
         how_to_fix = how_to_fix, context = list(call = sys.call()))
  }

  if (is.null(data_json) || !nzchar(data_json)) {
    return(refuse("DATA_LAYER_EMPTY", "No data-layer JSON supplied to the v2 report bundler.",
                  "Build the data layer with build_data_layer() + serialize_data_layer() first."))
  }

  html <- tryCatch(
    build_report_v2_html(data_json, config_obj, assets_dir,
                         prev_json = prev_json, micro_json = micro_json, qual_json = qual_json),
    error = function(e) e)
  if (inherits(html, "error")) {
    return(refuse("REPORT_V2_BUILD_FAILED", conditionMessage(html),
                  "Check the vendored assets in modules/tabs/lib/html_report_v2/assets/."))
  }

  written <- tryCatch({ writeLines(html, output_path, useBytes = TRUE); TRUE },
                      error = function(e) e)
  if (inherits(written, "error")) {
    return(refuse("IO_WRITE_FAILED", conditionMessage(written),
                  paste0("Check the output directory is writable: ", output_path)))
  }

  size_mb <- file.info(output_path)$size / 1024 / 1024
  cat(sprintf("  Report v2: %s (%.2f MB)\n", basename(output_path), size_mb))
  list(status = "PASS", output_file = output_path, file_size_mb = size_mb)
}
