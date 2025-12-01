# Create Excel Configuration for SaaS Subscription Project

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' required. Install with: install.packages('openxlsx')")
}

library(openxlsx)

cat("Creating Excel configuration for SaaS Subscription project...\n")

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
    "gg_monotonicity_behavior",
    "segment_vars"
  ),
  Value = c(
    "SaaS Subscription Pricing Analysis",
    "gabor_granger",
    "$",
    "saas_subscription_data.csv",
    "respondent_id",
    "survey_weight",
    "99",
    "18",
    "smooth",
    "age_group,company_size,industry"
  )
)
writeData(wb, "Settings", settings_data)

# Sheet 2: GaborGranger
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
    "25,30,35,40,45,50,55",
    "pi_25,pi_30,pi_35,pi_40,pi_45,pi_50,pi_55",
    "binary",
    "TRUE"
  )
)
writeData(wb, "GaborGranger", gg_data)

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
    "0.70",
    "TRUE",
    "0",
    "100"
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
    "saas_results",
    "xlsx",
    "TRUE",
    "TRUE"
  )
)
writeData(wb, "Output", output_data)

# Save workbook
saveWorkbook(wb, "config_saas.xlsx", overwrite = TRUE)

cat("✓ Created config_saas.xlsx\n")
cat("✓ Includes profit optimization (unit_cost = $18)\n")
cat("✓ Ready to load in Turas Pricing GUI\n")
