# ==============================================================================
# WEIGHTING MODULE - CELL/INTERLOCKED WEIGHT CALCULATION
# ==============================================================================
# Calculate weights for joint distributions (e.g., Age x Gender cells)
# Part of TURAS Weighting Module v3.0
#
# METHODOLOGY:
# Cell (interlocked) weighting adjusts for joint distributions of two or more
# variables simultaneously. Unlike rim weighting which adjusts marginal
# distributions independently, cell weighting matches the exact cross-tabulation.
#
# For each cell: weight = (target_proportion * N) / cell_count
#
# USE CASES:
# - When joint distributions are known (e.g., census cross-tabs)
# - When variable interactions matter (e.g., young males underrepresented)
# - Smaller surveys where rim weighting may not converge
# ==============================================================================

#' Calculate Cell Weights
#'
#' Calculates weights to match joint distribution targets for combinations
#' of two or more variables.
#'
#' @param data Data frame, survey data
#' @param cell_targets Data frame with columns: cell combination variables and target_percent
#' @param cell_variables Character vector, names of variables defining cells
#' @param verbose Logical, print progress messages (default: FALSE)
#' @return List with $weights, $cell_summary, $method
#' @export
calculate_cell_weights <- function(data,
                                   cell_targets,
                                   cell_variables,
                                   verbose = FALSE) {

  # Validate inputs
  if (!is.data.frame(data) || nrow(data) == 0) {
    weighting_refuse(
      code = "DATA_INVALID_INPUT",
      title = "Invalid Input Data",
      problem = "data must be a non-empty data frame",
      why_it_matters = "Cell weights cannot be calculated without valid survey data",
      how_to_fix = "Provide a data frame with at least one row of survey data"
    )
  }

  if (!is.data.frame(cell_targets) || nrow(cell_targets) == 0) {
    weighting_refuse(
      code = "CFG_INVALID_TARGETS",
      title = "Invalid Cell Targets",
      problem = "cell_targets must be a non-empty data frame",
      why_it_matters = "Cell weighting requires target proportions for each cell combination",
      how_to_fix = "Provide a data frame with cell variable columns and a target_percent column"
    )
  }

  # Check all cell variables exist in data
  missing_vars <- setdiff(cell_variables, names(data))
  if (length(missing_vars) > 0) {
    weighting_refuse(
      code = "CFG_MISSING_VARS",
      title = "Cell Variables Not Found",
      problem = sprintf("Cell variables not found in data: %s", paste(missing_vars, collapse = ", ")),
      why_it_matters = "All cell variables must exist in the data for interlocked weighting",
      how_to_fix = sprintf("Available columns: %s", paste(head(names(data), 20), collapse = ", "))
    )
  }

  # Validate target_percent column exists
  if (!"target_percent" %in% names(cell_targets)) {
    weighting_refuse(
      code = "CFG_MISSING_COLUMNS",
      title = "Missing target_percent Column",
      problem = "cell_targets must have a 'target_percent' column",
      why_it_matters = "Target percentages define the desired joint distribution",
      how_to_fix = "Add a 'target_percent' column to your cell targets table"
    )
  }

  # Validate all cell variable columns exist in targets
  missing_target_vars <- setdiff(cell_variables, names(cell_targets))
  if (length(missing_target_vars) > 0) {
    weighting_refuse(
      code = "CFG_MISSING_COLUMNS",
      title = "Cell Variables Missing From Targets",
      problem = sprintf("Cell variables not in targets table: %s", paste(missing_target_vars, collapse = ", ")),
      why_it_matters = "Each cell variable must appear as a column in the cell targets table",
      how_to_fix = "Ensure your cell targets table has columns for each cell variable"
    )
  }

  # Validate target percentages sum to ~100
  total_pct <- sum(cell_targets$target_percent, na.rm = TRUE)
  if (abs(total_pct - 100) > RIM_TARGET_SUM_TOLERANCE) {
    weighting_refuse(
      code = "CFG_TARGET_SUM_ERROR",
      title = "Cell Target Percentages Do Not Sum to 100",
      problem = sprintf("Cell target percentages sum to %.2f%%, expected 100%%", total_pct),
      why_it_matters = "Target percentages must represent a complete distribution",
      how_to_fix = sprintf("Adjust target_percent values so they sum to 100. Current sum: %.2f", total_pct)
    )
  }

  if (verbose) {
    message("\nCalculating cell weights (interlocked)...")
    message("  Variables: ", paste(cell_variables, collapse = " x "))
    message("  Number of cells: ", nrow(cell_targets))
  }

  n <- nrow(data)

  # Convert data columns to character for matching
  for (var in cell_variables) {
    data[[var]] <- as.character(data[[var]])
    cell_targets[[var]] <- as.character(cell_targets[[var]])
  }

  # Create cell key for each row in data
  data_keys <- apply(data[, cell_variables, drop = FALSE], 1, paste, collapse = "|")

  # Create cell key for each target row
  target_keys <- apply(cell_targets[, cell_variables, drop = FALSE], 1, paste, collapse = "|")

  # Initialize weight vector
  weights <- rep(NA_real_, n)

  # Build cell summary
  cell_summary <- data.frame(
    cell = character(0),
    target_pct = numeric(0),
    sample_count = integer(0),
    sample_pct = numeric(0),
    weight = numeric(0),
    stringsAsFactors = FALSE
  )

  # Track issues
  empty_cells <- character(0)

  for (i in seq_len(nrow(cell_targets))) {
    key <- target_keys[i]
    target_pct <- cell_targets$target_percent[i]

    # Find rows matching this cell
    in_cell <- data_keys == key
    cell_count <- sum(in_cell, na.rm = TRUE)

    if (cell_count == 0) {
      empty_cells <- c(empty_cells, key)
      next
    }

    # Calculate weight: (target_proportion * N) / cell_count
    target_prop <- target_pct / 100
    weight <- (target_prop * n) / cell_count

    weights[in_cell] <- weight

    # Build summary row label
    cell_label <- paste(
      paste0(cell_variables, "=", cell_targets[i, cell_variables]),
      collapse = ", "
    )

    cell_summary <- rbind(cell_summary, data.frame(
      cell = cell_label,
      target_pct = target_pct,
      sample_count = cell_count,
      sample_pct = round(100 * cell_count / n, 2),
      weight = round(weight, 4),
      stringsAsFactors = FALSE
    ))

    if (verbose) {
      message(sprintf("    %s: target=%.1f%%, n=%d, weight=%.4f",
                      cell_label, target_pct, cell_count, weight))
    }
  }

  # Handle empty cells
  if (length(empty_cells) > 0) {
    warning(sprintf(
      "%d cell(s) have targets but no observations: %s\nRows in these cells will have NA weights.",
      length(empty_cells),
      paste(empty_cells, collapse = "; ")
    ), call. = FALSE)
  }

  # Handle unmatched rows (rows not belonging to any defined cell)
  unmatched <- is.na(weights) & !is.na(data_keys)
  n_unmatched <- sum(unmatched)

  if (n_unmatched > 0) {
    unmatched_keys <- unique(data_keys[unmatched])
    warning(sprintf(
      "%d rows (%d%%) belong to undefined cells and will have NA weights.\nUndefined cells: %s",
      n_unmatched,
      round(100 * n_unmatched / n),
      paste(head(unmatched_keys, 10), collapse = "; ")
    ), call. = FALSE)
  }

  if (verbose) {
    n_valid <- sum(!is.na(weights) & weights > 0)
    message(sprintf("  Weights assigned: %d of %d rows", n_valid, n))
    if (n_valid > 0) {
      valid_w <- weights[!is.na(weights)]
      message(sprintf("  Weight range: [%.4f, %.4f], mean=%.4f",
                      min(valid_w), max(valid_w), mean(valid_w)))
    }
  }

  return(list(
    weights = weights,
    cell_summary = cell_summary,
    cell_variables = cell_variables,
    method = "cell",
    n_cells_defined = nrow(cell_targets),
    n_cells_empty = length(empty_cells),
    n_unmatched = n_unmatched
  ))
}

