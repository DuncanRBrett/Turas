# ==============================================================================
# CATEGORICAL KEY DRIVER - UTILITIES
# ==============================================================================
#
# Helper functions for the categorical key driver module.
# These utilities support configuration, data handling, and output formatting.
#
# Version: 1.1
# Date: March 2026
#
# ==============================================================================

# ==============================================================================
# NULL COALESCING OPERATOR
# ==============================================================================

# Define %||% if not already available (sourced via TRS infrastructure in production,
# but needed as safety net for standalone sourcing and tests)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
}

# ==============================================================================
# MODULE DEFAULTS (centralised thresholds & constants)
# ==============================================================================
# All hard-coded thresholds live here. Config values override these defaults.
# Reference: CLAUDE.md requires "Configuration over hardcoding".

#' CatDriver Module Default Parameters
#'
#' Centralised list of default thresholds and constants used throughout
#' the catdriver module. Config settings override these values.
#'
#' @keywords internal
CATDRIVER_DEFAULTS <- list(
  # Sample adequacy
  min_sample_size      = 30L,     # Minimum N for any analysis
  min_epp              = 10,      # Events per predictor (soft warning)
  min_subgroup_n       = 30L,     # Minimum per-subgroup N

  # Rare levels & sparse cells
  rare_level_threshold = 10L,     # Minimum N to keep a level
  rare_cell_threshold  = 5L,      # Cross-tab cell warning threshold

  # Missing data
  missing_threshold    = 50,      # Max % missing before refusal

  # Model diagnostics
  confidence_level     = 0.95,    # CI confidence level
  vif_threshold        = 5.0,     # GVIF threshold for multicollinearity

  # Effect size classification (importance %)
  effect_very_large    = 30,      # >30% = Very Large
  effect_large         = 15,      # >15% = Large
  effect_medium        = 5,       # >5%  = Medium

  # OR direction sanity
  direction_prop_diff  = 0.05,    # Proportion diff threshold for mismatch check
  direction_or_upper   = 1.25,    # OR above this with negative prop = mismatch
  direction_or_lower   = 0.80,    # OR below this with positive prop = mismatch

  # Bootstrap
  bootstrap_reps       = 500L     # Default bootstrap resamples
)

# ==============================================================================
# SETTING CONVERSION HELPERS
# ==============================================================================

#' Convert Setting to Logical
#'
#' Handles Y/N, YES/NO, T/F, 1/0, TRUE/FALSE conversions.
#'
#' @param value Setting value (may be string, numeric, or logical)
#' @param default Default if NULL/NA
#' @return Logical value
#' @keywords internal
as_logical_setting <- function(value, default = FALSE) {
  if (is.null(value) || (length(value) == 1 && is.na(value))) {
    return(default)
  }

  if (is.logical(value)) {
    return(value)
  }

  if (is.character(value)) {
    return(tolower(trimws(value)) %in% c("true", "yes", "1", "on", "enabled", "t", "y"))
  }

  if (is.numeric(value)) {
    return(value != 0)
  }

  default
}


#' Convert Setting to Numeric
#'
#' @param value Setting value
#' @param default Default if NULL/NA
#' @return Numeric value
#' @keywords internal
as_numeric_setting <- function(value, default = NA_real_) {
  if (is.null(value) || (length(value) == 1 && is.na(value))) {
    return(default)
  }

  if (is.numeric(value)) {
    return(value)
  }

  if (is.character(value)) {
    result <- suppressWarnings(as.numeric(value))
    if (is.na(result)) {
      return(default)
    }
    return(result)
  }

  default
}


#' Check for Missing Values
#'
#' Detects missing values including NA, empty strings, and whitespace-only strings.
#' This is more robust than is.na() alone for data that may have been loaded
#' from Excel or CSV where missing values appear as empty strings.
#'
#' @param x Vector to check
#' @return Logical vector indicating missing values
#' @export
is_missing_value <- function(x) {
  if (is.factor(x)) {
    # For factors, check if the level is NA or represents empty/whitespace
    is.na(x) | (as.character(x) %in% c("", " ")) | grepl("^\\s*$", as.character(x))
  } else if (is.character(x)) {
    # For strings, check NA, empty, or whitespace-only
    is.na(x) | x == "" | grepl("^\\s*$", x)
  } else {
    # For other types (numeric, etc.), just check NA
    is.na(x)
  }
}


#' Get Setting Value with Default
#'
#' Safely extract setting values from a list with fallback.
#'
#' @param settings Settings list
#' @param name Setting name
#' @param default Default value if not found
#' @return Setting value or default
#' @keywords internal
get_setting <- function(settings, name, default = NULL) {
  val <- settings[[name]]
  if (is.null(val) || (length(val) == 1 && is.na(val))) {
    return(default)
  }
  val
}


# ==============================================================================
# TEXT FORMATTING HELPERS
# ==============================================================================

#' Format P-Value for Display
#'
#' @param p Numeric p-value
#' @param digits Number of decimal places for regular values
#' @return Character string of formatted p-value
#' @keywords internal
format_pvalue <- function(p, digits = 3) {
  if (is.na(p)) return("NA")

  if (p < 0.001) {
    return("<0.001")
  } else if (p < 0.01) {
    return(sprintf("%.3f", p))
  } else {
    return(sprintf(paste0("%.", digits, "f"), p))
  }
}


