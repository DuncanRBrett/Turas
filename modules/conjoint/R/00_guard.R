# ==============================================================================
# CONJOINT - TRS GUARD LAYER
# ==============================================================================
#
# TRS v1.0 integration for the Conjoint module.
# Implements refusal, guard state, and validation gates per TRS standard.
#
# This module provides:
#   - conjoint_refuse() - module-specific refusal wrapper
#   - conjoint_with_refusal_handler() - wraps main analysis with TRS handling
#   - conjoint_guard_init() - initialize guard state with conjoint-specific fields
#   - Validation helpers for conjoint-specific requirements
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
  possible_paths <- c(
    file.path(dirname(sys.frame(1)$ofile), "../../shared/lib/trs_refusal.R"),
    file.path(getwd(), "modules/shared/lib/trs_refusal.R"),
    file.path(Sys.getenv("TURAS_HOME"), "modules/shared/lib/trs_refusal.R")
  )

  for (path in possible_paths) {
    if (file.exists(path)) {
      source(path)
      break
    }
  }
}


# ==============================================================================
# CONJOINT-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message (Conjoint)
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
conjoint_refuse <- function(code,
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
    module = "CONJOINT"
  )
}


#' Run Conjoint Analysis with Refusal Handler
#'
#' @param expr Expression to evaluate
#' @return Result or refusal/error object
#' @export
conjoint_with_refusal_handler <- function(expr) {
  result <- with_refusal_handler(expr, module = "CONJOINT")

  if (inherits(result, "turas_refusal_result")) {
    class(result) <- c("conjoint_refusal_result", class(result))
  }

  result
}


# ==============================================================================
# CONJOINT GUARD STATE
# ==============================================================================

#' Initialize Conjoint Guard State
#'
#' @return Guard state list
#' @export
conjoint_guard_init <- function() {
  guard <- guard_init(module = "CONJOINT")

  # Add Conjoint-specific fields
  guard$design_issues <- list()
  guard$estimation_warnings <- character(0)
  guard$convergence_status <- NULL
  guard$attribute_issues <- list()
  guard$none_option_included <- FALSE

  guard
}


#' Record Design Issue
#'
#' @param guard Guard state object
#' @param attribute Attribute name
#' @param issue Issue description
#' @return Updated guard state
#' @keywords internal
guard_record_design_issue <- function(guard, attribute, issue) {
  guard$design_issues[[attribute]] <- issue
  guard <- guard_flag_stability(guard, paste0("Design issue: ", attribute))
  guard
}


#' Record Estimation Warning
#'
#' @param guard Guard state object
#' @param warning Warning message
#' @return Updated guard state
#' @keywords internal
guard_record_estimation_warning <- function(guard, warning) {
  guard$estimation_warnings <- c(guard$estimation_warnings, warning)
  guard <- guard_warn(guard, warning, "estimation")
  guard
}


#' Record Convergence Status
#'
#' @param guard Guard state object
#' @param converged Logical
#' @param iterations Number of iterations
#' @param log_likelihood Final log-likelihood
#' @return Updated guard state
#' @keywords internal
guard_record_convergence <- function(guard, converged, iterations = NULL, log_likelihood = NULL) {
  guard$convergence_status <- list(
    converged = converged,
    iterations = iterations,
    log_likelihood = log_likelihood
  )

  if (!converged) {
    guard <- guard_flag_stability(guard, "Model did not converge")
  }

  guard
}


#' Get Conjoint Guard Summary
#'
#' @param guard Guard state object
#' @return List with summary info
#' @export
conjoint_guard_summary <- function(guard) {
  summary <- guard_summary(guard)

  summary$design_issues <- guard$design_issues
  summary$estimation_warnings <- guard$estimation_warnings
  summary$convergence_status <- guard$convergence_status
  summary$attribute_issues <- guard$attribute_issues
  summary$none_option_included <- guard$none_option_included

  summary$has_issues <- summary$has_issues ||
                        length(guard$design_issues) > 0 ||
                        length(guard$estimation_warnings) > 0 ||
                        (!is.null(guard$convergence_status) && !guard$convergence_status$converged)

  summary
}


# ==============================================================================
# CONJOINT VALIDATION GATES
# ==============================================================================

#' Validate Conjoint Configuration
#'
#' @param config Configuration list
#' @keywords internal
validate_conjoint_config <- function(config) {

  if (!is.list(config)) {
    conjoint_refuse(
      code = "CFG_INVALID_TYPE",
      title = "Invalid Configuration Format",
      problem = "Configuration must be a list.",
      why_it_matters = "Analysis cannot proceed without properly structured configuration.",
      how_to_fix = "Ensure config file was loaded correctly."
    )
  }

  invisible(TRUE)
}


