# Turas Analytics Platform - Technical Architecture

**Version:** 10.0
**Date:** December 6, 2025
**Status:** Production
**Document Type:** Master Technical Reference for Developers

---

## Executive Summary

Turas is a production-ready, modular R-based analytics platform designed for comprehensive market research analysis. This document provides complete technical architecture documentation for developers who need to understand, maintain, extend, or build upon the Turas codebase.

**Target Audience:** Software developers, technical maintainers, system architects, code reviewers

**Key Characteristics:**
- **8 Independent Modules:** AlchemerParser, Tabs, Tracker, Confidence, Segment, Conjoint, KeyDriver, Pricing
- **Configuration-Driven:** Excel-based configurations control all behavior
- **Zero-Tolerance Quality:** No merges without passing all tests
- **Modular Architecture:** Each module is self-contained and independently functional
- **Statistical Rigor:** Multiple validation layers, transparency diagnostics, reproducible pipelines

---

## Table of Contents

1. [System Architecture Overview](#1-system-architecture-overview)
2. [Technology Stack](#2-technology-stack)
3. [Module Catalog](#3-module-catalog)
4. [Directory Structure](#4-directory-structure)
5. [Data Flow Patterns](#5-data-flow-patterns)
6. [Integration Patterns](#6-integration-patterns)
7. [Configuration System](#7-configuration-system)
8. [Testing Framework](#8-testing-framework)
9. [Development Workflows](#9-development-workflows)
10. [Performance & Scalability](#10-performance--scalability)
11. [Security & Data Privacy](#11-security--data-privacy)
12. [Deployment Architecture](#12-deployment-architecture)
13. [Extension Points](#13-extension-points)
14. [Troubleshooting Guide](#14-troubleshooting-guide)

---

## 1. System Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     TURAS ANALYTICS PLATFORM v10.0                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    USER INTERFACE LAYER                         │    │
│  │  ├─ launch_turas.R (Shiny GUI - Module Launcher)                │    │
│  │  ├─ run_[module]_gui.R (Individual Shiny GUIs)                  │    │
│  │  └─ run_[module].R (CLI Entry Points)                           │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                ↓                                        │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    ANALYTICS MODULE LAYER                       │    │
│  │                                                                  │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │    │
│  │  │ PARSER   │  │  TABS    │  │ TRACKER  │  │CONFIDENCE│       │    │
│  │  │ Alchemer │  │ Cross-   │  │ Multi-   │  │ CI       │       │    │
│  │  │ Survey   │  │ tabs +   │  │ Wave     │  │ Analysis │       │    │
│  │  │ Parsing  │  │ SigTest  │  │ Trends   │  │ DEFF     │       │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │    │
│  │                                                                  │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │    │
│  │  │ SEGMENT  │  │ CONJOINT │  │KEYDRIVER │  │ PRICING  │       │    │
│  │  │ K-means  │  │ Part-    │  │ Driver   │  │ VW /     │       │    │
│  │  │ Cluster  │  │ worth    │  │ Analysis │  │ Gabor    │       │    │
│  │  │ Analysis │  │ Utility  │  │ Shapley  │  │ Granger  │       │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                ↓                                        │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    SHARED UTILITIES LAYER                       │    │
│  │  ├─ config_utils.R (Config loading & validation)                │    │
│  │  ├─ data_utils.R (Data I/O, manipulation, cleaning)             │    │
│  │  ├─ validation_utils.R (Input validation, error handling)       │    │
│  │  ├─ logging_utils.R (Structured logging framework)              │    │
│  │  ├─ weights.R (Weighting, DEFF, effective N calculations)       │    │
│  │  └─ formatting.R (Output formatting, Excel styling)             │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                ↓                                        │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                      OUTPUT LAYER                               │    │
│  │  ├─ Excel Workbooks (.xlsx) - Primary output format             │    │
│  │  ├─ CSV Exports (.csv) - Data exports                           │    │
│  │  ├─ JSON Objects (.json) - Inter-module communication           │    │
│  │  └─ RDS Objects (.rds) - Model persistence (Segment, Conjoint)  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                  ↓
                    ┌──────────────────────────┐
                    │   USER PROJECT SPACE     │
                    │   (User-managed files)   │
                    │   - Data files           │
                    │   - Configurations       │
                    │   - Output reports       │
                    └──────────────────────────┘
```

### 1.2 Architectural Principles

#### **1. Modularity**
- Each module is self-contained with clear boundaries
- Modules can be used independently or in combination
- Minimal coupling between modules
- Shared utilities extracted to common library

#### **2. Configuration-Driven Design**
- All behavior controlled via Excel configuration files
- No hard-coded business logic
- Enables version control and reproducibility
- User-friendly for non-programmers

#### **3. Pipeline Architecture**
- Standard processing pipeline: Load → Validate → Process → Output
- Each stage is isolated and testable
- Clear error boundaries at each stage
- Fail-fast validation before expensive processing

#### **4. Transparency & Auditability**
- All processing steps logged
- Diagnostic outputs (DEFF, effective N, warnings) included
- Methodology documented in output files
- Reproducible from configuration + data

#### **5. Statistical Rigor**
- Multiple validation layers
- Design-aware analysis (weighting, clustering)
- Transparent assumptions and limitations
- Flags uncertain results for manual review

### 1.3 Design Patterns

| Pattern | Usage | Location |
|---------|-------|----------|
| **Pipeline** | Sequential processing stages | All modules |
| **Strategy** | Multiple algorithm implementations | Confidence (CI methods), Tabs (sig tests) |
| **Factory** | Question type dispatching | Tabs (question processors) |
| **Builder** | Complex output construction | Excel writers in all modules |
| **Observer** | Reactive UI updates | Shiny GUIs |
| **Facade** | Simplified module interfaces | run_[module]() entry points |
| **Template Method** | Standard module structure | All module main scripts |

---

## 2. Technology Stack

### 2.1 Core Technologies

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Language** | R | 4.0+ (4.2+ recommended) | Statistical computing & data analysis |
| **GUI Framework** | Shiny | Latest | Interactive web-based interfaces |
| **Data Manipulation** | data.table | Latest | High-performance data operations |
| **Excel I/O** | openxlsx, readxl, writexl | Latest | Configuration & output files |
| **Statistics** | survey, effectsize, lmtest | Latest | Statistical analysis |
| **Version Control** | Git | 2.x+ | Source code management |
| **Testing** | testthat | Latest | Unit & regression testing |

### 2.2 Required R Packages

**Core Dependencies (All Modules):**
```r
install.packages(c(
  "openxlsx",      # Excel writing (configuration output)
  "readxl",        # Excel reading (configuration input)
  "data.table",    # Fast data manipulation
  "shiny"          # GUI interfaces
))
```

**Module-Specific Dependencies:**

**AlchemerParser:**
```r
install.packages(c(
  "officer",       # Word document reading
  "xml2",          # XML parsing
  "stringr"        # String manipulation
))
```

**Tabs:**
```r
install.packages(c(
  "survey",        # Complex survey design analysis
  "writexl"        # Alternative Excel writing
))
```

**Tracker:**
```r
install.packages(c(
  "brolgar",       # Longitudinal data analysis
  "dplyr"          # Data manipulation
))
```

**Confidence:**
```r
install.packages(c(
  "survey",        # Design effect calculations
  "effectsize"     # Effect size measures
))
```

**Segment:**
```r
install.packages(c(
  "cluster",       # Clustering algorithms
  "factoextra",    # Cluster visualization
  "ggplot2"        # Plotting
))
```

**Conjoint:**
```r
install.packages(c(
  "mlogit",        # Multinomial logit models
  "support.CEs"    # Conjoint experiments
))
```

**KeyDriver:**
```r
install.packages(c(
  "relaimpo",      # Relative importance
  "car",           # VIF calculation
  "ggplot2"        # Visualization
))
```

**Pricing:**
```r
install.packages(c(
  "ggplot2",       # Price curve visualization
  "scales"         # Axis formatting
))
```

### 2.3 Optional Packages

```r
install.packages(c(
  "haven",         # SPSS/Stata file reading
  "testthat",      # Testing framework
  "roxygen2",      # Documentation generation
  "devtools",      # Development utilities
  "profvis",       # Performance profiling
  "lintr"          # Code style checking
))
```

### 2.4 System Requirements

**Minimum:**
- R version: 4.0.0+
- RAM: 4 GB
- Disk: 1 GB free space
- OS: Windows 10, macOS 10.14+, Ubuntu 18.04+

**Recommended:**
- R version: 4.2.0+
- RAM: 8 GB (16 GB for large datasets >50K rows)
- Disk: 5 GB free space (for data, outputs, temp files)
- OS: Windows 11, macOS 12+, Ubuntu 20.04+
- RStudio: Latest version

**For Large-Scale Processing (>100K rows):**
- RAM: 32 GB+
- Multi-core CPU (4+ cores)
- SSD storage
- Consider data.table or database backend

---

## 3. Module Catalog

### 3.1 Module Overview

| Module | Status | Lines of Code | Complexity | Dependencies |
|--------|--------|---------------|------------|--------------|
| **AlchemerParser** | ✅ Production | ~3,000 | Medium | officer, openxlsx |
| **Tabs** | ✅ Production | ~13,000 | High | openxlsx, readxl, survey |
| **Tracker** | ✅ Production | ~4,700 | High | openxlsx, readxl, brolgar |
| **Confidence** | ✅ Production | ~4,900 | Medium | openxlsx, survey, effectsize |
| **Segment** | ✅ Production | ~4,000 | Medium | cluster, openxlsx |
| **Conjoint** | ✅ Production | ~5,500 | High | mlogit, openxlsx |
| **KeyDriver** | ✅ Production | ~3,200 | Medium | relaimpo, car, openxlsx |
| **Pricing** | ✅ Production | ~4,100 | Medium | ggplot2, openxlsx |
| **Shared** | ✅ Production | ~2,500 | Low | Base R |

**Total Codebase:** ~45,000 lines of R code

### 3.2 Detailed Module Descriptions

#### **AlchemerParser**
**Purpose:** Automated extraction of questionnaire structure from Alchemer survey exports

**Input:**
- Word document (.docx) - Questionnaire text
- Excel data map (.xlsx) - Variable mapping from Alchemer
- Translation file (.xlsx) - Response option labels

**Output:**
- Survey_Structure.xlsx - Standardized question/option structure
- Tabs_Config.xlsx - Ready-to-use Tabs configuration

**Key Features:**
- Automatic question type detection (NPS, Likert, Rating, Grid, etc.)
- Intelligent question code generation (Q01, Q02a, etc.)
- Handles skip logic and piping references
- Multi-language support preparation

**Technical Highlights:**
- Document parsing via officer package
- Regular expression-based question classification
- Template-driven output generation
- Reduces manual setup from 2-4 hours to 10 minutes

**Entry Point:** `modules/AlchemerParser/R/00_main.R`

---

#### **Tabs (Crosstabulation)**
**Purpose:** Single-wave weighted cross-tabulations with statistical significance testing

**Input:**
- Survey data (CSV, Excel, SPSS)
- Survey_Structure.xlsx - Question metadata
- Tabs_Config.xlsx - Crosstab specifications

**Output:**
- Excel workbook with crosstabs, significance tests, charts
- CSV exports (optional)
- JSON summary (optional)

**Key Features:**
- Weighted analysis with design effect (DEFF) calculations
- Statistical significance testing (Chi-square, Z-test, T-test)
- Banner (column) and stub (row) breakouts
- Net calculations (Top-2-Box, Bottom-2-Box)
- Composite metrics
- Multi-mention question handling
- Ranking question analysis

**Technical Highlights:**
- Modular architecture (16 specialized files)
- Strategy pattern for question type dispatching
- Memory-efficient index-based subsetting
- Vectorized calculations for performance
- Effective base calculations (Kish formula)

**Entry Point:** `modules/tabs/lib/run_crosstabs.R`

---

#### **Tracker**
**Purpose:** Multi-wave longitudinal tracking analysis with trend detection

**Input:**
- Multiple wave data files (Wave 1, Wave 2, ..., Wave N)
- Tracking_Config.xlsx - Wave specifications
- Question_Mapping.xlsx - Question alignment across waves

**Output:**
- Excel workbook with wave-over-wave comparisons
- Trend analysis
- Base drift diagnostics
- Continuity warnings

**Key Features:**
- Wave-over-wave significance testing
- Base drift detection and correction
- Question mapping across waves (handles code changes)
- Derived metrics across waves
- Multi-mention tracking
- Trend visualization

**Technical Highlights:**
- Dynamic wave loading
- Flexible question mapping engine
- Continuity validation
- Temporal alignment logic
- Handles questionnaire changes between waves

**Entry Point:** `modules/tracker/run_tracker.R`

---

#### **Confidence**
**Purpose:** Confidence interval analysis with multiple statistical methods

**Input:**
- Survey data (CSV, Excel)
- Confidence_Config.xlsx - Question specifications

**Output:**
- Excel workbook with confidence intervals
- Study-level diagnostics (DEFF, effective N)
- Weight concentration analysis
- Representativeness checks (if quotas provided)

**Key Features:**
- **CI Methods:** Normal/MOE, Wilson, Bootstrap, Bayesian
- **Statistic Types:** Proportions, Means, NPS
- **Weighted Analysis:** Design effect calculations
- **Representativeness:** Quota compliance traffic-light flagging
- **Bootstrap:** 5,000-10,000 iterations with parallel sampling

**Technical Highlights:**
- Multiple CI method implementations
- Kish effective sample size
- Bootstrap resampling for complex designs
- Bayesian credible intervals (conjugate priors)
- Automatic values/weights alignment

**Entry Point:** `modules/confidence/R/00_main.R`

---

#### **Segment**
**Purpose:** K-means clustering for market segmentation

**Input:**
- Survey data (CSV, Excel)
- Segment_Config.xlsx - Clustering specifications

**Output:**
- Excel workbook with segment assignments, profiles, validation
- RDS file with cluster model
- Scoring function for new data

**Key Features:**
- K-means clustering with automatic optimal k selection
- Outlier detection (z-score, Mahalanobis distance)
- Validation metrics (Silhouette, Elbow, Gap statistic)
- Enhanced segment profiling
- Variable importance for segments
- Cluster visualization

**Technical Highlights:**
- Multiple initialization methods
- Robust outlier handling
- Cross-validation for k selection
- Profile export for reporting
- Reproducible with seed setting

**Entry Point:** `modules/segment/run_segment.R`

---

#### **Conjoint**
**Purpose:** Conjoint analysis for product feature preference measurement

**Input:**
- Conjoint experiment data (CSV, Excel)
- Conjoint_Config.xlsx - Attribute/level specifications

**Output:**
- Excel workbook with part-worth utilities, importance scores
- Market simulator
- Scenario analysis

**Key Features:**
- **Analysis Types:** Rating-based, Choice-based
- **Estimation:** Regression (rating), Logit (choice)
- **Advanced:** Hierarchical Bayes (optional), interactions
- **Simulation:** Product preference simulator, share prediction
- **Best-Worst Scaling:** BWS support

**Technical Highlights:**
- Effects coding for categorical attributes
- Individual-level and aggregate utilities
- Market-level simulation
- NONE option handling
- Interaction effects modeling

**Entry Point:** `modules/conjoint/R/00_main.R`

---

#### **KeyDriver**
**Purpose:** Key driver analysis via multiple regression

**Input:**
- Survey data (CSV, Excel)
- KeyDriver_Config.xlsx - Outcome and driver variables

**Output:**
- Excel workbook with importance scores (4 methods), diagnostics

**Key Features:**
- **Importance Methods:**
  1. Shapley Value Decomposition (game theory)
  2. Relative Weights (Johnson's method)
  3. Standardized Coefficients (Beta weights)
  4. Zero-order Correlations
- **Diagnostics:** VIF (multicollinearity), R², adjusted R²
- **Weighted Analysis:** Supports weighted regression

**Technical Highlights:**
- Shapley value exact calculation
- Relative weights implementation
- VIF automatic calculation
- Handles categorical predictors (dummy coding)

**Entry Point:** `modules/keydriver/R/00_main.R`

---

#### **Pricing**
**Purpose:** Pricing research analysis (Van Westendorp, Gabor-Granger)

**Input:**
- Price sensitivity data (CSV, Excel)
- Pricing_Config.xlsx - Analysis specifications

**Output:**
- Excel workbook with price points, demand curves, elasticity

**Key Features:**
- **Van Westendorp PSM:** Price Sensitivity Meter, optimal price range
- **Gabor-Granger:** Demand curve, revenue optimization
- **Elasticity:** Price elasticity calculation
- **Scenarios:** Competitive scenario analysis
- **Bootstrap:** Confidence intervals for price points

**Technical Highlights:**
- Intersection point calculations (PSM)
- Demand curve fitting
- Revenue optimization algorithms
- Scenario modeling
- Visualization of price curves

**Entry Point:** `modules/pricing/R/00_main.R`

---

#### **Shared Utilities**
**Purpose:** Common functions used across multiple modules

**Location:** `/modules/shared/lib/`

**Components:**
- `config_utils.R` - Configuration loading, validation, path resolution
- `data_utils.R` - Data loading, cleaning, manipulation
- `validation_utils.R` - Input validation, error handling
- `logging_utils.R` - Structured logging framework
- `weights.R` - Weighting calculations, DEFF, effective N
- `formatting.R` - Output formatting, decimal separators, Excel styling

**Entry Point:** Individual source files

---

## 4. Directory Structure

### 4.1 Complete Repository Structure

```
/Turas/
├── README.md                           # Project overview
├── Turas.Rproj                         # RStudio project file
├── launch_turas.R                      # MAIN ENTRY POINT (Shiny GUI)
├── turas.R                             # Turas initialization script
│
├── modules/                            # Core analytics modules
│   ├── AlchemerParser/
│   │   ├── R/                          # Core R code
│   │   │   ├── 00_main.R              # Main orchestration
│   │   │   ├── 01_parse_data_map.R    # Data mapping parser
│   │   │   ├── 02_parse_translation.R # Translation parser
│   │   │   ├── 03_parse_word_doc.R    # Word document parser
│   │   │   ├── 04_classify_questions.R# Question classifier
│   │   │   ├── 05_generate_codes.R    # Code generator
│   │   │   └── 06_output.R            # Output generation
│   │   ├── run_alchemerparser.R       # CLI entry
│   │   ├── run_alchemerparser_gui.R   # GUI entry
│   │   ├── TECHNICAL_DOCS.md          # Technical documentation
│   │   ├── USER_MANUAL.md             # User guide
│   │   └── QUICK_START.md             # Quick start guide
│   │
│   ├── tabs/
│   │   ├── lib/                        # Core library
│   │   │   ├── run_crosstabs.R        # Main orchestrator
│   │   │   ├── config_loader.R        # Config loading
│   │   │   ├── validation.R           # Input validation
│   │   │   ├── question_orchestrator.R# Question prep
│   │   │   ├── question_dispatcher.R  # Type routing
│   │   │   ├── standard_processor.R   # Single/Multi questions
│   │   │   ├── numeric_processor.R    # Numeric/Rating/NPS
│   │   │   ├── composite_processor.R  # Composite metrics
│   │   │   ├── ranking.R              # Ranking questions
│   │   │   ├── cell_calculator.R      # Cell calculations
│   │   │   ├── banner.R               # Banner structure
│   │   │   ├── banner_indices.R       # Banner indexing
│   │   │   ├── weighting.R            # Weighting
│   │   │   ├── shared_functions.R     # Utilities
│   │   │   ├── excel_writer.R         # Excel output
│   │   │   └── summary_builder.R      # Summary stats
│   │   ├── run_tabs.R                 # CLI entry
│   │   ├── run_tabs_gui.R             # GUI entry
│   │   ├── TECHNICAL_DOCS.md
│   │   ├── USER_MANUAL.md
│   │   └── QUICK_START.md
│   │
│   ├── tracker/
│   │   ├── run_tracker.R              # Main script
│   │   ├── run_tracker_gui.R          # GUI entry
│   │   ├── tracker_config_loader.R    # Config loading
│   │   ├── tracker_output.R           # Output generation
│   │   ├── trend_calculator.R         # Trend calculations
│   │   ├── wave_loader.R              # Wave data loading
│   │   ├── question_mapper.R          # Question mapping
│   │   ├── banner_trends.R            # Banner trend analysis
│   │   ├── formatting_utils.R         # Formatting
│   │   ├── validation_tracker.R       # Validation
│   │   ├── constants.R                # Constants
│   │   ├── [templates]                # Config templates
│   │   ├── TECHNICAL_DOCS.md
│   │   ├── USER_MANUAL.md
│   │   └── QUICK_START.md
│   │
│   ├── confidence/
│   │   ├── R/
│   │   │   ├── 00_main.R              # Main orchestration
│   │   │   ├── 01_load_config.R       # Config loading
│   │   │   ├── 02_load_data.R         # Data loading
│   │   │   ├── 03_study_level.R       # Study stats
│   │   │   ├── 04_proportions.R       # Proportion CIs
│   │   │   ├── 05_means.R             # Mean CIs
│   │   │   ├── 07_output.R            # Excel output
│   │   │   └── utils.R                # Utilities
│   │   ├── run_confidence_gui.R       # GUI entry
│   │   ├── tests/                     # Test suite
│   │   ├── examples/                  # Example configs
│   │   ├── TECHNICAL_DOCS.md
│   │   ├── USER_MANUAL.md
│   │   └── QUICK_START.md
│   │
│   ├── segment/
│   │   ├── lib/
│   │   │   ├── segment_config.R       # Config loading
│   │   │   ├── segment_data_prep.R    # Data prep
│   │   │   ├── segment_kmeans.R       # K-means clustering
│   │   │   ├── segment_outliers.R     # Outlier detection
│   │   │   ├── segment_validation.R   # Validation metrics
│   │   │   ├── segment_variable_selection.R # Var selection
│   │   │   ├── segment_profile.R      # Basic profiling
│   │   │   ├── segment_profiling_enhanced.R # Enhanced profiles
│   │   │   ├── segment_scoring.R      # New data scoring
│   │   │   ├── segment_export.R       # Excel output
│   │   │   ├── segment_visualization.R# Charts
│   │   │   └── segment_utils.R        # Utilities
│   │   ├── run_segment.R              # CLI entry
│   │   ├── run_segment_gui.R          # GUI entry
│   │   ├── test_data/
│   │   ├── TECHNICAL_DOCS.md
│   │   ├── USER_MANUAL.md
│   │   └── QUICK_START.md
│   │
│   ├── conjoint/
│   │   ├── R/
│   │   │   ├── 00_main.R              # Main orchestration
│   │   │   ├── 01_config.R            # Config loading
│   │   │   ├── 02_data.R              # Data loading
│   │   │   ├── 03_estimation.R        # Model estimation
│   │   │   ├── 04_utilities.R         # Utility calculations
│   │   │   ├── 05_simulator.R         # Product simulator
│   │   │   ├── 06_interactions.R      # Interaction effects
│   │   │   ├── 07_output.R            # Excel output
│   │   │   ├── 08_market_simulator.R  # Market simulator
│   │   │   ├── 09_none_handling.R     # NONE option
│   │   │   ├── 10_best_worst.R        # BWS
│   │   │   ├── 11_hierarchical_bayes.R# HB estimation
│   │   │   └── 99_helpers.R           # Helpers
│   │   ├── run_conjoint_gui.R         # GUI entry
│   │   ├── examples/
│   │   ├── tests/
│   │   ├── TECHNICAL_DOCS.md
│   │   ├── USER_MANUAL.md
│   │   └── TUTORIAL.md
│   │
│   ├── keydriver/
│   │   ├── R/
│   │   │   ├── 00_main.R              # Main orchestration
│   │   │   ├── 01_config.R            # Config loading
│   │   │   ├── 02_validation.R        # Validation
│   │   │   ├── 03_analysis.R          # Statistical analysis
│   │   │   └── 04_output.R            # Excel output
│   │   ├── run_keydriver_gui.R        # GUI entry
│   │   ├── TECHNICAL_DOCS.md
│   │   ├── USER_MANUAL.md
│   │   └── QUICK_START.md
│   │
│   ├── pricing/
│   │   ├── R/
│   │   │   ├── 00_main.R              # Main orchestration
│   │   │   ├── 01_config.R            # Config loading
│   │   │   ├── 02_validation.R        # Validation
│   │   │   ├── 03_van_westendorp.R    # PSM analysis
│   │   │   ├── 04_gabor_granger.R     # Demand curve
│   │   │   ├── 05_visualization.R     # Charts
│   │   │   ├── 06_output.R            # Excel output
│   │   │   ├── 07_wtp_distribution.R  # WTP analysis
│   │   │   ├── 08_competitive_scenarios.R # Scenarios
│   │   │   └── 09_price_volume_optimisation.R # Optimization
│   │   ├── run_pricing_gui.R          # GUI entry
│   │   ├── examples/
│   │   ├── TECHNICAL_DOCS.md
│   │   ├── USER_MANUAL.md
│   │   └── TUTORIAL.md
│   │
│   └── shared/
│       ├── lib/
│       │   ├── config_utils.R         # Config utilities
│       │   ├── data_utils.R           # Data utilities
│       │   ├── validation_utils.R     # Validation
│       │   └── logging_utils.R        # Logging
│       ├── TECHNICAL_DOCS.md
│       └── README.md
│
├── templates/                          # Configuration templates
│   ├── working/                        # Ready-to-use templates
│   └── annotated/                      # Documented templates
│
├── docs/                               # Centralized documentation
│   ├── TECHNICAL_ARCHITECTURE.md       # This file
│   ├── MAINTENANCE.md                  # Maintenance guide
│   ├── TROUBLESHOOTING.md              # Troubleshooting
│   ├── [Config manuals]                # Configuration guides
│   └── [Other documentation]
│
├── tests/                              # Test suite
│   ├── testthat/                       # Unit tests
│   │   ├── test_shared_functions.R
│   │   ├── test_formatting_baseline.R
│   │   ├── test_config_baseline.R
│   │   └── test_weights_baseline.R
│   └── regression/                     # Regression tests
│       ├── run_all_regression_tests.R  # Master runner
│       ├── golden/                     # Expected outputs
│       ├── helpers/                    # Test helpers
│       └── test_regression_*.R         # Module tests
│
├── examples/                           # Example data & configs
│   ├── [module]/basic/                 # Basic examples per module
│   └── test_data/                      # Test datasets
│
├── archive/                            # Historical files
├── tools/                              # Utility scripts
├── .git/                               # Git repository
├── .gitignore
└── .gitattributes
```

### 4.2 Standard Module Structure

Every module follows this consistent structure:

```
modules/[module_name]/
├── R/ or lib/                          # Core R code
│   ├── 00_main.R                      # Main orchestration
│   ├── 01_*.R                         # Numbered components
│   └── utils.R or helpers.R           # Utilities
├── run_[module].R                      # CLI entry point
├── run_[module]_gui.R                  # GUI entry point (Shiny)
├── test_data/                          # Test datasets (optional)
├── examples/                           # Example configs (optional)
├── tests/                              # Test suite (optional)
├── TECHNICAL_DOCS.md                   # Technical documentation
├── USER_MANUAL.md                      # User guide
├── QUICK_START.md                      # Quick start (5-10 min)
├── EXAMPLE_WORKFLOWS.md                # Common use cases (optional)
└── README.md                           # Module overview
```

---

## 5. Data Flow Patterns

### 5.1 Standard Module Processing Pipeline

All modules follow this standardized pipeline:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. INITIALIZATION                                           │
│    - Source R files                                         │
│    - Load required packages                                 │
│    - Set constants and defaults                             │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│ 2. CONFIGURATION LOADING                                    │
│    - Read Excel configuration file(s)                       │
│    - Validate configuration structure                       │
│    - Validate configuration values                          │
│    - Resolve file paths (relative → absolute)               │
│    - Parse settings to R objects                            │
│    - Enforce limits (e.g., max questions)                   │
│    - Log configuration snapshot                             │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│ 3. DATA LOADING                                             │
│    - Detect file format (CSV, Excel, SPSS, Stata)           │
│    - Load survey data                                       │
│    - Validate data structure                                │
│    - Check required columns exist                           │
│    - Load weights (if specified)                            │
│    - Validate weights                                       │
│    - Create metadata structures                             │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│ 4. PRE-PROCESSING                                           │
│    - Data cleaning (handle NAs, trim whitespace)            │
│    - Type conversions (character → numeric where needed)    │
│    - Filter application (if specified)                      │
│    - Derive calculated fields                               │
│    - Create indices for fast subsetting                     │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│ 5. ANALYSIS                                                 │
│    - Calculate study-level statistics                       │
│    - Loop through questions/analyses                        │
│      ├─ Extract relevant data                               │
│      ├─ Apply module-specific processing                    │
│      ├─ Calculate statistics                                │
│      ├─ Handle errors gracefully (log, continue)            │
│      └─ Store results                                       │
│    - Aggregate results                                      │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│ 6. POST-PROCESSING                                          │
│    - Format results for output                              │
│    - Apply decimal separator preferences                    │
│    - Round to specified decimal places                      │
│    - Generate diagnostic outputs                            │
│    - Compile warnings and errors                            │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│ 7. OUTPUT GENERATION                                        │
│    - Create Excel workbook                                  │
│    - Add result sheets                                      │
│    - Add methodology sheet                                  │
│    - Add warnings sheet                                     │
│    - Add inputs sheet (config snapshot)                     │
│    - Apply formatting (colors, borders, fonts)              │
│    - Save to file                                           │
│    - Generate optional exports (CSV, JSON, RDS)             │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│ 8. FINALIZATION                                             │
│    - Return results object                                  │
│    - Print summary (if verbose)                             │
│    - Clean up temporary objects                             │
│    - Log completion                                         │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Data Flow Example: Tabs Module

Detailed data flow through the Tabs (crosstabulation) module:

```
USER INPUTS
├─ Survey data (survey_data.csv)
├─ Survey structure (Survey_Structure.xlsx)
└─ Crosstab config (Tabs_Config.xlsx)
        ↓
┌───────────────────────────────────┐
│ load_crosstab_configuration()    │
│  - Load config sheets             │
│  - Validate settings              │
│  - Validate banner/stub selection │
└─────────┬─────────────────────────┘
          ↓
┌───────────────────────────────────┐
│ Load survey data                  │
│  - Read CSV/Excel/SPSS file       │
│  - Preserve column names          │
└─────────┬─────────────────────────┘
          ↓
┌───────────────────────────────────┐
│ validate_survey_structure()       │
│  - Check required columns         │
│  - Validate question types        │
│  - Check for orphan options       │
└─────────┬─────────────────────────┘
          ↓
┌───────────────────────────────────┐
│ validate_survey_data()            │
│  - Verify required columns exist  │
│  - Check data types               │
│  - Validate multi-mention columns │
└─────────┬─────────────────────────┘
          ↓
┌───────────────────────────────────┐
│ load_weights()                    │
│  - Extract weight column          │
│  - Validate weights               │
│  - Calculate DEFF                 │
└─────────┬─────────────────────────┘
          ↓
┌───────────────────────────────────┐
│ create_banner_structure()         │
│  - Build banner columns           │
│  - Create display labels          │
│  - Generate internal keys         │
└─────────┬─────────────────────────┘
          ↓
┌───────────────────────────────────┐
│ create_banner_row_indices()       │
│  - Map each row to banner columns │
│  - Create index vectors           │
│  - Validate no empty indices      │
└─────────┬─────────────────────────┘
          ↓
FOR EACH STUB QUESTION:
  ↓
┌───────────────────────────────────┐
│ prepare_question_data()           │
│  - Load question metadata         │
│  - Load question options          │
│  - Apply base filter (if any)     │
│  - Subset banner indices          │
│  - Calculate bases                │
└─────────┬─────────────────────────┘
          ↓
┌───────────────────────────────────┐
│ process_question()                │
│  - Detect question type           │
│  - Route to appropriate processor │
│    ├─ process_standard_question() │
│    ├─ process_numeric_question()  │
│    ├─ process_composite_question()│
│    └─ process_ranking_question()  │
└─────────┬─────────────────────────┘
          ↓
  WITHIN PROCESSOR:
    ↓
  FOR EACH RESPONSE OPTION:
    ↓
  ┌─────────────────────────────────┐
  │ calculate_row_counts()          │
  │  - Count across banner columns  │
  │  - Apply weights                │
  │  - Return weighted counts       │
  └─────────┬───────────────────────┘
            ↓
  ┌─────────────────────────────────┐
  │ create_percentage_row()         │
  │  - Calculate percentages        │
  │  - Format to decimal places     │
  │  - Create data frame row        │
  └─────────┬───────────────────────┘
            ↓
  ┌─────────────────────────────────┐
  │ calculate_column_significance() │
  │  - Run statistical test         │
  │  - Assign significance letters  │
  │  - Return sig row               │
  └─────────┬───────────────────────┘
            ↓
  ┌─────────────────────────────────┐
  │ Combine rows into result table  │
  └─────────┬───────────────────────┘
            ↓
  ┌─────────────────────────────────┐
  │ Return question result object   │
  └─────────┬───────────────────────┘
            ↓
  ┌─────────────────────────────────┐
  │ Add to all_results list         │
  └─────────────────────────────────┘
          ↓
END QUESTION LOOP
        ↓
┌───────────────────────────────────┐
│ write_crosstab_excel()            │
│  - Create workbook                │
│  - Add sheets for each question   │
│  - Add summary sheet              │
│  - Add methodology sheet          │
│  - Add warnings sheet             │
│  - Apply Excel formatting         │
│  - Save workbook                  │
└─────────┬─────────────────────────┘
          ↓
┌───────────────────────────────────┐
│ Return results object             │
│  - all_results                    │
│  - validation info                │
│  - output file path               │
└───────────────────────────────────┘
          ↓
OUTPUT FILES
├─ Crosstabs.xlsx (main output)
├─ Crosstabs.csv (optional export)
└─ Crosstabs.json (optional metadata)
```

### 5.3 Inter-Module Data Flow

Modules can be chained together in workflows:

```
WORKFLOW EXAMPLE: Complete Survey Analysis

Step 1: PARSE QUESTIONNAIRE
┌─────────────────────────┐
│ AlchemerParser          │
│ Input: .docx, .xlsx     │
│ Output: Structure.xlsx  │
└───────┬─────────────────┘
        │
        ↓ (Use Survey_Structure.xlsx as input)
        │
Step 2: CROSSTABULATION
┌───────┴─────────────────┐
│ Tabs                    │
│ Input: Structure.xlsx   │
│       data.csv          │
│ Output: Crosstabs.xlsx  │
└───────┬─────────────────┘
        │
        ↓ (Identify key questions for tracking)
        │
Step 3: MULTI-WAVE TRACKING
┌───────┴─────────────────┐
│ Tracker                 │
│ Input: Wave 1-N data    │
│       Question mapping  │
│ Output: Trends.xlsx     │
└───────┬─────────────────┘
        │
        ↓ (Calculate CIs for trend estimates)
        │
Step 4: CONFIDENCE INTERVALS
┌───────┴─────────────────┐
│ Confidence              │
│ Input: Latest wave data │
│ Output: CIs.xlsx        │
└───────┬─────────────────┘
        │
        ↓ (Identify segments)
        │
Step 5: SEGMENTATION
┌───────┴─────────────────┐
│ Segment                 │
│ Input: Latest wave data │
│ Output: Segments.xlsx   │
└───────┬─────────────────┘
        │
        ↓ (Profile segments with crosstabs)
        │
Step 6: SEGMENT PROFILING
┌───────┴─────────────────┐
│ Tabs (with Segment var) │
│ Input: Data + segments  │
│ Output: Profiles.xlsx   │
└─────────────────────────┘
```

---

## 6. Integration Patterns

### 6.1 Module Integration Approaches

**Pattern 1: Sequential Pipeline**
```r
# Step 1: Parse questionnaire
source("modules/AlchemerParser/R/00_main.R")
structure <- run_alchemerparser(
  project_dir = "alchemer_export/",
  verbose = TRUE
)

# Step 2: Run crosstabs using parsed structure
source("modules/tabs/lib/run_crosstabs.R")
result <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = structure$survey_structure_path,
  data_file = "survey_data.csv"
)
```

**Pattern 2: Shared Data Structure**
```r
# Segment data, then use segments in Tabs
segments <- run_segment_analysis("segment_config.xlsx")

# Add segment assignments to survey data
survey_data$Segment <- segments$assignments

# Use Segment as banner variable in Tabs
# (Configure in Tabs_Config.xlsx Banner sheet)
```

**Pattern 3: Configuration Chaining**
```r
# AlchemerParser generates Tabs_Config.xlsx
# Which can be used directly in Tabs module
parser_output <- run_alchemerparser(...)

# parser_output$tabs_config_path points to ready-to-use config
tabs_result <- run_crosstabs(
  config_file = parser_output$tabs_config_path,
  data_file = "survey_data.csv"
)
```

### 6.2 External System Integration

**Survey Platform Integration:**
```r
# Export from Qualtrics/SurveyMonkey/Alchemer
# → Save as CSV or Excel
# → Load into Turas modules

# Example: Qualtrics
# 1. Export numeric values + labels
# 2. Download as CSV
# 3. Load in Tabs:
run_crosstabs(
  data_file = "qualtrics_export.csv",
  config_file = "Tabs_Config.xlsx"
)
```

**Database Integration (Future):**
```r
# Potential database connection pattern
library(DBI)
library(odbc)

con <- dbConnect(
  odbc::odbc(),
  driver = "SQL Server",
  server = "server_name",
  database = "survey_db"
)

survey_data <- dbGetQuery(con, "SELECT * FROM wave_1")

run_crosstabs(
  data_file = survey_data,  # Pass data frame directly
  config_file = "Tabs_Config.xlsx"
)
```

**Reporting Integration:**
```r
# Export to PowerPoint (via officer package)
library(officer)

ppt <- read_pptx()
ppt <- add_slide(ppt, layout = "Title and Content")
ppt <- ph_with(ppt, value = crosstab_table, location = ph_location_type("body"))

print(ppt, target = "report.pptx")
```

---

## 7. Configuration System

### 7.1 Configuration Philosophy

All Turas modules use **Excel-based configuration files** with these principles:

1. **Human-Readable:** Non-programmers can configure analyses
2. **Version-Controllable:** Can be tracked in git (convert to CSV)
3. **Self-Documenting:** Clear parameter names and structures
4. **Validated:** Extensive validation before processing
5. **Reproducible:** Same config + data = same results

### 7.2 Standard Configuration Structure

All config files follow this pattern:

```
Excel Workbook: [Module]_Config.xlsx
├─ Sheet: File_Paths
│   ├─ Parameter (column)
│   └─ Value (column)
│
├─ Sheet: Settings
│   ├─ Setting_Name (column)
│   └─ Setting_Value (column)
│
├─ Sheet: [Module-Specific Sheet 1]
│   └─ [Module-specific columns]
│
└─ Sheet: [Module-Specific Sheet 2]
    └─ [Module-specific columns]
```

### 7.3 Common Configuration Patterns

**File Paths:**
```
Parameter          | Value
-------------------|-------------------
Data_File          | data/survey.csv
Output_File        | output/results.xlsx
Survey_Structure   | config/structure.xlsx
```

**Settings:**
```
Setting_Name         | Setting_Value
---------------------|---------------
Confidence_Level     | 0.95
Significance_Level   | 0.05
Decimal_Places       | 0
Decimal_Separator    | .
Minimum_Base         | 30
Weight_Column        | weight
```

**Boolean Settings:**
```
Always use: TRUE / FALSE (all caps)
NOT: true/false, T/F, 1/0, Yes/No
```

**File Path Conventions:**
- Use forward slashes `/` (works on all OS)
- Relative paths preferred: `data/file.csv`
- Absolute paths supported: `C:/Projects/data/file.csv`
- Resolved relative to configuration file location

### 7.4 Configuration Loading Pattern

Standard configuration loading in all modules:

```r
load_[module]_config <- function(config_file) {

  # 1. Validate file exists
  if (!file.exists(config_file)) {
    stop("Configuration file not found: ", config_file)
  }

  # 2. Load required sheets
  file_paths <- readxl::read_excel(config_file, sheet = "File_Paths")
  settings <- readxl::read_excel(config_file, sheet = "Settings")

  # 3. Validate structure
  validate_config_structure(file_paths, settings)

  # 4. Parse settings to list
  config <- parse_settings_to_list(settings)

  # 5. Resolve file paths
  config$paths <- resolve_file_paths(file_paths, dirname(config_file))

  # 6. Validate values
  validate_config_values(config)

  # 7. Return config object
  return(config)
}
```

---

## 8. Testing Framework

### 8.1 Test Architecture

```
tests/
├── testthat/                           # Unit tests
│   ├── test_shared_functions.R        # Shared utilities
│   ├── test_formatting_baseline.R     # Formatting functions
│   ├── test_config_baseline.R         # Config loading
│   └── test_weights_baseline.R        # Weight calculations
│
└── regression/                         # Regression tests
    ├── run_all_regression_tests.R     # Master test runner
    ├── golden/                         # Expected outputs (JSON)
    │   ├── tabs_basic.json
    │   ├── tracker_basic.json
    │   ├── confidence_basic.json
    │   ├── segment_basic.json
    │   ├── conjoint_basic.json
    │   ├── keydriver_basic.json
    │   ├── pricing_basic.json
    │   └── alchemerparser_basic.json
    ├── helpers/
    │   ├── assertion_helpers.R         # Comparison functions
    │   └── path_helpers.R              # Path utilities
    └── test_regression_[module].R      # Per-module tests
```

### 8.2 Golden Master Testing

**Concept:** Compare actual output against known-good "golden" outputs

**Pattern:**
```r
# 1. Run module on example data
result <- run_[module]_analysis(
  config_file = "examples/[module]/basic/config.xlsx"
)

# 2. Extract key values
actual_values <- extract_test_values(result)

# 3. Load expected values
expected <- jsonlite::fromJSON("tests/regression/golden/[module]_basic.json")

# 4. Compare with tolerance
compare_with_tolerance(actual_values, expected, tolerance = 1e-6)

# 5. Report pass/fail
if (all_match) {
  cat("✓ Test passed\n")
} else {
  cat("✗ Test failed\n")
  print_differences(actual_values, expected)
}
```

### 8.3 Regression Test Coverage

**Current Coverage:** 67 assertions across 8 modules

| Module | Assertions | Key Checks |
|--------|------------|------------|
| Tabs | 10 | Percentages, bases, sig tests, weighted calculations |
| Confidence | 12 | CI widths, coverage, DEFF, representativeness |
| Tracker | 11 | Trends, wave comparisons, base drift, continuity |
| Segment | 7 | Cluster assignments, silhouette, profiles |
| Conjoint | 9 | Utilities, importance, simulations |
| KeyDriver | 5 | Shapley values, correlations, R² |
| Pricing | 7 | Price points, elasticity, optimization |
| AlchemerParser | 6 | Question codes, types, option counts |

### 8.4 Running Tests

**Run all regression tests:**
```r
source("tests/regression/run_all_regression_tests.R")
```

**Run unit tests:**
```r
library(testthat)
test_dir("tests/testthat")
```

**Run specific module test:**
```r
source("tests/regression/test_regression_tabs.R")
```

### 8.5 Test Quality Standards

**Pre-Commit Requirements:**
- All 67 regression tests must pass
- No new warnings introduced
- Code style checks (lintr) pass

**Pre-Release Requirements:**
- Full regression test suite passes
- Manual smoke test on real data
- Performance test on large dataset (>10K rows)
- Backward compatibility verified

---

## 9. Development Workflows

### 9.1 Adding a New Module

**Step-by-Step Process:**

**1. Create Directory Structure**
```bash
mkdir -p modules/new_module/R
mkdir -p modules/new_module/tests
mkdir -p modules/new_module/examples/basic
```

**2. Create Core Files**
```r
# modules/new_module/R/00_main.R
run_new_module_analysis <- function(config_file, verbose = TRUE) {
  # Main orchestration
}

# modules/new_module/R/01_config.R
load_new_module_config <- function(config_file) {
  # Config loading
}

# modules/new_module/R/02_analysis.R
perform_new_module_analysis <- function(data, config) {
  # Core analysis logic
}

# modules/new_module/R/03_output.R
write_new_module_output <- function(results, output_file) {
  # Excel/CSV output
}
```

**3. Create Entry Points**
```r
# modules/new_module/run_new_module.R
source("modules/new_module/R/00_main.R")
# CLI usage code

# modules/new_module/run_new_module_gui.R
library(shiny)
# Shiny app code
```

**4. Create Configuration Template**
```r
# Create Excel template with standard sheets:
# - File_Paths
# - Settings
# - [Module-specific sheets]
```

**5. Create Documentation**
```bash
touch modules/new_module/TECHNICAL_DOCS.md
touch modules/new_module/USER_MANUAL.md
touch modules/new_module/QUICK_START.md
touch modules/new_module/README.md
```

**6. Create Example Data**
```r
# modules/new_module/examples/basic/
# - config.xlsx
# - data.csv
# - README.md
```

**7. Create Tests**
```r
# tests/regression/test_regression_new_module.R
# tests/regression/golden/new_module_basic.json
```

**8. Add to Main Launcher**
```r
# Edit launch_turas.R to include new module card
```

**9. Update Documentation**
```bash
# Update docs/TECHNICAL_ARCHITECTURE.md
# Update README.md
```

### 9.2 Modifying Existing Module

**Safe Modification Workflow:**

**1. Create Feature Branch**
```bash
git checkout -b feature/module-enhancement
```

**2. Write Tests First (TDD)**
```r
# tests/regression/test_regression_[module].R
test_that("new feature works correctly", {
  result <- run_analysis_with_new_feature()
  expect_equal(result$new_metric, expected_value)
})
```

**3. Implement Feature**
```r
# Modify appropriate R file in modules/[module]/R/
# Follow existing code style
# Add comments explaining logic
```

**4. Update Golden Values (if needed)**
```r
# If expected outputs change:
# 1. Verify changes are correct
# 2. Update tests/regression/golden/[module]_basic.json
```

**5. Run Tests**
```r
source("tests/regression/run_all_regression_tests.R")
```

**6. Update Documentation**
```r
# Update TECHNICAL_DOCS.md
# Update USER_MANUAL.md
# Update version number if appropriate
```

**7. Create Pull Request**
```bash
git add .
git commit -m "feat: Add new feature to [module]"
git push origin feature/module-enhancement
```

### 9.3 Debugging Workflow

**Step 1: Enable Verbose Output**
```r
result <- run_[module]_analysis(
  config_file = "config.xlsx",
  verbose = TRUE  # Print detailed progress
)
```

**Step 2: Add Debug Prints**
```r
# Temporarily add debug messages
cat("DEBUG: Processing question", question_id, "\n")
cat("DEBUG: Data dimensions:", dim(data), "\n")
cat("DEBUG: Weights summary:", summary(weights), "\n")
```

**Step 3: Use browser() for Interactive Debugging**
```r
process_question <- function(question_id, data) {
  browser()  # Execution will pause here
  # ... rest of function
}
```

**Step 4: Check Intermediate Results**
```r
# After run_analysis():
result$intermediate_data
result$validation_log
result$warnings
```

**Step 5: Profile Performance**
```r
library(profvis)

profvis({
  result <- run_[module]_analysis("config.xlsx")
})
```

**Step 6: Use testthat for Isolated Testing**
```r
library(testthat)

test_that("specific function works", {
  data <- create_test_data()
  result <- specific_function(data)
  expect_equal(result, expected_value)
})
```

### 9.4 Release Workflow

**Version Numbering:** Semantic Versioning (MAJOR.MINOR.PATCH)
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

**Release Checklist:**

- [ ] All regression tests pass (67/67)
- [ ] Unit tests pass
- [ ] Manual smoke test completed
- [ ] Performance test on large dataset
- [ ] Backward compatibility verified
- [ ] Version numbers updated:
  - [ ] Module R/00_main.R (VERSION constant)
  - [ ] TECHNICAL_DOCS.md header
  - [ ] USER_MANUAL.md header
  - [ ] README.md
- [ ] CHANGELOG.md updated
- [ ] Documentation reviewed and updated
- [ ] Example configs validated
- [ ] Code review completed
- [ ] Git tag created: `git tag v[module]-[version]`
- [ ] Release notes written

---

## 10. Performance & Scalability

### 10.1 Performance Characteristics

**Typical Performance (MacBook Pro M1, 16GB RAM):**

| Module | Dataset Size | Processing Time |
|--------|--------------|-----------------|
| AlchemerParser | N/A | 5-15 seconds |
| Tabs | 1,000 × 50 vars × 10 questions | 10-20 seconds |
| Tabs | 10,000 × 100 vars × 50 questions | 1-2 minutes |
| Tabs | 50,000 × 200 vars × 100 questions | 5-10 minutes |
| Tracker | 5 waves × 1,000 rows × 20 questions | 20-30 seconds |
| Confidence | 1,000 rows × 50 questions (bootstrap) | 30-60 seconds |
| Segment | 1,000 rows × 20 vars (k=5) | 10-20 seconds |
| Conjoint | 1,000 respondents × 10 tasks | 20-40 seconds |
| KeyDriver | 1,000 rows × 10 drivers | 5-10 seconds |
| Pricing | 1,000 rows (VW + GG) | 10-20 seconds |

### 10.2 Memory Usage

**Typical Memory Consumption:**
- 1,000 rows × 50 columns: ~10 MB
- 10,000 rows × 100 columns: ~100 MB
- 50,000 rows × 200 columns: ~500 MB
- Excel output workbook: Variable (depends on # of sheets)

**Memory Optimization Strategies:**

**1. Index-Based Subsetting (Not Data Duplication)**
```r
# GOOD: Use master_weights[row_idx]
subset_weights <- master_weights[banner_indices$Male]

# BAD: Duplicate weight vector
subset_weights <- rep(master_weights, each = n)
```

**2. Vectorization (Not Loops)**
```r
# GOOD: Vectorized
matching_rows <- data$gender == "Male"
count <- sum(weights[matching_rows])

# BAD: Loop
count <- 0
for (i in 1:nrow(data)) {
  if (data$gender[i] == "Male") {
    count <- count + weights[i]
  }
}
```

**3. Process in Batches (For Large Datasets)**
```r
# For very large analyses
batch_size <- 20
for (batch_start in seq(1, n_questions, by = batch_size)) {
  batch_questions <- questions[batch_start:(batch_start + batch_size - 1)]
  batch_results <- process_batch(batch_questions)
  # Write batch to Excel
  # Clear memory
  rm(batch_results)
  gc()
}
```

**4. Use data.table for Large Data**
```r
library(data.table)
dt <- as.data.table(survey_data)

# Fast aggregation
dt[, .(weighted_mean = sum(value * weight) / sum(weight)), by = gender]
```

### 10.3 Scalability Limits

**Current Limits:**

| Resource | Limit | Reason |
|----------|-------|--------|
| Questions per analysis | 200 | Excel sheet limit, memory |
| Respondents | 100,000 | Memory (16GB RAM), processing time |
| Variables per respondent | 500 | Memory |
| Banner columns (Tabs) | 30 | Excel width, processing time |
| Bootstrap iterations (Confidence) | 10,000 | Processing time |
| Tracker waves | 20 | Excel sheets, processing complexity |

**Strategies for Large Datasets:**

**1. Split Analysis**
```r
# Process questions in groups
questions_group_1 <- questions[1:50]
questions_group_2 <- questions[51:100]

run_crosstabs(config_file_1)
run_crosstabs(config_file_2)
```

**2. Sample for Development**
```r
# Use sample for testing, full data for production
if (dev_mode) {
  data <- data[sample(nrow(data), 1000), ]
}
```

**3. Database Backend (Future)**
```r
# Store data in database, query on demand
# Rather than loading all data into memory
```

### 10.4 Performance Profiling

**Using profvis:**
```r
library(profvis)

profvis({
  result <- run_crosstabs("config.xlsx")
})

# Identifies bottlenecks:
# - Which functions take most time
# - Memory allocation patterns
# - Opportunities for optimization
```

**Using system.time:**
```r
system.time({
  result <- run_analysis()
})
#   user  system elapsed
#  10.2    0.5    10.8
```

**Benchmarking:**
```r
library(microbenchmark)

microbenchmark(
  vectorized = sum(weights[matching]),
  loop = sum_with_loop(weights, matching),
  times = 100
)
```

---

## 11. Security & Data Privacy

### 11.1 Data Security Principles

**1. Local Processing**
- All data processing happens locally on user's machine
- No data sent to external servers
- No cloud dependencies

**2. No Data Persistence**
- Survey data not stored by Turas (user provides and manages)
- Output files saved to user-specified locations only
- No automatic backups or logs containing PII

**3. Configuration Files**
- Configurations don't contain sensitive data
- Can be version-controlled safely
- No passwords or credentials stored

### 11.2 Handling Sensitive Data

**Best Practices:**

**1. Data Minimization**
```r
# Only load columns needed for analysis
data <- fread(
  "survey_data.csv",
  select = c("respondent_id", "q1", "q2", "weight")
)
```

**2. Anonymization**
```r
# Remove PII before analysis
data$email <- NULL
data$name <- NULL
data$ip_address <- NULL

# Or use anonymous IDs
data$respondent_id <- seq_len(nrow(data))
```

**3. Secure File Permissions**
```r
# Set restrictive permissions on output files (Unix/Mac)
Sys.chmod("output/results.xlsx", mode = "0600")  # User read/write only
```

**4. Temporary File Cleanup**
```r
# Clean up temporary files after processing
on.exit({
  unlink("temp_data.csv")
  unlink("temp_workbook.xlsx")
}, add = TRUE)
```

### 11.3 Git Security

**Don't Commit:**
- Raw survey data files
- Output files with results
- Files containing PII

**.gitignore patterns:**
```
# Data files
*.csv
*.xlsx
*.sav
*.dta

# Output files
output/
results/

# Except configuration templates
!templates/*.xlsx
!examples/**/*.xlsx
!examples/**/*.csv
```

**Safe to Commit:**
- R code
- Configuration templates (no actual data)
- Documentation
- Example data (synthetic, anonymized)

---

## 12. Deployment Architecture

### 12.1 Single-User Desktop Deployment (Current)

**Architecture:**
```
User's Computer
├── R Installation (4.0+)
├── RStudio (optional but recommended)
├── Turas Repository (/path/to/Turas/)
│   ├── modules/
│   ├── templates/
│   └── launch_turas.R
└── User Projects
    ├── Project_A/
    │   ├── data/
    │   ├── config/
    │   └── output/
    └── Project_B/
        ├── data/
        ├── config/
        └── output/
```

**Advantages:**
- Simple setup (no server required)
- Full data control (data never leaves user's computer)
- Works offline
- Fast for typical datasets (<10K rows)

**Setup:**
```r
# 1. Clone repository
git clone https://github.com/org/Turas.git

# 2. Install dependencies
install.packages(c("openxlsx", "readxl", "shiny", "data.table"))

# 3. Launch GUI
source("launch_turas.R")

# Or run modules via CLI
source("modules/tabs/lib/run_crosstabs.R")
```

### 12.2 Team Deployment (Network Share)

**Architecture:**
```
Network Share (Z:/)
├── Turas_Prod/                     # Production version
│   ├── modules/
│   └── launch_turas.R
├── Turas_Dev/                      # Development version
│   └── ...
└── Shared_Projects/
    ├── Client_A/
    ├── Client_B/
    └── Templates/
```

**Workflow:**
1. Analysts open RStudio
2. Set working directory: `setwd("Z:/Shared_Projects/Client_A")`
3. Source Turas: `source("Z:/Turas_Prod/launch_turas.R")`
4. Run analyses
5. Save outputs to shared project folders

**Version Management:**
```r
# Use specific Turas version
source("Z:/Turas_v9.9/launch_turas.R")

# Or latest
source("Z:/Turas_Latest/launch_turas.R")
```

### 12.3 Enterprise Deployment (Future - Shiny Server)

**Potential Architecture:**
```
┌─────────────────────────────────────┐
│     Users (Web Browsers)            │
└──────────────┬──────────────────────┘
               │ HTTPS
┌──────────────▼──────────────────────┐
│       Shiny Server Pro              │
│  ├─ Turas Web App                   │
│  ├─ Authentication (LDAP/SSO)       │
│  └─ Session Management              │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│       Application Server            │
│  ├─ R Session Pool                  │
│  ├─ Turas Modules                   │
│  └─ Background Jobs                 │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│       Data Layer                    │
│  ├─ File Storage (NAS)              │
│  ├─ Database (PostgreSQL)           │
│  └─ Object Storage (S3)             │
└─────────────────────────────────────┘
```

**Features:**
- Web-based access (no R installation needed)
- Multi-user concurrent access
- Centralized data management
- Job queue for long-running analyses
- Automated scheduling
- API access for integrations

**Not Currently Implemented** (planned for future release)

---

## 13. Extension Points

### 13.1 Adding New Statistical Methods

**Example: Adding a new CI method to Confidence module**

**Step 1: Implement method**
```r
# modules/confidence/R/04_proportions.R

calculate_proportion_ci_agresti_coull <- function(p, n, conf_level = 0.95) {
  # Agresti-Coull interval
  # Better for small n than normal approximation

  z <- qnorm(1 - (1 - conf_level) / 2)
  n_tilde <- n + z^2
  p_tilde <- (n * p + z^2 / 2) / n_tilde

  se <- sqrt(p_tilde * (1 - p_tilde) / n_tilde)

  ci_lower <- p_tilde - z * se
  ci_upper <- p_tilde + z * se

  return(list(
    lower = max(0, ci_lower),
    upper = min(1, ci_upper),
    method = "Agresti-Coull"
  ))
}
```

**Step 2: Add to configuration**
```r
# Add column to Question_Analysis sheet: Run_Agresti_Coull (Y/N)
```

**Step 3: Integrate in main processing**
```r
# modules/confidence/R/00_main.R

if (!is.null(q_row$Run_Agresti_Coull) &&
    toupper(q_row$Run_Agresti_Coull) == "Y") {

  ac_ci <- calculate_proportion_ci_agresti_coull(
    p = proportion,
    n = effective_n,
    conf_level = conf_level
  )

  result$agresti_coull <- ac_ci
}
```

**Step 4: Add to output**
```r
# modules/confidence/R/07_output.R

# Add columns for new method in Excel output
```

**Step 5: Document**
```r
# Update TECHNICAL_DOCS.md with method description
# Update USER_MANUAL.md with usage instructions
```

### 13.2 Adding New Question Types (Tabs)

**Example: Adding "Matrix Grid" question type**

**Step 1: Define in Survey_Structure**
```
QuestionCode | QuestionText | Variable_Type
Q10          | Satisfaction Grid | Matrix_Grid
```

**Step 2: Create processor**
```r
# modules/tabs/lib/matrix_grid_processor.R

process_matrix_grid_question <- function(prepared_data, config, error_log) {

  question_info <- prepared_data$question_info
  # ... get sub-questions and scale points

  result_table <- data.frame()

  for (sub_question in sub_questions) {
    for (scale_point in scale_points) {
      # Calculate counts and percentages
      # Build result rows
    }
  }

  return(list(
    question_code = question_info$QuestionCode,
    question_type = "Matrix_Grid",
    table = result_table
    # ... other fields
  ))
}
```

**Step 3: Add to dispatcher**
```r
# modules/tabs/lib/question_dispatcher.R

if (question_type == "Matrix_Grid") {
  result <- process_matrix_grid_question(prepared_data, config, error_log)
}
```

**Step 4: Update validation**
```r
# modules/tabs/lib/validation.R

valid_types <- c(
  "Single_Response", "Multi_Mention", "Rating", "Likert",
  "NPS", "Numeric", "Ranking", "Composite", "Matrix_Grid"  # Add new type
)
```

### 13.3 Creating Custom Modules

**Minimal Module Template:**

```r
# modules/custom_module/R/00_main.R

#' Custom Module Main Function
#'
#' @param config_file Path to configuration Excel file
#' @param verbose Print progress messages
#' @return Results list
#' @export
run_custom_analysis <- function(config_file, verbose = TRUE) {

  if (verbose) cat("Starting custom analysis...\n")

  # 1. Load configuration
  config <- load_custom_config(config_file)
  if (verbose) cat("Configuration loaded\n")

  # 2. Load data
  data <- load_survey_data(config$data_file)
  if (verbose) cat("Data loaded:", nrow(data), "rows\n")

  # 3. Validate
  validation <- validate_inputs(data, config)
  if (validation$has_errors) {
    stop("Validation failed:\n", paste(validation$errors, collapse = "\n"))
  }

  # 4. Process
  results <- process_custom_analysis(data, config)
  if (verbose) cat("Analysis complete\n")

  # 5. Output
  write_custom_output(results, config$output_file)
  if (verbose) cat("Output written to:", config$output_file, "\n")

  # 6. Return
  return(list(
    results = results,
    config = config,
    validation = validation
  ))
}
```

---

## 14. Troubleshooting Guide

### 14.1 Common Issues

#### **Issue: "Configuration file not found"**

**Cause:** Incorrect path or working directory

**Solution:**
```r
# Check current working directory
getwd()

# Set to project directory
setwd("/path/to/project")

# Or use absolute path
run_crosstabs(config_file = "/full/path/to/config.xlsx")

# Check file exists
file.exists("Tabs_Config.xlsx")
```

---

#### **Issue: "Column [Q01] not found in data"**

**Cause:** Survey_Structure QuestionCode doesn't match data column name

**Solution:**
```r
# Check data column names
names(survey_data)

# Check Survey_Structure
structure <- readxl::read_excel("Survey_Structure.xlsx", sheet = "Questions")
View(structure)

# Fix: Ensure QuestionCode matches data column exactly (case-sensitive)
```

---

#### **Issue: "All weights are NA"**

**Cause:** Weight column name incorrect or doesn't exist

**Solution:**
```r
# Check weight column name in config
config$weight_column  # Should match data column

# Check data has weight column
"weight" %in% names(survey_data)

# View weight summary
summary(survey_data$weight)

# Fix in config:
# Settings sheet: Weight_Column | [correct_column_name]
# Or set to NA for unweighted analysis
```

---

#### **Issue: "Excel file fails to open"**

**Cause:** File permissions, file already open, or disk space

**Solution:**
```r
# Check file isn't already open in Excel
# Close Excel and retry

# Check disk space
# df -h (Unix/Mac) or check Windows disk properties

# Check write permissions
file.access("output/", mode = 2)  # 2 = write permission
# Returns 0 if writable, -1 if not

# Try different output location
config$output_file <- "~/Desktop/test_output.xlsx"
```

---

#### **Issue: "Processing is very slow"**

**Cause:** Large dataset, many questions, or inefficient operations

**Solution:**
```r
# 1. Check dataset size
dim(survey_data)
object.size(survey_data)

# 2. Reduce for testing
survey_data_sample <- survey_data[sample(nrow(survey_data), 1000), ]

# 3. Profile to find bottleneck
library(profvis)
profvis({ result <- run_crosstabs(...) })

# 4. Optimize:
# - Reduce banner columns
# - Disable bootstrap (if using Confidence)
# - Process in batches
# - Convert Excel data to CSV (faster loading)
```

---

#### **Issue: "Out of memory"**

**Cause:** Dataset too large for available RAM

**Solution:**
```r
# Check memory usage
pryr::mem_used()

# Free memory
gc()

# Reduce dataset:
# - Fewer rows (sample)
# - Fewer columns (select only needed variables)

# Process in batches

# Increase available memory (on Windows):
# memory.limit(size = 16000)  # 16 GB
```

---

### 14.2 Module-Specific Issues

**Tabs:**
- No significance letters → Check base sizes (need n ≥ 30)
- Incorrect percentages → Check weight column is numeric
- Missing questions → Check Survey_Structure has all questions

**Tracker:**
- Continuity errors → Review question mapping between waves
- Base drift warnings → Expected if sample composition changed
- Missing wave data → Check wave file paths in config

**Confidence:**
- Bootstrap slow → Reduce iterations (5000 → 1000 for testing)
- Warnings about sample size → Expected if n < 30 for some questions
- DEFF > 3 → Weights are highly variable, consider reviewing

**Segment:**
- No clear clusters → Data may not have natural segments, try different variables
- High outlier count → Expected, review outlier threshold
- Low silhouette → Clusters may overlap, consider fewer clusters

---

### 14.3 Getting Help

**Documentation:**
1. Module QUICK_START.md (5-10 min introduction)
2. Module USER_MANUAL.md (comprehensive guide)
3. Module TECHNICAL_DOCS.md (for developers)
4. docs/TROUBLESHOOTING.md (issue-specific guide)

**Example Files:**
- examples/[module]/basic/ (working examples)
- templates/ (configuration templates)

**Code Review:**
- Read module R code with comments
- Check validation logic for requirements

---

## Appendix A: Module API Quick Reference

### AlchemerParser
```r
run_alchemerparser(
  project_dir,     # Directory with Alchemer export files
  verbose = TRUE
)
```

### Tabs
```r
run_crosstabs(
  config_file,
  survey_structure_file = NULL,  # Can be in config
  data_file = NULL,               # Can be in config
  output_file = NULL              # Can be in config
)
```

### Tracker
```r
run_tracker_analysis(
  config_file,
  output_folder = NULL  # Can be in config
)
```

### Confidence
```r
run_confidence_analysis(
  config_path,
  verbose = TRUE
)
```

### Segment
```r
turas_segment_from_config(
  config_file
)
```

### Conjoint
```r
run_conjoint_analysis(
  config_file,
  data_file = NULL,    # Can be in config
  output_file = NULL   # Can be in config
)
```

### KeyDriver
```r
run_keydriver_analysis(
  config_file
)
```

### Pricing
```r
run_pricing_analysis(
  config_file
)
```

---

## Appendix B: Version History

**v10.0 (2025-12-06) - Current**
- Comprehensive technical documentation
- All 8 modules production-ready
- 67 regression tests
- Modular architecture standardized

**v9.9 (2025-11-04)**
- Tabs module enhanced (modular architecture)
- Confidence module v2.0 (NPS, representativeness)
- Tracker multi-mention support
- Testing framework established

**v9.0 (2024-09-15)**
- Major architecture refactor
- Breaking changes in config structure
- Module independence established

**v8.0 (2024-03-20)**
- Legacy version (incompatible with v9+)

---

## Appendix C: Glossary

| Term | Definition |
|------|------------|
| **Banner** | Demographic variables used as columns in cross-tabulations |
| **Base** | Sample size for a metric (weighted or unweighted) |
| **CI** | Confidence Interval - range likely to contain true population value |
| **DEFF** | Design Effect - efficiency loss from weighting/clustering |
| **Effective N** | Sample size after adjusting for DEFF |
| **MOE** | Margin of Error - precision of an estimate |
| **NPS** | Net Promoter Score - % Promoters minus % Detractors |
| **Sig Testing** | Statistical significance testing (chi-square, t-test, z-test) |
| **Stub** | Questions used as rows in cross-tabulations |
| **Top-2-Box** | Combined top 2 response options (e.g., "Agree" + "Strongly Agree") |
| **Wave** | Single data collection period in tracking study |

---

**Document Version:** 1.0
**Last Updated:** December 6, 2025
**Maintained By:** Turas Development Team
**Next Review:** March 6, 2026

---

**End of Technical Architecture Documentation**
