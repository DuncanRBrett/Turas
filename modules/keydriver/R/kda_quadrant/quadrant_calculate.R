# ==============================================================================
# TURAS KEY DRIVER - QUADRANT CALCULATIONS
# ==============================================================================
#
# Purpose: Calculate quadrant assignments, thresholds, and gap scores
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================

#' Prepare Quadrant Data
#'
#' Combines importance and performance, assigns quadrants.
#'
#' @param importance Importance data frame
#' @param performance Performance data frame
#' @param config Configuration parameters
#' @return Data frame with quadrant assignments
#' @keywords internal
prepare_quadrant_data <- function(importance, performance, config) {

  # Merge importance and performance
  quad_data <- merge(
    importance,
    performance,
    by = "driver",
    all = FALSE  # Only keep drivers with both scores
  )

  # Remove rows with NA
  quad_data <- quad_data[!is.na(quad_data$importance) & !is.na(quad_data$performance), ]

  # Use normalized values
  quad_data$x <- quad_data$performance_normalized %||% quad_data$performance
  quad_data$y <- quad_data$importance_normalized %||% quad_data$importance

  # Calculate thresholds
  thresholds <- calculate_thresholds(quad_data, config)
  quad_data$x_threshold <- thresholds$x
  quad_data$y_threshold <- thresholds$y

  # Assign quadrants
  quad_data$quadrant <- assign_quadrants(
    quad_data$x,
    quad_data$y,
    thresholds$x,
    thresholds$y
  )

  # Add quadrant labels
  quad_data$quadrant_label <- factor(
    quad_data$quadrant,
    levels = 1:4,
    labels = c(
      config$quadrant_1_name %||% "Concentrate Here",
      config$quadrant_2_name %||% "Keep Up Good Work",
      config$quadrant_3_name %||% "Low Priority",
      config$quadrant_4_name %||% "Possible Overkill"
    )
  )

  # Calculate gap score (importance - performance)
  quad_data$gap <- quad_data$y - quad_data$x

  # Priority score (high importance + low performance = high priority)
  quad_data$priority_score <- quad_data$y * (100 - quad_data$x) / 100

  quad_data
}


#' Calculate Quadrant Thresholds
#'
#' Determines where to draw the quadrant lines.
#'
#' @param quad_data Data frame with x and y columns
#' @param config Configuration parameters
#' @return List with x and y thresholds
#' @keywords internal
calculate_thresholds <- function(quad_data, config) {

  method <- config$threshold_method %||% "mean"

  thresholds <- switch(tolower(method),

    "mean" = list(
      x = mean(quad_data$x, na.rm = TRUE),
      y = mean(quad_data$y, na.rm = TRUE)
    ),

    "median" = list(
      x = stats::median(quad_data$x, na.rm = TRUE),
      y = stats::median(quad_data$y, na.rm = TRUE)
    ),

    "midpoint" = list(
      x = (max(quad_data$x, na.rm = TRUE) + min(quad_data$x, na.rm = TRUE)) / 2,
      y = (max(quad_data$y, na.rm = TRUE) + min(quad_data$y, na.rm = TRUE)) / 2
    ),

    "custom" = list(
      x = config$performance_threshold %||% 50,
      y = config$importance_threshold %||% 50
    ),

    "scale_midpoint" = list(
      x = 50,
      y = 50
    ),

    # Default to mean
    list(
      x = mean(quad_data$x, na.rm = TRUE),
      y = mean(quad_data$y, na.rm = TRUE)
    )
  )

  thresholds
}


#' Assign Quadrant Numbers
#'
#' Quadrant numbering (standard IPA convention):
#'   1 (Concentrate) | 2 (Keep Up)
#'   -----------------+-----------
#'   3 (Low Priority) | 4 (Overkill)
#'
#' Note: Q1 is upper-left (high importance, low performance)
#'
#' @param x Performance values
#' @param y Importance values
#' @param x_thresh Performance threshold
#' @param y_thresh Importance threshold
#' @return Integer vector of quadrant assignments
#' @keywords internal
assign_quadrants <- function(x, y, x_thresh, y_thresh) {

  quadrant <- rep(NA_integer_, length(x))

  # Q1: High importance, Low performance (upper-left) - CONCENTRATE HERE
  quadrant[y >= y_thresh & x < x_thresh] <- 1L

  # Q2: High importance, High performance (upper-right) - KEEP UP GOOD WORK
  quadrant[y >= y_thresh & x >= x_thresh] <- 2L

  # Q3: Low importance, Low performance (lower-left) - LOW PRIORITY
  quadrant[y < y_thresh & x < x_thresh] <- 3L

  # Q4: Low importance, High performance (lower-right) - POSSIBLE OVERKILL
  quadrant[y < y_thresh & x >= x_thresh] <- 4L

  quadrant
}


