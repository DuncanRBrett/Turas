# ==============================================================================
# CATEGORICAL KEY DRIVER - PREPROCESSING
# ==============================================================================
#
# Variable type detection, outcome type detection, and data transformation
# for categorical logistic regression analysis.
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================

#' Detect Outcome Type
#'
#' Determines whether outcome should be treated as binary, ordinal, or nominal.
#'
#' @param outcome_var Outcome variable vector
#' @param order_spec Optional order specification from config
#' @param override_type Optional override ("binary", "ordinal", "nominal")
#' @return List with type and method information
#' @export
detect_outcome_type <- function(outcome_var, order_spec = NULL, override_type = "auto") {

  # Remove missing values for analysis
  outcome_clean <- na.omit(outcome_var)
  categories <- unique(outcome_clean)
  n_unique <- length(categories)

  # Validate minimum categories

  if (n_unique < 2) {
    catdriver_refuse(
      reason = "CFG_OUTCOME_INSUFFICIENT_CATEGORIES",
      title = "INSUFFICIENT OUTCOME CATEGORIES",
      problem = paste0("Outcome variable has only ", n_unique, " unique value(s)."),
      why_it_matters = "Logistic regression requires at least 2 distinct outcome categories.",
      fix = "Check that your outcome variable has at least 2 different values in the data."
    )
  }

  # Handle override
  if (!is.null(override_type) && override_type != "auto") {
    type <- tolower(override_type)

    if (type == "binary" && n_unique != 2) {
      warning("Binary type specified but outcome has ", n_unique, " categories. ",
              "Using multinomial instead.")
      type <- "nominal"
    }

    return(list(
      type = type,
      method = switch(type,
        binary = "binomial_logistic",
        ordinal = "proportional_odds",
        nominal = "multinomial_logistic"
      ),
      n_categories = n_unique,
      categories = sort(as.character(categories)),
      is_ordered = type == "ordinal"
    ))
  }

  # Auto-detection logic

  # Case 1: Binary outcome
  if (n_unique == 2) {
    return(list(
      type = "binary",
      method = "binomial_logistic",
      n_categories = 2,
      categories = sort(as.character(categories)),
      is_ordered = FALSE
    ))
  }

  # Case 2: User specified order -> ordinal
  if (!is.null(order_spec) && length(order_spec) >= 2) {
    return(list(
      type = "ordinal",
      method = "proportional_odds",
      n_categories = n_unique,
      categories = order_spec,
      is_ordered = TRUE
    ))
  }

  # Case 3: Already an ordered factor
  if (is.ordered(outcome_var)) {
    return(list(
      type = "ordinal",
      method = "proportional_odds",
      n_categories = n_unique,
      categories = levels(outcome_var),
      is_ordered = TRUE
    ))
  }

  # Case 4: Numeric with natural ordering
  if (is.numeric(outcome_var)) {
    sorted_cats <- sort(unique(outcome_clean))
    return(list(
      type = "ordinal",
      method = "proportional_odds",
      n_categories = n_unique,
      categories = as.character(sorted_cats),
      is_ordered = TRUE,
      note = "Numeric outcome treated as ordinal. Specify order in config or set outcome_type='nominal' to override."
    ))
  }

  # Default: nominal (unordered multi-category)
  list(
    type = "nominal",
    method = "multinomial_logistic",
    n_categories = n_unique,
    categories = sort(as.character(categories)),
    is_ordered = FALSE
  )
}


#' Detect Predictor Type
#'
#' Determines how a predictor variable should be treated in the model.
#'
#' @param predictor_var Predictor variable vector
#' @param order_spec Optional order specification from config
#' @return List with type and coding information
#' @keywords internal
detect_predictor_type <- function(predictor_var, order_spec = NULL) {

  predictor_clean <- na.omit(predictor_var)
  n_unique <- length(unique(predictor_clean))

  # Continuous numeric (> 10 unique values)
  if (is.numeric(predictor_var) && n_unique > 10) {
    return(list(
      type = "continuous",
      needs_dummy = FALSE,
      n_dummies = 0
    ))
  }

  # Binary categorical
  if (n_unique == 2) {
    return(list(
      type = "binary_categorical",
      needs_dummy = TRUE,
      n_dummies = 1
    ))
  }

  # Multi-category (3-20)
  if (n_unique >= 3 && n_unique <= 20) {
    is_ordered <- !is.null(order_spec) && length(order_spec) > 0

    return(list(
      type = if (is_ordered) "ordinal" else "nominal",
      needs_dummy = TRUE,
      n_dummies = n_unique - 1
    ))
  }

  # High cardinality (> 20)
  if (n_unique > 20) {
    warning("Predictor has ", n_unique, " categories. Consider grouping.")
    return(list(
      type = "high_cardinality",
      needs_dummy = TRUE,
      n_dummies = n_unique - 1
    ))
  }

  # Single value (constant)
  list(
    type = "constant",
    needs_dummy = FALSE,
    n_dummies = 0
  )
}


