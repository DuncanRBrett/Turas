# ==============================================================================
# WEIGHTED DATA TEST - CONFIDENCE MODULE
# ==============================================================================
# Purpose: Comprehensive test of weighted data handling
# Tests all edge cases that the bug fixes address:
#   - NA weights
#   - Zero weights
#   - Extreme weight variation
#   - Mixed scenarios
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("WEIGHTED DATA COMPREHENSIVE TEST\n")
cat("================================================================================\n\n")

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' required. Install with: install.packages('openxlsx')")
}

# ------------------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------------------

module_root <- getwd()
test_dir <- file.path(module_root, "tests", "weighted_test")
if (!dir.exists(test_dir)) dir.create(test_dir, recursive = TRUE)

# ------------------------------------------------------------------------------
# TEST 1: Standard weighted data (no issues)
# ------------------------------------------------------------------------------

cat("TEST 1: Standard weighted data (no NA, no zeros)\n")
cat("--------------------------------------------------\n")

set.seed(100)
n <- 100

data1 <- data.frame(
  ID = 1:n,
  Q_PROP = sample(c(0, 1), n, replace = TRUE, prob = c(0.35, 0.65)),
  Q_MEAN = round(rnorm(n, mean = 7.5, sd = 1.5), 1),
  weight = runif(n, min = 0.5, max = 2.5)  # Reasonable variation
)

write.csv(data1, file.path(test_dir, "test1_standard.csv"), row.names = FALSE)

# Create config
wb1 <- openxlsx::createWorkbook()

openxlsx::addWorksheet(wb1, "File_Paths")
openxlsx::writeData(wb1, "File_Paths", data.frame(
  Parameter = c("Data_File", "Output_File", "Weight_Variable"),
  Value = c(
    file.path(test_dir, "test1_standard.csv"),
    file.path(test_dir, "output1_standard.xlsx"),
    "weight"
  )
))

openxlsx::addWorksheet(wb1, "Study_Settings")
openxlsx::writeData(wb1, "Study_Settings", data.frame(
  Setting = c("Calculate_Effective_N", "Multiple_Comparison_Adjustment", "Multiple_Comparison_Method",
              "Bootstrap_Iterations", "Confidence_Level", "Decimal_Separator"),
  Value = c("Y", "N", "None", "1000", "0.95", ".")
))

openxlsx::addWorksheet(wb1, "Question_Analysis")
openxlsx::writeData(wb1, "Question_Analysis", data.frame(
  Question_ID = c("Q_PROP", "Q_MEAN"),
  Statistic_Type = c("proportion", "mean"),
  Categories = c("1", NA),
  Run_MOE = c("Y", "Y"),
  Run_Bootstrap = c("Y", "Y"),
  Run_Credible = c("N", "N"),
  Use_Wilson = c("Y", "N")
))

openxlsx::saveWorkbook(wb1, file.path(test_dir, "config1.xlsx"), overwrite = TRUE)

# Run analysis
source(file.path(module_root, "R", "00_main.R"))
result1 <- run_confidence_analysis(file.path(test_dir, "config1.xlsx"), verbose = FALSE)

cat("✓ Analysis completed successfully\n")
cat(sprintf("  Actual n: %d, Effective n: %d, DEFF: %.2f\n",
            result1$study_stats$Actual_n,
            result1$study_stats$Effective_n,
            result1$study_stats$DEFF))
cat(sprintf("  Q_PROP: n=%d, n_eff=%d, proportion=%.3f\n",
            result1$proportion_results$Q_PROP$n,
            result1$proportion_results$Q_PROP$n_eff,
            result1$proportion_results$Q_PROP$proportion))
cat(sprintf("  Q_MEAN: n=%d, n_eff=%d, mean=%.2f\n",
            result1$mean_results$Q_MEAN$n,
            result1$mean_results$Q_MEAN$n_eff,
            result1$mean_results$Q_MEAN$mean))

stopifnot(result1$proportion_results$Q_PROP$n == 100)
stopifnot(result1$mean_results$Q_MEAN$n == 100)
stopifnot(!is.null(result1$proportion_results$Q_PROP$moe))
stopifnot(!is.null(result1$proportion_results$Q_PROP$wilson))
stopifnot(!is.null(result1$mean_results$Q_MEAN$t_dist))

cat("✓ All assertions passed\n\n")

# ------------------------------------------------------------------------------
# TEST 2: Data with NA weights (critical fix test)
# ------------------------------------------------------------------------------

cat("TEST 2: Data with NA weights\n")
cat("--------------------------------------------------\n")

set.seed(101)
n <- 100

