# ==============================================================================
# BRAND MODULE TESTS - PORTFOLIO OVERVIEW DATA BUILDER (v2.0)
# ==============================================================================
# Known-answer tests for compute_portfolio_overview_data() and
# build_portfolio_overview(). Hand-verifiable synthetic fixtures:
#   4 respondents, 2 categories (DSS deep-dive, SLD awareness-only),
#   4 brands per category (IPK/ROB/ZEN/BLU for DSS; SAL/FRE/TOM/BLU for SLD).
#   BLU is shared across both categories; all others are category-unique.
#
# Why 4 brands: .detect_category_code uses a 50% column-match threshold. With
# only 2 brands the threshold collapses to 1 match, which lets cross-category
# columns accidentally satisfy detection. Four brands forces threshold = 2,
# so detection correctly maps Dishwashing → DSS, Salads → SLD.
#
# Scenario (DSS, 3m screener):
#   SQ2_DSS = 1 for rows 1,2,3; 0 for row 4  → 3 buyers of 4 (75% cat usage)
#   BRANDAWARE_DSS_IPK = 1 in rows 1,2,3     → 3/3 buyers = 100% awareness
#   BRANDAWARE_DSS_ROB = 1 in rows 1,3       → 2/3 buyers ≈ 66.667%
#   BRANDAWARE_DSS_ZEN = 1 in row 2          → 1/3 buyers ≈ 33.333%
#   BRANDAWARE_DSS_BLU = 1 in rows 1,2,3     → 3/3 buyers = 100%
#
#   Pen matrix (rows 1..4 × [IPK, ROB, ZEN, BLU]) and x_mat drive deep-dive.
#   Cat total volume = 10  →  IPK vol 70%, ROB 30%, ZEN 0%, BLU 0%.
#   IPK pen 75%, ROB 50%, ZEN 0%, BLU 0%.
#   IPK freq = 7/3, ROB freq = 1.5.
#   SoR: IPK 70%, ROB 30%.
#
# Scenario (SLD, awareness-only):
#   SQ2_SLD = 1 for rows 1,2,4; 0 for row 3  → 3 buyers of 4 (75% cat usage)
#   BRANDAWARE_SLD_SAL = 1 in rows 1,4       → 2/3 buyers ≈ 66.667%
#   BRANDAWARE_SLD_FRE = 1 in row 2          → 1/3 buyers ≈ 33.333%
#   BRANDAWARE_SLD_TOM = 1 in row 4          → 1/3 buyers ≈ 33.333%
#   BRANDAWARE_SLD_BLU = 1 in row 1          → 1/3 buyers ≈ 33.333%
#
#   BLU therefore present in both categories → n_categories_present = 2.
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

TURAS_ROOT  <- .find_turas_root_for_test()
brand_r_dir <- file.path(TURAS_ROOT, "modules", "brand", "R")

for (f in c("01_config.R", "09_portfolio.R", "09a_portfolio_footprint.R",
            "09h_portfolio_overview_data.R")) {
  source(file.path(brand_r_dir, f), local = FALSE)
}

# .detect_category_code is defined in 00_main.R; source the full file only if
# the helper isn't already on the search path.
if (!exists(".detect_category_code", mode = "function")) {
  source(file.path(brand_r_dir, "00_main.R"), local = FALSE)
}


# ---------------------------------------------------------------------------
# Synthetic fixture builders
# ---------------------------------------------------------------------------

.po_data <- function() {
  data.frame(
    respondentID = 1:4,
    SQ2_DSS      = c(1L, 1L, 1L, 0L),
    SQ2_SLD      = c(1L, 1L, 0L, 1L),
    BRANDAWARE_DSS_IPK = c(1L, 1L, 1L, 0L),
    BRANDAWARE_DSS_ROB = c(1L, 0L, 1L, 0L),
    BRANDAWARE_DSS_ZEN = c(0L, 1L, 0L, 0L),
    BRANDAWARE_DSS_BLU = c(1L, 1L, 1L, 0L),
    BRANDAWARE_SLD_SAL = c(1L, 0L, 0L, 1L),
    BRANDAWARE_SLD_FRE = c(0L, 1L, 0L, 0L),
    BRANDAWARE_SLD_TOM = c(0L, 0L, 0L, 1L),
    BRANDAWARE_SLD_BLU = c(1L, 0L, 0L, 0L),
    stringsAsFactors = FALSE
  )
}