#' Prepare Outcome Variable
#'
#' Converts outcome variable to appropriate format for modeling.
#' REFUSES with hard error if outcome type doesn't match data.
#'
#' @param data Data frame
#' @param config Configuration list
#' @param outcome_info Outcome type detection results
#' @return Modified data frame with prepared outcome
#' @export
prepare_outcome <- function(data, config, outcome_info) {

  outcome_var <- config$outcome_var
  outcome_data <- data[[outcome_var]]

  # Get reference category
  ref_cat <- config$reference_category

  # Get data categories
  data_cats <- unique(as.character(na.omit(outcome_data)))
  n_data_cats <- length(data_cats)

  # ===========================================================================
  # HARD VALIDATION: Refuse if outcome_type doesn't match data
  # ===========================================================================

  if (outcome_info$type == "binary") {
    if (n_data_cats != 2) {
      catdriver_refuse(
        reason = "CFG_OUTCOME_TYPE_MISMATCH",
        title = "OUTCOME TYPE MISMATCH",
        problem = paste0("outcome_type='binary' specified but data has ", n_data_cats, " categories."),
        why_it_matters = "Binary logistic regression requires exactly 2 outcome categories.",
        fix = paste0("Either:\n",
                     "  1. Set outcome_type='ordinal' or 'multinomial' in Settings, OR\n",
                     "  2. Verify your data has exactly 2 outcome categories"),
        details = paste0("Found categories: ", paste(data_cats, collapse = ", "))
      )
    }
  }

  if (outcome_info$type == "ordinal" && !is.null(config$outcome_order)) {
    # Check that all config categories exist in data
    config_cats <- config$outcome_order
    missing_in_data <- setdiff(config_cats, data_cats)
    extra_in_data <- setdiff(data_cats, config_cats)

    if (length(missing_in_data) > 0) {
      catdriver_refuse(
        reason = "CFG_OUTCOME_CATEGORY_MISMATCH",
        title = "OUTCOME CATEGORY MISMATCH",
        problem = "Configured outcome categories not found in data.",
        why_it_matters = "All specified outcome categories must exist in the data.",
        fix = "Update outcome Order in Variables sheet to match data categories.",
        details = paste0("Missing categories: ", paste(missing_in_data, collapse = ", "), "\n",
                         "Data categories: ", paste(data_cats, collapse = ", "))
      )
    }

    if (length(extra_in_data) > 0) {
      catdriver_refuse(
        reason = "CFG_OUTCOME_CATEGORY_MISMATCH",
        title = "OUTCOME CATEGORY MISMATCH",
        problem = "Data contains outcome categories not in config.",
        why_it_matters = "All data categories must be accounted for in the config.",
        fix = paste0("Either:\n",
                     "  1. Update outcome Order in Variables to include all data categories, OR\n",
                     "  2. Clean data to only include expected categories"),
        details = paste0("Extra categories: ", paste(extra_in_data, collapse = ", "), "\n",
                         "Configured: ", paste(config_cats, collapse = ", "))
      )
    }
  }

  # ===========================================================================
  # PROCEED WITH OUTCOME PREPARATION
  # ===========================================================================

  if (outcome_info$type == "binary") {
    # Convert to factor
    if (!is.factor(outcome_data)) {
      outcome_data <- factor(outcome_data)
    }

    # Set reference level if specified
    if (!is.null(ref_cat) && ref_cat %in% levels(outcome_data)) {
      outcome_data <- relevel(outcome_data, ref = ref_cat)
    }

    data[[outcome_var]] <- outcome_data

  } else if (outcome_info$type == "ordinal") {
    # Convert to ordered factor with specified order
    if (!is.null(outcome_info$categories)) {
      outcome_data <- factor(outcome_data, levels = outcome_info$categories, ordered = TRUE)
    } else {
      outcome_data <- factor(outcome_data, ordered = TRUE)
    }

    data[[outcome_var]] <- outcome_data

  } else {
    # Nominal/Multinomial: unordered factor
    if (!is.factor(outcome_data)) {
      outcome_data <- factor(outcome_data)
    }

    # Set reference level if specified
    if (!is.null(ref_cat) && ref_cat %in% levels(outcome_data)) {
      outcome_data <- relevel(outcome_data, ref = ref_cat)
    } else {
      # Use first alphabetically as reference
      outcome_data <- relevel(outcome_data, ref = sort(levels(outcome_data))[1])
    }

    data[[outcome_var]] <- outcome_data
  }

  data
}


