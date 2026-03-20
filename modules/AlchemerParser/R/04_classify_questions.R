# ==============================================================================
# ALCHEMER PARSER - QUESTION CLASSIFICATION
# ==============================================================================
# Classify question types and handle grid structures
# Implements detection hierarchy: NPS -> Likert -> Rating -> Ranking -> etc.
# ==============================================================================

# --- Classification Constants ------------------------------------------------

# NPS questions always have exactly 11 options (0-10 scale)
NPS_OPTION_COUNT <- 11L

# Rating scale option counts considered valid for keyword-based detection
# 5-point (e.g., Very Dissatisfied to Very Satisfied)
# 7-point (e.g., Extremely Unlikely to Extremely Likely)
# 10-point (numeric scale)
# 11-point (0-10 inclusive)
RATING_SCALE_COUNTS <- c(5L, 7L, 10L, 11L)

# Rating scale with "Don't know" option (0-10 + Don't know)
RATING_SCALE_WITH_DK_COUNT <- 12L

# Minimum number of numeric options to classify as a rating scale
MIN_NUMERIC_OPTIONS <- 3L

# Minimum fraction of options that must be numeric to classify as rating
MIN_NUMERIC_FRACTION <- 0.5

# Grid option search: how far beyond expected ID to search
GRID_OPTION_SEARCH_BEFORE <- 2L
GRID_OPTION_SEARCH_AFTER <- 10L

# Minimum average label length to consider radio grid (vs star rating)
MIN_RADIO_GRID_LABEL_LENGTH <- 8L

