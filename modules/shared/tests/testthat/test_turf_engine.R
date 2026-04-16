# ==============================================================================
# SHARED TURF ENGINE TESTS
# ==============================================================================
# Comprehensive tests for the shared TURF engine extracted from maxdiff.
# Covers: classify_appeal, calculate_reach, calculate_frequency,
#         run_turf_analysis, calculate_portfolio_reach,
#         compute_reach_sensitivity, turf_from_binary

# --- Find project root ---
.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) {
      return(dir)
    }
    dir <- dirname(dir)
  }
  getwd()
}

TURAS_ROOT <- .find_turas_root_for_test()

# Source the shared TURF engine
turf_path <- file.path(TURAS_ROOT, "modules", "shared", "lib", "turf_engine.R")
if (file.exists(turf_path)) {
  source(turf_path, local = FALSE)
} else {
  stop("Cannot find turf_engine.R at: ", turf_path)
}

# --- Test data generators ---

#' Generate simple test utilities matrix
generate_turf_test_utils <- function(n_resp = 30, n_items = 6, seed = 123) {
  set.seed(seed)
  item_ids <- paste0("I", seq_len(n_items))
  true_utils <- rnorm(n_items, 0, 1)
  names(true_utils) <- item_ids

  indiv_utils <- matrix(0, nrow = n_resp, ncol = n_items)
  colnames(indiv_utils) <- item_ids
  for (r in seq_len(n_resp)) {
    indiv_utils[r, ] <- true_utils + rnorm(n_items, 0, 0.5)
  }

  items_df <- data.frame(
    Item_ID = item_ids,
    Item_Label = paste("Item", LETTERS[seq_len(n_items)]),
    stringsAsFactors = FALSE
  )

  list(
    individual_utils = indiv_utils,
    items = items_df,
    n_resp = n_resp,
    n_items = n_items,
    true_utils = true_utils
  )
}


#' Generate a binary CEP linkage matrix (simulates brand module data)
generate_cep_linkage <- function(n_resp = 200, n_ceps = 15, n_brands = 8,
                                  seed = 42) {
  set.seed(seed)

  # Each respondent-CEP pair has a brand linkage probability
  # Larger brands have higher linkage rates (Double Jeopardy)
  brand_ids <- paste0("B", seq_len(n_brands))
  cep_ids <- paste0("CEP", sprintf("%02d", seq_len(n_ceps)))

  # For TURF, we need a respondent × CEP matrix where cell = 1 if the

  # respondent linked ANY brand to that CEP (for mental reach)
  linkage_probs <- runif(n_ceps, 0.15, 0.60)
  cep_matrix <- matrix(0L, nrow = n_resp, ncol = n_ceps)
  colnames(cep_matrix) <- cep_ids

  for (j in seq_len(n_ceps)) {
    cep_matrix[, j] <- rbinom(n_resp, 1, linkage_probs[j])
  }

  cep_df <- data.frame(
    Item_ID = cep_ids,
    Item_Label = paste0("When I ", c(
      "want something quick", "need to feed the family",
      "want a healthy option", "am on a budget",
      "am entertaining guests", "want comfort food",
      "am in a hurry", "want something different",
      "am cooking from scratch", "want a treat",
      "need a weeknight meal", "want to impress",
      "am feeling lazy", "want something filling",
      "am planning ahead"
    )[seq_len(n_ceps)]),
    stringsAsFactors = FALSE
  )

  list(
    cep_matrix = cep_matrix,
    cep_df = cep_df,
    n_resp = n_resp,
    n_ceps = n_ceps,
    linkage_probs = linkage_probs
  )
}


# ==============================================================================
# SECTION 1: classify_appeal TESTS
# ==============================================================================

test_that("classify_appeal returns correct dimensions with ABOVE_MEAN", {
  td <- generate_turf_test_utils()
  appeal <- classify_appeal(td$individual_utils, method = "ABOVE_MEAN")

  expect_equal(nrow(appeal), td$n_resp)
  expect_equal(ncol(appeal), td$n_items)
  expect_true(is.logical(appeal))
  # Each respondent should have roughly half items above mean
  avg_appeal <- mean(rowSums(appeal))
  expect_true(avg_appeal > 1 && avg_appeal < td$n_items - 1)
})

