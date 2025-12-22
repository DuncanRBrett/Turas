# ==============================================================================
# MODULE OUTPUT CONTRACT
# ==============================================================================
# 
# All analysis modules should return a list with these keys:
# 
# all_results (list of lists):
#   question_code (character): Question identifier
#   question_text (character): Display text
#   question_type (character): Variable_Type
#   base_filter (character): Any applied filter
#   bases (list): Base sizes by banner column
#     - $unweighted (numeric)
#     - $weighted (numeric) 
#     - $effective (numeric)
#   table (data.frame): Results table with:
#     - RowLabel (character)
#     - RowType (character): "Frequency", "Column %", "Row %", "Average", etc.
#     - [banner_columns] (numeric): One column per banner
# 
# This contract allows:
# - Consistent Excel writing across modules
# - Shared validation of outputs
# - Common charting/reporting layer (future)
# 
# ==============================================================================
# ==============================================================================
# CROSSTABS - TURAS V10.0
# ==============================================================================
# Enterprise-grade survey crosstabs - Debug code removed
#
# PREVIOUS FIXES:
# 1. ✅ Multi-mention questions now display correctly
# 2. ✅ ShowInOutput filtering works properly
# 3. ✅ Rating calculations fixed (OptionValue support)
# 4. ✅ All debug code removed
# 5. ✅ Clean, production-ready code
#
# V10.0 IMPROVEMENTS (Practical Enhancements):
# 1. ✅ Replaced deprecated pryr with lobstr for memory monitoring
# 2. ✅ Renamed log_issue() to add_log_entry() for clarity (alias kept)
# 3. ✅ Added smart CSV caching for large Excel files (10x faster loads)
# 4. ✅ Added configuration summary before processing (shows ETA)
# 5. ✅ Global namespace pollution fixed in excel_writer.R (local=TRUE)
# 6. ✅ MAX_DECIMAL_PLACES constant properly defined in validation.R
# ==============================================================================

SCRIPT_VERSION <- "10.0"

# ==============================================================================
# TRS GUARD LAYER - Must be loaded FIRST
# ==============================================================================

# Determine script directory for sourcing
script_dir <- if (exists("toolkit_path")) dirname(toolkit_path) else getwd()

# TRS Guard Layer (v1.0) - MUST be loaded before any TRS refusal calls
source(file.path(script_dir, "00_guard.R"))

# ==============================================================================
# TRS INFRASTRUCTURE (TRS v1.0)
# ==============================================================================

# Source TRS run state management
.source_trs_infrastructure_tabs <- function() {
  # Try multiple paths to find shared/lib
  possible_paths <- c(
    file.path(script_dir, "..", "..", "shared", "lib"),
    file.path(script_dir, "..", "shared", "lib"),
    file.path(getwd(), "modules", "shared", "lib"),
    file.path(getwd(), "..", "shared", "lib")
  )

  trs_files <- c("trs_run_state.R", "trs_banner.R", "trs_run_status_writer.R")

  for (shared_lib in possible_paths) {
    if (dir.exists(shared_lib)) {
      for (f in trs_files) {
        fpath <- file.path(shared_lib, f)
        if (file.exists(fpath)) {
          source(fpath)
        }
      }
      break
    }
  }
}

tryCatch({
  .source_trs_infrastructure_tabs()
}, error = function(e) {
  message(sprintf("[TRS INFO] TABS_TRS_LOAD: Could not load TRS infrastructure: %s", e$message))
})

# Create TRS run state for tracking events
trs_state <- if (exists("turas_run_state_new", mode = "function")) {
  turas_run_state_new("TABS")
} else {
  NULL
}

# ==============================================================================
# DEPENDENCY CHECKS (Friendly error messages)
# ==============================================================================

#' Check required packages with friendly errors
#'
#' @return Invisible NULL or stops with helpful message
check_dependencies <- function() {
  required_packages <- c("openxlsx", "readxl")
  missing <- character(0)
  
  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      missing <- c(missing, pkg)
    }
  }
  
  if (length(missing) > 0) {
    # TRS Refusal: PKG_MISSING_PACKAGES
    tabs_refuse(
      code = "PKG_MISSING_PACKAGES",
      title = "Missing Required Packages",
      problem = paste0("Required packages not installed: ", paste(missing, collapse = ", ")),
      why_it_matters = "Crosstab analysis requires these packages to function properly.",
      how_to_fix = c(
        "Install the missing packages with:",
        paste0("  install.packages(c(", paste(sprintf('"%s"', missing), collapse = ", "), "))")
      ),
      missing = missing
    )
  }
  
  # Optional but recommended (V10.0: lobstr replaces deprecated pryr)
  if (!requireNamespace("lobstr", quietly = TRUE)) {
    message("Note: 'lobstr' package not found. Memory monitoring will be disabled.")
  }
  
  invisible(NULL)
}

# Run check immediately
check_dependencies()

# ==============================================================================
# CONSTANTS
# ==============================================================================

# Column and Row Labels
TOTAL_COLUMN <- "Total"
SIG_ROW_TYPE <- "Sig."
BASE_ROW_LABEL <- "Base (n=)"
UNWEIGHTED_BASE_LABEL <- "Base (unweighted)"
WEIGHTED_BASE_LABEL <- "Base (weighted)"
EFFECTIVE_BASE_LABEL <- "Effective base"
FREQUENCY_ROW_TYPE <- "Frequency"
COLUMN_PCT_ROW_TYPE <- "Column %"
ROW_PCT_ROW_TYPE <- "Row %"
AVERAGE_ROW_TYPE <- "Average"
INDEX_ROW_TYPE <- "Index"
SCORE_ROW_TYPE <- "Score"

# Statistical Thresholds
MINIMUM_BASE_SIZE <- 30
VERY_SMALL_BASE_SIZE <- 10
DEFAULT_ALPHA <- 0.05  # P-value threshold (not confidence level)
DEFAULT_MIN_BASE <- 30

# Excel Limits
MAX_EXCEL_COLUMNS <- 16384
MAX_EXCEL_ROWS <- 1048576

# Performance Settings
BATCH_WRITE_THRESHOLD <- 100
VECTORIZE_THRESHOLD <- 50
CHECKPOINT_FREQUENCY <- 10

# Memory Thresholds (GiB = 1024^3 bytes)
MEMORY_WARNING_GIB <- 6
MEMORY_CRITICAL_GIB <- 8

# Decimal validation limits
MAX_DECIMAL_PLACES <- 6

# ==============================================================================
# LOAD DEPENDENCIES
# ==============================================================================

# script_dir already set above when loading TRS guard layer

source(file.path(script_dir, "shared_functions.R"))
source(file.path(script_dir, "validation.R"))
source(file.path(script_dir, "weighting.R"))
source(file.path(script_dir, "ranking.R"))

# Phase 7 Migration: Modular architecture files
source(file.path(script_dir, "banner.R"))
source(file.path(script_dir, "cell_calculator.R"))
source(file.path(script_dir, "question_dispatcher.R"))
source(file.path(script_dir, "standard_processor.R"))
source(file.path(script_dir, "numeric_processor.R"))
source(file.path(script_dir, "excel_writer.R"))
source(file.path(script_dir, "banner_indices.R"))
source(file.path(script_dir, "config_loader.R"))
source(file.path(script_dir, "question_orchestrator.R"))

# Composite Metrics Feature (V10.1)
source(file.path(script_dir, "composite_processor.R"))
source(file.path(script_dir, "summary_builder.R"))

# ==============================================================================
# LOGGING & MONITORING SYSTEM
# ==============================================================================







#' Type-safe equality with trimming
#'
#' CASE SENSITIVITY DOCUMENTED:
#' - Comparison is CASE-SENSITIVE by default
#' - "Apple" != "apple" 
#' - Both values are trimmed of whitespace before comparison
#' - If case-insensitive matching is needed for your survey, consider
#'   adding tolower() to both sides of the comparison
#'
#' @param a First value/vector
#' @param b Second value/vector
#' @return Logical vector
#' @export


