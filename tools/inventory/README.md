# Turas Inventory Tools

This directory contains all inventory generation scripts for the Turas project.

## Overview

Three inventory scripts provide different views of the codebase:

| Script | Purpose | Output |
|--------|---------|--------|
| `file_inventory.R` | Complete file inventory (all file types) | `structure/TURAS_FILE_INVENTORY.csv` |
| `generate_script_inventory.R` | Detailed R script analysis with refactoring scores | `structure/r_script_inventory.csv` + `.html` |
| `generate_script_inventory.sh` | Quick R script inventory (bash) | `structure/r_script_inventory_quick.csv` |

## Quick Start

### Option 1: Complete File Inventory

Inventories ALL files in the project (R scripts, docs, configs, data files, etc.):

```bash
# From repository root
Rscript tools/inventory/file_inventory.R
```

**Output:** `structure/TURAS_FILE_INVENTORY.csv`

Includes:
- File name, path, and location
- File type and category
- Size and modification date
- Purpose inference
- Quality assessment
- Status classification (Active/Supporting/Archived/Informational)

### Option 2: Detailed R Script Analysis

Analyzes all R scripts with refactoring complexity ratings:

```bash
# From repository root
Rscript tools/inventory/generate_script_inventory.R
```

**Output:**
- `structure/r_script_inventory.csv` - Detailed CSV
- `structure/r_script_inventory.html` - Interactive HTML dashboard

Includes:
- Lines of code (total, code, comments, blank)
- Function count and names
- Task/purpose extraction
- Refactoring complexity score (1-10)
- Refactoring recommendations

### Option 3: Quick R Script Inventory

Fast bash-based inventory for R scripts only:

```bash
# From repository root
./tools/inventory/generate_script_inventory.sh
```

**Output:** `structure/r_script_inventory_quick.csv`

## Output Location

All inventory reports are saved to the `structure/` directory to keep the repository root clean.

```
Turas/
├── structure/                          # Generated reports
│   ├── README.md
│   ├── TURAS_FILE_INVENTORY.csv
│   ├── r_script_inventory.csv
│   ├── r_script_inventory.html
│   └── r_script_inventory_quick.csv
└── tools/
    └── inventory/                      # Inventory scripts
        ├── README.md                   # This file
        ├── file_inventory.R
        ├── generate_script_inventory.R
        └── generate_script_inventory.sh
```

## Refactoring Complexity Ratings

The R script inventory includes refactoring complexity analysis:

| Rating | Score | Description | Action |
|--------|-------|-------------|--------|
| **Very Easy** | 1.0-2.5 | Small, well-organized file | No refactoring needed |
| **Easy** | 2.6-5.0 | Good size, minor improvements possible | Optional |
| **Medium** | 5.1-7.0 | Moderate complexity | Consider refactoring |
| **Hard** | 7.1-8.5 | High complexity | Refactoring recommended |
| **Very Hard** | 8.6-10.0 | Very high complexity | Major refactoring needed |

### Scoring Factors

1. **Lines of Code (40% weight)** - Larger files are harder to refactor
2. **Number of Functions (30% weight)** - More functions = more complexity
3. **Function Density (20% weight)** - Average lines per function
4. **File Type (10% weight)** - Main entry points vs helpers

## Usage Examples

### View largest R scripts

```bash
Rscript tools/inventory/generate_script_inventory.R
# Open structure/r_script_inventory.html in browser
# See "Top 10 Largest Scripts" section
```

### Find scripts needing refactoring

```bash
# Generate inventory
Rscript tools/inventory/generate_script_inventory.R

# Filter for Hard/Very Hard ratings
grep -E "Hard|Very Hard" structure/r_script_inventory.csv
```

### Find all test files

```bash
Rscript tools/inventory/file_inventory.R
grep "test" structure/TURAS_FILE_INVENTORY.csv | grep "\.R"
```

### Count files by category

```bash
Rscript tools/inventory/file_inventory.R
cut -d',' -f5 structure/TURAS_FILE_INVENTORY.csv | sort | uniq -c | sort -rn
```

## When to Run

Regenerate inventories:
- After adding new R scripts or modules
- After refactoring efforts (to verify improvements)
- Before release milestones
- As part of code review process
- When onboarding new developers

## Excluded Directories

The following are automatically excluded from analysis:
- `renv/` - R environment (package dependencies)
- `.git/` - Version control
- `.Rproj.user/` - RStudio user files

## Files in This Directory

| File | Description |
|------|-------------|
| `README.md` | This documentation |
| `file_inventory.R` | Full file inventory generator |
| `generate_script_inventory.R` | Detailed R script analyzer |
| `generate_script_inventory.sh` | Quick bash script analyzer |
| `inventory_summary.txt` | Sample output summary |
| `SCRIPT_INVENTORY_README.md` | Legacy documentation (deprecated) |

---

**Last Updated:** 2025-12-22
