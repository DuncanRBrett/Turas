# ==============================================================================
# TEST: Portfolio Duplication of Awareness — 09b_portfolio_dop_awareness.R
# Coverage: hand-verified observed cells, Sharp's D OLS, expected = D * a_j,
# deviation = obs - exp, diagonal, weighted base, single-brand refusal,
# zero-awareness refusal.
# ==============================================================================

library(testthat)

local({
  find_root <- function() {
    d <- getwd()
    for (i in 1:10) {
      if (file.exists(file.path(d, "launch_turas.R")) ||
          file.exists(file.path(d, "CLAUDE.md"))) return(d)
      d <- dirname(d)
    }
    getwd()
  }
  root <- find_root()
  source(file.path(root, "modules", "brand", "R",
                   "09b_portfolio_dop_awareness.R"), local = FALSE)
})


# ==============================================================================
# Hand-verifiable fixture
# ------------------------------------------------------------------------------
# 10 cat-buyers, 4 brands. Awareness pattern is constructed so D, observed,
# expected and deviation can all be checked on paper.
#
#   Brand A: respondents 1-8   -> 80% awareness
#   Brand B: respondents 1-6   -> 60%
#   Brand C: respondents 5-9   -> 50%
#   Brand D: respondent  10    -> 10%
#
# Hand-verified cells (uniform weights):
#   obs[A,B] = 6/8 = 75%       (resp 1-6 know B among the 8 A-awares)
#   obs[B,C] = 2/6 = 33.3%     (resp 5-6 know C among the 6 B-awares)
#   obs[D,A] = 0/1 = 0%        (resp 10 not in A's 1-8)
#   D        = 25,465 / 37,800 = 0.6737 (off-diagonal OLS)
# ==============================================================================

build_fixture_am <- function() {
  am <- matrix(0L, nrow = 10, ncol = 4,
               dimnames = list(NULL, c("A", "B", "C", "D")))
  am[1:8,  "A"] <- 1L
  am[1:6,  "B"] <- 1L
  am[5:9,  "C"] <- 1L
  am[10,   "D"] <- 1L
  am
}

run_fixture <- function(weights = rep(1, 10)) {
  am <- build_fixture_am()
  .compute_dop_aware_for_cat(
    am          = am,
    brand_codes = c("A", "B", "C", "D"),
    brand_lbls  = c(A = "A", B = "B", C = "C", D = "D"),
    base_idx    = 1:10,
    weights     = weights,
    cat_code    = "TEST",
    cat_label   = "Test category"
  )
}


# ==============================================================================
# OBSERVED MATRIX — hand-verified cells
# ==============================================================================

test_that("observed cell A->B equals 75% on hand fixture", {
  res <- run_fixture()
  expect_equal(res$status, "PASS")
  expect_equal(res$observed_matrix["A", "B"], 75.0)
})

test_that("observed cell B->C equals 33.3% on hand fixture", {
  res <- run_fixture()
  expect_equal(res$observed_matrix["B", "C"], 33.3)
})

test_that("observed cell D->A equals 0% on hand fixture", {
  res <- run_fixture()
  expect_equal(res$observed_matrix["D", "A"], 0)
})

test_that("observed diagonal is 100 on every row", {
  res <- run_fixture()
  for (b in c("A", "B", "C", "D")) {
    expect_equal(res$observed_matrix[b, b], 100)
  }
})


# ==============================================================================
# SHARP'S D COEFFICIENT — hand-verified
# ==============================================================================

test_that("D coefficient equals 25465/37800 = 0.6737 on hand fixture", {
  res <- run_fixture()
  expect_equal(round(res$D, 4), 0.6737)
})

test_that("D is positive when awareness overlaps", {
  res <- run_fixture()
  expect_gt(res$D, 0)
})


# ==============================================================================
# EXPECTED = D * aware_pct
# ==============================================================================

test_that("expected matrix off-diagonal equals D * aware_pct(j)", {
  res <- run_fixture()
  for (i in c("A", "B", "C", "D")) {
    for (j in c("A", "B", "C", "D")) {
      if (i == j) {
        expect_true(is.na(res$expected_matrix[i, j]))
      } else {
        expect_equal(
          unname(res$expected_matrix[i, j]),
          unname(round(res$D * res$aware_pcts[j], 1))
        )
      }
    }
  }
})


# ==============================================================================
# DEVIATION = observed - expected (off-diagonal)
# ==============================================================================

