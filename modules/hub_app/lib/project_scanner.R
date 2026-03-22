# ==============================================================================
# TURAS > HUB APP — PROJECT SCANNER
# ==============================================================================
# Scans directories for Turas project folders containing HTML reports.
# A "project" is any folder with at least one HTML file containing a
# <meta name="turas-report-type"> tag, OR containing a Hub config Excel file.
# ==============================================================================

#' Scan Directories for Turas Projects
#'
#' Searches configured root directories for folders containing Turas HTML
#' reports. Returns structured project metadata for the frontend.
#'
#' @param root_dirs Character vector of directories to scan
#' @param max_depth Maximum subdirectory depth to search (default: 3)
#' @return List with status and array of project objects
scan_for_projects <- function(root_dirs, max_depth = 3) {

  if (length(root_dirs) == 0) {
    return(list(status = "PASS", result = list(projects = list())))
  }

  projects <- list()

  for (root in root_dirs) {
    if (!dir.exists(root)) next

    # Find subdirectories containing HTML files (up to max_depth)
    candidate_dirs <- find_project_dirs(root, max_depth)

    for (dir_path in candidate_dirs) {
      project <- evaluate_project_dir(dir_path)
      if (!is.null(project)) {
        projects[[length(projects) + 1]] <- project
      }
    }
  }

  # Deduplicate by path
  seen_paths <- character(0)
  unique_projects <- list()
  for (p in projects) {
    if (!p$path %in% seen_paths) {
      seen_paths <- c(seen_paths, p$path)
      unique_projects[[length(unique_projects) + 1]] <- p
    }
  }

  # Sort by last modified (most recent first)
  if (length(unique_projects) > 0) {
    mod_times <- sapply(unique_projects, function(p) p$last_modified_ts)
    unique_projects <- unique_projects[order(mod_times, decreasing = TRUE)]
  }

  list(
    status = "PASS",
    result = list(
      projects = unique_projects,
      scan_time = Sys.time(),
      dirs_scanned = root_dirs
    ),
    message = sprintf("Found %d project(s) across %d director%s",
                       length(unique_projects),
                       length(root_dirs),
                       if (length(root_dirs) == 1) "y" else "ies")
  )
}


#' Find Candidate Project Directories
#'
#' Lists directories (up to max_depth) that contain at least one .html file.
#' Also includes the root itself if it contains HTML files.
#'
#' @param root Root directory to search
#' @param max_depth Maximum depth
#' @return Character vector of directory paths
#' @keywords internal
find_project_dirs <- function(root, max_depth = 3) {
  candidates <- character(0)

  # Check root itself
  root_html <- list.files(root, pattern = "\\.html$", ignore.case = TRUE)
  if (length(root_html) > 0) {
    candidates <- c(candidates, root)
  }

  # Walk subdirectories up to max_depth
  if (max_depth > 0) {
    subdirs <- tryCatch(
      list.dirs(root, recursive = FALSE, full.names = TRUE),
      error = function(e) character(0)
    )

    # Skip hidden directories and common non-project folders
    skip_patterns <- c("^\\.", "node_modules", "renv", "__pycache__",
                        "\\.git$", "tests$", "testthat$")
    for (subdir in subdirs) {
      base <- basename(subdir)
      if (any(sapply(skip_patterns, function(p) grepl(p, base)))) next

      # Check for HTML files in this subdirectory
      sub_html <- list.files(subdir, pattern = "\\.html$", ignore.case = TRUE)
      if (length(sub_html) > 0) {
        candidates <- c(candidates, subdir)
      }

      # Recurse one level deeper if needed
      if (max_depth > 1) {
        deeper <- find_project_dirs(subdir, max_depth - 1)
        candidates <- c(candidates, deeper)
      }
    }
  }

  unique(candidates)
}


#' Evaluate Whether a Directory Is a Turas Project
#'
#' Checks if a directory contains Turas HTML reports by looking for
#' the turas-report-type meta tag or a Hub config file.
#'
#' @param dir_path Directory to evaluate
#' @return Project object (list) if it's a Turas project, NULL otherwise
#' @keywords internal
evaluate_project_dir <- function(dir_path) {

  html_files <- list.files(
    dir_path,
    pattern = "\\.html$",
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(html_files) == 0) return(NULL)

  # Check for Hub config file (strong indicator)
  config_files <- list.files(
    dir_path,
    pattern = "Report_Hub_Config.*\\.xlsx$",
    full.names = TRUE,
    ignore.case = TRUE
  )
  has_hub_config <- length(config_files) > 0

  # Check HTML files for turas-report-type meta tag
  turas_reports <- list()
  for (html_path in html_files) {
    report_info <- sniff_report_type(html_path)
    if (!is.null(report_info)) {
      turas_reports[[length(turas_reports) + 1]] <- report_info
    }
  }

  # Skip if no Turas reports and no hub config
 if (length(turas_reports) == 0 && !has_hub_config) return(NULL)

  # Build project metadata
  all_mtimes <- file.mtime(html_files)
  last_modified <- max(all_mtimes, na.rm = TRUE)
  total_size <- sum(file.size(html_files), na.rm = TRUE)

  list(
    id = digest_path(dir_path),
    name = basename(dir_path),
    path = dir_path,
    reports = turas_reports,
    report_count = length(turas_reports),
    total_html_count = length(html_files),
    has_hub_config = has_hub_config,
    total_size = total_size,
    total_size_label = format_file_size(total_size),
    last_modified = format(last_modified, "%Y-%m-%d %H:%M"),
    last_modified_ts = as.numeric(last_modified)
  )
}


