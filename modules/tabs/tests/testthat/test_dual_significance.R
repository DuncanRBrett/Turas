# ==============================================================================
# TABS MODULE - DUAL SIGNIFICANCE LEVEL TESTS (V10.10)
# ==============================================================================
#
# Known-answer tests for the dual significance level feature.
# Covers:
#   1. alpha_to_confidence_label()  — label helper
#   2. validate_dual_significance_config()  — TRS guard validation
#   3. build_config_object()  — config parsing for new fields
#   4. add_significance_row() in dual-alpha mode  — known-answer calculation
#   5. detect_available_stats()  — has_sig2 flag
#
# All statistical expected values are hand-calculated and documented.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_dual_significance.R")
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
source(file.path(turas_root, "modules/tabs/lib/crosstabs/crosstabs_config.R"))
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))
source(file.path(turas_root, "modules/tabs/lib/html_report/01_data_transformer.R"))

# Extract significance functions from run_crosstabs.R without side effects
# (avoids sourcing the full orchestrator and its check_dependencies() call)
if (!exists("SIG_ROW_TYPE", envir = globalenv()))
  assign("SIG_ROW_TYPE", "Sig.",  envir = globalenv())
if (!exists("SIG2_ROW_TYPE", envir = globalenv()))
  assign("SIG2_ROW_TYPE", "Sig.2", envir = globalenv())
if (!exists("DEFAULT_ALPHA", envir = globalenv()))
  assign("DEFAULT_ALPHA", 0.05, envir = globalenv())
if (!exists("DEFAULT_MIN_BASE", envir = globalenv()))
  assign("DEFAULT_MIN_BASE", 30, envir = globalenv())
if (!exists("TOTAL_COLUMN", envir = globalenv()))
  assign("TOTAL_COLUMN", "Total", envir = globalenv())

.rc_lines <- readLines(file.path(turas_root, "modules/tabs/lib/run_crosstabs.R"))
.rc_start <- grep("^run_significance_tests_for_row <- function", .rc_lines)
.rc_end   <- grep("^add_significance_row <- function",           .rc_lines)
.rc_next  <- grep("^(#' Write question table|write_question_table_fast)", .rc_lines)
.rc_next  <- .rc_next[.rc_next > .rc_end[1]][1] - 1
eval(parse(text = .rc_lines[.rc_start[1]:.rc_next]), envir = globalenv())
rm(.rc_lines, .rc_start, .rc_end, .rc_next)


# ==============================================================================
# HELPER: minimal banner_info for two banner columns
# ==============================================================================
# banner_info mirrors the structure used by add_significance_row():
#   banner_info$banner_info[[<code>]]$internal_keys  — column keys
#   banner_info$banner_info[[<code>]]$letters        — named vector of letters
make_two_column_banner <- function(key_a = "GRP::A", key_b = "GRP::B") {
  list(
    banner_info = list(
      GRP = list(
        internal_keys = c(key_a, key_b),
        letters = setNames(c("A", "B"), c(key_a, key_b))
      )
    )
  )
}


# ==============================================================================
# 1. alpha_to_confidence_label()
# ==============================================================================
context("alpha_to_confidence_label")

test_that("converts 0.05 to 'Sig. (95%)'", {
  expect_equal(alpha_to_confidence_label(0.05), "Sig. (95%)")
})

test_that("converts 0.10 to 'Sig. (90%)'", {
  expect_equal(alpha_to_confidence_label(0.10), "Sig. (90%)")
})

test_that("converts 0.01 to 'Sig. (99%)'", {
  expect_equal(alpha_to_confidence_label(0.01), "Sig. (99%)")
})

test_that("converts 0.20 to 'Sig. (80%)'", {
  expect_equal(alpha_to_confidence_label(0.20), "Sig. (80%)")
})


# ==============================================================================
# 2. validate_dual_significance_config() — TRS guard
# ==============================================================================
context("validate_dual_significance_config — guard")

# Helper: build a minimal config_obj list for guard tests
make_cfg <- function(alpha = 0.05, alpha_secondary = NULL,
                     alpha_default = "primary") {
  list(alpha = alpha, alpha_secondary = alpha_secondary,
       alpha_default = alpha_default)
}

test_that("passes when alpha_secondary is NULL (feature disabled)", {
  expect_silent(validate_dual_significance_config(make_cfg()))
})

