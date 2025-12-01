# Generate SaaS Subscription Test Data
# Software Subscription Pricing - Gabor-Granger with Profit Optimization

set.seed(2026)
n <- 350

cat("Generating SaaS subscription test data...\n")

# Generate respondent characteristics
age_group <- sample(c("18-34", "35-54", "55+"), n, replace = TRUE, prob = c(0.5, 0.35, 0.15))
company_size <- sample(c("1-10", "11-50", "51-200", "200+"), n, replace = TRUE,
                       prob = c(0.3, 0.35, 0.25, 0.1))
industry <- sample(c("Tech", "Finance", "Healthcare", "Retail", "Other"), n, replace = TRUE)
survey_weight <- pmax(0.5, pmin(2.5, rnorm(n, 1, 0.3)))

# Gabor-Granger: Purchase intent at 7 price points ($25-$55/month)
# Realistic SaaS pricing with price sensitivity
price_points <- c(25, 30, 35, 40, 45, 50, 55)

# Base purchase intent (decreasing with price)
base_intent <- c(0.85, 0.72, 0.58, 0.43, 0.31, 0.22, 0.16)

# Generate purchase intent with individual variation
pi_data <- matrix(NA, nrow = n, ncol = length(price_points))
for (i in 1:n) {
  # Add individual heterogeneity
  sensitivity <- rnorm(1, 0, 0.15)  # Price sensitivity varies
  for (j in 1:length(price_points)) {
    # Probability decreases with price, varies by individual
    prob <- pmax(0, pmin(1, base_intent[j] + sensitivity - (j-4)*0.02))
    pi_data[i, j] <- rbinom(1, 1, prob)
  }
}

# Assemble data frame
data_saas <- data.frame(
  respondent_id = 1:n,
  age_group = age_group,
  company_size = company_size,
  industry = industry,
  survey_weight = round(survey_weight, 3),
  pi_25 = pi_data[, 1],
  pi_30 = pi_data[, 2],
  pi_35 = pi_data[, 3],
  pi_40 = pi_data[, 4],
  pi_45 = pi_data[, 5],
  pi_50 = pi_data[, 6],
  pi_55 = pi_data[, 7]
)

# Add "Don't Know" responses (3%)
dk_indices <- sample(1:n, floor(n * 0.03))
pi_cols <- c("pi_25", "pi_30", "pi_35", "pi_40", "pi_45", "pi_50", "pi_55")
for (idx in dk_indices) {
  # DK for all prices (couldn't evaluate)
  data_saas[idx, pi_cols] <- 99
}

# Save data
write.csv(data_saas, "saas_subscription_data.csv", row.names = FALSE)

cat(sprintf("✓ Created saas_subscription_data.csv (n=%d)\n", n))
cat("✓ Includes: 7 price points ($25-$55), weights, segments\n")
cat("✓ Unit cost: $18/month → Profit optimization enabled\n")
cat("✓ Ready to use with config_saas.xlsx\n")
