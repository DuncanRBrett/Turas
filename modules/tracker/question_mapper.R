# ==============================================================================
# TurasTracker - Question Mapper
# ==============================================================================
#
# Maps questions across waves, handling renumbering and structural changes.
# For example: Q10 in Wave1 → Q11 in Wave2 → Q12 in Wave3
#
# This is tracker-specific functionality (not needed in TurasTabs).
#
# ==============================================================================

#' Build Question Map Index
#'
#' Creates an indexed structure for efficient question lookups across waves.
#' Builds a bidirectional map: StandardCode → WaveCode and WaveCode → StandardCode
#'
#' @param question_mapping Data frame. Question mapping from load_question_mapping()
#' @param config List. Configuration object (for wave definitions)
#' @return List containing:
#'   - standard_to_wave: List mapping standard codes to wave-specific codes
#'   - wave_to_standard: List mapping wave-specific codes to standard codes
#'   - question_metadata: Data frame with question types and text
#'
#' @export
build_question_map_index <- function(question_mapping, config) {

  message("Building question map index...")

  # Get wave IDs from config
  wave_ids <- config$waves$WaveID

  # Initialize mapping structures
  standard_to_wave <- list()
  wave_to_standard <- list()

  # Process each question
  for (i in 1:nrow(question_mapping)) {
    standard_code <- trimws(as.character(question_mapping$QuestionCode[i]))

    # Initialize list for this standard code
    standard_to_wave[[standard_code]] <- list()

    # Map to each wave
    for (wave_idx in seq_along(wave_ids)) {
      wave_id <- wave_ids[wave_idx]
      # FIXED: Use actual WaveID instead of hardcoded "Wave" + index
      # This allows for flexible wave naming like W1, W2, W3 or Wave1, Wave2, Wave3
      wave_col <- wave_id

      # Get wave-specific code
      if (wave_col %in% names(question_mapping)) {
        wave_code <- question_mapping[[wave_col]][i]

        # Trim whitespace from wave codes (common issue with Excel data)
        if (!is.na(wave_code)) {
          wave_code <- trimws(as.character(wave_code))
        }

        # Only map if code exists for this wave
        if (!is.na(wave_code) && wave_code != "") {
          # Standard → Wave mapping
          standard_to_wave[[standard_code]][[wave_id]] <- wave_code

          # Wave → Standard mapping (reverse lookup)
          wave_key <- paste0(wave_id, ":", wave_code)
          wave_to_standard[[wave_key]] <- standard_code
        }
      }
    }
  }

  # Extract metadata - keep all non-wave columns for future extensibility
  # This includes QuestionCode, QuestionText, QuestionType, SourceQuestions, etc.
  # FIXED: Use actual wave IDs from config instead of regex pattern
  # This supports flexible wave naming (W1, W2, W3 or Wave1, Wave2, Wave3)
  wave_cols <- wave_ids

  # Get all columns except wave columns
  metadata_cols <- setdiff(names(question_mapping), wave_cols)
  metadata <- question_mapping[, metadata_cols, drop = FALSE]

  message(paste0("  Indexed ", nrow(question_mapping), " questions across ", length(wave_ids), " waves"))

  return(list(
    standard_to_wave = standard_to_wave,
    wave_to_standard = wave_to_standard,
    question_metadata = metadata
  ))
}


#' Get Wave-Specific Question Code
#'
#' Retrieves the wave-specific question code for a standardized question code.
#'
#' @param question_map List. Question map index from build_question_map_index()
#' @param standard_code Character. Standardized question code (e.g., "Q_SAT")
#' @param wave_id Character. Wave identifier (e.g., "W1")
#' @return Character. Wave-specific question code, or NA if not in wave
#'
#' @export
get_wave_question_code <- function(question_map, standard_code, wave_id) {

  # Trim whitespace from standard_code (defensive - handles whitespace in tracked_questions)
  standard_code <- trimws(as.character(standard_code))

  if (!standard_code %in% names(question_map$standard_to_wave)) {
    return(NA_character_)
  }

  wave_codes <- question_map$standard_to_wave[[standard_code]]

  if (!wave_id %in% names(wave_codes)) {
    return(NA_character_)
  }

  return(wave_codes[[wave_id]])
}


