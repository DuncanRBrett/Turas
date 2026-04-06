# ==============================================================================
# KEYDRIVER DEMO - SYNTHETIC DATA GENERATOR
# ==============================================================================
#
# Creates a realistic customer satisfaction survey dataset for demonstrating
# all keydriver module features including:
#   - Core importance analysis (Shapley, Relative Weight, Beta Weight)
#   - Bootstrap confidence intervals
#   - Effect size interpretation
#   - Segment comparison
#   - Executive summary
#   - Quadrant analysis (Importance-Performance)
#   - HTML report generation
#
# Scenario: A telecommunications company surveys 800 customers about their
# satisfaction with various service attributes to understand what drives
# overall satisfaction.
#
# ==============================================================================

generate_telecom_demo_data <- function(n = 800, seed = 42) {

  set.seed(seed)

  # ------------------------------------------------------------------
  # Respondent IDs
  # ------------------------------------------------------------------
  respondent_id <- seq_len(n)

  # ------------------------------------------------------------------
  # Segment variable: Customer type (for segment comparison)
  # 40% Business, 35% Residential, 25% Premium
  # ------------------------------------------------------------------
  segment_probs <- c(0.40, 0.35, 0.25)
  customer_type <- sample(
    c("Business", "Residential", "Premium"),
    size = n, replace = TRUE, prob = segment_probs
  )

  # ------------------------------------------------------------------
  # Demographic weight variable (realistic survey weights)
  # ------------------------------------------------------------------
  weight <- round(runif(n, 0.4, 2.5), 2)

  # ------------------------------------------------------------------
  # Generate correlated driver satisfaction scores (1-10 scale)
  # Using a latent factor structure to create realistic correlations
  # ------------------------------------------------------------------

  # Latent factors
  f_service <- rnorm(n)   # Service quality factor
  f_value   <- rnorm(n)   # Value perception factor
  f_tech    <- rnorm(n)   # Technology factor

  # Driver variables with realistic correlation structure
  # Higher coefficients = stronger relationship with outcome

  # Network Reliability: STRONG driver (will be #1)
  network_reliability <- round(pmin(10, pmax(1,
    5.5 + 1.2 * f_tech + 0.3 * f_service + rnorm(n, 0, 1.2)
  )))

  # Customer Service: STRONG driver (will be #2)
  customer_service <- round(pmin(10, pmax(1,
    6.0 + 1.0 * f_service + 0.2 * f_value + rnorm(n, 0, 1.3)
  )))

  # Value for Money: MODERATE driver
  value_for_money <- round(pmin(10, pmax(1,
    5.0 + 0.8 * f_value + 0.3 * f_tech + rnorm(n, 0, 1.4)
  )))

  # Data Speed: MODERATE driver (correlated with network)
  data_speed <- round(pmin(10, pmax(1,
    5.8 + 0.9 * f_tech + 0.4 * f_service + rnorm(n, 0, 1.1)
  )))

  # Billing Clarity: SMALL driver
  billing_clarity <- round(pmin(10, pmax(1,
    6.5 + 0.4 * f_value + 0.2 * f_service + rnorm(n, 0, 1.5)
  )))

  # Coverage Area: MODERATE driver
  coverage_area <- round(pmin(10, pmax(1,
    6.0 + 0.7 * f_tech + rnorm(n, 0, 1.3)
  )))

  # App Experience: SMALL driver
  app_experience <- round(pmin(10, pmax(1,
    5.5 + 0.5 * f_tech + 0.3 * f_service + rnorm(n, 0, 1.6)
  )))

  # Contract Flexibility: NEGLIGIBLE driver
  contract_flexibility <- round(pmin(10, pmax(1,
    5.8 + 0.2 * f_value + rnorm(n, 0, 1.8)
  )))

  # ------------------------------------------------------------------
  # Generate outcome: Overall Satisfaction
  # True importance weights (for validation):
  #   Network Reliability:   0.28  (dominant)
  #   Customer Service:      0.22
  #   Value for Money:       0.15
  #   Data Speed:            0.12
  #   Coverage Area:         0.10
  #   Billing Clarity:       0.06
  #   App Experience:        0.05
  #   Contract Flexibility:  0.02
  # ------------------------------------------------------------------
  overall_satisfaction <- round(pmin(10, pmax(1,
    0.28 * network_reliability +
    0.22 * customer_service +
    0.15 * value_for_money +
    0.12 * data_speed +
    0.10 * coverage_area +
    0.06 * billing_clarity +
    0.05 * app_experience +
    0.02 * contract_flexibility +
    rnorm(n, 0, 0.8)
  )))

  # ------------------------------------------------------------------
  # Add segment-specific effects to make segment comparison interesting
  # Business customers care more about reliability/speed
  # Premium customers care more about service/app
  # ------------------------------------------------------------------
  for (i in seq_len(n)) {
    if (customer_type[i] == "Business") {
      # Business: higher reliability expectations
      network_reliability[i] <- min(10, network_reliability[i] + sample(0:1, 1))
      data_speed[i] <- min(10, data_speed[i] + sample(0:1, 1))
    } else if (customer_type[i] == "Premium") {
      # Premium: higher service and app expectations
      customer_service[i] <- min(10, customer_service[i] + sample(0:1, 1))
      app_experience[i] <- min(10, app_experience[i] + sample(0:2, 1))
    }
  }

  # ------------------------------------------------------------------
  # Stated importance (for quadrant analysis)
  # These represent what customers SAY matters most
  # ------------------------------------------------------------------
  stated_importance <- data.frame(
    driver = c("network_reliability", "customer_service", "value_for_money",
               "data_speed", "billing_clarity", "coverage_area",
               "app_experience", "contract_flexibility"),
    stated_importance = c(9.2, 8.5, 8.8, 7.5, 6.2, 7.8, 5.5, 4.8),
    stringsAsFactors = FALSE
  )

  # ------------------------------------------------------------------
  # Introduce realistic missing data (~3%)
  # ------------------------------------------------------------------
  n_missing <- round(n * 0.03)
  missing_rows <- sample(seq_len(n), n_missing)
  missing_cols <- sample(c("billing_clarity", "app_experience",
                           "contract_flexibility"), n_missing, replace = TRUE)
  for (k in seq_len(n_missing)) {
    data_col <- missing_cols[k]
    # We'll set these to NA in the final data frame
  }

  # ------------------------------------------------------------------
  # Assemble data frame
  # ------------------------------------------------------------------
  demo_data <- data.frame(
    respondent_id = respondent_id,
    customer_type = customer_type,
    weight = weight,
    overall_satisfaction = overall_satisfaction,
    network_reliability = network_reliability,
    customer_service = customer_service,
    value_for_money = value_for_money,
    data_speed = data_speed,
    billing_clarity = billing_clarity,
    coverage_area = coverage_area,
    app_experience = app_experience,
    contract_flexibility = contract_flexibility,
    stringsAsFactors = FALSE
  )

  # Apply missing values
  for (k in seq_len(n_missing)) {
    demo_data[missing_rows[k], missing_cols[k]] <- NA
  }

  list(
    data = demo_data,
    stated_importance = stated_importance,
    true_weights = c(
      network_reliability = 0.28,
      customer_service = 0.22,
      value_for_money = 0.15,
      data_speed = 0.12,
      coverage_area = 0.10,
      billing_clarity = 0.06,
      app_experience = 0.05,
      contract_flexibility = 0.02
    ),
    description = paste0(
      "Synthetic telecom customer satisfaction survey (n=", n, "). ",
      "8 drivers, 3 customer segments (Business/Residential/Premium). ",
      "Network Reliability and Customer Service are the dominant drivers."
    )
  )
}

# Generate and save if run directly
if (sys.nframe() == 0 || identical(environment(), globalenv())) {
  cat("Generating demo data...\n")
  demo <- generate_telecom_demo_data()
  output_dir <- dirname(sys.frame(1)$ofile %||% ".")

  # Save data
  data_file <- file.path(output_dir, "demo_survey_data.csv")
  utils::write.csv(demo$data, data_file, row.names = FALSE)
  cat(sprintf("  Saved: %s (%d rows x %d cols)\n",
              data_file, nrow(demo$data), ncol(demo$data)))

  cat(sprintf("  Description: %s\n", demo$description))
  cat("Done.\n")
}
