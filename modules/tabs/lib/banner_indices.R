# ==============================================================================
# TURAS>TABS - BANNER INDICES MODULE
# ==============================================================================
# Purpose: Create memory-optimized banner row indices
# Key Design: Returns ONLY row indices, NO weight duplication
# Dependencies: banner, utilities
# Author: Turas Analytics Toolkit
# Version: 1.0.0
# ==============================================================================

#' Create Banner Row Indices
#' 
#' MEMORY OPTIMIZATION:
#' Returns ONLY row indices, not weights. This prevents memory duplication.
#' Caller should use master_weights[row_idx] when weights are needed.
#' 
#' Creates indices for each banner column showing which respondents
#' belong to that column.
#' 
#' @param data Survey data frame
#' @param banner_info Banner structure from create_banner_structure()
#' @return List with row_indices (list of integer vectors)
#' @export
#' @examples
#' indices <- create_banner_row_indices(data, banner_info)
#' # Get weights for a specific banner column:
#' col_weights <- master_weights[indices$row_indices[[internal_key]]]
create_banner_row_indices <- function(data, banner_info) {
  
  # Validate inputs
  validate_data_frame(data, param_name = "data")
  
  # Initialize with Total column (all rows)
  total_key <- paste0("TOTAL::", TOTAL_COLUMN)
  all_rows <- seq_len(nrow(data))
  
  row_indices_list <- setNames(list(all_rows), total_key)
  
  # If no banner questions, return Total only
  if (is.null(banner_info$banner_questions)) {
    return(list(row_indices = row_indices_list))
  }
  
  # Process each banner question
  for (banner_code in names(banner_info$banner_info)) {
    banner_data_info <- banner_info$banner_info[[banner_code]]
    question_info <- banner_data_info$question
    
    # Create indices based on question type
    if (!is.null(banner_data_info$is_boxcategory) && 
        banner_data_info$is_boxcategory) {
      # Box/Category banner
      subsets <- create_boxcategory_indices(
        data, 
        banner_code, 
        question_info, 
        banner_data_info
      )
    } else {
      # Standard banner
      subsets <- create_standard_indices(
        data, 
        banner_code, 
        question_info, 
        banner_data_info
      )
    }
    
    # Add to indices list
    row_indices_list <- c(row_indices_list, subsets$row_indices)
  }
  
  return(list(row_indices = row_indices_list))
}

# ==============================================================================
# STANDARD BANNER INDICES
# ==============================================================================

#' Create Indices for Standard Banner
#' 
#' Creates row indices for standard (non-box/category) banner questions
#' Handles both single-choice and multi-mention questions
#' 
#' @param data Survey data
#' @param banner_code Question code
#' @param question_info Question information
#' @param banner_data_info Banner data
#' @return List with row_indices
#' @export
create_standard_indices <- function(data, banner_code, question_info, 
                                    banner_data_info) {
  
  subset_indices <- list()
  
  # Multi-mention question
  if (question_info$Variable_Type == "Multi_Mention") {
    subset_indices <- create_multi_mention_indices(
      data, 
      banner_code, 
      question_info, 
      banner_data_info
    )
  } else {
    # Single choice question
    subset_indices <- create_single_choice_indices(
      data, 
      banner_code, 
      banner_data_info
    )
  }
  
  return(list(row_indices = subset_indices))
}

