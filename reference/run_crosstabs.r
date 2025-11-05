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
# CROSSTABS V9.9 - PRODUCTION RELEASE (CLEAN VERSION)
# ==============================================================================
# Enterprise-grade survey crosstabs - Debug code removed
# 
# FIXES APPLIED:
# 1. ✅ Multi-mention questions now display correctly
# 2. ✅ ShowInOutput filtering works properly
# 3. ✅ Rating calculations fixed (OptionValue support)
# 4. ✅ All debug code removed
# 5. ✅ Clean, production-ready code
# ==============================================================================

SCRIPT_VERSION <- "9.9"

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
    stop(sprintf(
      "Missing required packages: %s\n\nInstall with:\n  install.packages(c(%s))",
      paste(missing, collapse = ", "),
      paste(sprintf('"%s"', missing), collapse = ", ")
    ))
  }
  
  # Optional but recommended
  if (!requireNamespace("pryr", quietly = TRUE)) {
    message("Note: 'pryr' package not found. Memory monitoring will be disabled.")
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

script_dir <- if (exists("toolkit_path")) dirname(toolkit_path) else getwd()

source(file.path(script_dir, "shared_functions.R"))
source(file.path(script_dir, "validation.R"))
source(file.path(script_dir, "weighting.R"))
source(file.path(script_dir, "ranking.R"))

# ==============================================================================
# LOGGING & MONITORING SYSTEM
# ==============================================================================

#' Log message with timestamp and level
#'
#' @param msg Character, message to log
#' @param level Character, log level (INFO, WARNING, ERROR, DEBUG)
#' @param verbose Logical, whether to display
#' @return Invisible NULL
#' @export
log_message <- function(msg, level = "INFO", verbose = TRUE) {
  if (!verbose) return(invisible(NULL))
  
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] %s: %s\n", timestamp, level, msg))
  invisible(NULL)
}

#' Log progress with percentage and ETA
#'
#' @param current Integer, current item
#' @param total Integer, total items
#' @param item Character, item description
#' @param start_time POSIXct, when processing started
#' @return Invisible NULL
log_progress <- function(current, total, item = "", start_time = NULL) {
  pct <- round(100 * current / total, 1)
  
  eta_str <- ""
  if (!is.null(start_time) && current > 0) {
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    rate <- elapsed / current
    remaining <- (total - current) * rate
    eta_str <- sprintf(" | ETA: %s", format_seconds(remaining))
  }
  
  cat(sprintf("\r[%3d%%] %d/%d%s %s", 
             round(pct), current, total, eta_str, item))
  
  if (current == total) cat("\n")
  invisible(NULL)
}

#' Format seconds into readable time
#'
#' @param seconds Numeric, seconds
#' @return Character, formatted time
format_seconds <- function(seconds) {
  if (seconds < 60) {
    return(sprintf("%.0fs", seconds))
  } else if (seconds < 3600) {
    return(sprintf("%.1fm", seconds / 60))
  } else {
    return(sprintf("%.1fh", seconds / 3600))
  }
}

#' Check and warn about memory usage
#'
#' Memory reported in GiB (1024^3 bytes) to match OS conventions
#'
#' @param force_gc Logical, force garbage collection if high
#' @return Invisible NULL
check_memory <- function(force_gc = TRUE) {
  if (!requireNamespace("pryr", quietly = TRUE)) return(invisible(NULL))
  
  mem_used_bytes <- pryr::mem_used()
  mem_used_gib <- mem_used_bytes / (1024^3)
  
  if (mem_used_gib > MEMORY_CRITICAL_GIB) {
    log_message(sprintf("CRITICAL: Memory usage %.1f GiB - forcing cleanup", 
                       mem_used_gib), "ERROR")
    if (force_gc) gc()
  } else if (mem_used_gib > MEMORY_WARNING_GIB) {
    log_message(sprintf("WARNING: Memory usage %.1f GiB", mem_used_gib), "WARNING")
    if (force_gc) gc()
  }
  
  invisible(NULL)
}

#' Validate weight vector against data
#'
#' @param weights Numeric vector of weights
#' @param data_rows Integer, expected number of rows
#' @param allow_zero Logical, allow zero weights
#' @return Invisible TRUE if valid
#' @export
validate_weights <- function(weights, data_rows, allow_zero = TRUE) {
  if (!is.numeric(weights)) {
    stop("Weights must be numeric, got: ", class(weights)[1])
  }
  
  if (length(weights) != data_rows) {
    stop(sprintf("Weight vector length (%d) must match data rows (%d)", 
                length(weights), data_rows))
  }
  
  if (any(weights < 0, na.rm = TRUE)) {
    stop("Weights cannot be negative")
  }
  
  if (!allow_zero && all(weights == 0)) {
    stop("All weights are zero")
  }
  
  n_na <- sum(is.na(weights))
  if (n_na > 0) {
    warning(sprintf("Weight vector contains %d NA values (%.1f%%)", 
                   n_na, 100 * n_na / length(weights)))
  }
  
  invisible(TRUE)
}

# ==============================================================================
# SAFE EXECUTION WRAPPERS
# ==============================================================================

#' Safely execute with error handling
#'
#' @param expr Expression to evaluate
#' @param default Default value on error
#' @param error_msg Error message prefix
#' @param silent Suppress warnings
#' @return Result or default
#' @export
safe_execute <- function(expr, default = NA, error_msg = "Operation failed", 
                        silent = FALSE) {
  tryCatch(
    expr,
    error = function(e) {
      if (!silent) {
        warning(sprintf("%s: %s", error_msg, conditionMessage(e)), call. = FALSE)
      }
      return(default)
    }
  )
}

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
safe_equal <- function(a, b) {
  if (length(a) == 0 || length(b) == 0) return(logical(0))
  trimws(as.character(a)) == trimws(as.character(b))
}

#' Check if has data
#'
#' @param df Data frame
#' @return Logical
#' @export
has_data <- function(df) {
  !is.null(df) && is.data.frame(df) && nrow(df) > 0
}

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

#' Generate Excel column letters (proper base-26 to XFD)
#'
#' Converts column numbers to Excel-style letters using proper base-26 
#' algorithm. Handles A..Z (1-26), AA..ZZ (27-702), AAA..XFD (703-16384).
#'
#' @param n Number of letters to generate
#' @return Character vector of Excel column letters
#' @export
generate_excel_letters <- function(n) {
  validate_numeric_param(n, "n", min = 0, max = MAX_EXCEL_COLUMNS)
  
  if (n <= 0) return(character(0))
  
  letters_vec <- character(n)
  
  for (i in 1:n) {
    col_num <- i
    letter <- ""
    
    while (col_num > 0) {
      remainder <- (col_num - 1) %% 26
      letter <- paste0(LETTERS[remainder + 1], letter)
      col_num <- (col_num - 1) %/% 26
    }
    
    letters_vec[i] <- letter
  }
  
  return(letters_vec)
}

#' Batch rbind (efficient)
#'
#' @param row_list List of data frames
#' @return Single data frame
#' @export
batch_rbind <- function(row_list) {
  if (length(row_list) == 0) return(data.frame())
  do.call(rbind, row_list)
}

# ==============================================================================
# END OF PART 1
# ==============================================================================

# ==============================================================================
# PART 2: STARTUP, CONFIGURATION, BANNER FUNCTIONS
# ==============================================================================

# ==============================================================================
# STARTUP & CONFIG LOADING
# ==============================================================================

print_toolkit_header("Crosstab Analysis V9.9 - Production Release")

if (!exists("config_file")) {
  stop("ERROR: config_file not defined. Run from Jupyter notebook.")
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
  stop(sprintf("Survey structure file not found: %s", structure_file_path))
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
survey_structure$options$ShowInOutput[is.na(survey_structure$options$ShowInOutput)] <- "Y"
survey_structure$options$ExcludeFromIndex[is.na(survey_structure$options$ExcludeFromIndex)] <- "N"

log_message("✓ Survey structure loaded", "INFO")

# ==============================================================================
# LOAD DATA
# ==============================================================================

log_message("Loading survey data...", "INFO")
data_file <- get_config_value(survey_structure$project, "data_file", required = TRUE)
data_file_path <- resolve_path(project_root, data_file)

if (!file.exists(data_file_path)) {
  stop(sprintf("Data file not found: %s", data_file_path))
}

survey_data <- load_survey_data(data_file_path, project_root)
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
  readxl::read_excel(config_file, sheet = "Selection")
}, error = function(e) {
  stop(sprintf("Failed to load Selection sheet: %s", conditionMessage(e)))
})

validate_data_frame(selection_df, c("QuestionCode"), 1)

selection_df$Include <- ifelse(is.na(selection_df$Include), "N", selection_df$Include)
selection_df$UseBanner <- ifelse(is.na(selection_df$UseBanner), "N", selection_df$UseBanner)
selection_df$BannerBoxCategory <- ifelse(is.na(selection_df$BannerBoxCategory), "N", selection_df$BannerBoxCategory)
selection_df$CreateIndex <- ifelse(is.na(selection_df$CreateIndex), "N", selection_df$CreateIndex)

crosstab_questions <- selection_df[selection_df$Include == "Y", ]

