# ==============================================================================
# TURAS>TABS - CELL CALCULATOR MODULE
# ==============================================================================
# Purpose: Core cell and row calculation functions
# Dependencies: banner_indices, utilities, shared/statistics/weighting
# Author: Turas Analytics Toolkit
# Version: 1.0.0
# ==============================================================================

# Constants
TOTAL_COLUMN <- "Total"
COLUMN_PCT_ROW_TYPE <- "Column %"
ROW_PCT_ROW_TYPE <- "Row %"
FREQUENCY_ROW_TYPE <- "Frequency"
AVERAGE_ROW_TYPE <- "Average"
INDEX_ROW_TYPE <- "Index"
SCORE_ROW_TYPE <- "Score"

# ==============================================================================
# ROW COUNT CALCULATIONS
# ==============================================================================

#' Calculate Row Counts
#' 
#' MEMORY OPTIMIZATION:
#' Uses master_weights[row_idx] pattern - no weight duplication
#' 
#' Calculates weighted counts for a response option across all banner columns
#' Handles both single-choice and multi-mention questions
#' 
#' @param data Full survey data
#' @param banner_row_indices List of row indices by banner column
#' @param option_text Response option to count
#' @param question_col Question column name (for single choice)
#' @param is_multi_mention Logical, is this a multi-mention question
#' @param existing_cols Character vector of column names (for multi-mention)
#' @param internal_keys Banner column internal keys
#' @param master_weights Master weight vector for all data
#' @return Named numeric vector of weighted counts by banner column
#' @export
calculate_row_counts <- function(data, banner_row_indices, option_text, 
                                 question_col, is_multi_mention, existing_cols, 
                                 internal_keys, master_weights) {
  
  # Initialize counts
  row_counts <- setNames(numeric(length(internal_keys)), internal_keys)
  
  # Calculate for each banner column
  for (key in internal_keys) {
    row_idx <- banner_row_indices[[key]]
    
    if (length(row_idx) > 0) {
      # Get weights for this banner subset
      subset_weights <- master_weights[row_idx]
      
      if (is_multi_mention) {
        # Multi-mention: Check all columns and sum mentions
        mention_count <- 0
        for (question_col_i in existing_cols) {
          matching <- safe_equal(data[[question_col_i]][row_idx], option_text) & 
                     !is.na(data[[question_col_i]][row_idx])
          mention_count <- mention_count + sum(subset_weights[matching], na.rm = TRUE)
        }
        row_counts[key] <- mention_count
      } else {
        # Single choice: Check single column
        matching <- safe_equal(data[[question_col]][row_idx], option_text) & 
                   !is.na(data[[question_col]][row_idx])
        row_counts[key] <- sum(subset_weights[matching], na.rm = TRUE)
      }
    }
  }
  
  return(row_counts)
}

#' Calculate Cell Count
#' 
#' Calculates weighted count for a single cell (option x banner column)
#' 
#' @param data Survey data subset
#' @param option_text Response option
#' @param question_col Question column name
#' @param weights Weight vector for subset
#' @return Numeric weighted count
#' @export
calculate_cell_count <- function(data, option_text, question_col, weights) {
  
  if (nrow(data) == 0 || length(weights) == 0) {
    return(0)
  }
  
  matching <- safe_equal(data[[question_col]], option_text) & 
             !is.na(data[[question_col]])
  
  return(sum(weights[matching], na.rm = TRUE))
}

#' Calculate Multi-Mention Cell Count
#' 
#' Calculates weighted count for multi-mention question
#' Checks all columns and sums mentions
#' 
#' @param data Survey data subset
#' @param option_text Response option
#' @param column_names Vector of column names to check
#' @param weights Weight vector for subset
#' @return Numeric weighted count
#' @export
calculate_multi_mention_count <- function(data, option_text, column_names, weights) {
  
  if (nrow(data) == 0 || length(weights) == 0) {
    return(0)
  }
  
  total_count <- 0
  
  for (col in column_names) {
    if (col %in% names(data)) {
      matching <- safe_equal(data[[col]], option_text) & !is.na(data[[col]])
      total_count <- total_count + sum(weights[matching], na.rm = TRUE)
    }
  }
  
  return(total_count)
}

