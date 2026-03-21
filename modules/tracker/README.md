---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tracker Module

**Version:** 10.2 **Last Updated:** 21 March 2026

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
├── run_tracker.R           # Main entry point
├── run_tracker_gui.R       # Shiny GUI
└── lib/
    ├── 00_guard.R              # TRS guard layer
    ├── constants.R             # Module constants
    ├── tracker_config_loader.R # Configuration parsing
    ├── wave_loader.R           # Wave data loading
    ├── question_mapper.R       # Question mapping
    ├── validation_tracker.R    # Input validation
    ├── trend_calculator.R      # Trend algorithms
    ├── banner_trends.R         # Banner breakouts
    ├── formatting_utils.R      # Formatting helpers
    ├── tracker_output.R        # Excel output
    ├── tracker_dashboard_reports.R # Dashboard reports
    ├── metric_types.R          # Metric constants & validation (v10.1)
    ├── trend_changes.R         # Change calculations (v10.1)
    ├── trend_significance.R    # Significance testing (v10.1)
    └── output_formatting.R     # Excel styles (v10.1)
```

**Note:** Version 10.1 (December 2025) introduced 4 new extracted modules
to reduce code duplication and improve maintainability.

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
| [01_README.md](01_README.md) | This file - quick start and overview |
| [02_TRACKER_OVERVIEW.md](02_TRACKER_OVERVIEW.md) | Module introduction and capabilities |
| [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) | Authoritative architecture reference |
| [04_USER_MANUAL.md](04_USER_MANUAL.md) | End-user operational guide |
| [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) | Developer documentation |
| [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) | Template field reference |
| [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) | Practical examples and tutorials |

------------------------------------------------------------------------

## Templates

Template files are located in the `templates/` subfolder:

-   `Tracker_Config_Template.xlsx` - Configuration template
-   `Tracker_Question_Mapping_Template.xlsx` - Question mapping template

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
