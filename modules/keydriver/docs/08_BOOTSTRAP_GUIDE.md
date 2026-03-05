# Bootstrap Confidence Intervals Guide

## Overview

Bootstrap confidence intervals provide a robust, assumption-light measure of uncertainty for key driver importance scores. They answer a fundamental question: "If I repeated this survey many times, how much would my driver rankings and importance estimates vary?"

In market research, where non-probability samples (quota samples, panel samples, self-selection surveys) are the norm, bootstrap CIs offer a more honest picture of estimation precision than parametric alternatives that assume random sampling.

## How Bootstrap Works

### The Basic Idea

1. **Resample**: Randomly draw N observations from your data *with replacement* (some rows appear multiple times, others not at all)
2. **Refit**: Fit the same linear regression model to this resampled data
3. **Extract**: Calculate all three importance metrics (correlation, beta weight, relative weight)
4. **Repeat**: Do this many times (default: 1000 iterations)
5. **Summarize**: Use the distribution of bootstrap importance scores to estimate uncertainty

### Why It Matters for Key Driver Analysis

Standard parametric CIs assume random sampling, correct model specification, and normal residuals. Bootstrap CIs relax these assumptions and are particularly valuable when:

- **Drivers are correlated**, which inflates parametric standard errors unpredictably
- **Relative weights are used**, for which no closed-form CI exists
- **Weighted data** is involved, where effective sample size may be smaller than nominal n
- **Rankings matter**, because knowing "Product Quality is #1" is only useful if you know how confident that ranking is

## Enabling Bootstrap

Add these settings to the **Settings** sheet of your config Excel file:

| Setting | Value | Description |
|---------|-------|-------------|
| enable_bootstrap | TRUE | Enable bootstrap confidence intervals |
| bootstrap_iterations | 1000 | Number of bootstrap resamples (more = more precise, but slower) |
| bootstrap_ci_level | 0.95 | Confidence level (0.90, 0.95, or 0.99) |

All three settings are optional. When `enable_bootstrap` is TRUE, the defaults are 1000 iterations and a 95% confidence level.

**Minimum requirements**: At least 2 drivers, at least 30 complete cases (or 10 per driver, whichever is larger), all analysis columns numeric, at least 100 iterations.

## Output Columns Explained

When bootstrap is enabled, the output includes a `Bootstrap_CIs` sheet with one row per driver-method combination:

### Method

Three importance methods are bootstrapped:

- **Correlation**: Pearson correlation between driver and outcome. Bivariate association strength.
- **Beta_Weight**: Standardized regression coefficient as a percentage share. Unique contribution after controlling for other drivers.
- **Relative_Weight**: Johnson's relative weight decomposition of R-squared. Handles correlated drivers better than raw beta weights.

### Point_Estimate

The **mean** of the bootstrap distribution. Should be close to the sample estimate if the model is stable.

### CI_Lower and CI_Upper

**Percentile-based confidence interval** bounds (2.5th and 97.5th percentiles for a 95% CI). These do not assume a normal distribution and are often asymmetric.

**Interpretation**: "In 95% of bootstrap resamples, the importance score for this driver fell within this range."

### SE (Standard Error)

Standard deviation of the bootstrap distribution. Useful for informal comparisons: if two drivers' CIs overlap substantially, their ranking difference may not be reliable.

## Interpreting Results

### When CIs Are Narrow

The importance estimate is stable. The driver's ranking is unlikely to change if the study were repeated. You can make confident recommendations.

### When CIs Are Wide

The importance estimate is uncertain. Rankings involving this driver should be treated cautiously. Common causes:

| Cause | Remedy |
|-------|--------|
| Small sample size (n < 200) | Increase sample size |
| High multicollinearity | Combine or remove redundant drivers |
| Low driver variance | Check for ceiling/floor effects |
| Extreme case weights | Review weighting scheme |
| Too many drivers | Reduce driver count |

### Comparing Two Drivers

- **No CI overlap**: Strong evidence that one driver is more important
- **Partial overlap**: Suggestive but not conclusive
- **Complete overlap**: No evidence of a meaningful ranking difference

## Comparison with Parametric CIs

