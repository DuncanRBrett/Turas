# ==============================================================================
# CONJOINT ANALYSIS - CORE ALGORITHMS
# ==============================================================================

#' Calculate Conjoint Part-Worth Utilities
#'
#' Estimates part-worth utilities using regression-based approach.
#'
#' METHODOLOGY:
#' - Uses dummy coding for categorical attributes
#' - OLS regression for rating-based designs
#' - Logistic regression for choice-based designs
#' - Zero-centered utilities (sum to zero within each attribute)
#'
#' @param data Data list from load_conjoint_data()
#' @param config Configuration list
#' @return List with utilities and model fit statistics
#' @keywords internal
calculate_conjoint_utilities <- function(data, config) {

  # TODO: Implement full conjoint analysis based on design type
  # This is a template showing the structure

  analysis_type <- config$settings$analysis_type %||% "rating"

  if (analysis_type == "choice") {
    results <- estimate_choice_based_conjoint(data, config)
  } else {
    results <- estimate_rating_based_conjoint(data, config)
  }

  results
}


#' Estimate Rating-Based Conjoint
#'
#' @keywords internal
estimate_rating_based_conjoint <- function(data, config) {

  df <- data$data
  attributes <- config$attributes

  # Build formula for regression
  # Dependent variable
  dv <- config$settings$rating_variable %||% "rating"

  if (!dv %in% names(df)) {
    stop("Rating variable '", dv, "' not found in data", call. = FALSE)
  }

  # Independent variables (attributes as factors)
  attribute_cols <- attributes$AttributeName

  # Check attributes exist
  missing_attrs <- setdiff(attribute_cols, names(df))
  if (length(missing_attrs) > 0) {
    stop("Missing attribute columns: ", paste(missing_attrs, collapse = ", "),
         call. = FALSE)
  }

  # Convert attributes to factors
  for (attr in attribute_cols) {
    df[[attr]] <- factor(df[[attr]])
  }

  # Build formula
  formula_str <- paste(dv, "~", paste(attribute_cols, collapse = " + "))
  model_formula <- as.formula(formula_str)

  # Fit model
  model <- lm(model_formula, data = df)

  # Extract utilities from coefficients
  coefs <- coef(model)

  # Create utilities data frame
  utilities_list <- list()

  for (attr in attribute_cols) {
    # Get coefficients for this attribute
    attr_coefs <- coefs[grep(paste0("^", attr), names(coefs))]

    # Extract level names from coefficient names
    level_names <- gsub(paste0("^", attr), "", names(attr_coefs))

    # Get all levels for this attribute
    all_levels <- attributes$levels_list[attributes$AttributeName == attr][[1]]

    # Initialize utilities vector
    utilities <- numeric(length(all_levels))
    names(utilities) <- all_levels

    # Assign coefficients (first level is reference, utility = 0)
    utilities[level_names] <- attr_coefs

    # Zero-center utilities (sum to zero within attribute)
    utilities <- utilities - mean(utilities)

    # Store
    for (i in seq_along(utilities)) {
      utilities_list[[length(utilities_list) + 1]] <- data.frame(
        Attribute = attr,
        Level = names(utilities)[i],
        Utility = utilities[i],
        stringsAsFactors = FALSE
      )
    }
  }

  utilities_df <- do.call(rbind, utilities_list)

  # Model fit
  fit <- list(
    r_squared = summary(model)$r.squared,
    adj_r_squared = summary(model)$adj.r.squared,
    rmse = sqrt(mean(residuals(model)^2)),
    n_obs = nrow(df)
  )

  list(
    utilities = utilities_df,
    model = model,
    fit = fit
  )
}


#' Estimate Choice-Based Conjoint
#'
#' @keywords internal
estimate_choice_based_conjoint <- function(data, config) {
  # TODO: Implement choice-based conjoint using multinomial logit
  stop("Choice-based conjoint not yet implemented. Use analysis_type = 'rating'",
       call. = FALSE)
}


#' Calculate Attribute Importance
#'
#' Calculates attribute importance as % of total utility range.
#'
#' @param utilities Utilities data frame
#' @param config Configuration list
#' @return Data frame with attribute importance scores
#' @keywords internal
calculate_attribute_importance <- function(utilities, config) {

  # Calculate range of utilities for each attribute
  ranges <- aggregate(Utility ~ Attribute, data = utilities, FUN = function(x) {
    max(x) - min(x)
  })
  names(ranges)[2] <- "Range"

  # Calculate importance as % of total range
  total_range <- sum(ranges$Range)
  ranges$Importance <- (ranges$Range / total_range) * 100

  # Sort by importance descending
  ranges <- ranges[order(-ranges$Importance), ]

  ranges
}


#' @keywords internal
`%||%` <- function(x, y) if (is.null(x)) y else x
