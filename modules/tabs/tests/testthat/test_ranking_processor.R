# ==============================================================================
# TABS MODULE - RANKING PROCESSOR TESTS
# ==============================================================================
#
# Tests for ranking question processing across three submodules:
#   ranking_validation.R  — validate_ranking_matrix(), validate_ranking_question()
#   ranking_metrics.R     — calculate_percent_ranked_first(),
#                           calculate_percent_top_n(), calculate_mean_rank()
#   ranking_crosstabs.R   — format_ranking_value(), get_banner_subset_and_weights(),
#                           create_ranking_rows_for_item()
#   ranking.R             — normalize_rank_direction()
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_ranking_processor.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))

# Set .tabs_lib_dir for tabs_source()
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())

# Source weighting (needed for effective-n, weighted means)
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))

# Source ranking module (loads all three submodules via tabs_source)
source(file.path(turas_root, "modules/tabs/lib/ranking.R"))


# ==============================================================================
# TEST DATA HELPERS
# ==============================================================================

#' Create a known ranking matrix for deterministic testing.
#' 10 respondents ranking 4 items (BrandA-D).
#'
#' Known facts:
#'   BrandA ranked 1st by respondents 1,3,5,7,10 -> 5/10 = 50%
#'   BrandB ranked 1st by respondents 2,4,8,9    -> 4/10 = 40%
#'   BrandC ranked 1st by respondent 6           -> 1/10 = 10%
#'   BrandD ranked 1st by nobody                 -> 0/10 =  0%
#'   BrandA mean rank = (1+2+1+3+1+2+1+4+2+1)/10 = 1.8
#'   BrandB mean rank = (2+1+3+1+2+3+2+1+1+3)/10 = 1.9
make_ranking_matrix <- function() {
  m <- matrix(c(
    1, 2, 3, 4,
    2, 1, 3, 4,
    1, 3, 2, 4,
    3, 1, 2, 4,
    1, 2, 4, 3,
    2, 3, 1, 4,
    1, 2, 3, 4,
    4, 1, 2, 3,
    2, 1, 3, 4,
    1, 3, 2, 4
  ), nrow = 10, ncol = 4, byrow = TRUE)
  colnames(m) <- c("BrandA", "BrandB", "BrandC", "BrandD")
  m
}

#' Create a ranking matrix with ties (respondent 1 ranks both A and B as 1)
make_tied_ranking_matrix <- function() {
  m <- make_ranking_matrix()
  m[1, ] <- c(1, 1, 3, 4)
  m
}

#' Create a ranking matrix with gaps (respondent 1 skips rank 2)
make_gapped_ranking_matrix <- function() {
  m <- make_ranking_matrix()
  m[1, ] <- c(1, 3, 3, 4)
  m
}

#' Create a ranking matrix with NAs (partial completion)
make_incomplete_ranking_matrix <- function() {
  m <- make_ranking_matrix()
  m[1, ] <- c(1, NA, NA, NA)
  m[2, ] <- c(NA, NA, NA, NA)
  m
}

#' Create a ranking matrix with out-of-range values
make_oor_ranking_matrix <- function() {
  m <- make_ranking_matrix()
  m[1, 1] <- 0
  m[2, 2] <- 5
  m
}

#' Create a single-respondent ranking matrix
make_single_respondent_matrix <- function() {
  m <- matrix(c(1, 2, 3, 4), nrow = 1, ncol = 4)
  colnames(m) <- c("BrandA", "BrandB", "BrandC", "BrandD")
  m
}

#' Create a ranking matrix with an all-NA column
make_all_na_column_matrix <- function() {
  m <- make_ranking_matrix()
  m[, "BrandD"] <- NA
  m
}


# ==============================================================================
# 1. validate_ranking_matrix
# ==============================================================================

context("validate_ranking_matrix")

test_that("valid matrix passes validation", {
  m <- make_ranking_matrix()
  result <- validate_ranking_matrix(m, num_positions = 4)

  expect_true(result$valid)
  expect_false(result$has_issues)
  expect_equal(result$n_respondents, 10)
  expect_equal(result$n_items, 4)
  expect_equal(result$pct_complete, 100)
  expect_equal(result$n_ties, 0)
  expect_equal(result$n_gaps, 0)
  expect_equal(result$out_of_range, 0)
  expect_equal(result$non_integer, 0)
})

