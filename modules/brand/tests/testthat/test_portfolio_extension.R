# ==============================================================================
# BRAND MODULE TESTS - PERMISSION-TO-EXTEND TABLE (§4.5)
# ==============================================================================
# Known-answer tests for compute_extension_table() and helpers:
#   .detect_home_category(), .ext_sig_test().
#
# Synthetic scenario:
#   6 respondents, 2 categories: HOME and EXT.
#   focal brand IPK.
#   HOME: SQ2_HOME = c(1,1,1,0,0,0) → 3 buyers
#   EXT:  SQ2_EXT  = c(0,0,0,1,1,1) → 3 buyers
#   BRANDAWARE_HOME_IPK = c(1,1,1,0,0,0) → all HOME buyers aware → 100%
#   BRANDAWARE_EXT_IPK  = c(0,0,0,1,1,0) → 2 of 3 EXT buyers aware → 66.67%
#   Baseline "all": sum(0+0+0+1+1+0)/6 * 100 = 2/6 = 33.33%
#   lift = 0.6667 / 0.3333 = 2.0
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
            "09a_portfolio_footprint.R", "09e_portfolio_extension.R", "00_main.R")) {
  fpath <- file.path(brand_r_dir, f)
  if (file.exists(fpath)) tryCatch(source(fpath, local = FALSE), error = function(e) NULL)
}


# ---------------------------------------------------------------------------
# Minimal synthetic helpers
#
# .detect_category_code() uses a 50% column-match threshold (floor(n*0.5)).
# To disambiguate two categories that share only IPK, each must have 4 brands
# so threshold = floor(4*0.5) = 2. HOME has H1/H2/H3 unique; EXT has E1/E2/E3.
# Only 1 shared brand (IPK) → n_found=1 < threshold=2 → no cross-match.
# ---------------------------------------------------------------------------

.ex_data <- function() {
  data.frame(
    SQ1_HOME              = c(1L, 1L, 1L, 0L, 0L, 0L),
    SQ2_HOME              = c(1L, 1L, 1L, 0L, 0L, 0L),
    SQ1_EXT               = c(0L, 0L, 0L, 1L, 1L, 1L),
    SQ2_EXT               = c(0L, 0L, 0L, 1L, 1L, 1L),
    # HOME brands (IPK + 3 unique)
    BRANDAWARE_HOME_IPK   = c(1L, 1L, 1L, 0L, 0L, 0L),
    BRANDAWARE_HOME_H1    = c(1L, 0L, 0L, 0L, 0L, 0L),
    BRANDAWARE_HOME_H2    = c(0L, 1L, 0L, 0L, 0L, 0L),
    BRANDAWARE_HOME_H3    = c(0L, 0L, 1L, 0L, 0L, 0L),
    # EXT brands (IPK + 3 unique)
    BRANDAWARE_EXT_IPK    = c(0L, 0L, 0L, 1L, 1L, 0L),
    BRANDAWARE_EXT_E1     = c(0L, 0L, 0L, 1L, 0L, 0L),
    BRANDAWARE_EXT_E2     = c(0L, 0L, 0L, 0L, 1L, 0L),
    BRANDAWARE_EXT_E3     = c(0L, 0L, 0L, 0L, 0L, 1L),
    stringsAsFactors      = FALSE
  )
}

.ex_structure <- function() {
  list(
    brands = rbind(
      data.frame(Category = "Home Cat",
                 BrandCode = c("IPK", "H1", "H2", "H3"),
                 DisplayOrder = 1:4, stringsAsFactors = FALSE),
      data.frame(Category = "Ext Cat",
                 BrandCode = c("IPK", "E1", "E2", "E3"),
                 DisplayOrder = 1:4, stringsAsFactors = FALSE)
    ),
    questionmap = data.frame(
      Role       = c("funnel.awareness.HOME", "funnel.awareness.EXT"),
      ClientCode = c("BRANDAWARE_HOME",       "BRANDAWARE_EXT"),
      stringsAsFactors = FALSE
    )
  )
}

