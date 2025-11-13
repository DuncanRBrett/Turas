# ==============================================================================
# CREATE EXAMPLE CONFIGURATION
# ==============================================================================
# Helper script to create example confidence_config.xlsx for testing
#
# USAGE:
# source("examples/create_example_config.R")
# create_example_config("examples/confidence_config_example.xlsx")
#
# AUTHOR: Confidence Module Team
# DATE: 2025-11-13
# ==============================================================================

if (!require("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')", call. = FALSE)
}

#' Create example confidence configuration file
#'
#' Generates a complete example confidence_config.xlsx with all 3 sheets
#'
#' @param output_path Character. Path for output Excel file
#' @param data_file Character. Path to survey data file (default: "data/survey_data.csv")
#' @param output_file Character. Path for results file (default: "output/confidence_results.xlsx")
#'
#' @export
create_example_config <- function(output_path = "examples/confidence_config_example.xlsx",
                                   data_file = "examples/survey_data_example.csv",
                                   output_file = "examples/confidence_results_example.xlsx") {

  cat("Creating example confidence configuration...\n")

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # ============================================================================
  # SHEET 1: FILE_PATHS
  # ============================================================================

  openxlsx::addWorksheet(wb, "File_Paths")

  file_paths_df <- data.frame(
    Parameter = c(
      "Data_File",
      "Output_File",
      "Weight_Variable"
    ),
    Value = c(
      data_file,
      output_file,
      "weight"
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "File_Paths", file_paths_df, startRow = 1, startCol = 1,
                      colNames = TRUE, rowNames = FALSE)

  # Format header
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "File_Paths", header_style, rows = 1, cols = 1:2, gridExpand = TRUE)

  openxlsx::setColWidths(wb, "File_Paths", cols = 1:2, widths = c(20, 50))

  # ============================================================================
  # SHEET 2: STUDY_SETTINGS
  # ============================================================================

  openxlsx::addWorksheet(wb, "Study_Settings")

  study_settings_df <- data.frame(
    Setting = c(
      "Calculate_Effective_N",
      "Multiple_Comparison_Adjustment",
      "Multiple_Comparison_Method",
      "Bootstrap_Iterations",
      "Confidence_Level",
      "Decimal_Separator"
    ),
    Value = c(
      "Y",
      "N",
      "None",
      "5000",
      "0.95",
      "."
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Study_Settings", study_settings_df, startRow = 1, startCol = 1,
                      colNames = TRUE, rowNames = FALSE)

  openxlsx::addStyle(wb, "Study_Settings", header_style, rows = 1, cols = 1:2, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Study_Settings", cols = 1:2, widths = c(30, 15))

  # ============================================================================
  # SHEET 3: QUESTION_ANALYSIS
  # ============================================================================

  openxlsx::addWorksheet(wb, "Question_Analysis")

  # Create example questions (mix of proportions and means)
  question_analysis_df <- data.frame(
    Question_ID = c(
      "Q1_Gender",
      "Q2_Age",
      "Q3_Satisfaction",
      "Q4_NPS",
      "Q5_Brand_Awareness"
    ),
    Statistic_Type = c(
      "proportion",
      "proportion",
      "mean",
      "mean",
      "proportion"
    ),
    Categories = c(
      "1,2",           # Q1: Gender categories 1 and 2
      "1,2,3",         # Q2: Age groups 1, 2, 3
      NA,              # Q3: Mean (no categories)
      NA,              # Q4: NPS mean
      "1"              # Q5: Aware = 1
    ),
    Run_MOE = c(
      "Y",
      "Y",
      "Y",
      "Y",
      "Y"
    ),
    Run_Wilson = c(
      "Y",
      "Y",
      "N",
      "N",
      "Y"
    ),
    Run_Bootstrap = c(
      "Y",
      "N",
      "Y",
      "Y",
      "N"
    ),
    Run_Credible = c(
      "N",
      "N",
      "Y",
      "N",
      "N"
    ),
    Prior_Alpha = c(
      NA,
      NA,
      NA,
      NA,
      NA
    ),
    Prior_Beta = c(
      NA,
      NA,
      NA,
      NA,
      NA
    ),
    Prior_Mean = c(
      NA,
      NA,
      7.2,
      NA,
      NA
    ),
    Prior_SD = c(
      NA,
      NA,
      1.5,
      NA,
      NA
    ),
    Prior_N = c(
      NA,
      NA,
      500,
      NA,
      NA
    ),
    Notes = c(
      "Gender proportion",
      "Age group proportion",
      "Satisfaction mean (1-10 scale) with informed prior",
      "NPS score (-100 to 100)",
      "Brand awareness (top-of-mind)"
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Question_Analysis", question_analysis_df, startRow = 1, startCol = 1,
                      colNames = TRUE, rowNames = FALSE)

  openxlsx::addStyle(wb, "Question_Analysis", header_style, rows = 1,
                     cols = 1:ncol(question_analysis_df), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Question_Analysis", cols = 1:ncol(question_analysis_df), widths = "auto")

  # Save workbook
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)

  cat(sprintf("✓ Example configuration created: %s\n", output_path))
  cat("\nConfiguration includes:\n")
  cat("  - File paths sheet with data and output locations\n")
  cat("  - Study settings with 95% confidence, 5000 bootstrap iterations\n")
  cat("  - 5 example questions (3 proportions, 2 means)\n")
  cat("  - Mix of MOE, Wilson, Bootstrap, and Bayesian methods\n")
  cat("\nNext steps:\n")
  cat("  1. Create example survey data\n")
  cat("  2. Run: source('examples/create_example_data.R')\n")
  cat("  3. Run: create_example_data('examples/survey_data_example.csv')\n")
  cat("  4. Run analysis: source('R/00_main.R')\n")
  cat("  5. Run: run_confidence_analysis('examples/confidence_config_example.xlsx')\n\n")

  invisible(output_path)
}


#' Create example survey data
#'
#' Generates example survey data file for testing
#'
#' @param output_path Character. Path for output CSV file
#' @param n Integer. Number of respondents (default: 1000)
#' @param add_weights Logical. Add weight variable (default: TRUE)
#'
#' @export
create_example_data <- function(output_path = "examples/survey_data_example.csv",
                                 n = 1000,
                                 add_weights = TRUE) {

  cat(sprintf("Creating example survey data with %d respondents...\n", n))

  set.seed(42)

  # Q1: Gender (1 = Male, 2 = Female, 3 = Other)
  Q1_Gender <- sample(1:3, n, replace = TRUE, prob = c(0.48, 0.48, 0.04))

  # Q2: Age (1 = 18-34, 2 = 35-54, 3 = 55+)
  Q2_Age <- sample(1:3, n, replace = TRUE, prob = c(0.35, 0.40, 0.25))

  # Q3: Satisfaction (1-10 scale, mean around 7.5)
  Q3_Satisfaction <- pmin(10, pmax(1, round(rnorm(n, mean = 7.5, sd = 1.8))))

  # Q4: NPS (-100 to 100, mean around 30)
  Q4_NPS <- pmin(100, pmax(-100, round(rnorm(n, mean = 30, sd = 40))))

  # Q5: Brand Awareness (1 = Aware, 0 = Not aware, ~60% aware)
  Q5_Brand_Awareness <- sample(0:1, n, replace = TRUE, prob = c(0.40, 0.60))

  # Create data frame
  survey_data <- data.frame(
    Respondent_ID = 1:n,
    Q1_Gender = Q1_Gender,
    Q2_Age = Q2_Age,
    Q3_Satisfaction = Q3_Satisfaction,
    Q4_NPS = Q4_NPS,
    Q5_Brand_Awareness = Q5_Brand_Awareness
  )

  # Add weights if requested
  if (add_weights) {
    # Generate realistic weights (mean = 1, modest variation)
    # DEFF around 1.1-1.2 (CV around 0.3)
    survey_data$weight <- pmax(0.2, pmin(3.0, rnorm(n, mean = 1.0, sd = 0.3)))
  }

  # Add some random missing data (~5%)
  for (col in c("Q1_Gender", "Q2_Age", "Q3_Satisfaction", "Q4_NPS", "Q5_Brand_Awareness")) {
    missing_idx <- sample(1:n, size = round(n * 0.05))
    survey_data[missing_idx, col] <- NA
  }

  # Write to CSV
  write.csv(survey_data, output_path, row.names = FALSE)

  cat(sprintf("✓ Example survey data created: %s\n", output_path))
  cat(sprintf("  Respondents: %d\n", n))
  cat(sprintf("  Variables: %d\n", ncol(survey_data)))
  cat(sprintf("  Weighted: %s\n", ifelse(add_weights, "Yes", "No")))
  if (add_weights) {
    cat(sprintf("  Weight mean: %.3f\n", mean(survey_data$weight)))
    cat(sprintf("  Weight CV: %.3f\n", sd(survey_data$weight) / mean(survey_data$weight)))
  }
  cat("\nReady for analysis!\n")
  cat(sprintf("Run: run_confidence_analysis('examples/confidence_config_example.xlsx')\n\n"))

  invisible(output_path)
}


# ==============================================================================
# QUICK START FUNCTION
# ==============================================================================

#' Create complete example setup
#'
#' Creates both config and data files in one step
#'
#' @export
create_example_setup <- function() {
  # Create examples directory if needed
  if (!dir.exists("examples")) {
    dir.create("examples", recursive = TRUE)
  }

  # Create config
  create_example_config(
    output_path = "examples/confidence_config_example.xlsx",
    data_file = "survey_data_example.csv",
    output_file = "confidence_results_example.xlsx"
  )

  # Create data
  create_example_data(
    output_path = "examples/survey_data_example.csv",
    n = 1000,
    add_weights = TRUE
  )

  cat("\n")
  cat("================================================================================\n")
  cat("EXAMPLE SETUP COMPLETE\n")
  cat("================================================================================\n")
  cat("\nFiles created:\n")
  cat("  ✓ examples/confidence_config_example.xlsx\n")
  cat("  ✓ examples/survey_data_example.csv\n")
  cat("\nTo run analysis:\n")
  cat("  1. source('R/00_main.R')\n")
  cat("  2. setwd('modules/confidence')\n")
  cat("  3. run_confidence_analysis('examples/confidence_config_example.xlsx')\n")
  cat("\nOr use quick function:\n")
  cat("  quick_analysis('examples/confidence_config_example.xlsx')\n")
  cat("================================================================================\n\n")
}


# Print usage message
cat("\n=== EXAMPLE CONFIGURATION GENERATOR ===\n\n")
cat("Functions available:\n")
cat("  create_example_config()  - Create example config file\n")
cat("  create_example_data()    - Create example survey data\n")
cat("  create_example_setup()   - Create both config and data\n\n")
cat("Quick start:\n")
cat("  source('examples/create_example_config.R')\n")
cat("  create_example_setup()\n\n")
