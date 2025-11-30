#!/usr/bin/env Rscript
# ==============================================================================
# DIAGNOSTIC SCRIPT: Compare Data Columns vs Survey Structure
# ==============================================================================
#
# PURPOSE: Diagnose column name mismatches between data file and survey structure
#
# USAGE:
#   Rscript diagnose_columns.R <project_directory>
#
# EXAMPLE:
#   Rscript diagnose_columns.R "~/OneDrive/DB Files/Projects/CCPB/CCPB_CSAT/03_Waves/CSAT2025"
#
# ==============================================================================

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  cat("\nUsage: Rscript diagnose_columns.R <project_directory>\n\n")
  cat("Example:\n")
  cat('  Rscript diagnose_columns.R "~/OneDrive/DB Files/Projects/CCPB/CCPB_CSAT/03_Waves/CSAT2025"\n\n')
  quit(status = 1)
}

project_dir <- args[1]

# Expand tilde if present
project_dir <- path.expand(project_dir)

if (!dir.exists(project_dir)) {
  cat(sprintf("\nError: Directory not found: %s\n\n", project_dir))
  quit(status = 1)
}

cat("\n")
cat(strrep("=", 80), "\n")
cat("COLUMN DIAGNOSTIC TOOL\n")
cat(strrep("=", 80), "\n\n")

cat("Project directory:", project_dir, "\n\n")

# Set working directory
setwd(project_dir)

# Load required libraries
suppressPackageStartupMessages({
  library(readxl)
})

# ==============================================================================
# Step 1: Find configuration and data files
# ==============================================================================

cat("Step 1: Locating files...\n")

# Find config file
config_files <- list.files(pattern = "*Crosstab_Config\\.xlsx$", full.names = FALSE)
if (length(config_files) == 0) {
  cat("  ✗ No Crosstab_Config.xlsx file found\n")
  quit(status = 1)
}
config_file <- config_files[1]
cat(sprintf("  ✓ Config: %s\n", config_file))

# Find survey structure file
structure_files <- list.files(pattern = "*Survey_Structure\\.xlsx$", full.names = FALSE)
if (length(structure_files) == 0) {
  cat("  ✗ No Survey_Structure.xlsx file found\n")
  quit(status = 1)
}
structure_file <- structure_files[1]
cat(sprintf("  ✓ Structure: %s\n", structure_file))

# Find data file
data_files <- list.files(pattern = "*Data\\.xlsx$", full.names = FALSE)
if (length(data_files) == 0) {
  cat("  ✗ No *Data.xlsx file found\n")
  quit(status = 1)
}
data_file <- data_files[1]
cat(sprintf("  ✓ Data: %s\n", data_file))

# ==============================================================================
# Step 2: Load Survey Structure
# ==============================================================================

cat("\nStep 2: Loading survey structure...\n")

questions_df <- read_excel(structure_file, sheet = "Questions", col_types = "text")
cat(sprintf("  ✓ Loaded %d questions\n", nrow(questions_df)))

# Get expected column names
expected_questions <- questions_df$QuestionCode
cat(sprintf("  ✓ Expected %d question columns\n", length(expected_questions)))

# ==============================================================================
# Step 3: Load Data File
# ==============================================================================

cat("\nStep 3: Loading data file...\n")

survey_data <- read_excel(data_file, sheet = 1, col_types = "text", n_max = 5)
actual_columns <- names(survey_data)
cat(sprintf("  ✓ Found %d columns in data\n", length(actual_columns)))

# ==============================================================================
# Step 4: Compare Columns
# ==============================================================================

cat("\nStep 4: Comparing columns...\n\n")

# Find missing columns
missing_cols <- setdiff(expected_questions, actual_columns)

# Find extra columns (in data but not in structure)
extra_cols <- setdiff(actual_columns, expected_questions)

# Find matching columns
matching_cols <- intersect(expected_questions, actual_columns)

cat(sprintf("  Matching columns: %d / %d (%.1f%%)\n",
            length(matching_cols),
            length(expected_questions),
            100 * length(matching_cols) / length(expected_questions)))
cat(sprintf("  Missing columns:  %d\n", length(missing_cols)))
cat(sprintf("  Extra columns:    %d\n", length(extra_cols)))

# ==============================================================================
# Step 5: Check for Column Name Patterns
# ==============================================================================

cat("\nStep 5: Analyzing column name patterns...\n\n")

# Check for common naming pattern differences
cat("Data column sample (first 20):\n")
for (i in 1:min(20, length(actual_columns))) {
  cat(sprintf("  %2d. %s\n", i, actual_columns[i]))
}

cat("\nExpected question codes sample (first 20):\n")
for (i in 1:min(20, length(expected_questions))) {
  cat(sprintf("  %2d. %s\n", i, expected_questions[i]))
}

# ==============================================================================
# Step 6: Check Composite Metrics
# ==============================================================================

cat("\nStep 6: Checking composite metrics...\n")

# Check if Composite_Metrics sheet exists
sheets <- excel_sheets(structure_file)

if ("Composite_Metrics" %in% sheets) {
  composites_df <- read_excel(structure_file, sheet = "Composite_Metrics", col_types = "text")

  cat(sprintf("  ✓ Found %d composite metric(s)\n\n", nrow(composites_df)))

  for (i in 1:nrow(composites_df)) {
    comp_code <- composites_df$CompositeCode[i]
    source_questions <- strsplit(composites_df$SourceQuestions[i], ",")[[1]]
    source_questions <- trimws(source_questions)

    missing_sources <- setdiff(source_questions, actual_columns)

    cat(sprintf("  Composite: %s\n", comp_code))
    cat(sprintf("    Source questions: %s\n", paste(source_questions, collapse = ", ")))

    if (length(missing_sources) > 0) {
      cat(sprintf("    ✗ MISSING in data: %s\n", paste(missing_sources, collapse = ", ")))
    } else {
      cat("    ✓ All sources found\n")
    }
    cat("\n")
  }
} else {
  cat("  No Composite_Metrics sheet found\n")
}

# ==============================================================================
# Step 7: Recommendations
# ==============================================================================

cat("\n")
cat(strrep("=", 80), "\n")
cat("RECOMMENDATIONS\n")
cat(strrep("=", 80), "\n\n")

if (length(missing_cols) > 50) {
  cat("CRITICAL: Many columns are missing (", length(missing_cols), " / ", length(expected_questions), ")\n\n", sep = "")
  cat("Possible causes:\n")
  cat("  1. Using wrong data file (old export, different survey wave)\n")
  cat("  2. Data file has different column naming convention\n")
  cat("  3. Survey_Structure file is for a different survey\n\n")
  cat("Next steps:\n")
  cat("  1. Verify you're using the correct data file for this survey wave\n")
  cat("  2. Check if data columns have a different prefix/suffix\n")
  cat("  3. Ensure Survey_Structure.xlsx matches your data export\n\n")
} else if (length(missing_cols) > 0) {
  cat("Some columns are missing (", length(missing_cols), " / ", length(expected_questions), ")\n\n", sep = "")
  cat("Missing columns:\n")
  for (col in missing_cols[1:min(10, length(missing_cols))]) {
    cat(sprintf("  - %s\n", col))
  }
  if (length(missing_cols) > 10) {
    cat(sprintf("  ... and %d more\n", length(missing_cols) - 10))
  }
  cat("\n")
} else {
  cat("✓ All expected columns are present in the data!\n\n")
}

cat(strrep("=", 80), "\n\n")
