---
editor_options: 
  markdown: 
    wrap: 72
---

# AlchemerParser Module

**Parse Alchemer survey files and generate Tabs-ready configuration in
minutes.**

------------------------------------------------------------------------

## Overview

AlchemerParser automates the conversion of Alchemer survey exports into
Turas Tabs configuration files. What typically takes 2-4 hours of manual
work is completed in under 10 minutes with automatic question type
detection, code generation, and grid handling.

**Status:** ✅ Production Ready

**Version:** 1.0

**Last Updated:** 2025-11-20

------------------------------------------------------------------------

## Features

✅ **Automatic Question Type Detection** - NPS (Net Promoter Score) -
Likert scales - Rating scales - Single/Multi-Mention - Ranking - Numeric
& Open-End

✅ **Intelligent Grid Handling** - Radio button grids - Checkbox grids -
Star rating grids - Automatic pivoting and code generation

✅ **Smart Code Generation** - Standardized question codes (Q01, Q02a,
Q04_1) - Automatic padding for large surveys - Other/specify field
detection

✅ **Validation & Review** - Flags ambiguous questions - Identifies
missing data - Text consistency checks

✅ **Multiple Interfaces** - Interactive Shiny GUI - CLI for batch
processing - Integrated into main Turas launcher

------------------------------------------------------------------------

## Quick Start

### Required Input Files

Export these 3 files from your Alchemer survey:

