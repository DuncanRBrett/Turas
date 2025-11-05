# ==============================================================================
# TURAS>PARSER - Pattern Parser (FIXED v1.1.0)
# ==============================================================================
# Purpose: Parse questionnaires using pattern matching
# Version: 1.1.0 - NOW TRACKS OPTION FORMATS!
# ==============================================================================

#' Parse with Patterns
#' 
#' @description
#' Identifies questions and options using regex patterns.
#' Recognizes common questionnaire formats:
#' - "Q1. Text", "Question 1:", "1. Text", "[1] Text", "A1. Text"
#' 
#' FIXED: Now detects and stores option format (parentheses vs brackets)
#' FIXED: Better detection of ( ) and [ ] option formats
#' FIXED: Handles inline options (multiple options on one line)
#' 
#' @param lines Character vector. Cleaned lines from document
#' @param config List. Parsing configuration
#' 
#' @return Data frame of parsed questions or empty df if no matches
#' 
#' @export
parse_with_patterns <- function(lines, config) {
  
  # Question patterns (ordered by specificity)
  question_patterns <- c(
    "^(?:Q|Question|#)\\s*(\\d+)[\\.:)\\s]+(.+)",  # Q1. or Question 1:
    "^(\\d+)[\\.:)]\\s+(.+)",                       # 1. or 1)
    "^\\[(\\d+)\\]\\s*(.+)",                        # [1]
    "^([A-Z]\\d+)\\.\\s+(.+)"                       # A1.
  )
  
  # Option patterns (ENHANCED) - WITH NAMES FOR FORMAT DETECTION
  option_patterns <- list(
    list(pattern = "^\\(\\s*\\)\\s+(.+)", format = "parentheses"),  # ( ) Option
    list(pattern = "^\\[\\s*\\]\\s+(.+)", format = "brackets"),     # [ ] Option
    list(pattern = "^[a-z][\\.:)]\\s+(.+)", format = NA),           # a. or a)
    list(pattern = "^\\d+[\\.:)]\\s+(.+)", format = NA),            # 1. or 1)
    list(pattern = "^[-•*○◦▪▫►▻]\\s*(.+)", format = NA),            # Bullets
    list(pattern = "^\\s{2,}(.+)", format = NA)                     # Indented
  )
  
  questions_list <- list()
  current_question <- NULL
  
  for (i in seq_along(lines)) {
    line <- lines[i]
    
    # Check if line is a question
    is_question <- FALSE
    question_info <- NULL
    
    for (pattern in question_patterns) {
      matches <- stringr::str_match(line, pattern)
      if (!is.na(matches[1])) {
        is_question <- TRUE
        question_info <- list(
          number = matches[2],
          text = matches[3]
        )
        break
      }
    }
    
    if (is_question) {
      # Save previous question if exists
      if (!is.null(current_question)) {
        questions_list[[length(questions_list) + 1]] <- current_question
      }
      
      # Start new question
      current_question <- list(
        code = paste0("Q", question_info$number),
        text = question_info$text,
        original_text = line,
        options = character(0),
        option_format = NA_character_,  # TRACK FORMAT!
        confidence = "high",
        line_number = i
      )
      
    } else if (!is.null(current_question)) {
      # Check if line contains inline options (multiple options on one line)
      inline_options <- extract_inline_options(line)
      
      if (length(inline_options) > 1) {
        # Multiple options found on this line
        current_question$options <- c(current_question$options, inline_options)
        next
      }
      
      # Process as potential option or continuation (single option per line)
      is_option <- FALSE
      option_text <- NULL
      detected_format <- NA_character_
      
      # Try each option pattern and TRACK THE FORMAT
      for (opt_info in option_patterns) {
        matches <- stringr::str_match(line, opt_info$pattern)
        if (!is.na(matches[1])) {
          is_option <- TRUE
          option_text <- trimws(matches[2])
          detected_format <- opt_info$format  # STORE THE FORMAT!
          break
        }
      }
      
      line_length <- nchar(line)
      should_combine <- isTRUE(config$combine_multiline)
      
      if (is_option && line_length < 200 && nchar(option_text) > 0) {
        # Add as option
        current_question$options <- c(current_question$options, option_text)
        
        # SET THE FORMAT (only if not already set and format was detected)
        if (is.na(current_question$option_format) && !is.na(detected_format)) {
          current_question$option_format <- detected_format
          cat("  Question", current_question$code, "format detected:", detected_format, "\n")
        }
        
      } else if (should_combine && line_length > 0 && line_length < 200 && !is_option) {
        # Only combine if it's NOT an option
        # This prevents option text from being merged into question text
        current_question$text <- paste(current_question$text, line)
      }
    }
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

#' Extract Inline Options
#' 
#' @description
#' Extracts multiple options from a single line when they're formatted like:
#' "Never ( ) Rarely ( ) Sometimes ( ) Usually ( ) Always ( )"
#' "1 ( ) 2 ( ) 3 ( ) 4 ( ) 5 ( )"
#' 
#' Returns a character vector of options if multiple found, or empty vector.
#' 
#' @param line Character. Line that may contain inline options
#' 
#' @return Character vector. Extracted options (empty if < 2 found)
#' 
#' @keywords internal
extract_inline_options <- function(line) {
  
  # Pattern to find "text ( )" or "text [ ]"
  # This matches: word(s) or number(s) followed by ( ) or [ ]
  pattern <- "([A-Za-z0-9][A-Za-z0-9\\s'/-]*?)\\s*(?:\\(\\s*\\)|\\[\\s*\\])"
  
  matches <- stringr::str_match_all(line, pattern)[[1]]
  
  if (nrow(matches) >= 2) {
    # Found multiple options on one line
    options <- trimws(matches[, 2])
    # Remove empty options
    options <- options[nchar(options) > 0]
    return(options)
  }
  
  return(character(0))
}

#' Extract Option Text
#' 
#' @description
#' Extracts the text portion from an option line by removing
#' leading markers (letters, numbers, bullets, parentheses, brackets, etc.)
#' 
#' ENHANCED: Better handling of ( ) and [ ] markers
#' 
#' @param line Character. Option line with marker
#' 
#' @return Character. Cleaned option text
#' 
#' @export
extract_option_text <- function(line) {
  
  patterns <- c(
    "^\\(\\s*\\)\\s+(.+)",       # ( ) radio button
    "^\\[\\s*\\]\\s+(.+)",       # [ ] checkbox
    "^[a-z][\\.:)\\s]+(.+)",     # a. or a) or a:
    "^\\d+[\\.:)]\\s+(.+)",      # 1. or 1) or 1:
    "^[-•*○◦▪▫►▻]\\s*(.+)",      # Bullets
    "^\\s{2,}(.+)"               # Indented (2+ spaces)
  )
  
  for (pattern in patterns) {
    matches <- stringr::str_match(line, pattern)
    if (!is.na(matches[1])) {
      return(trimws(matches[2]))
    }
  }
  
  return(trimws(line))
}

#' Questions List to Data Frame
#' 
#' @description
#' Converts list of parsed questions into standardized data frame.
#' 
#' @param questions_list List. Questions with code, text, options, etc.
#' 
#' @return Data frame with standardized columns
#' 
#' @export
questions_list_to_df <- function(questions_list) {
  
  data.frame(
    code = sapply(questions_list, function(q) q$code),
    text = sapply(questions_list, function(q) q$text),
    type = NA_character_,
    options = I(lapply(questions_list, function(q) q$options)),
    option_format = sapply(questions_list, function(q) {
      if ("option_format" %in% names(q)) q$option_format else NA_character_
    }),
    bins = I(lapply(questions_list, function(q) NULL)),
    min_value = NA_integer_,
    max_value = NA_integer_,
    columns = NA_integer_,
    confidence = sapply(questions_list, function(q) q$confidence),
    needs_review = FALSE,
    stringsAsFactors = FALSE
  )
}

#' Create Empty Questions Data Frame
#' 
#' @description
#' Creates an empty data frame with correct column structure.
#' 
#' @return Empty data frame with question columns
#' 
#' @export
create_empty_questions_df <- function() {
  
  data.frame(
    code = character(0),
    text = character(0),
    type = character(0),
    options = I(list()),
    option_format = character(0),
    bins = I(list()),
    min_value = integer(0),
    max_value = integer(0),
    columns = integer(0),
    confidence = character(0),
    needs_review = logical(0),
    stringsAsFactors = FALSE
  )
}
