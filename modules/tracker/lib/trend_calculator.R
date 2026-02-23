# ==============================================================================
# TurasTracker - Trend Calculator
# ==============================================================================
#
# Calculates trends and wave-over-wave changes for tracked questions.
# Supports: Rating questions, Single choice, NPS, Index scores, Composites
#
# VERSION: 3.0.0 - Phase 4 maintainability refactoring
# SIZE: ~1,600 lines
#
# ARCHITECTURE:
# Core statistical functions (weighted mean, NPS, proportions, distribution,
# top/bottom box, custom range, significance tests) are defined in
# statistical_core.R (single source of truth). This file contains only
# trend-specific orchestration and enhanced question-type calculators.
#
# PARALLEL PROCESSING:
# When processing many tracked questions (10+), trend calculations can be
# parallelized using the future/future.apply framework.
# To enable: calculate_all_trends(..., parallel = TRUE)
#
# NOTE: Required modules are loaded by run_tracker.R in the correct order:
# - metric_types.R (metric type constants and validation)
# - statistical_core.R (core statistical functions - SINGLE SOURCE OF TRUTH)
# - trend_changes.R (wave-over-wave change calculations)
# - trend_significance.R (significance testing functions)
# - trend_calculator.R (this file - orchestration and enhanced calculators)
# ==============================================================================
# ==============================================================================

#' Calculate Trends for All Questions
#'
#' Main function to calculate trends across waves for all tracked questions.
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
#' @param config Configuration object
#' @param question_map Question map index
#' @param wave_data List of wave data frames
#' @param parallel Logical. If TRUE, attempt parallel calculation. Default FALSE.
#' @return List containing trend results for each question
#'
#' @export


# [REMOVED] normalize_question_type() - Now defined in statistical_core.R (single source of truth).


#' Dispatch Single Trend Calculation
#'
#' Routes a single question to the appropriate trend calculator based on type.
#' Returns a standardized result with q_code, result, and skipped fields.
#' Used by both parallel and sequential branches of calculate_all_trends.
#'
#' @param q_code Character. Question code
#' @param question_map List. Question mapping
#' @param wave_data List. All wave data
#' @param config List. Tracker config
#' @param wave_structures List or NULL. Survey structures
#' @return List with $q_code, $result (or NULL), $skipped (or NULL)
#' @keywords internal
dispatch_single_trend <- function(q_code, question_map, wave_data, config, wave_structures) {
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

  q_type_raw <- metadata$QuestionType
  q_type <- normalize_question_type(q_type_raw)

  trend_result <- tryCatch({
    if (q_type == "rating") {
      calculate_rating_trend_enhanced(q_code, question_map, wave_data, config, wave_structures)
    } else if (q_type == "nps") {
      calculate_nps_trend(q_code, question_map, wave_data, config, wave_structures)
    } else if (q_type == "single_choice") {
      calculate_single_choice_trend_enhanced(q_code, question_map, wave_data, config, wave_structures)
    } else if (q_type == "multi_choice" || q_type_raw == "Multi_Mention") {
      calculate_multi_mention_trend(q_code, question_map, wave_data, config, wave_structures)
    } else if (q_type == "composite") {
      calculate_composite_trend_enhanced(q_code, question_map, wave_data, config, wave_structures)
    } else if (q_type == "open_end") {
      return(list(
        q_code = q_code, result = NULL,
        skipped = list(question_code = q_code, reason = "Open-end questions cannot be tracked", stage = "type_check")
      ))
    } else if (q_type == "ranking") {
      return(list(
        q_code = q_code, result = NULL,
        skipped = list(question_code = q_code, reason = "Ranking questions not yet supported in tracker", stage = "type_check")
      ))
    } else {
      return(list(
        q_code = q_code, result = NULL,
        skipped = list(question_code = q_code, reason = paste0("Question type '", q_type_raw, "' not supported"), stage = "type_check")
      ))
    }
  }, error = function(e) {
    cat("[WARNING] Error calculating trend for ", q_code, ": ", e$message, "\n")
    return(list(
      q_code = q_code, result = NULL,
      skipped = list(question_code = q_code, reason = paste0("Error calculating trend: ", e$message), stage = "calculation")
    ))
  })

  # If we got a trend result (not an early return), wrap it
  if (!is.null(trend_result) &&
      (!is.list(trend_result) || is.null(trend_result$skipped))) {
    return(list(q_code = q_code, result = trend_result, skipped = NULL))
  }

  return(trend_result)
}


