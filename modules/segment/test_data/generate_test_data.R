# Generate synthetic test data for segmentation module testing
# Creates data with known 4-cluster structure

set.seed(42)

# Parameters
n_total <- 300
n_per_segment <- 75
n_segments <- 4

# Create respondent IDs
respondent_id <- 1:n_total

# Create true segments (for validation)
true_segment <- rep(1:n_segments, each = n_per_segment)

# Generate satisfaction variables with cluster structure
# Segment 1: High satisfaction (mean ~4.5)
# Segment 2: Medium-high satisfaction (mean ~3.5)
# Segment 3: Medium-low satisfaction (mean ~2.5)
# Segment 4: Low satisfaction (mean ~1.5)

segment_means <- c(4.5, 3.5, 2.5, 1.5)

# Initialize data frame
data <- data.frame(
  respondent_id = respondent_id,
  true_segment = true_segment
)

# Generate 5 satisfaction variables (q1-q5)
for (i in 1:5) {
  var_name <- paste0("q", i)
  values <- numeric(n_total)

  for (seg in 1:n_segments) {
    seg_idx <- which(true_segment == seg)
    # Generate from normal distribution with segment-specific mean
    values[seg_idx] <- rnorm(n_per_segment,
                             mean = segment_means[seg],
                             sd = 0.5)
    # Clip to 1-5 scale
    values[seg_idx] <- pmin(pmax(values[seg_idx], 1), 5)
  }

  data[[var_name]] <- round(values, 1)
}

# Add some demographic variables for profiling
# Age: varies by segment
data$age <- numeric(n_total)
for (seg in 1:n_segments) {
  seg_idx <- which(true_segment == seg)
  # Segment 1: older, Segment 4: younger
  age_mean <- 60 - (seg - 1) * 10
  data$age[seg_idx] <- round(rnorm(n_per_segment, mean = age_mean, sd = 8))
  data$age[seg_idx] <- pmin(pmax(data$age[seg_idx], 18), 85)
}

# Gender: random
data$gender <- sample(c("M", "F"), n_total, replace = TRUE)

# Tenure (years): varies by segment
data$tenure_years <- numeric(n_total)
for (seg in 1:n_segments) {
  seg_idx <- which(true_segment == seg)
  # Segment 1: longer tenure
  tenure_mean <- 3 + (seg - 1) * 2
  data$tenure_years[seg_idx] <- round(rnorm(n_per_segment, mean = tenure_mean, sd = 2))
  data$tenure_years[seg_idx] <- pmax(data$tenure_years[seg_idx], 0)
}

# Add a few missing values to test missing data handling
# Randomly set 2% of satisfaction data to NA
for (var in paste0("q", 1:5)) {
  missing_idx <- sample(1:n_total, size = round(0.02 * n_total))
  data[[var]][missing_idx] <- NA
}

# Save as CSV
write.csv(data, "modules/segment/test_data/test_survey_data.csv", row.names = FALSE)

cat("✓ Generated test data:\n")
cat(sprintf("  Respondents: %d\n", n_total))
cat(sprintf("  True segments: %d\n", n_segments))
cat(sprintf("  Satisfaction variables: 5 (q1-q5)\n"))
cat(sprintf("  Profile variables: age, gender, tenure_years\n"))
cat(sprintf("  Missing values: ~2%% random\n"))
cat("\nSegment characteristics:\n")
for (seg in 1:n_segments) {
  seg_idx <- which(true_segment == seg)
  cat(sprintf("  Segment %d (n=%d): Satisfaction mean=%.1f, Age mean=%.0f, Tenure mean=%.1f\n",
              seg, length(seg_idx),
              mean(data$q1[seg_idx], na.rm = TRUE),
              mean(data$age[seg_idx]),
              mean(data$tenure_years[seg_idx])))
}

cat("\nFile saved: modules/segment/test_data/test_survey_data.csv\n")
