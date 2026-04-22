# ==============================================================================
# BRAND MODULE TESTS - PORTFOLIO STRENGTH MAP (§4.4)
# ==============================================================================
# Known-answer tests for compute_strength_map().
#
# Synthetic scenario (hand-verifiable):
#   5 respondents, 1 category "TST", 2 brands IPK/ROB.
#   base_idx (SQ2_TST == 1): rows 1–3; n_total = 5.
#   BRANDAWARE_TST_IPK = c(1,1,0,1,0) → among base: 2/3 = 66.667%
#   BRANDAWARE_TST_ROB = c(1,0,0,1,0) → among base: 1/3 = 33.333%
#   cat_pen = 3/5 = 0.6
#   aware_n_w IPK (uniform weights): 2.0
#   aware_n_w ROB (uniform weights): 1.0
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

brand_r_dir <- file.path(TURAS_ROOT, "modules", "brand", "R")
assign("brand_script_dir_override", brand_r_dir, envir = globalenv())

for (f in c("00_guard.R", "00_role_map.R", "00_guard_role_map.R",
            "01_config.R", "09_portfolio.R",
            "09a_portfolio_footprint.R", "09d_portfolio_strength.R", "00_main.R")) {
  fpath <- file.path(brand_r_dir, f)
  if (file.exists(fpath)) tryCatch(source(fpath, local = FALSE), error = function(e) NULL)
}


# ---------------------------------------------------------------------------
# Minimal synthetic helpers (same structure as footprint tests)
# ---------------------------------------------------------------------------

.sm_data <- function() {
  data.frame(
    SQ2_TST            = c(1L, 1L, 1L, 0L, 0L),
    BRANDAWARE_TST_IPK = c(1L, 1L, 0L, 1L, 0L),
    BRANDAWARE_TST_ROB = c(1L, 0L, 0L, 1L, 0L),
    stringsAsFactors   = FALSE
  )
}

.sm_structure <- function() {
  list(
    brands = data.frame(
      Category     = "Test Spices",
      BrandCode    = c("IPK", "ROB"),
      DisplayOrder = 1:2,
      stringsAsFactors = FALSE
    ),
    questionmap = data.frame(
      Role       = "funnel.awareness.TST",
      ClientCode = "BRANDAWARE_TST",
      stringsAsFactors = FALSE
    )
  )
}

.sm_categories <- function() {
  data.frame(Category = "Test Spices", stringsAsFactors = FALSE)
}

.sm_config <- function(min_base = 2L) {
  list(
    focal_brand         = "IPK",
    portfolio_timeframe = "3m",
    portfolio_min_base  = min_base
  )
}


# ===========================================================================
# compute_strength_map() — known-answer tests
# ===========================================================================

test_that("strength map returns PASS with per_brand list", {
  result <- compute_strength_map(.sm_data(), .sm_categories(),
                                 .sm_structure(), .sm_config())
  expect_equal(result$status, "PASS")
  expect_true(is.list(result$per_brand))
})

test_that("per_brand contains both IPK and ROB", {
  result <- compute_strength_map(.sm_data(), .sm_categories(),
                                 .sm_structure(), .sm_config())
  expect_true("IPK" %in% names(result$per_brand))
  expect_true("ROB" %in% names(result$per_brand))
})

test_that("IPK cat_pen = 3/5 = 0.6", {
  result <- compute_strength_map(.sm_data(), .sm_categories(),
                                 .sm_structure(), .sm_config())
  ipk_df <- result$per_brand[["IPK"]]
  expect_equal(ipk_df$cat_pen[ipk_df$cat == "TST"], 0.6, tolerance = 1e-6)
})

test_that("IPK brand_aware = 2/3 * 100 = 66.667%", {
  result <- compute_strength_map(.sm_data(), .sm_categories(),
                                 .sm_structure(), .sm_config())
  ipk_df <- result$per_brand[["IPK"]]
  expect_equal(ipk_df$brand_aware[ipk_df$cat == "TST"],
               2 / 3 * 100, tolerance = 1e-4)
})

test_that("ROB brand_aware = 1/3 * 100 = 33.333%", {
  result <- compute_strength_map(.sm_data(), .sm_categories(),
                                 .sm_structure(), .sm_config())
  rob_df <- result$per_brand[["ROB"]]
  expect_equal(rob_df$brand_aware[rob_df$cat == "TST"],
               1 / 3 * 100, tolerance = 1e-4)
})

test_that("IPK aware_n_w = 2.0 (2 aware among 3 qualifiers, uniform weights)", {
  result <- compute_strength_map(.sm_data(), .sm_categories(),
                                 .sm_structure(), .sm_config())
  ipk_df <- result$per_brand[["IPK"]]
  expect_equal(ipk_df$aware_n_w[ipk_df$cat == "TST"], 2.0, tolerance = 1e-6)
})

test_that("ROB aware_n_w = 1.0 (1 aware among 3 qualifiers, uniform weights)", {
  result <- compute_strength_map(.sm_data(), .sm_categories(),
                                 .sm_structure(), .sm_config())
  rob_df <- result$per_brand[["ROB"]]
  expect_equal(rob_df$aware_n_w[rob_df$cat == "TST"], 1.0, tolerance = 1e-6)
})

test_that("per_brand data frame has correct column names", {
  result <- compute_strength_map(.sm_data(), .sm_categories(),
                                 .sm_structure(), .sm_config())
  ipk_df <- result$per_brand[["IPK"]]
  expect_true(all(c("cat", "cat_pen", "brand_aware", "aware_n_w") %in% names(ipk_df)))
})

test_that("suppression: categories below min_base excluded from per_brand", {
  result <- compute_strength_map(.sm_data(), .sm_categories(),
                                 .sm_structure(), .sm_config(min_base = 10L))
  expect_equal(result$status, "PASS")
  expect_equal(length(result$per_brand), 0L)
  expect_equal(result$suppressed_cats, "TST")
})

test_that("empty categories returns PASS with empty per_brand", {
  result <- compute_strength_map(
    .sm_data(),
    data.frame(Category = character(0), stringsAsFactors = FALSE),
    .sm_structure(), .sm_config()
  )
  expect_equal(result$status, "PASS")
  expect_equal(length(result$per_brand), 0L)
})

test_that("weighted: weights c(2,1,1,1,1) give IPK aware_n_w = 3.0", {
  # denom = 2+1+1=4; IPK aware rows 1,2 → 2+1=3
  weights <- c(2.0, 1.0, 1.0, 1.0, 1.0)
  result  <- compute_strength_map(.sm_data(), .sm_categories(),
                                  .sm_structure(), .sm_config(),
                                  weights = weights)
  ipk_df  <- result$per_brand[["IPK"]]
  expect_equal(ipk_df$aware_n_w[ipk_df$cat == "TST"], 3.0, tolerance = 1e-6)
})