calculate_all_trends <- function(config, question_map, wave_data, parallel = FALSE,
                                 wave_structures = NULL) {

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
    # Set up parallel plan if not already configured
    current_plan_class <- class(future::plan())[1]
    if (!current_plan_class %in% c("multisession", "multicore", "cluster")) {
      old_plan <- future::plan(future::multisession,
                               workers = min(n_questions, parallel::detectCores() - 1))
      on.exit(future::plan(old_plan), add = TRUE)
    }

    cat("Calculating trends in parallel...\n")

    # Run calculations in parallel using shared dispatch helper
    parallel_results <- future.apply::future_lapply(
      tracked_questions,
      dispatch_single_trend,
      question_map = question_map,
      wave_data = wave_data,
      config = config,
      wave_structures = wave_structures,
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

  } else {
    # ---------------------------------------------------------------------------
    # SEQUENTIAL TREND CALCULATION (default)
    # ---------------------------------------------------------------------------
    trend_results <- list()
    skipped_questions <- list()  # TRS v1.0: Track skipped questions for PARTIAL status

    for (q_code in tracked_questions) {
      cat(paste0("\n", strrep("=", 80), "\n"))
      cat(paste0("Processing question: ", q_code, "\n"))

      # Use shared dispatch helper
      res <- dispatch_single_trend(q_code, question_map, wave_data, config, wave_structures)

      if (!is.null(res$result)) {
        trend_results[[q_code]] <- res$result
        cat(paste0("  ✓ Trend calculated\n"))
      }
      if (!is.null(res$skipped)) {
        skipped_questions[[q_code]] <- res$skipped
        message(paste0("[TRS PARTIAL] ", q_code, " - ", res$skipped$reason))
      }
    }
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


# [REMOVED] calculate_rating_trend() - Dead code superseded by
# calculate_rating_trend_enhanced(). Removed in Phase 4 (zero callers confirmed).


#' Calculate NPS Trend
#'
#' Calculates Net Promoter Score across waves.
#' NPS = % Promoters (9-10) - % Detractors (0-6)
#'
#' @keywords internal
calculate_nps_trend <- function(q_code, question_map, wave_data, config,
                                wave_structures = NULL) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Calculate NPS for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    wave_df <- wave_data[[wave_id]]
    q_data <- extract_question_data(wave_df, wave_id, q_code, question_map)

    if (is.null(q_data)) {
      wave_results[[wave_id]] <- list(
        nps = NA,
        promoters_pct = NA,
        passives_pct = NA,
        detractors_pct = NA,
        n_unweighted = NA,
        n_weighted = NA,
        available = FALSE
      )
      next
    }

    # Resolve text → numeric using survey structure (if available)
    wave_struct <- if (!is.null(wave_structures)) wave_structures[[wave_id]] else NULL
    wave_col <- get_wave_question_code(question_map, q_code, wave_id)
    q_data <- resolve_question_values(q_data, wave_struct, wave_col)

    # Calculate NPS
    result <- calculate_nps_score(
      values = q_data,
      weights = wave_df$weight_var
    )

    wave_results[[wave_id]] <- c(result, list(available = TRUE))
  }

  # Calculate wave-over-wave changes
  changes <- calculate_changes(wave_results, wave_ids, "nps")

  # Significance testing for NPS (treat as proportion difference)
  sig_tests <- perform_significance_tests_nps(wave_results, wave_ids, config)

  result <- list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "nps",
    wave_results = wave_results,
    changes = changes,
    significance = sig_tests
  )

  validate_result_metric_type(result, context = "calculate_nps_trend")
  return(result)
}


# [REMOVED] calculate_single_choice_trend() - Dead code superseded by
# calculate_single_choice_trend_enhanced(). Removed in Phase 4 (zero callers confirmed).


#' Parse Single Choice TrackingSpecs
#'
#' Parses TrackingSpecs for single-choice questions.
#' Supports: "all", "top3", "category:X", "category:X,category:Y"
#'
#' @param tracking_specs Character. TrackingSpecs string
#' @param all_codes Character vector. All available response codes
#' @return List with $mode and $codes
#'
#' @keywords internal
parse_single_choice_specs <- function(tracking_specs, all_codes) {

  # Default to all if blank
  if (is.null(tracking_specs) || tracking_specs == "" || tolower(trimws(tracking_specs)) == "all") {
    return(list(
      mode = "all",
      codes = all_codes
    ))
  }

  # Parse comma-separated specs
  specs <- trimws(strsplit(tracking_specs, ",")[[1]])

  result <- list(
    mode = "selective",
    codes = character(0)
  )

  for (spec in specs) {
    # Strip =Label before processing (labels are display-only)
    parsed <- parse_spec_label(spec)
    core_spec <- parsed$core
    core_lower <- tolower(trimws(core_spec))

    if (core_lower == "all") {
      # Track all codes
      result$mode <- "all"
      result$codes <- unique(c(result$codes, all_codes))

    } else if (core_lower == "top3") {
      # Track top 3 most frequent codes (will need to determine from data)
      result$mode <- "top3"
      # Codes will be determined after calculating frequencies

    } else if (startsWith(core_lower, "category:")) {
      # Specific category: "category:last week"
      category_name <- sub("^category:", "", core_spec, ignore.case = TRUE)
      category_name <- trimws(category_name)  # Remove any leading/trailing whitespace
      if (category_name != "") {  # Only add if not empty
        result$codes <- c(result$codes, category_name)
      }

    } else {
      cat("[WARNING]", paste0("Unknown Single_Choice spec: ", core_spec), "\n")
    }
  }

  # Remove duplicates
  result$codes <- unique(result$codes)

  return(result)
}


#' Calculate Single Choice Trend Enhanced
#'
#' Enhanced version with TrackingSpecs support.
#' Calculates proportions for specified response options across waves.
#' Supports selective tracking via category: syntax.
#'
#' @keywords internal
calculate_single_choice_trend_enhanced <- function(q_code, question_map, wave_data, config,
                                                    wave_structures = NULL) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get TrackingSpecs
  tracking_specs <- get_tracking_specs(question_map, q_code, config = config)

  # Get all unique response codes across all waves
  all_codes <- character(0)
  for (wave_id in wave_ids) {
    wave_df <- wave_data[[wave_id]]
    q_data <- extract_question_data(wave_df, wave_id, q_code, question_map)
    if (!is.null(q_data)) {
      # Use which() to avoid NA issues in logical indexing
      valid_idx <- which(!is.na(q_data))
      all_codes <- unique(c(all_codes, unique(q_data[valid_idx])))
    }
  }

  # Parse specs to determine which codes to track
  specs_parsed <- parse_single_choice_specs(tracking_specs, all_codes)

  # If top3 mode, calculate frequencies and select top 3
  if (specs_parsed$mode == "top3") {
    # Calculate overall frequencies across all waves
    code_frequencies <- list()
    for (code in all_codes) {
      total_count <- 0
      for (wave_id in wave_ids) {
        wave_df <- wave_data[[wave_id]]
        q_data <- extract_question_data(wave_df, wave_id, q_code, question_map)
        if (!is.null(q_data)) {
          total_count <- total_count + sum(q_data == code, na.rm = TRUE)
        }
      }
      code_frequencies[[as.character(code)]] <- total_count
    }

    # Sort by frequency and take top 3
    sorted_codes <- names(sort(unlist(code_frequencies), decreasing = TRUE))
    specs_parsed$codes <- head(sorted_codes, 3)
  }

  # Use specified codes or all codes
  codes_to_track <- if (length(specs_parsed$codes) > 0) {
    specs_parsed$codes
  } else {
    all_codes
  }

  # Calculate proportions for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    wave_df <- wave_data[[wave_id]]
    q_data <- extract_question_data(wave_df, wave_id, q_code, question_map)

    if (is.null(q_data)) {
      wave_results[[wave_id]] <- list(
        proportions = NA,
        n_unweighted = NA,
        n_weighted = NA,
        available = FALSE
      )
      next
    }

    # Calculate proportions for tracked codes only
    result <- calculate_proportions(
      values = q_data,
      weights = wave_df$weight_var,
      codes = codes_to_track
    )

    wave_results[[wave_id]] <- c(result, list(available = TRUE))
  }

  # Calculate changes for each tracked code
  changes <- list()
  for (code in codes_to_track) {
    changes[[as.character(code)]] <- calculate_changes(wave_results, wave_ids, "proportions", code)
  }

  # Significance tests for each tracked code
  sig_tests <- list()
  for (code in codes_to_track) {
    sig_tests[[as.character(code)]] <- perform_significance_tests_proportions(
      wave_results, wave_ids, config, code
    )
  }

  result <- list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "proportions",
    response_codes = codes_to_track,
    tracking_specs = if (!is.null(tracking_specs) && tracking_specs != "") tracking_specs else NULL,
    wave_results = wave_results,
    changes = changes,
    significance = sig_tests
  )

  validate_result_metric_type(result, context = "calculate_single_choice_trend_enhanced")
  return(result)
}