.ex_categories <- function() {
  data.frame(Category = c("Home Cat", "Ext Cat"), stringsAsFactors = FALSE)
}

.ex_config <- function(baseline = "all", min_base = 2L,
                        focal_home_cat = "") {
  list(
    focal_brand                    = "IPK",
    portfolio_timeframe            = "3m",
    portfolio_min_base             = min_base,
    portfolio_extension_baseline   = baseline,
    focal_home_category            = focal_home_cat
  )
}

.ex_footprint <- function() {
  # HOME: IPK aware 100%; EXT: IPK aware 66.67% → HOME is home cat
  list(
    matrix_df = data.frame(
      Brand = c("IPK", "H1", "H2", "H3", "E1", "E2", "E3"),
      HOME  = c(100,  33, 33, 33, NA, NA, NA),
      EXT   = c(66.67, NA, NA, NA, 33, 33, 33),
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    bases_df = data.frame(
      cat         = c("HOME", "EXT"),
      n_buyers_uw = c(3L, 3L),
      n_buyers_w  = c(3.0, 3.0),
      stringsAsFactors = FALSE
    )
  )
}


# ===========================================================================
# .detect_home_category() — unit tests
# ===========================================================================

test_that("auto-detect: HOME has highest focal awareness → returns HOME", {
  fp <- .ex_footprint()
  home <- .detect_home_category(fp$matrix_df, fp$bases_df, "IPK", 6L)
  expect_equal(home, "HOME")
})

test_that("auto-detect: returns empty string when focal brand absent from matrix", {
  fp <- .ex_footprint()
  home <- .detect_home_category(fp$matrix_df, fp$bases_df, "ABSENT", 6L)
  expect_equal(home, "")
})

test_that("auto-detect: tie broken by highest cat_penetration", {
  fp       <- .ex_footprint()
  ipk_idx  <- which(fp$matrix_df$Brand == "IPK")
  fp$matrix_df$HOME[ipk_idx] <- 66.67  # tie HOME==EXT
  fp$bases_df$n_buyers_uw[fp$bases_df$cat == "HOME"] <- 4L  # HOME bigger
  home <- .detect_home_category(fp$matrix_df, fp$bases_df, "IPK", 6L)
  expect_equal(home, "HOME")
})

test_that("empty footprint matrix returns empty string", {
  home <- .detect_home_category(data.frame(), NULL, "IPK", 6L)
  expect_equal(home, "")
})


# ===========================================================================
# .ext_sig_test() — unit tests
# ===========================================================================

test_that("z-test: p_value is numeric in [0,1] and test_used is z_test", {
  result <- .ext_sig_test(50L, 100L, 30L, 100L)
  expect_true(result$p_value >= 0 && result$p_value <= 1)
  expect_equal(result$test_used, "z_test")
})

test_that("Fisher fallback: triggered when expected cell < 5", {
  # Very small counts → expected cells < 5
  result <- .ext_sig_test(2L, 4L, 1L, 4L)
  expect_equal(result$test_used, "fisher")
  expect_true(!is.na(result$p_value))
})

test_that("equal proportions: p_value ≈ 1", {
  result <- .ext_sig_test(50L, 100L, 50L, 100L)
  expect_true(result$p_value > 0.9)
})

test_that("n1 == 0 returns NA p_value and test_used = none", {
  result <- .ext_sig_test(0L, 0L, 30L, 100L)
  expect_true(is.na(result$p_value))
  expect_equal(result$test_used, "none")
})


# ===========================================================================
# compute_extension_table() — known-answer tests
# ===========================================================================

test_that("returns PASS with extension_df data frame", {
  result <- compute_extension_table(
    .ex_data(), .ex_categories(), .ex_structure(), .ex_config(),
    footprint_result = .ex_footprint()
  )
  expect_equal(result$status, "PASS")
  expect_true(is.data.frame(result$extension_df))
})

test_that("home cat detected as HOME (highest focal awareness = 100%)", {
  result <- compute_extension_table(
    .ex_data(), .ex_categories(), .ex_structure(), .ex_config(),
    footprint_result = .ex_footprint()
  )
  expect_equal(result$home_cat, "HOME")
  expect_equal(result$home_cat_source, "auto")
})

test_that("focal_home_category config override is respected", {
  cfg <- .ex_config(focal_home_cat = "EXT")
  result <- compute_extension_table(
    .ex_data(), .ex_categories(), .ex_structure(), cfg,
    footprint_result = .ex_footprint()
  )
  expect_equal(result$home_cat, "EXT")
  expect_equal(result$home_cat_source, "config")
})

test_that("EXT focal_aware_pct: 2 of 3 EXT buyers aware = 66.667%", {
  result <- compute_extension_table(
    .ex_data(), .ex_categories(), .ex_structure(), .ex_config(),
    footprint_result = .ex_footprint()
  )
  ext_row <- result$extension_df[result$extension_df$cat == "EXT" &
                                   !result$extension_df$is_home, ]
  expect_equal(ext_row$focal_aware_pct, 2 / 3 * 100, tolerance = 1e-3)
})

test_that("lift ≈ 2.0 (p_c=0.667 / baseline=0.333)", {
  # Baseline "all": sum(BRANDAWARE_EXT_IPK) / 6 = 2/6 = 0.333
  # p_c among EXT buyers: 2/3 = 0.667
  # lift = 0.667 / 0.333 = 2.0
  result <- compute_extension_table(
    .ex_data(), .ex_categories(), .ex_structure(), .ex_config(),
    footprint_result = .ex_footprint()
  )
  ext_row <- result$extension_df[result$extension_df$cat == "EXT" &
                                   !result$extension_df$is_home, ]
  expect_equal(ext_row$lift, 2.0, tolerance = 1e-3)
})

test_that("extension_df has required columns", {
  result <- compute_extension_table(
    .ex_data(), .ex_categories(), .ex_structure(), .ex_config(),
    footprint_result = .ex_footprint()
  )
  required <- c("cat", "is_home", "n_buyers_uw", "focal_aware_pct",
                "lift", "p_value", "p_adj", "test_used", "low_base_flag")
  expect_true(all(required %in% names(result$extension_df)))
})

test_that("REFUSED when focal_brand is empty", {
  cfg <- .ex_config()
  cfg$focal_brand <- ""
  result <- compute_extension_table(
    .ex_data(), .ex_categories(), .ex_structure(), cfg
  )
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CALC_EXTENSION_NO_FOCAL_AWARENESS")
})

test_that("REFUSED when no BRANDAWARE_*_focal columns exist", {
  dat <- data.frame(SQ2_TST = c(1L, 0L), stringsAsFactors = FALSE)
  cfg <- .ex_config()
  result <- compute_extension_table(dat, .ex_categories(), .ex_structure(), cfg)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CALC_EXTENSION_NO_FOCAL_AWARENESS")
})

test_that("p_adj column is present and all values in [0,1] or NA", {
  result <- compute_extension_table(
    .ex_data(), .ex_categories(), .ex_structure(), .ex_config(),
    footprint_result = .ex_footprint()
  )
  adj <- result$extension_df$p_adj
  valid <- adj[!is.na(adj)]
  expect_true(all(valid >= 0 & valid <= 1))
})

test_that("home row appears in output with is_home = TRUE", {
  result <- compute_extension_table(
    .ex_data(), .ex_categories(), .ex_structure(), .ex_config(),
    footprint_result = .ex_footprint()
  )
  home_rows <- result$extension_df[result$extension_df$is_home, ]
  expect_equal(nrow(home_rows), 1L)
  expect_equal(home_rows$cat, "HOME")
})
