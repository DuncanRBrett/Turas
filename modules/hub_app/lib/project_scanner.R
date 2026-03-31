# ==============================================================================
# TURAS > HUB APP — PROJECT SCANNER
# ==============================================================================
# Scans directories for Turas project folders. A "project" is any folder
# containing at least one Turas config file (.xlsx matching module naming
# patterns) OR at least one Turas HTML report (with <meta name="turas-report-type">).
#
# Detection tiers:
#   Tier 1 — Filename pattern matching (fast, no file I/O beyond list.files)
#   Tier 2 — Sheet-name inspection for ambiguous *_Config.xlsx files
#   Tier 3 — HTML meta tag sniffing (backward compat)
#
# File categorization within a project:
#   1. Config files  — .xlsx matching module patterns (excl. templates/parsed)
#   2. HTML reports   — all .html files (turas-tagged get rich metadata)
#   3. Misc           — templates, parsed outputs, copies
#   4. Data files     — .csv; .xlsx with data/responses/raw/survey/design in name
#   5. Diagnostics    — .xlsx with stats_pack/diagnostic/validation/shap in name
#   6. Excel reports  — all remaining .xlsx
# ==============================================================================


#' Null-coalescing operator (local)
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a


# ==============================================================================
# CONFIG FILE PATTERNS — Module Detection
# ==============================================================================

#' Module Config File Patterns
#'
#' Returns a named list of module IDs to regex patterns for detecting
#' Turas config files by filename (case-insensitive).
#'
#' @return Named list: module_id -> regex pattern
#' @keywords internal
get_config_patterns <- function() {
  list(
    tabs       = "(?:crosstab_config|tabs_config|survey_structure).*\\.xlsx$",
    tracker    = "(?:tracking_config|tracker_config).*\\.xlsx$",
    maxdiff    = "(?:maxdiff|max_diff).*config.*\\.xlsx$",
    conjoint   = "(?:conjoint|cbc).*config.*\\.xlsx$",
    segment    = "segment.*config.*\\.xlsx$",
    pricing    = "(?:pricing|monadic).*config.*\\.xlsx$",
    keydriver  = "(?:keydriver|key_driver).*config.*\\.xlsx$",
    catdriver  = "(?:catdriver|categorical).*config.*\\.xlsx$",
    confidence = "confidence.*config.*\\.xlsx$",
    weighting  = "weighting.*config.*\\.xlsx$",
    report_hub = "report_hub_config.*\\.xlsx$"
  )
}


#' Module Script Paths (for launching GUIs)
#'
#' Returns a named list mapping module IDs to their GUI script paths
#' (relative to TURAS_ROOT).
#'
#' @return Named list: module_id -> script path
#' @keywords internal
get_module_scripts <- function() {
  list(
    tabs       = "modules/tabs/run_tabs_gui.R",
    tracker    = "modules/tracker/run_tracker_gui.R",
    maxdiff    = "modules/maxdiff/run_maxdiff_gui.R",
    conjoint   = "modules/conjoint/run_conjoint_gui.R",
    segment    = "modules/segment/run_segment_gui.R",
    pricing    = "modules/pricing/run_pricing_gui.R",
    keydriver  = "modules/keydriver/run_keydriver_gui.R",
    catdriver  = "modules/catdriver/run_catdriver_gui.R",
    confidence = "modules/confidence/run_confidence_gui.R",
    weighting  = "modules/weighting/run_weighting_gui.R",
    report_hub = "modules/report_hub/run_report_hub_gui.R"
  )
}


#' Module Display Labels
#'
#' @return Named list: module_id -> display label
#' @keywords internal
get_module_labels <- function() {
  list(
    tabs       = "Tabs",
    tracker    = "Tracker",
    maxdiff    = "MaxDiff",
    conjoint   = "Conjoint",
    segment    = "Segment",
    pricing    = "Pricing",
    keydriver  = "Key Driver",
    catdriver  = "Cat Driver",
    confidence = "Confidence",
    weighting  = "Weighting",
    report_hub = "Report Hub"
  )
}


# ==============================================================================
# TIER 2 — Sheet-Name Inspection for Ambiguous Configs
# ==============================================================================