test_that("classify_appeal TOP_3 selects exactly 3 per respondent", {
  td <- generate_turf_test_utils()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  row_counts <- rowSums(appeal)
  expect_true(all(row_counts == 3))
})

test_that("classify_appeal TOP_K with k=2 selects exactly 2", {
  td <- generate_turf_test_utils()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_K", k = 2)

  row_counts <- rowSums(appeal)
  expect_true(all(row_counts == 2))
})

test_that("classify_appeal TOP_K caps at n_items", {
  td <- generate_turf_test_utils(n_items = 4)
  appeal <- classify_appeal(td$individual_utils, method = "TOP_K", k = 10)

  row_counts <- rowSums(appeal)
  expect_true(all(row_counts == 4))
})

test_that("classify_appeal ABOVE_ZERO works correctly", {
  mat <- matrix(c(1, -1, 0.5, -0.5, 2, 0.1), nrow = 2, ncol = 3)
  colnames(mat) <- c("A", "B", "C")
  appeal <- classify_appeal(mat, method = "ABOVE_ZERO")

  expect_true(as.logical(appeal[1, 1]))    # 1 > 0
  expect_false(as.logical(appeal[2, 1]))   # -1 < 0
  expect_true(as.logical(appeal[1, 2]))    # 0.5 > 0
  expect_false(as.logical(appeal[2, 2]))   # -0.5 < 0
  expect_true(as.logical(appeal[1, 3]))    # 2 > 0
  expect_true(as.logical(appeal[2, 3]))    # 0.1 > 0
})

test_that("classify_appeal BINARY treats >0 as TRUE", {
  mat <- matrix(c(1, 0, 1, 0, 0, 1), nrow = 3, ncol = 2)
  colnames(mat) <- c("X", "Y")
  appeal <- classify_appeal(mat, method = "BINARY")

  expect_equal(as.logical(appeal[, 1]), c(TRUE, FALSE, TRUE))
  expect_equal(as.logical(appeal[, 2]), c(FALSE, FALSE, TRUE))
})

test_that("classify_appeal handles NA values", {
  mat <- matrix(c(1, NA, 0.5, 2, 1, NA), nrow = 3, ncol = 2)
  colnames(mat) <- c("A", "B")

  appeal_mean <- classify_appeal(mat, method = "ABOVE_MEAN")
  expect_false(any(is.na(appeal_mean)))

  appeal_zero <- classify_appeal(mat, method = "ABOVE_ZERO")
  expect_false(any(is.na(appeal_zero)))
})

test_that("classify_appeal handles empty matrix", {
  mat <- matrix(numeric(0), nrow = 0, ncol = 0)
  appeal <- classify_appeal(mat, method = "ABOVE_MEAN")

  expect_equal(nrow(appeal), 0)
  expect_equal(ncol(appeal), 0)
})

test_that("classify_appeal handles NULL input", {
  appeal <- classify_appeal(NULL)
  expect_equal(nrow(appeal), 0)
})

test_that("classify_appeal warns on unknown method", {
  td <- generate_turf_test_utils()
  expect_warning(
    classify_appeal(td$individual_utils, method = "NONSENSE"),
    "Unknown threshold method"
  )
})

test_that("classify_appeal preserves column names", {
  mat <- matrix(1:6, nrow = 2, ncol = 3)
  colnames(mat) <- c("Alpha", "Beta", "Gamma")

  appeal <- classify_appeal(mat, method = "ABOVE_MEAN")
  expect_equal(colnames(appeal), c("Alpha", "Beta", "Gamma"))
})


# ==============================================================================
# SECTION 2: calculate_reach TESTS
# ==============================================================================

test_that("calculate_reach returns 0 for empty portfolio", {
  td <- generate_turf_test_utils()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  reach <- calculate_reach(appeal, integer(0))
  expect_equal(reach, 0)
})

