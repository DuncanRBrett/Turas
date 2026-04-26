# ==============================================================================
# BRAND MODULE TESTS - PORTFOLIO FOOTPRINT MATRIX (§4.1)
# ==============================================================================
# Known-answer tests for compute_footprint_matrix() and its pure helper
# .compute_category_awareness().
# Synthetic data with hand-verifiable expected values is used for correctness.
# Fixture tests (ipk_9cat_wave1.xlsx) check shape and plausibility.
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
            "09a_portfolio_footprint.R", "00_main.R")) {
  fpath <- file.path(brand_r_dir, f)
  if (file.exists(fpath)) tryCatch(source(fpath, local = FALSE), error = function(e) NULL)
}

# ---------------------------------------------------------------------------
# Minimal synthetic helpers
# Hand-verifiable scenario: 5 respondents, 1 category "TST", 2 brands IPK/ROB.
#   base_idx: rows 1-3 qualify (SQ2_TST == 1); rows 4-5 do not.
#   IPK aware in rows 1 and 2 → 2 of 3 qualifiers → 66.667%
#   ROB aware in row 1 only  → 1 of 3 qualifiers → 33.333%
# ---------------------------------------------------------------------------

.fp_data <- function() {
  data.frame(
    SQ2_TST            = c(1L, 1L, 1L, 0L, 0L),
    BRANDAWARE_TST_IPK = c(1L, 1L, 0L, 1L, 0L),
    BRANDAWARE_TST_ROB = c(1L, 0L, 0L, 1L, 0L),
    stringsAsFactors   = FALSE
  )
}

