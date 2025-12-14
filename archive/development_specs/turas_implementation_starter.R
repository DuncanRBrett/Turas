# ==============================================================================
# TURAS CONJOINT MODULE - IMPLEMENTATION STARTER CODE
# ==============================================================================
# This file provides working code templates for Sonnet 4.5 to build upon
# ==============================================================================

# ------------------------------------------------------------------------------
# FILE: 05_alchemer_import.R - Alchemer Data Transformer
# ------------------------------------------------------------------------------

#' Import Alchemer Conjoint Export
#'
#' Transforms Alchemer CBC export format to Turas internal format.
#'
#' ALCHEMER FORMAT:
#'   ResponseID, SetNumber, CardNumber, [Attributes...], Score
#'
#' TURAS FORMAT:
#'   resp_id, choice_set_id, alternative_id, [Attributes...], chosen
#'
#' @param file_path Path to Alchemer export (xlsx or csv)
#' @param config Configuration list with attribute mappings
#' @return Data frame in Turas format
#' @export
import_alchemer_conjoint <- function(file_path, config = NULL) {
  
  # Load file
  file_ext <- tolower(tools::file_ext(file_path))
  
  if (file_ext == "xlsx") {
    df <- openxlsx::read.xlsx(file_path)
  } else if (file_ext == "csv") {
    df <- utils::read.csv(file_path, stringsAsFactors = FALSE)
  } else {
    stop("Unsupported file format: ", file_ext, call. = FALSE)
  }
  
  # Validate required Alchemer columns
  required_cols <- c("ResponseID", "SetNumber", "CardNumber", "Score")
  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    stop("Missing required Alchemer columns: ", paste(missing, collapse = ", "), 
         call. = FALSE)
  }
  
  # Create unique choice_set_id (ResponseID + SetNumber combination)
  df$choice_set_id <- paste(df$ResponseID, df$SetNumber, sep = "_")
  
  # Rename columns to Turas format
  df$resp_id <- df$ResponseID
  df$alternative_id <- df$CardNumber
  
  # Normalize Score column (Alchemer uses 0/1 or 0/100)
  df$chosen <- ifelse(df$Score > 0, 1L, 0L)
  
  # Identify attribute columns (everything except system columns)
  system_cols <- c("ResponseID", "SetNumber", "CardNumber", "Score",
                   "choice_set_id", "resp_id", "alternative_id", "chosen")
  attribute_cols <- setdiff(names(df), system_cols)
  
  # Clean attribute level names if needed
  for (col in attribute_cols) {
    df[[col]] <- clean_alchemer_level(df[[col]], col)
  }
  
  # Select and order final columns
  final_cols <- c("resp_id", "choice_set_id", "alternative_id", 
                  attribute_cols, "chosen")
  df <- df[, final_cols]
  
  # Validate data integrity
  validate_choice_data(df)
  
  df
}


#' Clean Alchemer Level Names
#'
#' Extracts clean level names from Alchemer's compound format.
#' Examples:
#'   "Low_071" -> "Low"
#'   "MSG_Present" -> "Present"
#'   "A" -> "A" (unchanged)
#'
#' @param values Vector of level values
#' @param attribute_name Name of the attribute (for context)
#' @return Cleaned values
#' @keywords internal
clean_alchemer_level <- function(values, attribute_name) {
  
  # Pattern 1: Price format "Low_071" -> "Low"
  if (all(grepl("^(Low|Mid|High)_\\d+", values, ignore.case = TRUE))) {
    return(gsub("_\\d+$", "", values))
  }
  
  # Pattern 2: Binary format "Attribute_Level" -> "Level"
  # e.g., "MSG_Present" -> "Present", "Salt_Reduced" -> "Reduced"
  if (all(grepl(paste0("^", attribute_name, "_"), values))) {
    return(gsub(paste0("^", attribute_name, "_"), "", values))
  }
  
  # Pattern 3: Already clean (single letters, simple names)
  # Return unchanged
  values
}


