# Turas Key Driver Analysis - Example Workflows

**Version:** 10.4
**Last Updated:** 20 March 2026

This document provides practical examples and step-by-step workflows for common Key Driver Analysis scenarios.

---

## Table of Contents

1. [Basic Driver Analysis](#workflow-1-basic-driver-analysis)
2. [Weighted Analysis](#workflow-2-weighted-analysis)
3. [SHAP Analysis for Non-Linear Effects](#workflow-3-shap-analysis)
4. [Quadrant Analysis (IPA)](#workflow-4-quadrant-analysis)
5. [Segment Comparison](#workflow-5-segment-comparison)
6. [Handling Multicollinearity](#workflow-6-handling-multicollinearity)
7. [Dual-Importance Analysis](#workflow-7-dual-importance-analysis)
8. [Elastic Net Variable Selection](#workflow-8-elastic-net-variable-selection)
9. [Necessary Condition Analysis](#workflow-9-necessary-condition-analysis)
10. [Dominance Analysis](#workflow-10-dominance-analysis)
11. [GAM Nonlinear Effects](#workflow-11-gam-nonlinear-effects)
12. [Custom Slides in HTML Report](#workflow-12-custom-slides-in-html-report)
13. [Configurable Thresholds](#workflow-13-configurable-thresholds)
14. [Troubleshooting Guide](#troubleshooting-guide)

---

## Workflow 1: Basic Driver Analysis

**Scenario:** Identify what drives customer satisfaction for a retail brand.

### Step 1: Prepare Data

**survey_data.csv:**
```
resp_id | overall_sat | product_quality | service | price_value | delivery | website
1       | 8           | 7               | 9       | 6           | 8        | 7
2       | 9           | 9               | 8       | 8           | 9        | 8
3       | 6           | 5               | 7       | 7           | 6        | 5
4       | 7           | 8               | 6       | 9           | 7        | 6
...
```

### Step 2: Create Configuration

**satisfaction_config.xlsx - Settings sheet:**
```
Setting        | Value
analysis_name  | Customer Satisfaction Drivers
data_file      | survey_data.csv
output_file    | satisfaction_results.xlsx
```

**Variables sheet:**
```
VariableName    | Type    | Label
overall_sat     | Outcome | Overall Satisfaction
product_quality | Driver  | Product Quality
service         | Driver  | Customer Service
price_value     | Driver  | Value for Money
delivery        | Driver  | Delivery Speed
website         | Driver  | Website Experience
```

### Step 3: Run Analysis

```r
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

results <- run_keydriver_analysis(
  config_file = "satisfaction_config.xlsx"
)
```

### Step 4: Interpret Results

**Importance Summary shows:**
```
Driver           | Shapley | Rel.Weight | Beta  | Correlation
Product Quality  | 32.5%   | 31.2%      | 28.4% | 0.72
Customer Service | 26.8%   | 27.5%      | 26.1% | 0.68
Value for Money  | 21.3%   | 22.1%      | 22.3% | 0.58
Delivery Speed   | 12.7%   | 11.9%      | 13.8% | 0.51
Website          | 6.7%    | 7.3%       | 9.4%  | 0.44
```

**Interpretation:**
- Product Quality is #1 driver (32.5%) - highest priority
- Customer Service is #2 (26.8%) - secondary priority
- Methods agree (high consensus) - results are robust
- R² = 0.78 (excellent model fit)

---

## Workflow 2: Weighted Analysis

**Scenario:** Run driver analysis with survey weights to account for sampling design.

### Step 1: Add Weight to Config

**Variables sheet:**
```
VariableName    | Type    | Label
overall_sat     | Outcome | Overall Satisfaction
product_quality | Driver  | Product Quality
service         | Driver  | Customer Service
price_value     | Driver  | Value for Money
survey_weight   | Weight  | Survey Weight
```

### Step 2: Run Analysis

Same as Workflow 1 - weights automatically applied.

### Step 3: Review Weighted Results

**Model Summary shows:**
- Weighted N: 500 (sum of weights)
- Unweighted N: 485 (actual respondents)

**Key Considerations:**
- When using weights, prioritize **Relative Weights** and **SHAP**
- Shapley and Beta have minor weighting inconsistencies
- Compare weighted vs unweighted to assess weight impact

---

## Workflow 3: SHAP Analysis

**Scenario:** Use SHAP to detect non-linear relationships and driver interactions.

### Step 1: Enable SHAP in Settings

```
Setting              | Value
analysis_name        | Satisfaction Drivers with SHAP
data_file            | survey_data.csv
output_file          | shap_results.xlsx
enable_shap          | TRUE
n_trees              | 100
max_depth            | 6
include_interactions | TRUE
```

### Step 2: Install Required Packages

```r
install.packages(c("xgboost", "shapviz", "ggplot2"))
```

### Step 3: Run Analysis

```r
results <- run_keydriver_analysis(config_file = "shap_config.xlsx")

# Access SHAP results
print(results$shap$importance)
```

### Step 4: Interpret SHAP Results

**Compare SHAP vs Shapley:**
```
Driver           | Shapley | SHAP
Product Quality  | 32.5%   | 35.2%
Customer Service | 26.8%   | 22.8%
Value for Money  | 21.3%   | 18.5%
```

**If SHAP differs significantly:**
- Non-linear relationships present
- Interactions between drivers detected
- SHAP may be more accurate for complex relationships

**Beeswarm Plot Interpretation:**
- Red points (high values) on right → Positive relationship
- Blue points (low values) on right → Negative relationship
- Wide spread → Variable effect depends on value
- Narrow spread → Linear relationship

### Step 5: Review Interactions

**SHAP_Interactions sheet shows:**
```
Driver 1         | Driver 2     | Interaction
Product Quality  | Service      | 0.023
Price Value      | Product      | 0.018
```

**Interpretation:** Moderate interaction between Quality and Service - their combined effect is greater than sum of individual effects.

---

## Workflow 4: Quadrant Analysis (IPA)

**Scenario:** Create actionable quadrant charts for strategic planning.

### Step 1: Enable Quadrant in Settings

```
Setting            | Value
analysis_name      | Satisfaction Drivers IPA
data_file          | survey_data.csv
output_file        | ipa_results.xlsx
enable_quadrant    | TRUE
importance_source  | auto
threshold_method   | mean
normalize_axes     | TRUE
```

### Step 2: Run Analysis

```r
results <- run_keydriver_analysis(config_file = "ipa_config.xlsx")
```

### Step 3: Interpret Quadrant Results

**Quadrant_Summary sheet:**
```
Driver           | Importance | Performance | Quadrant
Product Quality  | 32.5       | 6.2         | Q1 (Concentrate Here)
Customer Service | 26.8       | 7.8         | Q2 (Keep Up Good Work)
Value for Money  | 21.3       | 5.5         | Q1 (Concentrate Here)
Delivery Speed   | 12.7       | 7.2         | Q3 (Low Priority)
Website          | 6.7        | 8.1         | Q4 (Possible Overkill)
```

### Step 4: Take Action

| Quadrant | Drivers | Action |
|----------|---------|--------|
| Q1 (Red) | Product Quality, Value for Money | **IMPROVE** - Priority investment |
| Q2 (Green) | Customer Service | **MAINTAIN** - Protect current performance |
| Q3 (Gray) | Delivery Speed | **MONITOR** - Low priority |
| Q4 (Yellow) | Website | **REASSESS** - May be over-investing |

### Step 5: Review Gap Analysis

**Gap_Analysis sheet:**
```
Driver           | Gap Score | Recommendation
Product Quality  | +26.3     | Top priority - large positive gap
Value for Money  | +15.8     | High priority
Customer Service | +19.0     | Monitor - performing well
Website          | -1.4      | Potential overkill
```

**Gap = Importance - Performance (normalized)**
- Positive gap = Underperforming relative to importance
- Negative gap = Overperforming relative to importance

---

## Workflow 5: Segment Comparison

**Scenario:** Compare driver importance across NPS segments (Promoters vs Detractors).

### Step 1: Add Segments Sheet

**Segments sheet:**
```
segment_name | segment_variable | segment_values
Promoters    | nps_group        | Promoter
Passives     | nps_group        | Passive
Detractors   | nps_group        | Detractor
```

### Step 2: Run Analysis

```r
results <- run_keydriver_analysis(config_file = "segment_config.xlsx")
```

### Step 3: Compare Segment Results

**Segment comparison shows:**
```
Driver           | Total | Promoters | Detractors
Product Quality  | 32.5% | 28.2%     | 38.1%
Customer Service | 26.8% | 30.5%     | 22.3%
Value for Money  | 21.3% | 18.8%     | 25.6%
```

**Interpretation:**
- **Detractors** care more about Product Quality (38% vs 28%)
- **Promoters** care more about Service (31% vs 22%)
- **Detractors** are more price-sensitive (26% vs 19%)

### Step 4: Tailor Strategies

| Segment | Focus On | Rationale |
|---------|----------|-----------|
| Promoters | Customer Service | Their top driver |
| Detractors | Product Quality, Price | Their pain points |
| Passives | Balanced approach | No strong preferences |

---

## Workflow 6: Handling Multicollinearity

**Scenario:** VIF diagnostics show high multicollinearity - how to address it.

### Step 1: Identify Problem

**Model Summary VIF section:**
```
Driver           | VIF  | Status
Product Quality  | 2.3  | OK
Brand Reputation | 12.4 | HIGH (>10)
Brand Trust      | 11.8 | HIGH (>10)
Customer Service | 3.1  | OK
```

### Step 2: Diagnose Cause

**Check correlation matrix:**
```
                 | Brand Reputation | Brand Trust
Brand Reputation | 1.00             | 0.92
Brand Trust      | 0.92             | 1.00
```

**Problem:** Brand Reputation and Brand Trust are highly correlated (r = 0.92)

### Step 3: Solutions

**Option A: Remove one driver**
```
# Remove Brand Trust from Variables sheet
# Re-run analysis
```

**Option B: Combine drivers**
```r
# Create composite before analysis
data$brand_overall <- (data$brand_reputation + data$brand_trust) / 2

# Update config to use brand_overall instead
```

**Option C: Trust robust methods**
```
# If keeping both drivers:
# Trust Shapley and Relative Weights (handle collinearity)
# Don't trust Beta Weights (unstable)
```

### Step 4: Verify Fix

After removing Brand Trust:
```
Driver           | VIF  | Status
Product Quality  | 2.3  | OK
Brand Reputation | 3.8  | OK
Customer Service | 3.1  | OK
```

All VIF < 5 - multicollinearity resolved.

---

## Workflow 7: Dual-Importance Analysis

**Scenario:** Compare statistical (derived) importance vs. what customers say matters (stated importance).

### Step 1: Add StatedImportance Sheet

Survey included: "How important is each factor to you?" (0-100 scale)

**StatedImportance sheet:**
```
driver           | stated_importance
product_quality  | 85
customer_service | 78
delivery_speed   | 65
price_value      | 92
website_ease     | 45
```

### Step 2: Enable Quadrant with Stated Importance

```
Setting            | Value
enable_quadrant    | TRUE
use_stated_importance | TRUE
```

### Step 3: Interpret Dual-Importance Matrix

**Results:**
```
Driver           | Derived  | Stated | Gap   | Category
Product Quality  | 32.5%    | 85     | -52.5 | As Expected
Price Value      | 21.3%    | 92     | -70.7 | FALSE PRIORITY
Customer Service | 26.8%    | 78     | -51.2 | As Expected
Delivery Speed   | 12.7%    | 65     | -52.3 | As Expected
Website          | 6.7%     | 45     | -38.3 | HIDDEN GEM
```

**Interpretation:**
- **Price Value (False Priority):** Customers SAY it matters a lot (92), but it doesn't actually drive satisfaction (21%). May need to adjust messaging.
- **Website (Hidden Gem):** Low stated importance (45) but actually drives satisfaction. Customers undervalue this.

---

## Workflow 8: Elastic Net Variable Selection

**Scenario:** You have many candidate drivers (15+) and want to automatically identify which ones truly matter, removing noise variables before interpreting importance.

### Step 1: Enable Elastic Net in Settings

**Settings sheet:**
```
Setting              | Value
analysis_name        | Satisfaction Drivers - Elastic Net Selection
data_file            | survey_data.csv
output_file          | elastic_net_results.xlsx
enable_elastic_net   | TRUE
elastic_net_alpha    | 0.5
elastic_net_nfolds   | 10
```

**Key parameters:**
- `enable_elastic_net` - Activates elastic net regularization
- `elastic_net_alpha` - Mixing parameter (0 = ridge, 1 = lasso, 0.5 = balanced elastic net)
- `elastic_net_nfolds` - Number of cross-validation folds for lambda selection

### Step 2: Run Analysis

```r
results <- run_keydriver_analysis(config_file = "elastic_net_config.xlsx")

# Access elastic net results
print(results$elastic_net$retained_drivers)
print(results$elastic_net$coefficients)
```

### Step 3: Interpret Results

**ElasticNet_Summary sheet:**
```
Driver           | Coefficient | Status
Product Quality  | 0.312       | Retained
Customer Service | 0.245       | Retained
Value for Money  | 0.189       | Retained
Delivery Speed   | 0.074       | Retained
Website          | 0.000       | Zeroed Out
Brand Awareness  | 0.000       | Zeroed Out
Social Media     | 0.000       | Zeroed Out
```

**Lambda selection:**
```
Lambda Method | Lambda Value | Drivers Retained | CV Error
lambda.min    | 0.0032       | 6                | 0.421
lambda.1se    | 0.0187       | 4                | 0.438
```

### Step 4: Interpretation Tips

- **Retained drivers** (non-zero coefficients) are the ones elastic net identifies as genuinely contributing to the outcome
- **Zeroed out drivers** have been shrunk to exactly zero - they add noise, not signal
- **lambda.1se** (default) gives a more parsimonious model - fewer drivers, slightly higher error but more robust
- **lambda.min** retains more drivers but risks overfitting
- **Coefficient magnitudes** indicate relative strength among retained drivers
- **Alpha = 0.5** balances between grouping correlated drivers (ridge) and selecting among them (lasso)
- After elastic net selection, the remaining analysis methods (Shapley, Relative Weights) run only on retained drivers

---

## Workflow 9: Necessary Condition Analysis

**Scenario:** Identify which drivers are necessary conditions for achieving high satisfaction - drivers where a minimum level is required before high outcomes are even possible.

### Step 1: Enable NCA in Settings

**Settings sheet:**
```
Setting        | Value
analysis_name  | Satisfaction Drivers - NCA
data_file      | survey_data.csv
output_file    | nca_results.xlsx
enable_nca     | TRUE
```

### Step 2: Run Analysis

```r
results <- run_keydriver_analysis(config_file = "nca_config.xlsx")

# Access NCA results
print(results$nca$effect_sizes)
print(results$nca$bottleneck)
```

### Step 3: Interpret Effect Sizes

**NCA_Effects sheet:**
```
Driver           | Effect Size | Is Necessary
Product Quality  | 0.42        | YES
Customer Service | 0.31        | YES
Value for Money  | 0.18        | YES
Delivery Speed   | 0.08        | No
Website          | 0.05        | No
```

**Effect size interpretation:**
- **> 0.3** - Large necessary condition (driver is a strong gatekeeper)
- **0.1 - 0.3** - Medium necessary condition
- **< 0.1** - Not a meaningful necessary condition

### Step 4: Read the Bottleneck Table

**NCA_Bottleneck sheet (minimum driver levels needed for target outcome levels):**
```
Target Outcome | Product Quality | Customer Service | Value for Money
50%            | 30%             | 20%              | 10%
60%            | 45%             | 35%              | 25%
70%            | 55%             | 50%              | 40%
80%            | 70%             | 60%              | 55%
90%            | 85%             | 75%              | 70%
```

### Step 5: Interpretation Tips

- **Necessary ≠ Sufficient.** A necessary driver must be at a minimum level for high outcomes, but improving it alone may not increase outcomes
- **Bottleneck table is actionable:** To achieve 80% satisfaction, Product Quality must be at least 70% - this is a floor, not a target
- **Drivers that are necessary but not sufficient** should be treated as hygiene factors - maintain them above the threshold
- **NCA complements standard importance:** A driver may have low derived importance but be a strict necessary condition
- Use NCA alongside Shapley/Relative Weights for a complete picture of which drivers are gatekeepers vs. differentiators

---

## Workflow 10: Dominance Analysis

**Scenario:** Determine which drivers dominate others across all possible sub-model comparisons, providing the most robust importance ranking available.

### Step 1: Enable Dominance in Settings

**Settings sheet:**
```
Setting            | Value
analysis_name      | Satisfaction Drivers - Dominance
data_file          | survey_data.csv
output_file        | dominance_results.xlsx
enable_dominance   | TRUE
```

**Note:** Dominance analysis is limited to 15 drivers maximum (it evaluates all possible sub-models). Weights are supported.

### Step 2: Run Analysis

```r
results <- run_keydriver_analysis(config_file = "dominance_config.xlsx")

# Access dominance results
print(results$dominance$general)
print(results$dominance$conditional)
print(results$dominance$complete)
```

### Step 3: Interpret Results

**Dominance_General sheet (average additional R² across all sub-models):**
```
Driver           | General Dominance | Rank
Product Quality  | 0.182             | 1
Customer Service | 0.156             | 2
Value for Money  | 0.114             | 3
Delivery Speed   | 0.068             | 4
Website          | 0.034             | 5
```

**Dominance_Conditional sheet (dominance within model sizes):**
```
Driver           | 1-driver | 2-driver | 3-driver | 4-driver
Product Quality  | 0.210    | 0.185    | 0.170    | 0.162
Customer Service | 0.178    | 0.160    | 0.148    | 0.138
Value for Money  | 0.125    | 0.118    | 0.110    | 0.103
```

**Dominance_Complete sheet (pairwise dominance matrix):**
```
                 | Product Quality | Customer Service | Value for Money
Product Quality  | -               | Dominates        | Dominates
Customer Service | Dominated       | -                | Dominates
Value for Money  | Dominated       | Dominated        | -
```

### Step 4: Interpretation Tips

- **General dominance** is the average incremental R² a driver contributes across all possible sub-models - the most stable importance metric
- **Conditional dominance** shows importance at each model size (1-driver, 2-driver, etc.) - if a driver's conditional dominance is always higher than another's, it completely dominates
- **Complete dominance** is the strictest test: Driver A completely dominates Driver B only if A's incremental contribution exceeds B's in every single sub-model
- General dominance values sum to the total model R² - they partition explained variance exactly
- When Shapley and dominance agree, you can be highly confident in the ranking
- Dominance analysis handles multicollinearity naturally, similar to Shapley values

---

## Workflow 11: GAM Nonlinear Effects

**Scenario:** Detect whether driver-outcome relationships are truly linear, or whether some drivers have diminishing returns, thresholds, or U-shaped effects.

### Step 1: Enable GAM in Settings

**Settings sheet:**
```
Setting        | Value
analysis_name  | Satisfaction Drivers - GAM Nonlinearity
data_file      | survey_data.csv
output_file    | gam_results.xlsx
enable_gam     | TRUE
gam_k          | 5
```

**Key parameters:**
- `enable_gam` - Activates Generalized Additive Model analysis
- `gam_k` - Maximum basis dimension for smoothing splines (default 5; higher values allow more complex curves)

### Step 2: Run Analysis

```r
results <- run_keydriver_analysis(config_file = "gam_config.xlsx")

# Access GAM results
print(results$gam$edf_summary)
print(results$gam$shape_classifications)
print(results$gam$model_comparison)
```

### Step 3: Interpret EDF Values

**GAM_Effects sheet:**
```
Driver           | EDF   | Shape          | Nonlinear?
Product Quality  | 1.02  | Linear         | No
Customer Service | 2.84  | Diminishing    | YES
Value for Money  | 1.15  | Linear         | No
Delivery Speed   | 3.21  | Threshold      | YES
Website          | 1.88  | Slight Curve   | Borderline
```

**EDF (Effective Degrees of Freedom) interpretation:**
- **EDF ≈ 1.0** - Relationship is linear (straight line)
- **EDF 1.0 - 1.5** - Essentially linear, minor curvature
- **EDF > 1.5** - Meaningfully nonlinear, investigate the shape
- **EDF approaching k** - May need higher `gam_k` to capture full complexity

### Step 4: Review Shape Classifications

- **Linear** - Straight-line relationship; standard regression is appropriate
- **Diminishing** - Returns flatten at higher driver levels (most common nonlinear shape in satisfaction research)
- **Threshold** - Little effect until a critical level, then strong effect
- **U-shaped** - High satisfaction at both extremes, low in middle (rare but important)
- **Inverted-U** - Optimal midpoint, declining at extremes

### Step 5: Compare Linear vs GAM Fit

**GAM_ModelComparison sheet:**
```
Metric              | Linear Model | GAM Model
R²                  | 0.78         | -
Deviance Explained  | -            | 83.2%
AIC                 | 1245         | 1198
```

### Step 6: Interpretation Tips

- If linear R² and GAM deviance explained are close (within 2-3 percentage points), nonlinearity is negligible - stick with linear interpretation
- Large gaps suggest important nonlinear effects that standard importance methods may miss
- For drivers with diminishing returns, the practical implication is that further improvement yields less benefit - focus investment elsewhere
- For threshold effects, the action is clear: ensure the driver is above the threshold level
- GAM results complement NCA - a threshold effect in GAM often aligns with a necessary condition in NCA
- Use `gam_k = 5` for most surveys; increase to 8-10 only with large samples (n > 500) and many scale points

---

## Workflow 12: Custom Slides in HTML Report

**Scenario:** Add bespoke narrative slides to the HTML report for executive commentary, methodology notes, or custom visualizations.

### Step 1: Add CustomSlides Sheet to Config

Add a new sheet called **CustomSlides** to your configuration Excel file:

```
slide_title          | slide_content                                              | slide_image           | slide_order
Executive Summary    | ## Key Findings\n\nProduct quality is the dominant driver. | summary_chart.png     | 1
Methodology Note     | Analysis uses Shapley values with 10 drivers.\n\n...       |                       | 2
Regional Comparison  | ## Regional View\n\nSee attached chart for breakdown.      | regional_chart.png    | 3
```

**Column definitions:**
- `slide_title` - Title displayed at the top of the slide
- `slide_content` - Markdown-formatted text content (supports headers, bullets, bold, italics)
- `slide_image` - Optional file path to an image (PNG/JPG) to include on the slide; leave blank for text-only slides
- `slide_order` - Numeric order for slide positioning within the Pinned Views panel

### Step 2: Run Analysis

```r
results <- run_keydriver_analysis(config_file = "custom_slides_config.xlsx")
```

### Step 3: View in HTML Report

Custom slides appear in the **Pinned Views** panel of the HTML report, ordered by `slide_order`. They sit alongside any auto-generated pinned views.

### Step 4: Tips

- **Markdown support:** Use `##` for sub-headers, `**bold**` for emphasis, `-` for bullet lists
- **Newlines:** Use `\n` in the Excel cell to create line breaks in the rendered markdown
- **Images:** Provide paths relative to the config file location, or use absolute paths; supported formats are PNG and JPG
- **Slide order:** Custom slides are interleaved with auto-generated content based on `slide_order` values; use decimals (e.g., 1.5) to position between existing slides
- **No limit:** Add as many custom slides as needed, but keep content concise for readability

---

## Workflow 13: Configurable Thresholds

**Scenario:** Override default VIF thresholds, effect size benchmarks, and other diagnostic cut-offs to match your organization's standards or research context.

### Step 1: Add Threshold Overrides to Settings

**Settings sheet:**
```
Setting                | Value
analysis_name          | Satisfaction Drivers - Custom Thresholds
data_file              | survey_data.csv
output_file            | custom_threshold_results.xlsx
vif_moderate_threshold | 3
vif_high_threshold     | 7
```

**Available threshold settings:**
- `vif_moderate_threshold` - VIF level triggering "Monitor" status (default: 5)
- `vif_high_threshold` - VIF level triggering "High/Remove" status (default: 10)

### Step 2: Run Analysis

```r
results <- run_keydriver_analysis(config_file = "custom_thresholds_config.xlsx")
```

### Step 3: Review Adjusted Diagnostics

**With custom thresholds (vif_moderate = 3, vif_high = 7):**
```
Driver           | VIF  | Status (Custom) | Status (Default)
Product Quality  | 2.3  | OK              | OK
Brand Reputation | 4.8  | MODERATE        | OK
Customer Service | 3.1  | MODERATE        | OK
Brand Trust      | 8.2  | HIGH            | MODERATE
```

Notice how the stricter thresholds flag Brand Reputation and Customer Service as moderate concerns, while Brand Trust escalates from moderate to high.

### Step 4: Interpretation Tips

- **Stricter VIF thresholds** (lower values) are appropriate when you need highly stable beta weights or when presenting regression coefficients directly
- **Relaxed VIF thresholds** (higher values) may be acceptable when relying primarily on Shapley values or Relative Weights, which handle collinearity better
- **Academic standard** is typically VIF > 10 for concern; **applied research** often uses VIF > 5
- **Effect size benchmarks** follow Cohen's conventions by default (small = 0.1, medium = 0.3, large = 0.5) but can be adjusted for domain-specific norms
- Document any threshold changes in your report methodology section so readers understand the diagnostic criteria applied
- Custom thresholds affect diagnostic flags and recommendations but do not change the underlying statistical computations

---

## Troubleshooting Guide

### Issue: "Insufficient complete cases"

**Error:** `Insufficient complete cases (45). Need at least 60.`

**Cause:** Not enough data after removing missing values.

**Solutions:**
1. Reduce drivers: Focus on 3-5 most important
2. Get more data
3. Impute missing values externally
4. Check which variables have most missingness

**Diagnostic:**
```r
# Check missingness
colSums(is.na(data[, driver_vars]))
```

---

### Issue: "Aliased/NA coefficients"

**Error:** `Drivers have aliased coefficients: brand_trust, brand_reputation`

**Cause:** Perfect multicollinearity - drivers are perfectly correlated.

**Solutions:**
1. Check correlation: `cor(data$brand_trust, data$brand_reputation)`
2. If r > 0.95, remove one or combine
3. If same concept, use only one measure

---

### Issue: "Too many drivers"

**Error:** `Too many drivers (18) for exact Shapley.`

**Cause:** Shapley requires 2^k models; 2^18 is impractical.

**Solutions:**
1. Pre-screen: Keep top 12-15 correlated with outcome
2. Combine related drivers into composites
3. Use two-stage: Screen with correlation, full analysis on top 12

**Pre-screening approach:**
```r
# Calculate correlations with outcome
cors <- cor(data[, driver_vars], data$outcome)

# Keep top 12 by absolute correlation
top_12 <- names(sort(abs(cors), decreasing = TRUE))[1:12]
```

---

### Issue: High VIF warnings

**Warning:** `High VIF detected: brand_reputation (VIF=12.4)`

**Impact:** Beta weights unreliable for this driver.

**Solutions:**
1. Check correlation matrix for highly correlated pairs
2. Remove one of the correlated drivers
3. Combine into composite
4. Trust Shapley/Relative Weights over Beta

---

### Issue: Methods disagree substantially

**Symptom:** Shapley rank = 2, Beta rank = 8

**Likely Cause:** Multicollinearity

**Diagnostic:**
```
# Check VIF for disagreeing drivers
# Look for VIF > 5
```

**Solution:**
1. Trust Shapley values
2. Investigate VIF
3. Consider removing high-VIF drivers

---

### Issue: Low R² (<0.30)

**Observation:** Model R² = 0.25

**Meaning:** Drivers explain only 25% of outcome variance.

**Possible Causes:**
1. Missing important drivers
2. Non-linear relationships
3. Measurement error
4. Outcome has low variance

**Solutions:**
1. Add more drivers (conceptual review)
2. Enable SHAP for non-linear detection
3. Check outcome variable distribution
4. Accept limitation if conceptually complete

---

### Issue: SHAP analysis failed

**Error:** `Package 'xgboost' required`

**Solution:**
```r
install.packages(c("xgboost", "shapviz", "ggplot2"))
```

**Error:** `SHAP analysis failed - singular matrix`

**Cause:** Usually highly correlated drivers.

**Solution:** Remove highly correlated drivers (r > 0.90)

---

### Issue: All correlations negative

**Observation:** All drivers have negative correlations with outcome.

**Likely Cause:** Reverse-coded outcome or drivers.

**Solution:**
1. Check scale direction: Higher = better?
2. Reverse-code if needed: `data$outcome <- max(data$outcome) - data$outcome + min(data$outcome)`

---

## Quick Reference

### Sample Size Requirements

| Drivers | Minimum n |
|---------|-----------|
| 3-5 | 50 |
| 6-8 | 80 |
| 9-12 | 120 |
| 13-15 | 150 |

### VIF Thresholds

| VIF | Action |
|-----|--------|
| < 5 | OK |
| 5-10 | Monitor |
| > 10 | Remove/combine |

### Method Priority

| Situation | Use |
|-----------|-----|
| General | Shapley |
| High VIF | Shapley, Relative Weights |
| Non-linear | SHAP |
| Small n | Relative Weights |
| Weights | Relative Weights, SHAP |

### Importance Thresholds

| Shapley | Interpretation |
|---------|----------------|
| > 25% | Dominant |
| 15-25% | Major |
| 10-15% | Moderate |
| 5-10% | Minor |
| < 5% | Marginal |

---

## Additional Resources

- [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods reference
- [04_USER_MANUAL.md](04_USER_MANUAL.md) - Complete user guide
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Template field reference
