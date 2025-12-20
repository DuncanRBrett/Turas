# ==============================================================================
# PRICING - TRS GUARD LAYER
# ==============================================================================
#
# TRS v1.0 integration for the Pricing module.
# Implements refusal, guard state, and validation gates per TRS standard.
#
# This module provides:
#   - pricing_refuse() - module-specific refusal wrapper
#   - pricing_with_refusal_handler() - wraps main analysis with TRS handling
#   - pricing_guard_init() - initialize guard state with pricing-specific fields
#   - Validation helpers for pricing-specific requirements
#
# Related:
#   - modules/shared/lib/trs_refusal.R - shared TRS infrastructure
#
# Version: 1.0 (TRS Integration)
# Date: December 2024
#
# ==============================================================================


# ==============================================================================
# SOURCE SHARED TRS INFRASTRUCTURE
# ==============================================================================

if (!exists("turas_refuse", mode = "function")) {
  script_dir_path <- tryCatch({
    ofile <- sys.frame(1)$ofile
    if (!is.null(ofile)) file.path(dirname(ofile), "../../shared/lib/trs_refusal.R") else NULL
  }, error = function(e) NULL)

  possible_paths <- c(
    script_dir_path,
    file.path(getwd(), "modules/shared/lib/trs_refusal.R"),
    file.path(Sys.getenv("TURAS_HOME"), "modules/shared/lib/trs_refusal.R"),
    file.path(Sys.getenv("TURAS_ROOT", getwd()), "modules/shared/lib/trs_refusal.R")
  )
  possible_paths <- possible_paths[!sapply(possible_paths, is.null)]

  trs_loaded <- FALSE
  for (path in possible_paths) {
    if (file.exists(path)) { source(path); trs_loaded <- TRUE; break }
  }

  if (!trs_loaded) {
    warning("TRS infrastructure not found. Using fallback.")
    turas_refuse <- function(code, title, problem, why_it_matters, how_to_fix, ...) {
      stop(paste0("[", code, "] ", title, ": ", problem))
    }
    with_refusal_handler <- function(expr, module = "UNKNOWN") tryCatch(expr, error = function(e) stop(e))
    guard_init <- function(module = "UNKNOWN") list(module = module, warnings = list(), stable = TRUE)
    guard_warn <- function(guard, msg, category = "general") { guard$warnings <- c(guard$warnings, list(list(msg = msg, category = category))); guard }
    guard_flag_stability <- function(guard, reason) { guard$stable <- FALSE; guard }
    guard_summary <- function(guard) list(module = guard$module, warning_count = length(guard$warnings), is_stable = guard$stable, has_issues = length(guard$warnings) > 0)
    trs_status_pass <- function(module) list(status = "PASS", module = module)
    trs_status_partial <- function(module, degraded_reasons, affected_outputs) list(status = "PARTIAL", module = module, degraded_reasons = degraded_reasons)
  }
}


# ==============================================================================
# PRICING-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message (Pricing)
#'
#' @param code Refusal code (will be prefixed if needed)
#' @param title Short title for the refusal
#' @param problem One-sentence description of what went wrong
#' @param why_it_matters Explanation of analytical risk (MANDATORY)
#' @param how_to_fix Explicit step-by-step instructions to resolve
#' @param expected Expected entities (for diagnostics)
#' @param observed Observed entities (for diagnostics)
#' @param missing Missing entities (for diagnostics)
#' @param details Additional diagnostic details
#'
#' @keywords internal
pricing_refuse <- function(code,
                           title,
                           problem,
                           why_it_matters,
                           how_to_fix,
                           expected = NULL,
                           observed = NULL,
                           missing = NULL,
                           details = NULL) {

  if (!grepl("^(CFG_|DATA_|IO_|MODEL_|MAPPER_|PKG_|FEATURE_|BUG_)", code)) {
    code <- paste0("CFG_", code)
  }

  turas_refuse(
    code = code,
    title = title,
    problem = problem,
    why_it_matters = why_it_matters,
    how_to_fix = how_to_fix,
    expected = expected,
    observed = observed,
    missing = missing,
    details = details,
    module = "PRICING"
  )
}


#' Run Pricing Analysis with Refusal Handler
#'
#' @param expr Expression to evaluate
#' @return Result or refusal/error object
#' @export
pricing_with_refusal_handler <- function(expr) {
  result <- with_refusal_handler(expr, module = "PRICING")

  if (inherits(result, "turas_refusal_result")) {
    class(result) <- c("pricing_refusal_result", class(result))
  }

  result
}


# ==============================================================================
# PRICING GUARD STATE
# ==============================================================================

#' Initialize Pricing Guard State
#'
#' @return Guard state list
#' @export
pricing_guard_init <- function() {
  guard <- guard_init(module = "PRICING")

  # Add Pricing-specific fields
  guard$analysis_type <- NULL  # VW, GG, or combined
  guard$price_point_issues <- list()
  guard$sample_size_by_price <- list()
  guard$curve_interpolation_used <- FALSE
  guard$optimal_price_found <- FALSE

  guard
}