#' Validate Choice Data Integrity
#'
#' Ensures data meets requirements for choice-based conjoint analysis.
#'
#' @param df Data frame to validate
#' @keywords internal
validate_choice_data <- function(df) {
  
  # Check: Exactly one chosen alternative per choice set
  choices_per_set <- aggregate(chosen ~ choice_set_id, data = df, FUN = sum)
  
  if (any(choices_per_set$chosen == 0)) {
    problem_sets <- choices_per_set$choice_set_id[choices_per_set$chosen == 0]
    warning(sprintf("Found %d choice sets with no selection: %s...", 
                    length(problem_sets), 
                    paste(head(problem_sets, 3), collapse = ", ")),
            call. = FALSE)
  }
  
  if (any(choices_per_set$chosen > 1)) {
    problem_sets <- choices_per_set$choice_set_id[choices_per_set$chosen > 1]
    warning(sprintf("Found %d choice sets with multiple selections: %s...",
                    length(problem_sets),
                    paste(head(problem_sets, 3), collapse = ", ")),
            call. = FALSE)
  }
  
  # Check: Consistent number of alternatives per set
  alts_per_set <- aggregate(alternative_id ~ choice_set_id, data = df, FUN = length)
  if (length(unique(alts_per_set$alternative_id)) > 1) {
    warning("Inconsistent number of alternatives across choice sets", call. = FALSE)
  }
  
  invisible(TRUE)
}


# ------------------------------------------------------------------------------
# FILE: 03_analysis.R - mlogit Implementation (Key Section)
# ------------------------------------------------------------------------------

#' Estimate Choice-Based Conjoint with mlogit
#'
#' Uses mlogit package for proper discrete choice modeling.
#'
#' @param data Data list from load_conjoint_data()
#' @param config Configuration list
#' @return List with utilities, model, and fit statistics
#' @keywords internal
estimate_choice_mlogit <- function(data, config) {
  
  # Check mlogit availability
  if (!requireNamespace("mlogit", quietly = TRUE)) {
    stop("Package 'mlogit' required. Install with: install.packages('mlogit')",
         call. = FALSE)
  }
  
  df <- data$data
  attributes <- config$attributes
  
  # Get column names from config
  choice_set_col <- config$settings$choice_set_column %||% "choice_set_id"
  chosen_col <- config$settings$chosen_column %||% "chosen"
  respondent_col <- config$settings$respondent_id_column %||% "resp_id"
  alt_col <- config$settings$alternative_id_column %||% "alternative_id"
  
  # Get attribute column names
  attribute_cols <- attributes$AttributeName
  
  # Convert attributes to factors with explicit levels from config
  for (i in seq_len(nrow(attributes))) {
    attr_name <- attributes$AttributeName[i]
    attr_levels <- attributes$levels_list[[i]]
    
    if (attr_name %in% names(df)) {
      df[[attr_name]] <- factor(df[[attr_name]], levels = attr_levels)
    }
  }
  
  # Prepare data for mlogit
  # mlogit.data requires specific structure
  mlogit_df <- mlogit::mlogit.data(
    df,
    choice = chosen_col,
    shape = "long",
    alt.var = alt_col,
    chid.var = choice_set_col,
    id.var = respondent_col
  )
  
  # Build formula
  # Format: chosen ~ attr1 + attr2 + ... | 0
  # The "| 0" suppresses alternative-specific constants
  formula_str <- paste(chosen_col, "~", 
                       paste(attribute_cols, collapse = " + "),
                       "| 0")
  model_formula <- as.formula(formula_str)
  
  # Fit model
  model <- mlogit::mlogit(model_formula, data = mlogit_df)
  
  # Extract and process coefficients
  coefs <- coef(model)
  std_errors <- sqrt(diag(vcov(model)))
  
  # Create utilities data frame
  utilities_list <- list()
  raw_coefs_list <- list()
  
  for (i in seq_len(nrow(attributes))) {
    attr_name <- attributes$AttributeName[i]
    attr_levels <- attributes$levels_list[[i]]
    
    # Find coefficients for this attribute
    # mlogit names: AttributeLevel (e.g., "PriceLow", "BrandApple")
    coef_pattern <- paste0("^", attr_name)
    attr_coef_idx <- grep(coef_pattern, names(coefs))
    attr_coefs <- coefs[attr_coef_idx]
    attr_se <- std_errors[attr_coef_idx]
    
    # Extract level names from coefficient names
    coef_levels <- gsub(coef_pattern, "", names(attr_coefs))
    
    # Initialize utilities (first level is reference = 0)
    utilities <- numeric(length(attr_levels))
    names(utilities) <- attr_levels
    
    # Assign estimated coefficients
    for (j in seq_along(coef_levels)) {
      if (coef_levels[j] %in% names(utilities)) {
        utilities[coef_levels[j]] <- attr_coefs[j]
      }
    }
    
    # Store raw coefficients before zero-centering
    for (j in seq_along(attr_levels)) {
      raw_coefs_list[[length(raw_coefs_list) + 1]] <- data.frame(
        Attribute = attr_name,
        Level = attr_levels[j],
        Coefficient = utilities[j],
        StdError = if (attr_levels[j] %in% coef_levels) {
          attr_se[match(attr_levels[j], coef_levels)]
        } else {
          NA  # Reference level has no SE
        },
        stringsAsFactors = FALSE
      )
    }
    
    # Zero-center utilities within attribute
    utilities <- utilities - mean(utilities)
    
    # Store zero-centered utilities
    for (j in seq_along(utilities)) {
      utilities_list[[length(utilities_list) + 1]] <- data.frame(
        Attribute = attr_name,
        Level = names(utilities)[j],
        Utility = utilities[j],
        stringsAsFactors = FALSE
      )
    }
  }
  
  utilities_df <- do.call(rbind, utilities_list)
  raw_coefs_df <- do.call(rbind, raw_coefs_list)
  
  # Calculate fit statistics
  fit <- calculate_mlogit_fit(model, df, choice_set_col, chosen_col, respondent_col)
  
  list(
    utilities = utilities_df,
    raw_coefficients = raw_coefs_df,
    model = model,
    fit = fit,
    engine = "mlogit"
  )
}