test_that("detects out-of-range values (rank 0 and rank > num_positions)", {
  m <- make_oor_ranking_matrix()
  result <- validate_ranking_matrix(m, num_positions = 4)

  expect_true(result$has_issues)
  expect_equal(result$out_of_range, 2)
  expect_false(result$valid)
})

test_that("detects tied ranks within respondents", {
  m <- make_tied_ranking_matrix()
  # Use a low tie threshold so even 1/10 = 10% exceeds it
  result <- validate_ranking_matrix(m, num_positions = 4, tie_threshold_pct = 5)

  expect_equal(result$n_ties, 1)
  expect_equal(result$pct_ties, 10)
  expect_true(result$has_issues)
})

test_that("detects gaps in rank sequences", {
  m <- make_gapped_ranking_matrix()
  result <- validate_ranking_matrix(m, num_positions = 4, gap_threshold_pct = 5)

  expect_true(result$n_gaps >= 1)
  expect_true(result$has_issues)
})

test_that("reports completeness for matrices with NAs", {
  m <- make_incomplete_ranking_matrix()
  result <- validate_ranking_matrix(m, num_positions = 4)

  # 10*4 = 40 cells total; 7 NAs => 33/40 = 82.5% complete
  expect_true(result$pct_complete < 100)
  expect_equal(result$pct_complete, 82.5)
})

test_that("refuses non-matrix input", {
  expect_error(
    validate_ranking_matrix("not a matrix", num_positions = 4),
    class = "turas_refusal"
  )
})

test_that("refuses invalid num_positions", {
  m <- make_ranking_matrix()
  expect_error(
    validate_ranking_matrix(m, num_positions = -1),
    class = "turas_refusal"
  )
  expect_error(
    validate_ranking_matrix(m, num_positions = c(1, 2)),
    class = "turas_refusal"
  )
})

test_that("detects non-numeric data frame columns", {
  df <- data.frame(
    BrandA = c("a", "b", "c"),
    BrandB = c(1, 2, 3),
    stringsAsFactors = FALSE
  )
  expect_error(
    validate_ranking_matrix(df, num_positions = 3),
    class = "turas_refusal"
  )
})


# ==============================================================================
# 2. calculate_percent_ranked_first
# ==============================================================================

context("calculate_percent_ranked_first")

test_that("correct percentage with known data (BrandA = 50%)", {
  m <- make_ranking_matrix()
  result <- calculate_percent_ranked_first(m, "BrandA")

  expect_equal(result$percentage, 50)
  expect_equal(result$count, 5)
  expect_equal(result$base, 10)
  expect_equal(result$effective_n, 10)
})

test_that("handles item never ranked first (BrandD = 0%)", {
  m <- make_ranking_matrix()
  result <- calculate_percent_ranked_first(m, "BrandD")

  expect_equal(result$percentage, 0)
  expect_equal(result$count, 0)
  expect_equal(result$base, 10)
})

test_that("weighted calculation differs from unweighted", {
  m <- make_ranking_matrix()
  # Give heavy weight to respondent 6 (who ranked BrandC first)
  weights <- rep(1, 10)
  weights[6] <- 5  # BrandC ranked 1st by respondent 6 with weight 5

  result_weighted <- calculate_percent_ranked_first(m, "BrandC", weights = weights)
  result_unweighted <- calculate_percent_ranked_first(m, "BrandC")

  # Unweighted: 1/10 = 10%
  expect_equal(result_unweighted$percentage, 10)

  # Weighted: 5 / (9*1 + 5) = 5/14 ~ 35.7%
  expect_true(result_weighted$percentage > result_unweighted$percentage)
  expect_equal(result_weighted$percentage, 5 / 14 * 100, tolerance = 0.01)
})

test_that("refuses missing item name", {
  m <- make_ranking_matrix()
  expect_error(
    calculate_percent_ranked_first(m, "NonExistent"),
    class = "turas_refusal"
  )
})

