# ==============================================================================
# CATEGORICAL KEY DRIVER - MISSING DATA HANDLING
# ==============================================================================
#
# Explicit, transparent missing data handling with per-variable strategies.
#
# Version: 2.0
# Date: December 2024
#
# ==============================================================================

#' Handle Missing Data According to Configuration
#'
#' Applies per-variable missing data strategies and tracks all changes.
#'
#' @param data Data frame
#' @param config Configuration list
#' @return List with:
#'   - data: Processed data frame
#'   - missing_report: Summary of missing data handling
#'   - rows_dropped: Row indices that were dropped
#'   - original_n: Original row count
#' @export
handle_missing_data <- function(data, config) {

  original_n <- nrow(data)
  rows_to_drop <- integer(0)
  missing_report <- list()

  # ==========================================================================
  # OUTCOME VARIABLE - ALWAYS DROP MISSING
  # ==========================================================================

  outcome_var <- config$outcome_var
  outcome_missing <- is.na(data[[outcome_var]])
  n_outcome_missing <- sum(outcome_missing)

  missing_report$outcome <- list(
    variable = outcome_var,
    label = config$outcome_label,
    n_missing_before = n_outcome_missing,
    pct_missing_before = round(100 * n_outcome_missing / original_n, 1),
    strategy = "drop_row",
    n_rows_dropped = n_outcome_missing
  )

  if (n_outcome_missing > 0) {
    rows_to_drop <- c(rows_to_drop, which(outcome_missing))
  }

  # ==========================================================================
  # DRIVER VARIABLES - APPLY PER-VARIABLE STRATEGY
  # ==========================================================================

  for (var_name in config$driver_vars) {
    var_data <- data[[var_name]]
    var_missing <- is.na(var_data)
    n_missing <- sum(var_missing)
    pct_missing <- round(100 * n_missing / original_n, 1)

    # Get strategy for this variable
    strategy <- get_driver_setting(config, var_name, "missing_strategy", "missing_as_level")

    # If no driver_settings, use global default
    if (is.null(strategy)) {
      strategy <- "missing_as_level"
    }

    var_report <- list(
      variable = var_name,
      label = get_var_label(config, var_name),
      n_missing_before = n_missing,
      pct_missing_before = pct_missing,
      strategy = strategy,
      n_rows_dropped = 0,
      n_recoded = 0
    )

    if (n_missing > 0) {
      if (strategy == "drop_row") {
        # Mark rows for dropping
        var_report$n_rows_dropped <- n_missing
        rows_to_drop <- c(rows_to_drop, which(var_missing))

      } else if (strategy == "missing_as_level") {
        # Recode missing as explicit level
        data[[var_name]] <- recode_missing_as_level(var_data)
        var_report$n_recoded <- n_missing

      } else if (strategy == "error_if_missing") {
        # Controlled refusal (not crash)
        catdriver_refuse(
          reason = "DATA_MISSING_NOT_ALLOWED",
          title = "MISSING VALUES NOT ALLOWED",
          problem = paste0("Missing values found in '", var_name, "' with error_if_missing strategy."),
          why_it_matters = paste0("N missing: ", n_missing, " (", pct_missing, "%). ",
                                  "The missing_strategy for this variable is 'error_if_missing', ",
                                  "which requires complete data."),
          fix = paste0("Either:\n",
                      "  1. Remove missing values from data before analysis, OR\n",
                      "  2. Change missing_strategy to 'drop_row' or 'missing_as_level' in Driver_Settings")
        )
      }
    }

    missing_report$drivers[[var_name]] <- var_report
  }

  # ==========================================================================
  # DROP MARKED ROWS
  # ==========================================================================

  rows_to_drop <- unique(rows_to_drop)
  n_dropped <- length(rows_to_drop)

  if (n_dropped > 0) {
    data <- data[-rows_to_drop, , drop = FALSE]
  }

  # ==========================================================================
  # BUILD SUMMARY
  # ==========================================================================

  missing_report$summary <- list(
    original_n = original_n,
    final_n = nrow(data),
    total_rows_dropped = n_dropped,
    pct_retained = round(100 * nrow(data) / original_n, 1)
  )

  list(
    data = data,
    missing_report = missing_report,
    rows_dropped = rows_to_drop,
    original_n = original_n
  )
}


