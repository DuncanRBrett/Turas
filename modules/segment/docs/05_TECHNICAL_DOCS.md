# Turas Segmentation Module - Technical Documentation

**Version:** 10.1
**Last Updated:** 29 December 2024
**Target Audience:** Developers, Technical Maintainers, Data Scientists

---

## Table of Contents

1. [Module Overview](#module-overview)
2. [Architecture](#architecture)
3. [File Structure](#file-structure)
4. [Core Components](#core-components)
5. [Data Processing Pipeline](#data-processing-pipeline)
6. [API Reference](#api-reference)
7. [Extension Points](#extension-points)
8. [GUI Implementation](#gui-implementation)
9. [Testing](#testing)
10. [Maintenance Guide](#maintenance-guide)

---

## Module Overview

### Purpose

The Segment module provides K-means clustering for market segmentation analysis. It identifies natural groups within survey respondents based on their attitudes, behaviors, or characteristics.

### Key Features

**Clustering:**
- K-means with configurable k range
- Automatic optimal k selection
- Multiple initialization (nstart)
- Reproducible results (seed)

**Data Preparation:**
- Automatic scaling and normalization
- Outlier detection (Z-score, Mahalanobis)
- Missing data handling
- Variable selection

**Validation:**
- Silhouette coefficient
- Elbow method (WCSS)
- Gap statistic
- Calinski-Harabasz index
- Bootstrap stability

**Profiling:**
- Basic means/frequencies
- Enhanced profiling with ANOVA
- Variable importance (eta-squared)
- Cross-tabulation

### Performance

| Dataset Size | Variables | Time |
|--------------|-----------|------|
| 500 respondents | 10 | 5-10 sec |
| 2,000 respondents | 20 | 15-30 sec |
| 10,000 respondents | 30 | 60-120 sec |

**Scalability:**
- Up to 50,000 respondents
- Up to 50 clustering variables
- k range: 2-20 clusters

---

## Architecture

### Design Pattern

Modular Pipeline Architecture:

```
Config → Data Prep → Outlier Removal → Clustering → Validation → Profiling → Output
```

### Design Principles

1. **Separation of Concerns** - Each file handles one aspect
2. **Two-Mode Operation** - Exploration (find k) vs Final (use k)
3. **Reproducibility** - Seed control for consistent results
4. **Statistical Rigor** - Multiple validation metrics
5. **Extensibility** - Easy to add new methods

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                   SEGMENT MODULE                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ INPUT LAYER                                           │   │
│  │  ├─ Survey Data (CSV/Excel/SPSS)                     │   │
│  │  └─ Configuration (Excel)                            │   │
│  └─────────────────┬────────────────────────────────────┘   │
│                    │                                         │
│  ┌─────────────────▼────────────────────────────────────┐   │
│  │ CONFIGURATION & DATA LOADING                          │   │
│  │  ├─ segment_config.R → Load & validate config        │   │
│  │  └─ segment_data_prep.R → Load & prepare data        │   │
│  └─────────────────┬────────────────────────────────────┘   │
│                    │                                         │
│  ┌─────────────────▼────────────────────────────────────┐   │
│  │ DATA PREPROCESSING                                    │   │
│  │  ├─ Variable selection (segment_variable_selection.R)│   │
│  │  ├─ Missing data handling                            │   │
│  │  ├─ Scaling/normalization                            │   │
│  │  └─ Outlier detection (segment_outliers.R)           │   │
│  └─────────────────┬────────────────────────────────────┘   │
│                    │                                         │
│  ┌─────────────────▼────────────────────────────────────┐   │
│  │ CLUSTERING ENGINE                                     │   │
│  │  ├─ segment_kmeans.R → K-means implementation        │   │
│  │  ├─ Run for k_min to k_max (exploration)             │   │
│  │  └─ Or run for k_fixed (final)                       │   │
│  └─────────────────┬────────────────────────────────────┘   │
│                    │                                         │
│  ┌─────────────────▼────────────────────────────────────┐   │
│  │ VALIDATION                                            │   │
│  │  ├─ segment_validation.R → Quality metrics           │   │
│  │  ├─ Silhouette, WCSS, Gap, Calinski-Harabasz        │   │
│  │  └─ Bootstrap stability                              │   │
│  └─────────────────┬────────────────────────────────────┘   │
│                    │                                         │
│  ┌─────────────────▼────────────────────────────────────┐   │
│  │ PROFILING                                             │   │
│  │  ├─ segment_profile.R → Basic profiling              │   │
│  │  ├─ segment_profiling_enhanced.R → Statistical tests │   │
│  │  └─ Variable importance (eta-squared)                │   │
│  └─────────────────┬────────────────────────────────────┘   │
│                    │                                         │
│  ┌─────────────────▼────────────────────────────────────┐   │
│  │ OUTPUT                                                │   │
│  │  ├─ segment_export.R → Excel output                  │   │
│  │  ├─ segment_visualization.R → Charts                 │   │
│  │  └─ Model object (.rds)                              │   │
│  └─────────────────┬────────────────────────────────────┘   │
│                    │                                         │
│  ┌─────────────────▼────────────────────────────────────┐   │
│  │ SCORING                                               │   │
│  │  └─ segment_scoring.R → Classify new data            │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Dependencies

**R Packages:**
```r
# Core
library(stats)          # kmeans()
library(cluster)        # silhouette(), clusGap()

# Data I/O
library(readxl)         # Excel reading
library(writexl)        # Excel writing
library(haven)          # SPSS support (optional)

# Visualization
library(ggplot2)        # Charts (optional)
```

---

## File Structure

### Directory Layout

```
modules/segment/
├── lib/                                # Core library
│   ├── segment_config.R               # Configuration loading
│   ├── segment_data_prep.R            # Data preparation
│   ├── segment_kmeans.R               # K-means clustering
│   ├── segment_outliers.R             # Outlier detection
│   ├── segment_validation.R           # Validation metrics
│   ├── segment_profile.R              # Basic profiling
│   ├── segment_profiling_enhanced.R   # Enhanced profiling
│   ├── segment_variable_selection.R   # Variable selection
│   ├── segment_scoring.R              # New data scoring
│   ├── segment_export.R               # Excel output
│   ├── segment_visualization.R        # Charts
│   └── segment_utils.R                # Utilities
├── run_segment.R                       # Main entry point (CLI)
├── run_segment_gui.R                   # Shiny GUI
├── test_data/                          # Test datasets
└── docs/                               # Documentation
    ├── 01_README.md
    ├── 02_SEGMENT_OVERVIEW.md
    ├── 03_REFERENCE_GUIDE.md
    ├── 04_USER_MANUAL.md
    ├── 05_TECHNICAL_DOCS.md            # This file
    ├── 06_TEMPLATE_REFERENCE.md
    ├── 07_EXAMPLE_WORKFLOWS.md
    └── templates/
```

### File Responsibilities

| File | Purpose | Key Functions |
|------|---------|---------------|
| segment_config.R | Load/validate config | `read_segment_config()` |
| segment_data_prep.R | Data preprocessing | `prepare_segment_data()` |
| segment_kmeans.R | Clustering engine | `run_kmeans_single()`, `run_kmeans_multiple()` |
| segment_outliers.R | Outlier detection | `detect_outliers_zscore()`, `detect_outliers_mahal()` |
| segment_validation.R | Validation metrics | `calculate_silhouette()`, `calculate_gap_stat()` |
| segment_profile.R | Basic profiling | `profile_clusters()`, `cluster_means()` |
| segment_profiling_enhanced.R | Statistical tests | `enhanced_profile()`, `test_anova()` |
| segment_scoring.R | Score new data | `score_new_data()`, `type_respondent()` |
| segment_export.R | Excel output | `write_segment_results()` |
| segment_visualization.R | Charts | `plot_elbow()`, `plot_silhouette()` |
| segment_utils.R | Utilities & Quick Run | See [segment_utils.R Structure](#segment_utilsr-structure) |

### segment_utils.R Structure

**Refactored December 2024** for improved maintainability and testability.

The file is organized into 9 sections:

| Section | Functions | Purpose |
|---------|-----------|---------|
| 1. Shared Infrastructure | `.source_shared_utils()` | Dynamic loading of shared validation utilities |
| 2. Package Dependencies | `check_segment_dependencies()`, `get_minimum_install_cmd()`, `get_full_install_cmd()` | Dependency checking and install commands |
| 3. Config Template | `generate_config_template()` | Create starter Excel config files |
| 4. Input Validation | `validate_input_data()` | Comprehensive data quality checks |
| 5. Project Init | `initialize_segmentation_project()` | Set up project folder structure |
| 6. Seed Management | `set_segmentation_seed()` | Centralized seed handling |
| 7. Quick Run Helpers | `.validate_quick_inputs()`, `.build_quick_config()`, `.prepare_quick_data()`, `.run_quick_exploration()`, `.run_quick_final()` | Internal helper functions (see below) |
| 8. Quick Run Main | `run_segment_quick()` | Public API orchestrator |
| 9. RNG Utilities | `get_rng_state()`, `restore_rng_state()`, `validate_seed_reproducibility()` | RNG state management |

**Quick Run Helper Functions (Internal):**

The `run_segment_quick()` function delegates to specialized helpers:

```
run_segment_quick()
    │
    ├── .validate_quick_inputs()    # Validate data, variables, k parameter
    │
    ├── .build_quick_config()       # Build config list from parameters
    │
    ├── .prepare_quick_data()       # Handle missing data, standardize
    │
    └── .run_quick_exploration()    # If k=NULL: test multiple k values
        OR
        .run_quick_final()          # If k=integer: run with fixed k
```

This decomposition improves:
- **Testability**: Each helper can be unit tested independently
- **Maintainability**: Single-responsibility functions are easier to modify
- **Readability**: Main function is ~60 lines (was 423 lines)

---

## Core Components

### Configuration Loader

**File:** `segment_config.R`

**Main Function:** `read_segment_config(config_file)`

```r
read_segment_config <- function(config_file) {
  # 1. Read Excel config
  config_raw <- readxl::read_excel(config_file, sheet = "Config")

  # 2. Convert to named list
  config <- setNames(as.list(config_raw$Value), config_raw$Setting)

  # 3. Validate and set defaults
  config <- validate_segment_config(config)

  return(config)
}

validate_segment_config <- function(config) {
  # Required fields
  required <- c("data_file", "id_variable", "clustering_vars")
  missing <- setdiff(required, names(config))
  if (length(missing) > 0) {
    stop("Missing required config fields: ", paste(missing, collapse = ", "))
  }

  # Determine mode
  if (!is.null(config$k_fixed) && !is.na(config$k_fixed) &&
      nchar(trimws(config$k_fixed)) > 0) {
    config$mode <- "final"
    config$k_fixed <- as.integer(config$k_fixed)
  } else {
    config$mode <- "exploration"
  }

  # Parse clustering variables
  config$clustering_vars <- strsplit(config$clustering_vars, ",")[[1]]
  config$clustering_vars <- trimws(config$clustering_vars)

  # Set defaults
  config$nstart <- as.integer(config$nstart %||% 25)
  config$seed <- as.integer(config$seed %||% 123)
  config$standardize <- as.logical(config$standardize %||% TRUE)
  config$k_min <- as.integer(config$k_min %||% 3)
  config$k_max <- as.integer(config$k_max %||% 6)

  return(config)
}
```

### Data Preparation

**File:** `segment_data_prep.R`

**Main Function:** `prepare_segment_data(config)`

```r
prepare_segment_data <- function(config) {
  # 1. Load data
  data <- load_survey_data(config$data_file, config$data_sheet)

  # 2. Validate columns exist
  required_cols <- c(config$id_variable, config$clustering_vars)
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing columns: ", paste(missing_cols, collapse = ", "))
  }

  # 3. Extract clustering data
  cluster_data <- data[, config$clustering_vars, drop = FALSE]

  # 4. Handle missing data
  if (config$missing_data == "listwise_deletion") {
    complete_rows <- complete.cases(cluster_data)
    data <- data[complete_rows, ]
    cluster_data <- cluster_data[complete_rows, ]
  } else if (config$missing_data == "mean_imputation") {
    cluster_data <- impute_means(cluster_data)
  }

  # 5. Scale data
  if (config$standardize) {
    cluster_data_scaled <- scale(cluster_data)
  } else {
    cluster_data_scaled <- as.matrix(cluster_data)
  }

  return(list(
    full_data = data,
    cluster_data = cluster_data,
    cluster_data_scaled = cluster_data_scaled,
    n_rows = nrow(data),
    n_vars = ncol(cluster_data)
  ))
}
```

### K-Means Clustering

**File:** `segment_kmeans.R`

**Exploration Mode:**
```r
run_kmeans_multiple <- function(data_scaled, k_min, k_max, config) {
  results <- list()

  for (k in k_min:k_max) {
    cat(sprintf("Testing k = %d...\n", k))

    km <- stats::kmeans(
      x = data_scaled,
      centers = k,
      nstart = config$nstart,
      iter.max = 100,
      algorithm = "Hartigan-Wong"
    )

    results[[paste0("k", k)]] <- list(
      k = k,
      model = km,
      cluster = km$cluster,
      centers = km$centers,
      size = km$size,
      tot.withinss = km$tot.withinss,
      betweenss = km$betweenss
    )
  }

  return(results)
}
```

**Final Mode:**
```r
run_kmeans_single <- function(data_scaled, k, config) {
  km <- stats::kmeans(
    x = data_scaled,
    centers = k,
    nstart = config$nstart,
    iter.max = 100,
    algorithm = "Hartigan-Wong"
  )

  return(list(
    k = k,
    model = km,
    cluster = km$cluster,
    centers = km$centers,
    size = km$size,
    tot.withinss = km$tot.withinss,
    betweenss = km$betweenss
  ))
}
```

### Validation Metrics

**File:** `segment_validation.R`

```r
calculate_silhouette <- function(data_scaled, clusters) {
  sil <- cluster::silhouette(clusters, dist(data_scaled))
  avg_sil <- mean(sil[, "sil_width"])
  return(avg_sil)
}

calculate_gap_statistic <- function(data_scaled, k_range, B = 50) {
  gap_stat <- cluster::clusGap(
    data_scaled,
    FUNcluster = kmeans,
    nstart = 25,
    K.max = max(k_range),
    B = B
  )
  return(gap_stat)
}

calculate_calinski_harabasz <- function(data_scaled, clusters, k) {
  n <- nrow(data_scaled)

  # Between-cluster SS
  overall_mean <- colMeans(data_scaled)
  bss <- 0
  for (i in 1:k) {
    cluster_data <- data_scaled[clusters == i, , drop = FALSE]
    n_k <- nrow(cluster_data)
    cluster_mean <- colMeans(cluster_data)
    bss <- bss + n_k * sum((cluster_mean - overall_mean)^2)
  }

  # Within-cluster SS
  wss <- 0
  for (i in 1:k) {
    cluster_data <- data_scaled[clusters == i, , drop = FALSE]
    cluster_mean <- colMeans(cluster_data)
    wss <- wss + sum((cluster_data - cluster_mean)^2)
  }

  ch <- (bss / (k - 1)) / (wss / (n - k))
  return(ch)
}
```

### Outlier Detection

**File:** `segment_outliers.R`

```r
detect_outliers_zscore <- function(data, threshold = 3.0, min_vars = 1) {
  z_scores <- scale(data)
  extreme_count <- rowSums(abs(z_scores) > threshold)
  outliers <- extreme_count >= min_vars

  return(list(
    is_outlier = outliers,
    z_scores = z_scores,
    extreme_count = extreme_count
  ))
}

detect_outliers_mahalanobis <- function(data, alpha = 0.001) {
  center <- colMeans(data)
  cov_matrix <- cov(data)

  mahal_dist <- mahalanobis(data, center, cov_matrix)
  threshold <- qchisq(1 - alpha, df = ncol(data))
  outliers <- mahal_dist > threshold

  return(list(
    is_outlier = outliers,
    distances = mahal_dist,
    threshold = threshold
  ))
}
```

### Profiling

**File:** `segment_profile.R`

```r
profile_clusters <- function(data, clusters, clustering_vars) {
  k <- length(unique(clusters))

  # Calculate means by cluster
  profiles <- lapply(1:k, function(i) {
    cluster_data <- data[clusters == i, clustering_vars, drop = FALSE]
    colMeans(cluster_data, na.rm = TRUE)
  })

  profile_df <- do.call(rbind, profiles)
  rownames(profile_df) <- paste0("Segment_", 1:k)

  # Add overall means
  overall <- colMeans(data[, clustering_vars], na.rm = TRUE)
  profile_df <- rbind(profile_df, Overall = overall)

  return(as.data.frame(profile_df))
}
```

**File:** `segment_profiling_enhanced.R`

```r
test_anova <- function(data, clusters, variable) {
  model <- aov(data[[variable]] ~ factor(clusters))
  summary_table <- summary(model)

  # Extract statistics
  f_value <- summary_table[[1]][["F value"]][1]
  p_value <- summary_table[[1]][["Pr(>F)"]][1]

  # Calculate eta-squared
  ss_between <- summary_table[[1]][["Sum Sq"]][1]
  ss_total <- sum(summary_table[[1]][["Sum Sq"]])
  eta_squared <- ss_between / ss_total

  return(list(
    f_value = f_value,
    p_value = p_value,
    eta_squared = eta_squared,
    significant = p_value < 0.05
  ))
}
```

---

## Data Processing Pipeline

### Complete Flow

```
1. LOAD CONFIG
   └─ Read Excel, parse settings, set defaults

2. LOAD DATA
   └─ Read survey file, validate columns

3. HANDLE MISSING
   ├─ Listwise deletion (default)
   └─ Mean/median imputation

4. SCALE DATA
   └─ Z-score standardization

5. DETECT OUTLIERS
   ├─ Z-score method
   └─ Mahalanobis method

6. RUN CLUSTERING
   ├─ Exploration: k_min to k_max
   └─ Final: k_fixed

7. CALCULATE METRICS
   ├─ Silhouette
   ├─ WCSS (elbow)
   ├─ Gap statistic
   └─ Calinski-Harabasz

8. PROFILE SEGMENTS
   ├─ Means
   ├─ ANOVA tests
   └─ Effect sizes

9. EXPORT RESULTS
   ├─ Assignments Excel
   ├─ Report Excel
   ├─ Charts
   └─ Model RDS
```

---

## API Reference

### Main Entry Point

```r
turas_segment_from_config(config_file, data_file = NULL, output_folder = NULL)
```

**Arguments:**
- `config_file`: Path to configuration Excel file
- `data_file`: Override data file path (optional)
- `output_folder`: Override output folder (optional)

**Returns:** List with segmentation results

### Quick Run Function

```r
run_segment_quick(
  data,
  id_var,
  clustering_vars,
  k = NULL,
  k_range = 3:6,
  profile_vars = NULL,
  output_folder = "output/",
  seed = 123,
  question_labels = NULL,
  standardize = TRUE,
  nstart = 50,
  outlier_detection = FALSE,
  missing_data = "listwise_deletion",
  segment_names = "auto"
)
```

**Arguments:**
- `data`: Data frame with survey data (already loaded in memory)
- `id_var`: Name of ID column
- `clustering_vars`: Character vector of clustering variable names
- `k`: Fixed k value (integer) or NULL for exploration mode
- `k_range`: Integer vector for exploration (default: 3:6)
- `profile_vars`: Character vector or NULL (auto-detect if NULL)
- `output_folder`: Output folder path (default: "output/")
- `seed`: Random seed for reproducibility (default: 123)
- `question_labels`: Named vector of question labels or NULL
- `standardize`: Whether to standardize data (default: TRUE)
- `nstart`: Number of random starts for k-means (default: 50)
- `outlier_detection`: Enable outlier detection (default: FALSE)
- `missing_data`: Handling method: "listwise_deletion", "mean_imputation", "median_imputation"
- `segment_names`: Segment naming: "auto" or character vector

**Returns:**

*Exploration Mode (k = NULL):*
```r
list(
  mode = "exploration",
  recommendation = list(recommended_k, ...),
  metrics = list(metrics_df, ...),
  models = list(...),
  output_files = list(report = "path/to/report.xlsx"),
  config = list(...)
)
```

*Final Mode (k = integer):*
```r
list(
  mode = "final",
  k = integer,
  model = kmeans_object,
  clusters = integer_vector,
  segment_names = character_vector,
  validation = list(avg_silhouette, ...),
  profiles = list(...),
  output_files = list(assignments, report, model),
  config = list(...)
)
```

**Internal Architecture:**

The function delegates to 5 internal helper functions:
1. `.validate_quick_inputs()` - Validates all input parameters
2. `.build_quick_config()` - Creates config list from parameters
3. `.prepare_quick_data()` - Handles missing data and standardization
4. `.run_quick_exploration()` - Runs exploration mode (multiple k)
5. `.run_quick_final()` - Runs final mode (fixed k)

### Scoring Function

```r
score_new_data(model_file, new_data, id_variable, output_file = NULL)
```

**Arguments:**
- `model_file`: Path to saved .rds model
- `new_data`: Data frame with new respondents
- `id_variable`: Name of ID column
- `output_file`: Path for output (optional)

**Returns:** Data frame with segment assignments

### Single Respondent Typing

```r
type_respondent(answers, model_file)
```

**Arguments:**
- `answers`: Named vector of answers (e.g., `c(q1=8, q2=7, q3=9)`)
- `model_file`: Path to saved model

**Returns:** List with segment, name, confidence

---

## Extension Points

### Adding New Clustering Methods

1. Create `segment_[method].R` in lib/
2. Implement `run_[method]_single()` and `run_[method]_multiple()`
3. Add method to config validation
4. Update run_segment.R to dispatch

### Adding New Validation Metrics

1. Add function to `segment_validation.R`
2. Update `calculate_all_metrics()`
3. Add to exploration report output

### Adding New Profiling Statistics

1. Add function to `segment_profiling_enhanced.R`
2. Update `create_enhanced_profile_report()`
3. Add sheet to Excel output

---

## GUI Implementation

### Architecture

The GUI uses Shiny with a 5-step workflow:

```r
# run_segment_gui.R structure
ui <- fluidPage(
  # Step 1: File selection
  # Step 2: Validation
  # Step 3: Run button
  # Step 4: Console output (static)
  # Step 5: Results display
)

server <- function(input, output, session) {
  # Reactive values for state
  # Event handlers for buttons
  # Console capture with sink()
}
```

### Console Output System

**R 4.2+ Compatibility:**

```r
# Use Progress$new(session) pattern for Shiny progress
# Console output captured with sink() to temporary file
# Display in verbatimTextOutput (static, not reactive)

observe_analysis <- function() {
  # Create temp file for output capture
  temp_output <- tempfile()
  sink(temp_output, split = TRUE)

  tryCatch({
    # Run analysis
    result <- turas_segment_from_config(config_file)
  }, finally = {
    sink()  # Restore output
  })

  # Read captured output
  console_text <- readLines(temp_output)
  return(console_text)
}
```

### Known GUI Patterns

1. **Console in static UI** - Not in reactive results panel
2. **Progress outside sink()** - Progress$new must be outside sink blocks
3. **Safe conditional checks** - Use `nchar(output[1])` not `nchar(output)`

---

## Testing

### Test Data

Located in `test_data/`:
- `test_survey.csv` - Standard test data
- `test_varsel.csv` - Variable selection test
- `test_outliers.csv` - Outlier detection test

### Test Scenarios

| Scenario | Config | Expected |
|----------|--------|----------|
| Basic exploration | k_min=3, k_max=5 | 3 solutions compared |
| Final run | k_fixed=4 | Single solution with profiles |
| Variable selection | 20 vars, selection=TRUE | Reduced to 10 vars |
| Outlier detection | outlier=TRUE | Outliers flagged/removed |

### Running Tests

```r
source("modules/segment/test_data/run_tests.R")
run_all_segment_tests()
```

---

## Maintenance Guide

### Common Maintenance Tasks

**Adding New Config Parameter:**
1. Add to `validate_segment_config()` with default
2. Document in 06_TEMPLATE_REFERENCE.md
3. Update template Excel files

**Updating Validation Thresholds:**
1. Locate in `segment_validation.R`
2. Update threshold values
3. Update documentation

**Fixing GUI Issues:**
1. Check R version compatibility (4.2+ patterns)
2. Verify sink() blocks don't contain Progress calls
3. Test with fresh R session

### Performance Optimization

**Large Datasets:**
- Use `data.table` for data operations
- Reduce nstart if acceptable
- Limit k_max range
- Sample for gap statistic calculation

**Memory Management:**
- Remove intermediate objects with `rm()`
- Use `gc()` after large operations
- Process in chunks if needed

### Troubleshooting

**"Cannot allocate vector":**
- Reduce dataset size or sample
- Increase R memory limit
- Reduce k_max range

**"Singular covariance matrix":**
- Variables are perfectly correlated
- Remove one of correlated pair
- Use Z-score instead of Mahalanobis

**GUI Grey Screen:**
- Check for errors in R console
- Update to latest code version
- Verify R 4.2+ compatibility patterns

### Version History

**v10.1 (December 2024) - segment_utils.R Refactoring**

Major refactoring of `segment_utils.R` for improved maintainability:

*Changes:*
- Extracted `run_segment_quick()` from 423 lines to ~60 lines orchestrator
- Created 5 internal helper functions (`.validate_quick_inputs()`, `.build_quick_config()`, `.prepare_quick_data()`, `.run_quick_exploration()`, `.run_quick_final()`)
- Added shared infrastructure integration for validation utilities
- Organized file into 9 clearly-labeled sections
- Added comprehensive roxygen documentation

*Benefits:*
- Each helper function can be unit tested independently
- Single-responsibility functions are easier to modify
- Clear separation between validation, configuration, and execution
- Fallback stubs ensure file works standalone if shared utils unavailable

*Backward Compatibility:*
- Public API unchanged - `run_segment_quick()` signature identical
- All existing scripts will continue to work without modification

---

## Additional Resources

- [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods
- [04_USER_MANUAL.md](04_USER_MANUAL.md) - User guide
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Configuration
- [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) - Examples

---

**Part of the Turas Analytics Platform**
