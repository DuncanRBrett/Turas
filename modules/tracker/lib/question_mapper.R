# ==============================================================================
# TurasTracker - Question Mapper
# ==============================================================================
#
# Maps questions across waves, handling renumbering and structural changes.
# For example: Q10 in Wave1 → Q11 in Wave2 → Q12 in Wave3
#
# This is tracker-specific functionality (not needed in TurasTabs).
#
# DEPENDENCIES:
# - metric_types.R (metric type constants and validation)
#
# ==============================================================================
# NOTE: Required modules are loaded by run_tracker.R in the correct order:
# - metric_types.R (metric type constants and validation)
# ==============================================================================

# WAVE MAPPING ARCHITECTURE
# ==============================================================================
#
# The question mapper creates a BIDIRECTIONAL INDEX for efficient lookups:
#
#   1. STANDARD → WAVE MAPPING (standard_to_wave)
#      Maps standardized question codes to wave-specific variable names.
#      Structure: list(StandardCode = list(WaveID = "VarName", ...))
#
#      Example:
#        $Q_SAT = list(W1 = "Q10", W2 = "Q11", W3 = "Q12")
#        $Q_NPS = list(W1 = "Q15", W2 = "Q15", W3 = "Q15")
#
#      Use case: "What is the variable name for Q_SAT in Wave 2?" → "Q11"
#
#   2. WAVE → STANDARD MAPPING (wave_to_standard)
#      Reverse lookup: maps wave-specific codes back to standard codes.
#      Structure: list("WaveID:VarName" = "StandardCode")
#
#      Example:
#        $`W1:Q10` = "Q_SAT"
#        $`W2:Q11` = "Q_SAT"
#        $`W3:Q12` = "Q_SAT"
#
#      Use case: "What standard code does W2:Q11 map to?" → "Q_SAT"
#
# WHY BIDIRECTIONAL MAPPING?
#   - Forward lookup: For extracting data when processing each wave
#   - Reverse lookup: For debugging/validation when checking data sources
#   - Both are O(1) hash table lookups for performance
#
# HANDLING QUESTION RENUMBERING:
#   Surveys often renumber questions between waves when:
#   - New questions are inserted
#   - Sections are reordered
#   - Questions are removed
#
#   The mapper abstracts this away so trend calculations can work with
#   stable "StandardCode" identifiers regardless of wave-specific numbering.
#
# ==============================================================================
# TRACKINGSPECS SYSTEM
# ==============================================================================
#
# TrackingSpecs allow per-question customization of which metrics to track.
#
# SYNTAX:
#   - Comma-separated list of specs: "mean,top2_box,range:9-10"
#   - Blank/NULL = use defaults for question type
#
# RATING QUESTIONS:
#   - mean: Track mean score
#   - top_box, top2_box, top3_box: % in top N boxes
#   - bottom_box, bottom2_box: % in bottom N boxes
#   - distribution: Full frequency distribution
#   - range:X-Y: Custom range (e.g., range:9-10 for % scoring 9-10)
#
# NPS QUESTIONS:
#   - nps_score: Net Promoter Score
#   - promoters_pct, passives_pct, detractors_pct: Individual segments
#   - full: All NPS metrics
#
# SINGLE CHOICE QUESTIONS:
#   - all: Track all response options
#   - top3: Track top 3 most frequent options
#   - category:X: Track specific category (e.g., category:Very Satisfied)
#
# MULTI-MENTION QUESTIONS:
#   - auto: Auto-detect and track all option columns (Q30_1, Q30_2, ...)
#   - any: Track % mentioning any option
#   - count_mean: Average number of mentions per respondent
#   - option:Q30_1: Track specific option column
#   - category:text: Search for text value across option columns
#
# ==============================================================================

