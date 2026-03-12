# ==============================================================================
# CONJOINT OUTPUT WRITER - ENHANCED
# ==============================================================================
#
# Module: Conjoint Analysis - Excel Output
# Purpose: Create formatted Excel workbook with comprehensive results
# Version: 3.0.0
# Date: 2026-03-10
#
# Output Structure (8 core sheets + HB-specific sheets):
#   1. Market Simulator    - Interactive what-if analysis tool
#   2. Attribute Importance - Ranked importance scores
#   3. Part-Worth Utilities - Zero-centered utilities by level
#   4. Utility Chart Data   - Pre-formatted data for Excel charts
#   5. Model Fit           - Diagnostic statistics and quality metrics
#   6. Configuration       - Study design summary
#   7. Raw Coefficients    - Uncentered model coefficients with std errors
#   8. Data Summary        - Response counts, completion rates
#
# HB-specific sheets (when estimation_method = "hb"):
#   9. Individual Utilities - Per-respondent part-worth utilities
#  10. HB Diagnostics      - MCMC convergence metrics (Geweke, ESS)
#  11. Respondent Quality   - RLH scores and quality flags
#
# ==============================================================================

#' Write Conjoint Results to Excel
#'
#' Creates formatted Excel workbook with 8-sheet structure per specification
#'
#' @param utilities Utilities data frame
#' @param importance Importance data frame
#' @param diagnostics Diagnostics list
#' @param model_result Model estimation results
#' @param config Configuration
#' @param data_info Data information list
#' @param output_file Output file path
#' @param run_result TRS run result (optional, for Run_Status sheet)
#' @keywords internal
write_conjoint_output <- function(utilities, importance, diagnostics, model_result,
                                  config, data_info, output_file, run_result = NULL) {

  wb <- openxlsx::createWorkbook()

  # Create styles
  header_style <- create_header_style()
  title_style <- create_title_style()
  positive_style <- create_positive_style()
  negative_style <- create_negative_style()

  # Sheet 1: Market Simulator (ALWAYS generated - primary deliverable)
  create_market_simulator_sheet(wb, utilities, importance, config, header_style)
  create_simulator_data_sheet(wb, utilities, importance, header_style)

  # Sheet 2: Attribute Importance
  create_importance_sheet(wb, importance, header_style, positive_style)

  # Sheet 3: Part-Worth Utilities
  create_utilities_sheet(wb, utilities, header_style, positive_style, negative_style)

  # Sheet 4: Utility Chart Data
  create_utility_chart_data_sheet(wb, utilities, importance, header_style)

  # Sheet 5: Model Fit
  create_model_fit_sheet(wb, diagnostics, model_result, header_style)

  # Sheet 6: Configuration
  create_configuration_sheet(wb, config, header_style)

  # Sheet 7: Raw Coefficients
  create_raw_coefficients_sheet(wb, model_result, header_style)

  # Sheet 8: Data Summary
  create_data_summary_sheet(wb, data_info, config, header_style)

  # HB-specific sheets (conditionally added when HB or LC estimation was used)
  if (!is.null(model_result$method) &&
      model_result$method %in% c("hierarchical_bayes", "latent_class")) {
    # Sheet 9: Individual Utilities
    create_individual_utilities_sheet(wb, model_result, config, header_style)

    # Sheet 10: HB Diagnostics
    create_hb_diagnostics_sheet(wb, model_result, header_style)

    # Sheet 11: Respondent Quality
    create_respondent_quality_sheet(wb, model_result, header_style)
  }

  # LC-specific sheets (conditionally added when latent class was used)
  if (!is.null(model_result$method) && model_result$method == "latent_class" &&
      !is.null(model_result$latent_class)) {
    # Sheet 12: Class Comparison
    create_class_comparison_sheet(wb, model_result, header_style)

    # Sheet 13: Class Profiles
    create_class_profiles_sheet(wb, model_result, config, header_style)

    # Sheet 14: Class Membership
    create_class_membership_sheet(wb, model_result, header_style)
  }

  # TRS Run_Status (if run_result provided)
  if (!is.null(run_result)) {
    tryCatch({
      if (!exists("turas_write_run_status_sheet", mode = "function")) {
        # Try to source the writer
        possible_paths <- c(
          file.path(getwd(), "modules", "shared", "lib", "trs_run_status_writer.R"),
          file.path(dirname(getwd()), "shared", "lib", "trs_run_status_writer.R")
        )
        for (p in possible_paths) {
          if (file.exists(p)) {
            source(p)
            break
          }
        }
      }
      if (exists("turas_write_run_status_sheet", mode = "function")) {
        turas_write_run_status_sheet(wb, run_result)
      }
    }, error = function(e) {
      message(sprintf("[TRS INFO] CONJ_RUN_STATUS_WRITE_FAILED: Could not write Run_Status sheet: %s", e$message))
    })
  }

  # Ensure output directory exists
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Save workbook (TRS v1.0: Use atomic save if available)
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_file, run_result = run_result, module = "CONJ")
    if (!save_result$success) {
      conjoint_refuse(
        code = "IO_OUTPUT_SAVE_FAILED",
        title = "Failed to Save Excel Output",
        problem = sprintf("Failed to save Excel file: %s", save_result$error),
        why_it_matters = "Results cannot be delivered if the output file cannot be saved.",
        how_to_fix = c(
          "Check that the file is not open in Excel",
          "Verify the directory is writable",
          "Ensure sufficient disk space is available"
        ),
        details = sprintf("Attempted path: %s", output_file)
      )
    }
  } else {
    # Fallback to direct save
    tryCatch({
      openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
    }, error = function(e) {
      conjoint_refuse(
        code = "IO_OUTPUT_SAVE_FAILED_DIRECT",
        title = "Failed to Save Excel Output",
        problem = sprintf("Failed to save Excel file: %s", conditionMessage(e)),
        why_it_matters = "Results cannot be delivered if the output file cannot be saved.",
        how_to_fix = c(
          "Check that the file is not open in Excel",
          "Verify the directory is writable",
          "Ensure sufficient disk space is available"
        ),
        details = sprintf("Attempted path: %s", output_file)
      )
    })
  }
}


