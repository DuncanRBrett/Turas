# ==============================================================================
# TURAS SEGMENTATION DEMO - GENERATE SYNTHETIC CUSTOMER DATA
# ==============================================================================
# Creates an 800-respondent telecom/retail customer dataset with 4 embedded
# true segments for demonstrating the Turas segmentation module.
#
# Segments:
#   1. Premium Loyalists (~25%) - High satisfaction, high WTP, strong loyalty
#   2. Price Seekers      (~30%) - Low-mid satisfaction, very price sensitive
#   3. Digital Enthusiasts (~20%) - High digital engagement, tech-savvy
#   4. Passive Users       (~25%) - Average everything, low engagement
#
# Variables:
#   12 clustering variables (1-10 scales)
#   Demographics: age_group, gender, region, tenure_years, income_bracket
#   Behavioral:   purchase_frequency, channel_preference, nps_score
#   ID:           resp_001 through resp_800
#
# Usage:
#   source("generate_demo_data.R")
#   # Creates demo_customer_data.csv in the same directory
#
# Version: 1.0
# ==============================================================================

cat("==============================================================\n")
cat("  TURAS Demo Data Generator - Telecom/Retail Customer Dataset\n")
cat("==============================================================\n\n")

# Reproducibility
set.seed(2024)

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------

n_total <- 800

# Segment sizes (approximate proportions)
seg_props <- c(
  premium_loyalists  = 0.25,
  price_seekers      = 0.30,
  digital_enthusiasts = 0.20,
  passive_users      = 0.25
)

seg_sizes <- round(seg_props * n_total)
# Adjust last segment to ensure exact total
seg_sizes[length(seg_sizes)] <- n_total - sum(seg_sizes[-length(seg_sizes)])

cat(sprintf("Total respondents: %d\n", n_total))
cat("Segment sizes:\n")
for (i in seq_along(seg_sizes)) {
  cat(sprintf("  %s: %d (%.0f%%)\n", names(seg_sizes)[i], seg_sizes[i],
              100 * seg_sizes[i] / n_total))
}
cat("\n")


# --------------------------------------------------------------------------
# Helper: Bounded Normal Draw
# --------------------------------------------------------------------------
# Generates values from a normal distribution, bounded to [lo, hi] and
# rounded to integers.

bounded_rnorm <- function(n, mean, sd, lo = 1, hi = 10) {
  x <- rnorm(n, mean = mean, sd = sd)
  x <- pmin(pmax(round(x), lo), hi)
  as.integer(x)
}


# --------------------------------------------------------------------------
# Generate Clustering Variables (12 variables, 1-10 scale)
# --------------------------------------------------------------------------
# Each segment has a distinct profile across these variables.
# Parameters are (mean, sd) for each variable within each segment.
# Moderate noise ensures realistic overlap between segments.

# Segment profile definitions: list of (mean, sd) per variable
# Rows = segments, columns defined below
#
# Variables:
#   overall_satisfaction, service_quality, value_for_money, brand_trust,
#   digital_experience, customer_support, product_range,
#   innovation_perception, ease_of_use, recommendation_likelihood,
#   loyalty_intent, price_sensitivity

segment_profiles <- list(
  premium_loyalists = list(
    overall_satisfaction       = c(8.2, 1.0),
    service_quality            = c(8.5, 0.9),
    value_for_money            = c(7.0, 1.3),
    brand_trust                = c(8.7, 0.8),
    digital_experience         = c(7.0, 1.4),
    customer_support           = c(8.0, 1.1),
    product_range              = c(7.8, 1.2),
    innovation_perception      = c(7.2, 1.3),
    ease_of_use                = c(8.0, 1.0),
    recommendation_likelihood  = c(8.8, 0.9),
    loyalty_intent             = c(9.0, 0.8),
    price_sensitivity          = c(3.5, 1.5)
  ),
  price_seekers = list(
    overall_satisfaction       = c(4.5, 1.5),
    service_quality            = c(4.8, 1.4),
    value_for_money            = c(3.5, 1.6),
    brand_trust                = c(4.0, 1.5),
    digital_experience         = c(5.0, 1.8),
    customer_support           = c(4.2, 1.6),
    product_range              = c(5.0, 1.5),
    innovation_perception      = c(4.5, 1.6),
    ease_of_use                = c(5.5, 1.7),
    recommendation_likelihood  = c(3.8, 1.6),
    loyalty_intent             = c(3.2, 1.5),
    price_sensitivity          = c(9.0, 0.8)
  ),
  digital_enthusiasts = list(
    overall_satisfaction       = c(6.5, 1.3),
    service_quality            = c(6.0, 1.4),
    value_for_money            = c(6.0, 1.4),
    brand_trust                = c(6.2, 1.3),
    digital_experience         = c(9.0, 0.7),
    customer_support           = c(5.5, 1.5),
    product_range              = c(6.5, 1.3),
    innovation_perception      = c(8.8, 0.8),
    ease_of_use                = c(8.5, 0.9),
    recommendation_likelihood  = c(7.0, 1.3),
    loyalty_intent             = c(6.0, 1.5),
    price_sensitivity          = c(5.5, 1.6)
  ),
  passive_users = list(
    overall_satisfaction       = c(5.5, 1.2),
    service_quality            = c(5.5, 1.2),
    value_for_money            = c(5.5, 1.3),
    brand_trust                = c(5.3, 1.3),
    digital_experience         = c(4.5, 1.5),
    customer_support           = c(5.0, 1.3),
    product_range              = c(5.5, 1.2),
    innovation_perception      = c(4.8, 1.4),
    ease_of_use                = c(5.8, 1.3),
    recommendation_likelihood  = c(5.0, 1.4),
    loyalty_intent             = c(5.0, 1.4),
    price_sensitivity          = c(6.0, 1.5)
  )
)