#' Build Question Map Index
#'
#' Creates an indexed structure for efficient question lookups across waves.
#' Builds a bidirectional map: StandardCode → WaveCode and WaveCode → StandardCode
#'
#' @section Mapping Algorithm:
#' The function processes the question_mapping data frame row by row:
#'
#' 1. For each question (row), extract the StandardCode from QuestionCode column
#' 2. For each wave defined in config:
#'    - Look for a column matching the WaveID (e.g., "W1", "W2")
#'    - Extract the wave-specific variable name from that column
#'    - Create bidirectional mapping entries
#' 3. Store all non-wave columns as question metadata (QuestionType, QuestionText, etc.)
#'
#' @section Example Input (question_mapping data frame):
#' ```
#' | QuestionCode | QuestionType | W1   | W2   | W3   |
#' |--------------|--------------|------|------|------|
#' | Q_SAT        | Rating       | Q10  | Q11  | Q12  |
#' | Q_NPS        | NPS          | Q15  | Q15  | Q15  |
#' | Q_NEW        | Rating       | NA   | Q20  | Q20  |
#' ```
#'
#' @section Example Output:
#' ```
#' $standard_to_wave
#'   $Q_SAT = list(W1 = "Q10", W2 = "Q11", W3 = "Q12")
#'   $Q_NPS = list(W1 = "Q15", W2 = "Q15", W3 = "Q15")
#'   $Q_NEW = list(W2 = "Q20", W3 = "Q20")  # Note: W1 missing (question not in Wave 1)
#'
#' $wave_to_standard
#'   $`W1:Q10` = "Q_SAT"
#'   $`W2:Q11` = "Q_SAT"
#'   ...
#' ```
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

  # Get wave IDs from config (e.g., c("W1", "W2", "W3"))
  # These must match column names in question_mapping
  wave_ids <- config$waves$WaveID

  # Initialize mapping structures (R lists used as hash tables)
  # Both provide O(1) lookup by key
  standard_to_wave <- list()  # StandardCode → list(WaveID → VarName)
  wave_to_standard <- list()  # "WaveID:VarName" → StandardCode

  # ---------------------------------------------------------------------------
  # STEP 1: Process each question row to build bidirectional mappings
  # ---------------------------------------------------------------------------
  for (i in 1:nrow(question_mapping)) {
    # Extract and clean the standardized question code
    standard_code <- trimws(as.character(question_mapping$QuestionCode[i]))

    # Initialize empty wave map for this standard code
    standard_to_wave[[standard_code]] <- list()

    # ---------------------------------------------------------------------------
    # STEP 2: For each wave, extract the wave-specific variable name
    # ---------------------------------------------------------------------------
    for (wave_idx in seq_along(wave_ids)) {
      wave_id <- wave_ids[wave_idx]

      # The wave column name in question_mapping matches the WaveID
      # This allows flexible wave naming: W1, W2, W3 OR Wave1, Wave2, Wave3
      wave_col <- wave_id

      # Check if this wave has a column in the mapping
      if (wave_col %in% names(question_mapping)) {
        wave_code <- question_mapping[[wave_col]][i]

        # Clean whitespace (common issue with Excel data)
        if (!is.na(wave_code)) {
          wave_code <- trimws(as.character(wave_code))
        }

        # Only create mapping if wave code exists (not NA, not empty)
        # A blank cell means this question doesn't exist in this wave
        if (!is.na(wave_code) && wave_code != "") {
          # FORWARD MAPPING: StandardCode → WaveCode
          # Used when: "I need to extract Q_SAT data from Wave 2"
          standard_to_wave[[standard_code]][[wave_id]] <- wave_code

          # REVERSE MAPPING: WaveCode → StandardCode
          # Key format: "WaveID:VarName" (e.g., "W2:Q11")
          # Used when: "What standard question is W2:Q11?"
          wave_key <- paste0(wave_id, ":", wave_code)
          wave_to_standard[[wave_key]] <- standard_code
        }
      }
    }
  }

  # ---------------------------------------------------------------------------
  # STEP 3: Extract question metadata (all non-wave columns)
  # ---------------------------------------------------------------------------
  # Metadata includes: QuestionCode, QuestionText, QuestionType, TrackingSpecs, etc.
  # This allows future extensibility - new metadata columns are automatically preserved
  wave_cols <- wave_ids
  metadata_cols <- setdiff(names(question_mapping), wave_cols)
  metadata <- question_mapping[, metadata_cols, drop = FALSE]

  # ---------------------------------------------------------------------------
  # STEP 3b: Normalize question types and auto-detect composites
  # ---------------------------------------------------------------------------
  if ("QuestionType" %in% names(metadata)) {
    # Type normalization map (common aliases → canonical types)
    type_normalize <- c(
      "Likert" = "Rating",
      "likert" = "Rating",
      "Single_Response" = "SingleChoice",
      "single_response" = "SingleChoice",
      "single_choice" = "SingleChoice",
      "multi_choice" = "MultiChoice",
      "multi_mention" = "Multi_Mention",
      "rating" = "Rating",
      "nps" = "NPS",
      "composite" = "Composite",
      "index" = "Index",
      "openend" = "OpenEnd"
    )

    for (i in seq_len(nrow(metadata))) {
      raw_type <- metadata$QuestionType[i]
      q_code <- metadata$QuestionCode[i]

      # Auto-detect Composite when type is NA but SourceQuestions is populated
      if ((is.na(raw_type) || trimws(as.character(raw_type)) == "") &&
          "SourceQuestions" %in% names(metadata)) {
        src <- metadata$SourceQuestions[i]
        if (!is.na(src) && trimws(as.character(src)) != "") {
          metadata$QuestionType[i] <- "Composite"
          message(paste0("  Auto-detected '", q_code, "' as Composite (has SourceQuestions)"))
          next
        }
      }

      # Normalize known aliases to canonical types
      if (!is.na(raw_type)) {
        canonical <- type_normalize[raw_type]
        if (!is.na(canonical)) {
          metadata$QuestionType[i] <- canonical
        }
      }
    }
  }

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
    # TRS v1.0: Mapped question not found in wave data is a data/config mismatch
    tracker_refuse(
      code = "DATA_QUESTION_NOT_FOUND",
      title = paste0("Mapped Question Missing in Wave ", wave_id),
      problem = paste0("Question '", wave_code, "' is mapped for Wave ", wave_id, " but not found in the data file."),
      why_it_matters = "Cannot calculate trends for this question. Results would be incomplete.",
      how_to_fix = c(
        paste0("Check that column '", wave_code, "' exists in Wave ", wave_id, " data file"),
        "Verify the question mapping in QuestionMapping.xlsx is correct",
        "Check for typos or case differences in the column name"
      ),
      missing = wave_code
    )
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
#
# TrackingSpecs allows users to customize which metrics are calculated and
# reported for each tracked question. This provides flexibility without
# requiring changes to the core calculation engine.
#
# FLOW:
# 1. User specifies TrackingSpecs in question_mapping.xlsx (optional column)
# 2. get_tracking_specs() retrieves the spec string for a question
# 3. validate_tracking_specs() checks syntax validity
# 4. Question-type-specific calculators parse and apply the specs
#
# DEFAULT BEHAVIOR (when TrackingSpecs is blank):
# - Rating: mean, top2_box
# - NPS: nps_score, promoters_pct, detractors_pct
# - Single_Choice: all response options
# - Multi_Mention: auto-detected options
#
# ==============================================================================

