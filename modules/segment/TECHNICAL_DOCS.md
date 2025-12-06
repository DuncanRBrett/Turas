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
