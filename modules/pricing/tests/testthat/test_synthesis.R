# ==============================================================================
# TURAS PRICING MODULE - RECOMMENDATION SYNTHESIS TESTS
# ==============================================================================

# Helper: build mock VW results with all required fields
mock_vw_results <- function() {
  list(
    price_points = list(PMC = 20, OPP = 35, IDP = 45, PME = 70),
    acceptable_range = list(lower = 20, upper = 70, width = 50),
    optimal_range = list(lower = 35, upper = 45, width = 10),
    nms_results = list(revenue_optimal = 42, trial_optimal = 38),
    diagnostics = list(n_valid = 200, violation_rate = 0.05)
  )
}

mock_gg_results <- function() {
  list(
    optimal_price = list(price = 40, purchase_intent = 0.6, revenue_index = 24),
    demand_curve = data.frame(
      price = c(20, 30, 40, 50, 60),
      purchase_intent = c(0.9, 0.75, 0.6, 0.4, 0.2)
    ),
    elasticity = data.frame(
      price_from = c(20, 30, 40, 50),
      price_to = c(30, 40, 50, 60),
      arc_elasticity = c(-0.5, -0.8, -1.2, -2.0),
      elasticity_type = c("Inelastic", "Inelastic", "Elastic", "Elastic")
    ),
    diagnostics = list(n_respondents = 200, n_price_points = 5)
  )
}

mock_monadic_results <- function() {
  list(
    method = "monadic",
    optimal_price = list(price = 42, predicted_intent = 0.6, revenue_index = 25.2),
    demand_curve = data.frame(
      price = seq(20, 60, length.out = 30),
      predicted_intent = 1 / (1 + exp(-2.5 + 0.04 * seq(20, 60, length.out = 30)))
    ),
    model_summary = list(
      pseudo_r2 = 0.15,
      aic = 250.3,
      price_coefficient_p = 0.001,
      n_observations = 200
    ),
    diagnostics = list(n_valid = 200)
  )
}

test_that("synthesize_recommendation works with VW results only", {
  skip_if(!exists("synthesize_recommendation", mode = "function"),
          "synthesize_recommendation not available")

  result <- synthesize_recommendation(
    vw_results = mock_vw_results(),
    gg_results = NULL,
    config = list(currency_symbol = "$")
  )

  expect_true(is.list(result))
  expect_true(!is.null(result$recommendation))
  expect_true(result$recommendation$price > 0)
})

test_that("synthesize_recommendation works with GG results only", {
  skip_if(!exists("synthesize_recommendation", mode = "function"),
          "synthesize_recommendation not available")

  result <- synthesize_recommendation(
    vw_results = NULL,
    gg_results = mock_gg_results(),
    config = list(currency_symbol = "$")
  )

  expect_true(is.list(result))
  expect_true(!is.null(result$recommendation))
})

test_that("synthesize_recommendation works with monadic results only", {
  skip_if(!exists("synthesize_recommendation", mode = "function"),
          "synthesize_recommendation not available")

  result <- synthesize_recommendation(
    vw_results = NULL,
    gg_results = NULL,
    monadic_results = mock_monadic_results(),
    config = list(currency_symbol = "$")
  )

  expect_true(is.list(result))
  expect_true(!is.null(result$recommendation))
})

test_that("synthesize_recommendation combines VW and GG", {
  skip_if(!exists("synthesize_recommendation", mode = "function"),
          "synthesize_recommendation not available")

  result <- synthesize_recommendation(
    vw_results = mock_vw_results(),
    gg_results = mock_gg_results(),
    config = list(currency_symbol = "$")
  )

  expect_true(!is.null(result$recommendation))
  expect_true(!is.null(result$evidence_table))
})

test_that("assess_recommendation_confidence scores correctly", {
  skip_if(!exists("assess_recommendation_confidence", mode = "function"),
          "assess_recommendation_confidence not available")

  method_prices <- list(
    nms_revenue = list(price = 42, label = "NMS Revenue"),
    gg_optimal = list(price = 40, label = "GG Optimal")
  )

  vw_results <- mock_vw_results()
  gg_results <- list(diagnostics = list(n_respondents = 250))

  result <- assess_recommendation_confidence(
    method_prices = method_prices,
    recommended_price = 41,
    vw_results = vw_results,
    gg_results = gg_results
  )

  expect_true(!is.null(result$score))
  expect_true(result$score >= 0 && result$score <= 1)
  expect_true(result$level %in% c("HIGH", "MEDIUM", "LOW"))
})