test_that("refuses mismatched weights length", {
  m <- make_ranking_matrix()
  expect_error(
    calculate_percent_ranked_first(m, "BrandA", weights = c(1, 2, 3)),
    class = "turas_refusal"
  )
})


# ==============================================================================
# 3. calculate_percent_top_n
# ==============================================================================

context("calculate_percent_top_n")

test_that("top 2 calculation correct", {
  m <- make_ranking_matrix()
  # BrandA in top 2: ranks <= 2 => respondents 1,2,3,5,6,7,9,10 = 8/10
  result <- calculate_percent_top_n(m, "BrandA", top_n = 2)

  expect_equal(result$percentage, 80)
  expect_equal(result$count, 8)
  expect_equal(result$base, 10)
})

test_that("top_n=1 equals percent ranked first", {
  m <- make_ranking_matrix()
  result_top1 <- calculate_percent_top_n(m, "BrandA", top_n = 1)
  result_first <- calculate_percent_ranked_first(m, "BrandA")

  expect_equal(result_top1$percentage, result_first$percentage)
  expect_equal(result_top1$count, result_first$count)
})

test_that("top_n clamped when exceeding num_positions", {
  m <- make_ranking_matrix()
  # top_n = 10 with only 4 positions -> clamp to 4 -> everyone in top 4
  result <- expect_output(
    calculate_percent_top_n(m, "BrandA", top_n = 10, num_positions = 4),
    "WARNING.*clamping"
  )

  # Everyone is in top 4, so 100%
  expect_equal(result$percentage, 100)
})

test_that("refuses invalid top_n", {
  m <- make_ranking_matrix()
  expect_error(
    calculate_percent_top_n(m, "BrandA", top_n = 0),
    class = "turas_refusal"
  )
  expect_error(
    calculate_percent_top_n(m, "BrandA", top_n = -1),
    class = "turas_refusal"
  )
})


# ==============================================================================
# 4. calculate_mean_rank
# ==============================================================================

context("calculate_mean_rank")

test_that("correct mean with known data (BrandA = 1.8, BrandB = 1.9)", {
  m <- make_ranking_matrix()

  mean_a <- calculate_mean_rank(m, "BrandA")
  mean_b <- calculate_mean_rank(m, "BrandB")

  expect_equal(mean_a, 1.8)
  expect_equal(mean_b, 1.9)
})

test_that("weighted mean differs from unweighted", {
  m <- make_ranking_matrix()
  # Give heavy weight to respondent 8 (who ranked BrandA 4th)
  weights <- rep(1, 10)
  weights[8] <- 5

  mean_unweighted <- calculate_mean_rank(m, "BrandA")
  mean_weighted <- calculate_mean_rank(m, "BrandA", weights = weights)

  # Unweighted: 1.8
  expect_equal(mean_unweighted, 1.8)

  # Weighted should be higher because respondent 8 (rank 4) gets weight 5
  expect_true(mean_weighted > mean_unweighted)
})

test_that("handles all-NA item by returning NA", {
  m <- make_all_na_column_matrix()
  result <- calculate_mean_rank(m, "BrandD")

  expect_true(is.na(result))
})

test_that("refuses missing item name", {
  m <- make_ranking_matrix()
  expect_error(
    calculate_mean_rank(m, "NonExistent"),
    class = "turas_refusal"
  )
})


# ==============================================================================
# 5. normalize_rank_direction
# ==============================================================================

context("normalize_rank_direction")

test_that("BestToWorst passthrough returns identical matrix", {
  m <- make_ranking_matrix()
  result <- normalize_rank_direction(m, num_positions = 4, direction = "BestToWorst")

  expect_identical(result, m)
})

test_that("WorstToBest flips ranks correctly (1 becomes num_positions)", {
  m <- make_ranking_matrix()
  result <- normalize_rank_direction(m, num_positions = 4, direction = "WorstToBest")

  # Rank 1 -> 4, rank 2 -> 3, rank 3 -> 2, rank 4 -> 1
  # Respondent 1: (1,2,3,4) -> (4,3,2,1)
  expect_equal(result[1, ], c(BrandA = 4, BrandB = 3, BrandC = 2, BrandD = 1))
  # Respondent 5: (1,2,4,3) -> (4,3,1,2)
  expect_equal(result[5, ], c(BrandA = 4, BrandB = 3, BrandC = 1, BrandD = 2))
})

