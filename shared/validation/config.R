# ==============================================================================
# TURAS VALIDATION: CONFIGURATION MODULE
# ==============================================================================
# Configuration validation functions
# Part of Turas Analytics Toolkit - Phase 4 Migration
#
# MIGRATED FROM: validation.r (lines 619-849, 879-1050, 1078-1303)
# DATE: October 24, 2025
# STATUS: Phase 4 - Module 3
#
# DESCRIPTION:
#   Validates crosstab, weighting, and filter configurations including:
#   - Weighting configuration and weight column validation
#   - Base filter expression validation (security and correctness)
#   - Crosstab configuration parameters (alpha, decimals, formats)
#
# DEPENDENCIES:
#   - core/validation.R (validate_data_frame, validate_char_param)
#   - core/logging.R (log_issue)
#   - core/utilities.R (safe_divide, safe_equal)
#   - core/io.R (get_config_value, safe_numeric, safe_logical)
#
# EXPORTED FUNCTIONS:
#   - validate_weighting_config() - Weighting configuration validator
#   - validate_base_filter() - Filter expression validator
#   - validate_crosstab_config() - Crosstab configuration validator
# ==============================================================================

# ==============================================================================
# WEIGHTING VALIDATION (V9.9.5: FULLY CONFIGURABLE THRESHOLDS)
# ==============================================================================

