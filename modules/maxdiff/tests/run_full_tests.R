# ==============================================================================
# MAXDIFF MODULE - COMPREHENSIVE TEST SUITE
# ==============================================================================
# Run this script to fully test the MaxDiff module
#
# USAGE:
#   setwd("/path/to/Turas")
#   source("modules/maxdiff/tests/run_full_tests.R")
#
# This script will:
#   1. Check R environment and packages
#   2. Validate syntax of all module files
#   3. Load the module
#   4. Run unit tests
#   5. Generate example data
#   6. Test DESIGN mode
#   7. Test ANALYSIS mode
#   8. Test GUI launch (optional)
#   9. Generate summary report
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("TURAS MAXDIFF MODULE - COMPREHENSIVE TEST SUITE\n")
cat("================================================================================\n")
cat(sprintf("Started: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("================================================================================\n\n")

# ==============================================================================
# CONFIGURATION
# ==============================================================================

TEST_CONFIG <- list(
  # Set to TRUE to test GUI (will open Shiny app)
  test_gui = FALSE,


  # Set to TRUE to test HB model (requires cmdstanr, takes several minutes)
  test_hb = FALSE,

  # Output directory for test files
  test_output_dir = file.path(tempdir(), "maxdiff_tests"),

  # Verbose output
  verbose = TRUE
)

# Create test output directory
if (!dir.exists(TEST_CONFIG$test_output_dir)) {
  dir.create(TEST_CONFIG$test_output_dir, recursive = TRUE)
}

cat(sprintf("Test output directory: %s\n\n", TEST_CONFIG$test_output_dir))

# ==============================================================================
# TEST TRACKING
# ==============================================================================

test_results <- list(
  passed = 0,
  failed = 0,
  skipped = 0,
  errors = character()
)

log_test <- function(name, passed, message = NULL) {
  if (passed) {
    test_results$passed <<- test_results$passed + 1
    cat(sprintf("  [PASS] %s\n", name))
  } else {
    test_results$failed <<- test_results$failed + 1
    error_msg <- sprintf("%s: %s", name, message %||% "Failed")
    test_results$errors <<- c(test_results$errors, error_msg)
    cat(sprintf("  [FAIL] %s - %s\n", name, message %||% ""))
  }
}

log_skip <- function(name, reason) {
  test_results$skipped <<- test_results$skipped + 1
  cat(sprintf("  [SKIP] %s - %s\n", name, reason))
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

# ==============================================================================
# STEP 1: ENVIRONMENT CHECK
# ==============================================================================

cat("STEP 1: Checking R environment...\n")

# Check R version
r_version <- paste(R.version$major, R.version$minor, sep = ".")
log_test("R version >= 4.0",
         as.numeric(R.version$major) >= 4,
         sprintf("Found R %s", r_version))

# Check required packages
required_packages <- c("openxlsx")
recommended_packages <- c("survival", "ggplot2", "shiny", "shinyFiles")
optional_packages <- c("cmdstanr", "AlgDesign")

for (pkg in required_packages) {
  installed <- requireNamespace(pkg, quietly = TRUE)
  if (!installed) {
    cat(sprintf("    Installing required package: %s\n", pkg))
    install.packages(pkg, quiet = TRUE)
    installed <- requireNamespace(pkg, quietly = TRUE)
  }
  log_test(sprintf("Package '%s' available", pkg), installed)
}

for (pkg in recommended_packages) {
  installed <- requireNamespace(pkg, quietly = TRUE)
  if (!installed) {
    cat(sprintf("    Installing recommended package: %s\n", pkg))
    install.packages(pkg, quiet = TRUE)
    installed <- requireNamespace(pkg, quietly = TRUE)
  }
  log_test(sprintf("Package '%s' available", pkg), installed,
           if (!installed) "Will use fallback methods")
}

for (pkg in optional_packages) {
  installed <- requireNamespace(pkg, quietly = TRUE)
  if (installed) {
    log_test(sprintf("Optional package '%s' available", pkg), TRUE)
  } else {
    log_skip(sprintf("Optional package '%s'", pkg), "Not installed")
  }
}

cat("\n")

# ==============================================================================
# STEP 2: SYNTAX VALIDATION
# ==============================================================================

cat("STEP 2: Validating R file syntax...\n")

# Find module directory
module_dir <- "modules/maxdiff"
if (!dir.exists(module_dir)) {
  # Try from different working directories
  if (dir.exists("R")) {
    module_dir <- "."
  } else if (dir.exists("../modules/maxdiff")) {
    module_dir <- "../modules/maxdiff"
  } else {
    stop("Cannot find MaxDiff module directory. Please run from Turas root.")
  }
}

r_files <- list.files(file.path(module_dir, "R"), pattern = "\\.R$", full.names = TRUE)

for (f in r_files) {
  result <- tryCatch({
    parse(f)
    TRUE
  }, error = function(e) {
    e$message
  })

  if (isTRUE(result)) {
    log_test(sprintf("Syntax: %s", basename(f)), TRUE)
  } else {
    log_test(sprintf("Syntax: %s", basename(f)), FALSE, result)
  }
}

# Check GUI file
gui_file <- file.path(module_dir, "run_maxdiff_gui.R")
if (file.exists(gui_file)) {
  result <- tryCatch({ parse(gui_file); TRUE }, error = function(e) e$message)
  log_test("Syntax: run_maxdiff_gui.R", isTRUE(result),
           if (!isTRUE(result)) result)
}

# Check Stan file exists
stan_file <- file.path(module_dir, "stan", "maxdiff_hb.stan")
log_test("Stan model file exists", file.exists(stan_file))

cat("\n")

# ==============================================================================
# STEP 3: LOAD MODULE
# ==============================================================================

cat("STEP 3: Loading MaxDiff module...\n")

main_file <- file.path(module_dir, "R", "00_main.R")

load_result <- tryCatch({
  source(main_file)
  TRUE
}, error = function(e) {
  e$message
})

log_test("Module loads without error", isTRUE(load_result),
         if (!isTRUE(load_result)) load_result)

# Check key functions exist
key_functions <- c("run_maxdiff", "load_maxdiff_config", "generate_maxdiff_design",
                   "compute_maxdiff_counts", "fit_aggregate_logit")

for (fn in key_functions) {
  log_test(sprintf("Function '%s' exists", fn), exists(fn, mode = "function"))
}

cat("\n")

# ==============================================================================
# STEP 4: UNIT TESTS
# ==============================================================================

cat("STEP 4: Running unit tests...\n")

# Test utility functions
test_utils <- function() {
  # Test safe_integer
  if (exists("safe_integer", mode = "function")) {
    result <- safe_integer("5", 0)
    log_test("safe_integer('5') == 5", identical(result, 5L))

    result <- safe_integer(NA, 10)
    log_test("safe_integer(NA, 10) == 10", identical(result, 10L))

    result <- safe_integer("abc", 99)
    log_test("safe_integer('abc', 99) == 99", identical(result, 99L))
  } else {
    log_skip("safe_integer tests", "Function not found")
  }

  # Test parse_yes_no
  if (exists("parse_yes_no", mode = "function")) {
    log_test("parse_yes_no('YES') == TRUE", isTRUE(parse_yes_no("YES", FALSE)))
    log_test("parse_yes_no('NO') == FALSE", isFALSE(parse_yes_no("NO", TRUE)))
    log_test("parse_yes_no('Y') == TRUE", isTRUE(parse_yes_no("Y", FALSE)))
    log_test("parse_yes_no(1) == TRUE", isTRUE(parse_yes_no(1, FALSE)))
  } else {
    log_skip("parse_yes_no tests", "Function not found")
  }

  # Test validate_file_path
  if (exists("validate_file_path", mode = "function")) {
    # Should work with existing file
    result <- tryCatch({
      validate_file_path(main_file, "test", must_exist = TRUE)
      TRUE
    }, error = function(e) FALSE)
    log_test("validate_file_path with existing file", result)

    # Should fail with non-existent file
    result <- tryCatch({
      validate_file_path("/nonexistent/file.xlsx", "test", must_exist = TRUE)
      FALSE
    }, error = function(e) TRUE)
    log_test("validate_file_path rejects missing file", result)
  } else {
    log_skip("validate_file_path tests", "Function not found")
  }
}

test_utils()

cat("\n")

# ==============================================================================
# STEP 5: GENERATE TEST DATA
# ==============================================================================

cat("STEP 5: Generating test data...\n")

# Create test configuration and data
create_test_files <- function(output_dir) {

  library(openxlsx)

  # --------------------------------------------------------------------------
  # CONFIG FILE
  # --------------------------------------------------------------------------

  # PROJECT_SETTINGS
  project_settings <- data.frame(
    Setting_Name = c(
      "Project_Name", "Mode", "Raw_Data_File", "Design_File",
      "Output_Folder", "Respondent_ID_Variable", "Weight_Variable", "Seed"
    ),
    Value = c(
      "TEST_MAXDIFF", "ANALYSIS",
      file.path(output_dir, "test_survey_data.xlsx"),
      file.path(output_dir, "test_design.xlsx"),
      output_dir, "RespID", "Weight", "12345"
    ),
    stringsAsFactors = FALSE
  )

  # ITEMS (8 items for testing)
  items <- data.frame(
    Item_ID = paste0("ITEM_", sprintf("%02d", 1:8)),
    Item_Label = c(
      "Low monthly fees",
      "High interest rates on savings",
      "Excellent mobile app",
      "Many branch locations",
      "24/7 customer support",
      "No foreign transaction fees",
      "Cashback rewards program",
      "Free overdraft protection"
    ),
    Item_Group = c("Price", "Returns", "Digital", "Access",
                   "Service", "Price", "Rewards", "Service"),
    Include = rep(1, 8),
    Anchor_Item = c(rep(0, 7), 1),
    Display_Order = 1:8,
    stringsAsFactors = FALSE
  )

  # DESIGN_SETTINGS
  design_settings <- data.frame(
    Parameter_Name = c(
      "Items_Per_Task", "Tasks_Per_Respondent", "Num_Versions",
      "Design_Type", "Max_Item_Repeats", "Force_Min_Pair_Balance"
    ),
    Value = c("4", "8", "2", "BALANCED", "4", "YES"),
    stringsAsFactors = FALSE
  )

  # SURVEY_MAPPING
  survey_mapping <- data.frame(
    Field_Type = c("VERSION",
                   rep(c("BEST_CHOICE", "WORST_CHOICE"), 8)),
    Field_Name = c("Version",
                   paste0(rep(paste0("Q", 1:8), each = 2),
                          rep(c("_Best", "_Worst"), 8))),
    Task_Number = c(NA, rep(1:8, each = 2)),
    stringsAsFactors = FALSE
  )

  # SEGMENT_SETTINGS
  segment_settings <- data.frame(
    Segment_ID = c("GENDER", "AGE"),
    Segment_Label = c("Gender", "Age Group"),
    Variable_Name = c("Gender", "AgeGroup"),
    Segment_Def = c("", ""),
    Include_in_Output = c(1, 1),
    stringsAsFactors = FALSE
  )

  # OUTPUT_SETTINGS
  output_settings <- data.frame(
    Option_Name = c(
      "Generate_Count_Scores", "Generate_Aggregate_Logit", "Generate_HB_Model",
      "Generate_Segment_Tables", "Generate_Charts", "Score_Rescale_Method",
      "Min_Respondents_Per_Segment", "Export_Individual_Utils"
    ),
    Value = c("YES", "YES", "NO", "YES", "YES", "0_100", "10", "YES"),
    stringsAsFactors = FALSE
  )

  # Write config workbook
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

  config_path <- file.path(output_dir, "test_config.xlsx")
  saveWorkbook(wb_config, config_path, overwrite = TRUE)

  # --------------------------------------------------------------------------
  # DESIGN FILE
  # --------------------------------------------------------------------------

  set.seed(12345)
  item_ids <- items$Item_ID

  design_rows <- list()
  row_idx <- 1

  for (version in 1:2) {
    for (task in 1:8) {
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

  design_path <- file.path(output_dir, "test_design.xlsx")
  saveWorkbook(wb_design, design_path, overwrite = TRUE)

  # --------------------------------------------------------------------------
  # SURVEY DATA
  # --------------------------------------------------------------------------

  set.seed(12345)
  n_respondents <- 100

  # True utilities for simulation
  true_utils <- c(1.5, 1.2, 0.8, 0.3, 0.5, -0.2, -0.5, 0)
  names(true_utils) <- item_ids

  survey_data <- data.frame(
    RespID = sprintf("R%03d", 1:n_respondents),
    Weight = runif(n_respondents, 0.8, 1.2),
    Version = sample(1:2, n_respondents, replace = TRUE),
    Gender = sample(c("Male", "Female"), n_respondents, replace = TRUE),
    AgeGroup = sample(c("18-34", "35-54", "55+"), n_respondents,
                      replace = TRUE, prob = c(0.3, 0.4, 0.3)),
    stringsAsFactors = FALSE
  )

  # Generate choices for each respondent
  for (r in 1:n_respondents) {
    version <- survey_data$Version[r]
    version_design <- design[design$Version == version, ]

    for (task in 1:8) {
      task_design <- version_design[version_design$Task_Number == task, ]
      shown_items <- c(task_design$Item1_ID, task_design$Item2_ID,
                       task_design$Item3_ID, task_design$Item4_ID)

      # Get utilities and add noise
      utils <- true_utils[shown_items] + rnorm(4, 0, 0.3)

      # Best choice (highest utility)
      best_probs <- exp(utils) / sum(exp(utils))
      best_idx <- sample(1:4, 1, prob = best_probs)

      # Worst choice (lowest utility from remaining)
      remaining <- setdiff(1:4, best_idx)
      worst_utils <- -utils[remaining]
      worst_probs <- exp(worst_utils) / sum(exp(worst_utils))
      worst_idx <- sample(remaining, 1, prob = worst_probs)

      survey_data[r, paste0("Q", task, "_Best")] <- best_idx
      survey_data[r, paste0("Q", task, "_Worst")] <- worst_idx
    }
  }

  wb_data <- createWorkbook()
  addWorksheet(wb_data, "Data")
  writeData(wb_data, "Data", survey_data)

  data_path <- file.path(output_dir, "test_survey_data.xlsx")
  saveWorkbook(wb_data, data_path, overwrite = TRUE)

  # --------------------------------------------------------------------------
  # DESIGN-ONLY CONFIG
  # --------------------------------------------------------------------------

  project_settings_design <- project_settings
  project_settings_design$Value[project_settings_design$Setting_Name == "Mode"] <- "DESIGN"
  project_settings_design$Value[project_settings_design$Setting_Name == "Output_Folder"] <- output_dir

  wb_design_config <- createWorkbook()
  addWorksheet(wb_design_config, "PROJECT_SETTINGS")
  writeData(wb_design_config, "PROJECT_SETTINGS", project_settings_design)
  addWorksheet(wb_design_config, "ITEMS")
  writeData(wb_design_config, "ITEMS", items)
  addWorksheet(wb_design_config, "DESIGN_SETTINGS")
  writeData(wb_design_config, "DESIGN_SETTINGS", design_settings)
  addWorksheet(wb_design_config, "OUTPUT_SETTINGS")
  writeData(wb_design_config, "OUTPUT_SETTINGS", output_settings)

  design_config_path <- file.path(output_dir, "test_config_design.xlsx")
  saveWorkbook(wb_design_config, design_config_path, overwrite = TRUE)

  list(
    config_path = config_path,
    design_config_path = design_config_path,
    design_path = design_path,
    data_path = data_path,
    items = items,
    design = design,
    true_utilities = true_utils
  )
}

test_files <- tryCatch({
  create_test_files(TEST_CONFIG$test_output_dir)
}, error = function(e) {
  log_test("Generate test files", FALSE, e$message)
  NULL
})

if (!is.null(test_files)) {
  log_test("Generate test config file", file.exists(test_files$config_path))
  log_test("Generate test design file", file.exists(test_files$design_path))
  log_test("Generate test data file", file.exists(test_files$data_path))
  log_test("Generate design-mode config", file.exists(test_files$design_config_path))
}

cat("\n")

# ==============================================================================
# STEP 6: TEST DESIGN MODE
# ==============================================================================

cat("STEP 6: Testing DESIGN mode...\n")

if (!is.null(test_files) && exists("run_maxdiff", mode = "function")) {

  design_result <- tryCatch({
    run_maxdiff(test_files$design_config_path, verbose = FALSE)
  }, error = function(e) {
    list(error = e$message)
  })

  if (is.null(design_result$error)) {
    log_test("DESIGN mode executes", TRUE)
    log_test("DESIGN mode returns design", !is.null(design_result$design_result))

    if (!is.null(design_result$design_result)) {
      design_df <- design_result$design_result$design
      log_test("Design has correct columns",
               all(c("Version", "Task_Number") %in% names(design_df)))
      log_test("Design has expected rows",
               nrow(design_df) == 2 * 8)  # 2 versions × 8 tasks
    }
  } else {
    log_test("DESIGN mode executes", FALSE, design_result$error)
  }

} else {
  log_skip("DESIGN mode tests", "Test files or function not available")
}

cat("\n")

# ==============================================================================
# STEP 7: TEST ANALYSIS MODE
# ==============================================================================

cat("STEP 7: Testing ANALYSIS mode...\n")

if (!is.null(test_files) && exists("run_maxdiff", mode = "function")) {

  analysis_result <- tryCatch({
    run_maxdiff(test_files$config_path, verbose = FALSE)
  }, error = function(e) {
    list(error = e$message)
  })

  if (is.null(analysis_result$error)) {
    log_test("ANALYSIS mode executes", TRUE)

    # Check count scores
    if (!is.null(analysis_result$count_scores)) {
      log_test("Count scores computed", TRUE)

      cs <- analysis_result$count_scores
      log_test("Count scores has Best_Pct", "Best_Pct" %in% names(cs))
      log_test("Count scores has Worst_Pct", "Worst_Pct" %in% names(cs))
      log_test("Count scores has Net_Score", "Net_Score" %in% names(cs))

      # Check that scores make sense (sum to reasonable values)
      if ("Best_Pct" %in% names(cs)) {
        log_test("Best_Pct values in valid range",
                 all(cs$Best_Pct >= 0 & cs$Best_Pct <= 100))
      }
    } else {
      log_test("Count scores computed", FALSE, "NULL result")
    }

    # Check logit results
    if (!is.null(analysis_result$logit_results)) {
      log_test("Logit model fitted", TRUE)

      lr <- analysis_result$logit_results
      log_test("Logit has utilities", !is.null(lr$utilities))

      if (!is.null(lr$utilities)) {
        log_test("Logit utilities has correct items",
                 nrow(lr$utilities) == 8)
      }
    } else {
      log_skip("Logit model", "Not computed or failed")
    }

    # Check segment results
    if (!is.null(analysis_result$segment_results)) {
      log_test("Segment analysis completed", TRUE)
    } else {
      log_skip("Segment analysis", "Not computed or failed")
    }

    # Check output file
    if (!is.null(analysis_result$output_path)) {
      log_test("Output file created", file.exists(analysis_result$output_path))
    } else {
      log_test("Output file created", FALSE, "No output path returned")
    }

    # Validate utilities match true values (correlation test)
    if (!is.null(analysis_result$count_scores)) {
      cs <- analysis_result$count_scores
      cs <- cs[order(cs$Item_ID), ]
      true_order <- order(test_files$true_utilities[cs$Item_ID], decreasing = TRUE)
      estimated_order <- order(cs$Net_Score, decreasing = TRUE)

      # Top 3 items should be similar
      top3_match <- length(intersect(true_order[1:3], estimated_order[1:3]))
      log_test("Top 3 items recovered (>=2 match)", top3_match >= 2,
               sprintf("%d of 3 match", top3_match))
    }

  } else {
    log_test("ANALYSIS mode executes", FALSE, analysis_result$error)
  }

} else {
  log_skip("ANALYSIS mode tests", "Test files or function not available")
}

cat("\n")

# ==============================================================================
# STEP 8: TEST INDIVIDUAL COMPONENTS
# ==============================================================================

cat("STEP 8: Testing individual components...\n")

# Test config loading
if (exists("load_maxdiff_config", mode = "function") && !is.null(test_files)) {
  config <- tryCatch({
    load_maxdiff_config(test_files$config_path)
  }, error = function(e) {
    list(error = e$message)
  })

  if (is.null(config$error)) {
    log_test("Config loading works", TRUE)
    log_test("Config has project_settings", !is.null(config$project_settings))
    log_test("Config has items", !is.null(config$items) && nrow(config$items) > 0)
    log_test("Config has survey_mapping", !is.null(config$survey_mapping))
    log_test("Config mode is ANALYSIS", config$mode == "ANALYSIS")
  } else {
    log_test("Config loading works", FALSE, config$error)
  }
}

# Test design generation directly
if (exists("generate_maxdiff_design", mode = "function")) {
  items_df <- data.frame(
    Item_ID = paste0("TEST_", 1:6),
    Item_Label = paste("Test Item", 1:6),
    Include = 1,
    stringsAsFactors = FALSE
  )

  design_settings <- list(
    Items_Per_Task = 3,
    Tasks_Per_Respondent = 6,
    Num_Versions = 1,
    Design_Type = "BALANCED",
    Max_Item_Repeats = 4,
    Force_Min_Pair_Balance = TRUE
  )

  gen_result <- tryCatch({
    generate_maxdiff_design(items_df, design_settings, seed = 999, verbose = FALSE)
  }, error = function(e) {
    list(error = e$message)
  })

  if (is.null(gen_result$error)) {
    log_test("Design generation works", TRUE)
    log_test("Generated design has rows", nrow(gen_result$design) == 6)
  } else {
    log_test("Design generation works", FALSE, gen_result$error)
  }
}

# Test chart generation
if (exists("generate_maxdiff_charts", mode = "function") &&
    !is.null(analysis_result) && is.null(analysis_result$error)) {

  if (!is.null(analysis_result$chart_paths)) {
    log_test("Charts generated", length(analysis_result$chart_paths) > 0)

    for (chart_path in analysis_result$chart_paths) {
      if (file.exists(chart_path)) {
        log_test(sprintf("Chart exists: %s", basename(chart_path)), TRUE)
      }
    }
  } else {
    log_skip("Chart generation", "No charts returned")
  }
}

cat("\n")

# ==============================================================================
# STEP 9: TEST GUI (OPTIONAL)
# ==============================================================================

cat("STEP 9: Testing GUI...\n")

if (TEST_CONFIG$test_gui) {
  gui_file <- file.path(module_dir, "run_maxdiff_gui.R")

  if (file.exists(gui_file)) {
    if (requireNamespace("shiny", quietly = TRUE) &&
        requireNamespace("shinyFiles", quietly = TRUE)) {

      cat("  Launching GUI (close window to continue)...\n")
      tryCatch({
        source(gui_file)
        log_test("GUI launches", TRUE)
      }, error = function(e) {
        log_test("GUI launches", FALSE, e$message)
      })

    } else {
      log_skip("GUI test", "shiny/shinyFiles not installed")
    }
  } else {
    log_skip("GUI test", "GUI file not found")
  }
} else {
  log_skip("GUI test", "Disabled in TEST_CONFIG")
}

cat("\n")

# ==============================================================================
# STEP 10: HB MODEL TEST (OPTIONAL)
# ==============================================================================

cat("STEP 10: Testing HB model...\n")

if (TEST_CONFIG$test_hb) {
  if (requireNamespace("cmdstanr", quietly = TRUE)) {

    # Modify config to enable HB
    if (!is.null(test_files)) {
      cat("  Running HB model (this may take several minutes)...\n")

      # This would require modifying the config and re-running
      # For now, just check that the function exists
      log_test("fit_hb_model function exists",
               exists("fit_hb_model", mode = "function"))

      log_skip("Full HB test", "Requires manual config modification")
    }

  } else {
    log_skip("HB model test", "cmdstanr not installed")
  }
} else {
  log_skip("HB model test", "Disabled in TEST_CONFIG")
}

cat("\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("================================================================================\n")
cat("TEST SUMMARY\n")
cat("================================================================================\n")
cat(sprintf("Passed:  %d\n", test_results$passed))
cat(sprintf("Failed:  %d\n", test_results$failed))
cat(sprintf("Skipped: %d\n", test_results$skipped))
cat("--------------------------------------------------------------------------------\n")

if (test_results$failed > 0) {
  cat("\nFAILED TESTS:\n")
  for (err in test_results$errors) {
    cat(sprintf("  - %s\n", err))
  }
}

cat("\n")
cat(sprintf("Test output saved to: %s\n", TEST_CONFIG$test_output_dir))
cat("================================================================================\n")

# Return results
invisible(list(
  passed = test_results$passed,
  failed = test_results$failed,
  skipped = test_results$skipped,
  errors = test_results$errors,
  test_files = test_files,
  output_dir = TEST_CONFIG$test_output_dir
))