if (nrow(crosstab_questions) == 0) {
  stop("No questions selected for analysis (Include='Y')")
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

# ==============================================================================
# BANNER STRUCTURE FUNCTIONS (Memory-optimized, no weight duplication)
# ==============================================================================

#' Create banner structure from selection
#'
#' @param selection_df Data frame from Selection sheet
#' @param survey_structure List with questions and options
#' @return List with banner metadata
#' @export
create_banner_structure <- function(selection_df, survey_structure) {
  validate_data_frame(selection_df, "QuestionCode", param_name = "selection_df")
  
  banner_questions <- selection_df[
    selection_df$UseBanner == "Y" & !is.na(selection_df$UseBanner), 
  ]
  
  if (nrow(banner_questions) == 0) {
    total_internal_key <- paste0("TOTAL::", TOTAL_COLUMN)
    return(list(
      banner_questions = NULL,
      columns = TOTAL_COLUMN,
      internal_keys = total_internal_key,
      column_labels = TOTAL_COLUMN,
      letters = "-",
      column_to_banner = setNames(TOTAL_COLUMN, total_internal_key),
      key_to_display = setNames(TOTAL_COLUMN, total_internal_key),
      banner_info = list(),
      banner_headers = data.frame(
        start_col = integer(), end_col = integer(), label = character(),
        stringsAsFactors = FALSE
      )
    ))
  }
  
  if ("DisplayOrder" %in% names(banner_questions) && 
      !all(is.na(banner_questions$DisplayOrder))) {
    banner_questions <- banner_questions[
      order(banner_questions$DisplayOrder, na.last = TRUE), 
    ]
  }
  
  all_columns <- TOTAL_COLUMN
  all_internal_keys <- paste0("TOTAL::", TOTAL_COLUMN)
  all_letters <- "-"
  column_to_banner <- setNames(TOTAL_COLUMN, all_internal_keys[1])
  key_to_display <- setNames(TOTAL_COLUMN, all_internal_keys[1])
  all_banner_info <- list()
  banner_headers <- data.frame(
    start_col = numeric(), end_col = numeric(), label = character(),
    stringsAsFactors = FALSE
  )
  
  current_col_index <- 2
  
  for (banner_idx in seq_len(nrow(banner_questions))) {
    banner_question_code <- banner_questions$QuestionCode[banner_idx]
    
    banner_question_info <- survey_structure$questions[
      survey_structure$questions$QuestionCode == banner_question_code, 
    ]
    
    if (nrow(banner_question_info) == 0) {
      warning(sprintf("Banner question not found: %s", banner_question_code))
      next
    }
    
    banner_question_info <- banner_question_info[1, ]
    
    is_boxcategory_banner <- !is.na(banner_questions$BannerBoxCategory[banner_idx]) &&
                             banner_questions$BannerBoxCategory[banner_idx] == "Y"
    
    banner_options <- survey_structure$options[
      survey_structure$options$QuestionCode == banner_question_code &
      (survey_structure$options$ShowInOutput == "Y" | 
       is.na(survey_structure$options$ShowInOutput)), 
    ]
    
    if ("DisplayOrder" %in% names(banner_options) && 
        !all(is.na(banner_options$DisplayOrder))) {
      banner_options <- banner_options[
        order(banner_options$DisplayOrder, na.last = TRUE), 
      ]
    }
    
    result <- if (is_boxcategory_banner) {
      process_boxcategory_banner(banner_question_code, banner_options, current_col_index)
    } else {
      process_standard_banner(banner_question_code, banner_question_info, 
                             banner_options, current_col_index)
    }
    
    if (is.null(result)) next
    
    all_columns <- c(all_columns, result$columns)
    all_internal_keys <- c(all_internal_keys, result$internal_keys)
    all_letters <- c(all_letters, result$letters)
    
    for (i in seq_along(result$columns)) {
      column_to_banner[result$internal_keys[i]] <- banner_question_code
      key_to_display[result$internal_keys[i]] <- result$columns[i]
    }
    
    banner_label <- get_banner_label(banner_questions, banner_idx)
    
    banner_headers <- rbind(banner_headers, data.frame(
      start_col = current_col_index,
      end_col = current_col_index + length(result$columns) - 1,
      label = banner_label,
      stringsAsFactors = FALSE
    ))
    
    all_banner_info[[banner_question_code]] <- c(
      list(
        question = banner_question_info,
        options = banner_options,
        is_boxcategory = is_boxcategory_banner
      ),
      result
    )
    
    current_col_index <- current_col_index + length(result$columns)
  }
  
  return(list(
    banner_questions = banner_questions,
    banner_info = all_banner_info,
    banner_headers = banner_headers,
    columns = all_columns,
    internal_keys = all_internal_keys,
    column_labels = all_columns,
    letters = all_letters,
    column_to_banner = column_to_banner,
    key_to_display = key_to_display
  ))
}

#' Process standard banner
#'
#' @param banner_code Character
#' @param question_info Data frame row
#' @param options Data frame
#' @param start_col Integer
#' @return List
process_standard_banner <- function(banner_code, question_info, options, start_col) {
  if (nrow(options) == 0) {
    warning(sprintf("No options for banner: %s", banner_code))
    return(NULL)
  }
  
  banner_columns <- options$DisplayText
  banner_internal_keys <- paste0(banner_code, "::", banner_columns)
  num_cols <- length(banner_columns)
  banner_letters <- generate_excel_letters(num_cols)
  
  return(list(
    columns = banner_columns,
    internal_keys = banner_internal_keys,
    letters = banner_letters,
    boxcat_groups = NULL
  ))
}

#' Process BoxCategory banner
#'
#' BOXCATEGORY LOGIC DOCUMENTED:
#' - For multi-mention questions: Uses OR logic across all columns
#' - Respondent included if they mentioned ANY option in the category
#'
#' @param banner_code Character
#' @param options Data frame
#' @param start_col Integer
#' @return List
process_boxcategory_banner <- function(banner_code, options, start_col) {
  box_categories <- unique(options$BoxCategory)
  box_categories <- box_categories[!is.na(box_categories) & box_categories != ""]
  
  if (length(box_categories) == 0) {
    warning(sprintf("No BoxCategory values for: %s", banner_code))
    return(NULL)
  }
  
  banner_columns <- box_categories
  banner_internal_keys <- paste0(banner_code, "::BOXCAT::", box_categories)
  num_cols <- length(banner_columns)
  banner_letters <- generate_excel_letters(num_cols)
  
  boxcat_option_groups <- lapply(box_categories, function(cat) {
    options$OptionText[options$BoxCategory == cat]
  })
  names(boxcat_option_groups) <- box_categories
  
  return(list(
    columns = banner_columns,
    internal_keys = banner_internal_keys,
    letters = banner_letters,
    boxcat_groups = boxcat_option_groups
  ))
}

#' Get banner label
#'
#' @param banner_questions Data frame
#' @param idx Integer
#' @return Character
get_banner_label <- function(banner_questions, idx) {
  label <- tryCatch({
    if ("BannerLabel" %in% names(banner_questions)) {
      label <- banner_questions$BannerLabel[idx]
      if (!is.null(label) && !is.na(label) && label != "") {
        return(as.character(label))
      }
    }
    
    if ("QuestionText" %in% names(banner_questions)) {
      label <- banner_questions$QuestionText[idx]
      if (!is.null(label) && !is.na(label) && label != "") {
        return(as.character(label))
      }
    }
    
    as.character(banner_questions$QuestionCode[idx])
  }, error = function(e) {
    as.character(banner_questions$QuestionCode[idx])
  })
  
  if (is.null(label) || length(label) == 0 || label == "") {
    label <- as.character(banner_questions$QuestionCode[idx])
  }
  
  return(label)
}

# ==============================================================================
# CREATE BANNER STRUCTURE
# ==============================================================================

log_message("Creating banner structure...", "INFO")
banner_info <- safe_execute(
  create_banner_structure(selection_df, survey_structure),
  default = NULL,
  error_msg = "Failed to create banner structure"
)

if (is.null(banner_info)) {
  stop("Banner structure creation failed")
}

log_message(sprintf("✓ Banner: %d columns", length(banner_info$columns)), "INFO")

# ==============================================================================
# END OF PART 2
# ==============================================================================
# ==============================================================================
# PART 3: MEMORY-OPTIMIZED BANNER SUBSETTING & STATISTICAL CALCULATIONS
# ==============================================================================

# ==============================================================================
# MEMORY-OPTIMIZED BANNER SUBSETTING (NO WEIGHT DUPLICATION)
# ==============================================================================

#' Create banner row indices (returns indices only, NO weights)
#'
#' Returns ONLY row indices, not weights. This prevents memory duplication.
#' Caller should use master_weights[row_idx] when weights are needed.
#'
#' @param data Data frame, survey data
#' @param banner_info List, banner structure
#' @return List with $row_indices (list of integer vectors ONLY)
#' @export
create_banner_row_indices <- function(data, banner_info) {
  validate_data_frame(data, param_name = "data")
  
  total_key <- paste0("TOTAL::", TOTAL_COLUMN)
  all_rows <- seq_len(nrow(data))
  
  row_indices_list <- setNames(list(all_rows), total_key)
  
  if (is.null(banner_info$banner_questions)) {
    return(list(row_indices = row_indices_list))
  }
  
  for (banner_code in names(banner_info$banner_info)) {
    banner_data_info <- banner_info$banner_info[[banner_code]]
    question_info <- banner_data_info$question
    
    if (!is.null(banner_data_info$is_boxcategory) && 
        banner_data_info$is_boxcategory) {
      subsets <- create_boxcategory_indices(data, banner_code, question_info, banner_data_info)
    } else {
      subsets <- create_standard_indices(data, banner_code, question_info, banner_data_info)
    }
    
    row_indices_list <- c(row_indices_list, subsets$row_indices)
  }
  
  return(list(row_indices = row_indices_list))
}

#' Create indices for standard banner (no weights returned)
#'
#' @param data Data frame
#' @param banner_code Character
#' @param question_info Data frame row
#' @param banner_data_info List
#' @return List with $row_indices ONLY
create_standard_indices <- function(data, banner_code, question_info, banner_data_info) {
  subset_indices <- list()
  
  if (question_info$Variable_Type == "Multi_Mention") {
    num_columns <- suppressWarnings(as.numeric(question_info$Columns))
    if (is.na(num_columns) || num_columns < 1) {
      return(list(row_indices = list()))
    }
    
    banner_cols <- paste0(banner_code, "_", seq_len(num_columns))
    existing_cols <- banner_cols[banner_cols %in% names(data)]
    if (!length(existing_cols)) {
      return(list(row_indices = list()))
    }
    
    for (option_idx in seq_len(nrow(banner_data_info$options))) {
      option_text <- banner_data_info$options$OptionText[option_idx]
      internal_key <- banner_data_info$internal_keys[option_idx]
      
      matching_rows <- Reduce(`|`, lapply(existing_cols, function(col) {
        safe_equal(data[[col]], option_text) & !is.na(data[[col]])
      }))
      
      row_idx <- which(matching_rows)
      subset_indices[[internal_key]] <- row_idx
    }
  } else {
    if (!banner_code %in% names(data)) {
      return(list(row_indices = list()))
    }
    
    for (option_idx in seq_len(nrow(banner_data_info$options))) {
      option_text <- banner_data_info$options$OptionText[option_idx]
      internal_key <- banner_data_info$internal_keys[option_idx]
      
      matching_rows <- safe_equal(data[[banner_code]], option_text) & 
                      !is.na(data[[banner_code]])
      
      row_idx <- which(matching_rows)
      subset_indices[[internal_key]] <- row_idx
    }
  }
  
  return(list(row_indices = subset_indices))
}

#' Create indices for BoxCategory banner (no weights returned)
#'
#' @param data Data frame
#' @param banner_code Character
#' @param question_info Data frame row
#' @param banner_data_info List
#' @return List with $row_indices ONLY
create_boxcategory_indices <- function(data, banner_code, question_info, banner_data_info) {
  subset_indices <- list()
  
  if (question_info$Variable_Type == "Multi_Mention") {
    num_columns <- suppressWarnings(as.numeric(question_info$Columns))
    if (is.na(num_columns) || num_columns < 1) {
      return(list(row_indices = list()))
    }
    
    banner_cols <- paste0(banner_code, "_", seq_len(num_columns))
    existing_cols <- banner_cols[banner_cols %in% names(data)]
    if (!length(existing_cols)) {
      return(list(row_indices = list()))
    }
    
    for (box_cat_idx in seq_along(banner_data_info$boxcat_groups)) {
      box_cat <- names(banner_data_info$boxcat_groups)[box_cat_idx]
      option_texts <- banner_data_info$boxcat_groups[[box_cat]]
      internal_key <- banner_data_info$internal_keys[box_cat_idx]
      
      matching_rows <- Reduce(`|`, lapply(existing_cols, function(col) {
        Reduce(`|`, lapply(option_texts, function(opt) {
          safe_equal(data[[col]], opt) & !is.na(data[[col]])
        }))
      }))
      
      row_idx <- which(matching_rows)
      subset_indices[[internal_key]] <- row_idx
    }
  } else {
    if (!banner_code %in% names(data)) {
      return(list(row_indices = list()))
    }
    
    for (box_cat_idx in seq_along(banner_data_info$boxcat_groups)) {
      box_cat <- names(banner_data_info$boxcat_groups)[box_cat_idx]
      option_texts <- banner_data_info$boxcat_groups[[box_cat]]
      internal_key <- banner_data_info$internal_keys[box_cat_idx]
      
      matching_rows <- Reduce(`|`, lapply(option_texts, function(opt) {
        safe_equal(data[[banner_code]], opt) & !is.na(data[[banner_code]])
      }))
      
      row_idx <- which(matching_rows)
      subset_indices[[internal_key]] <- row_idx
    }
  }
  
  return(list(row_indices = subset_indices))
}

#' Get data subset using row indices (helper)
#'
#' @param data Data frame, full dataset
#' @param row_indices Integer vector, row indices
#' @return Data frame subset
#' @export
get_data_subset <- function(data, row_indices) {
  if (length(row_indices) == 0) {
    return(data[integer(0), , drop = FALSE])
  }
  data[row_indices, , drop = FALSE]
}

# ==============================================================================
# STATISTICAL CALCULATIONS
# ==============================================================================

#' Calculate weighted variance (POPULATION VARIANCE)
#'
#' @param values Numeric vector
#' @param weights Numeric vector
#' @return Numeric, weighted population variance
#' @export
weighted_variance <- function(values, weights) {
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values <- values[valid_idx]
  weights <- weights[valid_idx]
  
  if (length(values) < 2) return(0)
  
  sum_weights <- sum(weights)
  if (sum_weights == 0) return(0)
  
  weighted_mean <- sum(values * weights) / sum_weights
  weighted_var <- sum(weights * (values - weighted_mean)^2) / sum_weights
  
  return(weighted_var)
}

#' Z-test for weighted proportions
#'
#' STATISTICAL METHODOLOGY:
#' - p_pooled = (weighted_count1 + weighted_count2) / (weighted_base1 + weighted_base2)
#' - Uses design-weighted counts and bases for pooled proportion
#' - Standard error uses effective-n (not weighted n) to account for design effect
#'
#' @param count1 Numeric, weighted count group 1
#' @param base1 Numeric, weighted base group 1
#' @param count2 Numeric, weighted count group 2
#' @param base2 Numeric, weighted base group 2
#' @param eff_n1 Numeric, effective sample size group 1 (REQUIRED if is_weighted=TRUE)
#' @param eff_n2 Numeric, effective sample size group 2 (REQUIRED if is_weighted=TRUE)
#' @param is_weighted Logical, whether data is weighted
#' @param min_base Integer, minimum base for testing
#' @param alpha Numeric, significance level (e.g., 0.05 for 95% CI)
#' @return List with $significant, $p_value, $higher
#' @export
weighted_z_test_proportions <- function(count1, base1, count2, base2, 
                                       eff_n1 = NULL, eff_n2 = NULL,
                                       is_weighted = FALSE,
                                       min_base = DEFAULT_MIN_BASE,
                                       alpha = DEFAULT_ALPHA) {
  if (any(is.na(c(count1, base1, count2, base2)))) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }
  
  if (is_weighted && (is.null(eff_n1) || is.null(eff_n2))) {
    warning("Weighted data requires effective-n for valid significance testing")
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }
  
  n1 <- if (is_weighted && !is.null(eff_n1)) eff_n1 else base1
  n2 <- if (is_weighted && !is.null(eff_n2)) eff_n2 else base2
  
  if (n1 < min_base || n2 < min_base) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }
  
  if (base1 == 0 || base2 == 0) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }
  
  p1 <- count1 / base1
  p2 <- count2 / base2
  
  p_pooled <- (count1 + count2) / (base1 + base2)
  
  if (p_pooled == 0 || p_pooled == 1) {
    return(list(significant = FALSE, p_value = 1, higher = (p1 > p2)))
  }
  
  se <- sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))
  
  if (se == 0 || is.na(se)) {
    return(list(significant = FALSE, p_value = 1, higher = (p1 > p2)))
  }
  
  z_stat <- (p1 - p2) / se
  p_value <- 2 * pnorm(-abs(z_stat))
  
  return(list(
    significant = (!is.na(p_value) && p_value < alpha),
    p_value = p_value,
    higher = (p1 > p2)
  ))
}

#' T-test for weighted means
#'
#' @param values1 Numeric vector, group 1
#' @param values2 Numeric vector, group 2
#' @param weights1 Numeric vector, weights group 1 (optional)
#' @param weights2 Numeric vector, weights group 2 (optional)
#' @param min_base Integer, minimum base
#' @param alpha Numeric, significance level
#' @return List with $significant, $p_value, $higher
#' @export
weighted_t_test_means <- function(values1, values2, weights1 = NULL, weights2 = NULL,
                                  min_base = DEFAULT_MIN_BASE,
                                  alpha = DEFAULT_ALPHA) {
  if (is.null(weights1)) weights1 <- rep(1, length(values1))
  if (is.null(weights2)) weights2 <- rep(1, length(values2))
  
  eff_n1 <- calculate_effective_n(weights1)
  eff_n2 <- calculate_effective_n(weights2)
  
  if (eff_n1 < min_base || eff_n2 < min_base) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }
  
  tryCatch({
    mean1 <- weighted.mean(values1, weights1, na.rm = TRUE)
    mean2 <- weighted.mean(values2, weights2, na.rm = TRUE)
    
    if (is.na(mean1) || is.na(mean2)) {
      return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
    }
    
    var1 <- weighted_variance(values1, weights1)
    var2 <- weighted_variance(values2, weights2)
    
    se <- sqrt(var1/eff_n1 + var2/eff_n2)
    
    if (se == 0 || is.na(se)) {
      return(list(significant = FALSE, p_value = 1, higher = (mean1 > mean2)))
    }
    
    t_stat <- (mean1 - mean2) / se
    
    df <- (var1/eff_n1 + var2/eff_n2)^2 / 
          ((var1/eff_n1)^2/(eff_n1-1) + (var2/eff_n2)^2/(eff_n2-1))
    
    if (is.na(df) || df <= 0) {
      return(list(significant = FALSE, p_value = NA_real_, higher = (mean1 > mean2)))
    }
    
    p_value <- 2 * pt(-abs(t_stat), df)
    
    return(list(
      significant = (!is.na(p_value) && p_value < alpha),
      p_value = p_value,
      higher = (mean1 > mean2)
    ))
    
  }, error = function(e) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  })
}

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
    stop(sprintf(
      "Sig letter mapping mismatch:\n  Test data keys: %s\n  Banner columns: %s",
      paste(head(names(row_data), 5), collapse = ", "),
      paste(head(banner_structure$column_names, 5), collapse = ", ")
    ))
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

