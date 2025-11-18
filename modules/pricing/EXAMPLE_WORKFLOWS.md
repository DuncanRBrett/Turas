# Example Workflows: Turas Pricing Module

Real-world pricing analysis scenarios with step-by-step instructions.

## Example 1: Basic Van Westendorp Analysis

### Scenario

A consumer electronics company is launching a new smart home device and needs to determine the initial price range. They've surveyed 500 target customers (tech-savvy consumers aged 25-45).

### Data

The survey data contains:
- `respondent_id`: Unique identifier
- `q1_too_cheap`: "At what price too cheap?"
- `q2_bargain`: "At what price a bargain?"
- `q3_expensive`: "At what price getting expensive?"
- `q4_too_expensive`: "At what price too expensive?"

### Workflow

#### Step 1: Create Configuration

```r
create_pricing_config(
  output_file = "smart_home_config.xlsx",
  method = "van_westendorp"
)
```

#### Step 2: Configure Excel File

Edit `smart_home_config.xlsx`:

**Settings Sheet:**
- project_name: "Smart Home Device Pricing"
- data_file: "data/smart_home_survey.csv"
- output_file: "results/smart_home_pricing.xlsx"
- currency_symbol: "$"

**VanWestendorp Sheet:**
- col_too_cheap: "q1_too_cheap"
- col_cheap: "q2_bargain"
- col_expensive: "q3_expensive"
- col_too_expensive: "q4_too_expensive"
- calculate_confidence: "TRUE"

#### Step 3: Run Analysis

```r
results <- run_pricing_analysis("smart_home_config.xlsx")
```

#### Step 4: Review Results

```r
# Price points
pp <- results$results$price_points
cat(sprintf("PMC: $%.2f\n", pp$PMC))
cat(sprintf("OPP: $%.2f\n", pp$OPP))
cat(sprintf("IDP: $%.2f\n", pp$IDP))
cat(sprintf("PME: $%.2f\n", pp$PME))

# Confidence intervals
print(results$results$confidence_intervals)

# View plot
print(results$plots$van_westendorp)
```

### Expected Output

```
Price points calculated:
  PMC (Point of Marginal Cheapness): $52.30
  OPP (Optimal Price Point): $74.50
  IDP (Indifference Price Point): $89.20
  PME (Point of Marginal Expensiveness): $118.40
```

### Business Recommendation

Based on the results:
- **Acceptable range**: $52.30 - $118.40
- **Optimal range**: $74.50 - $89.20
- **Recommended price**: $79.99 (middle of optimal range)
- **Premium option**: $99.99 (below PME, captures value seekers)
- **Avoid**: Below $69.99 (quality concerns) or above $119.99 (too expensive)

---

## Example 2: Gabor-Granger Revenue Optimization

### Scenario

A subscription service is repricing its monthly plan. They surveyed 750 existing customers on their willingness to pay at various price points.

### Data

Wide format with purchase intent at 5 price points:
- `customer_id`
- `buy_999` (1=yes, 0=no at $9.99)
- `buy_1499` (1=yes, 0=no at $14.99)
- `buy_1999` (1=yes, 0=no at $19.99)
- `buy_2499` (1=yes, 0=no at $24.99)
- `buy_2999` (1=yes, 0=no at $29.99)

### Workflow

#### Step 1: Create Configuration

```r
create_pricing_config(
  output_file = "subscription_config.xlsx",
  method = "gabor_granger"
)
```

#### Step 2: Configure Excel File

**Settings Sheet:**
- project_name: "Subscription Repricing Study"
- data_file: "data/subscription_survey.csv"
- output_file: "results/subscription_pricing.xlsx"

**GaborGranger Sheet:**
- data_format: "wide"
- price_sequence: "9.99;14.99;19.99;24.99;29.99"
- response_columns: "buy_999;buy_1499;buy_1999;buy_2499;buy_2999"
- calculate_elasticity: "TRUE"
- revenue_optimization: "TRUE"
- confidence_intervals: "TRUE"

#### Step 3: Run Analysis

```r
results <- run_pricing_analysis("subscription_config.xlsx")
```

#### Step 4: Review Results

```r
# Demand curve
print(results$results$demand_curve)

# Optimal price
opt <- results$results$optimal_price
cat(sprintf("Optimal price: $%.2f\n", opt$price))
cat(sprintf("Purchase intent: %.1f%%\n", opt$purchase_intent * 100))
cat(sprintf("Revenue index: %.2f\n", opt$revenue_index))

# Elasticity
print(results$results$elasticity)

# View plots
print(results$plots$demand_curve)
print(results$plots$revenue_curve)
```

