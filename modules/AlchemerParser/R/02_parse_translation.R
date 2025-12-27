# ==============================================================================
# ALCHEMER PARSER - TRANSLATION EXPORT PARSING
# ==============================================================================
# Parse Alchemer translation export file
# Extracts question texts and option labels
# ==============================================================================

#' Parse Translation Export
#'
#' @description
#' Parses the Alchemer translation export Excel file.
#' Extracts:
#' - Question texts (keys: q-{id})
#' - Option texts (keys: q-{id}-o-{code})
#' - Ignores otherText fields
#'
#' @param file_path Path to translation-export.xlsx
#' @param verbose Print progress messages
#'
#' @return List containing:
#'   \item{questions}{Named list of question texts by Q ID}
#'   \item{options}{Named list of option lists by Q ID}
#'   \item{n_questions}{Number of questions found}
#'   \item{n_options}{Total number of options found}
#'   \item{raw_data}{Raw translation data frame}
#'
#' @keywords internal
parse_translation_export <- function(file_path, verbose = FALSE) {

  # Check file exists
  if (!file.exists(file_path)) {
    alchemerparser_refuse(
      code = "IO_FILE_NOT_FOUND",
      title = "Translation Export File Not Found",
      problem = sprintf("Cannot find translation export file: %s", basename(file_path)),
      why_it_matters = "Translation export is required to get question and option texts.",
      how_to_fix = c(
        "Verify the file path is correct",
        "Check that the file exists at the specified location",
        "Export the translation file from Alchemer if missing"
      ),
      details = paste0("Expected path: ", file_path)
    )
  }

  # Load required package
  if (!requireNamespace("readxl", quietly = TRUE)) {
    alchemerparser_refuse(
      code = "PKG_MISSING_DEPENDENCY",
      title = "Missing Required Package",
      problem = "Package 'readxl' is not installed.",
      why_it_matters = "AlchemerParser requires 'readxl' to parse Excel translation exports.",
      how_to_fix = "Run: install.packages('readxl')"
    )
  }

  # Read translation export
  # Expected columns: Key, Default Text
  translation_data <- readxl::read_excel(file_path)

  # Verify required columns exist
  required_cols <- c("Key", "Default Text")
  missing_cols <- setdiff(required_cols, names(translation_data))

  if (length(missing_cols) > 0) {
    alchemerparser_refuse(
      code = "DATA_INVALID_STRUCTURE",
      title = "Invalid Translation File Structure",
      problem = "Translation export file is missing required columns.",
      why_it_matters = "Cannot parse translation data without required column structure.",
      how_to_fix = c(
        "Re-export the translation file from Alchemer",
        "Ensure the export includes all required columns",
        "Do not modify the translation file structure after export"
      ),
      expected = c("Key", "Default Text"),
      missing = missing_cols
    )
  }

  # Extract questions and options
  questions <- list()
  options <- list()
  n_options_total <- 0

  for (i in seq_len(nrow(translation_data))) {
    key <- as.character(translation_data$Key[i])
    text <- as.character(translation_data$`Default Text`[i])

    # Skip if NA
    if (is.na(key) || is.na(text)) {
      next
    }

    # Check if this is a question key (q-{id})
    if (grepl("^q-\\d+$", key)) {
      q_id <- extract_question_id(key)
      questions[[q_id]] <- text
    }

    # Check if this is an option key (q-{id}-o-{code})
    else if (grepl("^q-\\d+-o-", key)) {
      # Skip otherText fields
      if (grepl("-otherText$", key)) {
        next
      }

      q_id <- extract_question_id(key)
      option_code <- extract_option_code(key)

      # Initialize option list for this question if needed
      if (!(q_id %in% names(options))) {
        options[[q_id]] <- list()
      }

      # Add option
      options[[q_id]][[length(options[[q_id]]) + 1]] <- list(
        code = option_code,
        text = text,
        key = key
      )

      n_options_total <- n_options_total + 1
    }
  }

  if (verbose) {
    cat(sprintf("  Extracted %d question texts\n", length(questions)))
    cat(sprintf("  Extracted %d options across all questions\n", n_options_total))
  }

  return(list(
    questions = questions,
    options = options,
    n_questions = length(questions),
    n_options = n_options_total,
    raw_data = translation_data
  ))
}


#' Extract Question ID from Translation Key
#'
#' @description
#' Extracts the question ID from a translation key.
#' Examples:
#' - "q-2" -> "2"
#' - "q-15-o-10001" -> "15"
#'
#' @param key Translation key
#'
#' @return Question ID as character string
#'
#' @keywords internal
extract_question_id <- function(key) {
  # Extract digits after "q-" and before next hyphen or end
  match <- regexpr("q-(\\d+)", key, perl = TRUE)
  if (match > 0) {
    id_text <- regmatches(key, match)
    # Remove "q-" prefix
    id <- gsub("q-", "", id_text)
    return(id)
  }
  return(NA_character_)
}


#' Extract Option Code from Translation Key
#'
#' @description
#' Extracts the option code from a translation option key.
#' Example: "q-2-o-10001" -> "10001"
#'
#' @param key Translation key
#'
#' @return Option code as character string
#'
#' @keywords internal
extract_option_code <- function(key) {
  # Extract digits after "-o-"
  match <- regexpr("-o-(\\d+)", key, perl = TRUE)
  if (match > 0) {
    code_text <- regmatches(key, match)
    # Remove "-o-" prefix
    code <- gsub("-o-", "", code_text)
    return(code)
  }
  return(NA_character_)
}


#' Get Options for Question ID
#'
#' @description
#' Retrieves all options for a specific question ID from translation data.
#'
#' @param q_id Question ID
#' @param translation_data Parsed translation data (from parse_translation_export)
#'
#' @return List of option objects, or empty list if none found
#'
#' @keywords internal
get_options_for_question <- function(q_id, translation_data) {
  if (q_id %in% names(translation_data$options)) {
    return(translation_data$options[[q_id]])
  }
  return(list())
}


#' Get Question Text for Question ID
#'
#' @description
#' Retrieves question text for a specific question ID from translation data.
#'
#' @param q_id Question ID
#' @param translation_data Parsed translation data (from parse_translation_export)
#'
#' @return Question text, or NA if not found
#'
#' @keywords internal
get_question_text <- function(q_id, translation_data) {
  if (q_id %in% names(translation_data$questions)) {
    return(translation_data$questions[[q_id]])
  }
  return(NA_character_)
}
