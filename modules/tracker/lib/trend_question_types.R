# ==============================================================================
# TurasTracker - Trend Question Type Calculator Functions
# ==============================================================================
#
# PURPOSE:
# This file contains question type-specific trend calculation functions extracted
# from trend_calculator.R for improved code organization and maintainability.
#
# BACKGROUND:
# These functions were extracted from trend_calculator.R (originally ~2,700 lines)
# as part of ongoing refactoring to decompose the monolithic trend calculator
# into more manageable, focused modules.
#
# QUESTION TYPES SUPPORTED:
# - Rating questions (mean, top/bottom box, distributions, custom ranges)
# - NPS (Net Promoter Score)
# - Single choice questions (proportions for each response option)
# - Composite scores (aggregates of source questions)
# - Multi-mention questions (binary columns and category-based tracking)
#
# DEPENDENCIES:
# This file depends on functions from other tracker/lib modules:
#
#   trend_statistics.R:
#     - calculate_weighted_mean()
#     - calculate_nps_score()
#     - calculate_proportions()
#     - calculate_top_box()
#     - calculate_bottom_box()
#     - calculate_custom_range()
#     - calculate_distribution()
#
#   trend_significance.R:
#     - perform_significance_tests_means()
#     - perform_significance_tests_nps()
#     - perform_significance_tests_proportions()
#     - perform_significance_tests_for_metric()
#     - perform_significance_tests_multi_mention()
#     - perform_significance_tests_multi_mention_metric()
#
#   trend_changes.R:
#     - calculate_changes()
#     - calculate_changes_for_metric()
#     - calculate_changes_for_multi_mention_option()
#     - calculate_changes_for_multi_mention_metric()
#
#   trend_helpers.R:
#     - get_tracking_specs()
#     - parse_single_choice_specs()
#     - parse_multi_mention_specs()
#     - get_composite_source_questions()
#     - get_composite_sources()
#     - calculate_composite_score()
#     - calculate_composite_values_per_respondent()
#     - detect_multi_mention_columns()
#
#   tracker_data_loader.R:
#     - extract_question_data()
#     - get_wave_question_code()
#     - get_question_metadata()
#
# TRS COMPLIANCE:
# All functions follow TRS v1.0 standards:
# - Use tracker_refuse() for configuration validation errors
# - Handle missing data gracefully (return NA, not errors)
# - Return structured results with metadata
#
# VERSION: 1.0.0 - Initial extraction from trend_calculator.R
# ==============================================================================


#' Calculate Rating Question Trend
#'
#' Calculates mean scores across waves for rating/index questions.
#'
#' SHARED CODE NOTE: Mean calculation logic should be in /shared/calculations.R
#'
#' @keywords internal
calculate_rating_trend <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Calculate mean for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    # Extract question data for this wave
    wave_df <- wave_data[[wave_id]]
    wave_code <- get_wave_question_code(question_map, q_code, wave_id)
    q_data <- extract_question_data(wave_df, wave_id, q_code, question_map)

    if (is.null(q_data)) {
      if (!is.na(wave_code)) {
        cat(paste0("  ", wave_id, ": Mapped to ", wave_code, " but not found in data\n"))
      } else {
        cat(paste0("  ", wave_id, ": Not mapped for this wave\n"))
      }
      wave_results[[wave_id]] <- list(
        mean = NA,
        sd = NA,
        n_unweighted = NA,
        n_weighted = NA,
        available = FALSE,
        values = NULL,
        weights = NULL
      )
      next
    } else {
      cat(paste0("  ", wave_id, ": Found as ", wave_code, " (n=", length(q_data), ")\n"))
    }

    # Calculate weighted mean
    result <- calculate_weighted_mean(
      values = q_data,
      weights = wave_df$weight_var
    )

    # Store raw values and weights for distribution calculation
    wave_results[[wave_id]] <- c(
      result,
      list(
        available = TRUE,
        values = q_data,
        weights = wave_df$weight_var
      )
    )
  }

  # Calculate wave-over-wave changes
  changes <- calculate_changes(wave_results, wave_ids, "mean")

  # Perform significance testing
  sig_tests <- perform_significance_tests_means(wave_results, wave_ids, config)

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "mean",
    wave_results = wave_results,
    changes = changes,
    significance = sig_tests
  ))
}


