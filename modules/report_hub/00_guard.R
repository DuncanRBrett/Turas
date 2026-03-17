#' Report Hub Guard Layer
#'
#' Validates inputs for the combine_reports() function.
#' Checks config file, report paths, and configuration integrity.

# ==============================================================================
# HELPER: Clean OpenXML escape sequences from Excel text
# ==============================================================================

#' Clean OpenXML Escape Sequences from Text
#'
#' openxlsx may pass through unresolved OpenXML `_xHHHH_` escape sequences
#' (e.g., `_x000B_` for vertical tab / in-cell line break, `_x000D_` for
#' carriage return). This helper decodes common control-character escapes
#' to their natural equivalents so that markdown rendering and display work
#' correctly.
#'
#' @param x Character vector to clean
#' @return Cleaned character vector (same length as input)
#' @keywords internal
.clean_openxml_escapes <- function(x) {
  if (is.null(x) || !is.character(x)) return(x)
  # _x000D_ = carriage return → remove (usually paired with \n)
  x <- gsub("_x000D_", "", x, fixed = TRUE)
  # _x000B_ = vertical tab (Excel in-cell soft line break) → space.
  # Real paragraph breaks are already \n in the content; _x000B_ was a visual
  # break within a cell (Alt+Enter or Word paste). Using space keeps the
  # paragraph structure intact for the markdown renderer which wraps each
  # non-blank line in <p> tags.
  x <- gsub(" ?_x000B_", " ", x, perl = TRUE)
  # _x000A_ = line feed → newline (shouldn't normally appear, but be safe)
  x <- gsub("_x000A_", "\n", x, fixed = TRUE)
  # Catch-all: any remaining _xHHHH_ control chars (U+0000–U+001F) → space
  x <- gsub("_x00[0-1][0-9a-fA-F]_", " ", x, perl = TRUE)
  return(x)
}

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
    settings <- as.list(setNames(
      .clean_openxml_escapes(values[valid]),
      tolower(trimws(keys[valid]))
    ))
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
    settings <- as.list(setNames(
      .clean_openxml_escapes(values[valid]),
      tolower(trimws(keys[valid]))
    ))
    return(settings)
  }

  # Fallback: treat as single-row format (column names = field names)
  settings <- as.list(df[1, ])
  names(settings) <- tolower(trimws(names(settings)))
  return(settings)
}


#' Validate Config File Path and Format
#'
#' Checks that the config file path is provided, exists, and is .xlsx format.
#' Returns NULL on success, or a TRS refusal list on failure.
#'
#' @param config_file Path to the config file
#' @return NULL on success, TRS refusal list on failure
#' @keywords internal
.validate_config_file <- function(config_file) {
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

  NULL
}


#' Validate Required Sheets Exist in Config File
#'
#' Reads sheet names from the Excel file and verifies that the required
#' Settings and Reports sheets are present.
#'
#' @param config_file Path to the config file
#' @return List with \code{sheets} (character vector) on success,
#'   or a TRS refusal list on failure
#' @keywords internal
.validate_required_sheets <- function(config_file) {
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

  list(sheets = sheets)
}


#' Validate and Parse Settings Sheet
#'
#' Reads the Settings sheet and validates that required fields
#' (project_title, company_name) are present.
#'
#' @param config_file Path to the config file
#' @return List with \code{settings} (named list) on success,
#'   or a TRS refusal list on failure
#' @keywords internal
.validate_settings <- function(config_file) {
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

  list(settings = settings)
}


#' Validate and Parse Reports Sheet
#'
#' Reads the Reports sheet, validates structure and each row entry,
#' resolves file paths, and checks for duplicates.
#'
#' @param config_file Path to the config file
#' @return List with \code{reports_df} (data frame) on success,
#'   or a TRS refusal list on failure
#' @keywords internal
.validate_reports <- function(config_file) {
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

  # Validate each report entry
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

  list(reports_df = reports_df)
}


