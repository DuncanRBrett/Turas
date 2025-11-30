# TURAS CONFIDENCE MODULE - EXTERNAL REVIEW PACKAGE

**Version:** 1.0.0-beta
**Date:** November 30, 2025
**Purpose:** External code review for bug identification and quality assurance

---

## WELCOME REVIEWER

Thank you for reviewing the Turas Confidence Module. This package contains all source code, documentation, and review materials needed for a comprehensive assessment.

**Review Objectives:**
1. Identify bugs and potential errors
2. Verify statistical algorithm correctness
3. Check edge case handling
4. Assess code quality and maintainability
5. Validate the 200 question limit enforcement
6. Ensure proper error handling

---

## PACKAGE CONTENTS

```
confidence_module_review/
├── README.md                      ← You are here
├── TECHNICAL_SUMMARY.md           ← Start here: Complete technical overview
├── REVIEW_CHECKLIST.md            ← Guided review checklist
│
├── core_code/                     ← 8 core R modules (~3,900 lines)
│   ├── 00_main.R                  Main orchestration (621 lines)
│   ├── 01_load_config.R           Configuration loader (611 lines)
│   ├── 02_load_data.R             Data loader (415 lines)
│   ├── 03_study_level.R           DEFF & effective n (393 lines)
│   ├── 04_proportions.R           Proportion CIs (582 lines)
│   ├── 05_means.R                 Mean CIs (590 lines)
│   ├── 07_output.R                Excel output (850 lines)
│   └── utils.R                    Utilities (424 lines)
│
├── ui_and_tests/                  ← UI + Tests (~1,500 lines)
│   ├── run_confidence_gui.R       Shiny GUI (408 lines)
│   ├── test_01_load_config.R      Config tests (563 lines)
│   └── test_utils.R               Utility tests (548 lines)
│
├── examples/                      ← Example data generator
│   └── create_example_config.R    (360 lines)
│
└── documentation/                 ← User & technical docs
    ├── README.md                  Module overview
    ├── USER_MANUAL.md             User guide (1,596 lines)
    ├── QUICK_START.md             Quick start guide
    ├── EXAMPLE_WORKFLOWS.md       Real-world examples
    └── MAINTENANCE_GUIDE.md       Technical architecture (1,671 lines)
```

**Total Line Count:** ~4,900 lines of R code + comprehensive documentation

---

## GETTING STARTED

### Step 1: Read the Technical Summary

**File:** `TECHNICAL_SUMMARY.md`

This 40-page document provides:
- Executive summary
- Module architecture
- Statistical methodologies (formulas and references)
- Core components and data flow
- Key algorithms with pseudocode
- Input/output specifications
- Error handling approach
- Known limitations

**Time Estimate:** 60-90 minutes

---

### Step 2: Review the Checklist

**File:** `REVIEW_CHECKLIST.md`

This comprehensive checklist guides you through:
- 13 major review sections
- Specific files, functions, and line numbers to check
- Critical vs. important vs. nice-to-have items
- Common pitfalls and bugs to look for
- Suggested test cases
- Finding submission format

**Time Estimate:** Review planning: 30 minutes

---

### Step 3: Code Review

**Suggested Review Order (by priority):**

#### 🔴 **CRITICAL - Review First (Estimated: 3-4 hours)**

1. **Question Limit Enforcement**
   - File: `core_code/01_load_config.R`
   - Function: `load_question_analysis_sheet()` (lines 229-275)
   - Check: Hard limit of 200 questions enforced correctly
   - Test: `ui_and_tests/test_01_load_config.R::test_question_limit()`

2. **Effective Sample Size Calculation**
   - File: `core_code/03_study_level.R`
   - Function: `calculate_effective_n()` (lines 82-118)
   - Formula: `n_eff = (Σw)² / Σw²` (Kish 1965)
   - Check: Edge cases (all weights = 1, zero weights, division by zero)

3. **Wilson Score Interval**
   - File: `core_code/04_proportions.R`
   - Function: `calculate_proportion_ci_wilson()` (lines 184-219)
   - Formula: Complex (see TECHNICAL_SUMMARY.md Section 3.1)
   - Check: Never produces intervals outside [0,1], handles p=0 and p=1

