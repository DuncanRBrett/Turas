# ==============================================================================
# TURAS DEMO SURVEY GENERATOR
# ==============================================================================
# Creates a complete synthetic survey dataset to showcase all HTML report features:
#   - 4 banners: Region, Gender, Age, Customer Segment
#   - 25 questions: NPS, Rating (mean), Likert (index/net positive), Single choice
#   - n = 1,000 respondents
#   - Weighted data
#   - Realistic distributions with built-in group differences for sig testing
#
# Output files:
#   - Demo_Survey_Structure.xlsx (Project, Questions, Options, Composite_Metrics)
#   - Demo_Survey_Data.xlsx (response data)
#   - Demo_Crosstab_Config.xlsx (Settings, Selection)
# ==============================================================================

library(openxlsx)
set.seed(2025)

cat("=== TURAS DEMO SURVEY GENERATOR ===\n\n")

output_dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) NULL)
if (is.null(output_dir) || !dir.exists(output_dir)) {
  output_dir <- "examples/tabs/demo_survey"
}
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

n <- 1000

# ==============================================================================
# STEP 1: GENERATE RESPONDENT DEMOGRAPHICS
# ==============================================================================
cat("Step 1: Generating demographics...\n")

# Region (4 regions, unequal sizes for interesting sig tests)
region <- sample(
  c("Gauteng", "Western Cape", "KwaZulu-Natal", "Eastern Cape"),
  n, replace = TRUE, prob = c(0.35, 0.25, 0.25, 0.15)
)

# Gender
gender <- sample(c("Male", "Female"), n, replace = TRUE, prob = c(0.48, 0.52))

# Age
age_group <- sample(
  c("18 - 24", "25 - 34", "35 - 44", "45 - 54", "55+"),
  n, replace = TRUE, prob = c(0.15, 0.30, 0.25, 0.18, 0.12)
)

# Customer Segment
segment <- sample(
  c("Premium", "Standard", "Budget", "New Customer"),
  n, replace = TRUE, prob = c(0.20, 0.35, 0.25, 0.20)
)

# Weights (realistic rim weights)
wt <- runif(n, 0.6, 1.6)
wt <- wt / mean(wt)  # normalise to mean 1

# ==============================================================================
# STEP 2: GENERATE RESPONSE DATA
# ==============================================================================
cat("Step 2: Generating response data...\n")

# Helper: generate rating data (1-10) with group effects
gen_rating <- function(base_mean = 7, sd = 1.5, region_effect = NULL,
                       segment_effect = NULL) {
  vals <- rnorm(n, base_mean, sd)
  if (!is.null(region_effect)) {
    for (r in names(region_effect)) {
      vals[region == r] <- vals[region == r] + region_effect[[r]]
    }
  }
  if (!is.null(segment_effect)) {
    for (s in names(segment_effect)) {
      vals[segment == s] <- vals[segment == s] + segment_effect[[s]]
    }
  }
  pmin(pmax(round(vals), 1), 10)
}

# Helper: generate likert data (1-5) with group effects
gen_likert <- function(base_mean = 3.5, sd = 1.0, region_effect = NULL,
                       segment_effect = NULL) {
  vals <- rnorm(n, base_mean, sd)
  if (!is.null(region_effect)) {
    for (r in names(region_effect)) {
      vals[region == r] <- vals[region == r] + region_effect[[r]]
    }
  }
  if (!is.null(segment_effect)) {
    for (s in names(segment_effect)) {
      vals[segment == s] <- vals[segment == s] + segment_effect[[s]]
    }
  }
  pmin(pmax(round(vals), 1), 5)
}

# Helper: generate NPS (0-10) with group effects
gen_nps <- function(base_mean = 7.5, sd = 2.0, region_effect = NULL,
                    segment_effect = NULL) {
  vals <- rnorm(n, base_mean, sd)
  if (!is.null(region_effect)) {
    for (r in names(region_effect)) {
      vals[region == r] <- vals[region == r] + region_effect[[r]]
    }
  }
  if (!is.null(segment_effect)) {
    for (s in names(segment_effect)) {
      vals[segment == s] <- vals[segment == s] + segment_effect[[s]]
    }
  }
  pmin(pmax(round(vals), 0), 10)
}