#' Encode and Compress a Slide Image to a Base64 Data URI
#'
#' Reads an image file (PNG, JPG, or SVG), downscales if wider than 800px,
#' re-encodes as JPEG at 0.85 quality, and returns a data URI string.
#' SVG files are passed through without re-encoding.
#'
#' @param image_path Absolute path to the image file
#' @return A \code{data:image/...;base64,...} string, or NULL on failure
#' @keywords internal
.encode_slide_image <- function(image_path) {
  ext <- tolower(tools::file_ext(image_path))

  # SVG: pass through as-is (already lightweight vector format)
  if (ext == "svg") {
    raw_bytes <- readBin(image_path, "raw", file.info(image_path)$size)
    b64 <- base64enc::base64encode(raw_bytes)
    return(sprintf("data:image/svg+xml;base64,%s", b64))
  }

  # Read raster image
  img <- tryCatch({
    if (ext == "png") {
      png::readPNG(image_path)
    } else if (ext %in% c("jpg", "jpeg")) {
      jpeg::readJPEG(image_path)
    } else {
      return(NULL)
    }
  }, error = function(e) NULL)
  if (is.null(img)) return(NULL)

  # Downscale if wider than 800px (bilinear via approx on each channel)
  max_w <- 800
  orig_h <- nrow(img)
  orig_w <- ncol(img)
  if (orig_w > max_w) {
    scale <- max_w / orig_w
    new_w <- max_w
    new_h <- max(1L, round(orig_h * scale))
    n_channels <- if (length(dim(img)) == 3) dim(img)[3] else 1L
    if (n_channels == 1) {
      # Greyscale
      resized <- matrix(0, nrow = new_h, ncol = new_w)
      for (row in seq_len(new_h)) {
        src_row <- min(orig_h, max(1, round(row / scale)))
        row_data <- img[src_row, ]
        resized[row, ] <- approx(seq_len(orig_w), row_data, xout = seq(1, orig_w, length.out = new_w))$y
      }
      img <- resized
    } else {
      resized <- array(0, dim = c(new_h, new_w, n_channels))
      for (ch in seq_len(n_channels)) {
        for (row in seq_len(new_h)) {
          src_row <- min(orig_h, max(1, round(row / scale)))
          row_data <- img[src_row, , ch]
          resized[row, , ch] <- approx(seq_len(orig_w), row_data, xout = seq(1, orig_w, length.out = new_w))$y
        }
      }
      img <- resized
    }
  }

  # Clamp values to [0, 1] (approx can produce slight overshoot)
  img <- pmin(pmax(img, 0), 1)

  # Encode as JPEG at 0.85 quality to a raw vector
  raw_con <- rawConnection(raw(0), open = "wb")
  on.exit(close(raw_con), add = TRUE)
  jpeg::writeJPEG(img, raw_con, quality = 0.85)
  jpeg_bytes <- rawConnectionValue(raw_con)

  b64 <- base64enc::base64encode(jpeg_bytes)
  sprintf("data:image/jpeg;base64,%s", b64)
}


#' Parse Optional Config Sheets (CrossRef, Slides)
#'
#' Reads the optional CrossRef and Slides sheets from the config file.
#' Returns parsed data and any warnings for missing columns.
#'
#' @param config_file Path to the config file
#' @param sheets Character vector of available sheet names
#' @return List with \code{cross_refs}, \code{slides}, and \code{warnings}
#' @keywords internal
.parse_optional_sheets <- function(config_file, sheets) {
  warnings <- character(0)
  cross_refs <- NULL
  slides <- NULL

  # --- CrossRef sheet ---
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

  # --- Slides sheet ---
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
        # Check for optional image_path column
        has_image_col <- "image_path" %in% names(slides_df)
        config_dir <- dirname(config_file)
        slides <- lapply(seq_len(nrow(slides_df)), function(i) {
          slide <- list(
            id = sprintf("hub-slide-%d", i),
            title = trimws(.clean_openxml_escapes(slides_df$slide_title[i])),
            content = trimws(.clean_openxml_escapes(slides_df$content[i])),
            order = slides_df$display_order[i]
          )
          # Resolve and encode image if image_path column exists and has a value
          if (has_image_col) {
            img_path <- trimws(slides_df$image_path[i] %||% "")
            if (nzchar(img_path) && !is.na(img_path)) {
              # Try as-is (absolute), then relative to config dir
              resolved <- img_path
              if (!file.exists(resolved)) {
                resolved <- file.path(config_dir, img_path)
              }
              if (file.exists(resolved)) {
                encoded <- .encode_slide_image(normalizePath(resolved))
                if (!is.null(encoded)) {
                  slide$image_data <- encoded
                } else {
                  warnings <<- c(warnings, sprintf(
                    "Slide '%s': Could not encode image '%s'. Unsupported format or corrupt file.",
                    slide$title, img_path
                  ))
                }
              } else {
                warnings <<- c(warnings, sprintf(
                  "Slide '%s': Image file not found: %s. Slide will be created without an image.",
                  slide$title, img_path
                ))
              }
            }
          }
          slide
        })
      }
    }
  }

  list(cross_refs = cross_refs, slides = slides, warnings = warnings)
}


