# ==============================================================================
# TURAS>TABS - BANNER STRUCTURE MODULE
# ==============================================================================
# Purpose: Create banner (column) structure for crosstabs
# Dependencies: config_loader, core/validation
# Author: Turas Analytics Toolkit
# Version: 1.0.0
# ==============================================================================

# Constants
TOTAL_COLUMN <- "Total"

#' Create Complete Banner Structure
#' 
#' Main entry point for creating banner structure from selection
#' Creates all banner columns, internal keys, letters, and metadata
#' 
#' @param selection_df Data frame from Selection sheet
#' @param survey_structure List with questions and options
#' @return List with complete banner metadata
#' @export
#' @examples
#' banner <- create_banner_structure(selection_df, survey_structure)
create_banner_structure <- function(selection_df, survey_structure) {
  
  # Validate inputs
  if (is.null(selection_df) || !is.data.frame(selection_df)) {
    stop("selection_df must be a data frame")
  }
  
  if (!"QuestionCode" %in% names(selection_df)) {
    stop("selection_df must have QuestionCode column")
  }
  
  # Extract banner questions
  banner_questions <- selection_df[
    selection_df$UseBanner == "Y" & !is.na(selection_df$UseBanner), 
  ]
  
  # If no banner questions, return Total-only structure
  if (nrow(banner_questions) == 0) {
    return(create_total_only_banner())
  }
  
  # Sort by display order if available
  if ("DisplayOrder" %in% names(banner_questions) && 
      !all(is.na(banner_questions$DisplayOrder))) {
    banner_questions <- banner_questions[
      order(banner_questions$DisplayOrder, na.last = TRUE), 
    ]
  }
  
  # Initialize with Total column
  all_columns <- TOTAL_COLUMN
  all_internal_keys <- paste0("TOTAL::", TOTAL_COLUMN)
  all_letters <- "-"
  column_to_banner <- setNames(TOTAL_COLUMN, all_internal_keys[1])
  key_to_display <- setNames(TOTAL_COLUMN, all_internal_keys[1])
  all_banner_info <- list()
  banner_headers <- data.frame(
    start_col = numeric(), 
    end_col = numeric(), 
    label = character(),
    stringsAsFactors = FALSE
  )
  
  current_col_index <- 2  # Start after Total
  
  # Process each banner question
  for (banner_idx in seq_len(nrow(banner_questions))) {
    
    result <- process_banner_question(
      banner_questions, 
      banner_idx, 
      survey_structure,
      current_col_index
    )
    
    if (is.null(result)) next
    
    # Add columns
    all_columns <- c(all_columns, result$columns)
    all_internal_keys <- c(all_internal_keys, result$internal_keys)
    all_letters <- c(all_letters, result$letters)
    
    # Add mappings
    for (i in seq_along(result$columns)) {
      column_to_banner[result$internal_keys[i]] <- result$banner_code
      key_to_display[result$internal_keys[i]] <- result$columns[i]
    }
    
    # Add banner header
    banner_label <- get_banner_label(banner_questions, banner_idx)
    
    banner_headers <- rbind(banner_headers, data.frame(
      start_col = current_col_index,
      end_col = current_col_index + length(result$columns) - 1,
      label = banner_label,
      stringsAsFactors = FALSE
    ))
    
    # Store banner info
    all_banner_info[[result$banner_code]] <- c(
      list(
        question = result$question_info,
        options = result$options,
        is_boxcategory = result$is_boxcategory
      ),
      result$banner_data
    )
    
    current_col_index <- current_col_index + length(result$columns)
  }
  
  return(list(
    banner_questions = banner_questions,
    banner_info = all_banner_info,
    banner_headers = banner_headers,
    columns = all_columns,
    internal_keys = all_internal_keys,
    column_labels = all_columns,
    letters = all_letters,
    column_to_banner = column_to_banner,
    key_to_display = key_to_display
  ))
}

# ==============================================================================
# BANNER QUESTION PROCESSING
# ==============================================================================

