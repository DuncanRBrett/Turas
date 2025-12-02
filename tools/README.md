# TURAS Utility Tools

This directory contains utility scripts and development tools for TURAS maintenance and setup.

## Template Creation

- **create_all_templates.R** - R script to generate all Excel template files for TURAS modules
- **create_all_templates.py** - Python equivalent for template generation

Use these scripts to regenerate template files when module configurations change.

## Validation & Checking

- **check_excel_sheets.R** - Utility to validate Excel file sheet structures
- **check_documentation_files.sh** - Shell script to check if required documentation exists (Unix/Linux/Mac)
- **check_documentation_files.bat** - Batch script to check documentation (Windows)

## Usage

Run template creation when needed:
```r
setwd("/path/to/Turas")
source("tools/create_all_templates.R")
```

Or with Python:
```bash
cd /path/to/Turas
python tools/create_all_templates.py
```

Check documentation coverage:
```bash
./tools/check_documentation_files.sh
```

## Note

For test and validation scripts, see `/test_projects/` directory.
