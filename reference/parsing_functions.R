# ==============================================================================
# PARSING FUNCTIONS - COMPLETE WORKING VERSION
# ==============================================================================
# Version: 3.0 - All features working
# ==============================================================================

#' Parse Word Document Questionnaire
parse_docx_questionnaire <- function(docx_path, config) {
  if (!file.exists(docx_path)) stop("File not found: ", docx_path)
  if (!grepl("\\.docx?$", docx_path, ignore.case = TRUE)) stop("File must be .docx format")
  
  doc_text <- read_docx_text(docx_path)
  all_lines <- strsplit(doc_text, "\n")[[1]]
  all_lines <- trimws(all_lines)
  lines_raw <- all_lines
  lines_clean <- all_lines[nchar(all_lines) > 0]
  
  questions <- parse_with_patterns(lines_clean, config)
  if (is.null(questions) || nrow(questions) == 0) {
    message("Pattern parser found 0 questions. Trying structure-based...")
    questions <- parse_by_structure(lines_raw, config)
  }
  if (is.null(questions) || nrow(questions) == 0) {
    message("Structure parser found 0 questions. Trying permissive...")
    questions <- parse_permissive(lines_clean, config)
  }
  if (is.null(questions) || nrow(questions) == 0) {
    stop("No questions found. Please check document format.")
  }
  
  questions <- clean_question_text(questions)
  questions <- clean_inline_options(questions)
  questions <- renumber_questions(questions)
  questions <- post_process_questions(questions, config)
  
  return(questions)
}

#' Read DOCX Text
read_docx_text <- function(docx_path) {
  doc <- officer::read_docx(docx_path)
  content <- officer::docx_summary(doc)
  para_content <- content[content$content_type == "paragraph", ]
  if (nrow(para_content) == 0) stop("No text content found in document")
  return(paste(para_content$text, collapse = "\n"))
}

#' Parse with Patterns
parse_with_patterns <- function(lines, config) {
  question_patterns <- c(
    "^(?:Q|Question|#)\\s*(\\d+)[\\.:)\\s]+(.+)",
    "^(\\d+)[\\.:)]\\s+(.+)",
    "^\\[(\\d+)\\]\\s*(.+)",
    "^([A-Z]\\d+)\\.\\s+(.+)"
  )
  option_patterns <- c(
    "^[a-z][\\.:)]\\s+(.+)",
    "^\\d+[\\.:)]\\s+(.+)",
    "^[-•*○◦▪▫►▻]\\s*(.+)",
    "^\\s+(.+)"
  )
  
  questions_list <- list()
  current_question <- NULL
  
  for (i in seq_along(lines)) {
    line <- lines[i]
    is_question <- FALSE
    question_info <- NULL
    
    for (pattern in question_patterns) {
      matches <- stringr::str_match(line, pattern)
      if (!is.na(matches[1])) {
        is_question <- TRUE
        question_info <- list(number = matches[2], text = matches[3])
        break
      }
    }
    
    if (is_question) {
      if (!is.null(current_question)) {
        questions_list[[length(questions_list) + 1]] <- current_question
      }
      current_question <- list(
        code = paste0("Q", question_info$number),
        text = question_info$text,
        original_text = line,
        options = character(0),
        confidence = "high",
        line_number = i
      )
    } else if (!is.null(current_question)) {
      is_option <- FALSE
      for (pattern in option_patterns) {
        if (grepl(pattern, line, perl = TRUE)) {
          is_option <- TRUE
          break
        }
      }
      
      line_length <- nchar(line)
      should_combine <- isTRUE(config$combine_multiline)
      
      if (is_option && line_length < 200) {
        option_text <- extract_option_text(line)
        if (nchar(option_text) > 0) {
          current_question$options <- c(current_question$options, option_text)
        }
      } else if (should_combine && line_length > 0 && line_length < 200) {
        current_question$text <- paste(current_question$text, line)
      }
    }
  }
  
  if (!is.null(current_question)) {
    questions_list[[length(questions_list) + 1]] <- current_question
  }
  
  if (length(questions_list) == 0) return(create_empty_questions_df())
  return(questions_list_to_df(questions_list))
}

