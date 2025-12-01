# ==============================================================================
# TURAS PRICING MODULE - DATA LOADING AND VALIDATION
# ==============================================================================
#
# Purpose: Load and validate pricing survey data
# Version: 1.0.0
# Date: 2025-11-18
#
# ==============================================================================

#' Load Pricing Survey Data
#'
#' Loads survey data from various file formats for pricing analysis.
#'
#' @param data_file Path to data file (CSV, XLSX, SAV, DTA)
#' @param config Configuration list
#'
#' @return List with data and metadata
#'
#' @keywords internal
load_pricing_data <- function(data_file, config) {

  # Validate file exists
  if (!file.exists(data_file)) {
    stop(sprintf("Data file not found: %s", data_file), call. = FALSE)
  }

  # Determine file type
  file_ext <- tolower(tools::file_ext(data_file))

  # Load based on file type
  data <- switch(
    file_ext,
    "csv" = read.csv(data_file, stringsAsFactors = FALSE, na.strings = c("", "NA", "N/A", "-99")),
    "xlsx" = {
      if (!requireNamespace("readxl", quietly = TRUE)) {
        stop("Package 'readxl' is required for Excel files", call. = FALSE)
      }
      as.data.frame(readxl::read_excel(data_file))
    },
    "xls" = {
      if (!requireNamespace("readxl", quietly = TRUE)) {
        stop("Package 'readxl' is required for Excel files", call. = FALSE)
      }
      as.data.frame(readxl::read_excel(data_file))
    },
    "sav" = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' is required for SPSS files", call. = FALSE)
      }
      as.data.frame(haven::read_sav(data_file))
    },
    "dta" = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' is required for Stata files", call. = FALSE)
      }
      as.data.frame(haven::read_dta(data_file))
    },
    "rds" = readRDS(data_file),
    stop(sprintf("Unsupported file format: %s", file_ext), call. = FALSE)
  )

  # Recode "don't know" codes to NA
  dk_codes <- config$dk_codes
  if (length(dk_codes) > 0) {
    # Get all pricing-related columns
    pricing_cols <- character(0)

    # Van Westendorp columns
    if (!is.null(config$van_westendorp)) {
      vw <- config$van_westendorp
      pricing_cols <- c(pricing_cols,
                       vw$col_too_cheap, vw$col_cheap,
                       vw$col_expensive, vw$col_too_expensive)
    }

    # Gabor-Granger columns
    if (!is.null(config$gabor_granger)) {
      gg <- config$gabor_granger
      if (gg$data_format == "wide" && !is.null(gg$response_columns)) {
        pricing_cols <- c(pricing_cols, gg$response_columns)
      } else if (!is.null(gg$price_column) && !is.null(gg$response_column)) {
        pricing_cols <- c(pricing_cols, gg$price_column, gg$response_column)
      }
    }

    # Recode DK codes to NA in pricing columns
    pricing_cols <- unique(pricing_cols[pricing_cols %in% names(data)])
    for (col in pricing_cols) {
      if (is.numeric(data[[col]])) {
        data[[col]][data[[col]] %in% dk_codes] <- NA
      }
    }
  }

  # Return with metadata
  list(
    data = data,
    n_rows = nrow(data),
    n_cols = ncol(data),
    file_type = file_ext,
    dk_recoded = length(dk_codes) > 0
  )
}


