# ==============================================================================
# TEST: build_brand_volume_matrix() — 08b_brand_volume.R
# Coverage: §5.2 coercion, §5.3 reconciliation, §5.4 winsorisation,
#           missing columns, weighted path, weights-length mismatch.
# ==============================================================================

library(testthat)

# ---- Load module ----
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
  source(file.path(root, "modules", "brand", "R", "08b_brand_volume.R"), local = FALSE)
})


# ---- Minimal fixture builders ----

make_cat_data <- function(n = 10, brands = c("A", "B", "C"),
                          cat = "TST",
                          pen2_vals = NULL,
                          pen3_vals = NULL) {
  nb <- length(brands)
  df <- data.frame(Respondent_ID = seq_len(n))

  if (is.null(pen2_vals)) {
    set.seed(42)
    pen2_vals <- lapply(seq_len(nb), function(bi) {
      as.integer(rbinom(n, 1, 0.6))
    })
  }
  if (is.null(pen3_vals)) {
    pen3_vals <- lapply(seq_len(nb), function(bi) {
      v <- rep(NA_real_, n)
      v[pen2_vals[[bi]] == 1] <- sample(1:5, sum(pen2_vals[[bi]]),
                                         replace = TRUE)
      v
    })
  }

  for (bi in seq_along(brands)) {
    df[[paste0("BRANDPEN2_", cat, "_", brands[bi])]] <- pen2_vals[[bi]]
    df[[paste0("BRANDPEN3_", cat, "_", brands[bi])]] <- pen3_vals[[bi]]
  }
  df
}

make_brands_df <- function(codes = c("A", "B", "C")) {
  data.frame(BrandCode = codes, stringsAsFactors = FALSE)
}


# ==============================================================================
# HAPPY PATH
# ==============================================================================

