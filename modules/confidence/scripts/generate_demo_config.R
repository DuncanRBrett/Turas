# ==============================================================================
# Generate Demo Confidence Config for CCS-W4
# ==============================================================================
# Creates a confidence config for the National Coffee Culture Survey (Wave 4)
# demo dataset. Uses the standard Turas config colour scheme:
#   - Pale yellow: editable input cells
#   - Pale peach: required setting rows
#   - Pale green: optional setting rows
#   - Pale blue with blue italic text: description/help columns
#   - Data validation dropdowns on all constrained fields
# ==============================================================================

library(openxlsx)

# Set demo_dir before sourcing, or override with TURAS_DEMO_DIR env var
demo_dir   <- Sys.getenv("TURAS_DEMO_DIR", "examples/confidence/demo")
output_dir <- file.path(demo_dir, "output")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

config_path <- file.path(demo_dir, "CCS-W4_Confidence_Config.xlsx")

wb <- createWorkbook()

# ==============================================================================
# TURAS CONFIG COLOUR SCHEME (identical to template generator)
# ==============================================================================

brand_navy     <- "#1e3a5f"
white          <- "#FFFFFF"
border_col     <- "#C0C0C0"
peach_fill     <- "#FDEBD0"
green_fill     <- "#E8F8E8"
input_fill     <- "#FFF9E6"
blue_desc_fill <- "#EBF5FB"
section_fill   <- "#D5E3F0"
legend_ro_fill <- "#E8E8E8"
req_badge_bg   <- "#DC3545"
opt_badge_bg   <- "#E9ECEF"
blue_text      <- "#2471A3"
guide_grey     <- "#6c757d"

title_style <- createStyle(fontSize = 14, textDecoration = "bold", fontColour = brand_navy)
subtitle_style <- createStyle(fontSize = 11, fontColour = brand_navy)
legend_label_style <- createStyle(fontSize = 10, fontColour = "#333333")
legend_req_style <- createStyle(fontSize = 10, textDecoration = "bold", fgFill = peach_fill, border = "TopBottomLeftRight", borderColour = border_col, halign = "center")
legend_opt_style <- createStyle(fontSize = 10, fgFill = green_fill, border = "TopBottomLeftRight", borderColour = border_col, halign = "center")
legend_input_style <- createStyle(fontSize = 10, fgFill = input_fill, border = "TopBottomLeftRight", borderColour = border_col, halign = "center")
legend_readonly_style <- createStyle(fontSize = 10, fgFill = legend_ro_fill, border = "TopBottomLeftRight", borderColour = border_col, halign = "center")
header_style <- createStyle(fontSize = 11, textDecoration = "bold", fgFill = brand_navy, fontColour = white, border = "TopBottomLeftRight", wrapText = TRUE, halign = "left", valign = "center")
section_style <- createStyle(fontSize = 11, textDecoration = "bold", fontColour = brand_navy, fgFill = section_fill, border = "TopBottomLeftRight")
req_name_style <- createStyle(border = "TopBottomLeftRight", borderColour = border_col, fgFill = peach_fill, valign = "center")
opt_name_style <- createStyle(border = "TopBottomLeftRight", borderColour = border_col, fgFill = green_fill, valign = "center")
input_cell_style <- createStyle(border = "TopBottomLeftRight", borderColour = border_col, fgFill = input_fill, valign = "center")
desc_style <- createStyle(border = "TopBottomLeftRight", borderColour = border_col, fgFill = blue_desc_fill, fontColour = blue_text, textDecoration = "italic", wrapText = TRUE, valign = "top")
req_badge_style <- createStyle(textDecoration = "bold", fontColour = white, fgFill = req_badge_bg, halign = "center", valign = "center", border = "TopBottomLeftRight", borderColour = border_col)
opt_badge_style <- createStyle(fontColour = "#555555", fgFill = opt_badge_bg, halign = "center", valign = "center", border = "TopBottomLeftRight", borderColour = border_col)
cell_style <- createStyle(border = "TopBottomLeftRight", borderColour = border_col, wrapText = TRUE, valign = "top")

# ==============================================================================
# HELPERS
# ==============================================================================

write_sheet_header <- function(wb, sheet, title, subtitle, col_names) {
  writeData(wb, sheet, title, startRow = 1, startCol = 1)
  addStyle(wb, sheet, title_style, rows = 1, cols = 1)
  writeData(wb, sheet, subtitle, startRow = 2, startCol = 1)
  addStyle(wb, sheet, subtitle_style, rows = 2, cols = 1)
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
  for (j in seq_along(col_names)) {
    writeData(wb, sheet, col_names[j], startRow = 5, startCol = j)
  }
  addStyle(wb, sheet, header_style, rows = 5, cols = 1:length(col_names), gridExpand = TRUE)
}