# [REMOVED] calculate_composite_trend(), get_composite_source_questions(),
# calculate_composite_score() - Dead code superseded by calculate_composite_trend_enhanced().
# Removed in Phase 4 refactoring (zero callers confirmed via grep).


# [REMOVED] 7 core statistical functions (calculate_weighted_mean, calculate_nps_score,
# calculate_proportions, calculate_top_box, calculate_bottom_box, calculate_custom_range,
# calculate_distribution) - Now defined in statistical_core.R (single source of truth).
# statistical_core.R is sourced before trend_calculator.R in run_tracker.R.


# ------------------------------------------------------------------------------
# SHARED HELPERS FOR ENHANCED TREND CALCULATORS
# ------------------------------------------------------------------------------

#' Calculate Metrics from Tracking Specs
#'
#' Shared dispatch loop that calculates metrics from a specs_list.
#' Used by both rating and composite enhanced trend calculators.
#'
#' @param values Numeric vector. The data values (question data or composite scores)
#' @param weights Numeric vector. Weight variable from wave data
#' @param specs_list Character vector. Parsed tracking specs (e.g. "mean", "top_box")
#' @param wave_struct List or NULL. Survey structure for this wave (for box: specs)
#' @param wave_col Character or NULL. Wave-specific question code (for box: specs)
#' @return Named list of calculated metrics
#' @keywords internal
calculate_metrics_from_specs <- function(values, weights, specs_list,
                                          wave_struct = NULL, wave_col = NULL) {
  metrics <- list()

  for (spec in specs_list) {
    spec_lower <- tolower(trimws(spec))

    if (spec_lower == "mean") {
      result <- calculate_weighted_mean(values, weights)
      metrics$mean <- result$mean
      metrics$sd <- result$sd

    } else if (spec_lower == "top_box") {
      result <- calculate_top_box(values, weights, n_boxes = 1)
      metrics$top_box <- result$proportion

    } else if (spec_lower == "top2_box") {
      result <- calculate_top_box(values, weights, n_boxes = 2)
      metrics$top2_box <- result$proportion

    } else if (spec_lower == "top3_box") {
      result <- calculate_top_box(values, weights, n_boxes = 3)
      metrics$top3_box <- result$proportion

    } else if (spec_lower == "bottom_box") {
      result <- calculate_bottom_box(values, weights, n_boxes = 1)
      metrics$bottom_box <- result$proportion

    } else if (spec_lower == "bottom2_box") {
      result <- calculate_bottom_box(values, weights, n_boxes = 2)
      metrics$bottom2_box <- result$proportion

    } else if (grepl("^range:", spec_lower)) {
      # Strip "range:" prefix before passing to calculate_custom_range
      range_part <- sub("^range:", "", spec_lower)
      result <- calculate_custom_range(values, weights, range_part)
      metric_name <- gsub("[^a-z0-9_]", "_", spec_lower)  # Clean for list name
      metrics[[metric_name]] <- result$proportion

    } else if (grepl("^box:", spec_lower)) {
      # box:CATEGORY — calculate proportion of values in a BoxCategory group
      box_name <- sub("^box:", "", spec)  # Preserve original case
      box_values <- get_box_options(wave_struct, wave_col, box_name)
      if (!is.null(box_values)) {
        # Calculate weighted proportion of values matching box category
        valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
        if (length(valid_idx) > 0) {
          in_box <- values[valid_idx] %in% box_values
          proportion <- sum(weights[valid_idx][in_box]) /
                       sum(weights[valid_idx]) * 100
        } else {
          proportion <- NA
        }
      } else {
        proportion <- NA
      }
      metric_name <- paste0("box_", gsub("[^a-z0-9_]", "_", tolower(box_name)))
      metrics[[metric_name]] <- proportion

    } else if (spec_lower == "distribution") {
      result <- calculate_distribution(values, weights)
      metrics$distribution <- result$distribution
    }
  }

  return(metrics)
}


