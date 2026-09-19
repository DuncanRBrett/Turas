# ==============================================================================
# CATDRIVER - TESTS THAT FAIL WHEN THE FIX IS REMOVED (F18 to F21)
# ==============================================================================
# The independent review reverted several Session A fixes and found the suite
# stayed green. A test that passes on the broken code is not a test of the fix;
# it is a test of something else that happens to hold either way.
#
# F18. H1, the weighted null models: reverting all three refits to unweighted
#      left the suite green, because the assertions only checked that McFadden
#      lay in [0, 1] and mean-1 weights keep the two nulls close.
# F19. M1, the bootstrap's kept-with-warning path had never executed under test.
# F20. C1's headline test passed with the reduced models refitted unweighted.
# F21. Two tests the handover required were never written: the subgroup
#      comparison's failure degrade, and an enabled-but-failed bootstrap.
# ==============================================================================

.cd_disc_fixture <- function(n = 600, seed = 31415) {
  set.seed(seed)
  d <- data.frame(
    driver_a = factor(sample(c("lo", "mid", "hi"), n, TRUE)),
    driver_b = factor(sample(c("x", "y"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  eta <- ifelse(d$driver_a == "hi", 1.6, 0) + ifelse(d$driver_a == "mid", 0.7, 0) +
    ifelse(d$driver_b == "y", 0.5, 0)
  u <- eta + rlogis(n)
  d$ord <- factor(ifelse(u > 1, "High", ifelse(u > -0.5, "Mid", "Low")),
                  levels = c("Low", "Mid", "High"), ordered = TRUE)
  d$multi <- factor(apply(cbind(1, exp(eta), exp(eta * 0.5)), 1,
                          function(p) sample(c("A", "B", "C"), 1, prob = p)))
  # Weights that carry real information, so a weighted fit and an unweighted one
  # cannot agree by accident. Respondents high on the outcome get light weights.
  d$wt <- ifelse(d$ord == "High", 0.25, 1.9)
  d$wt <- d$wt / mean(d$wt)
  d
}

.cd_disc_config <- function(outcome, type) {
  list(outcome_var = outcome, outcome_type = type, outcome_label = outcome,
       confidence_level = 0.95, multinomial_mode = "baseline_category",
       outcome_order = if (type == "ordinal") c("Low", "Mid", "High") else NULL,
       driver_vars = c("driver_a", "driver_b"),
       # the settings a loaded config always carries
       min_sample_size = 30, rare_level_policy = "warn_only",
       rare_level_threshold = 10, rare_cell_threshold = 5,
       probability_lifts = FALSE, html_report = FALSE,
       driver_settings = data.frame(driver = c("driver_a", "driver_b"),
                                    type = "categorical",
                                    missing_strategy = "missing_as_level",
                                    stringsAsFactors = FALSE),
       variables = data.frame(VariableName = c("driver_a", "driver_b"),
                              Label = c("A", "B"), stringsAsFactors = FALSE))
}

# --------------------------------------------------------------------------- F18

test_that("the ordinal LR statistic is the weighted one, to the value", {
  skip_if_not_installed("ordinal")

  d <- .cd_disc_fixture()
  config <- .cd_disc_config("ord", "ordinal")
  w <- normalise_catdriver_weights(d$wt, "wt")$weights

  fit <- run_ordinal_logistic_robust(ord ~ driver_a + driver_b, d, w, config, guard_init())

  # Both nulls, fitted here from the definition.
  dd <- d
  dd$..w.. <- w
  full <- ordinal::clm(ord ~ driver_a + driver_b, data = dd, weights = ..w.., link = "logit")
  null_weighted <- ordinal::clm(ord ~ 1, data = dd, weights = ..w.., link = "logit")
  null_unweighted <- ordinal::clm(ord ~ 1, data = dd, link = "logit")

  lr_weighted <- -2 * (as.numeric(logLik(null_weighted)) - as.numeric(logLik(full)))
  lr_unweighted <- -2 * (as.numeric(logLik(null_unweighted)) - as.numeric(logLik(full)))

  # The two must be far enough apart that the assertion can tell them apart
  expect_gt(abs(lr_weighted - lr_unweighted), 1)
  expect_equal(fit$fit_statistics$lr_statistic, lr_weighted, tolerance = 1e-6)
  expect_false(isTRUE(all.equal(fit$fit_statistics$lr_statistic, lr_unweighted,
                                tolerance = 1e-3)))

  mcfadden_weighted <- 1 - as.numeric(logLik(full)) / as.numeric(logLik(null_weighted))
  expect_equal(fit$fit_statistics$mcfadden_r2, mcfadden_weighted, tolerance = 1e-6)
})

test_that("the multinomial LR statistic is the weighted one, to the value", {
  skip_if_not_installed("nnet")

  d <- .cd_disc_fixture()
  config <- .cd_disc_config("multi", "multinomial")
  w <- normalise_catdriver_weights(d$wt, "wt")$weights

  fit <- run_multinomial_logistic_robust(multi ~ driver_a + driver_b, d, w, config, guard_init())

  dd <- d
  dd$..w.. <- w
  full <- nnet::multinom(multi ~ driver_a + driver_b, data = dd, weights = ..w..,
                         trace = FALSE, maxit = 500)
  null_weighted <- nnet::multinom(multi ~ 1, data = dd, weights = ..w.., trace = FALSE)
  null_unweighted <- nnet::multinom(multi ~ 1, data = dd, trace = FALSE)

  lr_weighted <- -2 * (as.numeric(logLik(null_weighted)) - as.numeric(logLik(full)))
  lr_unweighted <- -2 * (as.numeric(logLik(null_unweighted)) - as.numeric(logLik(full)))

  expect_gt(abs(lr_weighted - lr_unweighted), 1)
  expect_equal(fit$fit_statistics$lr_statistic, lr_weighted, tolerance = 1e-4)
  expect_false(isTRUE(all.equal(fit$fit_statistics$lr_statistic, lr_unweighted,
                                tolerance = 1e-3)))
})

# --------------------------------------------------------------------------- F20

test_that("weighted multinomial importance equals the weighted LR for every driver", {
  skip_if_not_installed("nnet")

  d <- .cd_disc_fixture()
  config <- .cd_disc_config("multi", "multinomial")
  w <- normalise_catdriver_weights(d$wt, "wt")$weights

  fit <- run_multinomial_logistic_robust(multi ~ driver_a + driver_b, d, w, config, guard_init())
  imp <- calculate_multinomial_importance(fit, config)

  dd <- d
  dd$..w.. <- w
  full <- nnet::multinom(multi ~ driver_a + driver_b, data = dd, weights = ..w..,
                         trace = FALSE, maxit = 500)

  for (driver in config$driver_vars) {
    others <- setdiff(config$driver_vars, driver)
    reduced_formula <- as.formula(paste("multi ~", if (length(others)) paste(others, collapse = " + ") else "1"))
    reduced_w <- nnet::multinom(reduced_formula, data = dd, weights = ..w..,
                                trace = FALSE, maxit = 500)
    reduced_u <- nnet::multinom(reduced_formula, data = dd, trace = FALSE, maxit = 500)

    lr_w <- -2 * (as.numeric(logLik(reduced_w)) - as.numeric(logLik(full)))
    lr_u <- -2 * (as.numeric(logLik(reduced_u)) - as.numeric(logLik(full)))
    got <- imp$chi_square[imp$variable == driver]

    expect_equal(got, lr_w, tolerance = 1e-3, info = driver)
    # and it is not the unweighted statistic, which is what shipped before
    expect_gt(abs(lr_w - lr_u), 1)
    expect_false(isTRUE(all.equal(got, lr_u, tolerance = 1e-2)), info = driver)
  }
})

# --------------------------------------------------------------------------- F19

test_that("a resample that warns is kept, and the caveat counts it", {
  # Quasi-separation: a predictor that almost perfectly orders the outcome, with
  # a handful of cases the other side of the boundary. The fit converges and
  # warns about fitted probabilities of 0 or 1, which is the case M1 is about:
  # those resamples used to be discarded, narrowing the intervals exactly where
  # the bootstrap is worth running. Complete separation, by contrast, does not
  # converge and is discarded on purpose.
  set.seed(11)
  n <- 200
  d <- data.frame(x = rnorm(n))
  d$churn <- as.integer(d$x > 0)
  boundary <- order(abs(d$x))[seq_len(8)]
  d$churn[boundary] <- 1 - d$churn[boundary]
  d$churn <- factor(d$churn)

  one <- fit_model_for_bootstrap(d, churn ~ x, "binary", NULL)
  expect_equal(one$status, "ok")                 # converged
  expect_true("separation" %in% one$flags)       # and warned

  res <- run_bootstrap_or(d, churn ~ x, "binary", NULL, n_boot = 30, conf_level = 0.95)

  expect_false(is.null(res))
  kept_flagged <- sum(unlist(res$kept_flag_counts))
  expect_gt(kept_flagged, 0)
  expect_true(grepl("kept despite a warning", res$caveat))
  expect_true(grepl("separation", res$caveat))
  # a resample counts once however many warning classes it raised
  expect_true(kept_flagged <= res$n_successful)
  expect_equal(res$n_successful + res$n_discarded, res$n_boot)
})

# --------------------------------------------------------------------------- F21

test_that("a subgroup comparison that fails degrades the run and names itself", {
  skip_if_not_installed("openxlsx")
  skip_if(!exists("run_catdriver_subgroup_analysis", mode = "function"),
          "subgroup orchestrator not loaded")

  # The handover asked for this and it was never written: the comparison's
  # failure handler was only ever exercised by hand.
  original <- get("build_subgroup_comparison", envir = globalenv())
  assign("build_subgroup_comparison",
         function(...) stop("injected comparison failure"), envir = globalenv())
  on.exit(assign("build_subgroup_comparison", original, envir = globalenv()), add = TRUE)

  d <- .cd_disc_fixture(n = 400)
  d$churn <- factor(as.integer(d$ord == "High"))
  d$region <- factor(rep(c("North", "South"), length.out = nrow(d)))
  config <- .cd_disc_config("churn", "binary")
  config$subgroup_var <- "region"
  config$subgroup_include_total <- TRUE
  config$subgroup_min_n <- 10

  out <- utils::capture.output(
    res <- run_catdriver_subgroup_analysis(d, config, guard_init(), function(...) NULL,
                                           character(0), character(0))
  )

  expect_null(res$subgroup_comparison)
  expect_true(any(grepl("Subgroup comparison could not be built", res$degraded_reasons)),
              info = paste(res$degraded_reasons, collapse = " | "))
  expect_true(any(grepl("injected comparison failure", res$degraded_reasons)))
  expect_true(any(grepl("TURAS ERROR", out)))
})

test_that("a bootstrap that was requested and produced nothing degrades the run", {
  skip_if(!exists("run_catdriver_steps_4_to_10", mode = "function"),
          "pipeline helper not loaded")

  original <- get("run_bootstrap_or", envir = globalenv())
  assign("run_bootstrap_or", function(...) NULL, envir = globalenv())
  on.exit(assign("run_bootstrap_or", original, envir = globalenv()), add = TRUE)

  d <- .cd_disc_fixture(n = 300)
  d$churn <- factor(as.integer(d$ord == "High"))
  config <- .cd_disc_config("churn", "binary")
  config$bootstrap_ci <- TRUE
  config$bootstrap_reps <- 20

  out <- utils::capture.output(
    res <- run_catdriver_steps_4_to_10(d, config, guard_init(), function(...) NULL,
                                       group_label = "", verbose = FALSE)
  )

  expect_null(res$bootstrap_results)
  expect_equal(res$status, "PARTIAL")
  expect_true(any(grepl("Bootstrap confidence intervals were requested", res$degraded_reasons)),
              info = paste(res$degraded_reasons, collapse = " | "))
})

test_that("a multinomial bootstrap request is not silently ignored", {
  skip_if_not_installed("nnet")
  skip_if(!exists("run_catdriver_steps_4_to_10", mode = "function"),
          "pipeline helper not loaded")

  d <- .cd_disc_fixture(n = 300)
  config <- .cd_disc_config("multi", "multinomial")
  config$bootstrap_ci <- TRUE

  out <- utils::capture.output(
    res <- run_catdriver_steps_4_to_10(d, config, guard_init(), function(...) NULL,
                                       group_label = "", verbose = FALSE)
  )

  expect_true(any(grepl("not implemented for multinomial", res$degraded_reasons)),
              info = paste(res$degraded_reasons, collapse = " | "))
  expect_equal(res$status, "PARTIAL")
})

test_that("a stability flag alone does not kill the run", {
  skip_if(!exists("run_catdriver_steps_4_to_10", mode = "function"),
          "pipeline helper not loaded")

  # The shared run state refuses a PARTIAL that names no affected output, and a
  # stability flag was recorded as a degraded reason with nothing beside it. It
  # stayed latent until the events-per-parameter gate started counting fitted
  # parameters and began firing on designs it had been passing; then an ordinary
  # multinomial run died with "TRS: PARTIAL status requires at least one
  # affected_output" and produced no workbook at all.
  set.seed(4242)
  n <- 160
  d <- data.frame(
    driver_a = factor(sample(c("a", "b", "c", "d"), n, TRUE)),
    driver_b = factor(sample(c("x", "y", "z"), n, TRUE))
  )
  d$multi <- factor(sample(c("A", "B", "C"), n, TRUE))
  config <- .cd_disc_config("multi", "multinomial")

  out <- utils::capture.output(
    res <- run_catdriver_steps_4_to_10(d, config, guard_init(), function(...) NULL,
                                       group_label = "", verbose = FALSE)
  )

  expect_equal(res$status, "PARTIAL")
  expect_true(length(res$degraded_reasons) > 0)
  # every PARTIAL names something it affects
  expect_true(length(res$affected_outputs) > 0)
})
