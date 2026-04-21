# ==============================================================================
# BRAND MODULE TESTS - PORTFOLIO OUTPUT (§10) + SUPPORTING METRICS (§5)
# ==============================================================================
# Tests for 09g_portfolio_output.R (write_portfolio_sheets, write_portfolio_csv,
# long-format helpers) and the .compute_supporting_metrics() helper inside
# 09_portfolio.R (via the run_portfolio() return value).
#
# Known-answer scenario for supporting metrics:
#   4 respondents, 1 category "Test Cat" (TST), focal = AA
#   SQ2_TST = c(1,1,1,1)
#   BRANDAWARE_TST_AA = c(1,1,1,0) → AA aware = 3 of 4 buyers
#   awareness_set_size_mean = 3/4 × 1 + 1/4 × 0 = 0.75  (... actually
#     it's mean awareness set size per buyer, not per respondent — see clutter)
#   Mean repertoire depth: rowSums(SQ2_TST=c(1,1,1,1)) = all 1 → mean = 1.0
#   Focal footprint breadth: AA has >0 awareness in 1 of 1 cats → breadth = 1
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
            "09a_portfolio_footprint.R", "09b_portfolio_constellation.R",
            "09c_portfolio_clutter.R", "09d_portfolio_strength.R",
            "09e_portfolio_extension.R", "09f_portfolio_panel_data.R",
            "09g_portfolio_output.R", "00_main.R")) {
  fpath <- file.path(brand_r_dir, f)
  if (file.exists(fpath)) tryCatch(source(fpath, local = FALSE), error = function(e) NULL)
}


# ---------------------------------------------------------------------------
# Synthetic portfolio result for output tests
# ---------------------------------------------------------------------------

.make_portfolio_result <- function() {
  list(
    status      = "PASS",
    focal_brand = "AA",
    timeframe   = "3m",
    n_total     = 4L,
    n_weighted  = 4.0,
    bases       = list(
      per_category = data.frame(cat = "TST", n_buyers_uw = 4L,
                                n_buyers_w = 4.0, stringsAsFactors = FALSE)
    ),
    footprint_matrix = data.frame(
      Brand = c("AA", "BB"),
      TST   = c(75.0, 50.0),
      stringsAsFactors = FALSE, check.names = FALSE
    ),
    constellation = list(
      status  = "PASS",
      nodes   = data.frame(brand = c("AA", "BB", "CC"), n_aware_w = c(3, 2, 1),
                           is_focal = c(TRUE, FALSE, FALSE), stringsAsFactors = FALSE),
      edges   = data.frame(b1 = "AA", b2 = "BB", jaccard = 0.667, cooccur_n = 2L,
                           stringsAsFactors = FALSE),
      layout  = data.frame(brand = c("AA", "BB", "CC"), x = c(0,1,2),
                           y = c(0,1,0), stringsAsFactors = FALSE)
    ),
    clutter = list(
      clutter_df = data.frame(
        cat = "TST", awareness_set_size_mean = 1.5,
        focal_share_of_aware = 0.6, cat_penetration = 0.4,
        quadrant = "Dominant", stringsAsFactors = FALSE
      ),
      ref_x = 1.5, ref_y = 0.5, suppressed_cats = character(0)
    ),
    strength = list(
      status   = "PASS",
      per_brand = list(
        AA = data.frame(cat = "TST", cat_pen = 0.4, brand_aware = 0.75,
                        aware_n_w = 3.0, stringsAsFactors = FALSE)
      ),
      suppressed_cats = character(0)
    ),
    extension = list(
      status = "PASS",
      extension_df = data.frame(
        cat = "TST", is_home = TRUE, n_buyers_uw = 4L,
        focal_aware_pct = 75.0, lift = 1.0, p_value = NA_real_,
        p_adj = NA_real_, test_used = "none", low_base_flag = FALSE,
        stringsAsFactors = FALSE
      ),
      home_cat = "TST", home_cat_source = "auto",
      suppressed_cats = character(0)
    ),
    supporting = list(
      avg_awareness_set_size_focal_cat = 1.5,
      focal_footprint_breadth          = 1L,
      n_cats_total                     = 1L,
      focal_awareness_efficiency       = 1.5,
      mean_repertoire_depth            = 1.0,
      home_cat                         = "TST"
    ),
    suppressions = list(
      low_base_cats  = character(0),
      dropped_brands = character(0),
      dropped_edges  = 0L
    )
  )
}

