# ==============================================================================
# REPORT HUB - PREFLIGHT VALIDATORS
# ==============================================================================
# Cross-referential validation between config and actual report files.
# Catches configuration mistakes before the combine_reports() pipeline runs.
#
# These validators go BEYOND the guard layer (00_guard.R) which checks
# structural validity. Preflight checks verify the actual content of
# report files and cross-reference mappings.
#
# VERSION: 1.0
# DATE: 2026-03-08
#
# DEPENDENCIES:
# - log_issue() from modules/shared/lib/logging_utils.R
# - create_error_log() from modules/shared/lib/logging_utils.R
#
# FUNCTIONS EXPORTED:
# - check_report_files_readable()     - HTML files can be read and parsed
# - check_report_type_detection()     - Report types can be auto-detected
# - check_report_key_format()         - Report keys are valid identifiers
# - check_duplicate_report_keys()     - No duplicate keys
# - check_duplicate_report_paths()    - No duplicate file paths
# - check_report_order_gaps()         - Order values are sequential
# - check_crossref_codes_in_tracker() - CrossRef tracker codes exist in report
# - check_crossref_codes_in_tabs()    - CrossRef tabs codes exist in report
# - check_crossref_completeness()     - CrossRef covers key questions
# - check_report_compatibility()      - Reports use compatible Turas versions
# - check_logo_file_valid()           - Logo file is a valid image
# - check_colour_codes_valid()        - Brand/accent colours are valid hex
# - check_output_dir_writable()       - Output directory is writable
# - check_report_file_sizes()         - Report files not suspiciously small/large
# - validate_report_hub_preflight()   - Main orchestrator
# ==============================================================================


# ==============================================================================
# UTILITY: Create error log if not available from shared
# ==============================================================================

.hub_create_error_log <- function() {
  if (exists("create_error_log", mode = "function")) {
    return(create_error_log())
  }
  data.frame(
    Check = character(0),
    Issue = character(0),
    Detail = character(0),
    Context = character(0),
    Severity = character(0),
    stringsAsFactors = FALSE
  )
}

.hub_log_issue <- function(error_log, check, issue, detail, context = "", severity = "Error") {
  if (exists("log_issue", mode = "function")) {
    return(log_issue(error_log, check, issue, detail, context, severity))
  }
  rbind(error_log, data.frame(
    Check = check,
    Issue = issue,
    Detail = detail,
    Context = context,
    Severity = severity,
    stringsAsFactors = FALSE
  ))
}


# ==============================================================================
# CHECK 1: Report files are readable HTML
# ==============================================================================

#' Check Report Files Are Readable
#'
#' Verifies each report file can be read and contains valid HTML structure.
#' Goes beyond the guard's file.exists() check to verify content.
#'
#' @param reports_df Data frame from Reports sheet (with resolved paths)
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_report_files_readable <- function(reports_df, error_log) {

  for (i in seq_len(nrow(reports_df))) {
    path <- reports_df$resolved_path[i]
    label <- reports_df$report_label[i]

    if (is.na(path) || !file.exists(path)) {
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Report File Missing",
        sprintf("Report '%s' file not found: %s", label, path %||% "(NA)"),
        label, "Error"
      )
      next
    }

    # Try to read the file
    content <- tryCatch(
      readLines(path, warn = FALSE, n = 50),
      error = function(e) NULL
    )

    if (is.null(content)) {
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Report File Unreadable",
        sprintf("Cannot read report '%s': %s. File may be corrupted or locked.", label, path),
        label, "Error"
      )
      next
    }

    # Check for basic HTML structure
    combined <- paste(content, collapse = "\n")
    if (!grepl("<html|<!DOCTYPE", combined, ignore.case = TRUE)) {
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Not Valid HTML",
        sprintf("Report '%s' does not appear to be a valid HTML file: %s", label, path),
        label, "Error"
      )
    }
  }

  error_log
}


# ==============================================================================
# CHECK 2: Report type detection
# ==============================================================================

