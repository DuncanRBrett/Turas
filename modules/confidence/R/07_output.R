# ==============================================================================
# OUTPUT GENERATOR V1.0.0
# ==============================================================================
# Functions for generating Excel output with confidence analysis results
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# V1.0.0 - Initial release (2025-11-13)
#          - Multi-sheet Excel workbook generation
#          - Decimal separator support (period or comma)
#          - Summary, detailed results, methodology, and warnings
#          - Professional formatting with openxlsx
#
# OUTPUT STRUCTURE:
# Sheet 1: Summary - High-level overview
# Sheet 2: Study_Level - DEFF and effective sample size
# Sheet 3: Proportions_Detail - All proportion confidence intervals
# Sheet 4: Means_Detail - All mean confidence intervals
# Sheet 5: Methodology - Statistical methods documentation
# Sheet 6: Warnings - Data quality and calculation warnings
# Sheet 7: Inputs - Configuration summary
#
# DECIMAL SEPARATOR:
# - All numeric output formatted with user-specified separator (. or ,)
# - Applied at final output stage only
# - Internal calculations always use period
#
# DEPENDENCIES:
# - openxlsx (for Excel writing)
# - utils.R
# ==============================================================================

OUTPUT_VERSION <- "1.0.0"

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

if (!require("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')", call. = FALSE)
}

source_if_exists <- function(file_path) {
  if (file.exists(file_path)) {
    source(file_path)
  } else if (file.exists(file.path("R", file_path))) {
    source(file.path("R", file_path))
  } else if (file.exists(file.path("..", "R", file_path))) {
    source(file.path("..", "R", file_path))
  }
}

source_if_exists("utils.R")

# ==============================================================================
# MAIN OUTPUT FUNCTION
# ==============================================================================

#' Generate confidence analysis Excel output
#'
#' Creates comprehensive Excel workbook with all confidence analysis results.
#' Includes multiple sheets for summary, detailed results, methodology, and warnings.
#'
#' @param output_path Character. Path for output Excel file
#' @param study_level_stats Data frame. Study-level statistics (DEFF, effective n)
#' @param proportion_results List. Results from proportion analyses
#' @param mean_results List. Results from mean analyses
#' @param config List. Configuration settings
#' @param warnings Character vector. Any warnings generated during analysis
#' @param decimal_sep Character. Decimal separator ("." or ",")
#'
#' @return Logical. TRUE if successful (invisible)
#'
#' @examples
#' write_confidence_output(
#'   output_path = "output/confidence_results.xlsx",
#'   study_level_stats = study_stats,
#'   proportion_results = prop_results,
#'   mean_results = mean_results,
#'   config = config,
#'   warnings = warnings,
#'   decimal_sep = "."
#' )
#'
#' @author Confidence Module Team
#' @date 2025-11-13
#' @export
write_confidence_output <- function(output_path,
                                    study_level_stats = NULL,
                                    proportion_results = list(),
                                    mean_results = list(),
                                    config = list(),
                                    warnings = character(),
                                    decimal_sep = ".") {

  # Validate decimal separator
  if (!decimal_sep %in% c(".", ",")) {
    stop("decimal_sep must be either '.' or ','", call. = FALSE)
  }

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Sheet 1: Summary
  add_summary_sheet(wb, study_level_stats, proportion_results, mean_results,
                    config, warnings, decimal_sep)

  # Sheet 2: Study Level
  if (!is.null(study_level_stats) && nrow(study_level_stats) > 0) {
    add_study_level_sheet(wb, study_level_stats, decimal_sep)
  }

  # Sheet 3: Proportions Detail
  if (length(proportion_results) > 0) {
    add_proportions_detail_sheet(wb, proportion_results, decimal_sep)
  }

  # Sheet 4: Means Detail
  if (length(mean_results) > 0) {
    add_means_detail_sheet(wb, mean_results, decimal_sep)
  }

  # Sheet 5: Methodology
  add_methodology_sheet(wb)

  # Sheet 6: Warnings
  add_warnings_sheet(wb, warnings)

  # Sheet 7: Inputs
  add_inputs_sheet(wb, config, decimal_sep)

  # Save workbook
  tryCatch({
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
    cat(sprintf("\n✓ Output written to: %s\n", output_path))
  }, error = function(e) {
    stop(sprintf(
      "Failed to save Excel file\nPath: %s\nError: %s\n\nTroubleshooting:\n  1. Check file is not open in Excel\n  2. Verify output directory exists\n  3. Check write permissions",
      output_path,
      conditionMessage(e)
    ), call. = FALSE)
  })

  invisible(TRUE)
}


