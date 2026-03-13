# ==============================================================================
# MAXDIFF TESTS - TURF ANALYSIS
# ==============================================================================

test_that("classify_appeal returns correct dimensions with ABOVE_MEAN", {
  td <- generate_test_data()
  appeal <- classify_appeal(td$individual_utils, method = "ABOVE_MEAN")

  expect_equal(nrow(appeal), td$n_resp)
  expect_equal(ncol(appeal), td$n_items)
  expect_true(is.logical(appeal))
  # Each respondent should have roughly half items above mean
  avg_appeal <- mean(rowSums(appeal))
  expect_true(avg_appeal > 1 && avg_appeal < td$n_items - 1)
})

test_that("classify_appeal TOP_3 selects exactly 3 per respondent", {
  td <- generate_test_data()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  row_counts <- rowSums(appeal)
  expect_true(all(row_counts == 3))
})

test_that("classify_appeal TOP_K with k=2 selects exactly 2", {
  td <- generate_test_data()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_K", k = 2)

  row_counts <- rowSums(appeal)
  expect_true(all(row_counts == 2))
})

test_that("classify_appeal ABOVE_ZERO works correctly", {
  mat <- matrix(c(1, -1, 0.5, -0.5, 2, 0.1), nrow = 2, ncol = 3)
  colnames(mat) <- c("A", "B", "C")
  appeal <- classify_appeal(mat, method = "ABOVE_ZERO")

  expect_true(as.logical(appeal[1, 1]))    # 1 > 0
  expect_false(as.logical(appeal[2, 1]))   # -1 < 0
})

test_that("calculate_reach returns 0 for empty portfolio", {
  td <- generate_test_data()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  reach <- calculate_reach(appeal, integer(0))
  expect_equal(reach, 0)
})

test_that("calculate_reach returns value between 0 and 1", {
  td <- generate_test_data()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  reach <- calculate_reach(appeal, c(1, 2))
  expect_true(reach >= 0 && reach <= 1)
})

test_that("run_turf_analysis returns correct structure", {
  td <- generate_test_data()

  result <- run_turf_analysis(
    individual_utils = td$individual_utils,
    items = td$items,
    max_items = 4,
    threshold_method = "ABOVE_MEAN",
    verbose = FALSE
  )

  expect_equal(result$status, "PASS")
  expect_true(is.data.frame(result$incremental_table))
  expect_true(nrow(result$incremental_table) > 0)
  expect_true(nrow(result$incremental_table) <= 4)
  expect_true("Step" %in% names(result$incremental_table))
  expect_true("Reach_Pct" %in% names(result$incremental_table))
  expect_true("Incremental_Pct" %in% names(result$incremental_table))

  # Reach should be monotonically increasing
  reaches <- result$incremental_table$Reach_Pct
  expect_true(all(diff(reaches) >= 0))
})

test_that("run_turf_analysis refuses when no individual utilities", {
  skip_if(!exists("maxdiff_refuse", mode = "function"))

  result <- tryCatch(
    run_turf_analysis(NULL, NULL, verbose = FALSE),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(result$status == "REFUSED" || !is.null(result$message))
})

test_that("calculate_portfolio_reach works for custom portfolio", {
  td <- generate_test_data()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  result <- calculate_portfolio_reach(
    appeal,
    item_ids = c("I1", "I2"),
    all_item_ids = colnames(appeal)
  )

  expect_true(result$reach_pct >= 0 && result$reach_pct <= 100)
  expect_equal(result$n_items, 2)
})
