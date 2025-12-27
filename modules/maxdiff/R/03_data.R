# ==============================================================================
# MAXDIFF MODULE - DATA LOADING AND RESHAPING - TURAS V10.0
# ==============================================================================
# Data loading and reshaping functions for MaxDiff analysis
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
# Turas v10.1 - Security fix: safe filter expression evaluation (2024-12)
#
# DEPENDENCIES:
# - openxlsx, readxl (Excel reading)
# - utils.R
# ==============================================================================

DATA_VERSION <- "10.1"

# ==============================================================================
# SAFE EXPRESSION EVALUATION FOR FILTERS
# ==============================================================================

# Blacklisted function names that could be dangerous
.UNSAFE_FILTER_FUNCTIONS <- c(
  "system", "system2", "shell", "shell.exec",
  "Sys.setenv", "Sys.unsetenv",
  "file.remove", "file.rename", "unlink", "file.create", "file.copy",
  "download.file", "source", "eval", "parse",
  "library", "require", "loadNamespace", "attachNamespace",
  "assign", "rm", "remove", "get", "exists",
  "writeLines", "writeChar", "writeBin", "write.csv", "write.table",
  "save", "save.image", "saveRDS",
  "setwd", "Sys.chmod", "Sys.umask",
  "options", "Sys.setlocale",
  "q", "quit", "stop", "stopifnot"
)

#' Validate filter expression for safe evaluation
#'
#' @param expr_text Character. Filter expression text
#' @param allowed_vars Character vector. Column names allowed in expression
#' @return Logical TRUE if safe, otherwise throws error
#' @keywords internal
validate_filter_expression <- function(expr_text, allowed_vars) {
  if (is.null(expr_text) || !nzchar(trimws(expr_text))) {
    return(TRUE)
  }

  # Parse the expression to check its structure
  parsed <- tryCatch({
    parse(text = expr_text)
  }, error = function(e) {
    maxdiff_refuse(
      code = "DATA_INVALID_FILTER_SYNTAX",
      title = "Invalid Filter Expression Syntax",
      problem = sprintf("Filter expression has invalid R syntax: %s", conditionMessage(e)),
      why_it_matters = "Cannot apply data filtering with invalid R syntax",
      how_to_fix = c(
        "Check filter expression for syntax errors",
        "Ensure balanced parentheses and quotes",
        "Use valid R comparison operators (==, !=, <, >, etc.)"
      ),
      details = sprintf("Expression: %s\nError: %s", expr_text, conditionMessage(e))
    )
  })

  # Get all function calls in the expression
  expr_calls <- all.names(parsed, functions = TRUE, unique = TRUE)

  # Check for unsafe function calls
  unsafe_found <- intersect(tolower(expr_calls), tolower(.UNSAFE_FILTER_FUNCTIONS))
  if (length(unsafe_found) > 0) {
    maxdiff_refuse(
      code = "DATA_UNSAFE_FILTER_FUNCTION",
      title = "Unsafe Function in Filter Expression",
      problem = sprintf("Filter expression contains unsafe function calls: %s", paste(unsafe_found, collapse = ", ")),
      why_it_matters = "Security risk - unsafe functions could modify files or system state",
      how_to_fix = c(
        "Remove unsafe functions from filter expression",
        "Use only safe comparison and logical operators",
        "Avoid system calls, file operations, and assignment operators"
      ),
      details = sprintf("Expression: %s\nUnsafe functions: %s", expr_text, paste(unsafe_found, collapse = ", "))
    )
  }

  # Check for assignment operators
  if (grepl("<-|<<-|->|->>", expr_text, perl = TRUE)) {
    maxdiff_refuse(
      code = "DATA_FILTER_HAS_ASSIGNMENT",
      title = "Assignment Operator in Filter",
      problem = "Filter expression contains assignment operator (<-, ->, etc.)",
      why_it_matters = "Filter expressions should only test conditions, not modify data",
      how_to_fix = c(
        "Remove assignment operators from filter expression",
        "Use == for comparison instead of ="
      ),
      details = sprintf("Expression: %s", expr_text)
    )
  }

  # Single = is allowed in subset() context for column selection, but check for abuse
  if (grepl("(?<![=!<>])=(?!=)", expr_text, perl = TRUE)) {
    maxdiff_refuse(
      code = "DATA_FILTER_USE_DOUBLE_EQUALS",
      title = "Use == for Comparison",
      problem = "Filter expression uses = instead of == for comparison",
      why_it_matters = "Single = is assignment; use == for logical comparison",
      how_to_fix = "Replace = with == in filter expression for comparisons",
      details = sprintf("Expression: %s", expr_text)
    )
  }

  # Validate variable names if provided
  if (!is.null(allowed_vars) && length(allowed_vars) > 0) {
    expr_names <- all.names(parsed, functions = FALSE, unique = TRUE)

    # Filter out operators, literals, and safe functions
    expr_vars <- expr_names[!expr_names %in% c(
      "==", "!=", "<", ">", "<=", ">=", "&", "|", "!", "&&", "||",
      "+", "-", "*", "/", "^", "%%", "%/%", "%in%",
      "c", "TRUE", "FALSE", "NA", "NULL", "Inf", "NaN",
      "is.na", "is.null", "!is.na", "!is.null",
      "as.character", "as.numeric", "as.integer",
      "toupper", "tolower", "trimws", "grepl", "grep"
    )]

    # Remove numeric literals
    expr_vars <- expr_vars[!grepl("^[0-9.]+$", expr_vars)]

    unknown_vars <- setdiff(expr_vars, allowed_vars)
    if (length(unknown_vars) > 0) {
      maxdiff_refuse(
        code = "DATA_FILTER_UNKNOWN_COLUMN",
        title = "Unknown Column in Filter",
        problem = sprintf("Filter expression references columns not in data: %s", paste(unknown_vars, collapse = ", ")),
        why_it_matters = "Cannot filter on columns that don't exist in the dataset",
        how_to_fix = c(
          "Check column names match exactly (case-sensitive)",
          "Verify columns exist in survey data file",
          "Use one of the available columns listed below"
        ),
        expected = paste(head(allowed_vars, 15), collapse = ", "),
        observed = paste(unknown_vars, collapse = ", ")
      )
    }
  }

  return(TRUE)
}

