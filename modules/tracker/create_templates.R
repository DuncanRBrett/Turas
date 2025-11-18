#!/usr/bin/env Rscript
# ==============================================================================
# Create TurasTracker Template Files
# ==============================================================================
#
# Creates production-ready template files for TurasTracker setup:
# 1. tracking_config_template.xlsx
# 2. question_mapping_template.xlsx
# 3. wave_data_template.csv
#
# ==============================================================================

library(openxlsx)

message("Creating TurasTracker template files...")

# Get script directory for output paths
script_dir <- if (interactive()) {
  getwd()
} else {
  dirname(sys.frame(1)$ofile)
}

# ==============================================================================
# 1. TRACKING CONFIG TEMPLATE
# ==============================================================================

message("\n1. Creating tracking_config_template.xlsx...")

# Create workbook
wb_config <- createWorkbook()

# --- Waves Sheet ---
addWorksheet(wb_config, "Waves")

waves_data <- data.frame(
  WaveID = c("W1", "W2", "W3"),
  WaveName = c("Wave 1 - Q1 2024", "Wave 2 - Q2 2024", "Wave 3 - Q3 2024"),
  DataFile = c("wave1_data.csv", "wave2_data.csv", "wave3_data.csv"),
  FieldworkStart = as.Date(c("2024-01-15", "2024-04-15", "2024-07-15")),
  FieldworkEnd = as.Date(c("2024-02-15", "2024-05-15", "2024-08-15")),
  WeightVar = c("weight", "weight", "weight"),
  stringsAsFactors = FALSE
)

writeData(wb_config, "Waves", waves_data)

# Add notes
writeData(wb_config, "Waves",
          "NOTE: DataFile can be absolute path or relative to data directory",
          startRow = nrow(waves_data) + 3, startCol = 1)
writeData(wb_config, "Waves",
          "NOTE: WeightVar is the column name in your data file containing weights",
          startRow = nrow(waves_data) + 4, startCol = 1)

# --- Settings Sheet ---
addWorksheet(wb_config, "Settings")

settings_data <- data.frame(
  SettingName = c(
    "project_name",
    "decimal_places_ratings",
    "decimal_places_nps",
    "decimal_places_percentages",
    "show_significance",
    "alpha",
    "minimum_base",
    "weight_variable"
  ),
  Value = c(
    "Customer Satisfaction Tracking",
    "1",
    "1",
    "1",
    "TRUE",
    "0.05",
    "30",
    "weight"
  ),
  Description = c(
    "Project name (appears in output)",
    "Decimal places for rating scores (0-3)",
    "Decimal places for NPS scores (0-3)",
    "Decimal places for percentages (0-3)",
    "Show significance testing indicators (TRUE/FALSE)",
    "Significance level for testing (typically 0.05)",
    "Minimum base size for reporting",
    "Default weight variable name (can override in Waves sheet)"
  ),
  stringsAsFactors = FALSE
)

writeData(wb_config, "Settings", settings_data)

# --- Banner Sheet ---
addWorksheet(wb_config, "Banner")

banner_data <- data.frame(
  BreakVariable = c("Total", "Gender", "AgeGroup", "Region"),
  BreakLabel = c("Total", "Gender", "Age", "Region"),
  stringsAsFactors = FALSE
)

writeData(wb_config, "Banner", banner_data)

writeData(wb_config, "Banner",
          "NOTE: 'Total' is required and includes all respondents",
          startRow = nrow(banner_data) + 3, startCol = 1)
writeData(wb_config, "Banner",
          "NOTE: BreakVariable must match column names in your wave data files",
          startRow = nrow(banner_data) + 4, startCol = 1)
writeData(wb_config, "Banner",
          "NOTE: TurasTracker will auto-detect unique values in each BreakVariable",
          startRow = nrow(banner_data) + 5, startCol = 1)

# --- TrackedQuestions Sheet ---
addWorksheet(wb_config, "TrackedQuestions")

tracked_data <- data.frame(
  QuestionCode = c(
    "Q_SAT",
    "Q_RECOMMEND",
    "Q_VALUE",
    "Q_QUALITY",
    "Q_NPS",
    "COMP_OVERALL"
  ),
  stringsAsFactors = FALSE
)

