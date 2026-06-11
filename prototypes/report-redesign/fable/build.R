#!/usr/bin/env Rscript
# Build the single-file Turas report: template + CSS + JS modules + data JSON.
#
# Usage:
#   Rscript build.R                                          # demo data
#   Rscript build.R --data data/scale_data.json --out turas_report_scale.html
#
# The build refuses (exit 1) with an accumulated error list when inputs are
# missing, the JSON does not parse, a token is absent from the template, or
# the assembled file would break the <script> embedding.

build_report <- function(data_path, out_path, base_dir) {
  errors <- character(0)
  refuse <- function(errs) {
    cat("\n=== TURAS BUILD REFUSED ===\n")
    for (e in errs) cat("- ", e, "\n", sep = "")
    cat("===========================\n\n")
    quit(status = 1)
  }

  template_path <- file.path(base_dir, "src", "template.html")
  css_path <- file.path(base_dir, "src", "styles.css")
  js_dir <- file.path(base_dir, "src", "js")
  for (p in c(template_path, css_path, js_dir, data_path)) {
    if (!file.exists(p)) errors <- c(errors, paste0("IO_MISSING: ", p, " not found."))
  }
  if (length(errors)) refuse(errors)

  read_text <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")

  json_text <- read_text(data_path)
  parsed <- tryCatch(jsonlite::fromJSON(json_text, simplifyVector = FALSE),
                     error = function(e) NULL)
  if (is.null(parsed)) {
    errors <- c(errors, paste0("DATA_PARSE: ", data_path, " is not valid JSON."))
  } else {
    if (is.null(parsed$project$name)) errors <- c(errors, "DATA_NO_PROJECT: project.name missing.")
    if (is.null(parsed$banner$columns)) errors <- c(errors, "DATA_NO_BANNER: banner.columns missing.")
    if (is.null(parsed$questions) || length(parsed$questions) == 0) {
      errors <- c(errors, "DATA_NO_QUESTIONS: questions missing or empty.")
    }
  }

  js_files <- sort(list.files(js_dir, pattern = "\\.js$", full.names = TRUE))
  if (length(js_files) == 0) errors <- c(errors, "IO_NO_JS: no JS modules found in src/js.")
  js_bundle <- paste(vapply(js_files, read_text, character(1)), collapse = "\n\n")
  css_bundle <- read_text(css_path)
  template <- read_text(template_path)

  # embedding safety: nothing may terminate its host <script>/<style> early
  if (grepl("</script", js_bundle, fixed = TRUE)) {
    errors <- c(errors, "CFG_JS_EMBED: JS bundle contains '</script' which would break embedding.")
  }
  if (grepl("</style", css_bundle, fixed = TRUE)) {
    errors <- c(errors, "CFG_CSS_EMBED: CSS contains '</style' which would break embedding.")
  }
  for (token in c("{{TITLE}}", "{{GENERATED}}", "{{CSS}}", "{{DATA}}", "{{JS}}")) {
    if (!grepl(token, template, fixed = TRUE)) {
      errors <- c(errors, paste0("CFG_TOKEN: template is missing ", token, "."))
    }
  }
  if (length(errors)) refuse(errors)

  # JSON inside <script type="application/json"> must escape "</"
  json_safe <- gsub("</", "<\\/", json_text, fixed = TRUE)

  replace_token <- function(text, token, content) {
    parts <- strsplit(text, token, fixed = TRUE)[[1]]
    if (length(parts) == 1) return(text)
    paste(parts, collapse = content)
  }

  html <- template
  html <- replace_token(html, "{{TITLE}}",
                        paste0(parsed$project$name, " — Turas Report"))
  html <- replace_token(html, "{{GENERATED}}",
                        format(Sys.time(), "%Y-%m-%d %H:%M %Z"))
  html <- replace_token(html, "{{CSS}}", css_bundle)
  html <- replace_token(html, "{{DATA}}", json_safe)
  html <- replace_token(html, "{{JS}}", js_bundle)

  writeLines(html, out_path, useBytes = TRUE)

  built <- read_text(out_path)
  post <- character(0)
  if (!grepl('<script type="application/json" id="turas-data">', built, fixed = TRUE)) {
    post <- c(post, "CFG_BUILD: data island missing from output.")
  }
  if (grepl('(src|href)="https?://', built)) {
    post <- c(post, "CFG_EXTERNAL: output references an external URL — must be self-contained.")
  }
  if (length(post)) refuse(post)

  size <- file.info(out_path)$size
  cat(sprintf("BUILD OK  %s\n  data: %s (%.1f KB)\n  size: %.1f KB (%.2f MB)\n",
              out_path, data_path, file.info(data_path)$size / 1024,
              size / 1024, size / 1024 / 1024))
  invisible(out_path)
}

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  hit <- which(args == flag)
  if (length(hit) == 1 && hit < length(args)) args[hit + 1] else default
}
base_dir <- normalizePath(dirname(sub("--file=", "",
  grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])))
resolve_path <- function(path) {
  if (substr(path, 1, 1) == "/") path else file.path(base_dir, path)
}
build_report(
  data_path = resolve_path(get_arg("--data", "data/demo_data.json")),
  out_path  = resolve_path(get_arg("--out", "turas_report.html")),
  base_dir  = base_dir
)