test_that("deviation matrix equals observed minus expected on every off-diag", {
  res <- run_fixture()
  for (i in c("A", "B", "C", "D")) {
    for (j in c("A", "B", "C", "D")) {
      if (i == j) {
        expect_true(is.na(res$deviation_matrix[i, j]))
        next
      }
      o <- res$observed_matrix[i, j]
      e <- res$expected_matrix[i, j]
      d <- res$deviation_matrix[i, j]
      if (!is.na(o) && !is.na(e)) {
        expect_equal(unname(d), unname(round(o - e, 1)))
      }
    }
  }
})


# ==============================================================================
# WEIGHTED BASE — symmetry between weighting and replication
# ==============================================================================

test_that("doubling a respondent's weight matches duplicating their row", {
  # Build a 5-respondent fixture; double-weight resp 1 vs duplicating it.
  am5 <- matrix(0L, 5, 3, dimnames = list(NULL, c("A", "B", "C")))
  am5[1:4, "A"] <- 1L
  am5[1:3, "B"] <- 1L
  am5[c(2, 4, 5), "C"] <- 1L

  res_weighted <- .compute_dop_aware_for_cat(
    am = am5, brand_codes = c("A", "B", "C"),
    brand_lbls = c(A = "A", B = "B", C = "C"),
    base_idx = 1:5,
    weights = c(2, 1, 1, 1, 1),
    cat_code = "T", cat_label = "T"
  )

  am6 <- rbind(am5[1, , drop = FALSE], am5)
  res_dup <- .compute_dop_aware_for_cat(
    am = am6, brand_codes = c("A", "B", "C"),
    brand_lbls = c(A = "A", B = "B", C = "C"),
    base_idx = 1:6,
    weights = rep(1, 6),
    cat_code = "T", cat_label = "T"
  )

  expect_equal(round(res_weighted$aware_pcts, 4),
               round(res_dup$aware_pcts, 4))
  expect_equal(round(res_weighted$observed_matrix, 4),
               round(res_dup$observed_matrix, 4))
  expect_equal(round(res_weighted$D, 4),
               round(res_dup$D, 4))
})


# ==============================================================================
# REFUSALS
# ==============================================================================

test_that("single-brand fixture refuses with CALC_DOA_TOO_SPARSE", {
  am <- matrix(0L, 5, 1, dimnames = list(NULL, "A"))
  am[1:3, 1] <- 1L
  res <- .compute_dop_aware_for_cat(
    am = am, brand_codes = "A", brand_lbls = c(A = "A"),
    base_idx = 1:5, weights = rep(1, 5),
    cat_code = "T", cat_label = "T"
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CALC_DOA_TOO_SPARSE")
})

test_that("zero-awareness fixture refuses with CALC_DOA_TOO_SPARSE", {
  am <- matrix(0L, 5, 3, dimnames = list(NULL, c("A", "B", "C")))
  res <- .compute_dop_aware_for_cat(
    am = am, brand_codes = c("A", "B", "C"),
    brand_lbls = c(A = "A", B = "B", C = "C"),
    base_idx = 1:5, weights = rep(1, 5),
    cat_code = "T", cat_label = "T"
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CALC_DOA_TOO_SPARSE")
})

test_that("empty awareness matrix refuses with CALC_DOA_NO_MATRIX", {
  res <- .compute_dop_aware_for_cat(
    am = NULL, brand_codes = character(0),
    brand_lbls = character(0),
    base_idx = integer(0), weights = numeric(0),
    cat_code = "T", cat_label = "T"
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CALC_DOA_NO_MATRIX")
})

test_that("zero weighted base refuses with CALC_DOA_ZERO_BASE", {
  am <- build_fixture_am()
  res <- .compute_dop_aware_for_cat(
    am = am, brand_codes = c("A", "B", "C", "D"),
    brand_lbls = c(A = "A", B = "B", C = "C", D = "D"),
    base_idx = 1:10,
    weights = rep(0, 10),
    cat_code = "T", cat_label = "T"
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CALC_DOA_ZERO_BASE")
})


# ==============================================================================
# LOW-BASE FLAG
# ==============================================================================

test_that("brand with weighted aware count below threshold is flagged", {
  res <- run_fixture()
  # Brand D has 1 weighted aware respondent < DOA_ROW_LOW_BASE (30).
  expect_true("D" %in% res$low_base_brands)
  # Brand A has 8 weighted aware; also below 30, also flagged.
  expect_true("A" %in% res$low_base_brands)
})
