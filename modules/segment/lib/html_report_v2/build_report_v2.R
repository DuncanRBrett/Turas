# ==============================================================================
# SEGMENT — DATA-CENTRIC REPORT v2 BUNDLER
# ==============================================================================
# Inlines the vendored renderer (CSS + 29 JS modules + template) and the segment
# data-agg JSON island into a single self-contained *_report_v2.html. Ported
# from modules/tabs/lib/html_report_v2/build_report_v2.R; only the asset
# directory differs (segment vendors its own copy of the engine — see
# assets/README.md). Micro/prev/verify islands are inlined as null (this first
# cut is published-only: no live filtering, no Tracking tab).
# ==============================================================================

# Engine modules load first (00_namespace defines the TR namespace); v2 modules
# (20+) follow in sorted order. Mirrors the tabs bundler exactly.
.SEG_REPORT_V2_ENGINE_MODULES <- c(
  "00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js", "14_pptx_parts.js"
)

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}


#' Resolve the vendored v2 asset directory for the segment module
#' @return Absolute path to modules/segment/lib/html_report_v2/assets
#' @export
seg_report_v2_assets_dir <- function() {
  root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(root)) root <- getwd()
  d <- file.path(root, "modules", "segment", "lib", "html_report_v2", "assets")
  if (!dir.exists(d)) d <- file.path("modules", "segment", "lib", "html_report_v2", "assets")
  d
}


#' Bundle the renderer JS (engine modules first, then v2 modules sorted)
#' @export
seg_bundle_report_v2_js <- function(assets_dir = seg_report_v2_assets_dir()) {
  js_dir <- file.path(assets_dir, "js")
  read_text <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")

  all_js <- sort(basename(list.files(js_dir, pattern = "\\.js$")))
  v2_js <- setdiff(all_js, .SEG_REPORT_V2_ENGINE_MODULES)
  ordered <- c(.SEG_REPORT_V2_ENGINE_MODULES, v2_js)

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
#' @param data_json Serialised segment data-agg JSON (serialize_segment_data_layer)
#' @param title Report title for the <title> tag and header
#' @export
seg_build_report_v2_html <- function(data_json, title = "Segmentation Report",
                                     assets_dir = seg_report_v2_assets_dir(),
                                     generated = format(Sys.time(), "%Y-%m-%d %H:%M %Z")) {
  read_text <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")

  template_path <- file.path(assets_dir, "template.html")
  css_path <- file.path(assets_dir, "styles.css")
  for (p in c(template_path, css_path)) {
    if (!file.exists(p)) stop(sprintf("[IO_REPORT_V2_ASSET_MISSING] %s", p))
  }

  escape_island <- function(txt) gsub("</", "<\\/", txt, fixed = TRUE)
  escape_html <- function(txt) {
    txt <- gsub("&", "&amp;", txt, fixed = TRUE)
    txt <- gsub("<", "&lt;", txt, fixed = TRUE)
    gsub(">", "&gt;", txt, fixed = TRUE)
  }
  replace_token <- function(text, token, content) {
    parts <- strsplit(text, token, fixed = TRUE)[[1]]
    if (length(parts) == 1) stop(sprintf("[CFG_REPORT_V2_TOKEN] template missing %s", token))
    paste(parts, collapse = content)
  }

  html <- read_text(template_path)
  html <- replace_token(html, "{{TITLE}}", escape_html(as.character(title %||% "Segmentation Report")))
  html <- replace_token(html, "{{GENERATED}}", generated)
  html <- replace_token(html, "{{CSS}}", read_text(css_path))
  html <- replace_token(html, "{{DATA_AGG}}", escape_island(data_json))
  html <- replace_token(html, "{{DATA_MICRO}}", "null")
  html <- replace_token(html, "{{DATA_PREV}}", "null")
  html <- replace_token(html, "{{DATA_VERIFY}}", "null")
  html <- replace_token(html, "{{JS}}", seg_bundle_report_v2_js(assets_dir))

  if (grepl('(src|href)="https?://', html)) {
    stop("[CFG_REPORT_V2_EXTERNAL] bundled report references an external URL.")
  }
  html
}


#' Write the data-centric v2 segment report to a self-contained HTML file
#' @export
seg_write_report_v2 <- function(data_json, output_path, title = "Segmentation Report",
                                assets_dir = seg_report_v2_assets_dir()) {
  refuse <- function(code, message, how_to_fix) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code:", code, "\n"); cat("Message:", message, "\n"); cat("Fix:", how_to_fix, "\n")
    cat("==================\n\n")
    list(status = "REFUSED", code = code, message = message, how_to_fix = how_to_fix)
  }
  if (is.null(data_json) || !nzchar(data_json)) {
    return(refuse("DATA_LAYER_EMPTY", "No data-layer JSON supplied to the v2 report bundler.",
                  "Build it with build_segment_data_layer() + serialize_segment_data_layer()."))
  }
  html <- tryCatch(seg_build_report_v2_html(data_json, title, assets_dir),
                   error = function(e) e)
  if (inherits(html, "error")) {
    return(refuse("REPORT_V2_BUILD_FAILED", conditionMessage(html),
                  "Check the vendored assets in modules/segment/lib/html_report_v2/assets/."))
  }
  written <- tryCatch({ writeLines(html, output_path, useBytes = TRUE); TRUE },
                      error = function(e) e)
  if (inherits(written, "error")) {
    return(refuse("IO_WRITE_FAILED", conditionMessage(written),
                  paste0("Check the output directory is writable: ", output_path)))
  }
  size_mb <- file.info(output_path)$size / 1024 / 1024
  cat(sprintf("  Segment report v2: %s (%.2f MB)\n", basename(output_path), size_mb))
  list(status = "PASS", output_file = output_path, file_size_mb = size_mb)
}
