# ==============================================================================
# CONJOINT DATA VALIDATION
# ==============================================================================

#' Load Conjoint Data
#'
#' Loads and validates conjoint experimental data.
#'
#' @param data_file Path to data file (CSV, XLSX, SAV, DTA)
#' @param config Configuration list from load_conjoint_config()
#' @return List with validated data
#' @keywords internal
load_conjoint_data <- function(data_file, config) {

  if (!file.exists(data_file)) {
    stop("Data file not found: ", data_file, call. = FALSE)
  }

  # Detect file type and load
  file_ext <- tolower(tools::file_ext(data_file))

  data <- switch(file_ext,
    "csv" = utils::read.csv(data_file, stringsAsFactors = FALSE),
    "xlsx" = openxlsx::read.xlsx(data_file),
    "sav" = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' required for SPSS files. Install with: install.packages('haven')",
             call. = FALSE)
      }
      haven::read_sav(data_file)
    },
    "dta" = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' required for Stata files. Install with: install.packages('haven')",
             call. = FALSE)
      }
      haven::read_dta(data_file)
    },
    stop("Unsupported file format: ", file_ext, call. = FALSE)
  )

  # Convert to data frame (in case of tibble)
  data <- as.data.frame(data)

  # Validate required columns exist
  # TODO: Implement specific validation based on design type
  # - For choice-based: need respondent_id, profile_id, attributes, choice
  # - For rating-based: need respondent_id, profile_id, attributes, rating

  # Basic validation
  if (nrow(data) == 0) {
    stop("Data file is empty", call. = FALSE)
  }

  # Count respondents and profiles
  respondent_id_col <- config$settings$respondent_id_column %||% "resp_id"
  choice_set_col <- config$settings$choice_set_column %||% "choice_set_id"

  n_respondents <- if (respondent_id_col %in% names(data)) {
    length(unique(data[[respondent_id_col]]))
  } else {
    NA
  }

  # Count total rows (alternatives across all choice sets)
  n_total_rows <- nrow(data)

  # Count unique choice sets
  n_choice_sets <- if (choice_set_col %in% names(data)) {
    length(unique(data[[choice_set_col]]))
  } else {
    NA
  }

  list(
    data = data,
    n_respondents = n_respondents,
    n_profiles = n_total_rows,
    n_choice_sets = n_choice_sets
  )
}

#' @keywords internal
`%||%` <- function(x, y) if (is.null(x)) y else x
