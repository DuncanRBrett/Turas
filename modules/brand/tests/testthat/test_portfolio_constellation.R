# ==============================================================================
# BRAND MODULE TESTS - COMPETITIVE CONSTELLATION (§4.2)
# ==============================================================================
# Known-answer tests for compute_constellation() and helpers:
#   .fr_layout_r(), .build_aware_any_mat(), compute_constellation().
#
# Synthetic scenario (4 respondents, 1 category "Test Cat", code "TST"):
#   BRANDAWARE_TST_AA = c(1,1,1,0)  → n_aware_w = 3 (unweighted)
#   BRANDAWARE_TST_BB = c(1,1,0,0)  → n_aware_w = 2
#   BRANDAWARE_TST_CC = c(0,0,1,1)  → n_aware_w = 2
#
#   Jaccard(AA,BB): both=c(1,1,0,0), either=c(1,1,1,0) → 2/3 ≈ 0.6667
#   Jaccard(AA,CC): both=c(0,0,1,0), either=c(1,1,1,1) → 1/4 = 0.25
#   Jaccard(BB,CC): both=c(0,0,0,0)                    → cooccur=0, filtered
#
#   Weighted (w=c(2,1,1,2)):
#   Jaccard(AA,BB): w_both=3, w_either=4 → 0.75
#   Jaccard(AA,CC): w_both=1, w_either=6 → 1/6 ≈ 0.1667
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
            "09b_portfolio_constellation.R", "00_main.R")) {
  fpath <- file.path(brand_r_dir, f)
  if (file.exists(fpath)) tryCatch(source(fpath, local = FALSE), error = function(e) NULL)
}


# ---------------------------------------------------------------------------
# Synthetic fixture helpers
# ---------------------------------------------------------------------------

.cn_data <- function() {
  data.frame(
    SQ2_TST            = c(1L, 1L, 1L, 1L),
    BRANDAWARE_TST_AA  = c(1L, 1L, 1L, 0L),
    BRANDAWARE_TST_BB  = c(1L, 1L, 0L, 0L),
    BRANDAWARE_TST_CC  = c(0L, 0L, 1L, 1L),
    stringsAsFactors   = FALSE
  )
}

.cn_data_sparse <- function() {
  # Only 2 brands have any awareness — should trigger CALC_CONSTELLATION_TOO_SPARSE
  data.frame(
    SQ2_TST            = c(1L, 1L, 1L, 1L),
    BRANDAWARE_TST_AA  = c(1L, 1L, 1L, 0L),
    BRANDAWARE_TST_BB  = c(1L, 0L, 0L, 0L),
    BRANDAWARE_TST_CC  = c(0L, 0L, 0L, 0L),
    stringsAsFactors   = FALSE
  )
}

.cn_structure <- function() {
  list(
    brands = data.frame(
      Category     = rep("Test Cat", 3),
      BrandCode    = c("AA", "BB", "CC"),
      DisplayOrder = 1:3,
      stringsAsFactors = FALSE
    ),
    questionmap = data.frame(
      Role       = "funnel.awareness.TST",
      ClientCode = "BRANDAWARE_TST",
      stringsAsFactors = FALSE
    )
  )
}

.cn_categories <- function() {
  data.frame(Category = "Test Cat", stringsAsFactors = FALSE)
}

.cn_config <- function(focal = "AA", min_base = 2L, cooccur_min = 1L) {
  list(
    focal_brand                 = focal,
    portfolio_timeframe         = "3m",
    portfolio_min_base          = min_base,
    portfolio_cooccur_min_pairs = cooccur_min,
    portfolio_edge_top_n        = 40L
  )
}


# ==============================================================================
# .fr_layout_r() — pure-R Fruchterman-Reingold
# ==============================================================================

test_that(".fr_layout_r returns n-by-2 numeric matrix", {
  skip_if_not(exists(".fr_layout_r"), ".fr_layout_r not found")
  pos <- .fr_layout_r(n = 4L, adj = matrix(0.0, 4, 4), n_iter = 5L)
  expect_true(is.matrix(pos))
  expect_equal(dim(pos), c(4L, 2L))
  expect_true(is.numeric(pos))
})

