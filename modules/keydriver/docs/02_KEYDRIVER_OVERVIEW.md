# Turas Key Driver Analysis - Module Overview

**Version:** 10.4
**Last Updated:** 20 March 2026

---

## What is Key Driver Analysis?

Key Driver Analysis answers the fundamental business question: **"Which factors matter most?"**

Given an outcome metric (e.g., overall satisfaction) and multiple potential drivers (e.g., product quality, service, price), the analysis determines:

1. **How much** each driver contributes to the outcome (importance scores)
2. **The direction** of each relationship (positive/negative)
3. **The relative ranking** of drivers (prioritization)
4. **Model diagnostics** (fit quality, multicollinearity)

---

## Key Capabilities

### Nine Statistical Methods

Turas KeyDriver uses multiple complementary methods because no single approach is perfect:

| Method | Approach | Best For |
|--------|----------|----------|
| **Shapley Values** | Game-theoretic fair R² allocation | Most robust, recommended for prioritization |
| **Relative Weights** | Orthogonal transformation (Johnson 2000) | High multicollinearity situations |
| **Beta Weights** | Standardized regression coefficients | Traditional, widely understood |
| **Correlations** | Bivariate relationships | Simple baseline |
| **SHAP** | XGBoost + TreeSHAP | Non-linear relationships, interactions |
| **Elastic Net** | Penalized regression (glmnet) | Variable selection, high-dimensional driver sets |
| **NCA** | Necessary Condition Analysis (NCA package) | Identifying necessary (not just sufficient) drivers |
| **Dominance Analysis** | General/conditional/complete dominance (domir) | Pairwise driver comparisons, Shapley-adjacent |
| **GAM** | Generalized Additive Models (mgcv) | Detecting and quantifying nonlinear effects |

By comparing all nine, you get **robust consensus** on driver importance.

### Config-Driven Custom Slides (v10.4)

The HTML report now supports config-driven custom slides, allowing analysts to inject additional commentary, methodology notes, or client-specific content into the report output via the configuration file.

### Per-Table CSV/Excel Export (v10.4)

Every data table in the HTML report now includes individual export buttons for CSV and Excel download, enabling stakeholders to extract specific results without opening the full workbook.

### Configurable Analysis Thresholds (v10.4)

Effect size benchmarks, VIF thresholds, and R² quality tiers can now be customised in the configuration file rather than relying on hardcoded defaults. This allows analysts to apply domain-specific standards.

### Survey Weights Support

Full weighted analysis throughout the pipeline:
- Weighted correlations
- Weighted regression
- Weighted Shapley values
- Weighted relative weights
- Weighted SHAP (XGBoost)

### Multicollinearity Diagnostics

Variance Inflation Factor (VIF) calculated for all drivers:
- **VIF < 5**: No concern
- **VIF 5-10**: Moderate, monitor results
- **VIF > 10**: High - consider removing or combining drivers

### SHAP Analysis (Machine Learning)

When enabled, fits XGBoost model and calculates SHAP values:
- Captures non-linear relationships
- Detects driver interactions
- Provides individual-level explanations
- Generates beeswarm, waterfall, and dependence plots

### Elastic Net Variable Selection (v10.4)

Penalized regression via glmnet that automatically selects the most relevant drivers by shrinking less important coefficients to zero. Combines L1 (lasso) and L2 (ridge) penalties, controlled by the alpha parameter. Useful when the driver set is large or when you want a parsimonious model that highlights only the drivers that genuinely contribute.

### Necessary Condition Analysis (v10.4)

NCA identifies drivers that are *necessary* (not just correlated) for high outcome levels. Using the CE-FDH ceiling technique, it detects bottleneck relationships where a minimum level of a driver is required before high performance is achievable. Results include necessity effect sizes and a bottleneck table showing the minimum driver level needed for each outcome target.

### Dominance Analysis (v10.4)

Dominance analysis (via the domir package) provides a rigorous pairwise comparison of drivers through general, conditional, and complete dominance rankings. Closely related to Shapley value decomposition, it offers an alternative lens on relative importance by examining whether one driver consistently outperforms another across all possible subset models.

### GAM Nonlinear Effects (v10.4)

Generalized Additive Models (via mgcv) fit smooth nonlinear terms for each driver, revealing curved and threshold relationships that linear methods miss. The effective degrees of freedom (EDF) for each smooth term indicate the degree of nonlinearity (EDF > 1.5 suggests meaningful curvature). Deviance explained is reported alongside linear R² for direct comparison.

### Quadrant Analysis (IPA)

Importance-Performance Analysis places drivers in actionable quadrants:

```
        HIGH IMPORTANCE
             |
   CONCENTRATE    KEEP UP
   HERE           GOOD WORK
             |
-------------+-------------  PERFORMANCE
             |
   LOW            POSSIBLE
   PRIORITY       OVERKILL
             |
        LOW IMPORTANCE
```

---

## When to Use Key Driver Analysis

**Perfect For:**
- Customer satisfaction drivers
- Brand health analysis
- Employee engagement factors
- Product feature prioritization
- NPS driver identification
- Any "what drives X?" question

**Requirements:**
- Numeric outcome variable (1-10 scale recommended)
- 3-15 numeric driver variables
- Sample size: n ≥ max(30, 10 × number of drivers)
- Linear relationships assumed (or use SHAP for non-linear)

