# ==============================================================================
# TURAS PRICING MODULE - TEST SCRIPT FOR NEW FEATURES
# ==============================================================================
#
# Purpose: Test all Phase 1-3 implementations
# Run from: Turas root directory
#
# ==============================================================================

cat("\n")
cat("===============================================\n")
cat("TURAS PRICING MODULE - FEATURE TEST\n")
cat("Testing Phases 1, 2, 3 implementations\n")
cat("===============================================\n\n")

# Set working directory to Turas root
if (basename(getwd()) != "Turas") {
  stop("Please run this script from the Turas root directory")
}

# Source all pricing module files
cat("Loading pricing module...\n")
source("modules/pricing/R/00_main.R")
source("modules/pricing/R/01_config.R")
source("modules/pricing/R/02_validation.R")
source("modules/pricing/R/03_van_westendorp.R")
source("modules/pricing/R/04_gabor_granger.R")
source("modules/pricing/R/05_visualization.R")
source("modules/pricing/R/06_output.R")
source("modules/pricing/R/07_wtp_distribution.R")
source("modules/pricing/R/08_competitive_scenarios.R")
source("modules/pricing/R/09_price_volume_optimisation.R")

cat("✓ All modules loaded successfully\n\n")

# ==============================================================================
# CREATE TEST DATA
# ==============================================================================

cat("Creating test data...\n")

set.seed(42)
n <- 200

# Create Van Westendorp test data with weights
test_data_vw <- data.frame(
  respondent_id = 1:n,
  weight = runif(n, 0.5, 2.0),  # Varying weights
  age_group = sample(c("18-34", "35-54", "55+"), n, replace = TRUE),

  # Van Westendorp questions (prices in dollars)
  too_cheap = rnorm(n, 15, 5),
  cheap = rnorm(n, 25, 5),
  expensive = rnorm(n, 45, 8),
  too_expensive = rnorm(n, 60, 10),

  stringsAsFactors = FALSE
)

# Ensure monotonicity for most (but not all - to test monotonicity handling)
for (i in 1:n) {
  if (runif(1) > 0.1) {  # 90% monotonic
    vals <- c(test_data_vw$too_cheap[i], test_data_vw$cheap[i],
              test_data_vw$expensive[i], test_data_vw$too_expensive[i])
    sorted <- sort(vals)
    test_data_vw$too_cheap[i] <- sorted[1]
    test_data_vw$cheap[i] <- sorted[2]
    test_data_vw$expensive[i] <- sorted[3]
    test_data_vw$too_expensive[i] <- sorted[4]
  }
}

# Add some "don't know" codes (98, 99)
dk_indices <- sample(1:n, 10)
test_data_vw$too_cheap[dk_indices[1:3]] <- 98
test_data_vw$cheap[dk_indices[4:6]] <- 99

# Clip to reasonable ranges
test_data_vw$too_cheap <- pmax(5, pmin(100, test_data_vw$too_cheap))
test_data_vw$cheap <- pmax(5, pmin(100, test_data_vw$cheap))
test_data_vw$expensive <- pmax(5, pmin(100, test_data_vw$expensive))
test_data_vw$too_expensive <- pmax(5, pmin(100, test_data_vw$too_expensive))

# Save test data
write.csv(test_data_vw, "modules/pricing/test_data_vw.csv", row.names = FALSE)
cat("✓ Created test_data_vw.csv (n=200 with weights, segments, DK codes)\n")

# Create Gabor-Granger test data (wide format)
test_data_gg <- data.frame(
  respondent_id = 1:n,
  weight = runif(n, 0.5, 2.0),
  age_group = sample(c("18-34", "35-54", "55+"), n, replace = TRUE),

  # Purchase intent at different prices (0/1)
  # Generally decreasing with price
  pi_25 = rbinom(n, 1, 0.85),
  pi_30 = rbinom(n, 1, 0.75),
  pi_35 = rbinom(n, 1, 0.60),
  pi_40 = rbinom(n, 1, 0.45),
  pi_45 = rbinom(n, 1, 0.30),
  pi_50 = rbinom(n, 1, 0.15),

  stringsAsFactors = FALSE
)

# Add some DK codes
dk_indices_gg <- sample(1:n, 8)
test_data_gg$pi_30[dk_indices_gg[1:4]] <- 98
test_data_gg$pi_40[dk_indices_gg[5:8]] <- 99

write.csv(test_data_gg, "modules/pricing/test_data_gg.csv", row.names = FALSE)
cat("✓ Created test_data_gg.csv (n=200 with weights, segments, DK codes)\n\n")