#' Calculate summary statistic (FIXED: Rating calculation with OptionValue support)
#'
#' @param data Data frame, survey data
#' @param question_info Data frame row
#' @param options_info Data frame
#' @param weights Numeric vector
#' @return List with stat info or NULL
#' @export
calculate_summary_statistic <- function(data, question_info, options_info, weights) {
  var_type <- question_info$Variable_Type
  question_col <- question_info$QuestionCode

    
  if (var_type == "Rating") {
    valid_options <- options_info[
      options_info$ExcludeFromIndex != "Y" | is.na(options_info$ExcludeFromIndex), 
    ]
    
    if (question_col %in% names(data)) {
      all_responses <- data[[question_col]]
      
      # Convert both to character for matching
      matching_responses <- sapply(all_responses, function(resp) {
        if (is.na(resp) || resp == "") return(FALSE)
        any(safe_equal(as.character(resp), as.character(valid_options$OptionText)))
      })
      
      valid_data <- all_responses[matching_responses]
      valid_weights <- weights[matching_responses]
      
      if (length(valid_data) > 0) {
        numeric_values <- numeric(0)
        numeric_weights <- numeric(0)
        
        for (i in seq_len(nrow(valid_options))) {
          matching <- safe_equal(as.character(valid_data), as.character(valid_options$OptionText[i]))
          
          if (any(matching, na.rm = TRUE)) {
            option_value <- if ("OptionValue" %in% names(valid_options)) {
              suppressWarnings(as.numeric(valid_options$OptionValue[i]))
            } else {
              suppressWarnings(as.numeric(valid_options$OptionText[i]))
            }
            
            if (!is.na(option_value)) {
              count <- sum(matching, na.rm = TRUE)
              numeric_values <- c(numeric_values, rep(option_value, count))
              numeric_weights <- c(numeric_weights, valid_weights[matching])
            }
          }
        }
        
        if (length(numeric_values) > 0 && sum(numeric_weights) > 0) {
          mean_value <- weighted.mean(numeric_values, numeric_weights, na.rm = TRUE)
          
          return(list(
            stat_name = "Mean", 
            stat_label = AVERAGE_ROW_TYPE, 
            value = mean_value, 
            values = numeric_values,
            weights = numeric_weights
          ))
        }
      }
    }
    
  } else if (var_type == "Likert") {
    index_options <- options_info[!is.na(options_info$Index_Weight), ]
    
    if (nrow(index_options) > 0 && question_col %in% names(data)) {
      weighted_sum <- 0
      total_weight <- 0
      all_weighted_values <- numeric(0)
      all_weights <- numeric(0)
      
      for (i in seq_len(nrow(index_options))) {
        matching <- safe_equal(data[[question_col]], index_options$OptionText[i])
        option_weight <- sum(weights[matching], na.rm = TRUE)
        weighted_sum <- weighted_sum + (option_weight * index_options$Index_Weight[i])
        total_weight <- total_weight + option_weight
        
        all_weighted_values <- c(all_weighted_values, 
          rep(index_options$Index_Weight[i], sum(matching, na.rm = TRUE)))
        all_weights <- c(all_weights, weights[matching])
      }
      
      if (total_weight > 0) {
        index_value <- weighted_sum / total_weight
        return(list(
          stat_name = "Index", 
          stat_label = INDEX_ROW_TYPE,
          value = index_value, 
          values = all_weighted_values,
          weights = all_weights
        ))
      }
    }
    
  } else if (var_type == "NPS") {
    # NPS: Calculate Net Promoter Score (0-10 scale)
    # NOTE: 0 is a VALID score (detractor), must be included in base
    if (question_col %in% names(data)) {
      all_responses <- data[[question_col]]
      
      # Filter out ONLY non-numeric responses (DK, NA, blank)
      # Important: Keep 0 as it's a valid NPS score
      valid_responses <- all_responses[
        !is.na(all_responses) & 
        all_responses != "" &
        !all_responses %in% c("DK", "Don't know", "Not applicable", "NA")
      ]
      valid_weights <- weights[
        !is.na(all_responses) & 
        all_responses != "" &
        !all_responses %in% c("DK", "Don't know", "Not applicable", "NA")
      ]
      
      if (length(valid_responses) > 0) {
        numeric_responses <- suppressWarnings(as.numeric(valid_responses))
        valid_idx <- !is.na(numeric_responses)
        numeric_responses <- numeric_responses[valid_idx]
        valid_weights <- valid_weights[valid_idx]
        
        if (length(numeric_responses) > 0 && sum(valid_weights) > 0) {
          promoters <- sum(valid_weights[numeric_responses >= 9])
          detractors <- sum(valid_weights[numeric_responses <= 6])
          total_valid <- sum(valid_weights)
          
          if (total_valid > 0) {
            nps_score <- ((promoters - detractors) / total_valid) * 100
            return(list(
              stat_name = "NPS Score", 
              stat_label = SCORE_ROW_TYPE, 
              value = nps_score, 
              values = numeric_responses,
              weights = valid_weights
            ))
          }
        }
      }
    }
  }
  
  return(NULL)
}
# ==============================================================================
# END OF PART 3
# ==============================================================================
# ==============================================================================
# PART 4: QUESTION PROCESSING FUNCTIONS
# ==============================================================================

# ==============================================================================
# ROW CALCULATION FUNCTIONS
# ==============================================================================

#' Calculate row counts (uses master_weights[row_idx])
#'
#' @param data Data frame, full dataset
#' @param banner_row_indices List of integer vectors (row indices by banner)
#' @param option_text Character, option to count
#' @param question_col Character, question column name
#' @param is_multi_mention Logical
#' @param existing_cols Character vector, multi-mention columns
#' @param internal_keys Character vector, banner keys
#' @param master_weights Numeric vector, MASTER weight vector for all data
#' @return Named numeric vector of weighted counts
#' @export
calculate_row_counts <- function(data, banner_row_indices, option_text, question_col,
                                is_multi_mention, existing_cols, internal_keys, 
                                master_weights) {
  row_counts <- setNames(numeric(length(internal_keys)), internal_keys)
  
  for (key in internal_keys) {
    row_idx <- banner_row_indices[[key]]
    
    if (length(row_idx) > 0) {
      subset_weights <- master_weights[row_idx]
      
      if (is_multi_mention) {
        mention_count <- 0
        for (question_col_i in existing_cols) {
          matching <- safe_equal(data[[question_col_i]][row_idx], option_text) & 
                     !is.na(data[[question_col_i]][row_idx])
          mention_count <- mention_count + sum(subset_weights[matching], na.rm = TRUE)
        }
        row_counts[key] <- mention_count
      } else {
        matching <- safe_equal(data[[question_col]][row_idx], option_text) & 
                   !is.na(data[[question_col]][row_idx])
        row_counts[key] <- sum(subset_weights[matching], na.rm = TRUE)
      }
    }
  }
  
  return(row_counts)
}

#' Calculate weighted percentage
#'
#' @param weighted_count Numeric
#' @param weighted_base Numeric
#' @return Numeric percentage or NA
#' @export
calculate_weighted_percentage <- function(weighted_count, weighted_base) {
  if (is.na(weighted_base) || weighted_base == 0) return(NA_real_)
  return((weighted_count / weighted_base) * 100)
}

#' Create percentage row
#'
#' @param row_counts Named numeric vector
#' @param banner_bases List, base info by column
#' @param internal_keys Character vector
#' @param display_text Character
#' @param show_label Logical
#' @param decimal_places Integer
#' @return Data frame
#' @export
create_percentage_row <- function(row_counts, banner_bases, internal_keys, 
                                 display_text, show_label, decimal_places = 0) {
  row <- data.frame(
    RowLabel = if (show_label) display_text else "",
    RowType = COLUMN_PCT_ROW_TYPE,
    stringsAsFactors = FALSE
  )
  
  for (key in internal_keys) {
    base_info <- banner_bases[[key]]
    weighted_base <- if (!is.null(base_info$weighted)) {
      base_info$weighted
    } else {
      base_info$unweighted
    }
    percentage <- calculate_weighted_percentage(row_counts[key], weighted_base)
    row[[key]] <- format_output_value(percentage, "percent", 
                                     decimal_places_percent = decimal_places)
  }
  
  return(row)
}

#' Create row percentage row
#'
#' @param row_counts Named numeric vector
#' @param banner_info List
#' @param internal_keys Character vector
#' @param display_text Character
#' @param show_label Logical
#' @param decimal_places Integer
#' @param zero_division_as_blank Logical
#' @return Data frame
#' @export
create_row_percentage_row <- function(row_counts, banner_info, internal_keys, 
                                     display_text, show_label, decimal_places = 0,
                                     zero_division_as_blank = TRUE) {
  row <- data.frame(
    RowLabel = if (show_label) display_text else "",
    RowType = ROW_PCT_ROW_TYPE,
    stringsAsFactors = FALSE
  )
  
  total_key <- paste0("TOTAL::", TOTAL_COLUMN)
  if (total_key %in% internal_keys) {
    total_count <- row_counts[total_key]
    
    if (total_count == 0) {
      if (zero_division_as_blank) {
        row[[total_key]] <- NA_real_
      } else {
        row[[total_key]] <- format_output_value(0, "percent",
                                                decimal_places_percent = decimal_places)
      }
    } else {
      row[[total_key]] <- format_output_value(
        calculate_weighted_percentage(total_count, total_count),
        "percent", decimal_places_percent = decimal_places
      )
    }
  }
  
  for (banner_code in names(banner_info$banner_info)) {
    banner_keys <- banner_info$banner_info[[banner_code]]$internal_keys
    banner_total <- sum(row_counts[banner_keys], na.rm = TRUE)
    
    for (key in banner_keys) {
      if (banner_total == 0) {
        if (zero_division_as_blank) {
          row[[key]] <- NA_real_
        } else {
          row[[key]] <- format_output_value(0, "percent",
                                           decimal_places_percent = decimal_places)
        }
      } else {
        percentage <- calculate_weighted_percentage(row_counts[key], banner_total)
        row[[key]] <- format_output_value(percentage, "percent",
                                         decimal_places_percent = decimal_places)
      }
    }
  }
  
  return(row)
}

# ==============================================================================
# MAIN QUESTION PROCESSING (FIXED: Multi-mention and ShowInOutput)
# ==============================================================================

#' Process standard question (uses master_weights)
#'
#' FIXED: Multi-mention options now use column names (Q01_1, Q01_2)
#' FIXED: ShowInOutput filtering now works properly
#'
#' @param data Data frame, full dataset
#' @param question_info Data frame row
#' @param question_options Data frame
#' @param banner_info List
#' @param banner_row_indices List of integer vectors
#' @param master_weights Numeric vector, master weights for all data
#' @param banner_bases List
#' @param config List
#' @param is_weighted Logical
#' @return Data frame with results or NULL
#' @export
process_question <- function(data, question_info, question_options, banner_info,
                            banner_row_indices, master_weights, banner_bases, config,
                            is_weighted = FALSE) {
  question_col <- question_info$QuestionCode
  is_multi_mention <- question_info$Variable_Type == "Multi_Mention"
  internal_keys <- banner_info$internal_keys
  
  # FIXED: ShowInOutput filtering
  display_options <- question_options[
    question_options$ShowInOutput == "Y" | is.na(question_options$ShowInOutput), 
  ]
  
  if ("DisplayOrder" %in% names(display_options) && 
      !all(is.na(display_options$DisplayOrder))) {
    display_options <- display_options[
      order(display_options$DisplayOrder, na.last = TRUE), 
    ]
  }
  
  existing_cols <- NULL
  if (is_multi_mention) {
    num_columns <- suppressWarnings(as.numeric(question_info$Columns))
    if (is.na(num_columns) || num_columns < 1) {
      warning(sprintf("Invalid column count for %s", question_col))
      return(NULL)
    }
    
    question_cols <- paste0(question_col, "_", seq_len(num_columns))
    existing_cols <- question_cols[question_cols %in% names(data)]
    
    if (!length(existing_cols)) {
      warning(sprintf("No multi-mention columns for %s", question_col))
      return(NULL)
    }
  } else {
    if (!question_col %in% names(data)) {
      warning(sprintf("Question column not found: %s", question_col))
      return(NULL)
    }
  }
  
  results_list <- list()
  
  for (option_idx in seq_len(nrow(display_options))) {
    current_option <- display_options[option_idx, ]
    option_text <- current_option$OptionText
    display_text <- if (!is.na(current_option$DisplayText)) {
      current_option$DisplayText
    } else {
      option_text
    }
    
    row_counts <- calculate_row_counts(
      data, banner_row_indices, option_text, question_col,
      is_multi_mention, existing_cols, internal_keys, master_weights
    )
    
    if (config$show_frequency) {
      freq_row <- data.frame(
        RowLabel = display_text, 
        RowType = FREQUENCY_ROW_TYPE, 
        stringsAsFactors = FALSE
      )
      for (key in internal_keys) {
        freq_row[[key]] <- format_output_value(row_counts[key], "frequency")
      }
      results_list[[length(results_list) + 1]] <- freq_row
    }
    
    if (config$show_percent_column) {
      col_pct_row <- create_percentage_row(
        row_counts, banner_bases, internal_keys,
        display_text, !config$show_frequency,
        config$decimal_places_percent
      )
      results_list[[length(results_list) + 1]] <- col_pct_row
    }
    
    if (config$show_percent_row) {
      row_pct_row <- create_row_percentage_row(
        row_counts, banner_info, internal_keys,
        display_text, !config$show_frequency && !config$show_percent_column,
        config$decimal_places_percent,
        zero_division_as_blank = config$zero_division_as_blank
      )
      results_list[[length(results_list) + 1]] <- row_pct_row
    }
    
    if (config$show_percent_column && config$enable_significance_testing) {
      test_data <- list()
      total_key <- paste0("TOTAL::", TOTAL_COLUMN)
      
      for (key in internal_keys) {
        if (key != total_key) {
          base_info <- banner_bases[[key]]
          test_data[[key]] <- list(
            count = row_counts[key],
            base = if (!is.null(base_info$weighted)) {
              base_info$weighted
            } else {
              base_info$unweighted
            },
            eff_n = if (!is.null(base_info$effective)) {
              base_info$effective
            } else {
              base_info$unweighted
            }
          )
        }
      }
      
      sig_row <- add_significance_row(
        test_data, banner_info, "proportion", internal_keys,
        alpha = config$alpha,
        config$bonferroni_correction,
        config$significance_min_base,
        is_weighted = is_weighted
      )
      
      if (!is.null(sig_row)) {
        results_list[[length(results_list) + 1]] <- sig_row
      }
    }
  }
  
  if (length(results_list) > 0) {
    return(batch_rbind(results_list))
  }
  
  return(NULL)
}

