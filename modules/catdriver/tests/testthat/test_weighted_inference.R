# ==============================================================================
# CATDRIVER - WEIGHTS THROUGH THE LIKELIHOOD MACHINERY (C1, H1, H2, M6)
# ==============================================================================
# July 2026 production review:
#   C1  weighted multinomial importance subtracted an UNWEIGHTED reduced
#       log-likelihood from a WEIGHTED full one, so real drivers came out with
#       negative chi-squares and the importance shares were nonsense, under PASS.
#   H1  the ordinal and multinomial null models were refitted without weights,
#       so McFadden R-squared came out negative.
#   H2  raw weights were passed straight through as frequency weights, so
#       multiplying every weight by a constant shrank every standard error.
#   M6  missing and negative weights were repaired silently.
# ==============================================================================

.cd_weighted_fixture <- function(n = 600, seed = 20260918, scale = 1) {
  set.seed(seed)
  d <- data.frame(
    driver_strong = factor(sample(c("a", "b", "c"), n, TRUE)),
    driver_weak   = factor(sample(c("lo", "hi"), n, TRUE)),
    driver_noise  = factor(sample(c("p", "q"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  # Known truth: driver_strong moves the outcome hard, driver_weak a little,
  # driver_noise not at all.
  eta_b <- ifelse(d$driver_strong == "b", 1.8, 0) + ifelse(d$driver_strong == "c", -1.4, 0) +
    ifelse(d$driver_weak == "hi", 0.5, 0)
  eta_c <- ifelse(d$driver_strong == "c", 1.6, 0) + ifelse(d$driver_weak == "hi", 0.4, 0)
  p <- cbind(1, exp(eta_b), exp(eta_c))
  p <- p / rowSums(p)
  d$outcome <- factor(apply(p, 1, function(pr) sample(c("A", "B", "C"), 1, prob = pr)))
  d$ordinal_outcome <- factor(
    ifelse(eta_b + rlogis(n) > 1, "High", ifelse(eta_b + rlogis(n) > -0.5, "Mid", "Low")),
    levels = c("Low", "Mid", "High"), ordered = TRUE
  )
  d$binary_outcome <- factor(as.integer(plogis(eta_b + rlogis(n)) > 0.5))
  d$wt <- runif(n, 0.4, 2.2) * scale
  d
}

.cd_config <- function(outcome_var, outcome_type, weight_var = "wt") {
  list(
    outcome_var = outcome_var,
    outcome_type = outcome_type,
    outcome_label = outcome_var,
    confidence_level = 0.95,
    driver_vars = c("driver_strong", "driver_weak", "driver_noise"),
    weight_var = weight_var,
    variables = data.frame(
      VariableName = c("driver_strong", "driver_weak", "driver_noise"),
      Label = c("Strong", "Weak", "Noise"),
      stringsAsFactors = FALSE
    )
  )
}

# ---------------------------------------------------------------- normalisation

test_that("weights are normalised to mean 1 and every repair is counted", {
  res <- normalise_catdriver_weights(c(10, 20, 30, NA, -5), "wt")

  expect_true(res$usable)
  expect_equal(res$n_na_imputed, 1L)
  expect_equal(res$n_negative_zeroed, 1L)
  expect_true(res$rescaled)
  # mean over the positive weights after repair (10, 20, 30, 1) = 15.25
  expect_equal(res$raw_mean, 15.25)
  expect_equal(mean(res$weights[res$weights > 0]), 1)
  expect_true(any(grepl("rescaled to mean 1", res$notes)))
  expect_true(any(grepl("set to 1", res$notes)))
  expect_true(any(grepl("set to 0", res$notes)))
})

test_that("weights already on mean 1 are left alone", {
  res <- normalise_catdriver_weights(c(0.5, 1, 1.5), "wt")
  expect_false(res$rescaled)
  expect_equal(res$weights, c(0.5, 1, 1.5))
  expect_length(res$notes, 0)
})

test_that("a weight column with nothing usable in it is reported, not used", {
  res <- normalise_catdriver_weights(c(0, -1, NA_real_), "wt")
  # NA becomes 1, so this one IS usable; the all-zero case is the unusable one
  expect_true(res$usable)
  expect_false(normalise_catdriver_weights(c(0, 0, 0), "wt")$usable)
  expect_null(normalise_catdriver_weights(c(0, 0, 0), "wt")$weights)
})

test_that("the inference stamp says the design effect is not applied", {
  d <- .cd_weighted_fixture(n = 200)
  w <- normalise_catdriver_weights(d$wt, "wt")
  diag <- calculate_weight_diagnostics(w$weights)
  stamp <- catdriver_weighting_stamp("wt", diag, w)

  expect_true(grepl("frequency weights", stamp))
  expect_true(grepl("NOT applied", stamp))
  expect_true(grepl("Kish effective n", stamp))
  expect_false(grepl("design-based inference is implemented", stamp, ignore.case = TRUE))

  expect_true(grepl("Unweighted", catdriver_weighting_stamp(NULL, NULL, NULL)))
})

# --------------------------------------------------- C1: multinomial importance

test_that("weighted multinomial importance is non-negative and recovers the true order", {
  skip_if_not_installed("nnet")

  d <- .cd_weighted_fixture()
  config <- .cd_config("outcome", "multinomial")
  w <- normalise_catdriver_weights(d$wt, "wt")$weights

  fit <- run_multinomial_logistic_robust(
    outcome ~ driver_strong + driver_weak + driver_noise,
    d, w, config, guard_init()
  )
  imp <- calculate_multinomial_importance(fit, config)

  # The defect produced large NEGATIVE chi-squares for real drivers.
  expect_true(all(imp$chi_square >= 0 | is.na(imp$chi_square)),
              info = paste(utils::capture.output(print(imp)), collapse = "\n"))
  expect_true(all(imp$importance_pct >= 0 | is.na(imp$importance_pct)))
  expect_equal(imp$variable[1], "driver_strong")
  expect_equal(imp$variable[nrow(imp)], "driver_noise")
  expect_true(imp$importance_pct[1] > imp$importance_pct[nrow(imp)])
  expect_true(all(grepl("weighted", imp$method)))
})

test_that("the weighted reduced fits are the weighted ones, not unweighted copies", {
  skip_if_not_installed("nnet")

  d <- .cd_weighted_fixture()
  config <- .cd_config("outcome", "multinomial")
  w <- normalise_catdriver_weights(d$wt, "wt")$weights

  fit <- run_multinomial_logistic_robust(
    outcome ~ driver_strong + driver_weak + driver_noise,
    d, w, config, guard_init()
  )
  imp <- calculate_multinomial_importance(fit, config)

  # Independently: the weighted LR for driver_weak, computed from two fits
  # written here from the definition.
  dd <- d
  dd$..w.. <- w
  full <- nnet::multinom(outcome ~ driver_strong + driver_weak + driver_noise,
                         data = dd, weights = ..w.., trace = FALSE, maxit = 500)
  red  <- nnet::multinom(outcome ~ driver_strong + driver_noise,
                         data = dd, weights = ..w.., trace = FALSE, maxit = 500)
  lr_expected <- -2 * (as.numeric(logLik(red)) - as.numeric(logLik(full)))

  got <- imp$chi_square[imp$variable == "driver_weak"]
  expect_equal(got, lr_expected, tolerance = 1e-4)

  # And it is NOT the unweighted statistic
  full_u <- nnet::multinom(outcome ~ driver_strong + driver_weak + driver_noise,
                           data = dd, trace = FALSE, maxit = 500)
  red_u  <- nnet::multinom(outcome ~ driver_strong + driver_noise,
                           data = dd, trace = FALSE, maxit = 500)
  lr_unweighted <- -2 * (as.numeric(logLik(red_u)) - as.numeric(logLik(full_u)))
  expect_false(isTRUE(all.equal(got, lr_unweighted, tolerance = 1e-3)))
})

test_that("the importance refits use only the rows the full model used", {
  skip_if_not_installed("nnet")

  d <- .cd_weighted_fixture()
  d$driver_weak[1:25] <- NA          # rows the full fit drops
  config <- .cd_config("outcome", "multinomial")
  w <- normalise_catdriver_weights(d$wt, "wt")$weights

  fit <- run_multinomial_logistic_robust(
    outcome ~ driver_strong + driver_weak + driver_noise,
    d, w, config, guard_init()
  )
  expect_equal(nrow(fit$estimation_data), nrow(d) - 25)

  imp <- calculate_multinomial_importance(fit, config)
  # Dropping driver_weak from the formula would otherwise ADD 25 rows back and
  # make the two log-likelihoods incomparable — the classic negative LR.
  expect_true(all(imp$chi_square >= 0 | is.na(imp$chi_square)))
})

# ------------------------------------------------------------- H1: null models

test_that("weighted McFadden R-squared is in [0, 1] for every engine", {
  skip_if_not_installed("nnet")
  skip_if_not_installed("ordinal")

  d <- .cd_weighted_fixture()
  w <- normalise_catdriver_weights(d$wt, "wt")$weights

  fit_m <- run_multinomial_logistic_robust(
    outcome ~ driver_strong + driver_weak + driver_noise,
    d, w, .cd_config("outcome", "multinomial"), guard_init()
  )
  expect_gte(fit_m$fit_statistics$mcfadden_r2, 0)
  expect_lte(fit_m$fit_statistics$mcfadden_r2, 1)
  expect_gte(fit_m$fit_statistics$lr_statistic, 0)

  fit_o <- run_ordinal_logistic_robust(
    ordinal_outcome ~ driver_strong + driver_weak + driver_noise,
    d, w, .cd_config("ordinal_outcome", "ordinal"), guard_init()
  )
  expect_gte(fit_o$fit_statistics$mcfadden_r2, 0)
  expect_lte(fit_o$fit_statistics$mcfadden_r2, 1)
  expect_gte(fit_o$fit_statistics$lr_statistic, 0)

  fit_b <- run_binary_logistic_robust(
    binary_outcome ~ driver_strong + driver_weak + driver_noise,
    d, w, .cd_config("binary_outcome", "binary"), guard_init()
  )
  expect_gte(fit_b$fit_statistics$mcfadden_r2, 0)
  expect_lte(fit_b$fit_statistics$mcfadden_r2, 1)
})

# ------------------------------------------------- H2: rescaling must not matter

test_that("multiplying every weight by a constant leaves the standard errors alone", {
  d1 <- .cd_weighted_fixture(scale = 1)
  d2 <- d1
  d2$wt <- d1$wt * 4            # any rescaling at all: the H2 failure mode

  w1 <- normalise_catdriver_weights(d1$wt, "wt")$weights
  w2 <- normalise_catdriver_weights(d2$wt, "wt")$weights
  expect_equal(w1, w2)

  config <- .cd_config("binary_outcome", "binary")
  se <- function(w) {
    fit <- run_binary_logistic_robust(
      binary_outcome ~ driver_strong + driver_weak + driver_noise,
      d1, w, config, guard_init()
    )
    summary(fit$model)$coefficients[, 2]
  }
  expect_equal(se(w1), se(w2))

  # And the raw-scale fit, which is what shipped, is materially different:
  # four times the weights halves every standard error.
  se_raw <- summary(run_binary_logistic_robust(
    binary_outcome ~ driver_strong + driver_weak + driver_noise,
    d1, d2$wt, config, guard_init()
  )$model)$coefficients[, 2]
  expect_false(isTRUE(all.equal(unname(se_raw), unname(se(w1)), tolerance = 1e-3)))

})

test_that("a weighted binary fit no longer raises the non-integer successes warning", {
  d <- .cd_weighted_fixture(n = 300)
  w <- normalise_catdriver_weights(d$wt, "wt")$weights
  expect_silent(
    run_binary_logistic_robust(
      binary_outcome ~ driver_strong + driver_weak + driver_noise,
      d, w, .cd_config("binary_outcome", "binary"), guard_init()
    )
  )
})
