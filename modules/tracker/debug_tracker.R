#!/usr/bin/env Rscript
# Debug script to run tracker and see all output

# Set paths - CHANGE THESE TO YOUR SACS PROJECT PATHS
tracking_config_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis/SACS_tracking_config.xlsx"
question_mapping_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis/SACS_question_mapping.xlsx"
data_dir <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis"
output_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis/SACS_debug_output.xlsx"

# Change to tracker directory
setwd(file.path(Sys.getenv("TURAS_HOME"), "modules", "tracker"))

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
