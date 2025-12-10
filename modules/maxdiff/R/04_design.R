# ==============================================================================
# MAXDIFF MODULE - DESIGN GENERATION - TURAS V10.0
# ==============================================================================
# Experimental design generation for MaxDiff studies
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# DESIGN TYPES:
# - BALANCED: Near-balanced incomplete block design
# - OPTIMAL: D-optimal design using AlgDesign package
# - RANDOM: Pure random allocation (for testing)
#
# DEPENDENCIES:
# - AlgDesign (for OPTIMAL designs)
# - utils.R
# ==============================================================================

DESIGN_VERSION <- "10.0"

# ==============================================================================
# MAIN DESIGN GENERATOR
# ==============================================================================

#' Generate MaxDiff Design
#'
#' Generates experimental design for MaxDiff study.
#'
#' @param items Data frame. Items configuration
#' @param design_settings List. Design settings
#' @param seed Integer. Random seed for reproducibility
#' @param verbose Logical. Print progress messages
#'
#' @return List containing:
#'   - design: Data frame with design matrix
#'   - summary: Design summary statistics
#'   - diagnostics: Detailed diagnostics
#'
#' @export
generate_maxdiff_design <- function(items, design_settings, seed = 12345, verbose = TRUE) {

  if (verbose) {
    cat("\n")
    log_message("GENERATING MAXDIFF DESIGN", "INFO", verbose)
    cat(paste(rep("-", 60), collapse = ""), "\n")
  }

  # Set random seed
  set.seed(seed)

  # Get included items
  included_items <- items$Item_ID[items$Include == 1]
  n_items <- length(included_items)

  # Design parameters
  items_per_task <- design_settings$Items_Per_Task
  tasks_per_respondent <- design_settings$Tasks_Per_Respondent
  n_versions <- design_settings$Num_Versions
  design_type <- design_settings$Design_Type

  if (verbose) {
    log_message(sprintf("Items: %d included", n_items), "INFO", verbose)
    log_message(sprintf("Items per task: %d", items_per_task), "INFO", verbose)
    log_message(sprintf("Tasks per respondent: %d", tasks_per_respondent), "INFO", verbose)
    log_message(sprintf("Versions: %d", n_versions), "INFO", verbose)
    log_message(sprintf("Design type: %s", design_type), "INFO", verbose)
  }

  # Generate design based on type
  design <- switch(design_type,
    "BALANCED" = generate_balanced_design(
      item_ids = included_items,
      items_per_task = items_per_task,
      tasks_per_respondent = tasks_per_respondent,
      n_versions = n_versions,
      settings = design_settings,
      verbose = verbose
    ),
    "OPTIMAL" = generate_optimal_design(
      item_ids = included_items,
      items_per_task = items_per_task,
      tasks_per_respondent = tasks_per_respondent,
      n_versions = n_versions,
      settings = design_settings,
      verbose = verbose
    ),
    "RANDOM" = generate_random_design(
      item_ids = included_items,
      items_per_task = items_per_task,
      tasks_per_respondent = tasks_per_respondent,
      n_versions = n_versions,
      verbose = verbose
    ),
    stop(sprintf("Unknown design type: %s", design_type), call. = FALSE)
  )

  # Compute diagnostics
  diagnostics <- compute_design_diagnostics(design, included_items, verbose)

  # Optionally randomize task and item order
  if (design_settings$Randomise_Task_Order) {
    design <- randomize_task_order(design, verbose)
  }

  if (design_settings$Randomise_Item_Order_Within_Task) {
    design <- randomize_item_order(design, verbose)
  }

  if (verbose) {
    cat(paste(rep("-", 60), collapse = ""), "\n")
    log_message(sprintf(
      "Design generated: %d versions x %d tasks = %d rows",
      n_versions, tasks_per_respondent, nrow(design)
    ), "INFO", verbose)
    log_message(sprintf("D-efficiency: %.3f", diagnostics$d_efficiency), "INFO", verbose)
  }

  return(list(
    design = design,
    summary = list(
      n_items = n_items,
      items_per_task = items_per_task,
      tasks_per_respondent = tasks_per_respondent,
      n_versions = n_versions,
      design_type = design_type,
      d_efficiency = diagnostics$d_efficiency
    ),
    diagnostics = diagnostics
  ))
}


# ==============================================================================
# BALANCED DESIGN GENERATOR
# ==============================================================================

