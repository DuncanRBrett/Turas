# ==============================================================================
# ALCHEMER PARSER - WORD QUESTIONNAIRE PARSING
# ==============================================================================
# Parse Word questionnaire document
# Extracts question type hints from formatting and keywords
# ==============================================================================

#' Parse Word Questionnaire
#'
#' @description
#' Parses the Word questionnaire document to extract type hints:
#' - ( ) brackets = Single_Response
#' - [ ] brackets = Multi_Mention
#' - "rank" keyword = Ranking
#' - Question numbers and text
#'
#' @param file_path Path to questionnaire.docx
#' @param verbose Print progress messages
#'
#' @return Named list of question hints by question number
#'
#' @keywords internal
parse_word_questionnaire <- function(file_path, verbose = FALSE) {

  # Check file exists
  if (!file.exists(file_path)) {
    stop(sprintf("Questionnaire file not found: %s", file_path), call. = FALSE)
  }

  # Load required package
  if (!requireNamespace("officer", quietly = TRUE)) {
    stop("Package 'officer' is required. Install with: install.packages('officer')",
         call. = FALSE)
  }

  # Read Word document
  doc <- officer::read_docx(file_path)
  doc_content <- officer::docx_summary(doc)

  # Filter to text paragraphs AND table cells (for grid questions)
  text_paras <- doc_content[doc_content$content_type %in% c("paragraph", "table cell"), ]

  if (verbose) {
    cat(sprintf("  Reading %d paragraphs and table cells from questionnaire\n",
                nrow(text_paras)))
  }

  # Extract hints
  hints <- list()
  current_q_num <- NULL
  current_hint <- NULL

  for (i in seq_len(nrow(text_paras))) {
    text <- as.character(text_paras$text[i])

    # Skip NA or empty
    if (is.na(text) || trimws(text) == "") {
      next
    }

    # Try to extract question number (format: "1)" or "1.")
    q_match <- regexpr("^\\s*(\\d+)[\\).:]", text)
    if (q_match > 0) {
      # Save previous question if exists
      if (!is.null(current_q_num) && !is.null(current_hint)) {
        hints[[current_q_num]] <- current_hint
      }

      # Start new question
      q_num_match <- regmatches(text, q_match)
      current_q_num <- gsub("[^0-9]", "", q_num_match)

      # Remove question number from text
      question_text <- sub("^\\s*\\d+[\\).:]\\s*", "", text)

      current_hint <- list(
        question_text = trimws(question_text),
        brackets = NA_character_,
        type = NA_character_,
        has_rank_keyword = FALSE,
        full_text = text
      )
    }

    # If we're tracking a question, look for hints
    if (!is.null(current_q_num) && !is.null(current_hint)) {
      # Check for brackets (allow some flexibility with whitespace and formatting)
      # Match: ( ) or () with possible whitespace
      if (grepl("\\([\\s\u00A0]*\\)", text, perl = TRUE)) {
        current_hint$brackets <- "()"
      }
      # Match: [ ] or [] with possible whitespace
      if (grepl("\\[[\\s\u00A0]*\\]", text, perl = TRUE)) {
        current_hint$brackets <- "[]"
      }

      # Check for question type keywords
      text_lower <- tolower(text)

      if (grepl("slider", text_lower)) {
        current_hint$type <- "slider"
      }
      if (grepl("numeric\\s+box|number\\s+box", text_lower)) {
        current_hint$type <- "numeric"
      }
      if (grepl("textbox|text\\s+box|essay|open\\s+end", text_lower)) {
        current_hint$type <- "textbox"
      }
      if (grepl("dropdown|drop\\s+down", text_lower)) {
        current_hint$type <- "dropdown"
      }

      # Check for ranking keyword
      if (grepl("rank", text_lower)) {
        current_hint$has_rank_keyword <- TRUE
      }

      # Append to full text
      current_hint$full_text <- paste(current_hint$full_text, text, sep = "\n")
    }
  }

  # Save last question
  if (!is.null(current_q_num) && !is.null(current_hint)) {
    hints[[current_q_num]] <- current_hint
  }

  if (verbose) {
    cat(sprintf("  Extracted hints for %d questions\n", length(hints)))
  }

  return(hints)
}


#' Get Hint for Question
#'
#' @description
#' Retrieves hint information for a specific question number.
#'
#' @param q_num Question number (as character)
#' @param word_hints Parsed Word hints (from parse_word_questionnaire)
#'
#' @return Hint list, or empty list if not found
#'
#' @keywords internal
get_hint_for_question <- function(q_num, word_hints) {
  if (q_num %in% names(word_hints)) {
    return(word_hints[[q_num]])
  }

  # Return empty hint
  return(list(
    question_text = NA_character_,
    brackets = NA_character_,
    type = NA_character_,
    has_rank_keyword = FALSE
  ))
}