#' Validate Conjoint Attributes
#'
#' @param attributes Data frame of attributes and levels
#' @keywords internal
validate_conjoint_attributes <- function(attributes) {

  if (is.null(attributes) || !is.data.frame(attributes)) {
    conjoint_refuse(
      code = "CFG_NO_ATTRIBUTES",
      title = "No Attributes Defined",
      problem = "Attributes definition is missing or invalid.",
      why_it_matters = "Conjoint analysis requires attribute and level definitions.",
      how_to_fix = c(
        "Open your config file",
        "Add attributes and levels to the Attributes sheet"
      )
    )
  }

  if (nrow(attributes) == 0) {
    conjoint_refuse(
      code = "CFG_EMPTY_ATTRIBUTES",
      title = "Empty Attributes Definition",
      problem = "No attributes were defined.",
      why_it_matters = "Conjoint requires at least 2 attributes with 2+ levels each.",
      how_to_fix = "Add attribute definitions to the Attributes sheet."
    )
  }

  # Check minimum structure
  unique_attrs <- unique(attributes$attribute)
  if (length(unique_attrs) < 2) {
    conjoint_refuse(
      code = "CFG_INSUFFICIENT_ATTRIBUTES",
      title = "Insufficient Attributes",
      problem = paste0("Only ", length(unique_attrs), " attribute(s) defined. Need at least 2."),
      why_it_matters = "Conjoint requires multiple attributes to estimate trade-offs.",
      how_to_fix = "Add at least one more attribute to your design."
    )
  }

  # Check each attribute has at least 2 levels
  for (attr in unique_attrs) {
    levels <- attributes$level[attributes$attribute == attr]
    if (length(unique(levels)) < 2) {
      conjoint_refuse(
        code = "CFG_INSUFFICIENT_LEVELS",
        title = "Insufficient Levels for Attribute",
        problem = paste0("Attribute '", attr, "' has only ", length(unique(levels)), " level(s). Need at least 2."),
        why_it_matters = "Each attribute requires at least 2 levels to measure preference.",
        how_to_fix = paste0("Add at least one more level to attribute '", attr, "'.")
      )
    }
  }

  invisible(TRUE)
}


#' Validate Conjoint Design Matrix
#'
#' @param design Design matrix
#' @param attributes Attributes data frame
#' @keywords internal
validate_conjoint_design <- function(design, attributes) {

  if (is.null(design) || !is.data.frame(design)) {
    conjoint_refuse(
      code = "CFG_INVALID_DESIGN",
      title = "Invalid Conjoint Design",
      problem = "Design matrix is missing or invalid.",
      why_it_matters = "Conjoint analysis requires a valid experimental design.",
      how_to_fix = c(
        "Check that the Design sheet exists",
        "Generate a proper experimental design"
      )
    )
  }

  if (nrow(design) == 0) {
    conjoint_refuse(
      code = "CFG_EMPTY_DESIGN",
      title = "Empty Conjoint Design",
      problem = "Design matrix has no choice tasks.",
      why_it_matters = "Cannot analyze conjoint without choice tasks.",
      how_to_fix = "Add choice task definitions to your Design sheet."
    )
  }

  invisible(TRUE)
}


#' Validate Model Convergence
#'
#' @param model_result Model estimation result
#' @keywords internal
validate_conjoint_convergence <- function(model_result) {

  if (is.null(model_result)) {
    conjoint_refuse(
      code = "MODEL_FIT_FAILED",
      title = "Model Estimation Failed",
      problem = "Conjoint model estimation did not produce results.",
      why_it_matters = "Cannot calculate utilities without a fitted model.",
      how_to_fix = c(
        "Check data for quality issues",
        "Ensure sufficient sample size",
        "Check for respondents with no variation in choices"
      )
    )
  }

  # Check convergence if available
  if (!is.null(model_result$converged) && !model_result$converged) {
    conjoint_refuse(
      code = "MODEL_DID_NOT_CONVERGE",
      title = "Model Did Not Converge",
      problem = "The estimation algorithm did not reach convergence.",
      why_it_matters = "Non-converged estimates may be unreliable.",
      how_to_fix = c(
        "Increase maximum iterations",
        "Check for separation in the data",
        "Consider simplifying the model"
      )
    )
  }

  invisible(TRUE)
}


#' Validate Data Has Sufficient Choices
#'
#' @param data Choice data
#' @param min_choices Minimum choices per respondent
#' @keywords internal
validate_conjoint_data <- function(data, min_choices = 5) {

  if (is.null(data) || nrow(data) == 0) {
    conjoint_refuse(
      code = "DATA_INSUFFICIENT_CHOICES",
      title = "Insufficient Choice Data",
      problem = "No choice data available.",
      why_it_matters = "Conjoint analysis requires choice observations.",
      how_to_fix = c(
        "Check that data file was loaded correctly",
        "Verify choice columns are present"
      )
    )
  }

  invisible(TRUE)
}


# ==============================================================================
# TRS STATUS HELPERS
# ==============================================================================

#' Create Conjoint PASS Status
#'
#' @param n_attributes Number of attributes
#' @param n_respondents Number of respondents
#' @param model_type Model type used
#' @return TRS status object
#' @export
conjoint_status_pass <- function(n_attributes = NULL, n_respondents = NULL, model_type = NULL) {
  status <- trs_status_pass(module = "CONJOINT")
  status$details <- list(
    attributes = n_attributes,
    respondents = n_respondents,
    model_type = model_type
  )
  status
}


#' Create Conjoint PARTIAL Status
#'
#' @param degraded_reasons Character vector of degradation reasons
#' @param affected_outputs Character vector of affected outputs
#' @param estimation_warnings Character vector of estimation warnings
#' @return TRS status object
#' @export
conjoint_status_partial <- function(degraded_reasons,
                                    affected_outputs,
                                    estimation_warnings = NULL) {
  status <- trs_status_partial(
    module = "CONJOINT",
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )
  if (!is.null(estimation_warnings) && length(estimation_warnings) > 0) {
    status$details <- list(estimation_warnings = estimation_warnings)
  }
  status
}
