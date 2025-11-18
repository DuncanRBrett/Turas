# turas Key Driver Analysis Module - Development Specification

**Version:** 1.0  
**Date:** November 2025  
**Purpose:** Complete development specification for a world-class, configuration-driven key driver analysis module

---

## 1. EXECUTIVE SUMMARY

The Key Driver Analysis (KDA) module is a standalone yet integrated component of the turas survey analysis package. It enables non-technical users to identify which survey attributes (drivers) have the strongest influence on key outcome metrics (e.g., satisfaction, NPS, loyalty) through Excel-based configuration and multiple statistical methods.

**Core Principles:**
- **Zero-code configuration**: All setup via Excel templates
- **Method agnostic**: Support multiple KDA approaches
- **Future-proof**: Extensible without code modification
- **Survey-aware**: Leverage turas weighting, scaling, and data handling
- **Production-ready**: Enterprise-grade validation and error handling

---

## 2. FUNCTIONAL REQUIREMENTS

### 2.1 Supported Methods

The module shall support the following key driver analysis methods, selectable via configuration:

| Method | Description | Use Case | R Package |
|--------|-------------|----------|-----------|
| **Correlation Analysis** | Pearson/Spearman correlation | Quick screening, linear relationships | Base R `cor()` |
| **Linear Regression** | OLS with standardized coefficients | Continuous outcomes, interpretability | Base R `lm()` |
| **Logistic Regression** | Binary/ordinal outcomes | Top-box, satisfaction thresholds | Base R `glm()` |
| **Relative Weights** | Johnson's relative weights | Correlated predictors, variance decomposition | `relaimpo` package |
| **Shapley Value Regression** | Game-theory based attribution | Fair allocation, model-agnostic | `relaimpo` or custom implementation |
| **Random Forest Importance** | Tree-based variable importance | Non-linear relationships, interactions | `ranger` or `randomForest` |
| **Dominance Analysis** | Complete/conditional dominance | Hierarchical importance | `dominanceanalysis` or custom |

### 2.2 Input Data Requirements

**Data Structure:**
- Survey data in long or wide format
- One row per respondent
- Columns for: respondent ID, outcome variable(s), driver variables, weights (optional), segments (optional)

**Variable Types Supported:**
- Numeric scales (1-5, 1-10, 0-100, etc.)
- Likert scales (with turas handling)
- Rating scales
- Top-box/Bottom-box (binary conversions)
- Categorical (for segmentation)

**Integration with turas:**
- Utilize existing `turas::apply_weights()` function
- Leverage `turas::likert_to_numeric()` conversion
- Use `turas::calculate_topbox()` and `turas::calculate_bottombox()`
- Integrate with `turas::load_survey_data()` pipeline

### 2.3 Configuration via Excel

**Configuration Workbook Structure:**

```
KeyDriverConfig.xlsx
│
├── [1] ProjectSetup          # Project metadata and method selection
├── [2] DataMapping           # Variable definitions and transformations
├── [3] MethodParameters      # Method-specific settings
├── [4] OutputSpecification   # Report structure and formatting
├── [5] SegmentDefinition     # Optional: segment analysis rules
└── [6] ValidationRules       # Data quality checks
```

#### Sheet 1: ProjectSetup

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| project_name | Text | Project identifier | "Q4_2025_Customer_Sat" |
| analyst_name | Text | Person running analysis | "Jane Smith" |
| data_file_path | Path | Location of survey data | "../data/survey_data.csv" |
| data_type | Enum | Data format | "CSV", "SPSS", "Excel" |
| use_weights | Boolean | Apply survey weights | TRUE |
| weight_variable | Text | Weight column name | "final_weight" |
| primary_method | Enum | Default KDA method | "relative_weights" |
| secondary_methods | List | Additional methods to run | "correlation, regression" |
| output_folder | Path | Where to save results | "../output/kda_results/" |
| run_diagnostics | Boolean | Include model diagnostics | TRUE |
| confidence_level | Numeric | CI level (0-1) | 0.95 |

#### Sheet 2: DataMapping

| outcome_name | outcome_variable | outcome_type | transform | drivers_group | exclude_missing |
|--------------|------------------|--------------|-----------|---------------|-----------------|
| Overall_Satisfaction | Q1_Overall | numeric | none | service_drivers | TRUE |
| NPS_Category | Q2_NPS | topbox | threshold=9 | all_drivers | TRUE |
| Loyalty_Score | Q3_Loyalty | numeric | standardize | loyalty_drivers | FALSE |

**Driver Group Definitions:**

| group_name | driver_variables | variable_type | transform | include_in_model |
|------------|------------------|---------------|-----------|------------------|
| service_drivers | Q4_Speed, Q5_Quality, Q6_Courtesy | likert | likert_to_numeric | TRUE |
| product_drivers | Q7_Features, Q8_Price, Q9_Reliability | rating | none | TRUE |
| loyalty_drivers | Q10_Recommend, Q11_Repurchase | numeric | none | TRUE |