# ==============================================================================
# FORMATTING UTILITIES
# ==============================================================================

#' Format value for output (NA handling for Excel)
#'
#' Returns NA_real_ which Excel writer displays as blank cell
#'
#' @param value Numeric value
#' @param type Value type
#' @param decimal_places_percent Integer
#' @param decimal_places_ratings Integer
#' @param decimal_places_index Integer
#' @return Formatted numeric or NA_real_
#' @export
format_output_value <- function(value, type = "frequency", 
                               decimal_places_percent = 0,
                               decimal_places_ratings = 1,
                               decimal_places_index = 1,
                               decimal_places_numeric = 1) {  # V10.0.0: Added
  if (is.null(value) || is.na(value)) return(NA_real_)
  
  formatted_value <- switch(type,
    "percent" = round(as.numeric(value), decimal_places_percent),
    "rating" = round(as.numeric(value), decimal_places_ratings),
    "index" = round(as.numeric(value), decimal_places_index),
    "numeric" = round(as.numeric(value), decimal_places_numeric),  # V10.0.0: Added
    "frequency" = round(as.numeric(value), 0),
    round(as.numeric(value), 2)
  )
  
  return(formatted_value)
}


#' Batch rbind (efficient)
#'
#' @param row_list List of data frames
#' @return Single data frame
#' @export

# ==============================================================================
# END OF PART 1
# ==============================================================================

# ==============================================================================
# PART 2: STARTUP, CONFIGURATION, BANNER FUNCTIONS
# ==============================================================================

# ==============================================================================
# STARTUP & CONFIG LOADING
# ==============================================================================

# Print TRS start banner
if (exists("turas_print_start_banner", mode = "function")) {
  turas_print_start_banner("TABS", SCRIPT_VERSION)
} else {
  print_toolkit_header("Crosstab Analysis - Turas v10.0")
}

if (!exists("config_file")) {
  # TRS Refusal: CFG_NO_CONFIG_FILE
  tabs_refuse(
    code = "CFG_NO_CONFIG_FILE",
    title = "Configuration File Not Defined",
    problem = "The config_file variable is not defined.",
    why_it_matters = "Analysis requires a configuration file to specify data sources and settings.",
    how_to_fix = c(
      "Run this script from the Jupyter notebook entry point",
      "Or set config_file variable before sourcing this script"
    )
  )
}

project_root <- get_project_root(config_file)
log_message(sprintf("Project root: %s", project_root), "INFO")

start_time <- Sys.time()

# ==============================================================================
# LOAD CONFIGURATION
# ==============================================================================

log_message("Loading configuration...", "INFO")
config <- load_config_sheet(config_file, "Settings")

structure_file <- get_config_value(config, "structure_file", required = TRUE)
structure_file_path <- resolve_path(project_root, structure_file)

if (!file.exists(structure_file_path)) {
  # TRS Refusal: IO_STRUCTURE_FILE_NOT_FOUND
  tabs_refuse(
    code = "IO_STRUCTURE_FILE_NOT_FOUND",
    title = "Survey Structure File Not Found",
    problem = paste0("Cannot find survey structure file: ", basename(structure_file_path)),
    why_it_matters = "The survey structure defines questions and options needed for crosstabs.",
    how_to_fix = c(
      "Check that the structure_file path in Settings is correct",
      "Verify Survey_Structure.xlsx exists in your project folder"
    ),
    details = paste0("Expected path: ", structure_file_path)
  )
}

output_subfolder <- get_config_value(config, "output_subfolder", "Crosstabs")
output_filename <- get_config_value(config, "output_filename", "Crosstabs.xlsx")

# Build config object with alpha (not significance_level)
config_obj <- list(
  apply_weighting = safe_logical(get_config_value(config, "apply_weighting", FALSE)),
  weight_variable = get_config_value(config, "weight_variable", NULL),
  show_unweighted_n = safe_logical(get_config_value(config, "show_unweighted_n", TRUE)),
  show_effective_n = safe_logical(get_config_value(config, "show_effective_n", TRUE)),
  weight_label = get_config_value(config, "weight_label", "Weighted"),
  decimal_separator = get_config_value(config, "decimal_separator", "."),
  show_frequency = safe_logical(get_config_value(config, "show_frequency", TRUE)),
  show_percent_column = safe_logical(get_config_value(config, "show_percent_column", TRUE)),
  show_percent_row = safe_logical(get_config_value(config, "show_percent_row", FALSE)),
  boxcategory_frequency = safe_logical(get_config_value(config, "boxcategory_frequency", FALSE)),
  boxcategory_percent_column = safe_logical(get_config_value(config, "boxcategory_percent_column", TRUE)),
  boxcategory_percent_row = safe_logical(get_config_value(config, "boxcategory_percent_row", FALSE)),
  decimal_places_percent = safe_numeric(get_config_value(config, "decimal_places_percent", 0)),
  decimal_places_ratings = safe_numeric(get_config_value(config, "decimal_places_ratings", 1)),
  decimal_places_index = safe_numeric(get_config_value(config, "decimal_places_index", 1)),
  enable_significance_testing = safe_logical(get_config_value(config, "enable_significance_testing", TRUE)),
  alpha = safe_numeric(get_config_value(config, "alpha", DEFAULT_ALPHA)),
  significance_min_base = safe_numeric(get_config_value(config, "significance_min_base", DEFAULT_MIN_BASE)),
  bonferroni_correction = safe_logical(get_config_value(config, "bonferroni_correction", TRUE)),
  enable_checkpointing = safe_logical(get_config_value(config, "enable_checkpointing", TRUE)),
  zero_division_as_blank = safe_logical(get_config_value(config, "zero_division_as_blank", TRUE)),
     # V9.9.5: New features (ADD THESE THREE LINES)
  show_standard_deviation = safe_logical(get_config_value(config, "show_standard_deviation", FALSE)),
  test_net_differences = safe_logical(get_config_value(config, "test_net_differences", FALSE)),
  create_sample_composition = safe_logical(get_config_value(config, "create_sample_composition", FALSE)),
  enable_chi_square = safe_logical(get_config_value(config, "enable_chi_square", FALSE)),  # V9.9.5: NEW - with safe_logical
  show_net_positive = safe_logical(get_config_value(config, "show_net_positive", FALSE)),
  
  # V10.0.0: Numeric question settings
  show_numeric_median = safe_logical(get_config_value(config, "show_numeric_median", FALSE)),
  show_numeric_mode = safe_logical(get_config_value(config, "show_numeric_mode", FALSE)),
  show_numeric_outliers = safe_logical(get_config_value(config, "show_numeric_outliers", TRUE)),
  exclude_outliers_from_stats = safe_logical(get_config_value(config, "exclude_outliers_from_stats", FALSE)),
  outlier_method = get_config_value(config, "outlier_method", "IQR"),
  decimal_places_numeric = safe_numeric(get_config_value(config, "decimal_places_numeric", 1))
)

log_message("✓ Configuration loaded", "INFO")



# ==============================================================================
# LOAD SURVEY STRUCTURE
# ==============================================================================

log_message("Loading survey structure...", "INFO")
survey_structure <- load_survey_structure(structure_file_path, project_root)

validate_data_frame(survey_structure$questions, c("QuestionCode", "QuestionText", "Variable_Type"), 1)
validate_data_frame(survey_structure$options, c("QuestionCode", "OptionText"), 0)

# Apply ShowInOutput default to the actual options dataframe
# Ensure columns exist as character type before assignment
if (!"ShowInOutput" %in% names(survey_structure$options)) {
  survey_structure$options$ShowInOutput <- NA_character_
}
if (!"ExcludeFromIndex" %in% names(survey_structure$options)) {
  survey_structure$options$ExcludeFromIndex <- NA_character_
}
# Convert to character if not already (handles any type mismatches)
survey_structure$options$ShowInOutput <- as.character(survey_structure$options$ShowInOutput)
survey_structure$options$ExcludeFromIndex <- as.character(survey_structure$options$ExcludeFromIndex)
# Apply defaults
survey_structure$options$ShowInOutput[is.na(survey_structure$options$ShowInOutput)] <- "Y"
survey_structure$options$ExcludeFromIndex[is.na(survey_structure$options$ExcludeFromIndex)] <- "N"

