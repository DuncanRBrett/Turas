# ==============================================================================
# CONJOINT ANALYSIS - HELPER FUNCTIONS
# ==============================================================================
#
# Module: Conjoint Analysis - Utilities
# Purpose: Shared utility functions for conjoint analysis
# Version: 2.0.0 (Enhanced Implementation)
# Date: 2025-11-26
#
# ==============================================================================

# ==============================================================================
# OPERATOR OVERLOADS
# ==============================================================================

#' Null coalescing operator
#' @keywords internal
`%||%` <- function(x, y) if (is.null(x)) y else x


# ==============================================================================
# ERROR MESSAGE FORMATTING
# ==============================================================================

#' Create formatted error message
#'
#' Creates clear, actionable error messages following Turas standards
#'
#' @param module Character, module name (e.g., "DATA", "CONFIG", "ESTIMATION")
#' @param problem Character, specific problem description
#' @param solution Character, actionable solution
#' @param location Character, where to look (optional)
#' @return Formatted error message
#' @keywords internal
create_error <- function(module, problem, solution, location = NULL) {
  msg <- sprintf("[%s] Error: %s\n → %s", module, problem, solution)
  if (!is.null(location)) {
    msg <- paste0(msg, sprintf("\n → %s", location))
  }
  msg
}


#' Create formatted warning message
#' @keywords internal
create_warning <- function(module, problem, suggestion = NULL) {
  msg <- sprintf("[%s] Warning: %s", module, problem)
  if (!is.null(suggestion)) {
    msg <- paste0(msg, sprintf("\n → %s", suggestion))
  }
  msg
}


# ==============================================================================
# DATA TYPE CONVERSIONS
# ==============================================================================

#' Safely convert to logical
#'
#' Handles various TRUE/FALSE representations
#'
#' @param x Value to convert
#' @param default Default value if conversion fails
#' @return Logical value
#' @keywords internal
safe_logical <- function(x, default = FALSE) {
  if (is.null(x) || length(x) == 0) return(default)
  if (is.na(x)) return(default)

  # Already logical
  if (is.logical(x)) return(x)

  # Convert string representations
  if (is.character(x)) {
    x_lower <- tolower(trimws(x))
    if (x_lower %in% c("true", "t", "yes", "y", "1")) return(TRUE)
    if (x_lower %in% c("false", "f", "no", "n", "0")) return(FALSE)
  }

  # Convert numeric
  if (is.numeric(x)) {
    return(x != 0)
  }

  # Default if can't convert
  default
}


#' Safely convert to numeric
#' @keywords internal
safe_numeric <- function(x, default = NA_real_) {
  if (is.null(x) || length(x) == 0) return(default)
  result <- suppressWarnings(as.numeric(x))
  if (length(result) == 0 || is.na(result)) default else result
}


# ==============================================================================
# ATTRIBUTE LEVEL HANDLING
# ==============================================================================

#' Parse comma-separated level names
#'
#' Handles various formats and trimming
#'
#' @param level_string Character, comma-separated levels
#' @return Character vector of level names
#' @keywords internal
parse_level_names <- function(level_string) {
  if (is.null(level_string) || is.na(level_string) || level_string == "") {
    return(character(0))
  }

  # Split on comma
  levels <- strsplit(as.character(level_string), ",")[[1]]

  # Trim whitespace
  levels <- trimws(levels)

  # Remove empty strings
  levels <- levels[levels != ""]

  levels
}


#' Get levels for a specific attribute from config
#'
#' @param config Configuration list
#' @param attribute_name Character, name of attribute
#' @return Character vector of level names
#' @keywords internal
get_attribute_levels <- function(config, attribute_name) {
  idx <- which(config$attributes$AttributeName == attribute_name)
  if (length(idx) == 0) {
    stop(sprintf("Attribute '%s' not found in configuration", attribute_name),
         call. = FALSE)
  }

  config$attributes$levels_list[[idx]]
}


# ==============================================================================
# STATISTICAL FUNCTIONS
# ==============================================================================

#' Calculate confidence interval for a coefficient
#'
#' Uses normal approximation: estimate +/- z * SE
#'
#' @param estimate Numeric, point estimate
#' @param std_error Numeric, standard error
#' @param confidence_level Numeric, confidence level (default 0.95)
#' @return Named vector with lower and upper bounds
#' @keywords internal
calculate_ci <- function(estimate, std_error, confidence_level = 0.95) {
  z <- qnorm(1 - (1 - confidence_level) / 2)
  c(
    lower = estimate - z * std_error,
    upper = estimate + z * std_error
  )
}


#' Calculate p-value from z-statistic
#' @keywords internal
calculate_p_value <- function(estimate, std_error) {
  if (std_error == 0) return(NA_real_)
  z_stat <- estimate / std_error
  2 * (1 - pnorm(abs(z_stat)))
}


