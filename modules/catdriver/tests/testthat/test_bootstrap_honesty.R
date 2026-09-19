# ==============================================================================
# CATDRIVER - BOOTSTRAP HONESTY (H5, M1)
# ==============================================================================
# H5. fit_model_for_bootstrap() carried tryCatch(..., warning = function(w) NULL).
#     Every weighted binary fit raises "non-integer #successes in a binomial
#     glm!", so the handler returned NULL for the INITIAL fit and the whole
#     bootstrap was abandoned with a console line. The user asked for bootstrap
#     intervals, got none, and the run reported PASS. The bootstrap guide says
#     weighted data is where the bootstrap is "highly recommended".
# M1. The same handler discarded any resample that warned at all, including
#     quasi-separation, so percentile intervals were computed only over the
#     well-behaved resamples: biased narrow exactly where the bootstrap earns
#     its keep. Discards are now counted, categorised and disclosed.
# ==============================================================================

.cd_boot_fixture <- function(n = 300, seed = 606) {
  set.seed(seed)
  d <- data.frame(
    service = factor(sample(c("Poor", "Good"), n, TRUE)),
    price   = factor(sample(c("Cheap", "Dear"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  eta <- ifelse(d$service == "Good", 1.4, 0) - ifelse(d$price == "Dear", 0.8, 0)
  d$churn <- factor(as.integer(plogis(eta + rlogis(n)) > 0.5))
  d$wt <- runif(n, 0.4, 2.2)
  d$wt <- d$wt / mean(d$wt)
  d
}

test_that("a weighted binary bootstrap produces confidence intervals", {
  d <- .cd_boot_fixture()

  res <- run_bootstrap_or(
    data = d, formula = churn ~ service + price,
    outcome_type = "binary", weights = d$wt,
    n_boot = 40, conf_level = 0.95
  )

  expect_false(is.null(res))                       # it used to be NULL, always
  expect_gt(res$n_successful, 30)
  expect_true(all(is.finite(res$ci_lower)))
  expect_true(all(is.finite(res$ci_upper)))
  expect_true(all(res$ci_lower <= res$ci_upper))
  expect_true(all(res$sign_consistency >= 0 & res$sign_consistency <= 1))
  expect_true(all(c("servicePoor", "priceDear") %in% res$term))
})

test_that("the weighted bootstrap is weighted, and the weights follow their rows", {
  d <- .cd_boot_fixture()

  # A weight vector that carries the signal: respondents who churned get weight
  # near zero. If the resample kept the ORIGINAL weight order, this would leave
  # the interval roughly where the unweighted one sits.
  w <- ifelse(d$churn == "1", 0.02, 2)
  w <- w / mean(w)

  set.seed(1)
  weighted_res <- run_bootstrap_or(d, churn ~ service + price, "binary", w,
                                   n_boot = 40, conf_level = 0.95)
  set.seed(1)
  unweighted_res <- run_bootstrap_or(d, churn ~ service + price, "binary", NULL,
                                     n_boot = 40, conf_level = 0.95)

  expect_false(isTRUE(all.equal(unname(weighted_res$median_or),
                                unname(unweighted_res$median_or),
                                tolerance = 1e-3)))
})

test_that("an unweighted binary bootstrap still works", {
  d <- .cd_boot_fixture()
  res <- run_bootstrap_or(d, churn ~ service + price, "binary", NULL,
                          n_boot = 30, conf_level = 0.95)
  expect_false(is.null(res))
  expect_gt(res$n_successful, 20)
})

test_that("discarded resamples are counted, categorised and disclosed", {
  d <- .cd_boot_fixture()

  res <- run_bootstrap_or(d, churn ~ service + price, "binary", d$wt,
                          n_boot = 30, conf_level = 0.95)

  expect_true(is.numeric(res$n_discarded))
  expect_equal(res$n_successful + res$n_discarded, res$n_boot)
  expect_true(is.character(res$caveat) && nzchar(res$caveat))
  if (res$n_discarded == 0) {
    expect_true(grepl("All resamples were usable", res$caveat))
  } else {
    expect_true(grepl("discarded", res$caveat))
    expect_true(grepl("optimistic", res$caveat))
  }
})

test_that("a separation-prone fixture keeps its resamples and says so", {
  # A rare level that perfectly predicts the outcome: the resamples that include
  # it warn about fitted probabilities of 0 or 1. Those draws used to be thrown
  # away, which is what biased the intervals narrow.
  set.seed(77)
  n <- 220
  d <- data.frame(service = factor(c(rep("Poor", n - 12), rep("Perfect", 12)),
                                   levels = c("Poor", "Perfect")))
  d$churn <- factor(c(rbinom(n - 12, 1, 0.45), rep(1, 12)))
  d$wt <- runif(n, 0.5, 1.8)
  d$wt <- d$wt / mean(d$wt)

  res <- run_bootstrap_or(d, churn ~ service, "binary", d$wt,
                          n_boot = 40, conf_level = 0.95)

  expect_false(is.null(res))
  expect_gt(res$n_successful, 0)
  # Either resamples were kept with a flag, or none warned at all; both are
  # honest, but a flagged resample must never be silently dropped.
  expect_equal(res$n_successful + res$n_discarded, res$n_boot)
  expect_true(is.list(res$kept_flag_counts))
})

test_that("the fit helper reports why a resample failed instead of returning a bare NULL", {
  d <- .cd_boot_fixture()

  ok <- fit_model_for_bootstrap(d, churn ~ service + price, "binary", d$wt)
  expect_equal(ok$status, "ok")
  expect_false(is.null(ok$model))

  # Multinomial is deliberately out of scope for the bootstrap
  skipped <- fit_model_for_bootstrap(d, churn ~ service, "multinomial", NULL)
  expect_equal(skipped$status, "error")
  expect_null(skipped$model)

  broken <- fit_model_for_bootstrap(d, churn ~ not_a_column, "binary", NULL)
  expect_equal(broken$status, "error")
  expect_null(broken$model)
  expect_true(any(grepl("error:", broken$flags)))
})

test_that("a bootstrap that cannot start returns NULL rather than half a result", {
  d <- .cd_boot_fixture()
  expect_null(run_bootstrap_or(d, churn ~ service, "multinomial", NULL, n_boot = 5))
})
