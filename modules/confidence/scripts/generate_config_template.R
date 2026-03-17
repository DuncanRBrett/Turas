# ==============================================================================
# Generate Confidence Config Template (v10.3)
# ==============================================================================
# Creates the polished master template Excel file for the confidence module.
# Uses the standard Turas config colour scheme:
#   - Pale yellow: editable input cells
#   - Pale peach: required setting rows
#   - Pale green: optional setting rows
#   - Pale blue with blue italic text: description/help columns
#   - Red badge: REQUIRED label
#   - Grey badge: Optional label
#   - Navy headers, section dividers, legend row
#   - Data validation dropdowns on all constrained fields
#
# Run from Turas root: Rscript modules/confidence/scripts/generate_config_template.R
# ==============================================================================

library(openxlsx)

output_path <- file.path("modules", "confidence", "docs", "templates",
                          "Confidence_Config_Template.xlsx")

wb <- createWorkbook()

# ==============================================================================
# TURAS CONFIG COLOUR SCHEME
# ==============================================================================

brand_navy     <- "#1e3a5f"
white          <- "#FFFFFF"
border_col     <- "#C0C0C0"

# Row tints
peach_fill     <- "#FDEBD0"   # pale peach — required rows
green_fill     <- "#E8F8E8"   # pale green — optional rows
input_fill     <- "#FFF9E6"   # pale yellow — editable value cells
blue_desc_fill <- "#EBF5FB"   # pale blue — description/help columns
section_fill   <- "#D5E3F0"   # light blue-grey — section headers
legend_ro_fill <- "#E8E8E8"   # light grey — read-only legend swatch

# Badge fills
req_badge_bg   <- "#DC3545"   # red badge
opt_badge_bg   <- "#E9ECEF"   # grey badge

# Text colours
blue_text      <- "#2471A3"   # blue text for description columns
guide_grey     <- "#6c757d"   # grey text for guide row

# ==============================================================================
# STYLES
# ==============================================================================

title_style <- createStyle(
  fontSize = 14, textDecoration = "bold", fontColour = brand_navy
)
subtitle_style <- createStyle(fontSize = 11, fontColour = brand_navy)
legend_label_style <- createStyle(fontSize = 10, fontColour = "#333333")

legend_req_style <- createStyle(
  fontSize = 10, textDecoration = "bold", fgFill = peach_fill,
  border = "TopBottomLeftRight", borderColour = border_col, halign = "center"
)
legend_opt_style <- createStyle(
  fontSize = 10, fgFill = green_fill,
  border = "TopBottomLeftRight", borderColour = border_col, halign = "center"
)
legend_input_style <- createStyle(
  fontSize = 10, fgFill = input_fill,
  border = "TopBottomLeftRight", borderColour = border_col, halign = "center"
)
legend_readonly_style <- createStyle(
  fontSize = 10, fgFill = legend_ro_fill,
  border = "TopBottomLeftRight", borderColour = border_col, halign = "center"
)

header_style <- createStyle(
  fontSize = 11, textDecoration = "bold",
  fgFill = brand_navy, fontColour = white,
  border = "TopBottomLeftRight", wrapText = TRUE,
  halign = "left", valign = "center"
)

section_style <- createStyle(
  fontSize = 11, textDecoration = "bold",
  fontColour = brand_navy, fgFill = section_fill,
  border = "TopBottomLeftRight"
)

# Setting name column — required row (peach)
req_name_style <- createStyle(
  border = "TopBottomLeftRight", borderColour = border_col,
  fgFill = peach_fill, valign = "center"
)
# Setting name column — optional row (green)
opt_name_style <- createStyle(
  border = "TopBottomLeftRight", borderColour = border_col,
  fgFill = green_fill, valign = "center"
)

# Value column — always pale yellow (editable input)
input_cell_style <- createStyle(
  border = "TopBottomLeftRight", borderColour = border_col,
  fgFill = input_fill, valign = "center"
)