#' Sheet-Name Rules for Ambiguous Config Detection
#'
#' Maps sheet-name combinations to module IDs. Used when a file matches
#' *Config*.xlsx but not a specific module pattern.
#'
#' @return List of rules: each with `sheets` (required sheets) and `module`
#' @keywords internal
get_sheet_rules <- function() {
  list(
    list(sheets = c("Settings", "Questions", "Banners"), module = "tabs"),
    list(sheets = c("Settings", "Questions", "Waves"),   module = "tracker"),
    list(sheets = c("Settings", "Items"),                module = "maxdiff"),
    list(sheets = c("Settings", "Attributes"),           module = "conjoint"),
    list(sheets = c("Settings", "Reports"),              module = "report_hub"),
    list(sheets = c("Config"),                           module = "segment")
  )
}


#' Identify Module from Sheet Names (Tier 2)
#'
#' Opens an xlsx file and checks sheet names against known combinations.
#'
#' @param file_path Path to .xlsx file
#' @return Module ID string, or NULL if no match
#' @keywords internal
identify_module_by_sheets <- function(file_path) {
  tryCatch({
    sheets <- openxlsx::getSheetNames(file_path)
    rules <- get_sheet_rules()

    for (rule in rules) {
      if (all(rule$sheets %in% sheets)) {
        return(rule$module)
      }
    }
    NULL
  }, error = function(e) {
    NULL
  })
}


# ==============================================================================
# FILE CATEGORIZATION
# ==============================================================================

#' Config File Name Patterns (broad catch-all)
#'
#' Any xlsx with "config" or "survey_structure" in its name is a config file.
#' This catches variants not matched by the specific Tier 1 module patterns
#' (e.g. Crosstab_Config_Merch.xlsx, Crosstab_Config_Short.xlsx).
#' @keywords internal
is_config_file <- function(filename) {
  grepl("(?:config|survey_structure)", filename, ignore.case = TRUE) &&
    grepl("\\.xlsx$", filename, ignore.case = TRUE) &&
    !is_misc_file(filename)
}

#' Misc File Name Patterns
#'
#' Templates, parsed outputs, and other non-actionable files.
#' These are not configs you'd run, nor data/reports/diagnostics.
#' @keywords internal
is_misc_file <- function(filename) {
  grepl("(?:template|parsed|_copy\\b)", filename, ignore.case = TRUE)
}

#' Detect Module from Config Filename
#'
#' Tries to match a config filename against module patterns. If no specific
#' pattern matches, falls back to keyword detection in the filename.
#'
#' @param filename The config filename (basename only)
#' @param patterns Named list of module patterns from get_config_patterns()
#' @return Module ID string, or NULL if no match
#' @keywords internal
detect_module_from_filename <- function(filename, patterns) {
  # Try specific Tier 1 patterns first
  for (mod_id in names(patterns)) {
    if (grepl(patterns[[mod_id]], filename, ignore.case = TRUE)) {
      return(mod_id)
    }
  }

  # Keyword fallback for common config names
  fname_lower <- tolower(filename)
  keyword_map <- list(
    tabs       = c("crosstab", "cross_tab", "survey_structure"),
    tracker    = c("tracking", "tracker"),
    maxdiff    = c("maxdiff", "max_diff"),
    conjoint   = c("conjoint", "cbc"),
    segment    = c("segment"),
    pricing    = c("pricing", "monadic"),
    keydriver  = c("keydriver", "key_driver"),
    catdriver  = c("catdriver", "categorical"),
    confidence = c("confidence"),
    weighting  = c("weighting"),
    report_hub = c("report_hub")
  )

  for (mod_id in names(keyword_map)) {
    for (kw in keyword_map[[mod_id]]) {
      if (grepl(kw, fname_lower, fixed = TRUE)) {
        return(mod_id)
      }
    }
  }

  NULL
}

#' Data File Name Patterns
#' @keywords internal
is_data_file <- function(filename) {
  grepl("(?:data|responses|raw|design)", filename, ignore.case = TRUE)
}

#' Diagnostic File Name Patterns
#' @keywords internal
is_diagnostic_file <- function(filename) {
  grepl("(?:stats_pack|diagnostic|validation|shap)", filename, ignore.case = TRUE)
}


