# ==============================================================================
# Tests for run_shopper_location() and run_shopper_packsize()
# ==============================================================================
# Each happy-path test uses a tiny hand-constructed dataset with expected
# values calculable on paper. The goal is that an independent reviewer
# (including a non-programmer) can verify a number rather than trust the code.
# ==============================================================================

source("../../R/08e_shopper_behaviour.R", chdir = FALSE)


# ------------------------------------------------------------------------------
# Hand-verifiable fixture
# ------------------------------------------------------------------------------
# 4 respondents, 3 channels (S / O / C), 2 brands (A / B).
#   r1: channel S        | brand A
#   r2: channels S + O   | brands A and B
#   r3: channel O        | brand B
#   r4: no channels      | no brand
#
# Category buyers = anyone selecting any channel = r1, r2, r3 (n = 3).
# Expected category shares:
#   S = 2 / 3 = 66.7%   O = 2 / 3 = 66.7%   C = 0%
# Expected per-brand shares (of brand buyers):
#   A buyers = r1, r2: S = 100%, O = 50%,  C = 0%
#   B buyers = r2, r3: S = 50%,  O = 100%, C = 0%
# Cat-avg row = unweighted mean across brand rows: S = 75%, O = 75%, C = 0%.

build_fixture <- function() {
  list(
    df = data.frame(
      CH_S = c(1, 1, 0, 0),
      CH_O = c(0, 1, 1, 0),
      CH_C = c(0, 0, 0, 0)
    ),
    pen_mat = matrix(
      c(1, 1, 0, 0,
        0, 1, 1, 0),
      ncol = 2,
      dimnames = list(NULL, c("A", "B"))
    ),
    cols   = c("CH_S", "CH_O", "CH_C"),
    codes  = c("S",    "O",    "C"),
    labels = c("Supermarket", "Online", "Convenience"),
    brands = c("A", "B")
  )
}


# ------------------------------------------------------------------------------
# Happy path: known-answer test
# ------------------------------------------------------------------------------

test_that("run_shopper_location returns hand-verified category shares", {
  fx <- build_fixture()
  res <- run_shopper_location(
    fx$df, fx$cols, fx$codes, fx$labels,
    pen_mat = fx$pen_mat, brand_codes = fx$brands
  )
  expect_equal(res$status, "PASS")
  expect_equal(res$n_cat_buyers, 3L)
  expect_equal(res$n_respondents, 4L)
  expect_equal(res$category_distribution$Pct, c(66.7, 66.7, 0.0))
  expect_equal(res$category_distribution$n,   c(2L, 2L, 0L))
})

test_that("run_shopper_location returns hand-verified brand x channel matrix", {
  fx <- build_fixture()
  res <- run_shopper_location(
    fx$df, fx$cols, fx$codes, fx$labels,
    pen_mat = fx$pen_mat, brand_codes = fx$brands
  )
  bm <- res$brand_matrix
  expect_equal(bm$BrandCode, c("__cat__", "A", "B"))
  expect_equal(bm$Base_n,    c(NA_integer_, 2L, 2L))
  # Brand A: bought by r1 + r2 -> S=100, O=50, C=0
  brand_a <- bm[bm$BrandCode == "A", ]
  expect_equal(brand_a$Pct_S, 100)
  expect_equal(brand_a$Pct_O, 50)
  expect_equal(brand_a$Pct_C, 0)
  # Brand B: bought by r2 + r3 -> S=50, O=100, C=0
  brand_b <- bm[bm$BrandCode == "B", ]
  expect_equal(brand_b$Pct_S, 50)
  expect_equal(brand_b$Pct_O, 100)
  expect_equal(brand_b$Pct_C, 0)
  # Cat avg = unweighted mean across brand rows
  cat_row <- bm[bm$BrandCode == "__cat__", ]
  expect_equal(cat_row$Pct_S, 75)
  expect_equal(cat_row$Pct_O, 75)
  expect_equal(cat_row$Pct_C, 0)
})

test_that("run_shopper_location KPIs match hand calculation", {
  fx <- build_fixture()
  res <- run_shopper_location(
    fx$df, fx$cols, fx$codes, fx$labels,
    pen_mat = fx$pen_mat, brand_codes = fx$brands
  )
  # Top channel: S and O tied at 66.7%; which.max picks the first -> S
  expect_equal(res$top$code, "S")
  expect_equal(res$top$pct, 66.7)
  # HHI: 0.667^2 + 0.667^2 + 0 = 0.8893 -> rounds to 0.889
  expect_equal(res$hhi, 0.889, tolerance = 0.001)
})


# ------------------------------------------------------------------------------
# Weighted variant
# ------------------------------------------------------------------------------