test_that("calculate_reach returns value between 0 and 1", {
  td <- generate_turf_test_utils()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  reach <- calculate_reach(appeal, c(1, 2))
  expect_true(reach >= 0 && reach <= 1)
})

test_that("calculate_reach for known data", {
  appeal <- matrix(
    c(TRUE, FALSE, TRUE,
      FALSE, TRUE, TRUE,
      FALSE, FALSE, FALSE),
    nrow = 3, ncol = 3
  )
  colnames(appeal) <- c("I1", "I2", "I3")

  # I1 only: 2 of 3 reached
  expect_equal(calculate_reach(appeal, 1), 2/3)

  # I1 + I2: all 3 reached
  expect_equal(calculate_reach(appeal, c(1, 2)), 1)

  # I3 only: 0 reached
  expect_equal(calculate_reach(appeal, 3), 0)
})

test_that("calculate_reach handles single-item portfolio", {
  td <- generate_turf_test_utils()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  reach <- calculate_reach(appeal, c(1))
  expect_true(is.numeric(reach))
  expect_true(reach >= 0 && reach <= 1)
})

test_that("weighted reach calculation differs from unweighted", {
  appeal <- matrix(
    c(TRUE, TRUE, FALSE, FALSE,
      FALSE, FALSE, TRUE, TRUE),
    nrow = 4, ncol = 2
  )
  colnames(appeal) <- c("I1", "I2")

  # Unweighted reach of I1: 2/4 = 0.5
  reach_unweighted <- calculate_reach(appeal, c(1), weights = NULL)
  expect_equal(reach_unweighted, 0.5)

  # Weighted: resp 1,2 have high weight
  weights <- c(3, 3, 1, 1)
  reach_weighted <- calculate_reach(appeal, c(1), weights = weights)
  expect_equal(reach_weighted, 6/8)

  expect_false(reach_unweighted == reach_weighted)
})


# ==============================================================================
# SECTION 3: calculate_frequency TESTS
# ==============================================================================

test_that("calculate_frequency returns 0 for empty portfolio", {
  td <- generate_turf_test_utils()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  freq <- calculate_frequency(appeal, integer(0))
  expect_equal(freq, 0)
})

test_that("calculate_frequency increases with portfolio size", {
  td <- generate_turf_test_utils()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  freq_1 <- calculate_frequency(appeal, c(1))
  freq_2 <- calculate_frequency(appeal, c(1, 2))
  freq_3 <- calculate_frequency(appeal, c(1, 2, 3))

  expect_true(freq_2 >= freq_1)
  expect_true(freq_3 >= freq_2)
})

test_that("calculate_frequency for known data", {
  appeal <- matrix(
    c(TRUE, FALSE, TRUE,
      TRUE, TRUE, FALSE),
    nrow = 3, ncol = 2
  )
  colnames(appeal) <- c("A", "B")

  # Portfolio A+B: resp 1 has 2, resp 2 has 1, resp 3 has 1 -> mean 4/3
  freq <- calculate_frequency(appeal, c(1, 2))
  expect_equal(freq, 4/3)
})


# ==============================================================================
# SECTION 4: run_turf_analysis TESTS
# ==============================================================================

test_that("run_turf_analysis returns correct structure", {
  td <- generate_turf_test_utils()

  result <- run_turf_analysis(
    individual_scores = td$individual_utils,
    items = td$items,
    max_items = 4,
    threshold_method = "ABOVE_MEAN",
    verbose = FALSE
  )

  expect_equal(result$status, "PASS")
  expect_true(is.data.frame(result$incremental_table))
  expect_true(nrow(result$incremental_table) > 0)
  expect_true(nrow(result$incremental_table) <= 4)
  expect_true(all(c("Step", "Item_ID", "Item_Label", "Reach_Pct",
                     "Incremental_Pct", "Frequency") %in%
                    names(result$incremental_table)))

  # Reach should be monotonically increasing
  reaches <- result$incremental_table$Reach_Pct
  expect_true(all(diff(reaches) >= 0))

  # Metadata
  expect_equal(result$n_respondents, td$n_resp)
  expect_equal(result$n_items, td$n_items)
  expect_equal(result$threshold_method, "ABOVE_MEAN")
  expect_true(is.matrix(result$appeal_matrix))
})

