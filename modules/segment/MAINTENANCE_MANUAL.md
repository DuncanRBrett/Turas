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
