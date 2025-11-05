# ==============================================================================
# TURAS>PARSER - Text Cleaner
# ==============================================================================
# Purpose: Clean question text and extract inline options
# ==============================================================================

#' Clean Question Text
#' 
#' @description
#' Removes formatting artifacts from question text:
#' - Long underscores (______)
#' - Long dots (.......)
#' - Multiple spaces
#' - Trailing asterisks (required field markers)
#' 
#' @param questions Data frame. Parsed questions
#' 
#' @return Data frame with cleaned text
#' 
#' @export
clean_question_text <- function(questions) {
  
  cat("\n=== CLEANING QUESTION TEXT ===\n")
  
  for (i in seq_len(nrow(questions))) {
    original_text <- questions$text[i]
    cleaned_text <- original_text
    
    # Remove formatting
    cleaned_text <- gsub("_{4,}", "", cleaned_text)      # Long underscores
    cleaned_text <- gsub("\\.{4,}", "", cleaned_text)    # Long dots
    cleaned_text <- gsub("\\s+", " ", cleaned_text)      # Multiple spaces
    cleaned_text <- trimws(cleaned_text)
    cleaned_text <- gsub("\\*+$", "", cleaned_text)      # Trailing asterisks
    cleaned_text <- trimws(cleaned_text)
    
    # Log significant changes
    if (cleaned_text != original_text) {
      questions$text[i] <- cleaned_text
      
      char_diff <- nchar(original_text) - nchar(cleaned_text)
      if (char_diff > 10) {
        cat("Question", questions$code[i], "- cleaned", char_diff, "characters\n")
      }
    }
  }
  
  cat("=== QUESTION TEXT CLEANED ===\n\n")
  
  return(questions)
}

#' Clean Inline Options
#' 
#' @description
#' Extracts inline options from question text.
#' Recognizes two formats:
#' - Parentheses: "Choose one: ( ) Option 1 ( ) Option 2"
#' - Brackets: "Select: [ ] Option 1 [X] Option 2"
#' 
#' @param questions Data frame. Parsed questions
#' 
#' @return Data frame with inline options extracted to options column
#' 
#' @export
clean_inline_options <- function(questions) {
  
  cat("\n=== CLEANING INLINE OPTIONS ===\n")
  
  # Add option_format column if not exists
  if (!"option_format" %in% names(questions)) {
    questions$option_format <- rep(NA_character_, nrow(questions))
  }
  
  for (i in seq_len(nrow(questions))) {
    question_text <- questions$text[i]
    
    # Pattern 1: Parentheses format ( )
    if (grepl("\\(\\s*\\)", question_text)) {
      inline_opts <- extract_parentheses_options(question_text)
      
      if (length(inline_opts) > 0) {
        cat("Question", questions$code[i], "- found", 
            length(inline_opts), "inline options ( )\n")
        
        questions$option_format[i] <- "parentheses"
        questions$text[i] <- remove_inline_options_from_text(question_text, "\\(\\s*\\)")
        questions$options[[i]] <- c(questions$options[[i]], inline_opts)
      }
    }
    
    # Pattern 2: Bracket format [ ] or [X]
    if (grepl("\\[\\s*[Xx]?\\s*\\]", question_text)) {
      inline_opts <- extract_bracket_options(question_text)
      
      if (length(inline_opts) > 0) {
        cat("Question", questions$code[i], "- found", 
            length(inline_opts), "bracket options [ ]\n")
        
        questions$option_format[i] <- "brackets"
        questions$text[i] <- remove_inline_options_from_text(question_text, "\\[\\s*[Xx]?\\s*\\]")
        questions$options[[i]] <- c(questions$options[[i]], inline_opts)
      }
    }
  }
  
  cat("=== INLINE OPTIONS CLEANED ===\n\n")
  
  return(questions)
}

#' Extract Parentheses Options
#' 
#' @description
#' Extracts options from parentheses format: ( ) Option 1 ( ) Option 2
#' 
#' @param text Character. Question text
#' 
#' @return Character vector of options
#' 
#' @keywords internal
extract_parentheses_options <- function(text) {
  
  pattern <- "\\(\\s*\\)\\s*([^()]+?)(?=\\s*\\(\\s*\\)|$)"
  
  matches <- gregexpr(pattern, text, perl = TRUE)
  if (matches[[1]][1] == -1) return(character(0))
  
  match_data <- regmatches(text, matches)[[1]]
  inline_opts <- gsub("^\\(\\s*\\)\\s*", "", match_data)
  inline_opts <- trimws(inline_opts)
  inline_opts <- inline_opts[nchar(inline_opts) > 0]
  
  return(inline_opts)
}

#' Extract Bracket Options
#' 
#' @description
#' Extracts options from bracket format: [ ] Option 1 [X] Option 2
#' 
#' @param text Character. Question text
#' 
#' @return Character vector of options
#' 
#' @keywords internal
extract_bracket_options <- function(text) {
  
  pattern <- "\\[\\s*[Xx]?\\s*\\]\\s*([^\\[\\]]+?)(?=\\s*\\[|$)"
  
  matches <- gregexpr(pattern, text, perl = TRUE)
  if (matches[[1]][1] == -1) return(character(0))
  
  match_data <- regmatches(text, matches)[[1]]
  inline_opts <- gsub("^\\[\\s*[Xx]?\\s*\\]\\s*", "", match_data)
  inline_opts <- trimws(inline_opts)
  inline_opts <- inline_opts[nchar(inline_opts) > 0]
  
  return(inline_opts)
}

#' Remove Inline Options from Text
#' 
#' @description
#' Removes inline option markers from question text, keeping only
#' the question portion.
#' 
#' @param text Character. Question text with inline options
#' @param pattern Character. Regex pattern to match first marker
#' 
#' @return Character. Cleaned question text
#' 
#' @keywords internal
remove_inline_options_from_text <- function(text, pattern) {
  
  # Find first marker position
  first_marker_pos <- regexpr(pattern, text)
  
  if (first_marker_pos > 0) {
    # Keep only text before first marker
    clean_text <- substr(text, 1, first_marker_pos - 1)
    clean_text <- trimws(clean_text)
    
    # Remove trailing asterisk (required field marker)
    clean_text <- gsub("\\*+$", "", clean_text)
    clean_text <- trimws(clean_text)
    
    return(clean_text)
  }
  
  return(text)
}
