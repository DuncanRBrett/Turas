# Turas Categorical Key Driver Module - Final Development Specification

**Version:** 2.0 (Production-Ready)  
**Date:** December 2024  
**Target Delivery:** Q1 2025  
**Development Tool:** Claude Code  

---

## Executive Summary

This specification defines a Turas module for key driver analysis when outcomes are categorical rather than continuous. It complements the existing continuous key driver module by handling binary, ordinal, and nominal categorical outcomes using appropriate logistic regression methods.

**Design Philosophy:** This module is designed for practical applied research, not academic exercises. It prioritises:
- Clear, actionable outputs over statistical completeness
- Graceful handling of messy real-world data (missing values, small samples)
- Plain-English interpretation alongside statistical metrics
- Sensible defaults that work for 90% of use cases

**Use Cases:**
- Employee satisfaction (High/Medium/Low)
- Customer retention (Retained/Churned)
- Product preference (Brand A/B/C/D)
- Alumni employment success (Satisfied/Neutral/Dissatisfied)
- Patient outcomes (Improved/Stable/Declined)

---

## Module Overview

### Module Name
`categorical_keydriver` or `catdriver`

### Module Location
`Turas/modules/catdriver/`

### File Structure
```
modules/catdriver/
├── R/
│   ├── 00_main.R              # Main entry point & orchestration
│   ├── 01_config.R            # Configuration loader & validator
│   ├── 02_validation.R        # Data loading & validation
│   ├── 03_preprocessing.R     # Variable type detection & dummy coding
│   ├── 04_analysis.R          # Core logistic regression methods
│   ├── 05_importance.R        # Variable importance calculations
│   ├── 06_output.R            # Excel output generation
│   └── 07_utilities.R         # Helper functions
├── tests/
│   ├── test_data/
│   │   ├── binary_outcome.csv
│   │   ├── ordinal_outcome.csv
│   │   ├── nominal_outcome.csv
│   │   └── messy_data.csv     # Test data with missing values
│   ├── test_config_binary.xlsx
│   ├── test_config_ordinal.xlsx
│   └── test_config_nominal.xlsx
├── docs/
│   └── USER_MANUAL.md
├── examples/
│   ├── example_binary.R
│   ├── example_ordinal.R
│   └── example_nominal.R
└── README.md
```

---

## Technical Requirements

### Core R Packages

**Essential (will fail without these):**
```r
# Regression models
MASS          # ordinal logistic (polr)
nnet          # multinomial logistic (multinom)

# Variable importance & diagnostics
car           # Anova Type II tests, GVIF

# Data manipulation
dplyr         # data wrangling
tidyr         # data reshaping

# Excel I/O
openxlsx      # Excel read/write (consistent with existing module)

# Optional data formats
haven         # SPSS/Stata (optional, with graceful degradation)
```

**Package Rationale:**
- `MASS::polr` - Industry standard for ordinal logistic, maintained by R Core
- `nnet::multinom` - Standard for multinomial logistic, stable and well-documented
- `car::Anova` - Type II Wald tests, handles factor variables properly, includes GVIF

**Note on Brant test:** The `brant` package for testing proportional odds is sometimes archived from CRAN. Implement a fallback using score tests if unavailable, or provide practical guidance without formal test (see Proportional Odds section below).

---

## Statistical Methods

### Method 1: Binary Logistic Regression
**When:** Outcome has exactly 2 categories (e.g., Success/Failure)

**Implementation:**
```r
model <- glm(outcome ~ predictor1 + predictor2 + ...,
             family = binomial(link = "logit"),
             data = data)
```

**Outputs:**
- Odds ratios with 95% CI
- Predicted probabilities
- Classification metrics (accuracy, sensitivity, specificity)
- AUC if sample size permits

---

### Method 2: Ordinal Logistic Regression
**When:** Outcome has 3+ ordered categories (e.g., Low < Medium < High)

**Implementation:**
```r
library(MASS)
model <- polr(ordered_outcome ~ predictor1 + predictor2 + ...,
              data = data,
              Hess = TRUE,  # Required for standard errors
              method = "logistic")  # Proportional odds model
```

**Proportional Odds Assumption - Practical Approach:**

The formal Brant test almost always rejects with large samples (N > 500) even when violations are trivial. Use this practical guidance instead:

