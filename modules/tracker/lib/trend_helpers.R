#' Trend Calculator Helper Functions
#'
#' This file contains utility and helper functions extracted from trend_calculator.R
#' for improved maintainability and code organization.
#'
#' These functions provide common operations used throughout the trend calculation
#' process, including:
#' - Parsing tracking specifications for single choice and multi-mention questions
#' - Detecting multi-mention column patterns in wave data
#' - Extracting composite source question information from question maps
#'
#' @note This file was extracted from trend_calculator.R to reduce file size and
#'       improve code organization. All functions maintain their original behavior
#'       and interfaces.


#' Parse Single Choice Tracking Specs
#'
#' Parses TrackingSpecs for single choice questions to determine which response
#' options to track.
#'
#' @param tracking_specs Character. TrackingSpecs string from question metadata
#' @param all_codes Character vector. All unique response codes found in the data
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


#' Get Composite Source Questions
#'
#' Extracts the list of source questions for a composite question from the
#' question map metadata.
#'
#' @param question_map List. Question map containing question metadata
#' @param composite_code Character. The question code of the composite question
#' @return Character vector of source question codes, or NULL if not found
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


#' Detect Multi-Mention Columns
#'
#' Auto-detects multi-mention columns for a base question code by finding
#' columns matching the pattern {base_code}_{digits}.
#'
#' @param wave_df Data frame. Wave data to search for columns
#' @param base_code Character. Base question code (e.g., "Q30")
#' @return Character vector of column names sorted numerically, or NULL if none found
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
