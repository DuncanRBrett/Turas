# ==============================================================================
# TURAS>PARSER - Type Detector (FIXED)
# ==============================================================================
# Purpose: Automatically detect question types
# Version: 1.2.0 - FIXED: Format hints now have priority
# ==============================================================================

#' Detect Question Type
#' 
#' @description
#' Automatically detects question type based on:
#' - **FORMAT HINT FIRST**: Parentheses ( ) = Single, Brackets [ ] = Multi
#' - Question text patterns (keywords, phrases)
#' - Number of options
#' - Option values (1-10, 0-10, etc.)
#' 
#' CRITICAL FIX: Format hints now checked FIRST since they're most reliable
#' - [ ] brackets → Multi_Mention (takes priority)
#' - ( ) parentheses → Single_Response (takes priority)
#' 
#' Enhanced rules:
#' - 1-10 scales (with optional DK/NA) → Rating
#' - 0-10 scales → NPS
#' - "Recommend" questions with 0-10 → NPS
#' 
#' @param text Character. Question text
#' @param option_count Integer. Number of options
#' @param options Character vector. Option texts
#' @param format_hint Character. Optional format hint ("parentheses", "brackets")
#' 
#' @return Character. Detected question type
#' 
#' @export
detect_question_type <- function(text, option_count, options = NULL, format_hint = NA) {
  
  text_lower <- tolower(text)
  
  # ============================================================================
  # PRIORITY 0: FORMAT HINTS (MOST RELIABLE - CHECK FIRST!)
  # ============================================================================
  # This is the most reliable indicator and should override text patterns
  if (!is.na(format_hint)) {
    if (format_hint == "brackets") {
      cat("    [Format hint: brackets] → Multi_Mention\n")
      return("Multi_Mention")
    }
    if (format_hint == "parentheses") {
      cat("    [Format hint: parentheses] → Single_Response\n")
      return("Single_Response")
    }
  }
  
  # ============================================================================
  # PRIORITY 1: SPECIFIC NUMERIC PATTERNS
  # ============================================================================
  # Check option values for specific patterns
  if (!is.null(options) && length(options) > 0) {
    option_pattern <- detect_option_pattern(options)
    
    # Rule: 0-10 scale = NPS (especially with "recommend")
    if (option_pattern == "0-10" || 
        (grepl("recommend", text_lower) && option_pattern %in% c("0-10", "numeric_0_10"))) {
      return("NPS")
    }
    
    # Rule: 1-10 scale (possibly with DK/NA) = Rating
    if (option_pattern %in% c("1-10", "1-10_with_dk_na")) {
      return("Rating")
    }
  }
  
  # ============================================================================
  # PRIORITY 2: EXPLICIT TEXT PATTERNS
  # ============================================================================
  
  # NPS (very specific pattern)
  if (grepl("net.*promoter|likelihood.*recommend.*0.*10|recommend.*0.*10", text_lower)) {
    return("NPS")
  }
  
  # Ranking
  if (grepl("rank|place.*order|prioritize|arrange.*order", text_lower)) {
    return("Ranking")
  }
  
  # Multi-mention (explicit keywords - but format hint takes precedence above)
  if (grepl("select.*all|check.*all|choose.*all|mark.*all", text_lower)) {
    return("Multi_Mention")
  }
  
  # Likert scale
  if (grepl("strongly.*agree|agree.*disagree|satisfied.*dissatisfied", text_lower)) {
    return("Likert")
  }
  
  # Numeric input
  if (grepl("how.*many|number.*of|what.*is.*your.*age|enter.*number", text_lower)) {
    return("Numeric")
  }
  
  # Open-ended text response
  if (grepl("please.*explain|describe|comment|tell.*us|feedback|specify", text_lower)) {
    return("Open_End")
  }
  
  # Rating scale
  if (grepl("rate|rating|scale.*\\d+|stars?", text_lower)) {
    return("Rating")
  }
  
  # ============================================================================
  # PRIORITY 3: FALLBACK - USE OPTION COUNT
  # ============================================================================
  return(detect_type_by_options(option_count, text_lower, NA))  # Don't pass format_hint again
}

#' Detect Option Pattern
#' 
#' @description
#' Analyzes option values to detect specific patterns like:
#' - "0-10": Options are 0, 1, 2, ..., 10 (exactly 11 numeric options)
#' - "1-10": Options are 1, 2, 3, ..., 10 (exactly 10 numeric options)
#' - "1-10_with_dk_na": 1-10 plus "Don't know" and/or "Not applicable"
#' 
#' @param options Character vector. Option texts
#' 
#' @return Character. Pattern name or "none"
#' 
#' @export
detect_option_pattern <- function(options) {
  
  if (is.null(options) || length(options) == 0) return("none")
  
  # Extract numeric values
  numeric_opts <- suppressWarnings(as.numeric(options))
  numeric_opts <- numeric_opts[!is.na(numeric_opts)]
  
  if (length(numeric_opts) == 0) return("none")
  
  # Check for specific patterns
  
  # Pattern 1: 0-10 (exactly 11 numeric options from 0 to 10)
  if (length(numeric_opts) == 11 && 
      min(numeric_opts) == 0 && 
      max(numeric_opts) == 10 &&
      all(0:10 %in% numeric_opts)) {
    return("0-10")
  }
  
  # Pattern 2: 1-10 (exactly 10 numeric options from 1 to 10)
  if (length(numeric_opts) == 10 && 
      min(numeric_opts) == 1 && 
      max(numeric_opts) == 10 &&
      all(1:10 %in% numeric_opts)) {
    return("1-10")
  }
  
  # Pattern 3: 1-10 with additional non-numeric options (DK/NA)
  if (length(numeric_opts) >= 10 && 
      min(numeric_opts) == 1 && 
      max(numeric_opts) == 10 &&
      all(1:10 %in% numeric_opts) &&
      length(options) > 10) {
    return("1-10_with_dk_na")
  }
  
  # Pattern 4: 0-10 with additional non-numeric options
  if (length(numeric_opts) >= 11 && 
      min(numeric_opts) == 0 && 
      max(numeric_opts) == 10 &&
      all(0:10 %in% numeric_opts) &&
      length(options) > 11) {
    return("0-10_with_dk_na")
  }
  
  # Pattern 5: Any numeric range
  if (length(numeric_opts) >= 3) {
    return("numeric_range")
  }
  
  return("none")
}