#' Classify Questions
#'
#' @description
#' Classifies all questions by type and handles grid structures.
#' Applies detection hierarchy and merges data from all three sources.
#'
#' @param questions Question groups from data export map
#' @param translation_data Translation export data
#' @param word_hints Word questionnaire hints
#' @param verbose Print progress messages
#'
#' @return List of classified questions with variable types
#'
#' @keywords internal
classify_questions <- function(questions, translation_data, word_hints,
                               verbose = FALSE) {

  classified <- list()

  for (q_num in names(questions)) {
    q <- questions[[q_num]]

    # Special handling for ResponseID (system variable)
    if (q_num == "ResponseID") {
      classified[[q_num]] <- list(
        q_num = q_num,
        q_id = "ResponseID",
        question_text = "Response ID",
        variable_type = "Open_End",
        grid_type = "single",
        n_columns = 1,
        columns = q$columns,
        options = list(),
        hints = list(),
        is_grid = FALSE,
        is_system = TRUE
      )
      next
    }

    # Get Word doc hints first (needed for grid detection)
    hints <- get_hint_for_question(q_num, word_hints)

    # Check for Ranking BEFORE grid detection
    # Ranking questions can look like grids but should be treated differently
    is_ranking <- FALSE
    q_text <- tolower(q$question_text %||% "")
    n_cols <- length(q$columns)

    # Check Word doc hint for ranking
    if (!is.null(hints$has_rank_keyword) && !is.na(hints$has_rank_keyword) && hints$has_rank_keyword) {
      if (n_cols > 1) {
        is_ranking <- TRUE
      }
    }

    # Check question text for explicit ranking indicators
    if (!is_ranking && n_cols > 1) {
      if (grepl("ranking question", q_text, ignore.case = TRUE) ||
          grepl("most to least|least to most", q_text, ignore.case = TRUE) ||
          grepl("\\brank\\b|\\branking\\b|prioriti[sz]e", q_text, ignore.case = TRUE)) {
        is_ranking <- TRUE
      }
    }

    # If this is a ranking question, handle it separately (not as a grid)
    if (is_ranking) {
      options <- get_options_for_question(q$q_id, translation_data)

      classified[[q_num]] <- list(
        q_num = q_num,
        q_id = q$q_id,
        question_text = q$question_text,
        variable_type = "Ranking",
        grid_type = "multi_column",
        n_columns = n_cols,
        columns = q$columns,
        options = options,
        hints = hints,
        is_grid = FALSE
      )
      next
    }

    # Detect grid type (with Word doc hints for better detection)
    grid_type <- detect_grid_type_with_hints(q, hints)

    # Get options from translation
    # For grids, options are stored in the LAST question ID in the range
    if (grid_type %in% c("radio_grid", "checkbox_grid")) {
      # Calculate the expected last question ID (base_id + number of rows)
      num_rows <- length(unique(sapply(q$columns, function(c) c$row_label)))
      last_qid <- as.integer(q$q_id) + num_rows

      # Search for options near the expected location
      # Alchemer is inconsistent - sometimes it's +num_rows, +num_rows+1, +num_rows+2, etc.
      options <- find_grid_options(as.integer(q$q_id), last_qid, translation_data)
      grid_options_source <- "direct"

      # If still no options, try to find a shared rating scale (0-10 + Don't know)
      if (length(options) == 0) {
        options <- find_rating_scale_options(translation_data)
        if (length(options) > 0) {
          grid_options_source <- "generic_fallback"
          if (verbose) {
            cat(sprintf("  WARNING: Q%s (%s) — no grid options found at expected IDs (%d-%d). Using generic rating scale as fallback. Please review output.\n",
                        q_num, grid_type, as.integer(q$q_id), last_qid))
          }
        } else {
          grid_options_source <- "none"
          if (verbose) {
            cat(sprintf("  WARNING: Q%s (%s) — no options found at all. Grid sub-questions will have empty option lists.\n",
                        q_num, grid_type))
          }
        }
      }
    } else {
      options <- get_options_for_question(q$q_id, translation_data)
    }

    # Handle different grid types
    if (grid_type == "checkbox_grid") {
      # Pivot checkbox grid into sub-questions
      sub_qs <- pivot_checkbox_grid(q, options, hints)
      classified[[q_num]] <- list(
        q_num = q_num,
        q_id = q$q_id,
        grid_type = grid_type,
        sub_questions = sub_qs,
        is_grid = TRUE,
        grid_options_source = grid_options_source
      )

    } else if (grid_type == "radio_grid") {
      # Create sub-questions for each row
      sub_qs <- create_radio_grid_questions(q, options, hints)
      classified[[q_num]] <- list(
        q_num = q_num,
        q_id = q$q_id,
        grid_type = grid_type,
        sub_questions = sub_qs,
        is_grid = TRUE,
        grid_options_source = grid_options_source
      )

    } else if (grid_type == "star_rating_grid") {
      # Create sub-questions for each item
      sub_qs <- create_star_rating_grid_questions(q, options, hints)
      classified[[q_num]] <- list(
        q_num = q_num,
        q_id = q$q_id,
        grid_type = grid_type,
        sub_questions = sub_qs,
        is_grid = TRUE,
        grid_options_source = grid_options_source
      )

    } else {
      # Single or multi-column question
      var_type <- classify_variable_type(q, options, hints, verbose)

      classified[[q_num]] <- list(
        q_num = q_num,
        q_id = q$q_id,
        question_text = q$question_text,
        variable_type = var_type,
        grid_type = grid_type,
        n_columns = length(q$columns),
        columns = q$columns,
        options = options,
        hints = hints,
        is_grid = FALSE
      )
    }
  }

  return(classified)
}


#' Classify Variable Type
#'
#' @description
#' Classifies a single question's variable type using detection hierarchy:
#' 1. NPS, 2. Likert, 3. Rating, 4. Ranking, 5. Multi_Mention,
#' 6. Single_Response, 7. Numeric, 8. Open_End
#'
#' @param question Question group
#' @param options Option list from translation
#' @param hints Word doc hints
#' @param verbose Print messages
#'
#' @return Variable type string
#'
#' @keywords internal
classify_variable_type <- function(question, options, hints, verbose = FALSE) {

  q_text <- tolower(question$question_text %||% "")
  n_cols <- length(question$columns)
  n_options <- length(options)

  # Apply detection hierarchy: NPS -> Likert -> Rating -> Word hints ->
  # Ranking -> Multi_Mention -> Numeric Rating -> Single_Response -> Open_End
  detect_nps(options, n_options, q_text) %||%
    detect_likert(options, n_options) %||%
    detect_rating_by_keywords(options, n_options) %||%
    detect_type_from_word_hints(hints) %||%
    detect_ranking(hints, q_text, n_cols) %||%
    detect_multi_mention(hints, question, n_cols) %||%
    detect_numeric_rating(options, n_options) %||%
    if (n_options > 0) "Single_Response" else "Open_End"
}