#' Create Indices for Multi-Mention Banner
#' 
#' For multi-mention questions, checks all columns (Q1_1, Q1_2, etc.)
#' and includes respondent if they mentioned the option in ANY column
#' 
#' @param data Survey data
#' @param banner_code Question code
#' @param question_info Question information
#' @param banner_data_info Banner data
#' @return Named list of integer vectors
#' @export
create_multi_mention_indices <- function(data, banner_code, question_info, 
                                         banner_data_info) {
  
  subset_indices <- list()
  
  # Get number of columns
  num_columns <- suppressWarnings(as.numeric(question_info$Columns))
  if (is.na(num_columns) || num_columns < 1) {
    return(subset_indices)
  }
  
  # Build column names
  banner_cols <- paste0(banner_code, "_", seq_len(num_columns))
  existing_cols <- banner_cols[banner_cols %in% names(data)]
  
  if (length(existing_cols) == 0) {
    return(subset_indices)
  }
  
  # Process each option
  for (option_idx in seq_len(nrow(banner_data_info$options))) {
    option_text <- banner_data_info$options$OptionText[option_idx]
    internal_key <- banner_data_info$internal_keys[option_idx]
    
    # Check if option mentioned in ANY column (OR logic)
    matching_rows <- Reduce(`|`, lapply(existing_cols, function(col) {
      safe_equal(data[[col]], option_text) & !is.na(data[[col]])
    }))
    
    row_idx <- which(matching_rows)
    subset_indices[[internal_key]] <- row_idx
  }
  
  return(subset_indices)
}

#' Create Indices for Single Choice Banner
#' 
#' For single choice questions, checks the single column
#' 
#' @param data Survey data
#' @param banner_code Question code
#' @param banner_data_info Banner data
#' @return Named list of integer vectors
#' @export
create_single_choice_indices <- function(data, banner_code, banner_data_info) {

  subset_indices <- list()

  # Check if column exists
  if (!banner_code %in% names(data)) {
    # TRS v1.0: Banner column missing is a configuration error - refuse with clear message
    tabs_refuse(
      code = "CFG_BANNER_COLUMN_NOT_FOUND",
      title = paste0("Banner Column Missing: ", banner_code),
      problem = paste0("Banner column '", banner_code, "' is configured but not found in the data file."),
      why_it_matters = "Cannot create banner breakouts without this column. Analysis would produce incomplete crosstabs.",
      how_to_fix = c(
        "Check that the banner column name in Banner_Config matches the column name in your data exactly",
        "Verify the column exists in your data file (check for typos, case sensitivity)",
        "If the column was renamed, update the Banner_Config sheet accordingly"
      ),
      missing = banner_code
    )
  }
  
  # Process each option
  for (option_idx in seq_len(nrow(banner_data_info$options))) {
    option_text <- banner_data_info$options$OptionText[option_idx]
    internal_key <- banner_data_info$internal_keys[option_idx]
    
    # Find matching rows
    matching_rows <- safe_equal(data[[banner_code]], option_text) & 
                    !is.na(data[[banner_code]])
    
    row_idx <- which(matching_rows)
    subset_indices[[internal_key]] <- row_idx
  }
  
  return(subset_indices)
}

# ==============================================================================
# BOX/CATEGORY BANNER INDICES
# ==============================================================================

#' Create Indices for Box/Category Banner
#' 
#' BOXCATEGORY LOGIC:
#' - Groups response options into categories
#' - For multi-mention: Uses OR logic across all columns AND all options in category
#' - Respondent included if they mentioned ANY option in the category
#' 
#' @param data Survey data
#' @param banner_code Question code
#' @param question_info Question information
#' @param banner_data_info Banner data with boxcat_groups
#' @return List with row_indices
#' @export
create_boxcategory_indices <- function(data, banner_code, question_info, 
                                        banner_data_info) {
  
  subset_indices <- list()
  
  # Multi-mention question
  if (question_info$Variable_Type == "Multi_Mention") {
    subset_indices <- create_boxcat_multi_indices(
      data, 
      banner_code, 
      question_info, 
      banner_data_info
    )
  } else {
    # Single choice question
    subset_indices <- create_boxcat_single_indices(
      data, 
      banner_code, 
      banner_data_info
    )
  }
  
  return(list(row_indices = subset_indices))
}

