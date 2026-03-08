# ==============================================================================
# PREFLIGHT VALIDATORS - TURAS Confidence Module
# ==============================================================================
# Cross-referential validation between config, question definitions, and data
# Catches configuration mistakes before confidence interval analysis begins
#
# VERSION HISTORY:
# V1.0 - Initial creation (2026-03-08)
#       - 13 cross-referential checks
#       - Standalone orchestrator: validate_confidence_preflight()
#
# USAGE:
#   source("modules/confidence/lib/validation/preflight_validators.R")
#   error_log <- validate_confidence_preflight(config, data, questions_df, margins_df)
#
# FUNCTIONS EXPORTED:
# - check_question_columns_in_data()     - Question_ID values exist in data
# - check_statistic_type_validity()      - Statistic_Type is valid
# - check_method_selection()             - At least one CI method per question
# - check_proportion_categories()        - Proportion questions have Categories
# - check_nps_codes()                    - NPS questions have Promoter/Detractor
# - check_nps_code_overlap()             - Promoter/Detractor codes don't overlap
# - check_category_values_in_data()      - Category codes appear in data
# - check_prior_specs()                  - Bayesian prior parameters valid
# - check_weight_variable_in_data()      - Weight variable exists and is valid
# - check_population_margins_sum()       - Margins sum to ~1.0 per variable
# - check_population_margin_variables()  - Margin variables exist in data
# - check_confidence_level_valid()       - Confidence level is acceptable
# - check_bootstrap_iterations()         - Iterations in valid range
# - validate_confidence_preflight()      - Main orchestrator
# ==============================================================================


# ==============================================================================
# HELPER: Log preflight issue
# ==============================================================================

#' Log a preflight validation issue
#'
#' Appends a new row to the error log data frame with standardised columns.
#'
#' @param error_log Data frame, existing error log (or NULL to create new)
#' @param check_name Character, name of the check that detected the issue
#' @param issue_title Character, short title of the issue
#' @param detail Character, detailed description of the problem
#' @param context Character, additional context (e.g. question ID)
#' @param severity Character, one of "Error", "Warning", "Info"
#'
#' @return Updated error_log data frame
#' @keywords internal
log_preflight_issue <- function(error_log, check_name, issue_title, detail,
                                context = "", severity = "Error") {
  rbind(error_log, data.frame(
    Check = check_name,
    Issue = issue_title,
    Detail = detail,
    Context = context,
    Severity = severity,
    stringsAsFactors = FALSE
  ))
}


# ==============================================================================
# CHECK 1: Question columns exist in data
# ==============================================================================