#' Get Tracking Specs for Question
#'
#' Retrieves the TrackingSpecs string for a question. Checks multiple sources
#' in priority order:
#'
#' 1. TrackedQuestions sheet in tracking_config.xlsx (primary, if config provided)
#' 2. QuestionMap sheet in question_mapping.xlsx (legacy fallback)
#' 3. Default specs from settings (default_rating_specs, default_nps_specs)
#'
#' @section How TrackingSpecs Works:
#' 1. TrackingSpecs contains comma-separated metric specifications
#' 2. Each spec can be a simple keyword (e.g., "mean") or a pattern-based spec
#'    (e.g., "range:9-10", "category:Very Satisfied")
#' 3. If blank or missing everywhere, the question type's default metrics are used
#'
#' @section Examples:
#' - "mean,top2_box" → Track mean and top-2-box percentage for a rating question
#' - "category:Very Satisfied,category:Satisfied" → Track specific response options
#' - "auto" → Auto-detect all option columns for multi-mention questions
#'
#' @param question_map List. Question map index from build_question_map_index()
#' @param question_code Character. Question code
#' @param config List. Optional. Configuration object from load_tracking_config().
#'   When provided, TrackedQuestions$TrackingSpecs is checked first.
#' @return Character. TrackingSpecs string, or NULL if not specified/blank
#'
#' @export
get_tracking_specs <- function(question_map, question_code, config = NULL) {

  # Defensive: trim whitespace from question_code
  question_code <- trimws(as.character(question_code))

  # Priority 1: Check config$tracked_questions$TrackingSpecs (new primary location)
  if (!is.null(config) && !is.null(config$tracked_questions)) {
    tq <- config$tracked_questions
    if ("TrackingSpecs" %in% names(tq)) {
      tq_idx <- which(trimws(as.character(tq$QuestionCode)) == question_code)
      if (length(tq_idx) > 0) {
        spec_val <- tq$TrackingSpecs[tq_idx[1]]
        if (!is.na(spec_val) && trimws(as.character(spec_val)) != "") {
          return(trimws(as.character(spec_val)))
        }
      }
    }
  }

  # Priority 2: Check question_mapping metadata (legacy location)
  metadata_df <- question_map$question_metadata
  if ("TrackingSpecs" %in% names(metadata_df)) {
    q_row_idx <- which(metadata_df$QuestionCode == question_code)
    if (length(q_row_idx) > 0) {
      tracking_specs <- metadata_df$TrackingSpecs[q_row_idx[1]]
      if (!is.na(tracking_specs) && trimws(tracking_specs) != "") {
        message(paste0("  [INFO] TrackingSpecs for '", question_code,
                       "' read from question_mapping (consider moving to TrackedQuestions sheet)"))
        return(trimws(tracking_specs))
      }
    }
  }

  # Priority 3: Check default specs from settings
  if (!is.null(config)) {
    metadata <- get_question_metadata(question_map, question_code)
    if (!is.null(metadata)) {
      default_spec <- get_default_specs(config, metadata$QuestionType)
      if (!is.null(default_spec)) {
        return(default_spec)
      }
    }
  }

  # No specs found anywhere - calculators will use built-in defaults
  return(NULL)
}


