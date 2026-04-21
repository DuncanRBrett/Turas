# ==============================================================================
# TEST: run_buyer_heaviness() — 08d_buyer_heaviness.R
# Coverage: tertile counts, NMI = 100 for category-identical mix,
#           empty brand (no buyers), DATA_ALL_SAME_M, weighted path.
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
  source(file.path(root, "modules", "brand", "R", "08d_buyer_heaviness.R"), local = FALSE)
})


# ---- Helpers ----

make_pen_m <- function(n, brands, buy_probs, m_vec) {
  nb <- length(brands)
  pen_mat <- matrix(0L, n, nb, dimnames = list(NULL, brands))
  for (bi in seq_along(brands)) {
    pen_mat[, bi] <- as.integer(rbinom(n, 1, buy_probs[bi]))
  }
  # m_vec is supplied directly; pen_mat defines buyers
  list(pen_mat = pen_mat, m_vec = m_vec)
}


# ==============================================================================
# TERTILE STRUCTURE
# ==============================================================================

test_that("tertile counts sum to n_buyers", {
  set.seed(1)
  n <- 90
  brands <- c("A", "B")
  pen_mat <- matrix(1L, n, 2, dimnames = list(NULL, brands))
  m_vec   <- sample(1:15, n, replace = TRUE)

  res <- run_buyer_heaviness(pen_mat, m_vec, brands)
  expect_equal(res$status, "PASS")
  total_n <- sum(res$category_buyer_mix$n)
  expect_equal(total_n, n)  # all are buyers (pen_mat all 1)
})

test_that("tertile Pct values sum to approximately 100", {
  set.seed(3)
  n <- 60
  brands <- c("A", "B", "C")
  pen_mat <- matrix(1L, n, 3, dimnames = list(NULL, brands))
  m_vec   <- runif(n, 1, 20)

  res <- run_buyer_heaviness(pen_mat, m_vec, brands)
  expect_equal(res$status, "PASS")
  expect_equal(round(sum(res$category_buyer_mix$Pct)), 100)
})

test_that("tertile bounds have q33 < q67", {
  set.seed(5)
  n <- 45
  brands <- c("A", "B")
  pen_mat <- matrix(1L, n, 2, dimnames = list(NULL, brands))
  m_vec   <- seq(1, 45)

  res <- run_buyer_heaviness(pen_mat, m_vec, brands)
  expect_equal(res$status, "PASS")
  expect_true(res$tertile_bounds$light[2] < res$tertile_bounds$heavy[1])
})


# ==============================================================================
# NATURAL MONOPOLY INDEX
# ==============================================================================

test_that("NMI = 100 for brand whose buyer mix equals category mix", {
  # If brand's light/med/heavy = category's light/med/heavy, NMI = 1.0 * 100
  set.seed(9)
  n <- 90
  brands <- c("A", "B")
  # Make brand A buyers = all buyers (pen=1 for all)
  pen_mat <- matrix(1L, n, 2, dimnames = list(NULL, brands))
  m_vec   <- sample(1:10, n, replace = TRUE)

  res <- run_buyer_heaviness(pen_mat, m_vec, brands)
  # When brand buyers = all buyers, NMI must equal 100
  nmi_A <- res$brand_heaviness$NaturalMonopolyIndex[res$brand_heaviness$BrandCode == "A"]
  expect_equal(round(nmi_A, 1), 100.0)
})


# ==============================================================================
# EMPTY BRAND (no buyers)
# ==============================================================================

test_that("brand with zero buyers returns NA row, not dropped", {
  n <- 20
  brands <- c("A", "B", "C")
  pen_mat <- matrix(0L, n, 3, dimnames = list(NULL, brands))
  pen_mat[, 1] <- 1L   # only A has buyers
  pen_mat[1:10, 2] <- 1L
  # C has no buyers
  m_vec <- rowSums(pen_mat) * sample(1:5, n, replace = TRUE)

  res <- run_buyer_heaviness(pen_mat, m_vec, brands)
  expect_equal(res$status, "PASS")
  expect_true("C" %in% res$brand_heaviness$BrandCode)
  expect_true(is.na(res$brand_heaviness$NaturalMonopolyIndex[
    res$brand_heaviness$BrandCode == "C"]))
  expect_equal(res$brand_heaviness$Brand_Buyers_n[
    res$brand_heaviness$BrandCode == "C"], 0L)
})


# ==============================================================================
# DATA_ALL_SAME_M
# ==============================================================================

test_that("all-same m_vec returns PARTIAL with single-tier message", {
  n <- 30
  brands <- c("A", "B")
  pen_mat <- matrix(1L, n, 2, dimnames = list(NULL, brands))
  m_vec   <- rep(5, n)

  res <- run_buyer_heaviness(pen_mat, m_vec, brands)
  expect_equal(res$status, "PARTIAL")
  expect_true(length(res$warnings) > 0)
  expect_equal(res$category_buyer_mix$Tier, "All")
})


# ==============================================================================
# NO BUYERS
# ==============================================================================

test_that("all-zero m_vec returns DATA_NO_BUYERS refusal", {
  n <- 10
  brands <- c("A", "B")
  pen_mat <- matrix(0L, n, 2, dimnames = list(NULL, brands))
  m_vec   <- rep(0, n)

  res <- run_buyer_heaviness(pen_mat, m_vec, brands)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "DATA_NO_BUYERS")
})

test_that("NULL pen_mat returns DATA_NO_BUYERS refusal", {
  res <- run_buyer_heaviness(NULL, NULL, c("A"))
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "DATA_NO_BUYERS")
})


# ==============================================================================
# WEIGHTED PATH
# ==============================================================================

test_that("weighted path returns PASS and valid tertile Pct", {
  set.seed(77)
  n <- 60
  brands <- c("A", "B", "C")
  pen_mat <- matrix(1L, n, 3, dimnames = list(NULL, brands))
  m_vec   <- sample(1:20, n, replace = TRUE)
  w <- runif(n, 0.5, 1.5)

  res <- run_buyer_heaviness(pen_mat, m_vec, brands, weights = w)
  expect_equal(res$status, "PASS")
  expect_equal(round(sum(res$category_buyer_mix$Pct)), 100)
})

test_that("brand_heaviness has all required columns", {
  n <- 30
  brands <- c("A", "B")
  pen_mat <- matrix(1L, n, 2, dimnames = list(NULL, brands))
  m_vec   <- sample(1:10, n, replace = TRUE)

  res <- run_buyer_heaviness(pen_mat, m_vec, brands)
  expected_cols <- c("BrandCode", "Heavy_Pct", "Medium_Pct", "Light_Pct",
                     "WBar_Brand", "WBar_Category", "WBar_Gap",
                     "NaturalMonopolyIndex", "Brand_Buyers_n")
  expect_true(all(expected_cols %in% names(res$brand_heaviness)))
})

test_that("metrics_summary focal fields populated when focal brand present", {
  set.seed(33)
  n <- 45
  brands <- c("FOCAL", "COMP")
  pen_mat <- matrix(1L, n, 2, dimnames = list(NULL, brands))
  m_vec   <- sample(1:12, n, replace = TRUE)

  res <- run_buyer_heaviness(pen_mat, m_vec, brands, focal_brand = "FOCAL")
  expect_equal(res$metrics_summary$focal_brand, "FOCAL")
  expect_false(is.na(res$metrics_summary$focal_nmi))
  expect_false(is.na(res$metrics_summary$focal_wbar))
})
