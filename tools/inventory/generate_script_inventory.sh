#!/bin/bash
# ==============================================================================
# TURAS R SCRIPT INVENTORY GENERATOR (Bash Version)
# ==============================================================================
# Purpose: Quick bash-based inventory generator (simpler than R version)
# Usage: ./generate_script_inventory.sh
# Output: Creates CSV report in the repository root
# Note: For full featured analysis with HTML report, use generate_script_inventory.R
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT_CSV="${REPO_ROOT}/r_script_inventory_quick.csv"

echo "=============================================================================="
echo "TURAS R SCRIPT INVENTORY GENERATOR (Quick Bash Version)"
echo "=============================================================================="
echo ""

# Create CSV header
echo "Script Path,Filename,Directory,Total Lines,Code Lines,Comment Lines,Blank Lines,Num Functions,Sample Functions" > "$OUTPUT_CSV"

# Find all R scripts
SCRIPT_COUNT=0
echo "Scanning for R scripts..."

find "$REPO_ROOT" -type f -name "*.R" \
  ! -path "*/renv/*" \
  ! -path "*/.git/*" \
  ! -path "*/.Rproj.user/*" | \
  sort | while read -r script_path; do

  SCRIPT_COUNT=$((SCRIPT_COUNT + 1))

  # Get relative path
  rel_path="${script_path#$REPO_ROOT/}"
  filename=$(basename "$script_path")
  directory=$(dirname "$rel_path")

  # Count lines
  total_lines=$(wc -l < "$script_path")
  blank_lines=$(grep -c "^[[:space:]]*$" "$script_path" || echo 0)
  comment_lines=$(grep -c "^[[:space:]]*#" "$script_path" || echo 0)
  code_lines=$((total_lines - blank_lines))

  # Find function definitions
  # Pattern matches: function_name <- function( or function_name = function(
  functions=$(grep -oP "^\\s*\\K[a-zA-Z_][a-zA-Z0-9_\\.]*(?=\\s*(<-|=)\\s*function\\s*\\()" "$script_path" | sort -u | tr '\n' ';' | sed 's/;$//' || echo "")
  num_functions=$(echo "$functions" | grep -o ";" | wc -l)
  if [ -n "$functions" ]; then
    num_functions=$((num_functions + 1))
  else
    num_functions=0
  fi

  # Get first 3 functions for sample
  sample_functions=$(echo "$functions" | cut -d';' -f1-3 | sed 's/;/, /g')
  if [ "$num_functions" -gt 3 ]; then
    sample_functions="${sample_functions}, ..."
  fi

  # Escape quotes for CSV
  rel_path="${rel_path//\"/\"\"}"
  filename="${filename//\"/\"\"}"
  directory="${directory//\"/\"\"}"
  sample_functions="${sample_functions//\"/\"\"}"

  # Write to CSV
  echo "\"$rel_path\",\"$filename\",\"$directory\",$total_lines,$code_lines,$comment_lines,$blank_lines,$num_functions,\"$sample_functions\"" >> "$OUTPUT_CSV"

  # Progress indicator (every 10 files)
  if [ $((SCRIPT_COUNT % 10)) -eq 0 ]; then
    echo "  Processed $SCRIPT_COUNT scripts..." >&2
  fi
done

# Count total scripts processed
TOTAL_SCRIPTS=$(tail -n +2 "$OUTPUT_CSV" | wc -l)

echo ""
echo "=============================================================================="
echo "INVENTORY COMPLETE"
echo "=============================================================================="
echo "Total scripts analyzed: $TOTAL_SCRIPTS"
echo "Output saved to: $OUTPUT_CSV"
echo ""
echo "To view the report:"
echo "  cat $OUTPUT_CSV"
echo "  # or open in Excel/LibreOffice"
echo ""
echo "For a more detailed analysis with refactoring ratings and HTML report:"
echo "  Rscript generate_script_inventory.R"
echo "=============================================================================="
echo ""
