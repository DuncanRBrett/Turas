# ==============================================================================
# TABS — READER REPORT: BUNDLER + ENTRY POINT (V15)
# ==============================================================================
# Assembles the self-contained *_Reader.html — a narrative summary that sits
# beside the crosstab and deep-links back into it. Mirrors build_report_v2.R:
# a vendored template + CSS + JS under assets/, single-pass {{TOKEN}} fill, the
# reader model inlined as a data-reader island, TRS refusals, and a
# list(status, output_file, file_size_mb) return.
#
# The model comes from derive_reader_model() — pure derivation over the same
# data layer the crosstab used, so no statistic is recomputed and no figure can
# appear here that is not in the crosstab. Deterministic by default; the AI
# prose path (reader_ai_prose) overwrites model$prose upstream and is opt-in.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

#' Resolve the vendored Reader asset directory.
#' @return Absolute path to modules/tabs/lib/reader_report/assets
#' @export
reader_report_assets_dir <- function() {
  lib_dir <- get0(".tabs_lib_dir", ifnotfound = file.path("modules", "tabs", "lib"))
  file.path(lib_dir, "reader_report", "assets")
}

#' Serialise the reader model to JSON.
#' @param model The reader model (from derive_reader_model)
#' @return A JSON string
#' @export
serialize_reader_model <- function(model) {
  jsonlite::toJSON(model, auto_unbox = TRUE, na = "null", null = "null", digits = 6)
}

