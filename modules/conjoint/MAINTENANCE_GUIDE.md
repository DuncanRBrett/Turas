# Conjoint Module - Technical Maintenance Guide

**Version:** 2.0.1
**Date:** 2025-11-29
**Status:** Production

## Overview

This guide provides comprehensive technical documentation for maintaining and troubleshooting the Turas Conjoint Analysis module. It covers critical bug fixes, architecture decisions, common issues, and debugging strategies.

---

## Table of Contents

1. [Critical Bug Fixes (2025-11-26 to 2025-11-29)](#critical-bug-fixes)
2. [Architecture & Design Decisions](#architecture--design-decisions)
3. [Module Structure & File Dependencies](#module-structure--file-dependencies)
4. [Multi-Respondent Data Handling](#multi-respondent-data-handling)
5. [Model Estimation Methods](#model-estimation-methods)
6. [Common Issues & Solutions](#common-issues--solutions)
7. [Debugging Guide](#debugging-guide)
8. [Testing Strategy](#testing-strategy)
9. [Performance Considerations](#performance-considerations)
10. [Future Maintenance Notes](#future-maintenance-notes)

---

## Critical Bug Fixes

### 1. mlogit Hit Rate Calculation Bug (CRITICAL FIX)

**Date:** 2025-11-26
**Severity:** Critical
**Files:** `modules/conjoint/R/04_utilities.R` (lines 312-436)

#### Problem

Hit rate was stuck at ~34% (barely above 33% chance rate) despite good model fit (McFadden R² = 0.35+). The issue was misunderstanding the structure of `fitted(model, outcome = FALSE)` output from mlogit.

**Root Cause:**
- Code treated `fitted()` output as a long vector aligned with the long-format data
- **Actual behavior:** `fitted()` returns a **matrix** with dimensions (choice_sets × alternatives)
- Used incorrect 1D indexing which broke the alignment between predictions and actual choices

#### Solution

```r
# WRONG (previous code):
fitted_probs <- fitted(model, outcome = FALSE)  # Treated as vector
predicted <- tapply(fitted_probs, chid, which.max)  # Broken indexing

# CORRECT (fixed code):
fitted_mat <- fitted(model, outcome = FALSE)  # Recognize as matrix
# Dimension: nrow = number of choice sets, ncol = number of alternatives per set

# Verify it's a matrix
if (!is.matrix(fitted_mat)) {
  stop("fitted() did not return a matrix as expected")
}

# Get predicted choice per row (choice set)
predicted_choice <- max.col(fitted_mat, ties.method = "first")

# Get actual choice per choice set (compressed to per-set index)
actual_choice <- tapply(chosen, chid, function(x) {
  idx <- which(x)
  if (length(idx) == 0L) return(NA_integer_)
  if (length(idx) > 1L) {
    warning(sprintf("Choice set has %d chosen alternatives; using first", length(idx)))
    idx <- idx[1L]
  }
  idx
})

# Calculate hit rate
hit_rate <- sum(actual_choice == predicted_choice, na.rm = TRUE) / length(actual_choice)
```

#### Impact

- Hit rate improved from 34.5% → 65.2% (coffee example)
- Hit rate improved from 34.5% → 64.3% (noodle real data)
- Now correctly reflects model quality

#### Key Learnings

1. **Always verify data structure assumptions** - Use `str()`, `class()`, `dim()` to inspect
2. **mlogit `fitted()` with `outcome = FALSE`** returns choice-set-level probabilities as matrix
3. **Row sums should equal 1.0** - Use this as validation: `rowSums(fitted_mat)` should all be ~1.0

---

### 2. Multi-Respondent Validation Bug

**Date:** 2025-11-27
**Severity:** Critical
**Files:** `modules/conjoint/R/02_data.R` (lines 170-199)

#### Problem

Validation was failing for multi-respondent datasets with error:
```
[DATA] Error: Data validation failed → 5 choice sets do not have exactly 1 chosen alternative
```

When in reality, each respondent DID have exactly one chosen per choice set.

**Root Cause:**
- Validation grouped by `choice_set_column` only
- Multiple respondents can have the same `choice_set_id` values (1, 2, 3, 4, 5)
- Validation saw 2+ chosen alternatives for "choice set 1" (but from different respondents)

#### Solution

```r
# WRONG (previous code):
chosen_per_set <- data %>%
  group_by(!!sym(config$choice_set_column)) %>%
  summarise(n_chosen = sum(!!sym(config$chosen_column)))

# CORRECT (fixed code):
chosen_per_set <- data %>%
  group_by(!!sym(config$respondent_id_column), !!sym(config$choice_set_column)) %>%
  summarise(
    n_chosen = sum(!!sym(config$chosen_column)),
    .groups = "drop"
  )
```

#### Impact

- Validation now works correctly for multi-respondent data
- Error messages now show BOTH respondent_id and choice_set_id for problematic sets

---

### 3. clogit Hit Rate Calculation Bug

**Date:** 2025-11-27
**Severity:** Critical
**Files:** `modules/conjoint/R/04_utilities.R` (lines 438-469)

#### Problem

Hit rate showing 0.0% for clogit when it should be ~64%.

**Root Cause:**
- Same issue as validation - only looked at unique `choice_set_id` values (5 sets)
- Should look at unique `(respondent_id, choice_set_id)` combinations (1,725 sets)

#### Solution

```r
# WRONG (previous code):
unique_sets <- unique(data[[config$choice_set_column]])
for (cs in unique_sets) {
  cs_rows <- which(data[[config$choice_set_column]] == cs)
  # ... prediction logic
}

# CORRECT (fixed code):
unique_sets <- data %>%
  select(!!sym(config$respondent_id_column), !!sym(config$choice_set_column)) %>%
  distinct()

for (i in 1:nrow(unique_sets)) {
  resp <- unique_sets[[config$respondent_id_column]][i]
  cs <- unique_sets[[config$choice_set_column]][i]

  cs_rows <- which(
    data[[config$respondent_id_column]] == resp &
    data[[config$choice_set_column]] == cs
  )

  # ... prediction logic
}
```

---

### 4. Chance Rate Calculation Bug

**Date:** 2025-11-27
**Severity:** Minor
**Files:** `modules/conjoint/R/04_utilities.R` (lines 288-296)

#### Problem

Chance rate displayed as 0.1% instead of 33.3% (for 3-alternative choice sets).

**Root Cause:**
- Same grouping issue - calculated average alternatives across unique `choice_set_id` values only
- Should group by `(respondent_id, choice_set_id)`

#### Solution

```r
# CORRECT:
alts_per_set <- data %>%
  group_by(!!sym(config$respondent_id_column), !!sym(config$choice_set_column)) %>%
  summarise(n_alts = n(), .groups = "drop") %>%
  pull(n_alts) %>%
  mean()

chance_rate <- 1 / alts_per_set
```

---

### 5. mlogit Unique chid Bug

**Date:** 2025-11-27
**Severity:** Critical
**Files:** `modules/conjoint/R/03_estimation.R` (lines 187-194)

#### Problem

mlogit failed with error:
```
Error in dfidx(...): the two indexes don't define unique observations
```

**Root Cause:**
- `chid` was created from `choice_set_column` only (values 1-5)
- Multiple respondents with same choice_set_id → duplicate `(chid, alt)` pairs
- mlogit's dfidx requires unique observations identified by (chid, alt)

#### Solution

```r
# WRONG (previous code):
data$chid <- data[[config$choice_set_column]]

# CORRECT (fixed code):
# Create unique choice set ID combining respondent and choice_set
# This ensures (chid, alt) is unique across all observations
data$chid <- as.numeric(as.factor(
  paste(data[[config$respondent_id_column]],
        data[[config$choice_set_column]],
        sep = "_")
))
```

#### Key Points

- `chid` must uniquely identify each choice occasion across ALL respondents
- Use `paste()` + `as.factor()` + `as.numeric()` for robust unique ID generation
- The actual numeric values don't matter, just uniqueness

---

### 6. Market Simulator Blank Products Bug

**Date:** 2025-11-27
**Severity:** Medium
**Files:** `modules/conjoint/R/08_market_simulator.R` (lines 261-279)

#### Problem

When Products 4-5 were left blank (all attributes = reference level → utility = 0), they still showed market share. Products 1-3 didn't sum to 100%.

**Root Cause:**
- Formula: `exp(U_i) / sum(exp(U_all))`
- For blank products: `exp(0) = 1`
- Blank products contributed to denominator even though they shouldn't exist

#### Solution

```r
# WRONG (previous code):
share_formula <- sprintf("=%s%d/SUM(%s)*100",
                         col_letter, exp_utility_row,
                         exp_utility_range)

# CORRECT (fixed code):
# Use SUMIF to exclude products with Total Utility = 0
share_formula <- sprintf("=IF(%s%d=0,0,%s%d/SUMIF(%s,\"<>0\",%s)*100)",
                         col_letter, utility_row,     # If utility=0, return 0
                         col_letter, exp_utility_row, # Otherwise: exp(U_i)
                         utility_range,               # Check which utilities <> 0
                         exp_utility_range)           # Sum only those exp(U)
```

#### Impact

- Blank products now correctly show 0% market share
- Active products sum to 100%
- User can configure 1-5 products flexibly

---

### 7. GUI Module Loading Bug

**Date:** 2025-11-29
**Severity:** Critical
**Files:**
- `modules/conjoint/run_conjoint_gui.R` (lines 381-389, 410-419)
- `modules/conjoint/R/00_main.R` (lines 50-84)

#### Problem

When launching from Turas GUI, got error:
```
✗ Error: argument is of length zero
```

**Root Cause:**
- `getSrcDirectory()` returns empty string when sourced from Shiny
- `sys.frame(1)$ofile` doesn't work in reactive contexts
- `.conjoint_module_dir` ended up being invalid/empty
- `file.path(.conjoint_module_dir, "99_helpers.R")` caused "argument is of length zero"

#### Solution

**Part 1: GUI sets working directory (run_conjoint_gui.R)**
```r
# Set working directory to Turas root for module loading
old_wd <- getwd()
setwd(turas_root)

# Source main module file
source(file.path(turas_root, "modules/conjoint/R/00_main.R"))

# Restore working directory
setwd(old_wd)
```

**Part 2: Robust directory detection (00_main.R)**
```r
.conjoint_module_dir <- tryCatch({
  dir <- getSrcDirectory(function() {})
  if (is.null(dir) || length(dir) == 0 || dir == "") {
    # Fallback if getSrcDirectory doesn't work
    dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "")
  }
  if (is.null(dir) || length(dir) == 0 || dir == "") {
    # Check if we're in Turas directory structure
    wd <- getwd()
    if (file.exists(file.path(wd, "modules/conjoint/R"))) {
      # We're in Turas root
      dir <- file.path(wd, "modules/conjoint/R")
    } else if (basename(dirname(wd)) == "conjoint" && basename(wd) == "R") {
      # We're already in modules/conjoint/R
      dir <- wd
    } else if (basename(wd) == "conjoint") {
      # We're in modules/conjoint
      dir <- file.path(wd, "R")
    } else {
      # Last resort - assume working directory is Turas root
      dir <- file.path(wd, "modules/conjoint/R")
    }
  }
  dir
}, error = function(e) {
  file.path(getwd(), "modules/conjoint/R")
})

# Validate the directory exists
if (!dir.exists(.conjoint_module_dir)) {
  stop(sprintf(
    "Could not locate conjoint module directory. Expected: %s\nCurrent working directory: %s",
    .conjoint_module_dir, getwd()
  ))
}
```

**Part 3: Enhanced error handling (run_conjoint_gui.R)**
```r
}, error = function(e) {
  output_text <<- paste0(output_text, "\n\n✗ Error: ", e$message)
  output_text <<- paste0(output_text, "\n\nDebug info:")
  output_text <<- paste0(output_text, "\n  - Turas root: ", turas_root)
  output_text <<- paste0(output_text, "\n  - Config file: ", files$config_file)
  output_text <<- paste0(output_text, "\n  - Config exists: ", file.exists(files$config_file))
})
```

#### Key Learnings

1. **Shiny contexts break standard R sourcing assumptions**
2. **Always validate directory paths exist** before using in `file.path()`
3. **Provide multiple fallback strategies** for directory detection
4. **Set working directory explicitly** when sourcing from GUI contexts

---

## Architecture & Design Decisions

### 1. Why mlogit as Primary Method?

**Decision:** Use mlogit as primary estimation method, clogit as fallback

**Rationale:**
- **mlogit advantages:**
  - Industry standard for discrete choice modeling
  - Rich diagnostics (McFadden R², AIC, BIC)
  - Better handling of alternative-specific constants
  - Supports mixed logit extensions (future)

- **clogit advantages:**
  - More stable convergence for simple models
  - Faster computation
  - Part of base survival package (no extra dependencies)

**Implementation:**
```r
# Auto mode tries mlogit → clogit
estimate_auto_method <- function(data_list, config, verbose) {
  # Try mlogit first
  result <- tryCatch(
    estimate_with_mlogit(data_list, config, verbose),
    error = function(e) NULL
  )

  if (!is.null(result) && result$convergence$converged) {
    return(result)
  }

  # Fall back to clogit
  estimate_with_clogit(data_list, config, verbose)
}
```

---

### 2. Why Zero-Centered Utilities?

**Decision:** Zero-center part-worth utilities within each attribute

**Rationale:**
- **Interpretation:** Easier to understand relative preferences
- **Attribute importance:** Enables calculation as % of total utility range
- **Standard practice:** Aligns with Sawtooth, Conjointly, other tools
- **No information loss:** Only changes reference point, not relationships

**Implementation:**
```r
# Zero-centering formula
zero_centered_utility <- raw_utility - mean(all_utilities_for_attribute)

# Properties:
# 1. Sum(utilities_per_attribute) = 0
# 2. Differences preserved: U(A) - U(B) unchanged
# 3. Attribute importance = Range(U_attr) / Sum(Range(U_all))
```

---

### 3. Multi-Respondent Data Structure

**Key Principle:** `(respondent_id, choice_set_id)` uniquely identifies a choice occasion

**Why This Matters:**
- Multiple respondents can have same choice_set_id values (1, 2, 3, ...)
- Must ALWAYS group by BOTH columns for:
  - Validation (exactly 1 chosen per set)
  - Hit rate calculation (unique choice occasions)
  - Chance rate calculation (average alternatives per set)
  - mlogit chid creation (unique observations)

**Pattern:**
```r
# ALWAYS use both columns together
data %>%
  group_by(!!sym(respondent_id_column), !!sym(choice_set_column)) %>%
  # ... operations
```

---

### 4. File Organization Philosophy

**Principle:** Modular, numbered files with single responsibility

**Structure:**
```
00_main.R              - Entry point, workflow orchestration
01_config.R            - Configuration loading only
02_data.R              - Data loading and validation only
03_estimation.R        - Model estimation only
04_utilities.R         - Utilities calculation and diagnostics only
05_simulator.R         - Market share prediction functions
06_interactions.R      - Interaction effects (optional)
07_output.R            - Excel output generation
08_market_simulator.R  - Interactive Excel simulator
09_none_handling.R     - None option detection and handling
10_best_worst.R        - Best-worst scaling (optional)
11_hierarchical_bayes.R - HB framework (optional)
99_helpers.R           - Shared utility functions (loaded first)
```

**Benefits:**
- Easy to find relevant code
- Clear dependencies (numbered order)
- Optional features can be skipped
- Easy to test components independently

---

## Module Structure & File Dependencies

### Dependency Graph

```
99_helpers.R (loaded first - no dependencies)
    ↓
01_config.R (depends on: helpers)
    ↓
09_none_handling.R (depends on: helpers, config)
    ↓
02_data.R (depends on: helpers, config, none_handling)
    ↓
03_estimation.R (depends on: helpers, config, data structures)
    ↓
04_utilities.R (depends on: helpers, config, model results)
    ↓
05_simulator.R (depends on: utilities)
    ↓
08_market_simulator.R (depends on: utilities, simulator)
    ↓
07_output.R (depends on: all of the above)
    ↓
00_main.R (orchestrates all components)

Optional:
06_interactions.R (depends on: helpers, config, estimation)
10_best_worst.R (depends on: helpers, config, estimation)
11_hierarchical_bayes.R (depends on: helpers, config, estimation)
```

### Loading Order (Critical!)

From `00_main.R`:
```r
source(file.path(.conjoint_module_dir, "99_helpers.R"))      # FIRST - required by all
source(file.path(.conjoint_module_dir, "01_config.R"))
source(file.path(.conjoint_module_dir, "02_data.R"))
source(file.path(.conjoint_module_dir, "03_estimation.R"))
source(file.path(.conjoint_module_dir, "04_utilities.R"))
source(file.path(.conjoint_module_dir, "05_simulator.R"))
source(file.path(.conjoint_module_dir, "07_output.R"))
source(file.path(.conjoint_module_dir, "08_market_simulator.R"))
source(file.path(.conjoint_module_dir, "09_none_handling.R"))

# Optional - only load if files exist
if (file.exists(file.path(.conjoint_module_dir, "06_interactions.R"))) {
  source(file.path(.conjoint_module_dir, "06_interactions.R"))
}
```

**⚠️ WARNING:** Changing this order will break the module!

---

## Multi-Respondent Data Handling

### Key Concepts

1. **Respondent-level variation:**
   - Each respondent sees their own set of choice tasks
   - Choice set IDs may be reused across respondents (1, 2, 3, ...)

2. **Unique choice occasion:**
   - Identified by `(respondent_id, choice_set_id)` pair
   - NOT just `choice_set_id` alone!

3. **Data structure:**
```
resp_id | choice_set_id | alt_id | Price | Brand | chosen
--------|---------------|--------|-------|-------|-------
   1    |       1       |   1    |  $10  |   A   |   0
   1    |       1       |   2    |  $15  |   B   |   1     ← Resp 1, Set 1
   1    |       1       |   3    |  $20  |   A   |   0
   1    |       2       |   1    |  $10  |   B   |   1     ← Resp 1, Set 2
   1    |       2       |   2    |  $15  |   A   |   0
   2    |       1       |   1    |  $10  |   A   |   1     ← Resp 2, Set 1 (DIFFERENT from Resp 1, Set 1!)
   2    |       1       |   2    |  $15  |   B   |   0
```

### Critical Operations Requiring Both IDs

#### 1. Validation
```r
# Check exactly 1 chosen per choice set PER RESPONDENT
chosen_per_set <- data %>%
  group_by(respondent_id, choice_set_id) %>%
  summarise(n_chosen = sum(chosen))

invalid <- chosen_per_set %>% filter(n_chosen != 1)
```

#### 2. Hit Rate Calculation
```r
# Get unique choice occasions
unique_sets <- data %>%
  select(respondent_id, choice_set_id) %>%
  distinct()

# Calculate predictions for each unique (respondent, choice_set) pair
for (i in 1:nrow(unique_sets)) {
  resp <- unique_sets$respondent_id[i]
  cs <- unique_sets$choice_set_id[i]

  cs_rows <- which(data$respondent_id == resp & data$choice_set_id == cs)
  # ... prediction logic
}
```

#### 3. mlogit chid Creation
```r
# Create globally unique choice set identifier
data$chid <- as.numeric(as.factor(
  paste(data$respondent_id, data$choice_set_id, sep = "_")
))

# This ensures (chid, alt_id) is unique across ALL rows
```

#### 4. Chance Rate
```r
# Average number of alternatives per choice occasion
alts_per_set <- data %>%
  group_by(respondent_id, choice_set_id) %>%
  summarise(n_alts = n()) %>%
  pull(n_alts) %>%
  mean()

chance_rate <- 1 / alts_per_set
```

---

## Model Estimation Methods

### Method Comparison

| Feature | mlogit | clogit | OLS (rating) |
|---------|--------|--------|--------------|
| Data type | Choice | Choice | Rating |
| Speed | Medium | Fast | Fastest |
| Convergence | Can struggle | More robust | Always converges |
| Diagnostics | Rich (R², AIC) | Basic (R²) | R², RMSE |
| Extensions | Mixed logit | Limited | Interactions |
| Package | mlogit | survival | stats (base) |

### When Each Method Fails

**mlogit fails when:**
- Perfect separation (attribute perfectly predicts choice)
- Insufficient variation in chosen alternatives
- Collinearity between attributes
- Too few choice occasions per respondent
- Duplicate (chid, alt) pairs

**clogit fails when:**
- Perfect separation
- All alternatives chosen equally (no variation)
- Strata (choice sets) with only 1 alternative

**OLS fails when:**
- Perfect collinearity between predictors
- All ratings are identical (no variation)

### Debugging Estimation Failures

```r
# 1. Check for perfect separation
data %>%
  group_by(Brand, chosen) %>%
  summarise(n = n())
# Look for attributes where chosen=1 only for one level

# 2. Check variation in chosen alternatives
data %>%
  group_by(respondent_id, choice_set_id) %>%
  summarise(chosen_alt = which(chosen == 1)) %>%
  pull(chosen_alt) %>%
  table()
# All alternatives should be chosen at least sometimes

# 3. Check for duplicate observations (mlogit)
data %>%
  group_by(chid, alt_id) %>%
  filter(n() > 1)
# Should return 0 rows

# 4. Check choice set sizes
data %>%
  group_by(respondent_id, choice_set_id) %>%
  summarise(n_alts = n()) %>%
  pull(n_alts) %>%
  table()
# Should be consistent (usually 3-5 alternatives per set)
```

---

## Common Issues & Solutions

### Issue 1: "Argument is of length zero"

**Symptoms:**
- Error occurs during module loading
- Error in file.path() or similar function

**Causes:**
- Module directory detection failed
- NULL or empty variable passed to file.path()
- Working directory not set correctly

**Solutions:**
1. Check working directory: `getwd()` should be Turas root
2. Source 00_main.R with full path:
   ```r
   source("/full/path/to/Turas/modules/conjoint/R/00_main.R")
   ```
3. Set working directory first:
   ```r
   setwd("/path/to/Turas")
   source("modules/conjoint/R/00_main.R")
   ```

---

### Issue 2: "Indexes don't define unique observations" (mlogit)

**Symptoms:**
- Error from dfidx() when preparing mlogit data
- "the two indexes don't define unique observations"

**Cause:**
- Duplicate (chid, alt) pairs in data
- Usually happens with multi-respondent data when chid = choice_set_id only

**Solution:**
- Ensure chid combines respondent_id and choice_set_id:
  ```r
  data$chid <- as.numeric(as.factor(
    paste(data$respondent_id, data$choice_set_id, sep = "_")
  ))
  ```

**Debugging:**
```r
# Find duplicates
duplicates <- data %>%
  group_by(chid, alt_id) %>%
  filter(n() > 1)

print(duplicates)
```

---

### Issue 3: Hit Rate Too Low (<< Model R²)

**Symptoms:**
- Hit rate ~34% when R² = 0.35 (good fit)
- Hit rate barely above chance

**Causes:**
- **Most likely:** `fitted()` matrix misinterpretation (see Critical Bug Fix #1)
- Incorrect alignment between predictions and actual choices
- Using wrong choice set identifiers

**Solutions:**
1. Verify `fitted()` returns matrix: `class(fitted(model, outcome = FALSE))`
2. Check matrix dimensions: `dim(fitted_mat)` should be (n_choice_sets, n_alternatives)
3. Verify row sums = 1: `all(abs(rowSums(fitted_mat) - 1) < 1e-10)`
4. Use `max.col()` for row-wise max: `predicted <- max.col(fitted_mat)`

---

### Issue 4: Market Shares Don't Sum to 100%

**Symptoms:**
- Configured 3 products, shares sum to 67%
- Blank products showing non-zero share

**Cause:**
- Blank products have utility = 0 → exp(0) = 1
- Denominator includes blank products

**Solution:**
- Use SUMIF to exclude zero-utility products (see Critical Bug Fix #6)
```excel
=IF(utility=0, 0, exp(U_i)/SUMIF(utilities<>0, exp_utilities)*100)
```

---

### Issue 5: "Could not locate conjoint module directory"

**Symptoms:**
- Error on loading: "Could not locate conjoint module directory"
- Shows expected path and actual working directory

**Causes:**
- Working directory not set to Turas root
- Module files moved or deleted
- Incorrect directory structure

**Solutions:**
1. Set working directory: `setwd("/path/to/Turas")`
2. Verify files exist: `file.exists("modules/conjoint/R/00_main.R")`
3. Check directory structure:
   ```
   Turas/
   └── modules/
       └── conjoint/
           └── R/
               ├── 00_main.R
               ├── 01_config.R
               └── ...
   ```

---

## Debugging Guide

### 1. Enable Verbose Diagnostics

```r
# Turn on detailed hit rate diagnostics
options(conjoint.verbose_diagnostics = TRUE)

# Run analysis
results <- run_conjoint_analysis(config_file = "config.xlsx")
```

**Output:**
```
[HIT RATE CALCULATION]
Fitted matrix dimensions: 1725 choice sets × 3 alternatives
Row sums (should all be ~1.0): 1, 1, 1
Unique choice sets: 1725
Actual choices: [1, 2, 1, 3, 2, ...]
Predicted choices: [1, 2, 1, 3, 2, ...]
Total correct: 1109 / 1725 = 64.3%
```

---

### 2. Inspect Model Results

```r
# After estimation
model_result <- estimate_choice_model(data_list, config, verbose = TRUE)

# Check convergence
print(model_result$convergence)
# $converged: TRUE/FALSE
# $message: convergence details
# $iterations: number of iterations

# Check coefficients
print(model_result$coefficients)
# Named vector of estimated parameters

# Check standard errors
print(model_result$std_errors)

# Check vcov matrix
print(model_result$vcov)
```

---

### 3. Validate Data Structure

```r
# Load and validate data
data_list <- load_conjoint_data("data.csv", config, verbose = TRUE)

# Check structure
print(data_list$validation)
# $passed: TRUE/FALSE
# $errors: character vector of error messages
# $warnings: character vector of warnings

# Check choice set counts
print(data_list$n_choice_sets)  # Should match unique (respondent_id, choice_set_id)
print(data_list$n_respondents)  # Unique respondents

# Check for none option
print(data_list$has_none)
print(data_list$none_info)
```

---

### 4. Check fitted() Matrix Structure (mlogit)

```r
# After mlogit estimation
model <- model_result$model

# Get fitted probabilities
fitted_mat <- fitted(model, outcome = FALSE)

# Verify structure
print(class(fitted_mat))        # Should be "matrix"
print(dim(fitted_mat))          # Should be (n_choice_sets, n_alts)
print(head(rowSums(fitted_mat))) # Should all be ~1.0

# Check alignment
n_unique_sets <- data %>%
  select(respondent_id, choice_set_id) %>%
  distinct() %>%
  nrow()

print(nrow(fitted_mat) == n_unique_sets)  # Should be TRUE
```

---

### 5. Trace Hit Rate Calculation

```r
# Manual hit rate calculation for debugging
library(dplyr)

# Get unique choice sets
unique_sets <- data %>%
  select(respondent_id, choice_set_id) %>%
  distinct()

print(sprintf("Unique choice occasions: %d", nrow(unique_sets)))

# Get fitted matrix
fitted_mat <- fitted(model, outcome = FALSE)
print(sprintf("Fitted matrix rows: %d", nrow(fitted_mat)))

# Get predictions
predicted <- max.col(fitted_mat, ties.method = "first")
print(sprintf("Predictions: %s", paste(head(predicted), collapse = ", ")))

# Get actual choices
chid <- as.numeric(as.factor(paste(data$respondent_id, data$choice_set_id, sep = "_")))
chosen <- data$chosen

actual <- tapply(chosen, chid, function(x) which(x)[1])
print(sprintf("Actual choices: %s", paste(head(actual), collapse = ", ")))

# Calculate matches
matches <- predicted == actual
hit_rate <- sum(matches, na.rm = TRUE) / length(matches)
print(sprintf("Hit rate: %.1f%%", hit_rate * 100))
```

---

## Testing Strategy

### Unit Tests

Location: `modules/conjoint/tests/test_unit_tests.R`

**Run all tests:**
```r
source("modules/conjoint/tests/test_unit_tests.R")
run_all_tests()
```

**Run specific category:**
```r
run_tests_for_category("utilities")
```

**Categories:**
- Helpers (99_helpers.R functions)
- Config (configuration loading)
- Data (validation logic)
- None handling (detection algorithms)
- Estimation (model fitting)
- Utilities (utility calculation)
- Simulator (market share prediction)
- Output (Excel generation)

---

### Integration Tests

Location: `modules/conjoint/tests/test_integration.R`

**Run all integration tests:**
```r
source("modules/conjoint/tests/test_integration.R")
run_integration_tests()
```

**Test scenarios:**
1. End-to-end workflow (choice-based)
2. End-to-end workflow (rating-based)
3. Multi-respondent data
4. None option handling
5. Market simulator generation
6. Error handling (missing files, invalid config)
7. Robustness (different estimation methods)

---

### Regression Testing

**After fixing a bug, create a regression test:**

```r
test_mlogit_hit_rate_matrix_bug <- function() {
  # Setup test data
  data <- create_test_data_multi_respondent()
  config <- create_test_config()

  # Estimate model
  model_result <- estimate_with_mlogit(data, config, verbose = FALSE)

  # Calculate hit rate
  hit_rate <- calculate_hit_rate(model_result, data$data, config)

  # Test: Hit rate should be > 50% for this test data
  test_that("Hit rate reflects model quality", {
    expect_true(hit_rate > 0.5,
                info = sprintf("Hit rate %.1f%% is too low", hit_rate * 100))
  })

  # Test: fitted() should return matrix
  fitted_mat <- fitted(model_result$model, outcome = FALSE)
  test_that("fitted() returns matrix", {
    expect_true(is.matrix(fitted_mat))
  })

  # Test: Row sums should be ~1
  test_that("Probability matrix rows sum to 1", {
    expect_true(all(abs(rowSums(fitted_mat) - 1) < 1e-6))
  })
}
```

---

## Performance Considerations

### 1. Large Datasets (>10,000 choice sets)

**Considerations:**
- mlogit can be slow with large data
- Memory usage scales with n_choice_sets × n_alternatives

**Optimizations:**
```r
# Use clogit for large datasets
config$estimation_method <- "clogit"  # Faster than mlogit

# Reduce unnecessary calculations
config$include_diagnostics <- FALSE  # Skip some diagnostics
config$generate_market_simulator <- FALSE  # Skip if not needed
```

### 2. Many Attributes (>10 attributes)

**Considerations:**
- Model may not converge
- Perfect separation more likely
- Interpretation becomes difficult

**Solutions:**
```r
# 1. Use regularization (future enhancement)
# 2. Reduce attribute set through variable selection
# 3. Use hierarchical Bayes (future enhancement)
```

### 3. Memory Management

```r
# Clear large objects when done
rm(data_list, model_result)
gc()

# Don't store full model if not needed
config$store_full_model <- FALSE  # Future option
```

---

## Future Maintenance Notes

### Planned Enhancements

1. **Mixed Logit (Random Parameters)**
   - File: `12_mixed_logit.R`
   - Package: mlogit (supports random parameters)
   - Complexity: High
   - Benefits: Captures preference heterogeneity

2. **Individual-Level Utilities (HB)**
   - File: `11_hierarchical_bayes.R` (framework exists)
   - Package: bayesm or RSGHB
   - Complexity: Very High
   - Benefits: Respondent-specific utilities

3. **Attribute Interactions**
   - File: `06_interactions.R` (exists but basic)
   - Enhancement: Auto-detection of promising interactions
   - Complexity: Medium

4. **Visualization**
   - New file: `13_visualization.R`
   - Package: ggplot2
   - Features: Utility plots, importance charts, trade-off curves
   - Complexity: Medium

### Known Limitations

1. **No support for continuous attributes** (e.g., price as numeric)
   - Current: All attributes treated as factors
   - Future: Detect numeric attributes, fit linear/spline terms

2. **No holdout validation**
   - Current: Uses all data for estimation
   - Future: Train/test split, cross-validation

3. **No confidence intervals on importance scores**
   - Current: Point estimates only
   - Future: Bootstrap CIs on importance

4. **No support for partial profiles**
   - Current: Assumes full profiles shown
   - Future: Handle missing attribute combinations

### API Stability

**Stable (don't change):**
- `run_conjoint_analysis()` signature
- Config file structure (Settings, Attributes sheets)
- Data file format (respondent_id, choice_set_id, chosen columns)
- Output Excel structure (sheet names, key columns)

**Can change (internal):**
- Helper function names in 99_helpers.R
- Internal data structures between steps
- Diagnostic calculation details
- Excel formatting styles

---

## Contact & Support

**Module Maintainer:** Duncan Brett
**Last Updated:** 2025-11-29
**Version:** 2.0.1

**For Issues:**
1. Check this guide first
2. Review error message and debug info
3. Run relevant tests from `tests/` directory
4. Check GitHub issues/documentation

**For Enhancements:**
1. Review IMPLEMENTATION_STATUS.md for planned features
2. Check if feature exists but is disabled
3. Consider compatibility with existing code

---

## Appendix: Quick Reference

### File Locations

```
modules/conjoint/
├── R/                          # Source code
│   ├── 00_main.R              # Entry point
│   ├── 01_config.R            # Config loading
│   ├── 02_data.R              # Data validation
│   ├── 03_estimation.R        # Model estimation
│   ├── 04_utilities.R         # Utilities & diagnostics
│   ├── 05_simulator.R         # Prediction functions
│   ├── 07_output.R            # Excel output
│   ├── 08_market_simulator.R  # Interactive simulator
│   ├── 09_none_handling.R     # None option
│   └── 99_helpers.R           # Utilities
├── tests/                      # Test suite
│   ├── test_unit_tests.R
│   └── test_integration.R
├── examples/                   # Examples
│   ├── example_config.xlsx
│   ├── sample_cbc_data.csv
│   └── QUICK_START_GUIDE.md
├── run_conjoint_gui.R         # Shiny GUI
├── README.md                   # User documentation
├── IMPLEMENTATION_STATUS.md    # Feature status
├── MAINTENANCE_GUIDE.md        # This file
└── TUTORIAL.md                 # Step-by-step tutorial
```

### Key Functions

```r
# Main entry point
run_conjoint_analysis(config_file, data_file, output_file, verbose)

# Load configuration
config <- load_conjoint_config(config_file, verbose)

# Load and validate data
data_list <- load_conjoint_data(data_file, config, verbose)

# Estimate model
model_result <- estimate_choice_model(data_list, config, verbose)

# Calculate utilities
utilities <- calculate_utilities(model_result, config, verbose)

# Calculate importance
importance <- calculate_attribute_importance(utilities, config, verbose)

# Generate output
write_conjoint_output(utilities, importance, diagnostics,
                      model_result, config, data_info, output_file)
```

### Config File Template

```
Sheet: Settings
+------------------+----------+
| Setting          | Value    |
+------------------+----------+
| analysis_type    | choice   |
| choice_set_column| choice_set_id |
| chosen_column    | chosen   |
| respondent_id_column | resp_id |
| estimation_method| auto     |
+------------------+----------+

Sheet: Attributes
+--------------+-----------+------------------+
| AttributeName| NumLevels | LevelNames       |
+--------------+-----------+------------------+
| Price        | 3         | $10, $15, $20   |
| Brand        | 2         | A, B            |
| Feature      | 3         | Basic, Standard, Premium |
+--------------+-----------+------------------+
```

---

**End of Maintenance Guide**
