# ==============================================================================
# CURRENT MULTI_MENTION CODE - EXACT COPY FROM trend_calculator.R
# Extracted: 2025-12-05
# Lines: 1940-2690
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION 1: detect_multi_mention_columns (Lines 1940-1962)
# ------------------------------------------------------------------------------
detect_multi_mention_columns <- function(wave_df, base_code) {

  # Escape special regex characters in base_code
  base_code_escaped <- gsub("([.|()\\^{}+$*?\\[\\]])", "\\\\\\1", base_code)

  # Build pattern: ^{base_code}_{digits}$
  pattern <- paste0("^", base_code_escaped, "_[0-9]+$")

  # Find matches
  matched_cols <- grep(pattern, names(wave_df), value = TRUE)

  if (length(matched_cols) == 0) {
    warning(paste0("No multi-mention columns found for base code: ", base_code))
    return(NULL)
  }

  # Extract numeric parts and sort numerically (not lexicographically)
  numeric_parts <- as.integer(sub(paste0("^", base_code_escaped, "_"), "", matched_cols))
  sort_order <- order(numeric_parts)
  matched_cols <- matched_cols[sort_order]

  return(matched_cols)
}


# ------------------------------------------------------------------------------
# FUNCTION 2: parse_multi_mention_specs (Lines 1976-2052)
# ------------------------------------------------------------------------------
parse_multi_mention_specs <- function(tracking_specs, base_code, wave_df) {

  # Default to auto if blank
  if (is.null(tracking_specs) || tracking_specs == "" || tolower(trimws(tracking_specs)) == "auto") {
    return(list(
      mode = "auto",
      columns = detect_multi_mention_columns(wave_df, base_code),
      categories = character(0),
      additional_metrics = character(0)
    ))
  }

  # Parse comma-separated specs
  specs <- trimws(strsplit(tracking_specs, ",")[[1]])

  result <- list(
    mode = "selective",
    columns = character(0),
    categories = character(0),
    additional_metrics = character(0)
  )

  for (spec in specs) {
    spec_lower <- tolower(trimws(spec))

    if (spec_lower == "auto") {
      # Auto-detect all columns
      result$mode <- "auto"
      auto_cols <- detect_multi_mention_columns(wave_df, base_code)
      if (!is.null(auto_cols)) {
        result$columns <- unique(c(result$columns, auto_cols))
      }

    } else if (startsWith(spec_lower, "option:")) {
      # Specific option: "option:Q30_1"
      col_name <- sub("^option:", "", spec, ignore.case = TRUE)
      col_name <- trimws(col_name)  # Remove any leading/trailing whitespace
      if (col_name != "") {  # Only add if not empty
        result$columns <- c(result$columns, col_name)
      }

    } else if (startsWith(spec_lower, "category:")) {
      # Specific category text: "category:Internal store system"
      category_name <- sub("^category:", "", spec, ignore.case = TRUE)
      category_name <- trimws(category_name)  # Remove any leading/trailing whitespace
      if (category_name != "") {  # Only add if not empty
        result$mode <- "category"
        result$categories <- c(result$categories, category_name)
      }

    } else if (spec_lower %in% c("any", "count_mean", "count_distribution")) {
      # Additional metrics
      result$additional_metrics <- c(result$additional_metrics, spec_lower)

    } else {
      warning(paste0("Unknown Multi_Mention spec: ", spec))
    }
  }

  # Remove duplicates
  result$columns <- unique(result$columns)
  result$categories <- unique(result$categories)
  result$additional_metrics <- unique(result$additional_metrics)

  # Validate columns exist in data (skip if base_code is empty - we're just parsing for additional metrics)
  # Only validate for option: mode, not category: mode
  if (result$mode != "category" && length(result$columns) > 0 && !is.null(base_code) && base_code != "") {
    missing <- setdiff(result$columns, names(wave_df))
    if (length(missing) > 0) {
      warning(paste0("Multi-mention columns not found in data: ",
                     paste(missing, collapse = ", ")))
      result$columns <- intersect(result$columns, names(wave_df))
    }
  }

  return(result)
}


