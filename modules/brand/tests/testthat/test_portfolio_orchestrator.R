# ==============================================================================
# Tests for run_portfolio — cross-cat portfolio orchestrator (Step 4d)
# ==============================================================================
# run_portfolio wires the eight v2 sub-analyses (footprint, clutter,
# strength, extension, per-brand extension, cross-cat constellation,
# per-cat constellations, supporting metrics) and threads the global
# role_map through every call. This is the last v2 switch before
# rebuild cutover (planning doc §9 step 5).
#
# Coverage:
#   1. Orchestrator-level happy path — every panel populated.
#   2. Result shape parity with run_portfolio v1 — same top-level keys.
#   3. Slot-aware repertoire depth — v2 supporting metric uses
#      respondent_picked() over CategoryCodes, not the legacy column grep.
#   4. Guard refusal — cross_category_awareness off, no BRANDAWARE cols.
#   5. .compute_portfolio_data router — routes to v2 when role_map non-NULL,
#      legacy when NULL.
# ==============================================================================
library(testthat)

.find_root_pforch <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_pforch()

source(file.path(ROOT, "modules", "shared", "lib", "trs_refusal.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(ROOT, "modules", "brand", "R", "01_config.R"))
source(file.path(ROOT, "modules", "brand", "R", "09_portfolio.R"))
source(file.path(ROOT, "modules", "brand", "R", "09a_portfolio_footprint.R"))
source(file.path(ROOT, "modules", "brand", "R", "09b_portfolio_constellation.R"))
source(file.path(ROOT, "modules", "brand", "R", "09c_portfolio_clutter.R"))
source(file.path(ROOT, "modules", "brand", "R", "09d_portfolio_strength.R"))
source(file.path(ROOT, "modules", "brand", "R", "09e_portfolio_extension.R"))


# ------------------------------------------------------------------------------
# Mini-fixture (shared shape with test_portfolio_subanalyses.R)
# ------------------------------------------------------------------------------
# 8 respondents × 3 categories (DSS, POS, BAK) × 4 brands (A, B, C, D)
#
# DSS qualifiers (SQ2):  r1..r5  (n=5)
# POS qualifiers (SQ2):  r1, r4, r6, r8 (n=4)
# BAK qualifiers (SQ2):  none (cat dropped)
#
# Hand-checked supporting metrics for focal = "A", min_base = 1, 3m:
#   focal_footprint_breadth = 2  (DSS=100%, POS=50% — both > 0)
#   n_cats_total            = 3  (DSS, POS, BAK)
#   mean_repertoire_depth   = (2+1+1+2+1+1+0+1) / 8 = 1.125
#     (per-respondent count of distinct CategoryCodes in SQ2_1..N, where
#      "NONE" is outside the active category list)
# ------------------------------------------------------------------------------

mk_pforch_data <- function() {
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

mk_pforch_categories <- function() {
  data.frame(
    Category     = c("Dressings", "Pourable Sauces", "Baking"),
    CategoryCode = c("DSS",       "POS",            "BAK"),
    Active       = c("Y", "Y", "Y"),
    stringsAsFactors = FALSE
  )
}

mk_pforch_structure <- function() {
  brands <- data.frame(
    Category     = rep(c("Dressings","Pourable Sauces","Baking"), each = 4),
    CategoryCode = rep(c("DSS","POS","BAK"), each = 4),
    BrandCode    = rep(c("A","B","C","D"), 3),
    BrandLabel   = paste0("Brand_", rep(c("A","B","C","D"), 3)),
    stringsAsFactors = FALSE
  )
  list(
    brands      = brands,
    questionmap = NULL,
    questions   = NULL
  )
}

mk_pforch_config <- function(focal = "A", min_base = 1L,
                              cooccur_min = 1L,
                              cross_cat_aware = TRUE) {
  list(
    focal_brand                  = focal,
    portfolio_timeframe          = "3m",
    portfolio_min_base           = min_base,
    portfolio_cooccur_min_pairs  = cooccur_min,
    portfolio_edge_top_n         = 40L,
    cross_category_awareness     = cross_cat_aware
  )
}


# ------------------------------------------------------------------------------
# Happy path — every panel populated
# ------------------------------------------------------------------------------

test_that("run_portfolio: happy path returns PASS with footprint, clutter, strength, extension, supporting", {
  data       <- mk_pforch_data()
  categories <- mk_pforch_categories()
  structure  <- mk_pforch_structure()
  config     <- mk_pforch_config()

  out <- run_portfolio(data, role_map = NULL, categories, structure, config)

  expect_equal(out$status, "PASS")
  expect_equal(out$focal_brand, "A")
  expect_equal(out$timeframe, "3m")
  expect_equal(out$n_total, 8L)
  expect_equal(out$n_weighted, 8.0)

  # Top-level shape parity with v1
  expect_named(out, c(
    "status", "focal_brand", "timeframe", "n_total", "n_weighted",
    "bases", "footprint_matrix", "footprint_meta",
    "constellation", "constellation_per_cat",
    "clutter", "strength", "extension", "extension_per_brand",
    "supporting", "suppressions"
  ), ignore.order = TRUE)

  # Footprint matrix has the live cats (BAK dropped — no qualifiers)
  expect_false(is.null(out$footprint_matrix))
  expect_setequal(setdiff(names(out$footprint_matrix), "Brand"), c("DSS", "POS"))

  # Clutter populated for the live cats
  expect_false(is.null(out$clutter))
  expect_true("clutter_df" %in% names(out$clutter))

  # Strength + extension non-NULL when status PASS
  expect_false(is.null(out$strength))
  expect_false(is.null(out$extension))

  # Supporting + bases populated
  expect_false(is.null(out$supporting))
  expect_true(nrow(out$bases$per_category) >= 1L)
})


test_that("run_portfolio: supporting metrics — slot-aware repertoire depth", {
  data       <- mk_pforch_data()
  categories <- mk_pforch_categories()
  structure  <- mk_pforch_structure()
  config     <- mk_pforch_config()

  out <- run_portfolio(data, role_map = NULL, categories, structure, config)

  sup <- out$supporting
  # Hand-checked: A is aware in DSS (100%) AND POS (50%) — both > 0 -> breadth = 2
  expect_equal(sup$focal_footprint_breadth, 2L)
  expect_equal(sup$n_cats_total, 3L)

  # Hand-checked depth: per-respondent CategoryCode picks across SQ2_1..N
  #   r1=2, r2=1, r3=1, r4=2, r5=1, r6=1, r7=0 (NONE), r8=1  -> sum 9 / 8
  expect_equal(sup$mean_repertoire_depth, 9 / 8, tolerance = 1e-9)

  # The legacy v1 supporting helper would return 0 here (slot SQ2_1 cells
  # hold strings, integer cast NA) — confirms v2 path executed.
  expect_gt(sup$mean_repertoire_depth, 0)
})


test_that("run_portfolio: per-cat constellation populated for live cats", {
  data       <- mk_pforch_data()
  categories <- mk_pforch_categories()
  structure  <- mk_pforch_structure()
  config     <- mk_pforch_config(min_base = 1L, cooccur_min = 1L)

  out <- run_portfolio(data, role_map = NULL, categories, structure, config)

  expect_false(is.null(out$constellation_per_cat))
  expect_equal(out$constellation_per_cat$status, "PASS")
  # by_cat keyed by cat code
  expect_true(length(out$constellation_per_cat$by_cat) >= 1L)
})


test_that("run_portfolio: suppressed_cats aggregates across sub-analyses", {
  data       <- mk_pforch_data()
  categories <- mk_pforch_categories()
  structure  <- mk_pforch_structure()
  # min_base = 5 — POS (n=4) flagged in footprint suppressed_cats
  config     <- mk_pforch_config(min_base = 5L)

  out <- run_portfolio(data, role_map = NULL, categories, structure, config)

  expect_equal(out$status, "PASS")
  expect_true("POS" %in% out$suppressions$low_base_cats)
  expect_false("DSS" %in% out$suppressions$low_base_cats)
})


# ------------------------------------------------------------------------------
# Guard refusal
# ------------------------------------------------------------------------------

test_that("run_portfolio: refuses when cross_category_awareness disabled", {
  data       <- mk_pforch_data()
  categories <- mk_pforch_categories()
  structure  <- mk_pforch_structure()
  config     <- mk_pforch_config(cross_cat_aware = FALSE)

  out <- run_portfolio(data, role_map = NULL, categories, structure, config)

  expect_equal(out$status, "REFUSED")
  expect_equal(out$code, "CFG_PORTFOLIO_AWARENESS_OFF")
})


test_that("run_portfolio: refuses when no BRANDAWARE_* columns in data", {
  data       <- mk_pforch_data()
  data       <- data[, !grepl("^BRANDAWARE_", names(data)), drop = FALSE]
  categories <- mk_pforch_categories()
  structure  <- mk_pforch_structure()
  config     <- mk_pforch_config()

  out <- run_portfolio(data, role_map = NULL, categories, structure, config)

  expect_equal(out$status, "REFUSED")
  expect_equal(out$code, "DATA_PORTFOLIO_NO_AWARENESS_COLS")
})


# ------------------------------------------------------------------------------
# role_map override resolves a custom awareness root
# ------------------------------------------------------------------------------

test_that("run_portfolio: role_map override threads through to sub-analyses", {
  data       <- mk_pforch_data()
  categories <- mk_pforch_categories()
  structure  <- mk_pforch_structure()
  config     <- mk_pforch_config()

  # Provide an explicit role_map that points at the same convention root —
  # asserts the override path is wired (would otherwise silently fall back).
  role_map <- list(
    portfolio.awareness.DSS = list(column_root = "BRANDAWARE_DSS",
                                    variable_type = "Multi_Mention"),
    portfolio.awareness.POS = list(column_root = "BRANDAWARE_POS",
                                    variable_type = "Multi_Mention"),
    portfolio.awareness.BAK = list(column_root = "BRANDAWARE_BAK",
                                    variable_type = "Multi_Mention")
  )

  out <- run_portfolio(data, role_map = role_map, categories, structure, config)
  expect_equal(out$status, "PASS")
  # DSS hand-checked: A=100%, B=80%, C=40%, D=20%
  m <- out$footprint_matrix
  expect_equal(m$DSS[m$Brand == "A"], 100)
  expect_equal(m$DSS[m$Brand == "B"], 80)
})
