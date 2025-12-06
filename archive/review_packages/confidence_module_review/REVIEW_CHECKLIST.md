# CONFIDENCE MODULE - EXTERNAL REVIEW CHECKLIST

**Purpose**: Guide external reviewers through a comprehensive code review to identify bugs, edge cases, and potential improvements.

**Review Scope**: ~4,900 lines of R code across 8 core modules + UI + tests

---

## REVIEW PRIORITIES

### 🔴 CRITICAL (Must Review)
1. Statistical algorithm correctness
2. Question limit enforcement (200 max)
3. Input validation and error handling
4. Weight handling and effective sample size calculations

### 🟡 IMPORTANT (Should Review)
5. Edge cases and boundary conditions
6. Data type conversions and numeric stability
7. Missing data handling
8. Performance bottlenecks

### 🟢 NICE TO HAVE (Optional)
9. Code style and maintainability
10. Documentation completeness
11. Test coverage gaps

---

## SECTION 1: STATISTICAL CORRECTNESS

### 1.1 Effective Sample Size (CRITICAL)

**File**: `core_code/03_study_level.R`
**Function**: `calculate_effective_n()`
**Lines**: 82-118

**Review Checklist**:
- [ ] **Formula Correctness**: Verify `n_eff = (Σw)² / Σw²` matches Kish (1965)
- [ ] **Edge Case**: All weights = 1 → Returns actual n
- [ ] **Edge Case**: All weights = 0 → Returns 0
- [ ] **Edge Case**: Single weight → Doesn't crash
- [ ] **Numeric Stability**: Scaling by mean weight prevents overflow
- [ ] **Weight Filtering**: NA, infinite, zero, negative weights excluded
- [ ] **Return Type**: Always returns integer via `as.integer(round())`

**Potential Issues to Check**:
- Division by zero when `sum(w^2) = 0`
- Integer overflow with very large sample sizes (n > 2^31)
- Loss of precision with extreme weight ranges (e.g., 0.0001 to 10000)

---

### 1.2 Design Effect (CRITICAL)

**File**: `core_code/03_study_level.R`
**Function**: `calculate_deff()`
**Lines**: 155-175

**Review Checklist**:
- [ ] **Formula**: DEFF = 1 + CV² where CV = sd(weights)/mean(weights)
- [ ] **Edge Case**: All weights = 1 → Returns exactly 1.0
- [ ] **Edge Case**: Zero weights filtered before CV calculation
- [ ] **Divide by Zero**: mean(weights) = 0 handled
- [ ] **NA Handling**: Returns NA when no valid weights

---

### 1.3 Proportion Confidence Intervals (CRITICAL)

**File**: `core_code/04_proportions.R`

#### Wilson Score Interval
**Function**: `calculate_proportion_ci_wilson()`
**Lines**: 184-219

**Review Checklist**:
- [ ] **Formula Accuracy**: Center and margin calculations match Wilson (1927)
- [ ] **Never Outside [0,1]**: Bounds clamped to [0,1]
- [ ] **Edge Case**: p = 0 → Doesn't produce negative lower bound
- [ ] **Edge Case**: p = 1 → Doesn't produce upper > 1
- [ ] **n = 1**: Doesn't crash or produce NaN

**Formula to Verify**:
```
denominator = 1 + z²/n
center = (p + z²/(2n)) / denominator
margin = z * sqrt((p(1-p) + z²/(4n))/n) / denominator
```

#### Bootstrap
**Function**: `bootstrap_proportion_ci()`
**Lines**: 274-343

**Review Checklist**:
- [ ] **Resampling Correctness**: Resamples indices (not values) to preserve data-weight pairs
- [ ] **Sample Size**: Always resamples n observations (with replacement)
- [ ] **Weight Preservation**: Bootstrap weights correspond to bootstrap data
- [ ] **Edge Case**: B = 1 → Doesn't crash (though not useful)
- [ ] **Edge Case**: All same value → CI degenerates to point estimate
- [ ] **Seed Control**: Reproducible when seed specified
- [ ] **Percentile Method**: Uses `quantile()` correctly for α/2 and 1-α/2

