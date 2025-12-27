# ==============================================================================
# TurasTracker - Trend Calculator
# ==============================================================================
#
# Calculates trends and wave-over-wave changes for tracked questions.
# Supports: Rating questions, Single choice, NPS, Index scores
#
# VERSION: 2.3.0 - Added parallel calculation support
# SIZE: ~2,700 lines (target: decompose during maintenance)
#
# PARALLEL PROCESSING:
# When processing many tracked questions (10+), trend calculations can be
# parallelized using the future/future.apply framework.
#
# To enable: calculate_all_trends(..., parallel = TRUE)
# Requirements: future, future.apply packages installed
# Fallback: Sequential calculation if packages not available
#
# ARCHITECTURE NOTE:
# Core statistical functions have been extracted to lib/statistical_core.R
# for reference. During future maintenance, this file should be refactored to:
#
#   trend_calculator.R (orchestration, ~800 lines)
#     - calculate_all_trends()
#     - Question type dispatchers
#
#   lib/statistical_core.R (calculations, ~350 lines)
#     - t_test_for_means(), z_test_for_proportions()
#     - calculate_weighted_mean(), calculate_nps_score()
#     - calculate_top_box(), calculate_bottom_box()
#
#   lib/trend_significance.R (significance tests)
#     - perform_significance_tests_* functions
#
#   lib/trend_changes.R (wave-over-wave changes)
#     - calculate_changes_* functions
#
# SHARED UTILITIES: Uses /modules/shared/lib/ for common functions
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


