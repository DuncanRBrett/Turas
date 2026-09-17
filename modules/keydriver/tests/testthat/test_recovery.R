# ==============================================================================
# KEYDRIVER - RECOVERY AGAINST A KNOWN TRUTH (review A11)
# ==============================================================================
# Every other test in this module checks a property: the shares sum to 100, the
# refusal fires, the column exists. None of them asks the question a client
# asks, which is whether the ranking is right. These build data whose true
# driver order is known by construction and check the engine recovers it.
# ==============================================================================

# Not a skip: the engine is the thing under test.
stopifnot(exists("calculate_importance_scores", mode = "function"))

# Five drivers with known, well-separated coefficients on standardised inputs,
# so the true importance order is b1 > b2 > b3 > b4 > b5 by construction.
truth_fixture <- function(n = 1500, seed = 101, weighted = FALSE) {
  set.seed(seed)
  b <- c(0.90, 0.55, 0.35, 0.18, 0.05)
  x <- as.data.frame(matrix(rnorm(n * 5), n, 5))
  names(x) <- paste0("D", 1:5)
  x$Y <- as.matrix(x) %*% b + rnorm(n, sd = 0.5)
  x$Y <- as.numeric(x$Y)
  if (weighted) x$W <- runif(n, 0.4, 2.2)
  attr(x, "true_order") <- paste0("D", 1:5)
  x
}

test_that("the engine recovers a known driver ranking (A11)", {
  d <- truth_fixture()
  cfg <- list(outcome_var = "Y", driver_vars = paste0("D", 1:5), weight_var = NULL)
  corr <- cor(d[, c(paste0("D", 1:5), "Y")])
  model <- lm(Y ~ D1 + D2 + D3 + D4 + D5, data = d)
  imp <- suppressWarnings(calculate_importance_scores(model, d, corr, cfg))

  expect_true(is.data.frame(imp))
  expect_true("Shapley_Value" %in% names(imp))

  by_shapley <- imp$Driver[order(-imp$Shapley_Value)]
  expect_equal(by_shapley, attr(d, "true_order"))

  by_beta <- imp$Driver[order(-abs(imp$Beta_Weight))]
  expect_equal(by_beta, attr(d, "true_order"))

  # Relative weights must agree too, which they could not before C1 was fixed.
  by_rw <- imp$Driver[order(-imp$Relative_Weight)]
  expect_equal(by_rw, attr(d, "true_order"))

  # Rank correlation against the truth, as the review asked for.
  truth_rank <- seq_along(attr(d, "true_order"))
  got_rank <- match(attr(d, "true_order"), by_shapley)
  expect_equal(cor(truth_rank, got_rank, method = "spearman"), 1)
})

test_that("two drivers are not reported as equally important (C1 regression)", {
  # The narrowest case, and the one the old relative-weights math could not
  # tell apart: two drivers always split 50/50 whatever the data said.
  set.seed(77)
  n <- 1200
  d <- data.frame(D1 = rnorm(n), D2 = rnorm(n))
  d$Y <- 0.9 * d$D1 + 0.15 * d$D2 + rnorm(n, sd = 0.5)
  cfg <- list(outcome_var = "Y", driver_vars = c("D1", "D2"), weight_var = NULL)
  corr <- cor(d[, c("D1", "D2", "Y")])
  model <- lm(Y ~ D1 + D2, data = d)
  imp <- suppressWarnings(calculate_importance_scores(model, d, corr, cfg))

  rw <- imp$Relative_Weight[match(c("D1", "D2"), imp$Driver)]
  shares <- 100 * rw / sum(rw)
  expect_gt(shares[1], 80)
  expect_lt(shares[2], 20)
  expect_false(isTRUE(all.equal(shares, c(50, 50), tolerance = 0.05)))
})

test_that("a weighted importance table differs from an unweighted one (A11)", {
  # The weighted half of the sample follows a different driver, so weighting
  # has to change the answer. Before M1 and C1 the standard deviations and the
  # relative weights ignored the weight column entirely.
  set.seed(31)
  n <- 2000
  d <- data.frame(D1 = rnorm(n), D2 = rnorm(n))
  # A fifth of the sample follows D1 hard; the rest follow D2. Unweighted, the
  # majority wins. Weighted, that fifth carries twenty times the weight and
  # becomes most of the effective sample, so the answer must flip.
  minority <- seq_len(n / 5)
  d$Y <- 0.10 * d$D1 + 1.00 * d$D2 + rnorm(n, sd = 0.5)
  d$Y[minority] <- 2.20 * d$D1[minority] + 0.05 * d$D2[minority] +
    rnorm(length(minority), sd = 0.5)
  d$W <- 1
  d$W[minority] <- 20

  base <- list(outcome_var = "Y", driver_vars = c("D1", "D2"))
  model_un <- lm(Y ~ D1 + D2, data = d)
  model_we <- lm(Y ~ D1 + D2, data = d, weights = d$W)
  corr_un <- cor(d[, c("D1", "D2", "Y")])
  corr_we <- calculate_correlations(d, c(base, list(weight_var = "W")))

  un <- suppressWarnings(calculate_importance_scores(
    model_un, d, corr_un, c(base, list(weight_var = NULL))))
  we <- suppressWarnings(calculate_importance_scores(
    model_we, d, corr_we, c(base, list(weight_var = "W"))))

  # The unweighted sample is dominated by D2; the weighted one by D1.
  expect_equal(un$Driver[which.max(un$Shapley_Value)], "D2")
  expect_equal(we$Driver[which.max(we$Shapley_Value)], "D1")
  # And the standardised betas moved, which is M1.
  b_un <- un$Beta_Weight[match("D1", un$Driver)]
  b_we <- we$Beta_Weight[match("D1", we$Driver)]
  expect_gt(abs(b_we - b_un), 0.05)
})
