# ==============================================================================
# KEYDRIVER - JOHNSON RELATIVE WEIGHTS (review C1)
# ==============================================================================
# The engine orthogonalised with V * sqrt(Lambda), which is the PCA rotation,
# where Johnson's method needs the SYMMETRIC square root V * sqrt(Lambda) * V'.
# The difference is not cosmetic: with two drivers the PCA form returns 50/50
# whatever the data says, so a two-driver study's headline importance split was
# a constant.
#
# The golden values below were computed independently of the engine, from
# Johnson (2000) directly:
#   Lam        <- V %*% diag(sqrt(vals)) %*% t(V)     # symmetric square root
#   beta_star  <- solve(Lam) %*% r_xy                 # betas on the orthogonals
#   rw         <- (Lam^2) %*% (beta_star^2)           # weights in R-squared units
# and cross-checked against R2 = r_xy' R_xx^-1 r_xy, which the raw weights must
# equal before any normalisation.
# ==============================================================================

skip_if(!exists("calculate_relative_weights", mode = "function"), "engine not loaded")

# Johnson's method, written out here so the test does not lean on the engine.
johnson_reference <- function(R, rxy) {
  e <- eigen(R, symmetric = TRUE)
  p <- nrow(R)
  Lam <- e$vectors %*% diag(sqrt(e$values), p, p) %*% t(e$vectors)
  beta_star <- solve(Lam) %*% rxy
  as.numeric((Lam^2) %*% (beta_star^2))
}

# A data set with a known correlation structure, so the engine's own
# correlation matrix is the one the golden values were derived from.
rw_fixture <- function(R, rxy, n = 4000, seed = 42) {
  set.seed(seed)
  p <- nrow(R)
  full <- rbind(cbind(R, rxy), c(rxy, 1))
  L <- chol(full)
  z <- matrix(rnorm(n * (p + 1)), n, p + 1) %*% L
  d <- as.data.frame(z)
  names(d) <- c(paste0("D", seq_len(p)), "Y")
  d
}

test_that("two drivers do not split 50/50 regardless of the data (C1)", {
  R <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
  rxy <- c(0.6, 0.2)
  rw <- johnson_reference(R, rxy)
  shares <- 100 * rw / sum(rw)

  # Hand-derived, and nowhere near an even split: driver 1 correlates three
  # times as strongly with the outcome.
  expect_equal(shares, c(92.857143, 7.142857), tolerance = 1e-6)
  expect_false(isTRUE(all.equal(shares, c(50, 50))))

  # The engine, given data with this correlation structure, must agree.
  d <- rw_fixture(R, rxy)
  cfg <- list(outcome_var = "Y", driver_vars = c("D1", "D2"))
  corr <- cor(d[, c("D1", "D2", "Y")])
  model <- lm(Y ~ D1 + D2, data = d)
  got <- calculate_relative_weights(model, corr, cfg)
  got_shares <- unname(100 * got / sum(got))
  # The sample correlations are not exactly R, so allow for sampling, but the
  # gap between the two drivers must be unmistakable.
  expect_gt(got_shares[1], 85)
  expect_lt(got_shares[2], 15)
})

test_that("raw relative weights sum to the model R-squared before normalising (C1)", {
  R <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
  rxy <- c(0.6, 0.2)
  rw <- johnson_reference(R, rxy)
  r2 <- as.numeric(t(rxy) %*% solve(R) %*% rxy)
  # This identity is why the engine's rescale-to-R-squared step was a plaster
  # over the wrong math: correct weights already sum to R-squared.
  expect_equal(sum(rw), r2, tolerance = 1e-12)
  expect_equal(sum(rw), 0.3733333333, tolerance = 1e-9)
})

test_that("a three-driver golden case matches an independent computation (C1)", {
  R <- matrix(c(1, .4, .3, .4, 1, .5, .3, .5, 1), 3, 3)
  rxy <- c(.55, .35, .20)
  rw <- johnson_reference(R, rxy)
  expect_equal(rw, c(0.2453332600, 0.0646598193, 0.0133940174), tolerance = 1e-9)
  expect_equal(sum(rw), as.numeric(t(rxy) %*% solve(R) %*% rxy), tolerance = 1e-12)

  d <- rw_fixture(R, rxy, seed = 7)
  cfg <- list(outcome_var = "Y", driver_vars = c("D1", "D2", "D3"))
  corr <- cor(d[, c("D1", "D2", "D3", "Y")])
  model <- lm(Y ~ D1 + D2 + D3, data = d)
  got <- calculate_relative_weights(model, corr, cfg)
  got_shares <- 100 * got / sum(got)
  expect_equal(unname(got_shares), c(75.863651, 19.994558, 4.141791), tolerance = 0.06)
  # And the ranking is the one the data implies.
  expect_equal(order(got_shares, decreasing = TRUE), 1:3)
})
