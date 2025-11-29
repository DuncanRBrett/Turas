# ==============================================================================
# CREATE EXAMPLE CONJOINT CONFIGURATION FILE
# ==============================================================================
#
# This script creates a realistic example configuration file for the
# enhanced Turas conjoint module
#

library(openxlsx)

# Output path
output_file <- "/home/user/Turas/modules/conjoint/examples/example_config.xlsx"

# Create workbook
wb <- createWorkbook()

# ==============================================================================
# SHEET 1: Settings
# ==============================================================================

addWorksheet(wb, "Settings")

settings_data <- data.frame(
  Setting = c(
    "analysis_type",
    "estimation_method",
    "baseline_handling",
    "choice_type",
    "none_as_baseline",
    "none_label",
    "data_file",
    "output_file",
    "respondent_id_column",
    "choice_set_column",
    "alternative_id_column",
    "chosen_column",
    "confidence_level",
    "generate_market_simulator",
    "include_diagnostics"
  ),
  Value = c(
    "choice",
    "auto",
    "first_level_zero",
    "single",
    "FALSE",
    "None of these",
    "examples/sample_cbc_data.csv",
    "examples/output/example_results.xlsx",
    "resp_id",
    "choice_set_id",
    "alternative_id",
    "chosen",
    "0.95",
    "FALSE",
    "TRUE"
  ),
  Description = c(
    "Analysis type: 'choice' or 'rating'",
    "Estimation method: 'auto', 'mlogit', 'clogit', or 'hb'",
    "How to handle baseline: 'first_level_zero' or 'all_levels_explicit'",
    "Choice type: 'single', 'single_with_none', 'best_worst', 'continuous_sum'",
    "Treat none option as baseline level (TRUE/FALSE)",
    "Label for none option if applicable",
    "Path to data file (relative to config file or absolute)",
    "Path to output Excel file",
    "Column name for respondent ID",
    "Column name for choice set ID",
    "Column name for alternative ID (optional)",
    "Column name for chosen indicator (1=chosen, 0=not chosen)",
    "Confidence level for intervals (0-1)",
    "Generate interactive market simulator sheet (TRUE/FALSE)",
    "Include detailed diagnostics in output (TRUE/FALSE)"
  ),
  stringsAsFactors = FALSE
)

writeData(wb, "Settings", settings_data, startRow = 1, startCol = 1)

# Format Settings sheet
headerStyle <- createStyle(
  fontColour = "#FFFFFF",
  fgFill = "#4F81BD",
  halign = "center",
  valign = "center",
  textDecoration = "bold",
  border = "TopBottomLeftRight"
)

addStyle(wb, "Settings", headerStyle, rows = 1, cols = 1:3, gridExpand = TRUE)
setColWidths(wb, "Settings", cols = 1:3, widths = c(30, 40, 60))
freezePane(wb, "Settings", firstRow = TRUE)

# ==============================================================================
# SHEET 2: Attributes
# ==============================================================================

addWorksheet(wb, "Attributes")

attributes_data <- data.frame(
  AttributeName = c(
    "Brand",
    "Price",
    "Screen_Size",
    "Battery_Life",
    "Camera_Quality"
  ),
  AttributeLabel = c(
    "Brand",
    "Price",
    "Screen Size",
    "Battery Life",
    "Camera Quality"
  ),
  NumLevels = c(4, 4, 3, 3, 3),
  Level1 = c("Apple", "$299", "5.5 inches", "12 hours", "Basic"),
  Level2 = c("Samsung", "$399", "6.1 inches", "18 hours", "Good"),
  Level3 = c("Google", "$499", "6.7 inches", "24 hours", "Excellent"),
  Level4 = c("OnePlus", "$599", NA, NA, NA),
  Level5 = c(NA, NA, NA, NA, NA),
  Level6 = c(NA, NA, NA, NA, NA),
  stringsAsFactors = FALSE
)

writeData(wb, "Attributes", attributes_data, startRow = 1, startCol = 1)

# Format Attributes sheet
addStyle(wb, "Attributes", headerStyle, rows = 1, cols = 1:9, gridExpand = TRUE)
setColWidths(wb, "Attributes", cols = 1:2, widths = c(20, 20))
setColWidths(wb, "Attributes", cols = 3, widths = 15)
setColWidths(wb, "Attributes", cols = 4:9, widths = c(15, 15, 15, 15, 15, 15))
freezePane(wb, "Attributes", firstRow = TRUE)

# Add instructions worksheet
addWorksheet(wb, "Instructions")

instructions <- c(
  "TURAS CONJOINT ANALYSIS - EXAMPLE CONFIGURATION",
  "",
  "This is an example configuration file for a smartphone choice-based conjoint study.",
  "",
  "STUDY DESIGN:",
  "- Choice-based conjoint (CBC)",
  "- 5 attributes with 3-4 levels each",
  "- Auto estimation method (tries mlogit first, falls back to clogit)",
  "- First level of each attribute used as reference (utility = 0)",
  "",
  "ATTRIBUTES:",
  "1. Brand: Apple, Samsung, Google, OnePlus",
  "2. Price: $299, $399, $499, $599",
  "3. Screen Size: 5.5\", 6.1\", 6.7\"",
  "4. Battery Life: 12h, 18h, 24h",
  "5. Camera Quality: Basic, Good, Excellent",
  "",
  "TO USE THIS EXAMPLE:",
  "1. Ensure sample_cbc_data.csv exists in the same directory",
  "2. Run: source('modules/conjoint/R/00_main.R')",
  "3. Run: results <- run_conjoint_analysis('examples/example_config.xlsx')",
  "4. Check output in: examples/output/example_results.xlsx",
  "",
  "CUSTOMIZATION:",
  "- Modify attribute names and levels in the Attributes sheet",
  "- Adjust settings in the Settings sheet",
  "- Update data_file path to point to your data",
  "",
  "For more information, see the specification documents in modules/conjoint/"
)

writeData(wb, "Instructions", data.frame(Instructions = instructions),
          startRow = 1, startCol = 1, colNames = FALSE)
setColWidths(wb, "Instructions", cols = 1, widths = 100)

# Save workbook
saveWorkbook(wb, output_file, overwrite = TRUE)

cat("✓ Example configuration created:", output_file, "\n")