**Potential Bugs**:
- Off-by-one errors in indexing
- Misaligned data-weight pairs after resampling
- Wrong quantile calculation (e.g., using α instead of α/2)

#### Bayesian Beta-Binomial
**Function**: `credible_interval_proportion()`
**Lines**: 406-468

**Review Checklist**:
- [ ] **Conjugate Update**: α_post = α_prior + successes, β_post = β_prior + failures
- [ ] **Uninformed Prior**: Beta(1,1) when prior_mean is NULL
- [ ] **Informed Prior**: α = prior_mean * prior_n, β = (1-prior_mean) * prior_n
- [ ] **Edge Case**: prior_n = 0 → Treated as uninformed
- [ ] **Edge Case**: prior_mean = 0 or 1 → Doesn't produce invalid Beta parameters
- [ ] **Credible Interval**: Uses `qbeta()` with correct parameters

---

### 1.4 Mean Confidence Intervals (CRITICAL)

**File**: `core_code/05_means.R`

#### t-Distribution
**Function**: `calculate_mean_ci()`
**Lines**: 96-181

**Review Checklist**:
- [ ] **Weighted Mean**: Uses `sum(values * weights) / sum(weights)` correctly
- [ ] **Weighted SD**: Formula `sqrt(sum(weights * (values - mean)^2) / sum(weights))`
- [ ] **Degrees of Freedom**: Uses `n_eff - 1` for weighted data
- [ ] **Standard Error**: `SE = SD / sqrt(n_eff)` correct
- [ ] **Critical Value**: `qt(1 - α/2, df)` correct
- [ ] **Edge Case**: n = 2 → df = 1 (valid but wide CI)
- [ ] **Edge Case**: All same value → SD = 0 → CI = point estimate

**Potential Issues**:
- Weighted variance formula vs. unweighted (different formulas)
- Degrees of freedom for effective n (some use n-1, some use n_eff-1)

#### Bootstrap for Means
**Function**: `bootstrap_mean_ci()`
**Lines**: 235-309

**Review Checklist**:
- [ ] **Weighted Mean in Loop**: `sum(boot_values * boot_weights) / sum(boot_weights)`
- [ ] **Unweighted Case**: Uses simple `mean(boot_values)` when no weights
- [ ] **Same Logic as Proportions**: Consistent resampling approach

---

## SECTION 2: INPUT VALIDATION & QUESTION LIMIT

### 2.1 Question Limit Enforcement (CRITICAL)

**File**: `core_code/01_load_config.R`
**Function**: `load_question_analysis_sheet()`
**Lines**: 229-275

**Review Checklist**:
- [ ] **Limit Check**: Lines 262-267 enforce 200 question maximum
- [ ] **Error Message**: Clear message with actual count and maximum
- [ ] **Boundary**: Exactly 200 questions allowed (not 201)
- [ ] **Empty Rows**: Blank rows excluded from count (line 259)
- [ ] **Test Coverage**: `tests/test_01_load_config.R` tests 201 questions

**Specific Code to Review**:
```r
if (n_questions > 200) {
  stop(sprintf(
    "Question limit exceeded: %d questions specified (maximum 200)",
    n_questions
  ), call. = FALSE)
}
```

**Test**: Verify `test_question_limit()` in test file

---

### 2.2 Configuration Validation (CRITICAL)

**File**: `core_code/01_load_config.R`
**Function**: `validate_config()`
**Lines**: 310-335

**Review Checklist**:
- [ ] **All Required Sheets**: File_Paths, Study_Settings, Question_Analysis
- [ ] **All Required Parameters**: Data_File, Output_File checked
- [ ] **Value Ranges**: Confidence level in {0.90, 0.95, 0.99}
- [ ] **Bootstrap Iterations**: Range [1000, 10000] enforced
- [ ] **Decimal Separator**: Only '.' or ',' allowed
- [ ] **At Least One Method**: Each question has MOE, Bootstrap, or Credible = 'Y'

**Sub-Function Reviews**:

#### `validate_study_settings()`
**Lines**: 381-442

