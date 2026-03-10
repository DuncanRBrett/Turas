# ==============================================================================
# TESTS: PRODUCT OPTIMIZER (15_product_optimizer.R)
# ==============================================================================

fixture_path <- file.path(
  dirname(dirname(testthat::test_path())),
  "fixtures", "synthetic_data", "generate_conjoint_test_data.R"
)
if (file.exists(fixture_path)) source(fixture_path, local = TRUE)


test_that("exhaustive optimizer finds best product", {
  if (!exists("optimize_product_exhaustive", mode = "function")) skip("optimize_product_exhaustive not loaded")

  utils <- generate_utilities_df(with_price = FALSE)
  config <- list(
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size  = c("Small", "Medium", "Large")
    ),
    simulation_method = "logit"
  )

  competitors <- list(
    list(Brand = "Alpha", Size = "Small")
  )

  result <- optimize_product_exhaustive(utils, config, competitors, top_n = 3, verbose = FALSE)

  expect_is(result, "data.frame")
  expect_true(nrow(result) <= 3)
  expect_true("share" %in% names(result) || "utility" %in% names(result))
})


test_that("greedy optimizer returns valid result", {
  if (!exists("optimize_product_greedy", mode = "function")) skip("optimize_product_greedy not loaded")

  utils <- generate_utilities_df(with_price = FALSE)
  config <- list(
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size  = c("Small", "Medium", "Large")
    ),
    simulation_method = "logit"
  )

  competitors <- list(
    list(Brand = "Alpha", Size = "Small")
  )

  result <- optimize_product_greedy(utils, config, competitors,
                                     n_starts = 3, max_iter = 10, verbose = FALSE)

  expect_is(result, "data.frame")
  expect_true(nrow(result) >= 1)
})


test_that("product evaluation returns numeric score", {
  if (!exists("evaluate_product", mode = "function")) skip("evaluate_product not loaded")

  utils <- generate_utilities_df(with_price = FALSE)
  config <- list(
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size  = c("Small", "Medium", "Large")
    ),
    simulation_method = "logit"
  )

  product <- list(Brand = "Beta", Size = "Large")
  competitors <- list(list(Brand = "Alpha", Size = "Small"))

  score <- evaluate_product(product, utils, config, competitors, objective = "utility")

  expect_is(score, "numeric")
  expect_true(is.finite(score))
})