#' Normalize Question Type
#'
#' Maps question types to standardized internal types.
#' Supports both TurasTabs and legacy TurasTracker naming conventions.
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
    # Set up parallel plan if not already configured
    if (!future::plan() %in% c("multisession", "multicore", "cluster")) {
      old_plan <- future::plan(future::multisession,
                               workers = min(n_questions, parallel::detectCores() - 1))
      on.exit(future::plan(old_plan), add = TRUE)
    }

    cat("Calculating trends in parallel...\n")

    # Define the calculation function for a single question
    calculate_single_trend <- function(q_code) {
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
        if (q_type == "rating") {
          calculate_rating_trend_enhanced(q_code, question_map, wave_data, config)
        } else if (q_type == "nps") {
          calculate_nps_trend(q_code, question_map, wave_data, config)
        } else if (q_type == "single_choice") {
          calculate_single_choice_trend_enhanced(q_code, question_map, wave_data, config)
        } else if (q_type == "multi_choice" || q_type_raw == "Multi_Mention") {
          calculate_multi_mention_trend(q_code, question_map, wave_data, config)
        } else if (q_type == "composite") {
          calculate_composite_trend_enhanced(q_code, question_map, wave_data, config)
        } else if (q_type == "open_end") {
          return(list(
            q_code = q_code,
            result = NULL,
            skipped = list(
              question_code = q_code,
              reason = "Open-end questions cannot be tracked",
              stage = "type_check"
            )
          ))
        } else if (q_type == "ranking") {
          return(list(
            q_code = q_code,
            result = NULL,
            skipped = list(
              question_code = q_code,
              reason = "Ranking questions not yet supported in tracker",
              stage = "type_check"
            )
          ))
        } else {
          return(list(
            q_code = q_code,
            result = NULL,
            skipped = list(
              question_code = q_code,
              reason = paste0("Question type '", q_type_raw, "' not supported"),
              stage = "type_check"
            )
          ))
        }
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

      # If we got a trend result (not an early return), wrap it
      # Fixed operator precedence: use explicit parentheses for clarity
      # Condition: result is non-null AND (either not a list, OR a list without skipped field)
      if (!is.null(trend_result) &&
          (!is.list(trend_result) || is.null(trend_result$skipped))) {
        return(list(
          q_code = q_code,
          result = trend_result,
          skipped = NULL
        ))
      }

      return(trend_result)
    }

    # Run calculations in parallel
    parallel_results <- future.apply::future_lapply(
      tracked_questions,
      calculate_single_trend,
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

      trend_result <- tryCatch({
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
          skipped_questions[[q_code]] <- list(
            question_code = q_code,
            reason = "Open-end questions cannot be tracked",
            stage = "type_check"
          )
          message(paste0("[TRS PARTIAL] Open-end question ", q_code, " cannot be tracked - skipping"))
          NULL
        } else if (q_type == "ranking") {
          # TRS v1.0: Record unsupported type for PARTIAL status
          skipped_questions[[q_code]] <- list(
            question_code = q_code,
            reason = "Ranking questions not yet supported in tracker",
            stage = "type_check"
          )
          message(paste0("[TRS PARTIAL] Ranking question ", q_code, " not supported - skipping"))
          NULL
        } else {
          # TRS v1.0: Record unsupported type for PARTIAL status
          skipped_questions[[q_code]] <- list(
            question_code = q_code,
            reason = paste0("Question type '", q_type_raw, "' not supported"),
            stage = "type_check"
          )
          message(paste0("[TRS PARTIAL] Question type '", q_type_raw, "' not supported - skipping"))
          NULL
        }
      }, error = function(e) {
        # TRS v1.0: Record error for PARTIAL status
        skipped_questions[[q_code]] <<- list(
          question_code = q_code,
          reason = paste0("Error calculating trend: ", e$message),
          stage = "calculation"
        )
        message(paste0("[TRS PARTIAL] Error calculating trend for ", q_code, ": ", e$message))
        NULL
      })

      if (!is.null(trend_result)) {
        trend_results[[q_code]] <- trend_result
        cat(paste0("  ✓ Trend calculated\n"))
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
    spec_lower <- tolower(trimws(spec))

    if (spec_lower == "all") {
      # Track all codes
      result$mode <- "all"
      result$codes <- unique(c(result$codes, all_codes))

    } else if (spec_lower == "top3") {
      # Track top 3 most frequent codes (will need to determine from data)
      result$mode <- "top3"
      # Codes will be determined after calculating frequencies

    } else if (startsWith(spec_lower, "category:")) {
      # Specific category: "category:last week"
      category_name <- sub("^category:", "", spec, ignore.case = TRUE)
      category_name <- trimws(category_name)  # Remove any leading/trailing whitespace
      if (category_name != "") {  # Only add if not empty
        result$codes <- c(result$codes, category_name)
      }

    } else {
      warning(paste0("Unknown Single_Choice spec: ", spec))
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


#' Get Composite Source Questions
#'
#' Retrieves source question codes for a composite from question mapping.
#'
#' @keywords internal
get_composite_source_questions <- function(question_map, composite_code) {

  # Check if metadata has SourceQuestions field
  metadata_df <- question_map$question_metadata

  # Use which() to avoid NA issues in logical indexing
  comp_row_idx <- which(metadata_df$QuestionCode == composite_code)
  if (length(comp_row_idx) == 0) {
    return(NULL)
  }
  comp_row <- metadata_df[comp_row_idx[1], ]

  # Check for SourceQuestions column
  if (!"SourceQuestions" %in% names(metadata_df)) {
    return(NULL)
  }

  source_str <- comp_row$SourceQuestions[1]

  if (is.na(source_str) || source_str == "") {
    return(NULL)
  }

  # Parse comma-separated list
  sources <- trimws(strsplit(source_str, ",")[[1]])

  return(sources)
}


#' Calculate Composite Score
#'
#' Calculates composite score for a single wave.
#' For MVT, uses simple mean of source questions.
#'
#' SHARED CODE NOTE: This should use /shared/composite_calculator.R::calculate_composite_mean()
#' Identical logic to TurasTabs composite calculation.
#'
#' @keywords internal
calculate_composite_score <- function(wave_df, wave_id, source_questions, question_map) {

  # Extract data for each source question
  source_values <- list()

  for (src_code in source_questions) {
    src_data <- extract_question_data(wave_df, wave_id, src_code, question_map)

    if (!is.null(src_data)) {
      source_values[[src_code]] <- src_data
    }
  }

  if (length(source_values) == 0) {
    return(NULL)
  }

  # Calculate mean across source questions for each respondent
  # Build matrix: rows = respondents, cols = source questions
  n_resp <- nrow(wave_df)
  n_sources <- length(source_values)

  source_matrix <- matrix(NA, nrow = n_resp, ncol = n_sources)

  for (i in seq_along(source_values)) {
    source_matrix[, i] <- source_values[[i]]
  }

  # Calculate row means (composite score per respondent)
  composite_values <- rowMeans(source_matrix, na.rm = TRUE)

  # Handle cases where all source questions are NA for a respondent
  # Use which() to avoid NA issues in logical indexing
  all_na_idx <- which(apply(source_matrix, 1, function(row) all(is.na(row))))
  if (length(all_na_idx) > 0) {
    composite_values[all_na_idx] <- NA
  }

  # Calculate weighted mean of composite scores
  result <- calculate_weighted_mean(
    values = composite_values,
    weights = wave_df$weight_var
  )

  return(result)
}


#' Calculate Weighted Mean
#'
#' SHARED CODE NOTE: This should be in /shared/calculations.R
#' Used by both TurasTabs and TurasTracker
#'
#' @keywords internal
calculate_weighted_mean <- function(values, weights) {

  # Type validation - check if values are numeric
  if (!is.numeric(values)) {
    # Show sample of non-numeric values for debugging
    sample_values <- head(unique(values[!is.na(values)]), 5)
    # TRS Refusal: DATA_NON_NUMERIC_VALUES
    tracker_refuse(
      code = "DATA_NON_NUMERIC_VALUES",
      title = "Non-Numeric Data Detected",
      problem = "Expected numeric responses but found text values.",
      why_it_matters = "Weighted mean calculation requires numeric data.",
      how_to_fix = c(
        "Check that the data file has numeric values for this question",
        "Verify question type is configured correctly"
      ),
      details = paste0("Sample values found: ", paste(sample_values, collapse = ", "))
    )
  }

  # Remove NA values
  # Use which() to ensure we get numeric indices without NA
  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values <- values[valid_idx]
  weights <- weights[valid_idx]

  if (length(values) == 0) {
    return(list(
      mean = NA,
      sd = NA,
      n_unweighted = 0,
      n_weighted = 0,
      eff_n = 0
    ))
  }

  # Calculate weighted mean
  weighted_mean <- sum(values * weights) / sum(weights)

  # Calculate weighted standard deviation
  weighted_var <- sum(weights * (values - weighted_mean)^2) / sum(weights)
  weighted_sd <- sqrt(weighted_var)

  # Calculate effective N (design-effect adjusted sample size)
  # eff_n = (sum of weights)^2 / sum of squared weights
  sum_weights <- sum(weights)
  sum_weights_squared <- sum(weights^2)
  eff_n <- if (sum_weights_squared > 0) {
    (sum_weights^2) / sum_weights_squared
  } else {
    0
  }

  return(list(
    mean = weighted_mean,
    sd = weighted_sd,
    n_unweighted = length(values),
    n_weighted = sum(weights),
    eff_n = eff_n
  ))
}


#' Calculate NPS Score
#'
#' @keywords internal
calculate_nps_score <- function(values, weights) {

  # Remove NA values
  # Use which() to ensure we get numeric indices without NA
  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values <- values[valid_idx]
  weights <- weights[valid_idx]

  if (length(values) == 0) {
    return(list(
      nps = NA,
      promoters_pct = NA,
      passives_pct = NA,
      detractors_pct = NA,
      n_unweighted = 0,
      n_weighted = 0,
      eff_n = 0
    ))
  }

  # Classify responses
  promoters <- values >= 9
  passives <- values >= 7 & values <= 8
  detractors <- values <= 6

  # Calculate weighted percentages (use which() to avoid NA issues)
  total_weight <- sum(weights)
  promoters_pct <- sum(weights[which(promoters)]) / total_weight * 100
  passives_pct <- sum(weights[which(passives)]) / total_weight * 100
  detractors_pct <- sum(weights[which(detractors)]) / total_weight * 100

  # NPS = % Promoters - % Detractors
  nps <- promoters_pct - detractors_pct

  # Calculate effective N
  sum_weights_squared <- sum(weights^2)
  eff_n <- if (sum_weights_squared > 0) {
    (total_weight^2) / sum_weights_squared
  } else {
    0
  }

  return(list(
    nps = nps,
    promoters_pct = promoters_pct,
    passives_pct = passives_pct,
    detractors_pct = detractors_pct,
    n_unweighted = length(values),
    n_weighted = total_weight,
    eff_n = eff_n
  ))
}


#' Calculate Proportions
#'
#' SHARED CODE NOTE: Should be in /shared/calculations.R
#'
#' @keywords internal
calculate_proportions <- function(values, weights, codes) {

  # Remove NA values
  # Use which() to ensure we get numeric indices without NA
  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values <- values[valid_idx]
  weights <- weights[valid_idx]

  if (length(values) == 0) {
    return(list(
      proportions = setNames(rep(NA, length(codes)), codes),
      n_unweighted = 0,
      n_weighted = 0,
      eff_n = 0
    ))
  }

  total_weight <- sum(weights)

  # Calculate proportion for each code
  proportions <- sapply(codes, function(code) {
    # Use which() to avoid NA issues in logical indexing
    matched_idx <- which(values == code)
    code_weight <- sum(weights[matched_idx], na.rm = TRUE)
    (code_weight / total_weight) * 100
  })

  names(proportions) <- codes

  # Calculate effective N
  sum_weights_squared <- sum(weights^2)
  eff_n <- if (sum_weights_squared > 0) {
    (total_weight^2) / sum_weights_squared
  } else {
    0
  }

  return(list(
    proportions = proportions,
    n_unweighted = length(values),
    n_weighted = total_weight,
    eff_n = eff_n
  ))
}


#' Calculate Wave-over-Wave Changes
#'
#' @keywords internal
calculate_changes <- function(wave_results, wave_ids, metric_name, sub_metric = NULL) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get metric values
    if (!is.null(sub_metric)) {
      # For proportions, access by sub_metric (response code)
      sub_metric_str <- as.character(sub_metric)
      current_val <- if (!is.null(current[[metric_name]]) && sub_metric_str %in% names(current[[metric_name]])) {
        current[[metric_name]][[sub_metric_str]]
      } else {
        NA
      }
      previous_val <- if (!is.null(previous[[metric_name]]) && sub_metric_str %in% names(previous[[metric_name]])) {
        previous[[metric_name]][[sub_metric_str]]
      } else {
        NA
      }
    } else {
      current_val <- current[[metric_name]]
      previous_val <- previous[[metric_name]]
    }

    # Calculate changes
    if (!is.na(current_val) && !is.na(previous_val)) {
      absolute_change <- current_val - previous_val
      # Avoid division by zero
      percentage_change <- if (previous_val == 0) {
        NA  # Cannot calculate percentage change from zero baseline
      } else {
        (absolute_change / previous_val) * 100
      }

      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = absolute_change,
        percentage_change = percentage_change,
        direction = if (absolute_change > 0) "up" else if (absolute_change < 0) "down" else "stable"
      )
    } else {
      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = NA,
        percentage_change = NA,
        direction = "unavailable"
      )
    }
  }

  return(changes)
}