test_that(".fr_layout_r is deterministic with same seed", {
  skip_if_not(exists(".fr_layout_r"), ".fr_layout_r not found")
  adj <- matrix(c(0, 0.5, 0.5, 0,
                  0.5, 0,  0.2, 0,
                  0.5, 0.2, 0,  0,
                  0,   0,   0,  0), 4, 4)
  p1 <- .fr_layout_r(n = 4L, adj = adj, n_iter = 20L, seed = 42L)
  p2 <- .fr_layout_r(n = 4L, adj = adj, n_iter = 20L, seed = 42L)
  expect_equal(p1, p2)
})

test_that(".fr_layout_r produces different positions with different seeds", {
  skip_if_not(exists(".fr_layout_r"), ".fr_layout_r not found")
  adj <- matrix(0.5, 3, 3); diag(adj) <- 0
  p1 <- .fr_layout_r(n = 3L, adj = adj, n_iter = 10L, seed = 1L)
  p2 <- .fr_layout_r(n = 3L, adj = adj, n_iter = 10L, seed = 99L)
  expect_false(identical(p1, p2))
})

test_that(".fr_layout_r handles n=3 (minimum for constellation)", {
  skip_if_not(exists(".fr_layout_r"), ".fr_layout_r not found")
  pos <- .fr_layout_r(n = 3L, adj = matrix(0.0, 3, 3), n_iter = 5L)
  expect_equal(nrow(pos), 3L)
  expect_equal(ncol(pos), 2L)
  expect_false(anyNA(pos))
})


# ==============================================================================
# .build_aware_any_mat() — any-awareness matrix
# ==============================================================================

test_that(".build_aware_any_mat returns matrix with correct dimensions", {
  skip_if_not(exists(".build_aware_any_mat"), ".build_aware_any_mat not found")
  d <- .cn_data()
  mat <- .build_aware_any_mat(d, c("AA", "BB", "CC"))
  expect_true(is.matrix(mat))
  expect_equal(dim(mat), c(4L, 3L))
  expect_equal(colnames(mat), c("AA", "BB", "CC"))
})

test_that(".build_aware_any_mat known-answer: single category per brand", {
  skip_if_not(exists(".build_aware_any_mat"), ".build_aware_any_mat not found")
  d <- .cn_data()
  mat <- .build_aware_any_mat(d, c("AA", "BB", "CC"))
  expect_equal(mat[, "AA"], c(1L, 1L, 1L, 0L))
  expect_equal(mat[, "BB"], c(1L, 1L, 0L, 0L))
  expect_equal(mat[, "CC"], c(0L, 0L, 1L, 1L))
})

test_that(".build_aware_any_mat collapses multiple category columns to any-aware", {
  skip_if_not(exists(".build_aware_any_mat"), ".build_aware_any_mat not found")
  d <- data.frame(
    BRANDAWARE_CAT1_AA = c(1L, 0L, 0L),
    BRANDAWARE_CAT2_AA = c(0L, 1L, 0L),
    stringsAsFactors = FALSE
  )
  mat <- .build_aware_any_mat(d, "AA")
  # Respondent 1: aware in CAT1; respondent 2: aware in CAT2; respondent 3: neither
  expect_equal(mat[, "AA"], c(1L, 1L, 0L))
})

test_that(".build_aware_any_mat returns zero column for absent brand", {
  skip_if_not(exists(".build_aware_any_mat"), ".build_aware_any_mat not found")
  d <- .cn_data()
  mat <- .build_aware_any_mat(d, c("AA", "ZZ"))
  expect_equal(mat[, "ZZ"], c(0L, 0L, 0L, 0L))
})


# ==============================================================================
# compute_constellation() — TRS refusals
# ==============================================================================

test_that("compute_constellation returns REFUSED when < 3 brands have awareness", {
  result <- compute_constellation(
    .cn_data_sparse(), .cn_categories(), .cn_structure(), .cn_config()
  )
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CALC_CONSTELLATION_TOO_SPARSE")
})

test_that("compute_constellation returns REFUSED when data is empty", {
  empty <- .cn_data()[0, ]
  result <- compute_constellation(empty, .cn_categories(), .cn_structure(), .cn_config())
  expect_equal(result$status, "REFUSED")
})

test_that("compute_constellation returns REFUSED when all categories below min_base", {
  # min_base=10 but only 4 respondents → TST suppressed → no brands → TOO_SPARSE
  cfg <- .cn_config(min_base = 10L)
  result <- compute_constellation(.cn_data(), .cn_categories(), .cn_structure(), cfg)
  expect_equal(result$status, "REFUSED")
})