1. **Compare odds ratios across thresholds**: If cumulative ORs differ by less than 25% across thresholds, proceed with ordinal model
2. **Visual check**: Plot predicted probabilities - if lines are roughly parallel, assumption is reasonable
3. **If substantially violated**: Warn user and suggest multinomial as alternative, but don't block analysis

```r
# Practical check: compare ORs at different thresholds
# If max(OR)/min(OR) < 1.5 for same predictor, assumption acceptable
```

**Outputs:**
- Cumulative odds ratios
- Predicted probabilities for each outcome level
- Threshold coefficients

---

### Method 3: Multinomial Logistic Regression
**When:** Outcome has 3+ unordered categories (e.g., Product A/B/C/D)

**Implementation:**
```r
library(nnet)
model <- multinom(nominal_outcome ~ predictor1 + predictor2 + ...,
                  data = data,
                  trace = FALSE,   # Suppress iteration output
                  maxit = 500)     # Increase iterations for convergence
```

**Convergence handling:**
```r
# Check convergence explicitly
if (!model$convergence) {
  warning("Model did not fully converge. Consider:
           - Reducing number of predictors
           - Collapsing outcome categories
           - Checking for separation")
}
```

**Outputs:**
- Relative risk ratios (vs reference category)
- Predicted probabilities for each category
- Confusion matrix

---

## Variable Importance Calculation

### Primary Method: Wald Chi-Square Tests

```r
library(car)
importance <- Anova(model, type = "II")  # Type II for unbalanced designs
```

**Importance Metrics:**
1. **Chi-Square Value**: Test statistic for each predictor
2. **P-value**: Statistical significance
3. **Relative Importance %**: `100 * ChiSq / sum(ChiSq)`
4. **Importance Rank**: Ordered by chi-square

**Factor-level aggregation:** `car::Anova` automatically groups dummy variables from the same factor, providing a single importance score per original variable.

---

## Handling Missing Data

### Missing Data Strategy

Real-world datasets commonly have 10-40% missing data. The module must handle this gracefully.

**Default behaviour: Complete case analysis with clear reporting**

```r
# Report missing data clearly
missing_summary <- data.frame(
  Variable = names(data),
  N_Missing = sapply(data, function(x) sum(is.na(x))),
  Pct_Missing = sapply(data, function(x) 100 * mean(is.na(x)))
)
```

**Configuration options:**

| Setting | Values | Default | Description |
|---------|--------|---------|-------------|
| missing_threshold | 0-100 | 50 | Warn if any variable exceeds this % missing |
| missing_action | complete/warn/stop | warn | What to do when missing data detected |

**Output requirements:**
1. **Always report** original N, complete cases N, and % excluded
2. **Per-variable missing rates** in diagnostics sheet
3. **Pattern analysis**: Flag if missingness appears non-random (e.g., correlated with outcome)

**Warning message example:**
```
Missing data detected:
- Original sample: 500 respondents
- Complete cases: 387 respondents (77%)
- Excluded: 113 respondents (23%)

Variables with highest missingness:
- income_bracket: 18% missing
- tenure_years: 12% missing

Note: Analysis uses complete cases only. If missingness is related to the 
outcome, results may be biased. Consider investigating missing data patterns.
```

**Future enhancement (not v1.0):** Optional multiple imputation using `mice` package.

---

## Handling Small Samples

### Sample Size Requirements

**Minimum thresholds:**

| Model Type | Absolute Minimum | Recommended | Events per Predictor |
|------------|------------------|-------------|---------------------|
| Binary | 30 complete cases | 100+ | 10-15 per predictor term |
| Ordinal | 50 complete cases | 150+ | 10 per predictor per threshold |
| Nominal | 50 complete cases | 200+ | 10 per outcome category |

**"Events per predictor" for binary outcomes:**
- Count minority class observations (not total N)
- Example: 200 respondents, 30 churned → 30 events
- With 5 predictors → 6 events per predictor (marginal)

**Small cell handling:**

```r
# Detect small cells in cross-tabulation
check_cell_counts <- function(data, outcome_var, predictor_vars) {
  warnings <- list()
  
  for (pred in predictor_vars) {
    tab <- table(data[[pred]], data[[outcome_var]])
    small_cells <- which(tab < 5, arr.ind = TRUE)
    
    if (nrow(small_cells) > 0) {
      warnings[[pred]] <- list(
        cells = small_cells,
        suggestion = "Consider collapsing categories"
      )
    }
  }
  
  return(warnings)
}
```

