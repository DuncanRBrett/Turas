# ==============================================================================
# TURAS KEY DRIVER - QUADRANT DATA PREPARATION
# ==============================================================================
#
# Purpose: Extract and prepare importance/performance data for quadrant charts
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================

#' Extract Importance Scores from KDA Results
#'
#' Normalizes importance scores from various KDA methods to comparable scale.
#'
#' @param kda_results KDA results object or data frame with importance
#' @param config Configuration with importance_source
#' @return Data frame with driver and importance columns
#' @keywords internal
extract_importance_scores <- function(kda_results, config) {

  source <- config$importance_source %||% "auto"

  # If already a data frame with importance
  if (is.data.frame(kda_results)) {
    if ("importance" %in% names(kda_results)) {
      imp <- kda_results[, c("driver", "importance"), drop = FALSE]
      return(normalize_importance(imp, config))
    }
    if ("importance_pct" %in% names(kda_results)) {
      imp <- data.frame(
        driver = kda_results$driver,
        importance = kda_results$importance_pct,
        stringsAsFactors = FALSE
      )
      return(normalize_importance(imp, config))
    }
  }

  # If it's a shap_results object
  if (inherits(kda_results, "shap_results")) {
    imp <- data.frame(
      driver = kda_results$importance$driver,
      importance = kda_results$importance$importance_pct,
      stringsAsFactors = FALSE
    )
    return(normalize_importance(imp, config))
  }

  # Extract from standard KDA results list
  if (is.list(kda_results) && "importance" %in% names(kda_results)) {

    importance_df <- kda_results$importance

    # Try to get importance based on source
    imp <- switch(tolower(source),
      "shap" = {
        if ("Shapley_Value" %in% names(importance_df)) {
          data.frame(
            driver = importance_df$Driver,
            importance = importance_df$Shapley_Value,
            stringsAsFactors = FALSE
          )
        } else {
          select_best_importance(importance_df)
        }
      },
      "relative_weights" = {
        if ("Relative_Weight" %in% names(importance_df)) {
          data.frame(
            driver = importance_df$Driver,
            importance = importance_df$Relative_Weight,
            stringsAsFactors = FALSE
          )
        } else {
          select_best_importance(importance_df)
        }
      },
      "regression" = {
        if ("Beta_Weight" %in% names(importance_df)) {
          data.frame(
            driver = importance_df$Driver,
            importance = importance_df$Beta_Weight,
            stringsAsFactors = FALSE
          )
        } else {
          select_best_importance(importance_df)
        }
      },
      "correlation" = {
        if ("Correlation" %in% names(importance_df)) {
          data.frame(
            driver = importance_df$Driver,
            importance = abs(importance_df$Correlation) * 100,
            stringsAsFactors = FALSE
          )
        } else {
          select_best_importance(importance_df)
        }
      },
      "auto" = select_best_importance(importance_df),
      select_best_importance(importance_df)
    )

    return(normalize_importance(imp, config))
  }

  keydriver_refuse(
    code = "FEATURE_QUADRANT_NO_IMPORTANCE",
    title = "Cannot Extract Importance Scores",
    problem = "Could not extract importance scores from the provided results.",
    why_it_matters = "Quadrant analysis requires importance scores to position drivers.",
    how_to_fix = c(
      "Ensure you pass valid KDA results with importance scores",
      "Or provide a data frame with 'driver' and 'importance' columns"
    )
  )
}


