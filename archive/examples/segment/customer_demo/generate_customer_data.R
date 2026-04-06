# ==============================================================================
# CUSTOMER SEGMENTATION DEMO - Synthetic Data Generator
# ==============================================================================
# Generates a realistic 1000-respondent customer dataset with 4 embedded
# segments: Budget Seekers, Premium Loyalists, Digital Natives, Convenience
# Shoppers. Includes 15 numeric + 4 demographic variables with realistic
# noise, 5% MCAR missingness, and ~2% outlier contamination.
#
# Usage:
#   source("generate_customer_data.R")
#   data <- generate_customer_data(n = 1000, seed = 42)
#   write.csv(data, "customer_data.csv", row.names = FALSE)
# ==============================================================================


#' Generate Synthetic Customer Segmentation Data
#'
#' @param n Total number of respondents (default: 1000)
#' @param seed Random seed for reproducibility (default: 42)
#' @param missing_rate Fraction of MCAR missingness (default: 0.05)
#' @param outlier_rate Fraction of outlier contamination (default: 0.02)
#' @return Data frame with respondent data
generate_customer_data <- function(n = 1000, seed = 42, missing_rate = 0.05,
                                   outlier_rate = 0.02) {

  set.seed(seed)

  # =========================================================================
  # SEGMENT DEFINITIONS
  # =========================================================================

  # Segment sizes (sum = n)
  sizes <- c(
    budget    = round(0.28 * n),   # 280 Budget Seekers
    premium   = round(0.23 * n),   # 230 Premium Loyalists
    digital   = round(0.26 * n),   # 260 Digital Natives
    convenience = n - round(0.28 * n) - round(0.23 * n) - round(0.26 * n)  # 230 Convenience
  )

  segment_labels <- rep(c("Budget Seekers", "Premium Loyalists",
                           "Digital Natives", "Convenience Shoppers"),
                        times = sizes)

  # =========================================================================
  # NUMERIC VARIABLES (15 clustering variables, 1-10 scale unless noted)
  # =========================================================================

  # Helper: generate variable with segment-specific means and some noise
  gen_var <- function(means, sds = NULL) {
    if (is.null(sds)) sds <- rep(1.2, 4)
    vals <- numeric(n)
    offset <- 0
    for (seg in 1:4) {
      idx <- (offset + 1):(offset + sizes[seg])
      vals[idx] <- rnorm(sizes[seg], mean = means[seg], sd = sds[seg])
      offset <- offset + sizes[seg]
    }
    # Clip to [1, 10] for scale variables
    pmin(pmax(round(vals, 1), 1), 10)
  }

  #                          Budget  Premium  Digital  Convenience
  data <- data.frame(
    respondent_id = sprintf("R%04d", 1:n),

    # Behavioural variables
    purchase_frequency    = gen_var(c(4.5, 6.0, 5.5, 3.5), c(1.5, 1.2, 1.3, 1.0)),
    avg_monthly_spend     = gen_var(c(3.0, 8.5, 5.5, 6.0), c(1.0, 1.0, 1.5, 1.2)),
    brand_loyalty_score   = gen_var(c(3.5, 8.0, 4.5, 5.5), c(1.3, 1.0, 1.5, 1.2)),
    price_sensitivity     = gen_var(c(8.5, 3.0, 5.0, 5.5), c(1.0, 1.2, 1.5, 1.3)),
    online_preference     = gen_var(c(5.0, 4.5, 9.0, 4.0), c(1.5, 1.3, 0.8, 1.5)),

    # Satisfaction variables
    satisfaction_overall  = gen_var(c(5.5, 7.5, 6.5, 6.0), c(1.5, 1.0, 1.2, 1.3)),
    satisfaction_quality  = gen_var(c(5.0, 8.5, 6.0, 6.5), c(1.3, 0.8, 1.2, 1.1)),
    satisfaction_service  = gen_var(c(5.5, 7.0, 5.5, 7.5), c(1.4, 1.1, 1.5, 0.9)),
    satisfaction_delivery = gen_var(c(6.0, 7.0, 7.5, 5.0), c(1.2, 1.0, 1.0, 1.5)),

    # Psychographic variables
    tech_savviness        = gen_var(c(4.0, 5.0, 8.5, 4.5), c(1.5, 1.3, 0.9, 1.4)),
    time_pressure         = gen_var(c(4.5, 5.0, 6.0, 8.5), c(1.3, 1.4, 1.2, 0.8)),
    category_breadth      = gen_var(c(3.5, 5.5, 6.5, 4.0), c(1.2, 1.3, 1.4, 1.1)),
    recency_days          = gen_var(c(5.5, 4.0, 3.5, 6.5), c(1.5, 1.0, 1.2, 1.3)),
    referral_likelihood   = gen_var(c(4.0, 7.5, 6.0, 5.0), c(1.5, 1.0, 1.3, 1.4)),
    app_usage_score       = gen_var(c(3.0, 4.5, 9.0, 3.5), c(1.5, 1.5, 0.7, 1.5)),

    # True segment (for validation only)
    true_segment = segment_labels,

    stringsAsFactors = FALSE
  )

  # =========================================================================
  # DEMOGRAPHIC VARIABLES (4 categorical for profiling)
  # =========================================================================

  # Age group with segment-specific distributions
  age_probs <- list(
    budget    = c("18-24" = 0.15, "25-34" = 0.30, "35-44" = 0.25,
                  "45-54" = 0.20, "55+" = 0.10),
    premium   = c("18-24" = 0.05, "25-34" = 0.15, "35-44" = 0.30,
                  "45-54" = 0.30, "55+" = 0.20),
    digital   = c("18-24" = 0.30, "25-34" = 0.35, "35-44" = 0.20,
                  "45-54" = 0.10, "55+" = 0.05),
    convenience = c("18-24" = 0.10, "25-34" = 0.25, "35-44" = 0.30,
                    "45-54" = 0.25, "55+" = 0.10)
  )

  offset <- 0
  age_groups <- character(n)
  for (seg in 1:4) {
    idx <- (offset + 1):(offset + sizes[seg])
    probs <- age_probs[[seg]]
    age_groups[idx] <- sample(names(probs), sizes[seg], replace = TRUE, prob = probs)
    offset <- offset + sizes[seg]
  }
  data$age_group <- age_groups

  # Gender
  gender_probs <- list(
    budget    = c(Male = 0.55, Female = 0.42, Other = 0.03),
    premium   = c(Male = 0.48, Female = 0.49, Other = 0.03),
    digital   = c(Male = 0.50, Female = 0.45, Other = 0.05),
    convenience = c(Male = 0.45, Female = 0.52, Other = 0.03)
  )

  offset <- 0
  genders <- character(n)
  for (seg in 1:4) {
    idx <- (offset + 1):(offset + sizes[seg])
    probs <- gender_probs[[seg]]
    genders[idx] <- sample(names(probs), sizes[seg], replace = TRUE, prob = probs)
    offset <- offset + sizes[seg]
  }
  data$gender <- genders

  # Region
  region_probs <- list(
    budget    = c(Urban = 0.30, Suburban = 0.40, Rural = 0.30),
    premium   = c(Urban = 0.50, Suburban = 0.35, Rural = 0.15),
    digital   = c(Urban = 0.55, Suburban = 0.35, Rural = 0.10),
    convenience = c(Urban = 0.40, Suburban = 0.40, Rural = 0.20)
  )

  offset <- 0
  regions <- character(n)
  for (seg in 1:4) {
    idx <- (offset + 1):(offset + sizes[seg])
    probs <- region_probs[[seg]]
    regions[idx] <- sample(names(probs), sizes[seg], replace = TRUE, prob = probs)
    offset <- offset + sizes[seg]
  }
  data$region <- regions

  # Income bracket
  income_probs <- list(
    budget    = c("Under 30k" = 0.35, "30-60k" = 0.40, "60-100k" = 0.20, "Over 100k" = 0.05),
    premium   = c("Under 30k" = 0.05, "30-60k" = 0.15, "60-100k" = 0.35, "Over 100k" = 0.45),
    digital   = c("Under 30k" = 0.10, "30-60k" = 0.35, "60-100k" = 0.35, "Over 100k" = 0.20),
    convenience = c("Under 30k" = 0.10, "30-60k" = 0.30, "60-100k" = 0.35, "Over 100k" = 0.25)
  )

  offset <- 0
  incomes <- character(n)
  for (seg in 1:4) {
    idx <- (offset + 1):(offset + sizes[seg])
    probs <- income_probs[[seg]]
    incomes[idx] <- sample(names(probs), sizes[seg], replace = TRUE, prob = probs)
    offset <- offset + sizes[seg]
  }
  data$income_bracket <- incomes

  # =========================================================================
  # SHUFFLE ROWS (remove segment ordering)
  # =========================================================================

  shuffle_idx <- sample(n)
  data <- data[shuffle_idx, ]
  rownames(data) <- NULL

  # =========================================================================
  # ADD MISSINGNESS (~5% MCAR)
  # =========================================================================

  numeric_cols <- c("purchase_frequency", "avg_monthly_spend", "brand_loyalty_score",
                    "price_sensitivity", "online_preference", "satisfaction_overall",
                    "satisfaction_quality", "satisfaction_service", "satisfaction_delivery",
                    "tech_savviness", "time_pressure", "category_breadth",
                    "recency_days", "referral_likelihood", "app_usage_score")

  n_missing <- round(n * length(numeric_cols) * missing_rate)
  missing_cells <- sample(n * length(numeric_cols), n_missing)
  for (cell in missing_cells) {
    row <- ((cell - 1) %% n) + 1
    col <- numeric_cols[((cell - 1) %/% n) + 1]
    data[[col]][row] <- NA
  }

  # =========================================================================
  # ADD OUTLIER CONTAMINATION (~2%)
  # =========================================================================

  n_outliers <- round(n * outlier_rate)
  outlier_rows <- sample(n, n_outliers)
  for (idx in outlier_rows) {
    # Pick 2-4 random variables and set extreme values
    n_extreme <- sample(2:4, 1)
    extreme_cols <- sample(numeric_cols, n_extreme)
    for (col in extreme_cols) {
      # Push to extreme end of scale
      data[[col]][idx] <- sample(c(1, 1.5, 9.5, 10), 1)
    }
  }

  cat(sprintf("Generated %d respondents with %d segments\n", n, 4))
  cat(sprintf("  Missing values: ~%.0f%% MCAR\n", missing_rate * 100))
  cat(sprintf("  Outlier contamination: ~%.0f%%\n", outlier_rate * 100))
  cat(sprintf("  Segment sizes: %s\n",
              paste(sprintf("%s (%d)", names(sizes), sizes), collapse = ", ")))

  data
}


# Generate and save if run as script
if (interactive() || identical(sys.nframe(), 0L)) {
  data <- generate_customer_data()
  write.csv(data, file.path(dirname(sys.frame(1)$ofile %||% "."),
                            "customer_data.csv"), row.names = FALSE)
  cat("Saved to customer_data.csv\n")
}