**Category collapsing suggestions:**

When a predictor category has < 10 observations:
1. **Suggest specific collapse**: "Campus 'Online' has only 8 observations. Consider combining with another category or excluding."
2. **Provide code snippet**: Show how to collapse in config or pre-processing
3. **Don't block analysis** unless truly impossible to estimate

**Separation detection (binary logistic):**
```r
# Check for perfect/quasi-complete separation
# Signs: coefficients > 10, standard errors > 100, or convergence warnings
check_separation <- function(model) {
  coefs <- coef(model)
  ses <- sqrt(diag(vcov(model)))
  
  if (any(abs(coefs) > 10) || any(ses > 100)) {
    warning("Possible separation detected. Some predictor categories 
             may perfectly predict the outcome. Consider:
             - Collapsing rare categories
             - Removing problematic predictors
             - Using Firth's penalized likelihood (not implemented)")
  }
}
```

---

## Effect Size Interpretation Guidelines

### Odds Ratio Interpretation (Include in Output)

| Odds Ratio | Interpretation | Practical Significance |
|------------|----------------|------------------------|
| 0.9 - 1.1 | Negligible | No meaningful difference |
| 0.67 - 0.9 or 1.1 - 1.5 | Small | Minor difference, may not be actionable |
| 0.5 - 0.67 or 1.5 - 2.0 | Medium | Meaningful difference worth attention |
| 0.33 - 0.5 or 2.0 - 3.0 | Large | Substantial difference, high priority |
| < 0.33 or > 3.0 | Very Large | Major difference, investigate thoroughly |

**Include this table in the Excel output and USER_MANUAL.**

### Importance Score Interpretation

| Importance % | Interpretation |
|--------------|----------------|
| > 30% | Dominant driver - primary focus |
| 15-30% | Major driver - significant influence |
| 5-15% | Moderate driver - worth considering |
| < 5% | Minor driver - limited impact |

---

## Plain-English Summary Output

**Requirement: Auto-generate executive summary**

The module MUST produce a plain-English summary that non-statisticians can understand. Include in both console output and Excel output (separate "Executive Summary" sheet).

**Template:**
```
KEY DRIVER ANALYSIS SUMMARY
===========================

Outcome: [outcome_label] ([n_categories] categories: [list categories])
Sample: [n_complete] respondents (of [n_original] total, [pct_complete]% complete)
Model: [model_type] Logistic Regression

TOP DRIVERS (by importance):

1. [Driver 1 Label] ([importance_pct]% of explained variation)
   → [Best category] respondents are [OR]x more likely to report [high outcome]
     compared to [reference category] respondents.
   
2. [Driver 2 Label] ([importance_pct]% of explained variation)
   → [Description of effect]

3. [Driver 3 Label] ([importance_pct]% of explained variation)
   → [Description of effect]

KEY INSIGHTS:
• [Auto-generated insight about strongest effect]
• [Auto-generated insight about practical implications]

MODEL FIT:
• The model explains [pseudo_r2_pct]% of variation in [outcome_label]
• [interpretation: "This is a [good/moderate/limited] fit"]

CAUTIONS:
• [Any warnings about data quality, small cells, etc.]
```

**Example output:**
```
KEY DRIVER ANALYSIS SUMMARY
===========================

Outcome: Employment Satisfaction (3 categories: Low, Neutral, High)
Sample: 387 respondents (of 425 total, 91% complete)
Model: Ordinal Logistic Regression

TOP DRIVERS (by importance):

1. Academic Grade (38% of explained variation)
   → Grade A students are 4.2x more likely to report High satisfaction
     compared to Grade D students.
   
2. Campus Location (24% of explained variation)
   → Durban campus students show highest satisfaction (65% High),
     while Online students show lowest (51% High).

3. Course Type (19% of explained variation)
   → B.Com students outperform B.SocSci students on satisfaction.

KEY INSIGHTS:
• Academic performance is the dominant predictor - interventions targeting
  struggling students may have the greatest impact on satisfaction.
• Online delivery shows notably lower satisfaction - investigate support
  services for distance learners.

MODEL FIT:
• The model explains 34% of variation in Employment Satisfaction
• This is a good fit for social science research.

CAUTIONS:
• Small cell count: Only 8 observations for Online + Grade D combination.
• 9% of respondents excluded due to missing data.
```

