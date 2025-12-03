# TURAS Regression Test Harness - Implementation Plan

**Version:** 1.0
**Date:** December 2, 2025
**Author:** Claude (based on ChatGPT recommendations)
**Status:** Planning Phase

---

## Executive Summary

### 🎯 Goal
Create an automated regression test harness that provides **one-click validation** that TURAS modules produce correct outputs after any code changes.

### ✅ Is This Worthwhile?
**YES - Absolutely critical.** Here's why:

1. **Safety Net** - Catches subtle bugs from "well-meaning changes"
2. **Client Protection** - Quick validation before deliveries
3. **Confidence** - Proves code changes didn't break existing functionality
4. **Onboarding** - New developers can verify their setup works
5. **Documentation** - Known outputs serve as executable specifications
6. **Alignment with TURAS Philosophy** - Your README states: _"If it's not tested, it does not ship"_

### 📊 Current State Assessment

**What You Already Have:**
- ✅ `/tests/` - testthat framework with baseline tests (unit tests)
- ✅ `/examples/` - validation scripts, test data, module reviews
- ✅ Test data for Conjoint and KeyDriver modules
- ✅ Golden master testing concept mentioned in tests/README.md
- ✅ Strong testing culture documented in README.md

**What's Missing:**
- ❌ No automated end-to-end regression tests
- ❌ No "golden values" files to lock in expected outputs
- ❌ No single-command harness runner
- ❌ Examples not yet used as formal test inputs
- ❌ No Shiny "Run TURAS self-check" button

---

## ChatGPT Recommendation Assessment

### 📝 Summary of Recommendations

ChatGPT proposed:

1. **Test harness location:** `/tests/regression/`
2. **Golden datasets:** 2-3 tiny known datasets
3. **Golden values:** YAML files with expected outputs (cell values, CIs, sig flags)
4. **Single source of truth:** Use `/examples/` for both tutorials AND test inputs
5. **One-command execution:** `Rscript tests/regression/run_regression.R`
6. **Shiny integration:** "Run TURAS self-check" button
7. **Assertion helpers:** Simple functions to compare actual vs expected

### ✅ What I Agree With

**Strongly Agree:**
- ✅ Using `/examples/` as single source of truth (avoid duplication)
- ✅ Small YAML files for expected values (easy to maintain)
- ✅ Keep tests outside `/modules/` (separation of concerns)
- ✅ Simple assertion helpers (lightweight, no heavy dependencies)
- ✅ One-command execution (developer-friendly)

**Somewhat Agree:**
- ⚠️ Shiny button for self-check (nice-to-have, but CLI more important)
- ⚠️ YAML for expected values (JSON might be more R-friendly, but either works)

### 🤔 What I'd Adjust for TURAS

**Priority Adjustments:**

1. **Focus on CLI first, Shiny later**
   - Most critical: `Rscript tests/regression/run_regression.R`
   - Shiny button can come in Phase 2

2. **Integrate with existing testthat infrastructure**
   - You already have testthat - use it for regression tests too
   - Leverage `expect_equal()`, `expect_true()`, etc.
   - This gives you free CI/CD integration later

3. **Start with production modules only**
   - Priority: Tabs, Tracker, Confidence (production-ready)
   - Later: Segment, Conjoint, KeyDriver, Pricing

4. **Use JSON instead of YAML**
   - R has better native JSON support (`jsonlite`)
   - Easier to programmatically update
   - More familiar to R developers

5. **Add tolerance specification per metric**
   - Some metrics need exact matches (counts, flags)
   - Others need tolerance (percentages, CIs)

---

## Recommended Architecture

### 📁 Directory Structure

