# ==============================================================================
# AI INSIGHTS — Tabs Module Orchestrator
# ==============================================================================
#
# Main entry point for AI insight generation in the tabs module.
# Coordinates: sidecar loading → extraction → generation → verification →
#   selectivity → executive summary → sidecar save.
#
# Functions:
#   generate_all_insights() — orchestrate full AI insights pipeline
#   generate_executive_summary() — two-stage executive summary
#
# Dependencies:
#   modules/shared/lib/ai/ai_provider.R  — create_ai_chat, call_insight_model
#   modules/shared/lib/ai/ai_schemas.R   — verification_schema, selectivity_schema
#   modules/shared/lib/ai/ai_utils.R     — sidecar read/write, hashing
#   modules/shared/lib/ai/ai_verify.R    — verify_callout, rank_callouts
#   modules/tabs/lib/ai/ai_extraction.R  — extract_question_data, extract_study_context
#   modules/tabs/lib/ai/ai_prompts.R     — build_insight_prompt
#   modules/tabs/lib/ai/ai_schemas_tabs.R — ai_callout_schema, exec_*_schema
#
# Usage:
#   source("modules/tabs/lib/ai/ai_insights.R")
#   ai_result <- generate_all_insights(all_results, banner_info, config_obj, sidecar_path)
#
# ==============================================================================


