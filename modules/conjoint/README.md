# Turas Conjoint Analysis Module

## Overview

The Conjoint Analysis module estimates consumer preferences for product/service attributes using experimental choice or rating data. It calculates part-worth utilities and attribute importance scores using regression-based methods.

## Features

- **Rating-Based Conjoint**: OLS regression on preference ratings
- **Choice-Based Conjoint**: Multinomial logit on discrete choices (TODO)
- **Part-Worth Utilities**: Zero-centered utility estimates for each attribute level
- **Attribute Importance**: Relative importance scores (% of total utility range)
- **Formatted Output**: Excel workbook with all results and visualizations

## Quick Start

```r
# Source the module
source("modules/conjoint/R/00_main.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/02_validation.R")
source("modules/conjoint/R/03_analysis.R")
source("modules/conjoint/R/04_output.R")

# Run analysis
results <- run_conjoint_analysis(
  config_file = "conjoint_config.xlsx",
  data_file = "survey_data.csv",
  output_file = "conjoint_results.xlsx"
)

# View importance scores
print(results$importance)

# View utilities
print(results$utilities)
```

## Configuration File Format

Create an Excel file with the following sheets:

### Sheet 1: Settings
| Setting | Value |
|---------|-------|
| analysis_type | rating |
| rating_variable | preference_rating |
| respondent_id_column | resp_id |
| profile_id_column | profile_id |

### Sheet 2: Attributes
| AttributeName | NumLevels | LevelNames |
|---------------|-----------|------------|
| Price | 3 | $10, $15, $20 |
| Brand | 2 | Brand A, Brand B |
| Feature | 3 | Basic, Standard, Premium |

### Sheet 3: Design (Optional)
Can contain orthogonal design matrix if using specific experimental design.

## Data File Format

CSV or Excel with one row per profile rating:

| resp_id | profile_id | Price | Brand | Feature | preference_rating |
|---------|------------|-------|-------|---------|------------------|
| 1 | 1 | $10 | Brand A | Basic | 7 |
| 1 | 2 | $15 | Brand B | Premium | 9 |
| 2 | 1 | $10 | Brand A | Basic | 6 |

## Methodology

### Rating-Based Approach (OLS)
1. Code attributes as factors (dummy coding, first level = reference)
2. Fit linear model: `rating ~ attr1 + attr2 + ... + attrN`
3. Extract coefficients as part-worth utilities
4. Zero-center utilities within each attribute
5. Calculate importance from utility ranges

### Statistical Formula
```
Utility(Level) = β_level - mean(β_attribute)
Importance(Attribute) = Range(Utilities_attribute) / Σ Range(Utilities_all)
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

## Limitations (Current Version)

- ✅ Rating-based conjoint implemented
- ❌ Choice-based conjoint (TODO - requires multinomial logit)
- ❌ Mixed logit for heterogeneity (TODO)
- ❌ Interaction effects (TODO)
- ❌ Market simulation (TODO)

## Future Enhancements

1. Implement choice-based conjoint (multinomial/conditional logit)
2. Add hierarchical Bayes for individual-level utilities
3. Support for interaction terms
4. Market share simulation
5. Holdout validation
6. Visualization of utility curves

## Dependencies

- `openxlsx`: Excel I/O
- `haven` (optional): SPSS/Stata files
- Base R `stats` for regression

## References

- Green, P. E., & Srinivasan, V. (1978). Conjoint analysis in consumer research
- Orme, B. K. (2010). Getting Started with Conjoint Analysis
- Sawtooth Software technical papers

---

**Version**: 1.0.0 (Initial Implementation)
**Status**: Beta - Rating-based method functional, choice-based in development
**Last Updated**: 2025-11-18