# ==============================================================================
# compute_constellation() — happy path PASS
# ==============================================================================

test_that("compute_constellation returns PASS with 3 brands", {
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config()
  )
  expect_equal(result$status, "PASS")
})

test_that("compute_constellation nodes data frame has expected columns", {
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config()
  )
  expect_true(all(c("brand", "n_aware_w", "is_focal") %in% names(result$nodes)))
})

test_that("compute_constellation nodes known-answer: n_aware_w (unweighted)", {
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config()
  )
  nodes <- result$nodes
  aa_row <- nodes[nodes$brand == "AA", ]
  bb_row <- nodes[nodes$brand == "BB", ]
  cc_row <- nodes[nodes$brand == "CC", ]
  expect_equal(nrow(aa_row), 1L)
  expect_equal(aa_row$n_aware_w, 3.0, tolerance = 1e-6)
  expect_equal(bb_row$n_aware_w, 2.0, tolerance = 1e-6)
  expect_equal(cc_row$n_aware_w, 2.0, tolerance = 1e-6)
})

test_that("compute_constellation marks focal brand correctly", {
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config(focal = "BB")
  )
  nodes <- result$nodes
  expect_true(nodes$is_focal[nodes$brand == "BB"])
  expect_false(nodes$is_focal[nodes$brand == "AA"])
  expect_false(nodes$is_focal[nodes$brand == "CC"])
})

test_that("compute_constellation edges known-answer: Jaccard(AA,BB) = 2/3", {
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config()
  )
  edges <- result$edges
  ab <- edges[(edges$b1 == "AA" & edges$b2 == "BB") |
              (edges$b1 == "BB" & edges$b2 == "AA"), ]
  expect_equal(nrow(ab), 1L)
  expect_equal(ab$jaccard, 2 / 3, tolerance = 1e-6)
  expect_equal(ab$cooccur_n, 2L)
})

test_that("compute_constellation edges known-answer: Jaccard(AA,CC) = 0.25", {
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config()
  )
  edges <- result$edges
  ac <- edges[(edges$b1 == "AA" & edges$b2 == "CC") |
              (edges$b1 == "CC" & edges$b2 == "AA"), ]
  expect_equal(nrow(ac), 1L)
  expect_equal(ac$jaccard, 0.25, tolerance = 1e-6)
  expect_equal(ac$cooccur_n, 1L)
})

test_that("compute_constellation filters BB-CC edge (cooccur = 0 < cooccur_min=1)", {
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config()
  )
  edges <- result$edges
  bc <- edges[(edges$b1 == "BB" & edges$b2 == "CC") |
              (edges$b1 == "CC" & edges$b2 == "BB"), ]
  expect_equal(nrow(bc), 0L)
})

test_that("compute_constellation edges sorted descending by Jaccard", {
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config()
  )
  j <- result$edges$jaccard
  expect_true(all(diff(j) <= 0))
})

test_that("compute_constellation layout has one row per present brand", {
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config()
  )
  expect_equal(nrow(result$layout), 3L)
  expect_true(all(c("brand", "x", "y") %in% names(result$layout)))
})

test_that("compute_constellation layout contains no NAs", {
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config()
  )
  expect_false(anyNA(result$layout$x))
  expect_false(anyNA(result$layout$y))
})

test_that("compute_constellation weighted Jaccard(AA,BB) = 0.75", {
  w <- c(2, 1, 1, 2)
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config(),
    weights = w
  )
  edges <- result$edges
  ab <- edges[(edges$b1 == "AA" & edges$b2 == "BB") |
              (edges$b1 == "BB" & edges$b2 == "AA"), ]
  expect_equal(nrow(ab), 1L)
  # w_both = 2+1=3, w_either = 2+1+1=4 → J=0.75
  expect_equal(ab$jaccard, 0.75, tolerance = 1e-6)
})

test_that("compute_constellation weighted n_aware_w correct", {
  w <- c(2, 1, 1, 2)
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config(),
    weights = w
  )
  nodes <- result$nodes
  # AA: sum(c(2,1,1,2)*c(1,1,1,0)) = 4; BB: sum(c(2,1,1,2)*c(1,1,0,0)) = 3
  aa_row <- nodes[nodes$brand == "AA", ]
  bb_row <- nodes[nodes$brand == "BB", ]
  expect_equal(aa_row$n_aware_w, 4.0, tolerance = 1e-6)
  expect_equal(bb_row$n_aware_w, 3.0, tolerance = 1e-6)
})