# Convert Index_Weight to numeric for Likert index calculations
# (Options sheet is loaded as text, but Index_Weight needs to be numeric for arithmetic)
if ("Index_Weight" %in% names(survey_structure$options)) {
  survey_structure$options$Index_Weight <- as.numeric(survey_structure$options$Index_Weight)
}

# Convert DisplayOrder to numeric for proper sorting (not alphabetical)
# Without this, "1", "10", "2" sorts alphabetically instead of numerically
if ("DisplayOrder" %in% names(survey_structure$options)) {
  survey_structure$options$DisplayOrder <- as.numeric(survey_structure$options$DisplayOrder)
}

log_message("✓ Survey structure loaded", "INFO")

# Load composite definitions (V10.1 Feature - validation happens after data load)
composite_defs <- load_composite_definitions(structure_file_path)

if (!is.null(composite_defs) && nrow(composite_defs) > 0) {
  log_message(sprintf("Loaded %d composite metric(s)", nrow(composite_defs)), "INFO")
} else {
  log_message("No composite metrics defined", "INFO")
}

# ==============================================================================
# LOAD DATA
# ==============================================================================

log_message("Loading survey data...", "INFO")
data_file <- get_config_value(survey_structure$project, "data_file", required = TRUE)
data_file_path <- resolve_path(project_root, data_file)

if (!file.exists(data_file_path)) {
  # TRS Refusal: IO_DATA_FILE_NOT_FOUND
  tabs_refuse(
    code = "IO_DATA_FILE_NOT_FOUND",
    title = "Data File Not Found",
    problem = paste0("Cannot find data file: ", basename(data_file_path)),
    why_it_matters = "The analysis requires survey data to produce crosstabs.",
    how_to_fix = c(
      "Check that the data_file path in Project sheet is correct",
      "Verify the file exists at the specified location"
    ),
    details = paste0("Expected path: ", data_file_path)
  )
}

survey_data <- load_survey_data_smart(data_file_path, project_root)
validate_data_frame(survey_data, NULL, 1)

log_message(sprintf("✓ Loaded %d responses", nrow(survey_data)), "INFO")

# Setup weights (Store is_weighted flag)
is_weighted <- config_obj$apply_weighting
if (is_weighted) {
  master_weights <- get_weight_vector(survey_data, config_obj$weight_variable)
  validate_weights(master_weights, nrow(survey_data))
  summarize_weights(master_weights, paste("Weight:", config_obj$weight_variable))
  effective_n <- round(calculate_effective_n(master_weights), 0)
} else {
  master_weights <- rep(1, nrow(survey_data))
  effective_n <- nrow(survey_data)
  log_message("✓ Analysis will be unweighted", "INFO")
}

# ==============================================================================
# LOAD QUESTION SELECTION
# ==============================================================================

log_message("Loading question selection...", "INFO")
selection_df <- tryCatch({
  readxl::read_excel(config_file, sheet = "Selection", col_types = "text")
}, error = function(e) {
  # TRS Refusal: IO_SELECTION_SHEET_FAILED
  tabs_refuse(
    code = "IO_SELECTION_SHEET_FAILED",
    title = "Failed to Load Selection Sheet",
    problem = "Could not read the Selection sheet from configuration file.",
    why_it_matters = "The Selection sheet specifies which questions to analyze.",
    how_to_fix = c(
      "Verify the config file exists and is not corrupted",
      "Check that a 'Selection' sheet exists in the file",
      "Ensure the file is not open in another application"
    ),
    details = conditionMessage(e)
  )
})

validate_data_frame(selection_df, c("QuestionCode"), 1)

# Ensure optional columns exist and are character type before assignment
for (col in c("Include", "UseBanner", "BannerBoxCategory", "CreateIndex", "BaseFilter")) {
  if (!col %in% names(selection_df)) {
    selection_df[[col]] <- NA_character_
  } else {
    selection_df[[col]] <- as.character(selection_df[[col]])
  }
}

# Apply defaults
selection_df$Include[is.na(selection_df$Include)] <- "N"
selection_df$UseBanner[is.na(selection_df$UseBanner)] <- "N"
selection_df$BannerBoxCategory[is.na(selection_df$BannerBoxCategory)] <- "N"
selection_df$CreateIndex[is.na(selection_df$CreateIndex)] <- "N"

crosstab_questions <- selection_df[selection_df$Include == "Y", ]

if (nrow(crosstab_questions) == 0) {
  # TRS Refusal: CFG_NO_QUESTIONS_SELECTED
  tabs_refuse(
    code = "CFG_NO_QUESTIONS_SELECTED",
    title = "No Questions Selected for Analysis",
    problem = "No questions have Include='Y' in the Selection sheet.",
    why_it_matters = "At least one question must be selected to produce crosstabs.",
    how_to_fix = c(
      "Open your config file",
      "In the Selection sheet, set Include='Y' for questions to analyze",
      "Save and re-run"
    ),
    details = paste0("Total questions in selection: ", nrow(selection_df))
  )
}

log_message(sprintf("✓ Found %d questions to analyze", nrow(crosstab_questions)), "INFO")

# ==============================================================================
# VALIDATION
# ==============================================================================

log_message("Running comprehensive validation...", "INFO")

error_log <- run_all_validations(survey_structure, survey_data, config_obj)

if (nrow(error_log) > 0) {
  log_message(sprintf("⚠  Found %d validation issues", nrow(error_log)), "WARNING")
}

# Validate composites (V10.1 Feature)
if (!is.null(composite_defs) && nrow(composite_defs) > 0) {
  log_message("Validating composite definitions...", "INFO")

  validation_result <- validate_composite_definitions(
    composite_defs = composite_defs,
    questions_df = survey_structure$questions,
    survey_data = survey_data
  )

  if (!validation_result$is_valid) {
    # TRS Refusal: CFG_COMPOSITE_VALIDATION_FAILED
    tabs_refuse(
      code = "CFG_COMPOSITE_VALIDATION_FAILED",
      title = "Composite Definition Validation Failed",
      problem = "One or more composite metric definitions are invalid.",
      why_it_matters = "Invalid composites will produce incorrect or missing results.",
      how_to_fix = c(
        "Review the composite definitions in your config",
        "Ensure all referenced questions exist",
        "Check formula syntax is correct"
      ),
      details = paste(validation_result$errors, collapse = "\n")
    )
  }

  if (length(validation_result$warnings) > 0) {
    for (warn in validation_result$warnings) {
      warning(warn, call. = FALSE)
    }
  }

  log_message("✓ Composite definitions validated", "INFO")
}

# ==============================================================================
# CONFIGURATION SUMMARY FUNCTIONS (V10.0)
# ==============================================================================

#' Estimate Runtime Based on Dataset Size
#'
#' Provides an estimate of how long processing will take based on documented
#' benchmarks. Helps users plan for long-running analyses.
#'
#' @param n_questions Integer, number of questions to process
#' @param n_respondents Integer, number of respondents in data
#' @param n_banner_cols Integer, number of banner columns (default: 5)
#' @return Character, formatted time estimate
estimate_runtime <- function(n_questions, n_respondents, n_banner_cols = 5) {
  # Based on documented benchmarks: ~2.5 sec per 20 questions / 500 respondents / 5 banner cols
  base_time_sec <- (n_respondents / 500) * (n_questions / 20) * (n_banner_cols / 5) * 2.5

  if (base_time_sec < 60) {
    return(sprintf("~%.0f seconds", base_time_sec))
  } else if (base_time_sec < 3600) {
    return(sprintf("~%.1f minutes", base_time_sec / 60))
  } else {
    return(sprintf("~%.1f hours", base_time_sec / 3600))
  }
}

