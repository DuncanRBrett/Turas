# Tests for Gaussian Mixture Model clustering
# Part of Turas Segment Module v11.0 test suite

# Skip all tests if mclust is not installed
skip_if_not_installed("mclust")

# =============================================================================
# TEST SETUP
# =============================================================================

create_gmm_test_data <- function() {
  set.seed(42)
  n <- 100
  p <- 5

  # 3 well-separated clusters
  cluster1 <- matrix(rnorm(34 * p, mean = 3, sd = 0.5), ncol = p)
  cluster2 <- matrix(rnorm(33 * p, mean = 0, sd = 0.5), ncol = p)
  cluster3 <- matrix(rnorm(33 * p, mean = -3, sd = 0.5), ncol = p)

  scaled_data <- rbind(cluster1, cluster2, cluster3)
  colnames(scaled_data) <- paste0("v", 1:p)

  data_list <- list(
    scaled_data = scaled_data
  )

  config <- list(
    k_fixed = 3,
    gmm_model_type = NULL  # Let mclust choose best
  )

  guard <- segment_guard_init()

  list(
    data_list = data_list,
    config = config,
    guard = guard,
    scaled_data = scaled_data,
    n = n,
    p = p
  )
}


# =============================================================================
# TEST: run_gmm_clustering returns standard structure
# =============================================================================

test_that("run_gmm_clustering returns standard clustering result structure", {
  td <- create_gmm_test_data()

  result <- run_gmm_clustering(td$data_list, td$config, td$guard)

  # Check all standard fields
  expect_true(!is.null(result$clusters))
  expect_true(!is.null(result$k))
  expect_true(!is.null(result$centers))
  expect_true(!is.null(result$method))
  expect_true(!is.null(result$model))
  expect_true(!is.null(result$method_info))
})


# =============================================================================
# TEST: result$method == "gmm"
# =============================================================================

test_that("result method is 'gmm'", {
  td <- create_gmm_test_data()

  result <- run_gmm_clustering(td$data_list, td$config, td$guard)

  expect_equal(result$method, "gmm")
})


# =============================================================================
# TEST: probabilities is matrix with n rows, k cols
# =============================================================================

test_that("probabilities is matrix with n rows and k columns", {
  td <- create_gmm_test_data()

  result <- run_gmm_clustering(td$data_list, td$config, td$guard)

  probs <- result$method_info$probabilities
  expect_true(is.matrix(probs))
  expect_equal(nrow(probs), td$n)
  expect_equal(ncol(probs), td$config$k_fixed)
})


# =============================================================================
# TEST: probabilities sum to 1 per row
# =============================================================================

test_that("probabilities sum to 1 per row within tolerance", {
  td <- create_gmm_test_data()

  result <- run_gmm_clustering(td$data_list, td$config, td$guard)

  probs <- result$method_info$probabilities
  row_sums <- rowSums(probs)

  # Each row should sum to 1 within floating point tolerance
  expect_true(all(abs(row_sums - 1) < 1e-6))
})


# =============================================================================
# TEST: uncertainty is numeric vector
# =============================================================================

test_that("uncertainty is numeric vector of correct length", {
  td <- create_gmm_test_data()

  result <- run_gmm_clustering(td$data_list, td$config, td$guard)

  uncertainty <- result$method_info$uncertainty
  expect_true(is.numeric(uncertainty))
  expect_equal(length(uncertainty), td$n)
  # Uncertainty should be between 0 and 1
  expect_true(all(uncertainty >= 0))
  expect_true(all(uncertainty <= 1))
})


# =============================================================================
# TEST: summarize_gmm_membership returns expected structure
# =============================================================================

test_that("summarize_gmm_membership returns segment_summary and uncertainty", {
  td <- create_gmm_test_data()

  result <- run_gmm_clustering(td$data_list, td$config, td$guard)

  summary <- summarize_gmm_membership(
    probabilities = result$method_info$probabilities,
    uncertainty = result$method_info$uncertainty
  )

  expect_true(!is.null(summary$segment_summary))
  expect_true(is.data.frame(summary$segment_summary))
  expect_equal(nrow(summary$segment_summary), td$config$k_fixed)

  # Check expected columns in summary_df
  expect_true("segment" %in% names(summary$segment_summary))
  expect_true("mean_probability" %in% names(summary$segment_summary))
  expect_true("n_primary" %in% names(summary$segment_summary))

  # Check uncertainty summary is present
  expect_true(!is.null(summary$uncertainty))
  expect_true(is.list(summary$uncertainty))
  expect_true("mean" %in% names(summary$uncertainty))
  expect_true("pct_high" %in% names(summary$uncertainty))
})


# =============================================================================
# TEST: Borderline cases correctly identified
# =============================================================================

test_that("borderline cases are correctly identified with uncertainty > 0.3", {
  td <- create_gmm_test_data()

  result <- run_gmm_clustering(td$data_list, td$config, td$guard)

  uncertainty <- result$method_info$uncertainty
  borderline_threshold <- result$method_info$borderline_threshold
  n_borderline <- result$method_info$n_borderline

  expect_equal(borderline_threshold, 0.3)
  expect_equal(n_borderline, sum(uncertainty > 0.3))
})


# =============================================================================
# TEST: clusters are valid integers in 1:k
# =============================================================================

test_that("clusters are valid integers in 1:k", {
  td <- create_gmm_test_data()

  result <- run_gmm_clustering(td$data_list, td$config, td$guard)

  expect_type(result$clusters, "integer")
  expect_equal(length(result$clusters), td$n)
  expect_true(all(result$clusters >= 1))
  expect_true(all(result$clusters <= td$config$k_fixed))
})


# =============================================================================
# TEST: centers have correct dimensions
# =============================================================================

test_that("centers have correct dimensions (k x p)", {
  td <- create_gmm_test_data()

  result <- run_gmm_clustering(td$data_list, td$config, td$guard)

  expect_equal(nrow(result$centers), td$config$k_fixed)
  expect_equal(ncol(result$centers), td$p)
})


# =============================================================================
# TEST: method_info contains GMM-specific fields
# =============================================================================

test_that("method_info contains GMM-specific fields", {
  td <- create_gmm_test_data()

  result <- run_gmm_clustering(td$data_list, td$config, td$guard)

  mi <- result$method_info
  expect_true(!is.null(mi$model_type))
  expect_true(!is.null(mi$bic))
  expect_true(!is.null(mi$loglik))
  expect_true(!is.null(mi$n_parameters))
  expect_true(!is.null(mi$probabilities))
  expect_true(!is.null(mi$uncertainty))
  expect_true(!is.null(mi$n_borderline))
  expect_true(!is.null(mi$covariance_type))
})


# =============================================================================
# TEST: summarize_gmm_membership with custom segment names
# =============================================================================

test_that("summarize_gmm_membership accepts custom segment names", {
  td <- create_gmm_test_data()

  result <- run_gmm_clustering(td$data_list, td$config, td$guard)

  custom_names <- c("Alpha", "Beta", "Gamma")
  summary <- summarize_gmm_membership(
    probabilities = result$method_info$probabilities,
    uncertainty = result$method_info$uncertainty,
    segment_names = custom_names
  )

  expect_equal(summary$segment_summary$segment, custom_names)
})


# =============================================================================
# TEST: summarize_gmm_membership returns NULL for NULL probabilities
# =============================================================================

test_that("summarize_gmm_membership returns NULL for NULL probabilities", {
  result <- summarize_gmm_membership(
    probabilities = NULL,
    uncertainty = NULL
  )

  expect_null(result)
})