# ------------------------------------------------------------------------------
# FUNCTION 3: calculate_multi_mention_trend_categories (Lines 2061-2219)
# ------------------------------------------------------------------------------
calculate_multi_mention_trend_categories <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get TrackingSpecs
  tracking_specs <- get_tracking_specs(question_map, q_code)

  # First pass: detect all multi-mention columns and gather unique categories
  wave_base_codes <- list()
  all_categories <- character(0)

  for (wave_id in wave_ids) {
    wave_code <- get_wave_question_code(question_map, q_code, wave_id)
    if (!is.na(wave_code)) {
      wave_base_codes[[wave_id]] <- wave_code
      wave_df <- wave_data[[wave_id]]

      # Detect all multi-mention columns for this question
      mm_columns <- detect_multi_mention_columns(wave_df, wave_code)

      if (!is.null(mm_columns) && length(mm_columns) > 0) {
        # Gather all unique text values from these columns
        for (col in mm_columns) {
          if (col %in% names(wave_df)) {
            col_values <- wave_df[[col]]
            unique_vals <- unique(col_values[!is.na(col_values) & col_values != ""])
            all_categories <- unique(c(all_categories, unique_vals))
          }
        }
      }
    }
  }

  # Parse specs to determine which categories to track
  specs <- parse_multi_mention_specs(tracking_specs, "", wave_data[[wave_ids[1]]])
  categories_to_track <- if (length(specs$categories) > 0) {
    specs$categories
  } else {
    all_categories  # Track all discovered categories if no specific ones requested
  }

  if (length(categories_to_track) == 0) {
    warning(paste0("No categories found for question: ", q_code))
    return(NULL)
  }

  # Calculate metrics for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    wave_df <- wave_data[[wave_id]]
    wave_code <- wave_base_codes[[wave_id]]

    if (is.null(wave_code) || is.na(wave_code)) {
      wave_results[[wave_id]] <- list(
        available = FALSE,
        mention_proportions = list(),
        additional_metrics = list()
      )
      next
    }

    # Detect multi-mention columns for this wave
    mm_columns <- detect_multi_mention_columns(wave_df, wave_code)

    if (is.null(mm_columns) || length(mm_columns) == 0) {
      wave_results[[wave_id]] <- list(
        available = FALSE,
        mention_proportions = list(),
        additional_metrics = list()
      )
      next
    }

    # Filter to only existing columns
    mm_columns <- mm_columns[mm_columns %in% names(wave_df)]

    if (length(mm_columns) == 0) {
      wave_results[[wave_id]] <- list(
        available = FALSE,
        mention_proportions = list(),
        additional_metrics = list()
      )
      next
    }

    # Calculate mention proportions for each category
    mention_proportions <- list()

    # Create valid row indices
    valid_rows <- which(!is.na(wave_df$weight_var) & wave_df$weight_var > 0)

    for (category in categories_to_track) {
      # Search for this category text across ALL multi-mention columns
      mentioned_rows <- c()

      for (col in mm_columns) {
        col_data <- wave_df[[col]]
        # Find rows where this column contains the category text (case-insensitive match)
        matching_idx <- which(!is.na(col_data) & trimws(tolower(col_data)) == trimws(tolower(category)))
        matching_rows <- intersect(valid_rows, matching_idx)
        mentioned_rows <- unique(c(mentioned_rows, matching_rows))
      }

      # Calculate weighted proportion
      mentioned_weight <- sum(wave_df$weight_var[mentioned_rows], na.rm = TRUE)
      total_weight <- sum(wave_df$weight_var[valid_rows], na.rm = TRUE)

      proportion <- if (total_weight > 0) {
        (mentioned_weight / total_weight) * 100
      } else {
        NA
      }

      mention_proportions[[category]] <- proportion
    }

    # Store results
    wave_results[[wave_id]] <- list(
      available = TRUE,
      mention_proportions = mention_proportions,
      additional_metrics = list(),  # Category mode doesn't support additional metrics yet
      tracked_columns = mm_columns,
      tracked_categories = categories_to_track,
      n_unweighted = length(valid_rows),
      n_weighted = sum(wave_df$weight_var[valid_rows], na.rm = TRUE)
    )
  }

  # Calculate changes for each category
  changes <- list()
  for (category in categories_to_track) {
    changes[[category]] <- calculate_changes_for_multi_mention_option(
      wave_results, wave_ids, category
    )
  }

  # Significance testing for each category
  significance <- list()
  for (category in categories_to_track) {
    significance[[category]] <- perform_significance_tests_multi_mention(
      wave_results, wave_ids, category, config
    )
  }

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "category_mentions",
    response_categories = categories_to_track,
    tracking_specs = tracking_specs,
    wave_results = wave_results,
    changes = changes,
    significance = significance,
    metadata = metadata
  ))
}


