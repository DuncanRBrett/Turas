# ============================================================================
# SEGMENTATION MODULE - REAL DATA TESTING SCRIPT
# ============================================================================
# Quick testing script for real survey data
# Follow prompts to test the segmentation module
# ============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("SEGMENTATION MODULE - REAL DATA TESTING\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

# ----------------------------------------------------------------------------
# STEP 1: Data File Location
# ----------------------------------------------------------------------------

cat("STEP 1: Locate Your Data File\n")
cat(rep("-", 80), "\n", sep = "")
cat("\n")

# UPDATE THIS with your actual data file path
YOUR_DATA_FILE <- "path/to/your/survey.csv"  # <<< CHANGE THIS

if (!file.exists(YOUR_DATA_FILE)) {
  cat("❌ ERROR: Data file not found!\n")
  cat(sprintf("   Looking for: %s\n", YOUR_DATA_FILE))
  cat("\n")
  cat("ACTION REQUIRED:\n")
  cat("  1. Edit this script (test_segmentation_real_data.R)\n")
  cat("  2. Update YOUR_DATA_FILE with correct path\n")
  cat("  3. Run again\n")
  stop("Data file not found", call. = FALSE)
}

cat(sprintf("✓ Found data file: %s\n", basename(YOUR_DATA_FILE)))

# ----------------------------------------------------------------------------
# STEP 2: Inspect Data
# ----------------------------------------------------------------------------

cat("\n")
cat("STEP 2: Inspecting Data\n")
cat(rep("-", 80), "\n", sep = "")
cat("\n")

# Load data
if (grepl("\\.csv$", YOUR_DATA_FILE, ignore.case = TRUE)) {
  data <- read.csv(YOUR_DATA_FILE)
} else if (grepl("\\.(xlsx|xls)$", YOUR_DATA_FILE, ignore.case = TRUE)) {
  library(readxl)
  data <- as.data.frame(read_excel(YOUR_DATA_FILE))
} else {
  stop("Data file must be CSV or Excel (.xlsx, .xls)", call. = FALSE)
}

cat(sprintf("✓ Loaded %d respondents with %d variables\n", nrow(data), ncol(data)))
cat("\n")

cat("Column names:\n")
print(names(data))

cat("\n")
cat("Sample data (first 3 rows):\n")
print(head(data, 3))

cat("\n")
cat("Missing data summary:\n")
missing_summary <- colSums(is.na(data))
print(missing_summary[missing_summary > 0])

# ----------------------------------------------------------------------------
# STEP 3: Configure Variables
# ----------------------------------------------------------------------------

cat("\n")
cat("STEP 3: Variable Configuration\n")
cat(rep("-", 80), "\n", sep = "")
cat("\n")

cat("You need to specify:\n")
cat("  1. ID variable (respondent identifier)\n")
cat("  2. Clustering variables (5-15 numeric variables)\n")
cat("\n")

# UPDATE THESE with your actual variable names
YOUR_ID_VARIABLE <- "respondent_id"  # <<< CHANGE THIS
YOUR_CLUSTERING_VARS <- c("q1", "q2", "q3", "q4", "q5")  # <<< CHANGE THIS

cat("Current configuration:\n")
cat(sprintf("  ID variable: %s\n", YOUR_ID_VARIABLE))
cat(sprintf("  Clustering variables: %s\n", paste(YOUR_CLUSTERING_VARS, collapse = ", ")))
cat("\n")

# Validate configuration
if (!YOUR_ID_VARIABLE %in% names(data)) {
  cat(sprintf("❌ ERROR: ID variable '%s' not found in data\n", YOUR_ID_VARIABLE))
  cat("   Available columns:", paste(names(data), collapse = ", "), "\n")
  stop("Invalid ID variable", call. = FALSE)
}