# ==============================================================================
# PERCENTAGE CALCULATIONS
# ==============================================================================

#' Calculate Weighted Percentage
#' 
#' Safely calculates percentage with zero-division handling
#' 
#' @param weighted_count Weighted count (numerator)
#' @param weighted_base Weighted base (denominator)
#' @return Numeric percentage or NA
#' @export
calculate_weighted_percentage <- function(weighted_count, weighted_base) {
  if (is.na(weighted_base) || weighted_base == 0) {
    return(NA_real_)
  }
  return((weighted_count / weighted_base) * 100)
}

#' Create Column Percentage Row
#' 
#' Creates a row of column percentages (% down each banner column)
#' This is the standard crosstab percentage
#' 
#' @param row_counts Named numeric vector of weighted counts
#' @param banner_bases List of base info by banner column
#' @param internal_keys Banner column internal keys
#' @param display_text Row label text
#' @param show_label Show row label (TRUE) or blank ("")
#' @param decimal_places Decimal places for percentages
#' @return Data frame with one row
#' @export
create_percentage_row <- function(row_counts, banner_bases, internal_keys, 
                                  display_text, show_label = TRUE, 
                                  decimal_places = 0) {
  
  # Initialize row
  row <- data.frame(
    RowLabel = if (show_label) display_text else "",
    RowType = COLUMN_PCT_ROW_TYPE,
    stringsAsFactors = FALSE
  )
  
  # Calculate percentage for each banner column
  for (key in internal_keys) {
    base_info <- banner_bases[[key]]
    
    # Use weighted base if available, otherwise unweighted
    weighted_base <- if (!is.null(base_info$weighted)) {
      base_info$weighted
    } else {
      base_info$unweighted
    }
    
    # Calculate and format percentage
    percentage <- calculate_weighted_percentage(row_counts[key], weighted_base)
    row[[key]] <- format_output_value(
      percentage, 
      "percent", 
      decimal_places_percent = decimal_places
    )
  }
  
  return(row)
}

#' Create Row Percentage Row
#' 
#' Creates a row of row percentages (% across each banner column)
#' Less common than column percentages
#' 
#' @param row_counts Named numeric vector of weighted counts
#' @param banner_info Banner structure
#' @param internal_keys Banner column internal keys
#' @param display_text Row label text
#' @param show_label Show row label (TRUE) or blank ("")
#' @param decimal_places Decimal places for percentages
#' @param zero_division_as_blank Return NA for zero row total
#' @return Data frame with one row
#' @export
create_row_percentage_row <- function(row_counts, banner_info, internal_keys, 
                                      display_text, show_label = TRUE,
                                      decimal_places = 0,
                                      zero_division_as_blank = TRUE) {
  
  # Initialize row
  row <- data.frame(
    RowLabel = if (show_label) display_text else "",
    RowType = ROW_PCT_ROW_TYPE,
    stringsAsFactors = FALSE
  )
  
  # Handle Total column
  total_key <- paste0("TOTAL::", TOTAL_COLUMN)
  if (total_key %in% internal_keys) {
    total_count <- row_counts[total_key]
    
    if (total_count == 0) {
      row[[total_key]] <- if (zero_division_as_blank) {
        NA_real_
      } else {
        format_output_value(0, "percent", decimal_places_percent = decimal_places)
      }
    } else {
      # Total is always 100%
      row[[total_key]] <- format_output_value(
        100,
        "percent",
        decimal_places_percent = decimal_places
      )
    }
  }
  
  # Handle banner questions
  for (banner_code in names(banner_info$banner_info)) {
    banner_keys <- banner_info$banner_info[[banner_code]]$internal_keys
    
    # Calculate total for this banner question
    banner_total <- sum(row_counts[banner_keys], na.rm = TRUE)
    
    # Calculate percentage for each column within this banner
    for (key in banner_keys) {
      if (banner_total == 0) {
        row[[key]] <- if (zero_division_as_blank) {
          NA_real_
        } else {
          format_output_value(0, "percent", decimal_places_percent = decimal_places)
        }
      } else {
        percentage <- calculate_weighted_percentage(row_counts[key], banner_total)
        row[[key]] <- format_output_value(
          percentage,
          "percent",
          decimal_places_percent = decimal_places
        )
      }
    }
  }
  
  return(row)
}

