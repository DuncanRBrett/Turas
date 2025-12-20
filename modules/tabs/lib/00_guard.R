# ==============================================================================
# TABS - TRS GUARD LAYER
# ==============================================================================
#
# TRS v1.0 integration for the Tabs module.
# Implements refusal, guard state, and validation gates per TRS standard.
#
# This module provides:
#   - tabs_refuse() - module-specific refusal wrapper
#   - tabs_with_refusal_handler() - wraps main analysis with TRS handling
#   - tabs_guard_init() - initialize guard state with tabs-specific fields
#   - Validation helpers for tabs-specific requirements
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

# Source shared TRS infrastructure (if not already loaded)
if (!exists("turas_refuse", mode = "function")) {
  # Try multiple paths to find trs_refusal.R
  # Use tryCatch for sys.frame path since it fails in Jupyter/notebook contexts
  script_dir_path <- tryCatch({
    ofile <- sys.frame(1)$ofile
    if (!is.null(ofile)) {
      file.path(dirname(ofile), "../../shared/lib/trs_refusal.R")
    } else {
      NULL
    }
  }, error = function(e) NULL)

  possible_paths <- c(
    script_dir_path,
    file.path(getwd(), "modules/shared/lib/trs_refusal.R"),
    file.path(Sys.getenv("TURAS_HOME"), "modules/shared/lib/trs_refusal.R"),
    # Also try relative to script_dir if it exists (set by run_crosstabs.R)
    if (exists("script_dir")) file.path(script_dir, "../shared/lib/trs_refusal.R") else NULL
  )

  # Filter out NULL paths
  possible_paths <- possible_paths[!sapply(possible_paths, is.null)]

  trs_loaded <- FALSE
  for (path in possible_paths) {
    if (file.exists(path)) {
      source(path)
      trs_loaded <- TRUE
      break
    }
  }

  # If TRS not loaded, create stub functions to prevent errors
  if (!trs_loaded) {
    warning("TRS infrastructure not found. Using fallback error handling.")
    turas_refuse <- function(code, title, problem, why_it_matters, how_to_fix, ...) {
      stop(paste0("[", code, "] ", title, ": ", problem))
    }
    with_refusal_handler <- function(expr, module = "UNKNOWN") {
      tryCatch(expr, error = function(e) stop(e))
    }
    guard_init <- function(module = "UNKNOWN") {
      list(module = module, warnings = list(), stable = TRUE)
    }
    guard_warn <- function(guard, msg, category = "general") {
      guard$warnings <- c(guard$warnings, list(list(msg = msg, category = category)))
      guard
    }
    guard_flag_stability <- function(guard, reason) {
      guard$stable <- FALSE
      guard
    }
    guard_summary <- function(guard) {
      list(module = guard$module, warning_count = length(guard$warnings),
           is_stable = guard$stable, has_issues = length(guard$warnings) > 0)
    }
    trs_status_pass <- function(module) list(status = "PASS", module = module)
    trs_status_partial <- function(module, degraded_reasons, affected_outputs) {
      list(status = "PARTIAL", module = module, degraded_reasons = degraded_reasons)
    }
  }
}


# ==============================================================================
# TABS-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message (Tabs)
#'
#' Tabs-specific wrapper around turas_refuse() that provides
#' module-specific defaults and code prefix handling.
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
tabs_refuse <- function(code,
                        title,
                        problem,
                        why_it_matters,
                        how_to_fix,
                        expected = NULL,
                        observed = NULL,
                        missing = NULL,
                        details = NULL) {

  # Ensure code has valid TRS prefix
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
    module = "TABS"
  )
}


#' Run Tabs Analysis with Refusal Handler
#'
#' Wraps Tabs execution with TRS refusal handling.
#'
#' @param expr Expression to evaluate
#' @return Result or refusal/error object
#' @export
tabs_with_refusal_handler <- function(expr) {
  result <- with_refusal_handler(expr, module = "TABS")

  # Add Tabs-specific class for compatibility
  if (inherits(result, "turas_refusal_result")) {
    class(result) <- c("tabs_refusal_result", class(result))
  }

  result
}