# Description and Valid Values columns — pale blue, blue italic text
desc_style <- createStyle(
  border = "TopBottomLeftRight", borderColour = border_col,
  fgFill = blue_desc_fill, fontColour = blue_text,
  textDecoration = "italic", wrapText = TRUE, valign = "top"
)

# Required? badge — REQUIRED (bold white on red)
req_badge_style <- createStyle(
  textDecoration = "bold", fontColour = white,
  fgFill = req_badge_bg, halign = "center", valign = "center",
  border = "TopBottomLeftRight", borderColour = border_col
)
# Required? badge — Optional (dark text on grey)
opt_badge_style <- createStyle(
  fontColour = "#555555",
  fgFill = opt_badge_bg, halign = "center", valign = "center",
  border = "TopBottomLeftRight", borderColour = border_col
)

# Guide row (field descriptions under column headers)
guide_style <- createStyle(
  fontSize = 9, fontColour = guide_grey,
  border = "TopBottomLeftRight", borderColour = border_col,
  wrapText = TRUE, valign = "top", fgFill = blue_desc_fill
)

# Example / placeholder data rows
example_style <- createStyle(
  fontColour = guide_grey, textDecoration = "italic",
  border = "TopBottomLeftRight", borderColour = border_col,
  wrapText = TRUE, valign = "top"
)

# Plain bordered cell
cell_style <- createStyle(
  border = "TopBottomLeftRight", borderColour = border_col,
  wrapText = TRUE, valign = "top"
)


# ==============================================================================
# HELPER: Write standard sheet header block (rows 1-5)
# ==============================================================================

write_sheet_header <- function(wb, sheet, title, subtitle, col_names) {
  writeData(wb, sheet, title, startRow = 1, startCol = 1)
  addStyle(wb, sheet, title_style, rows = 1, cols = 1)

  writeData(wb, sheet, subtitle, startRow = 2, startCol = 1)
  addStyle(wb, sheet, subtitle_style, rows = 2, cols = 1)

  # Legend row
  writeData(wb, sheet, "Legend:", startRow = 3, startCol = 1)
  addStyle(wb, sheet, legend_label_style, rows = 3, cols = 1)
  writeData(wb, sheet, "Required", startRow = 3, startCol = 2)
  addStyle(wb, sheet, legend_req_style, rows = 3, cols = 2)
  writeData(wb, sheet, "Optional", startRow = 3, startCol = 3)
  addStyle(wb, sheet, legend_opt_style, rows = 3, cols = 3)
  writeData(wb, sheet, "Your Input", startRow = 3, startCol = 4)
  addStyle(wb, sheet, legend_input_style, rows = 3, cols = 4)
  writeData(wb, sheet, "Read Only", startRow = 3, startCol = 5)
  addStyle(wb, sheet, legend_readonly_style, rows = 3, cols = 5)

  # Row 4: blank spacer

  # Row 5: column headers
  for (j in seq_along(col_names)) {
    writeData(wb, sheet, col_names[j], startRow = 5, startCol = j)
  }
  addStyle(wb, sheet, header_style, rows = 5, cols = 1:length(col_names),
           gridExpand = TRUE)
}


# ==============================================================================
# HELPER: Write section header row
# ==============================================================================

write_section_row <- function(wb, sheet, row, label, n_cols) {
  writeData(wb, sheet, label, startRow = row, startCol = 1)
  addStyle(wb, sheet, section_style, rows = row, cols = 1:n_cols,
           gridExpand = TRUE)
}


# ==============================================================================
# HELPER: Write a setting row with full Turas styling
# ==============================================================================

write_setting_row <- function(wb, sheet, row, setting, value, required,
                               description, valid_values) {
  writeData(wb, sheet, setting,      startRow = row, startCol = 1)
  writeData(wb, sheet, value,        startRow = row, startCol = 2)
  writeData(wb, sheet, required,     startRow = row, startCol = 3)
  writeData(wb, sheet, description,  startRow = row, startCol = 4)
  writeData(wb, sheet, valid_values, startRow = row, startCol = 5)

  # Col 1 (Setting name): peach if required, green if optional
  name_st <- if (required == "REQUIRED") req_name_style else opt_name_style
  addStyle(wb, sheet, name_st, rows = row, cols = 1)

  # Col 2 (Value): always pale yellow
  addStyle(wb, sheet, input_cell_style, rows = row, cols = 2)

  # Col 3 (Required?): red or grey badge
  badge <- if (required == "REQUIRED") req_badge_style else opt_badge_style
  addStyle(wb, sheet, badge, rows = row, cols = 3)

  # Cols 4-5 (Description, Valid Values): pale blue, blue italic
  addStyle(wb, sheet, desc_style, rows = row, cols = 4:5, gridExpand = TRUE)
}


