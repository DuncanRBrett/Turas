# ==============================================================================
# MAXDIFF MODULE - EXAMPLE FILE GENERATOR
# ==============================================================================
# Creates example configuration and survey data files for testing
#
# USAGE:
# source("create_example_files.R")
# create_example_files()  # Creates files in current directory
# ==============================================================================

#' Create Example MaxDiff Files
#'
#' Generates example configuration Excel file and sample survey data
#' for testing the MaxDiff module.
#'
#' @param output_dir Character. Directory to save files (default: current dir)
#' @return List of created file paths
#' @export
create_example_files <- function(output_dir = ".") {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' required. Install with: install.packages('openxlsx')")
  }

  library(openxlsx)

  # ===========================================================================
  # CONFIGURATION FILE
  # ===========================================================================

  cat("Creating example configuration file...\n")

  # Sheet 1: PROJECT_SETTINGS
  project_settings <- data.frame(
    Setting = c(
      "Project_Name",
      "Project_Code",
      "Mode",
      "Raw_Data_Path",
      "Design_File_Path",
      "Output_Path",
      "Respondent_ID_Var",
      "Weight_Var",
      "Seed"
    ),
    Value = c(
      "Example MaxDiff Study",
      "MAXDIFF_EXAMPLE",
      "ANALYSIS",
      "example_survey_data.xlsx",
      "example_design.xlsx",
      "output/",
      "RespondentID",
      "Weight",
      "12345"
    ),
    Description = c(
      "Display name for the project",
      "Short code used in filenames",
      "DESIGN or ANALYSIS",
      "Path to survey responses (relative to config)",
      "Path to design file (relative to config)",
      "Output directory (relative to config)",
      "Column containing respondent IDs",
      "Column containing weights (blank for unweighted)",
      "Random seed for reproducibility"
    ),
    stringsAsFactors = FALSE
  )

  # Sheet 2: ITEMS
  items <- data.frame(
    Item_ID = paste0("ITEM_", 1:8),
    Item_Label = c(
      "High quality products",
      "Low prices",
      "Fast delivery",
      "Excellent customer service",
      "Wide product selection",
      "Easy returns",
      "Sustainable practices",
      "Loyalty rewards"
    ),
    Item_Group = c(
      "Product", "Price", "Service", "Service",
      "Product", "Service", "Values", "Value"
    ),
    Display_Order = 1:8,
    Include = rep(1, 8),
    Anchor_Item = c(rep(0, 7), 1),
    stringsAsFactors = FALSE
  )

  # Sheet 3: DESIGN_SETTINGS
  design_settings <- data.frame(
    Setting = c(
      "Design_Type",
      "Items_Per_Task",
      "Tasks_Per_Respondent",
      "N_Versions",
      "Max_Item_Repeat",
      "Min_Pair_Balance",
      "Optimize_Level_Balance",
      "Output_Filename"
    ),
    Value = c(
      "BALANCED",
      "4",
      "10",
      "3",
      "6",
      "0.8",
      "Y",
      "maxdiff_design.xlsx"
    ),
    Description = c(
      "BALANCED, OPTIMAL, or RANDOM",
      "Number of items shown per task",
      "Number of tasks each respondent completes",
      "Number of design versions",
      "Max times an item can appear",
      "Minimum balance threshold for item pairs",
      "Whether to balance within versions",
      "Output filename for generated design"
    ),
    stringsAsFactors = FALSE
  )

  # Sheet 4: SURVEY_MAPPING
  survey_mapping <- data.frame(
    Task_Number = 1:10,
    Version_Var = "DesignVersion",
    Best_Var = paste0("Q", 1:10, "_Best"),
    Worst_Var = paste0("Q", 1:10, "_Worst"),
    Shown_Var_1 = paste0("Q", 1:10, "_A"),
    Shown_Var_2 = paste0("Q", 1:10, "_B"),
    Shown_Var_3 = paste0("Q", 1:10, "_C"),
    Shown_Var_4 = paste0("Q", 1:10, "_D"),
    stringsAsFactors = FALSE
  )

  # Sheet 5: SEGMENT_SETTINGS
  segment_settings <- data.frame(
    Segment_ID = c("SEG_GENDER", "SEG_AGE"),
    Segment_Label = c("Gender", "Age Group"),
    Variable_Name = c("Gender", "AgeGroup"),
    Segment_Def = c("", ""),
    Include_in_Output = c(1, 1),
    stringsAsFactors = FALSE
  )

  # Sheet 6: OUTPUT_SETTINGS
  output_settings <- data.frame(
    Setting = c(
      "Include_Counts",
      "Include_Logit",
      "Include_HB",
      "Include_Individual",
      "Include_Segments",
      "Include_Charts",
      "Rescale_Method",
      "CI_Level",
      "Min_Respondents_Per_Segment",
      "HB_Iterations",
      "HB_Warmup",
      "HB_Chains",
      "Chart_Width",
      "Chart_Height",
      "Chart_DPI"
    ),
    Value = c(
      "Y",
      "Y",
      "N",
      "Y",
      "Y",
      "Y",
      "0_100",
      "0.95",
      "30",
      "2000",
      "1000",
      "4",
      "10",
      "6",
      "300"
    ),
    Description = c(
      "Include count-based scores (Best%, Worst%, Net)",
      "Include aggregate logit model",
      "Include Hierarchical Bayes estimation (requires cmdstanr)",
      "Include individual-level utilities",
      "Include segment analysis",
      "Generate visualization charts",
      "RAW, 0_100, or PROBABILITY",
      "Confidence interval level",
      "Min N for segment-level reporting",
      "HB MCMC iterations",
      "HB warmup iterations",
      "HB number of chains",
      "Chart width in inches",
      "Chart height in inches",
      "Chart resolution (dots per inch)"
    ),
    stringsAsFactors = FALSE
  )

  # Create workbook
  wb_config <- createWorkbook()

  addWorksheet(wb_config, "PROJECT_SETTINGS")
  writeData(wb_config, "PROJECT_SETTINGS", project_settings)

  addWorksheet(wb_config, "ITEMS")
  writeData(wb_config, "ITEMS", items)

  addWorksheet(wb_config, "DESIGN_SETTINGS")
  writeData(wb_config, "DESIGN_SETTINGS", design_settings)

  addWorksheet(wb_config, "SURVEY_MAPPING")
  writeData(wb_config, "SURVEY_MAPPING", survey_mapping)

  addWorksheet(wb_config, "SEGMENT_SETTINGS")
  writeData(wb_config, "SEGMENT_SETTINGS", segment_settings)

  addWorksheet(wb_config, "OUTPUT_SETTINGS")
  writeData(wb_config, "OUTPUT_SETTINGS", output_settings)

  config_path <- file.path(output_dir, "example_maxdiff_config.xlsx")
  saveWorkbook(wb_config, config_path, overwrite = TRUE)
  cat(sprintf("  Created: %s\n", config_path))

  # ===========================================================================
  # DESIGN FILE
  # ===========================================================================

  cat("Creating example design file...\n")

  # Generate balanced design
  set.seed(12345)
  item_ids <- paste0("ITEM_", 1:8)

  design_rows <- list()
  row_idx <- 1

  for (version in 1:3) {
    for (task in 1:10) {
      # Sample 4 items for this task
      shown_items <- sample(item_ids, 4)

      design_rows[[row_idx]] <- data.frame(
        Version = version,
        Task_Number = task,
        Item1_ID = shown_items[1],
        Item2_ID = shown_items[2],
        Item3_ID = shown_items[3],
        Item4_ID = shown_items[4],
        stringsAsFactors = FALSE
      )
      row_idx <- row_idx + 1
    }
  }

  design <- do.call(rbind, design_rows)

  wb_design <- createWorkbook()
  addWorksheet(wb_design, "Design")
  writeData(wb_design, "Design", design)

  design_path <- file.path(output_dir, "example_design.xlsx")
  saveWorkbook(wb_design, design_path, overwrite = TRUE)
  cat(sprintf("  Created: %s\n", design_path))

  # ===========================================================================
  # SURVEY DATA FILE
  # ===========================================================================

  cat("Creating example survey data file...\n")

  set.seed(12345)
  n_respondents <- 200

  # Create survey data
  survey_data <- data.frame(
    RespondentID = 1:n_respondents,
    Weight = runif(n_respondents, 0.8, 1.2),
    DesignVersion = sample(1:3, n_respondents, replace = TRUE),
    Gender = sample(c("Male", "Female"), n_respondents, replace = TRUE),
    AgeGroup = sample(c("18-34", "35-54", "55+"), n_respondents, replace = TRUE),
    stringsAsFactors = FALSE
  )

  # Simulate true utilities (item preferences)
  true_utils <- c(1.5, 2.0, 1.0, 0.5, 0.8, 0.3, -0.5, 0)  # ITEM_1 through ITEM_8
  names(true_utils) <- paste0("ITEM_", 1:8)

  # Generate responses for each respondent
  for (resp in 1:n_respondents) {
    version <- survey_data$DesignVersion[resp]

    # Get tasks for this version
    version_design <- design[design$Version == version, ]

    for (task in 1:10) {
      task_design <- version_design[version_design$Task_Number == task, ]
      shown_items <- c(
        task_design$Item1_ID,
        task_design$Item2_ID,
        task_design$Item3_ID,
        task_design$Item4_ID
      )

      # Store shown items
      survey_data[resp, paste0("Q", task, "_A")] <- shown_items[1]
      survey_data[resp, paste0("Q", task, "_B")] <- shown_items[2]
      survey_data[resp, paste0("Q", task, "_C")] <- shown_items[3]
      survey_data[resp, paste0("Q", task, "_D")] <- shown_items[4]

      # Calculate choice probabilities based on utilities
      utils <- true_utils[shown_items] + rnorm(4, 0, 0.5)  # Add noise

      # Best choice (highest utility with logit noise)
      best_probs <- exp(utils) / sum(exp(utils))
      best_idx <- sample(1:4, 1, prob = best_probs)
      survey_data[resp, paste0("Q", task, "_Best")] <- best_idx

      # Worst choice (lowest utility, from remaining items)
      remaining_idx <- setdiff(1:4, best_idx)
      worst_utils <- -utils[remaining_idx]  # Negate for worst
      worst_probs <- exp(worst_utils) / sum(exp(worst_utils))
      worst_choice <- sample(remaining_idx, 1, prob = worst_probs)
      survey_data[resp, paste0("Q", task, "_Worst")] <- worst_choice
    }
  }

  wb_data <- createWorkbook()
  addWorksheet(wb_data, "Data")
  writeData(wb_data, "Data", survey_data)

  data_path <- file.path(output_dir, "example_survey_data.xlsx")
  saveWorkbook(wb_data, data_path, overwrite = TRUE)
  cat(sprintf("  Created: %s\n", data_path))

  # ===========================================================================
  # OUTPUT DIRECTORY
  # ===========================================================================

  output_subdir <- file.path(output_dir, "output")
  if (!dir.exists(output_subdir)) {
    dir.create(output_subdir)
  }

  cat("\nExample files created successfully!\n")
  cat("To run the analysis:\n")
  cat("  1. source('modules/maxdiff/R/00_main.R')\n")
  cat("  2. run_maxdiff('example_maxdiff_config.xlsx')\n")

  invisible(list(
    config = config_path,
    design = design_path,
    data = data_path
  ))
}


# ==============================================================================
# AUTO-RUN
# ==============================================================================

if (!interactive()) {
  create_example_files()
}