#' Validate weighting configuration and weight column
#'
#' Comprehensive validation of weighting configuration including:
#' - Weighting config consistency
#' - Weight variable is specified when weighting enabled
#' - Weight column exists in data
#' - Weight values are valid (not all NA, not negative, not infinite)
#' - Weight distribution is reasonable (CV, design effect)
#' - Weights are not all equal
#'
#' V9.9.5 ENHANCEMENTS:
#' - All thresholds now configurable:
#'   * weight_na_threshold (default: 10)
#'   * weight_zero_threshold (default: 5)
#'   * weight_deff_warning (default: 3)
#'
#' V9.9.2 ENHANCEMENTS:
#' - Reports Kish design effect (deff ≈ 1 + CV²)
#' - Checks for all-equal weights (SD ≈ 0)
#'
#' @param survey_structure Survey structure list containing $project
#' @param survey_data Survey data frame
#' @param config Configuration list
#' @param error_log Error log data frame (from create_error_log())
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Updated error log data frame with any validation issues
#' @export
#' @examples
#' error_log <- validate_weighting_config(survey_structure, survey_data, config, error_log)
validate_weighting_config <- function(survey_structure, survey_data, config, error_log, verbose = TRUE) {
  
  # ============================================================================
  # INPUT VALIDATION
  # ============================================================================
  
  if (!is.list(survey_structure) || !"project" %in% names(survey_structure)) {
    stop("survey_structure must contain $project", call. = FALSE)
  }
  
  if (!is.data.frame(survey_data)) {
    stop("survey_data must be a data frame", call. = FALSE)
  }
  
  if (!is.list(config)) {
    stop("config must be a list", call. = FALSE)
  }
  
  if (!is.data.frame(error_log)) {
    stop("error_log must be a data frame", call. = FALSE)
  }
  
  # ============================================================================
  # CHECK IF WEIGHTING IS ENABLED
  # ============================================================================
  
  apply_weighting <- safe_logical(get_config_value(config, "apply_weighting", FALSE))
  
  if (!apply_weighting) {
    return(error_log)  # No weighting, nothing to validate
  }
  
  if (verbose) cat("Validating weighting configuration...\n")
  
  # ============================================================================
  # CHECK WEIGHT COLUMN EXISTS FLAG
  # ============================================================================
  
  weight_exists <- safe_logical(
    get_config_value(survey_structure$project, "weight_column_exists", "N")
  )
  
  if (!weight_exists) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Weighting Configuration Mismatch",
      "apply_weighting=TRUE but weight_column_exists=N in Survey_Structure. Update Survey_Structure or disable weighting.",
      "", 
      "Error"
    )
    return(error_log)
  }
  
  # ============================================================================
  # GET WEIGHT COLUMN NAME
  # ============================================================================
  
  weight_variable <- get_config_value(config, "weight_variable", NULL)
  
  if (is.null(weight_variable) || is.na(weight_variable) || weight_variable == "") {
    # Try to get default weight from Survey_Structure
    weight_variable <- get_config_value(survey_structure$project, "default_weight", NULL)
    
    if (is.null(weight_variable) || is.na(weight_variable) || weight_variable == "") {
      error_log <- log_issue(
        error_log, 
        "Validation", 
        "Missing Weight Variable",
        "Weighting enabled but no weight_variable specified in config. Set weight_variable or disable weighting.",
        "", 
        "Error"
      )
      return(error_log)
    }
  }
  
  # ============================================================================
  # CHECK WEIGHT COLUMN EXISTS IN DATA
  # ============================================================================
  
  if (!weight_variable %in% names(survey_data)) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Missing Weight Column",
      sprintf(
        "Weight column '%s' not found in data. Add column or update weight_variable.",
        weight_variable
      ),
      "", 
      "Error"
    )
    return(error_log)
  }
  
  # ============================================================================
  # VALIDATE WEIGHT VALUES
  # ============================================================================
  
  weight_values <- survey_data[[weight_variable]]
  
  # Check for non-numeric weights
  if (!is.numeric(weight_values)) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Non-Numeric Weights",
      sprintf("Weight column '%s' is not numeric (type: %s)", weight_variable, class(weight_values)[1]),
      "", 
      "Error"
    )
    return(error_log)
  }
  
  # Check for all NA
  valid_weights <- weight_values[!is.na(weight_values) & is.finite(weight_values)]
  
  if (length(valid_weights) == 0) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Empty Weight Column",
      sprintf("Weight column '%s' has no valid (non-NA, finite) values", weight_variable),
      "", 
      "Error"
    )
    return(error_log)
  }
  
  # ============================================================================
  # CHECK NA RATE (V9.9.5: Configurable threshold)
  # ============================================================================
  
  na_threshold <- safe_numeric(get_config_value(config, "weight_na_threshold", 10))
  zero_threshold <- safe_numeric(get_config_value(config, "weight_zero_threshold", 5))
  deff_threshold <- safe_numeric(get_config_value(config, "weight_deff_warning", 3))
  
  pct_na <- 100 * sum(is.na(weight_values)) / length(weight_values)
  
  if (pct_na > na_threshold) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "High NA Rate in Weights",
      sprintf(
        "Weight column '%s' has %.1f%% NA values (threshold: %.0f%%). Review data quality.",
        weight_variable, pct_na, na_threshold
      ),
      "", 
      "Warning"
    )
  }
  
  # ============================================================================
  # CHECK FOR NEGATIVE WEIGHTS
  # ============================================================================
  
  if (any(valid_weights < 0)) {
    n_negative <- sum(valid_weights < 0)
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Negative Weights",
      sprintf(
        "Weight column '%s' contains %d negative values (%.1f%%). Weights must be non-negative.",
        weight_variable, n_negative, 100 * n_negative / length(valid_weights)
      ),
      "", 
      "Error"
    )
  }
  
  # ============================================================================
  # CHECK FOR ZERO WEIGHTS (V9.9.5: Configurable threshold)
  # ============================================================================
  
  n_zero <- sum(valid_weights == 0)
  if (n_zero > 0) {
    pct_zero <- 100 * n_zero / length(valid_weights)
    if (pct_zero > zero_threshold) {
      error_log <- log_issue(
        error_log, 
        "Validation", 
        "Many Zero Weights",
        sprintf(
          "Weight column '%s' has %d zero values (%.1f%%, threshold: %.0f%%). High proportion may indicate data issues.",
          weight_variable, n_zero, pct_zero, zero_threshold
        ),
        "", 
        "Warning"
      )
    }
  }
  
  # ============================================================================
  # CHECK FOR INFINITE WEIGHTS
  # ============================================================================
  
  if (any(is.infinite(weight_values))) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Infinite Weights",
      sprintf("Weight column '%s' contains infinite values. Fix data before analysis.", weight_variable),
      "", 
      "Error"
    )
  }
  
  # ============================================================================
  # CHECK WEIGHT VARIABILITY (V9.9.2)
  # ============================================================================
  
  nonzero_weights <- valid_weights[valid_weights > 0]
  
  if (length(nonzero_weights) > 0) {
    weight_sd <- sd(nonzero_weights)
    weight_mean <- mean(nonzero_weights)
    
    # Check for all-equal weights (SD ≈ 0)
    if (weight_sd < 1e-10 || (weight_mean > 0 && weight_sd / weight_mean < 1e-6)) {
      error_log <- log_issue(
        error_log, 
        "Validation", 
        "All-Equal Weights",
        sprintf(
          "Weight column '%s' has near-zero variance (SD = %.10f). All weights appear equal - weighting may not be applied.",
          weight_variable, weight_sd
        ),
        "", 
        "Warning"
      )
    }
    
    # Calculate design effect (V9.9.5: Configurable threshold)
    weight_cv <- weight_sd / weight_mean
    
    if (weight_cv > 1.5) {
      # V9.9.2: Calculate and report Kish design effect (deff ≈ 1 + CV²)
      design_effect <- 1 + weight_cv^2
      
      severity <- if (design_effect > deff_threshold) "Warning" else "Info"
      
      error_log <- log_issue(
        error_log, 
        "Validation", 
        "High Weight Variability",
        sprintf(
          "Weight column '%s' has high variability (CV = %.2f, Design Effect ≈ %.2f, threshold: %.1f). %s",
          weight_variable, 
          weight_cv,
          design_effect,
          deff_threshold,
          if (design_effect > deff_threshold) "This substantially reduces effective sample size. Verify weights are correct." else "Verify weights are correct."
        ),
        "", 
        severity
      )
    }
  }
  
  # ============================================================================
  # COMPLETE
  # ============================================================================
  
  if (verbose) cat("✓ Weighting validation complete\n")
  
  return(error_log)
}

