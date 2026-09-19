# ==============================================================================
# CATDRIVER - ENGINE MEDIUMS (M2, M3, M4)
# ==============================================================================
# M2. The "events per parameter" gate divided OBSERVATIONS by parameters. At 10
#     per cent prevalence that is about ten times too optimistic, and the true
#     minority-class count existed only as a binary-outcome validation warning,
#     never for ordinal or multinomial.
# M3. The clm path carried `proportional_odds = NULL # clm has built-in tests`
#     and ran no test, so the default engine's central assumption went unchecked
#     while the guard skipped silently on NULL.
# M4. Probability lift is a difference in mean fitted probability between two
#     groups of respondents, not a marginal effect, and for a multinomial
#     outcome it described the alphabetically last level without naming it.
# ==============================================================================

# ------------------------------------------------------------------------- M2

test_that("the events-per-parameter gate counts events, not respondents", {
  # 400 respondents, 40 of them in the minority class, 8 parameters.
  # Observations per parameter is 50 and passes; events per parameter is 5 and
  # does not. The old gate saw only the first number.
  outcome <- factor(c(rep("yes", 40), rep("no", 360)))

  guard <- guard_check_sample_size(guard_init(), n_obs = 400, n_params = 8,
                                   outcome_type = "binary", config = NULL,
                                   outcome_values = outcome)

  expect_true(any(grepl("Low events-per-parameter", guard$warnings)))
  expect_true(any(grepl("minority-class events", guard$warnings)))
  expect_true(any(grepl("5.0", guard$warnings)))

  # Without the outcome it falls back to observations, and says which basis it used
  fallback <- guard_check_sample_size(guard_init(), n_obs = 400, n_params = 8,
                                      outcome_type = "binary", config = NULL)
  expect_length(fallback$warnings, 0)   # 50 per parameter passes, as before
})

test_that("the gate reads the smallest category for ordinal and multinomial too", {
  outcome <- factor(c(rep("A", 300), rep("B", 150), rep("C", 30)))

  guard <- guard_check_sample_size(guard_init(), n_obs = 480, n_params = 6,
                                   outcome_type = "multinomial", config = NULL,
                                   outcome_values = outcome)
  expect_true(any(grepl("Low events-per-parameter", guard$warnings)))
  expect_true(any(grepl("30 minority-class events", guard$warnings)))

  # A healthy design raises nothing
  healthy <- factor(c(rep("A", 300), rep("B", 300), rep("C", 300)))
  quiet <- guard_check_sample_size(guard_init(), n_obs = 900, n_params = 6,
                                   outcome_type = "multinomial", config = NULL,
                                   outcome_values = healthy)
  expect_length(quiet$warnings, 0)
})

# ------------------------------------------------------------------------- M3

test_that("the clm path actually tests proportional odds", {
  skip_if_not_installed("ordinal")

  set.seed(12)
  n <- 500
  d <- data.frame(a = factor(sample(c("x", "y", "z"), n, TRUE)),
                  b = factor(sample(c("p", "q"), n, TRUE)))
  eta <- ifelse(d$a == "y", 1, 0) + ifelse(d$a == "z", -0.8, 0) + ifelse(d$b == "q", 0.6, 0)
  u <- eta + rlogis(n)
  d$y <- factor(ifelse(u > 1, "H", ifelse(u > -0.5, "M", "L")),
                levels = c("L", "M", "H"), ordered = TRUE)
  d$wt <- runif(n, 0.5, 2)
  d$wt <- d$wt / mean(d$wt)

  config <- list(outcome_var = "y", outcome_type = "ordinal", outcome_label = "y",
                 confidence_level = 0.95, driver_vars = c("a", "b"),
                 outcome_order = c("L", "M", "H"),
                 variables = data.frame(VariableName = c("a", "b"), Label = c("A", "B"),
                                        stringsAsFactors = FALSE))

  fit <- run_ordinal_logistic_robust(y ~ a + b, d, d$wt, config, guard_init())
  po <- fit$proportional_odds

  expect_false(is.null(po))                      # it used to be NULL, always
  expect_true(po$checked)
  expect_equal(po$method, "ordinal::nominal_test")
  expect_true(po$status %in% c("PASS", "WARNING"))
  expect_true(is.numeric(po$p_values) && length(po$p_values) >= 1)
  expect_true(nzchar(po$interpretation))

  # and the guard now has something to act on
  guard <- guard_check_proportional_odds(guard_init(), po)
  if (identical(po$status, "WARNING")) {
    expect_true(length(guard$warnings) > 0)
  } else {
    expect_length(guard$warnings, 0)
  }
})

