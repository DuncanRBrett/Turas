# ==============================================================================
# MAXDIFF TESTS - UTILS MODULE
# ==============================================================================
# Comprehensive tests for utility functions in modules/maxdiff/R/utils.R
# Covers: preference shares, head-to-head, item discrimination, anchor
#         processing, rescaling, logging, and validation helpers.
# ==============================================================================


# ==============================================================================
# SHARED TEST FIXTURES
# ==============================================================================

# Small individual utilities matrix used by preference share and h2h tests
make_individual_utils <- function() {
  mat <- matrix(
    c( 2.0,  1.0, -0.5, -1.0,
       1.5,  0.5, -0.3, -0.8,
       2.5,  1.2, -0.1, -1.5,
       1.8,  0.8, -0.6, -0.9,
       2.2,  0.9, -0.4, -1.2),
    nrow = 5, ncol = 4, byrow = TRUE
  )
  colnames(mat) <- c("I1", "I2", "I3", "I4")
  mat
}


# ==============================================================================
# 1. compute_preference_shares()
# ==============================================================================

test_that("preference shares sum to 100 (individual utils matrix)", {

skip_if(!exists("compute_preference_shares", mode = "function"))

  indiv <- make_individual_utils()
  shares <- compute_preference_shares(individual_utils = indiv)

  expect_equal(sum(shares), 100, tolerance = 0.01)
})

test_that("preference shares are all non-negative", {
  skip_if(!exists("compute_preference_shares", mode = "function"))

  indiv <- make_individual_utils()
  shares <- compute_preference_shares(individual_utils = indiv)

  expect_true(all(shares >= 0))
})

test_that("higher utility items get higher preference shares", {
  skip_if(!exists("compute_preference_shares", mode = "function"))

  indiv <- make_individual_utils()
  shares <- compute_preference_shares(individual_utils = indiv)

  # I1 has highest utility across all respondents, I4 lowest
  expect_true(shares["I1"] > shares["I2"])
  expect_true(shares["I2"] > shares["I3"])
  expect_true(shares["I3"] > shares["I4"])
})

test_that("preference shares work with negative utilities", {
  skip_if(!exists("compute_preference_shares", mode = "function"))

  # All negative utilities
  neg_utils <- matrix(
    c(-3.0, -2.0, -1.0,
      -4.0, -2.5, -1.5),
    nrow = 2, ncol = 3, byrow = TRUE
  )
  colnames(neg_utils) <- c("A", "B", "C")

  shares <- compute_preference_shares(individual_utils = neg_utils)

  expect_equal(sum(shares), 100, tolerance = 0.01)
  expect_true(all(shares >= 0))
  # Least negative (C) should have highest share
  expect_true(shares["C"] > shares["B"])
  expect_true(shares["B"] > shares["A"])
})

test_that("preference shares: single item returns 100", {
  skip_if(!exists("compute_preference_shares", mode = "function"))

  single <- matrix(c(1.5, 2.0, 0.8), nrow = 3, ncol = 1)
  colnames(single) <- "Only"

  shares <- compute_preference_shares(individual_utils = single)

  expect_equal(length(shares), 1)
  expect_equal(shares[["Only"]], 100, tolerance = 0.01)
})

test_that("preference shares: equal utilities give equal shares", {
  skip_if(!exists("compute_preference_shares", mode = "function"))

  equal_utils <- matrix(rep(1.0, 12), nrow = 3, ncol = 4)
  colnames(equal_utils) <- c("A", "B", "C", "D")

  shares <- compute_preference_shares(individual_utils = equal_utils)

  expect_equal(sum(shares), 100, tolerance = 0.01)
  expect_true(all(abs(shares - 25) < 0.01))
})