#' Check Report Type Detection
#'
#' Verifies that report types can be auto-detected from meta tags or
#' structural markers. Warns if detection may fail at runtime.
#'
#' @param reports_df Data frame from Reports sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_report_type_detection <- function(reports_df, error_log) {

  for (i in seq_len(nrow(reports_df))) {
    path <- reports_df$resolved_path[i]
    label <- reports_df$report_label[i]
    explicit_type <- if ("report_type" %in% names(reports_df)) reports_df$report_type[i] else NA

    # Skip if type is explicitly set in config
    if (!is.na(explicit_type) && nzchar(trimws(explicit_type))) {
      valid_types <- c("tracker", "tabs")
      if (!tolower(trimws(explicit_type)) %in% valid_types) {
        error_log <- .hub_log_issue(
          error_log, "Preflight", "Invalid Report Type",
          sprintf("Report '%s' has report_type='%s'. Valid types: %s",
                  label, explicit_type, paste(valid_types, collapse = ", ")),
          label, "Error"
        )
      }
      next
    }

    # Try auto-detection
    if (!file.exists(path)) next

    content <- tryCatch(
      paste(readLines(path, warn = FALSE, n = 200), collapse = "\n"),
      error = function(e) ""
    )

    has_meta <- grepl('turas-report-type', content, ignore.case = TRUE)
    has_tracker_marker <- grepl('id="tab-metrics"', content, fixed = TRUE)
    has_tabs_marker <- grepl('id="tab-crosstabs"', content, fixed = TRUE)

    if (!has_meta && !has_tracker_marker && !has_tabs_marker) {
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Cannot Auto-Detect Report Type",
        sprintf("Report '%s' has no report_type set and no auto-detection markers found. Set report_type column to 'tracker' or 'tabs'.",
                label),
        label, "Warning"
      )
    }
  }

  error_log
}


# ==============================================================================
# CHECK 3: Report key format
# ==============================================================================

#' Check Report Key Format
#'
#' Validates report_key values are safe for use in HTML IDs, CSS selectors,
#' and JavaScript variable names.
#'
#' @param reports_df Data frame from Reports sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_report_key_format <- function(reports_df, error_log) {

  for (i in seq_len(nrow(reports_df))) {
    key <- reports_df$report_key[i]
    label <- reports_df$report_label[i]

    if (is.na(key) || !nzchar(trimws(key))) {
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Empty Report Key",
        sprintf("Report row %d ('%s'): report_key is empty", i, label),
        label, "Error"
      )
      next
    }

    key <- trimws(key)

    # Must start with a letter
    if (!grepl("^[a-zA-Z]", key)) {
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Invalid Report Key Start",
        sprintf("Report '%s': report_key '%s' must start with a letter", label, key),
        key, "Error"
      )
    }

    # Only alphanumeric, hyphens, underscores
    if (!grepl("^[a-zA-Z][a-zA-Z0-9_-]*$", key)) {
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Invalid Report Key Characters",
        sprintf("Report '%s': report_key '%s' contains invalid characters. Use only letters, numbers, hyphens, underscores.",
                label, key),
        key, "Error"
      )
    }

    # Warn about very long keys (they become DOM ID prefixes)
    if (nchar(key) > 30) {
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Long Report Key",
        sprintf("Report '%s': report_key '%s' is %d characters. Consider shortening for cleaner DOM IDs.",
                label, key, nchar(key)),
        key, "Warning"
      )
    }
  }

  error_log
}


# ==============================================================================
# CHECK 4: Duplicate report keys
# ==============================================================================