```
Turas/
├── examples/                          # SINGLE SOURCE OF TRUTH for test data
│   ├── tabs/
│   │   └── basic/
│   │       ├── README.md              # Human tutorial
│   │       ├── data.csv               # 50-100 rows, 10-15 vars
│   │       └── tabs_config.xlsx       # Known configuration
│   ├── tracker/
│   │   └── basic/
│   │       ├── README.md
│   │       ├── data.csv               # 3 waves, 50 rows each
│   │       └── tracker_config.xlsx
│   ├── confidence/
│   │   └── basic/
│   │       ├── README.md
│   │       ├── data.csv
│   │       └── confidence_config.xlsx
│   └── (other modules...)
│
├── tests/
│   ├── testthat/                      # Existing unit tests
│   │   ├── test_shared_functions.R
│   │   └── ...
│   │
│   ├── regression/                    # NEW: Regression tests
│   │   ├── golden/                    # Expected outputs (JSON)
│   │   │   ├── tabs_basic.json
│   │   │   ├── tracker_basic.json
│   │   │   └── confidence_basic.json
│   │   │
│   │   ├── helpers/                   # Utility functions
│   │   │   ├── assertion_helpers.R
│   │   │   └── path_helpers.R
│   │   │
│   │   ├── test_regression_tabs.R     # testthat format
│   │   ├── test_regression_tracker.R
│   │   ├── test_regression_confidence.R
│   │   │
│   │   └── run_all_regression.R       # One-command runner
│   │
│   ├── testthat.R                     # Existing runner (runs all)
│   └── README.md                      # Updated documentation
│
└── modules/                           # No test code here
    ├── tabs/
    ├── tracker/
    └── ...
```

### 🔑 Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Use `/examples/` for test data | Avoid duplication; tutorials = tests |
| Use testthat for regression tests | Consistency with existing tests; CI/CD ready |
| JSON for golden values | Better R support; easier to update |
| Start with 3 production modules | Tabs, Tracker, Confidence are stable |
| CLI before Shiny | Core functionality first; UI later |
| Tolerance per metric | Different metrics need different precision |

---

## Implementation Plan

### Phase 1: Foundation (Week 1-2)

**Goal:** Set up infrastructure and helpers

**Tasks:**
1. Create `/tests/regression/` directory structure
2. Write assertion helpers in `/tests/regression/helpers/assertion_helpers.R`
3. Write path helpers to locate example projects
4. Document the pattern in `/tests/README.md`

**Deliverables:**
- Directory structure created
- Helper functions tested
- Documentation updated

### Phase 2: Tabs Module Regression Tests (Week 2-3)

**Goal:** Full regression test for Tabs module as proof-of-concept

**Tasks:**
1. Create `/examples/tabs/basic/` with:
   - Small synthetic dataset (50 rows, 10 variables)
   - Working tabs_config.xlsx
   - README.md tutorial
2. Run Tabs module manually and capture key outputs:
   - Overall mean for a key metric
   - A specific cell value
   - A significance flag
   - Effective N
   - Base sizes
3. Create `/tests/regression/golden/tabs_basic.json` with expected values
4. Write `/tests/regression/test_regression_tabs.R`
5. Test and refine

**Deliverables:**
- Working tabs example
- Golden values file
- Regression test passing

**Golden Values Example (tabs_basic.json):**
```json
{
  "module": "tabs",
  "example": "basic",
  "version": "10.0",
  "created": "2025-12-02",
  "checks": [
    {
      "name": "overall_mean_satisfaction",
      "value": 7.42,
      "tolerance": 0.01,
      "type": "numeric",
      "description": "Overall mean satisfaction score"
    },
    {
      "name": "cell_wave2_male_top2box",
      "value": 68.5,
      "tolerance": 0.1,
      "type": "numeric",
      "description": "Wave 2, Male, Top 2 Box %"
    },
    {
      "name": "sig_flag_male_vs_female",
      "value": true,
      "type": "logical",
      "description": "Male vs Female satisfaction significantly different"
    },
    {
      "name": "base_size_total",
      "value": 50,
      "type": "integer",
      "description": "Total base size"
    },
    {
      "name": "effective_n_weighted",
      "value": 47.3,
      "tolerance": 0.5,
      "type": "numeric",
      "description": "Effective N after weighting"
    }
  ]
}
```