- [ ] **Calculate_Effective_N**: Must be 'Y' or 'N'
- [ ] **Multiple_Comparison_Adjustment**: Must be 'Y' or 'N'
- [ ] **Multiple_Comparison_Method**: Bonferroni/Holm/FDR (if adjustment = Y)
- [ ] **Bootstrap_Iterations**: Numeric and in [1000, 10000]
- [ ] **Confidence_Level**: Numeric and in {0.90, 0.95, 0.99}

#### `validate_question_analysis()`
**Lines**: 447-558

- [ ] **Statistic_Type**: Must be 'proportion', 'mean', or 'nps'
- [ ] **Categories**: Required for proportions, NA for means
- [ ] **At Least One Method**: Lines 498-503 check at least one Run_* = 'Y'
- [ ] **Prior Validation**: If Run_Credible = 'Y' and Prior_Mean specified:
  - For proportions: Prior_Mean in [0, 1]
  - For means: Prior_SD must be specified and > 0
  - Prior_N must be numeric

---

### 2.3 Data Validation (IMPORTANT)

**File**: `core_code/02_load_data.R`
**Function**: `validate_survey_data()`
**Lines**: 175-254

**Review Checklist**:
- [ ] **Required Questions**: All Question_IDs from config present in data
- [ ] **Weight Variable**: Exists and is numeric
- [ ] **No Negative Weights**: Check on lines 225-230
- [ ] **Zero Weights Warning**: Lines 233-240
- [ ] **NA Weights Warning**: Lines 243-250
- [ ] **Empty Data**: Check for nrow = 0, ncol = 0

**Edge Cases to Test**:
- All weights = NA
- All weights = 0
- Mix of positive, zero, and NA weights
- Weight column exists but is character type

---

## SECTION 3: EDGE CASES & BOUNDARY CONDITIONS

### 3.1 Sample Size Edge Cases

**Check Throughout All Statistical Functions**:

- [ ] **n = 0**: No data after removing NAs
- [ ] **n = 1**: Single observation
- [ ] **n = 2**: Minimum for variance calculation
- [ ] **n = Very Large**: (e.g., 1 million) → Integer overflow?

**Files to Check**:
- `04_proportions.R`: Each CI function
- `05_means.R`: Each CI function
- `03_study_level.R`: DEFF and effective n

---

### 3.2 Proportion Edge Cases

**File**: `core_code/04_proportions.R`

- [ ] **p = 0**: No successes
- [ ] **p = 1**: All successes
- [ ] **p = 0.5**: Middle value
- [ ] **p very small**: (e.g., 0.001) → Wilson should work
- [ ] **p very large**: (e.g., 0.999) → Wilson should work

**Functions to Test**:
- `calculate_proportion_ci_normal()`: Should warn for extremes
- `calculate_proportion_ci_wilson()`: Should handle all
- `bootstrap_proportion_ci()`: Should handle all
- `credible_interval_proportion()`: Check Beta(1+0, 1+n) case

---

### 3.3 Weight Edge Cases

**File**: `core_code/03_study_level.R`

- [ ] **All weights = 1**: DEFF = 1.0, n_eff = n
- [ ] **All weights = same value c**: DEFF = 1.0, n_eff = n
- [ ] **One extreme weight**: (e.g., [1,1,1,1,1000]) → High DEFF
- [ ] **Negative weights**: Should be caught in validation
- [ ] **Zero weights**: Should be excluded
- [ ] **Very small weights**: (e.g., 0.0001) → Numeric stability?

---

### 3.4 Missing Data Edge Cases

**Check All Data Processing Functions**:

- [ ] **All NA for a question**: Should produce warning and skip
- [ ] **Some NA**: Should remove and process remaining
- [ ] **NA in weights**: Should remove corresponding observations
- [ ] **NA in both data and weights**: Handle correctly

**Files**:
- `00_main.R`: Lines 509-526 (mean question processing)
- `04_proportions.R`: Lines 413-427 (proportion question processing)
- `05_means.R`: Lines 379-389 (credible interval for means)

---

## SECTION 4: NUMERIC STABILITY & DATA TYPES

### 4.1 Overflow/Underflow Risks

