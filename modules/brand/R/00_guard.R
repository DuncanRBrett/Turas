# ==============================================================================
# BRAND MODULE - GUARD LAYER (TRS v1.0)
# ==============================================================================
# Input validation and structured refusal handling for the brand module.
# Every config parameter and data column is validated here before analysis.
#
# VERSION: 1.0
#
# DEPENDENCIES:
# - modules/shared/lib/trs_refusal.R
# ==============================================================================

BRAND_GUARD_VERSION <- "1.0"

# --- Source shared TRS infrastructure ---
if (!exists("turas_refuse", mode = "function")) {
  .guard_candidates <- c(
    file.path(getwd(), "modules", "shared", "lib", "trs_refusal.R"),
    "modules/shared/lib/trs_refusal.R"
  )
  if (exists("find_turas_root", mode = "function")) {
    .guard_candidates <- c(
      file.path(find_turas_root(), "modules", "shared", "lib", "trs_refusal.R"),
      .guard_candidates
    )
  }
  for (.gp in .guard_candidates) {
    if (file.exists(.gp)) {
      source(.gp, local = FALSE)
      break
    }
  }
}


# ==============================================================================
# MODULE-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Brand module TRS refusal
#'
#' Wraps the shared \code{turas_refuse()} with the BRAND module prefix.
#' All brand module errors flow through this function.
#'
#' @param code Character. TRS error code (e.g., "CFG_MISSING_FIELD").
#' @param title Character. Brief error title.
#' @param problem Character. What went wrong.
#' @param why_it_matters Character. Why this matters.
#' @param how_to_fix Character or character vector. Steps to fix.
#' @param expected Optional. What was expected.
#' @param observed Optional. What was found.
#' @param missing Optional. What is missing.
#' @param details Optional. Additional details.
#'
#' @return A TRS refusal result (or stops execution).
#'
#' @keywords internal
brand_refuse <- function(code, title, problem, why_it_matters, how_to_fix,
                         expected = NULL, observed = NULL, missing = NULL,
                         details = NULL) {

  if (!grepl("^(CFG_|DATA_|IO_|CALC_|PKG_|BUG_)", code)) {
    code <- paste0("CFG_", code)
  }

  if (exists("turas_refuse", mode = "function")) {
    turas_refuse(code, title, problem, why_it_matters, how_to_fix,
                 expected, observed, missing, details, module = "BRAND")
  } else {
    # Fallback if TRS not loaded
    cat("\n=== TURAS BRAND ERROR ===\n")
    cat("Code:", code, "\n")
    cat("Title:", title, "\n")
    cat("Problem:", problem, "\n")
    cat("How to fix:", paste(how_to_fix, collapse = "; "), "\n")
    cat("========================\n\n")
    stop(sprintf("[BRAND %s] %s", code, problem), call. = FALSE)
  }
}


#' Brand module refusal handler wrapper
#'
#' @param expr Expression to evaluate.
#' @return The result of expr, or a TRS refusal.
#' @keywords internal
brand_with_refusal_handler <- function(expr) {
  if (exists("with_refusal_handler", mode = "function")) {
    result <- with_refusal_handler(expr, module = "BRAND")
    if (inherits(result, "turas_refusal_result")) {
      class(result) <- c("brand_refusal_result", class(result))
    }
    result
  } else {
    tryCatch(expr, error = function(e) {
      list(status = "REFUSED", code = "BUG_UNHANDLED",
           message = conditionMessage(e))
    })
  }
}


# ==============================================================================
# GUARD VALIDATION FUNCTIONS
# ==============================================================================

