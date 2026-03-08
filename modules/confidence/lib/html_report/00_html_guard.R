# ==============================================================================
# CONFIDENCE HTML REPORT - INPUT VALIDATION
# ==============================================================================
# Validates inputs before HTML report generation.
# Returns list(valid = TRUE/FALSE, errors = character())
# ==============================================================================

#' Validate Confidence HTML Report Inputs
#'
#' Checks that confidence_results has the expected structure and at least
#' one set of results to render.
#'
#' @param confidence_results List from run_confidence_analysis()
#' @param config List with optional brand_colour, accent_colour, etc.
#' @return List with valid (logical) and errors (character vector)
#' @keywords internal
validate_confidence_html_inputs <- function(confidence_results, config) {
  errors <- character()

  # Check confidence_results is a list

  if (!is.list(confidence_results)) {
    errors <- c(errors, "confidence_results must be a list")
    return(list(valid = FALSE, errors = errors))
  }

  # Check for required fields
  required_fields <- c("config")
  for (field in required_fields) {
    if (is.null(confidence_results[[field]])) {
      errors <- c(errors, sprintf("Missing required field: %s", field))
    }
  }

  # Check at least one result set exists
  has_proportions <- !is.null(confidence_results$proportion_results) &&
                     length(confidence_results$proportion_results) > 0
  has_means <- !is.null(confidence_results$mean_results) &&
               length(confidence_results$mean_results) > 0
  has_nps <- !is.null(confidence_results$nps_results) &&
             length(confidence_results$nps_results) > 0

  if (!has_proportions && !has_means && !has_nps) {
    errors <- c(errors, "No results to render: proportion_results, mean_results, and nps_results are all empty")
  }

  # Validate config options if provided
  if (!is.null(config$brand_colour) && !grepl("^#[0-9A-Fa-f]{6}$", config$brand_colour)) {
    errors <- c(errors, sprintf("Invalid brand_colour: '%s' (must be hex like #1e3a5f)", config$brand_colour))
  }
  if (!is.null(config$accent_colour) && !grepl("^#[0-9A-Fa-f]{6}$", config$accent_colour)) {
    errors <- c(errors, sprintf("Invalid accent_colour: '%s' (must be hex like #CC9900)", config$accent_colour))
  }

  list(valid = length(errors) == 0, errors = errors)
}
