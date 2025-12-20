# ==============================================================================
# ALCHEMERPARSER - TRS GUARD LAYER
# ==============================================================================
#
# TRS v1.0 integration for the AlchemerParser module.
# Implements refusal, guard state, and validation gates per TRS standard.
#
# This module provides:
#   - alchemerparser_refuse() - module-specific refusal wrapper
#   - alchemerparser_with_refusal_handler() - wraps main analysis with TRS handling
#   - alchemerparser_guard_init() - initialize guard state with parser-specific fields
#   - Validation helpers for parser-specific requirements
#
# Related:
#   - modules/shared/lib/trs_refusal.R - shared TRS infrastructure
#
# Version: 1.0 (TRS Integration)
# Date: December 2024
#
# ==============================================================================


# ==============================================================================
# SOURCE SHARED TRS INFRASTRUCTURE
# ==============================================================================

if (!exists("turas_refuse", mode = "function")) {
  script_dir_path <- tryCatch({
    ofile <- sys.frame(1)$ofile
    if (!is.null(ofile)) file.path(dirname(ofile), "../../shared/lib/trs_refusal.R") else NULL
  }, error = function(e) NULL)

  possible_paths <- c(
    script_dir_path,
    file.path(getwd(), "modules/shared/lib/trs_refusal.R"),
    file.path(Sys.getenv("TURAS_HOME"), "modules/shared/lib/trs_refusal.R"),
    file.path(Sys.getenv("TURAS_ROOT", getwd()), "modules/shared/lib/trs_refusal.R")
  )
  possible_paths <- possible_paths[!sapply(possible_paths, is.null)]

  trs_loaded <- FALSE
  for (path in possible_paths) {
    if (file.exists(path)) { source(path); trs_loaded <- TRUE; break }
  }

  if (!trs_loaded) {
    warning("TRS infrastructure not found. Using fallback.")
    turas_refuse <- function(code, title, problem, why_it_matters, how_to_fix, ...) {
      stop(paste0("[", code, "] ", title, ": ", problem))
    }
    with_refusal_handler <- function(expr, module = "UNKNOWN") tryCatch(expr, error = function(e) stop(e))
    guard_init <- function(module = "UNKNOWN") list(module = module, warnings = list(), stable = TRUE)
    guard_warn <- function(guard, msg, category = "general") { guard$warnings <- c(guard$warnings, list(list(msg = msg, category = category))); guard }
    guard_flag_stability <- function(guard, reason) { guard$stable <- FALSE; guard }
    guard_summary <- function(guard) list(module = guard$module, warning_count = length(guard$warnings), is_stable = guard$stable, has_issues = length(guard$warnings) > 0)
    trs_status_pass <- function(module) list(status = "PASS", module = module)
    trs_status_partial <- function(module, degraded_reasons, affected_outputs) list(status = "PARTIAL", module = module, degraded_reasons = degraded_reasons)
  }
}


# ==============================================================================
# ALCHEMERPARSER-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message (AlchemerParser)
#'
#' @param code Refusal code (will be prefixed if needed)
#' @param title Short title for the refusal
#' @param problem One-sentence description of what went wrong
#' @param why_it_matters Explanation of analytical risk (MANDATORY)
#' @param how_to_fix Explicit step-by-step instructions to resolve
#' @param expected Expected entities (for diagnostics)
#' @param observed Observed entities (for diagnostics)
#' @param missing Missing entities (for diagnostics)
#' @param details Additional diagnostic details
#'
#' @keywords internal
alchemerparser_refuse <- function(code,
                                  title,
                                  problem,
                                  why_it_matters,
                                  how_to_fix,
                                  expected = NULL,
                                  observed = NULL,
                                  missing = NULL,
                                  details = NULL) {

  if (!grepl("^(CFG_|DATA_|IO_|MODEL_|MAPPER_|PKG_|FEATURE_|BUG_)", code)) {
    code <- paste0("CFG_", code)
  }

  turas_refuse(
    code = code,
    title = title,
    problem = problem,
    why_it_matters = why_it_matters,
    how_to_fix = how_to_fix,
    expected = expected,
    observed = observed,
    missing = missing,
    details = details,
    module = "ALCHEMERPARSER"
  )
}


#' Run AlchemerParser with Refusal Handler
#'
#' @param expr Expression to evaluate
#' @return Result or refusal/error object
#' @export
alchemerparser_with_refusal_handler <- function(expr) {
  result <- with_refusal_handler(expr, module = "ALCHEMERPARSER")

  if (inherits(result, "turas_refusal_result")) {
    class(result) <- c("alchemerparser_refusal_result", class(result))
  }

  result
}


