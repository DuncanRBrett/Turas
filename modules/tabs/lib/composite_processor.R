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
#   - weighting.R (weighted_t_test_means for significance testing)
#   - shared_functions.R (utilities)
#
# VERSION: 1.0.1
# DATE: 2025-12-28
# V10.1 FIX: Changed from non-existent test_sig_mean to weighted_t_test_means
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
    tabs_refuse(
      code = "IO_FILE_NOT_FOUND",
      title = "Survey Structure File Not Found",
      problem = paste0("Survey structure file not found: ", survey_structure_file),
      why_it_matters = "Cannot load composite definitions without the Survey_Structure.xlsx file.",
      how_to_fix = c(
        "Verify the file path is correct",
        "Check that Survey_Structure.xlsx exists in the expected location"
      )
    )
  }

  # Check if Composite_Metrics sheet exists
  tryCatch({
    sheets <- readxl::excel_sheets(survey_structure_file)

    if (!"Composite_Metrics" %in% sheets) {
      # No composites defined - this is valid
      return(NULL)
    }

    # Read the sheet (auto-detect header row for template format)
    required_cols <- c("CompositeCode", "CompositeLabel", "CalculationType", "SourceQuestions")
    composite_defs <- .read_table_sheet(survey_structure_file, "Composite_Metrics",
                                         required_cols = required_cols)

    # Empty sheet — treat as no composites defined (not an error)
    if (nrow(composite_defs) == 0) {
      cat("  [INFO] Composite_Metrics sheet is empty - no composites to process\n")
      return(NULL)
    }

    # Validate required columns
    missing_cols <- setdiff(required_cols, names(composite_defs))

    if (length(missing_cols) > 0) {
      tabs_refuse(
        code = "CFG_MISSING_COLUMN",
        title = "Missing Columns in Composite_Metrics",
        problem = paste0("Composite_Metrics sheet missing required columns: ", paste(missing_cols, collapse = ", ")),
        why_it_matters = "These columns are required to define composite metrics properly.",
        how_to_fix = c(
          "Add the missing columns to the Composite_Metrics sheet",
          "Required columns: CompositeCode, CompositeLabel, CalculationType, SourceQuestions"
        )
      )
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

    # ExcludeFromSummary is a Y/N gate like the Selection and Options sheets', and
    # is normalised the same way (production review 2026-08, I12b). It used to be
    # read with a bare toupper(trimws(x)) == "Y" in summary_builder.R, so "Yes"
    # read as NO and a composite the operator asked to hide shipped to the client
    # anyway, without a word. Blank means include; anything unreadable refuses
    # here rather than silently publishing.
    if (!"ExcludeFromSummary" %in% names(composite_defs)) {
      composite_defs$ExcludeFromSummary <- NA_character_
    } else {
      composite_defs$ExcludeFromSummary <- normalise_flag_column(
        composite_defs$ExcludeFromSummary, "ExcludeFromSummary", "Composite_Metrics",
        default = "N", row_codes = composite_defs$CompositeCode)
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

    # If sheet becomes empty after cleaning blank rows, treat as no composites
    if (nrow(composite_defs) == 0) {
      cat("  [INFO] Composite_Metrics sheet has no valid definitions - no composites to process\n")
      return(NULL)
    }

    return(composite_defs)

  }, error = function(e) {
    # A TRS refusal raised INSIDE this block already names its own cause and fix —
    # re-signal it untouched. Wrapping it as a read error told an operator who had
    # typed an unreadable ExcludeFromSummary value to go looking for a corrupt
    # file (production review 2026-08, I12b).
    if (inherits(e, "turas_refusal")) stop(e)
    tabs_refuse(
      code = "IO_READ_ERROR",
      title = "Error Loading Composite_Metrics Sheet",
      problem = paste0("Error loading Composite_Metrics sheet: ", e$message),
      why_it_matters = "Cannot process composite metrics without successfully loading the sheet.",
      how_to_fix = c(
        "Verify the Excel file is not corrupted",
        "Check that the sheet name is 'Composite_Metrics' (case-sensitive)",
        "Ensure the file is not open in Excel"
      )
    )
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
  for (i in seq_len(nrow(composite_defs))) {
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

#' Score map for one composite source question: data value -> number
#'
#' A composite's sources are answers, and an answer is only sometimes a number.
#' A Likert stores words and carries its score in `Index_Weight`; a Rating or NPS
#' stores the point itself, with `OptionValue` as an override. Without this map
#' `calculate_composite_values()` coerces the raw column and a whole battery of
#' "TRUE"/"FALSE"/"Not sure" becomes NA — see its `options_df` note.
#'
#' Mirrors `derive_index_scores()` in score_utils.R (Rating -> option value,
#' Likert -> Index_Weight), but keys on OptionText, because that is what the data
#' holds. Options flagged `ExcludeFromIndex = Y` are dropped, as they are in
#' `calculate_rating_mean()`.
#'
#' @param q_code Source QuestionCode
#' @param questions_df Questions sheet
#' @param options_df Options sheet
#' @return Named numeric vector OptionText -> score, or NULL when the question
#'   has no usable option scoring (caller then coerces the raw column)
#' @keywords internal
composite_source_score_map <- function(q_code, questions_df, options_df) {
  if (is.null(questions_df) || is.null(options_df)) return(NULL)
  if (!all(c("QuestionCode", "OptionText") %in% names(options_df))) return(NULL)

  q_row <- questions_df[!is.na(questions_df$QuestionCode) &
                        questions_df$QuestionCode == q_code, , drop = FALSE]
  if (nrow(q_row) == 0) return(NULL)
  var_type <- as.character(q_row$Variable_Type[1])

  qopt <- options_df[!is.na(options_df$QuestionCode) &
                     options_df$QuestionCode == q_code, , drop = FALSE]
  if (nrow(qopt) == 0) return(NULL)
  if ("ExcludeFromIndex" %in% names(qopt)) {
    qopt <- qopt[is.na(qopt$ExcludeFromIndex) | qopt$ExcludeFromIndex != "Y", , drop = FALSE]
  }
  if (nrow(qopt) == 0) return(NULL)

  scores <- vapply(seq_len(nrow(qopt)), function(i) {
    row_i <- qopt[i, , drop = FALSE]
    if (identical(var_type, "Likert")) {
      iw <- if ("Index_Weight" %in% names(row_i)) row_i$Index_Weight else NA
      suppressWarnings(as.numeric(iw))
    } else {
      # Rating / NPS / Single_Response: OptionValue when present, else the
      # OptionText itself. option_numeric_value() is the canonical lookup
      # (score_utils.R) and is loaded by the time any composite runs.
      suppressWarnings(as.numeric(option_numeric_value(row_i)))
    }
  }, numeric(1))

  keys <- trimws(as.character(qopt$OptionText))
  keep <- !is.na(scores) & !is.na(keys) & nzchar(keys)
  if (!any(keep)) return(NULL)
  stats::setNames(scores[keep], keys[keep])
}


#' Calculate Composite Values
#'
#' Calculate composite score for respondent data.
#'
#' When `questions_df` and `options_df` are supplied, each source question's
#' answers are mapped through its Options (Index_Weight for a Likert, OptionValue
#' or OptionText for a Rating/NPS) before averaging. Without them the raw column
#' is coerced with `as.numeric()`, which is correct only for genuinely numeric
#' sources — a Likert holding words coerces to all-NA and the composite silently
#' becomes a blank cell.
#'
#' @param data_subset Survey data subset
#' @param source_questions Character vector of source question codes
#' @param calculation_type "Mean", "Sum", or "WeightedMean"
#' @param weights Numeric vector of calculation weights (for WeightedMean)
#' @param weight_vector Survey weights for this subset (optional)
#' @param questions_df Optional Questions sheet, for option-based scoring
#' @param options_df Optional Options sheet, for option-based scoring
#' @return Numeric: composite value (weighted mean if weight_vector provided, else vector)
#' @keywords internal
calculate_composite_values <- function(data_subset, source_questions,
                                       calculation_type, weights = NULL,
                                       weight_vector = NULL,
                                       questions_df = NULL, options_df = NULL) {

  # Validate calculation_type
  if (is.null(calculation_type) || length(calculation_type) == 0) {
    tabs_refuse(
      code = "ARG_MISSING_VALUE",
      title = "Missing Calculation Type",
      problem = "calculation_type cannot be NULL or empty.",
      why_it_matters = "Calculation type is required to determine how to compute the composite value.",
      how_to_fix = c(
        "Specify a CalculationType in the Composite_Metrics sheet",
        "Valid values: Mean, Sum, WeightedMean"
      )
    )
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

  # Sources that hold data but contribute nothing — the shape that used to ship
  # a blank composite without a word.
  unscored <- character(0)

  for (i in seq_along(source_questions)) {
    q_code <- source_questions[i]

    if (q_code %in% names(data_subset)) {
      raw <- data_subset[[q_code]]

      score_map <- composite_source_score_map(q_code, questions_df, options_df)
      values <- if (!is.null(score_map)) {
        unname(score_map[trimws(as.character(raw))])
      } else if (is.numeric(raw)) {
        raw
      } else {
        suppressWarnings(as.numeric(as.character(raw)))
      }

      has_data <- any(!is.na(raw) & nzchar(trimws(as.character(raw))))
      if (has_data && all(is.na(values))) unscored <- c(unscored, q_code)

      source_values_matrix[, i] <- values
    }
  }

  if (length(unscored) > 0) {
    cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
    cat("│ Context: composite metric — source question(s) scored nothing\n")
    cat("│ These sources hold answers, but not one of them could be\n")
    cat("│ turned into a number, so they contribute NOTHING to the\n")
    cat("│ composite (and if they are its only sources, the score is\n")
    cat("│ blank):\n")
    for (u in unscored) cat(sprintf("│   %s\n", u))
    cat("│ How to fix: a composite scores a Likert from Index_Weight and\n")
    cat("│ a Rating/NPS from OptionValue (else OptionText). Check the\n")
    cat("│ Options sheet defines those for these questions, and that\n")
    cat("│ OptionText matches the data exactly. A source whose answers\n")
    cat("│ are words with no Index_Weight cannot be averaged.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
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
      tabs_refuse(
        code = "ARG_MISSING_VALUE",
        title = "Missing Weights for WeightedMean",
        problem = "WeightedMean calculation type requires weights parameter.",
        why_it_matters = "Cannot calculate weighted mean without calculation weights.",
        how_to_fix = c(
          "Add Weights column to Composite_Metrics sheet",
          "Specify comma-separated weight values for each source question"
        )
      )
    }

    for (i in seq_len(nrow(source_values_matrix))) {
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
      tabs_refuse(
        code = "DATA_LENGTH_MISMATCH",
        title = "Weight Vector Length Mismatch",
        problem = "weight_vector length doesn't match data rows.",
        why_it_matters = "Survey weights must match the number of data rows for proper weighted analysis.",
        how_to_fix = "This is an internal error - check weight extraction logic"
      )
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
#' @param options_df Options sheet, so worded sources are scored through their
#'   Options rather than coerced raw. Omit only for genuinely numeric sources.
#' @return List with question_table and metadata
#' @keywords internal
process_composite_question <- function(composite_def, data, questions_df,
                                       banner_info, config, options_df = NULL) {

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
    tabs_refuse(
      code = "CFG_QUESTION_NOT_FOUND",
      title = "Composite Source Question Not Found",
      problem = sprintf("Source question '%s' not found in questions_df.", source_questions[1]),
      why_it_matters = "All source questions must exist in Survey_Structure for composite calculation.",
      how_to_fix = c(
        "Check that the source question code exists in the Questions sheet",
        "Verify spelling and case sensitivity of QuestionCode"
      )
    )
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
        subset_indices <- seq_len(nrow(data))
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
          subset_indices <- seq_len(nrow(data))  # Default to all if can't parse
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

    # Calculate composite value. questions_df/options_df let the sources be
    # scored through their Options (Index_Weight for a Likert, OptionValue for a
    # Rating) instead of coerced raw — without them a battery of worded answers
    # averages to NA and the composite ships blank.
    composite_value <- calculate_composite_values(
      data_subset = data_subset,
      source_questions = source_questions,
      calculation_type = calc_type,  # Use calc_type instead of composite_def$CalculationType
      weights = calc_weights,
      weight_vector = survey_weights,
      questions_df = questions_df,
      options_df = options_df
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

  # Tag as composite for downstream classification
  result_table$RowSource <- "composite"

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
      config = config,
      questions_df = questions_df,
      options_df = options_df
    )

    if (!is.null(sig_row)) {
      result_table <- rbind(result_table, sig_row)
    }
  }

  # The composite's OWN per-column bases, so the Index_Summary's disclosure gate
  # judges on the people actually in this composite rather than borrowing the
  # first source question's bases (production review 2026-08, M-K). Sources can
  # be routed differently — one asked of everyone, another of a sub-audience —
  # in which case the borrowed base named the wrong column as sub-k, withholding
  # a safe column or, worse, publishing a withheld one.
  comp_bases <- tryCatch(
    composite_column_bases(
      calculate_composite_values(
        data_subset = data, source_questions = source_questions,
        calculation_type = calc_type, weights = calc_weights,
        weight_vector = NULL, questions_df = questions_df,
        options_df = options_df),
      data, banner_info),
    error = function(e) NULL)

  return(list(
    question_table = result_table,
    bases = comp_bases,
    metadata = list(
      composite_code = composite_def$CompositeCode,
      source_questions = source_questions,
      calculation_type = calc_type,  # Use calc_type instead of composite_def$CalculationType
      has_significance = enable_sig_testing
    )
  ))
}

#' Row indices for one banner column, for composite testing
#'
#' \code{banner_info$subsets} is the fast path; when it carries no entry for a
#' key (or an empty one) the key is parsed back to its banner question and value
#' and the rows are found in the data — the same fallback the main composite
#' calculation uses. Extracted so the per-column bases the finite population
#' correction is built from and the rows each pairwise test reads are resolved
#' by one piece of code rather than two copies.
#'
#' @param banner_info List, banner structure
#' @param data Data frame, survey data (with the composite column attached)
#' @param key Character, one internal banner key

#' The composite's own per-column unweighted base
#'
#' Respondents in the column who have a scoreable composite value. This is the
#' base the finite population correction reads and — since M-K — the base the
#' Index_Summary's disclosure gate reads, so the two cannot disagree about who
#' is in a column.
#'
#' @param values Per-respondent composite values over the FULL data frame
#' @param data The full survey data (row order matches \code{values})
#' @param banner_info Banner structure
#' @return Named list, one \code{list(unweighted = n)} per internal key
#' @keywords internal
composite_column_bases <- function(values, data, banner_info) {
  keys <- banner_info$internal_keys
  stats::setNames(lapply(keys, function(k) {
    idx <- composite_subset_indices(banner_info, data, k)
    list(unweighted = sum(!is.na(values[idx])))
  }), keys)
}

#' @return Integer vector of row indices (possibly empty)
#' @keywords internal
composite_subset_indices <- function(banner_info, data, key) {
  idx <- banner_info$subsets[[key]]
  if (!is.null(idx) && length(idx) > 0) return(idx)

  if (grepl("^TOTAL::", key)) return(seq_len(nrow(data)))

  key_parts <- strsplit(key, "::")[[1]]
  if (length(key_parts) < 2) return(seq_len(nrow(data)))

  banner_question <- key_parts[1]
  banner_value <- key_parts[length(key_parts)]
  if (!banner_question %in% names(data)) return(integer(0))
  which(as.character(data[[banner_question]]) == banner_value)
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
#' @param questions_df Optional Questions sheet, for option-based scoring
#' @param options_df Optional Options sheet, for option-based scoring
#' @return Data frame with significance row or NULL
#' @keywords internal
test_composite_significance <- function(data, composite_code, source_questions,
                                        calculation_type, calc_weights,
                                        banner_info, config,
                                        questions_df = NULL, options_df = NULL) {

  # Calculate composite values for full dataset (for variance calculation).
  # These MUST be scored the same way the published value was — pass the
  # structure through, or a worded source yields all-NA here and the composite
  # is significance-tested against nothing while its printed value is fine.
  composite_values <- calculate_composite_values(
    data_subset = data,
    source_questions = source_questions,
    calculation_type = calculation_type,
    weights = calc_weights,
    weight_vector = NULL,  # Get vector, not mean
    questions_df = questions_df,
    options_df = options_df
  )

  # Add to data temporarily
  data[[composite_code]] <- composite_values

  # Initialize significance row
  sig_row <- data.frame(
    RowLabel = "",
    RowType = "Sig.",
    stringsAsFactors = FALSE
  )

  # Tag as composite for downstream classification
  sig_row$RowSource <- "composite"

  internal_keys <- banner_info$internal_keys
  sig_letters <- setNames(rep("", length(internal_keys)), internal_keys)

  # V10.8: Build key → letter lookup from parallel vectors.
  # banner_info$sig_letters does not exist; use banner_info$letters.
  key_to_letter <- setNames(banner_info$letters, internal_keys)

  # Pairwise tests are only valid WITHIN a banner group: column letters restart
  # per group (A, B, C… in each), so a cross-group letter is ambiguous, and the
  # Total column overlaps every other column (never a disjoint comparison).
  # The Bonferroni divisor is per group, mirroring the regular category rows.
  key_banner <- vapply(
    strsplit(internal_keys, "::", fixed = TRUE),
    function(parts) parts[1],
    character(1)
  )
  names(key_banner) <- internal_keys
  group_sizes <- table(key_banner[key_banner != "TOTAL"])

  # Row indices for every banner column, resolved once. Same fallback the main
  # composite calculation uses when banner_info$subsets has no entry for a key.
  key_indices <- setNames(
    lapply(internal_keys, function(k) composite_subset_indices(banner_info, data, k)),
    internal_keys
  )

  # Finite population correction, per banner column (review 2026-08, I5).
  # A composite is a mean row sitting among category rows that are already
  # corrected; before this it was the one row on a census table that kept its
  # letters. n_actual is this composite's own UNWEIGHTED base in the column —
  # respondents with a scoreable composite value — matching the definition
  # build_fpc_multipliers() documents for every other row type. All-1 (inert)
  # with no universe configured, so non-population reports are unchanged.
  composite_bases <- composite_column_bases(composite_values, data, banner_info)
  fpc_muls <- build_fpc_multipliers(
    composite_bases, resolve_column_populations(banner_info, config), internal_keys)

  # Test each within-group pair (skip if fewer than 2 keys)
  n_keys <- length(internal_keys)
  for (i in seq_len(max(0L, n_keys - 1L))) {
    key_a <- internal_keys[i]

    for (j in (i + 1L):n_keys) {
      key_b <- internal_keys[j]

      # Same banner group only; Total is never a test column
      group_a <- key_banner[[key_a]]
      if (group_a == "TOTAL" || !identical(group_a, key_banner[[key_b]])) {
        next
      }

      # Get subsets - handle NULL subsets like main calculation does.
      # Resolved once per key above, so the bases the FPC is built from and the
      # rows the test reads can never be two different sets of respondents.
      idx_a <- key_indices[[key_a]]
      idx_b <- key_indices[[key_b]]

      # Skip comparison if either subset is empty
      if (length(idx_a) == 0 || length(idx_b) == 0) {
        next
      }

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
      min_base <- if (!is.null(config$significance_min_base)) config$significance_min_base else 30

      # Apply Bonferroni correction if enabled — divided by this banner GROUP's
      # comparison count, the same divisor the regular category rows use, so a
      # composite row and the rows above it letter at the same adjusted alpha
      test_alpha <- if (bonf_corr) {
        alpha / choose(as.integer(group_sizes[[group_a]]), 2)
      } else {
        alpha
      }

      # Test significance using weighted t-test for means
      # V10.1 FIX: Use weighted_t_test_means instead of non-existent test_sig_mean
      sig_result <- weighted_t_test_means(
        values1 = values_a,
        values2 = values_b,
        weights1 = weights_a,
        weights2 = weights_b,
        min_base = min_base,
        alpha = test_alpha,
        fpc_mul1 = if (key_a %in% names(fpc_muls)) unname(fpc_muls[[key_a]]) else 1,
        fpc_mul2 = if (key_b %in% names(fpc_muls)) unname(fpc_muls[[key_b]]) else 1
      )

      if (!is.null(sig_result) && sig_result$significant) {
        # Determine direction: higher=TRUE means values1 > values2 (A > B)
        if (sig_result$higher) {
          # A > B: Add B's letter to A's significance
          sig_letters[key_a] <- paste0(sig_letters[key_a],
                                       key_to_letter[key_b])
        } else {
          # B > A: Add A's letter to B's significance
          sig_letters[key_b] <- paste0(sig_letters[key_b],
                                       key_to_letter[key_a])
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
#' @param options_df Options sheet, so worded sources are scored through their
#'   Options rather than coerced raw. Omit only for genuinely numeric sources.
#' @return List of composite results
#' @export
process_all_composites <- function(composite_defs, data, questions_df,
                                    banner_info, config, options_df = NULL) {

  if (is.null(composite_defs) || nrow(composite_defs) == 0) {
    return(list())
  }

  composite_results <- list()

  for (i in seq_len(nrow(composite_defs))) {
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
        config = config,
        options_df = options_df
      )

      composite_results[[comp_code]] <- result
      message(sprintf("  ✓ Completed: %s", comp_code))

    }, error = function(e) {
      # A composite is a contractual metric: an error must not demote to a
      # one-line warning while the run stays PASS (review 2026-08, I12). Box it
      # for the Shiny console and record a REFUSED entry — the analysis runner
      # turns any such entry into run_status PARTIAL.
      cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
      cat("│ Context: Composite processing\n")
      cat("│ Code: CALC_COMPOSITE_FAILED\n")
      cat(sprintf("│ Composite: %s\n", comp_code))
      cat(sprintf("│ Message: %s\n", e$message))
      cat("│ Consequence: this composite is ABSENT from every output sheet.\n")
      cat("│ How to fix: check its definition and source questions, then re-run.\n")
      cat("└───────────────────────────────────────────────────────┘\n\n")
      composite_results[[comp_code]] <<- list(
        status = "REFUSED", code = "CALC_COMPOSITE_FAILED",
        message = e$message, question_table = NULL
      )
    })
  }

  return(composite_results)
}

#' Provenance for a Composite, From Its Own Definition
#'
#' A composite is the one derived question the engine builds itself, so unlike
#' a column worked out before the data arrived it has nothing to declare: the
#' Composite_Metrics sheet has already said which questions feed it and how
#' they combine. This turns that definition into the two sentences the report
#' shows on the question card, so a composite is never the one obviously
#' calculated figure on the page with nothing said about it.
#'
#' The Selection sheet still wins per field — see add_composites_to_results().
#'
#' @param composite_def One-row data frame from the Composite_Metrics sheet.
#'
#' @return A list with structure:
#'   \item{source}{The source question codes, comma separated; "" if unknown}
#'   \item{formula}{How they combine, in plain words; "" if unknown}
#'
#' @examples
#' \dontrun{
#'   composite_provenance(defs[1, ])
#'   # $source  "Q01, Q02, Q03"
#'   # $formula "mean of the 3 source questions"
#' }
#'
#' @export
composite_provenance <- function(composite_def) {
  blank <- list(source = "", formula = "")
  if (is.null(composite_def) || !is.data.frame(composite_def) ||
      nrow(composite_def) == 0 || !"SourceQuestions" %in% names(composite_def)) {
    return(blank)
  }

  sq <- composite_def$SourceQuestions[1]
  if (is.null(sq) || length(sq) == 0 || is.na(sq)) return(blank)
  codes <- trimws(strsplit(as.character(sq), ",")[[1]])
  codes <- codes[nzchar(codes)]
  if (length(codes) == 0) return(blank)

  n <- length(codes)
  noun <- sprintf("%d source question%s", n, if (n == 1) "" else "s")

  calc <- if ("CalculationType" %in% names(composite_def) &&
              !is.na(composite_def$CalculationType[1])) {
    trimws(as.character(composite_def$CalculationType[1]))
  } else {
    ""
  }

  # The weights only join the sentence when they parse and there is one per
  # source question — a half-read weight list would describe a calculation the
  # engine did not do.
  weight_note <- ""
  if (identical(tolower(calc), "weightedmean") && "Weights" %in% names(composite_def) &&
      !is.na(composite_def$Weights[1])) {
    w <- suppressWarnings(as.numeric(trimws(strsplit(as.character(composite_def$Weights[1]), ",")[[1]])))
    if (length(w) == n && !any(is.na(w))) {
      weight_note <- sprintf(" (weights %s)", paste(format(w, trim = TRUE), collapse = ", "))
    }
  }

  formula <- if (identical(tolower(calc), "mean")) {
    sprintf("mean of the %s", noun)
  } else if (identical(tolower(calc), "sum")) {
    sprintf("sum of the %s", noun)
  } else if (identical(tolower(calc), "weightedmean")) {
    sprintf("weighted mean of the %s%s", noun, weight_note)
  } else if (nzchar(calc)) {
    # An unrecognised type is the analyst's word, used verbatim rather than
    # guessed at — the validator is what rejects a type the engine cannot run.
    sprintf("%s of the %s", calc, noun)
  } else {
    sprintf("combined from the %s", noun)
  }

  list(source = paste(codes, collapse = ", "), formula = formula)
}

message("[OK] Turas>Tabs composite_processor module loaded")