test_that("run_turf_analysis refuses when no scores", {
  result <- run_turf_analysis(NULL, NULL, verbose = FALSE)
  expect_equal(result$status, "REFUSED")
})

test_that("run_turf_analysis refuses on empty matrix", {
  empty <- matrix(numeric(0), nrow = 0, ncol = 0)
  result <- run_turf_analysis(empty, NULL, verbose = FALSE)
  expect_equal(result$status, "REFUSED")
})

test_that("run_turf_analysis reaches 100% when all find first item appealing", {
  utils_mat <- matrix(c(5, 5, 5, -1, -1, -1), nrow = 3, ncol = 2)
  colnames(utils_mat) <- c("I1", "I2")
  items <- data.frame(Item_ID = c("I1", "I2"),
                      Item_Label = c("A", "B"),
                      stringsAsFactors = FALSE)

  result <- run_turf_analysis(utils_mat, items, max_items = 2,
                              threshold_method = "ABOVE_ZERO", verbose = FALSE)

  expect_equal(result$status, "PASS")
  expect_equal(result$incremental_table$Reach_Pct[1], 100)
})

test_that("greedy selection stops at 100% reach", {
  set.seed(55)
  n_resp <- 30
  utils_mat <- matrix(0, nrow = n_resp, ncol = 3)
  colnames(utils_mat) <- c("I1", "I2", "I3")

  for (i in seq_len(n_resp)) {
    winner <- (i %% 3) + 1
    utils_mat[i, ] <- c(-2, -2, -2)
    utils_mat[i, winner] <- 5
  }

  items <- data.frame(Item_ID = c("I1", "I2", "I3"),
                      Item_Label = c("A", "B", "C"),
                      stringsAsFactors = FALSE)

  result <- run_turf_analysis(utils_mat, items, max_items = 3,
                              threshold_method = "TOP_K", threshold_k = 1,
                              verbose = FALSE)

  expect_equal(result$status, "PASS")
  final_reach <- tail(result$incremental_table$Reach_Pct, 1)
  expect_equal(final_reach, 100)
})

test_that("run_turf_analysis includes reach curve starting at 0", {
  td <- generate_turf_test_utils()
  result <- run_turf_analysis(td$individual_utils, td$items,
                              max_items = 3, verbose = FALSE)

  expect_true(is.data.frame(result$reach_curve))
  expect_equal(result$reach_curve$Portfolio_Size[1], 0)
  expect_equal(result$reach_curve$Reach_Pct[1], 0)
})

test_that("run_turf_analysis caps max_items at n_items", {
  td <- generate_turf_test_utils(n_items = 4)
  result <- run_turf_analysis(td$individual_utils, td$items,
                              max_items = 100, verbose = FALSE)

  expect_true(nrow(result$incremental_table) <= 4)
  expect_equal(result$max_items_evaluated, 4)
})

test_that("run_turf_analysis handles data frame with non-numeric columns", {
  td <- generate_turf_test_utils()
  df <- as.data.frame(td$individual_utils)
  df$resp_id <- paste0("R", seq_len(nrow(df)))

  result <- run_turf_analysis(df, td$items, max_items = 3, verbose = FALSE)
  expect_equal(result$status, "PASS")
  expect_equal(result$n_items, td$n_items)
})

test_that("run_turf_analysis works with custom id_col and label_col", {
  td <- generate_turf_test_utils()
  cep_items <- data.frame(
    CEP_Code = td$items$Item_ID,
    CEP_Text = paste("When I", tolower(td$items$Item_Label)),
    stringsAsFactors = FALSE
  )

  result <- run_turf_analysis(td$individual_utils, cep_items,
                              max_items = 3, verbose = FALSE,
                              id_col = "CEP_Code", label_col = "CEP_Text")

  expect_equal(result$status, "PASS")
  # Labels should come from CEP_Text column
  expect_true(grepl("^When I", result$incremental_table$Item_Label[1]))
})

