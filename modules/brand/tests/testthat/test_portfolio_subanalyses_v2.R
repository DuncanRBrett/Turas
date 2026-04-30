# ==============================================================================
# Tests for Portfolio sub-analyses V2 (slot-indexed migration, Step 3i)
# ==============================================================================
# Verifies that the v2 sub-analysis entries (compute_*_v2) build awareness
# matrices via the slot-indexed data-access layer (multi_mention_brand_matrix
# + multi_mention_indicator_matrix) instead of the legacy column-per-brand
# pattern (BRANDAWARE_{cat}_{brand} == 1L).
#
# Three test layers:
#   1. The shared helper .portfolio_aware_matrix_v2() — known-answer.
#   2. Each compute_*_v2() — known-answer on a hand-coded 3-cat x 4-brand
#      mini-fixture, plus invariant checks (low-base suppression, missing
#      CategoryCode refusal).
#   3. IPK Wave 1 integration — runs each v2 entry against the real fixture
#      and asserts the output shape + non-trivial values.
# ==============================================================================
library(testthat)

.find_root_pf_v2 <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_pf_v2()

source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map_v2.R"))
source(file.path(ROOT, "modules", "brand", "R", "01_config.R"))
source(file.path(ROOT, "modules", "brand", "R", "09_portfolio.R"))
source(file.path(ROOT, "modules", "brand", "R", "09a_portfolio_footprint.R"))
source(file.path(ROOT, "modules", "brand", "R", "09b_portfolio_constellation.R"))
source(file.path(ROOT, "modules", "brand", "R", "09c_portfolio_clutter.R"))
source(file.path(ROOT, "modules", "brand", "R", "09d_portfolio_strength.R"))
source(file.path(ROOT, "modules", "brand", "R", "09e_portfolio_extension.R"))
source(file.path(ROOT, "modules", "brand", "R", "09h_portfolio_overview_data.R"))


# ------------------------------------------------------------------------------
# Hand-coded mini-fixture: 3 categories x 4 brands, 8 respondents
# ------------------------------------------------------------------------------
# Categories: DSS, POS, BAK
# Brand universe: A, B, C, D
#
# Awareness (slot-indexed, BRANDAWARE_{cat}_1..N hold brand codes):
#   DSS:
#     r1 -> A,B    r2 -> A,B,C  r3 -> A      r4 -> A,B,C,D
#     r5 -> A,B    r6 -> B      r7 -> A      r8 -> (none)
#   POS:
#     r1 -> A      r2 -> A,B    r3 -> NULL   r4 -> B,C
#     r5 -> A      r6 -> NULL   r7 -> NULL   r8 -> A
#   BAK:
#     r1 -> A,B,C,D  r2 -> A,B,C,D  r3 -> A,B,C,D  r4 -> A,B,C,D
#     r5 -> A,B,C,D  r6 -> A,B,C,D  r7 -> A,B,C,D  r8 -> A,B,C,D
#
# Screener SQ2 slots (3m target window):
#   r1 -> DSS,POS  r2 -> DSS  r3 -> DSS  r4 -> DSS,POS
#   r5 -> DSS  r6 -> POS  r7 -> NONE  r8 -> POS
# DSS qualifiers: r1,r2,r3,r4,r5 (n=5)
# POS qualifiers: r1,r4,r6,r8     (n=4)
# BAK qualifiers: 0 (no SQ2 hits) — base will REFUSE; cat dropped
#
# DSS awareness % among DSS qualifiers (r1..r5):
#   A: r1,r2,r3,r4,r5 -> 5/5 = 100%
#   B: r1,r2,r4,r5    -> 4/5 = 80%
#   C: r2,r4          -> 2/5 = 40%
#   D: r4             -> 1/5 = 20%
#
# POS awareness % among POS qualifiers (r1,r4,r6,r8):
#   A: r1,r8     -> 2/4 = 50%
#   B: r4        -> 1/4 = 25%
#   C: r4        -> 1/4 = 25%
#   D: 0/4 = 0%
# ------------------------------------------------------------------------------

