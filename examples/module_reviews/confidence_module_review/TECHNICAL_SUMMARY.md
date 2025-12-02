# TURAS CONFIDENCE MODULE - TECHNICAL SUMMARY

**Version:** 1.0.0-beta
**Date:** November 2025
**Status:** Ready for External Review

---

## TABLE OF CONTENTS

1. [Executive Summary](#executive-summary)
2. [Module Architecture](#module-architecture)
3. [Statistical Methodologies](#statistical-methodologies)
4. [Core Components](#core-components)
5. [Data Flow](#data-flow)
6. [Key Algorithms](#key-algorithms)
7. [Input/Output Specifications](#inputoutput-specifications)
8. [Error Handling & Validation](#error-handling--validation)
9. [Testing Coverage](#testing-coverage)
10. [Dependencies](#dependencies)
11. [Known Limitations](#known-limitations)

---

## 1. EXECUTIVE SUMMARY

The Turas Confidence Module is a standalone R package for calculating statistical confidence intervals on survey data. It provides four different statistical approaches (Normal approximation, Wilson score, Bootstrap, and Bayesian methods) for both proportions and means, with full support for weighted survey data.

### Key Features:
- **Multiple Statistical Methods**: 4 approaches for both proportions and means
- **Weighted Data Support**: Full integration with survey weights via effective sample size calculations
- **Question Limit**: Enforced maximum of 200 questions per analysis
- **International Support**: Configurable decimal separators (period or comma)
- **Comprehensive Output**: Multi-sheet Excel workbooks with methodology documentation

### Performance:
- **Line Count**: ~4,900 lines of R code
- **Files**: 8 core modules + UI + tests
- **Supported Formats**: CSV, XLSX input data
- **Processing Capacity**: Up to 200 questions per run

---

## 2. MODULE ARCHITECTURE

### Directory Structure

```
modules/confidence/
├── R/                          # Core R code (8 files)
│   ├── 00_main.R              # Main orchestration (~621 lines)
│   ├── 01_load_config.R       # Configuration loading (~611 lines)
│   ├── 02_load_data.R         # Data loading (~415 lines)
│   ├── 03_study_level.R       # DEFF calculations (~393 lines)
│   ├── 04_proportions.R       # Proportion CIs (~582 lines)
│   ├── 05_means.R             # Mean CIs (~590 lines)
│   ├── 07_output.R            # Excel output (~850 lines)
│   └── utils.R                 # Utilities (~424 lines)
├── run_confidence_gui.R        # Shiny GUI (~408 lines)
├── tests/                      # Test suites
│   ├── test_01_load_config.R  (~563 lines)
│   └── test_utils.R            (~548 lines)
└── examples/
    └── create_example_config.R (~360 lines)
```

### Design Principles

1. **Modular Design**: Each file handles a specific responsibility
2. **Sequential Processing**: Numbered files (00-07) indicate execution order
3. **Separation of Concerns**: Config, data, calculations, and output are separate
4. **Fail-Fast Validation**: Input validation before heavy processing
5. **Reproducibility**: Seed control for bootstrap/Bayesian methods

---

## 3. STATISTICAL METHODOLOGIES

### 3.1 Proportions (4 Methods)

#### **Method 1: Normal Approximation (Margin of Error)**
- **Formula**: `MOE = z * sqrt(p*(1-p)/n_eff)`
- **Use Case**: Large samples (n ≥ 30), proportions away from extremes (0.1 < p < 0.9)
- **Limitations**: Poor coverage for small n or extreme proportions
- **Implementation**: `04_proportions.R::calculate_proportion_ci_normal()`

#### **Method 2: Wilson Score Interval**
- **Formula**: Adjusted center point with asymmetric interval
- **Advantages**:
  - Better coverage for small samples
  - Handles extreme proportions (p < 0.1 or p > 0.9)
  - Never produces intervals outside [0,1]
- **Recommended**: Default method for most use cases
- **Reference**: Wilson (1927), Agresti & Coull (1998)
- **Implementation**: `04_proportions.R::calculate_proportion_ci_wilson()`

#### **Method 3: Bootstrap (Percentile Method)**
- **Algorithm**:
  1. Resample data with replacement B times (default B=5000)
  2. Calculate proportion for each resample (preserving weights)
  3. Use quantiles as confidence limits
- **Advantages**:
  - No distributional assumptions
  - Handles complex weighting naturally
  - Captures asymmetry in sampling distribution
- **Performance**: ~1-2 seconds for 5000 iterations on 1000 respondents
- **Implementation**: `04_proportions.R::bootstrap_proportion_ci()`

#### **Method 4: Bayesian Beta-Binomial**
- **Prior**: Beta(α₀, β₀) distribution
  - Uninformed: Beta(1,1) = Uniform(0,1)
  - Informed: From previous wave data (prior_mean, prior_n)
- **Posterior**: Beta(α₀ + successes, β₀ + failures)
- **Output**: Credible interval (not confidence interval)
- **Use Case**: Tracking studies with historical data
- **Implementation**: `04_proportions.R::credible_interval_proportion()`

### 3.2 Means (3 Methods)

#### **Method 1: t-Distribution**
- **Formula**: `CI = mean ± t(df) * SE` where `SE = SD / sqrt(n_eff)`
- **Degrees of Freedom**: Uses effective n for weighted data
- **Assumptions**: Approximate normality (relaxed for large n via CLT)
- **Implementation**: `05_means.R::calculate_mean_ci()`

#### **Method 2: Bootstrap**
- **Algorithm**: Same as proportions but calculates mean instead
- **Weighted Handling**: Preserves survey weights in resampling
- **Implementation**: `05_means.R::bootstrap_mean_ci()`

#### **Method 3: Bayesian Normal-Normal Conjugate**
- **Prior**: N(μ₀, σ₀²/n₀)
- **Posterior**: Precision-weighted average of prior and data
- **Update Formula**:
  ```
  τ_post = τ_prior + τ_data
  μ_post = (τ_prior * μ_prior + τ_data * μ_data) / τ_post
  ```
- **Implementation**: `05_means.R::credible_interval_mean()`

### 3.3 Weighting & Design Effects

#### **Effective Sample Size (Kish 1965)**
```r
n_eff = (Σw)² / Σw²
```
- **Scale-Invariant**: Normalizes by mean weight for numeric stability
- **Used For**: Standard errors, degrees of freedom
- **Implementation**: `03_study_level.R::calculate_effective_n()`

#### **Design Effect (DEFF)**
```r
DEFF = 1 + CV²  where CV = σ_w / μ_w
```
- **Interpretation**:
  - DEFF = 1.00: No precision loss
  - DEFF = 1.05-1.20: Modest loss (5-20%)
  - DEFF = 1.20-2.00: Moderate loss (20-50%)
  - DEFF > 2.00: Substantial loss (>50%)
- **Alternative**: DEFF = n_actual / n_eff
- **Implementation**: `03_study_level.R::calculate_deff()`

---

## 4. CORE COMPONENTS

### 4.1 Main Orchestration (`00_main.R`)

**Function**: `run_confidence_analysis(config_path, verbose, stop_on_warnings)`

**Workflow**:
1. Load configuration from Excel (enforces 200 question limit)
2. Load survey data (CSV or XLSX)
3. Calculate study-level statistics (DEFF, effective n)
4. Process each question:
   - Dispatch to proportion or mean handler
   - Calculate requested CI methods
   - Collect warnings
5. Generate Excel output with 7 sheets
6. Report timing and summary statistics

**Error Handling**:
- Wrapped in try-catch blocks at each step
- Errors stop execution with diagnostic messages
- Warnings collected and reported but don't stop execution
- Optional `stop_on_warnings` parameter for strict mode

### 4.2 Configuration Loader (`01_load_config.R`)

**Sheets Loaded**:
1. **File_Paths** (required):
   - Data_File
   - Output_File
   - Weight_Variable (optional)

2. **Study_Settings** (required):
   - Calculate_Effective_N (Y/N)
   - Multiple_Comparison_Adjustment (Y/N)
   - Multiple_Comparison_Method (Bonferroni/Holm/FDR)
   - Bootstrap_Iterations (1000-10000)
   - Confidence_Level (0.90/0.95/0.99)
   - Decimal_Separator (. or ,)

3. **Question_Analysis** (required, max 200 rows):
   - Question_ID
   - Statistic_Type (proportion/mean/nps)
   - Categories (for proportions)
   - Run_MOE, Run_Bootstrap, Run_Credible (Y/N)
   - Prior parameters (optional)

**Validation**:
- **Question Limit Check**: Hard limit of 200 questions enforced in `load_question_analysis_sheet()`
- **Required Fields**: All parameters must be present
- **Value Ranges**: Confidence levels, bootstrap iterations validated
- **At Least One Method**: Each question must specify at least one CI method
- **Implementation**: `01_load_config.R::validate_config()`

### 4.3 Data Loader (`02_load_data.R`)

**Supported Formats**:
- CSV (using `data.table::fread` if available, 10x faster than base R)
- XLSX/XLS (using `readxl`)

**Validation**:
- Required questions present in data
- Weight variable exists and is numeric
- No negative weights (design weights must be ≥ 0)
- Warnings for zero or NA weights

**Performance Optimization**:
- Uses `data.table::fread()` for CSV files when available
- Validates only required columns (not entire dataset)

### 4.4 Output Generator (`07_output.R`)

**Excel Workbook Structure** (7 sheets):

1. **Summary**: High-level overview, analysis date, question counts
2. **Study_Level**: DEFF, effective n, weight statistics, warnings
3. **Proportions_Detail**: All proportion results with all requested CIs
4. **Means_Detail**: All mean results with all requested CIs
5. **Methodology**: Statistical formulas and references
6. **Warnings**: Data quality issues and calculation warnings
7. **Inputs**: Configuration summary for reproducibility

**Decimal Separator Handling**:
- Internal calculations always use period (R standard)
- Output formatted with user-specified separator (. or ,)
- Applied via Excel number formatting codes
- **Note**: Actual display depends on Excel's regional settings

---

## 5. DATA FLOW

```
┌─────────────────────┐
│  confidence_config  │
│     .xlsx           │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  01_load_config.R   │
│  - Validate         │
│  - 200 limit check  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐     ┌─────────────────┐
│   survey_data.csv   │────▶│ 02_load_data.R  │
│   or .xlsx          │     │ - Validate      │
└─────────────────────┘     └────────┬────────┘
                                     │
                                     ▼
                            ┌────────────────────┐
                            │ 03_study_level.R   │
                            │ - Calculate DEFF   │
                            │ - Effective n      │
                            └─────────┬──────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │                                   │
                    ▼                                   ▼
        ┌─────────────────────┐           ┌──────────────────────┐
        │  04_proportions.R   │           │    05_means.R        │
        │  - MOE              │           │    - t-dist          │
        │  - Wilson           │           │    - Bootstrap       │
        │  - Bootstrap        │           │    - Bayesian        │
        │  - Bayesian         │           │                      │
        └──────────┬──────────┘           └──────────┬───────────┘
                   │                                 │
                   └──────────────┬──────────────────┘
                                  │
                                  ▼
                         ┌────────────────────┐
                         │   07_output.R      │
                         │   - 7-sheet Excel  │
                         │   - Formatting     │
                         └─────────┬──────────┘
                                   │
                                   ▼
                         ┌────────────────────┐
                         │ confidence_results │
                         │     .xlsx          │
                         └────────────────────┘
```

---

## 6. KEY ALGORITHMS

### 6.1 Effective Sample Size Calculation

**File**: `03_study_level.R`
**Function**: `calculate_effective_n(weights)`

```r
# Pseudocode
calculate_effective_n <- function(weights) {
  # Remove NA, infinite, and zero/negative weights
  weights <- weights[valid & positive & finite]

  # Handle edge case: all weights = 1
  if (all(weights == 1)) return(length(weights))

  # Scale-safe calculation (prevents overflow)
  mean_weight <- mean(weights)
  w_scaled <- weights / mean_weight

  n_effective <- (sum(w_scaled)^2) / sum(w_scaled^2)

  return(round(n_effective))
}
```

**Numeric Stability**: Normalizes by mean weight to prevent overflow with large weights

### 6.2 Bootstrap Resampling

**File**: `04_proportions.R`, `05_means.R`
**Function**: `bootstrap_proportion_ci()`, `bootstrap_mean_ci()`

```r
# Pseudocode
bootstrap_ci <- function(data, weights, B, conf_level) {
  n <- length(data)
  boot_results <- numeric(B)

  for (i in 1:B) {
    # Resample indices with replacement
    boot_idx <- sample(1:n, size = n, replace = TRUE)
    boot_data <- data[boot_idx]
    boot_weights <- weights[boot_idx]

    # Calculate statistic (proportion or mean)
    boot_results[i] <- weighted_statistic(boot_data, boot_weights)
  }

  # Percentile method: use quantiles as CI
  alpha <- 1 - conf_level
  lower <- quantile(boot_results, alpha/2)
  upper <- quantile(boot_results, 1 - alpha/2)

  return(c(lower, upper))
}
```

**Key Detail**: Resamples indices (not values) to preserve data-weight correspondence

### 6.3 Bayesian Beta-Binomial Update

**File**: `04_proportions.R`
**Function**: `credible_interval_proportion()`

```r
# Pseudocode
credible_interval <- function(p, n, conf_level, prior_mean, prior_n) {
  # Convert prior to Beta parameters
  if (uninformed) {
    alpha_prior <- 1
    beta_prior <- 1
  } else {
    alpha_prior <- prior_mean * prior_n
    beta_prior <- (1 - prior_mean) * prior_n
  }

  # Observed data
  successes <- round(p * n)
  failures <- n - successes

  # Posterior update (conjugate)
  alpha_post <- alpha_prior + successes
  beta_post <- beta_prior + failures

  # Credible interval from posterior quantiles
  alpha_level <- 1 - conf_level
  lower <- qbeta(alpha_level/2, alpha_post, beta_post)
  upper <- qbeta(1 - alpha_level/2, alpha_post, beta_post)

  return(c(lower, upper))
}
```

**Conjugacy**: Beta prior + Binomial likelihood = Beta posterior (closed-form update)

---

## 7. INPUT/OUTPUT SPECIFICATIONS

### 7.1 Input: Configuration File

**File Format**: Excel (.xlsx)
**Required Sheets**: 3 (File_Paths, Study_Settings, Question_Analysis)
**Maximum Questions**: 200 (enforced)

**Example Question Row**:
```
Question_ID: Q1_Awareness
Statistic_Type: proportion
Categories: 1
Run_MOE: Y
Run_Wilson: Y
Run_Bootstrap: N
Run_Credible: N
Prior_Mean: NA
Prior_N: NA
```

### 7.2 Input: Survey Data

**File Formats**: CSV, XLSX, XLS
**Structure**:
- Row = Respondent
- Column = Question or weight variable
- Missing data: NA or blank cells

**Example**:
```csv
Respondent_ID,Q1_Awareness,Q2_Satisfaction,weight
1,1,8,1.2
2,0,7,0.9
3,1,9,1.1
```

### 7.3 Output: Excel Workbook

**File Format**: Excel (.xlsx)
**Sheets**: 7 (see Section 4.4)
**Decimal Formatting**: Configurable (. or ,)

**Example Proportions Row**:
```
Question_ID: Q1_Awareness
Proportion: 0.67
Sample_Size: 1000
Effective_n: 920
MOE_Normal_Lower: 0.64
MOE_Normal_Upper: 0.70
Wilson_Lower: 0.64
Wilson_Upper: 0.69
```

---

## 8. ERROR HANDLING & VALIDATION

### 8.1 Input Validation

**Configuration Validation** (`01_load_config.R::validate_config()`):
- ✓ File paths exist and are accessible
- ✓ Confidence level in {0.90, 0.95, 0.99}
- ✓ Bootstrap iterations in [1000, 10000]
- ✓ Decimal separator in {'.', ','}
- ✓ **Question count ≤ 200** (hard limit)
- ✓ At least one method selected per question
- ✓ Prior parameters valid if Bayesian method selected

**Data Validation** (`02_load_data.R::validate_survey_data()`):
- ✓ Data file exists and is readable
- ✓ Required questions present in data
- ✓ Weight variable exists (if specified)
- ✓ Weights are numeric and non-negative
- ✓ Sufficient non-missing data per question

### 8.2 Runtime Checks

**Proportion Calculations**:
- Warning: Small sample (n < 30)
- Warning: Extreme proportion (p < 0.1 or p > 0.9)
- Warning: All values missing for a question
- Error: No valid data after removing NAs

**Mean Calculations**:
- Warning: Small sample (n < 30)
- Warning: High skewness (may affect t-distribution validity)
- Error: Fewer than 2 valid observations

**Weighting**:
- Warning: High DEFF (> 2.0)
- Warning: High weight CV (> 0.30)
- Warning: Extreme weight range (max/min > 10:1)
- Error: All weights zero or negative

### 8.3 Error Messages

All error messages include:
1. Context (which question, which step)
2. Specific problem description
3. Suggested remediation (when applicable)

**Example**:
```
ERROR: Question Q5_NPS: Failed to calculate mean CI
Reason: Fewer than 2 valid observations after removing NAs
Suggestion: Check for missing data or exclude this question
```

---

## 9. TESTING COVERAGE

### 9.1 Unit Tests

**File**: `tests/test_utils.R` (548 lines)

**Functions Tested**:
- `format_decimal()`: Decimal separator formatting
- `validate_proportion()`: Proportion range [0,1]
- `validate_sample_size()`: Positive integers
- `validate_conf_level()`: Valid confidence levels
- `validate_question_limit()`: 200 question limit
- `check_small_sample()`: Sample size warnings
- `check_extreme_proportion()`: Extreme value warnings
- `parse_codes()`: Category code parsing
- `safe_divide()`: Division by zero handling

**Coverage**: All utility functions have unit tests with edge cases

### 9.2 Integration Tests

**File**: `tests/test_01_load_config.R` (563 lines)

**Scenarios Tested**:
1. **Valid Configuration**: Loads successfully
2. **Validation**: Config validation catches errors
3. **Question Limit**: 201 questions rejected with clear error
4. **Missing Sheets**: Detects missing required sheets
5. **Invalid Settings**: Catches invalid confidence level (0.85)
6. **Invalid Decimal Separator**: Catches invalid separator (';')
7. **No Methods Selected**: Catches questions with all methods = N

**Test Methodology**:
- Creates temporary Excel files programmatically
- Tests positive and negative cases
- Verifies error messages contain expected keywords
- Cleans up test files after execution

### 9.3 Test Execution

```r
# Run all tests
source("tests/test_utils.R")
run_all_tests()

source("tests/test_01_load_config.R")
run_all_tests()
```

**Expected Output**: ✓ ALL TESTS PASSED!

---

## 10. DEPENDENCIES

### 10.1 Required Packages

| Package | Purpose | Min Version | Critical? |
|---------|---------|-------------|-----------|
| `readxl` | Read Excel config files | Any | Yes |
| `openxlsx` | Write Excel output | Any | Yes |
| `shiny` | GUI interface | Any | For GUI only |
| `shinyFiles` | File browser widget | Any | For GUI only |

### 10.2 Optional Packages

| Package | Purpose | Fallback |
|---------|---------|----------|
| `data.table` | Fast CSV loading (10x faster) | `read.csv()` |
| `dplyr` | Data frame manipulation | Base R equivalents |

### 10.3 Base R Functions Used

**Statistical**:
- `mean()`, `sd()`, `weighted.mean()`
- `qnorm()`, `qt()`, `qbeta()`
- `quantile()`, `sample()`

**Data Manipulation**:
- `data.frame()`, `rbind()`, `do.call()`
- `setNames()`, `as.list()`

**File I/O**:
- `read.csv()`, `write.csv()`
- `file.exists()`, `dir.exists()`

---

## 11. KNOWN LIMITATIONS

### 11.1 Design Limitations

1. **Question Limit**: Hard maximum of 200 questions per analysis
   - **Reason**: Performance and output file size management
   - **Workaround**: Split into multiple runs

2. **No Subgroup Analysis**: Cannot calculate CIs by demographic groups
   - **Status**: Planned for Phase 2
   - **Workaround**: Create separate config files per subgroup

3. **No Multiple Comparison Adjustment**: Setting exists but not implemented
   - **Status**: Planned for Phase 2 (Bonferroni, Holm, FDR)

4. **No NPS Calculations**: Statistic type exists but not implemented
   - **Status**: Planned for Phase 2

5. **No Banner Columns**: Cannot output in crosstab banner format
   - **Status**: Planned for Phase 2

### 11.2 Statistical Limitations

1. **Bootstrap Speed**: 10,000 iterations on 200 questions ≈ 5-10 minutes
   - **Mitigation**: Default to 5,000 iterations (good for most cases)

2. **Normal Approximation Accuracy**: Poor for n < 30 or extreme proportions
   - **Mitigation**: Wilson score automatically recommended for extremes

3. **t-Distribution Assumption**: Assumes approximate normality for means
   - **Mitigation**: Bootstrap provides distribution-free alternative

4. **Effective-n Approximation**: Kish formula is approximate
   - **Note**: Exact DEFF varies by question; we use study-level estimate

### 11.3 Technical Limitations

1. **Excel Regional Settings**: Decimal separator display depends on user's Excel locale
   - **Mitigation**: Documentation explains this limitation

2. **Large Data Files**: CSV files > 1GB may be slow
   - **Mitigation**: `data.table::fread()` used when available

3. **Non-Interactive Execution**: Bootstrap progress not shown in batch mode
   - **Status**: Acceptable for current use case

### 11.4 Future Enhancements

**Phase 2 Roadmap**:
- [ ] Multiple comparison adjustments (Bonferroni, Holm, FDR)
- [ ] Subgroup analysis (by demographics)
- [ ] NPS score calculations
- [ ] Banner column output format
- [ ] Parallel processing for bootstrap
- [ ] Progress bars for long-running analyses
- [ ] Cached intermediate results for reanalysis

---

## APPENDIX: STATISTICAL REFERENCES

1. **Kish, L. (1965)**. *Survey Sampling*. Wiley.
   - Effective sample size formula

2. **Wilson, E. B. (1927)**. Probable inference, the law of succession, and statistical inference. *JASA*, 22(158), 209-212.
   - Wilson score interval

3. **Agresti, A., & Coull, B. A. (1998)**. Approximate is better than "exact" for interval estimation of binomial proportions. *The American Statistician*, 52(2), 119-126.
   - Wilson score advantages

4. **Efron, B., & Tibshirani, R. J. (1994)**. *An Introduction to the Bootstrap*. CRC press.
   - Bootstrap methodology

5. **Gelman, A., et al. (2013)**. *Bayesian Data Analysis* (3rd ed.). Chapman and Hall/CRC.
   - Bayesian conjugate priors

---

## DOCUMENT REVISION HISTORY

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-30 | Turas Team | Initial version for external review |

---

**END OF TECHNICAL SUMMARY**
