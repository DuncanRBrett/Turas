# ==============================================================================
# CREATE DEMO MAXDIFF CONFIG FILE
# ==============================================================================
# Run this script to generate Demo_MaxDiff_Config.xlsx
# Enables ALL module features for a full showcase demonstration.
# Requires: openxlsx
# ==============================================================================

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  cat("\n=== TURAS ERROR ===\n")
  cat("Package 'openxlsx' is required. Install with: install.packages('openxlsx')\n")
  cat("==================\n\n")
  return(invisible(NULL))
}

library(openxlsx)

demo_dir <- "examples/maxdiff/demo_showcase"
config_path <- file.path(demo_dir, "Demo_MaxDiff_Config.xlsx")

wb <- createWorkbook()

# --- PROJECT_SETTINGS ---
addWorksheet(wb, "PROJECT_SETTINGS")
project_settings <- data.frame(
  Setting_Name = c(
    "Project_Name", "Mode", "Raw_Data_File", "Design_File",
    "Data_File_Sheet", "Output_Folder", "Respondent_ID_Variable",
    "Weight_Variable", "Filter_Expression", "Seed", "Module_Version",
    "Brand_Colour", "Accent_Colour"
  ),
  Value = c(
    "Smartphone Feature Priorities",
    "ANALYSIS",
    "demo_data.csv",
    "demo_design.xlsx",
    "",
    "output",
    "Respondent_ID",
    "Weight",
    "",
    "42",
    "11.0",
    "#1e3a5f",
    "#2aa198"
  ),
  stringsAsFactors = FALSE
)
writeData(wb, "PROJECT_SETTINGS", project_settings)

# --- ITEMS ---
addWorksheet(wb, "ITEMS")
items <- data.frame(
  Item_ID = paste0("F", sprintf("%02d", 1:12)),
  Item_Label = c(
    "Battery Life", "Camera Quality", "Screen Size", "Affordable Price",
    "Brand Reputation", "Storage Capacity", "Processor Speed",
    "Water Resistance", "5G Connectivity", "Wireless Charging",
    "Lightweight Design", "Premium Build Quality"
  ),
  Item_Group = c(
    "Performance", "Camera", "Display", "Price",
    "Brand", "Storage", "Performance", "Durability",
    "Connectivity", "Charging", "Design", "Design"
  ),
  Include = rep(1, 12),
  Anchor_Item = rep(0, 12),
  Display_Order = 1:12,
  stringsAsFactors = FALSE
)
writeData(wb, "ITEMS", items)

# --- DESIGN_SETTINGS ---
addWorksheet(wb, "DESIGN_SETTINGS")
design_settings <- data.frame(
  Parameter_Name = c(
    "Items_Per_Task", "Tasks_Per_Respondent", "Num_Versions",
    "Design_Type", "Randomise_Task_Order", "Randomise_Item_Order_Within_Task"
  ),
  Value = c("4", "10", "3", "BALANCED", "YES", "YES"),
  stringsAsFactors = FALSE
)
writeData(wb, "DESIGN_SETTINGS", design_settings)

# --- SURVEY_MAPPING ---
addWorksheet(wb, "SURVEY_MAPPING")
mapping_rows <- list()
idx <- 1

# Version mapping
mapping_rows[[idx]] <- data.frame(Field_Type = "VERSION", Field_Name = "Version",
                                   Task_Number = NA, stringsAsFactors = FALSE)
idx <- idx + 1

# Best/Worst for each task (wide format: Best_T1, Worst_T1, ..., Best_T10, Worst_T10)
for (t in 1:10) {
  mapping_rows[[idx]] <- data.frame(Field_Type = "BEST_CHOICE",
                                     Field_Name = sprintf("Best_T%d", t),
                                     Task_Number = t, stringsAsFactors = FALSE)
  idx <- idx + 1
  mapping_rows[[idx]] <- data.frame(Field_Type = "WORST_CHOICE",
                                     Field_Name = sprintf("Worst_T%d", t),
                                     Task_Number = t, stringsAsFactors = FALSE)
  idx <- idx + 1
}

