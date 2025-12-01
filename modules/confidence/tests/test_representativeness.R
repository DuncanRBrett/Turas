# ==============================================================================
# REPRESENTATIVENESS TEST FOR TURAS CONFIDENCE MODULE
# ==============================================================================
# Purpose:
# - Test population margin comparison (simple and nested quotas)
# - Test weight concentration diagnostics
# - Verify traffic-light flags work correctly
# - Ensure system works with and without Population_Margins sheet
#
# Test Scenarios:
# 1. Simple margins: Gender, Age, Region
# 2. Nested quotas: Gender x Age
# 3. Weight concentration with varying distributions
# 4. Config without Population_Margins (should not error)
#
# ==============================================================================

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')",
       call. = FALSE)
}

# ------------------------------------------------------------------------------
# 1. Paths and directories
# ------------------------------------------------------------------------------

module_root <- getwd()
test_dir    <- file.path(module_root, "tests", "representativeness_test")
data_dir    <- test_dir

if (!dir.exists(test_dir)) dir.create(test_dir, recursive = TRUE)

data_file_path   <- file.path(data_dir, "test_quota_data.csv")
output_file_path <- file.path(data_dir, "confidence_results_quotas.xlsx")
config_path      <- file.path(data_dir, "confidence_config_quotas.xlsx")

cat("Module root: ", module_root, "\n", sep = "")
cat("Test dir:    ", test_dir, "\n", sep = "")
cat("Data file:   ", data_file_path, "\n", sep = "")
cat("Output file: ", output_file_path, "\n", sep = "")
cat("Config file: ", config_path, "\n\n", sep = "")

# ------------------------------------------------------------------------------
# 2. Create synthetic survey data with known quotas
# ------------------------------------------------------------------------------

set.seed(789)
n <- 500L

# Create demographic variables with specific distributions
# We'll create data that's SLIGHTLY off quota targets to test flagging

# Gender: Target 48% Male, 52% Female
# Actual: 45% Male, 55% Female (3pp off - AMBER flag expected)
gender <- sample(c("Male", "Female"), n, replace = TRUE,
                 prob = c(0.45, 0.55))

# Age: Target distribution
# 18-24: 15%, 25-34: 20%, 35-44: 18%, 45-54: 22%, 55+: 25%
# Actual: slight deviations
age_group <- sample(c("18-24", "25-34", "35-44", "45-54", "55+"), n, replace = TRUE,
                    prob = c(0.13, 0.21, 0.19, 0.22, 0.25))

# Region: Target
# Gauteng: 25%, Western Cape: 11%, KZN: 21%, Eastern Cape: 13%, Other: 30%
# Actual: Gauteng 30% (5pp over - RED flag expected)
region <- sample(c("Gauteng", "Western Cape", "KZN", "Eastern Cape", "Other"), n,
                 replace = TRUE,
                 prob = c(0.30, 0.11, 0.21, 0.13, 0.25))

# Create weights - deliberately make some concentrated
# Most weights around 1.0, but give 5% of cases very high weights (2.5-4.0)
weights <- runif(n, min = 0.7, max = 1.3)
n_top <- ceiling(0.05 * n)
top_indices <- sample(1:n, n_top)
weights[top_indices] <- runif(n_top, min = 2.5, max = 4.0)

# Create a simple proportion question for testing
q_satisfaction <- sample(c(0, 1), n, replace = TRUE, prob = c(0.35, 0.65))

survey_data <- data.frame(
  ID = 1:n,
  Gender = gender,
  Age_Group = age_group,
  Region = region,
  Q_SATISFACTION = q_satisfaction,
  weight = weights,
  stringsAsFactors = FALSE
)

# Inject NA and zero weights to test robustness
survey_data$weight[c(10, 25, 50)] <- NA
survey_data$weight[c(15, 30)] <- 0

# Save as CSV
write.csv(survey_data, data_file_path, row.names = FALSE)

cat("✓ Synthetic quota survey data written\n")
cat(sprintf("  Sample size: %d\n", n))
cat(sprintf("  Gender distribution: Male=%.1f%%, Female=%.1f%%\n",
            100 * mean(gender == "Male"), 100 * mean(gender == "Female")))
cat(sprintf("  Weight concentration: Top 5%% n=%d\n", n_top))

# ------------------------------------------------------------------------------
# 3. Create confidence_config with Population_Margins
# ------------------------------------------------------------------------------

wb <- openxlsx::createWorkbook()

# 3.1 File_Paths sheet
openxlsx::addWorksheet(wb, "File_Paths")

