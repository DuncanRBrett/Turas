# ==============================================================================
# Tests for calculate_ma_focal_view + classify_focal_read
# ==============================================================================
# The focal-brand view replaces the standalone Drivers & Barriers HTML
# page; this file locks the math, the significance test, the base-size
# suppression and the four-way Read classifier.
# ==============================================================================

library(testthat)

.find_root_fv <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_fv()

source(file.path(ROOT, "modules", "brand", "R", "02_mental_availability.R"))
source(file.path(ROOT, "modules", "brand", "R", "02b_mental_advantage.R"))
source(file.path(ROOT, "modules", "brand", "R", "06_drivers_barriers.R"))
source(file.path(ROOT, "modules", "brand", "R", "02c_ma_focal_view.R"))


# ------------------------------------------------------------------------------
# Helper: hand-built linkage tensor for 100 respondents, 3 brands, 3 stimuli
# ------------------------------------------------------------------------------
.fv_make_tensor <- function() {
  n <- 100L
  set.seed(42)
  brands <- c("FOC", "B1", "B2")
  stims  <- c("S1", "S2", "S3")

  # FOC linkage rates by buyer/non-buyer designed for known gaps:
  #   S1: 80% of buyers, 20% of non-buyers           -> gap = +60pp (STRENGTH territory)
  #   S2: 50% of buyers, 48% of non-buyers           -> gap = +2pp (flat)
  #   S3: 20% of buyers, 60% of non-buyers           -> gap = -40pp (negative)
  # Buyer mask: first 50 respondents are buyers
  buyer_mask <- c(rep(TRUE, 50), rep(FALSE, 50))

  foc <- matrix(0L, nrow = n, ncol = 3, dimnames = list(NULL, stims))
  foc[buyer_mask,  "S1"] <- c(rep(1L, 40), rep(0L, 10))   # 40 / 50 = 80%
  foc[!buyer_mask, "S1"] <- c(rep(1L, 10), rep(0L, 40))   # 10 / 50 = 20%
  foc[buyer_mask,  "S2"] <- c(rep(1L, 25), rep(0L, 25))   # 25 / 50 = 50%
  foc[!buyer_mask, "S2"] <- c(rep(1L, 24), rep(0L, 26))   # 24 / 50 = 48%
  foc[buyer_mask,  "S3"] <- c(rep(1L, 10), rep(0L, 40))   # 10 / 50 = 20%
  foc[!buyer_mask, "S3"] <- c(rep(1L, 30), rep(0L, 20))   # 30 / 50 = 60%

  # Other brands: arbitrary moderate fill; not the subject under test
  b1 <- matrix(rbinom(n * 3, 1, 0.3), nrow = n, dimnames = list(NULL, stims))
  b2 <- matrix(rbinom(n * 3, 1, 0.3), nrow = n, dimnames = list(NULL, stims))

  list(
    tensor = list(FOC = foc, B1 = b1, B2 = b2),
    pen    = as.integer(buyer_mask),
    codes  = stims
  )
}


# ==============================================================================
# CLASSIFIER TRUTH TABLE
# ==============================================================================

test_that("classify_focal_read covers the locked truth table", {
  # ma_thr=5, gap_thr=5 (defaults)
  expect_equal(classify_focal_read( 8,  10), "STRENGTH")
  expect_equal(classify_focal_read( 8,   2), "FAME_GAP")
  expect_equal(classify_focal_read( 8,  -7), "FAME_GAP")
  expect_equal(classify_focal_read( 1,  10), "BUYER_EDGE")
  expect_equal(classify_focal_read(-8,  10), "WEAK")
  expect_equal(classify_focal_read(-8,  -2), "WEAK")
  expect_equal(classify_focal_read( 1,   2), "")
  expect_equal(classify_focal_read( 1,  -2), "")
})

test_that("classify_focal_read forces INSUFFICIENT when below_min_base", {
  expect_equal(classify_focal_read(8, 10, below_min_base = TRUE),
               "INSUFFICIENT")
  expect_equal(classify_focal_read(-9, 12, below_min_base = TRUE),
               "INSUFFICIENT")
})

test_that("classify_focal_read returns empty string on NA inputs", {
  expect_equal(classify_focal_read(NA_real_, 10),  "")
  expect_equal(classify_focal_read(8, NA_real_),   "")
  expect_equal(classify_focal_read(NA_real_, NA_real_), "")
})

test_that("classify_focal_read is vectorised", {
  out <- classify_focal_read(
    ma_score        = c(8,   8,   1,  -8,   1),
    buyer_gap       = c(10,  2,   10,  3,   2),
    below_min_base  = c(FALSE, FALSE, FALSE, FALSE, FALSE)
  )
  expect_equal(out, c("STRENGTH", "FAME_GAP", "BUYER_EDGE", "WEAK", ""))
})


# ==============================================================================
# BUYER GAP MATH
# ==============================================================================

test_that("calculate_ma_focal_view reproduces hand-calculated buyer gaps", {
  fx <- .fv_make_tensor()
  out <- calculate_ma_focal_view(
    linkage_tensor = fx$tensor,
    codes          = fx$codes,
    focal_brand    = "FOC",
    pen            = fx$pen,
    ma_advantage   = c(8, 1, -8),
    ma_significant = c(TRUE, FALSE, TRUE)
  )

  expect_equal(nrow(out), 3L)
  expect_equal(out$Code, c("S1", "S2", "S3"))
  expect_equal(out$Buyer_Pct,    c(80, 50, 20))
  expect_equal(out$NonBuyer_Pct, c(20, 48, 60))
  expect_equal(out$Buyer_Gap,    c(60,  2, -40))
})

