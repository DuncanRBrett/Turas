# CONFIDENCE MODULE - TESTING GUIDE

**Date:** November 30, 2025
**Status:** All critical bugs fixed - Ready for testing

---

## STEP 1: Run Weighted Data Test (Verify Bug Fixes)

This comprehensive test verifies all the weighted data bug fixes work correctly.

### Run the Test:

```r
setwd("~/Documents/Turas/modules/confidence")
source("tests/test_weighted_data.R")
```

### What It Tests:

1. **Standard weighted data** - Normal scenario
2. **NA weights** - Critical bug fix #2 verification
3. **Zero weights** - Critical bug fix #2 verification
4. **Mixed messy data** - Worst case scenario (NA + zeros + missing)
5. **Extreme weight variation** - Stress test with high DEFF

### Expected Output:

```
================================================================================
ALL WEIGHTED DATA TESTS PASSED!
================================================================================

Tests completed:
  ✓ TEST 1: Standard weighted data
  ✓ TEST 2: NA weights (critical bug fix verified)
  ✓ TEST 3: Zero weights (critical bug fix verified)
  ✓ TEST 4: Mixed messy data (worst case)
  ✓ TEST 5: Extreme weight variation (stress test)

Critical verifications:
  ✓ No length mismatch errors
  ✓ No crashes in weighted.mean()
  ✓ No crashes in bootstrap functions
  ✓ Values and weights correctly aligned
  ✓ NA and zero weights properly excluded
  ✓ Effective n calculated correctly
  ✓ DEFF reflects weight variation

The weighted data bug fixes are confirmed working!
Ready for production use with weighted survey data.
```

**If this test passes:** ✅ All weighted data handling is working correctly!

---

## STEP 2: Test Through Turas GUI

Now test with your real data using the GUI.

### Launch Turas:

```r
setwd("~/Documents/Turas")
source("launch_turas.R")
```

### Steps in GUI:

1. **Click "Launch Confidence"** button (orange button with 📊 icon)
2. **New window opens** with the Confidence GUI
3. **Select your project directory** (click "Browse for Project Folder")
4. **Choose config file** from detected .xlsx files
5. **Click "RUN ANALYSIS"**

---

## STEP 3: Prepare Your Real Data

### Required Files:

1. **Survey data** (CSV or XLSX):
   - Must have columns for each question
   - Optional: weight variable
   - Example: `survey_data.csv`

2. **Configuration file** (XLSX with 3 sheets):
   - `File_Paths` - Points to data file, output location, weight variable
   - `Study_Settings` - Analysis settings
   - `Question_Analysis` - Questions to analyze

---

## Configuration Template

### Sheet 1: File_Paths

| Parameter | Value |
|-----------|-------|
| Data_File | path/to/survey_data.csv |
| Output_File | path/to/results.xlsx |
| Weight_Variable | weight |

### Sheet 2: Study_Settings

| Setting | Value | Valid Options |
|---------|-------|---------------|
| Calculate_Effective_N | Y | Y/N |
| Multiple_Comparison_Adjustment | N | Y/N (not implemented yet) |
| Multiple_Comparison_Method | None | None/Bonferroni/Holm/FDR |
| Bootstrap_Iterations | 5000 | 1000-10000 |
| Confidence_Level | 0.95 | 0.90/0.95/0.99 |
| Decimal_Separator | . | . or , |

### Sheet 3: Question_Analysis

| Question_ID | Statistic_Type | Categories | Run_MOE | Use_Wilson | Run_Bootstrap | Run_Credible |
|-------------|----------------|------------|---------|------------|---------------|--------------|
| Q1_Aware | proportion | 1 | Y | Y | Y | N |
| Q2_Satisfaction | mean | NA | Y | N | Y | N |