#' Get Default TrackingSpecs for a Question Type
#'
#' Returns the default TrackingSpecs from settings for a given question type.
#' Users can set `default_rating_specs`, `default_nps_specs`, etc. in the
#' Settings sheet to avoid repeating the same specs for every question.
#'
#' @param config List. Configuration object from load_tracking_config()
#' @param question_type Character. Question type (e.g., "Rating", "NPS")
#' @return Character. Default specs string, or NULL if not configured
#'
#' @export
get_default_specs <- function(config, question_type) {
  if (is.null(config) || is.null(question_type)) return(NULL)

  q_type_lower <- tolower(trimws(question_type))

  # Map question types to their default setting names
  setting_name <- if (q_type_lower %in% c("rating", "likert", "index", "scale")) {
    "default_rating_specs"
  } else if (q_type_lower == "nps") {
    "default_nps_specs"
  } else if (q_type_lower %in% c("single_response", "singlechoice", "single_choice")) {
    "default_single_response_specs"
  } else if (q_type_lower %in% c("multi_mention", "multimention", "multi_response")) {
    "default_multi_mention_specs"
  } else if (q_type_lower == "composite") {
    "default_composite_specs"
  } else {
    NULL
  }

  if (is.null(setting_name)) return(NULL)

  spec_val <- get_setting(config, setting_name, default = NULL)
  if (is.null(spec_val) || is.na(spec_val) || trimws(as.character(spec_val)) == "") {
    return(NULL)
  }

  return(trimws(as.character(spec_val)))
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


#' Parse Spec Label
#'
#' Splits a tracking spec into its core spec and optional display label.
#' Uses \code{=} as the delimiter. The label is purely cosmetic and does not
#' affect calculation or metric name normalisation.
#'
#' @param spec Character. A single tracking spec (e.g., "mean=Average",
#'   "range:4-5=Agree", "box:Agree=Top Box", "mean")
#' @return List with:
#'   \item{core}{Character. The core spec without label (e.g., "range:4-5")}
#'   \item{label}{Character or NULL. The custom label if provided}
#'
#' @examples
#' parse_spec_label("mean=Average")
#' # list(core = "mean", label = "Average")
#'
#' parse_spec_label("range:4-5=Agree")
#' # list(core = "range:4-5", label = "Agree")
#'
#' parse_spec_label("top2_box")
#' # list(core = "top2_box", label = NULL)
#'
#' @export
parse_spec_label <- function(spec) {
  spec_trimmed <- trimws(spec)

  # Split on first "=" only
  eq_pos <- regexpr("=", spec_trimmed, fixed = TRUE)

  if (eq_pos > 0) {
    core <- trimws(substr(spec_trimmed, 1, eq_pos - 1))
    label <- trimws(substr(spec_trimmed, eq_pos + 1, nchar(spec_trimmed)))
    if (nchar(label) == 0) label <- NULL
  } else {
    core <- spec_trimmed
    label <- NULL
  }

  list(core = core, label = label)
}


#' Validate Tracking Specs Syntax
#'
#' Validates that TrackingSpecs string contains valid specifications for
#' the given question type.
#'
#' @section Validation Rules:
#' The validator checks two things:
#' 1. Each spec is valid for the given question type
#' 2. Pattern-based specs (range:, category:, option:) have correct syntax
#'
#' @section Valid Specs by Question Type:
#' \describe{
#'   \item{Rating}{mean, top_box, top2_box, top3_box, bottom_box, bottom2_box, distribution, range:X-Y, box:CATEGORY}
#'   \item{NPS}{nps_score, promoters_pct, passives_pct, detractors_pct, full}
#'   \item{Single_Choice}{all, top3, category:X}
#'   \item{Multi_Mention}{auto, any, count_mean, count_distribution, option:X, category:X}
#'   \item{Composite}{mean, top_box, top2_box, top3_box, distribution, range:X-Y, box:CATEGORY}
#' }
#'
#' @section Pattern-Based Specs:
#' \describe{
#'   \item{range:X-Y}{Track % in custom range. X must be <= Y. (Rating/Composite only)}
#'   \item{box:CATEGORY}{Track % in a BoxCategory group from survey structure. (Rating/Composite only)}
#'   \item{category:text}{Track specific category by text value. (Single_Choice/Multi_Mention)}
#'   \item{option:varname}{Track specific option column. (Multi_Mention only)}
#' }
#'
#' @section Custom Labels:
#' Any spec can have an optional display label appended with \code{=}:
#' \code{mean=Average}, \code{range:4-5=Agree}, \code{box:Agree=Top Box}.
#' The label affects only the display name, not calculation or metric naming.
#'
#' @param specs_str Character. TrackingSpecs string (e.g., "mean,top2_box")
#' @param question_type Character. Question type (e.g., "Rating", "NPS", "Single_Choice")
#' @return List with $valid (logical) and $message (character describing any errors)
#'
#' @export
validate_tracking_specs <- function(specs_str, question_type) {

  # NULL or empty specs are always valid - means "use defaults"
  if (is.null(specs_str) || is.na(specs_str) || trimws(specs_str) == "") {
    return(list(valid = TRUE, message = ""))
  }

  # Handle NA question type
  if (is.null(question_type) || is.na(question_type) || trimws(as.character(question_type)) == "") {
    return(list(
      valid = FALSE,
      message = paste0("Unknown question type: ", question_type)
    ))
  }

  # Normalize question type for case-insensitive comparison
  q_type_normalized <- tolower(trimws(question_type))

  # ---------------------------------------------------------------------------
  # VALID SPECS REGISTRY
  # ---------------------------------------------------------------------------
  # Each question type has a defined set of valid spec keywords.
  # Pattern-based specs (range:, category:, option:) are validated separately.
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
    # Strip optional =Label before validation (label is display-only)
    parsed <- parse_spec_label(spec)
    core_spec <- parsed$core
    core_lower <- tolower(core_spec)

    # Check if it's a base valid spec
    if (core_lower %in% valid_for_type) {
      next
    }

    # Check for pattern-based specs
    if (grepl("^range:", core_lower)) {
      # Range specs only valid for rating/composite
      if (!q_type_key %in% c("rating", "composite")) {
        return(list(
          valid = FALSE,
          message = paste0("'", core_spec, "' is only valid for Rating or Composite questions, not ", question_type)
        ))
      }

      # Validate range syntax: range:X-Y
      range_part <- sub("^range:", "", core_lower)
      if (!grepl("^[0-9]+-[0-9]+$", range_part)) {
        return(list(
          valid = FALSE,
          message = paste0("Invalid range syntax: '", core_spec, "'. Expected format: range:X-Y (e.g., range:9-10)")
        ))
      }

      # Validate range values
      parts <- strsplit(range_part, "-")[[1]]
      range_min <- as.numeric(parts[1])
      range_max <- as.numeric(parts[2])

      if (is.na(range_min) || is.na(range_max) || range_min > range_max) {
        return(list(
          valid = FALSE,
          message = paste0("Invalid range values in '", core_spec, "': min must be <= max")
        ))
      }

      next
    }

    # Check for box specs (rating/likert questions with BoxCategory metadata)
    if (grepl("^box:", core_lower)) {
      if (!q_type_key %in% c("rating", "composite")) {
        return(list(
          valid = FALSE,
          message = paste0("'", core_spec, "' is only valid for Rating or Composite questions, not ", question_type)
        ))
      }
      # Box category name is validated at runtime (when structure is available)
      next
    }

    # Check for category specs (single_choice and multi_mention)
    if (grepl("^category:", core_lower)) {
      if (!q_type_key %in% c("single_choice", "multi_choice", "multi_mention")) {
        return(list(
          valid = FALSE,
          message = paste0("'", core_spec, "' is only valid for Single_Choice or Multi_Mention questions, not ", question_type)
        ))
      }
      next
    }

    # Check for option specs (multi_mention)
    if (grepl("^option:", core_lower)) {
      if (!q_type_key %in% c("multi_choice", "multi_mention")) {
        return(list(
          valid = FALSE,
          message = paste0("'", core_spec, "' is only valid for Multi_Choice or Multi_Mention questions, not ", question_type)
        ))
      }
      next
    }

    # If we get here, spec is invalid
    return(list(
      valid = FALSE,
      message = paste0("Invalid spec '", core_spec, "' for question type ", question_type,
                       ". Valid options: ", paste(valid_for_type, collapse = ", "),
                       ", or pattern-based specs (range:, category:, option:, box:)")
    ))
  }

  # All specs valid
  return(list(valid = TRUE, message = ""))
}
