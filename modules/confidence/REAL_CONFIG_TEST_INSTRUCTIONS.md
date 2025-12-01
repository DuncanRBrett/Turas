# Testing Confidence Module with Real CCPB Config

## Quick Start

This test validates that the confidence module works with your existing CCPB CSAT 2025 config file (created before NPS and representativeness features were added).

### Steps to Run:

1. **Open RStudio or R Console**

2. **Navigate to your Turas project directory:**
   ```r
   setwd("/Users/duncan/Documents/Turas")
   ```

3. **Run the test script:**
   ```r
   source("modules/confidence/tests/test_real_config_ccpb.R")
   ```

4. **Wait for completion** (may take 1-2 minutes depending on data size)

### Expected Output:

```
====================================
REAL CONFIG TEST: CCPB CSAT 2025
====================================

✓ Config file found
  Path: /Users/duncan/Library/CloudStorage/OneDrive-Personal/...

Loading confidence module...
✓ Module loaded successfully

Running confidence analysis with real config...
(This may take 1-2 minutes depending on data size)

📊 Starting Confidence Analysis Pipeline
  Config file: /Users/duncan/Library/CloudStorage/.../CCPB_CSAT2025_confidence_config.xlsx
  Working directory: /Users/duncan/Documents/Turas

✓ Configuration loaded successfully
  8 sheets processed
  Data file: .../CSAT2025_data.csv
  Weight variable: weight

✓ Data loaded: XXX observations, XX variables

✓ Study-level statistics calculated
  Total observations: XXX
  Effective sample size (n_eff): XX.X
  Design effect (DEFF): X.XXX
  Message: [DEFF interpretation]

✓ Processing XX questions...
  ✓ Processed: X proportions, X means, 0 NPS

✓ Excel output written
  Path: .../CCPB_CSAT2025_confidence_results.xlsx

====================================
ANALYSIS COMPLETED SUCCESSFULLY
====================================

=== Analysis Summary ===
Proportions analyzed: X
Means analyzed: X
NPS analyzed: 0

Warnings: [X warnings or None]

=== Study-Level Statistics ===
Total observations: XXX
Effective sample size: XX.X
Design effect (DEFF): X.XXX

Representativeness diagnostics present: NO (expected for old config)

=== Excel Output ===
✓ Output file created successfully
  Path: .../CCPB_CSAT2025_confidence_results.xlsx

Workbook sheets:
  - Summary
  - Study_Level
  - Proportions_Detail
  - Means_Detail
  - Methodology
  - Warnings
  - Inputs

====================================
✓ BACKWARD COMPATIBILITY TEST PASSED
====================================

The module successfully processed a config file created before
NPS and representativeness features were added. This confirms:
  ✓ No breaking changes to existing functionality
  ✓ Old configs work without Population_Margins sheet
  ✓ Real messy data handled correctly
  ✓ Module is production-ready for testing with GUI

Next steps:
  1. Open the Excel output file and verify it looks correct
  2. Compare results to previous analysis (if available)
  3. Test with launch_turas GUI
```

### What This Test Validates:

1. **Backward Compatibility**: Old config files (without NPS/representativeness features) still work
2. **No Breaking Changes**: New features don't interfere with existing functionality
3. **Real Data Handling**: Module correctly processes messy real-world survey data
4. **Optional Features**: Population_Margins sheet is truly optional (won't cause errors if absent)
5. **Output Generation**: Excel workbook created with all expected sheets

### If You Get Errors:

#### Error: "Config file not found"
- **Cause**: OneDrive file not synced or path incorrect
- **Fix**:
  - Check OneDrive is synced
  - Verify path: `/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/CCPB/CCPB_CSAT/03_Waves/CSAT2025/`
  - Try opening the file in Excel first to trigger OneDrive sync

#### Error: "Data file not found"
- **Cause**: Data file path in config points to location not accessible
- **Fix**:
  - Open the config file in Excel
  - Check `File_Paths` sheet → `Data_File` parameter
  - Ensure that data file exists and is accessible

#### Error: "Failed to load module"
- **Cause**: Working directory incorrect or R source files corrupted
- **Fix**:
  - Verify you're in the Turas project directory: `getwd()`
  - Re-clone repository if files corrupted
  - Check R console for specific error message

#### Error during analysis
- **Cause**: Data format issue or bug in code
- **Fix**:
  - Check R console for detailed error message
  - Look for specific line number in error trace
  - Report error details for debugging

### Interpreting Results:

**Study-Level Statistics:**
- `n_obs`: Total number of survey responses
- `n_eff`: Effective sample size (accounts for survey weights)
- `deff`: Design effect (measures impact of weighting)
  - DEFF = 1.0: No impact from weighting
  - DEFF = 1.5: 50% increase in variance due to weights
  - DEFF > 2.0: Consider reviewing weighting approach

**Question Analysis:**
- Proportions: Binary/categorical questions (Yes/No, satisfaction levels, etc.)
- Means: Numeric questions (scores, ratings, etc.)
- NPS: Net Promoter Score (should be 0 for old configs without NPS questions)

**Representativeness:**
- Should show "NO (expected for old config)"
- This confirms optional features work correctly

### Next Steps After Test Passes:

1. **Open Excel output**:
   - File location shown in test output
   - Verify formatting looks professional
   - Check confidence intervals are reasonable

2. **Compare to previous results** (if available):
   - If you previously analyzed this data, compare results
   - CIs should be similar (small differences expected due to random seed in bootstrap)

3. **Test with launch_turas GUI**:
   - Once backend validated, proceed to GUI integration
   - Test end-to-end workflow through GUI

4. **Test with new features**:
   - Create a config with NPS questions
   - Add Population_Margins sheet to test representativeness
   - Run full feature test

### Alternative: Run Individual Tests

If you prefer to run the comprehensive test suite first:

```r
# Test 1: Representativeness (new feature)
setwd("/Users/duncan/Documents/Turas/modules/confidence")
source("tests/test_representativeness.R")

# Test 2: NPS (new feature)
source("tests/test_nps.R")

# Test 3: Weighted data (existing feature - regression check)
source("tests/test_weighted_data.R")

# Test 4: Real config (backward compatibility)
setwd("/Users/duncan/Documents/Turas")
source("modules/confidence/tests/test_real_config_ccpb.R")
```

All four tests should pass without errors.

---

**Document Version:** 1.0
**Date:** December 1, 2025
**Module Version:** 2.0.0 (with NPS and representativeness)
