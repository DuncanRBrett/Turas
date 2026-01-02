# TURAS DEPENDENCY RESOLUTION GUIDE
**Last Updated:** 2025-12-25
**Status:** ✅ ALL DEPENDENCIES AVAILABLE ON CRAN

---

## EXECUTIVE SUMMARY

**GOOD NEWS:** After investigation, both packages flagged as potentially problematic are **AVAILABLE on CRAN**:

| Package | Status | Installation | Last Verified |
|---------|--------|--------------|---------------|
| **anesrake** | ✅ Available | `install.packages("anesrake")` | July 22, 2025 |
| **ordinal** | ✅ Available | `install.packages("ordinal")` | July 22, 2025 |

The initial concern was based on historical information. Both packages are maintained and installable.

---

## PACKAGE STATUS INVESTIGATION

### 1. anesrake (Weighting Module)

**Current Status:** ✅ **AVAILABLE ON CRAN**

**Evidence:**
- [CRAN Package Page](https://cran.r-project.org/web/packages/anesrake/index.html)
- [Package PDF (July 22, 2025)](https://cran.r-project.org/web/packages/anesrake/anesrake.pdf)
- Version: 0.80 (Date: 2018-04-27)
- [GitHub Mirror](https://github.com/cran/anesrake)

**Installation:**
```r
install.packages("anesrake")
library(anesrake)

# Verify installation
packageVersion("anesrake")  # Should show 0.80
```

**Purpose in Turas:**
- Implements iterative proportional fitting (raking) for survey weights
- Adjusts sample weights to match multiple target marginal distributions
- Used by Weighting module for rim weighting

**File:** `modules/weighting/lib/rim_weights.R`

---

### 2. ordinal (CatDriver Module)

**Current Status:** ✅ **AVAILABLE ON CRAN**

**Evidence:**
- [CRAN Package Page](https://cran.r-project.org/web/packages/ordinal/index.html)
- [Package PDF (July 22, 2025)](https://cran.r-project.org/web/packages/ordinal/ordinal.pdf)
- [CLM Article/Vignette](https://cran.r-project.org/web/packages/ordinal/vignettes/clm_article.pdf)

**Installation:**
```r
install.packages("ordinal")
library(ordinal)

# Verify installation
packageVersion("ordinal")
```

**Purpose in Turas:**
- Implements cumulative link models (CLM) for ordinal regression
- Superior to MASS::polr in terms of features and convergence
- Supports partial proportional odds, nominal tests, mixed models

**File:** `modules/catdriver/R/04a_ordinal.R`

**Note:** CatDriver **already implements robust fallback** to MASS::polr if ordinal unavailable (lines 35-106).

---

## WHY USE THESE PACKAGES?

### anesrake vs. Alternatives

**anesrake Advantages:**
- Industry-standard algorithm used by American National Election Studies
- Well-tested implementation
- Handles convergence gracefully

**Modern Alternatives (if needed):**

1. **[autumn](https://github.com/aaronrudkin/autumn)** - Faster, modern alternative
   - 67% faster than anesrake
   - 1/3 less memory allocation
   - Tidy-friendly syntax
   - Not yet on CRAN (install from GitHub)

2. **survey::rake()** - Built into survey package
   - Part of comprehensive survey analysis ecosystem
   - Well-maintained, widely used
   - Different API than anesrake

3. **[pewmethods](https://medium.com/pew-research-center-decoded/weighting-survey-data-with-the-pewmethods-r-package-d040afb0d2c2)** - Pew Research Center
   - Complete weighting workflow
   - Includes cleaning, recoding, raking, trimming

**Turas Choice:** Stick with **anesrake** (established, stable, meets needs)

---

### ordinal::clm vs. MASS::polr

**ordinal::clm Advantages:**
- More stable convergence for complex models
- Partial proportional odds effects
- Likelihood ratio tests of proportional odds assumption
- Mixed models via Laplace approximation
- Better standard error estimation

**MASS::polr Advantages:**
- Built into R (no extra dependency)
- Simpler implementation
- Sufficient for basic ordinal regression

**Turas Implementation:**
```r
# Primary: ordinal::clm (if available)
if (requireNamespace("ordinal", quietly = TRUE)) {
  model <- ordinal::clm(formula, data = data, link = "logit")
} else {
  # Fallback: MASS::polr (always available)
  model <- MASS::polr(formula, data = data, Hess = TRUE, method = "logistic")
}
```

**Turas Choice:** Use **ordinal::clm** with automatic **MASS::polr** fallback (already implemented)

---

## INSTALLATION TROUBLESHOOTING

### Common Issues & Solutions

#### Issue 1: Package Compilation Fails (Windows)

**Symptom:**
```
ERROR: compilation failed for package 'anesrake'
```

**Solution:**
```r
# Install pre-compiled binary (Windows)
install.packages("anesrake", type = "win.binary")
install.packages("ordinal", type = "win.binary")
```

---

#### Issue 2: Package Not Found

**Symptom:**
```
Warning: package 'anesrake' is not available for this version of R
```

**Solution 1 - Update R:**
```r
# Check R version (need 3.5.0+)
R.version.string

# Update R if needed
# Windows: Download from https://cran.r-project.org/bin/windows/base/
# Mac: Download from https://cran.r-project.org/bin/macosx/
# Linux: Use package manager (e.g., sudo apt-get update && sudo apt-get install r-base)
```

**Solution 2 - Specify CRAN Mirror:**
```r
# Set CRAN mirror explicitly
options(repos = c(CRAN = "https://cloud.r-project.org/"))
install.packages("anesrake")
install.packages("ordinal")
```

---

#### Issue 3: Dependencies Not Installed

**Symptom:**
```
ERROR: dependency 'Hmisc' is not available for package 'anesrake'
```

**Solution:**
```r
# Install dependencies first
install.packages("Hmisc")
install.packages("weights")

# Then install target package
install.packages("anesrake")
```

---

#### Issue 4: Network/Firewall Blocking CRAN

**Solution - Download & Install Manually:**

1. Download package source:
   - anesrake: https://cran.r-project.org/src/contrib/anesrake_0.80.tar.gz
   - ordinal: https://cran.r-project.org/web/packages/ordinal/index.html

2. Install from local file:
```r
install.packages("path/to/anesrake_0.80.tar.gz", repos = NULL, type = "source")
```

---

## VERIFICATION SCRIPT

Run this to check all critical Turas dependencies:

```r
# ==============================================================================
# TURAS DEPENDENCY VERIFICATION SCRIPT
# ==============================================================================

# List of critical packages
critical_packages <- list(
  # Core I/O
  "openxlsx" = "All modules",
  "readxl" = "All modules",

  # Potentially problematic (per review)
  "anesrake" = "Weighting module (rim weighting)",
  "ordinal" = "CatDriver module (ordinal regression)",

  # Statistical engines
  "MASS" = "CatDriver fallback, Segment (always in base R)",
  "survival" = "Conjoint, MaxDiff (conditional logit)",
  "mlogit" = "Conjoint (choice models)",
  "car" = "KeyDriver, CatDriver (Type II ANOVA)",

  # Advanced analytics
  "xgboost" = "KeyDriver (SHAP analysis)",
  "shapviz" = "KeyDriver (SHAP visualization)"
)

# Check installation status
cat("\n")
cat(strrep("=", 70), "\n")
cat("TURAS DEPENDENCY VERIFICATION\n")
cat(strrep("=", 70), "\n\n")

missing <- character()
installed <- character()

for (pkg in names(critical_packages)) {
  status <- requireNamespace(pkg, quietly = TRUE)

  if (status) {
    version <- tryCatch(
      as.character(packageVersion(pkg)),
      error = function(e) "unknown"
    )
    cat(sprintf("✅ %-15s v%-10s (%s)\n", pkg, version, critical_packages[[pkg]]))
    installed <- c(installed, pkg)
  } else {
    cat(sprintf("❌ %-15s MISSING        (%s)\n", pkg, critical_packages[[pkg]]))
    missing <- c(missing, pkg)
  }
}

cat("\n", strrep("=", 70), "\n")
cat(sprintf("Summary: %d installed, %d missing\n", length(installed), length(missing)))
cat(strrep("=", 70), "\n\n")

if (length(missing) > 0) {
  cat("TO INSTALL MISSING PACKAGES:\n\n")
  cat(sprintf('install.packages(c(%s))\n\n',
              paste(sprintf('"%s"', missing), collapse = ", ")))
} else {
  cat("✅ All critical dependencies installed!\n\n")
}
```

**Expected Output:**
```
======================================================================
TURAS DEPENDENCY VERIFICATION
======================================================================

✅ openxlsx       v4.2.5     (All modules)
✅ readxl         v1.4.3     (All modules)
✅ anesrake       v0.80      (Weighting module (rim weighting))
✅ ordinal        v2023.12-4 (CatDriver module (ordinal regression))
✅ MASS           v7.3-60    (CatDriver fallback, Segment (always in base R))
✅ survival       v3.5-7     (Conjoint, MaxDiff (conditional logit))
...

======================================================================
Summary: 10 installed, 0 missing
======================================================================

✅ All critical dependencies installed!
```

---

## DEFENSIVE PROGRAMMING RECOMMENDATIONS

Even though both packages are available, we should maintain robust fallbacks:

### 1. Weighting Module: Add survey::rake() Fallback

**Current:** Stops if anesrake unavailable
**Recommended:** Fall back to survey::rake()

**Implementation Location:** `modules/weighting/lib/rim_weights.R`

**Pseudocode:**
```r
calculate_rim_weights <- function(...) {
  if (requireNamespace("anesrake", quietly = TRUE)) {
    # Primary: anesrake (current implementation)
    use_anesrake(...)
  } else if (requireNamespace("survey", quietly = TRUE)) {
    # Fallback: survey::rake()
    use_survey_rake(...)
    warning("Using survey::rake() fallback (anesrake not available)")
  } else {
    # Refuse: Neither available
    weighting_refuse(
      code = "PKG_RAKING_UNAVAILABLE",
      title = "Raking Packages Not Available",
      problem = "Neither 'anesrake' nor 'survey' package installed",
      why_it_matters = "Cannot perform rim weighting without raking engine",
      how_to_fix = "Install either: install.packages('anesrake') OR install.packages('survey')"
    )
  }
}
```

**Priority:** Medium (defensive measure, not critical since anesrake is available)

---

### 2. CatDriver Module: Document Existing Fallback

**Status:** ✅ **ALREADY IMPLEMENTED**

The CatDriver module **already has robust fallback logic** in `04a_ordinal.R`:
- Lines 35-59: Try ordinal::clm
- Lines 65-106: Fall back to MASS::polr if ordinal unavailable
- Lines 108: Updates guard state to track fallback usage

**No action needed** - this is exemplary defensive programming.

---

## PACKAGE UPDATE POLICY

### When to Update

| Update Type | Action | Testing Required |
|-------------|--------|------------------|
| Patch (0.80 → 0.80.1) | Update immediately | Smoke test |
| Minor (0.80 → 0.81) | Test in dev, then update | Regression test |
| Major (0.80 → 1.0) | Extensive testing | Full test suite |

### How to Update

```r
# Check for updates
old.packages()

# Update specific package
update.packages("anesrake", ask = FALSE)
update.packages("ordinal", ask = FALSE)

# Update all packages (careful!)
update.packages(ask = FALSE)
```

### Testing After Update

```r
# 1. Check version
packageVersion("anesrake")
packageVersion("ordinal")

# 2. Run module tests
source("modules/weighting/tests/test_weighting.R")
source("modules/catdriver/tests/test_catdriver.R")

# 3. Run example workflow
source("examples/weighting/example_workflow.R")
source("examples/catdriver/example_workflow.R")
```

---

## FUTURE-PROOFING RECOMMENDATIONS

### Short-Term (Next 6 Months)

1. ✅ **Monitor package status** - Both packages are stable
2. ✅ **Document installation** - This guide covers it
3. ⚠️ **Add survey::rake() fallback** - Defensive measure for Weighting module

### Long-Term (12-24 Months)

1. **Consider autumn package** - If it moves to CRAN
   - 67% faster than anesrake
   - Modern tidy syntax
   - More memory efficient

2. **Evaluate survey ecosystem** - If more features needed
   - Comprehensive survey analysis
   - Post-stratification, calibration, variance estimation

3. **Monitor ordinal package** - Track for breaking changes
   - Currently stable and well-maintained
   - Academic backing (Rune Christensen)

---

## SUPPORT RESOURCES

### Package Documentation

**anesrake:**
- [Official Manual (PDF)](https://cran.r-project.org/web/packages/anesrake/anesrake.pdf)
- [GitHub Mirror](https://github.com/cran/anesrake)
- [Academic Paper](https://surveyinsights.org/wp-content/uploads/2014/07/Full-anesrake-paper.pdf)

**ordinal:**
- [Official Manual (PDF)](https://cran.r-project.org/web/packages/ordinal/ordinal.pdf)
- [CLM Article/Vignette](https://cran.r-project.org/web/packages/ordinal/vignettes/clm_article.pdf)
- [R Companion Handbook](https://rcompanion.org/handbook/G_01.html)

### Getting Help

1. **Installation issues:**
   ```r
   # Check R version
   R.version.string

   # Get package info
   help(package = "anesrake")
   help(package = "ordinal")

   # Check installation
   find.package("anesrake")
   find.package("ordinal")
   ```

2. **Usage questions:**
   - See module USER_MANUAL.md files
   - Check package vignettes: `browseVignettes("ordinal")`

3. **Bug reports:**
   - Turas-specific: GitHub Issues
   - Package-specific: CRAN maintainer contact

---

## CONCLUSION

### ✅ GOOD NEWS

Both packages flagged as problematic are **fully available on CRAN**:
- **anesrake** v0.80 - Stable, maintained
- **ordinal** - Actively maintained, July 2025 documentation

### ✅ CURRENT STATUS

- **Weighting module:** Uses anesrake successfully
- **CatDriver module:** Already has ordinal::clm + MASS::polr fallback

### 📋 RECOMMENDED ACTIONS

1. **Immediate:** Update review documents to reflect correct status
2. **Short-term:** Add survey::rake() fallback to Weighting module (defensive)
3. **Ongoing:** Monitor package updates, test before major version changes

### 📊 RISK ASSESSMENT

| Package | Risk Level | Mitigation | Status |
|---------|-----------|------------|---------|
| anesrake | 🟢 **LOW** | survey::rake() fallback | Recommended |
| ordinal | 🟢 **LOW** | MASS::polr fallback | ✅ Implemented |

---

**Last Verified:** 2025-12-25
**Next Review:** Q2 2026 (after major R version release)

**Maintained by:** Turas Development Team
