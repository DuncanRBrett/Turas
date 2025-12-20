# ==============================================================================
# KEY DRIVER - TERM-TO-DRIVER MAPPING LAYER
# ==============================================================================
#
# TRS Mixed Predictors Specification Implementation
#
# This module provides the mandatory term-to-driver mapping layer for
# mixed predictor support (continuous, categorical, ordinal).
#
# Core Functions:
#   - build_term_mapping(): Build mapping from model coefficients to drivers
#   - validate_term_mapping(): TRS mapping gate (REFUSES on mismatch)
#   - enforce_encoding_policy(): Apply encoding policy for factors/ordered
#   - get_predictor_info(): Get predictor type information for console output
#
# Version: 1.0 (Mixed Predictor Support)
# Date: December 2024
#
# ==============================================================================


# ==============================================================================
# TERM-TO-DRIVER MAPPING
# ==============================================================================

#' Build Term-to-Driver Mapping
#'
#' Creates a mapping from model coefficient names to driver variables
#' using model.matrix(). This is mandatory for mixed predictor support.
#'
#' @param formula Model formula
#' @param data Data frame with driver variables
#' @param driver_vars Character vector of driver variable names
#' @return List containing:
#'   - term_map: Named character vector (term -> driver)
#'   - driver_terms: Named list (driver -> vector of terms)
#'   - predictor_info: Data frame with predictor type info
#' @export
build_term_mapping <- function(formula, data, driver_vars) {

  # Build model matrix to get all coefficient terms
  # This handles factor expansion automatically
  mm <- stats::model.matrix(formula, data = data)
  all_terms <- colnames(mm)

  # Remove intercept from terms to map
  terms_to_map <- setdiff(all_terms, "(Intercept)")

  # Initialize mapping structures
  term_map <- character(length(terms_to_map))
  names(term_map) <- terms_to_map

  driver_terms <- setNames(vector("list", length(driver_vars)), driver_vars)

  # Collect predictor info
  predictor_info <- data.frame(
    driver = driver_vars,
    type = character(length(driver_vars)),
    n_terms = integer(length(driver_vars)),
    reference_level = character(length(driver_vars)),
    stringsAsFactors = FALSE
  )

  # Map each term to its originating driver
  for (i in seq_along(driver_vars)) {
    drv <- driver_vars[i]

    # Determine predictor type
    if (drv %in% names(data)) {
      var_data <- data[[drv]]

      if (is.factor(var_data)) {
        if (is.ordered(var_data)) {
          predictor_info$type[i] <- "ordered"
        } else {
          predictor_info$type[i] <- "categorical"
        }
        # Reference level is the first level (excluded from coefficients)
        predictor_info$reference_level[i] <- levels(var_data)[1]
      } else if (is.character(var_data)) {
        # Will be coerced to factor
        predictor_info$type[i] <- "categorical"
        predictor_info$reference_level[i] <- sort(unique(var_data))[1]
      } else if (is.numeric(var_data)) {
        predictor_info$type[i] <- "continuous"
        predictor_info$reference_level[i] <- NA_character_
      } else {
        predictor_info$type[i] <- "other"
        predictor_info$reference_level[i] <- NA_character_
      }
    } else {
      predictor_info$type[i] <- "unknown"
      predictor_info$reference_level[i] <- NA_character_
    }

    # Find terms belonging to this driver
    # For factors: term starts with driver name followed by level name
    # For numeric: term equals driver name exactly
    matching_terms <- character(0)

    for (term in terms_to_map) {
      # Exact match (continuous predictors)
      if (term == drv) {
        matching_terms <- c(matching_terms, term)
        term_map[term] <- drv
      }
      # Prefix match (factor levels: "driverLevel")
      else if (startsWith(term, drv) &&
               nchar(term) > nchar(drv) &&
               # Make sure it's actually a factor level, not another variable with similar prefix
               !any(startsWith(term, paste0(drv, ".")) |
                    term == paste0(drv, "TRUE") |
                    term == paste0(drv, "FALSE"))) {
        # Additional check: the suffix should be a level of the factor
        suffix <- substring(term, nchar(drv) + 1)
        if (predictor_info$type[i] %in% c("categorical", "ordered")) {
          # Check if this is a valid level
          if (drv %in% names(data)) {
            var_levels <- if (is.factor(data[[drv]])) {
              levels(data[[drv]])
            } else {
              unique(as.character(data[[drv]]))
            }
            if (suffix %in% var_levels) {
              matching_terms <- c(matching_terms, term)
              term_map[term] <- drv
            }
          }
        }
      }
      # Handle TRUE/FALSE for logical (treated as factor)
      else if (term %in% c(paste0(drv, "TRUE"), paste0(drv, "FALSE"))) {
        matching_terms <- c(matching_terms, term)
        term_map[term] <- drv
      }
    }

    driver_terms[[drv]] <- matching_terms
    predictor_info$n_terms[i] <- length(matching_terms)
  }

  list(
    term_map = term_map,
    driver_terms = driver_terms,
    predictor_info = predictor_info,
    all_terms = terms_to_map
  )
}


