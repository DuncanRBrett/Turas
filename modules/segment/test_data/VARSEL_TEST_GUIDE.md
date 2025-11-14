# Variable Selection Testing Guide

This guide explains how to test the variable selection feature with a 20-variable dataset.

## Prerequisites

1. Have R installed with required packages:
   - `readxl`, `writexl`, `cluster`, `psych`, `data.table` (optional)

## Step 1: Generate Test Data

Run the data generation script to create a 20-variable dataset:

```r
setwd("/path/to/Turas")
source("modules/segment/test_data/generate_test_data_20vars.R")
```

This creates `test_survey_data_20vars.csv` with:
- 300 respondents
- 20 satisfaction variables (q1-q20)
- 3 demographic variables
- 4 true clusters
- Designed characteristics:
  - **q20**: Very low variance (should be removed)
  - **q2, q6, q14**: Highly correlated with q1, q5, q13 (should be removed)
  - **Remaining variables**: Different variance levels for ranking

## Step 2: Generate Excel Config

```r
library(writexl)
config <- read.csv("modules/segment/test_data/test_varsel_config.csv")
write_xlsx(list(Config = config), "modules/segment/test_data/test_varsel_config.xlsx")
```

## Step 3: Run Variable Selection Test

```r
setwd("/path/to/Turas")
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("modules/segment/test_data/test_varsel_config.xlsx")
```

## Expected Output

### Console Output

You should see:

```
================================================================================
VARIABLE SELECTION
================================================================================

Method: variance_correlation
Original variables: 20 (q1 through q20)
Target: 10 variables

Step 1: Analyzing variance (threshold: 0.10)
  Removed 1 low-variance variables: q20
  Remaining: 19

Step 2: Analyzing correlations (threshold: 0.80)
  Found 3 highly correlated pairs
  Removed 3 correlated variables: q2, q6, q14
  Remaining: 16

Step 3: Ranking variables (16 → 10)
  Using variance ranking: selected top 10 variables

✓ Variable selection complete: 20 → 10 variables

================================================================================
VARIABLE SELECTION SUMMARY
================================================================================

Method: variance_correlation
Original variables: 20
Selected variables: 10
Removed variables: 10

Selected variables:
  q1, q3, q4, q5, q7, q9, q11, q13, q15, q17

Removed variables:
  q2, q6, q8, q10, q12, q14, q16, q18, q19, q20
```

### Excel Outputs

**File**: `varsel_test_k_selection_report.xlsx`

**New sheets**:
1. **VarSel_Selected**: List of 10 selected variables
2. **VarSel_Statistics**: All 20 variables with variance, SD, and selection status

The report will also show:
- Metrics comparison for k=3, 4, 5
- Segment profiles using only the 10 selected variables
- Variable selection was applied before clustering

## Test Different Methods

### Test Factor Analysis Method

Update config:
```r
config$Value[config$Setting == "variable_selection_method"] <- "factor_analysis"
write_xlsx(list(Config = config), "modules/segment/test_data/test_varsel_config.xlsx")
```

Re-run. This will:
- Perform exploratory factor analysis
- Identify underlying dimensions
- Select representative variables from each factor

### Test with Both Methods

```r
config$Value[config$Setting == "variable_selection_method"] <- "both"
```

This uses factor analysis if available, falls back to variance/correlation.

## Validation

After running, verify:

1. **Variable count reduced**: Started with 20, ended with 10
2. **Low-variance removed**: q20 should be excluded
3. **Correlations handled**: q2, q6, q14 should be excluded
4. **Clustering still works**: k selection report shows valid silhouette scores
5. **Sheets present**: VarSel_Selected and VarSel_Statistics in Excel report

## Disable Variable Selection

To run with all 20 variables:

```r
config$Value[config$Setting == "variable_selection"] <- "FALSE"
write_xlsx(list(Config = config), "modules/segment/test_data/test_varsel_config.xlsx")
```

Compare results to see impact of variable selection on clustering quality.

## Troubleshooting

**"psych package not installed"**: Install with `install.packages("psych")` or use `variance_correlation` method

**"Already at or below target"**: Reduce `max_clustering_vars` in config to force selection

**"No variables removed"**: Check that test data was generated correctly with correlations and low-variance q20