#' Get Significance Stars
#'
#' @param p Numeric p-value
#' @return Character string with stars or "ns"
#' @keywords internal
get_sig_stars <- function(p) {
  if (is.na(p)) return("")

  if (p < 0.001) {
    return("***")
  } else if (p < 0.01) {
    return("**")
  } else if (p < 0.05) {
    return("*")
  } else {
    return("ns")
  }
}


#' Format Percentage
#'
#' @param value Numeric value (0-1 scale or 0-100 scale)
#' @param digits Decimal places
#' @param already_pct TRUE if value is already percentage (0-100)
#' @return Formatted percentage string
#' @keywords internal
format_pct <- function(value, digits = 1, already_pct = FALSE) {
  if (is.na(value)) return("NA")

  if (!already_pct) {
    value <- value * 100
  }

  sprintf(paste0("%.", digits, "f%%"), value)
}


#' Format Odds Ratio for Display
#'
#' @param or Odds ratio value or vector
#' @param digits Decimal places
#' @return Formatted string or vector of strings
#' @keywords internal
format_or <- function(or, digits = 2) {
  # Vectorized version
  sapply(or, function(x) {
    if (is.na(x)) return("NA")

    if (abs(x) > 100) {
      return(sprintf("%.0f", x))
    } else if (abs(x) > 10) {
      return(sprintf("%.1f", x))
    } else {
      return(sprintf(paste0("%.", digits, "f"), x))
    }
  }, USE.NAMES = FALSE)
}


#' Interpret Odds Ratio Effect Size
#'
#' Based on standard guidelines for OR interpretation.
#'
#' @param or Odds ratio value
#' @return Character description of effect size
#' @keywords internal
interpret_or_effect <- function(or) {
  if (is.na(or) || is.infinite(or)) return("Unknown")

  # Convert OR to absolute scale (handle protective effects)
  or_abs <- if (or < 1) 1/or else or

  if (or_abs < 1.1) {
    return("Negligible")
  } else if (or_abs < 1.5) {
    return("Small")
  } else if (or_abs < 2.0) {
    return("Medium")
  } else if (or_abs < 3.0) {
    return("Large")
  } else {
    return("Very Large")
  }
}


#' Classify Importance Effect Size
#'
#' Maps relative importance percentage to a human-readable effect size label.
#' Thresholds: >30% = Very Large, >15% = Large, >5% = Medium, otherwise Small.
#'
#' @param pct Numeric, importance percentage (0-100)
#' @return Character, one of "Very Large", "Large", "Medium", "Small"
#' @keywords internal
classify_importance_effect <- function(pct) {
  if (is.na(pct) || !is.numeric(pct)) return("Unknown")
  if (pct > CATDRIVER_DEFAULTS$effect_very_large) return("Very Large")
  if (pct > CATDRIVER_DEFAULTS$effect_large) return("Large")
  if (pct > CATDRIVER_DEFAULTS$effect_medium) return("Medium")
  "Small"
}


#' Interpret Importance Percentage
#'
#' @param pct Importance percentage (0-100)
#' @return Character description
#' @keywords internal
interpret_importance <- function(pct) {
  if (is.na(pct)) return("Unknown")

  if (pct > 30) {
    return("Dominant driver")
  } else if (pct > 15) {
    return("Major driver")
  } else if (pct > 5) {
    return("Moderate driver")
  } else {
    return("Minor driver")
  }
}


#' Interpret McFadden Pseudo-R2
#'
#' @param r2 McFadden R-squared value
#' @return Character interpretation
#' @keywords internal
interpret_pseudo_r2 <- function(r2) {
  if (is.na(r2)) return("Unknown")

  if (r2 >= 0.4) {
    return("Excellent fit")
  } else if (r2 >= 0.2) {
    return("Good fit")
  } else if (r2 >= 0.1) {
    return("Moderate fit")
  } else {
    return("Limited explanatory power")
  }
}


# ==============================================================================
# VARIABLE NAME HELPERS
# ==============================================================================

#' Clean Variable Name for Safe Use
#'
#' Removes special characters, spaces, and ensures valid R variable name.
#'
#' @param name Character string to clean
#' @param max_length Maximum length (default 32)
#' @return Cleaned variable name
#' @keywords internal
clean_var_name <- function(name, max_length = 32) {
  if (is.na(name) || !nzchar(name)) return("unnamed")

  # Replace spaces with underscores
  cleaned <- gsub("\\s+", "_", name)

  # Remove special characters (keep alphanumeric and underscore)
  cleaned <- gsub("[^A-Za-z0-9_]", "", cleaned)

  # Ensure doesn't start with number
  if (grepl("^[0-9]", cleaned)) {
    cleaned <- paste0("x", cleaned)
  }

  # Truncate if needed
  if (nchar(cleaned) > max_length) {
    cleaned <- substr(cleaned, 1, max_length)
  }

  # Handle empty result
  if (!nzchar(cleaned)) {
    cleaned <- "unnamed"
  }

  cleaned
}