#' Calculate Rating Trend - Enhanced Version
#'
#' Enhanced version that supports TrackingSpecs for multiple metrics.
#' Backward compatible - defaults to mean if no TrackingSpecs specified.
#'
#' @keywords internal
calculate_rating_trend_enhanced <- function(q_code, question_map, wave_data, config) {

  # Debug helper
  .rating_debug <- function(...) {
    msg <- paste0(format(Sys.time(), "%H:%M:%S"), " [RATING] ", paste(..., collapse = " "), "\n")
    cat(msg)
    log_path <- file.path(getwd(), "..", "..", "tracker_gui_debug.log")
    if (!file.exists(dirname(log_path))) {
      log_path <- file.path(tempdir(), "tracker_debug.log")
    }
    tryCatch(cat(msg, file = log_path, append = TRUE), error = function(e) NULL)
  }

  .rating_debug("=== calculate_rating_trend_enhanced called for:", q_code, "===")

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)
  .rating_debug("metadata:", if (is.null(metadata)) "NULL" else "OK")

  # Get TrackingSpecs
  tracking_specs <- get_tracking_specs(question_map, q_code)

  # Parse specs (default to "mean" if not specified)
  if (is.null(tracking_specs) || tracking_specs == "") {
    specs_list <- c("mean")
  } else {
    specs_list <- trimws(strsplit(tracking_specs, ",")[[1]])
  }

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

    # Calculate each requested metric
    metrics <- list()

    for (spec in specs_list) {
      spec_lower <- tolower(trimws(spec))

      if (spec_lower == "mean") {
        result <- calculate_weighted_mean(q_data, wave_df$weight_var)
        metrics$mean <- result$mean
        metrics$sd <- result$sd

      } else if (spec_lower == "top_box") {
        result <- calculate_top_box(q_data, wave_df$weight_var, n_boxes = 1)
        metrics$top_box <- result$proportion

      } else if (spec_lower == "top2_box") {
        result <- calculate_top_box(q_data, wave_df$weight_var, n_boxes = 2)
        metrics$top2_box <- result$proportion

      } else if (spec_lower == "top3_box") {
        result <- calculate_top_box(q_data, wave_df$weight_var, n_boxes = 3)
        metrics$top3_box <- result$proportion

      } else if (spec_lower == "bottom_box") {
        result <- calculate_bottom_box(q_data, wave_df$weight_var, n_boxes = 1)
        metrics$bottom_box <- result$proportion

      } else if (spec_lower == "bottom2_box") {
        result <- calculate_bottom_box(q_data, wave_df$weight_var, n_boxes = 2)
        metrics$bottom2_box <- result$proportion

      } else if (grepl("^range:", spec_lower)) {
        result <- calculate_custom_range(q_data, wave_df$weight_var, spec)
        metric_name <- gsub("[^a-z0-9_]", "_", spec_lower)  # Clean for list name
        metrics[[metric_name]] <- result$proportion

      } else if (spec_lower == "distribution") {
        result <- calculate_distribution(q_data, wave_df$weight_var)
        metrics$distribution <- result$distribution
      }
    }

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

  # Calculate changes and significance for each metric
  changes <- list()
  significance <- list()

  for (spec in specs_list) {
    spec_lower <- tolower(trimws(spec))
    metric_name <- if (grepl("^range:", spec_lower)) {
      gsub("[^a-z0-9_]", "_", spec_lower)
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

  result <- list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "rating_enhanced",
    tracking_specs = specs_list,
    wave_results = wave_results,
    changes = changes,
    significance = significance
  )

  .rating_debug("Returning result for", q_code, "with metric_type:", result$metric_type)
  .rating_debug("=== calculate_rating_trend_enhanced COMPLETE for:", q_code, "===")

  return(result)
}


#' Calculate NPS Trend
#'
#' Calculates Net Promoter Score across waves.
#' NPS = % Promoters (9-10) - % Detractors (0-6)
#'
#' @keywords internal
calculate_nps_trend <- function(q_code, question_map, wave_data, config) {

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

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "nps",
    wave_results = wave_results,
    changes = changes,
    significance = sig_tests
  ))
}


