# ==============================================================================
# METRIC TYPES MODULE
# ==============================================================================
# Purpose: Define metric type constants and validation functions for the tracker
# module. This ensures consistent metric_type usage across all calculation
# and output functions.
#
# Author: Claude (Refactoring)
# Date: 2025-12-28
# ==============================================================================

# ------------------------------------------------------------------------------
# METRIC TYPE CONSTANTS
# ------------------------------------------------------------------------------
#' @description Enumeration of valid metric types supported by the tracker module

METRIC_TYPES <- list(
  # Numeric metrics
  MEAN = "mean",                          # Rating/Likert questions (numeric 1-5 scale)
  NPS = "nps",                            # Net Promoter Score (-100 to +100)

  # Categorical metrics
  PROPORTIONS = "proportions",            # Single choice percentages

  # Enhanced metrics
  RATING_ENHANCED = "rating_enhanced",    # Enhanced rating with custom specs
  COMPOSITE = "composite",                # Index scores (basic)
  COMPOSITE_ENHANCED = "composite_enhanced", # Index scores (enhanced)

  # Multi-option metrics
  MULTI_MENTION = "multi_mention",        # Select-all-that-apply options
  CATEGORY_MENTIONS = "category_mentions" # Select-all-that-apply categories
)

# Create a flat vector for easy validation
VALID_METRIC_TYPES <- unlist(METRIC_TYPES, use.names = FALSE)


# ------------------------------------------------------------------------------
# VALIDATION FUNCTIONS
# ------------------------------------------------------------------------------

#' Check if a metric type is valid
#'
#' @param metric_type Character string to validate
#' @return Logical TRUE if valid, FALSE otherwise
#' @export
is_valid_metric_type <- function(metric_type) {
  if (is.null(metric_type)) return(FALSE)
  if (length(metric_type) == 0) return(FALSE)
  if (!is.character(metric_type)) return(FALSE)
  if (nchar(metric_type) == 0) return(FALSE)

  return(metric_type %in% VALID_METRIC_TYPES)
}


#' Validate metric type and stop if invalid
#'
#' @param metric_type Character string to validate
#' @param context Character string describing where validation occurred (for error messages)
#' @return NULL (stops execution if invalid)
#' @export
validate_metric_type <- function(metric_type, context = "unknown") {
  if (is.null(metric_type)) {
    stop("metric_type is NULL in context: ", context, call. = FALSE)
  }

  if (length(metric_type) == 0) {
    stop("metric_type has length zero in context: ", context, call. = FALSE)
  }

  if (!is.character(metric_type)) {
    stop("metric_type must be a character string, got ", class(metric_type)[1],
         " in context: ", context, call. = FALSE)
  }

  if (nchar(metric_type) == 0) {
    stop("metric_type is empty string in context: ", context, call. = FALSE)
  }

  if (!is_valid_metric_type(metric_type)) {
    stop("Invalid metric_type: '", metric_type, "' in context: ", context,
         "\nValid types are: ", paste(VALID_METRIC_TYPES, collapse = ", "),
         call. = FALSE)
  }

  invisible(NULL)
}


#' Validate result object has valid metric_type
#'
#' @param result List object that should contain a metric_type field
#' @param context Character string describing where validation occurred
#' @return NULL (stops execution if invalid)
#' @export
validate_result_metric_type <- function(result, context = "unknown") {
  if (!is.list(result)) {
    stop("Result is not a list in context: ", context, call. = FALSE)
  }

  if (!"metric_type" %in% names(result)) {
    stop("Result does not contain 'metric_type' field in context: ", context,
         "\nAvailable fields: ", paste(names(result), collapse = ", "),
         call. = FALSE)
  }

  validate_metric_type(result$metric_type, context = paste0(context, " (result$metric_type)"))

  invisible(NULL)
}


# ------------------------------------------------------------------------------
# METRIC TYPE PROPERTIES
# ------------------------------------------------------------------------------

#' Check if metric type represents numeric/continuous data
#'
#' @param metric_type Character string metric type
#' @return Logical TRUE if numeric type, FALSE otherwise
#' @export
is_numeric_metric <- function(metric_type) {
  validate_metric_type(metric_type, "is_numeric_metric")
  return(metric_type %in% c(METRIC_TYPES$MEAN,
                            METRIC_TYPES$RATING_ENHANCED,
                            METRIC_TYPES$COMPOSITE,
                            METRIC_TYPES$COMPOSITE_ENHANCED))
}


