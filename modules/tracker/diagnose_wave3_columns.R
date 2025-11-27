# ==============================================================================
# Wave3 Column Diagnostics Script
# ==============================================================================
#
# This script reads your Wave3 data file and shows what columns actually exist,
# so you can update the question mapping to match the real column names.
#
# ==============================================================================

cat("================================================================================\n")
cat("WAVE3 COLUMN DIAGNOSTICS\n")
cat("================================================================================\n\n")

library(openxlsx)

# Path to Wave3 data file
wave3_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/03_Waves/SACS-2025/03_Data/SACS-2025_data.xlsx"

if (!file.exists(wave3_path)) {
  stop("Wave3 data file not found at: ", wave3_path)
}

cat("Reading Wave3 data file...\n")
wave3_data <- read.xlsx(wave3_path, sheet = 1, check.names = FALSE)

cat("✓ Successfully loaded Wave3 data\n")
cat("  Records:", nrow(wave3_data), "\n")
cat("  Columns:", ncol(wave3_data), "\n\n")

# Show all column names
cat("All columns in Wave3 data:\n")
cat("================================================================================\n")
for (i in seq_along(names(wave3_data))) {
  cat(sprintf("%3d. %s\n", i, names(wave3_data)[i]))
}

cat("\n================================================================================\n")

# Show columns that look like question codes (start with Q followed by digits)
q_cols <- grep("^Q[0-9]+", names(wave3_data), value = TRUE)
cat("\nColumns that look like question codes (Q##):\n")
cat("================================================================================\n")
if (length(q_cols) > 0) {
  for (col in q_cols) {
    cat("  ", col, "\n")
  }
} else {
  cat("  None found\n")
}

cat("\n================================================================================\n")

# Compare with expected mapping
cat("\nExpected columns from question mapping (for composite COMP_engage):\n")
cat("================================================================================\n")
expected_cols <- c("Q05", "Q06", "Q07", "Q08", "Q09", "Q10", "Q11", "Q12", "Q13", "Q14", "Q15", "Q16")
for (col in expected_cols) {
  found <- col %in% names(wave3_data)
  status <- if (found) "✓ FOUND" else "✗ MISSING"
  cat(sprintf("  %-10s %s\n", col, status))
}

cat("\n================================================================================\n")
cat("NEXT STEPS:\n")
cat("================================================================================\n")
cat("\n1. Review the actual column names shown above\n")
cat("2. Update your question mapping Excel file (SACS_question_mapping.xlsx)\n")
cat("3. In the 'Wave3' column, change the question codes to match the actual\n")
cat("   column names from your Wave3 data\n")
cat("4. If Wave3 uses different question codes (e.g., Q01 instead of Q05),\n")
cat("   update the mapping accordingly\n\n")
