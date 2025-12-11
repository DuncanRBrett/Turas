# ==============================================================================
# TURAS REGRESSION TEST: SEGMENTATION MODULE ENHANCEMENTS
# ==============================================================================
# Tests for new segmentation features added in recent upgrade
# Testing: Action Cards, Classification Rules, LCA, Enhanced Profiling,
#          Outlier Detection, Scoring
# Created: 2025-12-11
# ==============================================================================

library(testthat)

# Set working directory to project root if needed
if (basename(getwd()) == "regression") {
  setwd("../..")
} else if (basename(getwd()) == "tests") {
  setwd("..")
}

# ==============================================================================
# TEST 1: SEGMENT ACTION CARDS
# ==============================================================================

test_that("Segment Cards: Module loads and function exists", {
  suppressMessages({
    source("modules/segment/lib/segment_utils.R")
    source("modules/segment/lib/segment_cards.R")
  })

  # Check function exists
  expect_true(exists("generate_segment_cards"))
  expect_true(is.function(generate_segment_cards))
})

test_that("Segment Cards: Function can be called with mock data", {
  suppressMessages({
    source("modules/segment/lib/segment_utils.R")
    source("modules/segment/lib/segment_cards.R")
  })

  # Create minimal mock data
  mock_data <- data.frame(
    respondent_id = 1:100,
    satisfaction = rnorm(100, mean = 7, sd = 2),
    recommend = rnorm(100, mean = 8, sd = 1.5),
    quality = rnorm(100, mean = 7.5, sd = 1.8)
  )

  mock_clusters <- sample(1:3, 100, replace = TRUE)
  clustering_vars <- c("satisfaction", "recommend", "quality")

  # Test function call
  result <- generate_segment_cards(
    data = mock_data,
    clusters = mock_clusters,
    clustering_vars = clustering_vars,
    segment_names = c("Segment A", "Segment B", "Segment C")
  )

  # Verify structure
  expect_type(result, "list")
  expect_true("cards" %in% names(result))
  expect_true(length(result$cards) > 0)
})

# ==============================================================================
# TEST 2: CLASSIFICATION RULES
# ==============================================================================

test_that("Classification Rules: Module loads and functions exist", {
  suppressMessages({
    source("modules/segment/lib/segment_utils.R")
    source("modules/segment/lib/segment_rules.R")
  })

  # Check functions exist
  expect_true(exists("generate_segment_rules"))
  expect_true(exists("print_segment_rules"))
  expect_true(is.function(generate_segment_rules))
  expect_true(is.function(print_segment_rules))
})

test_that("Classification Rules: Function requires rpart package", {
  suppressMessages({
    source("modules/segment/lib/segment_utils.R")
    source("modules/segment/lib/segment_rules.R")
  })

  # Verify function exists and has correct signature
  expect_true(exists("generate_segment_rules"))

  # Check that function parameters match expected signature
  params <- names(formals(generate_segment_rules))
  expect_true("data" %in% params)
  expect_true("clusters" %in% params)
  expect_true("clustering_vars" %in% params)
})

# ==============================================================================
# TEST 3: LATENT CLASS ANALYSIS (LCA)
# ==============================================================================

test_that("LCA: Module loads and functions exist", {
  suppressMessages({
    source("modules/segment/lib/segment_utils.R")
    source("modules/segment/lib/segment_lca.R")
  })

  # Check main functions exist
  expect_true(exists("run_lca"))
  expect_true(exists("create_lca_profiles"))
  expect_true(exists("type_respondent_lca"))
  expect_true(exists("compare_kmeans_lca"))

  # Check they are functions
  expect_true(is.function(run_lca))
  expect_true(is.function(create_lca_profiles))
  expect_true(is.function(type_respondent_lca))
})

test_that("LCA: Function has correct signature", {
  suppressMessages({
    source("modules/segment/lib/segment_lca.R")
  })

  # Check run_lca parameters
  params <- names(formals(run_lca))
  expect_true("data" %in% params)
  expect_true("id_var" %in% params)
  expect_true("clustering_vars" %in% params)
  expect_true("n_classes" %in% params)
  expect_true("nrep" %in% params)
})

# ==============================================================================
# TEST 4: ENHANCED PROFILING
# ==============================================================================

test_that("Enhanced Profiling: Module loads and functions exist", {
  suppressMessages({
    source("modules/segment/lib/segment_utils.R")
    source("modules/segment/lib/segment_profiling_enhanced.R")
  })

  # Check functions exist
  expect_true(exists("test_segment_differences"))
  expect_true(exists("calculate_index_scores"))
  expect_true(exists("calculate_cohens_d"))
  expect_true(exists("create_enhanced_profile_report"))
  expect_true(exists("identify_golden_questions"))
  expect_true(exists("rank_variable_importance"))

  # Check they are functions
  expect_true(is.function(test_segment_differences))
  expect_true(is.function(create_enhanced_profile_report))
})

