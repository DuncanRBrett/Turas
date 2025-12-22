# Turas Project Structure

This directory contains generated inventory and structure reports for the Turas project.

## Generated Files

| File | Generator | Description |
|------|-----------|-------------|
| `TURAS_FILE_INVENTORY.csv` | `file_inventory.R` | Complete file inventory with quality assessments |
| `r_script_inventory.csv` | `generate_script_inventory.R` | R script analysis with refactoring scores |
| `r_script_inventory.html` | `generate_script_inventory.R` | Interactive HTML report |
| `r_script_inventory_quick.csv` | `generate_script_inventory.sh` | Quick R script inventory |

## Regenerating Reports

All inventory scripts are located in `tools/inventory/`:

```bash
# Full file inventory (all file types)
Rscript tools/inventory/file_inventory.R

# R script inventory with refactoring analysis (detailed)
Rscript tools/inventory/generate_script_inventory.R

# Quick R script inventory (bash version)
./tools/inventory/generate_script_inventory.sh
```

## Notes

- These files are auto-generated and can be regenerated at any time
- Do not manually edit these files
- Run inventory scripts after major code changes to keep reports current

---
*Generated reports are stored here to keep the repository root clean.*