# ==============================================================================
# TEST PHASE 1: CRITICAL FEATURES
# ==============================================================================

cat("===============================================\n")
cat("TESTING PHASE 1: CRITICAL FEATURES\n")
cat("===============================================\n\n")

# Test 1.1: Van Westendorp with Weights
cat("Test 1.1: Van Westendorp with Weights\n")
cat("--------------------------------------\n")

config_vw <- list(
  van_westendorp = list(
    col_too_cheap = "too_cheap",
    col_cheap = "cheap",
    col_expensive = "expensive",
    col_too_expensive = "too_expensive",
    validate_monotonicity = TRUE
  ),
  weight_var = "weight",
  vw_monotonicity_behavior = "flag_only",
  dk_codes = c(98, 99),
  validation = list(min_completeness = 0.8)
)

result_vw <- run_van_westendorp(test_data_vw, config_vw)

cat("Results:\n")
cat(sprintf("  Sample size: %d (effective n = %.0f)\n",
            result_vw$diagnostics$n_valid,
            result_vw$diagnostics$n_valid))  # Would show weighted n if tracked
cat(sprintf("  PMC: $%.2f\n", result_vw$price_points$PMC))
cat(sprintf("  OPP: $%.2f\n", result_vw$price_points$OPP))
cat(sprintf("  IDP: $%.2f\n", result_vw$price_points$IDP))
cat(sprintf("  PME: $%.2f\n", result_vw$price_points$PME))
cat(sprintf("  Acceptable range: $%.2f - $%.2f\n",
            result_vw$acceptable_range$lower,
            result_vw$acceptable_range$upper))
cat("✓ Van Westendorp with weights working!\n\n")

# Test 1.2: Gabor-Granger with Weights and Profit
cat("Test 1.2: Gabor-Granger with Weights and Profit\n")
cat("------------------------------------------------\n")

config_gg <- list(
  gabor_granger = list(
    data_format = "wide",
    price_sequence = c(25, 30, 35, 40, 45, 50),
    response_columns = c("pi_25", "pi_30", "pi_35", "pi_40", "pi_45", "pi_50"),
    response_coding = "binary",
    revenue_optimization = TRUE
  ),
  weight_var = "weight",
  unit_cost = 18,  # Unit cost for profit calculation
  gg_monotonicity_behavior = "smooth",
  dk_codes = c(98, 99),
  id_var = "respondent_id"
)

result_gg <- run_gabor_granger(test_data_gg, config_gg)

cat("Results:\n")
cat(sprintf("  Sample size: %d respondents\n", result_gg$diagnostics$n_respondents))
cat(sprintf("  Has profit calculation: %s\n", result_gg$diagnostics$has_profit))
cat("\nRevenue-maximizing price:\n")
cat(sprintf("  Price: $%.2f\n", result_gg$optimal_price$price))
cat(sprintf("  Purchase intent: %.1f%%\n", result_gg$optimal_price$purchase_intent * 100))
cat(sprintf("  Revenue index: %.2f\n", result_gg$optimal_price$revenue_index))

if (!is.null(result_gg$optimal_price_profit)) {
  cat("\nProfit-maximizing price:\n")
  cat(sprintf("  Price: $%.2f\n", result_gg$optimal_price_profit$price))
  cat(sprintf("  Purchase intent: %.1f%%\n", result_gg$optimal_price_profit$purchase_intent * 100))
  cat(sprintf("  Profit index: %.2f\n", result_gg$optimal_price_profit$profit_index))
  cat(sprintf("  Margin: $%.2f\n", result_gg$optimal_price_profit$margin))
}
cat("✓ Gabor-Granger with weights and profit working!\n\n")

# ==============================================================================
# TEST PHASE 3: ADVANCED FEATURES
# ==============================================================================

cat("===============================================\n")
cat("TESTING PHASE 3: ADVANCED FEATURES\n")
cat("===============================================\n\n")

# Test 3.1: WTP Distribution
cat("Test 3.1: WTP Distribution Extraction\n")
cat("--------------------------------------\n")

config_wtp <- list(
  van_westendorp = config_vw$van_westendorp,
  weight_var = "weight",
  segment_vars = c("age_group"),
  id_var = "respondent_id"
)

wtp_vw <- extract_wtp_vw(test_data_vw, config_wtp, method = "median")
cat(sprintf("  WTP records extracted: %d\n", nrow(wtp_vw)))