#' Categorize All Files in a Project Directory
#'
#' Scans the project directory (and 1-2 levels of subdirectories) and
#' categorizes every relevant file. Files are assigned to exactly one
#' category based on priority order.
#'
#' @param dir_path Project root directory
#' @param config_files Character vector of already-identified config file paths
#' @param subdirs_to_skip Character vector of subdirectory paths to skip
#'   (e.g., subdirectories that are themselves separate projects)
#' @return List with categorized file lists: configs, html_reports,
#'   data_files, diagnostics, excel_reports
#' @keywords internal
categorize_project_files <- function(dir_path, config_files = character(0),
                                     subdirs_to_skip = character(0)) {
  # Normalize skip paths for comparison
  skip_norm <- normalizePath(subdirs_to_skip, winslash = "/", mustWork = FALSE)

  # Collect all files from project root + up to 2 levels of subdirectories
  all_files <- list.files(dir_path, full.names = TRUE, recursive = FALSE)

  # Also scan subdirectories (1-2 levels deep)
  subdirs <- list.dirs(dir_path, recursive = FALSE, full.names = TRUE)
  skip_dir_patterns <- c("^\\.", "node_modules", "renv", "__pycache__",
                          "\\.git$", "tests$", "testthat$")

  for (subdir in subdirs) {
    sub_norm <- normalizePath(subdir, winslash = "/", mustWork = FALSE)
    base <- basename(subdir)

    # Skip hidden/system dirs
    if (any(sapply(skip_dir_patterns, function(p) grepl(p, base)))) next
    # Skip subdirectories that are themselves projects
    if (sub_norm %in% skip_norm) next

    sub_files <- list.files(subdir, full.names = TRUE, recursive = FALSE)
    all_files <- c(all_files, sub_files)

    # Go one more level deep
    sub_subdirs <- tryCatch(
      list.dirs(subdir, recursive = FALSE, full.names = TRUE),
      error = function(e) character(0)
    )
    for (ss in sub_subdirs) {
      ss_base <- basename(ss)
      if (any(sapply(skip_dir_patterns, function(p) grepl(p, ss_base)))) next
      ss_norm <- normalizePath(ss, winslash = "/", mustWork = FALSE)
      if (ss_norm %in% skip_norm) next

      ss_files <- list.files(ss, full.names = TRUE, recursive = FALSE)
      all_files <- c(all_files, ss_files)
    }
  }

  # Remove directories from file list
  all_files <- all_files[!file.info(all_files)$isdir]

  # Normalize config file paths for comparison
  config_norm <- normalizePath(config_files, winslash = "/", mustWork = FALSE)

  # Initialize category lists
  configs <- list()
  html_reports <- list()
  data_files <- list()
  diagnostics <- list()
  excel_reports <- list()
  misc <- list()

  # Track assigned files to avoid duplicates
  assigned <- character(0)

  # --- Priority 1: Config files (already detected) ---
  for (cf in config_files) {
    if (!file.exists(cf)) next
    configs[[length(configs) + 1]] <- build_file_info(cf)
    assigned <- c(assigned, normalizePath(cf, winslash = "/", mustWork = FALSE))
  }

  # --- Priority 2: HTML reports ---
  # Include ALL .html files; turas-tagged ones get rich metadata, others get basic info
  html_files <- all_files[grepl("\\.html$", all_files, ignore.case = TRUE)]
  for (hf in html_files) {
    hf_norm <- normalizePath(hf, winslash = "/", mustWork = FALSE)
    if (hf_norm %in% assigned) next

    report_info <- sniff_report_type(hf)
    if (!is.null(report_info)) {
      # Turas report — has type + label from meta/title tags
      html_reports[[length(html_reports) + 1]] <- report_info
    } else {
      # Non-turas HTML file — still include with basic file info
      finfo <- file.info(hf)
      html_reports[[length(html_reports) + 1]] <- list(
        path          = hf,
        filename      = basename(hf),
        label         = tools::file_path_sans_ext(basename(hf)),
        type          = "html",
        size          = finfo$size,
        size_label    = format_file_size(finfo$size),
        last_modified = format(finfo$mtime, "%Y-%m-%d %H:%M")
      )
    }
    assigned <- c(assigned, hf_norm)
  }

  # --- Remaining xlsx and csv files ---
  remaining <- all_files[grepl("\\.(xlsx|csv)$", all_files, ignore.case = TRUE)]
  remaining_norm <- normalizePath(remaining, winslash = "/", mustWork = FALSE)
  remaining <- remaining[!(remaining_norm %in% assigned)]

  for (f in remaining) {
    fname <- basename(f)
    f_norm <- normalizePath(f, winslash = "/", mustWork = FALSE)
    if (f_norm %in% assigned) next

    if (grepl("\\.csv$", fname, ignore.case = TRUE)) {
      # --- Priority 3: CSV files are always data ---
      data_files[[length(data_files) + 1]] <- build_file_info(f)
      assigned <- c(assigned, f_norm)
    } else if (is_misc_file(fname)) {
      # --- Priority 2a: Misc files (templates, parsed) ---
      misc[[length(misc) + 1]] <- build_file_info(f)
      assigned <- c(assigned, f_norm)
    } else if (is_config_file(fname)) {
      # --- Priority 2b: Any xlsx with "config" or "survey_structure" in name ---
      configs[[length(configs) + 1]] <- build_file_info(f)
      assigned <- c(assigned, f_norm)
    } else if (is_data_file(fname)) {
      # --- Priority 3: xlsx data files ---
      data_files[[length(data_files) + 1]] <- build_file_info(f)
      assigned <- c(assigned, f_norm)
    } else if (is_diagnostic_file(fname)) {
      # --- Priority 4: Diagnostic files ---
      diagnostics[[length(diagnostics) + 1]] <- build_file_info(f)
      assigned <- c(assigned, f_norm)
    } else {
      # --- Priority 5: Everything else is an Excel report ---
      excel_reports[[length(excel_reports) + 1]] <- build_file_info(f)
      assigned <- c(assigned, f_norm)
    }
  }

  list(
    configs       = configs,
    html_reports  = html_reports,
    data_files    = data_files,
    diagnostics   = diagnostics,
    excel_reports = excel_reports,
    misc          = misc
  )
}


