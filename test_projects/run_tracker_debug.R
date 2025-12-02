# ==============================================================================
# DEBUG TRACKER RUN
# ==============================================================================
# This script runs the tracker directly in R with full error output visible
# ==============================================================================

# Ensure we're in the Turas root directory
# (Assumes you've already set your working directory to the Turas folder)
cat("Current working directory:", getwd(), "\n")

# Change to tracker module directory to source correctly
old_wd <- getwd()
setwd("modules/tracker")

# Source the tracker module
source("run_tracker.R")

# Return to original directory
setwd(old_wd)

# Enable full error traceback
options(error = function() {
  cat("\n!!! ERROR OCCURRED !!!\n")
  cat("Error message:", geterrmessage(), "\n\n")
  cat("Call stack:\n")
  traceback()
})

# Your file paths - UPDATE THESE to your actual paths
config_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis/SACS_tracking_config.xlsx"
mapping_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis/SACS_question_mapping.xlsx"

# Run the tracker
cat("================================================================================\n")
cat("RUNNING TRACKER WITH FULL ERROR OUTPUT\n")
cat("================================================================================\n\n")

# Run with separate config and mapping files
result <- run_tracker(
  tracking_config_path = config_path,
  question_mapping_path = mapping_path
)

cat("\n================================================================================\n")
cat("TRACKER COMPLETED\n")
cat("================================================================================\n")