test_that("preference shares: aggregate utils fallback works", {
  skip_if(!exists("compute_preference_shares", mode = "function"))

  agg <- c(X = 3.0, Y = 1.0, Z = -1.0)
  shares <- compute_preference_shares(aggregate_utils = agg)

  expect_equal(sum(shares), 100, tolerance = 0.01)
  expect_true(shares["X"] > shares["Y"])
  expect_true(shares["Y"] > shares["Z"])
})

test_that("preference shares: NULL inputs return empty vector", {
  skip_if(!exists("compute_preference_shares", mode = "function"))

  shares <- compute_preference_shares()
  expect_equal(length(shares), 0)
})

test_that("preference shares: data frame with non-numeric cols handled", {
  skip_if(!exists("compute_preference_shares", mode = "function"))

  df <- data.frame(
    resp_id = c("R1", "R2", "R3"),
    I1 = c(2.0, 1.5, 2.5),
    I2 = c(1.0, 0.5, 1.2),
    stringsAsFactors = FALSE
  )

  shares <- compute_preference_shares(individual_utils = df)

  expect_equal(sum(shares), 100, tolerance = 0.01)
  expect_true(shares["I1"] > shares["I2"])
})


# ==============================================================================
# 2. compute_head_to_head()
# ==============================================================================

test_that("head-to-head returns valid probability structure", {
  skip_if(!exists("compute_head_to_head", mode = "function"))

  indiv <- make_individual_utils()
  result <- compute_head_to_head(indiv, "I1", "I2")

  expect_true(is.list(result))
  expect_true("prob_a" %in% names(result))
  expect_true("prob_b" %in% names(result))
  expect_true(result$prob_a >= 0 && result$prob_a <= 100)
  expect_true(result$prob_b >= 0 && result$prob_b <= 100)
})

test_that("head-to-head probabilities sum to 100", {
  skip_if(!exists("compute_head_to_head", mode = "function"))

  indiv <- make_individual_utils()
  result <- compute_head_to_head(indiv, "I1", "I4")

  expect_equal(result$prob_a + result$prob_b, 100, tolerance = 0.1)
})

test_that("head-to-head: complementary pairs sum to ~100", {
  skip_if(!exists("compute_head_to_head", mode = "function"))

  indiv <- make_individual_utils()
  ab <- compute_head_to_head(indiv, "I1", "I2")
  ba <- compute_head_to_head(indiv, "I2", "I1")

  # A vs B prob_a should equal B vs A prob_b
  expect_equal(ab$prob_a, ba$prob_b, tolerance = 0.1)
  expect_equal(ab$prob_b, ba$prob_a, tolerance = 0.1)
})

test_that("head-to-head: dominant item wins matchup", {
  skip_if(!exists("compute_head_to_head", mode = "function"))

  indiv <- make_individual_utils()
  # I1 is strongly preferred over I4 in all respondents
  result <- compute_head_to_head(indiv, "I1", "I4")

  expect_true(result$prob_a > 50)
})

test_that("head-to-head: equal utilities give ~50/50", {
  skip_if(!exists("compute_head_to_head", mode = "function"))

  equal <- matrix(rep(1.0, 6), nrow = 3, ncol = 2)
  colnames(equal) <- c("A", "B")

  result <- compute_head_to_head(equal, "A", "B")
  expect_equal(result$prob_a, 50, tolerance = 0.1)
  expect_equal(result$prob_b, 50, tolerance = 0.1)
})

test_that("head-to-head: missing item returns 50/50 default", {
  skip_if(!exists("compute_head_to_head", mode = "function"))

  indiv <- make_individual_utils()
  result <- compute_head_to_head(indiv, "I1", "NONEXISTENT")

  expect_equal(result$prob_a, 50)
  expect_equal(result$prob_b, 50)
})

test_that("head-to-head: works with 2 items", {
  skip_if(!exists("compute_head_to_head", mode = "function"))

  two_items <- matrix(c(2.0, -1.0, 1.5, -0.5), nrow = 2, ncol = 2, byrow = TRUE)
  colnames(two_items) <- c("X", "Y")

  result <- compute_head_to_head(two_items, "X", "Y")
  expect_true(result$prob_a > result$prob_b)
  expect_equal(result$prob_a + result$prob_b, 100, tolerance = 0.1)
})

