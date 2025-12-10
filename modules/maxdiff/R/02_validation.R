# ==============================================================================
# MAXDIFF MODULE - DATA VALIDATION - TURAS V10.0
# ==============================================================================
# Data validation functions for MaxDiff analysis
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# DEPENDENCIES:
# - utils.R
# ==============================================================================

VALIDATION_VERSION <- "10.0"

# ==============================================================================
# DESIGN VALIDATION
# ==============================================================================

#' Validate MaxDiff Design
#'
#' Validates a design matrix for completeness and consistency.
#'
#' @param design Data frame. Design matrix with Version, Task_Number, Item columns
#' @param items Data frame. Items configuration
#' @param verbose Logical. Print validation messages
#'
#' @return List with validation results:
#'   - valid: Logical. TRUE if design passes all checks
#'   - issues: Character vector of issues found
#'   - warnings: Character vector of warnings
#'   - summary: List with design statistics
#'
#' @export
validate_design <- function(design, items, verbose = TRUE) {

  issues <- character()
  warnings_list <- character()

  # ============================================================================
  # REQUIRED COLUMNS
  # ============================================================================

  required_cols <- c("Version", "Task_Number")
  missing_cols <- setdiff(required_cols, names(design))

  if (length(missing_cols) > 0) {
    issues <- c(issues, sprintf(
      "Design missing required columns: %s",
      paste(missing_cols, collapse = ", ")
    ))
    return(list(valid = FALSE, issues = issues, warnings = warnings_list, summary = NULL))
  }

  # Find item columns (Item1_ID, Item2_ID, etc.)
  item_cols <- grep("^Item\\d+_ID$", names(design), value = TRUE)

  if (length(item_cols) == 0) {
    issues <- c(issues, "Design has no item columns (Item1_ID, Item2_ID, ...)")
    return(list(valid = FALSE, issues = issues, warnings = warnings_list, summary = NULL))
  }

  items_per_task <- length(item_cols)

  # ============================================================================
  # BASIC STRUCTURE VALIDATION
  # ============================================================================

  # Check for NA values in required columns
  for (col in c(required_cols, item_cols)) {
    n_na <- sum(is.na(design[[col]]))
    if (n_na > 0) {
      issues <- c(issues, sprintf(
        "Column '%s' has %d NA values",
        col, n_na
      ))
    }
  }

  if (length(issues) > 0) {
    return(list(valid = FALSE, issues = issues, warnings = warnings_list, summary = NULL))
  }

  # ============================================================================
  # VERSION AND TASK VALIDATION
  # ============================================================================

  versions <- sort(unique(design$Version))
  n_versions <- length(versions)

  if (verbose) {
    log_message(sprintf("Design has %d versions", n_versions), "INFO", verbose)
  }

  # Check tasks per version
  tasks_per_version <- table(design$Version)
  n_tasks <- as.integer(tasks_per_version[1])

  if (length(unique(tasks_per_version)) > 1) {
    warnings_list <- c(warnings_list, sprintf(
      "Versions have different task counts: %s",
      paste(sprintf("V%s=%d", names(tasks_per_version), tasks_per_version), collapse = ", ")
    ))
  }

  # ============================================================================
  # ITEM VALIDATION
  # ============================================================================

  # Get all item IDs from design
  all_design_items <- unique(unlist(design[, item_cols]))

  # Get included items from config
  included_items <- items$Item_ID[items$Include == 1]

  # Check for unknown items in design
  unknown_items <- setdiff(all_design_items, items$Item_ID)
  if (length(unknown_items) > 0) {
    issues <- c(issues, sprintf(
      "Design contains unknown Item_IDs: %s",
      paste(unknown_items, collapse = ", ")
    ))
  }

  # Check all included items appear in design
  missing_items <- setdiff(included_items, all_design_items)
  if (length(missing_items) > 0) {
    warnings_list <- c(warnings_list, sprintf(
      "Some included items never appear in design: %s",
      paste(missing_items, collapse = ", ")
    ))
  }

  # ============================================================================
  # WITHIN-TASK VALIDATION
  # ============================================================================

  # Check for duplicate items within tasks
  for (i in seq_len(nrow(design))) {
    task_items <- as.character(unlist(design[i, item_cols]))

    if (length(unique(task_items)) < length(task_items)) {
      dup_items <- task_items[duplicated(task_items)]
      issues <- c(issues, sprintf(
        "Version %d Task %d has duplicate items: %s",
        design$Version[i], design$Task_Number[i], paste(dup_items, collapse = ", ")
      ))
    }
  }

  # ============================================================================
  # COMPUTE DESIGN STATISTICS
  # ============================================================================

  # Item frequencies
  item_freq <- table(unlist(design[, item_cols]))

  # Pair frequencies (compute efficiently)
  pair_freq <- compute_pair_frequencies(design, item_cols)

  # Position balance
  position_balance <- lapply(seq_along(item_cols), function(pos) {
    table(design[[item_cols[pos]]])
  })
  names(position_balance) <- paste0("Position_", seq_along(item_cols))

  # D-efficiency (simplified estimate)
  d_efficiency <- estimate_d_efficiency(design, item_cols, included_items)

  # ============================================================================
  # BALANCE CHECKS
  # ============================================================================

  # Item frequency CV (coefficient of variation)
  item_cv <- sd(item_freq) / mean(item_freq)
  if (item_cv > 0.2) {
    warnings_list <- c(warnings_list, sprintf(
      "Item frequencies are unbalanced (CV = %.3f > 0.2)",
      item_cv
    ))
  }

  # Pair frequency CV
  if (length(pair_freq) > 0) {
    pair_values <- as.numeric(pair_freq)
    pair_cv <- sd(pair_values) / mean(pair_values)
    if (pair_cv > 0.3) {
      warnings_list <- c(warnings_list, sprintf(
        "Pair frequencies are unbalanced (CV = %.3f > 0.3)",
        pair_cv
      ))
    }
  }

  # ============================================================================
  # SUMMARY
  # ============================================================================

  summary_stats <- list(
    n_versions = n_versions,
    n_tasks = n_tasks,
    items_per_task = items_per_task,
    total_rows = nrow(design),
    item_frequencies = item_freq,
    item_frequency_cv = item_cv,
    pair_frequency_cv = if (length(pair_freq) > 0) sd(as.numeric(pair_freq)) / mean(as.numeric(pair_freq)) else NA,
    d_efficiency = d_efficiency,
    position_balance = position_balance
  )

  valid <- length(issues) == 0

  if (verbose) {
    if (valid) {
      log_message(sprintf("Design validation passed (D-efficiency: %.3f)", d_efficiency), "INFO", verbose)
    } else {
      log_message(sprintf("Design validation failed with %d issues", length(issues)), "ERROR", verbose)
    }
    if (length(warnings_list) > 0) {
      log_message(sprintf("Design has %d warnings", length(warnings_list)), "WARN", verbose)
    }
  }

  return(list(
    valid = valid,
    issues = issues,
    warnings = warnings_list,
    summary = summary_stats
  ))
}


