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
    attributes = data.frame(
      AttributeName = c("Brand", "Size"),
      stringsAsFactors = FALSE
    )
  )
  config$attributes$levels_list <- list(
    c("Alpha", "Beta", "Gamma"),
    c("Small", "Medium", "Large")
  )

  competitors <- list(
    list(Brand = "Alpha", Size = "Small")
  )

  result <- optimize_product_exhaustive(utils, config, competitors,
                                         objective = "utility", top_n = 3, verbose = FALSE)

  expect_is(result, "list")
  expect_true("top_products" %in% names(result))
  expect_true("best_product" %in% names(result))
  expect_true(length(result$top_products) <= 3)
})


test_that("greedy optimizer returns valid result", {
  if (!exists("optimize_product_greedy", mode = "function")) skip("optimize_product_greedy not loaded")

  utils <- generate_utilities_df(with_price = FALSE)
  config <- list(
    attributes = data.frame(
      AttributeName = c("Brand", "Size"),
      stringsAsFactors = FALSE
    )
  )
  config$attributes$levels_list <- list(
    c("Alpha", "Beta", "Gamma"),
    c("Small", "Medium", "Large")
  )

  competitors <- list(
    list(Brand = "Alpha", Size = "Small")
  )

  result <- optimize_product_greedy(utils, config, competitors,
                                     objective = "utility",
                                     n_starts = 3, max_iterations = 10, verbose = FALSE)

  expect_is(result, "list")
  expect_true("best_product" %in% names(result))
  expect_true("best_score" %in% names(result))
  expect_true(is.finite(result$best_score))
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

  score <- evaluate_product(product, utils, competitors, objective = "utility",
                             price_attribute = NULL, cost_data = NULL,
                             model_result = NULL, config = NULL, method = "logit")

  expect_is(score, "numeric")
  expect_true(is.finite(score))
})
