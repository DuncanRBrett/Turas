# Tests for hierarchical clustering
# Part of Turas Segment Module v11.0 test suite

# =============================================================================
# TEST SETUP
# =============================================================================

# Create well-separated test data for hierarchical clustering
create_hclust_test_data <- function() {
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
    linkage_method = "ward.D2"
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
# TEST: run_hclust_clustering() returns standard result structure
# =============================================================================

test_that("run_hclust_clustering returns standard result structure", {
  td <- create_hclust_test_data()

  result <- run_hclust_clustering(td$data_list, td$config, td$guard)

  # Check all required fields exist
  expect_true(!is.null(result$clusters))
  expect_true(!is.null(result$k))
  expect_true(!is.null(result$centers))
  expect_true(!is.null(result$method))
  expect_true(!is.null(result$model))
  expect_true(!is.null(result$method_info))
})


# =============================================================================
# TEST: result$method == "hclust"
# =============================================================================

test_that("result method is 'hclust'", {
  td <- create_hclust_test_data()

  result <- run_hclust_clustering(td$data_list, td$config, td$guard)

  expect_equal(result$method, "hclust")
})


# =============================================================================
# TEST: clusters is integer vector with values 1:k
# =============================================================================

test_that("clusters is integer vector with values in 1:k", {
  td <- create_hclust_test_data()

  result <- run_hclust_clustering(td$data_list, td$config, td$guard)

  expect_type(result$clusters, "integer")
  expect_equal(length(result$clusters), td$n)
  expect_true(all(result$clusters >= 1))
  expect_true(all(result$clusters <= td$config$k_fixed))
  expect_equal(sort(unique(result$clusters)), 1:td$config$k_fixed)
})


# =============================================================================
# TEST: centers has correct dimensions (k x p)
# =============================================================================

test_that("centers has correct dimensions (k x p)", {
  td <- create_hclust_test_data()

  result <- run_hclust_clustering(td$data_list, td$config, td$guard)

  expect_equal(nrow(result$centers), td$config$k_fixed)
  expect_equal(ncol(result$centers), td$p)
})


# =============================================================================
# TEST: method_info contains expected hclust-specific fields
# =============================================================================

test_that("method_info contains linkage, engine, dendrogram, cophenetic_correlation", {
  td <- create_hclust_test_data()

  result <- run_hclust_clustering(td$data_list, td$config, td$guard)

  mi <- result$method_info
  expect_true(!is.null(mi$linkage))
  expect_true(!is.null(mi$engine))
  expect_true(!is.null(mi$dendrogram))
  expect_true(!is.null(mi$cophenetic_correlation))

  # Linkage should match what we requested
  expect_equal(mi$linkage, "ward.d2")

  # Engine should be a string

  expect_type(mi$engine, "character")
})


# =============================================================================
# TEST: extract_dendrogram_data returns expected structure
# =============================================================================

test_that("extract_dendrogram_data returns n_leaves, cut_height, merge_steps", {
  td <- create_hclust_test_data()

  # Build hclust model manually for this test
  dist_matrix <- dist(td$scaled_data, method = "euclidean")
  hc_model <- stats::hclust(dist_matrix, method = "ward.D2")

  dend_data <- extract_dendrogram_data(hc_model, k = 3)

  expect_true(!is.null(dend_data$n_leaves))
  expect_true(!is.null(dend_data$cut_height))
  expect_true(!is.null(dend_data$merge_steps))

  expect_equal(dend_data$n_leaves, td$n)
  expect_true(is.numeric(dend_data$cut_height))
  expect_true(dend_data$cut_height > 0)
  expect_true(is.list(dend_data$merge_steps))
  expect_equal(length(dend_data$merge_steps), td$n - 1)
})


# =============================================================================
# TEST: compute_cophenetic returns numeric between -1 and 1
# =============================================================================

test_that("compute_cophenetic returns a numeric value between -1 and 1", {
  td <- create_hclust_test_data()

  dist_matrix <- dist(td$scaled_data, method = "euclidean")
  hc_model <- stats::hclust(dist_matrix, method = "ward.D2")

  coph <- compute_cophenetic(hc_model, dist_matrix)

  expect_true(is.numeric(coph))
  expect_true(length(coph) == 1)
  expect_true(coph >= -1 && coph <= 1)
})


# =============================================================================
# TEST: Invalid linkage method is refused
# =============================================================================

test_that("invalid linkage method triggers refusal", {
  td <- create_hclust_test_data()
  td$config$linkage_method <- "invalid_method"

  expect_error(
    run_hclust_clustering(td$data_list, td$config, td$guard),
    "CFG_INVALID_LINKAGE|Invalid Linkage|not supported"
  )
})


# =============================================================================
# TEST: Different linkage methods work correctly
# =============================================================================

test_that("different valid linkage methods produce results", {
  td <- create_hclust_test_data()

  valid_methods <- c("complete", "average", "ward.D2")

  for (method in valid_methods) {
    td$config$linkage_method <- method
    result <- run_hclust_clustering(td$data_list, td$config, td$guard)

    expect_equal(result$method, "hclust",
                 info = sprintf("Failed for linkage method: %s", method))
    expect_equal(length(result$clusters), td$n,
                 info = sprintf("Wrong cluster length for linkage method: %s", method))
  }
})


# =============================================================================
# TEST: Cophenetic correlation is present in method_info from full run
# =============================================================================

test_that("cophenetic correlation is present and valid from full hclust run", {
  td <- create_hclust_test_data()

  result <- run_hclust_clustering(td$data_list, td$config, td$guard)

  coph <- result$method_info$cophenetic_correlation
  expect_true(is.numeric(coph))
  # For well-separated data with Ward linkage, cophenetic should be reasonable
  expect_true(coph >= -1 && coph <= 1)
})
