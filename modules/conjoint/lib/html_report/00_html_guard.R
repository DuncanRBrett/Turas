# ==============================================================================
# CONJOINT HTML REPORT - GUARD LAYER
# ==============================================================================
# Validates inputs before HTML report generation
# ==============================================================================

#' Validate Conjoint HTML Report Inputs
#'
#' @param conjoint_results List of conjoint analysis results
#' @param config Report configuration
#' @return List with valid (logical) and errors (character vector)
#' @keywords internal
validate_conjoint_html_inputs <- function(conjoint_results, config = list()) {

  errors <- character()

  # Check conjoint_results is a list

  if (!is.list(conjoint_results)) {
    errors <- c(errors, "conjoint_results must be a list")
    return(list(valid = FALSE, errors = errors))
  }

  # Check for required components
  if (is.null(conjoint_results$utilities) && is.null(conjoint_results$importance)) {
    errors <- c(errors, "conjoint_results must contain 'utilities' or 'importance'")
  }

  # Validate utilities structure
  if (!is.null(conjoint_results$utilities)) {
    req_cols <- c("Attribute", "Level", "Utility")
    missing_cols <- req_cols[!req_cols %in% names(conjoint_results$utilities)]
    if (length(missing_cols) > 0) {
      errors <- c(errors, sprintf("utilities missing columns: %s", paste(missing_cols, collapse = ", ")))
    }
  }

  # Validate importance structure
  if (!is.null(conjoint_results$importance)) {
    if (!"Attribute" %in% names(conjoint_results$importance) ||
        !"Importance" %in% names(conjoint_results$importance)) {
      errors <- c(errors, "importance must have 'Attribute' and 'Importance' columns")
    }
  }

  # Validate colour codes if provided
  for (colour_field in c("brand_colour", "accent_colour")) {
    val <- config[[colour_field]]
    if (!is.null(val) && nzchar(val)) {
      if (!grepl("^#[0-9a-fA-F]{6}$", val)) {
        errors <- c(errors, sprintf("Invalid %s: '%s' (must be #XXXXXX hex)", colour_field, val))
      }
    }
  }

  list(valid = length(errors) == 0, errors = errors)
}
