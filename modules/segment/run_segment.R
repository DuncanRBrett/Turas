# ==============================================================================
# TURAS SEGMENTATION MODULE - ENTRY POINT
# ==============================================================================
# Thin entry point that sources the main orchestrator.
# All logic lives in R/00_main.R.
#
# VERSION: 11.0
# ==============================================================================

# Source the main orchestrator (which sources all dependencies)
turas_root <- Sys.getenv("TURAS_ROOT", getwd())
source(file.path(turas_root, "modules/segment/R/00_main.R"))

# ==============================================================================
# COMMAND LINE EXECUTION
# ==============================================================================

if (!interactive() && sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) == 0) {
    cat("Usage: Rscript run_segment.R <config_file.xlsx>\n")
    cat("Example: Rscript run_segment.R segment_config.xlsx\n")
    quit(status = 1)
  }

  config_file <- args[1]

  if (!file.exists(config_file)) {
    cat(sprintf("Error: Config file not found: %s\n", config_file))
    quit(status = 1)
  }

  result <- turas_segment_from_config(config_file)
  quit(status = 0)
}

# ==============================================================================
# END OF RUN_SEGMENT.R
# ==============================================================================