#' Process Single Banner Question
#' 
#' Processes a single banner question and creates its columns
#' 
#' @param banner_questions Data frame of all banner questions
#' @param banner_idx Index of current banner question
#' @param survey_structure Survey structure
#' @param start_col Starting column index
#' @return List with banner data or NULL if error
#' @export
process_banner_question <- function(banner_questions, banner_idx, 
                                     survey_structure, start_col) {
  
  banner_code <- banner_questions$QuestionCode[banner_idx]
  
  # Get question info
  question_info <- survey_structure$questions[
    survey_structure$questions$QuestionCode == banner_code, 
  ]
  
  if (nrow(question_info) == 0) {
    # TRS v1.0: Banner question not found is a config error - refuse
    tabs_refuse(
      code = "CFG_BANNER_QUESTION_NOT_FOUND",
      title = paste0("Banner Question Not Found: ", banner_code),
      problem = paste0("Banner question '", banner_code, "' is listed in config but not found in Survey_Structure."),
      why_it_matters = "The banner structure cannot be built without valid question definitions.",
      how_to_fix = c(
        "Check that the QuestionCode in Tabs_Config matches Survey_Structure",
        "Verify the question exists in the Questions sheet",
        "Check for typos in the question code"
      )
    )
  }
  
  question_info <- question_info[1, ]
  
  # Check if box/category banner
  is_boxcategory <- !is.na(banner_questions$BannerBoxCategory[banner_idx]) &&
                    banner_questions$BannerBoxCategory[banner_idx] == "Y"
  
  # Get options
  options <- survey_structure$options[
    survey_structure$options$QuestionCode == banner_code &
    (survey_structure$options$ShowInOutput == "Y" | 
     is.na(survey_structure$options$ShowInOutput)), 
  ]
  
  # Sort options by display order if available
  if ("DisplayOrder" %in% names(options) && 
      !all(is.na(options$DisplayOrder))) {
    options <- options[
      order(options$DisplayOrder, na.last = TRUE), 
    ]
  }
  
  # Process based on type
  banner_data <- if (is_boxcategory) {
    process_boxcategory_banner(banner_code, options, start_col)
  } else {
    process_standard_banner(banner_code, question_info, options, start_col)
  }
  
  if (is.null(banner_data)) {
    return(NULL)
  }
  
  return(list(
    banner_code = banner_code,
    question_info = question_info,
    options = options,
    is_boxcategory = is_boxcategory,
    columns = banner_data$columns,
    internal_keys = banner_data$internal_keys,
    letters = banner_data$letters,
    banner_data = banner_data
  ))
}

# ==============================================================================
# STANDARD BANNER PROCESSING
# ==============================================================================

#' Process Standard Banner Question
#' 
#' Creates banner columns for a standard question (single/multi choice)
#' Each response option becomes a banner column
#' 
#' @param banner_code Question code
#' @param question_info Question information
#' @param options Response options
#' @param start_col Starting column index
#' @return List with columns, keys, and letters
#' @export
process_standard_banner <- function(banner_code, question_info, options, start_col) {
  
  if (nrow(options) == 0) {
    # TRS v1.0: No options for banner is a config error - refuse
    tabs_refuse(
      code = "CFG_BANNER_NO_OPTIONS",
      title = paste0("No Options for Banner: ", banner_code),
      problem = paste0("Banner question '", banner_code, "' has no response options defined."),
      why_it_matters = "Banner columns cannot be created without response options.",
      how_to_fix = c(
        "Add response options to the Options sheet for this question",
        "Ensure ShowInOutput is set to 'Y' for options you want as banner columns",
        "Check that the QuestionCode matches between Questions and Options sheets"
      )
    )
  }
  
  # Create column labels from DisplayText
  banner_columns <- options$DisplayText
  
  # Create internal keys for data lookup
  banner_internal_keys <- paste0(banner_code, "::", banner_columns)
  
  # Generate Excel column letters (A, B, C, etc.)
  num_cols <- length(banner_columns)
  banner_letters <- generate_excel_letters(num_cols)
  
  return(list(
    columns = banner_columns,
    internal_keys = banner_internal_keys,
    letters = banner_letters,
    boxcat_groups = NULL,
    column_type = "standard"
  ))
}