# ==============================================================================
# SHEET 1: File_Paths
# ==============================================================================

addWorksheet(wb, "File_Paths")

write_sheet_header(wb, "File_Paths",
  title     = "TURAS Confidence Module - File Paths",
  subtitle  = "Configure data input and output file locations",
  col_names = c("Setting", "Value", "Required?", "Description",
                "Valid Values / Notes")
)

write_section_row(wb, "File_Paths", 6, "FILE PATHS", 5)

write_setting_row(wb, "File_Paths", 7,
  "Data_File", "", "REQUIRED",
  "Path to your survey data file (CSV or XLSX format). Relative paths are resolved from the config file location.",
  "File path ending in .csv or .xlsx")

write_setting_row(wb, "File_Paths", 8,
  "Output_File", "", "REQUIRED",
  "Path for the output Excel workbook containing confidence interval results.",
  "File path ending in .xlsx")

write_setting_row(wb, "File_Paths", 9,
  "Weight_Variable", "", "Optional",
  "Column name in your data containing survey weights. Leave blank for unweighted analysis.",
  "Column name from your data file")

write_setting_row(wb, "File_Paths", 10,
  "HTML_Output_File", "", "Optional",
  "Path for an optional HTML report. Only generated if Generate_HTML_Report is set to Y.",
  "File path ending in .html")

setColWidths(wb, "File_Paths", cols = 1:5, widths = c(22, 55, 12, 65, 35))
setRowHeights(wb, "File_Paths", rows = 7:10, heights = 30)


# ==============================================================================
# SHEET 2: Study_Settings
# ==============================================================================

addWorksheet(wb, "Study_Settings")

write_sheet_header(wb, "Study_Settings",
  title     = "TURAS Confidence Module - Study Settings",
  subtitle  = "Statistical parameters, output formatting, and branding options",
  col_names = c("Setting", "Value", "Required?", "Description",
                "Valid Values / Notes")
)

write_section_row(wb, "Study_Settings", 6, "STATISTICAL SETTINGS", 5)

write_setting_row(wb, "Study_Settings", 7,
  "Confidence_Level", "0.95", "REQUIRED",
  "Confidence level for interval estimation. 0.95 gives 95% confidence intervals.",
  "0.90, 0.95, or 0.99")

write_setting_row(wb, "Study_Settings", 8,
  "Bootstrap_Iterations", "5000", "Optional",
  "Number of bootstrap resamples. Higher values give more precise intervals but take longer.",
  "Integer between 1000 and 10000")

write_setting_row(wb, "Study_Settings", 9,
  "Calculate_Effective_N", "Y", "Optional",
  "Calculate effective sample size (n_eff) accounting for design effects from weighting.",
  "Y or N")

write_setting_row(wb, "Study_Settings", 10,
  "Multiple_Comparison_Adjustment", "N", "Optional",
  "Apply p-value adjustment for multiple comparisons across questions.",
  "Y or N")

write_setting_row(wb, "Study_Settings", 11,
  "Multiple_Comparison_Method", "", "Optional",
  "Method for multiple comparison adjustment. Only used if Multiple_Comparison_Adjustment is Y.",
  "Bonferroni, Holm, or FDR")

write_section_row(wb, "Study_Settings", 12, "OUTPUT SETTINGS", 5)

write_setting_row(wb, "Study_Settings", 13,
  "Decimal_Separator", ".", "Optional",
  "Character used as the decimal separator in output. Use comma for European formatting.",
  ". or , (period or comma)")

