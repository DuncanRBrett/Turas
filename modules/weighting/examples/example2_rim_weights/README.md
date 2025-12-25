# Example 2: Rim Weighting

## Overview

This example demonstrates **rim weighting (raking)** using `survey::calibrate()` for a consumer panel sample that needs demographic adjustment to match population targets.

## What This Example Shows

- Rim weighting with `survey::calibrate()` (v2.0)
- Proper Weight_Config.xlsx structure for rim weights
- Multiple demographic variables (age, gender, region)
- Weight bounds applied **during** calibration (not after)
- Automatic weight trimming
- Comprehensive diagnostics

## Files in This Example

- `data/consumer_panel.csv` - Sample survey data (500 respondents)
- `Weight_Config.xlsx` - Pre-configured weighting setup
- `create_config.R` - Script to recreate Weight_Config.xlsx
- `README.md` - This file

## Quick Start

### Option 1: Use Existing Config (Fastest)

```r
source("modules/weighting/run_weighting.R")
result <- run_weighting("examples/example2_rim_weights/Weight_Config.xlsx")

# View results
head(result$data)
print(result$weight_results$population_weight$diagnostics)
```

### Option 2: Recreate Config from Scratch

```r
setwd("modules/weighting/examples/example2_rim_weights")
source("create_config.R")
source("../../run_weighting.R")
result <- run_weighting("Weight_Config.xlsx")
```

## Sample Data Structure

The `consumer_panel.csv` has 500 respondents with:

**Demographics:**
- `age`: 18-24, 25-34, 35-44, 45-54, 55-64, 65+ (6 categories)
- `gender`: Male, Female (2 categories)
- `region`: Urban, Suburban, Rural (3 categories)

**Survey Responses:**
- `income`: Income bracket
- `brand_preference`: Preferred brand
- `purchase_intent`: Purchase likelihood
- `satisfaction`: Satisfaction rating

**Sample Characteristics:**
- Sample is biased toward certain age groups and regions
- Rim weighting adjusts to match population demographics

## Population Targets

As configured in Rim_Targets sheet:

### Age Distribution
| Category | Target % |
|----------|----------|
| 18-24    | 13%      |
| 25-34    | 18%      |
| 35-44    | 17%      |
| 45-54    | 17%      |
| 55-64    | 16%      |
| 65+      | 19%      |

### Gender Distribution
| Category | Target % |
|----------|----------|
| Male     | 49%      |
| Female   | 51%      |

### Region Distribution
| Category | Target % |
|----------|----------|
| Urban    | 35%      |
| Suburban | 45%      |
| Rural    | 20%      |

## Advanced Settings (v2.0)

The config uses these v2.0 parameters:

```
calibration_method: "raking"         # Can also be "linear" or "logit"
weight_bounds: "0.1,10.0"            # Wide bounds for convergence
max_iterations: 100
convergence_tolerance: 1e-7
```

**Note on weight_bounds:** Wider bounds (0.1, 10.0) allow the calibration algorithm to converge. After calibration, weights are trimmed to [0.63, 4.0] for stability.

## Expected Results

After running, you should see:

1. **Convergence:** ✓ Converged successfully
2. **Weight range before trimming:** [0.63, 9.51]
3. **Weight range after trimming:** [0.63, 4.00]
4. **Achieved margins:** Within 0.0001% of targets (essentially perfect)
5. **Design effect:** ~1.31 (good quality)
6. **Effective N:** ~382 (76% efficiency)
7. **Quality status:** GOOD

## Config File Structure

Your `Weight_Config.xlsx` has 5 sheets:

### 1. General Sheet
```
Setting              Value
-----------------------------------------------------------------
project_name         Consumer_Panel_Study
data_file            data/consumer_panel.csv
output_file          output/consumer_panel_weighted.csv
save_diagnostics     Y
diagnostics_file     output/diagnostics.txt
```

**File format options:**
- data_file: .csv, .xlsx, .xls, .sav
- output_file: .csv, .xlsx
- diagnostics_file: .txt, .xlsx

### 2. Weight_Specifications Sheet
```
weight_name       | method | description                  | apply_trimming | trim_method | trim_value
------------------|--------|------------------------------|----------------|-------------|------------
population_weight | rim    | Population demographics      | Y              | cap         | 4
```

