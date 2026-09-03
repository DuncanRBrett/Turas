# ==============================================================================
# PREFLIGHT VALIDATORS - V10.3
# ==============================================================================
# Cross-referential validation between config, structure, and data files
# Catches configuration mistakes before analysis begins
#
# VERSION HISTORY:
# V10.3 - Initial creation (2026-03-08)
#        - 12 cross-referential checks
#        - Integrates into run_all_validations() pipeline
#
# DEPENDENCIES (must be loaded before this file):
# - log_issue() from logging_utils.R
# - get_config_value() from config_utils.R
# - safe_logical() from type_utils.R
# - tabs_refuse() from 00_guard.R
#
# USAGE:
# These functions are sourced by validation.R using:
#   tabs_source("validation", "preflight_validators.R")
#
# FUNCTIONS EXPORTED:
# - check_selection_vs_questions() - Selection↔Questions cross-check
# - check_option_values_vs_data() - Option values in data
# - check_preflight_multi_mention() - Multi_Mention binary columns
# - check_numeric_data_types() - Numeric question data types
# - check_create_index_config() - CreateIndex+Index_Weight consistency
# - check_banner_variables() - Banner variable existence in data
# - check_conflicting_display() - Conflicting display settings
# - check_preflight_weight_variable() - Weight variable in data
# - check_duplicate_options() - Duplicate option codes
# - check_open_end_selection() - Open_End questions selected
# - check_base_filter_variables() - Base filter column existence
# - check_data_column_coverage() - Data columns for selected questions
# - validate_preflight() - Main orchestrator function
# ==============================================================================


# ==============================================================================
# PREFLIGHT CHECK FUNCTIONS
# ==============================================================================

#' Check Selection vs Questions cross-reference
#'
#' Verifies every selected question exists in the Questions sheet and
#' warns about defined questions not in Selection.
#'
#' @param selection_df Data frame, Selection sheet
#' @param questions_df Data frame, Questions sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_selection_vs_questions <- function(selection_df, questions_df, error_log) {
  sel_codes <- unique(selection_df$QuestionCode)
  q_codes <- unique(questions_df$QuestionCode)

  # "Total" is a magic banner code that the tabs engine produces internally,
  # the standard Crosstab_Config template ships with it on row 5 of Selection.
  # It must NOT be required to also appear in the Survey_Structure Questions
  # sheet, otherwise every freshly-generated config fails preflight.
  TABS_MAGIC_BANNER_CODES <- c("Total")

  # Selected questions not in structure (critical - will fail at runtime)
  missing_in_structure <- setdiff(sel_codes, c(q_codes, TABS_MAGIC_BANNER_CODES))
  if (length(missing_in_structure) > 0) {
    error_log <- log_issue(
      error_log, "Preflight", "Selection/Structure Mismatch",
      sprintf("Selection sheet references %d question(s) not found in Survey_Structure Questions sheet: %s",
              length(missing_in_structure),
              paste(missing_in_structure, collapse = ", ")),
      paste(missing_in_structure, collapse = ", "),
      "Error"
    )
  }

  # Questions defined but not in Selection (may be intentional, but worth flagging)
  not_in_selection <- setdiff(q_codes, sel_codes)
  if (length(not_in_selection) > 0) {
    error_log <- log_issue(
      error_log, "Preflight", "Questions Not in Selection",
      sprintf("%d question(s) defined in Survey_Structure but absent from Selection sheet: %s. If intentional, ignore this warning.",
              length(not_in_selection),
              paste(not_in_selection, collapse = ", ")),
      "",
      "Warning"
    )
  }

  return(error_log)
}


