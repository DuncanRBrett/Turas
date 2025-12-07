# TURAS Quick Launch Guide

**Version:** 1.0
**Updated:** 2025-12-07

---

## Launch TURAS Modules

### Prerequisites
```r
install.packages(c("openxlsx", "readxl", "data.table", "testthat"))
```

### Run a Module

**1. AlchemerParser** - Parse Alchemer exports for Tabs
```r
setwd("/path/to/Turas")
source("modules/AlchemerParser/run_parser_gui.R")
# Browse to your Alchemer files and click Parse
```

**2. Tabs** - Generate cross-tabulation reports
```r
source("modules/tabs/run_tabs_gui.R")
# Browse to config file and click Run
# Or use CLI: source("modules/tabs/R/00_main.R")
```

**3. Tracker** - Analyze multi-wave tracking studies
```r
source("modules/tracker/R/00_main.R")
run_tracker_analysis("config.xlsx")
```

**4. Confidence** - Calculate confidence intervals
```r
source("modules/confidence/R/00_main.R")
run_confidence_analysis("config.xlsx")
```

**5. Segment** - Multi-dimensional segmentation
```r
source("modules/segment/R/00_main.R")
run_segmentation("config.xlsx")
```

**6. Conjoint** - Conjoint analysis with market simulator
```r
# Load all modules first (see USER_MANUAL.md)
source("modules/conjoint/R/00_main.R")
run_conjoint_analysis("config.xlsx")
```

---

## Run Regression Tests

### Quick Self-Check
```r
# From Turas root directory
Rscript tests/regression/run_all_regression_tests.R
```

### Run Specific Module Tests
```r
library(testthat)

# Unit tests
test_dir("tests/testthat")

# Regression tests
test_file("tests/regression/test_regression_tabs.R")
test_file("tests/regression/test_regression_tracker.R")
test_file("tests/regression/test_regression_confidence.R")
```

### From Command Line
```bash
# All tests
Rscript tests/testthat.R

# Regression tests only
Rscript -e "library(testthat); test_dir('tests/regression')"
```

### Expected Result
```
✓ | OK F W S | Context
✓ |  X 0 0 0 | Module tests
```
- ✓ = Pass
- F = Failure (investigate!)
- W = Warning (review)
- S = Skipped (integration incomplete)

---

## Troubleshooting

**"testthat not found"**
```r
install.packages("testthat")
```

**"Working directory wrong"**
```r
setwd("/path/to/Turas")  # Must be Turas root
```

**"Cannot source module files"**
- Check you're in Turas root: `getwd()`
- Verify file exists: `file.exists("modules/tabs/R/00_main.R")`

---

**For detailed documentation, see each module's USER_MANUAL.md**