#' Detect Type by Options
#' 
#' @description
#' Fallback method that uses option count and basic text patterns.
#' 
#' @param option_count Integer. Number of options
#' @param text_lower Character. Lowercase question text
#' @param format_hint Character. Format hint if available (not used here anymore)
#' 
#' @return Character. Detected question type
#' 
#' @keywords internal
detect_type_by_options <- function(option_count, text_lower, format_hint = NA) {
  
  # No options = open-ended or numeric
  if (option_count == 0) {
    if (grepl("age|number|how.*many|quantity", text_lower)) {
      return("Numeric")
    }
    return("Open_End")
  }
  
  # NOTE: We NO LONGER check format_hint here since it's handled at priority 0
  
  # 2-5 options = likely single response or rating
  if (option_count >= 2 && option_count <= 5) {
    if (grepl("rate|rating|scale", text_lower)) return("Rating")
    return("Single_Response")
  }
  
  # 6-11 options = could be rating or single response
  if (option_count >= 6 && option_count <= 11) {
    if (grepl("rate|rating|scale", text_lower)) return("Rating")
    return("Single_Response")
  }
  
  # 12+ options = probably multi-mention (but format hint would have caught it)
  if (option_count > 11) {
    return("Multi_Mention")
  }
  
  # Default
  return("Single_Response")
}

#' Get Question Type Patterns
#' 
#' @description
#' Returns regex patterns for each question type.
#' 
#' @return Named list of patterns
#' 
#' @export
get_question_type_patterns <- function() {
  list(
    "NPS" = "(?:net.*promoter|how.*likely.*recommend|0.*10.*scale|recommend.*0.*10)",
    "Numeric" = "(?:how.*many|number.*of|enter.*number|age|quantity)",
    "Ranking" = "(?:rank.*order|place.*in.*order|prioritize|arrange.*order)",
    "Rating" = "(?:rate.*following|rating.*scale|scale.*from.*\\d+|stars?|1.*10)",
    "Likert" = "(?:strongly.*agree|agree.*disagree|satisfied.*dissatisfied)",
    "Multi_Mention" = "(?:select.*all.*apply|check.*all.*apply|choose.*all)",
    "Open_End" = "(?:please.*explain|describe|comment|tell.*us|feedback)"
  )
}

#' Get Question Types
#' 
#' @description
#' Returns available question types with descriptions.
#' 
#' @return Named list of question types
#' 
#' @export
get_question_types <- function() {
  list(
    "Single_Response" = "Single choice question (select one)",
    "Multi_Mention" = "Multiple choice question (select all that apply)",
    "Likert" = "Likert scale (strongly agree to strongly disagree)",
    "Rating" = "Rating scale (e.g., 1-5 stars, 1-10 scale)",
    "NPS" = "Net Promoter Score (0-10 likelihood to recommend)",
    "Numeric" = "Numeric input or numeric bins",
    "Ranking" = "Rank items in order of preference",
    "Open_End" = "Open-ended text response"
  )
}

#' Detect Numeric Range
#' 
#' @description
#' Extracts min/max values from question text for numeric questions.
#' Examples: "(1-10)", "1 to 10 scale", "scale from 1-7"
#' 
#' @param text Character. Question text
#' 
#' @return List with min and max, or NULL if not found
#' 
#' @export
detect_numeric_range <- function(text) {
  
  # Try different patterns
  patterns <- c(
    "\\((\\d+)-(\\d+)\\)",           # (1-10)
    "(\\d+)\\s*to\\s*(\\d+)",        # 1 to 10
    "(\\d+)\\s*-\\s*(\\d+)",         # 1-10 or 1 - 10
    "from\\s*(\\d+)\\s*to\\s*(\\d+)" # from 1 to 10
  )
  
  for (pattern in patterns) {
    matches <- stringr::str_match(text, pattern)
    if (!is.na(matches[1])) {
      min_val <- as.integer(matches[2])
      max_val <- as.integer(matches[3])
      
      if (!is.na(min_val) && !is.na(max_val) && max_val > min_val) {
        return(list(min = min_val, max = max_val))
      }
    }
  }
  
  return(NULL)
}

#' Suggest Columns for Multi-Mention
#' 
#' @description
#' Suggests number of columns for multi-mention questions based on options.
#' 
#' @param option_count Integer. Number of options
#' 
#' @return Integer. Suggested column count
#' 
#' @export
suggest_multi_mention_columns <- function(option_count) {
  
  if (is.na(option_count) || option_count < 1) {
    return(1)
  }
  
  # Exact match for reasonable counts
  if (option_count <= 20) {
    return(option_count)
  }
  
  # For very large option counts, suggest a reasonable subset
  if (option_count <= 50) {
    return(20)
  }
  
  # Cap at 30 for very large lists
  return(30)
}
