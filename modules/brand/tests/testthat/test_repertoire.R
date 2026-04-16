# ==============================================================================
# BRAND MODULE TESTS - REPERTOIRE ELEMENT
# ==============================================================================

.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
TURAS_ROOT <- .find_turas_root_for_test()
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "04_repertoire.R"))


# ==============================================================================
# KNOWN-DATA TESTS
# ==============================================================================

test_that("repertoire size distribution is correct for known data", {
  # 6 respondents, 3 brands
  # Resp 1: buys A only (sole loyal)
  # Resp 2: buys A + B
  # Resp 3: buys A + B + C
  # Resp 4: buys B only
  # Resp 5: buys nothing (not a buyer)
  # Resp 6: buys A + C
  pen <- matrix(c(
    1, 0, 0,  # resp 1
    1, 1, 0,  # resp 2
    1, 1, 1,  # resp 3
    0, 1, 0,  # resp 4
    0, 0, 0,  # resp 5
    1, 0, 1   # resp 6
  ), nrow = 6, ncol = 3, byrow = TRUE)

  result <- run_repertoire(pen, c("A", "B", "C"), focal_brand = "A")

  expect_equal(result$status, "PASS")
  expect_equal(result$n_buyers, 5)

  # Distribution: 2 bought 1 brand, 2 bought 2, 1 bought 3
  expect_equal(result$repertoire_size$Count[1], 2)  # 1 brand
  expect_equal(result$repertoire_size$Count[2], 2)  # 2 brands
  expect_equal(result$repertoire_size$Count[3], 1)  # 3 brands

  # Mean: (1+2+3+1+2)/5 = 9/5 = 1.8
  expect_equal(result$mean_repertoire, 1.8)
})

test_that("sole loyalty is correct for known data", {
  pen <- matrix(c(
    1, 0, 0,  # sole A
    1, 1, 0,  # shared A+B
    1, 1, 1,  # shared all
    0, 1, 0,  # sole B
    0, 0, 0,  # non-buyer
    1, 0, 1   # shared A+C
  ), nrow = 6, ncol = 3, byrow = TRUE)

  result <- run_repertoire(pen, c("A", "B", "C"))

  # A: 4 buyers, 1 sole loyal -> 25%
  expect_equal(result$sole_loyalty$SoleLoyalty_Pct[
    result$sole_loyalty$BrandCode == "A"], 25)

  # B: 3 buyers, 1 sole loyal -> 33.3%
  expect_equal(result$sole_loyalty$SoleLoyalty_Pct[
    result$sole_loyalty$BrandCode == "B"], round(1/3 * 100, 1))

  # C: 2 buyers, 0 sole loyal -> 0%
  expect_equal(result$sole_loyalty$SoleLoyalty_Pct[
    result$sole_loyalty$BrandCode == "C"], 0)
})

test_that("brand overlap with focal brand is correct", {
  pen <- matrix(c(
    1, 0, 0,  # A only
    1, 1, 0,  # A + B
    1, 1, 1,  # A + B + C
    0, 1, 0,  # B only (not a focal buyer)
    1, 0, 1   # A + C
  ), nrow = 5, ncol = 3, byrow = TRUE)

  result <- run_repertoire(pen, c("A", "B", "C"), focal_brand = "A")

  # 4 focal brand (A) buyers
  # B overlap: 2 of 4 = 50%
  expect_equal(result$brand_overlap$Overlap_Pct[
    result$brand_overlap$BrandCode == "B"], 50)
  # C overlap: 2 of 4 = 50%
  expect_equal(result$brand_overlap$Overlap_Pct[
    result$brand_overlap$BrandCode == "C"], 50)
})

test_that("share of requirements is correct", {
  pen <- matrix(c(
    1, 0,   # buys A only
    1, 1    # buys A + B
  ), nrow = 2, ncol = 2, byrow = TRUE)

  # Frequency: resp 1 buys A 5x, resp 2 buys A 3x + B 7x
  freq <- matrix(c(
    5, 0,   # resp 1: A=5, B=0
    3, 7    # resp 2: A=3, B=7
  ), nrow = 2, ncol = 2, byrow = TRUE)

  result <- run_repertoire(pen, c("A", "B"), frequency_matrix = freq)

  # A's SoR among A buyers:
  # resp 1: 5/5 = 100%
  # resp 2: 3/10 = 30%
  # mean: (100 + 30)/2 = 65%
  expect_equal(result$share_of_requirements$SoR_Pct[
    result$share_of_requirements$BrandCode == "A"], 65)
})


# ==============================================================================
# EDGE CASES
# ==============================================================================

test_that("repertoire refuses empty data", {
  result <- run_repertoire(NULL, c("A"))
  expect_equal(result$status, "REFUSED")
})

test_that("repertoire refuses when no buyers", {
  pen <- matrix(0, nrow = 5, ncol = 3)
  result <- run_repertoire(pen, c("A", "B", "C"))
  expect_equal(result$status, "REFUSED")
})

test_that("repertoire handles single brand", {
  pen <- matrix(c(1, 1, 0, 1), ncol = 1)
  result <- run_repertoire(pen, "A", focal_brand = "A")

  expect_equal(result$status, "PASS")
  expect_equal(result$mean_repertoire, 1)
  expect_equal(result$sole_loyalty$SoleLoyalty_Pct, 100)
  # No other brands to overlap with, so overlap should be empty
  expect_true(is.null(result$brand_overlap) || nrow(result$brand_overlap) == 0)
})

test_that("repertoire with weights", {
  pen <- matrix(c(
    1, 0,   # buys A
    0, 1    # buys B
  ), nrow = 2, ncol = 2, byrow = TRUE)

  # Unweighted: mean repertoire = 1
  result_unw <- run_repertoire(pen, c("A", "B"))
  expect_equal(result_unw$mean_repertoire, 1)

  # Weights shouldn't change mean repertoire when everyone buys 1 brand
  result_wtd <- run_repertoire(pen, c("A", "B"), weights = c(3, 1))
  expect_equal(result_wtd$mean_repertoire, 1)
})

test_that("repertoire metrics_summary is populated", {
  pen <- matrix(c(1, 0, 1, 1, 0, 1), nrow = 3, ncol = 2, byrow = TRUE)
  result <- run_repertoire(pen, c("A", "B"), focal_brand = "A")

  ms <- result$metrics_summary
  expect_equal(ms$focal_brand, "A")
  expect_true(is.numeric(ms$mean_repertoire))
  expect_true(is.numeric(ms$pct_single_brand))
  expect_true(is.numeric(ms$n_buyers))
})
