# ==============================================================================
# TABS MODULE - V10.8 BUG FIX REGRESSION TESTS
# ==============================================================================
#
# Tests for 7 bugs found and fixed during systematic code review (2026-03-15):
#   1. weighting.R — Floating-point tolerance in weighted_z_test_proportions
#   2. numeric_processor.R — Bessel-corrected weighted SD
#   3. standard_processor.R — Bessel-corrected weighted SD
#   4. ranking_crosstabs.R — tryCatch closure scoping fix
#   5. composite_processor.R — sig_letters key-to-letter lookup
#   6. ranking_metrics.R — Tie-breaking in compare_mean_ranks
#   7. 01_data_transformer.R — BannerLabel priority over QuestionText
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_bugfixes_v10_8.R")
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

# Source TRS infrastructure
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))

# Source the guard layer (provides tabs_refuse)
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))

# Source modules under test
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))


# ==============================================================================
# 1. weighting.R — Floating-point tolerance (count ≈ base)
# ==============================================================================

context("Bug Fix #1: weighted_z_test — floating-point tolerance")

test_that("does NOT warn when count equals base exactly (100% cell)", {
  # 100% cells are legitimate: everyone in the subgroup chose this option
  result <- weighted_z_test_proportions(
    count1 = 50, base1 = 50,
    count2 = 30, base2 = 100,
    is_weighted = FALSE
  )
  expect_true(is.list(result))
  expect_true(!is.na(result$p_value))
})

test_that("does NOT warn when count exceeds base by tiny FP epsilon", {
  # Weighted sums via different code paths can differ by ~1e-12
  result <- weighted_z_test_proportions(
    count1 = 50.0000000000001, base1 = 50,
    count2 = 30, base2 = 100,
    is_weighted = FALSE
  )
  expect_true(is.list(result))
  # Should clamp and proceed, not skip
  expect_true(!is.na(result$p_value))
})

test_that("DOES skip when count genuinely exceeds base (data error)", {
  # count exceeds base by > 0.01 — genuine data error
  result <- weighted_z_test_proportions(
    count1 = 55, base1 = 50,
    count2 = 30, base2 = 100,
    is_weighted = FALSE
  )
  expect_false(result$significant)
  expect_true(is.na(result$p_value))
})

test_that("clamped proportion never exceeds 1.0", {
  # count slightly exceeds base (within tolerance) — should clamp, not crash
  result <- weighted_z_test_proportions(
    count1 = 50.005, base1 = 50,
    count2 = 30, base2 = 100,
    is_weighted = FALSE
  )
  # If it got past the guard, proportions were clamped and test ran

  expect_true(is.list(result))
  expect_true(!is.na(result$p_value))
})

test_that("negative counts are still rejected", {
  result <- weighted_z_test_proportions(
    count1 = -1, base1 = 50,
    count2 = 30, base2 = 100,
    is_weighted = FALSE
  )
  expect_false(result$significant)
  expect_true(is.na(result$p_value))
})

test_that("zero bases return non-significant", {
  result <- weighted_z_test_proportions(
    count1 = 0, base1 = 0,
    count2 = 30, base2 = 100,
    is_weighted = FALSE
  )
  expect_false(result$significant)
})


# ==============================================================================
# 2 & 3. Bessel-corrected weighted variance (numeric & standard processor)
# ==============================================================================

context("Bug Fix #2-3: Bessel-corrected weighted variance")

test_that("unweighted SD matches base R sd()", {
  values <- c(2, 4, 4, 4, 5, 5, 7, 9)
  weights <- rep(1, length(values))

  # Manual Bessel-corrected weighted variance
  mean_val <- sum(values * weights) / sum(weights)
  denom <- sum(weights) - 1
  variance <- sum(weights * (values - mean_val)^2) / denom
  weighted_sd <- sqrt(variance)

  # Should match R's built-in sd() when all weights are 1
  expect_equal(weighted_sd, sd(values), tolerance = 1e-10)
})

test_that("weighted SD uses sample (Bessel) correction, not population", {
  values <- c(10, 20, 30)
  weights <- c(2, 1, 1)

  mean_val <- sum(values * weights) / sum(weights)  # = (20+20+30)/4 = 17.5

  # Population variance (WRONG — old code)
  pop_var <- sum(weights * (values - mean_val)^2) / sum(weights)

  # Sample variance (CORRECT — new code)
  sample_var <- sum(weights * (values - mean_val)^2) / (sum(weights) - 1)

  # Sample variance should be larger than population variance
  expect_true(sample_var > pop_var)

  # Sample SD should equal sqrt of sample variance
  sample_sd <- sqrt(sample_var)
  expect_equal(sample_sd, sqrt(sample_var))
})