write_setting_row(wb, "Study_Settings", 14,
  "Max_Questions", "200", "Optional",
  "Maximum number of questions to process. Safety limit to prevent runaway processing.",
  "Integer between 1 and 1000")

write_setting_row(wb, "Study_Settings", 15,
  "Generate_HTML_Report", "Y", "Optional",
  "Generate an interactive HTML report in addition to the Excel output.",
  "Y or N")

write_setting_row(wb, "Study_Settings", 16,
  "Sampling_Method", "Not_Specified", "Optional",
  "The sampling methodology used. Affects design effect estimation and interpretation notes.",
  "Random, Stratified, Cluster, Census, Quota, Online_Panel, Self_Selected, Not_Specified")

write_section_row(wb, "Study_Settings", 17, "BRANDING", 5)

write_setting_row(wb, "Study_Settings", 18,
  "Brand_Colour", "#1e3a5f", "Optional",
  "Primary brand colour for HTML report headers and accents. Use hex format.",
  "Hex colour code, e.g. #1e3a5f")

write_setting_row(wb, "Study_Settings", 19,
  "Accent_Colour", "#2aa198", "Optional",
  "Secondary accent colour for HTML report charts and highlights. Use hex format.",
  "Hex colour code, e.g. #2aa198")

write_section_row(wb, "Study_Settings", 20, "ADVANCED", 5)

write_setting_row(wb, "Study_Settings", 21,
  "random_seed", "", "Optional",
  "Set a random seed for reproducible bootstrap and Bayesian results. Leave blank for random.",
  "Any positive integer")

setColWidths(wb, "Study_Settings", cols = 1:5, widths = c(32, 20, 12, 65, 40))
setRowHeights(wb, "Study_Settings", rows = c(7:11, 13:16, 18:19, 21), heights = 30)

# --- DATA VALIDATION: Study_Settings ---
dataValidation(wb, "Study_Settings", cols = 2, rows = 7,
               type = "list", value = '"0.90,0.95,0.99"',
               showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Study_Settings", cols = 2, rows = 8,
               type = "whole", operator = "between", value = c(1000, 10000),
               allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Study_Settings", cols = 2, rows = c(9, 10, 15),
               type = "list", value = '"Y,N"',
               allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Study_Settings", cols = 2, rows = 11,
               type = "list", value = '"Bonferroni,Holm,FDR"',
               allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Study_Settings", cols = 2, rows = 13,
               type = "list", value = '".,,"',
               allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Study_Settings", cols = 2, rows = 14,
               type = "whole", operator = "between", value = c(1, 1000),
               allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Study_Settings", cols = 2, rows = 16,
               type = "list",
               value = '"Random,Stratified,Cluster,Quota,Online_Panel,Self_Selected,Census,Not_Specified"',
               allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)


# ==============================================================================
# SHEET 3: Question_Analysis
# ==============================================================================

addWorksheet(wb, "Question_Analysis")

q_cols <- c(
  "Question_ID", "Question_Label", "Statistic_Type",
  "Run_MOE", "Run_Wilson", "Run_Bootstrap", "Run_Credible",
  "Categories", "Promoter_Codes", "Detractor_Codes",
  "Prior_Mean", "Prior_SD", "Prior_N",
  "Filter_Variable", "Filter_Values", "Notes"
)

writeData(wb, "Question_Analysis",
          "TURAS Confidence Module - Question Analysis",
          startRow = 1, startCol = 1)
addStyle(wb, "Question_Analysis", title_style, rows = 1, cols = 1)

writeData(wb, "Question_Analysis",
          "Define which questions to analyse and which CI methods to apply",
          startRow = 2, startCol = 1)
addStyle(wb, "Question_Analysis", subtitle_style, rows = 2, cols = 1)

# Row 3: Column headers
for (j in seq_along(q_cols)) {
  writeData(wb, "Question_Analysis", q_cols[j], startRow = 3, startCol = j)
}
addStyle(wb, "Question_Analysis", header_style, rows = 3,
         cols = 1:length(q_cols), gridExpand = TRUE)

