# ==============================================================================
# ALCHEMER PARSER - OUTPUT GENERATION
# ==============================================================================
# Generate output files for Tabs module
# Creates: Crosstab_Config.xlsx, Survey_Structure.xlsx, Data_Headers.xlsx
# ==============================================================================

#' Generate Output Files
#'
#' @description
#' Generates all three output files:
#' 1. Crosstab_Config.xlsx (Selection sheet)
#' 2. Survey_Structure.xlsx (Questions and Options sheets)
#' 3. Data_Headers.xlsx (Column headers for data file)
#'
#' @param questions Classified questions with codes
#' @param project_name Project name for file naming
#' @param output_dir Output directory
#' @param validation_flags Validation flags from parsing
#' @param verbose Print progress messages
#'
#' @return List with paths to generated files
#'
#' @keywords internal
generate_output_files <- function(questions, project_name, output_dir,
                                  validation_flags = list(), verbose = FALSE) {

  # Check required package
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')",
         call. = FALSE)
  }

  # Generate file paths with "_parsed" suffix to distinguish from templates
  crosstab_file <- file.path(output_dir,
                             paste0(project_name, "_Crosstab_Config_parsed.xlsx"))
  survey_file <- file.path(output_dir,
                           paste0(project_name, "_Survey_Structure_parsed.xlsx"))
  headers_file <- file.path(output_dir,
                            paste0(project_name, "_Data_Headers_parsed.xlsx"))

  # ===========================================================================
  # Generate Crosstab_Config (Selection sheet)
  # ===========================================================================
  if (verbose) {
    cat("  Generating Crosstab_Config...\n")
  }

  crosstab_data <- generate_crosstab_config(questions)

  wb_crosstab <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb_crosstab, "Selection")
  openxlsx::writeData(wb_crosstab, "Selection", crosstab_data,
                     startRow = 1, startCol = 1, colNames = TRUE)

  # Format headers
  openxlsx::addStyle(wb_crosstab, "Selection",
                    style = openxlsx::createStyle(textDecoration = "bold"),
                    rows = 1, cols = 1:ncol(crosstab_data), gridExpand = TRUE)

  openxlsx::saveWorkbook(wb_crosstab, crosstab_file, overwrite = TRUE)

  # ===========================================================================
  # Generate Survey_Structure (Questions and Options sheets)
  # ===========================================================================
  if (verbose) {
    cat("  Generating Survey_Structure...\n")
  }

  survey_data <- generate_survey_structure(questions)

  wb_survey <- openxlsx::createWorkbook()

  # Questions sheet
  openxlsx::addWorksheet(wb_survey, "Questions")
  openxlsx::writeData(wb_survey, "Questions", survey_data$questions,
                     startRow = 1, startCol = 1, colNames = TRUE)
  openxlsx::addStyle(wb_survey, "Questions",
                    style = openxlsx::createStyle(textDecoration = "bold"),
                    rows = 1, cols = 1:ncol(survey_data$questions),
                    gridExpand = TRUE)

  # Options sheet
  openxlsx::addWorksheet(wb_survey, "Options")
  openxlsx::writeData(wb_survey, "Options", survey_data$options,
                     startRow = 1, startCol = 1, colNames = TRUE)
  openxlsx::addStyle(wb_survey, "Options",
                    style = openxlsx::createStyle(textDecoration = "bold"),
                    rows = 1, cols = 1:ncol(survey_data$options),
                    gridExpand = TRUE)

  openxlsx::saveWorkbook(wb_survey, survey_file, overwrite = TRUE)

  # ===========================================================================
  # Generate Data_Headers
  # ===========================================================================
  if (verbose) {
    cat("  Generating Data_Headers...\n")
  }

  headers_data <- generate_data_headers(questions)

  wb_headers <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb_headers, "Headers")
  openxlsx::writeData(wb_headers, "Headers", headers_data,
                     startRow = 1, startCol = 1, colNames = FALSE)

  openxlsx::saveWorkbook(wb_headers, headers_file, overwrite = TRUE)

  return(list(
    crosstab_config = crosstab_file,
    survey_structure = survey_file,
    data_headers = headers_file
  ))
}


#' Generate Crosstab Config
#'
#' @description
#' Generates the Crosstab_Config Selection sheet data.
#'
#' @param questions Classified questions
#'
#' @return Data frame for Selection sheet
#'
#' @keywords internal
generate_crosstab_config <- function(questions) {

  rows <- list()

  # Add ResponseID row
  rows[[1]] <- data.frame(
    QuestionCode = "ResponseID",
    Include = NA,
    UseBanner = NA,
    BannerBoxCategory = NA,
    BannerLabel = NA,
    DisplayOrder = NA,
    CreateIndex = "N",
    BaseFilter = NA,
    QuestionText = "Response ID",
    stringsAsFactors = FALSE
  )

  # Process each question
  for (q_num in names(questions)) {
    q <- questions[[q_num]]

    if (q$is_grid) {
      # Grid questions - add each sub-question
      for (suffix in names(q$sub_questions)) {
        sub_q <- q$sub_questions[[suffix]]

        # For multi-column sub-questions, add each column
        if (sub_q$variable_type == "Multi_Mention") {
          for (code in sub_q$q_codes) {
            rows[[length(rows) + 1]] <- create_crosstab_row(
              code,
              sub_q$question_text,
              sub_q$variable_type
            )
          }
        } else {
          rows[[length(rows) + 1]] <- create_crosstab_row(
            sub_q$q_code,
            sub_q$question_text,
            sub_q$variable_type
          )
        }
      }

    } else {
      # Non-grid question
      # Crosstab_Config shows only the base question code (Q01, Q04)
      # Not the individual columns (Q04_1, Q04_2, etc.)
      rows[[length(rows) + 1]] <- create_crosstab_row(
        q$q_code,
        q$question_text,
        q$variable_type
      )
    }
  }

  # Combine into data frame
  do.call(rbind, rows)
}


