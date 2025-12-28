# ==============================================================================
# TurasTracker - Trend Calculator (Main Orchestration)
# ==============================================================================
#
# Main orchestration file for trend calculations. Dispatches to question-type
# specific calculators and coordinates parallel processing.
#
# VERSION: 3.0.0 - Refactored for maintainability (December 2025)
#
# REFACTORING COMPLETE:
# This file has been split into focused modules:
#
#   trend_calculator.R (this file - orchestration, ~400 lines)
#     - calculate_all_trends()
#     - Question type dispatchers
#     - Parallel processing coordination
#
#   trend_question_types.R (question-specific calculators)
#     - calculate_rating_trend(), calculate_rating_trend_enhanced()
#     - calculate_nps_trend()
#     - calculate_single_choice_trend(), calculate_single_choice_trend_enhanced()
#     - calculate_composite_trend(), calculate_composite_trend_enhanced()
#     - calculate_multi_mention_trend(), calculate_multi_mention_trend_categories()
#
#   trend_statistics.R (statistical calculations)
#     - calculate_weighted_mean(), calculate_nps_score()
#     - calculate_proportions(), calculate_distribution()
#     - calculate_top_box(), calculate_bottom_box(), calculate_custom_range()
#     - calculate_composite_score(), calculate_composite_values_per_respondent()
#
#   trend_significance.R (significance tests)
#     - perform_significance_tests_means()
#     - perform_significance_tests_proportions()
#     - perform_significance_tests_nps()
#     - perform_significance_tests_for_metric()
#     - perform_significance_tests_multi_mention()
#
#   trend_changes.R (wave-over-wave changes)
#     - calculate_changes(), calculate_changes_for_metric()
#     - calculate_changes_for_multi_mention_option()
#     - calculate_changes_for_multi_mention_metric()
#
#   trend_helpers.R (parsing and utilities)
#     - parse_single_choice_specs(), parse_multi_mention_specs()
#     - get_composite_source_questions(), detect_multi_mention_columns()
#
#   statistical_core.R (core statistical tests - single source of truth)
#     - t_test_for_means(), z_test_for_proportions()
#
# PARALLEL PROCESSING:
# When processing many tracked questions (10+), trend calculations can be
# parallelized using the future/future.apply framework.
#
# To enable: calculate_all_trends(..., parallel = TRUE)
# Requirements: future, future.apply packages installed
# Fallback: Sequential calculation if packages not available
#
# ==============================================================================

# ==============================================================================
# DEPENDENCIES - Source helper modules
# ==============================================================================
# Get the directory of this file
.trend_calc_dir <- if (exists("TRACKER_LIB_DIR")) {
  TRACKER_LIB_DIR
} else if (exists("script_dir") && !is.null(script_dir) && length(script_dir) > 0 && nzchar(script_dir[1])) {
  file.path(script_dir[1], "lib")
} else {
  tryCatch({
    ofile <- sys.frame(1)$ofile
    if (!is.null(ofile) && length(ofile) > 0 && nzchar(ofile)) {
      dirname(ofile)
    } else {
      getwd()
    }
  }, error = function(e) getwd())
}

# Source dependencies in correct order
# Note: statistical_core.R, constants.R, and tracker_data_loader.R should
# already be loaded by run_tracker.R before this file

# Source the refactored trend calculation modules with checks
.tc_safe_source <- function(fname) {
  fpath <- file.path(.trend_calc_dir, fname)
  if (!file.exists(fpath)) {
    stop(paste0("Cannot find: ", fpath, "\n  .trend_calc_dir=", .trend_calc_dir))
  }
  source(fpath)
}
.tc_safe_source("trend_helpers.R")
.tc_safe_source("trend_statistics.R")
.tc_safe_source("trend_changes.R")
.tc_safe_source("trend_significance.R")
.tc_safe_source("trend_question_types.R")
rm(.tc_safe_source)


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Check if Significance Test Result is Significant
#'
#' Safe helper function to check if a significance test result indicates significance.
#' Handles NULL, NA, and missing values gracefully.
#'
#' @param sig_test Significance test result object (may be NULL or have $significant field)
#' @return Logical. TRUE if test is significant, FALSE otherwise (including NULL/NA cases)
#'
#' @keywords internal
is_significant <- function(sig_test) {
  # Use isTRUE to safely handle NULL, NA, and non-logical values
  return(isTRUE(!is.null(sig_test) &&
                !is.na(sig_test$significant) &&
                sig_test$significant))
}


