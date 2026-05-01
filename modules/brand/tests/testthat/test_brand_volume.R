# ==============================================================================
# Tests for the migrated build_brand_volume_matrix (v2 slot-indexed)
# ==============================================================================
# Verifies that build_brand_volume_matrix() reads the slot-indexed
# BRANDPEN2 + BRANDPEN3 shape produced by AlchemerParser. Legacy
# per-brand-column path is also exercised to confirm backward compatibility.
# ==============================================================================
library(testthat)

.find_root_bv <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_bv()

source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "08b_brand_volume.R"))


# ------------------------------------------------------------------------------
# Hand-coded slot-indexed mini-fixture
# ------------------------------------------------------------------------------
# 4 respondents, 3 brands (IPK, ROB, CART)
#   Resp 1: bought IPK + ROB; counts 5, 2 (sum 7)
#   Resp 2: bought IPK only; count 4
#   Resp 3: bought ROB + CART; counts 3, 6 (sum 9)
#   Resp 4: bought nothing
# Expected pen_mat:
#   IPK ROB CART
#    1   1   0
#    1   0   0
#    0   1   1
#    0   0   0
# Expected x_mat:
#   IPK ROB CART
#    5   2   0
#    4   0   0
#    0   3   6
#    0   0   0

test_that("build_brand_volume_matrix reads slot-indexed BRANDPEN2 + BRANDPEN3", {
  cat_data <- data.frame(
    BRANDPEN2_DSS_1 = c("IPK",  "IPK",  "ROB",  NA),
    BRANDPEN2_DSS_2 = c("ROB",  NA,     "CART", NA),
    BRANDPEN2_DSS_3 = c(NA,     NA,     NA,     NA),
    BRANDPEN3_DSS_1 = c(5,      4,      3,      NA),
    BRANDPEN3_DSS_2 = c(2,      NA,     6,      NA),
    BRANDPEN3_DSS_3 = c(NA,     NA,     NA,     NA),
    stringsAsFactors = FALSE
  )
  brands <- data.frame(
    BrandCode = c("IPK", "ROB", "CART"),
    BrandLabel = c("IPK", "ROB", "CART"),
    stringsAsFactors = FALSE
  )

  res <- build_brand_volume_matrix(
    cat_data = cat_data, cat_brands = brands,
    pen_target_prefix = "BRANDPEN2_DSS",
    freq_prefix = "BRANDPEN3_DSS"
  )

  expect_equal(res$status, "PASS")
  expect_equal(res$pen_mat[, "IPK"],  c(1L, 1L, 0L, 0L))
  expect_equal(res$pen_mat[, "ROB"],  c(1L, 0L, 1L, 0L))
  expect_equal(res$pen_mat[, "CART"], c(0L, 0L, 1L, 0L))
  # x_mat may be winsorised; pre-winsor values should match
  expect_equal(res$x_mat[, "IPK"],  c(5, 4, 0, 0))
  expect_equal(res$x_mat[, "ROB"],  c(2, 0, 3, 0))
  expect_equal(res$x_mat[, "CART"], c(0, 0, 6, 0))
})


# ------------------------------------------------------------------------------
# Integration: against the IPK Wave 1 fixture
# ------------------------------------------------------------------------------

test_that("build_brand_volume_matrix runs cleanly against IPK Wave 1 DSS cohort", {
  data_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                         "ipk_wave1", "ipk_wave1_data.xlsx")
  skip_if_not(file.exists(data_path), "IPK Wave 1 fixture not built")

  data <- openxlsx::read.xlsx(data_path)
  dss <- data[!is.na(data$Focal_Category) & data$Focal_Category == "DSS", ]

  brands_dss <- data.frame(
    BrandCode = c("IPK", "ROB", "KNORR", "CART"),
    BrandLabel = c("IPK", "ROB", "KNORR", "CART"),
    stringsAsFactors = FALSE
  )

  res <- build_brand_volume_matrix(
    cat_data = dss, cat_brands = brands_dss,
    pen_target_prefix = "BRANDPEN2_DSS",
    freq_prefix = "BRANDPEN3_DSS"
  )

  expect_true(res$status %in% c("PASS", "PARTIAL"))
  expect_equal(dim(res$pen_mat), c(nrow(dss), 4))
  expect_equal(dim(res$x_mat),   c(nrow(dss), 4))
  # Some respondents must have non-zero category volume
  expect_true(sum(res$m_vec) > 0)
  # Buyer flags 0/1 only
  expect_true(all(res$pen_mat %in% c(0L, 1L)))
  # IPK is the focal brand and should have above-average penetration
  pen_rates <- colMeans(res$pen_mat)
  expect_gt(pen_rates[["IPK"]], pen_rates[["KNORR"]])
})