clustering_var_names <- names(segment_profiles[[1]])

cat(sprintf("Generating %d clustering variables...\n", length(clustering_var_names)))

# Generate data segment by segment
clustering_data_list <- list()

for (seg_name in names(segment_profiles)) {
  n_seg <- seg_sizes[seg_name]
  profile <- segment_profiles[[seg_name]]

  seg_df <- as.data.frame(lapply(profile, function(params) {
    bounded_rnorm(n_seg, mean = params[1], sd = params[2])
  }))

  clustering_data_list[[seg_name]] <- seg_df
}

# Combine all segments
clustering_data <- do.call(rbind, clustering_data_list)

# Shuffle rows (important: prevents segment ordering from leaking into analysis)
shuffle_idx <- sample(nrow(clustering_data))
clustering_data <- clustering_data[shuffle_idx, ]
true_segment <- rep(names(seg_sizes), times = seg_sizes)[shuffle_idx]


# --------------------------------------------------------------------------
# Generate Demographics
# --------------------------------------------------------------------------

cat("Generating demographic variables...\n")

n <- n_total

# Age group - segment-correlated
# Premium Loyalists skew older, Digital Enthusiasts younger, etc.
age_groups <- c("18-24", "25-34", "35-44", "45-54", "55+")

age_probs <- list(
  premium_loyalists   = c(0.05, 0.15, 0.25, 0.30, 0.25),
  price_seekers       = c(0.20, 0.30, 0.25, 0.15, 0.10),
  digital_enthusiasts = c(0.30, 0.35, 0.20, 0.10, 0.05),
  passive_users       = c(0.15, 0.20, 0.25, 0.25, 0.15)
)

age_group <- character(n)
for (seg_name in names(seg_sizes)) {
  mask <- true_segment == seg_name
  n_seg <- sum(mask)
  age_group[mask] <- sample(age_groups, n_seg, replace = TRUE,
                            prob = age_probs[[seg_name]])
}

# Gender
gender_options <- c("M", "F", "Other")
gender <- sample(gender_options, n, replace = TRUE, prob = c(0.48, 0.48, 0.04))

# Region
region_options <- c("North", "South", "East", "West")
region <- sample(region_options, n, replace = TRUE)

# Tenure years - correlated with segment
tenure_years <- numeric(n)
tenure_params <- list(
  premium_loyalists   = c(mean = 7.0, sd = 3.0),
  price_seekers       = c(mean = 2.5, sd = 2.0),
  digital_enthusiasts = c(mean = 3.5, sd = 2.5),
  passive_users       = c(mean = 4.5, sd = 2.5)
)

for (seg_name in names(seg_sizes)) {
  mask <- true_segment == seg_name
  n_seg <- sum(mask)
  params <- tenure_params[[seg_name]]
  vals <- rnorm(n_seg, mean = params[1], sd = params[2])
  tenure_years[mask] <- pmax(round(vals, 1), 0.5)
}

# Income bracket - correlated with segment
income_options <- c("Low", "Medium", "High")
income_probs <- list(
  premium_loyalists   = c(0.10, 0.30, 0.60),
  price_seekers       = c(0.50, 0.35, 0.15),
  digital_enthusiasts = c(0.15, 0.45, 0.40),
  passive_users       = c(0.30, 0.45, 0.25)
)

income_bracket <- character(n)
for (seg_name in names(seg_sizes)) {
  mask <- true_segment == seg_name
  n_seg <- sum(mask)
  income_bracket[mask] <- sample(income_options, n_seg, replace = TRUE,
                                 prob = income_probs[[seg_name]])
}


# --------------------------------------------------------------------------
# Generate Behavioral Variables
# --------------------------------------------------------------------------

cat("Generating behavioral variables...\n")

# Purchase frequency (1-12 per year)
purchase_freq <- integer(n)
pf_params <- list(
  premium_loyalists   = c(mean = 8.0, sd = 2.5),
  price_seekers       = c(mean = 5.0, sd = 2.5),
  digital_enthusiasts = c(mean = 7.0, sd = 2.0),
  passive_users       = c(mean = 3.5, sd = 2.0)
)

for (seg_name in names(seg_sizes)) {
  mask <- true_segment == seg_name
  n_seg <- sum(mask)
  params <- pf_params[[seg_name]]
  vals <- rnorm(n_seg, mean = params[1], sd = params[2])
  purchase_freq[mask] <- as.integer(pmin(pmax(round(vals), 1), 12))
}