#' Check Duplicate Report Keys
#'
#' @param reports_df Data frame from Reports sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_duplicate_report_keys <- function(reports_df, error_log) {
  keys <- trimws(reports_df$report_key)
  keys <- keys[!is.na(keys) & nzchar(keys)]

  if (any(duplicated(keys))) {
    dupes <- unique(keys[duplicated(keys)])
    error_log <- .hub_log_issue(
      error_log, "Preflight", "Duplicate Report Keys",
      sprintf("Duplicate report_key values found: %s. Each report must have a unique key.",
              paste(dupes, collapse = ", ")),
      paste(dupes, collapse = ", "), "Error"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 5: Duplicate report paths
# ==============================================================================

#' Check Duplicate Report Paths
#'
#' @param reports_df Data frame from Reports sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_duplicate_report_paths <- function(reports_df, error_log) {
  paths <- reports_df$resolved_path
  paths <- paths[!is.na(paths) & nzchar(paths)]

  if (any(duplicated(paths))) {
    dupes <- unique(basename(paths[duplicated(paths)]))
    error_log <- .hub_log_issue(
      error_log, "Preflight", "Duplicate Report Paths",
      sprintf("Same report file listed multiple times: %s. Each row should reference a different HTML report.",
              paste(dupes, collapse = ", ")),
      paste(dupes, collapse = ", "), "Warning"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 6: Report order gaps
# ==============================================================================

#' Check Report Order Gaps
#'
#' Validates order values are reasonable (sequential, no duplicates).
#'
#' @param reports_df Data frame from Reports sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_report_order_gaps <- function(reports_df, error_log) {
  orders <- reports_df$order
  orders <- orders[!is.na(orders)]

  if (length(orders) == 0) return(error_log)

  # Check for duplicate order values
  if (any(duplicated(orders))) {
    dupes <- unique(orders[duplicated(orders)])
    error_log <- .hub_log_issue(
      error_log, "Preflight", "Duplicate Order Values",
      sprintf("Duplicate order values: %s. Reports with the same order may display in unpredictable sequence.",
              paste(dupes, collapse = ", ")),
      paste(dupes, collapse = ", "), "Warning"
    )
  }

  # Check for non-positive order values
  if (any(orders <= 0)) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "Non-Positive Order",
      "Order values should be positive integers (1, 2, 3...).",
      paste(orders[orders <= 0], collapse = ", "), "Warning"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 7: CrossRef tracker codes in report
# ==============================================================================

#' Check CrossRef Tracker Codes Exist in Report
#'
#' If CrossRef sheet is present, verifies tracker_code values appear as
#' question codes in the tracker HTML report.
#'
#' @param crossref_df Data frame from CrossRef sheet (or NULL)
#' @param reports_df Data frame from Reports sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_crossref_codes_in_tracker <- function(crossref_df, reports_df, error_log) {

  if (is.null(crossref_df) || nrow(crossref_df) == 0) return(error_log)

  # Find tracker report
  tracker_idx <- which(
    (!is.na(reports_df$report_type) & tolower(reports_df$report_type) == "tracker") |
    (!is.na(reports_df$report_key) & tolower(reports_df$report_key) == "tracker")
  )

  if (length(tracker_idx) == 0) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "CrossRef Without Tracker",
      "CrossRef sheet has entries but no tracker-type report found in Reports sheet.",
      "", "Warning"
    )
    return(error_log)
  }

  tracker_path <- reports_df$resolved_path[tracker_idx[1]]
  if (!file.exists(tracker_path)) return(error_log)

  # Read tracker HTML and extract question codes
  tracker_html <- tryCatch(
    paste(readLines(tracker_path, warn = FALSE), collapse = "\n"),
    error = function(e) ""
  )

  # Look for question codes in data attributes or panel IDs
  tracker_codes <- character(0)
  code_matches <- gregexpr('data-question-code="([^"]+)"', tracker_html, perl = TRUE)
  if (code_matches[[1]][1] > 0) {
    tracker_codes <- regmatches(tracker_html, code_matches)[[1]]
    tracker_codes <- gsub('data-question-code="([^"]+)"', "\\1", tracker_codes, perl = TRUE)
  }

  # Also check panel IDs
  panel_matches <- gregexpr('id="panel-([^"]+)"', tracker_html, perl = TRUE)
  if (panel_matches[[1]][1] > 0) {
    panel_ids <- regmatches(tracker_html, panel_matches)[[1]]
    panel_ids <- gsub('id="panel-([^"]+)"', "\\1", panel_ids, perl = TRUE)
    tracker_codes <- unique(c(tracker_codes, panel_ids))
  }

  if (length(tracker_codes) == 0) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "Cannot Extract Tracker Codes",
      "Could not extract question codes from tracker report. CrossRef validation skipped.",
      tracker_path, "Info"
    )
    return(error_log)
  }

  # Check each CrossRef tracker_code
  missing <- setdiff(crossref_df$tracker_code, tracker_codes)
  if (length(missing) > 0) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "CrossRef Tracker Code Not Found",
      sprintf("%d CrossRef tracker_code(s) not found in tracker report: %s",
              length(missing), paste(missing, collapse = ", ")),
      paste(missing, collapse = ", "), "Warning"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 8: CrossRef tabs codes in report