### Expected Output

```
Demand Curve:
   price n_respondents n_purchase purchase_intent
1   9.99           750        638           0.851
2  14.99           750        525           0.700
3  19.99           750        390           0.520
4  24.99           750        225           0.300
5  29.99           750        113           0.151

Optimal price: $19.99
Purchase intent: 52.0%
Revenue index: 10.39

Elasticity:
   price_from price_to arc_elasticity elasticity_type
1       9.99    14.99          -0.58       Inelastic
2      14.99    19.99          -1.23         Elastic
3      19.99    24.99          -2.78         Elastic
4      24.99    29.99          -3.95         Elastic
```

### Business Recommendation

- **Optimal price**: $19.99/month (maximizes revenue)
- **Current subscribers**: Expect 52% retention at new price
- **Revenue impact**: Highest revenue index (10.39)
- **Elasticity insight**: Demand is inelastic between $9.99-$14.99, but becomes elastic above $14.99
- **Consider**: Grandfathering existing customers at current rate

---

## Example 3: Multi-Method Comparison

### Scenario

For a major product launch, you want to triangulate your pricing recommendation using both methodologies.

### Workflow

#### Step 1: Create Combined Configuration

```r
create_pricing_config(
  output_file = "combined_config.xlsx",
  method = "both"
)
```

#### Step 2: Configure Both Methods

Your survey needs both question types:
- Four Van Westendorp price perception questions
- Purchase intent at multiple price points

Configure both sheets in the Excel file.

#### Step 3: Run Analysis

```r
results <- run_pricing_analysis("combined_config.xlsx")
```

#### Step 4: Compare Results

```r
# Van Westendorp results
vw <- results$results$van_westendorp
cat(sprintf("VW Acceptable Range: $%.2f - $%.2f\n",
            vw$acceptable_range$lower, vw$acceptable_range$upper))
cat(sprintf("VW Optimal Range: $%.2f - $%.2f\n",
            vw$optimal_range$lower, vw$optimal_range$upper))

# Gabor-Granger results
gg <- results$results$gabor_granger
cat(sprintf("GG Optimal Price: $%.2f\n", gg$optimal_price$price))
cat(sprintf("GG Purchase Intent: %.1f%%\n", gg$optimal_price$purchase_intent * 100))

# Check consistency
gg_price <- gg$optimal_price$price
if (gg_price >= vw$optimal_range$lower && gg_price <= vw$optimal_range$upper) {
  cat("GG optimal price falls within VW optimal range.\n")
} else if (gg_price >= vw$acceptable_range$lower && gg_price <= vw$acceptable_range$upper) {
  cat("GG optimal price falls within VW acceptable range (but outside optimal).\n")
} else {
  cat("WARNING: Methods show inconsistent results - investigate further.\n")
}
```

### Interpretation

When methods agree:
- Strong confidence in the recommendation
- Price is both psychologically acceptable and revenue-optimizing

When methods disagree:
- Van Westendorp shows perception, Gabor-Granger shows behavior
- Consider market positioning (premium vs value)
- May need additional research

---

## Example 4: Segmented Analysis

### Scenario

Analyze pricing separately for different customer segments to develop tiered pricing.

### Workflow

#### Step 1: Run Separate Analyses

```r
# Filter data by segment before analysis
enterprise_data <- full_data[full_data$segment == "Enterprise", ]
smb_data <- full_data[full_data$segment == "SMB", ]

# Save filtered data
write.csv(enterprise_data, "data/enterprise_segment.csv", row.names = FALSE)
write.csv(smb_data, "data/smb_segment.csv", row.names = FALSE)
```

#### Step 2: Create Segment Configurations

Create two config files with different data_file paths:
- `enterprise_config.xlsx` → enterprise_segment.csv
- `smb_config.xlsx` → smb_segment.csv

#### Step 3: Run Both Analyses

```r
enterprise_results <- run_pricing_analysis("enterprise_config.xlsx")
smb_results <- run_pricing_analysis("smb_config.xlsx")
```

#### Step 4: Compare Segments

```r
# Compare Van Westendorp results
enterprise_pp <- enterprise_results$results$price_points
smb_pp <- smb_results$results$price_points

comparison <- data.frame(
  Metric = c("PMC", "OPP", "IDP", "PME"),
  Enterprise = c(enterprise_pp$PMC, enterprise_pp$OPP,
                 enterprise_pp$IDP, enterprise_pp$PME),
  SMB = c(smb_pp$PMC, smb_pp$OPP, smb_pp$IDP, smb_pp$PME)
)
comparison$Difference <- comparison$Enterprise - comparison$SMB

print(comparison)
```

