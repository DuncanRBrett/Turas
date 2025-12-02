# Bug Fix Testing Guide

This guide helps you test all 17 critical bug fixes before merging to main.

## Current Branch
`claude/fix-critical-bugs-01ReEWbkVNoaQJBCh6HX7gH6`

---

## Quick Validation Tests

### Test 1: Tabs Module (MOST IMPORTANT - Your Most-Used Module)

**What was fixed:**
- CR-TABS-001: Added MAX_DECIMAL_PLACES constant (was undefined)
- CR-TABS-002: Fixed namespace pollution
- CR-TABS-003: Improved log_issue() documentation

**Test with your existing Tabs workflow:**

```r
# Navigate to your Turas directory
setwd("/path/to/Turas")  # Change this to your actual path

# Run your normal Tabs analysis
source("modules/tabs/run_tabs.R")

# Or if you use run_tabs_gui():
source("modules/tabs/run_tabs_gui.R")
run_tabs_gui()

# Load your existing config and data
# This should work EXACTLY as before - no breaking changes
```

**What to check:**
- ✅ No errors about "MAX_DECIMAL_PLACES not found"
- ✅ Results match your previous runs (should be identical)
- ✅ All decimal rounding works correctly

---

### Test 2: Tracker Module (If You Use Multi-Wave Tracking)

**What was fixed:**
- CR-TRACKER-001: Fixed file validation logic error
- CR-TRACKER-002: Removed hard-coded user paths
- CR-TRACKER-003: Added division by zero protection
- CR-TRACKER-004: Actually exclude invalid weights
- CR-TRACKER-005: Proper z-test for NPS (BIGGEST CHANGE)

**Test with your existing Tracker workflow:**

```r
# Run your normal Tracker analysis
source("modules/tracker/run_tracker.R")

# Or GUI version:
source("modules/tracker/run_tracker_gui.R")
run_tracker_gui()
```

**What to check:**
- ✅ No division by zero errors if you have percentage changes
- ✅ NPS significance tests may be DIFFERENT (more statistically accurate)
  - Old method: Simple 10-point threshold
  - New method: Proper z-test
  - **This is EXPECTED and CORRECT**
- ✅ Invalid weights properly excluded
- ✅ No errors about file paths

**IMPORTANT:** If you see different NPS significance results, that's GOOD - the old method was statistically invalid.

---

### Test 3: Confidence Module (If You Use Confidence Analysis)

**What was fixed:**
- CR-CONF-001: Fixed wrong field name (posterior_mean → post_mean)
- CR-CONF-002: Fixed weight filtering index mismatch
- CR-CONF-003: Use weighted SD with weighted data (STATISTICAL FIX)

**Test with your existing Confidence workflow:**

```r
source("modules/confidence/run_confidence.R")
```

**What to check:**
- ✅ No errors about missing fields
- ✅ Weighted analysis may show DIFFERENT confidence intervals (more accurate)
  - Old method: Used unweighted SD even with weights (WRONG)
  - New method: Proper weighted SD (CORRECT)
  - **This is EXPECTED if you use weights**

---

### Test 4: Parser Module (If You Use Questionnaire Parsing)

**What was fixed:**
- CR-PARSER-001: No longer auto-installs packages (security fix)
- CR-PARSER-002: Added file validation (type and size checks)

**Test:**

```r
source("modules/parser/run_parser.R")
run_parser()

# Upload a .docx questionnaire file
# Should work normally with valid files
```

**What to check:**
- ✅ If missing packages, you get CLEAR ERROR MESSAGE (not auto-install)
- ✅ Non-.docx files are rejected with clear message
- ✅ Files >50MB are rejected
- ✅ Valid .docx files parse normally

---

### Test 5: Segment Module (If You Use Segmentation)

**What was fixed:**
- CR-SEG-001: Removed hard-coded user paths
- CR-SEG-002: Added cluster package check
- CR-SEG-003: Added validation for division by zero

**Test:**

```r
source("modules/segment/run_segment.R")
```

**What to check:**
- ✅ No errors about user paths
- ✅ Clear error if cluster package missing
- ✅ No division by zero errors

---

## Comprehensive Test (Recommended)

If you want to be thorough, run ALL your existing workflows:

```r
# 1. Run Tabs analysis with your latest project
# 2. Run Tracker if you have multi-wave data
# 3. Run Confidence if you use it
# 4. Run Parser if you use it
# 5. Run Segment if you use it
```

**Expected Results:**
- Everything should work EXACTLY as before
- EXCEPT:
  - Tracker NPS significance tests (more accurate now)
  - Confidence weighted SD (more accurate now)
  - Parser package install (now shows error instead of auto-installing)

---

## Quick Smoke Test (2 minutes)

If you just want to verify nothing is broken:

```r
# Test that modules load without errors
source("modules/tabs/lib/validation.R")
source("modules/tabs/lib/shared_functions.R")
source("modules/tracker/trend_calculator.R")
source("modules/confidence/R/00_main.R")

# If no errors, basic structure is intact
print("✅ All modules loaded successfully!")
```

---

## What to Report Back

After testing, tell me:

1. **Which modules did you test?** (Tabs, Tracker, etc.)
2. **Any errors?** (Copy the full error message)
3. **Different results?** (Expected for NPS tests and weighted Confidence)
4. **Ready to merge?** (Yes/No)

---

## If You Find Issues

If something breaks:

1. **Don't panic** - we can fix it
2. **Save the error message** - exact text helps
3. **Note which module** - Parser, Tabs, Tracker, etc.
4. **Tell me what you were doing** - helps reproduce

You can always switch back to main with:
```bash
git checkout main
```

---

## Merge When Ready

Once testing passes:

```bash
# Merge via GitHub (recommended)
# 1. Go to: https://github.com/DuncanRBrett/Turas/pull/new/claude/fix-critical-bugs-01ReEWbkVNoaQJBCh6HX7gH6
# 2. Click "Create pull request"
# 3. Review changes
# 4. Click "Merge pull request"

# Or merge locally (faster but less visible)
git checkout main
git merge claude/fix-critical-bugs-01ReEWbkVNoaQJBCh6HX7gH6
git push origin main
```

---

**Current Status:** Testing bug fixes on branch `claude/fix-critical-bugs-01ReEWbkVNoaQJBCh6HX7gH6`