#' Get Standard Question Code
#'
#' Retrieves the standardized question code for a wave-specific code.
#'
#' @param question_map List. Question map index from build_question_map_index()
#' @param wave_code Character. Wave-specific question code (e.g., "Q10")
#' @param wave_id Character. Wave identifier (e.g., "W1")
#' @return Character. Standardized question code, or NA if not found
#'
#' @export
get_standard_question_code <- function(question_map, wave_code, wave_id) {

  wave_key <- paste0(wave_id, ":", wave_code)

  if (!wave_key %in% names(question_map$wave_to_standard)) {
    return(NA_character_)
  }

  return(question_map$wave_to_standard[[wave_key]])
}


#' Get Question Metadata
#'
#' Retrieves metadata (text, type) for a standardized question code.
#'
#' @param question_map List. Question map index from build_question_map_index()
#' @param standard_code Character. Standardized question code
#' @return Named list with QuestionText and QuestionType, or NULL if not found
#'
#' @export
get_question_metadata <- function(question_map, standard_code) {

  # Trim whitespace from standard_code (defensive - handles whitespace in tracked_questions)
  standard_code <- trimws(as.character(standard_code))

  metadata <- question_map$question_metadata

  if (!standard_code %in% metadata$QuestionCode) {
    return(NULL)
  }

  # Use which() to avoid NA issues in logical indexing
  row_idx <- which(metadata$QuestionCode == standard_code)
  if (length(row_idx) == 0) {
    return(NULL)
  }
  row <- metadata[row_idx[1], ]

  return(list(
    QuestionText = row$QuestionText[1],
    QuestionType = row$QuestionType[1]
  ))
}


#' Get Questions Available in Wave
#'
#' Returns all standardized question codes that are available in a specific wave.
#'
#' @param question_map List. Question map index from build_question_map_index()
#' @param wave_id Character. Wave identifier
#' @return Character vector of standardized question codes
#'
#' @export
get_questions_in_wave <- function(question_map, wave_id) {

  available_questions <- character(0)

  for (standard_code in names(question_map$standard_to_wave)) {
    wave_codes <- question_map$standard_to_wave[[standard_code]]

    if (wave_id %in% names(wave_codes)) {
      available_questions <- c(available_questions, standard_code)
    }
  }

  return(available_questions)
}


#' Get Questions Available Across All Waves
#'
#' Returns standardized question codes that appear in ALL specified waves.
#' Useful for filtering to only questions that can be tracked across all waves.
#'
#' @param question_map List. Question map index from build_question_map_index()
#' @param wave_ids Character vector. Wave identifiers to check
#' @return Character vector of standardized question codes present in all waves
#'
#' @export
get_questions_across_all_waves <- function(question_map, wave_ids) {

  # Get questions in first wave
  common_questions <- get_questions_in_wave(question_map, wave_ids[1])

  # Intersect with each subsequent wave
  if (length(wave_ids) > 1) {
    for (wave_id in wave_ids[-1]) {
      wave_questions <- get_questions_in_wave(question_map, wave_id)
      common_questions <- intersect(common_questions, wave_questions)
    }
  }

  return(common_questions)
}


#' Extract Wave Data for Question
#'
#' Extracts data for a specific question from a wave's dataset,
#' using the question mapping to find the correct variable.
#'
#' @param wave_df Data frame. Wave data
#' @param wave_id Character. Wave identifier
#' @param standard_code Character. Standardized question code
#' @param question_map List. Question map index
#' @return Numeric/factor vector of question responses, or NULL if not found
#'
#' @export
extract_question_data <- function(wave_df, wave_id, standard_code, question_map) {

  # Get wave-specific code
  wave_code <- get_wave_question_code(question_map, standard_code, wave_id)

  if (is.na(wave_code)) {
    return(NULL)
  }

  # Check if variable exists in data
  if (!wave_code %in% names(wave_df)) {
    warning(paste0("Question ", wave_code, " not found in Wave ", wave_id, " data"))
    return(NULL)
  }

  # Extract data
  return(wave_df[[wave_code]])
}