#' Perform Significance Tests for Means
#'
#' SHARED CODE NOTE: T-test logic should be in /shared/significance_tests.R
#' This is identical to TurasTabs t-test implementation
#'
#' NOTE: Uses effective N (eff_n) instead of unweighted N to properly account
#' for design effects from weighting. This provides more accurate p-values when
#' weights vary substantially across respondents.
#'
#' @keywords internal
perform_significance_tests_means <- function(wave_results, wave_ids, config) {

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  min_base <- get_setting(config, "minimum_base", default = DEFAULT_MINIMUM_BASE)

  sig_tests <- list()

  # Test consecutive waves
  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    # Check if both available and have sufficient base (using effective N)
    if (current$available && previous$available &&
        current_eff_n >= min_base && previous_eff_n >= min_base) {

      # Two-sample t-test for means (using effective N)
      # SHARED CODE NOTE: Extract to shared/significance_tests.R::t_test_means()
      t_result <- t_test_for_means(
        mean1 = previous$mean,
        sd1 = previous$sd,
        n1 = previous_eff_n,
        mean2 = current$mean,
        sd2 = current$sd,
        n2 = current_eff_n,
        alpha = alpha
      )

      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- t_result
    } else {
      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
        significant = FALSE,
        reason = "insufficient_base_or_unavailable"
      )
    }
  }

  return(sig_tests)
}


