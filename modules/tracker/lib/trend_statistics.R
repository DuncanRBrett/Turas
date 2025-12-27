# ==============================================================================
# TurasTracker - Trend Statistics Functions
# ==============================================================================
#
# Statistical calculation functions for trend analysis.
# Extracted from trend_calculator.R for better maintainability and code reuse.
#
# VERSION: 1.0.0
# EXTRACTED FROM: trend_calculator.R
#
# DEPENDENCIES:
# - Requires 00_guard.R to be loaded for tracker_refuse() (TRS compliance)
# - Requires statistical_core.R for DEFAULT_ALPHA constant
#
# FUNCTIONS:
# - calculate_weighted_mean()              : Weighted mean with effective N
# - calculate_nps_score()                  : NPS calculation with segments
# - calculate_proportions()                : Proportions for categorical data
# - calculate_top_box()                    : Top N box calculation
# - calculate_bottom_box()                 : Bottom N box calculation
# - calculate_custom_range()               : Custom range calculation
# - calculate_distribution()               : Full distribution calculation
# - calculate_composite_score()            : Composite score (aggregate mean)
# - calculate_composite_values_per_respondent() : Per-respondent composite
#
# ==============================================================================

# Get script directory for sourcing guard layer
.stat_script_dir <- tryCatch({
  dirname(sys.frame(1)$ofile)
}, error = function(e) getwd())

# Source TRS guard layer if not already loaded
if (!exists("tracker_refuse", mode = "function")) {
  source(file.path(.stat_script_dir, "00_guard.R"))
}


#' Calculate Weighted Mean
#'
#' SHARED CODE NOTE: This should be in /shared/calculations.R
#' Used by both TurasTabs and TurasTracker
#'
#' @keywords internal
calculate_weighted_mean <- function(values, weights) {

  # Type validation - check if values are numeric
  if (!is.numeric(values)) {
    # Show sample of non-numeric values for debugging
    sample_values <- head(unique(values[!is.na(values)]), 5)
    # TRS Refusal: DATA_NON_NUMERIC_VALUES
    tracker_refuse(
      code = "DATA_NON_NUMERIC_VALUES",
      title = "Non-Numeric Data Detected",
      problem = "Expected numeric responses but found text values.",
      why_it_matters = "Weighted mean calculation requires numeric data.",
      how_to_fix = c(
        "Check that the data file has numeric values for this question",
        "Verify question type is configured correctly"
      ),
      details = paste0("Sample values found: ", paste(sample_values, collapse = ", "))
    )
  }

  # Remove NA values
  # Use which() to ensure we get numeric indices without NA
  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values <- values[valid_idx]
  weights <- weights[valid_idx]

  if (length(values) == 0) {
    return(list(
      mean = NA,
      sd = NA,
      n_unweighted = 0,
      n_weighted = 0,
      eff_n = 0
    ))
  }

  # Calculate weighted mean
  weighted_mean <- sum(values * weights) / sum(weights)

  # Calculate weighted standard deviation
  weighted_var <- sum(weights * (values - weighted_mean)^2) / sum(weights)
  weighted_sd <- sqrt(weighted_var)

  # Calculate effective N (design-effect adjusted sample size)
  # eff_n = (sum of weights)^2 / sum of squared weights
  sum_weights <- sum(weights)
  sum_weights_squared <- sum(weights^2)
  eff_n <- if (sum_weights_squared > 0) {
    (sum_weights^2) / sum_weights_squared
  } else {
    0
  }

  return(list(
    mean = weighted_mean,
    sd = weighted_sd,
    n_unweighted = length(values),
    n_weighted = sum(weights),
    eff_n = eff_n
  ))
}