#' Record Price Point Issue
#'
#' @param guard Guard state object
#' @param price Price point value
#' @param issue Issue description
#' @param sample_size Sample size at this price
#' @return Updated guard state
#' @keywords internal
guard_record_price_issue <- function(guard, price, issue, sample_size = NULL) {
  guard$price_point_issues[[as.character(price)]] <- list(
    issue = issue,
    sample_size = sample_size
  )
  guard <- guard_warn(guard, paste0("Price point issue at $", price, ": ", issue), "price_point")
  guard
}


#' Record Sample Size at Price
#'
#' @param guard Guard state object
#' @param price Price point value
#' @param n Sample size
#' @return Updated guard state
#' @keywords internal
guard_record_price_sample <- function(guard, price, n) {
  guard$sample_size_by_price[[as.character(price)]] <- n

  if (n < 30) {
    guard <- guard_flag_stability(guard, paste0("Small sample at $", price, " (n=", n, ")"))
  }

  guard
}


#' Get Pricing Guard Summary
#'
#' @param guard Guard state object
#' @return List with summary info
#' @export
pricing_guard_summary <- function(guard) {
  summary <- guard_summary(guard)

  summary$analysis_type <- guard$analysis_type
  summary$price_point_issues <- guard$price_point_issues
  summary$sample_size_by_price <- guard$sample_size_by_price
  summary$curve_interpolation_used <- guard$curve_interpolation_used
  summary$optimal_price_found <- guard$optimal_price_found

  summary$has_issues <- summary$has_issues ||
                        length(guard$price_point_issues) > 0

  summary
}


# ==============================================================================
# PRICING VALIDATION GATES
# ==============================================================================

#' Validate Pricing Configuration
#'
#' @param config Configuration list
#' @keywords internal
validate_pricing_config <- function(config) {

  if (!is.list(config)) {
    pricing_refuse(
      code = "CFG_INVALID_TYPE",
      title = "Invalid Configuration Format",
      problem = "Configuration must be a list.",
      why_it_matters = "Analysis cannot proceed without properly structured configuration.",
      how_to_fix = "Ensure config file was loaded correctly."
    )
  }

  invisible(TRUE)
}


#' Validate Price Points
#'
#' @param price_points Numeric vector of price points
#' @keywords internal
validate_price_points <- function(price_points) {

  if (is.null(price_points) || length(price_points) == 0) {
    pricing_refuse(
      code = "CFG_NO_PRICE_POINTS",
      title = "No Price Points Specified",
      problem = "No price points were specified for analysis.",
      why_it_matters = "Pricing analysis requires a range of price points to test.",
      how_to_fix = c(
        "Open your config file",
        "Specify price points in the Price_Points section"
      )
    )
  }

  if (length(price_points) < 3) {
    pricing_refuse(
      code = "CFG_INSUFFICIENT_PRICE_POINTS",
      title = "Insufficient Price Points",
      problem = paste0("Only ", length(price_points), " price point(s) specified. Need at least 3."),
      why_it_matters = "Meaningful price sensitivity analysis requires multiple price points.",
      how_to_fix = "Add more price points to span the relevant price range."
    )
  }

  # Check for invalid values
  if (any(is.na(price_points))) {
    pricing_refuse(
      code = "CFG_INVALID_PRICE_POINTS",
      title = "Invalid Price Points",
      problem = "Price points contain NA values.",
      why_it_matters = "All price points must be valid numbers.",
      how_to_fix = "Remove or replace NA values in price points."
    )
  }

  if (any(price_points <= 0)) {
    pricing_refuse(
      code = "CFG_NEGATIVE_PRICE_POINTS",
      title = "Non-Positive Price Points",
      problem = "Price points contain zero or negative values.",
      why_it_matters = "Price points must be positive numbers.",
      how_to_fix = "Remove or fix zero/negative price points."
    )
  }

  # Check for proper sequence
  sorted_prices <- sort(price_points)
  if (!identical(price_points, sorted_prices) && !identical(price_points, rev(sorted_prices))) {
    pricing_refuse(
      code = "CFG_INVALID_PRICE_SEQUENCE",
      title = "Invalid Price Sequence",
      problem = "Price points are not in ascending or descending order.",
      why_it_matters = "Price points should be in a logical sequence for analysis.",
      how_to_fix = "Order price points from lowest to highest.",
      observed = price_points
    )
  }

  invisible(TRUE)
}


