# ==============================================================================
# TURAS > HUB APP — GUARD LAYER
# ==============================================================================
# TRS v1.0 compliant input validation for the Hub App module.
# Validates project directories and configuration before launching.
# ==============================================================================

#' Validate Hub App Launch Parameters
#'
#' Checks that project directories exist and are accessible.
#' Returns a TRS-compliant result.
#'
#' @param project_dirs Character vector of directories to scan for projects
#' @return List with status ("PASS" or "REFUSED") and validated paths
guard_hub_app <- function(project_dirs = NULL) {

  # If no directories provided, use sensible defaults
  if (is.null(project_dirs) || length(project_dirs) == 0) {
    home <- Sys.getenv("HOME", path.expand("~"))
    project_dirs <- c(
      file.path(home, "Documents"),
      file.path(home, "Desktop")
    )
  }

  # Validate each directory
  valid_dirs <- character(0)
  invalid_dirs <- character(0)

 for (dir_path in project_dirs) {
    dir_path <- trimws(dir_path)
    if (!nzchar(dir_path)) next

    expanded <- tryCatch(
      normalizePath(path.expand(dir_path), winslash = "/", mustWork = FALSE),
      error = function(e) dir_path
    )

    if (dir.exists(expanded)) {
      valid_dirs <- c(valid_dirs, expanded)
    } else {
      invalid_dirs <- c(invalid_dirs, expanded)
    }
  }

  # Refuse if no valid directories at all
  if (length(valid_dirs) == 0) {
    cat("\n=== TURAS HUB APP ERROR ===\n")
    cat("Code: IO_NO_VALID_DIRS\n")
    cat("Attempted:", paste(project_dirs, collapse = ", "), "\n")
    cat("Fix: Provide at least one existing directory to scan for projects\n")
    cat("============================\n\n")

    return(list(
      status = "REFUSED",
      code = "IO_NO_VALID_DIRS",
      message = "No valid project directories found",
      how_to_fix = paste(
        "Provide at least one existing directory.",
        "Attempted:", paste(project_dirs, collapse = ", ")
      ),
      context = list(attempted = project_dirs)
    ))
  }

  # Partial pass if some directories are invalid
  warnings <- character(0)
  if (length(invalid_dirs) > 0) {
    for (d in invalid_dirs) {
      w <- sprintf("Directory not found (skipping): %s", d)
      warnings <- c(warnings, w)
      cat("[Hub App] WARNING:", w, "\n")
    }
  }

  status <- if (length(warnings) > 0) "PARTIAL" else "PASS"

  list(
    status = status,
    result = list(project_dirs = valid_dirs),
    warnings = warnings,
    message = sprintf(
      "Validated %d project director%s",
      length(valid_dirs),
      if (length(valid_dirs) == 1) "y" else "ies"
    )
  )
}


#' Validate a Single Project Path
#'
#' Checks that a project directory exists and contains HTML reports.
#'
#' @param project_path Path to a project directory
#' @return List with status and report details
guard_project <- function(project_path) {

  if (is.null(project_path) || !nzchar(trimws(project_path))) {
    return(list(
      status = "REFUSED",
      code = "IO_PROJECT_PATH_EMPTY",
      message = "Project path is empty or NULL",
      how_to_fix = "Provide a valid directory path"
    ))
  }

  if (!dir.exists(project_path)) {
    cat("\n[Hub App] ERROR: Project directory not found:", project_path, "\n")
    return(list(
      status = "REFUSED",
      code = "IO_PROJECT_NOT_FOUND",
      message = sprintf("Project directory does not exist: %s", project_path),
      how_to_fix = "Check the path and ensure the directory exists"
    ))
  }

  # Check for HTML files
  html_files <- list.files(
    project_path,
    pattern = "\\.html$",
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(html_files) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_NO_REPORTS",
      message = sprintf("No HTML report files found in: %s", project_path),
      how_to_fix = "Select a directory that contains Turas HTML reports"
    ))
  }

  list(
    status = "PASS",
    result = list(
      project_path = project_path,
      html_count = length(html_files)
    ),
    message = sprintf("Found %d HTML file(s) in project", length(html_files))
  )
}