#' Build File Info Object
#'
#' @param file_path Full path to file
#' @return List with path, filename, size, size_label, last_modified
#' @keywords internal
build_file_info <- function(file_path) {
  finfo <- file.info(file_path)
  list(
    path          = file_path,
    filename      = basename(file_path),
    size          = finfo$size,
    size_label    = format_file_size(finfo$size),
    last_modified = format(finfo$mtime, "%Y-%m-%d %H:%M")
  )
}


# ==============================================================================
# PROJECT SCANNING — Main Entry Point
# ==============================================================================

#' Scan Directories for Turas Projects
#'
#' Searches configured root directories for folders containing Turas config
#' files or HTML reports. Returns structured project metadata for the frontend.
#'
#' @param root_dirs Character vector of directories to scan
#' @param max_depth Maximum subdirectory depth to search (default: 6)
#' @return List with status and array of project objects
scan_for_projects <- function(root_dirs, max_depth = 6) {

  if (length(root_dirs) == 0) {
    return(list(status = "PASS", result = list(projects = list())))
  }

  # Phase 1: Find all candidate directories
  candidate_dirs <- character(0)
  for (root in root_dirs) {
    if (!dir.exists(root)) next
    candidate_dirs <- c(candidate_dirs, find_candidate_dirs(root, max_depth))
  }
  candidate_dirs <- unique(candidate_dirs)

  # Phase 2: Evaluate each candidate — identify projects
  # We need to identify project roots first, then avoid treating their
  # subdirectories as separate projects (unless they have their own configs)
  projects <- list()
  project_paths <- character(0)

  for (dir_path in candidate_dirs) {
    # Skip if this directory is a subdirectory of an already-found project
    # (unless it has its own config files — handled inside evaluate)
    is_subdir_of_project <- any(sapply(project_paths, function(pp) {
      startsWith(
        normalizePath(dir_path, winslash = "/", mustWork = FALSE),
        paste0(normalizePath(pp, winslash = "/", mustWork = FALSE), "/")
      )
    }))

    project <- evaluate_project_dir(dir_path)
    if (!is.null(project)) {
      # If this is a subdirectory of an existing project, only keep it
      # if it has its own config files (i.e., it's a wave or sub-project)
      if (is_subdir_of_project && length(project$files$configs) == 0) {
        next
      }
      projects[[length(projects) + 1]] <- project
      project_paths <- c(project_paths, dir_path)
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
#' Lists directories (up to max_depth) that contain .xlsx or .html files.
#' These are candidates for evaluation as Turas projects.
#'
#' @param root Root directory to search
#' @param max_depth Maximum depth
#' @return Character vector of directory paths
#' @keywords internal
find_candidate_dirs <- function(root, max_depth = 6) {
  candidates <- character(0)

  # Skip patterns for directories we should never enter
  skip_patterns <- c("^\\.", "node_modules", "renv", "__pycache__",
                      "\\.git$", "tests$", "testthat$",
                      "^Library$", "^Applications$", "^\\.Trash$")

  # Check root itself
  root_files <- list.files(root, pattern = "\\.(html|xlsx)$", ignore.case = TRUE)
  if (length(root_files) > 0) {
    candidates <- c(candidates, root)
  }

  # Walk subdirectories up to max_depth
  if (max_depth > 0) {
    subdirs <- tryCatch(
      list.dirs(root, recursive = FALSE, full.names = TRUE),
      error = function(e) character(0)
    )

    for (subdir in subdirs) {
      base <- basename(subdir)
      if (any(sapply(skip_patterns, function(p) grepl(p, base)))) next

      # Check for relevant files in this subdirectory
      sub_files <- list.files(subdir, pattern = "\\.(html|xlsx)$",
                               ignore.case = TRUE)
      if (length(sub_files) > 0) {
        candidates <- c(candidates, subdir)
      }

      # Recurse deeper
      if (max_depth > 1) {
        deeper <- find_candidate_dirs(subdir, max_depth - 1)
        candidates <- c(candidates, deeper)
      }
    }
  }

  unique(candidates)
}


# ==============================================================================
# PROJECT EVALUATION — Core Detection Logic
# ==============================================================================

#' Evaluate Whether a Directory Is a Turas Project
#'
#' Uses a tiered detection approach:
#'   Tier 1: Config filename patterns (fast)
#'   Tier 2: Sheet-name inspection for ambiguous configs
#'   Tier 3: HTML meta tag sniffing
#'
#' @param dir_path Directory to evaluate
#' @return Project object (list) if it's a Turas project, NULL otherwise
#' @keywords internal
evaluate_project_dir <- function(dir_path) {

  # --- Tier 1: Detect config files by filename pattern ---
  config_patterns <- get_config_patterns()
  xlsx_files <- list.files(dir_path, pattern = "\\.xlsx$",
                            full.names = TRUE, ignore.case = TRUE)
  config_files <- character(0)
  config_modules <- character(0)

  for (xlsx_path in xlsx_files) {
    fname <- basename(xlsx_path)
    matched <- FALSE

    # Skip templates and parsed files — these are not runnable configs
    if (is_misc_file(fname)) next

    for (module_id in names(config_patterns)) {
      if (grepl(config_patterns[[module_id]], fname, ignore.case = TRUE)) {
        config_files <- c(config_files, xlsx_path)
        config_modules <- c(config_modules, module_id)
        matched <- TRUE
        break
      }
    }

    # --- Tier 2: Ambiguous config — try sheet inspection ---
    if (!matched && grepl("config", fname, ignore.case = TRUE)) {
      module_id <- identify_module_by_sheets(xlsx_path)
      if (!is.null(module_id)) {
        config_files <- c(config_files, xlsx_path)
        config_modules <- c(config_modules, module_id)
      }
    }
  }

  has_configs <- length(config_files) > 0

  # --- Tier 3: Check HTML files for turas-report-type meta tag ---
  html_files <- list.files(dir_path, pattern = "\\.html$",
                            full.names = TRUE, ignore.case = TRUE)
  turas_reports <- list()
  for (html_path in html_files) {
    report_info <- sniff_report_type(html_path)
    if (!is.null(report_info)) {
      turas_reports[[length(turas_reports) + 1]] <- report_info
    }
  }

  has_reports <- length(turas_reports) > 0

  # Must have at least one config or one report to qualify
 if (!has_configs && !has_reports) return(NULL)

  # --- Categorize all files in the project ---
  # Find subdirectories that are themselves projects (to skip during file scan)
  subdirs <- tryCatch(
    list.dirs(dir_path, recursive = FALSE, full.names = TRUE),
    error = function(e) character(0)
  )
  child_project_dirs <- character(0)
  for (sd in subdirs) {
    sd_xlsx <- list.files(sd, pattern = "\\.xlsx$", ignore.case = TRUE)
    for (f in sd_xlsx) {
      for (pattern in config_patterns) {
        if (grepl(pattern, f, ignore.case = TRUE)) {
          child_project_dirs <- c(child_project_dirs, sd)
          break
        }
      }
      if (sd %in% child_project_dirs) break
    }
  }

  files <- categorize_project_files(dir_path, config_files, child_project_dirs)

  # Add module info to config file entries
  labels <- get_module_labels()
  scripts <- get_module_scripts()

  if (length(files$configs) > 0) {
    for (i in seq_along(files$configs)) {
      cfg_path <- files$configs[[i]]$path
      cfg_norm <- normalizePath(cfg_path, winslash = "/", mustWork = FALSE)

      # First check if this was a Tier 1 match
      idx <- match(cfg_norm,
        normalizePath(config_files, winslash = "/", mustWork = FALSE)
      )
      if (!is.na(idx)) {
        mod_id <- config_modules[idx]
        files$configs[[i]]$module <- mod_id
        files$configs[[i]]$module_label <- labels[[mod_id]] %||% mod_id
        files$configs[[i]]$script <- scripts[[mod_id]] %||% NULL
      } else {
        # Broad config catch-all — try to match module by pattern first
        fname <- basename(cfg_path)
        mod_id <- detect_module_from_filename(fname, config_patterns)

        # If filename doesn't reveal the module, try Tier 2 sheet inspection
        if (is.null(mod_id) && grepl("\\.xlsx$", fname, ignore.case = TRUE)) {
          mod_id <- identify_module_by_sheets(cfg_path)
        }

        if (!is.null(mod_id)) {
          files$configs[[i]]$module <- mod_id
          files$configs[[i]]$module_label <- labels[[mod_id]] %||% mod_id
          files$configs[[i]]$script <- scripts[[mod_id]] %||% NULL
        }
      }
    }
  }

  # --- Derive project metadata ---
  folder_name <- basename(dir_path)

  # Modules detected (from configs + reports + broad-catch configs)
  # Start with Tier 1/2 config modules
  all_modules <- config_modules

  # Add modules from HTML report types
  if (length(turas_reports) > 0) {
    report_mods <- vapply(turas_reports, function(r) {
      rtype <- tolower(r$type %||% "")
      sub("-.*$", "", rtype)
    }, character(1))
    all_modules <- c(all_modules, report_mods)
  }

  # Add modules from broad-catch configs (detected by is_config_file in categorize)
  if (length(files$configs) > 0) {
    for (cfg in files$configs) {
      if (!is.null(cfg$module) && nzchar(cfg$module)) {
        all_modules <- c(all_modules, cfg$module)
      }
    }
  }

  modules <- unique(all_modules)
  modules <- modules[nzchar(modules)]

  # Project name: try from report titles, then config filenames, then folder
  smart_name <- derive_project_name(turas_reports, config_files, folder_name)

  # Full display path (with ~ for HOME, NOT truncated)
  display_path <- full_display_path(dir_path)

  # Read project note if .turas_project.json exists
  note <- read_project_note(dir_path)

  # Compute counts
  counts <- list(
    configs       = length(files$configs),
    html_reports  = length(files$html_reports),
    excel_reports = length(files$excel_reports),
    data_files    = length(files$data_files),
    diagnostics   = length(files$diagnostics),
    misc          = length(files$misc)
  )

  # Last modified across all files
  all_file_paths <- c(
    vapply(files$configs, function(f) f$path, character(1)),
    vapply(files$html_reports, function(f) f$path, character(1)),
    vapply(files$excel_reports, function(f) f$path, character(1)),
    vapply(files$data_files, function(f) f$path, character(1)),
    vapply(files$diagnostics, function(f) f$path, character(1)),
    vapply(files$misc, function(f) f$path, character(1))
  )
  if (length(all_file_paths) == 0) all_file_paths <- dir_path
  all_mtimes <- file.mtime(all_file_paths)
  last_modified <- max(all_mtimes, na.rm = TRUE)

  # Derived convenience fields for reports
  has_hub_config <- "report_hub" %in% modules

  list(
    id              = digest_path(dir_path),
    name            = smart_name,
    folder_name     = folder_name,
    path            = dir_path,
    display_path    = display_path,
    note            = note,
    modules         = modules,
    files           = files,
    counts          = counts,
    reports         = turas_reports,
    report_count    = length(turas_reports),
    total_html_count = length(html_files),
    has_hub_config  = has_hub_config,
    last_modified   = format(last_modified, "%Y-%m-%d %H:%M"),
    last_modified_ts = as.numeric(last_modified)
  )
}


# ==============================================================================
# HTML REPORT SNIFFING
# ==============================================================================

#' Sniff Report Type from HTML File
#'
#' Reads the first 100 lines of an HTML file to extract the
#' turas-report-type meta tag. Avoids reading the entire file.
#'
#' @param html_path Path to HTML file
#' @return List with path, filename, label, type, size, size_label,
#'   last_modified; or NULL if not a Turas report
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
      path          = html_path,
      filename      = basename(html_path),
      label         = report_title,
      type          = report_type,
      size          = finfo$size,
      size_label    = format_file_size(finfo$size),
      last_modified = format(finfo$mtime, "%Y-%m-%d %H:%M")
    )
  }, error = function(e) {
    NULL
  })
}


