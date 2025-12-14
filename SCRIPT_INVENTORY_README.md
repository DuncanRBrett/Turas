# Turas R Script Inventory Tools

## Overview

This directory contains two scripts for generating a comprehensive inventory of all R scripts in the Turas repository. The inventory helps you understand the codebase structure, identify refactoring opportunities, and track code metrics.

## Quick Start

### Option 1: Quick Bash Version (Recommended for basic inventory)

```bash
./generate_script_inventory.sh
```

**Output:** `r_script_inventory_quick.csv`

This generates a CSV file with:
- Script path and location
- Total lines, code lines, comment lines, blank lines
- Number of functions
- Sample function names

### Option 2: Full R Version (Recommended for detailed analysis)

```bash
Rscript generate_script_inventory.R
# or
source("generate_script_inventory.R")
```

**Output:**
- `r_script_inventory.csv` (detailed CSV)
- `r_script_inventory.html` (interactive HTML report)

This generates comprehensive reports with:
- All metrics from the bash version
- Task/purpose extraction from script headers
- Complete function listings
- **Refactoring complexity ratings** (1-10 scale)
- Refactoring recommendations
- Visual HTML dashboard with:
  - Summary statistics
  - Top 10 largest scripts
  - Top 10 most complex scripts
  - Refactoring difficulty distribution
  - Searchable full inventory

## Generated Files

| File | Generator | Description |
|------|-----------|-------------|
| `r_script_inventory_quick.csv` | Bash script | Quick CSV inventory (basic metrics) |
| `r_script_inventory.csv` | R script | Detailed CSV with refactoring analysis |
| `r_script_inventory.html` | R script | Interactive HTML dashboard |

## Inventory Metrics

### Basic Metrics (Both Versions)

- **Script Path**: Full and relative paths
- **Location**: Directory within repository
- **Total Lines**: All lines including blanks
- **Code Lines**: Active code (non-comment, non-blank)
- **Comment Lines**: Lines starting with `#`
- **Blank Lines**: Empty or whitespace-only lines
- **Number of Functions**: Count of function definitions
- **Function Names**: List of all functions in the script

### Advanced Metrics (R Version Only)

- **Task/Purpose**: Extracted from script header comments
- **Refactoring Score**: 1-10 scale rating difficulty of refactoring
- **Refactoring Rating**: Very Easy / Easy / Medium / Hard / Very Hard
- **Refactoring Recommendation**: Specific guidance for each script
- **Complexity Reasons**: Why the score was assigned

## Refactoring Complexity Rating

The R version includes a sophisticated refactoring complexity algorithm that considers:

1. **Lines of Code (40% weight)**
   - < 100 LOC: Very Easy
   - 100-300 LOC: Easy
   - 300-600 LOC: Medium
   - 600-1000 LOC: Hard
   - \> 1000 LOC: Very Hard

2. **Number of Functions (30% weight)**
   - 0-3 functions: Simple
   - 4-10 functions: Moderate
   - 11-20 functions: Complex
   - \> 20 functions: Very Complex

3. **Function Density (20% weight)**
   - Average function size (lines per function)
   - Smaller functions are easier to refactor

4. **File Type (10% weight)**
   - Main entry points (00_main*.R): Orchestrators
   - Helper files (99_*.R): Utilities
   - Test files: Specialized

### Rating Guide

| Rating | Score | Description | Action |
|--------|-------|-------------|--------|
| **Very Easy** | 1.0-2.5 | Small, well-organized file | No refactoring needed |
| **Easy** | 2.6-5.0 | Good size, minor improvements possible | Optional refactoring |
| **Medium** | 5.1-7.0 | Moderate complexity | Consider refactoring |
| **Hard** | 7.1-8.5 | High complexity | Refactoring recommended |
| **Very Hard** | 8.6-10.0 | Very high complexity | Major refactoring needed |

## Current Repository Statistics

Based on the latest inventory:

