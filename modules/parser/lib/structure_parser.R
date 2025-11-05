# ==============================================================================
# TURAS>PARSER - Structure Parser
# ==============================================================================
# Purpose: Parse questionnaires based on document structure
# ==============================================================================

#' Parse by Structure
#' 
#' @description
#' Identifies questions based on document structure:
#' - Questions follow blank lines
#' - Questions are 30-200 characters long
#' - Questions contain question marks
#' - Options follow without blank lines
#' 
#' This is used when pattern matching fails.
#' 
#' @param lines Character vector. All lines including blanks
#' @param config List. Parsing configuration
#' 
#' @return Data frame of parsed questions
#' 
#' @export
parse_by_structure <- function(lines, config) {
  
  questions_list <- list()
  current_question <- NULL
  previous_blank <- FALSE
  
  for (i in seq_along(lines)) {
    line <- lines[i]
    line_length <- nchar(line)
    
    # Track blank lines
    if (line_length == 0) {
      previous_blank <- TRUE
      next
    }
    
    # Detect question candidates
    has_question_mark <- grepl("\\?", line)
    looks_like_header <- (line_length > 30) && (line_length < 200)
    
    if (previous_blank && looks_like_header && has_question_mark) {
      # Start new question
      if (!is.null(current_question)) {
        questions_list[[length(questions_list) + 1]] <- current_question
      }
      
      current_question <- list(
        code = paste0("Q", length(questions_list) + 1),
        text = line,
        original_text = line,
        options = character(0),
        confidence = "medium",
        line_number = i
      )
      
    } else if (!is.null(current_question) && line_length > 0 && line_length < 100) {
      # Add as option
      current_question$options <- c(current_question$options, line)
    }
    
    previous_blank <- FALSE
  }
  
  # Add final question
  if (!is.null(current_question)) {
    questions_list[[length(questions_list) + 1]] <- current_question
  }
  
  # Convert to data frame
  if (length(questions_list) == 0) {
    return(create_empty_questions_df())
  }
  
  return(questions_list_to_df(questions_list))
}

#' Parse Permissive
#' 
#' @description
#' Last resort parsing - accepts anything that looks like a question.
#' Used when both pattern and structure parsing fail.
#' All questions flagged for manual review.
#' 
#' @param lines Character vector. Cleaned lines
#' @param config List. Parsing configuration
#' 
#' @return Data frame of parsed questions with needs_review=TRUE
#' 
#' @export
parse_permissive <- function(lines, config) {
  
  questions_list <- list()
  
  for (i in seq_along(lines)) {
    line <- lines[i]
    line_length <- nchar(line)
    
    # Very basic criteria
    has_question <- grepl("\\?", line)
    good_length <- line_length > 20
    
    if (has_question && good_length) {
      questions_list[[length(questions_list) + 1]] <- list(
        code = paste0("Q", length(questions_list) + 1),
        text = line,
        original_text = line,
        options = character(0),
        confidence = "low",
        line_number = i
      )
    }
  }
  
  # Convert to data frame
  if (length(questions_list) == 0) {
    return(create_empty_questions_df())
  }
  
  df <- questions_list_to_df(questions_list)
  df$needs_review <- TRUE
  
  return(df)
}

#' Renumber Questions
#' 
#' @description
#' Ensures questions have sequential numbering (Q1, Q2, Q3, ...).
#' Useful after filtering or combining parsers.
#' 
#' @param questions Data frame. Parsed questions
#' 
#' @return Data frame with renumbered codes
#' 
#' @export
renumber_questions <- function(questions) {
  
  if (is.null(questions) || nrow(questions) == 0) {
    return(questions)
  }
  
  questions$code <- paste0("Q", seq_len(nrow(questions)))
  
  return(questions)
}
