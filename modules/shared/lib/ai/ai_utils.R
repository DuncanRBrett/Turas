# ==============================================================================
# AI UTILS — JSON Sidecar Persistence, Content-Hash Caching, Token Estimation
# ==============================================================================
#
# Shared utilities for AI insights across all modules:
#   - JSON sidecar read/write (atomic writes to prevent corruption)
#   - Content-hash caching (skip API calls when data unchanged)
#   - Token estimation (context window management)
#   - Sidecar path derivation from config file path
#   - Default sidecar template generation
#
# Dependencies:
#   jsonlite (already in Turas) — JSON serialisation
#   digest (already in renv)    — MD5 content hashing
#
# Usage:
#   source("modules/shared/lib/ai/ai_utils.R")
#   sidecar <- read_ai_sidecar("/path/to/config.xlsx")
#   write_ai_sidecar(sidecar, "/path/to/config.xlsx")
#
# ==============================================================================


# --- Sidecar Version ---------------------------------------------------------
AI_SIDECAR_VERSION <- "1.0"


#' Derive the AI insights sidecar file path from a config file path
#'
#' Replaces the config file extension with `_ai_insights.json`.
#' The sidecar sits alongside the config Excel file.
#'
#' @param config_file_path Character. Path to the config Excel workbook.
#'
#' @return Character. Path to the corresponding AI insights JSON sidecar.
#'
#' @examples
#' build_sidecar_path("projects/Demo_CX_Crosstabs.xlsx")
#' # "projects/Demo_CX_Crosstabs_ai_insights.json"
build_sidecar_path <- function(config_file_path) {
  if (is.null(config_file_path) || !nzchar(config_file_path)) {
    return(NULL)
  }
  base <- tools::file_path_sans_ext(config_file_path)
  paste0(base, "_ai_insights.json")
}


#' Read the AI insights JSON sidecar file
#'
#' Loads and parses the JSON sidecar. Returns NULL if the file does not exist
#' or cannot be parsed — never throws.
#'
#' @param config_file_path Character. Path to the config Excel workbook
#'   (the sidecar path is derived from this).
#'
#' @return A list with the sidecar contents, or NULL if unavailable.
read_ai_sidecar <- function(config_file_path) {
  sidecar_path <- build_sidecar_path(config_file_path)
  if (is.null(sidecar_path) || !file.exists(sidecar_path)) {
    return(NULL)
  }

  tryCatch({
    raw <- readLines(sidecar_path, warn = FALSE)
    jsonlite::fromJSON(paste(raw, collapse = "\n"), simplifyVector = FALSE)
  }, error = function(e) {
    warning(sprintf("Failed to read AI sidecar '%s': %s", sidecar_path, e$message))
    NULL
  })
}


#' Write the AI insights JSON sidecar file (atomic)
#'
#' Writes the sidecar as pretty-printed JSON. Uses atomic write pattern:
#' writes to a temporary file first, then renames. This prevents corruption
#' if the process is interrupted mid-write.
#'
#' @param sidecar List. The sidecar data structure to write.
#' @param config_file_path Character. Path to the config Excel workbook
#'   (the sidecar path is derived from this).
#'
#' @return Logical TRUE on success, FALSE on failure (never throws).
write_ai_sidecar <- function(sidecar, config_file_path) {
  sidecar_path <- build_sidecar_path(config_file_path)
  if (is.null(sidecar_path)) {
    warning("Cannot write AI sidecar: config_file_path is NULL or empty")
    return(FALSE)
  }

  tryCatch({
    # Update timestamp
    sidecar$generated_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
    sidecar$version <- AI_SIDECAR_VERSION

    json_text <- jsonlite::toJSON(sidecar, auto_unbox = TRUE, pretty = TRUE,
                                  digits = 6, null = "null")

    # Atomic write: write to temp file, then rename
    tmp_path <- paste0(sidecar_path, ".tmp")
    writeLines(as.character(json_text), tmp_path)
    file.rename(tmp_path, sidecar_path)

    TRUE
  }, error = function(e) {
    warning(sprintf("Failed to write AI sidecar '%s': %s", sidecar_path, e$message))
    # Clean up temp file if it exists
    tmp_path <- paste0(sidecar_path, ".tmp")
    if (file.exists(tmp_path)) unlink(tmp_path)
    FALSE
  })
}


#' Compute a content hash for a question's data payload
#'
#' Uses MD5 via digest::digest() on the JSON-serialised data. The hash
#' determines whether the underlying data has changed since the last
#' AI callout was generated.
#'
#' @param question_data List. The extracted question data payload
#'   (output of extract_question_data()).
#'
#' @return Character. MD5 hash string.
#'
#' @examples
#' data <- list(q_code = "Q1", results = list(Total = c(50, 30, 20)))
#' compute_data_hash(data)
compute_data_hash <- function(question_data) {
  json_repr <- jsonlite::toJSON(question_data, auto_unbox = TRUE, digits = 6)
  digest::digest(as.character(json_repr), algo = "md5")
}


#' Check if a cached callout is still valid
#'
#' Compares the stored data hash against the current data hash.
#' A callout is valid if: it exists, has a data_hash field, and the
#' hash matches the current data.
#'
#' @param existing_callout List or NULL. The stored callout from the sidecar.
#' @param current_hash Character. The MD5 hash of the current question data.
#'
#' @return Logical. TRUE if the cached callout is still valid.
is_callout_cache_valid <- function(existing_callout, current_hash) {
  if (is.null(existing_callout)) return(FALSE)
  if (is.null(existing_callout$data_hash)) return(FALSE)
  identical(existing_callout$data_hash, current_hash)
}


#' Estimate token count from a data payload
#'
#' Rough estimation: characters in JSON representation divided by 4.
#' Used for context window management when building executive summary prompts.
#'
#' @param payload R object to estimate tokens for.
#'
#' @return Numeric. Estimated token count.
estimate_tokens <- function(payload) {
  json_text <- jsonlite::toJSON(payload, auto_unbox = TRUE, digits = 4)
  nchar(as.character(json_text)) / 4
}


#' Create a default AI sidecar template
#'
#' Generates a new sidecar structure with default configuration.
#' Used when no sidecar exists and the user wants to enable AI insights.
#'
#' @param provider Character. Default provider (default: "anthropic").
#' @param model Character. Default model identifier.
#'
#' @return List. A sidecar template ready for customisation and writing.
create_default_sidecar <- function(provider = "anthropic",
                                   model = "claude-sonnet-4-20250514") {
  list(
    version      = AI_SIDECAR_VERSION,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    config = list(
      enabled                   = TRUE,
      provider                  = provider,
      model                     = model,
      temperature               = 0.3,
      max_tokens                = 1500L,
      exec_summary_max_tokens   = 2500L,
      verify_callouts           = TRUE,
      rank_callouts             = TRUE,
      generate_exec_summary     = TRUE,
      generate_per_question     = TRUE,
      exec_summary_reviewed     = TRUE,
      easystats_narration       = FALSE,
      max_verification_attempts = 2L,
      api_key_env               = "ANTHROPIC_API_KEY"
    ),
    questions          = list(),
    executive_summary  = NULL
  )
}
