# ==============================================================================
# MODULE 7: STANDARD_PROCESSOR.R
# ==============================================================================
#
# PURPOSE:
#   Process standard questions (single/multi choice, rating, likert, NPS, grids)
#   Handles the majority of question types in crosstabulation
#
# FUNCTIONS:
#   - process_standard_question() - Main processor
#   - add_boxcategory_summaries() - Grid/box summaries
#   - add_summary_statistic() - Mean/index calculations
#   - add_net_significance_rows() - Net difference testing
#   - add_net_positive_row() - Top-bottom net calculations
#
# DEPENDENCIES:
#   - utilities.R (safe_execute, logging, formatting)
#   - cell_calculator.R (row counts, percentages)
#   - statistics.R (significance testing)
#
# VERSION: 1.0.0
# DATE: 2025-10-25
# ==============================================================================

# Row type constants
FREQUENCY_ROW_TYPE <- "Frequency"
COLUMN_PCT_ROW_TYPE <- "Column %"
ROW_PCT_ROW_TYPE <- "Row %"
AVERAGE_ROW_TYPE <- "Average"
INDEX_ROW_TYPE <- "Index"
SCORE_ROW_TYPE <- "Score"
SIGNIFICANCE_ROW_TYPE <- "Sig."
TOTAL_COLUMN <- "Total"

# ==============================================================================
# MAIN STANDARD QUESTION PROCESSOR
# ==============================================================================

#' Process Standard Question
#'
#' Main processor for single/multi choice questions, ratings, likert, NPS, etc.
#' Creates frequency, percentage, and significance rows for each option.
#'
#' FIXED: Multi-mention uses column names (Q01_1, Q01_2)
#' FIXED: ShowInOutput filtering works properly
#'
#' @param data Data frame, full dataset (filtered)
#' @param question_info Data frame row, question metadata
#' @param question_options Data frame, response options
#' @param banner_info List, banner structure
#' @param banner_row_indices List, row indices by banner column
#' @param master_weights Numeric vector, master weights
#' @param banner_bases List, base sizes by column
#' @param config List, configuration object
#' @param is_weighted Logical, whether weighting is applied
#' @return Data frame with results or NULL
#' @export
process_standard_question <- function(data, question_info, question_options,
                                     banner_info, banner_row_indices,
                                     master_weights, banner_bases, config,
                                     is_weighted = FALSE) {
  
  question_col <- question_info$QuestionCode
  is_multi_mention <- question_info$Variable_Type == "Multi_Mention"
  internal_keys <- banner_info$internal_keys
  
  # Filter options by ShowInOutput
  display_options <- question_options[
    question_options$ShowInOutput == "Y" | is.na(question_options$ShowInOutput),
  ]
  
  # Sort by DisplayOrder if available
  if ("DisplayOrder" %in% names(display_options) &&
      !all(is.na(display_options$DisplayOrder))) {
    display_options <- display_options[
      order(display_options$DisplayOrder, na.last = TRUE),
    ]
  }
  
  # Validate question columns exist
  existing_cols <- NULL
  if (is_multi_mention) {
    num_columns <- suppressWarnings(as.numeric(question_info$Columns))
    if (is.na(num_columns) || num_columns < 1) {
      warning(sprintf("Invalid column count for %s", question_col))
      return(NULL)
    }
    
    question_cols <- paste0(question_col, "_", seq_len(num_columns))
    existing_cols <- question_cols[question_cols %in% names(data)]
    
    if (!length(existing_cols)) {
      warning(sprintf("No multi-mention columns for %s", question_col))
      return(NULL)
    }
  } else {
    if (!question_col %in% names(data)) {
      warning(sprintf("Question column not found: %s", question_col))
      return(NULL)
    }
  }
  
  # Process each option
  results_list <- list()
  
  for (option_idx in seq_len(nrow(display_options))) {
    current_option <- display_options[option_idx, ]
    option_text <- current_option$OptionText
    display_text <- if (!is.na(current_option$DisplayText)) {
      current_option$DisplayText
    } else {
      option_text
    }
    
    # Calculate row counts
    row_counts <- calculate_row_counts(
      data, banner_row_indices, option_text, question_col,
      is_multi_mention, existing_cols, internal_keys, master_weights
    )
    
    # Frequency row
    if (config$show_frequency) {
      freq_row <- data.frame(
        RowLabel = display_text,
        RowType = FREQUENCY_ROW_TYPE,
        stringsAsFactors = FALSE
      )
      for (key in internal_keys) {
        freq_row[[key]] <- format_output_value(row_counts[key], "frequency")
      }
      results_list[[length(results_list) + 1]] <- freq_row
    }
    
    # Column percentage row
    if (config$show_percent_column) {
      col_pct_row <- create_percentage_row(
        row_counts, banner_bases, internal_keys,
        display_text, !config$show_frequency,
        config$decimal_places_percent
      )
      results_list[[length(results_list) + 1]] <- col_pct_row
    }
    
    # Row percentage row
    if (config$show_percent_row) {
      row_pct_row <- create_row_percentage_row(
        row_counts, banner_info, internal_keys,
        display_text, !config$show_frequency && !config$show_percent_column,
        config$decimal_places_percent,
        zero_division_as_blank = config$zero_division_as_blank
      )
      results_list[[length(results_list) + 1]] <- row_pct_row
    }
    
    # Significance testing for proportions
    if (config$show_percent_column && config$enable_significance_testing) {
      test_data <- list()
      total_key <- paste0("TOTAL::", TOTAL_COLUMN)
      
      for (key in internal_keys) {
        if (key != total_key) {
          base_info <- banner_bases[[key]]
          test_data[[key]] <- list(
            count = row_counts[key],
            base = if (!is.null(base_info$weighted)) {
              base_info$weighted
            } else {
              base_info$unweighted
            },
            eff_n = if (!is.null(base_info$effective)) {
              base_info$effective
            } else {
              base_info$unweighted
            }
          )
        }
      }
      
      sig_row <- add_significance_row(
        test_data, banner_info, "proportion", internal_keys,
        alpha = config$alpha,
        config$bonferroni_correction,
        config$significance_min_base,
        is_weighted = is_weighted
      )
      
      if (!is.null(sig_row)) {
        results_list[[length(results_list) + 1]] <- sig_row
      }
    }
  }
  
  # Combine all rows
  if (length(results_list) > 0) {
    return(batch_rbind(results_list))
  }
  
  return(NULL)
}