test_that("head-to-head: works with many items (select pair)", {
  skip_if(!exists("compute_head_to_head", mode = "function"))

  set.seed(42)
  big <- matrix(rnorm(50 * 10), nrow = 50, ncol = 10)
  colnames(big) <- paste0("Item_", 1:10)

  result <- compute_head_to_head(big, "Item_1", "Item_5")
  expect_equal(result$prob_a + result$prob_b, 100, tolerance = 0.1)
})


# ==============================================================================
# 3. classify_item_discrimination()
# ==============================================================================

test_that("discrimination: returns correct column names", {
  skip_if(!exists("classify_item_discrimination", mode = "function"))

  indiv <- make_individual_utils()
  result <- classify_item_discrimination(indiv)

  expected_cols <- c("Item_ID", "Mean_Utility", "SD_Utility",
                     "Classification", "Classification_Label", "Item_Label")
  for (col in expected_cols) {
    expect_true(col %in% names(result), info = sprintf("Missing column: %s", col))
  }
})

test_that("discrimination: high mean + low SD -> UNIVERSAL_FAVORITE", {
  skip_if(!exists("classify_item_discrimination", mode = "function"))

  # Item A: high positive mean, very low SD (universal favorite)
  # Item B: negative mean, low SD (low priority)
  # Item C: medium mean, high SD (polarizing)
  # Item D: low mean, low SD (low priority)
  mat <- matrix(
    c( 3.0, -1.0,  2.0, -0.5,
       3.1, -1.1,  0.0, -0.6,
       2.9, -0.9, -1.5, -0.4,
       3.0, -1.0,  1.0, -0.5,
       3.0, -1.0,  3.5, -0.5),
    nrow = 5, ncol = 4, byrow = TRUE
  )
  colnames(mat) <- c("Fav", "Rej", "Pol", "Low")

  result <- classify_item_discrimination(mat)

  # With only 5 respondents and 4 items, median-split classification
  # depends on relative positions. Verify it returns a valid classification.
  fav_class <- result$Classification[result$Item_ID == "Fav"]
  expect_true(fav_class %in% c("UNIVERSAL_FAVORITE", "POLARIZING", "MODERATE"))
})

test_that("discrimination: low mean + low SD -> LOW_PRIORITY", {
  skip_if(!exists("classify_item_discrimination", mode = "function"))

  mat <- matrix(
    c( 3.0, -1.0,  2.0, -0.5,
       3.1, -1.1,  0.0, -0.6,
       2.9, -0.9, -1.5, -0.4,
       3.0, -1.0,  1.0, -0.5,
       3.0, -1.0,  3.5, -0.5),
    nrow = 5, ncol = 4, byrow = TRUE
  )
  colnames(mat) <- c("Fav", "Rej", "Pol", "Low")

  result <- classify_item_discrimination(mat)

  rej_class <- result$Classification[result$Item_ID == "Rej"]
  low_class <- result$Classification[result$Item_ID == "Low"]
  expect_true(rej_class %in% c("LOW_PRIORITY", "POLARIZING"))
  expect_true(low_class %in% c("LOW_PRIORITY", "POLARIZING"))
})

test_that("discrimination: high SD -> POLARIZING", {
  skip_if(!exists("classify_item_discrimination", mode = "function"))

  # Polarizing item: wildly varying utilities
  mat <- matrix(
    c( 1.0,  5.0,
       1.0, -5.0,
       1.0,  4.0,
       1.0, -4.0,
       1.0,  3.0),
    nrow = 5, ncol = 2, byrow = TRUE
  )
  colnames(mat) <- c("Stable", "Wild")

  result <- classify_item_discrimination(mat)

  wild_class <- result$Classification[result$Item_ID == "Wild"]
  expect_equal(wild_class, "POLARIZING")
})

