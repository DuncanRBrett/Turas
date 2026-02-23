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


#' Validate metric type and refuse if invalid
#'
#' @param metric_type Character string to validate
#' @param context Character string describing where validation occurred (for error messages)
#' @return NULL invisibly (throws turas_refusal condition if invalid)
#' @export
validate_metric_type <- function(metric_type, context = "unknown") {
  if (is.null(metric_type)) {
    tracker_refuse(
      code = "DATA_METRIC_TYPE_NULL",
      title = "Metric Type Is NULL",
      problem = paste0("metric_type is NULL in context: ", context),
      why_it_matters = "Every metric requires a valid type to determine how calculations and formatting are applied.",
      how_to_fix = "Ensure the metric_type parameter is set to one of the valid types before calling this function."
    )
  }

  if (length(metric_type) == 0) {
    tracker_refuse(
      code = "DATA_METRIC_TYPE_EMPTY",
      title = "Metric Type Has Zero Length",
      problem = paste0("metric_type has length zero in context: ", context),
      why_it_matters = "A zero-length metric_type cannot be matched to any calculation or formatting logic.",
      how_to_fix = "Provide a single character string as metric_type. Valid types are: mean, nps, proportions, rating_enhanced, composite, composite_enhanced, multi_mention, category_mentions."
    )
  }

  if (!is.character(metric_type)) {
    tracker_refuse(
      code = "DATA_METRIC_TYPE_WRONG_CLASS",
      title = "Metric Type Is Not a Character String",
      problem = paste0("metric_type must be a character string, got ", class(metric_type)[1],
                       " in context: ", context),
      why_it_matters = "Metric type lookups require a character string. A non-character value will cause downstream failures.",
      how_to_fix = paste0("Convert metric_type to character or ensure the correct value is passed. Got class: ",
                          class(metric_type)[1])
    )
  }

  if (nchar(metric_type) == 0) {
    tracker_refuse(
      code = "DATA_METRIC_TYPE_EMPTY_STRING",
      title = "Metric Type Is Empty String",
      problem = paste0("metric_type is an empty string in context: ", context),
      why_it_matters = "An empty string cannot match any valid metric type and will cause silent misrouting of calculations.",
      how_to_fix = "Provide a non-empty metric_type. Valid types are: mean, nps, proportions, rating_enhanced, composite, composite_enhanced, multi_mention, category_mentions."
    )
  }

  if (!is_valid_metric_type(metric_type)) {
    tracker_refuse(
      code = "DATA_METRIC_TYPE_INVALID",
      title = "Invalid Metric Type",
      problem = paste0("Invalid metric_type: '", metric_type, "' in context: ", context),
      why_it_matters = "An unrecognised metric type will cause calculation failures or incorrect output formatting.",
      how_to_fix = paste0("Use one of the valid metric types: ",
                          paste(VALID_METRIC_TYPES, collapse = ", "),
                          ". Got: '", metric_type, "'")
    )
  }

  invisible(NULL)
}


#' Validate result object has valid metric_type
#'
#' @param result List object that should contain a metric_type field
#' @param context Character string describing where validation occurred
#' @return NULL invisibly (throws turas_refusal condition if invalid)
#' @export
validate_result_metric_type <- function(result, context = "unknown") {
  if (!is.list(result)) {
    tracker_refuse(
      code = "DATA_RESULT_NOT_LIST",
      title = "Result Object Is Not a List",
      problem = paste0("Result is not a list in context: ", context,
                       ". Got class: ", class(result)[1]),
      why_it_matters = "Result objects must be lists with a metric_type field to route calculations correctly.",
      how_to_fix = "Ensure the function producing this result returns a list with at least a 'metric_type' field."
    )
  }

  if (!"metric_type" %in% names(result)) {
    tracker_refuse(
      code = "DATA_RESULT_MISSING_METRIC_TYPE",
      title = "Result Missing metric_type Field",
      problem = paste0("Result does not contain 'metric_type' field in context: ", context),
      why_it_matters = "Without a metric_type field, the system cannot determine how to process or format results.",
      how_to_fix = paste0("Add a 'metric_type' field to the result list. Available fields: ",
                          paste(names(result), collapse = ", "))
    )
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
    tracker_refuse(
      code = "DATA_METRIC_TYPE_NULL",
      title = "Cannot Normalize NULL/Empty Metric Type",
      problem = "metric_type is NULL or has zero length - cannot normalize.",
      why_it_matters = "Normalization requires a non-empty metric_type string to map legacy names to current standards.",
      how_to_fix = "Provide a non-NULL, non-empty character string as metric_type."
    )
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

  # Otherwise, refuse with actionable message
  tracker_refuse(
    code = "DATA_METRIC_TYPE_INVALID",
    title = "Unknown Metric Type - Cannot Normalize",
    problem = paste0("Unknown metric_type: '", metric_type, "' - cannot normalize."),
    why_it_matters = "An unrecognised metric type cannot be mapped to any valid type and will cause downstream failures.",
    how_to_fix = paste0("Use one of the valid metric types: ",
                        paste(VALID_METRIC_TYPES, collapse = ", "),
                        ". If this is a legacy name, add it to the legacy_mapping in normalize_metric_type().")
  )
}


# ==============================================================================
# END OF METRIC TYPES MODULE
# ==============================================================================
