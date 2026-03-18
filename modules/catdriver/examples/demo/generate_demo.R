# ==============================================================================
# CATDRIVER DEMO DATA & CONFIG GENERATOR
# ==============================================================================
#
# Generates a realistic synthetic customer satisfaction survey dataset
# and three configuration files demonstrating all outcome types:
#   1. Binary   — Customer churn (Retained vs Churned)
#   2. Ordinal  — Overall satisfaction (Low / Medium / High)
#   3. Multinomial — Preferred plan (Basic / Standard / Premium)
#
# Scenario: A South African telecoms company surveyed 500 customers to
# understand what drives churn, satisfaction, and plan preference.
#
# Drivers have KNOWN effect strengths so results can be validated:
#   - service_quality  : STRONG driver (largest effect on all outcomes)
#   - price_perception : MEDIUM driver
#   - support_experience: MEDIUM driver
#   - contract_type    : WEAK driver
#   - age_group        : WEAK driver
#
# Usage:
#   source("modules/catdriver/examples/demo/generate_demo.R")
#
# Output:
#   - demo_customer_survey.csv          (500 rows, 8 columns)
#   - demo_config_binary.xlsx           (churn analysis config)
#   - demo_config_ordinal.xlsx          (satisfaction analysis config)
#   - demo_config_multinomial.xlsx      (plan preference analysis config)
#   - demo_config_binary_subgroup.xlsx  (churn by age_group subgroup config)
#
# ==============================================================================

library(openxlsx)

set.seed(42)

# ==============================================================================
# 1. GENERATE SYNTHETIC DATA
# ==============================================================================

n <- 500

demo_dir <- if (exists("demo_output_dir")) {
  demo_output_dir
} else {
  dirname(if (interactive()) {
    rstudioapi::getSourceEditorContext()$path
  } else {
    "modules/catdriver/examples/demo/generate_demo.R"
  })
}

# --- Driver variables (independent) ---

service_quality <- sample(
  c("Poor", "Fair", "Good", "Excellent"),
  n, replace = TRUE,
  prob = c(0.10, 0.25, 0.40, 0.25)
)

price_perception <- sample(
  c("Too Expensive", "Fair", "Good Value"),
  n, replace = TRUE,
  prob = c(0.20, 0.45, 0.35)
)

support_experience <- sample(
  c("Negative", "Neutral", "Positive"),
  n, replace = TRUE,
  prob = c(0.15, 0.40, 0.45)
)

contract_type <- sample(
  c("Month-to-Month", "Annual", "Two-Year"),
  n, replace = TRUE,
  prob = c(0.40, 0.35, 0.25)
)

age_group <- sample(
  c("18-30", "31-45", "46-60", "61+"),
  n, replace = TRUE,
  prob = c(0.25, 0.35, 0.25, 0.15)
)

# --- Latent satisfaction score (drives all outcomes) ---
# Each driver contributes to a latent score; stronger drivers contribute more.

score_service <- ifelse(service_quality == "Excellent",  1.8,
                 ifelse(service_quality == "Good",        0.6,
                 ifelse(service_quality == "Fair",       -0.4, -1.5)))

score_price <- ifelse(price_perception == "Good Value",  0.8,
               ifelse(price_perception == "Fair",        0.0, -0.9))

score_support <- ifelse(support_experience == "Positive",  0.7,
                 ifelse(support_experience == "Neutral",   0.0, -0.8))

score_contract <- ifelse(contract_type == "Two-Year",      0.4,
                  ifelse(contract_type == "Annual",        0.1, -0.3))

score_age <- ifelse(age_group == "61+",   0.3,
             ifelse(age_group == "46-60",  0.1,
             ifelse(age_group == "31-45", -0.1, -0.2)))

latent <- score_service + score_price + score_support +
          score_contract + score_age + rnorm(n, 0, 1.2)

# --- Outcome 1: Churn (binary) ---
# Higher latent score = less likely to churn
churn_prob <- 1 / (1 + exp(0.8 * latent))
churn <- ifelse(runif(n) < churn_prob, "Churned", "Retained")

