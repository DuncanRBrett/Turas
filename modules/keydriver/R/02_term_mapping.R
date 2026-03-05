# ==============================================================================
# KEY DRIVER - TERM-TO-DRIVER MAPPING LAYER
# ==============================================================================
# TRS Mixed Predictors Specification Implementation
#
# Core Functions:
#   build_term_mapping()               - Map model coefficients to drivers
#   validate_term_mapping()            - TRS mapping gate (REFUSES on mismatch)
#   enforce_encoding_policy()          - Apply encoding policy for factors/ordered
#   validate_driver_type_consistency() - Check config vs data consistency
#
# Helpers:
#   find_matching_terms()  - Match model terms to a single driver variable
#   get_valid_driver_types / get_valid_agg_methods - Config value enums
#
# Version: 1.2 (Refactored - merged v1/v2 into single function)
# ==============================================================================

# --- Local utilities ---------------------------------------------------------

#' Null-Coalescing Operator
#' @param a Value to test
#' @param b Fallback value
#' @return \code{a} if not NULL, otherwise \code{b}
#' @keywords internal
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

#' Get Valid Driver Types
#' @return Character vector of valid driver type strings
#' @keywords internal
get_valid_driver_types <- function() {
  c("continuous", "ordinal", "categorical")
}

#' Get Valid Aggregation Methods
#' @return Character vector of valid aggregation method strings
#' @keywords internal
get_valid_agg_methods <- function() {
  c("partial_r2", "grouped_permutation", "grouped_shapley")
}

# ==============================================================================
# TERM-TO-DRIVER MAPPING
# ==============================================================================

#' Find Terms Matching a Driver Variable
#'
#' Searches model coefficient names for terms belonging to a given driver.
#' Handles exact matches (continuous), prefix matches with level validation
#' (categorical/ordinal factors), and TRUE/FALSE suffixes (logicals).
#'
#' @param terms_to_map Character vector of model coefficient names (excl. intercept)
#' @param drv Character scalar, the driver variable name
#' @param data Data frame containing the driver variable
#' @param predictor_type Character scalar: "continuous", "categorical", "ordered",
#'   "ordinal", "other", or "unknown"
#' @return Character vector of terms that belong to \code{drv}
#' @keywords internal
find_matching_terms <- function(terms_to_map, drv, data, predictor_type) {
  matching_terms <- character(0)
  for (term in terms_to_map) {
    # Exact match (continuous predictors)
    if (term == drv) {
      matching_terms <- c(matching_terms, term)
      next
    }
    # Prefix match (factor levels: "driverLevel")
    if (startsWith(term, drv) &&
        nchar(term) > nchar(drv) &&
        !any(startsWith(term, paste0(drv, ".")) |
             term == paste0(drv, "TRUE") |
             term == paste0(drv, "FALSE"))) {
      suffix <- substring(term, nchar(drv) + 1)
      if (predictor_type %in% c("categorical", "ordered", "ordinal")) {
        if (drv %in% names(data)) {
          var_levels <- if (is.factor(data[[drv]])) levels(data[[drv]]) else unique(as.character(data[[drv]]))
          if (suffix %in% var_levels) {
            matching_terms <- c(matching_terms, term)
          }
        }
      }
      next
    }
    # Handle TRUE/FALSE for logical (treated as factor)
    if (term %in% c(paste0(drv, "TRUE"), paste0(drv, "FALSE"))) {
      matching_terms <- c(matching_terms, term)
    }
  }
  matching_terms
}


