# ==============================================================================
# TurasTracker - Trend Calculator
# ==============================================================================
#
# Calculates trends and wave-over-wave changes for tracked questions.
# Supports: Rating questions, Single choice, NPS, Index scores
#
# SHARED CODE NOTES:
# - Significance testing functions should be in /shared/significance_tests.R
# - Mean/proportion calculation patterns shared with TurasTabs
# - Future: Extract calculate_mean_with_ci, calculate_proportion_with_ci
#
# ==============================================================================

#' Calculate Trends for All Questions
#'
#' Main function to calculate trends across waves for all tracked questions.
#'
#' @param config Configuration object
#' @param question_map Question map index
#' @param wave_data List of wave data frames
#' @return List containing trend results for each question
#'
#' @export
#' Normalize Question Type
#'
#' Maps question types to standardized internal types.
#' Supports both TurasTabs and legacy TurasTracker naming conventions.
#'
#' @keywords internal
normalize_question_type <- function(q_type) {
  # Map TurasTabs types to internal tracker types
  type_map <- c(
    "Single_Response" = "single_choice",
    "SingleChoice" = "single_choice",
    "Multi_Mention" = "multi_choice",
    "MultiChoice" = "multi_choice",
    "Rating" = "rating",
    "Likert" = "rating",  # Treat Likert same as Rating
    "NPS" = "nps",
    "Index" = "rating",  # Index scores treated as ratings
    "Numeric" = "rating",  # Numeric treated as rating
    "Open_End" = "open_end",
    "OpenEnd" = "open_end",
    "Ranking" = "ranking",
    "Composite" = "composite"
  )

  normalized <- type_map[q_type]

  if (is.na(normalized)) {
    return(tolower(q_type))  # Return lowercase if not in map
  }

  return(as.character(normalized))
}


calculate_all_trends <- function(config, question_map, wave_data) {

  message("\n================================================================================")
  message("CALCULATING TRENDS")
  message("================================================================================\n")

  tracked_questions <- config$tracked_questions$QuestionCode
  wave_ids <- config$waves$WaveID

  trend_results <- list()

  for (q_code in tracked_questions) {
    message(paste0("Processing question: ", q_code))

    # Get question metadata
    metadata <- get_question_metadata(question_map, q_code)

    if (is.null(metadata)) {
      warning(paste0("  Question ", q_code, " not found in mapping - skipping"))
      next
    }

    # Normalize question type to internal standard
    q_type_raw <- metadata$QuestionType
    q_type <- normalize_question_type(q_type_raw)

    trend_result <- tryCatch({
      if (q_type == "rating") {
        calculate_rating_trend(q_code, question_map, wave_data, config)
      } else if (q_type == "nps") {
        calculate_nps_trend(q_code, question_map, wave_data, config)
      } else if (q_type == "single_choice") {
        calculate_single_choice_trend(q_code, question_map, wave_data, config)
      } else if (q_type == "multi_choice") {
        warning(paste0("  Multi-choice questions not yet supported in tracker - skipping"))
        NULL
      } else if (q_type == "composite") {
        calculate_composite_trend(q_code, question_map, wave_data, config)
      } else if (q_type == "open_end") {
        warning(paste0("  Open-end questions cannot be tracked - skipping"))
        NULL
      } else if (q_type == "ranking") {
        warning(paste0("  Ranking questions not yet supported in tracker - skipping"))
        NULL
      } else {
        warning(paste0("  Question type '", q_type_raw, "' not supported - skipping"))
        NULL
      }
    }, error = function(e) {
      warning(paste0("  Error calculating trend for ", q_code, ": ", e$message))
      NULL
    })

    if (!is.null(trend_result)) {
      trend_results[[q_code]] <- trend_result
      message(paste0("  ✓ Trend calculated"))
    }
  }

  message(paste0("\nCompleted trend calculation for ", length(trend_results), " questions"))

  return(trend_results)
}