test_that("calculate_ma_focal_view two-prop z agrees with formula and prop.test", {
  fx <- .fv_make_tensor()
  out <- calculate_ma_focal_view(
    linkage_tensor = fx$tensor,
    codes          = fx$codes,
    focal_brand    = "FOC",
    pen            = fx$pen
  )
  # Reference: pooled-variance two-prop z for S1
  x_buy <- 40; n_buy <- 50; x_nonbuy <- 10; n_nonbuy <- 50
  p_pool <- (x_buy + x_nonbuy) / (n_buy + n_nonbuy)
  z_ref  <- (x_buy / n_buy - x_nonbuy / n_nonbuy) /
            sqrt(p_pool * (1 - p_pool) * (1 / n_buy + 1 / n_nonbuy))
  expect_equal(out$Gap_Z[1], round(z_ref, 3), tolerance = 1e-6)

  # Independent check against prop.test(correct=FALSE); prop.test returns
  # chi-sq so z = sqrt(chi-sq) (positive root; our z is signed).
  pt <- prop.test(c(x_buy, x_nonbuy), c(n_buy, n_nonbuy), correct = FALSE)
  expect_equal(abs(out$Gap_Z[1]), round(sqrt(unname(pt$statistic)), 3), tolerance = 1e-4)

  # S2 (gap = 2pp on n=50/50) should be non-significant
  expect_false(out$Gap_Significant[2])
  # S1 (gap = 60pp on n=50/50) should be significant
  expect_true(out$Gap_Significant[1])
})


# ==============================================================================
# MIN-BASE SUPPRESSION
# ==============================================================================

test_that("calculate_ma_focal_view suppresses gap fields when buyer base < min", {
  fx <- .fv_make_tensor()
  # Force tiny buyer base by zeroing pen except for two respondents
  pen_tiny <- integer(length(fx$pen))
  pen_tiny[1:2] <- 1L

  out <- calculate_ma_focal_view(
    linkage_tensor = fx$tensor,
    codes          = fx$codes,
    focal_brand    = "FOC",
    pen            = pen_tiny,
    min_base       = 30L
  )
  expect_true(all(out$Below_Min_Base))
  expect_true(all(is.na(out$Buyer_Gap)))
  expect_true(all(is.na(out$Gap_Z)))
  expect_true(all(is.na(out$Gap_Significant)))
  expect_true(all(out$Read_Label == "INSUFFICIENT"))
  expect_equal(unique(out$N_Buyer), 2L)
})

test_that("calculate_ma_focal_view also suppresses when non-buyer base < min", {
  fx <- .fv_make_tensor()
  # Force tiny non-buyer base
  pen_dom <- rep(1L, length(fx$pen))
  pen_dom[1:5] <- 0L

  out <- calculate_ma_focal_view(
    linkage_tensor = fx$tensor,
    codes          = fx$codes,
    focal_brand    = "FOC",
    pen            = pen_dom,
    min_base       = 30L
  )
  expect_true(all(out$Below_Min_Base))
  expect_true(all(out$Read_Label == "INSUFFICIENT"))
})


# ==============================================================================
# SHAPE / EMPTY-INPUT CONTRACT
# ==============================================================================

test_that("calculate_ma_focal_view returns empty df on bad inputs", {
  expect_equal(nrow(calculate_ma_focal_view(list(), c("S1"), "FOC", c(0,1))), 0L)
  expect_equal(nrow(calculate_ma_focal_view(list(FOC = matrix(0, 4, 1,
                                                               dimnames = list(NULL, "S1"))),
                                            character(0), "FOC", c(0,1,0,1))), 0L)
  expect_equal(nrow(calculate_ma_focal_view(list(FOC = matrix(0, 4, 1,
                                                               dimnames = list(NULL, "S1"))),
                                            "S1", "ABSENT", c(0,1,0,1))), 0L)
})

test_that("calculate_ma_focal_view handles unmatched stimulus codes gracefully", {
  fx <- .fv_make_tensor()
  # Add a bogus code that's not in any brand matrix — row should come back
  # with NA gap fields and Below_Min_Base=TRUE.
  out <- calculate_ma_focal_view(
    linkage_tensor = fx$tensor,
    codes          = c("S1", "S99"),
    focal_brand    = "FOC",
    pen            = fx$pen
  )
  expect_equal(out$Code, c("S1", "S99"))
  expect_true(out$Below_Min_Base[2])
  expect_true(is.na(out$Buyer_Gap[2]))
})


# ==============================================================================
# WEIGHTED PERCENTAGES
# ==============================================================================

test_that("uniform within-group weights preserve proportions and verdict but increase z", {
  fx <- .fv_make_tensor()
  w  <- rep(1, length(fx$pen))
  w[1:50] <- 2     # double-weight the buyers

  out_unw <- calculate_ma_focal_view(
    linkage_tensor = fx$tensor, codes = fx$codes,
    focal_brand = "FOC", pen = fx$pen)
  out_w   <- calculate_ma_focal_view(
    linkage_tensor = fx$tensor, codes = fx$codes,
    focal_brand = "FOC", pen = fx$pen, weights = w)

  # Proportions identical (ratio-preserving: all buyers scaled by same factor)
  expect_equal(out_unw$Buyer_Gap, out_w$Buyer_Gap)
  # Weighted z uses larger effective n_buy (100 vs 50) → larger |z| every row
  expect_true(all(abs(out_w$Gap_Z) >= abs(out_unw$Gap_Z)))
  # Significance verdict preserved (both above / below 1.96 threshold)
  expect_equal(out_unw$Gap_Significant, out_w$Gap_Significant)
  # N_Buyer stays unweighted — it controls min-base suppression only
  expect_equal(out_unw$N_Buyer, out_w$N_Buyer)
})