mk_pf_v2_data <- function() {
  data.frame(
    BRANDAWARE_DSS_1 = c("A","A","A","A","A","B","A",NA),
    BRANDAWARE_DSS_2 = c("B","B",NA,"B","B",NA,NA,NA),
    BRANDAWARE_DSS_3 = c(NA,"C",NA,"C",NA,NA,NA,NA),
    BRANDAWARE_DSS_4 = c(NA,NA,NA,"D",NA,NA,NA,NA),

    BRANDAWARE_POS_1 = c("A","A",NA,"B","A",NA,NA,"A"),
    BRANDAWARE_POS_2 = c(NA,"B",NA,"C",NA,NA,NA,NA),
    BRANDAWARE_POS_3 = c(NA,NA,NA,NA,NA,NA,NA,NA),

    BRANDAWARE_BAK_1 = rep("A", 8),
    BRANDAWARE_BAK_2 = rep("B", 8),
    BRANDAWARE_BAK_3 = rep("C", 8),
    BRANDAWARE_BAK_4 = rep("D", 8),

    SQ2_1 = c("DSS","DSS","DSS","DSS","DSS","POS","NONE","POS"),
    SQ2_2 = c("POS",NA,NA,"POS",NA,NA,NA,NA),
    SQ1_1 = c("DSS","DSS","DSS","DSS","DSS","POS","DSS","POS"),
    SQ1_2 = c("POS",NA,NA,"POS",NA,NA,NA,NA),

    stringsAsFactors = FALSE
  )
}

mk_pf_v2_categories <- function() {
  data.frame(
    Category     = c("Dressings", "Pourable Sauces", "Baking"),
    CategoryCode = c("DSS",       "POS",            "BAK"),
    Active       = c("Y", "Y", "Y"),
    stringsAsFactors = FALSE
  )
}

mk_pf_v2_structure <- function() {
  brands <- data.frame(
    Category = rep(c("Dressings","Pourable Sauces","Baking"), each = 4),
    CategoryCode = rep(c("DSS","POS","BAK"), each = 4),
    BrandCode = rep(c("A","B","C","D"), 3),
    BrandLabel = paste0("Brand_", rep(c("A","B","C","D"), 3)),
    stringsAsFactors = FALSE
  )
  list(
    brands = brands,
    questionmap = NULL  # convention-first inference; helper falls back to BRANDAWARE_{cat}
  )
}

mk_pf_v2_config <- function(focal = "A", min_base = 1L,
                             timeframe = "3m") {
  list(
    focal_brand                  = focal,
    portfolio_timeframe          = timeframe,
    portfolio_min_base           = min_base,
    portfolio_cooccur_min_pairs  = 1L,
    portfolio_edge_top_n         = 40L
  )
}


# ------------------------------------------------------------------------------
# .portfolio_aware_matrix_v2 — known-answer
# ------------------------------------------------------------------------------

test_that(".portfolio_aware_matrix_v2: DSS produces hand-checked 0/1 matrix", {
  data <- mk_pf_v2_data()
  mat  <- .portfolio_aware_matrix_v2(data, NULL, "DSS", c("A","B","C","D"))
  expect_equal(dim(mat), c(8L, 4L))
  expect_equal(colnames(mat), c("A","B","C","D"))
  # Hand-checked: A is aware in r1..r7 (NOT r8); B in r1,r2,r4,r5,r6; etc.
  expect_equal(unname(mat[, "A"]), c(1L,1L,1L,1L,1L,0L,1L,0L))
  expect_equal(unname(mat[, "B"]), c(1L,1L,0L,1L,1L,1L,0L,0L))
  expect_equal(unname(mat[, "C"]), c(0L,1L,0L,1L,0L,0L,0L,0L))
  expect_equal(unname(mat[, "D"]), c(0L,0L,0L,1L,0L,0L,0L,0L))
})


test_that(".portfolio_aware_matrix_v2: empty brand list returns 0-col matrix", {
  data <- mk_pf_v2_data()
  mat  <- .portfolio_aware_matrix_v2(data, NULL, "DSS", character(0))
  expect_equal(dim(mat), c(8L, 0L))
})