write_section_row <- function(wb, sheet, row, label, n_cols) {
  writeData(wb, sheet, label, startRow = row, startCol = 1)
  addStyle(wb, sheet, section_style, rows = row, cols = 1:n_cols, gridExpand = TRUE)
}

write_setting_row <- function(wb, sheet, row, setting, value, required, description, valid_values) {
  writeData(wb, sheet, setting,      startRow = row, startCol = 1)
  writeData(wb, sheet, value,        startRow = row, startCol = 2)
  writeData(wb, sheet, required,     startRow = row, startCol = 3)
  writeData(wb, sheet, description,  startRow = row, startCol = 4)
  writeData(wb, sheet, valid_values, startRow = row, startCol = 5)
  name_st <- if (required == "REQUIRED") req_name_style else opt_name_style
  addStyle(wb, sheet, name_st, rows = row, cols = 1)
  addStyle(wb, sheet, input_cell_style, rows = row, cols = 2)
  badge <- if (required == "REQUIRED") req_badge_style else opt_badge_style
  addStyle(wb, sheet, badge, rows = row, cols = 3)
  addStyle(wb, sheet, desc_style, rows = row, cols = 4:5, gridExpand = TRUE)
}


# ==============================================================================
# SHEET 1: File_Paths
# ==============================================================================

addWorksheet(wb, "File_Paths")

write_sheet_header(wb, "File_Paths",
  title = "TURAS Confidence Module - File Paths",
  subtitle = "Configure data input and output file locations",
  col_names = c("Setting", "Value", "Required?", "Description", "Valid Values / Notes"))

write_section_row(wb, "File_Paths", 6, "FILE PATHS", 5)

write_setting_row(wb, "File_Paths", 7, "Data_File", file.path(demo_dir, "CCS-W4_data.xlsx"), "REQUIRED",
  "Path to your survey data file (CSV or XLSX format).", "File path ending in .csv or .xlsx")
write_setting_row(wb, "File_Paths", 8, "Output_File", file.path(output_dir, "CCS-W4_Confidence_Results.xlsx"), "REQUIRED",
  "Path for the output Excel workbook containing confidence interval results.", "File path ending in .xlsx")
write_setting_row(wb, "File_Paths", 9, "Weight_Variable", "", "Optional",
  "Column name in your data containing survey weights. Leave blank for unweighted analysis.", "Column name from your data file")
write_setting_row(wb, "File_Paths", 10, "HTML_Output_File", file.path(output_dir, "CCS-W4_Confidence_Report.html"), "Optional",
  "Path for an optional HTML report. Only generated if Generate_HTML_Report is set to Y.", "File path ending in .html")

setColWidths(wb, "File_Paths", cols = 1:5, widths = c(22, 55, 12, 65, 35))
setRowHeights(wb, "File_Paths", rows = 7:10, heights = 30)


# ==============================================================================
# SHEET 2: Study_Settings
# ==============================================================================

addWorksheet(wb, "Study_Settings")

write_sheet_header(wb, "Study_Settings",
  title = "TURAS Confidence Module - Study Settings",
  subtitle = "Statistical parameters, output formatting, and branding options",
  col_names = c("Setting", "Value", "Required?", "Description", "Valid Values / Notes"))

write_section_row(wb, "Study_Settings", 6, "STATISTICAL SETTINGS", 5)
write_setting_row(wb, "Study_Settings", 7, "Confidence_Level", "0.95", "REQUIRED",
  "Confidence level for interval estimation. 0.95 gives 95% confidence intervals.", "0.90, 0.95, or 0.99")
write_setting_row(wb, "Study_Settings", 8, "Bootstrap_Iterations", "5000", "Optional",
  "Number of bootstrap resamples. Higher values give more precise intervals but take longer.", "Integer between 1000 and 10000")
write_setting_row(wb, "Study_Settings", 9, "Calculate_Effective_N", "N", "Optional",
  "Calculate effective sample size (n_eff) accounting for design effects from weighting.", "Y or N")
write_setting_row(wb, "Study_Settings", 10, "Multiple_Comparison_Adjustment", "N", "Optional",
  "Apply p-value adjustment for multiple comparisons across questions.", "Y or N")