# ==============================================================================
# BOXCATEGORY SUMMARIES (GRIDS)
# ==============================================================================

# ==============================================================================
# BOXCATEGORY HELPERS (INTERNAL)
# ==============================================================================

#' Create frequency row for a BoxCategory
#' @keywords internal
create_boxcategory_frequency_row <- function(category, row_counts, internal_keys) {
  freq_row <- data.frame(
    RowLabel = category,
    RowType = FREQUENCY_ROW_TYPE,
    stringsAsFactors = FALSE
  )
  for (key in internal_keys) {
    freq_row[[key]] <- format_output_value(row_counts[key], "frequency")
  }
  return(freq_row)
}

#' Create column percentage and significance rows for a BoxCategory
#' @keywords internal
create_boxcategory_column_percent <- function(category, row_counts, banner_bases,
                                              internal_keys, banner_info, config,
                                              is_weighted, show_label) {
  results <- list()

  # Column percentage row
  col_pct_row <- create_percentage_row(
    row_counts, banner_bases, internal_keys,
    category, show_label,
    config$decimal_places_percent
  )
  results[[1]] <- col_pct_row

  # Significance testing
  if (config$enable_significance_testing) {
    test_data <- list()
    total_key <- paste0("TOTAL::", TOTAL_COLUMN)

    for (key in internal_keys) {
      if (key != total_key) {
        base_info <- banner_bases[[key]]
        test_data[[key]] <- list(
          count = row_counts[key],
          base = if (!is.null(base_info$weighted)) {
            base_info$weighted
          } else {
            base_info$unweighted
          },
          eff_n = if (!is.null(base_info$effective)) {
            base_info$effective
          } else {
            base_info$unweighted
          }
        )
      }
    }

    sig_row <- add_significance_row(
      test_data, banner_info, "topbox", internal_keys,
      alpha = config$alpha,
      config$bonferroni_correction,
      config$significance_min_base,
      is_weighted = is_weighted
    )

    if (!is.null(sig_row)) {
      results[[2]] <- sig_row
    }
  }

  return(results)
}

#' Create row percentage row for a BoxCategory
#' @keywords internal
create_boxcategory_row_percent <- function(category, row_counts, banner_info,
                                           internal_keys, config, show_label) {
  row_pct_row <- create_row_percentage_row(
    row_counts, banner_info, internal_keys,
    category, show_label,
    config$decimal_places_percent,
    zero_division_as_blank = config$zero_division_as_blank
  )
  return(row_pct_row)
}