#' Validate Pricing Data
#'
#' Performs comprehensive validation of pricing survey data.
#'
#' @param data Data frame to validate
#' @param config Configuration list
#'
#' @return List with validation results and cleaned data
#'
#' @keywords internal
validate_pricing_data <- function(data, config) {

  warnings_list <- list()
  exclusions <- rep(FALSE, nrow(data))
  exclusion_reasons <- character(nrow(data))

  analysis_method <- tolower(config$analysis_method)

  # --------------------------------------------------------------------------
  # Validate Column Existence
  # --------------------------------------------------------------------------

  if (analysis_method %in% c("van_westendorp", "both")) {
    vw <- config$van_westendorp

    required_cols <- c(
      vw$col_too_cheap,
      vw$col_cheap,
      vw$col_expensive,
      vw$col_too_expensive
    )

    missing_cols <- required_cols[!required_cols %in% names(data)]
    if (length(missing_cols) > 0) {
      stop(sprintf("Van Westendorp columns not found in data: %s\nAvailable columns: %s",
                   paste(missing_cols, collapse = ", "),
                   paste(names(data), collapse = ", ")),
           call. = FALSE)
    }
  }

  if (analysis_method %in% c("gabor_granger", "both")) {
    gg <- config$gabor_granger

    if (gg$data_format == "wide") {
      missing_cols <- gg$response_columns[!gg$response_columns %in% names(data)]
      if (length(missing_cols) > 0) {
        stop(sprintf("Gabor-Granger response columns not found in data: %s",
                     paste(missing_cols, collapse = ", ")),
             call. = FALSE)
      }
    } else {
      required_cols <- c(gg$price_column, gg$response_column)
      missing_cols <- required_cols[!required_cols %in% names(data)]
      if (length(missing_cols) > 0) {
        stop(sprintf("Gabor-Granger columns not found in data: %s",
                     paste(missing_cols, collapse = ", ")),
             call. = FALSE)
      }
    }
  }

  # --------------------------------------------------------------------------
  # Validate Weight Variable
  # --------------------------------------------------------------------------

  weight_summary <- NULL
  if (!is.na(config$weight_var)) {
    if (!config$weight_var %in% names(data)) {
      stop(sprintf("Weight variable '%s' not found in data.\nAvailable columns: %s",
                   config$weight_var,
                   paste(names(data), collapse = ", ")),
           call. = FALSE)
    }

    # Coerce to numeric
    data[[config$weight_var]] <- suppressWarnings(as.numeric(data[[config$weight_var]]))

    # Flag invalid weights
    invalid_weight <- is.na(data[[config$weight_var]]) |
                      !is.finite(data[[config$weight_var]]) |
                      data[[config$weight_var]] < 0

    if (any(invalid_weight)) {
      exclusions[invalid_weight] <- TRUE
      exclusion_reasons[invalid_weight] <- paste0(
        exclusion_reasons[invalid_weight],
        ifelse(exclusion_reasons[invalid_weight] == "", "", "; "),
        "invalid_weight"
      )
      warnings_list[[length(warnings_list) + 1]] <- sprintf(
        "Weight variable has %d invalid values (NA, negative, or non-finite) - cases excluded",
        sum(invalid_weight)
      )
    }

    # Calculate weight summary for diagnostics
    valid_weights <- data[[config$weight_var]][!invalid_weight]
    weight_summary <- list(
      n_total = length(data[[config$weight_var]]),
      n_valid = sum(!invalid_weight),
      n_invalid = sum(invalid_weight),
      n_zero = sum(valid_weights == 0, na.rm = TRUE),
      min = min(valid_weights, na.rm = TRUE),
      max = max(valid_weights, na.rm = TRUE),
      mean = mean(valid_weights, na.rm = TRUE),
      sd = sd(valid_weights, na.rm = TRUE)
    )
  }

  # --------------------------------------------------------------------------
  # Validate Data Types and Ranges
  # --------------------------------------------------------------------------

  validation_config <- config$validation %||% get_default_validation()

  if (analysis_method %in% c("van_westendorp", "both")) {
    vw <- config$van_westendorp

    price_cols <- c(
      vw$col_too_cheap,
      vw$col_cheap,
      vw$col_expensive,
      vw$col_too_expensive
    )

    for (col in price_cols) {
      # Convert to numeric if needed
      if (!is.numeric(data[[col]])) {
        data[[col]] <- suppressWarnings(as.numeric(data[[col]]))
        warnings_list[[length(warnings_list) + 1]] <- sprintf(
          "Column '%s' converted to numeric", col
        )
      }

      # Check for missing values
      n_missing <- sum(is.na(data[[col]]))
      if (n_missing > 0) {
        warnings_list[[length(warnings_list) + 1]] <- sprintf(
          "Column '%s' has %d missing values (%.1f%%)",
          col, n_missing, 100 * n_missing / nrow(data)
        )
      }

      # Check range
      price_min <- as.numeric(validation_config$price_min %||% 0)
      price_max <- as.numeric(validation_config$price_max %||% 10000)

      out_of_range <- which(!is.na(data[[col]]) &
                             (data[[col]] < price_min | data[[col]] > price_max))
      if (length(out_of_range) > 0) {
        exclusions[out_of_range] <- TRUE
        exclusion_reasons[out_of_range] <- paste0(
          exclusion_reasons[out_of_range],
          sprintf("; %s out of range", col)
        )
        warnings_list[[length(warnings_list) + 1]] <- sprintf(
          "Column '%s' has %d values outside valid range [%.0f-%.0f]",
          col, length(out_of_range), price_min, price_max
        )
      }
    }

    # Check monotonicity
    if (isTRUE(vw$validate_monotonicity)) {
      violations <- check_vw_monotonicity(
        data[[vw$col_too_cheap]],
        data[[vw$col_cheap]],
        data[[vw$col_expensive]],
        data[[vw$col_too_expensive]]
      )

      if (violations$count > 0) {
        violation_rate <- violations$rate

        if (isTRUE(vw$exclude_violations)) {
          exclusions[violations$violation_indices] <- TRUE
          exclusion_reasons[violations$violation_indices] <- paste0(
            exclusion_reasons[violations$violation_indices],
            "; monotonicity violation"
          )
        }

        if (violation_rate > (vw$violation_threshold %||% 0.1)) {
          warnings_list[[length(warnings_list) + 1]] <- sprintf(
            "Monotonicity violations: %d cases (%.1f%%) - exceeds threshold of %.0f%%",
            violations$count, violation_rate * 100, (vw$violation_threshold %||% 0.1) * 100
          )
        } else {
          warnings_list[[length(warnings_list) + 1]] <- sprintf(
            "Monotonicity violations: %d cases (%.1f%%)",
            violations$count, violation_rate * 100
          )
        }
      }
    }
  }

  if (analysis_method %in% c("gabor_granger", "both")) {
    gg <- config$gabor_granger

    if (gg$data_format == "wide") {
      for (col in gg$response_columns) {
        # Check for missing values
        n_missing <- sum(is.na(data[[col]]))
        if (n_missing > 0) {
          warnings_list[[length(warnings_list) + 1]] <- sprintf(
            "Column '%s' has %d missing values (%.1f%%)",
            col, n_missing, 100 * n_missing / nrow(data)
          )
        }
      }
    }
  }

  # --------------------------------------------------------------------------
  # Check Completeness
  # --------------------------------------------------------------------------

  min_completeness <- as.numeric(validation_config$min_completeness %||% 0.8)

  if (analysis_method %in% c("van_westendorp", "both")) {
    vw <- config$van_westendorp
    price_cols <- c(vw$col_too_cheap, vw$col_cheap, vw$col_expensive, vw$col_too_expensive)
    n_complete <- rowSums(!is.na(data[, price_cols, drop = FALSE]))
    incomplete <- n_complete < (length(price_cols) * min_completeness)

    exclusions[incomplete] <- TRUE
    exclusion_reasons[incomplete] <- paste0(exclusion_reasons[incomplete], "; incomplete VW responses")
  }

  # --------------------------------------------------------------------------
  # Prepare Clean Data
  # --------------------------------------------------------------------------

  clean_data <- data[!exclusions, , drop = FALSE]

  # --------------------------------------------------------------------------
  # Return Results
  # --------------------------------------------------------------------------

  list(
    clean_data = clean_data,
    n_total = nrow(data),
    n_excluded = sum(exclusions),
    n_valid = sum(!exclusions),
    exclusion_mask = exclusions,
    exclusion_reasons = exclusion_reasons,
    warnings = warnings_list,
    n_warnings = length(warnings_list),
    weight_summary = weight_summary
  )
}