.make_config <- function() {
  list(
    focal_brand                  = "AA",
    portfolio_timeframe          = "3m",
    portfolio_min_base           = 2L,
    portfolio_extension_baseline = "all",
    wave                         = 1L
  )
}


# ==============================================================================
# .pf_footprint_long() — long-format footprint helper
# ==============================================================================

test_that(".pf_footprint_long returns data frame with expected columns", {
  skip_if_not(exists(".pf_footprint_long"), ".pf_footprint_long not found")
  df <- .pf_footprint_long(.make_portfolio_result())
  expect_true(is.data.frame(df))
  expect_true(all(c("Brand", "Category", "Awareness_Pct") %in% names(df)))
})

test_that(".pf_footprint_long has correct row count (brands × cats)", {
  skip_if_not(exists(".pf_footprint_long"), ".pf_footprint_long not found")
  df <- .pf_footprint_long(.make_portfolio_result())
  # 2 brands × 1 category = 2 rows
  expect_equal(nrow(df), 2L)
})

test_that(".pf_footprint_long known-answer: AA TST = 75.0%", {
  skip_if_not(exists(".pf_footprint_long"), ".pf_footprint_long not found")
  df <- .pf_footprint_long(.make_portfolio_result())
  aa_row <- df[df$Brand == "AA" & df$Category == "TST", ]
  expect_equal(nrow(aa_row), 1L)
  expect_equal(aa_row$Awareness_Pct, 75.0, tolerance = 1e-6)
})

test_that(".pf_footprint_long computes N_Aware_W from Awareness_Pct × N_Buyers_W", {
  skip_if_not(exists(".pf_footprint_long"), ".pf_footprint_long not found")
  df <- .pf_footprint_long(.make_portfolio_result())
  aa_row <- df[df$Brand == "AA" & df$Category == "TST", ]
  # 75% of 4.0 buyers = 3.0
  expect_equal(aa_row$N_Aware_W, 3.0, tolerance = 1e-3)
})

test_that(".pf_footprint_long returns empty df when footprint_matrix is NULL", {
  skip_if_not(exists(".pf_footprint_long"), ".pf_footprint_long not found")
  r <- .make_portfolio_result()
  r$footprint_matrix <- NULL
  df <- .pf_footprint_long(r)
  expect_equal(nrow(df), 0L)
})


# ==============================================================================
# .pf_strength_long() — long-format strength helper
# ==============================================================================

test_that(".pf_strength_long returns data frame with expected columns", {
  skip_if_not(exists(".pf_strength_long"), ".pf_strength_long not found")
  df <- .pf_strength_long(.make_portfolio_result())
  expect_true(all(c("Brand", "Category", "Cat_Pen", "Brand_Aware_Pct") %in% names(df)))
})

test_that(".pf_strength_long known-answer: AA TST cat_pen=40%, brand_aware=75%", {
  skip_if_not(exists(".pf_strength_long"), ".pf_strength_long not found")
  df <- .pf_strength_long(.make_portfolio_result())
  aa_row <- df[df$Brand == "AA" & df$Category == "TST", ]
  expect_equal(nrow(aa_row), 1L)
  expect_equal(aa_row$Cat_Pen, 40.0, tolerance = 1e-6)
  expect_equal(aa_row$Brand_Aware_Pct, 75.0, tolerance = 1e-6)
})

