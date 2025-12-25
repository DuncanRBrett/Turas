# TURAS PLATFORM - R PACKAGES REFERENCE
**Last Updated:** 2025-12-25
**Platform Version:** Turas v10.0+

This document catalogs all R packages used across the Turas platform, organized by module and functionality.

---

## COMPLETE PACKAGE LIST (Alphabetical)

### Core Dependencies (Used by 5+ modules)
| Package | Modules Using | Purpose | Installation |
|---------|---------------|---------|--------------|
| **openxlsx** | All 11 modules | Excel writing with formatting | `install.packages("openxlsx")` |
| **readxl** | All 11 modules | Excel reading (config files) | `install.packages("readxl")` |
| **ggplot2** | 7 modules | Visualization | `install.packages("ggplot2")` |
| **haven** | 6 modules | SPSS file support (.sav) | `install.packages("haven")` |
| **dplyr** | 5 modules | Data manipulation | `install.packages("dplyr")` |

### Statistical Modeling Packages
| Package | Module(s) | Purpose | Installation |
|---------|-----------|---------|--------------|
| **stats** | Base R | Linear models, kmeans, glm | Included in base R |
| **survival** | Conjoint, MaxDiff | Conditional logit (clogit) | `install.packages("survival")` |
| **mlogit** | Conjoint | Multinomial logit choice models | `install.packages("mlogit")` |
| **MASS** | Segment, CatDriver | LDA, ordinal regression (polr) | `install.packages("MASS")` |
| **car** | KeyDriver, CatDriver | Type II ANOVA, partial R² | `install.packages("car")` |
| **boot** | Confidence | Bootstrap confidence intervals | `install.packages("boot")` |

### Advanced Analytics Packages
| Package | Module(s) | Purpose | Installation |
|---------|-----------|---------|--------------|
| **xgboost** | KeyDriver | Gradient boosting for SHAP | `install.packages("xgboost")` |
| **shapviz** | KeyDriver | SHAP visualization | `install.packages("shapviz")` |
| **bayesm** | Conjoint | Hierarchical Bayes (choice models) | `install.packages("bayesm")` |
| **RSGHB** | Conjoint | Alternative HB engine | `install.packages("RSGHB")` |
| **cmdstanr** | MaxDiff | Hierarchical Bayes via Stan | See Stan installation docs |
| **ordinal** | CatDriver | Ordinal regression (clm) | `install.packages("ordinal", repos="http://www.r-project.org")` |
| **brglm2** | CatDriver | Firth's bias reduction | `install.packages("brglm2")` |
| **nnet** | CatDriver | Multinomial regression | `install.packages("nnet")` |

### Clustering & Segmentation
| Package | Module(s) | Purpose | Installation |
|---------|-----------|---------|--------------|
| **cluster** | Segment, MaxDiff | Silhouette, gap statistic | `install.packages("cluster")` |
| **poLCA** | Segment | Latent class analysis | `install.packages("poLCA")` |
| **rpart** | Segment | Decision tree rules | `install.packages("rpart")` |
| **randomForest** | Segment | Variable importance | `install.packages("randomForest")` |
| **psych** | Segment | Factor analysis, alpha | `install.packages("psych")` |

### Specialized Methodologies
| Package | Module(s) | Purpose | Installation |
|---------|-----------|---------|--------------|
| **pricesensitivitymeter** | Pricing | Van Westendorp PSM | `install.packages("pricesensitivitymeter")` |
| **anesrake** | Weighting | Rim weighting/raking | `install.packages("anesrake")` ⚠️ Archived |
| **AlgDesign** | MaxDiff | Experimental design | `install.packages("AlgDesign")` |
| **dfidx** | Conjoint | Indexed data frames for mlogit | `install.packages("dfidx")` |

### Document Processing
| Package | Module(s) | Purpose | Installation |
|---------|-----------|---------|--------------|
| **officer** | AlchemerParser | Read Word documents (.docx) | `install.packages("officer")` |
| **xml2** | AlchemerParser | XML parsing (Word internals) | `install.packages("xml2")` |
| **stringr** | AlchemerParser | String manipulation | `install.packages("stringr")` |

### Data Performance
| Package | Module(s) | Purpose | Installation |
|---------|-----------|---------|--------------|
| **data.table** | Multiple (optional) | Fast data operations | `install.packages("data.table")` |
| **writexl** | Segment, Shared | Fast Excel writing | `install.packages("writexl")` |

### Visualization Helpers
| Package | Module(s) | Purpose | Installation |
|---------|-----------|---------|--------------|
| **ggrepel** | KeyDriver | Non-overlapping labels | `install.packages("ggrepel")` |
| **patchwork** | KeyDriver | Combine ggplot2 plots | `install.packages("patchwork")` |
| **viridis** | KeyDriver | Colorblind-friendly palettes | `install.packages("viridis")` |
| **fmsb** | Segment | Radar/spider charts | `install.packages("fmsb")` |

### GUI & Interactivity
| Package | Module(s) | Purpose | Installation |
|---------|-----------|---------|--------------|
| **shiny** | All GUIs | Interactive web interfaces | `install.packages("shiny")` |
| **shinyFiles** | Weighting, others | File picker widgets | `install.packages("shinyFiles")` |

