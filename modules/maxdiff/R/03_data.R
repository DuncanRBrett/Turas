# ==============================================================================
# MAXDIFF MODULE - DATA LOADING AND RESHAPING - TURAS V10.0
# ==============================================================================
# Data loading and reshaping functions for MaxDiff analysis
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# DEPENDENCIES:
# - openxlsx, readxl (Excel reading)
# - utils.R
# ==============================================================================

DATA_VERSION <- "10.0"

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
        stop("Package 'openxlsx' is required for Excel files", call. = FALSE)
      }

      openxlsx::read.xlsx(file_path, sheet = sheet, colNames = TRUE,
                          detectDates = TRUE)
    } else {
      stop(sprintf("Unsupported file format: %s", ext), call. = FALSE)
    }
  }, error = function(e) {
    stop(sprintf(
      "Failed to load data file:\n  Path: %s\n  Error: %s",
      file_path, conditionMessage(e)
    ), call. = FALSE)
  })

  if (nrow(data) == 0) {
    stop("Data file is empty (0 rows)", call. = FALSE)
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
    stop("Package 'openxlsx' is required for design files", call. = FALSE)
  }

  # Get sheet names
  sheets <- openxlsx::getSheetNames(file_path)

  # Look for DESIGN sheet
  design_sheet <- if ("DESIGN" %in% sheets) "DESIGN" else sheets[1]

  design <- tryCatch({
    openxlsx::read.xlsx(file_path, sheet = design_sheet, colNames = TRUE)
  }, error = function(e) {
    stop(sprintf(
      "Failed to load design file:\n  Path: %s\n  Error: %s",
      file_path, conditionMessage(e)
    ), call. = FALSE)
  })

  if (nrow(design) == 0) {
    stop("Design file is empty", call. = FALSE)
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

  filtered <- tryCatch({
    subset(data, eval(parse(text = filter_expr)))
  }, error = function(e) {
    stop(sprintf(
      "Invalid filter expression: %s\n  Error: %s",
      filter_expr, conditionMessage(e)
    ), call. = FALSE)
  })

  n_after <- nrow(filtered)

  if (verbose) {
    log_message(sprintf(
      "Filter applied: %d -> %d rows (%d removed)",
      n_before, n_after, n_before - n_after
    ), "INFO", verbose)
  }

  if (n_after == 0) {
    stop(sprintf(
      "Filter expression removed all rows:\n  Expression: %s",
      filter_expr
    ), call. = FALSE)
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
    stop("No BEST_CHOICE fields found in survey mapping", call. = FALSE)
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
    stop("Failed to create long format data (0 rows)", call. = FALSE)
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