test_that("run_turf_analysis works with weights", {
  td <- generate_turf_test_utils()
  weights <- runif(td$n_resp, 0.5, 2.0)

  result_unw <- run_turf_analysis(td$individual_utils, td$items,
                                  max_items = 3, verbose = FALSE)
  result_wtd <- run_turf_analysis(td$individual_utils, td$items,
                                  max_items = 3, weights = weights,
                                  verbose = FALSE)

  expect_equal(result_unw$status, "PASS")
  expect_equal(result_wtd$status, "PASS")
  # Weighted and unweighted may differ
  # (Not guaranteed to differ with random weights, but structure should be same)
  expect_equal(ncol(result_unw$incremental_table), ncol(result_wtd$incremental_table))
})


# ==============================================================================
# SECTION 5: calculate_portfolio_reach TESTS
# ==============================================================================

test_that("calculate_portfolio_reach works for custom portfolio", {
  td <- generate_turf_test_utils()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  result <- calculate_portfolio_reach(
    appeal,
    item_ids = c("I1", "I2"),
    all_item_ids = colnames(appeal)
  )

  expect_true(result$reach_pct >= 0 && result$reach_pct <= 100)
  expect_equal(result$n_items, 2)
})

test_that("calculate_portfolio_reach returns 0 for non-existent items", {
  td <- generate_turf_test_utils()
  appeal <- classify_appeal(td$individual_utils, method = "TOP_3")

  result <- calculate_portfolio_reach(
    appeal,
    item_ids = c("NONEXISTENT_1", "NONEXISTENT_2"),
    all_item_ids = colnames(appeal)
  )

  expect_equal(result$reach_pct, 0)
  expect_equal(result$n_items, 0)
})

test_that("calculate_portfolio_reach exact values for known data", {
  appeal <- matrix(
    c(TRUE, FALSE, TRUE,
      FALSE, TRUE, TRUE,
      FALSE, FALSE, FALSE),
    nrow = 3, ncol = 3
  )
  colnames(appeal) <- c("I1", "I2", "I3")

  result_i1 <- calculate_portfolio_reach(appeal, item_ids = "I1")
  expect_equal(result_i1$reach_pct, round(2/3 * 100, 1))
  expect_equal(result_i1$n_items, 1)

  result_i1i2 <- calculate_portfolio_reach(appeal, item_ids = c("I1", "I2"))
  expect_equal(result_i1i2$reach_pct, 100)
  expect_equal(result_i1i2$n_items, 2)

  result_i3 <- calculate_portfolio_reach(appeal, item_ids = "I3")
  expect_equal(result_i3$reach_pct, 0)
})


# ==============================================================================
# SECTION 6: compute_reach_sensitivity TESTS
# ==============================================================================

test_that("compute_reach_sensitivity returns correct structure", {
  td <- generate_turf_test_utils()

  result <- compute_reach_sensitivity(
    td$individual_utils, td$items,
    portfolio_sizes = 1:3,
    methods = c("ABOVE_MEAN", "TOP_3"),
    verbose = FALSE
  )

  expect_true(is.data.frame(result))
  expect_true(all(c("Portfolio_Size", "Method", "Reach_Pct") %in% names(result)))
  expect_equal(nrow(result), 3 * 2)  # 3 sizes x 2 methods
})

test_that("compute_reach_sensitivity handles empty input", {
  result <- compute_reach_sensitivity(NULL, NULL)
  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 0)
})

test_that("different threshold methods produce different results", {
  td <- generate_turf_test_utils(n_resp = 50, n_items = 6)

  appeal_mean <- classify_appeal(td$individual_utils, method = "ABOVE_MEAN")
  appeal_zero <- classify_appeal(td$individual_utils, method = "ABOVE_ZERO")
  appeal_top3 <- classify_appeal(td$individual_utils, method = "TOP_3")

  expect_equal(dim(appeal_mean), dim(appeal_zero))
  expect_equal(dim(appeal_mean), dim(appeal_top3))
  expect_true(all(rowSums(appeal_top3) == 3))
  expect_false(identical(appeal_mean, appeal_top3))
})


# ==============================================================================
# SECTION 7: BINARY MATRIX / CEP TURF TESTS
# ==============================================================================

