# Turas Conjoint Module - Authoritative Guide

**Version:** 2.1.0
**Last Updated:** December 2025
**Audience:** Statisticians, Senior Analysts, Market Researchers

---

## Table of Contents

1. [Module Overview](#module-overview)
2. [Conjoint Analysis Fundamentals](#conjoint-analysis-fundamentals)
3. [Statistical Methods](#statistical-methods)
4. [Part-Worth Utilities](#part-worth-utilities)
5. [Attribute Importance](#attribute-importance)
6. [Market Simulation](#market-simulation)
7. [Model Diagnostics](#model-diagnostics)
8. [Alchemer Integration](#alchemer-integration)
9. [Strengths and Limitations](#strengths-and-limitations)
10. [Comparison with Alternatives](#comparison-with-alternatives)
11. [R Packages Used](#r-packages-used)
12. [References](#references)

---

## Module Overview

### Purpose

The Turas Conjoint Module estimates consumer preferences through choice-based experiments. It implements the random utility maximization (RUM) framework where consumers are assumed to choose the alternative that maximizes their utility.

### Core Capabilities

| Capability | Status | Method |
|------------|--------|--------|
| Choice-Based Conjoint | Production | Multinomial/Conditional Logit |
| Part-Worth Utilities | Production | Maximum Likelihood Estimation |
| Attribute Importance | Production | Utility Range Method |
| Market Simulation | Production | Logit Choice Probabilities |
| Confidence Intervals | Production | Delta Method |
| Alchemer Import | Production | Automated Transformation |
| Best-Worst Scaling | Beta | Sequential Maximum Difference |
| Hierarchical Bayes | Planned | MCMC with Individual Utilities |

---

## Conjoint Analysis Fundamentals

### Random Utility Maximization (RUM)

The theoretical foundation assumes:

```
U_ij = V_ij + ε_ij
```

Where:
- `U_ij` = Total utility of alternative j for person i
- `V_ij` = Systematic (observable) utility component
- `ε_ij` = Random (unobservable) component

### Systematic Utility

In our implementation:

```
V_ij = Σ_k (β_k × X_ijk)
```

Where:
- `β_k` = Part-worth utility for attribute level k
- `X_ijk` = 1 if alternative j has level k, 0 otherwise

### Choice Probability

With Type I Extreme Value (Gumbel) error distribution:

```
P(choose j | choice set C) = exp(V_j) / Σ_k∈C exp(V_k)
```

This is the multinomial logit formula.

---

## Statistical Methods

### Method 1: Multinomial Logit (mlogit)

**Package:** `mlogit`

**Model Specification:**
```r
library(mlogit)

# Prepare data in mlogit format
data_mlogit <- dfidx(
  data,
  choice = "chosen",
  idx = list(c("chid", "alt")),
  idnames = c("chid", "alt")
)

# Estimate model
model <- mlogit(
  chosen ~ Brand + Price + Storage + Battery | 0,
  data = data_mlogit
)
```

**Key Properties:**
- Maximum likelihood estimation
- Consistent and asymptotically efficient
- Requires unique (chid, alt) identifiers
- Rich diagnostics (R², AIC, BIC)

### Method 2: Conditional Logit (clogit)

**Package:** `survival`

**Model Specification:**
```r
library(survival)

model <- clogit(
  chosen ~ Brand + Price + Storage + Battery + strata(chid),
  data = data
)
```

**Key Properties:**
- Based on Cox proportional hazards framework
- More robust convergence
- Faster computation
- Fewer diagnostics than mlogit

### Method Selection

| Criterion | mlogit | clogit |
|-----------|--------|--------|
| Speed | Medium | Fast |
| Convergence | Can struggle | More robust |
| Diagnostics | Rich | Basic |
| Extensions | Mixed logit | Limited |
| Default | Yes | Fallback |

**Auto Mode Logic:**
```
1. Try mlogit first
2. If mlogit fails or doesn't converge → use clogit
3. Report which method was used
```

---

## Part-Worth Utilities

### Effects Coding

We use effects coding (not dummy coding) for interpretable utilities:

**Dummy Coding:**
```
Brand: A, B, C
  Brand_A: 1 if A, 0 otherwise
  Brand_B: 1 if B, 0 otherwise
  Brand_C: omitted (baseline = 0)
```

**Effects Coding:**
```
Brand: A, B, C
  Brand_A: 1 if A, -1 if C, 0 otherwise
  Brand_B: 1 if B, -1 if C, 0 otherwise
  Brand_C: calculated as -(Brand_A + Brand_B)
```

**Why Effects Coding:**
- Utilities sum to zero within attribute
- No arbitrary baseline level
- More intuitive interpretation
- Standard in conjoint analysis

### Zero-Centering

After estimation, utilities are zero-centered within each attribute:

```
centered_utility = raw_utility - mean(utilities_for_attribute)
```

**Properties:**
- Sum of utilities per attribute = 0
- Differences between levels preserved
- Enables importance calculation

### Confidence Intervals

**Delta Method:**

For utility β with variance Var(β):

```
CI = β ± z_α/2 × sqrt(Var(β))
```

The variance-covariance matrix is extracted from the model fit.

---

## Attribute Importance

### Calculation Method

Importance is based on the range of utilities within each attribute:

```
Range_k = max(utilities_k) - min(utilities_k)

Importance_k = 100 × Range_k / Σ_j Range_j
```

**Interpretation:**
- Percentage of total utility "swing" from each attribute
- Higher = more influence on choice
- Sum across all attributes = 100%

### Example Calculation

```
Utilities:
  Brand:   Apple=+0.45, Samsung=+0.12, Google=-0.57
  Price:   £449=+0.78, £599=+0.23, £699=-1.01
  Storage: 128GB=-0.35, 256GB=+0.10, 512GB=+0.25
  Battery: 12hr=-0.20, 18hr=+0.05, 24hr=+0.15

Ranges:
  Brand:   0.45 - (-0.57) = 1.02
  Price:   0.78 - (-1.01) = 1.79
  Storage: 0.25 - (-0.35) = 0.60
  Battery: 0.15 - (-0.20) = 0.35

Total Range: 1.02 + 1.79 + 0.60 + 0.35 = 3.76

Importance:
  Brand:   100 × 1.02/3.76 = 27%
  Price:   100 × 1.79/3.76 = 48%
  Storage: 100 × 0.60/3.76 = 16%
  Battery: 100 × 0.35/3.76 = 9%
```

---

## Market Simulation

### Share of Preference

Given product configurations, market share is calculated using logit probabilities:

```
Share_j = exp(U_j) / Σ_k exp(U_k)
```

Where:
- `U_j` = Total utility of product j (sum of part-worths for its features)
- Sum is over all products in the simulation

### Implementation

```r
predict_market_share <- function(products, utilities) {
  # Calculate total utility for each product
  total_utilities <- sapply(products, function(p) {
    sum(utilities[p$features])
  })

  # Logit probabilities
  exp_utilities <- exp(total_utilities)
  shares <- exp_utilities / sum(exp_utilities)

  return(shares)
}
```

### Handling Blank Products

If a product has all reference levels (utility = 0):

```
exp(0) = 1
```

This would give the blank product market share. Solution:

```
If Total_Utility = 0:
  Exclude from calculation
  Return Share = 0%
```

### None Option

When "None of these" is included:

```
Share_None = exp(U_None) / (exp(U_None) + Σ_j exp(U_j))
```

The None utility represents the "outside good" value.

---

## Model Diagnostics

### McFadden's Pseudo R²

```
R² = 1 - (LL_model / LL_null)
```

Where:
- `LL_model` = Log-likelihood of fitted model
- `LL_null` = Log-likelihood of null model (equal probabilities)

**Interpretation:**

| R² | Interpretation |
|----|----------------|
| 0.00-0.10 | Poor fit |
| 0.10-0.20 | Acceptable |
| 0.20-0.40 | Good fit |
| 0.40+ | Excellent fit |

**Note:** McFadden R² is typically lower than OLS R². Values of 0.2-0.4 represent good model fit.

### Hit Rate

Proportion of choices correctly predicted:

```
Hit Rate = Correct Predictions / Total Choice Sets
```

**Calculation:**
1. For each choice set, predict the alternative with highest probability
2. Compare to actual choice
3. Hit rate = proportion of matches

**Benchmarks:**

| Alternatives | Chance Rate | Good Hit Rate |
|--------------|-------------|---------------|
| 2 | 50% | >65% |
| 3 | 33% | >55% |
| 4 | 25% | >45% |
| 5 | 20% | >40% |

### AIC/BIC

**Akaike Information Criterion:**
```
AIC = -2 × LL + 2 × k
```

**Bayesian Information Criterion:**
```
BIC = -2 × LL + k × ln(n)
```

Where:
- `k` = number of parameters
- `n` = number of observations

Lower values indicate better model (balancing fit and parsimony).

---

## Alchemer Integration

### Overview

Version 2.1 adds direct import of Alchemer CBC exports, eliminating manual data transformation.

### Data Transformation

```
ALCHEMER FORMAT                    TURAS FORMAT
═══════════════                    ════════════
ResponseID ────────────────────────→ resp_id
SetNumber ─┬───────────────────────→ chid (combined)
ResponseID ┘                         format: ResponseID_SetNumber
CardNumber ────────────────────────→ alternative_id
Score (0/100) ─────────────────────→ chosen (0/1)
[Attributes] ──────────────────────→ [Cleaned Attributes]
```

### Level Name Cleaning

Alchemer exports include prefixes that need cleaning:

**Pattern 1: Price Codes**
```
"Low_071"  → "Low"
"Mid_089"  → "Mid"
Regex: ^[A-Za-z]+_\d+$ → gsub("_\\d+$", "", value)
```

**Pattern 2: Attribute Prefixes**
```
"MSG_Present" → "Present"
"Brand_Apple" → "Apple"
Regex: ^AttrName_ → gsub("^AttrName_", "", value)
```

**Pattern 3: Already Clean**
```
"A", "B", "C" → unchanged
```

### Config Settings for Alchemer

| Setting | Value | Description |
|---------|-------|-------------|
| data_source | alchemer | Enable Alchemer mode |
| clean_alchemer_levels | TRUE | Auto-clean level names |

---

## Strengths and Limitations

### Strengths

1. **Realistic Trade-Offs:** Forces respondents to make realistic choices
2. **Quantified Preferences:** Utilities on common scale
3. **Market Simulation:** Test unlimited configurations
4. **Statistical Rigor:** Maximum likelihood with standard errors
5. **Industry Standard:** Widely accepted methodology
6. **Alchemer Integration:** Seamless data import
7. **Interactive Output:** Excel simulator for clients

### Limitations

1. **IIA Assumption:** Independence of Irrelevant Alternatives
   - Adding/removing alternatives shouldn't change relative preferences
   - May not hold in reality (e.g., red bus/blue bus problem)

2. **Aggregate Utilities:** Only population-level estimates
   - No individual-level heterogeneity (without HB)
   - Assumes homogeneous preferences

3. **Categorical Attributes Only:** Currently no support for:
   - Continuous attributes (e.g., price as number)
   - Would require linear or spline terms

4. **No Cross-Validation:** Uses all data for estimation
   - No train/test split
   - Hit rate may be optimistic

5. **No Significance Testing:** Between-group comparisons not built in
   - Would need separate subgroup analyses

### Known Issues

1. **Convergence:** mlogit can struggle with:
   - Perfect separation
   - High collinearity
   - Small samples

2. **Memory:** Large datasets with many attributes can be slow

3. **Excel Limits:** Market simulator limited to ~5 products

---

## Comparison with Alternatives

### vs. Sawtooth Software

| Feature | Turas Conjoint | Sawtooth |
|---------|----------------|----------|
| Cost | Included in Turas | £10,000+/year |
| CBC Analysis | Yes | Yes |
| HB Estimation | Planned | Yes |
| Market Simulator | Yes | Yes |
| ACBC/MBC | No | Yes |
| MaxDiff | Beta | Yes |
| Survey Design | No | Yes |
| Learning Curve | Low | Medium |

### vs. R survey Package

| Feature | Turas Conjoint | R Manual |
|---------|----------------|----------|
| Configuration | Excel | R scripting |
| Output | Excel workbook | R objects |
| Market Simulator | Included | Build yourself |
| Learning Curve | Low | High |

### vs. Conjointly

| Feature | Turas Conjoint | Conjointly |
|---------|----------------|------------|
| Cost | Included | £500+/study |
| Hosting | On-premise | Cloud |
| Data Control | Full | Provider |
| Customization | High | Limited |

---

## R Packages Used

### Required Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `mlogit` | ≥1.1-0 | Multinomial logit estimation |
| `survival` | ≥3.0-0 | Conditional logit (clogit) |
| `readxl` | ≥1.4.0 | Read Excel config files |
| `openxlsx` | ≥4.2.5 | Write Excel output |
| `dfidx` | ≥0.0-5 | Data indexing for mlogit |

### Optional Dependencies

| Package | Purpose |
|---------|---------|
| `dplyr` | Data manipulation |
| `bayesm` | Hierarchical Bayes (future) |

### Base R Functions

Core calculations use base R:
- `optim()` - Optimization
- `vcov()` - Variance-covariance extraction
- `qnorm()` - Normal quantiles for CIs

---

## Design Recommendations

### Attributes and Levels

| Element | Minimum | Optimal | Maximum |
|---------|---------|---------|---------|
| Attributes | 2 | 4-6 | 8 |
| Levels per attribute | 2 | 3-4 | 6 |
| Total parameters | 4 | 12-20 | 30 |

### Choice Task Design

| Element | Minimum | Optimal | Maximum |
|---------|---------|---------|---------|
| Alternatives per set | 2 | 3-4 | 5 |
| Choice sets per respondent | 6 | 8-12 | 15 |
| None option | Optional | Often helpful | - |

### Sample Size

**Rule of Thumb:**
```
n ≥ 500 × (max_alternatives) / (tasks × alternatives)
```

**Practical Minimums:**

| Design | Minimum n |
|--------|-----------|
| 4 attr × 3 levels × 8 tasks | 300 |
| 6 attr × 4 levels × 10 tasks | 450 |
| 8 attr × 5 levels × 12 tasks | 600 |

---

## References

### Foundational Works

**Random Utility Theory:**
- McFadden, D. (1974). Conditional logit analysis of qualitative choice behavior. In P. Zarembka (Ed.), *Frontiers in Econometrics*. Academic Press.

**Conjoint Analysis:**
- Green, P. E., & Srinivasan, V. (1978). Conjoint analysis in consumer research: Issues and outlook. *Journal of Consumer Research*, 5(2), 103-123.

**Choice Modeling:**
- Train, K. E. (2009). *Discrete Choice Methods with Simulation* (2nd ed.). Cambridge University Press.

### R Package Documentation

**mlogit:**
- Croissant, Y. (2020). Estimation of Random Utility Models in R: The mlogit Package. *Journal of Statistical Software*, 95(11).

**survival:**
- Therneau, T. M. (2023). A Package for Survival Analysis in R. https://CRAN.R-project.org/package=survival

### Market Research Standards

**ESOMAR:**
- ESOMAR Guidelines on Conjoint Analysis and Pricing Research.

---

## Appendix: Formula Reference

### Multinomial Logit

**Probability:**
```
P(j) = exp(β'x_j) / Σ_k exp(β'x_k)
```

**Log-Likelihood:**
```
LL = Σ_n Σ_j y_nj × ln(P_nj)
```

### Part-Worth Utility

**Effects Coding:**
```
For K levels: k-1 indicator variables
Last level utility = -Σ(other utilities)
```

### Attribute Importance

**Range Method:**
```
Importance_a = 100 × [max(U_a) - min(U_a)] / Σ_b [max(U_b) - min(U_b)]
```

### Confidence Interval

**Delta Method:**
```
CI = β ± z × SE(β)
SE(β) = sqrt(diag(vcov(model)))
```

### Market Share

**Logit Share:**
```
Share_j = exp(U_j) / Σ_k exp(U_k)

Where U_j = Σ_a utility(level_ja)
```

---

**End of Authoritative Guide**

*Turas Conjoint Module v2.1.0*
*Last Updated: December 2025*