---

## Configuration File Specification

### Excel Configuration Structure

**Sheet 1: Settings**
| Setting | Value | Required | Default | Description |
|---------|-------|----------|---------|-------------|
| analysis_name | string | No | "Key Driver Analysis" | Descriptive name |
| data_file | path | Yes | - | Path to data file (CSV/XLSX/SAV/DTA) |
| output_file | path | Yes | - | Path for results Excel file |
| outcome_type | auto/binary/ordinal/nominal | No | auto | Override auto-detection |
| reference_category | string | No | first alphabetically | For binary/nominal reference |
| min_sample_size | integer | No | 30 | Minimum complete cases required |
| confidence_level | numeric | No | 0.95 | For confidence intervals |
| missing_threshold | numeric | No | 50 | Warn if any variable exceeds % missing |
| detailed_output | TRUE/FALSE | No | TRUE | If FALSE, produce simplified 4-sheet output |

**Sheet 2: Variables**
| VariableName | Type | Label | Order |
|--------------|------|-------|-------|
| satisfaction | Outcome | Employment Satisfaction | Low;Neutral;High |
| grade | Driver | Academic Grade | D;C;B;A |
| campus | Driver | Campus Location | |
| course_type | Driver | Course Type | |
| employment_field | Driver | Employment Field | |

**Column Definitions:**
- **VariableName**: Exact column name in data file
- **Type**: `Outcome` (exactly 1) or `Driver` (1 or more)
- **Label**: Human-readable name for output
- **Order**: 
  - For ordinal variables: semicolon-separated ordered categories (e.g., `Low;Medium;High`)
  - For nominal variables: leave blank or specify reference category first
  - Auto-detected if blank but can be overridden

---

## Auto-Detection Logic

### Outcome Type Detection

```r
detect_outcome_type <- function(outcome_var, order_spec = NULL) {
  
  n_unique <- length(unique(na.omit(outcome_var)))
  
  # Binary
  if (n_unique == 2) {
    return(list(type = "binary", method = "binomial_logistic"))
  }
  
  # Multi-category
  if (n_unique >= 3) {
    
    # User specified order?
    if (!is.null(order_spec) && order_spec != "") {
      return(list(type = "ordinal", method = "proportional_odds"))
    }
    
    # Try to infer ordering from data
    if (is.ordered(outcome_var)) {
      return(list(type = "ordinal", method = "proportional_odds"))
    }
    
    # Check if numeric with natural ordering (1,2,3,4,5)
    if (is.numeric(outcome_var)) {
      warning("Numeric outcome detected. Treating as ordinal. 
               Specify order in Variables sheet or set outcome_type='nominal' to override.")
      return(list(type = "ordinal", method = "proportional_odds"))
    }
    
    # Default to nominal
    return(list(type = "nominal", method = "multinomial_logistic"))
  }
  
  stop("Outcome variable must have at least 2 categories")
}
```

### Predictor Type Detection

```r
detect_predictor_type <- function(predictor_var, order_spec = NULL) {
  
  n_unique <- length(unique(na.omit(predictor_var)))
  
  # Continuous (treat as-is in model)
  if (is.numeric(predictor_var) && n_unique > 10) {
    return(list(type = "continuous", needs_dummy = FALSE))
  }
  
  # Binary categorical
  if (n_unique == 2) {
    return(list(type = "binary_categorical", needs_dummy = TRUE, n_dummies = 1))
  }
  
  # Multi-category
  if (n_unique >= 3 && n_unique <= 20) {
    is_ordered <- !is.null(order_spec) && order_spec != ""
    return(list(
      type = ifelse(is_ordered, "ordinal", "nominal"),
      needs_dummy = TRUE,
      n_dummies = n_unique - 1
    ))
  }
  
  # Too many categories
  if (n_unique > 20) {
    warning("Predictor has ", n_unique, " categories. 
             Consider grouping or treating as continuous.")
    return(list(type = "high_cardinality", needs_dummy = TRUE, n_dummies = n_unique - 1))
  }
}
```