#' Format p-value for display
#'
#' Returns "<0.001" for very small values, otherwise formatted to 3 decimals
#'
#' @param p_value Numeric, p-value
#' @return Character, formatted p-value
#' @keywords internal
format_p_value <- function(p_value) {
  if (is.na(p_value)) return("NA")
  if (p_value < 0.001) return("<0.001")
  sprintf("%.3f", p_value)
}


#' Get significance stars
#'
#' @param p_value Numeric, p-value
#' @return Character, significance stars
#' @keywords internal
get_significance_stars <- function(p_value) {
  if (is.na(p_value)) return("")
  if (p_value < 0.001) return("***")
  if (p_value < 0.01) return("**")
  if (p_value < 0.05) return("*")
  ""
}


# ==============================================================================
# UTILITY INTERPRETATION
# ==============================================================================

#' Interpret utility magnitude
#'
#' @param utility Numeric, utility value
#' @return Character, interpretation
#' @keywords internal
interpret_utility_magnitude <- function(utility) {
  abs_utility <- abs(utility)

  if (abs_utility > 1.0) return("Strongly")
  if (abs_utility > 0.5) return("Moderately")
  if (abs_utility > 0.2) return("Somewhat")
  return("Slightly")
}


#' Interpret utility direction and significance
#'
#' @param utility Numeric, utility value
#' @param p_value Numeric, p-value
#' @param is_baseline Logical, is this the baseline level?
#' @return Character, full interpretation
#' @keywords internal
interpret_utility <- function(utility, p_value, is_baseline = FALSE) {
  if (is_baseline) return("Baseline (reference level)")

  # Check significance
  if (is.na(p_value) || p_value >= 0.05) {
    return("Not significantly different from baseline")
  }

  # Get magnitude and direction
  magnitude <- interpret_utility_magnitude(utility)
  direction <- if (utility > 0) "preferred" else "avoided"
  stars <- get_significance_stars(p_value)

  sprintf("%s %s %s", magnitude, direction, stars)
}


#' Interpret attribute importance
#'
#' @param importance_pct Numeric, importance percentage
#' @return Character, interpretation
#' @keywords internal
interpret_importance <- function(importance_pct) {
  if (importance_pct > 40) return("Critical driver of choice")
  if (importance_pct > 20) return("Major influence on decisions")
  if (importance_pct > 10) return("Moderate influence")
  if (importance_pct > 5) return("Minor influence")
  return("Minimal impact")
}


# ==============================================================================
# MODEL QUALITY ASSESSMENT
# ==============================================================================

#' Assess McFadden R² quality
#'
#' @param r2 Numeric, McFadden R²
#' @return List with assessment level and explanation
#' @keywords internal
assess_mcfadden_r2 <- function(r2) {
  if (r2 > 0.40) {
    list(
      level = "excellent",
      explanation = "The model shows excellent fit with very strong explanatory power."
    )
  } else if (r2 > 0.20) {
    list(
      level = "good",
      explanation = "The model shows good fit with strong explanatory power."
    )
  } else if (r2 > 0.10) {
    list(
      level = "acceptable",
      explanation = "The model shows acceptable fit. Results are usable but indicate moderate explanatory power."
    )
  } else {
    list(
      level = "poor",
      explanation = "The model shows weak fit. Consider reviewing your data quality or attribute selection."
    )
  }
}


#' Assess hit rate quality
#'
#' @param hit_rate Numeric, proportion of correct predictions
#' @param chance_rate Numeric, chance prediction rate
#' @return Character, assessment
#' @keywords internal
assess_hit_rate <- function(hit_rate, chance_rate) {
  improvement <- hit_rate / chance_rate

  if (improvement >= 2.0) {
    "The model predicts very well, with hit rate 2x better than chance."
  } else if (improvement >= 1.5) {
    "The model predicts reasonably well, with hit rate 1.5x better than chance."
  } else if (improvement > 1.0) {
    "The model predicts slightly better than chance. Consider improving data quality or attribute selection."
  } else {
    "Warning: Model predictions are not better than random guessing."
  }
}


# ==============================================================================
# DATA QUALITY CHECKS
# ==============================================================================

#' Check for perfect separation
#'
#' Perfect separation occurs when a level is always/never chosen
#'
#' @param data Data frame
#' @param attribute_col Character, attribute column name
#' @param chosen_col Character, chosen indicator column
#' @return List with has_separation flag and details
#' @keywords internal
check_perfect_separation <- function(data, attribute_col, chosen_col) {
  level_choices <- aggregate(
    data[[chosen_col]],
    by = list(Level = data[[attribute_col]]),
    FUN = function(x) c(n_chosen = sum(x), n_total = length(x))
  )

  # Check for levels always or never chosen
  always_chosen <- level_choices$x[, "n_chosen"] == level_choices$x[, "n_total"]
  never_chosen <- level_choices$x[, "n_chosen"] == 0

  has_separation <- any(always_chosen) || any(never_chosen)

  list(
    has_separation = has_separation,
    always_chosen = level_choices$Level[always_chosen],
    never_chosen = level_choices$Level[never_chosen]
  )
}