# --- Outcome 2: Satisfaction (ordinal) ---
# Cut latent score into Low / Medium / High
satisfaction <- ifelse(latent < -0.5, "Low",
                ifelse(latent <  1.0, "Medium", "High"))

# --- Outcome 3: Plan preference (multinomial) ---
# Direct multinomial generation using stronger driver-specific effects
# Service quality strongly drives Premium; Price drives Basic; Age drives Standard
plan_preference <- character(n)
for (i in seq_len(n)) {
  # Base probabilities
  p_basic    <- 0.35
  p_standard <- 0.35
  p_premium  <- 0.30

  # Service quality strongly drives Premium uptake
  if (service_quality[i] == "Excellent") { p_premium <- p_premium + 0.35; p_basic <- p_basic - 0.20 }
  if (service_quality[i] == "Good")      { p_premium <- p_premium + 0.15; p_basic <- p_basic - 0.08 }
  if (service_quality[i] == "Poor")      { p_basic   <- p_basic   + 0.25; p_premium <- p_premium - 0.15 }

  # Price perception drives Basic (cost-conscious choose Basic)
  if (price_perception[i] == "Too Expensive") { p_basic <- p_basic + 0.20; p_premium <- p_premium - 0.12 }
  if (price_perception[i] == "Good Value")    { p_premium <- p_premium + 0.10; p_basic <- p_basic - 0.05 }

  # Age group: older customers prefer Standard (middle ground)
  if (age_group[i] %in% c("46-60", "61+")) { p_standard <- p_standard + 0.10 }
  if (age_group[i] == "18-30")              { p_premium  <- p_premium  + 0.05 }

  # Handle NAs in drivers (missing values)
  if (is.na(price_perception[i])) { p_basic <- 0.35; p_premium <- 0.30 }

  # Clamp and normalise
  probs <- pmax(c(p_basic, p_standard, p_premium), 0.05)
  probs <- probs / sum(probs)

  plan_preference[i] <- sample(c("Basic", "Standard", "Premium"), 1, prob = probs)
}

# --- Survey weights (realistic rim-weighted style) ---
survey_weight <- round(runif(n, 0.5, 2.0), 2)

# --- Introduce realistic missingness (5% in two drivers) ---
miss_price <- sample(seq_len(n), round(n * 0.05))
miss_support <- sample(seq_len(n), round(n * 0.04))
price_perception[miss_price] <- NA
support_experience[miss_support] <- NA

# --- Assemble data frame ---
demo_data <- data.frame(
  respondent_id       = seq_len(n),
  churn               = churn,
  satisfaction         = satisfaction,
  plan_preference      = plan_preference,
  service_quality      = service_quality,
  price_perception     = price_perception,
  support_experience   = support_experience,
  contract_type        = contract_type,
  age_group            = age_group,
  survey_weight        = survey_weight,
  stringsAsFactors     = FALSE
)

# Write CSV
data_file <- file.path(demo_dir, "demo_customer_survey.csv")
write.csv(demo_data, data_file, row.names = FALSE)
cat("Written:", data_file, "(", n, "rows )\n")

# ==============================================================================
# 2. HELPER: CREATE CONFIG WORKBOOK
# ==============================================================================