---

## Dummy Variable Coding

### Strategy: Treatment (Reference) Coding

**Default reference category:**
- First alphabetically (if nominal)
- Lowest value (if ordinal)
- User-specified via Order column (reference category listed first)

**Example:**
```
Original: Campus = {Cape Town, Durban, Johannesburg, Online}
Reference: Cape Town (first alphabetically)

Dummy variables created:
- campus_Durban (1 if Durban, 0 otherwise)
- campus_Johannesburg (1 if Johannesburg, 0 otherwise)
- campus_Online (1 if Online, 0 otherwise)
```

### Naming Convention
`{original_var}_{category_name}`

**Special characters handling:**
- Spaces → underscores: `"Cape Town"` → `Cape_Town`
- Remove special chars: `"B.SocSci"` → `BSocSci`
- Limit length: Max 32 chars per variable name

---

## Output Specification

### Excel Workbook Structure

**Standard output (detailed_output = TRUE): 6 sheets**

| Sheet | Name | Purpose |
|-------|------|---------|
| 1 | Executive Summary | Plain-English summary for non-statisticians |
| 2 | Importance Summary | Driver rankings with statistics |
| 3 | Factor Patterns | Category-level breakdowns for each driver |
| 4 | Model Summary | Fit statistics and diagnostics |
| 5 | Odds Ratios | Detailed ORs with confidence intervals |
| 6 | Diagnostics | Data quality checks and warnings |

**Simplified output (detailed_output = FALSE): 4 sheets**
- Executive Summary
- Importance Summary
- Factor Patterns
- Model Summary

**Removed from original spec:** Correlation Matrix sheet (Sheet 7) - practitioners rarely use this and it adds complexity without practical value.

---

#### Sheet 1: Executive Summary
Contains the plain-English summary described above, formatted for easy reading and copy-paste into reports.

---

#### Sheet 2: Importance Summary
| Factor | Label | Importance % | Chi-Square | P-Value | Sig. | Effect Size |
|--------|-------|--------------|------------|---------|------|-------------|
| grade | Academic Grade | 38% | 45.2 | <0.001 | *** | Large |
| campus | Campus Location | 24% | 28.3 | <0.001 | *** | Medium |
| course_type | Course Type | 19% | 22.1 | <0.001 | *** | Medium |
| field | Employment Field | 19% | 21.8 | <0.001 | *** | Medium |