#' Generate all AI insights for a tabs report
#'
#' Main orchestration function. Called once during HTML report generation.
#' Loads the existing sidecar (if any), generates per-question callouts,
#' runs verification and selectivity passes, generates the executive summary,
#' and saves everything back to the JSON sidecar.
#'
#' Returns NULL if AI insights are disabled or if all generation fails.
#' Never throws — all errors are caught and logged.
#'
#' @param all_results Named list. Full analysis results from run_crosstabs_analysis().
#' @param banner_info List. Banner structure from create_banner_structure().
#' @param config_obj List. Configuration object with ai_insights sub-list.
#' @param sidecar_path Character. Path to the AI insights JSON sidecar.
#'
#' @return List with:
#'   \item{callouts}{Named list of per-question callout lists (keyed by q_code)}
#'   \item{executive_summary}{Executive summary list, or NULL}
#'   \item{ai_config}{AI configuration from the sidecar}
#'   \item{model_display_name}{Human-readable model attribution string}
#'   Or NULL if AI insights are disabled or all calls fail.
generate_all_insights <- function(all_results, banner_info, config_obj,
                                  sidecar_path) {

  # Load sidecar (settings + cached callouts)
  sidecar <- read_ai_sidecar_from_path(sidecar_path)
  if (is.null(sidecar)) {
    cat("    [INFO] No AI sidecar found. AI insights skipped.\n")
    return(NULL)
  }

  ai_config <- sidecar$config
  if (!isTRUE(ai_config$enabled)) {
    cat("    [INFO] AI insights disabled in sidecar config.\n")
    return(NULL)
  }

  model_name <- get_model_display_name(ai_config)
  cat(sprintf("    Provider: %s\n", model_name))

  study_context <- extract_study_context(all_results, banner_info, config_obj)
  callouts <- sidecar$questions %||% list()
  generated_count <- 0L
  cached_count    <- 0L
  failed_count    <- 0L

  # === Per-question callouts ===
  if (isTRUE(ai_config$generate_per_question)) {
    q_codes <- names(all_results)
    cat(sprintf("    Processing %d questions...\n", length(q_codes)))

    for (q_code in q_codes) {
      q_result <- all_results[[q_code]]

      # Skip excluded questions
      existing_entry <- callouts[[q_code]]
      if (isTRUE(existing_entry$ai_callout_exclude)) next

      # Extract data for this question
      q_data <- extract_question_data(q_result, banner_info)
      if (is.null(q_data)) next

      # Check cache: skip if data unchanged
      current_hash <- compute_data_hash(q_data)
      existing_callout <- if (!is.null(existing_entry)) {
        existing_entry$ai_callout
      } else {
        NULL
      }

      if (is_callout_cache_valid(existing_callout, current_hash)) {
        cached_count <- cached_count + 1L
        next
      }

      # Generate new callout
      prompt <- tryCatch(
        build_insight_prompt(q_data, study_context, "ai_callout"),
        error = function(e) {
          cat(sprintf("    [WARNING] Prompt build failed for %s: %s\n",
                      q_code, e$message))
          NULL
        }
      )
      if (is.null(prompt)) {
        failed_count <- failed_count + 1L
        next
      }

      callout <- call_insight_model(prompt, ai_callout_schema, ai_config)
      if (is.null(callout)) {
        failed_count <- failed_count + 1L
        cat(sprintf("    [WARNING] Generation failed for %s\n", q_code))
        Sys.sleep(AI_RATE_LIMIT_SECONDS)
        next
      }

      # Verify (with regeneration on failure)
      if (isTRUE(callout$has_insight)) {
        callout <- verify_callout(callout, q_data, ai_config, build_insight_prompt)

        if (!isTRUE(callout$verified)) {
          max_attempts <- ai_config$max_verification_attempts %||% 2L
          for (attempt in seq_len(max_attempts)) {
            regen_prompt <- prompt
            regen_prompt$user <- paste0(
              prompt$user,
              "\n\nPREVIOUS ATTEMPT HAD ERRORS:\n",
              callout$verification_issues %||% "Unknown verification failure",
              "\n\nPlease correct these specific issues."
            )
            callout <- call_insight_model(regen_prompt, ai_callout_schema, ai_config)
            if (is.null(callout)) break
            callout <- verify_callout(callout, q_data, ai_config, build_insight_prompt)
            if (isTRUE(callout$verified)) break
            Sys.sleep(AI_RATE_LIMIT_SECONDS)
          }
          if (is.null(callout) || !isTRUE(callout$verified)) {
            if (!is.null(callout)) callout$has_insight <- FALSE
            cat(sprintf("    [WARNING] %s suppressed -- failed verification\n", q_code))
          }
        }
      }

      if (!is.null(callout)) {
        callout$pinned    <- callout$pinned %||% FALSE
        callout$data_hash <- current_hash

        if (is.null(callouts[[q_code]])) callouts[[q_code]] <- list()
        callouts[[q_code]]$ai_callout <- callout
        generated_count <- generated_count + 1L
      }

      Sys.sleep(AI_RATE_LIMIT_SECONDS)
    }

    cat(sprintf("    Callouts: %d generated, %d cached, %d failed\n",
                generated_count, cached_count, failed_count))

    # Selectivity pass
    callout_map <- list()
    question_titles <- c()
    for (q_code in names(callouts)) {
      co <- callouts[[q_code]]$ai_callout
      if (!is.null(co)) {
        callout_map[[q_code]] <- co
        q_result <- all_results[[q_code]]
        if (!is.null(q_result)) {
          question_titles[q_code] <- q_result$question_text %||% q_code
        }
      }
    }

    if (length(callout_map) >= 3L) {
      cat("    Running selectivity pass...\n")
      callout_map <- rank_callouts(callout_map, ai_config, build_insight_prompt,
                                   question_titles = question_titles)
      # Write back
      for (q_code in names(callout_map)) {
        callouts[[q_code]]$ai_callout <- callout_map[[q_code]]
      }
    }
  }

  # === Executive summary ===
  exec_summary <- sidecar$executive_summary
  if (isTRUE(ai_config$generate_exec_summary)) {
    # Build question data for hash check and potential generation
    all_q_data <- lapply(all_results, function(q) {
      extract_question_data(q, banner_info)
    })
    all_q_data <- Filter(Negate(is.null), all_q_data)

    # Cache invalidation: regenerate if data has changed since last summary
    exec_data_hash <- compute_data_hash(all_q_data)
    cached_valid <- !is.null(exec_summary) &&
                    nzchar(exec_summary$narrative %||% "") &&
                    identical(exec_summary$data_hash %||% "", exec_data_hash)

    if (!cached_valid) {
      cat("    Generating executive summary...\n")
      exec_summary <- generate_executive_summary(all_q_data, study_context, ai_config)
      if (!is.null(exec_summary)) {
        exec_summary$data_hash <- exec_data_hash

        # Deterministic verification: check cited numbers against source data
        det_check <- deterministic_number_check(exec_summary$narrative, all_q_data)
        if (!isTRUE(det_check$pass)) {
          cat(sprintf("    [WARNING] Exec summary failed numeric check: %s\n",
                      det_check$issues))
          exec_summary$verified <- FALSE
          exec_summary$verification_issues <- det_check$issues
        } else {
          exec_summary$verified <- TRUE
        }
        cat("    Executive summary generated.\n")
      } else {
        cat("    [WARNING] Executive summary generation failed.\n")
      }
    } else {
      cat("    Executive summary: using cached version.\n")
    }
  }

  # === Save sidecar ===
  sidecar$questions <- callouts
  sidecar$executive_summary <- exec_summary
  write_success <- write_ai_sidecar_to_path(sidecar, sidecar_path)
  if (write_success) {
    cat(sprintf("    Sidecar saved: %s\n", basename(sidecar_path)))
  }

  # Return the insights for rendering
  list(
    callouts           = callouts,
    executive_summary  = exec_summary,
    ai_config          = ai_config,
    model_display_name = model_name
  )
}


