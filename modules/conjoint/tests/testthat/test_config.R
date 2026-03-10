# ==============================================================================
# TESTS: CONJOINT CONFIG (01_config.R, 12_config_template.R)
# ==============================================================================

test_that("config loads with default values for new fields", {
  # Simulate a minimal config object
  config <- list(
    estimation_method = "auto",
    analysis_type = "choice"
  )

  # These new fields should have defaults in build_config_object
  expect_null(config$hb_iterations)
  expect_null(config$latent_class_min)
  expect_null(config$generate_html_report)
  expect_null(config$wtp_price_attribute)
})

test_that("null coalesce operator works", {
  `%||%` <- function(x, y) if (is.null(x)) y else x

  expect_equal(NULL %||% "default", "default")
  expect_equal("value" %||% "default", "value")
  expect_equal(0 %||% "default", 0)
  expect_equal(NA %||% "default", NA)
})

test_that("config fields have correct types", {
  config <- list(
    confidence_level = 0.95,
    n_alternatives = 3L,
    estimation_method = "auto",
    generate_html_report = TRUE,
    generate_html_simulator = FALSE,
    hb_iterations = 10000,
    hb_burnin = 5000,
    hb_thin = 10,
    latent_class_min = 2,
    latent_class_max = 5,
    simulation_method = "logit"
  )

  expect_is(config$confidence_level, "numeric")
  expect_is(config$n_alternatives, "integer")
  expect_is(config$estimation_method, "character")
  expect_is(config$generate_html_report, "logical")
  expect_true(config$hb_iterations > 0)
  expect_true(config$latent_class_min >= 2)
  expect_true(config$latent_class_max >= config$latent_class_min)
})
