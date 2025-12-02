# ==============================================================================
# TURAS REGRESSION TEST: PRICING MODULE (WORKING MOCK)
# ==============================================================================

library(testthat)

# Source helpers (only if not already loaded)
if (!exists("check_numeric")) {
  source("tests/regression/helpers/assertion_helpers.R")
}
if (!exists("get_example_paths")) {
  source("tests/regression/helpers/path_helpers.R")
}

mock_pricing_module <- function(data_path, config_path = NULL) {
  data <- read.csv(data_path, stringsAsFactors = FALSE)

  # Price points and purchase rates
  price_points <- c(40, 50, 60, 70)
  purchase_rates <- c(
    mean(data$purchase_1),
    mean(data$purchase_2),
    mean(data$purchase_3),
    mean(data$purchase_4)
  ) * 100

  # Calculate price elasticity (simplified)
  # Elasticity = % change in quantity / % change in price
  elasticity_40_50 <- ((purchase_rates[2] - purchase_rates[1]) / purchase_rates[1]) /
                      ((price_points[2] - price_points[1]) / price_points[1])

  # Optimal price point (highest revenue)
  revenues <- price_points * (purchase_rates / 100) * nrow(data)
  optimal_price_idx <- which.max(revenues)
  optimal_price <- price_points[optimal_price_idx]
  optimal_revenue <- max(revenues)

  output <- list(
    price_analysis = list(
      price_points = price_points,
      purchase_rates = purchase_rates,
      revenues = revenues,
      optimal_price = optimal_price,
      optimal_revenue = optimal_revenue,
      elasticity = elasticity_40_50
    ),
    summary = list(
      purchase_rate_at_40 = purchase_rates[1],
      purchase_rate_at_50 = purchase_rates[2],
      purchase_rate_at_60 = purchase_rates[3],
      purchase_rate_at_70 = purchase_rates[4],
      optimal_price = optimal_price,
      optimal_revenue = optimal_revenue,
      price_elasticity = elasticity_40_50,
      n_respondents = nrow(data)
    )
  )

  return(output)
}

extract_pricing_value <- function(output, check_name) {
  if (check_name %in% names(output$summary)) {
    return(output$summary[[check_name]])
  }
  stop("Unknown check: ", check_name)
}

test_that("Pricing module: basic example produces expected outputs", {
  paths <- get_example_paths("pricing", "basic")
  output <- mock_pricing_module(paths$data)
  golden <- load_golden("pricing", "basic")

  for (check in golden$checks) {
    actual <- extract_pricing_value(output, check$name)

    if (check$type == "numeric") {
      tolerance <- if (!is.null(check$tolerance)) check$tolerance else 0.01
      check_numeric(paste("Pricing:", check$description), actual, check$value, tolerance)
    } else if (check$type == "integer") {
      check_integer(paste("Pricing:", check$description), actual, check$value)
    }
  }
})