write_setting_row(wb, "Study_Settings", 11, "Multiple_Comparison_Method", "", "Optional",
  "Method for multiple comparison adjustment. Only used if Multiple_Comparison_Adjustment is Y.", "Bonferroni, Holm, or FDR")

write_section_row(wb, "Study_Settings", 12, "OUTPUT SETTINGS", 5)
write_setting_row(wb, "Study_Settings", 13, "Decimal_Separator", ".", "Optional",
  "Character used as the decimal separator in output. Use comma for European formatting.", ". or , (period or comma)")
write_setting_row(wb, "Study_Settings", 14, "Max_Questions", "200", "Optional",
  "Maximum number of questions to process. Safety limit to prevent runaway processing.", "Integer between 1 and 1000")
write_setting_row(wb, "Study_Settings", 15, "Generate_HTML_Report", "Y", "Optional",
  "Generate an interactive HTML report in addition to the Excel output.", "Y or N")
write_setting_row(wb, "Study_Settings", 16, "Sampling_Method", "Quota", "Optional",
  "The sampling methodology used. Affects design effect estimation and interpretation notes.",
  "Random, Stratified, Cluster, Census, Quota, Online_Panel, Self_Selected, Not_Specified")

write_section_row(wb, "Study_Settings", 17, "BRANDING", 5)
write_setting_row(wb, "Study_Settings", 18, "Brand_Colour", "#1e3a5f", "Optional",
  "Primary brand colour for HTML report headers and accents. Use hex format.", "Hex colour code, e.g. #1e3a5f")
write_setting_row(wb, "Study_Settings", 19, "Accent_Colour", "#2aa198", "Optional",
  "Secondary accent colour for HTML report charts and highlights. Use hex format.", "Hex colour code, e.g. #2aa198")

write_section_row(wb, "Study_Settings", 20, "ADVANCED", 5)
write_setting_row(wb, "Study_Settings", 21, "random_seed", "42", "Optional",
  "Set a random seed for reproducible bootstrap and Bayesian results. Leave blank for random.", "Any positive integer")

setColWidths(wb, "Study_Settings", cols = 1:5, widths = c(32, 20, 12, 65, 40))
setRowHeights(wb, "Study_Settings", rows = c(7:11, 13:16, 18:19, 21), heights = 30)

# Data validation
dataValidation(wb, "Study_Settings", cols = 2, rows = 7, type = "list", value = '"0.90,0.95,0.99"', showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Study_Settings", cols = 2, rows = 8, type = "whole", operator = "between", value = c(1000, 10000), allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Study_Settings", cols = 2, rows = c(9, 10, 15), type = "list", value = '"Y,N"', allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Study_Settings", cols = 2, rows = 11, type = "list", value = '"Bonferroni,Holm,FDR"', allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Study_Settings", cols = 2, rows = 13, type = "list", value = '".,,"', allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Study_Settings", cols = 2, rows = 14, type = "whole", operator = "between", value = c(1, 1000), allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Study_Settings", cols = 2, rows = 16, type = "list", value = '"Random,Stratified,Cluster,Quota,Online_Panel,Self_Selected,Census,Not_Specified"', allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)


# ==============================================================================
# SHEET 3: Question_Analysis
# ==============================================================================

addWorksheet(wb, "Question_Analysis")
q_cols <- c("Question_ID", "Question_Label", "Statistic_Type", "Run_MOE", "Run_Wilson", "Run_Bootstrap", "Run_Credible", "Categories", "Promoter_Codes", "Detractor_Codes", "Prior_Mean", "Prior_SD", "Prior_N", "Filter_Variable", "Filter_Values", "Notes")

writeData(wb, "Question_Analysis", "TURAS Confidence Module - Question Analysis", startRow = 1, startCol = 1)
addStyle(wb, "Question_Analysis", title_style, rows = 1, cols = 1)
writeData(wb, "Question_Analysis", "Define which questions to analyse and which CI methods to apply", startRow = 2, startCol = 1)
addStyle(wb, "Question_Analysis", subtitle_style, rows = 2, cols = 1)

for (j in seq_along(q_cols)) writeData(wb, "Question_Analysis", q_cols[j], startRow = 3, startCol = j)
addStyle(wb, "Question_Analysis", header_style, rows = 3, cols = 1:length(q_cols), gridExpand = TRUE)

