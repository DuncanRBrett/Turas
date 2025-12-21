# ==============================================================================
# MODULE: COMPOSITE_PROCESSOR.R
# ==============================================================================
#
# PURPOSE:
#   Process composite metrics that combine multiple questions
#   Composites are treated as "virtual questions" and processed through
#   the same pipeline as regular questions (banner, weighting, significance)
#
# FUNCTIONS:
#   - load_composite_definitions() - Load from Survey_Structure.xlsx
#   - validate_composite_definitions() - Pre-flight checks
#   - process_composite_question() - Main processor for one composite
#   - process_all_composites() - Process all composites
#   - calculate_composite_values() - Core calculation logic
#
# DEPENDENCIES:
#   - cell_calculator.R (calculate_summary_statistic)
#   - banner.R (banner structure)
#   - weighting.R (test_sig_mean)
#   - shared_functions.R (utilities)
#
# VERSION: 1.0.0
# DATE: 2025-11-06
# ==============================================================================

#' Load Composite Definitions
#'
#' Load composite metric definitions from Survey_Structure.xlsx
#'
#' @param survey_structure_file Path to Survey_Structure.xlsx
#' @return Data frame with composite definitions or NULL if sheet doesn't exist
#' @export
load_composite_definitions <- function(survey_structure_file) {

  # Check if file exists
  if (!file.exists(survey_structure_file)) {
    stop("Survey structure file not found: ", survey_structure_file)
  }

  # Check if Composite_Metrics sheet exists
  tryCatch({
    sheets <- readxl::excel_sheets(survey_structure_file)

    if (!"Composite_Metrics" %in% sheets) {
      # No composites defined - this is valid
      return(NULL)
    }

    # Read the sheet
    composite_defs <- readxl::read_excel(
      survey_structure_file,
      sheet = "Composite_Metrics",
      col_types = "text"  # Read all as text initially
    )

    # Check if empty
    if (nrow(composite_defs) == 0) {
      # TRS v1.0: Empty Composite_Metrics sheet is a config error - refuse
      tabs_refuse(
        code = "CFG_COMPOSITE_SHEET_EMPTY",
        title = "Empty Composite_Metrics Sheet",
        problem = "The Composite_Metrics sheet exists but contains no definitions.",
        why_it_matters = "If the sheet exists, Turas expects it to contain composite definitions. An empty sheet suggests incomplete configuration.",
        how_to_fix = c(
          "Add composite metric definitions to the Composite_Metrics sheet, or",
          "Delete the Composite_Metrics sheet entirely if you don't need composites"
        )
      )
    }

    # Validate required columns
    required_cols <- c("CompositeCode", "CompositeLabel", "CalculationType", "SourceQuestions")
    missing_cols <- setdiff(required_cols, names(composite_defs))

    if (length(missing_cols) > 0) {
      stop("Composite_Metrics sheet missing required columns: ",
           paste(missing_cols, collapse = ", "))
    }

    # Clean data
    composite_defs$CompositeCode <- trimws(composite_defs$CompositeCode)
    composite_defs$CompositeLabel <- trimws(composite_defs$CompositeLabel)
    composite_defs$CalculationType <- trimws(composite_defs$CalculationType)
    composite_defs$SourceQuestions <- trimws(composite_defs$SourceQuestions)

    # Handle optional columns
    if (!"Weights" %in% names(composite_defs)) {
      composite_defs$Weights <- NA_character_
    } else {
      composite_defs$Weights <- trimws(composite_defs$Weights)
    }

    if (!"ExcludeFromSummary" %in% names(composite_defs)) {
      composite_defs$ExcludeFromSummary <- NA_character_
    }

    if (!"SectionLabel" %in% names(composite_defs)) {
      composite_defs$SectionLabel <- NA_character_
    }

    if (!"Notes" %in% names(composite_defs)) {
      composite_defs$Notes <- NA_character_
    }

    # Remove rows with blank CompositeCode
    blank_codes <- is.na(composite_defs$CompositeCode) | composite_defs$CompositeCode == ""
    if (any(blank_codes)) {
      message(sprintf("[TRS INFO] Removing %d row(s) with blank CompositeCode", sum(blank_codes)))
      composite_defs <- composite_defs[!blank_codes, ]
    }

    # TRS v1.0: If sheet exists but becomes empty after cleaning, refuse
    if (nrow(composite_defs) == 0) {
      tabs_refuse(
        code = "CFG_COMPOSITE_SHEET_EMPTY_AFTER_CLEANING",
        title = "Composite Sheet Empty After Cleaning",
        problem = "The Composite_Metrics sheet exists but all rows have blank CompositeCode.",
        why_it_matters = "If the Composite_Metrics sheet is present, Turas expects at least one valid composite definition. An empty sheet after cleaning indicates incomplete configuration.",
        how_to_fix = c(
          "Add valid composite definitions with non-blank CompositeCode values, or",
          "Delete the Composite_Metrics sheet entirely if you don't need composites"
        )
      )
    }

    return(composite_defs)

  }, error = function(e) {
    stop("Error loading Composite_Metrics sheet: ", e$message)
  })
}

