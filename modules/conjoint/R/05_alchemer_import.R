# ==============================================================================
# TURAS CONJOINT ANALYSIS - ALCHEMER DATA IMPORT
# ==============================================================================
#
# Module: Conjoint Analysis - Alchemer Data Transformer
# Purpose: Transform Alchemer CBC export format to Turas internal format
# Version: 2.1.0 (Phase 1 - Alchemer Integration)
# Date: 2025-12-12
#
# ALCHEMER FORMAT:
#   ResponseID, SetNumber, CardNumber, [Attributes...], Score
#
# TURAS FORMAT:
#   resp_id, choice_set_id, alternative_id, [Attributes...], chosen
#
# ==============================================================================

# ==============================================================================
# MAIN IMPORT FUNCTION
# ==============================================================================

#' Import Alchemer Conjoint Export
#'
#' Transforms Alchemer CBC (Choice-Based Conjoint) export format to Turas
#' internal format. Handles column renaming, Score normalization, attribute
#' level cleaning, and data validation.
#'
#' @description
#' This function is the primary entry point for processing Alchemer conjoint
#' data exports. It performs the following transformations:
#'
#' 1. Column Mapping:
#'    - ResponseID -> resp_id
#'    - SetNumber + ResponseID -> choice_set_id (unique identifier)
#'    - CardNumber -> alternative_id
#'    - Score -> chosen (normalized to 0/1)
#'
#' 2. Attribute Level Cleaning:
#'    - Price format: "Low_071" -> "Low"
#'    - Binary format: "MSG_Present" -> "Present"
#'    - Already clean values pass through unchanged
#'
#' 3. Data Validation:
#'    - Exactly one chosen alternative per choice set
#'    - Consistent number of alternatives per set
#'    - No missing values in critical columns
#'
#' @param file_path Character. Path to Alchemer export file (.xlsx or .csv)
#' @param config List. Optional configuration with attribute mappings.
#'   If NULL, attributes are auto-detected from the data.
#' @param clean_levels Logical. Whether to clean attribute level names.
#'   Default TRUE. Set FALSE to preserve original Alchemer level names.
#' @param verbose Logical. Print progress messages. Default TRUE.
#'
#' @return Data frame in Turas format with columns:
#'   \item{resp_id}{Integer. Respondent identifier (from ResponseID)}
#'   \item{choice_set_id}{Character. Unique choice set ID (ResponseID_SetNumber)}
#'   \item{alternative_id}{Integer. Alternative within choice set (from CardNumber)}
#'   \item{[Attributes]}{Character/Factor. Attribute columns with cleaned level names}
#'   \item{chosen}{Integer. 0 or 1 indicating chosen alternative}
#'
#' @examples
#' \dontrun{
#' # Basic import
#' df <- import_alchemer_conjoint("DE_noodle_conjoint_raw.xlsx")
#'
#' # Import with custom config
#' config <- list(
#'   level_cleaning = list(
#'     Price = list(pattern = "_\\d+$", replacement = "")
#'   )
#' )
#' df <- import_alchemer_conjoint("data.xlsx", config = config)
#'
#' # Import without level cleaning
#' df <- import_alchemer_conjoint("data.csv", clean_levels = FALSE)
#' }
#'
#' @seealso \code{\link{validate_alchemer_data}}, \code{\link{clean_alchemer_level}}
#' @export
import_alchemer_conjoint <- function(file_path,
                                      config = NULL,
                                      clean_levels = TRUE,
                                      verbose = TRUE) {

  log_verbose("Importing Alchemer conjoint data...", verbose)
  log_verbose(sprintf("  Source: %s", basename(file_path)), verbose)

  # Validate file exists
  if (!file.exists(file_path)) {
    stop(create_error(
      "ALCHEMER_IMPORT",
      sprintf("File not found: %s", file_path),
      "Verify the file path is correct and the file exists"
    ), call. = FALSE)
  }

  # Load file based on extension
  df <- load_alchemer_file(file_path, verbose)

  log_verbose(sprintf("  Raw data: %d rows, %d columns", nrow(df), ncol(df)), verbose)

  # Validate required Alchemer columns
  validate_alchemer_columns(df)

  # Create unique choice_set_id (ResponseID + SetNumber combination)
  df$choice_set_id <- paste(df$ResponseID, df$SetNumber, sep = "_")

  # Rename columns to Turas format
  df$resp_id <- as.integer(df$ResponseID)
  df$alternative_id <- as.integer(df$CardNumber)

  # Normalize Score column (Alchemer uses 0/1 or 0/100)
  df$chosen <- normalize_score_column(df$Score)

  # Identify attribute columns (everything except system columns)
  system_cols <- c("ResponseID", "SetNumber", "CardNumber", "Score",
                   "choice_set_id", "resp_id", "alternative_id", "chosen")
  attribute_cols <- setdiff(names(df), system_cols)

  log_verbose(sprintf("  Attributes detected: %s",
                     paste(attribute_cols, collapse = ", ")), verbose)

  # Clean attribute level names if requested
  if (clean_levels && length(attribute_cols) > 0) {
    log_verbose("  Cleaning attribute level names...", verbose)
    for (col in attribute_cols) {
      original_levels <- unique(df[[col]])
      df[[col]] <- clean_alchemer_level(df[[col]], col)
      cleaned_levels <- unique(df[[col]])

      # Report changes if any
      if (!identical(original_levels, cleaned_levels)) {
        log_verbose(sprintf("    %s: %d unique levels (cleaned)",
                           col, length(cleaned_levels)), verbose)
      }
    }
  }

  # Select and order final columns
  final_cols <- c("resp_id", "choice_set_id", "alternative_id",
                  attribute_cols, "chosen")
  df <- df[, final_cols, drop = FALSE]

  # Validate data integrity
  validation_result <- validate_alchemer_data(df, verbose)

  if (!validation_result$is_valid) {
    stop(create_error(
      "ALCHEMER_IMPORT",
      "Data validation failed",
      paste(validation_result$errors, collapse = "\n   ")
    ), call. = FALSE)
  }

  # Report summary
  n_respondents <- length(unique(df$resp_id))
  n_choice_sets <- length(unique(df$choice_set_id))
  n_alternatives <- nrow(df)
  sets_per_resp <- n_choice_sets / n_respondents

  log_verbose(sprintf("  Processed: %d respondents, %d choice sets (%.1f per respondent)",
                     n_respondents, n_choice_sets, sets_per_resp), verbose)

  # Attach metadata as attributes
  attr(df, "source") <- "alchemer"
  attr(df, "source_file") <- basename(file_path)
  attr(df, "import_time") <- Sys.time()
  attr(df, "attribute_columns") <- attribute_cols

  df
}