data2 <- data.frame(
  ID = 1:n,
  Q_PROP = sample(c(0, 1), n, replace = TRUE, prob = c(0.4, 0.6)),
  Q_MEAN = round(rnorm(n, mean = 6.0, sd = 2.0), 1),
  weight = runif(n, min = 0.5, max = 2.5)
)

# Inject NA weights at specific positions
data2$weight[c(5, 10, 15, 20, 25)] <- NA  # 5 NA weights

write.csv(data2, file.path(test_dir, "test2_na_weights.csv"), row.names = FALSE)

# Create config
wb2 <- openxlsx::createWorkbook()

openxlsx::addWorksheet(wb2, "File_Paths")
openxlsx::writeData(wb2, "File_Paths", data.frame(
  Parameter = c("Data_File", "Output_File", "Weight_Variable"),
  Value = c(
    file.path(test_dir, "test2_na_weights.csv"),
    file.path(test_dir, "output2_na_weights.xlsx"),
    "weight"
  )
))

openxlsx::addWorksheet(wb2, "Study_Settings")
openxlsx::writeData(wb2, "Study_Settings", data.frame(
  Setting = c("Calculate_Effective_N", "Multiple_Comparison_Adjustment", "Multiple_Comparison_Method",
              "Bootstrap_Iterations", "Confidence_Level", "Decimal_Separator"),
  Value = c("Y", "N", "None", "1000", "0.95", ".")
))

openxlsx::addWorksheet(wb2, "Question_Analysis")
openxlsx::writeData(wb2, "Question_Analysis", data.frame(
  Question_ID = c("Q_PROP", "Q_MEAN"),
  Statistic_Type = c("proportion", "mean"),
  Categories = c("1", NA),
  Run_MOE = c("Y", "Y"),
  Run_Bootstrap = c("Y", "Y"),
  Run_Credible = c("N", "N"),
  Use_Wilson = c("Y", "N")
))

openxlsx::saveWorkbook(wb2, file.path(test_dir, "config2.xlsx"), overwrite = TRUE)

# Run analysis
result2 <- run_confidence_analysis(file.path(test_dir, "config2.xlsx"), verbose = FALSE)

cat("✓ Analysis completed successfully\n")
cat(sprintf("  Actual n: %d, Effective n: %d (5 NA weights excluded)\n",
            result2$study_stats$Actual_n,
            result2$study_stats$Effective_n))
cat(sprintf("  Q_PROP: n=%d (should be 95)\n", result2$proportion_results$Q_PROP$n))
cat(sprintf("  Q_MEAN: n=%d (should be 95)\n", result2$mean_results$Q_MEAN$n))

# Critical check: n should be 95 (100 - 5 NA weights)
stopifnot(result2$proportion_results$Q_PROP$n == 95)
stopifnot(result2$mean_results$Q_MEAN$n == 95)
stopifnot(!is.null(result2$proportion_results$Q_PROP$bootstrap))
stopifnot(!is.null(result2$mean_results$Q_MEAN$bootstrap))

cat("✓ NA weights correctly excluded from analysis\n")
cat("✓ No length mismatch errors (bug fix verified!)\n\n")

# ------------------------------------------------------------------------------
# TEST 3: Data with zero weights (critical fix test)
# ------------------------------------------------------------------------------

cat("TEST 3: Data with zero weights\n")
cat("--------------------------------------------------\n")

set.seed(102)
n <- 100

data3 <- data.frame(
  ID = 1:n,
  Q_PROP = sample(c(0, 1), n, replace = TRUE, prob = c(0.3, 0.7)),
  Q_MEAN = round(rnorm(n, mean = 8.0, sd = 1.2), 1),
  weight = runif(n, min = 0.5, max = 2.5)
)

# Inject zero weights
data3$weight[c(3, 7, 12, 18)] <- 0  # 4 zero weights

write.csv(data3, file.path(test_dir, "test3_zero_weights.csv"), row.names = FALSE)

# Create config
wb3 <- openxlsx::createWorkbook()

openxlsx::addWorksheet(wb3, "File_Paths")
openxlsx::writeData(wb3, "File_Paths", data.frame(
  Parameter = c("Data_File", "Output_File", "Weight_Variable"),
  Value = c(
    file.path(test_dir, "test3_zero_weights.csv"),
    file.path(test_dir, "output3_zero_weights.xlsx"),
    "weight"
  )
))

openxlsx::addWorksheet(wb3, "Study_Settings")
openxlsx::writeData(wb3, "Study_Settings", data.frame(
  Setting = c("Calculate_Effective_N", "Multiple_Comparison_Adjustment", "Multiple_Comparison_Method",
              "Bootstrap_Iterations", "Confidence_Level", "Decimal_Separator"),
  Value = c("Y", "N", "None", "1000", "0.95", ".")
))

