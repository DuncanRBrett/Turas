# ==============================================================================
# INTERACTION EFFECTS - ADVANCED CONJOINT ANALYSIS
# ==============================================================================
#
# This file implements interaction effects for conjoint analysis, allowing
# testing of whether the effect of one attribute depends on another.
#
# Types of interactions supported:
# - Two-way interactions (Attribute A × Attribute B)
# - Higher-order interactions (optional)
# - Automatic interaction detection
#
# Part of: Turas Enhanced Conjoint Analysis Module
# Version: 2.0.0
# ==============================================================================

# ==============================================================================
# 1. INTERACTION SPECIFICATION
# ==============================================================================

#' Specify interaction terms for conjoint model
#'
#' @param attributes Character vector of attribute names
#' @param interactions List of character vectors, each with 2+ attribute names
#'                     Example: list(c("Price", "Brand"), c("Size", "Color"))
#' @param auto_detect Logical: automatically detect promising interactions?
#' @param max_interactions Integer: maximum number of auto-detected interactions
#'
#' @return List with interaction specifications
#'
#' @examples
#' spec <- specify_interactions(
#'   attributes = c("Price", "Brand", "Size", "Color"),
#'   interactions = list(c("Price", "Brand")),
#'   auto_detect = FALSE
#' )
specify_interactions <- function(attributes,
                                  interactions = list(),
                                  auto_detect = FALSE,
                                  max_interactions = 3) {

  # Validate interactions
  if (length(interactions) > 0) {
    for (int in interactions) {
      if (length(int) < 2) {
        stop("Each interaction must involve at least 2 attributes")
      }

      missing_attrs <- setdiff(int, attributes)
      if (length(missing_attrs) > 0) {
        stop(sprintf("Interaction attributes not found: %s",
                     paste(missing_attrs, collapse = ", ")))
      }
    }
  }

  # Auto-detect interactions if requested
  if (auto_detect && length(interactions) < max_interactions) {
    # Generate all possible 2-way interactions
    all_pairs <- combn(attributes, 2, simplify = FALSE)

    # Filter out already-specified interactions
    new_pairs <- setdiff(all_pairs, interactions)

    # Add up to max_interactions
    n_to_add <- min(max_interactions - length(interactions), length(new_pairs))
    if (n_to_add > 0) {
      interactions <- c(interactions, new_pairs[1:n_to_add])
    }
  }

  structure(
    list(
      attributes = attributes,
      interactions = interactions,
      n_interactions = length(interactions)
    ),
    class = "conjoint_interactions"
  )
}


# ==============================================================================
# 2. MODEL ESTIMATION WITH INTERACTIONS
# ==============================================================================

#' Estimate choice model with interaction effects
#'
#' @param data_list Data list from load_conjoint_data()
#' @param config Configuration object
#' @param interaction_spec Interaction specification from specify_interactions()
#' @param verbose Logical: print progress?
#'
#' @return Model result with interaction effects
estimate_with_interactions <- function(data_list,
                                        config,
                                        interaction_spec,
                                        verbose = TRUE) {

  if (verbose) {
    cat(sprintf("\nEstimating model with %d interaction term(s):\n",
                interaction_spec$n_interactions))
    for (int in interaction_spec$interactions) {
      cat(sprintf("  - %s\n", paste(int, collapse = " × ")))
    }
  }

  # Prepare data with interaction terms
  data <- data_list$data
  data_with_int <- create_interaction_terms(data, config, interaction_spec)

  # Update config to include interaction attributes
  config_with_int <- add_interactions_to_config(config, interaction_spec)

  # Estimate model
  if (config$estimation_method == "mlogit" ||
      config$estimation_method == "auto") {
    result <- estimate_mlogit_with_interactions(
      data_with_int, config_with_int, verbose = verbose
    )
  } else {
    stop("Interaction effects only supported with mlogit estimation method")
  }

  # Add interaction information to result
  result$has_interactions <- TRUE
  result$interaction_spec <- interaction_spec
  result$base_attributes <- interaction_spec$attributes
  result$interaction_terms <- interaction_spec$interactions

  result
}