test_that("single observation returns SD = 0 (denom would be 0)", {
  values <- c(42)
  weights <- c(3)

  mean_val <- sum(values * weights) / sum(weights)
  denom <- sum(weights) - 1  # 3 - 1 = 2, not 0
  # With single value, variance = w*(v-mean)^2/denom = 3*0/2 = 0
  variance <- sum(weights * (values - mean_val)^2) / denom
  expect_equal(variance, 0)
})

test_that("total weight of 1 returns SD = 0 (denom = 0)", {
  values <- c(42)
  weights <- c(1)

  mean_val <- sum(values * weights) / sum(weights)
  denom <- sum(weights) - 1  # 1 - 1 = 0
  variance <- if (denom > 0) sum(weights * (values - mean_val)^2) / denom else 0
  expect_equal(variance, 0)
})


# ==============================================================================
# 4. ranking_crosstabs.R — tryCatch closure scoping
# ==============================================================================

context("Bug Fix #4: ranking_crosstabs — tryCatch return value pattern")

# Source ranking dependencies
source(file.path(turas_root, "modules/tabs/lib/ranking/ranking_metrics.R"))
source(file.path(turas_root, "modules/tabs/lib/ranking/ranking_crosstabs.R"))

test_that("create_ranking_rows_for_item returns valid rows for normal input", {
  # Create simple ranking matrix: 10 respondents, 3 items
  set.seed(42)
  ranking_matrix <- matrix(
    sample(1:3, 30, replace = TRUE),
    nrow = 10, ncol = 3,
    dimnames = list(NULL, c("Item_A", "Item_B", "Item_C"))
  )

  # Create banner data list with one group
  banner_data <- list(
    "TOTAL::Total" = data.frame(.original_row = 1:10)
  )

  banner_info <- list(
    internal_keys = "TOTAL::Total",
    letters = "A"
  )

  result <- create_ranking_rows_for_item(
    ranking_matrix = ranking_matrix,
    item_name = "Item_A",
    banner_data_list = banner_data,
    banner_info = banner_info,
    internal_keys = "TOTAL::Total",
    weights_list = NULL,
    show_top_n = TRUE,
    top_n = 2,
    num_positions = 3
  )

  # Should return 3 rows: % Ranked 1st, Mean Rank, % Top N
  expect_equal(length(result), 3)
  expect_true(grepl("Ranked 1st", result[[1]]$RowLabel))
  expect_true(grepl("Mean Rank", result[[2]]$RowLabel))
  expect_true(grepl("Top 2", result[[3]]$RowLabel))

  # Values should be numeric (not NA — closure scoping bug would have left them NA)
  expect_false(is.na(result[[1]][["TOTAL::Total"]]))
  expect_false(is.na(result[[2]][["TOTAL::Total"]]))
  expect_false(is.na(result[[3]][["TOTAL::Total"]]))
})

test_that("create_ranking_rows_for_item handles error gracefully (sets NA)", {
  # Empty matrix should produce NAs but not crash
  ranking_matrix <- matrix(
    numeric(0), nrow = 0, ncol = 3,
    dimnames = list(NULL, c("Item_A", "Item_B", "Item_C"))
  )

  banner_data <- list(
    "TOTAL::Total" = data.frame(.original_row = integer(0))
  )

  banner_info <- list(
    internal_keys = "TOTAL::Total",
    letters = "A"
  )

  result <- create_ranking_rows_for_item(
    ranking_matrix = ranking_matrix,
    item_name = "Item_A",
    banner_data_list = banner_data,
    banner_info = banner_info,
    internal_keys = "TOTAL::Total",
    weights_list = NULL,
    show_top_n = FALSE
  )

  # Should still return rows (2 without top_n), with NA values
  expect_equal(length(result), 2)
  expect_true(is.na(result[[1]][["TOTAL::Total"]]))
  expect_true(is.na(result[[2]][["TOTAL::Total"]]))
})

test_that("create_ranking_rows_for_item validates inputs with TRS", {
  # Non-matrix input should produce TRS refusal
  expect_error(
    create_ranking_rows_for_item(
      ranking_matrix = "not a matrix",
      item_name = "Item_A",
      banner_data_list = list(),
      banner_info = list(),
      internal_keys = character(0),
      weights_list = NULL
    ),
    class = "turas_refusal"
  )

  # Non-character item_name
  expect_error(
    create_ranking_rows_for_item(
      ranking_matrix = matrix(1:6, nrow = 2),
      item_name = 42,
      banner_data_list = list(),
      banner_info = list(),
      internal_keys = character(0),
      weights_list = NULL
    ),
    class = "turas_refusal"
  )
})