#' Check option values vs actual data
#'
#' For Single/Likert questions, verifies option values match data values.
#'
#' @param questions_df Data frame, Questions sheet
#' @param options_df Data frame, Options sheet
#' @param survey_data Data frame, survey data
#' @param selection_df Data frame, Selection sheet (only check selected questions)
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_option_values_vs_data <- function(questions_df, options_df, survey_data,
                                         selection_df, error_log) {
  # Only check included questions
  included_codes <- selection_df$QuestionCode[selection_df$Include == "Y"]

  # Get questions with discrete options to check
  checkable_types <- c("Single", "Single_Response", "Likert", "Rating", "NPS")
  check_questions <- questions_df[
    questions_df$QuestionCode %in% included_codes &
    questions_df$Variable_Type %in% checkable_types, ]

  if (nrow(check_questions) == 0) return(error_log)

  for (i in seq_len(nrow(check_questions))) {
    q_code <- check_questions$QuestionCode[i]
    # Data column name = QuestionCode (Columns field is a count, not a name)
    col_name <- q_code

    # Skip if column doesn't exist (caught by check_data_column_coverage)
    if (!col_name %in% names(survey_data)) next

    # Get defined option values
    q_options <- options_df[options_df$QuestionCode == q_code, ]
    if (nrow(q_options) == 0) next

    # Which column holds the value the DATA is supposed to match?
    #
    # OptionText is the answer, by definition ("EXACT value from data file").
    # OptionCode and OptionValue are alternative codings that only SOMETIMES
    # carry it. OptionValue in particular is the numeric a mean is computed
    # from, and on a Likert it routinely holds the scale position 1..5 while the
    # data holds the words. Preferring it there made every real answer read as
    # undefined and every option as unused: 53 spurious warnings on one study,
    # loud enough to bury a true one.
    #
    # So collect every candidate coding and treat a data value as defined if it
    # matches ANY of them. A value the config genuinely never declares still
    # matches none, and is still reported.
    candidate_cols <- intersect(c("OptionCode", "OptionValue", "OptionText"),
                                names(q_options))
    defined_by_col <- list()
    for (cc in candidate_cols) {
      v <- as.character(q_options[[cc]])
      v <- v[!is.na(v) & v != ""]
      if (length(v) > 0) defined_by_col[[cc]] <- v
    }
    if (length(defined_by_col) == 0) next

    defined_values <- unique(unlist(defined_by_col, use.names = FALSE))

    # Get actual data values (non-NA)
    data_values <- as.character(survey_data[[col_name]])
    data_values <- unique(data_values[!is.na(data_values) & data_values != ""])

    if (length(data_values) == 0 || length(defined_values) == 0) next

    # "Unused" is only meaningful against the coding the data actually speaks,
    # reporting the unmatched 1..5 of a Likert's OptionValue alongside its
    # matched labels would reinstate half the noise. Pick the candidate that
    # covers the most of the data and judge unused options against that one.
    coverage <- vapply(defined_by_col,
                       function(v) sum(data_values %in% v), integer(1))
    matched_col <- names(coverage)[which.max(coverage)]
    unused_pool <- defined_by_col[[matched_col]]

    # Data values not in options (missing option definitions)
    missing_opts <- setdiff(data_values, defined_values)
    if (length(missing_opts) > 0) {
      error_log <- log_issue(
        error_log, "Preflight", "Undefined Data Values",
        sprintf("Question '%s': data contains %d value(s) not defined in Options: %s",
                q_code, length(missing_opts),
                paste(utils::head(missing_opts, 5), collapse = ", ")),
        q_code,
        "Warning"
      )
    }

    # Defined options not in data (possibly unused codes).
    #
    # Absence only means something when the option had a fair chance of being
    # picked. On a pilot export an unused scale point is arithmetic, not a
    # config error, and reporting one per question buries the warnings that
    # matter. Gate on the conventional expected-cell floor of 5: with a base of
    # n spread over k options, an option is expected about n/k times, so below
    # 5 the check is uninformative and stays quiet. The Undefined check above is
    # NOT gated. A value the config cannot describe is a fault at any base.
    answered_base <- sum(!is.na(survey_data[[col_name]]) &
                         trimws(as.character(survey_data[[col_name]])) != "")
    expected_per_option <- answered_base / max(length(unused_pool), 1L)

    unused_opts <- setdiff(unused_pool, data_values)
    if (length(unused_opts) > 0 && expected_per_option >= 5) {
      error_log <- log_issue(
        error_log, "Preflight", "Unused Option Values",
        sprintf("Question '%s': %d option value(s) defined but never occur in data: %s",
                q_code, length(unused_opts),
                paste(utils::head(unused_opts, 5), collapse = ", ")),
        q_code,
        "Warning"
      )
    }
  }

  return(error_log)
}


