# Composite Scores Test Data

This directory contains minimal test data for the Composite Scores feature (V10.1).

## Files

1. **test_data.csv** - Minimal survey data with 4 satisfaction questions
2. **test_structure.xlsx** - Survey structure with Composite_Metrics sheet
3. **test_config.xlsx** - Configuration file with composite settings

## Test Composite

**COMP_SAT_OVERALL** - Overall Satisfaction
- Calculation: Mean of SAT_01, SAT_02, SAT_03, SAT_04
- Section: SATISFACTION METRICS

## Expected Output

When run, should produce:
- Standard crosstabs for SAT_01 through SAT_04
- Composite score showing average across all 4 questions
- Index_Summary sheet with all metrics consolidated
- Composite marked with → prefix

## Running the Test

```r
config_file <- "test_composite/test_config.xlsx"
toolkit_path <- "modules/tabs/lib/run_crosstabs.R"
source(toolkit_path)
```

## Success Criteria

✓ No errors during processing
✓ Composite calculated correctly
✓ Index_Summary sheet exists
✓ Composite appears in Index_Summary
✓ Section headers display correctly
✓ Existing functionality unchanged