test_that("respondent weights affect category shares as expected", {
  fx <- build_fixture()
  # Double-weight r3 (only mentions Online) -> pull O share above S.
  w <- c(1, 1, 2, 1)
  res <- run_shopper_location(
    fx$df, fx$cols, fx$codes, fx$labels,
    pen_mat = fx$pen_mat, brand_codes = fx$brands,
    weights = w
  )
  # Cat buyers weighted total = 1 + 1 + 2 = 4
  # S = (1*1 + 1*1 + 0*2)/4 = 50%
  # O = (1*0 + 1*1 + 2*1)/4 = 75%
  # C = 0
  pct <- res$category_distribution$Pct
  expect_equal(pct, c(50.0, 75.0, 0.0))
  expect_equal(res$top$code, "O")
})


# ------------------------------------------------------------------------------
# Pack-size wrapper (same engine, different vocabulary)
# ------------------------------------------------------------------------------

test_that("run_shopper_packsize produces identical-shape output", {
  fx <- build_fixture()
  res <- run_shopper_packsize(
    pack_data   = fx$df,
    pack_cols   = fx$cols,
    pack_codes  = fx$codes,
    pack_labels = fx$labels,
    pen_mat     = fx$pen_mat,
    brand_codes = fx$brands
  )
  expect_equal(res$status, "PASS")
  expect_equal(res$kind,   "packsize")
  expect_equal(res$category_distribution$Pct, c(66.7, 66.7, 0.0))
})


# ------------------------------------------------------------------------------
# Refusals: invalid inputs must fail loudly with TRS codes
# ------------------------------------------------------------------------------

test_that("empty data refuses with DATA_NO_INPUT", {
  res <- run_shopper_location(
    channel_data   = data.frame(),
    channel_cols   = character(0),
    channel_codes  = character(0),
    channel_labels = character(0)
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code,   "DATA_NO_INPUT")
})

test_that("missing option columns refuse with DATA_COLS_MISSING", {
  fx <- build_fixture()
  res <- run_shopper_location(
    fx$df,
    channel_cols   = c("CH_S", "MISSING_COL"),
    channel_codes  = c("S", "M"),
    channel_labels = c("Supermarket", "Missing")
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code,   "DATA_COLS_MISSING")
})

test_that("all-zero data refuses with DATA_NO_CAT_BUYERS", {
  df <- data.frame(CH_S = c(0, 0), CH_O = c(0, 0))
  res <- run_shopper_location(
    df,
    channel_cols   = c("CH_S", "CH_O"),
    channel_codes  = c("S", "O"),
    channel_labels = c("Supermarket", "Online")
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code,   "DATA_NO_CAT_BUYERS")
})

test_that("codes/labels length mismatch refuses with CFG codes", {
  fx <- build_fixture()
  res <- run_shopper_location(
    fx$df, fx$cols,
    channel_codes  = c("S", "O"),
    channel_labels = fx$labels
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code,   "CFG_CODES_LENGTH_MISMATCH")
})

test_that("weights length mismatch refuses with DATA_WEIGHTS_MISMATCH", {
  fx <- build_fixture()
  res <- run_shopper_location(
    fx$df, fx$cols, fx$codes, fx$labels,
    weights = c(1, 1)
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code,   "DATA_WEIGHTS_MISMATCH")
})


# ------------------------------------------------------------------------------
# Optional-input behaviour: missing pen_mat -> brand_matrix is NULL but
# category-level results still pass.
# ------------------------------------------------------------------------------

test_that("absent pen_mat omits brand_matrix but still passes", {
  fx <- build_fixture()
  res <- run_shopper_location(
    fx$df, fx$cols, fx$codes, fx$labels
  )
  expect_equal(res$status, "PASS")
  expect_null(res$brand_matrix)
  expect_equal(res$category_distribution$Pct, c(66.7, 66.7, 0.0))
})

test_that("pen_mat with wrong row count is silently ignored, not crashing", {
  fx <- build_fixture()
  bad_pen <- fx$pen_mat[1:2, , drop = FALSE]
  res <- run_shopper_location(
    fx$df, fx$cols, fx$codes, fx$labels,
    pen_mat = bad_pen, brand_codes = fx$brands
  )
  expect_equal(res$status, "PASS")
  expect_null(res$brand_matrix)
})


# ------------------------------------------------------------------------------
# NA handling: NA cells in the multi-mention columns collapse to 0.
# ------------------------------------------------------------------------------

test_that("NA in option columns is treated as 'not selected'", {
  df <- data.frame(
    CH_S = c(1, NA, 0, 0),
    CH_O = c(NA, 1, 1, 0),
    CH_C = c(0, 0, 0, 0)
  )
  # With NA -> 0, cat buyers = r1, r2, r3 (n = 3).
  # S = 1/3 = 33.3%, O = 2/3 = 66.7%, C = 0.
  res <- run_shopper_location(
    df,
    channel_cols   = c("CH_S", "CH_O", "CH_C"),
    channel_codes  = c("S", "O", "C"),
    channel_labels = c("Supermarket", "Online", "Convenience")
  )
  expect_equal(res$status, "PASS")
  expect_equal(res$n_cat_buyers, 3L)
  expect_equal(res$category_distribution$Pct, c(33.3, 66.7, 0.0))
})