# ==============================================================================
# DATA LOADING
# ==============================================================================

#' Load Survey Data
#'
#' Loads survey response data from CSV or Excel file.
#'
#' @param file_path Character. Path to data file
#' @param sheet Sheet name or number for Excel files
#' @param verbose Logical. Print progress messages
#'
#' @return Data frame with survey responses
#' @export
load_survey_data <- function(file_path, sheet = 1, verbose = TRUE) {

  file_path <- validate_file_path(file_path, "data_file", must_exist = TRUE)

  ext <- tolower(tools::file_ext(file_path))

  data <- tryCatch({
    if (ext == "csv") {
      if (verbose) log_message("Loading CSV data...", "INFO", verbose)
      read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)
    } else if (ext %in% c("xlsx", "xls")) {
      if (verbose) log_message("Loading Excel data...", "INFO", verbose)

      if (!requireNamespace("openxlsx", quietly = TRUE)) {
        maxdiff_refuse(
          code = "PKG_OPENXLSX_MISSING",
          title = "Required Package Not Installed",
          problem = "Package 'openxlsx' is required but not installed",
          why_it_matters = "Cannot read Excel data files without openxlsx package",
          how_to_fix = "Install the openxlsx package: install.packages('openxlsx')"
        )
      }

      openxlsx::read.xlsx(file_path, sheet = sheet, colNames = TRUE,
                          detectDates = TRUE)
    } else {
      maxdiff_refuse(
        code = "IO_UNSUPPORTED_FILE_FORMAT",
        title = "Unsupported File Format",
        problem = sprintf("File format '.%s' is not supported", ext),
        why_it_matters = "Can only read CSV and Excel (.xlsx, .xls) files",
        how_to_fix = c(
          "Convert file to CSV or Excel format",
          "Supported formats: .csv, .xlsx, .xls"
        ),
        expected = "File with extension: .csv, .xlsx, or .xls",
        observed = sprintf(".%s", ext)
      )
    }
  }, error = function(e) {
    maxdiff_refuse(
      code = "IO_DATA_FILE_READ_ERROR",
      title = "Failed to Load Data File",
      problem = sprintf("Error reading survey data file: %s", conditionMessage(e)),
      why_it_matters = "Cannot proceed with analysis without survey data",
      how_to_fix = c(
        "Check file is not corrupted or locked",
        "Verify file format matches extension (.csv, .xlsx)",
        "Ensure file has correct permissions",
        "Try opening file in Excel/text editor to verify contents"
      ),
      details = sprintf("Path: %s\nError: %s", file_path, conditionMessage(e))
    )
  })

  if (nrow(data) == 0) {
    maxdiff_refuse(
      code = "DATA_EMPTY_FILE",
      title = "Empty Data File",
      problem = "Survey data file contains no rows",
      why_it_matters = "Cannot analyze empty dataset",
      how_to_fix = c(
        "Check that correct data file was specified",
        "Verify data was exported correctly from survey platform",
        "Ensure file contains header row and at least one data row"
      )
    )
  }

  if (verbose) {
    log_message(sprintf("Loaded %d rows, %d columns", nrow(data), ncol(data)), "INFO", verbose)
  }

  return(data)
}


