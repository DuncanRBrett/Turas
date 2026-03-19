# Turas Segmentation Module - Reference Guide

**Version:** 11.1
**Last Updated:** 19 March 2026
**Target Audience:** Statisticians, Senior Analysts, Methodologists

This document provides comprehensive technical reference for the statistical methods used in the Turas Segmentation Module.

---

## Table of Contents

1. [K-Means Clustering Algorithm](#k-means-clustering-algorithm)
2. [Hierarchical Clustering Algorithm](#hierarchical-clustering-algorithm)
3. [Gaussian Mixture Models](#gaussian-mixture-models)
4. [Data Preprocessing](#data-preprocessing)
5. [Outlier Detection Methods](#outlier-detection-methods)
6. [Variable Selection Methods](#variable-selection-methods)
7. [Validation Metrics](#validation-metrics)
8. [Segment Profiling Statistics](#segment-profiling-statistics)
9. [Model Scoring](#model-scoring)
10. [Latent Class Analysis](#latent-class-analysis)
11. [Method Selection Guide](#method-selection-guide)

---

## K-Means Clustering Algorithm

### Algorithm Overview

K-means partitions n observations into k clusters by minimizing within-cluster variance. Each observation belongs to the cluster with the nearest centroid.

### Mathematical Formulation

**Objective Function:**

```
minimize J = Sigma_i=1^k Sigma_x in C_i ||x - mu_i||^2
```

Where:
- k = number of clusters
- C_i = set of observations in cluster i
- mu_i = centroid of cluster i
- ||x - mu_i||^2 = squared Euclidean distance

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
| Spherical clusters | Clusters are roughly circular | Check silhouette plot; consider GMM for elliptical |
| Equal variance | Clusters have similar spread | Standardize variables |
| Continuous data | Variables are numeric | Use LCA for categorical |
| No outliers | Extreme values distort centroids | Enable outlier detection |

---

## Hierarchical Clustering Algorithm

### Algorithm Overview

Agglomerative hierarchical clustering builds a hierarchy of clusters by iteratively merging the two most similar clusters until a single cluster remains. The result is a dendrogram (tree structure) that can be cut at any level to produce k clusters.

### Algorithm Steps

```
1. INITIALIZE: Each observation is its own cluster (n clusters)
2. COMPUTE: Calculate pairwise distances between all clusters
3. MERGE: Merge the two closest clusters into one
4. UPDATE: Recompute distances to the new cluster
5. REPEAT: Steps 3-4 until one cluster remains
6. CUT: Cut the dendrogram at the desired level to produce k clusters
```

### Linkage Methods

The linkage method determines how inter-cluster distance is computed when merging:

| Method | Formula | Properties |
|--------|---------|------------|
| **ward.D2** | Minimise total within-cluster variance increase | Tends to produce balanced, compact clusters. Default choice. |
| **complete** | d(A,B) = max{d(a,b) : a in A, b in B} | Maximum distance. Produces compact clusters. |
| **average** (UPGMA) | d(A,B) = mean{d(a,b) : a in A, b in B} | Mean distance. Compromise between single and complete. |
| **single** | d(A,B) = min{d(a,b) : a in A, b in B} | Minimum distance. Can produce chaining effects. |
| **mcquitty** (WPGMA) | Weighted average of merged distances | Similar to average but weights each group equally. |
| **median** (WPGMC) | Uses median of merged cluster distances | Robust to outliers but can produce inversions. |
| **centroid** (UPGMC) | d(A,B) = ||c_A - c_B||^2 | Distance between cluster centroids. Can produce inversions. |

**Recommendations:**
- Use **ward.D2** as the default for survey segmentation
- Use **complete** when you need well-separated, compact clusters
- Use **average** when cluster sizes vary substantially
- Avoid **single** linkage for market research (chaining effect)

### Cophenetic Correlation

The cophenetic correlation coefficient measures how faithfully the dendrogram represents the original pairwise distances.

**Formula:**
```
r_coph = cor(d_original, d_cophenetic)
```

Where:
- d_original = original pairwise distance matrix
- d_cophenetic = cophenetic distance matrix (height in dendrogram where two observations first join)

**Interpretation:**

| Value | Quality |
|-------|---------|
| > 0.85 | Excellent dendrogram fit |
| 0.70 - 0.85 | Good fit |
| 0.50 - 0.70 | Moderate fit |
| < 0.50 | Poor fit, consider a different linkage method |

### Computational Complexity

- **Distance Matrix:** O(n^2) memory and O(n^2 * p) computation
- **Merging:** O(n^2 * log n) for efficient implementations (fastcluster)
- **Practical limit:** ~15,000 observations (guarded in the module)

### Advantages Over K-Means

- No need to pre-specify k (explore dendrogram first)
- Reveals nested cluster structure
- Deterministic (no random initialization)
- Multiple linkage methods for different cluster shapes

### Limitations

- O(n^2) memory requirement (distance matrix)
- Cannot revise merges once made
- Sensitive to linkage method choice
- Does not produce centroids directly (computed as means after cutting)

---

## Gaussian Mixture Models

### Algorithm Overview

Gaussian Mixture Models (GMM) assume that the data is generated by a mixture of k multivariate Gaussian distributions. Each distribution represents a cluster (component). Unlike K-means, GMM provides soft assignments: each observation has a probability of belonging to each cluster.

### Mathematical Formulation

**Mixture Model:**

```
P(x) = Sigma_k=1^K pi_k * N(x | mu_k, Sigma_k)
```

Where:
- pi_k = mixing proportion (prior probability of component k, sum to 1)
- mu_k = mean vector of component k
- Sigma_k = covariance matrix of component k
- N(x | mu_k, Sigma_k) = multivariate Gaussian density

### EM Algorithm

GMMs are fitted using the Expectation-Maximization (EM) algorithm:

```
1. INITIALIZE: Set starting values for mu, Sigma, pi for each component
2. E-STEP: Compute posterior probabilities (responsibilities)
           gamma_ik = P(component k | x_i) for each observation
3. M-STEP: Update parameters using weighted maximum likelihood
           mu_k = weighted mean of observations
           Sigma_k = weighted covariance
           pi_k = proportion of total responsibility
4. REPEAT: Steps 2-3 until log-likelihood converges
```

### Covariance Structure (Model Types)

The `gmm_model_type` parameter controls the covariance parameterisation. The mclust package uses a compact naming convention:

| Model | Volume | Shape | Orientation | Description |
|-------|--------|-------|-------------|-------------|
| **EII** | Equal | Spherical | - | Spherical, equal volume (like K-means) |
| **VII** | Variable | Spherical | - | Spherical, variable volume |
| **EEE** | Equal | Equal | Equal | Equal ellipsoids |
| **VVV** | Variable | Variable | Variable | Most flexible, unconstrained |
| **VVI** | Variable | Variable | Axis-aligned | Diagonal covariance |

**Default behavior:** When `gmm_model_type` is left blank (NULL), mclust automatically selects the best model using BIC.

### BIC for Model Selection

**Bayesian Information Criterion:**

```
BIC = -2 * log(L) + p * log(n)
```

Where:
- L = maximized likelihood
- p = number of free parameters
- n = sample size

**Lower BIC = Better model.** BIC penalizes model complexity, balancing fit against overfitting.

### Membership Probabilities

Each observation receives a probability vector across all components:

```
gamma_ik = P(component k | x_i)

Assignment: argmax_k gamma_ik
Uncertainty: 1 - max_k gamma_ik
```

**Interpretation:**
- High max probability (> 0.80): Clear assignment
- Low max probability (< 0.60): Borderline, consider flagging
- Equal probabilities across components: Observation does not belong clearly to any segment

### Segment Assignment Output

When method = gmm, the segment assignments file includes additional columns:
- `segment_id`: Hard assignment (most probable component)
- `segment_name`: Segment label
- `prob_segment_1` through `prob_segment_k`: Per-component probabilities
- `max_probability`: Maximum probability across components
- `uncertainty`: 1 - max_probability

### Advantages Over K-Means

- Soft assignments with calibrated probabilities
- Handles elliptical and differently shaped clusters
- BIC-based principled model/k selection
- Statistical model framework (likelihood, AIC, BIC)
- Uncertainty quantification per respondent

### Limitations

- Computationally heavier than K-means
- Assumes Gaussian distribution within each component
- Can struggle in very high dimensions (>20 variables)
- Requires the `mclust` package

---

## Data Preprocessing

### Standardization (Z-Score)

**Purpose:** Give equal weight to all variables regardless of original scale.

**Formula:**
```
z = (x - mu) / sigma
```

Where:
- x = original value
- mu = variable mean
- sigma = variable standard deviation

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
z = (x - mu) / sigma
Outlier if: |z| > threshold AND extreme on >= min_vars
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
D^2_M = (x - mu)^T Sigma^(-1) (x - mu)
```

Where:
- x = observation vector
- mu = mean vector
- Sigma = covariance matrix

**Threshold:**
- Compare D^2_M to chi-square distribution with p degrees of freedom
- `outlier_alpha = 0.001` -> Flag if P(chi^2_p > D^2_M) < 0.001

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
S = (1/n) Sigma_i s(i)
```

Use for comparing different k values. Applicable to all three clustering methods.

### Elbow Method (Within-Cluster Sum of Squares)

**Purpose:** Identify point of diminishing returns for additional clusters.

**Formula:**
```
WCSS = Sigma_i=1^k Sigma_x in C_i ||x - mu_i||^2
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
Gap(k) = E*[log(W_k)] - log(W_k)
```

Where:
- W_k = within-cluster dispersion for k clusters
- E*[.] = expectation under null reference distribution

**Optimal k:**
- Choose smallest k where Gap(k) >= Gap(k+1) - SE(k+1)

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
DB = (1/k) Sigma_i=1^k max_{j != i} [(sigma_i + sigma_j) / d(c_i, c_j)]
```

Where:
- sigma_i = average distance of points in cluster i to centroid
- d(c_i, c_j) = distance between centroids

**Interpretation:**
- Lower values indicate better clustering
- 0 = perfect clustering
- Compare across k values

### Cophenetic Correlation (Hierarchical Only)

**Purpose:** Measure how well the dendrogram preserves the original distance structure.

See [Hierarchical Clustering Algorithm](#cophenetic-correlation) for formula and interpretation.

### BIC (GMM Only)

**Purpose:** Principled model selection balancing fit and complexity.

See [Gaussian Mixture Models](#bic-for-model-selection) for formula and interpretation.

---

## Segment Profiling Statistics

### Basic Profiling

**Cluster Means:**
```
mu_kj = (1/n_k) Sigma_{x in C_k} x_j
```

Mean of variable j in cluster k.

**Index Scores:**
```
Index = (mu_kj / mu_j) * 100
```

Where:
- mu_kj = cluster mean
- mu_j = overall mean
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
- P-value < 0.05 -> Significant difference between clusters
- Variables with significant p-values discriminate segments

**Effect Size (Eta-Squared):**
```
eta^2 = SSB / SST
```

| eta^2 | Interpretation |
|-------|----------------|
| 0.01 - 0.06 | Small effect |
| 0.06 - 0.14 | Medium effect |
| > 0.14 | Large effect |

**Cohen's d (Pairwise):**
```
d = (mu_1 - mu_2) / sigma_p
```

Where sigma_p = pooled standard deviation.

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

### Distance-Based Assignment (K-Means, Hierarchical)

**For new observation x:**
```
Assigned cluster = argmin_k ||x - mu_k||^2
```

Assign to cluster with nearest centroid.

### Probability-Based Assignment (GMM)

**For new observation x:**
```
Assigned cluster = argmax_k P(component k | x)
```

Assign to component with highest posterior probability. All probabilities are returned alongside the hard assignment.

### Confidence Scoring

**Relative Distance Method (K-Means/Hierarchical):**
```
Confidence = 1 - (d_min / d_second)
```

Where:
- d_min = distance to assigned cluster
- d_second = distance to second-nearest cluster

**Probability Method (GMM):**
```
Confidence = max_k P(component k | x)
Uncertainty = 1 - Confidence
```

**Interpretation:**
- Confidence near 1 = Clear assignment
- Confidence near 0 = Ambiguous (between clusters)
- Flag low-confidence assignments (< 0.5)

### Segment Drift Detection

**Chi-Square Test:**
```
chi^2 = Sigma_k [(O_k - E_k)^2 / E_k]
```

Where:
- O_k = Observed count in cluster k (new data)
- E_k = Expected count based on original proportions

**Interpretation:**
- P-value < 0.05 -> Significant distribution change
- Consider re-segmenting if substantial drift

---

## Latent Class Analysis

### When to Use LCA

| Scenario | Method |
|----------|--------|
| Continuous ratings (1-10) | K-Means, Hierarchical, or GMM |
| Binary variables (Yes/No) | LCA |
| Ordinal scales (1-5) | Either (LCA often better for ordinal) |
| Mixed types | Consider separate analyses |

### LCA Model

**Probability Model:**
```
P(x) = Sigma_k pi_k * Product_j P(x_j | class = k)
```

Where:
- pi_k = probability of belonging to class k
- P(x_j | class = k) = conditional probability of response pattern

### Model Selection

**Bayesian Information Criterion (BIC):**
```
BIC = -2 * log(L) + p * log(n)
```

Where:
- L = likelihood
- p = number of parameters
- n = sample size

**Lower BIC = Better model fit**

**Entropy:**
```
E = 1 - [Sigma_i Sigma_k p_ik * log(p_ik)] / [n * log(k)]
```

**Interpretation:**
- E > 0.8 = Good classification certainty
- E < 0.6 = Poor classification, high uncertainty

---

## Method Selection Guide

### Choosing a Clustering Method

| Criterion | K-Means | Hierarchical | GMM |
|-----------|---------|--------------|-----|
| Speed | Fast | Moderate | Slower |
| Sample size | Any | Up to ~15k | Up to ~20k |
| Cluster shape | Spherical | Depends on linkage | Elliptical |
| Assignment type | Hard | Hard | Soft (probabilities) |
| Interpretability | High | High (dendrogram) | Moderate |
| Deterministic | No (random starts) | Yes | No (EM initialization) |
| Nested structure | No | Yes | No |
| Default choice | Yes | For small-medium n | When probabilities needed |

### Choosing K (Number of Segments)

**Statistical Criteria:**
1. Highest silhouette score
2. Elbow in WCSS plot
3. Gap statistic criterion
4. BIC (GMM only)

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
| Hierarchical | Silhouette + Cophenetic | Calinski-Harabasz |
| GMM | BIC | Silhouette |

### Outlier Handling Decision

```
Is outlier % > 5%?
+-- Yes -> Investigate data quality issues
+-- No
    +-- Are outliers data errors?
        +-- Yes -> Remove (outlier_handling = remove)
        +-- No
            +-- Are outliers meaningful?
                +-- Yes -> Flag but include
                +-- Uncertain -> Flag, review manually
```

### Variable Selection Decision

```
How many candidate variables?
+-- < 10 -> Use all, skip variable selection
+-- 10-20 -> Consider selection if correlated
+-- > 20 -> Strongly recommend selection
    +-- Which method?
        +-- Simple, fast -> variance_correlation
        +-- Theory-driven -> factor_analysis
        +-- Comprehensive -> both
```

---

## Additional Resources

- [04_USER_MANUAL.md](04_USER_MANUAL.md) - Operational guide
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Configuration parameters
- [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) - Practical examples
- [08_HTML_REPORT_GUIDE.md](08_HTML_REPORT_GUIDE.md) - HTML report reference

---

**Part of the Turas Analytics Platform**