#' Parse by Structure
parse_by_structure <- function(lines, config) {
  questions_list <- list()
  current_question <- NULL
  previous_blank <- FALSE
  
  for (i in seq_along(lines)) {
    line <- lines[i]
    line_length <- nchar(line)
    
    if (line_length == 0) {
      previous_blank <- TRUE
      next
    }
    
    has_question_mark <- grepl("\\?", line)
    looks_like_header <- (line_length > 30) && (line_length < 200)
    
    if (previous_blank && looks_like_header && has_question_mark) {
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
      current_question$options <- c(current_question$options, line)
    }
    
    previous_blank <- FALSE
  }
  
  if (!is.null(current_question)) {
    questions_list[[length(questions_list) + 1]] <- current_question
  }
  
  if (length(questions_list) == 0) return(create_empty_questions_df())
  return(questions_list_to_df(questions_list))
}

#' Parse Permissive
parse_permissive <- function(lines, config) {
  questions_list <- list()
  
  for (i in seq_along(lines)) {
    line <- lines[i]
    line_length <- nchar(line)
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
  
  if (length(questions_list) == 0) return(create_empty_questions_df())
  df <- questions_list_to_df(questions_list)
  df$needs_review <- TRUE
  return(df)
}

#' Extract Option Text
extract_option_text <- function(line) {
  patterns <- c(
    "^[a-z][\\.:)\\s]+(.+)",
    "^\\d+[\\.:)]\\s+(.+)",
    "^[-•*○◦▪▫►▻]\\s*(.+)",
    "^\\s+(.+)"
  )
  
  for (pattern in patterns) {
    matches <- stringr::str_match(line, pattern)
    if (!is.na(matches[1])) {
      return(trimws(matches[2]))
    }
  }
  return(trimws(line))
}

#' Clean Question Text
clean_question_text <- function(questions) {
  cat("\n=== CLEANING QUESTION TEXT ===\n")
  
  for (i in 1:nrow(questions)) {
    original_text <- questions$text[i]
    cleaned_text <- original_text
    cleaned_text <- gsub("_{4,}", "", cleaned_text)
    cleaned_text <- gsub("\\.{4,}", "", cleaned_text)
    cleaned_text <- gsub("\\s+", " ", cleaned_text)
    cleaned_text <- trimws(cleaned_text)
    cleaned_text <- gsub("\\*+$", "", cleaned_text)
    cleaned_text <- trimws(cleaned_text)
    
    if (cleaned_text != original_text) {
      questions$text[i] <- cleaned_text
      if (nchar(original_text) - nchar(cleaned_text) > 10) {
        cat("Question", questions$code[i], "- cleaned", 
            nchar(original_text) - nchar(cleaned_text), "characters\n")
      }
    }
  }
  
  cat("=== QUESTION TEXT CLEANED ===\n\n")
  return(questions)
}

#' Clean Inline Options
clean_inline_options <- function(questions) {
  cat("\n=== CLEANING INLINE OPTIONS ===\n")
  questions$option_format <- rep(NA_character_, nrow(questions))
  
  for (i in 1:nrow(questions)) {
    question_text <- questions$text[i]
    pattern1 <- "\\(\\s*\\)\\s*([^()]+?)(?=\\s*\\(\\s*\\)|$)"
    
    if (grepl("\\(\\s*\\)", question_text)) {
      matches <- gregexpr(pattern1, question_text, perl = TRUE)
      if (matches[[1]][1] != -1) {
        match_data <- regmatches(question_text, matches)[[1]]
        inline_opts <- gsub("^\\(\\s*\\)\\s*", "", match_data)
        inline_opts <- trimws(inline_opts)
        inline_opts <- inline_opts[nchar(inline_opts) > 0]
        
        if (length(inline_opts) > 0) {
          cat("Question", questions$code[i], "- found", length(inline_opts), "inline options ( )\n")
          questions$option_format[i] <- "parentheses"
          first_paren_pos <- regexpr("\\(\\s*\\)", question_text)
          if (first_paren_pos > 0) {
            clean_text <- substr(question_text, 1, first_paren_pos - 1)
            clean_text <- trimws(clean_text)
            # Remove trailing asterisk (required field marker)
            clean_text <- gsub("\\*+$", "", clean_text)
            clean_text <- trimws(clean_text)
            
            questions$text[i] <- clean_text
            existing_opts <- questions$options[[i]]
            questions$options[[i]] <- if (length(existing_opts) > 0) c(existing_opts, inline_opts) else inline_opts
            cat("  Format: Single-response ( )\n")
            cat("  Cleaned text:", substr(clean_text, 1, 60), "...\n")
            cat("  Extracted options:", paste(inline_opts[1:min(3, length(inline_opts))], collapse = ", "), 
                if (length(inline_opts) > 3) "..." else "", "\n")
          }
        }
      }
    }
    
    pattern2 <- "\\[\\s*[Xx]?\\s*\\]\\s*([^\\[\\]]+?)(?=\\s*\\[|$)"
    if (grepl("\\[\\s*[Xx]?\\s*\\]", question_text)) {
      matches <- gregexpr(pattern2, question_text, perl = TRUE)
      if (matches[[1]][1] != -1) {
        match_data <- regmatches(question_text, matches)[[1]]
        inline_opts <- gsub("^\\[\\s*[Xx]?\\s*\\]\\s*", "", match_data)
        inline_opts <- trimws(inline_opts)
        inline_opts <- inline_opts[nchar(inline_opts) > 0]
        
        if (length(inline_opts) > 0) {
          cat("Question", questions$code[i], "- found", length(inline_opts), "bracket options [ ]\n")
          questions$option_format[i] <- "brackets"
          first_bracket_pos <- regexpr("\\[\\s*[Xx]?\\s*\\]", question_text)
          if (first_bracket_pos > 0) {
            clean_text <- substr(question_text, 1, first_bracket_pos - 1)
            clean_text <- trimws(clean_text)
            # Remove trailing asterisk (required field marker)
            clean_text <- gsub("\\*+$", "", clean_text)
            clean_text <- trimws(clean_text)
            
            questions$text[i] <- clean_text
            existing_opts <- questions$options[[i]]
            questions$options[[i]] <- if (length(existing_opts) > 0) c(existing_opts, inline_opts) else inline_opts
            cat("  Format: Multi-mention [ ]\n")
          }
        }
      }
    }
  }
  
  cat("=== INLINE OPTIONS CLEANED ===\n\n")
  return(questions)
}

#' Renumber Questions
renumber_questions <- function(questions) {
  cat("\n=== RENUMBERING QUESTIONS ===\n")
  n_questions <- nrow(questions)
  width <- if (n_questions < 100) 2 else if (n_questions < 1000) 3 else 4
  cat("Total questions:", n_questions, "\n")
  cat("Using", width, "digit padding\n")
  
  for (i in 1:n_questions) {
    questions$code[i] <- sprintf(paste0("Q%0", width, "d"), i)
  }
  
  cat("Question codes:", questions$code[1], "...", questions$code[n_questions], "\n")
  cat("=== RENUMBERING COMPLETE ===\n\n")
  return(questions)
}

#' Detect Question Type - WITH FORMAT_HINT PARAMETER
detect_question_type <- function(text, option_count, options = NULL, format_hint = NA) {
  text_lower <- tolower(text)
  type_patterns <- get_question_type_patterns()
  
  # PRIORITY 1: Check for 1-10 rating scale
  if (!is.null(options) && length(options) >= 10) {
    opts_no_dk <- options[!grepl("don'?t know", tolower(options))]
    if (length(opts_no_dk) >= 10) {
      numeric_opts <- suppressWarnings(as.numeric(opts_no_dk))
      if (!any(is.na(numeric_opts))) {
        if (all(numeric_opts %in% c(1:10))) return("Rating")
        if (all(numeric_opts %in% c(0:10))) {
          if (grepl("recommend|likely.*recommend|net.*promoter", text_lower)) return("NPS")
          return("Rating")
        }
      }
    }
  }
  
  # PRIORITY 2: Use format markers
  if (!is.na(format_hint)) {
    if (format_hint == "brackets") return("Multi_Mention")
    if (format_hint == "parentheses") {
      if (grepl("recommend.*scale.*0.*10|likely.*recommend.*0.*10|net.*promoter", text_lower)) return("NPS")
      if (grepl("rate|rating|scale.*\\d+", text_lower)) {
        if (!is.null(options) && length(options) > 0) {
          if (all(grepl("^\\d+$", options[1:min(3, length(options))]))) return("Rating")
        }
      }
      if (grepl("satisfied|agree|disagree|extent", text_lower)) {
        if (!is.null(options)) {
          likert_keywords <- c("satisfied", "dissatisfied", "agree", "disagree", "strongly", "somewhat")
          if (any(sapply(likert_keywords, function(kw) any(grepl(kw, tolower(options)))))) return("Likert")
        }
      }
      return("Single_Response")
    }
  }
  
  # PRIORITY 3: Pattern matching
  specific_order <- c("NPS", "Numeric", "Ranking", "Rating", "Likert", "Multi_Mention", "Text")
  for (type_name in specific_order) {
    if (type_name %in% names(type_patterns)) {
      pattern <- type_patterns[[type_name]]
      if (grepl(pattern, text_lower, perl = TRUE)) return(type_name)
    }
  }
  
  # PRIORITY 4: Option analysis
  if (!is.null(options) && length(options) > 0) {
    if (all(grepl("^\\d+$", options))) return("Rating")
    numeric_opts <- suppressWarnings(as.numeric(options))
    if (!any(is.na(numeric_opts)) && length(numeric_opts) >= 3) {
      if (max(numeric_opts) - min(numeric_opts) == length(numeric_opts) - 1) return("Rating")
    }
    likert_keywords <- c("strongly agree", "agree", "disagree", "strongly disagree",
                         "very satisfied", "satisfied", "dissatisfied", "very dissatisfied")
    if (any(sapply(likert_keywords, function(kw) any(grepl(kw, tolower(options)))))) return("Likert")
  }
  
  # PRIORITY 5: Heuristics
  if (option_count == 0) {
    if (grepl("how many|number|quantity|age|income|percent", text_lower)) return("Numeric")
    return("Text")
  }
  if (option_count == 2) return("Single_Response")
  if (option_count >= 3 && option_count <= 5) {
    if (grepl("rate|rating|scale", text_lower)) return("Rating")
    return("Single_Response")
  }
  if (option_count >= 6 && option_count <= 11) {
    if (grepl("rate|rating|scale", text_lower)) return("Rating")
    if (grepl("which|what.*following", text_lower)) return("Multi_Mention")
    return("Single_Response")
  }
  if (option_count > 11) return("Multi_Mention")
  
  return("Single_Response")
}

#' Post-Process Questions
post_process_questions <- function(questions, config) {
  cat("\n=== POST-PROCESS (NO LIST VERSION) ===\n")
  cat("Input questions rows:", nrow(questions), "\n")
  
  if (is.null(questions) || nrow(questions) == 0) return(questions)
  
  n_questions <- nrow(questions)
  cat("Processing", n_questions, "questions\n")
  
  questions$type <- rep(NA_character_, n_questions)
  questions$min_value <- rep(NA_integer_, n_questions)
  questions$max_value <- rep(NA_integer_, n_questions)
  questions$columns <- rep(NA_integer_, n_questions)
  questions$needs_review <- rep(FALSE, n_questions)
  
  cat("Main processing loop...\n")
  
  for (i in seq_len(n_questions)) {
    if (i %% 10 == 0) cat("Processing question", i, "of", n_questions, "\n")
    
    question_text <- as.character(questions$text[i])
    question_opts <- questions$options[[i]]
    question_conf <- as.character(questions$confidence[i])
    
    should_auto_detect <- isTRUE(config$auto_detect)
    
    if (should_auto_detect) {
      format_hint <- if ("option_format" %in% names(questions)) questions$option_format[i] else NA_character_
      questions$type[i] <- detect_question_type(question_text, length(question_opts), question_opts, format_hint)
    } else {
      questions$type[i] <- config$default_type
    }
    
    range_info <- detect_numeric_range(question_text)
    questions$min_value[i] <- if (is.na(range_info$min)) NA_integer_ else range_info$min
    questions$max_value[i] <- if (is.na(range_info$max)) NA_integer_ else range_info$max
    
    is_multi <- questions$type[i] == "Multi_Mention"
    has_options <- length(question_opts) > 0
    if (is_multi && has_options) questions$columns[i] <- length(question_opts)
    
    questions$needs_review[i] <- (question_conf == "low")
  }
  
  cat("Main loop complete. Now processing bins...\n")
  bins_column <- as.list(questions$bins)
  cat("Extracted bins column, length:", length(bins_column), "\n")
  
  for (i in seq_len(n_questions)) {
    if (i %% 10 == 0) cat("Processing bins for question", i, "of", n_questions, "\n")
    question_opts <- questions$options[[i]]
    detected_bins <- detect_numeric_bins_robust(question_opts)
    
    if (nrow(detected_bins) > 0) {
      bins_column[[i]] <- detected_bins
      questions$needs_review[i] <- TRUE
    } else {
      bins_column[i] <- list(NULL)
    }
  }
  
  cat("Bins processing complete. Reassigning bins column...\n")
  questions$bins <- I(bins_column)
  
  cat("Bins processed. Final review flags...\n")
  for (i in seq_len(n_questions)) {
    question_opts <- questions$options[[i]]
    has_bins <- !is.null(questions$bins[[i]]) && is.data.frame(questions$bins[[i]]) && nrow(questions$bins[[i]]) > 0
    numeric_no_bins <- (questions$type[i] == "Numeric") && !has_bins
    special_no_opts <- (questions$type[i] %in% c("Multi_Mention", "Ranking")) && length(question_opts) == 0
    
    if (numeric_no_bins || special_no_opts || has_bins) questions$needs_review[i] <- TRUE
  }
  
  cat("=== POST-PROCESS COMPLETE ===\n\n")
  return(questions)
}

#' Detect Numeric Bins
detect_numeric_bins_robust <- function(options) {
  bins <- data.frame(min = numeric(0), max = numeric(0), label = character(0), stringsAsFactors = FALSE)
  
  for (opt in options) {
    pattern1 <- "^(\\d+)\\s*[\\-—–]\\s*(\\d+)(?:\\s*(.*))?$"
    matches1 <- stringr::str_match(opt, pattern1)
    if (!is.na(matches1[1])) {
      bins <- rbind(bins, data.frame(min = as.numeric(matches1[2]), max = as.numeric(matches1[3]), 
                                      label = trimws(opt), stringsAsFactors = FALSE))
      next
    }
    
    pattern2 <- "^(\\d+)\\s+to\\s+(\\d+)(?:\\s*(.*))?$"
    matches2 <- stringr::str_match(tolower(opt), pattern2)
    if (!is.na(matches2[1])) {
      bins <- rbind(bins, data.frame(min = as.numeric(matches2[2]), max = as.numeric(matches2[3]), 
                                      label = trimws(opt), stringsAsFactors = FALSE))
      next
    }
    
    pattern3 <- "^(?:<|under|below|less\\s+than)\\s*(\\d+)(?:\\s*(.*))?$"
    matches3 <- stringr::str_match(tolower(opt), pattern3)
    if (!is.na(matches3[1])) {
      max_val <- as.numeric(matches3[2])
      bins <- rbind(bins, data.frame(min = 0, max = max_val - 1, label = trimws(opt), stringsAsFactors = FALSE))
      next
    }
    
    pattern4 <- "^(\\d+)\\s*(?:\\+|and\\s+(?:over|above)|or\\s+(?:more|older))(?:\\s*(.*))?$"
    matches4 <- stringr::str_match(tolower(opt), pattern4)
    if (!is.na(matches4[1])) {
      min_val <- as.numeric(matches4[2])
      bins <- rbind(bins, data.frame(min = min_val, max = 999, label = trimws(opt), stringsAsFactors = FALSE))
      next
    }
  }
  
  return(bins)
}

#' Detect Numeric Range
detect_numeric_range <- function(text) {
  pattern1 <- "\\((\\d+)\\s*-\\s*(\\d+)\\)"
  matches1 <- stringr::str_match(text, pattern1)
  if (!is.na(matches1[1])) return(list(min = as.integer(matches1[2]), max = as.integer(matches1[3])))
  
  pattern2 <- "(\\d+)\\s*(?:to|-|through)\\s*(\\d+)\\s*scale"
  matches2 <- stringr::str_match(tolower(text), pattern2)
  if (!is.na(matches2[1])) return(list(min = as.integer(matches2[2]), max = as.integer(matches2[3])))
  
  return(list(min = NA_integer_, max = NA_integer_))
}

#' Convert Questions List to Data Frame
questions_list_to_df <- function(questions_list) {
  data.frame(
    code = sapply(questions_list, function(q) q$code),
    text = sapply(questions_list, function(q) q$text),
    type = NA_character_,
    options = I(lapply(questions_list, function(q) q$options)),
    option_format = NA_character_,
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
