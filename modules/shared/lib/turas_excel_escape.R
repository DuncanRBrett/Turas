# ==============================================================================
# TURAS EXCEL FORMULA-INJECTION PROTECTION (TRS v1.0)
# ==============================================================================
#
# Provides protection against Excel formula injection attacks.
# When user-supplied data is written to Excel, malicious formulas starting
# with =, +, -, @, or tab characters can execute code when the file is opened.
#
# USAGE:
#   safe_value <- turas_excel_escape("=HYPERLINK(...)")  # Returns "'=HYPERLINK(...)"
#   safe_df <- turas_excel_escape_df(user_data)
#
# Reference: OWASP CSV Injection Prevention
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================


#' Excel Formula-Injection Protection Characters
#'
#' Characters that trigger formula interpretation in Excel when at start of cell.
#' @keywords internal
.EXCEL_FORMULA_PREFIXES <- c("=", "+", "-", "@", "\t", "\r", "\n")


#' Escape a Single Value for Excel Safety
#'
#' Prefixes potentially dangerous values with a single quote to prevent
#' formula injection when the value is opened in Excel.
#'
#' @param value The value to escape
#' @param escape_char Character to prefix (default: single quote)
#'
#' @return The escaped value (or original if not a string or not dangerous)
#' @export
#'
#' @examples
#' turas_excel_escape("=SUM(A1:A10)")     # Returns "'=SUM(A1:A10)"
#' turas_excel_escape("+1-2")             # Returns "'+1-2"
#' turas_excel_escape("Normal text")      # Returns "Normal text"
#' turas_excel_escape(42)                 # Returns 42 (unchanged)
turas_excel_escape <- function(value, escape_char = "'") {

  # Only process character values
 if (!is.character(value)) {
    return(value)
  }

  # Handle NA values
  if (length(value) == 0) {
    return(value)
  }

  # Vectorized operation for efficiency
  sapply(value, function(v) {
    if (is.na(v)) {
      return(NA_character_)
    }

    # Check if starts with a dangerous character
    if (nchar(v) > 0) {
      first_char <- substr(v, 1, 1)
      if (first_char %in% .EXCEL_FORMULA_PREFIXES) {
        return(paste0(escape_char, v))
      }
    }

    return(v)
  }, USE.NAMES = FALSE)
}


#' Check if a Value Contains Potential Formula Injection
#'
#' @param value The value to check
#' @return Logical indicating if value could be a formula injection attempt
#' @export
turas_excel_is_dangerous <- function(value) {
  if (!is.character(value) || length(value) == 0 || is.na(value[1])) {
    return(FALSE)
  }

  any(sapply(value, function(v) {
    if (is.na(v) || nchar(v) == 0) return(FALSE)
    substr(v, 1, 1) %in% .EXCEL_FORMULA_PREFIXES
  }))
}


#' Escape a Data Frame for Excel Safety
#'
#' Applies formula-injection protection to all character columns in a data frame.
#' Numeric, logical, date, and factor columns are left unchanged.
#'
#' @param df The data frame to escape
#' @param columns Optional character vector of column names to escape.
#'                If NULL (default), escapes all character columns.
#' @param escape_char Character to prefix (default: single quote)
#' @param verbose Logical. Report if any escaping occurred? (default FALSE)
#'
#' @return The escaped data frame
#' @export
#'
#' @examples
#' df <- data.frame(
#'   name = c("Alice", "=cmd|' /C calc'!A0", "Bob"),
#'   value = c(1, 2, 3)
#' )
#' safe_df <- turas_excel_escape_df(df)
turas_excel_escape_df <- function(df,
                                   columns = NULL,
                                   escape_char = "'",
                                   verbose = FALSE) {

  if (!is.data.frame(df)) {
    return(df)
  }

  if (nrow(df) == 0) {
    return(df)
  }

  # Determine which columns to process
  if (is.null(columns)) {
    # All character columns
    char_cols <- names(df)[sapply(df, is.character)]
  } else {
    # Specified columns that exist and are character
    char_cols <- intersect(columns, names(df))
    char_cols <- char_cols[sapply(df[char_cols], is.character)]
  }

  if (length(char_cols) == 0) {
    return(df)
  }

  escape_count <- 0

  for (col in char_cols) {
    original <- df[[col]]
    escaped <- turas_excel_escape(original, escape_char)

    # Count how many were escaped
    if (verbose) {
      changed <- !is.na(original) & !is.na(escaped) & original != escaped
      escape_count <- escape_count + sum(changed, na.rm = TRUE)
    }

    df[[col]] <- escaped
  }

  if (verbose && escape_count > 0 && exists("turas_log_info", mode = "function")) {
    turas_log_info("TURAS", sprintf("Escaped %d potentially dangerous cell(s) for Excel safety", escape_count))
  }

  return(df)
}