missing_vars <- setdiff(YOUR_CLUSTERING_VARS, names(data))
if (length(missing_vars) > 0) {
  cat("❌ ERROR: Clustering variables not found:", paste(missing_vars, collapse = ", "), "\n")
  cat("   Available columns:", paste(names(data), collapse = ", "), "\n")
  stop("Invalid clustering variables", call. = FALSE)
}

cat("✓ Configuration valid\n")

# ----------------------------------------------------------------------------
# STEP 4: Validate Data Quality
# ----------------------------------------------------------------------------

cat("\n")
cat("STEP 4: Data Quality Validation\n")
cat(rep("-", 80), "\n", sep = "")
cat("\n")

source("modules/segment/lib/segment_utils.R")

validation <- validate_input_data(
  data = data,
  id_variable = YOUR_ID_VARIABLE,
  clustering_vars = YOUR_CLUSTERING_VARS
)

if (validation$valid) {
  cat("\n✅ DATA VALIDATION PASSED - Ready to run segmentation!\n")
} else {
  cat("\n⚠ DATA VALIDATION ISSUES FOUND:\n")
  for (issue in validation$issues) {
    cat(sprintf("  - %s\n", issue))
  }
  cat("\nYou can still proceed, but review issues above.\n")
}

# ----------------------------------------------------------------------------
# STEP 5: Generate Configuration File
# ----------------------------------------------------------------------------

cat("\n")
cat("STEP 5: Generate Configuration File\n")
cat(rep("-", 80), "\n", sep = "")
cat("\n")

config_output <- "config/test_real_segmentation.xlsx"

# Create config directory if needed
if (!dir.exists("config")) {
  dir.create("config", recursive = TRUE)
}

generate_config_template(
  data_file = YOUR_DATA_FILE,
  output_file = config_output,
  mode = "exploration"
)

cat("\n")
cat("✓ Configuration template created!\n")
cat(sprintf("  Location: %s\n", config_output))

# ----------------------------------------------------------------------------
# STEP 6: Run Segmentation
# ----------------------------------------------------------------------------

cat("\n")
cat("STEP 6: Run Segmentation\n")
cat(rep("-", 80), "\n", sep = "")
cat("\n")

cat("⚠ BEFORE RUNNING:\n")
cat("  1. Open", config_output, "\n")
cat("  2. Update these fields:\n")
cat("       - id_variable:", YOUR_ID_VARIABLE, "\n")
cat("       - clustering_vars:", paste(YOUR_CLUSTERING_VARS, collapse = ","), "\n")
cat("  3. Review other settings (defaults usually good)\n")
cat("  4. Save and close Excel\n")
cat("\n")

cat("Ready to run? (y/n): ")
response <- readline()

if (tolower(trimws(response)) == "y") {
  cat("\n")
  cat("Running segmentation...\n")
  cat("\n")

  source("modules/segment/run_segment.R")

  result <- turas_segment_from_config(config_output)

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("SEGMENTATION COMPLETE!\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")
  cat("Results saved to:", result$output_folder, "\n")
  cat("\n")
  cat("Output files:\n")
  output_files <- list.files(result$output_folder, full.names = FALSE)
  for (file in output_files) {
    cat(sprintf("  - %s\n", file))
  }
  cat("\n")
  cat("Next steps:\n")
  cat("  1. Open seg_exploration_report.xlsx\n")
  cat("  2. Review Metrics_Comparison sheet\n")
  cat("  3. Choose optimal k (highest silhouette)\n")
  cat("  4. Review segment profiles\n")
  cat("  5. Check visualizations (PNG files)\n")

} else {
  cat("\n")
  cat("Segmentation not run.\n")
  cat("Update the config file and run manually:\n")
  cat("  source('modules/segment/run_segment.R')\n")
  cat("  result <- turas_segment_from_config('", config_output, "')\n", sep = "")
}

cat("\n")
cat("For detailed testing checklist, see:\n")
cat("  modules/segment/TESTING_CHECKLIST.md\n")
cat("\n")