writeData(wb_config, "TrackedQuestions", tracked_data)

writeData(wb_config, "TrackedQuestions",
          "NOTE: QuestionCode must match the codes in question_mapping.xlsx",
          startRow = nrow(tracked_data) + 3, startCol = 1)
writeData(wb_config, "TrackedQuestions",
          "NOTE: Include only questions you want to track across waves",
          startRow = nrow(tracked_data) + 4, startCol = 1)

# Save
saveWorkbook(wb_config,
             file.path(script_dir, "tracking_config_template.xlsx"),
             overwrite = TRUE)

message("  ✓ Created tracking_config_template.xlsx")

# ==============================================================================
# 2. QUESTION MAPPING TEMPLATE
# ==============================================================================

message("\n2. Creating question_mapping_template.xlsx...")

# Create workbook
wb_mapping <- createWorkbook()

# --- QuestionMap Sheet ---
addWorksheet(wb_mapping, "QuestionMap")

mapping_data <- data.frame(
  QuestionCode = c(
    "Q_SAT",
    "Q_RECOMMEND",
    "Q_VALUE",
    "Q_QUALITY",
    "Q_NPS",
    "Q_SUPPORT_QUALITY",
    "Q_SUPPORT_SPEED",
    "COMP_OVERALL"
  ),
  QuestionText = c(
    "Overall satisfaction with our service",
    "Likelihood to recommend to a friend",
    "Value for money",
    "Product quality",
    "How likely are you to recommend us? (0-10)",
    "Support team quality",
    "Support response speed",
    "Overall Score (Composite)"
  ),
  QuestionType = c(
    "Rating",
    "Rating",
    "Rating",
    "Rating",
    "NPS",
    "Rating",
    "Rating",
    "Composite"
  ),
  Wave1 = c(
    "Q10",
    "Q11",
    "Q12",
    "Q13",
    "Q20",
    "Q15a",
    "Q15b",
    NA
  ),
  Wave2 = c(
    "Q11",
    "Q12",
    "Q13",
    "Q14",
    "Q21",
    "Q16a",
    "Q16b",
    NA
  ),
  Wave3 = c(
    "Q12",
    "Q13",
    "Q14",
    "Q15",
    "Q22",
    "Q17a",
    "Q17b",
    NA
  ),
  SourceQuestions = c(
    NA,
    NA,
    NA,
    NA,
    NA,
    NA,
    NA,
    "Q_SAT,Q_VALUE,Q_QUALITY"
  ),
  stringsAsFactors = FALSE
)

writeData(wb_mapping, "QuestionMap", mapping_data)

# Add notes
writeData(wb_mapping, "QuestionMap",
          "NOTE: QuestionCode is your standardized question identifier (used in tracking)",
          startRow = nrow(mapping_data) + 3, startCol = 1)
writeData(wb_mapping, "QuestionMap",
          "NOTE: QuestionType must be: Rating, SingleChoice, MultiChoice, NPS, Index, OpenEnd, or Composite",
          startRow = nrow(mapping_data) + 4, startCol = 1)
writeData(wb_mapping, "QuestionMap",
          "NOTE: Wave1, Wave2, etc. contain the wave-specific question codes from your data files",
          startRow = nrow(mapping_data) + 5, startCol = 1)
writeData(wb_mapping, "QuestionMap",
          "NOTE: Leave Wave columns blank (NA) if question not asked in that wave",
          startRow = nrow(mapping_data) + 6, startCol = 1)
writeData(wb_mapping, "QuestionMap",
          "NOTE: For Composite questions, list source questions in SourceQuestions (comma-separated)",
          startRow = nrow(mapping_data) + 7, startCol = 1)
writeData(wb_mapping, "QuestionMap",
          "NOTE: Composite questions should have NA in Wave columns (they're calculated, not in raw data)",
          startRow = nrow(mapping_data) + 8, startCol = 1)

# Add examples section
writeData(wb_mapping, "QuestionMap",
          "EXAMPLES:",
          startRow = nrow(mapping_data) + 10, startCol = 1)
writeData(wb_mapping, "QuestionMap",
          "- Rating: Satisfaction scales (e.g., 1-10, 1-5)",
          startRow = nrow(mapping_data) + 11, startCol = 1)