.po_categories <- function() {
  data.frame(
    Category       = c("Dishwashing", "Salads"),
    Analysis_Depth = c("full", "awareness_only"),
    stringsAsFactors = FALSE
  )
}

.po_structure <- function() {
  list(
    brands = data.frame(
      Category = c(rep("Dishwashing", 4), rep("Salads", 4)),
      BrandCode = c("IPK", "ROB", "ZEN", "BLU",
                    "SAL", "FRE", "TOM", "BLU"),
      BrandName = c("Impulse", "Robust", "Zenith", "Blue",
                    "Salado", "Fresco", "Tomato", "Blue"),
      DisplayOrder = c(1L, 2L, 3L, 4L, 1L, 2L, 3L, 4L),
      stringsAsFactors = FALSE
    ),
    questionmap = data.frame(
      ClientCode = c("BRANDAWARE_DSS", "BRANDAWARE_SLD"),
      Role       = c("funnel.awareness.DSS", "funnel.awareness.SLD"),
      stringsAsFactors = FALSE
    )
  )
}

.po_config <- function() {
  list(focal_brand = "IPK", portfolio_timeframe = "3m")
}

.po_dss_pen_mat <- function() {
  matrix(c(
    1L, 1L, 0L, 0L,
    1L, 0L, 0L, 0L,
    1L, 1L, 0L, 0L,
    0L, 0L, 0L, 0L
  ), nrow = 4, byrow = TRUE,
  dimnames = list(NULL, c("IPK", "ROB", "ZEN", "BLU")))
}

.po_dss_x_mat <- function() {
  matrix(c(
    4, 1, 0, 0,
    2, 0, 0, 0,
    1, 2, 0, 0,
    0, 0, 0, 0
  ), nrow = 4, byrow = TRUE,
  dimnames = list(NULL, c("IPK", "ROB", "ZEN", "BLU")))
}

.po_dss_sor <- function() {
  data.frame(
    BrandCode = c("IPK", "ROB"),
    SoR_Pct   = c(70.0, 30.0),
    stringsAsFactors = FALSE
  )
}

.po_category_results <- function() {
  list(
    Dishwashing = list(
      analysis_depth = "full",
      brand_volume   = list(pen_mat = .po_dss_pen_mat(),
                            x_mat   = .po_dss_x_mat()),
      repertoire     = list(share_of_requirements = .po_dss_sor())
    ),
    Salads = list(analysis_depth = "awareness_only")
  )
}

.po_call <- function(data = .po_data(),
                    categories = .po_categories(),
                    structure = .po_structure(),
                    config = .po_config(),
                    weights = NULL,
                    category_results = .po_category_results()) {
  compute_portfolio_overview_data(data, categories, structure, config,
                                   weights = weights,
                                   category_results = category_results)
}


# ===========================================================================
# Public entry point — compute_portfolio_overview_data()
# ===========================================================================

test_that("returns PASS status for well-formed inputs", {
  r <- .po_call()
  expect_equal(r$status, "PASS")
  expect_equal(r$focal_brand, "IPK")
})

test_that("refuses with DATA_OVERVIEW_NO_DATA when data is NULL", {
  r <- compute_portfolio_overview_data(NULL, .po_categories(), .po_structure(),
                                        .po_config())
  expect_equal(r$status, "REFUSED")
  expect_equal(r$code, "DATA_OVERVIEW_NO_DATA")
})

test_that("refuses with DATA_OVERVIEW_NO_DATA when data is empty", {
  r <- compute_portfolio_overview_data(.po_data()[0, ], .po_categories(),
                                        .po_structure(), .po_config())
  expect_equal(r$status, "REFUSED")
  expect_equal(r$code, "DATA_OVERVIEW_NO_DATA")
})

