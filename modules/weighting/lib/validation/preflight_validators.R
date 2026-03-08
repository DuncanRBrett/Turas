# ==============================================================================
# PREFLIGHT VALIDATORS - TURAS Weighting Module
# ==============================================================================
# Cross-referential validation between config, weight specs, targets, and data
# Catches configuration mistakes before weighting calculations begin
#
# VERSION HISTORY:
# V1.0 - Initial creation (2026-03-08)
#       - 14 cross-referential checks
#       - Standalone log_preflight_issue helper (module-specific)
#       - Orchestrator: validate_weighting_preflight()
#
# USAGE:
#   source("modules/weighting/lib/validation/preflight_validators.R")
#   error_log <- validate_weighting_preflight(config, data)
#
# FUNCTIONS EXPORTED:
#   - log_preflight_issue()                - Append an issue to the error log
#   - check_weight_specs_methods()         - Method validity + target sheet presence
#   - check_design_targets_vs_data()       - Design targets match data
#   - check_rim_targets_sum()              - Rim targets sum to 100 per variable
#   - check_rim_categories_vs_data()       - Rim categories exist in data
#   - check_cell_targets_sum()             - Cell targets sum to 100 per weight
#   - check_cell_combinations_vs_data()    - Cell combinations exist in data
#   - check_trim_config_consistency()      - Trimming fields are complete
#   - check_advanced_settings_vs_specs()   - Advanced weight names match specs
#   - check_data_file_columns()            - Referenced variables exist in data
#   - check_weight_variable_quality()      - No NAs/negatives/Inf in weight vars
#   - check_empty_categories()             - No zero-count categories
#   - check_duplicate_weight_names()       - No duplicate weight_name values
#   - check_logo_file_exists()             - Logo file exists if specified
#   - check_colour_codes()                 - Hex colour format validation
#   - validate_weighting_preflight()       - Orchestrator (runs all checks)
# ==============================================================================


# ==============================================================================
# LOGGING HELPER
# ==============================================================================

#' Append a Pre-Flight Issue to the Error Log
#'
#' Creates a standardised error log entry and appends it to the running log.
#'
#' @param error_log Data frame, existing error log (or NULL to create one)
#' @param check_name Character, name of the check that found the issue
#' @param issue_title Character, short title for the issue
#' @param detail Character, detailed description of the problem
#' @param context Character, additional context (e.g. weight name, variable)
#' @param severity Character, one of "Error", "Warning", "Info"
#'
#' @return Data frame, updated error log with new row appended
#' @keywords internal
log_preflight_issue <- function(error_log, check_name, issue_title, detail,
                                context = "", severity = "Error") {
  new_row <- data.frame(
    Check = check_name,
    Issue = issue_title,
    Detail = detail,
    Context = context,
    Severity = severity,
    stringsAsFactors = FALSE
  )

  if (is.null(error_log) || nrow(error_log) == 0) {
    return(new_row)
  }

  rbind(error_log, new_row)
}


# ==============================================================================
# CHECK 1: Weight Specs - Method Validity & Target Sheet Presence
# ==============================================================================