#' Validate Sample Size at Each Price
#'
#' @param data Survey data
#' @param price_column Column containing price shown to respondent
#' @param min_per_price Minimum sample per price point
#' @param guard Guard state
#' @return Updated guard state
#' @keywords internal
validate_sample_by_price <- function(data, price_column, min_per_price = 30, guard) {

  if (!price_column %in% names(data)) {
    pricing_refuse(
      code = "DATA_PRICE_COLUMN_NOT_FOUND",
      title = "Price Column Not Found",
      problem = paste0("Price column '", price_column, "' not found in data."),
      why_it_matters = "Cannot analyze pricing without knowing which price each respondent saw.",
      how_to_fix = c(
        "Check the price column name in your config",
        "Verify the column exists in your data file"
      ),
      observed = names(data)
    )
  }

  price_counts <- table(data[[price_column]])

  insufficient_prices <- names(price_counts)[price_counts < min_per_price]

  if (length(insufficient_prices) > 0) {
    for (price in insufficient_prices) {
      guard <- guard_record_price_issue(
        guard,
        price,
        paste0("Sample size (", price_counts[price], ") below minimum (", min_per_price, ")"),
        as.numeric(price_counts[price])
      )
    }
  }

  # Store all sample sizes
  for (price in names(price_counts)) {
    guard <- guard_record_price_sample(guard, price, as.numeric(price_counts[price]))
  }

  # Hard refuse if any price has too few responses
  if (any(price_counts < 10)) {
    very_small <- names(price_counts)[price_counts < 10]
    pricing_refuse(
      code = "DATA_INSUFFICIENT_AT_PRICE",
      title = "Critically Low Sample at Price Point",
      problem = paste0(length(very_small), " price point(s) have fewer than 10 responses."),
      why_it_matters = "Very small samples at a price point make that data point unreliable.",
      how_to_fix = c(
        "Collect more data",
        "Consider removing problematic price points",
        "Combine adjacent price points if appropriate"
      ),
      details = paste0("Affected prices: ", paste(very_small, collapse = ", "))
    )
  }

  guard
}


#' Validate Van Westendorp Questions
#'
#' @param data Survey data
#' @param vw_columns Named list of VW column names (too_cheap, cheap, expensive, too_expensive)
#' @keywords internal
validate_van_westendorp_data <- function(data, vw_columns) {

  required_cols <- c("too_cheap", "cheap", "expensive", "too_expensive")
  missing <- setdiff(required_cols, names(vw_columns))

  if (length(missing) > 0) {
    pricing_refuse(
      code = "CFG_MISSING_VW_COLUMNS",
      title = "Missing Van Westendorp Column Mappings",
      problem = paste0("Van Westendorp analysis requires 4 price questions: ", paste(missing, collapse = ", ")),
      why_it_matters = "All four price perception questions are needed for Van Westendorp analysis.",
      how_to_fix = c(
        "Map all 4 VW questions in config:",
        "  - too_cheap: At what price would it be so cheap you'd question quality?",
        "  - cheap: At what price would it be a bargain?",
        "  - expensive: At what price would it be getting expensive?",
        "  - too_expensive: At what price would it be too expensive to consider?"
      ),
      expected = required_cols,
      missing = missing
    )
  }

  # Check columns exist in data
  missing_in_data <- character(0)
  for (col_name in names(vw_columns)) {
    if (!vw_columns[[col_name]] %in% names(data)) {
      missing_in_data <- c(missing_in_data, vw_columns[[col_name]])
    }
  }

  if (length(missing_in_data) > 0) {
    pricing_refuse(
      code = "DATA_VW_COLUMNS_NOT_FOUND",
      title = "Van Westendorp Columns Not Found in Data",
      problem = paste0(length(missing_in_data), " VW column(s) not found in data."),
      why_it_matters = "Cannot run Van Westendorp analysis without all 4 price questions.",
      how_to_fix = c(
        "Check column names match data exactly",
        "Column names are case-sensitive"
      ),
      expected = unlist(vw_columns),
      observed = names(data),
      missing = missing_in_data
    )
  }

  invisible(TRUE)
}


# ==============================================================================
# TRS STATUS HELPERS
# ==============================================================================

#' Create Pricing PASS Status
#'
#' @param analysis_type Type of analysis performed
#' @param n_respondents Number of respondents
#' @param optimal_price Optimal price found (if applicable)
#' @return TRS status object
#' @export
pricing_status_pass <- function(analysis_type = NULL, n_respondents = NULL, optimal_price = NULL) {
  status <- trs_status_pass(module = "PRICING")
  status$details <- list(
    analysis_type = analysis_type,
    respondents = n_respondents,
    optimal_price = optimal_price
  )
  status
}


#' Create Pricing PARTIAL Status
#'
#' @param degraded_reasons Character vector of degradation reasons
#' @param affected_outputs Character vector of affected outputs
#' @param price_issues Character vector of price point issues
#' @return TRS status object
#' @export
pricing_status_partial <- function(degraded_reasons,
                                   affected_outputs,
                                   price_issues = NULL) {
  status <- trs_status_partial(
    module = "PRICING",
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )
  if (!is.null(price_issues) && length(price_issues) > 0) {
    status$details <- list(price_issues = price_issues)
  }
  status
}
