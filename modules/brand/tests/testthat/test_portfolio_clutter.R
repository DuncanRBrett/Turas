# ==============================================================================
# BRAND MODULE TESTS - PORTFOLIO CLUTTER QUADRANT (§4.3)
# ==============================================================================
# Known-answer tests for compute_clutter_data() and the pure helper
# .compute_category_clutter_metrics().
#
# Synthetic scenario (hand-verifiable):
#   5 respondents, 1 category "TST", 2 brands IPK/ROB.
#   base_idx (SQ2_TST == 1): rows 1–3; n_total = 5.
#   BRANDAWARE_TST_IPK = c(1,1,0,1,0) → among base: 1,1,0 → IPK pct = 2/3 * 100
#   BRANDAWARE_TST_ROB = c(1,0,0,1,0) → among base: 1,0,0 → ROB pct = 1/3 * 100
#   set_size per resp (base rows): c(2,1,0) → mean = 1.0
#   sum_brand_pcts = (2/3 + 1/3) * 100 = 100
#   focal_share = (2/3*100) / 100 = 0.667
#   fair_share = 1/2 = 0.5
#   cat_penetration = 3 / 5 = 0.6
#   quadrant: focal_share(0.667) > fair_share(0.5) AND NOT high_clutter → "Dominant"
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
            "09c_portfolio_clutter.R", "00_main.R")) {
  fpath <- file.path(brand_r_dir, f)
  if (file.exists(fpath)) tryCatch(source(fpath, local = FALSE), error = function(e) NULL)
}


# ---------------------------------------------------------------------------
# Minimal synthetic helpers
# ---------------------------------------------------------------------------

.cl_data <- function() {
  data.frame(
    SQ2_TST            = c(1L, 1L, 1L, 0L, 0L),
    BRANDAWARE_TST_IPK = c(1L, 1L, 0L, 1L, 0L),
    BRANDAWARE_TST_ROB = c(1L, 0L, 0L, 1L, 0L),
    stringsAsFactors   = FALSE
  )
}

