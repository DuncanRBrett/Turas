# ==============================================================================
# DEBUG TRACKER RUN
# ==============================================================================
# This script runs the tracker directly in R with full error output visible
# ==============================================================================

# Set working directory to Turas root
setwd("/home/user/Turas")

# Source the tracker module
source("modules/tracker/run_tracker.R")

# Enable full error traceback
options(error = function() {
  cat("\n!!! ERROR OCCURRED !!!\n")
  cat("Error message:", geterrmessage(), "\n\n")
  cat("Call stack:\n")
  traceback()
})

# Your config file path - UPDATE THIS to your actual path
config_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis/SACS_tracking_config.xlsx"

# Run the tracker
cat("================================================================================\n")
cat("RUNNING TRACKER WITH FULL ERROR OUTPUT\n")
cat("================================================================================\n\n")

result <- run_tracker(config_path)

cat("\n================================================================================\n")
cat("TRACKER COMPLETED\n")
cat("================================================================================\n")
