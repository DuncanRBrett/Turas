# ==============================================================================
# CREATE WEIGHT_CONFIG.XLSX FOR EXAMPLE 2
# ==============================================================================
# Run this script to create the Weight_Config.xlsx file for example 2
#
# Usage:
#   setwd("modules/weighting/examples/example2_rim_weights")
#   source("create_config.R")
# ==============================================================================

library(openxlsx)

cat("Creating Weight_Config.xlsx...\n")

wb <- createWorkbook()

# ==============================================================================
# Sheet 1: General
# ==============================================================================
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
    "Consumer_Panel_Study",
    "data/consumer_panel.csv",
    "output/consumer_panel_weighted.csv",
    "Y",
    "output/diagnostics.txt"
  ),
  stringsAsFactors = FALSE
)

writeData(wb, "General", general_data)
cat("  ✓ General sheet created\n")

# ==============================================================================
# Sheet 2: Weight_Specifications
# ==============================================================================
addWorksheet(wb, "Weight_Specifications")

weight_specs <- data.frame(
  weight_name = "population_weight",
  method = "rim",
  description = "Rim weighting to match population demographics",
  apply_trimming = "N",
  trim_method = "",
  trim_value = "",
  stringsAsFactors = FALSE
)

writeData(wb, "Weight_Specifications", weight_specs)
cat("  ✓ Weight_Specifications sheet created\n")

# ==============================================================================
# Sheet 3: Design_Targets (empty - not needed for rim weighting)
# ==============================================================================
addWorksheet(wb, "Design_Targets")

design_targets <- data.frame(
  weight_name = character(),
  stratum_variable = character(),
  stratum_category = character(),
  population_size = numeric(),
  stringsAsFactors = FALSE
)

writeData(wb, "Design_Targets", design_targets)
cat("  ✓ Design_Targets sheet created (empty)\n")

# ==============================================================================
# Sheet 4: Rim_Targets
# ==============================================================================
addWorksheet(wb, "Rim_Targets")

rim_targets <- data.frame(
  weight_name = c(
    "population_weight", "population_weight", "population_weight",
    "population_weight", "population_weight", "population_weight",
    "population_weight", "population_weight",
    "population_weight", "population_weight", "population_weight"
  ),
  variable = c(
    "age", "age", "age", "age", "age", "age",
    "gender", "gender",
    "region", "region", "region"
  ),
  category = c(
    "18-24", "25-34", "35-44", "45-54", "55-64", "65+",
    "Male", "Female",
    "Urban", "Suburban", "Rural"
  ),
  target_percent = c(
    13, 18, 17, 17, 16, 19,
    49, 51,
    35, 45, 20
  ),
  stringsAsFactors = FALSE
)

writeData(wb, "Rim_Targets", rim_targets)
cat("  ✓ Rim_Targets sheet created\n")
cat("    - age: 13% 18-24, 18% 25-34, 17% 35-44, 17% 45-54, 16% 55-64, 19% 65+\n")
cat("    - gender: 49% Male, 51% Female\n")
cat("    - region: 35% Urban, 45% Suburban, 20% Rural\n")

# ==============================================================================
# Sheet 5: Advanced_Settings
# ==============================================================================
addWorksheet(wb, "Advanced_Settings")

advanced <- data.frame(
  weight_name = "population_weight",
  max_iterations = 100,
  convergence_tolerance = 1e-7,
  force_convergence = "N",
  calibration_method = "raking",
  weight_bounds = "0.1,10.0",
  stringsAsFactors = FALSE
)

writeData(wb, "Advanced_Settings", advanced)
cat("  ✓ Advanced_Settings sheet created\n")
cat("    - calibration_method: raking\n")
cat("    - weight_bounds: 0.1,10.0\n")
cat("    - max_iterations: 100\n")
cat("    - convergence_tolerance: 1e-7\n")

# ==============================================================================
# Save workbook
# ==============================================================================
saveWorkbook(wb, "Weight_Config.xlsx", overwrite = TRUE)

cat("\n✓ Weight_Config.xlsx created successfully!\n")
cat("\nTo run the example:\n")
cat("  source('../../run_weighting.R')\n")
cat("  result <- run_weighting('Weight_Config.xlsx')\n")
cat("  print(result$weight_results$population_weight$diagnostics)\n")
