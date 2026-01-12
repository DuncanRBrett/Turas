---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Confidence Module - Authoritative Guide

**Version:** 2.0.0 **Last Updated:** December 2025 **Audience:**
Statisticians, Senior Analysts, Researchers

------------------------------------------------------------------------

## Table of Contents

1.  [Module Overview](#module-overview)
2.  [Statistical Methods -
    Proportions](#statistical-methods---proportions)
3.  [Statistical Methods - Means](#statistical-methods---means)
4.  [Statistical Methods - NPS](#statistical-methods---nps)
5.  [Weighted Data Analysis](#weighted-data-analysis)
6.  [Representativeness Diagnostics](#representativeness-diagnostics)
7.  [Method Selection Guide](#method-selection-guide)
8.  [Strengths and Limitations](#strengths-and-limitations)
9.  [Comparison with Alternatives](#comparison-with-alternatives)
10. [Technical Implementation](#technical-implementation)
11. [R Packages Used](#r-packages-used)
12. [References](#references)

------------------------------------------------------------------------

## Module Overview {#module-overview}

The Turas Confidence Module provides statistical confidence interval
calculations for survey data. It is designed for market research and
social science applications where:

-   Data may be weighted to represent target populations
-   Multiple statistical methods should be available
-   Output must be professional and client-ready
-   Configuration should be accessible to non-programmers

### Core Capabilities

| Capability           | Status     | Methods                             |
|----------------------|------------|-------------------------------------|
| Proportion CIs       | Production | Normal, Wilson, Bootstrap, Bayesian |
| Mean CIs             | Production | t-distribution, Bootstrap, Bayesian |
| NPS CIs              | Production | Normal, Bootstrap, Bayesian         |
| Weighted Analysis    | Production | Kish effective n, DEFF              |
| Representativeness   | Production | Simple & nested quotas              |
| Multiple Comparisons | Planned    | Bonferroni, Holm, FDR               |

------------------------------------------------------------------------

## Statistical Methods - Proportions {#statistical-methods---proportions}

### Method 1: Normal Approximation (Margin of Error)

**Formula:**

```         
SE = sqrt(p * (1 - p) / n_eff)
MOE = z * SE
CI = [p - MOE, p + MOE]
```

Where: - `p` = sample proportion - `n_eff` = effective sample size - `z`
= critical value (1.96 for 95% CI)

**Assumptions:** - Normal approximation to binomial distribution - np ≥
10 and n(1-p) ≥ 10 (rule of thumb)

**Strengths:** - Fast computation - Easy to explain to stakeholders -
Widely recognized in industry

**Weaknesses:** - Can produce intervals outside [0, 1] - Poor coverage
for extreme proportions (p \< 0.1 or p \> 0.9) - Poor coverage for small
samples (n \< 30)

**When to Use:** - Large samples (n \> 100) - Moderate proportions (0.2
\< p \< 0.8) - Client requires "traditional" MOE

------------------------------------------------------------------------

### Method 2: Wilson Score Interval

**Formula:**

```         
p_adj = (p + z²/2n) / (1 + z²/n)
SE_adj = sqrt((p(1-p) + z²/4n) / n) / (1 + z²/n)
CI = [p_adj - z*SE_adj, p_adj + z*SE_adj]
```

**Strengths:** - Always produces intervals within [0, 1] - Good coverage
even for small samples - Recommended by statisticians (Agresti & Coull,
1998)

**Weaknesses:** - Slightly more complex formula - Less familiar to
non-statisticians - Asymmetric intervals may confuse some readers

**When to Use:** - Default choice for proportions - Small samples (n \<
100) - Extreme proportions (p \< 0.1 or p \> 0.9) - Publication-quality
results

------------------------------------------------------------------------

### Method 3: Bootstrap Resampling

**Algorithm:**

```         
For i = 1 to B:
  1. Resample data with replacement (size = n)
  2. If weighted: sample with probability proportional to weights
  3. Calculate proportion p_i
  4. Store p_i

CI_lower = percentile(p*, α/2)
CI_upper = percentile(p*, 1 - α/2)
```

**Implementation Details:** - Default iterations: B = 5,000 -
Recommended range: 1,000 to 10,000 - Uses percentile method (not BCa or
studentized)

**Strengths:** - No distributional assumptions - Correctly handles
complex weighting - Robust to outliers - Applicable to any statistic

**Weaknesses:** - Computationally intensive - Unstable for very small
samples (n \< 20) - Results vary slightly between runs (random seed
dependent)

**When to Use:** - Complex weighted surveys - Non-normal data
distributions - When theoretical assumptions questionable - Validation
of parametric methods

------------------------------------------------------------------------

### Method 4: Bayesian Credible Interval

**Model:**

```         
Prior: Beta(α₀, β₀)
Likelihood: Binomial(n, p)
Posterior: Beta(α₀ + x, β₀ + n - x)

Where x = number of successes
```

**Prior Options:**

| Prior Type | α₀ | β₀ | Use Case |
|------------------|------------------|------------------|------------------|
| Uniform (uninformative) | 1 | 1 | No prior knowledge |
| Jeffrey's | 0.5 | 0.5 | Default recommendation |
| Informed | from prior_mean, prior_n | from prior_mean, prior_n | Previous wave data |

**Informed Prior Calculation:**

```         
α₀ = prior_mean * prior_n
β₀ = (1 - prior_mean) * prior_n
```

**Strengths:** - Incorporates prior knowledge - Intuitive interpretation
("95% probability the true value is in this interval") - Regularization
for small samples - Useful for tracking studies

**Weaknesses:** - Prior specification is subjective - May be unfamiliar
to stakeholders - Credible ≠ confidence (different interpretations)

**When to Use:** - Tracking studies with previous wave data - Small
samples needing regularization - When prior information is available and
trusted

------------------------------------------------------------------------

## Statistical Methods - Means {#statistical-methods---means}

### Method 1: Student's t-Distribution

**Formula:**

```         
SE = SD / sqrt(n_eff)
t = t-critical value with df = n_eff - 1
CI = [mean - t*SE, mean + t*SE]
```

**For Weighted Data:**

```         
weighted_mean = Σ(w_i * x_i) / Σ(w_i)
weighted_var = Σ(w_i * (x_i - weighted_mean)²) / Σ(w_i)
SE = sqrt(weighted_var / n_eff)
```

**Strengths:** - Standard method for means - Accounts for sample size
through t-distribution - Well-understood and documented

**Weaknesses:** - Assumes normally distributed data - Sensitive to
outliers - May be anticonservative for very small samples

**When to Use:** - Normally distributed data - Rating scales (1-5,
1-10) - Large samples (n \> 30)

------------------------------------------------------------------------

### Method 2: Bootstrap Resampling

**Algorithm:**

```         
For i = 1 to B:
  1. Resample data with replacement
  2. If weighted: include weights in resampling
  3. Calculate mean_i (weighted if applicable)
  4. Store mean_i

CI_lower = percentile(means, α/2)
CI_upper = percentile(means, 1 - α/2)
```

**Strengths:** - No normality assumption - Handles skewed
distributions - Robust to outliers - Correct for weighted data

**Weaknesses:** - Computationally intensive - Unstable for very small
samples

**When to Use:** - Skewed data (income, time durations) - Complex
weighting - When normality questionable

------------------------------------------------------------------------

### Method 3: Bayesian Credible Interval

**Model:**

```         
Prior: Normal(μ₀, σ₀²)
Likelihood: Normal(x̄, σ²/n)
Posterior: Normal(μ', σ'²)

Where:
τ₀ = 1/σ₀² (prior precision)
τ_data = n/σ² (data precision)
τ' = τ₀ + τ_data
μ' = (τ₀*μ₀ + τ_data*x̄) / τ'
```

**Prior Specification:**

```         
prior_mean = expected mean value
prior_sd = uncertainty around prior mean
prior_n = effective prior sample size
```

**Strengths:** - Incorporates prior knowledge - Regularization for small
samples - Tracking study applications

**Weaknesses:** - Requires prior specification - May be unfamiliar to
stakeholders

**When to Use:** - Tracking studies - Small subgroup analysis - When
prior information available

------------------------------------------------------------------------

## Statistical Methods - NPS {#statistical-methods---nps}

### NPS Calculation

**Definition:**

```         
NPS = %Promoters - %Detractors

Where:
- Promoters: respondents rating 9 or 10 (on 0-10 scale)
- Passives: respondents rating 7 or 8
- Detractors: respondents rating 0 to 6

NPS range: -100 to +100
```

### NPS Standard Error

**Variance of Difference:**

```         
Var(NPS) = Var(p_promoter) + Var(p_detractor) - 2*Cov(p_promoter, p_detractor)
```

Since promoters and detractors are mutually exclusive (a respondent
cannot be both):

```         
Cov(p_promoter, p_detractor) = -p_promoter * p_detractor / n
```

**Final Formula:**

```         
Var(NPS) = (p_p*(1-p_p) + p_d*(1-p_d) + 2*p_p*p_d) / n_eff
SE(NPS) = sqrt(Var(NPS))
MOE = z * SE(NPS) * 100  # Convert to percentage points
```

### NPS Confidence Interval Methods

**Normal Approximation:**

```         
CI = [NPS - MOE, NPS + MOE]
```

**Bootstrap:** Resample full dataset, calculate NPS for each resample,
take percentiles.

**Bayesian Credible Interval:**

```
Prior: Normal(μ₀, σ₀²) on NPS score
Likelihood: Normal(NPS_obs, SE²)

Posterior parameters:
τ₀ = 1/σ₀² (prior precision)
τ_data = 1/SE² (data precision)
τ_post = τ₀ + τ_data
μ_post = (τ₀*μ₀ + τ_data*NPS_obs) / τ_post
σ_post = sqrt(1 / τ_post)

CI = [qnorm(α/2, μ_post, σ_post), qnorm(1-α/2, μ_post, σ_post)]
```

**Note:** This uses a Normal-Normal conjugate prior on the NPS score
directly, not a Dirichlet prior on the promoter/passive/detractor
proportions. The SE for the observed NPS is calculated using the delta
method from the promoter and detractor proportions.

**Prior Specification:**
- `prior_mean`: Expected NPS (e.g., from previous wave)
- `prior_sd`: Uncertainty around prior (default = 50 for wide/uninformative)

------------------------------------------------------------------------

## Weighted Data Analysis {#weighted-data-analysis}

### Effective Sample Size (Kish Formula)

**Formula:**

```         
n_eff = (Σw_i)² / Σ(w_i²)
```

**Interpretation:** - n_eff ≤ n_actual (always) - Represents "equivalent
unweighted sample size" - Larger weight variation → smaller n_eff

### Design Effect (DEFF)

**Formula:**

```         
DEFF = n_actual / n_eff
     = 1 + CV²(weights)

Where CV = SD(weights) / mean(weights)
```

**Interpretation:**

| DEFF  | Weight Variation         | Impact                    |
|-------|--------------------------|---------------------------|
| 1.0   | None (all weights equal) | No precision loss         |
| 1.2   | Low (CV ≈ 0.45)          | 20% variance inflation    |
| 1.5   | Moderate (CV ≈ 0.71)     | 50% variance inflation    |
| 2.0   | High (CV ≈ 1.0)          | Variance doubled          |
| \>2.5 | Very high                | Review weighting approach |

### Weight Quality Diagnostics

**Weight Concentration:**

```         
Top_K%_Share = Σ(top K% of weights) / Σ(all weights)
```

**Thresholds:**

| Metric       | LOW   | MODERATE | HIGH  |
|--------------|-------|----------|-------|
| Top 5% Share | \<15% | 15-25%   | \>25% |

------------------------------------------------------------------------

## Representativeness Diagnostics {#representativeness-diagnostics}

### Margin Comparison

**Calculation:**

```         
Diff_pp = (Weighted_Sample_% - Target_%) * 100
```

**Traffic-Light Flags:**

| Flag  | Threshold             | Interpretation        |
|-------|-----------------------|-----------------------|
| GREEN | \|Diff\| \< 2pp       | Excellent match       |
| AMBER | 2pp ≤ \|Diff\| \< 5pp | Acceptable deviation  |
| RED   | \|Diff\| ≥ 5pp        | Substantial deviation |

### Simple vs Nested Quotas

**Simple Quotas:** Single variable (e.g., Gender)

```         
Target: Male = 48%, Female = 52%
Check: Each category independently
```

**Nested Quotas:** Multi-variable interaction (e.g., Gender × Age)

```         
Target: Male_18-24 = 7%, Female_18-24 = 8%, ...
Check: Each cell of the cross-tabulation
```

------------------------------------------------------------------------

## Method Selection Guide {#method-selection-guide}

### Decision Tree for Proportions

```         
START
│
├─ Sample size < 30?
│  └─ YES → Wilson Score (never use Normal)
│
├─ Proportion < 0.1 or > 0.9?
│  └─ YES → Wilson Score
│
├─ Complex weighting?
│  └─ YES → Bootstrap (validation)
│
├─ Tracking study with prior data?
│  └─ YES → Bayesian
│
└─ Otherwise → Wilson Score (default) or Normal (if required)
```

### Decision Tree for Means

```         
START
│
├─ Distribution heavily skewed?
│  └─ YES → Bootstrap
│
├─ Complex weighting?
│  └─ YES → Bootstrap + t-distribution for comparison
│
├─ Tracking study with prior data?
│  └─ YES → Bayesian
│
└─ Otherwise → t-distribution (default)
```

### Recommended Defaults

| Statistic       | Standard            | Thorough           |
|-----------------|---------------------|--------------------|
| **Proportions** | Wilson only         | Wilson + Bootstrap |
| **Means**       | t-distribution only | t-dist + Bootstrap |
| **NPS**         | Normal + Bootstrap  | All three methods  |

------------------------------------------------------------------------

## Strengths and Limitations {#strengths-and-limitations}

### Strengths

1.  **Multiple Methods:** Four proportion methods, three mean methods
2.  **Weighted Data:** Full DEFF and effective n support
3.  **Excel Configuration:** No R coding required
4.  **Professional Output:** Client-ready workbooks
5.  **Representativeness:** Built-in quota checking
6.  **NPS Support:** Full Net Promoter Score analysis
7.  **Bayesian Option:** Prior incorporation for tracking
8.  **Tested:** Comprehensive test suite

### Limitations

1.  **Total Column Only:** Currently analyzes overall results, not
    banner breaks
2.  **200 Question Limit:** Prevents accidental large runs
3.  **No Significance Testing:** Compares CIs visually, no formal tests
4.  **Single Confidence Level:** One level for all questions
    (configurable, but consistent)
5.  **No Cluster Sampling:** DEFF accounts for weights only, not cluster
    design
6.  **R Dependency:** Requires R installation

### Known Issues

1.  **Bootstrap Speed:** Can be slow for very large datasets (\>50,000)
2.  **Excel Size:** Large question sets produce large workbooks
3.  **Memory:** Bootstrap with high iterations uses substantial RAM

------------------------------------------------------------------------

## Comparison with Alternatives {#comparison-with-alternatives}

### vs. SPSS Complex Samples

| Feature        | Turas Confidence     | SPSS Complex Samples |
|----------------|----------------------|----------------------|
| CI Methods     | 4 proportion, 3 mean | Limited              |
| NPS Support    | Yes                  | Manual               |
| Configuration  | Excel template       | GUI/Syntax           |
| Output         | Excel workbook       | SPSS tables          |
| Bayesian       | Yes                  | No                   |
| Cost           | Included in Turas    | Expensive add-on     |
| Quota Checking | Built-in             | Separate procedure   |

### vs. R survey Package

| Feature          | Turas Confidence | R survey       |
|------------------|------------------|----------------|
| Ease of Use      | Excel config     | R scripting    |
| CI Methods       | Multiple         | Primarily Wald |
| Output Format    | Excel            | R objects      |
| Learning Curve   | Low              | High           |
| Flexibility      | Moderate         | Very high      |
| Cluster Sampling | No               | Yes            |

### vs. Manual Calculation

| Feature       | Turas Confidence | Manual          |
|---------------|------------------|-----------------|
| Speed         | Seconds          | Hours           |
| Accuracy      | Tested           | Error-prone     |
| Consistency   | Guaranteed       | Variable        |
| Documentation | Automatic        | Manual          |
| Weighted Data | Correct          | Often incorrect |

------------------------------------------------------------------------

## Technical Implementation {#technical-implementation}

### Architecture

```         
modules/confidence/
├── R/
│   ├── 00_main.R          # Main orchestration
│   ├── 01_load_config.R   # Configuration loading
│   ├── 02_load_data.R     # Data loading
│   ├── 03_study_level.R   # DEFF, effective n
│   ├── 04_proportions.R   # Proportion CI methods
│   ├── 05_means.R         # Mean CI methods
│   ├── 06_nps.R           # NPS calculations
│   └── 07_output.R        # Excel generation
├── tests/                  # Test suite
└── docs/                   # This documentation
```

### Data Flow

```         
Config (Excel) → load_confidence_config()
                        ↓
                 load_survey_data()
                        ↓
              calculate_study_level_stats()
                        ↓
                process_questions()
                   ├── Proportions
                   ├── Means
                   └── NPS
                        ↓
              write_confidence_output() → Excel
```

### Key Algorithms

**Values/Weights Alignment:** Critical for weighted calculations. Always
align valid values with valid weights before computation.

``` r
valid_idx <- !is.na(values) & is.finite(values)
if (!is.null(weights)) {
  good_idx <- valid_idx & !is.na(weights) & weights > 0
  values_valid <- values[good_idx]
  weights_valid <- weights[good_idx]
}
```

**Bootstrap Resampling:**

``` r
for (i in 1:B) {
  idx <- sample(1:n, size = n, replace = TRUE, prob = weights)
  boot_sample <- values[idx]
  boot_weights <- weights[idx]
  boot_stats[i] <- weighted_stat(boot_sample, boot_weights)
}
```

------------------------------------------------------------------------

## R Packages Used {#r-packages-used}

### Required Dependencies

| Package      | Version | Purpose                 |
|--------------|---------|-------------------------|
| `readxl`     | ≥1.4.0  | Read Excel config files |
| `openxlsx`   | ≥4.2.5  | Write Excel output      |
| `data.table` | ≥1.14.0 | Fast CSV loading        |

### Optional Dependencies

| Package | Purpose                                     |
|---------|---------------------------------------------|
| `dplyr` | Data manipulation (fallback if unavailable) |

### Base R Only

The statistical calculations use only base R functions: - `qnorm()` -
Normal quantiles - `qt()` - t-distribution quantiles - `qbeta()` - Beta
distribution quantiles - `sample()` - Random sampling for bootstrap -
`weighted.mean()` - Weighted means

------------------------------------------------------------------------

## References {#references}

### Statistical Methods

**Wilson Score Interval:** - Wilson, E. B. (1927). Probable inference,
the law of succession, and statistical inference. *Journal of the
American Statistical Association*, 22(158), 209-212. - Agresti, A., &
Coull, B. A. (1998). Approximate is better than "exact" for interval
estimation of binomial proportions. *The American Statistician*, 52(2),
119-126.

**Bootstrap Methods:** - Efron, B., & Tibshirani, R. J. (1993). *An
Introduction to the Bootstrap*. Chapman & Hall/CRC.

**Bayesian Methods:** - Gelman, A., Carlin, J. B., Stern, H. S., Dunson,
D. B., Vehtari, A., & Rubin, D. B. (2013). *Bayesian Data Analysis* (3rd
ed.). Chapman & Hall/CRC.

**Design Effects:** - Kish, L. (1965). *Survey Sampling*. John Wiley &
Sons.

**Net Promoter Score:** - Reichheld, F. F. (2003). The one number you
need to grow. *Harvard Business Review*, 81(12), 46-54.

### Implementation References

**R Language:** - R Core Team (2024). R: A language and environment for
statistical computing. R Foundation for Statistical Computing.

**Excel Output:** - openxlsx package documentation:
<https://ycphs.github.io/openxlsx/>

------------------------------------------------------------------------

## Appendix: Formula Reference

### Proportion CI Formulas

**Normal (Wald):**

```         
CI = p ± z * sqrt(p(1-p)/n)
```

**Wilson:**

```         
CI = (p + z²/2n ± z*sqrt(p(1-p)/n + z²/4n²)) / (1 + z²/n)
```

**Bayesian (Beta posterior):**

```         
CI = [qbeta(α/2, a+x, b+n-x), qbeta(1-α/2, a+x, b+n-x)]
```

### Mean CI Formulas

**t-distribution:**

```         
CI = x̄ ± t_(n-1,α/2) * s/sqrt(n)
```

**Weighted:**

```         
CI = x̄_w ± t_(n_eff-1,α/2) * sqrt(s²_w/n_eff)
```

### Effective Sample Size

**Kish:**

```         
n_eff = (Σw)² / Σw²
```

**DEFF:**

```         
DEFF = 1 + CV²(w) = n/n_eff
```

------------------------------------------------------------------------

**End of Authoritative Guide**

*Turas Confidence Module v2.0.0* *Last Updated: December 2025*