#' Auto-Select Best Importance Source
#'
#' Priority: SHAP > Relative Weights > Regression > Correlation
#'
#' @param importance_df Importance data frame from KDA
#' @return Data frame with driver and importance
#' @keywords internal
select_best_importance <- function(importance_df) {

  # Determine driver column
  driver_col <- if ("Driver" %in% names(importance_df)) "Driver" else "driver"

  if ("Shapley_Value" %in% names(importance_df)) {
    message("Using Shapley importance (auto-selected)")
    return(data.frame(
      driver = importance_df[[driver_col]],
      importance = importance_df$Shapley_Value,
      stringsAsFactors = FALSE
    ))
  }

  if ("Relative_Weight" %in% names(importance_df)) {
    message("Using relative weights importance (auto-selected)")
    return(data.frame(
      driver = importance_df[[driver_col]],
      importance = importance_df$Relative_Weight,
      stringsAsFactors = FALSE
    ))
  }

  if ("Beta_Weight" %in% names(importance_df)) {
    message("Using regression importance (auto-selected)")
    return(data.frame(
      driver = importance_df[[driver_col]],
      importance = importance_df$Beta_Weight,
      stringsAsFactors = FALSE
    ))
  }

  if ("Correlation" %in% names(importance_df)) {
    message("Using correlation importance (auto-selected)")
    return(data.frame(
      driver = importance_df[[driver_col]],
      importance = abs(importance_df$Correlation) * 100,
      stringsAsFactors = FALSE
    ))
  }

  # Last resort - look for any column with "importance" in the name
  imp_cols <- grep("importance|weight|shap", names(importance_df), value = TRUE, ignore.case = TRUE)
  if (length(imp_cols) > 0) {
    return(data.frame(
      driver = importance_df[[driver_col]],
      importance = importance_df[[imp_cols[1]]],
      stringsAsFactors = FALSE
    ))
  }

  keydriver_refuse(
    code = "FEATURE_QUADRANT_NO_IMPORTANCE_SCORES",
    title = "No Importance Scores Found",
    problem = "No importance scores could be found in the KDA results.",
    why_it_matters = "Quadrant analysis requires importance scores to create the chart.",
    how_to_fix = c(
      "Ensure your KDA results contain importance scores",
      "Check that analysis completed successfully before creating quadrant"
    )
  )
}


#' Normalize Importance to 0-100 Scale
#'
#' @param imp Importance data frame
#' @param config Configuration parameters
#' @return Importance data frame with normalized column
#' @keywords internal
normalize_importance <- function(imp, config) {

  if (!isTRUE(config$normalize_axes)) {
    imp$importance_normalized <- imp$importance
    return(imp)
  }

  min_val <- min(imp$importance, na.rm = TRUE)
  max_val <- max(imp$importance, na.rm = TRUE)

  if (max_val == min_val) {
    imp$importance_normalized <- 50
  } else {
    imp$importance_normalized <-
      (imp$importance - min_val) / (max_val - min_val) * 100
  }

  imp
}


#' Calculate Performance Scores
#'
#' Computes mean satisfaction/performance for each driver.
#'
#' @param kda_results KDA results (may contain raw data)
#' @param data Original data frame
#' @param performance_data Optional pre-calculated performance
#' @param config Configuration parameters
#' @return Data frame with driver and performance columns
#' @keywords internal
calculate_performance_scores <- function(kda_results, data, performance_data, config) {

  # If pre-calculated performance provided
  if (!is.null(performance_data)) {
    if (!all(c("driver", "performance") %in% names(performance_data))) {
      keydriver_refuse(
        code = "FEATURE_QUADRANT_INVALID_PERFORMANCE_DATA",
        title = "Invalid Performance Data Format",
        problem = "Performance data must have 'driver' and 'performance' columns.",
        why_it_matters = "Cannot map performance scores to drivers without proper column names.",
        how_to_fix = c(
          "Ensure your performance_data has columns named 'driver' and 'performance'",
          "Column names are case-sensitive"
        ),
        observed = names(performance_data)
      )
    }
    return(normalize_performance(performance_data, config))
  }

  # Try to get data and drivers from kda_results
  if (is.null(data)) {
    if (is.list(kda_results) && "data" %in% names(kda_results)) {
      data <- kda_results$data
    } else if (is.list(kda_results) && "config" %in% names(kda_results) &&
               "data" %in% names(kda_results$config)) {
      data <- kda_results$config$data
    }
  }

  if (is.null(data)) {
    keydriver_refuse(
      code = "FEATURE_QUADRANT_NO_DATA",
      title = "No Data for Performance Calculation",
      problem = "Cannot calculate performance scores without data.",
      why_it_matters = "Performance scores must be calculated from respondent data.",
      how_to_fix = c(
        "Provide the 'data' argument with your survey data",
        "Or provide pre-calculated 'performance_data'"
      )
    )
  }

  # Get driver names
  drivers <- NULL
  if (is.list(kda_results) && "config" %in% names(kda_results)) {
    drivers <- kda_results$config$driver_vars
  }
  if (is.null(drivers) && is.list(kda_results) && "importance" %in% names(kda_results)) {
    drivers <- kda_results$importance$Driver
  }
  if (is.null(drivers) && is.data.frame(kda_results)) {
    drivers <- kda_results$driver
  }

  if (is.null(drivers)) {
    keydriver_refuse(
      code = "FEATURE_QUADRANT_NO_DRIVERS",
      title = "Cannot Determine Driver Variables",
      problem = "Could not identify driver variables for performance calculation.",
      why_it_matters = "Performance scores are calculated per driver variable.",
      how_to_fix = c(
        "Ensure KDA results contain driver variable information",
        "Or provide a data frame with a 'driver' column"
      )
    )
  }

  # Get weight variable if available
  weights <- NULL
  if (is.list(kda_results) && "config" %in% names(kda_results)) {
    weights <- kda_results$config$weight_var
  }

  # Calculate performance
  perf <- calculate_weighted_means(data, drivers, weights)

  normalize_performance(perf, config)
}