#' Build Term-to-Driver Mapping
#'
#' Creates a mapping from model coefficient names to driver variables using
#' model.matrix(). When \code{driver_settings} is provided, predictor types
#' are read from the config via \code{get_driver_type()}. When NULL (default),
#' types are inferred directly from the data (legacy behaviour).
#'
#' @param formula Model formula
#' @param data Data frame with driver variables
#' @param driver_vars Character vector of driver variable names
#' @param driver_settings Optional driver settings data frame from config.
#'   When NULL (the default), types are inferred from \code{data}.
#' @return List with term_map, driver_terms, predictor_info, all_terms
#' @export
build_term_mapping <- function(formula, data, driver_vars, driver_settings = NULL) {

  mm <- stats::model.matrix(formula, data = data)
  terms_to_map <- setdiff(colnames(mm), "(Intercept)")

  term_map <- setNames(character(length(terms_to_map)), terms_to_map)
  driver_terms <- setNames(vector("list", length(driver_vars)), driver_vars)
  use_config <- !is.null(driver_settings)

  predictor_info <- data.frame(
    driver = driver_vars,
    type = character(length(driver_vars)),
    n_terms = integer(length(driver_vars)),
    reference_level = character(length(driver_vars)),
    stringsAsFactors = FALSE
  )

  # Determine type and reference level for each driver
  for (i in seq_along(driver_vars)) {
    drv <- driver_vars[i]
    if (use_config) {
      # Config-declared type
      predictor_info$type[i] <- get_driver_type(drv, driver_settings) %||% "continuous"
      if (drv %in% names(data)) {
        var_data <- data[[drv]]
        drv_type <- predictor_info$type[i]
        if (drv_type %in% c("categorical", "ordinal")) {
          if (is.factor(var_data)) {
            predictor_info$reference_level[i] <- levels(var_data)[1]
          } else if (is.character(var_data)) {
            predictor_info$reference_level[i] <- sort(unique(var_data))[1]
          } else {
            predictor_info$reference_level[i] <- NA_character_
          }
        } else {
          predictor_info$reference_level[i] <- NA_character_
        }
      }
    } else {
      # Data-inferred type (legacy)
      if (drv %in% names(data)) {
        var_data <- data[[drv]]
        if (is.factor(var_data)) {
          predictor_info$type[i] <- if (is.ordered(var_data)) "ordered" else "categorical"
          predictor_info$reference_level[i] <- levels(var_data)[1]
        } else if (is.character(var_data)) {
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
    }
  }

  # Map each term to its originating driver
  for (i in seq_along(driver_vars)) {
    drv <- driver_vars[i]
    matching <- find_matching_terms(terms_to_map, drv, data, predictor_info$type[i])
    for (term in matching) term_map[term] <- drv
    driver_terms[[drv]] <- matching
    predictor_info$n_terms[i] <- length(matching)
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
#' REFUSES if any driver cannot be mapped or if unmapped model terms exist.
#'
#' @param mapping Result from build_term_mapping()
#' @param driver_vars Expected driver variables
#' @return TRUE if validation passes (refuses on mismatch, never returns FALSE)
#' @export
validate_term_mapping <- function(mapping, driver_vars) {
  term_map <- mapping$term_map
  observed_drivers <- unique(as.character(term_map[term_map != ""]))
  missing_drivers <- setdiff(driver_vars, observed_drivers)
  mapped_terms <- names(term_map)[term_map != ""]
  unmapped_terms <- setdiff(names(term_map), mapped_terms)

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
#' Applies TRS-mandated encoding: treatment contrasts for factors/ordered,
#' deterministic reference levels. Polynomial contrasts FORBIDDEN by default.
#'
#' @param data Data frame with driver variables
#' @param driver_vars Character vector of driver variable names
#' @param driver_settings Optional driver settings from config
#' @param allow_polynomial Logical, allow polynomial contrasts (default FALSE)
#' @return List with data (modified) and encoding_report (data frame)
#' @export
enforce_encoding_policy <- function(data,
                                     driver_vars,
                                     driver_settings = NULL,
                                     allow_polynomial = FALSE) {
  # Helper to append one row to the encoding report
  add_row <- function(rpt, drv, orig, enc, ctr, ref, nlev) {
    rbind(rpt, data.frame(driver = drv, original_class = orig, encoded_as = enc,
                          contrasts = ctr, reference_level = ref, n_levels = nlev,
                          stringsAsFactors = FALSE))
  }

  encoding_report <- data.frame(
    driver = character(0), original_class = character(0),
    encoded_as = character(0), contrasts = character(0),
    reference_level = character(0), n_levels = integer(0),
    stringsAsFactors = FALSE
  )

  for (drv in driver_vars) {
    if (!drv %in% names(data)) next
    var_data <- data[[drv]]
    original_class <- paste(class(var_data), collapse = ", ")

    # Get driver-specific reference level from settings
    ref_level <- NULL
    if (!is.null(driver_settings) && is.data.frame(driver_settings)) {
      idx <- which(driver_settings$driver == drv)
      if (length(idx) > 0) {
        ref_level <- driver_settings$reference_level[idx[1]]
        if (is.na(ref_level) || !nzchar(trimws(ref_level))) ref_level <- NULL
      }
    }

    if (is.factor(var_data)) {
      if (is.ordered(var_data)) {
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
              "be cleanly mapped to driver-level importance. Treatment contrasts are required."),
            how_to_fix = c(
              "Remove the ordered() designation and use regular factor",
              "Or set 'allow_polynomial=TRUE' if you understand the implications",
              "Recommended: Use treatment contrasts for interpretable importance"))
        }
        contrasts(data[[drv]]) <- "contr.treatment"
        encoding_report <- add_row(encoding_report, drv, original_class,
                                   "ordered_factor", "treatment",
                                   levels(var_data)[1], nlevels(var_data))
      } else {
        if (!is.null(ref_level) && ref_level %in% levels(var_data)) {
          data[[drv]] <- relevel(var_data, ref = ref_level)
        }
        contrasts(data[[drv]]) <- "contr.treatment"
        encoding_report <- add_row(encoding_report, drv, original_class,
                                   "factor", "treatment",
                                   levels(data[[drv]])[1], nlevels(var_data))
      }
    } else if (is.character(var_data)) {
      data[[drv]] <- factor(var_data)
      if (!is.null(ref_level) && ref_level %in% levels(data[[drv]])) {
        data[[drv]] <- relevel(data[[drv]], ref = ref_level)
      }
      contrasts(data[[drv]]) <- "contr.treatment"
      encoding_report <- add_row(encoding_report, drv, original_class,
                                 "factor", "treatment",
                                 levels(data[[drv]])[1], nlevels(data[[drv]]))
    } else if (is.numeric(var_data)) {
      encoding_report <- add_row(encoding_report, drv, original_class,
                                 "numeric", "N/A", NA_character_, NA_integer_)
    } else if (is.logical(var_data)) {
      data[[drv]] <- factor(var_data, levels = c(FALSE, TRUE))
      contrasts(data[[drv]]) <- "contr.treatment"
      encoding_report <- add_row(encoding_report, drv, original_class,
                                 "factor", "treatment", "FALSE", 2L)
    }
  }

  list(data = data, encoding_report = encoding_report)
}


#' Check if Any Predictor is Categorical
#' @param data Data frame
#' @param driver_vars Driver variable names
#' @return Logical TRUE if any driver is a factor/character/logical
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
                  row$n_levels, row$reference_level))
    } else {
      cat(sprintf("   - %s: %s\n", row$driver, row$encoded_as))
    }
  }
  cat("\n")
}

