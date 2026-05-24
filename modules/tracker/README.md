---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tracker Module

**Version:** 10.2 **Last Updated:** 24 May 2026

Time-series tracking and trend analysis for longitudinal survey studies.

------------------------------------------------------------------------

## Quick Start

``` r
source("modules/tracker/run_tracker.R")

run_tracker(
  tracking_config_path = "path/to/tracking_config.xlsx",
  question_mapping_path = "path/to/question_mapping.xlsx",
  data_dir = "path/to/wave/data"
)
```

Or use the GUI:

``` r
source("modules/tracker/run_tracker_gui.R")
run_tracker_gui()
```

------------------------------------------------------------------------

## Features

-   Multi-wave trend analysis (2+ waves)
-   Question mapping across waves (handles code changes)
-   Statistical significance testing (Z-tests, T-tests)
-   Banner analysis (demographic breakouts)
-   TrackingSpecs custom metrics (mean, top_box, ranges)
-   Multiple output formats (Detailed, Wave History, Dashboard, Sig
    Matrix)
-   Weighted data with design effect calculation

------------------------------------------------------------------------

## Required Files

| File | Purpose |
|-----------------------------|-------------------------------------------|
| `tracking_config.xlsx` | Wave definitions, settings, tracked questions, banner |
| `question_mapping.xlsx` | Question code mapping across waves with TrackingSpecs |
| Wave data files | Survey data per wave (.xlsx, .csv, or .sav) |

See [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) for complete
template documentation.

------------------------------------------------------------------------

## Module Architecture

```
tracker/
├── run_tracker.R                   # Main entry point (CLI / programmatic)
├── run_tracker_gui.R               # Shiny GUI launcher
└── lib/
    │
    ├── Bootstrapping & shared helpers
    │   ├── 00_guard.R              # TRS guard layer + refusal fallback
    │   ├── constants.R             # Module constants (alpha, min_base, etc.)
    │   └── formatting_utils.R      # Shared number / label formatters
    │
    ├── Config & input loading
    │   ├── tracker_config_loader.R # tracking_config.xlsx parser
    │   ├── question_mapper.R       # Question code mapping across waves
    │   ├── wave_loader.R           # Wave data ingest (.xlsx/.csv/.sav)
    │   ├── validation_tracker.R    # Post-load validation
    │   └── validation/
    │       └── preflight_validators.R  # Pre-run config sanity checks
    │
    ├── Trend & significance engine
    │   ├── metric_types.R          # Metric type constants & validators
    │   ├── statistical_core.R      # Single source for t-test, z-test,
    │   │                           #   weighted mean, NPS, proportions,
    │   │                           #   top/bottom box, custom range
    │   ├── trend_changes.R         # Wave-over-wave change calculations
    │   ├── trend_significance.R    # Significance test orchestration
    │   ├── trend_calculator.R      # Per-question trend orchestration
    │   └── banner_trends.R         # Demographic-banner breakouts
    │
    ├── Tracking crosstab engine
    │   ├── tracking_crosstab_engine.R   # Crosstab calculation core
    │   └── tracking_crosstab_excel.R    # Crosstab Excel writer
    │
    ├── Excel output
    │   ├── output_formatting.R         # Shared Excel styles
    │   ├── tracker_output.R            # Main detailed / wave-history writer
    │   ├── tracker_output_banners.R    # Banner-cut Excel writer
    │   ├── tracker_output_extended.R   # Extended-format Excel writer
    │   └── tracker_dashboard_reports.R # Dashboard / sig-matrix writer
    │
    ├── HTML report
    │   └── html_report/
    │       ├── 00_html_guard.R         # HTML report guard layer
    │       ├── 01_data_transformer.R   # Trend results → render model
    │       ├── 02_table_builder.R      # Per-question table HTML
    │       ├── 03_page_builder.R       # Page assembly
    │       ├── 03a_page_styling.R      # CSS + design tokens
    │       ├── 03b_page_components.R   # Reusable HTML components
    │       ├── 03c_summary_builder.R   # Executive summary builder
    │       ├── 03f_heatmap_builder.R   # Significance heatmap
    │       ├── 04_html_writer.R        # Final HTML emission
    │       ├── 05_chart_builder.R      # Trend chart SVG/HTML
    │       └── 99_html_report_main.R   # HTML report orchestrator
    │
    └── Template generation (script, not runtime)
        └── generate_config_templates.R # Builds Tracker_Config_Template.xlsx
```

