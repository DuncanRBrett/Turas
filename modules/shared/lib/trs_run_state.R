# ==============================================================================
# TURAS RUN STATE MANAGEMENT (TRS v1.0)
# ==============================================================================
#
# Provides a run-state environment for tracking events (INFO, PARTIAL, REFUSE)
# during module execution. Each event is logged with structured metadata.
#
# USAGE:
#   state <- turas_run_state_new("MODULE_NAME")
#   turas_run_state_info(state, "CODE", "Title", detail = "...")
#   turas_run_state_partial(state, "CODE", "Title", problem = "...")
#   result <- turas_run_state_result(state)
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================


#' Create New TRS Run State
#'
#' Creates a new run-state environment for tracking module execution.
#' The state starts as PASS and can be downgraded to PARTIAL (never upgraded).
#'
#' @param module Character. Module name (e.g., "CONFIDENCE", "MAXDIFF")
#' @return Environment containing run state
#' @export
turas_run_state_new <- function(module) {
  e <- new.env(parent = emptyenv())
  e$module <- module
  e$status <- "PASS"
  e$events <- list()
  e$start_time <- Sys.time()
  e
}


#' Log INFO Event to Run State
#'
#' Records an informational event. INFO events do not change the run status.
#' Use for optional features skipped, fallback used, or other non-critical notes.
#'
#' @param state Environment. Run state from turas_run_state_new()
#' @param code Character. Event code (e.g., "CONF_OPTIONAL_SHEET_MISSING")
#' @param title Character. Short title describing the event
#' @param detail Character. Additional detail (optional)
#' @param fix Character. Suggested fix (optional)
#' @param question_code Character. Related question code (optional)
#' @param section Character. Section of analysis (optional)
#' @param stage Character. Stage of execution (optional)
#' @return TRUE invisibly
#' @export
turas_run_state_info <- function(state, code, title, detail = NULL, fix = NULL,
                                  question_code = NULL, section = NULL, stage = NULL) {
  stopifnot(is.environment(state))

  ev <- list(
    level = "INFO",
    code = code,
    title = title,
    detail = detail,
    fix = fix,
    module = state$module,
    question_code = question_code,
    section = section,
    stage = stage,
    timestamp = Sys.time()
  )

  state$events[[length(state$events) + 1]] <- ev

  message(sprintf("[TRS INFO] %s (%s)%s",
                  title, code,
                  if (!is.null(detail)) paste0(": ", detail) else ""))

  invisible(TRUE)
}


#' Log PARTIAL Event to Run State
#'
#' Records a partial completion event. PARTIAL events downgrade run status
#' from PASS to PARTIAL. Use when analysis can continue but results are degraded.
#'
#' @param state Environment. Run state from turas_run_state_new()
#' @param code Character. Event code (e.g., "CONF_CHART_FAILED")
#' @param title Character. Short title describing the event
#' @param problem Character. Description of the problem
#' @param fix Character. Suggested fix (optional)
#' @param question_code Character. Related question code (optional)
#' @param section Character. Section of analysis (optional)
#' @param stage Character. Stage of execution (optional)
#' @param error Character. Error message if from exception (optional)
#' @return TRUE invisibly
#' @export
turas_run_state_partial <- function(state, code, title, problem, fix = NULL,
                                     question_code = NULL, section = NULL,
                                     stage = NULL, error = NULL) {
  stopifnot(is.environment(state))

  # Downgrade status to PARTIAL (never upgrade)
  state$status <- "PARTIAL"

  ev <- list(
    level = "PARTIAL",
    code = code,
    title = title,
    problem = problem,
    fix = fix,
    error = error,
    module = state$module,
    question_code = question_code,
    section = section,
    stage = stage,
    timestamp = Sys.time()
  )

  state$events[[length(state$events) + 1]] <- ev

  message(sprintf("[TRS PARTIAL] %s (%s)%s",
                  title, code,
                  if (!is.null(error)) paste0(": ", error) else ""))

  invisible(TRUE)
}


#' Get Run State Result
#'
#' Extracts the final result from the run state for use in output and reporting.
#'
#' @param state Environment. Run state from turas_run_state_new()
#' @return List with status, module, events, and timing information
#' @export
turas_run_state_result <- function(state) {
  stopifnot(is.environment(state))

  end_time <- Sys.time()

  list(
    status = state$status,
    module = state$module,
    events = state$events,
    start_time = state$start_time,
    end_time = end_time,
    duration_seconds = as.numeric(difftime(end_time, state$start_time, units = "secs"))
  )
}


#' Count Events by Level
#'
#' Returns count of events at each level (INFO, PARTIAL).
#'
#' @param state Environment. Run state from turas_run_state_new()
#' @return Named list with counts
#' @export
turas_run_state_counts <- function(state) {
  stopifnot(is.environment(state))

  levels <- vapply(state$events, function(e) e$level, character(1))

  list(
    INFO = sum(levels == "INFO"),
    PARTIAL = sum(levels == "PARTIAL"),
    total = length(levels)
  )
}


#' Check if Run State has Issues
#'
#' @param state Environment. Run state from turas_run_state_new()
#' @return TRUE if any events were logged
#' @export
turas_run_state_has_issues <- function(state) {
  stopifnot(is.environment(state))
  length(state$events) > 0
}


#' Null coalesce operator
#' @keywords internal
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
