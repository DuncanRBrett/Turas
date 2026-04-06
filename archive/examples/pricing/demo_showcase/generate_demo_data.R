# =============================================================================
# Turas Pricing Module — Demo Data & Config Generator
# Product: CloudSync Pro (cloud storage SaaS, $9-$35/month)
# =============================================================================
#
# Creates:
#   1. demo_data.csv              — 500 synthetic survey respondents
#   2. Demo_Pricing_Config.xlsx   — VW + GG combined analysis config
#   3. Demo_Monadic_Config.xlsx   — Monadic analysis config
#
# Run from Turas project root:
#   source("examples/pricing/demo_showcase/generate_demo_data.R")
#
# Dependencies: openxlsx (for Excel config generation)
# =============================================================================

cat("\n")
cat("===========================================================\n")
cat("  CloudSync Pro — Synthetic Pricing Data Generator\n")
cat("===========================================================\n\n")

# ---------------------------------------------------------------------------
# 0. Setup
# ---------------------------------------------------------------------------

set.seed(2024)
n <- 500

# Output directory (same as this script)
demo_dir <- file.path("examples", "pricing", "demo_showcase")
if (!dir.exists(demo_dir)) dir.create(demo_dir, recursive = TRUE)

# ---------------------------------------------------------------------------
# 1. Assign Segments & Demographics
# ---------------------------------------------------------------------------

cat("Step 1: Generating respondent demographics...\n")

# Segment allocation: Individual 200, Small Business 175, Enterprise 125
segment <- c(
  rep("Individual", 200),
  rep("Small Business", 175),
  rep("Enterprise", 125)
)
segment <- sample(segment)  # shuffle

# Age groups — Enterprise skews older
age_probs <- list(
  "Individual"     = c(0.25, 0.30, 0.20, 0.15, 0.10),
  "Small Business"  = c(0.10, 0.25, 0.30, 0.20, 0.15),
  "Enterprise"     = c(0.05, 0.15, 0.25, 0.30, 0.25)
)
age_labels <- c("18-24", "25-34", "35-44", "45-54", "55+")

age_group <- character(n)
for (i in seq_len(n)) {
  age_group[i] <- sample(age_labels, 1, prob = age_probs[[segment[i]]])
}

# Weights — lognormal, clipped to [0.5, 2.0], normalised to mean ~1.0
raw_weights <- rlnorm(n, meanlog = 0, sdlog = 0.3)
raw_weights <- pmax(pmin(raw_weights, 2.0), 0.5)
weight <- round(raw_weights / mean(raw_weights), 3)

# ---------------------------------------------------------------------------
# 2. Van Westendorp Prices (per segment)
# ---------------------------------------------------------------------------

cat("Step 2: Generating Van Westendorp price perceptions...\n")

# Segment-specific price range parameters [min, max] for each question
# Designed to produce: PMC ~$10, OPP ~$16, IDP ~$22, PME ~$30 overall
vw_params <- list(
  "Individual" = list(
    too_cheap     = c(3, 10),    # "so cheap I'd doubt quality"
    cheap         = c(7, 16),    # "a bargain / good value"
    expensive     = c(14, 26),   # "getting expensive"
    too_expensive = c(20, 32)    # "too expensive to consider"
  ),
  "Small Business" = list(
    too_cheap     = c(5, 13),
    cheap         = c(9, 19),
    expensive     = c(18, 32),
    too_expensive = c(25, 40)
  ),
  "Enterprise" = list(
    too_cheap     = c(8, 18),
    cheap         = c(12, 24),
    expensive     = c(22, 40),
    too_expensive = c(30, 52)
  )
)

vw_too_cheap     <- numeric(n)
vw_cheap         <- numeric(n)
vw_expensive     <- numeric(n)
vw_too_expensive <- numeric(n)