**v10.2 (March 2026):** added `Generate_Stats_Pack` config field + STUDY
IDENTIFICATION section. Diagnostic workbook is produced by the same
output layer.

**v10.1 (December 2025):** extracted four sub-modules from `trend_calculator.R`
(`metric_types`, `trend_changes`, `trend_significance`, `output_formatting`)
to reduce duplication and isolate the statistical core.

------------------------------------------------------------------------

## Dependencies

**Required:** - openxlsx (\>= 4.2.5) - Excel I/O - readxl (\>= 1.4.0) -
Excel reading

**Optional:** - haven (\>= 2.5.0) - SPSS .sav support - foreign (\>=
0.8-0) - Stata .dta support - shiny (\>= 1.7.0) - GUI interface -
shinyFiles (\>= 0.9.0) - File selection in GUI

------------------------------------------------------------------------

## Documentation Pack

| Document | Purpose |
|--------------------------------------|----------------------------------|
| `README.md` (this file) | Quick start, architecture, dependencies, version history |
| [docs/02_TRACKER_OVERVIEW.md](docs/02_TRACKER_OVERVIEW.md) | Module introduction and capabilities |
| [docs/03_REFERENCE_GUIDE.md](docs/03_REFERENCE_GUIDE.md) | Authoritative architecture reference |
| [docs/04_USER_MANUAL.md](docs/04_USER_MANUAL.md) | End-user operational guide |
| [docs/05_TECHNICAL_DOCS.md](docs/05_TECHNICAL_DOCS.md) | Developer documentation |
| [docs/06_TEMPLATE_REFERENCE.md](docs/06_TEMPLATE_REFERENCE.md) | Template field reference |
| [docs/07_EXAMPLE_WORKFLOWS.md](docs/07_EXAMPLE_WORKFLOWS.md) | Practical examples and tutorials |
| [docs/MULTI_MENTION_TRACKING_INSTRUCTIONS.md](docs/MULTI_MENTION_TRACKING_INSTRUCTIONS.md) | Multi-mention configuration deep-dive |
| [docs/CODE_INVENTORY.md](docs/CODE_INVENTORY.md) | File-by-file inventory |
| [docs/PRODUCTION_REVIEW_2026-05-24.md](docs/PRODUCTION_REVIEW_2026-05-24.md) | Most recent production review |
| [docs/GROWTH_PATH_2026-05-24.md](docs/GROWTH_PATH_2026-05-24.md) | Growth path from that review |

------------------------------------------------------------------------

## Templates

Template files are located in [`docs/templates/`](docs/templates/):

-   `Tracking_Config.xlsx` — Configuration template
-   `Question_Mapping.xlsx` — Question mapping template
-   `generate_templates.R` — Script to regenerate templates after schema changes

## Stats Pack

Set `Generate_Stats_Pack = Y` in the Settings sheet to produce a
diagnostic workbook alongside the main output. The stats pack is named
`{output}_stats_pack.xlsx` and contains a full audit trail: data
received, methods applied, assumptions, and reproducibility
information. Intended for advanced partners and research statisticians.

Optionally set `Project_Name`, `Analyst_Name`, and `Research_House` in
the **STUDY IDENTIFICATION** section of the Settings sheet — these
appear on the stats pack Declaration sheet for sign-off purposes.

------------------------------------------------------------------------

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 10.2 | March 2026 | Added `Generate_Stats_Pack` config field and STUDY IDENTIFICATION section (`Project_Name`, `Analyst_Name`, `Research_House`) to config template |
| 10.1 | December 2025 | Extracted 4 new sub-modules (metric_types, trend_changes, trend_significance, output_formatting) |