#### Sheet 3: MethodParameters

| method | parameter | value | description |
|--------|-----------|-------|-------------|
| correlation | method | "pearson" | Correlation type |
| correlation | min_threshold | 0.3 | Minimum correlation to report |
| regression | standardize | TRUE | Use standardized coefficients |
| regression | vif_check | TRUE | Check multicollinearity |
| regression | vif_threshold | 5 | Maximum acceptable VIF |
| relative_weights | metric | "lmg" | Relative importance metric |
| random_forest | n_trees | 500 | Number of trees |
| random_forest | mtry | "auto" | Variables per split |
| random_forest | importance_type | "permutation" | Importance calculation method |
| shapley | n_permutations | 100 | Sampling iterations |

#### Sheet 4: OutputSpecification

| output_type | include | format_options | filename_suffix |
|-------------|---------|----------------|-----------------|
| summary_table | TRUE | rank=TRUE, show_ci=TRUE | "_summary" |
| detailed_results | TRUE | include_diagnostics=TRUE | "_detailed" |
| comparison_chart | TRUE | method="bar", top_n=10 | "_chart" |
| correlation_matrix | TRUE | style="heatmap" | "_corr_matrix" |
| diagnostic_plots | TRUE | residuals=TRUE, qq=TRUE | "_diagnostics" |
| executive_summary | TRUE | template="standard" | "_exec_summary" |

#### Sheet 5: SegmentDefinition (Optional)

| segment_name | segment_variable | segment_values | run_separate_analysis |
|--------------|------------------|----------------|----------------------|
| Region | demo_region | "North, South, East, West" | TRUE |
| Customer_Type | demo_customer_type | "New, Returning" | TRUE |
| Tenure | demo_tenure | "0-1yr, 1-3yr, 3yr+" | FALSE |

#### Sheet 6: ValidationRules

| rule_name | check_type | threshold | action_if_fail |
|-----------|------------|-----------|----------------|
| minimum_sample_size | count | 100 | error |
| max_missing_pct | missing_data | 0.20 | warning |
| outcome_variance | variance | 0.1 | warning |
| correlation_singularity | correlation | 0.95 | error |
| vif_multicollinearity | vif | 10 | warning |

---

## 3. TECHNICAL ARCHITECTURE

### 3.1 Module Structure

```
turas/
└── R/
    ├── kda_main.R                    # Main orchestration function
    ├── kda_config_loader.R           # Excel configuration parser
    ├── kda_data_prep.R               # Data validation and preparation
    ├── kda_methods/
    │   ├── method_correlation.R      # Correlation analysis
    │   ├── method_regression.R       # Linear/logistic regression
    │   ├── method_relative_weights.R # Relative importance
    │   ├── method_shapley.R          # Shapley values
    │   ├── method_random_forest.R    # Random forest importance
    │   └── method_dominance.R        # Dominance analysis
    ├── kda_output/
    │   ├── output_excel.R            # Excel report generation
    │   ├── output_charts.R           # Chart creation (future)
    │   ├── output_powerpoint.R       # PPT export (future)
    │   └── output_dashboard.R        # Dashboard generation (future)
    ├── kda_validation.R              # Data quality checks
    ├── kda_diagnostics.R             # Model diagnostics
    └── kda_utils.R                   # Shared utilities
```

### 3.2 Core Functions

#### 3.2.1 Main Orchestration

```r
#' Run Key Driver Analysis
#'
#' Master function to execute complete key driver analysis workflow
#'
#' @param config_file Path to Excel configuration file
#' @param validate_only If TRUE, only validate configuration without running analysis
#' @param verbose Print progress messages
#' @return kda_results object containing all analysis outputs
#' @export
run_key_driver_analysis <- function(
  config_file,
  validate_only = FALSE,
  verbose = TRUE
) {
  # 1. Load and validate configuration
  # 2. Load and prepare data
  # 3. Run validation checks
  # 4. Execute selected methods
  # 5. Generate outputs
  # 6. Return structured results object
}
```

#### 3.2.2 Configuration Loading

```r
#' Load KDA Configuration from Excel
#'
#' Parse Excel configuration file into structured R object
#'
#' @param config_file Path to configuration Excel file
#' @return kda_config S3 object
#' @export
load_kda_config <- function(config_file) {
  # Read all sheets using openxlsx or readxl
  # Validate required sheets exist
  # Parse each sheet into list structure
  # Perform configuration validation
  # Return kda_config object
}

#' Validate KDA Configuration
#'
#' Check configuration for completeness and correctness
#'
#' @param config kda_config object
#' @return List with valid=TRUE/FALSE and messages
validate_kda_config <- function(config) {
  # Check required fields present
  # Validate file paths exist
  # Check method names are valid
  # Validate parameter ranges
  # Return validation results
}
```