test_that("assess_recommendation_confidence gives higher scores for agreement", {
  skip_if(!exists("assess_recommendation_confidence", mode = "function"),
          "assess_recommendation_confidence not available")

  high_agreement <- list(
    nms_revenue = list(price = 40, label = "NMS"),
    gg_optimal = list(price = 41, label = "GG")
  )

  low_agreement <- list(
    nms_revenue = list(price = 30, label = "NMS"),
    gg_optimal = list(price = 55, label = "GG")
  )

  vw_results <- mock_vw_results()

  high_result <- assess_recommendation_confidence(
    method_prices = high_agreement,
    recommended_price = 40,
    vw_results = vw_results,
    gg_results = list(diagnostics = list(n_respondents = 200))
  )

  low_result <- assess_recommendation_confidence(
    method_prices = low_agreement,
    recommended_price = 42,
    vw_results = vw_results,
    gg_results = list(diagnostics = list(n_respondents = 200))
  )

  expect_true(high_result$score >= low_result$score)
})

test_that("build_evidence_table includes all methods", {
  skip_if(!exists("build_evidence_table", mode = "function"),
          "build_evidence_table not available")

  method_prices <- list(
    nms_revenue = list(price = 42, label = "NMS Revenue Optimal",
                       description = "Revenue-maximizing price"),
    gg_optimal = list(price = 40, label = "GG Revenue Optimal",
                      description = "Gabor-Granger optimal")
  )

  vw_results <- mock_vw_results()

  result <- build_evidence_table(
    method_prices = method_prices,
    vw_results = vw_results,
    gg_results = NULL,
    recommended_price = 41,
    currency = "$"
  )

  expect_true(is.data.frame(result))
  expect_true(nrow(result) >= 2)
})

test_that("identify_pricing_risks returns categorized risks", {
  skip_if(!exists("identify_pricing_risks", mode = "function"),
          "identify_pricing_risks not available")

  vw_results <- mock_vw_results()
  gg_results <- mock_gg_results()
  confidence <- list(score = 0.75, level = "MEDIUM")

  result <- identify_pricing_risks(
    recommended_price = 45,
    vw_results = vw_results,
    gg_results = gg_results,
    confidence = confidence
  )

  expect_true(is.list(result))
})

test_that("round_to_psychological gives sensible results", {
  skip_if(!exists("round_to_psychological", mode = "function"),
          "round_to_psychological not available")

  expect_true(round_to_psychological(7.3) > 0)
  expect_true(round_to_psychological(42.5) > 0)
  expect_true(round_to_psychological(150) > 0)
})

test_that("synthesize_recommendation refuses with no inputs", {
  skip_if(!exists("synthesize_recommendation", mode = "function"),
          "synthesize_recommendation not available")

  expect_error(
    synthesize_recommendation(
      vw_results = NULL,
      gg_results = NULL,
      config = list(currency_symbol = "$")
    ),
    "DATA_NO_RESULTS|No Analysis"
  )
})

test_that("generate_executive_summary produces text output", {
  skip_if(!exists("generate_executive_summary", mode = "function"),
          "generate_executive_summary not available")

  result <- generate_executive_summary(
    recommended_price = 42,
    primary_source = "Van Westendorp OPP",
    confidence = list(score = 0.8, level = "HIGH", factors = list()),
    acceptable_range = list(lower = 30, upper = 55, lower_desc = "PMC floor", upper_desc = "PME ceiling"),
    optimal_zone = list(lower = 38, upper = 48),
    gg_results = NULL,
    monadic_results = NULL,
    segment_notes = NULL,
    tier_notes = NULL,
    risks = list(upside = list(), downside = list()),
    currency = "$",
    project_name = "Test Project"
  )

  expect_true(is.character(result))
  expect_true(nchar(result) > 50)
})