writeData(wb_mapping, "QuestionMap",
          "- NPS: Net Promoter Score (0-10 scale)",
          startRow = nrow(mapping_data) + 12, startCol = 1)
writeData(wb_mapping, "QuestionMap",
          "- SingleChoice: Pick one option (e.g., Yes/No, product choice)",
          startRow = nrow(mapping_data) + 13, startCol = 1)
writeData(wb_mapping, "QuestionMap",
          "- Composite: Derived metric combining multiple questions (e.g., Overall Score = mean of Q_SAT + Q_VALUE + Q_QUALITY)",
          startRow = nrow(mapping_data) + 14, startCol = 1)

# Save
saveWorkbook(wb_mapping,
             file.path(script_dir, "question_mapping_template.xlsx"),
             overwrite = TRUE)

message("  ✓ Created question_mapping_template.xlsx")

# ==============================================================================
# 3. WAVE DATA TEMPLATE (CSV)
# ==============================================================================

message("\n3. Creating wave_data_template.csv...")

# Create sample data
set.seed(42)
n <- 100

wave_data <- data.frame(
  ResponseID = 1:n,

  # Banner variables
  Gender = sample(c("Male", "Female", "Other"), n, replace = TRUE, prob = c(0.48, 0.48, 0.04)),
  AgeGroup = sample(c("18-34", "35-54", "55+"), n, replace = TRUE, prob = c(0.35, 0.40, 0.25)),
  Region = sample(c("North", "South", "East", "West"), n, replace = TRUE),

  # Rating questions (1-10 scale)
  Q10 = sample(c(1:10, NA), n, replace = TRUE, prob = c(rep(0.02, 3), rep(0.08, 4), rep(0.12, 3), 0.05)),
  Q11 = sample(c(1:10, NA), n, replace = TRUE, prob = c(rep(0.02, 3), rep(0.08, 4), rep(0.12, 3), 0.05)),
  Q12 = sample(c(1:10, NA), n, replace = TRUE, prob = c(rep(0.02, 3), rep(0.08, 4), rep(0.12, 3), 0.05)),
  Q13 = sample(c(1:10, NA), n, replace = TRUE, prob = c(rep(0.02, 3), rep(0.08, 4), rep(0.12, 3), 0.05)),

  # Support questions (1-10 scale)
  Q15a = sample(c(1:10, NA), n, replace = TRUE, prob = c(rep(0.02, 3), rep(0.08, 4), rep(0.12, 3), 0.05)),
  Q15b = sample(c(1:10, NA), n, replace = TRUE, prob = c(rep(0.02, 3), rep(0.08, 4), rep(0.12, 3), 0.05)),

  # NPS question (0-10 scale)
  Q20 = sample(c(0:10, NA), n, replace = TRUE, prob = c(rep(0.03, 6), rep(0.06, 3), rep(0.12, 2), 0.05)),

  # Weight variable
  weight = runif(n, 0.5, 1.5),

  stringsAsFactors = FALSE
)

# Save
write.csv(wave_data,
          file.path(script_dir, "wave_data_template.csv"),
          row.names = FALSE)

message("  ✓ Created wave_data_template.csv")

# ==============================================================================
# SUMMARY
# ==============================================================================

message("\n" , paste(rep("=", 80), collapse = ""))
message("TEMPLATE CREATION COMPLETE")
message(paste(rep("=", 80), collapse = ""))
message("\nCreated 3 template files:")
message("  1. tracking_config_template.xlsx")
message("  2. question_mapping_template.xlsx")
message("  3. wave_data_template.csv")
message("\nLocation: /Users/duncan/Documents/Turas/modules/tracker/")
message("\nNext steps:")
message("  1. Copy templates to your project directory")
message("  2. Rename files (remove '_template' suffix)")
message("  3. Customize with your project-specific data")
message("  4. Create additional wave data files (wave2_data.csv, wave3_data.csv)")
message("  5. Run: source('run_tracker.R'); run_tracker(...)")
message("\nSee TurasTracker_User_Manual.md for detailed setup instructions.")
message(paste(rep("=", 80), collapse = ""))
