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
scan_for_projects <- function(root_dirs, max_depth = 6) {

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
find_project_dirs <- function(root, max_depth = 6) {
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

  # Smart project name: try to derive from report titles, fall back to folder name
  folder_name <- basename(dir_path)
  smart_name <- derive_project_name(turas_reports, folder_name)

  # Abbreviated path for display (show parent context)
  display_path <- abbreviate_path(dir_path)

  # Report labels for display on card
  report_labels <- vapply(turas_reports, function(r) {
    r$label %||% tools::file_path_sans_ext(r$filename %||% "")
  }, character(1))

  list(
    id = digest_path(dir_path),
    name = smart_name,
    folder_name = folder_name,
    path = dir_path,
    display_path = display_path,
    reports = turas_reports,
    report_labels = report_labels,
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


#' Derive a Meaningful Project Name from Report Titles
#'
#' Attempts to extract a common project name from report \code{<title>} tags.
#' Falls back to the folder name if no pattern is found.
#'
#' Heuristic: report titles often follow the pattern
#' "Type Report - ProjectName" or "ProjectName - Type".
#' We look for the longest common substring across report titles,
#' or use the title of the first report stripped of the type prefix.
#'
#' @param reports List of report objects (from sniff_report_type)
#' @param folder_name Fallback name (basename of directory)
#' @return Character string — the best project name
#' @keywords internal
derive_project_name <- function(reports, folder_name) {
  if (length(reports) == 0) return(folder_name)

  labels <- vapply(reports, function(r) r$label %||% "", character(1))
  labels <- labels[nzchar(labels)]

  if (length(labels) == 0) return(folder_name)

  # If only one report, try to extract project name from its title
  if (length(labels) == 1) {
    name <- strip_report_type_from_title(labels[1])
    if (nzchar(name) && name != labels[1]) return(name)
    return(labels[1])
  }

  # Multiple reports: find common prefix/substring
  # Try stripping type keywords and finding commonality
  stripped <- vapply(labels, strip_report_type_from_title, character(1))
  stripped <- stripped[nzchar(stripped)]

  if (length(stripped) >= 2) {
    # Find the longest common prefix among stripped titles
    common <- longest_common_prefix(stripped)
    common <- trimws(gsub("[_-]+$", "", common))  # Clean trailing separators
    if (nchar(common) >= 3) return(common)
  }

  # Fallback: use folder name, but clean up date-like names
  clean <- clean_folder_name(folder_name)
  return(clean)
}


#' Strip Report Type Keywords from a Title
#'
#' Removes patterns like "Tracker Report - ", "Tabs - ", etc.
#' Returns the remaining meaningful part.
#'
#' @param title Report title string
#' @return Cleaned title
#' @keywords internal
strip_report_type_from_title <- function(title) {
  if (is.null(title) || !nzchar(title)) return("")

  # Common type phrases to remove (multi-word first, then single words)
  type_phrases <- c(
    "tabs report", "tracker report", "confidence report", "maxdiff report",
    "conjoint report", "pricing report", "segment report", "segmentation report",
    "catdriver report", "keydriver report", "weighting report",
    "cat driver report", "key driver report", "categorical driver report",
    "combined report", "hub report",
    "report", "tracker", "tabs", "crosstabs", "confidence",
    "maxdiff", "conjoint", "pricing", "segment", "segmentation",
    "catdriver", "keydriver", "weighting", "combined", "hub",
    "cat driver", "key driver", "categorical driver",
    "exploration", "comparison", "unified", "simulator"
  )

  result <- title

  # Remove "Phrase - " prefixes (e.g., "Tabs Report - BrandStudy")
  for (tw in type_phrases) {
    pattern <- sprintf("^\\s*%s\\s*[-—]\\s*", tw)
    result <- gsub(pattern, "", result, ignore.case = TRUE, perl = TRUE)
  }

  # Remove " - Phrase" suffixes (e.g., "BrandStudy - Tabs Report")
  for (tw in type_phrases) {
    pattern <- sprintf("\\s*[-—]\\s*%s\\s*$", tw)
    result <- gsub(pattern, "", result, ignore.case = TRUE, perl = TRUE)
  }

  # Remove standalone type phrases
  for (tw in type_phrases) {
    pattern <- sprintf("^\\s*%s\\s*$", tw)
    if (grepl(pattern, result, ignore.case = TRUE)) {
      return("")
    }
  }

  trimws(result)
}


#' Find Longest Common Prefix of Strings
#'
#' @param strings Character vector
#' @return The longest common prefix
#' @keywords internal
longest_common_prefix <- function(strings) {
  if (length(strings) == 0) return("")
  if (length(strings) == 1) return(strings[1])

  # Compare character by character
  ref <- strings[1]
  prefix_len <- nchar(ref)

  for (s in strings[-1]) {
    max_check <- min(prefix_len, nchar(s))
    match_len <- 0
    for (i in seq_len(max_check)) {
      if (substr(ref, i, i) == substr(s, i, i)) {
        match_len <- i
      } else {
        break
      }
    }
    prefix_len <- match_len
    if (prefix_len == 0) return("")
  }

  substr(ref, 1, prefix_len)
}


#' Abbreviate a File Path for Display
#'
#' Shows the last 2-3 path components, with ~ for HOME.
#' e.g., "/Users/duncan/Documents/Projects/BrandHealth" → "~/Documents/Projects/BrandHealth"
#'
#' @param path Full path
#' @return Abbreviated path string
#' @keywords internal
abbreviate_path <- function(path) {
  if (is.null(path) || !nzchar(path)) return("")

  home <- Sys.getenv("HOME", path.expand("~"))
  home <- normalizePath(home, winslash = "/", mustWork = FALSE)
  norm_path <- normalizePath(path, winslash = "/", mustWork = FALSE)

  # Replace HOME with ~
  if (startsWith(norm_path, home)) {
    display <- paste0("~", substring(norm_path, nchar(home) + 1))
  } else {
    display <- norm_path
  }

  # If still very long, show last 3 components
  parts <- strsplit(display, "/")[[1]]
  parts <- parts[nzchar(parts)]
  if (length(parts) > 4) {
    display <- paste0(".../", paste(tail(parts, 3), collapse = "/"))
  }

  display
}


#' Clean Up a Folder Name for Display
#'
#' Replaces underscores/hyphens with spaces, title-cases if it looks
#' like a slug. Preserves date-like names but adds context.
#'
#' @param name Folder basename
#' @return Cleaned display name
#' @keywords internal
clean_folder_name <- function(name) {
  if (is.null(name) || !nzchar(name)) return("Untitled Project")

  # If it's a pure date like "2026-03-24", keep it as is
  # (the display_path will provide context)
  if (grepl("^\\d{4}-\\d{2}-\\d{2}$", name)) return(name)

  # Replace underscores and hyphens with spaces (but not in dates)
  cleaned <- gsub("_", " ", name)

  # Title case if all lowercase
  if (cleaned == tolower(cleaned)) {
    cleaned <- tools::toTitleCase(cleaned)
  }

  trimws(cleaned)
}


#' Null-coalescing operator (local)
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a
