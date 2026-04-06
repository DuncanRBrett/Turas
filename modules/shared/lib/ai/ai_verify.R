# ==============================================================================
# AI VERIFY — Verification and Selectivity Passes
# ==============================================================================
#
# Two quality-assurance passes for AI-generated callouts:
#
#   1. verify_callout()  — Checks a single callout against source data for
#      factual accuracy (numbers match, significance claims match).
#
#   2. rank_callouts()   — Reviews the full set of callouts and removes any
#      that merely restate what the chart shows without adding interpretation.
#
# These passes add seconds, not minutes, and substantially raise the quality
# floor. Both fail-open: if they error, content passes through rather than
# being blocked.
#
# Dependencies:
#   ai_provider.R  — call_insight_model()
#   ai_schemas.R   — verification_schema, selectivity_schema
#
# Usage:
#   source("modules/shared/lib/ai/ai_verify.R")
#   callout <- verify_callout(callout, question_data, ai_config, build_prompt_fn)
#   filtered <- rank_callouts(callouts_list, ai_config, build_prompt_fn)
#
# ==============================================================================


#' Verify an AI callout against its source data
#'
#' Sends the callout narrative and source data to a verification LLM call.
#' Checks that every cited number matches the data and every significance
#' claim matches the significance flags. Returns the callout with a
#' `verified` field set to TRUE or FALSE.
#'
#' If verification is disabled in config, or the callout has no insight,
#' the callout is returned unchanged. If the LLM call fails, the callout
#' is returned with verified = FALSE (fail-open).
#'
#' @param callout List. The AI callout (has_insight, narrative, confidence, etc.).
#' @param question_data List. The extracted question data payload.
#' @param ai_config List. AI configuration (provider, model, verify_callouts, etc.).
#' @param build_prompt_fn Function. Builds a verification prompt.
#'   Signature: function(data, study_context, prompt_type) -> list(system, user).
#'
#' @return The callout list with `verified` and optionally `verification_issues` fields.
verify_callout <- function(callout, question_data, ai_config, build_prompt_fn) {

  # Skip if verification is disabled
  if (!isTRUE(ai_config$verify_callouts)) {
    callout$verified <- TRUE
    return(callout)
  }

  # Skip if no insight to verify
  if (!isTRUE(callout$has_insight)) {
    callout$verified <- TRUE
    return(callout)
  }

  # Build verification prompt
  verify_data <- list(
    narrative      = callout$narrative,
    question_data  = question_data
  )

  prompt <- tryCatch(
    build_prompt_fn(data = verify_data, study_context = NULL, prompt_type = "verification"),
    error = function(e) {
      warning(sprintf("Failed to build verification prompt: %s", e$message))
      NULL
    }
  )

  if (is.null(prompt)) {
    callout$verified <- FALSE
    return(callout)
  }

  # Deterministic pre-check: extract numbers from narrative and confirm each

  # appears in the source data. Catches fabricated statistics before the LLM
  # verification pass, which is not guaranteed to detect them.
  deterministic_result <- deterministic_number_check(callout$narrative, question_data)
  if (!isTRUE(deterministic_result$pass)) {
    callout$verified <- FALSE
    callout$verification_issues <- deterministic_result$issues
    return(callout)
  }

  # Call the verification model
  result <- call_insight_model(prompt, verification_schema, ai_config)

  if (is.null(result)) {
    callout$verified <- FALSE
    return(callout)
  }

  # Check results
  if (isTRUE(result$numbers_accurate) && isTRUE(result$significance_accurate)) {
    callout$verified <- TRUE
  } else {
    callout$verified <- FALSE
    callout$verification_issues <- result$mismatches
  }

  callout
}