.cl_structure <- function() {
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

.cl_categories <- function() {
  data.frame(Category = "Test Spices", stringsAsFactors = FALSE)
}

.cl_config <- function(focal = "IPK", min_base = 2L) {
  list(
    focal_brand         = focal,
    portfolio_timeframe = "3m",
    portfolio_min_base  = min_base
  )
}


# ===========================================================================
# .compute_category_clutter_metrics() — pure unit tests
# ===========================================================================

test_that("set size mean: c(2,1,0) among 3 qualifiers → 1.0", {
  dat      <- .cl_data()
  base_idx <- dat$SQ2_TST == 1L
  result   <- .compute_category_clutter_metrics(dat, "TST", c("IPK", "ROB"),
                                                "IPK", base_idx, NULL)
  expect_equal(result$awareness_set_size_mean, 1.0, tolerance = 1e-6)
})

test_that("focal_pct: 2 of 3 qualifiers aware → 66.667%", {
  dat      <- .cl_data()
  base_idx <- dat$SQ2_TST == 1L
  result   <- .compute_category_clutter_metrics(dat, "TST", c("IPK", "ROB"),
                                                "IPK", base_idx, NULL)
  expect_equal(result$focal_pct, 2 / 3 * 100, tolerance = 1e-6)
})

test_that("sum_brand_pcts: IPK(66.667) + ROB(33.333) = 100.0", {
  dat      <- .cl_data()
  base_idx <- dat$SQ2_TST == 1L
  result   <- .compute_category_clutter_metrics(dat, "TST", c("IPK", "ROB"),
                                                "IPK", base_idx, NULL)
  expect_equal(result$sum_brand_pcts, 100.0, tolerance = 1e-4)
})

test_that("n_brands equals length of brand_codes", {
  dat      <- .cl_data()
  base_idx <- dat$SQ2_TST == 1L
  result   <- .compute_category_clutter_metrics(dat, "TST", c("IPK", "ROB"),
                                                "IPK", base_idx, NULL)
  expect_equal(result$n_brands, 2L)
})

test_that("absent focal brand produces focal_pct = 0", {
  dat      <- .cl_data()
  base_idx <- dat$SQ2_TST == 1L
  result   <- .compute_category_clutter_metrics(dat, "TST", c("IPK", "ROB"),
                                                "ABSENT", base_idx, NULL)
  expect_equal(result$focal_pct, 0)
})

test_that("weighted: weights c(2,1,1,1,1) change set_size_mean and focal_pct", {
  # denom = 2+1+1 = 4
  # IPK aware (rows 1,2): weighted 2+1=3 → 3/4*100 = 75
  # ROB aware (row 1):    weighted 2     → 2/4*100 = 50
  # set_size weighted mean = (2*2 + 1*1 + 1*0) / 4 = 5/4 = 1.25
  dat      <- .cl_data()
  base_idx <- dat$SQ2_TST == 1L
  weights  <- c(2.0, 1.0, 1.0, 1.0, 1.0)
  result   <- .compute_category_clutter_metrics(dat, "TST", c("IPK", "ROB"),
                                                "IPK", base_idx, weights)
  expect_equal(result$awareness_set_size_mean, 1.25, tolerance = 1e-6)
  expect_equal(result$focal_pct, 75.0, tolerance = 1e-6)
})


# ===========================================================================
# compute_clutter_data() — known-answer tests (synthetic)
# ===========================================================================

test_that("clutter_df has correct structure", {
  result <- compute_clutter_data(.cl_data(), .cl_categories(),
                                 .cl_structure(), .cl_config())
  expect_equal(result$status, "PASS")
  expect_true(is.data.frame(result$clutter_df))
  expect_equal(nrow(result$clutter_df), 1L)
  expected_cols <- c("cat", "awareness_set_size_mean", "focal_share_of_aware",
                     "cat_penetration", "fair_share", "quadrant")
  expect_true(all(expected_cols %in% names(result$clutter_df)))
})

test_that("focal_share_of_aware: focal_pct(66.667) / sum(100) = 0.667", {
  result <- compute_clutter_data(.cl_data(), .cl_categories(),
                                 .cl_structure(), .cl_config())
  expect_equal(result$clutter_df$focal_share_of_aware, 2 / 3, tolerance = 1e-4)
})

test_that("cat_penetration: 3 qualifiers / 5 total = 0.6", {
  result <- compute_clutter_data(.cl_data(), .cl_categories(),
                                 .cl_structure(), .cl_config())
  expect_equal(result$clutter_df$cat_penetration, 0.6, tolerance = 1e-6)
})

test_that("fair_share: 1 / n_brands = 0.5 for 2 brands", {
  result <- compute_clutter_data(.cl_data(), .cl_categories(),
                                 .cl_structure(), .cl_config())
  expect_equal(result$clutter_df$fair_share, 0.5, tolerance = 1e-6)
})

test_that("ref_x equals awareness_set_size_mean for single-category data", {
  result <- compute_clutter_data(.cl_data(), .cl_categories(),
                                 .cl_structure(), .cl_config())
  expect_equal(result$ref_x, result$clutter_df$awareness_set_size_mean,
               tolerance = 1e-6)
})

test_that("ref_y equals fair_share for single-category data", {
  result <- compute_clutter_data(.cl_data(), .cl_categories(),
                                 .cl_structure(), .cl_config())
  expect_equal(result$ref_y, result$clutter_df$fair_share, tolerance = 1e-6)
})

test_that("quadrant: focal_share(0.667) > fair_share(0.5) and low clutter → Dominant", {
  # is_high_clutter: awareness_set_size_mean(1.0) > ref_x(1.0) is FALSE
  # is_strong: focal_share(0.667) > fair_share(0.5) is TRUE
  # Result: Dominant
  result <- compute_clutter_data(.cl_data(), .cl_categories(),
                                 .cl_structure(), .cl_config())
  expect_equal(result$clutter_df$quadrant, "Dominant")
})

test_that("quadrant: non-focal brand below fair share → Niche Opportunity", {
  result <- compute_clutter_data(.cl_data(), .cl_categories(),
                                 .cl_structure(), .cl_config(focal = "ROB"))
  # ROB focal_share = (1/3*100) / 100 = 0.333, fair_share = 0.5 → below
  # is_high_clutter: 1.0 > 1.0 → FALSE
  # Result: Niche Opportunity
  expect_equal(result$clutter_df$quadrant, "Niche Opportunity")
})

test_that("suppression: categories below min_base excluded from clutter_df", {
  result <- compute_clutter_data(.cl_data(), .cl_categories(),
                                 .cl_structure(), .cl_config(min_base = 10L))
  expect_equal(result$status, "PASS")
  expect_equal(nrow(result$clutter_df), 0L)
  expect_equal(result$suppressed_cats, "TST")
})

test_that("empty categories returns PASS with empty clutter_df", {
  result <- compute_clutter_data(
    .cl_data(),
    data.frame(Category = character(0), stringsAsFactors = FALSE),
    .cl_structure(), .cl_config()
  )
  expect_equal(result$status, "PASS")
  expect_equal(nrow(result$clutter_df), 0L)
})


# ===========================================================================
# Fixture tests — skipped if fixture not found
# ===========================================================================

FIXTURE_PATH <- file.path(
  path.expand("~"),
  "Library", "CloudStorage", "OneDrive-Personal", "DB Files",
  "TurasProjects", "Examples", "IPK_9Category", "ipk_9cat_wave1.xlsx"
)

.load_cl_fixture <- function() {
  skip_if_not(file.exists(FIXTURE_PATH),
              "Fixture ipk_9cat_wave1.xlsx not found — skipping")
  openxlsx::read.xlsx(FIXTURE_PATH, sheet = 1)
}

.ipk_cl_structure <- function() {
  brands_dss <- c("IPK","ROB","KNORR","CART","RAJAH","SFRI",
                  "SPMEC","WWTDSS","PNPDSS","CKRDSS")
  list(
    brands = data.frame(
      Category     = rep("DSS", length(brands_dss)),
      BrandCode    = brands_dss,
      DisplayOrder = seq_along(brands_dss),
      stringsAsFactors = FALSE
    ),
    questionmap = data.frame(
      Role       = "funnel.awareness.DSS",
      ClientCode = "BRANDAWARE_DSS",
      stringsAsFactors = FALSE
    )
  )
}

.ipk_cl_categories <- function() {
  data.frame(Category = "DSS", stringsAsFactors = FALSE)
}

.ipk_cl_config <- function() {
  list(
    focal_brand         = "IPK",
    portfolio_timeframe = "3m",
    portfolio_min_base  = 30L
  )
}

test_that("fixture: clutter_df has PASS status and 1 row", {
  dat    <- .load_cl_fixture()
  result <- compute_clutter_data(dat, .ipk_cl_categories(),
                                 .ipk_cl_structure(), .ipk_cl_config())
  expect_equal(result$status, "PASS")
  expect_equal(nrow(result$clutter_df), 1L)
  expect_equal(result$clutter_df$cat, "DSS")
})

test_that("fixture: focal_share_of_aware is in (0, 1]", {
  dat    <- .load_cl_fixture()
  result <- compute_clutter_data(dat, .ipk_cl_categories(),
                                 .ipk_cl_structure(), .ipk_cl_config())
  s <- result$clutter_df$focal_share_of_aware
  expect_true(s > 0 && s <= 1)
})

test_that("fixture: awareness_set_size_mean is positive and reasonable (< n_brands)", {
  dat    <- .load_cl_fixture()
  result <- compute_clutter_data(dat, .ipk_cl_categories(),
                                 .ipk_cl_structure(), .ipk_cl_config())
  m <- result$clutter_df$awareness_set_size_mean
  expect_true(m > 0 && m <= 10)
})

test_that("fixture: cat_penetration equals SQ2_DSS base / total (506/1200)", {
  dat    <- .load_cl_fixture()
  result <- compute_clutter_data(dat, .ipk_cl_categories(),
                                 .ipk_cl_structure(), .ipk_cl_config())
  expect_equal(result$clutter_df$cat_penetration, 506 / 1200, tolerance = 1e-4)
})

test_that("fixture: IPK has quadrant Dominant or Contested in DSS (focal brand, high share)", {
  dat    <- .load_cl_fixture()
  result <- compute_clutter_data(dat, .ipk_cl_categories(),
                                 .ipk_cl_structure(), .ipk_cl_config())
  q <- result$clutter_df$quadrant
  expect_true(q %in% c("Dominant", "Contested"))
})