#' Load Design File
#'
#' Loads MaxDiff design matrix from Excel file.
#'
#' @param file_path Character. Path to design file
#' @param verbose Logical. Print progress messages
#'
#' @return Data frame with design matrix
#' @export
load_design_file <- function(file_path, verbose = TRUE) {

  file_path <- validate_file_path(file_path, "design_file", must_exist = TRUE,
                                  extensions = c("xlsx", "xls"))

  if (verbose) log_message("Loading design file...", "INFO", verbose)

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    maxdiff_refuse(
      code = "PKG_OPENXLSX_MISSING",
      title = "Required Package Not Installed",
      problem = "Package 'openxlsx' is required but not installed",
      why_it_matters = "Cannot read Excel design files without openxlsx package",
      how_to_fix = "Install the openxlsx package: install.packages('openxlsx')"
    )
  }

  # Get sheet names
  sheets <- openxlsx::getSheetNames(file_path)

  # Look for DESIGN sheet
  design_sheet <- if ("DESIGN" %in% sheets) "DESIGN" else sheets[1]

  design <- tryCatch({
    openxlsx::read.xlsx(file_path, sheet = design_sheet, colNames = TRUE)
  }, error = function(e) {
    maxdiff_refuse(
      code = "IO_DESIGN_FILE_READ_ERROR",
      title = "Failed to Load Design File",
      problem = sprintf("Error reading design file: %s", conditionMessage(e)),
      why_it_matters = "Design file is required to match survey responses to items",
      how_to_fix = c(
        "Check file is not corrupted or locked",
        "Verify file is valid Excel format (.xlsx, .xls)",
        "Ensure DESIGN sheet exists in workbook",
        "Check file has correct permissions"
      ),
      details = sprintf("Path: %s\nError: %s", file_path, conditionMessage(e))
    )
  })

  if (nrow(design) == 0) {
    maxdiff_refuse(
      code = "DATA_EMPTY_DESIGN",
      title = "Empty Design File",
      problem = "Design file contains no rows",
      why_it_matters = "Design matrix is required to map survey tasks to items",
      how_to_fix = c(
        "Verify design was generated successfully",
        "Check DESIGN sheet in Excel file has data",
        "Re-run design generation if needed"
      )
    )
  }

  # Ensure Version and Task_Number are integers
  if ("Version" %in% names(design)) {
    design$Version <- as.integer(design$Version)
  }
  if ("Task_Number" %in% names(design)) {
    design$Task_Number <- as.integer(design$Task_Number)
  }

  if (verbose) {
    n_versions <- length(unique(design$Version))
    n_tasks <- length(unique(design$Task_Number))
    log_message(sprintf("Loaded design: %d versions, %d tasks each", n_versions, n_tasks),
                "INFO", verbose)
  }

  return(design)
}