# ==============================================================================
# ALCHEMERPARSER GUARD STATE
# ==============================================================================

#' Initialize AlchemerParser Guard State
#'
#' @return Guard state list
#' @export
alchemerparser_guard_init <- function() {
  guard <- guard_init(module = "ALCHEMERPARSER")

  # Add AlchemerParser-specific fields
  guard$parse_errors <- list()
  guard$unmapped_questions <- character(0)
  guard$invalid_formats <- character(0)
  guard$questions_parsed <- 0
  guard$options_parsed <- 0

  guard
}


#' Record Parse Error
#'
#' @param guard Guard state object
#' @param question_id Question identifier
#' @param error Error message
#' @return Updated guard state
#' @keywords internal
guard_record_parse_error <- function(guard, question_id, error) {
  guard$parse_errors[[question_id]] <- error
  guard <- guard_warn(guard, paste0("Parse error for ", question_id, ": ", error), "parse_error")
  guard
}


#' Record Unmapped Question
#'
#' @param guard Guard state object
#' @param question_id Question identifier
#' @return Updated guard state
#' @keywords internal
guard_record_unmapped_question <- function(guard, question_id) {
  guard$unmapped_questions <- c(guard$unmapped_questions, question_id)
  guard <- guard_flag_stability(guard, paste0("Unmapped question: ", question_id))
  guard
}


#' Record Invalid Format
#'
#' @param guard Guard state object
#' @param question_id Question identifier
#' @param expected_format Expected format
#' @param actual_format Actual format found
#' @return Updated guard state
#' @keywords internal
guard_record_invalid_format <- function(guard, question_id, expected_format, actual_format) {
  guard$invalid_formats <- c(guard$invalid_formats, question_id)
  guard <- guard_warn(guard, paste0("Invalid format for ", question_id, ": expected ", expected_format, ", got ", actual_format), "format")
  guard
}


#' Get AlchemerParser Guard Summary
#'
#' @param guard Guard state object
#' @return List with summary info
#' @export
alchemerparser_guard_summary <- function(guard) {
  summary <- guard_summary(guard)

  summary$parse_errors <- guard$parse_errors
  summary$unmapped_questions <- guard$unmapped_questions
  summary$invalid_formats <- guard$invalid_formats
  summary$questions_parsed <- guard$questions_parsed
  summary$options_parsed <- guard$options_parsed

  summary$has_issues <- summary$has_issues ||
                        length(guard$parse_errors) > 0 ||
                        length(guard$unmapped_questions) > 0 ||
                        length(guard$invalid_formats) > 0

  summary
}


# ==============================================================================
# ALCHEMERPARSER VALIDATION GATES
# ==============================================================================

#' Validate AlchemerParser Configuration
#'
#' @param config Configuration list
#' @keywords internal
validate_alchemerparser_config <- function(config) {

  if (!is.list(config)) {
    alchemerparser_refuse(
      code = "CFG_INVALID_TYPE",
      title = "Invalid Configuration Format",
      problem = "Configuration must be a list.",
      why_it_matters = "Parser cannot proceed without properly structured configuration.",
      how_to_fix = "Ensure config file was loaded correctly."
    )
  }

  invisible(TRUE)
}


#' Validate Word Document Exists
#'
#' @param doc_path Path to Word document
#' @keywords internal
validate_word_doc <- function(doc_path) {

  if (is.null(doc_path) || !nzchar(doc_path)) {
    alchemerparser_refuse(
      code = "IO_NO_WORD_DOC",
      title = "No Word Document Specified",
      problem = "No Word document path was specified.",
      why_it_matters = "AlchemerParser requires a Word document to parse survey questions.",
      how_to_fix = c(
        "Specify the Word document path in config",
        "Document should contain Alchemer survey structure"
      )
    )
  }

  if (!file.exists(doc_path)) {
    alchemerparser_refuse(
      code = "IO_WORD_DOC_NOT_FOUND",
      title = "Word Document Not Found",
      problem = paste0("Cannot find Word document: ", basename(doc_path)),
      why_it_matters = "Parser requires the Word document to extract survey structure.",
      how_to_fix = c(
        "Check that the file path is correct",
        "Verify the file exists at the specified location",
        "Check for typos in the filename"
      ),
      details = paste0("Expected path: ", doc_path)
    )
  }

  # Check file extension
  ext <- tolower(tools::file_ext(doc_path))
  if (!ext %in% c("docx", "doc")) {
    alchemerparser_refuse(
      code = "IO_INVALID_DOC_FORMAT",
      title = "Invalid Document Format",
      problem = paste0("Document has extension '.", ext, "', expected .docx or .doc"),
      why_it_matters = "Parser can only process Word documents.",
      how_to_fix = c(
        "Provide a Word document (.docx or .doc)",
        "If it's a different format, convert it to Word first"
      )
    )
  }

  invisible(TRUE)
}