| Aspect | Bootstrap CI | Parametric CI |
|--------|-------------|---------------|
| Assumptions | Minimal | Normality, random sampling |
| Distribution shape | Captures asymmetry naturally | Assumes symmetric (normal) |
| Relative weights | Fully supported | No closed-form CI available |
| Correlated drivers | Handles naturally | May understate uncertainty |
| Computational cost | Higher (many model fits) | Negligible |

**When bootstrap CIs agree with parametric CIs**: Model assumptions are reasonable.

**When bootstrap CIs are wider**: Parametric CIs are likely overconfident. Use bootstrap CIs for reporting.

## Performance Considerations

### Iterations vs Runtime

| Iterations | Typical Runtime (15 drivers, n=500) | CI Precision |
|-----------|-------------------------------------|-------------|
| 100 | 5-10 seconds | Rough estimates only |
| 500 | 20-40 seconds | Adequate for exploratory work |
| 1000 | 40-90 seconds | Standard recommendation |
| 2000 | 80-180 seconds | High precision for final reporting |
| 5000 | 3-8 minutes | Maximum precision (diminishing returns) |

Runtimes scale linearly with iterations and approximately linearly with drivers and observations.

### Weighted Resampling

When a weight column is specified, bootstrap resampling draws rows proportional to their weights. This is correct behaviour for weighted data but can increase CI width when weights are highly variable.

### Failed Iterations

Some bootstrap resamples may fail (singular matrices, zero-variance columns). Results are computed from successful iterations only. If more than 20% fail, investigate for near-perfect collinearity or sparse variables.

## Example Output Table

| Driver | Method | Point_Estimate | CI_Lower | CI_Upper | SE |
|--------|--------|---------------|----------|----------|------|
| Product Quality | Correlation | 0.6234 | 0.5812 | 0.6641 | 0.0211 |
| Product Quality | Beta_Weight | 31.42 | 25.18 | 37.91 | 3.24 |
| Product Quality | Relative_Weight | 28.51 | 23.44 | 33.72 | 2.62 |
| Customer Service | Correlation | 0.5187 | 0.4622 | 0.5731 | 0.0283 |
| Customer Service | Beta_Weight | 24.33 | 18.67 | 30.44 | 3.01 |
| Customer Service | Relative_Weight | 22.78 | 17.89 | 27.92 | 2.56 |
| Price Value | Correlation | 0.4102 | 0.3411 | 0.4778 | 0.0349 |
| Price Value | Beta_Weight | 18.67 | 12.33 | 25.44 | 3.35 |
| Price Value | Relative_Weight | 19.23 | 13.56 | 25.11 | 2.95 |

**Reading this table**:

- **Product Quality**: Tight CIs across all methods. Top driver ranking is stable and reliable.
- **Customer Service**: Reasonably tight CIs. Confidently the second most important driver.
- **Price Value**: Wider CIs, particularly on Beta_Weight. Ranking relative to drivers with similar scores is uncertain.

## Troubleshooting

### "Insufficient Sample Size for Bootstrap"

The module requires at least 30 complete cases or 10 per driver (whichever is larger). Remove rows with missing values, reduce the number of drivers, or impute missing values if appropriate.

### "All Bootstrap Iterations Failed"

Every resample produced an error (typically from singular matrices). Check the VIF diagnostics for multicollinearity. Remove or combine drivers with VIF > 10.

### "n_bootstrap must be an integer >= 100"

The minimum is 100 iterations. Use at least 500 for any serious analysis.

### High Percentage of Failed Iterations

If more than 10-20% fail, check for very high inter-driver correlations (> 0.85), low-variance drivers, or an excessive number of drivers relative to sample size.

### Bootstrap CIs Are Extremely Wide

Wide CIs mean the estimate is genuinely uncertain. If they seem implausibly wide, check sample size, extreme case weights, driver variance, and the driver-to-sample-size ratio.

## References

- Efron, B. & Tibshirani, R. (1993). *An Introduction to the Bootstrap*. Chapman & Hall.
- Davison, A.C. & Hinkley, D.V. (1997). *Bootstrap Methods and their Application*. Cambridge University Press.
- Johnson, J.W. (2000). A heuristic method for estimating the relative weight of predictor variables in multiple regression. *Multivariate Behavioral Research*, 35(1), 1-19.