#' Check Multi_Mention column verification
#'
#' Verifies all expected binary columns exist for Multi_Mention questions.
#'
#' @param questions_df Data frame, Questions sheet
#' @param survey_data Data frame, survey data
#' @param selection_df Data frame, Selection sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_preflight_multi_mention <- function(questions_df, survey_data, selection_df,
                                           error_log) {
  included_codes <- selection_df$QuestionCode[selection_df$Include == "Y"]

  mm_questions <- questions_df[
    questions_df$QuestionCode %in% included_codes &
    questions_df$Variable_Type == "Multi_Mention", ]

  if (nrow(mm_questions) == 0) return(error_log)

  data_cols <- names(survey_data)

  for (i in seq_len(nrow(mm_questions))) {
    q_code <- mm_questions$QuestionCode[i]
    num_columns <- suppressWarnings(as.numeric(mm_questions$Columns[i]))

    if (is.na(num_columns) || num_columns < 1) next

    # Multi_Mention columns follow pattern: QuestionCode_1, QuestionCode_2, ...
    expected_cols <- paste0(q_code, "_", seq_len(num_columns))

    # Check each expected column exists
    missing_cols <- setdiff(expected_cols, data_cols)
    if (length(missing_cols) > 0) {
      # Also check if ANY columns with this prefix exist
      prefix_pattern <- paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", q_code), "_")
      actual_matches <- data_cols[grepl(prefix_pattern, data_cols)]

      if (length(actual_matches) == 0) {
        error_log <- log_issue(
          error_log, "Preflight", "Missing Multi_Mention Columns",
          sprintf("Question '%s': no data columns found matching pattern '%s_*'",
                  q_code, q_code),
          q_code,
          "Error"
        )
      } else if (length(missing_cols) > 0) {
        error_log <- log_issue(
          error_log, "Preflight", "Missing Multi_Mention Columns",
          sprintf("Question '%s': expected %d columns but found %d. Missing: %s",
                  q_code, num_columns, length(actual_matches),
                  paste(utils::head(missing_cols, 5), collapse = ", ")),
          q_code,
          "Warning"
        )
      }
    }

    # Check data format for existing columns (binary 0/1 or text-in-column)
    # Both formats are valid:
    #   - Binary: 0/1 values (standard)
    #   - Text-in-column: option text if selected, NA/blank if not (Alchemer export format)
    # The cell calculator handles both via safe_equal() matching.
    # Only log once per question (not per column) as an informational note.
    existing_cols <- intersect(expected_cols, data_cols)
    if (length(existing_cols) > 0) {
      first_col <- existing_cols[1]
      vals <- survey_data[[first_col]]
      vals <- vals[!is.na(vals)]
      if (length(vals) > 0) {
        non_binary <- vals[!vals %in% c(0, 1, "0", "1")]
        if (length(non_binary) > 0) {
          error_log <- log_issue(
            error_log, "Preflight", "Text-Based Multi_Mention Format",
            sprintf("Question '%s': uses text-in-column format (e.g. '%s'). This is supported.",
                    q_code, utils::head(unique(non_binary), 1)),
            q_code,
            "Note"
          )
        }
      }
    }
  }

  return(error_log)
}


#' Check Numeric question data types
#'
#' Verifies Numeric variable type questions have actual numeric data.
#'
#' @param questions_df Data frame, Questions sheet
#' @param survey_data Data frame, survey data
#' @param selection_df Data frame, Selection sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_numeric_data_types <- function(questions_df, survey_data, selection_df,
                                      error_log) {
  included_codes <- selection_df$QuestionCode[selection_df$Include == "Y"]

  numeric_questions <- questions_df[
    questions_df$QuestionCode %in% included_codes &
    questions_df$Variable_Type == "Numeric", ]

  if (nrow(numeric_questions) == 0) return(error_log)

  for (i in seq_len(nrow(numeric_questions))) {
    q_code <- numeric_questions$QuestionCode[i]
    # Data column name = QuestionCode
    col_name <- q_code

    if (!col_name %in% names(survey_data)) next

    vals <- survey_data[[col_name]]
    vals <- vals[!is.na(vals)]

    if (length(vals) == 0) next

    # Try numeric conversion
    numeric_vals <- suppressWarnings(as.numeric(vals))
    n_non_numeric <- sum(is.na(numeric_vals))
    pct_non_numeric <- round(100 * n_non_numeric / length(vals), 1)

    if (pct_non_numeric > 10) {
      error_log <- log_issue(
        error_log, "Preflight", "Non-Numeric Data",
        sprintf("Question '%s' (Variable_Type=Numeric) has %.1f%% non-numeric values in column '%s'",
                q_code, pct_non_numeric, col_name),
        q_code,
        "Warning"
      )
    }
  }

  return(error_log)
}


#' Message for a Rating question flagged by the CreateIndex check
#'
#' Rating questions get their summary row from calculate_rating_mean(), which
#' scores each response from OptionValue (falling back to a numeric OptionText)
#' and never reads Index_Weight. The warning therefore points at the columns
#' that actually decide whether a mean row appears.
#'
#' @param q_code Character, the question code
#' @return Character, the warning message
#' @keywords internal
rating_index_message <- function(q_code) {
  sprintf(
    "Question '%s' (Variable_Type=Rating) has CreateIndex=Y. Rating means are scored from OptionValue (or a numeric OptionText), not Index_Weight, so the missing Index_Weight does not affect this question. If its options carry no numeric OptionValue or OptionText, no mean row will be produced and the question will be missing from the crosstab, from the report, and from the Patterns scan of rated questions.",
    q_code
  )
}


