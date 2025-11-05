# ==============================================================================
# TURAS>PARSER - Bin Detector
# ==============================================================================
# Purpose: Detect numeric bins in option text
# ==============================================================================

#' Detect Numeric Bins
#' 
#' @description
#' Identifies numeric ranges in option text.
#' Recognizes patterns like:
#' - "18-24", "25-34" (age ranges)
#' - "0 to 50", "51 to 100" (ranges with 'to')
#' - "Under 18", "Less than 25" (upper bounds)
#' - "65+", "100 and over" (lower bounds)
#' 
#' @param options Character vector. Option texts to analyze
#' 
#' @return Data frame with columns: min, max, label
#' 
#' @export
detect_numeric_bins <- function(options) {
  
  bins <- data.frame(
    min = numeric(0),
    max = numeric(0),
    label = character(0),
    stringsAsFactors = FALSE
  )
  
  for (opt in options) {
    
    # Pattern 1: Range with dash (18-24, 25-34)
    pattern1 <- "^(\\d+)\\s*[\\-—–]\\s*(\\d+)(?:\\s*(.*))?$"
    matches1 <- stringr::str_match(opt, pattern1)
    if (!is.na(matches1[1])) {
      bins <- rbind(bins, data.frame(
        min = as.numeric(matches1[2]),
        max = as.numeric(matches1[3]),
        label = trimws(opt),
        stringsAsFactors = FALSE
      ))
      next
    }
    
    # Pattern 2: Range with "to" (0 to 50, 51 to 100)
    pattern2 <- "^(\\d+)\\s+to\\s+(\\d+)(?:\\s*(.*))?$"
    matches2 <- stringr::str_match(tolower(opt), pattern2)
    if (!is.na(matches2[1])) {
      bins <- rbind(bins, data.frame(
        min = as.numeric(matches2[2]),
        max = as.numeric(matches2[3]),
        label = trimws(opt),
        stringsAsFactors = FALSE
      ))
      next
    }
    
    # Pattern 3: Upper bound (Under 18, Less than 25, Below 30)
    pattern3 <- "^(?:<|under|below|less\\s+than)\\s*(\\d+)(?:\\s*(.*))?$"
    matches3 <- stringr::str_match(tolower(opt), pattern3)
    if (!is.na(matches3[1])) {
      max_val <- as.numeric(matches3[2])
      bins <- rbind(bins, data.frame(
        min = 0,
        max = max_val - 1,
        label = trimws(opt),
        stringsAsFactors = FALSE
      ))
      next
    }
    
    # Pattern 4: Lower bound (65+, 100 and over, 75 or older)
    pattern4 <- "^(\\d+)\\s*(?:\\+|and\\s+(?:over|above)|or\\s+(?:more|older))(?:\\s*(.*))?$"
    matches4 <- stringr::str_match(tolower(opt), pattern4)
    if (!is.na(matches4[1])) {
      min_val <- as.numeric(matches4[2])
      bins <- rbind(bins, data.frame(
        min = min_val,
        max = 999,
        label = trimws(opt),
        stringsAsFactors = FALSE
      ))
      next
    }
  }
  
  return(bins)
}

#' Check if Options are Numeric Bins
#' 
#' @description
#' Determines if a set of options represents numeric bins.
#' 
#' @param options Character vector. Option texts
#' 
#' @return Logical. TRUE if options contain numeric bins
#' 
#' @export
are_numeric_bins <- function(options) {
  
  if (length(options) == 0) return(FALSE)
  
  bins <- detect_numeric_bins(options)
  
  # Consider it bins if at least 50% of options match
  return(nrow(bins) >= (length(options) * 0.5))
}

#' Validate Numeric Bins
#' 
#' @description
#' Checks if detected bins are valid:
#' - No gaps between ranges
#' - No overlaps
#' - Ascending order
#' 
#' @param bins Data frame. Detected bins with min/max
#' 
#' @return List with valid=TRUE/FALSE and issues vector
#' 
#' @export
validate_numeric_bins <- function(bins) {
  
  if (nrow(bins) == 0) {
    return(list(valid = TRUE, issues = character(0)))
  }
  
  issues <- character(0)
  
  # Sort by min value
  bins <- bins[order(bins$min), ]
  
  # Check for gaps and overlaps
  for (i in seq_len(nrow(bins) - 1)) {
    current_max <- bins$max[i]
    next_min <- bins$min[i + 1]
    
    # Gap check
    if (next_min > current_max + 1) {
      issues <- c(issues, sprintf(
        "Gap between '%s' and '%s'",
        bins$label[i], bins$label[i + 1]
      ))
    }
    
    # Overlap check
    if (next_min <= current_max) {
      issues <- c(issues, sprintf(
        "Overlap between '%s' and '%s'",
        bins$label[i], bins$label[i + 1]
      ))
    }
  }
  
  return(list(
    valid = (length(issues) == 0),
    issues = issues
  ))
}
