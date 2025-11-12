# Turas Confidence Analysis Module

## Status: Foundation Complete (In Development)

An independent, optional module for statistical confidence analysis in the Turas survey analytics platform.

## Version

**v1.0.0-alpha** (Foundation Phase)

## Purpose

Provides additional statistical confidence checks for crosstab results, including:
- Margin of Error (MOE) with normal approximation and Wilson score intervals
- Bootstrap confidence intervals
- Bayesian credible intervals
- Study-level effective sample size and design effect calculations
- Multiple comparison adjustments (Bonferroni, Holm, FDR)
- Support for proportions, means, and Net Promoter Score (NPS)

## Architecture

### Completed Modules

- **utils.R** - Utility functions (decimal separator formatting, validation helpers)
- **01_load_config.R** - Configuration loading and validation (enforces 200 question limit)
- **02_load_data.R** - Data loading (CSV + XLSX support)
- **03_study_level.R** - DEFF and effective sample size calculations

### In Development

- **04_proportions.R** - Proportion-based confidence methods
- **05_means.R** - Mean-based confidence methods
- **06_multiple_comparisons.R** - P-value adjustments
- **07_output.R** - Excel output generation with decimal separator support
- **00_main.R** - Main orchestration script

## Key Features

### Implemented

✅ **200 Question Limit**: Enforced in configuration validation
✅ **Decimal Separator Support**: Period (.) or comma (,) for international locales
✅ **Weighted Data Support**: Handles survey weights with DEFF calculation
✅ **Data Format Flexibility**: CSV and XLSX input files
✅ **Comprehensive Validation**: Input validation with clear error messages
✅ **Reuses Turas Code**: Leverages proven weighting.R functions

### Planned

⏳ Margin of Error (MOE) - Normal and Wilson score
⏳ Bootstrap confidence intervals (5000-10000 iterations)
⏳ Bayesian credible intervals (with informed/uninformed priors)
⏳ NPS confidence intervals
⏳ Multiple comparison adjustments
⏳ Excel output with multiple sheets

## Directory Structure

```
/modules/confidence/
├── R/
│   ├── utils.R                  # ✅ Utility functions
│   ├── 01_load_config.R         # ✅ Configuration loading
│   ├── 02_load_data.R           # ✅ Data loading
│   ├── 03_study_level.R         # ✅ DEFF calculations
│   ├── 04_proportions.R         # ⏳ In development
│   ├── 05_means.R               # ⏳ Planned
│   ├── 06_multiple_comparisons.R # ⏳ Planned
│   ├── 07_output.R              # ⏳ Planned
│   └── 00_main.R                # ⏳ Planned
├── tests/
│   ├── test_utils.R             # ✅ Comprehensive utils tests
│   ├── test_01_load_config.R    # ✅ Config validation tests
│   └── ...                      # ⏳ More tests coming
├── examples/
│   └── ...                      # ⏳ Example configs coming
├── docs/
│   ├── turas_confidence_analysis_design_spec_v1.0-3.md  # ✅ Full design spec
│   └── ...                      # ⏳ User guide coming
└── README.md                    # ✅ This file
```

## Configuration

The module requires a single Excel configuration file (`confidence_config.xlsx`) with 3 sheets:

### 1. File_Paths
Points to existing Turas files and output location

### 2. Study_Settings
Study-level settings:
- Calculate effective sample size (Y/N)
- Multiple comparison adjustment (Y/N)
- Adjustment method (Bonferroni/Holm/FDR)
- Bootstrap iterations (1000-10000)
- Confidence level (0.90/0.95/0.99)
- Decimal separator (. or ,)

### 3. Question_Analysis
Question-level specifications (max 200 rows):
- Question_ID
- Statistic_Type (proportion/mean/nps)
- Categories (for proportions)
- Run_MOE, Run_Bootstrap, Run_Credible (Y/N)
- Prior specifications (for Bayesian methods)

## Dependencies

**Required:**
- R >= 4.0
- readxl >= 1.4.0

**Optional (but recommended):**
- data.table (for fast CSV loading)
- openxlsx (for tests)

## Testing Strategy

✅ **Test as we go** - Each module has comprehensive tests before moving to next
✅ **Edge cases** - Tests cover n=1, p=0, p=1, extreme proportions, etc.
✅ **200 question limit** - Enforced and tested
✅ **Decimal separators** - Both period and comma tested

## Design Principles

1. **Independent** - Runs standalone, doesn't modify existing Turas modules
2. **Total only** - Phase 1 calculates confidence for overall sample (banner columns in Phase 2)
3. **Modular** - Each R script focuses on one area
4. **Reuse existing code** - Leverages proven Turas functions (e.g., calculate_effective_n)
5. **Quality over speed** - Thorough testing, clear code, comprehensive documentation

## Development Status

**Phase 1A: Foundation ✅ COMPLETE**
- [x] Directory structure
- [x] utils.R with validation and formatting
- [x] Config loading with full validation
- [x] Data loading (CSV + XLSX)
- [x] Study-level calculations (DEFF, effective n)

**Phase 1B: Proportions (Next)**
- [ ] MOE (Normal approximation)
- [ ] Wilson score interval
- [ ] Bootstrap confidence intervals
- [ ] Bayesian credible intervals

**Phase 1C: Means**
- [ ] t-distribution CI
- [ ] Bootstrap for means
- [ ] Bayesian for means

**Phase 1D: NPS (if time permits)**
- [ ] NPS calculations
- [ ] Confidence intervals for NPS

**Phase 1E: Output & Integration**
- [ ] Multiple comparison adjustments
- [ ] Excel output generation
- [ ] Main orchestration script
- [ ] Integration testing

**Phase 1F: Documentation**
- [ ] User guide
- [ ] Technical documentation
- [ ] Example files

## References

- Kish, L. (1965). Survey Sampling. Wiley.
- Agresti, A., & Coull, B. A. (1998). Approximate is better than "exact" for interval estimation of binomial proportions.
- Wilson, E. B. (1927). Probable inference, the law of succession, and statistical inference.

## Author

Turas Confidence Module Team
Date: 2025-11-12

## License

Part of the Turas Survey Analytics Platform
