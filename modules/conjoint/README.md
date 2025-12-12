# Turas Conjoint Analysis Module

## Overview

The Conjoint Analysis module estimates consumer preferences for product/service attributes using experimental choice or rating data. It calculates part-worth utilities and attribute importance scores using regression-based methods.

## Features

- **Direct Alchemer Import**: Import raw Alchemer CBC exports without preprocessing (NEW in v2.1)
- **Rating-Based Conjoint**: OLS regression on preference ratings ✅
- **Choice-Based Conjoint**: Conditional logit on discrete choices ✅ (Alchemer-style)
- **Part-Worth Utilities**: Zero-centered utility estimates for each attribute level
- **Attribute Importance**: Relative importance scores (% of total utility range)
- **Formatted Output**: Excel workbook with all results and visualizations
- **Model Fit Statistics**: McFadden's R², hit rate, AIC, BIC
- **Auto Level Cleaning**: Automatic cleaning of Alchemer level names (e.g., "Low_071" → "Low")

## Quick Start

### Option 1: Launch from Turas Suite (Recommended)

```r
# Launch Turas GUI
source("launch_turas.R")

# Click "Launch Conjoint" button
# Select your project directory and config file
# Run analysis from GUI
```

### Option 2: Command Line

```r
# Source the module (loads all components)
source("modules/conjoint/R/00_main.R")

# Run analysis (paths can be specified in config file)
results <- run_conjoint_analysis(
  config_file = "conjoint_config.xlsx"
)

# Or override paths
results <- run_conjoint_analysis(
  config_file = "conjoint_config.xlsx",
  data_file = "survey_data.csv",
  output_file = "conjoint_results.xlsx"
)

# View importance scores
print(results$importance)

# View utilities
print(results$utilities)

# View model fit (choice-based includes McFadden R² and hit rate)
print(results$diagnostics$fit_statistics)
```

### Example: Alchemer Choice-Based Conjoint (NEW in v2.1)

```r
# For raw Alchemer CBC export data - no preprocessing needed!
# Just set data_source = "alchemer" in your config

# Option A: Full analysis with config file
results <- run_conjoint_analysis(
  config_file = "alchemer_config.xlsx"   # Contains data_source = "alchemer"
)

# Option B: Standalone import + analysis
df <- import_alchemer_conjoint("DE_noodle_conjoint_raw.xlsx")
config <- create_config_from_alchemer(df, "auto_config.xlsx")

# Top 3 most important attributes
top3 <- head(results$importance[order(-results$importance$Importance), ], 3)
print(top3)
```

### Alchemer Configuration Setup

For Alchemer CBC exports, add these settings to your config file:

| Setting | Value | Description |
|---------|-------|-------------|
| data_source | alchemer | Enable Alchemer import |
| clean_alchemer_levels | TRUE | Auto-clean level names |
| data_file | DE_noodle_raw.xlsx | Your Alchemer export file |
| output_file | results.xlsx | Output file path |

The module automatically transforms Alchemer format:
- `ResponseID` → `resp_id`
- `SetNumber` + `ResponseID` → `choice_set_id`
- `CardNumber` → `alternative_id`
- `Score` (0/100) → `chosen` (0/1)
- Level names cleaned: "Low_071" → "Low", "MSG_Present" → "Present"

## Configuration File Format

Create an Excel file with the following sheets:

### Sheet 1: Settings

**For Rating-Based:**
| Setting | Value |
|---------|-------|
| analysis_type | rating |
| rating_variable | preference_rating |
| respondent_id_column | resp_id |
| profile_id_column | profile_id |

**For Choice-Based (Alchemer-style):**
| Setting | Value |
|---------|-------|
| analysis_type | choice |
| choice_set_column | choice_set_id |
| chosen_column | chosen |
| respondent_id_column | resp_id |

### Sheet 2: Attributes
| AttributeName | NumLevels | LevelNames |
|---------------|-----------|------------|
| Price | 3 | $10, $15, $20 |
| Brand | 2 | Brand A, Brand B |
| Feature | 3 | Basic, Standard, Premium |

### Sheet 3: Design (Optional)
Can contain orthogonal design matrix if using specific experimental design.

## Data File Format

### Rating-Based Data
CSV or Excel with one row per profile rating:

| resp_id | profile_id | Price | Brand | Feature | preference_rating |
|---------|------------|-------|-------|---------|------------------|
| 1 | 1 | $10 | Brand A | Basic | 7 |
| 1 | 2 | $15 | Brand B | Premium | 9 |
| 2 | 1 | $10 | Brand A | Basic | 6 |

### Choice-Based Data (Alchemer Format)
CSV or Excel with one row per alternative in each choice set:

| resp_id | choice_set_id | alternative_id | Price | Brand | Feature | chosen |
|---------|---------------|----------------|-------|-------|---------|--------|
| 1 | 1 | 1 | $10 | Brand A | Basic | 0 |
| 1 | 1 | 2 | $15 | Brand B | Premium | 1 |
| 1 | 1 | 3 | $20 | Brand A | Standard | 0 |
| 1 | 2 | 1 | $10 | Brand B | Standard | 1 |
| 1 | 2 | 2 | $15 | Brand A | Premium | 0 |
| 1 | 2 | 3 | $20 | Brand B | Basic | 0 |

