# ==============================================================================
# MAXDIFF - TRS GUARD LAYER
# ==============================================================================
#
# TRS v1.0 integration for the MaxDiff module.
# Implements refusal, guard state, and validation gates per TRS standard.
#
# This module provides:
#   - maxdiff_refuse() - module-specific refusal wrapper
#   - maxdiff_with_refusal_handler() - wraps main analysis with TRS handling
#   - maxdiff_guard_init() - initialize guard state with maxdiff-specific fields
#   - Validation helpers for maxdiff-specific requirements
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
# MAXDIFF-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message (MaxDiff)
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
maxdiff_refuse <- function(code,
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
    module = "MAXDIFF"
  )
}


#' Run MaxDiff Analysis with Refusal Handler
#'
#' @param expr Expression to evaluate
#' @return Result or refusal/error object
#' @export
maxdiff_with_refusal_handler <- function(expr) {
  result <- with_refusal_handler(expr, module = "MAXDIFF")

  if (inherits(result, "turas_refusal_result")) {
    class(result) <- c("maxdiff_refusal_result", class(result))
  }

  result
}


# ==============================================================================
# MAXDIFF GUARD STATE
# ==============================================================================

#' Initialize MaxDiff Guard State
#'
#' @return Guard state list
#' @export
maxdiff_guard_init <- function() {
  guard <- guard_init(module = "MAXDIFF")

  # Add MaxDiff-specific fields
  guard$design_balance <- list()
  guard$hb_convergence <- NULL
  guard$items_with_issues <- character(0)
  guard$estimation_method <- NULL
  guard$rescaled_utilities <- FALSE

  guard
}


#' Record Design Balance Issue
#'
#' @param guard Guard state object
#' @param item Item name
#' @param appearances Number of appearances
#' @param expected Expected appearances
#' @return Updated guard state
#' @keywords internal
guard_record_design_imbalance <- function(guard, item, appearances, expected) {
  guard$design_balance[[item]] <- list(
    actual = appearances,
    expected = expected,
    ratio = appearances / expected
  )
  guard <- guard_flag_stability(guard, paste0("Design imbalance: ", item))
  guard
}


#' Record HB Convergence Status
#'
#' @param guard Guard state object
#' @param converged Logical, whether HB converged
#' @param iterations Number of iterations
#' @param rhat R-hat statistic (if available)
#' @return Updated guard state
#' @keywords internal
guard_record_hb_convergence <- function(guard, converged, iterations, rhat = NULL) {
  guard$hb_convergence <- list(
    converged = converged,
    iterations = iterations,
    rhat = rhat
  )

  if (!converged) {
    guard <- guard_flag_stability(guard, "HB estimation did not converge")
  }

  guard
}


#' Get MaxDiff Guard Summary
#'
#' @param guard Guard state object
#' @return List with summary info
#' @export
maxdiff_guard_summary <- function(guard) {
  summary <- guard_summary(guard)

  summary$design_balance <- guard$design_balance
  summary$hb_convergence <- guard$hb_convergence
  summary$items_with_issues <- guard$items_with_issues
  summary$estimation_method <- guard$estimation_method
  summary$rescaled_utilities <- guard$rescaled_utilities

  summary$has_issues <- summary$has_issues ||
                        length(guard$design_balance) > 0 ||
                        (!is.null(guard$hb_convergence) && !guard$hb_convergence$converged)

  summary
}


# ==============================================================================
# MAXDIFF VALIDATION GATES
# ==============================================================================

#' Validate MaxDiff Configuration
#'
#' @param config Configuration list
#' @keywords internal
validate_maxdiff_config <- function(config) {

  if (!is.list(config)) {
    maxdiff_refuse(
      code = "CFG_INVALID_TYPE",
      title = "Invalid Configuration Format",
      problem = "Configuration must be a list.",
      why_it_matters = "Analysis cannot proceed without properly structured configuration.",
      how_to_fix = "Ensure config file was loaded correctly."
    )
  }

  invisible(TRUE)
}


#' Validate MaxDiff Items
#'
#' @param items Character vector of item names
#' @keywords internal
validate_maxdiff_items <- function(items) {

  if (is.null(items) || length(items) == 0) {
    maxdiff_refuse(
      code = "CFG_NO_ITEMS",
      title = "No MaxDiff Items Specified",
      problem = "No items were specified for MaxDiff analysis.",
      why_it_matters = "MaxDiff requires items to measure preference.",
      how_to_fix = c(
        "Open your config file",
        "Specify the items to include in the Items sheet"
      )
    )
  }

  if (length(items) < 4) {
    maxdiff_refuse(
      code = "CFG_INSUFFICIENT_ITEMS",
      title = "Insufficient Items for MaxDiff",
      problem = paste0("Only ", length(items), " items specified. Need at least 4."),
      why_it_matters = "MaxDiff requires enough items to create meaningful choice tasks.",
      how_to_fix = "Add more items to your MaxDiff design (minimum 4, typically 8-20)."
    )
  }

  # Check for duplicate items
  dup_items <- items[duplicated(items)]
  if (length(dup_items) > 0) {
    maxdiff_refuse(
      code = "CFG_DUPLICATE_ITEMS",
      title = "Duplicate Items in MaxDiff",
      problem = paste0(length(unique(dup_items)), " duplicate item(s) found."),
      why_it_matters = "Duplicate items will cause incorrect utility estimates.",
      how_to_fix = "Remove duplicate items from your configuration.",
      details = paste0("Duplicates: ", paste(unique(dup_items), collapse = ", "))
    )
  }

  invisible(TRUE)
}