#' Calculate Cell Weights from Config
#'
#' Wrapper function that uses configuration objects to calculate cell weights.
#'
#' @param data Data frame, survey data
#' @param config List, full configuration object
#' @param weight_name Character, name of the weight to calculate
#' @param verbose Logical, print progress messages
#' @return List with $weights, $cell_summary, $validation
#' @export
calculate_cell_weights_from_config <- function(data, config, weight_name,
                                                verbose = FALSE) {

  # Get cell targets for this weight
  cell_targets <- get_cell_targets(config, weight_name)

  if (is.null(cell_targets) || nrow(cell_targets) == 0) {
    weighting_refuse(
      code = "CFG_MISSING_TARGETS",
      title = "No Cell Targets Found",
      problem = sprintf("No cell targets found for weight '%s'", weight_name),
      why_it_matters = "Cell weighting requires joint distribution targets",
      how_to_fix = sprintf("Add cell targets for '%s' in the Cell_Targets sheet", weight_name)
    )
  }

  # Determine cell variables (all columns except weight_name and target_percent)
  cell_variables <- setdiff(names(cell_targets), c("weight_name", "target_percent"))

  if (length(cell_variables) == 0) {
    weighting_refuse(
      code = "CFG_NO_CELL_VARIABLES",
      title = "No Cell Variables Defined",
      problem = "Cell targets must include at least one variable column besides weight_name and target_percent",
      why_it_matters = "Cell weighting requires at least one variable to define cells",
      how_to_fix = "Add variable columns (e.g., Gender, Age) to the Cell_Targets sheet"
    )
  }

  # Validate cell targets against data
  validation <- validate_cell_config(data, cell_targets, weight_name, cell_variables)

  if (!validation$valid) {
    weighting_refuse(
      code = "CFG_VALIDATION_FAILED",
      title = "Cell Weight Configuration Invalid",
      problem = sprintf("Configuration validation failed for weight '%s'", weight_name),
      why_it_matters = "Invalid configuration prevents correct cell weight calculation",
      how_to_fix = paste(validation$errors, collapse = "; ")
    )
  }

  if (length(validation$warnings) > 0) {
    for (w in validation$warnings) {
      warning(w, call. = FALSE)
    }
  }

  # Calculate cell weights
  result <- calculate_cell_weights(
    data = data,
    cell_targets = cell_targets,
    cell_variables = cell_variables,
    verbose = verbose
  )

  # Validate calculated weights
  result$validation <- validate_calculated_weights(result$weights, weight_name)

  return(result)
}

