# ==============================================================================
# TURAS KEY DRIVER - EFFECT SIZE INTERPRETATION
# ==============================================================================
#
# Purpose: Classify and interpret effect sizes for driver importance
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================


# ------------------------------------------------------------------------------
# Effect Size Benchmarks
# ------------------------------------------------------------------------------

#' Get Effect Size Benchmarks for a Given Method
#'
#' Returns the threshold values used to classify effect sizes as
#' Negligible, Small, Medium, or Large for the specified method.
#'
#' @param method Character string specifying the benchmark method.
#'   One of \code{"cohen_f2"}, \code{"standardized_beta"}, or \code{"correlation"}.
#'
#' @return A named list with elements:
#'   \item{negligible}{Upper bound for negligible effects}
#'   \item{small}{Upper bound for small effects}
#'   \item{medium}{Upper bound for medium effects}
#'   Values above \code{medium} are classified as Large.
#'
#' @examples
#' \dontrun{
#'   benchmarks <- get_effect_size_benchmarks("cohen_f2")
#'   # benchmarks$negligible == 0.02
#'   # benchmarks$small == 0.15
#'   # benchmarks$medium == 0.35
#' }
#'
#' @keywords internal
get_effect_size_benchmarks <- function(method, config = NULL) {

  valid_methods <- c("cohen_f2", "standardized_beta", "correlation")

  if (is.null(method) || !is.character(method) || length(method) != 1) {
    keydriver_refuse(
      code = "CFG_INVALID_EFFECT_METHOD",
      title = "Invalid Effect Size Method",
      problem = "The 'method' parameter must be a single character string.",
      why_it_matters = "Cannot look up benchmarks without a valid method name.",
      how_to_fix = paste0(
        "Provide one of: ", paste(valid_methods, collapse = ", ")
      )
    )
  }

  method <- tolower(trimws(method))

  # Default benchmarks (Cohen 1988 conventions with Turas negligible tier)
  benchmarks <- list(
    cohen_f2 = list(negligible = 0.02, small = 0.15, medium = 0.35),
    standardized_beta = list(negligible = 0.05, small = 0.10, medium = 0.30),
    correlation = list(negligible = 0.10, small = 0.30, medium = 0.50)
  )

  # Allow config override for any method's thresholds
  if (!is.null(config) && !is.null(config$effect_size_benchmarks)) {
    custom <- config$effect_size_benchmarks
    if (is.list(custom) && !is.null(custom[[method]])) {
      cb <- custom[[method]]
      if (is.list(cb) && all(c("negligible", "small", "medium") %in% names(cb))) {
        benchmarks[[method]] <- cb
      }
    }
  }

  if (!method %in% names(benchmarks)) {
    keydriver_refuse(
      code = "CFG_UNKNOWN_EFFECT_METHOD",
      title = "Unknown Effect Size Method",
      problem = sprintf("Method '%s' is not a recognised effect size classification method.", method),
      why_it_matters = "Cannot classify effect sizes without valid benchmark thresholds.",
      how_to_fix = paste0(
        "Use one of the supported methods: ", paste(valid_methods, collapse = ", ")
      ),
      expected = valid_methods,
      observed = method
    )
  }

  benchmarks[[method]]
}


# ------------------------------------------------------------------------------
# Effect Size Classification
# ------------------------------------------------------------------------------

#' Classify an Effect Size Value
#'
#' Classifies a numeric effect size value as \code{"Negligible"}, \code{"Small"},
#' \code{"Medium"}, or \code{"Large"} using published benchmark thresholds
#' for the specified method.
#'
#' @param value A single numeric value representing the effect size.
#'   For directional measures (standardized beta, correlation), the
#'   absolute value is used for classification.
#' @param method Character string specifying the benchmark method.
#'   One of:
#'   \describe{
#'     \item{\code{"cohen_f2"}}{Cohen's f-squared. Negligible (<0.02),
#'       Small (0.02-0.15), Medium (0.15-0.35), Large (>0.35).}
#'     \item{\code{"standardized_beta"}}{Standardized regression coefficient.
#'       Negligible (<0.05), Small (0.05-0.10), Medium (0.10-0.30), Large (>0.30).}
#'     \item{\code{"correlation"}}{Pearson correlation coefficient.
#'       Negligible (<0.10), Small (0.10-0.30), Medium (0.30-0.50), Large (>0.50).}
#'   }
#'
#' @return A character string: one of \code{"Negligible"}, \code{"Small"},
#'   \code{"Medium"}, or \code{"Large"}.
#'
#' @examples
#' \dontrun{
#'   classify_effect_size(0.25, method = "cohen_f2")
#'   # Returns "Medium"
#'
#'   classify_effect_size(-0.42, method = "standardized_beta")
#'   # Returns "Large" (uses absolute value)
#' }
#'
#' @keywords internal
classify_effect_size <- function(value, method = "cohen_f2") {

  # Validate value
  if (is.null(value) || !is.numeric(value) || length(value) != 1) {
    keydriver_refuse(
      code = "DATA_INVALID_EFFECT_VALUE",
      title = "Invalid Effect Size Value",
      problem = "The 'value' parameter must be a single numeric value.",
      why_it_matters = "Cannot classify a non-numeric or multi-element value.",
      how_to_fix = "Provide a single numeric effect size value."
    )
  }

  if (is.na(value)) {
    return(NA_character_)
  }

  benchmarks <- get_effect_size_benchmarks(method)
  abs_value <- abs(value)

  if (abs_value < benchmarks$negligible) {
    return("Negligible")
  } else if (abs_value < benchmarks$small) {
    return("Small")
  } else if (abs_value < benchmarks$medium) {
    return("Medium")
  } else {
    return("Large")
  }
}


