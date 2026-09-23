# The penalised ordinal fit: agreement with ordinal::clm, the gradient, weights
# and the per-column penalty.

clm_fit <- function(X, y, w = NULL) {
  d <- data.frame(X)
  d$y <- factor(y, levels = sort(unique(y)), ordered = TRUE)
  if (is.null(w)) {
    m <- ordinal::clm(y ~ ., data = d, link = "logit")
  } else {
    d$.w <- w
    m <- ordinal::clm(stats::reformulate(colnames(X), "y"), data = d, weights = .w, link = "logit")
  }
  list(b = unname(stats::coef(m)[colnames(X)]), theta = unname(m$alpha))
}

sim_ordinal <- function(n, beta, cuts, seed) {
  set.seed(seed)
  X <- cbind(a = rnorm(n), b = rbinom(n, 1, 0.4), c = sample(1:5, n, TRUE) - 3)
  eta <- drop(X %*% beta)
  y <- as.integer(cut(eta + stats::rlogis(n), c(-Inf, cuts, Inf), labels = FALSE))
  list(X = X, y = y)
}

test_that("unpenalised fit equals ordinal::clm to 1e-4 (three categories, unweighted)", {
  skip_if_not_installed("ordinal")
  s <- sim_ordinal(700, c(0.8, -0.5, 0.3), c(-0.5, 1), seed = 11)
  ours <- whatif_fit_ordinal(s$X, s$y, penalty = 0)
  ref <- clm_fit(s$X, s$y)
  expect_true(ours$converged)
  expect_lt(max(abs(unname(ours$b) - ref$b)), 1e-4)
  expect_lt(max(abs(ours$theta - ref$theta)), 1e-4)
})

test_that("unpenalised fit equals ordinal::clm to 1e-4 with weights", {
  skip_if_not_installed("ordinal")
  s <- sim_ordinal(700, c(0.8, -0.5, 0.3), c(-0.5, 1), seed = 12)
  set.seed(3)
  w <- runif(700, 0.3, 2.5)
  ours <- whatif_fit_ordinal(s$X, s$y, w, penalty = 0)
  ref <- clm_fit(s$X, s$y, w)
  expect_lt(max(abs(unname(ours$b) - ref$b)), 1e-4)
  expect_lt(max(abs(ours$theta - ref$theta)), 1e-4)
})

test_that("two categories (binary) and five categories also match ordinal::clm", {
  skip_if_not_installed("ordinal")
  s2 <- sim_ordinal(600, c(0.7, 0.4, -0.2), 0.3, seed = 13)
  o2 <- whatif_fit_ordinal(s2$X, s2$y, penalty = 0)
  r2 <- clm_fit(s2$X, s2$y)
  expect_length(o2$theta, 1)
  expect_lt(max(abs(c(unname(o2$b), o2$theta) - c(r2$b, r2$theta))), 1e-4)

  s5 <- sim_ordinal(900, c(0.6, -0.3, 0.4), c(-1.5, -0.3, 0.6, 1.8), seed = 14)
  o5 <- whatif_fit_ordinal(s5$X, s5$y, penalty = 0)
  r5 <- clm_fit(s5$X, s5$y)
  expect_length(o5$theta, 4)
  expect_lt(max(abs(c(unname(o5$b), o5$theta) - c(r5$b, r5$theta))), 1e-4)
})

test_that("the synthetic fixture's design matrix fit equals ordinal::clm", {
  skip_if_not_installed("ordinal")
  spec <- whatif_synthetic_study(weighted = TRUE)
  spec <- whatif_guard_spec(spec)
  d <- whatif_build_design(spec$levers, spec$scale, spec$context, character(0))
  ours <- whatif_fit_ordinal(d$X, spec$y, spec$weights, penalty = 0)
  ref <- clm_fit(d$X, spec$y, spec$weights)
  expect_lt(max(abs(unname(ours$b) - ref$b)), 1e-4)
  expect_lt(max(abs(ours$theta - ref$theta)), 1e-4)
})

