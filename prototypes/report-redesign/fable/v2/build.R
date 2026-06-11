#!/usr/bin/env Rscript
# Build the single-file SACAP v2 report: template + CSS + JS (shared v1
# engine modules + v2 modules) + four data islands (2025 aggregates,
# synthetic microdata, 2024 wave, microdata verification).
#
# Usage: Rscript build.R            # -> sacap_report_v2.html

V1_MODULES <- c("00_namespace.js", "01_format.js", "03_svg.js",
                "13_zip.js", "14_pptx_parts.js")

build <- function(base_dir) {
  refuse <- function(errs) {
    cat("\n=== TURAS V2 BUILD REFUSED ===\n")
    for (e in errs) cat("- ", e, "\n", sep = "")
    quit(status = 1)
  }
  read_text <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")
  errors <- character(0)

  v1_dir <- file.path(dirname(base_dir), "src", "js")
  paths <- list(
    template = file.path(base_dir, "src", "template.html"),
    css = file.path(base_dir, "src", "styles.css"),
    agg = file.path(base_dir, "data", "sacap_2025.json"),
    micro = file.path(base_dir, "data", "sacap_microdata.json"),
    prev = file.path(base_dir, "data", "sacap_2024.json"),
    verify = file.path(base_dir, "data", "microdata_verification.json")
  )
  for (p in c(unlist(paths), file.path(v1_dir, V1_MODULES))) {
    if (!file.exists(p)) errors <- c(errors, paste0("IO_MISSING: ", p))
  }
  if (length(errors)) refuse(errors)

  v2_files <- sort(list.files(file.path(base_dir, "src", "js"),
                              pattern = "\\.js$", full.names = TRUE))
  js_bundle <- paste(
    c(vapply(file.path(v1_dir, V1_MODULES), read_text, character(1)),
      vapply(v2_files, read_text, character(1))),
    collapse = "\n\n")
  if (grepl("</script", js_bundle, fixed = TRUE)) {
    refuse("CFG_JS_EMBED: JS bundle contains '</script'.")
  }

  json_for <- function(path) {
    txt <- read_text(path)
    parsed <- tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE),
                       error = function(e) NULL)
    if (is.null(parsed)) refuse(paste0("DATA_PARSE: ", path, " is not valid JSON."))
    gsub("</", "<\\/", txt, fixed = TRUE)
  }

  replace_token <- function(text, token, content) {
    parts <- strsplit(text, token, fixed = TRUE)[[1]]
    if (length(parts) == 1) refuse(paste0("CFG_TOKEN: template missing ", token))
    paste(parts, collapse = content)
  }

  html <- read_text(paths$template)
  html <- replace_token(html, "{{TITLE}}", "SACAP 2025 Annual Student Survey — Turas Report v2")
  html <- replace_token(html, "{{GENERATED}}", format(Sys.time(), "%Y-%m-%d %H:%M %Z"))
  html <- replace_token(html, "{{CSS}}", read_text(paths$css))
  html <- replace_token(html, "{{DATA_AGG}}", json_for(paths$agg))
  html <- replace_token(html, "{{DATA_MICRO}}", json_for(paths$micro))
  html <- replace_token(html, "{{DATA_PREV}}", json_for(paths$prev))
  html <- replace_token(html, "{{DATA_VERIFY}}", json_for(paths$verify))
  html <- replace_token(html, "{{JS}}", js_bundle)

  out <- file.path(base_dir, "sacap_report_v2.html")
  writeLines(html, out, useBytes = TRUE)

  built <- read_text(out)
  if (grepl('(src|href)="https?://', built)) {
    refuse("CFG_EXTERNAL: output references an external URL.")
  }
  size <- file.info(out)$size
  cat(sprintf("BUILD OK  %s\n  size: %.2f MB (live report: 7.0 MB)\n",
              out, size / 1024 / 1024))
}

base_dir <- normalizePath(dirname(sub("--file=", "",
  grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])))
build(base_dir)
