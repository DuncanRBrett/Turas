# Turas Conjoint Analysis Module

**Version:** 3.0.0
**Last Updated:** March 2026
**Status:** Production Ready

---

## Overview

The Turas Conjoint Module is a world-class Choice-Based Conjoint (CBC) analysis platform. It estimates consumer preferences at both aggregate and individual level using Hierarchical Bayes, discovers preference-based segments via Latent Class Analysis, calculates Willingness to Pay, optimizes product configurations, and delivers results through interactive HTML reports and standalone browser-based market simulators.

---

## Quick Start

### 1. Launch from Turas Suite

```r
setwd("/path/to/Turas")
source("launch_turas.R")
# Click "Launch Conjoint" button
```

### 2. Run from Command Line

```r
setwd("/path/to/Turas/modules/conjoint")
source("R/00_main.R")

run_conjoint_analysis(
  config_file = "path/to/your_config.xlsx",
  verbose = TRUE
)
```

---

## Key Capabilities

| Feature | Description | Status |
|---------|-------------|--------|
| **Choice-Based Conjoint** | MNL via mlogit (primary) and clogit (fallback) | Production |
| **Hierarchical Bayes** | Individual-level utilities via bayesm | Production |
| **Latent Class Analysis** | Preference-based segmentation (2-K classes) | Production |
| **Part-Worth Utilities** | Aggregate + individual-level estimates | Production |
| **Attribute Importance** | Relative importance percentages | Production |
| **Willingness to Pay** | Monetary value of attribute levels with CIs | Production |
| **Product Optimizer** | Exhaustive + greedy search for optimal configs | Production |
| **Market Simulator (Excel)** | Interactive dropdown tool in output workbook | Production |
| **Market Simulator (HTML)** | Standalone browser-based what-if analysis | Production |
| **HTML Analysis Report** | Tabbed interactive report with charts | Production |
| **Source of Volume** | Share-shift analysis for new product entry | Production |
| **Demand Curves** | Price sensitivity sweep | Production |
| **Interaction Effects** | Config-driven 2-way interactions | Production |
| **Best-Worst Scaling** | Sequential and simultaneous BWS | Production |
| **Alchemer Integration** | Direct import of Alchemer CBC exports | Production |
| **None Option** | Support for "None of these" alternatives | Production |
| **Confidence Intervals** | Delta method and individual-level CIs | Production |
| **Report Hub Integration** | Meta tags for Turas Report Hub | Production |

---

## Documentation Pack

| Document | Purpose | Audience |
|----------|---------|----------|
| **[README.md](README.md)** | Quick start guide | Everyone |
| **[MARKETING.md](MARKETING.md)** | Module capabilities for clients | Clients, Sales |
| **[AUTHORITATIVE_GUIDE.md](AUTHORITATIVE_GUIDE.md)** | Statistical methodology reference | Analysts, Researchers |
| **[USER_MANUAL.md](USER_MANUAL.md)** | Complete setup and usage guide | End Users |
| **[TECHNICAL_DOCS.md](TECHNICAL_DOCS.md)** | Developer documentation | Developers |
| **[EXAMPLE_WORKFLOWS.md](EXAMPLE_WORKFLOWS.md)** | Common use cases and examples | Everyone |
| **Conjoint_Config_Template.xlsx** | Configuration template | End Users |

---

## Requirements

### Software
- R 4.0+ (R 4.2+ recommended)
- RStudio (optional but recommended)

### R Packages

```r
# Required (core estimation)
install.packages(c("mlogit", "dfidx", "survival", "openxlsx"))

# Required for HB/LC estimation
install.packages("bayesm")

# Optional (diagnostics)
install.packages("coda")
```

---

## Estimation Methods

| Method | Config Value | Description |
|--------|-------------|-------------|
| **Auto** | `auto` | Tries mlogit, falls back to clogit |
| **mlogit** | `mlogit` | Primary MNL engine (recommended) |
| **clogit** | `clogit` | Cox regression fallback |
| **Hierarchical Bayes** | `hb` | Individual-level utilities (bayesm) |
| **Latent Class** | `latent_class` | Preference-based segmentation |
| **Best-Worst** | `best_worst` | BWS via exploded logit |

---

## Configuration Overview

Create an Excel workbook with these sheets:

| Sheet | Required | Purpose |
|-------|----------|---------|
| **Instructions** | No | Documentation (not read by code) |
| **Settings** | Yes | Analysis parameters, file paths |
| **Attributes** | Yes | Product attributes and levels |

### Key Settings (v3.0.0)