#' Sniff Report Type from HTML File
#'
#' Reads the first 100 lines of an HTML file to extract the
#' turas-report-type meta tag. Avoids reading the entire file.
#'
#' @param html_path Path to HTML file
#' @return List with path, label, type, size, last_modified; or NULL
#' @keywords internal
sniff_report_type <- function(html_path) {
  tryCatch({
    # Read only the head section (first 100 lines is generous)
    lines <- readLines(html_path, n = 100, warn = FALSE, encoding = "UTF-8")
    head_text <- paste(lines, collapse = "\n")

    # Look for turas-report-type meta tag
    type_match <- regmatches(
      head_text,
      regexpr(
        '<meta\\s+name=["\']turas-report-type["\']\\s+content=["\']([^"\']+)["\']',
        head_text,
        perl = TRUE
      )
    )

    if (length(type_match) == 0 || nchar(type_match) == 0) return(NULL)

    # Extract the content value
    report_type <- sub(
      '.*content=["\']([^"\']+)["\'].*',
      "\\1",
      type_match,
      perl = TRUE
    )

    # Try to extract a title from <title> tag
    title_match <- regmatches(
      head_text,
      regexpr("<title>([^<]+)</title>", head_text, perl = TRUE)
    )
    report_title <- if (length(title_match) > 0 && nchar(title_match) > 0) {
      sub("<title>([^<]+)</title>", "\\1", title_match, perl = TRUE)
    } else {
      tools::file_path_sans_ext(basename(html_path))
    }

    finfo <- file.info(html_path)

    list(
      path = html_path,
      filename = basename(html_path),
      label = report_title,
      type = report_type,
      size = finfo$size,
      size_label = format_file_size(finfo$size),
      last_modified = format(finfo$mtime, "%Y-%m-%d %H:%M")
    )
  }, error = function(e) {
    NULL
  })
}


#' Generate a Stable ID from a File Path
#'
#' Creates a short, URL-safe identifier from a path.
#'
#' @param path File or directory path
#' @return Character string (8-char hex digest)
#' @keywords internal
digest_path <- function(path) {
  # Simple hash: sum of character codes, formatted as hex
  chars <- utf8ToInt(path)
  hash_val <- sum(chars * seq_along(chars)) %% .Machine$integer.max
  sprintf("%08x", hash_val)
}


#' Format File Size for Display
#'
#' Converts bytes to human-readable string (KB, MB, GB).
#'
#' @param bytes Numeric file size in bytes
#' @return Character string (e.g., "2.4 MB")
#' @keywords internal
format_file_size <- function(bytes) {
  if (is.na(bytes) || bytes < 0) return("0 B")
  if (bytes < 1024) return(paste(bytes, "B"))
  if (bytes < 1024^2) return(sprintf("%.1f KB", bytes / 1024))
  if (bytes < 1024^3) return(sprintf("%.1f MB", bytes / 1024^2))
  sprintf("%.1f GB", bytes / 1024^3)
}


#' Get Detailed Report List for a Single Project
#'
#' Returns full metadata for all Turas reports in a project directory.
#' Used when a user opens a specific project.
#'
#' @param project_path Path to the project directory
#' @return List with status and report array
get_project_reports <- function(project_path) {

  if (!dir.exists(project_path)) {
    cat("\n[Hub App] ERROR: Project directory not found:", project_path, "\n")
    return(list(
      status = "REFUSED",
      code = "IO_PROJECT_NOT_FOUND",
      message = sprintf("Project directory not found: %s", project_path)
    ))
  }

  html_files <- list.files(
    project_path,
    pattern = "\\.html$",
    full.names = TRUE,
    ignore.case = TRUE
  )

  reports <- list()
  for (html_path in html_files) {
    info <- sniff_report_type(html_path)
    if (!is.null(info)) {
      reports[[length(reports) + 1]] <- info
    }
  }

  list(
    status = "PASS",
    result = list(
      project_path = project_path,
      project_name = basename(project_path),
      reports = reports,
      report_count = length(reports)
    ),
    message = sprintf("Found %d Turas report(s)", length(reports))
  )
}