# ==============================================================================
# PROJECT REPORTS — Detailed View
# ==============================================================================

#' Get Detailed Report List for a Single Project
#'
#' Returns full metadata for all Turas reports in a project directory
#' (including subdirectories). Used when a user opens a specific project.
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

  # Look in root + subdirectories (up to 2 levels)
  html_files <- list.files(
    project_path,
    pattern = "\\.html$",
    full.names = TRUE,
    ignore.case = TRUE,
    recursive = TRUE
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


# ==============================================================================
# PROJECT NOTES — .turas_project.json Sidecar
# ==============================================================================

#' Read Project Note
#'
#' Reads the note field from .turas_project.json if it exists.
#'
#' @param project_path Project directory path
#' @return Character string (note text) or empty string
#' @keywords internal
read_project_note <- function(project_path) {
  note_file <- file.path(project_path, ".turas_project.json")
  if (!file.exists(note_file)) return("")

  tryCatch({
    data <- jsonlite::fromJSON(note_file, simplifyVector = FALSE)
    data$note %||% ""
  }, error = function(e) {
    ""
  })
}


#' Save Project Note
#'
#' Writes or updates .turas_project.json with the given note.
#'
#' @param project_path Project directory path
#' @param note Character string — the note text
#' @return List with status
save_project_note <- function(project_path, note) {
  note_file <- file.path(project_path, ".turas_project.json")

  tryCatch({
    # Read existing data if file exists (preserve other fields)
    existing <- list()
    if (file.exists(note_file)) {
      existing <- tryCatch(
        jsonlite::fromJSON(note_file, simplifyVector = FALSE),
        error = function(e) list()
      )
    }

    existing$note <- note
    existing$updated <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")

    json_out <- jsonlite::toJSON(existing, auto_unbox = TRUE, pretty = TRUE)
    writeLines(json_out, note_file)

    list(status = "PASS", message = "Note saved")
  }, error = function(e) {
    cat("[Hub App] ERROR saving project note:", e$message, "\n")
    list(
      status = "REFUSED",
      code = "IO_WRITE_FAILED",
      message = paste("Failed to save project note:", e$message)
    )
  })
}


# ==============================================================================
# NAME DERIVATION
# ==============================================================================

#' Derive a Meaningful Project Name
#'
#' Attempts to extract a common project name from report titles or config
#' file names. Falls back to the folder name.
#'
#' @param reports List of report objects (from sniff_report_type)
#' @param config_files Character vector of config file paths
#' @param folder_name Fallback name (basename of directory)
#' @return Character string — the best project name
#' @keywords internal
derive_project_name <- function(reports, config_files = character(0),
                                 folder_name = "Untitled") {
  # Try report titles first
  if (length(reports) > 0) {
    labels <- vapply(reports, function(r) r$label %||% "", character(1))
    labels <- labels[nzchar(labels)]

    if (length(labels) == 1) {
      name <- strip_report_type_from_title(labels[1])
      if (nzchar(name) && name != labels[1]) return(name)
      return(labels[1])
    }

    if (length(labels) >= 2) {
      stripped <- vapply(labels, strip_report_type_from_title, character(1))
      stripped <- stripped[nzchar(stripped)]

      if (length(stripped) >= 2) {
        common <- longest_common_prefix(stripped)
        common <- trimws(gsub("[_-]+$", "", common))
        if (nchar(common) >= 3) return(common)
      }
    }
  }

  # Try config file names
  if (length(config_files) > 0) {
    cfg_names <- tools::file_path_sans_ext(basename(config_files))
    # Strip module-type keywords
    cleaned <- vapply(cfg_names, function(n) {
      n <- gsub("(?:Crosstab|Tabs|Tracker|Tracking|MaxDiff|Max_Diff|Conjoint|CBC|Segment|Pricing|KeyDriver|Key_Driver|CatDriver|Categorical|Confidence|Weighting|Report_Hub|Survey_Structure)[_-]?",
                "", n, ignore.case = TRUE)
      n <- gsub("[_-]?(?:Config|Configuration)$", "", n, ignore.case = TRUE)
      trimws(gsub("[_-]+", " ", n))
    }, character(1))
    cleaned <- cleaned[nzchar(cleaned)]

    if (length(cleaned) == 1) return(cleaned)

    if (length(cleaned) >= 2) {
      common <- longest_common_prefix(cleaned)
      common <- trimws(gsub("[_-]+$", "", common))
      if (nchar(common) >= 3) return(common)
    }
  }

  # Fallback: folder name
  clean_folder_name(folder_name)
}


#' Strip Report Type Keywords from a Title
#'
#' Removes patterns like "Tracker Report - ", "Tabs - ", etc.
#'
#' @param title Report title string
#' @return Cleaned title
#' @keywords internal
strip_report_type_from_title <- function(title) {
  if (is.null(title) || !nzchar(title)) return("")

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

  for (tw in type_phrases) {
    pattern <- sprintf("^\\s*%s\\s*[-\u2014]\\s*", tw)
    result <- gsub(pattern, "", result, ignore.case = TRUE, perl = TRUE)
  }

  for (tw in type_phrases) {
    pattern <- sprintf("\\s*[-\u2014]\\s*%s\\s*$", tw)
    result <- gsub(pattern, "", result, ignore.case = TRUE, perl = TRUE)
  }

  for (tw in type_phrases) {
    pattern <- sprintf("^\\s*%s\\s*$", tw)
    if (grepl(pattern, result, ignore.case = TRUE)) {
      return("")
    }
  }

  trimws(result)
}


# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

#' Find Longest Common Prefix of Strings
#'
#' @param strings Character vector
#' @return The longest common prefix
#' @keywords internal
longest_common_prefix <- function(strings) {
  if (length(strings) == 0) return("")
  if (length(strings) == 1) return(strings[1])

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


#' Full Display Path (NOT Truncated)
#'
#' Replaces HOME with ~ but does NOT truncate. The full path is always shown.
#'
#' @param path Full path
#' @return Display path string
#' @keywords internal
full_display_path <- function(path) {
  if (is.null(path) || !nzchar(path)) return("")

  home <- Sys.getenv("HOME", path.expand("~"))
  home <- normalizePath(home, winslash = "/", mustWork = FALSE)
  norm_path <- normalizePath(path, winslash = "/", mustWork = FALSE)

  if (startsWith(norm_path, home)) {
    paste0("~", substring(norm_path, nchar(home) + 1))
  } else {
    norm_path
  }
}


#' Generate a Stable ID from a File Path
#'
#' Creates a short, URL-safe identifier from a path.
#'
#' @param path File or directory path
#' @return Character string (8-char hex digest)
#' @keywords internal
digest_path <- function(path) {
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


#' Clean Up a Folder Name for Display
#'
#' Replaces underscores/hyphens with spaces, title-cases if it looks
#' like a slug.
#'
#' @param name Folder basename
#' @return Cleaned display name
#' @keywords internal
clean_folder_name <- function(name) {
  if (is.null(name) || !nzchar(name)) return("Untitled Project")

  if (grepl("^\\d{4}-\\d{2}-\\d{2}$", name)) return(name)

  cleaned <- gsub("_", " ", name)

  if (cleaned == tolower(cleaned)) {
    cleaned <- tools::toTitleCase(cleaned)
  }

  trimws(cleaned)
}
