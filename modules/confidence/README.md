---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Confidence Analysis Module

**Version:** 10.2 **Last Updated:** March 2026 **Status:**
Production Ready

------------------------------------------------------------------------

## Overview

The Turas Confidence Module calculates statistical confidence intervals
for survey data. It provides rigorous statistical analysis for
proportions, means, and Net Promoter Score (NPS), with full support for
weighted survey data.

------------------------------------------------------------------------

## Quick Start

### 1. Launch from Turas Suite

``` r
setwd("/path/to/Turas")
source("launch_turas.R")
# Click "Launch Confidence" button
```

### 2. Run from Command Line

``` r
setwd("/path/to/Turas/modules/confidence")
source("R/00_main.R")

run_confidence_analysis(
  config_path = "path/to/your_config.xlsx",
  verbose = TRUE
)
```

------------------------------------------------------------------------

## Key Capabilities

| Feature                | Description                                        |
|------------------------|----------------------------------------------------|
| **Proportions**        | 4 CI methods (MOE, Wilson, Bootstrap, Bayesian)    |
| **Means**              | 3 CI methods (t-distribution, Bootstrap, Bayesian) |
| **NPS**                | Full Net Promoter Score analysis with CIs          |
| **Weighted Data**      | DEFF, effective n, weighted bootstrap              |
| **Representativeness** | Quota checking with traffic-light flags            |
| **HTML Report**        | Interactive report with charts, callouts, method notes |
| **Stats Pack**         | Diagnostic audit workbook for advanced partners — data receipt, methods, assumptions, reproducibility |
| **Sampling Context**   | Tailored CI interpretation by sampling method      |
| **Output**             | Multi-sheet Excel workbook + optional HTML report  |

------------------------------------------------------------------------

## Documentation Pack

| Document | Purpose | Audience |
|----|----|----|
| [**README.md**](README.md) | Quick start guide | Everyone |
| [**MARKETING.md**](MARKETING.md) | Module capabilities for clients | Clients, Sales |
| [**AUTHORITATIVE_GUIDE.md**](AUTHORITATIVE_GUIDE.md) | Deep technical reference | Analysts, Researchers |
| [**USER_MANUAL.md**](USER_MANUAL.md) | Complete setup and usage guide | End Users |
| [**TECHNICAL_DOCS.md**](TECHNICAL_DOCS.md) | Developer documentation | Developers |
| **Confidence_Config_Template.xlsx** | Configuration template | End Users |

------------------------------------------------------------------------

## Requirements

### Software

-   R 4.0+ (R 4.2+ recommended)
-   RStudio (optional but recommended)

### R Packages (with minimum tested versions)

| Package      | Min Version | Purpose                              |
|--------------|-------------|--------------------------------------|
| readxl       | 1.4.3       | Read Excel config and data files     |
| openxlsx     | 4.2.5       | Write formatted Excel output         |
| data.table   | 1.14.8      | Fast CSV loading (optional)          |
| testthat     | 3.1.0       | Unit testing framework (dev only)    |
| future       | 1.33.0      | Parallel bootstrap (optional)        |
| future.apply | 1.11.0      | Parallel bootstrap (optional)        |

``` r
install.packages(c("readxl", "openxlsx", "data.table"))
# Optional (for parallel bootstrap): install.packages(c("future", "future.apply"))
```

------------------------------------------------------------------------

## Configuration Overview

Create an Excel workbook with these sheets:

| Sheet | Required | Purpose |
|----|----|----|
| **File_Paths** | Yes | Data file, output location, weight variable |
| **Study_Settings** | Yes | Confidence level, bootstrap iterations |
| **Question_Analysis** | Yes | Questions to analyze (max 200) |
| **Population_Margins** | No | Quota targets for representativeness |

**New Study_Settings fields (v10.4):**