for (i in seq_len(n)) {
  p <- vw_params[[segment[i]]]

  # Generate raw values from uniform distributions
  tc <- runif(1, p$too_cheap[1],     p$too_cheap[2])
  ch <- runif(1, p$cheap[1],         p$cheap[2])
  ex <- runif(1, p$expensive[1],     p$expensive[2])
  te <- runif(1, p$too_expensive[1], p$too_expensive[2])

  # Sort to enforce monotonicity (too_cheap <= cheap <= expensive <= too_expensive)
  sorted <- sort(c(tc, ch, ex, te))

  # Round to nearest $0.50 for realism
  vw_too_cheap[i]     <- round(sorted[1] * 2) / 2
  vw_cheap[i]         <- round(sorted[2] * 2) / 2
  vw_expensive[i]     <- round(sorted[3] * 2) / 2
  vw_too_expensive[i] <- round(sorted[4] * 2) / 2
}

# Introduce ~7% monotonicity violations (swap cheap & expensive)
n_violations <- round(n * 0.07)
violation_idx <- sample(seq_len(n), n_violations)
for (idx in violation_idx) {
  tmp <- vw_cheap[idx]
  vw_cheap[idx] <- vw_expensive[idx]
  vw_expensive[idx] <- tmp
}

cat(sprintf("   %d respondents with VW monotonicity violations (%.1f%%)\n",
            n_violations, n_violations / n * 100))

# ---------------------------------------------------------------------------
# 3. NMS Purchase Intent (1-5 Likert scale)
# ---------------------------------------------------------------------------

cat("Step 3: Generating NMS purchase intent...\n")

# At bargain price — generally high intent
# At expensive price — varies by segment (Enterprise more willing)
nms_params <- list(
  "Individual"     = list(cheap_probs = c(0.02, 0.05, 0.15, 0.38, 0.40),
                          exp_probs   = c(0.15, 0.25, 0.30, 0.20, 0.10)),
  "Small Business"  = list(cheap_probs = c(0.02, 0.05, 0.12, 0.35, 0.46),
                          exp_probs   = c(0.10, 0.20, 0.30, 0.25, 0.15)),
  "Enterprise"     = list(cheap_probs = c(0.01, 0.03, 0.10, 0.30, 0.56),
                          exp_probs   = c(0.05, 0.15, 0.25, 0.30, 0.25))
)

pi_cheap    <- integer(n)
pi_expensive <- integer(n)

for (i in seq_len(n)) {
  p <- nms_params[[segment[i]]]
  pi_cheap[i]    <- sample(1:5, 1, prob = p$cheap_probs)
  pi_expensive[i] <- sample(1:5, 1, prob = p$exp_probs)
}

# ---------------------------------------------------------------------------
# 4. Gabor-Granger (Wide Format, Binary)
# ---------------------------------------------------------------------------

cat("Step 4: Generating Gabor-Granger purchase intent...\n")

# Six price points: $9, $14, $19, $24, $29, $34
gg_prices <- c(9, 14, 19, 24, 29, 34)

# Logistic model for base purchase probability at each price
# P(buy | price) = plogis(intercept - slope * price)
gg_params <- list(
  "Individual"     = list(intercept = 3.2, slope = 0.13),
  "Small Business"  = list(intercept = 3.6, slope = 0.12),
  "Enterprise"     = list(intercept = 4.2, slope = 0.11)
)

gg_data <- matrix(0L, nrow = n, ncol = length(gg_prices))
colnames(gg_data) <- paste0("gg_price_", gg_prices)

for (i in seq_len(n)) {
  p <- gg_params[[segment[i]]]
  probs <- plogis(p$intercept - p$slope * gg_prices)

  # Generate with enforced monotonicity (if buy at higher price, buy at all lower)
  responses <- rbinom(length(gg_prices), 1, probs)

  # Enforce mostly-monotonic: find highest price with "yes", set all below to "yes"
  last_yes <- max(c(0, which(responses == 1)))
  if (last_yes > 0) {
    responses[1:last_yes] <- 1L
  }

  gg_data[i, ] <- responses
}

# Add ~3% random noise (flip some 1→0 or 0→1 at random positions)
n_noise <- round(n * length(gg_prices) * 0.03)
noise_rows <- sample(seq_len(n), n_noise, replace = TRUE)
noise_cols <- sample(seq_along(gg_prices), n_noise, replace = TRUE)
for (k in seq_len(n_noise)) {
  gg_data[noise_rows[k], noise_cols[k]] <- 1L - gg_data[noise_rows[k], noise_cols[k]]
}

cat(sprintf("   GG price points: $%s\n",
            paste(gg_prices, collapse = ", $")))

