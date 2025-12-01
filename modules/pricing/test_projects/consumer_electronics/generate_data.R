# Generate Consumer Electronics Test Data
# Smart Speaker Pricing Study - Van Westendorp

set.seed(2025)
n <- 300

cat("Generating Consumer Electronics test data...\n")

# Realistic smart speaker pricing data ($80-180 range)
data_electronics <- data.frame(
  respondent_id = 1:n,
  age_group = sample(c("18-34", "35-54", "55+"), n, replace = TRUE, 
                     prob = c(0.4, 0.35, 0.25)),
  income = sample(c("Under 50k", "50-100k", "100k+"), n, replace = TRUE,
                  prob = c(0.3, 0.45, 0.25)),
  region = sample(c("Northeast", "South", "Midwest", "West"), n, replace = TRUE),
  survey_weight = pmax(0.3, pmin(3.0, rnorm(n, 1, 0.4))),
  
  # Smart speaker pricing - typical range $80-$180
  too_cheap = pmax(40, pmin(120, rnorm(n, 75, 18))),
  cheap = pmax(60, pmin(140, rnorm(n, 95, 20))),
  expensive = pmax(90, pmin(180, rnorm(n, 135, 22))),
  too_expensive = pmax(120, pmin(250, rnorm(n, 165, 28)))
)

# Add some "Don't Know" responses (5% of respondents)
dk_indices <- sample(1:n, floor(n * 0.05))
dk_cols <- c("too_cheap", "cheap", "expensive", "too_expensive")
for (idx in dk_indices) {
  data_electronics[idx, sample(dk_cols, 1)] <- 98
}

# Add realistic monotonicity violations (8%)
viol_indices <- sample(setdiff(1:n, dk_indices), floor(n * 0.08))
for (idx in viol_indices) {
  # Swap cheap and expensive (common confusion)
  temp <- data_electronics$cheap[idx]
  data_electronics$cheap[idx] <- data_electronics$expensive[idx]
  data_electronics$expensive[idx] <- temp
}

# Round to nearest $5 (realistic pricing)
price_cols <- c("too_cheap", "cheap", "expensive", "too_expensive")
for (col in price_cols) {
  data_electronics[[col]] <- round(data_electronics[[col]] / 5) * 5
}

# Save data
write.csv(data_electronics, "smart_speaker_data.csv", row.names = FALSE)

cat(sprintf("✓ Created smart_speaker_data.csv (n=%d)\n", n))
cat("✓ Includes: weights, segments, DK codes, monotonicity violations\n")
cat("✓ Ready to use with config_electronics.xlsx\n")
