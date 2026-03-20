# ==============================================================================
# MAXDIFF DEMO - SYNTHETIC DATA GENERATOR
# ==============================================================================
# Generates realistic MaxDiff survey data for demonstrating the module.
#
# SCENARIO: Smartphone Feature Prioritization Study
# - 12 features tested across 200 respondents
# - 3 latent segments with distinct preference patterns
# - Balanced design: 4 items per task, 10 tasks, 3 versions
# - Includes weight variable (random weights 0.5 to 2.0)
# - Includes anchor question (must-have features, comma-separated item IDs)
# - Demographics: Age group, Gender
#
# OUTPUTS:
#   demo_data.csv       - Survey responses with weights and anchor column
#   true_utilities.csv  - Known true utilities per respondent (for validation)
#   segment_truth.csv   - True segment assignments (for validation)
#
# USAGE:
#   source("examples/maxdiff/demo_showcase/generate_demo_data.R")
# ==============================================================================

cat("\n=== MaxDiff Demo Data Generator ===\n\n")

set.seed(42)

# ==============================================================================
# ITEM DEFINITIONS
# ==============================================================================

items <- data.frame(
  Item_ID = paste0("F", sprintf("%02d", 1:12)),
  Item_Label = c(
    "Battery Life",
    "Camera Quality",
    "Screen Size",
    "Affordable Price",
    "Brand Reputation",
    "Storage Capacity",
    "Processor Speed",
    "Water Resistance",
    "5G Connectivity",
    "Wireless Charging",
    "Lightweight Design",
    "Premium Build Quality"
  ),
  stringsAsFactors = FALSE
)

n_items <- nrow(items)
n_resp <- 200
n_tasks <- 10
items_per_task <- 4
n_versions <- 3

cat(sprintf("Items: %d\n", n_items))
cat(sprintf("Respondents: %d\n", n_resp))
cat(sprintf("Tasks per respondent: %d\n", n_tasks))
cat(sprintf("Items per task: %d\n", items_per_task))
cat(sprintf("Design versions: %d\n", n_versions))

# ==============================================================================
# SEGMENT DEFINITIONS & TRUE UTILITIES
# ==============================================================================

# Three latent segments with distinct preference patterns
# Utilities are on the MNL scale

# Tech-focused (35%): Value performance features
tech_utils <- c(
  2.0,   # Battery Life - important but not top
  1.5,   # Camera Quality
  0.5,   # Screen Size
  -0.5,  # Affordable Price - not a priority
  -0.3,  # Brand Reputation
  1.8,   # Storage Capacity - very important
  2.5,   # Processor Speed - TOP priority
  0.8,   # Water Resistance
  2.2,   # 5G Connectivity - very important
  1.0,   # Wireless Charging
  -1.0,  # Lightweight Design
  0.3    # Premium Build Quality
)

# Value-focused (40%): Price-sensitive, practical features
value_utils <- c(
  2.8,   # Battery Life - TOP priority
  1.0,   # Camera Quality
  0.3,   # Screen Size
  2.5,   # Affordable Price - very important
  -0.5,  # Brand Reputation
  1.5,   # Storage Capacity
  0.5,   # Processor Speed
  0.8,   # Water Resistance
  -0.3,  # 5G Connectivity
  -0.5,  # Wireless Charging
  1.2,   # Lightweight Design
  -1.5   # Premium Build Quality
)

# Design-focused (25%): Aesthetics and brand matter
design_utils <- c(
  1.0,   # Battery Life
  2.5,   # Camera Quality - TOP priority
  1.5,   # Screen Size
  -1.0,  # Affordable Price
  2.0,   # Brand Reputation - very important
  0.5,   # Storage Capacity
  0.3,   # Processor Speed
  1.0,   # Water Resistance
  0.5,   # 5G Connectivity
  1.5,   # Wireless Charging
  0.8,   # Lightweight Design
  2.2    # Premium Build Quality - very important
)

# Segment assignment
segment_probs <- c(0.35, 0.40, 0.25)
segment_assignment <- sample(1:3, n_resp, replace = TRUE, prob = segment_probs)
segment_labels <- c("Tech-Focused", "Value-Focused", "Design-Focused")

