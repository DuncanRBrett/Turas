# ==============================================================================
# COMPLETE MULTI_MENTION TRACKING CODE FOR REVIEW
# ==============================================================================
# Problem: Q10 appears in output but all values are blank/NA
# Question: Q10 is Multi_Mention with TEXT data (not 0/1)
# Data format: Q10_1, Q10_2, Q10_3, etc. contain text labels
# TrackingSpecs: category:Internal store system,category:Personal records,category:Other
# Wave mapping: Wave1=NA, Wave2=Q10, Wave3=Q10
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION 1: detect_multi_mention_columns
# ------------------------------------------------------------------------------
# Purpose: Find all columns matching pattern {base_code}_{number}
# Example: base_code="Q10" finds Q10_1, Q10_2, Q10_3, Q10_4, etc.
# Returns: Character vector of column names, sorted numerically
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
# FUNCTION 2: parse_multi_mention_specs
# ------------------------------------------------------------------------------
# Purpose: Parse TrackingSpecs string to determine mode and what to track
# Input: tracking_specs = "category:Personal records,category:Other"
# Output: list(mode="category", categories=c("Personal records", "Other"), ...)
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
      col_name <- trimws(col_name)
      if (col_name != "") {
        result$columns <- c(result$columns, col_name)
      }

    } else if (startsWith(spec_lower, "category:")) {
      # Specific category text: "category:Internal store system"
      category_name <- sub("^category:", "", spec, ignore.case = TRUE)
      category_name <- trimws(category_name)
      if (category_name != "") {
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

  # Validate columns exist in data (skip if base_code is empty)
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
# FUNCTION 3: calculate_multi_mention_trend_categories
# ------------------------------------------------------------------------------
# Purpose: Track text-based multi-mention questions
# How it works:
#   1. Detect all Q10_* columns
#   2. For each category, search for that text across ALL Q10_* columns
#   3. If respondent has that text in ANY column, they "mentioned" it
#   4. Calculate % mentioning each category
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
      additional_metrics = list(),
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
# FUNCTION 4: calculate_multi_mention_trend (MAIN DISPATCHER)
# ------------------------------------------------------------------------------
# Purpose: Main entry point - detects mode and routes to appropriate handler
# Binary mode (0/1): Uses original logic
# Category mode (text): Routes to calculate_multi_mention_trend_categories
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

  # Otherwise, continue with binary column-based tracking (0/1 values)
  # ... (rest of binary mode code follows)

  # [BINARY MODE CODE OMITTED FOR BREVITY - THIS WORKS FINE]
  # The issue is in category mode above, not binary mode
}

# ==============================================================================
# DEBUGGING QUESTIONS TO INVESTIGATE
# ==============================================================================
#
# 1. Is parse_multi_mention_specs() correctly identifying mode as "category"?
#    - Check: Does specs$categories contain the category names?
#    - Check: Is result$mode set to "category"?
#
# 2. Are columns being detected?
#    - Check: Does detect_multi_mention_columns() find Q10_1, Q10_2, etc?
#    - Check: Are these columns in wave_df?
#
# 3. Is the text matching working?
#    - Line 226: matching_idx <- which(!is.na(col_data) & trimws(tolower(col_data)) == trimws(tolower(category)))
#    - Check: Are the category names EXACTLY matching what's in the data?
#    - Check: Is trimws() and tolower() working correctly?
#
# 4. Is categories_to_track populated?
#    - Line 172: categories_to_track = specs$categories or all_categories
#    - Check: What does this contain?
#
# 5. Are wave_results being populated?
#    - Line 243: mention_proportions[[category]] <- proportion
#    - Check: What values are in mention_proportions?
#    - Check: Is proportion being calculated correctly?
#
# 6. Is the return structure correct?
#    - Line 263-272: Returns list with wave_results
#    - Check: Does this match what the output formatter expects?
#
# MOST LIKELY ISSUE:
# The category text in TrackingSpecs might not exactly match the text in the data.
# Example:
#   Data has: "Internal store system (e.g merchandiser control form/register)"
#   TrackingSpecs has: "Internal store system"
#   These won't match with exact string comparison!
#
# ==============================================================================