#' Generate a two-stage executive summary
#'
#' Stage 1: Identify structured patterns across all questions.
#' Stage 2: Write a narrative from those patterns.
#'
#' @param all_q_data Named list. Extracted data for all questions.
#' @param study_context List. Study-level context.
#' @param ai_config List. AI configuration.
#'
#' @return List with narrative, confidence, data_limitations, or NULL on failure.
generate_executive_summary <- function(all_q_data, study_context, ai_config) {

  # Check context window — use compact if payload is large
  estimated_tokens <- estimate_tokens(all_q_data)
  if (estimated_tokens > 80000) {
    cat("    [INFO] Large payload detected — using compact extraction for exec summary\n")
    # Re-extract compact versions — but we don't have q_result here,
    # so we truncate the existing data
    all_q_data <- lapply(all_q_data, function(q) {
      list(
        q_code          = q$q_code,
        q_title         = q$q_title,
        q_type          = q$q_type,
        results         = if ("Total" %in% names(q$results)) {
          list(Total = q$results[["Total"]])
        } else if (length(q$results) > 0) {
          list(Total = q$results[[1]])
        } else {
          list()
        },
        significance    = Filter(function(f) isTRUE(f$significant), q$significance),
        priority_metric = q$priority_metric
      )
    })
  }

  # Stage 1: Identify patterns
  prompt_patterns <- tryCatch(
    build_insight_prompt(all_q_data, study_context, "exec_patterns"),
    error = function(e) {
      warning(sprintf("Exec summary Stage 1 prompt failed: %s", e$message))
      NULL
    }
  )
  if (is.null(prompt_patterns)) return(NULL)

  patterns <- call_insight_model(prompt_patterns, exec_patterns_schema, ai_config)
  if (is.null(patterns)) return(NULL)

  Sys.sleep(AI_RATE_LIMIT_SECONDS)

  # Stage 2: Write narrative
  narrative_data <- list(patterns = patterns, all_q_data = all_q_data)
  prompt_narrative <- tryCatch(
    build_insight_prompt(narrative_data, study_context, "exec_narrative"),
    error = function(e) {
      warning(sprintf("Exec summary Stage 2 prompt failed: %s", e$message))
      NULL
    }
  )
  if (is.null(prompt_narrative)) return(NULL)

  # Use exec-specific max_tokens
  exec_config <- ai_config
  exec_config$max_tokens <- ai_config$exec_summary_max_tokens %||% 2500L

  result <- call_insight_model(prompt_narrative, exec_narrative_schema, exec_config)
  result
}


# ==============================================================================
# SIDECAR HELPERS (path-based variants)
# ==============================================================================

#' Read AI sidecar directly from a file path
#' @keywords internal
read_ai_sidecar_from_path <- function(sidecar_path) {
  if (is.null(sidecar_path) || !file.exists(sidecar_path)) return(NULL)

  tryCatch({
    raw <- readLines(sidecar_path, warn = FALSE)
    jsonlite::fromJSON(paste(raw, collapse = "\n"), simplifyVector = FALSE)
  }, error = function(e) {
    warning(sprintf("Failed to read AI sidecar '%s': %s", sidecar_path, e$message))
    NULL
  })
}


#' Write AI sidecar directly to a file path (atomic)
#' @keywords internal
write_ai_sidecar_to_path <- function(sidecar, sidecar_path) {
  if (is.null(sidecar_path)) return(FALSE)

  tryCatch({
    sidecar$generated_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
    sidecar$version <- AI_SIDECAR_VERSION %||% "1.0"

    json_text <- jsonlite::toJSON(sidecar, auto_unbox = TRUE, pretty = TRUE,
                                  digits = 6, null = "null")
    tmp_path <- paste0(sidecar_path, ".tmp")
    writeLines(as.character(json_text), tmp_path)
    file.rename(tmp_path, sidecar_path)
    TRUE
  }, error = function(e) {
    warning(sprintf("Failed to write AI sidecar: %s", e$message))
    tmp_path <- paste0(sidecar_path, ".tmp")
    if (file.exists(tmp_path)) unlink(tmp_path)
    FALSE
  })
}
