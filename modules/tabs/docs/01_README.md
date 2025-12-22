# Turas Tabs Module

**Version:** 10.0
**Date:** 22 December 2025

Cross-tabulation and survey data analysis engine for market research.

## What It Does

Turas Tabs transforms survey data into professional cross-tabulation reports. Point it at your survey data and configuration files, and it produces formatted Excel workbooks with weighted statistics, significance testing, and demographic breakouts.

## Quick Start

The fastest way to get started:

```r
# From the Turas root directory
source("turas.R")
turas_load("tabs")

# Run analysis
run_tabs_analysis("path/to/your/project")
```

Or use the graphical interface:

```r
source("modules/tabs/run_tabs_gui.R")
```

## What You Need

Before running an analysis, you'll need three things:

1. **Survey_Structure.xlsx** - Defines your questions, response options, and composite metrics
2. **Tabs_Config.xlsx** - Specifies analysis settings and which questions to analyze
3. **Data file** - Your survey responses (Excel, CSV, or SPSS format)

Both template files are available in the `templates/` subfolder of this documentation.

## Key Features

- Cross-tabulation with statistical significance testing
- Support for multiple question types: Single, Multi, Rating, NPS, Ranking, Numeric, Composite
- Weighted data analysis with design effect (DEFF) calculations
- Banner breakout analysis across demographic segments
- Configurable Excel output with professional formatting

## Documentation

This documentation pack contains everything you need:

| Document | Purpose |
|----------|---------|
| [02_TABS_OVERVIEW.md](02_TABS_OVERVIEW.md) | High-level introduction and capabilities |
| [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) | Complete feature reference |
| [04_USER_MANUAL.md](04_USER_MANUAL.md) | Step-by-step usage instructions |
| [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) | Developer and architecture reference |
| [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) | Detailed template field specifications |
| [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) | Real-world usage examples |

## Dependencies

**Required:**
- openxlsx (Excel file I/O)
- readxl (Excel reading)

**Optional:**
- haven (SPSS file support)
- data.table (faster CSV processing)

Install with:

```r
install.packages(c("openxlsx", "readxl"))
install.packages(c("haven", "data.table"))  # optional
```

## Module Structure

```
modules/tabs/
├── run_tabs.R              # Main entry point
├── run_tabs_gui.R          # GUI interface
├── lib/                    # Core processing library
│   ├── run_crosstabs.R
│   ├── config_loader.R
│   ├── validation.R
│   └── ...
└── docs/                   # This documentation
    └── templates/          # Config and structure templates
```

## Getting Help

Start with the [User Manual](04_USER_MANUAL.md) for step-by-step guidance, or jump to [Example Workflows](07_EXAMPLE_WORKFLOWS.md) to see practical usage patterns.

For template configuration details, the [Template Reference](06_TEMPLATE_REFERENCE.md) explains every field and option.
