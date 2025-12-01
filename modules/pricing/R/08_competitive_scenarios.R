# ==============================================================================
# TURAS PRICING MODULE - COMPETITIVE PRICING SCENARIOS
# ==============================================================================
#
# Purpose: Simulate competitive market scenarios and price-based choice
# Version: 1.0.0
# Date: 2025-12-01
#
# ==============================================================================

#' Simulate Choice Given Prices
#'
#' Simulates consumer choice behavior based on WTP and competitive prices.
#' Uses a simple surplus-based choice rule: choose brand with max(WTP - Price).
#'
#' @param wtp_df WTP data frame from extract_wtp_vw() or extract_wtp_gg()
#' @param prices Named numeric vector of prices (e.g., c(our_brand = 40, compA = 42, compB = 38))
#' @param allow_no_purchase Logical; allow "no purchase" if all prices exceed WTP?
#' @param market_size Optional total market volume for scaling
#'
#' @return Data frame with columns: brand, share, total_weight, optionally volume
#'
#' @export
simulate_choice <- function(wtp_df, prices, allow_no_purchase = TRUE, market_size = NULL) {

  brand_names <- names(prices)
  if (is.null(brand_names) || any(brand_names == "")) {
    stop("prices must be a named numeric vector (e.g., c(brand_a = 40, brand_b = 45))",
         call. = FALSE)
  }

  # Expand: one row per respondent per brand
  n_resp <- nrow(wtp_df)
  n_brands <- length(prices)

  # Create respondent × brand matrix
  choice_data <- data.frame(
    id = rep(wtp_df$id, each = n_brands),
    brand = rep(brand_names, times = n_resp),
    wtp = rep(wtp_df$wtp, each = n_brands),
    weight = rep(wtp_df$weight, each = n_brands),
    price = rep(prices, times = n_resp),
    stringsAsFactors = FALSE
  )

  # Calculate surplus for each option
  choice_data$surplus <- choice_data$wtp - choice_data$price

  # For each respondent, choose brand with max surplus (if > 0)
  chosen <- do.call(rbind, lapply(split(choice_data, choice_data$id), function(resp_choices) {
    max_surplus <- max(resp_choices$surplus, na.rm = TRUE)
    if (allow_no_purchase && max_surplus <= 0) {
      # No purchase
      data.frame(
        id = resp_choices$id[1],
        brand = ".no_purchase",
        weight = resp_choices$weight[1],
        stringsAsFactors = FALSE
      )
    } else {
      # Choose brand with max surplus (break ties randomly)
      best <- resp_choices[resp_choices$surplus == max_surplus, ][1, ]
      data.frame(
        id = best$id,
        brand = best$brand,
        weight = best$weight,
        stringsAsFactors = FALSE
      )
    }
  }))

  # Aggregate to brand shares
  shares <- aggregate(weight ~ brand, data = chosen, sum)
  names(shares) <- c("brand", "total_weight")
  shares$share <- shares$total_weight / sum(shares$total_weight)

  # Add volume if market size specified
  if (!is.null(market_size) && is.finite(market_size)) {
    shares$volume <- shares$share * market_size
  }

  # Sort by share descending
  shares <- shares[order(-shares$share), ]
  rownames(shares) <- NULL

  return(shares)
}