#' Build the self-contained Reader HTML (pure — no file I/O).
#' @param model_json Serialised reader-model JSON
#' @param model The reader model (for the title + theme colours)
#' @param assets_dir Vendored assets directory
#' @param generated A pre-formatted "generated" timestamp string
#' @return The complete HTML document as a single string
#' @export
build_reader_report_html <- function(model_json, model,
                                     assets_dir = reader_report_assets_dir(),
                                     generated = format(Sys.time(), "%Y-%m-%d %H:%M %Z")) {
  read_text <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")

  template_path <- file.path(assets_dir, "template.html")
  css_path <- file.path(assets_dir, "reader.css")
  js_path <- file.path(assets_dir, "reader.js")
  for (p in c(template_path, css_path, js_path)) {
    if (!file.exists(p)) stop(sprintf("[IO_READER_ASSET_MISSING] %s", p))
  }

  escape_island <- function(txt) gsub("</", "<\\/", txt, fixed = TRUE)
  escape_html <- function(txt) {
    txt <- gsub("&", "&amp;", txt, fixed = TRUE)
    txt <- gsub("<", "&lt;", txt, fixed = TRUE)
    gsub(">", "&gt;", txt, fixed = TRUE)
  }

  # Single-pass token fill (same guarantee as build_report_v2_html: content
  # inlined for one token is never re-scanned for another).
  render_template <- function(template, tokens) {
    for (tok in names(tokens)) {
      if (!grepl(tok, template, fixed = TRUE)) {
        stop(sprintf("[CFG_READER_TOKEN] template missing %s", tok))
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
      pieces[[p <- p + 1L]] <- if (tok %in% names(tokens)) tokens[[tok]] else tok
      last <- start + lens[i]
    }
    pieces[[p <- p + 1L]] <- substr(template, last, nchar(template))
    paste(pieces[seq_len(p)], collapse = "")
  }

  title <- model$prose$title %||% model$project$name %||% "Reader report"
  brand <- model$project$brand_colour %||% "#323367"
  accent <- model$project$accent_colour %||% "#CC9900"

  html <- render_template(read_text(template_path), list(
    "{{TITLE}}"       = escape_html(as.character(title)),
    "{{GENERATED}}"   = escape_html(generated),
    "{{BRAND}}"       = escape_html(brand),
    "{{ACCENT}}"      = escape_html(accent),
    "{{CSS}}"         = read_text(css_path),
    "{{DATA_READER}}" = escape_island(model_json),
    "{{JS}}"          = read_text(js_path)
  ))

  if (grepl('(src|href)="https?://', html)) {
    stop("[CFG_READER_EXTERNAL] bundled Reader report references an external URL.")
  }
  if (grepl("</script", read_text(js_path), fixed = TRUE)) {
    stop("[CFG_READER_JS_EMBED] reader.js contains '</script' — cannot inline safely.")
  }
  html
}

#' Generate the Reader report and write it to a self-contained HTML file.
#'
#' @param dl The data layer list (from build_data_layer) — NOT serialised.
#' @param prev_json Serialised tracking island JSON (string) or NULL.
#' @param qual_json Serialised qualitative island JSON (string) or NULL.
#' @param crosstab_file Basename of the sibling crosstab report (for deep links).
#' @param config_obj The tabs config object.
#' @param output_path Destination .html path.
#' @param assets_dir Vendored assets directory.
#'
#' @return list(status = "PASS"|"REFUSED", output_file, file_size_mb)
#' @examples
#' \dontrun{
#'   generate_reader_report(dl, prev_json, qual_json, "study_report.html",
#'                          config_obj, "study_Reader.html")
#' }
#' @export
generate_reader_report <- function(dl, prev_json = NULL, qual_json = NULL,
                                   crosstab_file = "", config_obj = list(),
                                   output_path,
                                   assets_dir = reader_report_assets_dir()) {
  refuse <- function(code, message, how_to_fix) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code:", code, "\n")
    cat("Message:", message, "\n")
    cat("Fix:", how_to_fix, "\n")
    cat("==================\n\n")
    list(status = "REFUSED", code = code, message = message,
         how_to_fix = how_to_fix, context = list(call = sys.call()))
  }

  if (is.null(dl) || !is.list(dl) || !length(dl$questions %||% list())) {
    return(refuse("DATA_LAYER_EMPTY",
                  "No usable data layer supplied to the Reader report generator.",
                  "Build the data layer with build_data_layer() first, then pass it as `dl`."))
  }

  # Parse the optional islands (strings) back to R objects; a bad island never
  # sinks the report — that section just stays unavailable.
  safe_parse <- function(js) {
    if (is.null(js) || !nzchar(js) || identical(js, "null")) return(NULL)
    tryCatch(jsonlite::fromJSON(js, simplifyVector = FALSE), error = function(e) NULL)
  }
  prev <- safe_parse(prev_json)
  qual <- safe_parse(qual_json)

  model <- tryCatch(
    derive_reader_model(dl, prev = prev, qual = qual, config_obj = config_obj,
                        crosstab_file = crosstab_file),
    error = function(e) e)
  if (inherits(model, "error")) {
    return(refuse("READER_DERIVE_FAILED", conditionMessage(model),
                  "The reader-model derivation errored; check the data layer shape."))
  }

  # AI prose (opt-in, reader_ai_prose): replace the templated narrative with
  # model-drafted prose — aggregates only, every cited number checked against
  # the data. Any failure degrades silently to the deterministic narrative.
  if (exists("reader_apply_ai_prose", mode = "function")) {
    model <- tryCatch(reader_apply_ai_prose(model, config_obj), error = function(e) model)
  }

  html <- tryCatch(
    build_reader_report_html(serialize_reader_model(model), model, assets_dir),
    error = function(e) e)
  if (inherits(html, "error")) {
    return(refuse("READER_BUILD_FAILED", conditionMessage(html),
                  "Check the vendored assets in modules/tabs/lib/reader_report/assets/."))
  }

  written <- tryCatch({ writeLines(html, output_path, useBytes = TRUE); TRUE },
                      error = function(e) e)
  if (inherits(written, "error")) {
    return(refuse("IO_WRITE_FAILED", conditionMessage(written),
                  paste0("Check the output directory is writable: ", output_path)))
  }

  size_mb <- file.info(output_path)$size / 1024 / 1024
  cat(sprintf("  Reader report: %s (%.2f MB)\n", basename(output_path), size_mb))
  list(status = "PASS", output_file = output_path, file_size_mb = size_mb)
}
