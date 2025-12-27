# Technical Documentation: Turas Pricing Module

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Module Structure](#2-module-structure)
3. [Core Components](#3-core-components)
4. [Mathematical Methods](#4-mathematical-methods)
5. [Data Flow](#5-data-flow)
6. [Configuration System](#6-configuration-system)
7. [Extension Points](#7-extension-points)
8. [Performance Considerations](#8-performance-considerations)
9. [Testing](#9-testing)

---

## 1. Architecture Overview

### 1.1 Design Philosophy

The Turas Pricing module follows these design principles:

- **Configuration-Driven**: All analysis parameters specified in Excel
- **Modular Architecture**: Separate files for distinct functionality
- **Consistent Patterns**: Follows Turas module conventions
- **Fail-Fast Validation**: Comprehensive input checks before analysis
- **Reproducibility**: Deterministic results with full audit trail

### 1.2 Data Flow

```
Config File → Config Loader → Validator → Analysis Engine → Output Generator
     ↓              ↓            ↓              ↓               ↓
   Excel       Structured     Clean Data   Results Object   Excel/Plots
                 List
```

---

## 2. Module Structure

### 2.1 File Organization

```
modules/pricing/
├── R/
│   ├── 00_main.R           # Entry point and orchestration
│   ├── 01_config.R         # Configuration management
│   ├── 02_validation.R     # Data loading and validation
│   ├── 03_van_westendorp.R # Van Westendorp PSM implementation
│   ├── 04_gabor_granger.R  # Gabor-Granger implementation
│   ├── 05_visualization.R  # Plot generation
│   └── 06_output.R         # Excel output generation
├── run_pricing_gui.R       # Shiny GUI launcher
├── tests/                  # Test files
└── docs/                   # Documentation
```

### 2.2 Function Naming Conventions

- Public functions: `run_pricing_analysis()`, `create_pricing_config()`
- Internal functions: Marked with `@keywords internal`
- Helper functions: Prefixed by context (e.g., `check_vw_monotonicity()`)

---

## 3. Core Components

### 3.1 Main Entry Point (00_main.R)

**Primary Function**: `run_pricing_analysis(config_file, data_file, output_file)`

**Workflow**:
1. Load and validate configuration
2. Load and validate data
3. Dispatch to appropriate analysis method
4. Generate visualizations
5. Write output files
6. Return results object

**Return Value**:
```r
list(
  method = "van_westendorp",  # Analysis method used
  results = list(...),        # Method-specific results
  plots = list(...),          # ggplot2 objects
  diagnostics = list(...),    # Validation results
  config = list(...)          # Configuration used
)
```

### 3.2 Configuration System (01_config.R)

**Primary Function**: `load_pricing_config(config_file)`

**Process**:
1. Validate file existence
2. Read Settings sheet
3. Resolve relative paths
4. Load method-specific sheets
5. Apply defaults for missing values
6. Return structured list

**Configuration Structure**:
```r
config <- list(
  project_name = "My Study",
  analysis_method = "van_westendorp",
  data_file = "/path/to/data.csv",
  output_file = "/path/to/output.xlsx",
  project_root = "/path/to/config/dir",
  van_westendorp = list(
    col_too_cheap = "q1",
    col_cheap = "q2",
    ...
  ),
  validation = list(...),
  visualization = list(...)
)
```

### 3.3 Data Validation (02_validation.R)

**Primary Functions**:
- `load_pricing_data()`: Multi-format data loading
- `validate_pricing_data()`: Comprehensive validation

**Validation Checks**:
1. Column existence
2. Data type conversion
3. Range validation
4. Completeness checks
5. Monotonicity validation (Van Westendorp)

**Return Value**:
```r
list(
  clean_data = data.frame(...),  # Validated data
  n_total = 500,                 # Original count
  n_excluded = 25,               # Excluded cases
  n_valid = 475,                 # Valid cases
  exclusion_mask = logical(...), # Which rows excluded
  warnings = list(...)           # Warning messages
)
```

---

## 4. Mathematical Methods

### 4.1 Van Westendorp PSM

#### Cumulative Distribution Calculation

For each price point P in the response range:

```
Curve_TooCheap(P) = Proportion of respondents whose "too cheap" price ≥ P
Curve_NotCheap(P) = Proportion of respondents whose "cheap" price ≤ P
Curve_NotExpensive(P) = Proportion of respondents whose "expensive" price ≥ P
Curve_TooExpensive(P) = Proportion of respondents whose "too expensive" price ≤ P
```

Additionally:
```
Curve_Cheap(P) = 1 - Curve_NotCheap(P)
Curve_Expensive(P) = 1 - Curve_NotExpensive(P)
```

#### Intersection Points

**PMC** (Point of Marginal Cheapness):
```
Find P where Curve_TooCheap(P) = Curve_NotCheap(P)
```

**OPP** (Optimal Price Point):
```
Find P where Curve_TooCheap(P) = Curve_TooExpensive(P)
```

**IDP** (Indifference Price Point):
```
Find P where Curve_Cheap(P) = Curve_Expensive(P)
```

**PME** (Point of Marginal Expensiveness):
```
Find P where Curve_NotExpensive(P) = Curve_TooExpensive(P)
```

#### Intersection Algorithm

Uses linear interpolation between adjacent grid points:

```r
find_curve_intersection <- function(x, y1, y2) {
  diff <- y1 - y2
  sign_changes <- which(diff[-1] * diff[-length(diff)] < 0)
  idx <- sign_changes[1]

  # Linear interpolation
  t <- (y2[idx] - y1[idx]) / ((y1[idx+1] - y1[idx]) - (y2[idx+1] - y2[idx]))
  x[idx] + (x[idx+1] - x[idx]) * t
}
```

#### Bootstrap Confidence Intervals

For each bootstrap iteration b = 1 to B:
1. Resample n respondents with replacement
2. Calculate all price points on resampled data
3. Store results

Calculate percentile confidence intervals:
```
CI_lower = quantile(boot_results, α/2)
CI_upper = quantile(boot_results, 1 - α/2)
```

### 4.2 Gabor-Granger Analysis

#### Demand Curve

For each price point P:
```
Purchase_Intent(P) = (Number willing to buy at P) / (Total respondents)
```

#### Revenue Curve

```
Revenue_Index(P) = P × Purchase_Intent(P)
```

#### Optimal Price

```
Optimal_Price = argmax_P { Revenue_Index(P) }
```

#### Arc Elasticity

Between consecutive price points P1 and P2:

```
E_arc = ((Q2 - Q1) / ((Q2 + Q1) / 2)) / ((P2 - P1) / ((P2 + P1) / 2))
```

Where Q = Purchase_Intent

**Interpretation**:
- |E| > 1: Elastic (demand sensitive to price)
- |E| < 1: Inelastic (demand insensitive to price)
- |E| = 1: Unit elastic

---

## 5. Data Flow

### 5.1 Van Westendorp Pipeline

```
Raw Data
    ↓
[02_validation.R] load_pricing_data()
    ↓
Loaded Data Frame
    ↓
[02_validation.R] validate_pricing_data()
    - Check column existence
    - Convert to numeric
    - Validate ranges
    - Check completeness
    - Check monotonicity
    ↓
Clean Data + Validation Results
    ↓
[03_van_westendorp.R] run_van_westendorp()
    - Extract price columns
    - Remove incomplete cases
    - Calculate curves (200 grid points)
    - Find intersections
    - Calculate confidence intervals (if requested)
    ↓
VW Results Object
    ↓
[05_visualization.R] plot_van_westendorp()
    ↓
ggplot2 Object
    ↓
[06_output.R] write_pricing_output()
    ↓
Excel Workbook + Plot Files
```

### 5.2 Gabor-Granger Pipeline

```
Raw Data
    ↓
[02_validation.R] load_pricing_data()
    ↓
Loaded Data Frame
    ↓
[04_gabor_granger.R] prepare_gg_wide_data() or prepare_gg_long_data()
    - Reshape to standard format
    - Code responses as binary
    ↓
Standardized Long Format
    ↓
[04_gabor_granger.R] run_gabor_granger()
    - Check monotonicity
    - Calculate demand curve
    - Calculate revenue curve
    - Find optimal price
    - Calculate elasticity
    - Bootstrap confidence intervals
    ↓
GG Results Object
    ↓
[05_visualization.R] plot_gg_demand(), plot_gg_revenue()
    ↓
ggplot2 Objects
    ↓
[06_output.R] write_pricing_output()
    ↓
Excel Workbook + Plot Files
```

---

## 6. Configuration System

### 6.1 Configuration Resolution

Path resolution follows this order:
1. Absolute path (if provided)
2. Relative to config file directory
3. Current working directory

### 6.2 Default Values

Defaults are applied in `apply_pricing_defaults()`:

```r
settings$project_name <- settings$project_name %||% "Pricing Analysis"
settings$currency_symbol <- settings$currency_symbol %||% "$"
settings$verbose <- as.logical(settings$verbose %||% TRUE)
```

The `%||%` operator returns the right-hand value if left is NULL or NA.

### 6.3 Type Coercion

Configuration values are coerced to appropriate types:
- Numeric: `as.numeric()`
- Logical: `as.logical()`
- Lists: Parse semicolon-separated strings

---

## 7. Extension Points

### 7.1 Adding New Analysis Methods

1. Create new file `R/0X_method_name.R`
2. Implement `run_method_name(data, config)` function
3. Add dispatch logic in `00_main.R`
4. Add config sheet handling in `01_config.R`
5. Add visualization in `05_visualization.R`
6. Add output handling in `06_output.R`

### 7.2 Adding Custom Visualizations

1. Create new plotting function in `05_visualization.R`
2. Add to `generate_pricing_plots()` dispatch
3. Return ggplot2 object

### 7.3 Adding Output Formats

1. Extend `write_pricing_output()` for new formats
2. Or create standalone export function (e.g., `export_pricing_csv()`)

---

## 8. Performance Considerations

### 8.1 Memory Usage

- Curve calculation uses 200 grid points (configurable)
- Bootstrap resampling creates B copies of indices
- Large datasets: Consider chunking for bootstrap

### 8.2 Computation Time

Typical execution times:
- Van Westendorp (n=500): < 1 second
- Gabor-Granger (n=500): < 1 second
- Bootstrap (1000 iterations): 5-10 seconds

### 8.3 Optimization Tips

- Reduce bootstrap iterations for exploration
- Use smaller grid for curve calculation
- Pre-filter data before analysis

---

## 9. Testing

### 9.1 Test Structure

```
tests/
├── testthat/
│   ├── test-config.R
│   ├── test-validation.R
│   ├── test-van_westendorp.R
│   ├── test-gabor_granger.R
│   └── test-integration.R
└── fixtures/
    ├── test_config.xlsx
    └── test_data.csv
```

### 9.2 Key Test Cases

**Configuration**:
- Valid config loads correctly
- Missing required fields throw errors
- Defaults are applied

**Validation**:
- Column existence checks work
- Invalid data is excluded
- Warnings are generated

**Van Westendorp**:
- Known data produces expected price points
- Monotonicity violations detected
- Bootstrap CIs calculated correctly

**Gabor-Granger**:
- Wide and long formats work
- Demand curve calculated correctly
- Optimal price found at revenue peak

### 9.3 Running Tests

```r
# Run all tests
testthat::test_dir("modules/pricing/tests/testthat")

# Run specific test file
testthat::test_file("modules/pricing/tests/testthat/test-van_westendorp.R")
```

---

## References

- Van Westendorp, P. (1976). NSS Price Sensitivity Meter (PSM) – A new approach to study consumer perception of price.
- Gabor, A., & Granger, C. W. J. (1966). Price as an indicator of quality: Report on an enquiry. Economica, 33(129), 43-70.
- Lyon, D. W. (2002). The price is right (or is it?). Marketing Research, 14(4), 8-13.
