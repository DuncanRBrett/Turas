# Turas Tabs Module

Cross-tabulation and survey data analysis engine for market research.

## Quick Start

```r
# From Turas root
source("turas.R")
turas_load("tabs")

# Run analysis
run_tabs_analysis("path/to/project")
```

Or use the GUI:
```r
source("modules/tabs/run_tabs_gui.R")
```

## Features

- Cross-tabulation with statistical significance testing
- Multiple question types: Single, Multi, Rating, NPS, Ranking, Composite
- Weighted data support with effective N calculation
- Banner breakout analysis (demographic segments)
- Configurable Excel output with formatting

## Required Files

Projects need:
- `Survey_Structure.xlsx` - Question definitions
- `Tabs_Config.xlsx` - Analysis configuration
- Data file (.xlsx, .csv, or .sav)

## Architecture

```
lib/
├── run_crosstabs.R       # Main orchestration
├── config_loader.R       # Configuration parsing
├── validation.R          # Input validation
├── question_dispatcher.R # Question type routing
├── standard_processor.R  # Single/Multi processing
├── numeric_processor.R   # Rating/NPS processing
├── weighting.R           # Weight calculations
├── excel_writer.R        # Output generation
└── shared_functions.R    # Utilities
```

## Dependencies

- openxlsx (Excel I/O)
- readxl (Excel reading)
- Optional: haven (SPSS support), data.table (faster CSV)

## Documentation

- [USER_MANUAL.md](USER_MANUAL.md) - End-user guide
- [TECHNICAL_DOCS.md](TECHNICAL_DOCS.md) - Developer reference
