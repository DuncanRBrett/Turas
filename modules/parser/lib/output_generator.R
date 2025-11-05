# ==============================================================================
# TURAS>PARSER - Output Generator (ENHANCED v1.2.0)
# ==============================================================================
# Purpose: Generate Survey_Structure.xlsx, Selection_Sheet.xlsx, and Data_Headers.xlsx
# Version: 1.2.0 - Added Data_Headers.xlsx output
# ==============================================================================

#' Generate Survey Structure Excel
#' 
#' @description
#' Creates Survey_Structure.xlsx with three sheets:
#' - Project: Metadata
#' - Questions: Question definitions (includes _othertext questions)
#' - Options: Option/bin definitions (with individual codes for multi-mention)
#' 
#' ENHANCEMENTS:
#' - Multi-mention questions now create Q10_1, Q10_2, etc. codes
#' - "Other (specify)" options create separate _othertext questions
#' - _othertext questions have ShowInOutput = "N" by default
#' 
#' @param questions Data frame. Parsed questions
#' @param output_path Character. Where to save file (user can choose)
#' 
#' @export
generate_survey_structure <- function(questions, output_path) {
  
  cat("\n=== GENERATING SURVEY STRUCTURE ===\n")
  
  # Validate
  if (!is.data.frame(questions) || nrow(questions) == 0) {
    stop("questions must be a non-empty data frame", call. = FALSE)
  }
  
  cat("Questions to export:", nrow(questions), "\n")
  
  # CRITICAL: Apply smart question codes BEFORE generating any sheets
  questions$code <- generate_smart_question_codes(nrow(questions))
  
  # Create workbook
  wb <- openxlsx::createWorkbook()
  
  # Sheet 1: Project metadata
  add_project_sheet(wb)
  
  # Sheet 2: Questions (with full column structure + othertext questions)
  add_questions_sheet_enhanced(wb, questions)
  
  # Sheet 3: Options (with full column structure + individual multi-mention codes)
  add_options_sheet_enhanced(wb, questions)
  
  # Save
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  
  cat("✓ Generated Survey_Structure.xlsx\n")
  cat("=== GENERATION COMPLETE ===\n\n")
  
  invisible(NULL)
}

#' Generate Selection Sheet Excel
#' 
#' @description
#' Creates Selection_Sheet.xlsx for crosstab configuration.
#' Applies smart defaults based on question types.
#' 
#' @param questions Data frame. Parsed questions
#' @param output_path Character. Where to save file (user can choose)
#' 
#' @export
generate_selection_sheet <- function(questions, output_path) {
  
  cat("\n=== GENERATING SELECTION SHEET ===\n")
  
  # Validate
  if (!is.data.frame(questions) || nrow(questions) == 0) {
    stop("questions must be a non-empty data frame", call. = FALSE)
  }
  
  cat("Questions to export:", nrow(questions), "\n")
  
  # CRITICAL: Apply smart question codes BEFORE generating sheet
  questions$code <- generate_smart_question_codes(nrow(questions))
  
  # Create workbook
  wb <- openxlsx::createWorkbook()
  
  # Create selection data with smart defaults
  selection_data <- create_selection_data_smart(questions)
  
  # Add sheet
  openxlsx::addWorksheet(wb, "Selection")
  openxlsx::writeData(wb, "Selection", selection_data)
  
  # Format
  header_style <- create_header_style()
  openxlsx::addStyle(wb, "Selection", header_style, 
                     rows = 1, cols = 1:8, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Selection", cols = 1:8, 
                         widths = c(15, 10, 10, 18, 20, 12, 12, 30))
  openxlsx::freezePane(wb, "Selection", firstRow = TRUE)
  
  # Add data validation
  if (nrow(selection_data) > 0) {
    add_selection_validation(wb, nrow(selection_data))
  }
  
  # Save
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  
  cat("✓ Generated Selection_Sheet.xlsx\n")
  cat("=== GENERATION COMPLETE ===\n\n")
  
  invisible(NULL)
}

