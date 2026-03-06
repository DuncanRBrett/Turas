# ==============================================================================
# WEIGHTING HTML REPORT - GUARD LAYER
# ==============================================================================

#' Validate HTML Report Inputs
#'
#' @param weighting_results List from run_weighting()
#' @param config List, report configuration
#' @return List with $valid, $errors
#' @keywords internal
validate_html_report_inputs <- function(weighting_results, config = list()) {
  errors <- character(0)

  if (is.null(weighting_results)) {
    errors <- c(errors, "weighting_results is NULL")
    return(list(valid = FALSE, errors = errors))
  }

  if (is.null(weighting_results$data) || !is.data.frame(weighting_results$data)) {
    errors <- c(errors, "weighting_results$data must be a data frame")
  }

  if (is.null(weighting_results$weight_names) || length(weighting_results$weight_names) == 0) {
    errors <- c(errors, "No weight names found in results")
  }

  if (is.null(weighting_results$weight_results) || length(weighting_results$weight_results) == 0) {
    errors <- c(errors, "No weight results found")
  }

  # Check htmltools availability
  if (!requireNamespace("htmltools", quietly = TRUE)) {
    errors <- c(errors, "Package 'htmltools' is required for HTML report generation. Install with: install.packages('htmltools')")
  }

  return(list(valid = length(errors) == 0, errors = errors))
}