#' Validate Data Map Exists
#'
#' @param map_path Path to data map file
#' @keywords internal
validate_data_map <- function(map_path) {

  if (is.null(map_path) || !nzchar(map_path)) {
    alchemerparser_refuse(
      code = "IO_NO_DATA_MAP",
      title = "No Data Map Specified",
      problem = "No data map file path was specified.",
      why_it_matters = "Data map is required to translate Alchemer column names.",
      how_to_fix = c(
        "Specify the data map file path in config",
        "Download data map from Alchemer survey settings"
      )
    )
  }

  if (!file.exists(map_path)) {
    alchemerparser_refuse(
      code = "CFG_MISSING_DATA_MAP",
      title = "Data Map File Not Found",
      problem = paste0("Cannot find data map file: ", basename(map_path)),
      why_it_matters = "Data map is required to map Alchemer columns to question codes.",
      how_to_fix = c(
        "Download data map from Alchemer",
        "Check that the file path is correct",
        "Verify the file exists at the specified location"
      ),
      details = paste0("Expected path: ", map_path)
    )
  }

  invisible(TRUE)
}


#' Validate Parsed Content
#'
#' @param parsed_content Parsed content from Word document
#' @keywords internal
validate_parsed_content <- function(parsed_content) {

  if (is.null(parsed_content)) {
    alchemerparser_refuse(
      code = "DATA_PARSE_FAILED",
      title = "Document Parsing Failed",
      problem = "Failed to parse content from Word document.",
      why_it_matters = "Cannot extract survey structure without successful parsing.",
      how_to_fix = c(
        "Check that the Word document is not corrupted",
        "Verify the document contains Alchemer survey content",
        "Try re-exporting from Alchemer"
      )
    )
  }

  if (length(parsed_content) == 0) {
    alchemerparser_refuse(
      code = "DATA_NO_CONTENT",
      title = "No Content Parsed",
      problem = "Word document appears to be empty or has no parseable content.",
      why_it_matters = "Cannot create survey structure from empty content.",
      how_to_fix = c(
        "Verify the Word document contains survey questions",
        "Check the document format matches expected Alchemer export"
      )
    )
  }

  invisible(TRUE)
}


#' Validate Question Classification
#'
#' @param questions Parsed questions
#' @param guard Guard state
#' @return Updated guard state
#' @keywords internal
validate_question_classification <- function(questions, guard) {

  if (is.null(questions) || nrow(questions) == 0) {
    alchemerparser_refuse(
      code = "DATA_NO_QUESTIONS",
      title = "No Questions Extracted",
      problem = "No questions were extracted from the document.",
      why_it_matters = "Survey structure requires at least one question.",
      how_to_fix = c(
        "Check document content",
        "Verify document format matches Alchemer export"
      )
    )
  }

  # Check for unclassified questions
  if ("Variable_Type" %in% names(questions)) {
    unclassified <- questions$QuestionCode[is.na(questions$Variable_Type) | questions$Variable_Type == ""]
    for (q in unclassified) {
      guard <- guard_record_unmapped_question(guard, q)
    }
  }

  guard$questions_parsed <- nrow(questions)
  guard
}


# ==============================================================================
# TRS STATUS HELPERS
# ==============================================================================

#' Create AlchemerParser PASS Status
#'
#' @param questions_parsed Number of questions parsed
#' @param options_parsed Number of options parsed
#' @return TRS status object
#' @export
alchemerparser_status_pass <- function(questions_parsed = NULL, options_parsed = NULL) {
  status <- trs_status_pass(module = "ALCHEMERPARSER")
  status$details <- list(
    questions_parsed = questions_parsed,
    options_parsed = options_parsed
  )
  status
}


#' Create AlchemerParser PARTIAL Status
#'
#' @param degraded_reasons Character vector of degradation reasons
#' @param affected_outputs Character vector of affected outputs
#' @param parse_errors Character vector of parse error question IDs
#' @return TRS status object
#' @export
alchemerparser_status_partial <- function(degraded_reasons,
                                          affected_outputs,
                                          parse_errors = NULL) {
  status <- trs_status_partial(
    module = "ALCHEMERPARSER",
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )
  if (!is.null(parse_errors) && length(parse_errors) > 0) {
    status$details <- list(parse_errors = parse_errors)
  }
  status
}