#' Check CreateIndex without Index_Weight
#'
#' Warns if CreateIndex=Y but no Index_Weight is specified in the Options sheet
#' of the Survey Structure. Index_Weight belongs with options because each option
#' within a question can have a different weight for index calculation.
#'
#' Ranking and NPS questions are skipped (Index_Weight does not apply to them),
#' and Rating questions get a message naming OptionValue/OptionText, because
#' their mean is scored from those columns rather than from Index_Weight.
#'
#' @param selection_df Data frame, Selection sheet (has CreateIndex flag)
#' @param options_df Data frame, Options sheet from Survey Structure (has Index_Weight)
#' @param error_log Data frame, error log
#' @param questions_df Data frame, Questions sheet (supplies Variable_Type); when
#'   NULL every flagged question gets the Likert/index wording
#' @return Updated error_log
#' @keywords internal
check_create_index_config <- function(selection_df, options_df, error_log,
                                      questions_df = NULL) {
  index_questions <- selection_df[
    !is.na(selection_df$CreateIndex) &
    toupper(selection_df$CreateIndex) == "Y", ]

  if (nrow(index_questions) == 0) return(error_log)

  has_weight_col <- "Index_Weight" %in% names(options_df)

  for (i in seq_len(nrow(index_questions))) {
    q_code <- index_questions$QuestionCode[i]

    # Skip question types where Index_Weight doesn't apply
    var_type <- NA_character_
    if (!is.null(questions_df)) {
      q_row <- questions_df[questions_df$QuestionCode == q_code, ]
      if (nrow(q_row) > 0) {
        var_type <- as.character(q_row$Variable_Type[1])
        if (!is.na(var_type) && var_type %in% c("Ranking", "NPS")) {
          next
        }
      }
    }

    # Rating questions score their summary row from OptionValue (falling back
    # to a numeric OptionText). calculate_rating_mean() never reads
    # Index_Weight, so name the columns that actually drive the mean.
    is_rating <- !is.na(var_type) && var_type == "Rating"

    if (!has_weight_col) {
      error_log <- log_issue(
        error_log, "Preflight", "Missing Index Weight",
        if (is_rating) rating_index_message(q_code) else
          sprintf("Question '%s' has CreateIndex=Y but Options sheet has no Index_Weight column. No index row will be produced for this question: it will be missing from the crosstab, from the report, and from the Patterns scan of rated questions. Add an Index_Weight column to the Options sheet and give each option a weight.",
                  q_code),
        q_code,
        "Warning"
      )
      next
    }

    # Check options for this question have Index_Weight values
    q_options <- options_df[options_df$QuestionCode == q_code, ]
    if (nrow(q_options) == 0) {
      # Multi_Mention options use column codes (Q01_1, Q01_2, etc.)
      pattern <- paste0("^", q_code, "_")
      q_options <- options_df[grepl(pattern, options_df$QuestionCode), ]
    }

    if (nrow(q_options) == 0 ||
        all(is.na(q_options$Index_Weight)) ||
        all(trimws(as.character(q_options$Index_Weight)) == "")) {
      error_log <- log_issue(
        error_log, "Preflight", "Missing Index Weight",
        if (is_rating) rating_index_message(q_code) else
          sprintf("Question '%s' has CreateIndex=Y but no Index_Weight specified in Options. No index row will be produced for this question: it will be missing from the crosstab, from the report, and from the Patterns scan of rated questions. Give each option in the Options sheet an Index_Weight.",
                  q_code),
        q_code,
        "Warning"
      )
    }
  }

  return(error_log)
}