# ------------------------------------------------------------------------------
# FUNCTION 4: calculate_multi_mention_trend (MAIN - Lines 2228-2468)
# ------------------------------------------------------------------------------
calculate_multi_mention_trend <- function(q_code, question_map, wave_data, config) {

  wave_ids <- config$waves$WaveID
  metadata <- get_question_metadata(question_map, q_code)

  # Get TrackingSpecs
  tracking_specs <- get_tracking_specs(question_map, q_code)

  # Parse specs to check mode (need to parse once to determine if category mode)
  # Find first wave where question exists (not NA)
  first_wave_code <- NA
  first_wave_df <- NULL
  for (wave_id in wave_ids) {
    wave_code <- get_wave_question_code(question_map, q_code, wave_id)
    if (!is.na(wave_code)) {
      first_wave_code <- wave_code
      first_wave_df <- wave_data[[wave_id]]
      break
    }
  }

  # If question not found in any wave, return NULL
  if (is.na(first_wave_code) || is.null(first_wave_df)) {
    warning(paste0("Question ", q_code, " not found in any wave"))
    return(NULL)
  }

  initial_specs <- parse_multi_mention_specs(tracking_specs, first_wave_code, first_wave_df)

  # If category mode, use category-based tracking
  if (initial_specs$mode == "category") {
    return(calculate_multi_mention_trend_categories(q_code, question_map, wave_data, config))
  }

  # Otherwise, continue with binary column-based tracking
  # Initialize structure to track all detected columns across all waves
  all_columns <- character(0)

  # First pass: detect columns in each wave, RESPECTING TrackingSpecs
  wave_base_codes <- list()
  for (wave_id in wave_ids) {
    wave_code <- get_wave_question_code(question_map, q_code, wave_id)
    if (!is.na(wave_code)) {
      wave_base_codes[[wave_id]] <- wave_code
      wave_df <- wave_data[[wave_id]]

      # Parse specs for this wave to determine which columns to track
      specs <- parse_multi_mention_specs(tracking_specs, wave_code, wave_df)
      detected_cols <- specs$columns

      if (!is.null(detected_cols) && length(detected_cols) > 0) {
        all_columns <- unique(c(all_columns, detected_cols))
      }
    }
  }

  if (length(all_columns) == 0) {
    warning(paste0("No multi-mention columns found for question: ", q_code))
    return(NULL)
  }

  # Calculate metrics for each wave
  wave_results <- list()

  for (wave_id in wave_ids) {
    wave_df <- wave_data[[wave_id]]
    wave_code <- wave_base_codes[[wave_id]]

    if (is.null(wave_code) || is.na(wave_code)) {
      wave_results[[wave_id]] <- list(
        available = FALSE,
        mention_proportions = list(),
        additional_metrics = list()
      )
      next
    }

    # Parse specs for this wave
    specs <- parse_multi_mention_specs(tracking_specs, wave_code, wave_df)

    # Use detected columns from specs
    option_columns <- specs$columns

    if (is.null(option_columns) || length(option_columns) == 0) {
      wave_results[[wave_id]] <- list(
        available = FALSE,
        mention_proportions = list(),
        additional_metrics = list()
      )
      next
    }

    # Calculate mention proportions for each option
    mention_proportions <- list()

    # Create valid row indices (use which() to ensure numeric indices)
    valid_rows <- which(!is.na(wave_df$weight_var) & wave_df$weight_var > 0)

    for (col_name in option_columns) {
      if (!col_name %in% names(wave_df)) {
        mention_proportions[[col_name]] <- NA
        next
      }

      # Get column data
      col_data <- wave_df[[col_name]]

      # Check if column data is valid
      if (is.null(col_data) || all(is.na(col_data))) {
        mention_proportions[[col_name]] <- NA
        next
      }

      # Calculate % mentioning (value == 1)
      # Use which() on valid_rows subset to avoid NA issues
      valid_col_data <- col_data[valid_rows]
      mentioned_idx <- which(!is.na(valid_col_data) & valid_col_data == 1)
      mentioned_rows <- valid_rows[mentioned_idx]

      mentioned_weight <- sum(wave_df$weight_var[mentioned_rows], na.rm = TRUE)
      total_weight <- sum(wave_df$weight_var[valid_rows], na.rm = TRUE)

      proportion <- if (total_weight > 0) {
        (mentioned_weight / total_weight) * 100
      } else {
        NA
      }

      mention_proportions[[col_name]] <- proportion
    }

    # Calculate additional metrics if requested
    additional_metrics <- list()

    # Note: valid_rows already defined above

    if ("any" %in% specs$additional_metrics) {
      # % mentioning at least one option
      option_matrix <- as.matrix(wave_df[valid_rows, option_columns, drop = FALSE])
      mentioned_any <- rowSums(option_matrix == 1, na.rm = TRUE) > 0
      mentioned_any_idx <- which(mentioned_any)
      any_weight <- sum(wave_df$weight_var[valid_rows][mentioned_any_idx], na.rm = TRUE)
      total_weight <- sum(wave_df$weight_var[valid_rows], na.rm = TRUE)
      additional_metrics$any_mention_pct <- if (total_weight > 0) {
        (any_weight / total_weight) * 100
      } else {
        NA
      }
    }

    if ("count_mean" %in% specs$additional_metrics) {
      # Mean number of mentions
      option_matrix <- as.matrix(wave_df[valid_rows, option_columns, drop = FALSE])
      mention_counts <- rowSums(option_matrix == 1, na.rm = TRUE)
      weights_valid <- wave_df$weight_var[valid_rows]
      additional_metrics$count_mean <- if (sum(weights_valid, na.rm = TRUE) > 0) {
        sum(mention_counts * weights_valid, na.rm = TRUE) / sum(weights_valid, na.rm = TRUE)
      } else {
        NA
      }
    }

    if ("count_distribution" %in% specs$additional_metrics) {
      # Distribution of mention counts
      option_matrix <- as.matrix(wave_df[valid_rows, option_columns, drop = FALSE])
      mention_counts <- rowSums(option_matrix == 1, na.rm = TRUE)
      weights_valid <- wave_df$weight_var[valid_rows]
      total_weight <- sum(weights_valid, na.rm = TRUE)

      count_dist <- list()
      for (count_val in 0:length(option_columns)) {
        matched_idx <- which(mention_counts == count_val)
        count_weight <- sum(weights_valid[matched_idx], na.rm = TRUE)
        count_dist[[as.character(count_val)]] <- if (total_weight > 0) {
          (count_weight / total_weight) * 100
        } else {
          NA
        }
      }
      additional_metrics$count_distribution <- count_dist
    }

    # Store results
    wave_results[[wave_id]] <- list(
      available = TRUE,
      mention_proportions = mention_proportions,
      additional_metrics = additional_metrics,
      tracked_columns = option_columns,
      n_unweighted = length(valid_rows),
      n_weighted = sum(wave_df$weight_var[valid_rows], na.rm = TRUE)
    )
  }

  # Calculate changes for each option
  changes <- list()
  for (col_name in all_columns) {
    changes[[col_name]] <- calculate_changes_for_multi_mention_option(
      wave_results, wave_ids, col_name
    )
  }

  # Calculate changes for additional metrics
  additional_specs <- parse_multi_mention_specs(tracking_specs, "", wave_data[[wave_ids[1]]])
  if ("any" %in% additional_specs$additional_metrics) {
    changes$any_mention_pct <- calculate_changes_for_multi_mention_metric(
      wave_results, wave_ids, "any_mention_pct"
    )
  }
  if ("count_mean" %in% additional_specs$additional_metrics) {
    changes$count_mean <- calculate_changes_for_multi_mention_metric(
      wave_results, wave_ids, "count_mean"
    )
  }

  # Significance testing for each option
  significance <- list()
  for (col_name in all_columns) {
    significance[[col_name]] <- perform_significance_tests_multi_mention(
      wave_results, wave_ids, col_name, config
    )
  }

  # Significance for additional metrics
  if ("any" %in% additional_specs$additional_metrics) {
    significance$any_mention_pct <- perform_significance_tests_multi_mention_metric(
      wave_results, wave_ids, "any_mention_pct", config
    )
  }

  return(list(
    question_code = q_code,
    question_text = metadata$QuestionText,
    question_type = metadata$QuestionType,
    metric_type = "multi_mention",
    tracking_specs = tracking_specs,
    tracked_columns = all_columns,
    wave_results = wave_results,
    changes = changes,
    significance = significance
  ))
}


