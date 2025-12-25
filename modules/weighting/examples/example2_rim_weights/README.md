# Example 2: Rim Weighting with survey::calibrate()

## Overview

This example demonstrates **rim weighting (raking)** using `survey::calibrate()` for a sample that needs demographic adjustment to match population targets.

## What This Example Shows

- How to use survey::calibrate() for rim weighting (v2.0)
- Proper Weight_Config.xlsx structure for rim weights
- Multiple demographic variables (Age, Gender, Region)
- Weight bounds applied **during** calibration (not after)
- Multiple calibration methods available

## Files in This Example

- `sample_data.csv` - Sample survey data (30 respondents)
- `create_config.R` - Script to create Weight_Config.xlsx
- `README.md` - This file

## Quick Start

### Step 1: Create the Config File

```r
setwd("modules/weighting/examples/example2_rim_weights")
source("create_config.R")
```

This creates `Weight_Config.xlsx` with proper v2.0 structure.

### Step 2: Run the Weighting

```r
source("../../run_weighting.R")
result <- run_weighting("Weight_Config.xlsx")

# View results
head(result$data)
print(result$weight_results$population_weight$diagnostics)
```

## Sample Data Structure

The `sample_data.csv` has 30 respondents with:

**Variables:**
- `ResponseID`: Unique identifier
- `Age`: 18-34, 35-54, 55+ (3 categories)
- `Gender`: Male, Female (2 categories)
- `Region`: Urban, Suburban, Rural (3 categories)
- `Q1`, `Q2`, `Q3`: Survey responses

**Sample Distribution (before weighting):**
- Sample is biased toward younger, female, urban respondents
- Rim weighting will adjust to match population targets

## Population Targets

As configured in Rim_Targets sheet:

### Age Distribution
| Category | Target % |
|----------|----------|
| 18-34    | 30%      |
| 35-54    | 40%      |
| 55+      | 30%      |

### Gender Distribution
| Category | Target % |
|----------|----------|
| Male     | 48%      |
| Female   | 52%      |

### Region Distribution
| Category | Target % |
|----------|----------|
| Urban    | 35%      |
| Suburban | 45%      |
| Rural    | 20%      |

## Advanced Settings (v2.0)

The config uses these v2.0 parameters:

```
calibration_method: "raking"    # Can also be "linear" or "logit"
weight_bounds: "0.3,3.0"        # Bounds applied DURING calibration
max_iterations: 50
convergence_tolerance: 1e-7
```

## Expected Results

After running, you should see:

1. **Convergence:** ✓ Converged successfully
2. **Weight range:** Approximately [0.3, 3.0] (due to bounds)
3. **Achieved margins:** Within 0.01% of targets
4. **Design effect:** Should be < 2.0 (good quality)

## Config File Structure

Your `Weight_Config.xlsx` should have 5 sheets:

### 1. General Sheet
```
| Setting           | Value                      |
|-------------------|----------------------------|
| project_name      | Example2_Rim_Weighting     |
| data_file         | sample_data.csv            |
| output_file       | weighted_data.csv          |
| save_diagnostics  | Y                          |
| diagnostics_file  | diagnostics.txt            |
```

### 2. Weight_Specifications Sheet
```
| weight_name       | method | description                            | apply_trimming |
|-------------------|--------|----------------------------------------|----------------|
| population_weight | rim    | Rim weighting to match population demographics | N              |
```

### 3. Design_Targets Sheet
(Empty - not used for rim weighting)

### 4. Rim_Targets Sheet
```
| weight_name       | variable | category  | target_percent |
|-------------------|----------|-----------|----------------|
| population_weight | Age      | 18-34     | 30             |
| population_weight | Age      | 35-54     | 40             |
| population_weight | Age      | 55+       | 30             |
| population_weight | Gender   | Male      | 48             |
| population_weight | Gender   | Female    | 52             |
| population_weight | Region   | Urban     | 35             |
| population_weight | Region   | Suburban  | 45             |
| population_weight | Region   | Rural     | 20             |
```

**Critical:** Each variable's target_percent must sum to 100!

### 5. Advanced_Settings Sheet (v2.0)
```
| weight_name       | max_iterations | convergence_tolerance | calibration_method | weight_bounds |
|-------------------|----------------|----------------------|-------------------|---------------|
| population_weight | 50             | 1e-7                 | raking            | 0.3,3.0       |
```

## Troubleshooting

### Error: "Variable not found in data"
**Cause:** Variable name in Rim_Targets doesn't match data column name exactly.

**Fix:** Check that `Age`, `Gender`, `Region` exist in `sample_data.csv` (case-sensitive!)

### Error: "Category not found"
**Cause:** Category value in Rim_Targets doesn't exist in data.

**Fix:** Verify all categories exist:
```r
table(data$Age)
table(data$Gender)
table(data$Region)
```

### Error: "Targets don't sum to 100"
**Cause:** target_percent doesn't sum to exactly 100 for each variable.

**Fix:** Verify in Excel:
- Age: 30 + 40 + 30 = 100 ✓
- Gender: 48 + 52 = 100 ✓
- Region: 35 + 45 + 20 = 100 ✓

## What Makes This v2.0?

Key v2.0 features demonstrated:

1. **survey::calibrate()** instead of anesrake
2. **Bounds during calibration** (not post-trimming)
3. **Multiple calibration methods** (raking/linear/logit)
4. **calibration_method parameter** in Advanced_Settings
5. **weight_bounds parameter** format: "lower,upper"

## Experimenting

Try changing these parameters to see effects:

```r
# Try logit calibration (better for bounded weights)
# In Advanced_Settings: calibration_method = "logit"

# Try tighter bounds
# In Advanced_Settings: weight_bounds = "0.5,2.0"

# Try linear calibration (more flexible)
# In Advanced_Settings: calibration_method = "linear"
```

## Next Steps

1. **Understand the output:**
   - Check `weighted_data.csv` for weighted data
   - Review `diagnostics.txt` for quality metrics

2. **Modify for your data:**
   - Replace `sample_data.csv` with your survey data
   - Update Rim_Targets to match your population
   - Adjust variable names to match your columns

3. **See CONFIG_EXAMPLE.md** for comprehensive configuration guide

---

*TURAS Weighting Module v2.0 - Example 2*