# Channel preference
channel_options <- c("Online", "Store", "Both")
channel_probs <- list(
  premium_loyalists   = c(0.25, 0.35, 0.40),
  price_seekers       = c(0.40, 0.40, 0.20),
  digital_enthusiasts = c(0.65, 0.10, 0.25),
  passive_users       = c(0.20, 0.45, 0.35)
)

channel_preference <- character(n)
for (seg_name in names(seg_sizes)) {
  mask <- true_segment == seg_name
  n_seg <- sum(mask)
  channel_preference[mask] <- sample(channel_options, n_seg, replace = TRUE,
                                     prob = channel_probs[[seg_name]])
}

# NPS score (0-10)
nps_score <- integer(n)
nps_params <- list(
  premium_loyalists   = c(mean = 8.5, sd = 1.2),
  price_seekers       = c(mean = 4.0, sd = 2.0),
  digital_enthusiasts = c(mean = 7.0, sd = 1.5),
  passive_users       = c(mean = 5.5, sd = 1.8)
)

for (seg_name in names(seg_sizes)) {
  mask <- true_segment == seg_name
  n_seg <- sum(mask)
  params <- nps_params[[seg_name]]
  vals <- rnorm(n_seg, mean = params[1], sd = params[2])
  nps_score[mask] <- as.integer(pmin(pmax(round(vals), 0), 10))
}


# --------------------------------------------------------------------------
# Assemble Dataset
# --------------------------------------------------------------------------

cat("Assembling final dataset...\n")

demo_data <- data.frame(
  id = sprintf("resp_%03d", 1:n),
  clustering_data,
  age_group = age_group,
  gender = gender,
  region = region,
  tenure_years = tenure_years,
  income_bracket = income_bracket,
  purchase_frequency = purchase_freq,
  channel_preference = channel_preference,
  nps_score = nps_score,
  stringsAsFactors = FALSE
)


# --------------------------------------------------------------------------
# Introduce ~3% MCAR Missingness to Clustering Variables
# --------------------------------------------------------------------------

cat("Introducing ~3% MCAR missingness to clustering variables...\n")

missingness_rate <- 0.03
n_cells <- n * length(clustering_var_names)
n_missing <- round(n_cells * missingness_rate)

# Randomly select cells to make NA
missing_rows <- sample(1:n, n_missing, replace = TRUE)
missing_cols <- sample(clustering_var_names, n_missing, replace = TRUE)

for (i in seq_len(n_missing)) {
  demo_data[missing_rows[i], missing_cols[i]] <- NA
}

# Report actual missingness
total_na <- sum(is.na(demo_data[, clustering_var_names]))
actual_rate <- total_na / n_cells
cat(sprintf("  Actual missingness: %d cells (%.1f%%)\n", total_na, 100 * actual_rate))


# --------------------------------------------------------------------------
# Save to CSV
# --------------------------------------------------------------------------

# Determine the output path - save alongside this script
script_dir <- tryCatch({
  # Works when called via source()
  dirname(sys.frame(1)$ofile)
}, error = function(e) {
  # Fallback: try commandArgs for Rscript execution
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    dirname(normalizePath(sub("^--file=", "", file_arg[1])))
  } else {
    getwd()
  }
})

output_path <- file.path(script_dir, "demo_customer_data.csv")

write.csv(demo_data, output_path, row.names = FALSE)

cat(sprintf("\nDataset saved: %s\n", output_path))
cat(sprintf("  Rows: %d\n", nrow(demo_data)))
cat(sprintf("  Columns: %d\n", ncol(demo_data)))
cat(sprintf("  Clustering variables: %d\n", length(clustering_var_names)))
cat(sprintf("  Profile variables: %d\n",
            ncol(demo_data) - length(clustering_var_names) - 1))

# --------------------------------------------------------------------------
# Summary Statistics
# --------------------------------------------------------------------------

cat("\n--- Clustering Variable Summary ---\n")
for (var in clustering_var_names) {
  vals <- demo_data[[var]]
  cat(sprintf("  %-30s  mean=%.1f  sd=%.1f  NA=%d\n",
              var, mean(vals, na.rm = TRUE), sd(vals, na.rm = TRUE),
              sum(is.na(vals))))
}

cat("\n--- Demographic Distribution ---\n")
cat("  Age groups:\n")
print(table(demo_data$age_group))
cat("  Gender:\n")
print(table(demo_data$gender))
cat("  Region:\n")
print(table(demo_data$region))
cat("  Income bracket:\n")
print(table(demo_data$income_bracket))

cat("\n--- Behavioral Summary ---\n")
cat(sprintf("  Purchase frequency: mean=%.1f, sd=%.1f\n",
            mean(demo_data$purchase_frequency), sd(demo_data$purchase_frequency)))
cat("  Channel preference:\n")
print(table(demo_data$channel_preference))
cat(sprintf("  NPS score: mean=%.1f, sd=%.1f\n",
            mean(demo_data$nps_score), sd(demo_data$nps_score)))

cat("\n==============================================================\n")
cat("  Demo data generation complete.\n")
cat("==============================================================\n")