#' Add BoxCategory Summaries
#'
#' Creates summary rows for grid questions with BoxCategory groupings.
#' Aggregates options within each category (e.g., Top 2 Box, Bottom 2 Box).
#'
#' @param data Data frame, survey data
#' @param question_info Data frame row, question metadata
#' @param question_options Data frame, response options
#' @param banner_info List, banner structure
#' @param banner_row_indices List, row indices by column
#' @param master_weights Numeric vector, master weights
#' @param banner_bases List, base sizes
#' @param config List, configuration
#' @param is_weighted Logical, weighting flag
#' @return Data frame with category summaries or NULL
#' @export
add_boxcategory_summaries <- function(data, question_info, question_options,
                                     banner_info, banner_row_indices,
                                     master_weights, banner_bases, config,
                                     is_weighted = FALSE) {

  # Get unique box categories
  box_categories <- unique(question_options$BoxCategory)
  box_categories <- box_categories[!is.na(box_categories) & box_categories != ""]

  if (length(box_categories) == 0) return(NULL)

  internal_keys <- banner_info$internal_keys
  results_list <- list()

  # Process each category
  for (category in box_categories) {
    # Calculate counts for this category
    row_counts <- calculate_boxcategory_counts(
      data, question_info, question_options, banner_row_indices,
      master_weights, internal_keys, category
    )

    # Frequency row (delegated to helper)
    if (config$boxcategory_frequency) {
      freq_row <- create_boxcategory_frequency_row(category, row_counts, internal_keys)
      results_list[[length(results_list) + 1]] <- freq_row
    }

    # Column percentage row + significance (delegated to helper)
    if (config$boxcategory_percent_column) {
      show_label <- !config$boxcategory_frequency
      col_pct_results <- create_boxcategory_column_percent(
        category, row_counts, banner_bases, internal_keys,
        banner_info, config, is_weighted, show_label
      )
      for (row in col_pct_results) {
        results_list[[length(results_list) + 1]] <- row
      }
    }

    # Row percentage row (delegated to helper)
    if (config$boxcategory_percent_row) {
      show_label <- !config$boxcategory_frequency && !config$boxcategory_percent_column
      row_pct_row <- create_boxcategory_row_percent(
        category, row_counts, banner_info, internal_keys, config, show_label
      )
      results_list[[length(results_list) + 1]] <- row_pct_row
    }
  }

  # Combine all rows
  if (length(results_list) > 0) {
    return(batch_rbind(results_list))
  }

  return(NULL)
}

# ==============================================================================
# SUMMARY STATISTICS (MEAN/INDEX/NPS)
# ==============================================================================

# ==============================================================================
# SUMMARY STATISTIC HELPERS (INTERNAL)
# ==============================================================================

#' Calculate statistics for all banner columns
#' @keywords internal
calculate_banner_statistics <- function(data, question_info, question_options,
                                        banner_info, banner_row_indices, master_weights) {
  internal_keys <- banner_info$internal_keys
  stat_values <- setNames(numeric(length(internal_keys)), internal_keys)
  stat_value_sets <- list()
  stat_weight_sets <- list()

  for (key in internal_keys) {
    row_idx <- banner_row_indices[[key]]

    if (length(row_idx) > 0) {
      subset_data <- data[row_idx, , drop = FALSE]
      subset_weights <- master_weights[row_idx]

      stat_result <- calculate_summary_statistic(
        subset_data, question_info, question_options, subset_weights
      )

      if (!is.null(stat_result)) {
        stat_values[key] <- stat_result$value
        stat_value_sets[[key]] <- stat_result$values
        stat_weight_sets[[key]] <- stat_result$weights
      } else {
        stat_values[key] <- NA_real_
      }
    } else {
      stat_values[key] <- NA_real_
    }
  }

  return(list(
    stat_values = stat_values,
    stat_value_sets = stat_value_sets,
    stat_weight_sets = stat_weight_sets
  ))
}

#' Create summary statistic row with formatted values
#' @keywords internal
create_summary_row <- function(stat_result, stat_values, internal_keys, config) {
  # Create summary row
  summary_row <- data.frame(
    RowLabel = stat_result$stat_name,
    RowType = stat_result$stat_label,
    stringsAsFactors = FALSE
  )

  # Determine value type for formatting
  value_type <- if (stat_result$stat_label == AVERAGE_ROW_TYPE) {
    "rating"
  } else if (stat_result$stat_label == INDEX_ROW_TYPE) {
    "index"
  } else if (stat_result$stat_label == SCORE_ROW_TYPE) {
    "percent"
  } else {
    "index"
  }

  # Add formatted values for each column
  for (key in internal_keys) {
    summary_row[[key]] <- format_output_value(
      stat_values[key], value_type,
      decimal_places_percent = config$decimal_places_percent,
      decimal_places_ratings = config$decimal_places_ratings,
      decimal_places_index = config$decimal_places_index
    )
  }

  return(summary_row)
}

#' Create standard deviation row
#' @keywords internal
create_standard_deviation_row <- function(stat_value_sets, stat_weight_sets,
                                          banner_row_indices, internal_keys, config) {
  sd_values <- setNames(numeric(length(internal_keys)), internal_keys)

  for (key in internal_keys) {
    row_idx <- banner_row_indices[[key]]

    if (length(row_idx) > 0 && !is.null(stat_value_sets[[key]])) {
      values <- stat_value_sets[[key]]
      weights <- stat_weight_sets[[key]]

      valid_idx <- !is.na(values) & !is.na(weights) & weights > 0

      if (sum(valid_idx) > 1) {
        v <- values[valid_idx]
        w <- weights[valid_idx]

        if (all(w == 1)) {
          sd_values[key] <- sd(v)
        } else {
          mean_val <- sum(v * w) / sum(w)
          var_val <- sum(w * (v - mean_val)^2) / sum(w)
          sd_values[key] <- sqrt(var_val)
        }
      }
    }
  }

  # Create SD row
  sd_row <- data.frame(
    RowLabel = "Standard Deviation",
    RowType = "StdDev",
    stringsAsFactors = FALSE
  )

  for (key in internal_keys) {
    sd_row[[key]] <- format_output_value(
      sd_values[key],
      "rating",
      decimal_places_ratings = config$decimal_places_ratings
    )
  }

  return(sd_row)
}