# ==============================================================================

#' Check CrossRef Tabs Codes Exist in Report
#'
#' @param crossref_df Data frame from CrossRef sheet (or NULL)
#' @param reports_df Data frame from Reports sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_crossref_codes_in_tabs <- function(crossref_df, reports_df, error_log) {

  if (is.null(crossref_df) || nrow(crossref_df) == 0) return(error_log)

  # Find tabs report
  tabs_idx <- which(
    (!is.na(reports_df$report_type) & tolower(reports_df$report_type) == "tabs") |
    (!is.na(reports_df$report_key) & tolower(reports_df$report_key) == "tabs")
  )

  if (length(tabs_idx) == 0) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "CrossRef Without Tabs Report",
      "CrossRef sheet has entries but no tabs-type report found in Reports sheet.",
      "", "Warning"
    )
    return(error_log)
  }

  tabs_path <- reports_df$resolved_path[tabs_idx[1]]
  if (!file.exists(tabs_path)) return(error_log)

  # Read tabs HTML and extract question codes
  tabs_html <- tryCatch(
    paste(readLines(tabs_path, warn = FALSE), collapse = "\n"),
    error = function(e) ""
  )

  tabs_codes <- character(0)
  code_matches <- gregexpr('data-question-code="([^"]+)"', tabs_html, perl = TRUE)
  if (code_matches[[1]][1] > 0) {
    tabs_codes <- regmatches(tabs_html, code_matches)[[1]]
    tabs_codes <- gsub('data-question-code="([^"]+)"', "\\1", tabs_codes, perl = TRUE)
  }

  panel_matches <- gregexpr('id="panel-([^"]+)"', tabs_html, perl = TRUE)
  if (panel_matches[[1]][1] > 0) {
    panel_ids <- regmatches(tabs_html, panel_matches)[[1]]
    panel_ids <- gsub('id="panel-([^"]+)"', "\\1", panel_ids, perl = TRUE)
    tabs_codes <- unique(c(tabs_codes, panel_ids))
  }

  if (length(tabs_codes) == 0) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "Cannot Extract Tabs Codes",
      "Could not extract question codes from tabs report. CrossRef validation skipped.",
      tabs_path, "Info"
    )
    return(error_log)
  }

  missing <- setdiff(crossref_df$tabs_code, tabs_codes)
  if (length(missing) > 0) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "CrossRef Tabs Code Not Found",
      sprintf("%d CrossRef tabs_code(s) not found in tabs report: %s",
              length(missing), paste(missing, collapse = ", ")),
      paste(missing, collapse = ", "), "Warning"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 9: CrossRef completeness
# ==============================================================================

