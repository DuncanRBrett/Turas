# ==============================================================================
# TurasTracker - Banner Breakout Trends
# ==============================================================================
#
# Calculates trends for banner segments (Total, Gender, Age, etc.).
# Extends Phase 2 trend calculation to include breakouts.
#
# SHARED CODE NOTES:
# - Banner processing patterns similar to TurasTabs banner_builder.R
# - Future: Extract get_banner_segments() to /shared/banner_utils.R
#
# ==============================================================================

#' Calculate Trends with Banner Breakouts
#'
#' Calculates trends for total sample and each banner segment.
#' Wrapper around Phase 2 trend calculation that repeats for each segment.
#'
#' @param config Configuration object
#' @param question_map Question map index
#' @param wave_data List of wave data frames
#' @return List of trend results organized by question → segment
#'
#' @export
calculate_trends_with_banners <- function(config, question_map, wave_data) {

  message("\n================================================================================")
  message("CALCULATING TRENDS WITH BANNER BREAKOUTS")
  message("================================================================================\n")

  # Get banner segments
  banner_segments <- get_banner_segments(config, wave_data)

  message(paste0("Banner segments: ", length(banner_segments)))
  for (seg_name in names(banner_segments)) {
    message(paste0("  - ", seg_name))
  }
  message("")

  tracked_questions <- config$tracked_questions$QuestionCode

  # Results structure: question -> segment -> trend_result
  all_results <- list()

  for (q_code in tracked_questions) {
    message(paste0("Processing question: ", q_code))

    question_results <- list()

    # Calculate trend for each segment
    for (seg_name in names(banner_segments)) {
      segment_def <- banner_segments[[seg_name]]

      # Filter wave data to this segment
      segment_wave_data <- filter_wave_data_to_segment(wave_data, segment_def)

      # Calculate trend for this segment (reuse Phase 2 logic)
      segment_trend <- calculate_trend_for_segment(
        q_code = q_code,
        question_map = question_map,
        wave_data = segment_wave_data,
        config = config,
        segment_name = seg_name
      )

      if (!is.null(segment_trend)) {
        question_results[[seg_name]] <- segment_trend
      }
    }

    all_results[[q_code]] <- question_results
    message(paste0("  ✓ Calculated trends for ", length(question_results), " segments"))
  }

  message(paste0("\nCompleted banner trend calculation for ", length(all_results), " questions"))

  return(all_results)
}


#' Get Banner Segments
#'
#' Extracts banner segment definitions from config.
#' Creates Total segment plus segments from Banner sheet.
#'
#' SHARED CODE NOTE: Similar to TurasTabs banner processing
#' Future: Extract to /shared/banner_utils.R
#'
#' @keywords internal
get_banner_segments <- function(config, wave_data) {

  segments <- list()

  # Always include Total
  segments[["Total"]] <- list(
    name = "Total",
    variable = NULL,
    filter = NULL,
    is_total = TRUE
  )

  # Get segments from Banner sheet
  banner <- config$banner
  wave_ids <- config$waves$WaveID

  for (i in 1:nrow(banner)) {
    break_var <- banner$BreakVariable[i]
    break_label <- banner$BreakLabel[i]

    # Skip Total (already added)
    if (tolower(break_var) == "total") {
      next
    }

    # Check if wave-specific columns exist in banner (like W2023, W2024, etc.)
    wave_specific_mapping <- list()
    has_wave_mapping <- FALSE

    for (wave_id in wave_ids) {
      if (wave_id %in% names(banner)) {
        wave_code <- banner[[wave_id]][i]
        if (!is.na(wave_code) && trimws(wave_code) != "") {
          wave_specific_mapping[[wave_id]] <- trimws(wave_code)
          has_wave_mapping <- TRUE
        }
      }
    }

    # Determine which variable name to use
    if (has_wave_mapping) {
      # Use wave-specific mapping - collect unique values across all waves
      all_unique_vals <- character(0)

      for (wave_id in wave_ids) {
        if (wave_id %in% names(wave_specific_mapping)) {
          wave_df <- wave_data[[wave_id]]
          wave_code <- wave_specific_mapping[[wave_id]]

          if (wave_code %in% names(wave_df)) {
            vals <- unique(wave_df[[wave_code]][!is.na(wave_df[[wave_code]])])
            all_unique_vals <- unique(c(all_unique_vals, vals))
          }
        }
      }

      # Create segments for each unique value
      for (val in all_unique_vals) {
        seg_name <- paste0(break_label, "_", val)

        segments[[seg_name]] <- list(
          name = seg_name,
          variable = break_var,
          value = val,
          wave_mapping = wave_specific_mapping,
          is_total = FALSE
        )
      }
    } else {
      # Legacy: Use break_var directly (same column across all waves)
      first_wave <- wave_data[[wave_ids[1]]]

      if (break_var %in% names(first_wave)) {
        unique_vals <- unique(first_wave[[break_var]][!is.na(first_wave[[break_var]])])

        for (val in unique_vals) {
          seg_name <- paste0(break_label, "_", val)

          segments[[seg_name]] <- list(
            name = seg_name,
            variable = break_var,
            value = val,
            is_total = FALSE
          )
        }
      }
    }
  }

  return(segments)
}