#' Create Box/Category Indices for Multi-Mention
#' 
#' OR logic: Respondent included if they mentioned ANY option 
#' in the category in ANY column
#' 
#' @param data Survey data
#' @param banner_code Question code
#' @param question_info Question information
#' @param banner_data_info Banner data with boxcat_groups
#' @return Named list of integer vectors
#' @export
create_boxcat_multi_indices <- function(data, banner_code, question_info, 
                                         banner_data_info) {
  
  subset_indices <- list()
  
  # Get number of columns
  num_columns <- suppressWarnings(as.numeric(question_info$Columns))
  if (is.na(num_columns) || num_columns < 1) {
    return(subset_indices)
  }
  
  # Build column names
  banner_cols <- paste0(banner_code, "_", seq_len(num_columns))
  existing_cols <- banner_cols[banner_cols %in% names(data)]
  
  if (length(existing_cols) == 0) {
    return(subset_indices)
  }
  
  # Process each box category
  for (box_cat_idx in seq_along(banner_data_info$boxcat_groups)) {
    box_cat <- names(banner_data_info$boxcat_groups)[box_cat_idx]
    option_texts <- banner_data_info$boxcat_groups[[box_cat]]
    internal_key <- banner_data_info$internal_keys[box_cat_idx]
    
    # OR across columns AND options
    matching_rows <- Reduce(`|`, lapply(existing_cols, function(col) {
      Reduce(`|`, lapply(option_texts, function(opt) {
        safe_equal(data[[col]], opt) & !is.na(data[[col]])
      }))
    }))
    
    row_idx <- which(matching_rows)
    subset_indices[[internal_key]] <- row_idx
  }
  
  return(subset_indices)
}