**Formatting:**
- Header: Bold, blue background (#4472C4)
- Significance stars: *** p<0.001, ** p<0.01, * p<0.05, ns p≥0.05
- Effect Size column: Based on largest OR within factor (Small/Medium/Large/Very Large)
- Sort by Importance % descending

---

#### Sheet 3: Factor Patterns
**For each driver, show category breakdown:**

**Example: Campus**
| Category | N | % of Total | Low | Neutral | High | OR vs Ref | 95% CI | Effect |
|----------|---|------------|-----|---------|------|-----------|--------|--------|
| Cape Town (ref) | 120 | 30% | 12% | 30% | 58% | 1.00 | - | - |
| Durban | 150 | 37.5% | 10% | 25% | 65% | 1.35 | 0.89-2.05 | Small |
| Johannesburg | 80 | 20% | 15% | 23% | 62% | 1.18 | 0.72-1.93 | Negligible |
| Online | 50 | 12.5% | 28% | 21% | 51% | 0.75 | 0.43-1.31 | Small |

**Formatting:**
- Reference category highlighted in light gray
- Effect column uses interpretation guidelines
- Confidence intervals that cross 1.0 shown in italics (not significant)

---

#### Sheet 4: Model Summary
| Metric | Value | Interpretation |
|--------|-------|----------------|
| Model Type | Ordinal Logistic Regression | |
| Outcome Variable | satisfaction (Low < Neutral < High) | |
| Number of Predictors | 4 factors (12 terms) | |
| Original Sample Size | 425 | |
| Complete Cases Used | 387 (91%) | Good - minimal data loss |
| McFadden Pseudo-R² | 0.342 | Good model fit |
| AIC | 678.3 | |
| Log-Likelihood | -327.2 | |
| LR Test vs Null | χ²(12) = 182.4, p < 0.001 | Model significantly better than null |

**Pseudo-R² interpretation (include in sheet):**
| McFadden R² | Interpretation |
|-------------|----------------|
| 0.2 - 0.4 | Good fit |
| 0.4+ | Excellent fit |
| < 0.2 | Limited explanatory power |

**For Ordinal Models:** Include proportional odds check result (practical assessment, not just p-value)

**For Binary Models:** Include AUC, sensitivity, specificity at optimal threshold

---

#### Sheet 5: Odds Ratios (Detailed)
| Factor | Comparison | Odds Ratio | 95% CI Lower | 95% CI Upper | P-Value | Effect |
|--------|------------|------------|--------------|--------------|---------|--------|
| Grade | A vs D (ref) | 4.23 | 2.87 | 6.24 | <0.001 | Very Large |
| Grade | B vs D (ref) | 2.15 | 1.52 | 3.04 | <0.001 | Large |
| Grade | C vs D (ref) | 1.42 | 1.01 | 2.00 | 0.044 | Small |
| Campus | Durban vs Cape Town (ref) | 1.35 | 0.89 | 2.05 | 0.158 | ns |
| Campus | Johannesburg vs Cape Town (ref) | 1.18 | 0.72 | 1.93 | 0.512 | ns |
| Campus | Online vs Cape Town (ref) | 0.75 | 0.43 | 1.31 | 0.311 | ns |

---

#### Sheet 6: Diagnostics
| Check | Status | Details | Action Required |
|-------|--------|---------|-----------------|
| Sample size | ✓ PASS | N=387 (min 30 required) | None |
| Complete cases | ✓ PASS | 91% complete (387/425) | None |
| Missing data pattern | ✓ PASS | Missingness appears random | None |
| Multicollinearity | ✓ PASS | Max GVIF^(1/2df) = 1.8 | None |
| Small cells | ⚠ WARNING | Online+Grade D = 8 obs | Consider collapsing |
| Proportional odds | ✓ PASS | OR variation < 25% | None |
| Model convergence | ✓ PASS | Converged normally | None |

**Missing Data Detail (sub-table):**
| Variable | N Missing | % Missing |
|----------|-----------|-----------|
| income_bracket | 25 | 5.9% |
| tenure_years | 13 | 3.1% |
| grade | 0 | 0.0% |
| campus | 0 | 0.0% |

---

## Function Signatures

### Main Entry Point

```r
#' Run Categorical Key Driver Analysis
#'
#' @param config_file Path to configuration Excel file
#' @param data_file Optional override for data file path
#' @param output_file Optional override for output file path
#' @param outcome_type Optional override: "auto", "binary", "ordinal", or "nominal"
#'
#' @return List containing:
#'   - model: Fitted regression model object
#'   - importance: Data frame with importance metrics
#'   - summary: Plain-English summary text
#'   - diagnostics: List of diagnostic checks
#'   - config: Processed configuration
#'
#' @examples
#' results <- run_categorical_keydriver("my_config.xlsx")
#' print(results$summary)  # Plain-English summary
#' print(results$importance)  # Statistical details
#'
#' @export
run_categorical_keydriver <- function(config_file, 
                                      data_file = NULL,
                                      output_file = NULL,
                                      outcome_type = "auto") {
  # Implementation
}

# Alias for convenience
catdriver <- run_categorical_keydriver
```

---

## Error Handling & Validation

### Required Validations

**Configuration Stage:**
- ✓ Config file exists and is readable
- ✓ Required sheets present (Settings, Variables)
- ✓ Exactly 1 outcome variable specified
- ✓ At least 1 driver variable specified
- ✓ Data file path valid
- ✓ Output file path writable

**Data Stage:**
- ✓ All variables exist in data
- ✓ Outcome has 2+ categories
- ✓ Minimum sample size met (default: 30 complete cases)
- ✓ No zero-variance predictors after listwise deletion
- ⚠ Warn if missing data exceeds threshold
- ⚠ Warn if events-per-predictor below 10

**Modeling Stage:**
- ✓ Model converges
- ⚠ Warn if perfect separation detected (binary)
- ⚠ Warn if proportional odds substantially violated (ordinal)
- ⚠ Warn if high multicollinearity (GVIF^(1/2df) > 2.5)
- ⚠ Warn if small cell counts (< 5 observations)

### Error Messages

**Principle: Clear, actionable, non-technical where possible**

```r
# Good error message
stop("Cannot run analysis: Only 18 complete cases available (minimum 30 required).

     Missing data by variable:
     - income_bracket: 45% missing
     - satisfaction: 12% missing
     
     Suggestions:
     1. Check if income_bracket is essential - removing it would give 89 complete cases
     2. Investigate why data is missing - is it systematic?
     3. Consider imputing missing values before analysis")

# Bad error message  
stop("Error in polr(): insufficient observations")
```

---

## Development Phases

### Phase 1: Core Functionality (Binary Focus)
**Deliverables:**
- [ ] File structure created
- [ ] Config loading & validation (01_config.R)
- [ ] Data loading with missing data reporting (02_validation.R)
- [ ] Preprocessing & dummy coding (03_preprocessing.R)
- [ ] Binary logistic regression (04_analysis.R)
- [ ] Importance calculation (05_importance.R)
- [ ] Basic Excel output (06_output.R - 4 sheets)
- [ ] Plain-English summary generation
- [ ] End-to-end test with binary outcome

**Success criteria:** Complete binary analysis with clear missing data handling

---

### Phase 2: Extended Methods
**Deliverables:**
- [ ] Ordinal logistic regression with practical PO check
- [ ] Multinomial logistic regression with convergence handling
- [ ] Auto-detection logic
- [ ] Full Excel output (all 6 sheets)
- [ ] Small sample warnings and suggestions
- [ ] Category collapsing recommendations

**Success criteria:** All three regression types working with appropriate guidance

---

### Phase 3: Polish & Documentation
**Deliverables:**
- [ ] USER_MANUAL.md (comprehensive, practical focus)
- [ ] README.md (quick start)
- [ ] Example datasets including messy data
- [ ] Worked examples with interpretation
- [ ] Error message refinement
- [ ] Final testing with edge cases

**Success criteria:** Production-ready module a practitioner can use without training

---

## Testing Requirements

### Test Scenarios

**Must handle gracefully:**
1. Clean data, binary outcome (happy path)
2. Clean data, ordinal outcome
3. Clean data, nominal outcome
4. 20% missing data, scattered randomly
5. 40% missing on single variable
6. Small sample (N=50)
7. Small cells (< 5 in some combinations)
8. Perfect separation in binary outcome
9. High collinearity between predictors
10. Non-convergence in multinomial

### Test Data Requirements

Create test datasets that reflect real-world messiness:
- `clean_binary.csv` - 500 rows, no missing, binary outcome
- `clean_ordinal.csv` - 400 rows, no missing, 3-level ordinal outcome
- `clean_nominal.csv` - 600 rows, no missing, 4-level nominal outcome
- `messy_realistic.csv` - 300 rows, 15-25% missing scattered, some small cells

---

## Success Metrics

### Technical Metrics
- All test scenarios pass without crashing
- Clear, actionable output for all scenarios
- Performance: < 30 seconds for 5,000 rows

### User Experience Metrics
- Non-statistician can interpret Executive Summary
- User can run analysis without reading documentation
- Warnings provide specific, actionable guidance

### Practical Research Metrics
- Output suitable for inclusion in research reports
- Effect size interpretations align with discipline norms
- Missing data handling matches best practices

---

## References

### Statistical References
- Agresti, A. (2012). *Categorical Data Analysis* (3rd ed.). Wiley.
- Hosmer, D. W., Lemeshow, S., & Sturdivant, R. X. (2013). *Applied Logistic Regression* (3rd ed.). Wiley.
- Peduzzi, P., et al. (1996). A simulation study of the number of events per variable in logistic regression analysis. *Journal of Clinical Epidemiology*, 49(12), 1373-1379.

### R Package Documentation
- `MASS::polr` - [CRAN Documentation](https://cran.r-project.org/package=MASS)
- `nnet::multinom` - [CRAN Documentation](https://cran.r-project.org/package=nnet)
- `car::Anova` - [CRAN Documentation](https://cran.r-project.org/package=car)

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | Dec 2024 | Initial specification | Claude (Sonnet) |
| 2.0 | Dec 2024 | Practical revisions: missing data, small samples, plain-English output, effect size guidelines | Claude (Opus) / Duncan |

---

**END OF SPECIFICATION**
