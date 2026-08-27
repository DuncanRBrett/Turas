# ==============================================================================
# MAXDIFF TESTS - PREFERENCE SHARES & HEAD-TO-HEAD
# ==============================================================================

test_that("compute_preference_shares from individual utils sums to 100", {
  td <- generate_test_data()
  shares <- compute_preference_shares(individual_utils = td$individual_utils)

  expect_equal(length(shares), td$n_items)
  expect_equal(round(sum(shares), 0), 100)
  expect_true(all(shares > 0))
  expect_true(all(shares < 100))
})

test_that("compute_preference_shares from aggregate utils sums to 100", {
  agg <- c(A = 2.0, B = 1.0, C = -0.5, D = 0.0)
  shares <- compute_preference_shares(aggregate_utils = agg)

  expect_equal(length(shares), 4)
  expect_equal(round(sum(shares), 0), 100)
  # Higher utility should get higher share
  expect_true(shares["A"] > shares["B"])
  expect_true(shares["B"] > shares["C"])
})

test_that("compute_preference_shares returns empty for null input", {
  shares <- compute_preference_shares()
  expect_equal(length(shares), 0)
})

test_that("compute_preference_shares handles equal utilities", {
  agg <- c(A = 1.0, B = 1.0, C = 1.0)
  shares <- compute_preference_shares(aggregate_utils = agg)

  expect_equal(round(sum(shares), 0), 100)
  # All equal should give ~33.3% each
  expect_true(all(abs(shares - 100/3) < 0.1))
})

test_that("compute_head_to_head returns valid probabilities", {
  td <- generate_test_data()

  result <- compute_head_to_head(td$individual_utils, "I1", "I2")

  expect_true(result$prob_a >= 0 && result$prob_a <= 100)
  expect_true(result$prob_b >= 0 && result$prob_b <= 100)
  expect_equal(round(result$prob_a + result$prob_b, 0), 100)
})

test_that("compute_head_to_head returns 50/50 for identical items", {
  mat <- matrix(rep(c(1.0, 2.0), each = 10), nrow = 10, ncol = 2)
  colnames(mat) <- c("A", "B")

  result <- compute_head_to_head(mat, "A", "A")
  # Same item vs itself should be 50/50
  expect_equal(result$prob_a, 50)
})

test_that("compute_head_to_head returns 50/50 for null input", {
  result <- compute_head_to_head(NULL, "A", "B")
  expect_equal(result$prob_a, 50)
  expect_equal(result$prob_b, 50)
})

test_that("compute_head_to_head handles missing item IDs", {
  td <- generate_test_data()
  result <- compute_head_to_head(td$individual_utils, "MISSING", "I1")
  expect_equal(result$prob_a, 50)
})

# ------------------------------------------------------------------------------
# C2: a NUMERIC resp_id column must never become an item. Survey exports
# commonly carry numeric IDs (openxlsx reads them numeric); a value like
# 10001 dominates every per-respondent softmax, so "resp_id" shipped with
# ~100% share and every real item ~0%.
# ------------------------------------------------------------------------------

make_utils_with_numeric_id <- function(n = 20, seed = 7) {
  set.seed(seed)
  data.frame(
    resp_id = 10000 + seq_len(n),          # numeric, large — the poison
    A = rnorm(n, 1.0, 0.4),
    B = rnorm(n, 0.2, 0.4),
    C = rnorm(n, -1.2, 0.4),
    stringsAsFactors = FALSE
  )
}

test_that("C2: preference shares ignore a numeric resp_id column", {
  df <- make_utils_with_numeric_id()
  shares <- compute_preference_shares(individual_utils = df)

  expect_false("resp_id" %in% names(shares))
  expect_equal(sort(names(shares)), c("A", "B", "C"))
  expect_equal(round(sum(shares), 0), 100)
  # The real items carry real shares, not the ~0% the phantom left them.
  expect_true(shares["A"] > shares["C"])
  expect_true(shares["A"] > 10)
})

test_that("C2: head-to-head ignores a numeric resp_id column", {
  df <- make_utils_with_numeric_id()
  h2h <- compute_head_to_head(df, "A", "C")

  expect_equal(h2h$prob_a + h2h$prob_b, 100)
  expect_true(h2h$prob_a > 50)   # A's utilities dominate C's
})

test_that("C2: discrimination classification ignores a numeric resp_id column", {
  df <- make_utils_with_numeric_id()
  cls <- classify_item_discrimination(df)

  expect_false("resp_id" %in% cls$Item_ID)
  expect_equal(sort(cls$Item_ID), c("A", "B", "C"))
})

test_that("C2: TURF's first pick is a real item, not the respondent ID", {
  df <- make_utils_with_numeric_id()
  items <- data.frame(Item_ID = c("A", "B", "C"),
                      Item_Label = c("Item A", "Item B", "Item C"),
                      stringsAsFactors = FALSE)
  res <- run_turf_analysis(df, items, max_items = 2, verbose = FALSE)

  expect_equal(res$status, "PASS")
  picked <- as.character(res$incremental_table$Item_ID)
  expect_true(length(picked) > 0)
  expect_false(any(grepl("resp_id", picked)))
  # The strongest item leads.
  expect_equal(picked[1], "A")
})