#' Add significance testing row for summary statistics
#' @keywords internal
add_summary_significance_row <- function(stat_value_sets, stat_weight_sets,
                                        internal_keys, banner_info, config, is_weighted) {
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
    test_data, banner_info, "index", internal_keys,
    alpha = config$alpha,
    config$bonferroni_correction,
    config$significance_min_base,
    is_weighted = is_weighted
  )

  return(sig_row)
}

#' Add Summary Statistic
#'
#' Adds mean/index/NPS score rows for Rating, Likert, and NPS questions.
#' Optionally adds standard deviation row.
#'
#' @param data Data frame, survey data
#' @param question_info Data frame row, question metadata
#' @param question_options Data frame, options with scores
#' @param banner_info List, banner structure
#' @param banner_row_indices List, row indices
#' @param master_weights Numeric vector, weights
#' @param banner_bases List, base sizes
#' @param selection_row Data frame row, from Selection sheet (has CreateIndex flag)
#' @param config List, configuration
#' @param is_weighted Logical, weighting flag
#' @return Data frame with summary rows or NULL
#' @export
add_summary_statistic <- function(data, question_info, question_options,
                                 banner_info, banner_row_indices,
                                 master_weights, banner_bases,
                                 selection_row, config, is_weighted = FALSE) {
  
  # Check if CreateIndex is enabled
  create_index <- if (!is.null(selection_row) && "CreateIndex" %in% names(selection_row)) {
    if (is.na(selection_row$CreateIndex)) "N" else selection_row$CreateIndex
  } else {
    "N"
  }

  if (create_index != "Y") return(NULL)
  if (!question_info$Variable_Type %in% c("Rating", "Likert", "NPS")) return(NULL)

  internal_keys <- banner_info$internal_keys

  # Calculate statistics for all banner columns (delegated to helper)
  banner_stats <- calculate_banner_statistics(
    data, question_info, question_options,
    banner_info, banner_row_indices, master_weights
  )

  # Get overall statistic for row label
  stat_result <- calculate_summary_statistic(
    data, question_info, question_options, master_weights
  )
  if (is.null(stat_result)) return(NULL)

  # Create summary row (delegated to helper)
  summary_row <- create_summary_row(stat_result, banner_stats$stat_values, internal_keys, config)

  results_list <- list(summary_row)

  # Add standard deviation row (V9.9.5) - delegated to helper
  if (config$show_standard_deviation &&
      question_info$Variable_Type %in% c("Rating", "Likert", "NPS")) {
    sd_row <- create_standard_deviation_row(
      banner_stats$stat_value_sets, banner_stats$stat_weight_sets,
      banner_row_indices, internal_keys, config
    )
    results_list[[length(results_list) + 1]] <- sd_row
  }

  # Significance testing for means/indices - delegated to helper
  test_enabled <- question_info$Variable_Type %in% c("Rating", "Likert", "NPS") &&
    config$enable_significance_testing

  if (test_enabled) {
    sig_row <- add_summary_significance_row(
      banner_stats$stat_value_sets, banner_stats$stat_weight_sets,
      internal_keys, banner_info, config, is_weighted
    )

    if (!is.null(sig_row)) {
      results_list[[length(results_list) + 1]] <- sig_row
    }
  }

  # Combine all rows
  if (length(results_list) > 0) {
    return(batch_rbind(results_list))
  }

  return(NULL)
}

# ==============================================================================
# NET SIGNIFICANCE TESTING (V9.9.5)
# ==============================================================================

# ==============================================================================
# NET SIGNIFICANCE HELPERS (INTERNAL)
# ==============================================================================

#' Validate net difference testing requirements
#' @keywords internal
validate_net_difference_requirements <- function(existing_table, config, question_options) {
  # Safety checks
  if (is.null(existing_table) || nrow(existing_table) == 0) {
    return(NULL)
  }

  if (!config$test_net_differences || !config$enable_significance_testing) {
    return(NULL)
  }

  # Get BoxCategories
  box_categories <- unique(question_options$BoxCategory)
  box_categories <- box_categories[!is.na(box_categories) & box_categories != ""]

  # Only for exactly 2 nets
  if (length(box_categories) != 2) {
    return(NULL)
  }

  return(box_categories)
}

