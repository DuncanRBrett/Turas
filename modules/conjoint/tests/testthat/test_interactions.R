# ==============================================================================
# TESTS: INTERACTIONS (06_interactions.R)
# ==============================================================================

test_that("specify_interactions validates attribute names", {
  if (!exists("specify_interactions", mode = "function")) skip("specify_interactions not loaded")

  attrs <- c("Brand", "Price", "Size")

  # Valid specification
  spec <- specify_interactions(attrs, interactions = list(c("Brand", "Price")))
  expect_equal(spec$n_interactions, 1)
  expect_equal(spec$interactions[[1]], c("Brand", "Price"))

  # Invalid: attribute not in list
  expect_error(
    specify_interactions(attrs, interactions = list(c("Brand", "Missing"))),
    regexp = NULL
  )
})


test_that("specify_interactions auto-detects pairs", {
  if (!exists("specify_interactions", mode = "function")) skip("specify_interactions not loaded")

  attrs <- c("Brand", "Price", "Size")
  spec <- specify_interactions(attrs, interactions = list(), auto_detect = TRUE, max_interactions = 2)

  expect_true(spec$n_interactions >= 1)
  expect_true(spec$n_interactions <= 2)
})


test_that("parse_interactions_from_config handles comma-colon format", {
  if (!exists("parse_interactions_from_config", mode = "function")) skip("parse_interactions_from_config not loaded")

  config <- list(
    attributes = data.frame(
      AttributeName = c("Brand", "Price", "Size"),
      stringsAsFactors = FALSE
    ),
    interaction_terms = "Brand:Price, Size:Brand",
    interaction_auto_detect = FALSE,
    interaction_max = 3
  )

  spec <- parse_interactions_from_config(config)

  expect_is(spec, "conjoint_interactions")
  expect_equal(spec$n_interactions, 2)
  expect_equal(spec$interactions[[1]], c("Brand", "Price"))
  expect_equal(spec$interactions[[2]], c("Size", "Brand"))
})


test_that("parse_interactions_from_config returns NULL for empty config", {
  if (!exists("parse_interactions_from_config", mode = "function")) skip("parse_interactions_from_config not loaded")

  config <- list(
    attributes = data.frame(AttributeName = c("A", "B"), stringsAsFactors = FALSE),
    interaction_terms = ""
  )

  result <- parse_interactions_from_config(config)
  expect_null(result)

  config2 <- list(attributes = data.frame(AttributeName = c("A", "B"), stringsAsFactors = FALSE))
  result2 <- parse_interactions_from_config(config2)
  expect_null(result2)
})


test_that("build_formula_with_interactions includes interaction terms", {
  if (!exists("build_formula_with_interactions", mode = "function")) skip("build_formula_with_interactions not loaded")

  config <- list(
    attributes = data.frame(
      AttributeName = c("Brand", "Price", "Size"),
      stringsAsFactors = FALSE
    ),
    chosen_column = "chosen"
  )

  spec <- structure(
    list(
      attributes = c("Brand", "Price", "Size"),
      interactions = list(c("Brand", "Price")),
      n_interactions = 1
    ),
    class = "conjoint_interactions"
  )

  formula <- build_formula_with_interactions(config, spec)
  formula_str <- deparse(formula)

  expect_true(grepl("Brand", formula_str))
  expect_true(grepl("Price", formula_str))
  expect_true(grepl("Size", formula_str))
  expect_true(grepl("Brand:Price", formula_str))
})


test_that("format_interaction displays correctly", {
  if (!exists("format_interaction", mode = "function")) skip("format_interaction not loaded")

  result <- format_interaction(c("Brand", "Price"))
  expect_equal(result, "Brand \u00d7 Price")
})
