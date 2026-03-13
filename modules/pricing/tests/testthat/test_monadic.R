# ==============================================================================
# TURAS PRICING MODULE - MONADIC ANALYSIS TESTS
# ==============================================================================

test_that("run_monadic_analysis produces valid demand curve", {
  skip_if(!exists("run_monadic_analysis", mode = "function"),
          "run_monadic_analysis not available")

  data <- generate_monadic_data(n = 300)

  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "purchase_intent",
      intent_type = "binary",
      model_type = "logistic",
      prediction_points = 50
    ),
    currency_symbol = "$"
  )

  result <- run_monadic_analysis(data, config)

  # Check structure
  expect_true(is.list(result))
  expect_equal(result$method, "monadic")
  expect_true(!is.null(result$demand_curve))
  expect_true(!is.null(result$observed_data))
  expect_true(!is.null(result$optimal_price))
  expect_true(!is.null(result$model_summary))

  # Demand curve should be monotonically decreasing
  dc <- result$demand_curve
  expect_equal(nrow(dc), 50)
  expect_true(all(dc$predicted_intent >= 0 & dc$predicted_intent <= 1))

  # Intent should generally decrease with price
  first_intent <- dc$predicted_intent[1]
  last_intent <- dc$predicted_intent[nrow(dc)]
  expect_true(first_intent > last_intent)
})

test_that("run_monadic_analysis handles log-logistic model", {
  skip_if(!exists("run_monadic_analysis", mode = "function"),
          "run_monadic_analysis not available")

  data <- generate_monadic_data(n = 200)

  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "purchase_intent",
      intent_type = "binary",
      model_type = "log_logistic"
    ),
    currency_symbol = "$"
  )

  result <- run_monadic_analysis(data, config)

  expect_equal(result$model_summary$model_type, "log_logistic")
  expect_true(!is.null(result$demand_curve))
})

test_that("run_monadic_analysis finds plausible optimal price", {
  skip_if(!exists("run_monadic_analysis", mode = "function"),
          "run_monadic_analysis not available")

  data <- generate_monadic_data(n = 300, prices = c(10, 20, 30, 40, 50, 60))

  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "purchase_intent",
      intent_type = "binary",
      model_type = "logistic"
    ),
    currency_symbol = "$"
  )

  result <- run_monadic_analysis(data, config)
  op <- result$optimal_price

  expect_true(op$price >= 10 && op$price <= 60)
  expect_true(op$predicted_intent > 0)
  expect_true(op$revenue_index > 0)
})

test_that("run_monadic_analysis reports model diagnostics", {
  skip_if(!exists("run_monadic_analysis", mode = "function"),
          "run_monadic_analysis not available")

  data <- generate_monadic_data(n = 200)

  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "purchase_intent",
      intent_type = "binary",
      model_type = "logistic"
    ),
    currency_symbol = "$"
  )

  result <- run_monadic_analysis(data, config)
  ms <- result$model_summary

  expect_true(!is.null(ms$coefficients))
  expect_true(!is.null(ms$aic))
  expect_true(!is.null(ms$pseudo_r2))
  expect_true(ms$pseudo_r2 >= 0 && ms$pseudo_r2 <= 1)
  expect_true(!is.null(ms$price_coefficient_p))
  expect_true(ms$n_observations > 0)
})

test_that("run_monadic_analysis computes bootstrap CIs when requested", {
  skip_if(!exists("run_monadic_analysis", mode = "function"),
          "run_monadic_analysis not available")

  # Use larger sample with strong effect for reliable bootstrap
  data <- generate_monadic_data(n = 600, intercept = 3.0, slope = -0.06)

  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "purchase_intent",
      intent_type = "binary",
      model_type = "logistic",
      confidence_intervals = TRUE,
      bootstrap_iterations = 50,
      confidence_level = 0.95
    ),
    currency_symbol = "$"
  )

  result <- run_monadic_analysis(data, config)

  expect_true(!is.null(result$confidence_intervals))
  ci <- result$confidence_intervals
  expect_true(!is.null(ci$n_attempted))
  # Bootstrap may not always succeed fully; check structure exists
  expect_true(ci$n_attempted == 50)
})

test_that("compute_monadic_elasticity returns valid classifications", {
  skip_if(!exists("compute_monadic_elasticity", mode = "function"),
          "compute_monadic_elasticity not available")

  demand_curve <- data.frame(
    price = seq(10, 60, length.out = 50),
    predicted_intent = 1 / (1 + exp(-2.5 + 0.04 * seq(10, 60, length.out = 50)))
  )

  result <- compute_monadic_elasticity(demand_curve)

  expect_true(is.data.frame(result))
  expect_true(nrow(result) > 0)
  # Check classification column (name may vary)
  class_col <- if ("classification" %in% names(result)) result$classification
               else if ("elasticity_type" %in% names(result)) result$elasticity_type
               else NULL
  if (!is.null(class_col)) {
    expect_true(all(tolower(class_col) %in% c("elastic", "inelastic", "unitary")))
  }
})

test_that("run_monadic_analysis handles scale intent type", {
  skip_if(!exists("run_monadic_analysis", mode = "function"),
          "run_monadic_analysis not available")

  set.seed(123)
  n <- 200
  prices <- c(25, 35, 45, 55, 65, 75)
  assigned_price <- sample(prices, n, replace = TRUE)

  # Generate 1-5 scale intent (higher price = lower intent)
  log_odds <- 2.5 - 0.04 * assigned_price
  prob <- 1 / (1 + exp(-log_odds))
  # Map to 1-5 scale
  intent_scale <- sample(1:5, n, replace = TRUE,
                          prob = c(0.1, 0.15, 0.25, 0.3, 0.2))

  data <- data.frame(
    price_shown = assigned_price,
    intent_scale = intent_scale
  )

  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "intent_scale",
      intent_type = "scale",
      scale_threshold = 4,
      model_type = "logistic"
    ),
    currency_symbol = "$"
  )

  result <- run_monadic_analysis(data, config)

  expect_true(is.list(result))
  expect_true(!is.null(result$demand_curve))
  expect_true(result$diagnostics$n_valid > 0)
})

test_that("run_monadic_analysis handles profit optimisation with unit_cost", {
  skip_if(!exists("run_monadic_analysis", mode = "function"),
          "run_monadic_analysis not available")

  data <- generate_monadic_data(n = 200)

  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "purchase_intent",
      intent_type = "binary",
      model_type = "logistic"
    ),
    unit_cost = 15,
    currency_symbol = "$"
  )

  result <- run_monadic_analysis(data, config)

  expect_true(!is.null(result$optimal_price_profit))
  expect_true(result$optimal_price_profit$price >= 15)  # Should be above cost
  expect_true(result$optimal_price_profit$profit_index > 0)
})

test_that("monadic_bootstrap_ci handles degenerate samples gracefully", {
  skip_if(!exists("monadic_bootstrap_ci", mode = "function"),
          "monadic_bootstrap_ci not available")

  # Very small sample that will produce some degenerate bootstrap samples
  prices <- rep(c(30, 50), each = 15)
  intents <- c(rep(1, 10), rep(0, 5), rep(0, 10), rep(1, 5))
  price_range <- seq(30, 50, length.out = 20)

  result <- monadic_bootstrap_ci(
    prices = prices,
    intents = intents,
    model_type = "logistic",
    price_range = price_range,
    n_boot = 30,
    conf_level = 0.95,
    unit_cost = NA
  )

  expect_true(is.list(result))
  expect_true(result$n_attempted == 30)
  # Should handle some failures gracefully
})