#' Validate Cell Weight Configuration
#'
#' Validates cell weight targets against the data.
#'
#' @param data Data frame, survey data
#' @param cell_targets Data frame, cell target definitions
#' @param weight_name Character, name of the weight
#' @param cell_variables Character vector, cell variable names
#' @return List with $valid, $errors, $warnings
#' @keywords internal
validate_cell_config <- function(data, cell_targets, weight_name, cell_variables) {
  errors <- character(0)
  warnings_list <- character(0)

  # Check variables exist in data
  for (var in cell_variables) {
    if (!var %in% names(data)) {
      errors <- c(errors, sprintf("Variable '%s' not found in data", var))
    }
  }

  # Check target_percent is numeric and valid
  if (any(is.na(cell_targets$target_percent))) {
    errors <- c(errors, "Some target_percent values are NA")
  }

  if (any(cell_targets$target_percent < 0, na.rm = TRUE)) {
    errors <- c(errors, "target_percent values must be non-negative")
  }

  # Check targets sum to ~100
  total_pct <- sum(cell_targets$target_percent, na.rm = TRUE)
  if (abs(total_pct - 100) > RIM_TARGET_SUM_TOLERANCE) {
    errors <- c(errors, sprintf(
      "Cell target percentages sum to %.2f%%, should be 100%% (+/- %.1f%%)",
      total_pct, RIM_TARGET_SUM_TOLERANCE
    ))
  }

  # Check for duplicate cells
  if (length(cell_variables) > 0 && all(cell_variables %in% names(cell_targets))) {
    cell_keys <- apply(cell_targets[, cell_variables, drop = FALSE], 1, paste, collapse = "|")
    if (any(duplicated(cell_keys))) {
      dup_keys <- unique(cell_keys[duplicated(cell_keys)])
      errors <- c(errors, sprintf("Duplicate cell definitions: %s", paste(dup_keys, collapse = ", ")))
    }
  }

  # Check that cell categories exist in data
  if (length(errors) == 0) {
    for (var in cell_variables) {
      if (var %in% names(data)) {
        data_vals <- unique(as.character(data[[var]]))
        target_vals <- unique(as.character(cell_targets[[var]]))
        missing <- setdiff(target_vals, data_vals)
        if (length(missing) > 0) {
          warnings_list <- c(warnings_list, sprintf(
            "Variable '%s': target categories not in data: %s",
            var, paste(missing, collapse = ", ")
          ))
        }
      }
    }
  }

  # Warn about small cell sizes
  if (length(errors) == 0 && all(cell_variables %in% names(data))) {
    for (var in cell_variables) {
      data[[var]] <- as.character(data[[var]])
      cell_targets[[var]] <- as.character(cell_targets[[var]])
    }

    data_keys <- apply(data[, cell_variables, drop = FALSE], 1, paste, collapse = "|")
    target_keys <- apply(cell_targets[, cell_variables, drop = FALSE], 1, paste, collapse = "|")

    for (key in target_keys) {
      cell_n <- sum(data_keys == key, na.rm = TRUE)
      if (cell_n > 0 && cell_n < 5) {
        warnings_list <- c(warnings_list, sprintf(
          "Cell '%s' has only %d observations (minimum 5 recommended)", key, cell_n
        ))
      }
    }
  }

  return(list(
    valid = length(errors) == 0,
    errors = errors,
    warnings = warnings_list
  ))
}