# ------------------------------------------------------------------------------
# FUNCTION 5: calculate_changes_for_multi_mention_option (Lines 2474-2530)
# ------------------------------------------------------------------------------
calculate_changes_for_multi_mention_option <- function(wave_results, wave_ids, column_name) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get mention proportions
    current_val <- if (current$available && !is.null(current$mention_proportions[[column_name]])) {
      current$mention_proportions[[column_name]]
    } else {
      NA
    }

    previous_val <- if (previous$available && !is.null(previous$mention_proportions[[column_name]])) {
      previous$mention_proportions[[column_name]]
    } else {
      NA
    }

    # Calculate changes
    if (!is.na(current_val) && !is.na(previous_val)) {
      absolute_change <- current_val - previous_val
      percentage_change <- if (previous_val == 0) {
        NA
      } else {
        (absolute_change / previous_val) * 100
      }

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
        direction = NA
      )
    }
  }

  return(changes)
}


# ------------------------------------------------------------------------------
# FUNCTION 6: calculate_changes_for_multi_mention_metric (Lines 2536-2590)
# ------------------------------------------------------------------------------
calculate_changes_for_multi_mention_metric <- function(wave_results, wave_ids, metric_name) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    current_val <- if (current$available && !is.null(current$additional_metrics[[metric_name]])) {
      current$additional_metrics[[metric_name]]
    } else {
      NA
    }

    previous_val <- if (previous$available && !is.null(previous$additional_metrics[[metric_name]])) {
      previous$additional_metrics[[metric_name]]
    } else {
      NA
    }

    if (!is.na(current_val) && !is.na(previous_val)) {
      absolute_change <- current_val - previous_val
      percentage_change <- if (previous_val == 0) {
        NA
      } else {
        (absolute_change / previous_val) * 100
      }

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
        direction = NA
      )
    }
  }

  return(changes)
}