test_that("compute_constellation returns layout_engine field", {
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), .cn_config()
  )
  expect_true(is.character(result$layout_engine))
  expect_true(nzchar(result$layout_engine))
})

test_that("compute_constellation respects cooccur_min filter", {
  # cooccur_min=2 filters AA-CC (cooccur=1 < 2)
  cfg <- .cn_config(cooccur_min = 2L)
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), cfg
  )
  edges <- result$edges
  ac <- edges[(edges$b1 == "AA" & edges$b2 == "CC") |
              (edges$b1 == "CC" & edges$b2 == "AA"), ]
  expect_equal(nrow(ac), 0L)
})

test_that("compute_constellation respects edge_top_n limit", {
  # Only 2 edges pass (AA-BB, AA-CC); edge_top_n=1 should keep only the top one
  cfg <- .cn_config(cooccur_min = 1L)
  cfg$portfolio_edge_top_n <- 1L
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), cfg
  )
  expect_equal(nrow(result$edges), 1L)
  expect_equal(result$edges$jaccard[1], 2 / 3, tolerance = 1e-6)
})

test_that("compute_constellation tracks suppressed low-base categories", {
  # min_base=5 → 4 qualifiers < 5 → TST category suppressed → no brands → REFUSED
  cfg <- .cn_config(min_base = 5L)
  result <- compute_constellation(
    .cn_data(), .cn_categories(), .cn_structure(), cfg
  )
  expect_equal(result$status, "REFUSED")
})


# ==============================================================================
# Fixture-based tests (skip if fixture not available)
# ==============================================================================

local({
  fixture_path <- file.path(
    TURAS_ROOT, "modules", "brand", "tests", "fixtures",
    "synthetic_ipk_9cat_wave1.rds"
  )
  if (!file.exists(fixture_path)) return()

  dat      <- readRDS(fixture_path)
  cfg_path <- file.path(TURAS_ROOT, "modules", "brand", "tests", "fixtures",
                        "brand_config.yml")
  struct   <- tryCatch(load_brand_survey_structure(dat), error = function(e) NULL)
  cfg      <- tryCatch(
    if (file.exists(cfg_path)) load_brand_config(cfg_path) else
      list(focal_brand = "IPK", portfolio_timeframe = "3m",
           portfolio_min_base = 30L, portfolio_cooccur_min_pairs = 5L,
           portfolio_edge_top_n = 40L),
    error = function(e)
      list(focal_brand = "IPK", portfolio_timeframe = "3m",
           portfolio_min_base = 30L, portfolio_cooccur_min_pairs = 5L,
           portfolio_edge_top_n = 40L)
  )
  if (is.null(struct)) return()
  cats <- if (!is.null(struct$categories)) struct$categories else
    data.frame(Category = unique(struct$brands$Category), stringsAsFactors = FALSE)

  test_that("compute_constellation PASS on 1200-row fixture", {
    result <- compute_constellation(dat, cats, struct, cfg)
    expect_true(result$status %in% c("PASS", "REFUSED"))
  })

  test_that("constellation fixture nodes data frame is non-empty", {
    result <- compute_constellation(dat, cats, struct, cfg)
    if (result$status == "PASS") {
      expect_true(nrow(result$nodes) >= CONSTELLATION_MIN_BRANDS)
    }
  })

  test_that("constellation fixture edges are within [0,1] Jaccard range", {
    result <- compute_constellation(dat, cats, struct, cfg)
    if (result$status == "PASS" && nrow(result$edges) > 0) {
      expect_true(all(result$edges$jaccard >= 0 & result$edges$jaccard <= 1))
    }
  })

  test_that("constellation fixture layout has no NA positions", {
    result <- compute_constellation(dat, cats, struct, cfg)
    if (result$status == "PASS") {
      expect_false(anyNA(result$layout$x))
      expect_false(anyNA(result$layout$y))
    }
  })

  test_that("constellation fixture focal brand marked in nodes", {
    result <- compute_constellation(dat, cats, struct, cfg)
    if (result$status == "PASS") {
      focal_node <- result$nodes[result$nodes$brand == cfg$focal_brand, ]
      if (nrow(focal_node) > 0) {
        expect_true(focal_node$is_focal[1])
      }
    }
  })
})