#### 3.2.3 Data Preparation

```r
#' Prepare Data for KDA
#'
#' Load, transform, and validate survey data for analysis
#'
#' @param config kda_config object
#' @return kda_data S3 object with prepared data
prepare_kda_data <- function(config) {
  # 1. Load data using turas::load_survey_data()
  # 2. Apply weights if specified
  # 3. Transform variables (likert, topbox, etc.)
  # 4. Handle missing data
  # 5. Create analysis dataset
  # 6. Run validation rules
}

#' Apply Variable Transformations
#'
#' Transform variables based on configuration
#'
#' @param data Data frame
#' @param mapping Data mapping configuration
#' @return Transformed data frame
apply_transformations <- function(data, mapping) {
  # Handle likert_to_numeric
  # Handle topbox/bottombox conversions
  # Handle standardization
  # Handle custom transformations
}
```

#### 3.2.4 Method Execution

Each method has a standardized interface:

```r
#' Execute [Method Name] Analysis
#'
#' @param data Prepared analysis dataset
#' @param outcome Character, outcome variable name
#' @param drivers Character vector, driver variable names
#' @param params List, method-specific parameters
#' @param weights Character, weight variable name (optional)
#' @return kda_method_result S3 object
run_method_[methodname] <- function(
  data,
  outcome,
  drivers,
  params = list(),
  weights = NULL
) {
  # Execute method
  # Calculate importance metrics
  # Generate confidence intervals
  # Return standardized result object
}
```

**Example: Relative Weights**

```r
#' Execute Relative Weights Analysis
#'
#' Johnson's relative weights for correlated predictors
#'
#' @inheritParams run_method_correlation
#' @return kda_method_result object
run_method_relative_weights <- function(
  data,
  outcome,
  drivers,
  params = list(),
  weights = NULL
) {
  
  # Default parameters
  metric <- params$metric %||% "lmg"  # lmg, pmvd, last, first, betasq
  
  # Apply weights if provided
  if (!is.null(weights)) {
    data <- apply_survey_weights(data, weights)
  }
  
  # Prepare formula
  formula <- as.formula(paste(outcome, "~", paste(drivers, collapse = " + ")))
  
  # Fit model
  model <- lm(formula, data = data)
  
  # Calculate relative importance
  rel_imp <- relaimpo::calc.relimp(
    model,
    type = metric,
    rela = TRUE
  )
  
  # Bootstrap confidence intervals
  rel_imp_boot <- relaimpo::boot.relimp(
    model,
    b = 1000,
    type = metric,
    rank = TRUE
  )
  
  # Structure results
  results <- data.frame(
    driver = drivers,
    importance = rel_imp@lmg,
    rank = rank(-rel_imp@lmg),
    ci_lower = rel_imp_boot@boot.lower,
    ci_upper = rel_imp_boot@boot.upper,
    pct_variance = rel_imp@lmg * 100
  )
  
  # Create result object
  kda_result <- structure(
    list(
      method = "relative_weights",
      results = results,
      model = model,
      params = params,
      diagnostics = extract_diagnostics(model)
    ),
    class = "kda_method_result"
  )
  
  return(kda_result)
}
```

#### 3.2.5 Output Generation

```r
#' Generate KDA Excel Report
#'
#' Create comprehensive Excel workbook with all results
#'
#' @param kda_results kda_results object from run_key_driver_analysis()
#' @param config kda_config object
#' @param output_file Path to output Excel file
#' @export
generate_kda_excel_report <- function(
  kda_results,
  config,
  output_file
) {
  # Create workbook
  wb <- openxlsx::createWorkbook()
  
  # Add sheets:
  # 1. Executive Summary
  # 2. Summary Table (all methods comparison)
  # 3. Detailed Results (per method)
  # 4. Correlation Matrix
  # 5. Model Diagnostics
  # 6. Data Quality Report
  # 7. Configuration Record
  
  # Apply formatting
  # Save workbook
}
```

### 3.3 Data Structures

#### kda_config Object

```r
kda_config <- list(
  project = list(
    name = "",
    analyst = "",
    date = Sys.Date()
  ),
  data = list(
    file_path = "",
    type = "",
    use_weights = FALSE,
    weight_var = NULL
  ),
  methods = list(
    primary = "",
    secondary = c(),
    parameters = list()
  ),
  variables = list(
    outcomes = data.frame(),
    drivers = data.frame(),
    segments = data.frame()
  ),
  output = list(
    folder = "",
    specifications = data.frame()
  ),
  validation = list(
    rules = data.frame()
  )
)
class(kda_config) <- "kda_config"
```

#### kda_results Object