---

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                  TURAS KEY DRIVER                           │
│                                                             │
│  Configuration    Survey Data                               │
│  (xlsx)           (csv/xlsx/sav)                            │
│      │                 │                                    │
│      └────────┬────────┘                                    │
│               ▼                                             │
│      ┌────────────────┐                                     │
│      │   Validation   │  Sample size, VIF, zero variance    │
│      └────────────────┘                                     │
│               │                                             │
│               ▼                                             │
│      ┌────────────────┐                                     │
│      │   Regression   │  OLS model fitting                  │
│      └────────────────┘                                     │
│               │                                             │
│               ▼                                             │
│      ┌────────────────┐                                     │
│      │  5 Importance  │  Shapley, RelWeights, Beta,         │
│      │    Methods     │  Correlations, SHAP                 │
│      └────────────────┘                                     │
│               │                                             │
│               ▼                                             │
│      ┌────────────────┐                                     │
│      │    Output      │  Excel with charts                  │
│      └────────────────┘                                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Output Example

### Importance Summary

```
Driver               Shapley  RelWeight  Beta   SHAP   Correlation
────────────────────────────────────────────────────────────────────
Product Quality      32.5%    31.8%      28.4%  35.2%  0.72
Customer Service     24.1%    25.3%      26.1%  22.8%  0.68
Value for Money      19.8%    18.9%      22.3%  18.5%  0.58
Brand Reputation     14.2%    15.1%      13.8%  14.1%  0.51
Delivery Speed        9.4%     8.9%       9.4%   9.4%  0.44
```

### Interpretation Thresholds

| Shapley Value | Interpretation | Priority |
|---------------|----------------|----------|
| > 20% | Major driver | **High priority** - Fix this first |
| 10-20% | Moderate driver | Secondary priority |
| < 10% | Minor driver | Limited impact |

---

## Strengths

1. **Multiple Methods**: Nine complementary approaches for cross-validation of importance rankings
2. **Robust to Multicollinearity**: Shapley and Relative Weights handle correlated drivers
3. **Survey Weights**: Full support throughout analysis
4. **Machine Learning Option**: SHAP captures non-linear effects
5. **Actionable Output**: Quadrant charts for strategic prioritization
6. **Comprehensive Diagnostics**: VIF, R², model fit statistics

---

## Limitations

1. **Linear Assumption**: Traditional methods assume linear relationships (use SHAP for non-linear)
2. **Correlation ≠ Causation**: Identifies associations, not causes
3. **Additive Effects**: Doesn't model interactions (except SHAP)
4. **Measured Variables Only**: Can't assess omitted drivers
5. **Shapley Limit**: Maximum 15 drivers for exact computation (2^15 models)
6. **Sample Size**: Requires n ≥ max(30, 10×k) complete cases

---

## Comparison with Alternatives

### vs. Simple Regression

| Aspect | Simple Regression | Turas KeyDriver |
|--------|-------------------|-----------------|
| Methods | 1 (beta weights) | 9 complementary |
| Multicollinearity | Problematic | Handled (Shapley, RelWeights) |
| Diagnostics | Manual | Automated (VIF, R²) |
| Output | Coefficients only | Full Excel workbook |
| Non-linear | No | Yes (SHAP option) |

### vs. R relaimpo Package

| Aspect | relaimpo | Turas KeyDriver |
|--------|----------|-----------------|
| Methods | 6+ | 9 (most useful) |
| Survey Weights | Limited | Full support |
| SHAP/ML | No | Yes |
| Output | R objects | Excel workbook |
| GUI | No | Yes |
| Quadrant Analysis | No | Yes |

### vs. SPSS Driver Analysis

| Aspect | SPSS | Turas KeyDriver |
|--------|------|-----------------|
| Cost | Licensed | Open source |
| Methods | Varies | 9 standardized |
| SHAP | No | Yes |
| Automation | Limited | Full scripting |
| Output | Various | Standardized Excel |

---

## Version History

| Version | Date | Key Features |
|---------|------|--------------|
| 1.0 | Nov 2025 | Initial release |
| 2.0 | Dec 2025 | Fixed Relative Weights, added survey weights, VIF, charts |
| 10.0 | Dec 2025 | SHAP analysis, Quadrant charts, segment comparison, documentation consolidation |
| 10.4 | Mar 2026 | Elastic Net variable selection, NCA, Dominance Analysis, GAM nonlinear effects, config-driven custom slides, per-table CSV/Excel export, configurable analysis thresholds |

---

## Use Cases

### Customer Satisfaction

**Question:** What drives overall customer satisfaction?

**Drivers:** Product quality, service quality, value for money, delivery speed, website experience

**Output:** Product quality (32%) and service (25%) are top drivers - prioritize improvement

### Brand Health

**Question:** What drives brand perception?

**Drivers:** Awareness, consideration, trust, innovation, value

**Output:** Trust (28%) dominates - focus brand messaging on reliability

### Employee Engagement

**Question:** What drives employee satisfaction?

**Drivers:** Management, compensation, growth, culture, work-life balance

**Output:** Growth opportunities (30%) and management (24%) are key - develop career paths

---

## Getting Started

1. **Prepare data**: Numeric outcome + drivers, sufficient sample size
2. **Create config**: Use template in `docs/templates/`
3. **Run analysis**: Via GUI or script
4. **Review output**: Check method consensus, VIF, model fit
5. **Take action**: Focus on high-importance, low-performance drivers

See [04_USER_MANUAL.md](04_USER_MANUAL.md) for detailed instructions.