#' Check CrossRef Mapping Completeness
#'
#' If both tracker and tabs reports exist and CrossRef sheet is provided,
#' check whether there are unmapped questions that could benefit from
#' cross-referencing.
#'
#' @param crossref_df Data frame from CrossRef sheet (or NULL)
#' @param reports_df Data frame from Reports sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_crossref_completeness <- function(crossref_df, reports_df, error_log) {

  # Only relevant when both tracker and tabs reports exist
  has_tracker <- any(
    (!is.na(reports_df$report_type) & tolower(reports_df$report_type) == "tracker") |
    (!is.na(reports_df$report_key) & tolower(reports_df$report_key) == "tracker")
  )
  has_tabs <- any(
    (!is.na(reports_df$report_type) & tolower(reports_df$report_type) == "tabs") |
    (!is.na(reports_df$report_key) & tolower(reports_df$report_key) == "tabs")
  )

  if (!has_tracker || !has_tabs) return(error_log)

  if (is.null(crossref_df) || nrow(crossref_df) == 0) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "No CrossRef Mappings",
      "Both tracker and tabs reports are included but no CrossRef mappings defined. Consider adding cross-reference mappings to enable linked navigation between reports.",
      "", "Info"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 10: Report compatibility (Turas version)
# ==============================================================================

#' Check Report Compatibility
#'
#' Verifies all reports were generated by compatible Turas versions.
#' Checks for turas-version meta tag.
#'
#' @param reports_df Data frame from Reports sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_report_compatibility <- function(reports_df, error_log) {

  versions <- character(0)

  for (i in seq_len(nrow(reports_df))) {
    path <- reports_df$resolved_path[i]
    label <- reports_df$report_label[i]

    if (!file.exists(path)) next

    head_lines <- tryCatch(
      paste(readLines(path, warn = FALSE, n = 50), collapse = "\n"),
      error = function(e) ""
    )

    # Extract version from meta tag
    ver_match <- regexpr('turas-version"\\s+content="([^"]+)"', head_lines, perl = TRUE)
    if (ver_match > 0) {
      ver <- regmatches(head_lines, ver_match)
      ver <- gsub('turas-version"\\s+content="([^"]+)"', "\\1", ver, perl = TRUE)
      versions <- c(versions, ver)
      names(versions)[length(versions)] <- label
    }
  }

  if (length(versions) >= 2) {
    unique_versions <- unique(versions)
    if (length(unique_versions) > 1) {
      version_detail <- paste(
        sprintf("%s: v%s", names(versions), versions),
        collapse = "; "
      )
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Mixed Turas Versions",
        sprintf("Reports generated by different Turas versions: %s. This may cause styling or functionality inconsistencies.",
                version_detail),
        paste(unique_versions, collapse = ", "), "Warning"
      )
    }
  }

  error_log
}


# ==============================================================================
# CHECK 11: Logo file valid
# ==============================================================================

#' Check Logo File Is Valid Image
#'
#' @param settings Named list of settings
#' @param config_dir Directory of the config file (for resolving relative paths)
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_logo_file_valid <- function(settings, config_dir, error_log) {

  logo_path <- settings$logo_path
  if (is.null(logo_path) || !nzchar(trimws(logo_path))) return(error_log)

  # Resolve relative path
  resolved <- logo_path
  if (!file.exists(resolved)) {
    resolved <- file.path(config_dir, logo_path)
  }

  if (!file.exists(resolved)) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "Logo File Not Found",
      sprintf("Logo file not found: %s. Report will be generated without a logo.", logo_path),
      logo_path, "Warning"
    )
    return(error_log)
  }

  # Check extension
  ext <- tolower(tools::file_ext(resolved))
  valid_exts <- c("png", "jpg", "jpeg", "svg", "gif")
  if (!ext %in% valid_exts) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "Invalid Logo Format",
      sprintf("Logo file '%s' has extension '.%s'. Supported formats: %s",
              basename(logo_path), ext, paste(valid_exts, collapse = ", ")),
      logo_path, "Warning"
    )
  }

  # Check file size (warn if > 2MB)
  file_kb <- file.size(resolved) / 1024
  if (file_kb > 2048) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "Large Logo File",
      sprintf("Logo file is %.0f KB. Large logos increase HTML file size since they are Base64-embedded. Consider using a smaller image.",
              file_kb),
      logo_path, "Warning"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 12: Colour codes valid
# ==============================================================================