#' Create interaction terms in data
#'
#' @param data Data frame
#' @param config Configuration
#' @param interaction_spec Interaction specification
#'
#' @return Data frame with interaction columns added
create_interaction_terms <- function(data, config, interaction_spec) {

  data_copy <- data

  for (int in interaction_spec$interactions) {
    # Create interaction column name
    int_name <- paste(int, collapse = "_x_")

    # Create interaction variable (concatenate levels)
    int_values <- do.call(paste, c(data_copy[int], sep = ":"))

    data_copy[[int_name]] <- int_values
  }

  data_copy
}


#' Add interaction terms to configuration
#'
#' @param config Configuration object
#' @param interaction_spec Interaction specification
#'
#' @return Updated configuration with interaction attributes
add_interactions_to_config <- function(config, interaction_spec) {

  config_copy <- config

  # Add interaction attributes to attributes data frame
  for (int in interaction_spec$interactions) {
    int_name <- paste(int, collapse = "_x_")

    # Get unique combinations
    # This would need access to actual data - placeholder for now
    config_copy$interaction_attributes <- c(
      config_copy$interaction_attributes %||% character(0),
      int_name
    )
  }

  config_copy
}


#' Estimate mlogit model with interaction terms
#'
#' @keywords internal
estimate_mlogit_with_interactions <- function(data, config, verbose = TRUE) {

  if (!requireNamespace("mlogit", quietly = TRUE)) {
    stop("Package 'mlogit' required for interaction effects. Install with: install.packages('mlogit')")
  }

  # Prepare formula with interactions
  formula <- build_interaction_formula(config)

  if (verbose) {
    cat(sprintf("\nFormula: %s\n", deparse(formula)))
  }

  # Convert to mlogit format
  data_mlogit <- prepare_mlogit_data(data, config)

  # Estimate model
  model <- tryCatch({
    mlogit::mlogit(
      formula,
      data = data_mlogit,
      reflevel = 1  # First alternative as reference
    )
  }, error = function(e) {
    stop(create_error(
      "ESTIMATION",
      sprintf("mlogit with interactions failed: %s", conditionMessage(e)),
      "Try reducing number of interactions or check for perfect separation",
      sprintf("Formula: %s", deparse(formula))
    ), call. = FALSE)
  })

  # Extract results
  extract_mlogit_results(model, data_mlogit, config)
}


#' Build formula with interaction terms
#'
#' @keywords internal
build_interaction_formula <- function(config) {

  # Main effects
  main_effects <- config$attributes$AttributeName

  # Interaction effects (if any)
  int_effects <- config$interaction_attributes %||% character(0)

  # Combine
  all_terms <- c(main_effects, int_effects)

  # Build formula
  formula_str <- sprintf("choice ~ %s | 0", paste(all_terms, collapse = " + "))

  as.formula(formula_str)
}


# ==============================================================================
# 3. INTERACTION ANALYSIS
# ==============================================================================

#' Analyze interaction effects
#'
#' @param model_result Model result with interactions
#' @param interaction_term Character vector: attributes in interaction
#' @param config Configuration
#'
#' @return Data frame with interaction analysis
analyze_interaction <- function(model_result, interaction_term, config) {

  if (!model_result$has_interactions) {
    stop("Model does not include interaction effects")
  }

  int_name <- paste(interaction_term, collapse = "_x_")

  # Extract coefficients for this interaction
  int_coefs <- model_result$coefficients[grepl(int_name, names(model_result$coefficients))]

  if (length(int_coefs) == 0) {
    stop(sprintf("Interaction %s not found in model", int_name))
  }

  # Parse interaction combinations
  combinations <- strsplit(names(int_coefs), ":")
  combinations <- do.call(rbind, combinations)

  # Create data frame
  result <- data.frame(
    Interaction = int_name,
    Combination = names(int_coefs),
    Coefficient = unname(int_coefs),
    stringsAsFactors = FALSE
  )

  # Add standard errors if available
  if (!is.null(model_result$std_errors)) {
    int_se <- model_result$std_errors[grepl(int_name, names(model_result$std_errors))]
    result$Std_Error <- unname(int_se)

    # Calculate significance
    result$Z_Value <- result$Coefficient / result$Std_Error
    result$P_Value <- 2 * pnorm(-abs(result$Z_Value))
    result$Significant <- result$P_Value < 0.05
  }

  result
}