#' Validate Composite Definitions
#'
#' Validate composite definitions against survey structure
#'
#' @param composite_defs Data frame of composite definitions
#' @param questions_df Questions data frame from Survey_Structure
#' @param survey_data Survey data frame
#' @return List with is_valid (logical), errors (character vector), warnings (character vector)
#' @export
validate_composite_definitions <- function(composite_defs, questions_df, survey_data) {

  errors <- character()
  warnings <- character()

  # Check 1: CompositeCode uniqueness
  dup_codes <- composite_defs$CompositeCode[duplicated(composite_defs$CompositeCode)]
  if (length(dup_codes) > 0) {
    errors <- c(errors, sprintf("Duplicate CompositeCode(s): %s",
                                paste(unique(dup_codes), collapse = ", ")))
  }

  # Check 2: CompositeCode doesn't conflict with QuestionCode
  conflicting_codes <- intersect(composite_defs$CompositeCode, questions_df$QuestionCode)
  if (length(conflicting_codes) > 0) {
    errors <- c(errors, sprintf("CompositeCode(s) conflict with existing QuestionCode(s): %s",
                                paste(conflicting_codes, collapse = ", ")))
  }

  # Check each composite
  for (i in 1:nrow(composite_defs)) {
    comp_def <- composite_defs[i, ]
    comp_code <- comp_def$CompositeCode

    # Parse source questions
    source_questions <- strsplit(comp_def$SourceQuestions, ",")[[1]]
    source_questions <- trimws(source_questions)

    if (length(source_questions) == 0) {
      errors <- c(errors, sprintf("Composite '%s' has no SourceQuestions", comp_code))
      next
    }

    # Check 3: SourceQuestions exist in questions_df
    missing_questions <- setdiff(source_questions, questions_df$QuestionCode)
    if (length(missing_questions) > 0) {
      errors <- c(errors, sprintf("Composite '%s' references non-existent question(s): %s",
                                  comp_code, paste(missing_questions, collapse = ", ")))
    }

    # Check 4: SourceQuestions exist in survey_data
    existing_sources <- intersect(source_questions, questions_df$QuestionCode)
    if (length(existing_sources) > 0) {
      missing_in_data <- setdiff(existing_sources, names(survey_data))
      if (length(missing_in_data) > 0) {
        errors <- c(errors, sprintf("Composite '%s': Question(s) not found in data: %s",
                                    comp_code, paste(missing_in_data, collapse = ", ")))
      }
    }

    # Check 5: SourceQuestions type compatibility
    if (length(existing_sources) > 0) {
      source_types <- questions_df$Variable_Type[questions_df$QuestionCode %in% existing_sources]
      unique_types <- unique(source_types)

      if (length(unique_types) > 1) {
        errors <- c(errors, sprintf(
          "Composite '%s' mixes question types: %s. All sources must be same type (Rating, Likert, or Numeric)",
          comp_code, paste(unique_types, collapse = ", ")
        ))
      }

      # Only allow Rating, Likert, or Numeric
      valid_types <- c("Rating", "Likert", "Numeric")
      if (!all(source_types %in% valid_types)) {
        invalid_types <- setdiff(source_types, valid_types)
        errors <- c(errors, sprintf(
          "Composite '%s' includes invalid question type(s): %s. Only Rating, Likert, and Numeric are supported",
          comp_code, paste(invalid_types, collapse = ", ")
        ))
      }
    }

    # Check 6: CalculationType validation
    calc_type <- comp_def$CalculationType
    valid_calc_types <- c("Mean", "Sum", "WeightedMean")
    if (!calc_type %in% valid_calc_types) {
      errors <- c(errors, sprintf(
        "Composite '%s' has invalid CalculationType '%s'. Must be: %s",
        comp_code, calc_type, paste(valid_calc_types, collapse = ", ")
      ))
    }

    # Check 7: Weights validation (if WeightedMean)
    if (calc_type == "WeightedMean") {
      if (is.na(comp_def$Weights) || comp_def$Weights == "") {
        errors <- c(errors, sprintf(
          "Composite '%s' uses WeightedMean but Weights column is empty",
          comp_code
        ))
      } else {
        # Parse weights
        weights_str <- trimws(strsplit(comp_def$Weights, ",")[[1]])
        weights_num <- suppressWarnings(as.numeric(weights_str))

        if (any(is.na(weights_num))) {
          errors <- c(errors, sprintf(
            "Composite '%s' has non-numeric weights: %s",
            comp_code, comp_def$Weights
          ))
        } else {
          # Check count matches source questions
          if (length(weights_num) != length(source_questions)) {
            errors <- c(errors, sprintf(
              "Composite '%s' has %d source questions but %d weights",
              comp_code, length(source_questions), length(weights_num)
            ))
          }

          # Check all positive
          if (any(weights_num <= 0)) {
            errors <- c(errors, sprintf(
              "Composite '%s' has non-positive weights. All weights must be > 0",
              comp_code
            ))
          }
        }
      }
    }

    # Warning: Single source question
    if (length(source_questions) == 1) {
      warnings <- c(warnings, sprintf(
        "Composite '%s' has only one source question. Consider using the source question directly.",
        comp_code
      ))
    }
  }

  return(list(
    is_valid = length(errors) == 0,
    errors = errors,
    warnings = warnings
  ))
}