**Note**: Each choice set has multiple rows (one per alternative), with `chosen=1` for the selected option.

## Methodology

### Rating-Based Approach (OLS)
1. Code attributes as factors (dummy coding, first level = reference)
2. Fit linear model: `rating ~ attr1 + attr2 + ... + attrN`
3. Extract coefficients as part-worth utilities
4. Zero-center utilities within each attribute
5. Calculate importance from utility ranges

### Choice-Based Approach (Conditional Logit) ✅
1. Code attributes as factors (dummy coding, first level = reference)
2. Fit conditional logit model: `P(chosen) ~ attr1 + attr2 + ... + strata(choice_set_id)`
3. Extract coefficients as part-worth utilities (log-odds scale)
4. Zero-center utilities within each attribute
5. Calculate importance from utility ranges
6. Calculate hit rate (% of choices correctly predicted)

### Statistical Formulas
```
# Utilities (both methods)
Utility(Level) = β_level - mean(β_attribute)
Importance(Attribute) = Range(Utilities_attribute) / Σ Range(Utilities_all)

# Choice probability (choice-based)
P(alternative i chosen) = exp(Utility_i) / Σ exp(Utility_j) for j in choice set

# McFadden's R² (choice-based)
R² = 1 - (LogLik_full / LogLik_null)
```

## Output

The module creates an Excel workbook with four sheets:

1. **Attribute Importance**: Ranked importance scores (%)
2. **Part-Worth Utilities**: Utility values for each level
3. **Model Fit**: R², RMSE, and other fit statistics
4. **Configuration**: Study design summary

## Interpretation

- **Part-Worth Utilities**: Higher values indicate stronger preference
- **Attribute Importance**: % contribution to overall preference
- **Zero-Centered**: Utilities sum to zero within each attribute

## Implementation Status

### Core Features (Production Ready)
- ✅ Rating-based conjoint (OLS regression)
- ✅ Choice-based conjoint (mlogit, clogit, auto-selection)
- ✅ Multi-respondent data support with robust validation
- ✅ None option auto-detection and handling
- ✅ Confidence intervals and significance testing
- ✅ Comprehensive diagnostics (McFadden R², hit rate, convergence)
- ✅ Interactive market simulator with Excel formulas
- ✅ GUI integration via Turas launcher

### Advanced Features (Available)
- ✅ Interaction effects analysis
- ✅ Best-worst scaling support
- ✅ Market share prediction and sensitivity analysis
- ✅ Product optimization algorithms
- ✅ Comprehensive test suite (50+ tests)

### Future Enhancements
- ⏳ Mixed logit for heterogeneity
- ⏳ Hierarchical Bayes for individual utilities (framework exists)
- ⏳ Visualization (utility curves, trade-off charts)

## Future Enhancements

1. Add hierarchical Bayes for individual-level utilities (HB-CBC)
2. Mixed logit for random utility parameters (capture heterogeneity)
3. Support for interaction terms between attributes
4. Market share simulation and "what-if" scenarios
5. Holdout validation and cross-validation
6. Visualization: utility curves, trade-off charts, importance plots

## Dependencies

### Required
- `mlogit`: Primary estimation method for choice-based conjoint
- `dfidx`: Data indexing for mlogit (required for mlogit >= 1.1-0)
- `survival`: Fallback conditional logit method
- `openxlsx`: Excel I/O for config and output files
- `dplyr`: Data manipulation

### Optional
- `haven`: SPSS/Stata file support (.sav, .dta)
- `shiny` + `shinyFiles`: GUI interface (for launch_turas integration)
- `bayesm` or `RSGHB`: Hierarchical Bayes (future)

## References

- Green, P. E., & Srinivasan, V. (1978). Conjoint analysis in consumer research
- Orme, B. K. (2010). Getting Started with Conjoint Analysis
- Sawtooth Software technical papers

---

## Documentation

- **README.md** (this file): Overview and quick start
- **TUTORIAL.md**: Step-by-step tutorial with coffee example
- **MAINTENANCE_GUIDE.md**: Comprehensive technical documentation for maintenance
- **IMPLEMENTATION_STATUS.md**: Feature status and development history
- **examples/QUICK_START_GUIDE.md**: Detailed usage examples

---

**Version**: 2.1.0 (Alchemer Integration)
**Status**: Production - Full-featured conjoint analysis with market simulator
**Compatibility**:
- Direct Alchemer CBC export import ✅ (NEW in v2.1)
- Alchemer/SurveyGizmo CBC format ✅
- Generic choice-based format ✅
- Multi-respondent datasets ✅
- Rating-based conjoint ✅
**Last Updated**: 2025-12-12
**New in v2.1**:
- Direct Alchemer CBC import (05_alchemer_import.R)
- Automatic level name cleaning
- Enhanced mlogit diagnostics
- Configurable zero-centering