| Setting | Values | Default | Description |
|---------|--------|---------|-------------|
| `estimation_method` | auto, mlogit, clogit, hb, latent_class | auto | Estimation engine |
| `hb_iterations` | Integer | 10000 | MCMC iterations for HB |
| `hb_burnin` | Integer | 5000 | Burn-in iterations for HB |
| `latent_class_min` | Integer | 2 | Minimum classes for LC |
| `latent_class_max` | Integer | 5 | Maximum classes for LC |
| `generate_html_report` | Y/N | N | Generate HTML analysis report |
| `generate_html_simulator` | Y/N | N | Generate standalone HTML simulator |
| `wtp_price_attribute` | Attribute name | (none) | Price attribute for WTP |
| `simulation_method` | logit, first_choice, rfc | logit | Simulation method |
| `brand_colour` | #XXXXXX | #2563eb | Brand colour for HTML output |
| `accent_colour` | #XXXXXX | #f59e0b | Accent colour for HTML output |
| `interaction_terms` | Attr1:Attr2,... | (none) | Interaction terms to estimate |

See **[USER_MANUAL.md](USER_MANUAL.md)** for detailed configuration.

---

## Data Requirements

Your conjoint data file must contain:

| Column | Purpose |
|--------|---------|
| resp_id | Respondent identifier |
| choice_set_id | Choice task identifier |
| alternative_id | Alternative within choice set |
| [Attributes] | One column per product attribute |
| chosen | Binary indicator (1 = chosen, 0 = not) |

**Critical:** Each choice set must have exactly ONE chosen=1.

---

## Output

### Excel Workbook
1. **Utilities** - Part-worth utilities for each level
2. **Relative_Importance** - Attribute importance percentages
3. **Market_Simulator** - Interactive dropdown tool
4. **Model_Summary** - Fit statistics and diagnostics
5. **Confidence_Intervals** - CIs for utilities
6. **Individual_Utilities** - Per-respondent utilities (HB/LC only)
7. **HB_Diagnostics** - MCMC convergence assessment (HB/LC only)
8. **Respondent_Quality** - RLH scores and quality flags (HB/LC only)
9. **Class_Comparison** - BIC/AIC across K solutions (LC only)
10. **Class_Profiles** - Class-level utilities and importance (LC only)
11. **Class_Membership** - Respondent-to-class assignment (LC only)
12. **README** - Interpretation guide

### HTML Report
- Tabbed interactive report (Overview, Utilities, Diagnostics, Latent Classes)
- SVG charts for importance, utilities, BIC comparison
- Report Hub integration via meta tags

### HTML Simulator
- Self-contained file (no server required)
- Product configuration with dropdowns
- Market share visualization
- Sensitivity analysis
- Source of volume
- Export-to-PNG capability

---

## Architecture

```
modules/conjoint/
  R/
    00_main.R              Main orchestrator
    00_guard.R             TRS guard layer
    01_config.R            Configuration loading
    02_data_loader.R       Data loading and validation
    03_estimation.R        Multi-method estimation dispatch
    04_utilities.R         Utility calculation
    05_simulator.R         Market simulation engine
    06_interactions.R      Interaction effects
    07_output.R            Excel output generation
    08_market_simulator.R  Excel simulator builder
    09_diagnostics.R       Model diagnostics
    10_best_worst.R        Best-worst scaling
    11_hierarchical_bayes.R  HB estimation
    12_config_template.R   Config template generator
    13_latent_class.R      Latent class analysis
    14_willingness_to_pay.R  WTP estimation
    15_product_optimizer.R Product optimization
  lib/
    html_report/           HTML analysis report (4-layer)
    html_simulator/        Standalone HTML simulator
  tests/
    testthat/              Unit and integration tests
    fixtures/              Synthetic test data
  docs/                    Documentation
```

---

## Version History

### v3.0.0 (March 2026)
- Hierarchical Bayes estimation (bayesm)
- Latent Class Analysis with BIC selection
- Willingness to Pay with individual-level distributions
- Product optimizer (exhaustive + greedy)
- Standalone HTML market simulator
- Interactive HTML analysis report
- Source of volume analysis
- Demand curves and price sensitivity
- Config-driven interaction effects
- Best-worst scaling (base R, no dplyr dependency)
- Report Hub integration
- Respondent quality flagging (individual RLH)
- MCMC convergence diagnostics

### v2.1.0 (December 2025)
- Alchemer CBC direct import
- Automatic level name cleaning
- Enhanced validation

### v2.0.0 (November 2025)
- Multi-respondent data support
- Hit rate calculation fixes
- Market simulator improvements

### v1.0.0 (October 2025)
- Initial release
- CBC with mlogit/clogit estimation
- Part-worth utilities and importance

---

## Support

For questions or issues:
1. Check **[USER_MANUAL.md](USER_MANUAL.md)** troubleshooting section
2. Review Model_Summary sheet in output
3. Contact Turas development team

---

**Module Status:** Production Ready
**Maintainer:** Turas Development Team