#' Compute pair frequencies in design
#'
#' @param design Design data frame
#' @param item_cols Item column names
#'
#' @return Named vector of pair frequencies
#' @keywords internal
compute_pair_frequencies <- function(design, item_cols) {

  pair_counts <- list()

  for (i in seq_len(nrow(design))) {
    task_items <- sort(as.character(unlist(design[i, item_cols])))

    # Generate all pairs
    for (j in 1:(length(task_items) - 1)) {
      for (k in (j + 1):length(task_items)) {
        pair_key <- paste(task_items[j], task_items[k], sep = "_")

        if (is.null(pair_counts[[pair_key]])) {
          pair_counts[[pair_key]] <- 0
        }
        pair_counts[[pair_key]] <- pair_counts[[pair_key]] + 1
      }
    }
  }

  unlist(pair_counts)
}


#' Estimate D-efficiency of design
#'
#' @param design Design data frame
#' @param item_cols Item column names
#' @param items Character vector of item IDs
#'
#' @return Numeric D-efficiency estimate (0-1)
#' @keywords internal
estimate_d_efficiency <- function(design, item_cols, items) {

  n_items <- length(items)
  k <- length(item_cols)
  n_tasks <- nrow(design)

  # Simple D-efficiency approximation
  # Based on balance of item frequencies and pair frequencies

  # Item balance component
  item_freq <- table(factor(unlist(design[, item_cols]), levels = items))
  expected_freq <- (n_tasks * k) / n_items
  item_balance <- 1 - (sd(item_freq) / expected_freq)

  # Pair balance component
  pair_freq <- compute_pair_frequencies(design, item_cols)
  if (length(pair_freq) > 0) {
    expected_pair <- n_tasks * choose(k, 2) / choose(n_items, 2)
    pair_balance <- 1 - min(1, sd(pair_freq) / max(1, expected_pair))
  } else {
    pair_balance <- 1
  }

  # Combined efficiency
  d_eff <- (item_balance * pair_balance)^0.5

  return(max(0, min(1, d_eff)))
}