#' Detect NPS question type
#' @keywords internal
detect_nps <- function(options, n_options, q_text) {
  if (n_options != NPS_OPTION_COUNT) return(NULL)

  option_texts <- sapply(options, function(o) o$text)
  option_values <- suppressWarnings(as.numeric(option_texts))

  if (all(!is.na(option_values)) && all(sort(option_values) == 0:10)) {
    return("NPS")
  }
  NULL
}


#' Detect Likert question type
#' @keywords internal
detect_likert <- function(options, n_options) {
  if (n_options == 0) return(NULL)

  option_texts <- tolower(sapply(options, function(o) o$text))
  likert_keywords <- c("disagree", "neutral", "agree", "strongly")

  if (any(sapply(likert_keywords, function(kw) any(grepl(kw, option_texts))))) {
    return("Likert")
  }
  NULL
}


#' Detect Rating question type by keyword matching
#' @keywords internal
detect_rating_by_keywords <- function(options, n_options) {
  if (!(n_options %in% RATING_SCALE_COUNTS)) return(NULL)

  option_texts <- tolower(sapply(options, function(o) o$text))
  rating_keywords <- c("satisfied", "dissatisfied", "poor", "excellent",
                        "quality", "likely", "unlikely")

  if (any(sapply(rating_keywords, function(kw) any(grepl(kw, option_texts))))) {
    return("Rating")
  }
  NULL
}


#' Detect variable type from Word document hints (slider, numeric, textbox)
#' @keywords internal
detect_type_from_word_hints <- function(hints) {
  if (is.na(hints$type)) return(NULL)

  switch(hints$type,
    "slider"  = "Numeric",
    "numeric" = "Numeric",
    "textbox" = "Open_End",
    NULL
  )
}


#' Detect Ranking question type
#' @keywords internal
detect_ranking <- function(hints, q_text, n_cols) {
  if (n_cols <= 1) return(NULL)

  # Check Word doc hint
  if (!is.null(hints$has_rank_keyword) && !is.na(hints$has_rank_keyword) && hints$has_rank_keyword) {
    return("Ranking")
  }

  # Check question text for ranking indicators
  ranking_patterns <- c(
    "ranking question",
    "most to least|least to most",
    "\\brank\\b|\\branking\\b|prioriti[sz]e"
  )
  for (pattern in ranking_patterns) {
    if (grepl(pattern, q_text, ignore.case = TRUE)) {
      return("Ranking")
    }
  }
  NULL
}


#' Detect Multi_Mention from Word doc brackets or column structure
#' @keywords internal
detect_multi_mention <- function(hints, question, n_cols) {
  # From Word doc brackets
  if (!is.null(hints$brackets) && !is.na(hints$brackets) && hints$brackets == "[]") {
    return("Multi_Mention")
  }

  # From column structure
  if (n_cols > 1 && question$structure == "grid_or_multi") {
    option_labels <- sapply(question$columns, function(c) c$row_label)
    if (length(unique(option_labels)) == length(option_labels)) {
      return("Multi_Mention")
    }
  }
  NULL
}


#' Detect Rating from predominantly numeric options
#' @keywords internal
detect_numeric_rating <- function(options, n_options) {
  if (n_options == 0) return(NULL)

  option_texts <- sapply(options, function(o) o$text)
  numeric_values <- suppressWarnings(as.numeric(option_texts))
  n_numeric <- sum(!is.na(numeric_values))

  if (n_numeric >= max(MIN_NUMERIC_OPTIONS, n_options * MIN_NUMERIC_FRACTION)) {
    return("Rating")
  }
  NULL
}


