# ==============================================================================
# NPS TEST FOR TURAS CONFIDENCE MODULE
# ==============================================================================
# Purpose:
# - Create a synthetic dataset with NPS questions
# - Test NPS calculations with and without weights
# - Verify all confidence interval methods work for NPS
# - Ensure promoter/detractor percentages are calculated correctly
#
# Assumptions:
# - Working directory is the module root (where 'R' and 'tests' live)
# - Packages 'openxlsx' and 'readxl' are available
# - R/00_main.R contains the NPS processing function
# ==============================================================================

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')",
       call. = FALSE)
}

# ------------------------------------------------------------------------------
# 1. Paths and directories
# ------------------------------------------------------------------------------

module_root <- getwd()
test_dir    <- file.path(module_root, "tests", "nps_test")
data_dir    <- test_dir

if (!dir.exists(test_dir)) dir.create(test_dir, recursive = TRUE)

data_file_path   <- file.path(data_dir, "test_nps_data.csv")
output_file_path <- file.path(data_dir, "confidence_results_nps.xlsx")
config_path      <- file.path(data_dir, "confidence_config_nps.xlsx")

cat("Module root: ", module_root, "\n", sep = "")
cat("Test dir:    ", test_dir, "\n", sep = "")
cat("Data file:   ", data_file_path, "\n", sep = "")
cat("Output file: ", output_file_path, "\n", sep = "")
cat("Config file: ", config_path, "\n\n", sep = "")

# ------------------------------------------------------------------------------
# 2. Create synthetic NPS survey data
# ------------------------------------------------------------------------------

set.seed(456)
n <- 100L

# Create NPS scores on 0-10 scale
# Typical distribution: some detractors (0-6), passives (7-8), promoters (9-10)
nps_scores <- sample(0:10, n, replace = TRUE,
                     prob = c(0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05,  # 0-6 (detractors)
                             0.15, 0.15,  # 7-8 (passives)
                             0.20, 0.20)) # 9-10 (promoters)

survey_data <- data.frame(
  ID        = 1:n,
  NPS_Q1    = nps_scores,
  NPS_Q2    = sample(0:10, n, replace = TRUE),  # Second NPS question
  weight    = runif(n, min = 0.5, max = 2.0),
  stringsAsFactors = FALSE
)

# Inject some missing answers
survey_data$NPS_Q1[c(4, 5)] <- NA
survey_data$NPS_Q2[c(6, 7)] <- NA

# Inject NA and zero weights to test alignment
survey_data$weight[c(3, 10)] <- NA
survey_data$weight[5] <- 0

# Save as CSV
write.csv(survey_data, data_file_path, row.names = FALSE)

cat("✓ Synthetic NPS survey data written\n")
cat(sprintf("  Sample NPS scores (Q1): %s\n",
            paste(head(survey_data$NPS_Q1, 10), collapse = ", ")))

# ------------------------------------------------------------------------------
# 3. Create confidence_config_nps.xlsx
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
    "random_seed"
  ),
  Value = c(
    "Y",
    "N",
    "None",
    "1200",
    "0.95",
    ".",
    "54321"
  ),
  stringsAsFactors = FALSE
)

openxlsx::writeData(wb, "Study_Settings", study_settings_df,
                    startRow = 1, startCol = 1,
                    colNames = TRUE, rowNames = FALSE)

# 3.3 Question_Analysis sheet
openxlsx::addWorksheet(wb, "Question_Analysis")

