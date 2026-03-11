# ==============================================================================
# MAXDIFF TESTS - EDGE CASES
# ==============================================================================

test_that("rescale_utilities handles single item", {
  result <- rescale_utilities(c(5), "0_100")
  expect_equal(result, 50)
})

test_that("rescale_utilities handles empty vector", {
  result <- rescale_utilities(numeric(0), "0_100")
  expect_equal(length(result), 0)
})

test_that("compute_preference_shares handles single item", {
  shares <- compute_preference_shares(aggregate_utils = c(A = 1.0))
  expect_equal(round(shares[["A"]]), 100)
})

test_that("classify_appeal handles 1-item matrix", {
  mat <- matrix(c(1, 2, 3), ncol = 1)
  colnames(mat) <- "A"
  result <- classify_appeal(mat, method = "ABOVE_ZERO")
  expect_equal(ncol(result), 1)
  expect_true(all(result))
})

test_that("classify_appeal handles empty matrix", {
  mat <- matrix(numeric(0), nrow = 0, ncol = 0)
  result <- classify_appeal(mat)
  expect_equal(nrow(result), 0)
})

test_that("classify_item_discrimination handles 2 items", {
  mat <- matrix(c(1, 2, 3, -1, -2, -3), nrow = 3, ncol = 2)
  colnames(mat) <- c("A", "B")

  result <- classify_item_discrimination(mat)
  expect_equal(nrow(result), 2)
  expect_true("Classification" %in% names(result))
})

test_that("classify_item_discrimination handles NULL", {
  result <- classify_item_discrimination(NULL)
  expect_equal(nrow(result), 0)
})

test_that("process_anchor_data returns NULL for missing variable", {
  result <- process_anchor_data(
    raw_data = data.frame(ID = 1:5),
    anchor_variable = NULL,
    items = data.frame(Item_ID = "A", Include = 1)
  )
  expect_null(result)
})

test_that("process_anchor_data handles COMMA_SEPARATED format", {
  raw <- data.frame(
    ID = 1:5,
    Anchor = c("A,B", "A", "B,C", "", "A,C"),
    stringsAsFactors = FALSE
  )
  items <- data.frame(Item_ID = c("A", "B", "C"), Include = c(1, 1, 1))

  result <- process_anchor_data(raw, "Anchor", items, anchor_format = "COMMA_SEPARATED")

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 3)
  expect_true("Anchor_Rate" %in% names(result))
  # A appears in 3/5 responses
  a_rate <- result$Anchor_Rate[result$Item_ID == "A"]
  expect_equal(a_rate, 0.6)
})

test_that("rank_utilities handles empty input", {
  result <- rank_utilities(numeric(0))
  expect_equal(length(result), 0)
})

test_that("calculate_deff returns 1 for equal weights", {
  deff <- calculate_deff(rep(1, 50))
  expect_equal(deff, 1)
})

test_that("safe_integer converts correctly", {
  expect_equal(safe_integer("5"), 5L)
  expect_equal(safe_integer(3.7), 3L)
  expect_equal(safe_integer("abc", default = 0), 0L)
  expect_equal(safe_integer(NULL, default = 1), 1L)
})
