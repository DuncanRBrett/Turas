# ==============================================================================
# TURAS PRICING MODULE - TEST SETUP
# ==============================================================================
#
# Purpose: Set up test environment, source module files, provide test utilities
# ==============================================================================

# Find Turas root
find_turas_root <- function() {
  # Check from this file's location
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) {
      return(dir)
    }
    parent <- dirname(dir)
    if (parent == dir) break
    dir <- parent
  }
  # Fallback: assume tests are run from project root
  getwd()
}

TURAS_ROOT <- find_turas_root()

# Source shared utilities
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in list.files(shared_lib, pattern = "[.]R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }
}

# Source pricing module files (all R files in order)
pricing_r_dir <- file.path(TURAS_ROOT, "modules", "pricing", "R")
if (dir.exists(pricing_r_dir)) {
  pricing_files <- sort(list.files(pricing_r_dir, pattern = "[.]R$", full.names = TRUE))
  for (fpath in pricing_files) {
    tryCatch(source(fpath), error = function(e) {
      message(sprintf("Could not source %s: %s", basename(fpath), e$message))
    })
  }
}

# Source HTML report modules
html_report_dir <- file.path(TURAS_ROOT, "modules", "pricing", "lib", "html_report")
if (dir.exists(html_report_dir)) {
  for (f in list.files(html_report_dir, pattern = "[.]R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }
}

# Source simulator builder
sim_builder <- file.path(TURAS_ROOT, "modules", "pricing", "lib", "simulator", "simulator_builder.R")
if (file.exists(sim_builder)) {
  tryCatch(source(sim_builder), error = function(e) NULL)
}

# Null-coalescing operator
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

# ==============================================================================
# SYNTHETIC DATA GENERATORS
# ==============================================================================

#' Generate Synthetic VW Data
#'
#' Creates realistic Van Westendorp survey data with four price columns
#' @param n Number of respondents
#' @param base_price Central price around which responses cluster
#' @param spread Price spread multiplier
#' @param include_nms Whether to include NMS purchase intent columns
#' @return Data frame
generate_vw_data <- function(n = 200, base_price = 50, spread = 0.3,
                              include_nms = FALSE) {
  set.seed(42)

  # Generate price perceptions with logical ordering:
  # too_cheap < cheap < expensive < too_expensive
  too_cheap <- base_price * runif(n, 0.3, 0.7)
  cheap <- base_price * runif(n, 0.6, 0.9)
  expensive <- base_price * runif(n, 1.0, 1.5)
  too_expensive <- base_price * runif(n, 1.3, 2.0)

  # Ensure monotonicity for most respondents
  for (i in seq_len(n)) {
    vals <- sort(c(too_cheap[i], cheap[i], expensive[i], too_expensive[i]))
    too_cheap[i] <- vals[1]
    cheap[i] <- vals[2]
    expensive[i] <- vals[3]
    too_expensive[i] <- vals[4]
  }

  # Introduce some violations (~10%)
  n_violate <- floor(n * 0.10)
  if (n_violate > 0) {
    idx <- sample(n, n_violate)
    temp <- cheap[idx]
    cheap[idx] <- expensive[idx]
    expensive[idx] <- temp
  }

  df <- data.frame(
    respondent_id = seq_len(n),
    too_cheap = round(too_cheap, 2),
    cheap = round(cheap, 2),
    expensive = round(expensive, 2),
    too_expensive = round(too_expensive, 2),
    stringsAsFactors = FALSE
  )

  if (include_nms) {
    # Generate purchase intent on 1-5 scale, correlated with price perception
    df$purchase_intent <- sample(1:5, n, replace = TRUE, prob = c(0.1, 0.15, 0.25, 0.3, 0.2))
  }

  df
}


#' Generate Synthetic GG Data (Wide Format)
#'
#' @param n Number of respondents
#' @param prices Vector of price points
#' @param base_intent Base purchase intent at lowest price
#' @return Data frame in wide format
generate_gg_data_wide <- function(n = 200,
                                   prices = c(20, 30, 40, 50, 60, 70, 80),
                                   base_intent = 0.85) {
  set.seed(42)

  df <- data.frame(respondent_id = seq_len(n))

  # Generate binary purchase intent at each price
  # Intent decreases as price increases
  for (p in prices) {
    price_effect <- (p - min(prices)) / (max(prices) - min(prices))
    prob <- base_intent * (1 - price_effect * 0.7)  # drops to ~25% at max price
    col_name <- paste0("price_", p)
    df[[col_name]] <- rbinom(n, 1, prob)
  }

  df
}


#' Generate Synthetic Monadic Data
#'
#' @param n Number of respondents
#' @param prices Vector of price cells
#' @param intercept Logistic intercept
#' @param slope Logistic slope (negative for normal demand)
#' @return Data frame with price and intent columns
generate_monadic_data <- function(n = 300,
                                   prices = c(25, 35, 45, 55, 65, 75),
                                   intercept = 2.5,
                                   slope = -0.04) {
  set.seed(42)

  # Randomly assign each respondent to a price cell
  assigned_price <- sample(prices, n, replace = TRUE)

  # Generate binary intent from logistic model
  log_odds <- intercept + slope * assigned_price
  prob <- 1 / (1 + exp(-log_odds))
  intent <- rbinom(n, 1, prob)

  data.frame(
    respondent_id = seq_len(n),
    price_shown = assigned_price,
    purchase_intent = intent,
    stringsAsFactors = FALSE
  )
}


#' Generate Segmented Data
#'
#' @param n Total respondents
#' @param n_segments Number of segments
#' @return Data frame with segment column
generate_segmented_data <- function(n = 300, n_segments = 3) {
  set.seed(42)

  seg_names <- c("Price Sensitive", "Mainstream", "Premium")[1:n_segments]
  segment <- sample(seg_names, n, replace = TRUE)

  data.frame(
    respondent_id = seq_len(n),
    segment = segment,
    stringsAsFactors = FALSE
  )
}