#' Perform Significance Tests for Proportions
#'
#' SHARED CODE NOTE: Z-test logic should be in /shared/significance_tests.R
#'
#' NOTE: Uses effective N (eff_n) instead of unweighted N to properly account
#' for design effects from weighting. This provides more accurate p-values when
#' weights vary substantially across respondents.
#'
#' @keywords internal
perform_significance_tests_proportions <- function(wave_results, wave_ids, config, response_code) {

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  min_base <- get_setting(config, "minimum_base", default = DEFAULT_MINIMUM_BASE)

  sig_tests <- list()

  # Test consecutive waves
  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    if (current$available && previous$available &&
        current_eff_n >= min_base && previous_eff_n >= min_base) {

      # Get proportions for this response code
      response_code_str <- as.character(response_code)

      # Check if response code exists in both waves
      if (!is.null(previous$proportions) && response_code_str %in% names(previous$proportions) &&
          !is.null(current$proportions) && response_code_str %in% names(current$proportions)) {

        p1 <- previous$proportions[[response_code_str]] / 100  # Convert to proportion
        p2 <- current$proportions[[response_code_str]] / 100

        # Z-test for proportions (using effective N)
        # SHARED CODE NOTE: Extract to shared/significance_tests.R::z_test_proportions()
        z_result <- z_test_for_proportions(
          p1 = p1,
          n1 = previous_eff_n,
          p2 = p2,
          n2 = current_eff_n,
          alpha = alpha
        )

        sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- z_result
      } else {
        sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
          significant = FALSE,
          reason = "response_code_not_found"
        )
      }
    } else {
      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
        significant = FALSE,
        reason = "insufficient_base_or_unavailable"
      )
    }
  }

  return(sig_tests)
}


