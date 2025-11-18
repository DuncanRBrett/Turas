# Turas Conjoint Analysis Module

## Overview

The Conjoint Analysis module estimates consumer preferences for product/service attributes using experimental choice or rating data. It calculates part-worth utilities and attribute importance scores using regression-based methods.

## Features

- **Rating-Based Conjoint**: OLS regression on preference ratings ✅
- **Choice-Based Conjoint**: Conditional logit on discrete choices ✅ (Alchemer-style)
- **Part-Worth Utilities**: Zero-centered utility estimates for each attribute level
- **Attribute Importance**: Relative importance scores (% of total utility range)
- **Formatted Output**: Excel workbook with all results and visualizations
- **Model Fit Statistics**: McFadden's R², hit rate, AIC, BIC

## Quick Start

```r
# Source the module
source("modules/conjoint/R/00_main.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/02_validation.R")
source("modules/conjoint/R/03_analysis.R")
source("modules/conjoint/R/04_output.R")

# Run analysis (works for both rating-based and choice-based)
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
print(results$fit)
```

### Example: Alchemer Choice-Based Conjoint

```r
# For Alchemer CBC export data
results <- run_conjoint_analysis(
  config_file = "alchemer_config.xlsx",  # Set analysis_type = "choice"
  data_file = "alchemer_choices.csv",    # One row per alternative
  output_file = "cbc_results.xlsx"
)

# Top 3 most important attributes
top3 <- head(results$importance[order(-results$importance$Importance), ], 3)
print(top3)
```

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

- ✅ Rating-based conjoint (OLS regression)
- ✅ Choice-based conjoint (conditional logit) - **Alchemer-compatible**
- ❌ Mixed logit for heterogeneity (TODO)
- ❌ Hierarchical Bayes for individual utilities (TODO)
- ❌ Interaction effects (TODO)
- ❌ Market simulation (TODO)

## Future Enhancements

1. Add hierarchical Bayes for individual-level utilities (HB-CBC)
2. Mixed logit for random utility parameters (capture heterogeneity)
3. Support for interaction terms between attributes
4. Market share simulation and "what-if" scenarios
5. Holdout validation and cross-validation
6. Visualization: utility curves, trade-off charts, importance plots

## Dependencies

- `openxlsx`: Excel I/O
- `survival`: Conditional logit (choice-based conjoint)
- `haven` (optional): SPSS/Stata files
- Base R `stats`: Regression (rating-based conjoint)

## References

- Green, P. E., & Srinivasan, V. (1978). Conjoint analysis in consumer research
- Orme, B. K. (2010). Getting Started with Conjoint Analysis
- Sawtooth Software technical papers

---

**Version**: 1.1.0 (Choice-Based CBC Added)
**Status**: Production - Both rating-based and choice-based methods fully functional
**Compatibility**: Alchemer/SurveyGizmo CBC data format supported
**Last Updated**: 2025-11-18