```r
kda_results <- list(
  config = kda_config,
  data_summary = list(
    n_obs = 0,
    n_drivers = 0,
    missing_summary = data.frame()
  ),
  method_results = list(
    # One entry per method
    correlation = kda_method_result,
    regression = kda_method_result,
    # etc.
  ),
  comparison = data.frame(
    # Cross-method comparison
  ),
  diagnostics = list(
    # Model fit statistics
    # Validation checks
  ),
  segments = list(
    # Segment-specific results if applicable
  )
)
class(kda_results) <- "kda_results"
```

### 3.4 Recommended R Packages

**Core Analysis:**
- `relaimpo` - Relative importance metrics
- `ranger` - Fast random forest implementation
- `dominanceanalysis` - Dominance analysis
- `survey` - Survey-weighted analysis
- `boot` - Bootstrap confidence intervals
- `car` - VIF and regression diagnostics

**Data Handling:**
- `readxl` - Read Excel configuration files
- `openxlsx` - Write Excel reports with formatting
- `dplyr` - Data manipulation
- `tidyr` - Data reshaping

**Utilities:**
- `broom` - Tidy model outputs
- `rlang` - Non-standard evaluation
- `cli` - User-friendly messages
- `logger` - Logging functionality

**Future (Visualization & Reporting):**
- `ggplot2` - Charts
- `officer` - PowerPoint generation
- `flextable` - Formatted tables
- `shiny` - Dashboards

---

## 4. IMPLEMENTATION SPECIFICATIONS

### 4.1 Error Handling

**Validation Levels:**

1. **Configuration Validation** (Pre-execution)
   - File existence checks
   - Required field completeness
   - Valid enumeration values
   - Parameter range validation

2. **Data Validation** (Pre-analysis)
   - Minimum sample size
   - Missing data thresholds
   - Variable type checks
   - Outcome variance checks

3. **Model Validation** (During analysis)
   - Multicollinearity (VIF)
   - Singularity detection
   - Convergence checks
   - Statistical assumptions

**Error Message Standards:**

```r
# ERROR: Stops execution
stop_kda <- function(message, context = NULL) {
  cli::cli_abort(c(
    "x" = message,
    "i" = context
  ))
}

# WARNING: Continues with caution
warn_kda <- function(message, context = NULL) {
  cli::cli_warn(c(
    "!" = message,
    "i" = context
  ))
}

# INFO: Progress updates
info_kda <- function(message) {
  cli::cli_inform(c(
    "v" = message
  ))
}
```

**Example Error Messages:**

```r
# Good error message
stop_kda(
  "Insufficient sample size for analysis",
  c(
    "Found: 45 observations",
    "Required: 100 observations (per ValidationRules)",
    "Suggestion: Reduce validation threshold or increase sample"
  )
)

# Good warning message
warn_kda(
  "High multicollinearity detected",
  c(
    "Variable 'Q5_Quality' has VIF = 8.3",
    "Threshold: 5.0",
    "Impact: Unstable regression coefficients",
    "Suggestion: Consider removing highly correlated drivers"
  )
)
```

### 4.2 Logging

Implement comprehensive logging using `logger` package:

```r
#' Initialize KDA Logger
#'
#' Set up logging for KDA analysis
#'
#' @param log_file Path to log file
#' @param level Logging level (DEBUG, INFO, WARN, ERROR)
init_kda_logger <- function(
  log_file = NULL,
  level = "INFO"
) {
  logger::log_threshold(level)
  
  if (!is.null(log_file)) {
    logger::log_appender(logger::appender_file(log_file))
  }
  
  logger::log_info("KDA analysis initialized")
}
```

**Log entries should capture:**
- Configuration loaded
- Data preparation steps
- Method execution start/end
- Warnings and errors
- Output generation
- Analysis completion

### 4.3 Performance Considerations

**Large Dataset Handling:**

```r
#' Check if large dataset handling needed
#'
#' @param n_obs Number of observations
#' @return Boolean
is_large_dataset <- function(n_obs) {
  n_obs > 50000
}

# If large dataset:
# - Use ranger instead of randomForest
# - Limit bootstrap iterations
# - Sample for Shapley values
# - Progress bars for long operations
```

**Memory Management:**
- Stream large datasets rather than loading entirely
- Clear intermediate objects
- Use data.table for large operations if needed

### 4.4 Testing Requirements

**Unit Tests (testthat framework):**

```r
# tests/testthat/test-kda-config.R
test_that("Config loader handles valid Excel file", {
  config <- load_kda_config("fixtures/valid_config.xlsx")
  expect_s3_class(config, "kda_config")
  expect_true(validate_kda_config(config)$valid)
})

test_that("Config loader detects missing required fields", {
  expect_error(
    load_kda_config("fixtures/invalid_config.xlsx"),
    "Required field 'project_name' missing"
  )
})

# tests/testthat/test-kda-methods.R
test_that("Relative weights produces expected output", {
  data <- generate_test_data(n = 500)
  result <- run_method_relative_weights(
    data = data,
    outcome = "satisfaction",
    drivers = c("speed", "quality", "price")
  )
  expect_s3_class(result, "kda_method_result")
  expect_equal(nrow(result$results), 3)
  expect_true(all(result$results$importance >= 0))
  expect_equal(sum(result$results$importance), 1, tolerance = 0.01)
})
```