# --- NPS Question ---
Q001 <- gen_nps(7.5, 2.0,
  region_effect = list("Gauteng" = 0.5, "Western Cape" = 0.8,
                       "KwaZulu-Natal" = -0.3, "Eastern Cape" = -1.0),
  segment_effect = list("Premium" = 1.2, "Standard" = 0, "Budget" = -0.8,
                        "New Customer" = 0.3)
)

# --- Rating Questions (1-10 scale) ---
# Overall satisfaction
Q002 <- gen_rating(7.0, 1.8,
  region_effect = list("Gauteng" = 0.3, "Western Cape" = 0.6,
                       "KwaZulu-Natal" = -0.2, "Eastern Cape" = -0.5),
  segment_effect = list("Premium" = 1.0, "Standard" = 0, "Budget" = -0.5,
                        "New Customer" = -0.3)
)

# Product quality
Q003 <- gen_rating(7.2, 1.6,
  region_effect = list("Gauteng" = 0.2, "Western Cape" = 0.4,
                       "KwaZulu-Natal" = 0.1, "Eastern Cape" = -0.5),
  segment_effect = list("Premium" = 0.8, "Standard" = 0.2, "Budget" = -0.6,
                        "New Customer" = 0)
)

# Value for money
Q004 <- gen_rating(6.0, 2.0,
  region_effect = list("Gauteng" = 0, "Western Cape" = 0.3,
                       "KwaZulu-Natal" = 0.2, "Eastern Cape" = -0.3),
  segment_effect = list("Premium" = -0.5, "Standard" = 0.3, "Budget" = 0.5,
                        "New Customer" = -0.2)
)

# Customer service
Q005 <- gen_rating(6.8, 1.9,
  region_effect = list("Gauteng" = 0.5, "Western Cape" = 0.7,
                       "KwaZulu-Natal" = -0.4, "Eastern Cape" = -0.8),
  segment_effect = list("Premium" = 1.5, "Standard" = 0, "Budget" = -0.8,
                        "New Customer" = -0.3)
)

# Ease of use
Q006 <- gen_rating(7.5, 1.5,
  segment_effect = list("Premium" = 0.3, "Standard" = 0.1, "Budget" = -0.2,
                        "New Customer" = -0.8)
)

# Delivery experience
Q007 <- gen_rating(6.5, 2.2,
  region_effect = list("Gauteng" = 0.8, "Western Cape" = 0.5,
                       "KwaZulu-Natal" = -0.3, "Eastern Cape" = -1.2)
)

# Website experience
Q008 <- gen_rating(7.0, 1.7,
  segment_effect = list("Premium" = 0.5, "Standard" = 0.2, "Budget" = -0.3,
                        "New Customer" = -0.6)
)

# Mobile app experience
Q009 <- gen_rating(6.3, 2.0,
  segment_effect = list("Premium" = 0.8, "Standard" = 0, "Budget" = -0.5,
                        "New Customer" = -0.4)
)

# Communication quality
Q010 <- gen_rating(6.7, 1.8,
  region_effect = list("Gauteng" = 0.3, "Western Cape" = 0.5,
                       "KwaZulu-Natal" = -0.2, "Eastern Cape" = -0.7)
)

# --- Likert Questions (1-5 scale) ---
# Trust in brand
Q011 <- gen_likert(3.6, 1.1,
  region_effect = list("Gauteng" = 0.2, "Western Cape" = 0.3,
                       "KwaZulu-Natal" = -0.1, "Eastern Cape" = -0.4),
  segment_effect = list("Premium" = 0.5, "Standard" = 0, "Budget" = -0.3,
                        "New Customer" = -0.1)
)

# Brand reputation
Q012 <- gen_likert(3.8, 1.0,
  segment_effect = list("Premium" = 0.4, "Standard" = 0.1, "Budget" = -0.2,
                        "New Customer" = -0.1)
)

# Innovation perception
Q013 <- gen_likert(3.3, 1.2,
  region_effect = list("Gauteng" = 0.3, "Western Cape" = 0.4,
                       "KwaZulu-Natal" = -0.1, "Eastern Cape" = -0.5)
)

# Sustainability commitment
Q014 <- gen_likert(3.1, 1.1,
  segment_effect = list("Premium" = 0.6, "Standard" = 0, "Budget" = -0.3,
                        "New Customer" = 0.2)
)

