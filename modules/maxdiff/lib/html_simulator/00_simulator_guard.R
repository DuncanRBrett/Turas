# ==============================================================================
# MAXDIFF SIMULATOR - GUARD LAYER - TURAS V11.0
# ==============================================================================

#' Validate simulator inputs
#'
#' @param utilities Population utilities or individual utilities
#' @param config Module config
#'
#' @return List with valid (logical) and issues (character vector)
#' @keywords internal
validate_simulator_inputs <- function(utilities, config) {

  issues <- character()

  if (is.null(utilities)) {
    issues <- c(issues, "No utilities provided for simulator")
  }

  if (is.null(config)) {
    issues <- c(issues, "No config provided for simulator")
  }

  if (is.null(config$items) || nrow(config$items) == 0) {
    issues <- c(issues, "No items defined in config")
  }

  list(
    valid = length(issues) == 0,
    issues = issues
  )
}

#' Validate hex colour code
#'
#' @param colour Character string
#' @return Logical
#' @keywords internal
is_valid_hex_colour <- function(colour) {
  if (is.null(colour) || !is.character(colour) || length(colour) != 1) return(FALSE)
  grepl("^#[0-9A-Fa-f]{6}$", colour)
}