#' Create Frequency Row
#' 
#' Creates a row of weighted frequencies (counts)
#' 
#' @param row_counts Named numeric vector of weighted counts
#' @param internal_keys Banner column internal keys
#' @param display_text Row label text
#' @param show_label Show row label (TRUE) or blank ("")
#' @return Data frame with one row
#' @export
create_frequency_row <- function(row_counts, internal_keys, display_text, 
                                 show_label = TRUE) {
  
  # Initialize row
  row <- data.frame(
    RowLabel = if (show_label) display_text else "",
    RowType = FREQUENCY_ROW_TYPE,
    stringsAsFactors = FALSE
  )
  
  # Add counts for each banner column
  for (key in internal_keys) {
    row[[key]] <- format_output_value(row_counts[key], "frequency")
  }
  
  return(row)
}

# ==============================================================================
# SUMMARY STATISTICS
# ==============================================================================

#' Calculate Summary Statistic
#' 
#' Calculates summary statistics (mean, index, NPS) for rating/Likert/NPS questions
#' 
#' @param data Survey data
#' @param question_info Question information
#' @param options_info Response options
#' @param weights Weight vector
#' @return List with stat_name, stat_label, value, values, weights or NULL
#' @export
calculate_summary_statistic <- function(data, question_info, options_info, weights) {
  
  var_type <- question_info$Variable_Type
  question_col <- question_info$QuestionCode
  
  # RATING QUESTIONS - Calculate mean score
  if (var_type == "Rating") {
    return(calculate_rating_mean(data, question_col, options_info, weights))
  }
  
  # LIKERT QUESTIONS - Calculate index score
  if (var_type == "Likert") {
    return(calculate_likert_index(data, question_col, options_info, weights))
  }
  
  # NPS QUESTIONS - Calculate Net Promoter Score
  if (var_type == "NPS") {
    return(calculate_nps_score(data, question_col, weights))
  }
  
  return(NULL)
}

#' Calculate Rating Mean
#' 
#' Calculates weighted mean for rating scale questions
#' Uses OptionValue if available, otherwise OptionText
#' 
#' @param data Survey data
#' @param question_col Question column name
#' @param options_info Response options
#' @param weights Weight vector
#' @return List with statistic info or NULL
#' @export
calculate_rating_mean <- function(data, question_col, options_info, weights) {
  
  # Get valid options (exclude from index if specified)
  valid_options <- options_info[
    options_info$ExcludeFromIndex != "Y" | is.na(options_info$ExcludeFromIndex), 
  ]
  
  if (!question_col %in% names(data)) {
    return(NULL)
  }
  
  all_responses <- data[[question_col]]
  
  # Find matching responses
  matching_responses <- sapply(all_responses, function(resp) {
    if (is.na(resp) || resp == "") return(FALSE)
    any(safe_equal(as.character(resp), as.character(valid_options$OptionText)))
  })
  
  valid_data <- all_responses[matching_responses]
  valid_weights <- weights[matching_responses]
  
  if (length(valid_data) == 0) {
    return(NULL)
  }
  
  # Convert to numeric values
  numeric_values <- numeric(0)
  numeric_weights <- numeric(0)
  
  for (i in seq_len(nrow(valid_options))) {
    matching <- safe_equal(as.character(valid_data), 
                          as.character(valid_options$OptionText[i]))
    
    if (any(matching, na.rm = TRUE)) {
      # Use OptionValue if available, otherwise OptionText
      option_value <- if ("OptionValue" %in% names(valid_options)) {
        suppressWarnings(as.numeric(valid_options$OptionValue[i]))
      } else {
        suppressWarnings(as.numeric(valid_options$OptionText[i]))
      }
      
      if (!is.na(option_value)) {
        count <- sum(matching, na.rm = TRUE)
        numeric_values <- c(numeric_values, rep(option_value, count))
        numeric_weights <- c(numeric_weights, valid_weights[matching])
      }
    }
  }
  
  if (length(numeric_values) > 0 && sum(numeric_weights) > 0) {
    mean_value <- weighted.mean(numeric_values, numeric_weights, na.rm = TRUE)
    
    return(list(
      stat_name = "Mean",
      stat_label = AVERAGE_ROW_TYPE,
      value = mean_value,
      values = numeric_values,
      weights = numeric_weights
    ))
  }
  
  return(NULL)
}