#' Validate brand config is well-formed
#'
#' Checks all required settings exist, types are correct, and element
#' toggles reference valid batteries in the data.
#'
#' @param config List. Loaded brand config.
#'
#' @return List with status = "PASS" or a TRS refusal.
#'
#' @keywords internal
guard_validate_brand_config <- function(config) {

  if (is.null(config)) {
    brand_refuse(
      code = "CFG_NULL",
      title = "No Configuration Provided",
      problem = "Brand config is NULL",
      why_it_matters = "Cannot run analysis without configuration",
      how_to_fix = "Load config with load_brand_config() first"
    )
  }

  # Required top-level fields
  required_fields <- c("project_name", "client_name", "focal_brand",
                        "data_file", "output_dir", "structure_file")

  for (field in required_fields) {
    val <- config[[field]]
    if (is.null(val) || (is.character(val) && trimws(val) == "")) {
      brand_refuse(
        code = "CFG_MISSING_FIELD",
        title = sprintf("Missing Required Setting: %s", field),
        problem = sprintf("Required setting '%s' is missing or empty in Brand_Config.xlsx", field),
        why_it_matters = "The brand module cannot run without this setting",
        how_to_fix = sprintf("Open Brand_Config.xlsx > Settings sheet > set '%s'", field),
        missing = field
      )
    }
  }

  # Validate study_type
  study_type <- config$study_type %||% "cross-sectional"
  if (!study_type %in% c("cross-sectional", "panel")) {
    brand_refuse(
      code = "CFG_INVALID_STUDY_TYPE",
      title = "Invalid Study Type",
      problem = sprintf("study_type = '%s' is not valid", study_type),
      why_it_matters = "Controls panel/cross-sectional data handling",
      how_to_fix = "Set study_type to 'cross-sectional' or 'panel'",
      expected = "cross-sectional or panel",
      observed = study_type
    )
  }

  # Validate focal_assignment
  focal_assignment <- config$focal_assignment %||% "balanced"
  if (!focal_assignment %in% c("balanced", "quota", "priority")) {
    brand_refuse(
      code = "CFG_INVALID_ASSIGNMENT",
      title = "Invalid Focal Assignment Method",
      problem = sprintf("focal_assignment = '%s' is not valid", focal_assignment),
      why_it_matters = "Controls how respondents are assigned to focal categories",
      how_to_fix = "Set focal_assignment to 'balanced', 'quota', or 'priority'",
      expected = "balanced, quota, or priority",
      observed = focal_assignment
    )
  }

  list(status = "PASS")
}


