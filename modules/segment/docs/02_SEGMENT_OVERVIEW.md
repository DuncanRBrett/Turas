# Turas Segmentation Module - Overview

**Version:** 11.0
**Last Updated:** 5 March 2026

Transform your survey data into actionable customer segments with multiple clustering algorithms, interactive HTML reports, and executive-ready deliverables.

---

## Table of Contents

1. [What is Customer Segmentation?](#what-is-customer-segmentation)
2. [Key Capabilities](#key-capabilities)
3. [Business Applications](#business-applications)
4. [Workflow Overview](#workflow-overview)
5. [Feature Comparison](#feature-comparison)
6. [Technical Requirements](#technical-requirements)
7. [Getting Started](#getting-started)

---

## What is Customer Segmentation?

Customer segmentation divides your respondents into distinct groups (segments) based on similarities in their attitudes, behaviors, or satisfaction levels. The Turas Segmentation Module offers three proven statistical methods: **K-means clustering**, **Hierarchical clustering**, and **Gaussian Mixture Models (GMM)**, allowing analysts to choose the best approach for their data.

### Why Segment Your Customers?

| Without Segmentation | With Segmentation |
|---------------------|-------------------|
| One-size-fits-all marketing | Tailored messaging per segment |
| Average satisfaction scores | Segment-specific insights |
| Generic action plans | Targeted interventions |
| Miss critical subgroups | Identify at-risk customers |
| Inefficient resource allocation | Prioritized investments |

### What Makes Good Segments?

**Effective segments are:**
- **Distinct** - Clearly different from each other
- **Stable** - Consistent membership over time
- **Actionable** - Can tailor strategies to each
- **Sized appropriately** - Large enough to matter (typically 10-40% each)
- **Interpretable** - Stakeholders can understand and describe them

---

## Key Capabilities

### Core Clustering

| Feature | Description |
|---------|-------------|
| **K-Means Clustering** | Industry-standard algorithm for continuous data |
| **Hierarchical Clustering** | Agglomerative method with dendrogram and multiple linkage options |
| **Gaussian Mixture Models** | Soft-assignment clustering with membership probabilities |
| **Automatic K Selection** | Tests multiple k values with statistical recommendations |
| **Exploration Mode** | Compare 2-10 segment solutions before committing |
| **Final Mode** | Detailed profiling of chosen solution |
| **Model Persistence** | Save models to score new data consistently |
| **Multi-Method Comparison** | Run kmeans, hclust, and GMM simultaneously with tabbed HTML report |

### Data Quality

| Feature | Description |
|---------|-------------|
| **Outlier Detection** | Z-score and Mahalanobis distance methods |
| **Missing Data Handling** | Listwise deletion, mean/median imputation |
| **Variable Standardization** | Automatic scaling for equal weighting |
| **Variable Selection** | Reduce 20+ variables to optimal subset |
| **Data Validation** | Comprehensive checks before analysis |

### Validation & Profiling

| Feature | Description |
|---------|-------------|
| **Silhouette Analysis** | Measure cluster quality (-1 to +1) |
| **Elbow Method** | Visual identification of optimal k |
| **Gap Statistic** | Compare to random data (optional) |
| **Calinski-Harabasz Index** | Cluster separation metric |
| **Cophenetic Correlation** | Dendrogram fit quality (hierarchical only) |
| **BIC Model Selection** | Principled model comparison (GMM only) |
| **Stability Assessment** | Multi-run consistency check |
| **Enhanced Profiling** | ANOVA tests and effect sizes |
| **Vulnerability Analysis** | Assignment confidence scores and segment switching identification |

### Scoring & Application

| Feature | Description |
|---------|-------------|
| **Model Scoring** | Classify new respondents to existing segments |
| **Confidence Scores** | Distance-based assignment confidence |
| **GMM Probabilities** | Soft membership probabilities per segment |
| **Segment Drift Monitoring** | Track distribution changes over time |
| **Respondent Typing** | Single or batch classification |

### Interactive HTML Reports (v11.0)

| Feature | Description |
|---------|-------------|
| **Self-Contained HTML** | Single-file report with no external dependencies |
| **SVG Charts** | Scalable vector charts for sizes, silhouette, heatmap, importance |
| **Sticky Navigation** | Section-aware nav bar for quick access |
| **Pinned Views** | Collect charts and tables into a curated workspace |
| **Slide Export** | Export individual sections as PNG for presentations |
| **Brand Customisation** | Configure colours and titles from the config Excel file |
| **Section Visibility** | Toggle report sections on/off via config flags |
| **Exploration Report** | K-selection variant with elbow plot and solution previews |

### Enhanced Features (v11.0)

| Feature | Description |
|---------|-------------|
| **Executive Summary** | Auto-generated narrative overview with quality assessment |
| **Classification Rules** | Plain-English decision rules from decision trees |
| **Segment Action Cards** | Executive-ready cards with strengths, pain points, and actions |
| **Auto Segment Naming** | Generate meaningful names automatically |
| **Golden Questions** | Identify minimum questions to predict segments |
| **Variable Importance** | Rank variables by discriminating power (eta-squared) |
| **Demographic Profiling** | Chi-square analysis of segment composition |
| **Stability Check** | Fast multi-run consistency verification |
| **Segment Assignments** | Excel output with ID, segment_id, segment_name (+ GMM probabilities) |
| **Latent Class Analysis** | Alternative method for categorical data |

---

## Business Applications

### Customer Satisfaction Studies

**Use Case:** Identify satisfaction-based segments for targeted improvements.

**Approach:**
- Cluster on satisfaction attributes (product, service, value)
- Profile segments by demographics and behavior
- Create action plans for "At-Risk" and "Detractor" segments

**Typical Segments:**
- Advocates (highly satisfied, high loyalty)
- Satisfied (above average, stable)
- Neutral (mixed satisfaction)
- At-Risk (below average, intervention needed)
- Detractors (low satisfaction, churn risk)

### Market Research

**Use Case:** Define market segments for product positioning.

**Approach:**
- Cluster on needs, preferences, or usage patterns
- Identify unmet needs in specific segments
- Size segments for market opportunity assessment

**Typical Segments:**
- Premium Seekers (quality over price)
- Value Hunters (price-sensitive)
- Convenience Focused (time-saving priority)
- Feature Enthusiasts (want all features)

### NPS Follow-Up

**Use Case:** Understand what drives Promoters vs. Detractors.

**Approach:**
- Segment within NPS groups (e.g., cluster Detractors)
- Identify sub-types with different pain points
- Create targeted recovery strategies

**Typical Sub-Segments:**
- Price Detractors (value issues)
- Service Detractors (support issues)
- Product Detractors (quality issues)

### Employee Engagement

**Use Case:** Identify employee segments for HR interventions.

**Approach:**
- Cluster on engagement dimensions
- Profile by department, tenure, role
- Create segment-specific engagement strategies

---

## Workflow Overview

### Two-Phase Workflow

```
Phase 1: EXPLORATION                 Phase 2: FINAL
+-----------------------+           +-----------------------+
| Test k = 3 to 6       |           | Run with k = 4        |
| Compare methods        | -- Choose --> | Full profiling         |
| Review HTML report     |           | HTML report + cards   |
+-----------------------+           +-----------------------+
         |                                    |
         v                                    v
    Exploration                         Final Report
    Report (Excel + HTML)               Assignments (Excel)
    (which k is best?)                  HTML Report
                                        Model (.rds)
```

### Step-by-Step Process

1. **Configure** - Create Excel config with data path, variables, and method
2. **Validate** - Run validation checks on data quality
3. **Explore** - Test multiple k values (3-6 typical)
4. **Review** - Compare silhouette scores and profiles in HTML report
5. **Decide** - Choose optimal k based on metrics and interpretability
6. **Finalize** - Run final segmentation with chosen k
7. **Profile** - Interpret segments and assign names
8. **Deliver** - Share HTML report with stakeholders
9. **Apply** - Score new data with saved model

### GUI vs. Command Line

| Aspect | GUI | Command Line |
|--------|-----|--------------|
| Best for | Most users, interactive analysis | Scripting, batch processing |
| Learning curve | Low | Moderate |
| Real-time feedback | Console output in GUI | R console |
| Reproducibility | Config file | Config file + scripts |

---

## Feature Comparison

### Segmentation Methods

| Method | Data Type | Sample Size | Complexity | When to Use |
|--------|-----------|-------------|------------|-------------|
| **K-Means** | Continuous | 100+ | Low | Default choice for scales |
| **Hierarchical** | Continuous | 100-15,000 | Medium | Need dendrogram, nested structures |
| **GMM** | Continuous | 200+ | Medium | Need soft assignments, elliptical clusters |
| **LCA** | Categorical | 200+ | Medium | Binary/ordinal data |

### Linkage Methods (Hierarchical Clustering)

| Method | Approach | Best For |
|--------|----------|----------|
| **ward.D2** | Minimize within-cluster variance | Default, balanced clusters |
| **complete** | Maximum inter-cluster distance | Well-separated clusters |
| **average** | Mean inter-cluster distance | Balanced approach |
| **single** | Minimum inter-cluster distance | Chained/elongated clusters |

### GMM Covariance Structures

| Model Type | Description | When to Use |
|------------|-------------|-------------|
| **(auto)** | mclust selects best by BIC | Default, recommended |
| **VVV** | Variable volume, shape, orientation | Most flexible |
| **EEE** | Equal volume, shape, orientation | When clusters are similar |
| **VVI** | Variable volume, axis-aligned | Moderate flexibility |

### Outlier Detection Methods

| Method | Approach | Best For |
|--------|----------|----------|
| **Z-Score** | Flag if |z| > threshold | Simple univariate check |
| **Mahalanobis** | Multivariate distance | Correlated variables |

### Variable Selection Methods

| Method | Approach | Best For |
|--------|----------|----------|
| **Variance-Correlation** | Remove low variance, high correlation | Most cases |
| **Factor Analysis** | Extract factors, use loadings | Many correlated variables |
| **Both** | Two-stage selection | Comprehensive reduction |

### Validation Metrics

| Metric | What It Measures | Interpretation |
|--------|-----------------|----------------|
| **Silhouette** | Cohesion + Separation | > 0.5 good, > 0.7 excellent |
| **Elbow (WCSS)** | Within-cluster variance | Look for "elbow" bend |
| **Gap Statistic** | Comparison to random | Optimal k where gap peaks |
| **Calinski-Harabasz** | Between/within variance | Higher is better |
| **Davies-Bouldin** | Average similarity ratio | Lower is better |
| **Cophenetic Corr.** | Dendrogram faithfulness | > 0.7 good (hclust only) |
| **BIC** | Model fit quality | Lower is better (GMM only) |

---

## Technical Requirements

### R Version

- **Minimum:** R 4.0+
- **Recommended:** R 4.2+ (for GUI compatibility)

### Required Packages

```r
install.packages(c("readxl", "writexl", "cluster", "openxlsx", "htmltools"))
```

### Optional Packages

```r
# Gaussian Mixture Models
install.packages("mclust")

# Faster hierarchical clustering
install.packages("fastcluster")

# SPSS file support
install.packages("haven")

# Discriminant analysis
install.packages("MASS")

# Enhanced visualizations
install.packages(c("ggplot2", "fmsb"))

# Latent Class Analysis
install.packages("poLCA")

# Classification rules
install.packages("rpart")
```

### Sample Size Guidelines

| Respondents | Recommended k | Notes |
|-------------|---------------|-------|
| 100-200 | 2-3 | Limited options |
| 200-500 | 3-5 | Comfortable range |
| 500-1000 | 4-6 | Good flexibility |
| 1000+ | Up to 8 | More granular segments |

**Rule of thumb:** At least 30-50 respondents per segment.

**Method-specific limits:**
- K-means: Up to 50,000 respondents
- Hierarchical: Up to ~15,000 respondents (distance matrix constraint)
- GMM: Up to ~20,000 respondents (computational constraint)

---

## Getting Started

### Option 1: GUI (Easiest)

```r
source("modules/segment/run_segment_gui.R")
run_segment_gui()
```

### Option 2: Command Line

```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("my_config.xlsx")
```

### Option 3: Quick Run (No Config File)

```r
source("modules/segment/R/10_utilities.R")
result <- run_segment_quick(
  data = survey_data,
  id_var = "respondent_id",
  clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
  k = 4
)
```

---

## Documentation Resources

| Document | Content |
|----------|---------|
| [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) | Statistical methods in depth |
| [04_USER_MANUAL.md](04_USER_MANUAL.md) | Complete operational guide |
| [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) | Developer documentation |
| [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) | Configuration field reference |
| [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) | Step-by-step examples |
| [08_HTML_REPORT_GUIDE.md](08_HTML_REPORT_GUIDE.md) | HTML report configuration and usage |

---

**Part of the Turas Analytics Platform**
