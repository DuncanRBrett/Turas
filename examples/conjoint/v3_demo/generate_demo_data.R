# ==============================================================================
# GENERATE DEMO DATA FOR CONJOINT v3.0 TEST PROJECT
# ==============================================================================
#
# Creates a realistic CBC dataset with known two-segment structure:
#   Segment 1 (~50%): Brand-driven (strong Brand preference, weak Price sensitivity)
#   Segment 2 (~50%): Price-driven (strong Price sensitivity, weak Brand preference)
#
# 300 respondents × 12 tasks × 3 alternatives = 10,800 rows
# ==============================================================================

set.seed(2026)

# --- Design parameters ---
n_respondents <- 300
n_tasks       <- 12
n_alts        <- 3

attributes <- list(
  Brand   = c("TechPro", "ValueMax", "PremiumX"),
  Price   = c("$199", "$299", "$399"),
  Screen  = c("5.5 inch", "6.1 inch", "6.7 inch"),
  Battery = c("3000mAh", "4500mAh", "5000mAh"),
  Storage = c("64GB", "128GB", "256GB")
)

# --- True utilities per segment ---
# Segment 1: Brand-driven
utils_seg1 <- c(
  BrandValueMax  = 0.3,  BrandPremiumX = 1.2,   # Strong brand pref
  `Price$299`    = -0.3, `Price$399`   = -0.5,   # Weak price sensitivity
  `Screen6.1 inch` = 0.2, `Screen6.7 inch` = 0.4,
  `Battery4500mAh` = 0.3, `Battery5000mAh` = 0.5,
  Storage128GB   = 0.2,  Storage256GB  = 0.4
)

# Segment 2: Price-driven
utils_seg2 <- c(
  BrandValueMax  = 0.1,  BrandPremiumX = 0.2,    # Weak brand pref
  `Price$299`    = -0.8, `Price$399`   = -1.5,    # Strong price sensitivity
  `Screen6.1 inch` = 0.3, `Screen6.7 inch` = 0.5,
  `Battery4500mAh` = 0.4, `Battery5000mAh` = 0.6,
  Storage128GB   = 0.3,  Storage256GB  = 0.5
)

# --- Assign segments ---
segment <- sample(c(1, 2), n_respondents, replace = TRUE, prob = c(0.45, 0.55))

# --- Generate choice data ---
all_rows <- vector("list", n_respondents * n_tasks * n_alts)
idx <- 0

for (r in seq_len(n_respondents)) {
  seg_utils <- if (segment[r] == 1) utils_seg1 else utils_seg2

  # Add individual-level noise (heterogeneity within segment)
  ind_noise <- rnorm(length(seg_utils), 0, 0.15)
  ind_utils <- seg_utils + ind_noise

  for (t in seq_len(n_tasks)) {
    task_id <- (r - 1) * n_tasks + t
    task_V <- numeric(n_alts)

    for (a in seq_len(n_alts)) {
      idx <- idx + 1

      # Random attribute levels
      row <- list(resp_id = r, choice_set_id = task_id, alternative_id = a)
      V <- 0

      for (attr_name in names(attributes)) {
        lvls <- attributes[[attr_name]]
        chosen_lvl <- sample(lvls, 1)
        row[[attr_name]] <- chosen_lvl

        # Calculate utility
        for (i in 2:length(lvls)) {
          coef_name <- paste0(attr_name, lvls[i])
          if (coef_name %in% names(ind_utils)) {
            V <- V + (chosen_lvl == lvls[i]) * ind_utils[coef_name]
          }
        }
      }

      task_V[a] <- V
      row$V <- V
      all_rows[[idx]] <- row
    }

    # Simulate choice (MNL with Gumbel error)
    eps <- -log(-log(runif(n_alts)))
    U <- task_V + eps
    winner <- which.max(U)

    for (a in seq_len(n_alts)) {
      row_idx <- idx - n_alts + a
      all_rows[[row_idx]]$chosen <- as.integer(a == winner)
      all_rows[[row_idx]]$V <- NULL
    }
  }
}

# --- Convert to data frame ---
data <- do.call(rbind, lapply(all_rows, function(x) as.data.frame(x, stringsAsFactors = FALSE)))

# --- Write CSV ---
output_path <- file.path(dirname(sys.frame(1)$ofile %||% "."), "demo_data.csv")
write.csv(data, output_path, row.names = FALSE)

cat(sprintf("Generated %d rows (%d respondents × %d tasks × %d alts)\n",
            nrow(data), n_respondents, n_tasks, n_alts))
cat(sprintf("Segment 1 (Brand-driven): %d respondents\n", sum(segment == 1)))
cat(sprintf("Segment 2 (Price-driven): %d respondents\n", sum(segment == 2)))
cat(sprintf("Written to: %s\n", output_path))

# Also save segment truth for validation
seg_truth <- data.frame(
  resp_id = seq_len(n_respondents),
  true_segment = segment,
  stringsAsFactors = FALSE
)
seg_path <- file.path(dirname(output_path), "segment_truth.csv")
write.csv(seg_truth, seg_path, row.names = FALSE)
cat(sprintf("Segment truth written to: %s\n", seg_path))
