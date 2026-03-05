# Tests for soft guards (00b_guards_soft.R)
# Part of Turas Segment Module v11.0 test suite
#
# Soft guards (guard_check_*) do NOT throw errors. They update the guard
# state with warnings and stability flags, then return the modified guard.

# ==============================================================================
# guard_check_low_variance()
# ==============================================================================

test_that("guard_check_low_variance() flags variables with near-zero variance", {
  # Arrange
  guard <- segment_guard_init()
  # Create data with one near-zero variance variable
  df <- data.frame(
    q1 = rnorm(100, mean = 5, sd = 1),
    q2 = rnorm(100, mean = 5, sd = 1),
    q3 = rep(3.0, 100) + rnorm(100, sd = 0.001)  # near-zero variance
  )

  # Act
  guard <- guard_check_low_variance(df, guard, threshold = 0.01)

  # Assert
  expect_true("q3" %in% guard$low_variance_variables)
  expect_false("q1" %in% guard$low_variance_variables)
  expect_false("q2" %in% guard$low_variance_variables)
  expect_true(length(guard$stability_flags) >= 1)
})

test_that("guard_check_low_variance() does not flag high variance variables", {
  # Arrange
  guard <- segment_guard_init()
  df <- data.frame(
    q1 = rnorm(100, sd = 2),
    q2 = rnorm(100, sd = 3)
  )

  # Act
  guard <- guard_check_low_variance(df, guard, threshold = 0.01)

  # Assert
  expect_length(guard$low_variance_variables, 0)
  expect_length(guard$stability_flags, 0)
})

test_that("guard_check_low_variance() respects custom threshold", {
  # Arrange
  guard <- segment_guard_init()
  set.seed(99)
  df <- data.frame(
    q1 = rnorm(100, sd = 0.5),   # var ~ 0.25
    q2 = rnorm(100, sd = 0.05)   # var ~ 0.0025
  )

  # Act - with high threshold, q1 should be flagged too
  guard <- guard_check_low_variance(df, guard, threshold = 0.30)

  # Assert - both should be flagged at threshold 0.30
  expect_true("q2" %in% guard$low_variance_variables)
})


# ==============================================================================
# guard_check_small_clusters()
# ==============================================================================

test_that("guard_check_small_clusters() flags clusters below min_pct", {

  # Arrange
  guard <- segment_guard_init()
  # 100 observations: segment 1 = 90, segment 2 = 8, segment 3 = 2
  clusters <- c(rep(1, 90), rep(2, 8), rep(3, 2))

  # Act
  guard <- guard_check_small_clusters(clusters, guard, min_pct = 5)

  # Assert - segment 3 is only 2%, below 5% threshold
  expect_true(length(guard$warnings) >= 1)
  expect_true(any(grepl("Segment 3", guard$warnings) | grepl("3", guard$warnings)))
})

test_that("guard_check_small_clusters() flags imbalance", {
  # Arrange
  guard <- segment_guard_init()
  # Ratio: 85/5 = 17x
  clusters <- c(rep(1, 85), rep(2, 10), rep(3, 5))

  # Act
  guard <- guard_check_small_clusters(clusters, guard, min_pct = 5)

  # Assert - should flag imbalance (ratio > 5)
  expect_true(any(grepl("imbalance", guard$warnings, ignore.case = TRUE)))
  expect_true(length(guard$stability_flags) >= 1)
})

test_that("guard_check_small_clusters() does not flag well-balanced clusters", {
  # Arrange
  guard <- segment_guard_init()
  clusters <- c(rep(1, 35), rep(2, 33), rep(3, 32))

  # Act
  guard <- guard_check_small_clusters(clusters, guard, min_pct = 5)

  # Assert - no warnings about small clusters or imbalance
  expect_false(any(grepl("imbalance", guard$warnings, ignore.case = TRUE)))
})


# ==============================================================================
# guard_check_silhouette_quality()
# ==============================================================================

test_that("guard_check_silhouette_quality() flags silhouette < 0.25", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  guard <- guard_check_silhouette_quality(0.15, guard)

  # Assert
  expect_true(length(guard$warnings) >= 1)
  expect_true(any(grepl("Weak", guard$warnings) | grepl("silhouette", guard$warnings, ignore.case = TRUE)))
  expect_true(length(guard$stability_flags) >= 1)
})

test_that("guard_check_silhouette_quality() warns but does not flag stability for moderate score", {
  # Arrange
  guard <- segment_guard_init()

  # Act - between 0.25 and 0.50
  guard <- guard_check_silhouette_quality(0.35, guard)

  # Assert - should warn but NOT add stability flag
  expect_true(length(guard$warnings) >= 1)
  expect_true(any(grepl("Moderate", guard$warnings)))
  # No stability flag for moderate
  expect_false(any(grepl("silhouette", guard$stability_flags, ignore.case = TRUE)))
})