| Field | Required | Description |
|----|----|----|
| **Generate_Stats_Pack** | No | `Y` or `N` — generate diagnostic stats pack workbook |
| **Project_Name** | No | Project name for stats pack Declaration sheet |
| **Analyst_Name** | No | Analyst name for stats pack Declaration sheet |
| **Research_House** | No | Research organisation name for stats pack Declaration sheet |

See [**USER_MANUAL.md**](USER_MANUAL.md) for detailed configuration.

------------------------------------------------------------------------

## Output

The module generates an Excel workbook with:

1.  **Summary** - Overview of results
2.  **Study_Level** - Sample size, DEFF, weight diagnostics
3.  **Proportions_Detail** - Proportion confidence intervals
4.  **Means_Detail** - Mean confidence intervals
5.  **NPS_Detail** - Net Promoter Score results (if applicable)
6.  **Representativeness_Weights** - Quota checks (if configured)
7.  **Methodology** - Statistical methods documentation
8.  **Warnings** - Data quality issues
9.  **Inputs** - Configuration snapshot

**Optional HTML Report:** Set `Generate_HTML_Report = Y` in
Study_Settings to also produce a self-contained HTML report with
interactive navigation, SVG charts, method comparison tables,
plain-English callouts, and sampling methodology notes tailored to
your declared sampling method.

**Optional Stats Pack:** Set `Generate_Stats_Pack = Y` in Study_Settings (or tick the GUI checkbox) to generate `{output}_stats_pack.xlsx` — a locked diagnostic workbook with Declaration, Data_Used, Assumptions, Warnings, Reproducibility, and Config_Echo sheets.

------------------------------------------------------------------------

## Version History

### v10.4 (March 2026)

-   **Stats pack:** Diagnostic audit workbook generation. Adds
    `Generate_Stats_Pack`, `Project_Name`, `Analyst_Name`,
    `Research_House` config fields.

### v10.3 (March 2026)

-   **Subset question support:** New `Filter_Variable` and
    `Filter_Values` columns in Question_Analysis allow confidence
    intervals on routed/filtered sub-samples with automatic
    base-size callouts in HTML report
-   **Bug fixes:** Fixed switch fallback in sampling_labels.R for
    unrecognised methods; fixed type-safety in ci_dispatcher prior
    extraction; fixed type alignment in proportion stats matching
-   **Validation:** Relaxed confidence level validation to accept
    any value in (0,1), not just 0.90/0.95/0.99
-   **Documentation:** Package versions listed; subset filtering
    guide added to USER_MANUAL

### v10.2 (March 2026)

-   **HTML Report:** Self-contained interactive HTML report with
    summary dashboard, per-question detail panels, forest plots,
    method comparison charts, plain-English callouts, and editable
    comments box
-   **Sampling Method:** New `Sampling_Method` config option (8 values)
    generates tailored interpretation notes explaining what the
    sampling design means for CI reliability
-   **Wilson Fix:** Fixed `Run_Wilson` column name mismatch that
    silently prevented Wilson score intervals from being calculated
-   **Expanded Tests:** New test files for CI dispatcher, mean CI,
    and study-level calculations

### v10.1 (December 2025)

-   **Refactoring release:** Orchestrator pattern architecture
-   Extracted shared logic to focused modules (question_processor.R, ci_dispatcher.R, output_helpers.R)
-   Improved error handling with clear warnings
-   Fixed NULL/NA handling in config validation
-   31% code reduction in main orchestration script

### v2.0.0 (December 2025)

-   Net Promoter Score (NPS) support
-   Quota representativeness checking
-   Weight concentration diagnostics
-   Improved error handling
-   R 4.2+ compatibility

### v1.0.0 (November 2025)

-   Initial release
-   Proportions and means analysis
-   Four confidence interval methods
-   Weighted data support

------------------------------------------------------------------------

## Support

For questions or issues: 1. Check [**USER_MANUAL.md**](USER_MANUAL.md)
troubleshooting section 2. Review Warnings sheet in Excel output 3.
Contact Turas development team

------------------------------------------------------------------------

**Module Status:** Production Ready (v10.2) **Maintainer:** Turas
Development Team