test_that(".portfolio_aware_matrix_v2: role_map override resolves a custom root", {
  data <- mk_pf_v2_data()
  role_map <- list(
    portfolio.awareness.DSS = list(column_root = "BRANDAWARE_DSS",
                                   variable_type = "Multi_Mention")
  )
  mat <- .portfolio_aware_matrix_v2(data, role_map, "DSS",
                                     c("A","B","C","D"))
  # Same answer as convention path
  expect_equal(unname(mat[, "A"]), c(1L,1L,1L,1L,1L,0L,1L,0L))
})


# ------------------------------------------------------------------------------
# compute_footprint_matrix_v2 — known-answer
# ------------------------------------------------------------------------------

test_that("compute_footprint_matrix_v2: DSS + POS rows match hand-calculated %", {
  data       <- mk_pf_v2_data()
  categories <- mk_pf_v2_categories()
  structure  <- mk_pf_v2_structure()
  config     <- mk_pf_v2_config(min_base = 1L)

  out <- compute_footprint_matrix_v2(data, role_map = NULL, categories,
                                      structure, config)
  expect_equal(out$status, "PASS")

  m <- out$matrix_df
  expect_true("Brand" %in% names(m))
  # BAK should be dropped (no SQ2 qualifiers); DSS + POS remain
  expect_setequal(setdiff(names(m), "Brand"), c("DSS", "POS"))

  # Row order: DSS+POS row sum descending. A wins.
  expect_equal(m$Brand[1], "A")
  expect_equal(m$DSS[m$Brand == "A"], 100)
  expect_equal(m$POS[m$Brand == "A"], 50)
  expect_equal(m$DSS[m$Brand == "B"], 80)
  expect_equal(m$POS[m$Brand == "B"], 25)
  expect_equal(m$DSS[m$Brand == "C"], 40)
  expect_equal(m$DSS[m$Brand == "D"], 20)
  expect_equal(m$POS[m$Brand == "D"], 0)

  # Bases — DSS qualifies 5, POS qualifies 4
  expect_equal(out$bases_df$n_buyers_uw[out$bases_df$cat == "DSS"], 5L)
  expect_equal(out$bases_df$n_buyers_uw[out$bases_df$cat == "POS"], 4L)

  # Brand labels survive
  expect_equal(out$brand_names[["A"]], "Brand_A")
})


test_that("compute_footprint_matrix_v2: low-base cats appear in suppressed_cats", {
  data       <- mk_pf_v2_data()
  categories <- mk_pf_v2_categories()
  structure  <- mk_pf_v2_structure()
  # min_base = 5 — POS (n=4) flagged, DSS (n=5) keeps
  config     <- mk_pf_v2_config(min_base = 5L)

  out <- compute_footprint_matrix_v2(data, role_map = NULL, categories,
                                      structure, config)
  expect_true("POS" %in% out$suppressed_cats)
  expect_false("DSS" %in% out$suppressed_cats)
  # POS is still emitted in the matrix per the v1 contract — flag is for
  # the renderer.
  expect_true("POS" %in% setdiff(names(out$matrix_df), "Brand"))
})


test_that("compute_footprint_matrix_v2: refuses without CategoryCode column", {
  data       <- mk_pf_v2_data()
  cats_no_cc <- mk_pf_v2_categories()
  cats_no_cc$CategoryCode <- NULL
  structure  <- mk_pf_v2_structure()
  config     <- mk_pf_v2_config()

  out <- compute_footprint_matrix_v2(data, role_map = NULL, cats_no_cc,
                                      structure, config)
  expect_equal(out$status, "REFUSED")
  expect_equal(out$code, "CFG_PORTFOLIO_NO_CATEGORY_CODE")
})