#' Validate Question Mapping Completeness
#'
#' Checks that tracked questions are properly mapped and exist in wave data.
#'
#' @param config List. Configuration object
#' @param question_map List. Question map index
#' @param wave_data List. Loaded wave data
#' @return Data frame showing availability of each tracked question in each wave
#'
#' @export
validate_question_mapping <- function(config, question_map, wave_data) {

  message("Validating question mapping completeness...")

  tracked_questions <- config$tracked_questions$QuestionCode
  wave_ids <- config$waves$WaveID

  # Build availability matrix
  availability <- data.frame(
    QuestionCode = tracked_questions,
    stringsAsFactors = FALSE
  )

  for (wave_id in wave_ids) {
    availability[[wave_id]] <- sapply(tracked_questions, function(q_code) {
      wave_code <- get_wave_question_code(question_map, q_code, wave_id)

      if (is.na(wave_code)) {
        return("NOT_MAPPED")
      }

      # Check if exists in data
      if (!is.null(wave_data[[wave_id]]) && wave_code %in% names(wave_data[[wave_id]])) {
        return("AVAILABLE")
      } else {
        return("MISSING_DATA")
      }
    })
  }

  # Summary
  total_tracked <- nrow(availability)
  for (wave_id in wave_ids) {
    n_available <- sum(availability[[wave_id]] == "AVAILABLE")
    n_missing <- sum(availability[[wave_id]] == "MISSING_DATA")
    n_not_mapped <- sum(availability[[wave_id]] == "NOT_MAPPED")

    message(paste0("  ", wave_id, ": ",
                   n_available, " available, ",
                   n_missing, " missing from data, ",
                   n_not_mapped, " not mapped"))
  }

  # Identify questions available across all waves
  all_available <- apply(availability[, wave_ids, drop = FALSE], 1, function(row) {
    all(row == "AVAILABLE")
  })

  n_trackable <- sum(all_available)
  message(paste0("  ", n_trackable, " questions available across all ", length(wave_ids), " waves"))

  return(availability)
}


# ==============================================================================
# TRACKINGSPECS SUPPORT (Enhancement Phase 1)
# ==============================================================================

#' Get Tracking Specs for Question
#'
#' Retrieves the TrackingSpecs string for a question from the question mapping.
#' TrackingSpecs is an optional column that allows customization of which metrics
#' to track (e.g., "mean,top2_box" or "option:Q30_1,any").
#'
#' @param question_map List. Question map index from build_question_map_index()
#' @param question_code Character. Question code
#' @return Character. TrackingSpecs string, or NULL if not specified/blank
#'
#' @export
get_tracking_specs <- function(question_map, question_code) {

  # Trim whitespace from question_code (defensive - handles whitespace in tracked_questions)
  question_code <- trimws(as.character(question_code))

  metadata_df <- question_map$question_metadata

  # Check if TrackingSpecs column exists
  if (!"TrackingSpecs" %in% names(metadata_df)) {
    return(NULL)
  }

  # Find question row (use which() to avoid NA issues)
  q_row_idx <- which(metadata_df$QuestionCode == question_code)
  if (length(q_row_idx) == 0) {
    return(NULL)
  }
  q_row <- metadata_df[q_row_idx[1], ]

  tracking_specs <- q_row$TrackingSpecs[1]

  # Return NULL if blank/NA
  if (is.na(tracking_specs) || trimws(tracking_specs) == "") {
    return(NULL)
  }

  return(trimws(tracking_specs))
}


#' Get Composite Source Questions
#'
#' Retrieves the SourceQuestions string for a composite question from the question mapping.
#' SourceQuestions contains comma-separated list of source question codes that form the composite.
#'
#' @param question_map List. Question map index from build_question_map_index()
#' @param question_code Character. Question code
#' @return Character vector. Source question codes, or NULL if not specified/blank
#'
#' @export
get_composite_sources <- function(question_map, question_code) {

  # Trim whitespace from question_code (defensive - handles whitespace in tracked_questions)
  question_code <- trimws(as.character(question_code))

  metadata_df <- question_map$question_metadata

  # Check if SourceQuestions column exists
  if (!"SourceQuestions" %in% names(metadata_df)) {
    return(NULL)
  }

  # Find question row (use which() to avoid NA issues)
  q_row_idx <- which(metadata_df$QuestionCode == question_code)
  if (length(q_row_idx) == 0) {
    return(NULL)
  }
  q_row <- metadata_df[q_row_idx[1], ]

  source_questions <- q_row$SourceQuestions[1]

  # Return NULL if blank/NA
  if (is.na(source_questions) || trimws(source_questions) == "") {
    return(NULL)
  }

  # Parse comma-separated list
  sources <- trimws(strsplit(trimws(source_questions), ",")[[1]])

  return(sources)
}