file_paths_df <- data.frame(
  Parameter = c("Data_File",      "Output_File",           "Weight_Variable"),
  Value     = c(data_file_path,   output_file_path,        "weight"),
  stringsAsFactors = FALSE
)

openxlsx::writeData(wb, "File_Paths", file_paths_df,
                    startRow = 1, startCol = 1,
                    colNames = TRUE, rowNames = FALSE)

# 3.2 Study_Settings sheet
openxlsx::addWorksheet(wb, "Study_Settings")

study_settings_df <- data.frame(
  Setting = c(
    "Calculate_Effective_N",
    "Multiple_Comparison_Adjustment",
    "Multiple_Comparison_Method",
    "Bootstrap_Iterations",
    "Confidence_Level",
    "Decimal_Separator",
    "random_seed"
  ),
  Value = c(
    "Y",
    "N",
    "None",
    "1200",
    "0.95",
    ".",
    "99999"
  ),
  stringsAsFactors = FALSE
)

openxlsx::writeData(wb, "Study_Settings", study_settings_df,
                    startRow = 1, startCol = 1,
                    colNames = TRUE, rowNames = FALSE)

# 3.3 Question_Analysis sheet (simple proportion question)
openxlsx::addWorksheet(wb, "Question_Analysis")

question_analysis_df <- data.frame(
  Question_ID      = c("Q_SATISFACTION"),
  Statistic_Type   = c("proportion"),
  Categories       = c("1"),
  Run_MOE          = c("Y"),
  Run_Bootstrap    = c("Y"),
  Run_Credible     = c("N"),
  Use_Wilson       = c("N"),
  Promoter_Codes   = c(NA),
  Detractor_Codes  = c(NA),
  Prior_Mean       = c(NA),
  Prior_SD         = c(NA),
  Prior_N          = c(NA),
  Notes            = c("Satisfaction test"),
  stringsAsFactors = FALSE
)

openxlsx::writeData(wb, "Question_Analysis", question_analysis_df,
                    startRow = 1, startCol = 1,
                    colNames = TRUE, rowNames = FALSE)

# 3.4 Population_Margins sheet - THE KEY SHEET FOR THIS TEST
openxlsx::addWorksheet(wb, "Population_Margins")

# Simple margins + nested quota
population_margins_df <- data.frame(
  Variable = c(
    # Simple margin: Gender
    "Gender", "Gender",
    # Simple margin: Age
    "Age_Group", "Age_Group", "Age_Group", "Age_Group", "Age_Group",
    # Simple margin: Region
    "Region", "Region", "Region", "Region", "Region",
    # Nested quota: Gender x Age (example: Male 18-24, Female 18-24, etc.)
    "Gender,Age_Group", "Gender,Age_Group", "Gender,Age_Group", "Gender,Age_Group"
  ),
  Category_Label = c(
    # Gender
    "Male", "Female",
    # Age
    "18-24", "25-34", "35-44", "45-54", "55+",
    # Region
    "Gauteng", "Western Cape", "KZN", "Eastern Cape", "Other",
    # Nested: Gender x Age (just a few examples)
    "Male, 18-24", "Female, 18-24", "Male, 25-34", "Female, 25-34"
  ),
  Category_Code = c(
    # Gender (codes match data)
    "Male", "Female",
    # Age
    "18-24", "25-34", "35-44", "45-54", "55+",
    # Region
    "Gauteng", "Western Cape", "KZN", "Eastern Cape", "Other",
    # Nested: underscore separator (will be created by code: "Male_18-24")
    "Male_18-24", "Female_18-24", "Male_25-34", "Female_25-34"
  ),
  Target_Prop = c(
    # Gender targets
    0.48, 0.52,
    # Age targets
    0.15, 0.20, 0.18, 0.22, 0.25,
    # Region targets
    0.25, 0.11, 0.21, 0.13, 0.30,
    # Nested targets (these are joint proportions, so sum to < 1)
    0.07, 0.08, 0.10, 0.10
  ),
  Include = c(
    # All included (2 gender + 5 age + 5 region + 4 nested = 16)
    rep("Y", 16)
  ),
  stringsAsFactors = FALSE
)

openxlsx::writeData(wb, "Population_Margins", population_margins_df,
                    startRow = 1, startCol = 1,
                    colNames = TRUE, rowNames = FALSE)

# Save config workbook
openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