# ==============================================================================
# FILE LOADING
# ==============================================================================

#' Load Alchemer Export File
#'
#' Loads data from Alchemer export file (Excel or CSV format)
#'
#' @param file_path Character. Path to file
#' @param verbose Logical. Print progress
#' @return Data frame with raw Alchemer data
#' @keywords internal
load_alchemer_file <- function(file_path, verbose = TRUE) {

  file_ext <- tolower(tools::file_ext(file_path))

  df <- tryCatch({
    if (file_ext == "xlsx" || file_ext == "xls") {
      log_verbose("  Loading Excel file...", verbose)
      openxlsx::read.xlsx(file_path, detectDates = TRUE)

    } else if (file_ext == "csv") {
      log_verbose("  Loading CSV file...", verbose)
      utils::read.csv(file_path, stringsAsFactors = FALSE,
                     check.names = FALSE, na.strings = c("", "NA", "N/A"))

    } else {
      stop(sprintf("Unsupported file format: .%s (use .xlsx or .csv)", file_ext))
    }
  }, error = function(e) {
    stop(create_error(
      "ALCHEMER_IMPORT",
      sprintf("Failed to load file: %s", conditionMessage(e)),
      "Check that the file is not corrupted or open in another program"
    ), call. = FALSE)
  })

  # Convert to data frame (in case of tibble)
  as.data.frame(df, stringsAsFactors = FALSE)
}


# ==============================================================================
# COLUMN VALIDATION
# ==============================================================================