#' Create Dummy Variable Name
#'
#' Creates standardized dummy variable name from base variable and category.
#'
#' @param base_var Base variable name
#' @param category Category name
#' @return Dummy variable name
#' @keywords internal
make_dummy_name <- function(base_var, category) {
  # Clean category
  clean_cat <- clean_var_name(as.character(category), max_length = 20)

  # Combine
  paste0(base_var, "_", clean_cat)
}


# ==============================================================================
# DATA INSPECTION HELPERS
# ==============================================================================

#' Get Variable Summary
#'
#' Quick summary of a variable's type and unique values.
#'
#' @param x Vector to summarize
#' @return List with type info and unique count
#' @keywords internal
var_summary <- function(x) {
  list(
    class = class(x)[1],
    n_total = length(x),
    n_missing = sum(is.na(x)),
    n_unique = length(unique(na.omit(x))),
    is_numeric = is.numeric(x),
    is_factor = is.factor(x),
    is_ordered = is.ordered(x)
  )
}


#' Check if Variable is Categorical
#'
#' Determines if variable should be treated as categorical.
#'
#' @param x Vector to check
#' @param max_unique Maximum unique values for numeric to be categorical
#' @return Logical
#' @keywords internal
is_categorical <- function(x, max_unique = 10) {
  if (is.factor(x) || is.character(x) || is.logical(x)) {
    return(TRUE)
  }

  if (is.numeric(x)) {
    n_unique <- length(unique(na.omit(x)))
    return(n_unique <= max_unique)
  }

  FALSE
}


# ==============================================================================
# CROSS-TABULATION HELPERS
# ==============================================================================

#' Safe Cross-Tabulation with Proportions
#'
#' Creates cross-tab with row proportions, handling edge cases.
#'
#' @param row_var Row variable (predictor)
#' @param col_var Column variable (outcome)
#' @return List with count and proportion tables
#' @keywords internal
safe_crosstab <- function(row_var, col_var) {
  # Create count table
  tab_count <- table(row_var, col_var, useNA = "no")

  # Calculate row proportions safely
  row_totals <- rowSums(tab_count)
  tab_prop <- tab_count / ifelse(row_totals == 0, 1, row_totals)

  list(
    counts = tab_count,
    proportions = tab_prop,
    row_totals = row_totals,
    col_totals = colSums(tab_count)
  )
}


#' Detect Small Cells in Cross-Tabulation
#'
#' @param tab Cross-tabulation table (from table())
#' @param threshold Minimum cell count (default 5)
#' @return List with small cell locations and summary
#' @keywords internal
detect_small_cells <- function(tab, threshold = 5) {
  small_cells <- which(tab < threshold & tab > 0, arr.ind = TRUE)

  if (nrow(small_cells) == 0) {
    return(list(
      has_small_cells = FALSE,
      n_small_cells = 0,
      details = NULL
    ))
  }

  # Build details
  details <- data.frame(
    row_category = rownames(tab)[small_cells[, 1]],
    col_category = colnames(tab)[small_cells[, 2]],
    count = apply(small_cells, 1, function(idx) tab[idx[1], idx[2]])
  )

  list(
    has_small_cells = TRUE,
    n_small_cells = nrow(small_cells),
    details = details
  )
}


# ==============================================================================
# PATH HELPERS
# ==============================================================================

#' Check if Path is Absolute
#'
#' @param path File path to check
#' @return Logical
#' @keywords internal
is_absolute_path <- function(path) {
  if (is.null(path) || !nzchar(path)) return(FALSE)

  # Windows absolute (C:\ or \\)
  if (grepl("^[A-Za-z]:", path) || grepl("^\\\\\\\\", path)) {
    return(TRUE)
  }

  # Unix absolute (/)
  if (grepl("^/", path)) {
    return(TRUE)
  }

  FALSE
}


#' Resolve Relative Path from Base Directory
#'
#' @param base_dir Base directory
#' @param rel_path Relative path
#' @return Absolute normalized path
#' @keywords internal
resolve_path <- function(base_dir, rel_path) {
  if (is.null(rel_path) || is.na(rel_path) || !nzchar(rel_path)) {
    return(NULL)
  }

  # Already absolute
  if (is_absolute_path(rel_path)) {
    return(normalizePath(rel_path, winslash = "/", mustWork = FALSE))
  }

  # Remove leading ./
  rel_path <- gsub("^\\./", "", rel_path)

  # Combine and normalize
  full_path <- file.path(base_dir, rel_path)
  normalizePath(full_path, winslash = "/", mustWork = FALSE)
}


# ==============================================================================
# LOGGING HELPERS (TRS v1.0 Compliant)
# ==============================================================================

#' Print Status Message
#'
#' TRS v1.0 compliant formatting for status messages.
#' Uses [OK], [INFO], [WARN], [PARTIAL], [ERROR] prefixes.
#'
#' @param message Message text
#' @param type Type: "info", "success", "warning", "error", "partial"
#' @keywords internal
log_message <- function(message, type = "info") {
  prefix <- switch(type,
    info = "   [INFO] ",
    success = "   [OK] ",
    warning = "   [WARN] ",
    partial = "   [PARTIAL] ",
    error = "   [ERROR] ",
    "   "
  )

  cat(prefix, message, "\n", sep = "")
}


