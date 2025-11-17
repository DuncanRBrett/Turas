# ==============================================================================
# GENERATE TEST DATA WITH 20 VARIABLES FOR VARIABLE SELECTION TESTING
# ==============================================================================
# Creates synthetic survey data with 20 satisfaction variables
# Includes correlations and varying variance for variable selection testing
# ==============================================================================

set.seed(456)  # Different seed for variety

# Parameters
n_respondents <- 300
n_clusters <- 4

# Generate cluster assignments
cluster_assignment <- sample(1:n_clusters, n_respondents, replace = TRUE)

# Initialize data frame
test_data <- data.frame(
  respondent_id = paste0("R", sprintf("%03d", 1:n_respondents))
)

# ==============================================================================
# GENERATE 20 SATISFACTION VARIABLES
# ==============================================================================
# Create 5 groups of 4 correlated variables each
# This simulates survey themes (e.g., product, service, support, value, overall)

# Group 1: Product Satisfaction (q1-q4) - High variance
for (i in 1:4) {
  var_name <- paste0("q", i)
  cluster_means <- c(2, 3.5, 4.5, 5) + rnorm(4, 0, 0.2)
  test_data[[var_name]] <- cluster_means[cluster_assignment] + rnorm(n_respondents, 0, 0.8)
}

# Group 2: Service Satisfaction (q5-q8) - Correlated with Group 1
for (i in 5:8) {
  var_name <- paste0("q", i)
  cluster_means <- c(2.2, 3.6, 4.3, 4.9) + rnorm(4, 0, 0.2)
  test_data[[var_name]] <- cluster_means[cluster_assignment] + rnorm(n_respondents, 0, 0.9)
}

# Group 3: Support Satisfaction (q9-q12) - Medium variance
for (i in 9:12) {
  var_name <- paste0("q", i)
  cluster_means <- c(2.5, 3.3, 4.6, 5.2) + rnorm(4, 0, 0.2)
  test_data[[var_name]] <- cluster_means[cluster_assignment] + rnorm(n_respondents, 0, 0.7)
}

# Group 4: Value Satisfaction (q13-q16) - Higher correlation within group
for (i in 13:16) {
  var_name <- paste0("q", i)
  cluster_means <- c(1.8, 3.2, 4.8, 5.3) + rnorm(4, 0, 0.2)
  test_data[[var_name]] <- cluster_means[cluster_assignment] + rnorm(n_respondents, 0, 1.0)
}

# Group 5: Overall Experience (q17-q20) - One with very low variance
for (i in 17:19) {
  var_name <- paste0("q", i)
  cluster_means <- c(2.3, 3.4, 4.4, 5.1) + rnorm(4, 0, 0.2)
  test_data[[var_name]] <- cluster_means[cluster_assignment] + rnorm(n_respondents, 0, 0.85)
}

# q20: Low variance variable (everyone rates similarly - should be removed)
test_data$q20 <- 4.0 + rnorm(n_respondents, 0, 0.15)

# Clip to 1-5 scale
for (col in paste0("q", 1:20)) {
  test_data[[col]] <- pmax(1, pmin(5, test_data[[col]]))
}

# ==============================================================================
# ADD CORRELATIONS WITHIN GROUPS
# ==============================================================================
# Make some variables within each group highly correlated
# This will test correlation-based removal

# q2 highly correlated with q1
test_data$q2 <- 0.85 * test_data$q1 + 0.15 * test_data$q2

# q6 highly correlated with q5
test_data$q6 <- 0.82 * test_data$q5 + 0.18 * test_data$q6

# q14 highly correlated with q13
test_data$q14 <- 0.88 * test_data$q13 + 0.12 * test_data$q14

# Clip again after adding correlations
for (col in paste0("q", 1:20)) {
  test_data[[col]] <- pmax(1, pmin(5, test_data[[col]]))
}

# ==============================================================================
# ADD DEMOGRAPHIC VARIABLES
# ==============================================================================

# Age (correlated with cluster - younger = lower satisfaction)
age_means <- c(35, 42, 48, 55)
test_data$age <- round(age_means[cluster_assignment] + rnorm(n_respondents, 0, 8))

# Gender (balanced)
test_data$gender <- sample(c("Male", "Female"), n_respondents, replace = TRUE)

# Tenure years (correlated with cluster - longer tenure = higher satisfaction)
tenure_means <- c(1, 3, 5, 8)
test_data$tenure_years <- round(pmax(0, tenure_means[cluster_assignment] + rnorm(n_respondents, 0, 2)))

# ==============================================================================
# ADD MISSING DATA
# ==============================================================================
# Approximately 2% missing data randomly across satisfaction variables

missing_rate <- 0.02
for (col in paste0("q", 1:20)) {
  missing_idx <- sample(1:n_respondents, size = floor(n_respondents * missing_rate))
  test_data[[col]][missing_idx] <- NA
}

# ==============================================================================
# SAVE TEST DATA
# ==============================================================================

write.csv(test_data, "modules/segment/test_data/test_survey_data_20vars.csv", row.names = FALSE)

cat("✓ Generated test data with 20 variables\n")
cat(sprintf("  Respondents: %d\n", nrow(test_data)))
cat(sprintf("  Variables: %d satisfaction + 3 demographic\n", 20))
cat(sprintf("  True clusters: %d\n", n_clusters))
cat("\nVariable characteristics:\n")
cat("  - q1-q4: Product satisfaction (high variance)\n")
cat("  - q5-q8: Service satisfaction (q6 correlated with q5)\n")
cat("  - q9-q12: Support satisfaction (medium variance)\n")
cat("  - q13-q16: Value satisfaction (q14 correlated with q13)\n")
cat("  - q17-q20: Overall experience (q20 has very low variance)\n")
cat("  - q2 highly correlated with q1\n")
cat("  - Missing data: ~2% random\n")
cat("\nExpected variable selection behavior:\n")
cat("  - Remove: q20 (low variance)\n")
cat("  - Remove: q2, q6, q14 (high correlation)\n")
cat("  - Reduce from 20 to ~10 variables using variance ranking or factor analysis\n")
