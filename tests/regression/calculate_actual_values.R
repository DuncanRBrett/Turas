#!/usr/bin/env Rscript
# Calculate actual values for failing modules

library(jsonlite)

# Source helpers
source("tests/regression/helpers/assertion_helpers.R")
source("tests/regression/helpers/path_helpers.R")

# Source test files to get mock functions
source("tests/regression/test_regression_keydriver_mock.R")
source("tests/regression/test_regression_segment_mock.R")
source("tests/regression/test_regression_pricing_mock.R")

cat("================================================================================\n")
cat("CALCULATING ACTUAL VALUES FOR GOLDEN FILES\n")
cat("================================================================================\n\n")

# KeyDriver
cat("1. KEYDRIVER MODULE\n")
cat("-------------------\n")
paths <- get_example_paths("keydriver", "basic")
output <- mock_keydriver_module(paths$data)
cat("R-squared:", output$model_fit$r_squared, "\n")
cat("Adjusted R-squared:", output$model_fit$adj_r_squared, "\n")
cat("Correlation - product quality:", output$correlations$product_quality, "\n")
cat("Correlation - customer service:", output$correlations$customer_service, "\n")
cat("Correlation - value for money:", output$correlations$value_for_money, "\n")
cat("Relative importance - product quality:", output$importance$product_quality$pct, "\n")
cat("Relative importance - customer service:", output$importance$customer_service$pct, "\n")
cat("\n")

# Segment
cat("2. SEGMENT MODULE\n")
cat("-----------------\n")
paths <- get_example_paths("segment", "basic")
output <- mock_segment_module(paths$data)
cat("Cluster 1 size:", output$cluster_sizes[[1]], "\n")
cat("Cluster 2 size:", output$cluster_sizes[[2]], "\n")
cat("Cluster 3 size:", output$cluster_sizes[[3]], "\n")
cat("Silhouette score:", output$quality_metrics$silhouette_score, "\n")
cat("Between SS ratio:", output$quality_metrics$between_ss_ratio, "\n")
cat("\n")

# Pricing
cat("3. PRICING MODULE\n")
cat("-----------------\n")
paths <- get_example_paths("pricing", "basic")
output <- mock_pricing_module(paths$data)
cat("Purchase rate at $40:", output$price_sensitivity$`40`$purchase_rate, "\n")
cat("Purchase rate at $50:", output$price_sensitivity$`50`$purchase_rate, "\n")
cat("Purchase rate at $60:", output$price_sensitivity$`60`$purchase_rate, "\n")
cat("Purchase rate at $70:", output$price_sensitivity$`70`$purchase_rate, "\n")
cat("Optimal price:", output$optimization$optimal_price, "\n")
cat("Price elasticity (40-50):", output$elasticity$`40_to_50`, "\n")
cat("\n")

cat("================================================================================\n")
cat("Copy these values to the respective golden JSON files\n")
cat("================================================================================\n")
