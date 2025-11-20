# ==============================================================================
# ALCHEMER PARSER - DATA EXPORT MAP PARSING
# ==============================================================================
# Parse Alchemer data export map Excel file
# Extracts question numbers, IDs, and column structure
# ==============================================================================

#' Parse Data Export Map
#'
#' @description
#' Parses the Alchemer data export map Excel file.
#' - Row 1: Q Numbers (1:, 2:, 3:...)
#' - Row 2: Q IDs (2:, 3:, 7:...)
#' - Column A: Row labels
#' - Columns B+: Data columns
#'
#' @param file_path Path to data_export_map.xlsx
#' @param verbose Print progress messages
#'
#' @return List containing:
#'   \item{questions}{List of question groups with parsed columns}
#'   \item{n_columns}{Total number of data columns}
#'   \item{raw_data}{Raw Excel data (first 2 rows)}
#'
#' @keywords internal
parse_data_export_map <- function(file_path, verbose = FALSE) {

  # Check file exists
  if (!file.exists(file_path)) {
    stop(sprintf("Data export map file not found: %s", file_path), call. = FALSE)
  }

  # Load required package
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required. Install with: install.packages('readxl')",
         call. = FALSE)
  }

  # Read first two rows (no column names)
  data_map <- readxl::read_excel(file_path, col_names = FALSE, n_max = 2)

  # Skip column A (row labels)
  q_num_row <- data_map[1, -1]
  q_id_row <- data_map[2, -1]

  n_cols <- ncol(data_map) - 1

  if (verbose) {
    cat(sprintf("  Reading %d data columns from export map\n", n_cols))
  }

  # Parse each column
  parsed_columns <- list()

  for (i in seq_len(n_cols)) {
    q_num_header <- as.character(q_num_row[[i]])
    q_id_header <- as.character(q_id_row[[i]])

    # Skip if both are NA
    if (is.na(q_num_header) && is.na(q_id_header)) {
      next
    }

    parsed_col <- parse_column_header(q_num_header, q_id_header, i)
    parsed_columns[[length(parsed_columns) + 1]] <- parsed_col
  }

  # Group columns by question number
  questions <- group_columns_by_question(parsed_columns)

  if (verbose) {
    cat(sprintf("  Grouped into %d questions\n", length(questions)))
  }

  return(list(
    questions = questions,
    n_columns = length(parsed_columns),
    raw_data = data_map[1:2, ]
  ))
}


#' Parse Column Header
#'
#' @description
#' Parses a single column header from the data export map.
#' Handles three structures:
#' 1. Simple: "Q#: Question Text" (2 parts)
#' 2. Grid/Multi: "Q#: Row/Option:Question Text" (3 parts)
#' 3. Checkbox Grid: "Q#: Col:Row:Question Text" (4 parts)
#'
#' @param q_num_header Header from row 1
#' @param q_id_header Header from row 2
#' @param col_index Column index (1-based)
#'
#' @return List with parsed column information
#'
#' @keywords internal
parse_column_header <- function(q_num_header, q_id_header, col_index) {

  # Special handling for ResponseID (first column)
  if (grepl("^Response\\s*ID$", q_num_header, ignore.case = TRUE)) {
    return(list(
      col_index = col_index,
      q_num = "ResponseID",
      q_id = "ResponseID",
      structure = "system",
      question_text = "Response ID",
      row_label = NA_character_,
      col_label = NA_character_,
      is_system = TRUE
    ))
  }

  # Extract Q numbers using regex
  q_num <- extract_leading_number(q_num_header)
  q_id <- extract_leading_number(q_id_header)

  # Split header into parts by colon
  parts <- strsplit(q_num_header, ":", fixed = TRUE)[[1]]
  n_parts <- length(parts)

  # Trim whitespace from all parts
  parts <- trimws(parts)

  # Determine structure based on number of parts
  if (n_parts == 2) {
    # Simple question: "Q#: Question Text"
    return(list(
      col_index = col_index,
      q_num = q_num,
      q_id = q_id,
      structure = "simple",
      question_text = parts[2],
      row_label = NA_character_,
      col_label = NA_character_
    ))

  } else if (n_parts == 3) {
    # Grid or Multi: "Q#: Row/Option:Question Text"
    return(list(
      col_index = col_index,
      q_num = q_num,
      q_id = q_id,
      structure = "grid_or_multi",
      question_text = parts[3],
      row_label = parts[2],
      col_label = NA_character_
    ))

  } else if (n_parts == 4) {
    # Checkbox Grid: "Q#: Col:Row:Question Text"
    return(list(
      col_index = col_index,
      q_num = q_num,
      q_id = q_id,
      structure = "checkbox_grid",
      question_text = parts[4],
      row_label = parts[3],  # Row is 3rd part
      col_label = parts[2]   # Column is 2nd part
    ))

  } else {
    # Unexpected format - treat as simple
    warning(sprintf("Unexpected header format (col %d): %s",
                   col_index, q_num_header))
    return(list(
      col_index = col_index,
      q_num = q_num,
      q_id = q_id,
      structure = "simple",
      question_text = paste(parts[-1], collapse = ":"),
      row_label = NA_character_,
      col_label = NA_character_
    ))
  }
}


