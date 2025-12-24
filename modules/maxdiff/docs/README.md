# Turas MaxDiff Module

**Version:** 10.0
**Part of:** Turas Survey Analysis Suite

## Overview

The MaxDiff module provides comprehensive Best-Worst Scaling (BWS) design generation and analysis capabilities. It supports two operational modes:

- **DESIGN mode**: Generate optimal experimental designs for MaxDiff studies
- **ANALYSIS mode**: Analyze survey responses and compute preference utilities

## What is MaxDiff?

MaxDiff (Maximum Difference Scaling), also known as Best-Worst Scaling, is a research technique for measuring the relative importance or preference of multiple items. In each task, respondents are shown a subset of items and asked to select:
- The **BEST** (most important/preferred) item
- The **WORST** (least important/preferred) item

This approach forces trade-offs and produces more discriminating results than traditional rating scales.

## Key Features

- Excel-based configuration for non-technical users
- Balanced Incomplete Block Design (BIBD) generation with optimization
- Multiple scoring methods:
  - Count-based scores (Best%, Worst%, Net Score)
  - Aggregate conditional logit model
  - Hierarchical Bayes individual-level utilities
- Segment-level analysis
- Publication-ready visualizations
- Comprehensive validation and logging

## Quick Start

### From R Console

```r
# Source the module
source("modules/maxdiff/R/00_main.R")

# Run MaxDiff (mode determined by config file)
run_maxdiff("path/to/maxdiff_config.xlsx")
```

### From Turas Launcher

1. Launch Turas: `source("launch_turas.R")`
2. Click "MaxDiff" button
3. Browse to select your configuration file
4. Click "Run"

## Typical Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  1. CREATE CONFIG    Create Excel workbook with items       │
│         ↓            and settings                           │
├─────────────────────────────────────────────────────────────┤
│  2. DESIGN MODE      Generate experimental design           │
│         ↓            (run module with Mode = DESIGN)        │
├─────────────────────────────────────────────────────────────┤
│  3. PROGRAM SURVEY   Use design file to build survey        │
│         ↓            in your survey platform                │
├─────────────────────────────────────────────────────────────┤
│  4. COLLECT DATA     Field your survey                      │
│         ↓                                                   │
├─────────────────────────────────────────────────────────────┤
│  5. ANALYSIS MODE    Analyse responses                      │
│                      (run module with Mode = ANALYSIS)      │
└─────────────────────────────────────────────────────────────┘
```

## Documentation

This module includes comprehensive documentation:

1. **[Marketing Guide](MARKETING.md)** - Client-facing overview of MaxDiff capabilities
2. **[Authoritative Guide](AUTHORITATIVE_GUIDE.md)** - Deep dive into Turas MaxDiff methodology
3. **[User Manual](USER_MANUAL.md)** - Complete setup and usage guide
4. **[Template Guide](maxdiff_config_template.xlsx)** - Excel configuration template
5. **[Technical Reference](TECHNICAL_REFERENCE.md)** - Developer documentation
6. **[Example Workflows](EXAMPLE_WORKFLOWS.md)** - Practical step-by-step examples

## Configuration

Create an Excel workbook (.xlsx) with the following sheets:

### Required Sheets

1. **PROJECT_SETTINGS**: Global project parameters
   - `Project_Name`: Unique identifier (no spaces)
   - `Mode`: DESIGN or ANALYSIS
   - `Raw_Data_File`: Path to survey data (ANALYSIS mode)
   - `Design_File`: Path to design file (ANALYSIS mode)
   - `Output_Folder`: Output directory

2. **ITEMS**: Item definitions
   - `Item_ID`: Unique identifier
   - `Item_Label`: Full text description
   - `Include`: 1 to include, 0 to exclude
   - `Anchor_Item`: 1 for anchor item (HB reference)

### Mode-Specific Sheets

3. **DESIGN_SETTINGS** (DESIGN mode):
   - `Items_Per_Task`: Items shown per task (typically 4-5)
   - `Tasks_Per_Respondent`: Tasks per respondent (typically 10-15)
   - `Num_Versions`: Number of design versions
   - `Design_Type`: BALANCED, OPTIMAL, or RANDOM

4. **SURVEY_MAPPING** (ANALYSIS mode):
   - `Field_Type`: VERSION, BEST_CHOICE, WORST_CHOICE
   - `Field_Name`: Column name in survey data
   - `Task_Number`: Task number for choice fields

### Optional Sheets

5. **SEGMENT_SETTINGS**: Segment definitions for subgroup analysis
6. **OUTPUT_SETTINGS**: Output format preferences

## Output

### DESIGN Mode
- `{Project_Name}_MaxDiff_Design.xlsx`: Design matrix with task assignments

### ANALYSIS Mode
- `{Project_Name}_MaxDiff_Results.xlsx`: Complete results workbook
  - SUMMARY: Project metadata and sample sizes
  - ITEM_SCORES: All scoring methods
  - SEGMENT_SCORES: Segment-level results
  - INDIVIDUAL_UTILS: Individual-level utilities (if HB enabled)
  - MODEL_DIAGNOSTICS: Model fit statistics

- Charts (PNG files):
  - Utility bar chart
  - Best-Worst diverging chart
  - Segment comparison charts
  - Utility distribution (HB)

## Dependencies

**Required:**
- openxlsx (Excel files)
- survival (logit models)
- ggplot2 (charts)

**Optional:**
- cmdstanr (Hierarchical Bayes)
- AlgDesign (optimal designs)

## File Structure

```
modules/maxdiff/
├── R/
│   ├── 00_main.R          # Entry point
│   ├── 01_config.R        # Configuration loading
│   ├── 02_validation.R    # Data validation
│   ├── 03_data.R          # Data loading/reshaping
│   ├── 04_design.R        # Design generation
│   ├── 05_counts.R        # Count-based scoring
│   ├── 06_logit.R         # Aggregate logit
│   ├── 07_hb.R            # Hierarchical Bayes
│   ├── 08_segments.R      # Segment analysis
│   ├── 09_output.R        # Excel output
│   ├── 10_charts.R        # Visualizations
│   └── utils.R            # Utilities
├── stan/
│   └── maxdiff_hb.stan    # Stan model
├── docs/
│   ├── README.md              # This file
│   ├── MARKETING.md           # Client-facing overview
│   ├── AUTHORITATIVE_GUIDE.md # Deep methodology guide
│   ├── USER_MANUAL.md         # Complete user guide
│   ├── TECHNICAL_REFERENCE.md # Developer documentation
│   ├── EXAMPLE_WORKFLOWS.md   # Practical examples
│   └── maxdiff_config_template.xlsx  # Excel template
├── templates/
│   └── create_maxdiff_template.R  # Template generator
├── tests/
│   └── test_maxdiff.R     # Unit tests
├── examples/
│   └── basic/             # Example files
└── run_maxdiff_gui.R      # Shiny GUI
```

## Support

For detailed information:
- **Users**: See [User Manual](USER_MANUAL.md) for step-by-step instructions
- **Clients**: See [Marketing Guide](MARKETING.md) for capabilities overview
- **Developers**: See [Technical Reference](TECHNICAL_REFERENCE.md) for API documentation
- **Examples**: See [Example Workflows](EXAMPLE_WORKFLOWS.md) for practical use cases

For issues or questions, consult the documentation or contact the development team.