#' Calculate mlogit Model Fit Statistics
#'
#' @keywords internal
calculate_mlogit_fit <- function(model, df, choice_set_col, chosen_col, respondent_col) {
  
  # Extract log-likelihoods
  ll_null <- model$logLik[1]  # Null model (equal probabilities)
  ll_full <- model$logLik[2]  # Full model
  
  # McFadden's pseudo R-squared
  mcfadden_r2 <- 1 - (ll_full / ll_null)
  
  # Calculate hit rate (prediction accuracy)
  fitted_probs <- fitted(model, outcome = FALSE)
  
  # Get predicted choice for each choice set
  choice_sets <- unique(df[[choice_set_col]])
  correct <- 0
  
  for (cs in choice_sets) {
    cs_idx <- which(df[[choice_set_col]] == cs)
    cs_probs <- fitted_probs[cs_idx]
    
    predicted <- which.max(cs_probs)
    actual <- which(df[[chosen_col]][cs_idx] == 1)
    
    if (length(actual) > 0 && predicted == actual[1]) {
      correct <- correct + 1
    }
  }
  
  hit_rate <- correct / length(choice_sets)
  
  list(
    mcfadden_r2 = as.numeric(mcfadden_r2),
    hit_rate = hit_rate,
    log_likelihood = as.numeric(ll_full),
    aic = AIC(model),
    bic = BIC(model),
    n_obs = nrow(df),
    n_choice_sets = length(choice_sets),
    n_respondents = length(unique(df[[respondent_col]])),
    engine = "mlogit"
  )
}


# ------------------------------------------------------------------------------
# FILE: 06_simulator.R - Market Simulator Generation
# ------------------------------------------------------------------------------

