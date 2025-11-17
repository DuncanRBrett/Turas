# ==============================================================================
# HELDERBERG VILLAGE SEGMENTATION TEST
# ==============================================================================
# Testing script for HV Cluster data
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("HELDERBERG VILLAGE - SEGMENTATION TEST\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

# ------------------------------------------------------------------------------
# STEP 1: Load and Inspect Data
# ------------------------------------------------------------------------------

cat("STEP 1: Loading and Inspecting Data\n")
cat(rep("-", 80), "\n", sep = "")
cat("\n")

# Data file path
data_file <- "HV Cluster data.xlsx"

if (!file.exists(data_file)) {
  cat("❌ ERROR: Data file not found!\n")
  cat(sprintf("   Looking for: %s\n", data_file))
  cat(sprintf("   Current directory: %s\n", getwd()))
  cat("\n")
  cat("ACTION: Make sure you're running this from the Turas directory\n")
  cat("        where 'HV Cluster data.xlsx' is located.\n")
  stop("Data file not found", call. = FALSE)
}

cat(sprintf("✓ Found data file: %s\n", data_file))
cat("\n")

# Load data
library(readxl)
data <- as.data.frame(read_excel(data_file))

cat(sprintf("✓ Loaded %d respondents with %d variables\n", nrow(data), ncol(data)))
cat("\n")

# Show structure
cat("Column names and types:\n")
cat(rep("-", 80), "\n", sep = "")
str(data)
cat("\n")

cat("First few rows:\n")
cat(rep("-", 80), "\n", sep = "")
print(head(data, 5))
cat("\n")

# Check for missing data
cat("Missing data summary:\n")
cat(rep("-", 80), "\n", sep = "")
missing_summary <- colSums(is.na(data))
if (any(missing_summary > 0)) {
  print(missing_summary[missing_summary > 0])
} else {
  cat("No missing data detected\n")
}
cat("\n")

# Identify numeric columns (potential clustering variables)
numeric_cols <- names(data)[sapply(data, is.numeric)]
cat("Numeric columns (potential clustering variables):\n")
cat(paste(numeric_cols, collapse = ", "), "\n")
cat("\n")

# ------------------------------------------------------------------------------
# STEP 2: Configure Variables
# ------------------------------------------------------------------------------

cat("\n")
cat("STEP 2: Configure Segmentation Variables\n")
cat(rep("-", 80), "\n", sep = "")
cat("\n")

cat("IMPORTANT: You need to specify:\n")
cat("  1. ID variable - column that uniquely identifies each respondent\n")
cat("  2. Clustering variables - 5-15 numeric variables for segmentation\n")
cat("\n")

cat("Looking at your data columns:\n")
print(names(data))
cat("\n")

# Try to auto-detect ID variable (common names)
possible_id_vars <- c("id", "respondent_id", "participant_id", "ID", "RespondentID")
id_var <- NULL
for (var in possible_id_vars) {
  if (var %in% names(data)) {
    id_var <- var
    break
  }
}

if (is.null(id_var)) {
  # Use first column if no standard ID found
  id_var <- names(data)[1]
  cat(sprintf("⚠ No standard ID variable found. Assuming first column: '%s'\n", id_var))
} else {
  cat(sprintf("✓ Detected ID variable: '%s'\n", id_var))
}
cat("\n")

# Suggest clustering variables (numeric columns, excluding ID)
clustering_candidates <- setdiff(numeric_cols, id_var)
cat("Suggested clustering variables (all numeric columns):\n")
cat(paste(clustering_candidates, collapse = ", "), "\n")
cat("\n")

cat("CONFIGURATION NEEDED:\n")
cat("  Please review and modify the following in this script:\n")
cat("  - Line ~160: Set YOUR_ID_VARIABLE\n")
cat("  - Line ~161: Set YOUR_CLUSTERING_VARS (5-15 variables)\n")
cat("\n")

# ==============================================================================
# CONFIGURATION SECTION - EDIT THESE LINES
# ==============================================================================

# Set your ID variable (respondent identifier)
YOUR_ID_VARIABLE <- id_var  # CHANGE THIS if needed

# Set your clustering variables (5-15 numeric variables)
# Example: c("satisfaction", "quality", "value", "service", "loyalty")
YOUR_CLUSTERING_VARS <- clustering_candidates[1:min(10, length(clustering_candidates))]  # CHANGE THIS

cat("\n")
cat("Current configuration:\n")
cat(sprintf("  ID variable: %s\n", YOUR_ID_VARIABLE))
cat(sprintf("  Clustering variables: %s\n", paste(YOUR_CLUSTERING_VARS, collapse = ", ")))
cat("\n")

# Prompt user to continue or modify
cat("Is this configuration correct? (y/n): ")
response <- readline()

if (tolower(trimws(response)) != "y") {
  cat("\nPlease edit this script (test_HV_segmentation.R) and modify:\n")
  cat("  - YOUR_ID_VARIABLE\n")
  cat("  - YOUR_CLUSTERING_VARS\n")
  cat("\nThen run the script again.\n")
  stop("Configuration needs modification", call. = FALSE)
}

# ------------------------------------------------------------------------------
# STEP 3: Validate Data Quality
# ------------------------------------------------------------------------------

cat("\n")
cat("STEP 3: Data Quality Validation\n")
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

# ------------------------------------------------------------------------------
# STEP 4: Generate Configuration File
# ------------------------------------------------------------------------------

cat("\n")
cat("STEP 4: Generate Configuration File\n")
cat(rep("-", 80), "\n", sep = "")
cat("\n")

# Create config directory if needed
if (!dir.exists("config")) {
  dir.create("config", recursive = TRUE)
}

config_output <- "config/HV_segmentation_config.xlsx"

# Generate configuration template
source("modules/segment/lib/segment_utils.R")

generate_config_template(
  data_file = data_file,
  output_file = config_output,
  mode = "exploration"
)

cat("\n")
cat("✓ Configuration template created!\n")
cat(sprintf("  Location: %s\n", config_output))
cat("\n")

# ------------------------------------------------------------------------------
# STEP 5: Run Segmentation
# ------------------------------------------------------------------------------

cat("\n")
cat("STEP 5: Run Segmentation Analysis\n")
cat(rep("-", 80), "\n", sep = "")
cat("\n")

cat("Ready to run segmentation? (y/n): ")
response <- readline()

if (tolower(trimws(response)) == "y") {
  cat("\n")
  cat("Running segmentation (exploration mode)...\n")
  cat("This will test k=3 to k=6 clusters\n")
  cat("\n")

  source("modules/segment/run_segment.R")

  result <- turas_segment_from_config(config_output)

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("SEGMENTATION TEST COMPLETE!\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  if (!is.null(result$output_files$report)) {
    cat("✅ Analysis completed successfully!\n")
    cat("\n")
    cat("Output files:\n")
    cat(sprintf("  - Exploration report: %s\n", result$output_files$report))
    cat("\n")
    cat("Next steps:\n")
    cat("  1. Open the exploration report Excel file\n")
    cat("  2. Review the Metrics_Comparison sheet\n")
    cat("  3. Choose optimal k based on silhouette scores\n")
    cat("  4. Review segment profiles for each k\n")
    cat("\n")
  }

} else {
  cat("\n")
  cat("Segmentation not run.\n")
  cat("To run manually:\n")
  cat("  source('modules/segment/run_segment.R')\n")
  cat("  result <- turas_segment_from_config('", config_output, "')\n", sep = "")
}

cat("\n")
cat("For detailed testing checklist, see:\n")
cat("  modules/segment/TESTING_CHECKLIST.md\n")
cat("\n")