#' Prepare Predictor Variables
#'
#' Converts predictor variables to appropriate format for modeling.
#' Uses DRIVER_SETTINGS from config for explicit type and reference level.
#' Falls back to inference ONLY when no Driver_Settings sheet exists.
#'
#' @param data Data frame
#' @param config Configuration list
#' @return List with prepared data and predictor info
#' @export
prepare_predictors <- function(data, config) {

  predictor_info <- list()

  # Check if we have explicit Driver_Settings
  has_driver_settings <- !is.null(config$driver_settings) &&
                         is.data.frame(config$driver_settings) &&
                         nrow(config$driver_settings) > 0

  for (var_name in config$driver_vars) {
    var_data <- data[[var_name]]

    # =========================================================================
    # GET TYPE AND SETTINGS FROM DRIVER_SETTINGS (explicit) OR INFER (fallback)
    # =========================================================================

    if (has_driver_settings) {
      # Use explicit settings from Driver_Settings sheet
      explicit_type <- get_driver_setting(config, var_name, "type", NULL)
      explicit_ref <- get_driver_setting(config, var_name, "reference_level", NULL)
      explicit_order <- get_driver_setting(config, var_name, "levels_order", NULL)

      # Parse levels_order if provided (semicolon-separated)
      order_spec <- if (!is.null(explicit_order) && !is.na(explicit_order) && nzchar(explicit_order)) {
        trimws(strsplit(explicit_order, ";")[[1]])
      } else {
        config$driver_orders[[var_name]]  # Fall back to Variables sheet order
      }

      # TRS: Log the level specification source for traceability
      if (!is.null(order_spec) && length(order_spec) > 0) {
        order_source <- if (!is.null(explicit_order) && !is.na(explicit_order) && nzchar(explicit_order)) {
          "Driver_Settings.levels_order"
        } else {
          "Variables.Order"
        }
        log_message(paste0("Driver '", var_name, "' levels from ", order_source, ": ",
                          paste(order_spec, collapse = ";")), "info")
      }

      # Map explicit type to internal representation
      if (!is.null(explicit_type) && !is.na(explicit_type) && nzchar(explicit_type)) {
        pred_type <- switch(tolower(explicit_type),
          "categorical" = list(type = "nominal", needs_dummy = TRUE, n_dummies = NA),
          "nominal" = list(type = "nominal", needs_dummy = TRUE, n_dummies = NA),
          "ordinal" = list(type = "ordinal", needs_dummy = TRUE, n_dummies = NA),
          "binary" = list(type = "binary_categorical", needs_dummy = TRUE, n_dummies = 1),
          "control_only" = list(type = "control", needs_dummy = TRUE, n_dummies = NA),
          # Unknown type - refuse (guards should have caught this)
          {
            catdriver_refuse(
              reason = "CFG_DRIVER_TYPE_UNKNOWN",
              title = "UNKNOWN DRIVER TYPE",
              problem = paste0("Driver '", var_name, "' has unknown type '", explicit_type, "'."),
              why_it_matters = "Cannot determine how to treat this predictor.",
              fix = "Set type to: categorical, ordinal, binary, or control_only"
            )
          }
        )
      } else {
        # No type specified - refuse (guards should have caught this)
        catdriver_refuse(
          reason = "CFG_DRIVER_TYPE_MISSING",
          title = "DRIVER TYPE MISSING",
          problem = paste0("Driver '", var_name, "' has no type in Driver_Settings."),
          why_it_matters = "All drivers must have explicit type declarations.",
          fix = paste0("Add 'type' column entry for '", var_name, "' in Driver_Settings sheet.")
        )
      }

    } else {
      # No Driver_Settings sheet - use inference (legacy mode)
      order_spec <- config$driver_orders[[var_name]]
      pred_type <- detect_predictor_type(var_data, order_spec)
      explicit_ref <- NULL

      # TRS: Log the level specification source for traceability (legacy mode)
      if (!is.null(order_spec) && length(order_spec) > 0) {
        log_message(paste0("Driver '", var_name, "' levels from Variables.Order: ",
                          paste(order_spec, collapse = ";")), "info")
      }
    }

    # =========================================================================
    # PREPARE VARIABLE BASED ON TYPE
    # =========================================================================

    if (pred_type$type == "control") {
      # Control variable - convert to factor but mark for exclusion from driver reports
      if (!is.factor(var_data)) {
        var_data <- factor(var_data)
      }
      # Set reference level if specified
      if (!is.null(explicit_ref) && !is.na(explicit_ref) && nzchar(explicit_ref)) {
        if (explicit_ref %in% levels(var_data)) {
          var_data <- relevel(var_data, ref = explicit_ref)
        }
      }
      pred_type$exclude_from_driver_report <- TRUE

    } else if (pred_type$type %in% c("binary_categorical", "nominal", "high_cardinality")) {
      # Convert to factor
      if (!is.factor(var_data)) {
        var_data <- factor(var_data)
      }

      # =======================================================================
      # HARD VALIDATION: If order_spec provided, check levels match data
      # =======================================================================
      if (!is.null(order_spec) && length(order_spec) > 0) {
        data_levels <- levels(var_data)

        # TRS: Log validation comparison
        log_message(paste0("Validating '", var_name, "' - Config levels: [",
                          paste(order_spec, collapse = ";"), "] vs Data levels: [",
                          paste(data_levels, collapse = ";"), "]"), "info")

        missing_in_data <- setdiff(order_spec, data_levels)
        extra_in_data <- setdiff(data_levels, order_spec)

        if (length(missing_in_data) > 0 || length(extra_in_data) > 0) {
          catdriver_refuse(
            reason = "MAPPER_DRIVER_LEVEL_MISMATCH",
            title = "DRIVER LEVEL MISMATCH",
            problem = paste0("Driver '", var_name, "' level specification doesn't match data."),
            why_it_matters = paste0(
              "The levels in your config must exactly match the values in your data. ",
              "Mismatched levels would cause incorrect OR interpretations or silent data loss."
            ),
            fix = c(
              "Update the Order column or levels_order in Driver_Settings to match your data values.",
              if (length(missing_in_data) > 0)
                paste0("Config levels not in data: ", paste(missing_in_data, collapse = ", ")),
              if (length(extra_in_data) > 0)
                paste0("Data values not in config: ", paste(extra_in_data, collapse = ", "))
            ),
            details = paste0(
              "Config levels: ", paste(order_spec, collapse = ";"), "\n",
              "Data levels: ", paste(data_levels, collapse = ";")
            )
          )
        }
      }

      # Set reference level - PREFER explicit from Driver_Settings
      if (!is.null(explicit_ref) && !is.na(explicit_ref) && nzchar(explicit_ref)) {
        if (explicit_ref %in% levels(var_data)) {
          var_data <- relevel(var_data, ref = explicit_ref)
        } else {
          # REFUSE instead of warning - explicit ref level must exist
          catdriver_refuse(
            reason = "MAPPER_REFERENCE_LEVEL_NOT_FOUND",
            title = "REFERENCE LEVEL NOT FOUND",
            problem = paste0("Driver '", var_name, "' reference level '", explicit_ref,
                           "' not found in data."),
            why_it_matters = "The reference level must exist in the data to properly set contrasts.",
            fix = c(
              "Check that the reference_level in Driver_Settings matches a value in your data.",
              paste0("Available levels: ", paste(levels(var_data), collapse = ", "))
            )
          )
        }
      } else if (!is.null(order_spec) && length(order_spec) > 0) {
        # First in order spec is reference
        ref_level <- order_spec[1]
        if (ref_level %in% levels(var_data)) {
          var_data <- relevel(var_data, ref = ref_level)
        }
      } else {
        # First alphabetically is reference
        var_data <- relevel(var_data, ref = sort(levels(var_data))[1])
      }

    } else if (pred_type$type == "ordinal") {
      # Ordinal predictor - use UNORDERED factor with levels in semantic order
      # CRITICAL: Do NOT use ordered=TRUE for predictors passed to ordinal::clm
      # because clm handles ordered factors differently, causing sign inversions.
      # Instead, create unordered factor with levels in the correct order.
      if (!is.null(order_spec) && length(order_spec) > 0) {
        # =======================================================================
        # HARD VALIDATION: Refuse if config levels don't match data levels
        # =======================================================================
        data_levels <- unique(as.character(na.omit(var_data)))

        # TRS: Log validation comparison
        log_message(paste0("Validating ordinal '", var_name, "' - Config levels: [",
                          paste(order_spec, collapse = ";"), "] vs Data levels: [",
                          paste(data_levels, collapse = ";"), "]"), "info")

        missing_in_data <- setdiff(order_spec, data_levels)
        extra_in_data <- setdiff(data_levels, order_spec)

        if (length(missing_in_data) > 0 || length(extra_in_data) > 0) {
          catdriver_refuse(
            reason = "MAPPER_DRIVER_LEVEL_MISMATCH",
            title = "DRIVER LEVEL MISMATCH",
            problem = paste0("Driver '", var_name, "' level specification doesn't match data."),
            why_it_matters = paste0(
              "The levels in your config must exactly match the values in your data. ",
              "Mismatched levels would cause incorrect OR interpretations or silent data loss."
            ),
            fix = c(
              "Update the Order column or levels_order in Driver_Settings to match your data values.",
              if (length(missing_in_data) > 0)
                paste0("Config levels not in data: ", paste(missing_in_data, collapse = ", ")),
              if (length(extra_in_data) > 0)
                paste0("Data values not in config: ", paste(extra_in_data, collapse = ", "))
            ),
            details = paste0(
              "Config levels: ", paste(order_spec, collapse = ";"), "\n",
              "Data levels: ", paste(data_levels, collapse = ";")
            )
          )
        }

        # CRITICAL FIX: Use ordered = FALSE for ordinal PREDICTORS
        # =========================================================
        # ordinal::clm internally handles ordered factors differently than
        # regular factors, which can cause coefficient sign inversions even
        # when treatment contrasts are explicitly set. By creating an unordered
        # factor with levels in the specified order, we get:
        # 1. Levels remain in correct semantic order (D < C < B < A)
        # 2. Treatment contrasts work as expected
        # 3. clm() treats it as a regular categorical predictor
        # 4. Coefficients have correct sign (OR > 1 when higher levels
        #    have higher outcome probability)
        var_data <- factor(var_data, levels = order_spec, ordered = FALSE)
      } else {
        var_data <- factor(var_data, ordered = FALSE)
      }

      # CRITICAL: Override default polynomial contrasts with treatment contrasts
      # Polynomial contrasts (.L, .Q, .C) are not mappable to levels and would
      # produce misleading Factor Patterns output. Treatment contrasts give us
      # level-based coefficients that match the expected OR interpretation.
      #
      # IMPORTANT: Set dimnames so columns are named with level labels (e.g., "C", "B", "A")
      # not numeric indices (e.g., "2", "3", "4"). Without this, model.matrix() creates
      # columns like "grade2" instead of "gradeC", breaking term-to-level mapping.

      # Validate sufficient levels for contrast matrix
      n_levels <- nlevels(var_data)
      if (n_levels < 2) {
        catdriver_refuse(
          reason = "CFG_ORDINAL_INSUFFICIENT_LEVELS",
          title = "INSUFFICIENT ORDINAL LEVELS",
          problem = paste0("Ordinal variable '", var_name, "' has only ", n_levels, " level(s)."),
          why_it_matters = "Ordinal contrasts require at least 2 levels to create meaningful comparisons.",
          fix = "Check that your data has multiple levels for this variable, or change type to 'continuous'."
        )
      }

      cm <- contr.treatment(n_levels)
      rownames(cm) <- levels(var_data)
      colnames(cm) <- levels(var_data)[-1]  # non-reference levels
      contrasts(var_data) <- cm
    }

    # Update data
    data[[var_name]] <- var_data

    # Update n_dummies now that we know actual levels
    if (is.factor(var_data)) {
      pred_type$n_dummies <- length(levels(var_data)) - 1
    }

    # Store info
    pred_type$reference_level <- if (is.factor(var_data)) levels(var_data)[1] else NA
    pred_type$levels <- if (is.factor(var_data)) levels(var_data) else unique(na.omit(var_data))
    pred_type$source <- if (has_driver_settings) "driver_settings" else "inference"
    predictor_info[[var_name]] <- pred_type
  }

  list(
    data = data,
    predictor_info = predictor_info
  )
}