# ==============================================================================
# DATA VALIDATION
# ==============================================================================

#' Validate Survey Data
#'
#' Validates survey response data for MaxDiff analysis.
#'
#' @param data Data frame. Survey response data
#' @param survey_mapping Data frame. Survey mapping configuration
#' @param design Data frame. Design matrix
#' @param items Data frame. Items configuration
#' @param verbose Logical. Print validation messages
#'
#' @return List with validation results
#'
#' @export
validate_survey_data <- function(data, survey_mapping, design, items, verbose = TRUE) {

  issues <- character()
  warnings_list <- character()

  # ============================================================================
  # CHECK REQUIRED COLUMNS
  # ============================================================================

  # Get all required column names from survey mapping
  required_cols <- survey_mapping$Field_Name

  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    issues <- c(issues, sprintf(
      "Data missing required columns from SURVEY_MAPPING:\n  %s",
      paste(missing_cols, collapse = "\n  ")
    ))
  }

  if (length(issues) > 0) {
    return(list(valid = FALSE, issues = issues, warnings = warnings_list, summary = NULL))
  }

  # ============================================================================
  # VERSION VALIDATION
  # ============================================================================

  version_col <- survey_mapping$Field_Name[survey_mapping$Field_Type == "VERSION"][1]

  if (!is.null(version_col) && version_col %in% names(data)) {
    data_versions <- unique(data[[version_col]])
    design_versions <- unique(design$Version)

    unknown_versions <- setdiff(data_versions, design_versions)
    if (length(unknown_versions) > 0) {
      issues <- c(issues, sprintf(
        "Data contains unknown version numbers: %s\n  Design versions: %s",
        paste(unknown_versions, collapse = ", "),
        paste(design_versions, collapse = ", ")
      ))
    }

    # Check version distribution
    version_counts <- table(data[[version_col]])
    if (verbose) {
      log_message(sprintf(
        "Version distribution: %s",
        paste(sprintf("V%s=%d", names(version_counts), version_counts), collapse = ", ")
      ), "INFO", verbose)
    }

    # Warn if versions are very unbalanced
    if (length(version_counts) > 1) {
      version_cv <- sd(version_counts) / mean(version_counts)
      if (version_cv > 0.5) {
        warnings_list <- c(warnings_list, sprintf(
          "Version distribution is unbalanced (CV = %.2f)",
          version_cv
        ))
      }
    }
  }

  # ============================================================================
  # CHOICE VALIDATION
  # ============================================================================

  # Get item IDs from config
  valid_item_ids <- items$Item_ID

  # Get BEST and WORST columns
  best_cols <- survey_mapping$Field_Name[survey_mapping$Field_Type == "BEST_CHOICE"]
  worst_cols <- survey_mapping$Field_Name[survey_mapping$Field_Type == "WORST_CHOICE"]

  # Check each choice column
  for (col in c(best_cols, worst_cols)) {
    if (col %in% names(data)) {
      col_values <- data[[col]]
      col_values <- col_values[!is.na(col_values)]

      invalid_values <- setdiff(unique(col_values), valid_item_ids)
      if (length(invalid_values) > 0) {
        issues <- c(issues, sprintf(
          "Column '%s' contains invalid Item_IDs: %s",
          col, paste(invalid_values, collapse = ", ")
        ))
      }
    }
  }

  # ============================================================================
  # DUPLICATE CHOICE VALIDATION
  # ============================================================================

  # Check that best != worst in same task
  n_tasks <- length(best_cols)

  for (i in seq_len(n_tasks)) {
    if (best_cols[i] %in% names(data) && worst_cols[i] %in% names(data)) {
      best_val <- data[[best_cols[i]]]
      worst_val <- data[[worst_cols[i]]]

      same_choice <- !is.na(best_val) & !is.na(worst_val) & best_val == worst_val
      n_same <- sum(same_choice)

      if (n_same > 0) {
        issues <- c(issues, sprintf(
          "Task %d: %d respondents have same best and worst choice",
          i, n_same
        ))
      }
    }
  }

  # ============================================================================
  # SHOWN ITEMS VALIDATION (if provided)
  # ============================================================================

  shown_cols <- survey_mapping$Field_Name[survey_mapping$Field_Type == "SHOWN_ITEMS"]

  if (length(shown_cols) > 0) {
    for (col in shown_cols) {
      if (col %in% names(data)) {
        # Validate choices are in shown items
        task_num <- survey_mapping$Task_Number[survey_mapping$Field_Name == col]

        if (!is.na(task_num)) {
          best_col <- best_cols[task_num]
          worst_col <- worst_cols[task_num]

          if (best_col %in% names(data) && worst_col %in% names(data)) {
            for (r in seq_len(nrow(data))) {
              shown_items <- unlist(strsplit(as.character(data[[col]][r]), ","))
              shown_items <- trimws(shown_items)

              best_item <- data[[best_col]][r]
              worst_item <- data[[worst_col]][r]

              if (!is.na(best_item) && !best_item %in% shown_items) {
                warnings_list <- c(warnings_list, sprintf(
                  "Row %d Task %d: Best choice '%s' not in shown items",
                  r, task_num, best_item
                ))
              }

              if (!is.na(worst_item) && !worst_item %in% shown_items) {
                warnings_list <- c(warnings_list, sprintf(
                  "Row %d Task %d: Worst choice '%s' not in shown items",
                  r, task_num, worst_item
                ))
              }
            }
          }
        }
      }
    }

    # Limit warnings
    if (length(warnings_list) > 20) {
      n_more <- length(warnings_list) - 20
      warnings_list <- c(warnings_list[1:20], sprintf("... and %d more warnings", n_more))
    }
  }

  # ============================================================================
  # COMPLETENESS CHECK
  # ============================================================================

  # Count complete cases
  choice_cols <- c(best_cols, worst_cols)
  choice_cols <- choice_cols[choice_cols %in% names(data)]

  complete_cases <- complete.cases(data[, choice_cols, drop = FALSE])
  n_complete <- sum(complete_cases)
  n_total <- nrow(data)

  if (n_complete < n_total) {
    pct_complete <- round(100 * n_complete / n_total, 1)
    warnings_list <- c(warnings_list, sprintf(
      "Only %d of %d respondents (%.1f%%) have complete choice data",
      n_complete, n_total, pct_complete
    ))
  }

  # ============================================================================
  # SUMMARY
  # ============================================================================

  summary_stats <- list(
    n_respondents = n_total,
    n_complete = n_complete,
    n_tasks = n_tasks,
    version_distribution = if (exists("version_counts")) version_counts else NULL
  )

  valid <- length(issues) == 0

  if (verbose) {
    if (valid) {
      log_message(sprintf(
        "Data validation passed: %d respondents, %d complete",
        n_total, n_complete
      ), "INFO", verbose)
    } else {
      log_message(sprintf(
        "Data validation failed with %d issues",
        length(issues)
      ), "ERROR", verbose)
    }
  }

  return(list(
    valid = valid,
    issues = issues,
    warnings = warnings_list,
    summary = summary_stats
  ))
}