**Review Areas**:

#### Large Sums
- [ ] **Sum of weights**: `sum(weights)` could overflow if weights are large
- [ ] **Sum of squares**: `sum(weights^2)` more prone to overflow

**File**: `03_study_level.R`
**Mitigation**: Lines 96-103 scale by mean weight
**Check**: Does scaling work for all cases?

#### Extreme Proportions
- [ ] **p very small**: SE → 0, does `sqrt(p*(1-p)/n)` underflow?
- [ ] **p very large**: Same issue

---

### 4.2 Integer vs. Numeric

**Review All Conversions**:

- [ ] **Sample Sizes**: `as.integer()` used correctly?
  - `03_study_level.R`, line 117: `as.integer(round(n_effective))`
  - Check: Does this handle n > 2^31-1?

- [ ] **Bootstrap Iterations**: `as.integer()` for B parameter
  - `00_main.R`, line 455: `as.integer(config$study_settings$Bootstrap_Iterations)`

- [ ] **Degrees of Freedom**: Integer or numeric?
  - `05_means.R`, line 151: `df <- n_eff - 1`

---

### 4.3 Division by Zero

**Check All Division Operations**:

- [ ] **Effective n calculation**: `sum(w^2)` in denominator
  - File: `03_study_level.R`, line 113
  - Check: Lines 109-114 handle this?

- [ ] **DEFF calculation**: `mean(weights)` in denominator
  - File: `03_study_level.R`, line 169
  - Check: Handled?

- [ ] **Standard error**: `sqrt(n)` in denominator
  - Multiple files
  - Check: `n = 0` caught earlier?

- [ ] **Weighted mean**: `sum(weights)` in denominator
  - Multiple files
  - Check: Validated to be > 0?

---

## SECTION 5: QUESTION PROCESSING LOGIC

### 5.1 Main Loop

**File**: `core_code/00_main.R`
**Lines**: 260-284

**Review Checklist**:
- [ ] **Loop Range**: `seq_len(n_questions)` correct for all question counts
- [ ] **Question Dispatch**: Correctly routes to proportion vs. mean handlers
- [ ] **Error Propagation**: Errors in one question don't stop others
- [ ] **Warning Collection**: Warnings accumulated correctly

**Code to Review**:
```r
for (i in seq_len(n_questions)) {
  q_row <- config$question_analysis[i, ]
  q_id <- q_row$Question_ID

  stat_type <- tolower(q_row$Statistic_Type)

  if (stat_type == "proportion") {
    result <- process_proportion_question(...)
  } else if (stat_type == "mean") {
    result <- process_mean_question(...)
  } else {
    warning(...)
  }
}
```

**Potential Issues**:
- Case sensitivity in `stat_type` (lowercased on line 270, check config loader)
- Empty or NA Question_ID
- Duplicate Question_IDs

---

### 5.2 Proportion Question Processing

**File**: `core_code/00_main.R`
**Function**: `process_proportion_question()`
**Lines**: 380-478

**Review Checklist**:
- [ ] **Question Existence**: Line 387 checks if Q_ID in data
- [ ] **Category Parsing**: Line 401 uses `parse_codes(q_row$Categories)`
- [ ] **Success Definition**: Line 411 uses `values %in% categories`
- [ ] **NA Removal**: Line 414 creates `valid_idx`
- [ ] **Weight Alignment**: Lines 420-426 filter weights to match valid data
- [ ] **Effective n Calculation**: Line 428 calls `calculate_effective_n()`
- [ ] **Proportion Calculation**: Line 429 weighted proportion
- [ ] **Method Dispatch**: Lines 444-471 check Run_MOE, Run_Wilson, etc.

**Potential Bugs**:
- Misalignment between `success_values` and `weights_valid`
- Category parsing failure (e.g., "1,2,3" vs. "1, 2, 3" vs. "1;2;3")
- Prior parameters not passed correctly to Bayesian function

---

### 5.3 Mean Question Processing

**File**: `core_code/00_main.R`
**Function**: `process_mean_question()`
**Lines**: 483-567

