# ==============================================================================
# TURAS PRICING MODULE - COMPREHENSIVE SAMPLE CONFIGURATION
# ==============================================================================
#
# This configuration demonstrates all Phase 1-3 features including:
# - Weighted analysis
# - Profit optimization
# - DK code handling
# - Configurable monotonicity behavior
# - WTP distribution extraction
# - Competitive scenario simulation
# - Constrained price optimization
#
# ==============================================================================

# ==============================================================================
# VAN WESTENDORP CONFIGURATION
# ==============================================================================

vw_config <- list(
  # Basic Settings
  project_name = "Consumer Electronics Pricing Study",
  analysis_method = "van_westendorp",
  currency_symbol = "$",

  # Data Configuration
  data_file = "modules/pricing/test_data_vw.csv",
  id_var = "respondent_id",

  # Van Westendorp Column Mapping
  van_westendorp = list(
    col_too_cheap = "too_cheap",
    col_cheap = "cheap",
    col_expensive = "expensive",
    col_too_expensive = "too_expensive",
    validate_monotonicity = TRUE
  ),

  # PHASE 1: Weighting and Data Quality
  weight_var = "weight",                          # Column containing survey weights
  dk_codes = c(98, 99),                          # "Don't know" codes to recode as NA
  vw_monotonicity_behavior = "flag_only",        # Options: "flag_only", "drop", "fix"

  # PHASE 1: Segmentation
  segment_vars = c("age_group"),                 # Comma-separated or vector

  # Bootstrap Settings
  bootstrap = list(
    enabled = TRUE,
    n_iterations = 1000,
    confidence_level = 0.95,
    method = "percentile"
  ),

  # Validation Settings
  validation = list(
    min_completeness = 0.80,                     # Require 80% of price questions answered
    check_ranges = TRUE,
    min_price = 0,
    max_price = 200
  ),

  # Output Settings
  output = list(
    directory = "output/pricing_vw",
    filename_prefix = "vw_analysis",
    format = "xlsx",                             # "xlsx", "csv", or "both"
    save_plots = TRUE,
    save_data = TRUE
  ),

  # Visualization Settings
  visualization = list(
    generate_plots = TRUE,
    show_range = TRUE,
    show_points = TRUE,
    plot_width = 12,
    plot_height = 8,
    plot_dpi = 300,
    export_format = "png"                        # "png", "pdf", "svg"
  )
)


# ==============================================================================
# GABOR-GRANGER CONFIGURATION WITH PROFIT OPTIMIZATION
# ==============================================================================

gg_config <- list(
  # Basic Settings
  project_name = "SaaS Subscription Pricing Analysis",
  analysis_method = "gabor_granger",
  currency_symbol = "$",

  # Data Configuration
  data_file = "modules/pricing/test_data_gg.csv",
  id_var = "respondent_id",

  # Gabor-Granger Settings
  gabor_granger = list(
    data_format = "wide",                        # "wide" or "long"
    price_sequence = c(25, 30, 35, 40, 45, 50),
    response_columns = c("pi_25", "pi_30", "pi_35", "pi_40", "pi_45", "pi_50"),
    response_coding = "binary",                  # "binary" or "scale"
    revenue_optimization = TRUE
  ),

  # PHASE 1: Weighting
  weight_var = "weight",

  # PHASE 2: Profit Optimization
  unit_cost = 18,                                # Cost per unit for profit calculation

  # PHASE 1: Data Quality
  dk_codes = c(98, 99),
  gg_monotonicity_behavior = "smooth",           # Options: "smooth", "flag_only", "none"

  # PHASE 1: Segmentation
  segment_vars = c("age_group"),

  # Bootstrap Settings
  bootstrap = list(
    enabled = TRUE,
    n_iterations = 1000,
    confidence_level = 0.95,
    method = "percentile"
  ),

  # Validation Settings
  validation = list(
    min_completeness = 0.70,
    check_ranges = TRUE,
    min_price = 0,
    max_price = 100
  ),

  # Output Settings
  output = list(
    directory = "output/pricing_gg",
    filename_prefix = "gg_analysis",
    format = "xlsx",
    save_plots = TRUE,
    save_data = TRUE
  ),

  # Visualization Settings
  visualization = list(
    generate_plots = TRUE,
    plot_width = 12,
    plot_height = 8,
    plot_dpi = 300,
    export_format = "png"
  )
)


# ==============================================================================
# DUAL METHOD CONFIGURATION (VAN WESTENDORP + GABOR-GRANGER)
# ==============================================================================

dual_config <- list(
  # Basic Settings
  project_name = "Comprehensive Pricing Study - VW + GG",
  analysis_method = "both",
  currency_symbol = "$",

  # Data Configuration
  data_file = "path/to/combined_data.csv",
  id_var = "respondent_id",

  # Van Westendorp Configuration
  van_westendorp = list(
    col_too_cheap = "q1_too_cheap",
    col_cheap = "q2_cheap",
    col_expensive = "q3_expensive",
    col_too_expensive = "q4_too_expensive",
    validate_monotonicity = TRUE
  ),

  # Gabor-Granger Configuration
  gabor_granger = list(
    data_format = "wide",
    price_sequence = c(20, 25, 30, 35, 40, 45, 50),
    response_columns = c("pi_20", "pi_25", "pi_30", "pi_35", "pi_40", "pi_45", "pi_50"),
    response_coding = "binary",
    revenue_optimization = TRUE
  ),

  # Weighting and Data Quality
  weight_var = "survey_weight",
  unit_cost = 22,
  dk_codes = c(98, 99, -99),
  vw_monotonicity_behavior = "flag_only",
  gg_monotonicity_behavior = "smooth",

  # Segmentation
  segment_vars = c("age_group", "income_bracket", "region"),

  # Bootstrap
  bootstrap = list(
    enabled = TRUE,
    n_iterations = 2000,
    confidence_level = 0.95,
    method = "percentile"
  ),

  # Validation
  validation = list(
    min_completeness = 0.75,
    check_ranges = TRUE,
    min_price = 0,
    max_price = 150
  ),

  # Output
  output = list(
    directory = "output/pricing_dual",
    filename_prefix = "dual_analysis",
    format = "both",
    save_plots = TRUE,
    save_data = TRUE
  ),

  # Visualization
  visualization = list(
    generate_plots = TRUE,
    show_range = TRUE,
    show_points = TRUE,
    plot_width = 14,
    plot_height = 9,
    plot_dpi = 300,
    export_format = "png"
  )
)