#' Create Crosstab Row
#'
#' @description Creates a single row for Crosstab_Config
#'
#' @keywords internal
create_crosstab_row <- function(q_code, q_text, var_type) {

  # Determine CreateIndex based on variable type
  create_index <- if (var_type %in% c("NPS", "Rating", "Likert")) "Y" else "N"

  # Check if othermention field
  include_val <- if (grepl("_othermention", q_code)) "N" else NA

  data.frame(
    QuestionCode = q_code,
    Include = include_val,
    UseBanner = NA,
    BannerBoxCategory = NA,
    BannerLabel = NA,
    DisplayOrder = NA,
    CreateIndex = create_index,
    BaseFilter = NA,
    QuestionText = q_text,
    stringsAsFactors = FALSE
  )
}


#' Generate Survey Structure
#'
#' @description
#' Generates Questions and Options sheets for Survey_Structure.
#'
#' @param questions Classified questions
#'
#' @return List with questions and options data frames
#'
#' @keywords internal
generate_survey_structure <- function(questions) {

  question_rows <- list()
  option_rows <- list()

  for (q_num in names(questions)) {
    q <- questions[[q_num]]

    if (q$is_grid) {
      # Grid questions
      for (suffix in names(q$sub_questions)) {
        sub_q <- q$sub_questions[[suffix]]

        # Calculate correct column count (exclude othertext/othermention)
        display_columns <- calculate_display_columns(sub_q)

        # Add question row
        question_rows[[length(question_rows) + 1]] <- create_question_row(
          sub_q$q_code,
          sub_q$question_text,
          sub_q$variable_type,
          display_columns
        )

        # Add option rows
        opts <- create_option_rows(sub_q)
        option_rows <- c(option_rows, opts)
      }

    } else {
      # Non-grid question
      # Calculate correct column count (exclude othertext/othermention)
      display_columns <- calculate_display_columns(q)

      question_rows[[length(question_rows) + 1]] <- create_question_row(
        q$q_code,
        q$question_text,
        q$variable_type,
        display_columns
      )

      # Add option rows
      opts <- create_option_rows(q)
      option_rows <- c(option_rows, opts)
    }
  }

  list(
    questions = do.call(rbind, question_rows),
    options = do.call(rbind, option_rows)
  )
}


#' Calculate Display Columns
#'
#' @description
#' Calculates the number of columns to display in Survey_Structure.
#' Excludes othertext/othermention auxiliary columns.
#'
#' @keywords internal
calculate_display_columns <- function(q) {
  var_type <- q$variable_type

  # Single_Response always shows 1 column (even with othermention)
  if (var_type == "Single_Response") {
    return(1)
  }

  # For other types, count non-othertext columns
  if (!is.null(q$q_codes)) {
    # Handle both single string and vector
    codes <- if (is.list(q$q_codes)) unlist(q$q_codes) else q$q_codes

    # If we have multiple codes, count non-auxiliary ones
    if (length(codes) > 1) {
      # Count codes that don't end with "othertext" or "_othermention"
      main_codes <- !grepl("othertext$|_othermention$", codes)
      return(sum(main_codes))
    } else if (length(codes) == 1 && !grepl("othertext$|_othermention$", codes)) {
      # Single code that's not othertext
      return(1)
    }
  }

  # Default to n_columns
  return(q$n_columns %||% 1)
}


#' Create Question Row
#'
#' @description Creates a single row for Questions sheet
#'
#' @keywords internal
create_question_row <- function(q_code, q_text, var_type, n_cols) {

  # Set Ranking_Format if applicable
  ranking_format <- if (var_type == "Ranking" && n_cols > 1) {
    "position"
  } else {
    NA
  }

  data.frame(
    QuestionCode = q_code,
    QuestionText = q_text,
    Variable_Type = var_type,
    Columns = n_cols,
    Ranking_Format = ranking_format,
    Ranking_Positions = NA,
    Ranking_Direction = NA,
    Category = NA,
    Notes = NA,
    stringsAsFactors = FALSE
  )
}