test_that(".pf_strength_long returns empty df when strength is NULL", {
  skip_if_not(exists(".pf_strength_long"), ".pf_strength_long not found")
  r <- .make_portfolio_result()
  r$strength <- NULL
  df <- .pf_strength_long(r)
  expect_equal(nrow(df), 0L)
})


# ==============================================================================
# .pf_meta_df() — metadata sheet helper
# ==============================================================================

test_that(".pf_meta_df returns data frame with Key and Value columns", {
  skip_if_not(exists(".pf_meta_df"), ".pf_meta_df not found")
  df <- .pf_meta_df(.make_portfolio_result(), .make_config())
  expect_true(all(c("Key", "Value") %in% names(df)))
  expect_true(nrow(df) > 0)
})

test_that(".pf_meta_df contains focal_brand row", {
  skip_if_not(exists(".pf_meta_df"), ".pf_meta_df not found")
  df <- .pf_meta_df(.make_portfolio_result(), .make_config())
  focal_row <- df[df$Key == "focal_brand", ]
  expect_equal(nrow(focal_row), 1L)
  expect_equal(focal_row$Value, "AA")
})


# ==============================================================================
# write_portfolio_csv()
# ==============================================================================

test_that("write_portfolio_csv returns REFUSED when portfolio REFUSED", {
  refused <- list(status = "REFUSED", code = "DATA_TEST")
  result <- write_portfolio_csv(refused, tempdir())
  expect_equal(result$status, "REFUSED")
})

test_that("write_portfolio_csv creates portfolio subdirectory", {
  tmp <- tempdir()
  pf_dir <- file.path(tmp, "portfolio")
  if (dir.exists(pf_dir)) unlink(pf_dir, recursive = TRUE)
  result <- write_portfolio_csv(.make_portfolio_result(), tmp, .make_config())
  expect_true(dir.exists(pf_dir))
})

test_that("write_portfolio_csv writes expected CSV files", {
  tmp <- tempdir()
  result <- write_portfolio_csv(.make_portfolio_result(), tmp, .make_config())
  expect_equal(result$status, "PASS")
  # At minimum footprint, clutter, strength, extension, meta should be written
  pf_dir <- file.path(tmp, "portfolio")
  csv_files <- list.files(pf_dir, pattern = "\\.csv$")
  expect_true(length(csv_files) >= 4)
})

test_that("write_portfolio_csv footprint CSV has correct rows", {
  tmp <- tempdir()
  write_portfolio_csv(.make_portfolio_result(), tmp, .make_config())
  pf_fp <- file.path(tmp, "portfolio", "portfolio_footprint.csv")
  if (file.exists(pf_fp)) {
    df <- read.csv(pf_fp, stringsAsFactors = FALSE)
    expect_equal(nrow(df), 2L)  # 2 brands × 1 cat
  }
})


# ==============================================================================
# Supporting metrics via run_portfolio()
# ==============================================================================

# Minimal fixtures for run_portfolio integration
.rp_data <- function() {
  data.frame(
    SQ2_TST           = c(1L, 1L, 1L, 1L),
    BRANDAWARE_TST_AA = c(1L, 1L, 1L, 0L),
    BRANDAWARE_TST_BB = c(1L, 1L, 0L, 0L),
    BRANDAWARE_TST_CC = c(0L, 0L, 1L, 1L),
    stringsAsFactors  = FALSE
  )
}

.rp_structure <- function() {
  list(
    brands = data.frame(
      Category = rep("Test Cat", 3), BrandCode = c("AA", "BB", "CC"),
      DisplayOrder = 1:3, stringsAsFactors = FALSE
    ),
    questionmap = data.frame(
      Role = "funnel.awareness.TST", ClientCode = "BRANDAWARE_TST",
      stringsAsFactors = FALSE
    )
  )
}

.rp_categories <- function() {
  data.frame(Category = "Test Cat", stringsAsFactors = FALSE)
}