# ==============================================================================
# TABS GUARD STATE
# ==============================================================================

#' Initialize Tabs Guard State
#'
#' Creates guard state with Tabs-specific tracking fields.
#'
#' @return Guard state list
#' @export
tabs_guard_init <- function() {
  guard <- guard_init(module = "TABS")

  # Add Tabs-specific fields
  guard$skipped_questions <- character(0)
  guard$empty_base_questions <- character(0)
  guard$banner_issues <- list()
  guard$option_mapping_issues <- list()

  guard
}


#' Record Skipped Question
#'
#' Records when a question was skipped from analysis.
#'
#' @param guard Guard state object
#' @param question_code Question code
#' @param reason Reason for skipping
#' @return Updated guard state
#' @keywords internal
guard_record_skipped_question <- function(guard, question_code, reason) {
  guard$skipped_questions <- c(guard$skipped_questions, question_code)
  guard <- guard_warn(guard, paste0("Skipped question: ", question_code, " (", reason, ")"), "skipped")
  guard
}


#' Record Empty Base Question
#'
#' Records when a question has zero respondents after filtering.
#'
#' @param guard Guard state object
#' @param question_code Question code
#' @param filter_expression Filter that caused empty base
#' @return Updated guard state
#' @keywords internal
guard_record_empty_base <- function(guard, question_code, filter_expression = NULL) {
  guard$empty_base_questions <- c(guard$empty_base_questions, question_code)
  msg <- paste0("Empty base for question: ", question_code)
  if (!is.null(filter_expression) && nzchar(filter_expression)) {
    msg <- paste0(msg, " (filter: ", filter_expression, ")")
  }
  guard <- guard_warn(guard, msg, "empty_base")
  guard
}


#' Get Tabs Guard Summary
#'
#' Creates comprehensive summary including Tabs-specific fields.
#'
#' @param guard Guard state object
#' @return List with summary info
#' @export
tabs_guard_summary <- function(guard) {
  summary <- guard_summary(guard)

  # Add Tabs-specific fields
  summary$skipped_questions <- guard$skipped_questions
  summary$empty_base_questions <- guard$empty_base_questions
  summary$banner_issues <- guard$banner_issues
  summary$option_mapping_issues <- guard$option_mapping_issues

  # Update has_issues
  summary$has_issues <- summary$has_issues ||
                        length(guard$skipped_questions) > 0 ||
                        length(guard$empty_base_questions) > 0 ||
                        length(guard$banner_issues) > 0

  summary
}


# ==============================================================================
# TABS VALIDATION GATES
# ==============================================================================

#' Validate Tabs Configuration
#'
#' Hard validation gate for Tabs config. Refuses if critical issues found.
#'
#' @param config Configuration list
#' @keywords internal
validate_tabs_config <- function(config) {

  # Check that config is a list
  if (!is.list(config)) {
    tabs_refuse(
      code = "CFG_INVALID_TYPE",
      title = "Invalid Configuration Format",
      problem = "Configuration must be a list, not a data frame or other type.",
      why_it_matters = "Analysis cannot proceed without properly structured configuration.",
      how_to_fix = c(
        "Ensure config file was loaded correctly",
        "Check that the Settings sheet has proper format"
      )
    )
  }

  invisible(TRUE)
}


#' Validate Tabs Data File
#'
#' Hard validation gate for data file. Refuses if file not found.
#'
#' @param data_file_path Path to data file
#' @keywords internal
validate_tabs_data_file <- function(data_file_path) {

  if (!file.exists(data_file_path)) {
    tabs_refuse(
      code = "IO_DATA_FILE_NOT_FOUND",
      title = "Data File Not Found",
      problem = paste0("Cannot find data file: ", basename(data_file_path)),
      why_it_matters = "The analysis requires survey data to produce crosstabs.",
      how_to_fix = c(
        "Check that the data_file path in Project sheet is correct",
        "Verify the file exists at the specified location",
        "Check for typos in the filename or path"
      ),
      details = paste0("Expected path: ", data_file_path)
    )
  }

  invisible(TRUE)
}