**Integration Tests:**
- Full workflow with sample configuration
- Multi-method comparison
- Segment analysis
- Edge cases (perfect correlation, zero variance, etc.)

**Validation Tests:**
- Known datasets with expected results
- Compare with SPSS/SAS output
- Statistical property verification

### 4.5 Documentation Requirements

**Function Documentation (roxygen2):**
- All exported functions must have complete roxygen2 documentation
- Include parameter descriptions, return values, examples
- Cross-reference related functions

**User Guide:**
- Step-by-step configuration instructions
- Interpretation guide for each method
- Best practices and recommendations
- Troubleshooting common issues

**Technical Documentation:**
- Architecture overview
- Adding new methods (developer guide)
- Configuration schema reference
- API reference

---

## 5. TEMPLATES & CASE STUDIES

### 5.1 Template Configuration Files

**Template 1: Basic Customer Satisfaction KDA**

Purpose: Simple analysis with correlation and regression for CSAT drivers

```
CustomerSat_Template.xlsx
- 5 outcome variables (Overall Sat, NPS, Loyalty, etc.)
- 15 common driver variables
- Methods: correlation, regression, relative_weights
- Basic validation rules
```

**Template 2: Comprehensive Multi-Method Analysis**

Purpose: Compare multiple methods for executive reporting

```
MultiMethod_Template.xlsx
- 1-2 key outcomes
- 10-20 drivers
- Methods: All available methods
- Segment analysis by 1-2 demographics
- Full diagnostic output
```

**Template 3: Quick Screening Analysis**

Purpose: Rapid initial exploration with correlation only

```
QuickScreen_Template.xlsx
- Multiple outcomes
- Large driver set (20-40 variables)
- Methods: correlation only
- Minimal validation
- Simplified output
```

**Template 4: Advanced Non-Linear Analysis**

Purpose: Complex relationships using tree-based methods

```
NonLinear_Template.xlsx
- 1 key outcome
- 10-15 drivers
- Methods: random_forest, regression (comparison)
- Interaction detection
- Feature importance plots
```

### 5.2 Case Studies

**Case Study 1: Bank Customer Satisfaction**

**Scenario:**
- Outcome: Overall satisfaction (1-10 scale)
- Drivers: 12 service attributes (Likert 1-5)
- Sample: 2,500 weighted responses
- Segments: Customer type, region

**Files Provided:**
- `bank_case_study_data.csv` - Sample survey data
- `bank_case_study_config.xlsx` - Configured analysis
- `bank_case_study_results.xlsx` - Expected output
- `bank_case_study_interpretation.pdf` - Analysis write-up

**Learning Objectives:**
- How to configure weighted analysis
- Interpreting relative weights
- Comparing methods
- Segment differences

**Case Study 2: Employee Engagement Drivers**

**Scenario:**
- Outcome: Engagement index (composite score)
- Drivers: 20 workplace factors
- Sample: 1,200 responses (no weights)
- Focus: Comparing linear vs. non-linear methods

**Files Provided:**
- Complete configuration and results
- Comparison of regression vs. random forest
- Guidance on when to use each method

**Case Study 3: NPS Driver Analysis**

**Scenario:**
- Outcome: NPS (top-box analysis, 9-10 promoters)
- Drivers: 15 product/service attributes
- Sample: 5,000 responses
- Methods: Logistic regression, random forest

**Files Provided:**
- Top-box configuration example
- Logistic regression interpretation
- Variable importance comparison

---

## 6. OUTPUT SPECIFICATIONS

### 6.1 Excel Report Structure

**Workbook Layout:**

```
KDA_Results_[ProjectName]_[Date].xlsx

Sheet 1: Executive Summary
├── Project Information
├── Key Findings (top 5 drivers)
├── Method Comparison Summary
└── Recommendations

Sheet 2: Summary Table
├── Driver rankings across all methods
├── Average importance scores
├── Consistency metrics
└── Color-coded heatmap

Sheet 3: [Method Name] - Detailed Results
├── Importance scores with confidence intervals
├── Statistical significance
├── Model fit statistics
└── Interpretation notes
(Repeated for each method)

Sheet 4: Correlation Matrix
├── Driver intercorrelations
├── Heatmap formatting
└── Multicollinearity flags

Sheet 5: Model Diagnostics
├── R-squared, adjusted R-squared
├── VIF values
├── Residual plots summary
└── Assumption checks

Sheet 6: Segment Analysis (if applicable)
├── Results by segment
├── Segment comparison
└── Interaction effects

Sheet 7: Data Quality Report
├── Sample sizes
├── Missing data summary
├── Variable distributions
└── Validation check results

Sheet 8: Configuration Record
├── Analysis settings used
├── Transformations applied
└── Reproducibility information
```