questions <- data.frame(
  Question_ID     = c("Q07", "Q08", "Q09", "Q10", "Q12", "Q16", "Q09"),
  Question_Label  = c("Overall Satisfaction (1-10)", "Likelihood to Recommend (NPS)", "Coffee Quality Consistently Good (Top-2-Box)", "Prices Good Value (Top-2-Box)", "Staff Friendly and Helpful (Top-2-Box)", "Sustainability Important (Top-2-Box)", "Coffee Quality (Daily Users Only)"),
  Statistic_Type  = c("mean", "nps", "proportion", "proportion", "proportion", "proportion", "proportion"),
  Run_MOE         = c("Y", "Y", "Y", "Y", "Y", "Y", "Y"),
  Run_Wilson      = c("N", "N", "Y", "Y", "Y", "Y", "Y"),
  Run_Bootstrap   = c("Y", "Y", "Y", "N", "N", "N", "N"),
  Run_Credible    = c("N", "N", "N", "N", "N", "N", "N"),
  Categories      = c("", "", "4,5", "4,5", "4,5", "4,5", "4,5"),
  Promoter_Codes  = c("", "9,10", "", "", "", "", ""),
  Detractor_Codes = c("", "0,1,2,3,4,5,6", "", "", "", "", ""),
  Prior_Mean      = c("", "", "", "", "", "", ""),
  Prior_SD        = c("", "", "", "", "", "", ""),
  Prior_N         = c("", "", "", "", "", "", ""),
  Filter_Variable = c("", "", "", "", "", "", "Q04"),
  Filter_Values   = c("", "", "", "", "", "", "Daily"),
  Notes           = c("1-10 satisfaction scale", "Standard 0-10 NPS scale", "5-point Likert: 4=Agree, 5=Strongly Agree", "5-point Likert: top-2-box agreement", "5-point Likert: top-2-box agreement", "5-point importance scale: top-2-box", "SUBSET: Only daily coffee drinkers (Q04=Daily)"),
  stringsAsFactors = FALSE)

writeData(wb, "Question_Analysis", questions, startRow = 4, colNames = FALSE)
for (r in 4:(3 + nrow(questions))) addStyle(wb, "Question_Analysis", cell_style, rows = r, cols = 1:length(q_cols), gridExpand = TRUE)

setColWidths(wb, "Question_Analysis", cols = 1:length(q_cols), widths = c(14, 42, 16, 10, 12, 14, 14, 14, 14, 18, 12, 10, 10, 16, 14, 50))

dataValidation(wb, "Question_Analysis", cols = 3, rows = 4:54, type = "list", value = '"proportion,mean,nps"', showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Question_Analysis", cols = 4, rows = 4:54, type = "list", value = '"Y,N"', showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Question_Analysis", cols = 5, rows = 4:54, type = "list", value = '"Y,N"', allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Question_Analysis", cols = 6, rows = 4:54, type = "list", value = '"Y,N"', showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Question_Analysis", cols = 7, rows = 4:54, type = "list", value = '"Y,N"', showInputMsg = TRUE, showErrorMsg = TRUE)


# ==============================================================================
# SHEET 4: Population_Margins (empty for demo)
# ==============================================================================

addWorksheet(wb, "Population_Margins")
margin_cols <- c("Variable", "Category_Label", "Category_Code", "Target_Prop", "Include")
writeData(wb, "Population_Margins", "TURAS Confidence Module - Population Margins", startRow = 1, startCol = 1)
addStyle(wb, "Population_Margins", title_style, rows = 1, cols = 1)
writeData(wb, "Population_Margins", "Define population proportions for representativeness analysis (optional)", startRow = 2, startCol = 1)
addStyle(wb, "Population_Margins", subtitle_style, rows = 2, cols = 1)
for (j in seq_along(margin_cols)) writeData(wb, "Population_Margins", margin_cols[j], startRow = 3, startCol = j)
addStyle(wb, "Population_Margins", header_style, rows = 3, cols = 1:length(margin_cols), gridExpand = TRUE)
setColWidths(wb, "Population_Margins", cols = 1:5, widths = c(18, 20, 16, 14, 10))

dataValidation(wb, "Population_Margins", cols = 4, rows = 4:34, type = "decimal", operator = "between", value = c(0, 1), showInputMsg = TRUE, showErrorMsg = TRUE)
dataValidation(wb, "Population_Margins", cols = 5, rows = 4:34, type = "list", value = '"Y,N"', allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)

saveWorkbook(wb, config_path, overwrite = TRUE)
cat("Demo config saved to:", config_path, "\n")
