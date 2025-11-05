# ==============================================================================
# TURAS SHARED - OUTPUT FORMATTERS
# ==============================================================================
# Output formatting and branding utilities
# Migrated from shared_functions.r V9.9.1
# ==============================================================================

#' Get toolkit version
#'
#' @return Character, version string
#' @export
get_toolkit_version <- function() {
  return(SCRIPT_VERSION)
}

#' Print toolkit header
#'
#' USAGE: Display at start of analysis scripts for branding
#'
#' @param analysis_type Character, type of analysis being run
#' @export
#' @examples
#' print_toolkit_header("Crosstab Analysis")
print_toolkit_header <- function(analysis_type = "Analysis") {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
  cat("  R SURVEY ANALYTICS TOOLKIT V", get_toolkit_version(), "\n", sep = "")
  cat("  ", analysis_type, "\n", sep = "")
  cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
  cat("\n")
}

# Success message
cat("Turas output formatters loaded\n")