#' Calculate Weighted Mean Performance
#'
#' @param data Data frame
#' @param drivers Character vector of driver variable names
#' @param weights Character name of weight variable (or NULL)
#' @return Data frame with driver and performance columns
#' @keywords internal
calculate_weighted_means <- function(data, drivers, weights = NULL) {

  if (is.null(weights) || !weights %in% names(data)) {
    w <- rep(1, nrow(data))
  } else {
    w <- data[[weights]]
    w[is.na(w)] <- 0
  }

  perf <- data.frame(
    driver = drivers,
    performance = sapply(drivers, function(d) {
      if (!d %in% names(data)) return(NA_real_)
      x <- data[[d]]
      valid <- !is.na(x) & !is.na(w) & w > 0
      if (sum(valid) == 0) return(NA_real_)
      stats::weighted.mean(x[valid], w[valid])
    }),
    stringsAsFactors = FALSE
  )

  perf
}


#' Normalize Performance to 0-100 Scale
#'
#' @param perf Performance data frame
#' @param config Configuration parameters
#' @return Performance data frame with normalized column
#' @keywords internal
normalize_performance <- function(perf, config) {

  if (!isTRUE(config$normalize_axes)) {
    perf$performance_normalized <- perf$performance
    return(perf)
  }

  # If scale range is specified, use it
  scale_min <- config$performance_scale_min
  scale_max <- config$performance_scale_max

  if (is.null(scale_min)) {
    scale_min <- min(perf$performance, na.rm = TRUE)
  }
  if (is.null(scale_max)) {
    scale_max <- max(perf$performance, na.rm = TRUE)
  }

  if (scale_max == scale_min) {
    perf$performance_normalized <- 50
  } else {
    perf$performance_normalized <-
      (perf$performance - scale_min) / (scale_max - scale_min) * 100
  }

  perf
}


#' Validate Quadrant Inputs
#'
#' @param importance Importance data frame
#' @param performance Performance data frame
#' @keywords internal
validate_quadrant_inputs <- function(importance, performance) {

  # Check drivers match
  imp_drivers <- importance$driver
  perf_drivers <- performance$driver

  missing_perf <- setdiff(imp_drivers, perf_drivers)
  if (length(missing_perf) > 0) {
    warning(sprintf(
      "Drivers missing from performance data: %s. These will be excluded.",
      paste(missing_perf, collapse = ", ")
    ))
  }

  # Check for valid values
  if (any(is.na(importance$importance))) {
    warning("NA values in importance scores - these drivers will be excluded")
  }

  if (any(is.na(performance$performance))) {
    warning("NA values in performance scores - these drivers will be excluded")
  }

  # Check minimum drivers
  common_drivers <- intersect(imp_drivers, perf_drivers)
  n_valid <- sum(
    !is.na(importance$importance[importance$driver %in% common_drivers]) &
    !is.na(performance$performance[performance$driver %in% common_drivers])
  )

  if (n_valid < 4) {
    keydriver_refuse(
      code = "FEATURE_QUADRANT_INSUFFICIENT_DRIVERS",
      title = "Insufficient Drivers for Quadrant Analysis",
      problem = paste0("Found only ", n_valid, " valid drivers. Quadrant analysis requires at least 4."),
      why_it_matters = "A meaningful quadrant chart needs multiple drivers to distribute across quadrants.",
      how_to_fix = c(
        "Ensure you have at least 4 driver variables in your analysis",
        "Check that drivers have valid importance and performance scores"
      ),
      details = paste0("Valid drivers: ", n_valid, ", Required: >= 4")
    )
  }

  invisible(TRUE)
}


#' Null-coalescing operator (if not already defined)
#' @keywords internal
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