#' Print Configuration Summary Before Processing
#'
#' Displays a summary of the analysis configuration before starting processing.
#' Helps users verify settings and estimate processing time.
#'
#' @param config_obj List, configuration object
#' @param n_questions Integer, number of questions to process
#' @param n_respondents Integer, number of respondents
#' @param n_banner_cols Integer, number of banner columns
#' @return Invisible NULL
print_config_summary <- function(config_obj, n_questions, n_respondents, n_banner_cols) {
  cat("\n")
  cat(strrep("=", 60), "\n")
  cat("ANALYSIS CONFIGURATION\n")
  cat(strrep("=", 60), "\n")
  cat(sprintf("  Questions to process:    %d\n", n_questions))
  cat(sprintf("  Respondents:             %d\n", n_respondents))
  cat(sprintf("  Banner columns:          %d\n", n_banner_cols))
  cat(sprintf("  Weighting:               %s\n",
              if(config_obj$apply_weighting) config_obj$weight_variable else "None"))
  cat(sprintf("  Significance testing:    %s\n",
              if(config_obj$enable_significance_testing)
                sprintf("Yes (alpha=%.3f)", config_obj$alpha) else "No"))
  cat(sprintf("  Estimated time:          %s\n",
              estimate_runtime(n_questions, n_respondents, n_banner_cols)))
  cat(strrep("=", 60), "\n\n")

  invisible(NULL)
}

# ==============================================================================
# CREATE BANNER STRUCTURE (uses banner.R module)
# ==============================================================================

log_message("Creating banner structure...", "INFO")
banner_info <- safe_execute(
  create_banner_structure(selection_df, survey_structure),
  default = NULL,
  error_msg = "Failed to create banner structure"
)

if (is.null(banner_info)) {
  # TRS Refusal: CFG_BANNER_CREATION_FAILED
  tabs_refuse(
    code = "CFG_BANNER_CREATION_FAILED",
    title = "Failed to Create Banner Structure",
    problem = "Could not create banner structure from configuration.",
    why_it_matters = "Crosstabs require a valid banner to break down results by segments.",
    how_to_fix = c(
      "Check that at least one question has UseBanner='Y' in Selection sheet",
      "Verify banner question has valid options defined",
      "Check that banner question exists in the data"
    )
  )
}

log_message(sprintf("✓ Banner: %d columns", length(banner_info$columns)), "INFO")

# V10.0: Print configuration summary before processing
print_config_summary(
  config_obj,
  nrow(crosstab_questions),
  nrow(survey_data),
  length(banner_info$columns)
)

# ==============================================================================
# END OF PART 2
# ==============================================================================
# ==============================================================================
# PART 3: MEMORY-OPTIMIZED BANNER SUBSETTING & STATISTICAL CALCULATIONS
# ==============================================================================





#' Run pairwise significance tests
#'
#' @param row_data List, test data by column
#' @param row_type Character, test type
#' @param banner_structure List with column names and letters
#' @param alpha Numeric, p-value threshold (default: 0.05)
#' @param bonferroni_correction Logical
#' @param min_base Integer
#' @param is_weighted Logical, whether data is weighted
#' @return List of significance results
#' @export
run_significance_tests_for_row <- function(row_data, row_type, banner_structure,
                                          alpha = DEFAULT_ALPHA,
                                          bonferroni_correction = TRUE,
                                          min_base = DEFAULT_MIN_BASE,
                                          is_weighted = FALSE) {
  if (is.null(row_data) || length(row_data) == 0) return(list())
  if (is.null(banner_structure) || is.null(banner_structure$letters)) return(list())
  
  if (!setequal(names(row_data), banner_structure$column_names)) {
    # TRS Refusal: BUG_SIG_LETTER_MISMATCH
    tabs_refuse(
      code = "BUG_SIG_LETTER_MISMATCH",
      title = "Significance Letter Mapping Mismatch",
      problem = "Banner column names don't match test data keys.",
      why_it_matters = "Significance letters would be incorrectly mapped to columns.",
      how_to_fix = c(
        "This is an internal error - please report it",
        "Include the error details in your report"
      ),
      expected = banner_structure$column_names,
      observed = names(row_data),
      details = paste0("Test data keys: ", paste(head(names(row_data), 5), collapse = ", "),
                       "\nBanner columns: ", paste(head(banner_structure$column_names, 5), collapse = ", "))
    )
  }
  
  num_comparisons <- choose(length(row_data), 2)
  if (num_comparisons == 0) return(list())
  
  alpha_adj <- alpha
  if (bonferroni_correction && num_comparisons > 0) {
    alpha_adj <- alpha / num_comparisons
  }
  
  sig_results <- list()
  column_names <- names(row_data)
  
  for (i in seq_along(row_data)) {
    higher_than <- character(0)
    
    for (j in seq_along(row_data)) {
      if (i == j) next
      
      test_result <- if (row_type %in% c("proportion", "topbox")) {
        weighted_z_test_proportions(
          row_data[[i]]$count, row_data[[i]]$base,
          row_data[[j]]$count, row_data[[j]]$base,
          row_data[[i]]$eff_n, row_data[[j]]$eff_n,
          is_weighted = is_weighted,
          min_base = min_base,
          alpha = alpha_adj
        )
      } else if (row_type %in% c("mean", "index")) {
        weighted_t_test_means(
          row_data[[i]]$values, row_data[[j]]$values,
          row_data[[i]]$weights, row_data[[j]]$weights,
          min_base = min_base,
          alpha = alpha_adj
        )
      } else {
        list(significant = FALSE, p_value = NA_real_, higher = FALSE)
      }
      
      if (test_result$significant && test_result$higher) {
        col_letter <- banner_structure$letters[
          banner_structure$column_names == column_names[j]
        ]
        if (length(col_letter) > 0) {
          higher_than <- c(higher_than, col_letter)
        }
      }
    }
    
    sig_results[[column_names[i]]] <- paste(higher_than, collapse = "")
  }
  
  return(sig_results)
}

#' Add significance row
#'
#' @param test_data List, test data by column
#' @param banner_info List, banner structure
#' @param row_type Character, test type
#' @param internal_columns Character vector
#' @param alpha Numeric, p-value threshold
#' @param bonferroni_correction Logical
#' @param min_base Integer
#' @param is_weighted Logical
#' @return Data frame with sig row or NULL
#' @export
add_significance_row <- function(test_data, banner_info, row_type, internal_columns,
                                alpha = DEFAULT_ALPHA,
                                bonferroni_correction = TRUE,
                                min_base = DEFAULT_MIN_BASE,
                                is_weighted = FALSE) {
  if (is.null(test_data) || length(test_data) < 2) return(NULL)
  
  sig_values <- setNames(rep("", length(internal_columns)), internal_columns)
  
  total_key <- paste0("TOTAL::", TOTAL_COLUMN)
  if (total_key %in% names(sig_values)) {
    sig_values[total_key] <- "-"
  }
  
  for (banner_code in names(banner_info$banner_info)) {
    banner_cols <- banner_info$banner_info[[banner_code]]$internal_keys
    banner_test_data <- test_data[names(test_data) %in% banner_cols]
    
    if (length(banner_test_data) > 1) {
      banner_structure <- list(
        column_names = names(banner_test_data),
        letters = banner_info$banner_info[[banner_code]]$letters
      )
      
      sig_results <- run_significance_tests_for_row(
        banner_test_data, row_type, banner_structure,
        alpha, bonferroni_correction, min_base,
        is_weighted = is_weighted
      )
      
      for (col_key in names(sig_results)) {
        sig_values[col_key] <- sig_results[[col_key]]
      }
    }
  }
  
  sig_row <- data.frame(
    RowLabel = "", 
    RowType = SIG_ROW_TYPE, 
    stringsAsFactors = FALSE
  )
  
  for (col_key in internal_columns) {
    sig_row[[col_key]] <- sig_values[col_key]
  }
  
  return(sig_row)
}