# ==============================================================================
# DATA FILTERING
# ==============================================================================

#' Apply filter expression to data
#'
#' Applies a filter expression to data after validating it for safety.
#' Prevents code injection by blocking dangerous function calls.
#'
#' @param data Data frame. Survey data
#' @param filter_expr Character. R filter expression (e.g., "Wave == 2025")
#' @param verbose Logical. Print progress messages
#'
#' @return Filtered data frame
#' @export
apply_filter_expression <- function(data, filter_expr, verbose = TRUE) {

  if (is.null(filter_expr) || !nzchar(trimws(filter_expr))) {
    return(data)
  }

  n_before <- nrow(data)

  # Validate filter expression for safety before evaluation
  validate_filter_expression(filter_expr, allowed_vars = names(data))

  # Now safe to evaluate - uses subset() which evaluates in data context
  filtered <- tryCatch({
    # Parse once (already validated above)
    parsed_expr <- parse(text = filter_expr)
    # Evaluate in restricted environment (baseenv prevents access to global functions)
    subset(data, eval(parsed_expr, envir = data, enclos = baseenv()))
  }, error = function(e) {
    maxdiff_refuse(
      code = "DATA_FILTER_EVALUATION_ERROR",
      title = "Filter Expression Evaluation Error",
      problem = sprintf("Error evaluating filter expression: %s", conditionMessage(e)),
      why_it_matters = "Cannot apply data filter due to evaluation error",
      how_to_fix = c(
        "Check filter expression syntax",
        "Verify column names match data",
        "Ensure data types match comparison operators"
      ),
      details = sprintf("Expression: %s\nError: %s", filter_expr, conditionMessage(e))
    )
  })

  n_after <- nrow(filtered)

  if (verbose) {
    log_message(sprintf(
      "Filter applied: %d -> %d rows (%d removed)",
      n_before, n_after, n_before - n_after
    ), "INFO", verbose)
  }

  if (n_after == 0) {
    maxdiff_refuse(
      code = "DATA_FILTER_REMOVED_ALL_ROWS",
      title = "Filter Removed All Data",
      problem = "Filter expression removed all rows from dataset",
      why_it_matters = "Cannot analyze empty dataset after filtering",
      how_to_fix = c(
        "Check filter expression is correct",
        "Verify filter criteria matches actual data values",
        "Review data to ensure expected values exist",
        "Consider broadening filter criteria"
      ),
      details = sprintf("Expression: %s\nRows before: %d, Rows after: 0", filter_expr, n_before)
    )
  }

  return(filtered)
}


# ==============================================================================
# DATA RESHAPING TO LONG FORMAT
# ==============================================================================