#' Validate Term Mapping (TRS Gate)
#'
#' Performs mandatory TRS mapping validation. REFUSES if any driver
#' cannot be mapped or if there are unmapped model terms.
#'
#' @param mapping Result from build_term_mapping()
#' @param driver_vars Expected driver variables
#' @return TRUE if validation passes (never returns FALSE - refuses instead)
#' @export
validate_term_mapping <- function(mapping, driver_vars) {

  term_map <- mapping$term_map
  driver_terms <- mapping$driver_terms

  # Get observed drivers (those with at least one mapped term)
  observed_drivers <- unique(as.character(term_map[term_map != ""]))

  # Check for missing drivers (expected but not in model)
  missing_drivers <- setdiff(driver_vars, observed_drivers)

  # Check for unmapped terms (in model but not attributed to any driver)
  all_model_terms <- names(term_map)
  mapped_terms <- names(term_map)[term_map != ""]
  unmapped_terms <- setdiff(all_model_terms, mapped_terms)

  # TRS: REFUSE if any mismatch
  if (length(missing_drivers) > 0 || length(unmapped_terms) > 0) {
    keydriver_refuse(
      code = "MAPPER_TERM_MISMATCH",
      title = "Term-to-Driver Mapping Failed",
      problem = paste0(
        if (length(missing_drivers) > 0)
          paste0(length(missing_drivers), " driver(s) produced no model terms. "),
        if (length(unmapped_terms) > 0)
          paste0(length(unmapped_terms), " model term(s) could not be mapped to drivers.")
      ),
      why_it_matters = paste0(
        "Mixed predictor analysis requires mapping all model coefficients to their ",
        "originating driver variables. Without complete mapping, importance scores ",
        "would be incomplete or incorrectly attributed."
      ),
      how_to_fix = c(
        if (length(missing_drivers) > 0)
          "Check that missing drivers have variation in the data",
        if (length(unmapped_terms) > 0)
          "Verify that unmapped terms correspond to expected driver variables",
        "Ensure categorical drivers are properly encoded as factors",
        "Check for unexpected interaction terms or polynomial expansions"
      ),
      expected = driver_vars,
      observed = observed_drivers,
      missing = if (length(missing_drivers) > 0) missing_drivers else NULL,
      unmapped = if (length(unmapped_terms) > 0) unmapped_terms else NULL
    )
  }

  TRUE
}


# ==============================================================================
# PREDICTOR ENCODING POLICY
# ==============================================================================