# Value alignment
Q015 <- gen_likert(3.4, 1.0,
  segment_effect = list("Premium" = 0.5, "Standard" = 0.1, "Budget" = -0.4,
                        "New Customer" = 0.1)
)

# After-sales support
Q016 <- gen_likert(3.2, 1.2,
  region_effect = list("Gauteng" = 0.4, "Western Cape" = 0.3,
                       "KwaZulu-Natal" = -0.2, "Eastern Cape" = -0.8)
)

# Loyalty intent
Q017 <- gen_likert(3.5, 1.1,
  segment_effect = list("Premium" = 0.7, "Standard" = 0, "Budget" = -0.5,
                        "New Customer" = 0.2)
)

# --- Single Choice Questions ---
# Purchase frequency
Q018 <- sample(
  c("Weekly", "Monthly", "Quarterly", "Yearly", "First time"),
  n, replace = TRUE, prob = c(0.10, 0.30, 0.25, 0.20, 0.15)
)

# Primary channel
Q019 <- sample(
  c("Online", "In-store", "Mobile app", "Phone", "Social media"),
  n, replace = TRUE, prob = c(0.35, 0.25, 0.20, 0.10, 0.10)
)

# How did you hear about us?
Q020 <- sample(
  c("Social media", "Word of mouth", "TV advertising", "Online search",
    "Print media", "Email marketing"),
  n, replace = TRUE, prob = c(0.25, 0.20, 0.15, 0.20, 0.08, 0.12)
)

# Reason for choosing us
Q021 <- sample(
  c("Price", "Quality", "Convenience", "Brand reputation",
    "Recommendation", "No alternative"),
  n, replace = TRUE, prob = c(0.20, 0.25, 0.20, 0.15, 0.12, 0.08)
)

# Complaint in last 12 months
Q022 <- sample(
  c("Yes", "No"),
  n, replace = TRUE, prob = c(0.22, 0.78)
)

# Complaint resolved satisfactorily (only for those who complained)
Q023 <- ifelse(Q022 == "Yes",
  sample(c("Yes", "No", "Partially"), sum(Q022 == "Yes"),
         replace = TRUE, prob = c(0.45, 0.20, 0.35)),
  NA
)

# Would switch to competitor
Q024 <- sample(
  c("Definitely would", "Probably would", "Not sure",
    "Probably would not", "Definitely would not"),
  n, replace = TRUE, prob = c(0.08, 0.15, 0.22, 0.30, 0.25)
)

# Overall impression
Q025 <- sample(
  c("Excellent", "Good", "Average", "Below average", "Poor"),
  n, replace = TRUE,
  prob = c(0.18, 0.35, 0.25, 0.14, 0.08)
)

# ==============================================================================
# STEP 3: ASSEMBLE DATA FILE
# ==============================================================================
cat("Step 3: Assembling data file...\n")

survey_data <- data.frame(
  respondent_id = 1:n,
  Region = region,
  Gender = gender,
  Age_Group = age_group,
  Segment = segment,
  Weight = round(wt, 4),
  Q001 = Q001, Q002 = Q002, Q003 = Q003, Q004 = Q004, Q005 = Q005,
  Q006 = Q006, Q007 = Q007, Q008 = Q008, Q009 = Q009, Q010 = Q010,
  Q011 = Q011, Q012 = Q012, Q013 = Q013, Q014 = Q014, Q015 = Q015,
  Q016 = Q016, Q017 = Q017,
  Q018 = Q018, Q019 = Q019, Q020 = Q020, Q021 = Q021,
  Q022 = Q022, Q023 = Q023, Q024 = Q024, Q025 = Q025,
  stringsAsFactors = FALSE
)

# Write data
data_path <- file.path(output_dir, "Demo_Survey_Data.xlsx")
wb_data <- createWorkbook()
addWorksheet(wb_data, "Data")
writeData(wb_data, "Data", survey_data)
saveWorkbook(wb_data, data_path, overwrite = TRUE)
cat(sprintf("  -> Data: %s (%d rows)\n", data_path, n))

# ==============================================================================
# STEP 4: CREATE SURVEY STRUCTURE
# ==============================================================================
cat("Step 4: Creating Survey Structure...\n")