# ---------------------------------------------------------------------------
# 5. Monadic Price Testing (Randomised Cell)
# ---------------------------------------------------------------------------

cat("Step 5: Generating monadic price assignments...\n")

monadic_prices <- c(9.99, 14.99, 19.99, 24.99, 29.99, 34.99)

# Random assignment — each respondent sees exactly one price
monadic_price <- sample(monadic_prices, n, replace = TRUE)

# Logistic model: P(buy) = plogis(intercept + slope * price)
# Steeper slopes ensure a clear demand curve when pooled across segments.
# Target: ~85% intent at $9.99, ~20% at $34.99 (overall)
monadic_params <- list(
  "Individual"     = list(intercept = 3.5, slope = -0.18),
  "Small Business"  = list(intercept = 4.0, slope = -0.17),
  "Enterprise"     = list(intercept = 4.8, slope = -0.16)
)

monadic_intent <- integer(n)
for (i in seq_len(n)) {
  p <- monadic_params[[segment[i]]]
  prob <- plogis(p$intercept + p$slope * monadic_price[i])
  monadic_intent[i] <- rbinom(1, 1, prob)
}

# Cell size check
cell_table <- table(monadic_price)
cat(sprintf("   Monadic cells: %s\n",
            paste(sprintf("$%.2f (n=%d)", as.numeric(names(cell_table)), cell_table),
                  collapse = ", ")))

# ---------------------------------------------------------------------------
# 6. Assemble & Save Data Frame
# ---------------------------------------------------------------------------

cat("\nStep 6: Assembling dataset...\n")

