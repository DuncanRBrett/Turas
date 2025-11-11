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
    standard_code <- question_mapping$QuestionCode[i]

    # Initialize list for this standard code
    standard_to_wave[[standard_code]] <- list()

    # Map to each wave
    for (wave_idx in seq_along(wave_ids)) {
      wave_id <- wave_ids[wave_idx]
      wave_col <- paste0("Wave", wave_idx)

      # Get wave-specific code
      if (wave_col %in% names(question_mapping)) {
        wave_code <- question_mapping[[wave_col]][i]

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
  wave_col_pattern <- "^Wave\\d+$"
  wave_cols <- grep(wave_col_pattern, names(question_mapping), value = TRUE)

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

  metadata <- question_map$question_metadata

  if (!standard_code %in% metadata$QuestionCode) {
    return(NULL)
  }

  row <- metadata[metadata$QuestionCode == standard_code, ]

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