- **Total Scripts:** 227
- **Total Lines:** 101,370
- **Code Lines:** 85,416
- **Total Functions:** 1,351
- **Average Lines/Script:** 447
- **Average Functions/Script:** 6.0

## Usage Examples

### Generate inventory and view in terminal

```bash
./generate_script_inventory.sh
cat r_script_inventory_quick.csv | column -t -s,
```

### Generate full inventory with HTML report

```bash
Rscript generate_script_inventory.R
# Then open r_script_inventory.html in your browser
```

### Filter for large files

```bash
# Files with > 500 lines of code
tail -n +2 r_script_inventory_quick.csv | awk -F',' '$5 > 500 {print $2, $5}' | sort -t' ' -k2 -rn
```

### Find scripts with many functions

```bash
# Scripts with > 10 functions
tail -n +2 r_script_inventory_quick.csv | awk -F',' '$8 > 10 {print $2, $8}' | sort -t' ' -k2 -rn
```

### Search for specific functions

```bash
# Find scripts containing a specific function
grep -i "calculate_utilities" r_script_inventory_quick.csv
```

## Rerunning the Inventory

Both scripts are designed to be rerun whenever needed:

```bash
# Quick update (bash version) - runs in seconds
./generate_script_inventory.sh

# Full analysis (R version) - may take 1-2 minutes
Rscript generate_script_inventory.R
```

The scripts will overwrite previous reports, so you can run them:
- After adding new R scripts
- After refactoring efforts
- Before release milestones
- As part of code review process

## Excluded Directories

The following directories are automatically excluded:
- `renv/` - R environment management
- `.git/` - Version control
- `.Rproj.user/` - RStudio user files

## Script Locations

| Script | Purpose |
|--------|---------|
| `generate_script_inventory.sh` | Bash version for quick inventory |
| `generate_script_inventory.R` | R version for detailed analysis |
| `SCRIPT_INVENTORY_README.md` | This documentation |

## Troubleshooting

### Bash script not running

```bash
chmod +x generate_script_inventory.sh
./generate_script_inventory.sh
```

### R script fails with "package not found"

The R script has minimal dependencies. If you encounter issues:

```r
# The script should work with base R only
# No additional packages required
Rscript generate_script_inventory.R
```

### No output generated

Check that you're running from the Turas repository root:

```bash
cd /path/to/Turas
./generate_script_inventory.sh
```

## Integration Ideas

### Git Pre-commit Hook

Track inventory in version control:

```bash
#!/bin/bash
# .git/hooks/pre-commit
./generate_script_inventory.sh
git add r_script_inventory_quick.csv
```

### CI/CD Pipeline

Add to your build process:

```yaml
# .github/workflows/inventory.yml
- name: Generate Script Inventory
  run: |
    ./generate_script_inventory.sh
    # Upload as artifact or commit to repo
```

### Monthly Reports

Schedule automatic inventory generation:

```bash
# crontab entry - first day of each month
0 0 1 * * cd /path/to/Turas && Rscript generate_script_inventory.R
```

## Future Enhancements

Potential additions to the inventory tools:

- [ ] Dependency analysis (which scripts source which)
- [ ] Code complexity metrics (cyclomatic complexity)
- [ ] TODO/FIXME comment tracking
- [ ] Test coverage correlation
- [ ] Git blame integration (last modified dates)
- [ ] Function call graphs
- [ ] Duplicate code detection

## Contributing

To improve the inventory tools:

1. Edit `generate_script_inventory.sh` for bash version improvements
2. Edit `generate_script_inventory.R` for R version enhancements
3. Test with: `./generate_script_inventory.sh && Rscript generate_script_inventory.R`
4. Update this README with new features

## Questions?

For issues or feature requests related to the inventory tools:
- Check this README first
- Review the generated CSV/HTML outputs
- Examine the script source code (both are well-commented)

---

**Last Updated:** 2025-12-14
**Version:** 1.0.0
**Maintainer:** Turas Development Team
