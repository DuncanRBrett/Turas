# Tests for guard framework (00_guard.R)
# Part of Turas Segment Module v11.0 test suite

# ==============================================================================
# segment_guard_init()
# ==============================================================================

test_that("segment_guard_init() creates proper guard state with expected fields", {
  # Act
  guard <- segment_guard_init()

  # Assert - base guard fields from guard_init()
  expect_true(is.list(guard))
  expect_equal(guard$module, "SEGMENT")
  expect_type(guard$warnings, "character")
  expect_length(guard$warnings, 0)

  expect_type(guard$stability_flags, "character")
  expect_length(guard$stability_flags, 0)

  # Assert - segment-specific fields
  expect_type(guard$dropped_variables, "character")
  expect_length(guard$dropped_variables, 0)

  expect_type(guard$low_variance_variables, "character")
  expect_length(guard$low_variance_variables, 0)

  expect_true(is.list(guard$cluster_stability))
  expect_length(guard$cluster_stability, 0)

  expect_equal(guard$outliers_removed, 0)

  expect_null(guard$clustering_method)

  expect_type(guard$imputed_variables, "character")
  expect_length(guard$imputed_variables, 0)

  expect_false(guard$variables_selected)
  expect_equal(guard$original_var_count, 0)
  expect_equal(guard$final_var_count, 0)
})


# ==============================================================================
# guard_record_dropped_variable()
# ==============================================================================

test_that("guard_record_dropped_variable() adds to dropped_variables list", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  guard <- guard_record_dropped_variable(guard, "q1", "zero variance")
  guard <- guard_record_dropped_variable(guard, "q5", "constant value")

  # Assert
  expect_equal(guard$dropped_variables, c("q1", "q5"))
  expect_length(guard$dropped_variables, 2)
  # Should also add warnings
  expect_true(length(guard$warnings) >= 2)
  expect_true(any(grepl("q1", guard$warnings)))
  expect_true(any(grepl("q5", guard$warnings)))
})


# ==============================================================================
# guard_record_low_variance()
# ==============================================================================

test_that("guard_record_low_variance() adds to low_variance_variables", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  guard <- guard_record_low_variance(guard, "q3", 0.001)
  guard <- guard_record_low_variance(guard, "q7", 0.005)

  # Assert
  expect_equal(guard$low_variance_variables, c("q3", "q7"))
  expect_true(length(guard$stability_flags) >= 1)
  expect_true(any(grepl("q3", guard$stability_flags)))
})


# ==============================================================================
# guard_record_cluster_stability()
# ==============================================================================

test_that("guard_record_cluster_stability() records stability metrics", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  guard <- guard_record_cluster_stability(guard, k = 4, silhouette = 0.45, within_ss = 1234.5)

  # Assert
  expect_equal(guard$cluster_stability$k, 4)
  expect_equal(guard$cluster_stability$silhouette, 0.45)
  expect_equal(guard$cluster_stability$within_ss, 1234.5)
})

test_that("guard_record_cluster_stability() flags low silhouette", {
  # Arrange
  guard <- segment_guard_init()

  # Act - silhouette below 0.25 threshold
  guard <- guard_record_cluster_stability(guard, k = 3, silhouette = 0.15, within_ss = 500)

  # Assert - should add stability flag
  expect_true(length(guard$stability_flags) >= 1)
  expect_true(any(grepl("silhouette", guard$stability_flags, ignore.case = TRUE)))
})

test_that("guard_record_cluster_stability() does not flag good silhouette", {
  # Arrange
  guard <- segment_guard_init()

  # Act - silhouette above 0.25 threshold
  guard <- guard_record_cluster_stability(guard, k = 3, silhouette = 0.55, within_ss = 300)

  # Assert - no stability flags added for cluster quality
  expect_length(guard$stability_flags, 0)
})


# ==============================================================================
# guard_record_outliers_removed()
# ==============================================================================

test_that("guard_record_outliers_removed() tracks count", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  guard <- guard_record_outliers_removed(guard, 5)
  guard <- guard_record_outliers_removed(guard, 3)

  # Assert - should accumulate
  expect_equal(guard$outliers_removed, 8)
  expect_true(length(guard$warnings) >= 2)
})

test_that("guard_record_outliers_removed() does not warn when n_removed is 0", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  guard <- guard_record_outliers_removed(guard, 0)

  # Assert
  expect_equal(guard$outliers_removed, 0)
  expect_length(guard$warnings, 0)
})


# ==============================================================================
# guard_record_imputation()
# ==============================================================================