# ------------------------------------------------------------------------------
# Cohen's f-squared Calculation
# ------------------------------------------------------------------------------

#' Calculate Cohen's f-squared Effect Size
#'
#' Computes Cohen's f-squared from the R-squared values of a full model
#' and a reduced model (with one predictor removed).
#'
#' Formula: f2 = (R2_full - R2_reduced) / (1 - R2_full)
#'
#' @param r_squared_full Numeric. R-squared of the full model (all predictors).
#'   Must be between 0 and 1 inclusive.
#' @param r_squared_reduced Numeric. R-squared of the reduced model (target
#'   predictor removed). Must be between 0 and 1 inclusive.
#'
#' @return A single numeric value representing Cohen's f-squared.
#'   Returns 0 when R-squared values are equal (no incremental contribution).
#'   Returns \code{Inf} when \code{r_squared_full} equals 1 (perfect fit)
#'   and there is an R-squared difference.
#'
#' @examples
#' \dontrun{
#'   # Moderate effect
#'   calculate_cohens_f2(0.45, 0.30)
#'   # Returns 0.2727...
#'
#'   # No incremental contribution
#'   calculate_cohens_f2(0.30, 0.30)
#'   # Returns 0
#' }
#'
#' @keywords internal
calculate_cohens_f2 <- function(r_squared_full, r_squared_reduced) {

  # Validate r_squared_full
  if (is.null(r_squared_full) || !is.numeric(r_squared_full) || length(r_squared_full) != 1) {
    keydriver_refuse(
      code = "DATA_INVALID_R_SQUARED",
      title = "Invalid R-Squared (Full Model)",
      problem = "The 'r_squared_full' parameter must be a single numeric value.",
      why_it_matters = "Cohen's f-squared requires valid R-squared values from both models.",
      how_to_fix = "Provide the R-squared from the full regression model as a single number between 0 and 1."
    )
  }

  if (is.na(r_squared_full)) {
    return(NA_real_)
  }

  # Validate r_squared_reduced
  if (is.null(r_squared_reduced) || !is.numeric(r_squared_reduced) || length(r_squared_reduced) != 1) {
    keydriver_refuse(
      code = "DATA_INVALID_R_SQUARED",
      title = "Invalid R-Squared (Reduced Model)",
      problem = "The 'r_squared_reduced' parameter must be a single numeric value.",
      why_it_matters = "Cohen's f-squared requires valid R-squared values from both models.",
      how_to_fix = "Provide the R-squared from the reduced regression model as a single number between 0 and 1."
    )
  }

  if (is.na(r_squared_reduced)) {
    return(NA_real_)
  }

  # Range validation
  if (r_squared_full < 0 || r_squared_full > 1) {
    keydriver_refuse(
      code = "DATA_R_SQUARED_OUT_OF_RANGE",
      title = "R-Squared Out of Range (Full Model)",
      problem = sprintf("r_squared_full = %.4f is outside the valid range [0, 1].", r_squared_full),
      why_it_matters = "R-squared values must be between 0 and 1 for meaningful effect size calculation.",
      how_to_fix = "Check your model fitting. R-squared should be between 0 and 1.",
      expected = "Value between 0 and 1",
      observed = as.character(r_squared_full)
    )
  }

  if (r_squared_reduced < 0 || r_squared_reduced > 1) {
    keydriver_refuse(
      code = "DATA_R_SQUARED_OUT_OF_RANGE",
      title = "R-Squared Out of Range (Reduced Model)",
      problem = sprintf("r_squared_reduced = %.4f is outside the valid range [0, 1].", r_squared_reduced),
      why_it_matters = "R-squared values must be between 0 and 1 for meaningful effect size calculation.",
      how_to_fix = "Check your model fitting. R-squared should be between 0 and 1.",
      expected = "Value between 0 and 1",
      observed = as.character(r_squared_reduced)
    )
  }

  # Edge case: full model R-squared is 1 or near-1 (perfect fit)
  if (r_squared_full >= 1 - 1e-10) {
    r2_diff <- r_squared_full - r_squared_reduced
    if (r2_diff > 0) {
      return(Inf)
    } else {
      return(0)
    }
  }

  # Edge case: negative R-squared difference (reduced model is somehow better)
  r2_diff <- r_squared_full - r_squared_reduced
  if (r2_diff < 0) {
    cat("[WARN] R-squared of full model is less than reduced model. Returning f2 = 0.\n")
    return(0)
  }

  # Standard calculation
  f2 <- r2_diff / (1 - r_squared_full)

  f2
}


