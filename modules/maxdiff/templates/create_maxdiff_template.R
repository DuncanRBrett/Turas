# ==============================================================================
# CREATE MAXDIFF CONFIGURATION TEMPLATE
# ==============================================================================
# Generates a comprehensive Excel template with instructions for all settings
# Run this script to create: maxdiff_config_template.xlsx
# ==============================================================================

library(openxlsx)

# ------------------------------------------------------------------------------
# Shared workbook saver
# ------------------------------------------------------------------------------
# turas_saveWorkbook() reconciles worksheet relationships before saving. Without
# it openxlsx leaves every sheet pointing at a drawing part it never writes, and
# Excel reports a problem with the file and offers to repair it -- a repair that
# strips every data-validation dropdown in the template.
#
# This file is designed to be sourced on its own, so it locates the shared
# helper itself rather than assuming the caller has already loaded it.
if (!exists("turas_saveWorkbook", mode = "function")) {
  .turas_saver_rel <- file.path("modules", "shared", "lib", "turas_save_workbook_atomic.R")
  .turas_saver_dir <- getwd()
  while (!file.exists(file.path(.turas_saver_dir, .turas_saver_rel)) &&
         .turas_saver_dir != dirname(.turas_saver_dir)) {
    .turas_saver_dir <- dirname(.turas_saver_dir)
  }
  .turas_saver_path <- file.path(.turas_saver_dir, .turas_saver_rel)
  if (file.exists(.turas_saver_path)) {
    source(.turas_saver_path)
  } else {
    cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
    cat("│ Code: IO_SAVER_NOT_FOUND\n")
    cat("│ Message: turas_save_workbook_atomic.R was not found, so templates are\n")
    cat("│          written without part reconciliation and Excel may offer to\n")
    cat("│          repair them, losing their dropdowns.\n")
    cat("│ How to fix: run from the Turas project root, or set the working\n")
    cat("│          directory so that modules/shared/lib is reachable\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    turas_saveWorkbook <- function(wb, file, overwrite = TRUE, ...) {
      openxlsx::saveWorkbook(wb, file, overwrite = overwrite, ...)
    }
  }
  rm(.turas_saver_rel, .turas_saver_dir, .turas_saver_path)
}