# ==============================================================================
# BASE FILTER VALIDATION (V9.9.2)
# ==============================================================================

#' Validate base filter expression for safety and correctness
#'
#' Comprehensive validation of filter expressions including:
#' - Expression is valid R code
#' - Expression returns logical vector
#' - Vector length matches data
#' - Filter retains at least some rows
#' - No unsafe characters or operations
#'
#' V9.9.2 ENHANCEMENTS:
#' - Allows %in% and : operators (common in filters)
#' - Hardened dangerous patterns (::, :::, get, assign, mget, do.call)
#' - Uses enclos = parent.frame() for safer evaluation
#'
#' DESIGN: Comprehensive security checks before evaluating user-provided code
#'
#' @param filter_expression R expression as string
#' @param survey_data Survey data frame
#' @param question_code Question code for logging (optional)
#' @return List with $valid (logical) and $message (character)
#' @export
#' @examples
#' result <- validate_base_filter("AGE %in% 18:24", survey_data)
#' if (!result$valid) stop(result$message)
validate_base_filter <- function(filter_expression, survey_data, question_code = "") {
  
  # ============================================================================
  # INPUT VALIDATION
  # ============================================================================
  
  if (!is.data.frame(survey_data)) {
    return(list(
      valid = FALSE,
      message = "survey_data must be a data frame"
    ))
  }
  
  if (nrow(survey_data) == 0) {
    return(list(
      valid = FALSE,
      message = "survey_data is empty (0 rows)"
    ))
  }
  
  # Empty/null filter is valid (no filtering)
  if (is.na(filter_expression) || is.null(filter_expression) || filter_expression == "") {
    return(list(valid = TRUE, message = "No filter"))
  }
  
  # Must be character
  if (!is.character(filter_expression)) {
    return(list(
      valid = FALSE,
      message = sprintf("Filter must be character string, got: %s", class(filter_expression)[1])
    ))
  }
  
  # ============================================================================
  # CLEAN UNICODE CHARACTERS
  # ============================================================================
  
  filter_expression <- tryCatch({
    # Convert to ASCII, replacing non-ASCII with closest match
    cleaned <- iconv(filter_expression, to = "ASCII//TRANSLIT", sub = "")
    if (is.na(cleaned)) filter_expression else cleaned
  }, error = function(e) filter_expression)
  
  # Replace various Unicode spaces with regular space
  filter_expression <- gsub("[\u00A0\u2000-\u200B\u202F\u205F\u3000]", " ", filter_expression)
  
  # Replace smart quotes with regular quotes
  filter_expression <- gsub("[\u2018\u2019\u201A\u201B]", "'", filter_expression)
  filter_expression <- gsub("[\u201C\u201D\u201E\u201F]", '"', filter_expression)
  
  # Trim whitespace
  filter_expression <- trimws(filter_expression)
  
  # ============================================================================
  # CHECK FOR UNSAFE CHARACTERS
  # ============================================================================
  
  # V9.9.2: Check for potentially unsafe characters (NOW INCLUDES % and :)
  # Allow: letters, numbers, underscore, $, ., (), &, |, !, <, >, =, +, -, *, /, ,, quotes, [], space, %, :
  if (grepl("[^A-Za-z0-9_$.()&|!<>= +*/,'\"\\[\\]%:-]", filter_expression)) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Filter contains potentially unsafe characters: '%s'. Use only standard operators and column names.",
        filter_expression
      )
    ))
  }
  
  # ============================================================================
  # CHECK FOR DANGEROUS PATTERNS
  # ============================================================================
  
  # V9.9.2: Enhanced dangerous patterns list
  dangerous_patterns <- c(
    "system\\s*\\(",    # system calls
    "eval\\s*\\(",      # eval (nested)
    "source\\s*\\(",    # sourcing code
    "library\\s*\\(",   # loading packages
    "require\\s*\\(",   # loading packages
    "<-",               # assignment
    "<<-",              # global assignment
    "->",               # right assignment
    "->>",              # right global assignment
    "rm\\s*\\(",        # removing objects
    "file\\.",          # file operations
    "sink\\s*\\(",      # sink
    "options\\s*\\(",   # changing options
    "\\.GlobalEnv",     # accessing global env
    "::",               # namespace access (V9.9.2)
    ":::",              # internal namespace access (V9.9.2)
    "get\\s*\\(",       # get function (V9.9.2)
    "assign\\s*\\(",    # assign function (V9.9.2)
    "mget\\s*\\(",      # mget function (V9.9.2)
    "do\\.call\\s*\\(" # do.call function (V9.9.2)
  )
  
  for (pattern in dangerous_patterns) {
    if (grepl(pattern, filter_expression, ignore.case = TRUE)) {
      return(list(
        valid = FALSE,
        message = sprintf(
          "Filter contains unsafe pattern: '%s' not allowed",
          gsub("\\\\s\\*\\\\\\(", "(", pattern)
        )
      ))
    }
  }
  
  # ============================================================================
  # EVALUATE FILTER
  # ============================================================================
  
  tryCatch({
    # V9.9.2: Use enclos = parent.frame() for safer name resolution
    filter_result <- eval(
      parse(text = filter_expression), 
      envir = survey_data,
      enclos = parent.frame()
    )
    
    # Check return type
    if (!is.logical(filter_result)) {
      return(list(
        valid = FALSE,
        message = sprintf(
          "Filter must return logical vector, got: %s. Use logical operators (==, !=, <, >, &, |, %%in%%).",
          class(filter_result)[1]
        )
      ))
    }
    
    # Check length
    if (length(filter_result) != nrow(survey_data)) {
      return(list(
        valid = FALSE,
        message = sprintf(
          "Filter returned %d values but data has %d rows. Check column names and operations.",
          length(filter_result), 
          nrow(survey_data)
        )
      ))
    }
    
    # Check how many rows retained (excluding NAs)
    n_retained <- sum(filter_result, na.rm = TRUE)
    n_total <- nrow(survey_data)
    pct_retained <- round(100 * n_retained / n_total, 1)
    
    if (n_retained == 0) {
      return(list(
        valid = FALSE,
        message = sprintf(
          "Filter retains 0 rows (filters out all data). Expression: '%s'",
          filter_expression
        )
      ))
    }
    
    # Check for too many NAs in filter result
    n_na <- sum(is.na(filter_result))
    pct_na <- round(100 * n_na / n_total, 1)
    
    message_parts <- c(
      sprintf("Filter OK: %d of %d rows (%.1f%%)", n_retained, n_total, pct_retained)
    )
    
    if (n_na > 0) {
      message_parts <- c(
        message_parts,
        sprintf("%d NA values (%.1f%%) treated as FALSE", n_na, pct_na)
      )
    }
    
    return(list(
      valid = TRUE,
      message = paste(message_parts, collapse = "; ")
    ))
    
  }, error = function(e) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Filter evaluation failed: %s. Check column names and syntax. Expression: '%s'",
        conditionMessage(e),
        filter_expression
      )
    ))
  })
}