### Business Recommendation

Use segment-specific pricing:
- **Enterprise tier**: Price at segment's OPP-IDP range
- **SMB tier**: Price at segment's OPP-IDP range
- **Price gap**: Maintain meaningful differentiation

---

## Example 5: Handling Data Quality Issues

### Scenario

Your data has monotonicity violations and missing values that need handling.

### Workflow

#### Step 1: Initial Run with Diagnostics

```r
results <- run_pricing_analysis("config.xlsx")

# Check diagnostics
cat(sprintf("Total respondents: %d\n", results$diagnostics$n_total))
cat(sprintf("Valid respondents: %d\n", results$diagnostics$n_valid))
cat(sprintf("Excluded: %d\n", results$diagnostics$n_excluded))
cat(sprintf("Warnings: %d\n", results$diagnostics$n_warnings))

# View warnings
for (w in results$diagnostics$warnings) {
  cat(paste0("- ", w, "\n"))
}
```

#### Step 2: Address Issues

If monotonicity violations are high (>10%):

**Option A: Exclude violations**

In VanWestendorp sheet:
- exclude_violations: "TRUE"
- violation_threshold: "0.10"

**Option B: Review and clean data manually**

```r
# Load data and find violations
data <- read.csv("data/survey.csv")

# Check monotonicity
violations <- with(data, {
  q1_too_cheap > q2_bargain |
  q2_bargain > q3_expensive |
  q3_expensive > q4_too_expensive
})

violation_rows <- data[violations, ]
print(violation_rows)

# Decide: remove, impute, or flag for follow-up
```

#### Step 3: Re-run with Clean Data

```r
results_clean <- run_pricing_analysis("config.xlsx")
```

### Quality Checklist

- [ ] Violations < 10% of sample
- [ ] Missing values < 20% per variable
- [ ] Prices within reasonable range
- [ ] Sample size ≥ 100 per segment

---

## Example 6: Automated Batch Processing

### Scenario

Run pricing analysis for 10 products using consistent methodology.

### Workflow

#### Step 1: Prepare Configurations

Create a config file for each product with consistent settings but different data files.

```r
products <- c("ProductA", "ProductB", "ProductC", ...)

for (product in products) {
  create_pricing_config(
    output_file = sprintf("configs/%s_config.xlsx", product),
    method = "van_westendorp"
  )
  # Then manually edit each with product-specific data_file
}
```

#### Step 2: Batch Run

```r
# Get all config files
config_files <- list.files("configs", pattern = "\\.xlsx$", full.names = TRUE)

# Run all analyses
results_list <- list()
for (config in config_files) {
  product_name <- gsub("_config\\.xlsx$", "", basename(config))
  cat(sprintf("\nProcessing: %s\n", product_name))

  tryCatch({
    results_list[[product_name]] <- run_pricing_analysis(config)
  }, error = function(e) {
    cat(sprintf("ERROR in %s: %s\n", product_name, e$message))
  })
}
```

#### Step 3: Aggregate Results

```r
# Create summary table
summary_table <- do.call(rbind, lapply(names(results_list), function(name) {
  pp <- results_list[[name]]$results$price_points
  data.frame(
    Product = name,
    PMC = pp$PMC,
    OPP = pp$OPP,
    IDP = pp$IDP,
    PME = pp$PME,
    stringsAsFactors = FALSE
  )
}))

print(summary_table)

# Export summary
write.csv(summary_table, "results/batch_summary.csv", row.names = FALSE)
```

---

## Common Patterns

### Loading Results Later

```r
# Results are in the Excel output
# But you can also save the R object
saveRDS(results, "results/analysis_results.rds")

# Load later
results <- readRDS("results/analysis_results.rds")
```

### Custom Plotting

```r
# Access curve data for custom plots
curves <- results$results$curves

# Create custom ggplot
library(ggplot2)
ggplot(curves, aes(x = price)) +
  geom_line(aes(y = too_cheap, color = "Too Cheap")) +
  geom_line(aes(y = too_expensive, color = "Too Expensive")) +
  theme_minimal() +
  labs(title = "Custom Van Westendorp Plot")
```

### Exporting for Other Tools

```r
# Export demand curve for external modeling
write.csv(
  results$results$demand_curve,
  "exports/demand_curve.csv",
  row.names = FALSE
)

# Export to JSON
jsonlite::write_json(
  results$results$price_points,
  "exports/price_points.json"
)
```