#' Enforce Predictor Encoding Policy
#'
#' Applies TRS-mandated encoding policy for categorical and ordinal predictors.
#'
#' Policy (per Mixed Predictor Spec):
#'   - Unordered factors: treatment contrasts with deterministic reference
#'   - Ordered factors: treatment contrasts (polynomial FORBIDDEN unless explicit)
#'   - Reference level: explicit in config, or first level after ordering
#'
#' @param data Data frame with driver variables
#' @param driver_vars Character vector of driver variable names
#' @param driver_settings Optional driver settings from config
#' @param allow_polynomial Logical, allow polynomial contrasts for ordered (default FALSE)
#' @return List with:
#'   - data: Modified data frame with proper encoding
#'   - encoding_report: Data frame documenting encoding applied
#' @export
enforce_encoding_policy <- function(data,
                                     driver_vars,
                                     driver_settings = NULL,
                                     allow_polynomial = FALSE) {

  encoding_report <- data.frame(
    driver = character(0),
    original_class = character(0),
    encoded_as = character(0),
    contrasts = character(0),
    reference_level = character(0),
    n_levels = integer(0),
    stringsAsFactors = FALSE
  )

  for (drv in driver_vars) {
    if (!drv %in% names(data)) next

    var_data <- data[[drv]]
    original_class <- paste(class(var_data), collapse = ", ")

    # Get driver-specific settings if available
    ref_level <- NULL
    if (!is.null(driver_settings) && is.data.frame(driver_settings)) {
      idx <- which(driver_settings$driver == drv)
      if (length(idx) > 0) {
        ref_level <- driver_settings$reference_level[idx[1]]
        if (is.na(ref_level) || !nzchar(trimws(ref_level))) {
          ref_level <- NULL
        }
      }
    }

    # Handle different predictor types
    if (is.factor(var_data)) {

      if (is.ordered(var_data)) {
        # Ordered factor - check for polynomial contrasts
        current_contrasts <- attr(var_data, "contrasts")
        is_polynomial <- !is.null(current_contrasts) &&
                         any(grepl("poly", class(current_contrasts)))

        if (is_polynomial && !allow_polynomial) {
          keydriver_refuse(
            code = "CFG_POLYNOMIAL_CONTRASTS_FORBIDDEN",
            title = "Polynomial Contrasts Detected",
            problem = paste0("Ordered factor '", drv, "' has polynomial contrasts."),
            why_it_matters = paste0(
              "Polynomial contrasts create multiple coefficients per level that cannot ",
              "be cleanly mapped to driver-level importance. Treatment contrasts are required."
            ),
            how_to_fix = c(
              "Remove the ordered() designation and use regular factor",
              "Or set 'allow_polynomial=TRUE' if you understand the implications",
              "Recommended: Use treatment contrasts for interpretable importance"
            )
          )
        }

        # Apply treatment contrasts to ordered factors
        contrasts(data[[drv]]) <- "contr.treatment"

        encoding_report <- rbind(encoding_report, data.frame(
          driver = drv,
          original_class = original_class,
          encoded_as = "ordered_factor",
          contrasts = "treatment",
          reference_level = levels(var_data)[1],
          n_levels = nlevels(var_data),
          stringsAsFactors = FALSE
        ))

      } else {
        # Unordered factor - treatment contrasts
        # Apply reference level if specified
        if (!is.null(ref_level) && ref_level %in% levels(var_data)) {
          data[[drv]] <- relevel(var_data, ref = ref_level)
        }

        contrasts(data[[drv]]) <- "contr.treatment"

        encoding_report <- rbind(encoding_report, data.frame(
          driver = drv,
          original_class = original_class,
          encoded_as = "factor",
          contrasts = "treatment",
          reference_level = levels(data[[drv]])[1],
          n_levels = nlevels(var_data),
          stringsAsFactors = FALSE
        ))
      }

    } else if (is.character(var_data)) {
      # Convert character to factor with treatment contrasts
      data[[drv]] <- factor(var_data)

      if (!is.null(ref_level) && ref_level %in% levels(data[[drv]])) {
        data[[drv]] <- relevel(data[[drv]], ref = ref_level)
      }

      contrasts(data[[drv]]) <- "contr.treatment"

      encoding_report <- rbind(encoding_report, data.frame(
        driver = drv,
        original_class = original_class,
        encoded_as = "factor",
        contrasts = "treatment",
        reference_level = levels(data[[drv]])[1],
        n_levels = nlevels(data[[drv]]),
        stringsAsFactors = FALSE
      ))

    } else if (is.numeric(var_data)) {
      # Continuous - no encoding needed
      encoding_report <- rbind(encoding_report, data.frame(
        driver = drv,
        original_class = original_class,
        encoded_as = "numeric",
        contrasts = "N/A",
        reference_level = NA_character_,
        n_levels = NA_integer_,
        stringsAsFactors = FALSE
      ))

    } else if (is.logical(var_data)) {
      # Logical - convert to factor
      data[[drv]] <- factor(var_data, levels = c(FALSE, TRUE))
      contrasts(data[[drv]]) <- "contr.treatment"

      encoding_report <- rbind(encoding_report, data.frame(
        driver = drv,
        original_class = original_class,
        encoded_as = "factor",
        contrasts = "treatment",
        reference_level = "FALSE",
        n_levels = 2L,
        stringsAsFactors = FALSE
      ))
    }
  }

  list(
    data = data,
    encoding_report = encoding_report
  )
}