#' Validate categories are well-formed
#'
#' @param categories Data frame. From Categories sheet.
#' @param config List. Brand config.
#'
#' @return List with status = "PASS" or a TRS refusal.
#'
#' @keywords internal
guard_validate_categories <- function(categories, config) {

  if (is.null(categories) || nrow(categories) == 0) {
    brand_refuse(
      code = "CFG_NO_CATEGORIES",
      title = "No Categories Defined",
      problem = "The Categories sheet in Brand_Config.xlsx is empty",
      why_it_matters = "At least one category is required for brand analysis",
      how_to_fix = "Add category definitions to the Categories sheet"
    )
  }

  required_cols <- c("Category", "Type", "Timeframe_Target")
  missing_cols <- setdiff(required_cols, names(categories))
  if (length(missing_cols) > 0) {
    brand_refuse(
      code = "CFG_MISSING_CATEGORY_COLS",
      title = "Missing Category Columns",
      problem = sprintf("Categories sheet missing columns: %s",
                        paste(missing_cols, collapse = ", ")),
      why_it_matters = "These columns are required for proper analysis configuration",
      how_to_fix = sprintf("Add columns to Categories sheet: %s",
                           paste(missing_cols, collapse = ", ")),
      missing = missing_cols
    )
  }

  # Validate category types
  valid_types <- c("transaction", "durable", "service")
  invalid_types <- setdiff(unique(categories$Type), valid_types)
  if (length(invalid_types) > 0) {
    brand_refuse(
      code = "CFG_INVALID_CATEGORY_TYPE",
      title = "Invalid Category Type",
      problem = sprintf("Invalid category type(s): %s",
                        paste(invalid_types, collapse = ", ")),
      why_it_matters = "Category type controls question wording and data structure",
      how_to_fix = sprintf("Valid types are: %s", paste(valid_types, collapse = ", ")),
      expected = paste(valid_types, collapse = ", "),
      observed = paste(invalid_types, collapse = ", ")
    )
  }

  # Validate priority weights if using priority assignment
  focal_assignment <- config$focal_assignment %||% "balanced"
  if (focal_assignment == "priority") {
    if (!"Focal_Weight" %in% names(categories)) {
      brand_refuse(
        code = "CFG_MISSING_WEIGHTS",
        title = "Missing Focal Weights",
        problem = "focal_assignment = 'priority' but Focal_Weight column is missing",
        why_it_matters = "Priority routing needs weights to know how to distribute respondents",
        how_to_fix = "Add Focal_Weight column to Categories sheet (must sum to 1.0)"
      )
    }

    weights <- categories$Focal_Weight
    if (any(is.na(weights))) {
      brand_refuse(
        code = "CFG_NA_WEIGHTS",
        title = "Missing Focal Weights",
        problem = "Some categories have NA Focal_Weight values",
        why_it_matters = "All categories must have weights for priority routing",
        how_to_fix = "Set Focal_Weight for all categories (must sum to 1.0)"
      )
    }

    weight_sum <- sum(weights, na.rm = TRUE)
    if (abs(weight_sum - 1.0) > 0.01) {
      brand_refuse(
        code = "CFG_WEIGHTS_SUM",
        title = "Focal Weights Don't Sum to 1.0",
        problem = sprintf("Focal_Weight values sum to %.3f, not 1.0", weight_sum),
        why_it_matters = "Weights must sum to 1.0 for valid probability-based assignment",
        how_to_fix = "Adjust Focal_Weight values so they sum to 1.0",
        expected = "1.0",
        observed = sprintf("%.3f", weight_sum)
      )
    }
  }

  # Portfolio element requires 2+ categories
  element_portfolio <- config$element_portfolio %||% "Y"
  if (toupper(element_portfolio) == "Y" && nrow(categories) < 2) {
    brand_refuse(
      code = "CFG_PORTFOLIO_MIN_CATS",
      title = "Portfolio Requires Multiple Categories",
      problem = "element_portfolio = Y but only 1 category is defined",
      why_it_matters = "Portfolio analysis maps across categories; it needs 2+",
      how_to_fix = c("Add more categories to the Categories sheet",
                     "OR set element_portfolio = N in Settings")
    )
  }

  list(status = "PASS")
}


#' Validate brand survey structure
#'
#' @param structure List. Loaded survey structure with brands, ceps, etc.
#' @param config List. Brand config.
#'
#' @return List with status = "PASS" or a TRS refusal.
#'
#' @keywords internal
guard_validate_structure <- function(structure, config) {

  if (is.null(structure)) {
    brand_refuse(
      code = "CFG_NULL_STRUCTURE",
      title = "No Survey Structure",
      problem = "Survey structure is NULL",
      why_it_matters = "The survey structure defines what data is available",
      how_to_fix = "Load structure with load_brand_survey_structure() first"
    )
  }

  # Must have brands
  if (is.null(structure$brands) || nrow(structure$brands) == 0) {
    brand_refuse(
      code = "CFG_NO_BRANDS",
      title = "No Brands Defined",
      problem = "The Brands sheet in Survey_Structure.xlsx is empty",
      why_it_matters = "Brand definitions are required for all analytical elements",
      how_to_fix = "Add brand definitions to the Brands sheet"
    )
  }

  # Focal brand must exist in brands
  focal_brand <- config$focal_brand
  if (!is.null(focal_brand) && nrow(structure$brands) > 0) {
    if (!focal_brand %in% structure$brands$BrandCode) {
      brand_refuse(
        code = "CFG_FOCAL_BRAND_NOT_FOUND",
        title = "Focal Brand Not Found",
        problem = sprintf("focal_brand = '%s' not found in Brands sheet", focal_brand),
        why_it_matters = "The focal brand drives colour, annotations, and comparisons",
        how_to_fix = c(
          sprintf("Check that '%s' appears in the BrandCode column of the Brands sheet",
                  focal_brand),
          "OR update focal_brand in Brand_Config.xlsx Settings"
        ),
        expected = focal_brand,
        observed = paste(unique(structure$brands$BrandCode), collapse = ", ")
      )
    }
  }

  # If Mental Availability is active, must have CEPs
  element_ma <- config$element_mental_avail %||% "Y"
  if (toupper(element_ma) == "Y") {
    if (is.null(structure$ceps) || nrow(structure$ceps) == 0) {
      brand_refuse(
        code = "CFG_NO_CEPS",
        title = "No CEPs Defined",
        problem = "Mental Availability is enabled but no CEPs are defined",
        why_it_matters = "CEPs are the core input for Mental Availability analysis",
        how_to_fix = c("Add CEP definitions to the CEPs sheet in Survey_Structure.xlsx",
                       "OR set element_mental_avail = N in Brand_Config.xlsx")
      )
    }
  }

  list(status = "PASS")
}