# ==============================================================================
# NEW SHEET FUNCTIONS FOR 8-SHEET SPECIFICATION
# ==============================================================================

#' Create Utility Chart Data Sheet
#'
#' Pre-formatted data for easy Excel charting
#'
#' @keywords internal
create_utility_chart_data_sheet <- function(wb, utilities, importance, header_style) {

  openxlsx::addWorksheet(wb, "Utility Chart Data", tabColour = "#9DC3E6")
  row <- 1

  # Section 1: Importance Chart Data
  openxlsx::writeData(wb, "Utility Chart Data", "ATTRIBUTE IMPORTANCE (for bar chart)",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Utility Chart Data", header_style, rows = row, cols = 1:2)
  row <- row + 1

  # Sort by importance
  imp_sorted <- importance[order(-importance$Importance), ]
  imp_chart <- data.frame(
    Attribute = imp_sorted$Attribute,
    Importance = imp_sorted$Importance,
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Utility Chart Data", imp_chart, startRow = row, startCol = 1,
                     headerStyle = header_style)
  row <- row + nrow(imp_chart) + 3

  # Section 2: Utilities by Attribute (for grouped bar charts)
  openxlsx::writeData(wb, "Utility Chart Data", "UTILITIES BY ATTRIBUTE (for grouped bar charts)",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Utility Chart Data", header_style, rows = row, cols = 1:3)
  row <- row + 1

  # Create wide format for each attribute
  for (attr in unique(utilities$Attribute)) {
    attr_utils <- utilities[utilities$Attribute == attr, c("Level", "Utility")]
    attr_utils <- attr_utils[order(-attr_utils$Utility), ]

    openxlsx::writeData(wb, "Utility Chart Data", attr, startRow = row, startCol = 1)
    openxlsx::addStyle(wb, "Utility Chart Data",
                      openxlsx::createStyle(textDecoration = "bold"),
                      rows = row, cols = 1)
    row <- row + 1

    openxlsx::writeData(wb, "Utility Chart Data", attr_utils, startRow = row, startCol = 1,
                       headerStyle = header_style)
    row <- row + nrow(attr_utils) + 2
  }

  # Section 3: All utilities in long format (for pivot charts)
  openxlsx::writeData(wb, "Utility Chart Data", "ALL UTILITIES - LONG FORMAT (for pivot charts)",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Utility Chart Data", header_style, rows = row, cols = 1:3)
  row <- row + 1

  chart_data <- utilities[, c("Attribute", "Level", "Utility")]
  openxlsx::writeData(wb, "Utility Chart Data", chart_data, startRow = row, startCol = 1,
                     headerStyle = header_style)

  # Apply number formatting
  num_style <- openxlsx::createStyle(numFmt = "0.000")
  openxlsx::addStyle(wb, "Utility Chart Data", num_style,
                    rows = (row + 1):(row + nrow(chart_data)),
                    cols = 3, gridExpand = TRUE)

  # Set column widths
  openxlsx::setColWidths(wb, "Utility Chart Data", cols = 1:3, widths = c(20, 20, 15))

  # Freeze top row
  openxlsx::freezePane(wb, "Utility Chart Data", firstRow = TRUE)
}


#' Create Model Fit Sheet (replaces Model Diagnostics)
#'
#' Comprehensive fit statistics and quality metrics
#'
#' @keywords internal
create_model_fit_sheet <- function(wb, diagnostics, model_result, header_style) {

  openxlsx::addWorksheet(wb, "Model Fit", tabColour = "#70AD47")
  row <- 1

  # Section 1: Model Fit Statistics
  openxlsx::writeData(wb, "Model Fit", "MODEL FIT STATISTICS",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Model Fit", header_style, rows = row, cols = 1:2)
  row <- row + 1

  if (!is.null(diagnostics$fit_statistics)) {
    fit_stats <- data.frame(
      Metric = c("McFadden R²", "Hit Rate", "Log-Likelihood", "AIC", "BIC"),
      Value = c(
        sprintf("%.4f", diagnostics$fit_statistics$mcfadden_r2 %||% NA),
        sprintf("%.1f%%", (diagnostics$fit_statistics$hit_rate %||% 0) * 100),
        sprintf("%.2f", diagnostics$fit_statistics$log_likelihood %||% NA),
        sprintf("%.2f", diagnostics$fit_statistics$aic %||% NA),
        sprintf("%.2f", diagnostics$fit_statistics$bic %||% NA)
      ),
      Interpretation = c(
        "0.2-0.4 is considered good for choice models",
        "% correctly predicted choices (random = 33% for 3 alternatives)",
        "Higher (less negative) is better",
        "Lower is better (penalizes complexity)",
        "Lower is better (stronger complexity penalty)"
      ),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Model Fit", fit_stats, startRow = row, startCol = 1,
                       headerStyle = header_style)
    row <- row + nrow(fit_stats) + 2
  }

  # Section 2: Sample Information
  openxlsx::writeData(wb, "Model Fit", "SAMPLE INFORMATION",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Model Fit", header_style, rows = row, cols = 1:2)
  row <- row + 1

  sample_info <- data.frame(
    Metric = c("Total Observations", "Estimation Method", "Converged"),
    Value = c(
      as.character(model_result$n_obs %||% "N/A"),
      model_result$method %||% "N/A",
      if (!is.null(model_result$convergence$converged))
        ifelse(model_result$convergence$converged, "Yes", "No") else "N/A"
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Model Fit", sample_info, startRow = row, startCol = 1,
                     headerStyle = header_style)
  row <- row + nrow(sample_info) + 2

  # Section 3: Quality Assessment
  if (!is.null(diagnostics$quality_assessment)) {
    openxlsx::writeData(wb, "Model Fit", "QUALITY ASSESSMENT",
                       startRow = row, startCol = 1)
    openxlsx::addStyle(wb, "Model Fit", header_style, rows = row, cols = 1:2)
    row <- row + 1

    qa <- diagnostics$quality_assessment
    quality_df <- data.frame(
      Item = c("Quality Level", "Recommendation"),
      Value = c(qa$level %||% "N/A", qa$recommendation %||% "N/A"),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Model Fit", quality_df, startRow = row, startCol = 1,
                       headerStyle = header_style)
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Model Fit", cols = 1:3, widths = c(25, 20, 50))
}


#' Create Raw Coefficients Sheet
#'
#' Uncentered model coefficients with standard errors
#'
#' @keywords internal
create_raw_coefficients_sheet <- function(wb, model_result, header_style) {

  openxlsx::addWorksheet(wb, "Raw Coefficients", tabColour = "#BF8F00")
  row <- 1

  # Title
  openxlsx::writeData(wb, "Raw Coefficients", "RAW MODEL COEFFICIENTS",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Raw Coefficients", header_style, rows = row, cols = 1:5)
  row <- row + 2

  # Build coefficients table
  coefs <- model_result$coefficients
  std_errors <- model_result$std_errors

  if (!is.null(coefs) && length(coefs) > 0) {
    # Calculate z-values and p-values
    z_values <- coefs / std_errors
    p_values <- 2 * (1 - pnorm(abs(z_values)))

    # Create data frame
    coef_df <- data.frame(
      Coefficient = names(coefs),
      Estimate = coefs,
      Std_Error = std_errors,
      z_value = z_values,
      p_value = p_values,
      Significance = ifelse(p_values < 0.001, "***",
                     ifelse(p_values < 0.01, "**",
                     ifelse(p_values < 0.05, "*",
                     ifelse(p_values < 0.1, ".", "")))),
      stringsAsFactors = FALSE,
      row.names = NULL
    )

    # Write data
    openxlsx::writeData(wb, "Raw Coefficients", coef_df, startRow = row, startCol = 1,
                       headerStyle = header_style)

    # Apply number formatting
    num_style <- openxlsx::createStyle(numFmt = "0.0000")
    openxlsx::addStyle(wb, "Raw Coefficients", num_style,
                      rows = (row + 1):(row + nrow(coef_df)),
                      cols = 2:5, gridExpand = TRUE)

    row <- row + nrow(coef_df) + 2
  } else {
    openxlsx::writeData(wb, "Raw Coefficients", "No coefficients available",
                       startRow = row, startCol = 1)
    row <- row + 2
  }

  # Add legend
  openxlsx::writeData(wb, "Raw Coefficients", "Significance codes:",
                     startRow = row, startCol = 1)
  row <- row + 1
  openxlsx::writeData(wb, "Raw Coefficients",
                     "*** p < 0.001, ** p < 0.01, * p < 0.05, . p < 0.1",
                     startRow = row, startCol = 1)

  # Add note about zero-centering
  row <- row + 2
  openxlsx::writeData(wb, "Raw Coefficients",
                     "NOTE: These are uncentered coefficients from the model.",
                     startRow = row, startCol = 1)
  row <- row + 1
  openxlsx::writeData(wb, "Raw Coefficients",
                     "See 'Part-Worth Utilities' sheet for zero-centered utilities.",
                     startRow = row, startCol = 1)

  note_style <- openxlsx::createStyle(fontColour = "#666666", textDecoration = "italic")
  openxlsx::addStyle(wb, "Raw Coefficients", note_style, rows = (row-1):row, cols = 1)

  # Set column widths
  openxlsx::setColWidths(wb, "Raw Coefficients", cols = 1:6, widths = c(30, 12, 12, 10, 12, 12))

  # Freeze top row
  openxlsx::freezePane(wb, "Raw Coefficients", firstRow = TRUE)
}


#' Create Importance Sheet
#' @keywords internal
create_importance_sheet <- function(wb, importance, header_style, positive_style) {

  openxlsx::addWorksheet(wb, "Attribute Importance")

  # Write data
  openxlsx::writeData(wb, "Attribute Importance", importance, startRow = 1)

  # Apply styles
  openxlsx::addStyle(wb, "Attribute Importance", header_style, rows = 1,
                    cols = 1:ncol(importance), gridExpand = TRUE)

  # Set column widths
  openxlsx::setColWidths(wb, "Attribute Importance", cols = 1:ncol(importance),
                        widths = "auto")

  # Freeze top row
  openxlsx::freezePane(wb, "Attribute Importance", firstRow = TRUE)
}


#' Create Utilities Sheet
#' @keywords internal
create_utilities_sheet <- function(wb, utilities, header_style,
                                  positive_style, negative_style) {

  openxlsx::addWorksheet(wb, "Part-Worth Utilities")

  # Write data
  openxlsx::writeData(wb, "Part-Worth Utilities", utilities, startRow = 1)

  # Apply header style
  openxlsx::addStyle(wb, "Part-Worth Utilities", header_style, rows = 1,
                    cols = 1:ncol(utilities), gridExpand = TRUE)

  # Apply conditional formatting to utilities column
  utility_col <- which(names(utilities) == "Utility")
  if (length(utility_col) > 0) {
    # Positive utilities
    for (i in 2:nrow(utilities)+1) {
      if (utilities$Utility[i-1] > 0) {
        openxlsx::addStyle(wb, "Part-Worth Utilities", positive_style,
                          rows = i, cols = utility_col)
      } else if (utilities$Utility[i-1] < 0) {
        openxlsx::addStyle(wb, "Part-Worth Utilities", negative_style,
                          rows = i, cols = utility_col)
      }
    }
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Part-Worth Utilities", cols = 1:ncol(utilities),
                        widths = "auto")

  # Freeze top row
  openxlsx::freezePane(wb, "Part-Worth Utilities", firstRow = TRUE)
}


# NOTE: create_diagnostics_sheet removed in v2.1.0, replaced by create_model_fit_sheet


#' Create Data Summary Sheet
#' @keywords internal
create_data_summary_sheet <- function(wb, data_info, config, header_style) {

  openxlsx::addWorksheet(wb, "Data Summary")
  row <- 1

  # Sample statistics
  openxlsx::writeData(wb, "Data Summary", "SAMPLE STATISTICS",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Data Summary", header_style, rows = row, cols = 1:2)
  row <- row + 1

  sample_stats <- data.frame(
    Metric = c("Respondents", "Choice Sets", "Total Observations",
               "Has None Option"),
    Value = c(
      data_info$n_respondents,
      data_info$n_choice_sets,
      data_info$n_profiles,
      data_info$has_none
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Data Summary", sample_stats,
                     startRow = row, startCol = 1)
  row <- row + nrow(sample_stats) + 2

  # Validation summary
  if (!is.null(data_info$validation)) {
    openxlsx::writeData(wb, "Data Summary", "VALIDATION SUMMARY",
                       startRow = row, startCol = 1)
    openxlsx::addStyle(wb, "Data Summary", header_style, rows = row, cols = 1:2)
    row <- row + 1

    val_summary <- data.frame(
      Item = c("Critical Errors", "Warnings", "Info Messages"),
      Count = c(
        length(data_info$validation$errors),
        length(data_info$validation$warnings),
        length(data_info$validation$info)
      ),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Data Summary", val_summary,
                       startRow = row, startCol = 1)
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Data Summary", cols = 1:2, widths = "auto")
}


#' Create Configuration Sheet
#' @keywords internal
create_configuration_sheet <- function(wb, config, header_style) {

  openxlsx::addWorksheet(wb, "Configuration")

  config_summary <- data.frame(
    Attribute = config$attributes$AttributeName,
    NumLevels = config$attributes$NumLevels,
    Levels = config$attributes$LevelNames,
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Configuration", config_summary, startRow = 1)
  openxlsx::addStyle(wb, "Configuration", header_style, rows = 1,
                    cols = 1:ncol(config_summary), gridExpand = TRUE)

  openxlsx::setColWidths(wb, "Configuration", cols = 1:ncol(config_summary),
                        widths = "auto")

  # Freeze top row
  openxlsx::freezePane(wb, "Configuration", firstRow = TRUE)
}


# ==============================================================================
# HB-SPECIFIC SHEET FUNCTIONS
# ==============================================================================

#' Create Individual Utilities Sheet
#'
#' Per-respondent part-worth utilities from HB estimation. Each row is a
#' respondent, each column pair is an attribute level's utility and its
#' posterior standard deviation.
#'
#' @param wb openxlsx workbook
#' @param model_result HB model result (turas_conjoint_model)
#' @param config Configuration object
#' @param header_style Header cell style
#' @keywords internal
create_individual_utilities_sheet <- function(wb, model_result, config, header_style) {

  openxlsx::addWorksheet(wb, "Individual Utilities", tabColour = "#7030A0")
  row <- 1

  # Title
  openxlsx::writeData(wb, "Individual Utilities",
                     "INDIVIDUAL-LEVEL PART-WORTH UTILITIES (Hierarchical Bayes)",
                     startRow = row, startCol = 1)
  title_style <- openxlsx::createStyle(
    fontName = "Arial", fontSize = 12, textDecoration = "bold",
    fontColour = "#323367"
  )
  openxlsx::addStyle(wb, "Individual Utilities", title_style, rows = row, cols = 1)
  row <- row + 1

  openxlsx::writeData(wb, "Individual Utilities",
                     sprintf("Estimation: %d iterations, %d burn-in, thin=%d | %d respondents",
                             model_result$hb_settings$iterations,
                             model_result$hb_settings$burnin,
                             model_result$hb_settings$thin,
                             model_result$n_respondents),
                     startRow = row, startCol = 1)
  subtitle_style <- openxlsx::createStyle(
    fontName = "Arial", fontSize = 10, fontColour = "#666666",
    textDecoration = "italic"
  )
  openxlsx::addStyle(wb, "Individual Utilities", subtitle_style, rows = row, cols = 1)
  row <- row + 2

  # Build per-respondent utility table
  individual_betas <- model_result$individual_betas
  respondent_ids <- model_result$respondent_ids
  col_names <- model_result$col_names
  attribute_map <- model_result$attribute_map

  # Create readable column names from attribute_map
  readable_cols <- character(length(col_names))
  for (k in seq_along(col_names)) {
    cn <- col_names[k]
    if (!is.null(attribute_map[[cn]])) {
      readable_cols[k] <- paste0(attribute_map[[cn]]$attribute, ": ", attribute_map[[cn]]$level)
    } else {
      readable_cols[k] <- cn
    }
  }

  # Build data frame: Respondent ID + individual utilities
  indiv_df <- data.frame(
    Respondent = respondent_ids,
    stringsAsFactors = FALSE
  )

  for (k in seq_along(col_names)) {
    indiv_df[[readable_cols[k]]] <- individual_betas[, k]
  }

  # Add RLH column if available
  if (!is.null(model_result$respondent_quality)) {
    indiv_df$RLH <- model_result$respondent_quality$rlh_scores
    indiv_df$Quality_Flag <- ifelse(
      model_result$respondent_quality$quality_flags,
      "FLAGGED", "OK"
    )
  }

  # Write data
  openxlsx::writeData(wb, "Individual Utilities", indiv_df,
                     startRow = row, startCol = 1, headerStyle = header_style)

  # Number formatting for utility columns
  num_style <- openxlsx::createStyle(numFmt = "0.000")
  n_util_cols <- length(col_names)
  openxlsx::addStyle(wb, "Individual Utilities", num_style,
                    rows = (row + 1):(row + nrow(indiv_df)),
                    cols = 2:(1 + n_util_cols), gridExpand = TRUE)

  # RLH formatting
  if (!is.null(model_result$respondent_quality)) {
    rlh_col <- 1 + n_util_cols + 1
    openxlsx::addStyle(wb, "Individual Utilities",
                      openxlsx::createStyle(numFmt = "0.000"),
                      rows = (row + 1):(row + nrow(indiv_df)),
                      cols = rlh_col, gridExpand = TRUE)

    # Highlight flagged respondents
    flag_col <- rlh_col + 1
    flag_style <- openxlsx::createStyle(fontColour = "#CC0000", textDecoration = "bold")
    for (r in seq_len(nrow(indiv_df))) {
      if (indiv_df$Quality_Flag[r] == "FLAGGED") {
        openxlsx::addStyle(wb, "Individual Utilities", flag_style,
                          rows = row + r, cols = flag_col)
      }
    }
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Individual Utilities",
                        cols = 1:ncol(indiv_df),
                        widths = c(15, rep(18, n_util_cols),
                                   if (!is.null(model_result$respondent_quality)) c(10, 12) else NULL))

  # Freeze header row and respondent column
  openxlsx::freezePane(wb, "Individual Utilities", firstRow = TRUE, firstCol = TRUE)
}


#' Create HB Diagnostics Sheet
#'
#' MCMC convergence diagnostics including Geweke z-scores, effective sample
#' sizes, and overall convergence assessment.
#'
#' @param wb openxlsx workbook
#' @param model_result HB model result (turas_conjoint_model)
#' @param header_style Header cell style
#' @keywords internal
create_hb_diagnostics_sheet <- function(wb, model_result, header_style) {

  openxlsx::addWorksheet(wb, "HB Diagnostics", tabColour = "#FF6600")
  row <- 1

  # Title
  openxlsx::writeData(wb, "HB Diagnostics",
                     "HIERARCHICAL BAYES CONVERGENCE DIAGNOSTICS",
                     startRow = row, startCol = 1)
  title_style <- openxlsx::createStyle(
    fontName = "Arial", fontSize = 12, textDecoration = "bold",
    fontColour = "#323367"
  )
  openxlsx::addStyle(wb, "HB Diagnostics", title_style, rows = row, cols = 1)
  row <- row + 2

  # Section 1: MCMC Settings
  openxlsx::writeData(wb, "HB Diagnostics", "MCMC SETTINGS",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "HB Diagnostics", header_style, rows = row, cols = 1:2)
  row <- row + 1

  hb_settings <- model_result$hb_settings
  settings_df <- data.frame(
    Setting = c("Total Iterations", "Burn-in", "Thinning Interval",
                "Mixture Components", "Draws Retained"),
    Value = c(
      as.character(hb_settings$iterations),
      as.character(hb_settings$burnin),
      as.character(hb_settings$thin),
      as.character(hb_settings$ncomp),
      as.character(hb_settings$n_draws_retained)
    ),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "HB Diagnostics", settings_df,
                     startRow = row, startCol = 1, headerStyle = header_style)
  row <- row + nrow(settings_df) + 2

  # Section 2: Overall Convergence Assessment
  conv <- model_result$convergence
  openxlsx::writeData(wb, "HB Diagnostics", "CONVERGENCE ASSESSMENT",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "HB Diagnostics", header_style, rows = row, cols = 1:2)
  row <- row + 1

  status_text <- if (conv$converged) "CONVERGED" else "NOT CONVERGED"
  status_colour <- if (conv$converged) "#006600" else "#CC0000"

  assess_df <- data.frame(
    Metric = c("Overall Status", "Geweke Test", "ESS Test", "Details"),
    Value = c(
      status_text,
      if (conv$geweke_pass) "PASSED" else "FAILED",
      if (conv$ess_pass) "PASSED" else "FAILED",
      conv$message
    ),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "HB Diagnostics", assess_df,
                     startRow = row, startCol = 1, headerStyle = header_style)

  # Colour the status cell
  status_style <- openxlsx::createStyle(
    fontColour = status_colour, textDecoration = "bold"
  )
  openxlsx::addStyle(wb, "HB Diagnostics", status_style, rows = row + 1, cols = 2)

  row <- row + nrow(assess_df) + 2

  # Section 3: Per-Parameter Diagnostics
  openxlsx::writeData(wb, "HB Diagnostics", "PER-PARAMETER DIAGNOSTICS",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "HB Diagnostics", header_style, rows = row, cols = 1:5)
  row <- row + 1

  param_names <- names(conv$geweke_z)
  param_df <- data.frame(
    Parameter = param_names,
    Geweke_z = conv$geweke_z,
    Geweke_Status = ifelse(abs(conv$geweke_z) < 1.96, "OK", "FAIL"),
    ESS = conv$effective_sample_size,
    ESS_Status = ifelse(conv$effective_sample_size > 100, "OK", "LOW"),
    stringsAsFactors = FALSE,
    row.names = NULL
  )

  openxlsx::writeData(wb, "HB Diagnostics", param_df,
                     startRow = row, startCol = 1, headerStyle = header_style)

  # Format numbers
  num_style_2 <- openxlsx::createStyle(numFmt = "0.00")
  num_style_0 <- openxlsx::createStyle(numFmt = "0")
  openxlsx::addStyle(wb, "HB Diagnostics", num_style_2,
                    rows = (row + 1):(row + nrow(param_df)), cols = 2, gridExpand = TRUE)
  openxlsx::addStyle(wb, "HB Diagnostics", num_style_0,
                    rows = (row + 1):(row + nrow(param_df)), cols = 4, gridExpand = TRUE)

  # Highlight failures
  fail_style <- openxlsx::createStyle(fontColour = "#CC0000", textDecoration = "bold")
  ok_style <- openxlsx::createStyle(fontColour = "#006600")
  for (r in seq_len(nrow(param_df))) {
    data_row <- row + r
    if (param_df$Geweke_Status[r] == "FAIL") {
      openxlsx::addStyle(wb, "HB Diagnostics", fail_style, rows = data_row, cols = 3)
    } else {
      openxlsx::addStyle(wb, "HB Diagnostics", ok_style, rows = data_row, cols = 3)
    }
    if (param_df$ESS_Status[r] == "LOW") {
      openxlsx::addStyle(wb, "HB Diagnostics", fail_style, rows = data_row, cols = 5)
    } else {
      openxlsx::addStyle(wb, "HB Diagnostics", ok_style, rows = data_row, cols = 5)
    }
  }

  row <- row + nrow(param_df) + 2

  # Interpretation guide
  openxlsx::writeData(wb, "HB Diagnostics", "INTERPRETATION GUIDE",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "HB Diagnostics", header_style, rows = row, cols = 1:2)
  row <- row + 1

  guide_df <- data.frame(
    Metric = c("Geweke z-score", "Effective Sample Size (ESS)"),
    Interpretation = c(
      "|z| < 1.96 indicates convergence (first 10% vs last 50% of chain are from same distribution)",
      "ESS > 100 indicates sufficient independent draws. Low ESS suggests high autocorrelation; increase iterations or thinning."
    ),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "HB Diagnostics", guide_df,
                     startRow = row, startCol = 1, headerStyle = header_style)

  # Set column widths
  openxlsx::setColWidths(wb, "HB Diagnostics", cols = 1:5, widths = c(30, 15, 15, 15, 15))

  # Freeze header row
  openxlsx::freezePane(wb, "HB Diagnostics", firstRow = TRUE)
}


#' Create Respondent Quality Sheet
#'
#' Individual respondent Root Likelihood (RLH) scores with quality flags.
#' Helps identify speeders and random clickers.
#'
#' @param wb openxlsx workbook
#' @param model_result HB model result (turas_conjoint_model)
#' @param header_style Header cell style
#' @keywords internal
create_respondent_quality_sheet <- function(wb, model_result, header_style) {

  openxlsx::addWorksheet(wb, "Respondent Quality", tabColour = "#00B050")
  row <- 1

  quality <- model_result$respondent_quality
  if (is.null(quality)) {
    openxlsx::writeData(wb, "Respondent Quality",
                       "Respondent quality data not available (requires HB estimation)",
                       startRow = 1, startCol = 1)
    return(invisible(NULL))
  }

  # Title
  openxlsx::writeData(wb, "Respondent Quality",
                     "RESPONDENT QUALITY ASSESSMENT (Root Likelihood)",
                     startRow = row, startCol = 1)
  title_style <- openxlsx::createStyle(
    fontName = "Arial", fontSize = 12, textDecoration = "bold",
    fontColour = "#323367"
  )
  openxlsx::addStyle(wb, "Respondent Quality", title_style, rows = row, cols = 1)
  row <- row + 2

  # Section 1: Summary Statistics
  openxlsx::writeData(wb, "Respondent Quality", "QUALITY SUMMARY",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Respondent Quality", header_style, rows = row, cols = 1:2)
  row <- row + 1

  n_respondents <- length(quality$rlh_scores)
  summary_df <- data.frame(
    Metric = c("Total Respondents", "Flagged (Poor Quality)", "Percent Flagged",
               "Chance RLH", "Quality Threshold", "Mean RLH", "Median RLH",
               "Min RLH", "Max RLH"),
    Value = c(
      as.character(n_respondents),
      as.character(quality$n_flagged),
      sprintf("%.1f%%", quality$n_flagged / n_respondents * 100),
      sprintf("%.3f", quality$chance_rlh),
      sprintf("%.3f", quality$quality_threshold),
      sprintf("%.3f", quality$mean_rlh),
      sprintf("%.3f", quality$median_rlh),
      sprintf("%.3f", min(quality$rlh_scores)),
      sprintf("%.3f", max(quality$rlh_scores))
    ),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Respondent Quality", summary_df,
                     startRow = row, startCol = 1, headerStyle = header_style)
  row <- row + nrow(summary_df) + 2

  # Section 2: Per-Respondent RLH Table
  openxlsx::writeData(wb, "Respondent Quality", "PER-RESPONDENT RLH SCORES",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Respondent Quality", header_style, rows = row, cols = 1:3)
  row <- row + 1

  # Sort by RLH ascending so poor respondents appear first
  resp_df <- data.frame(
    Respondent = quality$respondent_ids,
    RLH = quality$rlh_scores,
    Quality = ifelse(quality$quality_flags, "FLAGGED", "OK"),
    stringsAsFactors = FALSE
  )
  resp_df <- resp_df[order(resp_df$RLH), ]

  openxlsx::writeData(wb, "Respondent Quality", resp_df,
                     startRow = row, startCol = 1, headerStyle = header_style)

  # Number formatting for RLH
  rlh_style <- openxlsx::createStyle(numFmt = "0.000")
  openxlsx::addStyle(wb, "Respondent Quality", rlh_style,
                    rows = (row + 1):(row + nrow(resp_df)), cols = 2, gridExpand = TRUE)

  # Highlight flagged respondents
  flag_style <- openxlsx::createStyle(fontColour = "#CC0000", textDecoration = "bold")
  ok_style <- openxlsx::createStyle(fontColour = "#006600")
  for (r in seq_len(nrow(resp_df))) {
    data_row <- row + r
    if (resp_df$Quality[r] == "FLAGGED") {
      openxlsx::addStyle(wb, "Respondent Quality", flag_style, rows = data_row, cols = 3)
      # Also highlight the RLH value
      openxlsx::addStyle(wb, "Respondent Quality",
                        openxlsx::createStyle(numFmt = "0.000", fontColour = "#CC0000"),
                        rows = data_row, cols = 2)
    } else {
      openxlsx::addStyle(wb, "Respondent Quality", ok_style, rows = data_row, cols = 3)
    }
  }

  row <- row + nrow(resp_df) + 2

  # Interpretation guide
  openxlsx::writeData(wb, "Respondent Quality", "INTERPRETATION",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Respondent Quality", header_style, rows = row, cols = 1:2)
  row <- row + 1

  guide_df <- data.frame(
    Term = c("RLH (Root Likelihood)", "Chance RLH", "Quality Threshold", "FLAGGED"),
    Explanation = c(
      "Geometric mean probability of correct prediction per choice task. Higher is better.",
      sprintf("Expected RLH for random responding (1/%d alternatives = %.3f).",
              round(1 / quality$chance_rlh), quality$chance_rlh),
      sprintf("Respondents below %.3f (1.2 x chance) are flagged as potentially poor quality.",
              quality$quality_threshold),
      "Respondent's choices are near-random. Consider excluding from analysis or reviewing for data quality issues."
    ),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Respondent Quality", guide_df,
                     startRow = row, startCol = 1, headerStyle = header_style)

  # Set column widths
  openxlsx::setColWidths(wb, "Respondent Quality", cols = 1:3, widths = c(20, 12, 12))

  # Freeze header row
  openxlsx::freezePane(wb, "Respondent Quality", firstRow = TRUE)
}


# ==============================================================================
# LATENT CLASS-SPECIFIC SHEET FUNCTIONS
# ==============================================================================

#' Create Class Comparison Sheet
#'
#' BIC/AIC comparison across all K solutions tested.
#'
#' @param wb openxlsx workbook
#' @param model_result LC model result
#' @param header_style Header cell style
#' @keywords internal
create_class_comparison_sheet <- function(wb, model_result, header_style) {

  openxlsx::addWorksheet(wb, "Class Comparison", tabColour = "#4472C4")
  row <- 1
  lc <- model_result$latent_class

  # Title
  openxlsx::writeData(wb, "Class Comparison",
                     "LATENT CLASS MODEL COMPARISON",
                     startRow = row, startCol = 1)
  title_style <- openxlsx::createStyle(
    fontName = "Arial", fontSize = 12, textDecoration = "bold",
    fontColour = "#323367"
  )
  openxlsx::addStyle(wb, "Class Comparison", title_style, rows = row, cols = 1)
  row <- row + 1

  openxlsx::writeData(wb, "Class Comparison",
                     sprintf("Optimal: K=%d (selected by %s)",
                             lc$optimal_k, toupper(lc$criterion)),
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Class Comparison",
                    openxlsx::createStyle(fontColour = "#666666", textDecoration = "italic"),
                    rows = row, cols = 1)
  row <- row + 2

  # Comparison table
  comp <- lc$comparison
  display_cols <- c("K", "LogLik", "n_params", "AIC", "BIC", "Entropy_R2", "Converged")
  display_df <- comp[, display_cols[display_cols %in% names(comp)]]

  openxlsx::writeData(wb, "Class Comparison", display_df,
                     startRow = row, startCol = 1, headerStyle = header_style)

  # Number formatting
  num_cols <- which(names(display_df) %in% c("LogLik", "AIC", "BIC"))
  if (length(num_cols) > 0) {
    openxlsx::addStyle(wb, "Class Comparison",
                      openxlsx::createStyle(numFmt = "0.0"),
                      rows = (row + 1):(row + nrow(display_df)),
                      cols = num_cols, gridExpand = TRUE)
  }

  ent_col <- which(names(display_df) == "Entropy_R2")
  if (length(ent_col) > 0) {
    openxlsx::addStyle(wb, "Class Comparison",
                      openxlsx::createStyle(numFmt = "0.000"),
                      rows = (row + 1):(row + nrow(display_df)),
                      cols = ent_col, gridExpand = TRUE)
  }

  # Highlight optimal row
  optimal_row_idx <- which(display_df$K == lc$optimal_k)
  if (length(optimal_row_idx) > 0) {
    highlight_style <- openxlsx::createStyle(
      fgFill = "#E2EFDA", textDecoration = "bold"
    )
    openxlsx::addStyle(wb, "Class Comparison", highlight_style,
                      rows = row + optimal_row_idx,
                      cols = 1:ncol(display_df), gridExpand = TRUE)
  }

  row <- row + nrow(display_df) + 2

  # Interpretation
  openxlsx::writeData(wb, "Class Comparison", "INTERPRETATION",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Class Comparison", header_style, rows = row, cols = 1:2)
  row <- row + 1

  guide_df <- data.frame(
    Metric = c("BIC", "AIC", "Entropy R²", "Optimal K"),
    Interpretation = c(
      "Lower BIC is better. Preferred criterion; penalizes complexity more strongly than AIC.",
      "Lower AIC is better. Less conservative than BIC; may favour more classes.",
      "Values near 1.0 indicate clear class separation. Below 0.6 suggests fuzzy boundaries.",
      sprintf("K=%d selected by %s. Consider adjacent solutions if BIC differences are small (<10).",
              lc$optimal_k, toupper(lc$criterion))
    ),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Class Comparison", guide_df,
                     startRow = row, startCol = 1, headerStyle = header_style)

  openxlsx::setColWidths(wb, "Class Comparison", cols = 1:ncol(display_df),
                        widths = c(8, 15, 12, 12, 12, 12, 12))
  openxlsx::freezePane(wb, "Class Comparison", firstRow = TRUE)
}


#' Create Class Profiles Sheet
#'
#' Class-level utilities and importance for each discovered class.
#'
#' @param wb openxlsx workbook
#' @param model_result LC model result
#' @param config Configuration
#' @param header_style Header cell style
#' @keywords internal
create_class_profiles_sheet <- function(wb, model_result, config, header_style) {

  openxlsx::addWorksheet(wb, "Class Profiles", tabColour = "#4472C4")
  row <- 1
  lc <- model_result$latent_class

  # Title
  openxlsx::writeData(wb, "Class Profiles",
                     sprintf("LATENT CLASS PROFILES (K=%d)", lc$optimal_k),
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Class Profiles",
                    openxlsx::createStyle(fontName = "Arial", fontSize = 12,
                                         textDecoration = "bold", fontColour = "#323367"),
                    rows = row, cols = 1)
  row <- row + 2

  # Section 1: Class sizes
  openxlsx::writeData(wb, "Class Profiles", "CLASS SIZES",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Class Profiles", header_style, rows = row, cols = 1:3)
  row <- row + 1

  size_df <- data.frame(
    Class = paste0("Class ", seq_len(lc$optimal_k)),
    Size = lc$class_sizes,
    Percentage = sprintf("%.1f%%", lc$class_proportions * 100),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Class Profiles", size_df,
                     startRow = row, startCol = 1, headerStyle = header_style)
  row <- row + nrow(size_df) + 2

  # Section 2: Importance by class
  openxlsx::writeData(wb, "Class Profiles", "ATTRIBUTE IMPORTANCE BY CLASS",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Class Profiles", header_style, rows = row, cols = 1:4)
  row <- row + 1

  for (c in seq_len(lc$optimal_k)) {
    class_name <- paste0("Class_", c)
    if (!is.null(lc$class_importance[[class_name]])) {
      imp <- lc$class_importance[[class_name]]

      openxlsx::writeData(wb, "Class Profiles",
                         sprintf("Class %d (n=%d, %.1f%%)", c, lc$class_sizes[c],
                                 lc$class_proportions[c] * 100),
                         startRow = row, startCol = 1)
      openxlsx::addStyle(wb, "Class Profiles",
                        openxlsx::createStyle(textDecoration = "bold"),
                        rows = row, cols = 1)
      row <- row + 1

      openxlsx::writeData(wb, "Class Profiles", imp[, c("Attribute", "Importance")],
                         startRow = row, startCol = 1, headerStyle = header_style)

      # Number formatting
      openxlsx::addStyle(wb, "Class Profiles",
                        openxlsx::createStyle(numFmt = "0.0"),
                        rows = (row + 1):(row + nrow(imp)), cols = 2, gridExpand = TRUE)

      row <- row + nrow(imp) + 2
    }
  }

  # Section 3: Class-level utilities
  openxlsx::writeData(wb, "Class Profiles", "CLASS-LEVEL PART-WORTH UTILITIES",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Class Profiles", header_style, rows = row, cols = 1:5)
  row <- row + 1

  # Build wide-format utility table
  col_names <- model_result$col_names
  attr_map <- model_result$attribute_map

  wide_rows <- list()
  for (cn in col_names) {
    if (!is.null(attr_map[[cn]])) {
      row_data <- list(
        Attribute = attr_map[[cn]]$attribute,
        Level = attr_map[[cn]]$level
      )
      for (c in seq_len(lc$optimal_k)) {
        row_data[[paste0("Class_", c)]] <- lc$class_betas[c, cn]
      }
      wide_rows[[length(wide_rows) + 1]] <- as.data.frame(row_data, stringsAsFactors = FALSE)
    }
  }

  if (length(wide_rows) > 0) {
    utils_wide <- do.call(rbind, wide_rows)
    openxlsx::writeData(wb, "Class Profiles", utils_wide,
                       startRow = row, startCol = 1, headerStyle = header_style)

    # Number format for class columns
    class_cols <- 3:(2 + lc$optimal_k)
    openxlsx::addStyle(wb, "Class Profiles",
                      openxlsx::createStyle(numFmt = "0.000"),
                      rows = (row + 1):(row + nrow(utils_wide)),
                      cols = class_cols, gridExpand = TRUE)
  }

  openxlsx::setColWidths(wb, "Class Profiles", cols = 1:10, widths = "auto")
  openxlsx::freezePane(wb, "Class Profiles", firstRow = TRUE)
}


#' Create Class Membership Sheet
#'
#' Per-respondent class assignment and membership probabilities.
#'
#' @param wb openxlsx workbook
#' @param model_result LC model result
#' @param header_style Header cell style
#' @keywords internal
create_class_membership_sheet <- function(wb, model_result, header_style) {

  openxlsx::addWorksheet(wb, "Class Membership", tabColour = "#4472C4")
  row <- 1
  lc <- model_result$latent_class

  # Title
  openxlsx::writeData(wb, "Class Membership",
                     sprintf("CLASS MEMBERSHIP ASSIGNMENT (K=%d)", lc$optimal_k),
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Class Membership",
                    openxlsx::createStyle(fontName = "Arial", fontSize = 12,
                                         textDecoration = "bold", fontColour = "#323367"),
                    rows = row, cols = 1)
  row <- row + 1

  openxlsx::writeData(wb, "Class Membership",
                     sprintf("Entropy R² = %.3f", lc$entropy_r2),
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Class Membership",
                    openxlsx::createStyle(fontColour = "#666666", textDecoration = "italic"),
                    rows = row, cols = 1)
  row <- row + 2

  # Membership table
  membership <- lc$membership
  openxlsx::writeData(wb, "Class Membership", membership,
                     startRow = row, startCol = 1, headerStyle = header_style)

  # Number formatting for probability columns
  prob_cols <- grep("Prob$|Probability", names(membership))
  if (length(prob_cols) > 0) {
    openxlsx::addStyle(wb, "Class Membership",
                      openxlsx::createStyle(numFmt = "0.000"),
                      rows = (row + 1):(row + nrow(membership)),
                      cols = prob_cols, gridExpand = TRUE)
  }

  openxlsx::setColWidths(wb, "Class Membership", cols = 1:ncol(membership), widths = "auto")
  openxlsx::freezePane(wb, "Class Membership", firstRow = TRUE, firstCol = TRUE)
}
