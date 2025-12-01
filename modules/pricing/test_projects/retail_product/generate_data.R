# Generate Retail Product Test Data
# Premium Coffee Maker - Both VW and GG Methods

set.seed(2027)
n <- 400

cat("Generating Retail Product test data (both methods)...\n")

# Generate respondent characteristics
age_group <- sample(c("18-34", "35-54", "55+"), n, replace = TRUE, prob = c(0.35, 0.40, 0.25))
income_bracket <- sample(c("Under 50k", "50-75k", "75-100k", "100k+"), n, replace = TRUE,
                         prob = c(0.25, 0.30, 0.25, 0.20))
coffee_consumption <- sample(c("Light", "Moderate", "Heavy"), n, replace = TRUE,
                             prob = c(0.30, 0.45, 0.25))
survey_weight <- pmax(0.4, pmin(2.8, rnorm(n, 1, 0.45)))

# Van Westendorp: Premium coffee maker ($150-$350 range)
vw_too_cheap <- pmax(80, pmin(200, rnorm(n, 140, 25)))
vw_cheap <- pmax(120, pmin(250, rnorm(n, 180, 28)))
vw_expensive <- pmax(180, pmin(350, rnorm(n, 260, 32)))
vw_too_expensive <- pmax(220, pmin(450, rnorm(n, 320, 40)))

# Gabor-Granger: 6 price points ($180-$280)
price_points <- c(180, 200, 220, 240, 260, 280)
base_intent <- c(0.78, 0.65, 0.51, 0.38, 0.27, 0.19)

pi_data <- matrix(NA, nrow = n, ncol = length(price_points))
for (i in 1:n) {
  sensitivity <- rnorm(1, 0, 0.12)
  for (j in 1:length(price_points)) {
    prob <- pmax(0, pmin(1, base_intent[j] + sensitivity))
    pi_data[i, j] <- rbinom(1, 1, prob)
  }
}

# Assemble data
data_retail <- data.frame(
  respondent_id = 1:n,
  age_group = age_group,
  income_bracket = income_bracket,
  coffee_consumption = coffee_consumption,
  survey_weight = round(survey_weight, 3),
  
  # Van Westendorp columns
  vw_too_cheap = vw_too_cheap,
  vw_cheap = vw_cheap,
  vw_expensive = vw_expensive,
  vw_too_expensive = vw_too_expensive,
  
  # Gabor-Granger columns
  gg_180 = pi_data[, 1],
  gg_200 = pi_data[, 2],
  gg_220 = pi_data[, 3],
  gg_240 = pi_data[, 4],
  gg_260 = pi_data[, 5],
  gg_280 = pi_data[, 6]
)

# Add DK codes (4%)
dk_indices <- sample(1:n, floor(n * 0.04))
for (idx in dk_indices) {
  # Some in VW
  if (runif(1) < 0.5) {
    data_retail[idx, sample(c("vw_too_cheap", "vw_cheap", "vw_expensive", "vw_too_expensive"), 1)] <- 98
  } else {
    # Some in GG
    data_retail[idx, c("gg_180", "gg_200", "gg_220", "gg_240", "gg_260", "gg_280")] <- 99
  }
}

# Add monotonicity violations for VW (6%)
viol_indices <- sample(setdiff(1:n, dk_indices), floor(n * 0.06))
for (idx in viol_indices) {
  temp <- data_retail$vw_cheap[idx]
  data_retail$vw_cheap[idx] <- data_retail$vw_expensive[idx]
  data_retail$vw_expensive[idx] <- temp
}

# Round VW prices to nearest $10
vw_cols <- c("vw_too_cheap", "vw_cheap", "vw_expensive", "vw_too_expensive")
for (col in vw_cols) {
  data_retail[[col]] <- round(data_retail[[col]] / 10) * 10
}

# Save data
write.csv(data_retail, "coffee_maker_data.csv", row.names = FALSE)

cat(sprintf("✓ Created coffee_maker_data.csv (n=%d)\n", n))
cat("✓ Includes: Both VW and GG data\n")
cat("✓ VW range: $150-$350, GG prices: $180-$280\n")
cat("✓ Unit cost: $95 → Profit optimization enabled\n")
cat("✓ Ready to use with config_retail.xlsx\n")