# ------------------------------------------------------------------------------
# Effect Interpretation Generator
# ------------------------------------------------------------------------------

#' Generate Effect Size Interpretations for Drivers
#'
#' Takes an importance data frame (as produced by the keydriver analysis pipeline)
#' and generates plain-English effect size interpretations for each driver.
#'
#' When \code{model_summary} is provided (containing R-squared values for
#' full and reduced models), Cohen's f-squared is computed for each driver.
#' Otherwise, the function falls back to classifying via standardized beta
#' coefficients (from the \code{Std_Beta} or \code{Beta_Coefficient} column).
#'
#' @param importance_df A data frame with at least a \code{Driver} column.
#'   Expected additional columns (used if present):
#'   \describe{
#'     \item{Std_Beta or Beta_Coefficient}{Standardized beta weight (signed).}
#'     \item{Correlation}{Zero-order correlation with outcome.}
#'   }
#' @param model_summary An optional list containing R-squared information
#'   for Cohen's f-squared calculation. Expected structure:
#'   \describe{
#'     \item{r_squared_full}{Numeric. R-squared of the full model.}
#'     \item{r_squared_reduced}{Named numeric vector. R-squared of each
#'       reduced model, keyed by driver name.}
#'   }
#'
#' @return A data.frame with columns:
#'   \item{Driver}{Driver variable name}
#'   \item{Effect_Value}{The numeric value used for classification}
#'   \item{Effect_Size}{Classification: Negligible / Small / Medium / Large}
#'   \item{Interpretation}{Plain-English description of the effect}
#'   \item{Benchmark_Method}{Which benchmark method was used (cohen_f2 or standardized_beta)}
#'
#' @examples
#' \dontrun{
#'   # Using standardized betas (no model_summary)
#'   imp_df <- data.frame(
#'     Driver = c("Price", "Quality", "Service"),
#'     Beta_Coefficient = c(0.45, 0.22, 0.08),
#'     stringsAsFactors = FALSE
#'   )
#'   effects <- generate_effect_interpretation(imp_df)
#'   print(effects)
#'
#'   # Using Cohen's f-squared with model_summary
#'   model_info <- list(
#'     r_squared_full = 0.55,
#'     r_squared_reduced = c(Price = 0.35, Quality = 0.48, Service = 0.53)
#'   )
#'   effects <- generate_effect_interpretation(imp_df, model_summary = model_info)
#' }
#'
#' @keywords internal
generate_effect_interpretation <- function(importance_df, model_summary = NULL) {

  # --- Input validation ---
  if (is.null(importance_df) || !is.data.frame(importance_df)) {
    keydriver_refuse(
      code = "DATA_INVALID_IMPORTANCE",
      title = "Invalid Importance Data Frame",
      problem = "The 'importance_df' parameter must be a data.frame.",
      why_it_matters = "Effect size interpretation requires a valid importance data frame from the keydriver pipeline.",
      how_to_fix = "Pass the importance data frame produced by calculate_importance_scores() or calculate_importance_mixed()."
    )
  }

  if (!"Driver" %in% names(importance_df)) {
    keydriver_refuse(
      code = "DATA_MISSING_DRIVER_COLUMN",
      title = "Missing 'Driver' Column",
      problem = "The importance data frame does not contain a 'Driver' column.",
      why_it_matters = "The 'Driver' column is required to identify which variable each row refers to.",
      how_to_fix = "Ensure the importance data frame has a 'Driver' column with variable names.",
      expected = "Column named 'Driver'",
      observed = paste(names(importance_df), collapse = ", ")
    )
  }

  if (nrow(importance_df) == 0) {
    return(data.frame(
      Driver = character(0),
      Effect_Value = numeric(0),
      Effect_Size = character(0),
      Interpretation = character(0),
      Benchmark_Method = character(0),
      stringsAsFactors = FALSE
    ))
  }

  drivers <- importance_df$Driver
  n_drivers <- length(drivers)

  # Pre-allocate result vectors
  effect_values <- numeric(n_drivers)
  effect_sizes <- character(n_drivers)
  interpretations <- character(n_drivers)
  benchmark_methods <- character(n_drivers)

  # --- Determine method: Cohen's f2 if model_summary available, else standardized beta ---
  use_cohens_f2 <- FALSE

  if (!is.null(model_summary)) {
    has_full <- !is.null(model_summary$r_squared_full) &&
                is.numeric(model_summary$r_squared_full) &&
                length(model_summary$r_squared_full) == 1

    has_reduced <- !is.null(model_summary$r_squared_reduced) &&
                   is.numeric(model_summary$r_squared_reduced) &&
                   length(model_summary$r_squared_reduced) > 0

    if (has_full && has_reduced) {
      use_cohens_f2 <- TRUE
    }
  }

  # --- Resolve the standardized beta column name ---
  std_beta_col <- NULL
  if ("Std_Beta" %in% names(importance_df)) {
    std_beta_col <- "Std_Beta"
  } else if ("Beta_Coefficient" %in% names(importance_df)) {
    std_beta_col <- "Beta_Coefficient"
  }

  # --- Generate interpretations for each driver ---
  for (i in seq_len(n_drivers)) {
    drv <- drivers[i]

    if (use_cohens_f2) {
      # Cohen's f-squared path
      r2_full <- model_summary$r_squared_full
      r2_reduced <- model_summary$r_squared_reduced[drv]

      if (!is.null(r2_reduced) && !is.na(r2_reduced)) {
        f2 <- calculate_cohens_f2(r2_full, r2_reduced)
        effect_values[i] <- f2
        effect_sizes[i] <- classify_effect_size(f2, method = "cohen_f2")
        benchmark_methods[i] <- "cohen_f2"
        es_label <- if (is.na(effect_sizes[i])) "an unclassified" else tolower(effect_sizes[i])
        interpretations[i] <- sprintf(
          "%s has %s effect on the outcome (Cohen's f2 = %.3f)",
          drv,
          es_label,
          f2
        )
      } else {
        # Fall back to standardized beta for this driver
        val <- .get_std_beta_value(importance_df, i, std_beta_col)
        effect_values[i] <- val
        if (is.na(val)) {
          effect_sizes[i] <- NA_character_
          benchmark_methods[i] <- "standardized_beta"
          interpretations[i] <- sprintf(
            "%s: effect size could not be determined (no beta or R-squared available)",
            drv
          )
        } else {
          effect_sizes[i] <- classify_effect_size(val, method = "standardized_beta")
          benchmark_methods[i] <- "standardized_beta"
          es_label2 <- if (is.na(effect_sizes[i])) "an unclassified" else tolower(effect_sizes[i])
          interpretations[i] <- sprintf(
            "%s has %s effect on the outcome (std. beta = %.2f)",
            drv,
            es_label2,
            val
          )
        }
      }
    } else {
      # Standardized beta path
      val <- .get_std_beta_value(importance_df, i, std_beta_col)
      effect_values[i] <- val

      if (is.na(val)) {
        effect_sizes[i] <- NA_character_
        benchmark_methods[i] <- "standardized_beta"
        interpretations[i] <- sprintf(
          "%s: effect size could not be determined (no standardized beta available)",
          drv
        )
      } else {
        effect_sizes[i] <- classify_effect_size(val, method = "standardized_beta")
        benchmark_methods[i] <- "standardized_beta"
        es_label3 <- if (is.na(effect_sizes[i])) "an unclassified" else tolower(effect_sizes[i])
        interpretations[i] <- sprintf(
          "%s has %s effect on the outcome (std. beta = %.2f)",
          drv,
          es_label3,
          val
        )
      }
    }
  }

  data.frame(
    Driver = drivers,
    Effect_Value = effect_values,
    Effect_Size = effect_sizes,
    Interpretation = interpretations,
    Benchmark_Method = benchmark_methods,
    stringsAsFactors = FALSE
  )
}


# ------------------------------------------------------------------------------
# Internal Helper
# ------------------------------------------------------------------------------

#' Extract Standardized Beta Value for a Driver Row
#'
#' @param importance_df Importance data frame
#' @param row_idx Row index
#' @param std_beta_col Resolved column name or NULL
#' @return Numeric value or NA_real_
#' @keywords internal
.get_std_beta_value <- function(importance_df, row_idx, std_beta_col) {
  if (!is.null(std_beta_col)) {
    val <- importance_df[[std_beta_col]][row_idx]
    if (is.numeric(val) && length(val) == 1) {
      return(val)
    }
  }
  NA_real_
}


# ==============================================================================
# NULL-COALESCING OPERATOR (guarded)
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