#' Calculate Changes and Significance for Enhanced Metrics
#'
#' Shared post-processing that calculates wave-over-wave changes and
#' significance tests for each metric in specs_list. Used by both rating
#' and composite enhanced trend calculators.
#'
#' @param specs_list Character vector. Parsed tracking specs
#' @param wave_results List. Wave results with metrics
#' @param wave_ids Character vector. Wave IDs
#' @param config List. Tracker config
#' @return List with $changes and $significance named lists
#' @keywords internal
calculate_enhanced_changes_and_significance <- function(specs_list, wave_results, wave_ids, config) {
  changes <- list()
  significance <- list()

  for (spec in specs_list) {
    spec_lower <- tolower(trimws(spec))
    metric_name <- if (grepl("^range:", spec_lower)) {
      gsub("[^a-z0-9_]", "_", spec_lower)
    } else if (grepl("^box:", spec_lower)) {
      box_name <- sub("^box:", "", spec_lower)
      paste0("box_", gsub("[^a-z0-9_]", "_", box_name))
    } else {
      spec_lower
    }

    # Skip distribution (too complex for wave-over-wave comparison)
    if (metric_name == "distribution") {
      next
    }

    # Calculate changes
    changes[[metric_name]] <- calculate_changes_for_metric(wave_results, wave_ids, metric_name)

    # Significance testing
    # For means, use t-test; for proportions (boxes/ranges), use z-test
    if (metric_name == "mean") {
      significance[[metric_name]] <- perform_significance_tests_means(wave_results, wave_ids, config)
    } else {
      # Box/range metrics are proportions
      significance[[metric_name]] <- perform_significance_tests_for_metric(
        wave_results, wave_ids, metric_name, config, test_type = "proportion"
      )
    }
  }

  return(list(changes = changes, significance = significance))
}


#' Calculate Rating Trend - Enhanced Version
#'
#' Enhanced version that supports TrackingSpecs for multiple metrics.
#' Backward compatible - defaults to mean if no TrackingSpecs specified.
#'
#' @keywords internal
calculate_rating_trend_enhanced <- function(q_code, question_map, wave_data, config,
                                             wave_structures = NULL) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get TrackingSpecs
  tracking_specs <- get_tracking_specs(question_map, q_code, config = config)

  # Parse specs (default to "mean" if not specified)
  if (is.null(tracking_specs) || tracking_specs == "") {
    specs_list <- c("mean")
  } else {
    specs_list <- trimws(strsplit(tracking_specs, ",")[[1]])
  }

  # Strip =Label from specs — labels are display-only, not used in calculation
  # Store original specs for label lookup later
  specs_original <- specs_list
  specs_list <- vapply(specs_list, function(s) parse_spec_label(s)$core, character(1))

  # Calculate metrics for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    # Extract question data for this wave
    wave_df <- wave_data[[wave_id]]
    q_data <- extract_question_data(wave_df, wave_id, q_code, question_map)

    if (is.null(q_data)) {
      # Wave not available - initialize with NA
      wave_results[[wave_id]] <- list(
        available = FALSE,
        metrics = list()
      )
      next
    }

    # Resolve text → numeric using survey structure (if available)
    wave_struct <- if (!is.null(wave_structures)) wave_structures[[wave_id]] else NULL
    wave_col <- get_wave_question_code(question_map, q_code, wave_id)
    q_data <- resolve_question_values(q_data, wave_struct, wave_col)

    # Calculate each requested metric using shared dispatch
    metrics <- calculate_metrics_from_specs(q_data, wave_df$weight_var, specs_list,
                                             wave_struct, wave_col)

    # Store basic counts (shared across all metrics)
    # Use which() to get numeric indices (avoids NA issues)
    valid_idx <- which(!is.na(q_data) & !is.na(wave_df$weight_var) & wave_df$weight_var > 0)
    wave_results[[wave_id]] <- list(
      available = TRUE,
      metrics = metrics,
      n_unweighted = length(valid_idx),
      n_weighted = sum(wave_df$weight_var[valid_idx]),
      values = q_data,
      weights = wave_df$weight_var
    )
  }

  # Calculate changes and significance using shared helper
  cs <- calculate_enhanced_changes_and_significance(specs_list, wave_results, wave_ids, config)

  result <- list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "rating_enhanced",
    tracking_specs = specs_list,
    tracking_specs_original = specs_original,
    wave_results = wave_results,
    changes = cs$changes,
    significance = cs$significance
  )

  validate_result_metric_type(result, context = "calculate_rating_trend_enhanced")
  return(result)
}


# ==============================================================================
# ENHANCED COMPOSITE CALCULATIONS (Enhancement Phase 1)
# ==============================================================================

#' Calculate Composite Values Per Respondent
#'
#' Calculates composite score for each respondent (row mean of source questions).
#' Returns the composite values vector which can then be treated like rating values.
#'
#' @keywords internal
calculate_composite_values_per_respondent <- function(wave_df, wave_id, source_questions, question_map) {

  # Extract data for each source question
  source_values <- list()
  missing_sources <- character(0)

  for (src_code in source_questions) {
    # Get wave-specific code for this source question
    wave_code <- get_wave_question_code(question_map, src_code, wave_id)

    src_data <- extract_question_data(wave_df, wave_id, src_code, question_map)

    if (!is.null(src_data)) {
      source_values[[src_code]] <- src_data
      cat(paste0("    ✓ Found source question ", src_code, " (", wave_code, ") for ", wave_id, "\n"))
    } else {
      missing_sources <- c(missing_sources, src_code)
      if (!is.na(wave_code)) {
        cat(paste0("    ✗ Source question ", src_code, " mapped to ", wave_code, " but not found in ", wave_id, " data\n"))
      } else {
        cat(paste0("    ✗ Source question ", src_code, " not mapped for ", wave_id, "\n"))
      }
    }
  }

  if (length(source_values) == 0) {
    cat("[WARNING]", paste0("No valid source questions found for composite in ", wave_id,
                   ". Missing: ", paste(missing_sources, collapse = ", ")), "\n")
    return(rep(NA, nrow(wave_df)))
  }

  if (length(missing_sources) > 0) {
    cat(paste0("    Note: ", length(source_values), "/", length(source_questions),
                   " source questions found for ", wave_id, "\n"))
  }

  # Build matrix: rows = respondents, cols = source questions
  n_resp <- nrow(wave_df)
  n_sources <- length(source_values)
  source_matrix <- matrix(NA, nrow = n_resp, ncol = n_sources)

  for (i in seq_along(source_values)) {
    source_matrix[, i] <- source_values[[i]]
  }

  # Calculate row means (composite score per respondent)
  composite_values <- rowMeans(source_matrix, na.rm = TRUE)

  # Set to NA if all sources were NA for a respondent
  # Use which() to avoid NA issues in logical indexing
  all_na_idx <- which(apply(source_matrix, 1, function(row) all(is.na(row))))
  if (length(all_na_idx) > 0) {
    composite_values[all_na_idx] <- NA
  }

  return(composite_values)
}