#' Check banner variables exist in data
#'
#' Verifies banner questions exist in both structure and data.
#'
#' @param selection_df Data frame, Selection sheet
#' @param questions_df Data frame, Questions sheet
#' @param survey_data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_banner_variables <- function(selection_df, questions_df, survey_data,
                                    error_log) {
  banner_questions <- selection_df[
    !is.na(selection_df$UseBanner) &
    toupper(selection_df$UseBanner) == "Y", ]

  if (nrow(banner_questions) == 0) {
    error_log <- log_issue(
      error_log, "Preflight", "No Banner Questions",
      "No questions have UseBanner=Y. Analysis will only produce a Total column.",
      "",
      "Warning"
    )
    return(error_log)
  }

  q_codes <- unique(questions_df$QuestionCode)
  data_cols <- names(survey_data)

  for (i in seq_len(nrow(banner_questions))) {
    q_code <- banner_questions$QuestionCode[i]

    # Check question exists in structure
    if (!q_code %in% q_codes) {
      error_log <- log_issue(
        error_log, "Preflight", "Banner Question Not Found",
        sprintf("Banner question '%s' not found in Survey_Structure Questions sheet.",
                q_code),
        q_code,
        "Error"
      )
      next
    }

    # Get the variable type for this question
    q_row <- questions_df[questions_df$QuestionCode == q_code, ]
    var_type <- q_row$Variable_Type[1]

    if (var_type != "Multi_Mention") {
      # Single column questions: data column name = QuestionCode
      if (!q_code %in% data_cols) {
        error_log <- log_issue(
          error_log, "Preflight", "Missing Banner Data Column",
          sprintf("Banner question '%s' not found as a column in data.", q_code),
          q_code,
          "Error"
        )
      }
    }
  }

  return(error_log)
}


#' Check for conflicting display settings
#'
#' Detects logically contradictory config settings.
#'
#' @param config List, configuration object
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_conflicting_display <- function(config, error_log) {
  # Check if all display metrics are disabled
  show_freq <- isTRUE(config$show_frequency)
  show_pct_col <- isTRUE(config$show_percent_column)
  show_pct_row <- isTRUE(config$show_percent_row)

  if (!show_freq && !show_pct_col && !show_pct_row) {
    error_log <- log_issue(
      error_log, "Preflight", "No Display Metrics Enabled",
      "show_frequency, show_percent_column, and show_percent_row are all FALSE. Crosstabs will have no visible data.",
      "",
      "Warning"
    )
  }

  # Significance testing without percentages
  if (isTRUE(config$enable_significance_testing) && !show_pct_col) {
    error_log <- log_issue(
      error_log, "Preflight", "Significance Without Percentages",
      "Significance testing is enabled but show_percent_column is FALSE. Significance letters typically annotate column percentages.",
      "",
      "Warning"
    )
  }

  return(error_log)
}


#' Check weight variable exists in data
#'
#' If weighting is enabled, verifies the weight column exists and is valid.
#'
#' @param config List, configuration object
#' @param survey_data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_preflight_weight_variable <- function(config, survey_data, error_log) {
  if (!isTRUE(config$apply_weighting)) return(error_log)

  weight_var <- config$weight_variable

  if (is.null(weight_var) || is.na(weight_var) || trimws(weight_var) == "") {
    error_log <- log_issue(
      error_log, "Preflight", "Missing Weight Variable",
      "apply_weighting is TRUE but no weight_variable is specified in config.",
      "",
      "Error"
    )
    return(error_log)
  }

  if (!weight_var %in% names(survey_data)) {
    error_log <- log_issue(
      error_log, "Preflight", "Weight Column Not Found",
      sprintf("Weight variable '%s' not found in data columns.", weight_var),
      "",
      "Error"
    )
    return(error_log)
  }

  # Check weight values are numeric and valid
  weights <- survey_data[[weight_var]]
  numeric_weights <- suppressWarnings(as.numeric(weights))
  n_invalid <- sum(is.na(numeric_weights) & !is.na(weights))

  if (n_invalid > 0) {
    error_log <- log_issue(
      error_log, "Preflight", "Non-Numeric Weights",
      sprintf("Weight variable '%s' has %d non-numeric values.", weight_var, n_invalid),
      "",
      "Error"
    )
  }

  # Check for negative weights
  valid_weights <- numeric_weights[!is.na(numeric_weights)]
  if (any(valid_weights < 0)) {
    error_log <- log_issue(
      error_log, "Preflight", "Negative Weights",
      sprintf("Weight variable '%s' contains negative values.", weight_var),
      "",
      "Error"
    )
  }

  return(error_log)
}


#' Check for duplicate option codes
#'
#' Detects duplicate OptionCode values within the same question.
#'
#' @param options_df Data frame, Options sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_duplicate_options <- function(options_df, error_log) {
  if (!"OptionCode" %in% names(options_df)) return(error_log)

  # Check each question for duplicates
  q_codes <- unique(options_df$QuestionCode)

  for (q_code in q_codes) {
    q_opts <- options_df[options_df$QuestionCode == q_code, ]
    opt_codes <- q_opts$OptionCode[!is.na(q_opts$OptionCode) & q_opts$OptionCode != ""]

    dup_codes <- opt_codes[duplicated(opt_codes)]
    if (length(dup_codes) > 0) {
      error_log <- log_issue(
        error_log, "Preflight", "Duplicate Option Codes",
        sprintf("Question '%s' has duplicate OptionCodes: %s",
                q_code, paste(unique(dup_codes), collapse = ", ")),
        q_code,
        "Error"
      )
    }
  }

  return(error_log)
}