**Formatting Standards:**

```r
# Color scheme
colors <- list(
  header = "#2C3E50",      # Dark blue-grey
  high_importance = "#27AE60",  # Green
  medium_importance = "#F39C12", # Orange
  low_importance = "#E74C3C",    # Red
  neutral = "#ECF0F1"      # Light grey
)

# Conditional formatting rules
format_importance <- function(wb, sheet, data_range) {
  # High importance: > 0.15 (green)
  # Medium importance: 0.05-0.15 (orange)
  # Low importance: < 0.05 (red)
}
```

### 6.2 Charts (Future Enhancement)

**Chart Types:**

1. **Importance Bar Chart**
   - Horizontal bars showing importance scores
   - Error bars for confidence intervals
   - Color by importance tier
   - Top N drivers (configurable)

2. **Method Comparison Chart**
   - Grouped bar chart comparing rankings across methods
   - Highlight consensus drivers
   - Show disagreement

3. **Correlation Heatmap**
   - Driver intercorrelations
   - Color intensity by strength
   - Hierarchical clustering

4. **Segment Comparison**
   - Faceted bar charts by segment
   - Highlight segment-specific drivers

**Package:** `ggplot2` with custom theme

### 6.3 PowerPoint Export (Future Enhancement)

**Template Slides:**

1. Title slide
2. Executive summary
3. Methodology overview
4. Top drivers chart
5. Method comparison
6. Detailed findings (1 slide per method)
7. Segment insights
8. Recommendations

**Package:** `officer` for PPT generation

### 6.4 Dashboard (Future Enhancement)

**Interactive Dashboard Features:**

- Drop-down method selection
- Interactive importance charts
- Drill-down to segments
- Data quality indicators
- Export filtered results

**Package:** `shiny` or `flexdashboard`

---

## 7. EXTENSIBILITY & FUTURE-PROOFING

### 7.1 Adding New Methods

**Design Pattern for New Methods:**

All methods follow a standardized interface, making additions straightforward:

```r
# Template for new method
run_method_[new_method] <- function(
  data,
  outcome,
  drivers,
  params = list(),
  weights = NULL
) {
  
  # 1. Extract and validate parameters
  # 2. Apply weights if provided
  # 3. Execute analysis
  # 4. Calculate importance metrics
  # 5. Generate confidence intervals
  # 6. Return kda_method_result object
  
  return(
    structure(
      list(
        method = "[new_method]",
        results = results_df,  # Standardized format
        model = model_object,
        params = params,
        diagnostics = diagnostics_list
      ),
      class = "kda_method_result"
    )
  )
}
```

**Steps to Add a New Method:**

1. Create new file in `R/kda_methods/method_[name].R`
2. Implement `run_method_[name]()` function
3. Add method to valid methods list in config validator
4. Add method-specific parameters to template
5. Update documentation
6. Add unit tests
7. Update case studies if relevant

**No code changes required in:**
- Main orchestration
- Configuration loading
- Output generation
- Validation framework

### 7.2 Configuration Extension

**Adding New Configuration Options:**

The Excel-based configuration is extensible without code changes:

```r
# Configuration parsing handles unknown columns gracefully
# New columns are stored in config object
# Methods can access via params$[new_parameter]

# Example: Adding a new parameter
# In MethodParameters sheet, add row:
# method = "regression"
# parameter = "robust_se"
# value = TRUE

# Method automatically receives it:
run_method_regression <- function(data, outcome, drivers, params, weights) {
  # Access new parameter
  use_robust <- params$robust_se %||% FALSE
  
  if (use_robust) {
    # Use sandwich package for robust SE
  }
}
```

### 7.3 Output Format Extension

**Adding New Output Formats:**

```r
# Generic output function pattern
generate_kda_[format] <- function(kda_results, config, output_file) {
  # Extract results
  # Format for output type
  # Generate output
  # Save to file
}

# Register in output dispatcher
output_formats <- list(
  excel = generate_kda_excel_report,
  powerpoint = generate_kda_powerpoint,
  dashboard = generate_kda_dashboard,
  pdf = generate_kda_pdf_report  # Future addition
)
```

### 7.4 Custom Transformations

**User-Defined Transformations:**

Allow users to specify custom transformations in configuration:

```r
# In DataMapping sheet:
# transform = "custom:my_transform_function"

# Users can provide R script with transformation functions
# Load custom transformations from specified script file

load_custom_transformations <- function(script_file) {
  source(script_file, local = TRUE)
  # Functions now available
}
```

### 7.5 Plugin Architecture (Advanced)

**Future Enhancement: Plugin System**

