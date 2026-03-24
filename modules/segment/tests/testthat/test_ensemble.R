# ==============================================================================
# Tests for 14_ensemble.R
# Part of Turas Segment Module test suite
# ==============================================================================
# Covers: build_coassociation_matrix, cluster_coassociation,
#   compute_consensus_certainty, assess_consensus_quality,
#   generate_ensemble_partitions, run_ensemble_clustering
# ==============================================================================


# ==============================================================================
# build_coassociation_matrix()
# ==============================================================================

test_that("build_coassociation_matrix returns square matrix of correct size", {
  n <- 20
  # Create simple partitions: 2 partitions of n observations
  partitions <- cbind(
    rep(c(1, 2), each = n / 2),
    rep(c(1, 2), each = n / 2)
  )

  result <- build_coassociation_matrix(partitions, n)

  expect_true(is.matrix(result))
  expect_equal(nrow(result), n)
  expect_equal(ncol(result), n)
})

test_that("build_coassociation_matrix diagonal is always 1", {
  n <- 10
  partitions <- cbind(
    c(1, 1, 2, 2, 3, 3, 1, 2, 3, 1),
    c(1, 2, 1, 2, 1, 2, 3, 3, 3, 1)
  )

  result <- build_coassociation_matrix(partitions, n)

  expect_equal(diag(result), rep(1, n))
})

test_that("build_coassociation_matrix is symmetric", {
  n <- 15
  set.seed(42)
  partitions <- cbind(
    sample(1:3, n, replace = TRUE),
    sample(1:3, n, replace = TRUE),
    sample(1:2, n, replace = TRUE)
  )

  result <- build_coassociation_matrix(partitions, n)

  expect_equal(result, t(result))
})

test_that("build_coassociation_matrix values are in [0, 1]", {
  n <- 20
  set.seed(42)
  partitions <- cbind(
    sample(1:3, n, replace = TRUE),
    sample(1:3, n, replace = TRUE),
    sample(1:4, n, replace = TRUE),
    sample(1:2, n, replace = TRUE)
  )

  result <- build_coassociation_matrix(partitions, n)

  expect_true(all(result >= 0))
  expect_true(all(result <= 1))
})

test_that("build_coassociation_matrix returns 1 for always-together pairs", {
  n <- 10
  # Both partitions put observations 1-5 together and 6-10 together
  partitions <- cbind(
    c(rep(1, 5), rep(2, 5)),
    c(rep(1, 5), rep(2, 5))
  )

  result <- build_coassociation_matrix(partitions, n)

  # Observations 1 and 2 are always together
  expect_equal(result[1, 2], 1)
  # Observations 1 and 6 are never together
  expect_equal(result[1, 6], 0)
})


# ==============================================================================
# cluster_coassociation()
# ==============================================================================

test_that("cluster_coassociation returns correct structure", {
  n <- 20
  # Create a clear 2-cluster structure
  coassoc <- matrix(0.1, nrow = n, ncol = n)
  coassoc[1:10, 1:10] <- 0.9
  coassoc[11:20, 11:20] <- 0.9
  diag(coassoc) <- 1

  result <- cluster_coassociation(coassoc, k = 2)

  expect_true(is.list(result))
  expect_true("clusters" %in% names(result))
  expect_true("hc" %in% names(result))
  expect_length(result$clusters, n)
  expect_true(inherits(result$hc, "hclust"))
})

test_that("cluster_coassociation finds correct clusters for clear separation", {
  n <- 20
  coassoc <- matrix(0, nrow = n, ncol = n)
  coassoc[1:10, 1:10] <- 1
  coassoc[11:20, 11:20] <- 1
  diag(coassoc) <- 1

  result <- cluster_coassociation(coassoc, k = 2)

  # All items in group 1 should have the same cluster assignment
  expect_true(length(unique(result$clusters[1:10])) == 1)
  expect_true(length(unique(result$clusters[11:20])) == 1)
  # The two groups should have different assignments
  expect_true(result$clusters[1] != result$clusters[11])
})