test_that("WorstToBest preserves NAs during flip", {
  m <- make_incomplete_ranking_matrix()
  result <- normalize_rank_direction(m, num_positions = 4, direction = "WorstToBest")

  # Respondent 1: (1, NA, NA, NA) -> (4, NA, NA, NA)
  expect_equal(unname(result[1, 1]), 4)
  expect_true(is.na(result[1, 2]))
  expect_true(is.na(result[1, 3]))

  # Respondent 2: all NA -> all NA
  expect_true(all(is.na(result[2, ])))
})

test_that("refuses non-matrix input", {
  expect_error(
    normalize_rank_direction("not a matrix", num_positions = 4, direction = "BestToWorst"),
    class = "turas_refusal"
  )
})

test_that("refuses invalid num_positions", {
  m <- make_ranking_matrix()
  expect_error(
    normalize_rank_direction(m, num_positions = -1, direction = "BestToWorst"),
    class = "turas_refusal"
  )
})


# ==============================================================================
# 6. Edge cases
# ==============================================================================

context("Ranking edge cases")

test_that("single respondent produces valid results", {
  m <- make_single_respondent_matrix()

  # Validation
  v <- validate_ranking_matrix(m, num_positions = 4)
  expect_true(v$valid)
  expect_equal(v$n_respondents, 1)

  # Metrics
  first <- calculate_percent_ranked_first(m, "BrandA")
  expect_equal(first$percentage, 100)
  expect_equal(first$base, 1)

  mean_r <- calculate_mean_rank(m, "BrandA")
  expect_equal(mean_r, 1)
})

test_that("all-NA column returns NA for mean rank and 0% for ranked first", {
  m <- make_all_na_column_matrix()

  mean_r <- calculate_mean_rank(m, "BrandD")
  expect_true(is.na(mean_r))

  first <- calculate_percent_ranked_first(m, "BrandD")
  # No valid ranks, so base = 0, percentage should be NA (division by zero guard)
  expect_true(is.na(first$percentage))
  expect_equal(first$base, 0)
})

test_that("data.frame input accepted and converted to matrix", {
  df <- data.frame(
    BrandA = c(1, 2, 3),
    BrandB = c(2, 1, 1),
    BrandC = c(3, 3, 2)
  )
  result <- validate_ranking_matrix(df, num_positions = 3)

  expect_equal(result$n_respondents, 3)
  expect_equal(result$n_items, 3)
})


# ==============================================================================
# 7. calculate_rank_variance
# ==============================================================================

context("calculate_rank_variance")

test_that("variance is zero for constant ranks", {
  m <- matrix(c(1, 2, 1, 2, 1, 2), nrow = 3, ncol = 2, byrow = TRUE)
  colnames(m) <- c("ItemA", "ItemB")

  var_a <- calculate_rank_variance(m, "ItemA")
  expect_equal(var_a, 0)
})

test_that("variance is positive for varying ranks", {
  m <- make_ranking_matrix()
  var_a <- calculate_rank_variance(m, "BrandA")
  expect_true(var_a > 0)
})

test_that("returns NA for missing item", {
  m <- make_ranking_matrix()
  var_missing <- calculate_rank_variance(m, "NonExistent")
  expect_true(is.na(var_missing))
})

test_that("returns NA for item with fewer than 2 valid ranks", {
  m <- matrix(c(1, NA, NA, NA), nrow = 2, ncol = 2)
  colnames(m) <- c("A", "B")
  var_result <- calculate_rank_variance(m, "A")
  expect_true(is.na(var_result))
})


# ==============================================================================
# 8. format_ranking_value
# ==============================================================================

context("format_ranking_value")

test_that("formats percent value with specified decimal places", {
  result <- format_ranking_value(50.123, "percent",
                                  decimal_places_percent = 1,
                                  decimal_places_index = 2)
  expect_equal(result, 50.1)
})

test_that("formats index value with specified decimal places", {
  result <- format_ranking_value(1.8567, "index",
                                  decimal_places_percent = 0,
                                  decimal_places_index = 2)
  expect_equal(result, 1.86)
})

