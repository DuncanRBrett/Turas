---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Confidence Analysis Module

**Version:** 10.1 **Last Updated:** December 2025 **Status:**
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
| **Output**             | Multi-sheet Excel workbook                         |

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

### R Packages

``` r
install.packages(c("readxl", "openxlsx", "data.table"))
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

------------------------------------------------------------------------

## Version History

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

**Module Status:** Production Ready **Maintainer:** Turas Development
Team