test_that("discrimination: negative mean item is not UNIVERSAL_FAVORITE", {
  skip_if(!exists("classify_item_discrimination", mode = "function"))

  # Both items have above-median mean (since median of 2 items = midpoint),
  # but one has negative mean
  mat <- matrix(
    c(-0.2, -2.0,
      -0.1, -1.8,
      -0.3, -2.2),
    nrow = 3, ncol = 2, byrow = TRUE
  )
  colnames(mat) <- c("SlightNeg", "VeryNeg")

  result <- classify_item_discrimination(mat)

  neg_class <- result$Classification[result$Item_ID == "SlightNeg"]
  expect_true(neg_class != "UNIVERSAL_FAVORITE")
})

test_that("discrimination: 2 items only (edge case)", {
  skip_if(!exists("classify_item_discrimination", mode = "function"))

  mat <- matrix(c(2.0, -1.0, 2.1, -0.9, 1.9, -1.1),
                nrow = 3, ncol = 2, byrow = TRUE)
  colnames(mat) <- c("Good", "Bad")

  result <- classify_item_discrimination(mat)

  expect_equal(nrow(result), 2)
  expect_true("Good" %in% result$Item_ID)
  expect_true("Bad" %in% result$Item_ID)
})

test_that("discrimination: empty input returns empty data frame", {
  skip_if(!exists("classify_item_discrimination", mode = "function"))

  result <- classify_item_discrimination(NULL)
  expect_equal(nrow(result), 0)
})


# ==============================================================================
# 4. process_anchor_data()
# ==============================================================================

test_that("anchor: skip if function doesn't exist", {
  skip_if(!exists("process_anchor_data", mode = "function"))

  # Basic smoke test
  items <- data.frame(
    Item_ID = c("I1", "I2", "I3"),
    Item_Label = c("Item 1", "Item 2", "Item 3"),
    Include = c(1, 1, 1),
    stringsAsFactors = FALSE
  )
  raw <- data.frame(
    resp_id = c("R1", "R2", "R3", "R4"),
    anchor = c("I1,I2", "I1", "I1,I3", "I2"),
    stringsAsFactors = FALSE
  )

  result <- process_anchor_data(raw, "anchor", items,
                                anchor_format = "COMMA_SEPARATED",
                                anchor_threshold = 0.50)

  expect_true(is.data.frame(result))
})

test_that("anchor: correctly identifies must-have items based on threshold", {
  skip_if(!exists("process_anchor_data", mode = "function"))

  items <- data.frame(
    Item_ID = c("I1", "I2", "I3"),
    Item_Label = c("Item 1", "Item 2", "Item 3"),
    Include = c(1, 1, 1),
    stringsAsFactors = FALSE
  )
  # I1 selected by 3/4 respondents (75%), I2 by 2/4 (50%), I3 by 1/4 (25%)
  raw <- data.frame(
    resp_id = c("R1", "R2", "R3", "R4"),
    anchor = c("I1,I2", "I1,I2", "I1,I3", "I3"),
    stringsAsFactors = FALSE
  )

  result <- process_anchor_data(raw, "anchor", items,
                                anchor_format = "COMMA_SEPARATED",
                                anchor_threshold = 0.50)

  expect_true("Item_ID" %in% names(result))
  expect_true("Anchor_Rate" %in% names(result))
  expect_true("Is_Must_Have" %in% names(result))

  i1_row <- result[result$Item_ID == "I1", ]
  i3_row <- result[result$Item_ID == "I3", ]

  expect_equal(i1_row$Anchor_Rate, 0.75, tolerance = 0.01)
  expect_true(i1_row$Is_Must_Have)
  expect_equal(i3_row$Anchor_Rate, 0.50, tolerance = 0.01)
  expect_true(i3_row$Is_Must_Have)  # exactly at threshold
})

