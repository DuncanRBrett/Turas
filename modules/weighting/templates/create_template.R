# ==============================================================================
# CREATE WEIGHT_CONFIG_TEMPLATE.XLSX
# ==============================================================================
# Run this script to generate the Weight_Config_Template.xlsx file
# Part of TURAS Weighting Module v3.0
# ==============================================================================

library(openxlsx)

create_weight_config_template <- function(output_path = NULL) {

  if (is.null(output_path)) {
    output_path <- file.path(dirname(sys.frame(1)$ofile), "Weight_Config_Template.xlsx")
  }

  wb <- createWorkbook()

  # Add header style
  headerStyle <- createStyle(
    fontColour = "#FFFFFF",
    fgFill = "#4472C4",
    halign = "center",
    textDecoration = "bold"
  )

  # ============================================================================
  # Sheet 1: General
  # ============================================================================
  addWorksheet(wb, "General")

  general_data <- data.frame(
    Setting = c(
      "project_name",
      "data_file",
      "output_file",
      "save_diagnostics",
      "diagnostics_file",
      "html_report",
      "html_report_file",
      "brand_colour",
      "accent_colour",
      "researcher_name",
      "client_name",
      "logo_file"
    ),
    Value = c(
      "My_Project",
      "data/survey_responses.csv",
      "data/survey_weighted.csv",
      "Y",
      "output/weight_diagnostics.xlsx",
      "Y",
      "output/weighting_report.html",
      "#1e3a5f",
      "#2aa198",
      "",
      "",
      ""
    ),
    Description = c(
      "Project identifier for reporting",
      "Path to survey data file (relative to config or absolute)",
      "Path for weighted data output (optional)",
      "Save Excel diagnostics report? (Y/N)",
      "Path for diagnostics workbook (required if save_diagnostics=Y)",
      "Generate self-contained HTML report? (Y/N)",
      "Path for HTML report (auto-generated if blank)",
      "Brand hex colour for HTML report (optional)",
      "Accent hex colour for HTML report (optional)",
      "Researcher/analyst name shown in report header (optional)",
      "Client name shown in report header (optional)",
      "Path to logo image for report header (PNG/JPG/SVG, optional)"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "General", general_data)
  setColWidths(wb, "General", cols = 1:3, widths = c(20, 35, 50))
  addStyle(wb, "General", headerStyle, rows = 1, cols = 1:3, gridExpand = TRUE)

  # ============================================================================
  # Sheet 2: Weight_Specifications
  # ============================================================================
  addWorksheet(wb, "Weight_Specifications")

  weight_specs <- data.frame(
    weight_name = c("design_weight", "population_weight", "cell_weight"),
    method = c("design", "rim", "cell"),
    description = c(
      "Design weights by customer segment",
      "Rim weights to match population demographics",
      "Cell weights for interlocked Age x Gender"
    ),
    apply_trimming = c("N", "Y", "N"),
    trim_method = c(NA, "cap", NA),
    trim_value = c(NA, 5, NA),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Weight_Specifications", weight_specs)
  setColWidths(wb, "Weight_Specifications", cols = 1:6, widths = c(20, 10, 40, 15, 15, 12))
  addStyle(wb, "Weight_Specifications", headerStyle, rows = 1, cols = 1:6, gridExpand = TRUE)

  # ============================================================================
  # Sheet 3: Design_Targets
  # ============================================================================
  addWorksheet(wb, "Design_Targets")

  design_targets <- data.frame(
    weight_name = c("design_weight", "design_weight", "design_weight"),
    stratum_variable = c("segment", "segment", "segment"),
    stratum_category = c("Small", "Medium", "Large"),
    population_size = c(5000, 3500, 1500),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Design_Targets", design_targets)
  setColWidths(wb, "Design_Targets", cols = 1:4, widths = c(20, 20, 20, 15))
  addStyle(wb, "Design_Targets", headerStyle, rows = 1, cols = 1:4, gridExpand = TRUE)

  # ============================================================================
  # Sheet 4: Rim_Targets
  # ============================================================================
  addWorksheet(wb, "Rim_Targets")

  rim_targets <- data.frame(
    weight_name = rep("population_weight", 9),
    variable = c(
      "Age", "Age", "Age",
      "Gender", "Gender",
      "Region", "Region", "Region", "Region"
    ),
    category = c(
      "18-34", "35-54", "55+",
      "Male", "Female",
      "North", "South", "East", "West"
    ),
    target_percent = c(
      30, 40, 30,
      48, 52,
      25, 35, 20, 20
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Rim_Targets", rim_targets)
  setColWidths(wb, "Rim_Targets", cols = 1:4, widths = c(20, 15, 15, 15))
  addStyle(wb, "Rim_Targets", headerStyle, rows = 1, cols = 1:4, gridExpand = TRUE)

  # ============================================================================
  # Sheet 5: Cell_Targets
  # ============================================================================
  addWorksheet(wb, "Cell_Targets")

  cell_targets <- data.frame(
    weight_name = rep("cell_weight", 6),
    Gender = rep(c("Male", "Female"), each = 3),
    Age = rep(c("18-34", "35-54", "55+"), 2),
    target_percent = c(14.5, 19.4, 14.6, 15.5, 20.6, 15.4),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Cell_Targets", cell_targets)
  setColWidths(wb, "Cell_Targets", cols = 1:4, widths = c(20, 15, 15, 15))
  addStyle(wb, "Cell_Targets", headerStyle, rows = 1, cols = 1:4, gridExpand = TRUE)

  # ============================================================================
  # Sheet 6: Advanced_Settings
  # ============================================================================
  addWorksheet(wb, "Advanced_Settings")

  advanced <- data.frame(
    weight_name = c("population_weight"),
    max_iterations = c(50),
    convergence_tolerance = c(0.001),
    force_convergence = c("N"),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Advanced_Settings", advanced)
  setColWidths(wb, "Advanced_Settings", cols = 1:4, widths = c(20, 15, 22, 18))
  addStyle(wb, "Advanced_Settings", headerStyle, rows = 1, cols = 1:4, gridExpand = TRUE)

  # ============================================================================
  # Sheet 7: Notes
  # ============================================================================
  addWorksheet(wb, "Notes")

  notes <- data.frame(
    Section = c("Assumptions", "Assumptions", "Methodology", "Data Quality", "Caveats"),
    Note = c(
      "Population data sourced from Census 2021",
      "Age categories collapsed from 5-year bands",
      "Rim weighting chosen over cell due to sparse cells",
      "3 records excluded due to missing age data",
      "Rural areas may be under-represented"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Notes", notes)
  setColWidths(wb, "Notes", cols = 1:2, widths = c(20, 60))
  addStyle(wb, "Notes", headerStyle, rows = 1, cols = 1:2, gridExpand = TRUE)

  # ============================================================================
  # Sheet 8: Instructions
  # ============================================================================
  addWorksheet(wb, "Instructions")

  instructions <- c(
    "TURAS WEIGHTING MODULE - CONFIGURATION TEMPLATE v3.0",
    "",
    "This template helps you configure survey weighting calculations.",
    "",
    "SHEETS:",
    "",
    "1. General - Overall configuration settings",
    "   - project_name: Identifier for your project",
    "   - data_file: Path to your survey data (CSV, Excel, or SPSS)",
    "   - output_file: Where to save weighted data (optional)",
    "   - save_diagnostics: Y/N to save Excel diagnostics report",
    "   - diagnostics_file: Path for diagnostics (if save_diagnostics=Y)",
    "   - html_report: Y/N to generate self-contained HTML report",
    "   - html_report_file: Path for HTML report (auto-generated if blank)",
    "   - brand_colour: Hex colour for report branding (optional)",
    "   - accent_colour: Hex accent colour for report (optional)",
    "   - researcher_name: Researcher/analyst name for report header (optional)",
    "   - client_name: Client name for report header (optional)",
    "   - logo_file: Path to logo image for report header (optional)",
    "",
    "2. Weight_Specifications - Define each weight to calculate",
    "   - weight_name: Unique name for the weight column",
    "   - method: 'design', 'rim' (or 'rake'), or 'cell'",
    "   - description: Optional description",
    "   - apply_trimming: Y/N to cap extreme weights",
    "   - trim_method: 'cap' (hard max) or 'percentile' (e.g., 95th percentile)",
    "   - trim_value: Max weight (if cap) or upper percentile (if percentile)",
    "",
    "3. Design_Targets - For design weights only",
    "   - weight_name: Links to Weight_Specifications",
    "   - stratum_variable: Column in your data for stratification",
    "   - stratum_category: Value in the stratum column",
    "   - population_size: Number in population for this stratum",
    "",
    "4. Rim_Targets - For rim weights only",
    "   - weight_name: Links to Weight_Specifications",
    "   - variable: Column in your data to weight on",
    "   - category: Value in the variable column",
    "   - target_percent: Target percentage (must sum to 100 per variable)",
    "",
    "5. Cell_Targets - For cell/interlocked weights only",
    "   - weight_name: Links to Weight_Specifications",
    "   - One column per cell variable (e.g., Gender, Age)",
    "   - target_percent: Joint distribution target (all rows must sum to 100)",
    "",
    "6. Advanced_Settings (Optional) - Rim weighting parameters",
    "   - max_iterations: Maximum iterations for convergence (default: 50)",
    "   - convergence_tolerance: Precision threshold (default: 0.001)",
    "   - force_convergence: Y/N to accept non-converged weights",
    "",
    "7. Notes (Optional) - Document assumptions and methodology",
    "   - Section: Category (e.g., Assumptions, Methodology, Data Quality, Caveats)",
    "   - Note: Description text",
    "   - Notes appear in HTML report and Excel diagnostics",
    "",
    "USAGE:",
    "",
    "1. Copy this template and rename for your project",
    "2. Update the General settings",
    "3. Define your weights in Weight_Specifications",
    "4. Add targets to Design_Targets, Rim_Targets, and/or Cell_Targets as needed",
    "5. Run: result <- run_weighting('your_config.xlsx')",
    "",
    "TIPS:",
    "",
    "- Rim targets for each variable must sum to 100%",
    "- Cell targets must sum to 100% across all rows",
    "- Design weights: Ensure all stratum categories exist in your data",
    "- For rim weighting, max 5 variables recommended",
    "- For cell weighting, ensure every cell combination has at least 1 respondent",
    "- Start with apply_trimming=N, then add if design effect > 2.0",
    "- All paths are relative to the config file location",
    "",
    "For more information, see the module README.md."
  )

  writeData(wb, "Instructions", data.frame(Instructions = instructions))
  setColWidths(wb, "Instructions", cols = 1, widths = 80)

  # Save workbook
  saveWorkbook(wb, output_path, overwrite = TRUE)

  message("Template created: ", output_path)
  return(invisible(output_path))
}

# Run if executed directly
if (!interactive()) {
  create_weight_config_template()
}