#' Generate Balanced Design
#'
#' Generates a near-balanced incomplete block design using iterative
#' optimization to balance item and pair frequencies.
#'
#' @param item_ids Character vector. Item IDs
#' @param items_per_task Integer. Items per task
#' @param tasks_per_respondent Integer. Tasks per respondent
#' @param n_versions Integer. Number of versions
#' @param settings Design settings list
#' @param verbose Logical. Print progress
#'
#' @return Data frame with design matrix
#' @keywords internal
generate_balanced_design <- function(item_ids, items_per_task, tasks_per_respondent,
                                     n_versions, settings, verbose = TRUE) {

  n_items <- length(item_ids)
  max_iterations <- settings$Max_Design_Iterations
  efficiency_threshold <- settings$Design_Efficiency_Threshold

  # Initialize best design
  best_design <- NULL
  best_efficiency <- 0

  # Target frequencies
  total_slots <- n_versions * tasks_per_respondent * items_per_task
  target_item_freq <- total_slots / n_items

  # Number of pairs
  n_pairs <- choose(n_items, 2)
  tasks_total <- n_versions * tasks_per_respondent
  pairs_per_task <- choose(items_per_task, 2)
  target_pair_freq <- (tasks_total * pairs_per_task) / n_pairs

  if (verbose) {
    log_message(sprintf("Target item frequency: %.1f", target_item_freq), "INFO", verbose)
    log_message(sprintf("Target pair frequency: %.1f", target_pair_freq), "INFO", verbose)
  }

  # Iterate to find good design
  for (iter in 1:min(100, max_iterations / 100)) {
    # Generate candidate design
    candidate <- generate_balanced_candidate(
      item_ids = item_ids,
      items_per_task = items_per_task,
      tasks_per_respondent = tasks_per_respondent,
      n_versions = n_versions,
      target_item_freq = target_item_freq
    )

    # Evaluate efficiency
    item_cols <- grep("^Item\\d+_ID$", names(candidate), value = TRUE)
    efficiency <- estimate_d_efficiency(candidate, item_cols, item_ids)

    if (efficiency > best_efficiency) {
      best_design <- candidate
      best_efficiency <- efficiency

      if (verbose && iter %% 10 == 0) {
        log_message(sprintf(
          "Iteration %d: D-efficiency = %.3f",
          iter, efficiency
        ), "INFO", verbose)
      }
    }

    # Check if threshold met
    if (best_efficiency >= efficiency_threshold) {
      if (verbose) {
        log_message(sprintf(
          "Efficiency threshold (%.2f) met at iteration %d",
          efficiency_threshold, iter
        ), "INFO", verbose)
      }
      break
    }
  }

  if (is.null(best_design)) {
    stop("Failed to generate valid design", call. = FALSE)
  }

  return(best_design)
}


#' Generate balanced design candidate
#'
#' @keywords internal
generate_balanced_candidate <- function(item_ids, items_per_task, tasks_per_respondent,
                                        n_versions, target_item_freq) {

  n_items <- length(item_ids)

  # Initialize tracking
  item_counts <- setNames(rep(0, n_items), item_ids)

  design_rows <- list()
  row_idx <- 1

  for (v in 1:n_versions) {
    # Reset counts for each version if needed
    version_item_counts <- setNames(rep(0, n_items), item_ids)

    for (t in 1:tasks_per_respondent) {
      # Select items for this task
      # Prefer items that appear less frequently
      weights <- 1 / (version_item_counts + 1)

      # Sample items
      task_items <- sample(
        item_ids,
        size = items_per_task,
        replace = FALSE,
        prob = weights
      )

      # Update counts
      for (item in task_items) {
        item_counts[item] <- item_counts[item] + 1
        version_item_counts[item] <- version_item_counts[item] + 1
      }

      # Create design row
      row_data <- data.frame(
        Version = v,
        Task_Number = t,
        stringsAsFactors = FALSE
      )

      for (i in seq_along(task_items)) {
        row_data[[sprintf("Item%d_ID", i)]] <- task_items[i]
      }

      design_rows[[row_idx]] <- row_data
      row_idx <- row_idx + 1
    }
  }

  do.call(rbind, design_rows)
}


# ==============================================================================
# OPTIMAL DESIGN GENERATOR
# ==============================================================================

