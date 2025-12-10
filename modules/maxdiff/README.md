# Turas MaxDiff Module

**Version:** 10.0
**Part of:** Turas Survey Analysis Suite

## Overview

The MaxDiff module provides comprehensive Best-Worst Scaling (BWS) design generation and analysis capabilities. It supports two operational modes:

- **DESIGN mode**: Generate optimal experimental designs for MaxDiff studies
- **ANALYSIS mode**: Analyze survey responses and compute preference utilities

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
├── run_maxdiff_gui.R      # Shiny GUI
├── README.md              # This file
└── examples/basic/        # Example files
```

## Support

For issues or questions, consult the Turas documentation or contact the development team.