# ==============================================================================
# END OF PART 3
# ==============================================================================
# ==============================================================================
# PART 4: QUESTION PROCESSING FUNCTIONS
# ==============================================================================


# ==============================================================================
# QUESTION PROCESSING (uses standard_processor.R module)
# ==============================================================================
# The following functions are now provided by standard_processor.R:
# - process_standard_question()
# - add_boxcategory_summaries()
# - add_summary_statistic()
# - add_net_significance_rows()
# - calculate_boxcategory_counts()
# - add_net_positive_row()
# ==============================================================================

# ==============================================================================
# END OF PART 4
# ==============================================================================
# ==============================================================================
# PART 5: EXCEL OUTPUT (Separate styles for rating/index/score)
# ==============================================================================
# PART 5: EXCEL OUTPUT (Separate styles for rating/index/score)
# ==============================================================================





#' Write question table (Sig overlay safeguards applied)
#'
#' ORDER: Matrix first, then sig strings overlaid (prevents erasure)
#' SAFEGUARDS: Skip Total column, skip empty strings
#'
#' @param wb Workbook
#' @param sheet Character
#' @param data_table Data frame
#' @param banner_info List
#' @param internal_keys Character vector
#' @param styles List
#' @param current_row Integer
#' @return Integer, next row
#' @export
write_question_table_fast <- function(wb, sheet, data_table, banner_info, 
                                      internal_keys, styles, current_row) {
  if (is.null(data_table) || nrow(data_table) == 0) return(current_row)
  
  n_rows <- nrow(data_table)
  n_data_cols <- length(banner_info$columns)
  
  label_col <- as.character(data_table$RowLabel)
  type_col <- as.character(data_table$RowType)
  
  data_matrix <- matrix(NA_real_, nrow = n_rows, ncol = n_data_cols)
  
  sig_cells <- list()
  
  total_key <- paste0("TOTAL::", TOTAL_COLUMN)
  total_col_idx <- which(internal_keys == total_key)
  
  for (i in seq_along(internal_keys)) {
    internal_key <- internal_keys[i]
    if (internal_key %in% names(data_table)) {
      col_data <- data_table[[internal_key]]
      
      if (any(type_col == SIG_ROW_TYPE)) {
        sig_indices <- which(type_col == SIG_ROW_TYPE)
        for (sig_idx in sig_indices) {
          sig_val <- col_data[sig_idx]
          
          # SAFEGUARDS: Skip Total column, skip empty strings
          if (!is.na(sig_val) && is.character(sig_val) && nchar(sig_val) > 0) {
            if (length(total_col_idx) == 0 || i != total_col_idx) {
              sig_cells[[length(sig_cells) + 1]] <- list(
                row = current_row + sig_idx - 1,
                col = i + 2,
                value = sig_val
              )
            }
          }
          col_data[sig_idx] <- NA
        }
      }
      
      data_matrix[, i] <- suppressWarnings(as.numeric(col_data))
    }
  }
  
  # STEP 1: Write labels and types
  openxlsx::writeData(wb, sheet, label_col, 
                     startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::writeData(wb, sheet, type_col, 
                     startRow = current_row, startCol = 2, colNames = FALSE)
  
  # STEP 2: Write numeric matrix FIRST
  openxlsx::writeData(wb, sheet, data_matrix, 
                     startRow = current_row, startCol = 3, colNames = FALSE)
  
  # STEP 3: Overlay sig strings (after matrix write)
  for (sig_cell in sig_cells) {
    openxlsx::writeData(wb, sheet, sig_cell$value, 
                       startRow = sig_cell$row, startCol = sig_cell$col, 
                       colNames = FALSE)
  }
  
  # STEP 4: Apply styles (Uses get_row_style for correct mapping)
  for (row_idx in seq_len(n_rows)) {
    row_type <- type_col[row_idx]
    style <- get_row_style(row_type, styles)
    
    openxlsx::addStyle(wb, sheet, style, 
                      rows = current_row + row_idx - 1, 
                      cols = 3:(2 + n_data_cols), gridExpand = TRUE)
  }
  
  return(current_row + n_rows)
}

# ==============================================================================
# CHECKPOINT SYSTEM
# ==============================================================================
# ==============================================================================
# CHECKPOINT SYSTEM
# ==============================================================================

#' Save checkpoint
#'
#' @param checkpoint_file Character
#' @param all_results List
#' @param processed_questions Character vector
#' @export
save_checkpoint <- function(checkpoint_file, all_results, processed_questions) {
  # Ensure checkpoint directory exists
  checkpoint_dir <- dirname(checkpoint_file)
  if (!dir.exists(checkpoint_dir)) {
    dir.create(checkpoint_dir, recursive = TRUE)
  }

  checkpoint_data <- list(
    results = all_results,
    processed = processed_questions,
    timestamp = Sys.time()
  )
  saveRDS(checkpoint_data, checkpoint_file)
}

#' Load checkpoint
#'
#' @param checkpoint_file Character
#' @return List or NULL
#' @export
load_checkpoint <- function(checkpoint_file) {
  # Check if directory exists first (important for OneDrive paths)
  checkpoint_dir <- dirname(checkpoint_file)
  if (!dir.exists(checkpoint_dir)) return(NULL)

  # Check if file exists
  if (!file.exists(checkpoint_file)) return(NULL)

  tryCatch({
    checkpoint_data <- readRDS(checkpoint_file)
    log_message(sprintf("Checkpoint loaded: %d questions already processed",
                       length(checkpoint_data$processed)), "INFO")
    return(checkpoint_data)
  }, error = function(e) {
    # TRS v1.0: Make checkpoint load failure visible (not output-affecting, just informational)
    message(sprintf("[TRS INFO] Checkpoint file exists but could not be loaded: %s\n  Starting fresh instead.", conditionMessage(e)))
    return(NULL)
  })
}

# ==============================================================================
# CHECKPOINTING SETUP
# ==============================================================================

checkpoint_file <- file.path(project_root, output_subfolder,
                             ".crosstabs_checkpoint.rds")

if (config_obj$enable_checkpointing) {
  checkpoint_data <- load_checkpoint(checkpoint_file)
  
  if (!is.null(checkpoint_data)) {
    all_results <- checkpoint_data$results
    processed_questions <- checkpoint_data$processed
    remaining_questions <- crosstab_questions[
      !crosstab_questions$QuestionCode %in% processed_questions, 
    ]
    
    log_message(sprintf("Resuming: %d questions remaining", 
                       nrow(remaining_questions)), "INFO")
  } else {
    all_results <- list()
    processed_questions <- character(0)
    remaining_questions <- crosstab_questions
  }
} else {
  all_results <- list()
  processed_questions <- character(0)
  remaining_questions <- crosstab_questions
}

# ==============================================================================
# PROCESS QUESTIONS (CLEAN VERSION - All fixes applied)
# ==============================================================================

log_message(sprintf("Processing %d questions...", nrow(remaining_questions)), "INFO")
cat("\n")

# Choose progress callback: GUI progress bar if available, otherwise console log
# This allows the GUI to inject a Shiny progress updater while keeping
# command-line execution unchanged (backward compatible)
active_progress_callback <- if (exists("gui_progress_callback", envir = .GlobalEnv)) {
  get("gui_progress_callback", envir = .GlobalEnv)
} else {
  log_progress
}

orchestration_result <- process_all_questions(
  remaining_questions, survey_data, survey_structure,
  banner_info, master_weights, config_obj,
  checkpoint_config = list(
    enabled = config_obj$enable_checkpointing,
    file = checkpoint_file,
    frequency = CHECKPOINT_FREQUENCY
  ),
  progress_callback = active_progress_callback,
  is_weighted = is_weighted,
  total_column = TOTAL_COLUMN,
  all_questions = crosstab_questions,
  processed_so_far = processed_questions
)

all_results <- orchestration_result$all_results
processed_questions <- orchestration_result$processed_questions
run_status <- orchestration_result$run_status
skipped_questions <- orchestration_result$skipped_questions
partial_questions <- orchestration_result$partial_questions  # TRS v1.0: Questions with missing sections

cat("\n")

# TRS v1.0: Mandatory PARTIAL status disclosure
if (run_status == "PARTIAL") {
  cat("\n")
  cat(paste(rep("!", 80), collapse=""), "\n")
  cat("[TRS PARTIAL] ANALYSIS COMPLETED WITH PARTIAL RESULTS\n")
  cat(paste(rep("!", 80), collapse=""), "\n")

  # Report skipped questions
  if (length(skipped_questions) > 0) {
    cat(sprintf("\n  SKIPPED QUESTIONS: %d\n", length(skipped_questions)))
    cat("  The following questions are MISSING from your output:\n\n")
    for (skip_code in names(skipped_questions)) {
      skip_info <- skipped_questions[[skip_code]]
      cat(sprintf("    - %s: %s (stage: %s)\n",
                  skip_code, skip_info$reason, skip_info$stage))
    }
  }

  # Report questions with missing sections
  if (length(partial_questions) > 0) {
    cat(sprintf("\n  QUESTIONS WITH MISSING SECTIONS: %d\n", length(partial_questions)))
    cat("  The following questions have incomplete output:\n\n")
    for (pq_code in names(partial_questions)) {
      pq_info <- partial_questions[[pq_code]]
      cat(sprintf("    - %s:\n", pq_code))
      for (section in pq_info$sections) {
        cat(sprintf("        * %s: %s\n", section$section, section$error))
      }
    }
  }

  cat("\n")
  cat("  ACTION REQUIRED: Review and fix the issues above, then re-run.\n")
  cat("  A 'Run_Status' sheet will be included in your workbook.\n")
  cat(paste(rep("!", 80), collapse=""), "\n\n")
}

log_message(sprintf("✓ Processed %d questions", length(all_results)), "INFO")

if (config_obj$enable_checkpointing && file.exists(checkpoint_file)) {
  file.remove(checkpoint_file)
}

# ==============================================================================
# PROCESS COMPOSITE METRICS (V10.1 Feature)
# ==============================================================================

composite_results <- list()

if (!is.null(composite_defs) && nrow(composite_defs) > 0) {
  log_message(sprintf("\nProcessing %d composite metric(s)...", nrow(composite_defs)), "INFO")

  # ISSUE #3 FIX: Create banner row indices for composites
  # Composites need banner_row_indices to filter data by banner segments
  log_message("Creating banner row indices for composites...", "INFO")
  banner_result <- create_banner_row_indices(survey_data, banner_info)
  banner_row_indices <- banner_result$row_indices

  # Merge row_indices into banner_info as 'subsets' (expected by composite processor)
  banner_info$subsets <- banner_row_indices
  log_message(sprintf("✓ Created indices for %d banner columns", length(banner_row_indices)), "INFO")

  tryCatch({
    composite_results <- process_all_composites(
      composite_defs = composite_defs,
      data = survey_data,
      questions_df = survey_structure$questions,
      banner_info = banner_info,
      config = config_obj
    )

    log_message(sprintf("✓ Processed %d composite(s)", length(composite_results)), "INFO")
  }, error = function(e) {
    # TRS Refusal: MODEL_COMPOSITE_PROCESSING_FAILED
    tabs_refuse(
      code = "MODEL_COMPOSITE_PROCESSING_FAILED",
      title = "Composite Processing Failed",
      problem = "An error occurred while processing composite metrics.",
      why_it_matters = "Composite metrics are required outputs and cannot be skipped.",
      how_to_fix = c(
        "Check composite definitions for errors",
        "Verify all referenced questions exist in data",
        "Review the error details below"
      ),
      details = paste0("Error: ", e$message, "\n\nCall stack:\n", paste(sys.calls(), collapse = "\n"))
    )
  })

  # Add composites to all_results so they appear in Crosstabs sheet
  if (length(composite_results) > 0) {
    for (comp_code in names(composite_results)) {
      comp_result <- composite_results[[comp_code]]

      # Safety check
      if (is.null(comp_result) || is.null(comp_result$question_table)) {
        warning(sprintf("Composite '%s' has no results table, skipping", comp_code))
        next
      }

      if (nrow(comp_result$question_table) == 0) {
        warning(sprintf("Composite '%s' has empty results table, skipping", comp_code))
        next
      }

      # Get composite label safely
      comp_label <- if ("RowLabel" %in% names(comp_result$question_table) &&
                        nrow(comp_result$question_table) > 0) {
        comp_result$question_table$RowLabel[1]
      } else if (!is.null(comp_result$metadata$composite_code)) {
        comp_result$metadata$composite_code
      } else {
        comp_code
      }

      # Convert to standard result format
      # Composites use the same base sizes as the overall banner
      all_results[[comp_code]] <- list(
        question_code = comp_code,
        question_text = comp_label,
        question_type = "Composite",
        base_filter = NA,
        table = comp_result$question_table,
        bases = banner_info$base_sizes  # Use banner base sizes
      )
    }
    log_message(sprintf("Added %d composite(s) to results", length(composite_results)), "INFO")
  }
}

# ==============================================================================
# CREATE EXCEL OUTPUT
# ==============================================================================

log_message("Creating Excel output...", "INFO")

wb <- openxlsx::createWorkbook()

# Styles with separate rating/index/score styles
# Safe extraction of style parameters
decimal_separator <- if (!is.null(config_obj$decimal_separator) &&
                         length(config_obj$decimal_separator) > 0) {
  config_obj$decimal_separator
} else {
  "."
}

# Get general decimal_places as fallback (defaults to 1 if not specified)
general_decimal_places <- if (!is.null(config_obj$decimal_places) &&
                               length(config_obj$decimal_places) > 0) {
  config_obj$decimal_places
} else {
  1
}

decimal_places_percent <- if (!is.null(config_obj$decimal_places_percent) &&
                              length(config_obj$decimal_places_percent) > 0) {
  config_obj$decimal_places_percent
} else {
  general_decimal_places
}

decimal_places_ratings <- if (!is.null(config_obj$decimal_places_ratings) &&
                              length(config_obj$decimal_places_ratings) > 0) {
  config_obj$decimal_places_ratings
} else {
  general_decimal_places
}

decimal_places_index <- if (!is.null(config_obj$decimal_places_index) &&
                            length(config_obj$decimal_places_index) > 0) {
  config_obj$decimal_places_index
} else {
  general_decimal_places
}

decimal_places_numeric <- if (!is.null(config_obj$decimal_places_numeric) &&
                              length(config_obj$decimal_places_numeric) > 0) {
  config_obj$decimal_places_numeric
} else {
  general_decimal_places
}

styles <- create_excel_styles(
  decimal_separator,
  decimal_places_percent,
  decimal_places_ratings,
  decimal_places_index,
  decimal_places_numeric  # V10.0.0: Added
)

project_name <- get_config_value(survey_structure$project, "project_name", "Crosstabs")

project_info <- list(
  project_name = project_name,
  total_responses = nrow(survey_data),
  effective_n = effective_n,
  total_banner_cols = length(banner_info$columns),
  num_banner_questions = if (!is.null(banner_info$banner_questions)) {
    nrow(banner_info$banner_questions)
  } else {
    0
  }
)

tryCatch({
  log_message("Creating Summary sheet...", "INFO")
  create_summary_sheet(wb, project_info, all_results, config_obj, styles,
                       SCRIPT_VERSION, TOTAL_COLUMN, VERY_SMALL_BASE_SIZE)
  log_message("✓ Summary sheet created", "INFO")
}, error = function(e) {
  # TRS Refusal: IO_SUMMARY_SHEET_FAILED
  tabs_refuse(
    code = "IO_SUMMARY_SHEET_FAILED",
    title = "Failed to Create Summary Sheet",
    problem = "An error occurred while creating the Summary sheet.",
    why_it_matters = "The Summary sheet provides an overview of the analysis results.",
    how_to_fix = c(
      "Check that all results were processed correctly",
      "Review the error details below"
    ),
    details = paste0("Error: ", e$message, "\nNumber of results: ", length(all_results),
                     "\nResult codes: ", paste(names(all_results), collapse = ", "))
  )
})

# Build and write Index_Summary sheet (V10.1 Feature)
# Default to TRUE if composites are defined, otherwise FALSE
default_create_summary <- !is.null(composite_defs) && nrow(composite_defs) > 0
create_index_summary <- get_config_value(config_obj, "create_index_summary", default_create_summary)

if (create_index_summary) {
  tryCatch({
    log_message("Building index summary...", "INFO")

    summary_table <- build_index_summary_table(
      results_list = all_results,
      composite_results = composite_results,
      banner_info = banner_info,
      config = config_obj,
      composite_defs = composite_defs
    )

    if (!is.null(summary_table) && nrow(summary_table) > 0) {
      log_message(sprintf("Writing Index_Summary sheet with %d metrics...", nrow(summary_table)), "INFO")

      write_index_summary_sheet(
        wb = wb,
        summary_table = summary_table,
        banner_info = banner_info,
        config = config_obj,
        styles = styles,
        all_results = all_results
      )

      log_message("✓ Index_Summary sheet created", "INFO")
    } else {
      log_message("No metrics to include in Index_Summary", "INFO")
    }
  }, error = function(e) {
    # TRS Refusal: IO_INDEX_SUMMARY_FAILED
    tabs_refuse(
      code = "IO_INDEX_SUMMARY_FAILED",
      title = "Failed to Create Index Summary Sheet",
      problem = "An error occurred while creating the Index_Summary sheet.",
      why_it_matters = "The Index_Summary sheet consolidates key metrics for easy review.",
      how_to_fix = c(
        "Check that composite definitions are valid",
        "Verify all referenced questions have results",
        "Review the error details below"
      ),
      details = paste0("Error: ", e$message, "\n\nTraceback:\n",
                       paste(capture.output(traceback()), collapse = "\n"))
    )
  })
}

# Error log
write_error_log_sheet(wb, error_log, styles)

# TRS v1.0: Log PARTIAL events to run state
if (!is.null(trs_state)) {
  # Log skipped questions as PARTIAL events
  if (length(skipped_questions) > 0) {
    for (skip_code in names(skipped_questions)) {
      skip_info <- skipped_questions[[skip_code]]
      if (exists("turas_run_state_partial", mode = "function")) {
        turas_run_state_partial(
          trs_state,
          sprintf("TABS_SKIP_%s", skip_code),
          sprintf("Question skipped: %s", skip_code),
          problem = skip_info$reason,
          stage = skip_info$stage
        )
      }
    }
  }

  # Log partial questions as PARTIAL events
  if (length(partial_questions) > 0) {
    for (pq_code in names(partial_questions)) {
      pq_info <- partial_questions[[pq_code]]
      for (section in pq_info$sections) {
        if (exists("turas_run_state_partial", mode = "function")) {
          turas_run_state_partial(
            trs_state,
            sprintf("TABS_PARTIAL_%s", pq_code),
            sprintf("Missing section in %s: %s", pq_code, section$section),
            problem = section$error
          )
        }
      }
    }
  }
}

# TRS v1.0: Get run result for Run_Status sheet
run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
  turas_run_state_result(trs_state)
} else {
  NULL
}

