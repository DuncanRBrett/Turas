# ==============================================================================
# ALCHEMER PARSER - QUESTION CODE GENERATION
# ==============================================================================
# Generate question codes following Turas conventions
# Handles padding, grid suffixes, and othermention fields
# ==============================================================================

#' Generate Question Codes
#'
#' @description
#' Generates question codes for all questions.
#' - Determines padding (Q01 vs Q001) based on total questions
#' - Handles grid suffixes (Q02a, Q02b)
#' - Handles multi-column suffixes (Q04_1, Q04_2)
#' - Identifies and renames othermention fields
#'
#' @param questions Classified questions list
#' @param verbose Print progress messages
#'
#' @return Questions list with codes added
#'
#' @keywords internal
generate_question_codes <- function(questions, verbose = FALSE) {

  # Determine padding
  n_questions <- length(questions)
  padding <- if (n_questions >= 100) 3 else 2

  if (verbose) {
    cat(sprintf("  Using %d-digit padding (Q%s)\n",
                padding,
                paste0(rep("0", padding), collapse = "")))
  }

  # Generate codes for each question
  for (q_num in names(questions)) {
    q <- questions[[q_num]]

    if (q$is_grid) {
      # Grid questions have sub-questions
      for (suffix in names(q$sub_questions)) {
        sub_q <- q$sub_questions[[suffix]]

        # Generate base code
        base_code <- generate_base_code(q_num, padding)

        # Add suffix
        sub_q$q_code <- paste0(base_code, suffix)

        # For multi-column sub-questions (checkbox grid), add column suffixes
        if (sub_q$variable_type == "Multi_Mention") {
          sub_q$q_codes <- generate_multi_mention_codes(
            sub_q$q_code,
            sub_q$col_labels
          )
        } else {
          sub_q$q_codes <- sub_q$q_code
        }

        q$sub_questions[[suffix]] <- sub_q
      }

    } else {
      # Single question
      base_code <- generate_base_code(q_num, padding)
      q$q_code <- base_code

      # For multi-column questions, generate column codes
      if (q$n_columns > 1) {
        if (q$variable_type == "Multi_Mention") {
          # Multi-mention: Q04_1, Q04_2, Q04_3, Q04_4, Q04_4othertext
          q$q_codes <- generate_multi_mention_codes_sequential(base_code, q$columns)

        } else if (q$variable_type == "Ranking") {
          # Ranking: Q12_1, Q12_2, Q12_3
          q$q_codes <- paste0(base_code, "_", seq_along(q$columns))

        } else if (q$variable_type == "Single_Mention") {
          # Single_Mention with multiple columns (usually main + othermention)
          q$q_codes <- generate_single_mention_codes(base_code, q$columns)

        } else {
          # Other multi-column (shouldn't happen often)
          q$q_codes <- paste0(base_code, "_", seq_along(q$columns))
        }
      } else {
        q$q_codes <- base_code
      }
    }

    questions[[q_num]] <- q
  }

  return(questions)
}


#' Generate Base Code
#'
#' @description
#' Generates base question code with proper padding.
#'
#' @param q_num Question number (as character)
#' @param padding Number of digits (2 or 3)
#'
#' @return Base code (e.g., "Q01", "Q001")
#'
#' @keywords internal
generate_base_code <- function(q_num, padding = 2) {
  q_num_int <- as.integer(q_num)
  padded <- sprintf(paste0("%0", padding, "d"), q_num_int)
  return(paste0("Q", padded))
}


#' Generate Single Mention Codes
#'
#' @description
#' Generates codes for single-mention questions with potential othermention field.
#'
#' @param base_code Base question code (e.g., "Q01")
#' @param columns Column objects from question
#'
#' @return Vector of codes
#'
#' @keywords internal
generate_single_mention_codes <- function(base_code, columns) {

  codes <- character(length(columns))

  for (i in seq_along(columns)) {
    col <- columns[[i]]
    label <- col$row_label

    # Check if this is an "othertext" field
    if (!is.na(label) && grepl("other.*text", label, ignore.case = TRUE)) {
      codes[i] <- paste0(base_code, "_othermention")
    } else {
      # Main column
      codes[i] <- base_code
    }
  }

  return(codes)
}


#' Generate Multi-Mention Codes (Sequential)
#'
#' @description
#' Generates codes for multi-mention questions.
#' Uses sequential numbering (Q04_1, Q04_2, Q04_3, Q04_4).
#' Detects othertext fields and names them Q04_#othertext.
#'
#' @param base_code Base question code (e.g., "Q04")
#' @param columns Column objects from question
#'
#' @return Vector of codes
#'
#' @keywords internal
generate_multi_mention_codes_sequential <- function(base_code, columns) {

  codes <- character(length(columns))
  option_index <- 0
  last_option_num <- 0
  seen_labels <- character(0)

  for (i in seq_along(columns)) {
    col <- columns[[i]]
    label <- col$row_label

    # Check if this is a duplicate label (indicates othertext field)
    # For "Other - Write In (Required)", Alchemer creates TWO columns with same label:
    # 1st = checkbox option, 2nd = text entry field
    is_duplicate <- !is.na(label) && label %in% seen_labels

    # Also check for explicit "othertext" in the label
    has_text_keyword <- !is.na(label) && grepl("other.*text", label, ignore.case = TRUE)

    if (is_duplicate || has_text_keyword) {
      # This is the text field for the previous "other" option
      codes[i] <- paste0(base_code, "_", last_option_num, "othertext")
    } else {
      # Regular option - increment index
      option_index <- option_index + 1
      codes[i] <- paste0(base_code, "_", option_index)
      last_option_num <- option_index
      seen_labels <- c(seen_labels, label)
    }
  }

  return(codes)
}