#' Check if metric type represents proportions/percentages
#'
#' @param metric_type Character string metric type
#' @return Logical TRUE if proportion type, FALSE otherwise
#' @export
is_proportion_metric <- function(metric_type) {
  validate_metric_type(metric_type, "is_proportion_metric")
  return(metric_type %in% c(METRIC_TYPES$PROPORTIONS,
                            METRIC_TYPES$MULTI_MENTION,
                            METRIC_TYPES$CATEGORY_MENTIONS))
}


#' Check if metric type is Net Promoter Score
#'
#' @param metric_type Character string metric type
#' @return Logical TRUE if NPS type, FALSE otherwise
#' @export
is_nps_metric <- function(metric_type) {
  validate_metric_type(metric_type, "is_nps_metric")
  return(metric_type == METRIC_TYPES$NPS)
}


#' Check if metric type represents enhanced/custom metrics
#'
#' @param metric_type Character string metric type
#' @return Logical TRUE if enhanced type, FALSE otherwise
#' @export
is_enhanced_metric <- function(metric_type) {
  validate_metric_type(metric_type, "is_enhanced_metric")
  return(metric_type %in% c(METRIC_TYPES$RATING_ENHANCED,
                            METRIC_TYPES$COMPOSITE_ENHANCED))
}


#' Check if metric type is multi-mention (select all that apply)
#'
#' @param metric_type Character string metric type
#' @return Logical TRUE if multi-mention type, FALSE otherwise
#' @export
is_multi_mention_metric <- function(metric_type) {
  validate_metric_type(metric_type, "is_multi_mention_metric")
  return(metric_type %in% c(METRIC_TYPES$MULTI_MENTION,
                            METRIC_TYPES$CATEGORY_MENTIONS))
}


# ------------------------------------------------------------------------------
# FORMATTING HELPERS
# ------------------------------------------------------------------------------

#' Get display name for metric type
#'
#' @param metric_type Character string metric type
#' @return Character string display name
#' @export
get_metric_type_display_name <- function(metric_type) {
  validate_metric_type(metric_type, "get_metric_type_display_name")

  display_names <- list(
    mean = "Mean Score",
    nps = "Net Promoter Score",
    proportions = "Proportions",
    rating_enhanced = "Enhanced Rating",
    composite = "Composite Index",
    composite_enhanced = "Enhanced Composite Index",
    multi_mention = "Multi-Mention",
    category_mentions = "Category Mentions"
  )

  return(display_names[[metric_type]])
}


#' Get short display name for metric type
#'
#' @param metric_type Character string metric type
#' @return Character string short display name
#' @export
get_metric_type_short_name <- function(metric_type) {
  validate_metric_type(metric_type, "get_metric_type_short_name")

  short_names <- list(
    mean = "Mean",
    nps = "NPS",
    proportions = "Prop",
    rating_enhanced = "Rating",
    composite = "Composite",
    composite_enhanced = "Composite",
    multi_mention = "Multi",
    category_mentions = "Categories"
  )

  return(short_names[[metric_type]])
}


# ------------------------------------------------------------------------------
# MIGRATION HELPERS
# ------------------------------------------------------------------------------

#' Convert legacy metric type names to current standard
#'
#' @param metric_type Character string (possibly legacy) metric type
#' @return Character string standardized metric type
#' @export
normalize_metric_type <- function(metric_type) {
  if (is.null(metric_type) || length(metric_type) == 0) {
    stop("Cannot normalize NULL or empty metric_type", call. = FALSE)
  }

  # Handle legacy or typo variants
  legacy_mapping <- list(
    "proportion" = METRIC_TYPES$PROPORTIONS,  # Singular typo
    "multi-mention" = METRIC_TYPES$MULTI_MENTION,  # Hyphenated variant
    "category-mentions" = METRIC_TYPES$CATEGORY_MENTIONS  # Hyphenated variant
  )

  if (metric_type %in% names(legacy_mapping)) {
    normalized <- legacy_mapping[[metric_type]]
    warning("Converted legacy metric_type '", metric_type, "' to '", normalized, "'",
            call. = FALSE)
    return(normalized)
  }

  # If already valid, return as-is
  if (is_valid_metric_type(metric_type)) {
    return(metric_type)
  }

  # Otherwise, error
  stop("Unknown metric_type: '", metric_type, "' - cannot normalize",
       call. = FALSE)
}


# ==============================================================================
# END OF METRIC TYPES MODULE
# ==============================================================================