#' Perform Significance Tests for NPS
#'
#' NOTE: Uses effective N (eff_n) instead of unweighted N to properly account
#' for design effects from weighting.
#'
#' @keywords internal
perform_significance_tests_nps <- function(wave_results, wave_ids, config) {

  # NPS is a difference of proportions, so we test the NPS score directly
  # This is a simplified approach for MVT
  # Could be enhanced with proper proportion difference testing

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  min_base <- get_setting(config, "minimum_base", default = DEFAULT_MINIMUM_BASE)

  sig_tests <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    if (current$available && previous$available &&
        current_eff_n >= min_base && previous_eff_n >= min_base) {

      # Calculate z-test for NPS difference
      # NPS is on -100 to +100 scale, convert to proportion scale (0-1)
      nps_diff <- current$nps - previous$nps

      # Approximate standard error for NPS difference (using effective N)
      # Using conservative estimate: SE = sqrt((100^2 / n1) + (100^2 / n2))
      # This assumes worst-case variance for NPS scale
      se_nps <- sqrt((10000 / current_eff_n) + (10000 / previous_eff_n))

      # Calculate z-statistic
      z_stat <- abs(nps_diff) / se_nps

      # Critical value for two-tailed test (e.g., 1.96 for 95% confidence)
      z_critical <- qnorm(1 - alpha/2)

      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
        significant = z_stat > z_critical,
        nps_difference = nps_diff,
        z_statistic = z_stat,
        p_value = 2 * (1 - pnorm(abs(z_stat))),
        note = "Z-test for NPS difference (conservative SE estimate, uses effective N)"
      )
    } else {
      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
        significant = FALSE,
        reason = "insufficient_base_or_unavailable"
      )
    }
  }

  return(sig_tests)
}


#' T-Test for Means
#'
#' Two-sample t-test for comparing means.
#'
#' SHARED CODE NOTE: This should be extracted to /shared/significance_tests.R
#' Identical to TurasTabs t-test implementation
#'
#' @keywords internal
t_test_for_means <- function(mean1, sd1, n1, mean2, sd2, n2, alpha = DEFAULT_ALPHA) {

  # Pooled standard deviation
  pooled_var <- ((n1 - 1) * sd1^2 + (n2 - 1) * sd2^2) / (n1 + n2 - 2)
  pooled_sd <- sqrt(pooled_var)

  # Standard error
  se <- pooled_sd * sqrt(1/n1 + 1/n2)

  # T statistic
  t_stat <- (mean2 - mean1) / se

  # Degrees of freedom
  df <- n1 + n2 - 2

  # P-value (two-tailed)
  p_value <- 2 * pt(-abs(t_stat), df)

  # Significant?
  significant <- p_value < alpha

  return(list(
    t_stat = t_stat,
    df = df,
    p_value = p_value,
    significant = significant,
    alpha = alpha
  ))
}


#' Z-Test for Proportions
#'
#' Two-sample z-test for comparing proportions.
#'
#' SHARED CODE NOTE: This should be extracted to /shared/significance_tests.R
#' Identical to TurasTabs z-test implementation
#'
#' @keywords internal
z_test_for_proportions <- function(p1, n1, p2, n2, alpha = DEFAULT_ALPHA) {

  # Pooled proportion
  p_pooled <- (p1 * n1 + p2 * n2) / (n1 + n2)

  # Standard error
  se <- sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))

  # Handle zero SE
  if (se == 0) {
    return(list(
      z_stat = 0,
      p_value = 1,
      significant = FALSE,
      alpha = alpha
    ))
  }

  # Z statistic
  z_stat <- (p2 - p1) / se

  # P-value (two-tailed)
  p_value <- 2 * pnorm(-abs(z_stat))

  # Significant?
  significant <- p_value < alpha

  return(list(
    z_stat = z_stat,
    p_value = p_value,
    significant = significant,
    alpha = alpha
  ))
}