#' Filter Wave Data to Segment
#'
#' Filters each wave's data to include only records in the specified segment.
#'
#' @keywords internal
filter_wave_data_to_segment <- function(wave_data, segment_def) {

  # If Total, return all data
  if (segment_def$is_total) {
    return(wave_data)
  }

  # Filter each wave
  filtered_data <- list()

  for (wave_id in names(wave_data)) {
    wave_df <- wave_data[[wave_id]]

    # Determine which variable to use for this wave
    if (!is.null(segment_def$wave_mapping) && wave_id %in% names(segment_def$wave_mapping)) {
      # Use wave-specific question code
      var_name <- segment_def$wave_mapping[[wave_id]]
    } else {
      # Use break variable directly
      var_name <- segment_def$variable
    }

    # Check if variable exists in this wave
    if (!var_name %in% names(wave_df)) {
      # Variable doesn't exist in this wave - return empty data
      filtered_data[[wave_id]] <- wave_df[0, ]  # Empty dataframe with same structure
      next
    }

    # Filter to segment value
    # Use which() to get numeric indices (avoids NA issues with logical indexing)
    segment_rows <- which(wave_df[[var_name]] == segment_def$value &
                         !is.na(wave_df[[var_name]]))

    filtered_data[[wave_id]] <- wave_df[segment_rows, ]
  }

  return(filtered_data)
}


#' Calculate Trend for Segment
#'
#' Calculates trend for a single question in a single segment.
#' Delegates to Phase 2 trend calculation functions.
#'
#' @keywords internal
calculate_trend_for_segment <- function(q_code, question_map, wave_data, config, segment_name) {

  # Get question metadata
  metadata <- get_question_metadata(question_map, q_code)

  if (is.null(metadata)) {
    return(NULL)
  }

  # Normalize question type to internal standard
  q_type_raw <- metadata$QuestionType
  q_type <- normalize_question_type(q_type_raw)

  # Route to appropriate calculator based on question type
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
      warning(paste0("  Open-end questions cannot be tracked - skipping"))
      NULL
    } else if (q_type == "ranking") {
      warning(paste0("  Ranking questions not yet supported in tracker - skipping"))
      NULL
    } else {
      warning(paste0("  Question type '", q_type_raw, "' not supported - skipping"))
      NULL
    }
  }, error = function(e) {
    warning(paste0("  Error calculating trend for ", q_code, " in segment ", segment_name, ": ", e$message))
    NULL
  })

  # Add segment name to result
  if (!is.null(trend_result)) {
    trend_result$segment_name <- segment_name
  }

  return(trend_result)
}


#' Get Segment Summary
#'
#' Creates summary statistics for banner segments across all waves.
#' Shows base sizes per segment per wave.
#'
#' @param config Configuration object
#' @param wave_data List of wave data frames
#' @param banner_segments List of banner segment definitions
#' @return Data frame with segment × wave base sizes
#'
#' @export
get_segment_summary <- function(config, wave_data, banner_segments) {

  wave_ids <- config$waves$WaveID

  summary_list <- list()

  for (seg_name in names(banner_segments)) {
    segment_def <- banner_segments[[seg_name]]

    # Filter data to segment
    seg_data <- filter_wave_data_to_segment(wave_data, segment_def)

    # Get base sizes for each wave
    seg_row <- list(Segment = seg_name)

    for (wave_id in wave_ids) {
      wave_df <- seg_data[[wave_id]]
      n <- sum(!is.na(wave_df$weight_var) & wave_df$weight_var > 0)
      seg_row[[paste0(wave_id, "_n")]] <- n
    }

    summary_list[[seg_name]] <- as.data.frame(seg_row, stringsAsFactors = FALSE)
  }

  summary_df <- do.call(rbind, summary_list)
  rownames(summary_df) <- NULL

  return(summary_df)
}


#' Validate Banner Structure
#'
#' Checks that banner variables exist in wave data and have sufficient bases.
#'
#' @param config Configuration object
#' @param wave_data List of wave data frames
#' @param min_base Minimum acceptable base size (default 30)
#' @return List with validation results
#'
#' @export
validate_banner_structure <- function(config, wave_data, min_base = 30) {

  validation <- list(
    errors = character(0),
    warnings = character(0),
    info = character(0)
  )

  banner <- config$banner
  wave_ids <- config$waves$WaveID

  for (i in 1:nrow(banner)) {
    break_var <- banner$BreakVariable[i]
    break_label <- banner$BreakLabel[i]

    # Skip Total
    if (tolower(break_var) == "total") {
      next
    }

    # Check if variable exists in each wave
    for (wave_id in wave_ids) {
      wave_df <- wave_data[[wave_id]]

      if (!break_var %in% names(wave_df)) {
        validation$warnings <- c(
          validation$warnings,
          paste0("Banner variable '", break_var, "' not found in ", wave_id, " data")
        )
        next
      }

      # Check base sizes for each value
      unique_vals <- unique(wave_df[[break_var]][!is.na(wave_df[[break_var]])])

      for (val in unique_vals) {
        n <- sum(wave_df[[break_var]] == val & !is.na(wave_df[[break_var]]) &
                 wave_df$weight_var > 0, na.rm = TRUE)

        if (n < min_base) {
          validation$warnings <- c(
            validation$warnings,
            paste0(wave_id, " - ", break_label, "=", val, ": n=", n, " (below minimum ", min_base, ")")
          )
        } else {
          validation$info <- c(
            validation$info,
            paste0(wave_id, " - ", break_label, "=", val, ": n=", n)
          )
        }
      }
    }
  }

  return(validation)
}


#' Create Segment Labels
#'
#' Creates human-readable labels for banner segments.
#' Useful for output formatting.
#'
#' @param banner_segments List of segment definitions
#' @return Named character vector (segment_key -> display_label)
#'
#' @export
create_segment_labels <- function(banner_segments) {

  labels <- character(length(banner_segments))
  names(labels) <- names(banner_segments)

  for (seg_name in names(banner_segments)) {
    segment_def <- banner_segments[[seg_name]]

    if (segment_def$is_total) {
      labels[seg_name] <- "Total"
    } else {
      # Format as "Variable: Value"
      labels[seg_name] <- segment_def$name
    }
  }

  return(labels)
}