test_that("refuses with DATA_OVERVIEW_NO_CATEGORIES when categories empty", {
  r <- compute_portfolio_overview_data(.po_data(),
                                        .po_categories()[0, ],
                                        .po_structure(), .po_config())
  expect_equal(r$status, "REFUSED")
  expect_equal(r$code, "DATA_OVERVIEW_NO_CATEGORIES")
})

test_that("refuses with DATA_OVERVIEW_NO_COVERAGE when no awareness detected", {
  bad <- .po_structure()
  bad$questionmap$Role <- c("other.role.DSS", "other.role.SLD")
  r <- .po_call(structure = bad)
  expect_equal(r$status, "REFUSED")
  expect_equal(r$code, "DATA_OVERVIEW_NO_COVERAGE")
})


# ===========================================================================
# Category records — includes BOTH deep-dive and awareness-only
# ===========================================================================

test_that("categories list spans ALL config categories (deep + awareness)", {
  r <- .po_call()
  expect_equal(sort(names(r$categories)), c("DSS", "SLD"))
})

test_that("cat_usage_pct = buyers / n_total * 100", {
  r <- .po_call()
  expect_equal(r$categories$DSS$cat_usage_pct, 75.0, tolerance = 1e-6)
  expect_equal(r$categories$SLD$cat_usage_pct, 75.0, tolerance = 1e-6)
})

test_that("n_buyers_uw matches SQ2 flag count", {
  r <- .po_call()
  expect_equal(r$categories$DSS$n_buyers_uw, 3L)
  expect_equal(r$categories$SLD$n_buyers_uw, 3L)
})

test_that("total_n_uw matches nrow(data)", {
  r <- .po_call()
  expect_equal(r$categories$DSS$total_n_uw, 4L)
  expect_equal(r$categories$SLD$total_n_uw, 4L)
})

test_that("analysis_depth labels propagate from config$categories", {
  r <- .po_call()
  expect_equal(r$categories$DSS$analysis_depth, "full")
  expect_equal(r$categories$SLD$analysis_depth, "awareness_only")
})

test_that("awareness_pct computed against category buyers only", {
  r <- .po_call()
  expect_equal(r$categories$DSS$awareness_pct$IPK, 100.0, tolerance = 1e-6)
  expect_equal(r$categories$DSS$awareness_pct$ROB, 200/3, tolerance = 1e-6)
  expect_equal(r$categories$DSS$awareness_pct$ZEN, 100/3, tolerance = 1e-6)
  expect_equal(r$categories$DSS$awareness_pct$BLU, 100.0, tolerance = 1e-6)
  expect_equal(r$categories$SLD$awareness_pct$SAL, 200/3, tolerance = 1e-6)
  expect_equal(r$categories$SLD$awareness_pct$FRE, 100/3, tolerance = 1e-6)
  expect_equal(r$categories$SLD$awareness_pct$TOM, 100/3, tolerance = 1e-6)
  expect_equal(r$categories$SLD$awareness_pct$BLU, 100/3, tolerance = 1e-6)
})

test_that("brand_codes and brand_names propagate from structure", {
  r <- .po_call()
  expect_equal(r$categories$DSS$brand_codes,
               c("IPK", "ROB", "ZEN", "BLU"))
  expect_equal(r$categories$DSS$brand_names$IPK, "Impulse")
  expect_equal(r$categories$DSS$brand_names$BLU, "Blue")
  expect_equal(r$categories$SLD$brand_codes,
               c("SAL", "FRE", "TOM", "BLU"))
  expect_equal(r$categories$SLD$brand_names$SAL, "Salado")
})


# ===========================================================================
# Deep-dive enrichment — penetration, SCR, frequency, volume share
# ===========================================================================

test_that("deep_dive is NULL for awareness-only categories", {
  r <- .po_call()
  expect_null(r$categories$SLD$deep_dive)
})

test_that("deep-dive penetration_pct = buyers / n_resp * 100", {
  r  <- .po_call()
  dd <- r$categories$DSS$deep_dive
  expect_equal(dd$IPK$penetration_pct, 75.0, tolerance = 1e-6)
  expect_equal(dd$ROB$penetration_pct, 50.0, tolerance = 1e-6)
  expect_equal(dd$ZEN$penetration_pct, 0.0,  tolerance = 1e-6)
  expect_equal(dd$BLU$penetration_pct, 0.0,  tolerance = 1e-6)
})

