# ==============================================================================
# QUESTION TYPES CONFIGURATION - IMPROVED PATTERNS
# ==============================================================================

#' Get Question Types
get_question_types <- function() {
  list(
    "Single_Response" = "Single choice question (select one)",
    "Multi_Mention" = "Multiple choice question (select all that apply)",
    "Likert" = "Likert scale (strongly agree to strongly disagree)",
    "Rating" = "Rating scale (e.g., 1-5 stars, 1-7 scale)",
    "NPS" = "Net Promoter Score (0-10 likelihood to recommend)",
    "Numeric" = "Numeric input or numeric bins",
    "Ranking" = "Rank items in order of preference",
    "Text" = "Open-ended text response"
  )
}

#' Get Question Type Patterns - IMPROVED
get_question_type_patterns <- function() {
  list(
    # NPS (very specific - check first)
    "NPS" = paste0(
      "(?:net.*promoter|",
      "how.*likely.*recommend|",
      "likelihood.*recommend|",
      "recommend.*(?:to|on).*scale.*(?:0.*10|ten)|",
      "(?:0.*10|0-10).*(?:scale|likely|recommend))"
    ),
    
    # Numeric (before Rating since it's more general)
    "Numeric" = paste0(
      "(?:how.*many|",
      "number.*of|",
      "enter.*number|",
      "quantity|",
      "what.*is.*your.*age|",
      "your.*age|",
      "income.*(?:range|level|bracket)?|",
      "percentage|",
      "percent|",
      "how.*much|",
      "total|",
      "count)"
    ),
    
    # Ranking
    "Ranking" = paste0(
      "(?:rank.*(?:order|following|items)|",
      "place.*in.*order|",
      "order.*(?:of|by).*(?:preference|importance|priority)|",
      "prioritize|",
      "arrange.*(?:in.*)?order|",
      "drag.*drop|",
      "position.*order)"
    ),
    
    # Rating scales (before Likert)
    "Rating" = paste0(
      "(?:rate.*(?:following|quality|service|experience|satisfaction)|",
      "rating.*(?:scale|of)|",
      "scale.*(?:of|from).*\\d+|",
      "on.*scale.*(?:of|from).*\\d+.*(?:to|through|-|–).*\\d+|",
      "\\d+.*(?:to|through|-|–).*\\d+.*scale|",
      "how.*would.*you.*rate|",
      "(?:1|one).*(?:to|-|through|–).*(?:5|10|seven|ten)|",
      "stars?|",
      "out.*of.*\\d+)"
    ),
    
    # Likert scales
    "Likert" = paste0(
      "(?:strongly.*(?:agree|disagree)|",
      "agree.*disagree|",
      "extent.*(?:agree|disagree)|",
      "satisfaction.*(?:level|with)|",
      "satisfied.*dissatisfied|",
      "how.*satisfied|",
      "satisfaction.*(?:is|was)|",
      "to.*what.*extent|",
      "indicate.*agreement|",
      "somewhat.*agree)"
    ),
    
    # Multiple choice (select all)
    "Multi_Mention" = paste0(
      "(?:select.*all.*(?:that.*)?apply|",
      "check.*all.*(?:that.*)?apply|",
      "choose.*all.*(?:that.*)?apply|",
      "pick.*all.*(?:that.*)?apply|",
      "mark.*all.*(?:that.*)?apply|",
      "tick.*all.*(?:that.*)?apply|",
      "indicate.*all.*(?:that.*)?apply|",
      "which.*of.*following.*apply|",
      "all.*that.*apply)"
    ),
    
    # Open text (least specific - check last)
    "Text" = paste0(
      "(?:please.*explain|",
      "describe|",
      "comment|",
      "additional.*comment|",
      "tell.*us.*(?:more|about|why)|",
      "in.*your.*own.*words|",
      "why.*(?:did|do)|",
      "what.*(?:did|do).*you.*(?:think|feel)|",
      "feedback|",
      "suggestions?|",
      "please.*specify|",
      "other.*(?:please.*)?specify)"
    )
  )
}

#' Get Question Type Metadata
get_question_type_metadata <- function() {
  list(
    "Single_Response" = list(
      requires_options = TRUE,
      supports_bins = FALSE,
      typical_option_count = c(2, 10),
      data_types = c("character", "factor", "numeric"),
      notes = "Standard single-choice question"
    ),
    
    "Multi_Mention" = list(
      requires_options = TRUE,
      supports_bins = FALSE,
      typical_option_count = c(2, 20),
      data_types = c("character", "numeric", "logical"),
      notes = "Requires Columns field in Questions sheet",
      requires_columns = TRUE
    ),
    
    "Likert" = list(
      requires_options = TRUE,
      supports_bins = FALSE,
      typical_option_count = c(3, 7),
      data_types = c("character", "factor", "numeric"),
      notes = "Typically 3, 5, or 7 point scale",
      supports_index = TRUE
    ),
    
    "Rating" = list(
      requires_options = TRUE,
      supports_bins = FALSE,
      typical_option_count = c(3, 10),
      data_types = c("numeric", "character"),
      notes = "Numeric scale (e.g., 1-5, 1-7, 1-10)"
    ),
    
    "NPS" = list(
      requires_options = FALSE,
      supports_bins = FALSE,
      typical_option_count = c(11, 11),
      data_types = c("numeric"),
      notes = "Must be 0-10 scale. Calculates NPS score."
    ),
    
    "Numeric" = list(
      requires_options = FALSE,
      supports_bins = TRUE,
      typical_option_count = c(0, 10),
      data_types = c("numeric", "integer"),
      notes = "Can have optional bins in Options sheet with Min/Max"
    ),
    
    "Ranking" = list(
      requires_options = TRUE,
      supports_bins = FALSE,
      typical_option_count = c(3, 10),
      data_types = c("numeric"),
      notes = "Requires Ranking_Format and Ranking_Positions in Questions sheet",
      requires_ranking_fields = TRUE
    ),
    
    "Text" = list(
      requires_options = FALSE,
      supports_bins = FALSE,
      typical_option_count = c(0, 0),
      data_types = c("character"),
      notes = "Open-ended response. Not analyzed in crosstabs."
    )
  )
}

#' Get Alchemer Question Type Mappings
get_alchemer_type_mappings <- function() {
  list(
    "Radio Button" = "Single_Response",
    "Checkbox" = "Multi_Mention",
    "Menu (Dropdown)" = "Single_Response",
    "Text Box" = "Text",
    "Essay" = "Text",
    "Number" = "Numeric",
    "Net Promoter Score" = "NPS",
    "Rating Scale" = "Rating",
    "Rank Order" = "Ranking",
    "Likert" = "Likert",
    "Matrix (Single)" = "Single_Response",
    "Matrix (Multi)" = "Multi_Mention",
    "Slider" = "Rating",
    "Date/Time" = "Text",
    "Image Choice" = "Single_Response",
    "Constant Sum" = "Numeric"
  )
}

#' Validate Question Type Configuration
validate_question_type_config <- function() {
  types <- names(get_question_types())
  patterns <- names(get_question_type_patterns())
  metadata <- names(get_question_type_metadata())
  
  active_types <- types[!grepl("^#", types)]
  missing_patterns <- setdiff(active_types, patterns)
  if (length(missing_patterns) > 0) {
    stop("Question types missing patterns: ", paste(missing_patterns, collapse = ", "))
  }
  
  missing_metadata <- setdiff(active_types, metadata)
  if (length(missing_metadata) > 0) {
    warning("Question types missing metadata: ", paste(missing_metadata, collapse = ", "))
  }
  
  message("✓ Question type configuration is valid")
  return(TRUE)
}