#' Validate MaxDiff Design
#'
#' @param design Design matrix
#' @param n_items Number of items
#' @keywords internal
validate_maxdiff_design <- function(design, n_items) {

  if (is.null(design) || !is.data.frame(design)) {
    maxdiff_refuse(
      code = "CFG_INVALID_DESIGN",
      title = "Invalid MaxDiff Design",
      problem = "Design matrix is missing or invalid.",
      why_it_matters = "MaxDiff analysis requires a valid experimental design.",
      how_to_fix = c(
        "Check that the Design sheet exists in your config",
        "Verify design format is correct"
      )
    )
  }

  if (nrow(design) == 0) {
    maxdiff_refuse(
      code = "CFG_EMPTY_DESIGN",
      title = "Empty MaxDiff Design",
      problem = "Design matrix has no rows.",
      why_it_matters = "Cannot analyze MaxDiff without choice tasks.",
      how_to_fix = "Add choice task definitions to your Design sheet."
    )
  }

  invisible(TRUE)
}


#' Validate MaxDiff Design Balance
#'
#' @param design Design matrix
#' @param items Item names
#' @param guard Guard state
#' @return Updated guard state
#' @keywords internal
validate_design_balance <- function(design, items, guard) {

  # Count appearances of each item
  item_counts <- table(unlist(design[, grepl("item", names(design), ignore.case = TRUE)]))

  expected <- mean(item_counts)
  tolerance <- 0.2  # 20% imbalance tolerance

  for (item in names(item_counts)) {
    ratio <- item_counts[item] / expected
    if (abs(ratio - 1) > tolerance) {
      guard <- guard_record_design_imbalance(guard, item, item_counts[item], expected)
    }
  }

  # Hard refuse if severe imbalance
  min_count <- min(item_counts)
  max_count <- max(item_counts)

  if (max_count / min_count > 3) {
    maxdiff_refuse(
      code = "CFG_UNBALANCED_DESIGN",
      title = "Severely Unbalanced MaxDiff Design",
      problem = paste0("Item appearances range from ", min_count, " to ", max_count, " (ratio > 3:1)."),
      why_it_matters = "Severely unbalanced designs produce unreliable utility estimates.",
      how_to_fix = c(
        "Generate a new balanced design",
        "Ensure each item appears approximately the same number of times"
      ),
      details = paste0("Item counts: ", paste(paste(names(item_counts), "=", item_counts), collapse = ", "))
    )
  }

  guard
}


#' Validate HB Convergence
#'
#' @param hb_result HB estimation result
#' @keywords internal
validate_hb_convergence <- function(hb_result) {

  if (is.null(hb_result)) {
    maxdiff_refuse(
      code = "MODEL_HB_FAILED",
      title = "Hierarchical Bayes Estimation Failed",
      problem = "HB estimation did not produce results.",
      why_it_matters = "Cannot calculate individual-level utilities without HB results.",
      how_to_fix = c(
        "Check data for issues",
        "Try increasing number of iterations",
        "Check for respondents with all same choices"
      )
    )
  }

  if (!is.null(hb_result$converged) && !hb_result$converged) {
    maxdiff_refuse(
      code = "MODEL_HB_DID_NOT_CONVERGE",
      title = "HB Estimation Did Not Converge",
      problem = "Hierarchical Bayes estimation did not reach convergence.",
      why_it_matters = "Non-converged estimates may be unreliable.",
      how_to_fix = c(
        "Increase the number of iterations",
        "Check data quality",
        "Consider using aggregate logit as fallback"
      ),
      details = if (!is.null(hb_result$iterations)) paste0("Iterations: ", hb_result$iterations) else NULL
    )
  }

  invisible(TRUE)
}


# ==============================================================================
# TRS STATUS HELPERS
# ==============================================================================

#' Create MaxDiff PASS Status
#'
#' @param n_items Number of items analyzed
#' @param n_respondents Number of respondents
#' @param method Estimation method used
#' @return TRS status object
#' @export
maxdiff_status_pass <- function(n_items = NULL, n_respondents = NULL, method = NULL) {
  status <- trs_status_pass(module = "MAXDIFF")
  status$details <- list(
    items = n_items,
    respondents = n_respondents,
    method = method
  )
  status
}


#' Create MaxDiff PARTIAL Status
#'
#' @param degraded_reasons Character vector of degradation reasons
#' @param affected_outputs Character vector of affected outputs
#' @param imbalanced_items Character vector of imbalanced item names
#' @return TRS status object
#' @export
maxdiff_status_partial <- function(degraded_reasons,
                                   affected_outputs,
                                   imbalanced_items = NULL) {
  status <- trs_status_partial(
    module = "MAXDIFF",
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )
  if (!is.null(imbalanced_items) && length(imbalanced_items) > 0) {
    status$details <- list(imbalanced_items = imbalanced_items)
  }
  status
}