#' Build test data structure for net difference tests
#' @keywords internal
build_net_test_data <- function(row_counts_net1, row_counts_net2,
                                banner_bases, internal_keys) {
  net_test_data <- list()
  total_key <- paste0("TOTAL::", TOTAL_COLUMN)

  for (key in internal_keys) {
    if (key != total_key) {
      base_info <- banner_bases[[key]]

      net_test_data[[key]] <- list(
        count1 = row_counts_net1[key],
        count2 = row_counts_net2[key],
        base = if (!is.null(base_info$weighted)) {
          base_info$weighted
        } else {
          base_info$unweighted
        },
        eff_n = if (!is.null(base_info$effective)) {
          base_info$effective
        } else {
          base_info$unweighted
        }
      )
    }
  }

  return(net_test_data)
}

#' Insert significance row after a BoxCategory percentage row
#' @keywords internal
insert_net_sig_row <- function(existing_table, net_name, net_results, internal_keys) {
  # Find net percentage row position
  net_pct_row <- which(
    existing_table$RowLabel == net_name &
      existing_table$RowType == "Column %"
  )

  if (length(net_pct_row) == 0) {
    return(existing_table)
  }

  # Create significance row
  net_sig_row <- data.frame(
    RowLabel = "",
    RowType = "Sig.",
    stringsAsFactors = FALSE
  )

  for (key in internal_keys) {
    net_sig_row[[key]] <- net_results[[key]]
  }

  # Insert after net percentage row
  if (net_pct_row[1] < nrow(existing_table)) {
    existing_table <- rbind(
      existing_table[1:net_pct_row[1], ],
      net_sig_row,
      existing_table[(net_pct_row[1] + 1):nrow(existing_table), ]
    )
  } else {
    existing_table <- rbind(existing_table, net_sig_row)
  }

  return(existing_table)
}

#' Add Net Difference Significance Rows
#'
#' Adds significance testing for differences between two BoxCategory nets.
#' Only applies when exactly 2 BoxCategories exist.
#'
#' V9.9.5: NEW FEATURE - Net difference testing
#'
#' @param existing_table Data frame, existing BoxCategory results
#' @param data Data frame, survey data
#' @param question_info Data frame row, question metadata
#' @param question_options Data frame, options
#' @param banner_info List, banner structure
#' @param banner_row_indices List, row indices
#' @param master_weights Numeric vector, weights
#' @param banner_bases List, base sizes
#' @param config List, configuration
#' @param is_weighted Logical, weighting flag
#' @return Data frame with net sig rows inserted, or original if not applicable
#' @export
add_net_significance_rows <- function(existing_table, data, question_info,
                                     question_options, banner_info,
                                     banner_row_indices, master_weights,
                                     banner_bases, config, is_weighted = FALSE) {

  # Validate requirements (delegated to helper)
  box_categories <- validate_net_difference_requirements(
    existing_table, config, question_options
  )
  if (is.null(box_categories)) {
    return(existing_table)
  }

  internal_keys <- banner_info$internal_keys

  # Calculate row counts for each net
  row_counts_net1 <- calculate_boxcategory_counts(
    data, question_info, question_options, banner_row_indices,
    master_weights, internal_keys, box_categories[1]
  )

  row_counts_net2 <- calculate_boxcategory_counts(
    data, question_info, question_options, banner_row_indices,
    master_weights, internal_keys, box_categories[2]
  )

  # Build test data (delegated to helper)
  net_test_data <- build_net_test_data(
    row_counts_net1, row_counts_net2,
    banner_bases, internal_keys
  )

  # Run net difference tests
  net_sig_results <- run_net_difference_tests(
    net_test_data, banner_info, internal_keys,
    alpha = config$alpha,
    config$bonferroni_correction,
    config$significance_min_base,
    is_weighted = is_weighted
  )

  if (is.null(net_sig_results)) {
    return(existing_table)
  }

  # Insert sig rows into existing table (delegated to helper)
  existing_table <- insert_net_sig_row(
    existing_table, box_categories[1], net_sig_results$net1, internal_keys
  )

  existing_table <- insert_net_sig_row(
    existing_table, box_categories[2], net_sig_results$net2, internal_keys
  )

  return(existing_table)
}

# ==============================================================================
# NET POSITIVE (TOP - BOTTOM) (V9.9.5)
# ==============================================================================

# ==============================================================================
# NET POSITIVE HELPERS (INTERNAL)
# ==============================================================================

#' Get sorted BoxCategories by DisplayOrder
#' @keywords internal
get_sorted_boxcategories <- function(question_options) {
  box_categories <- unique(question_options$BoxCategory)
  box_categories <- box_categories[!is.na(box_categories) & box_categories != ""]

  if (length(box_categories) < 2) {
    return(NULL)
  }

  # Get DisplayOrder for each category
  cat_order <- sapply(box_categories, function(cat) {
    opts <- question_options[question_options$BoxCategory == cat, ]
    if (nrow(opts) > 0 && "DisplayOrder" %in% names(opts)) {
      min(opts$DisplayOrder, na.rm = TRUE)
    } else {
      NA
    }
  })

  # Skip if no DisplayOrder
  if (any(is.na(cat_order))) {
    return(NULL)
  }

  # Sort categories by DisplayOrder
  ordered_cats <- box_categories[order(cat_order)]
  return(ordered_cats)
}