#' Check Brand and Accent Colour Codes
#'
#' @param settings Named list of settings
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_colour_codes_valid <- function(settings, error_log) {
  colour_fields <- c("brand_colour", "accent_colour")

  for (field in colour_fields) {
    val <- settings[[field]]
    if (is.null(val) || !nzchar(trimws(val))) next

    val <- trimws(val)
    # Check valid hex colour (3, 4, 6, or 8 hex digits with optional #)
    if (!grepl("^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$", val)) {
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Invalid Colour Code",
        sprintf("%s value '%s' is not a valid hex colour. Use format #RRGGBB (e.g., #323367).",
                field, val),
        val, "Error"
      )
    }
  }

  error_log
}


# ==============================================================================
# CHECK 13: Output directory writable
# ==============================================================================

#' Check Output Directory Is Writable
#'
#' @param settings Named list of settings
#' @param config_dir Directory of the config file
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_output_dir_writable <- function(settings, config_dir, error_log) {

  out_dir <- settings$output_dir
  if (is.null(out_dir) || !nzchar(trimws(out_dir))) {
    out_dir <- config_dir
  }

  # Resolve relative path
  if (!dir.exists(out_dir)) {
    out_dir <- file.path(config_dir, trimws(out_dir))
  }

  if (!dir.exists(out_dir)) {
    # Try to create it
    created <- tryCatch({
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
      dir.exists(out_dir)
    }, error = function(e) FALSE)

    if (!created) {
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Output Directory Cannot Be Created",
        sprintf("Output directory does not exist and cannot be created: %s", out_dir),
        out_dir, "Error"
      )
      return(error_log)
    }
  }

  # Check writable
  test_file <- file.path(out_dir, ".turas_write_test")
  can_write <- tryCatch({
    writeLines("test", test_file)
    unlink(test_file)
    TRUE
  }, error = function(e) FALSE)

  if (!can_write) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "Output Directory Not Writable",
      sprintf("Output directory exists but is not writable: %s", out_dir),
      out_dir, "Error"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 14: Report file sizes
# ==============================================================================

#' Check Report File Sizes
#'
#' Flags suspiciously small files (likely empty/corrupt) and very large files
#' that may cause performance issues in the combined report.
#'
#' @param reports_df Data frame from Reports sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_report_file_sizes <- function(reports_df, error_log) {

  for (i in seq_len(nrow(reports_df))) {
    path <- reports_df$resolved_path[i]
    label <- reports_df$report_label[i]

    if (!file.exists(path)) next

    size_kb <- file.size(path) / 1024

    if (size_kb < 1) {
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Suspiciously Small Report",
        sprintf("Report '%s' is only %.1f KB. It may be empty or corrupted.", label, size_kb),
        path, "Warning"
      )
    }

    if (size_kb > 50000) {
      error_log <- .hub_log_issue(
        error_log, "Preflight", "Very Large Report",
        sprintf("Report '%s' is %.1f MB. The combined report may be slow to load.", label, size_kb / 1024),
        path, "Warning"
      )
    }
  }

  # Check combined size
  total_kb <- sum(sapply(reports_df$resolved_path, function(p) {
    if (file.exists(p)) file.size(p) / 1024 else 0
  }))

  if (total_kb > 100000) {
    error_log <- .hub_log_issue(
      error_log, "Preflight", "Large Combined Size",
      sprintf("Combined report input files total %.1f MB. The output may be very large.", total_kb / 1024),
      "", "Warning"
    )
  }

  error_log
}


# ==============================================================================
# ORCHESTRATOR: Run All Preflight Checks
# ==============================================================================

