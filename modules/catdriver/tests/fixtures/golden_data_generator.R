# ==============================================================================
# GOLDEN FIXTURE DATA GENERATOR
# ==============================================================================
#
# Generates reproducible test data with KNOWN statistical properties.
# This script creates the golden test fixtures and computes expected values.
#
# Run this script to regenerate fixtures if the test data format changes.
#
# IMPORTANT: Running this will overwrite existing fixtures!
#
# ==============================================================================

set.seed(20241218)  # Fixed seed for reproducibility

# ==============================================================================
# GENERATE BINARY OUTCOME TEST DATA
# ==============================================================================

generate_golden_binary_data <- function() {
  n <- 400
  set.seed(42)  # Nested seed for this specific dataset

  # Create predictors with specific distributions
  satisfaction <- factor(
    sample(c("Low", "Medium", "High"), n, TRUE, c(0.3, 0.4, 0.3)),
    levels = c("Low", "Medium", "High")
  )

  product_tier <- factor(
    sample(c("Basic", "Standard", "Premium"), n, TRUE, c(0.4, 0.4, 0.2)),
    levels = c("Basic", "Standard", "Premium")
  )

  channel <- factor(
    sample(c("Online", "Retail", "Partner"), n, TRUE, c(0.35, 0.35, 0.30)),
    levels = c("Online", "Retail", "Partner")
  )

  # Create outcome with known relationships to predictors
  # Satisfaction: High -> more likely retained (strong effect)
  # Product tier: Premium -> more likely retained (medium effect)
  # Channel: minimal effect

  # Base probability
  p_retained <- 0.65

  # Adjust based on satisfaction (strong driver)
  p_retained <- p_retained + ifelse(satisfaction == "High", 0.15,
                                     ifelse(satisfaction == "Low", -0.20, 0))

  # Adjust based on product tier (medium driver)
  p_retained <- p_retained + ifelse(product_tier == "Premium", 0.10,
                                     ifelse(product_tier == "Basic", -0.08, 0))

  # Adjust based on channel (weak/negligible driver)
  p_retained <- p_retained + ifelse(channel == "Partner", 0.02, 0)

  # Clamp probabilities
  p_retained <- pmax(0.05, pmin(0.95, p_retained))

  # Generate outcomes
  retained <- factor(
    ifelse(runif(n) < p_retained, "Retained", "Churned"),
    levels = c("Churned", "Retained")
  )

  data.frame(
    respondent_id = 1:n,
    retained = retained,
    satisfaction = satisfaction,
    product_tier = product_tier,
    channel = channel,
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# GENERATE ORDINAL OUTCOME TEST DATA
# ==============================================================================

generate_golden_ordinal_data <- function() {
  n <- 350
  set.seed(123)  # Nested seed for this specific dataset

  # Predictors
  age_group <- factor(
    sample(c("18-34", "35-54", "55+"), n, TRUE, c(0.35, 0.40, 0.25)),
    levels = c("18-34", "35-54", "55+")
  )

  service_quality <- factor(
    sample(c("Poor", "Fair", "Good", "Excellent"), n, TRUE, c(0.15, 0.30, 0.35, 0.20)),
    levels = c("Poor", "Fair", "Good", "Excellent")
  )

  price_perception <- factor(
    sample(c("Too High", "Fair", "Good Value"), n, TRUE, c(0.25, 0.45, 0.30)),
    levels = c("Too High", "Fair", "Good Value")
  )

  # Generate ordinal outcome with known relationships
  # Service quality: STRONGEST driver
  # Price perception: MEDIUM driver
  # Age: WEAK driver

  latent_score <- rnorm(n, mean = 0, sd = 1)

  # Service quality effect (large)
  latent_score <- latent_score +
    ifelse(service_quality == "Excellent", 1.2,
           ifelse(service_quality == "Good", 0.5,
                  ifelse(service_quality == "Fair", -0.3, -1.0)))

  # Price perception effect (medium)
  latent_score <- latent_score +
    ifelse(price_perception == "Good Value", 0.6,
           ifelse(price_perception == "Too High", -0.5, 0))

  # Age effect (small)
  latent_score <- latent_score +
    ifelse(age_group == "55+", 0.2,
           ifelse(age_group == "18-34", -0.1, 0))

  # Convert to ordinal outcome
  satisfaction <- ordered(
    cut(latent_score,
        breaks = c(-Inf, -0.8, 0.3, Inf),
        labels = c("Dissatisfied", "Neutral", "Satisfied")),
    levels = c("Dissatisfied", "Neutral", "Satisfied")
  )

  data.frame(
    respondent_id = 1:n,
    satisfaction = satisfaction,
    age_group = age_group,
    service_quality = service_quality,
    price_perception = price_perception,
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# GENERATE DATA WITH MISSING VALUES
# ==============================================================================

generate_golden_missing_data <- function() {
  # Start with binary data
  data <- generate_golden_binary_data()
  n <- nrow(data)

  set.seed(999)  # Different seed for missing pattern

  # Inject missing values with known pattern
  # 5% missing in satisfaction (drop_row strategy expected)
  data$satisfaction[sample(n, round(n * 0.05))] <- NA

  # 8% missing in product_tier (missing_as_level strategy expected)
  data$product_tier[sample(n, round(n * 0.08))] <- NA

  # Channel: no missing

  data
}


# ==============================================================================
# COMPUTE EXPECTED VALUES
# ==============================================================================

compute_expected_values <- function() {

  # Load required packages
  library(car)

  # ===========================================================================
  # BINARY MODEL EXPECTED VALUES
  # ===========================================================================

  binary_data <- generate_golden_binary_data()

  # Fit binary logistic model
  binary_model <- glm(
    retained ~ satisfaction + product_tier + channel,
    data = binary_data,
    family = binomial()
  )

  # Extract key statistics
  binary_coefs <- coef(binary_model)
  binary_se <- sqrt(diag(vcov(binary_model)))
  binary_or <- exp(binary_coefs)

  # Anova for importance
  binary_anova <- car::Anova(binary_model, type = "II")

  # Importance ranking (by chi-square)
  importance_order <- order(binary_anova$Chisq, decreasing = TRUE)
  binary_importance_ranking <- rownames(binary_anova)[importance_order]

  # Top driver chi-square
  binary_top_chi_sq <- max(binary_anova$Chisq)

  binary_expected <- list(
    n_observations = nrow(binary_data),
    outcome_levels = levels(binary_data$retained),

    # Coefficient checks (rounded to avoid floating point issues)
    intercept = round(binary_coefs["(Intercept)"], 4),

    # Odds ratios for key comparisons
    or_satisfaction_high = round(binary_or["satisfactionHigh"], 3),
    or_satisfaction_medium = round(binary_or["satisfactionMedium"], 3),
    or_product_premium = round(binary_or["product_tierPremium"], 3),

    # Model fit
    mcfadden_r2_min = 0.05,  # Should be at least this
    mcfadden_r2_max = 0.30,  # Should be at most this

    # Importance ranking (first should be satisfaction)
    top_driver = "satisfaction",
    importance_ranking = binary_importance_ranking,
    top_chi_square = round(binary_top_chi_sq, 2),

    # Convergence
    converged = TRUE
  )

  # ===========================================================================
  # ORDINAL MODEL EXPECTED VALUES
  # ===========================================================================

  ordinal_data <- generate_golden_ordinal_data()

  # Fit ordinal model
  if (requireNamespace("ordinal", quietly = TRUE)) {
    ordinal_model <- ordinal::clm(
      satisfaction ~ service_quality + price_perception + age_group,
      data = ordinal_data
    )
    ordinal_coefs <- coef(ordinal_model)
    ordinal_engine <- "ordinal::clm"
  } else {
    ordinal_model <- MASS::polr(
      satisfaction ~ service_quality + price_perception + age_group,
      data = ordinal_data,
      Hess = TRUE
    )
    ordinal_coefs <- c(ordinal_model$zeta, coef(ordinal_model))
    ordinal_engine <- "MASS::polr"
  }

  ordinal_expected <- list(
    n_observations = nrow(ordinal_data),
    outcome_levels = levels(ordinal_data$satisfaction),
    n_thresholds = length(levels(ordinal_data$satisfaction)) - 1,

    # Top driver should be service_quality
    top_driver = "service_quality",

    # Engine used
    expected_engine = ordinal_engine,

    # Basic coefficient sanity
    n_coefficients_expected = 6  # 3 service + 2 price + 1 age (minus references)
  )

  # ===========================================================================
  # MISSING DATA HANDLING EXPECTED VALUES
  # ===========================================================================

  missing_data <- generate_golden_missing_data()

  n_satisfaction_missing <- sum(is.na(missing_data$satisfaction))
  n_product_tier_missing <- sum(is.na(missing_data$product_tier))

  missing_expected <- list(
    total_rows = nrow(missing_data),
    n_satisfaction_missing = n_satisfaction_missing,
    n_product_tier_missing = n_product_tier_missing,

    # With drop_row for satisfaction, missing_as_level for product_tier:
    # - Rows with missing satisfaction are dropped
    # - Rows with missing product_tier get "Missing" level
    expected_rows_after_prep = nrow(missing_data) - n_satisfaction_missing,
    expected_product_tier_levels = c("Basic", "Standard", "Premium", "Missing")
  )

  # ===========================================================================
  # RETURN ALL EXPECTED VALUES
  # ===========================================================================

  list(
    binary = binary_expected,
    ordinal = ordinal_expected,
    missing = missing_expected,
    generation_date = Sys.Date(),
    r_version = R.version.string
  )
}


# ==============================================================================
# SAVE FIXTURES
# ==============================================================================

save_golden_fixtures <- function(output_dir = "tests/fixtures") {

  cat("Generating golden fixture data...\n")

  # Generate data
  binary_data <- generate_golden_binary_data()
  ordinal_data <- generate_golden_ordinal_data()
  missing_data <- generate_golden_missing_data()

  # Save as CSV
  write.csv(binary_data, file.path(output_dir, "golden_binary.csv"), row.names = FALSE)
  write.csv(ordinal_data, file.path(output_dir, "golden_ordinal.csv"), row.names = FALSE)
  write.csv(missing_data, file.path(output_dir, "golden_missing.csv"), row.names = FALSE)

  cat("  Saved: golden_binary.csv\n")
  cat("  Saved: golden_ordinal.csv\n")
  cat("  Saved: golden_missing.csv\n")

  # Compute and save expected values
  cat("Computing expected values...\n")
  expected <- compute_expected_values()

  # Save as RDS for easy loading in tests
  saveRDS(expected, file.path(output_dir, "golden_expected.rds"))
  cat("  Saved: golden_expected.rds\n")

  # Also save human-readable version
  cat("\n=== GOLDEN FIXTURE EXPECTED VALUES ===\n\n")

  cat("BINARY MODEL:\n")
  cat("  N:", expected$binary$n_observations, "\n")
  cat("  Top driver:", expected$binary$top_driver, "\n")
  cat("  OR (satisfaction High vs Low):", expected$binary$or_satisfaction_high, "\n")
  cat("  OR (satisfaction Medium vs Low):", expected$binary$or_satisfaction_medium, "\n")
  cat("  Top chi-square:", expected$binary$top_chi_square, "\n")

  cat("\nORDINAL MODEL:\n")
  cat("  N:", expected$ordinal$n_observations, "\n")
  cat("  Top driver:", expected$ordinal$top_driver, "\n")
  cat("  Expected engine:", expected$ordinal$expected_engine, "\n")

  cat("\nMISSING DATA:\n")
  cat("  Total rows:", expected$missing$total_rows, "\n")
  cat("  Missing satisfaction:", expected$missing$n_satisfaction_missing, "\n")
  cat("  Missing product_tier:", expected$missing$n_product_tier_missing, "\n")
  cat("  Expected rows after prep:", expected$missing$expected_rows_after_prep, "\n")

  cat("\nGenerated on:", as.character(Sys.Date()), "\n")
  cat("R version:", R.version.string, "\n")

  invisible(expected)
}


# ==============================================================================
# RUN IF CALLED DIRECTLY
# ==============================================================================

if (!interactive() && sys.nframe() == 0) {
  # Running as script
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) > 0 && args[1] == "--generate") {
    save_golden_fixtures()
  } else {
    cat("Usage: Rscript golden_data_generator.R --generate\n")
  }
}