#' Identify Top and Bottom BoxCategories
#' @keywords internal
identify_top_bottom_categories <- function(ordered_cats) {
  if (is.null(ordered_cats) || length(ordered_cats) < 2) {
    return(NULL)
  }

  # Top is first
  top_category <- ordered_cats[1]

  # Exclude DK/NA from bottom
  non_dk_cats <- ordered_cats[!grepl("DK|NA|Don't Know|Not Applicable",
                                     ordered_cats, ignore.case = TRUE)]

  if (length(non_dk_cats) < 2) {
    bottom_category <- ordered_cats[length(ordered_cats)]
  } else {
    bottom_category <- non_dk_cats[length(non_dk_cats)]
  }

  # Skip if Top and Bottom are the same
  if (top_category == bottom_category) {
    return(NULL)
  }

  return(list(top = top_category, bottom = bottom_category))
}

#' Create NET POSITIVE row with formatted values
#' @keywords internal
create_net_positive_row <- function(top_category, bottom_category, row_counts_top,
                                   row_counts_bottom, banner_bases, internal_keys, config) {
  net_positive_row <- data.frame(
    RowLabel = sprintf("NET POSITIVE (%s - %s)", bottom_category, top_category),
    RowType = "Column %",
    stringsAsFactors = FALSE
  )

  net_pct_values <- setNames(numeric(length(internal_keys)), internal_keys)

  for (key in internal_keys) {
    base_info <- banner_bases[[key]]
    weighted_base <- if (!is.null(base_info$weighted)) {
      base_info$weighted
    } else {
      base_info$unweighted
    }

    if (weighted_base > 0) {
      top_pct <- (row_counts_top[key] / weighted_base) * 100
      bottom_pct <- (row_counts_bottom[key] / weighted_base) * 100
      net_pct <- bottom_pct - top_pct
      net_pct_values[key] <- net_pct
    } else {
      net_pct_values[key] <- NA_real_
    }

    net_positive_row[[key]] <- format_output_value(
      net_pct_values[key],
      "percent",
      decimal_places_percent = config$decimal_places_percent
    )
  }

  return(net_positive_row)
}

#' Add NET POSITIVE significance testing
#' @keywords internal
add_net_positive_significance <- function(row_counts_top, row_counts_bottom,
                                         banner_bases, internal_keys, banner_info,
                                         config, is_weighted) {
  test_data <- list()
  total_key <- paste0("TOTAL::", TOTAL_COLUMN)

  for (key in internal_keys) {
    if (key != total_key) {
      base_info <- banner_bases[[key]]
      test_data[[key]] <- list(
        count1 = row_counts_top[key],
        count2 = row_counts_bottom[key],
        base = if (!is.null(base_info$weighted)) {
          base_info$weighted
        } else {
          base_info$unweighted
        },
        eff_n = if (!is.null(base_info$effective)) {
          base_info$effective
        } else {
          base_info$unweighted
        }
      )
    }
  }

  # Run net difference tests
  net_sig_results <- run_net_difference_tests(
    test_data, banner_info, internal_keys,
    alpha = config$alpha,
    config$bonferroni_correction,
    config$significance_min_base,
    is_weighted = is_weighted
  )

  if (!is.null(net_sig_results)) {
    sig_row <- data.frame(
      RowLabel = "",
      RowType = "Sig.",
      stringsAsFactors = FALSE
    )
    for (key in internal_keys) {
      sig_row[[key]] <- net_sig_results$net1[[key]]
    }
    return(sig_row)
  }

  return(NULL)
}