#' Build Model Formula
#'
#' Constructs the formula for logistic regression.
#'
#' @param config Configuration list
#' @return Formula object
#' @keywords internal
build_model_formula <- function(config) {
  # Simple additive formula
  formula_str <- paste(config$outcome_var, "~",
                       paste(config$driver_vars, collapse = " + "))
  as.formula(formula_str)
}


#' Preprocess Data for Analysis
#'
#' Main preprocessing function that prepares all variables.
#'
#' @param data Raw data frame
#' @param config Configuration list
#' @return List with preprocessed data and metadata
#' @export
preprocess_catdriver_data <- function(data, config) {

  # Detect outcome type
  outcome_info <- detect_outcome_type(
    data[[config$outcome_var]],
    config$outcome_order,
    config$outcome_type
  )

  # Prepare outcome
  data <- prepare_outcome(data, config, outcome_info)

  # Prepare predictors
  prep_result <- prepare_predictors(data, config)
  data <- prep_result$data
  predictor_info <- prep_result$predictor_info

  # Build formula
  model_formula <- build_model_formula(config)

  # Calculate effective sample sizes by outcome category
  outcome_counts <- table(data[[config$outcome_var]])

  list(
    data = data,
    outcome_info = outcome_info,
    predictor_info = predictor_info,
    model_formula = model_formula,
    outcome_counts = outcome_counts,
    n_predictors = length(config$driver_vars),
    n_terms = sum(sapply(predictor_info, function(x) max(1, x$n_dummies)))
  )
}


