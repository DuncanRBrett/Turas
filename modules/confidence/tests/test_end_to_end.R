# ==============================================================================
# END-TO-END TEST FOR TURAS CONFIDENCE MODULE
# ==============================================================================
# Purpose:
# - Create a tiny synthetic dataset with:
#   * 1 proportion question (Q_BIN)
#   * 1 mean question (Q_MEAN)
#   * weight variable with NA and zero values
# - Create a minimal confidence_config.xlsx that points to this data
# - Run run_confidence_analysis() and verify that:
#     * it completes without error
#     * both questions appear in the results
#     * no weight/value alignment errors occur
#
# Assumptions:
# - Working directory is the module root (where 'R' and 'tests' live).
# - Packages 'openxlsx' and 'readxl' are available.
# - R/00_main.R contains the patched process_* functions.
# ==============================================================================

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')",
       call. = FALSE)
}

# ------------------------------------------------------------------------------
# 1. Paths and directories
# ------------------------------------------------------------------------------

module_root <- getwd()
test_dir    <- file.path(module_root, "tests", "end_to_end_test")
data_dir    <- test_dir  # keep everything together

if (!dir.exists(test_dir)) dir.create(test_dir, recursive = TRUE)

data_file_path   <- file.path(data_dir, "test_survey_data.csv")
output_file_path <- file.path(data_dir, "confidence_results_end_to_end.xlsx")
config_path      <- file.path(data_dir, "confidence_config_end_to_end.xlsx")

cat("Module root: ", module_root, "\n", sep = "")
cat("Test dir:    ", test_dir, "\n", sep = "")
cat("Data file:   ", data_file_path, "\n", sep = "")
cat("Output file: ", output_file_path, "\n", sep = "")
cat("Config file: ", config_path, "\n\n", sep = "")

# ------------------------------------------------------------------------------
# 2. Create synthetic survey data
# ------------------------------------------------------------------------------

set.seed(123)
n <- 50L

survey_data <- data.frame(
  ID     = 1:n,
  Q_BIN  = sample(c(0, 1), n, replace = TRUE, prob = c(0.4, 0.6)),
  Q_MEAN = round(rnorm(n, mean = 5, sd = 1), 2),
  weight = runif(n, min = 0.5, max = 2.0),
  stringsAsFactors = FALSE
)

# Inject some missing answers
survey_data$Q_BIN[c(4, 5)]   <- NA
survey_data$Q_MEAN[c(6, 7)]  <- NA

# Inject NA and zero weights to trigger the alignment logic
survey_data$weight[c(3, 10)] <- NA
survey_data$weight[5]        <- 0   # zero weight on a case that also has NA Q_BIN

# Save as CSV (supported by load_survey_data)
write.csv(survey_data, data_file_path, row.names = FALSE)

cat("✓ Synthetic survey data written\n")

# ------------------------------------------------------------------------------
# 3. Create confidence_config_end_to_end.xlsx
# ------------------------------------------------------------------------------

wb <- openxlsx::createWorkbook()

# 3.1 File_Paths sheet
openxlsx::addWorksheet(wb, "File_Paths")

file_paths_df <- data.frame(
  Parameter = c("Data_File",          "Output_File",           "Weight_Variable"),
  Value     = c(data_file_path,       output_file_path,        "weight"),
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
    "random_seed"              # optional, but we include it
  ),
  Value = c(
    "Y",                        # Calculate effective n
    "N",                        # No multiple comparison adjustment
    "None",                     # Placeholder (not used since MC = N)
    "1200",                     # Between 1000 and 10000
    "0.95",                     # Allowed values: 0.90, 0.95, 0.99
    ".",                        # Decimal separator
    "12345"                     # Seed (numeric)
  ),
  stringsAsFactors = FALSE
)

openxlsx::writeData(wb, "Study_Settings", study_settings_df,
                    startRow = 1, startCol = 1,
                    colNames = TRUE, rowNames = FALSE)

# 3.3 Question_Analysis sheet
openxlsx::addWorksheet(wb, "Question_Analysis")