#' Deterministic check that numbers cited in a narrative appear in source data
#'
#' Extracts all numeric values from the narrative text and checks each against
#' a flattened set of numbers from the source data. Numbers that do not appear
#' in the source data are flagged. This catches fabricated statistics that an
#' LLM verifier might miss.
#'
#' @param narrative Character. The AI-generated narrative text.
#' @param question_data List. The extracted question data payload.
#' @return List with `pass` (logical) and `issues` (character or NULL).
#' @keywords internal
deterministic_number_check <- function(narrative, question_data) {
  if (is.null(narrative) || !nzchar(narrative)) return(list(pass = TRUE, issues = NULL))

  # Extract all numbers from the narrative (integers and decimals)
  numbers_in_text <- regmatches(narrative, gregexpr("-?\\d+\\.?\\d*", narrative))[[1]]
  if (length(numbers_in_text) == 0) return(list(pass = TRUE, issues = NULL))

  numbers_in_text <- unique(as.numeric(numbers_in_text))
  numbers_in_text <- numbers_in_text[!is.na(numbers_in_text)]
  if (length(numbers_in_text) == 0) return(list(pass = TRUE, issues = NULL))

  # Flatten all numeric values from the source data
  source_numbers <- extract_all_numbers(question_data)

  # Check each narrative number against source (with tolerance for rounding)
  unmatched <- c()
  for (n in numbers_in_text) {
    # Skip very common numbers that aren't statistical claims (0, 1, 2, etc.)
    if (n %in% 0:10) next
    # Skip percentages of 100 (common phrasing, not a data point)
    if (n == 100) next

    # Check if the number matches any source value within rounding tolerance
    matched <- any(abs(source_numbers - n) < 0.6)
    if (!matched) {
      unmatched <- c(unmatched, n)
    }
  }

  if (length(unmatched) > 0) {
    return(list(
      pass = FALSE,
      issues = sprintf(
        "Deterministic check: narrative cites numbers not in source data: %s",
        paste(unmatched, collapse = ", ")
      )
    ))
  }

  list(pass = TRUE, issues = NULL)
}


#' Recursively extract all numeric values from a nested list
#' @keywords internal
extract_all_numbers <- function(x) {
  if (is.numeric(x)) return(x)
  if (is.character(x)) {
    vals <- suppressWarnings(as.numeric(x))
    return(vals[!is.na(vals)])
  }
  if (is.list(x)) return(unlist(lapply(x, extract_all_numbers)))
  numeric(0)
}


#' Review callouts for selectivity and remove low-value entries
#'
#' Sends all callouts with has_insight = TRUE to a selectivity LLM call.
#' The model identifies any callouts that merely restate what the chart shows
#' without adding interpretive value. Those are suppressed by setting
#' has_insight = FALSE.
#'
#' If the selectivity pass fails (LLM error, parse failure), all callouts
#' are retained (fail-open).
#'
#' @param callouts Named list. Keyed by q_code, each element is a callout list.
#' @param ai_config List. AI configuration.
#' @param build_prompt_fn Function. Builds a selectivity prompt.
#'   Signature: function(data, study_context, prompt_type) -> list(system, user).
#' @param question_titles Named character vector. Maps q_code to question title
#'   (used in the selectivity prompt for context).
#'
#' @return The callouts list with low-value entries suppressed (has_insight = FALSE).
rank_callouts <- function(callouts, ai_config, build_prompt_fn,
                          question_titles = NULL) {

  # Skip if selectivity is disabled
  if (!isTRUE(ai_config$rank_callouts)) return(callouts)

  # Collect only callouts with insights
  active_callouts <- list()
  for (q_code in names(callouts)) {
    co <- callouts[[q_code]]
    if (!is.null(co) && isTRUE(co$has_insight)) {
      title <- if (!is.null(question_titles)) {
        question_titles[[q_code]] %||% q_code
      } else {
        q_code
      }
      active_callouts[[q_code]] <- list(
        q_code    = q_code,
        q_title   = title,
        narrative = co$narrative
      )
    }
  }

  # Need at least 3 callouts to make selectivity meaningful
  if (length(active_callouts) < 3L) return(callouts)

  # Build selectivity prompt
  prompt <- tryCatch(
    build_prompt_fn(data = active_callouts, study_context = NULL,
                    prompt_type = "selectivity"),
    error = function(e) {
      warning(sprintf("Failed to build selectivity prompt: %s", e$message))
      NULL
    }
  )

  if (is.null(prompt)) return(callouts)

  # Call the selectivity model
  result <- call_insight_model(prompt, selectivity_schema, ai_config)

  if (is.null(result)) return(callouts)

  # Suppress flagged callouts
  remove_codes <- result$remove_q_codes
  if (is.null(remove_codes) || length(remove_codes) == 0L) return(callouts)

  for (q_code in remove_codes) {
    if (q_code %in% names(callouts)) {
      callouts[[q_code]]$has_insight <- FALSE
      callouts[[q_code]]$selectivity_removed <- TRUE
      message(sprintf("  Selectivity pass removed callout for %s", q_code))
    }
  }

  if (nzchar(result$reasoning %||% "")) {
    message(sprintf("  Selectivity reasoning: %s", result$reasoning))
  }

  callouts
}