#' Validate Tabs Structure File
#'
#' Hard validation gate for structure file. Refuses if file not found.
#'
#' @param structure_file_path Path to Survey_Structure file
#' @keywords internal
validate_tabs_structure_file <- function(structure_file_path) {

  if (!file.exists(structure_file_path)) {
    tabs_refuse(
      code = "IO_STRUCTURE_FILE_NOT_FOUND",
      title = "Survey Structure File Not Found",
      problem = paste0("Cannot find survey structure file: ", basename(structure_file_path)),
      why_it_matters = "The survey structure defines questions and options needed for crosstabs.",
      how_to_fix = c(
        "Check that the structure_file path in config is correct",
        "Verify Survey_Structure.xlsx exists in your project folder",
        "Check for typos in the filename or path"
      ),
      details = paste0("Expected path: ", structure_file_path)
    )
  }

  invisible(TRUE)
}


#' Validate Tabs Survey Structure
#'
#' Hard validation gate for survey structure content. Refuses if critical issues found.
#'
#' @param survey_structure Survey structure list with $questions and $options
#' @keywords internal
validate_tabs_survey_structure <- function(survey_structure) {

  # Check structure exists
  if (!is.list(survey_structure)) {
    tabs_refuse(
      code = "CFG_INVALID_STRUCTURE",
      title = "Invalid Survey Structure",
      problem = "Survey structure must be a list with questions and options.",
      why_it_matters = "Cannot process crosstabs without properly loaded survey structure.",
      how_to_fix = "Check that Survey_Structure.xlsx was loaded correctly."
    )
  }

  # Check questions exist
  if (is.null(survey_structure$questions) || nrow(survey_structure$questions) == 0) {
    tabs_refuse(
      code = "CFG_NO_QUESTIONS",
      title = "No Questions Defined",
      problem = "The Questions sheet is empty or not found.",
      why_it_matters = "Crosstabs require at least one question to analyze.",
      how_to_fix = c(
        "Open Survey_Structure.xlsx",
        "Add questions to the Questions sheet",
        "Each question needs QuestionCode, QuestionText, and Variable_Type"
      )
    )
  }

  # Check required columns in questions
  required_cols <- c("QuestionCode", "QuestionText", "Variable_Type")
  missing_cols <- setdiff(required_cols, names(survey_structure$questions))

  if (length(missing_cols) > 0) {
    tabs_refuse(
      code = "CFG_MISSING_QUESTION_COLUMNS",
      title = "Missing Required Columns in Questions",
      problem = paste0("Questions sheet missing required columns: ", paste(missing_cols, collapse = ", ")),
      why_it_matters = "These columns are required for proper question processing.",
      how_to_fix = c(
        "Open Survey_Structure.xlsx",
        "Add the missing columns to the Questions sheet"
      ),
      expected = required_cols,
      observed = names(survey_structure$questions),
      missing = missing_cols
    )
  }

  invisible(TRUE)
}