#' Validate Required Alchemer Columns
#'
#' Checks that all required Alchemer columns are present
#'
#' @param df Data frame with Alchemer data
#' @keywords internal
validate_alchemer_columns <- function(df) {

  required_cols <- c("ResponseID", "SetNumber", "CardNumber", "Score")
  missing <- setdiff(required_cols, names(df))

  if (length(missing) > 0) {
    # Check for case-insensitive matches
    df_names_lower <- tolower(names(df))
    still_missing <- character()

    for (col in missing) {
      if (!tolower(col) %in% df_names_lower) {
        still_missing <- c(still_missing, col)
      }
    }

    if (length(still_missing) > 0) {
      stop(create_error(
        "ALCHEMER_IMPORT",
        sprintf("Missing required Alchemer columns: %s",
               paste(still_missing, collapse = ", ")),
        "Ensure you're using a raw Alchemer CBC export file",
        sprintf("Found columns: %s", paste(head(names(df), 10), collapse = ", "))
      ), call. = FALSE)
    }

    # Rename columns to expected case
    for (col in missing) {
      idx <- which(df_names_lower == tolower(col))
      if (length(idx) > 0) {
        names(df)[idx[1]] <- col
      }
    }
  }

  invisible(TRUE)
}


# ==============================================================================
# SCORE NORMALIZATION
# ==============================================================================

#' Normalize Score Column
#'
#' Converts Alchemer Score values to binary 0/1.
#' Alchemer may use 0/1, 0/100, or other scales.
#'
#' @param score_values Numeric vector of Score values
#' @return Integer vector with 0 (not chosen) or 1 (chosen)
#' @keywords internal
normalize_score_column <- function(score_values) {

  # Convert to numeric if needed
  score_values <- as.numeric(score_values)

  # Check for NA values
  if (any(is.na(score_values))) {
    n_na <- sum(is.na(score_values))
    warning(create_warning(
      "ALCHEMER_IMPORT",
      sprintf("Found %d NA values in Score column", n_na),
      "These will be treated as 'not chosen' (0)"
    ), call. = FALSE)
    score_values[is.na(score_values)] <- 0
  }

  # Determine scale and normalize
  max_score <- max(score_values, na.rm = TRUE)
  min_score <- min(score_values, na.rm = TRUE)

  if (max_score == 100 && min_score == 0) {
    # 0/100 scale - normalize to 0/1
    chosen <- ifelse(score_values >= 50, 1L, 0L)
  } else if (max_score == 1 && min_score == 0) {
    # Already 0/1 scale
    chosen <- as.integer(score_values)
  } else if (max_score > 0) {
    # Unknown scale - treat any positive value as chosen
    chosen <- ifelse(score_values > 0, 1L, 0L)
  } else {
    # All zeros - this is a problem
    warning(create_warning(
      "ALCHEMER_IMPORT",
      "All Score values are 0 or negative",
      "This may indicate a data quality issue"
    ), call. = FALSE)
    chosen <- 0L
  }

  chosen
}


# ==============================================================================
# LEVEL NAME CLEANING
# ==============================================================================