#' Check Weight Specifications Methods
#'
#' For each weight: validates the method is one of design/rim/rake/cell, and
#' verifies the corresponding target sheet exists in the config.
#'
#' @param specs_df Data frame, Weight_Specifications sheet
#' @param available_sheets Character vector, names of sheets present in config
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_weight_specs_methods <- function(specs_df, available_sheets, error_log) {
  valid_methods <- c("design", "rim", "rake", "cell")

  for (i in seq_len(nrow(specs_df))) {
    wname <- specs_df$weight_name[i]
    method <- tolower(trimws(as.character(specs_df$method[i])))

    # Check method is valid
    if (is.na(method) || !method %in% valid_methods) {
      error_log <- log_preflight_issue(
        error_log, "Weight Specs Methods", "Invalid Weighting Method",
        sprintf("Weight '%s' has method='%s'. Must be one of: %s.",
                wname, as.character(specs_df$method[i]),
                paste(valid_methods, collapse = ", ")),
        wname, "Error"
      )
      next
    }

    # Check target sheet exists for this method
    if (method == "design") {
      if (!"Design_Targets" %in% available_sheets) {
        error_log <- log_preflight_issue(
          error_log, "Weight Specs Methods", "Missing Design_Targets Sheet",
          sprintf("Weight '%s' uses method=design but no Design_Targets sheet found in config.",
                  wname),
          wname, "Error"
        )
      }
    } else if (method %in% c("rim", "rake")) {
      if (!"Rim_Targets" %in% available_sheets) {
        error_log <- log_preflight_issue(
          error_log, "Weight Specs Methods", "Missing Rim_Targets Sheet",
          sprintf("Weight '%s' uses method=%s but no Rim_Targets sheet found in config.",
                  wname, method),
          wname, "Error"
        )
      }
    } else if (method == "cell") {
      if (!"Cell_Targets" %in% available_sheets) {
        error_log <- log_preflight_issue(
          error_log, "Weight Specs Methods", "Missing Cell_Targets Sheet",
          sprintf("Weight '%s' uses method=cell but no Cell_Targets sheet found in config.",
                  wname),
          wname, "Error"
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 2: Design Targets vs Data
# ==============================================================================

#' Check Design Targets Against Data
#'
#' Verifies that stratum_variable columns exist in data, stratum_category
#' values are present in the data, and population_size values are positive.
#'
#' @param design_df Data frame, Design_Targets sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_design_targets_vs_data <- function(design_df, data, error_log) {
  if (is.null(design_df) || nrow(design_df) == 0) return(error_log)

  data_cols <- names(data)

  for (i in seq_len(nrow(design_df))) {
    wname <- as.character(design_df$weight_name[i])
    strat_var <- as.character(design_df$stratum_variable[i])
    strat_cat <- as.character(design_df$stratum_category[i])
    pop_size <- design_df$population_size[i]

    # Check stratum_variable exists in data
    if (!strat_var %in% data_cols) {
      error_log <- log_preflight_issue(
        error_log, "Design Targets vs Data", "Stratum Variable Not Found",
        sprintf("Weight '%s': stratum_variable '%s' does not exist as a column in the data.",
                wname, strat_var),
        paste(wname, strat_var, sep = " / "), "Error"
      )
      next
    }

    # Check stratum_category exists in data values
    data_values <- unique(as.character(data[[strat_var]]))
    if (!strat_cat %in% data_values) {
      error_log <- log_preflight_issue(
        error_log, "Design Targets vs Data", "Stratum Category Not in Data",
        sprintf("Weight '%s': stratum_category '%s' not found in column '%s'. Available values: %s.",
                wname, strat_cat, strat_var,
                paste(utils::head(data_values[!is.na(data_values)], 10), collapse = ", ")),
        paste(wname, strat_var, strat_cat, sep = " / "), "Warning"
      )
    }

    # Check population_size > 0
    numeric_pop <- suppressWarnings(as.numeric(pop_size))
    if (is.na(numeric_pop) || numeric_pop <= 0) {
      error_log <- log_preflight_issue(
        error_log, "Design Targets vs Data", "Invalid Population Size",
        sprintf("Weight '%s': population_size for '%s=%s' must be a positive number (got: '%s').",
                wname, strat_var, strat_cat, as.character(pop_size)),
        paste(wname, strat_var, strat_cat, sep = " / "), "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 3: Rim Targets Sum to 100
# ==============================================================================

#' Check Rim Targets Sum to 100
#'
#' Verifies that target_percent values sum to 100 per variable per weight_name
#' (with a tolerance of +/- 0.5 percentage points).
#'
#' @param rim_df Data frame, Rim_Targets sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_rim_targets_sum <- function(rim_df, error_log) {
  if (is.null(rim_df) || nrow(rim_df) == 0) return(error_log)

  tolerance <- 0.5

  # Group by weight_name + variable
  combos <- unique(rim_df[, c("weight_name", "variable"), drop = FALSE])

  for (j in seq_len(nrow(combos))) {
    wname <- as.character(combos$weight_name[j])
    varname <- as.character(combos$variable[j])

    subset_rows <- rim_df[rim_df$weight_name == wname & rim_df$variable == varname, ]
    pct_values <- suppressWarnings(as.numeric(subset_rows$target_percent))
    pct_values <- pct_values[!is.na(pct_values)]

    if (length(pct_values) == 0) {
      error_log <- log_preflight_issue(
        error_log, "Rim Targets Sum", "No Valid Percentages",
        sprintf("Weight '%s', variable '%s': no valid numeric target_percent values found.",
                wname, varname),
        paste(wname, varname, sep = " / "), "Error"
      )
      next
    }

    total <- sum(pct_values)
    if (abs(total - 100) > tolerance) {
      error_log <- log_preflight_issue(
        error_log, "Rim Targets Sum", "Targets Do Not Sum to 100%",
        sprintf("Weight '%s', variable '%s': target_percent sums to %.2f%% (expected 100%%, tolerance +/-%.1f%%).",
                wname, varname, total, tolerance),
        paste(wname, varname, sep = " / "), "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 4: Rim Categories vs Data
# ==============================================================================

#' Check Rim Categories Against Data
#'
#' Verifies that rim variable columns exist in data and that rim category
#' values are present in the data.
#'
#' @param rim_df Data frame, Rim_Targets sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_rim_categories_vs_data <- function(rim_df, data, error_log) {
  if (is.null(rim_df) || nrow(rim_df) == 0) return(error_log)

  data_cols <- names(data)

  # Check each unique variable
  unique_vars <- unique(as.character(rim_df$variable))

  for (varname in unique_vars) {
    if (!varname %in% data_cols) {
      error_log <- log_preflight_issue(
        error_log, "Rim Categories vs Data", "Rim Variable Not Found",
        sprintf("Rim variable '%s' does not exist as a column in the data.", varname),
        varname, "Error"
      )
      next
    }

    # Check each category for this variable
    var_rows <- rim_df[rim_df$variable == varname, ]
    data_values <- unique(as.character(data[[varname]]))
    data_values <- data_values[!is.na(data_values)]

    for (k in seq_len(nrow(var_rows))) {
      cat_val <- as.character(var_rows$category[k])
      if (!cat_val %in% data_values) {
        wname <- as.character(var_rows$weight_name[k])
        error_log <- log_preflight_issue(
          error_log, "Rim Categories vs Data", "Rim Category Not in Data",
          sprintf("Weight '%s': category '%s' for variable '%s' not found in data. Available values: %s.",
                  wname, cat_val, varname,
                  paste(utils::head(data_values, 10), collapse = ", ")),
          paste(wname, varname, cat_val, sep = " / "), "Warning"
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 5: Cell Targets Sum to 100
# ==============================================================================

#' Check Cell Targets Sum to 100
#'
#' Verifies that target_percent values sum to 100 per weight_name
#' (with a tolerance of +/- 0.5 percentage points).
#'
#' @param cell_df Data frame, Cell_Targets sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_cell_targets_sum <- function(cell_df, error_log) {
  if (is.null(cell_df) || nrow(cell_df) == 0) return(error_log)

  tolerance <- 0.5

  unique_weights <- unique(as.character(cell_df$weight_name))

  for (wname in unique_weights) {
    subset_rows <- cell_df[cell_df$weight_name == wname, ]
    pct_values <- suppressWarnings(as.numeric(subset_rows$target_percent))
    pct_values <- pct_values[!is.na(pct_values)]

    if (length(pct_values) == 0) {
      error_log <- log_preflight_issue(
        error_log, "Cell Targets Sum", "No Valid Percentages",
        sprintf("Weight '%s': no valid numeric target_percent values found in Cell_Targets.",
                wname),
        wname, "Error"
      )
      next
    }

    total <- sum(pct_values)
    if (abs(total - 100) > tolerance) {
      error_log <- log_preflight_issue(
        error_log, "Cell Targets Sum", "Cell Targets Do Not Sum to 100%",
        sprintf("Weight '%s': cell target_percent sums to %.2f%% (expected 100%%, tolerance +/-%.1f%%).",
                wname, total, tolerance),
        wname, "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 6: Cell Combinations vs Data
# ==============================================================================

#' Check Cell Combinations Against Data
#'
#' Verifies that cell variable columns exist in data and that cell value
#' combinations are present.
#'
#' @param cell_df Data frame, Cell_Targets sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_cell_combinations_vs_data <- function(cell_df, data, error_log) {
  if (is.null(cell_df) || nrow(cell_df) == 0) return(error_log)

  data_cols <- names(data)

  for (i in seq_len(nrow(cell_df))) {
    wname <- as.character(cell_df$weight_name[i])
    var1 <- as.character(cell_df$Variable_1[i])
    val1 <- as.character(cell_df$Value_1[i])
    var2 <- as.character(cell_df$Variable_2[i])
    val2 <- as.character(cell_df$Value_2[i])

    # Check Variable_1 exists in data
    if (!var1 %in% data_cols) {
      error_log <- log_preflight_issue(
        error_log, "Cell Combinations vs Data", "Cell Variable Not Found",
        sprintf("Weight '%s': Variable_1='%s' does not exist as a column in the data.",
                wname, var1),
        paste(wname, var1, sep = " / "), "Error"
      )
      next
    }

    # Check Variable_2 exists in data
    if (!var2 %in% data_cols) {
      error_log <- log_preflight_issue(
        error_log, "Cell Combinations vs Data", "Cell Variable Not Found",
        sprintf("Weight '%s': Variable_2='%s' does not exist as a column in the data.",
                wname, var2),
        paste(wname, var2, sep = " / "), "Error"
      )
      next
    }

    # Check combination exists in data
    data_var1 <- as.character(data[[var1]])
    data_var2 <- as.character(data[[var2]])
    combo_exists <- any(data_var1 == val1 & data_var2 == val2, na.rm = TRUE)

    if (!combo_exists) {
      error_log <- log_preflight_issue(
        error_log, "Cell Combinations vs Data", "Cell Combination Not in Data",
        sprintf("Weight '%s': combination %s='%s' + %s='%s' has zero respondents in data.",
                wname, var1, val1, var2, val2),
        paste(wname, var1, val1, var2, val2, sep = " / "), "Warning"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 7: Trim Config Consistency
# ==============================================================================

#' Check Trim Configuration Consistency
#'
#' If apply_trimming=Y, verifies that trim_method and trim_value are specified
#' and that trim_value is positive.
#'
#' @param specs_df Data frame, Weight_Specifications sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_trim_config_consistency <- function(specs_df, error_log) {
  for (i in seq_len(nrow(specs_df))) {
    wname <- as.character(specs_df$weight_name[i])
    apply_trim <- toupper(trimws(as.character(specs_df$apply_trimming[i])))

    if (is.na(apply_trim) || apply_trim != "Y") next

    # Check trim_method is specified
    trim_method <- as.character(specs_df$trim_method[i])
    if (is.na(trim_method) || trimws(trim_method) == "") {
      error_log <- log_preflight_issue(
        error_log, "Trim Config", "Missing Trim Method",
        sprintf("Weight '%s': apply_trimming=Y but trim_method is empty. Must be 'cap' or 'percentile'.",
                wname),
        wname, "Error"
      )
    }

    # Check trim_value is specified and positive
    trim_value <- suppressWarnings(as.numeric(specs_df$trim_value[i]))
    if (is.na(trim_value)) {
      error_log <- log_preflight_issue(
        error_log, "Trim Config", "Missing Trim Value",
        sprintf("Weight '%s': apply_trimming=Y but trim_value is empty or non-numeric.",
                wname),
        wname, "Error"
      )
    } else if (trim_value <= 0) {
      error_log <- log_preflight_issue(
        error_log, "Trim Config", "Invalid Trim Value",
        sprintf("Weight '%s': trim_value must be positive (got: %.4f).",
                wname, trim_value),
        wname, "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 8: Advanced Settings vs Specs
# ==============================================================================

#' Check Advanced Settings Reference Valid Weight Names
#'
#' Verifies that weight_names in Advanced_Settings match those defined
#' in Weight_Specifications.
#'
#' @param advanced_df Data frame, Advanced_Settings sheet
#' @param specs_df Data frame, Weight_Specifications sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_advanced_settings_vs_specs <- function(advanced_df, specs_df, error_log) {
  if (is.null(advanced_df) || nrow(advanced_df) == 0) return(error_log)

  specs_names <- unique(as.character(specs_df$weight_name))
  adv_names <- unique(as.character(advanced_df$weight_name))

  orphan_names <- setdiff(adv_names, specs_names)
  if (length(orphan_names) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Advanced vs Specs", "Orphan Advanced Settings",
      sprintf("Advanced_Settings references %d weight_name(s) not found in Weight_Specifications: %s.",
              length(orphan_names), paste(orphan_names, collapse = ", ")),
      paste(orphan_names, collapse = ", "), "Warning"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 9: Data File Columns
# ==============================================================================

#' Check All Referenced Variables Exist in Data
#'
#' Gathers all variable names referenced across all config sheets and checks
#' they exist as columns in the data.
#'
#' @param config List, parsed config (with $rim_targets, $design_targets, $cell_targets)
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_data_file_columns <- function(config, data, error_log) {
  data_cols <- names(data)
  referenced_vars <- character(0)

  # Collect variables from design targets
  if (!is.null(config$design_targets) && nrow(config$design_targets) > 0) {
    referenced_vars <- c(referenced_vars,
                         unique(as.character(config$design_targets$stratum_variable)))
  }

  # Collect variables from rim targets
  if (!is.null(config$rim_targets) && nrow(config$rim_targets) > 0) {
    referenced_vars <- c(referenced_vars,
                         unique(as.character(config$rim_targets$variable)))
  }

  # Collect variables from cell targets
  if (!is.null(config$cell_targets) && nrow(config$cell_targets) > 0) {
    referenced_vars <- c(referenced_vars,
                         unique(as.character(config$cell_targets$Variable_1)),
                         unique(as.character(config$cell_targets$Variable_2)))
  }

  referenced_vars <- unique(referenced_vars)
  referenced_vars <- referenced_vars[!is.na(referenced_vars) & referenced_vars != ""]

  missing_cols <- setdiff(referenced_vars, data_cols)
  if (length(missing_cols) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Data File Columns", "Referenced Columns Missing",
      sprintf("%d variable(s) referenced in config but not found in data: %s.",
              length(missing_cols), paste(missing_cols, collapse = ", ")),
      paste(missing_cols, collapse = ", "), "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 10: Weight Variable Quality
# ==============================================================================

#' Check Weight Variable Data Quality
#'
#' Validates that weighting variable columns contain no NAs, no negative
#' values, and no infinite values.
#'
#' @param data Data frame, survey data
#' @param weight_vars Character vector, column names used as weighting variables
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_weight_variable_quality <- function(data, weight_vars, error_log) {
  if (is.null(weight_vars) || length(weight_vars) == 0) return(error_log)

  data_cols <- names(data)

  for (varname in weight_vars) {
    if (!varname %in% data_cols) next

    vals <- data[[varname]]

    # Check for NAs
    n_na <- sum(is.na(vals))
    if (n_na > 0) {
      error_log <- log_preflight_issue(
        error_log, "Weight Variable Quality", "Missing Values in Weight Variable",
        sprintf("Variable '%s' has %d missing (NA) value(s) out of %d rows. Weighting requires complete data for all weight variables.",
                varname, n_na, length(vals)),
        varname, "Error"
      )
    }

    # For numeric checks, attempt conversion
    numeric_vals <- suppressWarnings(as.numeric(vals))
    non_na_numeric <- numeric_vals[!is.na(numeric_vals)]

    if (length(non_na_numeric) > 0) {
      # Check for negative values
      n_negative <- sum(non_na_numeric < 0)
      if (n_negative > 0) {
        error_log <- log_preflight_issue(
          error_log, "Weight Variable Quality", "Negative Values in Weight Variable",
          sprintf("Variable '%s' has %d negative value(s). Weight variables must be non-negative.",
                  varname, n_negative),
          varname, "Error"
        )
      }

      # Check for infinite values
      n_inf <- sum(is.infinite(non_na_numeric))
      if (n_inf > 0) {
        error_log <- log_preflight_issue(
          error_log, "Weight Variable Quality", "Infinite Values in Weight Variable",
          sprintf("Variable '%s' has %d infinite value(s). Weight variables must be finite.",
                  varname, n_inf),
          varname, "Error"
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 11: Empty Categories
# ==============================================================================

#' Check for Empty Categories in Weighting Variables
#'
#' Verifies no categories have zero respondents in the weighting variables.
#' Zero-count cells make weights undefined.
#'
#' @param data Data frame, survey data
#' @param weight_vars Character vector, column names used as weighting variables
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_empty_categories <- function(data, weight_vars, error_log) {
  if (is.null(weight_vars) || length(weight_vars) == 0) return(error_log)

  data_cols <- names(data)

  for (varname in weight_vars) {
    if (!varname %in% data_cols) next

    vals <- data[[varname]]
    vals <- vals[!is.na(vals)]

    if (length(vals) == 0) {
      error_log <- log_preflight_issue(
        error_log, "Empty Categories", "All-NA Variable",
        sprintf("Variable '%s' has no non-NA values. Cannot compute weights.", varname),
        varname, "Error"
      )
      next
    }

    # Check category frequencies
    freq_table <- table(vals)
    zero_cats <- names(freq_table[freq_table == 0])

    if (length(zero_cats) > 0) {
      error_log <- log_preflight_issue(
        error_log, "Empty Categories", "Zero-Count Category",
        sprintf("Variable '%s' has %d category(ies) with zero respondents: %s. This will cause undefined weights.",
                varname, length(zero_cats),
                paste(zero_cats, collapse = ", ")),
        varname, "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 12: Duplicate Weight Names
# ==============================================================================

#' Check for Duplicate Weight Names
#'
#' Verifies that all weight_name values in Weight_Specifications are unique.
#'
#' @param specs_df Data frame, Weight_Specifications sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_duplicate_weight_names <- function(specs_df, error_log) {
  if (is.null(specs_df) || nrow(specs_df) == 0) return(error_log)

  weight_names <- as.character(specs_df$weight_name)
  weight_names <- weight_names[!is.na(weight_names) & weight_names != ""]

  dup_names <- weight_names[duplicated(weight_names)]

  if (length(dup_names) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Duplicate Weight Names", "Duplicate weight_name Values",
      sprintf("Weight_Specifications contains %d duplicate weight_name(s): %s. Each weight_name must be unique.",
              length(unique(dup_names)), paste(unique(dup_names), collapse = ", ")),
      paste(unique(dup_names), collapse = ", "), "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 13: Logo File Exists
# ==============================================================================

#' Check Logo File Exists
#'
#' If logo_file is specified in config, verifies the file exists on disk.
#'
#' @param config List, parsed config object
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_logo_file_exists <- function(config, error_log) {
  logo_path <- config$logo_file

  if (is.null(logo_path) || is.na(logo_path) || trimws(logo_path) == "") {
    return(error_log)
  }

  if (!file.exists(logo_path)) {
    error_log <- log_preflight_issue(
      error_log, "Logo File", "Logo File Not Found",
      sprintf("logo_file '%s' does not exist. The report will render without a logo.",
              logo_path),
      logo_path, "Warning"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 14: Colour Code Validation
# ==============================================================================

#' Check Colour Codes Are Valid Hex
#'
#' Validates that brand_colour and accent_colour are valid hex colour codes
#' in #RRGGBB format.
#'
#' @param config List, parsed config object
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_colour_codes <- function(config, error_log) {
  hex_pattern <- "^#[0-9A-Fa-f]{6}$"

  colour_fields <- list(
    brand_colour = "Brand colour",
    accent_colour = "Accent colour"
  )

  for (field_name in names(colour_fields)) {
    val <- config[[field_name]]

    if (is.null(val) || is.na(val) || trimws(val) == "") next

    if (!grepl(hex_pattern, trimws(val))) {
      error_log <- log_preflight_issue(
        error_log, "Colour Codes", "Invalid Hex Colour",
        sprintf("%s '%s' is not a valid hex colour code (expected format: #RRGGBB).",
                colour_fields[[field_name]], val),
        val, "Warning"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# ORCHESTRATOR
# ==============================================================================

#' Run All Pre-Flight Weighting Validation Checks
#'
#' Cross-references config, weight specifications, targets, and data to catch
#' configuration mistakes before weighting calculations begin. Runs all 14
#' check functions and returns a consolidated error log.
#'
#' @param config List, parsed weighting config. Expected fields:
#'   \itemize{
#'     \item{specs}{Data frame, Weight_Specifications}
#'     \item{design_targets}{Data frame, Design_Targets (or NULL)}
#'     \item{rim_targets}{Data frame, Rim_Targets (or NULL)}
#'     \item{cell_targets}{Data frame, Cell_Targets (or NULL)}
#'     \item{advanced_settings}{Data frame, Advanced_Settings (or NULL)}
#'     \item{available_sheets}{Character vector, sheet names in config file}
#'     \item{brand_colour}{Character, hex colour (or NULL)}
#'     \item{accent_colour}{Character, hex colour (or NULL)}
#'     \item{logo_file}{Character, path (or NULL)}
#'   }
#' @param data Data frame, survey data
#' @param error_log Data frame, existing error log (NULL to create fresh)
#'
#' @return Data frame, consolidated error log with columns:
#'   Check, Issue, Detail, Context, Severity
#'
#' @examples
#' \dontrun{
#'   error_log <- validate_weighting_preflight(config, survey_data)
#'   errors_only <- error_log[error_log$Severity == "Error", ]
#'   if (nrow(errors_only) > 0) {
#'     cat("Pre-flight failed with", nrow(errors_only), "error(s)\n")
#'   }
#' }
#'
#' @export
validate_weighting_preflight <- function(config, data, error_log = NULL) {

  # Initialise empty error log if not provided
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

  cat("\n  Pre-flight cross-reference checks (weighting)...\n")

  # Extract config components
  specs_df <- config$specs
  design_df <- config$design_targets
  rim_df <- config$rim_targets
  cell_df <- config$cell_targets
  advanced_df <- config$advanced_settings
  available_sheets <- config$available_sheets

  if (is.null(available_sheets)) {
    available_sheets <- character(0)
  }

  # --- Check 1: Weight specs method validity and target sheet presence ---
  if (!is.null(specs_df) && nrow(specs_df) > 0) {
    error_log <- check_weight_specs_methods(specs_df, available_sheets, error_log)
  }

  # --- Check 2: Design targets vs data ---
  if (!is.null(design_df) && nrow(design_df) > 0) {
    error_log <- check_design_targets_vs_data(design_df, data, error_log)
  }

  # --- Check 3: Rim targets sum to 100 ---
  if (!is.null(rim_df) && nrow(rim_df) > 0) {
    error_log <- check_rim_targets_sum(rim_df, error_log)
  }

  # --- Check 4: Rim categories vs data ---
  if (!is.null(rim_df) && nrow(rim_df) > 0) {
    error_log <- check_rim_categories_vs_data(rim_df, data, error_log)
  }

  # --- Check 5: Cell targets sum to 100 ---
  if (!is.null(cell_df) && nrow(cell_df) > 0) {
    error_log <- check_cell_targets_sum(cell_df, error_log)
  }

  # --- Check 6: Cell combinations vs data ---
  if (!is.null(cell_df) && nrow(cell_df) > 0) {
    error_log <- check_cell_combinations_vs_data(cell_df, data, error_log)
  }

  # --- Check 7: Trim config consistency ---
  if (!is.null(specs_df) && nrow(specs_df) > 0) {
    error_log <- check_trim_config_consistency(specs_df, error_log)
  }

  # --- Check 8: Advanced settings vs specs ---
  if (!is.null(advanced_df) && nrow(advanced_df) > 0 &&
      !is.null(specs_df) && nrow(specs_df) > 0) {
    error_log <- check_advanced_settings_vs_specs(advanced_df, specs_df, error_log)
  }

  # --- Check 9: All referenced variables exist in data ---
  error_log <- check_data_file_columns(config, data, error_log)

  # --- Check 10: Weight variable data quality ---
  # Gather all unique variable names used as weighting dimensions
  weight_vars <- character(0)
  if (!is.null(design_df) && nrow(design_df) > 0) {
    weight_vars <- c(weight_vars, unique(as.character(design_df$stratum_variable)))
  }
  if (!is.null(rim_df) && nrow(rim_df) > 0) {
    weight_vars <- c(weight_vars, unique(as.character(rim_df$variable)))
  }
  if (!is.null(cell_df) && nrow(cell_df) > 0) {
    weight_vars <- c(weight_vars,
                     unique(as.character(cell_df$Variable_1)),
                     unique(as.character(cell_df$Variable_2)))
  }
  weight_vars <- unique(weight_vars)
  weight_vars <- weight_vars[!is.na(weight_vars) & weight_vars != ""]

  if (length(weight_vars) > 0) {
    error_log <- check_weight_variable_quality(data, weight_vars, error_log)
  }

  # --- Check 11: Empty categories in weighting variables ---
  if (length(weight_vars) > 0) {
    error_log <- check_empty_categories(data, weight_vars, error_log)
  }

  # --- Check 12: Duplicate weight names ---
  if (!is.null(specs_df) && nrow(specs_df) > 0) {
    error_log <- check_duplicate_weight_names(specs_df, error_log)
  }

  # --- Check 13: Logo file exists ---
  error_log <- check_logo_file_exists(config, error_log)

  # --- Check 14: Colour code validation ---
  error_log <- check_colour_codes(config, error_log)

  # --- Summary ---
  n_issues <- nrow(error_log)
  if (n_issues == 0) {
    cat("  All pre-flight checks passed\n")
  } else {
    n_errors <- sum(error_log$Severity == "Error")
    n_warnings <- sum(error_log$Severity == "Warning")
    n_info <- sum(error_log$Severity == "Info")
    cat(sprintf("  Pre-flight found %d issue(s): %d error(s), %d warning(s), %d info\n",
                n_issues, n_errors, n_warnings, n_info))
  }

  return(error_log)
}