#' Validate Tabs Question Selection
#'
#' Hard validation gate for question selection. Refuses if no questions selected.
#'
#' @param selection_df Selection data frame
#' @keywords internal
validate_tabs_selection <- function(selection_df) {

  if (!is.data.frame(selection_df)) {
    tabs_refuse(
      code = "CFG_INVALID_SELECTION",
      title = "Invalid Selection Format",
      problem = "Selection must be a data frame from the Selection sheet.",
      why_it_matters = "Cannot determine which questions to analyze without selection data.",
      how_to_fix = "Check that the Selection sheet exists in your config file."
    )
  }

  # Check QuestionCode column exists
  if (!"QuestionCode" %in% names(selection_df)) {
    tabs_refuse(
      code = "CFG_MISSING_QUESTION_CODE",
      title = "Missing QuestionCode Column",
      problem = "Selection sheet must have a QuestionCode column.",
      why_it_matters = "QuestionCode is required to identify which questions to analyze.",
      how_to_fix = c(
        "Open your config file",
        "Ensure the Selection sheet has a QuestionCode column"
      ),
      observed = names(selection_df)
    )
  }

  # Check if any questions are selected
  if (!"Include" %in% names(selection_df)) {
    tabs_refuse(
      code = "CFG_MISSING_INCLUDE_COLUMN",
      title = "Missing Include Column",
      problem = "Selection sheet must have an Include column to mark questions for analysis.",
      why_it_matters = "The Include column determines which questions to analyze.",
      how_to_fix = c(
        "Open your config file",
        "Add an Include column to the Selection sheet",
        "Set Include='Y' for questions you want to analyze"
      )
    )
  }

  # Check if any questions have Include='Y'
  included_questions <- selection_df[selection_df$Include == "Y", ]

  if (nrow(included_questions) == 0) {
    tabs_refuse(
      code = "CFG_NO_QUESTIONS_SELECTED",
      title = "No Questions Selected for Analysis",
      problem = "No questions have Include='Y' in the Selection sheet.",
      why_it_matters = "At least one question must be selected to produce crosstabs.",
      how_to_fix = c(
        "Open your config file",
        "In the Selection sheet, set Include='Y' for questions to analyze",
        "Save and re-run"
      ),
      details = paste0("Total questions in selection: ", nrow(selection_df))
    )
  }

  invisible(TRUE)
}


#' Validate Banner Structure
#'
#' Hard validation gate for banner. Refuses if banner cannot be created.
#'
#' @param banner_info Banner info structure
#' @param selection_df Selection data frame
#' @keywords internal
validate_tabs_banner <- function(banner_info, selection_df) {

  if (is.null(banner_info)) {
    tabs_refuse(
      code = "CFG_BANNER_CREATION_FAILED",
      title = "Failed to Create Banner Structure",
      problem = "Could not create banner structure from configuration.",
      why_it_matters = "Crosstabs require a valid banner to break down results by segments.",
      how_to_fix = c(
        "Check that at least one question has UseBanner='Y' in Selection sheet",
        "Verify banner question has valid options defined",
        "Check that banner question exists in the data"
      )
    )
  }

  if (is.null(banner_info$columns) || length(banner_info$columns) == 0) {
    tabs_refuse(
      code = "CFG_NO_BANNER_COLUMNS",
      title = "No Banner Columns Created",
      problem = "Banner structure is empty - no columns were created.",
      why_it_matters = "At least one banner column is required for crosstabs.",
      how_to_fix = c(
        "Check that banner questions have valid options",
        "Verify options have ShowInOutput='Y' or blank",
        "Ensure data contains the banner question columns"
      )
    )
  }

  invisible(TRUE)
}


#' Validate Question Column Exists in Data
#'
#' Soft validation for question column. Returns FALSE if not found.
#'
#' @param question_code Question code to check
#' @param data Survey data
#' @param guard Guard state for tracking
#' @return Updated guard state
#' @keywords internal
validate_question_column <- function(question_code, data, guard) {

  if (!question_code %in% names(data)) {
    guard <- guard_record_skipped_question(
      guard,
      question_code,
      "Column not found in data"
    )
  }

  guard
}


# ==============================================================================
# TRS STATUS HELPERS
# ==============================================================================

#' Create Tabs PASS Status
#'
#' @param results_count Number of questions processed
#' @return TRS status object
#' @export
tabs_status_pass <- function(results_count = NULL) {
  status <- trs_status_pass(module = "TABS")
  if (!is.null(results_count)) {
    status$details <- list(questions_processed = results_count)
  }
  status
}


#' Create Tabs PARTIAL Status
#'
#' @param degraded_reasons Character vector of degradation reasons
#' @param affected_outputs Character vector of affected outputs
#' @param skipped_questions Character vector of skipped question codes
#' @return TRS status object
#' @export
tabs_status_partial <- function(degraded_reasons,
                                affected_outputs,
                                skipped_questions = NULL) {
  status <- trs_status_partial(
    module = "TABS",
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )
  if (!is.null(skipped_questions) && length(skipped_questions) > 0) {
    status$details <- list(skipped_questions = skipped_questions)
  }
  status
}
