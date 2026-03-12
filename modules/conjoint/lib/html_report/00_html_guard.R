# ==============================================================================
# CONJOINT HTML REPORT - GUARD LAYER
# ==============================================================================
# Validates all inputs before HTML report generation.
# TRS v1.0: Returns structured list with valid/errors, never stop().
# ==============================================================================

#' Validate Conjoint HTML Report Inputs
#'
#' Validates conjoint results, WTP data, simulator data, insight config,
#' and about page config before HTML report generation.
#'
#' @param conjoint_results List of conjoint analysis results
#' @param config Report configuration list
#' @return List with valid (logical), errors (character), warnings (character)
#' @keywords internal
validate_conjoint_html_inputs <- function(conjoint_results, config = list()) {

  errors <- character()
  warnings <- character()

  # --- Core structure ---
  if (!is.list(conjoint_results)) {
    errors <- c(errors, "conjoint_results must be a list")
    return(list(valid = FALSE, errors = errors, warnings = warnings))
  }

  if (is.null(conjoint_results$utilities) && is.null(conjoint_results$importance)) {
    errors <- c(errors, "conjoint_results must contain 'utilities' or 'importance'")
  }

  # --- Utilities validation ---
  errors <- c(errors, .validate_utilities(conjoint_results$utilities))

  # --- Importance validation ---
  errors <- c(errors, .validate_importance(conjoint_results$importance))

  # --- Model result validation ---
  warnings <- c(warnings, .validate_model_result(conjoint_results$model_result))

  # --- WTP validation ---
  warnings <- c(warnings, .validate_wtp(conjoint_results$wtp))

  # --- Colour codes ---
  errors <- c(errors, .validate_colours(config))

  # --- Insight config ---
  warnings <- c(warnings, .validate_insights(config))

  list(valid = length(errors) == 0, errors = errors, warnings = warnings)
}


# ==============================================================================
# INTERNAL VALIDATORS
# ==============================================================================

#' @keywords internal
.validate_utilities <- function(utilities) {
  if (is.null(utilities)) return(character())
  errors <- character()
  if (!is.data.frame(utilities)) {
    return("utilities must be a data.frame")
  }
  req_cols <- c("Attribute", "Level", "Utility")
  missing_cols <- req_cols[!req_cols %in% names(utilities)]
  if (length(missing_cols) > 0) {
    errors <- c(errors, sprintf("utilities missing columns: %s",
                                paste(missing_cols, collapse = ", ")))
  }
  if (nrow(utilities) == 0) {
    errors <- c(errors, "utilities has no rows")
  }
  errors
}

#' @keywords internal
.validate_importance <- function(importance) {
  if (is.null(importance)) return(character())
  errors <- character()
  if (!is.data.frame(importance)) {
    return("importance must be a data.frame")
  }
  if (!"Attribute" %in% names(importance) || !"Importance" %in% names(importance)) {
    errors <- c(errors, "importance must have 'Attribute' and 'Importance' columns")
  }
  errors
}

#' @keywords internal
.validate_model_result <- function(model_result) {
  if (is.null(model_result)) return(character())
  warnings <- character()
  if (is.null(model_result$method)) {
    warnings <- c(warnings, "model_result$method is NULL, defaulting to 'unknown'")
  }
  if (!is.null(model_result$convergence) && !isTRUE(model_result$convergence$converged)) {
    warnings <- c(warnings, "Model did not converge; results may be unreliable")
  }
  warnings
}

#' @keywords internal
.validate_wtp <- function(wtp) {
  if (is.null(wtp)) return(character())
  warnings <- character()
  if (!is.null(wtp$wtp_table) && is.data.frame(wtp$wtp_table)) {
    req_cols <- c("Attribute", "Level", "WTP")
    missing <- req_cols[!req_cols %in% names(wtp$wtp_table)]
    if (length(missing) > 0) {
      warnings <- c(warnings, sprintf("WTP table missing columns: %s; WTP section will be skipped",
                                      paste(missing, collapse = ", ")))
    }
  }
  warnings
}

#' @keywords internal
.validate_colours <- function(config) {
  errors <- character()
  for (field in c("brand_colour", "accent_colour")) {
    val <- config[[field]]
    if (!is.null(val) && nzchar(val)) {
      if (!grepl("^#[0-9a-fA-F]{6}$", val)) {
        errors <- c(errors, sprintf("Invalid %s: '%s' (must be #XXXXXX hex)", field, val))
      }
    }
  }
  errors
}

#' @keywords internal
.validate_insights <- function(config) {
  warnings <- character()
  insight_fields <- c("insight_overview", "insight_utilities", "insight_diagnostics",
                       "insight_simulator", "insight_wtp")
  for (field in insight_fields) {
    val <- config[[field]]
    if (!is.null(val) && !is.character(val)) {
      warnings <- c(warnings, sprintf("%s must be character (got %s); will be ignored",
                                      field, class(val)[1]))
    }
  }
  warnings
}