test_that("compute_footprint_matrix_v2: weighted base influences awareness %", {
  data       <- mk_pf_v2_data()
  categories <- mk_pf_v2_categories()
  structure  <- mk_pf_v2_structure()
  config     <- mk_pf_v2_config(min_base = 1L)

  # Heavily weight r1 (DSS qualifier, aware A+B not C+D) so DSS A/B stays
  # at 100/100 but C/D drops sharply.
  w <- c(100, 1, 1, 1, 1, 1, 1, 1)
  out <- compute_footprint_matrix_v2(data, role_map = NULL, categories,
                                      structure, config, weights = w)
  expect_equal(out$status, "PASS")
  m <- out$matrix_df
  # DSS qualifiers w-sum = 100+1+1+1+1 = 104. A awareness w-sum = 104.
  expect_equal(m$DSS[m$Brand == "A"], 100)
  # B awareness w-sum = r1+r2+r4+r5 = 100+1+1+1 = 103 / 104 ≈ 99.04%
  expect_equal(m$DSS[m$Brand == "B"], 103 / 104 * 100, tolerance = 1e-6)
  # C awareness w-sum = r2+r4 = 2 / 104 ≈ 1.92%
  expect_equal(m$DSS[m$Brand == "C"], 2 / 104 * 100, tolerance = 1e-6)
})


# ------------------------------------------------------------------------------
# Integration: against the IPK Wave 1 fixture
# ------------------------------------------------------------------------------

test_that("IPK Wave 1: compute_footprint_matrix_v2 runs and returns a brand x cat matrix", {
  data_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                          "ipk_wave1", "ipk_wave1_data.xlsx")
  ss_path   <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                          "ipk_wave1", "Survey_Structure.xlsx")
  bc_path   <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                          "ipk_wave1", "Brand_Config.xlsx")
  skip_if_not(file.exists(data_path), "IPK Wave 1 fixture not built")
  skip_if_not(file.exists(ss_path),   "IPK Survey_Structure not built")
  skip_if_not(file.exists(bc_path),   "IPK Brand_Config not built")

  data <- openxlsx::read.xlsx(data_path)

  # Build minimal structure+categories from the fixture sheets directly.
  brands_df <- openxlsx::read.xlsx(ss_path, sheet = "Brands")
  cats_df   <- openxlsx::read.xlsx(bc_path, sheet = "Categories")
  structure <- list(brands = brands_df, questionmap = NULL)

  # Active-only category list — must have CategoryCode
  active_cats <- cats_df[!is.na(cats_df$Active) &
                          toupper(cats_df$Active) == "Y", , drop = FALSE]
  expect_true("CategoryCode" %in% names(active_cats))
  expect_gt(nrow(active_cats), 0L)

  config <- list(
    focal_brand                  = "IPK",
    portfolio_timeframe          = "3m",
    portfolio_min_base           = 30L,
    portfolio_cooccur_min_pairs  = 5L,
    portfolio_edge_top_n         = 40L
  )

  out <- compute_footprint_matrix_v2(data, role_map = NULL,
                                      categories = active_cats,
                                      structure  = structure,
                                      config     = config)

  expect_equal(out$status, "PASS")
  expect_true(is.data.frame(out$matrix_df))
  expect_gt(nrow(out$matrix_df), 0L)
  expect_true("DSS" %in% setdiff(names(out$matrix_df), "Brand"))

  # IPK should appear in the brand list (DSS focal brand)
  expect_true("IPK" %in% out$matrix_df$Brand)
  ipk_dss <- out$matrix_df$DSS[out$matrix_df$Brand == "IPK"]
  expect_true(is.finite(ipk_dss) && ipk_dss >= 0 && ipk_dss <= 100)
})


# ------------------------------------------------------------------------------
# compute_clutter_data_v2
# ------------------------------------------------------------------------------

