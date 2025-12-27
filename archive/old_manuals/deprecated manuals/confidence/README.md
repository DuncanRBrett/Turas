# Turas Confidence Analysis Module

## Version 2.0.0 ✅

A comprehensive statistical confidence analysis module for the Turas survey analytics platform.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Quick Start](#quick-start)
- [What's New in v2.0](#whats-new-in-v20)
- [Documentation](#documentation)
- [Installation](#installation)
- [Basic Usage](#basic-usage)
- [Support](#support)

---

## Overview

The Confidence Module calculates statistical confidence intervals for survey data, supporting proportions, means, and Net Promoter Score (NPS). It handles weighted data, provides multiple confidence interval methods, and includes optional quota representativeness diagnostics.

**Perfect for:**
- 📊 Calculating margins of error for survey results
- 🎯 Analyzing Net Promoter Score with confidence intervals
- ⚖️ Handling weighted survey data with design effects
- 📈 Comparing sample composition to population targets
- 🔬 Research-grade statistical analysis

---

## Key Features

### ✅ Statistical Methods

- **Proportions (4 methods)**
  - Margin of Error (MOE) - Normal approximation
  - Wilson Score Intervals
  - Bootstrap resampling (5,000-10,000 iterations)
  - Bayesian credible intervals (Beta-Binomial)

- **Means (3 methods)**
  - Student's t-distribution
  - Bootstrap resampling with weighted support
  - Bayesian credible intervals (Normal-Normal)

- **Net Promoter Score**
  - NPS calculation (%Promoters - %Detractors)
  - All three CI methods (Normal, Bootstrap, Bayesian)
  - Variance of difference formula for standard errors

### ✅ Weighted Data Support

- Effective sample size (Kish formula)
- Design effect (DEFF) calculation
- Weight concentration diagnostics
- Weighted bootstrap resampling

### ✅ Representativeness Diagnostics (Optional)

- Simple quota comparison (single variables)
- Nested quota analysis (multi-variable interactions)
- Traffic-light flagging (GREEN/AMBER/RED)
- Weight concentration metrics (Top 1%, 5%, 10%)

### ✅ Professional Output

- Multi-sheet Excel workbook
- Color-coded formatting
- Methodology documentation
- Warning logs
- Decimal separator support (period or comma)

### ✅ User Interface

- **GUI Mode**: Launch from Turas Suite with visual interface
- **Command Line**: Run directly from R console
- **Batch Processing**: Automated workflows

---

## Quick Start

### 1. Launch from Turas Suite GUI

```r
# Start Turas Suite
setwd("/path/to/Turas")
source("launch_turas.R")
# Click "Launch Confidence" button
```

### 2. Run from Command Line

```r
# Load module
setwd("/path/to/Turas/modules/confidence")
source("R/00_main.R")

# Run analysis
run_confidence_analysis(
  config_path = "/path/to/your_confidence_config.xlsx",
  verbose = TRUE
)
```

### 3. Create Configuration File

See **[Quick Start Guide](QUICK_START.md)** for step-by-step configuration setup.

---

## What's New in v2.0

### 🎯 Net Promoter Score (NPS)
- Full NPS support with all confidence interval methods
- Automatic handling of promoter/detractor codes
- Dedicated NPS output sheet

### 📊 Representativeness Analysis
- Compare weighted sample vs population targets
- Simple and nested quota checking
- Weight concentration diagnostics
- Traffic-light flagging for quick assessment

### 🔧 Improvements
- Auto-conversion of text-formatted numeric columns
- Backward compatibility with old config files
- Improved error messages and troubleshooting
- R 4.2+ compatibility
- Enhanced GUI with full console output capture

### 🐛 Bug Fixes
- Fixed Wilson interval flag handling
- Fixed routed question numeric conversion
- Fixed values/weights alignment for weighted data
- Corrected NPS variance calculation

---

## Documentation

### For Users

| Document | Description |
|----------|-------------|
| **[User Manual](USER_MANUAL.md)** | Complete guide to using the module |
| **[Quick Start](QUICK_START.md)** | Get started in 5 minutes |
| **[Example Workflows](EXAMPLE_WORKFLOWS.md)** | Common use cases with examples |
| **[NPS Guide](NPS_PHASE2_IMPLEMENTATION.md)** | Net Promoter Score analysis |
| **[Representativeness Guide](REPRESENTATIVENESS_GUIDE.md)** | Quota checking and weight diagnostics |

### For Developers

| Document | Description |
|----------|-------------|
| **[Technical Documentation](TECHNICAL_DOCUMENTATION.md)** | Architecture and code structure |
| **[Testing Guide](TESTING_GUIDE.md)** | How to run and write tests |
| **[Maintenance Guide](MAINTENANCE_GUIDE.md)** | Maintaining and extending the module |

### Reference

| Document | Description |
|----------|-------------|
| **[External Review Fixes](EXTERNAL_REVIEW_FIXES.md)** | Bug fixes from external audit |
| **[Real Config Test](REAL_CONFIG_TEST_INSTRUCTIONS.md)** | Backward compatibility testing |

---

## Installation

### Prerequisites

- R 4.0 or higher (R 4.2+ recommended)
- Required packages: `readxl`, `writexl`, `openxlsx`
- Optional packages: `data.table` (for faster CSV loading)

### Setup

1. **Clone or download** the Turas repository
2. **Install dependencies**:

```r
install.packages(c("readxl", "writexl", "openxlsx", "data.table"))
```

3. **Verify installation**:

```r
setwd("/path/to/Turas/modules/confidence")
source("R/00_main.R")
cat("✓ Module loaded successfully\n")
```

---

## Basic Usage

### Step 1: Prepare Configuration File

Create an Excel file with these sheets:

1. **File_Paths** - Data file location and output path
2. **Study_Settings** - Confidence level, bootstrap iterations, etc.
3. **Question_Analysis** - Questions to analyze (max 200)
4. **Population_Margins** - (Optional) Quota targets for representativeness

See **[User Manual](USER_MANUAL.md)** for detailed configuration instructions.

### Step 2: Run Analysis

**Option A - GUI:**
```r
setwd("/path/to/Turas")
source("modules/confidence/run_confidence_gui.R")
```

**Option B - Command Line:**
```r
source("/path/to/Turas/modules/confidence/R/00_main.R")
result <- run_confidence_analysis(
  config_path = "/path/to/config.xlsx",
  verbose = TRUE
)
```

### Step 3: Review Results

The module generates an Excel workbook with:

- **Summary** - Overview of all results
- **Study_Level** - Sample size, DEFF, weight diagnostics
- **Proportions_Detail** - Full results for proportion questions
- **Means_Detail** - Full results for mean questions
- **NPS_Detail** - Net Promoter Score results (if applicable)
- **Representativeness_Weights** - Quota checks (if applicable)
- **Methodology** - Statistical methods documentation
- **Warnings** - Any issues encountered
- **Inputs** - Configuration used for reproducibility

---

## Examples

### Example 1: Simple Unweighted Analysis

```r
# Analyze customer satisfaction survey (unweighted)
run_confidence_analysis(
  config_path = "projects/CSAT_Q4/csat_confidence_config.xlsx",
  verbose = TRUE
)
```

### Example 2: Weighted NPS with Representativeness

```r
# NPS study with quota checking
# Config includes:
# - Weight variable
# - NPS questions with promoter/detractor codes
# - Population_Margins sheet with quota targets

run_confidence_analysis(
  config_path = "projects/NPS_Wave5/nps_confidence_config.xlsx",
  verbose = TRUE
)
```

### Example 3: Means Analysis with Bootstrap

```r
# Analyze rating scores with bootstrap CIs
# Config specifies:
# - Statistic_Type = "mean"
# - Run_Bootstrap = "Y"
# - Bootstrap_Iterations = 10000

run_confidence_analysis(
  config_path = "projects/Product_Ratings/ratings_config.xlsx",
  verbose = TRUE
)
```

---

## Configuration Summary

### Required Sheets

| Sheet | Purpose |
|-------|---------|
| **File_Paths** | Data file path, output location |
| **Study_Settings** | Confidence level, methods, iterations |
| **Question_Analysis** | Questions to analyze (max 200 rows) |

### Optional Sheets

| Sheet | Purpose |
|-------|---------|
| **Population_Margins** | Quota targets for representativeness analysis |

### Key Settings

| Setting | Options | Default |
|---------|---------|---------|
| Confidence Level | 0.90, 0.95, 0.99 | 0.95 |
| Bootstrap Iterations | 1000-10000 | 5000 |
| Decimal Separator | . or , | . |
| Calculate Effective n | Y/N | Y |

---

## Statistical Methods

### Proportions

**Normal Approximation (MOE):**
```
SE = sqrt(p(1-p) / n_eff)
CI = p ± z * SE
```

**Wilson Score:**
Recommended for small samples or extreme proportions (p near 0 or 1)

**Bootstrap:**
- Resamples data with replacement
- Handles weighted data correctly
- Provides empirical confidence intervals

**Bayesian:**
- Uses Beta-Binomial conjugate prior
- Can incorporate prior beliefs
- Provides credible intervals

### Means

**Student's t:**
```
SE = SD / sqrt(n_eff)
CI = mean ± t * SE
```

**Bootstrap:**
- Weighted resampling for complex designs
- No distributional assumptions

**Bayesian:**
- Normal-Normal conjugate prior
- Flexible for incorporating prior knowledge

### NPS

**Calculation:**
```
NPS = %Promoters - %Detractors
Range: -100 to +100
```

**Standard Error:**
Uses variance of difference formula accounting for correlation

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Config file not found" | Check file path, ensure OneDrive is synced |
| "Data file not accessible" | Verify data path in File_Paths sheet |
| "Question not found in data" | Check Question_ID matches data column names |
| "Non-numeric values for mean" | Ensure mean questions contain numbers |
| "Weight variable not found" | Check weight column name in data |

See **[User Manual](USER_MANUAL.md)** for detailed troubleshooting.

---

## Testing

### Run Test Suite

```r
# Test 1: Representativeness
source("modules/confidence/tests/test_representativeness.R")

# Test 2: NPS
source("modules/confidence/tests/test_nps.R")

# Test 3: Weighted data
source("modules/confidence/tests/test_weighted_data.R")

# Test 4: Real config (backward compatibility)
source("modules/confidence/tests/test_real_config_ccpb.R")
```

All tests should pass without errors.

---

## Performance

**Typical Analysis:**
- 50 questions, 1000 respondents: ~30 seconds
- 100 questions, 5000 respondents: ~2 minutes
- Bootstrap (10,000 iterations): +1-2 minutes per question

**Optimizations:**
- Uses `data.table::fread()` for fast CSV loading
- Vectorized operations where possible
- Efficient weighted calculations

---

## Limitations

- Maximum 200 questions per analysis (prevents accidental large runs)
- Bootstrap can be slow for very large datasets (>50,000 respondents)
- Representativeness checking requires manually prepared quota targets
- Currently analyzes "Total" column only (banner columns planned for Phase 3)

---

## Version History

### v2.0.0 (December 2025)
- ✅ Net Promoter Score (NPS) support
- ✅ Quota representativeness checking
- ✅ Weight concentration diagnostics
- ✅ Auto-conversion of text-formatted numerics
- ✅ Backward compatibility improvements
- ✅ GUI console output fixes
- ✅ R 4.2+ compatibility

### v1.0.0 (November 2025)
- ✅ Initial release with proportions and means
- ✅ Four confidence interval methods
- ✅ Weighted data support
- ✅ Excel output generation
- ✅ Design effect calculations

---

## Support

### Getting Help

1. **Check documentation** - See links above
2. **Review examples** - [Example Workflows](EXAMPLE_WORKFLOWS.md)
3. **Run tests** - Verify module is working correctly
4. **Check warnings** - Excel output includes Warnings sheet

### Contributing

This module is part of the Turas analytics platform. For bug reports or feature requests, contact the Turas development team.

---

## License

Part of Turas Analytics Platform
© 2025 All Rights Reserved

---

## Acknowledgments

- External review and bug identification by ChatGPT
- Statistical methods based on established literature
- Design inspired by commercial crosstab tools
- Built on proven Turas weighting infrastructure

---

**Module Status:** ✅ Production Ready

**Last Updated:** December 1, 2025

**Maintainer:** Turas Development Team
