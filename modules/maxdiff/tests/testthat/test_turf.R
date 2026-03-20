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

# ==============================================================================
# EXPANDED TURF TESTS
# ==============================================================================

test_that("TURF with 1 item reaches 100% if all respondents find it appealing", {
  # Arrange: all respondents have positive utility for item I1
  # Using ABOVE_ZERO, every respondent has item I1 above 0
  utils_mat <- matrix(c(5, 5, 5, -1, -1, -1), nrow = 3, ncol = 2)
  colnames(utils_mat) <- c("I1", "I2")

  items <- data.frame(
    Item_ID = c("I1", "I2"),
    Item_Label = c("Item A", "Item B"),
    stringsAsFactors = FALSE
  )

  # Act
  result <- run_turf_analysis(
    individual_utils = utils_mat,
    items = items,
    max_items = 2,
    threshold_method = "ABOVE_ZERO",
    verbose = FALSE
  )

  # Assert: first step should reach 100% since all respondents find I1 appealing
  expect_equal(result$status, "PASS")
  expect_equal(result$incremental_table$Reach_Pct[1], 100)
})

test_that("greedy selection stops at 100% reach", {
  # Arrange: 3 items, each respondent finds at least one appealing
  # With TOP_K k=1, every respondent has exactly one appealing item
  # So 3 items covering 3 non-overlapping groups should hit 100%
  set.seed(55)
  n_resp <- 30
  utils_mat <- matrix(rnorm(n_resp * 3), nrow = n_resp, ncol = 3)
  colnames(utils_mat) <- c("I1", "I2", "I3")

  # Force each respondent to have exactly one clear winner
  for (i in seq_len(n_resp)) {
    winner <- (i %% 3) + 1
    utils_mat[i, ] <- c(-2, -2, -2)
    utils_mat[i, winner] <- 5
  }

  items <- data.frame(
    Item_ID = c("I1", "I2", "I3"),
    Item_Label = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )

  # Act (using TOP_K with k=1 so each respondent finds exactly 1 item appealing)
  result <- run_turf_analysis(
    individual_utils = utils_mat,
    items = items,
    max_items = 3,
    threshold_method = "TOP_K",
    threshold_k = 1,
    verbose = FALSE
  )

  # Assert: should reach 100% within 3 steps
  expect_equal(result$status, "PASS")
  final_reach <- tail(result$incremental_table$Reach_Pct, 1)
  expect_equal(final_reach, 100)
})

test_that("calculate_portfolio_reach returns correct values for known data", {
  # Arrange: known appeal matrix
  appeal <- matrix(
    c(TRUE, FALSE, TRUE,   # I1: resp 1 & 3 find it appealing
      FALSE, TRUE, TRUE,   # I2: resp 2 & 3 find it appealing
      FALSE, FALSE, FALSE), # I3: nobody finds it appealing
    nrow = 3, ncol = 3
  )
  colnames(appeal) <- c("I1", "I2", "I3")

  # Act: portfolio of I1 only
  result_i1 <- calculate_portfolio_reach(appeal, item_ids = "I1", all_item_ids = c("I1", "I2", "I3"))
  expect_equal(result_i1$reach_pct, round(2/3 * 100, 1))  # 66.7%
  expect_equal(result_i1$n_items, 1)

  # Act: portfolio of I1 + I2 should reach all 3 respondents
  result_i1i2 <- calculate_portfolio_reach(appeal, item_ids = c("I1", "I2"), all_item_ids = c("I1", "I2", "I3"))
  expect_equal(result_i1i2$reach_pct, 100)
  expect_equal(result_i1i2$n_items, 2)

  # Act: portfolio of I3 only should reach 0%
  result_i3 <- calculate_portfolio_reach(appeal, item_ids = "I3", all_item_ids = c("I1", "I2", "I3"))
  expect_equal(result_i3$reach_pct, 0)
})

test_that("different threshold methods produce different appeal matrices", {
  td <- generate_test_data(n_resp = 50, n_items = 6)

  appeal_mean <- classify_appeal(td$individual_utils, method = "ABOVE_MEAN")
  appeal_zero <- classify_appeal(td$individual_utils, method = "ABOVE_ZERO")
  appeal_top3 <- classify_appeal(td$individual_utils, method = "TOP_3")

  # All should have same dimensions
  expect_equal(dim(appeal_mean), dim(appeal_zero))
  expect_equal(dim(appeal_mean), dim(appeal_top3))

  # But the actual appeal patterns should differ
  # TOP_3 always has exactly 3 per respondent
  expect_true(all(rowSums(appeal_top3) == 3))

  # ABOVE_MEAN will vary but average around n_items/2
  avg_mean <- mean(rowSums(appeal_mean))
  expect_true(avg_mean > 1 && avg_mean < td$n_items - 1)

  # ABOVE_ZERO depends on utility signs
  # The matrices should not be identical
  expect_false(identical(appeal_mean, appeal_top3))
})

test_that("weighted reach calculation differs from unweighted", {
  # Arrange: 4 respondents, 2 items
  # Resp 1 and 2 find I1 appealing, resp 3 and 4 find I2 appealing
  appeal <- matrix(
    c(TRUE, TRUE, FALSE, FALSE,  # I1
      FALSE, FALSE, TRUE, TRUE),  # I2
    nrow = 4, ncol = 2
  )
  colnames(appeal) <- c("I1", "I2")

  # Unweighted reach of I1: 2/4 = 0.5
  reach_unweighted <- calculate_reach(appeal, c(1), weights = NULL)
  expect_equal(reach_unweighted, 0.5)

  # Weighted reach with unequal weights: resp 1 and 2 have high weight
  weights <- c(3, 3, 1, 1)  # Total = 8
  reach_weighted <- calculate_reach(appeal, c(1), weights = weights)
  # Weighted: (3 + 3) / (3 + 3 + 1 + 1) = 6/8 = 0.75
  expect_equal(reach_weighted, 0.75)

  # They should differ
  expect_false(reach_unweighted == reach_weighted)
})

test_that("calculate_reach handles single-item portfolio correctly", {
  td <- generate_test_data()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  # Single item should return a valid proportion
  reach <- calculate_reach(appeal, c(1))
  expect_true(is.numeric(reach))
  expect_true(reach >= 0 && reach <= 1)
})

test_that("calculate_frequency increases with portfolio size", {
  skip_if(!exists("calculate_frequency", mode = "function"))

  td <- generate_test_data()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  freq_1 <- calculate_frequency(appeal, c(1))
  freq_2 <- calculate_frequency(appeal, c(1, 2))
  freq_3 <- calculate_frequency(appeal, c(1, 2, 3))

  # Frequency should be non-decreasing as portfolio grows
  expect_true(freq_2 >= freq_1)
  expect_true(freq_3 >= freq_2)
})