#' Calculate Single Choice Trend
#'
#' Calculates proportions for each response option across waves.
#'
#' @keywords internal
calculate_single_choice_trend <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

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

    # Calculate proportions for each code
    result <- calculate_proportions(
      values = q_data,
      weights = wave_df$weight_var,
      codes = all_codes
    )

    wave_results[[wave_id]] <- c(result, list(available = TRUE))
  }

  # Calculate changes for each response code
  changes <- list()
  for (code in all_codes) {
    changes[[as.character(code)]] <- calculate_changes(wave_results, wave_ids, "proportions", code)
  }

  # Significance tests for each code
  sig_tests <- list()
  for (code in all_codes) {
    sig_tests[[as.character(code)]] <- perform_significance_tests_proportions(
      wave_results, wave_ids, config, code
    )
  }

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "proportions",
    response_codes = all_codes,
    wave_results = wave_results,
    changes = changes,
    significance = sig_tests
  ))
}


#' Calculate Single Choice Trend Enhanced
#'
#' Enhanced version with TrackingSpecs support.
#' Calculates proportions for specified response options across waves.
#' Supports selective tracking via category: syntax.
#'
#' @keywords internal
calculate_single_choice_trend_enhanced <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get TrackingSpecs
  tracking_specs <- get_tracking_specs(question_map, q_code)

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

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "proportions",
    response_codes = codes_to_track,
    tracking_specs = if (!is.null(tracking_specs) && tracking_specs != "") tracking_specs else NULL,
    wave_results = wave_results,
    changes = changes,
    significance = sig_tests
  ))
}


#' Calculate Composite Score Trend
#'
#' Calculates composite score trend across waves.
#' Composite is mean (or other aggregation) of source questions.
#'
#' SHARED CODE NOTE: Composite calculation should use /shared/composite_calculator.R
#' For MVT, using simple mean calculation inline.
#'
#' @keywords internal
calculate_composite_trend <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get source questions for this composite
  # For MVT, assume metadata has SourceQuestions field (comma-separated)
  source_questions <- get_composite_source_questions(question_map, q_code)

  if (is.null(source_questions) || length(source_questions) == 0) {
    warning(paste0("  No source questions defined for composite ", q_code))
    return(NULL)
  }

  # Calculate composite for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    wave_df <- wave_data[[wave_id]]

    # Calculate composite score
    result <- calculate_composite_score(
      wave_df = wave_df,
      wave_id = wave_id,
      source_questions = source_questions,
      question_map = question_map
    )

    if (is.null(result)) {
      wave_results[[wave_id]] <- list(
        mean = NA,
        sd = NA,
        n_unweighted = NA,
        n_weighted = NA,
        available = FALSE
      )
    } else {
      wave_results[[wave_id]] <- c(result, list(available = TRUE))
    }
  }

  # Calculate wave-over-wave changes
  changes <- calculate_changes(wave_results, wave_ids, "mean")

  # Perform significance testing
  sig_tests <- perform_significance_tests_means(wave_results, wave_ids, config)

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "composite",
    source_questions = source_questions,
    wave_results = wave_results,
    changes = changes,
    significance = sig_tests
  ))
}