test_that("guard_record_imputation() tracks imputed variables", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  guard <- guard_record_imputation(guard, "q2", "median")
  guard <- guard_record_imputation(guard, "q8", "mean")

  # Assert
  expect_equal(guard$imputed_variables, c("q2", "q8"))
  expect_true(length(guard$warnings) >= 2)
  expect_true(any(grepl("q2", guard$warnings)))
  expect_true(any(grepl("median", guard$warnings)))
})


# ==============================================================================
# segment_guard_summary()
# ==============================================================================

test_that("segment_guard_summary() returns comprehensive summary", {
  # Arrange
  guard <- segment_guard_init()
  guard <- guard_record_dropped_variable(guard, "q1", "constant")
  guard <- guard_record_low_variance(guard, "q3", 0.001)
  guard <- guard_record_cluster_stability(guard, k = 3, silhouette = 0.35, within_ss = 500)
  guard <- guard_record_outliers_removed(guard, 2)
  guard$clustering_method <- "kmeans"
  guard <- guard_record_imputation(guard, "q5", "median")

  # Act
  summary <- segment_guard_summary(guard)

  # Assert
  expect_true(is.list(summary))
  expect_equal(summary$module, "SEGMENT")
  expect_true(summary$has_issues)
  expect_true(summary$n_warnings > 0)
  expect_equal(summary$dropped_variables, "q1")
  expect_equal(summary$low_variance_variables, "q3")
  expect_equal(summary$cluster_stability$k, 3)
  expect_equal(summary$outliers_removed, 2)
  expect_equal(summary$clustering_method, "kmeans")
  expect_equal(summary$imputed_variables, "q5")
})

test_that("segment_guard_summary() reports has_issues when variables dropped", {
  # Arrange
  guard <- segment_guard_init()
  guard <- guard_record_dropped_variable(guard, "q1", "constant")

  # Act
  summary <- segment_guard_summary(guard)

  # Assert
  expect_true(summary$has_issues)
})

test_that("segment_guard_summary() reports no issues on clean guard", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  summary <- segment_guard_summary(guard)

  # Assert
  expect_false(summary$has_issues)
  expect_equal(summary$n_warnings, 0)
})


# ==============================================================================
# segment_determine_status()
# ==============================================================================

test_that("segment_determine_status() returns PASS when no issues", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  status <- segment_determine_status(guard,
    clusters_created = 3,
    cases_assigned = 300,
    silhouette_score = 0.55
  )

  # Assert
  expect_equal(status$run_status, "PASS")
  expect_equal(status$details$silhouette_score, 0.55)
})

test_that("segment_determine_status() returns PARTIAL when variables dropped", {
  # Arrange
  guard <- segment_guard_init()
  guard <- guard_record_dropped_variable(guard, "q1", "constant")

  # Act
  status <- segment_determine_status(guard,
    clusters_created = 3,
    cases_assigned = 300,
    silhouette_score = 0.55
  )

  # Assert
  expect_equal(status$run_status, "PARTIAL")
  expect_true(length(status$degraded_reasons) > 0)
  expect_true(any(grepl("dropped", status$degraded_reasons, ignore.case = TRUE)))
  expect_true("cluster_centers" %in% status$affected_outputs ||
              "variable_profiles" %in% status$affected_outputs)
})

test_that("segment_determine_status() returns PARTIAL when silhouette < 0.25", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  status <- segment_determine_status(guard,
    clusters_created = 3,
    cases_assigned = 300,
    silhouette_score = 0.18
  )

  # Assert
  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("silhouette", status$degraded_reasons, ignore.case = TRUE)))
  expect_equal(status$details$silhouette_score, 0.18)
})

test_that("segment_determine_status() returns PARTIAL when outliers removed", {
  # Arrange
  guard <- segment_guard_init()
  guard <- guard_record_outliers_removed(guard, 10)

  # Act
  status <- segment_determine_status(guard,
    clusters_created = 3,
    cases_assigned = 290,
    silhouette_score = 0.45
  )

  # Assert
  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("outlier", status$degraded_reasons, ignore.case = TRUE)))
})

test_that("segment_determine_status() returns PARTIAL when variables imputed", {
  # Arrange
  guard <- segment_guard_init()
  guard <- guard_record_imputation(guard, "q2", "median")

  # Act
  status <- segment_determine_status(guard,
    clusters_created = 3,
    cases_assigned = 300,
    silhouette_score = 0.50
  )

  # Assert
  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("imputed", status$degraded_reasons, ignore.case = TRUE)))
})

test_that("segment_determine_status() includes silhouette in details", {
  # Arrange
  guard <- segment_guard_init()

  # Act
  status <- segment_determine_status(guard, silhouette_score = 0.72)

  # Assert
  expect_equal(status$details$silhouette_score, 0.72)
})