create_config <- function(filename, outcome_var, outcome_label, outcome_type,
                          outcome_order = NULL, reference_category = NULL,
                          multinomial_mode = NULL, target_outcome_level = NULL,
                          use_weights = TRUE,
                          subgroup_var = NULL,
                          exclude_drivers = NULL,
                          slides = NULL) {

  wb <- createWorkbook()

  # --- Settings sheet ---
  settings <- data.frame(
    Setting = character(),
    Value   = character(),
    stringsAsFactors = FALSE
  )

  add_setting <- function(s, v) {
    settings[nrow(settings) + 1, ] <<- c(s, v)
  }

  add_setting("data_file",          "demo_customer_survey.csv")
  add_setting("output_file",        paste0("results_", gsub(".xlsx$", "", filename), ".xlsx"))
  add_setting("analysis_name",      paste0("Demo: ", outcome_label, " Analysis"))
  add_setting("outcome_type",       outcome_type)

  if (!is.null(reference_category)) {
    add_setting("reference_category", reference_category)
  }
  if (!is.null(multinomial_mode)) {
    add_setting("multinomial_mode", multinomial_mode)
  }
  if (!is.null(target_outcome_level)) {
    add_setting("target_outcome_level", target_outcome_level)
  }

  add_setting("min_sample_size",    "30")
  add_setting("confidence_level",   "0.95")
  add_setting("missing_threshold",  "50")
  add_setting("rare_level_policy",  "collapse_to_other")
  add_setting("rare_level_threshold", "10")
  add_setting("rare_cell_threshold",  "5")
  add_setting("detailed_output",    "TRUE")
  add_setting("bootstrap_ci",       "FALSE")
  add_setting("html_report",        "TRUE")
  add_setting("probability_lifts",  "TRUE")
  add_setting("brand_colour",       "#323367")
  add_setting("accent_colour",      "#CC9900")
  add_setting("researcher_logo_path", file.path(demo_dir, "trlwhite.png"))
  add_setting("report_title",       paste0("Customer ", outcome_label, " — Key Drivers"))

  # Subgroup settings (optional)
  if (!is.null(subgroup_var)) {
    add_setting("subgroup_var", subgroup_var)
    add_setting("subgroup_min_n", "30")
    add_setting("subgroup_include_total", "TRUE")
  }

  addWorksheet(wb, "Settings")
  writeData(wb, "Settings", settings)

  # --- Variables sheet ---
  all_driver_names  <- c("service_quality", "price_perception",
                         "support_experience", "contract_type", "age_group")
  all_driver_labels <- c("Service Quality", "Price Perception",
                         "Support Experience", "Contract Type", "Age Group")

  # Remove excluded drivers (e.g., when a driver becomes the subgroup_var)
  if (!is.null(exclude_drivers)) {
    keep <- !all_driver_names %in% exclude_drivers
    all_driver_names  <- all_driver_names[keep]
    all_driver_labels <- all_driver_labels[keep]
  }

  # Lookup table: driver name → display order (used to build var_order dynamically)
  driver_order_lookup <- c(
    service_quality    = "Poor;Fair;Good;Excellent",
    price_perception   = "Too Expensive;Fair;Good Value",
    support_experience = "Negative;Neutral;Positive",
    contract_type      = "",
    age_group          = ""
  )

  var_names  <- c(outcome_var, all_driver_names)
  var_types  <- c("Outcome", rep("Driver", length(all_driver_names)))
  var_labels <- c(outcome_label, all_driver_labels)
  var_order  <- c(ifelse(is.null(outcome_order), "", outcome_order),
                  unname(driver_order_lookup[all_driver_names]))

  if (use_weights) {
    var_names  <- c(var_names,  "survey_weight")
    var_types  <- c(var_types,  "Weight")
    var_labels <- c(var_labels, "Survey Weight")
    var_order  <- c(var_order,  "")
  }

  variables <- data.frame(
    VariableName = var_names,
    Type         = var_types,
    Label        = var_labels,
    Order        = var_order,
    stringsAsFactors = FALSE
  )

  addWorksheet(wb, "Variables")
  writeData(wb, "Variables", variables)

  # --- Driver_Settings sheet ---
  # Build full driver settings, then filter to match the (possibly reduced) driver list
  all_ds <- data.frame(
    driver           = c("service_quality", "price_perception",
                         "support_experience", "contract_type", "age_group"),
    type             = c("ordinal", "ordinal", "ordinal", "categorical", "ordinal"),
    levels_order     = c("Poor;Fair;Good;Excellent",
                         "Too Expensive;Fair;Good Value",
                         "Negative;Neutral;Positive",
                         "",
                         "18-30;31-45;46-60;61+"),
    reference_level  = c("Poor", "Too Expensive", "Negative",
                         "Month-to-Month", "18-30"),
    missing_strategy = c("drop_row", "drop_row", "drop_row",
                         "drop_row", "drop_row"),
    rare_level_policy = c("", "", "", "", ""),
    stringsAsFactors = FALSE
  )
  driver_settings <- all_ds[all_ds$driver %in% all_driver_names, , drop = FALSE]

  addWorksheet(wb, "Driver_Settings")
  writeData(wb, "Driver_Settings", driver_settings)

  # --- Slides sheet (optional) ---
  sheets_to_style <- c("Settings", "Variables", "Driver_Settings")

  if (!is.null(slides) && is.data.frame(slides) && nrow(slides) > 0) {
    addWorksheet(wb, "Slides")
    writeData(wb, "Slides", slides)
    sheets_to_style <- c(sheets_to_style, "Slides")
  }

  # --- Style all sheets ---
  header_style <- createStyle(
    fontName = "Arial", fontSize = 11,
    textDecoration = "bold",
    fgFill = "#323367", fontColour = "#FFFFFF",
    border = "Bottom", borderColour = "#000000"
  )

  for (sheet in sheets_to_style) {
    addStyle(wb, sheet, header_style, rows = 1,
             cols = 1:10, gridExpand = TRUE)
    setColWidths(wb, sheet, cols = 1:10, widths = "auto")
  }

  # Save
  out_path <- file.path(demo_dir, filename)
  saveWorkbook(wb, out_path, overwrite = TRUE)
  cat("Written:", out_path, "\n")
}