# Row 4: Guide row (field-level help text) — pale blue background
guide_texts <- c(
  "[REQUIRED] Column name in data that contains responses for this question.",
  "[Optional] Human-readable label for this question. Shown alongside Question_ID in output reports.",
  "[REQUIRED] Type of statistic to compute: proportion (binary/categorical), mean (continuous), or nps (Net Promoter Score).",
  "[REQUIRED] Calculate margin of error using the normal approximation method.",
  "[Optional] Calculate Wilson score confidence interval. Recommended for proportions, especially with small samples.",
  "[REQUIRED] Calculate bootstrap confidence interval. Non-parametric method suitable for any statistic type.",
  "[REQUIRED] Calculate Bayesian credible interval. Requires prior specification for informative priors.",
  "[Optional] Comma-separated category codes for proportion. E.g. '1,2' to calculate proportion of responses coded 1 or 2.",
  "[Optional] Comma-separated codes for NPS promoters. Typically '9,10' on a 0-10 scale.",
  "[Optional] Comma-separated codes for NPS detractors. Typically '0,1,2,3,4,5,6' on a 0-10 scale.",
  "[Optional] Prior mean for Bayesian credible intervals. For proportions use 0-1 range, for means use expected scale.",
  "[Optional] Prior standard deviation for Bayesian credible intervals. Must be greater than 0.",
  "[Optional] Prior effective sample size for Bayesian credible intervals. Controls how much weight is given to the prior.",
  "[Optional] Column name to filter on for sub-sample analysis. E.g. 'Q04' to only include certain respondent groups.",
  "[Optional] Comma-separated values to keep from Filter_Variable. E.g. 'Daily,Weekly' to analyse only frequent users.",
  "[Optional] Free-text notes for documentation. Not used in analysis."
)
for (j in seq_along(guide_texts)) {
  writeData(wb, "Question_Analysis", guide_texts[j], startRow = 4, startCol = j)
}
addStyle(wb, "Question_Analysis", guide_style, rows = 4,
         cols = 1:length(q_cols), gridExpand = TRUE)
setRowHeights(wb, "Question_Analysis", rows = 4, heights = 55)

# Rows 5-8: Example data rows
examples <- data.frame(
  Question_ID     = c("Q_SAT",  "Q_NPS",  "Q_AGREE",  "Q_SUBSET"),
  Question_Label  = c("Overall Satisfaction",
                      "Likelihood to Recommend (NPS)",
                      "Agreement with Statement",
                      "Subset: Daily Users Only"),
  Statistic_Type  = c("mean", "nps", "proportion", "proportion"),
  Run_MOE         = c("Y", "Y", "Y", "Y"),
  Run_Wilson      = c("N", "N", "Y", "Y"),
  Run_Bootstrap   = c("Y", "Y", "Y", "N"),
  Run_Credible    = c("Y", "N", "N", "N"),
  Categories      = c("", "", "4,5", "4,5"),
  Promoter_Codes  = c("", "9,10", "", ""),
  Detractor_Codes = c("", "0,1,2,3,4,5,6", "", ""),
  Prior_Mean      = c("7.5", "", "", ""),
  Prior_SD        = c("1.5", "", "", ""),
  Prior_N         = c("100", "", "", ""),
  Filter_Variable = c("", "", "", "Q_FREQ"),
  Filter_Values   = c("", "", "", "Daily"),
  Notes           = c("1-10 scale. Prior from previous wave.",
                      "Standard 0-10 NPS scale.",
                      "Top-2-box on 5-point Likert (4=Agree, 5=Strongly Agree).",
                      "Only asked to daily users (Q_FREQ=Daily). Subset filtering applied."),
  stringsAsFactors = FALSE
)

writeData(wb, "Question_Analysis", examples, startRow = 5, colNames = FALSE)
for (r in 5:8) {
  addStyle(wb, "Question_Analysis", example_style, rows = r,
           cols = 1:length(q_cols), gridExpand = TRUE)
}

