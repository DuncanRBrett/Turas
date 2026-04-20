# ==============================================================================
# BRAND MODULE TESTS - CATEGORY BUYING FREQUENCY
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
source(file.path(TURAS_ROOT, "modules", "brand", "R", "08_cat_buying.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "04_repertoire.R"))

# Helper: minimal cat_buy_scale option map matching IPK 1-5 scale
.make_option_map <- function() {
  data.frame(
    Scale      = rep("cat_buy_scale", 5),
    ClientCode = as.character(1:5),
    Role       = c("cat_buy_scale.several_week",
                   "cat_buy_scale.once_week",
                   "cat_buy_scale.few_month",
                   "cat_buy_scale.monthly_less",
                   "cat_buy_scale.never"),
    ClientLabel = c("Several times a week",
                    "About once a week",
                    "A few times a month",
                    "Monthly or less",
                    "Never buy"),
    OrderIndex  = 1:5,
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# run_cat_buying_frequency — guard tests
# ==============================================================================

test_that("refuses NULL data", {
  result <- run_cat_buying_frequency(NULL)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code,   "DATA_NO_FREQ_DATA")
})

test_that("refuses empty vector", {
  result <- run_cat_buying_frequency(character(0))
  expect_equal(result$status, "REFUSED")
})

test_that("refuses all-NA data", {
  result <- run_cat_buying_frequency(c(NA, NA, NA))
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_ALL_NA")
})

test_that("refuses mismatched weights", {
  result <- run_cat_buying_frequency(c(1, 2, 3), weights = c(1, 2))
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_WEIGHTS_MISMATCH")
})


# ==============================================================================
# run_cat_buying_frequency — known-data tests (labelled scale)
# ==============================================================================

test_that("known distribution matches hand-calculated percentages", {
  # 10 respondents: codes 1-5 with counts 2, 2, 3, 2, 1
  freq_data <- c(1, 1, 2, 2, 3, 3, 3, 4, 4, 5)
  omap <- .make_option_map()

  result <- run_cat_buying_frequency(freq_data, omap)

  expect_equal(result$status,        "PASS")
  expect_equal(result$n_respondents, 10L)

  dist <- result$distribution
  expect_equal(nrow(dist), 5)

  # Check specific row %
  expect_equal(dist$Pct[dist$Code == "1"], 20)   # 2/10
  expect_equal(dist$Pct[dist$Code == "3"], 30)   # 3/10
  expect_equal(dist$Pct[dist$Code == "5"], 10)   # 1/10

  # Labels populated from option map
  expect_equal(dist$Label[dist$Code == "1"], "Several times a week")
  expect_equal(dist$Label[dist$Code == "5"], "Never buy")
})

test_that("mean_freq is correctly computed", {
  # 4 respondents: 1=several_week(12), 2=once_week(4), 3=few_month(2), 5=never(0)
  freq_data <- c(1, 2, 3, 5)
  omap <- .make_option_map()

  result <- run_cat_buying_frequency(freq_data, omap)

  expect_equal(result$status, "PASS")
  # mean(12, 4, 2, 0) = 18/4 = 4.5
  expect_equal(result$mean_freq, 4.5)
})

test_that("pct_buyers excludes never-buy respondents", {
  # 5 respondents: 3 buyers (codes 1-3) + 2 never (code 5)
  freq_data <- c(1, 2, 3, 5, 5)
  omap <- .make_option_map()

  result <- run_cat_buying_frequency(freq_data, omap)

  expect_equal(result$status,   "PASS")
  expect_equal(result$n_buyers, 3L)
  expect_equal(result$pct_buyers, 60)  # 3/5
})

test_that("works without option_map (fallback to unique codes)", {
  freq_data <- c(1, 1, 2, 3, 5)
  result    <- run_cat_buying_frequency(freq_data, option_map = NULL)

  expect_equal(result$status, "PASS")
  expect_equal(nrow(result$distribution), 4L)  # 4 unique codes
  expect_true(all(result$distribution$Role == ""))
  expect_true(is.na(result$mean_freq))
  expect_true(is.na(result$pct_buyers))
})


# ==============================================================================
# run_cat_buying_frequency — weighted tests
# ==============================================================================

test_that("weighted distribution sums to 100%", {
  freq_data <- c(1, 2, 3, 5)
  weights   <- c(2, 1, 1, 2)   # total weight = 6
  omap      <- .make_option_map()

  result <- run_cat_buying_frequency(freq_data, omap, weights = weights)

  expect_equal(result$status, "PASS")
  expect_equal(sum(result$distribution$Pct), 100)
})

test_that("weighted mean_freq differs from unweighted when weights vary", {
  freq_data   <- c(1, 5)           # one heavy buyer, one non-buyer
  omap        <- .make_option_map()
  unwt_result <- run_cat_buying_frequency(freq_data, omap)
  wt_result   <- run_cat_buying_frequency(freq_data, omap, weights = c(3, 1))

  # Unweighted mean: (12 + 0) / 2 = 6
  expect_equal(unwt_result$mean_freq, 6)
  # Weighted mean: (3*12 + 1*0) / 4 = 9
  expect_equal(wt_result$mean_freq, 9)
})


# ==============================================================================
# crossover_matrix in run_repertoire
# ==============================================================================

test_that("crossover_matrix is NULL for single-brand data", {
  pen    <- matrix(c(1, 1, 0), ncol = 1)
  result <- run_repertoire(pen, "A", focal_brand = "A")
  expect_null(result$crossover_matrix)
})

test_that("crossover_matrix diagonal is 100 for each brand", {
  pen <- matrix(c(
    1, 0, 0,
    1, 1, 0,
    1, 1, 1
  ), nrow = 3, ncol = 3, byrow = TRUE)
  result <- run_repertoire(pen, c("A", "B", "C"), focal_brand = "A")

  cm <- result$crossover_matrix
  expect_false(is.null(cm))
  expect_equal(cm$A[cm$BrandCode == "A"], 100)
  expect_equal(cm$B[cm$BrandCode == "B"], 100)
  expect_equal(cm$C[cm$BrandCode == "C"], 100)
})

test_that("crossover_matrix values match manual calculation", {
  # 4 buyers:
  # Resp 1: A only
  # Resp 2: A + B
  # Resp 3: A + B + C
  # Resp 4: B + C
  pen <- matrix(c(
    1, 0, 0,
    1, 1, 0,
    1, 1, 1,
    0, 1, 1
  ), nrow = 4, ncol = 3, byrow = TRUE)

  result <- run_repertoire(pen, c("A", "B", "C"), focal_brand = "A")
  cm <- result$crossover_matrix

  # A buyers (rows 1-3): 3 total. B overlap = rows 2+3 = 2/3 = 66.7%
  expect_equal(cm$B[cm$BrandCode == "A"], round(2/3 * 100, 1))

  # B buyers (rows 2-4): 3 total. A overlap = rows 2+3 = 2/3 = 66.7%
  expect_equal(cm$A[cm$BrandCode == "B"], round(2/3 * 100, 1))

  # C buyers (rows 3-4): 2 total. A overlap = row 3 only = 1/2 = 50%
  expect_equal(cm$A[cm$BrandCode == "C"], 50)
})

test_that("crossover_matrix has BrandCode column + one column per brand", {
  pen <- matrix(c(1, 0, 1, 1), nrow = 2, ncol = 2, byrow = TRUE)
  result <- run_repertoire(pen, c("A", "B"))
  cm <- result$crossover_matrix

  expect_true("BrandCode" %in% names(cm))
  expect_true("A" %in% names(cm))
  expect_true("B" %in% names(cm))
  expect_equal(nrow(cm), 2L)
})

test_that("crossover_matrix respects weights", {
  pen <- matrix(c(
    1, 1,   # resp 1 buys both
    1, 0    # resp 2 buys A only
  ), nrow = 2, ncol = 2, byrow = TRUE)
  weights <- c(1, 3)   # resp 2 counts 3x

  result_unwt <- run_repertoire(pen, c("A", "B"))
  result_wt   <- run_repertoire(pen, c("A", "B"), weights = weights)

  # Unweighted: A buyers = 2, both buy A; B overlap = 1/2 = 50%
  expect_equal(result_unwt$crossover_matrix$B[
    result_unwt$crossover_matrix$BrandCode == "A"], 50)

  # Weighted: A buyers weighted = 1+3=4; B overlap weight = 1/4 = 25%
  expect_equal(result_wt$crossover_matrix$B[
    result_wt$crossover_matrix$BrandCode == "A"], 25)
})


# ==============================================================================
# brand_repertoire_profile in run_repertoire
# ==============================================================================

test_that("brand_repertoire_profile is present and has correct columns", {
  pen <- matrix(c(
    1, 0, 0,
    1, 1, 0,
    1, 1, 1,
    0, 1, 0
  ), nrow = 4, ncol = 3, byrow = TRUE)
  result <- run_repertoire(pen, c("A", "B", "C"), focal_brand = "A")

  brp <- result$brand_repertoire_profile
  expect_false(is.null(brp))
  expect_true(all(c("BrandCode", "Brand_Buyers_n", "Sole_Pct",
                    "Dual_Pct", "Multi_Pct", "Mean_Repertoire") %in% names(brp)))
  expect_equal(nrow(brp), 3L)
})

test_that("brand_repertoire_profile sole + dual + multi sums to 100 for each brand", {
  pen <- matrix(c(
    1, 0, 0,   # A sole
    1, 1, 0,   # A + B dual
    1, 1, 1,   # A + B + C multi
    0, 1, 0    # B sole
  ), nrow = 4, ncol = 3, byrow = TRUE)
  result <- run_repertoire(pen, c("A", "B", "C"))
  brp <- result$brand_repertoire_profile

  for (i in seq_len(nrow(brp))) {
    total <- brp$Sole_Pct[i] + brp$Dual_Pct[i] + brp$Multi_Pct[i]
    if (brp$Brand_Buyers_n[i] > 0) {
      expect_equal(total, 100, tolerance = 0.5,
                   label = sprintf("Sum for %s", brp$BrandCode[i]))
    }
  }
})

test_that("brand_repertoire_profile known values are correct", {
  # 4 buyers of A:
  #   Resp 1: A only (sole)
  #   Resp 2: A + B (dual)
  #   Resp 3: A + B + C (multi)
  #   Resp 4: A + C (dual)
  pen <- matrix(c(
    1, 0, 0,
    1, 1, 0,
    1, 1, 1,
    1, 0, 1
  ), nrow = 4, ncol = 3, byrow = TRUE)
  result <- run_repertoire(pen, c("A", "B", "C"), focal_brand = "A")
  brp <- result$brand_repertoire_profile

  a_row <- brp[brp$BrandCode == "A", ]
  expect_equal(a_row$Brand_Buyers_n, 4L)
  expect_equal(a_row$Sole_Pct,  25)   # 1 of 4
  expect_equal(a_row$Dual_Pct,  50)   # 2 of 4 (resp 2 + resp 4)
  expect_equal(a_row$Multi_Pct, 25)   # 1 of 4 (resp 3)
  # Mean repertoire among A buyers: (1+2+3+2)/4 = 2
  expect_equal(a_row$Mean_Repertoire, 2)
})

test_that("brand_repertoire_profile is NULL for zero buyers", {
  pen <- matrix(c(0, 0, 0, 0, 0, 0), nrow = 2, ncol = 3, byrow = TRUE)
  result <- run_repertoire(pen, c("A", "B", "C"))
  expect_equal(result$status, "REFUSED")  # no buyers at all
})

test_that("brand_repertoire_profile respects weights", {
  # Resp 1: A only (sole, weight=3); Resp 2: A+B (dual, weight=1)
  pen <- matrix(c(1, 0, 1, 1), nrow = 2, ncol = 2, byrow = TRUE)
  weights <- c(3, 1)

  result_unwt <- run_repertoire(pen, c("A", "B"))
  result_wt   <- run_repertoire(pen, c("A", "B"), weights = weights)

  # Unweighted: A sole = 1/2 = 50%, dual = 1/2 = 50%
  a_unwt <- result_unwt$brand_repertoire_profile[
    result_unwt$brand_repertoire_profile$BrandCode == "A", ]
  expect_equal(a_unwt$Sole_Pct, 50)

  # Weighted: A buyers weighted = 3+1=4; sole weight = 3/4 = 75%
  a_wt <- result_wt$brand_repertoire_profile[
    result_wt$brand_repertoire_profile$BrandCode == "A", ]
  expect_equal(a_wt$Sole_Pct, 75)
})
