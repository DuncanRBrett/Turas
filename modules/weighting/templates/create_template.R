# ==============================================================================
# CREATE WEIGHT_CONFIG_TEMPLATE.XLSX
# ==============================================================================
# Run this script to generate the Weight_Config_Template.xlsx file
# ==============================================================================

library(openxlsx)

create_weight_config_template <- function(output_path = NULL) {

  if (is.null(output_path)) {
    output_path <- file.path(dirname(sys.frame(1)$ofile), "Weight_Config_Template.xlsx")
  }

  wb <- createWorkbook()

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
      "diagnostics_file"
    ),
    Value = c(
      "My_Project",
      "data/survey_responses.csv",
      "data/survey_weighted.csv",
      "Y",
      "output/weight_diagnostics.txt"
    ),
    Description = c(
      "Project identifier for reporting",
      "Path to survey data file (relative to config or absolute)",
      "Path for weighted data output (optional)",
      "Save diagnostics to file? (Y/N)",
      "Path for diagnostics report (required if save_diagnostics=Y)"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "General", general_data)
  setColWidths(wb, "General", cols = 1:3, widths = c(20, 35, 50))

  # Add header style
  headerStyle <- createStyle(
    fontColour = "#FFFFFF",
    fgFill = "#4472C4",
    halign = "center",
    textDecoration = "bold"
  )
  addStyle(wb, "General", headerStyle, rows = 1, cols = 1:3, gridExpand = TRUE)

  # ============================================================================
  # Sheet 2: Weight_Specifications
  # ============================================================================
  addWorksheet(wb, "Weight_Specifications")

  weight_specs <- data.frame(
    weight_name = c("design_weight", "population_weight"),
    method = c("design", "rim"),
    description = c(
      "Design weights by customer segment",
      "Rim weights to match population demographics"
    ),
    apply_trimming = c("Y", "Y"),
    trim_method = c("cap", "percentile"),
    trim_value = c(5, 0.95),
    population_total = c(10000, 50000),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Weight_Specifications", weight_specs)
  setColWidths(wb, "Weight_Specifications", cols = 1:7, widths = c(20, 10, 40, 15, 15, 12, 15))
  addStyle(wb, "Weight_Specifications", headerStyle, rows = 1, cols = 1:7, gridExpand = TRUE)

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
    weight_name = c(
      "population_weight", "population_weight", "population_weight",
      "population_weight", "population_weight",
      "population_weight", "population_weight", "population_weight", "population_weight"
    ),
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
  # Sheet 5: Advanced_Settings
  # ============================================================================
  addWorksheet(wb, "Advanced_Settings")

  advanced <- data.frame(
    weight_name = c("population_weight"),
    max_iterations = c(25),
    convergence_tolerance = c(0.01),
    force_convergence = c("N"),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Advanced_Settings", advanced)
  setColWidths(wb, "Advanced_Settings", cols = 1:4, widths = c(20, 15, 22, 18))
  addStyle(wb, "Advanced_Settings", headerStyle, rows = 1, cols = 1:4, gridExpand = TRUE)

  # ============================================================================
  # Sheet 6: Instructions
  # ============================================================================
  addWorksheet(wb, "Instructions")

  instructions <- c(
    "TURAS WEIGHTING MODULE - CONFIGURATION TEMPLATE",
    "",
    "This template helps you configure survey weighting calculations.",
    "",
    "SHEETS:",
    "",
    "1. General - Overall configuration settings",
    "   - project_name: Identifier for your project",
    "   - data_file: Path to your survey data (CSV, Excel, or SPSS)",
    "   - output_file: Where to save weighted data (optional)",
    "   - save_diagnostics: Y/N to save diagnostic report",
    "   - diagnostics_file: Path for diagnostics (if save_diagnostics=Y)",
    "",
    "2. Weight_Specifications - Define each weight to calculate",
    "   - weight_name: Unique name for the weight column",
    "   - method: 'design' for stratified samples, 'rim' for demographic adjustment",
    "   - description: Optional description",
    "   - apply_trimming: Y/N to cap extreme weights",
    "   - trim_method: 'cap' (hard max) or 'percentile' (e.g., 95th percentile)",
    "   - trim_value: Max weight (if cap) or percentile (0-1 if percentile)",
    "   - population_total: Total population size (for grossing up)",
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
    "5. Advanced_Settings (Optional) - Rim weighting parameters",
    "   - max_iterations: Maximum iterations for convergence (default: 25)",
    "   - convergence_tolerance: When to stop (default: 0.01 = 1%)",
    "   - force_convergence: Return weights even if not converged (Y/N)",
    "",
    "USAGE:",
    "",
    "1. Copy this template and rename for your project",
    "2. Update the General settings",
    "3. Define your weights in Weight_Specifications",
    "4. Add targets to Design_Targets and/or Rim_Targets as needed",
    "5. Run: result <- run_weighting('your_config.xlsx')",
    "",
    "TIPS:",
    "",
    "- Rim targets for each variable must sum to 100%",
    "- Design weights: Ensure all stratum categories exist in your data",
    "- For rim weighting, max 5 variables recommended",
    "- Start with apply_trimming=N, then add if needed",
    "",
    "For more information, see the module README."
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