.rp_config <- function() {
  list(
    focal_brand                  = "AA",
    portfolio_timeframe          = "3m",
    portfolio_min_base           = 2L,
    portfolio_cooccur_min_pairs  = 1L,
    portfolio_edge_top_n         = 40L,
    portfolio_extension_baseline = "all",
    focal_home_category          = "",
    element_portfolio            = TRUE,
    cross_category_awareness     = TRUE
  )
}

test_that("run_portfolio populates supporting field", {
  result <- run_portfolio(.rp_data(), .rp_categories(), .rp_structure(), .rp_config())
  expect_equal(result$status, "PASS")
  expect_false(is.null(result$supporting))
})

test_that("supporting$focal_footprint_breadth = 1 (AA present in 1 cat)", {
  result <- run_portfolio(.rp_data(), .rp_categories(), .rp_structure(), .rp_config())
  expect_equal(result$supporting$focal_footprint_breadth, 1L)
})

test_that("supporting$mean_repertoire_depth = 1.0 (all 4 respondents buy 1 cat)", {
  result <- run_portfolio(.rp_data(), .rp_categories(), .rp_structure(), .rp_config())
  expect_equal(result$supporting$mean_repertoire_depth, 1.0, tolerance = 1e-6)
})

test_that("supporting$n_cats_total = 1", {
  result <- run_portfolio(.rp_data(), .rp_categories(), .rp_structure(), .rp_config())
  expect_equal(result$supporting$n_cats_total, 1L)
})

test_that("supporting$focal_awareness_efficiency > 0", {
  result <- run_portfolio(.rp_data(), .rp_categories(), .rp_structure(), .rp_config())
  eff <- result$supporting$focal_awareness_efficiency
  if (!is.na(eff)) expect_true(eff > 0)
})

test_that("supporting mean_repertoire_depth weighted correctly", {
  # weights: c(2,1,1,2) — still all buy 1 category → mean = 1.0
  w <- c(2, 1, 1, 2)
  result <- run_portfolio(.rp_data(), .rp_categories(), .rp_structure(), .rp_config(),
                          weights = w)
  expect_equal(result$supporting$mean_repertoire_depth, 1.0, tolerance = 1e-6)
})

test_that("supporting mean_repertoire_depth varies with multiple categories", {
  d <- data.frame(
    SQ2_TST           = c(1L, 1L, 0L, 0L),
    SQ2_EXT           = c(0L, 1L, 1L, 0L),
    BRANDAWARE_TST_AA = c(1L, 1L, 0L, 0L),
    BRANDAWARE_TST_BB = c(1L, 0L, 0L, 0L),
    BRANDAWARE_TST_CC = c(0L, 1L, 0L, 0L),
    BRANDAWARE_EXT_AA = c(0L, 1L, 1L, 0L),
    BRANDAWARE_EXT_BB = c(0L, 0L, 1L, 0L),
    BRANDAWARE_EXT_CC = c(0L, 0L, 0L, 1L),
    stringsAsFactors  = FALSE
  )
  struct <- list(
    brands = rbind(
      data.frame(Category = "Test Cat", BrandCode = c("AA", "BB", "CC"),
                 DisplayOrder = 1:3, stringsAsFactors = FALSE),
      data.frame(Category = "Ext Cat", BrandCode = c("AA", "BB", "CC"),
                 DisplayOrder = 1:3, stringsAsFactors = FALSE)
    ),
    questionmap = data.frame(
      Role = c("funnel.awareness.TST", "funnel.awareness.EXT"),
      ClientCode = c("BRANDAWARE_TST", "BRANDAWARE_EXT"),
      stringsAsFactors = FALSE
    )
  )
  cats   <- data.frame(Category = c("Test Cat", "Ext Cat"), stringsAsFactors = FALSE)
  config <- .rp_config()
  result <- run_portfolio(d, cats, struct, config)
  # R1: buys 1 cat; R2: buys 2 cats; R3: buys 1 cat; R4: buys 0 → mean = 4/4 = 1.0
  expect_equal(result$supporting$mean_repertoire_depth, 1.0, tolerance = 1e-6)
})