### Phase 3: Tracker Module Regression Tests (Week 3-4)

**Goal:** Regression tests for Tracker module

**Tasks:**
1. Create `/examples/tracker/basic/`
2. Capture golden values (trends, CIs, change significance)
3. Write test file
4. Validate

**Key Checks for Tracker:**
- Wave-to-wave change value
- 95% CI bounds
- Significance flag for change
- Base drift warnings
- Continuity flags

### Phase 4: Confidence Module Regression Tests (Week 4)

**Goal:** Regression tests for Confidence module

**Key Checks:**
- MOE values
- Wilson score intervals
- Design effects (DEFF)
- Effective N calculations
- Bootstrap CI bounds

### Phase 5: Integration & Automation (Week 5)

**Goal:** One-command execution and documentation

**Tasks:**
1. Create `/tests/regression/run_all_regression.R`
2. Update `/tests/testthat.R` to optionally run regression tests
3. Create simple reporting (pass/fail summary)
4. Update documentation

**Command:**
```bash
# Run all tests (unit + regression)
Rscript tests/testthat.R

# Run only regression tests
Rscript tests/regression/run_all_regression.R

# Run specific module regression
Rscript -e "testthat::test_file('tests/regression/test_regression_tabs.R')"
```

### Phase 6: Shiny Integration (Optional - Week 6)

**Goal:** "Run TURAS self-check" button in Shiny UI

**Tasks:**
1. Add button to main Shiny UI
2. Add output panel for results
3. Run regression tests in isolated environment
4. Display pass/fail summary with details

---

## Example Code Snippets

### Assertion Helper (`tests/regression/helpers/assertion_helpers.R`)

```r
#' Compare numeric value with tolerance
#'
#' @param name Test name
#' @param actual Actual value from module
#' @param expected Expected value from golden file
#' @param tolerance Acceptable difference
#' @return Invisible TRUE/FALSE
check_numeric <- function(name, actual, expected, tolerance = 0.01) {
  testthat::test_that(name, {
    testthat::expect_equal(actual, expected, tolerance = tolerance,
                           label = paste0("actual (", actual, ")"),
                           expected.label = paste0("expected (", expected, ")"))
  })
}

#' Compare logical value (exact match)
check_logical <- function(name, actual, expected) {
  testthat::test_that(name, {
    testthat::expect_identical(actual, expected,
                               label = paste0("actual (", actual, ")"),
                               expected.label = paste0("expected (", expected, ")"))
  })
}

#' Compare integer value (exact match)
check_integer <- function(name, actual, expected) {
  testthat::test_that(name, {
    testthat::expect_equal(as.integer(actual), as.integer(expected),
                           label = paste0("actual (", actual, ")"),
                           expected.label = paste0("expected (", expected, ")"))
  })
}
```

### Path Helper (`tests/regression/helpers/path_helpers.R`)

```r
#' Get paths for an example project
#'
#' @param module Module name (e.g., "tabs", "tracker")
#' @param example Example name (e.g., "basic")
#' @return List with data and config paths
get_example_paths <- function(module, example = "basic") {
  base_path <- file.path("examples", module, example)

  if (!dir.exists(base_path)) {
    stop("Example not found: ", base_path)
  }

  list(
    base = base_path,
    data = file.path(base_path, "data.csv"),
    config = file.path(base_path, paste0(module, "_config.xlsx")),
    readme = file.path(base_path, "README.md")
  )
}

#' Get golden values file path
get_golden_path <- function(module, example = "basic") {
  path <- file.path("tests", "regression", "golden",
                    paste0(module, "_", example, ".json"))

  if (!file.exists(path)) {
    stop("Golden values file not found: ", path)
  }

  path
}

#' Load golden values from JSON
load_golden <- function(module, example = "basic") {
  path <- get_golden_path(module, example)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}
```

### Regression Test Example (`tests/regression/test_regression_tabs.R`)

