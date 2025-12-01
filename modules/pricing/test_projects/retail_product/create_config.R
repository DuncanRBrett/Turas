# Create Excel Configuration for Retail Product Project (Both Methods)

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' required. Install with: install.packages('openxlsx')")
}

library(openxlsx)

cat("Creating Excel configuration for Retail Product project...\n")

wb <- createWorkbook()

# Sheet 1: Settings
addWorksheet(wb, "Settings")
settings_data <- data.frame(
  Setting = c(
    "project_name",
    "analysis_method",
    "currency_symbol",
    "data_file",
    "id_var",
    "weight_var",
    "dk_codes",
    "unit_cost",
    "vw_monotonicity_behavior",
    "gg_monotonicity_behavior",
    "segment_vars"
  ),
  Value = c(
    "Premium Coffee Maker Pricing",
    "both",
    "$",
    "coffee_maker_data.csv",
    "respondent_id",
    "survey_weight",
    "98,99",
    "95",
    "flag_only",
    "smooth",
    "age_group,income_bracket,coffee_consumption"
  )
)
writeData(wb, "Settings", settings_data)

# Sheet 2: VanWestendorp
addWorksheet(wb, "VanWestendorp")
vw_data <- data.frame(
  Setting = c(
    "col_too_cheap",
    "col_cheap",
    "col_expensive",
    "col_too_expensive",
    "validate_monotonicity"
  ),
  Value = c(
    "vw_too_cheap",
    "vw_cheap",
    "vw_expensive",
    "vw_too_expensive",
    "TRUE"
  )
)
writeData(wb, "VanWestendorp", vw_data)

# Sheet 3: GaborGranger
addWorksheet(wb, "GaborGranger")
gg_data <- data.frame(
  Setting = c(
    "data_format",
    "price_sequence",
    "response_columns",
    "response_coding",
    "revenue_optimization"
  ),
  Value = c(
    "wide",
    "180,200,220,240,260,280",
    "gg_180,gg_200,gg_220,gg_240,gg_260,gg_280",
    "binary",
    "TRUE"
  )
)
writeData(wb, "GaborGranger", gg_data)

# Sheet 4: Bootstrap
addWorksheet(wb, "Bootstrap")
bootstrap_data <- data.frame(
  Setting = c(
    "enabled",
    "n_iterations",
    "confidence_level",
    "method"
  ),
  Value = c(
    "TRUE",
    "1000",
    "0.95",
    "percentile"
  )
)
writeData(wb, "Bootstrap", bootstrap_data)

# Sheet 5: Validation
addWorksheet(wb, "Validation")
validation_data <- data.frame(
  Setting = c(
    "min_completeness",
    "check_ranges",
    "min_price",
    "max_price"
  ),
  Value = c(
    "0.75",
    "TRUE",
    "0",
    "600"
  )
)
writeData(wb, "Validation", validation_data)

# Sheet 6: Output
addWorksheet(wb, "Output")
output_data <- data.frame(
  Setting = c(
    "directory",
    "filename_prefix",
    "format",
    "save_plots",
    "save_data"
  ),
  Value = c(
    "output",
    "coffee_maker_results",
    "xlsx",
    "TRUE",
    "TRUE"
  )
)
writeData(wb, "Output", output_data)

# Save workbook
saveWorkbook(wb, "config_retail.xlsx", overwrite = TRUE)

cat("✓ Created config_retail.xlsx\n")
cat("✓ Includes both VW and GG analysis\n")
cat("✓ Profit optimization enabled (unit_cost = $95)\n")
cat("✓ Ready to load in Turas Pricing GUI\n")