#' Generate Market Simulator Sheet
#'
#' Creates an interactive Excel sheet for market simulation.
#'
#' @param wb openxlsx workbook object
#' @param utilities Utilities data frame
#' @param config Configuration list
#' @keywords internal
create_simulator_sheet <- function(wb, utilities, config) {
  
  sheet_name <- "Market Simulator"
  openxlsx::addWorksheet(wb, sheet_name)
  
  # Get attributes and levels
  attributes <- config$attributes
  n_attrs <- nrow(attributes)
  
  # Layout constants
  start_row <- 6
  max_products <- 10
  
  # --- Header Section ---
  openxlsx::writeData(wb, sheet_name, "MARKET SIMULATOR", startRow = 1, startCol = 1)
  openxlsx::writeData(wb, sheet_name, 
                      paste("Study:", config$settings$study_name %||% "Conjoint Analysis"),
                      startRow = 2, startCol = 1)
  
  # --- Column Headers ---
  headers <- c("Product", attributes$AttributeName, "Total Utility", "Exp(Utility)", "Market Share")
  openxlsx::writeData(wb, sheet_name, t(headers), startRow = start_row, startCol = 1, colNames = FALSE)
  
  # Apply header formatting
  header_style <- openxlsx::createStyle(
    fontSize = 11, fontColour = "#FFFFFF", fgFill = "#1F4E79",
    halign = "center", valign = "center", textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, sheet_name, header_style, 
                     rows = start_row, cols = 1:(n_attrs + 4), gridExpand = TRUE)
  
  # --- Product Rows ---
  for (i in 1:max_products) {
    row <- start_row + i
    
    # Product number
    openxlsx::writeData(wb, sheet_name, i, startRow = row, startCol = 1)
    
    # Attribute dropdowns (columns 2 to n_attrs+1)
    for (j in seq_len(n_attrs)) {
      col <- j + 1
      attr_name <- attributes$AttributeName[j]
      levels <- attributes$levels_list[[j]]
      
      # Create data validation dropdown
      openxlsx::dataValidation(wb, sheet_name,
                               rows = row, cols = col, type = "list",
                               value = paste0('"', paste(levels, collapse = ","), '"'))
      
      # Set default value to first level
      openxlsx::writeData(wb, sheet_name, levels[1], startRow = row, startCol = col)
    }
    
    # Utility calculation column
    util_col <- n_attrs + 2
    # Formula: Sum of VLOOKUP for each attribute
    # This will need to reference the utility lookup table
    util_formula <- create_utility_formula(row, n_attrs, start_row)
    openxlsx::writeFormula(wb, sheet_name, util_formula, startRow = row, startCol = util_col)
    
    # Exp(Utility) column
    exp_col <- n_attrs + 3
    exp_formula <- sprintf("EXP(%s%d)", LETTERS[util_col], row)
    openxlsx::writeFormula(wb, sheet_name, exp_formula, startRow = row, startCol = exp_col)
    
    # Market Share column
    share_col <- n_attrs + 4
    exp_range <- sprintf("%s%d:%s%d", LETTERS[exp_col], start_row + 1, 
                         LETTERS[exp_col], start_row + max_products)
    share_formula <- sprintf("IF(SUM(%s)>0, %s%d/SUM(%s), 0)", 
                             exp_range, LETTERS[exp_col], row, exp_range)
    openxlsx::writeFormula(wb, sheet_name, share_formula, startRow = row, startCol = share_col)
  }
  
  # Format share column as percentage
  pct_style <- openxlsx::createStyle(numFmt = "0.0%")
  openxlsx::addStyle(wb, sheet_name, pct_style,
                     rows = (start_row + 1):(start_row + max_products),
                     cols = n_attrs + 4, gridExpand = TRUE)
  
  # --- Utility Lookup Table ---
  lookup_start_row <- start_row + max_products + 3
  openxlsx::writeData(wb, sheet_name, "UTILITY REFERENCE", 
                      startRow = lookup_start_row, startCol = 1)
  
  # Write utilities table
  openxlsx::writeData(wb, sheet_name, utilities, 
                      startRow = lookup_start_row + 1, startCol = 1)
  
  # Format lookup table header
  openxlsx::addStyle(wb, sheet_name, header_style,
                     rows = lookup_start_row + 1, cols = 1:3, gridExpand = TRUE)
  
  # Set column widths
  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 12)
  openxlsx::setColWidths(wb, sheet_name, cols = 2:(n_attrs + 1), widths = 15)
  openxlsx::setColWidths(wb, sheet_name, cols = (n_attrs + 2):(n_attrs + 4), widths = 14)
  
  invisible(wb)
}


#' Create Utility Lookup Formula
#'
#' Generates Excel formula to sum utilities for selected levels.
#'
#' @keywords internal
create_utility_formula <- function(row, n_attrs, header_row) {
  # This creates a SUMPRODUCT formula that looks up each selected level
  # in the utility reference table
  
  # Simplified approach: reference named ranges or fixed positions
  # Full implementation would use VLOOKUP or INDEX/MATCH for each attribute
  
  # Placeholder - actual implementation depends on utility table location
  parts <- sapply(1:n_attrs, function(j) {
    col_letter <- LETTERS[j + 1]
    sprintf('VLOOKUP(%s%d,UtilityTable,3,FALSE)', col_letter, row)
  })
  
  paste0("=", paste(parts, collapse = "+"))
}


#' @keywords internal
`%||%` <- function(x, y) if (is.null(x)) y else x


# ------------------------------------------------------------------------------
# TESTING CODE - Run this to validate the implementation
# ------------------------------------------------------------------------------

test_implementation <- function() {
  
  cat("=== TURAS CONJOINT MODULE TEST ===\n\n")
  
  # Test 1: Alchemer Import
  cat("Test 1: Alchemer Import\n")
  tryCatch({
    df <- import_alchemer_conjoint("DE_noodle_conjoint_raw.xlsx")
    cat(sprintf("  ✓ Loaded %d rows, %d respondents, %d choice sets\n",
                nrow(df),
                length(unique(df$resp_id)),
                length(unique(df$choice_set_id))))
    cat(sprintf("  ✓ Attributes: %s\n", 
                paste(setdiff(names(df), c("resp_id", "choice_set_id", "alternative_id", "chosen")),
                      collapse = ", ")))
  }, error = function(e) {
    cat(sprintf("  ✗ Error: %s\n", e$message))
  })
  
  # Test 2: mlogit estimation (if data loaded)
  cat("\nTest 2: mlogit Estimation\n")
  # ... additional test code
  
  cat("\n=== TEST COMPLETE ===\n")
}