#' Recode Missing Values as Explicit Level
#'
#' Creates "Missing / Not answered" level for missing values.
#'
#' @param x Vector with missing values
#' @return Factor with "Missing / Not answered" level
#' @keywords internal
recode_missing_as_level <- function(x) {
  missing_label <- "Missing / Not answered"

  if (is.factor(x)) {
    # Add missing level
    if (!missing_label %in% levels(x)) {
      levels(x) <- c(levels(x), missing_label)
    }
    x[is.na(x)] <- missing_label
    # Move missing to end
    levels_order <- c(setdiff(levels(x), missing_label), missing_label)
    x <- factor(x, levels = levels_order, ordered = is.ordered(x))
  } else {
    # Convert to factor
    x <- as.character(x)
    x[is.na(x)] <- missing_label
    x <- factor(x)
    # Move missing to end
    levels_order <- c(setdiff(levels(x), missing_label), missing_label)
    x <- factor(x, levels = levels_order)
  }

  x
}


#' Create Missing Data Summary Table
#'
#' Generates a formatted summary of missing data handling for output.
#'
#' @param missing_report Missing report from handle_missing_data()
#' @return Data frame for output
#' @export
format_missing_report <- function(missing_report) {

  rows <- list()

  # Outcome row
  out_info <- missing_report$outcome
  rows[[1]] <- data.frame(
    Variable = out_info$variable,
    Label = out_info$label,
    Type = "Outcome",
    N_Missing_Before = out_info$n_missing_before,
    Pct_Missing_Before = paste0(out_info$pct_missing_before, "%"),
    Strategy = out_info$strategy,
    Action = if (out_info$n_rows_dropped > 0) {
      paste0("Dropped ", out_info$n_rows_dropped, " rows")
    } else {
      "None required"
    },
    stringsAsFactors = FALSE
  )

  # Driver rows
  if (!is.null(missing_report$drivers)) {
    for (var_name in names(missing_report$drivers)) {
      var_info <- missing_report$drivers[[var_name]]

      action_text <- if (var_info$n_rows_dropped > 0) {
        paste0("Dropped ", var_info$n_rows_dropped, " rows")
      } else if (var_info$n_recoded > 0) {
        paste0("Recoded ", var_info$n_recoded, " as 'Missing'")
      } else {
        "None required"
      }

      rows[[length(rows) + 1]] <- data.frame(
        Variable = var_info$variable,
        Label = var_info$label,
        Type = "Driver",
        N_Missing_Before = var_info$n_missing_before,
        Pct_Missing_Before = paste0(var_info$pct_missing_before, "%"),
        Strategy = var_info$strategy,
        Action = action_text,
        stringsAsFactors = FALSE
      )
    }
  }

  do.call(rbind, rows)
}


# ==============================================================================
# RARE LEVEL HANDLING
# ==============================================================================