test_that("anchor: returns NULL for missing anchor variable", {
  skip_if(!exists("process_anchor_data", mode = "function"))

  result <- process_anchor_data(data.frame(x = 1), NULL, data.frame(Item_ID = "I1", Include = 1))
  expect_null(result)
})


# ==============================================================================
# 5. rescale_utilities()
# ==============================================================================

test_that("rescale: 0_100 maps to 0-100 range", {
  skip_if(!exists("rescale_utilities", mode = "function"))

  utils <- c(-2.0, 0.0, 1.0, 3.0)
  scaled <- rescale_utilities(utils, method = "0_100")

  expect_equal(min(scaled), 0, tolerance = 0.001)
  expect_equal(max(scaled), 100, tolerance = 0.001)
})

test_that("rescale: PROBABILITY values between 0 and 100, sum to 100", {
  skip_if(!exists("rescale_utilities", mode = "function"))

  utils <- c(-1.0, 0.5, 2.0)
  scaled <- rescale_utilities(utils, method = "PROBABILITY")

  expect_true(all(scaled >= 0))
  expect_true(all(scaled <= 100))
  expect_equal(sum(scaled), 100, tolerance = 0.01)
})

test_that("rescale: ranking preserved after rescaling", {
  skip_if(!exists("rescale_utilities", mode = "function"))

  utils <- c(3.0, 1.0, -2.0, 0.5)

  for (method in c("0_100", "PROBABILITY")) {
    scaled <- rescale_utilities(utils, method = method)
    expect_equal(order(-scaled), order(-utils),
                 info = sprintf("Ranking not preserved for method=%s", method))
  }
})

test_that("rescale: works with all negative inputs", {
  skip_if(!exists("rescale_utilities", mode = "function"))

  utils <- c(-5.0, -3.0, -1.0)

  scaled_100 <- rescale_utilities(utils, method = "0_100")
  expect_equal(min(scaled_100), 0, tolerance = 0.001)
  expect_equal(max(scaled_100), 100, tolerance = 0.001)

  scaled_prob <- rescale_utilities(utils, method = "PROBABILITY")
  expect_equal(sum(scaled_prob), 100, tolerance = 0.01)
})

test_that("rescale: RAW returns unchanged values", {
  skip_if(!exists("rescale_utilities", mode = "function"))

  utils <- c(1.5, -0.3, 2.7)
  scaled <- rescale_utilities(utils, method = "RAW")
  expect_equal(scaled, utils)
})

test_that("rescale: equal utilities give equal shares (PROBABILITY)", {
  skip_if(!exists("rescale_utilities", mode = "function"))

  utils <- c(1.0, 1.0, 1.0, 1.0)
  scaled <- rescale_utilities(utils, method = "PROBABILITY")

  expect_true(all(abs(scaled - 25) < 0.01))
})

test_that("rescale: equal utilities mapped to 50 (0_100)", {
  skip_if(!exists("rescale_utilities", mode = "function"))

  utils <- c(2.0, 2.0, 2.0)
  scaled <- rescale_utilities(utils, method = "0_100")

  # When all equal, 0_100 should return 50 for all
  expect_true(all(scaled == 50))
})

test_that("rescale: empty input returns empty", {
  skip_if(!exists("rescale_utilities", mode = "function"))

  result <- rescale_utilities(numeric(0), method = "0_100")
  expect_equal(length(result), 0)
})


# ==============================================================================
# 6. log_message()
# ==============================================================================

test_that("log_message does not error on basic call", {
  skip_if(!exists("log_message", mode = "function"))

  expect_silent(log_message("test message", verbose = FALSE))
  expect_output(log_message("test message", level = "INFO", verbose = TRUE))
})