#' Check if Any Predictor is Categorical
#'
#' @param data Data frame
#' @param driver_vars Driver variable names
#' @return Logical TRUE if any driver is a factor/character
#' @export
has_categorical_predictors <- function(data, driver_vars) {
  for (drv in driver_vars) {
    if (drv %in% names(data)) {
      if (is.factor(data[[drv]]) || is.character(data[[drv]]) || is.logical(data[[drv]])) {
        return(TRUE)
      }
    }
  }
  FALSE
}


#' Get Numeric Predictors Only
#'
#' Returns subset of driver_vars that are numeric.
#'
#' @param data Data frame
#' @param driver_vars Driver variable names
#' @return Character vector of numeric driver names
#' @export
get_numeric_drivers <- function(data, driver_vars) {
  numeric_drivers <- character(0)
  for (drv in driver_vars) {
    if (drv %in% names(data) && is.numeric(data[[drv]])) {
      numeric_drivers <- c(numeric_drivers, drv)
    }
  }
  numeric_drivers
}


# ==============================================================================
# CONSOLE OUTPUT HELPERS
# ==============================================================================

#' Print Predictor Encoding Summary
#'
#' Displays encoding information per TRS console requirements.
#'
#' @param encoding_report Encoding report from enforce_encoding_policy()
#' @export
print_encoding_summary <- function(encoding_report) {

  cat("\n   [PREDICTOR ENCODING]\n")

  for (i in seq_len(nrow(encoding_report))) {
    row <- encoding_report[i, ]
    if (row$encoded_as == "numeric") {
      cat(sprintf("   - %s: continuous\n", row$driver))
    } else if (row$encoded_as %in% c("factor", "ordered_factor")) {
      cat(sprintf("   - %s: %s (%d levels, ref='%s')\n",
                  row$driver,
                  if (row$encoded_as == "ordered_factor") "ordered" else "categorical",
                  row$n_levels,
                  row$reference_level))
    } else {
      cat(sprintf("   - %s: %s\n", row$driver, row$encoded_as))
    }
  }

  cat("\n")
}


#' Print Term Mapping Summary
#'
#' Displays term mapping information.
#'
#' @param mapping Result from build_term_mapping()
#' @export
print_term_mapping_summary <- function(mapping) {

  cat("   [TERM MAPPING]\n")

  info <- mapping$predictor_info
  for (i in seq_len(nrow(info))) {
    row <- info[i, ]
    cat(sprintf("   - %s: %d term(s)\n", row$driver, row$n_terms))
  }

  cat(sprintf("   Total model terms: %d\n", length(mapping$all_terms)))
  cat("\n")
}