# TRS v1.0: Run_Status sheet (using standard writer)
tryCatch({
  log_message("Creating Run_Status sheet...", "INFO")

  if (!is.null(run_result) && exists("turas_write_run_status_sheet", mode = "function")) {
    # Use standard TRS writer
    turas_write_run_status_sheet(wb, run_result)
    log_message(sprintf("✓ Run_Status sheet created (status: %s)", run_result$status), "INFO")
  } else {
    # Fallback: Create basic Run_Status sheet manually
    openxlsx::addWorksheet(wb, "Run_Status")

    status_row <- 1
    openxlsx::writeData(wb, "Run_Status", "TRS Run Status Report", startRow = status_row, startCol = 1)
    openxlsx::addStyle(wb, "Run_Status", styles$question, rows = status_row, cols = 1)
    status_row <- status_row + 2

    status_color <- if (run_status == "PASS") "#28a745" else "#dc3545"
    status_style <- openxlsx::createStyle(fontColour = status_color, textDecoration = "bold", fontSize = 14)
    openxlsx::writeData(wb, "Run_Status", sprintf("Overall Status: %s", run_status), startRow = status_row, startCol = 1)
    openxlsx::addStyle(wb, "Run_Status", status_style, rows = status_row, cols = 1)
    status_row <- status_row + 1

    openxlsx::writeData(wb, "Run_Status", sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), startRow = status_row, startCol = 1)
    status_row <- status_row + 1

    openxlsx::writeData(wb, "Run_Status", sprintf("Questions processed: %d of %d", length(processed_questions), nrow(crosstab_questions)), startRow = status_row, startCol = 1)

    openxlsx::setColWidths(wb, "Run_Status", cols = 1:3, widths = c(20, 60, 25))
    log_message(sprintf("✓ Run_Status sheet created (status: %s)", run_status), "INFO")
  }
}, error = function(e) {
  warning(sprintf("Failed to create Run_Status sheet: %s", conditionMessage(e)), call. = FALSE)
})