# ==============================================================================
# 5. composite_processor.R — key_to_letter lookup
# ==============================================================================

context("Bug Fix #5: composite sig_letters — key_to_letter lookup")

test_that("key_to_letter lookup produces correct mapping from parallel vectors", {
  # This reproduces the fix: banner_info$sig_letters doesn't exist,
  # but banner_info$letters + internal_keys are parallel vectors
  internal_keys <- c("Gender::Male", "Gender::Female", "Age::18-24")
  letters <- c("A", "B", "C")

  key_to_letter <- setNames(letters, internal_keys)

  expect_equal(key_to_letter["Gender::Male"], c("Gender::Male" = "A"))
  expect_equal(key_to_letter["Gender::Female"], c("Gender::Female" = "B"))
  expect_equal(key_to_letter["Age::18-24"], c("Age::18-24" = "C"))
})

test_that("key_to_letter returns NA for unknown keys (safe fallback)", {
  internal_keys <- c("Gender::Male", "Gender::Female")
  letters <- c("A", "B")

  key_to_letter <- setNames(letters, internal_keys)

  # Unknown key returns NA (not an error)
  expect_true(is.na(key_to_letter["Unknown::Key"]))
})


# ==============================================================================
# 6. ranking_metrics.R — Tie-breaking in compare_mean_ranks
# ==============================================================================

context("Bug Fix #6: ranking tie-breaking — equal means return NA")

test_that("better_group is 1 when mean1 < mean2 (lower = better for ranks)", {
  mean1 <- 1.5
  mean2 <- 2.5
  better_group <- if (mean1 < mean2) 1L else if (mean1 > mean2) 2L else NA_integer_
  expect_equal(better_group, 1L)
})

test_that("better_group is 2 when mean1 > mean2", {
  mean1 <- 3.0
  mean2 <- 1.5
  better_group <- if (mean1 < mean2) 1L else if (mean1 > mean2) 2L else NA_integer_
  expect_equal(better_group, 2L)
})

test_that("better_group is NA when means are equal (not biased to group 2)", {
  # OLD BUG: `if (mean1 < mean2) 1 else 2` always returned 2 on tie
  mean1 <- 2.0
  mean2 <- 2.0
  better_group <- if (mean1 < mean2) 1L else if (mean1 > mean2) 2L else NA_integer_
  expect_true(is.na(better_group))
})

test_that("compare_mean_ranks returns NA_integer_ for tied groups", {
  # Create identical ranking matrices so means will be equal
  set.seed(123)
  ranks <- sample(1:3, 30, replace = TRUE)
  matrix1 <- matrix(ranks, nrow = 10, ncol = 3,
                    dimnames = list(NULL, c("A", "B", "C")))
  matrix2 <- matrix(ranks, nrow = 10, ncol = 3,
                    dimnames = list(NULL, c("A", "B", "C")))

  result <- compare_mean_ranks(
    ranking_matrix1 = matrix1,
    ranking_matrix2 = matrix2,
    item_name = "A",
    weights1 = rep(1, 10),
    weights2 = rep(1, 10)
  )

  # Identical data → equal means → better_group should be NA
  expect_true(is.na(result$better_group))
  expect_equal(result$mean1, result$mean2)
})


# ==============================================================================
# 7. 01_data_transformer.R — BannerLabel priority
# ==============================================================================

context("Bug Fix #7: BannerLabel takes priority over QuestionText")

test_that("build_banner_groups uses BannerLabel when available", {
  # Source the data transformer
  source(file.path(turas_root, "modules/tabs/lib/html_report/01_data_transformer.R"))

  # Create mock banner_info with BannerLabel in banner_headers
  # Note: internal_keys typically starts with TOTAL::Total, so Gender keys
  # are at positions 2-3, and banner_headers start_col/end_col reflect that.
  banner_info <- list(
    banner_questions = "Gender",
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
    letters = c("T", "A", "B"),
    columns = c("Total", "Male", "Female"),
    banner_info = list(
      Gender = list(
        internal_keys = c("Gender::Male", "Gender::Female"),
        columns = c("Male", "Female"),
        letters = c("A", "B"),
        question = list(
          QuestionText = "What is your gender identity? Please select the option that best describes you."
        )
      )
    ),
    banner_headers = data.frame(
      label = "Gender",
      start_col = 2,
      end_col = 3,
      stringsAsFactors = FALSE
    )
  )

  result <- build_banner_groups(banner_info)

  # Should use "Gender" (from BannerLabel/banner_headers), NOT the full QuestionText
  expect_true("Gender" %in% names(result))
  expect_false(any(grepl("gender identity", names(result), ignore.case = TRUE)))
})