#' Add Net Positive Row
#'
#' Calculates and adds Net Positive row (Top% - Bottom% with significance).
#' Uses DisplayOrder to identify Top (lowest) and Bottom (highest non-DK).
#'
#' V9.9.5: NEW FEATURE - Net Positive Option A
#'
#' @param existing_table Data frame, existing BoxCategory results
#' @param data Data frame, survey data
#' @param question_info Data frame row, question metadata
#' @param question_options Data frame, options
#' @param banner_info List, banner structure
#' @param banner_row_indices List, row indices
#' @param master_weights Numeric vector, weights
#' @param banner_bases List, base sizes
#' @param config List, configuration
#' @param is_weighted Logical, weighting flag
#' @return Data frame with net positive row added, or original if not applicable
#' @export
add_net_positive_row <- function(existing_table, data, question_info,
                                question_options, banner_info,
                                banner_row_indices, master_weights,
                                banner_bases, config, is_weighted = FALSE) {
  
  # Safety checks
  if (is.null(existing_table) || nrow(existing_table) == 0) {
    return(existing_table)
  }

  if (!config$show_net_positive) {
    return(existing_table)
  }

  # Get sorted BoxCategories (delegated to helper)
  ordered_cats <- get_sorted_boxcategories(question_options)
  if (is.null(ordered_cats)) {
    return(existing_table)
  }

  # Identify Top and Bottom categories (delegated to helper)
  categories <- identify_top_bottom_categories(ordered_cats)
  if (is.null(categories)) {
    return(existing_table)
  }

  internal_keys <- banner_info$internal_keys

  # Calculate counts for Top and Bottom
  row_counts_top <- calculate_boxcategory_counts(
    data, question_info, question_options, banner_row_indices,
    master_weights, internal_keys, categories$top
  )

  row_counts_bottom <- calculate_boxcategory_counts(
    data, question_info, question_options, banner_row_indices,
    master_weights, internal_keys, categories$bottom
  )

  # Create NET POSITIVE row (delegated to helper)
  net_positive_row <- create_net_positive_row(
    categories$top, categories$bottom, row_counts_top,
    row_counts_bottom, banner_bases, internal_keys, config
  )

  # Add net positive row to table
  existing_table <- rbind(existing_table, net_positive_row)

  # Add significance testing if enabled (delegated to helper)
  if (config$enable_significance_testing) {
    sig_row <- add_net_positive_significance(
      row_counts_top, row_counts_bottom,
      banner_bases, internal_keys, banner_info,
      config, is_weighted
    )

    if (!is.null(sig_row)) {
      existing_table <- rbind(existing_table, sig_row)
    }
  }

  return(existing_table)
}

# ==============================================================================
# HELPER FUNCTION: CALCULATE BOXCATEGORY COUNTS
# ==============================================================================

#' Calculate BoxCategory Counts
#'
#' Helper function to calculate weighted counts for a BoxCategory.
#' Aggregates all options within the category.
#'
#' @param data Data frame, survey data
#' @param question_info Data frame row, question metadata
#' @param question_options Data frame, all options
#' @param banner_row_indices List, row indices
#' @param master_weights Numeric vector, weights
#' @param internal_keys Character vector, banner column keys
#' @param category_name Character, BoxCategory name
#' @return Named numeric vector of counts by column
#' @export
calculate_boxcategory_counts <- function(data, question_info, question_options,
                                        banner_row_indices, master_weights,
                                        internal_keys, category_name) {
  
  row_counts <- setNames(numeric(length(internal_keys)), internal_keys)
  
  # Get options in this category
  category_options <- question_options[
    question_options$BoxCategory == category_name,
  ]
  
  # Calculate for each banner column
  for (key in internal_keys) {
    row_idx <- banner_row_indices[[key]]
    
    if (length(row_idx) > 0) {
      subset_weights <- master_weights[row_idx]
      
      if (question_info$Variable_Type == "Multi_Mention") {
        num_columns <- suppressWarnings(as.numeric(question_info$Columns))
        if (!is.na(num_columns) && num_columns > 0) {
          question_cols <- paste0(question_info$QuestionCode, "_", seq_len(num_columns))
          existing_cols <- question_cols[question_cols %in% names(data)]
          
          category_count <- 0
          for (question_col in existing_cols) {
            for (option_text in category_options$OptionText) {
              matching <- safe_equal(data[[question_col]][row_idx], option_text) &
                !is.na(data[[question_col]][row_idx])
              category_count <- category_count + sum(subset_weights[matching], na.rm = TRUE)
            }
          }
          row_counts[key] <- category_count
        }
      } else {
        question_col <- question_info$QuestionCode
        if (question_col %in% names(data)) {
          for (option_text in category_options$OptionText) {
            matching <- safe_equal(data[[question_col]][row_idx], option_text) &
              !is.na(data[[question_col]][row_idx])
            row_counts[key] <- row_counts[key] + sum(subset_weights[matching], na.rm = TRUE)
          }
        }
      }
    }
  }
  
  return(row_counts)
}
# ==============================================================================
# CHI-SQUARE TEST FOR BOXCATEGORY RESULTS
# ==============================================================================

