# ==============================================================================
# TURAS>TRACKER GUI LAUNCHER
# ==============================================================================
# Quick launcher for Turas Tracker GUI
# ==============================================================================

# Set working directory to Turas root
# If running from RStudio, use current file location
if (exists("rstudioapi") && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
} else {
  # Otherwise assume we're already in the right directory
  # or set it manually before sourcing
  if (basename(getwd()) != "Turas") {
    stop("Please run this from the Turas root directory (the one containing launch_turas.R).\n  Alternatively, set the TURAS_ROOT environment variable before sourcing.")
  }
}

# Source and run GUI
source("modules/tracker/run_tracker_gui.R")
run_tracker_gui()