#' Print Cell Weight Summary
#'
#' Displays a formatted summary of cell weight calculation.
#'
#' @param result List, result from calculate_cell_weights_from_config
#' @param weight_name Character, name of the weight
#' @export
print_cell_summary <- function(result, weight_name = "cell_weight") {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("CELL WEIGHT SUMMARY:", weight_name, "\n")
  cat(strrep("=", 70), "\n\n")

  cat("Method: Cell/Interlocked Weighting\n")
  cat("Variables: ", paste(result$cell_variables, collapse = " x "), "\n")
  cat("Cells defined: ", result$n_cells_defined, "\n")
  if (result$n_cells_empty > 0) {
    cat("Empty cells: ", result$n_cells_empty, "\n")
  }
  if (result$n_unmatched > 0) {
    cat("Unmatched rows: ", result$n_unmatched, "\n")
  }
  cat("\n")

  cat("CELL DETAILS:\n")
  cat(strrep("-", 70), "\n")
  cat(sprintf("%-35s %8s %8s %8s %8s\n",
              "Cell", "Target%", "Sample#", "Sample%", "Weight"))
  cat(strrep("-", 70), "\n")

  for (i in seq_len(nrow(result$cell_summary))) {
    row <- result$cell_summary[i, ]
    cat(sprintf("%-35s %8.1f %8d %8.1f %8.4f\n",
                substr(row$cell, 1, 35),
                row$target_pct,
                row$sample_count,
                row$sample_pct,
                row$weight))
  }

  cat(strrep("-", 70), "\n")

  valid_w <- result$weights[!is.na(result$weights)]
  if (length(valid_w) > 0) {
    cat(sprintf("\nWeight range: [%.4f, %.4f], mean=%.4f\n",
                min(valid_w), max(valid_w), mean(valid_w)))
  }

  cat(strrep("=", 70), "\n")
}
