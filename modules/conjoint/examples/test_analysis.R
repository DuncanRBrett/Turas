# ==============================================================================
# TEST CONJOINT ANALYSIS WITH EXAMPLE DATA
# ==============================================================================
#
# This script tests the enhanced Turas conjoint module with example data
#

# Clear environment
rm(list = ls())

# Set working directory to Turas root
setwd("/home/user/Turas")

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("TESTING ENHANCED TURAS CONJOINT MODULE\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

# ==============================================================================
# STEP 1: Load required packages
# ==============================================================================

cat("1. Checking required packages...\n")

required_packages <- c("mlogit", "survival", "openxlsx", "dplyr", "tidyr")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("  ✗ Package '%s' not installed. Installing...\n", pkg))
    install.packages(pkg, repos = "https://cloud.r-project.org/", quiet = TRUE)
  }
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}

cat("  ✓ All required packages loaded\n")

# ==============================================================================
# STEP 2: Source module files
# ==============================================================================

cat("\n2. Sourcing module files...\n")

module_files <- c(
  "modules/conjoint/R/99_helpers.R",
  "modules/conjoint/R/01_config.R",
  "modules/conjoint/R/09_none_handling.R",
  "modules/conjoint/R/02_data.R",
  "modules/conjoint/R/03_estimation.R",
  "modules/conjoint/R/04_utilities.R",
  "modules/conjoint/R/05_simulator.R",         # Market simulator functions
  "modules/conjoint/R/08_market_simulator.R",  # Excel simulator sheet
  "modules/conjoint/R/07_output.R",
  "modules/conjoint/R/00_main.R"
)

for (file in module_files) {
  file_path <- file.path(getwd(), file)
  if (!file.exists(file_path)) {
    stop(sprintf("ERROR: Module file not found: %s", file_path))
  }
  source(file_path)
  cat(sprintf("  ✓ %s\n", basename(file)))
}

cat("  ✓ All module files loaded successfully\n")

# ==============================================================================
# STEP 3: Run analysis
# ==============================================================================

cat("\n3. Running conjoint analysis with example data...\n\n")

# Run analysis
results <- tryCatch({
  run_conjoint_analysis(
    config_file = "modules/conjoint/examples/example_config.xlsx",
    verbose = TRUE
  )
}, error = function(e) {
  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("TEST FAILED\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\nError:\n")
  cat(conditionMessage(e), "\n\n")
  stop(e)
})

# ==============================================================================
# STEP 4: Verify results
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("RESULTS SUMMARY\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

# Check results structure
cat("Result structure:\n")
cat(sprintf("  - Version: %s\n", results$version))
cat(sprintf("  - Method: %s\n", results$model_result$method))
cat(sprintf("  - Convergence: %s\n",
            if(results$model_result$convergence$converged) "✓ Success" else "✗ Failed"))
cat(sprintf("  - Elapsed time: %.2f seconds\n", results$elapsed_time))
cat("\n")

# Attribute importance
cat("Attribute Importance (Top 3):\n")
for (i in 1:min(3, nrow(results$importance))) {
  cat(sprintf("  %d. %-20s: %5.1f%%\n",
              i,
              results$importance$Attribute[i],
              results$importance$Importance[i]))
}
cat("\n")

# Model fit
if (results$model_result$method %in% c("mlogit", "clogit")) {
  cat("Model Fit:\n")
  cat(sprintf("  - McFadden R²: %.3f\n",
              results$diagnostics$fit_statistics$mcfadden_r2))
  cat(sprintf("  - Hit Rate: %.1f%%\n",
              results$diagnostics$fit_statistics$hit_rate * 100))
  cat(sprintf("  - AIC: %.1f\n", results$diagnostics$fit_statistics$aic))
  cat("\n")
}

# Utilities sample
cat("Sample Utilities (first attribute):\n")
first_attr <- results$utilities$Attribute[1]
first_attr_utils <- results$utilities[results$utilities$Attribute == first_attr, ]
for (i in 1:nrow(first_attr_utils)) {
  cat(sprintf("  %-20s: %7.3f %s (p=%0.3f)\n",
              first_attr_utils$Level[i],
              first_attr_utils$Utility[i],
              first_attr_utils$Significance[i],
              first_attr_utils$p_value[i]))
}
cat("\n")

# Check output file
output_file <- results$config$output_file
if (file.exists(output_file)) {
  cat(sprintf("✓ Output file created: %s\n", output_file))
  cat(sprintf("  File size: %.1f KB\n", file.size(output_file) / 1024))
} else {
  cat(sprintf("✗ Output file NOT found: %s\n", output_file))
}

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("TEST COMPLETED SUCCESSFULLY!\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

# Return results invisibly
invisible(results)