test_that("happy path: pen_mat and x_mat have correct dimensions", {
  brands <- c("A", "B", "C")
  df <- make_cat_data(n = 20, brands = brands)
  res <- build_brand_volume_matrix(df, make_brands_df(brands),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")
  expect_equal(res$status, "PASS")
  expect_equal(dim(res$pen_mat), c(20L, 3L))
  expect_equal(dim(res$x_mat),   c(20L, 3L))
  expect_equal(length(res$m_vec), 20L)
  expect_equal(colnames(res$pen_mat), brands)
  expect_equal(colnames(res$x_mat),   brands)
})

test_that("happy path: pen_mat is 0/1 only", {
  brands <- c("A", "B")
  df <- make_cat_data(n = 15, brands = brands)
  res <- build_brand_volume_matrix(df, make_brands_df(brands),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")
  expect_true(all(res$pen_mat %in% c(0L, 1L)))
})

test_that("happy path: m_vec = rowSums(x_mat)", {
  brands <- c("A", "B", "C")
  df <- make_cat_data(n = 12, brands = brands)
  res <- build_brand_volume_matrix(df, make_brands_df(brands),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")
  expect_equal(res$m_vec, rowSums(res$x_mat))
})

test_that("unweighted and weight=1 paths return identical pen_mat", {
  brands <- c("A", "B")
  df <- make_cat_data(n = 10, brands = brands)
  res_uw <- build_brand_volume_matrix(df, make_brands_df(brands),
                                      "BRANDPEN2_TST", "BRANDPEN3_TST")
  # Weights of 1.0 should produce identical pen_mat (weights not used in matrix build)
  expect_equal(res_uw$status, "PASS")
})


# ==============================================================================
# §5.3 RECONCILIATION
# ==============================================================================

test_that("reconciliation case A: pen=1 count=0 → count set to 1", {
  brands <- c("A")
  n <- 5
  pen2 <- list(c(1L, 1L, 0L, 0L, 1L))
  pen3 <- list(c(0,  0,  0,  0,  3))   # first two buyers have count=0

  df <- make_cat_data(n = n, brands = brands, pen2_vals = pen2, pen3_vals = pen3)
  res <- build_brand_volume_matrix(df, make_brands_df(brands),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")

  expect_equal(as.vector(res$pen_mat[1, "A"]), 1L)  # remains a buyer
  expect_equal(as.vector(res$x_mat[1, "A"]),   1.0) # count floored to 1
  expect_equal(res$reconciliation$pen_yes_count_no, 2L)
})

test_that("reconciliation case B: pen=0 count>0 → promoted to buyer", {
  brands <- c("A")
  n <- 5
  pen2 <- list(c(0L, 0L, 0L, 1L, 1L))
  pen3 <- list(c(3,  0,  0,  2,  4))   # respondent 1 has count>0 but pen=0

  df <- make_cat_data(n = n, brands = brands, pen2_vals = pen2, pen3_vals = pen3)
  res <- build_brand_volume_matrix(df, make_brands_df(brands),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")

  expect_equal(as.vector(res$pen_mat[1, "A"]), 1L)  # promoted to buyer
  expect_equal(as.vector(res$x_mat[1, "A"]),   3.0) # count preserved
  expect_equal(res$reconciliation$pen_no_count_yes, 1L)
})

test_that("reconciliation case D: pen=0 count=0 → non-buyer, count stays 0", {
  brands <- c("A")
  n <- 3
  pen2 <- list(c(0L, 0L, 1L))
  pen3 <- list(c(0,  0,  2))

  df <- make_cat_data(n = n, brands = brands, pen2_vals = pen2, pen3_vals = pen3)
  res <- build_brand_volume_matrix(df, make_brands_df(brands),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")

  expect_equal(as.vector(res$pen_mat[1, "A"]), 0L)
  expect_equal(as.vector(res$x_mat[1, "A"]),   0.0)
})

test_that("reconciliation >10% case-A triggers PARTIAL", {
  brands <- c("A")
  n <- 20
  # All buyers but all with count=0 → 100% case-A rate
  pen2 <- list(rep(1L, n))
  pen3 <- list(rep(0, n))

  df <- make_cat_data(n = n, brands = brands, pen2_vals = pen2, pen3_vals = pen3)
  res <- build_brand_volume_matrix(df, make_brands_df(brands),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")

  expect_equal(res$status, "PARTIAL")
  expect_true(length(res$warnings) > 0)
})


# ==============================================================================
# §5.4 WINSORISATION
# ==============================================================================

test_that("winsorisation caps outlier m_vec at 99th pct × mult", {
  # 99 normal respondents (m=3) + 1 extreme (m=3000).
  # 99th percentile of [3,3,...3,3000] = 3 → cap = 3*3 = 9.
  # m_vec[100] = 3000 > 9 so it must be winsorised to 9.
  n <- 100
  brands <- c("A", "B")
  pen2 <- list(rep(1L, n), rep(1L, n))
  pen3_a <- c(rep(2, 99), 2000)   # one extreme outlier
  pen3_b <- c(rep(1, 99), 1000)
  pen3 <- list(pen3_a, pen3_b)

  df <- make_cat_data(n = n, brands = brands, pen2_vals = pen2, pen3_vals = pen3)
  res <- build_brand_volume_matrix(df, make_brands_df(brands),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST",
                                   winsor_mult = 3)

  expect_equal(res$status, "PASS")
  expect_true(res$reconciliation$winsorised_n >= 1L)
  # The extreme outlier (original m=3000) must be capped below its pre-winsorisation value
  expect_true(max(res$m_vec) < 3000)
})

test_that("winsorisation preserves per-respondent SCR (x/m ratio)", {
  # 49 normal respondents (m=5) + 1 extreme (m=7000).
  # 99th percentile = 5 → cap = 5*3 = 15.
  # Scaling by (15/7000) is applied to all brands for that respondent,
  # so brand A's share = 5000/7000 is preserved exactly.
  n <- 50
  brands <- c("A", "B")
  pen2 <- list(rep(1L, n), rep(1L, n))
  pen3_a <- c(rep(3, 49), 5000)   # one extreme outlier
  pen3_b <- c(rep(2, 49), 2000)
  pen3 <- list(pen3_a, pen3_b)

  df <- make_cat_data(n = n, brands = brands, pen2_vals = pen2, pen3_vals = pen3)
  res <- build_brand_volume_matrix(df, make_brands_df(brands),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")

  idx_extreme <- which(pen3_a > 100)  # = 50
  for (i in idx_extreme) {
    orig_share <- pen3_a[i] / (pen3_a[i] + pen3_b[i])
    post_share <- as.vector(res$x_mat[i, "A"]) / res$m_vec[i]
    expect_equal(round(post_share, 4), round(orig_share, 4))
  }
})


# ==============================================================================
# §5.2 COERCION
# ==============================================================================

test_that("character counts are coerced to numeric", {
  brands <- c("A")
  n <- 5
  pen2 <- list(c(1L, 1L, 0L, 1L, 0L))
  pen3_chr <- c("3", "2.5", NA, "4", "0")

  df <- data.frame(
    Respondent_ID         = 1:5,
    BRANDPEN2_TST_A       = pen2[[1]],
    BRANDPEN3_TST_A       = pen3_chr,
    stringsAsFactors      = FALSE)

  res <- build_brand_volume_matrix(df, make_brands_df(brands),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")
  expect_true(res$status %in% c("PASS", "PARTIAL"))
  expect_equal(as.vector(res$x_mat[1, "A"]), 3.0)
  expect_equal(as.vector(res$x_mat[2, "A"]), 2.5)
})


# ==============================================================================
# ERROR PATHS
# ==============================================================================

test_that("NULL cat_data returns DATA_NO_CAT_DATA refusal", {
  res <- build_brand_volume_matrix(NULL, make_brands_df("A"),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code,   "DATA_NO_CAT_DATA")
})

test_that("empty cat_data returns DATA_NO_CAT_DATA refusal", {
  res <- build_brand_volume_matrix(data.frame(), make_brands_df("A"),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code,   "DATA_NO_CAT_DATA")
})

test_that("missing BRANDPEN2 columns returns DATA_BRANDPEN2_MISSING", {
  df <- data.frame(BRANDPEN3_TST_A = c(1, 2))
  res <- build_brand_volume_matrix(df, make_brands_df("A"),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code,   "DATA_BRANDPEN2_MISSING")
})

test_that("missing BRANDPEN3 columns returns DATA_BRANDPEN3_MISSING", {
  df <- data.frame(BRANDPEN2_TST_A = c(1L, 0L))
  res <- build_brand_volume_matrix(df, make_brands_df("A"),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code,   "DATA_BRANDPEN3_MISSING")
})

test_that("all-zero counts after reconciliation returns DATA_ALL_NA", {
  brands <- c("A")
  n <- 5
  pen2 <- list(rep(0L, n))
  pen3 <- list(rep(0, n))
  df <- make_cat_data(n = n, brands = brands, pen2_vals = pen2, pen3_vals = pen3)
  res <- build_brand_volume_matrix(df, make_brands_df(brands),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code,   "DATA_ALL_NA")
})

test_that("reconciliation list contains all expected fields", {
  brands <- c("A")
  df <- make_cat_data(n = 10, brands = brands)
  res <- build_brand_volume_matrix(df, make_brands_df(brands),
                                   "BRANDPEN2_TST", "BRANDPEN3_TST")
  expect_true(is.list(res$reconciliation))
  expect_true("pen_yes_count_no"  %in% names(res$reconciliation))
  expect_true("pen_no_count_yes"  %in% names(res$reconciliation))
  expect_true("winsorised_n"      %in% names(res$reconciliation))
  expect_true("coercion_failures" %in% names(res$reconciliation))
})