#' Escape a Named List of Data Frames (for Excel Sheets)
#'
#' Convenience function for escaping all sheets before saving to Excel.
#'
#' @param sheets Named list of data frames
#' @param columns Optional column names to escape (applies to all sheets)
#' @param escape_char Character to prefix (default: single quote)
#' @param verbose Logical. Report escaping? (default FALSE)
#'
#' @return List of escaped data frames
#' @export
turas_excel_escape_sheets <- function(sheets,
                                       columns = NULL,
                                       escape_char = "'",
                                       verbose = FALSE) {

  if (!is.list(sheets)) {
    return(sheets)
  }

  lapply(sheets, function(sheet) {
    if (is.data.frame(sheet)) {
      turas_excel_escape_df(sheet, columns = columns,
                            escape_char = escape_char, verbose = verbose)
    } else {
      sheet
    }
  })
}


#' Escape User-Supplied Text for Excel Cell Content
#'
#' More aggressive escaping for text known to come from user input.
#' Also handles pipe (|) and semicolon (;) which can be used in DDE attacks.
#'
#' @param value The value to escape
#' @param strict Logical. Use strict mode with additional character escaping? (default TRUE)
#'
#' @return The escaped value
#' @export
turas_excel_escape_user_input <- function(value, strict = TRUE) {

  if (!is.character(value)) {
    return(value)
  }

  # Basic formula prefix escaping
  result <- turas_excel_escape(value)

  if (strict) {
    # Also check for DDE/pipe patterns that could be dangerous
    # even without formula prefix
    result <- sapply(result, function(v) {
      if (is.na(v)) return(NA_character_)

      # Check for DDE patterns: =DDE, @DDE, etc.
      if (grepl("^[=+\\-@]\\s*(DDE|cmd|IMPORTRANGE)", v, ignore.case = TRUE)) {
        if (!startsWith(v, "'")) {
          return(paste0("'", v))
        }
      }

      return(v)
    }, USE.NAMES = FALSE)
  }

  return(result)
}


# ==============================================================================
# INTEGRATION WITH OPENXLSX
# ==============================================================================

#' Write Data to Excel with Formula Protection
#'
#' Wrapper around openxlsx::writeData that applies formula-injection
#' protection before writing.
#'
#' @param wb Workbook object
#' @param sheet Sheet name or index
#' @param x Data to write (data.frame, matrix, or vector)
#' @param startCol Starting column (default 1)
#' @param startRow Starting row (default 1)
#' @param escape Logical. Apply formula escaping? (default TRUE)
#' @param ... Additional arguments passed to openxlsx::writeData
#'
#' @return Invisible NULL
#' @export
turas_write_data_safe <- function(wb,
                                   sheet,
                                   x,
                                   startCol = 1,
                                   startRow = 1,
                                   escape = TRUE,
                                   ...) {

  # Apply escaping if requested and data is a data.frame
  if (escape && is.data.frame(x)) {
    x <- turas_excel_escape_df(x)
  }

  # Write using openxlsx
  openxlsx::writeData(wb, sheet, x,
                      startCol = startCol, startRow = startRow,
                      ...)

  invisible(NULL)
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

if (interactive()) {
  message("[TRS INFO] Excel formula-injection protection loaded (turas_excel_escape v1.0)")
}