demo_data <- data.frame(
  resp_id = 1:n,
  segment = segment,
  age_group = age_group,
  weight = weight,
  vw_too_cheap = vw_too_cheap,
  vw_cheap = vw_cheap,
  vw_expensive = vw_expensive,
  vw_too_expensive = vw_too_expensive,
  pi_cheap = pi_cheap,
  pi_expensive = pi_expensive,
  gg_data,
  monadic_price = monadic_price,
  monadic_intent = monadic_intent,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

csv_path <- file.path(demo_dir, "demo_data.csv")
write.csv(demo_data, csv_path, row.names = FALSE)
cat(sprintf("   Saved: %s (%d rows, %d columns)\n", csv_path, nrow(demo_data), ncol(demo_data)))

# ---------------------------------------------------------------------------
# 7. Create Excel Config Files
# ---------------------------------------------------------------------------

cat("\nStep 7: Creating Excel configuration files...\n")

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  cat("   WARNING: openxlsx not installed. Skipping config file generation.\n")
  cat("   Install with: install.packages('openxlsx')\n")
  cat("   Then re-run this script.\n\n")
} else {

  library(openxlsx)

  # --- Header style ---
  header_style <- createStyle(
    fontColour = "#FFFFFF",
    fgFill = "#003D5C",
    halign = "left",
    textDecoration = "bold",
    fontSize = 11,
    fontName = "Arial"
  )

  value_style <- createStyle(
    fontSize = 11,
    fontName = "Arial"
  )

  # =========================================================================
  # Config 1: Demo_Pricing_Config.xlsx (VW + GG)
  # =========================================================================

  wb <- createWorkbook()

  # --- Settings sheet ---
  addWorksheet(wb, "Settings")
  settings_df <- data.frame(
    Setting = c(
      "Project_Name", "Analysis_Method", "Data_File", "Output_File",
      "ID_Variable", "Weight_Variable", "Currency_Symbol", "Unit_Cost",
      "DK_Codes",
      "Generate_HTML_Report", "Generate_Simulator", "Brand_Colour",
      "VW_Monotonicity_Behavior", "GG_Monotonicity_Behavior",
      "Segment_Column", "Min_Segment_N", "Include_Total",
      "N_Tiers", "Tier_Names", "Min_Gap_Pct", "Max_Gap_Pct", "Round_To"
    ),
    Value = c(
      "CloudSync Pro Pricing Study", "both", "demo_data.csv", "output/demo_vwgg_results.xlsx",
      "resp_id", "weight", "$", "3.50",
      "",
      "TRUE", "TRUE", "#2563eb",
      "flag_only", "smooth",
      "segment", "50", "TRUE",
      "3", "Value;Standard;Premium", "15", "50", "0.99"
    ),
    stringsAsFactors = FALSE
  )
  writeData(wb, "Settings", settings_df, headerStyle = header_style)
  addStyle(wb, "Settings", value_style, rows = 2:(nrow(settings_df)+1), cols = 1:2, gridExpand = TRUE)
  setColWidths(wb, "Settings", cols = 1:2, widths = c(30, 45))

  # --- VanWestendorp sheet (LOWERCASE names!) ---
  addWorksheet(wb, "VanWestendorp")
  vw_df <- data.frame(
    Setting = c(
      "col_too_cheap", "col_cheap", "col_expensive", "col_too_expensive",
      "col_pi_cheap", "col_pi_expensive",
      "validate_monotonicity", "calculate_confidence",
      "confidence_level", "bootstrap_iterations", "interpolation_method"
    ),
    Value = c(
      "vw_too_cheap", "vw_cheap", "vw_expensive", "vw_too_expensive",
      "pi_cheap", "pi_expensive",
      "TRUE", "TRUE",
      "0.95", "1000", "linear"
    ),
    stringsAsFactors = FALSE
  )
  writeData(wb, "VanWestendorp", vw_df, headerStyle = header_style)
  addStyle(wb, "VanWestendorp", value_style, rows = 2:(nrow(vw_df)+1), cols = 1:2, gridExpand = TRUE)
  setColWidths(wb, "VanWestendorp", cols = 1:2, widths = c(30, 45))

  # --- GaborGranger sheet (LOWERCASE names, COMMA separators!) ---
  addWorksheet(wb, "GaborGranger")
  gg_df <- data.frame(
    Setting = c(
      "data_format", "price_sequence", "response_columns",
      "response_type", "check_monotonicity",
      "calculate_elasticity", "revenue_optimization",
      "confidence_intervals", "bootstrap_iterations", "confidence_level"
    ),
    Value = c(
      "wide",
      "9,14,19,24,29,34",
      "gg_price_9,gg_price_14,gg_price_19,gg_price_24,gg_price_29,gg_price_34",
      "binary", "TRUE",
      "TRUE", "TRUE",
      "TRUE", "1000", "0.95"
    ),
    stringsAsFactors = FALSE
  )
  writeData(wb, "GaborGranger", gg_df, headerStyle = header_style)
  addStyle(wb, "GaborGranger", value_style, rows = 2:(nrow(gg_df)+1), cols = 1:2, gridExpand = TRUE)
  setColWidths(wb, "GaborGranger", cols = 1:2, widths = c(30, 60))

  # --- Simulator sheet (TABLE format, NOT Setting/Value) ---
  addWorksheet(wb, "Simulator")
  sim_df <- data.frame(
    Scenario_Name = c("Budget Starter", "Market Standard", "Premium Pro"),
    Product_Price = c(9.99, 16.99, 24.99),
    Competitor_1_Price = c(12.99, 12.99, 12.99),
    Competitor_2_Price = c(14.99, 14.99, 14.99),
    Competitor_3_Price = c(19.99, 19.99, 19.99),
    Description = c(
      "Aggressive entry-level pricing below all competitors",
      "Mid-market positioning matching expected value zone",
      "Premium positioning targeting Enterprise segment"
    ),
    stringsAsFactors = FALSE
  )
  writeData(wb, "Simulator", sim_df, headerStyle = header_style)
  addStyle(wb, "Simulator", value_style, rows = 2:4, cols = 1:6, gridExpand = TRUE)
  setColWidths(wb, "Simulator", cols = 1:6, widths = c(20, 15, 20, 20, 20, 50))

  # --- Validation sheet ---
  addWorksheet(wb, "Validation")
  val_df <- data.frame(
    Setting = c(
      "Min_Completeness", "Min_Sample", "Price_Min", "Price_Max",
      "Flag_Outliers", "Outlier_Method", "Outlier_Threshold"
    ),
    Value = c("0.80", "30", "0", "100", "TRUE", "iqr", "3"),
    stringsAsFactors = FALSE
  )
  writeData(wb, "Validation", val_df, headerStyle = header_style)
  addStyle(wb, "Validation", value_style, rows = 2:(nrow(val_df)+1), cols = 1:2, gridExpand = TRUE)
  setColWidths(wb, "Validation", cols = 1:2, widths = c(25, 20))

  config_path <- file.path(demo_dir, "Demo_Pricing_Config.xlsx")
  saveWorkbook(wb, config_path, overwrite = TRUE)
  cat(sprintf("   Saved: %s\n", config_path))

  # =========================================================================
  # Config 2: Demo_Monadic_Config.xlsx (Monadic only)
  # =========================================================================

  wb2 <- createWorkbook()

  # --- Settings sheet ---
  addWorksheet(wb2, "Settings")
  settings2_df <- data.frame(
    Setting = c(
      "Project_Name", "Analysis_Method", "Data_File", "Output_File",
      "ID_Variable", "Weight_Variable", "Currency_Symbol", "Unit_Cost",
      "Generate_HTML_Report", "Generate_Simulator", "Brand_Colour"
    ),
    Value = c(
      "CloudSync Pro Monadic Analysis", "monadic", "demo_data.csv", "output/demo_monadic_results.xlsx",
      "resp_id", "weight", "$", "3.50",
      "FALSE", "FALSE", "#2563eb"
    ),
    stringsAsFactors = FALSE
  )
  writeData(wb2, "Settings", settings2_df, headerStyle = header_style)
  addStyle(wb2, "Settings", value_style, rows = 2:(nrow(settings2_df)+1), cols = 1:2, gridExpand = TRUE)
  setColWidths(wb2, "Settings", cols = 1:2, widths = c(30, 45))

  # --- Monadic sheet (Title_Case OK — loader normalises) ---
  addWorksheet(wb2, "Monadic")
  mon_df <- data.frame(
    Setting = c(
      "Price_Column", "Intent_Column", "Intent_Type",
      "Model_Type", "Min_Cell_Size", "Prediction_Points",
      "Confidence_Intervals", "Bootstrap_Iterations", "Confidence_Level"
    ),
    Value = c(
      "monadic_price", "monadic_intent", "binary",
      "logistic", "30", "100",
      "TRUE", "1000", "0.95"
    ),
    stringsAsFactors = FALSE
  )
  writeData(wb2, "Monadic", mon_df, headerStyle = header_style)
  addStyle(wb2, "Monadic", value_style, rows = 2:(nrow(mon_df)+1), cols = 1:2, gridExpand = TRUE)
  setColWidths(wb2, "Monadic", cols = 1:2, widths = c(25, 30))

  # --- Validation sheet ---
  addWorksheet(wb2, "Validation")
  writeData(wb2, "Validation", val_df, headerStyle = header_style)
  addStyle(wb2, "Validation", value_style, rows = 2:(nrow(val_df)+1), cols = 1:2, gridExpand = TRUE)
  setColWidths(wb2, "Validation", cols = 1:2, widths = c(25, 20))

  monadic_config_path <- file.path(demo_dir, "Demo_Monadic_Config.xlsx")
  saveWorkbook(wb2, monadic_config_path, overwrite = TRUE)
  cat(sprintf("   Saved: %s\n", monadic_config_path))
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

cat("\n")
cat("===========================================================\n")
cat("  Data Generation Complete!\n")
cat("===========================================================\n")
cat(sprintf("  Respondents:  %d\n", n))
cat(sprintf("  Segments:     Individual (%d), Small Business (%d), Enterprise (%d)\n",
            sum(segment == "Individual"),
            sum(segment == "Small Business"),
            sum(segment == "Enterprise")))
cat(sprintf("  VW violations: %d (%.1f%%)\n", n_violations, n_violations / n * 100))
cat(sprintf("  GG prices:    $%s\n", paste(gg_prices, collapse = ", $")))
cat(sprintf("  Monadic cells: %s\n",
            paste(sprintf("$%.2f", monadic_prices), collapse = ", ")))
cat("\n  Files created:\n")
cat(sprintf("    %s\n", csv_path))
if (exists("config_path")) cat(sprintf("    %s\n", config_path))
if (exists("monadic_config_path")) cat(sprintf("    %s\n", monadic_config_path))
cat("\n  Next: source('examples/pricing/demo_showcase/run_demo.R')\n")
cat("===========================================================\n\n")
