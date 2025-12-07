# Segment Module - Technical Documentation

**Version:** 1.0 (Turas v10.0)
**Last Updated:** December 6, 2025
**Module Status:** ✅ Production Ready
**Target Audience:** Developers, Technical Maintainers, Data Scientists

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Architecture](#2-architecture)
3. [File Structure](#3-file-structure)
4. [Core Components](#4-core-components)
5. [Clustering Algorithms](#5-clustering-algorithms)
6. [Data Processing Pipeline](#6-data-processing-pipeline)
7. [Validation & Metrics](#7-validation--metrics)
8. [Profiling System](#8-profiling-system)
9. [API Reference](#9-api-reference)
10. [Extension Points](#10-extension-points)
11. [Testing & Quality](#11-testing--quality)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Module Overview

### 1.1 Purpose

The Segment module provides K-means clustering for market segmentation analysis. It identifies natural groups within survey respondents based on their attitudes, behaviors, or characteristics, enabling targeted marketing and product development strategies.

### 1.2 Key Features

**Clustering Capabilities:**
- K-means clustering with configurable k range
- Automatic optimal k selection
- Multiple initialization methods (k-means++, random, manual)
- Reproducible results with seed setting

**Data Preparation:**
- Automatic variable scaling and normalization
- Outlier detection and removal (z-score, Mahalanobis distance)
- Missing data handling
- Variable selection support

**Validation & Quality:**
- Multiple validation metrics:
  - Silhouette coefficient
  - Elbow method (within-cluster sum of squares)
  - Gap statistic
  - Calinski-Harabasz index
- Cluster stability assessment
- Quality diagnostics

**Profiling:**
- Basic profiling (means, frequencies)
- Enhanced profiling with statistical tests
- Cluster characterization
- Variable importance for segments
- Cross-tabulation with external variables

**Scoring:**
- Score new respondents to existing segments
- Batch scoring support
- Confidence scores for assignments

### 1.3 Input/Output

**Input:**
- **Survey data** (CSV, Excel): Respondent-level data
- **Configuration** (Excel): Clustering specifications
  - Variables to use for clustering
  - k range (exploration mode) or k_fixed (final mode)
  - Outlier settings
  - Output specifications

**Output:**
1. **Segmentation Results** (Excel):
   - Cluster assignments
   - Cluster centers (centroids)
   - Validation metrics
   - Cluster profiles
   - Quality diagnostics

2. **Model Object** (RDS):
   - Trained clustering model
   - For scoring new data

3. **Visualizations** (optional):
   - Elbow plot
   - Silhouette plot
   - Cluster comparison charts

### 1.4 Performance

**Typical Performance:**
- Small dataset (500 respondents, 10 vars): 5-10 seconds
- Medium dataset (2,000 respondents, 20 vars): 15-30 seconds
- Large dataset (10,000 respondents, 30 vars): 60-120 seconds

**Scalability:**
- Handles up to 50,000 respondents
- Up to 50 clustering variables
- k range: 2-20 clusters recommended

---

## 2. Architecture

### 2.1 Design Pattern

Segment follows a **Modular Pipeline Architecture**:

```
Config → Data Prep → Outlier Removal → Clustering → Validation → Profiling → Output
```

**Key Design Principles:**
1. **Separation of Concerns** - Each file handles one aspect
2. **Two-Mode Operation** - Exploration (find optimal k) vs Final (use fixed k)
3. **Reproducibility** - Seed control for consistent results
4. **Statistical Rigor** - Multiple validation metrics
5. **Extensibility** - Easy to add new clustering methods

### 2.2 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                   SEGMENT MODULE                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ INPUT LAYER                                           │  │
│  │  ├─ Survey Data (CSV/Excel)                          │  │
│  │  └─ Configuration (Excel)                            │  │
│  └─────────────────┬────────────────────────────────────┘  │
│                    │                                        │
│  ┌─────────────────▼────────────────────────────────────┐  │
│  │ CONFIGURATION & DATA LOADING                          │  │
│  │  ├─ segment_config.R → Load & validate config        │  │
│  │  └─ segment_data_prep.R → Load & prepare data        │  │
│  └─────────────────┬────────────────────────────────────┘  │
│                    │                                        │
│  ┌─────────────────▼────────────────────────────────────┐  │
│  │ DATA PREPROCESSING                                    │  │
│  │  ├─ Variable selection                               │  │
│  │  ├─ Missing data handling                            │  │
│  │  ├─ Scaling/normalization                            │  │
│  │  └─ segment_outliers.R → Outlier detection/removal   │  │
│  └─────────────────┬────────────────────────────────────┘  │
│                    │                                        │
│  ┌─────────────────▼────────────────────────────────────┐  │
│  │ CLUSTERING ENGINE                                     │  │
│  │  ├─ segment_kmeans.R → K-means implementation        │  │
│  │  ├─ Run for k_min to k_max (exploration)            │  │
│  │  └─ Or run for k_fixed (final)                       │  │
│  └─────────────────┬────────────────────────────────────┘  │
│                    │                                        │
│  ┌─────────────────▼────────────────────────────────────┐  │
│  │ VALIDATION & SELECTION                                │  │
│  │  ├─ segment_validation.R → Quality metrics           │  │
│  │  ├─ Silhouette coefficient                           │  │
│  │  ├─ Within-cluster SS (elbow)                        │  │
│  │  ├─ Gap statistic                                     │  │
│  │  └─ Calinski-Harabasz index                          │  │
│  └─────────────────┬────────────────────────────────────┘  │
│                    │                                        │
│  ┌─────────────────▼────────────────────────────────────┐  │
│  │ PROFILING                                             │  │
│  │  ├─ segment_profile.R → Basic profiling              │  │
│  │  ├─ segment_profiling_enhanced.R → Statistical tests │  │
│  │  ├─ Cluster means/frequencies                        │  │
│  │  ├─ Variable importance                              │  │
│  │  └─ Cluster characterization                         │  │
│  └─────────────────┬────────────────────────────────────┘  │
│                    │                                        │
│  ┌─────────────────▼────────────────────────────────────┐  │
│  │ VISUALIZATION                                         │  │
│  │  ├─ segment_visualization.R → Charts                 │  │
│  │  ├─ Elbow plot                                        │  │
│  │  ├─ Silhouette plot                                   │  │
│  │  └─ Cluster comparison charts                        │  │
│  └─────────────────┬────────────────────────────────────┘  │
│                    │                                        │
│  ┌─────────────────▼────────────────────────────────────┐  │
│  │ OUTPUT GENERATION                                     │  │
│  │  ├─ segment_export.R → Excel output                  │  │
│  │  ├─ Cluster assignments                              │  │
│  │  ├─ Validation metrics                               │  │
│  │  ├─ Cluster profiles                                 │  │
│  │  └─ Model object (RDS)                               │  │
│  └─────────────────┬────────────────────────────────────┘  │
│                    │                                        │
│  ┌─────────────────▼────────────────────────────────────┐  │
│  │ SCORING (Optional)                                    │  │
│  │  └─ segment_scoring.R → Score new data               │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                             ↓
                 ┌───────────────────────┐
                 │  OUTPUT FILES         │
                 │  - Segments.xlsx      │
                 │  - Model.rds          │
                 │  - Profiles.xlsx      │
                 └───────────────────────┘
```

### 2.3 Dependencies

**R Packages:**
```r
# Core clustering
library(stats)          # Built-in kmeans()
library(cluster)        # Silhouette, gap statistic

# Data manipulation
library(data.table)     # Fast operations (optional)

# Visualization
library(ggplot2)        # Charts
library(factoextra)     # Cluster visualization

# Output
library(openxlsx)       # Excel writing
library(readxl)         # Excel reading
```

**Internal Dependencies:**
```r
# Shared utilities
modules/shared/lib/config_utils.R
modules/shared/lib/data_utils.R
modules/shared/lib/validation_utils.R
modules/shared/lib/logging_utils.R
```

---

## 3. File Structure

### 3.1 Directory Layout

```
modules/segment/
├── lib/                                # Core library
│   ├── segment_config.R               # Configuration loading (400 lines)
│   ├── segment_data_prep.R            # Data preparation (500 lines)
│   ├── segment_kmeans.R               # K-means clustering (600 lines)
│   ├── segment_outliers.R             # Outlier detection (350 lines)
│   ├── segment_validation.R           # Validation metrics (450 lines)
│   ├── segment_profile.R              # Basic profiling (400 lines)
│   ├── segment_profiling_enhanced.R   # Enhanced profiling (550 lines)
│   ├── segment_variable_selection.R   # Variable selection (300 lines)
│   ├── segment_scoring.R              # New data scoring (350 lines)
│   ├── segment_export.R               # Excel output (500 lines)
│   ├── segment_visualization.R        # Charts (400 lines)
│   └── segment_utils.R                # Utilities (250 lines)
├── run_segment.R                       # Main entry point (CLI)
├── run_segment_gui.R                   # Shiny GUI
├── test_data/                          # Test datasets
├── TECHNICAL_DOCS.md                   # This file
├── USER_MANUAL.md                      # User guide
├── QUICK_START.md                      # 5-minute intro
├── EXAMPLE_WORKFLOWS.md                # Use cases
├── MAINTENANCE_MANUAL.md               # Maintenance guide
└── README.md                           # Overview
```

**Total Lines of Code:** ~4,000

### 3.2 File Responsibilities

| File | Responsibility | Key Functions |
|------|----------------|---------------|
| **segment_config.R** | Load and validate configuration | `read_segment_config()`, `validate_segment_config()` |
| **segment_data_prep.R** | Data loading and preprocessing | `prepare_segment_data()`, `scale_segment_data()` |
| **segment_kmeans.R** | K-means clustering implementation | `run_kmeans_single()`, `run_kmeans_multiple()` |
| **segment_outliers.R** | Outlier detection and removal | `detect_outliers_zscore()`, `detect_outliers_mahal()` |
| **segment_validation.R** | Validation metrics calculation | `calculate_silhouette()`, `calculate_gap_stat()` |
| **segment_profile.R** | Basic cluster profiling | `profile_clusters()`, `cluster_means()` |
| **segment_profiling_enhanced.R** | Statistical profiling | `enhanced_profile()`, `test_differences()` |
| **segment_variable_selection.R** | Variable selection helpers | `select_variables()`, `importance_ranking()` |
| **segment_scoring.R** | Score new data | `score_new_data()`, `assign_to_clusters()` |
| **segment_export.R** | Excel output generation | `write_segment_results()`, `format_output()` |
| **segment_visualization.R** | Create charts | `plot_elbow()`, `plot_silhouette()` |
| **segment_utils.R** | Utility functions | `set_segmentation_seed()`, `print_toolkit_header()` |

---

## 4. Core Components

### 4.1 Configuration Loader (segment_config.R)

**Purpose:** Load and validate segmentation configuration

**Main Function:** `read_segment_config()`

**Configuration Structure:**
```r
# Excel file: segment_config.xlsx
# Sheet: Config

# Required fields:
- data_file              # Path to survey data
- id_variable            # Respondent ID column
- clustering_variables   # Comma-separated list of variables
- k_min                  # Minimum clusters (exploration)
- k_max                  # Maximum clusters (exploration)
- k_fixed                # Fixed k (final mode) - optional

# Optional fields:
- weight_variable        # Weight column (if weighted)
- outlier_method         # "zscore", "mahalanobis", or "none"
- outlier_threshold      # Threshold for outlier detection (default: 3.0)
- scaling_method         # "standard", "minmax", or "none"
- seed                   # Random seed for reproducibility
- nstart                 # Number of random starts (default: 25)
- max_iter               # Max iterations (default: 100)
- output_folder          # Output directory
```

**Validation:**
```r
validate_segment_config <- function(config) {
  # 1. Check required fields
  required <- c("data_file", "id_variable", "clustering_variables")
  missing <- setdiff(required, names(config))
  if (length(missing) > 0) {
    stop("Missing required config fields: ", paste(missing, collapse = ", "))
  }

  # 2. Determine mode
  if (!is.null(config$k_fixed) && !is.na(config$k_fixed)) {
    config$mode <- "final"
  } else {
    config$mode <- "exploration"
    # Check k_min, k_max
    if (is.null(config$k_min) || is.null(config$k_max)) {
      stop("For exploration mode, specify k_min and k_max")
    }
    if (config$k_min < 2 || config$k_max > 20) {
      stop("k_min must be >= 2, k_max must be <= 20")
    }
  }

  # 3. Parse clustering variables
  config$clustering_vars <- strsplit(config$clustering_variables, ",")[[1]]
  config$clustering_vars <- trimws(config$clustering_vars)

  # 4. Set defaults
  config$outlier_method <- config$outlier_method %||% "zscore"
  config$outlier_threshold <- config$outlier_threshold %||% 3.0
  config$scaling_method <- config$scaling_method %||% "standard"
  config$nstart <- config$nstart %||% 25
  config$max_iter <- config$max_iter %||% 100

  return(config)
}
```

---

### 4.2 Data Preparation (segment_data_prep.R)

**Purpose:** Load and preprocess data for clustering

**Main Function:** `prepare_segment_data()`

**Processing Steps:**

```r
prepare_segment_data <- function(config) {

  # 1. Load data
  data <- load_survey_data(config$data_file)

  # 2. Validate required columns
  required_cols <- c(config$id_variable, config$clustering_vars)
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing columns in data: ", paste(missing_cols, collapse = ", "))
  }

  # 3. Extract clustering variables
  cluster_data <- data[, config$clustering_vars, drop = FALSE]

  # 4. Handle missing data
  if (any(is.na(cluster_data))) {
    cat("Warning: Missing data detected\n")

    # Count missing by variable
    missing_counts <- colSums(is.na(cluster_data))
    cat("Missing counts:\n")
    print(missing_counts)

    # Remove rows with any missing (complete case analysis)
    complete_rows <- complete.cases(cluster_data)
    cat(sprintf("Removing %d rows with missing data\n",
                sum(!complete_rows)))

    data <- data[complete_rows, ]
    cluster_data <- cluster_data[complete_rows, ]
  }

  # 5. Convert to numeric (if needed)
  for (col in names(cluster_data)) {
    if (!is.numeric(cluster_data[[col]])) {
      cluster_data[[col]] <- as.numeric(cluster_data[[col]])
    }
  }

  # 6. Scale data
  if (config$scaling_method != "none") {
    cluster_data_scaled <- scale_segment_data(
      cluster_data,
      method = config$scaling_method
    )
  } else {
    cluster_data_scaled <- cluster_data
  }

  # 7. Return
  return(list(
    full_data = data,                    # Full dataset
    cluster_data = cluster_data,         # Raw clustering variables
    cluster_data_scaled = cluster_data_scaled, # Scaled data for clustering
    n_rows = nrow(data),
    n_vars = ncol(cluster_data),
    variable_names = names(cluster_data)
  ))
}
```

**Scaling Methods:**

```r
scale_segment_data <- function(data, method = "standard") {

  if (method == "standard") {
    # Z-score standardization: (x - mean) / sd
    # Mean = 0, SD = 1
    scaled <- scale(data, center = TRUE, scale = TRUE)

  } else if (method == "minmax") {
    # Min-max normalization: (x - min) / (max - min)
    # Range = [0, 1]
    scaled <- apply(data, 2, function(x) {
      (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
    })

  } else {
    stop("Unknown scaling method: ", method)
  }

  return(scaled)
}
```

---

### 4.3 Outlier Detection (segment_outliers.R)

**Purpose:** Detect and remove outliers before clustering

**Why Remove Outliers:**
- K-means is sensitive to outliers (uses Euclidean distance)
- Outliers can distort cluster centers
- Can create artificial single-member clusters

**Methods:**

**1. Z-Score Method:**
```r
detect_outliers_zscore <- function(data, threshold = 3.0) {
  # Calculate z-scores for each variable
  z_scores <- scale(data, center = TRUE, scale = TRUE)

  # Flag if any variable has |z| > threshold
  outliers <- apply(abs(z_scores), 1, max) > threshold

  return(outliers)
}
```

**2. Mahalanobis Distance:**
```r
detect_outliers_mahalanobis <- function(data, threshold = NULL) {
  # Calculate Mahalanobis distance
  # Accounts for correlations between variables

  center <- colMeans(data)
  cov_matrix <- cov(data)

  # Mahalanobis distance for each row
  mahal_dist <- mahalanobis(data, center = center, cov = cov_matrix)

  # Default threshold: Chi-square critical value
  if (is.null(threshold)) {
    # 99.9% quantile of chi-square distribution
    threshold <- qchisq(0.999, df = ncol(data))
  }

  outliers <- mahal_dist > threshold

  return(list(
    outliers = outliers,
    distances = mahal_dist,
    threshold = threshold
  ))
}
```

**Outlier Removal:**
```r
remove_outliers <- function(data_list, config) {

  if (config$outlier_method == "none") {
    cat("Outlier detection: DISABLED\n")
    return(data_list)
  }

  cat(sprintf("Outlier detection: %s (threshold = %.2f)\n",
              toupper(config$outlier_method),
              config$outlier_threshold))

  # Detect outliers
  if (config$outlier_method == "zscore") {
    outliers <- detect_outliers_zscore(
      data_list$cluster_data_scaled,
      threshold = config$outlier_threshold
    )
  } else if (config$outlier_method == "mahalanobis") {
    outlier_result <- detect_outliers_mahalanobis(
      data_list$cluster_data_scaled,
      threshold = config$outlier_threshold
    )
    outliers <- outlier_result$outliers
  }

  # Remove outliers
  n_outliers <- sum(outliers)
  pct_outliers <- 100 * n_outliers / length(outliers)

  cat(sprintf("Outliers detected: %d (%.1f%%)\n", n_outliers, pct_outliers))

  if (n_outliers > 0) {
    data_list$full_data <- data_list$full_data[!outliers, ]
    data_list$cluster_data <- data_list$cluster_data[!outliers, ]
    data_list$cluster_data_scaled <- data_list$cluster_data_scaled[!outliers, ]
    data_list$n_rows <- sum(!outliers)
    data_list$outliers_removed <- outliers
  }

  return(data_list)
}
```

---

### 4.4 K-Means Clustering (segment_kmeans.R)

**Purpose:** Run K-means clustering

**Algorithm:** Uses R's built-in `stats::kmeans()` with enhancements

**Exploration Mode (Multiple k):**
```r
run_kmeans_multiple <- function(data_scaled, k_min, k_max, config) {

  results <- list()

  for (k in k_min:k_max) {
    cat(sprintf("\nRunning k-means for k = %d...\n", k))

    # Run k-means with multiple random starts
    km <- stats::kmeans(
      x = data_scaled,
      centers = k,
      nstart = config$nstart,      # Multiple random initializations
      iter.max = config$max_iter,  # Max iterations
      algorithm = "Hartigan-Wong"  # Standard algorithm
    )

    # Store result
    results[[paste0("k", k)]] <- list(
      k = k,
      model = km,
      centers = km$centers,
      cluster = km$cluster,
      size = km$size,
      withinss = km$withinss,
      tot.withinss = km$tot.withinss,
      betweenss = km$betweenss,
      totss = km$totss
    )

    cat(sprintf("  Total within-cluster SS: %.2f\n", km$tot.withinss))
    cat(sprintf("  Cluster sizes: %s\n",
                paste(km$size, collapse = ", ")))
  }

  return(results)
}
```

**Final Mode (Fixed k):**
```r
run_kmeans_single <- function(data_scaled, k, config) {

  cat(sprintf("\nRunning k-means for k = %d (final)...\n", k))

  # Run k-means
  km <- stats::kmeans(
    x = data_scaled,
    centers = k,
    nstart = config$nstart,
    iter.max = config$max_iter,
    algorithm = "Hartigan-Wong"
  )

  # Check convergence
  if (km$ifault != 0) {
    warning("K-means did not converge. Consider increasing max_iter.")
  }

  return(list(
    k = k,
    model = km,
    centers = km$centers,
    cluster = km$cluster,
    size = km$size,
    withinss = km$withinss,
    tot.withinss = km$tot.withinss,
    betweenss = km$betweenss,
    totss = km$totss,
    converged = (km$ifault == 0)
  ))
}
```

**Key K-Means Parameters:**

- `centers`: Number of clusters (k)
- `nstart`: Number of random initializations (default: 25)
  - Higher = better solution but slower
  - K-means can get stuck in local optima
- `iter.max`: Maximum iterations (default: 100)
- `algorithm`: "Hartigan-Wong" (standard), "Lloyd", "Forgy", "MacQueen"

---

## 5. Clustering Algorithms

### 5.1 K-Means Algorithm

**Overview:**
- Partitioning method that assigns each point to nearest cluster center
- Iteratively updates centers until convergence
- Minimizes within-cluster variance

**Algorithm Steps:**

```
1. Initialize k cluster centers (randomly or k-means++)
2. REPEAT:
   a. Assignment step: Assign each point to nearest center
   b. Update step: Recalculate centers as mean of assigned points
3. UNTIL: Centers don't change (convergence) OR max iterations reached
```

**Mathematical Formulation:**

Minimize objective function:
```
J = Σ(i=1 to k) Σ(x in Cluster_i) ||x - μ_i||²

Where:
- k = number of clusters
- x = data point
- μ_i = center of cluster i
- ||x - μ_i|| = Euclidean distance
```

**Strengths:**
- ✅ Fast and scalable
- ✅ Works well with spherical clusters
- ✅ Easy to interpret
- ✅ Deterministic given initial centers

**Weaknesses:**
- ❌ Requires specifying k in advance
- ❌ Sensitive to outliers
- ❌ Assumes clusters are spherical and similar size
- ❌ Can get stuck in local optima

**Implementation Details:**

```r
# Hartigan-Wong Algorithm (default)
# - More efficient than Lloyd's algorithm
# - Better convergence properties
# - Standard in R's stats::kmeans()

# Key optimizations:
# 1. Multiple random starts (nstart = 25)
# 2. K-means++ initialization (optional)
# 3. Early stopping if centers stable
```

### 5.2 Initialization Methods

**Random Initialization:**
```r
# Randomly select k points as initial centers
# Simple but can lead to poor solutions
```

**K-Means++ (Better):**
```r
# Smart initialization to spread out initial centers
# Algorithm:
# 1. Choose first center randomly
# 2. For each subsequent center:
#    - Choose point with probability ∝ D²(x)
#    - Where D(x) = distance to nearest existing center
# 3. Repeat until k centers chosen
```

**Manual Centers:**
```r
# Specify initial centers explicitly
# Useful for guided segmentation
```

---

## 6. Data Processing Pipeline

### 6.1 Complete Pipeline Flow

```
RAW DATA (survey_data.csv)
        ↓
┌───────────────────────────────────┐
│ 1. LOAD & VALIDATE                │
│    - Read data file               │
│    - Check required columns       │
│    - Validate data types          │
└─────────────┬─────────────────────┘
              ↓
┌─────────────▼─────────────────────┐
│ 2. EXTRACT CLUSTERING VARIABLES   │
│    - Select specified variables   │
│    - Check for numeric data       │
└─────────────┬─────────────────────┘
              ↓
┌─────────────▼─────────────────────┐
│ 3. HANDLE MISSING DATA            │
│    - Identify missing values      │
│    - Remove incomplete cases      │
│    - (Alternative: imputation)    │
└─────────────┬─────────────────────┘
              ↓
┌─────────────▼─────────────────────┐
│ 4. SCALE/NORMALIZE DATA           │
│    - Z-score standardization OR   │
│    - Min-max normalization        │
│    - Ensures equal weighting      │
└─────────────┬─────────────────────┘
              ↓
┌─────────────▼─────────────────────┐
│ 5. DETECT & REMOVE OUTLIERS       │
│    - Z-score method OR            │
│    - Mahalanobis distance         │
│    - Remove flagged outliers      │
└─────────────┬─────────────────────┘
              ↓
EXPLORATION MODE          FINAL MODE
      ↓                        ↓
┌─────▼──────────┐    ┌───────▼──────────┐
│ Run k-means    │    │ Run k-means      │
│ for k=2,3,...,N│    │ for k=K_FIXED    │
└─────┬──────────┘    └───────┬──────────┘
      ↓                        ↓
┌─────▼──────────────────────┬▼──────────┐
│ 6. CALCULATE VALIDATION    │           │
│    METRICS FOR EACH k      │           │
│    - Silhouette            │           │
│    - Within-cluster SS     │           │
│    - Gap statistic         │           │
│    - Calinski-Harabasz     │           │
└─────┬──────────────────────┴───────────┘
      ↓
┌─────▼──────────────────────────────────┐
│ 7. SELECT OPTIMAL k                    │
│    (Exploration mode only)             │
│    - Review validation metrics         │
│    - Consider business context         │
│    - User selects k_fixed for final    │
└─────┬──────────────────────────────────┘
      ↓
┌─────▼──────────────────────────────────┐
│ 8. PROFILE CLUSTERS                    │
│    - Calculate cluster means           │
│    - Frequency distributions           │
│    - Statistical tests                 │
│    - Variable importance               │
└─────┬──────────────────────────────────┘
      ↓
┌─────▼──────────────────────────────────┐
│ 9. GENERATE OUTPUTS                    │
│    - Excel: Assignments, profiles      │
│    - RDS: Model object                 │
│    - Charts: Elbow, silhouette         │
└────────────────────────────────────────┘
```

### 6.2 Two-Mode Operation

**Exploration Mode:**
- User doesn't specify k_fixed
- Module runs k-means for k = k_min to k_max
- Calculates validation metrics for each k
- User reviews metrics and selects optimal k
- Rerun in final mode with k_fixed

**Final Mode:**
- User specifies k_fixed in config
- Module runs k-means once with that k
- Generates full profiles and outputs
- Saves model for scoring new data

---

## 7. Validation & Metrics

### 7.1 Silhouette Coefficient

**Purpose:** Measure how well each point fits in its assigned cluster

**Formula:**
```
For each point i:
  a(i) = average distance to points in same cluster
  b(i) = average distance to points in nearest other cluster

  silhouette(i) = (b(i) - a(i)) / max(a(i), b(i))
```

**Range:** -1 to +1
- **+1**: Perfect assignment (far from other clusters)
- **0**: On border between clusters
- **-1**: Likely in wrong cluster

**Average Silhouette:**
```r
avg_silhouette = mean(silhouette values for all points)
```

**Interpretation:**
- 0.71-1.00: Strong structure
- 0.51-0.70: Reasonable structure
- 0.26-0.50: Weak structure
- < 0.25: No substantial structure

**Implementation:**
```r
calculate_silhouette <- function(cluster_result, data_scaled) {

  library(cluster)

  # Calculate silhouette
  sil <- silhouette(
    x = cluster_result$cluster,  # Cluster assignments
    dist = dist(data_scaled)      # Distance matrix
  )

  # Extract metrics
  avg_sil <- mean(sil[, "sil_width"])

  # Per-cluster averages
  cluster_sil <- aggregate(
    sil[, "sil_width"],
    by = list(cluster = sil[, "cluster"]),
    FUN = mean
  )

  return(list(
    average = avg_sil,
    per_cluster = cluster_sil,
    individual = sil[, "sil_width"]
  ))
}
```

---

### 7.2 Elbow Method (Within-Cluster Sum of Squares)

**Purpose:** Identify optimal k by finding "elbow" in WCSS curve

**Metric:** Within-cluster sum of squares (WCSS)
```
WCSS = Σ(i=1 to k) Σ(x in Cluster_i) ||x - μ_i||²
```

**How to Use:**
1. Plot WCSS vs k
2. Look for "elbow" where adding clusters gives diminishing returns
3. Elbow point suggests optimal k

**Implementation:**
```r
calculate_elbow_metric <- function(clustering_results) {

  # Extract WCSS for each k
  wcss <- sapply(clustering_results, function(result) {
    result$tot.withinss
  })

  k_values <- sapply(clustering_results, function(result) {
    result$k
  })

  # Calculate "elbow" using second derivative
  if (length(k_values) >= 3) {
    # Second differences (curvature)
    diffs <- diff(wcss, differences = 2)

    # Elbow = maximum curvature
    elbow_idx <- which.max(abs(diffs)) + 1
    optimal_k <- k_values[elbow_idx]
  } else {
    optimal_k <- NA
  }

  return(list(
    k = k_values,
    wcss = wcss,
    optimal_k = optimal_k
  ))
}
```

---

### 7.3 Gap Statistic

**Purpose:** Compare clustering structure to random data

**Idea:** Good clustering should have lower WCSS than random data

**Formula:**
```
Gap(k) = E[log(WCSS_random)] - log(WCSS_observed)
```

**How to Use:**
- Higher gap = better clustering
- Optimal k = smallest k where: Gap(k) ≥ Gap(k+1) - SE(k+1)

**Implementation:**
```r
calculate_gap_statistic <- function(data_scaled, clustering_results, B = 50) {

  library(cluster)

  k_values <- sapply(clustering_results, function(r) r$k)

  # Calculate gap statistic
  gap_result <- clusGap(
    x = data_scaled,
    FUNcluster = kmeans,
    K.max = max(k_values),
    B = B,              # Number of bootstrap samples
    verbose = FALSE
  )

  # Find optimal k
  optimal_k <- maxSE(
    gap_result$Tab[, "gap"],
    gap_result$Tab[, "SE.sim"],
    method = "firstSEmax"
  )

  return(list(
    gap_values = gap_result$Tab[, "gap"],
    se_values = gap_result$Tab[, "SE.sim"],
    optimal_k = optimal_k,
    full_result = gap_result
  ))
}
```

---

### 7.4 Calinski-Harabasz Index

**Purpose:** Ratio of between-cluster to within-cluster variance

**Formula:**
```
CH(k) = (SSB / (k-1)) / (SSW / (n-k))

Where:
- SSB = Between-cluster sum of squares
- SSW = Within-cluster sum of squares
- k = number of clusters
- n = number of points
```

**Interpretation:**
- Higher values = better clustering
- Optimal k = maximum CH value

**Implementation:**
```r
calculate_calinski_harabasz <- function(cluster_result, data_scaled) {

  k <- cluster_result$k
  n <- nrow(data_scaled)

  # Between-cluster SS
  ssb <- cluster_result$betweenss

  # Within-cluster SS
  ssw <- cluster_result$tot.withinss

  # Calinski-Harabasz index
  ch <- (ssb / (k - 1)) / (ssw / (n - k))

  return(ch)
}
```

---

## 8. Profiling System

### 8.1 Basic Profiling (segment_profile.R)

**Purpose:** Describe clusters using means and frequencies

**Cluster Means:**
```r
profile_clusters <- function(cluster_result, data, data_list) {

  # Get cluster assignments
  clusters <- cluster_result$cluster

  # Calculate means for clustering variables
  cluster_means <- aggregate(
    data_list$cluster_data,
    by = list(Cluster = clusters),
    FUN = mean
  )

  # Calculate cluster sizes
  cluster_sizes <- table(clusters)

  # Combine
  profile <- cbind(
    cluster_means,
    N = as.vector(cluster_sizes),
    Pct = 100 * as.vector(cluster_sizes) / length(clusters)
  )

  return(profile)
}
```

**Example Output:**
```
Cluster | Satisfaction | Quality | Value | Price_Sensitive | N   | Pct
--------|-------------|---------|-------|-----------------|-----|-----
1       | 4.2         | 4.1     | 3.8   | 2.1             | 234 | 28%
2       | 3.1         | 3.2     | 3.0   | 3.9             | 312 | 37%
3       | 4.8         | 4.7     | 4.6   | 1.8             | 294 | 35%
```

---

### 8.2 Enhanced Profiling (segment_profiling_enhanced.R)

**Purpose:** Add statistical tests and variable importance

**Statistical Tests:**
```r
enhanced_profile <- function(cluster_result, data, data_list, config) {

  clusters <- cluster_result$cluster

  # Basic profile
  basic_profile <- profile_clusters(cluster_result, data, data_list)

  # Add statistical tests
  # Test if each variable differs significantly across clusters

  test_results <- list()

  for (var in names(data_list$cluster_data)) {

    # One-way ANOVA
    # H0: Means are equal across all clusters
    # H1: At least one mean is different

    formula <- as.formula(paste(var, "~ Cluster"))
    anova_data <- data.frame(
      Cluster = as.factor(clusters),
      data_list$cluster_data
    )

    anova_result <- aov(formula, data = anova_data)
    anova_summary <- summary(anova_result)

    # Extract p-value
    p_value <- anova_summary[[1]][["Pr(>F)"]][1]

    # Effect size (eta-squared)
    ssb <- anova_summary[[1]][["Sum Sq"]][1]
    sst <- sum(anova_summary[[1]][["Sum Sq"]])
    eta_sq <- ssb / sst

    test_results[[var]] <- list(
      p_value = p_value,
      significant = p_value < 0.05,
      eta_squared = eta_sq
    )
  }

  # Variable importance ranking
  # Variables with larger eta-squared are more important for segmentation
  importance <- sapply(test_results, function(x) x$eta_squared)
  importance <- sort(importance, decreasing = TRUE)

  return(list(
    basic_profile = basic_profile,
    statistical_tests = test_results,
    variable_importance = importance
  ))
}
```

**Variable Importance:**
- Eta-squared (η²): Proportion of variance explained by cluster membership
- Range: 0 to 1
- Interpretation:
  - 0.01: Small effect
  - 0.06: Medium effect
  - 0.14: Large effect

---

### 8.3 Cluster Characterization

**Purpose:** Generate descriptive names/labels for clusters

**Approach:**
1. Identify variables with highest importance
2. For each cluster, find distinctive characteristics
3. Generate descriptive label

**Example:**
```r
characterize_clusters <- function(enhanced_profile) {

  # Get top 3 most important variables
  top_vars <- names(enhanced_profile$variable_importance)[1:3]

  # For each cluster
  cluster_labels <- character()

  for (cluster_id in unique(clusters)) {

    characteristics <- character()

    for (var in top_vars) {
      # Get cluster mean for this variable
      cluster_mean <- basic_profile[cluster_id, var]

      # Get overall mean
      overall_mean <- mean(data_list$cluster_data[[var]])

      # If cluster mean is notably higher/lower
      if (cluster_mean > overall_mean + 0.5) {
        characteristics <- c(characteristics, paste("High", var))
      } else if (cluster_mean < overall_mean - 0.5) {
        characteristics <- c(characteristics, paste("Low", var))
      }
    }

    # Create label
    if (length(characteristics) > 0) {
      label <- paste(characteristics, collapse = ", ")
    } else {
      label <- paste("Cluster", cluster_id)
    }

    cluster_labels[cluster_id] <- label
  }

  return(cluster_labels)
}
```

**Example Output:**
```
Cluster 1: High Satisfaction, High Quality
Cluster 2: Price Sensitive, Low Value
Cluster 3: Premium Seekers (High across all dimensions)
```

---

## 9. API Reference

### 9.1 Main Entry Point

```r
turas_segment_from_config(
  config_file,      # Character: Path to Excel config
  verbose = TRUE    # Logical: Print progress messages
) -> list
```

**Returns:**
```r
list(
  mode = "exploration" or "final",
  config = list(...),                  # Configuration used
  data_summary = list(                 # Data summary
    n_rows_original = 1000,
    n_rows_after_outliers = 950,
    n_vars = 10,
    outliers_removed = 50
  ),
  clustering_results = list(...),      # K-means results
  validation_metrics = list(           # Quality metrics
    silhouette = list(...),
    elbow = list(...),
    gap_statistic = list(...),
    calinski_harabasz = numeric(...)
  ),
  profiles = list(                     # Cluster profiles
    basic = data.frame(...),
    enhanced = list(...),
    characterization = character(...)
  ),
  output_files = list(                 # Output paths
    excel = "path/to/segments.xlsx",
    model = "path/to/model.rds"
  )
)
```

---

### 9.2 Component Functions

**Configuration:**
```r
read_segment_config(config_file) -> list
validate_segment_config(config_raw) -> list
```

**Data Preparation:**
```r
prepare_segment_data(config) -> list
scale_segment_data(data, method = "standard") -> matrix
```

**Outlier Detection:**
```r
detect_outliers_zscore(data, threshold = 3.0) -> logical vector
detect_outliers_mahalanobis(data, threshold = NULL) -> list
remove_outliers(data_list, config) -> list
```

**Clustering:**
```r
run_kmeans_single(data_scaled, k, config) -> list
run_kmeans_multiple(data_scaled, k_min, k_max, config) -> list
```

**Validation:**
```r
calculate_silhouette(cluster_result, data_scaled) -> list
calculate_elbow_metric(clustering_results) -> list
calculate_gap_statistic(data_scaled, clustering_results, B = 50) -> list
calculate_calinski_harabasz(cluster_result, data_scaled) -> numeric
```

**Profiling:**
```r
profile_clusters(cluster_result, data, data_list) -> data.frame
enhanced_profile(cluster_result, data, data_list, config) -> list
characterize_clusters(enhanced_profile) -> character vector
```

**Scoring:**
```r
score_new_data(new_data, model, config) -> list
```

**Output:**
```r
write_segment_results(results, output_path) -> NULL
```

---

## 10. Extension Points

### 10.1 Adding New Clustering Methods

**Example: Hierarchical Clustering**

**Step 1: Create new file**
```r
# modules/segment/lib/segment_hierarchical.R

run_hierarchical <- function(data_scaled, k, config) {

  # Calculate distance matrix
  dist_matrix <- dist(data_scaled, method = "euclidean")

  # Hierarchical clustering
  hc <- hclust(dist_matrix, method = "ward.D2")

  # Cut tree to get k clusters
  clusters <- cutree(hc, k = k)

  # Calculate cluster centers
  centers <- aggregate(
    data_scaled,
    by = list(Cluster = clusters),
    FUN = mean
  )[, -1]

  return(list(
    method = "hierarchical",
    k = k,
    cluster = clusters,
    centers = centers,
    dendrogram = hc
  ))
}
```

**Step 2: Add to configuration**
```r
# In config Excel:
# clustering_method | hierarchical
```

**Step 3: Update main**
```r
# In run_segment.R:
if (config$clustering_method == "hierarchical") {
  result <- run_hierarchical(data_scaled, k, config)
} else {
  result <- run_kmeans_single(data_scaled, k, config)
}
```

---

### 10.2 Adding New Validation Metrics

**Example: Davies-Bouldin Index**

```r
# modules/segment/lib/segment_validation.R

calculate_davies_bouldin <- function(cluster_result, data_scaled) {
  # Davies-Bouldin Index
  # Lower values indicate better clustering

  k <- cluster_result$k
  clusters <- cluster_result$cluster
  centers <- cluster_result$centers

  # Calculate within-cluster scatter for each cluster
  scatter <- numeric(k)
  for (i in 1:k) {
    cluster_points <- data_scaled[clusters == i, , drop = FALSE]
    scatter[i] <- mean(dist(rbind(centers[i, ], cluster_points)))
  }

  # Calculate between-cluster distances
  db_values <- numeric(k)
  for (i in 1:k) {
    max_ratio <- 0
    for (j in 1:k) {
      if (i != j) {
        # Distance between centers
        d_ij <- dist(rbind(centers[i, ], centers[j, ]))

        # Ratio of within to between
        ratio <- (scatter[i] + scatter[j]) / d_ij

        max_ratio <- max(max_ratio, ratio)
      }
    }
    db_values[i] <- max_ratio
  }

  # Davies-Bouldin Index = average of max ratios
  db_index <- mean(db_values)

  return(db_index)
}
```

---

### 10.3 Custom Profiling Functions

**Example: Add profiling against external variables**

```r
# Profile clusters on variables NOT used for clustering

profile_external_variables <- function(cluster_result, data, external_vars) {

  clusters <- cluster_result$cluster

  # Calculate means for external variables
  external_profile <- aggregate(
    data[, external_vars, drop = FALSE],
    by = list(Cluster = clusters),
    FUN = mean
  )

  # Statistical tests
  test_results <- list()
  for (var in external_vars) {
    formula <- as.formula(paste(var, "~ Cluster"))
    test_data <- data.frame(
      Cluster = as.factor(clusters),
      data[, var, drop = FALSE]
    )
    anova_result <- aov(formula, data = test_data)
    test_results[[var]] <- summary(anova_result)
  }

  return(list(
    profile = external_profile,
    tests = test_results
  ))
}
```

---

## 11. Testing & Quality

### 11.1 Test Strategy

**Unit Tests:**
```r
test_that("outlier detection works correctly", {
  # Create test data with known outliers
  data <- matrix(rnorm(100), ncol = 5)
  data[1, ] <- c(10, 10, 10, 10, 10)  # Outlier

  outliers <- detect_outliers_zscore(data, threshold = 3.0)

  expect_true(outliers[1])
  expect_false(any(outliers[-1]))
})

test_that("k-means produces expected number of clusters", {
  data <- matrix(rnorm(100), ncol = 5)
  result <- run_kmeans_single(data, k = 3, config = list(nstart = 25, max_iter = 100))

  expect_equal(result$k, 3)
  expect_equal(length(unique(result$cluster)), 3)
})
```

**Integration Tests:**
```r
test_that("full segmentation pipeline works", {
  result <- turas_segment_from_config(
    "test_data/segment_config.xlsx",
    verbose = FALSE
  )

  expect_true(file.exists(result$output_files$excel))
  expect_true("cluster" %in% names(result$clustering_results))
})
```

---

### 11.2 Validation Checklist

**Before Running Segmentation:**
- [ ] Clustering variables are numeric
- [ ] No missing data (or handled appropriately)
- [ ] Variables are scaled/normalized
- [ ] Outliers are detected/removed
- [ ] k range is reasonable (2-20)
- [ ] Seed is set for reproducibility

**After Running Segmentation:**
- [ ] All validation metrics calculated
- [ ] Silhouette coefficient > 0.25
- [ ] Cluster sizes are reasonable (no tiny clusters)
- [ ] Profiles show meaningful differences
- [ ] Variable importance rankings make sense
- [ ] Results are reproducible

---

## 12. Troubleshooting

### Issue: "Empty clusters created"

**Cause:** k too high for data structure, poor initialization

**Solution:**
```r
# Reduce k
# Increase nstart for better initialization
# Check for outliers
# Ensure data is scaled
```

---

### Issue: "Clustering not reproducible"

**Cause:** Seed not set properly

**Solution:**
```r
# Ensure seed is specified in config
# Check that seed is actually being used before kmeans()
```

---

### Issue: "Poor silhouette scores"

**Cause:** Data doesn't have natural cluster structure, k inappropriate

**Solution:**
```r
# Try different k values
# Review data - may not be suitable for clustering
# Consider different variables
# Try hierarchical clustering instead
```

---

### Issue: "All clusters similar in profiles"

**Cause:** Variables used don't differentiate segments well

**Solution:**
```r
# Review variable selection
# Check variable importance - are any actually differentiating?
# Consider adding more discriminating variables
# May indicate data doesn't support segmentation
```

---

**Document Version:** 1.0
**Last Updated:** December 6, 2025
**Maintained By:** Turas Development Team
**Next Review:** March 6, 2026

---

**End of Segment Module Technical Documentation**

---

## Maintenance Manual

# Turas Segmentation Module - Maintenance Manual

**Technical Documentation for Developers and Maintainers**

Version 1.0 | Last Updated: 2024

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Module Structure](#module-structure)
3. [Core Components](#core-components)
4. [Data Flow](#data-flow)
5. [Function Reference](#function-reference)
6. [Extension Points](#extension-points)
7. [Testing](#testing)
8. [Debugging](#debugging)
9. [Performance Optimization](#performance-optimization)
10. [Future Enhancements](#future-enhancements)

---

## 1. Architecture Overview

### Design Philosophy

The segmentation module follows these principles:

- **Modularity**: Each file handles one functional area
- **Progressive enhancement**: Optional features don't break core functionality
- **Fail-safe defaults**: Sensible defaults for all parameters
- **Validation-first**: Extensive input validation before processing
- **User feedback**: Console messages at every major step

### Technology Stack

- **Language**: R 4.0+
- **Core algorithm**: k-means clustering (stats package)
- **Data I/O**: readxl, writexl
- **Clustering metrics**: cluster package
- **Optional**: MASS (discriminant analysis), fmsb (spider plots), psych (factor analysis)

### Integration Points

- **Turas Launcher**: `launch_turas.R` → `run_segment_gui.R`
- **Shared utilities**: `modules/shared/lib/` (validation, config, data utils)
- **Output**: Excel reports, PNG visualizations, RDS models

---

## 2. Module Structure

```
modules/segment/
├── run_segment.R                # Main orchestrator
├── run_segment_gui.R            # Shiny GUI interface
├── lib/                         # Core library functions
│   ├── segment_config.R         # Configuration loading/validation
│   ├── segment_data_prep.R      # Data loading and preparation
│   ├── segment_clustering.R     # K-means clustering engine
│   ├── segment_profiling.R      # Segment profile generation
│   ├── segment_export.R         # Excel export functions
│   ├── segment_outliers.R       # Outlier detection
│   ├── segment_variable_selection.R  # Variable selection
│   ├── segment_scoring.R        # Model scoring (NEW)
│   ├── segment_visualization.R  # Charts and plots (NEW)
│   ├── segment_validation.R     # Segment quality metrics (NEW)
│   ├── segment_profiling_enhanced.R  # Stats tests (NEW)
│   └── segment_utils.R          # Utilities (NEW)
├── test_data/                   # Test datasets and configs
│   ├── test_survey_data.csv
│   ├── test_segment_config.xlsx
│   ├── test_varsel_config.xlsx
│   └── test_question_labels.xlsx
├── docs/                        # Documentation
│   ├── QUICK_START.md
│   ├── USER_MANUAL.md
│   └── MAINTENANCE_MANUAL.md (this file)
└── turas_segmentation_module_specs.md  # Original specs
```

---

## 3. Core Components

### 3.1 Configuration System (`segment_config.R`)

**Purpose**: Load, validate, and manage all segmentation parameters

**Key Functions**:

```r
read_segment_config(config_file)
# Loads Excel config file into named list
# Uses shared utilities from modules/shared/lib/config_utils.R

validate_segment_config(config)
# Validates all parameters, applies defaults
# Returns enriched config with mode detection

load_question_labels(labels_file)
# Loads question label mappings (NEW)
# Returns named vector: names=variables, values=labels

format_variable_label(variable, question_labels)
# Formats variable display with labels (NEW)
# Returns "q1: Overall satisfaction" or "q1" if no label
```

**Configuration Flow**:
1. Read Excel → named list
2. Validate required parameters
3. Apply defaults for optional parameters
4. Validate relationships (e.g., k_min < k_max)
5. Detect mode (exploration vs. final)
6. Load question labels if provided
7. Return validated config object

**Extension Point**: Add new parameters by:
1. Adding to validation function
2. Adding to config template generator
3. Documenting in USER_MANUAL.md

### 3.2 Data Preparation (`segment_data_prep.R`)

**Purpose**: Load, clean, and prepare data for clustering

**Key Functions**:

```r
prepare_segmentation_data(config)
# Master preparation function
# Returns data_list with all prepared components

perform_variable_selection(data_list, config)
# Automatic variable selection (20+ vars → 10)
# Updates config$clustering_vars with selected variables

handle_outliers(data_list, config)
# Detects and handles outliers before clustering
# Returns data with outlier flags/removals
```

**Data Preparation Pipeline**:
```
Raw Data
  ↓
Load & Validate
  ↓
Variable Selection (if enabled)
  ↓
Outlier Detection (if enabled)
  ↓
Missing Data Handling
  ↓
Standardization
  ↓
Ready for Clustering
```

**Data List Structure**:
```r
data_list <- list(
  data = <full data frame>,
  clustering_data = <subset for clustering>,
  scaled_data = <standardized data>,
  scale_params = <for scoring new data>,
  n_original = <respondent count>,
  config = <updated config>,
  variable_selection_result = <if enabled>,
  outlier_result = <if enabled>
)
```

### 3.3 Clustering Engine (`segment_clustering.R`)

**Purpose**: Execute k-means clustering and compute metrics

**Key Functions**:

```r
run_exploration_clustering(data_list, config)
# Tests multiple k values (k_min to k_max)
# Returns models + metrics for each k

run_final_clustering(data_list, config)
# Single k clustering
# Returns final model + assignments

validate_cluster_quality(model, data)
# Computes silhouette, within/between SS
# Returns validation metrics
```

**Clustering Process**:
1. Scale data (if standardize=TRUE)
2. Run kmeans(data, centers=k, nstart=25, algorithm="Hartigan-Wong")
3. Compute validation metrics (silhouette, elbow)
4. Check segment sizes vs. min_segment_size_pct
5. Warn if segments too small

**Algorithm Choice**: Uses Hartigan-Wong (default) for better performance on large datasets

### 3.4 Profiling System (`segment_profiling.R` + `segment_profiling_enhanced.R`)

**Purpose**: Generate segment characteristic profiles

**Key Functions**:

```r
# Base profiling
create_segment_profile(data, clusters, profile_vars)
# Returns means/medians by segment

create_full_segment_profile(data, clusters, clustering_vars, profile_vars)
# Separates clustering vs. profiling variables
# Returns structured profile

# Enhanced profiling (NEW)
test_segment_differences(data, clusters, variables)
# ANOVA/Kruskal-Wallis significance tests
# Returns p-values and effect sizes

calculate_index_scores(data, clusters, variables)
# Computes index scores (100 = average)
# Useful for reporting

calculate_cohens_d(data, clusters, variables)
# Pairwise effect sizes between segments
# Small: 0.2, Medium: 0.5, Large: 0.8
```

**Profile Output Structure**:
```
Variable | Segment_1 | Segment_2 | Segment_3 | Segment_4 | Overall
---------|-----------|-----------|-----------|-----------|--------
q1       | 8.5       | 6.2       | 3.1       | 9.2       | 7.1
q2       | 8.3       | 6.5       | 2.8       | 9.0       | 7.0
...
```

### 3.5 Export System (`segment_export.R`)

**Purpose**: Generate Excel reports and save results

**Key Functions**:

```r
export_exploration_report(exploration_result, config, data_list, output_folder)
# Multi-sheet workbook with k-selection metrics and profiles for each k

export_final_report(final_result, config, data_list, output_folder)
# Complete final segmentation report

export_segment_assignments(data, clusters, segment_names, id_var, output_path)
# Simple respondent-to-segment mapping file
```

**Report Sheets**:
- **Exploration**: Metrics_Comparison, Profile_k3, Profile_k4, ..., VarSel, Outliers
- **Final**: Summary, Profiles, Demographics, VarSel, Outliers

**Label Integration**: All export functions now support question_labels for enhanced readability

### 3.6 Model Scoring (`segment_scoring.R`) - NEW

**Purpose**: Apply saved models to new data

**Key Functions**:

```r
score_new_data(model_file, new_data, id_variable, output_file)
# Loads model, validates new data, assigns segments
# Returns assignments with confidence scores

compare_segment_distributions(model_file, scoring_result)
# Monitors segment drift over time
# Returns comparison table
```

**Scoring Process**:
1. Load saved model (centers, config, scale_params)
2. Validate new data has all clustering variables
3. Handle missing data (same method as original)
4. Standardize using original scale parameters
5. Calculate distances to each center
6. Assign to nearest center
7. Compute confidence scores

**Model RDS Structure**:
```r
model_object <- list(
  model = <kmeans object>,
  k = <number of segments>,
  centers = <cluster centers matrix>,
  clustering_vars = <variable names>,
  config = <full config>,
  scale_params = <mean/sd for standardization>,
  original_distribution = <segment counts>,
  timestamp = <creation time>
)
```

### 3.7 Validation System (`segment_validation.R`) - NEW

**Purpose**: Test segment quality and stability

**Key Functions**:

```r
assess_segment_stability(data, clustering_vars, k, n_bootstrap)
# Bootstrap resampling to test consistency
# Returns Jaccard similarity scores

perform_discriminant_analysis(data, clusters, clustering_vars)
# LDA to test separability
# Returns classification accuracy

calculate_separation_metrics(data, clusters, clustering_vars)
# Calinski-Harabasz and Davies-Bouldin indices
# Higher CH = better, Lower DB = better

validate_segmentation(data, clusters, clustering_vars, k)
# Runs all validation metrics
# Returns overall quality assessment
```

**Bootstrap Stability Algorithm**:
```
For i = 1 to n_bootstrap:
  1. Resample data with replacement
  2. Cluster resampled data
  3. Map assignments back to original indices
  4. Compare with previous iteration (Jaccard similarity)
  
Stability = Average Jaccard similarity across iterations
```

### 3.8 Visualization System (`segment_visualization.R`) - NEW

**Purpose**: Create charts and visual analytics

**Key Functions**:

```r
plot_segment_sizes(clusters, segment_names, output_file)
# Bar chart with counts and percentages

plot_k_selection(exploration_result, output_file)
# Elbow and silhouette plots side-by-side

plot_segment_profiles(profile, question_labels, output_file)
# Heatmap of segment profiles

plot_segment_spider(profile, max_vars, question_labels, output_file)
# Radar/spider chart (requires fmsb package)

create_all_visualizations(result, output_folder, prefix, question_labels)
# Convenience function to generate all standard charts
```

**Visualization Design**:
- Uses base R graphics (no dependencies)
- PNG output (800x600 or 1000x500 for dual plots)
- Colorblind-friendly palettes (rainbow with alpha, blues, greens)
- Labeled axes and legends

### 3.9 GUI Console Output System (`run_segment_gui.R`) - NEW

**Purpose**: Provide real-time analysis feedback in Shiny GUI

**Architecture**: The GUI console output system was modeled after the tracker module's EXACT pattern to ensure R 4.2+ compatibility and prevent grey screen crashes.

**Key Components**:

```r
# 1. Console output reactive value
console_output <- reactiveVal("")

# 2. CSS styling for dark-themed console
.console-output {
  background: #1e1e1e;
  color: #d4d4d4;
  font-family: 'Courier New', monospace;
  /* ... */
}

# 3. Static UI placement (CRITICAL)
# Console is in STATIC main UI (Step 4), NOT in reactive results_ui
div(class = "step-card",
  div(class = "step-title", "Step 4: Console Output"),
  div(class = "console-output",
    verbatimTextOutput("console_text")
  )
)

# 4. R 4.2+ compatible renderText()
output$console_text <- renderText({
  current_output <- console_output()

  # CRITICAL: Single TRUE/FALSE for R 4.2+
  if (is.null(current_output) ||
      length(current_output) == 0 ||
      nchar(current_output[1]) == 0) {
    "Console output will appear here..."
  } else {
    # Ensure single string
    if (length(current_output) > 1) {
      paste(current_output, collapse = "\n")
    } else {
      current_output
    }
  }
})

# 5. Progress handling - EXACT tracker pattern
progress <- Progress$new(session)  # NOT withProgress()!
progress$set(message = "Running...", value = 0)
on.exit(progress$close())

# 6. Console capture with sink()
output_capture_file <- tempfile()
sink(output_capture_file, type = "output")

# Run analysis...
result <- turas_segment_from_config(...)

sink(type = "output")  # Close sink

# 7. Progress updates OUTSIDE sink blocks
progress$set(value = 0.9, detail = "Finalizing...")
```

**Critical Design Patterns**:

**Pattern 1: Static UI Placement**
- ❌ **WRONG**: Console in `renderUI()` that depends on `analysis_result()`
  ```r
  # CAUSES GREY SCREEN - don't do this!
  output$results_ui <- renderUI({
    req(analysis_result())  # Requires result to exist
    tagList(
      # Console here - BAD!
      verbatimTextOutput("console_text")
    )
  })
  ```

- ✅ **CORRECT**: Console in static main UI
  ```r
  # In main UI layout - always visible
  div(class = "step-card",
    verbatimTextOutput("console_text")
  )
  ```

**Pattern 2: R 4.2+ Conditional Safety**
- **Problem**: `if (nchar(x) == 0)` returns VECTOR in R 4.2+ if `x` is vector
- **Solution**: Always check first element `nchar(x[1])`
  ```r
  # R 4.2+ safe:
  if (is.null(x) || length(x) == 0 || nchar(x[1]) == 0) {
    # Single TRUE/FALSE guaranteed
  }
  ```

**Pattern 3: Progress Outside Sink Blocks**
- **Problem**: `withProgress()` + `incProgress()` inside `sink()` breaks Shiny
- **Solution**: Use `Progress$new(session)` with updates OUTSIDE sink
  ```r
  # CORRECT pattern from tracker:
  progress <- Progress$new(session)
  progress$set(value = 0.3, detail = "Step 1")

  sink(file, type = "output")
  # ... work happens here ...
  sink(type = "output")

  progress$set(value = 0.6, detail = "Step 2")  # OUTSIDE sink
  ```

**Pattern 4: Numeric Safety in Results Display**
- **Problem**: `round(x, 3)` fails if `x` is not numeric
- **Solution**: Check type before mathematical operations
  ```r
  if (!is.null(value) && is.numeric(value)) {
    round(value, 3)
  } else {
    "N/A"
  }
  ```

**Common Pitfalls**:

1. **Grey Screen on Launch**: Console in reactive UI instead of static
2. **Grey Screen During Analysis**: Progress updates inside sink blocks
3. **Console Not Updating**: R 4.2+ conditional returning vector
4. **Display Errors**: Attempting math operations on non-numeric values

**Testing Checklist**:

- [ ] GUI launches without grey screen
- [ ] Console displays placeholder text before analysis
- [ ] Console updates in real-time during analysis
- [ ] Progress indicator works throughout
- [ ] Both exploration and final modes work
- [ ] Results display after completion
- [ ] No errors with non-numeric values

---

## 4. Data Flow

### Exploration Mode Flow

```
User Config (k_min=3, k_max=6, k_fixed=blank)
  ↓
[segment_config.R] Load & Validate Config → mode = "exploration"
  ↓
[segment_data_prep.R] Load Data → Handle Missing → Variable Selection → Outlier Detection
  ↓
[segment_clustering.R] Run Clustering for k=3,4,5,6
  ↓
[segment_profiling.R] Create Profiles for each k
  ↓
[segment_export.R] Export Exploration Report
  ↓
[segment_visualization.R] Create K-Selection Plots
  ↓
User Reviews Metrics → Chooses k=4
```

### Final Mode Flow

```
User Config (k_fixed=4)
  ↓
[segment_config.R] Load & Validate Config → mode = "final"
  ↓
[segment_data_prep.R] Load & Prepare Data
  ↓
[segment_clustering.R] Run Clustering for k=4
  ↓
[segment_profiling.R] Create Full Profile
[segment_profiling_enhanced.R] Statistical Tests (optional)
  ↓
[segment_export.R] Export Final Report + Assignments
  ↓
[segment_visualization.R] Create Charts
  ↓
[segment_validation.R] Validate Quality (optional)
  ↓
Save Model → [segment_scoring.R] Score New Data (later)
```

---

## 5. Function Reference

### Public API Functions

These are the main entry points users call:

```r
# Main orchestrator
turas_segment_from_config(config_file, verbose = TRUE)

# GUI launcher
run_segment_gui()

# Model scoring
score_new_data(model_file, new_data, id_variable, output_file = NULL)

# Validation
validate_segmentation(data, clusters, clustering_vars, k, n_bootstrap = 100)

# Visualization
create_all_visualizations(result, output_folder, prefix, question_labels)

# Enhanced profiling
create_enhanced_profile_report(data, clusters, clustering_vars, profile_vars, 
                               output_path, question_labels)

# Utilities
generate_config_template(data_file, output_file, mode)
validate_input_data(data, id_variable, clustering_vars)
initialize_segmentation_project(project_name, data_file, base_folder)
```

### Internal Helper Functions

Do not call directly, used by public API:

```r
# Config
read_segment_config()
validate_segment_config()

# Data prep
load_survey_data()
handle_missing_data()
standardize_data()

# Clustering
kmeans_wrapper()
compute_silhouette()
compute_validation_metrics()

# Profiling
calculate_means_by_segment()
calculate_categorical_profiles()

# Export
create_excel_sheets()
format_profile_for_export()
```

---

## 6. Extension Points

### Adding a New Clustering Method

Currently only k-means supported. To add hierarchical or DBSCAN:

1. **Add to segment_clustering.R**:
```r
run_hierarchical_clustering <- function(data_list, config) {
  # Implementation
  # Must return same structure as run_final_clustering()
}
```

2. **Update config validation** in `segment_config.R`:
```r
method <- get_char_config(config, "method", default_value = "kmeans",
                         allowed_values = c("kmeans", "hierarchical", "dbscan"))
```

3. **Update main orchestrator** in `run_segment.R`:
```r
if (config$method == "kmeans") {
  result <- run_final_clustering(data_list, config)
} else if (config$method == "hierarchical") {
  result <- run_hierarchical_clustering(data_list, config)
}
```

### Adding a New Export Format

Currently Excel only. To add CSV or JSON:

1. **Add to segment_export.R**:
```r
export_to_json <- function(result, output_path) {
  json_data <- jsonlite::toJSON(result, pretty = TRUE)
  writeLines(json_data, output_path)
}
```

2. **Add config parameter**:
```
export_format = xlsx,csv,json
```

3. **Call in orchestrator**:
```r
if ("json" %in% config$export_formats) {
  export_to_json(result, json_path)
}
```

### Adding New Validation Metrics

To add Gap statistic or CCC index:

1. **Add to segment_clustering.R**:
```r
compute_gap_statistic <- function(data, clusters, k) {
  # Implementation
  # Return numeric value
}
```

2. **Integrate into validation**:
```r
metrics$gap_statistic <- compute_gap_statistic(data, clusters, k)
```

3. **Add to export** in metrics comparison table

---

## 7. Testing

### Test Data

Located in `modules/segment/test_data/`:

- `test_survey_data.csv`: 500 respondents, 20 satisfaction variables + demographics
- `test_segment_config.xlsx`: Basic exploration config (5 variables)
- `test_varsel_config.xlsx`: Variable selection config (20 variables → 10)
- `test_question_labels.xlsx`: Question label mappings

### Manual Testing Workflow

```r
# Test basic segmentation
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("modules/segment/test_data/test_segment_config.xlsx")

# Test variable selection
result_varsel <- turas_segment_from_config("modules/segment/test_data/test_varsel_config.xlsx")

# Test model scoring
source("modules/segment/lib/segment_scoring.R")
scores <- score_new_data(
  model_file = "modules/segment/test_data/output/test_model.rds",
  new_data = new_test_data,
  id_variable = "respondent_id"
)

# Test validation
source("modules/segment/lib/segment_validation.R")
validation <- validate_segmentation(
  data = test_data,
  clusters = result$clusters,
  clustering_vars = c("q1","q2","q3","q4","q5"),
  k = 4
)
```

### Unit Testing (Future)

Create `tests/` directory with testthat:

```r
test_that("Config validation catches invalid k_min", {
  config <- list(k_min = 5, k_max = 3)
  expect_error(validate_segment_config(config))
})

test_that("Variable selection reduces to target", {
  result <- select_clustering_variables(data, vars, target_n = 10)
  expect_equal(length(result$selected_vars), 10)
})
```

---

## 8. Debugging

### Common Issues

**Issue**: k-means doesn't converge
- **Debug**: Check if data has extreme outliers or constants
- **Fix**: Enable outlier detection or check variable variance

**Issue**: Segments all same size
- **Debug**: Check if standardization is working
- **Fix**: Verify scale() is applied correctly in clustering_data

**Issue**: Missing clustering variables error
- **Debug**: Print `names(data)` and `config$clustering_vars`
- **Fix**: Check case-sensitivity and whitespace

### Debugging Tools

**Add verbose logging**:
```r
if (config$verbose) {
  cat(sprintf("DEBUG: Clustering %d respondents with %d variables\n",
              nrow(data), length(vars)))
  print(str(data))
}
```

**Inspect intermediate results**:
```r
# In run_segment.R, add:
saveRDS(data_list, "debug_data_list.rds")
# Then inspect:
debug_data <- readRDS("debug_data_list.rds")
View(debug_data$scaled_data)
```

**Check model structure**:
```r
model <- readRDS("output/seg_model.rds")
str(model)  # Verify all expected elements present
```

### Performance Profiling

```r
# Profile clustering performance
Rprof("clustering_profile.out")
result <- run_final_clustering(data_list, config)
Rprof(NULL)
summaryRprof("clustering_profile.out")
```

---

## 9. Performance Optimization

### Bottlenecks

1. **k-means iterations**: nstart=25 runs algorithm 25 times
   - Reduce to 10 for faster results (slightly less stable)

2. **Variable selection bootstrap**: 100 iterations per method
   - Reduce to 50 for speed

3. **Silhouette computation**: O(n²) for large datasets
   - Skip silhouette for n > 5000 respondents

4. **Excel export**: Large multi-sheet workbooks
   - Use CSV for assignments if speed critical

### Optimization Strategies

**Large datasets (10k+ respondents)**:
```r
# In config:
nstart = 10  # Instead of 25
k_selection_metrics = "elbow"  # Skip silhouette
variable_selection = FALSE  # Pre-select variables manually
```

**Parallel processing** (future enhancement):
```r
library(parallel)
cl <- makeCluster(detectCores() - 1)
results <- parLapply(cl, k_values, function(k) {
  run_clustering_for_k(data, k)
})
stopCluster(cl)
```

---

## 10. Future Enhancements

### Planned Features

**Phase 2:**
- [ ] Hierarchical clustering support
- [ ] DBSCAN density-based clustering
- [ ] Automatic segment naming (based on profiles)
- [ ] PowerPoint export template
- [ ] Interactive Shiny dashboard for exploring segments

**Phase 3:**
- [ ] Multi-method ensemble (combine k-means + hierarchical)
- [ ] Time-series segmentation (segments evolving over time)
- [ ] Integration with CRM systems
- [ ] API endpoint for model scoring
- [ ] Automated reporting scheduler

### Technical Debt

- [ ] Add comprehensive unit tests (testthat)
- [ ] Refactor config validation (currently one large function)
- [ ] Standardize error messages (use message catalog)
- [ ] Add progress bars for long operations (shiny::withProgress)
- [ ] Optimize silhouette computation for large n

### Known Limitations

1. **Categorical variables**: Not supported for clustering (only numeric)
   - **Workaround**: Use k-modes or convert to dummies externally

2. **Mixed-type data**: Can't cluster on numeric + categorical together
   - **Workaround**: Use Gower distance + PAM (not implemented)

3. **Very small segments**: k-means can create tiny segments
   - **Mitigation**: min_segment_size_pct parameter enforced

4. **Label switching**: Segment numbers may change between runs
   - **Workaround**: Use segment_names to maintain consistency

---

## Appendix A: File Dependency Graph

```
run_segment.R
  ├─→ segment_config.R
  │     └─→ modules/shared/lib/config_utils.R
  │     └─→ modules/shared/lib/validation_utils.R
  ├─→ segment_data_prep.R
  │     ├─→ segment_variable_selection.R
  │     │     └─→ segment_config.R
  │     └─→ segment_outliers.R
  ├─→ segment_clustering.R
  ├─→ segment_profiling.R
  └─→ segment_export.R
        └─→ segment_config.R

run_segment_gui.R
  └─→ run_segment.R (calls turas_segment_from_config)

segment_scoring.R (standalone)
  └─→ segment_config.R (for label formatting)

segment_validation.R (standalone)

segment_visualization.R (standalone)
  └─→ segment_config.R (for label formatting)

segment_profiling_enhanced.R (standalone)
  └─→ segment_config.R (for label formatting)

segment_utils.R (standalone)
```

---

## Appendix B: Configuration Schema

**JSON Schema representation** (for validation tools):

```json
{
  "type": "object",
  "required": ["data_file", "id_variable", "clustering_vars"],
  "properties": {
    "data_file": {"type": "string"},
    "id_variable": {"type": "string"},
    "clustering_vars": {"type": "string", "pattern": "^[^,]+(,[^,]+)*$"},
    "method": {"enum": ["kmeans"]},
    "k_fixed": {"type": ["integer", "null"], "minimum": 2},
    "k_min": {"type": "integer", "minimum": 2, "maximum": 10},
    "k_max": {"type": "integer", "minimum": 2, "maximum": 15},
    "standardize": {"type": "boolean"},
    "outlier_detection": {"type": "boolean"},
    "variable_selection": {"type": "boolean"}
  }
}
```

---

**End of Maintenance Manual**

For user-facing documentation, see `QUICK_START.md` and `USER_MANUAL.md`.