#' Clean Alchemer Level Names
#'
#' Extracts clean level names from Alchemer's compound format.
#' Handles multiple naming conventions used by Alchemer.
#'
#' @description
#' Alchemer encodes attribute levels in various formats:
#'
#' \itemize{
#'   \item Price format: "Low_071", "Mid_089", "High_107" -> "Low", "Mid", "High"
#'   \item Binary format: "MSG_Present", "Salt_Reduced" -> "Present", "Reduced"
#'   \item Simple format: "A", "B", "C" -> unchanged
#' }
#'
#' @param values Character vector of level values from Alchemer
#' @param attribute_name Character. Name of the attribute (for context-aware cleaning)
#' @return Character vector with cleaned level names
#'
#' @examples
#' \dontrun{
#' # Price format
#' clean_alchemer_level(c("Low_071", "Mid_089", "High_107"), "Price")
#' # Returns: c("Low", "Mid", "High")
#'
#' # Binary format
#' clean_alchemer_level(c("MSG_Present", "MSG_Absent"), "MSG")
#' # Returns: c("Present", "Absent")
#'
#' # NutriScore (unchanged)
#' clean_alchemer_level(c("A", "B", "C", "D", "E"), "NutriScore")
#' # Returns: c("A", "B", "C", "D", "E")
#' }
#'
#' @export
clean_alchemer_level <- function(values, attribute_name) {

  # Handle NULL or empty
  if (is.null(values) || length(values) == 0) {
    return(values)
  }

  # Convert to character
  values <- as.character(values)
  unique_values <- unique(values)

  # Pattern 1: Price format "Low_071", "Mid_089", "High_107" -> "Low", "Mid", "High"
  # Match pattern: Word followed by underscore and numbers
  if (all(grepl("^[A-Za-z]+_\\d+$", unique_values))) {
    return(gsub("_\\d+$", "", values))
  }

  # Pattern 2: Binary/attribute prefix format "Attribute_Level"
  # e.g., "MSG_Present" -> "Present", "Salt_Reduced" -> "Reduced"
  # Only apply if ALL values start with the attribute name
  # Use fixed=TRUE to avoid issues with special regex characters (e.g., "I+G")
  attr_prefix <- paste0(attribute_name, "_")
  if (all(startsWith(unique_values, attr_prefix))) {
    return(substring(values, nchar(attr_prefix) + 1))
  }

  # Pattern 3: Generic underscore prefix (attribute may have different name)
  # e.g., "PotassiumChloride_Present" for attribute "PotassiumChloride"
  # Check if values have consistent prefix before underscore
  has_underscore <- grepl("_", unique_values)
  if (all(has_underscore)) {
    # Extract prefix and suffix
    parts <- strsplit(unique_values, "_", fixed = TRUE)
    prefixes <- sapply(parts, function(x) x[1])

    # If all prefixes are the same, strip them
    if (length(unique(prefixes)) == 1) {
      return(gsub(paste0("^", unique(prefixes), "_"), "", values))
    }
  }

  # Pattern 4: Already clean (single letters, simple names like "A", "B", "C")
  # Return unchanged
  values
}


#' Clean All Attribute Levels with Custom Rules
#'
#' Apply custom cleaning rules from config to attribute levels
#'
#' @param df Data frame with attribute columns
#' @param config Configuration list with level_cleaning rules
#' @return Data frame with cleaned levels
#' @keywords internal
clean_levels_with_config <- function(df, config) {

  if (is.null(config$level_cleaning)) {
    return(df)
  }

  for (attr_name in names(config$level_cleaning)) {
    if (attr_name %in% names(df)) {
      rules <- config$level_cleaning[[attr_name]]

      if (!is.null(rules$pattern) && !is.null(rules$replacement)) {
        df[[attr_name]] <- gsub(rules$pattern, rules$replacement, df[[attr_name]])
      }

      if (!is.null(rules$mapping)) {
        for (old_val in names(rules$mapping)) {
          df[[attr_name]][df[[attr_name]] == old_val] <- rules$mapping[[old_val]]
        }
      }
    }
  }

  df
}


# ==============================================================================
# DATA VALIDATION
# ==============================================================================

