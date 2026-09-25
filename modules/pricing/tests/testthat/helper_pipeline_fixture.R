# ==============================================================================
# TURAS PRICING - PIPELINE FIXTURE (robustness gate 2)
# ==============================================================================
#
# Runs the module the way launch_turas() does, from a config workbook to its
# output files, in a child Rscript, so nothing the test session has loaded can
# stand in for what the module loads itself. Sourced explicitly by the
# pipeline tests (the runner only runs test*.R files).
#
# pricing_pipeline_run(config_name, edits) copies nothing into examples/: the
# Karoo config is read where it is, the data file and output path are pointed
# at a temporary folder, and `edits` is R code applied to the loaded config
# before the run (for example a smaller bootstrap).
# ==============================================================================

pricing_repo_root <- function() {
  d <- normalizePath(getwd())
  for (i in 1:10) {
    if (file.exists(file.path(d, "launch_turas.R"))) return(d)
    d <- dirname(d)
  }
  stop("Turas root not found above ", getwd())
}

pricing_pipeline_run <- function(config_name, edits = "", out_dir = tempfile("pricing_pipe_"),
                                 data_file = NULL, config_path = NULL) {
  root <- pricing_repo_root()
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  if (is.null(config_path)) config_path <- file.path(root, "examples", "pricing", config_name)
  if (is.null(data_file)) data_file <- file.path(root, "examples", "pricing", "Karoo_Pricing_Data.xlsx")
  out_file <- file.path(out_dir, sub("[.]xlsx$", "_Results.xlsx", basename(config_path)))
  script <- file.path(out_dir, "run.R")
  writeLines(c(
    sprintf("setwd(%s)", deparse(root)),
    "source('modules/pricing/R/00_main.R')",
    sprintf("cfg <- load_pricing_config(%s)", deparse(config_path)),
    sprintf("cfg$data_file <- %s", deparse(data_file)),
    sprintf("cfg$output_file <- %s", deparse(out_file)),
    edits,
    "res <- tryCatch(run_pricing_analysis_from_config(cfg),",
    "  turas_refusal = function(e) { cat('\\nREFUSED:', e$code, '\\n'); NULL })",
    sprintf("writeLines(if (is.null(res)) 'REFUSED' else res$run_result$status, %s)",
            deparse(file.path(out_dir, "final_status.txt")))
  ), script)
  log <- system2(file.path(R.home("bin"), "Rscript"), script, stdout = TRUE, stderr = TRUE,
                 env = c(paste0("R_LIBS=", paste(.libPaths(), collapse = .Platform$path.sep)),
                         "RENV_CONFIG_AUTOLOADER_ENABLED=FALSE"))
  status_file <- file.path(out_dir, "final_status.txt")
  list(
    dir = out_dir,
    log = log,
    status = if (file.exists(status_file)) readLines(status_file)[1] else "CRASHED",
    workbook = out_file,
    stats_pack = sub("[.]xlsx$", "_stats_pack.xlsx", out_file),
    island = sub("[.]xlsx$", "_pr_island.json", out_file),
    simulator = sub("[.]xlsx$", "_simulator.html", out_file)
  )
}

#' Read a sheet back with blank rows kept (never compact the row index).
pricing_sheet <- function(path, sheet, ...) {
  openxlsx::read.xlsx(path, sheet = sheet, skipEmptyRows = FALSE, ...)
}

#' A two-column Setting/Value style sheet as a named character vector.
pricing_kv <- function(path, sheet) {
  x <- openxlsx::read.xlsx(path, sheet = sheet, colNames = FALSE, skipEmptyRows = FALSE)
  x <- x[!is.na(x[[1]]), , drop = FALSE]
  stats::setNames(as.character(x[[2]]), as.character(x[[1]]))
}

#' The simulator's embedded data island, parsed.
pricing_simulator_data <- function(path) {
  html <- paste(readLines(path, warn = FALSE), collapse = "\n")
  m <- regmatches(html, regexpr('<script type="application/json" id="pricing-simulator-data">.*?</script>', html))
  json <- sub('^<script[^>]*>', "", sub("</script>$", "", m))
  jsonlite::fromJSON(json, simplifyVector = TRUE)
}

#' Render the v2 Pricing tab from an island with the shipped 27z_pricing.js
#' and return its visible text.
pricing_render_tab <- function(island_path) {
  root <- pricing_repo_root()
  js <- file.path(root, "modules", "pricing", "tests", "js", "render_pricing_tab.mjs")
  out <- system2("node", c(shQuote(js), shQuote(island_path)), stdout = TRUE, stderr = TRUE)
  paste(out, collapse = "\n")
}