#' Calculate Composite Values
#'
#' Calculate composite score for respondent data
#'
#' @param data_subset Survey data subset
#' @param source_questions Character vector of source question codes
#' @param calculation_type "Mean", "Sum", or "WeightedMean"
#' @param weights Numeric vector of calculation weights (for WeightedMean)
#' @param weight_vector Survey weights for this subset (optional)
#' @return Numeric: composite value (weighted mean if weight_vector provided, else vector)
#' @keywords internal
calculate_composite_values <- function(data_subset, source_questions,
                                       calculation_type, weights = NULL,
                                       weight_vector = NULL) {

  # Validate calculation_type
  if (is.null(calculation_type) || length(calculation_type) == 0) {
    stop("calculation_type cannot be NULL or empty")
  }

  if (nrow(data_subset) == 0) {
    if (!is.null(weight_vector)) {
      return(NA_real_)
    } else {
      return(numeric(0))
    }
  }

  # Extract source values as matrix
  source_values_matrix <- matrix(NA_real_, nrow = nrow(data_subset),
                                  ncol = length(source_questions))

  for (i in seq_along(source_questions)) {
    q_code <- source_questions[i]

    if (q_code %in% names(data_subset)) {
      # Get numeric values
      values <- data_subset[[q_code]]

      # Convert to numeric if needed
      if (!is.numeric(values)) {
        values <- suppressWarnings(as.numeric(as.character(values)))
      }

      source_values_matrix[, i] <- values
    }
  }

  # Calculate composite based on type
  composite_values <- rep(NA_real_, nrow(data_subset))

  if (calculation_type == "Mean") {
    # Simple mean of available values
    composite_values <- rowMeans(source_values_matrix, na.rm = TRUE)

  } else if (calculation_type == "Sum") {
    # Sum of available values
    composite_values <- rowSums(source_values_matrix, na.rm = TRUE)

  } else if (calculation_type == "WeightedMean") {
    # Weighted mean: sum(values * weights) / sum(weights for non-NA values)
    if (is.null(weights)) {
      stop("WeightedMean requires weights parameter")
    }

    for (i in 1:nrow(source_values_matrix)) {
      row_values <- source_values_matrix[i, ]
      valid_idx <- !is.na(row_values)

      if (sum(valid_idx) > 0) {
        composite_values[i] <- sum(row_values[valid_idx] * weights[valid_idx]) /
                                sum(weights[valid_idx])
      }
    }
  }

  # Set to NA if all sources were NA
  valid_count <- rowSums(!is.na(source_values_matrix))
  composite_values[valid_count == 0] <- NA_real_

  # If weight_vector provided, return weighted mean
  if (!is.null(weight_vector)) {
    if (length(weight_vector) != length(composite_values)) {
      stop("weight_vector length doesn't match data rows")
    }
    return(weighted.mean(composite_values, w = weight_vector, na.rm = TRUE))
  }

  return(composite_values)
}