create_maxdiff_template <- function(output_path = NULL) {

  if (is.null(output_path)) {
    output_path <- file.path(dirname(dirname(getwd())), "templates", "maxdiff_config_template.xlsx")
  }

  # Ensure output directory exists
  dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)

  wb <- createWorkbook()

  # Turas brand palette (matches tabs module and platform identity)
  .TPL_NAVY <- "#323367"
  .TPL_NAVY_LIGHT <- "#e8e8f0"
  .TPL_GOLD <- "#CC9900"
  .TPL_GOLD_LIGHT <- "#fef3c7"
  .TPL_GREEN <- "#ecfdf5"
  .TPL_BLUE <- "#eff6ff"
  .TPL_FONT <- "Calibri"

  # Define styles - aligned with Turas platform brand
  headerStyle <- createStyle(
    fontSize = 12, fontName = .TPL_FONT, fontColour = "#FFFFFF", fgFill = .TPL_NAVY,
    halign = "center", valign = "center", textDecoration = "bold",
    border = "TopBottomLeftRight", borderColour = "#1a1a4e"
  )

  instructionStyle <- createStyle(
    fontSize = 10, fontName = .TPL_FONT, fgFill = .TPL_NAVY_LIGHT, wrapText = TRUE,
    valign = "top", border = "TopBottomLeftRight", borderColour = "#c8c8d8"
  )

  requiredStyle <- createStyle(
    fontSize = 10, fontName = .TPL_FONT, fgFill = .TPL_GOLD_LIGHT, fontColour = "#92400e",
    border = "TopBottomLeftRight", borderColour = "#fcd34d"
  )

  optionalStyle <- createStyle(
    fontSize = 10, fontName = .TPL_FONT, fgFill = .TPL_GREEN, fontColour = "#065f46",
    border = "TopBottomLeftRight", borderColour = "#a7f3d0"
  )

  exampleStyle <- createStyle(
    fontSize = 10, fontName = .TPL_FONT, fgFill = .TPL_BLUE, fontColour = "#1e40af",
    border = "TopBottomLeftRight", borderColour = "#bfdbfe"
  )

  sectionStyle <- createStyle(
    fontSize = 11, fontName = .TPL_FONT, fontColour = "#FFFFFF", fgFill = .TPL_GOLD,
    textDecoration = "bold", border = "TopBottomLeftRight"
  )

  # ============================================================================
  # SHEET 1: INSTRUCTIONS
  # ============================================================================

  addWorksheet(wb, "INSTRUCTIONS", gridLines = FALSE)

  instructions <- data.frame(
    Topic = c(
      "OVERVIEW",
      "",
      "",
      "",
      "",
      "SHEET DESCRIPTIONS",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "WORKFLOW: DESIGN MODE",
      "",
      "",
      "",
      "",
      "WORKFLOW: ANALYSIS MODE",
      "",
      "",
      "",
      "",
      "",
      "",
      "TIPS & BEST PRACTICES",
      "",
      "",
      "",
      "",
      "",
      ""
    ),
    Description = c(
      "MaxDiff (Maximum Difference Scaling) Template Configuration",
      "This template helps you set up MaxDiff studies for both DESIGN generation and ANALYSIS of results.",
      "MaxDiff asks respondents to choose the BEST and WORST items from sets of options, providing robust preference data.",
      "Complete the required sheets based on your mode (DESIGN or ANALYSIS) and run using TURAS>MaxDiff.",
      "",
      "PROJECT_SETTINGS: Core project configuration (name, mode, file paths) - REQUIRED",
      "ITEMS: List of items/attributes to be evaluated - REQUIRED",
      "DESIGN_SETTINGS: Parameters for generating experimental designs - Required for DESIGN mode",
      "SURVEY_MAPPING: Column mappings for survey data - Required for ANALYSIS mode",
      "SEGMENT_SETTINGS: Define segments for subgroup analysis - Optional",
      "OUTPUT_SETTINGS: Control what outputs are generated - Optional (has defaults)",
      "SLIDES: Custom report pages inserted before/after diagnostics - Optional",
      "",
      "1. Set Mode = DESIGN in PROJECT_SETTINGS",
      "2. Define your items in the ITEMS sheet",
      "3. Configure design parameters in DESIGN_SETTINGS",
      "4. Run MaxDiff - generates design file for survey programming",
      "",
      "1. Set Mode = ANALYSIS in PROJECT_SETTINGS",
      "2. Specify paths to Raw_Data_File and Design_File in PROJECT_SETTINGS",
      "3. Define your items in the ITEMS sheet (same as used for design)",
      "4. Map your survey columns in SURVEY_MAPPING",
      "5. Optionally define segments in SEGMENT_SETTINGS",
      "6. Run MaxDiff - generates Excel output with scores and charts",
      "",
      "Typical MaxDiff study: 15-25 items, 4-5 items per task, 10-15 tasks per respondent",
      "More items = more tasks needed for stable estimates",
      "4 items per task is most common; 5 items works well for experienced respondents",
      "Minimum sample size: 200 respondents recommended for stable estimates",
      "Always validate your design before fielding - check balance and efficiency",
      "Use consistent Item_IDs between design and analysis phases",
      ""
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "INSTRUCTIONS", instructions, startRow = 1, startCol = 1)
  addStyle(wb, "INSTRUCTIONS", headerStyle, rows = 1, cols = 1:2, gridExpand = TRUE)
  addStyle(wb, "INSTRUCTIONS", instructionStyle, rows = 2:nrow(instructions) + 1, cols = 1:2, gridExpand = TRUE)
  setColWidths(wb, "INSTRUCTIONS", cols = 1, widths = 30)
  setColWidths(wb, "INSTRUCTIONS", cols = 2, widths = 100)
  freezePane(wb, "INSTRUCTIONS", firstRow = TRUE)

  # ============================================================================
  # SHEET 2: PROJECT_SETTINGS
  # ============================================================================

  addWorksheet(wb, "PROJECT_SETTINGS", gridLines = FALSE)

  project_settings <- data.frame(
    Setting_Name = c(
      "Project_Name",
      "Mode",
      "Raw_Data_File",
      "Design_File",
      "Output_Folder",
      "Data_File_Sheet",
      "Respondent_ID_Variable",
      "Weight_Variable",
      "Filter_Expression",
      "Choice_Value_Type",
      "Seed",
      "Brand_Colour",
      "Accent_Colour",
      "Analyst_Name",
      "Research_House",
      "Module_Version"
    ),
    Value = c(
      "My_MaxDiff_Study",
      "DESIGN",
      "",
      "",
      "output",
      "1",
      "RespID",
      "",
      "",
      "ITEM_ID",
      "12345",
      "#1e3a5f",
      "#2aa198",
      "",
      "",
      "v11.0"
    ),
    Required = c(
      "YES",
      "YES",
      "ANALYSIS only",
      "ANALYSIS only",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO"
    ),
    Description = c(
      "Unique name for your project (no spaces - use underscores)",
      "DESIGN = Generate experimental design | ANALYSIS = Analyze survey results",
      "Path to survey data file (.xlsx, .csv, .sav) - only needed for analysis",
      "Path to design file (.xlsx) created in design mode - needed for analysis",
      "Folder for output files (relative to config location, or absolute path)",
      "Sheet number or name in data file (default: 1 = first sheet)",
      "Column name containing respondent IDs (default: RespID)",
      "Column name for weighting variable (leave blank for unweighted)",
      "R expression to filter data, e.g., Q1 == 1 (leave blank for no filter)",
      "How best/worst cells are coded: ITEM_ID (Item_ID strings) or ITEM_POSITION (1-based position within the task - how Sawtooth/Alchemer usually export)",
      "Random seed for reproducibility (any integer)",
      "Primary brand colour for HTML report and simulator (hex format)",
      "Secondary accent colour for HTML report (hex format)",
      "Analyst name - appears in the stats pack Declaration sheet",
      "Research organisation name - appears in the stats pack Declaration sheet",
      "Module version (for tracking)"
    ),
    Options_Examples = c(
      "Brand_Preference_Study, Product_Features_Q1_2024",
      "DESIGN or ANALYSIS",
      "data/survey_results.xlsx, C:/Data/maxdiff_responses.csv",
      "output/maxdiff_design.xlsx, designs/study1_design.xlsx",
      "output, results, C:/Output/MaxDiff",
      "1, 2, Sheet1, Data",
      "RespID, ResponseID, ID, Respondent_ID",
      "Weight, wgt, sample_weight (leave blank if unweighted)",
      "Region == 'North', Age >= 18 & Age <= 65, Complete == 1",
      "ITEM_ID or ITEM_POSITION",
      "12345, 42, 98765",
      "#1e3a5f, #2c3e50, #003366",
      "#2aa198, #e67e22, #27ae60",
      "Jane Smith",
      "The Research LampPost, Acme Research Partners",
      "v11.0"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "PROJECT_SETTINGS", project_settings, startRow = 1, startCol = 1)
  addStyle(wb, "PROJECT_SETTINGS", headerStyle, rows = 1, cols = 1:5, gridExpand = TRUE)

  # Color code required vs optional
  for (i in 2:(nrow(project_settings) + 1)) {
    if (project_settings$Required[i-1] == "YES") {
      addStyle(wb, "PROJECT_SETTINGS", requiredStyle, rows = i, cols = 1:5, gridExpand = TRUE)
    } else {
      addStyle(wb, "PROJECT_SETTINGS", optionalStyle, rows = i, cols = 1:5, gridExpand = TRUE)
    }
  }

  setColWidths(wb, "PROJECT_SETTINGS", cols = 1, widths = 25)
  setColWidths(wb, "PROJECT_SETTINGS", cols = 2, widths = 30)
  setColWidths(wb, "PROJECT_SETTINGS", cols = 3, widths = 15)
  setColWidths(wb, "PROJECT_SETTINGS", cols = 4, widths = 60)
  setColWidths(wb, "PROJECT_SETTINGS", cols = 5, widths = 50)
  freezePane(wb, "PROJECT_SETTINGS", firstRow = TRUE)

  # Add data validation for Mode
  dataValidation(wb, "PROJECT_SETTINGS", col = 2, rows = 3,
                 type = "list", value = "'DESIGN,ANALYSIS'")

  # ============================================================================
  # SHEET 3: ITEMS
  # ============================================================================

  addWorksheet(wb, "ITEMS", gridLines = FALSE)

  items <- data.frame(
    Item_ID = c("ITEM_01", "ITEM_02", "ITEM_03", "ITEM_04", "ITEM_05",
                "ITEM_06", "ITEM_07", "ITEM_08", "ITEM_09", "ITEM_10"),
    Item_Label = c(
      "High quality materials",
      "Affordable price",
      "Fast delivery",
      "Excellent customer service",
      "Wide product selection",
      "Easy returns policy",
      "Loyalty rewards program",
      "Sustainable/eco-friendly",
      "Local/domestic brand",
      "Innovative features"
    ),
    Item_Group = c("Quality", "Price", "Service", "Service", "Selection",
                   "Service", "Loyalty", "Values", "Values", "Quality"),
    Include = c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
    Anchor_Item = c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    Display_Order = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10),
    Notes = c("", "", "", "", "", "", "", "", "", ""),
    stringsAsFactors = FALSE
  )

  # Add header row with column descriptions
  items_header <- data.frame(
    Item_ID = "Item_ID",
    Item_Label = "Item_Label",
    Item_Group = "Item_Group",
    Include = "Include",
    Anchor_Item = "Anchor_Item",
    Display_Order = "Display_Order",
    Notes = "Notes",
    stringsAsFactors = FALSE
  )

  writeData(wb, "ITEMS", items, startRow = 1, startCol = 1)
  addStyle(wb, "ITEMS", headerStyle, rows = 1, cols = 1:7, gridExpand = TRUE)
  addStyle(wb, "ITEMS", exampleStyle, rows = 2:11, cols = 1:7, gridExpand = TRUE)

  setColWidths(wb, "ITEMS", cols = 1, widths = 15)
  setColWidths(wb, "ITEMS", cols = 2, widths = 40)
  setColWidths(wb, "ITEMS", cols = 3, widths = 15)
  setColWidths(wb, "ITEMS", cols = 4, widths = 10)
  setColWidths(wb, "ITEMS", cols = 5, widths = 12)
  setColWidths(wb, "ITEMS", cols = 6, widths = 14)
  setColWidths(wb, "ITEMS", cols = 7, widths = 30)
  freezePane(wb, "ITEMS", firstRow = TRUE)

  # Add column descriptions below data
  item_instructions <- data.frame(
    Column = c("Item_ID", "Item_Label", "Item_Group", "Include", "Anchor_Item", "Display_Order", "Notes"),
    Required = c("YES", "YES", "NO", "NO", "NO", "NO", "NO"),
    Description = c(
      "Unique identifier for the item (used in design and analysis - keep consistent!)",
      "Text shown to respondents - the actual item/attribute text",
      "Optional grouping for reporting (e.g., by category or theme)",
      "1 = Include in study, 0 = Exclude (useful for testing subsets)",
      "1 = Use as anchor/reference item for scaling, 0 = Normal item (max 1 anchor)",
      "Order for display in output tables (1 = first)",
      "Any notes or comments about the item"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "ITEMS", item_instructions, startRow = 14, startCol = 1)
  addStyle(wb, "ITEMS", sectionStyle, rows = 14, cols = 1:3, gridExpand = TRUE)
  addStyle(wb, "ITEMS", instructionStyle, rows = 15:21, cols = 1:3, gridExpand = TRUE)

  # ============================================================================
  # SHEET 4: DESIGN_SETTINGS
  # ============================================================================

  addWorksheet(wb, "DESIGN_SETTINGS", gridLines = FALSE)

  design_settings <- data.frame(
    Parameter_Name = c(
      "Items_Per_Task",
      "Tasks_Per_Respondent",
      "Num_Versions",
      "Design_Type",
      "Allow_Item_Repeat_Per_Respondent",
      "Max_Item_Repeats",
      "Force_Min_Pair_Balance",
      "Randomise_Task_Order",
      "Randomise_Item_Order_Within_Task",
      "Design_Efficiency_Threshold",
      "Max_Design_Iterations"
    ),
    Value = c(
      "4",
      "12",
      "1",
      "BALANCED",
      "YES",
      "3",
      "YES",
      "YES",
      "YES",
      "0.90",
      "10000"
    ),
    Required = c(
      "YES",
      "YES",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO",
      "NO"
    ),
    Description = c(
      "Number of items shown in each task (typically 4 or 5)",
      "Number of MaxDiff tasks each respondent completes",
      "Number of design versions (for blocking/rotation)",
      "Design generation algorithm: BALANCED, RANDOM, or OPTIMAL",
      "Can an item appear multiple times for same respondent?",
      "Maximum times an item can appear per respondent",
      "Ensure all item pairs appear with similar frequency?",
      "Randomize task order for each respondent?",
      "Randomize item positions within each task?",
      "Minimum D-efficiency threshold (0-1, higher = better)",
      "Maximum iterations for design optimization"
    ),
    Options = c(
      "3, 4, 5 (4 is most common)",
      "8-20 typical (more = better precision but longer survey)",
      "1-10 (use multiple versions for large samples)",
      "BALANCED = equal frequency | RANDOM = simple random | OPTIMAL = D-optimal",
      "YES or NO",
      "1-10 (lower = more variety, higher = more efficient)",
      "YES or NO (YES recommended for better estimates)",
      "YES or NO (YES recommended to reduce order bias)",
      "YES or NO (YES recommended to reduce position bias)",
      "0.80-0.99 (0.90+ is good, 0.95+ is excellent)",
      "1000-100000 (more = better design but slower)"
    ),
    Recommendation = c(
      "4 for general use, 5 for experienced respondents",
      "12-15 for 15-20 items, adjust based on item count",
      "1 for small studies, 3-5 for large studies",
      "BALANCED for most cases",
      "YES unless very short survey",
      "3 for typical studies",
      "YES",
      "YES",
      "YES",
      "0.90",
      "10000"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "DESIGN_SETTINGS", design_settings, startRow = 1, startCol = 1)
  addStyle(wb, "DESIGN_SETTINGS", headerStyle, rows = 1, cols = 1:6, gridExpand = TRUE)

  for (i in 2:12) {
    if (design_settings$Required[i-1] == "YES") {
      addStyle(wb, "DESIGN_SETTINGS", requiredStyle, rows = i, cols = 1:6, gridExpand = TRUE)
    } else {
      addStyle(wb, "DESIGN_SETTINGS", optionalStyle, rows = i, cols = 1:6, gridExpand = TRUE)
    }
  }

  setColWidths(wb, "DESIGN_SETTINGS", cols = 1, widths = 35)
  setColWidths(wb, "DESIGN_SETTINGS", cols = 2, widths = 12)
  setColWidths(wb, "DESIGN_SETTINGS", cols = 3, widths = 10)
  setColWidths(wb, "DESIGN_SETTINGS", cols = 4, widths = 50)
  setColWidths(wb, "DESIGN_SETTINGS", cols = 5, widths = 45)
  setColWidths(wb, "DESIGN_SETTINGS", cols = 6, widths = 40)
  freezePane(wb, "DESIGN_SETTINGS", firstRow = TRUE)

  # Add data validations for DESIGN_SETTINGS
  dataValidation(wb, "DESIGN_SETTINGS", col = 2, rows = 5,
                 type = "list", value = "'BALANCED,OPTIMAL,RANDOM'")
  dataValidation(wb, "DESIGN_SETTINGS", col = 2, rows = 6,
                 type = "list", value = "'YES,NO'")
  dataValidation(wb, "DESIGN_SETTINGS", col = 2, rows = 8,
                 type = "list", value = "'YES,NO'")
  dataValidation(wb, "DESIGN_SETTINGS", col = 2, rows = 9,
                 type = "list", value = "'YES,NO'")
  dataValidation(wb, "DESIGN_SETTINGS", col = 2, rows = 10,
                 type = "list", value = "'YES,NO'")

  # ============================================================================
  # SHEET 5: SURVEY_MAPPING
  # ============================================================================

  addWorksheet(wb, "SURVEY_MAPPING", gridLines = FALSE)

  # One row per data column the loader reads (01_config.R: Field_Type /
  # Field_Name / Task_Number). The old template used a pattern schema
  # (Mapping_Type / Best_Column_Pattern) the loader has never supported, so
  # the shipped template could not complete an ANALYSIS run (H6).
  n_example_tasks <- 6
  survey_mapping <- data.frame(
    Field_Type = c("VERSION",
                   rep(c("BEST_CHOICE", "WORST_CHOICE"), n_example_tasks)),
    Field_Name = c("Version",
                   as.vector(rbind(sprintf("MaxDiff_T%d_Best", 1:n_example_tasks),
                                   sprintf("MaxDiff_T%d_Worst", 1:n_example_tasks)))),
    Task_Number = c(NA, rep(1:n_example_tasks, each = 2)),
    Description = c(
      "Column holding the design version number (1, 2, 3...)",
      as.vector(rbind(sprintf("Best choice for task %d", 1:n_example_tasks),
                      sprintf("Worst choice for task %d", 1:n_example_tasks)))
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "SURVEY_MAPPING", survey_mapping, startRow = 1, startCol = 1)
  addStyle(wb, "SURVEY_MAPPING", headerStyle, rows = 1, cols = 1:4, gridExpand = TRUE)
  addStyle(wb, "SURVEY_MAPPING", exampleStyle,
           rows = 2:(nrow(survey_mapping) + 1), cols = 1:4, gridExpand = TRUE)

  survey_mapping_notes <- data.frame(
    Note = c(
      "One row per data column. Field_Type is VERSION, BEST_CHOICE or WORST_CHOICE.",
      "Field_Name must match the column name in your data file exactly.",
      "Task_Number links each best/worst pair to a DESIGN task; a T1/T2 infix in the name is auto-detected when the column is blank.",
      "Adjust the example rows to your own task count and column names.",
      "Whether the cells carry Item_IDs or task positions is set in PROJECT_SETTINGS (Choice_Value_Type)."
    ),
    stringsAsFactors = FALSE
  )
  # Side column, NOT below the table: anything in the schema columns reads
  # back as a mapping row and the loader (rightly) refuses it.
  writeData(wb, "SURVEY_MAPPING", survey_mapping_notes,
            startRow = 2, startCol = 6)
  addStyle(wb, "SURVEY_MAPPING", instructionStyle,
           rows = 3:7, cols = 6, gridExpand = TRUE)
  setColWidths(wb, "SURVEY_MAPPING", cols = 6, widths = 110)

  setColWidths(wb, "SURVEY_MAPPING", cols = 1, widths = 16)
  setColWidths(wb, "SURVEY_MAPPING", cols = 2, widths = 24)
  setColWidths(wb, "SURVEY_MAPPING", cols = 3, widths = 13)
  setColWidths(wb, "SURVEY_MAPPING", cols = 4, widths = 90)
  freezePane(wb, "SURVEY_MAPPING", firstRow = TRUE)

  # ============================================================================
  # SHEET 6: SEGMENT_SETTINGS
  # ============================================================================

  addWorksheet(wb, "SEGMENT_SETTINGS", gridLines = FALSE)

  # One row per segment GROUP (the loader refuses duplicate Segment_IDs and
  # wants Segment_ID / Segment_Label / Variable_Name, 01_config.R). The old
  # template's one-row-per-LEVEL schema with repeated IDs refused on load (H6).
  segment_settings <- data.frame(
    Segment_ID = c("Gender", "Age_Group", "Region"),
    Segment_Label = c("Gender", "Age group", "Region"),
    Variable_Name = c("Gender", "Age_Group", "Region"),
    Segment_Def = c("", "", ""),
    Include_in_Output = c(1, 1, 1),
    stringsAsFactors = FALSE
  )

  writeData(wb, "SEGMENT_SETTINGS", segment_settings, startRow = 1, startCol = 1)
  addStyle(wb, "SEGMENT_SETTINGS", headerStyle, rows = 1, cols = 1:5, gridExpand = TRUE)
  addStyle(wb, "SEGMENT_SETTINGS", exampleStyle, rows = 2:4, cols = 1:5, gridExpand = TRUE)

  setColWidths(wb, "SEGMENT_SETTINGS", cols = 1:5, widths = c(15, 20, 18, 30, 16))
  freezePane(wb, "SEGMENT_SETTINGS", firstRow = TRUE)

  segment_instructions <- data.frame(
    Column = c("Segment_ID", "Segment_Label", "Variable_Name",
               "Segment_Def", "Include_in_Output"),
    Required = c("YES", "YES", "YES", "NO", "NO"),
    Description = c(
      "Unique identifier for the segment group (one ROW per group, not per level)",
      "Display name in the output tables",
      "Column in your data file whose LEVELS become the segments",
      "Optional R expression to derive the grouping (e.g. Age >= 35); blank = use the variable's own values",
      "1 = include in output (default), 0 = skip"
    ),
    stringsAsFactors = FALSE
  )

  # Side columns for the same reason as SURVEY_MAPPING: below-the-table
  # rows read back as segment definitions.
  writeData(wb, "SEGMENT_SETTINGS", segment_instructions, startRow = 2, startCol = 7)
  addStyle(wb, "SEGMENT_SETTINGS", sectionStyle, rows = 2, cols = 7:9, gridExpand = TRUE)
  addStyle(wb, "SEGMENT_SETTINGS", instructionStyle, rows = 3:7, cols = 7:9, gridExpand = TRUE)
  setColWidths(wb, "SEGMENT_SETTINGS", cols = 7:9, widths = c(22, 10, 80))

  # ============================================================================
  # SHEET 7: OUTPUT_SETTINGS
  # ============================================================================

  addWorksheet(wb, "OUTPUT_SETTINGS", gridLines = FALSE)

  output_settings <- data.frame(
    Setting_Name = c(
      # --- Output Formats ---
      "--- OUTPUT FORMATS ---",
      "Generate_Design_File",
      "Generate_Count_Scores",
      "Generate_Aggregate_Logit",
      "Generate_HB_Model",
      "Generate_Segment_Tables",
      "Generate_Charts",
      "Generate_HTML_Report",
      "Generate_Simulator",
      "Generate_Stats_Pack",
      # --- TURF Analysis ---
      "--- TURF ANALYSIS ---",
      "Generate_TURF",
      "TURF_Max_Items",
      "TURF_Threshold",
      # --- Anchored MaxDiff ---
      "--- ANCHORED MAXDIFF ---",
      "Has_Anchor_Question",
      "Anchor_Variable",
      "Anchor_Threshold",
      "Anchor_Format",
      # --- Display & Formatting ---
      "--- DISPLAY & FORMATTING ---",
      "Score_Display",
      "Score_Rescale_Method",
      "Export_Individual_Utils",
      "Min_Respondents_Per_Segment",
      "Output_Item_Sort_Order"
    ),
    Value = c(
      "",
      "YES",
      "YES",
      "YES",
      "NO",
      "YES",
      "YES",
      "YES",
      "YES",
      "YES",
      "",
      "YES",
      "10",
      "ABOVE_MEAN",
      "",
      "NO",
      "",
      "0.50",
      "COMMA_SEPARATED",
      "",
      "BOTH",
      "0_100",
      "YES",
      "50",
      "UTILITY_DESC"
    ),
    Description = c(
      "",
      "Generate design file with task assignments (DESIGN mode)",
      "Calculate count-based scores (Best%, Worst%, Net Score)",
      "Fit aggregate multinomial logit model for utilities",
      "Fit Hierarchical Bayes model for individual-level utilities (requires cmdstanr)",
      "Generate separate score tables for each segment",
      "Generate PNG/PDF visualization charts",
      "Generate interactive HTML report with SVG charts and tabbed layout",
      "Generate interactive HTML simulator (head-to-head, portfolio builder)",
      "Generate a diagnostic stats pack workbook alongside main output. The stats pack provides a full audit trail of data received, methods used, assumptions, and reproducibility — designed for advanced partners and research statisticians. Output file is named {output}_stats_pack.xlsx.",
      "",
      "Run TURF (Total Unduplicated Reach & Frequency) portfolio optimization",
      "Maximum portfolio size for TURF analysis",
      "Method for classifying items as appealing in TURF",
      "",
      "Whether the survey includes an anchor/must-have question",
      "Column name containing anchor responses (leave blank if Has_Anchor_Question = NO)",
      "Proportion threshold for classifying items as must-have (0.0-1.0)",
      "Format of anchor variable data",
      "",
      "How to display preference scores in reports",
      "Scale for utility scores (the setting the engine reads - the old template's Utility_Scale row was silently ignored)",
      "Write the per-respondent utilities sheet (needed for TURF and the tabs export)",
      "Minimum respondents for a segment to be reported",
      "Row order for item tables"
    ),
    Options = c(
      "",
      "YES or NO",
      "YES or NO",
      "YES or NO",
      "YES or NO (requires additional setup)",
      "YES or NO",
      "YES or NO",
      "YES or NO (produces self-contained .html file)",
      "YES or NO (requires HB or logit results)",
      "YES or NO",
      "",
      "YES or NO (requires individual-level utilities from HB)",
      "1 to n_items (default: min(10, n_items))",
      "ABOVE_MEAN | TOP_3 | TOP_K | ABOVE_ZERO",
      "",
      "YES or NO",
      "Column name from data file",
      "0.0-1.0 (items with anchor rate above this = must-have)",
      "COMMA_SEPARATED | BINARY",
      "",
      "UTILITY | PREFERENCE_SHARE | BOTH",
      "RAW = logit scale | 0_100 = rescaled 0-100 | PROBABILITY = share of preference",
      "YES or NO",
      "Positive integer (default 50)",
      "UTILITY_DESC | UTILITY_ASC | ITEM_ID | DISPLAY_ORDER"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "OUTPUT_SETTINGS", output_settings, startRow = 1, startCol = 1)
  addStyle(wb, "OUTPUT_SETTINGS", headerStyle, rows = 1, cols = 1:4, gridExpand = TRUE)

  # Style rows: section headers get sectionStyle, data rows get optionalStyle
  section_rows <- which(grepl("^---", output_settings$Setting_Name)) + 1
  data_rows <- setdiff(2:(nrow(output_settings) + 1), section_rows)
  for (r in section_rows) {
    addStyle(wb, "OUTPUT_SETTINGS", sectionStyle, rows = r, cols = 1:4, gridExpand = TRUE)
  }
  for (r in data_rows) {
    addStyle(wb, "OUTPUT_SETTINGS", optionalStyle, rows = r, cols = 1:4, gridExpand = TRUE)
  }

  setColWidths(wb, "OUTPUT_SETTINGS", cols = 1, widths = 28)
  setColWidths(wb, "OUTPUT_SETTINGS", cols = 2, widths = 20)
  setColWidths(wb, "OUTPUT_SETTINGS", cols = 3, widths = 60)
  setColWidths(wb, "OUTPUT_SETTINGS", cols = 4, widths = 50)
  freezePane(wb, "OUTPUT_SETTINGS", firstRow = TRUE)

  # Data validations for OUTPUT_SETTINGS
  # YES/NO dropdowns for boolean fields
  yn_setting_names <- c("Generate_Design_File", "Generate_Count_Scores",
                        "Generate_Aggregate_Logit", "Generate_HB_Model",
                        "Generate_Segment_Tables", "Generate_Charts",
                        "Generate_HTML_Report", "Generate_Simulator",
                        "Generate_Stats_Pack",
                        "Generate_TURF", "Has_Anchor_Question",
                        "Export_Individual_Utils")
  for (sname in yn_setting_names) {
    row_idx <- which(output_settings$Setting_Name == sname) + 1
    if (length(row_idx) == 1) {
      dataValidation(wb, "OUTPUT_SETTINGS", col = 2, rows = row_idx,
                     type = "list", value = "'YES,NO'")
    }
  }

  # TURF_Threshold dropdown
  turf_thresh_row <- which(output_settings$Setting_Name == "TURF_Threshold") + 1
  if (length(turf_thresh_row) == 1) {
    dataValidation(wb, "OUTPUT_SETTINGS", col = 2, rows = turf_thresh_row,
                   type = "list", value = "'ABOVE_MEAN,TOP_3,TOP_K,ABOVE_ZERO'")
  }

  # Anchor_Format dropdown
  anchor_fmt_row <- which(output_settings$Setting_Name == "Anchor_Format") + 1
  if (length(anchor_fmt_row) == 1) {
    dataValidation(wb, "OUTPUT_SETTINGS", col = 2, rows = anchor_fmt_row,
                   type = "list", value = "'COMMA_SEPARATED,BINARY'")
  }

  # ============================================================================
  # SHEET 9: SLIDES
  # ============================================================================

  addWorksheet(wb, "SLIDES", gridLines = FALSE)

  slides <- data.frame(
    Title = c("About This Study"),
    Content = c("<p>This MaxDiff study was conducted to understand customer preferences across key product attributes.</p><p>Results are based on a sample of N=500 respondents.</p>"),
    Position = c("BEFORE_DIAGNOSTICS"),
    Image_Path = c(""),
    stringsAsFactors = FALSE
  )

  writeData(wb, "SLIDES", slides, startRow = 1, startCol = 1)
  addStyle(wb, "SLIDES", headerStyle, rows = 1, cols = 1:4, gridExpand = TRUE)
  addStyle(wb, "SLIDES", exampleStyle, rows = 2, cols = 1:4, gridExpand = TRUE)

  setColWidths(wb, "SLIDES", cols = 1, widths = 30)
  setColWidths(wb, "SLIDES", cols = 2, widths = 80)
  setColWidths(wb, "SLIDES", cols = 3, widths = 25)
  setColWidths(wb, "SLIDES", cols = 4, widths = 40)
  freezePane(wb, "SLIDES", firstRow = TRUE)

  # Add column descriptions below data
  slides_instructions <- data.frame(
    Column = c("Title", "Content", "Position", "Image_Path"),
    Required = c("YES", "YES", "YES", "NO"),
    Description = c(
      "Slide title displayed as a heading in the report",
      "HTML content for the slide body (supports <p>, <ul>, <li>, <b>, <em> tags)",
      "Where to insert the slide in the report",
      "Optional file path to an image displayed on the slide (PNG/JPG)"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "SLIDES", slides_instructions, startRow = 5, startCol = 1)
  addStyle(wb, "SLIDES", sectionStyle, rows = 5, cols = 1:3, gridExpand = TRUE)
  addStyle(wb, "SLIDES", instructionStyle, rows = 6:9, cols = 1:3, gridExpand = TRUE)

  # Data validation for Position
  dataValidation(wb, "SLIDES", col = 3, rows = 2:20,
                 type = "list", value = "'BEFORE_DIAGNOSTICS,AFTER_DIAGNOSTICS'")

  # ============================================================================

  turas_saveWorkbook(wb, output_path, overwrite = TRUE)

  cat("\n")
  cat("================================================================================\n")
  cat("MaxDiff Configuration Template Created\n")
  cat("================================================================================\n")
  cat(sprintf("File: %s\n", output_path))
  cat("\n")
  cat("Sheets included:\n")
  cat("  1. INSTRUCTIONS        - How to use this template\n")
  cat("  2. PROJECT_SETTINGS    - Core project configuration\n")
  cat("  3. ITEMS               - Item/attribute definitions\n")
  cat("  4. DESIGN_SETTINGS     - Design generation parameters\n")
  cat("  5. SURVEY_MAPPING      - Survey column mappings\n")
  cat("  6. SEGMENT_SETTINGS    - Segment definitions\n")
  cat("  7. OUTPUT_SETTINGS     - Output options (TURF, Anchor, Display, Stats Pack)\n")
  cat("  8. SLIDES              - Custom report pages\n")
  cat("\n")
  cat("Color coding:\n")
  cat("  Yellow  = Required setting\n")
  cat("  Green   = Optional setting (has default)\n")
  cat("  Blue    = Example data (replace with your own)\n")
  cat("  Purple  = Section header\n")
  cat("================================================================================\n")

  invisible(output_path)
}

# Run if executed directly
if (!exists("TURAS_LAUNCHER_ACTIVE") || !TURAS_LAUNCHER_ACTIVE) {
  # Create in templates folder
  template_dir <- file.path(getwd(), "templates")
  if (!dir.exists(template_dir)) {
    dir.create(template_dir, recursive = TRUE)
  }
  create_maxdiff_template(file.path(template_dir, "maxdiff_config_template.xlsx"))
}