#' Calculate Composite Trend - Enhanced Version
#'
#' Enhanced version that supports TrackingSpecs for composite questions.
#' Calculates composite values per respondent, then applies requested metrics
#' (mean, top_box, distribution, etc.) to those composite scores.
#'
#' @keywords internal
calculate_composite_trend_enhanced <- function(q_code, question_map, wave_data, config,
                                                wave_structures = NULL) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get source questions for composite
  source_questions <- get_composite_sources(question_map, q_code)

  if (is.null(source_questions) || length(source_questions) == 0) {
    # TRS Refusal: CFG_NO_COMPOSITE_SOURCES
    return(tracker_refuse(
      code = "CFG_NO_COMPOSITE_SOURCES",
      title = "No Source Questions for Composite",
      problem = paste0("Composite question '", q_code, "' has no source questions defined."),
      why_it_matters = "Composites require source questions to calculate.",
      how_to_fix = "Define source questions in the SourceQuestions column of the question mapping."
    ))
  }

  # Get TrackingSpecs
  tracking_specs <- get_tracking_specs(question_map, q_code, config = config)

  # Parse specs (default to "mean" if not specified)
  if (is.null(tracking_specs) || tracking_specs == "") {
    specs_list <- c("mean")
  } else {
    specs_list <- trimws(strsplit(tracking_specs, ",")[[1]])
  }

  # Strip =Label from specs — labels are display-only
  specs_original <- specs_list
  specs_list <- vapply(specs_list, function(s) parse_spec_label(s)$core, character(1))

  # Calculate composite values and metrics for each wave
  wave_results <- list()

  cat(paste0("  Calculating composite for ", length(wave_ids), " waves...\n"))

  for (wave_id in wave_ids) {
    cat(paste0("  Processing ", wave_id, "...\n"))
    wave_df <- wave_data[[wave_id]]

    # Calculate composite values per respondent
    composite_values <- calculate_composite_values_per_respondent(
      wave_df, wave_id, source_questions, question_map
    )

    # Check if we got valid composite values
    # Use which() to get numeric indices (avoids NA issues)
    valid_idx <- which(!is.na(composite_values) & !is.na(wave_df$weight_var) & wave_df$weight_var > 0)

    if (length(valid_idx) == 0) {
      # No valid data for this wave
      wave_results[[wave_id]] <- list(
        available = FALSE,
        metrics = list()
      )
      next
    }

    # Apply requested metrics to composite values using shared dispatch
    wave_struct <- if (!is.null(wave_structures)) wave_structures[[wave_id]] else NULL
    composite_wave_col <- tryCatch(
      get_wave_question_code(question_map, q_code, wave_id),
      error = function(e) q_code
    )
    metrics <- calculate_metrics_from_specs(composite_values, wave_df$weight_var, specs_list,
                                             wave_struct, composite_wave_col)

    # Store results
    wave_results[[wave_id]] <- list(
      available = TRUE,
      metrics = metrics,
      n_unweighted = length(valid_idx),
      n_weighted = sum(wave_df$weight_var[valid_idx]),
      values = composite_values,
      weights = wave_df$weight_var,
      source_questions = source_questions
    )
  }

  # Calculate changes and significance using shared helper
  cs <- calculate_enhanced_changes_and_significance(specs_list, wave_results, wave_ids, config)

  result <- list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "composite_enhanced",
    tracking_specs = specs_list,
    tracking_specs_original = specs_original,
    source_questions = source_questions,
    wave_results = wave_results,
    changes = cs$changes,
    significance = cs$significance
  )

  validate_result_metric_type(result, context = "calculate_composite_trend_enhanced")
  return(result)
}


# ==============================================================================
# MULTI-MENTION SUPPORT (Enhancement Phase 2)
# ==============================================================================

#' Detect Multi-Mention Columns
#'
#' Auto-detects multi-mention option columns based on naming pattern.
#' Pattern: {base_code}_{number} (e.g., Q30_1, Q30_2, Q30_3)
#'
#' @param wave_df Data frame. Wave data
#' @param base_code Character. Base question code (e.g., "Q30")
#' @return Character vector of detected column names, sorted numerically
#'
#' @keywords internal
detect_multi_mention_columns <- function(wave_df, base_code) {

  # Escape special regex characters in base_code
  base_code_escaped <- gsub("([.|()\\^{}+$*?\\[\\]])", "\\\\\\1", base_code)

  # Build pattern: ^{base_code}_{digits}$
  pattern <- paste0("^", base_code_escaped, "_[0-9]+$")

  # Find matches
  matched_cols <- grep(pattern, names(wave_df), value = TRUE)

  if (length(matched_cols) == 0) {
    cat("[WARNING]", paste0("No multi-mention columns found for base code: ", base_code), "\n")
    return(NULL)
  }

  # Extract numeric parts and sort numerically (not lexicographically)
  numeric_parts <- as.integer(sub(paste0("^", base_code_escaped, "_"), "", matched_cols))
  sort_order <- order(numeric_parts)
  matched_cols <- matched_cols[sort_order]

  return(matched_cols)
}


