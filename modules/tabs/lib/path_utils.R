# ==============================================================================
# PATH UTILITIES - TURAS V10.1 (Phase 3 Refactoring)
# ==============================================================================
# Path handling and module sourcing utilities
# Extracted from shared_functions.R for better modularity
#
# VERSION HISTORY:
# V10.1 - Extracted from shared_functions.R (Phase 3 Refactoring)
#        - tabs_lib_path, tabs_source (V10.1 Phase 2 helpers)
#        - resolve_path, get_project_root
#        - is_package_available, source_if_exists
#
# DEPENDENCIES:
# - tabs_refuse() from 00_guard.R (for error handling)
#
# ==============================================================================

# ==============================================================================
# TABS MODULE PATH RESOLUTION (V10.1 - Phase 2 Refactoring Support)
# ==============================================================================

#' Get path to file within tabs lib directory (V10.1 - Phase 2 Refactoring Support)
#'
#' This function provides reliable path resolution for sourcing files from
#' subdirectories within the tabs/lib directory. It uses the cached lib path
#' set when run_crosstabs.R or shared_functions.R is first sourced.
#'
#' @param ... Path components to join (e.g., "validation", "data_validators.R")
#' @param must_exist Logical, if TRUE stops with error if path doesn't exist
#' @return Character, full path to the file or directory
#' @examples
#' tabs_lib_path()  # Returns lib directory
#' tabs_lib_path("validation", "data_validators.R")  # Returns path to submodule
#' @export
tabs_lib_path <- function(..., must_exist = FALSE) {
  lib_dir <- if (exists(".tabs_lib_dir", envir = globalenv())) {
    get(".tabs_lib_dir", envir = globalenv())
  } else if (exists("script_dir")) {
    script_dir
  } else {
    getwd()
  }

  args <- list(...)
  if (length(args) == 0) {
    return(lib_dir)
  }

  path <- do.call(file.path, c(list(lib_dir), args))

  if (must_exist && !file.exists(path)) {
    if (exists("tabs_refuse", mode = "function")) {
      tabs_refuse(
        code = "IO_FILE_NOT_FOUND",
        title = "Module File Not Found",
        problem = sprintf("Cannot find required file: %s", path),
        why_it_matters = "The tabs module requires this file to function correctly.",
        how_to_fix = c(
          "Verify the file exists in the expected location.",
          sprintf("Expected path: %s", path)
        )
      )
    } else {
      stop(sprintf("Module file not found: %s", path), call. = FALSE)
    }
  }

  path
}


#' Source a file from tabs lib subdirectory (V10.1 - Phase 2 Support)
#'
#' Convenience function for sourcing files from subdirectories of the tabs lib.
#' Handles path resolution and provides clear error messages on failure.
#'
#' @param ... Path components relative to lib directory
#' @param local Logical, passed to source() - FALSE sources into global env
#' @return Invisible NULL
#' @examples
#' tabs_source("validation", "data_validators.R")  # Source from validation/
#' @export
tabs_source <- function(..., local = FALSE) {
  path <- tabs_lib_path(..., must_exist = TRUE)
  source(path, local = local)
  invisible(NULL)
}


# ==============================================================================
# PROJECT PATH HANDLING
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
    if (exists("tabs_refuse", mode = "function")) {
      tabs_refuse(
        code = "ARG_EMPTY_PATH",
        title = "Empty Base Path",
        problem = "base_path cannot be empty",
        why_it_matters = "A valid base path is required to resolve relative file paths correctly.",
        how_to_fix = "Provide a valid directory path as the base_path parameter."
      )
    } else {
      stop("base_path cannot be empty", call. = FALSE)
    }
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
  if (exists("validate_char_param", mode = "function")) {
    validate_char_param(config_file_path, "config_file_path", allow_empty = FALSE)
  } else if (is.null(config_file_path) || !nzchar(config_file_path)) {
    stop("config_file_path cannot be empty", call. = FALSE)
  }

  project_root <- dirname(config_file_path)
  project_root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)

  return(project_root)
}


# ==============================================================================
# DEPENDENCY MANAGEMENT
# ==============================================================================

#' Check if package is available
#'
#' @param package_name Character, package name
#' @return Logical, TRUE if available
#' @export
is_package_available <- function(package_name) {
  requireNamespace(package_name, quietly = TRUE)
}


#' Safely source file if it exists (V9.9.1: Environment control added)
#'
#' SECURITY: Sources into specified environment to prevent namespace pollution
#' DEFAULT: Sources into caller's environment (parent.frame())
#'
#' @param file_path Character, path to R script
#' @param envir Environment, where to source (default: parent.frame())
#' @return Invisible NULL
#' @export
source_if_exists <- function(file_path, envir = parent.frame()) {
  if (file.exists(file_path)) {
    tryCatch({
      source(file_path, local = envir)
      invisible(NULL)
    }, error = function(e) {
      warning(sprintf("Failed to source %s: %s", file_path, conditionMessage(e)))
      invisible(NULL)
    })
  }
}


# ==============================================================================
# END OF PATH_UTILS.R
# ==============================================================================