#' Calculate Rating Question Trend
#'
#' Calculates mean scores across waves for rating/index questions.
#'
#' SHARED CODE NOTE: Mean calculation logic should be in /shared/calculations.R
#'
#' @keywords internal
calculate_rating_trend <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Calculate mean for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    # Extract question data for this wave
    wave_df <- wave_data[[wave_id]]
    q_data <- extract_question_data(wave_df, wave_id, q_code, question_map)

    if (is.null(q_data)) {
      wave_results[[wave_id]] <- list(
        mean = NA,
        sd = NA,
        n_unweighted = NA,
        n_weighted = NA,
        available = FALSE,
        values = NULL,
        weights = NULL
      )
      next
    }

    # Calculate weighted mean
    result <- calculate_weighted_mean(
      values = q_data,
      weights = wave_df$weight_var
    )

    # Store raw values and weights for distribution calculation
    wave_results[[wave_id]] <- c(
      result,
      list(
        available = TRUE,
        values = q_data,
        weights = wave_df$weight_var
      )
    )
  }

  # Calculate wave-over-wave changes
  changes <- calculate_changes(wave_results, wave_ids, "mean")

  # Perform significance testing
  sig_tests <- perform_significance_tests_means(wave_results, wave_ids, config)

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "mean",
    wave_results = wave_results,
    changes = changes,
    significance = sig_tests
  ))
}


#' Calculate NPS Trend
#'
#' Calculates Net Promoter Score across waves.
#' NPS = % Promoters (9-10) - % Detractors (0-6)
#'
#' @keywords internal
calculate_nps_trend <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Calculate NPS for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    wave_df <- wave_data[[wave_id]]
    q_data <- extract_question_data(wave_df, wave_id, q_code, question_map)

    if (is.null(q_data)) {
      wave_results[[wave_id]] <- list(
        nps = NA,
        promoters_pct = NA,
        passives_pct = NA,
        detractors_pct = NA,
        n_unweighted = NA,
        n_weighted = NA,
        available = FALSE
      )
      next
    }

    # Calculate NPS
    result <- calculate_nps_score(
      values = q_data,
      weights = wave_df$weight_var
    )

    wave_results[[wave_id]] <- c(result, list(available = TRUE))
  }

  # Calculate wave-over-wave changes
  changes <- calculate_changes(wave_results, wave_ids, "nps")

  # Significance testing for NPS (treat as proportion difference)
  sig_tests <- perform_significance_tests_nps(wave_results, wave_ids, config)

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "nps",
    wave_results = wave_results,
    changes = changes,
    significance = sig_tests
  ))
}


#' Calculate Single Choice Trend
#'
#' Calculates proportions for each response option across waves.
#'
#' @keywords internal
calculate_single_choice_trend <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get all unique response codes across all waves
  all_codes <- character(0)
  for (wave_id in wave_ids) {
    wave_df <- wave_data[[wave_id]]
    q_data <- extract_question_data(wave_df, wave_id, q_code, question_map)
    if (!is.null(q_data)) {
      all_codes <- unique(c(all_codes, unique(q_data[!is.na(q_data)])))
    }
  }

  # Calculate proportions for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    wave_df <- wave_data[[wave_id]]
    q_data <- extract_question_data(wave_df, wave_id, q_code, question_map)

    if (is.null(q_data)) {
      wave_results[[wave_id]] <- list(
        proportions = NA,
        n_unweighted = NA,
        n_weighted = NA,
        available = FALSE
      )
      next
    }

    # Calculate proportions for each code
    result <- calculate_proportions(
      values = q_data,
      weights = wave_df$weight_var,
      codes = all_codes
    )

    wave_results[[wave_id]] <- c(result, list(available = TRUE))
  }

  # Calculate changes for each response code
  changes <- list()
  for (code in all_codes) {
    changes[[as.character(code)]] <- calculate_changes(wave_results, wave_ids, "proportions", code)
  }

  # Significance tests for each code
  sig_tests <- list()
  for (code in all_codes) {
    sig_tests[[as.character(code)]] <- perform_significance_tests_proportions(
      wave_results, wave_ids, config, code
    )
  }

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "proportions",
    response_codes = all_codes,
    wave_results = wave_results,
    changes = changes,
    significance = sig_tests
  ))
}