#' Parse Multi-Mention TrackingSpecs
#'
#' Parses TrackingSpecs for multi-mention questions to determine which
#' options to track and what additional metrics to calculate.
#'
#' @param tracking_specs Character. TrackingSpecs string
#' @param base_code Character. Base question code
#' @param wave_df Data frame. Wave data for validation
#' @return List with $mode, $columns, $additional_metrics
#'
#' @keywords internal
parse_multi_mention_specs <- function(tracking_specs, base_code, wave_df) {

  # Default to auto if blank
  if (is.null(tracking_specs) || tracking_specs == "" || tolower(trimws(tracking_specs)) == "auto") {
    return(list(
      mode = "auto",
      columns = detect_multi_mention_columns(wave_df, base_code),
      categories = character(0),
      additional_metrics = character(0)
    ))
  }

  # Parse comma-separated specs
  specs <- trimws(strsplit(tracking_specs, ",")[[1]])

  result <- list(
    mode = "selective",
    columns = character(0),
    categories = character(0),
    additional_metrics = character(0)
  )

  for (spec in specs) {
    # Strip =Label before processing (labels are display-only)
    parsed <- parse_spec_label(spec)
    core_spec <- parsed$core
    core_lower <- tolower(trimws(core_spec))

    if (core_lower == "auto") {
      # Auto-detect all columns
      result$mode <- "auto"
      auto_cols <- detect_multi_mention_columns(wave_df, base_code)
      if (!is.null(auto_cols)) {
        result$columns <- unique(c(result$columns, auto_cols))
      }

    } else if (startsWith(core_lower, "option:")) {
      # Specific option: "option:Q30_1"
      col_name <- sub("^option:", "", core_spec, ignore.case = TRUE)
      col_name <- trimws(col_name)  # Remove any leading/trailing whitespace
      if (col_name != "") {  # Only add if not empty
        result$columns <- c(result$columns, col_name)
      }

    } else if (startsWith(core_lower, "category:")) {
      # Specific category text: "category:Internal store system"
      category_name <- sub("^category:", "", core_spec, ignore.case = TRUE)
      category_name <- trimws(category_name)  # Remove any leading/trailing whitespace
      if (category_name != "") {  # Only add if not empty
        result$mode <- "category"
        result$categories <- c(result$categories, category_name)
      }

    } else if (core_lower %in% c("any", "count_mean", "count_distribution")) {
      # Additional metrics
      result$additional_metrics <- c(result$additional_metrics, core_lower)

    } else {
      cat("[WARNING]", paste0("Unknown Multi_Mention spec: ", core_spec), "\n")
    }
  }

  # Remove duplicates
  result$columns <- unique(result$columns)
  result$categories <- unique(result$categories)
  result$additional_metrics <- unique(result$additional_metrics)

  # Validate columns exist in data (skip if base_code is empty - we're just parsing for additional metrics)
  # Only validate for option: mode, not category: mode
  if (result$mode != "category" && length(result$columns) > 0 && !is.null(base_code) && base_code != "") {
    missing <- setdiff(result$columns, names(wave_df))
    if (length(missing) > 0) {
      cat("[WARNING]", paste0("Multi-mention columns not found in data: ",
                     paste(missing, collapse = ", ")), "\n")
      result$columns <- intersect(result$columns, names(wave_df))
    }
  }

  return(result)
}


#' Calculate Multi-Mention Trend with Category-Based Tracking
#'
#' For multi-mention questions where each column contains TEXT VALUES (not 0/1),
#' this function searches for specific category text across all option columns.
#'
#' @keywords internal
calculate_multi_mention_trend_categories <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get TrackingSpecs
  tracking_specs <- get_tracking_specs(question_map, q_code, config = config)

  # First pass: detect all multi-mention columns and gather unique categories
  wave_base_codes <- list()
  all_categories <- character(0)

  for (wave_id in wave_ids) {
    wave_code <- get_wave_question_code(question_map, q_code, wave_id)
    if (!is.na(wave_code)) {
      wave_base_codes[[wave_id]] <- wave_code
      wave_df <- wave_data[[wave_id]]

      # Detect all multi-mention columns for this question
      mm_columns <- detect_multi_mention_columns(wave_df, wave_code)

      if (!is.null(mm_columns) && length(mm_columns) > 0) {
        # Gather all unique text values from these columns
        for (col in mm_columns) {
          if (col %in% names(wave_df)) {
            col_values <- wave_df[[col]]
            unique_vals <- unique(col_values[!is.na(col_values) & col_values != ""])
            all_categories <- unique(c(all_categories, unique_vals))
          }
        }
      }
    }
  }

  # Parse specs to determine which categories to track
  specs <- parse_multi_mention_specs(tracking_specs, "", wave_data[[wave_ids[1]]])
  categories_to_track <- if (length(specs$categories) > 0) {
    specs$categories
  } else {
    all_categories  # Track all discovered categories if no specific ones requested
  }

  if (length(categories_to_track) == 0) {
    cat("[WARNING]", paste0("No categories found for question: ", q_code), "\n")
    return(NULL)
  }

  # Calculate metrics for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    wave_df <- wave_data[[wave_id]]
    wave_code <- wave_base_codes[[wave_id]]

    if (is.null(wave_code) || is.na(wave_code)) {
      wave_results[[wave_id]] <- list(
        available = FALSE,
        mention_proportions = list(),
        additional_metrics = list()
      )
      next
    }

    # Detect multi-mention columns for this wave
    mm_columns <- detect_multi_mention_columns(wave_df, wave_code)

    if (is.null(mm_columns) || length(mm_columns) == 0) {
      wave_results[[wave_id]] <- list(
        available = FALSE,
        mention_proportions = list(),
        additional_metrics = list()
      )
      next
    }

    # Filter to only existing columns
    mm_columns <- mm_columns[mm_columns %in% names(wave_df)]

    if (length(mm_columns) == 0) {
      wave_results[[wave_id]] <- list(
        available = FALSE,
        mention_proportions = list(),
        additional_metrics = list()
      )
      next
    }

    # Calculate mention proportions for each category
    mention_proportions <- list()

    # Create valid row indices
    valid_rows <- which(!is.na(wave_df$weight_var) & wave_df$weight_var > 0)

    for (category in categories_to_track) {
      # Search for this category text across ALL multi-mention columns
      mentioned_rows <- c()

      for (col in mm_columns) {
        col_data <- wave_df[[col]]
        # Find rows where this column contains the category text (case-insensitive match)
        matching_idx <- which(!is.na(col_data) & trimws(tolower(col_data)) == trimws(tolower(category)))
        matching_rows <- intersect(valid_rows, matching_idx)
        mentioned_rows <- unique(c(mentioned_rows, matching_rows))
      }

      # Calculate weighted proportion
      mentioned_weight <- sum(wave_df$weight_var[mentioned_rows], na.rm = TRUE)
      total_weight <- sum(wave_df$weight_var[valid_rows], na.rm = TRUE)

      proportion <- if (total_weight > 0) {
        (mentioned_weight / total_weight) * 100
      } else {
        NA
      }

      mention_proportions[[category]] <- proportion
    }

    # Store results
    wave_results[[wave_id]] <- list(
      available = TRUE,
      mention_proportions = mention_proportions,
      additional_metrics = list(),  # Category mode doesn't support additional metrics yet
      tracked_columns = mm_columns,
      tracked_categories = categories_to_track,
      n_unweighted = length(valid_rows),
      n_weighted = sum(wave_df$weight_var[valid_rows], na.rm = TRUE)
    )
  }

  # Calculate changes for each category
  changes <- list()
  for (category in categories_to_track) {
    changes[[category]] <- calculate_changes_for_multi_mention_option(
      wave_results, wave_ids, category
    )
  }

  # Significance testing for each category
  significance <- list()
  for (category in categories_to_track) {
    significance[[category]] <- perform_significance_tests_multi_mention(
      wave_results, wave_ids, category, config
    )
  }

  result <- list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "category_mentions",
    response_categories = categories_to_track,
    tracking_specs = tracking_specs,
    wave_results = wave_results,
    changes = changes,
    significance = significance,
    metadata = metadata
  )

  validate_result_metric_type(result, context = "calculate_multi_mention_trend_categories")
  return(result)
}