#' Calculate Likert Index
#' 
#' Calculates weighted index for Likert scale questions
#' Uses Index_Weight field from options
#' 
#' @param data Survey data
#' @param question_col Question column name
#' @param options_info Response options with Index_Weight
#' @param weights Weight vector
#' @return List with statistic info or NULL
#' @export
calculate_likert_index <- function(data, question_col, options_info, weights) {
  
  # Get options with index weights
  index_options <- options_info[!is.na(options_info$Index_Weight), ]
  
  if (nrow(index_options) == 0 || !question_col %in% names(data)) {
    return(NULL)
  }
  
  weighted_sum <- 0
  total_weight <- 0
  all_weighted_values <- numeric(0)
  all_weights <- numeric(0)
  
  for (i in seq_len(nrow(index_options))) {
    matching <- safe_equal(data[[question_col]], index_options$OptionText[i])
    option_weight <- sum(weights[matching], na.rm = TRUE)
    
    weighted_sum <- weighted_sum + (option_weight * index_options$Index_Weight[i])
    total_weight <- total_weight + option_weight
    
    all_weighted_values <- c(
      all_weighted_values, 
      rep(index_options$Index_Weight[i], sum(matching, na.rm = TRUE))
    )
    all_weights <- c(all_weights, weights[matching])
  }
  
  if (total_weight > 0) {
    index_value <- weighted_sum / total_weight
    
    return(list(
      stat_name = "Index",
      stat_label = INDEX_ROW_TYPE,
      value = index_value,
      values = all_weighted_values,
      weights = all_weights
    ))
  }
  
  return(NULL)
}

#' Calculate NPS Score
#' 
#' Calculates Net Promoter Score (0-10 scale)
#' Promoters (9-10) - Detractors (0-6) / Total
#' 
#' NOTE: 0 is a VALID score (detractor) and must be included in base
#' 
#' @param data Survey data
#' @param question_col Question column name
#' @param weights Weight vector
#' @return List with statistic info or NULL
#' @export
calculate_nps_score <- function(data, question_col, weights) {
  
  if (!question_col %in% names(data)) {
    return(NULL)
  }
  
  all_responses <- data[[question_col]]
  
  # Filter out ONLY non-numeric responses (DK, NA, blank)
  # IMPORTANT: Keep 0 as it's a valid NPS score (detractor)
  valid_responses <- all_responses[
    !is.na(all_responses) & 
    all_responses != "" &
    !all_responses %in% c("DK", "Don't know", "Not applicable", "NA")
  ]
  
  valid_weights <- weights[
    !is.na(all_responses) & 
    all_responses != "" &
    !all_responses %in% c("DK", "Don't know", "Not applicable", "NA")
  ]
  
  if (length(valid_responses) == 0) {
    return(NULL)
  }
  
  # Convert to numeric
  numeric_responses <- suppressWarnings(as.numeric(valid_responses))
  valid_idx <- !is.na(numeric_responses)
  numeric_responses <- numeric_responses[valid_idx]
  valid_weights <- valid_weights[valid_idx]
  
  if (length(numeric_responses) == 0 || sum(valid_weights) == 0) {
    return(NULL)
  }
  
  # Calculate NPS
  promoters <- sum(valid_weights[numeric_responses >= 9])
  detractors <- sum(valid_weights[numeric_responses <= 6])
  total_valid <- sum(valid_weights)
  
  if (total_valid > 0) {
    nps_score <- ((promoters - detractors) / total_valid) * 100
    
    return(list(
      stat_name = "NPS Score",
      stat_label = SCORE_ROW_TYPE,
      value = nps_score,
      values = numeric_responses,
      weights = valid_weights
    ))
  }
  
  return(NULL)
}

# ==============================================================================
# BASE SIZE CALCULATIONS
# ==============================================================================

