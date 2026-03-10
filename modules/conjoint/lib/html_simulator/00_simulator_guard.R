# ==============================================================================
# CONJOINT HTML SIMULATOR - GUARD LAYER
# ==============================================================================

#' Validate Simulator Inputs
#' @keywords internal
validate_simulator_inputs <- function(utilities, config) {

  errors <- character()

  if (is.null(utilities) || !is.data.frame(utilities)) {
    errors <- c(errors, "utilities must be a data frame")
  } else {
    req <- c("Attribute", "Level", "Utility")
    missing <- req[!req %in% names(utilities)]
    if (length(missing) > 0) {
      errors <- c(errors, sprintf("utilities missing columns: %s", paste(missing, collapse = ", ")))
    }
    if (nrow(utilities) == 0) {
      errors <- c(errors, "utilities has zero rows")
    }
  }

  if (is.null(config$attributes)) {
    errors <- c(errors, "config must have attributes definition")
  }

  list(valid = length(errors) == 0, errors = errors)
}