### Utilities
| Package | Module(s) | Purpose | Installation |
|---------|-----------|---------|--------------|
| **lobstr** | Tabs | Memory profiling (replaced pryr) | `install.packages("lobstr")` |
| **lubridate** | Tracker | Date parsing and manipulation | `install.packages("lubridate")` |
| **tidyr** | Conjoint | Data reshaping | `install.packages("tidyr")` |

---

## PACKAGES BY MODULE

### 1. AlchemerParser
```r
# Required
install.packages(c("openxlsx", "readxl", "officer", "xml2", "stringr"))

# Optional
install.packages("data.table")  # Performance boost for large surveys
```

### 2. Tabs
```r
# Required
install.packages(c("openxlsx", "readxl"))

# Optional
install.packages("lobstr")       # Memory profiling
install.packages("data.table")   # Fast operations
```

### 3. Tracker
```r
# Required
install.packages(c("openxlsx", "readxl", "dplyr", "lubridate"))

# Optional
install.packages("data.table")   # Multi-wave performance
```

### 4. Confidence
```r
# Required
install.packages(c("openxlsx", "readxl", "boot"))

# Optional
install.packages("data.table")   # Fast calculations
install.packages("dplyr")        # Group-wise operations
```

### 5. Segment
```r
# Required (core)
install.packages(c("openxlsx", "readxl", "writexl", "cluster"))

# Required (analysis)
install.packages(c("MASS", "rpart", "ggplot2", "fmsb"))

# Optional
install.packages("poLCA")         # Latent class analysis
install.packages("randomForest")  # Variable importance
install.packages("psych")         # Factor analysis
install.packages("haven")         # SPSS support
```

### 6. Conjoint
```r
# Required (core)
install.packages(c("openxlsx", "readxl", "mlogit", "dfidx", "survival"))

# Required (data manipulation)
install.packages(c("dplyr", "tidyr"))

# Optional (Hierarchical Bayes)
install.packages("bayesm")    # HB method 1
install.packages("RSGHB")     # HB method 2
```

### 7. KeyDriver
```r
# Required (core)
install.packages(c("openxlsx", "readxl", "car"))

# Required (SHAP analysis)
install.packages(c("xgboost", "shapviz"))

# Required (visualization)
install.packages(c("ggplot2", "ggrepel", "patchwork"))

# Optional
install.packages("viridis")   # Better color scales
install.packages("haven")     # SPSS support
```

### 8. Pricing
```r
# Required
install.packages(c("openxlsx", "readxl", "pricesensitivitymeter", "ggplot2"))

# Optional
install.packages("haven")     # SPSS support
```

### 9. MaxDiff
```r
# Required (design)
install.packages(c("openxlsx", "AlgDesign"))

# Required (analysis)
install.packages(c("survival", "ggplot2"))

# Optional (Hierarchical Bayes)
# See: https://mc-stan.org/cmdstanr/
install.packages("cmdstanr", repos = c("https://mc-stan.org/r-packages/", getOption("repos")))

# Optional (segmentation)
install.packages("cluster")
```

### 10. CatDriver
```r
# Required (core)
install.packages(c("openxlsx", "readxl", "MASS", "nnet", "car"))

# Optional (enhanced ordinal)
install.packages("ordinal")   # Superior to MASS::polr

# Optional (separation handling)
install.packages("brglm2")    # Firth's method

# Optional
install.packages("haven")      # SPSS support
install.packages("data.table") # Performance
```

### 11. Weighting
```r
# Required
install.packages(c("openxlsx", "readxl", "anesrake"))

# GUI
install.packages(c("shiny", "shinyFiles"))

# Optional
install.packages("haven")     # SPSS support
```

⚠️ **NOTE:** `anesrake` is archived on CRAN. Install from archive:
```r
install.packages("anesrake", repos = "https://cran.r-project.org/src/contrib/Archive/anesrake/")
```

---

## INSTALLATION SCRIPTS

### Minimum Installation (Core Platform)
```r
# Install all core dependencies for basic Turas functionality
install.packages(c(
  # Excel I/O
  "openxlsx", "readxl", "writexl",

  # Data manipulation
  "dplyr", "tidyr",

  # Visualization
  "ggplot2",

  # GUI
  "shiny", "shinyFiles",

  # Statistical modeling
  "survival", "MASS", "car", "boot",

  # Clustering
  "cluster"
))
```

### Full Installation (All Features)
```r
# Install all packages for complete Turas functionality
install.packages(c(
  # Core I/O
  "openxlsx", "readxl", "writexl",

  # Data manipulation
  "dplyr", "tidyr", "data.table",

  # Visualization
  "ggplot2", "ggrepel", "patchwork", "viridis", "fmsb",

  # GUI
  "shiny", "shinyFiles",

  # Statistical modeling
  "survival", "MASS", "car", "boot", "mlogit", "dfidx", "nnet", "brglm2",

  # Advanced analytics
  "xgboost", "shapviz", "bayesm", "RSGHB",

  # Clustering & segmentation
  "cluster", "poLCA", "rpart", "randomForest", "psych",

  # Specialized
  "pricesensitivitymeter", "anesrake", "AlgDesign",

  # Document processing
  "officer", "xml2", "stringr",

  # Utilities
  "lobstr", "lubridate", "haven"
))

# Optional: ordinal (not on main CRAN)
install.packages("ordinal", repos="http://www.r-project.org")

# Optional: cmdstanr (requires separate Stan installation)
# See: https://mc-stan.org/cmdstanr/
```

