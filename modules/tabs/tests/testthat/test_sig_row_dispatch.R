# ==============================================================================
# TABS MODULE - SIGNIFICANCE ROW DISPATCH TESTS (production review 2026-08, C1)
# ==============================================================================
#
# Numeric and Allocation questions passed row_type "rating" to
# add_significance_row(), whose dispatch only knows proportion/topbox/mean/index
# — every pair silently returned significant = FALSE and the Sig row shipped
# all-blank, reading as "tested, nothing significant".
#
# These tests pin:
#   1. add_significance_row() with mean-shaped data (values + weights — the
#      exact shape both processors pass) letters a hand-calculated pair.
#   2. An unknown row_type now REFUSES (CALC_UNKNOWN_SIG_ROW_TYPE) instead of
#      silently emitting a blank Sig row.
#   3. process_numeric_question() end-to-end produces a lettered Sig row.
#   4. build_allocation_sig_row() produces a lettered Sig row.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_sig_row_dispatch.R")
#
# ==============================================================================

library(testthat)

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
source(file.path(turas_root, "modules/tabs/lib/crosstabs/crosstabs_config.R"))  # alpha_to_confidence_label
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))
source(file.path(turas_root, "modules/tabs/lib/report_shared.R"))  # build_fpc_multipliers

# batch_rbind copied from shared_functions.R (the orchestrator can't be sourced
# under testthat — same approach as test_standard_processor.R)
batch_rbind <- function(row_list) {
  if (length(row_list) == 0) return(data.frame())
  all_cols <- unique(unlist(lapply(row_list, names)))
  row_list <- lapply(row_list, function(df) {
    missing_cols <- setdiff(all_cols, names(df))
    for (col in missing_cols) df[[col]] <- NA
    df[, all_cols, drop = FALSE]
  })
  do.call(rbind, row_list)
}
assign("batch_rbind", batch_rbind, envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/numeric_processor.R"))
source(file.path(turas_root, "modules/tabs/lib/allocation_processor.R"))

# --- Constants used by the extracted significance functions ---
if (!exists("SIG_ROW_TYPE", envir = globalenv()))
  assign("SIG_ROW_TYPE", "Sig.", envir = globalenv())
if (!exists("SIG2_ROW_TYPE", envir = globalenv()))
  assign("SIG2_ROW_TYPE", "Sig.2", envir = globalenv())
if (!exists("TOTAL_COLUMN", envir = globalenv()))
  assign("TOTAL_COLUMN", "Total", envir = globalenv())
if (!exists("FREQUENCY_ROW_TYPE", envir = globalenv()))
  assign("FREQUENCY_ROW_TYPE", "Frequency", envir = globalenv())
if (!exists("AVERAGE_ROW_TYPE", envir = globalenv()))
  assign("AVERAGE_ROW_TYPE", "Average", envir = globalenv())

# --- Extract the significance functions from run_crosstabs.R (same technique
#     as test_dual_significance.R — avoids executing the orchestrator) ---
.rc_lines <- readLines(file.path(turas_root, "modules/tabs/lib/run_crosstabs.R"))
.rc_start <- grep("^run_significance_tests_for_row <- function", .rc_lines)
.rc_end   <- grep("^add_significance_row <- function", .rc_lines)
.rc_next  <- grep("^(#' Write question table|write_question_table_fast)", .rc_lines)
.rc_next  <- .rc_next[.rc_next > .rc_end[1]][1] - 1
eval(parse(text = .rc_lines[.rc_start[1]:.rc_next]), envir = globalenv())
rm(.rc_lines, .rc_start, .rc_end, .rc_next)

# ==============================================================================
# Known-answer fixture
# ==============================================================================
#
# Group A: 20 values of 8.5 and 20 of 7.5  -> mean 8.0, sd = sqrt(10/39) = 0.5064
# Group B: 20 values of 7.5 and 20 of 6.5  -> mean 7.0, sd = 0.5064
# Welch SE = sqrt(0.25641/40 + 0.25641/40) = 0.11323
# t = (8.0 - 7.0) / 0.11323 = 8.83, df ~ 78 -> p << 0.001 -> A significantly higher.

VALUES_A <- c(rep(8.5, 20), rep(7.5, 20))
VALUES_B <- c(rep(7.5, 20), rep(6.5, 20))

KEY_T <- "TOTAL::Total"
KEY_A <- "GRP::A"
KEY_B <- "GRP::B"

make_banner_info <- function() {
  list(
    internal_keys = c(KEY_T, KEY_A, KEY_B),
    banner_info = list(
      GRP = list(
        internal_keys = c(KEY_A, KEY_B),
        letters = setNames(c("A", "B"), c(KEY_A, KEY_B))
      )
    )
  )
}

make_config <- function() {
  list(
    enable_significance_testing = TRUE,
    alpha = 0.05,
    bonferroni_correction = FALSE,
    significance_min_base = 30,
    alpha_secondary = NULL,
    show_frequency = FALSE,
    show_numeric_median = FALSE,
    show_numeric_mode = FALSE,
    show_numeric_outliers = FALSE,
    exclude_outliers_from_stats = FALSE,
    outlier_method = "IQR",
    decimal_places_numeric = 1,
    # Both flags are read with a bare `if (config$...)` in the processors, so a
    # fixture that predates a setting crashes with "argument is of length zero"
    # rather than failing an assertion. build_config_object() always supplies
    # them in production; a hand-built config here must too (review 2026-08-21,
    # I-6). show_numeric_sd defaults ON in the real builder — keep it TRUE so
    # this fixture exercises the same shape a real run produces.
    show_numeric_sd = TRUE,
    show_percent_column = FALSE
  )
}

# ==============================================================================
# 1. add_significance_row — mean-shaped data (the processors' shape)
# ==============================================================================
context("add_significance_row — mean dispatch (C1)")

test_that("mean-shaped test data letters a hand-calculated significant pair", {
  td <- list()
  td[[KEY_A]] <- list(values = VALUES_A, weights = rep(1, 40))
  td[[KEY_B]] <- list(values = VALUES_B, weights = rep(1, 40))

  result <- add_significance_row(
    td, make_banner_info(), "mean", c(KEY_T, KEY_A, KEY_B),
    alpha = 0.05, bonferroni_correction = FALSE, min_base = 30,
    is_weighted = FALSE, alpha_secondary = NULL
  )

  expect_false(is.null(result))
  expect_equal(result$RowType[1], "Sig.")
  expect_equal(result[[KEY_A]][1], "B")  # A significantly higher than B
  expect_equal(result[[KEY_B]][1], "")
})

test_that("identical groups produce a present but empty Sig row", {
  td <- list()
  td[[KEY_A]] <- list(values = VALUES_A, weights = rep(1, 40))
  td[[KEY_B]] <- list(values = VALUES_A, weights = rep(1, 40))

  result <- add_significance_row(
    td, make_banner_info(), "mean", c(KEY_T, KEY_A, KEY_B),
    alpha = 0.05, bonferroni_correction = FALSE, min_base = 30,
    is_weighted = FALSE, alpha_secondary = NULL
  )

  expect_false(is.null(result))
  expect_equal(result[[KEY_A]][1], "")
  expect_equal(result[[KEY_B]][1], "")
})

test_that("an unknown row_type refuses instead of emitting a blank Sig row", {
  td <- list()
  td[[KEY_A]] <- list(values = VALUES_A, weights = rep(1, 40))
  td[[KEY_B]] <- list(values = VALUES_B, weights = rep(1, 40))

  expect_error(
    add_significance_row(
      td, make_banner_info(), "rating", c(KEY_T, KEY_A, KEY_B),
      alpha = 0.05, bonferroni_correction = FALSE, min_base = 30,
      is_weighted = FALSE, alpha_secondary = NULL
    ),
    class = "turas_refusal"
  )
})

# ==============================================================================
# 2. process_numeric_question — end to end (C1 regression, numeric)
# ==============================================================================
context("process_numeric_question — significance letters (C1)")

test_that("a numeric question with a significant group difference gets letters", {
  data <- data.frame(Q_SPEND = c(VALUES_A, VALUES_B) * 100)

  banner_row_indices <- setNames(
    list(1:80, 1:40, 41:80),
    c(KEY_T, KEY_A, KEY_B)
  )
  banner_bases <- setNames(
    list(
      list(weighted = 80, unweighted = 80),
      list(weighted = 40, unweighted = 40),
      list(weighted = 40, unweighted = 40)
    ),
    c(KEY_T, KEY_A, KEY_B)
  )

  result <- process_numeric_question(
    data = data,
    question_info = list(QuestionCode = "Q_SPEND"),
    question_options = data.frame(),
    banner_info = make_banner_info(),
    banner_row_indices = banner_row_indices,
    master_weights = rep(1, 80),
    banner_bases = banner_bases,
    config = make_config(),
    is_weighted = FALSE
  )

  sig_rows <- result[result$RowType == "Sig.", , drop = FALSE]
  expect_equal(nrow(sig_rows), 1L)
  expect_equal(sig_rows[[KEY_A]][1], "B")
  expect_equal(sig_rows[[KEY_B]][1], "")
})

# ==============================================================================
# 3. build_allocation_sig_row — end to end (C1 regression, allocation)
# ==============================================================================
context("build_allocation_sig_row — significance letters (C1)")

test_that("an allocation column with a significant group difference gets letters", {
  value_sets <- setNames(
    list(c(VALUES_A, VALUES_B), VALUES_A, VALUES_B),
    c(KEY_T, KEY_A, KEY_B)
  )
  weight_sets <- setNames(
    list(rep(1, 80), rep(1, 40), rep(1, 40)),
    c(KEY_T, KEY_A, KEY_B)
  )

  sig_row <- build_allocation_sig_row(
    value_sets, weight_sets, make_banner_info(),
    c(KEY_T, KEY_A, KEY_B), make_config(), is_weighted = FALSE
  )

  expect_false(is.null(sig_row))
  expect_equal(sig_row[[KEY_A]][1], "B")
  expect_equal(sig_row[[KEY_B]][1], "")
})

# ==============================================================================
# 5. Letters stay on their columns when a column has no data
#    (final review 2026-08)
# ==============================================================================
#
# The processors drop banner columns with no test data before dispatch
# (standard_processor.R, numeric_processor.R, allocation_processor.R). The
# letters vector must be subset the same way: indexing the full-length letters
# with a subset-length logical recycles, shifting every letter after the
# dropped column onto the wrong column.

context("add_significance_row — letter alignment when a column drops")

KEY_N <- "GRP3::North"
KEY_M <- "GRP3::Central"
KEY_S <- "GRP3::South"

make_banner_info_3 <- function() {
  list(
    internal_keys = c(KEY_T, KEY_N, KEY_M, KEY_S),
    banner_info = list(
      GRP3 = list(
        internal_keys = c(KEY_N, KEY_M, KEY_S),
        # unnamed and positional, exactly as create_banner_structure builds them
        letters = c("A", "B", "C")
      )
    )
  )
}

test_that("an empty middle column does not shift the letters of later columns", {
  td <- list()
  td[[KEY_N]] <- list(values = VALUES_A, weights = rep(1, 40))
  td[[KEY_S]] <- list(values = VALUES_B, weights = rep(1, 40))
  # KEY_M (letter B) has no data for this question and is absent from td

  result <- add_significance_row(
    td, make_banner_info_3(), "mean", c(KEY_T, KEY_N, KEY_M, KEY_S),
    alpha = 0.05, bonferroni_correction = FALSE, min_base = 30,
    is_weighted = FALSE, alpha_secondary = NULL
  )

  expect_false(is.null(result))
  # North beats South, whose column letter is C. The recycled index used to
  # return "B" — the letter of the EMPTY column.
  expect_equal(result[[KEY_N]][1], "C")
  expect_equal(result[[KEY_M]][1], "")
  expect_equal(result[[KEY_S]][1], "")
})

test_that("dual-alpha letters stay aligned too when a column drops", {
  td <- list()
  td[[KEY_N]] <- list(values = VALUES_A, weights = rep(1, 40))
  td[[KEY_S]] <- list(values = VALUES_B, weights = rep(1, 40))

  result <- add_significance_row(
    td, make_banner_info_3(), "mean", c(KEY_T, KEY_N, KEY_M, KEY_S),
    alpha = 0.05, bonferroni_correction = FALSE, min_base = 30,
    is_weighted = FALSE, alpha_secondary = 0.20
  )

  expect_false(is.null(result))
  sig1 <- result[result$RowType == "Sig.", ]
  sig2 <- result[result$RowType == "Sig.2", ]
  expect_equal(sig1[[KEY_N]][1], "C")
  expect_equal(sig2[[KEY_N]][1], "C")
  expect_equal(sig1[[KEY_M]][1], "")
  expect_equal(sig2[[KEY_M]][1], "")
})