#' Process Composite Question
#'
#' Process one composite through the full crosstab pipeline
#'
#' @param composite_def Single row data frame with composite definition
#' @param data Survey data
#' @param questions_df Questions data frame
#' @param banner_info Banner structure
#' @param config Configuration list
#' @return List with question_table and metadata
#' @keywords internal
process_composite_question <- function(composite_def, data, questions_df,
                                       banner_info, config) {

  # Parse source questions
  source_questions <- strsplit(composite_def$SourceQuestions, ",")[[1]]
  source_questions <- trimws(source_questions)

  # Parse weights if WeightedMean
  calc_weights <- NULL
  calc_type <- if (!is.null(composite_def$CalculationType) && length(composite_def$CalculationType) > 0) {
    composite_def$CalculationType
  } else {
    "Mean"  # Default
  }

  if (!is.na(calc_type) && calc_type == "WeightedMean") {
    weights_str <- trimws(strsplit(composite_def$Weights, ",")[[1]])
    calc_weights <- as.numeric(weights_str)
  }

  # Get source question type
  first_source <- questions_df[questions_df$QuestionCode == source_questions[1], ]

  if (nrow(first_source) == 0) {
    stop(sprintf("Source question '%s' not found in questions_df", source_questions[1]))
  }

  source_type <- first_source$Variable_Type[1]

  # Determine row type based on source type
  if (source_type == "Rating") {
    row_type <- "Average"
  } else if (source_type == "Likert") {
    row_type <- "Index"
  } else if (source_type == "Numeric") {
    row_type <- "Average"
  } else {
    row_type <- "Score"
  }

  # Calculate composite values for each banner column
  banner_results <- list()
  internal_keys <- banner_info$internal_keys

  for (key in internal_keys) {
    # Get subset for this banner column
    subset_indices <- banner_info$subsets[[key]]

    # Handle NULL subsets - if NULL, need to calculate based on banner definition
    if (is.null(subset_indices) || length(subset_indices) == 0) {
      # For TOTAL column, use all rows
      if (grepl("^TOTAL::", key)) {
        subset_indices <- 1:nrow(data)
      } else {
        # For other banner columns, need to filter based on banner question
        # Extract banner question and value from key (format: "QuestionCode::Category::Value" or "QuestionCode::BOXCAT::Value")
        key_parts <- strsplit(key, "::")[[1]]
        if (length(key_parts) >= 2) {
          banner_question <- key_parts[1]
          # The actual value to match is the last part
          banner_value <- key_parts[length(key_parts)]

          # Check if banner question exists in data
          if (banner_question %in% names(data)) {
            # For BOXCAT or similar category columns, the data might contain the value directly
            # Match rows where the banner question equals the banner value
            subset_indices <- which(as.character(data[[banner_question]]) == banner_value)
          } else {
            # If banner question not in data, try looking for a column that matches the full key pattern
            # Some banners might use combined column names
            subset_indices <- integer(0)
          }
        } else {
          subset_indices <- 1:nrow(data)  # Default to all if can't parse
        }
      }
    }

    data_subset <- data[subset_indices, , drop = FALSE]

    # Get weights for this subset
    apply_weighting <- !is.null(config$apply_weighting) &&
                       length(config$apply_weighting) > 0 &&
                       config$apply_weighting
    has_weight_var <- !is.null(config$weight_variable) &&
                      length(config$weight_variable) > 0

    if (apply_weighting && has_weight_var) {
      survey_weights <- data_subset[[config$weight_variable]]
    } else {
      survey_weights <- rep(1, nrow(data_subset))
    }

    # Calculate composite value
    composite_value <- calculate_composite_values(
      data_subset = data_subset,
      source_questions = source_questions,
      calculation_type = calc_type,  # Use calc_type instead of composite_def$CalculationType
      weights = calc_weights,
      weight_vector = survey_weights
    )

    banner_results[[key]] <- composite_value
  }

  # Build output table
  comp_label <- if (!is.null(composite_def$CompositeLabel) &&
                    length(composite_def$CompositeLabel) > 0) {
    as.character(composite_def$CompositeLabel)
  } else {
    composite_def$CompositeCode
  }

  result_table <- data.frame(
    RowLabel = comp_label,
    RowType = row_type,
    stringsAsFactors = FALSE
  )

  # Add banner columns
  # Get decimal places safely for ratings
  decimal_places_ratings <- if (!is.null(config$decimal_places_ratings) &&
                                length(config$decimal_places_ratings) > 0) {
    config$decimal_places_ratings
  } else {
    1  # Default
  }

  # Get decimal separator
  decimal_sep <- if (!is.null(config$decimal_separator) &&
                     length(config$decimal_separator) > 0) {
    config$decimal_separator
  } else {
    "."
  }

  for (key in internal_keys) {
    raw_value <- banner_results[[key]]

    # Format the value
    # NOTE: Store as numeric (not string) so Excel writer can handle it properly
    # The Excel writer will apply the correct decimal separator formatting
    if (is.null(raw_value) || is.na(raw_value)) {
      formatted <- NA_real_
    } else {
      # Round to correct decimal places and keep as numeric
      formatted <- round(as.numeric(raw_value), decimal_places_ratings)
    }

    result_table[[key]] <- formatted
  }

  # Run significance testing if enabled
  enable_sig_testing <- !is.null(config$enable_significance_testing) &&
                        length(config$enable_significance_testing) > 0 &&
                        config$enable_significance_testing

  if (enable_sig_testing) {
    sig_row <- test_composite_significance(
      data = data,
      composite_code = composite_def$CompositeCode,
      source_questions = source_questions,
      calculation_type = calc_type,  # Use calc_type instead of composite_def$CalculationType
      calc_weights = calc_weights,
      banner_info = banner_info,
      config = config
    )

    if (!is.null(sig_row)) {
      result_table <- rbind(result_table, sig_row)
    }
  }

  return(list(
    question_table = result_table,
    metadata = list(
      composite_code = composite_def$CompositeCode,
      source_questions = source_questions,
      calculation_type = calc_type,  # Use calc_type instead of composite_def$CalculationType
      has_significance = enable_sig_testing
    )
  ))
}

