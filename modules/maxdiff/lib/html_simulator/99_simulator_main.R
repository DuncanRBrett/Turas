# ==============================================================================
# MAXDIFF SIMULATOR - MAIN ORCHESTRATOR - TURAS V11.0
# ==============================================================================

MAXDIFF_SIMULATOR_VERSION <- "2.0"

.md_sim_loaded <- FALSE

#' Source simulator sub-modules
#' @keywords internal
.md_load_simulator_submodules <- function() {

  if (.md_sim_loaded) return(invisible(NULL))

  sim_dir <- NULL

  # Find simulator directory
  for (i in seq_len(sys.nframe())) {
    ofile <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(ofile) && is.character(ofile) && length(ofile) == 1) {
      candidate <- dirname(normalizePath(ofile, mustWork = FALSE))
      if (file.exists(file.path(candidate, "00_simulator_guard.R"))) {
        sim_dir <- candidate
        break
      }
    }
  }

  if (is.null(sim_dir)) {
    candidates <- c(
      file.path(getwd(), "modules", "maxdiff", "lib", "html_simulator"),
      file.path(getwd(), "lib", "html_simulator")
    )
    if (exists("script_dir_override", envir = globalenv())) {
      sd <- get("script_dir_override", envir = globalenv())
      candidates <- c(
        file.path(sd, "..", "lib", "html_simulator"),
        file.path(dirname(sd), "lib", "html_simulator"),
        candidates
      )
    }
    for (c in candidates) {
      c <- normalizePath(c, mustWork = FALSE)
      if (file.exists(file.path(c, "00_simulator_guard.R"))) {
        sim_dir <- c
        break
      }
    }
  }

  if (is.null(sim_dir)) {
    message("[TRS INFO] MAXD_SIM_DIR_NOT_FOUND: Could not locate html_simulator directory")
    return(invisible(NULL))
  }

  files <- c("00_simulator_guard.R", "01_simulator_data_transformer.R", "02_simulator_page_builder.R")
  for (f in files) {
    fpath <- file.path(sim_dir, f)
    if (file.exists(fpath)) source(fpath, local = FALSE)
  }

  .md_sim_loaded <<- TRUE
  assign(".md_sim_dir", sim_dir, envir = globalenv())
  invisible(NULL)
}


#' Generate MaxDiff Interactive Simulator
#'
#' @param maxdiff_results Full results from run_maxdiff()
#' @param config Module config
#' @param output_path Path for the output HTML file
#'
#' @return List with status, output_file
#' @export
generate_maxdiff_html_simulator <- function(maxdiff_results, config, output_path) {

  .md_load_simulator_submodules()

  # Validate
  hb_results <- maxdiff_results$hb_results
  logit_results <- maxdiff_results$logit_results

  if (is.null(hb_results) && is.null(logit_results)) {
    message("[TRS INFO] MAXD_SIM_NO_UTILS: Need HB or logit results for simulator")
    return(list(status = "REFUSED", message = "No utility estimates available"))
  }

  guard <- validate_simulator_inputs(
    utilities = if (!is.null(hb_results)) hb_results else logit_results,
    config = config
  )

  if (!guard$valid) {
    message(sprintf("[TRS PARTIAL] MAXD_SIM_GUARD: %s", paste(guard$issues, collapse = "; ")))
    return(list(status = "REFUSED", message = paste(guard$issues, collapse = "; ")))
  }

  # Build data
  sim_data <- build_simulator_data(
    hb_results = hb_results,
    logit_results = logit_results,
    config = config,
    segment_results = maxdiff_results$segment_results,
    raw_data = maxdiff_results$raw_data
  )

  # Read JS files
  sim_dir <- get(".md_sim_dir", envir = globalenv())
  js_dir <- file.path(sim_dir, "js")

  read_js <- function(filename) {
    fpath <- file.path(js_dir, filename)
    if (file.exists(fpath)) paste(readLines(fpath, warn = FALSE), collapse = "\n") else ""
  }

  # Load shared pin library
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) turas_root <- getwd()
  pins_path <- file.path(turas_root, "modules", "shared", "lib", "turas_pins_js.R")
  if (!file.exists(pins_path)) pins_path <- file.path("modules", "shared", "lib", "turas_pins_js.R")
  if (!exists("turas_pins_js", mode = "function") && file.exists(pins_path)) {
    source(pins_path, local = FALSE)
  }
  shared_js <- if (exists("turas_pins_js", mode = "function")) turas_pins_js() else ""

  js_files <- list(
    shared = shared_js,
    engine = read_js("simulator_engine.js"),
    charts = read_js("simulator_charts.js"),
    pins   = read_js("sim_pins.js"),
    export = read_js("simulator_export.js"),
    ui     = read_js("simulator_ui.js")
  )

  # Build page
  page <- build_simulator_page(sim_data, js_files)

  # Write
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  writeLines(page, output_path)

  file_size <- file.info(output_path)$size
  message(sprintf("  Simulator generated: %s (%.1f KB)", output_path, file_size / 1024))

  list(
    status = "PASS",
    output_file = output_path,
    file_size_bytes = file_size
  )
}


#' Build Simulator HTML String (for embedding in report)
#'
#' Same as generate_maxdiff_html_simulator but returns the HTML string
#' instead of writing to a file.
#'
#' @param maxdiff_results Full results from run_maxdiff()
#' @param config Module config
#'
#' @return Character string of complete simulator HTML, or NULL on failure
#' @keywords internal
build_simulator_html_string <- function(maxdiff_results, config) {

  .md_load_simulator_submodules()

  hb_results <- maxdiff_results$hb_results
  logit_results <- maxdiff_results$logit_results

  if (is.null(hb_results) && is.null(logit_results)) {
    message("[TRS INFO] MAXD_SIM_NO_UTILS: Need HB or logit results for simulator")
    return(NULL)
  }

  guard <- validate_simulator_inputs(
    utilities = if (!is.null(hb_results)) hb_results else logit_results,
    config = config
  )

  if (!guard$valid) {
    message(sprintf("[TRS PARTIAL] MAXD_SIM_GUARD: %s", paste(guard$issues, collapse = "; ")))
    return(NULL)
  }

  sim_data <- build_simulator_data(
    hb_results = hb_results,
    logit_results = logit_results,
    config = config,
    segment_results = maxdiff_results$segment_results,
    raw_data = maxdiff_results$raw_data
  )

  sim_dir <- get(".md_sim_dir", envir = globalenv())
  js_dir <- file.path(sim_dir, "js")

  read_js <- function(filename) {
    fpath <- file.path(js_dir, filename)
    if (file.exists(fpath)) paste(readLines(fpath, warn = FALSE), collapse = "\n") else ""
  }

  shared_js <- if (exists("turas_pins_js", mode = "function")) turas_pins_js() else ""

  js_files <- list(
    shared = shared_js,
    engine = read_js("simulator_engine.js"),
    charts = read_js("simulator_charts.js"),
    pins   = read_js("sim_pins.js"),
    export = read_js("simulator_export.js"),
    ui     = read_js("simulator_ui.js")
  )

  build_simulator_page(sim_data, js_files)
}