test_that("a proportional-odds test that cannot run is disclosed, not silent", {
  skip_if_not_installed("ordinal")

  broken <- structure(list(), class = "clm")   # no model frame to refit from
  po <- test_proportional_odds_clm(broken)

  expect_false(po$checked)
  expect_equal(po$status, "NOT_TESTED")
  expect_true(grepl("NOT tested", po$interpretation))
  # the guard must not turn a test that never ran into a clean bill of health
  expect_length(guard_check_proportional_odds(guard_init(), po)$warnings, 0)
  expect_false(isTRUE(po$status == "PASS"))
})

# ------------------------------------------------------------------------- M4

test_that("the probability lift table names the outcome level it describes", {
  skip_if_not_installed("nnet")

  set.seed(21)
  n <- 400
  d <- data.frame(service = factor(sample(c("Poor", "Good"), n, TRUE)),
                  stringsAsFactors = FALSE)
  d$plan <- factor(sample(c("Basic", "Premium", "Standard"), n, TRUE))
  config <- list(outcome_var = "plan", outcome_type = "multinomial",
                 outcome_label = "Plan", confidence_level = 0.95,
                 multinomial_mode = "baseline_category",
                 driver_vars = "service",
                 variables = data.frame(VariableName = "service", Label = "Service",
                                        stringsAsFactors = FALSE))

  fit <- run_multinomial_logistic_robust(plan ~ service, d, NULL, config, guard_init())
  prep <- list(data = d, outcome_info = list(type = "multinomial", categories = levels(d$plan)))

  lift <- calculate_probability_lift(fit, prep, config)

  expect_false(is.null(lift))
  expect_true("outcome_level" %in% names(lift))
  expect_true(all(nzchar(lift$outcome_level)))
  # It is one named level of the outcome, not "the last column"
  expect_true(all(lift$outcome_level %in% levels(d$plan)))
})

test_that("the probability lift only crosses rows the model fitted", {
  set.seed(22)
  n <- 300
  d <- data.frame(service = factor(sample(c("Poor", "Good"), n, TRUE)),
                  price = factor(sample(c("Cheap", "Dear"), n, TRUE)))
  d$churn <- factor(as.integer(plogis(ifelse(d$service == "Good", 1.2, 0) + rlogis(n)) > 0.5))
  d$price[1:20] <- NA          # rows the fit drops

  config <- list(outcome_var = "churn", outcome_type = "binary", outcome_label = "Churn",
                 confidence_level = 0.95, driver_vars = c("service", "price"),
                 variables = data.frame(VariableName = c("service", "price"),
                                        Label = c("Service", "Price"),
                                        stringsAsFactors = FALSE))

  fit <- run_binary_logistic_robust(churn ~ service + price, d, NULL, config, guard_init())
  prep <- list(data = d, outcome_info = list(type = "binary", categories = levels(d$churn)))

  lift <- calculate_probability_lift(fit, prep, config)

  expect_false(is.null(lift))
  expect_true(all(is.finite(lift$mean_predicted_prob)))
  expect_true(all(lift$mean_predicted_prob >= 0 & lift$mean_predicted_prob <= 1))
})