# Project sheet
project_df <- data.frame(
  Setting = c("project_name", "project_code", "client_name", "study_type",
              "study_date", "data_file", "output_folder", "total_sample",
              "weight_column_exists", "weight_columns", "default_weight"),
  Value = c("Turas Demo Customer Experience Survey", "DEMO_CX_2025",
            "Turas Analytics (Demo)", "Ad-hoc", "20250215",
            "Demo_Survey_Data.xlsx", "Output", "1000",
            "Y", "Weight", "Weight"),
  stringsAsFactors = FALSE
)

# Questions sheet
questions_df <- data.frame(
  QuestionCode = c(
    "Region", "Gender", "Age_Group", "Segment",
    "Q001", "Q002", "Q003", "Q004", "Q005", "Q006", "Q007", "Q008",
    "Q009", "Q010",
    "Q011", "Q012", "Q013", "Q014", "Q015", "Q016", "Q017",
    "Q018", "Q019", "Q020", "Q021", "Q022", "Q023", "Q024", "Q025"
  ),
  QuestionText = c(
    "Region", "Gender", "Age group", "Customer segment",
    "How likely are you to recommend us to a friend or colleague? (0-10)",
    "How would you rate your overall satisfaction with our service?",
    "How would you rate the quality of our products?",
    "How would you rate the value for money of our products?",
    "How would you rate the quality of our customer service?",
    "How easy is it to do business with us?",
    "How would you rate your delivery experience?",
    "How would you rate your experience with our website?",
    "How would you rate your experience with our mobile app?",
    "How would you rate the quality of our communications?",
    "How much do you trust our brand?",
    "How would you rate our brand's reputation?",
    "How innovative do you consider our company to be?",
    "How committed do you feel we are to sustainability?",
    "How well does our brand align with your personal values?",
    "How satisfied are you with our after-sales support?",
    "How likely are you to remain a customer in the next 12 months?",
    "How often do you purchase from us?",
    "What is your primary channel for interacting with us?",
    "How did you first hear about us?",
    "What was the main reason you chose us?",
    "Have you made a complaint in the last 12 months?",
    "Was your complaint resolved to your satisfaction?",
    "How likely would you be to switch to a competitor?",
    "What is your overall impression of our company?"
  ),
  Variable_Type = c(
    "Single_Response", "Single_Response", "Single_Response", "Single_Response",
    "NPS",
    rep("Rating", 9),
    rep("Likert", 7),
    rep("Single_Response", 8)
  ),
  Columns = rep(1, 29),
  Category = c(
    rep("Demographics", 4),
    "Loyalty",
    rep("Satisfaction", 5),
    rep("Experience", 4),
    rep("Brand Perception", 5),
    rep("Loyalty", 2),
    rep("Behaviour", 4),
    "Complaints", "Complaints",
    "Loyalty", "Overall"
  ),
  stringsAsFactors = FALSE
)

# Options sheet
options_list <- list()

# Region options
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Region",
  OptionText = c("Gauteng", "Western Cape", "KwaZulu-Natal", "Eastern Cape"),
  DisplayText = c("Gauteng", "Western Cape", "KwaZulu-Natal", "Eastern Cape"),
  ShowInOutput = "Y",
  DisplayOrder = 1:4,
  Index_Weight = NA, BoxCategory = NA, ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

# Gender options
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Gender",
  OptionText = c("Male", "Female"),
  DisplayText = c("Male", "Female"),
  ShowInOutput = "Y",
  DisplayOrder = 1:2,
  Index_Weight = NA, BoxCategory = NA, ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

# Age options
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Age_Group",
  OptionText = c("18 - 24", "25 - 34", "35 - 44", "45 - 54", "55+"),
  DisplayText = c("18 - 24", "25 - 34", "35 - 44", "45 - 54", "55+"),
  ShowInOutput = "Y",
  DisplayOrder = 1:5,
  Index_Weight = NA, BoxCategory = NA, ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

# Segment options
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Segment",
  OptionText = c("Premium", "Standard", "Budget", "New Customer"),
  DisplayText = c("Premium", "Standard", "Budget", "New Customer"),
  ShowInOutput = "Y",
  DisplayOrder = 1:4,
  Index_Weight = NA, BoxCategory = NA, ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