# ------------------------------------------------------------------------------
# MULTI-MENTION TREND HELPERS
# ------------------------------------------------------------------------------

#' Calculate Mention Proportions for a Single Wave
#'
#' Computes weighted mention proportions for each option column in a wave.
#'
#' @param option_columns Character vector. Column names to process
#' @param wave_df Data frame. Wave data with weight_var column
#' @param valid_rows Integer vector. Row indices with valid weights
#' @return Named list of proportions (percentage mentioning each option)
#' @keywords internal
calculate_mention_proportions_for_wave <- function(option_columns, wave_df, valid_rows) {
  mention_proportions <- list()

  for (col_name in option_columns) {
    if (!col_name %in% names(wave_df)) {
      mention_proportions[[col_name]] <- NA
      next
    }

    # Get column data
    col_data <- wave_df[[col_name]]

    # Check if column data is valid
    if (is.null(col_data) || all(is.na(col_data))) {
      mention_proportions[[col_name]] <- NA
      next
    }

    # Calculate % mentioning (value == 1)
    # Use which() on valid_rows subset to avoid NA issues
    valid_col_data <- col_data[valid_rows]
    mentioned_idx <- which(!is.na(valid_col_data) & valid_col_data == 1)
    mentioned_rows <- valid_rows[mentioned_idx]

    mentioned_weight <- sum(wave_df$weight_var[mentioned_rows], na.rm = TRUE)
    total_weight <- sum(wave_df$weight_var[valid_rows], na.rm = TRUE)

    proportion <- if (total_weight > 0) {
      (mentioned_weight / total_weight) * 100
    } else {
      NA
    }

    mention_proportions[[col_name]] <- proportion
  }

  return(mention_proportions)
}


#' Calculate Additional Multi-Mention Metrics for a Single Wave
#'
#' Computes additional metrics (any mention, count mean, count distribution)
#' for a multi-mention question in a single wave.
#'
#' @param specs List. Parsed multi-mention specs with $additional_metrics
#' @param option_columns Character vector. Column names to process
#' @param wave_df Data frame. Wave data with weight_var column
#' @param valid_rows Integer vector. Row indices with valid weights
#' @return Named list of additional metrics
#' @keywords internal
calculate_mention_additional_metrics_for_wave <- function(specs, option_columns,
                                                          wave_df, valid_rows) {
  additional_metrics <- list()

  if ("any" %in% specs$additional_metrics) {
    # % mentioning at least one option
    option_matrix <- as.matrix(wave_df[valid_rows, option_columns, drop = FALSE])
    mentioned_any <- rowSums(option_matrix == 1, na.rm = TRUE) > 0
    mentioned_any_idx <- which(mentioned_any)
    any_weight <- sum(wave_df$weight_var[valid_rows][mentioned_any_idx], na.rm = TRUE)
    total_weight <- sum(wave_df$weight_var[valid_rows], na.rm = TRUE)
    additional_metrics$any_mention_pct <- if (total_weight > 0) {
      (any_weight / total_weight) * 100
    } else {
      NA
    }
  }

  if ("count_mean" %in% specs$additional_metrics) {
    # Mean number of mentions
    option_matrix <- as.matrix(wave_df[valid_rows, option_columns, drop = FALSE])
    mention_counts <- rowSums(option_matrix == 1, na.rm = TRUE)
    weights_valid <- wave_df$weight_var[valid_rows]
    additional_metrics$count_mean <- if (sum(weights_valid, na.rm = TRUE) > 0) {
      sum(mention_counts * weights_valid, na.rm = TRUE) / sum(weights_valid, na.rm = TRUE)
    } else {
      NA
    }
  }

  if ("count_distribution" %in% specs$additional_metrics) {
    # Distribution of mention counts
    option_matrix <- as.matrix(wave_df[valid_rows, option_columns, drop = FALSE])
    mention_counts <- rowSums(option_matrix == 1, na.rm = TRUE)
    weights_valid <- wave_df$weight_var[valid_rows]
    total_weight <- sum(weights_valid, na.rm = TRUE)

    count_dist <- list()
    for (count_val in 0:length(option_columns)) {
      matched_idx <- which(mention_counts == count_val)
      count_weight <- sum(weights_valid[matched_idx], na.rm = TRUE)
      count_dist[[as.character(count_val)]] <- if (total_weight > 0) {
        (count_weight / total_weight) * 100
      } else {
        NA
      }
    }
    additional_metrics$count_distribution <- count_dist
  }

  return(additional_metrics)
}