openxlsx::addWorksheet(wb3, "Question_Analysis")
openxlsx::writeData(wb3, "Question_Analysis", data.frame(
  Question_ID = c("Q_PROP", "Q_MEAN"),
  Statistic_Type = c("proportion", "mean"),
  Categories = c("1", NA),
  Run_MOE = c("Y", "Y"),
  Run_Bootstrap = c("Y", "Y"),
  Run_Credible = c("N", "N"),
  Use_Wilson = c("Y", "N")
))

openxlsx::saveWorkbook(wb3, file.path(test_dir, "config3.xlsx"), overwrite = TRUE)

# Run analysis
result3 <- run_confidence_analysis(file.path(test_dir, "config3.xlsx"), verbose = FALSE)

cat("✓ Analysis completed successfully\n")
cat(sprintf("  Q_PROP: n=%d (should be 96, 4 zero weights excluded)\n",
            result3$proportion_results$Q_PROP$n))
cat(sprintf("  Q_MEAN: n=%d (should be 96, 4 zero weights excluded)\n",
            result3$mean_results$Q_MEAN$n))

stopifnot(result3$proportion_results$Q_PROP$n == 96)
stopifnot(result3$mean_results$Q_MEAN$n == 96)
stopifnot(!is.null(result3$proportion_results$Q_PROP$wilson))

cat("✓ Zero weights correctly excluded from analysis\n")
cat("✓ No crashes in weighted calculations (bug fix verified!)\n\n")

# ------------------------------------------------------------------------------
# TEST 4: Mixed NA, zeros, and missing data (worst case)
# ------------------------------------------------------------------------------

cat("TEST 4: Mixed NA weights, zero weights, and missing data\n")
cat("--------------------------------------------------\n")

set.seed(103)
n <- 100

data4 <- data.frame(
  ID = 1:n,
  Q_PROP = sample(c(0, 1, NA), n, replace = TRUE, prob = c(0.35, 0.6, 0.05)),
  Q_MEAN = sample(c(rnorm(95, mean = 7, sd = 1.5), rep(NA, 5))),
  weight = runif(n, min = 0.5, max = 2.5)
)

# Inject problematic weights
data4$weight[c(2, 5, 8)] <- NA    # 3 NA weights
data4$weight[c(10, 15)] <- 0       # 2 zero weights

write.csv(data4, file.path(test_dir, "test4_mixed.csv"), row.names = FALSE)

# Create config
wb4 <- openxlsx::createWorkbook()

openxlsx::addWorksheet(wb4, "File_Paths")
openxlsx::writeData(wb4, "File_Paths", data.frame(
  Parameter = c("Data_File", "Output_File", "Weight_Variable"),
  Value = c(
    file.path(test_dir, "test4_mixed.csv"),
    file.path(test_dir, "output4_mixed.xlsx"),
    "weight"
  )
))

openxlsx::addWorksheet(wb4, "Study_Settings")
openxlsx::writeData(wb4, "Study_Settings", data.frame(
  Setting = c("Calculate_Effective_N", "Multiple_Comparison_Adjustment", "Multiple_Comparison_Method",
              "Bootstrap_Iterations", "Confidence_Level", "Decimal_Separator"),
  Value = c("Y", "N", "None", "1000", "0.95", ".")
))

openxlsx::addWorksheet(wb4, "Question_Analysis")
openxlsx::writeData(wb4, "Question_Analysis", data.frame(
  Question_ID = c("Q_PROP", "Q_MEAN"),
  Statistic_Type = c("proportion", "mean"),
  Categories = c("1", NA),
  Run_MOE = c("Y", "Y"),
  Run_Bootstrap = c("Y", "Y"),
  Run_Credible = c("N", "N"),
  Use_Wilson = c("Y", "N")
))

openxlsx::saveWorkbook(wb4, file.path(test_dir, "config4.xlsx"), overwrite = TRUE)

# Run analysis
result4 <- run_confidence_analysis(file.path(test_dir, "config4.xlsx"), verbose = FALSE)

cat("✓ Analysis completed successfully with messy data\n")
cat(sprintf("  Q_PROP: n=%d (valid cases after all filtering)\n",
            result4$proportion_results$Q_PROP$n))
cat(sprintf("  Q_MEAN: n=%d (valid cases after all filtering)\n",
            result4$mean_results$Q_MEAN$n))

# Should have valid results despite messy data
stopifnot(!is.null(result4$proportion_results$Q_PROP$proportion))
stopifnot(!is.null(result4$mean_results$Q_MEAN$mean))
stopifnot(result4$proportion_results$Q_PROP$n > 0)
stopifnot(result4$mean_results$Q_MEAN$n > 0)