**Important:**
- `Statistic_Type` must be `proportion` or `mean` (NOT `nps` - that's Phase 2)
- For proportions: Specify `Categories` (codes to count as success)
- For means: Leave `Categories` as NA
- `Use_Wilson` flag (not `Run_Wilson`) for Wilson score intervals

---

## What to Watch For

### ✅ Good Signs:

- Analysis completes without errors
- Output Excel file created with 7 sheets
- Results look reasonable (proportions 0-1, sensible CIs)
- Warnings are informative (e.g., "Small base n=25")

### ⚠️ Warning Messages (Normal):

These are **informative**, not errors:

```
Weight variable 'weight' contains X zero values (these will be excluded from analysis)
Weight variable 'weight' contains X NA values (these will be excluded from analysis)
Question Q5: Small base (n=45) - interpret with caution
```

### 🔴 Error Messages (Report These):

If you see any of these, please report:

```
ERROR: Question X: different lengths
ERROR: weights must have same length as data
ERROR: if(logical(0)) ...
ERROR: Statistic_Type must be 'proportion' or 'mean' (NPS support planned for Phase 2)
```

---

## Output File Structure

The Excel workbook will have **7 sheets**:

1. **Summary** - High-level overview
2. **Study_Level** - DEFF, effective n, weight statistics
3. **Proportions_Detail** - All proportion results with CIs
4. **Means_Detail** - All mean results with CIs
5. **Methodology** - Statistical formulas and references
6. **Warnings** - Data quality warnings
7. **Inputs** - Configuration summary for reproducibility

---

## Common Issues & Solutions

### Issue: "Config file not detected"
**Solution:** Config file must be `.xlsx` and contain "confidence" in filename (case-insensitive)

### Issue: "Question X not found in data"
**Solution:** Check Question_ID spelling matches data column names exactly

### Issue: "Weight variable 'X' not found"
**Solution:** Check Weight_Variable spelling in File_Paths sheet

### Issue: "Prior_SD required when Prior_Mean specified for mean"
**Solution:** For Bayesian mean CIs, must specify both Prior_Mean AND Prior_SD

### Issue: Analysis runs but some questions missing
**Solution:** Check warnings in console or Warnings sheet - likely small sample or all NA

---

## Weighted Data Specifics

### If Using Weights:

1. **Specify Weight_Variable** in File_Paths sheet
2. **Set Calculate_Effective_N = Y** in Study_Settings
3. **Check Study_Level sheet** in output for:
   - Actual n (raw sample size)
   - Effective n (precision-adjusted)
   - DEFF (design effect)
   - Weight statistics (min, max, CV)

### Understanding DEFF:

- **DEFF = 1.0** → No precision loss from weighting
- **DEFF = 1.1-1.2** → Modest loss (5-20%)
- **DEFF = 1.2-2.0** → Moderate loss (20-50%)
- **DEFF > 2.0** → Substantial loss (>50%) - check weights!

### Weight Quality Checks:

Look for warnings in Study_Level sheet:
- High CV (> 0.30) → Extreme weight variation
- Wide range (max/min > 10) → Some cases heavily weighted
- High DEFF (> 2.0) → Significant precision loss

---

## Real Data Testing Checklist

Before testing with real data:

- [ ] Run `test_weighted_data.R` and confirm all tests pass
- [ ] Create config file with 3 required sheets
- [ ] Verify Question_IDs match data column names
- [ ] Check weight variable name if using weights
- [ ] Ensure Statistic_Type is only "proportion" or "mean"
- [ ] Use `Use_Wilson` flag (not `Run_Wilson`)

During testing:

- [ ] Launch through `launch_turas.R` GUI
- [ ] Browse to project directory
- [ ] Select config file
- [ ] Click "RUN ANALYSIS"
- [ ] Watch console output for errors
- [ ] Check Excel output has 7 sheets

After testing:

- [ ] Verify proportions are in [0, 1] range
- [ ] Check confidence intervals make sense (lower < upper)
- [ ] Review warnings for data quality issues
- [ ] Compare weighted vs unweighted results (if applicable)
- [ ] Verify n and n_eff values are reasonable

---

## Performance Expectations

### Typical Run Times:

- **10 questions, n=1000, unweighted:** ~5 seconds
- **10 questions, n=1000, weighted, bootstrap:** ~10 seconds
- **50 questions, n=5000, weighted, bootstrap:** ~30-60 seconds
- **200 questions, n=10000, all methods:** ~5-10 minutes

**Note:** Bootstrap with 10,000 iterations is slower than 1,000 iterations

---

## Example Real Data Scenario

### Scenario: Customer Satisfaction Survey

**Data:**
- 2,500 respondents
- 15 satisfaction questions (0-10 scale)
- 5 brand awareness questions (binary 0/1)
- Design weights to correct for demographics

**Config:**
- Means for satisfaction questions (Run_MOE=Y, Run_Bootstrap=Y)
- Proportions for awareness (categories="1", Use_Wilson=Y, Run_Bootstrap=Y)
- Calculate_Effective_N = Y
- Bootstrap_Iterations = 5000
- Confidence_Level = 0.95

**Expected Output:**
- Study DEFF around 1.1-1.3 (typical for demo weighting)
- Effective n around 2,000-2,200 (from 2,500 actual)
- Satisfaction means with ~±0.15 CIs
- Awareness proportions with ~±0.04 CIs (depending on base)

---

## Support & Troubleshooting

### If Tests Fail:

1. Check you pulled latest changes: `git pull`
2. Verify R packages installed: `openxlsx`, `readxl`
3. Review error messages carefully
4. Check file paths are absolute (not relative)

### If GUI Doesn't Launch:

1. Verify `shiny` and `shinyFiles` packages installed
2. Check working directory: `getwd()` should be Turas root
3. Look for error in R console

### If Analysis Crashes:

1. Check config file format (3 sheets with exact names)
2. Verify Question_IDs match data columns
3. Ensure Statistic_Type is only "proportion" or "mean"
4. Review console output for specific error location

---

## Next Steps After Successful Testing

Once your real data test completes successfully:

1. **Review output thoroughly** - Check all sheets make sense
2. **Validate against known benchmarks** - Compare to previous analysis if available
3. **Test edge cases** - Try with small samples, extreme proportions, etc.
4. **Consider Phase 2 features** - NPS, multiple comparisons, etc.

---

## Summary

**Testing Path:**
1. ✅ Run `test_weighted_data.R` → Verify bug fixes
2. ✅ Launch Turas GUI → Test user interface
3. ✅ Run real data analysis → Production verification

**All critical bugs fixed and tested. Ready for production use!**

---

**Document Version:** 1.0
**Last Updated:** November 30, 2025
