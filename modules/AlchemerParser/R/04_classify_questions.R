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

    # Detect grid type
    grid_type <- detect_grid_type(q)

    # Get options from translation
    options <- get_options_for_question(q$q_id, translation_data)

    # Get Word doc hints
    hints <- get_hint_for_question(q_num, word_hints)

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
      if (grepl("recommend", q_text)) {
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
  if (grepl("rank", q_text) || (!is.na(hints$has_rank_keyword) && hints$has_rank_keyword)) {
    if (n_cols > 1) {
      return("Ranking")
    }
  }

  # 6. Check for Multi-Mention from Word doc brackets
  if (!is.na(hints$brackets)) {
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

  # 8. Default to Single-Mention
  return("Single_Mention")
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

  # Extract unique rows and columns
  row_labels <- unique(sapply(cols, function(c) c$row_label))
  col_labels <- unique(sapply(cols, function(c) c$col_label))

  # Sort to ensure consistent order
  row_labels <- sort(row_labels)
  col_labels <- sort(col_labels)

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

  # Extract unique rows
  row_labels <- unique(sapply(cols, function(c) c$row_label))
  row_labels <- sort(row_labels)

  sub_questions <- list()

  for (i in seq_along(row_labels)) {
    row <- row_labels[i]
    suffix <- letters[i]

    sub_questions[[suffix]] <- list(
      suffix = suffix,
      row_label = row,
      question_text = question$question_text,  # Same question for all rows
      variable_type = "Single_Mention",
      n_columns = 1,
      options = options
    )
  }

  return(sub_questions)
}


#' Create Star Rating Grid Questions
#'
#' @description
#' Creates sub-questions for a star rating grid (one per item).
#' Each sub-question is Rating type.
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

  # Extract unique items (remove the numeric suffixes)
  items <- unique(sapply(cols, function(c) {
    # Remove trailing ":digit" pattern
    gsub(":\\d+$", "", c$row_label)
  }))
  items <- sort(items)

  sub_questions <- list()

  for (i in seq_along(items)) {
    item <- items[i]
    suffix <- letters[i]

    # Determine rating scale from row labels
    item_cols <- Filter(function(c) grepl(paste0("^", item, ":"), c$row_label), cols)
    scale_values <- sort(unique(sapply(item_cols, function(c) {
      gsub("^.*:(\\d+)$", "\\1", c$row_label)
    })))

    # Create synthetic options for the scale (e.g., 1-5)
    scale_options <- lapply(scale_values, function(val) {
      list(code = val, text = val, key = paste0("synthetic-", val))
    })

    sub_questions[[suffix]] <- list(
      suffix = suffix,
      item_label = item,
      question_text = paste0(item, ":", question$question_text),
      variable_type = "Rating",
      n_columns = 1,
      options = scale_options
    )
  }

  return(sub_questions)
}
