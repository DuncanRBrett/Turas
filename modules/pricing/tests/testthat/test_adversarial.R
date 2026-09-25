# ==============================================================================
# TURAS PRICING - ADVERSARIAL CASES (robustness gate 3)
# ==============================================================================
#
# The hard inputs a real data file brings: prices read as text, segment
# columns with blanks, labels that start with a formula character, and so on.
# Each case either reproduces the reference answer or refuses by name.
# ==============================================================================

quiet <- function(expr) { capture.output(r <- suppressWarnings(expr)); r }

adv_mon_cfg <- function() {
  list(weight_var = NA_character_, unit_cost = NA_real_, currency_symbol = "R",
       monadic = list(price_column = "price", intent_column = "buy",
                      intent_type = "binary", model_type = "logistic",
                      prediction_points = 100, confidence_intervals = FALSE))
}

adv_mon_data <- function() {
  set.seed(7)
  price <- rep(c(20, 30, 40, 50, 60, 70), each = 40)
  data.frame(price = price, buy = rbinom(240, 1, plogis(3 - 0.05 * price)))
}

test_that("a monadic price column read as text gives the numeric answer", {
  # A CSV or an Excel column with one stray text cell arrives as character.
  # "20", "30"... must fit the same model as 20, 30...: glm on a character
  # predictor fits a factor, and the prediction step then died on
  # "variable 'prices' was fitted with type character".
  d <- adv_mon_data()
  num <- quiet(run_monadic_analysis(d, adv_mon_cfg()))
  d_txt <- d
  d_txt$price <- as.character(d$price)
  txt <- quiet(run_monadic_analysis(d_txt, adv_mon_cfg()))
  expect_equal(unname(txt$model_summary$coefficients[, 1]),
               unname(num$model_summary$coefficients[, 1]), tolerance = 1e-10)
  expect_equal(txt$optimal_price$price, num$optimal_price$price)
})

test_that("a monadic price that is not a number refuses by name", {
  d <- adv_mon_data()
  d$price <- paste0("R", d$price)
  err <- tryCatch(quiet(run_monadic_analysis(d, adv_mon_cfg())),
                  turas_refusal = function(e) e, error = function(e) e)
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_MONADIC_PRICE_NOT_NUMERIC")
  expect_match(err$problem, "R20")
})