#' Validate weights
#'
#' @param weights Numeric vector of weights
#' @param verbose Logical. Print messages
#'
#' @return List with validation results
#' @keywords internal
validate_maxdiff_weights <- function(weights, verbose = TRUE) {

  issues <- character()
  warnings_list <- character()

  if (is.null(weights)) {
    return(list(valid = TRUE, issues = issues, warnings = warnings_list))
  }

  # Check for NAs
  n_na <- sum(is.na(weights))
  if (n_na > 0) {
    issues <- c(issues, sprintf(
      "Weights contain %d NA values",
      n_na
    ))
  }

  # Check for non-positive
  weights_valid <- weights[!is.na(weights)]
  n_nonpos <- sum(weights_valid <= 0)

  if (n_nonpos > 0) {
    issues <- c(issues, sprintf(
      "Weights contain %d non-positive values",
      n_nonpos
    ))
  }

  # Check range
  if (length(weights_valid) > 0) {
    w_min <- min(weights_valid[weights_valid > 0])
    w_max <- max(weights_valid)
    w_ratio <- w_max / w_min

    if (w_ratio > 10) {
      warnings_list <- c(warnings_list, sprintf(
        "Weight ratio is very large (%.1f). Consider trimming extreme weights.",
        w_ratio
      ))
    }

    # Compute design effect
    deff <- calculate_deff(weights_valid)
    if (deff > 2) {
      warnings_list <- c(warnings_list, sprintf(
        "Design effect is %.2f. Effective sample size is reduced.",
        deff
      ))
    }
  }

  valid <- length(issues) == 0

  return(list(valid = valid, issues = issues, warnings = warnings_list))
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff validation module loaded (v%s)", VALIDATION_VERSION))