4. **Bootstrap Resampling Logic**
   - File: `core_code/04_proportions.R`
   - Function: `bootstrap_proportion_ci()` (lines 274-343)
   - Critical: Resamples indices (not values) to preserve data-weight pairs
   - Check: Lines 308-316 (resampling loop)

5. **Main Processing Loop**
   - File: `core_code/00_main.R`
   - Lines: 260-284
   - Check: Correct dispatch to proportion vs. mean handlers
   - Check: Error handling doesn't crash entire analysis

#### 🟡 **IMPORTANT - Review Second (Estimated: 2-3 hours)**

6. **Configuration Validation**
   - File: `core_code/01_load_config.R`
   - Functions: `validate_config()`, `validate_study_settings()`, `validate_question_analysis()`
   - Check: All input validation rules enforced

7. **Data Validation**
   - File: `core_code/02_load_data.R`
   - Function: `validate_survey_data()` (lines 175-254)
   - Check: Weight validation, missing data handling

8. **Weighted Mean & SD Calculations**
   - File: `core_code/05_means.R`
   - Function: `calculate_mean_ci()` (lines 96-181)
   - Check: Weighted variance formula correct

9. **Proportion Question Processing**
   - File: `core_code/00_main.R`
   - Function: `process_proportion_question()` (lines 380-478)
   - Check: Category parsing, data-weight alignment

10. **Mean Question Processing**
    - File: `core_code/00_main.R`
    - Function: `process_mean_question()` (lines 483-567)
    - Check: Numeric conversion, NA handling

#### 🟢 **NICE TO HAVE - Review If Time (Estimated: 2-3 hours)**

11. **Output Generation**
    - File: `core_code/07_output.R`
    - Check: Excel structure, decimal separator handling

12. **Utility Functions**
    - File: `core_code/utils.R`
    - Check: Validation helpers, parsing functions

13. **Test Coverage**
    - Files: `ui_and_tests/test_*.R`
    - Check: Test coverage gaps (see REVIEW_CHECKLIST Section 9)

---

### Step 4: Testing (Optional)

If you have R installed, you can run the tests:

```r
# Set working directory to this package
setwd("/path/to/confidence_module_review")

# Run utility tests
source("ui_and_tests/test_utils.R")
run_all_tests()

# Run config loader tests
source("ui_and_tests/test_01_load_config.R")
run_all_tests()
```

**Required R Packages:**
- `openxlsx` (for Excel file tests)
- `readxl` (for reading Excel)

**Time Estimate:** 15 minutes (if tests pass)

---

## KEY REVIEW AREAS

### 1. Statistical Correctness

**Files:** `03_study_level.R`, `04_proportions.R`, `05_means.R`

**Questions to Answer:**
- Are the formulas correctly implemented?
- Do they match the references cited (Kish 1965, Wilson 1927, etc.)?
- Are edge cases (p=0, p=1, n=1, all weights=1) handled correctly?

**References:**
- See TECHNICAL_SUMMARY.md Section 3 for formula details
- See REVIEW_CHECKLIST.md Sections 1.1-1.4 for specific checks

---

### 2. Question Limit (200 Max)

**File:** `core_code/01_load_config.R`

**Critical Check:**
- Lines 262-267: Enforces 200 question maximum
- Error message clear and includes actual count
- Test coverage: `test_question_limit()` passes

**Why Critical:**
This is a hard requirement specified by the client. Exceeding 200 questions should never be allowed.

---

### 3. Weight Handling

**Files:** `02_load_data.R`, `03_study_level.R`, `04_proportions.R`, `05_means.R`

**Key Questions:**
- Are zero and negative weights correctly excluded?
- Is effective sample size calculated correctly?
- Are data and weights properly aligned in bootstrap resampling?
- Is DEFF calculated using the correct formula?

---

### 4. Error Handling

**All Files**

**Check For:**
- Division by zero
- Integer overflow
- NA propagation
- Empty data after filtering
- Misaligned data and weights
- File I/O errors

**Error Message Quality:**
- Actionable (tells user what to do)
- Includes context (question ID, file name)
- Consistent format

---

### 5. Edge Cases

**High Priority Edge Cases:**
1. n = 0 (no data after removing NAs)
2. n = 1 (single observation)
3. p = 0 or p = 1 (extreme proportions)
4. All weights = 1 (unweighted case)
5. All values identical (zero variance)
6. Missing data (all NA, some NA)

