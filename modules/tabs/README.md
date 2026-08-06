# Turas Tabs Module

**Version:** 10.8.1 **Date:** 5 August 2026

Cross-tabulation and survey data analysis engine for market research.

## What It Does

Turas Tabs transforms survey data into professional cross-tabulation reports. Point it at your survey data and configuration files, and it produces formatted Excel workbooks with weighted statistics, significance testing, and demographic breakouts.

## Quick Start

The recommended route is the Turas launcher (from the Turas root directory):

``` r
source("launch_turas.R")
launch_turas()          # click the Tabs tile, browse to your project folder
```

For a scripted (non-GUI) run, point the entry script at a config workbook:

``` r
source("modules/tabs/run_tabs.R")
run_tabs_analysis("path/to/My_Crosstab_Config.xlsx")
```

A complete synthetic demo lives in `examples/tabs/demo_survey/` — run it with:

``` r
run_tabs_analysis("examples/tabs/demo_survey/Demo_Crosstab_Config.xlsx")
```

## What You Need

Before running an analysis, you'll need three things:

1.  **Survey_Structure.xlsx** - Defines your questions, response options, and composite metrics
2.  **Tabs_Config.xlsx** - Specifies analysis settings and which questions to analyze
3.  **Data file** - Your survey responses (Excel, CSV, or SPSS format)

Both template files are available in the `templates/` subfolder of this module (`modules/tabs/templates/`).

## Key Features

-   Cross-tabulation with statistical significance testing
-   Support for multiple question types: Single_Response, Multi_Mention, Rating, NPS, Likert, Ranking, Numeric, Allocation, Open_End, Composite
-   Weighted data analysis with design effect (DEFF) calculations
-   Banner breakout analysis across demographic segments
-   Configurable Excel output with professional formatting
-   Optional self-contained, interactive **data-centric report v2** (live audience
    filter, custom banners, confidence intervals, and an optional Tracking tab) —
    additive and off by default; see [11_DATA_CENTRIC_REPORT_V2.md](docs/11_DATA_CENTRIC_REPORT_V2.md)

## Documentation

This documentation pack contains everything you need:

| Document | Purpose |
|----|----|
| [02_TABS_OVERVIEW.md](docs/02_TABS_OVERVIEW.md) | High-level introduction and capabilities |
| [03_REFERENCE_GUIDE.md](docs/03_REFERENCE_GUIDE.md) | Complete feature reference |
| [04_USER_MANUAL.md](docs/04_USER_MANUAL.md) | Step-by-step usage instructions |
| [05_TECHNICAL_DOCS.md](docs/05_TECHNICAL_DOCS.md) | Developer and architecture reference |
| [06_TEMPLATE_REFERENCE.md](docs/06_TEMPLATE_REFERENCE.md) | Detailed template field specifications |
| [07_EXAMPLE_WORKFLOWS.md](docs/07_EXAMPLE_WORKFLOWS.md) | Real-world usage examples |
| [09_COLOUR_REFERENCE.md](docs/09_COLOUR_REFERENCE.md) | What the config's colour settings control |
| [11_DATA_CENTRIC_REPORT_V2.md](docs/11_DATA_CENTRIC_REPORT_V2.md) | The interactive report: options, TR.MICRO/tracking contracts, enabling, governance |

## Dependencies

**Required:** - openxlsx (Excel file I/O) - readxl (Excel reading)

**Optional:** - haven (SPSS file support) - data.table (faster CSV processing)

Install with:

``` r
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
├── docs/                   # This documentation
└── templates/              # Config and structure templates
```

## Stats Pack

The tabs module supports a diagnostic stats pack workbook. Because tabs
is a legacy procedural module, the stats pack is enabled via an R
option rather than the config file directly:

```r
options(turas.generate_stats_pack = TRUE)
```

The config template includes a `Generate_Stats_Pack` field (in the
ANALYST & CLOSING SECTION) and a **STUDY IDENTIFICATION** section
(`Project_Name`, `Analyst_Name`, `Research_House`) as a reference for
analysts — these fields document intent and appear in the stats pack
Declaration sheet when the option is active.

Output is named `{output}_stats_pack.xlsx`.

------------------------------------------------------------------------

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 10.8.1 | June 2026 | Current version. This table was not kept current through 10.3–10.8 — see version-tagged comments in the code (e.g. `crosstabs_config.R`) and `git log modules/tabs/` for the detail: dashboard settings (10.4), inline SVG charts (10.5), report enhancements (10.6), closing section & qualitative content (10.7), Report-tab background/executive-summary + AddedSlides rename (10.8), config loader cleanup (10.8.1). |
| 10.2 | May 2026 | Added `Allocation` question type for constant-sum / budget-allocation questions; fixed `Variable_Type` dropdown (`Single_Mention` → `Single_Response`) |
| 10.1 | March 2026 | Added `Generate_Stats_Pack` field and STUDY IDENTIFICATION section to config template; documented stats pack support |
| 10.0 | December 2025 | Initial production release |

------------------------------------------------------------------------

## Getting Help

Start with the [User Manual](docs/04_USER_MANUAL.md) for step-by-step guidance, or jump to [Example Workflows](docs/07_EXAMPLE_WORKFLOWS.md) to see practical usage patterns.

For template configuration details, the [Template Reference](docs/06_TEMPLATE_REFERENCE.md) explains every field and option.
