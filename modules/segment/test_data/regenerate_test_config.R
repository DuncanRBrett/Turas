# ==============================================================================
# REGENERATE TEST CONFIG EXCEL FILE
# ==============================================================================
# This script converts the test_segment_config.csv to test_segment_config.xlsx
# Run this if you've updated the CSV file
# ==============================================================================

# Load library
library(writexl)

# Read CSV
config_data <- read.csv(
  'modules/segment/test_data/test_segment_config.csv',
  stringsAsFactors = FALSE
)

# Write to Excel
write_xlsx(
  list(Config = config_data),
  'modules/segment/test_data/test_segment_config.xlsx'
)

cat("✓ Updated test_segment_config.xlsx\n")
cat(sprintf("  Rows: %d\n", nrow(config_data)))
cat(sprintf("  Parameters: %s\n", paste(head(config_data$Setting, 5), collapse = ", ")))
