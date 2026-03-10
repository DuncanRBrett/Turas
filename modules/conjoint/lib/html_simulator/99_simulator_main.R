# ==============================================================================
# CONJOINT HTML SIMULATOR - MAIN ORCHESTRATOR
# ==============================================================================
#
# Module: Conjoint Analysis - HTML Simulator Generator
# Purpose: Generate self-contained HTML market simulator
# Version: 3.0.0
# Date: 2026-03-10
#
# USAGE:
#   generate_conjoint_html_simulator(utilities, importance, model_result, config, output_path)
#
# OUTPUT:
#   A single HTML file that clients can open in any browser for what-if
#   market simulation. No server required. All data and JS embedded inline.
#
# ==============================================================================

# Null coalesce
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

.conjoint_html_simulator_dir <- if (exists(".conjoint_lib_dir", envir = globalenv())) {
  file.path(get(".conjoint_lib_dir", envir = globalenv()), "html_simulator")
} else {
  tryCatch(dirname(sys.frame(1)$ofile), error = function(e) ".")
}

assign(".sim_submodules_loaded", FALSE, envir = globalenv())


.sim_load_submodules <- function() {
  if (isTRUE(get0(".sim_submodules_loaded", envir = globalenv()))) return(NULL)

  submodules <- c(
    "00_simulator_guard.R",
    "01_simulator_data_transformer.R",
    "02_simulator_page_builder.R"
  )

  for (f in submodules) {
    fpath <- file.path(.conjoint_html_simulator_dir, f)
    if (!file.exists(fpath)) {
      return(list(
        status = "REFUSED",
        code = "IO_SIMULATOR_SUBMODULE_MISSING",
        message = sprintf("Simulator submodule not found: %s", f),
        how_to_fix = sprintf("Ensure %s exists in %s", f, .conjoint_html_simulator_dir)
      ))
    }
    source(fpath, local = FALSE)
  }

  assign(".sim_submodules_loaded", TRUE, envir = globalenv())
  NULL
}


#' Generate Conjoint HTML Simulator
#'
#' Creates a self-contained HTML file for interactive market simulation.
#' Clients can open this in any browser without a server.
#'
#' @param utilities Data frame with Attribute, Level, Utility
#' @param importance Data frame with Attribute, Importance
#' @param model_result Optional turas_conjoint_model (for individual-level data)
#' @param config Configuration object
#' @param output_path File path for HTML output
#' @return TRS status list
#' @export
generate_conjoint_html_simulator <- function(utilities, importance,
                                              model_result = NULL, config,
                                              output_path) {

  # Lazy load
  load_err <- .sim_load_submodules()
  if (!is.null(load_err)) return(load_err)

  cat("\n  [HTML SIMULATOR] Generating interactive market simulator...\n")

  # Validate
  guard_result <- validate_simulator_inputs(utilities, config)
  if (!guard_result$valid) {
    cat(sprintf("\n  [SIMULATOR ERROR] Validation: %s\n", paste(guard_result$errors, collapse = "; ")))
    return(list(
      status = "REFUSED",
      code = "DATA_SIMULATOR_VALIDATION_FAILED",
      message = paste("Validation failed:", paste(guard_result$errors, collapse = "; ")),
      how_to_fix = "Check utilities and config structure"
    ))
  }

  # Build data
  sim_data <- build_simulator_data(utilities, importance, model_result, config)
  sim_json <- simulator_data_to_json(sim_data)

  # Build page
  page <- build_simulator_page(sim_json, config)

  # Write
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  tryCatch({
    writeLines(page, output_path, useBytes = TRUE)
    file_size_mb <- round(file.size(output_path) / (1024 * 1024), 2)
    cat(sprintf("  [HTML SIMULATOR] Written to: %s (%.2f MB)\n", output_path, file_size_mb))

    list(
      status = "PASS",
      output_path = output_path,
      file_size_mb = file_size_mb
    )
  }, error = function(e) {
    cat(sprintf("  [SIMULATOR ERROR] Write failed: %s\n", conditionMessage(e)))
    list(
      status = "REFUSED",
      code = "IO_SIMULATOR_WRITE_FAILED",
      message = sprintf("Failed to write simulator: %s", conditionMessage(e)),
      how_to_fix = sprintf("Check path: %s", output_path)
    )
  })
}


message("TURAS>Conjoint HTML Simulator orchestrator loaded (v3.0.0)")
