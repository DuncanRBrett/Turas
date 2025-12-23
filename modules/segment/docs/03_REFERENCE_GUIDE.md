# Turas Segmentation Module - Reference Guide

**Version:** 10.0
**Last Updated:** 22 December 2025
**Target Audience:** Statisticians, Senior Analysts, Methodologists

This document provides comprehensive technical reference for the statistical methods used in the Turas Segmentation Module.

---

## Table of Contents

1. [K-Means Clustering Algorithm](#k-means-clustering-algorithm)
2. [Data Preprocessing](#data-preprocessing)
3. [Outlier Detection Methods](#outlier-detection-methods)
4. [Variable Selection Methods](#variable-selection-methods)
5. [Validation Metrics](#validation-metrics)
6. [Segment Profiling Statistics](#segment-profiling-statistics)
7. [Model Scoring](#model-scoring)
8. [Latent Class Analysis](#latent-class-analysis)
9. [Method Selection Guide](#method-selection-guide)

---

## K-Means Clustering Algorithm

### Algorithm Overview

K-means partitions n observations into k clusters by minimizing within-cluster variance. Each observation belongs to the cluster with the nearest centroid.

### Mathematical Formulation

**Objective Function:**

```
minimize J = Σᵢ₌₁ᵏ Σₓ∈Cᵢ ||x - μᵢ||²
```

Where:
- k = number of clusters
- Cᵢ = set of observations in cluster i
- μᵢ = centroid of cluster i
- ||x - μᵢ||² = squared Euclidean distance

### Algorithm Steps

```
1. INITIALIZE: Randomly select k observations as initial centroids
2. ASSIGN: For each observation, calculate distance to all centroids
           Assign to cluster with nearest centroid
3. UPDATE: Recalculate centroid as mean of all observations in cluster
4. REPEAT: Steps 2-3 until convergence (no reassignments)
```

### Implementation Details

**Multiple Random Starts (nstart):**
- K-means can converge to local optima
- Running multiple times with different initial centroids improves results
- Default: nstart = 25
- Recommendation: Use 25-50 for production analyses

**Convergence Criteria:**
- No change in cluster assignments between iterations
- Maximum iterations reached (default: 100)

**Distance Metric:**
- Euclidean distance (L2 norm)
- Requires continuous, scaled variables

### Assumptions

| Assumption | Description | Mitigation |
|------------|-------------|------------|
| Spherical clusters | Clusters are roughly circular | Check silhouette plot distribution |
| Equal variance | Clusters have similar spread | Standardize variables |
| Continuous data | Variables are numeric | Use LCA for categorical |
| No outliers | Extreme values distort centroids | Enable outlier detection |

---

## Data Preprocessing

### Standardization (Z-Score)

**Purpose:** Give equal weight to all variables regardless of original scale.

**Formula:**
```
z = (x - μ) / σ
```

Where:
- x = original value
- μ = variable mean
- σ = variable standard deviation

**When to Use:**
- Variables on different scales (1-5 vs 1-10)
- Variables with different variances
- Default recommendation: Always standardize

**When to Skip:**
- All variables already on same scale
- Want to preserve natural scaling
- Set `standardize = FALSE` in config

### Missing Data Handling

| Method | Description | When to Use |
|--------|-------------|-------------|
| **Listwise Deletion** | Remove cases with any missing | < 5% missing, MCAR |
| **Mean Imputation** | Replace with variable mean | 5-15% missing, MCAR |
| **Median Imputation** | Replace with variable median | Skewed distributions |
| **Refuse** | Error if any missing | Data quality enforcement |

**Missing Data Patterns:**

```
MCAR: Missing Completely At Random
      - Missingness unrelated to any variables
      - Safe to use listwise deletion

MAR:  Missing At Random
      - Missingness related to observed variables
      - Imputation acceptable

MNAR: Missing Not At Random
      - Missingness related to unobserved values
      - No simple solution, investigate cause
```

---

## Outlier Detection Methods

### Z-Score Method

**Approach:** Flag observations with extreme z-scores on specified number of variables.

**Formula:**
```
z = (x - μ) / σ
Outlier if: |z| > threshold AND extreme on ≥ min_vars
```

**Default Parameters:**
- `outlier_threshold = 3.0` (99.7% of normal distribution)
- `outlier_min_vars = 1`

**Interpretation:**

| Threshold | % Flagged (Normal) | Sensitivity |
|-----------|-------------------|-------------|
| 2.0 | 4.6% | High (many false positives) |
| 2.5 | 1.2% | Moderate |
| 3.0 | 0.3% | Standard |
| 3.5 | 0.05% | Conservative |

### Mahalanobis Distance Method

**Approach:** Multivariate distance accounting for correlations between variables.

**Formula:**
```
D²ₘ = (x - μ)ᵀ Σ⁻¹ (x - μ)
```

Where:
- x = observation vector
- μ = mean vector
- Σ = covariance matrix

**Threshold:**
- Compare D²ₘ to chi-square distribution with p degrees of freedom
- `outlier_alpha = 0.001` → Flag if P(χ²ₚ > D²ₘ) < 0.001

**Advantages:**
- Accounts for correlations between variables
- Single multivariate test
- More appropriate for correlated data

**Disadvantages:**
- Sensitive to non-normality
- Requires invertible covariance matrix
- Slower than z-score method

### Handling Strategies

| Strategy | Action | When to Use |
|----------|--------|-------------|
| **none** | Detect but don't act | Review only |
| **flag** | Mark in output | Default - allows review |
| **remove** | Exclude from clustering | Confirmed data errors |

---

## Variable Selection Methods

### Variance-Correlation Method

**Two-Stage Process:**

**Stage 1: Variance Filtering**
```
Remove variables where: Var(x) < varsel_min_variance
Default threshold: 0.1 (on standardized data)
```

Rationale: Low variance variables don't differentiate respondents.

**Stage 2: Correlation Filtering**
```
For each pair (x, y) where |r| > varsel_max_correlation:
    Remove variable with lower variance
Default threshold: 0.8
```

Rationale: Highly correlated variables are redundant.

**Final Selection:**
- Rank remaining variables by variance
- Select top `max_clustering_vars` (default: 10)

### Factor Analysis Method

**Approach:** Extract latent factors, use factor loadings to select variables.

**Steps:**
1. Run principal axis factor analysis
2. Retain factors with eigenvalue > 1
3. Rotate factors (varimax rotation)
4. For each factor, select variable with highest loading
5. Add additional high-loading variables up to max limit

**Advantages:**
- Identifies underlying constructs
- Reduces redundancy
- Theory-driven selection

**Disadvantages:**
- Requires larger sample size (n > 200)
- Results depend on rotation method
- More complex to interpret

### Combined Method (both)

**Process:**
1. Run variance-correlation filtering
2. Run factor analysis on filtered variables
3. Intersection of both methods determines final set

---

## Validation Metrics

### Silhouette Coefficient

**Purpose:** Measure how similar observations are to their own cluster compared to other clusters.

**Formula (for observation i):**
```
s(i) = [b(i) - a(i)] / max{a(i), b(i)}
```

Where:
- a(i) = average distance to other points in same cluster
- b(i) = minimum average distance to points in other clusters

**Interpretation:**

| Value | Interpretation |
|-------|----------------|
| 1.0 | Perfect separation |
| 0.7 - 1.0 | Strong structure |
| 0.5 - 0.7 | Reasonable structure |
| 0.3 - 0.5 | Weak structure |
| < 0.3 | No substantial structure |
| < 0 | Misclassified observations |

**Average Silhouette Width:**
```
S = (1/n) Σᵢ s(i)
```

Use for comparing different k values.

### Elbow Method (Within-Cluster Sum of Squares)

**Purpose:** Identify point of diminishing returns for additional clusters.

**Formula:**
```
WCSS = Σᵢ₌₁ᵏ Σₓ∈Cᵢ ||x - μᵢ||²
```

**Interpretation:**
- Plot WCSS vs. k
- Look for "elbow" where rate of decrease slows
- Elbow point suggests optimal k

**Limitations:**
- Subjective visual interpretation
- Elbow not always clear
- Use with other metrics

### Between/Total Sum of Squares Ratio

**Formula:**
```
Ratio = BSS / TSS
```

Where:
- BSS = Between-cluster sum of squares
- TSS = Total sum of squares (BSS + WCSS)

**Interpretation:**
- Range: 0 to 1
- Higher = better separation
- Typical good values: > 0.6

### Gap Statistic

**Purpose:** Compare clustering to reference null distribution.

**Formula:**
```
Gap(k) = E*[log(Wₖ)] - log(Wₖ)
```

Where:
- Wₖ = within-cluster dispersion for k clusters
- E*[·] = expectation under null reference distribution

**Optimal k:**
- Choose smallest k where Gap(k) ≥ Gap(k+1) - SE(k+1)

**Advantages:**
- Statistical foundation
- Handles non-globular clusters

**Disadvantages:**
- Computationally expensive
- Requires B bootstrap samples (default: 50)

### Calinski-Harabasz Index

**Formula:**
```
CH = [BSS / (k-1)] / [WCSS / (n-k)]
```

**Interpretation:**
- Higher values indicate better clustering
- No absolute threshold, compare across k values
- Also called Variance Ratio Criterion

### Davies-Bouldin Index

**Formula:**
```
DB = (1/k) Σᵢ₌₁ᵏ maxⱼ≠ᵢ [(σᵢ + σⱼ) / d(cᵢ, cⱼ)]
```

Where:
- σᵢ = average distance of points in cluster i to centroid
- d(cᵢ, cⱼ) = distance between centroids

**Interpretation:**
- Lower values indicate better clustering
- 0 = perfect clustering
- Compare across k values

---

## Segment Profiling Statistics

### Basic Profiling

**Cluster Means:**
```
μₖⱼ = (1/nₖ) Σₓ∈Cₖ xⱼ
```

Mean of variable j in cluster k.

**Index Scores:**
```
Index = (μₖⱼ / μⱼ) × 100
```

Where:
- μₖⱼ = cluster mean
- μⱼ = overall mean
- Index > 100 = above average
- Index < 100 = below average

### Enhanced Statistical Profiling

**One-Way ANOVA:**

Tests whether means differ significantly across clusters.

```
F = MSB / MSW
```

Where:
- MSB = Mean Square Between groups
- MSW = Mean Square Within groups

**Interpretation:**
- P-value < 0.05 → Significant difference between clusters
- Variables with significant p-values discriminate segments

**Effect Size (Eta-Squared):**
```
η² = SSB / SST
```

| η² | Interpretation |
|----|----------------|
| 0.01 - 0.06 | Small effect |
| 0.06 - 0.14 | Medium effect |
| > 0.14 | Large effect |

**Cohen's d (Pairwise):**
```
d = (μ₁ - μ₂) / σₚ
```

Where σₚ = pooled standard deviation.

| |d| | Interpretation |
|-----|----------------|
| 0.2 | Small effect |
| 0.5 | Medium effect |
| 0.8 | Large effect |

### Discriminant Analysis

**Linear Discriminant Analysis (LDA):**

Tests whether cluster membership can be predicted from variables.

**Metrics:**
- Classification accuracy (% correctly classified)
- Wilks' Lambda (multivariate separation)

**Interpretation:**
- Accuracy > 90% = Excellent discrimination
- Accuracy > 80% = Good discrimination
- Accuracy < 70% = Poor discrimination, consider fewer clusters

---

## Model Scoring

### Distance-Based Assignment

**For new observation x:**
```
Assigned cluster = argminₖ ||x - μₖ||²
```

Assign to cluster with nearest centroid.

### Confidence Scoring

**Relative Distance Method:**
```
Confidence = 1 - (d_min / d_second)
```

Where:
- d_min = distance to assigned cluster
- d_second = distance to second-nearest cluster

**Interpretation:**
- Confidence near 1 = Clear assignment
- Confidence near 0 = Ambiguous (between clusters)
- Flag low-confidence assignments (< 0.5)

### Segment Drift Detection

**Chi-Square Test:**
```
χ² = Σₖ [(Oₖ - Eₖ)² / Eₖ]
```

Where:
- Oₖ = Observed count in cluster k (new data)
- Eₖ = Expected count based on original proportions

**Interpretation:**
- P-value < 0.05 → Significant distribution change
- Consider re-segmenting if substantial drift

---

## Latent Class Analysis

### When to Use LCA

| Scenario | Method |
|----------|--------|
| Continuous ratings (1-10) | K-Means |
| Binary variables (Yes/No) | LCA |
| Ordinal scales (1-5) | Either (LCA often better) |
| Mixed types | Consider separate analyses |

### LCA Model

**Probability Model:**
```
P(x) = Σₖ πₖ ∏ⱼ P(xⱼ | class = k)
```

Where:
- πₖ = probability of belonging to class k
- P(xⱼ | class = k) = conditional probability of response pattern

### Model Selection

**Bayesian Information Criterion (BIC):**
```
BIC = -2·log(L) + p·log(n)
```

Where:
- L = likelihood
- p = number of parameters
- n = sample size

**Lower BIC = Better model fit**

**Entropy:**
```
E = 1 - [Σᵢ Σₖ pᵢₖ·log(pᵢₖ)] / [n·log(k)]
```

**Interpretation:**
- E > 0.8 = Good classification certainty
- E < 0.6 = Poor classification, high uncertainty

---

## Method Selection Guide

### Choosing K (Number of Segments)

**Statistical Criteria:**
1. Highest silhouette score
2. Elbow in WCSS plot
3. Gap statistic criterion

**Practical Criteria:**
1. Can you describe each segment distinctly?
2. Can you action each segment differently?
3. Are segment sizes reasonable (>10%)?

**Recommendation:**
- Start with k = 3-5 for most analyses
- Rarely use k > 6 in practice
- Balance statistics with interpretability

### Choosing Validation Metrics

| Situation | Primary Metric | Secondary |
|-----------|---------------|-----------|
| General use | Silhouette | Elbow |
| Large sample (n>1000) | Silhouette + Gap | Calinski-Harabasz |
| Small sample (n<200) | Silhouette only | Elbow |
| Presentation focus | Elbow (visual) | Silhouette (numeric) |

### Outlier Handling Decision

```
Is outlier % > 5%?
├── Yes → Investigate data quality issues
└── No
    └── Are outliers data errors?
        ├── Yes → Remove (outlier_handling = remove)
        └── No
            └── Are outliers meaningful?
                ├── Yes → Flag but include
                └── Uncertain → Flag, review manually
```

### Variable Selection Decision

```
How many candidate variables?
├── < 10 → Use all, skip variable selection
├── 10-20 → Consider selection if correlated
└── > 20 → Strongly recommend selection
    └── Which method?
        ├── Simple, fast → variance_correlation
        ├── Theory-driven → factor_analysis
        └── Comprehensive → both
```

---

## Additional Resources

- [04_USER_MANUAL.md](04_USER_MANUAL.md) - Operational guide
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Configuration parameters
- [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) - Practical examples

---

**Part of the Turas Analytics Platform**