#' Test Composite Significance
#'
#' Run significance testing for composite scores across banner columns
#'
#' @param data Survey data
#' @param composite_code Composite code
#' @param source_questions Source question codes
#' @param calculation_type Calculation type
#' @param calc_weights Calculation weights
#' @param banner_info Banner structure
#' @param config Configuration
#' @return Data frame with significance row or NULL
#' @keywords internal
test_composite_significance <- function(data, composite_code, source_questions,
                                        calculation_type, calc_weights,
                                        banner_info, config) {

  # Calculate composite values for full dataset (for variance calculation)
  composite_values <- calculate_composite_values(
    data_subset = data,
    source_questions = source_questions,
    calculation_type = calculation_type,
    weights = calc_weights,
    weight_vector = NULL  # Get vector, not mean
  )

  # Add to data temporarily
  data[[composite_code]] <- composite_values

  # Initialize significance row
  sig_row <- data.frame(
    RowLabel = "",
    RowType = "Sig.",
    stringsAsFactors = FALSE
  )

  internal_keys <- banner_info$internal_keys
  sig_letters <- setNames(rep("", length(internal_keys)), internal_keys)

  # Test each pair
  for (i in 1:(length(internal_keys) - 1)) {
    key_a <- internal_keys[i]

    for (j in (i + 1):length(internal_keys)) {
      key_b <- internal_keys[j]

      # Get subsets
      idx_a <- banner_info$subsets[[key_a]]
      idx_b <- banner_info$subsets[[key_b]]

      data_a <- data[idx_a, ]
      data_b <- data[idx_b, ]

      # Get weights
      apply_weighting <- !is.null(config$apply_weighting) && config$apply_weighting
      if (apply_weighting && !is.null(config$weight_variable)) {
        weights_a <- data_a[[config$weight_variable]]
        weights_b <- data_b[[config$weight_variable]]
      } else {
        weights_a <- rep(1, nrow(data_a))
        weights_b <- rep(1, nrow(data_b))
      }

      # Get composite values
      values_a <- data_a[[composite_code]]
      values_b <- data_b[[composite_code]]

      # Get sig test parameters safely
      alpha <- if (!is.null(config$alpha)) config$alpha else 0.05
      bonf_corr <- !is.null(config$bonferroni_correction) && config$bonferroni_correction

      # Test significance using t-test for means
      sig_result <- test_sig_mean(
        values_a = values_a,
        values_b = values_b,
        weights_a = weights_a,
        weights_b = weights_b,
        alpha = alpha,
        bonferroni_correction = bonf_corr,
        num_comparisons = choose(length(internal_keys), 2)
      )

      if (!is.null(sig_result) && sig_result$is_significant) {
        # A > B
        if (sig_result$direction == "A>B") {
          # Add B's letter to A's significance
          sig_letters[key_a] <- paste0(sig_letters[key_a],
                                       banner_info$sig_letters[key_b])
        } else if (sig_result$direction == "B>A") {
          # Add A's letter to B's significance
          sig_letters[key_b] <- paste0(sig_letters[key_b],
                                       banner_info$sig_letters[key_a])
        }
      }
    }
  }

  # Add sig letters to row
  for (key in internal_keys) {
    sig_row[[key]] <- sig_letters[key]
  }

  # Remove temporary column
  data[[composite_code]] <- NULL

  return(sig_row)
}

