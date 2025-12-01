# Setup All Test Projects
# Generates data and configs for all three test scenarios

cat("===================================================\n")
cat("  Turas Pricing Module - Test Projects Setup\n")
cat("===================================================\n\n")

# Check required package
if (!requireNamespace("openxlsx", quietly = TRUE)) {
  cat("Installing required package: openxlsx\n")
  install.packages("openxlsx")
}

projects <- list(
  list(name = "Consumer Electronics", dir = "consumer_electronics"),
  list(name = "SaaS Subscription", dir = "saas_subscription"),
  list(name = "Retail Product", dir = "retail_product")
)

for (proj in projects) {
  cat(sprintf("\n[%s]\n", proj$name))
  cat(sprintf("  Directory: %s/\n", proj$dir))
  
  # Change to project directory
  setwd(proj$dir)
  
  # Generate data
  cat("  → Generating data... ")
  source("generate_data.R", local = TRUE)
  
  # Create config
  cat("  → Creating config... ")
  source("create_config.R", local = TRUE)
  
  # Return to parent
  setwd("..")
  
  cat("  ✓ Complete\n")
}

cat("\n===================================================\n")
cat("  All test projects created successfully!\n")
cat("===================================================\n\n")

cat("Files created:\n")
cat("  consumer_electronics/\n")
cat("    - smart_speaker_data.csv\n")
cat("    - config_electronics.xlsx\n\n")

cat("  saas_subscription/\n")
cat("    - saas_subscription_data.csv\n")
cat("    - config_saas.xlsx\n\n")

cat("  retail_product/\n")
cat("    - coffee_maker_data.csv\n")
cat("    - config_retail.xlsx\n\n")

cat("Next steps:\n")
cat("1. Test in GUI: Launch Turas → Pricing → Load config files\n")
cat("2. Copy to OneDrive: Move project folders to OneDrive/Projects/\n")
cat("3. See README.md in each folder for detailed project info\n\n")

cat("Quick test:\n")
cat("  • Start with consumer_electronics (simplest)\n")
cat("  • Then saas_subscription (profit optimization)\n")
cat("  • Finish with retail_product (complete features)\n\n")