#' Calculate Composite Score Trend
#'
#' Calculates composite score trend across waves.
#' Composite is mean (or other aggregation) of source questions.
#'
#' SHARED CODE NOTE: Composite calculation should use /shared/composite_calculator.R
#' For MVT, using simple mean calculation inline.
#'
#' @keywords internal
calculate_composite_trend <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get source questions for this composite
  # For MVT, assume metadata has SourceQuestions field (comma-separated)
  source_questions <- get_composite_source_questions(question_map, q_code)

  if (is.null(source_questions) || length(source_questions) == 0) {
    warning(paste0("  No source questions defined for composite ", q_code))
    return(NULL)
  }

  # Calculate composite for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    wave_df <- wave_data[[wave_id]]

    # Calculate composite score
    result <- calculate_composite_score(
      wave_df = wave_df,
      wave_id = wave_id,
      source_questions = source_questions,
      question_map = question_map
    )

    if (is.null(result)) {
      wave_results[[wave_id]] <- list(
        mean = NA,
        sd = NA,
        n_unweighted = NA,
        n_weighted = NA,
        available = FALSE
      )
    } else {
      wave_results[[wave_id]] <- c(result, list(available = TRUE))
    }
  }

  # Calculate wave-over-wave changes
  changes <- calculate_changes(wave_results, wave_ids, "mean")

  # Perform significance testing
  sig_tests <- perform_significance_tests_means(wave_results, wave_ids, config)

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "composite",
    source_questions = source_questions,
    wave_results = wave_results,
    changes = changes,
    significance = sig_tests
  ))
}


#' Get Composite Source Questions
#'
#' Retrieves source question codes for a composite from question mapping.
#'
#' @keywords internal
get_composite_source_questions <- function(question_map, composite_code) {

  # Check if metadata has SourceQuestions field
  metadata_df <- question_map$question_metadata

  comp_row <- metadata_df[metadata_df$QuestionCode == composite_code, ]

  if (nrow(comp_row) == 0) {
    return(NULL)
  }

  # Check for SourceQuestions column
  if (!"SourceQuestions" %in% names(metadata_df)) {
    return(NULL)
  }

  source_str <- comp_row$SourceQuestions[1]

  if (is.na(source_str) || source_str == "") {
    return(NULL)
  }

  # Parse comma-separated list
  sources <- trimws(strsplit(source_str, ",")[[1]])

  return(sources)
}


#' Calculate Composite Score
#'
#' Calculates composite score for a single wave.
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
  all_na <- apply(source_matrix, 1, function(row) all(is.na(row)))
  composite_values[all_na] <- NA

  # Calculate weighted mean of composite scores
  result <- calculate_weighted_mean(
    values = composite_values,
    weights = wave_df$weight_var
  )

  return(result)
}