#' Generate Multi-Mention Codes (for Grid Sub-questions)
#'
#' @description
#' Generates codes for checkbox grid sub-questions.
#' Uses column labels for naming (based on col_labels).
#'
#' @param base_code Base question code (e.g., "Q02a")
#' @param col_labels Column labels from grid
#'
#' @return Vector of codes
#'
#' @keywords internal
generate_multi_mention_codes <- function(base_code, col_labels) {

  # For checkbox grid sub-questions, generate codes like:
  # Q02a_1, Q02a_2, Q02a_3
  codes <- paste0(base_code, "_", seq_along(col_labels))

  return(codes)
}


#' Check if Option is Other/Specify Field
#'
#' @description
#' Detects if an option text is an "other" or "specify" field.
#'
#' @param option_text Option text
#'
#' @return TRUE if other field, FALSE otherwise
#'
#' @keywords internal
is_other_field <- function(option_text) {

  if (is.na(option_text)) {
    return(FALSE)
  }

  option_lower <- tolower(trimws(option_text))

  # Patterns that indicate other/specify field
  patterns <- c(
    "other.*write.*in",
    "other.*please.*specify",
    "other.*required",
    "^other.*:",
    "^other \\(.*\\)",
    "^other$",
    "other - write in",
    "please specify"
  )

  # Check if any pattern matches
  for (pattern in patterns) {
    if (grepl(pattern, option_lower)) {
      return(TRUE)
    }
  }

  return(FALSE)
}


#' Validate Parsing
#'
#' @description
#' Validates parsed questions and flags issues for review.
#'
#' @param questions Classified questions with codes
#' @param translation_data Translation export data
#' @param word_hints Word doc hints
#' @param verbose Print messages
#'
#' @return List with validation flags
#'
#' @keywords internal
validate_parsing <- function(questions, translation_data, word_hints,
                             verbose = FALSE) {

  flags <- list()

  for (q_num in names(questions)) {
    q <- questions[[q_num]]

    # Check 1: Q ID exists in translation export
    if (!is.na(q$q_id)) {
      expected_key <- paste0("q-", q$q_id)
      if (!(q$q_id %in% names(translation_data$questions))) {
        flags[[length(flags) + 1]] <- list(
          q_num = q_num,
          q_code = q$q_code %||% "unknown",
          issue = "Q_ID_NOT_FOUND_IN_TRANSLATION",
          severity = "WARNING",
          details = paste("Q ID", q$q_id, "not found in translation export")
        )
      }
    }

    # Check 2: Question text consistency (Word vs Data)
    if (!q$is_grid && q_num %in% names(word_hints)) {
      word_text <- word_hints[[q_num]]$question_text
      data_text <- q$question_text

      if (!is.na(word_text) && !is.na(data_text)) {
        # Simple similarity check
        if (nchar(word_text) > 0 && nchar(data_text) > 0) {
          similarity <- text_similarity(word_text, data_text)
          if (similarity < 0.5) {
            flags[[length(flags) + 1]] <- list(
              q_num = q_num,
              q_code = q$q_code %||% "unknown",
              issue = "TEXT_MISMATCH",
              severity = "REVIEW",
              details = sprintf("Word: '%s' | Data: '%s'",
                              substr(word_text, 1, 50),
                              substr(data_text, 1, 50))
            )
          }
        }
      }
    }

    # Check 3: Missing options for Single_Mention
    if (!q$is_grid && q$variable_type == "Single_Mention") {
      if (length(q$options) == 0) {
        flags[[length(flags) + 1]] <- list(
          q_num = q_num,
          q_code = q$q_code %||% "unknown",
          issue = "NO_OPTIONS_FOUND",
          severity = "ERROR",
          details = "Single_Mention question has no options in translation"
        )
      }
    }

    # Check 4: Ambiguous multi-column questions
    if (!q$is_grid && q$n_columns > 1) {
      if (q$variable_type %in% c("Multi_Mention", "Ranking")) {
        # Check if we have Word doc confirmation
        if (!(q_num %in% names(word_hints))) {
          flags[[length(flags) + 1]] <- list(
            q_num = q_num,
            q_code = q$q_code %||% "unknown",
            issue = "AMBIGUOUS_MULTI_COLUMN",
            severity = "REVIEW",
            details = sprintf("Classified as %s but no Word doc confirmation",
                            q$variable_type)
          )
        }
      }
    }
  }

  return(list(flags = flags))
}


#' Text Similarity
#'
#' @description
#' Simple text similarity based on word overlap.
#'
#' @param text1 First text
#' @param text2 Second text
#'
#' @return Similarity score (0-1)
#'
#' @keywords internal
text_similarity <- function(text1, text2) {
  words1 <- tolower(strsplit(text1, "\\s+")[[1]])
  words2 <- tolower(strsplit(text2, "\\s+")[[1]])

  # Remove common stop words
  stop_words <- c("the", "a", "an", "and", "or", "but", "in", "on", "at",
                  "to", "for", "of", "with", "is", "are", "was", "were")
  words1 <- setdiff(words1, stop_words)
  words2 <- setdiff(words2, stop_words)

  if (length(words1) == 0 || length(words2) == 0) {
    return(0)
  }

  matches <- sum(words1 %in% words2)
  total <- length(unique(c(words1, words2)))

  return(matches / total)
}