# ==============================================================================
# ENHANCED RATING CALCULATIONS (Enhancement Phase 1)
# ==============================================================================

#' Calculate Top Box
#'
#' Calculates percentage of responses in top N values of scale.
#' Auto-detects scale from data.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @param n_boxes Integer, number of top values to include (1, 2, or 3)
#' @return List with proportion, scale_detected, top_values
#'
#' @keywords internal
calculate_top_box <- function(values, weights, n_boxes = 1) {

  # Remove NA values
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(
      proportion = NA,
      scale_detected = NA,
      top_values = NA,
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Detect scale
  unique_values <- sort(unique(values_valid))
  scale_min <- min(unique_values)
  scale_max <- max(unique_values)

  # Get top N values
  n_boxes <- min(n_boxes, length(unique_values))  # Can't exceed available values
  top_values <- tail(unique_values, n_boxes)

  # Calculate percentage (use which() to avoid NA issues)
  in_top_box <- values_valid %in% top_values
  top_weight <- sum(weights_valid[which(in_top_box)])
  total_weight <- sum(weights_valid)

  proportion <- (top_weight / total_weight) * 100

  return(list(
    proportion = proportion,
    scale_detected = paste0(scale_min, "-", scale_max),
    top_values = top_values,
    n_unweighted = length(values_valid),
    n_weighted = total_weight
  ))
}


#' Calculate Bottom Box
#'
#' Calculates percentage of responses in bottom N values of scale.
#' Auto-detects scale from data.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @param n_boxes Integer, number of bottom values to include (1, 2, or 3)
#' @return List with proportion, scale_detected, bottom_values
#'
#' @keywords internal
calculate_bottom_box <- function(values, weights, n_boxes = 1) {

  # Remove NA values
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(
      proportion = NA,
      scale_detected = NA,
      bottom_values = NA,
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Detect scale
  unique_values <- sort(unique(values_valid))
  scale_min <- min(unique_values)
  scale_max <- max(unique_values)

  # Get bottom N values
  n_boxes <- min(n_boxes, length(unique_values))
  bottom_values <- head(unique_values, n_boxes)

  # Calculate percentage (use which() to avoid NA issues)
  in_bottom_box <- values_valid %in% bottom_values
  bottom_weight <- sum(weights_valid[which(in_bottom_box)])
  total_weight <- sum(weights_valid)

  proportion <- (bottom_weight / total_weight) * 100

  return(list(
    proportion = proportion,
    scale_detected = paste0(scale_min, "-", scale_max),
    bottom_values = bottom_values,
    n_unweighted = length(values_valid),
    n_weighted = total_weight
  ))
}


#' Calculate Custom Range
#'
#' Calculates percentage of responses within a custom range (e.g., 9-10, 7-8).
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @param range_spec Character, range specification (e.g., "range:9-10")
#' @return List with proportion, range_values, range_spec
#'
#' @keywords internal
calculate_custom_range <- function(values, weights, range_spec) {

  # Parse range spec: "range:9-10" -> c(9, 10)
  range_str <- sub("^range:", "", tolower(range_spec))
  parts <- strsplit(range_str, "-")[[1]]

  if (length(parts) != 2) {
    warning(paste0("Invalid range specification: ", range_spec))
    return(list(
      proportion = NA,
      range_values = NA,
      range_spec = range_spec,
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  range_min <- as.numeric(parts[1])
  range_max <- as.numeric(parts[2])

  if (is.na(range_min) || is.na(range_max) || range_min > range_max) {
    warning(paste0("Invalid range values: ", range_spec))
    return(list(
      proportion = NA,
      range_values = NA,
      range_spec = range_spec,
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Generate sequence of values in range
  range_values <- seq(range_min, range_max)

  # Remove NA values
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(
      proportion = NA,
      range_values = range_values,
      range_spec = range_spec,
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Calculate proportion (use which() to avoid NA issues)
  in_range <- values_valid %in% range_values
  range_weight <- sum(weights_valid[which(in_range)])
  total_weight <- sum(weights_valid)

  proportion <- (range_weight / total_weight) * 100

  return(list(
    proportion = proportion,
    range_values = range_values,
    range_spec = range_spec,
    n_unweighted = length(values_valid),
    n_weighted = total_weight
  ))
}


#' Calculate Distribution
#'
#' Calculates percentage for each unique value found in data.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @return List with distribution (named list of percentages), n_unweighted, n_weighted
#'
#' @keywords internal
calculate_distribution <- function(values, weights) {

  # Remove NA values
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(
      distribution = list(),
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Get unique values
  unique_vals <- sort(unique(values_valid))

  # Calculate percentage for each value
  distribution <- list()
  total_weight <- sum(weights_valid)

  for (val in unique_vals) {
    matched_idx <- which(values_valid == val)
    val_weight <- sum(weights_valid[matched_idx])
    distribution[[as.character(val)]] <- (val_weight / total_weight) * 100
  }

  return(list(
    distribution = distribution,
    n_unweighted = length(values_valid),
    n_weighted = total_weight
  ))
}


#' Calculate Rating Trend - Enhanced Version
#'
#' Enhanced version that supports TrackingSpecs for multiple metrics.
#' Backward compatible - defaults to mean if no TrackingSpecs specified.
#'
#' @keywords internal
calculate_rating_trend_enhanced <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

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

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "rating_enhanced",
    tracking_specs = specs_list,
    wave_results = wave_results,
    changes = changes,
    significance = significance
  ))
}


#' Calculate Changes for a Specific Metric
#'
#' Helper function to calculate wave-over-wave changes for enhanced metrics.
#'
#' @keywords internal
calculate_changes_for_metric <- function(wave_results, wave_ids, metric_name) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get metric values
    current_val <- if (current$available && !is.null(current$metrics[[metric_name]])) {
      current$metrics[[metric_name]]
    } else {
      NA
    }

    previous_val <- if (previous$available && !is.null(previous$metrics[[metric_name]])) {
      previous$metrics[[metric_name]]
    } else {
      NA
    }

    # Calculate changes
    if (!is.na(current_val) && !is.na(previous_val)) {
      absolute_change <- current_val - previous_val
      percentage_change <- if (previous_val == 0) {
        NA
      } else {
        (absolute_change / previous_val) * 100
      }

      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = absolute_change,
        percentage_change = percentage_change,
        direction = if (absolute_change > 0) "up" else if (absolute_change < 0) "down" else "stable"
      )
    } else {
      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = NA,
        percentage_change = NA,
        direction = NA
      )
    }
  }

  return(changes)
}


#' Perform Significance Tests for Enhanced Metric
#'
#' Performs significance testing for proportion-based metrics (top_box, range, etc.).
#'
#' NOTE: Uses effective N (eff_n) instead of unweighted N to properly account
#' for design effects from weighting.
#'
#' @keywords internal
perform_significance_tests_for_metric <- function(wave_results, wave_ids, metric_name,
                                                   config, test_type = "proportion") {

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  sig_tests <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Check availability
    if (!current$available || !previous$available) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    # Get metric values
    current_val <- current$metrics[[metric_name]]
    previous_val <- previous$metrics[[metric_name]]

    if (is.na(current_val) || is.na(previous_val)) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    # Perform test based on type
    if (test_type == "proportion") {
      # Convert percentages to proportions
      p1 <- previous_val / 100
      p2 <- current_val / 100

      test_result <- z_test_for_proportions(p1, previous_eff_n, p2, current_eff_n, alpha)
    } else {
      # Would use t-test for means, but this function is for proportions
      test_result <- NA
    }

    sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- test_result
  }

  return(sig_tests)
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
    warning(paste0("No valid source questions found for composite in ", wave_id,
                   ". Missing: ", paste(missing_sources, collapse = ", ")))
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
    warning(paste0("No multi-mention columns found for base code: ", base_code))
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
    spec_lower <- tolower(trimws(spec))

    if (spec_lower == "auto") {
      # Auto-detect all columns
      result$mode <- "auto"
      auto_cols <- detect_multi_mention_columns(wave_df, base_code)
      if (!is.null(auto_cols)) {
        result$columns <- unique(c(result$columns, auto_cols))
      }

    } else if (startsWith(spec_lower, "option:")) {
      # Specific option: "option:Q30_1"
      col_name <- sub("^option:", "", spec, ignore.case = TRUE)
      col_name <- trimws(col_name)  # Remove any leading/trailing whitespace
      if (col_name != "") {  # Only add if not empty
        result$columns <- c(result$columns, col_name)
      }

    } else if (startsWith(spec_lower, "category:")) {
      # Specific category text: "category:Internal store system"
      category_name <- sub("^category:", "", spec, ignore.case = TRUE)
      category_name <- trimws(category_name)  # Remove any leading/trailing whitespace
      if (category_name != "") {  # Only add if not empty
        result$mode <- "category"
        result$categories <- c(result$categories, category_name)
      }

    } else if (spec_lower %in% c("any", "count_mean", "count_distribution")) {
      # Additional metrics
      result$additional_metrics <- c(result$additional_metrics, spec_lower)

    } else {
      warning(paste0("Unknown Multi_Mention spec: ", spec))
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
      warning(paste0("Multi-mention columns not found in data: ",
                     paste(missing, collapse = ", ")))
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


#' Calculate Changes for Multi-Mention Option
#'
#' @keywords internal
calculate_changes_for_multi_mention_option <- function(wave_results, wave_ids, column_name) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get mention proportions
    current_val <- if (current$available && !is.null(current$mention_proportions[[column_name]])) {
      current$mention_proportions[[column_name]]
    } else {
      NA
    }

    previous_val <- if (previous$available && !is.null(previous$mention_proportions[[column_name]])) {
      previous$mention_proportions[[column_name]]
    } else {
      NA
    }

    # Calculate changes
    if (!is.na(current_val) && !is.na(previous_val)) {
      absolute_change <- current_val - previous_val
      percentage_change <- if (previous_val == 0) {
        NA
      } else {
        (absolute_change / previous_val) * 100
      }

      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = absolute_change,
        percentage_change = percentage_change,
        direction = if (absolute_change > 0) "up" else if (absolute_change < 0) "down" else "stable"
      )
    } else {
      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = NA,
        percentage_change = NA,
        direction = NA
      )
    }
  }

  return(changes)
}