#' Print Section Header
#'
#' @param step_number Step number
#' @param title Section title
#' @keywords internal
log_section <- function(step_number, title) {
  cat("\n", step_number, ". ", title, "\n", sep = "")
}


# ==============================================================================
# CONFIDENCE INTERVAL HELPERS
# ==============================================================================

#' Calculate Odds Ratio Confidence Interval
#'
#' @param or Odds ratio (point estimate)
#' @param se Standard error of log(OR)
#' @param conf_level Confidence level (default 0.95)
#' @return Named vector with lower and upper bounds
#' @keywords internal
or_ci <- function(or, se, conf_level = 0.95) {
  z <- qnorm(1 - (1 - conf_level) / 2)
  log_or <- log(or)

  c(
    lower = exp(log_or - z * se),
    upper = exp(log_or + z * se)
  )
}


#' Format Confidence Interval
#'
#' @param lower Lower bound
#' @param upper Upper bound
#' @param digits Decimal places
#' @return Formatted string like "1.23-4.56"
#' @keywords internal
format_ci <- function(lower, upper, digits = 2) {
  if (is.na(lower) || is.na(upper)) return("-")

  sprintf("%.*f-%.*f", digits, lower, digits, upper)
}


# ==============================================================================
# MODEL DIAGNOSTIC HELPERS
# ==============================================================================

# calc_mcfadden_r2() was deleted 2026-09-18. It had no callers and, worse, it
# fabricated its null log-likelihood as `ll_full * 0.5` behind a placeholder
# comment, so anything that had started using it would have got an invented
# R-squared. Each engine computes McFadden against its own fitted null model.



#' Check for Separation in Binary Model
#'
#' Detects perfect or quasi-complete separation.
#'
#' @param model Fitted glm model
#' @return List with separation status and details
#' @keywords internal
check_separation <- function(model) {
  coefs <- coef(model)
  ses <- sqrt(diag(vcov(model)))

  large_coef <- any(abs(coefs) > 10, na.rm = TRUE)
  large_se <- any(ses > 100, na.rm = TRUE)

  has_separation <- large_coef || large_se

  problematic <- character(0)
  if (has_separation) {
    idx <- which(abs(coefs) > 10 | ses > 100)
    problematic <- names(coefs)[idx]
  }

  list(
    has_separation = has_separation,
    problematic_vars = problematic,
    message = if (has_separation) {
      paste0("Possible separation detected in: ",
             paste(problematic, collapse = ", "),
             ". Consider collapsing rare categories.")
    } else {
      "No separation detected"
    }
  )
}


# ==============================================================================
# LIST/DATA FRAME HELPERS
# ==============================================================================

#' Safe List Element Access
#'
#' @param lst List to access
#' @param name Element name
#' @param default Default if not found
#' @return Element value or default
#' @keywords internal
safe_get <- function(lst, name, default = NULL) {
  if (is.null(lst) || !name %in% names(lst)) {
    return(default)
  }
  lst[[name]]
}


#' Combine Multiple Data Frames
#'
#' Safe rbind that handles empty data frames.
#'
#' @param ... Data frames to combine
#' @return Combined data frame
#' @keywords internal
safe_rbind <- function(...) {
  dfs <- list(...)
  dfs <- dfs[!sapply(dfs, is.null)]
  dfs <- dfs[sapply(dfs, function(x) nrow(x) > 0)]

  if (length(dfs) == 0) {
    return(data.frame())
  }

  do.call(rbind, dfs)
}


# ==============================================================================
# WEIGHT DIAGNOSTICS
# ==============================================================================

#' Calculate Weight Diagnostics
#'
#' Computes diagnostic statistics for survey weights including min, max,
#' coefficient of variation, and effective sample size (Kish design effect).
#'
#' @param weights Numeric vector of weights
#' @return List with weight diagnostics:
#'   - min_weight: Minimum weight
#'   - max_weight: Maximum weight
#'   - mean_weight: Mean weight
#'   - cv_weight: Coefficient of variation (SD/mean)
#'   - effective_n: Kish effective sample size = (sum(w))^2 / sum(w^2)
#'   - design_effect: Kish design effect = n / effective_n
#'   - has_extreme_weights: TRUE if max/min > 10
#' @export
#' The Outcome Values the Model Actually Fitted
#'
#' Predictions come back only for the rows the fit used, while the caller's
#' frame still holds every row. Crossing the two produced
#' "all arguments must have the same length" the moment any predictor had a
#' missing value: a raw error, not a refusal. This returns the outcome vector
#' aligned to the fitted rows.
#'
#' @param model A fitted model object.
#' @param data The frame passed to the fit.
#' @param outcome_var Name of the outcome column.
#' @return The outcome vector for the fitted rows.
#' @keywords internal
cd_fitted_outcome <- function(model, data, outcome_var) {
  keep <- cd_estimation_rows(model, nrow(data))
  if (is.null(keep)) data[[outcome_var]] else data[[outcome_var]][keep]
}