#' Calculate Multi-Mention Trend
#'
#' Calculates percentage mentioning each option across waves for multi-mention questions.
#' Supports TrackingSpecs for selective option tracking and additional metrics.
#'
#' @keywords internal
calculate_multi_mention_trend <- function(q_code, question_map, wave_data, config,
                                          wave_structures = NULL) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get TrackingSpecs
  tracking_specs <- get_tracking_specs(question_map, q_code, config = config)

  # Parse specs to check mode (need to parse once to determine if category mode)
  # Find first wave where question exists (not NA)
  first_wave_code <- NA
  first_wave_df <- NULL
  for (wave_id in wave_ids) {
    wave_code <- get_wave_question_code(question_map, q_code, wave_id)
    if (!is.na(wave_code)) {
      first_wave_code <- wave_code
      first_wave_df <- wave_data[[wave_id]]
      break
    }
  }

  # If question not found in any wave, return NULL
  if (is.na(first_wave_code) || is.null(first_wave_df)) {
    cat("[WARNING]", paste0("Question ", q_code, " not found in any wave"), "\n")
    return(NULL)
  }

  initial_specs <- parse_multi_mention_specs(tracking_specs, first_wave_code, first_wave_df)

  # If category mode, use category-based tracking
  if (initial_specs$mode == "category") {
    return(calculate_multi_mention_trend_categories(q_code, question_map, wave_data, config))
  }

  # Otherwise, continue with binary column-based tracking
  # Initialize structure to track all detected columns across all waves
  all_columns <- character(0)

  # First pass: detect columns in each wave, RESPECTING TrackingSpecs
  wave_base_codes <- list()
  for (wave_id in wave_ids) {
    wave_code <- get_wave_question_code(question_map, q_code, wave_id)
    if (!is.na(wave_code)) {
      wave_base_codes[[wave_id]] <- wave_code
      wave_df <- wave_data[[wave_id]]

      # Parse specs for this wave to determine which columns to track
      specs <- parse_multi_mention_specs(tracking_specs, wave_code, wave_df)
      detected_cols <- specs$columns

      if (!is.null(detected_cols) && length(detected_cols) > 0) {
        all_columns <- unique(c(all_columns, detected_cols))
      }
    }
  }

  if (length(all_columns) == 0) {
    cat("[WARNING]", paste0("No multi-mention columns found for question: ", q_code), "\n")
    return(NULL)
  }

  # Calculate metrics for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    wave_df <- wave_data[[wave_id]]
    wave_code <- wave_base_codes[[wave_id]]

    if (is.null(wave_code) || is.na(wave_code)) {
      wave_results[[wave_id]] <- list(
        available = FALSE,
        mention_proportions = list(),
        additional_metrics = list()
      )
      next
    }

    # Parse specs for this wave
    specs <- parse_multi_mention_specs(tracking_specs, wave_code, wave_df)

    # Use detected columns from specs
    option_columns <- specs$columns

    if (is.null(option_columns) || length(option_columns) == 0) {
      wave_results[[wave_id]] <- list(
        available = FALSE,
        mention_proportions = list(),
        additional_metrics = list()
      )
      next
    }

    # Create valid row indices (use which() to ensure numeric indices)
    valid_rows <- which(!is.na(wave_df$weight_var) & wave_df$weight_var > 0)

    # Calculate mention proportions for each option
    mention_proportions <- calculate_mention_proportions_for_wave(
      option_columns, wave_df, valid_rows
    )

    # Calculate additional metrics if requested
    additional_metrics <- calculate_mention_additional_metrics_for_wave(
      specs, option_columns, wave_df, valid_rows
    )

    # Store results
    wave_results[[wave_id]] <- list(
      available = TRUE,
      mention_proportions = mention_proportions,
      additional_metrics = additional_metrics,
      tracked_columns = option_columns,
      n_unweighted = length(valid_rows),
      n_weighted = sum(wave_df$weight_var[valid_rows], na.rm = TRUE)
    )
  }

  # Calculate changes for each option
  changes <- list()
  for (col_name in all_columns) {
    changes[[col_name]] <- calculate_changes_for_multi_mention_option(
      wave_results, wave_ids, col_name
    )
  }

  # Calculate changes for additional metrics
  additional_specs <- parse_multi_mention_specs(tracking_specs, "", wave_data[[wave_ids[1]]])
  if ("any" %in% additional_specs$additional_metrics) {
    changes$any_mention_pct <- calculate_changes_for_multi_mention_metric(
      wave_results, wave_ids, "any_mention_pct"
    )
  }
  if ("count_mean" %in% additional_specs$additional_metrics) {
    changes$count_mean <- calculate_changes_for_multi_mention_metric(
      wave_results, wave_ids, "count_mean"
    )
  }

  # Significance testing for each option
  significance <- list()
  for (col_name in all_columns) {
    significance[[col_name]] <- perform_significance_tests_multi_mention(
      wave_results, wave_ids, col_name, config
    )
  }

  # Significance for additional metrics
  if ("any" %in% additional_specs$additional_metrics) {
    significance$any_mention_pct <- perform_significance_tests_multi_mention_metric(
      wave_results, wave_ids, "any_mention_pct", config
    )
  }

  result <- list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "multi_mention",
    tracking_specs = tracking_specs,
    tracked_columns = all_columns,
    wave_results = wave_results,
    changes = changes,
    significance = significance
  )

  validate_result_metric_type(result, context = "calculate_multi_mention_trend")
  return(result)
}
