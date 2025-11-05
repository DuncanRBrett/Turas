# ==============================================================================
# TURAS SHARED - DATA FILTERS
# ==============================================================================
# Survey data filtering utilities
# Migrated from shared_functions.r V9.9.1
# ==============================================================================

#' Apply base filter to survey data
#'
#' USAGE: Filter data for specific question analysis
#' DESIGN: Returns filtered data with .original_row tracking
#' SECURITY: Validates and sanitizes expressions
#'
#' @param data Data frame, survey data
#' @param filter_expression Character, R expression for filtering
#' @return Data frame, filtered subset with .original_row column
#' @export
#' @examples
#' # Filter to adults only
#' filtered <- apply_base_filter(survey_data, "Age >= 18")
#' 
#' # Filter with multiple conditions
#' filtered <- apply_base_filter(survey_data, "Age >= 18 & Region == 'North'")
apply_base_filter <- function(data, filter_expression) {
  # Validate inputs
  if (!is.data.frame(data) || nrow(data) == 0) {
    stop("data must be a non-empty data frame", call. = FALSE)
  }
  
  # Empty/null filter = return all data with row indices
  if (is.null(filter_expression) || is.na(filter_expression) || 
      trimws(filter_expression) == "") {
    data$.original_row <- seq_len(nrow(data))
    return(data)
  }
  
  # Validate filter is safe
  if (!is.character(filter_expression) || length(filter_expression) != 1) {
    stop("filter_expression must be a single character string", call. = FALSE)
  }
  
  # Clean Unicode and special characters
  filter_expression <- tryCatch({
    cleaned <- iconv(filter_expression, to = "ASCII//TRANSLIT", sub = "")
    if (is.na(cleaned)) filter_expression else cleaned
  }, error = function(e) filter_expression)
  
  # Replace Unicode spaces and quotes
  filter_expression <- gsub("[\u00A0\u2000-\u200B\u202F\u205F\u3000]", " ", filter_expression)
  filter_expression <- gsub("[\u2018\u2019\u201A\u201B]", "'", filter_expression)
  filter_expression <- gsub("[\u201C\u201D\u201E\u201F]", '"', filter_expression)
  
  # Apply filter with error handling
  tryCatch({
    # Evaluate filter expression
    filter_result <- eval(
      parse(text = filter_expression),
      envir = data,
      enclos = parent.frame()
    )
    
    # Check return type
    if (!is.logical(filter_result)) {
      stop(sprintf(
        "Filter must return logical vector, got: %s",
        class(filter_result)[1]
      ), call. = FALSE)
    }
    
    # Check length
    if (length(filter_result) != nrow(data)) {
      stop(sprintf(
        "Filter returned %d values but data has %d rows",
        length(filter_result),
        nrow(data)
      ), call. = FALSE)
    }
    
    # Replace NAs with FALSE (don't include NA cases)
    filter_result[is.na(filter_result)] <- FALSE
    
    # Check if any rows retained
    n_retained <- sum(filter_result)
    if (n_retained == 0) {
      warning(sprintf(
        "Filter retains 0 rows (filters out all data): '%s'",
        filter_expression
      ), call. = FALSE)
    }
    
    # Create filtered dataset with original row tracking
    original_rows <- which(filter_result)
    filtered_data <- data[filter_result, , drop = FALSE]
    filtered_data$.original_row <- original_rows
    
    return(filtered_data)
    
  }, error = function(e) {
    stop(sprintf(
      "Filter evaluation failed: %s\nExpression: '%s'",
      conditionMessage(e),
      filter_expression
    ), call. = FALSE)
  })
}

# Success message
cat("Turas data filters loaded\n")