# ==============================================================================
# EXCEL FORMATTING HELPERS
# ==============================================================================

#' Create standard header style for Excel
#'
#' @return openxlsx style object
#' @keywords internal
create_header_style <- function() {
  openxlsx::createStyle(
    fontSize = 11,
    fontColour = "#FFFFFF",
    fgFill = "#4472C4",
    halign = "left",
    valign = "center",
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
}


#' Create cell style for positive values (green)
#' @keywords internal
create_positive_style <- function() {
  openxlsx::createStyle(
    fontColour = "#006100",
    fgFill = "#C6EFCE"
  )
}


#' Create cell style for negative values (red)
#' @keywords internal
create_negative_style <- function() {
  openxlsx::createStyle(
    fontColour = "#9C0006",
    fgFill = "#FFC7CE"
  )
}


#' Create title style
#' @keywords internal
create_title_style <- function() {
  openxlsx::createStyle(
    fontSize = 14,
    fontColour = "#44546A",
    textDecoration = "bold"
  )
}


# ==============================================================================
# LOGGING AND PROGRESS
# ==============================================================================

#' Log verbose message
#'
#' Only prints if verbose = TRUE
#'
#' @param msg Character, message
#' @param verbose Logical, whether to print
#' @keywords internal
log_verbose <- function(msg, verbose = TRUE) {
  if (verbose) {
    cat(msg, "\n")
  }
  invisible(NULL)
}


#' Print section header
#'
#' @param title Character, section title
#' @param char Character, character to use for line (default "=")
#' @param width Integer, line width (default 80)
#' @keywords internal
print_section <- function(title, char = "=", width = 80) {
  cat("\n")
  cat(rep(char, width), "\n", sep = "")
  cat(title, "\n")
  cat(rep(char, width), "\n", sep = "")
  cat("\n")
}


# ==============================================================================
# PACKAGE CHECKING
# ==============================================================================

#' Check if required package is available
#'
#' @param package Character, package name
#' @param install_msg Character, installation instruction
#' @return Logical, TRUE if available (or stops with error)
#' @keywords internal
require_package <- function(package, install_msg = NULL) {
  if (!requireNamespace(package, quietly = TRUE)) {
    if (is.null(install_msg)) {
      install_msg <- sprintf(
        "Package '%s' required but not installed.\nInstall with: install.packages('%s')",
        package, package
      )
    }
    stop(install_msg, call. = FALSE)
  }
  TRUE
}


# ==============================================================================
# MODEL COMPARISON
# ==============================================================================

#' Compare two models using likelihood ratio test
#'
#' @param model_full Full model
#' @param model_restricted Restricted (nested) model
#' @return List with test statistic, df, and p-value
#' @keywords internal
likelihood_ratio_test <- function(model_full, model_restricted) {
  ll_full <- logLik(model_full)
  ll_restricted <- logLik(model_restricted)

  lr_stat <- 2 * (as.numeric(ll_full) - as.numeric(ll_restricted))
  df <- attr(ll_full, "df") - attr(ll_restricted, "df")
  p_value <- pchisq(lr_stat, df, lower.tail = FALSE)

  list(
    statistic = lr_stat,
    df = df,
    p_value = p_value,
    significant = p_value < 0.05
  )
}


# ==============================================================================
# ZERO-CENTERING
# ==============================================================================

#' Zero-center utilities within attribute
#'
#' This is critical for proper conjoint analysis interpretation
#'
#' @param utilities Numeric vector of utilities for an attribute
#' @return Numeric vector, zero-centered
#' @keywords internal
zero_center_utilities <- function(utilities) {
  utilities - mean(utilities, na.rm = TRUE)
}


# ==============================================================================
# ATTRIBUTE NAME HANDLING
# ==============================================================================

#' Escape Attribute Name for Formula
#'
#' Wraps attribute names with special characters in backticks for safe use
#' in R formulas. e.g., "I+G" becomes "`I+G`"
#'
#' @param attr Character, attribute name
#' @return Character, escaped attribute name
#' @keywords internal
escape_attr_for_formula <- function(attr) {
  if (grepl("[^a-zA-Z0-9_.]", attr)) {
    paste0("`", attr, "`")
  } else {
    attr
  }
}


#' Escape Attribute Name for Regex
#'
#' Escapes special regex characters in attribute names for pattern matching.
#' e.g., "I+G" becomes "I\\+G"
#'
#' @param attr Character, attribute name
#' @return Character, regex-safe attribute name
#' @keywords internal
escape_attr_for_regex <- function(attr) {
  gsub("([+*?^${}()|\\[\\]\\\\.])", "\\\\\\1", attr)
}


# ==============================================================================
# VERSION INFO
# ==============================================================================

#' Get module version
#' @keywords internal
get_conjoint_version <- function() {
  "2.1.0"
}