test_that("guard_check_silhouette_quality() is silent for good silhouette", {
  # Arrange
  guard <- segment_guard_init()

  # Act - >= 0.50
  guard <- guard_check_silhouette_quality(0.65, guard)

  # Assert - no warnings
  expect_length(guard$warnings, 0)
  expect_length(guard$stability_flags, 0)
})

test_that("guard_check_silhouette_quality() handles NULL silhouette", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  guard <- guard_check_silhouette_quality(NULL, guard)

  # Assert - no changes
  expect_length(guard$warnings, 0)
})

test_that("guard_check_silhouette_quality() handles NA silhouette", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  guard <- guard_check_silhouette_quality(NA, guard)

  # Assert - no changes
  expect_length(guard$warnings, 0)
})


# ==============================================================================
# guard_check_outlier_proportion()
# ==============================================================================

test_that("guard_check_outlier_proportion() flags when >10% outliers", {
  # Arrange
  guard <- segment_guard_init()

  # Act - 15 outliers out of 100 = 15%
  guard <- guard_check_outlier_proportion(15, 100, guard, max_pct = 10)

  # Assert
  expect_true(length(guard$warnings) >= 1)
  expect_true(any(grepl("outlier", guard$warnings, ignore.case = TRUE)))
  expect_true(length(guard$stability_flags) >= 1)
})

test_that("guard_check_outlier_proportion() warns for moderate proportion (5-10%)", {
  # Arrange
  guard <- segment_guard_init()

  # Act - 7 outliers out of 100 = 7%
  guard <- guard_check_outlier_proportion(7, 100, guard, max_pct = 10)

  # Assert - should warn but NOT add stability flag
  expect_true(length(guard$warnings) >= 1)
  expect_true(any(grepl("outlier", guard$warnings, ignore.case = TRUE)))
  # Moderate proportion should not add stability flag (only > max_pct does)
  expect_length(guard$stability_flags, 0)
})

test_that("guard_check_outlier_proportion() is silent for zero outliers", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  guard <- guard_check_outlier_proportion(0, 100, guard, max_pct = 10)

  # Assert
  expect_length(guard$warnings, 0)
  expect_length(guard$stability_flags, 0)
})

test_that("guard_check_outlier_proportion() respects custom max_pct", {
  # Arrange
  guard <- segment_guard_init()

  # Act - 6 out of 100 = 6%, with max_pct = 5 should flag
  guard <- guard_check_outlier_proportion(6, 100, guard, max_pct = 5)

  # Assert
  expect_true(any(grepl("unusually high", guard$warnings, ignore.case = TRUE)))
  expect_true(length(guard$stability_flags) >= 1)
})


# ==============================================================================
# guard_check_missing_data()
# ==============================================================================

test_that("guard_check_missing_data() flags high missing rate", {
  # Arrange
  guard <- segment_guard_init()
  n <- 100
  df <- data.frame(
    q1 = c(rep(NA, 25), rnorm(75)),  # 25% missing
    q2 = rnorm(n),                    # 0% missing
    q3 = c(rep(NA, 5), rnorm(95))     # 5% missing
  )

  # Act
  guard <- guard_check_missing_data(df, vars = c("q1", "q2", "q3"), guard, threshold = 15)

  # Assert - only q1 (25%) should be flagged (> 15% threshold)
  expect_true(length(guard$warnings) >= 1)
  expect_true(any(grepl("q1", guard$warnings)))
  expect_false(any(grepl("q2", guard$warnings)))
  expect_false(any(grepl("q3", guard$warnings)))
})

test_that("guard_check_missing_data() is silent when below threshold", {
  # Arrange
  guard <- segment_guard_init()
  df <- data.frame(
    q1 = c(NA, rnorm(99)),   # 1% missing
    q2 = rnorm(100)           # 0% missing
  )

  # Act
  guard <- guard_check_missing_data(df, vars = c("q1", "q2"), guard, threshold = 15)

  # Assert
  expect_length(guard$warnings, 0)
})

test_that("guard_check_missing_data() handles variable not in data", {
  # Arrange
  guard <- segment_guard_init()
  df <- data.frame(q1 = rnorm(100))

  # Act - should silently skip nonexistent variable
  guard <- guard_check_missing_data(df, vars = c("q1", "nonexistent"), guard, threshold = 15)

  # Assert - no error, no warning about nonexistent
  expect_length(guard$warnings, 0)
})

test_that("guard_check_missing_data() respects custom threshold", {
  # Arrange
  guard <- segment_guard_init()
  df <- data.frame(
    q1 = c(rep(NA, 8), rnorm(92))  # 8% missing
  )

  # Act - threshold = 5 should flag it

  guard <- guard_check_missing_data(df, vars = "q1", guard, threshold = 5)

  # Assert
  expect_true(length(guard$warnings) >= 1)
  expect_true(any(grepl("q1", guard$warnings)))
})