# We use Use_Wilson (the correct flag name)
question_analysis_df <- data.frame(
  Question_ID    = c("Q_BIN",     "Q_MEAN"),
  Statistic_Type = c("proportion","mean"),
  Categories     = c("1",        NA),       # Proportion uses category "1"; mean has no categories
  Run_MOE        = c("Y",        "Y"),
  Run_Bootstrap  = c("Y",        "Y"),
  Run_Credible   = c("Y",        "Y"),
  Use_Wilson     = c("Y",        "N"),      # For proportions only
  Prior_Mean     = c(NA,         NA),       # Leave priors blank (optional)
  Prior_SD       = c(NA,         NA),
  Prior_N        = c(NA,         NA),
  Notes          = c("Binary proportion test", "Mean test with weights"),
  stringsAsFactors = FALSE
)

openxlsx::writeData(wb, "Question_Analysis", question_analysis_df,
                    startRow = 1, startCol = 1,
                    colNames = TRUE, rowNames = FALSE)

# 3.4 Save config workbook
openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

cat("✓ Test configuration workbook written\n\n")

# ------------------------------------------------------------------------------
# 4. Source main module and run analysis
# ------------------------------------------------------------------------------

core_main <- file.path(module_root, "R", "00_main.R")

if (!file.exists(core_main)) {
  stop(sprintf("Could not find R/00_main.R at: %s", core_main), call. = FALSE)
}

cat("Sourcing main module from: ", core_main, "\n", sep = "")
source(core_main)

cat("\nRunning run_confidence_analysis() on test config...\n\n")

res <- run_confidence_analysis(
  config_path       = config_path,
  verbose           = TRUE,
  stop_on_warnings  = FALSE   # We want to see warnings but not stop on them
)

cat("\n✓ run_confidence_analysis() completed without error\n")

# ------------------------------------------------------------------------------
# 5. Basic sanity checks on results
# ------------------------------------------------------------------------------

# res is returned invisibly; we already captured it above.
if (!is.list(res)) {
  stop("Result from run_confidence_analysis() is not a list – unexpected structure.")
}

# Check that the two questions are present in the appropriate result slots
if (!"Q_BIN" %in% names(res$proportion_results)) {
  stop("Q_BIN not found in proportion_results – something is wrong with proportion processing.")
}

if (!"Q_MEAN" %in% names(res$mean_results)) {
  stop("Q_MEAN not found in mean_results – something is wrong with mean processing.")
}

# Check that we got a non-empty study_stats object if effective n is enabled
if (is.null(res$study_stats)) {
  stop("study_stats is NULL even though Calculate_Effective_N = 'Y'.")
}

# Check Q_BIN results
q_bin_result <- res$proportion_results$Q_BIN
if (is.null(q_bin_result$proportion)) {
  stop("Q_BIN: proportion is NULL")
}
if (is.null(q_bin_result$n) || q_bin_result$n == 0) {
  stop("Q_BIN: n is NULL or zero")
}
if (is.null(q_bin_result$n_eff) || q_bin_result$n_eff == 0) {
  stop("Q_BIN: n_eff is NULL or zero")
}

# Check Q_MEAN results
q_mean_result <- res$mean_results$Q_MEAN
if (is.null(q_mean_result$mean)) {
  stop("Q_MEAN: mean is NULL")
}
if (is.null(q_mean_result$n) || q_mean_result$n == 0) {
  stop("Q_MEAN: n is NULL or zero")
}
if (is.null(q_mean_result$n_eff) || q_mean_result$n_eff == 0) {
  stop("Q_MEAN: n_eff is NULL or zero")
}

cat("✓ Sanity checks passed:\n")
cat("  - study_stats non-NULL\n")
cat("  - Q_BIN present in proportion_results with valid n and n_eff\n")
cat("  - Q_MEAN present in mean_results with valid n and n_eff\n")

if (length(res$warnings) > 0) {
  cat("\nWarnings returned (", length(res$warnings), "):\n", sep = "")
  for (w in res$warnings) {
    cat("  - ", w, "\n", sep = "")
  }
}

cat("\nEnd-to-end test completed successfully.\n")
cat("Output workbook written to: ", output_file_path, "\n", sep = "")