#' Generate Optimal Design
#'
#' Generates D-optimal design using AlgDesign package.
#'
#' @param item_ids Character vector. Item IDs
#' @param items_per_task Integer. Items per task
#' @param tasks_per_respondent Integer. Tasks per respondent
#' @param n_versions Integer. Number of versions
#' @param settings Design settings list
#' @param verbose Logical. Print progress
#'
#' @return Data frame with design matrix
#' @keywords internal
generate_optimal_design <- function(item_ids, items_per_task, tasks_per_respondent,
                                    n_versions, settings, verbose = TRUE) {

  # Check for AlgDesign package
  if (!requireNamespace("AlgDesign", quietly = TRUE)) {
    warning("AlgDesign package not available. Falling back to BALANCED design.",
            call. = FALSE)
    return(generate_balanced_design(
      item_ids = item_ids,
      items_per_task = items_per_task,
      tasks_per_respondent = tasks_per_respondent,
      n_versions = n_versions,
      settings = settings,
      verbose = verbose
    ))
  }

  n_items <- length(item_ids)

  if (verbose) {
    log_message("Using AlgDesign for optimal design...", "INFO", verbose)
  }

  # Generate candidate set (all possible tasks)
  candidate_tasks <- generate_candidate_tasks(item_ids, items_per_task)

  if (verbose) {
    log_message(sprintf(
      "Candidate set: %d possible tasks",
      nrow(candidate_tasks)
    ), "INFO", verbose)
  }

  # Run optimization for each version
  design_rows <- list()

  for (v in 1:n_versions) {
    if (verbose) {
      log_message(sprintf("Optimizing version %d...", v), "INFO", verbose)
    }

    # Select optimal tasks using Federov algorithm
    optimal_result <- tryCatch({
      AlgDesign::optFederov(
        ~ .,
        data = candidate_tasks,
        nTrials = tasks_per_respondent,
        maxIteration = settings$Max_Design_Iterations,
        nRepeats = 5
      )
    }, error = function(e) {
      warning(sprintf(
        "AlgDesign optimization failed for version %d: %s",
        v, conditionMessage(e)
      ), call. = FALSE)
      NULL
    })

    if (is.null(optimal_result)) {
      # Fall back to random selection
      selected_rows <- sample(1:nrow(candidate_tasks), tasks_per_respondent)
      selected_tasks <- candidate_tasks[selected_rows, ]
    } else {
      selected_tasks <- optimal_result$design
    }

    # Convert to design format
    for (t in 1:nrow(selected_tasks)) {
      row_data <- data.frame(
        Version = v,
        Task_Number = t,
        stringsAsFactors = FALSE
      )

      task_row <- selected_tasks[t, ]
      item_idx <- 1
      for (col in names(task_row)) {
        if (task_row[[col]] == 1) {
          row_data[[sprintf("Item%d_ID", item_idx)]] <- col
          item_idx <- item_idx + 1
        }
      }

      design_rows[[length(design_rows) + 1]] <- row_data
    }
  }

  do.call(rbind, design_rows)
}


#' Generate all possible task combinations
#'
#' @keywords internal
generate_candidate_tasks <- function(item_ids, items_per_task) {

  n_items <- length(item_ids)

  # Generate all combinations
  combos <- combn(n_items, items_per_task)

  # Convert to binary indicator matrix
  candidate_matrix <- matrix(0, nrow = ncol(combos), ncol = n_items)
  colnames(candidate_matrix) <- item_ids

  for (i in 1:ncol(combos)) {
    candidate_matrix[i, combos[, i]] <- 1
  }

  as.data.frame(candidate_matrix)
}


# ==============================================================================
# RANDOM DESIGN GENERATOR
# ==============================================================================

#' Generate Random Design
#'
#' Generates purely random design (for testing purposes).
#'
#' @keywords internal
generate_random_design <- function(item_ids, items_per_task, tasks_per_respondent,
                                   n_versions, verbose = TRUE) {

  if (verbose) {
    log_message("Generating random design...", "INFO", verbose)
  }

  design_rows <- list()
  row_idx <- 1

  for (v in 1:n_versions) {
    for (t in 1:tasks_per_respondent) {
      # Random sample
      task_items <- sample(item_ids, size = items_per_task, replace = FALSE)

      row_data <- data.frame(
        Version = v,
        Task_Number = t,
        stringsAsFactors = FALSE
      )

      for (i in seq_along(task_items)) {
        row_data[[sprintf("Item%d_ID", i)]] <- task_items[i]
      }

      design_rows[[row_idx]] <- row_data
      row_idx <- row_idx + 1
    }
  }

  do.call(rbind, design_rows)
}


# ==============================================================================
# DESIGN POST-PROCESSING
# ==============================================================================

