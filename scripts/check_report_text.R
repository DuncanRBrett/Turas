# Pre-flight for the v2 report: does its authored text still validate against
# the renderer? A refusal here is what run_crosstabs turns into a warning, so
# the analysis passes and no HTML is written. Run this before a project run.
source("modules/shared/lib/callouts/callout_registry.R")
source("modules/tabs/lib/html_report_v2/build_report_v2.R")
source("modules/tabs/lib/html_report_v2/report_text.R")

reg <- "modules/shared/lib/callouts/callouts.json"
raw <- paste(readLines(reg, warn = FALSE), collapse = "\n")
if (grepl("^(<<<<<<<|=======|>>>>>>>)", raw, perl = TRUE) ||
    grepl("\n(<<<<<<<|>>>>>>>)", raw)) {
  cat("REFUSED: callouts.json carries git conflict markers. Resolve the merge first.\n")
  quit(status = 1)
}
entries <- turas_callout_module("tabs")
cat("tabs callout entries:", length(entries), "\n")
if (!length(entries)) {
  cat("REFUSED: the registry parsed to nothing. Every report would build without text.\n")
  quit(status = 1)
}
assets <- report_v2_assets_dir()
js <- sort(list.files(file.path(assets, "js"), pattern = "\\.js$", full.names = TRUE))
bundle <- paste(vapply(js, function(f) paste(readLines(f, warn = FALSE), collapse = "\n"),
                       character(1)), collapse = "\n")
ok <- tryCatch({ build_report_text_json(assets_dir = assets, js_bundle = bundle); TRUE },
               error = function(e) { cat("REFUSED:\n", conditionMessage(e), "\n"); FALSE })
if (isTRUE(ok)) cat("PASS: the v2 report will find every sentence it needs.\n")
quit(status = if (isTRUE(ok)) 0 else 1)