# ==============================================================================
# SHEET 1: SUMMARY
# ==============================================================================

#' Add summary sheet to workbook (internal)
#' @keywords internal
add_summary_sheet <- function(wb, study_stats, prop_results, mean_results,
                               config, warnings, decimal_sep) {

  openxlsx::addWorksheet(wb, "Summary")

  # Title
  row <- 1
  openxlsx::writeData(wb, "Summary", "TURAS CONFIDENCE ANALYSIS - SUMMARY",
                      startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Summary",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 2

  # Analysis Info
  openxlsx::writeData(wb, "Summary", "Analysis Information",
                      startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Summary",
                     style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 1

  info_df <- data.frame(
    Setting = c("Date", "Module Version", "Confidence Level", "Decimal Separator"),
    Value = c(
      format(Sys.Date(), "%Y-%m-%d"),
      OUTPUT_VERSION,
      ifelse(!is.null(config$confidence_level),
             format_decimal(config$confidence_level, decimal_sep, 2),
             "0.95"),
      decimal_sep
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Summary", info_df, startCol = 1, startRow = row,
                      colNames = TRUE, rowNames = FALSE)
  row <- row + nrow(info_df) + 2

  # Study-Level Summary
  if (!is.null(study_stats) && nrow(study_stats) > 0) {
    openxlsx::writeData(wb, "Summary", "Study-Level Statistics",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Summary",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                       rows = row, cols = 1)
    row <- row + 1

    # Format study stats with decimal separator
    study_display <- study_stats
    study_display <- format_dataframe_decimals(study_display, decimal_sep)

    openxlsx::writeData(wb, "Summary", study_display, startCol = 1, startRow = row,
                        colNames = TRUE, rowNames = FALSE)
    row <- row + nrow(study_display) + 2
  }

  # Results Summary
  openxlsx::writeData(wb, "Summary", "Results Summary",
                      startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Summary",
                     style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 1

  summary_df <- data.frame(
    Metric = c("Proportions Analyzed", "Means Analyzed", "Total Questions"),
    Count = c(
      length(prop_results),
      length(mean_results),
      length(prop_results) + length(mean_results)
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Summary", summary_df, startCol = 1, startRow = row,
                      colNames = TRUE, rowNames = FALSE)
  row <- row + nrow(summary_df) + 2

  # Warnings Summary
  if (length(warnings) > 0) {
    openxlsx::writeData(wb, "Summary", "⚠ Warnings",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Summary",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold",
                                                     fontColour = "#FF0000"),
                       rows = row, cols = 1)
    row <- row + 1

    openxlsx::writeData(wb, "Summary",
                        sprintf("%d warnings detected - see Warnings sheet for details",
                                length(warnings)),
                        startCol = 1, startRow = row)
  } else {
    openxlsx::writeData(wb, "Summary", "✓ No Warnings",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Summary",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold",
                                                     fontColour = "#008000"),
                       rows = row, cols = 1)
  }

  # Auto-size columns
  openxlsx::setColWidths(wb, "Summary", cols = 1:2, widths = "auto")
}


# ==============================================================================
# SHEET 2: STUDY LEVEL
# ==============================================================================

#' Add study-level statistics sheet (internal)
#' @keywords internal
add_study_level_sheet <- function(wb, study_stats, decimal_sep) {

  openxlsx::addWorksheet(wb, "Study_Level")

  # Title
  openxlsx::writeData(wb, "Study_Level", "STUDY-LEVEL STATISTICS",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Study_Level",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  # Format with decimal separator
  study_display <- study_stats
  study_display <- format_dataframe_decimals(study_display, decimal_sep)

  # Write data
  openxlsx::writeData(wb, "Study_Level", study_display, startCol = 1, startRow = 3,
                      colNames = TRUE, rowNames = FALSE)

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "Study_Level", header_style, rows = 3,
                     cols = 1:ncol(study_display), gridExpand = TRUE)

  # Interpretation notes
  row <- 3 + nrow(study_display) + 2
  openxlsx::writeData(wb, "Study_Level", "INTERPRETATION:", startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Study_Level",
                     style = openxlsx::createStyle(textDecoration = "bold"),
                     rows = row, cols = 1)

  row <- row + 1
  notes <- c(
    "DEFF (Design Effect):",
    "  1.00 = No loss of precision from weighting",
    "  1.05-1.20 = Modest loss (5-20%)",
    "  1.20-2.00 = Moderate loss (20-50%)",
    "  >2.00 = Substantial loss (>50%)",
    "",
    "Weight CV (Coefficient of Variation):",
    "  <0.20 = Modest variation",
    "  0.20-0.30 = Moderate variation",
    "  >0.30 = High variation"
  )

  for (note in notes) {
    openxlsx::writeData(wb, "Study_Level", note, startCol = 1, startRow = row)
    row <- row + 1
  }

  # Auto-size columns
  openxlsx::setColWidths(wb, "Study_Level", cols = 1:ncol(study_display), widths = "auto")
}


# ==============================================================================
# SHEET 3: PROPORTIONS DETAIL
# ==============================================================================

#' Add proportions detail sheet (internal)
#' @keywords internal
add_proportions_detail_sheet <- function(wb, prop_results, decimal_sep) {

  openxlsx::addWorksheet(wb, "Proportions_Detail")

  # Title
  openxlsx::writeData(wb, "Proportions_Detail", "PROPORTIONS - DETAILED RESULTS",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Proportions_Detail",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  # Convert results list to data frame
  prop_df <- build_proportions_dataframe(prop_results)

  if (nrow(prop_df) == 0) {
    openxlsx::writeData(wb, "Proportions_Detail", "No proportion analyses performed",
                        startCol = 1, startRow = 3)
    return(invisible(NULL))
  }

  # Format with decimal separator
  prop_display <- format_dataframe_decimals(prop_df, decimal_sep)

  # Write data
  openxlsx::writeData(wb, "Proportions_Detail", prop_display, startCol = 1, startRow = 3,
                      colNames = TRUE, rowNames = FALSE)

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "Proportions_Detail", header_style, rows = 3,
                     cols = 1:ncol(prop_display), gridExpand = TRUE)

  # Auto-size columns
  openxlsx::setColWidths(wb, "Proportions_Detail", cols = 1:ncol(prop_display), widths = "auto")
}


#' Build proportions dataframe from results list (internal)
#' @keywords internal
build_proportions_dataframe <- function(prop_results) {

  if (length(prop_results) == 0) {
    return(data.frame())
  }

  rows_list <- list()

  for (q_id in names(prop_results)) {
    q_result <- prop_results[[q_id]]

    # Base info
    base_row <- list(
      Question_ID = q_id,
      Category = ifelse(!is.null(q_result$category), q_result$category, "Total"),
      Proportion = ifelse(!is.null(q_result$proportion), q_result$proportion, NA),
      Sample_Size = ifelse(!is.null(q_result$n), q_result$n, NA),
      Effective_n = ifelse(!is.null(q_result$n_eff), q_result$n_eff, NA)
    )

    # MOE
    if (!is.null(q_result$moe_normal)) {
      base_row$MOE_Normal_Lower <- q_result$moe_normal$lower
      base_row$MOE_Normal_Upper <- q_result$moe_normal$upper
      base_row$MOE <- q_result$moe_normal$moe
    }

    # Wilson
    if (!is.null(q_result$wilson)) {
      base_row$Wilson_Lower <- q_result$wilson$lower
      base_row$Wilson_Upper <- q_result$wilson$upper
    }

    # Bootstrap
    if (!is.null(q_result$bootstrap)) {
      base_row$Bootstrap_Lower <- q_result$bootstrap$lower
      base_row$Bootstrap_Upper <- q_result$bootstrap$upper
    }

    # Bayesian
    if (!is.null(q_result$bayesian)) {
      base_row$Bayesian_Lower <- q_result$bayesian$lower
      base_row$Bayesian_Upper <- q_result$bayesian$upper
    }

    rows_list[[length(rows_list) + 1]] <- base_row
  }

  # Combine all rows
  df <- do.call(rbind, lapply(rows_list, function(x) as.data.frame(x, stringsAsFactors = FALSE)))

  return(df)
}


# ==============================================================================
# SHEET 4: MEANS DETAIL
# ==============================================================================

#' Add means detail sheet (internal)
#' @keywords internal
add_means_detail_sheet <- function(wb, mean_results, decimal_sep) {

  openxlsx::addWorksheet(wb, "Means_Detail")

  # Title
  openxlsx::writeData(wb, "Means_Detail", "MEANS - DETAILED RESULTS",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Means_Detail",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  # Convert results list to data frame
  mean_df <- build_means_dataframe(mean_results)

  if (nrow(mean_df) == 0) {
    openxlsx::writeData(wb, "Means_Detail", "No mean analyses performed",
                        startCol = 1, startRow = 3)
    return(invisible(NULL))
  }

  # Format with decimal separator
  mean_display <- format_dataframe_decimals(mean_df, decimal_sep)

  # Write data
  openxlsx::writeData(wb, "Means_Detail", mean_display, startCol = 1, startRow = 3,
                      colNames = TRUE, rowNames = FALSE)

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "Means_Detail", header_style, rows = 3,
                     cols = 1:ncol(mean_display), gridExpand = TRUE)

  # Auto-size columns
  openxlsx::setColWidths(wb, "Means_Detail", cols = 1:ncol(mean_display), widths = "auto")
}


#' Build means dataframe from results list (internal)
#' @keywords internal
build_means_dataframe <- function(mean_results) {

  if (length(mean_results) == 0) {
    return(data.frame())
  }

  rows_list <- list()

  for (q_id in names(mean_results)) {
    q_result <- mean_results[[q_id]]

    # Base info
    base_row <- list(
      Question_ID = q_id,
      Mean = ifelse(!is.null(q_result$mean), q_result$mean, NA),
      SD = ifelse(!is.null(q_result$sd), q_result$sd, NA),
      Sample_Size = ifelse(!is.null(q_result$n), q_result$n, NA),
      Effective_n = ifelse(!is.null(q_result$n_eff), q_result$n_eff, NA)
    )

    # t-distribution CI
    if (!is.null(q_result$t_dist)) {
      base_row$tDist_Lower <- q_result$t_dist$lower
      base_row$tDist_Upper <- q_result$t_dist$upper
      base_row$SE <- q_result$t_dist$se
      base_row$DF <- q_result$t_dist$df
    }

    # Bootstrap
    if (!is.null(q_result$bootstrap)) {
      base_row$Bootstrap_Lower <- q_result$bootstrap$lower
      base_row$Bootstrap_Upper <- q_result$bootstrap$upper
    }

    # Bayesian
    if (!is.null(q_result$bayesian)) {
      base_row$Bayesian_Lower <- q_result$bayesian$lower
      base_row$Bayesian_Upper <- q_result$bayesian$upper
      base_row$Bayesian_Mean <- q_result$bayesian$posterior_mean
    }

    rows_list[[length(rows_list) + 1]] <- base_row
  }

  # Combine all rows
  df <- do.call(rbind, lapply(rows_list, function(x) as.data.frame(x, stringsAsFactors = FALSE)))

  return(df)
}


# ==============================================================================
# SHEET 5: METHODOLOGY
# ==============================================================================

#' Add methodology documentation sheet (internal)
#' @keywords internal
add_methodology_sheet <- function(wb) {

  openxlsx::addWorksheet(wb, "Methodology")

  # Title
  openxlsx::writeData(wb, "Methodology", "STATISTICAL METHODOLOGY",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Methodology",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  row <- 3

  # Methodology content
  methodology_text <- c(
    "PROPORTIONS:",
    "",
    "1. Normal Approximation (Margin of Error)",
    "   Formula: MOE = z * sqrt(p*(1-p)/n)",
    "   Use: Large samples (n*p >= 10 and n*(1-p) >= 10)",
    "   Confidence Interval: [p - MOE, p + MOE]",
    "",
    "2. Wilson Score Interval",
    "   Better for extreme proportions (p < 0.1 or p > 0.9)",
    "   Automatically provides asymmetric intervals",
    "   Recommended for small samples or extreme proportions",
    "",
    "3. Bootstrap",
    "   Non-parametric resampling method (5000-10000 iterations)",
    "   No distributional assumptions required",
    "   Percentile method for confidence intervals",
    "",
    "4. Bayesian (Beta-Binomial)",
    "   Posterior: Beta(alpha + x, beta + n - x)",
    "   Uninformed prior: Beta(1,1) = Uniform(0,1)",
    "   Informed prior: Beta from previous wave data",
    "",
    "MEANS:",
    "",
    "1. t-Distribution",
    "   Formula: CI = mean ± t(df) * SE",
    "   SE = sd / sqrt(n_eff)",
    "   Accounts for design effect in weighted data",
    "",
    "2. Bootstrap",
    "   Resampling with replacement (5000-10000 iterations)",
    "   Preserves survey weights if applicable",
    "   Percentile method for confidence intervals",
    "",
    "3. Bayesian (Normal-Normal Conjugate)",
    "   Prior: N(mu0, sigma0²/n0)",
    "   Posterior: Precision-weighted combination of prior and data",
    "   Uninformed: very weak prior (large prior variance)",
    "   Informed: from previous wave statistics",
    "",
    "WEIGHTING:",
    "",
    "Design Effect (DEFF): DEFF = 1 + CV²",
    "  where CV = coefficient of variation of weights",
    "",
    "Effective Sample Size: n_eff = (Σw)² / Σw²",
    "  Kish (1965) approximation",
    "",
    "Standard errors use effective n for weighted data",
    "",
    "REFERENCES:",
    "",
    "Kish, L. (1965). Survey Sampling. Wiley.",
    "Agresti, A., & Coull, B. A. (1998). Approximate is better than exact.",
    "Wilson, E. B. (1927). Probable inference and statistical inference.",
    "Efron, B., & Tibshirani, R. J. (1994). An Introduction to the Bootstrap."
  )

  for (line in methodology_text) {
    openxlsx::writeData(wb, "Methodology", line, startCol = 1, startRow = row)
    row <- row + 1
  }

  # Auto-size column
  openxlsx::setColWidths(wb, "Methodology", cols = 1, widths = 80)
}


# ==============================================================================
# SHEET 6: WARNINGS
# ==============================================================================

#' Add warnings sheet (internal)
#' @keywords internal
add_warnings_sheet <- function(wb, warnings) {

  openxlsx::addWorksheet(wb, "Warnings")

  # Title
  openxlsx::writeData(wb, "Warnings", "WARNINGS AND DATA QUALITY NOTES",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Warnings",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  row <- 3

  if (length(warnings) == 0) {
    openxlsx::writeData(wb, "Warnings", "✓ No warnings detected",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Warnings",
                       style = openxlsx::createStyle(fontSize = 12, fontColour = "#008000"),
                       rows = row, cols = 1)
  } else {
    # Write warnings
    warnings_df <- data.frame(
      Number = seq_along(warnings),
      Warning = warnings,
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Warnings", warnings_df, startCol = 1, startRow = row,
                        colNames = TRUE, rowNames = FALSE)

    # Header style
    header_style <- openxlsx::createStyle(
      fontSize = 11,
      textDecoration = "bold",
      fgFill = "#FF6B6B",
      fontColour = "#FFFFFF"
    )
    openxlsx::addStyle(wb, "Warnings", header_style, rows = row,
                       cols = 1:2, gridExpand = TRUE)

    # Auto-size columns
    openxlsx::setColWidths(wb, "Warnings", cols = 1:2, widths = "auto")
  }
}


# ==============================================================================
# SHEET 7: INPUTS
# ==============================================================================

#' Add inputs/configuration sheet (internal)
#' @keywords internal
add_inputs_sheet <- function(wb, config, decimal_sep) {

  openxlsx::addWorksheet(wb, "Inputs")

  # Title
  openxlsx::writeData(wb, "Inputs", "INPUT CONFIGURATION",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Inputs",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  row <- 3

  # Study Settings
  openxlsx::writeData(wb, "Inputs", "Study Settings:", startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Inputs",
                     style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 1

  settings_df <- data.frame(
    Setting = c(
      "Confidence Level",
      "Bootstrap Iterations",
      "Multiple Comparison Adjustment",
      "Decimal Separator",
      "Calculate Effective Sample Size"
    ),
    Value = c(
      ifelse(!is.null(config$confidence_level),
             format_decimal(config$confidence_level, decimal_sep, 2), "0.95"),
      ifelse(!is.null(config$bootstrap_iterations),
             as.character(config$bootstrap_iterations), "5000"),
      ifelse(!is.null(config$multiple_comparison_method),
             config$multiple_comparison_method, "None"),
      decimal_sep,
      ifelse(!is.null(config$calculate_effective_n),
             ifelse(config$calculate_effective_n, "Yes", "No"), "Yes")
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Inputs", settings_df, startCol = 1, startRow = row,
                      colNames = TRUE, rowNames = FALSE)

  # Auto-size columns
  openxlsx::setColWidths(wb, "Inputs", cols = 1:2, widths = "auto")
}


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Format data frame numeric columns with decimal separator (internal)
#' @keywords internal
format_dataframe_decimals <- function(df, decimal_sep) {

  if (!is.data.frame(df)) {
    return(df)
  }

  # Create copy
  df_formatted <- df

  # Format each numeric column
  for (col_name in names(df_formatted)) {
    col_data <- df_formatted[[col_name]]

    if (is.numeric(col_data)) {
      # Determine appropriate decimal places
      digits <- 2

      # Use more precision for small values (SE, MOE, etc.)
      if (any(grepl("SE|MOE|CV|DEFF", col_name, ignore.case = TRUE))) {
        digits <- 3
      }

      # Format with decimal separator
      formatted_values <- sapply(col_data, function(x) {
        if (is.na(x)) {
          return(NA_character_)
        } else {
          val <- formatC(x, format = "f", digits = digits)
          if (decimal_sep == ",") {
            val <- gsub("\\.", ",", val)
          }
          return(val)
        }
      })

      df_formatted[[col_name]] <- formatted_values
    }
  }

  return(df_formatted)
}


#' Create default configuration for output (internal)
#' @keywords internal
create_default_config <- function() {
  list(
    confidence_level = 0.95,
    bootstrap_iterations = 5000,
    multiple_comparison_method = "None",
    calculate_effective_n = TRUE
  )
}