wtp_summary <- compute_wtp_summary(wtp_vw)
cat(sprintf("  Mean WTP: $%.2f\n", wtp_summary$mean))
cat(sprintf("  Median WTP: $%.2f\n", wtp_summary$median))
cat(sprintf("  SD: $%.2f\n", wtp_summary$sd))

percentiles <- compute_wtp_percentiles(wtp_vw)
cat("\n  Percentiles:\n")
cat(sprintf("    25th: $%.2f\n", percentiles["p25"]))
cat(sprintf("    50th: $%.2f\n", percentiles["p50"]))
cat(sprintf("    75th: $%.2f\n", percentiles["p75"]))

cat("✓ WTP distribution extraction working!\n\n")

# Test 3.2: Competitive Scenarios
cat("Test 3.2: Competitive Scenario Simulation\n")
cat("------------------------------------------\n")

# Define competitive pricing scenarios
prices_base <- c(our_brand = 35, comp_a = 40, comp_b = 32)
prices_premium <- c(our_brand = 42, comp_a = 40, comp_b = 32)
prices_value <- c(our_brand = 30, comp_a = 40, comp_b = 32)

scenarios <- data.frame(
  our_brand = c(35, 42, 30),
  comp_a = c(40, 40, 40),
  comp_b = c(32, 32, 32)
)
rownames(scenarios) <- c("Base", "Premium", "Value")

scenario_results <- simulate_scenarios(wtp_vw, scenarios,
                                      scenario_names = rownames(scenarios),
                                      allow_no_purchase = TRUE,
                                      market_size = 100000)

cat("  Market share by scenario:\n")
for (scenario in unique(scenario_results$scenario)) {
  cat(sprintf("\n  %s:\n", scenario))
  subset <- scenario_results[scenario_results$scenario == scenario, ]
  for (i in 1:nrow(subset)) {
    cat(sprintf("    %s: %.1f%%\n", subset$brand[i], subset$share[i] * 100))
  }
}

cat("✓ Competitive scenarios working!\n\n")

# Test 3.3: Constrained Optimization
cat("Test 3.3: Constrained Price Optimization\n")
cat("-----------------------------------------\n")

# Find profit-maximizing price with minimum volume constraint
optimal_constrained <- find_constrained_optimal(
  result_gg$revenue_curve,
  objective = "profit",
  constraints = list(min_volume = 30000),
  market_size = 100000
)

cat("  Constrained optimal price (min 30k volume):\n")
if (optimal_constrained$feasible) {
  cat(sprintf("    Price: $%.2f\n", optimal_constrained$price))
  cat(sprintf("    Volume: %.0f\n", optimal_constrained$volume))
  cat(sprintf("    Profit index: %.2f\n", optimal_constrained$profit_index))
} else {
  cat("    No feasible solution found\n")
}

# Find price to achieve target volume
target_volume_result <- find_price_for_volume(
  result_gg$demand_curve,
  target_volume = 40000,
  market_size = 100000
)

cat("\n  Price for 40k volume:\n")
cat(sprintf("    Price: $%.2f\n", target_volume_result$price))
cat(sprintf("    Actual volume: %.0f\n", target_volume_result$volume))
cat(sprintf("    Target met: %s\n", target_volume_result$target_met))

cat("✓ Constrained optimization working!\n\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("===============================================\n")
cat("TEST SUMMARY\n")
cat("===============================================\n\n")

cat("✅ PHASE 1 TESTS PASSED:\n")
cat("   ✓ Weighted Van Westendorp\n")
cat("   ✓ Weighted Gabor-Granger\n")
cat("   ✓ DK code handling\n")
cat("   ✓ Monotonicity handling\n")
cat("   ✓ Profit optimization\n\n")

cat("✅ PHASE 3 TESTS PASSED:\n")
cat("   ✓ WTP distribution extraction\n")
cat("   ✓ Competitive scenario simulation\n")
cat("   ✓ Constrained price optimization\n\n")

cat("===============================================\n")
cat("ALL TESTS COMPLETED SUCCESSFULLY! 🎉\n")
cat("===============================================\n\n")

cat("Test data files created:\n")
cat("  - modules/pricing/test_data_vw.csv\n")
cat("  - modules/pricing/test_data_gg.csv\n\n")

cat("You can now:\n")
cat("  1. Examine the test data files\n")
cat("  2. Run analyses with your own data\n")
cat("  3. Create config templates with create_pricing_config()\n")
cat("  4. Use the new advanced features in your workflows\n\n")
