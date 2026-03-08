# Confidence Module - Script Inventory

## Overview

Complete inventory of all scripts in the TURAS Confidence module. This module provides production-ready confidence interval estimation for survey data, supporting proportions, means, and NPS statistics with multiple CI methods (MOE, Wilson, Bootstrap, Bayesian Credible).

## Inventory

| Script | Lines | Purpose | Status | Quality |
|--------|-------|---------|--------|---------|
| R/00_guard.R | 619 | TRS v1.0 guard layer - validates all inputs before processing | Active | 5/5 |
| R/00_main.R | 1077 | Main orchestration - coordinates the full analysis pipeline | Active | 4/5 |
| R/01_load_config.R | 925 | Config loading & validation - reads Excel config into structured list | Active | 4/5 |
| R/02_load_data.R | 503 | Data file I/O - reads CSV/XLSX survey data with validation | Active | 4/5 |
| R/03_study_level.R | 703 | Study-level stats - DEFF, n_eff, representativeness analysis | Active | 5/5 |
| R/04_proportions.R | 669 | Proportion CI methods - Wilson, MOE, Bootstrap, Credible for proportions | Active | 5/5 |
| R/05_means.R | 751 | Mean CI methods - t-based, Bootstrap, Credible for continuous variables | Active | 5/5 |
| R/07_output.R | 1588 | Excel output generation - formatted workbook with results and diagnostics | Active | 4/5 |
| R/ci_dispatcher.R | 393 | CI method dispatch - routes questions to correct CI calculation functions | Active | 5/5 |
| R/output_helpers.R | 399 | Output formatting - number formatting, style helpers for Excel output | Active | 4/5 |
| R/question_processor.R | 473 | Question data prep - extracts and validates per-question data from survey | Active | 4/5 |
| R/utils.R | 588 | Validation & utilities - shared helper functions used across the module | Active | 4/5 |
| lib/generate_config_templates.R | NEW | Professional config templates - Excel template with validation and styling | Active | 5/5 |
| lib/validation/preflight_validators.R | NEW | Pre-flight checks - 13 cross-referential validators run before analysis | Active | 5/5 |
| lib/html_report/00_html_guard.R | 56 | HTML validation - guards for HTML report generation inputs | Active | 4/5 |
| lib/html_report/01_data_transformer.R | 632 | Data transformation - prepares CI results for HTML report rendering | Active | 4/5 |
| lib/html_report/02_table_builder.R | 438 | HTML tables - builds formatted HTML tables from CI results | Active | 4/5 |
| lib/html_report/03_page_builder.R | 942 | Page assembly - constructs full HTML page with navigation and layout | Active | 4/5 |
| lib/html_report/04_html_writer.R | 63 | File writing - writes assembled HTML to disk | Active | 4/5 |
| lib/html_report/05_chart_builder.R | 336 | SVG charts - generates inline SVG confidence interval charts | Active | 4/5 |
| lib/html_report/99_html_report_main.R | 310 | HTML orchestration - coordinates all HTML report sub-modules | Active | 4/5 |
| run_confidence_gui.R | 496 | Shiny GUI - interactive interface for running confidence analysis | Active | 4/5 |
| examples/create_example_config.R | - | Example config generator - creates sample config for demonstration | Supporting | 3/5 |

## Status Definitions

- **Active** - In production use, actively maintained
- **Supporting** - Utility/example script, not part of core pipeline

## Quality Scale

- **5/5** - Production-hardened, comprehensive tests, TRS compliant, well-documented
- **4/5** - Production-ready, good coverage, minor improvements possible
- **3/5** - Functional, limited test coverage or documentation gaps
- **2/5** - Needs refactoring or significant test gaps
- **1/5** - Legacy/deprecated, replacement planned

## Architecture

```
modules/confidence/
├── R/                              # Core analysis pipeline
│   ├── 00_guard.R                  # Input validation (TRS v1.0)
│   ├── 00_main.R                   # Main orchestration
│   ├── 01_load_config.R            # Config loading
│   ├── 02_load_data.R              # Data I/O
│   ├── 03_study_level.R            # Study-level statistics
│   ├── 04_proportions.R            # Proportion CI methods
│   ├── 05_means.R                  # Mean CI methods
│   ├── 07_output.R                 # Excel output
│   ├── ci_dispatcher.R             # Method routing
│   ├── output_helpers.R            # Output formatting
│   ├── question_processor.R        # Question data prep
│   └── utils.R                     # Shared utilities
├── lib/                            # Supporting infrastructure
│   ├── generate_config_templates.R # Professional Excel templates
│   ├── validation/
│   │   └── preflight_validators.R  # Pre-flight cross-reference checks
│   └── html_report/                # HTML report generation
│       ├── 00_html_guard.R
│       ├── 01_data_transformer.R
│       ├── 02_table_builder.R
│       ├── 03_page_builder.R
│       ├── 04_html_writer.R
│       ├── 05_chart_builder.R
│       └── 99_html_report_main.R
├── run_confidence_gui.R            # Shiny GUI entry point
├── examples/
│   └── create_example_config.R     # Example config generator
├── tests/                          # Test suite
│   ├── testthat/                   # Unit & integration tests
│   ├── fixtures/                   # Synthetic test data
│   └── legacy/                     # Older test scripts
├── docs/                           # Documentation
└── SCRIPT_INVENTORY.md             # This file
```

## Pipeline Flow

```
run_confidence_gui.R (or direct call)
  └── R/00_main.R
        ├── R/00_guard.R              (validate inputs)
        ├── R/01_load_config.R        (read config Excel)
        ├── lib/validation/preflight_validators.R  (cross-reference checks)
        ├── R/02_load_data.R          (read survey data)
        ├── R/03_study_level.R        (DEFF, n_eff)
        ├── R/ci_dispatcher.R         (route per question)
        │     ├── R/question_processor.R  (extract question data)
        │     ├── R/04_proportions.R      (proportion CIs)
        │     └── R/05_means.R            (mean CIs)
        ├── R/07_output.R            (Excel workbook)
        │     └── R/output_helpers.R  (formatting)
        └── lib/html_report/99_html_report_main.R  (optional HTML)
              ├── 00_html_guard.R
              ├── 01_data_transformer.R
              ├── 02_table_builder.R
              ├── 03_page_builder.R
              ├── 04_html_writer.R
              └── 05_chart_builder.R
```

## Recent Changes

- **2026-03-08**: Added `lib/generate_config_templates.R` - Professional Excel config templates with shared template infrastructure
- **2026-03-08**: Added `lib/validation/preflight_validators.R` - 13 pre-flight cross-reference validators
- **2026-03-08**: Added `SCRIPT_INVENTORY.md` - This inventory file
