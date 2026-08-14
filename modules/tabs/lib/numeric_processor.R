# ==============================================================================
# MODULE 8: NUMERIC_PROCESSOR.R
# ==============================================================================
#
# PURPOSE:
#   Process numeric questions with bins and summary statistics
#   V10.0 NEW FEATURE
#
# FUNCTIONS:
#   - process_numeric_question() - Main numeric processor
#   - calculate_numeric_statistics() - Mean, median, mode, SD
#   - detect_outliers_iqr() - IQR-based outlier detection
#   - categorize_numeric_bins() - Bin numeric values
#
# DEPENDENCIES:
#   - utilities.R (formatting, safe operations)
#   - cell_calculator.R (base calculations)
#   - statistics.R (significance testing)
#
# VERSION: 1.0.0
# DATE: 2025-10-25
# ==============================================================================

# Row type constants
FREQUENCY_ROW_TYPE <- "Frequency"
COLUMN_PCT_ROW_TYPE <- "Column %"
AVERAGE_ROW_TYPE <- "Average"
RATIO_ROW_TYPE <- "RatioMean"
TOTAL_COLUMN <- "Total"

# The Questions-sheet columns that describe a ratio-of-totals row.
NUMERIC_RATIO_COLS <- c(numerator = "RatioNumerator",
                        denominator = "RatioDenominator")

#' One optional Questions-sheet cell, or a fallback
#'
#' A structure workbook written before a column existed simply has no such
#' column, and an empty cell means "not set" - both must read the same.
#'
#' @param question_info One row of the Questions sheet.
#' @param column The column name to read.
#' @param fallback What to return when it is absent or blank.
#'
#' @return A single string.
#' @keywords internal
question_text_or <- function(question_info, column, fallback) {
  if (!column %in% names(question_info)) {
    return(fallback)
  }
  value <- trimws(as.character(question_info[[column]][1]))
  if (is.na(value) || !nzchar(value)) {
    return(fallback)
  }
  return(value)
}

#' The ratio-of-totals specification for a numeric question, or NULL
#'
#' A question declares one by naming the two columns to total. Naming one
#' without the other, or naming a column that is not in the data, REFUSES -
#' a ratio row that silently did not appear would leave the reader with the
#' per-person mean and no sign that the other number was meant to be there.
#'
#' @param question_info One row of the Questions sheet.
#' @param data The (filtered) survey data.
#'
#' @return A list of \code{numerator}, \code{denominator} and \code{label}, or
#'   NULL when the question declares no ratio.
#' @keywords internal
numeric_ratio_spec <- function(question_info, data) {
  named <- vapply(NUMERIC_RATIO_COLS, function(col) {
    question_text_or(question_info, col, "")
  }, character(1))
  if (!any(nzchar(named))) {
    return(NULL)
  }

  question_col <- question_info$QuestionCode
  if (!all(nzchar(named))) {
    tabs_refuse(
      code = "CFG_RATIO_INCOMPLETE",
      title = paste0("Half a Ratio Row: ", question_col),
      problem = sprintf(
        "Question '%s' names %s but not %s.", question_col,
        paste(NUMERIC_RATIO_COLS[nzchar(named)], collapse = " and "),
        paste(NUMERIC_RATIO_COLS[!nzchar(named)], collapse = " and ")),
      why_it_matters = "A ratio of totals needs both halves. With one named, the row cannot be built and the table would show only the per-respondent mean, with nothing saying the other figure is missing.",
      how_to_fix = c(
        sprintf("Fill both %s and %s on this question's Questions row",
                NUMERIC_RATIO_COLS[["numerator"]], NUMERIC_RATIO_COLS[["denominator"]]),
        "Or clear both, to publish the mean alone"
      )
    )
  }

  missing <- named[!named %in% names(data)]
  if (length(missing)) {
    tabs_refuse(
      code = "DATA_RATIO_COLUMN_NOT_FOUND",
      title = paste0("Ratio Column Missing: ", question_col),
      problem = sprintf("Question '%s' names column(s) not in the data: %s",
                        question_col, paste(missing, collapse = ", ")),
      why_it_matters = "The ratio row totals these columns. Without them it cannot be computed.",
      how_to_fix = c(
        "Check the spelling against the data file's column names (case-sensitive)",
        sprintf("Columns named: %s", paste(named, collapse = ", "))
      ),
      missing = unname(missing)
    )
  }

  return(list(
    numerator = unname(named[["numerator"]]),
    denominator = unname(named[["denominator"]]),
    label = question_text_or(question_info, "RatioLabel", "Mean per unit")
  ))
}