### Check Installed Packages
```r
# Check which Turas packages are installed
turas_packages <- c(
  "openxlsx", "readxl", "writexl", "dplyr", "tidyr", "data.table",
  "ggplot2", "ggrepel", "patchwork", "viridis", "fmsb",
  "shiny", "shinyFiles",
  "survival", "MASS", "car", "boot", "mlogit", "dfidx", "nnet", "brglm2",
  "xgboost", "shapviz", "bayesm", "RSGHB",
  "cluster", "poLCA", "rpart", "randomForest", "psych",
  "pricesensitivitymeter", "anesrake", "AlgDesign",
  "officer", "xml2", "stringr",
  "lobstr", "lubridate", "haven", "ordinal", "cmdstanr"
)

installed <- sapply(turas_packages, requireNamespace, quietly = TRUE)
missing <- turas_packages[!installed]

if (length(missing) > 0) {
  cat("Missing packages:\n")
  cat(paste("-", missing, collapse = "\n"), "\n")
} else {
  cat("All Turas packages installed!\n")
}
```

---

## PACKAGE RISK ASSESSMENT

### ✅ STATUS UPDATE (2025-12-25)

**Previous Assessment Corrected:** Both packages flagged as high-risk are actually **AVAILABLE on CRAN**.

| Package | Previous Status | Actual Status | Verified |
|---------|----------------|---------------|----------|
| **anesrake** | "Archived" ❌ | ✅ Available v0.80 | [CRAN](https://cran.r-project.org/web/packages/anesrake/) |
| **ordinal** | "Not on CRAN" ❌ | ✅ Available on CRAN | [CRAN](https://cran.r-project.org/web/packages/ordinal/) |

**See DEPENDENCY_RESOLUTION_GUIDE.md for detailed installation instructions and verification.**

### 🟢 LOW RISK (Defensive Measures Recommended)

| Package | Recommendation | Priority | Mitigation |
|---------|---------------|----------|------------|
| **anesrake** | Add `survey::rake()` fallback | Medium | Defensive programming (package is available) |
| **ordinal** | Already has MASS::polr fallback | ✅ Done | No action needed (see CatDriver 04a_ordinal.R) |

### ⚠️ MEDIUM RISK (Monitor)

| Package | Issue | Impact | Mitigation |
|---------|-------|--------|------------|
| **cmdstanr** | Complex install (requires Stan) | MaxDiff HB unavailable | Clear installation docs, graceful degradation |
| **RSGHB** | Low maintenance | Conjoint HB limited | Prefer bayesm, monitor package status |

### ✅ LOW RISK (Stable)

All other packages are actively maintained on CRAN with stable APIs.

---

## PERFORMANCE-CRITICAL PACKAGES

These packages provide significant performance benefits:

1. **data.table** - 10-100x faster than base R for large datasets
2. **xgboost** - GPU-accelerated if CUDA available
3. **writexl** - 2-3x faster than openxlsx for simple writes
4. **lobstr** - Efficient memory profiling

**Recommendation:** Make data.table standard (not optional) for modules handling >10k rows.

---

## PACKAGE UPDATE POLICY

**Current State:** No automated update policy

**Recommended Policy:**
1. **Major updates:** Test in development environment before production
2. **Minor updates:** Safe to apply after brief smoke test
3. **Patch updates:** Apply immediately (security fixes)

**Implementation:**
```r
# Check for outdated packages
old_packages <- old.packages()
if (!is.null(old_packages)) {
  print(old_packages[, c("Package", "Installed", "ReposVer")])
}

# Update all safely (excluding riskier packages)
safe_packages <- setdiff(
  rownames(old_packages),
  c("anesrake", "ordinal", "cmdstanr", "RSGHB")  # Manual review required
)
update.packages(oldPkgs = safe_packages, ask = FALSE)
```

---

## SUPPORT & TROUBLESHOOTING

### Common Installation Issues

**Issue:** Package compilation fails on Windows
```r
# Solution: Install pre-compiled binaries
install.packages("package_name", type = "win.binary")
```

**Issue:** MASS::polr vs ordinal::clm
```r
# CatDriver prefers ordinal::clm but falls back to MASS::polr
# If ordinal install fails, MASS is sufficient
```

**Issue:** cmdstanr not found
```r
# Stan requires separate installation
# See: https://mc-stan.org/docs/cmdstan-guide/cmdstan-installation.html
# Then: install.packages("cmdstanr", repos = c("https://mc-stan.org/r-packages/", getOption("repos")))
```

---

**Maintained by:** Turas Development Team
**Questions:** See module-specific USER_MANUAL.md files