# Generate individual utilities with noise
true_utils <- matrix(0, nrow = n_resp, ncol = n_items)
colnames(true_utils) <- items$Item_ID

for (r in 1:n_resp) {
  seg <- segment_assignment[r]
  base_utils <- switch(seg, tech_utils, value_utils, design_utils)
  # Add individual-level noise (heterogeneity)
  true_utils[r, ] <- base_utils + rnorm(n_items, 0, 0.6)
}

# ==============================================================================
# EXPERIMENTAL DESIGN (Balanced)
# ==============================================================================

cat("\nGenerating balanced experimental design...\n")

generate_balanced_design <- function(n_items, items_per_task, n_tasks, n_versions, item_ids) {
  design_rows <- list()

  for (v in 1:n_versions) {
    for (t in 1:n_tasks) {
      shown <- sample(1:n_items, items_per_task)
      row <- data.frame(
        Version = v,
        Task_Number = t,
        stringsAsFactors = FALSE
      )
      for (pos in 1:items_per_task) {
        row[[sprintf("Item%d_ID", pos)]] <- item_ids[shown[pos]]
      }
      design_rows[[length(design_rows) + 1]] <- row
    }
  }

  do.call(rbind, design_rows)
}

design <- generate_balanced_design(n_items, items_per_task, n_tasks, n_versions, items$Item_ID)
cat(sprintf("  Design matrix: %d rows\n", nrow(design)))

# ==============================================================================
# SIMULATE CHOICES (MNL model)
# ==============================================================================

cat("Simulating survey responses...\n")

# Assign versions to respondents
resp_versions <- sample(1:n_versions, n_resp, replace = TRUE)

# Generate demographics
age_groups <- sample(c("18-34", "35-54", "55+"), n_resp, replace = TRUE,
                     prob = c(0.35, 0.40, 0.25))
genders <- sample(c("Male", "Female"), n_resp, replace = TRUE, prob = c(0.48, 0.52))

# Generate weight variable (random weights between 0.5 and 2.0)
# Weights are correlated with demographics to be realistic:
# younger respondents slightly over-weighted, older slightly under-weighted
resp_weights <- numeric(n_resp)
for (r in 1:n_resp) {
  base_weight <- runif(1, 0.5, 2.0)
  # Slight demographic adjustment for realism
  if (age_groups[r] == "18-34") base_weight <- base_weight * 1.1
  if (age_groups[r] == "55+") base_weight <- base_weight * 0.9
  resp_weights[r] <- round(pmin(pmax(base_weight, 0.5), 2.0), 4)
}

# Build wide-format response data (one row per respondent)
# Module expects separate columns per task: Best_T1, Worst_T1, Best_T2, Worst_T2, etc.
resp_rows <- list()

for (r in 1:n_resp) {
  v <- resp_versions[r]
  version_design <- design[design$Version == v, ]

  row <- list(
    Respondent_ID = sprintf("R%03d", r),
    Version = v
  )

  for (t in 1:n_tasks) {
    task_design <- version_design[version_design$Task_Number == t, ]
    shown_item_ids <- as.character(unlist(task_design[1, grep("^Item\\d+_ID$", names(task_design))]))
    shown_items <- match(shown_item_ids, items$Item_ID)

    # Get utilities for shown items
    utils_shown <- true_utils[r, shown_items]

    # MNL choice probability for BEST
    exp_u <- exp(utils_shown)
    prob_best <- exp_u / sum(exp_u)
    best_pos <- sample(seq_along(shown_items), 1, prob = prob_best)

    # MNL choice probability for WORST (among remaining)
    remaining_idx <- seq_along(shown_items)[-best_pos]
    utils_remaining <- true_utils[r, shown_items[remaining_idx]]
    exp_u_neg <- exp(-utils_remaining)
    prob_worst <- exp_u_neg / sum(exp_u_neg)
    worst_pos <- remaining_idx[sample(length(remaining_idx), 1, prob = prob_worst)]

    # Store best/worst as item IDs (matching design matrix)
    row[[sprintf("Best_T%d", t)]] <- shown_item_ids[best_pos]
    row[[sprintf("Worst_T%d", t)]] <- shown_item_ids[worst_pos]
  }

  resp_rows[[r]] <- as.data.frame(row, stringsAsFactors = FALSE)
}