test_that("compute_clutter_data_v2: per-cat metrics match hand calculation", {
  data       <- mk_pf_v2_data()
  categories <- mk_pf_v2_categories()
  structure  <- mk_pf_v2_structure()
  config     <- mk_pf_v2_config(focal = "A", min_base = 1L)

  out <- compute_clutter_data_v2(data, role_map = NULL, categories,
                                  structure, config)
  expect_equal(out$status, "PASS")

  cl <- out$clutter_df
  # DSS qualifiers: r1..r5
  # awareness set sizes per qualifier:
  #   r1: A,B = 2;  r2: A,B,C = 3;  r3: A = 1;  r4: A,B,C,D = 4;  r5: A,B = 2
  # mean = (2+3+1+4+2)/5 = 2.4
  dss_row <- cl[cl$cat == "DSS", , drop = FALSE]
  expect_equal(dss_row$awareness_set_size_mean, 2.4, tolerance = 1e-9)

  # focal_share_of_aware = focal_pct / sum(brand_pcts)
  #   pcts: A=100, B=80, C=40, D=20 -> sum=240 -> focal A=100/240
  expect_equal(dss_row$focal_share_of_aware, 100 / 240, tolerance = 1e-9)
  # cat_penetration = 5/8
  expect_equal(dss_row$cat_penetration, 5 / 8)
  # fair_share = 1 / 4
  expect_equal(dss_row$fair_share, 1 / 4)

  # POS qualifiers: r1, r4, r6, r8
  # set sizes: r1=A => 1, r4=B,C => 2, r6=NULL => 0, r8=A => 1
  # mean = (1+2+0+1)/4 = 1.0
  pos_row <- cl[cl$cat == "POS", , drop = FALSE]
  expect_equal(pos_row$awareness_set_size_mean, 1.0, tolerance = 1e-9)
})


test_that("compute_clutter_data_v2: BAK is suppressed (zero qualifiers)", {
  data       <- mk_pf_v2_data()
  categories <- mk_pf_v2_categories()
  structure  <- mk_pf_v2_structure()
  config     <- mk_pf_v2_config(min_base = 1L)

  out <- compute_clutter_data_v2(data, role_map = NULL, categories,
                                  structure, config)
  expect_true("BAK" %in% out$suppressed_cats)
  expect_false("BAK" %in% out$clutter_df$cat)
})


test_that("compute_clutter_data_v2: refuses without CategoryCode column", {
  data       <- mk_pf_v2_data()
  cats_no_cc <- mk_pf_v2_categories()
  cats_no_cc$CategoryCode <- NULL
  out <- compute_clutter_data_v2(data, role_map = NULL, cats_no_cc,
                                  mk_pf_v2_structure(), mk_pf_v2_config())
  expect_equal(out$status, "REFUSED")
  expect_equal(out$code, "CFG_PORTFOLIO_NO_CATEGORY_CODE")
})


# ------------------------------------------------------------------------------
# compute_strength_map_v2
# ------------------------------------------------------------------------------

test_that("compute_strength_map_v2: per-brand rows match hand calculation", {
  data       <- mk_pf_v2_data()
  categories <- mk_pf_v2_categories()
  structure  <- mk_pf_v2_structure()
  config     <- mk_pf_v2_config(min_base = 1L)

  out <- compute_strength_map_v2(data, role_map = NULL, categories,
                                  structure, config)
  expect_equal(out$status, "PASS")

  per <- out$per_brand
  # A is in DSS (5/5 = 100, aware_n_w=5) and POS (2/4 = 50, aware_n_w=2).
  expect_true(setequal(per[["A"]]$cat, c("DSS", "POS")))
  dss_a <- per[["A"]][per[["A"]]$cat == "DSS", , drop = FALSE]
  expect_equal(dss_a$brand_aware, 100)
  expect_equal(dss_a$aware_n_w, 5)
  expect_equal(dss_a$cat_pen, 5 / 8)
  pos_a <- per[["A"]][per[["A"]]$cat == "POS", , drop = FALSE]
  expect_equal(pos_a$brand_aware, 50)
  expect_equal(pos_a$aware_n_w, 2)

  # D appears in DSS only (0% in POS still passes — brand_aware = 0)
  expect_true("D" %in% names(per))
  d_dss <- per[["D"]][per[["D"]]$cat == "DSS", , drop = FALSE]
  expect_equal(d_dss$brand_aware, 20)
  expect_equal(d_dss$aware_n_w, 1)
})


