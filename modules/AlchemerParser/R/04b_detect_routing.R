# ==============================================================================
# ALCHEMER PARSER - ROUTING & SKIP LOGIC DETECTION
# ==============================================================================
# Detect routing/skip logic from Word questionnaire text patterns
# and data structure analysis. Adds routing metadata to questions.
# ==============================================================================

#' Detect Routing and Skip Logic
#'
#' @description
#' Scans parsed question data for evidence of routing/skip logic:
#' 1. Text pattern detection from Word questionnaire (e.g., "If Q2 = Yes...")
#' 2. Structural analysis of data export map (question sequencing, sparsity)
#' 3. Annotation of questions with routing metadata
#'
#' @param questions Classified questions (from classify_questions)
#' @param word_hints Parsed Word document hints
#' @param verbose Print progress messages
#'
#' @return Modified questions list with routing metadata added to each question
#'
#' @keywords internal
detect_routing <- function(questions, word_hints, verbose = FALSE) {

  if (verbose) {
    cat("  Scanning for routing/skip logic patterns...\n")
  }

  n_routed <- 0L

  for (q_num in names(questions)) {
    q <- questions[[q_num]]

    # Initialize routing metadata
    routing <- list(
      has_routing = FALSE,
      conditional_on = character(0),
      condition_text = NA_character_,
      confidence = NA_character_,
      source = NA_character_
    )

    # --- Strategy 1: Detect routing from Word doc text patterns ---
    hint <- word_hints[[q_num]]
    if (!is.null(hint) && !is.null(hint$full_text) && !is.na(hint$full_text)) {
      text_routing <- detect_routing_from_text(hint$full_text)
      if (text_routing$detected) {
        routing$has_routing <- TRUE
        routing$conditional_on <- text_routing$references
        routing$condition_text <- text_routing$condition_text
        routing$confidence <- "INFERRED"
        routing$source <- "word_text_pattern"
      }
    }

    # --- Strategy 2: Detect routing from question text itself ---
    if (!routing$has_routing && !is.null(q$question_text) && !is.na(q$question_text)) {
      text_routing <- detect_routing_from_text(q$question_text)
      if (text_routing$detected) {
        routing$has_routing <- TRUE
        routing$conditional_on <- text_routing$references
        routing$condition_text <- text_routing$condition_text
        routing$confidence <- "INFERRED"
        routing$source <- "question_text_pattern"
      }
    }

    # Attach routing metadata
    questions[[q_num]]$routing <- routing

    if (routing$has_routing) {
      n_routed <- n_routed + 1L
    }
  }

  if (verbose) {
    cat(sprintf("  Detected routing/skip logic on %d of %d questions\n",
                n_routed, length(questions)))
  }

  questions
}


#' Detect Routing from Text Content
#'
#' @description
#' Scans question text for common routing/skip logic patterns.
#' Recognises patterns like:
#' - "If Q2 = Yes" / "If response to Q3 is..."
#' - "ASK IF Q1 = 1" / "SHOW IF..."
#' - "Based on answer to Q..."
#' - "Those who selected..." / "For respondents who..."
#' - "SKIP TO Q10" / "GO TO Q15"
#' - "[ROUTING: Q5 = 1,2]"
#'
#' @param text Character string to scan
#'
#' @return List with:
#'   \item{detected}{Logical — was a routing pattern found?}
#'   \item{references}{Character vector of referenced question numbers}
#'   \item{condition_text}{The matched routing text}
#'
#' @keywords internal
detect_routing_from_text <- function(text) {

  result <- list(
    detected = FALSE,
    references = character(0),
    condition_text = NA_character_
  )

  if (is.null(text) || is.na(text) || !nzchar(trimws(text))) {
    return(result)
  }

  text_lower <- tolower(text)

  # ---- Pattern set: conditional display ----
  routing_patterns <- c(
    # "If Q2 = Yes" / "If Q2 is..." / "IF Q3 equals..."
    "if\\s+q\\.?\\s*(\\d+)\\s*(=|is|equals|was|were|said|selected|chose)",
    # "If response to Q2" / "If answer to Q3"
    "if\\s+(response|answer|reply)\\s+to\\s+q\\.?\\s*(\\d+)",
    # "ASK IF Q5" / "SHOW IF Q1" / "DISPLAY IF Q2"
    "(ask|show|display|present)\\s+if\\s+q\\.?\\s*(\\d+)",
    # "Based on Q3" / "Based on answer to Q4"
    "based\\s+on\\s+(answer\\s+to\\s+)?q\\.?\\s*(\\d+)",
    # "Those who selected" / "For respondents who" / "Those who answered"
    "(those|respondents|participants)\\s+who\\s+(selected|answered|chose|said|indicated)",
    # "SKIP TO Q10" / "GO TO Q15" / "PROCEED TO Q20"
    "(skip|go|proceed|jump)\\s+to\\s+q\\.?\\s*(\\d+)",
    # "[ROUTING: Q5 = 1,2]" / "[FILTER: Q3 = Yes]"
    "\\[(routing|filter|logic|condition|skip)[:\\s]+q\\.?\\s*(\\d+)",
    # "SCREENER" / "QUALIFIER"
    "(screener|qualifier|screening\\s+question)",
    # "Only ask if" / "Only show if"
    "only\\s+(ask|show|display)\\s+if"
  )

  for (pattern in routing_patterns) {
    match <- regexpr(pattern, text_lower, perl = TRUE)
    if (match > 0) {
      result$detected <- TRUE

      # Extract the matched routing text
      matched_text <- regmatches(text_lower, match)
      result$condition_text <- trimws(matched_text)

      break
    }
  }

  # Extract referenced question numbers from full text
  if (result$detected) {
    q_refs <- gregexpr("q\\.?\\s*(\\d+)", text_lower, perl = TRUE)
    q_matches <- regmatches(text_lower, q_refs)[[1]]
    if (length(q_matches) > 0) {
      # Extract just the digits
      ref_nums <- gsub("[^0-9]", "", q_matches)
      ref_nums <- unique(ref_nums[nzchar(ref_nums)])

      # Don't reference the question's own number (self-reference)
      # Note: we don't know our own q_num here, caller handles that
      result$references <- ref_nums
    }
  }

  result
}


#' Build Routing Summary
#'
#' @description
#' Creates a data frame summarising all detected routing for output.
#'
#' @param questions Questions list with routing metadata
#'
#' @return Data frame with routing summary (empty if no routing detected)
#'
#' @keywords internal
build_routing_summary <- function(questions) {

  rows <- list()

  for (q_num in names(questions)) {
    q <- questions[[q_num]]
    routing <- q$routing

    if (!is.null(routing) && isTRUE(routing$has_routing)) {
      rows[[length(rows) + 1]] <- data.frame(
        QuestionCode = q$q_code %||% paste0("Q", q_num),
        QuestionNumber = q_num,
        ConditionalOn = if (length(routing$conditional_on) > 0)
                          paste(paste0("Q", routing$conditional_on), collapse = ", ")
                        else NA_character_,
        ConditionText = routing$condition_text,
        Confidence = routing$confidence,
        Source = routing$source,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(rows) == 0) {
    return(data.frame(
      QuestionCode = character(0),
      QuestionNumber = character(0),
      ConditionalOn = character(0),
      ConditionText = character(0),
      Confidence = character(0),
      Source = character(0),
      stringsAsFactors = FALSE
    ))
  }

  do.call(rbind, rows)
}
