# Bootstrap Confidence Intervals Guide

## Overview

Bootstrap confidence intervals provide a more robust alternative to model-based confidence intervals, particularly useful for **non-probability samples** (quota samples, self-selection surveys, panel samples) commonly used in market research.

## How Bootstrap Works

### The Basic Idea

1. **Resample**: Randomly draw N observations from your data *with replacement* (some rows appear multiple times, others not at all)
2. **Refit**: Fit the same logistic regression model to this resampled data
3. **Extract**: Record the odds ratios from this model
4. **Repeat**: Do this many times (default: 200 resamples)
5. **Summarize**: Use the distribution of bootstrap odds ratios to estimate uncertainty

### Why It's Better for Non-Probability Samples

Traditional (model-based) confidence intervals assume:
- Random sampling from a population
- The model is correctly specified
- Large sample asymptotics apply

Bootstrap CIs instead ask: "If I repeated this survey many times, how much would my estimates vary?" This is more appropriate when you can't assume random sampling.

## Enabling Bootstrap

Add these settings to your config file's **Settings** sheet:

| Setting | Value | Description |
|---------|-------|-------------|
| bootstrap_ci | TRUE | Enable bootstrap analysis |
| bootstrap_reps | 200 | Number of bootstrap resamples (more = more precise, but slower) |

**Runtime**: Expect 1-3 minutes with 200 resamples, depending on sample size and number of predictors.

## Output Columns Explained

When bootstrap is enabled, three new columns appear in the **Odds Ratios** sheet:

### 1. Bootstrap OR (median)

The **median** odds ratio across all bootstrap resamples.

- More robust than the mean (less affected by extreme values)
- Should be close to the model-based OR if the model is stable
- Large differences from model-based OR suggest instability

**Example**: If model-based OR = 2.5 and Bootstrap OR = 2.3, the estimate is stable. If model-based OR = 2.5 and Bootstrap OR = 4.1, investigate further.

### 2. Bootstrap 95% CI

The **percentile confidence interval** from bootstrap resamples.

- Lower bound = 2.5th percentile of bootstrap ORs
- Upper bound = 97.5th percentile of bootstrap ORs
- Does NOT assume normal distribution
- Often wider than model-based CIs (more honest about uncertainty)

**Interpretation**: "In 95% of bootstrap resamples, the OR fell within this range."

**Comparison to model-based CI**:
- If bootstrap CI is similar to model-based CI → model assumptions are reasonable
- If bootstrap CI is much wider → model-based CI may understate uncertainty
- If bootstrap CI is asymmetric → the sampling distribution is skewed

### 3. Sign Stability

The **percentage of bootstrap resamples** where the odds ratio stayed on the same side of 1.0 as the median.

- 100% = Direction never flipped (very stable)
- 95%+ = Highly stable, confident in direction
- 80-95% = Moderately stable
- <80% = Unstable, direction uncertain

**This is the most important bootstrap metric for decision-making.**

**Example interpretations**:
- OR = 2.5, Sign Stability = 98% → "Grade A consistently predicts higher satisfaction"
- OR = 1.3, Sign Stability = 72% → "Effect is weak and direction is uncertain"
- OR = 0.4, Sign Stability = 99% → "Factor X consistently predicts lower satisfaction"

## Practical Guidelines

### When to Use Bootstrap

| Scenario | Recommendation |
|----------|----------------|
| Quota sample, n > 300 | Recommended |
| Self-selection sample | Recommended |
| Small sample (n < 200) | Highly recommended |
| Weighted data with extreme weights | Highly recommended |
| Academic/regulatory reporting | Required for credibility |
| Quick exploratory analysis | Optional (adds time) |

### Interpreting Results

**Strong evidence (act on this)**:
- Large OR (> 2.0 or < 0.5)
- Narrow bootstrap CI
- Sign stability > 95%

**Moderate evidence (investigate further)**:
- Medium OR (1.5-2.0 or 0.5-0.67)
- Bootstrap CI doesn't cross 1.0
- Sign stability 85-95%

**Weak evidence (use caution)**:
- Small OR (1.1-1.5 or 0.67-0.9)
- Bootstrap CI crosses 1.0
- Sign stability < 85%

### Red Flags

1. **Bootstrap OR very different from model-based OR**: Model may be unstable or influenced by outliers

2. **Bootstrap CI much wider than model-based CI**: Model-based CI is overconfident; use bootstrap CI for reporting

3. **Low sign stability on "significant" effects**: P-value may be misleading; effect direction is uncertain

4. **Many failed bootstrap resamples** (e.g., 150/200 successful): Data has structural issues (sparse cells, separation)

## Technical Details

### Algorithm

```
For b = 1 to n_bootstrap:
    1. Sample n rows with replacement from data
    2. Fit ordinal/binary logistic regression
    3. Store exp(coefficients) as odds ratios

For each coefficient:
    - median_or = median of bootstrap ORs
    - ci_lower = 2.5th percentile
    - ci_upper = 97.5th percentile
    - sign_stability = proportion where sign(log(OR)) matches sign(log(median_or))
```

### Limitations

1. **Multinomial models**: Bootstrap is disabled for multinomial outcomes (complexity)

2. **Computational cost**: 200 model fits takes 1-3 minutes

3. **Failed resamples**: Some bootstrap samples may fail to converge (sparse data). Results use successful resamples only.

4. **Not a fix for bias**: Bootstrap addresses variance/precision, not systematic bias from non-random sampling

## Example Interpretation

| Factor | Comparison | Model OR | Model 95% CI | Bootstrap OR | Bootstrap 95% CI | Sign Stability |
|--------|------------|----------|--------------|--------------|------------------|----------------|
| Grade | A vs D | 6.58 | [3.21, 13.5] | 6.42 | [2.89, 14.2] | 98% |
| Grade | B vs D | 2.34 | [1.45, 3.78] | 2.28 | [1.31, 4.12] | 94% |
| Grade | C vs D | 1.18 | [0.82, 1.70] | 1.15 | [0.76, 1.89] | 68% |

**Reading this table**:

- **Grade A vs D**: Strong, stable effect. Both CIs exclude 1.0, sign stability 98%. Confident that Grade A predicts higher satisfaction.

- **Grade B vs D**: Moderate effect. Bootstrap CI slightly wider but still excludes 1.0. Sign stability 94% is good.

- **Grade C vs D**: Weak, unstable effect. Both CIs include 1.0, sign stability only 68%. Cannot confidently say Grade C differs from Grade D.

## References

- Efron, B. & Tibshirani, R. (1993). *An Introduction to the Bootstrap*. Chapman & Hall.
- Davison, A.C. & Hinkley, D.V. (1997). *Bootstrap Methods and their Application*. Cambridge University Press.