# ==============================================================================
# MINIMAL CONFIGURATION (No weights, no profit, basic features only)
# ==============================================================================

minimal_config <- list(
  project_name = "Quick Pricing Test",
  analysis_method = "van_westendorp",
  currency_symbol = "$",

  data_file = "data/pricing_data.csv",

  van_westendorp = list(
    col_too_cheap = "too_cheap",
    col_cheap = "cheap",
    col_expensive = "expensive",
    col_too_expensive = "too_expensive",
    validate_monotonicity = TRUE
  ),

  # Minimal validation
  validation = list(
    min_completeness = 0.70
  ),

  # Minimal output
  output = list(
    directory = "output",
    format = "xlsx"
  )
)


# ==============================================================================
# USAGE EXAMPLES
# ==============================================================================

# Example 1: Run Van Westendorp with full features
# source("modules/pricing/R/00_main.R")
# vw_results <- run_pricing_analysis(vw_config)

# Example 2: Run Gabor-Granger with profit optimization
# gg_results <- run_pricing_analysis(gg_config)

# Example 3: Run both methods
# dual_results <- run_pricing_analysis(dual_config)

# Example 4: Extract WTP distribution (Phase 3)
# source("modules/pricing/R/07_wtp_distribution.R")
# wtp_data <- extract_wtp_vw(data, vw_config, method = "median")
# wtp_summary <- compute_wtp_summary(wtp_data)
# percentiles <- compute_wtp_percentiles(wtp_data)

# Example 5: Run competitive scenario simulation (Phase 3)
# source("modules/pricing/R/08_competitive_scenarios.R")
# scenarios <- data.frame(
#   our_brand = c(35, 40, 30),
#   competitor_a = c(38, 38, 38),
#   competitor_b = c(32, 32, 32)
# )
# rownames(scenarios) <- c("Base", "Premium", "Value")
# scenario_results <- simulate_scenarios(wtp_data, scenarios,
#                                       scenario_names = rownames(scenarios),
#                                       market_size = 100000)

# Example 6: Constrained optimization (Phase 3)
# source("modules/pricing/R/09_price_volume_optimisation.R")
# optimal_constrained <- find_constrained_optimal(
#   gg_results$revenue_curve,
#   objective = "profit",
#   constraints = list(min_volume = 30000, min_margin_pct = 25),
#   market_size = 100000
# )

# Example 7: Find price for target volume (Phase 3)
# target_price <- find_price_for_volume(
#   gg_results$demand_curve,
#   target_volume = 50000,
#   market_size = 100000
# )


# ==============================================================================
# CONFIGURATION NOTES
# ==============================================================================

# PHASE 1 FEATURES:
# - weight_var: Column name containing survey weights (uses equal weights if NA)
# - dk_codes: Numeric codes to recode as NA (e.g., 98="Don't know", 99="Refused")
# - vw_monotonicity_behavior: How to handle price order violations
#   * "flag_only" (default): Report but don't modify
#   * "drop": Exclude violating respondents
#   * "fix": Automatically sort prices to enforce monotonicity
# - gg_monotonicity_behavior: Demand curve monotonicity
#   * "smooth" (default): Apply isotonic regression
#   * "flag_only": Report only
#   * "none": No checking
# - segment_vars: Variables for subgroup analysis

# PHASE 2 FEATURES:
# - unit_cost: Per-unit cost for profit calculation (revenue - cost)
#   * Enables profit-maximizing price (separate from revenue-maximizing)
#   * Creates profit curves and profit index

# PHASE 3 FEATURES:
# - WTP Distribution: Extract individual-level willingness-to-pay
#   * Use extract_wtp_vw() or extract_wtp_gg()
#   * Compute summary statistics and percentiles
# - Competitive Scenarios: Simulate market share across price scenarios
#   * Use simulate_choice() or simulate_scenarios()
#   * Surplus-based choice model (max WTP - Price)
# - Constrained Optimization: Find optimal price with business constraints
#   * find_constrained_optimal(): Min volume, min profit, margin constraints
#   * find_price_for_volume(): Reverse optimization (volume → price)

# DATA QUALITY BEST PRACTICES:
# 1. Always specify weight_var if using survey weights
# 2. List all DK codes used in your survey
# 3. Choose monotonicity behavior based on data quality expectations
# 4. Set appropriate min_completeness (0.70-0.80 typical)
# 5. Enable bootstrap for confidence intervals (production analyses)

# PROFIT OPTIMIZATION GUIDANCE:
# - Specify unit_cost accurately (variable costs only, not fixed)
# - Revenue-max vs Profit-max can differ significantly
# - Use profit optimization for margin-focused strategies
# - Revenue optimization better for volume/share strategies