#' Generate Data Headers Excel
#' 
#' @description
#' Creates Data_Headers.xlsx with a single row of column headers.
#' This file shows exactly what columns should be in the raw data file.
#' 
#' Headers include:
#' - ID (respondent identifier)
#' - All question columns (Q01, Q02, Q10_1, Q10_2, Q10_othertext, etc.)
#' 
#' @param questions Data frame. Parsed questions
#' @param output_path Character. Where to save file (user can choose)
#' 
#' @export
generate_data_headers <- function(questions, output_path) {
  
  cat("\n=== GENERATING DATA HEADERS ===\n")
  
  # Validate
  if (!is.data.frame(questions) || nrow(questions) == 0) {
    stop("questions must be a non-empty data frame", call. = FALSE)
  }
  
  cat("Questions to export:", nrow(questions), "\n")
  
  # CRITICAL: Apply smart question codes BEFORE generating headers
  questions$code <- generate_smart_question_codes(nrow(questions))
  
  # Build header list
  headers <- c("ID")  # Start with ID column
  
  for (i in seq_len(nrow(questions))) {
    q <- questions[i, ]
    q_code <- q$code
    q_type <- q$type
    
    # Check if multi-mention
    is_multi_mention <- !is.na(q_type) && q_type == "Multi_Mention"
    
    if (is_multi_mention) {
      # Get number of columns
      num_columns <- suppressWarnings(as.numeric(q$columns))
      if (is.na(num_columns) || num_columns < 1) {
        num_columns <- length(q$options[[1]])
      }
      
      # Add Q10_1, Q10_2, Q10_3, etc.
      for (col_idx in seq_len(num_columns)) {
        headers <- c(headers, paste0(q_code, "_", col_idx))
      }
      
      # Check if this question has othertext
      if (length(q$options[[1]]) > 0) {
        has_other <- any(sapply(q$options[[1]], is_other_specify))
        if (has_other) {
          headers <- c(headers, paste0(q_code, "_othertext"))
          cat("  Added othertext column:", paste0(q_code, "_othertext"), "\n")
        }
      }
      
    } else {
      # Single column question: Q01, Q02, etc.
      headers <- c(headers, q_code)
      
      # Check if single-mention has othertext
      if (length(q$options[[1]]) > 0) {
        has_other <- any(sapply(q$options[[1]], is_other_specify))
        if (has_other) {
          headers <- c(headers, paste0(q_code, "_othertext"))
          cat("  Added othertext column:", paste0(q_code, "_othertext"), "\n")
        }
      }
    }
  }
  
  cat("Total columns:", length(headers), "\n")
  cat("  - ID column: 1\n")
  cat("  - Question columns:", length(headers) - 1, "\n")
  
  # Create data frame with just the header row
  header_df <- as.data.frame(t(headers))
  colnames(header_df) <- headers
  
  # Remove the data row (we only want headers)
  header_df <- header_df[0, ]
  
  # Create workbook
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Headers")
  
  # Write headers
  openxlsx::writeData(wb, "Headers", header_df, colNames = TRUE, rowNames = FALSE)
  
  # Format header row
  header_style <- create_header_style()
  openxlsx::addStyle(wb, "Headers", header_style, 
                     rows = 1, cols = 1:length(headers), gridExpand = TRUE)
  
  # Set column widths (15 for all columns)
  openxlsx::setColWidths(wb, "Headers", cols = 1:length(headers), widths = 15)
  
  # Freeze header row
  openxlsx::freezePane(wb, "Headers", firstRow = TRUE)
  
  # Save
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  
  cat("✓ Generated Data_Headers.xlsx\n")
  cat("=== GENERATION COMPLETE ===\n\n")
  
  invisible(NULL)
}

# Helper functions ============================================================

#' Smart Question Code Generation
#' 
#' @description
#' Generates question codes with appropriate zero-padding:
#' - 1-99 questions: Q01, Q02, ..., Q99
#' - 100-999 questions: Q001, Q002, ..., Q999
#' - 1000+ questions: Q0001, Q0002, ..., Q9999
#' 
#' @keywords internal
generate_smart_question_codes <- function(n_questions) {
  
  if (n_questions < 100) {
    # Q01, Q02, ..., Q99
    return(sprintf("Q%02d", seq_len(n_questions)))
  } else if (n_questions < 1000) {
    # Q001, Q002, ..., Q999
    return(sprintf("Q%03d", seq_len(n_questions)))
  } else {
    # Q0001, Q0002, ..., Q9999
    return(sprintf("Q%04d", seq_len(n_questions)))
  }
}

#' Detect "Other (specify)" Options
#' 
#' @description
#' Identifies options that indicate open-ended text input.
#' Common patterns:
#' - "Other - (specify)"
#' - "Other (please specify)"
#' - "Other - Write In"
#' - Any option containing "specify", "write in", "please state", etc.
#' 
#' @param option_text Character. Option text to check
#' @return Logical. TRUE if this is an "other specify" option
#' 
#' @keywords internal
is_other_specify <- function(option_text) {
  if (is.na(option_text) || option_text == "") return(FALSE)
  
  option_lower <- tolower(option_text)
  
  # Check for common "other specify" patterns
  patterns <- c(
    "other.*specify",
    "other.*write",
    "other.*please",
    "specify.*other",
    "write.*in",
    "please.*state",
    "please.*explain"
  )
  
  any(sapply(patterns, function(p) grepl(p, option_lower)))
}