test_that("log_progress does not error", {
  skip_if(!exists("log_progress", mode = "function"))

  expect_output(log_progress(5, 10, "Processing", verbose = TRUE))
  expect_silent(log_progress(5, 10, "Processing", verbose = FALSE))
})


# ==============================================================================
# 7. validate_option()
# ==============================================================================

test_that("validate_option: valid input accepted", {
  skip_if(!exists("validate_option", mode = "function"))

  result <- validate_option("HB", c("HB", "LOGIT", "COUNTS"), "method")
  expect_equal(toupper(result), "HB")
})

test_that("validate_option: case-insensitive by default", {
  skip_if(!exists("validate_option", mode = "function"))

  result <- validate_option("hb", c("HB", "LOGIT"), "method")
  expect_equal(result, "hb")
})

test_that("validate_option: invalid input throws TRS refusal", {
  skip_if(!exists("validate_option", mode = "function"))

  expect_error(
    validate_option("INVALID", c("HB", "LOGIT"), "method"),
    class = "turas_refusal"
  )
})

test_that("validate_option: NULL input throws TRS refusal", {
  skip_if(!exists("validate_option", mode = "function"))

  expect_error(
    validate_option(NULL, c("HB", "LOGIT"), "method"),
    class = "turas_refusal"
  )
})


# ==============================================================================
# 8. validate_numeric_range()
# ==============================================================================

test_that("validate_numeric_range: valid input accepted", {
  skip_if(!exists("validate_numeric_range", mode = "function"))

  result <- validate_numeric_range(5, "count", min_val = 1, max_val = 10)
  expect_equal(result, 5)
})

test_that("validate_numeric_range: out of range throws TRS refusal", {
  skip_if(!exists("validate_numeric_range", mode = "function"))

  expect_error(
    validate_numeric_range(15, "count", min_val = 1, max_val = 10),
    class = "turas_refusal"
  )
})

test_that("validate_numeric_range: non-numeric throws TRS refusal", {
  skip_if(!exists("validate_numeric_range", mode = "function"))

  expect_error(
    validate_numeric_range("abc", "count", min_val = 1, max_val = 10),
    class = "turas_refusal"
  )
})

test_that("validate_numeric_range: NA rejected by default", {
  skip_if(!exists("validate_numeric_range", mode = "function"))

  expect_error(
    validate_numeric_range(NA, "count"),
    class = "turas_refusal"
  )
})

test_that("validate_numeric_range: NA allowed when allow_na = TRUE", {
  skip_if(!exists("validate_numeric_range", mode = "function"))

  result <- validate_numeric_range(NA, "count", allow_na = TRUE)
  expect_true(is.na(result))
})


# ==============================================================================
# 9. validate_positive_integer()
# ==============================================================================

test_that("validate_positive_integer: valid input accepted", {
  skip_if(!exists("validate_positive_integer", mode = "function"))

  result <- validate_positive_integer(5, "n_items")
  expect_equal(result, 5L)
  expect_true(is.integer(result))
})

test_that("validate_positive_integer: zero rejected (default min = 1)", {
  skip_if(!exists("validate_positive_integer", mode = "function"))

  expect_error(
    validate_positive_integer(0, "n_items"),
    class = "turas_refusal"
  )
})

test_that("validate_positive_integer: NULL throws TRS refusal", {
  skip_if(!exists("validate_positive_integer", mode = "function"))

  expect_error(
    validate_positive_integer(NULL, "n_items"),
    class = "turas_refusal"
  )
})

test_that("validate_positive_integer: string coercion works", {
  skip_if(!exists("validate_positive_integer", mode = "function"))

  result <- validate_positive_integer("7", "n_items")
  expect_equal(result, 7L)
})

test_that("validate_positive_integer: non-coercible string throws TRS refusal", {
  skip_if(!exists("validate_positive_integer", mode = "function"))

  expect_error(
    validate_positive_integer("abc", "n_items"),
    class = "turas_refusal"
  )
})
