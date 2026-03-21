# Turas MaxDiff Module

**Version:** 11.1
**Part of:** Turas Analytics Platform

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
- Balanced Incomplete Block Design (BIBD) generation with D-optimal optimization
- Multiple scoring methods:
  - Count-based scores (Best%, Worst%, Net Score, BW Score)
  - Aggregate conditional logit model (via survival::clogit)
  - Hierarchical Bayes individual-level utilities (via Stan/cmdstanr)
- **TURF portfolio optimization** — find the item combination that reaches the most people
- **Anchored MaxDiff** — add absolute "must-have" benchmarks to relative preferences
- **Item discrimination analysis** — classify items as universal favourites, polarizing, or niche
- Segment-level analysis with grouped bar chart visualisations
- **Self-contained HTML report** with tabbed navigation, interactive table sorting, and SVG charts
- **Interactive preference simulator** with portfolio builder, head-to-head comparison, and export
- Add-slides and add-images support for custom report content
- Publication-ready ggplot2 visualizations (PNG)
- Comprehensive Excel output with conditional formatting
- Reach sensitivity analysis across threshold methods
- TRS v1.0 compliant error handling and run status tracking
- **Diagnostic stats pack** — on-demand audit workbook covering data received, methods, assumptions, and reproducibility for advanced partners and statisticians

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

1. **[User Manual](USER_MANUAL.md)** - Complete setup, usage guide, study design, troubleshooting
2. **[Technical Reference](TECHNICAL_REFERENCE.md)** - Statistical methods, API reference, architecture
3. **[Configuration Template](../templates/maxdiff_config_template.xlsx)** - Excel configuration template
4. **[Demo Showcase](../../examples/maxdiff/demo_showcase/)** - Full working example with all features

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
   - `Generate_Stats_Pack`: `YES` or `NO` — generate a diagnostic stats pack workbook alongside main output (named `{Project_Name}_stats_pack.xlsx`)
7. **STUDY_IDENTIFICATION**: Project metadata for the stats pack Declaration sheet
   - `Project_Name`: Project name for sign-off
   - `Analyst_Name`: Analyst name
   - `Research_House`: Research organisation or white-label partner name

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
│   ├── 00_guard.R         # TRS guard layer
│   ├── 00_main.R          # Entry point & orchestration
│   ├── 01_config.R        # Configuration loading
│   ├── 02_validation.R    # Data validation
│   ├── 03_data.R          # Data loading/reshaping
│   ├── 04_design.R        # Design generation (BALANCED/OPTIMAL/RANDOM)
│   ├── 05_counts.R        # Count-based scoring
│   ├── 06_logit.R         # Aggregate conditional logit
│   ├── 07_hb.R            # Hierarchical Bayes (Stan/cmdstanr)
│   ├── 08_segments.R      # Segment analysis
│   ├── 09_output.R        # Excel output with conditional formatting
│   ├── 10_charts.R        # ggplot2 chart generation
│   ├── 11_turf.R          # TURF portfolio optimisation
│   └── utils.R            # Shared utilities
├── lib/
│   ├── html_report/       # Self-contained HTML report pipeline
│   │   ├── 01_data_transformer.R
│   │   ├── 02_table_builder.R
│   │   ├── 03_page_builder.R
│   │   ├── 04_chart_builder.R
│   │   └── 99_html_report_main.R
│   └── html_simulator/    # Interactive preference simulator
│       ├── 01_simulator_data_transformer.R
│       ├── 02_simulator_page_builder.R
│       ├── 99_simulator_main.R
│       └── js/            # 5 JavaScript modules
├── stan/
│   └── maxdiff_hb.stan    # HB Stan model
├── docs/
│   ├── README.md              # This file
│   ├── USER_MANUAL.md         # Complete user guide (v11.1)
│   └── TECHNICAL_REFERENCE.md # Statistical methods & API (v11.1)
├── templates/
│   ├── create_maxdiff_template.R    # Template generator
│   └── maxdiff_config_template.xlsx # Excel config template
├── tests/
│   ├── testthat/          # 13 test files
│   ├── test_maxdiff.R     # Standalone test runner
│   └── run_full_tests.R   # Integration test suite
├── examples/
│   └── basic/             # Built-in example
└── run_maxdiff_gui.R      # Shiny GUI launcher
```

## Support

For detailed information:
- **Users**: See [User Manual](USER_MANUAL.md) for step-by-step instructions
- **Developers**: See [Technical Reference](TECHNICAL_REFERENCE.md) for API documentation
- **Demo**: See [Demo Showcase](../../examples/maxdiff/demo_showcase/) for a working example

For issues or questions, consult the documentation or contact the development team.

---

## Version History

### v11.2 (2026-03-21)

- Added `Generate_Stats_Pack` to `OUTPUT_SETTINGS` — generates a diagnostic stats pack workbook (`{Project_Name}_stats_pack.xlsx`) alongside main output, providing a full audit trail of data received, methods used, assumptions, and reproducibility for advanced partners and research statisticians.
- Added `STUDY_IDENTIFICATION` sheet to config template (`Project_Name`, `Analyst_Name`, `Research_House`) for stats pack Declaration sheet sign-off.
