#!/usr/bin/env Rscript
# Debug script to run tracker and see all output

# Set paths - CHANGE THESE TO YOUR SACS PROJECT PATHS
tracking_config_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis/SACS_tracking_config.xlsx"
question_mapping_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis/SACS_question_mapping.xlsx"
data_dir <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis"
output_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis/SACS_debug_output.xlsx"

# Change to tracker directory
# Find Turas root (portable path resolution)
find_turas_root <- function() {
  # Try environment variable first
  if (Sys.getenv("TURAS_HOME") != "") {
    return(Sys.getenv("TURAS_HOME"))
  }

  # Otherwise walk up directory tree
  current_dir <- getwd()
  while (current_dir != dirname(current_dir)) {
    if (file.exists(file.path(current_dir, "launch_turas.R")) ||
        dir.exists(file.path(current_dir, "modules"))) {
      return(current_dir)
    }
    current_dir <- dirname(current_dir)
  }
  stop("Cannot locate Turas root directory. Set TURAS_HOME or run from within Turas directory.")
}

turas_root <- find_turas_root()
setwd(file.path(turas_root, "modules", "tracker"))

# Source run_tracker.R
source("run_tracker.R")

# Run tracker with banners
cat("\n=== RUNNING TRACKER WITH BANNERS ===\n\n")
result <- run_tracker(
  tracking_config_path = tracking_config_path,
  question_mapping_path = question_mapping_path,
  data_dir = data_dir,
  output_path = output_path,
  use_banners = TRUE
)

cat("\n\n=== TRACKER COMPLETED ===\n")
cat("Output file:", result, "\n")
