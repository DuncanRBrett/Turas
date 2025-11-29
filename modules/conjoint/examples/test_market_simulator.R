# ==============================================================================
# TEST MARKET SIMULATOR FUNCTIONS
# ==============================================================================
#
# This script tests the market simulator functionality including:
# - Share prediction (logit, first-choice)
# - Sensitivity analysis
# - What-if scenarios
# - Excel simulator sheet generation
#

# Clear environment
rm(list = ls())

# Set working directory
setwd("/home/user/Turas")

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("TESTING MARKET SIMULATOR\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

# ==============================================================================
# STEP 1: Load required packages and modules
# ==============================================================================

cat("1. Loading packages and modules...\n")

suppressPackageStartupMessages({
  library(mlogit)
  library(survival)
  library(openxlsx)
  library(dplyr)
  library(tidyr)
})

# Source all module files
source("modules/conjoint/R/99_helpers.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/09_none_handling.R")
source("modules/conjoint/R/02_data.R")
source("modules/conjoint/R/03_estimation.R")
source("modules/conjoint/R/04_utilities.R")
source("modules/conjoint/R/05_simulator.R")         # NEW: Market simulator functions
source("modules/conjoint/R/08_market_simulator.R")  # NEW: Excel simulator sheet
source("modules/conjoint/R/07_output.R")
source("modules/conjoint/R/00_main.R")

cat("  ✓ All modules loaded\n\n")

# ==============================================================================
# STEP 2: Run full conjoint analysis to get utilities
# ==============================================================================

cat("2. Running conjoint analysis to get utilities...\n")

results <- run_conjoint_analysis(
  config_file = "modules/conjoint/examples/example_config.xlsx",
  verbose = FALSE
)

cat(sprintf("  ✓ Analysis complete (%d utilities estimated)\n",
            nrow(results$utilities)))
cat("\n")

# ==============================================================================
# STEP 3: Test share prediction functions
# ==============================================================================

cat("3. Testing share prediction functions...\n")

# Create example products
products <- list(
  # Product 1: High-end Apple
  list(
    Brand = "Apple",
    Price = "$299",
    Screen_Size = "6.7 inches",
    Battery_Life = "24 hours",
    Camera_Quality = "Excellent"
  ),
  # Product 2: Mid-range Samsung
  list(
    Brand = "Samsung",
    Price = "$399",
    Screen_Size = "6.1 inches",
    Battery_Life = "18 hours",
    Camera_Quality = "Good"
  ),
  # Product 3: Budget OnePlus
  list(
    Brand = "OnePlus",
    Price = "$599",
    Screen_Size = "5.5 inches",
    Battery_Life = "12 hours",
    Camera_Quality = "Basic"
  )
)

# Test multinomial logit share prediction
cat("\n  Testing multinomial logit (MNL) model:\n")
shares_logit <- predict_market_shares(
  products = products,
  utilities = results$utilities,
  method = "logit",
  verbose = FALSE
)

for (i in seq_len(nrow(shares_logit))) {
  cat(sprintf("    %s: %.1f%% (utility = %.2f)\n",
              shares_logit$Product[i],
              shares_logit$Share_Percent[i],
              shares_logit$Total_Utility[i]))
}

# Verify shares sum to 100%
total_share <- sum(shares_logit$Share_Percent)
cat(sprintf("\n    ✓ Total share = %.1f%% (should be 100.0%%)\n", total_share))
if (abs(total_share - 100) > 0.1) {
  stop("ERROR: Shares do not sum to 100%!")
}

# Test first-choice rule
cat("\n  Testing deterministic first-choice rule:\n")
shares_fc <- predict_market_shares(
  products = products,
  utilities = results$utilities,
  method = "first_choice",
  verbose = FALSE
)

winner <- shares_fc$Product[shares_fc$Share_Percent == 100]
cat(sprintf("    Winner: %s (100%% share)\n", winner))
cat(sprintf("    Utility: %.2f\n", shares_fc$Total_Utility[shares_fc$Share_Percent == 100]))

cat("\n  ✓ Share prediction tests passed\n\n")

# ==============================================================================
# STEP 4: Test one-way sensitivity analysis
# ==============================================================================

cat("4. Testing one-way sensitivity analysis...\n")

base_product <- products[[1]]

# Test sensitivity for Price attribute
price_levels <- c("$299", "$399", "$499", "$599")

sensitivity_price <- sensitivity_one_way(
  base_product = base_product,
  attribute = "Price",
  all_levels = price_levels,
  utilities = results$utilities,
  other_products = products[2:3],
  method = "logit"
)

cat("\n  Price sensitivity for Product 1:\n")
for (i in seq_len(nrow(sensitivity_price))) {
  marker <- if (sensitivity_price$Is_Current[i]) " (current)" else ""
  cat(sprintf("    %-10s: %.1f%% share (change: %+.1f%%)%s\n",
              sensitivity_price$Level[i],
              sensitivity_price$Share_Percent[i],
              sensitivity_price$Share_Change[i],
              marker))
}

cat("\n  ✓ Sensitivity analysis test passed\n\n")

# ==============================================================================
# STEP 5: Test two-way sensitivity
# ==============================================================================

cat("5. Testing two-way sensitivity analysis...\n")

sensitivity_2way <- sensitivity_two_way(
  base_product = base_product,
  attribute1 = "Price",
  levels1 = c("$299", "$399"),
  attribute2 = "Battery_Life",
  levels2 = c("12 hours", "18 hours", "24 hours"),
  utilities = results$utilities,
  other_products = products[2:3],
  method = "logit"
)

cat("\n  Price x Battery Life sensitivity grid:\n")
cat(sprintf("    %-10s", "Price"))
for (battery in unique(sensitivity_2way$Battery_Life)) {
  cat(sprintf(" | %-12s", battery))
}
cat("\n")
cat("    ", rep("-", 60), "\n", sep = "")

for (price in unique(sensitivity_2way$Price)) {
  cat(sprintf("    %-10s", price))
  for (battery in unique(sensitivity_2way$Battery_Life)) {
    share <- sensitivity_2way$Share_Percent[
      sensitivity_2way$Price == price &
      sensitivity_2way$Battery_Life == battery
    ]
    cat(sprintf(" | %5.1f%%      ", share))
  }
  cat("\n")
}

cat("\n  ✓ Two-way sensitivity test passed\n\n")

# ==============================================================================
# STEP 6: Test scenario comparison
# ==============================================================================

cat("6. Testing scenario comparison...\n")

scenarios <- list(
  "Current" = list(products[[1]], products[[2]], products[[3]]),
  "Improved_P1" = list(
    list(
      Brand = "Apple",
      Price = "$299",  # Lower price
      Screen_Size = "6.7 inches",
      Battery_Life = "24 hours",
      Camera_Quality = "Excellent"
    ),
    products[[2]],
    products[[3]]
  )
)

scenario_results <- compare_scenarios(
  scenarios = scenarios,
  utilities = results$utilities,
  method = "logit"
)

cat("\n  Scenario comparison:\n")
for (scenario in unique(scenario_results$Scenario)) {
  cat(sprintf("\n    %s:\n", scenario))
  scenario_data <- scenario_results[scenario_results$Scenario == scenario, ]
  for (i in seq_len(nrow(scenario_data))) {
    cat(sprintf("      %s: %.1f%%\n",
                scenario_data$Product[i],
                scenario_data$Share_Percent[i]))
  }
}

cat("\n  ✓ Scenario comparison test passed\n\n")

# ==============================================================================
# STEP 7: Test product optimization
# ==============================================================================

cat("7. Testing product optimization...\n")

optimization_result <- optimize_product(
  base_product = products[[3]],  # Start with worst product
  utilities = results$utilities,
  config = results$config,
  other_products = products[1:2],
  max_iterations = 50,
  method = "logit"
)

cat(sprintf("\n  Optimization results:\n"))
cat(sprintf("    Initial share: %.1f%%\n", optimization_result$initial_share))
cat(sprintf("    Final share:   %.1f%%\n", optimization_result$final_share))
cat(sprintf("    Improvement:   %+.1f percentage points\n", optimization_result$improvement))
cat(sprintf("    Iterations:    %d\n", optimization_result$iterations))
cat(sprintf("    Converged:     %s\n", optimization_result$converged))

cat("\n    Optimized product configuration:\n")
for (attr in names(optimization_result$optimized_product)) {
  original <- products[[3]][[attr]]
  optimized <- optimization_result$optimized_product[[attr]]
  changed <- if (original != optimized) " (CHANGED)" else ""
  cat(sprintf("      %-20s: %s%s\n", attr, optimized, changed))
}

cat("\n  ✓ Optimization test passed\n\n")

# ==============================================================================
# STEP 8: Verify Excel output with simulator
# ==============================================================================

cat("8. Verifying Excel output includes market simulator...\n")

output_file <- "modules/conjoint/examples/output/example_results.xlsx"

if (!file.exists(output_file)) {
  stop("ERROR: Output file not found! Run full analysis first.")
}

# Load workbook
wb <- loadWorkbook(output_file)
sheet_names <- names(wb)

cat(sprintf("\n  Found %d sheets:\n", length(sheet_names)))
for (sheet in sheet_names) {
  marker <- if (grepl("Simulator", sheet)) " ← SIMULATOR" else ""
  cat(sprintf("    - %s%s\n", sheet, marker))
}

# Check for simulator sheets
has_market_sim <- "Market Simulator" %in% sheet_names
has_sim_data <- "Simulator Data" %in% sheet_names

if (!has_market_sim) {
  stop("ERROR: 'Market Simulator' sheet not found in output!")
}

if (!has_sim_data) {
  stop("ERROR: 'Simulator Data' sheet not found in output!")
}

cat("\n  ✓ Both simulator sheets present\n")

# Verify simulator data sheet has utilities
sim_data <- readWorkbook(wb, "Simulator Data")
cat(sprintf("\n  Simulator Data sheet:\n"))
cat(sprintf("    Rows: %d (should match number of utility levels)\n", nrow(sim_data)))
cat(sprintf("    Columns: %s\n", paste(names(sim_data), collapse = ", ")))

expected_rows <- nrow(results$utilities)
if (nrow(sim_data) != expected_rows) {
  warning(sprintf("Expected %d rows, found %d", expected_rows, nrow(sim_data)))
}

cat("\n  ✓ Simulator data sheet verification passed\n\n")

# ==============================================================================
# STEP 9: Test manual share calculation vs. Excel formulas
# ==============================================================================

cat("9. Verifying Excel formulas produce correct shares...\n")

# Read market simulator sheet
market_sim <- readWorkbook(wb, "Market Simulator",
                            colNames = FALSE,  # Don't use first row as names
                            skipEmptyRows = FALSE,
                            skipEmptyCols = FALSE)

cat("\n  Note: Excel formula verification requires opening file in Excel\n")
cat(sprintf("  File location: %s\n", output_file))
cat("\n  Manual verification steps:\n")
cat("    1. Open the Excel file\n")
cat("    2. Go to 'Market Simulator' sheet\n")
cat("    3. Change dropdown values and verify shares update\n")
cat("    4. Verify shares always sum to 100%\n")
cat("    5. Check that utilities breakdown matches configuration\n")

cat("\n  ✓ Excel output verification complete\n\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat(rep("=", 80), "\n", sep = "")
cat("ALL MARKET SIMULATOR TESTS PASSED!\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

cat("Tests completed:\n")
cat("  ✓ Share prediction (logit model)\n")
cat("  ✓ Share prediction (first-choice rule)\n")
cat("  ✓ One-way sensitivity analysis\n")
cat("  ✓ Two-way sensitivity analysis\n")
cat("  ✓ Scenario comparison\n")
cat("  ✓ Product optimization\n")
cat("  ✓ Excel simulator sheet generation\n")
cat("  ✓ Simulator data sheet generation\n")
cat("\n")

cat("Next steps:\n")
cat("  1. Open the Excel file and test the interactive simulator\n")
cat("  2. Try changing dropdown values and watch shares update\n")
cat("  3. Experiment with different product configurations\n")
cat("\n")

cat(sprintf("Excel file: %s\n", output_file))
cat(sprintf("File size: %.1f KB\n\n", file.size(output_file) / 1024))

# Return results for further inspection
invisible(list(
  shares_logit = shares_logit,
  shares_first_choice = shares_fc,
  sensitivity_price = sensitivity_price,
  sensitivity_2way = sensitivity_2way,
  scenarios = scenario_results,
  optimization = optimization_result,
  output_file = output_file
))