#' Create Box/Category Indices for Single Choice
#' 
#' OR logic: Respondent included if their answer matches ANY option
#' in the category
#' 
#' @param data Survey data
#' @param banner_code Question code
#' @param banner_data_info Banner data with boxcat_groups
#' @return Named list of integer vectors
#' @export
create_boxcat_single_indices <- function(data, banner_code, banner_data_info) {

  subset_indices <- list()

  # Check if column exists
  if (!banner_code %in% names(data)) {
    # TRS v1.0: Banner column missing is a configuration error - refuse with clear message
    tabs_refuse(
      code = "CFG_BANNER_COLUMN_NOT_FOUND",
      title = paste0("Banner Column Missing: ", banner_code),
      problem = paste0("Banner column '", banner_code, "' is configured for BoxCategory but not found in the data file."),
      why_it_matters = "Cannot create banner breakouts without this column. Analysis would produce incomplete crosstabs.",
      how_to_fix = c(
        "Check that the banner column name in Banner_Config matches the column name in your data exactly",
        "Verify the column exists in your data file (check for typos, case sensitivity)",
        "If the column was renamed, update the Banner_Config sheet accordingly"
      ),
      missing = banner_code
    )
  }
  
  # Process each box category
  for (box_cat_idx in seq_along(banner_data_info$boxcat_groups)) {
    box_cat <- names(banner_data_info$boxcat_groups)[box_cat_idx]
    option_texts <- banner_data_info$boxcat_groups[[box_cat]]
    internal_key <- banner_data_info$internal_keys[box_cat_idx]
    
    # OR across options in category
    matching_rows <- Reduce(`|`, lapply(option_texts, function(opt) {
      safe_equal(data[[banner_code]], opt) & !is.na(data[[banner_code]])
    }))
    
    row_idx <- which(matching_rows)
    subset_indices[[internal_key]] <- row_idx
  }
  
  return(subset_indices)
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Get Data Subset Using Row Indices
#' 
#' Retrieves a subset of data using row indices
#' Returns empty data frame if no indices
#' 
#' @param data Full data frame
#' @param row_indices Integer vector of row indices
#' @return Data frame subset
#' @export
get_data_subset <- function(data, row_indices) {
  if (length(row_indices) == 0) {
    return(data[integer(0), , drop = FALSE])
  }
  return(data[row_indices, , drop = FALSE])
}

#' Get Weights for Banner Column
#' 
#' Retrieves weights for a specific banner column
#' 
#' @param master_weights Full weight vector
#' @param row_indices Row indices for banner column
#' @return Weight vector for subset
#' @export
get_column_weights <- function(master_weights, row_indices) {
  if (length(row_indices) == 0) {
    return(numeric(0))
  }
  return(master_weights[row_indices])
}

#' Calculate Banner Base Sizes
#' 
#' Calculates base sizes (unweighted, weighted, effective) for all banner columns
#' 
#' @param banner_row_indices List of row indices
#' @param master_weights Weight vector
#' @param is_weighted Logical, whether weighting is applied
#' @return List with bases for each banner column
#' @export
calculate_banner_bases <- function(banner_row_indices, master_weights, 
                                   is_weighted = FALSE) {
  
  bases <- list()
  
  for (internal_key in names(banner_row_indices$row_indices)) {
    row_idx <- banner_row_indices$row_indices[[internal_key]]
    
    # Unweighted base
    unweighted_n <- length(row_idx)
    
    if (is_weighted && length(row_idx) > 0) {
      # Weighted base
      col_weights <- master_weights[row_idx]
      weighted_n <- sum(col_weights)
      
      # Effective base
      sum_weights_sq <- sum(col_weights^2)
      effective_n <- if (sum_weights_sq > 0) {
        (weighted_n^2) / sum_weights_sq
      } else {
        0
      }
    } else {
      weighted_n <- unweighted_n
      effective_n <- unweighted_n
    }
    
    bases[[internal_key]] <- list(
      unweighted = unweighted_n,
      weighted = weighted_n,
      effective = effective_n
    )
  }
  
  return(bases)
}

#' Validate Banner Indices
#' 
#' Validates banner row indices structure
#' 
#' @param banner_row_indices Banner row indices list
#' @param data_rows Number of data rows
#' @return TRUE if valid, stops with error if not
#' @export
validate_banner_indices <- function(banner_row_indices, data_rows) {
  
  if (is.null(banner_row_indices$row_indices)) {
    stop("Banner indices missing row_indices element")
  }
  
  if (!is.list(banner_row_indices$row_indices)) {
    stop("row_indices must be a list")
  }
  
  if (length(banner_row_indices$row_indices) == 0) {
    stop("row_indices is empty")
  }
  
  # Check each index vector
  for (key in names(banner_row_indices$row_indices)) {
    idx <- banner_row_indices$row_indices[[key]]
    
    if (!is.numeric(idx) && !is.integer(idx)) {
      stop(sprintf("Indices for '%s' must be numeric", key))
    }
    
    if (any(idx < 1 | idx > data_rows)) {
      stop(sprintf("Indices for '%s' out of range (1-%d)", key, data_rows))
    }
  }
  
  return(TRUE)
}

# ==============================================================================
# MODULE METADATA
# ==============================================================================

#' Get Module Version
#' @export
get_banner_indices_version <- function() {
  return("1.0.0")
}

#' Get Module Info
#' @export
get_banner_indices_info <- function() {
  cat("")

  cat("================================================")

  cat("TURAS>TABS Banner Indices Module")

  cat("================================================")

  cat("Version:", get_banner_indices_version(), "")

  cat("Purpose: Memory-optimized banner row indices")

  cat("")

  cat("Key Design:")

  cat("  - Returns ONLY row indices (no weight duplication)")

  cat("  - Use master_weights[row_idx] when needed")

  cat("  - Supports standard and box/category banners")

  cat("")

  cat("Main Functions:")

  cat("  - create_banner_row_indices()")

  cat("  - create_standard_indices()")

  cat("  - create_boxcategory_indices()")

  cat("  - get_data_subset()")

  cat("  - calculate_banner_bases()")

  cat("================================================\n")

}

# Module loaded message
message("Turas>Tabs banner_indices module loaded")