#' Process All Composites
#'
#' Process all composite definitions
#'
#' @param composite_defs Data frame of composite definitions
#' @param data Survey data
#' @param questions_df Questions data frame
#' @param banner_info Banner structure
#' @param config Configuration
#' @return List of composite results
#' @export
process_all_composites <- function(composite_defs, data, questions_df,
                                    banner_info, config) {

  if (is.null(composite_defs) || nrow(composite_defs) == 0) {
    return(list())
  }

  composite_results <- list()

  for (i in 1:nrow(composite_defs)) {
    composite_def <- composite_defs[i, ]
    comp_code <- if (!is.null(composite_def$CompositeCode)) {
      as.character(composite_def$CompositeCode)
    } else {
      sprintf("composite_%d", i)
    }

    tryCatch({
      message(sprintf("  Processing composite %d/%d: %s", i, nrow(composite_defs), comp_code))

      result <- process_composite_question(
        composite_def = composite_def,
        data = data,
        questions_df = questions_df,
        banner_info = banner_info,
        config = config
      )

      composite_results[[comp_code]] <- result
      message(sprintf("  ✓ Completed: %s", comp_code))

    }, error = function(e) {
      error_detail <- sprintf("Error processing composite '%s': %s\n  Traceback: %s",
                             comp_code, e$message,
                             paste(as.character(sys.calls()), collapse = "\n  "))
      warning(error_detail, call. = FALSE)
    })
  }

  return(composite_results)
}

message("[OK] Turas>Tabs composite_processor module loaded")