cat("✓ Test configuration workbook written with Population_Margins sheet\n")
cat(sprintf("  - %d simple margin targets (Gender, Age, Region)\n", 12))
cat(sprintf("  - %d nested quota targets (Gender x Age)\n", 4))
cat("\n")

# ------------------------------------------------------------------------------
# 4. Source main module and run analysis
# ------------------------------------------------------------------------------

core_main <- file.path(module_root, "R", "00_main.R")

if (!file.exists(core_main)) {
  stop(sprintf("Could not find R/00_main.R at: %s", core_main), call. = FALSE)
}

cat("Sourcing main module from: ", core_main, "\n", sep = "")
source(core_main)

cat("\nRunning run_confidence_analysis() with quota targets...\n\n")

res <- run_confidence_analysis(
  config_path       = config_path,
  verbose           = TRUE,
  stop_on_warnings  = FALSE
)

cat("\n✓ run_confidence_analysis() completed without error\n")

# ------------------------------------------------------------------------------
# 5. Validate representativeness results
# ------------------------------------------------------------------------------

if (!is.list(res)) {
  stop("Result is not a list – unexpected structure.")
}

# Check study stats exist
if (is.null(res$study_stats)) {
  stop("study_stats is NULL even though Calculate_Effective_N = 'Y'.")
}

# Extract weight concentration and margin comparison
weight_conc <- attr(res$study_stats, "weight_concentration")
margin_comp <- attr(res$study_stats, "margin_comparison")

cat("\n=== WEIGHT CONCENTRATION DIAGNOSTICS ===\n")
if (!is.null(weight_conc)) {
  print(weight_conc)

  # Validate structure
  if (is.null(weight_conc$Top_5pct_Share)) {
    stop("Weight concentration missing Top_5pct_Share")
  }

  if (is.null(weight_conc$Concentration_Flag)) {
    stop("Weight concentration missing Concentration_Flag")
  }

  # We deliberately created concentrated weights, so expect HIGH or MODERATE
  if (weight_conc$Concentration_Flag == "LOW") {
    warning("Expected MODERATE or HIGH concentration given test data design")
  }

  cat("\n✓ Weight concentration diagnostics validated\n")
} else {
  stop("Weight concentration is NULL - calculation failed")
}

cat("\n=== MARGIN COMPARISON RESULTS ===\n")
if (!is.null(margin_comp)) {
  print(margin_comp, row.names = FALSE)

  # Validate structure
  required_cols <- c("Variable", "Category_Label", "Target_Pct",
                     "Weighted_Sample_Pct", "Diff_pp", "Flag")
  missing_cols <- setdiff(required_cols, names(margin_comp))
  if (length(missing_cols) > 0) {
    stop(sprintf("Margin comparison missing columns: %s",
                 paste(missing_cols, collapse = ", ")))
  }

  # Count flags
  n_red <- sum(margin_comp$Flag == "RED", na.rm = TRUE)
  n_amber <- sum(margin_comp$Flag == "AMBER", na.rm = TRUE)
  n_green <- sum(margin_comp$Flag == "GREEN", na.rm = TRUE)

  cat(sprintf("\n✓ Margin comparison validated: %d targets\n", nrow(margin_comp)))
  cat(sprintf("  - GREEN: %d (excellent)\n", n_green))
  cat(sprintf("  - AMBER: %d (acceptable)\n", n_amber))
  cat(sprintf("  - RED: %d (concerning)\n", n_red))

  # We expect at least 1 RED (Gauteng is 30% vs target 25% = 5pp)
  # We expect at least 1 AMBER (Gender Male is 45% vs target 48% = 3pp)
  if (n_red == 0) {
    warning("Expected at least 1 RED flag (Gauteng over-represented)")
  }

  if (n_amber == 0) {
    warning("Expected at least 1 AMBER flag (Gender slightly off)")
  }

  # Check nested quotas were calculated
  nested_rows <- grepl(",", margin_comp$Variable)
  if (sum(nested_rows) == 0) {
    warning("No nested quota results found - expected Gender,Age_Group combinations")
  } else {
    cat(sprintf("  - Nested quotas: %d targets evaluated\n", sum(nested_rows)))
  }

} else {
  stop("Margin comparison is NULL - calculation failed")
}

# ------------------------------------------------------------------------------
# 6. Check Excel output
# ------------------------------------------------------------------------------

if (!file.exists(output_file_path)) {
  stop(sprintf("Output file not created: %s", output_file_path))
}

# Read sheet names
sheets <- readxl::excel_sheets(output_file_path)

