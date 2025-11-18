# ==============================================================================
# KEY DRIVER DATA VALIDATION
# ==============================================================================

#' Load Key Driver Data
#'
#' Loads and validates data for key driver analysis.
#'
#' @param data_file Path to data file
#' @param config Configuration list
#' @return List with validated data
#' @keywords internal
load_keydriver_data <- function(data_file, config) {

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

  # Convert to data frame
  data <- as.data.frame(data)

  # Validate required variables exist
  all_vars <- c(config$outcome_var, config$driver_vars)
  missing_vars <- setdiff(all_vars, names(data))

  if (length(missing_vars) > 0) {
    stop("Missing variables in data: ", paste(missing_vars, collapse = ", "),
         call. = FALSE)
  }

  # Select only relevant variables
  data <- data[, all_vars, drop = FALSE]

  # Convert to numeric if needed
  for (var in all_vars) {
    if (!is.numeric(data[[var]])) {
      data[[var]] <- as.numeric(as.character(data[[var]]))
    }
  }

  # Count complete cases
  complete_cases <- complete.cases(data)
  n_complete <- sum(complete_cases)
  n_missing <- nrow(data) - n_complete

  if (n_missing > 0) {
    warning(sprintf("%d rows with missing data will be excluded (%.1f%%)",
                    n_missing, 100 * n_missing / nrow(data)))
  }

  if (n_complete < 30) {
    stop("Insufficient complete cases (", n_complete, "). Need at least 30.",
         call. = FALSE)
  }

  # Filter to complete cases
  data <- data[complete_cases, ]

  list(
    data = data,
    n_respondents = nrow(data),
    n_complete = n_complete,
    n_missing = n_missing
  )
}