1.  \*\*{ProjectName}\_questionnaire.docx\*\* - Download to Word export
2.  \*\*{ProjectName}\_data_export_map.xlsx\*\* - Data export mapping
    (must do twice - headers with question numbers and with
    questionIDs - copy only the headers into the map.
3.  \*\*{ProjectName}\_translation-export.xlsx\*\* - Translation export

### Launch GUI

``` r
setwd("/path/to/Turas")
source("launch_turas.R")
# Click "Launch AlchemerParser"
```

### Or Use CLI

``` r
source("modules/AlchemerParser/run_alchemerparser.R")

result <- run_alchemerparser(
  project_dir = "/path/to/alchemer/files",
  verbose = TRUE
)
```

### Output Files Generated

1.  \*\*{ProjectName}\_Crosstab_Config.xlsx\*\* - Tabs selection sheet
2.  \*\*{ProjectName}\_Survey_Structure.xlsx\*\* - Questions & options
3.  \*\*{ProjectName}\_Data_Headers.xlsx\*\* - Column headers for data

------------------------------------------------------------------------

## Documentation

| Document | Purpose | Time to Read |
|----------------------|--------------------|------------------------------|
| [QUICK_START.md](QUICK_START.md) | Get started in 10 minutes | 5 min |
| [USER_MANUAL.md](USER_MANUAL.md) | Comprehensive user guide | 30 min |
| [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md) | Developer documentation | 45 min |
| [EXAMPLE_WORKFLOWS.md](EXAMPLE_WORKFLOWS.md) | Real-world examples | 20 min |

------------------------------------------------------------------------

## Requirements

### R Packages

``` r
install.packages(c("readxl", "openxlsx", "officer", "shiny", "shinyFiles", "fs"))
```

### Input Files

-   Alchemer survey with exported files
-   All files must have matching project name prefix

------------------------------------------------------------------------

## Module Structure

```         
AlchemerParser/
├── R/                              # Core parsing functions
│   ├── 00_main.R                   # Main orchestration
│   ├── 01_parse_data_map.R         # Parse data export map
│   ├── 02_parse_translation.R      # Parse translation export
│   ├── 03_parse_word_doc.R         # Parse Word questionnaire
│   ├── 04_classify_questions.R     # Question type detection
│   ├── 05_generate_codes.R         # Code generation & validation
│   └── 06_output.R                 # Output file generation
├── run_alchemerparser.R            # CLI entry point
├── run_alchemerparser_gui.R        # Shiny GUI
├── QUICK_START.md                  # Quick start guide
├── USER_MANUAL.md                  # Comprehensive user manual
├── TECHNICAL_DOCUMENTATION.md      # Developer documentation
├── EXAMPLE_WORKFLOWS.md            # Real-world examples
└── README.md                       # This file
```

------------------------------------------------------------------------

## Usage Examples

### Basic Survey

``` r
result <- run_alchemerparser(
  project_dir = "/data/CustomerSat2025/",
  verbose = TRUE
)
# Outputs: 15 questions, 0 flags
```

### Batch Processing

``` r
projects <- c("Survey_A", "Survey_B", "Survey_C")

for (proj in projects) {
  run_alchemerparser(
    project_dir = file.path("/data", proj),
    output_dir = file.path("/outputs", proj)
  )
}
```

### Review Validation Flags

``` r
result <- run_alchemerparser(project_dir = "/data/survey/")

if (result$summary$n_flags > 0) {
  for (flag in result$validation_flags) {
    cat(sprintf("[%s] %s: %s\n",
                flag$severity,
                flag$q_code,
                flag$details))
  }
}
```

------------------------------------------------------------------------

## Question Type Detection

AlchemerParser uses a hierarchical detection system:

1.  **NPS** - 11 options (0-10) + "recommend" in question text
2.  **Likert** - Options contain disagree/neutral/agree
3.  **Rating** - 5/7/10-point scales with satisfaction/quality terms
4.  **Ranking** - "rank" keyword or sequential position data
5.  **Multi_Mention** - `[ ]` brackets in Word doc or multiple columns
6.  **Single_Response** - `( )` brackets or default
7.  **Numeric** - Numeric input or slider
8.  **Open_End** - Text box (excluded from analysis)

------------------------------------------------------------------------

## Grid Question Handling

### Radio Button Grid

**Input:** Multiple rows, single choice per row **Output:** Q##a, Q##b,
Q##c (Single_Response per row)

### Checkbox Grid

**Input:** Multiple rows, multiple choices per row **Output:** Q##a,
Q##b, Q##c (Multi_Mention per row with \_1, \_2, \_3 suffixes)

### Star Rating Grid

**Input:** Multiple items rated on same scale **Output:** Q##a, Q##b,
Q##c (Rating per item)

------------------------------------------------------------------------

## Troubleshooting

| Issue | Solution |
|------------------------------|------------------------------------------|
| "Files not found" | Ensure all 3 files have matching project name prefix |
| "Translation missing columns" | Re-export from Alchemer with "Key" and "Default Text" columns |
| Questions all classified as Single_Response | Check Word doc is .docx format with proper question numbering |
| Grid questions not detected | Verify data export is mapping file (not data) with Question Numbers format |

------------------------------------------------------------------------

## Integration with Tabs Module

After parsing:

1.  **Rename data file columns** - Use Data_Headers.xlsx to replace
    Alchemer column names
2.  **Load Crosstab_Config** - Import into Tabs for banner/selection
    setup
3.  **Load Survey_Structure** - Import into Tabs for question/option
    definitions
4.  **Run analysis** - Use Tabs module for cross-tabulation

------------------------------------------------------------------------

## Performance

| Survey Size    | Parse Time    |
|----------------|---------------|
| 20 questions   | \< 5 seconds  |
| 50 questions   | \< 10 seconds |
| 100+ questions | \< 30 seconds |

------------------------------------------------------------------------

## Validation & Quality

AlchemerParser flags issues for manual review:

-   **ERROR** - Critical issues requiring fixes (e.g., missing options)
-   **WARNING** - Potential problems (e.g., missing translation)
-   **REVIEW** - Ambiguous classifications (e.g., unclear question type)

Always review flagged items before using outputs in Tabs.

------------------------------------------------------------------------

## Limitations

-   Requires all 3 Alchemer export files
-   Word questionnaire must be .docx format
-   Grid detection depends on consistent Alchemer export structure
-   Some edge cases may require manual review

------------------------------------------------------------------------

## Future Enhancements

Potential additions (not yet implemented):

-   Support for skip logic metadata
-   Custom question type definitions
-   Batch validation reports
-   Direct Alchemer API integration

------------------------------------------------------------------------

## Support

-   **Quick questions:** See [QUICK_START.md](QUICK_START.md)
-   **Detailed guidance:** See [USER_MANUAL.md](USER_MANUAL.md)
-   **Technical issues:** See
    [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md)
-   **Examples:** See [EXAMPLE_WORKFLOWS.md](EXAMPLE_WORKFLOWS.md)

------------------------------------------------------------------------

## License

Part of the Turas Analytics Suite.

------------------------------------------------------------------------

## Changelog

### Version 1.0 (2025-11-20)

-   Initial release
-   Core parsing functionality
-   GUI and CLI interfaces
-   Comprehensive documentation
-   Integrated into main Turas launcher

------------------------------------------------------------------------

**Ready to get started?** See [QUICK_START.md](QUICK_START.md) for a
10-minute tutorial.
