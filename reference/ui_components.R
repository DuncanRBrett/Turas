# ==============================================================================
# UI COMPONENTS & FILE GENERATION - FIXED VERSION
# ==============================================================================

#' Generate Survey_Structure.xlsx
generate_survey_structure <- function(questions, output_path) {
  
  cat("\n=== GENERATING SURVEY STRUCTURE ===\n")
  
  # Validate inputs
  if (!is.data.frame(questions) || nrow(questions) == 0) {
    stop("questions must be a non-empty data frame")
  }
  
  cat("Questions to export:", nrow(questions), "\n")
  
  # Create workbook
  wb <- openxlsx::createWorkbook()
  
  # ============================================================================
  # SHEET 1: Project
  # ============================================================================
  
  project_data <- data.frame(
    Setting = c(
      "project_name",
      "data_file",
      "analyst",
      "client",
      "survey_date"
    ),
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
  
  # Format header
  header_style <- openxlsx::createStyle(
    fontColour = "#FFFFFF",
    fgFill = "#4F81BD",
    halign = "left",
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "Project", header_style, rows = 1, cols = 1:2, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Project", cols = 1:2, widths = c(20, 50))
  
  # ============================================================================
  # SHEET 2: Questions
  # ============================================================================
  
  questions_data <- data.frame(
    QuestionCode = questions$code,
    QuestionText = questions$text,
    Variable_Type = questions$type,
    Columns = ifelse(is.na(questions$columns), "", questions$columns),
    stringsAsFactors = FALSE
  )
  
  openxlsx::addWorksheet(wb, "Questions")
  openxlsx::writeData(wb, "Questions", questions_data)
  openxlsx::addStyle(wb, "Questions", header_style, rows = 1, cols = 1:4, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Questions", cols = 1:4, widths = c(15, 60, 18, 10))
  openxlsx::freezePane(wb, "Questions", firstRow = TRUE)
  
  # ============================================================================
  # SHEET 3: Options
  # ============================================================================
  
  options_list <- list()
  
  for (i in 1:nrow(questions)) {
    q <- questions[i, ]
    
    # Check if question has numeric bins
    has_bins <- !is.null(q$bins[[1]]) && is.data.frame(q$bins[[1]]) && nrow(q$bins[[1]]) > 0
    
    if (has_bins) {
      # Add bins with Min/Max
      bins <- q$bins[[1]]
      for (j in 1:nrow(bins)) {
        options_list[[length(options_list) + 1]] <- data.frame(
          QuestionCode = q$code,
          OptionText = bins$label[j],
          DisplayText = bins$label[j],
          ShowInOutput = "Y",
          ExcludeFromIndex = "N",
          Min = bins$min[j],
          Max = bins$max[j],
          stringsAsFactors = FALSE
        )
      }
    } else if (length(q$options[[1]]) > 0) {
      # Add regular options
      for (opt in q$options[[1]]) {
        options_list[[length(options_list) + 1]] <- data.frame(
          QuestionCode = q$code,
          OptionText = opt,
          DisplayText = opt,
          ShowInOutput = "Y",
          ExcludeFromIndex = "N",
          Min = NA_integer_,
          Max = NA_integer_,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  
  # Combine into data frame
  if (length(options_list) > 0) {
    options_data <- do.call(rbind, options_list)
  } else {
    # Empty options sheet
    options_data <- data.frame(
      QuestionCode = character(0),
      OptionText = character(0),
      DisplayText = character(0),
      ShowInOutput = character(0),
      ExcludeFromIndex = character(0),
      Min = integer(0),
      Max = integer(0),
      stringsAsFactors = FALSE
    )
  }
  
  openxlsx::addWorksheet(wb, "Options")
  openxlsx::writeData(wb, "Options", options_data)
  openxlsx::addStyle(wb, "Options", header_style, rows = 1, cols = 1:7, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Options", cols = 1:7, widths = c(15, 40, 40, 12, 15, 10, 10))
  openxlsx::freezePane(wb, "Options", firstRow = TRUE)
  
  # Save workbook
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  
  cat("✓ Generated Survey_Structure.xlsx\n")
  cat("  -", nrow(questions_data), "questions\n")
  cat("  -", nrow(options_data), "options\n")
  cat("=== GENERATION COMPLETE ===\n\n")
  
  invisible(NULL)
}

#' Generate Selection Sheet
generate_selection_sheet <- function(questions, output_path) {
  
  cat("\n=== GENERATING SELECTION SHEET ===\n")
  
  # Validate inputs
  if (!is.data.frame(questions) || nrow(questions) == 0) {
    stop("questions must be a non-empty data frame")
  }
  
  cat("Questions to export:", nrow(questions), "\n")
  
  # Create workbook
  wb <- openxlsx::createWorkbook()
  
  # ============================================================================
  # Selection Sheet
  # ============================================================================
  
  selection_data <- data.frame(
    QuestionCode = questions$code,
    Include = "Y",
    UseBanner = "N",
    BannerBoxCategory = "N",
    BannerLabel = "",
    DisplayOrder = 1:nrow(questions),
    CreateIndex = "N",
    BaseFilter = "",
    stringsAsFactors = FALSE
  )
  
  cat("Selection data created:", nrow(selection_data), "rows\n")
  
  openxlsx::addWorksheet(wb, "Selection")
  openxlsx::writeData(wb, "Selection", selection_data)
  
  # Format header
  header_style <- openxlsx::createStyle(
    fontColour = "#FFFFFF",
    fgFill = "#4F81BD",
    halign = "left",
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "Selection", header_style, rows = 1, cols = 1:8, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Selection", cols = 1:8, widths = c(15, 10, 10, 18, 20, 12, 12, 30))
  openxlsx::freezePane(wb, "Selection", firstRow = TRUE)
  
  # Add data validation for Y/N columns
  if (nrow(selection_data) > 0) {
    openxlsx::dataValidation(wb, "Selection", 
                             cols = 2, rows = 2:(nrow(selection_data) + 1), 
                             type = "list", value = '"Y,N"')
    openxlsx::dataValidation(wb, "Selection", 
                             cols = 3, rows = 2:(nrow(selection_data) + 1), 
                             type = "list", value = '"Y,N"')
    openxlsx::dataValidation(wb, "Selection", 
                             cols = 4, rows = 2:(nrow(selection_data) + 1), 
                             type = "list", value = '"Y,N"')
    openxlsx::dataValidation(wb, "Selection", 
                             cols = 7, rows = 2:(nrow(selection_data) + 1), 
                             type = "list", value = '"Y,N"')
  }
  
  # Save workbook
  cat("Saving to:", output_path, "\n")
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  
  cat("✓ Generated Selection_Sheet.xlsx\n")
  cat("  -", nrow(selection_data), "questions\n")
  cat("=== GENERATION COMPLETE ===\n\n")
  
  invisible(NULL)
}