# ------------------------------------------------------------------------------
# FUNCTION 7: perform_significance_tests_multi_mention (Lines 2601-2639)
# ------------------------------------------------------------------------------
perform_significance_tests_multi_mention <- function(wave_results, wave_ids, column_name, config) {

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  sig_tests <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    if (!current$available || !previous$available) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    current_val <- current$mention_proportions[[column_name]]
    previous_val <- previous$mention_proportions[[column_name]]

    if (is.na(current_val) || is.na(previous_val)) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    # Convert percentages to proportions
    p1 <- previous_val / 100
    p2 <- current_val / 100

    test_result <- z_test_for_proportions(p1, previous_eff_n, p2, current_eff_n, alpha)
    sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- test_result
  }

  return(sig_tests)
}


# ------------------------------------------------------------------------------
# FUNCTION 8: perform_significance_tests_multi_mention_metric (Lines 2645-2690)
# ------------------------------------------------------------------------------
perform_significance_tests_multi_mention_metric <- function(wave_results, wave_ids, metric_name, config) {

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  sig_tests <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    if (!current$available || !previous$available) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    current_val <- current$additional_metrics[[metric_name]]
    previous_val <- previous$additional_metrics[[metric_name]]

    if (is.na(current_val) || is.na(previous_val)) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    # For "any" metric, use z-test for proportions (using effective N)
    # For "count_mean", use t-test (but need raw values - skip for now)
    if (metric_name == "any_mention_pct") {
      p1 <- previous_val / 100
      p2 <- current_val / 100

      test_result <- z_test_for_proportions(p1, previous_eff_n, p2, current_eff_n, alpha)
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- test_result
    } else {
      # For count_mean, we'd need the raw count values for t-test
      # Skip significance testing for now
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
    }
  }

  return(sig_tests)
}

# ==============================================================================
# END OF MULTI_MENTION CODE
# ==============================================================================