```r
# Regression tests for Tabs module
library(testthat)
library(jsonlite)

# Source helpers
source("tests/regression/helpers/assertion_helpers.R")
source("tests/regression/helpers/path_helpers.R")

# Source Tabs module
source("modules/tabs/run_tabs.R")

test_that("Tabs module: basic example produces expected outputs", {

  # 1. Load example data and config
  paths <- get_example_paths("tabs", "basic")
  data <- read.csv(paths$data, stringsAsFactors = FALSE)
  # Assume run_tabs() accepts config path and data

  # 2. Run Tabs module
  # NOTE: Adjust this to match your actual Tabs entry point
  output <- run_tabs_module(
    data = data,
    config_file = paths$config,
    output_file = NULL  # Don't write output, just return object
  )

  # 3. Load golden values
  golden <- load_golden("tabs", "basic")

  # 4. Run checks
  for (check in golden$checks) {
    # Extract actual value from output
    # NOTE: Adjust extraction logic to match your output structure
    actual <- extract_value_from_tabs_output(output, check$name)

    # Compare based on type
    if (check$type == "numeric") {
      check_numeric(
        name = paste("Tabs basic:", check$description),
        actual = actual,
        expected = check$value,
        tolerance = check$tolerance
      )
    } else if (check$type == "logical") {
      check_logical(
        name = paste("Tabs basic:", check$description),
        actual = actual,
        expected = check$value
      )
    } else if (check$type == "integer") {
      check_integer(
        name = paste("Tabs basic:", check$description),
        actual = actual,
        expected = check$value
      )
    }
  }
})

# Helper to extract values from Tabs output
# NOTE: This needs to be customized to your actual output structure
extract_value_from_tabs_output <- function(output, check_name) {
  # Example structure - adjust to your actual output
  switch(check_name,
    "overall_mean_satisfaction" = output$summary$overall_mean,
    "cell_wave2_male_top2box" = output$crosstab[output$crosstab$wave == 2 &
                                                  output$crosstab$gender == "Male",
                                                  "top2box_pct"],
    "sig_flag_male_vs_female" = output$sig_tests[output$sig_tests$comparison == "Male_vs_Female",
                                                   "significant"],
    "base_size_total" = nrow(output$data),
    "effective_n_weighted" = output$weighting$effective_n,
    stop("Unknown check: ", check_name)
  )
}
```

### Main Runner (`tests/regression/run_all_regression.R`)

```r
#!/usr/bin/env Rscript
# Run all TURAS regression tests

library(testthat)

cat("================================================================================\n")
cat("TURAS REGRESSION TEST HARNESS\n")
cat("================================================================================\n\n")

# Run all regression tests
results <- test_dir(
  "tests/regression",
  reporter = "check",
  pattern = "^test_regression_.*\\.R$"
)

# Summary
cat("\n================================================================================\n")
if (all(results$passed)) {
  cat("✅ TURAS SELF-CHECK PASSED\n")
  cat("All regression tests passed successfully.\n")
  quit(status = 0)
} else {
  cat("❌ TURAS SELF-CHECK FAILED\n")
  cat("Some regression tests failed. Review output above.\n")
  quit(status = 1)
}
```

---

## Risk Mitigation: How to Avoid Breaking Existing Code

### 🛡️ Safety Measures

1. **Separate Directory Structure**
   - All new code goes in `/tests/regression/`
   - No modifications to `/modules/` code initially
   - No changes to existing `/tests/testthat/` tests

2. **Non-Invasive Integration**
   - Regression tests call existing module entry points
   - No refactoring required to start
   - Tests adapt to current module structure

3. **Phased Rollout**
   - Start with ONE module (Tabs)
   - Validate approach before expanding
   - Learn and adjust before committing to all modules

4. **Version Control**
   - Create feature branch for this work
   - Commit frequently with clear messages
   - Easy to revert if needed

5. **Optional Execution**
   - Regression tests are opt-in initially
   - Don't block existing workflows
   - Can be skipped during development