test_that("the analytic gradient matches a numerical gradient", {
  s <- sim_ordinal(300, c(0.8, -0.5, 0.3), c(-0.5, 1), seed = 15)
  w <- rep(c(0.5, 1.5), 150)
  pen <- c(0.3, 0, 2)
  set.seed(4)
  par <- c(rnorm(3, 0, 0.5), -0.4, log(1.2))
  g <- whatif_nll(par, s$X, s$y, w, pen, 3)$gradient
  num <- vapply(seq_along(par), function(i) {
    e <- replace(numeric(length(par)), i, 1e-6)
    (whatif_nll(par + e, s$X, s$y, w, pen, 3)$value - whatif_nll(par - e, s$X, s$y, w, pen, 3)$value) / 2e-6
  }, numeric(1))
  expect_lt(max(abs(g - num)), 1e-4)
})

test_that("doubling every weight leaves the unpenalised fit unchanged", {
  s <- sim_ordinal(500, c(0.8, -0.5, 0.3), c(-0.5, 1), seed = 16)
  a <- whatif_fit_ordinal(s$X, s$y, rep(1, 500), penalty = 0)
  b <- whatif_fit_ordinal(s$X, s$y, rep(2, 500), penalty = 0)
  expect_lt(max(abs(a$b - b$b)), 1e-5)
})

test_that("a weight of 2 equals the same respondent entered twice", {
  s <- sim_ordinal(400, c(0.8, -0.5, 0.3), c(-0.5, 1), seed = 17)
  w <- c(rep(2, 50), rep(1, 350))
  a <- whatif_fit_ordinal(s$X, s$y, w, penalty = 0)
  idx <- c(1:50, 1:400)
  b <- whatif_fit_ordinal(s$X[idx, ], s$y[idx], penalty = 0)
  expect_lt(max(abs(a$b - b$b)), 1e-5)
  expect_lt(max(abs(a$theta - b$theta)), 1e-5)
})

test_that("the penalty shrinks only the columns it is given", {
  s <- sim_ordinal(600, c(0.8, -0.5, 0.3), c(-0.5, 1), seed = 18)
  free <- whatif_fit_ordinal(s$X, s$y, penalty = 0)
  pen <- whatif_fit_ordinal(s$X, s$y, penalty = c(0, 1e4, 0))
  expect_lt(abs(pen$b[["b"]]), 0.01)
  expect_gt(abs(free$b[["b"]]), 0.3)
  expect_equal(sign(pen$b[["a"]]), sign(free$b[["a"]]))
})

test_that("probabilities sum to one and the NPS score is P(top) - P(bottom)", {
  s <- sim_ordinal(200, c(0.8, -0.5, 0.3), c(-0.5, 1), seed = 19)
  fit <- whatif_fit_ordinal(s$X, s$y, penalty = 0)
  eta <- drop(s$X %*% fit$b)
  P <- whatif_probs(fit, eta)
  expect_equal(rowSums(P), rep(1, 200), tolerance = 1e-12)
  expect_equal(whatif_score_vec(fit, eta, c(-100, 0, 100)), 100 * (P[, 3] - P[, 1]))
})

test_that("cross-validation folds cover every respondent once and are reproducible", {
  f1 <- whatif_cv_folds(103, 5, 7)
  f2 <- whatif_cv_folds(103, 5, 7)
  expect_identical(f1, f2)
  expect_setequal(unlist(f1), 1:103)
  expect_length(unlist(f1), 103)
})

test_that("the penalty chooser returns a grid value with its table", {
  s <- sim_ordinal(400, c(0.8, -0.5, 0.3), c(-0.5, 1), seed = 20)
  ch <- whatif_choose_penalty(s$X, s$y, rep(1, 400), 3, c(FALSE, TRUE, TRUE), c(1, 10, 100), 0,
                              whatif_cv_folds(400, 5, 7))
  expect_true(ch$penalty %in% c(1, 10, 100))
  expect_equal(nrow(ch$table), 3)
  expect_equal(ch$table$cv_r2[ch$table$penalty == ch$penalty], max(ch$table$cv_r2))
})