#' Calculate Gap Analysis
#'
#' Computes importance-performance gaps and ranks drivers.
#'
#' @param quad_data Quadrant data from prepare_quadrant_data()
#' @return Data frame with gap analysis
#' @keywords internal
calculate_gap_analysis <- function(quad_data) {

  gap_data <- data.frame(
    driver = quad_data$driver,
    importance = quad_data$y,
    performance = quad_data$x,
    quadrant = quad_data$quadrant,
    quadrant_label = quad_data$quadrant_label,
    stringsAsFactors = FALSE
  )

  # Gap = Importance - Performance
  # Positive gap = underperforming relative to importance
  gap_data$gap <- gap_data$importance - gap_data$performance

  # Weighted gap (importance-weighted)
  gap_data$weighted_gap <- gap_data$gap * (gap_data$importance / 100)

  # Rank by gap (largest positive gap = highest priority)
  gap_data$gap_rank <- rank(-gap_data$gap, ties.method = "min")

  # Gap direction
  gap_data$gap_direction <- ifelse(gap_data$gap >= 0, "Underperforming", "Overperforming")

  # Sort by gap descending
  gap_data <- gap_data[order(-gap_data$gap), ]
  rownames(gap_data) <- NULL

  gap_data
}


#' Create Action Table
#'
#' Prioritized list of drivers with recommended actions.
#'
#' @param quad_data Quadrant data
#' @param config Configuration
#' @return Data frame with prioritized actions
#' @keywords internal
create_action_table <- function(quad_data, config) {

  action_table <- data.frame(
    driver = quad_data$driver,
    quadrant = quad_data$quadrant,
    quadrant_label = as.character(quad_data$quadrant_label),
    importance = quad_data$y,
    performance = quad_data$x,
    gap = quad_data$gap,
    priority_score = quad_data$priority_score,
    stringsAsFactors = FALSE
  )

  # Add recommended actions
  action_table$action <- sapply(action_table$quadrant, function(q) {
    switch(as.character(q),
      "1" = "IMPROVE: High importance, low performance. Priority investment needed.",
      "2" = "MAINTAIN: High importance, high performance. Protect current investment.",
      "3" = "MONITOR: Low importance, low performance. Low priority unless trending.",
      "4" = "REASSESS: Low importance, high performance. Consider reallocating resources.",
      "Review required"
    )
  })

  # Sort by priority
  action_table <- action_table[order(-action_table$priority_score), ]

  # Add priority rank
  action_table$priority_rank <- seq_len(nrow(action_table))

  # Round numeric columns
  numeric_cols <- c("importance", "performance", "gap", "priority_score")
  action_table[numeric_cols] <- lapply(action_table[numeric_cols], round, 1)

  # Reorder columns
  action_table <- action_table[, c(
    "priority_rank",
    "driver",
    "quadrant_label",
    "importance",
    "performance",
    "gap",
    "action"
  )]

  names(action_table) <- c(
    "Priority",
    "Driver",
    "Zone",
    "Importance",
    "Performance",
    "Gap",
    "Recommended Action"
  )

  rownames(action_table) <- NULL

  action_table
}


#' Prepare Dual Importance Data
#'
#' Merges derived and stated importance for comparison.
#'
#' @param derived_importance Derived importance data frame
#' @param stated_importance Stated importance data frame
#' @return Data frame with both importance types
#' @keywords internal
prepare_dual_importance <- function(derived_importance, stated_importance) {

  # Standardize stated importance column names
  if ("stated_importance" %in% names(stated_importance)) {
    # Already in expected format
  } else if ("importance" %in% names(stated_importance)) {
    names(stated_importance)[names(stated_importance) == "importance"] <- "stated_importance"
  } else {
    # Try to find any numeric column
    num_cols <- sapply(stated_importance, is.numeric)
    if (any(num_cols)) {
      stated_col <- names(stated_importance)[num_cols][1]
      names(stated_importance)[names(stated_importance) == stated_col] <- "stated_importance"
    }
  }

  # Merge
  dual_data <- merge(
    derived_importance[, c("driver", "importance")],
    stated_importance[, c("driver", "stated_importance")],
    by = "driver",
    all = FALSE
  )

  names(dual_data)[names(dual_data) == "importance"] <- "derived_importance"

  # Normalize both to 0-100
  dual_data$derived_importance <- normalize_to_100(dual_data$derived_importance)
  dual_data$stated_importance <- normalize_to_100(dual_data$stated_importance)

  dual_data
}


#' Normalize Vector to 0-100 Scale
#'
#' @param x Numeric vector
#' @return Normalized vector
#' @keywords internal
normalize_to_100 <- function(x) {
  min_x <- min(x, na.rm = TRUE)
  max_x <- max(x, na.rm = TRUE)

  if (max_x == min_x) {
    return(rep(50, length(x)))
  }

  (x - min_x) / (max_x - min_x) * 100
}


#' Null-coalescing operator (if not already defined)
#' @keywords internal
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
