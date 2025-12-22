# TURAS Utility Tools

This directory contains utility scripts and development tools for TURAS maintenance and setup.

## Inventory Tools

All inventory scripts are in the `inventory/` subdirectory:

```bash
# Complete file inventory (all file types)
Rscript tools/inventory/file_inventory.R

# Detailed R script analysis with refactoring scores
Rscript tools/inventory/generate_script_inventory.R

# Quick R script inventory (bash)
./tools/inventory/generate_script_inventory.sh
```

**Output:** All reports are saved to `structure/` directory.

See `inventory/README.md` for detailed documentation.

## Template Creation

- **create_all_templates.R** - R script to generate all Excel template files for TURAS modules
- **create_all_templates.py** - Python equivalent for template generation

Use these scripts to regenerate template files when module configurations change:

```r
setwd("/path/to/Turas")
source("tools/create_all_templates.R")
```

Or with Python:
```bash
cd /path/to/Turas
python tools/create_all_templates.py
```

## Validation & Checking

- **check_documentation_files.sh** - Shell script to check if required documentation exists (Unix/Linux/Mac)
- **check_documentation_files.bat** - Batch script to check documentation (Windows)

```bash
./tools/check_documentation_files.sh
```

## Directory Structure

```
tools/
├── README.md                      # This file
├── inventory/                     # Inventory generation scripts
│   ├── README.md
│   ├── file_inventory.R
│   ├── generate_script_inventory.R
│   └── generate_script_inventory.sh
├── create_all_templates.R
├── create_all_templates.py
├── check_documentation_files.sh
└── check_documentation_files.bat
```

## Note

For test and validation scripts, see the `tests/` directory.