#' Validate Alchemer Data
#'
#' Performs comprehensive validation of imported Alchemer data to ensure
#' it meets requirements for conjoint analysis.
#'
#' @param df Data frame in Turas format
#' @param verbose Logical. Print validation messages
#' @return List with is_valid, errors, and warnings
#'
#' @details
#' Validation checks include:
#' \itemize{
#'   \item Exactly one chosen alternative per choice set
#'   \item Consistent number of alternatives per choice set
#'   \item No missing values in critical columns
#'   \item Valid binary values for chosen column (0/1)
#' }
#'
#' @export
validate_alchemer_data <- function(df, verbose = TRUE) {

  errors <- character()
  warnings <- character()

  # Check 1: Exactly one chosen alternative per choice set
  choices_per_set <- aggregate(chosen ~ choice_set_id, data = df, FUN = sum)

  # Choice sets with no selection
  no_choice_sets <- choices_per_set$choice_set_id[choices_per_set$chosen == 0]
  if (length(no_choice_sets) > 0) {
    warnings <- c(warnings, sprintf(
      "Found %d choice sets with no selection (may indicate 'none' choices): %s...",
      length(no_choice_sets),
      paste(head(no_choice_sets, 3), collapse = ", ")
    ))
  }

  # Choice sets with multiple selections (error)
  multi_choice_sets <- choices_per_set$choice_set_id[choices_per_set$chosen > 1]
  if (length(multi_choice_sets) > 0) {
    errors <- c(errors, sprintf(
      "Found %d choice sets with MULTIPLE selections (invalid): %s",
      length(multi_choice_sets),
      paste(head(multi_choice_sets, 5), collapse = ", ")
    ))
  }

  # Check 2: Consistent number of alternatives per set
  alts_per_set <- aggregate(alternative_id ~ choice_set_id, data = df, FUN = length)
  unique_alt_counts <- unique(alts_per_set$alternative_id)

  if (length(unique_alt_counts) > 1) {
    warnings <- c(warnings, sprintf(
      "Inconsistent alternatives per choice set: %s",
      paste(unique_alt_counts, collapse = ", ")
    ))
  }

  # Check 3: No missing values in critical columns
  critical_cols <- c("resp_id", "choice_set_id", "alternative_id", "chosen")
  for (col in critical_cols) {
    if (col %in% names(df) && any(is.na(df[[col]]))) {
      n_missing <- sum(is.na(df[[col]]))
      errors <- c(errors, sprintf(
        "Column '%s' has %d missing values (NAs not allowed)",
        col, n_missing
      ))
    }
  }

  # Check 4: Valid binary values for chosen
  if ("chosen" %in% names(df)) {
    chosen_vals <- unique(df$chosen)
    if (!all(chosen_vals %in% c(0, 1))) {
      errors <- c(errors, sprintf(
        "'chosen' column must contain only 0 and 1 (found: %s)",
        paste(unique(chosen_vals), collapse = ", ")
      ))
    }
  }

  # Report validation results
  is_valid <- length(errors) == 0

  if (verbose) {
    if (is_valid) {
      log_verbose("  Data validation passed", verbose)
    } else {
      log_verbose(sprintf("  Data validation FAILED: %d errors", length(errors)), verbose)
    }

    if (length(warnings) > 0) {
      log_verbose(sprintf("  %d validation warnings", length(warnings)), verbose)
      for (w in warnings) {
        log_verbose(sprintf("    - %s", w), verbose)
      }
    }
  }

  list(
    is_valid = is_valid,
    errors = errors,
    warnings = warnings,
    n_choice_sets = nrow(choices_per_set),
    n_respondents = length(unique(df$resp_id)),
    alternatives_per_set = unique_alt_counts
  )
}


# ==============================================================================
# CONVENIENCE FUNCTIONS
# ==============================================================================