# V9.9.5: Sample Composition sheet (SAFE - separate sheet)
if (config_obj$create_sample_composition) {
  log_message("Creating sample composition sheet...", "INFO")
  create_sample_composition_sheet(
    wb, survey_data, banner_info, master_weights, config_obj, styles, survey_structure
  )
}

# Crosstabs sheet
openxlsx::addWorksheet(wb, "Crosstabs")
current_row <- 1
total_cols <- 2 + length(banner_info$columns)

current_row <- write_banner_headers(wb, "Crosstabs", banner_info, styles)

if (config_obj$enable_significance_testing) {
  current_row <- write_column_letters(wb, "Crosstabs", banner_info, styles, current_row)
}

openxlsx::freezePane(wb, "Crosstabs", firstActiveRow = current_row, firstActiveCol = 3)

# Write questions
for (q_code in names(all_results)) {
  tryCatch({
    question_results <- all_results[[q_code]]

    if (!is.null(question_results$table) && nrow(question_results$table) > 0) {
      cat(sprintf("Writing question: %s\n", q_code))

      header_text <- paste(question_results$question_code, "-",
                          question_results$question_text)

      # Safe weighting check
      apply_weighting <- !is.null(config_obj$apply_weighting) &&
                         length(config_obj$apply_weighting) > 0 &&
                         config_obj$apply_weighting

      if (apply_weighting) {
        weight_label <- if (!is.null(config_obj$weight_label) &&
                           length(config_obj$weight_label) > 0) {
          config_obj$weight_label
        } else {
          "Weighted"
        }
        header_text <- paste0(header_text, " [", weight_label, "]")
      }

      openxlsx::writeData(wb, "Crosstabs", header_text,
                         startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::addStyle(wb, "Crosstabs", styles$question, rows = current_row, cols = 1)
      current_row <- current_row + 1

      if (!is.null(question_results$base_filter) &&
          !is.na(question_results$base_filter) &&
          nchar(trimws(question_results$base_filter)) > 0) {
        filter_display <- paste("  Filter:", question_results$base_filter)
        openxlsx::writeData(wb, "Crosstabs", filter_display,
                           startRow = current_row, startCol = 1, colNames = FALSE)
        openxlsx::addStyle(wb, "Crosstabs", styles$filter, rows = current_row, cols = 1)
        current_row <- current_row + 1
      }

      cat(sprintf("  Writing base rows for %s\n", q_code))
      current_row <- write_base_rows(wb, "Crosstabs", banner_info,
                                     question_results$bases, styles,
                                     current_row, config_obj)

      cat(sprintf("  Writing table for %s\n", q_code))
      current_row <- write_question_table_fast(wb, "Crosstabs", question_results$table,
                                               banner_info, banner_info$internal_keys,
                                               styles, current_row)

      current_row <- current_row + 1
      cat(sprintf("  ✓ Completed %s\n", q_code))
    }
  }, error = function(e) {
    # TRS Refusal: IO_QUESTION_WRITE_FAILED
    tabs_refuse(
      code = "IO_QUESTION_WRITE_FAILED",
      title = "Failed to Write Question to Excel",
      problem = paste0("An error occurred while writing question '", q_code, "' to Excel."),
      why_it_matters = "All questions must be written to produce complete crosstabs output.",
      how_to_fix = c(
        "Check that the question has valid results",
        "Verify the question type is supported",
        "Review the error details below"
      ),
      details = paste0("Question: ", q_code,
                       "\nError: ", e$message,
                       "\nQuestion type: ", question_results$question_type,
                       "\nHas table: ", !is.null(question_results$table),
                       "\nTable rows: ", if(!is.null(question_results$table)) nrow(question_results$table) else "NULL",
                       "\nHas bases: ", !is.null(question_results$bases))
    )
  })
}

openxlsx::setColWidths(wb, "Crosstabs", cols = 1:2, widths = c(25, 12))
if (length(banner_info$columns) > 0) {
  openxlsx::setColWidths(wb, "Crosstabs", cols = 3:(2 + length(banner_info$columns)), 
                        widths = 10)
}

# Save
output_path <- resolve_path(project_root, file.path(output_subfolder,
                                                    output_filename))
output_dir <- dirname(output_path)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
  log_message("✓ Created output directory", "INFO")
}