#' Extract Leading Number
#'
#' @description Extracts the first number before a colon in a string
#'
#' @param text String to parse
#'
#' @return Character string of the number, or NA
#'
#' @keywords internal
extract_leading_number <- function(text) {
  if (is.na(text) || text == "") {
    return(NA_character_)
  }

  # Extract digits before the first colon
  match <- regexpr("^\\s*(\\d+)\\s*:", text)
  if (match > 0) {
    num_text <- regmatches(text, match)
    # Extract just the digits
    digits <- gsub("[^0-9]", "", num_text)
    return(digits)
  }

  return(NA_character_)
}


#' Group Columns by Question
#'
#' @description
#' Groups parsed columns by question number.
#' Each question can have multiple columns (multi-mention, ranking, grids).
#'
#' @param parsed_columns List of parsed column objects
#'
#' @return Named list of question groups
#'
#' @keywords internal
group_columns_by_question <- function(parsed_columns) {

  questions <- list()

  for (col in parsed_columns) {
    q_num <- col$q_num

    if (is.na(q_num)) {
      warning(sprintf("Skipping column %d with missing Q number", col$col_index))
      next
    }

    # Create question group if it doesn't exist
    if (!(q_num %in% names(questions))) {
      questions[[q_num]] <- list(
        q_num = q_num,
        q_id = col$q_id,
        question_text = col$question_text,
        columns = list(),
        structure = col$structure
      )
    }

    # Add column to question group
    questions[[q_num]]$columns[[length(questions[[q_num]]$columns) + 1]] <- col
  }

  return(questions)
}


#' Detect Grid Type
#'
#' @description
#' Analyzes a question group with multiple columns to determine grid type:
#' - single: One column only
#' - checkbox_grid: 4-part headers, pivot by rows
#' - radio_grid: Multiple rows with different row_labels
#' - star_rating_grid: Row labels are numeric (1,2,3,4,5)
#' - multi_column: Multi-mention or ranking
#'
#' @param question_group Question group with columns
#'
#' @return Grid type classification
#'
#' @keywords internal
detect_grid_type <- function(question_group) {
  # Legacy function - calls new version without hints
  return(detect_grid_type_with_hints(question_group, list()))
}


#' Detect Grid Type with Word Doc Hints
#'
#' @description
#' Improved grid detection using Word doc hints.
#' Uses ( ) vs [ ] brackets to distinguish radio vs checkbox grids.
#'
#' @param question_group Question group with columns
#' @param hints Word doc hints (must include brackets field)
#'
#' @return Grid type classification
#'
#' @keywords internal
detect_grid_type_with_hints <- function(question_group, hints = list()) {

  cols <- question_group$columns
  n_cols <- length(cols)

  # Single column = not a grid
  if (n_cols == 1) {
    return("single")
  }

  # Extract row labels
  row_labels <- sapply(cols, function(c) c$row_label)
  row_labels <- row_labels[!is.na(row_labels)]

  # Check for multiple unique row labels
  unique_rows <- unique(row_labels)

  # PRIORITY 1: Check Word doc brackets first (most reliable source of truth)
  # Word doc brackets override data export map structure field
  if (!is.null(hints$brackets) && !is.na(hints$brackets)) {
    if (hints$brackets == "()") {
      # ( ) brackets = Single mention per row

      # Check for star rating grid pattern (numeric labels like "1", "2", "3")
      if (length(unique_rows) > 1 && all(grepl("^\\d+$", unique_rows))) {
        return("star_rating_grid")
      }

      # Check for star rating grid pattern (e.g., "Item:1", "Item:2", "Item:3")
      if (length(unique_rows) > 1 && all(grepl(":.+:\\d+$", unique_rows))) {
        return("star_rating_grid")
      }

      # Otherwise it's a radio grid (single mention per row)
      # This handles cases where structure == "checkbox_grid" but brackets say ()
      if (length(unique_rows) > 1) {
        return("radio_grid")
      }

    } else if (hints$brackets == "[]") {
      # [ ] brackets = Multi mention

      # Check if this has col_labels (indicates a checkbox grid)
      col_labels <- sapply(cols, function(c) c$col_label)
      has_col_labels <- any(!is.na(col_labels))

      # If NO col_labels, it's a multi-column multi-mention (not a grid)
      if (!has_col_labels) {
        return("multi_column")
      }

      # If each column has different row label, it's a multi-column multi-mention (not a grid)
      if (length(unique_rows) > 1 && length(unique_rows) == n_cols) {
        return("multi_column")
      }

      # If multiple columns share row labels AND has col_labels, it's a checkbox grid
      if (length(unique_rows) > 1 && has_col_labels) {
        return("checkbox_grid")
      }
    }
  }

  # PRIORITY 2: Check data export map structure field
  # Only use this if no Word doc hints available
  if (all(sapply(cols, function(c) c$structure == "checkbox_grid"))) {
    # Could be either checkbox_grid or radio_grid
    # Without Word doc hints, assume checkbox_grid (but this is risky)
    return("checkbox_grid")
  }

  # PRIORITY 3: Heuristics based on row label patterns
  if (length(unique_rows) > 1 && length(unique_rows) == n_cols) {
    # Each column has a unique row label

    # Check for star rating grid pattern
    if (all(grepl(":.+:\\d+$", unique_rows))) {
      return("star_rating_grid")
    }

    # Check if all row labels are purely numeric (star rating grid)
    if (all(grepl("^\\d+$", unique_rows))) {
      return("star_rating_grid")
    }

    # Check row label characteristics
    avg_label_length <- mean(nchar(unique_rows))
    if (avg_label_length > 8) {
      # Likely a radio grid (descriptive labels)
      return("radio_grid")
    }
  }

  # Otherwise multi-column question (multi-mention or ranking)
  return("multi_column")
}