#' Create Option Rows
#'
#' @description
#' Creates option rows for a question.
#'
#' @param q Question object
#'
#' @return List of option row data frames
#'
#' @keywords internal
create_option_rows <- function(q) {

  rows <- list()

  if (q$variable_type == "Multi_Mention") {
    # Multi-mention: one row per column
    col_labels <- if (!is.null(q$col_labels)) {
      q$col_labels
    } else {
      sapply(q$columns, function(c) c$row_label)
    }

    codes <- if (!is.null(q$q_codes) && length(q$q_codes) > 1) {
      q$q_codes
    } else {
      paste0(q$q_code, "_", seq_along(col_labels))
    }

    for (i in seq_along(col_labels)) {
      label <- col_labels[i]
      code <- codes[i]

      # Hide othertext and othermention fields
      show_output <- if (grepl("othertext$|_othermention$", code)) "N" else "Y"

      rows[[i]] <- data.frame(
        QuestionCode = code,
        OptionText = label,
        DisplayText = label,
        DisplayOrder = NA,
        ShowInOutput = show_output,
        ExcludeFromIndex = NA,
        Index_Weight = NA,
        BoxCategory = NA,
        stringsAsFactors = FALSE
      )
    }

  } else if (q$variable_type %in% c("Single_Response", "Rating", "Likert", "NPS")) {
    # Options from translation
    options <- q$options

    for (i in seq_along(options)) {
      opt <- options[[i]]

      # Check if should exclude from index
      exclude_from_index <- check_exclude_from_index(opt$text, q$variable_type)

      rows[[i]] <- data.frame(
        QuestionCode = q$q_code,
        OptionText = opt$text,
        DisplayText = opt$text,
        DisplayOrder = NA,
        ShowInOutput = "Y",
        ExcludeFromIndex = if (exclude_from_index) "Y" else NA,
        Index_Weight = NA,
        BoxCategory = NA,
        stringsAsFactors = FALSE
      )
    }

  } else if (q$variable_type == "Ranking") {
    # Ranking: options are items being ranked
    # Use q_codes (Q12_1, Q12_2, Q12_3) not just q_code
    items <- sapply(q$columns, function(c) c$row_label)
    unique_items <- unique(items)

    codes <- if (!is.null(q$q_codes) && length(q$q_codes) == length(unique_items)) {
      q$q_codes
    } else {
      paste0(q$q_code, "_", seq_along(unique_items))
    }

    for (i in seq_along(unique_items)) {
      item <- unique_items[i]
      code <- codes[i]

      rows[[i]] <- data.frame(
        QuestionCode = code,  # Use Q12_1, Q12_2, Q12_3 not just Q12
        OptionText = item,
        DisplayText = item,
        DisplayOrder = NA,
        ShowInOutput = "Y",
        ExcludeFromIndex = NA,
        Index_Weight = NA,
        BoxCategory = NA,
        stringsAsFactors = FALSE
      )
    }
  }

  # If no options created, return empty data frame with correct structure
  if (length(rows) == 0) {
    return(list(data.frame(
      QuestionCode = character(0),
      OptionText = character(0),
      DisplayText = character(0),
      DisplayOrder = character(0),
      ShowInOutput = character(0),
      ExcludeFromIndex = character(0),
      Index_Weight = character(0),
      BoxCategory = character(0),
      stringsAsFactors = FALSE
    )))
  }

  rows
}


#' Check Exclude from Index
#'
#' @description
#' Checks if an option should be excluded from index calculation.
#'
#' @keywords internal
check_exclude_from_index <- function(option_text, var_type) {

  if (!(var_type %in% c("Likert", "NPS", "Rating"))) {
    return(FALSE)
  }

  opt_lower <- tolower(trimws(option_text))

  exclude_patterns <- c(
    "don't know",
    "dont know",
    "^dk$",
    "not applicable",
    "^na$",
    "^n/a$",
    "prefer not"
  )

  for (pattern in exclude_patterns) {
    if (grepl(pattern, opt_lower)) {
      return(TRUE)
    }
  }

  return(FALSE)
}


#' Generate Data Headers
#'
#' @description
#' Generates data headers row for renaming columns in data file.
#'
#' @param questions Classified questions
#'
#' @return Single-row data frame with headers
#'
#' @keywords internal
generate_data_headers <- function(questions) {

  headers <- c("ResponseID")

  # Extract all question codes in order
  q_nums <- sort(as.integer(names(questions)))

  for (q_num in q_nums) {
    q <- questions[[as.character(q_num)]]

    if (q$is_grid) {
      # Grid: add sub-question codes
      for (suffix in names(q$sub_questions)) {
        sub_q <- q$sub_questions[[suffix]]

        if (is.list(sub_q$q_codes) || length(sub_q$q_codes) > 1) {
          headers <- c(headers, sub_q$q_codes)
        } else {
          headers <- c(headers, sub_q$q_code)
        }
      }

    } else {
      # Non-grid
      if (length(q$q_codes) > 1) {
        # Convert _othermention to _othertext for display
        codes <- gsub("_othermention$", "_othertext", q$q_codes)
        headers <- c(headers, codes)
      } else {
        headers <- c(headers, q$q_code)
      }
    }
  }

  # Convert any remaining _othermention to _othertext for display
  headers <- gsub("_othermention$", "_othertext", headers)

  # Create single-row data frame
  as.data.frame(t(headers), stringsAsFactors = FALSE)
}
