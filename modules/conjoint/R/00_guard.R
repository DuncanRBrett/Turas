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
      # TRS-compliant: output to console then stop with structured message
      # The stop() here is intentional — turas_refuse is expected to halt execution
      # throughout the codebase. The structured message is printed for Shiny console visibility.
      msg <- paste0("[", code, "] ", title, ": ", problem)
      cat("\n=== TURAS REFUSAL ===\n")
      cat("Code:", code, "\n")
      cat("Title:", title, "\n")
      cat("Problem:", problem, "\n")
      cat("How to fix:", paste(how_to_fix, collapse = "; "), "\n")
      cat("====================\n\n")
      stop(msg, call. = FALSE)
    }
    with_refusal_handler <- function(expr, module = "UNKNOWN") {
      tryCatch(expr, error = function(e) {
        list(status = "REFUSED", code = "UNHANDLED_ERROR", message = conditionMessage(e),
             module = module, how_to_fix = "Check the console output for details")
      })
    }
    guard_init <- function(module = "UNKNOWN") list(module = module, warnings = list(), stable = TRUE)
    guard_warn <- function(guard, msg, category = "general") { guard$warnings <- c(guard$warnings, list(list(msg = msg, category = category))); guard }
    guard_flag_stability <- function(guard, reason) { guard$stable <- FALSE; guard }
    guard_summary <- function(guard) list(module = guard$module, warning_count = length(guard$warnings), is_stable = guard$stable, has_issues = length(guard$warnings) > 0, stability_flags = character(0))
    trs_status_pass <- function(module) list(status = "PASS", module = module)
    trs_status_partial <- function(module, degraded_reasons, affected_outputs) list(status = "PARTIAL", module = module, degraded_reasons = degraded_reasons)
    trs_status_refuse <- function(module, code, message, how_to_fix) list(status = "REFUSED", module = module, code = code, message = message, how_to_fix = how_to_fix)
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
  guard$convergence_status <- list(converged = NULL)
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
                        (!is.null(guard$convergence_status$converged) && !guard$convergence_status$converged)

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
  unique_attrs <- unique(attributes$AttributeName)
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
    levels <- attributes$LevelNames[attributes$AttributeName == attr]
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

  # Check convergence if available (supports both flat and nested structure)
  converged_val <- model_result$convergence$converged %||% model_result$converged
  if (!is.null(converged_val) && !converged_val) {
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


#' Guard: Check Data Exists and Is Non-Empty
#'
#' Quick pre-check before detailed validation in 02_data.R.
#' Do not confuse with validate_conjoint_data() in 02_data.R which
#' performs comprehensive column/type validation.
#'
#' @param data Choice data
#' @param min_choices Minimum choices per respondent (unused, kept for compat)
#' @keywords internal
guard_check_data_exists <- function(data, min_choices = 5) {

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
# PHASE 3 UPGRADE - ADDITIONAL VALIDATION GATES
# ==============================================================================

#' Validate HB Configuration
#'
#' Validates Hierarchical Bayes-specific settings including iterations,
#' burn-in, thinning, and package availability.
#'
#' @param config Configuration list
#' @keywords internal
validate_hb_config <- function(config) {

  # Check bayesm package
  if (!requireNamespace("bayesm", quietly = TRUE)) {
    conjoint_refuse(
      code = "PKG_BAYESM_MISSING",
      title = "Required Package Not Installed",
      problem = "Package 'bayesm' is required for Hierarchical Bayes estimation but is not installed.",
      why_it_matters = "HB estimation uses bayesm::rhierMnlRwMixture for individual-level utility calculation.",
      how_to_fix = c(
        "Install bayesm: install.packages('bayesm')",
        "Or change estimation_method to 'auto', 'mlogit', or 'clogit' in your config"
      )
    )
  }

  # Validate iteration settings
  if (config$hb_iterations < 100) {
    conjoint_refuse(
      code = "CFG_HB_ITERATIONS_TOO_LOW",
      title = "Insufficient HB Iterations",
      problem = sprintf("hb_iterations = %d is too low for reliable estimation.", config$hb_iterations),
      why_it_matters = "MCMC estimation requires sufficient iterations for convergence. Minimum is 1000, recommended is 10000+.",
      how_to_fix = "Set hb_iterations to at least 1000 (recommended: 10000)"
    )
  }

  if (config$hb_burnin >= config$hb_iterations) {
    conjoint_refuse(
      code = "CFG_HB_BURNIN_EXCEEDS_ITERATIONS",
      title = "Invalid HB Burn-in",
      problem = sprintf("hb_burnin (%d) >= hb_iterations (%d).", config$hb_burnin, config$hb_iterations),
      why_it_matters = "Burn-in must be less than total iterations to retain post-burn-in draws for inference.",
      how_to_fix = sprintf("Set hb_burnin to less than %d (recommended: %d)",
                           config$hb_iterations,
                           as.integer(config$hb_iterations / 2))
    )
  }

  if (config$hb_thin < 1) {
    conjoint_refuse(
      code = "CFG_HB_THIN_INVALID",
      title = "Invalid HB Thinning",
      problem = sprintf("hb_thin = %d is invalid (must be >= 1).", config$hb_thin),
      why_it_matters = "Thinning controls how many MCMC draws are retained. A value of 1 keeps all draws.",
      how_to_fix = "Set hb_thin to 1 (keep all) or a small positive integer"
    )
  }

  invisible(TRUE)
}


#' Validate Latent Class Configuration
#'
#' Validates latent class analysis settings.
#'
#' @param config Configuration list
#' @keywords internal
validate_latent_class_config <- function(config) {

  # bayesm is also required for LC (multi-component mixture)
  if (!requireNamespace("bayesm", quietly = TRUE)) {
    conjoint_refuse(
      code = "PKG_BAYESM_MISSING",
      title = "Required Package Not Installed",
      problem = "Package 'bayesm' is required for latent class analysis but is not installed.",
      why_it_matters = "Latent class analysis uses bayesm with multiple mixture components.",
      how_to_fix = c(
        "Install bayesm: install.packages('bayesm')",
        "Or change estimation_method to 'auto', 'mlogit', or 'clogit' in your config"
      )
    )
  }

  if (config$latent_class_min < 2) {
    conjoint_refuse(
      code = "CFG_LC_MIN_TOO_LOW",
      title = "Invalid Latent Class Minimum",
      problem = sprintf("latent_class_min = %d is invalid (must be >= 2).", config$latent_class_min),
      why_it_matters = "Latent class analysis requires at least 2 classes to be meaningful.",
      how_to_fix = "Set latent_class_min to 2 or higher"
    )
  }

  if (config$latent_class_max < config$latent_class_min) {
    conjoint_refuse(
      code = "CFG_LC_MAX_BELOW_MIN",
      title = "Invalid Latent Class Range",
      problem = sprintf("latent_class_max (%d) < latent_class_min (%d).",
                        config$latent_class_max, config$latent_class_min),
      why_it_matters = "The maximum number of classes must be >= the minimum.",
      how_to_fix = sprintf("Set latent_class_max to at least %d", config$latent_class_min)
    )
  }

  valid_criteria <- c("bic", "aic")
  if (!config$latent_class_criterion %in% valid_criteria) {
    conjoint_refuse(
      code = "CFG_LC_CRITERION_INVALID",
      title = "Invalid Class Selection Criterion",
      problem = sprintf("latent_class_criterion = '%s' is not supported.", config$latent_class_criterion),
      why_it_matters = "The criterion determines how the optimal number of classes is selected.",
      how_to_fix = sprintf("Use one of: %s", paste(valid_criteria, collapse = ", "))
    )
  }

  invisible(TRUE)
}


#' Validate HTML Output Configuration
#'
#' Validates settings for HTML report and simulator generation.
#'
#' @param config Configuration list
#' @keywords internal
validate_html_config <- function(config) {

  # Validate brand colours if specified
  colour_pattern <- "^#[0-9A-Fa-f]{6}$"

  if (!is.na(config$brand_colour) && !grepl(colour_pattern, config$brand_colour)) {
    conjoint_refuse(
      code = "CFG_HTML_INVALID_COLOUR",
      title = "Invalid Brand Colour",
      problem = sprintf("brand_colour '%s' is not a valid hex colour.", config$brand_colour),
      why_it_matters = "The brand colour is used for styling the HTML report and simulator.",
      how_to_fix = "Use a valid 6-digit hex colour code (e.g., '#323367')"
    )
  }

  if (!is.na(config$accent_colour) && !grepl(colour_pattern, config$accent_colour)) {
    conjoint_refuse(
      code = "CFG_HTML_INVALID_ACCENT",
      title = "Invalid Accent Colour",
      problem = sprintf("accent_colour '%s' is not a valid hex colour.", config$accent_colour),
      why_it_matters = "The accent colour is used for highlights in the HTML report and simulator.",
      how_to_fix = "Use a valid 6-digit hex colour code (e.g., '#CC9900')"
    )
  }

  invisible(TRUE)
}


#' Validate WTP Configuration
#'
#' Validates willingness-to-pay settings.
#'
#' @param config Configuration list
#' @param attributes_df Data frame of attributes
#' @keywords internal
validate_wtp_config <- function(config, attributes_df) {

  price_attr <- config$wtp_price_attribute

  # If WTP price attribute is specified, validate it exists

  if (!is.na(price_attr) && nchar(trimws(price_attr)) > 0) {
    if (!price_attr %in% attributes_df$AttributeName) {
      conjoint_refuse(
        code = "CFG_WTP_ATTRIBUTE_NOT_FOUND",
        title = "WTP Price Attribute Not Found",
        problem = sprintf("wtp_price_attribute '%s' not found in Attributes sheet.", price_attr),
        why_it_matters = "WTP calculation requires a valid price attribute to compute willingness to pay.",
        how_to_fix = c(
          sprintf("Available attributes: %s", paste(attributes_df$AttributeName, collapse = ", ")),
          "Set wtp_price_attribute to the attribute representing price, or leave blank to skip WTP"
        )
      )
    }

    valid_wtp_methods <- c("marginal", "simulation", "sos")
    if (!config$wtp_method %in% valid_wtp_methods) {
      conjoint_refuse(
        code = "CFG_WTP_METHOD_INVALID",
        title = "Invalid WTP Method",
        problem = sprintf("wtp_method '%s' is not supported.", config$wtp_method),
        why_it_matters = "The WTP method determines how willingness to pay is calculated.",
        how_to_fix = sprintf("Use one of: %s", paste(valid_wtp_methods, collapse = ", "))
      )
    }
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


#' Create Conjoint REFUSE Status
#'
#' Creates a TRS-compliant REFUSE status for the conjoint module.
#' Use this when the module cannot proceed due to user-fixable issues.
#'
#' @param code Refusal code (e.g., "CFG_NO_ATTRIBUTES", "DATA_INSUFFICIENT_CHOICES")
#' @param reason Human-readable reason for refusal
#' @return TRS status object with REFUSE state
#' @export
conjoint_status_refuse <- function(code = NULL, reason = NULL) {
  trs_status_refuse(
    module = "CONJOINT",
    code = code,
    reason = reason %||% "Conjoint analysis refused"
  )
}


#' Determine Final Run Status from Guard State
#'
#' Analyzes the guard state accumulated during conjoint analysis to determine
#' the final TRS execution status (PASS, PARTIAL, REFUSE, ERROR).
#'
#' Decision logic:
#' - PASS: No warnings, converged model, no design issues
#' - PARTIAL: Has warnings or design issues but produced valid output
#' - REFUSE: Critical validation failures (handled via conjoint_refuse())
#'
#' @param guard Guard state object from conjoint_guard_init()
#' @param n_attributes Integer, number of attributes analyzed (NULL if failed)
#' @param n_respondents Integer, number of respondents (NULL if failed)
#' @param model_type Character, estimation method used (NULL if failed)
#' @param mcfadden_r2 Numeric, McFadden R-squared value (NULL if not calculated)
#' @return TRS status object (PASS or PARTIAL)
#' @export
conjoint_determine_status <- function(guard,
                                      n_attributes = NULL,
                                      n_respondents = NULL,
                                      model_type = NULL,
                                      mcfadden_r2 = NULL) {

  # Get guard summary
  summary <- conjoint_guard_summary(guard)

  # Collect degradation reasons
  degraded_reasons <- character(0)
  affected_outputs <- character(0)

  # Check for design issues
  if (length(summary$design_issues) > 0) {
    degraded_reasons <- c(degraded_reasons,
      sprintf("%d attribute(s) have design issues", length(summary$design_issues)))
    affected_outputs <- c(affected_outputs, "part_worth_utilities", "attribute_importance")
  }

  # Check for estimation warnings
  if (length(summary$estimation_warnings) > 0) {
    degraded_reasons <- c(degraded_reasons,
      sprintf("%d estimation warning(s)", length(summary$estimation_warnings)))
    affected_outputs <- c(affected_outputs, "model_coefficients", "confidence_intervals")
  }

  # Check convergence status
  if (!is.null(summary$convergence_status$converged) && !summary$convergence_status$converged) {
    degraded_reasons <- c(degraded_reasons, "Model did not fully converge")
    affected_outputs <- c(affected_outputs, "all_outputs")
  }

  # Check model fit quality via McFadden R²
  if (!is.null(mcfadden_r2)) {
    if (mcfadden_r2 < 0.1) {
      degraded_reasons <- c(degraded_reasons,
        sprintf("Poor model fit (McFadden R²=%.3f, threshold=0.1)", mcfadden_r2))
      affected_outputs <- c(affected_outputs, "market_simulator", "predictions")
    } else if (mcfadden_r2 < 0.2) {
      degraded_reasons <- c(degraded_reasons,
        sprintf("Marginal model fit (McFadden R²=%.3f, good=0.2+)", mcfadden_r2))
      affected_outputs <- c(affected_outputs, "market_simulator")
    }
  }

  # Check stability flags
  if (length(summary$stability_flags) > 0) {
    degraded_reasons <- c(degraded_reasons, summary$stability_flags)
    affected_outputs <- c(affected_outputs, "result_stability")
  }

  # Determine final status
  if (length(degraded_reasons) > 0) {
    status <- conjoint_status_partial(
      degraded_reasons = unique(degraded_reasons),
      affected_outputs = unique(affected_outputs),
      estimation_warnings = summary$estimation_warnings
    )
  } else {
    status <- conjoint_status_pass(
      n_attributes = n_attributes,
      n_respondents = n_respondents,
      model_type = model_type
    )
  }

  # Add model fit to status details
  if (!is.null(mcfadden_r2)) {
    if (is.null(status$details)) status$details <- list()
    status$details$mcfadden_r2 <- mcfadden_r2
  }

  status
}