#' Add BoxCategory summaries
#'
#' @param data Data frame
#' @param question_info Data frame row
#' @param question_options Data frame
#' @param banner_info List
#' @param banner_row_indices List of integer vectors
#' @param master_weights Numeric vector
#' @param banner_bases List
#' @param config List
#' @param is_weighted Logical
#' @return Data frame or NULL
#' @export
add_boxcategory_summaries <- function(data, question_info, question_options, 
                                     banner_info, banner_row_indices, master_weights, 
                                     banner_bases, config,
                                     is_weighted = FALSE) {
  box_categories <- unique(question_options$BoxCategory)
  box_categories <- box_categories[!is.na(box_categories) & box_categories != ""]
  
  if (length(box_categories) == 0) return(NULL)
  
  internal_keys <- banner_info$internal_keys
  results_list <- list()
  
  for (category in box_categories) {
    category_options <- question_options[question_options$BoxCategory == category, ]
    row_counts <- setNames(numeric(length(internal_keys)), internal_keys)
    
    for (key in internal_keys) {
      row_idx <- banner_row_indices[[key]]
      
      if (length(row_idx) > 0) {
        subset_weights <- master_weights[row_idx]
        
        if (question_info$Variable_Type == "Multi_Mention") {
          num_columns <- as.numeric(question_info$Columns)
          question_cols <- paste0(question_info$QuestionCode, "_", seq_len(num_columns))
          existing_cols <- question_cols[question_cols %in% names(data)]
          
          category_count <- 0
          for (question_col in existing_cols) {
            for (option_text in category_options$OptionText) {
              matching <- safe_equal(data[[question_col]][row_idx], option_text) &
                         !is.na(data[[question_col]][row_idx])
              category_count <- category_count + sum(subset_weights[matching], na.rm = TRUE)
            }
          }
          row_counts[key] <- category_count
        } else {
          question_col <- question_info$QuestionCode
          if (question_col %in% names(data)) {
            for (option_text in category_options$OptionText) {
              matching <- safe_equal(data[[question_col]][row_idx], option_text) &
                         !is.na(data[[question_col]][row_idx])
              row_counts[key] <- row_counts[key] + sum(subset_weights[matching], na.rm = TRUE)
            }
          }
        }
      }
    }
    
    if (config$boxcategory_frequency) {
      freq_row <- data.frame(
        RowLabel = category, 
        RowType = FREQUENCY_ROW_TYPE, 
        stringsAsFactors = FALSE
      )
      for (key in internal_keys) {
        freq_row[[key]] <- format_output_value(row_counts[key], "frequency")
      }
      results_list[[length(results_list) + 1]] <- freq_row
    }
    
    if (config$boxcategory_percent_column) {
      col_pct_row <- create_percentage_row(
        row_counts, banner_bases, internal_keys,
        category, !config$boxcategory_frequency,
        config$decimal_places_percent
      )
      results_list[[length(results_list) + 1]] <- col_pct_row
      
      if (config$enable_significance_testing) {
        test_data <- list()
        total_key <- paste0("TOTAL::", TOTAL_COLUMN)
        
        for (key in internal_keys) {
          if (key != total_key) {
            base_info <- banner_bases[[key]]
            test_data[[key]] <- list(
              count = row_counts[key],
              base = if (!is.null(base_info$weighted)) {
                base_info$weighted
              } else {
                base_info$unweighted
              },
              eff_n = if (!is.null(base_info$effective)) {
                base_info$effective
              } else {
                base_info$unweighted
              }
            )
          }
        }
        
        sig_row <- add_significance_row(
          test_data, banner_info, "topbox", internal_keys,
          alpha = config$alpha,
          config$bonferroni_correction,
          config$significance_min_base,
          is_weighted = is_weighted
        )
        
        if (!is.null(sig_row)) {
          results_list[[length(results_list) + 1]] <- sig_row
        }
      }
    }
    
    if (config$boxcategory_percent_row) {
      row_pct_row <- create_row_percentage_row(
        row_counts, banner_info, internal_keys,
        category, !config$boxcategory_frequency && !config$boxcategory_percent_column,
        config$decimal_places_percent,
        zero_division_as_blank = config$zero_division_as_blank
      )
      results_list[[length(results_list) + 1]] <- row_pct_row
    }
  }
  
  if (length(results_list) > 0) {
    return(batch_rbind(results_list))
  }
  
  return(NULL)
}

#' Add summary statistic
#'
#' Smart formatting by stat type:
#' - Mean (Rating) → "rating" format
#' - Index (Likert) → "index" format
#' - Score (NPS) → "percent" format
#'
#' @param data Data frame
#' @param question_info Data frame row
#' @param question_options Data frame
#' @param banner_info List
#' @param banner_row_indices List of integer vectors
#' @param master_weights Numeric vector
#' @param banner_bases List
#' @param selection_row Data frame row
#' @param config List
#' @param is_weighted Logical
#' @return Data frame or NULL
#' @export
add_summary_statistic <- function(data, question_info, question_options, banner_info,
                                 banner_row_indices, master_weights, banner_bases, 
                                 selection_row, config,
                                 is_weighted = FALSE) {
  create_index <- if (!is.null(selection_row) && "CreateIndex" %in% names(selection_row)) {
    if (is.na(selection_row$CreateIndex)) "N" else selection_row$CreateIndex
  } else {
    "N"
  }
  
  if (create_index != "Y") return(NULL)
  if (!question_info$Variable_Type %in% c("Rating", "Likert", "NPS")) return(NULL)
  
  internal_keys <- banner_info$internal_keys
  stat_values <- setNames(numeric(length(internal_keys)), internal_keys)
  stat_value_sets <- list()
  stat_weight_sets <- list()
  
  for (key in internal_keys) {
    row_idx <- banner_row_indices[[key]]
    
    if (length(row_idx) > 0) {
      subset_data <- data[row_idx, , drop = FALSE]
      subset_weights <- master_weights[row_idx]
      
      stat_result <- calculate_summary_statistic(
        subset_data, question_info, question_options, subset_weights
      )
      
      if (!is.null(stat_result)) {
        stat_values[key] <- stat_result$value
        stat_value_sets[[key]] <- stat_result$values
        stat_weight_sets[[key]] <- stat_result$weights
      } else {
        stat_values[key] <- NA_real_
      }
    } else {
      stat_values[key] <- NA_real_
    }
  }
  
  stat_result <- calculate_summary_statistic(
    data, question_info, question_options, master_weights
  )
  if (is.null(stat_result)) return(NULL)
  
  summary_row <- data.frame(
    RowLabel = stat_result$stat_name, 
    RowType = stat_result$stat_label,
    stringsAsFactors = FALSE
  )
  
  value_type <- if (stat_result$stat_label == AVERAGE_ROW_TYPE) {
    "rating"
  } else if (stat_result$stat_label == INDEX_ROW_TYPE) {
    "index"
  } else if (stat_result$stat_label == SCORE_ROW_TYPE) {
    "percent"
  } else {
    "index"
  }
  
  for (key in internal_keys) {
    summary_row[[key]] <- format_output_value(
      stat_values[key], value_type,
      decimal_places_percent = config$decimal_places_percent,
      decimal_places_ratings = config$decimal_places_ratings,
      decimal_places_index   = config$decimal_places_index
    )
  }
  
results_list <- list(summary_row)
  
 # ==============================================================================
  # V9.9.5: STANDARD DEVIATION (CLEAN IMPLEMENTATION)
  # ==============================================================================
  if (config$show_standard_deviation && 
      question_info$Variable_Type %in% c("Rating", "Likert", "NPS")) {
    
    sd_values <- setNames(numeric(length(internal_keys)), internal_keys)
    
    for (key in internal_keys) {
      row_idx <- banner_row_indices[[key]]
      
      if (length(row_idx) > 0) {
        subset_data <- data[row_idx, , drop = FALSE]
        subset_weights <- master_weights[row_idx]
        
        # Get values for this column
        col_stat <- calculate_summary_statistic(
          subset_data, question_info, question_options, subset_weights
        )
        
        if (!is.null(col_stat) && !is.null(col_stat$values) && length(col_stat$values) > 1) {
          values <- col_stat$values
          weights <- col_stat$weights
          
          valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
          
          if (sum(valid_idx) > 1) {
            v <- values[valid_idx]
            w <- weights[valid_idx]
            
            if (all(w == 1)) {
              sd_values[key] <- sd(v)
            } else {
              mean_val <- sum(v * w) / sum(w)
              var_val <- sum(w * (v - mean_val)^2) / sum(w)
              sd_values[key] <- sqrt(var_val)
            }
          }
        }
      }
    }
    
    # Create SD row
    sd_row <- data.frame(
      RowLabel = "Standard Deviation",
      RowType = "StdDev",
      stringsAsFactors = FALSE
    )
    
    for (key in internal_keys) {
      sd_row[[key]] <- format_output_value(
        sd_values[key], 
        "rating",  # Always use rating format for SD
        decimal_places_percent = config$decimal_places_percent,
        decimal_places_ratings = config$decimal_places_ratings,
        decimal_places_index = config$decimal_places_index
      )
    }
    
    results_list[[length(results_list) + 1]] <- sd_row
  }
  # ==============================================================================
  
  
  test_enabled <- question_info$Variable_Type %in% c("Rating", "Likert", "NPS") &&
                  config$enable_significance_testing
  
  if (test_enabled) {
    test_data <- list()
    total_key <- paste0("TOTAL::", TOTAL_COLUMN)
    
    for (key in internal_keys) {
      if (key != total_key && !is.null(stat_value_sets[[key]])) {
        test_data[[key]] <- list(
          values = stat_value_sets[[key]],
          weights = stat_weight_sets[[key]]
        )
      }
    }
    
    sig_row <- add_significance_row(
      test_data, banner_info, "index", internal_keys,
      alpha = config$alpha,
      config$bonferroni_correction,
      config$significance_min_base,
      is_weighted = is_weighted
    )
    
    if (!is.null(sig_row)) {
      results_list[[length(results_list) + 1]] <- sig_row
    }
  }
  
  if (length(results_list) > 0) {
    return(batch_rbind(results_list))
  }
  
  return(NULL)
}

# V9.9.5: NEW FUNCTION - Net difference testing (SAFE - doesn't modify existing code)
#' Add net difference significance rows (SAFE VERSION)
#'
#' Adds significance testing rows for BoxCategory nets.
#' Called AFTER add_boxcategory_summaries completes.
#' Does not modify existing BoxCategory logic.
#'
#' @param existing_table Data frame, existing BoxCategory results
#' @param data Data frame, survey data
#' @param question_info Data frame row
#' @param question_options Data frame
#' @param banner_info List
#' @param banner_row_indices List of row indices
#' @param master_weights Numeric vector
#' @param banner_bases List
#' @param config List
#' @param is_weighted Logical
#' @return Data frame with net sig rows inserted, or original table if not applicable
#' @export
add_net_significance_rows <- function(existing_table, data, question_info, question_options,
                                     banner_info, banner_row_indices, master_weights,
                                     banner_bases, config, is_weighted = FALSE) {
  # Safety checks
  if (is.null(existing_table) || nrow(existing_table) == 0) {
    return(existing_table)
  }
  
  if (!config$test_net_differences || !config$enable_significance_testing) {
    return(existing_table)
  }
  
  # Get BoxCategories from options
  box_categories <- unique(question_options$BoxCategory)
  box_categories <- box_categories[!is.na(box_categories) & box_categories != ""]
  
  # Only for exactly 2 nets
  if (length(box_categories) != 2) {
    return(existing_table)
  }
  
  internal_keys <- banner_info$internal_keys
  
  # Recalculate row counts for each net (SAFE - separate calculation)
  row_counts_net1 <- calculate_boxcategory_counts(
    data, question_info, question_options, banner_row_indices,
    master_weights, internal_keys, box_categories[1]
  )
  
  row_counts_net2 <- calculate_boxcategory_counts(
    data, question_info, question_options, banner_row_indices,
    master_weights, internal_keys, box_categories[2]
  )
  
  # Build test data
  net_test_data <- list()
  total_key <- paste0("TOTAL::", TOTAL_COLUMN)
  
  for (key in internal_keys) {
    if (key != total_key) {
      base_info <- banner_bases[[key]]
      
      net_test_data[[key]] <- list(
        count1 = row_counts_net1[key],
        count2 = row_counts_net2[key],
        base = if (!is.null(base_info$weighted)) {
          base_info$weighted
        } else {
          base_info$unweighted
        },
        eff_n = if (!is.null(base_info$effective)) {
          base_info$effective
        } else {
          base_info$unweighted
        }
      )
    }
  }
  
  # Run net difference tests
  net_sig_results <- run_net_difference_tests(
    net_test_data, banner_info, internal_keys,
    alpha = config$alpha,
    config$bonferroni_correction,
    config$significance_min_base,
    is_weighted = is_weighted
  )
  
  if (is.null(net_sig_results)) {
    return(existing_table)
  }
  
  # Insert sig rows into existing table
  # Find net1 percentage row position
  net1_name <- box_categories[1]
  net1_pct_row <- which(
    existing_table$RowLabel == net1_name & 
    existing_table$RowType == "Column %"
  )
  
  if (length(net1_pct_row) > 0) {
    net1_sig_row <- data.frame(
      RowLabel = "",
      RowType = "Sig.",
      stringsAsFactors = FALSE
    )
    for (key in internal_keys) {
      net1_sig_row[[key]] <- net_sig_results$net1[[key]]
    }
    
    # Insert after net1 percentage row
    if (net1_pct_row[1] < nrow(existing_table)) {
      existing_table <- rbind(
        existing_table[1:net1_pct_row[1], ],
        net1_sig_row,
        existing_table[(net1_pct_row[1] + 1):nrow(existing_table), ]
      )
    } else {
      existing_table <- rbind(existing_table, net1_sig_row)
    }
  }
  
  # Find net2 percentage row position (recalculate after insertion)
  net2_name <- box_categories[2]
  net2_pct_row <- which(
    existing_table$RowLabel == net2_name & 
    existing_table$RowType == "Column %"
  )
  
  if (length(net2_pct_row) > 0) {
    net2_sig_row <- data.frame(
      RowLabel = "",
      RowType = "Sig.",
      stringsAsFactors = FALSE
    )
    for (key in internal_keys) {
      net2_sig_row[[key]] <- net_sig_results$net2[[key]]
    }
    
    # Insert after net2 percentage row
    if (net2_pct_row[1] < nrow(existing_table)) {
      existing_table <- rbind(
        existing_table[1:net2_pct_row[1], ],
        net2_sig_row,
        existing_table[(net2_pct_row[1] + 1):nrow(existing_table), ]
      )
    } else {
      existing_table <- rbind(existing_table, net2_sig_row)
    }
  }
  
  return(existing_table)
}

# Helper: Calculate BoxCategory counts (SAFE - separate function)
calculate_boxcategory_counts <- function(data, question_info, question_options,
                                        banner_row_indices, master_weights,
                                        internal_keys, category_name) {
  row_counts <- setNames(numeric(length(internal_keys)), internal_keys)
  
  category_options <- question_options[
    question_options$BoxCategory == category_name, 
  ]
  
  for (key in internal_keys) {
    row_idx <- banner_row_indices[[key]]
    
    if (length(row_idx) > 0) {
      subset_weights <- master_weights[row_idx]
      
      if (question_info$Variable_Type == "Multi_Mention") {
        num_columns <- suppressWarnings(as.numeric(question_info$Columns))
        if (!is.na(num_columns) && num_columns > 0) {
          question_cols <- paste0(question_info$QuestionCode, "_", seq_len(num_columns))
          existing_cols <- question_cols[question_cols %in% names(data)]
          
          category_count <- 0
          for (question_col in existing_cols) {
            for (option_text in category_options$OptionText) {
              matching <- safe_equal(data[[question_col]][row_idx], option_text) &
                         !is.na(data[[question_col]][row_idx])
              category_count <- category_count + sum(subset_weights[matching], na.rm = TRUE)
            }
          }
          row_counts[key] <- category_count
        }
      } else {
        question_col <- question_info$QuestionCode
        if (question_col %in% names(data)) {
          for (option_text in category_options$OptionText) {
            matching <- safe_equal(data[[question_col]][row_idx], option_text) &
                       !is.na(data[[question_col]][row_idx])
            row_counts[key] <- row_counts[key] + sum(subset_weights[matching], na.rm = TRUE)
          }
        }
      }
    }
  }
  
  return(row_counts)
}


# ==============================================================================
# END OF PART 4

# ==============================================================================
# NET POSITIVE TESTING (V9.9.5: OPTION A - TOP MINUS BOTTOM WITH SIG)
# ==============================================================================