#' Print Term Mapping Summary
#' @param mapping Result from build_term_mapping()
#' @export
print_term_mapping_summary <- function(mapping) {
  cat("   [TERM MAPPING]\n")
  info <- mapping$predictor_info
  for (i in seq_len(nrow(info))) {
    cat(sprintf("   - %s: %d term(s)\n", info$driver[i], info$n_terms[i]))
  }
  cat(sprintf("   Total model terms: %d\n", length(mapping$all_terms)))
  cat("\n")
}

# ==============================================================================
# DRIVER TYPE CONSISTENCY VALIDATION
# ==============================================================================

#' Validate Driver Type Consistency
#'
#' Checks that config-declared driver_type matches the actual data type.
#' REFUSES on hard mismatches; warns on soft issues.
#'
#' @param data Data frame with driver variables
#' @param driver_vars Character vector of driver variable names
#' @param driver_settings Driver settings data frame from config
#' @return TRUE if all validations pass (REFUSES on mismatch)
#' @export
validate_driver_type_consistency <- function(data, driver_vars, driver_settings) {
  if (is.null(driver_settings)) return(TRUE)  # backwards compatibility

  mismatches <- character(0)
  type_issues <- character(0)

  for (drv in driver_vars) {
    if (!drv %in% names(data)) next
    declared_type <- get_driver_type(drv, driver_settings)
    if (is.null(declared_type)) next

    var_data <- data[[drv]]
    actual_type <- detect_actual_type(var_data)

    if (declared_type == "continuous" && !is.numeric(var_data)) {
      mismatches <- c(mismatches, paste0(drv, ": declared 'continuous' but data is ", actual_type))
    } else if (declared_type == "categorical") {
      if (is.numeric(var_data)) {
        n_unique <- length(unique(var_data[!is.na(var_data)]))
        if (n_unique > 20) {
          type_issues <- c(type_issues, paste0(
            drv, ": declared 'categorical' but has ", n_unique, " unique numeric values"))
        }
      }
      n_levels <- length(unique(var_data[!is.na(var_data)]))
      if (n_levels < 2) {
        mismatches <- c(mismatches, paste0(
          drv, ": categorical driver must have >=2 observed levels (found ", n_levels, ")"))
      }
    } else if (declared_type == "ordinal") {
      if (is.character(var_data) && !is.ordered(factor(var_data))) {
        type_issues <- c(type_issues, paste0(
          drv, ": declared 'ordinal' but is unordered character data"))
      }
    }
  }

  if (length(mismatches) > 0) {
    keydriver_refuse(
      code = "DATA_DRIVER_TYPE_MISMATCH",
      title = "Driver Type Mismatch Between Config and Data",
      problem = paste0(length(mismatches), " driver(s) have mismatched types."),
      why_it_matters = paste0(
        "The declared driver_type in config must match the actual data. ",
        "Mismatches can cause encoding errors or silently wrong importance scores."),
      how_to_fix = c(
        "Review and correct DriverType in the Variables sheet",
        "Or ensure your data matches the declared types",
        "Mismatched drivers listed below"),
      missing = mismatches)
  }

  if (length(type_issues) > 0) {
    for (issue in type_issues) cat(sprintf("   [WARN] %s\n", issue))
  }

  TRUE
}

#' Detect Actual Data Type
#' @param x Vector to check
#' @return Character string: "numeric", "factor", "ordered", "character",
#'   "logical", or "other"
#' @keywords internal
detect_actual_type <- function(x) {
  if (is.ordered(x)) "ordered"
  else if (is.factor(x)) "factor"
  else if (is.numeric(x)) "numeric"
  else if (is.character(x)) "character"
  else if (is.logical(x)) "logical"
  else "other"
}
