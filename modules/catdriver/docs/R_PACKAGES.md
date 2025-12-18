# R Package Dependencies - Categorical Key Driver Module

**Version:** 1.0
**Date:** December 2024

---

## Package Summary

The Categorical Key Driver module requires the following R packages:

| Package | Required | Purpose | CRAN | Notes |
|---------|----------|---------|------|-------|
| MASS | **Yes** | Ordinal logistic regression | Yes | Part of R recommended packages |
| nnet | **Yes** | Multinomial logistic regression | Yes | Part of R recommended packages |
| car | **Yes** | Statistical tests and diagnostics | Yes | Widely used, well-maintained |
| openxlsx | **Yes** | Excel file I/O | Yes | No Java dependency |
| haven | No | SPSS/Stata file support | Yes | Only needed for .sav/.dta files |
| shiny | GUI only | Web application framework | Yes | Only for GUI usage |
| shinyFiles | GUI only | File browser widgets | Yes | Only for GUI usage |

---

## Core Statistical Packages

### MASS (Modern Applied Statistics with S)

**Purpose:** Provides `polr()` function for ordinal logistic regression using the proportional odds (cumulative logit) model.

**Why This Package:**
- Part of R's recommended packages (installed by default)
- Industry standard for ordinal regression
- Maintained by R Core Team (Brian Ripley)
- Well-documented and extensively tested
- Provides Hessian matrix for standard error calculation

**Functions Used:**
- `polr()` - Proportional odds logistic regression

**License:** GPL-2 | GPL-3

**Alternative Considered:** `ordinal::clm()` offers more flexibility but adds complexity and another dependency. MASS is sufficient for our needs and more widely available.

---

### nnet (Feed-Forward Neural Networks and Multinomial Log-Linear Models)

**Purpose:** Provides `multinom()` function for multinomial logistic regression.

**Why This Package:**
- Part of R's recommended packages (installed by default)
- Standard choice for multinomial logistic regression
- Maintained by R Core Team (Brian Ripley, William Venables)
- Stable API since R 1.0
- Good convergence properties

**Functions Used:**
- `multinom()` - Multinomial logistic regression

**License:** GPL-2 | GPL-3

**Alternative Considered:** `mlogit` package offers more features for discrete choice modeling but is more complex to use. `nnet::multinom()` is simpler and covers our use case well.

---

### car (Companion to Applied Regression)

**Purpose:** Provides Type II Wald tests for variable importance and variance inflation factors for multicollinearity diagnostics.

**Why This Package:**
- Gold standard for regression diagnostics in R
- Provides proper Type II tests that handle factors correctly
- `Anova()` automatically aggregates dummy variables to factor-level
- `vif()` provides Generalized VIF for categorical predictors
- Maintained by John Fox (author of Applied Regression textbook)

**Functions Used:**
- `Anova()` - Type II Wald chi-square tests
- `vif()` - Variance Inflation Factors

**License:** GPL-2 | GPL-3

**Alternative Considered:** Could calculate chi-square manually from z-values, but `car::Anova()` handles factors properly and is more reliable. The code includes a fallback to z-value calculation if car fails.

---

## Data I/O Packages

### openxlsx

**Purpose:** Read and write Excel files (.xlsx format).

**Why This Package:**
- No Java dependency (unlike xlsx, XLConnect)
- Fast performance for large files
- Excellent formatting capabilities (styles, conditional formatting)
- Can write formulas and multiple sheets
- Active maintenance (rOpenSci ecosystem)

**Functions Used:**
- `read.xlsx()` - Read Excel sheets
- `createWorkbook()` - Create new workbook
- `addWorksheet()` - Add sheets
- `writeData()` - Write data to sheets
- `createStyle()` - Define cell formatting
- `addStyle()` - Apply styles
- `saveWorkbook()` - Save to file
- `getSheetNames()` - List available sheets

**License:** MIT

**Alternative Considered:**
- `xlsx` requires Java - problematic for deployment
- `readxl` only reads, doesn't write
- `writexl` writes but limited formatting
- openxlsx provides best balance of features and reliability

---

### haven (Optional)

**Purpose:** Read SPSS (.sav) and Stata (.dta) files.

**Why This Package:**
- Part of tidyverse ecosystem (well-maintained)
- Correctly handles labelled variables
- Preserves variable and value labels
- Good performance