#' Test significance of interaction effects
#'
#' @param model_with_int Model with interactions
#' @param model_without_int Model without interactions (main effects only)
#'
#' @return List with likelihood ratio test results
test_interaction_significance <- function(model_with_int, model_without_int) {

  # Extract log-likelihoods
  ll_with <- model_with_int$loglik[2]  # Fitted model LL
  ll_without <- model_without_int$loglik[2]

  # Calculate LR test statistic
  lr_stat <- -2 * (ll_without - ll_with)

  # Degrees of freedom = difference in number of parameters
  df <- length(model_with_int$coefficients) - length(model_without_int$coefficients)

  # P-value from chi-squared distribution
  p_value <- pchisq(lr_stat, df, lower.tail = FALSE)

  list(
    lr_statistic = lr_stat,
    df = df,
    p_value = p_value,
    significant = p_value < 0.05,
    ll_with_interactions = ll_with,
    ll_without_interactions = ll_without,
    improvement = ll_with - ll_without
  )
}


# ==============================================================================
# 4. VISUALIZATION AND INTERPRETATION
# ==============================================================================

#' Create interaction plot data
#'
#' @param model_result Model with interactions
#' @param interaction_term Character vector: attributes in interaction
#' @param config Configuration
#'
#' @return Data frame for plotting interaction effects
prepare_interaction_plot <- function(model_result, interaction_term, config) {

  # Analyze interaction
  int_analysis <- analyze_interaction(model_result, interaction_term, config)

  # Parse combinations into separate columns
  combos <- strsplit(int_analysis$Combination, ":")

  # Assuming 2-way interaction
  if (length(interaction_term) == 2) {
    attr1_levels <- sapply(combos, `[`, 1)
    attr2_levels <- sapply(combos, `[`, 2)

    plot_data <- data.frame(
      Attribute1 = interaction_term[1],
      Level1 = attr1_levels,
      Attribute2 = interaction_term[2],
      Level2 = attr2_levels,
      Effect = int_analysis$Coefficient,
      Std_Error = int_analysis$Std_Error %||% NA,
      stringsAsFactors = FALSE
    )

    return(plot_data)
  }

  # For higher-order interactions, return raw analysis
  int_analysis
}


#' Interpret interaction effect
#'
#' @param interaction_analysis Result from analyze_interaction()
#' @param threshold Numeric: threshold for "strong" interaction
#'
#' @return Character vector of interpretations
interpret_interaction <- function(interaction_analysis, threshold = 0.5) {

  # Find strongest effects
  strongest_idx <- which.max(abs(interaction_analysis$Coefficient))
  strongest <- interaction_analysis[strongest_idx, ]

  # Interpretation
  if (abs(strongest$Coefficient) > threshold) {
    direction <- if (strongest$Coefficient > 0) "amplifies" else "diminishes"

    sprintf(
      "Strong interaction detected: %s %s the preference for this combination (coef = %.3f, p = %.3f)",
      strongest$Combination,
      direction,
      strongest$Coefficient,
      strongest$P_Value %||% NA
    )
  } else {
    sprintf(
      "Weak interaction: Effects are mostly additive (max |coef| = %.3f)",
      max(abs(interaction_analysis$Coefficient))
    )
  }
}


# ==============================================================================
# 5. UTILITY FUNCTIONS
# ==============================================================================

#' Check if model has interaction effects
#'
#' @param model_result Model result object
#'
#' @return Logical
has_interactions <- function(model_result) {
  !is.null(model_result$has_interactions) && model_result$has_interactions
}


#' Get list of interaction terms in model
#'
#' @param model_result Model result object
#'
#' @return List of character vectors, each defining an interaction
get_interaction_terms <- function(model_result) {
  if (!has_interactions(model_result)) {
    return(list())
  }

  model_result$interaction_terms
}


#' Format interaction term for display
#'
#' @param interaction_term Character vector of attribute names
#'
#' @return Character string
format_interaction <- function(interaction_term) {
  paste(interaction_term, collapse = " × ")
}