#' Calculate NPS Score
#'
#' @keywords internal
calculate_nps_score <- function(values, weights) {

  # Remove NA values
  # Use which() to ensure we get numeric indices without NA
  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values <- values[valid_idx]
  weights <- weights[valid_idx]

  if (length(values) == 0) {
    return(list(
      nps = NA,
      promoters_pct = NA,
      passives_pct = NA,
      detractors_pct = NA,
      n_unweighted = 0,
      n_weighted = 0,
      eff_n = 0
    ))
  }

  # Classify responses
  promoters <- values >= 9
  passives <- values >= 7 & values <= 8
  detractors <- values <= 6

  # Calculate weighted percentages (use which() to avoid NA issues)
  total_weight <- sum(weights)
  promoters_pct <- sum(weights[which(promoters)]) / total_weight * 100
  passives_pct <- sum(weights[which(passives)]) / total_weight * 100
  detractors_pct <- sum(weights[which(detractors)]) / total_weight * 100

  # NPS = % Promoters - % Detractors
  nps <- promoters_pct - detractors_pct

  # Calculate effective N
  sum_weights_squared <- sum(weights^2)
  eff_n <- if (sum_weights_squared > 0) {
    (total_weight^2) / sum_weights_squared
  } else {
    0
  }

  return(list(
    nps = nps,
    promoters_pct = promoters_pct,
    passives_pct = passives_pct,
    detractors_pct = detractors_pct,
    n_unweighted = length(values),
    n_weighted = total_weight,
    eff_n = eff_n
  ))
}


#' Calculate Proportions
#'
#' SHARED CODE NOTE: Should be in /shared/calculations.R
#'
#' @keywords internal
calculate_proportions <- function(values, weights, codes) {

  # Remove NA values
  # Use which() to ensure we get numeric indices without NA
  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values <- values[valid_idx]
  weights <- weights[valid_idx]

  if (length(values) == 0) {
    return(list(
      proportions = setNames(rep(NA, length(codes)), codes),
      n_unweighted = 0,
      n_weighted = 0,
      eff_n = 0
    ))
  }

  total_weight <- sum(weights)

  # Calculate proportion for each code
  proportions <- sapply(codes, function(code) {
    # Use which() to avoid NA issues in logical indexing
    matched_idx <- which(values == code)
    code_weight <- sum(weights[matched_idx], na.rm = TRUE)
    (code_weight / total_weight) * 100
  })

  names(proportions) <- codes

  # Calculate effective N
  sum_weights_squared <- sum(weights^2)
  eff_n <- if (sum_weights_squared > 0) {
    (total_weight^2) / sum_weights_squared
  } else {
    0
  }

  return(list(
    proportions = proportions,
    n_unweighted = length(values),
    n_weighted = total_weight,
    eff_n = eff_n
  ))
}