#' Apply Rare Level Policy
#'
#' Handles rare levels according to configuration.
#'
#' @param data Data frame (already missing-handled)
#' @param config Configuration list
#' @return List with:
#'   - data: Processed data frame
#'   - collapse_report: Summary of collapsed levels
#'   - rows_dropped: Additional rows dropped
#' @export
apply_rare_level_policy <- function(data, config) {

  global_policy <- config$rare_level_policy
  global_threshold <- config$rare_level_threshold
  cell_threshold <- config$rare_cell_threshold

  collapse_report <- list()
  rows_to_drop <- integer(0)

  for (var_name in config$driver_vars) {
    var_data <- data[[var_name]]

    if (!is.factor(var_data)) {
      # Convert to factor if not already
      var_data <- factor(var_data)
      data[[var_name]] <- var_data
    }

    # Get per-variable policy (or use global)
    policy <- get_driver_setting(config, var_name, "rare_level_policy", global_policy)
    if (is.null(policy) || is.na(policy)) {
      policy <- global_policy
    }

    # Count levels
    level_counts <- table(var_data)
    rare_levels <- names(level_counts)[level_counts < global_threshold]

    # Exclude "Missing / Not answered" from collapsing
    rare_levels <- setdiff(rare_levels, "Missing / Not answered")

    var_report <- list(
      variable = var_name,
      label = get_var_label(config, var_name),
      policy = policy,
      threshold = global_threshold,
      rare_levels = rare_levels,
      n_rare = length(rare_levels),
      action = "none",
      collapsed_to = NA
    )

    if (length(rare_levels) > 0) {
      if (policy == "warn_only") {
        var_report$action <- "warned"
        warning("Rare levels in '", var_name, "': ",
                paste(rare_levels, collapse = ", "),
                " (N < ", global_threshold, ")")

      } else if (policy == "collapse_to_other") {
        # Collapse rare levels to "Other"
        other_label <- "Other"
        levels_vec <- levels(var_data)

        # Create mapping
        new_levels <- levels_vec
        new_levels[new_levels %in% rare_levels] <- other_label

        # Apply mapping
        var_data <- factor(new_levels[as.integer(var_data)],
                          levels = unique(c(setdiff(levels_vec, rare_levels), other_label)))

        data[[var_name]] <- var_data
        var_report$action <- "collapsed"
        var_report$collapsed_to <- other_label
        var_report$n_collapsed <- sum(level_counts[rare_levels])

      } else if (policy == "drop_level") {
        # Drop rows with rare levels
        rows_with_rare <- which(as.character(var_data) %in% rare_levels)
        if (length(rows_with_rare) > 0) {
          rows_to_drop <- c(rows_to_drop, rows_with_rare)
          var_report$action <- "dropped"
          var_report$n_dropped <- length(rows_with_rare)
        }

      } else if (policy == "error") {
        catdriver_refuse(
          reason = "DATA_RARE_LEVELS_NOT_ALLOWED",
          title = "RARE LEVELS NOT ALLOWED",
          problem = paste0("Rare levels found in '", var_name, "' with error policy."),
          why_it_matters = paste0("Rare levels: ", paste(rare_levels, collapse = ", "), ". ",
                                  "Threshold: N < ", global_threshold, ". ",
                                  "Levels with very few observations can cause model instability."),
          fix = paste0("Either:\n",
                      "  1. Increase rare_level_threshold, OR\n",
                      "  2. Change rare_level_policy to 'warn_only' or 'collapse_to_other'")
        )
      }
    }

    collapse_report[[var_name]] <- var_report
  }

  # Drop marked rows
  rows_to_drop <- unique(rows_to_drop)
  if (length(rows_to_drop) > 0) {
    data <- data[-rows_to_drop, , drop = FALSE]
  }

  # Check for empty cross-cells (optional warning)
  cell_warnings <- check_sparse_cells(data, config, cell_threshold)

  list(
    data = data,
    collapse_report = collapse_report,
    rows_dropped = rows_to_drop,
    cell_warnings = cell_warnings
  )
}


#' Check for Sparse Cross-Tabulation Cells
#'
#' @param data Data frame
#' @param config Configuration list
#' @param threshold Minimum cell count
#' @return List of warnings
#' @keywords internal
check_sparse_cells <- function(data, config, threshold = 5) {
  warnings_list <- list()

  outcome_var <- config$outcome_var
  outcome_data <- data[[outcome_var]]

  for (var_name in config$driver_vars) {
    var_data <- data[[var_name]]

    if (!is.factor(var_data)) next

    tab <- table(var_data, outcome_data)
    sparse <- which(tab < threshold & tab > 0, arr.ind = TRUE)

    if (nrow(sparse) > 0) {
      warnings_list[[var_name]] <- list(
        variable = var_name,
        n_sparse_cells = nrow(sparse),
        min_cell = min(tab[tab > 0])
      )
    }
  }

  warnings_list
}


#' Format Collapse Report for Output
#'
#' @param collapse_report From apply_rare_level_policy()
#' @return Data frame for output
#' @export
format_collapse_report <- function(collapse_report) {

  if (length(collapse_report) == 0) {
    return(data.frame(
      Variable = character(0),
      Label = character(0),
      Policy = character(0),
      Rare_Levels = character(0),
      Action = character(0),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(names(collapse_report), function(var_name) {
    info <- collapse_report[[var_name]]

    rare_text <- if (length(info$rare_levels) > 0) {
      paste(info$rare_levels, collapse = ", ")
    } else {
      "None"
    }

    action_text <- switch(info$action,
      "none" = "No action needed",
      "warned" = "Warning issued",
      "collapsed" = paste0("Collapsed to '", info$collapsed_to, "'"),
      "dropped" = paste0("Dropped ", info$n_dropped, " rows"),
      info$action
    )

    data.frame(
      Variable = info$variable,
      Label = info$label,
      Policy = info$policy,
      Rare_Levels = rare_text,
      Action = action_text,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}
