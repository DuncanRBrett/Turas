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

  # Get weight variable if specified
  weight_var <- config$weight_var

  # Build variable list: outcome + drivers + weight (if present)
  base_vars <- c(config$outcome_var, config$driver_vars)
  all_vars <- unique(c(base_vars, weight_var))

  # Validate required variables exist
  missing_vars <- setdiff(base_vars, names(data))
  if (length(missing_vars) > 0) {
    stop("Missing variables in data: ", paste(missing_vars, collapse = ", "),
         call. = FALSE)
  }

  # Check weight variable exists if specified
  if (!is.null(weight_var) && !weight_var %in% names(data)) {
    stop("Weight variable '", weight_var, "' not found in data.", call. = FALSE)
  }

  # Select only relevant variables
  data <- data[, all_vars, drop = FALSE]

  # Convert outcome and drivers to numeric if needed
  for (var in base_vars) {
    if (!is.numeric(data[[var]])) {
      data[[var]] <- as.numeric(as.character(data[[var]]))
    }
  }

  # Convert weight to numeric if specified
  if (!is.null(weight_var)) {
    if (!is.numeric(data[[weight_var]])) {
      data[[weight_var]] <- as.numeric(as.character(data[[weight_var]]))
    }
  }

  # Define complete cases:
  #  - all base_vars non-missing
  #  - weight non-missing and > 0 (if weight is used)
  complete_cases <- stats::complete.cases(data[, base_vars, drop = FALSE])

  if (!is.null(weight_var)) {
    w <- data[[weight_var]]
    valid_w <- !is.na(w) & w > 0
    complete_cases <- complete_cases & valid_w
  }

  n_complete <- sum(complete_cases)
  n_missing <- nrow(data) - n_complete

  if (n_missing > 0) {
    warning(sprintf(
      "%d rows will be excluded due to missing values and/or invalid weights (%.1f%%)",
      n_missing, 100 * n_missing / nrow(data)
    ))
  }

  # IMPROVED: Sample size rule based on number of drivers
  # Rule of thumb: n >= max(30, 10 * number_of_drivers)
  n_drivers <- length(config$driver_vars)
  min_n <- max(30L, 10L * n_drivers)

  if (n_complete < min_n) {
    stop(
      sprintf(
        "Insufficient complete cases (%d). Need at least %d given %d driver(s).",
        n_complete, min_n, n_drivers
      ),
      call. = FALSE
    )
  }

  # Filter to complete cases
  data <- data[complete_cases, , drop = FALSE]

  # NEW: Zero-variance checks after filtering
  sds <- vapply(base_vars, function(v) stats::sd(data[[v]], na.rm = TRUE), numeric(1))
  zero_var <- sds == 0

  if (any(zero_var)) {
    offending <- base_vars[zero_var]
    stop(
      "The following variables have zero variance and cannot be used in key driver analysis: ",
      paste(offending, collapse = ", "),
      call. = FALSE
    )
  }

  list(
    data = data,
    n_respondents = nrow(data),
    n_complete = n_complete,
    n_missing = n_missing
  )
}