#' Row Positions the Model Fitted
#'
#' The positions of \code{data}'s rows that survived the fit's own listwise
#' deletion, or NULL when nothing was dropped.
#'
#' This reads \code{model$na.action}, which the fitted object carries, rather
#' than \code{model.frame(model)}: model.frame re-evaluates the model call in
#' the FORMULA's environment, and CatDriver builds its formulas in the caller,
#' so the fit's local data frame is not visible there. Verified by running it,
#' 2026-09-18: model.frame() on a multinom fitted this way fails with
#' "object 'fit_data' not found".
#'
#' @param model A fitted model object.
#' @param n_rows Number of rows in the frame handed to the fit.
#' @return Integer vector of kept positions, or NULL when all rows were used.
#' @keywords internal
cd_estimation_rows <- function(model, n_rows) {
  omit <- model$na.action
  if (is.null(omit) || length(omit) == 0) return(NULL)
  if (!inherits(omit, "omit")) return(NULL)
  dropped <- as.integer(unclass(omit))
  dropped <- dropped[!is.na(dropped) & dropped >= 1 & dropped <= n_rows]
  if (length(dropped) == 0) return(NULL)
  setdiff(seq_len(n_rows), dropped)
}


#' Muffle the Binomial Non-Integer-Successes Warning
#'
#' With frequency weights that are not whole numbers, \code{glm(family =
#' binomial)} (and \code{MASS::polr}, which uses a binomial fit for its
#' starting values) warns "non-integer #successes in a binomial glm!" on every
#' fit. The warning says the weights are not counts; it does not say the fit is
#' wrong. Coefficients and the deviance-based likelihood-ratio tests are the
#' ones the module reports, and they are correct.
#'
#' It matters that this is muffled at the fit site rather than swallowed by a
#' \code{tryCatch(warning = ...)} handler: the old bootstrap code treated the
#' warning as a failure and returned NULL, so weighted binary runs silently lost
#' their confidence intervals.
#'
#' Switching the family to \code{quasibinomial} was considered and rejected:
#' it keeps the coefficients identical but estimates a dispersion parameter, so
#' the standard errors move, and \code{logLik()}/\code{AIC()} return NA, which
#' would take out McFadden R-squared and the LR test. Verified by running both
#' on a weighted fit, 2026-09-18.
#'
#' @param expr Expression to evaluate.
#' @return The value of \code{expr}.
#' @export
cd_muffle_noninteger_successes <- function(expr) {
  withCallingHandlers(
    expr,
    warning = function(w) {
      if (grepl("non-integer #successes", conditionMessage(w), fixed = TRUE)) {
        invokeRestart("muffleWarning")
      }
    }
  )
}


#' How far a weight vector's mean may sit from 1 before the run calls it a
#' rescale. Below this the weights are still normalised; the run just does not
#' report it, because rounding in a config workbook is not a finding.
#' @keywords internal
CATDRIVER_WEIGHT_RESCALE_TOLERANCE <- 1e-3


#' Normalise a Weight Vector to Mean 1
#'
#' CatDriver's four engines pass weights to glm/clm/polr/multinom as frequency
#' weights, which means the standard errors scale with the SUM of the weights,
#' not with the number of respondents. Expansion weights (summing to a
#' population) therefore produce standard errors that are far too small and
#' p-values that are far too significant, silently, under PASS. Normalising to
#' mean 1 makes the weighted sample the size of the real sample, which is the
#' frequency-weight approximation the module stamps on its output.
#'
#' NA weights are imputed to 1 and negative weights to 0, as before, but the
#' counts are returned so the caller can report them instead of hiding them.
#'
#' @param raw Weight vector as read from the data (any type).
#' @param weight_var Name of the weight variable, used in messages.
#'
#' @return List with:
#'   \item{weights}{Numeric vector normalised to mean 1, or NULL if unusable}
#'   \item{n_na_imputed}{Count of NA weights set to 1}
#'   \item{n_negative_zeroed}{Count of negative weights set to 0}
#'   \item{n_zero}{Count of zero weights after imputation}
#'   \item{raw_mean}{Mean of the weights before normalisation}
#'   \item{scale_factor}{Multiplier applied (1 / raw_mean)}
#'   \item{rescaled}{TRUE when the raw mean was not already 1}
#'   \item{notes}{Character vector of human-readable notes}
#'   \item{usable}{FALSE when no positive finite weight remains}
#' @export
normalise_catdriver_weights <- function(raw, weight_var = "weight") {

  out <- list(
    weights = NULL, n_na_imputed = 0L, n_negative_zeroed = 0L, n_zero = 0L,
    raw_mean = NA_real_, scale_factor = NA_real_, rescaled = FALSE,
    notes = character(0), usable = FALSE
  )

  if (is.null(raw) || length(raw) == 0) return(out)

  w <- suppressWarnings(as.numeric(raw))

  n_na <- sum(is.na(w))
  w[is.na(w)] <- 1
  n_nonfinite <- sum(!is.finite(w))
  w[!is.finite(w)] <- 1
  n_neg <- sum(w < 0)
  w[w < 0] <- 0

  positive <- w[w > 0]
  if (length(positive) == 0) return(out)

  raw_mean <- mean(positive)
  scale_factor <- if (raw_mean > 0) 1 / raw_mean else 1
  if (!isTRUE(all.equal(raw_mean, 1))) w <- w * scale_factor

  # Rim weights arrive already on mean 1 and are then rounded in the config
  # workbook, so their mean is 1.0000002 rather than 1. Normalising them is
  # free, but calling that a rescale would put every ordinary weighted run into
  # PARTIAL with a reason that says nothing. Only a materially different scale
  # (expansion weights, percentages, counts) is reported.
  rescaled <- abs(raw_mean - 1) > CATDRIVER_WEIGHT_RESCALE_TOLERANCE

  notes <- character(0)
  if (n_na > 0) {
    notes <- c(notes, sprintf("%d missing weight(s) in '%s' set to 1", n_na, weight_var))
  }
  if (n_nonfinite > 0) {
    notes <- c(notes, sprintf("%d non-finite weight(s) in '%s' set to 1", n_nonfinite, weight_var))
  }
  if (n_neg > 0) {
    notes <- c(notes, sprintf("%d negative weight(s) in '%s' set to 0 (those respondents carry no information)",
                              n_neg, weight_var))
  }
  if (rescaled) {
    notes <- c(notes, sprintf("Weights rescaled to mean 1 (raw mean %.4f, factor %.6g); without this, standard errors would follow the weight total rather than the sample size",
                              raw_mean, scale_factor))
  }

  out$weights <- w
  out$n_na_imputed <- as.integer(n_na)
  out$n_nonfinite_imputed <- as.integer(n_nonfinite)
  out$n_negative_zeroed <- as.integer(n_neg)
  out$n_zero <- as.integer(sum(w == 0))
  out$raw_mean <- raw_mean
  out$scale_factor <- scale_factor
  out$rescaled <- rescaled
  out$notes <- notes
  out$usable <- TRUE

  out
}