#' Add Project Sheet
#' @keywords internal
add_project_sheet <- function(wb) {
  
  project_data <- data.frame(
    Setting = c("project_name", "data_file", "analyst", "client", "survey_date"),
    Value = c(
      "Generated Survey Structure",
      "Data/survey_data.xlsx",
      "",
      "",
      format(Sys.Date(), "%Y-%m-%d")
    ),
    stringsAsFactors = FALSE
  )
  
  openxlsx::addWorksheet(wb, "Project")
  openxlsx::writeData(wb, "Project", project_data)
  
  header_style <- create_header_style()
  openxlsx::addStyle(wb, "Project", header_style, 
                     rows = 1, cols = 1:2, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Project", cols = 1:2, widths = c(20, 50))
}

#' Add Questions Sheet with Full Column Structure (ENHANCED)
#' 
#' @description
#' Creates Questions sheet including:
#' - Original questions
#' - Auto-generated _othertext questions for "other specify" options
#' 
#' @keywords internal
add_questions_sheet_enhanced <- function(wb, questions) {
  
  questions_list <- list()
  
  # Add original questions
  for (i in seq_len(nrow(questions))) {
    q <- questions[i, ]
    
    questions_list[[length(questions_list) + 1]] <- data.frame(
      QuestionCode = q$code,
      QuestionText = q$text,
      Variable_Type = q$type,
      Columns = ifelse(is.na(q$columns), "", q$columns),
      Ranking_Format = "",
      Ranking_Positions = "",
      Ranking_Direction = "",
      Category = "",
      Notes = "",
      Min_Value = ifelse(is.na(q$min_value), "", q$min_value),
      Max_Value = ifelse(is.na(q$max_value), "", q$max_value),
      stringsAsFactors = FALSE
    )
    
    # Check if this question has "other specify" options
    if (length(q$options[[1]]) > 0) {
      for (opt in q$options[[1]]) {
        if (is_other_specify(opt)) {
          # Add _othertext question
          othertext_code <- paste0(q$code, "_othertext")
          
          questions_list[[length(questions_list) + 1]] <- data.frame(
            QuestionCode = othertext_code,
            QuestionText = paste0(q$text, " - Other (specify)"),
            Variable_Type = "Open_End",
            Columns = "",
            Ranking_Format = "",
            Ranking_Positions = "",
            Ranking_Direction = "",
            Category = "",
            Notes = "Auto-generated for 'other specify' option",
            Min_Value = "",
            Max_Value = "",
            stringsAsFactors = FALSE
          )
          
          cat("  ℹ Created othertext question:", othertext_code, "\n")
          break  # Only create one _othertext per question
        }
      }
    }
  }
  
  questions_data <- do.call(rbind, questions_list)
  
  openxlsx::addWorksheet(wb, "Questions")
  openxlsx::writeData(wb, "Questions", questions_data)
  
  header_style <- create_header_style()
  openxlsx::addStyle(wb, "Questions", header_style, 
                     rows = 1, cols = 1:11, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Questions", cols = 1:11, 
                         widths = c(15, 60, 18, 10, 15, 17, 17, 12, 30, 10, 10))
  openxlsx::freezePane(wb, "Questions", firstRow = TRUE)
}

#' Add Options Sheet with Full Column Structure (ENHANCED)
#' 
#' @description
#' Creates Options sheet with:
#' - Individual codes for multi-mention (Q10_1, Q10_2, etc.)
#' - Separate _othertext entries with ShowInOutput = "N"
#' 
#' @keywords internal
add_options_sheet_enhanced <- function(wb, questions) {
  
  options_list <- list()
  display_order <- 1
  
  for (i in seq_len(nrow(questions))) {
    q <- questions[i, ]
    is_multi_mention <- !is.na(q$type) && q$type == "Multi_Mention"
    
    # Determine number of columns for multi-mention
    num_columns <- 1
    if (is_multi_mention) {
      num_columns <- suppressWarnings(as.numeric(q$columns))
      if (is.na(num_columns) || num_columns < 1) {
        num_columns <- length(q$options[[1]])  # Fall back to option count
      }
    }
    
    # Check for numeric bins
    has_bins <- !is.null(q$bins[[1]]) && 
                is.data.frame(q$bins[[1]]) && 
                nrow(q$bins[[1]]) > 0
    
    if (has_bins) {
      # Add bins with Min/Max
      bins <- q$bins[[1]]
      for (j in seq_len(nrow(bins))) {
        options_list[[length(options_list) + 1]] <- data.frame(
          QuestionCode = q$code,
          OptionText = bins$label[j],
          DisplayText = bins$label[j],
          DisplayOrder = display_order,
          ShowInOutput = "Y",
          ExcludeFromIndex = "N",
          Index_Weight = "",
          BoxCategory = "",
          Min = bins$min[j],
          Max = bins$max[j],
          stringsAsFactors = FALSE
        )
        display_order <- display_order + 1
      }
      
    } else if (length(q$options[[1]]) > 0) {
      # Add regular options
      option_idx <- 1
      has_othertext <- FALSE
      
      for (opt in q$options[[1]]) {
        
        # Determine question code for this option
        if (is_multi_mention) {
          # Multi-mention: Use Q10_1, Q10_2, etc.
          option_code <- paste0(q$code, "_", option_idx)
          cat("  → Multi-mention option:", option_code, "-", opt, "\n")
        } else {
          # Single mention: Use base code Q10
          option_code <- q$code
        }
        
        # Check if this is an "other specify" option
        is_other <- is_other_specify(opt)
        
        if (is_other) {
          has_othertext <- TRUE
          cat("  ℹ Detected 'other specify' option:", opt, "\n")
        }
        
        # Add the option
        options_list[[length(options_list) + 1]] <- data.frame(
          QuestionCode = option_code,
          OptionText = opt,
          DisplayText = opt,
          DisplayOrder = display_order,
          ShowInOutput = "Y",
          ExcludeFromIndex = ifelse(is_other, "Y", "N"),
          Index_Weight = "",
          BoxCategory = "",
          Min = NA_integer_,
          Max = NA_integer_,
          stringsAsFactors = FALSE
        )
        display_order <- display_order + 1
        option_idx <- option_idx + 1
      }
      
      # Add _othertext option row if "other specify" detected
      if (has_othertext) {
        othertext_code <- paste0(q$code, "_othertext")
        
        options_list[[length(options_list) + 1]] <- data.frame(
          QuestionCode = othertext_code,
          OptionText = "Open-ended text response",
          DisplayText = "Other (specify)",
          DisplayOrder = display_order,
          ShowInOutput = "N",  # Default to hidden
          ExcludeFromIndex = "Y",
          Index_Weight = "",
          BoxCategory = "",
          Min = NA_integer_,
          Max = NA_integer_,
          stringsAsFactors = FALSE
        )
        display_order <- display_order + 1
        
        cat("  ✓ Added othertext option:", othertext_code, "(ShowInOutput = N)\n")
      }
    }
  }
  
  # Combine or create empty
  if (length(options_list) > 0) {
    options_data <- do.call(rbind, options_list)
  } else {
    options_data <- create_empty_options_df_full()
  }
  
  openxlsx::addWorksheet(wb, "Options")
  openxlsx::writeData(wb, "Options", options_data)
  
  header_style <- create_header_style()
  openxlsx::addStyle(wb, "Options", header_style, 
                     rows = 1, cols = 1:10, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Options", cols = 1:10, 
                         widths = c(15, 40, 40, 12, 12, 15, 12, 12, 10, 10))
  openxlsx::freezePane(wb, "Options", firstRow = TRUE)
}

#' Create Selection Data with Smart Defaults
#' @keywords internal
create_selection_data_smart <- function(questions) {
  
  selection_data <- data.frame(
    QuestionCode = questions$code,
    Include = "Y",
    UseBanner = "N",
    BannerBoxCategory = "N",
    BannerLabel = "",
    DisplayOrder = seq_len(nrow(questions)),
    CreateIndex = "N",
    BaseFilter = "",
    stringsAsFactors = FALSE
  )
  
  # Apply smart defaults based on question type
  for (i in seq_len(nrow(questions))) {
    q_type <- questions$type[i]
    
    # Open_End questions default to Include = N
    if (q_type == "Open_End") {
      selection_data$Include[i] <- "N"
    }
    
    # Rating scales and NPS default to CreateIndex = Y
    if (q_type %in% c("Rating", "NPS")) {
      selection_data$CreateIndex[i] <- "Y"
    }
  }
  
  return(selection_data)
}

#' Create Header Style
#' @keywords internal
create_header_style <- function() {
  openxlsx::createStyle(
    fontColour = "#FFFFFF",
    fgFill = "#4F81BD",
    halign = "left",
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
}

#' Create Empty Options DataFrame with Full Structure
#' @keywords internal
create_empty_options_df_full <- function() {
  data.frame(
    QuestionCode = character(0),
    OptionText = character(0),
    DisplayText = character(0),
    DisplayOrder = integer(0),
    ShowInOutput = character(0),
    ExcludeFromIndex = character(0),
    Index_Weight = character(0),
    BoxCategory = character(0),
    Min = integer(0),
    Max = integer(0),
    stringsAsFactors = FALSE
  )
}

#' Add Selection Validation
#' @keywords internal
add_selection_validation <- function(wb, n_rows) {
  
  # Y/N dropdowns for columns 2, 3, 4, 7
  for (col in c(2, 3, 4, 7)) {
    openxlsx::dataValidation(
      wb, "Selection",
      cols = col,
      rows = 2:(n_rows + 1),
      type = "list",
      value = '"Y,N"'
    )
  }
}