test_that("cluster_coassociation returns k clusters", {
  n <- 30
  coassoc <- matrix(0.1, nrow = n, ncol = n)
  coassoc[1:10, 1:10] <- 0.9
  coassoc[11:20, 11:20] <- 0.9
  coassoc[21:30, 21:30] <- 0.9
  diag(coassoc) <- 1

  result <- cluster_coassociation(coassoc, k = 3)

  expect_equal(length(unique(result$clusters)), 3)
})


# ==============================================================================
# compute_consensus_certainty()
# ==============================================================================

test_that("compute_consensus_certainty returns values in [0, 1]", {
  n <- 20
  coassoc <- matrix(0.1, nrow = n, ncol = n)
  coassoc[1:10, 1:10] <- 0.9
  coassoc[11:20, 11:20] <- 0.9
  diag(coassoc) <- 1

  clusters <- c(rep(1, 10), rep(2, 10))

  result <- compute_consensus_certainty(coassoc, clusters, k = 2)

  expect_length(result, n)
  expect_true(all(result >= 0))
  expect_true(all(result <= 1))
})

test_that("compute_consensus_certainty gives high values for cohesive clusters", {
  n <- 20
  coassoc <- matrix(0, nrow = n, ncol = n)
  coassoc[1:10, 1:10] <- 1
  coassoc[11:20, 11:20] <- 1
  diag(coassoc) <- 1

  clusters <- c(rep(1, 10), rep(2, 10))

  result <- compute_consensus_certainty(coassoc, clusters, k = 2)

  # Perfect co-association within clusters -> high certainty
  expect_true(all(result > 0.9))
})

test_that("compute_consensus_certainty handles single-member clusters", {
  n <- 5
  coassoc <- matrix(0.5, nrow = n, ncol = n)
  diag(coassoc) <- 1

  # Cluster 3 has only one member (observation 5)
  clusters <- c(1, 1, 2, 2, 3)

  result <- compute_consensus_certainty(coassoc, clusters, k = 3)

  # Single member cluster should have certainty = 1
  expect_equal(result[5], 1)
})


# ==============================================================================
# assess_consensus_quality()
# ==============================================================================

test_that("assess_consensus_quality returns expected fields", {
  n <- 20
  coassoc <- matrix(0.1, nrow = n, ncol = n)
  coassoc[1:10, 1:10] <- 0.9
  coassoc[11:20, 11:20] <- 0.9
  diag(coassoc) <- 1

  clusters <- c(rep(1, 10), rep(2, 10))

  result <- assess_consensus_quality(coassoc, clusters, n_partitions = 10)

  expect_true(is.list(result))
  expect_true("consensus_rate" %in% names(result))
  expect_true("mean_cohesion" %in% names(result))
  expect_true("mean_separation" %in% names(result))
  expect_true("cluster_cohesion" %in% names(result))
  expect_true("cluster_separation" %in% names(result))
})

test_that("assess_consensus_quality metrics are in valid range", {
  n <- 20
  set.seed(42)
  coassoc <- matrix(runif(n * n), nrow = n, ncol = n)
  coassoc <- (coassoc + t(coassoc)) / 2
  diag(coassoc) <- 1

  clusters <- c(rep(1, 10), rep(2, 10))

  result <- assess_consensus_quality(coassoc, clusters, n_partitions = 10)

  expect_true(result$consensus_rate >= 0 && result$consensus_rate <= 1)
  expect_true(result$mean_cohesion >= 0 && result$mean_cohesion <= 1)
  expect_true(result$mean_separation >= 0 && result$mean_separation <= 1)
})

test_that("assess_consensus_quality gives high values for clear clusters", {
  n <- 20
  coassoc <- matrix(0, nrow = n, ncol = n)
  coassoc[1:10, 1:10] <- 1
  coassoc[11:20, 11:20] <- 1
  diag(coassoc) <- 1

  clusters <- c(rep(1, 10), rep(2, 10))

  result <- assess_consensus_quality(coassoc, clusters, n_partitions = 50)

  # Perfect separation should yield high consensus rate, high cohesion
  expect_true(result$consensus_rate > 0.8)
  expect_true(result$mean_cohesion > 0.9)
  expect_true(result$mean_separation > 0.9)
})


# ==============================================================================
# generate_ensemble_partitions()
# ==============================================================================

