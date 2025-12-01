# Create Excel Configuration for Consumer Electronics Project

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' required. Install with: install.packages('openxlsx')")
}

library(openxlsx)

cat("Creating Excel configuration for Consumer Electronics project...\n")

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
    "vw_monotonicity_behavior",
    "segment_vars"
  ),
  Value = c(
    "Smart Speaker Pricing Study",
    "van_westendorp",
    "$",
    "smart_speaker_data.csv",
    "respondent_id",
    "survey_weight",
    "98",
    "flag_only",
    "age_group,income,region"
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
    "too_cheap",
    "cheap",
    "expensive",
    "too_expensive",
    "TRUE"
  )
)
writeData(wb, "VanWestendorp", vw_data)

# Sheet 3: Bootstrap
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

# Sheet 4: Validation
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
    "500"
  )
)
writeData(wb, "Validation", validation_data)

# Sheet 5: Output
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
    "smart_speaker_results",
    "xlsx",
    "TRUE",
    "TRUE"
  )
)
writeData(wb, "Output", output_data)

# Save workbook
saveWorkbook(wb, "config_electronics.xlsx", overwrite = TRUE)

cat("✓ Created config_electronics.xlsx\n")
cat("✓ Ready to load in Turas Pricing GUI\n")