### 3. Design_Targets Sheet
(Empty - not used for rim weighting)

### 4. Rim_Targets Sheet
```
weight_name       | variable | category  | target_percent
------------------|----------|-----------|----------------
population_weight | age      | 18-24     | 13
population_weight | age      | 25-34     | 18
population_weight | age      | 35-44     | 17
population_weight | age      | 45-54     | 17
population_weight | age      | 55-64     | 16
population_weight | age      | 65+       | 19
population_weight | gender   | Male      | 49
population_weight | gender   | Female    | 51
population_weight | region   | Urban     | 35
population_weight | region   | Suburban  | 45
population_weight | region   | Rural     | 20
```

**Critical:** Each variable's target_percent must sum to 100!

### 5. Advanced_Settings Sheet (v2.0)
```
weight_name       | max_iterations | convergence_tolerance | calibration_method | weight_bounds
------------------|----------------|----------------------|-------------------|---------------
population_weight | 100            | 1e-7                 | raking            | 0.1,10.0
```

## What Makes This v2.0?

Key v2.0 features demonstrated:

1. **survey::calibrate()** instead of anesrake
   - Modern, actively maintained package
   - Better control over convergence

2. **Bounds during calibration** (not post-trimming)
   - Calibration respects weight limits
   - More mathematically sound than post-hoc trimming

3. **Multiple calibration methods**
   - raking: Standard iterative proportional fitting
   - linear: More flexible, allows negative weights
   - logit: Best for bounded weights

4. **Better convergence control**
   - More iterations available
   - Clearer convergence criteria
   - Better error messages

## Troubleshooting

### Error: "Did not converge"
**Cause:** Weight bounds too restrictive or targets impossible to achieve.

**Fix:**
1. Widen weight_bounds (e.g., "0.05,20.0")
2. Increase max_iterations (e.g., 200)
3. Try calibration_method = "linear"
4. Check if target combinations are realistic

### Error: "Variable not found in data"
**Cause:** Variable name in Rim_Targets doesn't match data column name exactly.

**Fix:** Check that `age`, `gender`, `region` exist in data (case-sensitive!)

```r
data <- read.csv("data/consumer_panel.csv")
names(data)  # Check exact column names
```

### Error: "Category not found"
**Cause:** Category value in Rim_Targets doesn't exist in data.

**Fix:** Verify all categories exist:
```r
table(data$age)
table(data$gender)
table(data$region)
```

### Error: "Targets don't sum to 100"
**Cause:** target_percent doesn't sum to exactly 100 for each variable.

**Fix:** Verify in Excel or R:
```r
library(readxl)
rim <- read_excel("Weight_Config.xlsx", sheet = "Rim_Targets")
tapply(rim$target_percent, rim$variable, sum)
# Should show: age=100, gender=100, region=100
```

## Experimenting

Try changing these parameters to see effects:

### Different calibration methods
```r
# In Advanced_Settings:
calibration_method = "logit"    # Better handles bounded weights
calibration_method = "linear"   # More flexible convergence
```

### Different weight bounds
```r
# In Advanced_Settings:
weight_bounds = "0.5,2.0"    # Tighter bounds (may not converge)
weight_bounds = "0.2,5.0"    # Moderate bounds
```

### Different file formats
```r
# In General sheet:
data_file = "data/consumer_panel.xlsx"
output_file = "output/consumer_panel_weighted.xlsx"
diagnostics_file = "output/diagnostics.xlsx"
```

## Output Files

After running, check the output directory:

- `consumer_panel_weighted.csv` - Data with `population_weight` column added
- `diagnostics.txt` - Detailed diagnostics report

Or if using .xlsx formats:
- `consumer_panel_weighted.xlsx` - Excel file with weighted data
- `diagnostics.xlsx` - Excel workbook with diagnostic tables

## Next Steps

1. **Understand the diagnostics:**
   - Review the diagnostics file for quality metrics
   - Check that margins match targets
   - Verify design effect is acceptable

2. **Use the weighted data:**
   - Import into modules/tabs/ for crosstabulations
   - Specify weight column in analysis configurations

3. **Adapt for your data:**
   - Replace consumer_panel.csv with your survey data
   - Update Rim_Targets to match your population
   - Adjust variable names to match your columns
   - Test with create_config.R to verify structure

---

*TURAS Weighting Module v2.0 - Example 2*