#' Calculate Chi-Square Test Row for BoxCategory Results
#'
#' Performs chi-square test on BoxCategory frequency rows with smart filtering
#' and threshold checks. Extracted from orchestration loop for modularity.
#'
#' V9.9.5: RELAXED THRESHOLDS for small banner groups
#' - Min expected: 0.5 (was 1.0) - allows smaller cells
#' - Low expected %: 40% (was 20%) - more permissive for small groups
#'
#' @param boxcategory_results Data frame with BoxCategory summary rows
#' @param banner_info List with banner structure metadata (needs $internal_keys)
#' @param config Configuration object (needs $alpha)
#' @param total_column_name Character, name of total column (default "Total")
#' @param question_code Character, question code for error messages (optional)
#' @return Data frame with single chi-square row, or NULL if test not applicable
#' @export
calculate_chi_square_row <- function(boxcategory_results, banner_info, config,
                                     total_column_name = "Total",
                                     question_code = NULL) {

  # Validate inputs
  if (is.null(boxcategory_results) || !is.data.frame(boxcategory_results) ||
      nrow(boxcategory_results) == 0) {
    return(NULL)
  }

  if (is.null(banner_info) || is.null(banner_info$internal_keys)) {
    return(NULL)
  }

  chi_square_row <- tryCatch({
    # Get BoxCategory FREQUENCY rows
    box_freq_rows <- boxcategory_results[
      boxcategory_results$RowType == "Frequency",
    ]

    if (nrow(box_freq_rows) >= 2) {
      # Extract numeric matrix
      obs_matrix <- as.matrix(box_freq_rows[, banner_info$internal_keys, drop = FALSE])
      storage.mode(obs_matrix) <- "double"

      # Remove Total column
      total_key <- paste0("TOTAL::", total_column_name)
      if (total_key %in% colnames(obs_matrix)) {
        obs_matrix <- obs_matrix[, colnames(obs_matrix) != total_key, drop = FALSE]
      }

      if (ncol(obs_matrix) >= 2 && nrow(obs_matrix) >= 2) {

        # SMART FILTERING - Remove sparse BoxCategories
        row_totals <- rowSums(obs_matrix)
        row_labels <- box_freq_rows$RowLabel

        # Keep rows with at least 5 total responses OR 1% of sample
        min_count <- max(5, 0.01 * sum(obs_matrix))
        keep_rows <- row_totals >= min_count

        if (sum(keep_rows) >= 2) {
          obs_matrix_filtered <- obs_matrix[keep_rows, , drop = FALSE]
          filtered_labels <- row_labels[keep_rows]

          # Check expected frequencies
          row_totals_f <- rowSums(obs_matrix_filtered)
          col_totals_f <- colSums(obs_matrix_filtered)
          grand_total_f <- sum(obs_matrix_filtered)

          if (grand_total_f > 0) {
            expected_matrix <- outer(row_totals_f, col_totals_f) / grand_total_f
            min_expected <- min(expected_matrix)
            low_expected_pct <- 100 * sum(expected_matrix < 5) / length(expected_matrix)

            # V9.9.5: RELAXED THRESHOLDS for small banner groups
            # - Min expected: 0.5 (was 1.0) - allows smaller cells
            # - Low expected %: 40% (was 20%) - more permissive for small groups
            if (min_expected >= 0.5 && low_expected_pct <= 40) {
              chi_result <- chi_square_test(obs_matrix_filtered, alpha = config$alpha)

              # Build message
              chi_message <- sprintf("Chi-square (%d categories): χ²=%.2f, df=%d, p=%.4f%s",
                                    nrow(obs_matrix_filtered),
                                    chi_result$chi_square_stat,
                                    chi_result$df,
                                    chi_result$p_value,
                                    if (chi_result$significant) " **" else "")

              # Note if categories were excluded
              if (sum(keep_rows) < length(keep_rows)) {
                excluded_cats <- row_labels[!keep_rows]
                chi_message <- paste0(chi_message,
                                     sprintf(" [Excluded: %s]",
                                            paste(excluded_cats, collapse=", ")))
              }

              # Add warning note if thresholds are marginal
              if (min_expected < 1 || low_expected_pct > 20) {
                chi_message <- paste0(chi_message, " [Note: Small sample in some cells]")
              }

              # Create display row
              chi_row <- data.frame(
                RowLabel = chi_message,
                RowType = "ChiSquare",
                stringsAsFactors = FALSE
              )

              for (key in banner_info$internal_keys) {
                chi_row[[key]] <- NA_real_
              }

              chi_row
            } else {
              NULL
            }
          } else {
            NULL
          }
        } else {
          NULL
        }
      } else {
        NULL
      }
    } else {
      NULL
    }
  }, error = function(e) {
    error_msg <- if (!is.null(question_code)) {
      sprintf("Chi-square test failed for %s: %s", question_code, conditionMessage(e))
    } else {
      sprintf("Chi-square test failed: %s", conditionMessage(e))
    }
    warning(error_msg, call. = FALSE)
    NULL
  })

  return(chi_square_row)
}

# ==============================================================================
# MODULE INFO
# ==============================================================================

#' Get Standard Processor Module Information
#'
#' Returns metadata about the standard_processor module.
#'
#' @return List with module information
#' @export
get_standard_processor_info <- function() {
  list(
    module = "standard_processor",
    version = "1.0.0",
    date = "2025-10-25",
    description = "Standard question processor for single/multi choice, rating, likert, NPS",
    functions = c(
      "process_standard_question",
      "add_boxcategory_summaries",
      "add_summary_statistic",
      "add_net_significance_rows",
      "add_net_positive_row",
      "calculate_boxcategory_counts",
      "calculate_chi_square_row",
      "get_standard_processor_info"
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

message("[OK] Turas>Tabs standard_processor module loaded")

# ==============================================================================
# END OF MODULE 7: STANDARD_PROCESSOR.R
# ==============================================================================