test_that("generate_ensemble_partitions returns matrix of correct dimensions", {
  set.seed(42)
  data <- matrix(rnorm(200), ncol = 5)

  result <- generate_ensemble_partitions(
    scaled_data = data,
    methods = c("kmeans"),
    n_runs = 10,
    k_range = c(2, 4),
    nstart = 10
  )

  expect_true(is.matrix(result))
  expect_equal(nrow(result), 40)  # n = 40 observations
  # Should have approximately 10 partitions (some might fail)
  expect_true(ncol(result) >= 5)
})

test_that("generate_ensemble_partitions handles multiple methods", {
  set.seed(42)
  data <- matrix(rnorm(200), ncol = 5)

  result <- generate_ensemble_partitions(
    scaled_data = data,
    methods = c("kmeans", "hclust"),
    n_runs = 5,
    k_range = c(2, 3),
    nstart = 10
  )

  expect_true(is.matrix(result))
  # Should have more partitions with 2 methods
  expect_true(ncol(result) >= 5)
})

test_that("generate_ensemble_partitions returns empty matrix for unknown method", {
  set.seed(42)
  data <- matrix(rnorm(100), ncol = 5)

  result <- generate_ensemble_partitions(
    scaled_data = data,
    methods = c("nonexistent_method"),
    n_runs = 5,
    k_range = c(2, 3),
    nstart = 10
  )

  expect_true(is.matrix(result))
  expect_equal(ncol(result), 0)
})

test_that("generate_ensemble_partitions cluster values are valid", {
  set.seed(42)
  data <- matrix(rnorm(200), ncol = 5)

  result <- generate_ensemble_partitions(
    scaled_data = data,
    methods = c("kmeans"),
    n_runs = 5,
    k_range = c(2, 3),
    nstart = 10
  )

  # All partitions should have at least 2 unique values
  for (i in seq_len(ncol(result))) {
    expect_true(length(unique(result[, i])) >= 2)
  }
})


# ==============================================================================
# run_ensemble_clustering() - integration-level test
# ==============================================================================

test_that("run_ensemble_clustering returns expected structure", {
  set.seed(42)
  n <- 60
  p <- 4
  # Create data with 3 clear clusters
  data <- rbind(
    matrix(rnorm(20 * p, mean = 0), ncol = p),
    matrix(rnorm(20 * p, mean = 5), ncol = p),
    matrix(rnorm(20 * p, mean = 10), ncol = p)
  )
  colnames(data) <- paste0("v", 1:p)

  data_list <- list(scaled_data = data)
  config <- list(
    k_fixed = 3,
    ensemble_methods = c("kmeans"),
    ensemble_n_runs = 20,
    ensemble_k_range = c(2, 4),
    nstart = 10
  )
  guard <- list()

  output <- capture.output(
    result <- run_ensemble_clustering(data_list, config, guard)
  )

  expect_true(is.list(result))
  expect_true("clusters" %in% names(result))
  expect_true("k" %in% names(result))
  expect_true("centers" %in% names(result))
  expect_true("method" %in% names(result))
  expect_true("method_info" %in% names(result))

  expect_equal(result$k, 3)
  expect_equal(result$method, "ensemble")
  expect_equal(length(result$clusters), n)
  expect_equal(nrow(result$centers), 3)
  expect_equal(ncol(result$centers), p)

  # Method info
  expect_true("n_partitions" %in% names(result$method_info))
  expect_true("consensus_rate" %in% names(result$method_info))
  expect_true("mean_certainty" %in% names(result$method_info))
  expect_true("certainty" %in% names(result$method_info))
  expect_length(result$method_info$certainty, n)
})

test_that("run_ensemble_clustering refuses insufficient partitions", {
  set.seed(42)
  data <- matrix(rnorm(30), ncol = 3)
  colnames(data) <- paste0("v", 1:3)

  data_list <- list(scaled_data = data)
  config <- list(
    k_fixed = 2,
    ensemble_methods = c("nonexistent"),
    ensemble_n_runs = 3,
    ensemble_k_range = c(2, 3),
    nstart = 5
  )
  guard <- list()

  expect_error(
    capture.output(run_ensemble_clustering(data_list, config, guard)),
    class = "turas_refusal"
  )
})
