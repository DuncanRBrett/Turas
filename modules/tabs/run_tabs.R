# ==============================================================================
# TURAS>TABS - CROSSTABULATION MODULE - SCRIPTED ENTRY POINT
# ==============================================================================
# Runs one crosstab config through the same engine the Shiny GUI uses.
#
# Usage:
#   source("modules/tabs/run_tabs.R")
#   run_tabs_analysis("path/to/My_Crosstab_Config.xlsx")
#
# The recommended route is still the GUI (source("launch_turas.R");
# launch_turas()) — it detects configs, shows progress and captures the
# console. This wrapper exists for scripted/batch runs.
# ==============================================================================

#' Run one tabs analysis from a crosstab config workbook
#'
#' Sets the global `config_file` the engine expects, sources
#' `modules/tabs/lib/run_crosstabs.R` from its own directory (the engine
#' resolves its siblings relative to the working directory), and restores
#' the working directory and globals afterwards.
#'
#' @param config_file Path to a Crosstab_Config .xlsx (as built from
#'   modules/tabs/templates/Crosstab_Config_Template.xlsx).
#'
#' @return Invisibly, TRUE on success; FALSE after a refusal/error (details
#'   are printed to the console — Turas convention: errors must be visible).
run_tabs_analysis <- function(config_file) {
  if (missing(config_file) || is.null(config_file) || !nzchar(config_file)) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: CFG_CONFIG_PATH_MISSING\n")
    cat("Message: run_tabs_analysis() needs the path to a crosstab config workbook.\n")
    cat("Fix: run_tabs_analysis(\"path/to/My_Crosstab_Config.xlsx\")\n")
    cat("===================\n\n")
    return(invisible(FALSE))
  }
  if (!file.exists(config_file)) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: IO_CONFIG_NOT_FOUND\n")
    cat("Message: Config file does not exist:", config_file, "\n")
    cat("Fix: Check the path. Build a new config from modules/tabs/templates/Crosstab_Config_Template.xlsx.\n")
    cat("===================\n\n")
    return(invisible(FALSE))
  }

  # Resolve modules/tabs/lib relative to this script's own location.
  this_file <- tryCatch(normalizePath(sys.frame(1)$ofile), error = function(e) NULL)
  if (is.null(this_file)) {
    args <- commandArgs(trailingOnly = FALSE)
    fa <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
    if (length(fa)) this_file <- normalizePath(fa[1])
  }
  tabs_lib_dir <- if (!is.null(this_file)) {
    file.path(dirname(this_file), "lib")
  } else {
    # Sourced without a file record (e.g. pasted into the console): fall back
    # to the repo layout relative to the working directory.
    candidates <- c("modules/tabs/lib", "tabs/lib", "lib")
    hit <- candidates[file.exists(file.path(candidates, "run_crosstabs.R"))]
    if (!length(hit)) {
      cat("\n=== TURAS ERROR ===\n")
      cat("Code: IO_ENGINE_NOT_FOUND\n")
      cat("Message: Cannot locate modules/tabs/lib/run_crosstabs.R from the working directory.\n")
      cat("Fix: setwd() to the Turas root, or source this file with source(\"modules/tabs/run_tabs.R\").\n")
      cat("===================\n\n")
      return(invisible(FALSE))
    }
    hit[1]
  }

  old_wd <- getwd()
  had_config <- exists("config_file", envir = .GlobalEnv)
  old_config <- if (had_config) get("config_file", envir = .GlobalEnv) else NULL
  on.exit({
    setwd(old_wd)
    if (had_config) {
      assign("config_file", old_config, envir = .GlobalEnv)
    } else if (exists("config_file", envir = .GlobalEnv)) {
      rm("config_file", envir = .GlobalEnv)
    }
  }, add = TRUE)

  # The engine reads the global `config_file` and resolves its sibling scripts
  # from the working directory — the same contract the GUI uses (run_tabs_gui.R).
  assign("config_file", normalizePath(config_file), envir = .GlobalEnv)
  setwd(tabs_lib_dir)

  ok <- tryCatch({
    source("run_crosstabs.R", local = FALSE)
    TRUE
  }, error = function(e) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: CALC_TABS_RUN_FAILED\n")
    cat("Message:", conditionMessage(e), "\n")
    cat("Fix: Read the refusal/output above this box — the engine names the failing step.\n")
    cat("===================\n\n")
    FALSE
  })
  invisible(ok)
}
