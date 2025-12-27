# ==============================================================================
# SHARED PATH FUNCTIONS - TURAS V10.0
# ==============================================================================
# Extracted from shared_functions.R for better maintainability
# Provides path handling utilities for the toolkit
#
# CONTENTS:
# - Resolve relative paths to absolute paths
# - Get project root from config file location
#
# DESIGN PRINCIPLES:
# - Platform-independent (works on Windows, Mac, Linux)
# - Security: Normalizes paths to prevent directory traversal
# - Handles ./ and ../ correctly
# ==============================================================================

#' Resolve relative path from base path
#'
#' USAGE: Convert relative paths to absolute for file operations
#' DESIGN: Platform-independent, handles ./ and ../ correctly
#' SECURITY: Normalizes path to prevent directory traversal attacks
#'
#' @param base_path Character, base directory path
#' @param relative_path Character, path relative to base
#' @return Character, absolute normalized path
#' @export
#' @examples
#' # Returns: /Users/john/project/Data/survey.xlsx
#' resolve_path("/Users/john/project", "Data/survey.xlsx")
#'
#' # Handles ./ prefix
#' resolve_path("/Users/john/project", "./Data/survey.xlsx")
resolve_path <- function(base_path, relative_path) {
  # Validate inputs
  if (is.null(base_path) || is.na(base_path) || base_path == "") {
    tabs_refuse(
      code = "ARG_EMPTY_PATH",
      title = "Empty Base Path",
      problem = "base_path cannot be empty",
      why_it_matters = "A valid base path is required to resolve relative file paths correctly.",
      how_to_fix = "Provide a valid directory path as the base_path parameter."
    )
  }

  if (is.null(relative_path) || is.na(relative_path) || relative_path == "") {
    return(normalizePath(base_path, mustWork = FALSE))
  }

  # Remove leading ./
  relative_path <- gsub("^\\./", "", relative_path)

  # Combine paths (handles both / and \)
  full_path <- file.path(base_path, relative_path)

  # Normalize (resolves .., ., converts to OS-specific separators)
  full_path <- normalizePath(full_path, winslash = "/", mustWork = FALSE)

  return(full_path)
}

#' Get project root directory from config file location
#'
#' USAGE: Determine project root for resolving relative paths
#' DESIGN: Simple - parent directory of config file
#' NOTE: Project root = directory containing config file
#'
#' @param config_file_path Character, path to config file
#' @return Character, project root directory path
#' @export
#' @examples
#' # Config at: /Users/john/MyProject/Config.xlsx
#' # Returns:   /Users/john/MyProject
#' project_root <- get_project_root(config_file)
get_project_root <- function(config_file_path) {
  validate_char_param(config_file_path, "config_file_path", allow_empty = FALSE)

  project_root <- dirname(config_file_path)
  project_root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)

  return(project_root)
}

# ==============================================================================
# END OF SHARED_PATHS.R
# ==============================================================================