test_that("turf_from_binary works with CEP linkage matrix", {
  td <- generate_cep_linkage(n_resp = 100, n_ceps = 10)

  result <- turf_from_binary(
    binary_matrix = td$cep_matrix,
    items = td$cep_df,
    max_items = 5,
    verbose = FALSE
  )

  expect_equal(result$status, "PASS")
  expect_true(nrow(result$incremental_table) > 0)
  expect_true(nrow(result$incremental_table) <= 5)

  # Reach should be monotonically increasing
  reaches <- result$incremental_table$Reach_Pct
  expect_true(all(diff(reaches) >= 0))

  # First CEP should be the one with highest individual reach
  # (highest linkage probability)
  first_cep <- result$incremental_table$Item_ID[1]
  individual_reaches <- colMeans(td$cep_matrix)
  expected_first <- names(which.max(individual_reaches))
  expect_equal(first_cep, expected_first)
})

test_that("turf_from_binary handles all-zero matrix", {
  zero_mat <- matrix(0L, nrow = 50, ncol = 5)
  colnames(zero_mat) <- paste0("C", 1:5)
  items <- data.frame(Item_ID = paste0("C", 1:5),
                      Item_Label = paste("CEP", 1:5),
                      stringsAsFactors = FALSE)

  result <- turf_from_binary(zero_mat, items, max_items = 3, verbose = FALSE)
  expect_equal(result$status, "PASS")
  # All reach should be 0
  expect_true(all(result$incremental_table$Reach_Pct == 0))
})

test_that("turf_from_binary handles all-one matrix", {
  one_mat <- matrix(1L, nrow = 50, ncol = 5)
  colnames(one_mat) <- paste0("C", 1:5)
  items <- data.frame(Item_ID = paste0("C", 1:5),
                      Item_Label = paste("CEP", 1:5),
                      stringsAsFactors = FALSE)

  result <- turf_from_binary(one_mat, items, max_items = 3, verbose = FALSE)
  expect_equal(result$status, "PASS")
  # First item should reach 100%
  expect_equal(result$incremental_table$Reach_Pct[1], 100)
})

test_that("CEP TURF with weighted respondents", {
  td <- generate_cep_linkage(n_resp = 100, n_ceps = 8)
  weights <- runif(100, 0.5, 2.0)

  result_unw <- turf_from_binary(td$cep_matrix, td$cep_df,
                                 max_items = 5, verbose = FALSE)
  result_wtd <- turf_from_binary(td$cep_matrix, td$cep_df,
                                 max_items = 5, weights = weights,
                                 verbose = FALSE)

  expect_equal(result_unw$status, "PASS")
  expect_equal(result_wtd$status, "PASS")
})

test_that("run_turf_analysis with BINARY method matches turf_from_binary", {
  td <- generate_cep_linkage(n_resp = 50, n_ceps = 6)

  result_direct <- run_turf_analysis(
    td$cep_matrix, td$cep_df,
    max_items = 4, threshold_method = "BINARY", verbose = FALSE
  )
  result_wrapper <- turf_from_binary(
    td$cep_matrix, td$cep_df,
    max_items = 4, verbose = FALSE
  )

  expect_equal(result_direct$incremental_table, result_wrapper$incremental_table)
  expect_equal(result_direct$reach_curve, result_wrapper$reach_curve)
})


# ==============================================================================
# SECTION 8: REGRESSION / GOLDEN FILE TESTS
# ==============================================================================
# These tests use fixed seeds and exact expected values to catch
# any unintended behavioural changes.

test_that("TURF regression: fixed seed produces deterministic results", {
  set.seed(999)
  n <- 50
  mat <- matrix(rnorm(n * 5), nrow = n, ncol = 5)
  colnames(mat) <- paste0("X", 1:5)
  items <- data.frame(Item_ID = paste0("X", 1:5),
                      Item_Label = paste("Item", 1:5),
                      stringsAsFactors = FALSE)

  result1 <- run_turf_analysis(mat, items, max_items = 5,
                               threshold_method = "ABOVE_MEAN", verbose = FALSE)

  # Run again with same data (no seed reset needed - data is deterministic)
  result2 <- run_turf_analysis(mat, items, max_items = 5,
                               threshold_method = "ABOVE_MEAN", verbose = FALSE)

  expect_identical(result1$incremental_table, result2$incremental_table)
  expect_identical(result1$reach_curve, result2$reach_curve)
})