test_that("deep-dive freq_mean = mean of volumes among buyers only", {
  r  <- .po_call()
  dd <- r$categories$DSS$deep_dive
  expect_equal(dd$IPK$freq_mean, 7/3, tolerance = 1e-6)
  expect_equal(dd$ROB$freq_mean, 1.5, tolerance = 1e-6)
  # Zero-buyer brands → NA_real_ (not NaN)
  expect_true(is.na(dd$ZEN$freq_mean))
  expect_true(is.na(dd$BLU$freq_mean))
})

test_that("deep-dive vol_share_pct = brand_vol / cat_total * 100", {
  r  <- .po_call()
  dd <- r$categories$DSS$deep_dive
  expect_equal(dd$IPK$vol_share_pct, 70.0, tolerance = 1e-6)
  expect_equal(dd$ROB$vol_share_pct, 30.0, tolerance = 1e-6)
  expect_equal(dd$ZEN$vol_share_pct, 0.0,  tolerance = 1e-6)
  expect_equal(dd$BLU$vol_share_pct, 0.0,  tolerance = 1e-6)
})

test_that("deep-dive scr_pct comes from repertoire share_of_requirements", {
  r  <- .po_call()
  dd <- r$categories$DSS$deep_dive
  expect_equal(dd$IPK$scr_pct, 70.0, tolerance = 1e-6)
  expect_equal(dd$ROB$scr_pct, 30.0, tolerance = 1e-6)
  # Missing from SoR table → NA, not 0.
  expect_true(is.na(dd$ZEN$scr_pct))
  expect_true(is.na(dd$BLU$scr_pct))
})

test_that("buyers_n is integer count of buyers", {
  r  <- .po_call()
  dd <- r$categories$DSS$deep_dive
  expect_equal(dd$IPK$buyers_n, 3L)
  expect_equal(dd$ROB$buyers_n, 2L)
  expect_equal(dd$ZEN$buyers_n, 0L)
  expect_equal(dd$BLU$buyers_n, 0L)
})

test_that("missing repertoire yields NA scr_pct but other metrics survive", {
  cr <- .po_category_results()
  cr$Dishwashing$repertoire <- NULL
  r  <- .po_call(category_results = cr)
  dd <- r$categories$DSS$deep_dive
  expect_true(is.na(dd$IPK$scr_pct))
  expect_equal(dd$IPK$penetration_pct, 75.0, tolerance = 1e-6)
  expect_equal(dd$IPK$vol_share_pct,   70.0, tolerance = 1e-6)
})

test_that("missing brand_volume yields NULL deep_dive (not error)", {
  cr <- .po_category_results()
  cr$Dishwashing$brand_volume <- NULL
  r  <- .po_call(category_results = cr)
  expect_null(r$categories$DSS$deep_dive)
})

test_that("category_results = NULL omits deep-dive entirely", {
  r <- .po_call(category_results = NULL)
  expect_null(r$categories$DSS$deep_dive)
  expect_null(r$categories$SLD$deep_dive)
  expect_equal(r$categories$DSS$awareness_pct$IPK, 100.0, tolerance = 1e-6)
})


# ===========================================================================
# Brands list: focal-first ordering, name resolution, cross-cat presence
# ===========================================================================

test_that("brands list puts focal brand first", {
  r <- .po_call()
  expect_equal(r$brands$brand_code[1], "IPK")
})

test_that("brands list contains the union of all category brand codes", {
  r <- .po_call()
  expect_equal(sort(r$brands$brand_code),
               sort(c("IPK", "ROB", "ZEN", "BLU", "SAL", "FRE", "TOM")))
})

test_that("brands list resolves BrandName from structure", {
  r <- .po_call()
  expect_equal(r$brands$brand_name[r$brands$brand_code == "IPK"], "Impulse")
  expect_equal(r$brands$brand_name[r$brands$brand_code == "BLU"], "Blue")
  expect_equal(r$brands$brand_name[r$brands$brand_code == "SAL"], "Salado")
})