#' Check Question_ID columns exist in data
#'
#' Verifies that every Question_ID listed in the Question_Analysis sheet
#' corresponds to an actual column in the survey data.
#'
#' @param questions_df Data frame from Question_Analysis sheet
#' @param data Data frame, the survey data
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_question_columns_in_data <- function(questions_df, data, error_log) {
  if (is.null(questions_df) || nrow(questions_df) == 0) return(error_log)

  question_ids <- questions_df$Question_ID
  question_ids <- question_ids[!is.na(question_ids) & trimws(question_ids) != ""]
  data_cols <- names(data)

  missing_cols <- setdiff(question_ids, data_cols)
  if (length(missing_cols) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Question Columns", "Question_ID Not Found in Data",
      sprintf("%d question(s) defined in Question_Analysis but not found as columns in data: %s",
              length(missing_cols),
              paste(missing_cols, collapse = ", ")),
      paste(missing_cols, collapse = ", "),
      "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 2: Statistic_Type validity
# ==============================================================================

#' Check Statistic_Type values are valid
#'
#' Verifies that every Statistic_Type in the Question_Analysis sheet is one
#' of the supported types: proportion, mean, or nps.
#'
#' @param questions_df Data frame from Question_Analysis sheet
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_statistic_type_validity <- function(questions_df, error_log) {
  if (is.null(questions_df) || nrow(questions_df) == 0) return(error_log)

  valid_types <- c("proportion", "mean", "nps")

  for (i in seq_len(nrow(questions_df))) {
    q_id <- questions_df$Question_ID[i]
    stat_type <- tolower(trimws(as.character(questions_df$Statistic_Type[i])))

    if (is.na(q_id) || trimws(q_id) == "") next

    if (is.na(stat_type) || stat_type == "") {
      error_log <- log_preflight_issue(
        error_log, "Statistic Type", "Missing Statistic_Type",
        sprintf("Question '%s' has no Statistic_Type specified. Must be one of: %s",
                q_id, paste(valid_types, collapse = ", ")),
        q_id,
        "Error"
      )
    } else if (!stat_type %in% valid_types) {
      error_log <- log_preflight_issue(
        error_log, "Statistic Type", "Invalid Statistic_Type",
        sprintf("Question '%s' has Statistic_Type='%s'. Must be one of: %s",
                q_id, stat_type, paste(valid_types, collapse = ", ")),
        q_id,
        "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 3: At least one CI method selected per question
# ==============================================================================

#' Check at least one CI method is selected per question
#'
#' Verifies that every question in Question_Analysis has at least one
#' Run_* method set to Y.
#'
#' @param questions_df Data frame from Question_Analysis sheet
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_method_selection <- function(questions_df, error_log) {
  if (is.null(questions_df) || nrow(questions_df) == 0) return(error_log)

  method_cols <- c("Run_MOE", "Run_Wilson", "Run_Bootstrap", "Run_Credible")
  available_methods <- intersect(method_cols, names(questions_df))

  if (length(available_methods) == 0) {
    error_log <- log_preflight_issue(
      error_log, "Method Selection", "No Method Columns Found",
      "Question_Analysis sheet is missing all Run_* columns (Run_MOE, Run_Wilson, Run_Bootstrap, Run_Credible).",
      "",
      "Error"
    )
    return(error_log)
  }

  for (i in seq_len(nrow(questions_df))) {
    q_id <- questions_df$Question_ID[i]
    if (is.na(q_id) || trimws(q_id) == "") next

    any_selected <- FALSE
    for (method in available_methods) {
      val <- toupper(trimws(as.character(questions_df[[method]][i])))
      if (!is.na(val) && val == "Y") {
        any_selected <- TRUE
        break
      }
    }

    if (!any_selected) {
      error_log <- log_preflight_issue(
        error_log, "Method Selection", "No CI Method Selected",
        sprintf("Question '%s' has no CI method enabled. At least one of %s must be set to Y.",
                q_id, paste(available_methods, collapse = ", ")),
        q_id,
        "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 4: Proportion questions have Categories
# ==============================================================================

#' Check proportion questions have Categories specified
#'
#' For questions with Statistic_Type = 'proportion', verifies that the
#' Categories field is not empty.
#'
#' @param questions_df Data frame from Question_Analysis sheet
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_proportion_categories <- function(questions_df, error_log) {
  if (is.null(questions_df) || nrow(questions_df) == 0) return(error_log)
  if (!"Categories" %in% names(questions_df)) return(error_log)

  for (i in seq_len(nrow(questions_df))) {
    q_id <- questions_df$Question_ID[i]
    stat_type <- tolower(trimws(as.character(questions_df$Statistic_Type[i])))

    if (is.na(q_id) || trimws(q_id) == "") next
    if (is.na(stat_type) || stat_type != "proportion") next

    categories <- as.character(questions_df$Categories[i])
    if (is.na(categories) || trimws(categories) == "") {
      error_log <- log_preflight_issue(
        error_log, "Proportion Categories", "Missing Categories",
        sprintf("Question '%s' has Statistic_Type='proportion' but no Categories specified. Provide comma-separated category codes (e.g. '1,2').",
                q_id),
        q_id,
        "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 5: NPS questions have Promoter and Detractor codes
# ==============================================================================

#' Check NPS questions have both Promoter_Codes and Detractor_Codes
#'
#' For questions with Statistic_Type = 'nps', verifies that both
#' Promoter_Codes and Detractor_Codes are specified.
#'
#' @param questions_df Data frame from Question_Analysis sheet
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_nps_codes <- function(questions_df, error_log) {
  if (is.null(questions_df) || nrow(questions_df) == 0) return(error_log)

  has_promoter_col <- "Promoter_Codes" %in% names(questions_df)
  has_detractor_col <- "Detractor_Codes" %in% names(questions_df)

  for (i in seq_len(nrow(questions_df))) {
    q_id <- questions_df$Question_ID[i]
    stat_type <- tolower(trimws(as.character(questions_df$Statistic_Type[i])))

    if (is.na(q_id) || trimws(q_id) == "") next
    if (is.na(stat_type) || stat_type != "nps") next

    # Check Promoter_Codes
    if (!has_promoter_col) {
      error_log <- log_preflight_issue(
        error_log, "NPS Codes", "Missing Promoter_Codes Column",
        sprintf("Question '%s' is NPS type but Question_Analysis sheet has no Promoter_Codes column.",
                q_id),
        q_id,
        "Error"
      )
    } else {
      promoter_val <- as.character(questions_df$Promoter_Codes[i])
      if (is.na(promoter_val) || trimws(promoter_val) == "") {
        error_log <- log_preflight_issue(
          error_log, "NPS Codes", "Missing Promoter_Codes",
          sprintf("Question '%s' is NPS type but Promoter_Codes is empty. Provide comma-separated codes (e.g. '9,10').",
                  q_id),
          q_id,
          "Error"
        )
      }
    }

    # Check Detractor_Codes
    if (!has_detractor_col) {
      error_log <- log_preflight_issue(
        error_log, "NPS Codes", "Missing Detractor_Codes Column",
        sprintf("Question '%s' is NPS type but Question_Analysis sheet has no Detractor_Codes column.",
                q_id),
        q_id,
        "Error"
      )
    } else {
      detractor_val <- as.character(questions_df$Detractor_Codes[i])
      if (is.na(detractor_val) || trimws(detractor_val) == "") {
        error_log <- log_preflight_issue(
          error_log, "NPS Codes", "Missing Detractor_Codes",
          sprintf("Question '%s' is NPS type but Detractor_Codes is empty. Provide comma-separated codes (e.g. '0,1,2,3,4,5,6').",
                  q_id),
          q_id,
          "Error"
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 6: NPS Promoter and Detractor codes don't overlap
# ==============================================================================

#' Check NPS Promoter and Detractor codes don't overlap
#'
#' For NPS questions, verifies that the same code does not appear in both
#' the Promoter_Codes and Detractor_Codes lists.
#'
#' @param questions_df Data frame from Question_Analysis sheet
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_nps_code_overlap <- function(questions_df, error_log) {
  if (is.null(questions_df) || nrow(questions_df) == 0) return(error_log)

  has_promoter_col <- "Promoter_Codes" %in% names(questions_df)
  has_detractor_col <- "Detractor_Codes" %in% names(questions_df)

  if (!has_promoter_col || !has_detractor_col) return(error_log)

  for (i in seq_len(nrow(questions_df))) {
    q_id <- questions_df$Question_ID[i]
    stat_type <- tolower(trimws(as.character(questions_df$Statistic_Type[i])))

    if (is.na(q_id) || trimws(q_id) == "") next
    if (is.na(stat_type) || stat_type != "nps") next

    promoter_val <- as.character(questions_df$Promoter_Codes[i])
    detractor_val <- as.character(questions_df$Detractor_Codes[i])

    if (is.na(promoter_val) || trimws(promoter_val) == "") next
    if (is.na(detractor_val) || trimws(detractor_val) == "") next

    promoter_codes <- trimws(unlist(strsplit(promoter_val, ",")))
    detractor_codes <- trimws(unlist(strsplit(detractor_val, ",")))

    overlap <- intersect(promoter_codes, detractor_codes)
    if (length(overlap) > 0) {
      error_log <- log_preflight_issue(
        error_log, "NPS Code Overlap", "Overlapping Promoter/Detractor Codes",
        sprintf("Question '%s': codes %s appear in both Promoter_Codes and Detractor_Codes. Each code must belong to exactly one group.",
                q_id, paste(overlap, collapse = ", ")),
        q_id,
        "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 7: Category/code values actually appear in data
# ==============================================================================

#' Check category values exist in data columns
#'
#' For proportion and NPS questions, verifies that the specified category
#' codes or promoter/detractor codes actually appear in the data column.
#'
#' @param questions_df Data frame from Question_Analysis sheet
#' @param data Data frame, the survey data
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_category_values_in_data <- function(questions_df, data, error_log) {
  if (is.null(questions_df) || nrow(questions_df) == 0) return(error_log)

  data_cols <- names(data)

  for (i in seq_len(nrow(questions_df))) {
    q_id <- questions_df$Question_ID[i]
    stat_type <- tolower(trimws(as.character(questions_df$Statistic_Type[i])))

    if (is.na(q_id) || trimws(q_id) == "") next
    if (!q_id %in% data_cols) next  # Column existence checked elsewhere

    data_values <- as.character(data[[q_id]])
    data_values <- unique(data_values[!is.na(data_values) & data_values != ""])

    if (length(data_values) == 0) next

    # Check proportion Categories
    if (!is.na(stat_type) && stat_type == "proportion" &&
        "Categories" %in% names(questions_df)) {
      cat_val <- as.character(questions_df$Categories[i])
      if (!is.na(cat_val) && trimws(cat_val) != "") {
        specified_codes <- trimws(unlist(strsplit(cat_val, ",")))
        missing_codes <- setdiff(specified_codes, data_values)
        if (length(missing_codes) > 0) {
          error_log <- log_preflight_issue(
            error_log, "Category Values", "Category Codes Not in Data",
            sprintf("Question '%s': category code(s) %s specified but not found in data column. Data contains: %s",
                    q_id, paste(missing_codes, collapse = ", "),
                    paste(utils::head(data_values, 10), collapse = ", ")),
            q_id,
            "Warning"
          )
        }
      }
    }

    # Check NPS Promoter_Codes
    if (!is.na(stat_type) && stat_type == "nps" &&
        "Promoter_Codes" %in% names(questions_df)) {
      promo_val <- as.character(questions_df$Promoter_Codes[i])
      if (!is.na(promo_val) && trimws(promo_val) != "") {
        promo_codes <- trimws(unlist(strsplit(promo_val, ",")))
        missing_promo <- setdiff(promo_codes, data_values)
        if (length(missing_promo) > 0) {
          error_log <- log_preflight_issue(
            error_log, "Category Values", "Promoter Codes Not in Data",
            sprintf("Question '%s': promoter code(s) %s not found in data column.",
                    q_id, paste(missing_promo, collapse = ", ")),
            q_id,
            "Warning"
          )
        }
      }
    }

    # Check NPS Detractor_Codes
    if (!is.na(stat_type) && stat_type == "nps" &&
        "Detractor_Codes" %in% names(questions_df)) {
      det_val <- as.character(questions_df$Detractor_Codes[i])
      if (!is.na(det_val) && trimws(det_val) != "") {
        det_codes <- trimws(unlist(strsplit(det_val, ",")))
        missing_det <- setdiff(det_codes, data_values)
        if (length(missing_det) > 0) {
          error_log <- log_preflight_issue(
            error_log, "Category Values", "Detractor Codes Not in Data",
            sprintf("Question '%s': detractor code(s) %s not found in data column.",
                    q_id, paste(missing_det, collapse = ", ")),
            q_id,
            "Warning"
          )
        }
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 8: Bayesian prior specifications are valid
# ==============================================================================

#' Check prior specifications are valid
#'
#' For questions with Run_Credible=Y or with prior parameters specified,
#' validates that Prior_Mean is in the correct range for the statistic type,
#' Prior_SD is positive, and Prior_N is positive.
#'
#' @param questions_df Data frame from Question_Analysis sheet
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_prior_specs <- function(questions_df, error_log) {
  if (is.null(questions_df) || nrow(questions_df) == 0) return(error_log)

  has_prior_mean <- "Prior_Mean" %in% names(questions_df)
  has_prior_sd <- "Prior_SD" %in% names(questions_df)
  has_prior_n <- "Prior_N" %in% names(questions_df)

  for (i in seq_len(nrow(questions_df))) {
    q_id <- questions_df$Question_ID[i]
    stat_type <- tolower(trimws(as.character(questions_df$Statistic_Type[i])))

    if (is.na(q_id) || trimws(q_id) == "") next

    # Parse prior values
    prior_mean_raw <- if (has_prior_mean) suppressWarnings(as.numeric(questions_df$Prior_Mean[i])) else NA
    prior_sd_raw <- if (has_prior_sd) suppressWarnings(as.numeric(questions_df$Prior_SD[i])) else NA
    prior_n_raw <- if (has_prior_n) suppressWarnings(as.numeric(questions_df$Prior_N[i])) else NA

    has_any_prior <- !is.na(prior_mean_raw) || !is.na(prior_sd_raw) || !is.na(prior_n_raw)
    if (!has_any_prior) next

    # Validate Prior_Mean range based on statistic type
    if (!is.na(prior_mean_raw) && !is.na(stat_type)) {
      if (stat_type == "proportion") {
        if (prior_mean_raw < 0 || prior_mean_raw > 1) {
          error_log <- log_preflight_issue(
            error_log, "Prior Specs", "Prior_Mean Out of Range",
            sprintf("Question '%s': Prior_Mean=%.4f is outside valid range [0, 1] for proportion statistics.",
                    q_id, prior_mean_raw),
            q_id,
            "Error"
          )
        }
      } else if (stat_type == "nps") {
        if (prior_mean_raw < -100 || prior_mean_raw > 100) {
          error_log <- log_preflight_issue(
            error_log, "Prior Specs", "Prior_Mean Out of Range",
            sprintf("Question '%s': Prior_Mean=%.4f is outside valid range [-100, 100] for NPS statistics.",
                    q_id, prior_mean_raw),
            q_id,
            "Error"
          )
        }
      }
      # For mean type, any value is acceptable (no range restriction)
    }

    # Validate Prior_SD > 0
    if (!is.na(prior_sd_raw)) {
      if (prior_sd_raw <= 0) {
        error_log <- log_preflight_issue(
          error_log, "Prior Specs", "Prior_SD Not Positive",
          sprintf("Question '%s': Prior_SD=%.4f must be greater than 0.",
                  q_id, prior_sd_raw),
          q_id,
          "Error"
        )
      }
    }

    # Validate Prior_N > 0
    if (!is.na(prior_n_raw)) {
      if (prior_n_raw <= 0) {
        error_log <- log_preflight_issue(
          error_log, "Prior Specs", "Prior_N Not Positive",
          sprintf("Question '%s': Prior_N=%.4f must be greater than 0.",
                  q_id, prior_n_raw),
          q_id,
          "Error"
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 9: Weight variable exists, is numeric, non-negative, no NAs
# ==============================================================================

#' Check weight variable in data
#'
#' If a weight variable is configured, verifies it exists in the data,
#' is numeric, contains no negative values, and has no NAs.
#'
#' @param config List, configuration object (must contain $Weight_Variable)
#' @param data Data frame, the survey data
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_weight_variable_in_data <- function(config, data, error_log) {
  weight_var <- config$Weight_Variable
  if (is.null(weight_var) || is.na(weight_var) || trimws(weight_var) == "") {
    return(error_log)
  }

  weight_var <- trimws(weight_var)

  # Check existence
  if (!weight_var %in% names(data)) {
    error_log <- log_preflight_issue(
      error_log, "Weight Variable", "Weight Column Not Found",
      sprintf("Weight_Variable '%s' not found in data columns. Available columns: %s",
              weight_var, paste(utils::head(names(data), 20), collapse = ", ")),
      weight_var,
      "Error"
    )
    return(error_log)
  }

  weights <- data[[weight_var]]

  # Check numeric
  numeric_weights <- suppressWarnings(as.numeric(weights))
  n_non_numeric <- sum(is.na(numeric_weights) & !is.na(weights))
  if (n_non_numeric > 0) {
    error_log <- log_preflight_issue(
      error_log, "Weight Variable", "Non-Numeric Weights",
      sprintf("Weight_Variable '%s' contains %d non-numeric value(s). Weights must be numeric.",
              weight_var, n_non_numeric),
      weight_var,
      "Error"
    )
    return(error_log)
  }

  # Check NAs
  n_na <- sum(is.na(weights))
  if (n_na > 0) {
    error_log <- log_preflight_issue(
      error_log, "Weight Variable", "NA Weights",
      sprintf("Weight_Variable '%s' contains %d NA value(s). Rows with NA weights will be excluded from analysis.",
              weight_var, n_na),
      weight_var,
      "Warning"
    )
  }

  # Check non-negative
  valid_weights <- numeric_weights[!is.na(numeric_weights)]
  if (length(valid_weights) > 0 && any(valid_weights < 0)) {
    n_negative <- sum(valid_weights < 0)
    error_log <- log_preflight_issue(
      error_log, "Weight Variable", "Negative Weights",
      sprintf("Weight_Variable '%s' contains %d negative value(s). Survey weights must be non-negative.",
              weight_var, n_negative),
      weight_var,
      "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 10: Population margins sum to ~1.0 per variable
# ==============================================================================

#' Check population margins sum to approximately 1.0 per variable
#'
#' For each unique Variable in the Population_Margins sheet, verifies that
#' the Target_Prop values sum to approximately 1.0 (tolerance +/- 0.02).
#'
#' @param margins_df Data frame from Population_Margins sheet
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_population_margins_sum <- function(margins_df, error_log) {
  if (is.null(margins_df) || nrow(margins_df) == 0) return(error_log)

  # Filter to included rows
  if ("Include" %in% names(margins_df)) {
    included <- margins_df[is.na(margins_df$Include) |
                           toupper(trimws(as.character(margins_df$Include))) != "N", ]
  } else {
    included <- margins_df
  }

  if (nrow(included) == 0) return(error_log)

  variables <- unique(included$Variable)
  variables <- variables[!is.na(variables) & trimws(variables) != ""]

  for (var in variables) {
    var_rows <- included[included$Variable == var, ]
    props <- suppressWarnings(as.numeric(var_rows$Target_Prop))
    props <- props[!is.na(props)]

    if (length(props) == 0) {
      error_log <- log_preflight_issue(
        error_log, "Margin Sums", "No Valid Target_Prop",
        sprintf("Variable '%s': no valid numeric Target_Prop values found.", var),
        var,
        "Error"
      )
      next
    }

    prop_sum <- sum(props)
    if (abs(prop_sum - 1.0) > 0.02) {
      error_log <- log_preflight_issue(
        error_log, "Margin Sums", "Target_Prop Does Not Sum to 1.0",
        sprintf("Variable '%s': Target_Prop values sum to %.4f (expected ~1.0, tolerance +/-0.02). Check that all categories are included.",
                var, prop_sum),
        var,
        "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 11: Margin Variable values exist in data columns
# ==============================================================================

#' Check margin variable names exist in data
#'
#' Verifies that every Variable listed in the Population_Margins sheet
#' corresponds to an actual column in the survey data.
#'
#' @param margins_df Data frame from Population_Margins sheet
#' @param data Data frame, the survey data
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_population_margin_variables <- function(margins_df, data, error_log) {
  if (is.null(margins_df) || nrow(margins_df) == 0) return(error_log)

  variables <- unique(margins_df$Variable)
  variables <- variables[!is.na(variables) & trimws(variables) != ""]

  data_cols <- names(data)

  missing_vars <- setdiff(variables, data_cols)
  if (length(missing_vars) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Margin Variables", "Margin Variable Not Found in Data",
      sprintf("%d population margin variable(s) not found in data columns: %s",
              length(missing_vars),
              paste(missing_vars, collapse = ", ")),
      paste(missing_vars, collapse = ", "),
      "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 12: Confidence level is valid
# ==============================================================================

#' Check confidence level is valid
#'
#' Verifies that the configured Confidence_Level is one of the accepted
#' values: 0.90, 0.95, or 0.99.
#'
#' @param config List, configuration object (must contain $Confidence_Level)
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_confidence_level_valid <- function(config, error_log) {
  conf_level <- config$Confidence_Level

  if (is.null(conf_level) || is.na(conf_level)) {
    error_log <- log_preflight_issue(
      error_log, "Confidence Level", "Missing Confidence_Level",
      "No Confidence_Level specified in config. Default is 0.95.",
      "",
      "Warning"
    )
    return(error_log)
  }

  conf_level_num <- suppressWarnings(as.numeric(conf_level))
  if (is.na(conf_level_num)) {
    error_log <- log_preflight_issue(
      error_log, "Confidence Level", "Non-Numeric Confidence_Level",
      sprintf("Confidence_Level='%s' is not numeric. Must be 0.90, 0.95, or 0.99.", conf_level),
      "",
      "Error"
    )
    return(error_log)
  }

  valid_levels <- c(0.90, 0.95, 0.99)
  if (!conf_level_num %in% valid_levels) {
    error_log <- log_preflight_issue(
      error_log, "Confidence Level", "Invalid Confidence_Level",
      sprintf("Confidence_Level=%.2f is not one of the accepted values: %s",
              conf_level_num, paste(valid_levels, collapse = ", ")),
      "",
      "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 13: Bootstrap iterations in valid range
# ==============================================================================

#' Check bootstrap iterations are in valid range
#'
#' If Bootstrap_Iterations is specified, verifies the value is between
#' 1000 and 10000 (inclusive).
#'
#' @param config List, configuration object (must contain $Bootstrap_Iterations)
#' @param error_log Data frame, error log
#'
#' @return Updated error_log
#' @keywords internal
check_bootstrap_iterations <- function(config, error_log) {
  boot_iter <- config$Bootstrap_Iterations

  if (is.null(boot_iter) || is.na(boot_iter)) {
    return(error_log)
  }

  boot_iter_num <- suppressWarnings(as.numeric(boot_iter))
  if (is.na(boot_iter_num)) {
    error_log <- log_preflight_issue(
      error_log, "Bootstrap Iterations", "Non-Numeric Bootstrap_Iterations",
      sprintf("Bootstrap_Iterations='%s' is not numeric. Must be an integer between 1000 and 10000.",
              boot_iter),
      "",
      "Error"
    )
    return(error_log)
  }

  if (boot_iter_num < 1000 || boot_iter_num > 10000) {
    error_log <- log_preflight_issue(
      error_log, "Bootstrap Iterations", "Bootstrap_Iterations Out of Range",
      sprintf("Bootstrap_Iterations=%d is outside valid range [1000, 10000]. Use at least 1000 for reliable intervals.",
              as.integer(boot_iter_num)),
      "",
      "Error"
    )
  }

  if (boot_iter_num != round(boot_iter_num)) {
    error_log <- log_preflight_issue(
      error_log, "Bootstrap Iterations", "Non-Integer Bootstrap_Iterations",
      sprintf("Bootstrap_Iterations=%.2f is not a whole number. Must be an integer.", boot_iter_num),
      "",
      "Warning"
    )
  }

  return(error_log)
}


# ==============================================================================
# ORCHESTRATOR
# ==============================================================================

#' Run Pre-Flight Validation for Confidence Module
#'
#' Orchestrates all 13 pre-flight checks across config, question definitions,
#' data, and population margins. Returns a consolidated error log.
#'
#' @param config List, configuration object with settings from File_Paths and
#'   Study_Settings sheets
#' @param data Data frame, the survey data
#' @param questions_df Data frame from Question_Analysis sheet
#' @param margins_df Data frame from Population_Margins sheet (NULL to skip
#'   margin checks)
#' @param error_log Data frame, existing error log (NULL to create new)
#'
#' @return Data frame error log with columns: Check, Issue, Detail, Context, Severity
#'
#' @examples
#' \dontrun{
#'   error_log <- validate_confidence_preflight(config, data, questions_df, margins_df)
#'   errors <- error_log[error_log$Severity == "Error", ]
#'   if (nrow(errors) > 0) {
#'     cat("Pre-flight found", nrow(errors), "error(s). Fix before running analysis.\n")
#'   }
#' }
#'
#' @export
validate_confidence_preflight <- function(config, data, questions_df,
                                           margins_df = NULL, error_log = NULL) {
  # Initialise error log if not provided
  if (is.null(error_log)) {
    error_log <- data.frame(
      Check = character(0),
      Issue = character(0),
      Detail = character(0),
      Context = character(0),
      Severity = character(0),
      stringsAsFactors = FALSE
    )
  }

  cat("  Pre-flight cross-reference checks (Confidence)...\n")

  # --- Checks that require questions_df and data ---
  if (!is.null(questions_df) && is.data.frame(questions_df) && nrow(questions_df) > 0) {

    # 1. Question columns exist in data
    error_log <- check_question_columns_in_data(questions_df, data, error_log)

    # 2. Statistic_Type validity
    error_log <- check_statistic_type_validity(questions_df, error_log)

    # 3. At least one CI method selected
    error_log <- check_method_selection(questions_df, error_log)

    # 4. Proportion questions have Categories
    error_log <- check_proportion_categories(questions_df, error_log)

    # 5. NPS questions have Promoter and Detractor codes
    error_log <- check_nps_codes(questions_df, error_log)

    # 6. NPS Promoter/Detractor code overlap
    error_log <- check_nps_code_overlap(questions_df, error_log)

    # 7. Category/code values in data
    error_log <- check_category_values_in_data(questions_df, data, error_log)

    # 8. Prior specifications
    error_log <- check_prior_specs(questions_df, error_log)
  }

  # --- Checks that require config and data ---

  # 9. Weight variable
  error_log <- check_weight_variable_in_data(config, data, error_log)

  # --- Checks that require margins_df ---
  if (!is.null(margins_df) && is.data.frame(margins_df) && nrow(margins_df) > 0) {

    # 10. Population margins sum to ~1.0
    error_log <- check_population_margins_sum(margins_df, error_log)

    # 11. Margin variable names in data
    error_log <- check_population_margin_variables(margins_df, data, error_log)
  }

  # --- Config-only checks ---

  # 12. Confidence level
  error_log <- check_confidence_level_valid(config, error_log)

  # 13. Bootstrap iterations
  error_log <- check_bootstrap_iterations(config, error_log)

  # --- Summary ---
  n_errors <- sum(error_log$Severity == "Error")
  n_warnings <- sum(error_log$Severity == "Warning")
  n_info <- sum(error_log$Severity == "Info")

  if (n_errors == 0 && n_warnings == 0 && n_info == 0) {
    cat("  All pre-flight checks passed\n")
  } else {
    if (n_errors > 0) {
      cat(sprintf("  Pre-flight found %d error(s)\n", n_errors))
    }
    if (n_warnings > 0) {
      cat(sprintf("  Pre-flight found %d warning(s)\n", n_warnings))
    }
    if (n_info > 0) {
      cat(sprintf("  Pre-flight found %d info message(s)\n", n_info))
    }
  }

  return(error_log)
}
