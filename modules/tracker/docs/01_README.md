---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tracker Module

**Version:** 10.0 **Last Updated:** 22 December 2025

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
    └── tracker_dashboard_reports.R # Dashboard reports
```

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