**Review Checklist**:
- [ ] **Numeric Conversion**: Lines 498-500 convert to numeric
- [ ] **NA Removal**: Lines 509-510
- [ ] **Weight Filtering**: Lines 513-517
- [ ] **Mean Calculation**: Lines 520-531 (weighted vs. unweighted)
- [ ] **SD Calculation**: Lines 525-526 (weighted variance)
- [ ] **Method Dispatch**: Lines 541-560 check Run_MOE, Run_Bootstrap, Run_Credible

**Potential Issues**:
- Non-numeric data not handled (e.g., "N/A" string)
- SD calculation differs from `05_means.R`? (Check consistency)
- Prior_SD vs. Prior_N parameter passing

---

## SECTION 6: OUTPUT GENERATION

### 6.1 Excel Output Structure

**File**: `core_code/07_output.R`
**Function**: `write_confidence_output()`
**Lines**: 88-145

**Review Checklist**:
- [ ] **7 Sheets Created**: Summary, Study_Level, Proportions_Detail, Means_Detail, Methodology, Warnings, Inputs
- [ ] **Conditional Sheets**: Study_Level only if data exists (lines 108-111)
- [ ] **Overwrite Protection**: Line 134 uses `overwrite = TRUE`
- [ ] **Error Handling**: Lines 133-142 wrap saveWorkbook in try-catch

---

### 6.2 Decimal Separator Handling

**File**: `core_code/07_output.R`

**Critical Review**:
- [ ] **Format Function**: Lines 772-784 `create_excel_number_format()`
- [ ] **Always Uses Period in Format**: Line 782 (Excel standard)
- [ ] **Warning**: Comment lines 778-780 explain locale dependency
- [ ] **Numeric Formatting**: Lines 800-837 `apply_numeric_formatting()`
- [ ] **No String Conversion**: Values stay numeric, only formatting changes

**Potential Issues**:
- User expects comma but sees period (Excel locale mismatch)
- Documentation clarity about this limitation
- Alternative: Could convert to character strings with gsub (but loses Excel numeric properties)

---

### 6.3 Dataframe Construction

**Proportions**: Lines 379-444
**Means**: Lines 498-559

**Review Checklist**:
- [ ] **Missing Columns**: Uses `dplyr::bind_rows()` or manual fallback (lines 428-441, 543-556)
- [ ] **Column Alignment**: All questions have same column set (NA for missing methods)
- [ ] **Question Ordering**: Maintains original question order

---

## SECTION 7: UTILITY FUNCTIONS

### 7.1 Validation Helpers

**File**: `core_code/utils.R`

#### `validate_proportion()`
**Lines**: 139-153

- [ ] **Range Check**: 0 ≤ p ≤ 1
- [ ] **NA Check**: Rejects NA values
- [ ] **Vector Handling**: Uses `any()` for vectors

#### `validate_sample_size()`
**Lines**: 167-185

- [ ] **Positive Check**: n ≥ min_n (default 1)
- [ ] **Integer Check**: `n != as.integer(n)` detects non-integers
- [ ] **NA Check**: Rejects NA

#### `validate_conf_level()`
**Lines**: 198-219

- [ ] **Range**: 0 < conf_level < 1
- [ ] **Allowed Values**: Checks against allowed_values parameter
- [ ] **Default**: {0.90, 0.95, 0.99}

#### `validate_question_limit()`
**Lines**: 258-276

- [ ] **Maximum Check**: n_questions ≤ max_questions
- [ ] **Default**: max_questions = 200
- [ ] **Error Message**: Includes actual and maximum counts

---

### 7.2 Parsing & Formatting

#### `parse_codes()`
**Lines**: 343-359

- [ ] **Empty String**: Returns NULL (line 344-346)
- [ ] **NA**: Returns NULL (line 344-346)
- [ ] **Comma Separation**: Uses `strsplit(codes_string, ",")`
- [ ] **Whitespace Trim**: Uses `trimws()`
- [ ] **Numeric Detection**: Tries `as.numeric()`, returns numeric if all convert
- [ ] **Character Fallback**: Returns character vector if any non-numeric