#' Calculate Weighted Mean
#'
#' SHARED CODE NOTE: This should be in /shared/calculations.R
#' Used by both TurasTabs and TurasTracker
#'
#' @keywords internal
calculate_weighted_mean <- function(values, weights) {

  # Remove NA values
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values <- values[valid_idx]
  weights <- weights[valid_idx]

  if (length(values) == 0) {
    return(list(
      mean = NA,
      sd = NA,
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Calculate weighted mean
  weighted_mean <- sum(values * weights) / sum(weights)

  # Calculate weighted standard deviation
  weighted_var <- sum(weights * (values - weighted_mean)^2) / sum(weights)
  weighted_sd <- sqrt(weighted_var)

  return(list(
    mean = weighted_mean,
    sd = weighted_sd,
    n_unweighted = length(values),
    n_weighted = sum(weights)
  ))
}


#' Calculate NPS Score
#'
#' @keywords internal
calculate_nps_score <- function(values, weights) {

  # Remove NA values
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values <- values[valid_idx]
  weights <- weights[valid_idx]

  if (length(values) == 0) {
    return(list(
      nps = NA,
      promoters_pct = NA,
      passives_pct = NA,
      detractors_pct = NA,
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Classify responses
  promoters <- values >= 9
  passives <- values >= 7 & values <= 8
  detractors <- values <= 6

  # Calculate weighted percentages
  total_weight <- sum(weights)
  promoters_pct <- sum(weights[promoters]) / total_weight * 100
  passives_pct <- sum(weights[passives]) / total_weight * 100
  detractors_pct <- sum(weights[detractors]) / total_weight * 100

  # NPS = % Promoters - % Detractors
  nps <- promoters_pct - detractors_pct

  return(list(
    nps = nps,
    promoters_pct = promoters_pct,
    passives_pct = passives_pct,
    detractors_pct = detractors_pct,
    n_unweighted = length(values),
    n_weighted = total_weight
  ))
}


#' Calculate Proportions
#'
#' SHARED CODE NOTE: Should be in /shared/calculations.R
#'
#' @keywords internal
calculate_proportions <- function(values, weights, codes) {

  # Remove NA values
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values <- values[valid_idx]
  weights <- weights[valid_idx]

  if (length(values) == 0) {
    return(list(
      proportions = setNames(rep(NA, length(codes)), codes),
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  total_weight <- sum(weights)

  # Calculate proportion for each code
  proportions <- sapply(codes, function(code) {
    code_weight <- sum(weights[values == code])
    (code_weight / total_weight) * 100
  })

  names(proportions) <- codes

  return(list(
    proportions = proportions,
    n_unweighted = length(values),
    n_weighted = total_weight
  ))
}


#' Calculate Wave-over-Wave Changes
#'
#' @keywords internal
calculate_changes <- function(wave_results, wave_ids, metric_name, sub_metric = NULL) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get metric values
    if (!is.null(sub_metric)) {
      # For proportions, access by sub_metric (response code)
      current_val <- current[[metric_name]][[as.character(sub_metric)]]
      previous_val <- previous[[metric_name]][[as.character(sub_metric)]]
    } else {
      current_val <- current[[metric_name]]
      previous_val <- previous[[metric_name]]
    }

    # Calculate changes
    if (!is.na(current_val) && !is.na(previous_val)) {
      absolute_change <- current_val - previous_val
      percentage_change <- (absolute_change / previous_val) * 100

      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = absolute_change,
        percentage_change = percentage_change,
        direction = if (absolute_change > 0) "up" else if (absolute_change < 0) "down" else "stable"
      )
    } else {
      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = NA,
        percentage_change = NA,
        direction = "unavailable"
      )
    }
  }

  return(changes)
}


#' Perform Significance Tests for Means
#'
#' SHARED CODE NOTE: T-test logic should be in /shared/significance_tests.R
#' This is identical to TurasTabs t-test implementation
#'
#' @keywords internal
perform_significance_tests_means <- function(wave_results, wave_ids, config) {

  alpha <- get_setting(config, "alpha", default = 0.05)
  min_base <- get_setting(config, "minimum_base", default = 30)

  sig_tests <- list()

  # Test consecutive waves
  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Check if both available and have sufficient base
    if (current$available && previous$available &&
        current$n_unweighted >= min_base && previous$n_unweighted >= min_base) {

      # Two-sample t-test for means
      # SHARED CODE NOTE: Extract to shared/significance_tests.R::t_test_means()
      t_result <- t_test_for_means(
        mean1 = previous$mean,
        sd1 = previous$sd,
        n1 = previous$n_unweighted,
        mean2 = current$mean,
        sd2 = current$sd,
        n2 = current$n_unweighted,
        alpha = alpha
      )

      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- t_result
    } else {
      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
        significant = FALSE,
        reason = "insufficient_base_or_unavailable"
      )
    }
  }

  return(sig_tests)
}


#' Perform Significance Tests for Proportions
#'
#' SHARED CODE NOTE: Z-test logic should be in /shared/significance_tests.R
#'
#' @keywords internal
perform_significance_tests_proportions <- function(wave_results, wave_ids, config, response_code) {

  alpha <- get_setting(config, "alpha", default = 0.05)
  min_base <- get_setting(config, "minimum_base", default = 30)

  sig_tests <- list()

  # Test consecutive waves
  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    if (current$available && previous$available &&
        current$n_unweighted >= min_base && previous$n_unweighted >= min_base) {

      # Get proportions for this response code
      p1 <- previous$proportions[[as.character(response_code)]] / 100  # Convert to proportion
      p2 <- current$proportions[[as.character(response_code)]] / 100

      # Z-test for proportions
      # SHARED CODE NOTE: Extract to shared/significance_tests.R::z_test_proportions()
      z_result <- z_test_for_proportions(
        p1 = p1,
        n1 = previous$n_unweighted,
        p2 = p2,
        n2 = current$n_unweighted,
        alpha = alpha
      )

      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- z_result
    } else {
      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
        significant = FALSE,
        reason = "insufficient_base_or_unavailable"
      )
    }
  }

  return(sig_tests)
}


#' Perform Significance Tests for NPS
#'
#' @keywords internal
perform_significance_tests_nps <- function(wave_results, wave_ids, config) {

  # NPS is a difference of proportions, so we test the NPS score directly
  # This is a simplified approach for MVT
  # Could be enhanced with proper proportion difference testing

  alpha <- get_setting(config, "alpha", default = 0.05)
  min_base <- get_setting(config, "minimum_base", default = 30)

  sig_tests <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    if (current$available && previous$available &&
        current$n_unweighted >= min_base && previous$n_unweighted >= min_base) {

      # For MVT, we'll use a simple comparison
      # Future enhancement: Test promoter and detractor proportions separately
      nps_diff <- abs(current$nps - previous$nps)

      # Simple heuristic: NPS difference > 10 points is "significant"
      # This is NOT statistically rigorous - just for MVT
      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
        significant = nps_diff > 10,
        nps_difference = current$nps - previous$nps,
        note = "MVT: Simple threshold comparison, not statistical test"
      )
    } else {
      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
        significant = FALSE,
        reason = "insufficient_base_or_unavailable"
      )
    }
  }

  return(sig_tests)
}


