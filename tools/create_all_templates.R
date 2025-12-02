#!/usr/bin/env Rscript
# ==============================================================================
# Create All Turas Module Templates
# ==============================================================================
# This script creates Excel template files for all Turas modules with:
# - Clear headers and example data
# - Professional formatting
# - Helpful comments and instructions
# ==============================================================================

library(openxlsx)

# Create templates directory if it doesn't exist
templates_dir <- "templates"
if (!dir.exists(templates_dir)) {
  dir.create(templates_dir)
}

cat("Creating Turas module templates...\n\n")

# ==============================================================================
# PARSER MODULE TEMPLATES
# ==============================================================================

cat("Creating Parser templates...\n")

## 1. Questionnaire Template
create_parser_questionnaire_template <- function() {
  wb <- createWorkbook()
  addWorksheet(wb, "Questionnaire")

  # Example questionnaire data
  data <- data.frame(
    Q_Number = c("Q1", "Q2", "Q3", "Q4", "Q5", "Q6"),
    Question_Text = c(
      "Which of the following brands are you aware of? (Select all that apply)",
      "Which ONE brand do you prefer?",
      "How satisfied are you with [BRAND]? (1=Very Dissatisfied, 5=Very Satisfied)",
      "How likely are you to recommend [BRAND] to a friend? (0=Not at all likely, 10=Extremely likely)",
      "In the last 3 months, how many times have you purchased [PRODUCT]?",
      "What do you like most about [BRAND]? (Open-ended)"
    ),
    Response_Options = c(
      "Brand A, Brand B, Brand C, Brand D, Other, None",
      "Brand A, Brand B, Brand C, Brand D",
      "1, 2, 3, 4, 5",
      "0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10",
      "Numeric",
      "Open-ended"
    ),
    stringsAsFactors = FALSE
  )

  # Write data
  writeData(wb, "Questionnaire", data, startRow = 1)

  # Format headers
  headerStyle <- createStyle(
    fontName = "Arial",
    fontSize = 11,
    fontColour = "#FFFFFF",
    fgFill = "#4472C4",
    halign = "left",
    valign = "center",
    textDecoration = "bold",
    border = "TopBottomLeftRight",
    borderColour = "#000000"
  )

  addStyle(wb, "Questionnaire", headerStyle, rows = 1, cols = 1:3, gridExpand = TRUE)

  # Auto-width columns
  setColWidths(wb, "Questionnaire", cols = 1:3, widths = c(12, 80, 50))

  # Add instructions
  instructions <- data.frame(
    Instructions = c(
      "INSTRUCTIONS:",
      "1. Enter your survey questions in this template",
      "2. Q_Number: Unique identifier for each question (e.g., Q1, Q2, Q3)",
      "3. Question_Text: Full question wording as shown to respondents",
      "4. Response_Options: Comma-separated list of response options",
      "   - For multi-select: List all options",
      "   - For single choice: List all options",
      "   - For rating scales: List all scale points (e.g., 1, 2, 3, 4, 5)",
      "   - For numeric: Enter 'Numeric'",
      "   - For open-ended: Enter 'Open-ended'",
      "5. Run Parser to generate Survey_Structure.xlsx"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Questionnaire", instructions, startRow = 10, colNames = FALSE)

  # Save
  saveWorkbook(wb, file.path(templates_dir, "Parser_Questionnaire_Template.xlsx"), overwrite = TRUE)
  cat("  ✓ Parser_Questionnaire_Template.xlsx\n")
}

create_parser_questionnaire_template()

# ==============================================================================
# TABS MODULE TEMPLATES
# ==============================================================================

cat("\nCreating Tabs templates...\n")

## 1. Survey Structure Template
create_tabs_survey_structure_template <- function() {
  wb <- createWorkbook()

  # Questions Sheet
  addWorksheet(wb, "Questions")

  questions_data <- data.frame(
    QuestionCode = c("Q01", "Q02", "Q03", "Q04", "Q05", "Gender", "Age_Group"),
    QuestionText = c(
      "Brand Awareness (Unaided)",
      "Brand Consideration",
      "Brand Preference",
      "Overall Satisfaction (1-5)",
      "Likelihood to Recommend (0-10)",
      "Gender",
      "Age Group"
    ),
    Variable_Type = c(
      "Single_Response",
      "Single_Response",
      "Single_Response",
      "Rating",
      "NPS",
      "Single_Response",
      "Single_Response"
    ),
    Columns = c(NA, NA, NA, NA, NA, NA, NA),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Questions", questions_data)

  # Format
  headerStyle <- createStyle(
    fontName = "Arial", fontSize = 11, fontColour = "#FFFFFF",
    fgFill = "#4472C4", halign = "left", textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  addStyle(wb, "Questions", headerStyle, rows = 1, cols = 1:4, gridExpand = TRUE)
  setColWidths(wb, "Questions", cols = 1:4, widths = c(15, 40, 18, 12))

  # Options Sheet
  addWorksheet(wb, "Options")

  options_data <- data.frame(
    QuestionCode = c(
      "Q01", "Q01", "Q01", "Q01",
      "Q02", "Q02", "Q02",
      "Q03", "Q03", "Q03",
      "Q04", "Q04", "Q04", "Q04", "Q04",
      "Q05", "Q05", "Q05", "Q05", "Q05", "Q05", "Q05", "Q05", "Q05", "Q05", "Q05",
      "Gender", "Gender",
      "Age_Group", "Age_Group", "Age_Group"
    ),
    OptionValue = c(
      1, 2, 3, 4,
      1, 2, 3,
      1, 2, 3,
      1, 2, 3, 4, 5,
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
      1, 2,
      1, 2, 3
    ),
    OptionText = c(
      "Brand A", "Brand B", "Brand C", "None",
      "Brand A", "Brand B", "Brand C",
      "Brand A", "Brand B", "Brand C",
      "1 - Very Dissatisfied", "2", "3", "4", "5 - Very Satisfied",
      "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
      "Male", "Female",
      "18-34", "35-54", "55+"
    ),
    ShowInOutput = rep(TRUE, 31),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Options", options_data)
  addStyle(wb, "Options", headerStyle, rows = 1, cols = 1:4, gridExpand = TRUE)
  setColWidths(wb, "Options", cols = 1:4, widths = c(15, 12, 30, 12))

  saveWorkbook(wb, file.path(templates_dir, "Tabs_Survey_Structure_Template.xlsx"), overwrite = TRUE)
  cat("  ✓ Tabs_Survey_Structure_Template.xlsx\n")
}

## 2. Tabs Config Template
create_tabs_config_template <- function() {
  wb <- createWorkbook()

  # Settings Sheet
  addWorksheet(wb, "Settings")

  settings_data <- data.frame(
    Setting = c(
      "survey_structure_file",
      "data_file",
      "output_file",
      "show_significance",
      "significance_level",
      "minimum_base",
      "stat_test",
      "decimal_places",
      "decimal_places_average",
      "show_frequencies",
      "show_percentages",
      "weight_column"
    ),
    Value = c(
      "Survey_Structure.xlsx",
      "survey_data.csv",
      "Crosstab_Results.xlsx",
      "TRUE",
      "0.05",
      "30",
      "chi-square",
      "0",
      "1",
      "TRUE",
      "TRUE",
      "NA"
    ),
    Description = c(
      "Path to Survey_Structure.xlsx file",
      "Path to survey data file (CSV, XLSX, SAV, DTA)",
      "Path to output Excel file",
      "Show significance testing (TRUE/FALSE)",
      "Significance level (0.05 = 95% confidence, 0.10 = 90%)",
      "Minimum base size for significance testing",
      "Statistical test: chi-square, z-test, or t-test",
      "Decimal places for percentages (0 = whole numbers)",
      "Decimal places for averages",
      "Show frequency counts (TRUE/FALSE)",
      "Show column percentages (TRUE/FALSE)",
      "Weight column name (or NA if unweighted)"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Settings", settings_data)

  headerStyle <- createStyle(
    fontName = "Arial", fontSize = 11, fontColour = "#FFFFFF",
    fgFill = "#4472C4", halign = "left", textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  addStyle(wb, "Settings", headerStyle, rows = 1, cols = 1:3, gridExpand = TRUE)
  setColWidths(wb, "Settings", cols = 1:3, widths = c(25, 25, 55))

  # Banner Sheet
  addWorksheet(wb, "Banner")

  banner_data <- data.frame(
    BannerQuestion = c("Total", "Gender", "Age_Group"),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Banner", banner_data)
  addStyle(wb, "Banner", headerStyle, rows = 1, cols = 1, gridExpand = TRUE)
  setColWidths(wb, "Banner", cols = 1, widths = 20)

  # Stub Sheet
  addWorksheet(wb, "Stub")

  stub_data <- data.frame(
    StubQuestion = c("Q01", "Q02", "Q03", "Q04", "Q05"),
    BaseFilter = c(NA, NA, NA, "Gender == 'Male'", NA),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Stub", stub_data)
  addStyle(wb, "Stub", headerStyle, rows = 1, cols = 1:2, gridExpand = TRUE)
  setColWidths(wb, "Stub", cols = 1:2, widths = c(20, 30))

  saveWorkbook(wb, file.path(templates_dir, "Tabs_Config_Template.xlsx"), overwrite = TRUE)
  cat("  ✓ Tabs_Config_Template.xlsx\n")
}

create_tabs_survey_structure_template()
create_tabs_config_template()

# ==============================================================================
# TRACKER MODULE TEMPLATES
# ==============================================================================

cat("\nCreating Tracker templates...\n")

## 1. Tracking Config Template
create_tracker_config_template <- function() {
  wb <- createWorkbook()

  # Waves Sheet
  addWorksheet(wb, "Waves")

  waves_data <- data.frame(
    WaveID = c("W1", "W2", "W3", "W4"),
    WaveName = c("Q1 2024", "Q2 2024", "Q3 2024", "Q4 2024"),
    DataFile = c("wave1.csv", "wave2.csv", "wave3.csv", "wave4.csv"),
    FieldworkStart = as.Date(c("2024-01-01", "2024-04-01", "2024-07-01", "2024-10-01")),
    FieldworkEnd = as.Date(c("2024-01-15", "2024-04-15", "2024-07-15", "2024-10-15")),
    WeightVariable = c("Weight", "Weight", "Weight", "Weight"),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Waves", waves_data)

  headerStyle <- createStyle(
    fontName = "Arial", fontSize = 11, fontColour = "#FFFFFF",
    fgFill = "#4472C4", halign = "left", textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  addStyle(wb, "Waves", headerStyle, rows = 1, cols = 1:6, gridExpand = TRUE)
  setColWidths(wb, "Waves", cols = 1:6, widths = c(10, 15, 20, 15, 15, 15))

  # TrackedQuestions Sheet
  addWorksheet(wb, "TrackedQuestions")

  questions_data <- data.frame(
    QuestionCode = c("Q01_Awareness", "Q02_Consideration", "Q03_Preference", "Q04_Satisfaction", "Q05_NPS"),
    QuestionText = c(
      "Brand Awareness (Unaided)",
      "Brand Consideration",
      "Brand Preference",
      "Overall Satisfaction (1-5)",
      "Net Promoter Score (0-10)"
    ),
    QuestionType = c("proportion", "proportion", "proportion", "rating", "nps"),
    stringsAsFactors = FALSE
  )

  writeData(wb, "TrackedQuestions", questions_data)
  addStyle(wb, "TrackedQuestions", headerStyle, rows = 1, cols = 1:3, gridExpand = TRUE)
  setColWidths(wb, "TrackedQuestions", cols = 1:3, widths = c(20, 40, 15))

  # Banner Sheet
  addWorksheet(wb, "Banner")

  banner_data <- data.frame(
    BreakVariable = c("Total", "Gender", "Age_Group"),
    BreakLabel = c("Total", "Gender", "Age Group"),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Banner", banner_data)
  addStyle(wb, "Banner", headerStyle, rows = 1, cols = 1:2, gridExpand = TRUE)
  setColWidths(wb, "Banner", cols = 1:2, widths = c(20, 20))

  # Settings Sheet
  addWorksheet(wb, "Settings")

  settings_data <- data.frame(
    SettingName = c(
      "project_name",
      "output_file",
      "confidence_level",
      "min_base_size",
      "trend_significance",
      "decimal_places_proportion",
      "decimal_places_mean",
      "show_sample_sizes"
    ),
    SettingValue = c(
      "2024 Brand Tracking Study",
      "Tracking_Results.xlsx",
      "0.95",
      "30",
      "TRUE",
      "0",
      "2",
      "TRUE"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Settings", settings_data)
  addStyle(wb, "Settings", headerStyle, rows = 1, cols = 1:2, gridExpand = TRUE)
  setColWidths(wb, "Settings", cols = 1:2, widths = c(30, 30))

  saveWorkbook(wb, file.path(templates_dir, "Tracker_Config_Template.xlsx"), overwrite = TRUE)
  cat("  ✓ Tracker_Config_Template.xlsx\n")
}

## 2. Question Mapping Template
create_tracker_question_mapping_template <- function() {
  wb <- createWorkbook()

  addWorksheet(wb, "QuestionMap")

  mapping_data <- data.frame(
    QuestionCode = c("Q01_Awareness", "Q02_Consideration", "Q03_Preference", "Q04_Satisfaction", "Q05_NPS"),
    QuestionText = c(
      "Brand Awareness (Unaided)",
      "Brand Consideration",
      "Brand Preference",
      "Overall Satisfaction (1-5)",
      "Net Promoter Score (0-10)"
    ),
    QuestionType = c("proportion", "proportion", "proportion", "rating", "nps"),
    W1 = c("Q1_Awareness", "Q2_Consider", "Q3_Preference", "Q4_Sat", "Q5_NPS"),
    W2 = c("Q1_Awareness", "Q2_Consider", "Q3_Preference", "Q4_Sat", "Q5_NPS"),
    W3 = c("Q01_Aware", "Q02_Consideration", "Q03_Pref", "Q04_Satisfaction", "Q05_NPS_Score"),
    W4 = c("Q01_Aware", "Q02_Consideration", "Q03_Pref", "Q04_Satisfaction", "Q05_NPS_Score"),
    stringsAsFactors = FALSE
  )

  writeData(wb, "QuestionMap", mapping_data)

  headerStyle <- createStyle(
    fontName = "Arial", fontSize = 11, fontColour = "#FFFFFF",
    fgFill = "#4472C4", halign = "left", textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  addStyle(wb, "QuestionMap", headerStyle, rows = 1, cols = 1:7, gridExpand = TRUE)
  setColWidths(wb, "QuestionMap", cols = 1:7, widths = c(20, 40, 15, 18, 18, 20, 20))

  # Add note
  note_data <- data.frame(
    Note = c(
      "",
      "INSTRUCTIONS:",
      "- QuestionCode: Standardized question identifier (used in Tracking_Config.xlsx)",
      "- QuestionText: Question wording",
      "- QuestionType: proportion, rating, nps, or composite",
      "- W1, W2, W3, W4: Actual column names in each wave's data file",
      "- Use NA if question not asked in that wave",
      "- Add more wave columns (W5, W6, etc.) as needed"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "QuestionMap", note_data, startRow = 8, colNames = FALSE)

  saveWorkbook(wb, file.path(templates_dir, "Tracker_Question_Mapping_Template.xlsx"), overwrite = TRUE)
  cat("  ✓ Tracker_Question_Mapping_Template.xlsx\n")
}

create_tracker_config_template()
create_tracker_question_mapping_template()

# ==============================================================================
# CONFIDENCE MODULE TEMPLATES
# ==============================================================================

cat("\nCreating Confidence templates...\n")

create_confidence_config_template <- function() {
  wb <- createWorkbook()

  # Settings Sheet
  addWorksheet(wb, "Settings")

  settings_data <- data.frame(
    Setting = c(
      "data_file",
      "survey_structure_file",
      "output_file",
      "weight_variable",
      "confidence_level",
      "decimal_separator",
      "bootstrap_iterations",
      "methods_proportion",
      "methods_mean"
    ),
    Value = c(
      "survey_data.csv",
      "Survey_Structure.xlsx",
      "Confidence_Analysis.xlsx",
      "Weight",
      "0.95",
      ".",
      "5000",
      "MOE,Wilson,Bootstrap,Bayesian",
      "tdist,Bootstrap,Bayesian"
    ),
    Description = c(
      "Path to survey data file",
      "Path to Survey_Structure.xlsx (from Tabs or Parser)",
      "Output Excel file name",
      "Weight column name (or NA if unweighted)",
      "Confidence level (0.90, 0.95, or 0.99)",
      "Decimal separator: period (.) or comma (,)",
      "Number of bootstrap iterations (1000-10000)",
      "Methods for proportions: MOE, Wilson, Bootstrap, Bayesian",
      "Methods for means: tdist, Bootstrap, Bayesian"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Settings", settings_data)

  headerStyle <- createStyle(
    fontName = "Arial", fontSize = 11, fontColour = "#FFFFFF",
    fgFill = "#4472C4", halign = "left", textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  addStyle(wb, "Settings", headerStyle, rows = 1, cols = 1:3, gridExpand = TRUE)
  setColWidths(wb, "Settings", cols = 1:3, widths = c(25, 35, 50))

  # Questions Sheet
  addWorksheet(wb, "Questions")

  questions_data <- data.frame(
    QuestionCode = c("Q01", "Q02", "Q03", "Q04"),
    QuestionType = c("proportion", "proportion", "rating", "nps"),
    BayesianPrior_Mean = c(0.5, 0.5, 3.5, 25),
    BayesianPrior_N = c(30, 30, 30, 30),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Questions", questions_data)
  addStyle(wb, "Questions", headerStyle, rows = 1, cols = 1:4, gridExpand = TRUE)
  setColWidths(wb, "Questions", cols = 1:4, widths = c(18, 18, 20, 18))

  # Add instructions
  note_data <- data.frame(
    Note = c(
      "",
      "INSTRUCTIONS:",
      "- QuestionCode: Must match codes in Survey_Structure.xlsx",
      "- QuestionType: proportion, rating, or nps",
      "- BayesianPrior_Mean: Prior estimate (e.g., 0.5 = 50% for proportions, 3.5 for 1-5 rating)",
      "- BayesianPrior_N: Prior sample size (strength of prior, typically 30-100)",
      "- Leave Bayesian columns empty if not using Bayesian method"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Questions", note_data, startRow = 7, colNames = FALSE)

  saveWorkbook(wb, file.path(templates_dir, "Confidence_Config_Template.xlsx"), overwrite = TRUE)
  cat("  ✓ Confidence_Config_Template.xlsx\n")
}

create_confidence_config_template()

# ==============================================================================
# SEGMENT MODULE TEMPLATES
# ==============================================================================

cat("\nCreating Segment templates...\n")

create_segment_config_template <- function() {
  wb <- createWorkbook()

  addWorksheet(wb, "Config")

  config_data <- data.frame(
    parameter = c(
      "data_file",
      "id_variable",
      "clustering_vars",
      "profiling_vars",
      "k_min",
      "k_max",
      "k_final",
      "output_folder",
      "random_seed",
      "max_iterations",
      "n_starts",
      "outlier_method",
      "outlier_threshold",
      "handle_outliers",
      "run_mode"
    ),
    value = c(
      "survey_data.csv",
      "RespondentID",
      "Q1,Q2,Q3,Q4,Q5",
      "Age,Gender,Region",
      "3",
      "6",
      "4",
      "output/",
      "123",
      "100",
      "25",
      "zscore",
      "3",
      "remove",
      "explore"
    ),
    description = c(
      "Path to survey data file (CSV or XLSX)",
      "Column name containing respondent ID",
      "Comma-separated list of variables for clustering",
      "Comma-separated list of variables for profiling segments",
      "Minimum number of segments to test (exploration mode)",
      "Maximum number of segments to test (exploration mode)",
      "Final number of segments (final run mode)",
      "Output directory for results",
      "Random seed for reproducibility",
      "Maximum k-means iterations",
      "Number of random starts for k-means",
      "Outlier detection method: zscore or mahalanobis",
      "Outlier threshold (z-score units or chi-square critical value)",
      "How to handle outliers: remove, flag, or ignore",
      "Run mode: explore (test k_min to k_max) or final (use k_final)"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Config", config_data)

  headerStyle <- createStyle(
    fontName = "Arial", fontSize = 11, fontColour = "#FFFFFF",
    fgFill = "#4472C4", halign = "left", textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  addStyle(wb, "Config", headerStyle, rows = 1, cols = 1:3, gridExpand = TRUE)
  setColWidths(wb, "Config", cols = 1:3, widths = c(22, 30, 60))

  saveWorkbook(wb, file.path(templates_dir, "Segment_Config_Template.xlsx"), overwrite = TRUE)
  cat("  ✓ Segment_Config_Template.xlsx\n")
}

create_segment_config_template()

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("TEMPLATE CREATION COMPLETE\n")
cat("================================================================================\n")
cat("\nAll templates created in:", normalizePath(templates_dir), "\n\n")
cat("Templates created:\n")
cat("  Parser:\n")
cat("    - Parser_Questionnaire_Template.xlsx\n")
cat("  Tabs:\n")
cat("    - Tabs_Survey_Structure_Template.xlsx\n")
cat("    - Tabs_Config_Template.xlsx\n")
cat("  Tracker:\n")
cat("    - Tracker_Config_Template.xlsx\n")
cat("    - Tracker_Question_Mapping_Template.xlsx\n")
cat("  Confidence:\n")
cat("    - Confidence_Config_Template.xlsx\n")
cat("  Segment:\n")
cat("    - Segment_Config_Template.xlsx\n")
cat("\nTotal: 7 template files\n\n")
