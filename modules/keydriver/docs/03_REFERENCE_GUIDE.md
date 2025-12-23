# Turas Key Driver Analysis - Reference Guide

**Version:** 10.0
**Last Updated:** 22 December 2025
**Target Audience:** Analysts, Statisticians, Data Scientists

This document provides comprehensive reference for Key Driver Analysis methodology, statistical methods, and interpretation guidelines.

---

## Table of Contents

1. [Regression Framework](#regression-framework)
2. [Method 1: Shapley Value Decomposition](#method-1-shapley-value-decomposition)
3. [Method 2: Relative Weights (Johnson)](#method-2-relative-weights-johnson)
4. [Method 3: Standardized Coefficients](#method-3-standardized-coefficients)
5. [Method 4: Zero-Order Correlations](#method-4-zero-order-correlations)
6. [Method 5: SHAP Analysis](#method-5-shap-analysis)
7. [Multicollinearity Diagnostics (VIF)](#multicollinearity-diagnostics-vif)
8. [Quadrant Analysis (IPA)](#quadrant-analysis-ipa)
9. [Weighted Analysis](#weighted-analysis)
10. [Interpretation Guidelines](#interpretation-guidelines)
11. [Method Comparison](#method-comparison)
12. [Assumptions and Limitations](#assumptions-and-limitations)

---

## Regression Framework

### Multiple Linear Regression Model

Key Driver Analysis is built on the multiple linear regression framework:

```
Y = β₀ + β₁X₁ + β₂X₂ + ... + βₖXₖ + ε

Where:
  Y  = Outcome variable (e.g., Overall Satisfaction)
  Xᵢ = Driver variables (e.g., Product Quality, Service)
  βᵢ = Regression coefficients
  ε  = Error term ~ N(0, σ²)
```

### OLS Estimation

Coefficients estimated via Ordinary Least Squares:

```
β̂ = (X'X)⁻¹X'Y

Where:
  X = n × (k+1) design matrix (with intercept column)
  Y = n × 1 outcome vector
```

### Model Fit Statistics

| Statistic | Formula | Interpretation |
|-----------|---------|----------------|
| R² | 1 - SS_res/SS_tot | Proportion of variance explained |
| Adjusted R² | 1 - (1-R²)(n-1)/(n-k-1) | R² adjusted for number of predictors |
| F-statistic | (R²/k) / ((1-R²)/(n-k-1)) | Overall model significance |
| RMSE | √(SS_res/(n-k-1)) | Root mean squared error |

---

## Method 1: Shapley Value Decomposition

### Concept

Shapley values originate from cooperative game theory (Shapley, 1953). Each driver's "fair share" of R² is calculated by averaging its marginal contribution across all possible orderings of predictors.

### Mathematical Definition

For k predictors, the Shapley value for predictor j is:

```
φⱼ = Σ [|S|!(k-|S|-1)!/k!] × [R²(S∪{j}) - R²(S)]
     S⊆N\{j}

Where:
  S = subset of predictors not including j
  N = full set of predictors
  |S| = size of subset S
  R²(S) = R² from model using only predictors in S
```

### Algorithm

```
1. For each driver j:
   a. Generate all 2^(k-1) subsets of other drivers
   b. For each subset S:
      - Fit model with S (get R²_without)
      - Fit model with S ∪ {j} (get R²_with)
      - Calculate marginal contribution: R²_with - R²_without
   c. Average marginal contributions (with appropriate weights)

2. Convert to percentages: φⱼ% = 100 × φⱼ / Σφᵢ
```

### Properties

**Axioms satisfied:**
- **Efficiency**: Shapley values sum to total R²
- **Symmetry**: Equal contributors get equal shares
- **Null player**: Zero contribution → zero Shapley value
- **Additivity**: Decomposition is additive across games

### Strengths and Limitations

| Strengths | Limitations |
|-----------|-------------|
| Theoretically sound (axiomatic) | Computationally expensive: O(2^k) |
| Handles multicollinearity | Maximum ~15 drivers practical |
| Fair attribution | Assumes linear additive model |
| Most robust method | No direction information |

### Computational Complexity

| Drivers (k) | Models Required | Approximate Time |
|-------------|-----------------|------------------|
| 5 | 32 | < 1 second |
| 10 | 1,024 | 2-5 seconds |
| 15 | 32,768 | 10-30 seconds |
| 20 | 1,048,576 | 5-10 minutes |

**Practical limit:** k ≤ 15 for exact computation

---

## Method 2: Relative Weights (Johnson)

### Concept

Johnson's (2000) relative weights method decomposes R² into non-negative driver contributions by:
1. Transforming correlated predictors to orthogonal space
2. Regressing outcome on orthogonal components
3. Mapping contributions back to original predictors

### Mathematical Formulation

**Step 1: Eigendecomposition of predictor correlation matrix**

```
R_XX = VΛV'

Where:
  R_XX = k × k correlation matrix of predictors
  V = matrix of eigenvectors
  Λ = diagonal matrix of eigenvalues
```

**Step 2: Create orthogonal predictors**

```
Z = XV Λ^(-1/2)

Where:
  X = standardized predictor matrix
  Z = orthogonal predictors (Z'Z = I)
```

**Step 3: Regress Y on Z**

```
β_Z = Z'Y / n

(Since Z'Z = I, coefficients are simple projections)
```

**Step 4: Calculate relative weights**

```
RW_j = Σᵢ (V_ji × λᵢ^(1/2) × β_Zi)²

Convert to percentage: RW_j% = 100 × RW_j / R²
```

### Properties

- Always non-negative
- Sum to 100% of R²
- Handles multicollinearity via orthogonalization
- Faster than Shapley: O(k³) for eigendecomposition

### Strengths and Limitations

| Strengths | Limitations |
|-----------|-------------|
| Always positive contributions | Less intuitive than beta |
| Handles multicollinearity | Sensitive to predictor set |
| Fast computation | No direction information |
| Widely used in I/O psychology | Requires matrix algebra |

---

## Method 3: Standardized Coefficients

### Concept

Beta weights are regression coefficients expressed in standard deviation units:

```
β*_j = β_j × (SD_Xj / SD_Y)

Interpretation: A 1-SD increase in Xj is associated with
               β*_j SD change in Y
```

### Calculation

```
1. Standardize all variables: z = (x - mean) / SD
2. Fit regression on standardized data
3. Extract coefficients (intercept = 0 for standardized data)
4. Convert |β*| to percentages for importance ranking
```

### Importance Conversion

```
Importance_j% = 100 × |β*_j| / Σ|β*_i|
```

**Note:** Absolute values used for ranking; signed values reported separately for direction.

### Strengths and Limitations

| Strengths | Limitations |
|-----------|-------------|
| Easy interpretation | Unstable with multicollinearity |
| Shows direction | Can have suppressor effects |
| Widely understood | May not sum to 100% meaningfully |
| Fast computation | Affected by irrelevant predictors |

### When Beta Weights Fail

**Suppressor effect example:**
```
X₁ and X₂ are correlated (r = 0.8)
X₁ positively related to Y
X₂ not related to Y alone

In regression: β*₂ may be negative (suppressor)
because X₂ "suppresses" irrelevant variance in X₁
```

**Recommendation:** When VIF > 5, prefer Shapley or Relative Weights.

---

## Method 4: Zero-Order Correlations

### Concept

Simple Pearson correlation between each driver and the outcome, ignoring other predictors.

### Formula

```
r_jY = Cov(Xj, Y) / (SD_Xj × SD_Y)

     = Σ(Xj - X̄j)(Y - Ȳ) / √[Σ(Xj - X̄j)² × Σ(Y - Ȳ)²]
```

### Importance Conversion

```
Importance_j% = 100 × r²_jY / Σr²_iY
```

### Strengths and Limitations

| Strengths | Limitations |
|-----------|-------------|
| Simple, intuitive | Ignores other predictors |
| No collinearity issues | Doesn't control confounds |
| Shows direction | Overestimates correlated drivers |
| Baseline comparison | Not recommended for prioritization |

### When to Use

- As baseline comparison
- When drivers are uncorrelated
- For descriptive (not inferential) purposes
- To understand bivariate relationships

---

## Method 5: SHAP Analysis

### Concept

SHAP (SHapley Additive exPlanations) extends Shapley values to machine learning models (Lundberg & Lee, 2017). Uses XGBoost to capture non-linear relationships and interactions.

### How It Works

```
1. Fit XGBoost model: Y ~ f(X₁, X₂, ..., Xₖ)
2. Calculate SHAP values using TreeSHAP algorithm
3. Aggregate: Mean |SHAP| per feature = importance
```

### TreeSHAP Algorithm

For tree-based models, SHAP values can be computed efficiently in O(TLD²) where:
- T = number of trees
- L = maximum leaves
- D = maximum depth

### XGBoost Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| n_trees | 100 | Number of boosting rounds |
| max_depth | 6 | Maximum tree depth |
| learning_rate | 0.1 | Step size shrinkage |
| subsample | 0.8 | Row sampling ratio |

### SHAP Visualizations

**1. Importance Bar Plot**
- Mean |SHAP| for each feature
- Higher = more important

**2. Beeswarm Plot**
- X-axis: SHAP value (impact on prediction)
- Y-axis: Features
- Color: Feature value (red = high, blue = low)
- Shows distribution and direction

**3. Waterfall Plot**
- Individual prediction explanation
- Shows each feature's contribution

**4. Dependence Plot**
- X-axis: Feature value
- Y-axis: SHAP value
- Shows non-linear relationships

### When to Use SHAP

| Use SHAP When | Don't Use When |
|---------------|----------------|
| Suspect non-linear effects | Linear relationships sufficient |
| Want interaction detection | Small sample (n < 200) |
| Need individual explanations | Interpretability critical |
| Large sample available | Need p-values |

### Strengths and Limitations

| Strengths | Limitations |
|-----------|-------------|
| Captures non-linearity | Requires xgboost package |
| Detects interactions | Slower than linear methods |
| Individual explanations | May overfit with small n |
| Consistent Shapley properties | Black box model |

---

## Multicollinearity Diagnostics (VIF)

### Variance Inflation Factor

VIF measures how much the variance of a regression coefficient is inflated due to multicollinearity:

```
VIF_j = 1 / (1 - R²_j)

Where:
  R²_j = R² from regressing Xj on all other predictors
```

### Interpretation

| VIF | Multicollinearity | Action |
|-----|-------------------|--------|
| 1.0 | None | Ideal |
| 1-5 | Low | No concern |
| 5-10 | Moderate | Monitor, prefer Shapley/RelWeights |
| > 10 | High | Remove or combine drivers |

### Relationship to Tolerance

```
Tolerance_j = 1 / VIF_j = 1 - R²_j

Tolerance < 0.1 indicates high multicollinearity
```

### Effect on Standard Errors

```
SE(β̂_j) = σ × √(VIF_j / Σ(Xj - X̄j)²)

High VIF → inflated standard errors → unstable coefficients
```

### Detection Strategy

1. Calculate VIF for all drivers
2. Flag drivers with VIF > 10
3. Examine correlation matrix for highly correlated pairs
4. Remove or combine problematic drivers
5. Re-run analysis

---

## Quadrant Analysis (IPA)

### Importance-Performance Analysis

Quadrant charts plot drivers on two dimensions:
- **X-axis:** Performance (mean rating)
- **Y-axis:** Importance (derived from analysis)

### Quadrant Definitions

```
                    HIGH IMPORTANCE
                          |
           Q1             |            Q2
    CONCENTRATE HERE      |      KEEP UP GOOD WORK
    (High importance,     |      (High importance,
     Low performance)     |       High performance)
                          |
    ──────────────────────┼──────────────────────── PERFORMANCE
                          |
           Q3             |            Q4
       LOW PRIORITY       |      POSSIBLE OVERKILL
    (Low importance,      |      (Low importance,
     Low performance)     |       High performance)
                          |
                    LOW IMPORTANCE
```

### Strategic Actions by Quadrant

| Quadrant | Meaning | Action |
|----------|---------|--------|
| Q1 (Red) | Important, underperforming | **IMPROVE** - Priority investment |
| Q2 (Green) | Important, performing well | **MAINTAIN** - Protect investment |
| Q3 (Gray) | Low importance, low performance | **MONITOR** - Low priority |
| Q4 (Yellow) | Low importance, high performance | **REASSESS** - Potential overkill |

### Threshold Methods

| Method | Description |
|--------|-------------|
| mean | Thresholds at mean importance and performance |
| median | Thresholds at median values |
| midpoint | Thresholds at scale midpoints |
| custom | User-specified threshold values |

### Gap Analysis

```
Gap_j = Importance_j (normalized) - Performance_j (normalized)

Positive gap: Underperforming relative to importance → priority
Negative gap: Overperforming relative to importance → reassess
```

---

## Weighted Analysis

### Survey Weights

When survey weights are specified, all calculations incorporate weights:

### Weighted Correlation

```
r_w = Σwᵢ(Xᵢ - X̄_w)(Yᵢ - Ȳ_w) / √[Σwᵢ(Xᵢ - X̄_w)² × Σwᵢ(Yᵢ - Ȳ_w)²]

Where:
  X̄_w = Σwᵢxᵢ / Σwᵢ  (weighted mean)
```

### Weighted Regression

```
β̂_w = (X'WX)⁻¹X'WY

Where:
  W = diagonal matrix of weights
```

### Weighted R²

```
R²_w = 1 - Σwᵢ(Yᵢ - Ŷᵢ)² / Σwᵢ(Yᵢ - Ȳ_w)²
```

### Method-Specific Weighting

| Method | Weighting Approach |
|--------|-------------------|
| Correlations | Weighted covariance |
| Regression | Weighted OLS |
| Beta Weights | Weighted regression + unweighted SD normalization |
| Relative Weights | Weighted correlation matrix |
| Shapley | Weighted R² in each subset model |
| SHAP (XGBoost) | Sample weights in model fitting |

### Best Practice with Weights

When using weights, prioritize:
1. **Relative Weights** - Most trustworthy weighted implementation
2. **SHAP** - Properly weighted via XGBoost
3. **Shapley** - Has known minor weighting inconsistency in subset models
4. **Beta Weights** - Minor inconsistency (weighted coefficients, unweighted SD)

---

## Interpretation Guidelines

### Importance Score Thresholds

| Shapley Value | Interpretation | Priority |
|---------------|----------------|----------|
| > 25% | Dominant driver | Highest priority |
| 15-25% | Major driver | High priority |
| 10-15% | Moderate driver | Secondary priority |
| 5-10% | Minor driver | Lower priority |
| < 5% | Marginal driver | Limited impact |

### Method Consensus

**High Consensus (all methods agree within ±2 ranks):**
- Strong evidence for driver importance
- Trust the ranking confidently

**Moderate Consensus (±3-4 ranks):**
- Good evidence, some variation expected
- Check VIF for multicollinearity

**Low Consensus (> 4 rank difference):**
- Investigate multicollinearity (VIF > 5?)
- Check for suppressor effects
- Trust Shapley values over beta weights

### Model Fit Assessment

| R² | Quality | Interpretation |
|----|---------|----------------|
| > 0.70 | Excellent | Drivers explain most variance |
| 0.50-0.70 | Good | Drivers capture key effects |
| 0.30-0.50 | Moderate | Missing some important drivers |
| < 0.30 | Weak | Consider adding drivers |

### Direction Interpretation

**Positive coefficient/correlation:**
- Higher driver value → higher outcome
- Example: Better quality → higher satisfaction

**Negative coefficient/correlation:**
- Higher driver value → lower outcome
- Example: Higher price → lower satisfaction
- Or: Suppressor effect (unexpected negative - investigate)

---

## Method Comparison

### When to Trust Each Method

| Situation | Recommended Method |
|-----------|-------------------|
| General prioritization | Shapley |
| High multicollinearity (VIF > 5) | Shapley or Relative Weights |
| Need direction information | Beta coefficients |
| Suspect non-linear effects | SHAP |
| Small sample (n < 100) | Relative Weights |
| Large sample (n > 500) + ML | SHAP |
| Simple baseline | Correlations |

### Method Properties Summary

| Property | Shapley | RelWeights | Beta | Correlation | SHAP |
|----------|---------|------------|------|-------------|------|
| Always positive | Yes | Yes | No* | No | Yes |
| Sums to 100% | Yes | Yes | No | No | Yes |
| Handles collinearity | Yes | Yes | No | N/A | Yes |
| Shows direction | No | No | Yes | Yes | Yes |
| Non-linear | No | No | No | No | Yes |
| Fast (k > 15) | No | Yes | Yes | Yes | Yes |

*Beta weights use absolute values for ranking; signed values reported separately.

---

## Assumptions and Limitations

### Statistical Assumptions

**1. Linearity**
- Relationship between each driver and outcome is linear
- Check: Residual plots, SHAP dependence plots
- Violation: Use SHAP for non-linear detection

**2. Independence**
- Observations are independent
- Check: Study design (no clustering?)
- Violation: Use clustered standard errors or multilevel models

**3. Homoscedasticity**
- Constant variance of residuals
- Check: Residuals vs. fitted values plot
- Violation: Use robust standard errors

**4. No Perfect Multicollinearity**
- No driver perfectly predicted by others
- Check: VIF < ∞, no aliased coefficients
- Violation: Remove redundant drivers

**5. Normality (for inference)**
- Residuals normally distributed
- Check: Q-Q plot
- Violation: Point estimates still valid; CIs/p-values affected

### Key Limitations

1. **Correlation ≠ Causation**: Cannot establish causal relationships
2. **Omitted Variables**: Missing drivers can bias results
3. **Measurement Error**: Poor measurement inflates error variance
4. **Sample Size**: Requires sufficient n for stable estimates
5. **Shapley Limit**: Maximum ~15 drivers for exact computation
6. **Listwise Deletion**: Missing data reduces sample size

---

## References

### Primary Sources

- **Shapley, L. S.** (1953). A value for n-person games. *Contributions to the Theory of Games*, 2(28), 307-317.

- **Johnson, J. W.** (2000). A heuristic method for estimating the relative weight of predictor variables in multiple regression. *Multivariate Behavioral Research*, 35(1), 1-19.

- **Lundberg, S. M., & Lee, S. I.** (2017). A unified approach to interpreting model predictions. *Advances in Neural Information Processing Systems*, 30.

- **Martilla, J. A., & James, J. C.** (1977). Importance-performance analysis. *Journal of Marketing*, 41(1), 77-79.

### Additional Reading

- **Tonidandel, S., & LeBreton, J. M.** (2011). Relative importance analysis: A useful supplement to regression analysis. *Journal of Business and Psychology*, 26(1), 1-9.

- **Grömping, U.** (2006). Relative importance for linear regression in R: The package relaimpo. *Journal of Statistical Software*, 17(1), 1-27.

- **Budescu, D. V.** (1993). Dominance analysis: A new approach to the problem of relative importance of predictors in multiple regression. *Psychological Bulletin*, 114(3), 542-551.