#' Validate Report Hub Preflight
#'
#' Runs all cross-referential checks on the validated config.
#' Call this AFTER guard_validate_hub_config() has returned PASS.
#'
#' @param config Validated config object from guard_validate_hub_config()
#' @param config_file Path to the original config file (for resolving paths)
#' @param error_log Data frame, error log (optional, created if NULL)
#' @return Updated error_log data frame with columns:
#'   Check, Issue, Detail, Context, Severity
#' @export
validate_report_hub_preflight <- function(config, config_file, error_log = NULL) {

  if (is.null(error_log)) {
    error_log <- .hub_create_error_log()
  }

  config_dir <- dirname(normalizePath(config_file))
  settings <- config$settings

  # Build reports_df from config$reports for checks that need it
  reports_df <- do.call(rbind, lapply(config$reports, function(r) {
    data.frame(
      report_path = basename(r$path),
      report_label = r$label,
      report_key = r$key,
      order = r$order,
      report_type = r$type %||% NA_character_,
      resolved_path = r$path,
      stringsAsFactors = FALSE
    )
  }))

  # Build crossref_df
  crossref_df <- config$cross_refs

  cat("Running preflight checks...\n")

  # --- Check 1: Report files readable ---
  cat("  [1/14] Checking report files are readable...\n")
  error_log <- check_report_files_readable(reports_df, error_log)

  # --- Check 2: Report type detection ---
  cat("  [2/14] Checking report type detection...\n")
  error_log <- check_report_type_detection(reports_df, error_log)

  # --- Check 3: Report key format ---
  cat("  [3/14] Checking report key format...\n")
  error_log <- check_report_key_format(reports_df, error_log)

  # --- Check 4: Duplicate report keys ---
  cat("  [4/14] Checking for duplicate report keys...\n")
  error_log <- check_duplicate_report_keys(reports_df, error_log)

  # --- Check 5: Duplicate report paths ---
  cat("  [5/14] Checking for duplicate report paths...\n")
  error_log <- check_duplicate_report_paths(reports_df, error_log)

  # --- Check 6: Report order gaps ---
  cat("  [6/14] Checking report order values...\n")
  error_log <- check_report_order_gaps(reports_df, error_log)

  # --- Check 7: CrossRef tracker codes ---
  cat("  [7/14] Checking CrossRef tracker codes...\n")
  error_log <- check_crossref_codes_in_tracker(crossref_df, reports_df, error_log)

  # --- Check 8: CrossRef tabs codes ---
  cat("  [8/14] Checking CrossRef tabs codes...\n")
  error_log <- check_crossref_codes_in_tabs(crossref_df, reports_df, error_log)

  # --- Check 9: CrossRef completeness ---
  cat("  [9/14] Checking CrossRef completeness...\n")
  error_log <- check_crossref_completeness(crossref_df, reports_df, error_log)

  # --- Check 10: Report compatibility ---
  cat("  [10/14] Checking report compatibility...\n")
  error_log <- check_report_compatibility(reports_df, error_log)

  # --- Check 11: Logo file valid ---
  cat("  [11/14] Checking logo file...\n")
  error_log <- check_logo_file_valid(settings, config_dir, error_log)

  # --- Check 12: Colour codes ---
  cat("  [12/14] Checking colour codes...\n")
  error_log <- check_colour_codes_valid(settings, error_log)

  # --- Check 13: Output directory writable ---
  cat("  [13/14] Checking output directory...\n")
  error_log <- check_output_dir_writable(settings, config_dir, error_log)

  # --- Check 14: Report file sizes ---
  cat("  [14/14] Checking report file sizes...\n")
  error_log <- check_report_file_sizes(reports_df, error_log)

  # --- Summary ---
  n_errors <- sum(error_log$Severity == "Error")
  n_warnings <- sum(error_log$Severity == "Warning")
  n_info <- sum(error_log$Severity == "Info")

  cat(sprintf("\nPreflight complete: %d error(s), %d warning(s), %d info\n",
              n_errors, n_warnings, n_info))

  if (n_errors > 0) {
    cat("\n┌─── PREFLIGHT ERRORS ─────────────────────────────────┐\n")
    errors_only <- error_log[error_log$Severity == "Error", ]
    for (i in seq_len(nrow(errors_only))) {
      cat(sprintf("│ [%s] %s\n", errors_only$Issue[i], errors_only$Detail[i]))
    }
    cat("└───────────────────────────────────────────────────────┘\n\n")
  }

  error_log
}
