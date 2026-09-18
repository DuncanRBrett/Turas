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

# Loaded rather than skipped: a file-level skip made this report 0 tests
# under test_file, which reads as success (review F17).
kd_ensure_module_loaded("core")
expect_true(exists("calculate_relative_weights", mode = "function"))

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

# ------------------------------------------------------------------------------
# H3: the provenance names the engine that ran
# ------------------------------------------------------------------------------

test_that("the dead v10.3 importance engine is gone (H3)", {
  # Three functions implementing a partial-R-squared and permutation scheme
  # that nothing in the pipeline called. The Run_Status sheet stamped
  # "partial_r2" anyway, so the provenance named an engine that had not run.
  for (fn in c("calculate_importance_partial_r2", "calculate_importance_permutation",
               "calculate_importance_by_config")) {
    expect_false(exists(fn, mode = "function"), info = fn)
  }
})

test_that("primary_method reports Shapley, and says when a run was mixed (H3)", {
  skip_if(!exists(".kd_primary_method", mode = "function"), "helper not loaded")
  plain <- list(importance = data.frame(Driver = c("A", "B"),
                                        Shapley_Value = c(0.3, 0.1),
                                        stringsAsFactors = FALSE))
  expect_equal(.kd_primary_method(plain), "shapley_r2_decomposition")
  expect_false(grepl("partial_r2", .kd_primary_method(plain), fixed = TRUE))

  mixed <- plain
  mixed$importance$Method_Note <- c("direct", "grouped_terms")
  expect_match(.kd_primary_method(mixed), "mixed")

  # Nothing to report is said, not guessed.
  expect_equal(.kd_primary_method(list()), "unknown")
})

test_that("AggregationMethod no longer refuses a run it cannot affect (H3)", {
  src <- readLines(file.path(module_dir, "R", "01_config.R"))
  expect_false(any(grepl("CFG_INVALID_AGGREGATION_METHOD", src, fixed = TRUE)))
  expect_false(any(grepl("valid_agg_methods", src, fixed = TRUE)))
  # And a config that still sets it is told, not refused.
  expect_true(any(grepl("That setting is withdrawn", src, fixed = TRUE)))
})

test_that("the stats pack does not credit a package the module never used (H3)", {
  src <- readLines(file.path(module_dir, "R", "00_main.R"))
  expect_false(any(grepl('"shapr package"', src, fixed = TRUE)))
  expect_true(any(grepl("TreeSHAP", src, fixed = TRUE)))
  expect_true(any(grepl("xgboost", src, fixed = TRUE)))
})

# ------------------------------------------------------------------------------
# H4: the mixed path refuses where the non-mixed path refuses
# ------------------------------------------------------------------------------

test_that("a near-singular mixed model refuses instead of substituting a proxy (H4)", {
  skip_if(!exists("calculate_relative_weights_mixed", mode = "function"), "mixed path not loaded")
  skip_if(!exists("build_term_mapping", mode = "function"), "term mapping not loaded")
  set.seed(19)
  n <- 300
  x1 <- rnorm(n)
  # A second driver that is a near-perfect copy: the term correlation matrix
  # is then singular to numerical tolerance.
  x2 <- x1 + rnorm(n, sd = 1e-7)
  grp <- factor(sample(c("A", "B"), n, TRUE))
  y <- 0.8 * x1 + rnorm(n, sd = 0.3)
  d <- data.frame(X1 = x1, X2 = x2, G = grp, Y = y)
  cfg <- list(outcome_var = "Y", driver_vars = c("X1", "X2", "G"), weight_var = NULL)
  f <- Y ~ X1 + X2 + G
  model <- lm(f, data = d)
  tm <- build_term_mapping(f, d, cfg$driver_vars)

  err <- tryCatch({
    suppressWarnings(capture.output(
      calculate_relative_weights_mixed(model, d, cfg, tm)))
    "NO REFUSAL"
  }, error = function(e) conditionMessage(e))
  expect_match(err, "MODEL_SINGULAR_MATRIX")
  # The old behaviour named itself on the console and carried on.
  expect_false(grepl("simplified relative weights", err, fixed = TRUE))
  # And the refusal explains why a proxy was not acceptable.
  expect_match(err, "do not decompose R-squared|not decompose")
})

test_that("the silent proxy is gone from the source (H4)", {
  src <- readLines(file.path(module_dir, "R", "03_analysis.R"))
  expect_false(any(grepl("using simplified relative weights", src, fixed = TRUE)))
  expect_false(any(grepl("Fallback: use squared correlations as proxy", src, fixed = TRUE)))
})

test_that("a weighted mixed run uses weighted correlations (A1)", {
  skip_if(!exists("calculate_relative_weights_mixed", mode = "function"), "mixed path not loaded")
  skip_if(!exists("build_term_mapping", mode = "function"), "term mapping not loaded")
  set.seed(23)
  n <- 800
  x1 <- rnorm(n); x2 <- rnorm(n)
  grp <- factor(sample(c("A", "B"), n, TRUE))
  # The relationship differs sharply between the halves the weight favours.
  half <- seq_len(n / 2)
  y <- 0.2 * x1 + 0.8 * x2 + rnorm(n, sd = 0.3)
  y[half] <- 1.4 * x1[half] + 0.1 * x2[half] + rnorm(n / 2, sd = 0.3)
  d <- data.frame(X1 = x1, X2 = x2, G = grp, Y = y, W = 1)
  d$W[half] <- 9
  f <- Y ~ X1 + X2 + G
  model <- lm(f, data = d)
  tm <- build_term_mapping(f, d, c("X1", "X2", "G"))

  base <- list(outcome_var = "Y", driver_vars = c("X1", "X2", "G"))
  un <- suppressWarnings(capture.output(
    a <- calculate_relative_weights_mixed(model, d, c(base, list(weight_var = NULL)), tm)))
  we <- suppressWarnings(capture.output(
    b <- calculate_relative_weights_mixed(model, d, c(base, list(weight_var = "W")), tm)))
  expect_equal(length(a), length(b))
  # The weights move the correlations, so they move the weights. Before the
  # fix the mixed path used plain cor() whatever the config said.
  expect_gt(max(abs(as.numeric(a) - as.numeric(b))), 1)
})