#' Normalize Question Type
#'
#' Maps question types to standardized internal types.
#' Supports both TurasTabs and legacy TurasTracker naming conventions.
#'
#' @param q_type Character. Raw question type from configuration.
#' @return Character. Normalized internal question type.
#'
#' @keywords internal
normalize_question_type <- function(q_type) {
  # Map TurasTabs types to internal tracker types
  type_map <- c(
    "Single_Response" = "single_choice",
    "SingleChoice" = "single_choice",
    "Multi_Mention" = "multi_choice",
    "MultiChoice" = "multi_choice",
    "Rating" = "rating",
    "Likert" = "rating",  # Treat Likert same as Rating
    "NPS" = "nps",
    "Index" = "rating",  # Index scores treated as ratings
    "Numeric" = "rating",  # Numeric treated as rating
    "Open_End" = "open_end",
    "OpenEnd" = "open_end",
    "Ranking" = "ranking",
    "Composite" = "composite"
  )

  normalized <- type_map[q_type]

  if (is.na(normalized)) {
    return(tolower(q_type))  # Return lowercase if not in map
  }

  return(as.character(normalized))
}


# ==============================================================================
# MAIN ORCHESTRATION FUNCTION
# ==============================================================================

#' Calculate Trends for All Questions
#'
#' Main function to calculate trends across waves for all tracked questions.
#' Dispatches to question-type specific calculators and coordinates results.
#'
#' @section Parallel Processing:
#' When parallel = TRUE and many questions exist (10+), trend calculations
#' are performed in parallel using the future/future.apply framework.
#' This can significantly speed up processing for large tracker studies.
#'
#' Requirements for parallel processing:
#' - future and future.apply packages installed
#' - At least 10 tracked questions (overhead not worth it for fewer)
#'
#' If packages are not available, falls back to sequential processing.
#'
#' @param config Configuration object containing tracked_questions and waves
#' @param question_map Question map index for looking up question metadata
#' @param wave_data List of wave data frames keyed by wave ID
#' @param parallel Logical. If TRUE, attempt parallel calculation. Default FALSE.
#' @return List containing:
#'   - trends: Named list of trend results for each question
#'   - skipped_questions: List of questions that couldn't be processed
#'   - run_status: "PASS" or "PARTIAL" based on TRS v1.0
#'
#' @export
calculate_all_trends <- function(config, question_map, wave_data, parallel = FALSE) {

  cat("\n================================================================================\n")
  cat("CALCULATING TRENDS\n")
  cat("================================================================================\n")

  tracked_questions <- config$tracked_questions$QuestionCode
  wave_ids <- config$waves$WaveID
  n_questions <- length(tracked_questions)

  # ---------------------------------------------------------------------------
  # PARALLEL PROCESSING SETUP
  # ---------------------------------------------------------------------------
  # Use parallel processing when:
  # 1. parallel = TRUE requested
  # 2. At least 10 questions (overhead not worth it for fewer)
  # 3. Required packages are available
  use_parallel <- FALSE
  if (parallel && n_questions >= 10) {
    if (requireNamespace("future", quietly = TRUE) &&
        requireNamespace("future.apply", quietly = TRUE)) {
      use_parallel <- TRUE
      cat(paste0("Using parallel calculation for ", n_questions, " questions\n"))
    } else {
      cat("Note: parallel=TRUE requested but future/future.apply packages not installed.\n")
      cat("Falling back to sequential calculation. Install packages for parallel support.\n")
    }
  }

  if (use_parallel) {
    # ---------------------------------------------------------------------------
    # PARALLEL TREND CALCULATION
    # ---------------------------------------------------------------------------
    result <- calculate_trends_parallel(
      tracked_questions, question_map, wave_data, config, wave_ids
    )
    trend_results <- result$trend_results
    skipped_questions <- result$skipped_questions

  } else {
    # ---------------------------------------------------------------------------
    # SEQUENTIAL TREND CALCULATION (default)
    # ---------------------------------------------------------------------------
    result <- calculate_trends_sequential(
      tracked_questions, question_map, wave_data, config, wave_ids
    )
    trend_results <- result$trend_results
    skipped_questions <- result$skipped_questions
  }

  cat(paste0("\nCompleted trend calculation for ", length(trend_results), " questions\n"))

  # TRS v1.0: Determine run status and return with metadata
  run_status <- if (length(skipped_questions) > 0) "PARTIAL" else "PASS"

  if (run_status == "PARTIAL") {
    message(sprintf("[TRS] Trend calculation completed with PARTIAL status: %d questions skipped",
                    length(skipped_questions)))
  }

  return(list(
    trends = trend_results,
    skipped_questions = skipped_questions,
    run_status = run_status
  ))
}