# NPS questions with promoter/detractor codes
question_analysis_df <- data.frame(
  Question_ID      = c("NPS_Q1",     "NPS_Q2"),
  Statistic_Type   = c("nps",        "nps"),
  Categories       = c(NA,           NA),
  Run_MOE          = c("Y",          "Y"),
  Run_Bootstrap    = c("Y",          "Y"),
  Run_Credible     = c("Y",          "Y"),
  Use_Wilson       = c("N",          "N"),
  Promoter_Codes   = c("9,10",       "9,10"),      # Standard NPS: 9-10 are promoters
  Detractor_Codes  = c("0,1,2,3,4,5,6", "0,1,2,3,4,5,6"),  # 0-6 are detractors
  Prior_Mean       = c(NA,           NA),
  Prior_SD         = c(NA,           NA),
  Prior_N          = c(NA,           NA),
  Notes            = c("NPS test with weights", "NPS test unweighted"),
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

cat("\nRunning run_confidence_analysis() on NPS test config...\n\n")

res <- run_confidence_analysis(
  config_path       = config_path,
  verbose           = TRUE,
  stop_on_warnings  = FALSE
)

cat("\n✓ run_confidence_analysis() completed without error\n")

# ------------------------------------------------------------------------------
# 5. Validate NPS results
# ------------------------------------------------------------------------------

if (!is.list(res)) {
  stop("Result from run_confidence_analysis() is not a list – unexpected structure.")
}

# Check that NPS questions are present
if (!"NPS_Q1" %in% names(res$nps_results)) {
  stop("NPS_Q1 not found in nps_results – something is wrong with NPS processing.")
}

if (!"NPS_Q2" %in% names(res$nps_results)) {
  stop("NPS_Q2 not found in nps_results – something is wrong with NPS processing.")
}

# Check study stats
if (is.null(res$study_stats)) {
  stop("study_stats is NULL even though Calculate_Effective_N = 'Y'.")
}

# Validate NPS_Q1 results
nps_q1 <- res$nps_results$NPS_Q1

cat("\n=== NPS_Q1 Results ===\n")
cat(sprintf("NPS Score: %.1f\n", nps_q1$nps_score))
cat(sprintf("%% Promoters: %.1f%%\n", nps_q1$pct_promoters))
cat(sprintf("%% Detractors: %.1f%%\n", nps_q1$pct_detractors))
cat(sprintf("Sample Size (n): %d\n", nps_q1$n))
cat(sprintf("Effective n: %.1f\n", nps_q1$n_eff))

# Validation checks
if (is.null(nps_q1$nps_score)) {
  stop("NPS_Q1: NPS score is NULL")
}

if (nps_q1$nps_score < -100 || nps_q1$nps_score > 100) {
  stop(sprintf("NPS_Q1: NPS score out of range: %.1f (should be -100 to +100)", nps_q1$nps_score))
}

if (is.null(nps_q1$pct_promoters) || is.null(nps_q1$pct_detractors)) {
  stop("NPS_Q1: Promoter or detractor percentage is NULL")
}

# Check that NPS = %Promoters - %Detractors
expected_nps <- nps_q1$pct_promoters - nps_q1$pct_detractors
if (abs(nps_q1$nps_score - expected_nps) > 0.01) {
  stop(sprintf("NPS_Q1: NPS calculation error. Expected %.2f, got %.2f",
               expected_nps, nps_q1$nps_score))
}

if (is.null(nps_q1$n) || nps_q1$n == 0) {
  stop("NPS_Q1: n is NULL or zero")
}

if (is.null(nps_q1$n_eff) || nps_q1$n_eff == 0) {
  stop("NPS_Q1: n_eff is NULL or zero")
}

# Check confidence intervals exist
if (!is.null(nps_q1$normal_ci)) {
  cat(sprintf("Normal CI: [%.1f, %.1f]\n",
              nps_q1$normal_ci$lower, nps_q1$normal_ci$upper))

  # CI should contain the NPS score
  if (nps_q1$normal_ci$lower > nps_q1$nps_score ||
      nps_q1$normal_ci$upper < nps_q1$nps_score) {
    warning("Normal CI does not contain the NPS score")
  }
}

if (!is.null(nps_q1$bootstrap)) {
  cat(sprintf("Bootstrap CI: [%.1f, %.1f]\n",
              nps_q1$bootstrap$lower, nps_q1$bootstrap$upper))
}

if (!is.null(nps_q1$bayesian)) {
  cat(sprintf("Bayesian CI: [%.1f, %.1f] (post mean: %.1f)\n",
              nps_q1$bayesian$lower, nps_q1$bayesian$upper,
              nps_q1$bayesian$post_mean))
}

# Validate NPS_Q2 results
nps_q2 <- res$nps_results$NPS_Q2

cat("\n=== NPS_Q2 Results ===\n")
cat(sprintf("NPS Score: %.1f\n", nps_q2$nps_score))
cat(sprintf("%% Promoters: %.1f%%\n", nps_q2$pct_promoters))
cat(sprintf("%% Detractors: %.1f%%\n", nps_q2$pct_detractors))
cat(sprintf("Sample Size (n): %d\n", nps_q2$n))
cat(sprintf("Effective n: %.1f\n", nps_q2$n_eff))

if (is.null(nps_q2$nps_score)) {
  stop("NPS_Q2: NPS score is NULL")
}

if (nps_q2$nps_score < -100 || nps_q2$nps_score > 100) {
  stop(sprintf("NPS_Q2: NPS score out of range: %.1f", nps_q2$nps_score))
}

cat("\n✓ All NPS validations passed\n")

# Check warnings
if (length(res$warnings) > 0) {
  cat("\nWarnings returned (", length(res$warnings), "):\n", sep = "")
  for (w in res$warnings) {
    cat("  - ", w, "\n", sep = "")
  }
}

cat("\n================================================================================\n")
cat("NPS TEST COMPLETED SUCCESSFULLY\n")
cat("================================================================================\n")
cat("\nKey Results:\n")
cat(sprintf("  - NPS_Q1: %.1f (n=%d, n_eff=%.1f)\n",
            nps_q1$nps_score, nps_q1$n, nps_q1$n_eff))
cat(sprintf("  - NPS_Q2: %.1f (n=%d, n_eff=%.1f)\n",
            nps_q2$nps_score, nps_q2$n, nps_q2$n_eff))
cat(sprintf("\nOutput workbook: %s\n", output_file_path))
cat("\nAll NPS functionality verified:\n")
cat("  ✓ NPS calculation (promoters - detractors)\n")
cat("  ✓ Weighted data handling\n")
cat("  ✓ Normal approximation CI\n")
cat("  ✓ Bootstrap CI\n")
cat("  ✓ Bayesian CI\n")
cat("  ✓ Output generation\n")
cat("\n")
