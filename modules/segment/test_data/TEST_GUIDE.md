# Segmentation Module Test Guide

This directory contains test data and configuration for testing the Turas Segmentation Module.

## Test Files Created

✅ **test_survey_data.csv** - Synthetic survey data (300 respondents)
- 4 true clusters with known structure
- 5 satisfaction variables (q1-q5) on 1-5 scale
- Demographic variables (age, gender, tenure_years)
- ~2% random missing data

✅ **test_segment_config.xlsx** - Configuration for exploration mode
- Tests k=3 to k=5
- Uses all 5 satisfaction variables for clustering
- Profiles on age and tenure
- Outputs to: `modules/segment/test_data/output/`

## Test Data Structure

### True Segments (for validation)

| Segment | Size | Satisfaction Mean | Age Mean | Tenure Mean |
|---------|------|-------------------|----------|-------------|
| 1 (High) | 75 | ~4.5 | ~60 | ~3 years |
| 2 (Med-High) | 75 | ~3.5 | ~50 | ~5 years |
| 3 (Med-Low) | 75 | ~2.5 | ~40 | ~7 years |
| 4 (Low) | 75 | ~1.5 | ~30 | ~9 years |

The algorithm should recover approximately these 4 segments.

---

## How to Run Tests

### Prerequisites

Make sure you have R installed with required packages:

```r
install.packages(c("readxl", "writexl", "cluster"))
```

### Test 1: Exploration Mode

**Objective:** Test k=3, 4, 5 and get automatic k recommendation

```r
# Change to Turas directory
setwd("/path/to/Turas")

# Source the segmentation module
source("modules/segment/run_segment.R")

# Run exploration mode
result <- turas_segment_from_config("modules/segment/test_data/test_segment_config.xlsx")
```

**Expected Outputs:**
- File: `modules/segment/test_data/output/test_k_selection_report.xlsx`
- Recommended k: Should be 4 (matches true structure)
- High silhouette scores for k=4 (>0.5)

**What to Check:**
1. ✓ Module runs without errors
2. ✓ Output file is created
3. ✓ Metrics_Comparison sheet shows k=4 has best silhouette
4. ✓ Profile_K4 sheet shows 4 distinct segment profiles
5. ✓ Segments have roughly equal sizes (~75 each)

### Test 2: Final Run Mode

**Objective:** Run with k_fixed=4 and verify outputs

**Update config file:**
1. Open `test_segment_config.xlsx`
2. Change `k_fixed` from blank to `4`
3. Save and close

```r
# Run final mode
result <- turas_segment_from_config("modules/segment/test_data/test_segment_config.xlsx")
```

**Expected Outputs:**
- File: `modules/segment/test_data/output/test_segment_assignments.xlsx`
- File: `modules/segment/test_data/output/test_segmentation_report.xlsx`
- File: `modules/segment/test_data/output/test_model.rds`

**What to Check:**
1. ✓ All 3 output files created
2. ✓ Segment assignments has 300 rows
3. ✓ Segmentation report has multiple tabs (Summary, Segment_Profiles, Validation)
4. ✓ Validation shows good silhouette (>0.5)
5. ✓ 4 segments identified
6. ✓ Segment profiles show clear differences

### Test 3: Validation Against True Segments

**Objective:** Compare discovered segments to true segments

```r
# Load true segments and assignments
test_data <- read.csv("modules/segment/test_data/test_survey_data.csv")
assignments <- readxl::read_excel("modules/segment/test_data/output/test_segment_assignments.xlsx")

# Merge
library(dplyr)
comparison <- left_join(test_data, assignments, by = "respondent_id")

# Compare true vs discovered segments
table(comparison$true_segment, comparison$segment)

# Calculate accuracy (may need to remap segment numbers)
# Should see high overlap (>80%)
```

**Expected Result:**
- Confusion matrix shows high diagonal values
- Most respondents correctly clustered
- Segment 1 (true) ≈ Segment X (discovered) with high satisfaction
- Segment 4 (true) ≈ Segment Y (discovered) with low satisfaction

---

## Test 4: Missing Data Handling

**Objective:** Test different missing data strategies

**Edit config and test each strategy:**

```r
# Test mean imputation
# Edit config: missing_data | mean_imputation
result <- turas_segment_from_config("modules/segment/test_data/test_segment_config.xlsx")

# Test median imputation
# Edit config: missing_data | median_imputation
result <- turas_segment_from_config("modules/segment/test_data/test_segment_config.xlsx")

# Test refuse
# Edit config: missing_data | refuse
# Should fail with error if missing > threshold
```

---

## Test 5: Edge Cases

### 5.1 Test with k=2 (minimum)
```r
# Edit config: k_min | 2, k_max | 2
result <- turas_segment_from_config("modules/segment/test_data/test_segment_config.xlsx")
```
Should complete successfully.

### 5.2 Test without standardization
```r
# Edit config: standardize | FALSE
result <- turas_segment_from_config("modules/segment/test_data/test_segment_config.xlsx")
```
Should complete but may give slightly different results.

### 5.3 Test with custom segment names
```r
# Edit config: k_fixed | 4
# Edit config: segment_names | Very Satisfied,Satisfied,Dissatisfied,Very Dissatisfied
result <- turas_segment_from_config("modules/segment/test_data/test_segment_config.xlsx")
```
Check that custom names appear in outputs.

---

## Expected Performance

On a typical machine:
- **Exploration mode (k=3-5):** < 10 seconds
- **Final mode (k=4):** < 5 seconds
- **Memory usage:** < 100 MB (for 300 respondents)

---

## Troubleshooting

### Error: "Package 'cluster' required"
```r
install.packages("cluster")
```

### Error: "Config file not found"
- Check working directory with `getwd()`
- Use full path to config file

### Error: "Data file not found"
- Config uses relative path: `modules/segment/test_data/test_survey_data.csv`
- Must run from Turas project root

### Warning: "High missing data"
- Expected (2% missing)
- Should proceed with listwise deletion

### No output files created
- Check output folder exists
- Check write permissions
- Look for error messages in console

---

## Success Criteria

✅ **All tests pass if:**
1. Exploration mode runs without errors
2. Recommends k=4 (true structure)
3. Silhouette scores > 0.5 for k=4
4. Final mode creates all 3 output files
5. Segment profiles show clear differences
6. Discovered segments match true segments (>80% accuracy)

---

## Next Steps After Testing

1. **If all tests pass:**
   - Module is working correctly
   - Ready to use with real survey data
   - Create config for your actual project

2. **If tests fail:**
   - Document exact error messages
   - Check R version and package versions
   - Review console output for warnings

3. **Performance testing:**
   - Test with larger dataset (1000+ respondents)
   - Test with more variables (10+ clustering vars)

---

## Test Data Generation

The test data was generated with known cluster structure:

```python
# 4 segments with distinct characteristics
Segment 1: High satisfaction (mean=4.5), older (60), short tenure (3y)
Segment 2: Med-high satisfaction (mean=3.5), age 50, medium tenure (5y)
Segment 3: Med-low satisfaction (mean=2.5), age 40, longer tenure (7y)
Segment 4: Low satisfaction (mean=1.5), younger (30), longest tenure (9y)
```

Each segment has 75 respondents. Random noise added (SD=0.5) to make clustering realistic.

---

**Created:** 2025-11-14
**Version:** 1.0
**Part of:** Turas Segmentation Module Testing