#' Validate data columns match survey structure
#'
#' @param data Data frame. Survey data.
#' @param structure List. Survey structure.
#' @param config List. Brand config.
#'
#' @return List with status = "PASS", warnings for missing optional columns,
#'   or a TRS refusal for missing required columns.
#'
#' @keywords internal
guard_validate_data <- function(data, structure, config) {

  if (is.null(data) || nrow(data) == 0) {
    brand_refuse(
      code = "DATA_EMPTY",
      title = "No Data",
      problem = "Survey data is empty or NULL",
      why_it_matters = "Cannot run analysis without data",
      how_to_fix = "Check data_file path in Brand_Config.xlsx"
    )
  }

  warnings <- character(0)

  # Check respondent ID column for panel studies
  study_type <- config$study_type %||% "cross-sectional"
  id_col <- config$respondent_id_col %||% "Respondent_ID"
  if (study_type == "panel" && !id_col %in% names(data)) {
    brand_refuse(
      code = "DATA_NO_RESPONDENT_ID",
      title = "Missing Respondent ID Column",
      problem = sprintf("study_type = 'panel' but column '%s' not found in data", id_col),
      why_it_matters = "Panel studies need respondent IDs for longitudinal tracking",
      how_to_fix = c(
        sprintf("Add '%s' column to data file", id_col),
        "OR update respondent_id_col in Brand_Config.xlsx",
        "OR set study_type = 'cross-sectional'"
      )
    )
  }

  # Check weight column if specified
  weight_col <- config$weight_variable
  if (!is.null(weight_col) && nchar(trimws(weight_col)) > 0) {
    if (!weight_col %in% names(data)) {
      warnings <- c(warnings, sprintf(
        "Weight variable '%s' not found in data. Running unweighted.", weight_col
      ))
    }
  }

  # Check questions from structure exist in data
  if (!is.null(structure$questions)) {
    question_codes <- structure$questions$QuestionCode
    for (qcode in question_codes) {
      # Questions may map to multiple columns (e.g., BRANDAWARE_DSS_IPK,
      # BRANDAWARE_DSS_ROB). Check for prefix match.
      matching_cols <- grep(paste0("^", qcode), names(data), value = TRUE)
      if (length(matching_cols) == 0) {
        warnings <- c(warnings, sprintf(
          "Question '%s' not found in data (no columns matching '%s*')",
          qcode, qcode
        ))
      }
    }
  }

  if (length(warnings) > 0) {
    return(list(status = "PARTIAL", warnings = warnings))
  }

  list(status = "PASS")
}


# ==============================================================================
# ROLE-REGISTRY GUARD LAYER (split into 00_guard_role_map.R)
# ==============================================================================
# The role-registry guard layer (guard_validate_role_map + helpers) lives in
# modules/brand/R/00_guard_role_map.R. It is sourced alongside this file by
# 00_main.R.
# ==============================================================================

# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

# Null coalescing operator
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand guard layer loaded (v%s)", BRAND_GUARD_VERSION))
}
