# ==============================================================================
# TURAS REGRESSION TEST: KEYDRIVER MODULE (WORKING MOCK)
# ==============================================================================

library(testthat)

# Source helpers (only if not already loaded)
if (!exists("check_numeric")) {
  source("tests/regression/helpers/assertion_helpers.R")
}
if (!exists("get_example_paths")) {
  source("tests/regression/helpers/path_helpers.R")
}

# ==============================================================================
# MOCK KEYDRIVER MODULE
# ==============================================================================

mock_keydriver_module <- function(data_path, config_path = NULL) {
  data <- read.csv(data_path, stringsAsFactors = FALSE)

  # Outcome variable
  outcome <- data$overall_satisfaction

  # Driver variables
  drivers <- c("product_quality", "customer_service", "value_for_money",
               "delivery_speed", "website_usability", "brand_reputation")

  # Correlation matrix
  cors <- sapply(drivers, function(d) cor(data[[d]], outcome))

  # Simple linear regression for relative importance
  formula_str <- paste("overall_satisfaction ~", paste(drivers, collapse = " + "))
  model <- lm(as.formula(formula_str), data = data)

  # R-squared
  r_squared <- summary(model)$r.squared
  adj_r_squared <- summary(model)$adj.r.squared

  # Beta weights (standardized coefficients)
  betas <- coef(model)[-1]  # Exclude intercept

  # Relative importance (simplified - use absolute beta weights)
  rel_importance <- abs(betas) / sum(abs(betas)) * 100

  # Rankings
  ranks <- rank(-rel_importance)

  # Top driver
  top_driver <- names(which.max(rel_importance))
  top_importance <- max(rel_importance)

  output <- list(
    correlations = cors,
    model_fit = list(
      r_squared = r_squared,
      adj_r_squared = adj_r_squared,
      n = nrow(data)
    ),
    importance = rel_importance,
    ranks = ranks,
    summary = list(
      r_squared = r_squared,
      adj_r_squared = adj_r_squared,
      top_driver = top_driver,
      top_driver_importance = top_importance,
      correlation_product_quality = cors["product_quality"],
      correlation_customer_service = cors["customer_service"],
      importance_product_quality = rel_importance["product_quality"],
      importance_customer_service = rel_importance["customer_service"],
      rank_product_quality = ranks["product_quality"],
      rank_customer_service = ranks["customer_service"],
      base_size = nrow(data)
    )
  )

  return(output)
}

extract_keydriver_value <- function(output, check_name) {
  if (check_name %in% names(output$summary)) {
    return(output$summary[[check_name]])
  }
  stop("Unknown check: ", check_name)
}

# ==============================================================================
# REGRESSION TEST
# ==============================================================================

test_that("KeyDriver module: basic example produces expected outputs", {
  paths <- get_example_paths("keydriver", "basic")
  output <- mock_keydriver_module(paths$data)
  golden <- load_golden("keydriver", "basic")

  for (check in golden$checks) {
    actual <- extract_keydriver_value(output, check$name)

    if (check$type == "numeric") {
      tolerance <- if (!is.null(check$tolerance)) check$tolerance else 0.01
      check_numeric(
        paste("KeyDriver basic:", check$description),
        actual, check$value, tolerance
      )
    } else if (check$type == "character" || check$type == "string") {
      check_string(
        paste("KeyDriver basic:", check$description),
        actual, check$value
      )
    } else if (check$type == "integer") {
      check_integer(
        paste("KeyDriver basic:", check$description),
        actual, check$value
      )
    }
  }
})
