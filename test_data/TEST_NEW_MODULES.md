# Testing New Modules with Synthetic Data

This directory contains synthetic test data for validating the Conjoint and Key Driver modules.

---

## Test 1: Conjoint Analysis (Choice-Based)

### Scenario
**Product:** Smartphones
**Respondents:** 10 people
**Choice Sets:** 3 per person (30 choice sets total)
**Alternatives per Set:** 3 (90 total alternatives)

### Attributes Being Tested
- **Price:** £449, £599, £699
- **Brand:** Apple, Samsung, Google
- **Storage:** 128GB, 256GB, 512GB
- **Battery:** 12 hours, 18 hours, 24 hours

### Files
- **Data:** `conjoint_test_data.csv` (90 rows - Alchemer CBC format)
- **Config:** `conjoint_test_config.xlsx`

### How to Test

```r
# Set working directory
setwd("/path/to/Turas")

# Source Conjoint module
source("modules/conjoint/R/00_main.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/02_validation.R")
source("modules/conjoint/R/03_analysis.R")
source("modules/conjoint/R/04_output.R")

# Run analysis
results <- run_conjoint_analysis(
  config_file = "test_data/conjoint_test_config.xlsx",
  data_file = "test_data/conjoint_test_data.csv",
  output_file = "test_data/conjoint_test_results.xlsx"
)

# View results
print(results$importance)
print(results$utilities)
print(results$fit)
```

### Expected Results
- **Utilities:** Part-worth values for each attribute level
- **Importance:** % importance for Price, Brand, Storage, Battery
- **Model Fit:**
  - McFadden's R² (0-1, higher is better)
  - Hit rate (% choices correctly predicted)
  - AIC, BIC, Log-likelihood

### What to Check
✅ No errors during execution
✅ Results file created: `test_data/conjoint_test_results.xlsx`
✅ Output has 4 sheets: Importance, Utilities, Model Fit, Configuration
✅ Importance scores sum to 100%
✅ Utilities are zero-centered within each attribute

---

## Test 2: Key Driver Analysis

### Scenario
**Product:** Brand Health Study
**Respondents:** 100 customers
**Outcome:** Overall satisfaction (1-10 scale)
**Drivers:** 6 potential drivers (all 1-10 scale)

### Drivers Being Tested
1. Product Quality
2. Customer Service
3. Value for Money
4. Brand Reputation
5. Delivery Speed
6. Website Ease of Use

### Files
- **Data:** `keydriver_test_data.csv` (100 respondents)
- **Config:** `keydriver_test_config.xlsx`

### How to Test

```r
# Set working directory
setwd("/path/to/Turas")

# Source Key Driver module
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

# Run analysis
results <- run_keydriver_analysis(
  config_file = "test_data/keydriver_test_config.xlsx",
  data_file = "test_data/keydriver_test_data.csv",
  output_file = "test_data/keydriver_test_results.xlsx"
)

# View results
print(results$importance)
```

### Expected Results
- **Importance Scores:** % importance from 4 methods:
  - Shapley Value (most robust)
  - Relative Weights (Johnson's method)
  - Beta Weights (standardized coefficients)
  - Correlation (zero-order r)
- **Rankings:** Rank position from each method
- **Model Fit:** R², Adj R², F-stat, RMSE, p-value

### What to Check
✅ No errors during execution
✅ Results file created: `test_data/keydriver_test_results.xlsx`
✅ Output has 4 sheets: Importance Summary, Method Rankings, Model Summary, Correlations
✅ All importance scores are positive
✅ Console shows "TOP 5 DRIVERS" summary
✅ Model R² > 0 (indicates model explains variance)

---

## Expected Console Output

### Conjoint
```
================================================================================
TURAS CONJOINT ANALYSIS
================================================================================

1. Loading configuration...
   ✓ Loaded 4 attributes with 12 total levels

2. Loading and validating data...
   ✓ Loaded 10 respondents with 90 profiles each

3. Calculating part-worth utilities...
   ✓ Estimated 12 part-worth utilities

4. Calculating attribute importance...
   ✓ Importance scores calculated

5. Generating output file...
   ✓ Results written to: test_data/conjoint_test_results.xlsx

================================================================================
ANALYSIS COMPLETE
================================================================================
```

### Key Driver
```
================================================================================
TURAS KEY DRIVER ANALYSIS
================================================================================

1. Loading configuration...
   ✓ Outcome variable: overall_satisfaction
   ✓ Driver variables: 6 variables

2. Loading and validating data...
   ✓ Loaded 100 respondents
   ✓ Complete cases: 100

3. Calculating correlations...
   ✓ Correlation matrix calculated

4. Fitting regression model...
   ✓ Model R² = 0.XXX

5. Calculating importance scores...
   ✓ Multiple importance methods calculated

6. Generating output file...
   ✓ Results written to: test_data/keydriver_test_results.xlsx

================================================================================
ANALYSIS COMPLETE
================================================================================

TOP 5 DRIVERS (by Shapley value):
  1. Customer Service (XX.X%)
  2. Product Quality (XX.X%)
  3. Value for Money (XX.X%)
  4. Brand Reputation (XX.X%)
  5. Delivery Speed (XX.X%)
```

---

## Troubleshooting

### "Package 'survival' required" (Conjoint)
```r
install.packages("survival")
```

### "Package 'openxlsx' required"
```r
install.packages("openxlsx")
```

### "Package 'haven' required" (if using SPSS/Stata files)
```r
install.packages("haven")
```

### File Not Found Errors
Make sure you're in the Turas directory:
```r
getwd()  # Should show /path/to/Turas
setwd("/path/to/Turas")  # If not
```

---

## After Successful Testing

Once both modules test successfully:

1. ✅ **Conjoint works** - Ready for your real CBC data
2. ✅ **Key Driver works** - Ready for your real satisfaction/driver data

You can delete the test files or keep them as examples:
```r
# To delete test data (optional)
unlink("test_data", recursive = TRUE)
```

---

**Created:** 2025-11-18
**Purpose:** Validate new Conjoint and Key Driver modules
**Data:** Synthetic (safe for testing, no real respondent data)
