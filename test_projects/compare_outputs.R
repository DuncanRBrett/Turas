# ==============================================================================
# COMPARE BASELINE vs MODULAR OUTPUT
# ==============================================================================

library(readxl)

baseline_file <- "~/Documents/Turas_Test_Baseline/baseline_output.xlsx"
comparison_file <- "~/Documents/Turas_Test_Baseline/chunk8_output.xlsx"

cat("================================================================================\n")
cat("COMPARING OUTPUTS: Baseline vs Chunk 8 (Utility Functions)\n")
cat("================================================================================\n\n")

# Get sheet names
baseline_sheets <- excel_sheets(baseline_file)
comparison_sheets <- excel_sheets(comparison_file)

cat("Baseline sheets:", length(baseline_sheets), "\n")
cat("Comparison sheets:", length(comparison_sheets), "\n\n")

# Compare sheet names
if (!identical(baseline_sheets, comparison_sheets)) {
  cat("❌ DIFFERENCE: Sheet names differ\n")
  cat("  Baseline:", paste(baseline_sheets, collapse=", "), "\n")
  cat("  Comparison:", paste(comparison_sheets, collapse=", "), "\n\n")
} else {
  cat("✓ Sheet names match\n\n")
}

# Compare each sheet
all_match <- TRUE
differences <- list()

for (sheet in baseline_sheets) {
  cat("Checking sheet:", sheet, "...\n")

  baseline_data <- tryCatch({
    read_excel(baseline_file, sheet=sheet, col_types="text")
  }, error=function(e) NULL)

  comparison_data <- tryCatch({
    read_excel(comparison_file, sheet=sheet, col_types="text")
  }, error=function(e) NULL)

  if (is.null(baseline_data) || is.null(comparison_data)) {
    cat("  ⚠ Could not read sheet\n")
    next
  }

  # Compare dimensions
  if (!identical(dim(baseline_data), dim(comparison_data))) {
    cat("  ❌ DIFFERENT dimensions\n")
    cat("    Baseline:", nrow(baseline_data), "rows x", ncol(baseline_data), "cols\n")
    cat("    Comparison:", nrow(comparison_data), "rows x", ncol(comparison_data), "cols\n")
    all_match <- FALSE
    differences[[sheet]] <- "Dimension mismatch"
    next
  }

  # Compare column names
  if (!identical(names(baseline_data), names(comparison_data))) {
    cat("  ❌ DIFFERENT column names\n")
    all_match <- FALSE
    differences[[sheet]] <- "Column name mismatch"
    next
  }

  # Compare data content (as text to handle numeric precision)
  if (!identical(baseline_data, comparison_data)) {
    # Find differences
    diff_count <- 0
    for (i in 1:nrow(baseline_data)) {
      for (j in 1:ncol(baseline_data)) {
        b_val <- baseline_data[i, j]
        c_val <- comparison_data[i, j]
        if (!identical(b_val, c_val)) {
          if (diff_count == 0) {
            cat("  ❌ DIFFERENT data content\n")
          }
          if (diff_count < 5) {  # Show first 5 differences
            cat(sprintf("    Row %d, Col %s: '%s' vs '%s'\n",
                       i, names(baseline_data)[j],
                       as.character(b_val), as.character(c_val)))
          }
          diff_count <- diff_count + 1
        }
      }
    }
    if (diff_count > 5) {
      cat(sprintf("    ... and %d more differences\n", diff_count - 5))
    }
    all_match <- FALSE
    differences[[sheet]] <- sprintf("%d cell differences", diff_count)
  } else {
    cat("  ✓ IDENTICAL\n")
  }
}

cat("\n================================================================================\n")
cat("COMPARISON SUMMARY\n")
cat("================================================================================\n\n")

if (all_match && length(differences) == 0) {
  cat("✅ SUCCESS: All sheets are IDENTICAL\n")
  cat("   Baseline and modular outputs match perfectly.\n")
  cat("   Safe to proceed with code deletion.\n\n")
} else {
  cat("❌ DIFFERENCES FOUND\n\n")
  cat("Sheets with differences:\n")
  for (sheet in names(differences)) {
    cat(sprintf("  • %s: %s\n", sheet, differences[[sheet]]))
  }
  cat("\n⚠ DO NOT PROCEED - Investigate differences first\n\n")
}

cat("================================================================================\n")