#' Get Attribute Summary from Alchemer Data
#'
#' Extracts attribute names and levels from imported Alchemer data.
#' Useful for building configuration files.
#'
#' @param df Data frame from import_alchemer_conjoint()
#' @return Data frame with AttributeName, NumLevels, LevelNames columns
#'
#' @examples
#' \dontrun{
#' df <- import_alchemer_conjoint("data.xlsx")
#' attrs <- get_alchemer_attributes(df)
#' print(attrs)
#' }
#'
#' @export
get_alchemer_attributes <- function(df) {

  # Get attribute columns from metadata or detect
  attribute_cols <- attr(df, "attribute_columns")

  if (is.null(attribute_cols)) {
    system_cols <- c("resp_id", "choice_set_id", "alternative_id", "chosen")
    attribute_cols <- setdiff(names(df), system_cols)
  }

  # Build summary
  attrs_list <- lapply(attribute_cols, function(col) {
    levels <- sort(unique(df[[col]]))
    data.frame(
      AttributeName = col,
      NumLevels = length(levels),
      LevelNames = paste(levels, collapse = ", "),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, attrs_list)
}


#' Create Turas Config from Alchemer Data
#'
#' Auto-generates a configuration list from imported Alchemer data.
#' This can be used directly or saved to Excel for further customization.
#'
#' @param df Data frame from import_alchemer_conjoint()
#' @param output_file Optional. Path to save config as Excel file.
#' @return List with settings and attributes configuration
#'
#' @examples
#' \dontrun{
#' df <- import_alchemer_conjoint("data.xlsx")
#' config <- create_config_from_alchemer(df, "conjoint_config.xlsx")
#' }
#'
#' @export
create_config_from_alchemer <- function(df, output_file = NULL) {

  # Get attributes
  attrs_df <- get_alchemer_attributes(df)

  # Parse level names into list
  attrs_df$levels_list <- lapply(attrs_df$LevelNames, function(x) {
    trimws(strsplit(x, ",")[[1]])
  })

  # Build settings
  settings <- list(
    data_source = "alchemer",
    analysis_type = "choice",
    estimation_method = "auto",
    choice_type = "single",
    respondent_id_column = "resp_id",
    choice_set_column = "choice_set_id",
    alternative_id_column = "alternative_id",
    chosen_column = "chosen",
    generate_market_simulator = TRUE,
    confidence_level = 0.95
  )

  # Build config
  config <- list(
    settings = settings,
    attributes = attrs_df
  )

  # Optionally save to Excel
  if (!is.null(output_file)) {
    save_config_to_excel(config, output_file)
  }

  config
}


#' Save Configuration to Excel
#'
#' Saves a configuration list to Excel file in Turas format.
#'
#' @param config Configuration list
#' @param output_file Path for output Excel file
#' @keywords internal
save_config_to_excel <- function(config, output_file) {

  wb <- openxlsx::createWorkbook()

  # Settings sheet
  openxlsx::addWorksheet(wb, "Settings")
  settings_df <- data.frame(
    Setting = names(config$settings),
    Value = unlist(config$settings),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Settings", settings_df)

  # Attributes sheet
  openxlsx::addWorksheet(wb, "Attributes")
  attrs_df <- config$attributes[, c("AttributeName", "NumLevels", "LevelNames")]
  openxlsx::writeData(wb, "Attributes", attrs_df)

  # Apply formatting
  header_style <- create_header_style()
  openxlsx::addStyle(wb, "Settings", header_style, rows = 1, cols = 1:2, gridExpand = TRUE)
  openxlsx::addStyle(wb, "Attributes", header_style, rows = 1, cols = 1:3, gridExpand = TRUE)

  openxlsx::setColWidths(wb, "Settings", cols = 1:2, widths = "auto")
  openxlsx::setColWidths(wb, "Attributes", cols = 1:3, widths = "auto")

  openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)

  message(sprintf("Configuration saved to: %s", output_file))
}


# ==============================================================================
# TESTING FUNCTION
# ==============================================================================

#' Test Alchemer Import
#'
#' Runs a quick test of the Alchemer import functionality.
#' Useful for verifying installation and basic functionality.
#'
#' @param file_path Path to Alchemer export file for testing
#' @return Logical. TRUE if test passed, FALSE otherwise
#'
#' @examples
#' \dontrun{
#' test_alchemer_import("DE_noodle_conjoint_raw.xlsx")
#' }
#'
#' @export
test_alchemer_import <- function(file_path) {

  cat("\n=== ALCHEMER IMPORT TEST ===\n\n")

  result <- tryCatch({
    # Test 1: Import file
    cat("Test 1: Importing file...\n")
    df <- import_alchemer_conjoint(file_path, verbose = FALSE)
    cat(sprintf("  PASS: Loaded %d rows, %d columns\n", nrow(df), ncol(df)))

    # Test 2: Check structure
    cat("\nTest 2: Checking data structure...\n")
    required_cols <- c("resp_id", "choice_set_id", "alternative_id", "chosen")
    missing <- setdiff(required_cols, names(df))
    if (length(missing) > 0) {
      cat(sprintf("  FAIL: Missing columns: %s\n", paste(missing, collapse = ", ")))
      return(FALSE)
    }
    cat("  PASS: All required columns present\n")

    # Test 3: Validate choices
    cat("\nTest 3: Validating choice structure...\n")
    choices_per_set <- aggregate(chosen ~ choice_set_id, data = df, FUN = sum)
    valid_sets <- sum(choices_per_set$chosen == 1)
    cat(sprintf("  Valid choice sets: %d / %d (%.1f%%)\n",
               valid_sets, nrow(choices_per_set),
               100 * valid_sets / nrow(choices_per_set)))

    # Test 4: Show attribute summary
    cat("\nTest 4: Attribute summary...\n")
    attrs <- get_alchemer_attributes(df)
    for (i in seq_len(nrow(attrs))) {
      cat(sprintf("  %s: %d levels (%s)\n",
                 attrs$AttributeName[i],
                 attrs$NumLevels[i],
                 substr(attrs$LevelNames[i], 1, 50)))
    }

    cat("\n=== TEST COMPLETE ===\n")
    TRUE

  }, error = function(e) {
    cat(sprintf("\nTEST FAILED: %s\n", conditionMessage(e)))
    FALSE
  })

  invisible(result)
}