#' Simulate Multiple Competitive Scenarios
#'
#' Runs choice simulation across multiple pricing scenarios.
#'
#' @param wtp_df WTP data frame
#' @param scenarios Data frame where each row is a scenario and columns are brand prices.
#'   Column names must be brand names.
#' @param scenario_names Optional vector of scenario names (defaults to S1, S2, ...)
#' @param allow_no_purchase Logical; allow no purchase option?
#' @param market_size Optional total market volume
#'
#' @return Data frame with columns: scenario, brand, price, share, optionally volume
#'
#' @export
simulate_scenarios <- function(wtp_df, scenarios, scenario_names = NULL,
                               allow_no_purchase = TRUE, market_size = NULL) {

  if (!is.data.frame(scenarios)) {
    stop("scenarios must be a data frame with brand names as columns", call. = FALSE)
  }

  n_scenarios <- nrow(scenarios)

  if (is.null(scenario_names)) {
    scenario_names <- paste0("S", seq_len(n_scenarios))
  } else if (length(scenario_names) != n_scenarios) {
    stop("Length of scenario_names must match number of scenarios", call. = FALSE)
  }

  # Run simulation for each scenario
  results <- lapply(seq_len(n_scenarios), function(i) {
    prices <- unlist(scenarios[i, ])
    names(prices) <- colnames(scenarios)

    sim <- simulate_choice(wtp_df, prices, allow_no_purchase, market_size)
    sim$scenario <- scenario_names[i]

    # Add prices to output
    sim$price <- prices[sim$brand]
    sim$price[sim$brand == ".no_purchase"] <- NA

    sim
  })

  # Combine all scenarios
  combined <- do.call(rbind, results)

  # Reorder columns
  col_order <- c("scenario", "brand", "price", "share", "total_weight")
  if ("volume" %in% names(combined)) col_order <- c(col_order, "volume")
  combined <- combined[, col_order]

  return(combined)
}


#' Create Price Response Curve
#'
#' Shows how share changes as your price varies while competitors hold constant.
#'
#' @param wtp_df WTP data frame
#' @param your_prices Numeric vector of prices to test for your brand
#' @param competitor_prices Named numeric vector of fixed competitor prices
#' @param your_brand_name Name for your brand (default: "Your Brand")
#' @param allow_no_purchase Logical; allow no purchase?
#'
#' @return Data frame with columns: your_price, your_share, competitor shares
#'
#' @export
price_response_curve <- function(wtp_df, your_prices, competitor_prices,
                                 your_brand_name = "Your Brand",
                                 allow_no_purchase = TRUE) {

  results <- lapply(your_prices, function(your_p) {
    # Combine your price with competitor prices
    all_prices <- c(your_p, competitor_prices)
    names(all_prices) <- c(your_brand_name, names(competitor_prices))

    # Simulate
    sim <- simulate_choice(wtp_df, all_prices, allow_no_purchase, market_size = NULL)

    # Extract your share
    your_row <- sim[sim$brand == your_brand_name, ]
    your_share <- if (nrow(your_row) > 0) your_row$share else 0

    data.frame(
      your_price = your_p,
      your_share = your_share,
      stringsAsFactors = FALSE
    )
  })

  combined <- do.call(rbind, results)
  return(combined)
}


#' Plot Competitive Scenario Results
#'
#' Visualizes share by scenario and brand.
#'
#' @param scenario_results Output from simulate_scenarios()
#' @param title Plot title
#'
#' @return ggplot object (if available), otherwise NULL with message
#'
#' @export
plot_scenario_shares <- function(scenario_results, title = "Market Share by Scenario") {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    message("ggplot2 package required. Install with: install.packages('ggplot2')")
    return(invisible(NULL))
  }

  # Filter out no-purchase for cleaner viz (optional)
  plot_data <- scenario_results[scenario_results$brand != ".no_purchase", ]

  p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = scenario, y = share, fill = brand)) +
    ggplot2::geom_col(position = "dodge") +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::labs(
      title = title,
      x = "Scenario",
      y = "Market Share",
      fill = "Brand"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(legend.position = "right")

  return(p)
}


#' Plot Price Response Curve
#'
#' Shows how your share responds to price changes.
#'
#' @param response_curve Output from price_response_curve()
#' @param title Plot title
#'
#' @return ggplot object (if available), otherwise NULL
#'
#' @export
plot_price_response <- function(response_curve, title = "Price-Share Response Curve") {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    message("ggplot2 package required")
    return(invisible(NULL))
  }

  p <- ggplot2::ggplot(response_curve, ggplot2::aes(x = your_price, y = your_share)) +
    ggplot2::geom_line(color = "steelblue", size = 1.2) +
    ggplot2::geom_point(color = "steelblue", size = 2.5) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::labs(
      title = title,
      x = "Your Price",
      y = "Your Market Share"
    ) +
    ggplot2::theme_minimal()

  return(p)
}