# ==============================================================================
# SEQUENTIAL PROCESSING
# ==============================================================================

#' Calculate Trends Sequentially
#'
#' Process all tracked questions one at a time.
#'
#' @keywords internal
calculate_trends_sequential <- function(tracked_questions, question_map, wave_data, config, wave_ids) {

  trend_results <- list()
  skipped_questions <- list()  # TRS v1.0: Track skipped questions for PARTIAL status

  for (q_code in tracked_questions) {
    cat(paste0("\n", strrep("=", 80), "\n"))
    cat(paste0("Processing question: ", q_code, "\n"))

    # Get question metadata
    metadata <- get_question_metadata(question_map, q_code)

    if (is.null(metadata)) {
      # TRS v1.0: Record skipped question for PARTIAL status
      skipped_questions[[q_code]] <- list(
        question_code = q_code,
        reason = "Question not found in mapping",
        stage = "get_question_metadata"
      )
      message(paste0("[TRS PARTIAL] Question ", q_code, " not found in mapping - skipping"))
      next
    }

    # Normalize question type to internal standard
    q_type_raw <- metadata$QuestionType
    q_type <- normalize_question_type(q_type_raw)
    cat(paste0("  Type: ", q_type_raw, " (normalized: ", q_type, ")\n"))

    # Dispatch to appropriate calculator
    trend_result <- calculate_single_question_trend(
      q_code, q_type, q_type_raw, question_map, wave_data, config, skipped_questions
    )

    # Debug: Check what we got back - write to log file too
    debug_msg <- paste0(
      "  [CALC DEBUG] q_code=", q_code,
      " q_type_raw=", q_type_raw,
      " q_type=", q_type,
      " result=", if (is.null(trend_result)) "NULL" else paste0("list(", length(names(trend_result)), ")"),
      " metric_type=", if (!is.null(trend_result$metric_type)) trend_result$metric_type else "NULL"
    )
    cat(debug_msg, "\n")
    # Also write to debug log file
    tryCatch({
      log_path <- file.path(getwd(), "..", "..", "tracker_gui_debug.log")
      if (file.exists(log_path)) {
        cat(format(Sys.time(), "%H:%M:%S"), debug_msg, "\n", file = log_path, append = TRUE)
      }
    }, error = function(e) NULL)

    # Handle skipped questions (returned as list with $skipped)
    if (is.list(trend_result) && !is.null(trend_result$skipped)) {
      skipped_questions[[q_code]] <- trend_result$skipped
      cat(paste0("  SKIPPED: ", trend_result$skipped$reason, "\n"))
    } else if (!is.null(trend_result)) {
      trend_results[[q_code]] <- trend_result
      cat(paste0("  ✓ Trend calculated\n"))
    }
  }

  return(list(
    trend_results = trend_results,
    skipped_questions = skipped_questions
  ))
}


# ==============================================================================
# PARALLEL PROCESSING
# ==============================================================================