#' Randomize task order within versions
#'
#' @keywords internal
randomize_task_order <- function(design, verbose = TRUE) {

  versions <- unique(design$Version)

  new_design_list <- list()

  for (v in versions) {
    version_rows <- design[design$Version == v, ]

    # Random permutation
    new_order <- sample(1:nrow(version_rows))
    version_rows <- version_rows[new_order, ]

    # Reassign task numbers
    version_rows$Task_Number <- 1:nrow(version_rows)

    new_design_list[[length(new_design_list) + 1]] <- version_rows
  }

  result <- do.call(rbind, new_design_list)
  rownames(result) <- NULL

  if (verbose) {
    log_message("Task order randomized within versions", "INFO", verbose)
  }

  return(result)
}


#' Randomize item order within tasks
#'
#' @keywords internal
randomize_item_order <- function(design, verbose = TRUE) {

  item_cols <- grep("^Item\\d+_ID$", names(design), value = TRUE)

  for (i in 1:nrow(design)) {
    task_items <- as.character(design[i, item_cols])
    shuffled <- sample(task_items)
    design[i, item_cols] <- shuffled
  }

  if (verbose) {
    log_message("Item order randomized within tasks", "INFO", verbose)
  }

  return(design)
}


# ==============================================================================
# DESIGN DIAGNOSTICS
# ==============================================================================

#' Compute Design Diagnostics
#'
#' Computes comprehensive diagnostics for a MaxDiff design.
#'
#' @param design Data frame. Design matrix
#' @param item_ids Character vector. Item IDs
#' @param verbose Logical. Print messages
#'
#' @return List with diagnostics
#' @export
compute_design_diagnostics <- function(design, item_ids, verbose = TRUE) {

  item_cols <- grep("^Item\\d+_ID$", names(design), value = TRUE)
  items_per_task <- length(item_cols)
  n_tasks <- nrow(design)

  # Item frequencies
  all_items <- unlist(design[, item_cols])
  item_freq <- table(factor(all_items, levels = item_ids))

  # Item frequency statistics
  item_freq_cv <- sd(item_freq) / mean(item_freq)

  # Pair frequencies
  pair_freq <- compute_pair_frequencies(design, item_cols)
  pair_freq_cv <- if (length(pair_freq) > 0) {
    sd(pair_freq) / mean(pair_freq)
  } else {
    NA
  }

  # Position balance (how often each item appears in each position)
  position_balance <- lapply(seq_along(item_cols), function(pos) {
    table(factor(design[[item_cols[pos]]], levels = item_ids))
  })
  names(position_balance) <- paste0("Position_", seq_along(item_cols))

  # D-efficiency estimate
  d_efficiency <- estimate_d_efficiency(design, item_cols, item_ids)

  # Version-level statistics
  version_stats <- aggregate(
    Task_Number ~ Version,
    data = design,
    FUN = length
  )
  names(version_stats)[2] <- "n_tasks"

  diagnostics <- list(
    item_frequencies = item_freq,
    item_frequency_cv = item_freq_cv,
    pair_frequencies = pair_freq,
    pair_frequency_cv = pair_freq_cv,
    position_balance = position_balance,
    d_efficiency = d_efficiency,
    version_stats = version_stats,
    n_tasks = n_tasks,
    items_per_task = items_per_task
  )

  return(diagnostics)
}


#' Summarize design for output
#'
#' @param design_result List. Output from generate_maxdiff_design
#'
#' @return Data frame summary for Excel output
#' @export
summarize_design <- function(design_result) {

  diag <- design_result$diagnostics

  # Item frequency table
  item_freq_df <- data.frame(
    Item_ID = names(diag$item_frequencies),
    Frequency = as.integer(diag$item_frequencies),
    Percentage = round(100 * as.integer(diag$item_frequencies) /
                        sum(diag$item_frequencies), 1),
    stringsAsFactors = FALSE
  )

  # Design summary
  summary_df <- data.frame(
    Metric = c(
      "Total Items",
      "Items per Task",
      "Total Tasks",
      "Number of Versions",
      "D-Efficiency",
      "Item Frequency CV",
      "Pair Frequency CV"
    ),
    Value = c(
      length(diag$item_frequencies),
      diag$items_per_task,
      diag$n_tasks,
      nrow(diag$version_stats),
      round(diag$d_efficiency, 3),
      round(diag$item_frequency_cv, 3),
      round(diag$pair_frequency_cv, 3)
    ),
    stringsAsFactors = FALSE
  )

  list(
    summary = summary_df,
    item_frequencies = item_freq_df
  )
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff design module loaded (v%s)", DESIGN_VERSION))