**Test Cases**:
- `"1,2,3"` → `c(1, 2, 3)` (numeric)
- `"1, 2, 3"` → `c(1, 2, 3)` (trimmed)
- `"A,B,C"` → `c("A", "B", "C")` (character)
- `"1,A,3"` → `c("1", "A", "3")` (character, not numeric)

#### `format_decimal()`
**Lines**: 44-67

- [ ] **Formula**: Uses `formatC(x, format = "f", digits = digits)`
- [ ] **Comma Replacement**: Line 63 uses `gsub("\\.", ",", formatted)`
- [ ] **Validation**: Lines 46-56 check inputs
- [ ] **Vector Handling**: Works on vectors

---

## SECTION 8: GUI APPLICATION

**File**: `ui_and_tests/run_confidence_gui.R`

### 8.1 File Path Handling

- [ ] **Script Directory Override**: Lines 362-363 set `script_dir_override`
- [ ] **Cleanup**: Lines 394-396 remove global variable
- [ ] **Working Directory**: Line 338 saves, line 398 restores

---

### 8.2 Error Display

**Lines**: 388-390

- [ ] **User-Friendly Messages**: Displayed in console_output
- [ ] **Notification**: Shiny notification shown
- [ ] **No Crashes**: Errors caught and displayed, app continues running

---

## SECTION 9: TEST COVERAGE GAPS

### 9.1 Tests to Add

**File**: `ui_and_tests/test_01_load_config.R`

**Existing Tests**: ✓
- Valid config loading
- Config validation
- 201 questions rejected
- Missing sheets
- Invalid confidence level
- Invalid decimal separator
- No methods selected

**Missing Tests**:
- [ ] Exactly 200 questions (boundary case)
- [ ] Duplicate Question_IDs
- [ ] Invalid Statistic_Type
- [ ] Categories missing for proportions
- [ ] Prior_SD missing when Prior_Mean specified for means
- [ ] Prior_Mean out of range for proportions

---

### 9.2 Statistical Function Tests

**Currently Missing**:
- [ ] Unit tests for `calculate_effective_n()` with edge cases
- [ ] Unit tests for `calculate_deff()` with edge cases
- [ ] Integration tests for `run_confidence_analysis()` end-to-end
- [ ] Tests for each CI method with known results (e.g., p=0.5, n=100 → known CI)
- [ ] Bootstrap reproducibility tests (same seed → same results)

**Suggested Additions**:

```r
# Test calculate_effective_n edge cases
test_effective_n <- function() {
  # All weights = 1
  weights <- rep(1, 100)
  n_eff <- calculate_effective_n(weights)
  stopifnot(n_eff == 100)

  # Single weight
  n_eff <- calculate_effective_n(1.5)
  stopifnot(n_eff == 1)

  # All same non-1 weight
  weights <- rep(2.5, 50)
  n_eff <- calculate_effective_n(weights)
  stopifnot(n_eff == 50)

  # High variation
  weights <- c(rep(0.5, 90), rep(10, 10))
  n_eff <- calculate_effective_n(weights)
  # Should be much less than 100
}
```

---

## SECTION 10: PERFORMANCE CONSIDERATIONS

### 10.1 Bootstrap Performance

**File**: `core_code/04_proportions.R`, `core_code/05_means.R`

- [ ] **Loop Efficiency**: Lines use vectorized `sample()`, check if can be further optimized
- [ ] **Memory Allocation**: `boot_proportions <- numeric(B)` pre-allocates (good)
- [ ] **Large B**: Test with B=10000 and n=10000 → Time?

**Potential Optimization**:
- Parallel processing using `parallel` package
- Progress bar for user feedback

---

### 10.2 Data Loading Performance

**File**: `core_code/02_load_data.R`

- [ ] **data.table Usage**: Lines 133-135 use `fread` if available
- [ ] **Fallback**: Lines 137-138 use base `read.csv`
- [ ] **Large Files**: Test with 1M+ row CSV

---

## SECTION 11: DOCUMENTATION REVIEW

### 11.1 User Manual

**File**: `documentation/USER_MANUAL.md`