6. **Documentation First**
   - Write READMEs before code
   - Clear examples and rationale
   - Make it easy for future maintainers

### ⚠️ What Could Go Wrong & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Module APIs not stable | Medium | High | Document current API; tests adapt to changes |
| Output structure differs per run | Low | Medium | Use tolerance; check structure not exact format |
| Maintenance burden | Medium | Medium | Keep checks minimal (5-10 per module); automate updates |
| False positives/flakes | Low | Medium | Set appropriate tolerances; rerun failed tests |
| Slows development | Low | Low | Make tests fast (<10 seconds total); optional during dev |

---

## Success Criteria

### ✅ Phase 1-2 Success (Tabs POC)

- [ ] `/examples/tabs/basic/` exists with working example
- [ ] Golden values file created and documented
- [ ] Regression test passes on current code
- [ ] Test can be run via `Rscript tests/regression/test_regression_tabs.R`
- [ ] Documentation updated
- [ ] Example serves as useful tutorial

### ✅ Phase 5 Success (Full System)

- [ ] Regression tests exist for Tabs, Tracker, Confidence
- [ ] One-command execution: `Rscript tests/regression/run_all_regression.R`
- [ ] All tests pass on current codebase
- [ ] Clear pass/fail reporting
- [ ] Documentation complete
- [ ] Zero broken existing functionality

### ✅ Long-term Success

- [ ] Tests catch real regressions during development
- [ ] Developers run tests before committing changes
- [ ] New modules automatically get regression tests
- [ ] Golden values updated when behavior intentionally changes
- [ ] Tests run in <30 seconds total
- [ ] Everyone trusts the test suite

---

## Next Steps

### Immediate Actions (This Week)

1. **Review & Approve Plan**
   - Read this document
   - Discuss any concerns
   - Approve or request changes

2. **Create Branch**
   ```bash
   git checkout -b feature/regression-test-harness
   ```

3. **Start Phase 1**
   - Create directory structure
   - Write helper functions
   - Update documentation

### Decision Points

**Decision 1: Start Now or Later?**
- **Now:** Start with Tabs module POC (2-3 weeks effort)
- **Later:** Defer until after other priorities

**Decision 2: DIY or Assisted?**
- **DIY:** Follow this plan, implement yourself
- **Assisted:** I can help implement if you want

**Decision 3: Scope**
- **Minimal:** Just Tabs module as POC
- **Standard:** Tabs + Tracker + Confidence (recommended)
- **Full:** All production modules

---

## Appendix: ChatGPT Full Recommendations

The full ChatGPT recommendations are stored in:
- `turas harness.txt` (this repository)

Key points from ChatGPT:
- ✅ Small test harness with 2-3 tiny datasets
- ✅ Check cell values, CIs, sig flags
- ✅ One command: "Run Turas self-check"
- ✅ Use `/examples/` for both tutorials and tests
- ✅ Store expected values in YAML (I suggest JSON instead)
- ✅ Simple assertion helpers
- ✅ Optional Shiny button integration

---

## Questions & Answers

**Q: Will this slow down development?**
A: No - tests are optional during development, and run in <30 seconds once set up.

**Q: How much work is this?**
A: Phase 1-2 (Tabs POC): ~2-3 weeks. Full system (3 modules): ~4-5 weeks.

**Q: Can we do this incrementally?**
A: Yes - start with Tabs, validate approach, then expand.

**Q: What if module output changes?**
A: Update the golden values file - it's designed to be easily updatable.

**Q: Will this replace existing tests?**
A: No - this complements existing unit tests with end-to-end regression tests.

**Q: What's the maintenance burden?**
A: Low - only update when module behavior intentionally changes (rare).

---

**RECOMMENDATION: Proceed with Phase 1-2 (Tabs POC) to validate the approach before committing to full implementation.**

---

*Document prepared by: Claude*
*Based on: ChatGPT recommendations + TURAS architecture review*
*Status: Ready for review and approval*