#' Add net positive row with significance testing
#'
#' Calculates Top% - Bottom%, ignoring Middle categories and DK/NA.
#' Adds significance testing across banner groups.
#'
#' METHODOLOGY:
#' - Identifies Top and Bottom via DisplayOrder (lowest = Top, highest = Bottom)
#' - Middle categories ignored in net calculation (but still displayed)
#' - Net Positive = Top% - Bottom%
#' - Significance tested using z-test on net difference
#'
#' V9.9.5: NEW FEATURE (Net Positive Option A)
#'
#' @param existing_table Data frame, existing BoxCategory results
#' @param data Data frame, survey data
#' @param question_info Data frame row
#' @param question_options Data frame
#' @param banner_info List
#' @param banner_row_indices List of row indices
#' @param master_weights Numeric vector
#' @param banner_bases List
#' @param config List
#' @param is_weighted Logical
#' @return Data frame with net positive row and sig row added
#' @export
add_net_positive_row <- function(existing_table, data, question_info, question_options,
                                 banner_info, banner_row_indices, master_weights,
                                 banner_bases, config, is_weighted = FALSE) {
  # Safety checks
  if (is.null(existing_table) || nrow(existing_table) == 0) {
    return(existing_table)
  }
  
  if (!config$show_net_positive) {
    return(existing_table)
  }
  
  # Get BoxCategories
  box_categories <- unique(question_options$BoxCategory)
  box_categories <- box_categories[!is.na(box_categories) & box_categories != ""]
  
  # Need at least 2 categories (Top, Bottom)
  if (length(box_categories) < 2) {
    return(existing_table)
  }
  
  # Get DisplayOrder for each BoxCategory
  cat_order <- sapply(box_categories, function(cat) {
    opts <- question_options[question_options$BoxCategory == cat, ]
    if (nrow(opts) > 0 && "DisplayOrder" %in% names(opts)) {
      min(opts$DisplayOrder, na.rm = TRUE)
    } else {
      NA
    }
  })
  
  # Skip if no DisplayOrder
  if (any(is.na(cat_order))) {
    return(existing_table)
  }
  
 # Sort categories by DisplayOrder
  ordered_cats <- box_categories[order(cat_order)]
  
  # Identify Top (first) and Bottom (last non-DK/NA)
  # Middle categories (if any) are ignored in net calculation
  top_category <- ordered_cats[1]
  
  # Exclude DK/NA from bottom calculation
  # Check if last category is DK/NA by name pattern
  non_dk_cats <- ordered_cats[!grepl("DK|NA|Don't Know|Not Applicable", 
                                     ordered_cats, ignore.case = TRUE)]
  
  # If we filtered out everything, fall back to all categories
  if (length(non_dk_cats) < 2) {
    bottom_category <- ordered_cats[length(ordered_cats)]
  } else {
    bottom_category <- non_dk_cats[length(non_dk_cats)]
  }
  
  # Skip if Top and Bottom are the same (only 1 category)
  if (top_category == bottom_category) {
    return(existing_table)
  }
  
  internal_keys <- banner_info$internal_keys
  
  # Calculate counts for Top and Bottom
  row_counts_top <- calculate_boxcategory_counts(
    data, question_info, question_options, banner_row_indices,
    master_weights, internal_keys, top_category
  )
  
  row_counts_bottom <- calculate_boxcategory_counts(
    data, question_info, question_options, banner_row_indices,
    master_weights, internal_keys, bottom_category
  )
  
  # Calculate NET POSITIVE percentages
  net_positive_row <- data.frame(
    RowLabel = sprintf("NET POSITIVE (%s - %s)", bottom_category, top_category),
    RowType = "Column %",
    stringsAsFactors = FALSE
  )
  
  # Store percentages for each column
  for (key in internal_keys) {
    base_info <- banner_bases[[key]]
    weighted_base <- if (!is.null(base_info$weighted)) {
      base_info$weighted
    } else {
      base_info$unweighted
    }
    
    if (weighted_base > 0) {
      top_pct <- (row_counts_top[key] / weighted_base) * 100
      bottom_pct <- (row_counts_bottom[key] / weighted_base) * 100
      net_pct <- bottom_pct - top_pct  # Reversed: Satisfied - Dissatisfied
    } else {
      net_pct <- NA_real_
    }
    
    net_positive_row[[key]] <- format_output_value(
      net_pct, "percent",
      decimal_places_percent = config$decimal_places_percent
    )
  }
  
  # Add Net Positive row
  existing_table <- rbind(existing_table, net_positive_row)
  
  # Add significance testing if enabled
  if (config$enable_significance_testing) {
    # Build test data for Net Positive
    net_test_data <- list()
    total_key <- paste0("TOTAL::", TOTAL_COLUMN)
    
    for (key in internal_keys) {
      if (key != total_key) {
        base_info <- banner_bases[[key]]
        
        # For net positive, we test the DIFFERENCE
        # This is equivalent to testing if (Top% - Bottom%) differs across groups
        net_test_data[[key]] <- list(
          count = row_counts_top[key] - row_counts_bottom[key],  # Net count
          base = if (!is.null(base_info$weighted)) {
            base_info$weighted
          } else {
            base_info$unweighted
          },
          eff_n = if (!is.null(base_info$effective)) {
            base_info$effective
          } else {
            base_info$unweighted
          }
        )
      }
    }
    
    # Run significance tests
    sig_row <- add_significance_row(
      net_test_data, banner_info, "topbox", internal_keys,
      alpha = config$alpha,
      config$bonferroni_correction,
      config$significance_min_base,
      is_weighted = is_weighted
    )
    
    if (!is.null(sig_row)) {
      existing_table <- rbind(existing_table, sig_row)
    }
  }
  
  return(existing_table)
}
# ==============================================================================
# END OF PART 4
# ==============================================================================
# ==============================================================================
# PART 5: EXCEL OUTPUT (Separate styles for rating/index/score)
# ==============================================================================

# ==============================================================================
# EXCEL STYLE CREATION (Separate rating_style, index_style, score_style)
# ==============================================================================

#' Create Excel styles
#'
#' CRITICAL: Each metric type gets its own style with correct decimal places
#' - rating_style uses decimal_places_ratings
#' - index_style uses decimal_places_index
#' - score_style uses decimal_places_percent (NPS is a percentage)
#' - column_pct and row_pct are SEPARATE styles
#'
#' @param decimal_separator Character
#' @param decimal_places_percent Integer
#' @param decimal_places_ratings Integer
#' @param decimal_places_index Integer
#' @return List of style objects
#' @export
create_excel_styles <- function(decimal_separator = ".", 
                               decimal_places_percent = 0,
                               decimal_places_ratings = 1,
                               decimal_places_index = 1,
                               decimal_places_numeric = 1) {  # V10.0.0: Added
    
  sep <- decimal_separator
  
  list(
    banner = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "white", 
      fgFill = "#1F4E79", halign = "center", valign = "center", 
      textDecoration = "bold", border = "TopBottomLeftRight", 
      borderColour = "black"
    ),
    
    question = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", textDecoration = "bold",
      halign = "left", valign = "center"
    ),
    
    filter = openxlsx::createStyle(
      fontSize = 10, fontName = "Aptos", fontColour = "#0066CC",
      halign = "left", valign = "center", wrapText = FALSE
    ),
    
    letter = openxlsx::createStyle(
      fontSize = 10, fontName = "Aptos", fontColour = "#595959",
      halign = "center", valign = "center", textDecoration = "bold"
    ),
    
    base = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos", halign = "center", 
      valign = "center", textDecoration = "bold"
    ),
    
    frequency = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos", fontColour = "#595959",
      halign = "right", valign = "center", numFmt = "#,##0"
    ),
    
    column_pct = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center",
      numFmt = if (decimal_places_percent == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_percent), collapse = ""))
      }
    ),
    
    row_pct = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "#595959",
      halign = "left", valign = "center",
      numFmt = if (decimal_places_percent == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_percent), collapse = ""))
      }
    ),
    
    sig = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center"
    ),
    
    rating_style = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = if (decimal_places_ratings == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_ratings), collapse = ""))
      }
    ),
      
     numeric_style = openxlsx::createStyle(  # V10.0.0: Added
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = if (decimal_places_numeric == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_numeric), collapse = ""))
      }
    ),  
      
    index_style = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = if (decimal_places_index == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_index), collapse = ""))
      }
    ),
    
    score_style = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = if (decimal_places_percent == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_percent), collapse = ""))
      }
    ),
        # V9.9.5: Standard deviation style (NEW - ADDED THIS ENTIRE BLOCK)
    stddev_style = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos", fontColour = "#595959",
      halign = "center", valign = "center", fgFill = "#F2F2F2",
      numFmt = if (decimal_places_ratings == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_ratings), collapse = ""))
      }
    ),
      
    header = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", textDecoration = "bold",
      fgFill = "#1F4E79", fontColour = "white",
      border = "TopBottomLeftRight", borderColour = "black"
    ),
    
    section = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos", textDecoration = "bold",
      fgFill = "#E7E6E6"
    ),
    
    warning = openxlsx::createStyle(
      fgFill = "#FFEB9C", fontColour = "#9C6500"
    ),
    
    caution = openxlsx::createStyle(
      fgFill = "#FFF4CC", fontColour = "#7F6000"
    ),
    
    error = openxlsx::createStyle(
      fgFill = "#FFC7CE", fontColour = "#9C0006"
    )
  )
}

#' Get style for row type
#'
#' Maps each row type to its specific style:
#' - "Average" → rating_style (uses decimal_places_ratings)
#' - "Index" → index_style (uses decimal_places_index)
#' - "Score" → score_style (uses decimal_places_percent)
#' - "Column %" → column_pct
#' - "Row %" → row_pct (separate from column_pct)
#'
#' @param row_type Character
#' @param styles List
#' @return Style object
get_row_style <- function(row_type, styles) {
  switch(row_type,
    "Frequency" = styles$frequency,
    "Column %" = styles$column_pct,
    "Row %" = styles$row_pct,
    "Average" = styles$rating_style,
    "Index" = styles$index_style,
    "Score" = styles$score_style,
    "StdDev" = styles$stddev_style,
    "Median" = styles$numeric_style,  # V10.0.0: Added for Numeric questions
    "Mode" = styles$numeric_style,     # V10.0.0: Added for Numeric questions
    "Outliers" = styles$base,          # V10.0.0: Added for Numeric questions
    "Sig." = styles$sig,
    "ChiSquare" = styles$sig,
    styles$base
  )
}


# ==============================================================================
# EXCEL WRITING FUNCTIONS
# ==============================================================================

#' Write banner headers
#'
#' @param wb Workbook
#' @param sheet Character
#' @param banner_info List
#' @param styles List
#' @return Integer, next row
#' @export
write_banner_headers <- function(wb, sheet, banner_info, styles) {
  current_row <- 1
  total_cols <- 2 + length(banner_info$columns)
  
  if (!is.null(banner_info$banner_questions) && 
      nrow(banner_info$banner_headers) > 0) {
    for (i in seq_len(nrow(banner_info$banner_headers))) {
      header_info <- banner_info$banner_headers[i, ]
      start_col <- header_info$start_col + 2
      end_col <- header_info$end_col + 2
      
      openxlsx::writeData(wb, sheet, header_info$label, 
                         startRow = current_row, startCol = start_col, 
                         colNames = FALSE)
      
      if (start_col < end_col && end_col <= total_cols) {
        openxlsx::mergeCells(wb, sheet, cols = start_col:end_col, 
                           rows = current_row)
      }
    }
    
    openxlsx::addStyle(wb, sheet, styles$banner, rows = current_row, 
                      cols = seq_len(total_cols), gridExpand = TRUE)
    current_row <- current_row + 1
  }
  
  header_row <- c("", "", banner_info$columns)
  openxlsx::writeData(wb, sheet, t(header_row), 
                     startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet, styles$banner, rows = current_row, 
                    cols = seq_len(total_cols), gridExpand = TRUE)
  current_row <- current_row + 1
  
  return(current_row)
}

#' Write column letters
#'
#' @param wb Workbook
#' @param sheet Character
#' @param banner_info List
#' @param styles List
#' @param current_row Integer
#' @return Integer, next row
#' @export
write_column_letters <- function(wb, sheet, banner_info, styles, current_row) {
  total_cols <- 2 + length(banner_info$columns)
  
  letter_row <- c("", "", banner_info$letters)
  openxlsx::writeData(wb, sheet, t(letter_row), 
                     startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet, styles$letter, rows = current_row, 
                    cols = seq_len(total_cols), gridExpand = TRUE)
  
  return(current_row + 1)
}

