# ==============================================================================
# ALCHEMER PARSER - QUESTION CLASSIFICATION
# ==============================================================================
# Classify question types and handle grid structures
# Implements detection hierarchy: NPS -> Likert -> Rating -> Ranking -> etc.
# ==============================================================================

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
        variable_type = "System",
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

    # Detect grid type (with Word doc hints for better detection)
    grid_type <- detect_grid_type_with_hints(q, hints)

    # Get options from translation
    # For grids, options are stored in the LAST question ID in the range
    if (grid_type %in% c("radio_grid", "checkbox_grid")) {
      # Calculate the last question ID (base_id + number of rows)
      num_rows <- length(unique(sapply(q$columns, function(c) c$row_label)))
      last_qid <- as.character(as.integer(q$q_id) + num_rows)
      options <- get_options_for_question(last_qid, translation_data)

      # If no options found at last_qid, try base question ID
      if (length(options) == 0) {
        options <- get_options_for_question(q$q_id, translation_data)
      }

      # If still no options, try to find a shared rating scale (0-10 + Don't know)
      if (length(options) == 0) {
        options <- find_rating_scale_options(translation_data)
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
        is_grid = TRUE
      )

    } else if (grid_type == "radio_grid") {
      # Create sub-questions for each row
      sub_qs <- create_radio_grid_questions(q, options, hints)
      classified[[q_num]] <- list(
        q_num = q_num,
        q_id = q$q_id,
        grid_type = grid_type,
        sub_questions = sub_qs,
        is_grid = TRUE
      )

    } else if (grid_type == "star_rating_grid") {
      # Create sub-questions for each item
      sub_qs <- create_star_rating_grid_questions(q, options, hints)
      classified[[q_num]] <- list(
        q_num = q_num,
        q_id = q$q_id,
        grid_type = grid_type,
        sub_questions = sub_qs,
        is_grid = TRUE
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
#' 6. Single_Mention, 7. Numeric, 8. Open_End
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

  # 1. Check for NPS
  if (n_options == 11) {
    option_texts <- sapply(options, function(o) o$text)
    option_values <- suppressWarnings(as.numeric(option_texts))

    if (all(!is.na(option_values)) && all(option_values == 0:10)) {
      # Check for NPS keywords: recommend, likely to recommend
      if (grepl("recommend|likely", q_text, ignore.case = TRUE)) {
        return("NPS")
      }
      # If 11-point scale (0-10) but no clear keyword, still likely NPS
      # Check if options match exactly 0:10
      if (all(sort(option_values) == 0:10)) {
        return("NPS")
      }
    }
  }

  # 2. Check for Likert
  if (n_options > 0) {
    option_texts <- tolower(sapply(options, function(o) o$text))
    likert_keywords <- c("disagree", "neutral", "agree", "strongly")

    if (any(sapply(likert_keywords, function(kw) any(grepl(kw, option_texts))))) {
      return("Likert")
    }
  }

  # 3. Check for Rating
  if (n_options %in% c(5, 7, 10, 11)) {
    option_texts <- tolower(sapply(options, function(o) o$text))
    rating_keywords <- c("satisfied", "dissatisfied", "poor", "excellent",
                        "quality", "likely", "unlikely")

    if (any(sapply(rating_keywords, function(kw) any(grepl(kw, option_texts))))) {
      return("Rating")
    }
  }

  # 4. Check for Slider/Numeric from Word doc
  if (!is.na(hints$type)) {
    if (hints$type == "slider") {
      return("Numeric")
    }
    if (hints$type == "numeric") {
      return("Numeric")
    }
    if (hints$type == "textbox") {
      return("Open_End")
    }
  }

  # 5. Check for Ranking
  # Check Word doc hint first
  if (!is.null(hints$has_rank_keyword) && !is.na(hints$has_rank_keyword) && hints$has_rank_keyword) {
    if (n_cols > 1) {
      return("Ranking")
    }
  }

  # Check question text for rank keyword
  if (grepl("rank|order|priorit", q_text, ignore.case = TRUE)) {
    if (n_cols > 1) {
      return("Ranking")
    }
  }

  # 6. Check for Multi-Mention from Word doc brackets
  if (!is.null(hints$brackets) && !is.na(hints$brackets)) {
    if (hints$brackets == "[]") {
      return("Multi_Mention")
    }
  }

  # 7. Check for Multi-Mention from column structure
  if (n_cols > 1 && question$structure == "grid_or_multi") {
    # Check if columns have different option labels
    option_labels <- sapply(question$columns, function(c) c$row_label)
    if (length(unique(option_labels)) == length(option_labels)) {
      return("Multi_Mention")
    }
  }

  # 8. Check if Single-Mention (has options)
  if (n_options > 0) {
    return("Single_Mention")
  }

  # 9. Otherwise Open_End (no options, not classified above)
  return("Open_End")
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
#' Each sub-question is Single_Mention type.
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

  sub_questions <- list()

  for (i in seq_along(row_labels)) {
    row <- row_labels[i]
    suffix <- letters[i]

    sub_questions[[suffix]] <- list(
      suffix = suffix,
      row_label = row,
      question_text = row,  # Use row label as question text (e.g., "Tees", "greens", "fairways")
      variable_type = "Single_Mention",
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


#' Find Rating Scale Options
#'
#' @description
#' Searches for a standard 0-10 + "Don't know" rating scale in the translation data.
#' Used as a fallback when radio grid options aren't found at expected question IDs.
#'
#' @param translation_data Translation export data
#'
#' @return List of options, or empty list if not found
#'
#' @keywords internal
find_rating_scale_options <- function(translation_data) {

  # Search all questions with options
  for (qid in names(translation_data$options)) {
    opts <- translation_data$options[[qid]]

    # Look for a scale with 11-12 options (likely 0-10 or 0-10 + Don't know)
    if (length(opts) >= 11 && length(opts) <= 12) {
      opt_texts <- sapply(opts, function(o) o$text)

      # Check if this looks like a 0-10 scale
      has_zero <- any(grepl("^0$", opt_texts))
      has_ten <- any(grepl("^10$", opt_texts))

      if (has_zero && has_ten) {
        # Found a 0-10 scale, return it
        return(opts)
      }
    }
  }

  # No rating scale found
  return(list())
}