#' Calculate Top Box
#'
#' Calculates percentage of responses in top N values of scale.
#' Auto-detects scale from data.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @param n_boxes Integer, number of top values to include (1, 2, or 3)
#' @return List with proportion, scale_detected, top_values
#'
#' @keywords internal
calculate_top_box <- function(values, weights, n_boxes = 1) {

  # Remove NA values
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(
      proportion = NA,
      scale_detected = NA,
      top_values = NA,
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Detect scale
  unique_values <- sort(unique(values_valid))
  scale_min <- min(unique_values)
  scale_max <- max(unique_values)

  # Get top N values
  n_boxes <- min(n_boxes, length(unique_values))  # Can't exceed available values
  top_values <- tail(unique_values, n_boxes)

  # Calculate percentage (use which() to avoid NA issues)
  in_top_box <- values_valid %in% top_values
  top_weight <- sum(weights_valid[which(in_top_box)])
  total_weight <- sum(weights_valid)

  proportion <- (top_weight / total_weight) * 100

  return(list(
    proportion = proportion,
    scale_detected = paste0(scale_min, "-", scale_max),
    top_values = top_values,
    n_unweighted = length(values_valid),
    n_weighted = total_weight
  ))
}


#' Calculate Bottom Box
#'
#' Calculates percentage of responses in bottom N values of scale.
#' Auto-detects scale from data.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @param n_boxes Integer, number of bottom values to include (1, 2, or 3)
#' @return List with proportion, scale_detected, bottom_values
#'
#' @keywords internal
calculate_bottom_box <- function(values, weights, n_boxes = 1) {

  # Remove NA values
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(
      proportion = NA,
      scale_detected = NA,
      bottom_values = NA,
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Detect scale
  unique_values <- sort(unique(values_valid))
  scale_min <- min(unique_values)
  scale_max <- max(unique_values)

  # Get bottom N values
  n_boxes <- min(n_boxes, length(unique_values))
  bottom_values <- head(unique_values, n_boxes)

  # Calculate percentage (use which() to avoid NA issues)
  in_bottom_box <- values_valid %in% bottom_values
  bottom_weight <- sum(weights_valid[which(in_bottom_box)])
  total_weight <- sum(weights_valid)

  proportion <- (bottom_weight / total_weight) * 100

  return(list(
    proportion = proportion,
    scale_detected = paste0(scale_min, "-", scale_max),
    bottom_values = bottom_values,
    n_unweighted = length(values_valid),
    n_weighted = total_weight
  ))
}


#' Calculate Custom Range
#'
#' Calculates percentage of responses within a custom range (e.g., 9-10, 7-8).
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @param range_spec Character, range specification (e.g., "range:9-10")
#' @return List with proportion, range_values, range_spec
#'
#' @keywords internal
calculate_custom_range <- function(values, weights, range_spec) {

  # Parse range spec: "range:9-10" -> c(9, 10)
  range_str <- sub("^range:", "", tolower(range_spec))
  parts <- strsplit(range_str, "-")[[1]]

  if (length(parts) != 2) {
    warning(paste0("Invalid range specification: ", range_spec))
    return(list(
      proportion = NA,
      range_values = NA,
      range_spec = range_spec,
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  range_min <- as.numeric(parts[1])
  range_max <- as.numeric(parts[2])

  if (is.na(range_min) || is.na(range_max) || range_min > range_max) {
    warning(paste0("Invalid range values: ", range_spec))
    return(list(
      proportion = NA,
      range_values = NA,
      range_spec = range_spec,
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Generate sequence of values in range
  range_values <- seq(range_min, range_max)

  # Remove NA values
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(
      proportion = NA,
      range_values = range_values,
      range_spec = range_spec,
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Calculate proportion (use which() to avoid NA issues)
  in_range <- values_valid %in% range_values
  range_weight <- sum(weights_valid[which(in_range)])
  total_weight <- sum(weights_valid)

  proportion <- (range_weight / total_weight) * 100

  return(list(
    proportion = proportion,
    range_values = range_values,
    range_spec = range_spec,
    n_unweighted = length(values_valid),
    n_weighted = total_weight
  ))
}


#' Calculate Distribution
#'
#' Calculates percentage for each unique value found in data.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @return List with distribution (named list of percentages), n_unweighted, n_weighted
#'
#' @keywords internal
calculate_distribution <- function(values, weights) {

  # Remove NA values
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(
      distribution = list(),
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Get unique values
  unique_vals <- sort(unique(values_valid))

  # Calculate percentage for each value
  distribution <- list()
  total_weight <- sum(weights_valid)

  for (val in unique_vals) {
    matched_idx <- which(values_valid == val)
    val_weight <- sum(weights_valid[matched_idx])
    distribution[[as.character(val)]] <- (val_weight / total_weight) * 100
  }

  return(list(
    distribution = distribution,
    n_unweighted = length(values_valid),
    n_weighted = total_weight
  ))
}


#' Calculate Composite Score (Aggregate Mean)
#'
#' Calculates composite score as mean of source questions.
#' For MVT, uses simple mean of source questions.
#'
#' SHARED CODE NOTE: This should use /shared/composite_calculator.R::calculate_composite_mean()
#' Identical logic to TurasTabs composite calculation.
#'
#' @keywords internal
calculate_composite_score <- function(wave_df, wave_id, source_questions, question_map) {

  # Extract data for each source question
  source_values <- list()

  for (src_code in source_questions) {
    src_data <- extract_question_data(wave_df, wave_id, src_code, question_map)

    if (!is.null(src_data)) {
      source_values[[src_code]] <- src_data
    }
  }

  if (length(source_values) == 0) {
    return(NULL)
  }

  # Calculate mean across source questions for each respondent
  # Build matrix: rows = respondents, cols = source questions
  n_resp <- nrow(wave_df)
  n_sources <- length(source_values)

  source_matrix <- matrix(NA, nrow = n_resp, ncol = n_sources)

  for (i in seq_along(source_values)) {
    source_matrix[, i] <- source_values[[i]]
  }

  # Calculate row means (composite score per respondent)
  composite_values <- rowMeans(source_matrix, na.rm = TRUE)

  # Handle cases where all source questions are NA for a respondent
  # Use which() to avoid NA issues in logical indexing
  all_na_idx <- which(apply(source_matrix, 1, function(row) all(is.na(row))))
  if (length(all_na_idx) > 0) {
    composite_values[all_na_idx] <- NA
  }

  # Calculate weighted mean of composite scores
  result <- calculate_weighted_mean(
    values = composite_values,
    weights = wave_df$weight_var
  )

  return(result)
}


#' Calculate Composite Values Per Respondent
#'
#' Calculates composite score for each respondent (row mean of source questions).
#' Returns the composite values vector which can then be treated like rating values.
#'
#' @keywords internal
calculate_composite_values_per_respondent <- function(wave_df, wave_id, source_questions, question_map) {

  # Extract data for each source question
  source_values <- list()
  missing_sources <- character(0)

  for (src_code in source_questions) {
    # Get wave-specific code for this source question
    wave_code <- get_wave_question_code(question_map, src_code, wave_id)

    src_data <- extract_question_data(wave_df, wave_id, src_code, question_map)

    if (!is.null(src_data)) {
      source_values[[src_code]] <- src_data
      cat(paste0("    ✓ Found source question ", src_code, " (", wave_code, ") for ", wave_id, "\n"))
    } else {
      missing_sources <- c(missing_sources, src_code)
      if (!is.na(wave_code)) {
        cat(paste0("    ✗ Source question ", src_code, " mapped to ", wave_code, " but not found in ", wave_id, " data\n"))
      } else {
        cat(paste0("    ✗ Source question ", src_code, " not mapped for ", wave_id, "\n"))
      }
    }
  }

  if (length(source_values) == 0) {
    warning(paste0("No valid source questions found for composite in ", wave_id,
                   ". Missing: ", paste(missing_sources, collapse = ", ")))
    return(rep(NA, nrow(wave_df)))
  }

  if (length(missing_sources) > 0) {
    cat(paste0("    Note: ", length(source_values), "/", length(source_questions),
                   " source questions found for ", wave_id, "\n"))
  }

  # Build matrix: rows = respondents, cols = source questions
  n_resp <- nrow(wave_df)
  n_sources <- length(source_values)
  source_matrix <- matrix(NA, nrow = n_resp, ncol = n_sources)

  for (i in seq_along(source_values)) {
    source_matrix[, i] <- source_values[[i]]
  }

  # Calculate row means (composite score per respondent)
  composite_values <- rowMeans(source_matrix, na.rm = TRUE)

  # Set to NA if all sources were NA for a respondent
  # Use which() to avoid NA issues in logical indexing
  all_na_idx <- which(apply(source_matrix, 1, function(row) all(is.na(row))))
  if (length(all_na_idx) > 0) {
    composite_values[all_na_idx] <- NA
  }

  return(composite_values)
}