#' Total the numerator over the total denominator, for one banner column
#'
#' Weighted throughout: Sum(w * numerator) / Sum(w * denominator), which
#' collapses to the plain ratio on an unweighted run. A respondent counts only
#' when BOTH values are present and their denominator is above zero, so the two
#' totals always describe the same people.
#'
#' @param data The (filtered) survey data.
#' @param spec From \code{numeric_ratio_spec()}.
#' @param row_idx The banner column's row indices.
#' @param weights The full weight vector.
#'
#' @return The ratio, or NA when nothing qualifies.
#' @keywords internal
calculate_ratio_of_totals <- function(data, spec, row_idx, weights) {
  if (length(row_idx) == 0) {
    return(NA_real_)
  }
  numerator <- suppressWarnings(as.numeric(data[[spec$numerator]][row_idx]))
  denominator <- suppressWarnings(as.numeric(data[[spec$denominator]][row_idx]))
  w <- weights[row_idx]

  usable <- !is.na(numerator) & !is.na(denominator) & denominator > 0 & !is.na(w)
  if (!any(usable)) {
    return(NA_real_)
  }
  bottom <- sum(w[usable] * denominator[usable])
  if (!is.finite(bottom) || bottom <= 0) {
    return(NA_real_)
  }
  return(sum(w[usable] * numerator[usable]) / bottom)
}

# ==============================================================================
# MAIN NUMERIC QUESTION PROCESSOR
# ==============================================================================