#' Inference Stamp for a Weighted CatDriver Run
#'
#' The honest one-line description of what the weighting did and did not do.
#' CatDriver treats weights as frequency weights normalised to mean 1; it does
#' not run design-based (survey-package) inference, so the design effect is
#' reported but never applied to the standard errors.
#'
#' @param weight_var Name of the weight variable, or NULL/"" if unweighted.
#' @param diagnostics Output of \code{calculate_weight_diagnostics()}, or NULL.
#' @param normalisation Output of \code{normalise_catdriver_weights()}, or NULL.
#'
#' @return Single character string.
#' @export
catdriver_weighting_stamp <- function(weight_var = NULL, diagnostics = NULL,
                                      normalisation = NULL) {

  if (is.null(weight_var) || !nzchar(weight_var) || is.null(diagnostics)) {
    return("Unweighted analysis. Standard errors, confidence intervals and p-values assume simple random sampling.")
  }

  parts <- sprintf("Weighted by '%s', applied as frequency weights normalised to mean 1.", weight_var)

  if (!is.null(normalisation) && isTRUE(normalisation$rescaled)) {
    parts <- paste(parts, sprintf("Raw weights had mean %.4f and were rescaled by %.6g.",
                                  normalisation$raw_mean, normalisation$scale_factor))
  }

  parts <- paste(parts, sprintf("Kish effective n = %.0f of %d (design effect %.2f).",
                                diagnostics$effective_n, diagnostics$n_weights,
                                diagnostics$design_effect))

  paste(parts,
        "Inference is a frequency-weight approximation: the design effect is reported but NOT applied to standard errors, confidence intervals or p-values, so significance is stated slightly optimistically. Design-based inference is not implemented in CatDriver.")
}


calculate_weight_diagnostics <- function(weights) {

  if (is.null(weights) || length(weights) == 0) {
    return(NULL)
  }

  # Remove NA and zero weights for diagnostics
  w <- weights[!is.na(weights) & weights > 0]

  if (length(w) == 0) {
    return(NULL)
  }

  n <- length(w)
  sum_w <- sum(w)
  sum_w2 <- sum(w^2)

  min_w <- min(w)
  max_w <- max(w)
  mean_w <- mean(w)
  sd_w <- sd(w)

  # Coefficient of variation
  cv_w <- if (mean_w > 0) sd_w / mean_w else NA

  # Kish effective sample size: (sum(w))^2 / sum(w^2).
  # One definition for the platform (modules/shared/lib/effective_n.R, OPUS-0).
  # The local expression below is the same statistic and is only reached when
  # that file was not sourced; it is kept so a bare source() of this file still
  # works.
  effective_n <- if (exists("calculate_effective_n", mode = "function")) {
    calculate_effective_n(w)
  } else if (sum_w2 > 0) {
    (sum_w^2) / sum_w2
  } else {
    n
  }

  # Design effect: actual n / effective n
  design_effect <- if (effective_n > 0) n / effective_n else 1

  # Flag extreme weights (max/min > 10 is concerning)
  weight_ratio <- if (min_w > 0) max_w / min_w else Inf
  has_extreme <- weight_ratio > 10

  list(
    n_weights = n,
    min_weight = min_w,
    max_weight = max_w,
    mean_weight = mean_w,
    sd_weight = sd_w,
    cv_weight = cv_w,
    effective_n = effective_n,
    design_effect = design_effect,
    weight_ratio = weight_ratio,
    has_extreme_weights = has_extreme
  )
}