setColWidths(wb, "Question_Analysis",
             cols = 1:length(q_cols),
             widths = c(14, 32, 16, 10, 12, 14, 14, 14, 14, 18, 12, 10, 10,
                        16, 16, 42))

# --- DATA VALIDATION: Question_Analysis ---
dataValidation(wb, "Question_Analysis", cols = 3, rows = 5:54,
               type = "list", value = '"proportion,mean,nps"',
               showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Question_Analysis", cols = 4, rows = 5:54,
               type = "list", value = '"Y,N"',
               showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Question_Analysis", cols = 5, rows = 5:54,
               type = "list", value = '"Y,N"',
               allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Question_Analysis", cols = 6, rows = 5:54,
               type = "list", value = '"Y,N"',
               showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Question_Analysis", cols = 7, rows = 5:54,
               type = "list", value = '"Y,N"',
               showInputMsg = TRUE, showErrorMsg = TRUE)


# ==============================================================================
# SHEET 4: Population_Margins
# ==============================================================================

addWorksheet(wb, "Population_Margins")

margin_cols <- c("Variable", "Category_Label", "Category_Code",
                 "Target_Prop", "Include")

writeData(wb, "Population_Margins",
          "TURAS Confidence Module - Population Margins",
          startRow = 1, startCol = 1)
addStyle(wb, "Population_Margins", title_style, rows = 1, cols = 1)

writeData(wb, "Population_Margins",
          "Define population proportions for representativeness analysis (optional)",
          startRow = 2, startCol = 1)
addStyle(wb, "Population_Margins", subtitle_style, rows = 2, cols = 1)

for (j in seq_along(margin_cols)) {
  writeData(wb, "Population_Margins", margin_cols[j], startRow = 3, startCol = j)
}
addStyle(wb, "Population_Margins", header_style, rows = 3,
         cols = 1:length(margin_cols), gridExpand = TRUE)

# Row 4: Guide row
margin_guides <- c(
  "[REQUIRED] Name of the demographic or stratification variable (must match a column name in your data).",
  "[REQUIRED] Human-readable label for this category (e.g. 'Male', 'Female', '18-34').",
  "[Optional] Numeric or string code used in the data for this category. If blank, Category_Label is used for matching.",
  "[REQUIRED] Target population proportion for this category. All categories within a variable must sum to approximately 1.0.",
  "[Optional] Include this margin in the representativeness analysis. Set to N to temporarily exclude."
)
for (j in seq_along(margin_guides)) {
  writeData(wb, "Population_Margins", margin_guides[j], startRow = 4, startCol = j)
}
addStyle(wb, "Population_Margins", guide_style, rows = 4,
         cols = 1:length(margin_cols), gridExpand = TRUE)
setRowHeights(wb, "Population_Margins", rows = 4, heights = 45)

# Rows 5-9: Example data
margins_ex <- data.frame(
  Variable       = c("Gender", "Gender", "Age_Group", "Age_Group", "Age_Group"),
  Category_Label = c("Male", "Female", "18-34", "35-54", "55+"),
  Category_Code  = c("", "", "", "", ""),
  Target_Prop    = c(0.48, 0.52, 0.30, 0.35, 0.35),
  Include        = c("Y", "Y", "Y", "Y", "Y"),
  stringsAsFactors = FALSE
)

writeData(wb, "Population_Margins", margins_ex, startRow = 5, colNames = FALSE)
for (r in 5:9) {
  addStyle(wb, "Population_Margins", example_style, rows = r,
           cols = 1:length(margin_cols), gridExpand = TRUE)
}

setColWidths(wb, "Population_Margins", cols = 1:5,
             widths = c(18, 20, 16, 14, 10))

# --- DATA VALIDATION: Population_Margins ---
dataValidation(wb, "Population_Margins", cols = 4, rows = 5:34,
               type = "decimal", operator = "between", value = c(0, 1),
               showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Population_Margins", cols = 5, rows = 5:34,
               type = "list", value = '"Y,N"',
               allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)


# ==============================================================================
# SAVE
# ==============================================================================

saveWorkbook(wb, output_path, overwrite = TRUE)
cat("Template saved to:", output_path, "\n")