- [ ] **Examples**: All examples work?
- [ ] **Screenshots**: Up to date?
- [ ] **Troubleshooting**: Common errors covered?

---

### 11.2 Technical Docs

**File**: `documentation/MAINTENANCE_GUIDE.md`

- [ ] **Architecture**: Matches actual code structure?
- [ ] **Formulas**: Mathematically correct?
- [ ] **References**: Citations complete?

---

## SECTION 12: CRITICAL BUGS TO LOOK FOR

### 12.1 Common R Pitfalls

- [ ] **Vector Recycling**: Unintended recycling in operations
- [ ] **Partial Matching**: Using `$` operator with partial names
- [ ] **Factor Conversion**: Unexpected factor-to-numeric conversions
- [ ] **NULL vs. NA**: Confusion between NULL and NA
- [ ] **Integer Overflow**: Calculations exceeding 2^31-1

---

### 12.2 Survey Statistics Pitfalls

- [ ] **Weights Sum to 1?**: Some formulas assume this, some don't
- [ ] **Effective n Formula**: Different sources use different approximations
- [ ] **Degrees of Freedom**: n-1 vs. n_eff-1 for weighted data
- [ ] **Bootstrap Weights**: Should sum to original sum or be rescaled?
- [ ] **Prior Elicitation**: Beta(α,β) vs. (mean, n) parameterization

---

## SECTION 13: OVERALL CODE QUALITY

### 13.1 Code Style

- [ ] **Consistent Naming**: snake_case vs. camelCase
- [ ] **Function Length**: Any functions > 100 lines that should be split?
- [ ] **Comments**: Adequate inline comments for complex logic?
- [ ] **Magic Numbers**: Hard-coded values explained?

---

### 13.2 Error Messages

- [ ] **Actionable**: Do error messages tell user what to do?
- [ ] **Context**: Do messages include question ID or file name?
- [ ] **Formatting**: Consistent format across all errors?

---

### 13.3 Maintainability

- [ ] **DRY Principle**: Duplicated code that should be functions?
- [ ] **Function Reuse**: Are utility functions used consistently?
- [ ] **Dependencies**: Are package dependencies clearly documented?

---

## REVIEW SUBMISSION FORMAT

### Suggested Format for Findings

```markdown
## Finding #1: [SEVERITY] Brief Title

**File**: core_code/03_study_level.R
**Function**: calculate_effective_n()
**Lines**: 109-114

**Issue**:
Division by zero possible when all weights are zero.

**Evidence**:
```r
n_effective <- (sum_weights^2) / sum_weights_squared
# If sum_weights_squared = 0, this crashes
```

**Impact**:
Program crash if all weights are zero or invalid.

**Suggested Fix**:
```r
if (sum_weights_squared == 0) {
  return(0L)
}
n_effective <- (sum_weights^2) / sum_weights_squared
```

**Severity**: MEDIUM (edge case, unlikely but not caught)
```

---

## PRIORITY RECOMMENDATIONS

### High Priority Items to Review First

1. **Question limit enforcement** (Section 2.1)
2. **Effective n calculation** (Section 1.1)
3. **Wilson score formula** (Section 1.3)
4. **Division by zero checks** (Section 4.3)
5. **Weight alignment in bootstrap** (Section 1.3)
6. **Main processing loop** (Section 5.1)

### Medium Priority

7. Edge cases in all CI functions (Section 3)
8. Data validation (Section 2.3)
9. Numeric stability (Section 4.1)
10. Output generation (Section 6)

### Lower Priority

11. Code style (Section 13.1)
12. Performance (Section 10)
13. Documentation (Section 11)

---

## QUESTIONS FOR REVIEWER

1. Are the statistical formulas (DEFF, effective n, Wilson score) correctly implemented?
2. Are there edge cases that could cause crashes or incorrect results?
3. Is the 200 question limit properly enforced at all entry points?
4. Are there numeric stability issues with extreme values?
5. Is the bootstrap resampling logic correct for weighted data?
6. Are there test coverage gaps for critical functionality?
7. Are error messages clear and actionable?
8. Are there performance bottlenecks that should be addressed?

---

**END OF REVIEW CHECKLIST**