#' Process Numeric Question
#'
#' Processes numeric questions with optional bins and summary statistics.
#' Part 1: Frequency distribution by bins (if bins defined in options)
#' Part 2: Summary statistics (mean, median, mode, SD, outliers)
#' Part 3: Significance testing for means
#'
#' V10.0: NEW FEATURE
#'
#' @param data Data frame, survey data
#' @param question_info Data frame row, question metadata
#' @param question_options Data frame, bin definitions (Min, Max, OptionText)
#' @param banner_info List, banner structure
#' @param banner_row_indices List, row indices by column
#' @param master_weights Numeric vector, weights
#' @param banner_bases List, base sizes
#' @param config List, configuration
#' @param is_weighted Logical, weighting flag
#' @return Data frame with numeric results
#' @export
process_numeric_question <- function(data, question_info, question_options,
                                    banner_info, banner_row_indices,
                                    master_weights, banner_bases,
                                    config, is_weighted) {
  
  question_col <- question_info$QuestionCode
  internal_keys <- banner_info$internal_keys

  # Having Options rows is not the same as being binned. Bins are defined by
  # Min and Max; option rows without them are display labels, and there is no
  # frequency distribution to build from them. Without this the run either fell
  # over in categorize_numeric_bins() or produced an all-empty bin table under
  # the question's name.
  has_bins <- nrow(question_options) > 0 &&
    all(c("Min", "Max") %in% names(question_options))
  
  results_list <- list()
  
  # ===========================================================================
  # PART 1: Frequency Distribution (if bins defined)
  # ===========================================================================
  
  if (has_bins) {
    # Categorize all data into bins
    all_binned <- categorize_numeric_bins(
      suppressWarnings(as.numeric(data[[question_col]])),
      question_options
    )
    
    # Get unique bin labels in display order
    if ("DisplayOrder" %in% names(question_options)) {
      sorted_options <- question_options[order(question_options$DisplayOrder), ]
    } else {
      sorted_options <- question_options[order(question_options$Min), ]
    }
    
    bin_labels <- as.character(sorted_options$OptionText)
    
    # Calculate frequencies for each bin
    for (bin_label in bin_labels) {
      row_counts <- setNames(numeric(length(internal_keys)), internal_keys)
      row_pcts <- setNames(numeric(length(internal_keys)), internal_keys)
      
      for (key in internal_keys) {
        row_idx <- banner_row_indices[[key]]
        
        if (length(row_idx) > 0) {
          subset_binned <- all_binned[row_idx]
          subset_weights <- master_weights[row_idx]
          
          # Count matches
          matching <- !is.na(subset_binned) & (subset_binned == bin_label)
          count <- sum(subset_weights[matching])
          row_counts[key] <- count
          
          # Calculate percentage
          base_info <- banner_bases[[key]]
          weighted_base <- if (!is.null(base_info$weighted)) {
            base_info$weighted
          } else {
            base_info$unweighted
          }
          row_pcts[key] <- if (weighted_base > 0) (count / weighted_base) * 100 else NA_real_
        } else {
          row_counts[key] <- 0
          row_pcts[key] <- NA_real_
        }
      }
      
      # Create frequency row
      if (config$show_frequency) {
        freq_row <- data.frame(
          RowLabel = bin_label,
          RowType = FREQUENCY_ROW_TYPE,
          RowSource = "individual",
          stringsAsFactors = FALSE
        )
        for (key in internal_keys) {
          freq_row[[key]] <- format_output_value(
            row_counts[key],
            "frequency"
          )
        }
        results_list[[length(results_list) + 1]] <- freq_row
      }

      # Create percentage row
      if (config$show_percent_column) {
        pct_row <- data.frame(
          RowLabel = bin_label,
          RowType = COLUMN_PCT_ROW_TYPE,
          RowSource = "individual",
          stringsAsFactors = FALSE
        )
        for (key in internal_keys) {
          pct_row[[key]] <- format_output_value(
            row_pcts[key],
            "percent",
            decimal_places_percent = config$decimal_places_percent
          )
        }
        results_list[[length(results_list) + 1]] <- pct_row
      }
    }
  }
  
  # ===========================================================================
  # PART 2: Summary Statistics
  # ===========================================================================
  
  # Calculate statistics for each banner column
  stat_results <- list()
  stat_value_sets <- list()
  stat_weight_sets <- list()
  
  for (key in internal_keys) {
    row_idx <- banner_row_indices[[key]]
    
    if (length(row_idx) > 0) {
      subset_data <- data[row_idx, , drop = FALSE]
      subset_weights <- master_weights[row_idx]
      
      stats <- calculate_numeric_statistics(
        subset_data, question_info, subset_weights, config, is_weighted
      )
      
      stat_results[[key]] <- stats
      
      # Store for significance testing
      numeric_values <- suppressWarnings(as.numeric(subset_data[[question_col]]))
      valid_idx <- !is.na(numeric_values)
      stat_value_sets[[key]] <- numeric_values[valid_idx]
      stat_weight_sets[[key]] <- subset_weights[valid_idx]
    } else {
      stat_results[[key]] <- list(
        mean = NA_real_, median = NA_real_, mode = NA_real_,
        sd = NA_real_, outlier_count = 0
      )
    }
  }
  
  # Mean row. MeanLabel renames it where "Mean" alone would be ambiguous - a
  # question that also carries a ratio row needs the two told apart ("Mean per
  # buyer" against "Mean per transaction"). The RowType is untouched, so
  # significance, styling and the v2 recompute all still find it.
  mean_row <- data.frame(
    RowLabel = question_text_or(question_info, "MeanLabel", "Mean"),
    RowType = AVERAGE_ROW_TYPE,
    stringsAsFactors = FALSE
  )

  for (key in internal_keys) {
    mean_row[[key]] <- format_output_value(
      stat_results[[key]]$mean,
      "numeric",
      decimal_places_numeric = config$decimal_places_numeric
    )
  }

  results_list[[length(results_list) + 1]] <- mean_row

  # Ratio-of-totals row, when the question names a numerator and a denominator.
  #
  # The mean above averages PEOPLE: each respondent's own value counts once,
  # whatever their size. This one averages the UNITS underneath - total spend
  # over total transactions - so somebody who transacts eight times a month
  # counts eight times. On prepaid electricity the two read R534.63 and R295.61
  # off the same 764 people, and reporting either as "the" average without the
  # other has already caused a wave comparison to look like a collapse that
  # never happened (Electrum VAS, 10 Aug 2026).
  #
  # Deliberately NOT subject to exclude_outliers_from_stats: dropping a person
  # from one total and not the other would produce a ratio of two different
  # populations. The base is everyone with both values present and a
  # denominator above zero.
  ratio_spec <- numeric_ratio_spec(question_info, data)
  if (!is.null(ratio_spec)) {
    ratio_row <- data.frame(
      RowLabel = ratio_spec$label,
      RowType = RATIO_ROW_TYPE,
      stringsAsFactors = FALSE
    )
    for (key in internal_keys) {
      row_idx <- banner_row_indices[[key]]
      ratio_row[[key]] <- format_output_value(
        calculate_ratio_of_totals(data, ratio_spec, row_idx, master_weights),
        "numeric",
        decimal_places_numeric = config$decimal_places_numeric
      )
    }
    results_list[[length(results_list) + 1]] <- ratio_row
  }

  # Median row (if enabled and unweighted)
  if (config$show_numeric_median) {
    median_row <- data.frame(
      RowLabel = "Median",
      RowType = "Median",
      stringsAsFactors = FALSE
    )
    
    if (is_weighted) {
      for (key in internal_keys) {
        median_row[[key]] <- "N/A (weighted)"
      }
    } else {
      for (key in internal_keys) {
        median_row[[key]] <- format_output_value(
          stat_results[[key]]$median,
          "numeric",
          decimal_places_numeric = config$decimal_places_numeric
        )
      }
    }
    results_list[[length(results_list) + 1]] <- median_row
  }
  
  # Mode row (if enabled and unweighted)
  if (config$show_numeric_mode) {
    mode_row <- data.frame(
      RowLabel = "Mode",
      RowType = "Mode",
      stringsAsFactors = FALSE
    )
    
    if (is_weighted) {
      for (key in internal_keys) {
        mode_row[[key]] <- "N/A (weighted)"
      }
    } else {
      for (key in internal_keys) {
        mode_val <- stat_results[[key]]$mode
        mode_row[[key]] <- if (is.na(mode_val)) {
          "No single mode"
        } else {
          format_output_value(
            mode_val,
            "numeric",
            decimal_places_numeric = config$decimal_places_numeric
          )
        }
      }
    }
    results_list[[length(results_list) + 1]] <- mode_row
  }
  
  # Standard deviation row. Switchable since 2026-08: on a skewed measure like
  # monthly spend the SD routinely exceeds the mean, which tells a reader
  # nothing they can use - the bins above say far more about the spread. It
  # defaults ON, so a report that has not asked for the change is unaffected.
  if (config$show_numeric_sd) {
    sd_row <- data.frame(
      RowLabel = "Standard Deviation",
      RowType = "StdDev",
      stringsAsFactors = FALSE
    )

    for (key in internal_keys) {
      sd_row[[key]] <- format_output_value(
        stat_results[[key]]$sd,
        "numeric",
        decimal_places_numeric = config$decimal_places_numeric
      )
    }

    results_list[[length(results_list) + 1]] <- sd_row
  }

  # Outliers row (if enabled)
  if (config$show_numeric_outliers) {
    outlier_label <- if (config$exclude_outliers_from_stats) {
      "Outliers (excluded)"
    } else {
      "Outliers (IQR)"
    }
    
    outlier_row <- data.frame(
      RowLabel = outlier_label,
      RowType = "Outliers",
      stringsAsFactors = FALSE
    )
    
    for (key in internal_keys) {
      outlier_row[[key]] <- as.character(stat_results[[key]]$outlier_count)
    }
    
    results_list[[length(results_list) + 1]] <- outlier_row
  }
  
  # ===========================================================================
  # PART 3: Significance Testing (for means)
  # ===========================================================================
  
  if (config$enable_significance_testing) {
    test_data <- list()
    total_key <- paste0("TOTAL::", TOTAL_COLUMN)
    
    for (key in internal_keys) {
      if (key != total_key && !is.null(stat_value_sets[[key]])) {
        test_data[[key]] <- list(
          values = stat_value_sets[[key]],
          weights = stat_weight_sets[[key]]
        )
      }
    }
    
    sig_row <- add_significance_row(
      test_data, banner_info, "mean", internal_keys,
      alpha = config$alpha,
      config$bonferroni_correction,
      config$significance_min_base,
      is_weighted = is_weighted,
      alpha_secondary = config$alpha_secondary,
      fpc_muls = build_fpc_multipliers(
        banner_bases, resolve_column_populations(banner_info, config), internal_keys)
    )
    
    if (!is.null(sig_row)) {
      results_list[[length(results_list) + 1]] <- sig_row
    }
  }
  
  # ===========================================================================
  # Combine all results
  # ===========================================================================
  
  if (length(results_list) > 0) {
    # Tag rows without a RowSource as summary (Mean, Median, StdDev, etc.)
    # Bin rows already have RowSource = "individual" set above
    for (i in seq_along(results_list)) {
      if (!"RowSource" %in% names(results_list[[i]]) ||
          is.na(results_list[[i]]$RowSource[1]) ||
          !nzchar(results_list[[i]]$RowSource[1])) {
        results_list[[i]]$RowSource <- "summary"
      }
    }
    return(batch_rbind(results_list))
  }

  return(NULL)
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Calculate Numeric Statistics
#'
#' Calculates mean, median, mode, and standard deviation for numeric questions.
#' Handles weighted and unweighted data.
#' Optionally detects and excludes outliers.
#'
#' @param data Data frame, survey data (subset)
#' @param question_info Data frame row, question metadata
#' @param weights Numeric vector, weights for this subset
#' @param config List, configuration object
#' @param is_weighted Logical, whether weighting is applied
#' @return List with statistics: mean, median, mode, sd, outlier_count
#' @export
calculate_numeric_statistics <- function(data, question_info, weights,
                                        config, is_weighted) {
  
  question_col <- question_info$QuestionCode
  
  # Extract and validate numeric data
  raw_values <- data[[question_col]]
  numeric_values <- suppressWarnings(as.numeric(raw_values))
  
  # Apply Min/Max filters if specified
  min_val <- if ("Min_Value" %in% names(question_info)) {
    suppressWarnings(as.numeric(question_info$Min_Value))
  } else {
    NA_real_
  }
  
  max_val <- if ("Max_Value" %in% names(question_info)) {
    suppressWarnings(as.numeric(question_info$Max_Value))
  } else {
    NA_real_
  }
  
  # Filter valid values
  valid_idx <- !is.na(numeric_values)
  
  if (!is.na(min_val)) {
    valid_idx <- valid_idx & (numeric_values >= min_val)
  }
  
  if (!is.na(max_val)) {
    valid_idx <- valid_idx & (numeric_values <= max_val)
  }
  
  valid_values <- numeric_values[valid_idx]
  valid_weights <- weights[valid_idx]
  
  # Initialize results
  result <- list(
    mean = NA_real_,
    median = NA_real_,
    mode = NA_real_,
    sd = NA_real_,
    outlier_count = 0,
    n_valid = length(valid_values)
  )
  
  if (length(valid_values) == 0) {
    return(result)
  }
  
  # Detect outliers if needed
  outlier_indices <- rep(FALSE, length(valid_values))
  if (config$show_numeric_outliers || config$exclude_outliers_from_stats) {
    outlier_info <- detect_outliers_iqr(valid_values)
    result$outlier_count <- outlier_info$count
    outlier_indices <- outlier_info$indices
  }
  
  # Exclude outliers from calculations if requested
  if (config$exclude_outliers_from_stats) {
    calc_values <- valid_values[!outlier_indices]
    calc_weights <- valid_weights[!outlier_indices]
  } else {
    calc_values <- valid_values
    calc_weights <- valid_weights
  }
  
  if (length(calc_values) == 0) {
    return(result)
  }
  
  # Calculate mean (weighted or unweighted)
  if (all(calc_weights == 1) || !is_weighted) {
    result$mean <- mean(calc_values)
  } else {
    total_weight <- sum(calc_weights)
    if (total_weight > 0) {
      result$mean <- sum(calc_values * calc_weights) / total_weight
    }
  }
  
  # Calculate standard deviation (weighted or unweighted)
  if (length(calc_values) > 1) {
    if (all(calc_weights == 1) || !is_weighted) {
      result$sd <- sd(calc_values)
    } else {
      total_weight <- sum(calc_weights)
      if (total_weight > 0) {
        mean_val <- result$mean
        # V10.8: Use Bessel-corrected (reliability) weighted variance.
        # Population formula divides by sum(w); sample formula divides by sum(w) - 1.
        denom <- total_weight - 1
        if (denom > 0) {
          variance <- sum(calc_weights * (calc_values - mean_val)^2) / denom
        } else {
          variance <- 0
        }
        result$sd <- sqrt(variance)
      }
    }
  }
  
  # Calculate median (unweighted only)
  if (config$show_numeric_median && !is_weighted) {
    result$median <- median(calc_values)
  }
  
  # Calculate mode (unweighted only)
  if (config$show_numeric_mode && !is_weighted) {
    # Find most frequent value
    freq_table <- table(calc_values)
    if (length(freq_table) > 0) {
      max_freq <- max(freq_table)
      modes <- as.numeric(names(freq_table)[freq_table == max_freq])
      
      # If multiple modes or mode appears only once (highly dispersed), report NA
      if (length(modes) == 1 && max_freq > 1) {
        result$mode <- modes[1]
      }
    }
  }
  
  return(result)
}

#' Detect Outliers Using IQR Method
#'
#' Identifies outliers using the IQR (Interquartile Range) method.
#' Outliers are values < Q1 - 1.5*IQR or > Q3 + 1.5*IQR
#'
#' @param values Numeric vector, values to check for outliers
#' @return List with count (number of outliers) and indices (logical vector)
#' @export
detect_outliers_iqr <- function(values) {
  if (length(values) < 4) {
    # Not enough data for quartiles
    return(list(count = 0, indices = rep(FALSE, length(values))))
  }
  
  q1 <- quantile(values, 0.25, na.rm = TRUE)
  q3 <- quantile(values, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  
  lower_bound <- q1 - 1.5 * iqr
  upper_bound <- q3 + 1.5 * iqr
  
  is_outlier <- (values < lower_bound) | (values > upper_bound)
  
  return(list(
    count = sum(is_outlier, na.rm = TRUE),
    indices = is_outlier
  ))
}

#' Categorize Numeric Values into Bins
#'
#' Assigns numeric values to predefined bins from Options sheet.
#' Bins are defined by Min and Max values, with OptionText as label.
#'
#' @param values Numeric vector, values to categorize
#' @param option_info Data frame, bin definitions (Min, Max, OptionText)
#' @return Character vector, bin labels for each value (NA if unbinned)
#' @export
categorize_numeric_bins <- function(values, option_info) {
  # No rows, or no Min/Max columns, means no bins. A Numeric question can carry
  # Options rows that are display labels rather than bin definitions — a
  # frequency cascade's answer texts, say — and the Options sheet then has no
  # Min/Max at all. option_info$Min is NULL in that case, and order(NULL) raises
  # "argument 1 is not a vector", which surfaced as a bare
  # DATA_NUMERIC_QUESTION_FAILED naming the question but not the cause.
  if (nrow(option_info) == 0 ||
      !all(c("Min", "Max") %in% names(option_info))) {
    return(rep(NA_character_, length(values)))
  }

  # Initialize result
  result <- rep(NA_character_, length(values))

  # Sort bins by Min for efficient processing
  option_info <- option_info[order(option_info$Min), ]
  
  # Extract bin boundaries
  bin_mins <- as.numeric(option_info$Min)
  bin_maxs <- as.numeric(option_info$Max)
  bin_labels <- as.character(option_info$OptionText)
  
  # Assign each value to a bin
  for (i in seq_along(values)) {
    if (!is.na(values[i])) {
      # Find matching bin
      for (b in seq_along(bin_labels)) {
        if (!is.na(bin_mins[b]) && !is.na(bin_maxs[b])) {
          if (values[i] >= bin_mins[b] && values[i] <= bin_maxs[b]) {
            result[i] <- bin_labels[b]
            break  # First matching bin wins
          }
        }
      }
    }
  }
  
  return(result)
}

# ==============================================================================
# MODULE INFO
# ==============================================================================

#' Get Numeric Processor Module Information
#'
#' Returns metadata about the numeric_processor module.
#'
#' @return List with module information
#' @export
get_numeric_processor_info <- function() {
  list(
    module = "numeric_processor",
    version = "1.0.0",
    date = "2025-10-25",
    description = "Numeric question processor with bins and statistics (V10.0 feature)",
    functions = c(
      "process_numeric_question",
      "calculate_numeric_statistics",
      "detect_outliers_iqr",
      "categorize_numeric_bins",
      "get_numeric_processor_info"
    ),
    dependencies = c(
      "utilities.R",
      "cell_calculator.R",
      "statistics.R"
    )
  )
}

# ==============================================================================
# MODULE LOAD MESSAGE
# ==============================================================================

message("[OK] Turas>Tabs numeric_processor module loaded")

# ==============================================================================
# END OF MODULE 8: NUMERIC_PROCESSOR.R
# ==============================================================================
