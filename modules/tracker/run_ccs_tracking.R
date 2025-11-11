#!/usr/bin/env Rscript
# Run CCS Tracking Analysis
# This script has the paths pre-configured with no line breaks

setwd("/Users/duncan/Documents/Turas/modules/tracker")
source("run_tracker.R")

# Paths defined as variables to avoid line break issues
config_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/CCPB/CCPB-CCS/04_CrossWave/CCS_tracking_config.xlsx"
mapping_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/CCPB/CCPB-CCS/04_CrossWave/CCS_question_mapping.xlsx"
data_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/CCPB/CCPB-CCS/04_CrossWave/"
output_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/CCPB/CCPB-CCS/04_CrossWave/CCS_tracking_output.xlsx"

# Run tracker
output_file <- run_tracker(
  tracking_config_path = config_path,
  question_mapping_path = mapping_path,
  data_dir = data_path,
  output_path = output_path,
  use_banners = TRUE
)

cat("\n")
cat("================================================================================\n")
cat("SUCCESS!\n")
cat("================================================================================\n")
cat("Output file:", output_file, "\n")