#' Pivot Checkbox Grid
#'
#' @description
#' Pivots a checkbox grid into sub-questions (one per row).
#' Each sub-question is Multi_Mention type.
#'
#' @param question Question group
#' @param options Options from translation
#' @param hints Word doc hints
#'
#' @return List of sub-questions
#'
#' @keywords internal
pivot_checkbox_grid <- function(question, options, hints) {

  cols <- question$columns

  # Extract unique rows and columns (preserve original order from data)
  row_labels <- unique(sapply(cols, function(c) c$row_label))
  col_labels <- unique(sapply(cols, function(c) c$col_label))

  # DO NOT sort - preserve data order

  # Create sub-questions (one per row)
  sub_questions <- list()

  for (i in seq_along(row_labels)) {
    row <- row_labels[i]
    suffix <- letters[i]  # a, b, c, ...

    # Find columns for this row
    row_cols <- Filter(function(c) c$row_label == row, cols)

    # Sort by column label
    row_cols <- row_cols[order(sapply(row_cols, function(c) c$col_label))]

    sub_questions[[suffix]] <- list(
      suffix = suffix,
      row_label = row,
      question_text = paste0(row, ":", question$question_text),
      columns = row_cols,
      col_labels = col_labels,
      variable_type = "Multi_Mention",
      n_columns = length(col_labels)
    )
  }

  return(sub_questions)
}


#' Create Radio Grid Questions
#'
#' @description
#' Creates sub-questions for a radio button grid (one per row).
#' Each sub-question is Single_Response type, unless options are numeric (then Rating).
#'
#' @param question Question group
#' @param options Options from translation
#' @param hints Word doc hints
#'
#' @return List of sub-questions
#'
#' @keywords internal
create_radio_grid_questions <- function(question, options, hints) {

  cols <- question$columns

  # Extract unique rows (preserve original order from data export map)
  row_labels <- unique(sapply(cols, function(c) c$row_label))
  # DO NOT sort - preserve data order

  # Determine variable type based on options
  # If options are mostly numeric (e.g., 0-10), classify as Rating
  var_type <- "Single_Response"
  if (length(options) > 0) {
    option_texts <- sapply(options, function(o) o$text)
    numeric_values <- suppressWarnings(as.numeric(option_texts))
    n_numeric <- sum(!is.na(numeric_values))

    # If most options are numeric, it's a rating scale
    if (n_numeric >= max(MIN_NUMERIC_OPTIONS, length(options) * MIN_NUMERIC_FRACTION)) {
      var_type <- "Rating"
    }
  }

  sub_questions <- list()

  for (i in seq_along(row_labels)) {
    row <- row_labels[i]
    suffix <- letters[i]

    sub_questions[[suffix]] <- list(
      suffix = suffix,
      row_label = row,
      question_text = row,  # Use row label as question text (e.g., "Tees", "greens", "fairways")
      variable_type = var_type,
      n_columns = 1,
      options = options  # Options from translation (e.g., Happy, Neutral, Unhappy)
    )
  }

  return(sub_questions)
}


#' Create Star Rating Grid Questions
#'
#' @description
#' Creates sub-questions for a star rating grid (one per item).
#' Each sub-question is Rating type.
#' Handles patterns like "Question:Item:1", "Question:Item:2", etc.
#'
#' @param question Question group
#' @param options Options from translation
#' @param hints Word doc hints
#'
#' @return List of sub-questions
#'
#' @keywords internal
create_star_rating_grid_questions <- function(question, options, hints) {

  cols <- question$columns

  # Extract unique items (remove the numeric rating suffixes)
  # Handles both "Item:1" and "Question:Item:1" patterns
  items <- unique(sapply(cols, function(c) {
    label <- c$row_label
    # Remove trailing ":digit" pattern to get base item name
    base <- gsub(":\\d+$", "", label)
    return(base)
  }))
  items <- sort(items)

  sub_questions <- list()

  for (i in seq_along(items)) {
    item <- items[i]
    suffix <- letters[i]

    # Find all columns for this item
    # Escape special regex characters in item name
    item_escaped <- gsub("([.?*+^$\\[\\]{}()|\\\\])", "\\\\\\1", item)
    item_cols <- Filter(function(c) {
      grepl(paste0("^", item_escaped, ":\\d+$"), c$row_label)
    }, cols)

    # Extract rating scale values from row labels
    scale_values <- sort(unique(sapply(item_cols, function(c) {
      # Extract the final number after the last colon
      matches <- regmatches(c$row_label, regexec(":(\\d+)$", c$row_label))
      if (length(matches[[1]]) > 1) {
        return(matches[[1]][2])
      }
      return(NA)
    })))
    scale_values <- scale_values[!is.na(scale_values)]

    # Create synthetic options for the scale (e.g., 1-5)
    scale_options <- lapply(scale_values, function(val) {
      list(code = val, text = val, key = paste0("synthetic-", val))
    })

    # Extract item display name (last part after colons)
    # For "Q13: Item description:1", we want "Item description"
    item_display <- gsub("^.*?:(.*)$", "\\1", item)
    if (item_display == item) {
      # No colon found, use as-is
      item_display <- item
    }

    sub_questions[[suffix]] <- list(
      suffix = suffix,
      item_label = item,
      question_text = item_display,
      variable_type = "Rating",
      n_columns = 1,
      options = scale_options
    )
  }

  return(sub_questions)
}