#' Validate and Resolve Output Settings and Logo Path
#'
#' Resolves output_dir (relative to config dir), ensures output_file
#' ends in .html, and resolves the logo path. Appends warnings for
#' non-fatal issues (missing logo, unresolvable output directory).
#'
#' @param settings Named list of settings from the Settings sheet
#' @param config_file Path to the config file (used for relative path resolution)
#' @param warnings Character vector of existing warnings to append to
#' @return List with \code{settings} (modified) and \code{warnings}
#' @keywords internal
.validate_output_settings <- function(settings, config_file, warnings) {
  # --- output_dir ---
  if (!is.null(settings$output_dir) && nzchar(trimws(settings$output_dir))) {
    out_dir <- trimws(settings$output_dir)
    if (!dir.exists(out_dir)) {
      config_dir <- dirname(config_file)
      out_dir_resolved <- file.path(config_dir, out_dir)
      if (dir.exists(out_dir_resolved)) {
        out_dir <- normalizePath(out_dir_resolved)
      } else {
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

  # --- output_file ---
  if (!is.null(settings$output_file) && nzchar(trimws(settings$output_file))) {
    out_file <- trimws(settings$output_file)
    if (!grepl("\\.html?$", out_file, ignore.case = TRUE)) {
      out_file <- paste0(out_file, ".html")
    }
    settings$output_file <- out_file
  }

  # --- logo_path ---
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

  list(settings = settings, warnings = warnings)
}


#' Build Validated Config Object from Parsed Components
#'
#' Assembles the final config list from validated settings, reports,
#' cross-references, and slides. Trims and normalises all string fields.
#'
#' @param settings Named list of validated settings
#' @param reports_df Data frame of validated report entries
#' @param cross_refs Data frame of cross-references (or NULL)
#' @param slides List of slide objects (or NULL)
#' @return The assembled config list
#' @keywords internal
.build_validated_config <- function(settings, reports_df, cross_refs, slides) {
  # Helper: return trimmed value if non-null and non-empty, else NULL
  .trim_or_null <- function(x) {
    if (!is.null(x) && nzchar(trimws(x))) trimws(x) else NULL
  }

  list(
    settings = list(
      project_title = trimws(settings$project_title),
      subtitle = .trim_or_null(settings$subtitle),
      company_name = trimws(settings$company_name),
      client_name = .trim_or_null(settings$client_name),
      brand_colour = .trim_or_null(settings$brand_colour),
      accent_colour = .trim_or_null(settings$accent_colour),
      logo_path = settings$logo_path,
      output_dir = .trim_or_null(settings$output_dir),
      output_file = .trim_or_null(settings$output_file),
      executive_summary = .trim_or_null(settings$executive_summary),
      background_text = .trim_or_null(settings$background_text),
      analyst_name = .trim_or_null(settings$analyst_name),
      analyst_email = .trim_or_null(settings$analyst_email),
      analyst_phone = .trim_or_null(settings$analyst_phone),
      appendices = .trim_or_null(settings$appendices),
      notes = .trim_or_null(settings$notes)
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
}


#' Validate Report Hub Configuration
#'
#' Validates the Report Hub config Excel file: checks file existence,
#' reads and validates Settings and Reports sheets, parses optional
#' CrossRef and Slides sheets, resolves output paths, and assembles
#' the validated config object.
#'
#' @param config_file Path to the Report Hub config Excel file
#' @return TRS-compliant list with status and validated config
guard_validate_hub_config <- function(config_file) {

  # --- Step 1: Validate config file path and format ---
  file_check <- .validate_config_file(config_file)
  if (!is.null(file_check)) return(file_check)

  # --- Step 2: Validate required sheets exist ---
  sheets_check <- .validate_required_sheets(config_file)
  if (!is.null(sheets_check$status)) return(sheets_check)
  sheets <- sheets_check$sheets

  # --- Step 3: Parse and validate Settings sheet ---
  settings_check <- .validate_settings(config_file)
  if (!is.null(settings_check$status)) return(settings_check)
  settings <- settings_check$settings

  # --- Step 4: Parse and validate Reports sheet ---
  reports_check <- .validate_reports(config_file)
  if (!is.null(reports_check$status)) return(reports_check)
  reports_df <- reports_check$reports_df

  # --- Step 5: Parse optional sheets (CrossRef, Slides) ---
  optional <- .parse_optional_sheets(config_file, sheets)
  warnings <- optional$warnings

  # --- Step 6: Validate output settings and logo path ---
  output_check <- .validate_output_settings(settings, config_file, warnings)
  settings <- output_check$settings
  warnings <- output_check$warnings

  # --- Step 7: Build validated config object ---
  config <- .build_validated_config(
    settings, reports_df, optional$cross_refs, optional$slides
  )

  # --- Return ---
  status <- if (length(warnings) > 0) "PARTIAL" else "PASS"
  return(list(
    status = status,
    result = config,
    warnings = warnings,
    message = sprintf("Config validated: %d reports, %s cross-references",
                      length(config$reports),
                      if (is.null(optional$cross_refs)) "no" else nrow(optional$cross_refs))
  ))
}


#' Parse Settings Sheet into a Named List
#'
#' Converts a Settings sheet data frame into a named list of configuration
#' values. Supports two formats: key-value format (with "Field" and "Value"
#' columns where each row is one setting) and single-row format (where
#' column names are field names and the first row contains values).
#' Field names are normalised to lowercase with whitespace trimmed.
#'
#' @param df Data frame read from the Settings sheet of a Report Hub
#'   config Excel file. Must have at least one row. If in key-value
#'   format, must contain columns named "Field" and "Value"
#'   (case-insensitive).
#'
#' @return A named list where names are lowercase field identifiers
#'   (e.g., \code{"project_title"}, \code{"brand_colour"}) and values
#'   are the corresponding character strings. Returns an empty list
#'   if \code{df} has zero rows.
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