test_that("passes with valid alpha_secondary different from primary", {
  expect_silent(validate_dual_significance_config(
    make_cfg(alpha = 0.05, alpha_secondary = 0.10)
  ))
})

test_that("passes with alpha_default = 'secondary'", {
  expect_silent(validate_dual_significance_config(
    make_cfg(alpha = 0.05, alpha_secondary = 0.10, alpha_default = "secondary")
  ))
})

test_that("refuses when alpha_secondary is NA (non-numeric)", {
  # NA is the result when safe_numeric() receives an un-parseable value
  expect_error(
    validate_dual_significance_config(make_cfg(alpha_secondary = NA_real_)),
    regexp = "CFG_ALPHA_SECONDARY_INVALID"
  )
})

test_that("refuses when alpha_secondary >= 1", {
  expect_error(
    validate_dual_significance_config(make_cfg(alpha_secondary = 1.0)),
    regexp = "CFG_ALPHA_SECONDARY_RANGE"
  )
})

test_that("refuses when alpha_secondary <= 0", {
  expect_error(
    validate_dual_significance_config(make_cfg(alpha_secondary = 0)),
    regexp = "CFG_ALPHA_SECONDARY_RANGE"
  )
})

test_that("refuses when alpha_secondary equals primary alpha", {
  expect_error(
    validate_dual_significance_config(make_cfg(alpha = 0.05, alpha_secondary = 0.05)),
    regexp = "CFG_ALPHA_SECONDARY_DUPLICATE"
  )
})

test_that("refuses when alpha_default is not 'primary' or 'secondary'", {
  expect_error(
    validate_dual_significance_config(
      make_cfg(alpha_secondary = 0.10, alpha_default = "foo")
    ),
    regexp = "CFG_ALPHA_DEFAULT_INVALID"
  )
})


# ==============================================================================
# 3. build_config_object() — new field parsing
# ==============================================================================
context("build_config_object — dual significance fields")

# Helper: build a minimal named-list config (mirrors what load_config_sheet returns)
make_raw_config <- function(...) {
  defaults <- list(
    structure_file     = "Survey_Structure.xlsx",
    data_file          = "data.csv",
    alpha              = "0.05",
    significance_min_base = "30",
    bonferroni_correction = "TRUE",
    enable_significance_testing = "TRUE"
  )
  overrides <- list(...)
  modifyList(defaults, overrides)
}

test_that("alpha_secondary is NULL when absent from config", {
  cfg <- build_config_object(make_raw_config())
  expect_null(cfg$alpha_secondary)
})

test_that("alpha_secondary parses correctly when set", {
  cfg <- build_config_object(make_raw_config(alpha_secondary = "0.10"))
  expect_equal(cfg$alpha_secondary, 0.10)
})

test_that("alpha_default defaults to 'primary' when absent", {
  cfg <- build_config_object(make_raw_config())
  expect_equal(cfg$alpha_default, "primary")
})

test_that("alpha_default parses 'secondary' correctly", {
  cfg <- build_config_object(make_raw_config(alpha_default = "secondary"))
  expect_equal(cfg$alpha_default, "secondary")
})

test_that("alpha_secondary is NULL when config value is blank string", {
  cfg <- build_config_object(make_raw_config(alpha_secondary = ""))
  expect_null(cfg$alpha_secondary)
})


# ==============================================================================
# 4. add_significance_row() — dual-alpha known-answer tests
# ==============================================================================
context("add_significance_row — dual-alpha mode")

# --- Known-answer setup -------------------------------------------------
#
# Two groups, n = 100 each, unweighted, no Bonferroni (single comparison):
#   Group A: 60 successes / 100 respondents  (proportion = 0.60)
#   Group B: 45 successes / 100 respondents  (proportion = 0.45)
#
# Pooled proportion: p_pool = (60 + 45) / (100 + 100) = 105/200 = 0.525
# SE = sqrt(p_pool * (1 - p_pool) * (1/100 + 1/100))
#    = sqrt(0.525 * 0.475 * 0.02)
#    = sqrt(0.004988)
#    = 0.07062
# z  = (0.60 - 0.45) / 0.07062 = 0.15 / 0.07062 = 2.124
# p  = pnorm(-2.124) ≈ 0.0169 (one-tailed)
#
# Decision:
#   alpha = 0.05  (primary):  0.0169 < 0.05 → SIGNIFICANT (A > B)
#   alpha = 0.01  (secondary): 0.0169 > 0.01 → NOT significant
#
# Therefore:
#   Primary sig row   — Group A column: "B", Group B column: ""
#   Secondary sig row — Group A column: "",  Group B column: ""
# -----------------------------------------------------------------------

