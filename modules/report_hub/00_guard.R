#' Report Hub Guard Layer
#'
#' Validates inputs for the combine_reports() function.
#' Checks config file, report paths, and configuration integrity.

# ==============================================================================
# HELPER: Auto-detect header row (same approach as tabs module)
# ==============================================================================

#' Read a table-format Excel sheet with auto-detection of header row
#'
#' Supports both legacy format (headers in row 1) and new template format
#' (title/subtitle/help rows above the actual column headers).
#' Scans first 10 rows for the required column names.
#'
#' @param file_path Path to Excel file
#' @param sheet_name Sheet name to read
#' @param required_cols Character vector of required column names to detect
#' @return Data frame with the sheet contents, or NULL if headers not found
#' @keywords internal
.read_table_sheet <- function(file_path, sheet_name, required_cols) {
  # First try standard read (headers in row 1)
  df <- openxlsx::read.xlsx(file_path, sheet = sheet_name)

  if (all(required_cols %in% names(df))) {
    # Filter out help/description rows that start with "[REQUIRED]" or "[Optional]"
    if (nrow(df) > 0 && any(grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                                   as.character(df[[1]]), ignore.case = TRUE))) {
      df <- df[!grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                       as.character(df[[1]]), ignore.case = TRUE), , drop = FALSE]
    }
    # Remove completely empty rows
    if (nrow(df) > 0) {
      all_na <- apply(df, 1, function(row) all(is.na(row) | trimws(as.character(row)) == ""))
      df <- df[!all_na, , drop = FALSE]
    }
    return(df)
  }

  # Auto-detect: scan first 10 rows for the header
  raw <- openxlsx::read.xlsx(file_path, sheet = sheet_name,
                              colNames = FALSE, rows = 1:10)
  header_row <- NULL
  for (r in seq_len(nrow(raw))) {
    row_vals <- as.character(unlist(raw[r, ]))
    if (all(required_cols %in% row_vals)) {
      header_row <- r
      break
    }
  }

  if (!is.null(header_row)) {
    df <- openxlsx::read.xlsx(file_path, sheet = sheet_name,
                               startRow = header_row)

    # Filter out help/description rows
    if (nrow(df) > 0 && any(grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                                   as.character(df[[1]]), ignore.case = TRUE))) {
      df <- df[!grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                       as.character(df[[1]]), ignore.case = TRUE), , drop = FALSE]
    }

    # Remove completely empty rows
    if (nrow(df) > 0) {
      all_na <- apply(df, 1, function(row) all(is.na(row) | trimws(as.character(row)) == ""))
      df <- df[!all_na, , drop = FALSE]
    }

    return(df)
  }

  # Fall through - return original df, let caller handle validation
  return(df)
}


#' Read a Settings-format Excel sheet with auto-detection of header row
#'
#' Supports both legacy format (Setting/Value or Field/Value in row 1) and
#' new template format (title/subtitle/legend rows above the header).
#' Returns a named list of settings.
#'
#' @param file_path Path to Excel file
#' @param sheet_name Sheet name to read
#' @return Named list of settings
#' @keywords internal
.read_settings_sheet <- function(file_path, sheet_name) {
  df <- openxlsx::read.xlsx(file_path, sheet = sheet_name)
  col_lower <- tolower(names(df))

  # Check for key-value format: Setting/Value or Field/Value in row 1
  has_kv <- ("setting" %in% col_lower && "value" %in% col_lower) ||
            ("field" %in% col_lower && "value" %in% col_lower)

  if (has_kv) {
    key_col <- if ("setting" %in% col_lower) which(col_lower == "setting")[1]
               else which(col_lower == "field")[1]
    value_col <- which(col_lower == "value")[1]
    # Filter out section headers and empty rows
    keys <- as.character(df[[key_col]])
    values <- as.character(df[[value_col]])
    valid <- !is.na(keys) & nzchar(trimws(keys)) &
             !grepl("^\\[", keys) &           # skip [REQUIRED] description rows
             !grepl("^(PROJECT|BRANDING|OUTPUT|SECTION)$", keys, ignore.case = TRUE)  # skip section headers
    settings <- as.list(setNames(values[valid], tolower(trimws(keys[valid]))))
    return(settings)
  }

  # Auto-detect: scan first 10 rows for Setting/Value or Field/Value header
  raw <- openxlsx::read.xlsx(file_path, sheet = sheet_name,
                              colNames = FALSE, rows = 1:10)
  header_row <- NULL
  for (r in seq_len(nrow(raw))) {
    row_vals <- tolower(as.character(unlist(raw[r, ])))
    if (("setting" %in% row_vals && "value" %in% row_vals) ||
        ("field" %in% row_vals && "value" %in% row_vals)) {
      header_row <- r
      break
    }
  }

  if (!is.null(header_row)) {
    df <- openxlsx::read.xlsx(file_path, sheet = sheet_name,
                               startRow = header_row)
    col_lower <- tolower(names(df))
    key_col <- if ("setting" %in% col_lower) which(col_lower == "setting")[1]
               else which(col_lower == "field")[1]
    value_col <- which(col_lower == "value")[1]
    keys <- as.character(df[[key_col]])
    values <- as.character(df[[value_col]])
    valid <- !is.na(keys) & nzchar(trimws(keys)) &
             !grepl("^\\[", keys) &
             !grepl("^(PROJECT|BRANDING|OUTPUT|SECTION)$", keys, ignore.case = TRUE)
    settings <- as.list(setNames(values[valid], tolower(trimws(keys[valid]))))
    return(settings)
  }

  # Fallback: treat as single-row format (column names = field names)
  settings <- as.list(df[1, ])
  names(settings) <- tolower(trimws(names(settings)))
  return(settings)
}