# ==============================================================================
# BOOTSTRAP CONFIDENCE INTERVALS
# ==============================================================================

#' Run Bootstrap Analysis for Odds Ratios
#'
#' Performs bootstrap resampling to compute percentile confidence intervals
#' and sign stability for odds ratios. More robust than model-based CIs for
#' non-probability samples.
#'
#' @param data Analysis data frame
#' @param formula Model formula
#' @param outcome_type Type of outcome ("binary", "ordinal", "multinomial")
#' @param weights Optional weight vector
#' @param n_boot Number of bootstrap resamples (default 200)
#' @param conf_level Confidence level (default 0.95)
#' @param progress_callback Optional progress callback function
#' @return List with bootstrap results:
#'   - boot_or: Matrix of bootstrap odds ratios (n_boot x n_terms)
#'   - median_or: Median odds ratio for each term
#'   - ci_lower: Lower percentile CI
#'   - ci_upper: Upper percentile CI
#'   - sign_consistency: Proportion of bootstrap samples with same sign as median
#'   - n_successful: Number of successful bootstrap fits
#' @export
run_bootstrap_or <- function(data, formula, outcome_type, weights = NULL,
                             n_boot = 200, conf_level = 0.95,
                             progress_callback = NULL) {

  # Get term names from initial fit
  initial_fit <- fit_model_for_bootstrap(data, formula, outcome_type, weights)
  initial_model <- initial_fit$model
  if (is.null(initial_model)) {
    # This is where weighted binary bootstraps used to die in silence: the
    # old handler treated the "non-integer #successes" warning, which every
    # weighted binomial fit raises, as a failure. The user asked for bootstrap
    # intervals, got none, and the run still said PASS.
    cat(sprintf("   [WARNING] Initial model fit failed (%s) - cannot run bootstrap\n",
                paste(c(initial_fit$status, initial_fit$flags), collapse = "; ")))
    return(NULL)
  }

  term_names <- names(initial_model$coefficients)
  # Remove threshold terms for ordinal models
  term_names <- term_names[!grepl("^[0-9]+\\|[0-9]+$", term_names)]

  n_terms <- length(term_names)
  n_obs <- nrow(data)

  # Initialize storage
  boot_or <- matrix(NA, nrow = n_boot, ncol = n_terms)
  colnames(boot_or) <- term_names

  successful_boots <- 0
  discard_reasons <- character(0)
  kept_flagged <- character(0)

  for (b in seq_len(n_boot)) {
    # Update progress every 10 iterations
    if (!is.null(progress_callback) && b %% 10 == 0) {
      progress_callback(b / n_boot, paste0("Bootstrap ", b, "/", n_boot))
    }

    # Resample with replacement
    boot_idx <- sample(seq_len(n_obs), n_obs, replace = TRUE)
    boot_data <- data[boot_idx, , drop = FALSE]
    boot_weights <- if (!is.null(weights)) weights[boot_idx] else NULL

    # Fit model to bootstrap sample
    boot_fit <- tryCatch({
      fit_model_for_bootstrap(boot_data, formula, outcome_type, boot_weights)
    }, error = function(e) list(model = NULL, status = "error", flags = conditionMessage(e)))

    boot_model <- boot_fit$model

    if (!is.null(boot_model)) {
      # Extract coefficients
      coefs <- boot_model$coefficients
      # Match to term names (some may be missing if level not in resample)
      for (term in term_names) {
        if (term %in% names(coefs)) {
          boot_or[b, term] <- exp(coefs[[term]])
        }
      }
      successful_boots <- successful_boots + 1
      # A resample that converged but hit quasi-separation is kept; it is a real
      # draw from a sparse region, and dropping it is what biased the old
      # intervals narrow. It is counted so the caveat can say so.
      if (length(boot_fit$flags) > 0) {
        kept_flagged <- c(kept_flagged, boot_fit$flags)
      }
    } else {
      discard_reasons <- c(discard_reasons, boot_fit$status %||% "error")
    }
  }

  # Calculate summary statistics
  alpha <- 1 - conf_level
  discard_counts <- as.list(table(discard_reasons))
  kept_flag_counts <- as.list(table(kept_flagged))

  caveat <- if (length(discard_reasons) == 0) {
    "All resamples were usable."
  } else {
    sprintf("%d of %d resamples were discarded (%s). Percentile intervals and sign stability describe the resamples that survived, so they are, to that extent, optimistic.",
            length(discard_reasons), n_boot,
            paste(sprintf("%s: %d", names(discard_counts), unlist(discard_counts)),
                  collapse = ", "))
  }
  if (length(kept_flagged) > 0) {
    caveat <- paste(caveat,
      sprintf("%d resample(s) were kept despite a warning (%s); dropping them would bias the intervals narrow.",
              length(kept_flagged),
              paste(sprintf("%s: %d", names(kept_flag_counts), unlist(kept_flag_counts)),
                    collapse = ", ")))
  }

  results <- list(
    term = term_names,
    n_boot = n_boot,
    n_successful = successful_boots,
    n_discarded = length(discard_reasons),
    discard_counts = discard_counts,
    kept_flag_counts = kept_flag_counts,
    caveat = caveat,
    boot_or_matrix = boot_or
  )

  if (length(discard_reasons) > 0) {
    cat(sprintf("   [INFO] Bootstrap: %s\n", caveat))
  }

  # For each term, calculate stats
  results$median_or <- apply(boot_or, 2, median, na.rm = TRUE)
  results$ci_lower <- apply(boot_or, 2, quantile, probs = alpha/2, na.rm = TRUE)
  results$ci_upper <- apply(boot_or, 2, quantile, probs = 1 - alpha/2, na.rm = TRUE)
  results$iqr_lower <- apply(boot_or, 2, quantile, probs = 0.10, na.rm = TRUE)
  results$iqr_upper <- apply(boot_or, 2, quantile, probs = 0.90, na.rm = TRUE)

  # Sign consistency: % of boots where OR direction matches median
  # (OR > 1 vs OR < 1, excluding OR = 1)
  median_sign <- sign(log(results$median_or))
  sign_consistency <- sapply(seq_len(n_terms), function(i) {
    boot_signs <- sign(log(boot_or[, i]))
    mean(boot_signs == median_sign[i], na.rm = TRUE)
  })
  results$sign_consistency <- sign_consistency

  results
}


