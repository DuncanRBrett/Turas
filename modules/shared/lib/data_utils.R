# ==============================================================================
# DATA UTILITIES
# ==============================================================================
# Data loading, type conversion, and manipulation utilities
# Extracted from shared_functions.R Turas v10.0
# Part of Turas shared module infrastructure
# ==============================================================================

# Constants
SUPPORTED_DATA_FORMATS <- c("xlsx", "xls", "csv", "sav")

#' Load survey data file
#'
#' SUPPORTED FORMATS: .xlsx, .xls, .csv, .sav (SPSS via haven package)
#'
#' PERFORMANCE:
#'   - Excel: ~10MB/sec on typical hardware
#'   - CSV (base R): ~50MB/sec
#'   - CSV (data.table): ~500MB/sec [Auto-enabled if package available]
#'   - SPSS: ~20MB/sec
#'
#' MEMORY: Loads entire file into RAM
#'   - Files >500MB will show warning
#'   - Consider splitting very large datasets
#'
#' @param data_file_path Character, path to data file (relative or absolute)
#' @param project_root Character, optional project root for resolving relative paths
#' @param convert_labelled Logical, convert SPSS labelled to plain R types (default: FALSE)
#' @return Data frame with survey responses
#' @export
load_survey_data <- function(data_file_path, project_root = NULL,
                             convert_labelled = FALSE) {
  # Resolve path if relative
  if (!is.null(project_root) && !file.exists(data_file_path)) {
    data_file_path <- resolve_path(project_root, data_file_path)
  }

  # Validate file exists
  validate_file_path(data_file_path, "data_file_path", must_exist = TRUE)

  cat("Loading survey data from:", basename(data_file_path), "\n")

  # Detect file type
  file_ext <- tolower(tools::file_ext(data_file_path))

  if (!file_ext %in% SUPPORTED_DATA_FORMATS) {
    turas_refuse(
      code = "IO_UNSUPPORTED_FILE_FORMAT",
      title = "Unsupported Data File Format",
      problem = sprintf("File type '.%s' is not supported for data loading.", file_ext),
      why_it_matters = "Only specific file formats can be reliably loaded and processed.",
      how_to_fix = c(
        sprintf("Convert your data file to one of the supported formats: %s",
                paste0(".", SUPPORTED_DATA_FORMATS, collapse = ", ")),
        "Most software can export to .xlsx or .csv format",
        "For SPSS files, ensure the file extension is .sav"
      ),
      expected = SUPPORTED_DATA_FORMATS,
      observed = file_ext
    )
  }

  # Load data with format-specific handling
  survey_data <- tryCatch({
    switch(file_ext,
      "xlsx" = readxl::read_excel(data_file_path),
      "xls"  = readxl::read_excel(data_file_path),
      "csv"  = {
        # CSV fast-path via data.table if available
        if (requireNamespace("data.table", quietly = TRUE)) {
          cat("  Using data.table::fread() for faster loading...\n")
          data.table::fread(data_file_path, data.table = FALSE)
        } else {
          read.csv(data_file_path, stringsAsFactors = FALSE)
        }
      },
      "sav"  = {
        # SPSS support via haven package
        if (!requireNamespace("haven", quietly = TRUE)) {
          turas_refuse(
            code = "PKG_HAVEN_MISSING",
            title = "Missing Required Package: haven",
            problem = "SPSS .sav files require the 'haven' package, which is not installed.",
            why_it_matters = "The haven package is needed to read SPSS data files.",
            how_to_fix = c(
              "Install the haven package by running:",
              "  install.packages('haven')",
              "Then retry loading your data",
              "Alternative: Convert your .sav file to .csv or .xlsx format"
            )
          )
        }

        dat <- haven::read_sav(data_file_path)

        # Optional label conversion
        if (convert_labelled) {
          cat("  Converting SPSS labels to plain R types...\n")
          dat <- haven::zap_labels(dat)
        }

        dat
      }
    )
  }, error = function(e) {
    turas_refuse(
      code = "IO_DATA_LOAD_FAILED",
      title = "Failed to Load Data File",
      problem = sprintf("Could not load data file: %s", basename(data_file_path)),
      why_it_matters = "Survey data must be loaded successfully to proceed with analysis.",
      how_to_fix = c(
        "Verify the file is not corrupted by opening it manually",
        "Ensure the file is not currently open in another program (Excel, SPSS, etc.)",
        "For Excel files: try saving as .csv format and retry",
        "Check file permissions to ensure it's readable",
        "Verify the file format matches its extension"
      ),
      details = conditionMessage(e)
    )
  })

  # Validate loaded data
  if (!is.data.frame(survey_data)) {
    turas_refuse(
      code = "DATA_INVALID_STRUCTURE",
      title = "Invalid Data Structure",
      problem = "Data file loaded but is not in the expected data frame format.",
      why_it_matters = "Turas requires data in a standard tabular (rows and columns) format.",
      how_to_fix = c(
        "Ensure your data is in a standard table format",
        "Check that the file contains a single data table, not multiple sheets or complex structures",
        "For Excel files: ensure data starts at cell A1 with column headers in row 1",
        sprintf("Data type detected: %s", paste(class(survey_data), collapse = ", "))
      )
    )
  }

  if (nrow(survey_data) == 0) {
    turas_refuse(
      code = "DATA_EMPTY_FILE",
      title = "Empty Data File",
      problem = "Data file contains no rows of data.",
      why_it_matters = "Analysis cannot proceed without survey responses.",
      how_to_fix = c(
        "Check that you're loading the correct file",
        "Verify the file contains actual data rows, not just column headers",
        "Ensure data export completed successfully from your survey platform"
      )
    )
  }

  if (ncol(survey_data) == 0) {
    turas_refuse(
      code = "DATA_NO_COLUMNS",
      title = "Data File Has No Columns",
      problem = "Data file contains no columns.",
      why_it_matters = "Analysis requires data columns corresponding to survey questions.",
      how_to_fix = c(
        "Check that you're loading the correct file",
        "Verify the file structure is a valid table with column headers",
        "Ensure the data export included all necessary columns"
      )
    )
  }

  # Success message
  cat(sprintf(
    "✓ Loaded: %s rows, %s columns\n",
    format(nrow(survey_data), big.mark = ","),
    format(ncol(survey_data), big.mark = ",")
  ))

  return(survey_data)
}

