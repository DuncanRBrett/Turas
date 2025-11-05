# ==============================================================================
# TURAS CORE - DEPENDENCIES
# ==============================================================================
# Package availability checking and safe script sourcing
# Migrated from shared_functions.r V9.9.1
# ==============================================================================

#' Check if package is available
#'
#' @param package_name Character, package name
#' @return Logical, TRUE if available
#' @export
#' @examples
#' if (is_package_available("dplyr")) {
#'   library(dplyr)
#' }
is_package_available <- function(package_name) {
  requireNamespace(package_name, quietly = TRUE)
}

#' Safely source file if it exists
#'
#' SECURITY: Sources into specified environment to prevent namespace pollution
#' DEFAULT: Sources into caller's environment (parent.frame())
#'
#' @param file_path Character, path to R script
#' @param envir Environment, where to source (default: parent.frame())
#' @return Invisible NULL
#' @export
#' @examples
#' # Source a script if it exists
#' source_if_exists("optional_config.R")
#' 
#' # Source into specific environment
#' source_if_exists("helpers.R", envir = .GlobalEnv)
source_if_exists <- function(file_path, envir = parent.frame()) {
  if (file.exists(file_path)) {
    tryCatch({
      source(file_path, local = envir)
      invisible(NULL)
    }, error = function(e) {
      warning(sprintf("Failed to source %s: %s", 
                      file_path, 
                      conditionMessage(e)))
      invisible(NULL)
    })
  }
}

# Check for commonly used packages
required_packages <- c("openxlsx", "readxl", "dplyr", "tidyr")

for (pkg in required_packages) {
  if (!is_package_available(pkg)) {
    # Only show message for truly required ones
    if (pkg %in% c("openxlsx", "readxl")) {
      message(sprintf("Package '%s' not found. Install with: install.packages('%s')", 
                      pkg, pkg))
    }
  }
}

cat("Turas dependencies checked\n")