# ==============================================================================
# 3. CREATE THREE CONFIG FILES
# ==============================================================================

# --- Demo slides for binary config ---
demo_slides <- data.frame(
  slide_order      = c(1, 2),
  slide_title      = c("Executive Summary", "Methodology Note"),
  slide_content    = c(
    "## Key Findings\n\n**Service quality** is the strongest driver of customer churn.\n\n- Customers rating service as 'Poor' are 3x more likely to churn\n- Price perception has moderate influence\n- Contract length shows weak but significant effect\n\n> Focus retention efforts on service quality improvements",
    "## Analysis Approach\n\nBinary logistic regression was used to identify drivers of churn.\n\n- **Outcome**: Customer churn (Yes/No)\n- **Drivers**: 6 categorical variables\n- **Sample**: 500 respondents\n- **Weighting**: Survey weights applied"
  ),
  slide_image_path = c("", ""),
  stringsAsFactors = FALSE
)

# Binary: Churn (Retained vs Churned)
create_config(
  filename           = "demo_config_binary.xlsx",
  outcome_var        = "churn",
  outcome_label      = "Customer Churn",
  outcome_type       = "binary",
  outcome_order      = "Retained;Churned",
  reference_category = "Retained",
  slides             = demo_slides
)

# Ordinal: Satisfaction (Low / Medium / High)
create_config(
  filename           = "demo_config_ordinal.xlsx",
  outcome_var        = "satisfaction",
  outcome_label      = "Customer Satisfaction",
  outcome_type       = "ordinal",
  outcome_order      = "Low;Medium;High",
  reference_category = NULL
)

# Multinomial: Plan preference (Basic / Standard / Premium)
# Note: Unweighted - nnet::multinom has limited weight support
create_config(
  filename           = "demo_config_multinomial.xlsx",
  outcome_var        = "plan_preference",
  outcome_label      = "Plan Preference",
  outcome_type       = "multinomial",
  outcome_order      = "Basic;Standard;Premium",
  reference_category = "Basic",
  multinomial_mode   = "baseline_category",
  use_weights        = FALSE
)

# Binary + Subgroup: Churn split by Age Group
# Note: age_group is excluded from drivers (can't be both splitter and predictor)
create_config(
  filename           = "demo_config_binary_subgroup.xlsx",
  outcome_var        = "churn",
  outcome_label      = "Customer Churn",
  outcome_type       = "binary",
  outcome_order      = "Retained;Churned",
  reference_category = "Retained",
  subgroup_var       = "age_group",
  exclude_drivers    = "age_group"
)

cat("\n=== DEMO GENERATION COMPLETE ===\n")
cat("Files created in:", demo_dir, "\n\n")
cat("Quick data summary:\n")
cat("  Rows:", n, "\n")
cat("  Churn:         ", table(demo_data$churn), "\n")
cat("  Satisfaction:  ", table(demo_data$satisfaction), "\n")
cat("  Plan pref:     ", table(demo_data$plan_preference), "\n")
cat("  Missing price: ", sum(is.na(demo_data$price_perception)), "\n")
cat("  Missing support:", sum(is.na(demo_data$support_experience)), "\n")