#' T-Test for Means
#'
#' Two-sample t-test for comparing means.
#'
#' SHARED CODE NOTE: This should be extracted to /shared/significance_tests.R
#' Identical to TurasTabs t-test implementation
#'
#' @keywords internal
t_test_for_means <- function(mean1, sd1, n1, mean2, sd2, n2, alpha = 0.05) {

  # Pooled standard deviation
  pooled_var <- ((n1 - 1) * sd1^2 + (n2 - 1) * sd2^2) / (n1 + n2 - 2)
  pooled_sd <- sqrt(pooled_var)

  # Standard error
  se <- pooled_sd * sqrt(1/n1 + 1/n2)

  # T statistic
  t_stat <- (mean2 - mean1) / se

  # Degrees of freedom
  df <- n1 + n2 - 2

  # P-value (two-tailed)
  p_value <- 2 * pt(-abs(t_stat), df)

  # Significant?
  significant <- p_value < alpha

  return(list(
    t_stat = t_stat,
    df = df,
    p_value = p_value,
    significant = significant,
    alpha = alpha
  ))
}


#' Z-Test for Proportions
#'
#' Two-sample z-test for comparing proportions.
#'
#' SHARED CODE NOTE: This should be extracted to /shared/significance_tests.R
#' Identical to TurasTabs z-test implementation
#'
#' @keywords internal
z_test_for_proportions <- function(p1, n1, p2, n2, alpha = 0.05) {

  # Pooled proportion
  p_pooled <- (p1 * n1 + p2 * n2) / (n1 + n2)

  # Standard error
  se <- sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))

  # Handle zero SE
  if (se == 0) {
    return(list(
      z_stat = 0,
      p_value = 1,
      significant = FALSE,
      alpha = alpha
    ))
  }

  # Z statistic
  z_stat <- (p2 - p1) / se

  # P-value (two-tailed)
  p_value <- 2 * pnorm(-abs(z_stat))

  # Significant?
  significant <- p_value < alpha

  return(list(
    z_stat = z_stat,
    p_value = p_value,
    significant = significant,
    alpha = alpha
  ))
}