#' Calculate Composite Trend - Enhanced Version
#'
#' Enhanced version that supports TrackingSpecs for composite questions.
#' Calculates composite values per respondent, then applies requested metrics
#' (mean, top_box, distribution, etc.) to those composite scores.
#'
#' @keywords internal
calculate_composite_trend_enhanced <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get source questions for composite
  source_questions <- get_composite_sources(question_map, q_code)

  if (is.null(source_questions) || length(source_questions) == 0) {
    # TRS Refusal: CFG_NO_COMPOSITE_SOURCES
    tracker_refuse(
      code = "CFG_NO_COMPOSITE_SOURCES",
      title = "No Source Questions for Composite",
      problem = paste0("Composite question '", q_code, "' has no source questions defined."),
      why_it_matters = "Composites require source questions to calculate.",
      how_to_fix = "Define source questions in the SourceQuestions column of the question mapping."
    )
  }

  # Get TrackingSpecs
  tracking_specs <- get_tracking_specs(question_map, q_code)

  # Parse specs (default to "mean" if not specified)
  if (is.null(tracking_specs) || tracking_specs == "") {
    specs_list <- c("mean")
  } else {
    specs_list <- trimws(strsplit(tracking_specs, ",")[[1]])
  }

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

    # Now apply requested metrics to composite values
    # (same logic as rating questions)
    metrics <- list()

    for (spec in specs_list) {
      spec_lower <- tolower(trimws(spec))

      if (spec_lower == "mean") {
        result <- calculate_weighted_mean(composite_values, wave_df$weight_var)
        metrics$mean <- result$mean
        metrics$sd <- result$sd

      } else if (spec_lower == "top_box") {
        result <- calculate_top_box(composite_values, wave_df$weight_var, n_boxes = 1)
        metrics$top_box <- result$proportion

      } else if (spec_lower == "top2_box") {
        result <- calculate_top_box(composite_values, wave_df$weight_var, n_boxes = 2)
        metrics$top2_box <- result$proportion

      } else if (spec_lower == "top3_box") {
        result <- calculate_top_box(composite_values, wave_df$weight_var, n_boxes = 3)
        metrics$top3_box <- result$proportion

      } else if (spec_lower == "bottom_box") {
        result <- calculate_bottom_box(composite_values, wave_df$weight_var, n_boxes = 1)
        metrics$bottom_box <- result$proportion

      } else if (spec_lower == "bottom2_box") {
        result <- calculate_bottom_box(composite_values, wave_df$weight_var, n_boxes = 2)
        metrics$bottom2_box <- result$proportion

      } else if (grepl("^range:", spec_lower)) {
        result <- calculate_custom_range(composite_values, wave_df$weight_var, spec)
        metric_name <- gsub("[^a-z0-9_]", "_", spec_lower)
        metrics[[metric_name]] <- result$proportion

      } else if (spec_lower == "distribution") {
        result <- calculate_distribution(composite_values, wave_df$weight_var)
        metrics$distribution <- result$distribution
      }
    }

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

  # Calculate changes and significance for each metric
  changes <- list()
  significance <- list()

  for (spec in specs_list) {
    spec_lower <- tolower(trimws(spec))
    metric_name <- if (grepl("^range:", spec_lower)) {
      gsub("[^a-z0-9_]", "_", spec_lower)
    } else {
      spec_lower
    }

    # Skip distribution
    if (metric_name == "distribution") {
      next
    }

    # Calculate changes
    changes[[metric_name]] <- calculate_changes_for_metric(wave_results, wave_ids, metric_name)

    # Significance testing
    if (metric_name == "mean") {
      significance[[metric_name]] <- perform_significance_tests_means(wave_results, wave_ids, config)
    } else {
      # Box/range metrics are proportions
      significance[[metric_name]] <- perform_significance_tests_for_metric(
        wave_results, wave_ids, metric_name, config, test_type = "proportion"
      )
    }
  }

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "composite_enhanced",
    tracking_specs = specs_list,
    source_questions = source_questions,
    wave_results = wave_results,
    changes = changes,
    significance = significance
  ))
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
  tracking_specs <- get_tracking_specs(question_map, q_code)

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
    warning(paste0("No categories found for question: ", q_code))
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

  return(list(
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
  ))
}


#' Calculate Multi-Mention Trend
#'
#' Calculates percentage mentioning each option across waves for multi-mention questions.
#' Supports TrackingSpecs for selective option tracking and additional metrics.
#'
#' @keywords internal
calculate_multi_mention_trend <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get TrackingSpecs
  tracking_specs <- get_tracking_specs(question_map, q_code)

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
    warning(paste0("Question ", q_code, " not found in any wave"))
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
    warning(paste0("No multi-mention columns found for question: ", q_code))
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

    # Calculate mention proportions for each option
    mention_proportions <- list()

    # Create valid row indices (use which() to ensure numeric indices)
    valid_rows <- which(!is.na(wave_df$weight_var) & wave_df$weight_var > 0)

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

    # Calculate additional metrics if requested
    additional_metrics <- list()

    # Note: valid_rows already defined above

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

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "multi_mention",
    tracking_specs = tracking_specs,
    tracked_columns = all_columns,
    wave_results = wave_results,
    changes = changes,
    significance = significance
  ))
}