test_that("compute_strength_map_v2: BAK is suppressed (zero qualifiers)", {
  data       <- mk_pf_v2_data()
  out <- compute_strength_map_v2(data, role_map = NULL,
                                  mk_pf_v2_categories(),
                                  mk_pf_v2_structure(),
                                  mk_pf_v2_config(min_base = 1L))
  expect_true("BAK" %in% out$suppressed_cats)
})


# ------------------------------------------------------------------------------
# compute_extension_table_v2
# ------------------------------------------------------------------------------

test_that("compute_extension_table_v2: focal awareness % per cat matches hand calc", {
  data       <- mk_pf_v2_data()
  categories <- mk_pf_v2_categories()
  structure  <- mk_pf_v2_structure()
  # Focal = A. Home cat configured = DSS (skip auto-detect).
  config     <- mk_pf_v2_config(focal = "A", min_base = 1L)
  config$focal_home_category <- "DSS"

  out <- compute_extension_table_v2(data, role_map = NULL, categories,
                                     structure, config)
  expect_equal(out$status, "PASS")
  expect_equal(out$home_cat, "DSS")
  expect_equal(out$home_cat_source, "config")

  ext <- out$extension_df
  # Focal-aware in DSS (qualifiers r1..r5, all aware of A) = 100%
  expect_equal(ext$focal_aware_pct[ext$cat == "DSS"], 100)
  # Focal-aware in POS (qualifiers r1,r4,r6,r8 ; A aware in r1,r8) = 2/4 = 50%
  expect_equal(ext$focal_aware_pct[ext$cat == "POS"], 50)

  # Lift uses category-specific focal awareness.
  # Baseline (mode="all"): p_base for cat c uses respondent_picked(data,
  # "BRANDAWARE_{c}", focal). For DSS:
  #   A aware across BRANDAWARE_DSS slots: r1..r5 + r7 = 6/8 = 0.75
  #   p_c (DSS qualifiers) = 5/5 = 1.0 -> lift = 1.0 / 0.75 = 4/3
  expect_equal(ext$lift[ext$cat == "DSS"], 4 / 3, tolerance = 1e-9)
  # POS A awareness across all 8: r1,r2,r5,r8 = 4/8 = 0.5
  # p_c POS = 2/4 = 0.5 -> lift = 0.5 / 0.5 = 1.0
  expect_equal(ext$lift[ext$cat == "POS"], 1.0, tolerance = 1e-9)
})


test_that("compute_extension_table_v2: refuses when focal not in any category", {
  config <- mk_pf_v2_config(focal = "Z")
  out <- compute_extension_table_v2(mk_pf_v2_data(), role_map = NULL,
                                     mk_pf_v2_categories(),
                                     mk_pf_v2_structure(), config)
  expect_equal(out$status, "REFUSED")
  expect_equal(out$code, "CALC_EXTENSION_NO_FOCAL_AWARENESS")
})


test_that("compute_extension_table_v2: refuses with empty focal", {
  config <- mk_pf_v2_config(focal = "")
  out <- compute_extension_table_v2(mk_pf_v2_data(), role_map = NULL,
                                     mk_pf_v2_categories(),
                                     mk_pf_v2_structure(), config)
  expect_equal(out$status, "REFUSED")
})


# ------------------------------------------------------------------------------
# compute_extension_per_brand_v2
# ------------------------------------------------------------------------------

test_that("compute_extension_per_brand_v2: walks brand universe from structure$brands", {
  data       <- mk_pf_v2_data()
  categories <- mk_pf_v2_categories()
  structure  <- mk_pf_v2_structure()
  config     <- mk_pf_v2_config(focal = "A", min_base = 1L)
  config$focal_home_category <- "DSS"

  out <- compute_extension_per_brand_v2(data, role_map = NULL, categories,
                                         structure, config)
  # Universe is c("A","B","C","D"); D has zero non-DSS exposure but still
  # produces a PASS extension table (lift=NA where p_base=0 / p_c=0).
  expect_true(all(c("A","B","C") %in% names(out$per_brand)))
  expect_equal(out$brand_names[["A"]], "Brand_A")

  # Per-brand result shape — each is a full extension_table_v2 result
  expect_true(is.data.frame(out$per_brand[["A"]]$extension_df))
  expect_equal(out$per_brand[["A"]]$home_cat, "DSS")
})