**See:** REVIEW_CHECKLIST.md Section 3 for complete edge case list

---

## REVIEW OUTPUT

### Findings Report Format

Please document findings using this format:

```markdown
## Finding #X: [SEVERITY] Brief Title

**File:** core_code/filename.R
**Function:** function_name()
**Lines:** X-Y

**Issue:**
[Clear description of the problem]

**Evidence:**
```r
[Code snippet showing the issue]
```

**Impact:**
[What goes wrong if this isn't fixed]

**Suggested Fix:**
```r
[Proposed code fix, if applicable]
```

**Severity:** HIGH | MEDIUM | LOW
**Type:** BUG | EDGE_CASE | PERFORMANCE | STYLE | DOCUMENTATION
```

### Severity Definitions

- **HIGH**: Causes incorrect results, crashes, or data corruption
- **MEDIUM**: Edge case not handled, potential for incorrect results
- **LOW**: Style issues, documentation gaps, minor inefficiencies

---

## EXPECTED REVIEW TIME

**Estimated Total Time:** 8-12 hours

**Breakdown:**
- Reading technical summary: 1.5 hours
- Critical items (1-5): 3-4 hours
- Important items (6-10): 2-3 hours
- Nice-to-have items (11-13): 2-3 hours
- Documentation and reporting: 1-2 hours

**Recommended Approach:**
- Day 1: Read technical summary + review critical items
- Day 2: Review important items + testing
- Day 3: Nice-to-have items + write findings report

---

## QUESTIONS & SUPPORT

If you have questions during the review:

1. **Statistical Methodology:** See TECHNICAL_SUMMARY.md Section 3
2. **Code Architecture:** See TECHNICAL_SUMMARY.md Section 2
3. **Specific Algorithms:** See TECHNICAL_SUMMARY.md Section 6
4. **Input/Output Format:** See TECHNICAL_SUMMARY.md Section 7
5. **Known Limitations:** See TECHNICAL_SUMMARY.md Section 11

**Additional Resources:**
- `documentation/MAINTENANCE_GUIDE.md` - Detailed architecture and troubleshooting
- `documentation/USER_MANUAL.md` - User perspective and examples
- Original references cited in TECHNICAL_SUMMARY.md Appendix

---

## MODULE OVERVIEW (Quick Summary)

### What This Module Does

Calculates statistical confidence intervals for survey data using four methods:

**For Proportions:**
1. Normal approximation (Margin of Error)
2. Wilson score interval
3. Bootstrap percentile method
4. Bayesian Beta-Binomial

**For Means:**
1. t-distribution
2. Bootstrap percentile method
3. Bayesian Normal-Normal conjugate

**Key Features:**
- Handles weighted survey data (design weights)
- Calculates design effects (DEFF) and effective sample size
- Supports up to 200 questions per analysis
- Outputs 7-sheet Excel workbook with results and methodology
- International support (decimal separator: period or comma)

### Technology Stack

- **Language:** R (base R + packages)
- **Required Packages:** readxl, openxlsx
- **Optional Packages:** data.table, shiny, shinyFiles
- **Input:** Excel config + CSV/XLSX survey data
- **Output:** Multi-sheet Excel workbook

### Statistical Foundations

- **Effective n:** Kish (1965) formula
- **DEFF:** Design effect via coefficient of variation
- **Wilson Score:** Wilson (1927), Agresti & Coull (1998)
- **Bootstrap:** Efron & Tibshirani (1994)
- **Bayesian:** Gelman et al. (2013) conjugate priors

---

## FILE-BY-FILE SUMMARY

### Core Code

#### `00_main.R` (621 lines)
**Purpose:** Main orchestration
**Key Functions:**
- `run_confidence_analysis()` - Main entry point
- `process_proportion_question()` - Proportion processing
- `process_mean_question()` - Mean processing
**Priority:** HIGH - Review processing loops and dispatch logic

#### `01_load_config.R` (611 lines)
**Purpose:** Configuration loading and validation
**Key Functions:**
- `load_confidence_config()` - Loads 3-sheet Excel config
- `load_question_analysis_sheet()` - **Enforces 200 question limit**
- `validate_config()` - Comprehensive validation
**Priority:** CRITICAL - Question limit enforcement here

