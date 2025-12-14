# Check what sheets exist in the Excel file
library(openxlsx)

# CHANGE THIS PATH to your config file location
config_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis/SACS_tracking_config.xlsx"

cat("Sheets in", basename(config_path), ":\n")
cat("================================================================================\n")
sheets <- getSheetNames(config_path)
for (i in seq_along(sheets)) {
  cat(sprintf("%d. %s\n", i, sheets[i]))
}
cat("================================================================================\n")