#' Build MaxDiff Long Format Data
#'
#' Reshapes wide survey data to long format for MaxDiff analysis.
#' Creates one row per item-task-respondent combination.
#'
#' @param data Data frame. Raw survey data
#' @param survey_mapping Data frame. Survey mapping configuration
#' @param design Data frame. Design matrix
#' @param config List. Full configuration object
#' @param verbose Logical. Print progress messages
#'
#' @return Data frame in long format with columns:
#'   - resp_id: Respondent identifier
#'   - version: Design version
#'   - task: Task number
#'   - item_id: Item shown
#'   - position: Position in task (1, 2, 3, ...)
#'   - is_best: 1 if chosen as best, 0 otherwise
#'   - is_worst: 1 if chosen as worst, 0 otherwise
#'   - weight: Respondent weight (if applicable)
#'
#' @export
build_maxdiff_long <- function(data, survey_mapping, design, config, verbose = TRUE) {

  if (verbose) log_message("Reshaping data to long format...", "INFO", verbose)

  # Get column mappings
  resp_id_var <- config$project_settings$Respondent_ID_Variable
  weight_var <- config$project_settings$Weight_Variable
  version_col <- survey_mapping$Field_Name[survey_mapping$Field_Type == "VERSION"][1]

  # Get task columns
  best_mapping <- survey_mapping[survey_mapping$Field_Type == "BEST_CHOICE", ]
  worst_mapping <- survey_mapping[survey_mapping$Field_Type == "WORST_CHOICE", ]

  # Order by task number
  best_mapping <- best_mapping[order(best_mapping$Task_Number), ]
  worst_mapping <- worst_mapping[order(worst_mapping$Task_Number), ]

  n_tasks <- nrow(best_mapping)

  if (n_tasks == 0) {
    maxdiff_refuse(
      code = "CFG_NO_BEST_CHOICE_FIELDS",
      title = "No Best Choice Fields Defined",
      problem = "Survey mapping does not define any BEST_CHOICE fields",
      why_it_matters = "MaxDiff requires best choice data to estimate utilities",
      how_to_fix = c(
        "Add BEST_CHOICE field mappings to SURVEY_MAPPING sheet",
        "Ensure Field_Type column contains 'BEST_CHOICE' entries",
        "Verify survey question fields are mapped correctly"
      )
    )
  }

  # Get item columns in design
  item_cols <- grep("^Item\\d+_ID$", names(design), value = TRUE)
  items_per_task <- length(item_cols)

  # Initialize list to collect long format rows
  long_data_list <- vector("list", nrow(data) * n_tasks * items_per_task)
  idx <- 1

  # Process each respondent
  for (r in seq_len(nrow(data))) {
    resp_id <- data[[resp_id_var]][r]
    version <- data[[version_col]][r]
    weight <- if (!is.null(weight_var) && weight_var %in% names(data)) {
      data[[weight_var]][r]
    } else {
      1
    }

    # Skip if version is NA
    if (is.na(version)) next

    # Get design rows for this version
    version_design <- design[design$Version == version, ]

    # Process each task
    for (t in seq_len(n_tasks)) {
      best_col <- best_mapping$Field_Name[t]
      worst_col <- worst_mapping$Field_Name[t]
      task_num <- best_mapping$Task_Number[t]

      # Get choices
      best_choice <- data[[best_col]][r]
      worst_choice <- data[[worst_col]][r]

      # Get items shown in this task
      design_row <- version_design[version_design$Task_Number == task_num, ]

      if (nrow(design_row) == 0) {
        # Try matching by row index if task numbers don't match
        if (t <= nrow(version_design)) {
          design_row <- version_design[t, ]
        } else {
          next
        }
      }

      items_shown <- as.character(unlist(design_row[1, item_cols]))

      # Create long format rows for each item shown
      for (pos in seq_along(items_shown)) {
        item_id <- items_shown[pos]

        long_data_list[[idx]] <- data.frame(
          resp_id = resp_id,
          version = version,
          task = task_num,
          item_id = item_id,
          position = pos,
          is_best = as.integer(!is.na(best_choice) && item_id == best_choice),
          is_worst = as.integer(!is.na(worst_choice) && item_id == worst_choice),
          weight = weight,
          stringsAsFactors = FALSE
        )
        idx <- idx + 1
      }
    }

    # Progress
    if (verbose && r %% 100 == 0) {
      log_progress(r, nrow(data), "Reshaping respondents", verbose)
    }
  }

  # Combine all rows
  long_data_list <- long_data_list[!sapply(long_data_list, is.null)]
  long_data <- do.call(rbind, long_data_list)

  if (is.null(long_data) || nrow(long_data) == 0) {
    maxdiff_refuse(
      code = "DATA_LONG_FORMAT_FAILED",
      title = "Failed to Create Long Format Data",
      problem = "Data reshaping produced zero rows",
      why_it_matters = "Long format data is required for all MaxDiff analyses",
      how_to_fix = c(
        "Check that survey data has valid responses",
        "Verify survey mapping matches actual column names",
        "Ensure design versions match survey data",
        "Check that respondent ID column exists and has values"
      )
    )
  }

  # Add task identifier
  long_data$task_id <- make_task_id(long_data$version, long_data$task)

  # Add unique observation ID
  long_data$obs_id <- seq_len(nrow(long_data))

  if (verbose) {
    n_resp <- length(unique(long_data$resp_id))
    n_obs <- nrow(long_data)
    log_message(sprintf(
      "Long format created: %d respondents, %d observations",
      n_resp, n_obs
    ), "INFO", verbose)
  }

  return(long_data)
}