```r
# Allow users to create "plugins" for new methods
# Plugin structure:
plugin_structure <- list(
  name = "my_custom_method",
  version = "1.0",
  author = "Jane Doe",
  run_function = run_method_my_custom,
  validate_function = validate_my_custom,
  required_packages = c("package1", "package2"),
  parameter_schema = list(...)
)

# Register plugin
register_kda_plugin(plugin_structure)

# Plugin becomes available in configuration dropdown
```

---

## 8. QUALITY ASSURANCE

### 8.1 Validation Strategy

**Statistical Validation:**

```r
# Compare against known results
validate_against_benchmark <- function() {
  # Load mtcars dataset
  # Run known analysis
  # Compare with published results
  # Assert differences within tolerance
}

# Example benchmark test
test_that("Relative weights matches published example", {
  data(mtcars)
  result <- run_method_relative_weights(
    data = mtcars,
    outcome = "mpg",
    drivers = c("cyl", "disp", "hp", "wt")
  )
  
  # Compare with relaimpo package documentation example
  expected_importance <- c(0.14, 0.34, 0.08, 0.44)
  expect_equal(
    result$results$importance,
    expected_importance,
    tolerance = 0.02
  )
})
```

**Data Quality Checks:**

Automated validation before analysis:

```r
validate_kda_data <- function(data, config) {
  checks <- list()
  
  # 1. Sample size
  checks$sample_size <- list(
    test = nrow(data) >= config$validation$min_sample_size,
    message = sprintf(
      "Sample size: %d (required: %d)",
      nrow(data),
      config$validation$min_sample_size
    )
  )
  
  # 2. Missing data
  missing_pct <- sum(is.na(data)) / (nrow(data) * ncol(data))
  checks$missing_data <- list(
    test = missing_pct <= config$validation$max_missing_pct,
    message = sprintf(
      "Missing data: %.1f%% (max: %.1f%%)",
      missing_pct * 100,
      config$validation$max_missing_pct * 100
    )
  )
  
  # 3. Outcome variance
  # 4. No constant predictors
  # 5. Correlation singularity
  # etc.
  
  return(checks)
}
```

### 8.2 Code Quality Standards

**Code Style:**
- Follow tidyverse style guide
- Use `styler` package for formatting
- Use `lintr` for static code analysis

**Documentation:**
- 100% roxygen2 coverage for exported functions
- Inline comments for complex logic
- Vignettes for user guidance

**Version Control:**
- Semantic versioning (MAJOR.MINOR.PATCH)
- Changelog maintained
- Tagged releases

### 8.3 User Acceptance Testing

**UAT Checklist:**

- [ ] Non-technical user can complete analysis using template
- [ ] Error messages are clear and actionable
- [ ] Results match manual calculations
- [ ] Excel output is formatted and readable
- [ ] Analysis completes in reasonable time (<5 min for typical project)
- [ ] Configuration validation catches common errors
- [ ] Case studies run without modification

---

## 9. DEPLOYMENT & MAINTENANCE

### 9.1 Package Installation

**Installation Methods:**

```r
# From GitHub
devtools::install_github("yourorg/turas")

# From local source
devtools::install_local("path/to/turas")

# Production: CRAN or internal repository
install.packages("turas")
```

**Dependencies:**

Automatic installation of required packages on first use:

```r
# In .onAttach or first function call
check_and_install_kda_dependencies <- function() {
  required_pkgs <- c(
    "relaimpo", "ranger", "openxlsx", "readxl",
    "dplyr", "broom", "cli", "logger"
  )
  
  missing_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
  
  if (length(missing_pkgs) > 0) {
    message("Installing required packages for KDA module...")
    install.packages(missing_pkgs)
  }
}
```

### 9.2 User Training Materials

**Quick Start Guide:**
- 5-minute video tutorial
- Step-by-step PDF guide
- Template walk-through

**Reference Materials:**
- Method selection decision tree
- Interpretation guide for each method
- FAQ document
- Troubleshooting guide

**Advanced Topics:**
- Custom transformations
- Segment analysis strategies
- Handling complex survey designs

### 9.3 Support & Maintenance

**Issue Tracking:**
- GitHub issues for bug reports
- Feature request template
- Internal ticketing system integration

**Versioning Strategy:**
- Major releases: New methods, breaking changes (annually)
- Minor releases: New features, enhancements (quarterly)
- Patch releases: Bug fixes (as needed)

**Backward Compatibility:**
- Maintain compatibility with previous config file versions
- Deprecation warnings before removing features
- Config file version upgrade utilities

---

## 10. SUCCESS METRICS

**Adoption Metrics:**
- Number of projects using KDA module
- Frequency of use per analyst
- Template usage vs. custom configuration

**Quality Metrics:**
- Analysis completion rate (% successful runs)
- Error rate by error type
- User satisfaction score

**Performance Metrics:**
- Average analysis runtime
- Time from data to insights
- Reduction in manual analysis time

**Business Impact:**
- Projects informed by KDA
- Decisions influenced by driver insights
- ROI of insights generated

---

## 11. RISK MITIGATION