**Functions Used:**
- `read_sav()` - Read SPSS files
- `read_dta()` - Read Stata files
- `as_factor()` - Convert labelled to factor

**License:** MIT

**Note:** This package is optional. The module works without it if users only need CSV/Excel support. A helpful error message is shown if user tries to load .sav/.dta without haven installed.

---

## GUI Packages

### shiny

**Purpose:** Web application framework for the graphical user interface.

**Why This Package:**
- De facto standard for R web apps
- Maintained by RStudio/Posit
- Extensive documentation and community
- Used throughout Turas for consistency

**Functions Used:**
- UI components: `fluidPage()`, `div()`, `actionButton()`, etc.
- Server components: `reactive()`, `observeEvent()`, `renderText()`
- App construction: `shinyApp()`

**License:** GPL-3

---

### shinyFiles

**Purpose:** File and directory browser widgets for Shiny.

**Why This Package:**
- Native file dialogs in Shiny apps
- Cross-platform (Windows, Mac, Linux)
- Security-aware (can restrict to specific directories)
- Used throughout Turas for consistency

**Functions Used:**
- `shinyDirButton()` - Directory selection button
- `shinyDirChoose()` - Directory chooser handler
- `parseDirPath()` - Parse selected directory

**License:** GPL-3

---

## Installation Instructions

### Minimum Installation (Headless/Script Use)

```r
install.packages(c("MASS", "nnet", "car", "openxlsx"))
```

Note: MASS and nnet are typically pre-installed as recommended packages.

### Full Installation (With GUI and SPSS/Stata Support)

```r
install.packages(c(
  "MASS",        # Ordinal logistic
  "nnet",        # Multinomial logistic
  "car",         # Statistical tests
  "openxlsx",    # Excel I/O
  "haven",       # SPSS/Stata support
  "shiny",       # Web app framework
  "shinyFiles"   # File browser widgets
))
```

### Version Requirements

The module is designed to work with current CRAN versions. Minimum tested versions:

| Package | Minimum Version | Tested With |
|---------|-----------------|-------------|
| R | 4.0.0 | 4.3.x |
| MASS | 7.3-50 | 7.3-60 |
| nnet | 7.3-12 | 7.3-19 |
| car | 3.0-0 | 3.1-2 |
| openxlsx | 4.2.0 | 4.2.5 |
| haven | 2.4.0 | 2.5.4 |
| shiny | 1.7.0 | 1.8.0 |
| shinyFiles | 0.9.0 | 0.9.3 |

---

## Package Justification for External Review

### Selection Criteria

All packages were selected based on:

1. **Stability**: Established packages with long track records
2. **Maintenance**: Actively maintained with regular updates
3. **CRAN**: Available on CRAN (quality assurance)
4. **License**: Compatible with GPL/MIT (permissive)
5. **Dependencies**: Minimal dependency chains
6. **Consistency**: Already used elsewhere in Turas where applicable

### Packages NOT Used (and Why)

| Package | Reason Not Used |
|---------|-----------------|
| tidyverse/dplyr | Added complexity, base R sufficient for our needs |
| broom | Would simplify coefficient extraction but adds dependency |
| ggplot2 | No visualization required in output |
| VGAM | More flexible ordinal models but adds complexity |
| mlogit | Advanced choice modeling features not needed |
| xlsx/XLConnect | Java dependency problematic for deployment |
| ordinal | Additional features not required |

### Dependency Chain

The module has a shallow dependency tree:

```
catdriver
├── MASS (depends: R only)
├── nnet (depends: R only)
├── car (depends: carData, abind, pbkrtest, quantreg, lme4, ...)
├── openxlsx (depends: Rcpp, zip, stringi)
├── haven [optional] (depends: Rcpp, readr, tibble, ...)
├── shiny [GUI only] (depends: httpuv, htmltools, ...)
└── shinyFiles [GUI only] (depends: shiny, fs)
```

The `car` package has the deepest dependency tree, but these are all well-established statistical packages.

---

## Security Notes

All packages are:
- Available from official CRAN mirrors
- Digitally signed by CRAN
- Open source with public code review
- Free of known security vulnerabilities (as of review date)

No packages:
- Execute arbitrary system commands
- Require network access during analysis
- Write to locations outside user-specified paths
- Collect or transmit user data

---

## Contact

For package-related questions or to request support for additional file formats, refer to the Turas documentation.
