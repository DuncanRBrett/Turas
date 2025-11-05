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
TOTAL_COLUMN <- "Total"

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
  has_bins <- nrow(question_options) > 0
  
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
  
  # Mean row
  mean_row <- data.frame(
    RowLabel = "Mean",
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
  
  # Standard deviation row
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
      test_data, banner_info, "rating", internal_keys,
      alpha = config$alpha,
      config$bonferroni_correction,
      config$significance_min_base,
      is_weighted = is_weighted
    )
    
    if (!is.null(sig_row)) {
      results_list[[length(results_list) + 1]] <- sig_row
    }
  }
  
  # ===========================================================================
  # Combine all results
  # ===========================================================================
  
  if (length(results_list) > 0) {
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
        variance <- sum(calc_weights * (calc_values - mean_val)^2) / total_weight
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
  if (nrow(option_info) == 0) {
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