#' Calculate Trends in Parallel
#'
#' Process all tracked questions using parallel workers.
#'
#' @keywords internal
calculate_trends_parallel <- function(tracked_questions, question_map, wave_data, config, wave_ids) {

  # Set up parallel plan if not already configured
  if (!future::plan() %in% c("multisession", "multicore", "cluster")) {
    old_plan <- future::plan(future::multisession,
                             workers = min(length(tracked_questions), parallel::detectCores() - 1))
    on.exit(future::plan(old_plan), add = TRUE)
  }

  cat("Calculating trends in parallel...\n")

  # Define the calculation function for a single question
  calculate_single_trend_wrapper <- function(q_code) {
    # Get question metadata
    metadata <- get_question_metadata(question_map, q_code)

    if (is.null(metadata)) {
      return(list(
        q_code = q_code,
        result = NULL,
        skipped = list(
          question_code = q_code,
          reason = "Question not found in mapping",
          stage = "get_question_metadata"
        )
      ))
    }

    # Normalize question type
    q_type_raw <- metadata$QuestionType
    q_type <- normalize_question_type(q_type_raw)

    trend_result <- tryCatch({
      calculate_single_question_trend(
        q_code, q_type, q_type_raw, question_map, wave_data, config, list()
      )
    }, error = function(e) {
      return(list(
        q_code = q_code,
        result = NULL,
        skipped = list(
          question_code = q_code,
          reason = paste0("Error calculating trend: ", e$message),
          stage = "calculation"
        )
      ))
    })

    # If we got a trend result (not a skipped marker), wrap it
    if (!is.null(trend_result) &&
        (!is.list(trend_result) || is.null(trend_result$skipped))) {
      return(list(
        q_code = q_code,
        result = trend_result,
        skipped = NULL
      ))
    }

    # Return skipped info
    if (is.list(trend_result) && !is.null(trend_result$skipped)) {
      return(list(
        q_code = q_code,
        result = NULL,
        skipped = trend_result$skipped
      ))
    }

    return(trend_result)
  }

  # Run calculations in parallel
  parallel_results <- future.apply::future_lapply(
    tracked_questions,
    calculate_single_trend_wrapper,
    future.seed = TRUE
  )

  # Collect results
  trend_results <- list()
  skipped_questions <- list()

  for (res in parallel_results) {
    if (!is.null(res$result)) {
      trend_results[[res$q_code]] <- res$result
      cat(paste0("  ✓ ", res$q_code, " - trend calculated\n"))
    }
    if (!is.null(res$skipped)) {
      skipped_questions[[res$q_code]] <- res$skipped
      cat(paste0("  ⊘ ", res$q_code, " - skipped: ", res$skipped$reason, "\n"))
    }
  }

  return(list(
    trend_results = trend_results,
    skipped_questions = skipped_questions
  ))
}


# ==============================================================================
# QUESTION TYPE DISPATCHER
# ==============================================================================

#' Calculate Trend for Single Question
#'
#' Dispatches to the appropriate question-type specific calculator.
#'
#' @keywords internal
calculate_single_question_trend <- function(q_code, q_type, q_type_raw, question_map,
                                            wave_data, config, skipped_questions) {

  tryCatch({
    if (q_type == "rating") {
      # Use enhanced version (supports TrackingSpecs, backward compatible)
      calculate_rating_trend_enhanced(q_code, question_map, wave_data, config)

    } else if (q_type == "nps") {
      calculate_nps_trend(q_code, question_map, wave_data, config)

    } else if (q_type == "single_choice") {
      # Use enhanced version (supports TrackingSpecs, backward compatible)
      calculate_single_choice_trend_enhanced(q_code, question_map, wave_data, config)

    } else if (q_type == "multi_choice" || q_type_raw == "Multi_Mention") {
      # Multi-mention support (Enhancement Phase 2)
      calculate_multi_mention_trend(q_code, question_map, wave_data, config)

    } else if (q_type == "composite") {
      # Use enhanced version (supports TrackingSpecs, backward compatible)
      calculate_composite_trend_enhanced(q_code, question_map, wave_data, config)

    } else if (q_type == "open_end") {
      # TRS v1.0: Record unsupported type for PARTIAL status
      message(paste0("[TRS PARTIAL] Open-end question ", q_code, " cannot be tracked - skipping"))
      return(list(
        skipped = list(
          question_code = q_code,
          reason = "Open-end questions cannot be tracked",
          stage = "type_check"
        )
      ))

    } else if (q_type == "ranking") {
      # TRS v1.0: Record unsupported type for PARTIAL status
      message(paste0("[TRS PARTIAL] Ranking question ", q_code, " not supported - skipping"))
      return(list(
        skipped = list(
          question_code = q_code,
          reason = "Ranking questions not yet supported in tracker",
          stage = "type_check"
        )
      ))

    } else {
      # TRS v1.0: Record unsupported type for PARTIAL status
      message(paste0("[TRS PARTIAL] Question type '", q_type_raw, "' not supported - skipping"))
      return(list(
        skipped = list(
          question_code = q_code,
          reason = paste0("Question type '", q_type_raw, "' not supported"),
          stage = "type_check"
        )
      ))
    }

  }, error = function(e) {
    # TRS v1.0: Record error for PARTIAL status
    message(paste0("[TRS PARTIAL] Error calculating trend for ", q_code, ": ", e$message))
    return(list(
      skipped = list(
        question_code = q_code,
        reason = paste0("Error calculating trend: ", e$message),
        stage = "calculation"
      )
    ))
  })
}
