# ==============================================================================
# CATEGORICAL KEY DRIVER - CANONICAL DESIGN-MATRIX MAPPER
# ==============================================================================
#
# Proper term-to-level mapping using model matrix introspection.
# Never infers levels by string slicing.
#
# Version: 2.0
# Date: December 2024
#
# ==============================================================================

#' Map Model Terms to Factor Levels
#'
#' Creates a reliable mapping from model coefficient names to original
#' variable names and factor levels using model matrix attributes.
#'
#' CRITICAL: This function uses POSITIONAL MAPPING via the assign attribute,
#' NOT string parsing. This is the only reliable approach because R's column
#' naming can vary (e.g., "gradeB" vs "grade2" depending on factor encoding).
#'
#' @param model Fitted model object (glm, polr, or multinom)
#' @param data Data frame used for fitting
#' @param formula Model formula
#' @return Data frame with columns:
#'   - driver: Original variable name
#'   - level: Factor level (or NA for continuous)
#'   - design_col: Column name in design matrix / coefficient name
#'   - coef_name: Coefficient name in model output
#'   - reference_level: Reference level for this variable
#'   - is_reference: Logical - TRUE if this is the reference level
#'   - outcome_level: For multinomial, the outcome being compared (or NA)
#' @export
map_terms_to_levels <- function(model, data, formula = NULL) {

  # Get formula from model if not provided
  if (is.null(formula)) {
    formula <- tryCatch(formula(model), error = function(e) NULL)
    if (is.null(formula)) {
      formula <- tryCatch(model$terms, error = function(e) NULL)
    }
  }

  if (is.null(formula)) {
    catdriver_refuse(
      reason = "MAPPER_NO_FORMULA",
      title = "CANNOT EXTRACT FORMULA FROM MODEL",
      problem = "Could not extract the model formula for term mapping.",
      why_it_matters = "Term-to-level mapping requires the formula to understand model structure.",
      fix = "This may indicate a model type that is not fully supported. Please report this issue."
    )
  }

  # Build model frame and matrix
  mf <- tryCatch(
    model.frame(formula, data, na.action = na.pass),
    error = function(e) {
      # Fallback for models that store model frame
      if (!is.null(model$model)) return(model$model)
      if (!is.null(model[["model"]])) return(model[["model"]])
      catdriver_refuse(
        reason = "MAPPER_MODEL_FRAME_FAILED",
        title = "CANNOT BUILD MODEL FRAME",
        problem = "Could not construct the model frame for term mapping.",
        why_it_matters = "The model frame is needed to understand the relationship between variables and coefficients.",
        fix = "Check that all variables in the formula exist in the data.",
        details = e$message
      )
    }
  )

  # Get the model matrix
  mm <- tryCatch(
    model.matrix(formula, data = mf),
    error = function(e) {
      # For ordinal/multinomial, try to extract from model
      if (!is.null(model$fitted.values)) {
        # polr stores model differently
        mm_tmp <- model.matrix(formula, data = data)
        return(mm_tmp)
      }
      catdriver_refuse(
        reason = "MAPPER_MODEL_MATRIX_FAILED",
        title = "CANNOT BUILD MODEL MATRIX",
        problem = "Could not construct the model matrix for term mapping.",
        why_it_matters = "The model matrix is needed to map coefficients back to original variables and levels.",
        fix = "Check that all predictor variables are properly formatted (factors should have valid levels).",
        details = e$message
      )
    }
  )

  # Get the terms object
  tt <- terms(formula, data = data)

  # Get assignment vector: maps each column to a term
  assign_vec <- attr(mm, "assign")
  if (is.null(assign_vec)) {
    # Fallback: try to build from term labels
    assign_vec <- attr(model.matrix(tt, data = mf), "assign")
  }

  # Validate assign_vec dimensions match model matrix
  if (is.null(assign_vec)) {
    catdriver_refuse(
      reason = "MAPPER_ASSIGN_VEC_MISSING",
      title = "MISSING ASSIGNMENT VECTOR",
      problem = "Could not obtain term assignment vector from model matrix.",
      why_it_matters = "The assignment vector is needed to map coefficients to their original variables.",
      fix = "This is an internal error. Please report this issue with your configuration."
    )
  }

  # Check that assign_vec length matches model matrix columns
  if (length(assign_vec) != ncol(mm)) {
    log_message(sprintf(
      "Assignment vector length (%d) does not match model matrix columns (%d). May affect term mapping.",
      length(assign_vec), ncol(mm)
    ), "warn")
  }

  # Get term labels (predictor names)
  term_labels <- attr(tt, "term.labels")

  # Get contrasts info
  contrasts_info <- attr(mm, "contrasts")

  # Get xlevels (factor levels used in model)
  xlevels <- model$xlevels
  if (is.null(xlevels)) {
    # Build from model frame - get levels for each factor variable
    xlevels <- list()
    for (var_name in term_labels) {
      if (var_name %in% names(mf) && is.factor(mf[[var_name]])) {
        xlevels[[var_name]] <- levels(mf[[var_name]])
      }
    }
  }

  # ============================================================================
  # POSITIONAL MAPPING - The ONLY reliable approach
  # ============================================================================
  # For each term (predictor), we know:
  # 1. Which columns belong to it (from assign_vec)
  # 2. The order of non-reference levels (from xlevels)
  # Column position within a term maps directly to non-reference level position.
  #
  # Example: grade with levels D, C, B, A (D=reference)
  # - assign_vec will have positions for 3 columns (one per non-ref level)
  # - Column 1 of this term = level C (position 2 in levels)
  # - Column 2 of this term = level B (position 3 in levels)
  # - Column 3 of this term = level A (position 4 in levels)
  # ============================================================================

  mapping_list <- list()
  col_names <- colnames(mm)

  for (term_idx in seq_along(term_labels)) {
    driver <- term_labels[term_idx]

    # Get all columns for this term
    term_col_indices <- which(assign_vec == term_idx)

    if (length(term_col_indices) == 0) next

    # Check if this is a factor variable
    is_factor_var <- driver %in% names(xlevels)

    if (is_factor_var) {
      levels_vec <- xlevels[[driver]]
      reference_level <- levels_vec[1]
      non_ref_levels <- levels_vec[-1]  # All levels except reference

      # CRITICAL: Check for polynomial contrasts BEFORE positional mapping
      # Polynomial contrast column names end in .L, .Q, .C, .^4, etc.
      first_col_name <- col_names[term_col_indices[1]]
      if (grepl("\\.(L|Q|C|\\^[0-9]+)$", first_col_name)) {
        catdriver_refuse(
          reason = "MAPPER_POLYNOMIAL_CONTRAST",
          title = "POLYNOMIAL CONTRAST DETECTED",
          problem = paste0(
            "Predictor '", driver, "' is using polynomial contrasts. ",
            "These cannot be mapped to factor levels for Factor Patterns output."
          ),
          why_it_matters = paste0(
            "Polynomial contrast coefficients (.L=linear, .Q=quadratic, .C=cubic) represent ",
            "trend effects, not comparisons between specific levels. Mapping them to levels ",
            "would produce misleading odds ratio interpretations."
          ),
          fix = paste0(
            "This usually indicates a bug in preprocessing. Ordinal predictors should use ",
            "treatment contrasts, not polynomial contrasts. Check that the predictor is ",
            "being processed correctly, or change its type to 'categorical' in Driver_Settings."
          )
        )
      }

      # Verify column count matches non-reference level count
      if (length(term_col_indices) != length(non_ref_levels)) {
        catdriver_refuse(
          reason = "MAPPER_COLUMN_COUNT_MISMATCH",
          title = "TERM-TO-LEVEL MAPPING FAILED",
          problem = paste0(
            "Predictor '", driver, "' has ", length(term_col_indices),
            " design matrix columns but ", length(non_ref_levels), " non-reference levels."
          ),
          why_it_matters = "Column count must match level count for positional mapping.",
          fix = "Check that the factor is properly defined with correct contrasts.",
          details = paste0(
            "Columns: ", paste(col_names[term_col_indices], collapse = ", "), "\n",
            "Non-ref levels: ", paste(non_ref_levels, collapse = ", ")
          )
        )
      }

      # POSITIONAL MAPPING: column i of this term -> non_ref_levels[i]
      for (j in seq_along(term_col_indices)) {
        col_idx <- term_col_indices[j]
        col_name <- col_names[col_idx]
        level <- non_ref_levels[j]

        mapping_list[[length(mapping_list) + 1]] <- data.frame(
          driver = driver,
          level = level,
          design_col = col_name,
          coef_name = col_name,
          reference_level = reference_level,
          is_reference = FALSE,
          stringsAsFactors = FALSE
        )
      }

      # Add reference level entry (not in design matrix but needed for output)
      mapping_list[[length(mapping_list) + 1]] <- data.frame(
        driver = driver,
        level = reference_level,
        design_col = NA,
        coef_name = NA,
        reference_level = reference_level,
        is_reference = TRUE,
        stringsAsFactors = FALSE
      )

    } else {
      # Continuous variable or other - single column per term
      for (col_idx in term_col_indices) {
        col_name <- col_names[col_idx]
        mapping_list[[length(mapping_list) + 1]] <- data.frame(
          driver = driver,
          level = NA,
          design_col = col_name,
          coef_name = col_name,
          reference_level = NA,
          is_reference = FALSE,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  mapping <- do.call(rbind, mapping_list)
  rownames(mapping) <- NULL

  # Add outcome_level column (for multinomial - filled in later)
  mapping$outcome_level <- NA

  mapping
}


#' Map Multinomial Model Terms
#'
#' Extends basic mapping to include outcome levels for multinomial models.
#'
#' @param model Fitted multinom model
#' @param data Data frame
#' @param formula Model formula
#' @param outcome_var Outcome variable name
#' @return Data frame with mapping including outcome_level
#' @export
map_multinomial_terms <- function(model, data, formula, outcome_var) {

  # Get base mapping
  base_mapping <- map_terms_to_levels(model, data, formula)

  # Get coefficient structure
  coef_matrix <- coef(model)

  # Handle single vs multiple equations
  if (is.null(dim(coef_matrix))) {
    # Single equation (3 outcome categories)
    outcome_levels <- names(model$lev)[-1]
    coef_matrix <- matrix(coef_matrix, nrow = 1,
                         dimnames = list(outcome_levels[1], names(coef_matrix)))
  }

  # Get outcome levels being modeled (non-reference)
  outcome_levels <- rownames(coef_matrix)
  reference_outcome <- setdiff(model$lev, outcome_levels)[1]

  # Expand mapping for each outcome level
  expanded_list <- list()

  for (out_level in outcome_levels) {
    level_mapping <- base_mapping
    level_mapping$outcome_level <- out_level
    level_mapping$reference_outcome <- reference_outcome
    expanded_list[[length(expanded_list) + 1]] <- level_mapping
  }

  expanded_mapping <- do.call(rbind, expanded_list)
  rownames(expanded_mapping) <- NULL

  expanded_mapping
}


#' Get Odds Ratios Using Mapping
#'
#' Extracts odds ratios using proper term-level mapping instead of string parsing.
#'
#' @param model_result Model result from run_catdriver_model()
#' @param mapping Term-level mapping from map_terms_to_levels()
#' @param config Configuration list
#' @param conf_level Confidence level for CIs
#' @return Data frame with properly mapped odds ratios
#' @export
extract_odds_ratios_mapped <- function(model_result, mapping, config, conf_level = 0.95) {

  coef_df <- model_result$coefficients

  # Join coefficients to mapping
  if (model_result$model_type == "multinomial_logistic") {
    # Multinomial: match by outcome_level and term
    or_list <- list()

    for (i in seq_len(nrow(coef_df))) {
      row <- coef_df[i, ]
      term <- row$term
      out_level <- row$outcome_level

      # Find matching mapping entry
      match_idx <- which(
        mapping$coef_name == term &
        mapping$outcome_level == out_level
      )

      if (length(match_idx) > 0) {
        m <- mapping[match_idx[1], ]

        or_list[[length(or_list) + 1]] <- data.frame(
          term = row$term,  # Raw coefficient name for bootstrap matching
          factor = m$driver,
          factor_label = get_var_label(config, m$driver),
          comparison = m$level,
          reference = m$reference_level,
          outcome_level = out_level,
          reference_outcome = m$reference_outcome,
          odds_ratio = row$odds_ratio,
          or_lower = row$or_lower,
          or_upper = row$or_upper,
          p_value = row$p_value,
          stringsAsFactors = FALSE
        )
      }
    }

  } else {
    # Binary/Ordinal: match by term only
    or_list <- list()

    for (i in seq_len(nrow(coef_df))) {
      row <- coef_df[i, ]
      term <- row$term

      # Skip intercept
      if (grepl("^\\(Intercept\\)", term)) next

      # Find matching mapping entry
      match_idx <- which(mapping$coef_name == term & !mapping$is_reference)

      if (length(match_idx) > 0) {
        m <- mapping[match_idx[1], ]

        or_list[[length(or_list) + 1]] <- data.frame(
          term = term,  # Raw coefficient name for bootstrap matching
          factor = m$driver,
          factor_label = get_var_label(config, m$driver),
          comparison = m$level,
          reference = m$reference_level,
          odds_ratio = row$odds_ratio,
          or_lower = row$or_lower,
          or_upper = row$or_upper,
          p_value = row$p_value,
          stringsAsFactors = FALSE
        )
      } else {
        # Continuous variable - use term as is
        or_list[[length(or_list) + 1]] <- data.frame(
          term = term,  # Raw coefficient name for bootstrap matching
          factor = term,
          factor_label = get_var_label(config, term),
          comparison = "per unit",
          reference = NA,
          odds_ratio = row$odds_ratio,
          or_lower = row$or_lower,
          or_upper = row$or_upper,
          p_value = row$p_value,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(or_list) == 0) {
    return(data.frame())
  }

  or_df <- do.call(rbind, or_list)
  rownames(or_df) <- NULL

  # Add interpretation columns
  or_df$effect <- sapply(or_df$odds_ratio, interpret_or_effect)
  or_df$significance <- sapply(or_df$p_value, get_sig_stars)
  or_df$or_formatted <- format_or(or_df$odds_ratio)
  or_df$ci_formatted <- mapply(format_ci, or_df$or_lower, or_df$or_upper)
  or_df$p_formatted <- sapply(or_df$p_value, format_pvalue)

  or_df
}


#' Aggregate Term Importance to Variable Level
#'
#' Uses mapping to correctly aggregate dummy variable importance to factor level.
#'
#' @param term_importance Data frame with term-level chi-squares
#' @param mapping Term-level mapping
#' @return Data frame with variable-level importance
#' @keywords internal
aggregate_importance_mapped <- function(term_importance, mapping) {

  # Join terms to drivers
  term_importance$driver <- NA

  for (i in seq_len(nrow(term_importance))) {
    term <- term_importance$term[i]
    match_idx <- which(mapping$coef_name == term | mapping$design_col == term)

    if (length(match_idx) > 0) {
      term_importance$driver[i] <- mapping$driver[match_idx[1]]
    } else {
      term_importance$driver[i] <- term
    }
  }

  # Aggregate by driver
  agg <- aggregate(
    chi_square ~ driver,
    data = term_importance,
    FUN = sum,
    na.rm = TRUE
  )

  # Get minimum p-value
  pval_agg <- aggregate(
    p_value ~ driver,
    data = term_importance,
    FUN = min,
    na.rm = TRUE
  )

  agg$p_value <- pval_agg$p_value[match(agg$driver, pval_agg$driver)]

  names(agg)[1] <- "variable"

  agg
}


#' Validate Mapping Completeness
#'
#' Checks that all model terms can be mapped. This is a HARD GATE -
#' if any coefficients are unmapped, the analysis refuses to proceed.
#'
#' @param mapping Term-level mapping from map_terms_to_levels() or map_multinomial_terms()
#' @param model_coefs Model coefficient names (from names(coef(model)) or similar)
#' @return TRUE if valid, refuses with catdriver_refuse() otherwise
#' @export
validate_mapping <- function(mapping, model_coefs) {
  # Filter out terms that should not be mapped:
  # 1. Intercept terms
  # 2. Ordinal threshold parameters (e.g., "1|2", "2|3", "Low|Medium", etc.)
  #    These are from polr/clm models and represent cut points, not predictors

  model_coefs <- model_coefs[!grepl("^\\(Intercept\\)", model_coefs)]
  model_coefs <- model_coefs[!grepl("\\|", model_coefs)]  # Ordinal thresholds contain "|"

  if (nrow(mapping) == 0 && length(model_coefs) > 0) {
    catdriver_refuse(
      reason = "MAPPER_EMPTY_MAPPING",
      title = "TERM MAPPING FAILED",
      problem = "Term mapping is empty but the model has coefficients that need to be mapped.",
      why_it_matters = "Without proper mapping, CatDriver cannot determine which coefficients belong to which variables.",
      fix = "This may indicate a model structure issue. Check that your predictors are categorical factors.",
      details = paste0("Unmapped coefficients: ", paste(model_coefs, collapse = ", "))
    )
  }

  # Check all non-reference mapped
  mapped_terms <- mapping$coef_name[!mapping$is_reference]
  mapped_terms <- mapped_terms[!is.na(mapped_terms)]

  unmapped <- setdiff(model_coefs, mapped_terms)

  if (length(unmapped) > 0) {
    catdriver_refuse(
      reason = "MAPPER_UNMAPPED_COEFFICIENTS",
      title = "UNMAPPED MODEL COEFFICIENTS",
      problem = "Some model coefficients could not be mapped back to predictors/levels.",
      why_it_matters = "This would make the odds ratio tables incomplete or incorrectly labeled.",
      fix = "Investigate coefficient naming and ensure all categorical predictors are factors with stable level names.",
      details = paste0("Unmapped coefficients: ", paste(unmapped, collapse = ", "))
    )
  }

  invisible(TRUE)
}
