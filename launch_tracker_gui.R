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
    stop("Please run this from the Turas directory or use:\n  setwd('/Users/duncan/Documents/Turas')\n  source('launch_tracker_gui.R')")
  }
}

# Source and run GUI
source("modules/tracker/run_tracker_gui.R")
run_tracker_gui()