#' Check Open_End questions in Selection
#'
#' Warns if Open_End questions are selected for analysis.
#'
#' @param selection_df Data frame, Selection sheet
#' @param questions_df Data frame, Questions sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_open_end_selection <- function(selection_df, questions_df, error_log) {
  included_codes <- selection_df$QuestionCode[selection_df$Include == "Y"]

  open_end_questions <- questions_df[
    questions_df$QuestionCode %in% included_codes &
    questions_df$Variable_Type == "Open_End", ]

  if (nrow(open_end_questions) > 0) {
    error_log <- log_issue(
      error_log, "Preflight", "Open_End Questions Selected",
      sprintf("Open_End questions selected for crosstab analysis (will produce empty tables): %s",
              paste(open_end_questions$QuestionCode, collapse = ", ")),
      paste(open_end_questions$QuestionCode, collapse = ", "),
      "Warning"
    )
  }

  return(error_log)
}


#' Check base filter variable references
#'
#' Verifies that columns referenced in BaseFilter expressions exist in data.
#'
#' @param selection_df Data frame, Selection sheet
#' @param survey_data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_base_filter_variables <- function(selection_df, survey_data, error_log) {
  if (!"BaseFilter" %in% names(selection_df)) return(error_log)

  filter_rows <- selection_df[
    !is.na(selection_df$BaseFilter) &
    trimws(selection_df$BaseFilter) != "", ]

  if (nrow(filter_rows) == 0) return(error_log)

  data_cols <- names(survey_data)

  for (i in seq_len(nrow(filter_rows))) {
    q_code <- filter_rows$QuestionCode[i]
    filter_expr <- filter_rows$BaseFilter[i]

    # Extract variable names from filter expression
    # Remove string literals first
    clean_expr <- gsub("'[^']*'", "", filter_expr)
    clean_expr <- gsub('"[^"]*"', "", clean_expr)
    # Remove operators (but keep word characters and underscores)
    clean_expr <- gsub("[>=<!&|()]+", " ", clean_expr)
    # Remove standalone numbers (but not numbers that are part of identifiers)
    clean_expr <- gsub("(^|\\s)[0-9.]+($|\\s)", " ", clean_expr)

    # Extract potential variable names (word characters including digits)
    tokens <- regmatches(clean_expr, gregexpr("[A-Za-z_][A-Za-z0-9_.]*", clean_expr))
    tokens <- unique(unlist(tokens))

    # Filter out R keywords
    r_keywords <- c("TRUE", "FALSE", "NA", "NULL", "T", "F", "in", "is", "c",
                     "if", "else", "for", "while", "function", "return", "next", "break")
    potential_vars <- setdiff(tokens, r_keywords)

    # Check each potential variable exists in data
    missing_vars <- setdiff(potential_vars, data_cols)
    if (length(missing_vars) > 0) {
      error_log <- log_issue(
        error_log, "Preflight", "Missing Filter Variable",
        sprintf("Question '%s' BaseFilter references column(s) not found in data: %s. Filter: %s",
                q_code, paste(missing_vars, collapse = ", "), filter_expr),
        q_code,
        "Error"
      )
    }
  }

  return(error_log)
}