#' Fit Model for Bootstrap (Internal)
#'
#' Helper function to fit logistic model for bootstrap resampling.
#'
#' @param data Data frame
#' @param formula Model formula
#' @param outcome_type Outcome type
#' @param weights Optional weights
#' @return Fitted model or NULL if failed
#' @keywords internal
fit_model_for_bootstrap <- function(data, formula, outcome_type, weights = NULL) {

  warn_flags <- character(0)

  classify <- function(msg) {
    if (grepl("fitted probabilities numerically 0 or 1|separation", msg, ignore.case = TRUE)) {
      "separation"
    } else if (grepl("did not converge|convergence", msg, ignore.case = TRUE)) {
      "non_convergence"
    } else {
      "other"
    }
  }

  model <- withCallingHandlers(
    tryCatch({
      if (outcome_type == "binary") {
        if (!is.null(weights)) {
          fit_data <- data
          fit_data$..catdriver_wt.. <- weights
          glm(formula, data = fit_data, family = binomial(), weights = ..catdriver_wt..)
        } else {
          glm(formula, data = data, family = binomial())
        }
      } else if (outcome_type == "ordinal") {
        if (requireNamespace("ordinal", quietly = TRUE)) {
          if (!is.null(weights)) {
            data$..catdriver_wt.. <- weights
            ordinal::clm(formula, data = data, weights = ..catdriver_wt.., link = "logit")
          } else {
            ordinal::clm(formula, data = data, link = "logit")
          }
        } else if (requireNamespace("MASS", quietly = TRUE)) {
          if (!is.null(weights)) {
            data$..catdriver_wt.. <- weights
            MASS::polr(formula, data = data, weights = ..catdriver_wt.., Hess = TRUE)
          } else {
            MASS::polr(formula, data = data, Hess = TRUE)
          }
        } else {
          NULL
        }
      } else {
        # Multinomial - skip for bootstrap (too complex)
        NULL
      }
    }, error = function(e) {
      warn_flags <<- c(warn_flags, paste0("error: ", conditionMessage(e)))
      NULL
    }),
    warning = function(w) {
      msg <- conditionMessage(w)
      # Non-integer successes is what every weighted binary fit says about its
      # weights; it is not a fault in the resample. Everything else is counted
      # and reported, but still muffled: 200 resamples would otherwise bury the
      # Shiny console.
      if (!grepl("non-integer #successes", msg, fixed = TRUE)) {
        warn_flags <<- c(warn_flags, classify(msg))
      }
      invokeRestart("muffleWarning")
    }
  )

  status <- if (is.null(model)) {
    "error"
  } else if (!cd_fit_converged(model)) {
    "non_convergence"
  } else {
    "ok"
  }

  # For ordinal::clm, coefficients are in $beta
  if (!is.null(model) && inherits(model, "clm")) {
    model$coefficients <- model$beta
  }

  list(
    model = if (identical(status, "ok")) model else NULL,
    status = status,
    flags = unique(warn_flags)
  )
}


#' Did This Fit Converge
#'
#' glm, clm and polr each report convergence differently. A resample that did
#' not converge carries meaningless coefficients and must not enter a bootstrap
#' distribution; a resample that merely warned about separation is a real draw
#' from a sparse region and must, or the intervals come out falsely narrow
#' exactly where the bootstrap was worth running.
#'
#' @param model A fitted model object.
#' @return TRUE when the fit converged (or says nothing about it).
#' @keywords internal
cd_fit_converged <- function(model) {
  if (is.null(model)) return(FALSE)
  if (inherits(model, "glm")) return(isTRUE(model$converged))
  if (inherits(model, "clm")) {
    code <- model$convergence$code
    return(is.null(code) || isTRUE(code == 0))
  }
  if (inherits(model, "polr")) {
    return(is.null(model$convergence) || isTRUE(model$convergence == 0))
  }
  TRUE
}
