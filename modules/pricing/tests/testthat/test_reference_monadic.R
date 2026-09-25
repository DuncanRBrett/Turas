# ==============================================================================
# TURAS PRICING - MONADIC REFERENCE CHECKS (robustness gate 1)
# ==============================================================================
#
# The monadic model against stats::glm fitted in the test, the cell intents
# against a hand weighted mean, and the optimum against stats::optimize on the
# fitted revenue function. The engine's own earlier output is never the
# reference.
# ==============================================================================

quiet <- function(expr) { capture.output(r <- expr); r }

ref_mon_cfg <- function(weight_var = NA_character_, model_type = "logistic",
                        unit_cost = NA_real_, points = 100) {
  list(weight_var = weight_var, unit_cost = unit_cost, currency_symbol = "R",
       monadic = list(price_column = "price", intent_column = "buy",
                      intent_type = "binary", model_type = model_type,
                      prediction_points = points, confidence_intervals = FALSE))
}

# 240 respondents over six cells, true model logit(p) = 3 - 0.05 * price.
ref_mon_data <- function(seed = 7) {
  set.seed(seed)
  n <- 240
  price <- rep(c(20, 30, 40, 50, 60, 70), each = n / 6)
  buy <- rbinom(n, 1, plogis(3 - 0.05 * price))
  data.frame(id = 1:n, price = price, buy = buy,
             w = round(runif(n, 0.3, 2.5), 3))
}

test_that("unweighted: coefficients, p-value, pseudo-R2 and AIC equal glm", {
  d <- ref_mon_data()
  r <- quiet(run_monadic_analysis(d, ref_mon_cfg()))
  g <- glm(buy ~ price, family = binomial, data = d)
  cf <- summary(g)$coefficients
  expect_equal(unname(r$model_summary$coefficients[, 1]), unname(cf[, 1]), tolerance = 1e-8)
  expect_equal(r$model_summary$price_coefficient_p, cf[2, 4], tolerance = 1e-8)
  expect_equal(r$model_summary$pseudo_r2, 1 - g$deviance / g$null.deviance, tolerance = 1e-10)
  expect_equal(r$model_summary$aic, AIC(g), tolerance = 1e-8)
})

test_that("weighted: coefficients equal glm with the raw weights, p-value glm at mean-1 weights", {
  d <- ref_mon_data()
  r <- quiet(run_monadic_analysis(d, ref_mon_cfg("w")))
  # Rescaling frequency weights leaves the point estimates unchanged...
  g_raw <- suppressWarnings(glm(buy ~ price, family = binomial, data = d, weights = w))
  expect_equal(unname(r$model_summary$coefficients[, 1]), unname(coef(g_raw)), tolerance = 1e-7)
  # ...but not the standard errors, so the p-value is the one at mean-1 weights.
  d$w1 <- d$w / mean(d$w)
  g1 <- suppressWarnings(glm(buy ~ price, family = binomial, data = d, weights = w1))
  expect_equal(r$model_summary$price_coefficient_p, summary(g1)$coefficients[2, 4], tolerance = 1e-8)
  # And survey::svyglm agrees on the point estimates (design-based).
  des <- survey::svydesign(ids = ~1, weights = ~w, data = d)
  sg <- suppressWarnings(survey::svyglm(buy ~ price, design = des, family = quasibinomial))
  expect_equal(unname(r$model_summary$coefficients[, 1]), unname(coef(sg)), tolerance = 1e-6)
})

test_that("cell intents are the weighted share buying in each cell", {
  d <- ref_mon_data()
  r <- quiet(run_monadic_analysis(d, ref_mon_cfg("w")))
  hand <- vapply(split(d, d$price), function(s) sum(s$w * s$buy) / sum(s$w), numeric(1))
  expect_equal(r$observed_data$price, c(20, 30, 40, 50, 60, 70))
  expect_equal(r$observed_data$observed_intent, unname(hand), tolerance = 1e-12)
  expect_equal(r$observed_data$n, rep(40, 6))
})

test_that("the revenue optimum is within one grid step of the continuous optimum", {
  d <- ref_mon_data()
  r <- quiet(run_monadic_analysis(d, ref_mon_cfg()))
  g <- glm(buy ~ price, family = binomial, data = d)
  a <- coef(g)[1]; b <- coef(g)[2]
  rev_fn <- function(p) p * plogis(a + b * p)
  opt <- optimize(rev_fn, c(20, 70), maximum = TRUE)$maximum
  step <- (70 - 20) / 99
  expect_lte(abs(r$optimal_price$price - opt), step)
  expect_equal(unname(r$optimal_price$predicted_intent), unname(plogis(a + b * r$optimal_price$price)), tolerance = 1e-10)
  # The grid answer is the best grid point, not merely a nearby one.
  grid <- seq(20, 70, length.out = 100)
  expect_equal(r$optimal_price$price, grid[which.max(rev_fn(grid))])
})

test_that("the profit optimum is within one grid step of the continuous profit optimum", {
  d <- ref_mon_data()
  r <- quiet(run_monadic_analysis(d, ref_mon_cfg(unit_cost = 15)))
  g <- glm(buy ~ price, family = binomial, data = d)
  a <- coef(g)[1]; b <- coef(g)[2]
  opt <- optimize(function(p) (p - 15) * plogis(a + b * p), c(20, 70), maximum = TRUE)$maximum
  expect_lte(abs(r$optimal_price_profit$price - opt), (70 - 20) / 99)
  expect_gt(r$optimal_price_profit$price, r$optimal_price$price)
})

test_that("the log-logistic model equals glm on log(price)", {
  d <- ref_mon_data()
  r <- quiet(run_monadic_analysis(d, ref_mon_cfg(model_type = "log_logistic")))
  g <- glm(buy ~ log(price), family = binomial, data = d)
  expect_equal(unname(r$model_summary$coefficients[, 1]), unname(coef(g)), tolerance = 1e-8)
  p30 <- r$demand_curve$predicted_intent[which.min(abs(r$demand_curve$price - 30))]
  p_at <- r$demand_curve$price[which.min(abs(r$demand_curve$price - 30))]
  expect_equal(p30, unname(plogis(coef(g)[1] + coef(g)[2] * log(p_at))), tolerance = 1e-10)
})
