# Turas Tracker Module

Time-series tracking and trend analysis for longitudinal survey studies.

## Quick Start

```r
source("modules/tracker/run_tracker.R")

run_tracker(
  tracking_config_path = "path/to/tracking_config.xlsx",
  question_mapping_path = "path/to/question_mapping.xlsx",
  data_dir = "path/to/wave/data"
)
```

Or use the GUI:
```r
source("modules/tracker/run_tracker_gui.R")
```

## Features

- Multi-wave trend analysis (2+ waves)
- Question mapping across waves (handles code changes)
- Statistical significance testing (Z-tests, T-tests)
- Banner analysis (demographic breakouts)
- TrackingSpecs custom metrics (mean, top_box, ranges)
- Multiple output formats (Detailed, Wave History)
- Weighted data with design effect calculation

## Required Files

- `tracking_config.xlsx` - Wave definitions and settings
- `question_mapping.xlsx` - Question code mapping
- Wave data files (.xlsx, .csv, or .sav)

## Architecture

```
tracker/
├── run_tracker.R           # Main entry point
├── run_tracker_gui.R       # Shiny GUI
├── tracker_config_loader.R # Configuration parsing
├── wave_loader.R           # Wave data loading
├── question_mapper.R       # Question mapping
├── validation_tracker.R    # Input validation
├── trend_calculator.R      # Trend algorithms
├── banner_trends.R         # Banner breakouts
├── tracker_output.R        # Excel output
└── formatting_utils.R      # Formatting helpers
```

## Dependencies

- openxlsx (Excel I/O)
- readxl (Excel reading)
- Optional: haven (SPSS), shiny/shinyFiles (GUI)

## Documentation

- [USER_MANUAL.md](USER_MANUAL.md) - End-user guide (132KB)
- [TECHNICAL_DOCS.md](TECHNICAL_DOCS.md) - Developer reference