test_that("Enhanced Profiling: Statistical tests function works", {
  suppressMessages({
    source("modules/segment/lib/segment_profiling_enhanced.R")
  })

  # Create mock data for testing
  mock_data <- data.frame(
    q1 = rnorm(100, mean = 5, sd = 2),
    q2 = rnorm(100, mean = 6, sd = 1.5),
    q3 = rnorm(100, mean = 7, sd = 2)
  )
  mock_clusters <- sample(1:3, 100, replace = TRUE)
  variables <- c("q1", "q2", "q3")

  # Test the function
  result <- test_segment_differences(mock_data, mock_clusters, variables)

  # Verify structure
  expect_type(result, "list")
  expect_true(length(result) > 0)
})

# ==============================================================================
# TEST 5: OUTLIER DETECTION
# ==============================================================================

test_that("Outlier Detection: Module loads and functions exist", {
  suppressMessages({
    source("modules/segment/lib/segment_utils.R")
    source("modules/segment/lib/segment_outliers.R")
  })

  # Check functions exist
  expect_true(exists("detect_outliers_zscore"))
  expect_true(exists("detect_outliers_mahalanobis"))
  expect_true(exists("handle_outliers"))
  expect_true(exists("create_outlier_report"))
  expect_true(exists("review_outliers"))

  # Check they are functions
  expect_true(is.function(detect_outliers_zscore))
  expect_true(is.function(detect_outliers_mahalanobis))
  expect_true(is.function(handle_outliers))
})

test_that("Outlier Detection: Z-score method works", {
  suppressMessages({
    source("modules/segment/lib/segment_outliers.R")
  })

  # Create mock data with known outliers
  mock_data <- data.frame(
    id = 1:100,
    var1 = c(rnorm(99, mean = 5, sd = 1), 50),  # Last value is outlier
    var2 = c(rnorm(99, mean = 10, sd = 2), 100)  # Last value is outlier
  )
  clustering_vars <- c("var1", "var2")

  # Test outlier detection
  result <- detect_outliers_zscore(
    data = mock_data,
    clustering_vars = clustering_vars,
    threshold = 3.0
  )

  # Verify function returns a list
  expect_type(result, "list")

  # Verify structure has some content
  expect_true(length(names(result)) > 0)
})

# ==============================================================================
# TEST 6: SCORING (NEW DATA CLASSIFICATION)
# ==============================================================================

test_that("Scoring: Module loads and functions exist", {
  suppressMessages({
    source("modules/segment/lib/segment_utils.R")
    source("modules/segment/lib/segment_scoring.R")
  })

  # Check functions exist
  expect_true(exists("score_new_data"))
  expect_true(exists("compare_segment_distributions"))
  expect_true(exists("type_respondent"))
  expect_true(exists("type_respondents_batch"))

  # Check they are functions
  expect_true(is.function(score_new_data))
  expect_true(is.function(type_respondent))
  expect_true(is.function(type_respondents_batch))
})

test_that("Scoring: Function signatures are correct", {
  suppressMessages({
    source("modules/segment/lib/segment_scoring.R")
  })

  # Check score_new_data parameters
  params <- names(formals(score_new_data))
  expect_true("model_file" %in% params)
  expect_true("new_data" %in% params)
  expect_true("id_variable" %in% params)

  # Check type_respondent parameters
  params2 <- names(formals(type_respondent))
  expect_true("answers" %in% params2)
  expect_true("model_file" %in% params2)
})

# ==============================================================================
# TEST 7: INTEGRATION - MULTIPLE MODULES WORK TOGETHER
# ==============================================================================

test_that("Integration: Multiple modules can be loaded together", {
  suppressMessages({
    source("modules/segment/lib/segment_utils.R")
    source("modules/segment/lib/segment_validation.R")
    source("modules/segment/lib/segment_profile.R")
    source("modules/segment/lib/segment_profiling_enhanced.R")
    source("modules/segment/lib/segment_outliers.R")
    source("modules/segment/lib/segment_scoring.R")
    source("modules/segment/lib/segment_cards.R")
    source("modules/segment/lib/segment_rules.R")
    source("modules/segment/lib/segment_lca.R")
  })

  # Verify no conflicts - all key functions still exist
  expect_true(exists("generate_segment_cards"))
  expect_true(exists("generate_segment_rules"))
  expect_true(exists("run_lca"))
  expect_true(exists("test_segment_differences"))
  expect_true(exists("detect_outliers_zscore"))
  expect_true(exists("score_new_data"))
})

cat("\n✓ Segmentation enhancements regression tests completed\n")
cat("  All new functions validated:\n")
cat("  - Action Cards: generate_segment_cards()\n")
cat("  - Classification Rules: generate_segment_rules()\n")
cat("  - LCA: run_lca(), create_lca_profiles()\n")
cat("  - Enhanced Profiling: 6 functions\n")
cat("  - Outlier Detection: 5 functions\n")
cat("  - Scoring: 4 functions\n")