#' Calculate Base Sizes for Banner Columns
#' 
#' Calculates unweighted, weighted, and effective base sizes
#' 
#' @param banner_row_indices List of row indices by banner column
#' @param master_weights Master weight vector
#' @param is_weighted Logical, is weighting applied
#' @return List with base info for each banner column
#' @export
calculate_banner_base_sizes <- function(banner_row_indices, master_weights, 
                                        is_weighted = FALSE) {
  
  bases <- list()
  
  for (key in names(banner_row_indices$row_indices)) {
    row_idx <- banner_row_indices$row_indices[[key]]
    
    # Unweighted base
    unweighted_n <- length(row_idx)
    
    if (is_weighted && length(row_idx) > 0) {
      # Get weights for this column
      col_weights <- master_weights[row_idx]
      
      # Weighted base
      weighted_n <- sum(col_weights)
      
      # Effective base (requires calculate_effective_n from weighting module)
      effective_n <- calculate_effective_base(col_weights)
    } else {
      weighted_n <- unweighted_n
      effective_n <- unweighted_n
    }
    
    bases[[key]] <- list(
      unweighted = unweighted_n,
      weighted = weighted_n,
      effective = effective_n
    )
  }
  
  return(bases)
}

#' Calculate Effective Base Size
#' 
#' Calculates effective base size using Kish's formula
#' Effective n = (sum of weights)^2 / sum of squared weights
#' 
#' @param weights Weight vector
#' @return Numeric effective base size
#' @export
calculate_effective_base <- function(weights) {
  
  if (length(weights) == 0) {
    return(0)
  }
  
  # Remove zero weights
  weights <- weights[weights > 0]
  
  if (length(weights) == 0) {
    return(0)
  }
  
  sum_weights <- sum(weights)
  sum_weights_sq <- sum(weights^2)
  
  if (sum_weights_sq == 0) {
    return(0)
  }
  
  effective_n <- (sum_weights^2) / sum_weights_sq
  
  return(effective_n)
}

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

#' Create Empty Row
#' 
#' Creates an empty row with proper structure
#' 
#' @param internal_keys Banner column internal keys
#' @param row_label Row label text
#' @param row_type Row type
#' @return Data frame with one empty row
#' @export
create_empty_row <- function(internal_keys, row_label = "", row_type = "") {
  
  row <- data.frame(
    RowLabel = row_label,
    RowType = row_type,
    stringsAsFactors = FALSE
  )
  
  # Add NA for each banner column
  for (key in internal_keys) {
    row[[key]] <- NA_real_
  }
  
  return(row)
}

#' Validate Row Counts
#' 
#' Validates that row counts are properly formed
#' 
#' @param row_counts Named numeric vector
#' @param internal_keys Expected keys
#' @return TRUE if valid, stops with error if not
#' @export
validate_row_counts <- function(row_counts, internal_keys) {
  
  if (!is.numeric(row_counts)) {
    stop("row_counts must be numeric")
  }
  
  if (length(row_counts) != length(internal_keys)) {
    stop(sprintf(
      "row_counts length (%d) doesn't match internal_keys (%d)",
      length(row_counts),
      length(internal_keys)
    ))
  }
  
  missing_keys <- setdiff(internal_keys, names(row_counts))
  if (length(missing_keys) > 0) {
    stop(sprintf(
      "row_counts missing keys: %s",
      paste(head(missing_keys, 5), collapse = ", ")
    ))
  }
  
  return(TRUE)
}

# ==============================================================================
# MODULE METADATA
# ==============================================================================

#' Get Module Version
#' @export
get_cell_calculator_version <- function() {
  return("1.0.0")
}

#' Get Module Info
#' @export
get_cell_calculator_info <- function() {
  cat("")

  cat("================================================")

  cat("TURAS>TABS Cell Calculator Module")

  cat("================================================")

  cat("Version:", get_cell_calculator_version(), "")

  cat("Purpose: Core cell and row calculations")

  cat("")

  cat("Main Functions:")

  cat("  - calculate_row_counts()")

  cat("  - calculate_weighted_percentage()")

  cat("  - create_percentage_row()")

  cat("  - create_row_percentage_row()")

  cat("  - create_frequency_row()")

  cat("  - calculate_summary_statistic()")

  cat("  - calculate_rating_mean()")

  cat("  - calculate_likert_index()")

  cat("  - calculate_nps_score()")

  cat("  - calculate_banner_base_sizes()")

  cat("================================================\n")

}

# Module loaded message
cat("[OK] Turas>Tabs cell_calculator module loaded")