# ==============================================================================
# BOX/CATEGORY BANNER PROCESSING
# ==============================================================================

#' Process Box/Category Banner Question
#' 
#' BOXCATEGORY LOGIC:
#' - Groups response options into categories based on BoxCategory field
#' - Each category becomes a banner column
#' - For multi-mention questions: Uses OR logic across all options in category
#' - Respondent included if they mentioned ANY option in the category
#' 
#' @param banner_code Question code
#' @param options Response options with BoxCategory field
#' @param start_col Starting column index
#' @return List with columns, keys, and letters
#' @export
process_boxcategory_banner <- function(banner_code, options, start_col) {
  
  # Extract unique categories
  box_categories <- unique(options$BoxCategory)
  box_categories <- box_categories[!is.na(box_categories) & box_categories != ""]
  
  if (length(box_categories) == 0) {
    # TRS v1.0: No BoxCategory values is a config error - refuse
    tabs_refuse(
      code = "CFG_BANNER_NO_BOXCATEGORY",
      title = paste0("No BoxCategory Values for Banner: ", banner_code),
      problem = paste0("Banner '", banner_code, "' is configured as BoxCategory but no BoxCategory values are defined."),
      why_it_matters = "BoxCategory banners require BoxCategory values in the Options sheet to create column groups.",
      how_to_fix = c(
        "Add BoxCategory values to the Options sheet for this question",
        "Or change BannerBoxCategory to 'N' in Tabs_Config to use standard banner format"
      )
    )
  }
  
  # Create columns for each category
  banner_columns <- box_categories
  
  # Create internal keys with BOXCAT prefix
  banner_internal_keys <- paste0(banner_code, "::BOXCAT::", box_categories)
  
  # Generate Excel column letters
  num_cols <- length(banner_columns)
  banner_letters <- generate_excel_letters(num_cols)
  
  # Create option groups for each category
  boxcat_option_groups <- lapply(box_categories, function(cat) {
    options$OptionText[options$BoxCategory == cat]
  })
  names(boxcat_option_groups) <- box_categories
  
  return(list(
    columns = banner_columns,
    internal_keys = banner_internal_keys,
    letters = banner_letters,
    boxcat_groups = boxcat_option_groups,
    column_type = "boxcategory"
  ))
}

# ==============================================================================
# BANNER LABELS
# ==============================================================================

#' Get Banner Label
#' 
#' Extracts display label for banner question
#' Priority: BannerLabel > QuestionText > QuestionCode
#' 
#' @param banner_questions Data frame of banner questions
#' @param idx Index of current question
#' @return Character label
#' @export
get_banner_label <- function(banner_questions, idx) {
  
  label <- tryCatch({
    # Try BannerLabel field first
    if ("BannerLabel" %in% names(banner_questions)) {
      label <- banner_questions$BannerLabel[idx]
      if (!is.null(label) && !is.na(label) && label != "") {
        return(as.character(label))
      }
    }
    
    # Try QuestionText field
    if ("QuestionText" %in% names(banner_questions)) {
      label <- banner_questions$QuestionText[idx]
      if (!is.null(label) && !is.na(label) && label != "") {
        return(as.character(label))
      }
    }
    
    # Fallback to QuestionCode
    as.character(banner_questions$QuestionCode[idx])
    
  }, error = function(e) {
    as.character(banner_questions$QuestionCode[idx])
  })
  
  if (is.null(label) || length(label) == 0 || label == "") {
    label <- as.character(banner_questions$QuestionCode[idx])
  }
  
  return(label)
}

# ==============================================================================
# SPECIAL BANNER STRUCTURES
# ==============================================================================