# ------------------------------------------------------------------------------
# compute_constellation_v2 + compute_constellations_per_cat_v2
# ------------------------------------------------------------------------------

test_that("compute_constellation_v2: returns nodes/edges/layout shape", {
  data       <- mk_pf_v2_data()
  categories <- mk_pf_v2_categories()
  structure  <- mk_pf_v2_structure()
  # Low cooccur_min so the small fixture produces edges
  config     <- mk_pf_v2_config(min_base = 1L)
  config$portfolio_cooccur_min_pairs <- 1L

  out <- compute_constellation_v2(data, role_map = NULL, categories,
                                   structure, config)
  expect_equal(out$status, "PASS")
  expect_true(is.data.frame(out$nodes))
  expect_true(is.data.frame(out$edges))
  expect_true(is.data.frame(out$layout))
  # All four declared brands have at least one aware respondent
  expect_setequal(out$nodes$brand, c("A", "B", "C", "D"))
  # Layout has same brand list
  expect_setequal(out$layout$brand, out$nodes$brand)
})


test_that("compute_constellation_v2: refuses with too-sparse fixture", {
  # Only 2 aware brands across whole fixture
  sparse <- data.frame(
    BRANDAWARE_DSS_1 = c("A","B"),
    BRANDAWARE_DSS_2 = c(NA, NA),
    SQ2_1            = c("DSS","DSS"),
    SQ1_1            = c("DSS","DSS"),
    stringsAsFactors = FALSE
  )
  cats <- data.frame(Category="Dressings", CategoryCode="DSS",
                     Active="Y", stringsAsFactors=FALSE)
  br   <- data.frame(Category="Dressings", CategoryCode="DSS",
                     BrandCode=c("A","B"),
                     BrandLabel=c("a","b"),
                     stringsAsFactors=FALSE)
  out <- compute_constellation_v2(sparse, role_map = NULL, cats,
                                   list(brands=br), mk_pf_v2_config(min_base=1L))
  expect_equal(out$status, "REFUSED")
  expect_equal(out$code, "CALC_CONSTELLATION_TOO_SPARSE")
})


test_that("compute_constellations_per_cat_v2: produces one entry per qualifying cat", {
  data       <- mk_pf_v2_data()
  categories <- mk_pf_v2_categories()
  structure  <- mk_pf_v2_structure()
  config     <- mk_pf_v2_config(min_base = 1L)
  config$portfolio_cooccur_min_pairs <- 1L

  out <- compute_constellations_per_cat_v2(data, role_map = NULL, categories,
                                             structure, config)
  expect_equal(out$status, "PASS")
  # DSS has all 4 brands aware in qualifiers; constellation should pass.
  expect_true("DSS" %in% out$cat_order)
  # POS has 3 brands aware in qualifiers (A, B, C); should also pass.
  # BAK has zero qualifiers; should be in suppressed_cats.
  expect_true("BAK" %in% out$suppressed_cats$cat)
})


# ------------------------------------------------------------------------------
# compute_portfolio_overview_data_v2
# ------------------------------------------------------------------------------

test_that("compute_portfolio_overview_data_v2: builds per-cat awareness records", {
  data       <- mk_pf_v2_data()
  categories <- mk_pf_v2_categories()
  structure  <- mk_pf_v2_structure()
  config     <- mk_pf_v2_config(focal = "A")

  out <- compute_portfolio_overview_data_v2(data, role_map = NULL, categories,
                                              structure, config)
  expect_equal(out$status, "PASS")
  expect_equal(out$focal_brand, "A")

  # DSS record: 4 brands, awareness {A:100, B:80, C:40, D:20}
  dss <- out$categories[["DSS"]]
  expect_equal(dss$cat_code, "DSS")
  expect_equal(as.numeric(dss$awareness_pct[["A"]]), 100)
  expect_equal(as.numeric(dss$awareness_pct[["B"]]), 80)
  expect_equal(as.numeric(dss$awareness_pct[["C"]]), 40)
  expect_equal(as.numeric(dss$awareness_pct[["D"]]), 20)

  # POS record present (4 qualifiers > 0); BAK absent (0 qualifiers)
  expect_true("POS" %in% names(out$categories))
  expect_false("BAK" %in% names(out$categories))

  # Brand list — A is focal, n_categories_present > 0
  expect_equal(out$brands$brand_code[1], "A")
})


