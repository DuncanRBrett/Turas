# ==============================================================================
# Tests for .kk_layout_r — Kamada-Kawai constellation layout
# ==============================================================================
# Replaces Fruchterman-Reingold for the competitive constellation: KK targets
# pairwise Euclidean distance proportional to (1 - jaccard) so dense
# high-co-awareness clusters stay tight without collapsing on top of each
# other and disconnected outliers sit at distance-meaningful gaps.
# ==============================================================================
library(testthat)

.find_root_kk <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_kk()

source(file.path(ROOT, "modules", "brand", "R", "09b_portfolio_constellation.R"))


# ------------------------------------------------------------------------------
# Shape + determinism
# ------------------------------------------------------------------------------

test_that(".kk_layout_r returns n-by-2 numeric matrix", {
  pos <- .kk_layout_r(n = 4L, adj = matrix(0, 4, 4))
  expect_true(is.matrix(pos))
  expect_equal(dim(pos), c(4L, 2L))
  expect_true(is.numeric(pos))
})


test_that(".kk_layout_r is deterministic with the same seed", {
  set.seed(NULL)
  adj <- matrix(0.5, 4, 4); diag(adj) <- 0
  p1 <- .kk_layout_r(4L, adj, seed = 42L)
  p2 <- .kk_layout_r(4L, adj, seed = 42L)
  expect_equal(p1, p2)
})


test_that(".kk_layout_r produces different positions with different seeds", {
  adj <- matrix(0.5, 3, 3); diag(adj) <- 0
  p1 <- .kk_layout_r(3L, adj, seed = 1L)
  p2 <- .kk_layout_r(3L, adj, seed = 99L)
  expect_false(isTRUE(all.equal(p1, p2)))
})


test_that(".kk_layout_r handles n=1 (degenerate)", {
  pos <- .kk_layout_r(1L, matrix(0, 1, 1))
  expect_equal(dim(pos), c(1L, 2L))
  expect_equal(pos[1L, ], c(0, 0))
})


test_that(".kk_layout_r handles n=2 deterministically by Jaccard", {
  # Two nodes with high Jaccard sit close
  adj_high <- matrix(c(0, 0.9, 0.9, 0), 2L, 2L)
  pos_high <- .kk_layout_r(2L, adj_high)
  d_high <- sqrt(sum((pos_high[1L, ] - pos_high[2L, ])^2))

  # Two nodes with low Jaccard sit far
  adj_low <- matrix(c(0, 0.1, 0.1, 0), 2L, 2L)
  pos_low <- .kk_layout_r(2L, adj_low)
  d_low <- sqrt(sum((pos_low[1L, ] - pos_low[2L, ])^2))

  expect_lt(d_high, d_low)
  # n=2 is a closed-form path: d_high = 1 - 0.9 = 0.1, d_low = 1 - 0.1 = 0.9
  expect_equal(d_high, 0.1, tolerance = 1e-9)
  expect_equal(d_low,  0.9, tolerance = 1e-9)
})


# ------------------------------------------------------------------------------
# Geometric correctness — the property that fixes the IPK constellation
# ------------------------------------------------------------------------------

test_that(".kk_layout_r places dense Jaccard cluster tight + outlier far", {
  # 4-node graph: tight triangle (A-B-C all Jaccard 0.75-0.85) with an
  # outlier D weakly tied to A only (Jaccard 0.10).
  # FR collapses the triangle onto each other; KK should keep the triangle
  # tight while the outlier sits at distance ~ 1 - 0.1 = 0.9.
  adj <- matrix(0, 4, 4)
  adj[1, 2] <- adj[2, 1] <- 0.85
  adj[1, 3] <- adj[3, 1] <- 0.80
  adj[2, 3] <- adj[3, 2] <- 0.75
  adj[1, 4] <- adj[4, 1] <- 0.10

  pos <- .kk_layout_r(4L, adj)

  d <- function(i, j) sqrt(sum((pos[i, ] - pos[j, ])^2))
  d_AB <- d(1, 2); d_AC <- d(1, 3); d_BC <- d(2, 3)
  d_AD <- d(1, 4); d_BD <- d(2, 4); d_CD <- d(3, 4)

  # Triangle distances stay near (1 - jaccard): A-B=0.15, A-C=0.20, B-C=0.25
  # KK won't hit them exactly because all pairs constrain each other, but
  # they should be in the right neighbourhood.
  expect_gt(d_AB, 0.05); expect_lt(d_AB, 0.30)
  expect_gt(d_AC, 0.05); expect_lt(d_AC, 0.30)
  expect_gt(d_BC, 0.05); expect_lt(d_BC, 0.30)

  # Outlier sits far — d_AD should be ~0.9 (the direct edge), and d_BD/d_CD
  # follow shortest path through A so should also be larger than the
  # triangle distances.
  expect_gt(d_AD, 0.5)
  expect_gt(d_BD, d_AB)
  expect_gt(d_CD, d_AC)

  # The point of moving from FR to KK: outlier is genuinely separated from
  # the cluster — d_AD should be at least 3x the average triangle distance.
  triangle_mean <- mean(c(d_AB, d_AC, d_BC))
  expect_gt(d_AD / triangle_mean, 3)
})