test_that("n_categories_present counts categories with awareness > 0", {
  r <- .po_call()
  # BLU spans both cats; all others only one.
  expect_equal(r$brands$n_categories_present[r$brands$brand_code == "BLU"], 2L)
  expect_equal(r$brands$n_categories_present[r$brands$brand_code == "IPK"], 1L)
  expect_equal(r$brands$n_categories_present[r$brands$brand_code == "SAL"], 1L)
})

test_that("non-focal brands sorted by n_categories_present desc then name asc", {
  r <- .po_call()
  non_focal <- r$brands[r$brands$brand_code != "IPK", , drop = FALSE]
  # BLU (2 cats) must come first among non-focals.
  expect_equal(non_focal$brand_code[1], "BLU")
})


# ===========================================================================
# build_portfolio_overview() — presentation wrapper
# ===========================================================================

test_that("wrapper returns payload when results$portfolio_overview present", {
  payload <- .po_call()
  r <- build_portfolio_overview(list(portfolio_overview = payload), .po_config())
  expect_equal(r$status, "PASS")
  expect_equal(r$focal_brand, "IPK")
})

test_that("wrapper reads payload from results$results$portfolio_overview", {
  payload <- .po_call()
  r <- build_portfolio_overview(
    list(results = list(portfolio_overview = payload)), .po_config())
  expect_equal(r$status, "PASS")
})

test_that("wrapper refuses DATA_OVERVIEW_NO_RESULTS when results NULL", {
  r <- build_portfolio_overview(NULL, .po_config())
  expect_equal(r$status, "REFUSED")
  expect_equal(r$code, "DATA_OVERVIEW_NO_RESULTS")
})

test_that("wrapper refuses DATA_OVERVIEW_NOT_COMPUTED when payload missing", {
  r <- build_portfolio_overview(list(), .po_config())
  expect_equal(r$status, "REFUSED")
  expect_equal(r$code, "DATA_OVERVIEW_NOT_COMPUTED")
})

test_that("wrapper refuses DATA_OVERVIEW_NOT_COMPUTED when categories empty", {
  payload <- list(status = "PASS", focal_brand = "IPK",
                  brands = data.frame(), categories = list())
  r <- build_portfolio_overview(list(portfolio_overview = payload), .po_config())
  expect_equal(r$status, "REFUSED")
  expect_equal(r$code, "DATA_OVERVIEW_NOT_COMPUTED")
})


# ===========================================================================
# Weighting behaviour
# ===========================================================================

test_that("weights affect awareness computation", {
  w <- c(2.0, 1.0, 1.0, 1.0)
  r <- .po_call(weights = w)
  # DSS buyers (rows 1-3) with w={2,1,1} → denom = 4.
  # IPK aware in all three rows → (2+1+1)/4 = 100%.
  expect_equal(r$categories$DSS$awareness_pct$IPK, 100.0, tolerance = 1e-6)
  # ROB aware in rows 1,3 → (2+1)/4 = 75%.
  expect_equal(r$categories$DSS$awareness_pct$ROB, 75.0, tolerance = 1e-6)
})


# ===========================================================================
# cross_cat.awareness role detection
# ===========================================================================

test_that("cross_cat.awareness.{CC} roles also map to their category code", {
  # SLD is awareness-only in the real 9cat study; the role prefix is
  # cross_cat.awareness rather than funnel.awareness. Simulate that shape.
  st <- .po_structure()
  st$questionmap$Role <- c("funnel.awareness.DSS", "cross_cat.awareness.SLD")
  r <- .po_call(structure = st)
  expect_equal(sort(names(r$categories)), c("DSS", "SLD"))
  expect_equal(r$categories$SLD$analysis_depth, "awareness_only")
})


# ===========================================================================
# Absent awareness column — NA, not zero
# ===========================================================================

test_that("missing BRANDAWARE column yields NA, not 0", {
  d <- .po_data()
  d$BRANDAWARE_DSS_ROB <- NULL
  r <- .po_call(data = d)
  expect_true(is.na(r$categories$DSS$awareness_pct$ROB))
  expect_equal(r$categories$DSS$awareness_pct$IPK, 100.0, tolerance = 1e-6)
})
