# Technical Documentation: Turas Pricing Module

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Module Structure](#2-module-structure)
3. [Core Components](#3-core-components)
4. [Mathematical Methods](#4-mathematical-methods)
5. [Data Flow](#5-data-flow)
6. [Configuration System](#6-configuration-system)
7. [HTML Report Architecture](#7-html-report-architecture)
8. [Simulator Architecture](#8-simulator-architecture)
9. [Extension Points](#9-extension-points)
10. [Performance Considerations](#10-performance-considerations)
11. [Testing](#11-testing)

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
│   ├── 00_main.R               # Entry point and orchestration
│   ├── 00_guard.R              # TRS guard layer (pre-flight validation)
│   ├── 01_config.R             # Configuration management (autodetect heading)
│   ├── 02_validation.R         # Data loading and validation
│   ├── 03_van_westendorp.R     # Van Westendorp PSM implementation
│   ├── 04_gabor_granger.R      # Gabor-Granger implementation
│   ├── 05_visualization.R      # Plot generation
│   ├── 06_output.R             # Excel output generation
│   ├── 07_wtp_distribution.R   # Willingness-to-pay analysis
│   ├── 08_competitive_scenarios.R  # Competitive scenario analysis
│   ├── 09_price_volume_optimisation.R  # Price-volume optimisation
│   ├── 10_segmentation.R       # Segment analysis
│   ├── 11_price_ladder.R       # Good/Better/Best tier generation
│   ├── 12_recommendation_synthesis.R  # Multi-method synthesis
│   └── 13_monadic.R            # Monadic price testing (logistic regression)
├── lib/
│   ├── html_report/            # HTML report generation (4-layer architecture)
│   │   ├── 01_data_transformer.R   # Results → HTML-optimised data structure
│   │   ├── 02_table_builder.R      # HTML table generation
│   │   ├── 03_page_builder.R       # Full page assembly with meta tags
│   │   └── 04_chart_builder.R      # SVG chart generation
│   ├── simulator/              # Interactive simulator dashboard
│   │   ├── simulator_builder.R     # R builder (assembles self-contained HTML)
│   │   ├── css/simulator_styles.css
│   │   └── js/                     # Client-side JavaScript
│   │       ├── simulator_core.js       # Demand interpolation, sliders
│   │       ├── scenario_manager.js     # Preset/battle mode
│   │       ├── chart_renderer.js       # Interactive SVG charts
│   │       └── export_png.js           # Canvas PNG export
│   └── generate_config_templates.R # Config template generator
├── tests/testthat/             # 83 tests across 10 test files
├── run_pricing_gui.R           # Shiny GUI launcher
└── docs/                       # Documentation
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

### 4.3 Monadic Price Testing

#### Logistic Regression Model

For binary purchase intent Y and price P:

```
P(Y=1 | P) = 1 / (1 + exp(-(β₀ + β₁P)))
```

Fitted using `glm(intent ~ price, family = binomial(link = "logit"))`.

**Log-logistic variant**: Uses `log(price)` as predictor instead of raw price, useful when the price-intent relationship is more linear on the log scale.

#### Model Diagnostics

**McFadden's Pseudo-R²**:
```
R²_McFadden = 1 - (residual_deviance / null_deviance)
```

Typical values for pricing data: 0.05-0.25. Values > 0.20 indicate excellent fit.

#### Demand Curve

Predicted purchase probability at n evenly-spaced points across the observed price range:

```
predicted_intent(P) = predict(model, newdata = P, type = "response")
```

#### Revenue and Profit Curves

```
Revenue_Index(P) = P × predicted_intent(P)
Profit_Index(P) = (P - unit_cost) × predicted_intent(P)
```

#### Optimal Price

```
Optimal_Revenue_Price = argmax_P { Revenue_Index(P) }
Optimal_Profit_Price  = argmax_P { Profit_Index(P) }
```

#### Arc Elasticity

Sampled at regular intervals (every ~5% of the price range):

```
E_arc = ((Q2 - Q1) / ((Q2 + Q1) / 2)) / ((P2 - P1) / ((P2 + P1) / 2))
```

#### Bootstrap Confidence Intervals

For each bootstrap iteration b = 1 to B:
1. Resample n observations with replacement
2. Skip degenerate samples (all same intent)
3. Fit logistic model on resampled data
4. Record optimal price and demand curve predictions

Calculate percentile CIs from successful iterations:
```
CI_lower = quantile(boot_results, α/2, na.rm = TRUE)
CI_upper = quantile(boot_results, 1 - α/2, na.rm = TRUE)
```

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

### 5.3 Monadic Pipeline

```
Raw Data
    ↓
[13_monadic.R] run_monadic_analysis()
    - Extract price and intent columns
    - Convert scale intent to binary (top-box coding)
    - Remove NAs, compute observed intent by price cell
    ↓
[13_monadic.R] glm(intents ~ prices, family = binomial)
    - Fit logistic (or log-logistic) regression
    - Compute model diagnostics (pseudo-R², AIC, p-values)
    ↓
[13_monadic.R] predict() across price range
    - Generate demand curve (n_points predictions)
    - Calculate revenue and profit indices
    - Find optimal prices (revenue and profit)
    ↓
[13_monadic.R] compute_monadic_elasticity()
    - Arc elasticity at sampled intervals
    ↓
[13_monadic.R] monadic_bootstrap_ci()  (if requested)
    - Bootstrap CIs for optimal price and demand curve
    ↓
Monadic Results Object
    ↓
[lib/html_report/] transform_pricing_for_html() → build_pricing_report()
    ↓
Self-contained HTML Report
    ↓
[lib/simulator/] build_pricing_simulator()
    ↓
Interactive Simulator Dashboard (HTML)
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

## 7. HTML Report Architecture

The HTML report follows a 4-layer architecture pattern consistent with other Turas modules (confidence, tabs).

### 7.1 Layer 1: Data Transformer (`01_data_transformer.R`)

Converts analysis results into an HTML-optimised structure. Each method's results are normalised into a common format with:
- Chart data (arrays suitable for SVG rendering)
- Table data (pre-formatted for HTML table generation)
- Callout text (plain-English interpretations)
- Meta information (method used, sample size, confidence level)

**Entry point**: `transform_pricing_for_html(pricing_results, config)`

### 7.2 Layer 2: Table Builder (`02_table_builder.R`)

Generates styled HTML tables for:
- VW price points (with CIs if available)
- GG demand curve
- Monadic model summary and demand curve
- Segment comparison
- Recommendation summary

### 7.3 Layer 3: Page Builder (`03_page_builder.R`)

Assembles the complete HTML page:
- Meta tags for Report Hub integration (`<meta name="turas-report-type" content="pricing">`)
- Embedded CSS with brand colour token replacement
- Tab navigation JavaScript
- Self-contained (no external dependencies)

### 7.4 Layer 4: Chart Builder (`04_chart_builder.R`)

Generates pure SVG charts:
- VW cumulative distribution curves (4 lines + intersection markers)
- GG demand curve with revenue overlay
- Monadic logistic curve with CI band
- Segment comparison forest plot
- Price ladder tier visualisation

---

## 8. Simulator Architecture

The simulator is a self-contained HTML dashboard built by `lib/simulator/simulator_builder.R`.

### 8.1 Build Process

The R builder function:
1. Reads CSS from `css/simulator_styles.css`
2. Reads JS from `js/*.js` (4 files)
3. Serialises demand curves, segments, and preset scenarios to JSON
4. Embeds everything into a single HTML file with `<script>` and `<style>` tags

### 8.2 JavaScript Modules

- **simulator_core.js**: Demand curve interpolation (monotone-preserving cubic), slider event handling, real-time metric calculations
- **scenario_manager.js**: Save/load/delete scenarios, preset card rendering, battle mode comparison logic
- **chart_renderer.js**: SVG-based interactive charts with draggable price markers
- **export_png.js**: Canvas-based PNG capture with brand watermark

### 8.3 Data Embedding

Analysis results are embedded as a `PRICING_DATA` JSON constant:
```javascript
const PRICING_DATA = {
  demand_curve: [...],        // price, predicted_intent, revenue_index
  segments: { ... },          // segment-level demand curves
  preset_scenarios: [...],    // from config Simulator sheet
  optimal_prices: { ... },    // revenue and profit optima
  currency: "$",
  brand_colour: "#1e3a5f"
};
```

---

## 9. Extension Points

### 9.1 Adding New Analysis Methods

1. Create new file `R/0X_method_name.R`
2. Implement `run_method_name(data, config)` function
3. Add dispatch logic in `00_main.R`
4. Add config sheet handling in `01_config.R`
5. Add visualization in `05_visualization.R`
6. Add output handling in `06_output.R`

### 9.2 Adding Custom Visualizations

1. Create new plotting function in `05_visualization.R`
2. Add to `generate_pricing_plots()` dispatch
3. Return ggplot2 object

### 9.3 Adding Output Formats

1. Extend `write_pricing_output()` for new formats
2. Or create standalone export function (e.g., `export_pricing_csv()`)

---

## 10. Performance Considerations

### 10.1 Memory Usage

- Curve calculation uses 200 grid points (configurable)
- Bootstrap resampling creates B copies of indices
- Large datasets: Consider chunking for bootstrap

### 10.2 Computation Time

Typical execution times:
- Van Westendorp (n=500): < 1 second
- Gabor-Granger (n=500): < 1 second
- Monadic (n=500): < 1 second (model fitting)
- Bootstrap (1000 iterations): 5-10 seconds
- HTML report generation: 1-3 seconds
- Simulator assembly: 1-2 seconds

### 10.3 Optimization Tips

- Reduce bootstrap iterations for exploration
- Use smaller grid for curve calculation
- Pre-filter data before analysis

---

## 11. Testing

### 11.1 Test Structure

```
tests/testthat/
├── setup.R                 # Test infrastructure, sources all module files,
│                           # provides synthetic data generators
├── test_config.R           # Configuration loading (13 tests)
├── test_guard.R            # Pre-flight validation (24 tests)
├── test_van_westendorp.R   # VW analysis (12 tests, 6 skip w/o PSM package)
├── test_gabor_granger.R    # GG analysis (9 tests)
├── test_monadic.R          # Monadic analysis (9 tests)
├── test_segmentation.R     # Segment analysis (5 tests, 3 skip w/o PSM)
├── test_price_ladder.R     # Tier generation (6 tests)
├── test_synthesis.R        # Recommendation synthesis (10 tests)
└── test_integration.R      # End-to-end workflows (8 tests, 3 skip w/o PSM)
```

**Total: 83 tests** (12 skipped when `pricesensitivitymeter` package not installed)

### 11.2 Key Test Cases

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

**Monadic**:
- Logistic and log-logistic models fit correctly
- Demand curve bounded [0, 1]
- Revenue and profit optimisation works
- Bootstrap CIs handle degenerate samples
- Scale intent type with top-box coding
- Elasticity classification correct

### 11.3 Running Tests

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
- Lipovetsky, S. (2006). Van Westendorp price sensitivity in statistical modeling. International Journal of Operations and Quantitative Management, 12(2).
- Lyon, D. W. (2002). The price is right (or is it?). Marketing Research, 14(4), 8-13.
