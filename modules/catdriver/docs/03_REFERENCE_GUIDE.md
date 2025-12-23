# Turas Categorical Key Driver Module - Reference Guide

**Version:** 10.0
**Last Updated:** 22 December 2025
**Target Audience:** Statisticians, Senior Analysts, Methodologists

This document provides comprehensive technical reference for the statistical methods used in the Categorical Key Driver module.

---

## Table of Contents

1. [Binary Logistic Regression](#binary-logistic-regression)
2. [Ordinal Logistic Regression](#ordinal-logistic-regression)
3. [Multinomial Logistic Regression](#multinomial-logistic-regression)
4. [Variable Importance](#variable-importance)
5. [Effect Size Interpretation](#effect-size-interpretation)
6. [Model Fit Statistics](#model-fit-statistics)
7. [Diagnostics](#diagnostics)
8. [Method Selection Guide](#method-selection-guide)

---

## Binary Logistic Regression

### When Used

Automatically selected when the outcome variable has exactly 2 categories.

### Model Specification

```
logit(P(Y=1)) = β₀ + β₁X₁ + β₂X₂ + ... + βₖXₖ
```

Where:
- `logit(p) = log(p / (1-p))` is the log-odds
- `Y` is the binary outcome (0 or 1)
- `X₁, X₂, ..., Xₖ` are predictor variables
- `β₀` is the intercept
- `β₁, β₂, ..., βₖ` are coefficients

### Implementation

```r
model <- glm(outcome ~ drivers, family = binomial(link = "logit"), data = data)
```

### Odds Ratio Calculation

```
OR = exp(β)
```

The odds ratio represents how much the odds of the outcome change for a one-unit increase in the predictor (or compared to reference category for factors).

### Confidence Intervals

Wald-based confidence intervals:

```
CI = exp(β ± z × SE(β))
```

Where `z` is the critical value (1.96 for 95% CI).

### Fit Statistics

| Statistic | Formula | Interpretation |
|-----------|---------|----------------|
| McFadden R² | `1 - (deviance / null.deviance)` | Pseudo R-squared |
| AIC | `2k - 2log(L)` | Lower is better |
| LR Test | `null.deviance - deviance` | Chi-square test vs null |

### Separation Handling

**Perfect Separation:** When a predictor perfectly predicts the outcome.

**Detection:**
- Extremely large coefficients (|β| > 10)
- Very large standard errors (SE > 5)
- Convergence warnings

**Solution:**
- If `brglm2` package installed: Firth bias-reduced estimation
- If not installed: Analysis refuses (no silent degradation)

---

## Ordinal Logistic Regression

### When Used

Automatically selected when:
- Outcome has 3+ categories AND
- Order is specified in config OR
- Outcome is already an ordered factor

### Model Specification (Proportional Odds)

```
logit(P(Y ≤ j)) = αⱼ - (β₁X₁ + β₂X₂ + ... + βₖXₖ)
```

Where:
- `j = 1, 2, ..., J-1` for J outcome categories
- `αⱼ` are threshold (intercept) parameters
- `β` coefficients are the same across all thresholds (proportional odds assumption)

### Implementation

**Primary engine (if ordinal package installed):**
```r
model <- ordinal::clm(outcome ~ drivers, data = data)
```

**Fallback engine:**
```r
model <- MASS::polr(outcome ~ drivers, method = "logistic", Hess = TRUE, data = data)
```

### Proportional Odds Assumption

**Assumption:** The effect of each predictor is the same regardless of which threshold is being crossed.

**Practical Check:**
1. Fit separate binary models at each threshold
2. Compare odds ratios across thresholds
3. PASS if `max(OR) / min(OR) < 1.25`
4. WARNING if ratio > 1.5
5. Consider multinomial if ratio > 2.0

### Odds Ratio Interpretation

For ordinal models, the odds ratio represents the cumulative odds:

> "For each unit increase in X, the odds of being in category j or higher (vs. category j-1 or lower) are multiplied by OR."

### Threshold Parameters

The `αⱼ` parameters represent the log-odds of being in category j or lower when all predictors are zero.

---

## Multinomial Logistic Regression

### When Used

Automatically selected when:
- Outcome has 3+ categories AND
- No order is specified AND
- Outcome is not an ordered factor

### Model Specification

For J outcome categories with reference category 1:

```
log(P(Y=j) / P(Y=1)) = β₀ⱼ + β₁ⱼX₁ + β₂ⱼX₂ + ... + βₖⱼXₖ

for j = 2, 3, ..., J
```

Each outcome category (except reference) has its own set of coefficients.

### Implementation

```r
model <- nnet::multinom(outcome ~ drivers, trace = FALSE, maxit = 500, data = data)
```

### Reference Category

By default, the first category alphabetically is the reference. Can be overridden in config.

### Odds Ratio Interpretation

```
ORⱼ = exp(βⱼ)
```

> "For a one-unit increase in X, the odds of being in category j (vs. reference) are multiplied by ORⱼ."

### Convergence

- Maximum iterations: 500 (default)
- Convergence checked via `model$convergence == 0`
- Warning issued if not converged

### Aggregating Importance

For multinomial models, each predictor has J-1 coefficients. Importance is aggregated:

1. Calculate chi-square for each coefficient
2. Sum chi-squares for same predictor across outcomes
3. Calculate importance % from aggregated chi-squares

---

## Variable Importance

### Method: Type II Wald Chi-Square

**Primary calculation via `car::Anova()`:**

```r
anova_result <- car::Anova(model, type = "II")
chisq_values <- anova_result$`Chisq`
importance_pct <- 100 * chisq_values / sum(chisq_values)
```

### Why Type II Tests?

| Test Type | Description | Use Case |
|-----------|-------------|----------|
| Type I | Sequential, order-dependent | Not recommended |
| Type II | Each term adjusted for all others at same level | **Preferred** |
| Type III | Each term adjusted for all others | Requires sum-to-zero contrasts |

Type II is preferred because:
- Order-independent
- Properly handles categorical predictors
- Works with default treatment contrasts
- Aggregates dummy variables automatically

### Importance Formula

```
Importance % = 100 × (χ² for variable) / (Σ all χ²)
```

### Fallback Method

If `car::Anova()` fails (rare), fallback to coefficient-based calculation:

1. Extract z-values from coefficient table
2. Square to approximate chi-square: `χ² ≈ z²`
3. Aggregate by original variable
4. Calculate importance %

### Interpretation

| Importance % | Interpretation |
|--------------|----------------|
| > 30% | Dominant driver |
| 15-30% | Major driver |
| 5-15% | Moderate driver |
| < 5% | Minor driver |

---

## Effect Size Interpretation

### Odds Ratio Effect Sizes

Based on Chen, Cohen & Chen (2010) and practical guidelines:

| Odds Ratio Range | Effect Size | Description |
|------------------|-------------|-------------|
| 0.90 - 1.10 | Negligible | No meaningful difference |
| 0.67 - 0.90 | Small (protective) | Minor reduction in odds |
| 1.10 - 1.50 | Small (risk) | Minor increase in odds |
| 0.50 - 0.67 | Medium (protective) | Moderate reduction |
| 1.50 - 2.00 | Medium (risk) | Moderate increase |
| 0.33 - 0.50 | Large (protective) | Substantial reduction |
| 2.00 - 3.00 | Large (risk) | Substantial increase |
| < 0.33 | Very Large (protective) | Very strong reduction |
| > 3.00 | Very Large (risk) | Very strong increase |

### Confidence Interval Considerations

Effect size interpretation should consider:
- Point estimate (OR)
- CI width (precision)
- CI crossing 1.0 (significance)
- Practical significance vs. statistical significance

---

## Model Fit Statistics

### McFadden Pseudo-R²

```
R²_McFadden = 1 - (log L_model / log L_null)
```

Where:
- `L_model` = likelihood of fitted model
- `L_null` = likelihood of intercept-only model

**Interpretation:**

| R² Value | Interpretation |
|----------|----------------|
| 0.4+ | Excellent fit |
| 0.2 - 0.4 | Good fit |
| 0.1 - 0.2 | Moderate fit |
| < 0.1 | Limited explanatory power |

**Note:** McFadden R² values are typically lower than OLS R² values. A McFadden R² of 0.2-0.4 is considered very good.

### Akaike Information Criterion (AIC)

```
AIC = 2k - 2log(L)
```

Where:
- `k` = number of parameters
- `L` = maximized likelihood

**Interpretation:**
- Lower is better
- Compare between models on same data
- Difference of 2+ suggests meaningful improvement

### Likelihood Ratio Test

```
LR = 2 × (log L_model - log L_null) ~ χ²(df)
```

Tests whether model is significantly better than intercept-only.

### Nagelkerke Pseudo-R²

```
R²_Nagelkerke = (1 - (L_null/L_model)^(2/n)) / (1 - L_null^(2/n))
```

Adjusted to range from 0 to 1. Often higher than McFadden R².

---

## Diagnostics

### Missing Data Assessment

| Metric | Calculation | Threshold |
|--------|-------------|-----------|
| % Missing per Variable | `100 × sum(is.na(x)) / n` | Warn if > 20% |
| Complete Cases | `sum(complete.cases(data))` | Require ≥ min_sample_size |
| Missing Pattern | `md.pattern()` if available | Check for systematic |

### Small Cell Detection

Cells (predictor-outcome combinations) with fewer than expected observations:

```r
expected <- rowSums(table) %*% t(colSums(table)) / sum(table)
small_cells <- which(observed < 5 & expected >= 5)
```

**Impact:**
- May cause unstable estimates
- Chi-square tests less reliable
- Consider collapsing categories

### Multicollinearity

Generalized Variance Inflation Factor (GVIF):

```r
vif_values <- car::vif(model)
```

For categorical predictors with df degrees of freedom:

```
GVIF^(1/(2×df))
```

**Interpretation:**

| GVIF^(1/2df) | Interpretation |
|--------------|----------------|
| < 2 | Acceptable |
| 2-5 | Moderate, monitor |
| > 5 | High, consider removing |
| > 10 | Severe, action required |

### Convergence Diagnostics

| Issue | Detection | Resolution |
|-------|-----------|------------|
| Non-convergence | `model$convergence != 0` | Increase iterations, reduce predictors |
| Perfect separation | Large coefficients, large SE | Use Firth correction or remove predictor |
| Quasi-separation | Very large coefficients | May proceed with caution |

---

## Method Selection Guide

### Automatic Selection Logic

```
Is outcome binary (2 categories)?
├── Yes → Binary Logistic Regression (glm)
└── No
    └── Is order specified or is.ordered(outcome)?
        ├── Yes → Ordinal Logistic Regression (polr/clm)
        └── No → Multinomial Logistic Regression (multinom)
```

### Manual Override

Set `outcome_type` in config to force a specific method:

- `auto` - Use automatic detection (default)
- `binary` - Force binary logistic
- `ordinal` - Force ordinal logistic
- `nominal` - Force multinomial logistic

### When to Override

| Situation | Override To |
|-----------|-------------|
| Ordinal outcome but want category-specific effects | `nominal` |
| Nominal outcome but want parsimonious model | Not recommended |
| Binary outcome treated as ordinal (Never/Sometimes/Always but only 2 observed) | `binary` |

---

## Package-Specific Notes

### MASS::polr()

- Returns coefficients with opposite sign to `clm()`
- Module handles sign conversion automatically
- Requires `Hess = TRUE` for standard errors

### nnet::multinom()

- Default trace output suppressed (`trace = FALSE`)
- Coefficients on log-odds scale
- Reference category is first level of factor

### car::Anova()

- Type II tests are default and preferred
- Properly aggregates dummy variables
- Returns chi-square and p-values

### brglm2 (if installed)

- Provides Firth bias-reduced estimation
- Handles perfect/quasi-separation
- Falls back to standard glm if not installed

---

## References

1. Agresti, A. (2010). Analysis of Ordinal Categorical Data. Wiley.
2. Hosmer, D.W. & Lemeshow, S. (2000). Applied Logistic Regression. Wiley.
3. Long, J.S. (1997). Regression Models for Categorical and Limited Dependent Variables. Sage.
4. Chen, H., Cohen, P. & Chen, S. (2010). How big is a big odds ratio? Interpreting the magnitudes of odds ratios in epidemiological studies. Communications in Statistics.

---

**Part of the Turas Analytics Platform**