# Anchor
mapping_rows[[idx]] <- data.frame(Field_Type = "ANCHOR", Field_Name = "Anchor_Items",
                                   Task_Number = NA, stringsAsFactors = FALSE)

survey_mapping <- do.call(rbind, mapping_rows)
writeData(wb, "SURVEY_MAPPING", survey_mapping)

# --- SEGMENT_SETTINGS ---
addWorksheet(wb, "SEGMENT_SETTINGS")
segments <- data.frame(
  Segment_ID = c("young", "middle", "senior", "male", "female"),
  Segment_Label = c("Age 18-34", "Age 35-54", "Age 55+", "Male", "Female"),
  Variable_Name = c("Age_Group", "Age_Group", "Age_Group", "Gender", "Gender"),
  Segment_Def = c(
    'Age_Group == "18-34"',
    'Age_Group == "35-54"',
    'Age_Group == "55+"',
    'Gender == "Male"',
    'Gender == "Female"'
  ),
  Include_in_Output = rep(1, 5),
  stringsAsFactors = FALSE
)
writeData(wb, "SEGMENT_SETTINGS", segments)

# --- OUTPUT_SETTINGS ---
# All features enabled for full showcase
addWorksheet(wb, "OUTPUT_SETTINGS")
output_settings <- data.frame(
  Setting_Name = c(
    "Generate_Count_Scores",
    "Generate_Aggregate_Logit",
    "Generate_HB_Model",
    "Generate_Segment_Tables",
    "Generate_Charts",
    "Generate_HTML_Report",
    "Generate_Simulator",
    "Generate_TURF",
    "TURF_Max_Items",
    "TURF_Threshold",
    "Has_Anchor_Question",
    "Anchor_Variable",
    "Anchor_Threshold",
    "Anchor_Format",
    "Export_Individual_Utils",
    "Generate_Design_File",
    "Score_Rescale_Method",
    "Output_Item_Sort_Order",
    "Min_Respondents_Per_Segment",
    "Score_Display",
    "HB_Iterations",
    "HB_Warmup",
    "HB_Chains"
  ),
  Value = c(
    "YES",
    "YES",
    "YES",
    "YES",
    "YES",
    "YES",
    "YES",
    "YES",
    "8",
    "ABOVE_MEAN",
    "YES",
    "Anchor_Items",
    "0.50",
    "COMMA_SEPARATED",
    "YES",
    "NO",
    "PROBABILITY",
    "UTILITY_DESC",
    "20",
    "BOTH",
    "1000",
    "500",
    "2"
  ),
  stringsAsFactors = FALSE
)
writeData(wb, "OUTPUT_SETTINGS", output_settings)

# --- Style ---
headerStyle <- createStyle(fontName = "Arial", fontSize = 11, fontColour = "#FFFFFF",
                           fgFill = "#1e3a5f", textDecoration = "bold")

for (sheet in names(wb)) {
  addStyle(wb, sheet, headerStyle, rows = 1, cols = 1:10, gridExpand = TRUE)
  setColWidths(wb, sheet, cols = 1:10, widths = "auto")
}

# Save
saveWorkbook(wb, config_path, overwrite = TRUE)
cat(sprintf("Config saved: %s\n", config_path))
cat("\nFeatures enabled:\n")
cat("  - Count-based scores\n")
cat("  - Aggregate logit model\n")
cat("  - Hierarchical Bayes estimation\n")
cat("  - Segment tables (Age Group + Gender)\n")
cat("  - SVG charts\n")
cat("  - Interactive HTML report\n")
cat("  - Interactive simulator\n")
cat("  - TURF portfolio optimization (max 8 items, above-mean threshold)\n")
cat("  - Anchored MaxDiff (Anchor_Items column)\n")
cat("  - Individual utility export\n")
cat("  - Brand colour: #1e3a5f, Accent colour: #2aa198\n")
cat("  - Weight variable: Weight\n")
cat("  - Output folder: output/\n")