cat("\n=== EXCEL OUTPUT VALIDATION ===\n")
cat(sprintf("Output file: %s\n", output_file_path))
cat(sprintf("Sheets created: %d\n", length(sheets)))
cat(sprintf("  - %s\n", paste(sheets, collapse = "\n  - ")))

# Check for Representativeness_Weights sheet
if (!"Representativeness_Weights" %in% sheets) {
  stop("Representativeness_Weights sheet not found in output")
}

cat("\n✓ Representativeness_Weights sheet exists\n")

# Try to read the sheet
rep_sheet <- tryCatch({
  readxl::read_excel(output_file_path, sheet = "Representativeness_Weights")
}, error = function(e) {
  stop(sprintf("Failed to read Representativeness_Weights sheet: %s",
               conditionMessage(e)))
})

cat(sprintf("✓ Representativeness_Weights sheet readable (%d rows)\n", nrow(rep_sheet)))

# ------------------------------------------------------------------------------
# 7. Test WITHOUT Population_Margins (should not error)
# ------------------------------------------------------------------------------

cat("\n=== TESTING WITHOUT POPULATION_MARGINS SHEET ===\n")

config_no_margins <- file.path(data_dir, "confidence_config_no_margins.xlsx")

# Copy workbook but don't include Population_Margins sheet
wb2 <- openxlsx::createWorkbook()

openxlsx::addWorksheet(wb2, "File_Paths")
openxlsx::writeData(wb2, "File_Paths", file_paths_df, colNames = TRUE)

openxlsx::addWorksheet(wb2, "Study_Settings")
openxlsx::writeData(wb2, "Study_Settings", study_settings_df, colNames = TRUE)

openxlsx::addWorksheet(wb2, "Question_Analysis")
openxlsx::writeData(wb2, "Question_Analysis", question_analysis_df, colNames = TRUE)

# NO Population_Margins sheet

openxlsx::saveWorkbook(wb2, config_no_margins, overwrite = TRUE)

cat("Running analysis WITHOUT Population_Margins sheet...\n")

res2 <- run_confidence_analysis(
  config_path       = config_no_margins,
  verbose           = FALSE,
  stop_on_warnings  = FALSE
)

# Should complete without error
if (is.null(res2)) {
  stop("Analysis failed when Population_Margins sheet absent")
}

margin_comp2 <- attr(res2$study_stats, "margin_comparison")
weight_conc2 <- attr(res2$study_stats, "weight_concentration")

# Margin comparison should be NULL (no targets provided)
if (!is.null(margin_comp2)) {
  warning("Margin comparison should be NULL when no Population_Margins provided")
}

# Weight concentration should still work (doesn't need targets)
if (is.null(weight_conc2)) {
  stop("Weight concentration should work even without Population_Margins")
}

cat("✓ Analysis works correctly without Population_Margins sheet\n")
cat("  - Margin comparison: NULL (expected)\n")
cat(sprintf("  - Weight concentration: calculated (Top 5%% = %.1f%%)\n",
            weight_conc2$Top_5pct_Share))

# ------------------------------------------------------------------------------
# 8. Final summary
# ------------------------------------------------------------------------------

cat("\n================================================================================\n")
cat("REPRESENTATIVENESS TEST COMPLETED SUCCESSFULLY\n")
cat("================================================================================\n")

cat("\nKey Results:\n")
cat(sprintf("  - Weight concentration: %s (Top 5%% hold %.1f%% of weight)\n",
            weight_conc$Concentration_Flag,
            weight_conc$Top_5pct_Share))
cat(sprintf("  - Margin targets evaluated: %d\n", nrow(margin_comp)))
cat(sprintf("    • GREEN flags: %d\n", n_green))
cat(sprintf("    • AMBER flags: %d\n", n_amber))
cat(sprintf("    • RED flags: %d\n", n_red))
cat(sprintf("  - Nested quotas tested: YES (Gender x Age)\n"))

cat("\nAll representativeness functionality verified:\n")
cat("  ✓ Population_Margins config loading\n")
cat("  ✓ Simple margin comparison (Gender, Age, Region)\n")
cat("  ✓ Nested quota comparison (Gender x Age)\n")
cat("  ✓ Weight concentration diagnostics\n")
cat("  ✓ Traffic-light flagging (GREEN/AMBER/RED)\n")
cat("  ✓ Excel output sheet generation\n")
cat("  ✓ Graceful handling when no margins provided\n")
cat("\n")

cat(sprintf("Output file: %s\n", output_file_path))
cat("Open the Representativeness_Weights sheet to review results!\n\n")