#' Find Grid Options
#'
#' @description
#' Searches for grid options in translation data.
#' Alchemer stores grid options inconsistently - sometimes at base_id + num_rows,
#' sometimes at base_id + num_rows + 1, etc.
#' This function searches a range of IDs to find the options.
#'
#' @param base_id Base question ID (as integer)
#' @param expected_last_qid Expected last question ID (base_id + num_rows)
#' @param translation_data Translation export data
#'
#' @return List of options, or empty list if not found
#'
#' @keywords internal
find_grid_options <- function(base_id, expected_last_qid, translation_data) {

  # First try the expected location (most common)
  qid <- as.character(expected_last_qid)
  if (qid %in% names(translation_data$options)) {
    opts <- translation_data$options[[qid]]
    if (length(opts) > 0) {
      return(opts)
    }
  }

  # Try base ID
  qid <- as.character(base_id)
  if (qid %in% names(translation_data$options)) {
    opts <- translation_data$options[[qid]]
    if (length(opts) > 0) {
      return(opts)
    }
  }

  # Search nearby IDs — Alchemer's inconsistent storage patterns
  search_range <- (expected_last_qid - GRID_OPTION_SEARCH_BEFORE):(expected_last_qid + GRID_OPTION_SEARCH_AFTER)
  for (test_id in search_range) {
    qid <- as.character(test_id)
    if (qid %in% names(translation_data$options)) {
      opts <- translation_data$options[[qid]]
      if (length(opts) > 0) {
        return(opts)
      }
    }
  }

  # No options found
  return(list())
}


#' Find Rating Scale Options
#'
#' @description
#' Searches for a standard 0-10 + "Don't know" rating scale in the translation data.
#' Used as a fallback when radio grid options aren't found at expected question IDs.
#' Prefers the 12-option version (0-10 + Don't know) over 11-option version (0-10 only).
#'
#' @param translation_data Translation export data
#'
#' @return List of options, or empty list if not found
#'
#' @keywords internal
find_rating_scale_options <- function(translation_data) {

  # First pass: Look for scale with Don't know (0-10 + Don't know) - preferred
  for (qid in names(translation_data$options)) {
    opts <- translation_data$options[[qid]]

    if (length(opts) == RATING_SCALE_WITH_DK_COUNT) {
      opt_texts <- sapply(opts, function(o) o$text)

      # Check if this is a 0-10 + Don't know scale
      has_zero <- any(grepl("^0$", opt_texts))
      has_ten <- any(grepl("^10$", opt_texts))
      has_dont_know <- any(grepl("don't know", opt_texts, ignore.case = TRUE))

      if (has_zero && has_ten && has_dont_know) {
        # Found the preferred 12-option scale
        return(opts)
      }
    }
  }

  # Second pass: Fall back to 11-option scale (0-10 only) if no DK version found
  for (qid in names(translation_data$options)) {
    opts <- translation_data$options[[qid]]

    if (length(opts) == NPS_OPTION_COUNT) {
      opt_texts <- sapply(opts, function(o) o$text)

      has_zero <- any(grepl("^0$", opt_texts))
      has_ten <- any(grepl("^10$", opt_texts))

      if (has_zero && has_ten) {
        # Found 11-option scale as fallback
        return(opts)
      }
    }
  }

  # No rating scale found
  return(list())
}