#' Get Reference Category for Variable
#'
#' @param data Preprocessed data
#' @param var_name Variable name
#' @return Reference category name
#' @keywords internal
get_reference_category <- function(data, var_name) {
  var_data <- data[[var_name]]

  if (is.factor(var_data)) {
    return(levels(var_data)[1])
  }

  if (is.character(var_data)) {
    return(sort(unique(na.omit(var_data)))[1])
  }

  NA
}


#' Create Dummy Variable Mapping
#'
#' Creates a mapping from dummy variable names to original variable and category.
#'
#' @param data Preprocessed data
#' @param config Configuration list
#' @param predictor_info Predictor information list
#' @return Data frame mapping dummy names to original variables
#' @keywords internal
create_dummy_mapping <- function(data, config, predictor_info) {

  mappings <- list()

  for (var_name in config$driver_vars) {
    info <- predictor_info[[var_name]]

    if (info$needs_dummy && is.factor(data[[var_name]])) {
      levels_vec <- levels(data[[var_name]])
      ref_level <- levels_vec[1]

      for (level in levels_vec[-1]) {  # Skip reference
        dummy_name <- paste0(var_name, level)
        mappings[[length(mappings) + 1]] <- data.frame(
          dummy_name = dummy_name,
          original_var = var_name,
          category = level,
          reference = ref_level,
          label = get_var_label(config, var_name),
          stringsAsFactors = FALSE
        )
      }
    } else {
      # Continuous or single-level
      mappings[[length(mappings) + 1]] <- data.frame(
        dummy_name = var_name,
        original_var = var_name,
        category = NA,
        reference = NA,
        label = get_var_label(config, var_name),
        stringsAsFactors = FALSE
      )
    }
  }

  do.call(rbind, mappings)
}