KEY_A <- "GRP::A"
KEY_B <- "GRP::B"
TOTAL_KEY <- "TOTAL::Total"

make_sig_test_data <- function(count_a = 60, count_b = 45, base = 100) {
  list(
    "GRP::A" = list(count = count_a, base = base, eff_n = base),
    "GRP::B" = list(count = count_b, base = base, eff_n = base)
  )
}

test_that("single-alpha mode: primary sig row produced, no secondary row", {
  td <- make_sig_test_data()
  bi <- make_two_column_banner()
  ic <- c(TOTAL_KEY, KEY_A, KEY_B)

  result <- add_significance_row(
    td, bi, "proportion", ic,
    alpha = 0.05, bonferroni_correction = FALSE, min_base = 10,
    is_weighted = FALSE, alpha_secondary = NULL
  )

  expect_equal(nrow(result), 1L)
  expect_equal(result$RowType[1], "Sig.")
  expect_equal(result$RowLabel[1], "")  # blank label in single-alpha mode
})

test_that("dual-alpha mode produces two rows with correct RowTypes", {
  td <- make_sig_test_data()
  bi <- make_two_column_banner()
  ic <- c(TOTAL_KEY, KEY_A, KEY_B)

  result <- add_significance_row(
    td, bi, "proportion", ic,
    alpha = 0.05, bonferroni_correction = FALSE, min_base = 10,
    is_weighted = FALSE, alpha_secondary = 0.01
  )

  expect_equal(nrow(result), 2L)
  expect_equal(result$RowType[1], "Sig.")
  expect_equal(result$RowType[2], "Sig.2")
})

test_that("dual-alpha mode: primary row has confidence label", {
  td <- make_sig_test_data()
  bi <- make_two_column_banner()
  ic <- c(TOTAL_KEY, KEY_A, KEY_B)

  result <- add_significance_row(
    td, bi, "proportion", ic,
    alpha = 0.05, bonferroni_correction = FALSE, min_base = 10,
    is_weighted = FALSE, alpha_secondary = 0.01
  )

  # alpha = 0.05 → 95% confidence; alpha_secondary = 0.01 → 99% confidence
  expect_equal(result$RowLabel[1], "Sig. (95%)")
  expect_equal(result$RowLabel[2], "Sig. (99%)")
})

test_that("known-answer: primary sig (alpha=0.05) finds A > B, secondary (alpha=0.01) finds nothing", {
  # p ≈ 0.0169 — below 0.05 but above 0.01
  td <- make_sig_test_data(count_a = 60, count_b = 45, base = 100)
  bi <- make_two_column_banner()
  ic <- c(TOTAL_KEY, KEY_A, KEY_B)

  result <- add_significance_row(
    td, bi, "proportion", ic,
    alpha = 0.05, bonferroni_correction = FALSE, min_base = 10,
    is_weighted = FALSE, alpha_secondary = 0.01
  )

  primary_row   <- result[result$RowType == "Sig.",  , drop = FALSE]
  secondary_row <- result[result$RowType == "Sig.2", , drop = FALSE]

  # Primary: A is significantly higher than B at 95% → Group A cell should contain "B"
  expect_equal(primary_row[[KEY_A]], "B")
  expect_equal(primary_row[[KEY_B]], "")

  # Secondary: not significant at 99% → both cells empty
  expect_equal(secondary_row[[KEY_A]], "")
  expect_equal(secondary_row[[KEY_B]], "")
})

test_that("known-answer: both levels significant when p is very small", {
  # Large difference — p will be far below both 0.05 and 0.10
  # Group A: 80/100, Group B: 30/100
  # p_pool = 110/200 = 0.55; SE ≈ 0.0704; z ≈ 7.1; p ≈ 0 (effectively)
  td <- make_sig_test_data(count_a = 80, count_b = 30, base = 100)
  bi <- make_two_column_banner()
  ic <- c(TOTAL_KEY, KEY_A, KEY_B)

  result <- add_significance_row(
    td, bi, "proportion", ic,
    alpha = 0.05, bonferroni_correction = FALSE, min_base = 10,
    is_weighted = FALSE, alpha_secondary = 0.10
  )

  primary_row   <- result[result$RowType == "Sig.",  , drop = FALSE]
  secondary_row <- result[result$RowType == "Sig.2", , drop = FALSE]

  # Both levels: A is significantly higher than B
  expect_equal(primary_row[[KEY_A]],   "B")
  expect_equal(secondary_row[[KEY_A]], "B")
})