#' Type-safe equality comparison with trimming
#'
#' CASE SENSITIVITY: Comparison is CASE-SENSITIVE
#'   - "Apple" != "apple"
#'   - Both values are trimmed of whitespace before comparison
#'
#' NA HANDLING:
#'   - Real NA values are treated as missing (non-match)
#'   - NA == NA returns TRUE (both missing)
#'   - NA != "NA" (missing value != string "NA")
#'
#' @param a First value/vector
#' @param b Second value/vector
#' @return Logical vector of comparisons
#' @export
safe_equal <- function(a, b) {
  if (length(a) == 0 || length(b) == 0) {
    return(logical(0))
  }

  # Vectorize to longer length
  max_len <- max(length(a), length(b))
  if (length(a) < max_len) a <- rep_len(a, max_len)
  if (length(b) < max_len) b <- rep_len(b, max_len)

  # Initialize result
  result <- rep(FALSE, max_len)

  # Identify NAs
  na_a <- is.na(a)
  na_b <- is.na(b)

  # Both NA = TRUE (both missing)
  both_na <- na_a & na_b
  result[both_na] <- TRUE

  # Compare non-NA values (trim whitespace)
  neither_na <- !na_a & !na_b
  if (any(neither_na)) {
    result[neither_na] <- trimws(as.character(a[neither_na])) ==
                          trimws(as.character(b[neither_na]))
  }

  return(result)
}

#' Safely convert to numeric
#'
#' USAGE: Convert config values, survey responses to numeric
#' DESIGN: Suppresses warnings, replaces failures with na_value
#'
#' @param x Value(s) to convert
#' @param na_value Value to use for conversion failures (default: NA_real_)
#' @return Numeric value(s)
#' @export
safe_numeric <- function(x, na_value = NA_real_) {
  result <- suppressWarnings(as.numeric(x))
  result[is.na(result)] <- na_value
  return(result)
}

#' Safely convert to logical
#'
#' USAGE: Convert config settings to TRUE/FALSE
#' DESIGN: Handles multiple text representations (Y/N, YES/NO, T/F, 1/0)
#' CASE INSENSITIVE: Converts to uppercase before checking
#'
#' @param x Value to convert (TRUE/FALSE/Y/N/YES/NO/T/F/1/0)
#' @param default Default value if conversion fails (default: FALSE)
#' @return Logical value
#' @export
safe_logical <- function(x, default = FALSE) {
  if (is.null(x) || (length(x) == 1 && is.na(x))) {
    return(default)
  }

  # Already logical
  if (is.logical(x)) {
    return(x)
  }

  # Convert to uppercase string
  x_upper <- toupper(trimws(as.character(x)))

  # Check TRUE values
  if (x_upper %in% c("TRUE", "T", "Y", "YES", "1")) {
    return(TRUE)
  }

  # Check FALSE values
  if (x_upper %in% c("FALSE", "F", "N", "NO", "0")) {
    return(FALSE)
  }

  # Couldn't convert
  warning(sprintf(
    "Could not convert '%s' to logical, using default: %s",
    x, default
  ), call. = FALSE)
  return(default)
}

#' Calculate percentage
#'
#' USAGE: Calculate percentages with automatic 0/0 handling
#' DESIGN: Returns NA_real_ for division by zero (not 0 or error)
#'
#' @param numerator Numeric, numerator
#' @param denominator Numeric, denominator
#' @param decimal_places Integer, decimal places for rounding (default: 0)
#' @return Numeric, percentage (0-100 scale) or NA_real_
#' @export
calc_percentage <- function(numerator, denominator, decimal_places = 0) {
  if (is.na(denominator) || denominator == 0) {
    return(NA_real_)
  }

  return(round((numerator / denominator) * 100, decimal_places))
}
