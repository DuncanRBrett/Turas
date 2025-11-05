# ==============================================================================
# TURAS>PARSER - Main Orchestrator
# ==============================================================================
# Purpose: Orchestrate the complete parsing workflow
# ==============================================================================

#' Parse DOCX Questionnaire
#' 
#' @description
#' Main orchestrator function that:
#' 1. Reads the Word document
#' 2. Tries pattern-based parsing
#' 3. Falls back to structure-based parsing
#' 4. Falls back to permissive parsing
#' 5. Cleans text and extracts inline options
#' 6. Detects question types
#' 7. Detects numeric bins
#' 8. Adds review flags
#' 
#' @param docx_path Character. Path to .docx file
#' @param config List with:
#'   - auto_detect: Logical. Auto-detect question types?
#'   - default_type: Character. Default type if not auto-detecting
#'   - combine_multiline: Logical. Combine multi-line questions?
#' 
#' @return Data frame of parsed questions
#' 
#' @export
parse_docx_questionnaire <- function(docx_path, config) {
  
  cat("\n=== STARTING QUESTIONNAIRE PARSER ===\n")
  cat("File:", docx_path, "\n")
  cat("Config:", paste(names(config), config, sep = "=", collapse = ", "), "\n\n")
  
  # Step 1: Read document
  cat("Step 1: Reading document...\n")
  doc_text <- read_docx_text(docx_path)
  lines <- split_docx_lines(doc_text)
  cat("  - Lines (raw):", length(lines$raw), "\n")
  cat("  - Lines (clean):", length(lines$clean), "\n\n")
  
  # Step 2: Try parsing strategies
  cat("Step 2: Parsing questions...\n")
  questions <- try_parsing_strategies(lines, config)
  cat("  - Questions found:", nrow(questions), "\n\n")
  
  # Step 3: Clean text
  cat("Step 3: Cleaning text...\n")
  questions <- clean_question_text(questions)
  questions <- clean_inline_options(questions)
  
  # Step 4: Renumber
  cat("Step 4: Renumbering questions...\n")
  questions <- renumber_questions(questions)
  
  # Step 5: Post-process
  cat("Step 5: Post-processing...\n")
  questions <- post_process_questions(questions, config)
  
  cat("=== PARSING COMPLETE ===\n")
  cat("Final question count:", nrow(questions), "\n")
  cat("Questions needing review:", sum(questions$needs_review, na.rm = TRUE), "\n\n")
  
  return(questions)
}

#' Try Parsing Strategies
#' 
#' @description
#' Tries multiple parsing strategies in order of reliability:
#' 1. Pattern-based (most reliable)
#' 2. Structure-based (medium reliability)
#' 3. Permissive (least reliable, all flagged for review)
#' 
#' @param lines List. Raw and clean lines from document
#' @param config List. Parsing configuration
#' 
#' @return Data frame of parsed questions
#' 
#' @keywords internal
try_parsing_strategies <- function(lines, config) {
  
  # Strategy 1: Pattern-based
  cat("  Trying pattern-based parsing...\n")
  questions <- parse_with_patterns(lines$clean, config)
  
  if (nrow(questions) > 0) {
    cat("  âœ“ Pattern parser found", nrow(questions), "questions\n")
    return(questions)
  }
  
  # Strategy 2: Structure-based
  cat("  Pattern parser found 0 questions\n")
  cat("  Trying structure-based parsing...\n")
  questions <- parse_by_structure(lines$raw, config)
  
  if (nrow(questions) > 0) {
    cat("  âœ“ Structure parser found", nrow(questions), "questions\n")
    return(questions)
  }
  
  # Strategy 3: Permissive
  cat("  Structure parser found 0 questions\n")
  cat("  Trying permissive parsing...\n")
  questions <- parse_permissive(lines$clean, config)
  
  if (nrow(questions) > 0) {
    cat("  âš  Permissive parser found", nrow(questions), "questions (all flagged for review)\n")
    return(questions)
  }
  
  stop("No questions found in document. Please check document format.", call. = FALSE)
}

#' Post-Process Questions
#' 
#' @description
#' Final processing stage:
#' - Detect question types
#' - Extract numeric ranges
#' - Set column counts for multi-mention
#' - Detect numeric bins
#' - Set review flags
#' 
#' @param questions Data frame. Parsed questions
#' @param config List. Parsing configuration
#' 
#' @return Data frame with completed processing
#' 
#' @keywords internal
post_process_questions <- function(questions, config) {
  
  if (is.null(questions) || nrow(questions) == 0) return(questions)
  
  n_questions <- nrow(questions)
  
  # Initialize columns
  questions$type <- rep(NA_character_, n_questions)
  questions$min_value <- rep(NA_integer_, n_questions)
  questions$max_value <- rep(NA_integer_, n_questions)
  questions$columns <- rep(NA_integer_, n_questions)
  if (!"needs_review" %in% names(questions)) {
    questions$needs_review <- rep(FALSE, n_questions)
  }
  
  # Process each question
  for (i in seq_len(n_questions)) {
    
    question_text <- as.character(questions$text[i])
    question_opts <- questions$options[[i]]
    question_conf <- as.character(questions$confidence[i])
    
    # Detect question type
    if (isTRUE(config$auto_detect)) {
      format_hint <- if ("option_format" %in% names(questions)) {
        questions$option_format[i]
      } else {
        NA_character_
      }
      
      questions$type[i] <- detect_question_type(
        question_text,
        length(question_opts),
        question_opts,
        format_hint
      )
    } else {
      questions$type[i] <- config$default_type
    }
    
    # Detect numeric range
    range_info <- detect_numeric_range(question_text)
    if (!is.null(range_info)) {
      questions$min_value[i] <- range_info$min
      questions$max_value[i] <- range_info$max
    }
    
    # Set columns for multi-mention
    if (questions$type[i] == "Multi_Mention" && length(question_opts) > 0) {
      questions$columns[i] <- length(question_opts)
    }
    
    # Detect numeric bins
    if (length(question_opts) > 0) {
      detected_bins <- detect_numeric_bins(question_opts)
      
      if (nrow(detected_bins) > 0) {
        questions$bins[[i]] <- detected_bins
        questions$needs_review[i] <- TRUE
      }
    }
    
    # Review flags
    if (question_conf == "low") {
      questions$needs_review[i] <- TRUE
    }
    
    # Special cases needing review
    has_bins <- !is.null(questions$bins[[i]]) && 
                is.data.frame(questions$bins[[i]]) && 
                nrow(questions$bins[[i]]) > 0
    
    numeric_no_bins <- (questions$type[i] == "Numeric") && !has_bins
    special_no_opts <- (questions$type[i] %in% c("Multi_Mention", "Ranking")) && 
                       length(question_opts) == 0
    
    if (numeric_no_bins || special_no_opts) {
      questions$needs_review[i] <- TRUE
    }
  }
  
  return(questions)
}