# NPS options (Q001: 0-10)
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Q001",
  OptionText = as.character(0:10),
  DisplayText = as.character(0:10),
  ShowInOutput = "Y",
  DisplayOrder = 1:11,
  Index_Weight = NA,
  BoxCategory = c(rep("Detractor (0-6)", 7), rep("Passive (7-8)", 2),
                  rep("Promoter (9-10)", 2)),
  ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

# Rating options (Q002-Q010: 1-10 scale)
for (qc in paste0("Q", sprintf("%03d", 2:10))) {
  options_list[[length(options_list) + 1]] <- data.frame(
    QuestionCode = qc,
    OptionText = as.character(1:10),
    DisplayText = as.character(1:10),
    ShowInOutput = "Y",
    DisplayOrder = 1:10,
    Index_Weight = 1:10,
    BoxCategory = c(rep("Poor (1-3)", 3), rep("Average (4-6)", 3),
                    rep("Good or excellent (7-10)", 4)),
    ExcludeFromIndex = NA,
    stringsAsFactors = FALSE
  )
}

# Likert options (Q011-Q017: 1-5 scale)
for (qc in paste0("Q", sprintf("%03d", 11:17))) {
  options_list[[length(options_list) + 1]] <- data.frame(
    QuestionCode = qc,
    OptionText = as.character(1:5),
    DisplayText = c("Strongly disagree (1)", "Disagree (2)", "Neutral (3)",
                    "Agree (4)", "Strongly agree (5)"),
    ShowInOutput = "Y",
    DisplayOrder = 1:5,
    Index_Weight = c(1, 2, 3, 4, 5),
    BoxCategory = c("Negative", "Negative", "Neutral", "Positive", "Positive"),
    ExcludeFromIndex = NA,
    stringsAsFactors = FALSE
  )
}

# Q018 - Purchase frequency
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Q018",
  OptionText = c("Weekly", "Monthly", "Quarterly", "Yearly", "First time"),
  DisplayText = c("Weekly", "Monthly", "Quarterly", "Yearly", "First time"),
  ShowInOutput = "Y",
  DisplayOrder = 1:5,
  Index_Weight = NA, BoxCategory = NA, ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

# Q019 - Primary channel
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Q019",
  OptionText = c("Online", "In-store", "Mobile app", "Phone", "Social media"),
  DisplayText = c("Online", "In-store", "Mobile app", "Phone", "Social media"),
  ShowInOutput = "Y",
  DisplayOrder = 1:5,
  Index_Weight = NA, BoxCategory = NA, ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

# Q020 - How heard
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Q020",
  OptionText = c("Social media", "Word of mouth", "TV advertising",
                 "Online search", "Print media", "Email marketing"),
  DisplayText = c("Social media", "Word of mouth", "TV advertising",
                  "Online search", "Print media", "Email marketing"),
  ShowInOutput = "Y",
  DisplayOrder = 1:6,
  Index_Weight = NA, BoxCategory = NA, ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

# Q021 - Reason for choosing
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Q021",
  OptionText = c("Price", "Quality", "Convenience", "Brand reputation",
                 "Recommendation", "No alternative"),
  DisplayText = c("Price", "Quality", "Convenience", "Brand reputation",
                  "Recommendation", "No alternative"),
  ShowInOutput = "Y",
  DisplayOrder = 1:6,
  Index_Weight = NA, BoxCategory = NA, ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

# Q022 - Complaint
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Q022",
  OptionText = c("Yes", "No"),
  DisplayText = c("Yes", "No"),
  ShowInOutput = "Y",
  DisplayOrder = 1:2,
  Index_Weight = NA, BoxCategory = NA, ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

# Q023 - Complaint resolved
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Q023",
  OptionText = c("Yes", "No", "Partially"),
  DisplayText = c("Yes, fully resolved", "No, not resolved",
                  "Partially resolved"),
  ShowInOutput = "Y",
  DisplayOrder = 1:3,
  Index_Weight = NA, BoxCategory = NA, ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

# Q024 - Switch to competitor
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Q024",
  OptionText = c("Definitely would", "Probably would", "Not sure",
                 "Probably would not", "Definitely would not"),
  DisplayText = c("Definitely would", "Probably would", "Not sure",
                  "Probably would not", "Definitely would not"),
  ShowInOutput = "Y",
  DisplayOrder = 1:5,
  Index_Weight = NA,
  BoxCategory = c("Would switch", "Would switch", "Undecided",
                  "Would not switch", "Would not switch"),
  ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