#' Validate Report Hub Configuration
#'
#' @param config_file Path to the Report Hub config Excel file
#' @return TRS-compliant list with status and validated config
guard_validate_hub_config <- function(config_file) {

  # --- Check config file exists ---
  if (is.null(config_file) || !nzchar(config_file)) {
    return(list(
      status = "REFUSED",
      code = "CFG_MISSING",
      message = "No config file path provided",
      how_to_fix = "Provide the path to a Report Hub config Excel file (.xlsx)"
    ))
  }

  if (!file.exists(config_file)) {
    return(list(
      status = "REFUSED",
      code = "IO_FILE_NOT_FOUND",
      message = sprintf("Config file not found: %s", config_file),
      how_to_fix = "Check the file path. The config file must be a valid .xlsx file."
    ))
  }

  ext <- tolower(tools::file_ext(config_file))
  if (ext != "xlsx") {
    return(list(
      status = "REFUSED",
      code = "IO_INVALID_FORMAT",
      message = sprintf("Config file must be .xlsx format, got .%s", ext),
      how_to_fix = "Provide an Excel (.xlsx) config file."
    ))
  }

  # --- Read and validate Settings sheet ---
  sheets <- tryCatch(
    openxlsx::getSheetNames(config_file),
    error = function(e) NULL
  )

  if (is.null(sheets)) {
    return(list(
      status = "REFUSED",
      code = "IO_READ_FAILED",
      message = sprintf("Cannot read Excel file: %s", config_file),
      how_to_fix = "Ensure the file is a valid .xlsx file and is not corrupted or open in another program."
    ))
  }

  if (!"Settings" %in% sheets) {
    return(list(
      status = "REFUSED",
      code = "CFG_MISSING_SHEET",
      message = "Config file missing required 'Settings' sheet",
      how_to_fix = "Add a 'Settings' sheet with at least project_title and company_name fields."
    ))
  }

  if (!"Reports" %in% sheets) {
    return(list(
      status = "REFUSED",
      code = "CFG_MISSING_SHEET",
      message = "Config file missing required 'Reports' sheet",
      how_to_fix = "Add a 'Reports' sheet listing the HTML report files to combine."
    ))
  }

  # --- Parse Settings sheet (auto-detect header row) ---
  settings <- .read_settings_sheet(config_file, "Settings")

  if (is.null(settings$project_title) || !nzchar(trimws(settings$project_title))) {
    return(list(
      status = "REFUSED",
      code = "CFG_MISSING_FIELD",
      message = "Settings sheet missing required field: project_title",
      how_to_fix = "Add a 'project_title' row/column in the Settings sheet."
    ))
  }

  if (is.null(settings$company_name) || !nzchar(trimws(settings$company_name))) {
    return(list(
      status = "REFUSED",
      code = "CFG_MISSING_FIELD",
      message = "Settings sheet missing required field: company_name",
      how_to_fix = "Add a 'company_name' row/column in the Settings sheet."
    ))
  }

  # --- Parse Reports sheet (auto-detect header row) ---
  reports_df <- .read_table_sheet(config_file, "Reports",
                                   c("report_path", "report_label", "report_key", "order"))

  required_cols <- c("report_path", "report_label", "report_key", "order")
  missing_cols <- setdiff(required_cols, names(reports_df))
  if (length(missing_cols) > 0) {
    return(list(
      status = "REFUSED",
      code = "CFG_MISSING_FIELD",
      message = sprintf("Reports sheet missing required columns: %s",
                        paste(missing_cols, collapse = ", ")),
      how_to_fix = "The Reports sheet needs columns: report_path, report_label, report_key, order"
    ))
  }

  if (nrow(reports_df) == 0) {
    return(list(
      status = "REFUSED",
      code = "CFG_EMPTY",
      message = "Reports sheet has no rows",
      how_to_fix = "Add at least one report entry to the Reports sheet."
    ))
  }

  # Coerce order to numeric (template format may read all columns as character
  # because description rows contain text in numeric columns)
  if ("order" %in% names(reports_df)) {
    reports_df$order <- suppressWarnings(as.numeric(reports_df$order))
  }

  # --- Validate each report entry ---
  warnings <- character(0)

  for (i in seq_len(nrow(reports_df))) {
    row <- reports_df[i, ]

    # Check report file exists
    if (is.na(row$report_path) || !nzchar(trimws(row$report_path))) {
      return(list(
        status = "REFUSED",
        code = "CFG_MISSING_FIELD",
        message = sprintf("Reports row %d: report_path is empty", i),
        how_to_fix = "Every report row must have a valid file path."
      ))
    }

    # Resolve path relative to config file directory if not absolute
    report_path <- row$report_path
    if (!file.exists(report_path)) {
      config_dir <- dirname(config_file)
      report_path <- file.path(config_dir, row$report_path)
    }
    if (!file.exists(report_path)) {
      return(list(
        status = "REFUSED",
        code = "IO_FILE_NOT_FOUND",
        message = sprintf("Report file not found: %s (row %d: '%s')",
                          row$report_path, i, row$report_label),
        how_to_fix = "Check the file path. Paths can be absolute or relative to the config file location."
      ))
    }
    reports_df$resolved_path[i] <- normalizePath(report_path)

    # Check file is HTML
    ext_r <- tolower(tools::file_ext(report_path))
    if (ext_r != "html" && ext_r != "htm") {
      return(list(
        status = "REFUSED",
        code = "IO_INVALID_FORMAT",
        message = sprintf("Report file must be .html, got .%s (row %d: '%s')",
                          ext_r, i, row$report_label),
        how_to_fix = "Provide HTML report files generated by Turas."
      ))
    }

    # Check required fields
    if (is.na(row$report_label) || !nzchar(trimws(row$report_label))) {
      return(list(
        status = "REFUSED",
        code = "CFG_MISSING_FIELD",
        message = sprintf("Reports row %d: report_label is empty", i),
        how_to_fix = "Every report row must have a display label."
      ))
    }

    if (is.na(row$report_key) || !nzchar(trimws(row$report_key))) {
      return(list(
        status = "REFUSED",
        code = "CFG_MISSING_FIELD",
        message = sprintf("Reports row %d: report_key is empty", i),
        how_to_fix = "Every report row must have a unique key (e.g., 'tracker', 'tabs')."
      ))
    }

    # Validate report_key format (must be safe for use in JS, HTML, and CSS identifiers)
    key_val <- trimws(row$report_key)
    if (!grepl("^[a-zA-Z][a-zA-Z0-9_-]*$", key_val)) {
      return(list(
        status = "REFUSED",
        code = "CFG_INVALID_VALUE",
        message = sprintf("Reports row %d: report_key '%s' contains invalid characters", i, key_val),
        how_to_fix = "report_key must start with a letter and contain only letters, numbers, hyphens, or underscores (e.g., 'tracker', 'brand-health', 'tabs_v2')."
      ))
    }

    if (is.na(row$order) || !is.numeric(row$order)) {
      return(list(
        status = "REFUSED",
        code = "CFG_INVALID_VALUE",
        message = sprintf("Reports row %d: order must be a number", i),
        how_to_fix = "Set the order column to a numeric value (1, 2, 3, ...)."
      ))
    }
  }

  # Check for duplicate keys
  keys <- trimws(reports_df$report_key)
  if (any(duplicated(keys))) {
    dupes <- unique(keys[duplicated(keys)])
    return(list(
      status = "REFUSED",
      code = "CFG_DUPLICATE_KEY",
      message = sprintf("Duplicate report_key values: %s", paste(dupes, collapse = ", ")),
      how_to_fix = "Each report must have a unique report_key."
    ))
  }

  # Sort by order
  reports_df <- reports_df[order(reports_df$order), ]

  # --- Parse CrossRef sheet (optional) ---
  cross_refs <- NULL
  if ("CrossRef" %in% sheets) {
    xref_required <- c("tracker_code", "tabs_code")
    xref_df <- .read_table_sheet(config_file, "CrossRef", xref_required)
    if (nrow(xref_df) > 0) {
      xref_missing <- setdiff(xref_required, names(xref_df))
      if (length(xref_missing) > 0) {
        warnings <- c(warnings, sprintf(
          "CrossRef sheet missing columns: %s. Cross-references will be skipped.",
          paste(xref_missing, collapse = ", ")
        ))
      } else {
        cross_refs <- xref_df[!is.na(xref_df$tracker_code) & !is.na(xref_df$tabs_code), ]
        if (nrow(cross_refs) == 0) cross_refs <- NULL
      }
    }
  }

  # --- Parse Slides sheet (optional) ---
  slides <- NULL
  if ("Slides" %in% sheets) {
    slides_required <- c("slide_title", "content", "display_order")
    slides_df <- .read_table_sheet(config_file, "Slides", slides_required)
    slides_missing <- setdiff(slides_required, names(slides_df))
    if (length(slides_missing) > 0) {
      warnings <- c(warnings, sprintf(
        "Slides sheet missing columns: %s. Slides will be skipped.",
        paste(slides_missing, collapse = ", ")
      ))
    } else if (nrow(slides_df) > 0) {
      # Coerce display_order to numeric
      slides_df$display_order <- suppressWarnings(as.numeric(slides_df$display_order))
      # Remove rows with missing title or content
      valid_slides <- !is.na(slides_df$slide_title) & nzchar(trimws(slides_df$slide_title)) &
                      !is.na(slides_df$content) & nzchar(trimws(slides_df$content))
      slides_df <- slides_df[valid_slides, , drop = FALSE]
      if (nrow(slides_df) > 0) {
        # Sort by display_order
        slides_df <- slides_df[order(slides_df$display_order), ]
        slides <- lapply(seq_len(nrow(slides_df)), function(i) {
          list(
            id = sprintf("hub-slide-%d", i),
            title = trimws(slides_df$slide_title[i]),
            content = trimws(slides_df$content[i]),
            order = slides_df$display_order[i]
          )
        })
      }
    }
  }

  # --- Validate output settings if provided ---
  # output_dir: directory for the combined report (absolute or relative to config)
  # output_file: filename for the combined report (just the name, no directory)
  if (!is.null(settings$output_dir) && nzchar(trimws(settings$output_dir))) {
    out_dir <- trimws(settings$output_dir)
    # Resolve relative to config file directory
    if (!dir.exists(out_dir)) {
      config_dir <- dirname(config_file)
      out_dir_resolved <- file.path(config_dir, out_dir)
      if (dir.exists(out_dir_resolved)) {
        out_dir <- normalizePath(out_dir_resolved)
      } else {
        # Try to create the directory
        dir_created <- tryCatch({
          dir.create(out_dir_resolved, recursive = TRUE, showWarnings = FALSE)
          dir.exists(out_dir_resolved)
        }, error = function(e) FALSE)
        if (dir_created) {
          out_dir <- normalizePath(out_dir_resolved)
        } else {
          warnings <- c(warnings, sprintf(
            "Output directory not found and could not be created: %s. Using config file directory instead.",
            settings$output_dir
          ))
          out_dir <- dirname(config_file)
        }
      }
    } else {
      out_dir <- normalizePath(out_dir)
    }
    settings$output_dir <- out_dir
  }

  if (!is.null(settings$output_file) && nzchar(trimws(settings$output_file))) {
    out_file <- trimws(settings$output_file)
    # Ensure it ends in .html
    if (!grepl("\\.html?$", out_file, ignore.case = TRUE)) {
      out_file <- paste0(out_file, ".html")
    }
    settings$output_file <- out_file
  }

  # --- Validate logo path if provided ---
  if (!is.null(settings$logo_path) && nzchar(trimws(settings$logo_path))) {
    logo_path <- settings$logo_path
    if (!file.exists(logo_path)) {
      config_dir <- dirname(config_file)
      logo_path <- file.path(config_dir, settings$logo_path)
    }
    if (!file.exists(logo_path)) {
      warnings <- c(warnings, sprintf(
        "Logo file not found: %s. Report will be generated without a logo.",
        settings$logo_path
      ))
      settings$logo_path <- NULL
    } else {
      settings$logo_path <- normalizePath(logo_path)
    }
  }

  # --- Build validated config object ---
  config <- list(
    settings = list(
      project_title = trimws(settings$project_title),
      subtitle = if (!is.null(settings$subtitle)) trimws(settings$subtitle) else NULL,
      company_name = trimws(settings$company_name),
      client_name = if (!is.null(settings$client_name)) trimws(settings$client_name) else NULL,
      brand_colour = if (!is.null(settings$brand_colour)) trimws(settings$brand_colour) else NULL,
      accent_colour = if (!is.null(settings$accent_colour)) trimws(settings$accent_colour) else NULL,
      logo_path = settings$logo_path,
      output_dir = if (!is.null(settings$output_dir) && nzchar(trimws(settings$output_dir)))
                     settings$output_dir else NULL,
      output_file = if (!is.null(settings$output_file) && nzchar(trimws(settings$output_file)))
                      settings$output_file else NULL,
      executive_summary = if (!is.null(settings$executive_summary) && nzchar(trimws(settings$executive_summary)))
                            trimws(settings$executive_summary) else NULL,
      background_text = if (!is.null(settings$background_text) && nzchar(trimws(settings$background_text)))
                           trimws(settings$background_text) else NULL,
      # About section fields
      analyst_name = if (!is.null(settings$analyst_name) && nzchar(trimws(settings$analyst_name)))
                       trimws(settings$analyst_name) else NULL,
      analyst_email = if (!is.null(settings$analyst_email) && nzchar(trimws(settings$analyst_email)))
                        trimws(settings$analyst_email) else NULL,
      analyst_phone = if (!is.null(settings$analyst_phone) && nzchar(trimws(settings$analyst_phone)))
                        trimws(settings$analyst_phone) else NULL,
      appendices = if (!is.null(settings$appendices) && nzchar(trimws(settings$appendices)))
                     trimws(settings$appendices) else NULL,
      notes = if (!is.null(settings$notes) && nzchar(trimws(settings$notes)))
                trimws(settings$notes) else NULL
    ),
    reports = lapply(seq_len(nrow(reports_df)), function(i) {
      row <- reports_df[i, ]
      list(
        path = row$resolved_path,
        label = trimws(row$report_label),
        key = trimws(row$report_key),
        order = row$order,
        type = if ("report_type" %in% names(row) && !is.na(row$report_type) &&
                   nzchar(trimws(row$report_type))) trimws(row$report_type) else NULL
      )
    }),
    cross_refs = cross_refs,
    slides = slides
  )

  # --- Return ---
  status <- if (length(warnings) > 0) "PARTIAL" else "PASS"
  return(list(
    status = status,
    result = config,
    warnings = warnings,
    message = sprintf("Config validated: %d reports, %s cross-references",
                      length(config$reports),
                      if (is.null(cross_refs)) "no" else nrow(cross_refs))
  ))
}


#' Parse Settings Sheet
#'
#' Handles both key-value format (Field/Value columns) and single-row format.
#' @param df Data frame from Settings sheet
#' @return Named list of settings
parse_settings_sheet <- function(df) {
  if (nrow(df) == 0) return(list())

  # Check if it's key-value format (has Field and Value columns)
  col_lower <- tolower(names(df))
  if ("field" %in% col_lower && "value" %in% col_lower) {
    field_col <- which(col_lower == "field")[1]
    value_col <- which(col_lower == "value")[1]
    settings <- as.list(setNames(
      as.character(df[[value_col]]),
      tolower(trimws(as.character(df[[field_col]])))
    ))
    return(settings)
  }

  # Otherwise treat as single-row format (column names = field names)
  settings <- as.list(df[1, ])
  names(settings) <- tolower(trimws(names(settings)))
  return(settings)
}