#' Check Van Westendorp Monotonicity
#'
#' Validates that price responses follow logical sequence:
#' too_cheap <= cheap <= expensive <= too_expensive
#'
#' @param too_cheap Vector of "too cheap" prices
#' @param cheap Vector of "bargain/cheap" prices
#' @param expensive Vector of "expensive" prices
#' @param too_expensive Vector of "too expensive" prices
#'
#' @return List with violation count, rate, and indices
#'
#' @keywords internal
check_vw_monotonicity <- function(too_cheap, cheap, expensive, too_expensive) {

  n <- length(too_cheap)

  # Check logical sequence
  violations <- rep(FALSE, n)

  # Check: too_cheap <= cheap
  violations <- violations | (!is.na(too_cheap) & !is.na(cheap) & too_cheap > cheap)

  # Check: cheap <= expensive
  violations <- violations | (!is.na(cheap) & !is.na(expensive) & cheap > expensive)

  # Check: expensive <= too_expensive
  violations <- violations | (!is.na(expensive) & !is.na(too_expensive) & expensive > too_expensive)

  # Ignore cases with missing values
  all_present <- !is.na(too_cheap) & !is.na(cheap) & !is.na(expensive) & !is.na(too_expensive)
  n_testable <- sum(all_present)

  violations_in_testable <- violations & all_present

  list(
    count = sum(violations_in_testable),
    rate = if (n_testable > 0) sum(violations_in_testable) / n_testable else 0,
    valid_cases = !violations,
    violation_indices = which(violations_in_testable)
  )
}


#' Get Default Validation Settings
#'
#' @return Default validation configuration
#' @keywords internal
get_default_validation <- function() {
  list(
    min_completeness = 0.8,
    price_min = 0,
    price_max = 10000,
    flag_outliers = TRUE,
    outlier_method = "iqr",
    outlier_threshold = 3
  )
}