# ==============================================================================
# RESPONDENT-LEVEL AGGREGATION
# ==============================================================================

#' Aggregate data to respondent level
#'
#' Creates respondent-level summary of choices.
#'
#' @param long_data Data frame. Long format MaxDiff data
#' @param items Data frame. Items configuration
#'
#' @return Data frame with respondent-level item counts
#' @keywords internal
aggregate_by_respondent <- function(long_data, items) {

  item_ids <- items$Item_ID[items$Include == 1]

  # Aggregate by respondent and item
  agg <- aggregate(
    cbind(is_best, is_worst, weight) ~ resp_id + item_id,
    data = long_data,
    FUN = sum
  )

  # Count times shown
  shown_counts <- aggregate(
    obs_id ~ resp_id + item_id,
    data = long_data,
    FUN = length
  )
  names(shown_counts)[3] <- "times_shown"

  # Merge
  result <- merge(agg, shown_counts, by = c("resp_id", "item_id"))

  # Calculate respondent-level best-worst score
  result$bw_score <- result$is_best - result$is_worst

  return(result)
}


# ==============================================================================
# DATA SUMMARY FUNCTIONS
# ==============================================================================

#' Compute study-level data summary
#'
#' @param long_data Data frame. Long format MaxDiff data
#' @param config List. Configuration object
#' @param verbose Logical. Print messages
#'
#' @return List with study-level statistics
#' @export
compute_study_summary <- function(long_data, config, verbose = TRUE) {

  n_respondents <- length(unique(long_data$resp_id))
  n_tasks <- length(unique(long_data$task))
  n_items <- length(unique(long_data$item_id))
  n_observations <- nrow(long_data)

  # Weight statistics
  weight_var <- config$project_settings$Weight_Variable
  has_weights <- !is.null(weight_var)

  if (has_weights) {
    resp_weights <- unique(long_data[, c("resp_id", "weight")])
    weights <- resp_weights$weight

    eff_n <- calculate_effective_n(weights)
    deff <- calculate_deff(weights)
    weight_sum <- sum(weights, na.rm = TRUE)
  } else {
    eff_n <- n_respondents
    deff <- 1
    weight_sum <- n_respondents
  }

  # Version distribution
  resp_versions <- unique(long_data[, c("resp_id", "version")])
  version_dist <- table(resp_versions$version)

  summary_stats <- list(
    n_respondents = n_respondents,
    n_tasks = n_tasks,
    n_items = n_items,
    n_observations = n_observations,
    weighted = has_weights,
    effective_n = eff_n,
    design_effect = deff,
    weight_sum = weight_sum,
    version_distribution = version_dist
  )

  if (verbose) {
    log_message(sprintf(
      "Study summary: %d respondents, effective n = %.1f, DEFF = %.2f",
      n_respondents, eff_n, deff
    ), "INFO", verbose)
  }

  return(summary_stats)
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff data module loaded (v%s)", DATA_VERSION))