test_that("TURF regression: known 3x3 matrix exact results", {
  # Deterministic: 3 respondents, 3 items, clear appeal pattern
  mat <- matrix(
    c(5, -1, -1,   # Resp 1: only I1 appealing (ABOVE_ZERO)
      -1, 5, -1,   # Resp 2: only I2 appealing
      -1, -1, 5),  # Resp 3: only I3 appealing
    nrow = 3, ncol = 3, byrow = TRUE
  )
  colnames(mat) <- c("I1", "I2", "I3")
  items <- data.frame(Item_ID = c("I1", "I2", "I3"),
                      Item_Label = c("A", "B", "C"),
                      stringsAsFactors = FALSE)

  result <- run_turf_analysis(mat, items, max_items = 3,
                              threshold_method = "ABOVE_ZERO", verbose = FALSE)

  # Each item reaches exactly 1/3
  expect_equal(result$incremental_table$Reach_Pct[1], round(1/3 * 100, 1))
  # After 2 items: 2/3
  expect_equal(result$incremental_table$Reach_Pct[2], round(2/3 * 100, 1))
  # After 3 items: 100%
  expect_equal(result$incremental_table$Reach_Pct[3], 100)
})


# ==============================================================================
# SECTION 9: EDGE CASE TESTS
# ==============================================================================

test_that("TURF handles single respondent", {
  mat <- matrix(c(1, -1, 2), nrow = 1, ncol = 3)
  colnames(mat) <- c("A", "B", "C")
  items <- data.frame(Item_ID = c("A", "B", "C"),
                      Item_Label = c("A", "B", "C"),
                      stringsAsFactors = FALSE)

  result <- run_turf_analysis(mat, items, max_items = 3,
                              threshold_method = "ABOVE_ZERO", verbose = FALSE)
  expect_equal(result$status, "PASS")
  expect_equal(result$n_respondents, 1)
  # First item should reach 100% (only one respondent)
  expect_equal(result$incremental_table$Reach_Pct[1], 100)
})

test_that("TURF handles single item", {
  mat <- matrix(c(1, 2, 3), nrow = 3, ncol = 1)
  colnames(mat) <- "ONLY"
  items <- data.frame(Item_ID = "ONLY", Item_Label = "Only Item",
                      stringsAsFactors = FALSE)

  result <- run_turf_analysis(mat, items, max_items = 1,
                              threshold_method = "ABOVE_ZERO", verbose = FALSE)
  expect_equal(result$status, "PASS")
  expect_equal(nrow(result$incremental_table), 1)
  expect_equal(result$incremental_table$Reach_Pct[1], 100)
})

test_that("TURF with NULL items still works (uses IDs from column names)", {
  td <- generate_turf_test_utils()
  result <- run_turf_analysis(td$individual_utils, items = NULL,
                              max_items = 3, verbose = FALSE)
  expect_equal(result$status, "PASS")
  # Labels should fall back to column names
  expect_true(grepl("^I", result$incremental_table$Item_Label[1]))
})

test_that("TURF handles large matrix efficiently", {
  skip_on_cran()
  set.seed(42)
  big_mat <- matrix(rnorm(500 * 20), nrow = 500, ncol = 20)
  colnames(big_mat) <- paste0("I", 1:20)
  items <- data.frame(Item_ID = paste0("I", 1:20),
                      Item_Label = paste("Item", 1:20),
                      stringsAsFactors = FALSE)

  time_start <- proc.time()["elapsed"]
  result <- run_turf_analysis(big_mat, items, max_items = 10, verbose = FALSE)
  elapsed <- proc.time()["elapsed"] - time_start

  expect_equal(result$status, "PASS")
  expect_true(elapsed < 10)  # Should complete well under 10 seconds
})