# ==============================================================================
# CROSSTAB CONFIG VALIDATION (V9.9.3: OUTPUT FORMAT NORMALIZATION)
# ==============================================================================

#' Validate crosstab configuration parameters
#'
#' Comprehensive validation of crosstab configuration including:
#' - alpha (significance level) is in (0, 1)
#' - significance_min_base is positive
#' - decimal_places are reasonable (0-5, documented standard)
#' - All required config values are present
#' - Output format is valid (normalizes excel → xlsx)
#'
#' V9.9.2 ENHANCEMENTS:
#' - Documents decimal precision policy (0-5 is standard)
#'
#' V9.9.3 ENHANCEMENTS:
#' - Normalizes output_format in config object: "excel" → "xlsx"
#'
#' @param config Configuration list
#' @param survey_structure Survey structure list
#' @param survey_data Survey data frame
#' @param error_log Error log data frame (from create_error_log())
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Updated error log data frame with any validation issues
#' @export
#' @examples
#' error_log <- validate_crosstab_config(config, survey_structure, survey_data, error_log)
validate_crosstab_config <- function(config, survey_structure, survey_data, error_log, verbose = TRUE) {
  
  # ============================================================================
  # INPUT VALIDATION
  # ============================================================================
  
  if (!is.list(config)) {
    stop("config must be a list", call. = FALSE)
  }
  
  if (!is.data.frame(error_log)) {
    stop("error_log must be a data frame", call. = FALSE)
  }
  
  if (verbose) cat("Validating crosstab configuration...\n")
  
  # ============================================================================
  # VALIDATE ALPHA (SIGNIFICANCE LEVEL)
  # ============================================================================
  
  alpha <- get_config_value(config, "alpha", NULL)
  sig_level <- get_config_value(config, "significance_level", NULL)
  
  if (!is.null(sig_level) && is.null(alpha)) {
    # Old config using significance_level (0.95) - warn about deprecation
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Deprecated Config Parameter",
      "Using 'significance_level' is deprecated. Use 'alpha' instead (e.g., alpha = 0.05 for 95% CI).",
      "", 
      "Warning"
    )
    
    # Convert significance_level to alpha
    sig_level <- safe_numeric(sig_level)
    if (sig_level > 0.5) {
      # Looks like confidence level (0.95), convert to alpha
      alpha <- 1 - sig_level
    } else {
      # Already looks like alpha
      alpha <- sig_level
    }
  } else if (!is.null(alpha)) {
    alpha <- safe_numeric(alpha)
  } else {
    # Default
    alpha <- 0.05
  }
  
  # Validate alpha range
  if (alpha <= 0 || alpha >= 1) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Invalid Alpha",
      sprintf(
        "alpha must be between 0 and 1 (typical: 0.05 for 95%% CI, 0.01 for 99%% CI), got: %.4f",
        alpha
      ),
      "", 
      "Error"
    )
  }
  
  # Warn if alpha is unusual
  if (alpha > 0.2) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Unusual Alpha Value",
      sprintf(
        "alpha = %.4f is unusually high (>80%% CI). Typical values: 0.05 (95%% CI) or 0.01 (99%% CI).",
        alpha
      ),
      "", 
      "Warning"
    )
  }
  
  # ============================================================================
  # VALIDATE MINIMUM BASE
  # ============================================================================
  
  min_base <- safe_numeric(get_config_value(config, "significance_min_base", 30))
  
  if (min_base < 1) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Invalid Minimum Base",
      sprintf("significance_min_base must be positive, got: %d", min_base),
      "", 
      "Error"
    )
  }
  
  if (min_base < 10) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Low Minimum Base",
      sprintf(
        "significance_min_base = %d is very low. Values < 30 may give unreliable significance tests.",
        min_base
      ),
      "", 
      "Warning"
    )
  }
  
  # ============================================================================
  # VALIDATE DECIMAL PLACES (0-5 recommended, 6 allowed for edge cases)
  # ============================================================================
  
  decimal_settings <- c(
    "decimal_places_percent",
    "decimal_places_ratings",
    "decimal_places_index",
    "decimal_places_mean",
    "decimal_places_numeric"  # V10.0.0: Added for Numeric questions
  )
  
  for (setting in decimal_settings) {
    value <- safe_numeric(get_config_value(config, setting, 0))
    
    if (value < 0 || value > MAX_DECIMAL_PLACES) {
      error_log <- log_issue(
        error_log, 
        "Validation", 
        "Invalid Decimal Places",
        sprintf(
          "%s out of range: %d (must be 0-%d).",
          setting, value, MAX_DECIMAL_PLACES
        ),
        "", 
        "Error"
      )
    } else if (value > 5) {
      error_log <- log_issue(
        error_log, 
        "Validation", 
        "High Decimal Places",
        sprintf(
          "%s = %d exceeds recommended range (0-5 is standard). Values 0-2 are typical for survey reporting.",
          setting, value
        ),
        "", 
        "Warning"
      )
    }
  }
  
  # ============================================================================
  # VALIDATE NUMERIC QUESTION SETTINGS (V10.0.0)
  # ============================================================================
  
  # Validate median/mode with weighting
  show_median <- safe_logical(get_config_value(config, "show_numeric_median", FALSE))
  show_mode <- safe_logical(get_config_value(config, "show_numeric_mode", FALSE))
  apply_weighting <- safe_logical(get_config_value(config, "apply_weighting", FALSE))
  
  if (show_median && apply_weighting) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Unsupported Configuration",
      "show_numeric_median=TRUE with apply_weighting=TRUE: Median is only available for unweighted data. Median will display as 'N/A (weighted)'.",
      "",
      "Warning"
    )
  }
  
  if (show_mode && apply_weighting) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Unsupported Configuration",
      "show_numeric_mode=TRUE with apply_weighting=TRUE: Mode is only available for unweighted data. Mode will display as 'N/A (weighted)'.",
      "",
      "Warning"
    )
  }
  
  # Validate outlier method
  outlier_method <- get_config_value(config, "outlier_method", "IQR")
  valid_outlier_methods <- c("IQR")
  
  if (!outlier_method %in% valid_outlier_methods) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Invalid Outlier Method",
      sprintf(
        "outlier_method '%s' not supported. Valid methods: %s. Using 'IQR' as default.",
        outlier_method,
        paste(valid_outlier_methods, collapse = ", ")
      ),
      "",
      "Warning"
    )
    config$outlier_method <- "IQR"  # Normalize to default
  }
  
  # ============================================================================
  # VALIDATE AND NORMALIZE OUTPUT FORMAT (V9.9.3)
  # ============================================================================
  
  output_format <- get_config_value(config, "output_format", "excel")
  valid_formats <- c("excel", "xlsx", "csv")
  
  if (!output_format %in% valid_formats) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Invalid Output Format",
      sprintf(
        "output_format '%s' not recognized. Valid formats: %s. Using 'xlsx' as default.",
        output_format,
        paste(valid_formats, collapse = ", ")
      ),
      "", 
      "Warning"
    )
    config$output_format <- "xlsx"  # V9.9.3: Normalize
  } else if (output_format == "excel") {
    # V9.9.3: Normalize "excel" to "xlsx" IN the config object
    config$output_format <- "xlsx"
    if (verbose) {
      cat("  Note: output_format 'excel' normalized to 'xlsx'\n")
    }
  }
  
  # ============================================================================
  # COMPLETE
  # ============================================================================
  
  if (verbose) cat("✓ Configuration validation complete\n")
  
  return(error_log)
}