**Technical Risks:**

| Risk | Mitigation |
|------|------------|
| Method produces unstable results | Extensive validation, diagnostics, warnings to user |
| Performance issues with large datasets | Optimization, sampling strategies, progress indicators |
| Package dependency breaks | Pin package versions, comprehensive testing |
| Configuration errors | Validation before execution, clear error messages |

**User Risks:**

| Risk | Mitigation |
|------|------------|
| Misinterpretation of results | Interpretation guides, training materials, notes in output |
| Invalid configuration | Template files, examples, validation checks |
| Data quality issues | Automated checks, warnings, data quality report |

**Operational Risks:**

| Risk | Mitigation |
|------|------------|
| Lack of adoption | Training, templates, case studies, clear value demonstration |
| Maintenance burden | Modular design, comprehensive documentation, automated testing |
| Inconsistent usage | Standard templates, best practice guides, peer review process |

---

## 12. IMPLEMENTATION ROADMAP

**Phase 1: Core Functionality (Months 1-2)**
- [ ] Configuration loading and validation
- [ ] Data preparation and integration with turas
- [ ] Implement 3 core methods: correlation, regression, relative weights
- [ ] Basic Excel output
- [ ] Unit tests for core functions
- [ ] Template configuration file

**Phase 2: Method Expansion (Month 3)**
- [ ] Add Shapley values method
- [ ] Add random forest method
- [ ] Add dominance analysis method
- [ ] Enhanced diagnostics
- [ ] Integration testing

**Phase 3: Polish & Documentation (Month 4)**
- [ ] Comprehensive error handling
- [ ] Logging system
- [ ] Complete documentation
- [ ] Case studies (3 examples)
- [ ] User guide and training materials
- [ ] UAT with internal users

**Phase 4: Advanced Features (Month 5-6)**
- [ ] Segment analysis
- [ ] Chart generation
- [ ] PowerPoint export
- [ ] Performance optimization
- [ ] Additional templates

**Phase 5: Deployment (Month 6)**
- [ ] Package installation process
- [ ] Training sessions
- [ ] Production deployment
- [ ] Monitoring and feedback collection

---

## 13. APPENDICES

### Appendix A: Statistical Methods Reference

**Correlation Analysis:**
- Pearson: Linear relationships, continuous variables
- Spearman: Monotonic relationships, ordinal data
- Interpretation: -1 to +1, magnitude indicates strength

**Linear Regression:**
- Standardized coefficients (beta weights)
- Interpretation: Change in SD of outcome per 1 SD change in driver
- Assumptions: Linearity, homoscedasticity, normality of residuals

**Relative Weights (Johnson's):**
- Accounts for multicollinearity
- Sums to R-squared
- Interpretation: Proportion of explained variance attributable to each driver

**Shapley Values:**
- Game-theoretic approach
- Fair allocation of predictive power
- Computationally intensive, use sampling for large datasets

**Random Forest Importance:**
- Permutation importance or impurity-based
- Captures non-linear relationships
- Interpretation: Decrease in model performance when variable removed

**Dominance Analysis:**
- General dominance: Average importance across all subsets
- Conditional dominance: Importance given other predictors
- Complete dominance: Always more important regardless of other predictors

### Appendix B: Example Configuration Files

(Included as separate Excel files in deliverables)

### Appendix C: API Reference

(Complete function documentation - generated from roxygen2)

### Appendix D: Troubleshooting Guide

**Common Issues and Solutions:**

1. **"Insufficient sample size" error**
   - Check ValidationRules sheet minimum_sample_size
   - Verify data file loaded correctly
   - Consider adjusting threshold if appropriate

2. **"High multicollinearity detected" warning**
   - Review correlation matrix
   - Consider removing highly correlated drivers
   - Use relative weights method which handles multicollinearity

3. **"Outcome has zero variance" error**
   - Check outcome variable transformation
   - Verify data loaded correctly
   - Confirm variable mapping in configuration

4. **Analysis runs slowly**
   - Check dataset size
   - Reduce number of bootstrap iterations
   - Consider using ranger instead of randomForest

---

## CONCLUSION

This specification provides a comprehensive blueprint for implementing a world-class key driver analysis module for the turas survey analysis package. The design emphasizes:

- **User-friendliness**: Excel-based configuration requiring no R knowledge
- **Flexibility**: Multiple methods, customizable parameters, extensible architecture
- **Robustness**: Comprehensive validation, error handling, and diagnostics
- **Future-proofing**: Modular design allowing new methods and features without code rewrites
- **Quality**: Extensive testing, documentation, and training materials

The module will serve as a powerful tool for analysts to uncover key drivers of survey outcomes, providing actionable insights for years to come.

---

**Document Version:** 1.0  
**Date:** November 2025  
**Status:** Ready for Development  
**Next Steps:** Review with software team, refine based on feedback, begin Phase 1 implementation