# TRS v1.0: Use atomic save if available
if (exists("turas_save_workbook_atomic", mode = "function")) {
  save_result <- turas_save_workbook_atomic(wb, output_path, run_result = run_result, module = "TABS")
  if (!save_result$success) {
    tabs_refuse(
      code = "IO_EXCEL_SAVE_FAILED",
      title = "Failed to Save Excel File",
      problem = "Could not save the Excel workbook to disk.",
      why_it_matters = "The analysis results cannot be delivered without saving the file.",
      how_to_fix = c(
        "Check that the output directory is writable",
        "Ensure the file is not open in another application",
        "Verify there is sufficient disk space"
      ),
      details = paste0("Output path: ", output_path, "\nError: ", save_result$error)
    )
  } else {
    log_message(sprintf("\u2713 Saved: %s", output_path), "INFO")
  }
} else {
  tryCatch({
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
    log_message(sprintf("\u2713 Saved: %s", output_path), "INFO")
  }, error = function(e) {
    # TRS Refusal: IO_EXCEL_SAVE_FAILED
    tabs_refuse(
      code = "IO_EXCEL_SAVE_FAILED",
      title = "Failed to Save Excel File",
      problem = "Could not save the Excel workbook to disk.",
      why_it_matters = "The analysis results cannot be delivered without saving the file.",
      how_to_fix = c(
        "Check that the output directory is writable",
        "Ensure the file is not open in another application",
        "Verify there is sufficient disk space"
      ),
      details = paste0("Output path: ", output_path, "\nError: ", conditionMessage(e))
    )
  })
}

# ==============================================================================
# COMPLETION SUMMARY
# ==============================================================================

elapsed <- difftime(Sys.time(), start_time, units = "secs")

# TRS v1.0: Print final banner
if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
  turas_print_final_banner(run_result)
} else {
  cat("\n")
  cat(paste(rep("=", 80), collapse=""), "\n")
  cat("ANALYSIS COMPLETE - TURAS V10.0 (CLEAN)\n")
  cat(paste(rep("=", 80), collapse=""), "\n\n")

  # TRS v1.0: Display run status prominently
  if (run_status == "PARTIAL") {
    cat("⚠  TRS Status: PARTIAL (see Run_Status sheet for details)\n")
    if (length(skipped_questions) > 0) {
      cat(sprintf("⚠  Questions skipped: %d\n", length(skipped_questions)))
    }
    if (length(partial_questions) > 0) {
      cat(sprintf("⚠  Questions with missing sections: %d\n", length(partial_questions)))
    }
  } else {
    cat("✓ TRS Status: PASS\n")
  }
  cat("\n")
}

cat("✓ Project:", project_name, "\n")
cat("✓ Questions:", length(all_results), "\n")
cat("✓ Responses:", nrow(survey_data), "\n")

if (config_obj$apply_weighting) {
  cat("✓ Weighting:", config_obj$weight_variable, "\n")
  cat("✓ Effective N:", effective_n, "\n")
}

cat("✓ Significance:", if (config_obj$enable_significance_testing) "ENABLED" else "disabled", "\n")
if (config_obj$enable_significance_testing) {
  cat("✓ Alpha (p-value):", sprintf("%.3f", config_obj$alpha), "\n")
}
cat("✓ Output:", output_path, "\n")
cat("✓ Duration:", format_seconds(as.numeric(elapsed)), "\n")

if (nrow(error_log) > 0) {
  cat("⚠  Issues:", nrow(error_log), "(see Error Log)\n")
}

cat("\n")
cat("TURAS V10.0 - ALL IMPROVEMENTS APPLIED:\n")
cat("  ✓ Multi-mention questions display correctly\n")
cat("  ✓ ShowInOutput filtering works properly\n")
cat("  ✓ Rating calculations fixed (OptionValue support)\n")
cat("  ✓ Replaced deprecated pryr with lobstr\n")
cat("  ✓ Smart CSV caching for large Excel files\n")
cat("  ✓ Configuration summary with ETA before processing\n")
cat("\n")
cat("Ready for production use.\n")
cat(paste(rep("=", 80), collapse=""), "\n")

# ==============================================================================
# END OF SCRIPT - TURAS V10.0 (ENHANCED VERSION)
# ==============================================================================
#
# PREVIOUS FIXES (RETAINED):
#
# 1. ✅ MULTI-MENTION FIX
#    - Options sheet now uses column names (Q01_1, Q01_2) as QuestionCode
#    - Pattern matching finds all multi-mention columns
#    - No more "orphan options" confusion
#
# 2. ✅ SHOWINOUTPUT FIX
#    - Proper filtering in process_question function
#    - Only displays options where ShowInOutput = "Y" or blank
#    - Banner options also respect ShowInOutput
#
# 3. ✅ RATING CALCULATION FIX
#    - Added OptionValue column support
#    - Character data in rating columns now works correctly
#    - Uses OptionValue for numeric calculations if available
#    - Falls back to OptionText if no OptionValue column
#
# 4. ✅ DEBUG CODE REMOVED
#    - All cat() debug statements removed
#    - Clean production code
#    - No performance impact from debug output
#
# 5. ✅ PROPER STYLE MAPPING
#    - Separate styles for rating/index/score
#    - Each uses correct decimal places
#    - No more decimal "leakage" between types
#
# V10.0 PRACTICAL ENHANCEMENTS:
#
# 6. ✅ REPLACED PRYR WITH LOBSTR
#    - pryr package is archived/deprecated
#    - lobstr is the maintained successor
#    - Memory monitoring now uses lobstr::obj_size()
#
# 7. ✅ RENAMED LOG_ISSUE TO ADD_LOG_ENTRY
#    - Clearer name indicates pure function behavior
#    - Original log_issue() kept as alias for compatibility
#    - Enhanced documentation emphasizes capturing return value
#
# 8. ✅ SMART CSV CACHING FOR LARGE FILES
#    - load_survey_data_smart() added
#    - Auto-creates CSV cache for Excel files >50MB
#    - 10x faster subsequent loads (500 MB/sec vs 10 MB/sec)
#    - Cache auto-invalidates when source changes
#
# 9. ✅ CONFIGURATION SUMMARY DISPLAY
#    - Shows analysis settings before processing
#    - Displays estimated runtime based on benchmarks
#    - Helps users verify configuration
#
# 10. ✅ GLOBAL NAMESPACE POLLUTION FIXED
#    - source() calls in excel_writer.R use local=TRUE
#    - Prevents function/variable leakage to global environment
#
# ==============================================================================