test_that("known-answer: neither level significant when difference is negligible", {
  # Group A: 50/100, Group B: 49/100 — effectively equal
  # p_pool ≈ 0.495; SE ≈ 0.0707; z ≈ 0.14; p ≈ 0.44 — not significant at any reasonable level
  td <- make_sig_test_data(count_a = 50, count_b = 49, base = 100)
  bi <- make_two_column_banner()
  ic <- c(TOTAL_KEY, KEY_A, KEY_B)

  result <- add_significance_row(
    td, bi, "proportion", ic,
    alpha = 0.05, bonferroni_correction = FALSE, min_base = 10,
    is_weighted = FALSE, alpha_secondary = 0.10
  )

  primary_row   <- result[result$RowType == "Sig.",  , drop = FALSE]
  secondary_row <- result[result$RowType == "Sig.2", , drop = FALSE]

  expect_equal(primary_row[[KEY_A]],   "")
  expect_equal(primary_row[[KEY_B]],   "")
  expect_equal(secondary_row[[KEY_A]], "")
  expect_equal(secondary_row[[KEY_B]], "")
})

test_that("Total column is marked '-' in both sig rows", {
  td <- make_sig_test_data()
  bi <- make_two_column_banner()
  ic <- c(TOTAL_KEY, KEY_A, KEY_B)

  result <- add_significance_row(
    td, bi, "proportion", ic,
    alpha = 0.05, bonferroni_correction = FALSE, min_base = 10,
    is_weighted = FALSE, alpha_secondary = 0.10
  )

  expect_equal(result[[TOTAL_KEY]][1], "-")
  expect_equal(result[[TOTAL_KEY]][2], "-")
})

test_that("backward compatibility: single-alpha mode is unchanged vs. pre-V10.10 behaviour", {
  # When alpha_secondary is NULL, add_significance_row returns exactly one row
  # with blank RowLabel, same as before V10.10.
  td <- make_sig_test_data(count_a = 60, count_b = 45, base = 100)
  bi <- make_two_column_banner()
  ic <- c(TOTAL_KEY, KEY_A, KEY_B)

  result <- add_significance_row(
    td, bi, "proportion", ic,
    alpha = 0.05, bonferroni_correction = FALSE, min_base = 10,
    is_weighted = FALSE
    # alpha_secondary defaults to NULL
  )

  expect_equal(nrow(result), 1L)
  expect_equal(result$RowType, "Sig.")
  expect_equal(result$RowLabel, "")   # blank label — backward compatible
  expect_equal(result[[KEY_A]], "B")  # significance still computed correctly
})


# ==============================================================================
# 5. detect_available_stats() — has_sig2 flag
# ==============================================================================
context("detect_available_stats — has_sig2")

make_table_with_row_types <- function(types) {
  data.frame(
    RowLabel = rep("A", length(types)),
    RowType  = types,
    stringsAsFactors = FALSE
  )
}

test_that("has_sig2 is FALSE when no 'Sig.2' row present", {
  tbl <- make_table_with_row_types(c("Column %", "Frequency", "Sig."))
  stats <- detect_available_stats(tbl)
  expect_false(stats$has_sig2)
})

test_that("has_sig2 is TRUE when 'Sig.2' row is present", {
  tbl <- make_table_with_row_types(c("Column %", "Frequency", "Sig.", "Sig.2"))
  stats <- detect_available_stats(tbl)
  expect_true(stats$has_sig2)
})

test_that("has_sig is still TRUE independently when both sig rows present", {
  tbl <- make_table_with_row_types(c("Column %", "Sig.", "Sig.2"))
  stats <- detect_available_stats(tbl)
  expect_true(stats$has_sig)
  expect_true(stats$has_sig2)
})

test_that("has_sig2 is FALSE when table has no sig rows at all", {
  tbl <- make_table_with_row_types(c("Column %", "Frequency"))
  stats <- detect_available_stats(tbl)
  expect_false(stats$has_sig)
  expect_false(stats$has_sig2)
})