test_that("returns NA for NA input", {
  result <- format_ranking_value(NA, "percent",
                                  decimal_places_percent = 1,
                                  decimal_places_index = 2)
  expect_true(is.na(result))
})


# ==============================================================================
# 9. validate_ranking_question
# ==============================================================================

context("validate_ranking_question")

test_that("valid ranking question produces no new errors", {
  question_info <- data.frame(
    QuestionCode = "Q1",
    Ranking_Format = "Position",
    Ranking_Positions = 4,
    stringsAsFactors = FALSE
  )
  options_info <- data.frame(
    DisplayText = c("Brand A", "Brand B"),
    OptionText = c("BrandA", "BrandB"),
    stringsAsFactors = FALSE
  )
  error_log <- data.frame(
    Timestamp = character(0), Component = character(0),
    Issue_Type = character(0), Description = character(0),
    QuestionCode = character(0), Severity = character(0),
    stringsAsFactors = FALSE
  )

  result <- validate_ranking_question(question_info, options_info, error_log)
  expect_equal(nrow(result), 0)
})

test_that("missing Ranking_Format logs an error", {
  question_info <- data.frame(
    QuestionCode = "Q1",
    Ranking_Positions = 4,
    stringsAsFactors = FALSE
  )
  options_info <- data.frame(
    DisplayText = "A", OptionText = "A", stringsAsFactors = FALSE
  )
  error_log <- data.frame(
    Timestamp = character(0), Component = character(0),
    Issue_Type = character(0), Description = character(0),
    QuestionCode = character(0), Severity = character(0),
    stringsAsFactors = FALSE
  )

  result <- validate_ranking_question(question_info, options_info, error_log)
  expect_true(nrow(result) > 0)
  expect_true(any(grepl("Ranking_Format", result$Issue_Type, ignore.case = TRUE) |
                   grepl("Ranking_Format", result$Description, ignore.case = TRUE)))
})

test_that("refuses non-dataframe question_info", {
  expect_error(
    validate_ranking_question("not a df", data.frame(), data.frame()),
    class = "turas_refusal"
  )
})


# ==============================================================================
# 10. get_banner_subset_and_weights
# ==============================================================================

context("get_banner_subset_and_weights")

test_that("returns valid=FALSE for missing key", {
  m <- make_ranking_matrix()
  result <- get_banner_subset_and_weights(
    key = "nonexistent",
    banner_data_list = list(),
    ranking_matrix = m,
    weights_list = NULL
  )
  expect_false(result$valid)
})

test_that("returns valid subset with original_row indices", {
  m <- make_ranking_matrix()
  subset_df <- data.frame(
    .original_row = c(1, 3, 5),
    dummy = c("a", "b", "c"),
    stringsAsFactors = FALSE
  )
  banner_data_list <- list(total = subset_df)
  weights_list <- list(total = c(1, 1, 1))

  result <- get_banner_subset_and_weights(
    key = "total",
    banner_data_list = banner_data_list,
    ranking_matrix = m,
    weights_list = weights_list
  )

  expect_true(result$valid)
  expect_equal(nrow(result$subset_matrix), 3)
  expect_equal(result$subset_weights, c(1, 1, 1))
})


# ==============================================================================
# 11. compare_mean_ranks
# ==============================================================================

context("compare_mean_ranks")

test_that("returns non-significant for identical groups", {
  m <- make_ranking_matrix()
  result <- compare_mean_ranks(m, m, "BrandA")

  expect_false(result$significant)
  expect_equal(result$mean1, result$mean2)
})

test_that("returns NA when one group has all-NA item", {
  m <- make_ranking_matrix()
  m_na <- make_all_na_column_matrix()

  result <- compare_mean_ranks(m, m_na, "BrandD")

  expect_false(result$significant)
  expect_true(is.na(result$p_value))
})

test_that("refuses invalid alpha", {
  m <- make_ranking_matrix()
  expect_error(
    compare_mean_ranks(m, m, "BrandA", alpha = 0),
    class = "turas_refusal"
  )
  expect_error(
    compare_mean_ranks(m, m, "BrandA", alpha = 1),
    class = "turas_refusal"
  )
})