test_that(".kk_layout_r preserves Jaccard ranking among edges", {
  # Five-node graph where every edge has a distinct Jaccard. The Euclidean
  # distances in the layout should preserve the ordering of (1 - jaccard) for
  # directly-connected pairs.
  jacs <- c(0.95, 0.80, 0.60, 0.40, 0.20)  # A-B, A-C, A-D, A-E, B-C
  adj <- matrix(0, 5, 5)
  adj[1, 2] <- adj[2, 1] <- jacs[1]
  adj[1, 3] <- adj[3, 1] <- jacs[2]
  adj[1, 4] <- adj[4, 1] <- jacs[3]
  adj[1, 5] <- adj[5, 1] <- jacs[4]
  adj[2, 3] <- adj[3, 2] <- jacs[5]

  pos <- .kk_layout_r(5L, adj)
  d <- function(i, j) sqrt(sum((pos[i, ] - pos[j, ])^2))
  dists <- c(d(1, 2), d(1, 3), d(1, 4), d(1, 5))  # A's edges, sorted by jaccard desc
  # Higher Jaccard => shorter distance => dists should be increasing
  expect_true(all(diff(dists) > 0),
              info = sprintf("Distances: %s", paste(round(dists, 3), collapse = ", ")))
})


test_that(".kk_layout_r handles disconnected components without blowing up", {
  # Two triangles with no edge between them. Each triangle should be tight,
  # and the two triangles should sit at finite distance (sentinel cap, not Inf).
  adj <- matrix(0, 6, 6)
  for (i in 1:2) for (j in (i + 1):3) { adj[i, j] <- adj[j, i] <- 0.7 }
  for (i in 4:5) for (j in (i + 1):6) { adj[i, j] <- adj[j, i] <- 0.7 }

  pos <- .kk_layout_r(6L, adj)
  expect_true(all(is.finite(pos)))

  d <- function(i, j) sqrt(sum((pos[i, ] - pos[j, ])^2))
  # Within-triangle distances — all should be similar
  d_within_1 <- mean(c(d(1, 2), d(1, 3), d(2, 3)))
  d_within_2 <- mean(c(d(4, 5), d(4, 6), d(5, 6)))
  # Across-component distance — should be larger
  d_across <- mean(c(d(1, 4), d(2, 5), d(3, 6)))

  expect_gt(d_across, d_within_1)
  expect_gt(d_across, d_within_2)
})


test_that(".kk_layout_r handles Jaccard >= 1 without crashing (defensive)", {
  # A pair with Jaccard exactly 1 would give edge-length 0 -> div by zero.
  # The implementation floors the edge length at 1e-3 to keep things finite.
  adj <- matrix(0, 3, 3)
  adj[1, 2] <- adj[2, 1] <- 1.0
  adj[2, 3] <- adj[3, 2] <- 0.5
  pos <- .kk_layout_r(3L, adj)
  expect_true(all(is.finite(pos)))
})


# ------------------------------------------------------------------------------
# Performance — 60-node IPK-shape graph
# ------------------------------------------------------------------------------

test_that(".kk_layout_r runs in under 5 seconds for a 60-node dense graph", {
  set.seed(123)
  n <- 60L
  adj <- matrix(0, n, n)
  # Sparse edges with random Jaccard
  for (i in 1:(n - 1L)) for (j in (i + 1L):n) {
    if (runif(1) < 0.15) {
      jac <- runif(1, 0.1, 0.9)
      adj[i, j] <- adj[j, i] <- jac
    }
  }
  t0 <- Sys.time()
  pos <- .kk_layout_r(n, adj)
  elapsed <- as.numeric(Sys.time() - t0, units = "secs")
  expect_lt(elapsed, 5.0)
  expect_equal(dim(pos), c(n, 2L))
  expect_true(all(is.finite(pos)))
})
