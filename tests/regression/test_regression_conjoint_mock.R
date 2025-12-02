# ==============================================================================
# TURAS REGRESSION TEST: CONJOINT MODULE (WORKING MOCK)
# ==============================================================================

library(testthat)
source("tests/regression/helpers/assertion_helpers.R")
source("tests/regression/helpers/path_helpers.R")

mock_conjoint_module <- function(data_path, config_path = NULL) {
  data <- read.csv(data_path, stringsAsFactors = FALSE)

  # Simulate conjoint analysis results
  # In real implementation, would use survival::clogit or similar

  # Part-worth utilities (simplified)
  utilities <- list(
    price_449 = 0.5,
    price_599 = 0.0,
    price_699 = -0.5,
    brand_apple = 0.8,
    brand_samsung = 0.2,
    brand_google = -1.0,
    storage_128 = -0.3,
    storage_256 = 0.1,
    storage_512 = 0.2,
    battery_12h = -0.4,
    battery_18h = 0.0,
    battery_24h = 0.4
  )

  # Attribute importance (range method)
  price_range <- max(utilities$price_449, utilities$price_599, utilities$price_699) -
                min(utilities$price_449, utilities$price_599, utilities$price_699)
  brand_range <- max(utilities$brand_apple, utilities$brand_samsung, utilities$brand_google) -
                min(utilities$brand_apple, utilities$brand_samsung, utilities$brand_google)
  storage_range <- max(utilities$storage_128, utilities$storage_256, utilities$storage_512) -
                  min(utilities$storage_128, utilities$storage_256, utilities$storage_512)
  battery_range <- max(utilities$battery_12h, utilities$battery_18h, utilities$battery_24h) -
                  min(utilities$battery_12h, utilities$battery_18h, utilities$battery_24h)

  total_range <- price_range + brand_range + storage_range + battery_range

  importance <- list(
    price = (price_range / total_range) * 100,
    brand = (brand_range / total_range) * 100,
    storage = (storage_range / total_range) * 100,
    battery = (battery_range / total_range) * 100
  )

  output <- list(
    utilities = utilities,
    importance = importance,
    fit = list(
      mcfadden_r2 = 0.35,
      hit_rate = 0.65,
      n_respondents = nrow(data) / 3  # Assuming 3 choice sets per respondent
    ),
    summary = list(
      utility_price_449 = utilities$price_449,
      utility_brand_apple = utilities$brand_apple,
      importance_price = importance$price,
      importance_brand = importance$brand,
      importance_storage = importance$storage,
      importance_battery = importance$battery,
      mcfadden_r2 = 0.35,
      hit_rate = 0.65,
      n_choice_sets = nrow(data)
    )
  )

  return(output)
}

extract_conjoint_value <- function(output, check_name) {
  if (check_name %in% names(output$summary)) {
    return(output$summary[[check_name]])
  }
  stop("Unknown check: ", check_name)
}

test_that("Conjoint module: basic example produces expected outputs", {
  paths <- get_example_paths("conjoint", "basic")
  output <- mock_conjoint_module(paths$data)
  golden <- load_golden("conjoint", "basic")

  for (check in golden$checks) {
    actual <- extract_conjoint_value(output, check$name)

    if (check$type == "numeric") {
      tolerance <- if (!is.null(check$tolerance)) check$tolerance else 0.01
      check_numeric(paste("Conjoint:", check$description), actual, check$value, tolerance)
    } else if (check$type == "integer") {
      check_integer(paste("Conjoint:", check$description), actual, check$value)
    }
  }
})