survey_data <- do.call(rbind, resp_rows)

# Add demographics
survey_data$Age_Group <- age_groups
survey_data$Gender <- genders
survey_data$Segment_True <- segment_labels[segment_assignment]

# Add weight variable
survey_data$Weight <- resp_weights

# ==============================================================================
# ANCHOR QUESTION (Must-Have items)
# ==============================================================================

cat("Generating anchor responses...\n")

# For each respondent, items with high utility are more likely to be flagged as must-have
# Anchor_Items column contains comma-separated item IDs
anchor_data <- character(n_resp)
for (r in 1:n_resp) {
  # Probability of flagging as must-have based on utility
  scaled_utils <- (true_utils[r, ] - min(true_utils[r, ])) / (max(true_utils[r, ]) - min(true_utils[r, ]))
  # Higher utilities more likely to be must-have, with threshold
  flag_probs <- pmin(scaled_utils^2 * 0.8, 0.9)
  # Only top items get flagged (roughly 2-4 per respondent)
  flags <- rbinom(n_items, 1, flag_probs * 0.4)
  flagged_items <- items$Item_ID[flags == 1]
  anchor_data[r] <- paste(flagged_items, collapse = ",")
}

# Add anchor to survey data (already one row per respondent)
survey_data$Anchor_Items <- anchor_data

# ==============================================================================
# SAVE FILES
# ==============================================================================

demo_dir <- file.path("examples", "maxdiff", "demo_showcase")
if (!dir.exists(demo_dir)) dir.create(demo_dir, recursive = TRUE)

# Save survey data (includes weights and anchor column)
data_path <- file.path(demo_dir, "demo_data.csv")
write.csv(survey_data, data_path, row.names = FALSE)
cat(sprintf("\nSaved: %s (%d rows, %d columns)\n", data_path, nrow(survey_data), ncol(survey_data)))

# Save design as xlsx (required by MaxDiff module)
design_path <- file.path(demo_dir, "demo_design.xlsx")
if (requireNamespace("openxlsx", quietly = TRUE)) {
  wb_design <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb_design, "DESIGN")
  openxlsx::writeData(wb_design, "DESIGN", design)
  openxlsx::saveWorkbook(wb_design, design_path, overwrite = TRUE)
} else {
  # Fallback to csv
  design_path <- file.path(demo_dir, "demo_design.csv")
  write.csv(design, design_path, row.names = FALSE)
}
cat(sprintf("Saved: %s (%d rows)\n", design_path, nrow(design)))

# Save segment truth (for validation)
truth_path <- file.path(demo_dir, "segment_truth.csv")
segment_truth <- survey_data[, c("Respondent_ID", "Age_Group", "Gender", "Segment_True")]
write.csv(segment_truth, truth_path, row.names = FALSE)
cat(sprintf("Saved: %s\n", truth_path))

# Save true utilities (for validation)
true_utils_df <- as.data.frame(true_utils)
true_utils_df$Respondent_ID <- sprintf("R%03d", 1:n_resp)
true_utils_df$Segment <- segment_labels[segment_assignment]
truth_utils_path <- file.path(demo_dir, "true_utilities.csv")
write.csv(true_utils_df, truth_utils_path, row.names = FALSE)
cat(sprintf("Saved: %s\n", truth_utils_path))

cat("\n=== Data generation complete ===\n")
cat(sprintf("  %d respondents, %d items, %d tasks each\n", n_resp, n_items, n_tasks))
cat(sprintf("  Weight range: %.2f to %.2f\n", min(resp_weights), max(resp_weights)))
cat(sprintf("  Anchor column: Anchor_Items (comma-separated item IDs)\n"))
cat(sprintf("  Segments: Tech-Focused (%.0f%%), Value-Focused (%.0f%%), Design-Focused (%.0f%%)\n",
            mean(segment_assignment == 1) * 100,
            mean(segment_assignment == 2) * 100,
            mean(segment_assignment == 3) * 100))
cat("\nOutput files:\n")
cat(sprintf("  - %s\n", data_path))
cat(sprintf("  - %s\n", design_path))
cat(sprintf("  - %s\n", truth_path))
cat(sprintf("  - %s\n", truth_utils_path))
cat("\n")