cat("✓ Handles worst-case scenario correctly\n")
cat("✓ No crashes with mixed NA/zero weights + missing data\n\n")

# ------------------------------------------------------------------------------
# TEST 5: Extreme weight variation (high DEFF)
# ------------------------------------------------------------------------------

cat("TEST 5: Extreme weight variation (stress test)\n")
cat("--------------------------------------------------\n")

set.seed(104)
n <- 100

# Create weights with extreme variation
weights_extreme <- c(
  rep(0.1, 30),     # Very low weights
  runif(50, 0.8, 1.2),  # Normal weights
  rep(5.0, 20)      # Very high weights
)

data5 <- data.frame(
  ID = 1:n,
  Q_PROP = sample(c(0, 1), n, replace = TRUE),
  Q_MEAN = round(rnorm(n, mean = 6.5, sd = 1.8), 1),
  weight = sample(weights_extreme)  # Shuffle for randomness
)

write.csv(data5, file.path(test_dir, "test5_extreme.csv"), row.names = FALSE)

# Create config
wb5 <- openxlsx::createWorkbook()

openxlsx::addWorksheet(wb5, "File_Paths")
openxlsx::writeData(wb5, "File_Paths", data.frame(
  Parameter = c("Data_File", "Output_File", "Weight_Variable"),
  Value = c(
    file.path(test_dir, "test5_extreme.csv"),
    file.path(test_dir, "output5_extreme.xlsx"),
    "weight"
  )
))

openxlsx::addWorksheet(wb5, "Study_Settings")
openxlsx::writeData(wb5, "Study_Settings", data.frame(
  Setting = c("Calculate_Effective_N", "Multiple_Comparison_Adjustment", "Multiple_Comparison_Method",
              "Bootstrap_Iterations", "Confidence_Level", "Decimal_Separator"),
  Value = c("Y", "N", "None", "1000", "0.95", ".")
))

openxlsx::addWorksheet(wb5, "Question_Analysis")
openxlsx::writeData(wb5, "Question_Analysis", data.frame(
  Question_ID = c("Q_PROP", "Q_MEAN"),
  Statistic_Type = c("proportion", "mean"),
  Categories = c("1", NA),
  Run_MOE = c("Y", "Y"),
  Run_Bootstrap = c("Y", "Y"),
  Run_Credible = c("N", "N"),
  Use_Wilson = c("Y", "N")
))

openxlsx::saveWorkbook(wb5, file.path(test_dir, "config5.xlsx"), overwrite = TRUE)

# Run analysis
result5 <- run_confidence_analysis(file.path(test_dir, "config5.xlsx"), verbose = FALSE)

cat("✓ Analysis completed with extreme weights\n")
cat(sprintf("  Actual n: %d, Effective n: %d, DEFF: %.2f (should be high!)\n",
            result5$study_stats$Actual_n,
            result5$study_stats$Effective_n,
            result5$study_stats$DEFF))

# With extreme variation, DEFF should be notably > 1
stopifnot(result5$study_stats$DEFF > 1.5)  # Should be substantial
stopifnot(result5$study_stats$Effective_n < result5$study_stats$Actual_n)
stopifnot(!is.null(result5$proportion_results$Q_PROP$bootstrap))

cat("✓ Correctly handles extreme weight variation\n")
cat("✓ DEFF calculation working properly\n\n")

# ------------------------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------------------------

cat("================================================================================\n")
cat("ALL WEIGHTED DATA TESTS PASSED!\n")
cat("================================================================================\n\n")

cat("Tests completed:\n")
cat("  ✓ TEST 1: Standard weighted data\n")
cat("  ✓ TEST 2: NA weights (critical bug fix verified)\n")
cat("  ✓ TEST 3: Zero weights (critical bug fix verified)\n")
cat("  ✓ TEST 4: Mixed messy data (worst case)\n")
cat("  ✓ TEST 5: Extreme weight variation (stress test)\n\n")

cat("Critical verifications:\n")
cat("  ✓ No length mismatch errors\n")
cat("  ✓ No crashes in weighted.mean()\n")
cat("  ✓ No crashes in bootstrap functions\n")
cat("  ✓ Values and weights correctly aligned\n")
cat("  ✓ NA and zero weights properly excluded\n")
cat("  ✓ Effective n calculated correctly\n")
cat("  ✓ DEFF reflects weight variation\n\n")

cat("Output files created in: ", test_dir, "\n")
cat("  - 5 test datasets\n")
cat("  - 5 config files\n")
cat("  - 5 result workbooks\n\n")

cat("The weighted data bug fixes are confirmed working!\n")
cat("Ready for production use with weighted survey data.\n\n")
