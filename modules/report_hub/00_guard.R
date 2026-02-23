#' Report Hub Guard Layer
#'
#' Validates inputs for the combine_reports() function.
#' Checks config file, report paths, and configuration integrity.

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

  # --- Parse Settings sheet ---
  settings_raw <- openxlsx::read.xlsx(config_file, sheet = "Settings")

  # Settings can be in key-value format (Field, Value columns) or single-row
  settings <- parse_settings_sheet(settings_raw)

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

  # --- Parse Reports sheet ---
  reports_df <- openxlsx::read.xlsx(config_file, sheet = "Reports")

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
    xref_df <- openxlsx::read.xlsx(config_file, sheet = "CrossRef")
    if (nrow(xref_df) > 0) {
      xref_required <- c("tracker_code", "tabs_code")
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
      logo_path = settings$logo_path
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
    cross_refs = cross_refs
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
