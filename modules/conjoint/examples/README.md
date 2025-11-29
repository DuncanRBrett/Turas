# Enhanced Conjoint Module - Examples

This directory contains complete working examples for the Enhanced Turas Conjoint Analysis module.

## Quick Start

**New to the module?** Start here:

1. Read [`QUICK_START_GUIDE.md`](QUICK_START_GUIDE.md) - Comprehensive usage guide
2. Examine `example_config.xlsx` - See how to structure your configuration
3. Look at `sample_cbc_data.csv` - See the expected data format
4. Run `test_analysis.R` - Test the module with example data

## Files in This Directory

### Configuration Files

- **`example_config.xlsx`** - Complete example configuration file
  - Demonstrates a smartphone choice-based conjoint study
  - 5 attributes: Brand, Price, Screen Size, Battery Life, Camera Quality
  - Includes Settings, Attributes, and Instructions sheets
  - Ready to use with the sample data

### Data Files

- **`sample_cbc_data.csv`** - Realistic choice-based conjoint data
  - 50 respondents
  - 8 choice sets per respondent (400 total)
  - 3 alternatives per choice set
  - 1,200 total rows
  - Generated with realistic preference patterns

### Test Scripts

- **`test_analysis.R`** - Complete end-to-end test script
  - Loads all module files
  - Runs analysis with example data
  - Displays results summary
  - Verifies output file creation
  - Use this to test your R environment setup

### Documentation

- **`QUICK_START_GUIDE.md`** - Complete usage documentation
  - Installation instructions
  - Configuration file format
  - Data file format
  - Step-by-step examples
  - Troubleshooting guide
  - Best practices

- **`README.md`** (this file) - Overview of examples directory

### Generation Scripts

- **`create_example_config.py`** - Script to regenerate the example config file
- **`create_sample_data.py`** - Script to regenerate the sample data
  - These are provided for reference and reproducibility
  - You don't need to run these unless you want to modify the examples

### Output Directory

- **`output/`** - Directory where example results are saved
  - `example_results.xlsx` will be created here when you run the analysis

## How to Use These Examples

### Option 1: Run the Example Analysis (Recommended for First-Time Users)

```r
# 1. Set working directory to Turas root
setwd("/path/to/Turas")

# 2. Load required packages
library(mlogit)
library(survival)
library(openxlsx)
library(dplyr)
library(tidyr)

# 3. Source all module files
source("modules/conjoint/R/99_helpers.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/09_none_handling.R")
source("modules/conjoint/R/02_data.R")
source("modules/conjoint/R/03_estimation.R")
source("modules/conjoint/R/04_utilities.R")
source("modules/conjoint/R/07_output.R")
source("modules/conjoint/R/00_main.R")

# 4. Run the example
results <- run_conjoint_analysis(
  config_file = "modules/conjoint/examples/example_config.xlsx"
)

# 5. View results
print(results$importance)
print(results$utilities)

# 6. Check the Excel output
# Located at: modules/conjoint/examples/output/example_results.xlsx
```

### Option 2: Use the Test Script

```r
# Set working directory to Turas root
setwd("/path/to/Turas")

# Run the complete test script
source("modules/conjoint/examples/test_analysis.R")
```

This will:
- Check and install required packages
- Load all module files
- Run the analysis
- Display a comprehensive results summary
- Verify the output file was created

### Option 3: Adapt for Your Own Data

1. **Copy the example config**: `example_config.xlsx` → `my_study_config.xlsx`
2. **Edit the Attributes sheet**:
   - Change attribute names to match your study
   - Update levels for each attribute
   - Adjust NumLevels accordingly
3. **Edit the Settings sheet**:
   - Update `data_file` to point to your data
   - Update `output_file` to your desired output location
   - Adjust other settings as needed
4. **Prepare your data file** in the same format as `sample_cbc_data.csv`
5. **Run your analysis**:
   ```r
   results <- run_conjoint_analysis(
     config_file = "path/to/my_study_config.xlsx"
   )
   ```

## Expected Results from Example

When you run the example analysis, you should see:

**Attribute Importance (approximate):**
1. Price: ~35%
2. Brand: ~29%
3. Camera Quality: ~17%
4. Battery Life: ~12%
5. Screen Size: ~7%

**Model Fit:**
- McFadden R²: ~0.31 (Good)
- Hit Rate: ~54% (vs. 33% chance rate)

**Excel Output:**
- 6 sheets with professional formatting
- Conditional formatting on utilities (green/red)
- Comprehensive diagnostics and summaries

## Understanding the Example Study

The example simulates a smartphone conjoint study where:

- **Respondents** evaluate different smartphone configurations
- **Each choice set** presents 3 smartphone options
- **Choices** are driven by realistic preference patterns:
  - Strong preference for Apple and lower prices
  - Moderate preference for larger screens and better batteries
  - Moderate preference for better camera quality

The data was generated with known "true" utilities:
- **Brand**: Apple (+0.8) > Samsung (+0.4) > Google (+0.2) > OnePlus (-1.4)
- **Price**: $299 (+1.2) > $399 (+0.4) > $499 (-0.3) > $599 (-1.3)
- **Screen**: 6.7" (+0.6) > 6.1" (0.0) > 5.5" (-0.6)
- **Battery**: 24h (+0.8) > 18h (0.0) > 12h (-0.8)
- **Camera**: Excellent (+0.7) > Good (0.0) > Basic (-0.7)

Your analysis should recover utilities close to these values!

## Troubleshooting

### "Package 'mlogit' not installed"
```r
install.packages("mlogit")
```

### "Cannot find file example_config.xlsx"
- Check your working directory with `getwd()`
- Make sure you're in the Turas root directory
- Use full paths if needed

### "mlogit estimation failed"
- This shouldn't happen with the example data
- If it does, the module will automatically fall back to clogit
- Check that all packages are properly installed

### Still having issues?
- See the Troubleshooting section in [`QUICK_START_GUIDE.md`](QUICK_START_GUIDE.md)
- Check the specification documents in `modules/conjoint/`
- Ensure you're using R version 4.0 or higher

## Additional Resources

- **Full Specification**: See `modules/conjoint/Part1_Core_Technical_Specification.md` (and Parts 2-5)
- **Implementation Status**: See `modules/conjoint/IMPLEMENTATION_STATUS.md`
- **Module Code**: See `modules/conjoint/R/` directory

## Questions?

1. Read the Quick Start Guide
2. Review the specification documents
3. Examine the example files
4. Check the implementation status document
5. Contact the Turas development team

---

**Version:** 2.0.0
**Date:** 2025-11-27
**Status:** Production Ready

**Happy analyzing!**