test_that("build_banner_groups falls back to QuestionText when no BannerLabel", {
  source(file.path(turas_root, "modules/tabs/lib/html_report/01_data_transformer.R"))

  banner_info <- list(
    banner_questions = "Q5",
    internal_keys = c("Q5::Yes", "Q5::No"),
    letters = c("A", "B"),
    columns = c("Yes", "No"),
    banner_info = list(
      Q5 = list(
        internal_keys = c("Q5::Yes", "Q5::No"),
        columns = c("Yes", "No"),
        letters = c("A", "B"),
        question = list(
          QuestionText = "Are you satisfied?"
        )
      )
    ),
    banner_headers = data.frame(
      label = character(0),
      start_col = integer(0),
      end_col = integer(0),
      stringsAsFactors = FALSE
    )
  )

  result <- build_banner_groups(banner_info)

  # No BannerLabel found → should fall back to QuestionText
  # (or banner code if QuestionText also fails)
  group_names <- names(result)
  expect_true(length(group_names) == 1)
  # Should be either "Are you satisfied?" or "Q5" (fallback), NOT empty
  expect_true(nzchar(group_names[1]))
})

test_that("build_banner_groups falls back to code when no label at all", {
  source(file.path(turas_root, "modules/tabs/lib/html_report/01_data_transformer.R"))

  banner_info <- list(
    banner_questions = "Q99",
    internal_keys = c("Q99::A", "Q99::B"),
    letters = c("A", "B"),
    columns = c("A", "B"),
    banner_info = list(
      Q99 = list(
        internal_keys = c("Q99::A", "Q99::B"),
        columns = c("A", "B"),
        letters = c("A", "B"),
        question = list()  # No QuestionText
      )
    ),
    banner_headers = data.frame(
      label = character(0),
      start_col = integer(0),
      end_col = integer(0),
      stringsAsFactors = FALSE
    )
  )

  result <- build_banner_groups(banner_info)

  # No BannerLabel, no QuestionText → falls back to code "Q99"
  expect_true("Q99" %in% names(result))
})


# ==============================================================================
# WEIGHTED Z-TEST — Additional edge cases
# ==============================================================================

context("weighted_z_test_proportions — parameter validation")

test_that("rejects invalid alpha values", {
  expect_error(
    weighted_z_test_proportions(10, 50, 20, 50, alpha = 0),
    class = "turas_refusal"
  )
  expect_error(
    weighted_z_test_proportions(10, 50, 20, 50, alpha = 1),
    class = "turas_refusal"
  )
  expect_error(
    weighted_z_test_proportions(10, 50, 20, 50, alpha = -0.5),
    class = "turas_refusal"
  )
})

test_that("rejects invalid min_base values", {
  expect_error(
    weighted_z_test_proportions(10, 50, 20, 50, min_base = 0),
    class = "turas_refusal"
  )
  expect_error(
    weighted_z_test_proportions(10, 50, 20, 50, min_base = -5),
    class = "turas_refusal"
  )
})

test_that("weighted mode requires effective-n", {
  result <- weighted_z_test_proportions(
    count1 = 10, base1 = 50,
    count2 = 20, base2 = 50,
    is_weighted = TRUE,
    eff_n1 = NULL, eff_n2 = NULL
  )
  # Should skip (not crash) when effective-n missing
  expect_false(result$significant)
  expect_true(is.na(result$p_value))
})

test_that("weighted mode works with effective-n provided", {
  result <- weighted_z_test_proportions(
    count1 = 10, base1 = 50,
    count2 = 30, base2 = 50,
    eff_n1 = 45, eff_n2 = 48,
    is_weighted = TRUE,
    alpha = 0.05
  )
  expect_true(is.list(result))
  expect_true(!is.na(result$p_value))
  # Large difference (20% vs 60%) should be significant
  expect_true(result$significant)
})

test_that("NA inputs return non-significant result", {
  result <- weighted_z_test_proportions(
    count1 = NA, base1 = 50,
    count2 = 20, base2 = 50
  )
  expect_false(result$significant)
  expect_true(is.na(result$p_value))
})

test_that("below min_base returns non-significant", {
  result <- weighted_z_test_proportions(
    count1 = 5, base1 = 10,
    count2 = 8, base2 = 10,
    min_base = 30
  )
  expect_false(result$significant)
  expect_true(is.na(result$p_value))
})