#' Validate Tracking Specs Syntax
#'
#' Validates that TrackingSpecs string contains valid specifications for
#' the given question type.
#'
#' @param specs_str Character. TrackingSpecs string (e.g., "mean,top2_box")
#' @param question_type Character. Question type (e.g., "Rating", "NPS", "Single_Choice")
#' @return List with $valid (logical) and $message (character)
#'
#' @export
validate_tracking_specs <- function(specs_str, question_type) {

  # If NULL or empty, always valid (uses defaults)
  if (is.null(specs_str) || trimws(specs_str) == "") {
    return(list(valid = TRUE, message = ""))
  }

  # Normalize question type for comparison
  q_type_normalized <- tolower(trimws(question_type))

  # Define valid specs by question type
  VALID_SPECS <- list(
    rating = c("mean", "top_box", "top2_box", "top3_box",
               "bottom_box", "bottom2_box", "distribution"),
    nps = c("nps_score", "promoters_pct", "passives_pct",
            "detractors_pct", "full"),
    single_choice = c("all", "top3"),
    multi_choice = c("auto", "any", "count_mean", "count_distribution"),
    multi_mention = c("auto", "any", "count_mean", "count_distribution"),
    composite = c("mean", "top_box", "top2_box", "top3_box", "distribution")
  )

  # Map common question type names to normalized types
  type_map <- c(
    "rating" = "rating",
    "likert" = "rating",
    "index" = "rating",
    "numeric" = "rating",
    "nps" = "nps",
    "single_choice" = "single_choice",
    "single_response" = "single_choice",
    "singlechoice" = "single_choice",
    "multi_choice" = "multi_choice",
    "multi_mention" = "multi_mention",
    "multichoice" = "multi_choice",
    "composite" = "composite"
  )

  # Normalize the question type
  q_type_key <- type_map[q_type_normalized]
  if (is.na(q_type_key)) {
    q_type_key <- q_type_normalized
  }

  # Get valid specs for this type
  valid_for_type <- VALID_SPECS[[as.character(q_type_key)]]

  if (is.null(valid_for_type)) {
    return(list(
      valid = FALSE,
      message = paste0("Unknown question type: ", question_type)
    ))
  }

  # Parse comma-separated specs
  specs <- trimws(strsplit(specs_str, ",")[[1]])

  # Validate each spec
  for (spec in specs) {
    spec_lower <- tolower(spec)

    # Check if it's a base valid spec
    if (spec_lower %in% valid_for_type) {
      next
    }

    # Check for pattern-based specs
    if (grepl("^range:", spec_lower)) {
      # Range specs only valid for rating/composite
      if (!q_type_key %in% c("rating", "composite")) {
        return(list(
          valid = FALSE,
          message = paste0("'", spec, "' is only valid for Rating or Composite questions, not ", question_type)
        ))
      }

      # Validate range syntax: range:X-Y
      range_part <- sub("^range:", "", spec_lower)
      if (!grepl("^[0-9]+-[0-9]+$", range_part)) {
        return(list(
          valid = FALSE,
          message = paste0("Invalid range syntax: '", spec, "'. Expected format: range:X-Y (e.g., range:9-10)")
        ))
      }

      # Validate range values
      parts <- strsplit(range_part, "-")[[1]]
      range_min <- as.numeric(parts[1])
      range_max <- as.numeric(parts[2])

      if (is.na(range_min) || is.na(range_max) || range_min > range_max) {
        return(list(
          valid = FALSE,
          message = paste0("Invalid range values in '", spec, "': min must be <= max")
        ))
      }

      next
    }

    # Check for category specs (single_choice and multi_mention)
    if (grepl("^category:", spec_lower)) {
      if (!q_type_key %in% c("single_choice", "multi_choice", "multi_mention")) {
        return(list(
          valid = FALSE,
          message = paste0("'", spec, "' is only valid for Single_Choice or Multi_Mention questions, not ", question_type)
        ))
      }
      next
    }

    # Check for option specs (multi_mention)
    if (grepl("^option:", spec_lower)) {
      if (!q_type_key %in% c("multi_choice", "multi_mention")) {
        return(list(
          valid = FALSE,
          message = paste0("'", spec, "' is only valid for Multi_Choice or Multi_Mention questions, not ", question_type)
        ))
      }
      next
    }

    # If we get here, spec is invalid
    return(list(
      valid = FALSE,
      message = paste0("Invalid spec '", spec, "' for question type ", question_type,
                       ". Valid options: ", paste(valid_for_type, collapse = ", "),
                       ", or pattern-based specs (range:, category:, option:)")
    ))
  }

  # All specs valid
  return(list(valid = TRUE, message = ""))
}