#### `02_load_data.R` (415 lines)
**Purpose:** Survey data loading
**Key Functions:**
- `load_survey_data()` - Loads CSV or XLSX
- `validate_survey_data()` - Validates data structure
**Priority:** HIGH - Weight validation critical

#### `03_study_level.R` (393 lines)
**Purpose:** Study-level statistics (DEFF, effective n)
**Key Functions:**
- `calculate_effective_n()` - **Kish (1965) formula**
- `calculate_deff()` - Design effect
- `calculate_study_level_stats()` - Comprehensive stats
**Priority:** CRITICAL - Core statistical calculations

#### `04_proportions.R` (582 lines)
**Purpose:** Proportion confidence intervals
**Key Functions:**
- `calculate_proportion_ci_normal()` - MOE
- `calculate_proportion_ci_wilson()` - **Wilson score (recommended)**
- `bootstrap_proportion_ci()` - Bootstrap resampling
- `credible_interval_proportion()` - Bayesian Beta-Binomial
**Priority:** CRITICAL - Core statistical algorithms

#### `05_means.R` (590 lines)
**Purpose:** Mean confidence intervals
**Key Functions:**
- `calculate_mean_ci()` - t-distribution
- `bootstrap_mean_ci()` - Bootstrap
- `credible_interval_mean()` - Bayesian Normal-Normal
**Priority:** HIGH - Core statistical algorithms

#### `07_output.R` (850 lines)
**Purpose:** Excel output generation
**Key Functions:**
- `write_confidence_output()` - Creates 7-sheet workbook
- `add_*_sheet()` - Individual sheet generators
- `apply_numeric_formatting()` - Decimal separator handling
**Priority:** MEDIUM - Output formatting

#### `utils.R` (424 lines)
**Purpose:** Utility functions
**Key Functions:**
- `format_decimal()` - Decimal separator formatting
- `validate_proportion()`, `validate_sample_size()`, etc. - Input validation
- `parse_codes()` - Category code parsing
**Priority:** MEDIUM - Validation logic

### UI and Tests

#### `run_confidence_gui.R` (408 lines)
**Purpose:** Shiny GUI interface
**Priority:** LOW - Nice to review but not critical

#### `test_01_load_config.R` (563 lines)
**Purpose:** Config loader tests
**Key Tests:** Question limit (201 questions rejected)
**Priority:** HIGH - Verify test coverage

#### `test_utils.R` (548 lines)
**Purpose:** Utility function tests
**Priority:** MEDIUM - Check test coverage

### Examples

#### `create_example_config.R` (360 lines)
**Purpose:** Generate example config and data
**Priority:** LOW - Helper script only

---

## COMMON ISSUES TO LOOK FOR

### R-Specific Pitfalls

1. **Vector Recycling:** Unintended silent recycling
2. **Partial Matching:** Using `$` with partial names
3. **Factor Conversion:** Factors converting to numeric incorrectly
4. **NULL vs. NA:** Confusion between NULL and NA
5. **Integer Overflow:** Exceeding 2^31-1

### Statistical Pitfalls

1. **Weight Summation:** Do weights need to sum to 1? (They don't here)
2. **Effective n Variants:** Different formulas exist, verify ours
3. **Degrees of Freedom:** n-1 vs. n_eff-1 for weighted data
4. **Bootstrap Weights:** Preservation vs. rescaling
5. **Prior Parameterization:** Beta(α,β) vs. (mean,n) conversion

### Survey Data Pitfalls

1. **Missing Weight Data:** NA in weights
2. **Zero Weights:** Should exclude or include?
3. **Negative Weights:** Invalid design weights
4. **Data-Weight Alignment:** Misaligned after filtering
5. **Empty After Filtering:** All data becomes NA

---

## SUCCESS CRITERIA

A successful review should:

✓ Verify question limit (200 max) is enforced
✓ Confirm statistical formulas match references
✓ Identify any crashes or incorrect results
✓ Check edge case handling (p=0, p=1, n=1, etc.)
✓ Validate error messages are clear and actionable
✓ Document any bugs or improvements
✓ Assess test coverage adequacy

---

## THANK YOU

We appreciate your time and expertise in reviewing this code. Your feedback will help ensure the Turas Confidence Module is robust, accurate, and reliable for production use.

**Contact for Questions:**
[Your contact information here]

---

**END OF README**