# Q025 - Overall impression
options_list[[length(options_list) + 1]] <- data.frame(
  QuestionCode = "Q025",
  OptionText = c("Excellent", "Good", "Average", "Below average", "Poor"),
  DisplayText = c("Excellent", "Good", "Average", "Below average", "Poor"),
  ShowInOutput = "Y",
  DisplayOrder = 1:5,
  Index_Weight = NA,
  BoxCategory = c("Good or excellent", "Good or excellent", "Average",
                  "Below average or poor", "Below average or poor"),
  ExcludeFromIndex = NA,
  stringsAsFactors = FALSE
)

options_df <- do.call(rbind, options_list)

# Composite metrics
composite_df <- data.frame(
  CompositeCode = c("COMP_SAT", "COMP_EXP"),
  CompositeLabel = c("Overall Satisfaction Index",
                     "Digital Experience Index"),
  CalculationType = c("Mean", "Mean"),
  SourceQuestions = c("Q002,Q003,Q004,Q005",
                      "Q008,Q009"),
  Weights = c("", ""),
  SectionLabel = c("Satisfaction", "Experience"),
  stringsAsFactors = FALSE
)

# Write Survey Structure
struct_path <- file.path(output_dir, "Demo_Survey_Structure.xlsx")
wb_struct <- createWorkbook()

addWorksheet(wb_struct, "Project")
writeData(wb_struct, "Project", project_df)

addWorksheet(wb_struct, "Questions")
writeData(wb_struct, "Questions", questions_df)

addWorksheet(wb_struct, "Options")
writeData(wb_struct, "Options", options_df)

addWorksheet(wb_struct, "Composite_Metrics")
writeData(wb_struct, "Composite_Metrics", composite_df)

saveWorkbook(wb_struct, struct_path, overwrite = TRUE)
cat(sprintf("  -> Structure: %s\n", struct_path))

# ==============================================================================
# STEP 5: CREATE CONFIG WORKBOOK
# ==============================================================================
cat("Step 5: Creating Config workbook...\n")

# Settings sheet
settings_df <- data.frame(
  Setting = c(
    # File paths
    "structure_file", "output_subfolder", "output_filename", "output_format",
    # Weighting
    "apply_weighting", "weight_variable", "show_unweighted_n",
    # Display
    "show_frequency", "show_percent_column", "show_percent_row",
    "decimal_places_percent", "decimal_places_ratings", "decimal_places_index",
    # Box categories
    "boxcategory_frequency", "boxcategory_percent_column",
    # Significance
    "enable_significance_testing", "alpha", "significance_min_base",
    "bonferroni_correction",
    # Summary
    "create_index_summary", "show_standard_deviation", "show_net_positive",
    # HTML Report
    "html_report", "project_title", "brand_colour", "fieldwork_dates",
    "embed_frequencies", "include_summary",
    # Dashboard
    "dashboard_metrics",
    "dashboard_scale_mean", "dashboard_scale_index",
    "dashboard_green_net", "dashboard_amber_net",
    "dashboard_green_mean", "dashboard_amber_mean",
    "dashboard_green_index", "dashboard_amber_index",
    "dashboard_green_custom", "dashboard_amber_custom",
    # Index descriptor
    "index_descriptor",
    # Charts
    "show_charts"
  ),
  Value = c(
    # File paths
    "Demo_Survey_Structure.xlsx", "Output",
    "Demo_CX_Crosstabs.xlsx", "xlsx",
    # Weighting
    "TRUE", "Weight", "TRUE",
    # Display
    "TRUE", "TRUE", "FALSE",
    "0", "1", "1",
    # Box categories
    "FALSE", "TRUE",
    # Significance
    "TRUE", "0.05", "30", "TRUE",
    # Summary
    "Y", "FALSE", "TRUE",
    # HTML Report
    "TRUE", "Turas Demo: Customer Experience Survey 2025",
    "#0d8a8a", "Jan - Feb 2025",
    "TRUE", "TRUE",
    # Dashboard
    "NPS Score, NET POSITIVE, Mean, Good or excellent",
    "10", "5",
    "30", "0",
    "7", "5",
    "4", "3",
    "60", "40",
    # Index descriptor
    "Strongly disagree(1) = 1 to Strongly agree(5) = 5",
    # Charts
    "TRUE"
  ),
  stringsAsFactors = FALSE
)

