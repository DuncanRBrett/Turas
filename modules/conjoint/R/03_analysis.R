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
#' Uses conditional logit to estimate part-worth utilities from choice data.
#'
#' DATA FORMAT EXPECTED:
#' - One row per alternative per choice set
#' - choice_set_id: identifies the choice task
#' - chosen: 1 if selected, 0 otherwise
#' - attribute columns: levels for each attribute
#'
#' @keywords internal
estimate_choice_based_conjoint <- function(data, config) {

  df <- data$data
  attributes <- config$attributes

  # Get column names
  choice_set_col <- config$settings$choice_set_column %||% "choice_set_id"
  chosen_col <- config$settings$chosen_column %||% "chosen"
  respondent_col <- config$settings$respondent_id_column %||% "respondent_id"

  # Validate required columns exist
  required_cols <- c(choice_set_col, chosen_col)
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop("Missing required columns for choice-based conjoint: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  # Validate attributes exist
  attribute_cols <- attributes$AttributeName
  missing_attrs <- setdiff(attribute_cols, names(df))
  if (length(missing_attrs) > 0) {
    stop("Missing attribute columns: ", paste(missing_attrs, collapse = ", "),
         call. = FALSE)
  }

  # Convert attributes to factors
  for (attr in attribute_cols) {
    df[[attr]] <- factor(df[[attr]])
  }

  # Build formula for conditional logit
  # Format: chosen ~ attr1 + attr2 + ... + strata(choice_set_id)
  formula_str <- paste(
    chosen_col, "~",
    paste(attribute_cols, collapse = " + "),
    "+ survival::strata(", choice_set_col, ")"
  )
  model_formula <- as.formula(formula_str)

  # Check if survival package is available and load it
  if (!requireNamespace("survival", quietly = TRUE)) {
    stop("Package 'survival' required for choice-based conjoint. Install with: install.packages('survival')",
         call. = FALSE)
  }

  # Load survival package (needed for clogit's internal coxph call)
  library(survival)

  # Fit conditional logit model
  model <- survival::clogit(model_formula, data = df)

  # Extract utilities from coefficients
  coefs <- coef(model)

  # DEBUG: Print coefficient names
  cat("\n--- DEBUG: Model coefficient names ---\n")
  print(names(coefs))
  cat("--------------------------------------\n\n")

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

  # Model fit statistics
  # For clogit, we use likelihood-based measures
  null_loglik <- model$loglik[1]
  full_loglik <- model$loglik[2]

  # McFadden's pseudo R-squared
  mcfadden_r2 <- 1 - (full_loglik / null_loglik)

  # Count R-squared (prediction accuracy)
  # Predict choice probabilities for each alternative
  if (respondent_col %in% names(df)) {
    # Calculate hit rate (% correctly predicted choices)
    pred_probs <- predict(model, type = "expected")

    # For each choice set, find alternative with highest predicted probability
    choice_sets <- unique(df[[choice_set_col]])
    correct_predictions <- 0

    for (cs in choice_sets) {
      cs_data <- df[df[[choice_set_col]] == cs, ]
      cs_probs <- pred_probs[df[[choice_set_col]] == cs]

      predicted_choice <- which.max(cs_probs)
      actual_choice <- which(cs_data[[chosen_col]] == 1)

      if (length(actual_choice) > 0 && predicted_choice == actual_choice[1]) {
        correct_predictions <- correct_predictions + 1
      }
    }

    hit_rate <- correct_predictions / length(choice_sets)
  } else {
    hit_rate <- NA
  }

  fit <- list(
    mcfadden_r2 = mcfadden_r2,
    hit_rate = hit_rate,
    log_likelihood = full_loglik,
    aic = AIC(model),
    bic = BIC(model),
    n_obs = nrow(df),
    n_choice_sets = length(unique(df[[choice_set_col]]))
  )

  list(
    utilities = utilities_df,
    model = model,
    fit = fit
  )
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