#' Calculate Changes for Multi-Mention Additional Metric
#'
#' @keywords internal
calculate_changes_for_multi_mention_metric <- function(wave_results, wave_ids, metric_name) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    current_val <- if (current$available && !is.null(current$additional_metrics[[metric_name]])) {
      current$additional_metrics[[metric_name]]
    } else {
      NA
    }

    previous_val <- if (previous$available && !is.null(previous$additional_metrics[[metric_name]])) {
      previous$additional_metrics[[metric_name]]
    } else {
      NA
    }

    if (!is.na(current_val) && !is.na(previous_val)) {
      absolute_change <- current_val - previous_val
      percentage_change <- if (previous_val == 0) {
        NA
      } else {
        (absolute_change / previous_val) * 100
      }

      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = absolute_change,
        percentage_change = percentage_change,
        direction = if (absolute_change > 0) "up" else if (absolute_change < 0) "down" else "stable"
      )
    } else {
      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = NA,
        percentage_change = NA,
        direction = NA
      )
    }
  }

  return(changes)
}


#' Perform Significance Tests for Multi-Mention Option
#'
#' Uses z-test for proportions (same as single-choice questions).
#'
#' NOTE: Uses effective N (eff_n) instead of unweighted N to properly account
#' for design effects from weighting.
#'
#' @keywords internal
perform_significance_tests_multi_mention <- function(wave_results, wave_ids, column_name, config) {

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  sig_tests <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    if (!current$available || !previous$available) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    current_val <- current$mention_proportions[[column_name]]
    previous_val <- previous$mention_proportions[[column_name]]

    if (is.na(current_val) || is.na(previous_val)) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    # Convert percentages to proportions
    p1 <- previous_val / 100
    p2 <- current_val / 100

    test_result <- z_test_for_proportions(p1, previous_eff_n, p2, current_eff_n, alpha)
    sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- test_result
  }

  return(sig_tests)
}


#' Perform Significance Tests for Multi-Mention Additional Metric
#'
#' @keywords internal
perform_significance_tests_multi_mention_metric <- function(wave_results, wave_ids, metric_name, config) {

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  sig_tests <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    if (!current$available || !previous$available) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    current_val <- current$additional_metrics[[metric_name]]
    previous_val <- previous$additional_metrics[[metric_name]]

    if (is.na(current_val) || is.na(previous_val)) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    # For "any" metric, use z-test for proportions (using effective N)
    # For "count_mean", use t-test (but need raw values - skip for now)
    if (metric_name == "any_mention_pct") {
      p1 <- previous_val / 100
      p2 <- current_val / 100

      test_result <- z_test_for_proportions(p1, previous_eff_n, p2, current_eff_n, alpha)
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- test_result
    } else {
      # For count_mean, we'd need the raw count values for t-test
      # Skip significance testing for now
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
    }
  }

  return(sig_tests)
}