# Selection sheet
selection_df <- data.frame(
  QuestionCode = c(
    "Region", "Gender", "Age_Group", "Segment",
    "Q001", "Q002", "Q003", "Q004", "Q005", "Q006", "Q007", "Q008",
    "Q009", "Q010",
    "Q011", "Q012", "Q013", "Q014", "Q015", "Q016", "Q017",
    "Q018", "Q019", "Q020", "Q021", "Q022", "Q023", "Q024", "Q025"
  ),
  Include = c(
    "N", "N", "N", "N",
    rep("Y", 25)
  ),
  UseBanner = c(
    "Y", "Y", "Y", "Y",
    rep("N", 25)
  ),
  BannerLabel = c(
    "Region", "Gender", "Age", "Customer Segment",
    rep("", 25)
  ),
  DisplayOrder = c(
    2, 3, 4, 5,
    rep(NA, 25)
  ),
  CreateIndex = c(
    rep("N", 4),
    "N",  # NPS has its own score
    rep("Y", 9),  # Rating questions get mean
    rep("Y", 7),  # Likert questions get index
    rep("N", 8)   # Single choice - no index
  ),
  BaseFilter = rep("", 29),
  stringsAsFactors = FALSE
)

# Q023 has a base filter (only asked if Q022 == "Yes")
selection_df$BaseFilter[selection_df$QuestionCode == "Q023"] <- 'Q022 == "Yes"'

# Write Config
config_path <- file.path(output_dir, "Demo_Crosstab_Config.xlsx")
wb_config <- createWorkbook()

addWorksheet(wb_config, "Settings")
writeData(wb_config, "Settings", settings_df)

addWorksheet(wb_config, "Selection")
writeData(wb_config, "Selection", selection_df)

# Add instructions sheet for completeness
addWorksheet(wb_config, "Instructions")
writeData(wb_config, "Instructions", data.frame(
  Instructions = c(
    "TURAS DEMO SURVEY - CONFIGURATION FILE",
    "",
    "This config file demonstrates all HTML report features:",
    "- 4 banner groups (Region, Gender, Age, Customer Segment)",
    "- 25 analysis questions (NPS, Rating, Likert, Single choice)",
    "- Dashboard with NPS Score, NET POSITIVE, Mean, and custom labels",
    "- Configurable colour thresholds",
    "- Weighted data (n=1,000)",
    "- Significance testing with Bonferroni correction",
    "",
    "To run: source('launch_turas.R'); launch_turas()",
    "Select this config file when prompted."
  ),
  stringsAsFactors = FALSE
))

saveWorkbook(wb_config, config_path, overwrite = TRUE)
cat(sprintf("  -> Config: %s\n", config_path))

# ==============================================================================
# SUMMARY
# ==============================================================================
cat("\n=== DEMO SURVEY GENERATED SUCCESSFULLY ===\n\n")
cat("Files created:\n")
cat(sprintf("  1. %s  (response data, n=%d)\n", basename(data_path), n))
cat(sprintf("  2. %s  (survey structure)\n", basename(struct_path)))
cat(sprintf("  3. %s  (analysis config)\n", basename(config_path)))
cat("\nSurvey design:\n")
cat("  - 4 Banners: Region (4), Gender (2), Age (5), Segment (4)\n")
cat("  - 1 NPS question (Q001)\n")
cat("  - 9 Rating questions 1-10 (Q002-Q010) with box categories\n")
cat("  - 7 Likert questions 1-5 (Q011-Q017) with NET POSITIVE\n")
cat("  - 8 Single choice questions (Q018-Q025)\n")
cat("  - Weighted data (Weight column)\n")
cat("  - Built-in group differences for significant findings\n")
cat("\nDashboard metrics configured:\n")
cat("  - NPS Score (from Q001)\n")
cat("  - NET POSITIVE (from Likert Q011-Q017)\n")
cat("  - Mean (from Rating Q002-Q010)\n")
cat("  - Good or excellent (from Q025 box category)\n")
cat("\nTo run the analysis:\n")
cat(sprintf("  1. Open Turas and select: %s\n", config_path))
cat("  2. The HTML report will be generated alongside the Excel output\n")
cat("  3. Open the .html file in any browser\n")