#' Create Total-Only Banner Structure
#' 
#' Creates banner structure with only Total column (no banner questions)
#' 
#' @return List with Total column only
#' @export
create_total_only_banner <- function() {
  
  total_internal_key <- paste0("TOTAL::", TOTAL_COLUMN)
  
  return(list(
    banner_questions = NULL,
    columns = TOTAL_COLUMN,
    internal_keys = total_internal_key,
    column_labels = TOTAL_COLUMN,
    letters = "-",
    column_to_banner = setNames(TOTAL_COLUMN, total_internal_key),
    key_to_display = setNames(TOTAL_COLUMN, total_internal_key),
    banner_info = list(),
    banner_headers = data.frame(
      start_col = integer(), 
      end_col = integer(), 
      label = character(),
      stringsAsFactors = FALSE
    )
  ))
}

# ==============================================================================
# UTILITIES
# ==============================================================================

#' Generate Excel Column Letters
#' 
#' Converts column numbers to Excel-style letters (A, B, C, ..., Z, AA, AB, ...)
#' Uses proper base-26 algorithm
#' 
#' @param n Number of letters to generate
#' @return Character vector of Excel column letters
#' @export
generate_excel_letters <- function(n) {
  
  if (n <= 0) return(character(0))
  
  letters_vec <- character(n)
  
  for (i in 1:n) {
    col_num <- i
    letter <- ""
    
    while (col_num > 0) {
      remainder <- (col_num - 1) %% 26
      letter <- paste0(LETTERS[remainder + 1], letter)
      col_num <- (col_num - 1) %/% 26
    }
    
    letters_vec[i] <- letter
  }
  
  return(letters_vec)
}

#' Validate Banner Structure
#' 
#' Validates that banner structure is properly formed
#' 
#' @param banner_structure Banner structure list
#' @return TRUE if valid, stops with error if not
#' @export
validate_banner_structure <- function(banner_structure) {
  
  required_elements <- c("columns", "internal_keys", "letters", 
                        "column_to_banner", "key_to_display")
  
  missing <- setdiff(required_elements, names(banner_structure))
  
  if (length(missing) > 0) {
    stop(sprintf(
      "Banner structure missing required elements: %s",
      paste(missing, collapse = ", ")
    ))
  }
  
  # Check lengths match
  n_cols <- length(banner_structure$columns)
  
  if (length(banner_structure$internal_keys) != n_cols) {
    stop("Banner structure: internal_keys length doesn't match columns")
  }
  
  if (length(banner_structure$letters) != n_cols) {
    stop("Banner structure: letters length doesn't match columns")
  }
  
  return(TRUE)
}

#' Get Banner Summary
#' 
#' Returns a summary of banner structure
#' 
#' @param banner_structure Banner structure list
#' @export
get_banner_summary <- function(banner_structure) {
  
  cat("")

  cat("==============================================")

  cat("BANNER STRUCTURE SUMMARY")

  cat("==============================================")

  cat(sprintf("Total columns: %d\n", length(banner_structure$columns)))
  cat(sprintf("Banner questions: %d\n", length(banner_structure$banner_info)))
  cat("")

  
  if (length(banner_structure$banner_info) > 0) {
    cat("Banner Questions:")

    for (code in names(banner_structure$banner_info)) {
      info <- banner_structure$banner_info[[code]]
      cat(sprintf("  - %s (%s columns)\n", 
                  code, 
                  length(info$columns)))
    }
  }
  
  cat("==============================================\n")

}

# ==============================================================================
# MODULE METADATA
# ==============================================================================

#' Get Module Version
#' @export
get_banner_module_version <- function() {
  return("1.0.0")
}

#' Get Module Info
#' @export
get_banner_module_info <- function() {
  cat("")

  cat("================================================")

  cat("TURAS>TABS Banner Structure Module")

  cat("================================================")

  cat("Version:", get_banner_module_version(), "")

  cat("Purpose: Create banner (column) structure")

  cat("")

  cat("Main Functions:")

  cat("  - create_banner_structure()")

  cat("  - process_standard_banner()")

  cat("  - process_boxcategory_banner()")

  cat("  - get_banner_label()")

  cat("  - validate_banner_structure()")

  cat("================================================\n")

}

# Module loaded message
message("Turas>Tabs banner module loaded")