#' Check data column coverage for selected questions
#'
#' Verifies the expected data column(s) exist for every selected question.
#'
#' @param selection_df Data frame, Selection sheet
#' @param questions_df Data frame, Questions sheet
#' @param survey_data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_data_column_coverage <- function(selection_df, questions_df, survey_data,
                                        error_log) {
  included_codes <- selection_df$QuestionCode[selection_df$Include == "Y"]
  data_cols <- names(survey_data)

  for (q_code in included_codes) {
    q_row <- questions_df[questions_df$QuestionCode == q_code, ]

    # Skip if question not found (caught by check_selection_vs_questions)
    if (nrow(q_row) == 0) next

    var_type <- q_row$Variable_Type[1]

    if (var_type == "Multi_Mention") {
      # Multi_Mention handled by check_multi_mention_columns
      next
    }

    if (var_type == "Ranking") {
      # Ranking uses multiple columns (Q76_1, Q76_2, etc.), not a single column
      next
    }

    if (var_type == "Allocation") {
      # Allocation (constant-sum) spreads across {code}_1..{code}_N with NO
      # bare column, exactly like Multi_Mention. Check_allocation_columns()
      # verifies those members. Looking for a bare column here raised a hard
      # ERROR on every allocation question and blocked the run (VAS 2026, the
      # first study to use the type).
      next
    }

    # Single column questions: data column name = QuestionCode
    if (!q_code %in% data_cols) {
      error_log <- log_issue(
        error_log, "Preflight", "Missing Data Column",
        sprintf("Question '%s' not found as a column in data.", q_code),
        q_code,
        "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 13: LOGO FILE EXISTENCE (REPORT BRANDING)
# ==============================================================================

#' Check Logo Files Exist
#'
#' Verifies that configured logo files actually exist. Upgrades the console-only
#' warning from crosstabs_config.R to a logged issue. Unconditional since the
#' classic report was retired: the interactive report carries the same logos, so
#' a missing file is a branding fault on the deliverable that always ships.
#'
#' @param config List, configuration object
#' @param error_log Data frame, error log
#' @return Updated error_log
check_preflight_logo_files <- function(config, error_log) {
  logo_fields <- list(
    researcher_logo_path = "Researcher logo",
    client_logo_path = "Client logo",
    logo_path = "Logo"
  )

  for (field in names(logo_fields)) {
    path <- config[[field]]
    if (!is.null(path) && nzchar(path) && !file.exists(path)) {
      error_log <- log_issue(error_log, "Preflight", "Warning",
        sprintf("%s file not found: '%s'. The report will render without this logo.",
                logo_fields[[field]], basename(path)),
        severity = "Warning")
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 14: COLOUR CODE VALIDATION (REPORT BRANDING)
# ==============================================================================

#' Check Colour Codes Are Valid Hex
#'
#' Validates that brand_colour, accent_colour, and chart_bar_colour are valid
#' hex colour codes. Unconditional since the classic report was retired: the
#' interactive report reads the same three fields, and only well-formed hex
#' reaches its renderer. Junk simply disappears without this warning.
#'
#' @param config List, configuration object
#' @param error_log Data frame, error log
#' @return Updated error_log
check_preflight_colour_codes <- function(config, error_log) {
  hex_pattern <- "^#[0-9A-Fa-f]{6}$"

  colour_fields <- list(
    brand_colour = "Brand colour",
    accent_colour = "Accent colour",
    chart_bar_colour = "Chart bar colour"
  )

  for (field in names(colour_fields)) {
    val <- config[[field]]
    if (!is.null(val) && nzchar(val) && !grepl(hex_pattern, val)) {
      error_log <- log_issue(error_log, "Preflight", "Warning",
        sprintf("%s '%s' is not a valid hex colour code (expected format: #RRGGBB). The report may not render colours correctly.",
                colour_fields[[field]], val),
        severity = "Warning")
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 15: DASHBOARD SCALE VALIDATION
# ==============================================================================

#' Check Dashboard Scale Thresholds
#'
#' Validates that the dashboard colour break thresholds are logically ordered
#' (green > amber). Runs unconditionally: it used to be gated on
#' `include_summary`, which was retired with the classic HTML report, and a
#' retired setting is absent from `config_obj`, so the gate would have read NULL
#' and returned early forever, silently killing the check for the pairs that ARE
#' live (production review 2026-08, I11). The pairs always have defaults, so
#' there is always something to check, and green <= amber is always worth saying.
#'
#' Only the mean and index pairs remain: the net and custom pairs drove the
#' retired classic dashboard and are read by nothing.
#'
#' @param config List, configuration object
#' @param error_log Data frame, error log
#' @return Updated error_log
check_preflight_dashboard_scales <- function(config, error_log) {
  # Check green > amber for each metric type the interactive dashboard reads
  scale_pairs <- list(
    list(green = "dashboard_green_mean", amber = "dashboard_amber_mean", label = "Mean"),
    list(green = "dashboard_green_index", amber = "dashboard_amber_index", label = "Index")
  )

  for (pair in scale_pairs) {
    green_val <- config[[pair$green]]
    amber_val <- config[[pair$amber]]

    if (!is.null(green_val) && !is.null(amber_val)) {
      if (green_val <= amber_val) {
        error_log <- log_issue(error_log, "Preflight", "Warning",
          sprintf("Dashboard %s: green threshold (%.1f) <= amber threshold (%.1f). Green should be higher than amber for correct colour coding.",
                  pair$label, green_val, amber_val),
          severity = "Warning")
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 16: BONFERRONI WITH FEW COLUMNS
# ==============================================================================

#' Check Bonferroni With Few Banner Columns
#'
#' When bonferroni_correction is enabled with fewer than 5 banner columns,
#' warns that the correction may be overly conservative.
#'
#' @param config List, configuration object
#' @param selection_df Data frame, Selection sheet (for counting banner columns)
#' @param error_log Data frame, error log
#' @return Updated error_log
check_preflight_bonferroni <- function(config, selection_df, error_log) {
  sig_enabled <- !is.null(config$enable_significance_testing) &&
                 isTRUE(config$enable_significance_testing)
  bonf <- !is.null(config$bonferroni_correction) &&
          isTRUE(config$bonferroni_correction)

  if (!sig_enabled || !bonf) return(error_log)

  # Count banner columns from selection_df
  if (!is.null(selection_df) && "UseBanner" %in% names(selection_df)) {
    banner_cols <- selection_df[!is.na(selection_df$UseBanner) &
                                toupper(as.character(selection_df$UseBanner)) == "Y", ]
    n_banner <- nrow(banner_cols)

    if (n_banner > 0 && n_banner < 5) {
      error_log <- log_issue(error_log, "Preflight", "Info",
        sprintf("Bonferroni correction is enabled with only %d banner column(s). With few columns, this correction may be overly conservative and reduce the ability to detect significant differences. Consider disabling bonferroni_correction.",
                n_banner),
        severity = "Info")
    }
  }

  return(error_log)
}


# ==============================================================================
# PREFLIGHT ORCHESTRATOR
# ==============================================================================

#' Run Pre-Flight Validation Checks
#'
#' Cross-references config, structure, and data to catch configuration
#' mistakes before analysis begins.
#'
#' @param survey_structure List with $questions, $options
#' @param survey_data Data frame, survey data
#' @param config List, configuration object
#' @param selection_df Data frame, Selection sheet (NULL to skip selection checks)
#' @param error_log Data frame, error log
#' @param verbose Logical, print progress messages
#' @return Updated error_log
#' @export
validate_preflight <- function(survey_structure, survey_data, config,
                                selection_df = NULL, error_log, verbose = TRUE) {
  if (verbose) {
    cat("  Pre-flight cross-reference checks...\n")
  }

  questions_df <- survey_structure$questions
  options_df <- survey_structure$options

  # --- Checks that require selection_df ---
  if (!is.null(selection_df) && is.data.frame(selection_df) && nrow(selection_df) > 0) {

    # 1. Selection vs Questions cross-check
    error_log <- check_selection_vs_questions(selection_df, questions_df, error_log)

    # 2. Option values vs actual data
    error_log <- check_option_values_vs_data(
      questions_df, options_df, survey_data, selection_df, error_log)

    # 3. Multi_Mention column verification
    error_log <- check_preflight_multi_mention(
      questions_df, survey_data, selection_df, error_log)

    # 4. Numeric data type check
    error_log <- check_numeric_data_types(
      questions_df, survey_data, selection_df, error_log)

    # 5. CreateIndex configuration (Index_Weight lives in Options sheet)
    error_log <- check_create_index_config(selection_df, options_df, error_log,
                                              questions_df = questions_df)

    # 6. Banner variable validation
    error_log <- check_banner_variables(
      selection_df, questions_df, survey_data, error_log)

    # 10. Open_End questions selected
    error_log <- check_open_end_selection(selection_df, questions_df, error_log)

    # 11. Base filter variable check
    error_log <- check_base_filter_variables(selection_df, survey_data, error_log)

    # 12. Data column coverage
    error_log <- check_data_column_coverage(
      selection_df, questions_df, survey_data, error_log)
  }

  # --- Checks that don't require selection_df ---

  # 7. Conflicting display settings
  error_log <- check_conflicting_display(config, error_log)

  # 8. Weight variable validation
  error_log <- check_preflight_weight_variable(config, survey_data, error_log)

  # 9. Duplicate options
  error_log <- check_duplicate_options(options_df, error_log)

  # 13. Logo file existence (HTML report)
  error_log <- check_preflight_logo_files(config, error_log)

  # 14. Colour code validation (HTML report)
  error_log <- check_preflight_colour_codes(config, error_log)

  # 15. Dashboard scale thresholds
  error_log <- check_preflight_dashboard_scales(config, error_log)

  # 16. Bonferroni with few columns
  error_log <- check_preflight_bonferroni(config, selection_df, error_log)

  if (verbose) {
    n_preflight <- sum(error_log$Component == "Preflight")
    if (n_preflight == 0) {
      cat("  ✓ All pre-flight checks passed\n")
    } else {
      cat(sprintf("  ⚠ Pre-flight found %d issue(s)\n", n_preflight))
    }
  }

  return(error_log)
}