test_that("compute_portfolio_overview_data_v2: refuses on missing CategoryCode", {
  cats_no_cc <- mk_pf_v2_categories()
  cats_no_cc$CategoryCode <- NULL
  out <- compute_portfolio_overview_data_v2(mk_pf_v2_data(), role_map = NULL,
                                              cats_no_cc,
                                              mk_pf_v2_structure(),
                                              mk_pf_v2_config())
  expect_equal(out$status, "REFUSED")
  expect_equal(out$code, "CFG_PORTFOLIO_NO_CATEGORY_CODE")
})


# ------------------------------------------------------------------------------
# Integration: IPK Wave 1 fixture — every v2 sub-analysis runs end-to-end
# ------------------------------------------------------------------------------

test_that("IPK Wave 1: every portfolio v2 sub-analysis runs end-to-end", {
  data_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                          "ipk_wave1", "ipk_wave1_data.xlsx")
  ss_path   <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                          "ipk_wave1", "Survey_Structure.xlsx")
  bc_path   <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                          "ipk_wave1", "Brand_Config.xlsx")
  skip_if_not(file.exists(data_path), "IPK Wave 1 fixture not built")
  skip_if_not(file.exists(ss_path),   "IPK Survey_Structure not built")
  skip_if_not(file.exists(bc_path),   "IPK Brand_Config not built")

  data <- openxlsx::read.xlsx(data_path)
  brands_df <- openxlsx::read.xlsx(ss_path, sheet = "Brands")
  cats_df   <- openxlsx::read.xlsx(bc_path, sheet = "Categories")
  structure <- list(brands = brands_df, questionmap = NULL)

  active_cats <- cats_df[!is.na(cats_df$Active) &
                          toupper(cats_df$Active) == "Y", , drop = FALSE]

  config <- list(
    focal_brand                  = "IPK",
    portfolio_timeframe          = "3m",
    portfolio_min_base           = 30L,
    portfolio_cooccur_min_pairs  = 5L,
    portfolio_edge_top_n         = 40L
  )

  fp <- compute_footprint_matrix_v2(data, role_map = NULL, active_cats,
                                     structure, config)
  expect_equal(fp$status, "PASS")
  expect_gt(nrow(fp$matrix_df), 0L)

  cl <- compute_clutter_data_v2(data, role_map = NULL, active_cats,
                                 structure, config)
  expect_equal(cl$status, "PASS")
  expect_true(is.data.frame(cl$clutter_df))

  st <- compute_strength_map_v2(data, role_map = NULL, active_cats,
                                 structure, config)
  expect_equal(st$status, "PASS")
  expect_true("IPK" %in% names(st$per_brand))

  ext <- compute_extension_table_v2(data, role_map = NULL, active_cats,
                                     structure, config,
                                     footprint_result = fp)
  expect_equal(ext$status, "PASS")
  expect_true(nzchar(ext$home_cat))

  ext_pb <- compute_extension_per_brand_v2(data, role_map = NULL, active_cats,
                                             structure, config,
                                             footprint_result = fp)
  expect_true("IPK" %in% names(ext_pb$per_brand))

  cn_per <- compute_constellations_per_cat_v2(data, role_map = NULL,
                                                active_cats, structure, config)
  expect_equal(cn_per$status, "PASS")
  expect_gt(length(cn_per$by_cat), 0L)

  ov <- compute_portfolio_overview_data_v2(data, role_map = NULL, active_cats,
                                             structure, config)
  expect_equal(ov$status, "PASS")
  expect_gt(length(ov$categories), 0L)
  expect_true("IPK" %in% ov$brands$brand_code)
})