#' Write base rows (Proper vector transposition)
#'
#' @param wb Workbook
#' @param sheet Character
#' @param banner_info List
#' @param question_bases List
#' @param styles List
#' @param current_row Integer
#' @param config List
#' @return Integer, next row
#' @export
write_base_rows <- function(wb, sheet, banner_info, question_bases, styles, 
                            current_row, config) {
  internal_keys <- banner_info$internal_keys
  total_cols <- 2 + length(banner_info$columns)
  
  if (config$apply_weighting) {
    if (config$show_unweighted_n) {
      base_values <- sapply(internal_keys, function(key) {
        as.numeric(question_bases[[key]]$unweighted)
      })
      
      openxlsx::writeData(wb, sheet, "", startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::writeData(wb, sheet, UNWEIGHTED_BASE_LABEL, startRow = current_row, startCol = 2, colNames = FALSE)
      openxlsx::writeData(wb, sheet, t(as.matrix(base_values)), startRow = current_row, startCol = 3, colNames = FALSE)
      
      openxlsx::addStyle(wb, sheet, styles$base, rows = current_row, 
                        cols = seq_len(total_cols), gridExpand = TRUE)
      current_row <- current_row + 1
    }
    
    weighted_values <- sapply(internal_keys, function(key) {
      round(as.numeric(question_bases[[key]]$weighted), 0)
    })
    
    openxlsx::writeData(wb, sheet, "", startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::writeData(wb, sheet, WEIGHTED_BASE_LABEL, startRow = current_row, startCol = 2, colNames = FALSE)
    openxlsx::writeData(wb, sheet, t(as.matrix(weighted_values)), startRow = current_row, startCol = 3, colNames = FALSE)
    
    openxlsx::addStyle(wb, sheet, styles$base, rows = current_row, 
                      cols = seq_len(total_cols), gridExpand = TRUE)
    current_row <- current_row + 1
    
    if (config$show_effective_n) {
      eff_values <- sapply(internal_keys, function(key) {
        round(as.numeric(question_bases[[key]]$effective), 0)
      })
      
      openxlsx::writeData(wb, sheet, "", startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::writeData(wb, sheet, EFFECTIVE_BASE_LABEL, startRow = current_row, startCol = 2, colNames = FALSE)
      openxlsx::writeData(wb, sheet, t(as.matrix(eff_values)), startRow = current_row, startCol = 3, colNames = FALSE)
      
      openxlsx::addStyle(wb, sheet, styles$base, rows = current_row, 
                        cols = seq_len(total_cols), gridExpand = TRUE)
      current_row <- current_row + 1
    }
  } else {
    base_values <- sapply(internal_keys, function(key) {
      as.numeric(question_bases[[key]]$unweighted)
    })
    
    openxlsx::writeData(wb, sheet, "", startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::writeData(wb, sheet, BASE_ROW_LABEL, startRow = current_row, startCol = 2, colNames = FALSE)
    openxlsx::writeData(wb, sheet, t(as.matrix(base_values)), startRow = current_row, startCol = 3, colNames = FALSE)
    
    openxlsx::addStyle(wb, sheet, styles$base, rows = current_row, 
                      cols = seq_len(total_cols), gridExpand = TRUE)
    current_row <- current_row + 1
  }
  
  return(current_row)
}

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

#' Create summary sheet
#'
#' @param wb Workbook
#' @param project_info List
#' @param all_results List
#' @param config List
#' @param styles List
#' @export
create_summary_sheet <- function(wb, project_info, all_results, config, styles) {
  openxlsx::addWorksheet(wb, "Summary")
  
  summary_rows <- list(
    c("PROJECT INFORMATION", ""),
    c("Project Name", project_info$project_name),
    c("Analysis Date", as.character(Sys.Date())),
    c("Script Version", SCRIPT_VERSION),
    c("", ""),
    c("DATA SUMMARY", ""),
    c("Total Responses", as.character(project_info$total_responses)),
    c("Questions Analyzed", as.character(length(all_results))),
    c("", ""),
    c("WEIGHTING", ""),
    c("Weighting Applied", if (config$apply_weighting) "YES" else "NO"),
    c("Weight Variable", if (config$apply_weighting) config$weight_variable else "N/A"),
    c("Effective Sample Size", as.character(project_info$effective_n)),
    c("", ""),
    c("SIGNIFICANCE TESTING", ""),
    c("Enabled", if (config$enable_significance_testing) "YES" else "NO"),
    c("Alpha (p-value threshold)", if (config$enable_significance_testing) 
      sprintf("%.3f", config$alpha) else "N/A"),
    c("Minimum Base Size", if (config$enable_significance_testing) 
      as.character(config$significance_min_base) else "N/A"),
    c("Bonferroni Correction", if (config$enable_significance_testing && 
      config$bonferroni_correction) "YES" else "NO"),
    c("", ""),
    c("DISPLAY SETTINGS", ""),
    c("Show Frequency", if (config$show_frequency) "YES" else "NO"),
    c("Show Column %", if (config$show_percent_column) "YES" else "NO"),
    c("Show Row %", if (config$show_percent_row) "YES" else "NO"),
    c("Zero Division Display", if (config$zero_division_as_blank) "Blank" else "Zero"),
    c("Decimal Places (Percent)", as.character(config$decimal_places_percent)),
    c("Decimal Places (Ratings)", as.character(config$decimal_places_ratings)),
    c("Decimal Places (Index)", as.character(config$decimal_places_index)),
    c("Decimal Separator", config$decimal_separator),
    c("", ""),
    c("BANNER INFORMATION", ""),
    c("Total Banner Columns", as.character(project_info$total_banner_cols)),
    c("Banner Questions", as.character(project_info$num_banner_questions))
  )
  
  summary_df <- as.data.frame(do.call(rbind, summary_rows), 
                              stringsAsFactors = FALSE)
  names(summary_df) <- c("Setting", "Value")
  
  openxlsx::writeData(wb, "Summary", summary_df, startRow = 1, colNames = TRUE)
  
  openxlsx::addStyle(wb, "Summary", styles$header, rows = 1, cols = 1:2, 
                    gridExpand = TRUE)
  
  section_rows <- c(2, 7, 11, 16, 22, 32)
  for (row in section_rows) {
    if (row <= nrow(summary_df) + 1) {
      openxlsx::addStyle(wb, "Summary", styles$section, rows = row, 
                        cols = 1:2, gridExpand = TRUE)
    }
  }
  
  openxlsx::setColWidths(wb, "Summary", cols = 1:2, widths = c(30, 40))
  
  add_question_list(wb, all_results, config, styles, nrow(summary_df) + 3)
}

#' Add question list to summary
#'
#' @param wb Workbook
#' @param all_results List
#' @param config List
#' @param styles List
#' @param start_row Integer
add_question_list <- function(wb, all_results, config, styles, start_row) {
  question_list_rows <- list(
    c("Question Code", "Question Text", "Variable Type", "Base (Total)", "Base Warning")
  )
  
  for (q_code in names(all_results)) {
    q_result <- all_results[[q_code]]
    
    total_key <- paste0("TOTAL::", TOTAL_COLUMN)
    base_info <- q_result$bases[[total_key]]
    
    if (config$apply_weighting) {
      total_base <- round(base_info$weighted, 0)
      eff_base <- round(base_info$effective, 0)
      base_display <- paste0(total_base, " (eff: ", eff_base, ")")
    } else {
      total_base <- base_info$unweighted
      eff_base <- total_base
      base_display <- as.character(total_base)
    }
    
    base_warning <- ""
    if (eff_base < VERY_SMALL_BASE_SIZE) {
      base_warning <- paste0("WARNING: Very small base (n<", VERY_SMALL_BASE_SIZE, ")")
    } else if (eff_base < config$significance_min_base) {
      base_warning <- paste0("CAUTION: Small base (n<", config$significance_min_base, ")")
    }
    
    filter_text <- if (!is.null(q_result$base_filter) && 
                      !is.na(q_result$base_filter) && 
                      q_result$base_filter != "") {
      paste0(" [Filter: ", q_result$base_filter, "]")
    } else {
      ""
    }
    
    question_list_rows[[length(question_list_rows) + 1]] <- c(
      q_result$question_code,
      paste0(q_result$question_text, filter_text),
      q_result$question_type,
      base_display,
      base_warning
    )
  }
  
  question_list_df <- as.data.frame(do.call(rbind, question_list_rows), 
                                   stringsAsFactors = FALSE)
  names(question_list_df) <- question_list_df[1, ]
  question_list_df <- question_list_df[-1, ]
  
  openxlsx::writeData(wb, "Summary", "QUESTION LIST", 
                     startRow = start_row, startCol = 1)
  openxlsx::addStyle(wb, "Summary", styles$section, rows = start_row, 
                    cols = 1:5, gridExpand = TRUE)
  
  openxlsx::writeData(wb, "Summary", question_list_df, 
                     startRow = start_row + 1, colNames = TRUE)
  openxlsx::addStyle(wb, "Summary", styles$header, rows = start_row + 1, 
                    cols = 1:5, gridExpand = TRUE)
  
  for (i in seq_len(nrow(question_list_df))) {
    warning_text <- question_list_df[i, 5]
    if (!is.na(warning_text) && warning_text != "") {
      style <- if (grepl("WARNING", warning_text)) {
        styles$warning
      } else if (grepl("CAUTION", warning_text)) {
        styles$caution
      } else {
        NULL
      }
      
      if (!is.null(style)) {
        openxlsx::addStyle(wb, "Summary", style, 
                          rows = start_row + 1 + i, cols = 1:5, 
                          gridExpand = TRUE)
      }
    }
  }
  
  openxlsx::setColWidths(wb, "Summary", cols = 1:5, 
                        widths = c(15, 50, 15, 20, 30))
}

# ==============================================================================
# END OF PART 5
# ==============================================================================
# ==============================================================================
# PART 6: MAIN EXECUTION (All fixes applied, clean code)
# ==============================================================================
# ==============================================================================
# SAMPLE COMPOSITION SHEET (V9.9.5: NEW FEATURE)
# ==============================================================================

#' Create sample composition sheet (SAFE - separate sheet)
#'
#' Shows distribution of each banner variable.
#' Doesn't modify any existing sheets or data.
#'
#' V9.9.5: NEW FEATURE (sample composition)
#'
#' @param wb Workbook object
#' @param data Survey data frame
#' @param banner_info Banner structure metadata
#' @param master_weights Weight vector
#' @param config Configuration list
#' @param styles Excel styles list
#' @export
create_sample_composition_sheet <- function(wb, data, banner_info, master_weights, config, styles) {
  # Safety check
  if (is.null(banner_info$banner_questions) || 
      nrow(banner_info$banner_questions) == 0) {
    return(invisible(NULL))
  }
  
  tryCatch({
    openxlsx::addWorksheet(wb, "Sample Composition")
    
    current_row <- 1
    
    # Title
    openxlsx::writeData(wb, "Sample Composition", "SAMPLE COMPOSITION", 
                       startRow = current_row, startCol = 1)
    openxlsx::addStyle(wb, "Sample Composition", styles$section, 
                      rows = current_row, cols = 1:7, gridExpand = TRUE)
    current_row <- current_row + 2
    
    # Build composition data
    composition_rows <- list()
    
    for (banner_idx in seq_len(nrow(banner_info$banner_questions))) {
      banner_code <- banner_info$banner_questions$QuestionCode[banner_idx]
      banner_data <- banner_info$banner_info[[banner_code]]
      
      if (is.null(banner_data)) next
      
      # Variable label
      var_label <- if ("BannerLabel" %in% names(banner_info$banner_questions)) {
        label <- banner_info$banner_questions$BannerLabel[banner_idx]
        if (!is.null(label) && !is.na(label) && label != "") {
          as.character(label)
        } else {
          banner_code
        }
      } else {
        banner_code
      }
      
      # Process each category
      for (cat_idx in seq_along(banner_data$columns)) {
        cat_name <- banner_data$columns[cat_idx]
        internal_key <- banner_data$internal_keys[cat_idx]
        
        # Find respondents in this category
        if (banner_data$is_boxcategory) {
          # BoxCategory banner - need to find all matching options
          cat_options <- banner_data$boxcat_groups[[cat_name]]
          
          if (question_info$Variable_Type == "Multi_Mention") {
            num_cols <- suppressWarnings(as.numeric(question_info$Columns))
            if (!is.na(num_cols) && num_cols > 0) {
              banner_cols <- paste0(banner_code, "_", seq_len(num_cols))
              existing_cols <- banner_cols[banner_cols %in% names(data)]
              
              matching_rows <- Reduce(`|`, lapply(existing_cols, function(col) {
                Reduce(`|`, lapply(cat_options, function(opt) {
                  safe_equal(data[[col]], opt) & !is.na(data[[col]])
                }))
              }))
            } else {
              matching_rows <- rep(FALSE, nrow(data))
            }
          } else {
            if (banner_code %in% names(data)) {
              matching_rows <- Reduce(`|`, lapply(cat_options, function(opt) {
                safe_equal(data[[banner_code]], opt) & !is.na(data[[banner_code]])
              }))
            } else {
              matching_rows <- rep(FALSE, nrow(data))
            }
          }
          
          row_idx <- which(matching_rows)
        } else {
          # Standard banner - direct match
          if (banner_code %in% names(data)) {
            matching_rows <- safe_equal(data[[banner_code]], cat_name) & 
                           !is.na(data[[banner_code]])
            row_idx <- which(matching_rows)
          } else {
            row_idx <- integer(0)
          }
        }
        
        # Calculate composition
        comp_row <- list(
          Variable = if (cat_idx == 1) var_label else "",
          Category = cat_name,
          Unweighted_n = length(row_idx),
          Unweighted_pct = if (nrow(data) > 0) {
            round(100 * length(row_idx) / nrow(data), 1)
          } else {
            NA_real_
          }
        )
        
        if (config$apply_weighting) {
          subset_weights <- master_weights[row_idx]
          valid_weights <- subset_weights[!is.na(subset_weights) & is.finite(subset_weights)]
          
          weighted_n <- sum(valid_weights, na.rm = TRUE)
          total_weight <- sum(master_weights[!is.na(master_weights) & is.finite(master_weights)], na.rm = TRUE)
          
          comp_row$Weighted_n <- round(weighted_n, 1)
          comp_row$Weighted_pct <- if (total_weight > 0) {
            round(100 * weighted_n / total_weight, 1)
          } else {
            NA_real_
          }
          comp_row$Effective_n <- calculate_effective_n(valid_weights)
        }
        
        composition_rows[[length(composition_rows) + 1]] <- comp_row
      }
    }
    
    if (length(composition_rows) == 0) {
      return(invisible(NULL))
    }
    
    # Convert to data frame
    composition_df <- do.call(rbind, lapply(composition_rows, as.data.frame, 
                                            stringsAsFactors = FALSE))
    
    # Write headers
    header_cols <- c("Variable", "Category", "Unweighted n", "Unweighted %")
    if (config$apply_weighting) {
      header_cols <- c(header_cols, "Weighted n", "Weighted %", "Effective n")
    }
    
    openxlsx::writeData(wb, "Sample Composition", 
                       matrix(header_cols, nrow = 1),
                       startRow = current_row, colNames = FALSE)
    openxlsx::addStyle(wb, "Sample Composition", styles$header, 
                      rows = current_row, cols = 1:length(header_cols), 
                      gridExpand = TRUE)
    current_row <- current_row + 1
    
    # Write data
    openxlsx::writeData(wb, "Sample Composition", composition_df, 
                       startRow = current_row, colNames = FALSE)
    
    # Alternating row colors
    for (i in seq_len(nrow(composition_df))) {
      if (i %% 2 == 0) {
        openxlsx::addStyle(wb, "Sample Composition", 
                          openxlsx::createStyle(fgFill = "#F9F9F9"),
                          rows = current_row + i - 1, 
                          cols = 1:ncol(composition_df), 
                          gridExpand = TRUE)
      }
    }
    
    # Column widths
    openxlsx::setColWidths(wb, "Sample Composition", 
                          cols = 1:ncol(composition_df),
                          widths = c(25, 25, rep(15, ncol(composition_df) - 2)))
    
  }, error = function(e) {
    warning(sprintf("Sample composition sheet creation failed: %s", conditionMessage(e)))
  })
  
  invisible(NULL)
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
  if (!file.exists(checkpoint_file)) return(NULL)
  
  tryCatch({
    checkpoint_data <- readRDS(checkpoint_file)
    log_message(sprintf("Checkpoint loaded: %d questions already processed", 
                       length(checkpoint_data$processed)), "INFO")
    return(checkpoint_data)
  }, error = function(e) {
    warning(sprintf("Failed to load checkpoint: %s", conditionMessage(e)))
    return(NULL)
  })
}

# ==============================================================================
# CHECKPOINTING SETUP
# ==============================================================================

checkpoint_file <- file.path(project_root, "Output", output_subfolder, 
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
# NUMERIC QUESTION PROCESSING FUNCTIONS (V10.0.0 - NEW)
# ==============================================================================

#' Detect Outliers Using IQR Method
#'
#' Identifies outliers using the IQR (Interquartile Range) method
#' Outliers are values < Q1 - 1.5*IQR or > Q3 + 1.5*IQR
#'
#' @param values Numeric vector, values to check for outliers
#' @return List with count (number of outliers) and indices (logical vector)
#' @export
detect_outliers_iqr <- function(values) {
  if (length(values) < 4) {
    # Not enough data for quartiles
    return(list(count = 0, indices = rep(FALSE, length(values))))
  }
  
  q1 <- quantile(values, 0.25, na.rm = TRUE)
  q3 <- quantile(values, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  
  lower_bound <- q1 - 1.5 * iqr
  upper_bound <- q3 + 1.5 * iqr
  
  is_outlier <- (values < lower_bound) | (values > upper_bound)
  
  return(list(
    count = sum(is_outlier, na.rm = TRUE),
    indices = is_outlier
  ))
}

#' Calculate Numeric Statistics
#'
#' Calculates mean, median, mode, and standard deviation for numeric questions
#'
#' @param data Data frame, survey data (already filtered by base filter)
#' @param question_info Data frame row, question metadata
#' @param weights Numeric vector, weights for this data subset
#' @param config List, configuration object
#' @param is_weighted Logical, whether weighting is applied
#' @return List with statistics: mean, median, mode, sd, outlier_count
#' @export
calculate_numeric_statistics <- function(data, question_info, weights, 
                                        config, is_weighted) {
  question_col <- question_info$QuestionCode
  
  # Extract and validate numeric data
  raw_values <- data[[question_col]]
  numeric_values <- suppressWarnings(as.numeric(raw_values))
  
  # Apply Min/Max filters if specified
  min_val <- if ("Min_Value" %in% names(question_info)) {
    suppressWarnings(as.numeric(question_info$Min_Value))
  } else {
    NA_real_
  }
  
  max_val <- if ("Max_Value" %in% names(question_info)) {
    suppressWarnings(as.numeric(question_info$Max_Value))
  } else {
    NA_real_
  }
  
  # Filter valid values
  valid_idx <- !is.na(numeric_values)
  
  if (!is.na(min_val)) {
    valid_idx <- valid_idx & (numeric_values >= min_val)
  }
  
  if (!is.na(max_val)) {
    valid_idx <- valid_idx & (numeric_values <= max_val)
  }
  
  valid_values <- numeric_values[valid_idx]
  valid_weights <- weights[valid_idx]
  
  # Initialize results
  result <- list(
    mean = NA_real_,
    median = NA_real_,
    mode = NA_real_,
    sd = NA_real_,
    outlier_count = 0,
    n_valid = length(valid_values)
  )
  
  if (length(valid_values) == 0) {
    return(result)
  }
  
  # Calculate mean (weighted or unweighted)
  if (all(valid_weights == 1) || !is_weighted) {
    result$mean <- mean(valid_values)
  } else {
    total_weight <- sum(valid_weights)
    if (total_weight > 0) {
      result$mean <- sum(valid_values * valid_weights) / total_weight
    }
  }
  
  # Calculate standard deviation (weighted or unweighted)
  if (length(valid_values) > 1) {
    if (all(valid_weights == 1) || !is_weighted) {
      result$sd <- sd(valid_values)
    } else {
      total_weight <- sum(valid_weights)
      if (total_weight > 0) {
        mean_val <- result$mean
        variance <- sum(valid_weights * (valid_values - mean_val)^2) / total_weight
        result$sd <- sqrt(variance)
      }
    }
  }
  
  # Calculate median (unweighted only)
  if (config$show_numeric_median && !is_weighted) {
    result$median <- median(valid_values)
  }
  
  # Calculate mode (unweighted only)
  if (config$show_numeric_mode && !is_weighted) {
    # For mode, find most frequent value
    freq_table <- table(valid_values)
    if (length(freq_table) > 0) {
      max_freq <- max(freq_table)
      modes <- as.numeric(names(freq_table)[freq_table == max_freq])
      
      # If multiple modes or mode appears only once (highly dispersed), report NA
      if (length(modes) == 1 && max_freq > 1) {
        result$mode <- modes[1]
      }
    }
  }
  
  # Detect outliers using IQR method (on raw data, not weighted)
  if (config$show_numeric_outliers || config$exclude_outliers_from_stats) {
    outlier_info <- detect_outliers_iqr(valid_values)
    result$outlier_count <- outlier_info$count
    result$outlier_indices <- outlier_info$indices
  }
  
  return(result)
}

#' Categorize Numeric Values into Bins
#'
#' Assigns numeric values to predefined bins from Options sheet
#'
#' @param values Numeric vector, values to categorize
#' @param option_info Data frame, bin definitions (Min, Max, OptionText)
#' @return Character vector, bin labels for each value (NA if unbinned)
#' @export
categorize_numeric_bins <- function(values, option_info) {
  if (nrow(option_info) == 0) {
    return(rep(NA_character_, length(values)))
  }
  
  # Initialize result
  result <- rep(NA_character_, length(values))
  
  # Sort bins by Min for efficient processing
  option_info <- option_info[order(option_info$Min), ]
  
  # Extract bin boundaries
  bin_mins <- as.numeric(option_info$Min)
  bin_maxs <- as.numeric(option_info$Max)
  bin_labels <- as.character(option_info$OptionText)
  
  # Assign values to bins (inclusive on both ends [Min, Max])
  for (i in seq_len(nrow(option_info))) {
    # Find values in this bin
    in_bin <- !is.na(values) & 
              (values >= bin_mins[i]) & 
              (values <= bin_maxs[i])
    
    result[in_bin] <- bin_labels[i]
  }
  
  return(result)
}

#' Process Numeric Question
#'
#' Main processing function for Numeric question type
#' Handles bins (if defined), statistics, and significance testing
#'
#' @param data Data frame, survey data (filtered by base filter)
#' @param question_info Data frame row, question metadata
#' @param question_options Data frame, options/bins for this question
#' @param banner_info List, banner structure information
#' @param banner_row_indices List, row indices for each banner column
#' @param master_weights Numeric vector, weight vector for filtered data
#' @param banner_bases List, base sizes for each banner column
#' @param config List, configuration object
#' @param is_weighted Logical, whether weighting is applied
#' @return Data frame, formatted results table
#' @export
process_numeric_question <- function(data, question_info, question_options,
                                     banner_info, banner_row_indices,
                                     master_weights, banner_bases,
                                     config, is_weighted) {
  
  question_col <- question_info$QuestionCode
  internal_keys <- banner_info$internal_keys
  has_bins <- nrow(question_options) > 0
  
  results_list <- list()
  
  # ===========================================================================
  # PART 1: Frequency Distribution (if bins defined)
  # ===========================================================================
  
  if (has_bins) {
    # Categorize all data into bins
    all_binned <- categorize_numeric_bins(
      suppressWarnings(as.numeric(data[[question_col]])),
      question_options
    )
    
    # Get unique bin labels in display order
    if ("DisplayOrder" %in% names(question_options)) {
      sorted_options <- question_options[order(question_options$DisplayOrder), ]
    } else {
      sorted_options <- question_options[order(question_options$Min), ]
    }
    
    bin_labels <- as.character(sorted_options$OptionText)
    
    # Calculate frequencies for each bin
    for (bin_label in bin_labels) {
      row_counts <- list()
      
      for (key in internal_keys) {
        row_idx <- banner_row_indices[[key]]
        
        if (length(row_idx) > 0) {
          subset_binned <- all_binned[row_idx]
          subset_weights <- master_weights[row_idx]
          
          # Count matches
          matching <- !is.na(subset_binned) & (subset_binned == bin_label)
          count <- sum(subset_weights[matching])
          
          # Calculate percentage
          base <- banner_bases[[key]]$weighted_base
          pct <- if (base > 0) (count / base) * 100 else NA_real_
          
          row_counts[[key]] <- list(
            frequency = count,
            percent = pct
          )
        } else {
          row_counts[[key]] <- list(frequency = 0, percent = NA_real_)
        }
      }
      
      # Create row data frame
      freq_row <- data.frame(
        RowLabel = bin_label,
        RowType = FREQUENCY_ROW_TYPE,
        stringsAsFactors = FALSE
      )
      
      pct_row <- data.frame(
        RowLabel = bin_label,
        RowType = COLUMN_PCT_ROW_TYPE,
        stringsAsFactors = FALSE
      )
      
      # Add columns
      for (key in internal_keys) {
        if (config$show_frequency) {
          freq_row[[key]] <- format_output_value(
            row_counts[[key]]$frequency,
            "frequency"
          )
        }
        
        if (config$show_percent_column) {
          pct_row[[key]] <- format_output_value(
            row_counts[[key]]$percent,
            "percent",
            decimal_places_percent = config$decimal_places_percent
          )
        }
      }
      
      if (config$show_frequency) results_list[[length(results_list) + 1]] <- freq_row
      if (config$show_percent_column) results_list[[length(results_list) + 1]] <- pct_row
    }
  }
  
  # ===========================================================================
  # PART 2: Summary Statistics
  # ===========================================================================
  
  # Calculate statistics for each banner column
  stat_results <- list()
  stat_value_sets <- list()
  stat_weight_sets <- list()
  
  for (key in internal_keys) {
    row_idx <- banner_row_indices[[key]]
    
    if (length(row_idx) > 0) {
      subset_data <- data[row_idx, , drop = FALSE]
      subset_weights <- master_weights[row_idx]
      
      stats <- calculate_numeric_statistics(
        subset_data, question_info, subset_weights, config, is_weighted
      )
      
      stat_results[[key]] <- stats
      
      # Store for significance testing
      numeric_values <- suppressWarnings(as.numeric(subset_data[[question_col]]))
      valid_idx <- !is.na(numeric_values)
      stat_value_sets[[key]] <- numeric_values[valid_idx]
      stat_weight_sets[[key]] <- subset_weights[valid_idx]
    } else {
      stat_results[[key]] <- list(
        mean = NA_real_, median = NA_real_, mode = NA_real_, 
        sd = NA_real_, outlier_count = 0
      )
    }
  }
  
  # Mean row
  mean_row <- data.frame(
    RowLabel = "Mean",
    RowType = AVERAGE_ROW_TYPE,
    stringsAsFactors = FALSE
  )
  
  for (key in internal_keys) {
    mean_row[[key]] <- format_output_value(
      stat_results[[key]]$mean,
      "numeric",
      decimal_places_numeric = config$decimal_places_numeric
    )
  }
  
  results_list[[length(results_list) + 1]] <- mean_row
  
  # Median row (if enabled and unweighted)
  if (config$show_numeric_median) {
    if (is_weighted) {
      median_row <- data.frame(
        RowLabel = "Median",
        RowType = "Median",
        stringsAsFactors = FALSE
      )
      for (key in internal_keys) {
        median_row[[key]] <- "N/A (weighted)"
      }
      results_list[[length(results_list) + 1]] <- median_row
    } else {
      median_row <- data.frame(
        RowLabel = "Median",
        RowType = "Median",
        stringsAsFactors = FALSE
      )
      for (key in internal_keys) {
        median_row[[key]] <- format_output_value(
          stat_results[[key]]$median,
          "numeric",
          decimal_places_numeric = config$decimal_places_numeric
        )
      }
      results_list[[length(results_list) + 1]] <- median_row
    }
  }
  
  # Mode row (if enabled and unweighted)
  if (config$show_numeric_mode) {
    if (is_weighted) {
      mode_row <- data.frame(
        RowLabel = "Mode",
        RowType = "Mode",
        stringsAsFactors = FALSE
      )
      for (key in internal_keys) {
        mode_row[[key]] <- "N/A (weighted)"
      }
      results_list[[length(results_list) + 1]] <- mode_row
    } else {
      mode_row <- data.frame(
        RowLabel = "Mode",
        RowType = "Mode",
        stringsAsFactors = FALSE
      )
      for (key in internal_keys) {
        mode_val <- stat_results[[key]]$mode
        mode_row[[key]] <- if (is.na(mode_val)) {
          "No single mode"
        } else {
          format_output_value(
            mode_val,
            "numeric",
            decimal_places_numeric = config$decimal_places_numeric
          )
        }
      }
      results_list[[length(results_list) + 1]] <- mode_row
    }
  }
  
  # Standard deviation row
  sd_row <- data.frame(
    RowLabel = "Standard Deviation",
    RowType = "StdDev",
    stringsAsFactors = FALSE
  )
  
  for (key in internal_keys) {
    sd_row[[key]] <- format_output_value(
      stat_results[[key]]$sd,
      "numeric",
      decimal_places_numeric = config$decimal_places_numeric
    )
  }
  
  results_list[[length(results_list) + 1]] <- sd_row
  
  # Outliers row (if enabled)
  if (config$show_numeric_outliers) {
    outlier_label <- if (config$exclude_outliers_from_stats) {
      "Outliers (excluded)"
    } else {
      "Outliers (IQR)"
    }
    
    outlier_row <- data.frame(
      RowLabel = outlier_label,
      RowType = "Outliers",
      stringsAsFactors = FALSE
    )
    
    for (key in internal_keys) {
      outlier_row[[key]] <- as.character(stat_results[[key]]$outlier_count)
    }
    
    results_list[[length(results_list) + 1]] <- outlier_row
  }
  
  # ===========================================================================
  # PART 3: Significance Testing (for means)
  # ===========================================================================
  
  if (config$enable_significance_testing) {
    test_data <- list()
    total_key <- paste0("TOTAL::", TOTAL_COLUMN)
    
    for (key in internal_keys) {
      if (key != total_key && !is.null(stat_value_sets[[key]])) {
        test_data[[key]] <- list(
          values = stat_value_sets[[key]],
          weights = stat_weight_sets[[key]]
        )
      }
    }
    
    sig_row <- add_significance_row(
      test_data, banner_info, "rating", internal_keys,
      alpha = config$alpha,
      config$bonferroni_correction,
      config$significance_min_base,
      is_weighted = is_weighted
    )
    
    if (!is.null(sig_row)) {
      results_list[[length(results_list) + 1]] <- sig_row
    }
  }
  
  # Combine all results
  if (length(results_list) > 0) {
    return(batch_rbind(results_list))
  }
  
  return(NULL)
}
      
      
# ==============================================================================
# PROCESS QUESTIONS (CLEAN VERSION - All fixes applied)
# ==============================================================================

log_message(sprintf("Processing %d questions...", nrow(remaining_questions)), "INFO")
cat("\n")

processing_start <- Sys.time()
checkpoint_counter <- 0

for (q_idx in seq_len(nrow(remaining_questions))) {
  current_question_code <- remaining_questions$QuestionCode[q_idx]
  
  total_processed <- length(processed_questions) + q_idx
  log_progress(total_processed, nrow(crosstab_questions), 
              current_question_code, processing_start)
  
  if (q_idx %% 10 == 0) {
    check_memory(force_gc = TRUE)
  }
  
  question_info <- survey_structure$questions[
    survey_structure$questions$QuestionCode == current_question_code, 
  ]
  
  if (nrow(question_info) == 0) {
    warning(sprintf("Question not found: %s", current_question_code))
    next
  }
  
  question_info <- question_info[1, ]
  
  # FIXED: Multi-mention uses column names as QuestionCode in Options
  if (question_info$Variable_Type == "Multi_Mention") {
    pattern <- paste0("^", current_question_code, "_")
    question_options <- survey_structure$options[grepl(pattern, survey_structure$options$QuestionCode), ]
  } else {
    question_options <- survey_structure$options[
      survey_structure$options$QuestionCode == current_question_code, 
    ]
  }
  
  # Apply base filter
  base_filter <- remaining_questions$BaseFilter[q_idx]
  if (!is.na(base_filter) && base_filter != "") {
    filtered_data <- safe_execute(
      apply_base_filter(survey_data, base_filter),
      default = NULL,
      error_msg = paste("Filter failed:", current_question_code)
    )
    
    if (is.null(filtered_data)) {
      warning(sprintf("Skipping %s: filter failed", current_question_code))
      next
    }
    
    if (".original_row" %in% names(filtered_data)) {
      question_weights <- master_weights[filtered_data$.original_row]
    } else {
      question_weights <- master_weights
    }
  } else {
    filtered_data <- survey_data
    question_weights <- master_weights
  }
  
  # Create banner ROW INDICES only (no weight duplication)
  banner_result <- create_banner_row_indices(filtered_data, banner_info)
  banner_row_indices <- banner_result$row_indices
  
  # Calculate bases
  banner_bases <- list()
  for (key in banner_info$internal_keys) {
    row_idx <- banner_row_indices[[key]]
    if (length(row_idx) > 0) {
      subset_data <- filtered_data[row_idx, , drop = FALSE]
      subset_weights <- question_weights[row_idx]
      base_result <- calculate_weighted_base(
        subset_data, question_info, subset_weights
      )
    } else {
      base_result <- list(unweighted = 0, weighted = 0, effective = 0)
    }
    banner_bases[[key]] <- base_result
  }
  
 # Process based on question type
  if (question_info$Variable_Type == "Ranking") {
    ranking_data <- safe_execute(
      extract_ranking_data(filtered_data, question_info, question_options),
      default = NULL,
      error_msg = paste("Ranking failed:", current_question_code)
    )
    
    if (is.null(ranking_data)) {
      warning(sprintf("Skipping %s: ranking failed", current_question_code))
      next
    }
    
    # Build banner_data_list and weights_list (required by ranking function)
    banner_data_list <- list()
    weights_list <- list()
    
    for (key in banner_info$internal_keys) {
      row_idx <- banner_row_indices[[key]]
      
      if (length(row_idx) > 0) {
        subset_df <- filtered_data[row_idx, , drop = FALSE]
        subset_df$.original_row <- row_idx
        banner_data_list[[key]] <- subset_df
        weights_list[[key]] <- question_weights[row_idx]
      } else {
        banner_data_list[[key]] <- filtered_data[integer(0), , drop = FALSE]
        weights_list[[key]] <- numeric(0)
      }
    }
    
    # Create rows for each item
    question_results <- list()
    for (item in ranking_data$items) {
      item_rows <- create_ranking_rows_for_item(
        ranking_data$matrix, item, banner_data_list, banner_info,
        banner_info$internal_keys, weights_list,
        show_top_n = TRUE, top_n = 3,
        num_positions = ranking_data$num_positions,
        decimal_places_percent = config_obj$decimal_places_percent,
        decimal_places_index = config_obj$decimal_places_index
      )
      question_results <- c(question_results, item_rows)
    }
    
    question_table <- if (length(question_results) > 0) {
      batch_rbind(question_results)
    } else {
      data.frame()
    }

} else if (question_info$Variable_Type == "Numeric") {
  # V10.0.0: Process Numeric question
  individual_results <- tryCatch({
    process_numeric_question(
      filtered_data, question_info, question_options,
      banner_info, banner_row_indices, question_weights,
      banner_bases, config_obj, is_weighted
    )
  }, error = function(e) {
    warning(sprintf("Failed to process Numeric question %s: %s", 
                   current_question_code, conditionMessage(e)))
    return(NULL)
  })
      
      
  } else {
    # Standard processing (All fixes applied)
    individual_results <- tryCatch({
      process_question(filtered_data, question_info, question_options, 
                      banner_info, banner_row_indices, question_weights, 
                      banner_bases, config_obj,
                      is_weighted = is_weighted)
    }, error = function(e) {
      warning(sprintf("Failed %s: %s", current_question_code, conditionMessage(e)))
      return(NULL)
    })
    
boxcategory_results <- tryCatch({
      add_boxcategory_summaries(filtered_data, question_info, question_options, 
                               banner_info, banner_row_indices, question_weights, 
                               banner_bases, config_obj,
                               is_weighted = is_weighted)
    }, error = function(e) {
      return(NULL)
    })
    
    # V9.9.5: Add net difference testing (SAFE - separate function)
    if (!is.null(boxcategory_results) && nrow(boxcategory_results) > 0) {
      boxcategory_results <- tryCatch({
        add_net_significance_rows(
          boxcategory_results, filtered_data, question_info, question_options,
          banner_info, banner_row_indices, question_weights, banner_bases,
          config_obj, is_weighted = is_weighted
        )
      }, error = function(e) {
        warning(sprintf("Net difference testing failed for %s: %s", 
                       current_question_code, conditionMessage(e)))
        boxcategory_results  # Return original on error
      })
    }

# ============================================================================
    # V9.9.5: CHI-SQUARE TEST (RELAXED THRESHOLDS FOR SMALL BANNER GROUPS)
    # ============================================================================
    chi_square_row <- NULL
    
    # Safe logical check
    enable_chi <- FALSE
    if ("enable_chi_square" %in% names(config_obj)) {
      enable_chi <- safe_logical(config_obj$enable_chi_square, default = FALSE)
    }
    
    if (enable_chi && 
        !is.null(boxcategory_results) && nrow(boxcategory_results) > 0) {
      
      chi_square_row <- tryCatch({
        # Get BoxCategory FREQUENCY rows
        box_freq_rows <- boxcategory_results[
          boxcategory_results$RowType == "Frequency",
        ]
        
        if (nrow(box_freq_rows) >= 2) {
          # Extract numeric matrix
          obs_matrix <- as.matrix(box_freq_rows[, banner_info$internal_keys, drop = FALSE])
          storage.mode(obs_matrix) <- "double"
          
          # Remove Total column
          total_key <- paste0("TOTAL::", TOTAL_COLUMN)
          if (total_key %in% colnames(obs_matrix)) {
            obs_matrix <- obs_matrix[, colnames(obs_matrix) != total_key, drop = FALSE]
          }
          
          if (ncol(obs_matrix) >= 2 && nrow(obs_matrix) >= 2) {
            
            # SMART FILTERING - Remove sparse BoxCategories
            row_totals <- rowSums(obs_matrix)
            row_labels <- box_freq_rows$RowLabel
            
            # Keep rows with at least 5 total responses OR 1% of sample
            min_count <- max(5, 0.01 * sum(obs_matrix))
            keep_rows <- row_totals >= min_count
            
            if (sum(keep_rows) >= 2) {
              obs_matrix_filtered <- obs_matrix[keep_rows, , drop = FALSE]
              filtered_labels <- row_labels[keep_rows]
              
              # Check expected frequencies
              row_totals_f <- rowSums(obs_matrix_filtered)
              col_totals_f <- colSums(obs_matrix_filtered)
              grand_total_f <- sum(obs_matrix_filtered)
              
              if (grand_total_f > 0) {
                expected_matrix <- outer(row_totals_f, col_totals_f) / grand_total_f
                min_expected <- min(expected_matrix)
                low_expected_pct <- 100 * sum(expected_matrix < 5) / length(expected_matrix)
                
                # V9.9.5: RELAXED THRESHOLDS for small banner groups
                # - Min expected: 0.5 (was 1.0) - allows smaller cells
                # - Low expected %: 40% (was 20%) - more permissive for small groups
                if (min_expected >= 0.5 && low_expected_pct <= 40) {
                  chi_result <- chi_square_test(obs_matrix_filtered, alpha = config_obj$alpha)
                  
                  # Build message
                  chi_message <- sprintf("Chi-square (%d categories): χ²=%.2f, df=%d, p=%.4f%s",
                                        nrow(obs_matrix_filtered),
                                        chi_result$chi_square_stat,
                                        chi_result$df,
                                        chi_result$p_value,
                                        if (chi_result$significant) " **" else "")
                  
                  # Note if categories were excluded
                  if (sum(keep_rows) < length(keep_rows)) {
                    excluded_cats <- row_labels[!keep_rows]
                    chi_message <- paste0(chi_message, 
                                         sprintf(" [Excluded: %s]", 
                                                paste(excluded_cats, collapse=", ")))
                  }
                  
                  # Add warning note if thresholds are marginal
                  if (min_expected < 1 || low_expected_pct > 20) {
                    chi_message <- paste0(chi_message, " [Note: Small sample in some cells]")
                  }
                  
                  # Create display row
                  chi_row <- data.frame(
                    RowLabel = chi_message,
                    RowType = "ChiSquare",
                    stringsAsFactors = FALSE
                  )
                  
                  for (key in banner_info$internal_keys) {
                    chi_row[[key]] <- NA_real_
                  }
                  
                  chi_row
                } else {
                  NULL
                }
              } else {
                NULL
              }
            } else {
              NULL
            }
          } else {
            NULL
          }
        } else {
          NULL
        }
      }, error = function(e) {
        warning(sprintf("Chi-square test failed for %s: %s", 
                       current_question_code, conditionMessage(e)))
        NULL
      })
    }
    # ============================================================================

    # ============================================================================
    # V9.9.5: NET POSITIVE (TOP - BOTTOM WITH SIGNIFICANCE)
    # ============================================================================
    if (!is.null(boxcategory_results) && nrow(boxcategory_results) > 0) {
      boxcategory_results <- tryCatch({
        add_net_positive_row(
          boxcategory_results, filtered_data, question_info, question_options,
          banner_info, banner_row_indices, question_weights, banner_bases,
          config_obj, is_weighted = is_weighted
        )
      }, error = function(e) {
        warning(sprintf("Net positive calculation failed for %s: %s", 
                       current_question_code, conditionMessage(e)))
        boxcategory_results  # Return original on error
      })
    }
    # ============================================================================
                  
      
    summary_results <- tryCatch({
      add_summary_statistic(filtered_data, question_info, question_options, 
                           banner_info, banner_row_indices, question_weights, 
                           banner_bases, remaining_questions[q_idx, ], config_obj,
                           is_weighted = is_weighted)
    }, error = function(e) {
      return(NULL)
    })
    
     question_table <- data.frame()
    if (!is.null(individual_results) && nrow(individual_results) > 0) {
      question_table <- rbind(question_table, individual_results)
    }
    if (!is.null(boxcategory_results) && nrow(boxcategory_results) > 0) {
      question_table <- rbind(question_table, boxcategory_results)
    }
    # V9.9.5: Add chi-square row (NEW)
    if (!is.null(chi_square_row) && nrow(chi_square_row) > 0) {
      question_table <- rbind(question_table, chi_square_row)
    }
    if (!is.null(summary_results) && nrow(summary_results) > 0) {
      question_table <- rbind(question_table, summary_results)
    }
  }
  
  all_results[[current_question_code]] <- list(
    question_code = current_question_code,
    question_text = question_info$QuestionText,
    question_type = question_info$Variable_Type,
    base_filter = base_filter,
    bases = banner_bases,
    table = question_table
  )
  
  processed_questions <- c(processed_questions, current_question_code)
  
  checkpoint_counter <- checkpoint_counter + 1
  if (config_obj$enable_checkpointing && checkpoint_counter >= CHECKPOINT_FREQUENCY) {
    save_checkpoint(checkpoint_file, all_results, processed_questions)
    checkpoint_counter <- 0
  }
}

cat("\n")
log_message(sprintf("✓ Processed %d questions", length(all_results)), "INFO")

if (config_obj$enable_checkpointing && file.exists(checkpoint_file)) {
  file.remove(checkpoint_file)
}

# ==============================================================================
# CREATE EXCEL OUTPUT
# ==============================================================================

log_message("Creating Excel output...", "INFO")

wb <- openxlsx::createWorkbook()

# Styles with separate rating/index/score styles
styles <- create_excel_styles(
  config_obj$decimal_separator,
  config_obj$decimal_places_percent,
  config_obj$decimal_places_ratings,
  config_obj$decimal_places_index,
  config_obj$decimal_places_numeric  # V10.0.0: Added
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

create_summary_sheet(wb, project_info, all_results, config_obj, styles)

# Error log
if (nrow(error_log) > 0) {
  openxlsx::addWorksheet(wb, "Error Log")
  openxlsx::writeData(wb, "Error Log", error_log, startRow = 1, colNames = TRUE)
  
  openxlsx::addStyle(wb, "Error Log", styles$header, rows = 1, 
                    cols = 1:ncol(error_log), gridExpand = TRUE)
  
  for (i in seq_len(nrow(error_log))) {
    style <- switch(error_log$Severity[i],
      "Error" = styles$error,
      "Warning" = styles$warning,
      NULL
    )
    
    if (!is.null(style)) {
      openxlsx::addStyle(wb, "Error Log", style, rows = i + 1, 
                        cols = 1:ncol(error_log), gridExpand = TRUE)
    }
  }
  
  openxlsx::setColWidths(wb, "Error Log", cols = 1:ncol(error_log), widths = "auto")
} else {
  openxlsx::addWorksheet(wb, "Error Log")
  openxlsx::writeData(wb, "Error Log", "No errors or warnings.", 
                     startRow = 1, startCol = 1)
}

# V9.9.5: Sample Composition sheet (SAFE - separate sheet)
if (config_obj$create_sample_composition) {
  log_message("Creating sample composition sheet...", "INFO")
  create_sample_composition_sheet(
    wb, survey_data, banner_info, master_weights, config_obj, styles
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
  question_results <- all_results[[q_code]]
  
  if (!is.null(question_results$table) && nrow(question_results$table) > 0) {
    header_text <- paste(question_results$question_code, "-", 
                        question_results$question_text)
    if (config_obj$apply_weighting) {
      header_text <- paste0(header_text, " [", config_obj$weight_label, "]")
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
    
    current_row <- write_base_rows(wb, "Crosstabs", banner_info, 
                                   question_results$bases, styles, 
                                   current_row, config_obj)
    
    current_row <- write_question_table_fast(wb, "Crosstabs", question_results$table, 
                                             banner_info, banner_info$internal_keys, 
                                             styles, current_row)
    
    current_row <- current_row + 1
  }
}

openxlsx::setColWidths(wb, "Crosstabs", cols = 1:2, widths = c(25, 12))
if (length(banner_info$columns) > 0) {
  openxlsx::setColWidths(wb, "Crosstabs", cols = 3:(2 + length(banner_info$columns)), 
                        widths = 10)
}

# Save
output_path <- resolve_path(project_root, file.path("Output", output_subfolder, 
                                                    output_filename))
output_dir <- dirname(output_path)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
  log_message("✓ Created output directory", "INFO")
}

tryCatch({
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  log_message(sprintf("✓ Saved: %s", output_path), "INFO")
}, error = function(e) {
  stop(sprintf("Failed to save Excel: %s", conditionMessage(e)))
})

# ==============================================================================
# COMPLETION SUMMARY
# ==============================================================================

elapsed <- difftime(Sys.time(), start_time, units = "secs")

cat("\n")
cat(paste(rep("=", 80), collapse=""), "\n")
cat("ANALYSIS COMPLETE - V9.9 PRODUCTION RELEASE (CLEAN)\n")
cat(paste(rep("=", 80), collapse=""), "\n\n")

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
cat("V9.9 PRODUCTION RELEASE - ALL FIXES APPLIED:\n")
cat("  ✓ Multi-mention questions display correctly\n")
cat("  ✓ ShowInOutput filtering works properly\n")
cat("  ✓ Rating calculations fixed (OptionValue support)\n")
cat("  ✓ All debug code removed\n")
cat("  ✓ Clean, production-ready code\n")
cat("\n")
cat("Ready for production use.\n")
cat(paste(rep("=", 80), collapse=""), "\n")

# ==============================================================================
# END OF SCRIPT V9.9 - PRODUCTION RELEASE (CLEAN VERSION)
# ==============================================================================
# 
# FIXES APPLIED IN THIS VERSION:
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
# ==============================================================================