.fp_structure <- function() {
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

.fp_categories <- function() {
  data.frame(Category = "Test Spices", stringsAsFactors = FALSE)
}

.fp_config <- function(min_base = 2L) {
  list(
    focal_brand         = "IPK",
    portfolio_timeframe = "3m",
    portfolio_min_base  = min_base
  )
}


# ===========================================================================
# .compute_category_awareness() — pure unit tests
# ===========================================================================

test_that("unweighted: 2 of 3 qualifiers aware → 66.667%", {
  dat      <- .fp_data()
  base_idx <- dat$SQ2_TST == 1L
  result   <- .compute_category_awareness(dat, "TST", c("IPK", "ROB"),
                                          base_idx, weights = NULL)
  expect_equal(result[["IPK"]], 2 / 3 * 100, tolerance = 1e-6)
  expect_equal(result[["ROB"]], 1 / 3 * 100, tolerance = 1e-6)
})

test_that("weighted: weights c(2,1,1) on 3 qualifiers → IPK 75%, ROB 50%", {
  # denom = 2+1+1 = 4
  # IPK aware (rows 1 and 2): 2+1 = 3  →  3/4 = 75%
  # ROB aware (row 1 only):   2        →  2/4 = 50%
  dat      <- .fp_data()
  base_idx <- dat$SQ2_TST == 1L
  weights  <- c(2.0, 1.0, 1.0, 1.0, 1.0)
  result   <- .compute_category_awareness(dat, "TST", c("IPK", "ROB"),
                                          base_idx, weights)
  expect_equal(result[["IPK"]], 75.0, tolerance = 1e-6)
  expect_equal(result[["ROB"]], 50.0, tolerance = 1e-6)
})

test_that("absent brand column returns NA, not zero", {
  dat      <- .fp_data()
  base_idx <- dat$SQ2_TST == 1L
  result   <- .compute_category_awareness(dat, "TST", c("IPK", "MISSING"),
                                          base_idx, weights = NULL)
  expect_equal(result[["IPK"]], 2 / 3 * 100, tolerance = 1e-6)
  expect_true(is.na(result[["MISSING"]]))
})

test_that("zero-denominator base returns NA for every brand", {
  dat <- data.frame(
    SQ2_TST            = c(0L, 0L),
    BRANDAWARE_TST_IPK = c(1L, 1L),
    stringsAsFactors   = FALSE
  )
  base_idx <- dat$SQ2_TST == 1L
  result   <- .compute_category_awareness(dat, "TST", "IPK", base_idx, NULL)
  expect_true(is.na(result[["IPK"]]))
})

test_that("all qualifiers aware → 100%", {
  dat <- data.frame(
    SQ2_TST            = c(1L, 1L, 1L),
    BRANDAWARE_TST_IPK = c(1L, 1L, 1L),
    stringsAsFactors   = FALSE
  )
  base_idx <- dat$SQ2_TST == 1L
  result   <- .compute_category_awareness(dat, "TST", "IPK", base_idx, NULL)
  expect_equal(result[["IPK"]], 100.0, tolerance = 1e-6)
})

test_that("no qualifiers aware → 0%", {
  dat <- data.frame(
    SQ2_TST            = c(1L, 1L),
    BRANDAWARE_TST_IPK = c(0L, 0L),
    stringsAsFactors   = FALSE
  )
  base_idx <- dat$SQ2_TST == 1L
  result   <- .compute_category_awareness(dat, "TST", "IPK", base_idx, NULL)
  expect_equal(result[["IPK"]], 0.0, tolerance = 1e-6)
})


# ===========================================================================
# compute_footprint_matrix() — known-answer tests (synthetic)
# ===========================================================================

test_that("matrix dimensions: 2 brands × 1 category", {
  result <- compute_footprint_matrix(.fp_data(), .fp_categories(),
                                     .fp_structure(), .fp_config())
  expect_equal(result$status, "PASS")
  expect_equal(nrow(result$matrix_df), 2L)
  expect_true("Brand" %in% names(result$matrix_df))
  expect_true("TST"   %in% names(result$matrix_df))
})

test_that("matrix values: IPK 66.667%, ROB 33.333%", {
  result <- compute_footprint_matrix(.fp_data(), .fp_categories(),
                                     .fp_structure(), .fp_config())
  ipk_row <- result$matrix_df[result$matrix_df$Brand == "IPK", ]
  rob_row <- result$matrix_df[result$matrix_df$Brand == "ROB", ]
  expect_equal(ipk_row$TST, 2 / 3 * 100, tolerance = 1e-4)
  expect_equal(rob_row$TST, 1 / 3 * 100, tolerance = 1e-4)
})

test_that("matrix sorted: IPK (higher footprint) in first row", {
  result <- compute_footprint_matrix(.fp_data(), .fp_categories(),
                                     .fp_structure(), .fp_config())
  expect_equal(result$matrix_df$Brand[1], "IPK")
})

test_that("bases_df: correct unweighted and weighted buyer counts", {
  result <- compute_footprint_matrix(.fp_data(), .fp_categories(),
                                     .fp_structure(), .fp_config())
  expect_equal(nrow(result$bases_df), 1L)
  expect_equal(result$bases_df$cat, "TST")
  expect_equal(result$bases_df$n_buyers_uw, 3L)
  expect_equal(result$bases_df$n_buyers_w, 3.0, tolerance = 1e-6)
})

test_that("categories below min_base are flagged but kept in the matrix", {
  # Spec change (Apr 2026): the Footprint sub-tab now shows EVERY category
  # the screener resolves, regardless of base. Low-base categories are
  # recorded in `suppressed_cats` so the renderer can mark them, but their
  # column (and any awareness values it carries) is still emitted — Duncan
  # wants the full portfolio view, not a base-filtered subset.
  result <- compute_footprint_matrix(.fp_data(), .fp_categories(),
                                     .fp_structure(), .fp_config(min_base = 10L))
  expect_equal(result$status, "PASS")
  expect_gt(nrow(result$matrix_df), 0L)
  expect_true("TST" %in% result$suppressed_cats)
  expect_true("TST" %in% setdiff(names(result$matrix_df), "Brand"))
})

test_that("empty categories input returns PASS with empty matrix", {
  result <- compute_footprint_matrix(
    .fp_data(),
    data.frame(Category = character(0), stringsAsFactors = FALSE),
    .fp_structure(), .fp_config()
  )
  expect_equal(result$status, "PASS")
  expect_equal(nrow(result$matrix_df), 0L)
  expect_equal(length(result$suppressed_cats), 0L)
})

test_that("weighted matrix: weights c(2,1,1,1,1) → IPK 75%, ROB 50%", {
  weights <- c(2.0, 1.0, 1.0, 1.0, 1.0)
  result  <- compute_footprint_matrix(.fp_data(), .fp_categories(),
                                      .fp_structure(), .fp_config(),
                                      weights = weights)
  ipk_row <- result$matrix_df[result$matrix_df$Brand == "IPK", ]
  rob_row <- result$matrix_df[result$matrix_df$Brand == "ROB", ]
  expect_equal(ipk_row$TST, 75.0, tolerance = 1e-4)
  expect_equal(rob_row$TST, 50.0, tolerance = 1e-4)
})


# ===========================================================================
# Fixture tests — skipped if fixture not found
# ===========================================================================

FIXTURE_PATH <- file.path(
  path.expand("~"),
  "Library", "CloudStorage", "OneDrive-Personal", "DB Files",
  "TurasProjects", "Examples", "IPK_9Category", "ipk_9cat_wave1.xlsx"
)

.load_fp_fixture <- function() {
  skip_if_not(file.exists(FIXTURE_PATH),
              "Fixture ipk_9cat_wave1.xlsx not found — skipping")
  openxlsx::read.xlsx(FIXTURE_PATH, sheet = 1)
}

.ipk_structure <- function() {
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

.ipk_categories <- function() {
  data.frame(Category = "DSS", stringsAsFactors = FALSE)
}

.ipk_config <- function() {
  list(
    focal_brand         = "IPK",
    portfolio_timeframe = "3m",
    portfolio_min_base  = 30L
  )
}

test_that("fixture: footprint matrix has PASS status and 1 category column", {
  dat    <- .load_fp_fixture()
  result <- compute_footprint_matrix(dat, .ipk_categories(),
                                     .ipk_structure(), .ipk_config())
  expect_equal(result$status, "PASS")
  expect_true("DSS" %in% names(result$matrix_df))
})

test_that("fixture: DSS base is 506 (SQ2_DSS=1)", {
  dat    <- .load_fp_fixture()
  result <- compute_footprint_matrix(dat, .ipk_categories(),
                                     .ipk_structure(), .ipk_config())
  expect_equal(result$bases_df$n_buyers_uw[result$bases_df$cat == "DSS"], 506L)
})

test_that("fixture: all awareness values are in [0, 100]", {
  dat    <- .load_fp_fixture()
  result <- compute_footprint_matrix(dat, .ipk_categories(),
                                     .ipk_structure(), .ipk_config())
  cat_cols <- setdiff(names(result$matrix_df), "Brand")
  vals <- unlist(result$matrix_df[, cat_cols])
  vals <- vals[!is.na(vals)]
  expect_true(all(vals >= 0 & vals <= 100))
})

test_that("fixture: IPK awareness in DSS exceeds 70% (high focal awareness design)", {
  dat    <- .load_fp_fixture()
  result <- compute_footprint_matrix(dat, .ipk_categories(),
                                     .ipk_structure(), .ipk_config())
  ipk_dss <- result$matrix_df$DSS[result$matrix_df$Brand == "IPK"]
  expect_true(ipk_dss > 70)
})

test_that("fixture: IPK has the highest total footprint in DSS", {
  dat    <- .load_fp_fixture()
  result <- compute_footprint_matrix(dat, .ipk_categories(),
                                     .ipk_structure(), .ipk_config())
  expect_equal(result$matrix_df$Brand[1], "IPK")
})
