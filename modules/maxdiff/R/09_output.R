# ==============================================================================
# MAXDIFF MODULE - EXCEL OUTPUT GENERATION - TURAS V10.0
# ==============================================================================
# Excel output generation for MaxDiff results
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# OUTPUT SHEETS:
# - SUMMARY: Project metadata and sample sizes
# - ITEM_SCORES: Main results with all scoring methods
# - SEGMENT_SCORES: Segment-level results
# - INDIVIDUAL_UTILS: Individual-level utilities (optional)
# - TURF_RESULTS: TURF incremental reach analysis (optional)
# - ANCHOR_ANALYSIS: Anchor/must-have item analysis (optional)
# - ITEM_DISCRIMINATION: Item discrimination classification (optional)
# - MODEL_DIAGNOSTICS: Model fit statistics
# - DESIGN_SUMMARY: Design statistics (if DESIGN mode)
# - Run_Status: TRS run status (if run_result provided)
#
# DEPENDENCIES:
# - openxlsx
# - utils.R
# ==============================================================================

# ---------------------------------------------------------------------------
# Formula injection protection (OWASP CSV Injection)
# Inline fallback using vapply+substr (not regex, per Phase 3 re-review R3)
# ---------------------------------------------------------------------------
maxdiff_escape_cell <- if (exists("turas_excel_escape", mode = "function")) {
  turas_excel_escape
} else {
  function(x) {
    if (!is.character(x)) return(x)
    vapply(x, function(val) {
      if (is.na(val) || nchar(val) == 0L) return(val)
      first_char <- substr(val, 1, 1)
      if (first_char %in% c("=", "+", "-", "@", "\t", "\r", "\n")) {
        paste0("'", val)
      } else {
        val
      }
    }, character(1), USE.NAMES = FALSE)
  }
}

maxdiff_escape_df <- function(df) {
  if (!is.data.frame(df)) return(df)
  nm <- names(df)
  names(df) <- maxdiff_escape_cell(nm)
  for (col in seq_along(df)) {
    if (is.character(df[[col]])) {
      df[[col]] <- maxdiff_escape_cell(df[[col]])
    }
  }
  df
}

OUTPUT_VERSION <- "11.2"

# ==============================================================================
# MAIN OUTPUT GENERATOR
# ==============================================================================

#' Generate MaxDiff Excel Output
#'
#' Creates comprehensive Excel output workbook with all results.
#'
#' @param results List. Analysis results from run_maxdiff_analysis
#' @param config List. Configuration object
#' @param verbose Logical. Print progress messages
#' @param run_result List. Optional TRS run result for Run_Status sheet
#'
#' @return Character. Path to output file
#' @export
generate_maxdiff_output <- function(results, config, verbose = TRUE, run_result = NULL) {

  if (verbose) {
    cat("\n")
    log_message("GENERATING EXCEL OUTPUT", "INFO", verbose)
    cat(paste(rep("-", 60), collapse = ""), "\n")
  }

  # Check openxlsx
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    maxdiff_refuse(
      code = "PKG_OPENXLSX_MISSING",
      title = "Required Package Not Installed",
      problem = "Package 'openxlsx' is required but not installed",
      why_it_matters = "Excel output generation depends on the openxlsx package",
      how_to_fix = "Install the openxlsx package: install.packages('openxlsx')"
    )
  }

  # Determine output path
  output_folder <- config$project_settings$Output_Folder
  project_name <- config$project_settings$Project_Name

  if (is.null(output_folder) || !nzchar(output_folder)) {
    output_folder <- config$project_root
  }

  # Create output folder if needed
  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
  }

  output_filename <- sprintf("%s_MaxDiff_Results.xlsx", project_name)
  output_path <- file.path(output_folder, output_filename)

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Define styles
  styles <- create_output_styles()

  # ============================================================================
  # SUMMARY SHEET
  # ============================================================================

  if (verbose) log_message("Writing SUMMARY sheet...", "INFO", verbose)

  write_summary_sheet(wb, results, config, styles)

  # ============================================================================
  # ITEM_SCORES SHEET
  # ============================================================================

  if (verbose) log_message("Writing ITEM_SCORES sheet...", "INFO", verbose)

  write_item_scores_sheet(wb, results, config, styles)

  # ============================================================================
  # SEGMENT_SCORES SHEET (if applicable)
  # ============================================================================

  if (!is.null(results$segment_results)) {
    if (verbose) log_message("Writing SEGMENT_SCORES sheet...", "INFO", verbose)
    write_segment_scores_sheet(wb, results, config, styles)
  }

  # ============================================================================
  # INDIVIDUAL_UTILS SHEET (if applicable)
  # ============================================================================

  if (config$output_settings$Export_Individual_Utils &&
      !is.null(results$hb_results) &&
      !is.null(results$hb_results$individual_utilities)) {
    if (verbose) log_message("Writing INDIVIDUAL_UTILS sheet...", "INFO", verbose)
    write_individual_utils_sheet(wb, results, config, styles)
  }

  # ============================================================================
  # MODEL_DIAGNOSTICS SHEET
  # ============================================================================

  if (verbose) log_message("Writing MODEL_DIAGNOSTICS sheet...", "INFO", verbose)

  write_diagnostics_sheet(wb, results, config, styles)

  # ============================================================================
  # TURF_RESULTS SHEET (if applicable)
  # ============================================================================

  if (!is.null(results$turf_results)) {
    if (verbose) log_message("Writing TURF_RESULTS sheet...", "INFO", verbose)
    write_turf_results_sheet(wb, results, config, styles)
  }

  # ============================================================================
  # ANCHOR_ANALYSIS SHEET (if applicable)
  # ============================================================================

  if (!is.null(results$anchor_data)) {
    if (verbose) log_message("Writing ANCHOR_ANALYSIS sheet...", "INFO", verbose)
    write_anchor_analysis_sheet(wb, results, config, styles)
  }

  # ============================================================================
  # ITEM_DISCRIMINATION SHEET (if applicable)
  # ============================================================================

  if (!is.null(results$discrimination_data)) {
    if (verbose) log_message("Writing ITEM_DISCRIMINATION sheet...", "INFO", verbose)
    write_item_discrimination_sheet(wb, results, config, styles)
  }

  # ============================================================================
  # DESIGN SHEET (if DESIGN mode)
  # ============================================================================

  if (config$mode == "DESIGN" && !is.null(results$design_result)) {
    if (verbose) log_message("Writing DESIGN sheets...", "INFO", verbose)
    write_design_sheets(wb, results, config, styles)
  }

  # ============================================================================
  # TRS RUN_STATUS SHEET (TRS v1.0)
  # ============================================================================

  if (!is.null(run_result)) {
    if (verbose) log_message("Writing Run_Status sheet...", "INFO", verbose)
    # Prefer shared turas writer if available, otherwise use local helper
    if (exists("turas_write_run_status_sheet", mode = "function")) {
      turas_write_run_status_sheet(wb, run_result)
    } else {
      write_run_status_sheet(wb, run_result, styles)
    }
  }

  # ============================================================================
  # SAVE WORKBOOK (TRS v1.0: Use atomic save if available)
  # ============================================================================

  if (verbose) log_message("Saving workbook...", "INFO", verbose)

  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_path, run_result = run_result, module = "MAXD")
    if (!save_result$success) {
      maxdiff_refuse(
        code = "IO_EXCEL_SAVE_FAILED",
        title = "Excel File Save Failed",
        problem = sprintf("Failed to save Excel output file: %s", save_result$error),
        why_it_matters = "Results cannot be saved to Excel file",
        how_to_fix = c(
          "Check that output folder has write permissions",
          "Ensure output file is not open in Excel",
          "Verify sufficient disk space available",
          "Check path is valid and accessible"
        ),
        details = sprintf("Path: %s\nError: %s", output_path, save_result$error)
      )
    }
  } else {
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  }

  if (verbose) {
    log_message(sprintf("Output saved: %s", output_path), "INFO", verbose)
  }

  return(output_path)
}


# ==============================================================================
# STYLE DEFINITIONS
# ==============================================================================

#' Create output styles
#' @keywords internal
create_output_styles <- function() {

  list(
    header = openxlsx::createStyle(
      fontSize = 12,
      fontColour = "white",
      fgFill = "#2c3e50",
      halign = "center",
      valign = "center",
      textDecoration = "bold",
      border = "TopBottomLeftRight",
      borderColour = "#2c3e50"
    ),

    subheader = openxlsx::createStyle(
      fontSize = 11,
      fontColour = "black",
      fgFill = "#ecf0f1",
      halign = "center",
      valign = "center",
      textDecoration = "bold"
    ),

    number_1dp = openxlsx::createStyle(
      numFmt = "0.0",
      halign = "center"
    ),

    number_2dp = openxlsx::createStyle(
      numFmt = "0.00",
      halign = "center"
    ),

    number_3dp = openxlsx::createStyle(
      numFmt = "0.000",
      halign = "center"
    ),

    percent = openxlsx::createStyle(
      numFmt = "0.0%",
      halign = "center"
    ),

    percent_1dp = openxlsx::createStyle(
      numFmt = "0.0%",
      halign = "center"
    ),

    percent_display = openxlsx::createStyle(
      numFmt = "0.0",
      halign = "center"
    ),

    score_3dp = openxlsx::createStyle(
      numFmt = "0.000",
      halign = "center"
    ),

    integer = openxlsx::createStyle(
      numFmt = "0",
      halign = "center"
    ),

    count = openxlsx::createStyle(
      numFmt = "#,##0",
      halign = "center"
    ),

    good_highlight = openxlsx::createStyle(
      fgFill = "#d5f5e3",
      fontColour = "#1e8449"
    ),

    text_left = openxlsx::createStyle(
      halign = "left",
      valign = "center"
    ),

    text_center = openxlsx::createStyle(
      halign = "center",
      valign = "center"
    ),

    positive = openxlsx::createStyle(
      fontColour = "#27ae60"
    ),

    negative = openxlsx::createStyle(
      fontColour = "#e74c3c"
    )
  )
}


# ==============================================================================
# SUMMARY SHEET
# ==============================================================================

#' Write SUMMARY sheet
#' @keywords internal
write_summary_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "SUMMARY")

  # Project Information
  project_info <- data.frame(
    Setting = c(
      "Project Name",
      "Mode",
      "Module Version",
      "Generated",
      "Seed"
    ),
    Value = c(
      config$project_settings$Project_Name,
      config$mode,
      config$project_settings$Module_Version,
      format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      as.character(config$project_settings$Seed)
    ),
    stringsAsFactors = FALSE
  )

  # Sample Information
  if (!is.null(results$study_summary)) {
    sample_info <- data.frame(
      Metric = c(
        "Total Respondents",
        "Effective N",
        "Design Effect (DEFF)",
        "Number of Items",
        "Tasks per Respondent",
        "Items per Task",
        "Weighted Analysis"
      ),
      Value = c(
        results$study_summary$n_respondents,
        round(results$study_summary$effective_n, 1),
        round(results$study_summary$design_effect, 3),
        results$study_summary$n_items,
        results$study_summary$n_tasks,
        length(grep("^Item\\d+_ID$",
                    names(results$design))),
        ifelse(results$study_summary$weighted, "Yes", "No")
      ),
      stringsAsFactors = FALSE
    )
  } else {
    sample_info <- data.frame(
      Metric = character(),
      Value = character(),
      stringsAsFactors = FALSE
    )
  }

  # Escape user-sourced text (formula injection protection)
  project_info <- maxdiff_escape_df(project_info)
  sample_info  <- maxdiff_escape_df(sample_info)

  # Write project info
  openxlsx::writeData(wb, "SUMMARY", "PROJECT INFORMATION", startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, "SUMMARY", styles$header, rows = 1, cols = 1:2, gridExpand = TRUE)
  openxlsx::writeData(wb, "SUMMARY", project_info, startRow = 2, startCol = 1,
                     colNames = TRUE, headerStyle = styles$subheader)

  # Write sample info
  start_row <- nrow(project_info) + 5
  openxlsx::writeData(wb, "SUMMARY", "SAMPLE INFORMATION", startRow = start_row, startCol = 1)
  openxlsx::addStyle(wb, "SUMMARY", styles$header, rows = start_row, cols = 1:2, gridExpand = TRUE)
  openxlsx::writeData(wb, "SUMMARY", sample_info, startRow = start_row + 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$subheader)

  # Set column widths
  openxlsx::setColWidths(wb, "SUMMARY", cols = 1:2, widths = c(25, 30))

  # Freeze header
  openxlsx::freezePane(wb, "SUMMARY", firstRow = TRUE)
}


# ==============================================================================
# ITEM_SCORES SHEET
# ==============================================================================

#' Write ITEM_SCORES sheet
#' @keywords internal
write_item_scores_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "ITEM_SCORES")

  # Start with count scores
  item_scores <- results$count_scores

  # Add logit utilities if available
  if (!is.null(results$logit_results)) {
    logit_utils <- results$logit_results$utilities[, c("Item_ID", "Logit_Utility", "Logit_SE")]
    item_scores <- merge(item_scores, logit_utils, by = "Item_ID", all.x = TRUE)
  }

  # Add HB utilities if available
  if (!is.null(results$hb_results)) {
    hb_utils <- results$hb_results$population_utilities[,
                  c("Item_ID", "HB_Utility_Mean", "HB_Utility_SD")]
    item_scores <- merge(item_scores, hb_utils, by = "Item_ID", all.x = TRUE)
  }

  # Add rescaled scores
  rescale_method <- config$output_settings$Score_Rescale_Method

  if ("HB_Utility_Mean" %in% names(item_scores)) {
    item_scores$Rescaled_Score <- rescale_utilities(
      item_scores$HB_Utility_Mean, rescale_method
    )
  } else if ("Logit_Utility" %in% names(item_scores)) {
    item_scores$Rescaled_Score <- rescale_utilities(
      item_scores$Logit_Utility, rescale_method
    )
  } else {
    item_scores$Rescaled_Score <- rescale_utilities(
      item_scores$Net_Score, rescale_method
    )
  }

  # Sort by output preference
  sort_order <- config$output_settings$Output_Item_Sort_Order

  sort_col <- switch(sort_order,
    "UTILITY_DESC" = -item_scores$Rescaled_Score,
    "UTILITY_ASC" = item_scores$Rescaled_Score,
    "ITEM_ID" = item_scores$Item_ID,
    "DISPLAY_ORDER" = item_scores$Display_Order,
    -item_scores$Rescaled_Score
  )

  item_scores <- item_scores[order(sort_col), ]

  # Update rank
  item_scores$Rank <- rank(-item_scores$Rescaled_Score, ties.method = "min")

  # Select columns for output
  output_cols <- c(
    "Item_ID", "Item_Label", "Item_Group",
    "Times_Shown", "Times_Best", "Times_Worst",
    "Best_Pct", "Worst_Pct", "Net_Score"
  )

  if ("Logit_Utility" %in% names(item_scores)) {
    output_cols <- c(output_cols, "Logit_Utility", "Logit_SE")
  }

  if ("HB_Utility_Mean" %in% names(item_scores)) {
    output_cols <- c(output_cols, "HB_Utility_Mean", "HB_Utility_SD")
  }

  output_cols <- c(output_cols, "Rescaled_Score", "Rank")
  output_cols <- output_cols[output_cols %in% names(item_scores)]

  output_df <- item_scores[, output_cols]

  # Escape user-sourced text (formula injection protection)
  output_df <- maxdiff_escape_df(output_df)

  # Write data
  openxlsx::writeData(wb, "ITEM_SCORES", output_df, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)

  # Apply styles
  n_rows <- nrow(output_df)

  # Percentage columns (displayed as "0.0" since values are already 0-100 scale)
  pct_cols <- which(names(output_df) %in%
                     c("Best_Pct", "Worst_Pct"))
  for (col in pct_cols) {
    openxlsx::addStyle(wb, "ITEM_SCORES", styles$percent_display,
                      rows = 2:(n_rows + 1), cols = col, gridExpand = TRUE)
  }

  # Score columns (0.000 format)
  score_cols <- which(names(output_df) %in%
                       c("Net_Score", "Rescaled_Score"))
  for (col in score_cols) {
    openxlsx::addStyle(wb, "ITEM_SCORES", styles$score_3dp,
                      rows = 2:(n_rows + 1), cols = col, gridExpand = TRUE)
  }

  # Utility columns (0.000 format)
  util_cols <- which(names(output_df) %in%
                      c("Logit_Utility", "Logit_SE", "HB_Utility_Mean", "HB_Utility_SD"))
  for (col in util_cols) {
    openxlsx::addStyle(wb, "ITEM_SCORES", styles$score_3dp,
                      rows = 2:(n_rows + 1), cols = col, gridExpand = TRUE)
  }

  # Count columns (#,##0 format)
  count_cols <- which(names(output_df) %in%
                       c("Times_Shown", "Times_Best", "Times_Worst"))
  for (col in count_cols) {
    openxlsx::addStyle(wb, "ITEM_SCORES", styles$count,
                      rows = 2:(n_rows + 1), cols = col, gridExpand = TRUE)
  }

  # Rank column (integer format)
  rank_col <- which(names(output_df) == "Rank")
  if (length(rank_col) > 0) {
    openxlsx::addStyle(wb, "ITEM_SCORES", styles$integer,
                      rows = 2:(n_rows + 1), cols = rank_col, gridExpand = TRUE)
  }

  # ---------------------------------------------------------------------------
  # Conditional formatting
  # ---------------------------------------------------------------------------

  # Green-red color scale on BW_Score/Net_Score columns
  net_score_col <- which(names(output_df) == "Net_Score")
  if (length(net_score_col) > 0) {
    openxlsx::conditionalFormatting(
      wb, "ITEM_SCORES",
      cols = net_score_col,
      rows = 2:(n_rows + 1),
      type = "colourScale",
      style = c("#e74c3c", "#f7dc6f", "#27ae60"),
      rule = NULL
    )
  }

  rescaled_col <- which(names(output_df) == "Rescaled_Score")
  if (length(rescaled_col) > 0) {
    openxlsx::conditionalFormatting(
      wb, "ITEM_SCORES",
      cols = rescaled_col,
      rows = 2:(n_rows + 1),
      type = "colourScale",
      style = c("#e74c3c", "#f7dc6f", "#27ae60"),
      rule = NULL
    )
  }

  # Green highlight on Rank == 1
  if (length(rank_col) > 0) {
    openxlsx::conditionalFormatting(
      wb, "ITEM_SCORES",
      cols = rank_col,
      rows = 2:(n_rows + 1),
      rule = "==1",
      style = openxlsx::createStyle(fgFill = "#d5f5e3", fontColour = "#1e8449")
    )
  }

  # Set column widths
  openxlsx::setColWidths(wb, "ITEM_SCORES", cols = 1:ncol(output_df),
                        widths = "auto")
  openxlsx::setColWidths(wb, "ITEM_SCORES", cols = 2, widths = 40)  # Item_Label

  # Freeze header
  openxlsx::freezePane(wb, "ITEM_SCORES", firstRow = TRUE)
}


# ==============================================================================
# SEGMENT_SCORES SHEET
# ==============================================================================

#' Write SEGMENT_SCORES sheet
#' @keywords internal
write_segment_scores_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "SEGMENT_SCORES")

  segment_scores <- results$segment_results$segment_scores

  if (is.null(segment_scores) || nrow(segment_scores) == 0) {
    openxlsx::writeData(wb, "SEGMENT_SCORES", "No segment results available",
                       startRow = 1, startCol = 1)
    return()
  }

  # Select columns
  output_cols <- c(
    "Segment_ID", "Segment_Label", "Segment_Value", "Segment_N",
    "Item_ID", "Item_Label",
    "Times_Shown", "Times_Best", "Times_Worst",
    "Best_Pct", "Worst_Pct", "Net_Score", "Rank"
  )
  output_cols <- output_cols[output_cols %in% names(segment_scores)]

  output_df <- segment_scores[, output_cols]

  # Escape user-sourced text (formula injection protection)
  output_df <- maxdiff_escape_df(output_df)

  # Write data
  openxlsx::writeData(wb, "SEGMENT_SCORES", output_df, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)

  n_rows <- nrow(output_df)

  # Percentage columns (0.0 display)
  seg_pct_cols <- which(names(output_df) %in% c("Best_Pct", "Worst_Pct"))
  for (col in seg_pct_cols) {
    openxlsx::addStyle(wb, "SEGMENT_SCORES", styles$percent_display,
                      rows = 2:(n_rows + 1), cols = col, gridExpand = TRUE)
  }

  # Score columns (0.000)
  seg_score_cols <- which(names(output_df) == "Net_Score")
  for (col in seg_score_cols) {
    openxlsx::addStyle(wb, "SEGMENT_SCORES", styles$score_3dp,
                      rows = 2:(n_rows + 1), cols = col, gridExpand = TRUE)
  }

  # Count columns (#,##0)
  seg_count_cols <- which(names(output_df) %in%
                           c("Times_Shown", "Times_Best", "Times_Worst", "Segment_N"))
  for (col in seg_count_cols) {
    openxlsx::addStyle(wb, "SEGMENT_SCORES", styles$count,
                      rows = 2:(n_rows + 1), cols = col, gridExpand = TRUE)
  }

  # Rank column (integer)
  seg_rank_col <- which(names(output_df) == "Rank")
  if (length(seg_rank_col) > 0) {
    openxlsx::addStyle(wb, "SEGMENT_SCORES", styles$integer,
                      rows = 2:(n_rows + 1), cols = seg_rank_col, gridExpand = TRUE)

    # Highlight Rank == 1
    openxlsx::conditionalFormatting(
      wb, "SEGMENT_SCORES",
      cols = seg_rank_col,
      rows = 2:(n_rows + 1),
      rule = "==1",
      style = openxlsx::createStyle(fgFill = "#d5f5e3", fontColour = "#1e8449")
    )
  }

  # Set column widths
  openxlsx::setColWidths(wb, "SEGMENT_SCORES", cols = 1:ncol(output_df),
                        widths = "auto")
  if ("Item_Label" %in% names(output_df)) {
    label_col <- which(names(output_df) == "Item_Label")
    openxlsx::setColWidths(wb, "SEGMENT_SCORES", cols = label_col, widths = 40)
  }

  # Freeze header
  openxlsx::freezePane(wb, "SEGMENT_SCORES", firstRow = TRUE)
}


# ==============================================================================
# INDIVIDUAL_UTILS SHEET
# ==============================================================================

#' Write INDIVIDUAL_UTILS sheet
#' @keywords internal
write_individual_utils_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "INDIVIDUAL_UTILS")

  ind_utils <- results$hb_results$individual_utilities

  if (is.null(ind_utils) || nrow(ind_utils) == 0) {
    openxlsx::writeData(wb, "INDIVIDUAL_UTILS", "No individual utilities available",
                       startRow = 1, startCol = 1)
    return()
  }

  # Escape user-sourced text (formula injection protection)
  ind_utils <- maxdiff_escape_df(ind_utils)

  # Write data
  openxlsx::writeData(wb, "INDIVIDUAL_UTILS", ind_utils, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)

  # Set column widths
  openxlsx::setColWidths(wb, "INDIVIDUAL_UTILS", cols = 1:ncol(ind_utils),
                        widths = "auto")

  # Freeze header
  openxlsx::freezePane(wb, "INDIVIDUAL_UTILS", firstRow = TRUE)
}


# ==============================================================================
# MODEL_DIAGNOSTICS SHEET
# ==============================================================================

#' Write MODEL_DIAGNOSTICS sheet
#' @keywords internal
write_diagnostics_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "MODEL_DIAGNOSTICS")

  diagnostics_data <- list()

  # Logit model diagnostics
  if (!is.null(results$logit_results)) {
    fit <- results$logit_results$model_fit

    logit_diag <- data.frame(
      Metric = c(
        "Log-Likelihood",
        "Null Log-Likelihood",
        "AIC",
        "BIC",
        "McFadden Pseudo-R2",
        "Number of Parameters",
        "Number of Choice Sets"
      ),
      Value = c(
        round(fit$log_likelihood, 2),
        round(fit$null_log_likelihood, 2),
        round(fit$aic, 2),
        round(fit$bic, 2),
        round(fit$mcfadden_r2, 4),
        fit$n_parameters,
        fit$n_choice_sets
      ),
      stringsAsFactors = FALSE
    )

    diagnostics_data[["Logit Model"]] <- logit_diag
  }

  # HB model diagnostics
  if (!is.null(results$hb_results)) {
    hb_diag <- results$hb_results$diagnostics

    if (!is.null(hb_diag)) {
      hb_df <- data.frame(
        Metric = c(
          "Method",
          "Number of Divergences",
          "Max Treedepth Exceeded",
          "Mean Rhat",
          "Minimum ESS"
        ),
        Value = c(
          results$hb_results$model_fit$method,
          hb_diag$n_divergences %||% "N/A",
          hb_diag$max_treedepth_exceeded %||% "N/A",
          round(hb_diag$mean_rhat %||% NA, 3),
          round(hb_diag$min_ess %||% NA, 0)
        ),
        stringsAsFactors = FALSE
      )

      diagnostics_data[["HB Model"]] <- hb_df
    }
  }

  # Write each section
  current_row <- 1

  for (section_name in names(diagnostics_data)) {
    section_data <- diagnostics_data[[section_name]]

    # Escape user-sourced text (formula injection protection)
    section_name_safe <- maxdiff_escape_cell(section_name)
    section_data <- maxdiff_escape_df(section_data)

    openxlsx::writeData(wb, "MODEL_DIAGNOSTICS", section_name_safe,
                       startRow = current_row, startCol = 1)
    openxlsx::addStyle(wb, "MODEL_DIAGNOSTICS", styles$header,
                      rows = current_row, cols = 1:2, gridExpand = TRUE)

    openxlsx::writeData(wb, "MODEL_DIAGNOSTICS", section_data,
                       startRow = current_row + 1, startCol = 1,
                       colNames = TRUE, headerStyle = styles$subheader)

    current_row <- current_row + nrow(section_data) + 4
  }

  # Set column widths
  openxlsx::setColWidths(wb, "MODEL_DIAGNOSTICS", cols = 1:2, widths = c(30, 20))

  # Freeze header
  openxlsx::freezePane(wb, "MODEL_DIAGNOSTICS", firstRow = TRUE)

  # Conditional formatting: highlight "Good" values in diagnostics Value column
  # Apply the rule across all data rows; it is a no-op if no cells contain "Good"
  if (current_row > 1) {
    openxlsx::conditionalFormatting(
      wb, "MODEL_DIAGNOSTICS",
      cols = 2,
      rows = 2:current_row,
      rule = '=="Good"',
      style = openxlsx::createStyle(fgFill = "#d5f5e3", fontColour = "#1e8449")
    )
  }
}


# ==============================================================================
# TURF_RESULTS SHEET
# ==============================================================================

#' Write TURF_RESULTS sheet
#'
#' Writes the TURF incremental reach table with a summary row.
#'
#' @param wb Workbook object
#' @param results List. Analysis results containing turf_results
#' @param config List. Configuration object
#' @param styles List. Output styles
#' @keywords internal
write_turf_results_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "TURF_RESULTS")

  turf <- results$turf_results

  # Build incremental table
  inc_table <- turf$incremental_table
  if (is.null(inc_table) || nrow(inc_table) == 0) {
    openxlsx::writeData(wb, "TURF_RESULTS", "No TURF results available",
                       startRow = 1, startCol = 1)
    return()
  }

  # Select output columns - use what is available
  desired_cols <- c("Step", "Item_ID", "Item_Label", "Reach_Pct",
                    "Incremental_Pct", "Frequency")
  output_cols <- desired_cols[desired_cols %in% names(inc_table)]
  output_df <- inc_table[, output_cols, drop = FALSE]

  # Escape user-sourced text (formula injection protection)
  output_df <- maxdiff_escape_df(output_df)

  # Write data
  openxlsx::writeData(wb, "TURF_RESULTS", output_df, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)

  n_rows <- nrow(output_df)

  # Apply number formats
  pct_cols <- which(names(output_df) %in% c("Reach_Pct", "Incremental_Pct"))
  for (col in pct_cols) {
    openxlsx::addStyle(wb, "TURF_RESULTS", styles$percent_display,
                      rows = 2:(n_rows + 1), cols = col, gridExpand = TRUE)
  }

  freq_col <- which(names(output_df) == "Frequency")
  if (length(freq_col) > 0) {
    openxlsx::addStyle(wb, "TURF_RESULTS", styles$count,
                      rows = 2:(n_rows + 1), cols = freq_col, gridExpand = TRUE)
  }

  step_col <- which(names(output_df) == "Step")
  if (length(step_col) > 0) {
    openxlsx::addStyle(wb, "TURF_RESULTS", styles$integer,
                      rows = 2:(n_rows + 1), cols = step_col, gridExpand = TRUE)
  }

  # Summary row: total reach at max portfolio
  summary_row <- n_rows + 3
  openxlsx::writeData(wb, "TURF_RESULTS", "TOTAL REACH AT MAX PORTFOLIO",
                     startRow = summary_row, startCol = 1)
  openxlsx::addStyle(wb, "TURF_RESULTS", styles$subheader,
                    rows = summary_row, cols = 1:2, gridExpand = TRUE)

  # Write the max reach value
  max_reach <- if (!is.null(turf$total_reach)) {
    turf$total_reach
  } else if ("Reach_Pct" %in% names(output_df)) {
    max(output_df$Reach_Pct, na.rm = TRUE)
  } else {
    NA
  }

  openxlsx::writeData(wb, "TURF_RESULTS", max_reach,
                     startRow = summary_row, startCol = 2)
  openxlsx::addStyle(wb, "TURF_RESULTS", styles$percent_display,
                    rows = summary_row, cols = 2)

  # Column widths
  openxlsx::setColWidths(wb, "TURF_RESULTS", cols = 1:ncol(output_df),
                        widths = "auto")
  if ("Item_Label" %in% names(output_df)) {
    label_col <- which(names(output_df) == "Item_Label")
    openxlsx::setColWidths(wb, "TURF_RESULTS", cols = label_col, widths = 40)
  }

  # Freeze header
  openxlsx::freezePane(wb, "TURF_RESULTS", firstRow = TRUE)
}


# ==============================================================================
# ANCHOR_ANALYSIS SHEET
# ==============================================================================

#' Write ANCHOR_ANALYSIS sheet
#'
#' Writes anchor/must-have item analysis results.
#'
#' @param wb Workbook object
#' @param results List. Analysis results containing anchor_data
#' @param config List. Configuration object
#' @param styles List. Output styles
#' @keywords internal
write_anchor_analysis_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "ANCHOR_ANALYSIS")

  anchor <- results$anchor_data

  if (is.null(anchor) || nrow(anchor) == 0) {
    openxlsx::writeData(wb, "ANCHOR_ANALYSIS", "No anchor analysis data available",
                       startRow = 1, startCol = 1)
    return()
  }

  # Select output columns
  desired_cols <- c("Item_ID", "Item_Label", "Anchor_Rate", "Is_Must_Have")
  output_cols <- desired_cols[desired_cols %in% names(anchor)]
  output_df <- anchor[, output_cols, drop = FALSE]

  # Escape user-sourced text (formula injection protection)
  output_df <- maxdiff_escape_df(output_df)

  # Write data
  openxlsx::writeData(wb, "ANCHOR_ANALYSIS", output_df, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)

  n_rows <- nrow(output_df)

  # Apply number formats
  rate_col <- which(names(output_df) == "Anchor_Rate")
  if (length(rate_col) > 0) {
    openxlsx::addStyle(wb, "ANCHOR_ANALYSIS", styles$percent_display,
                      rows = 2:(n_rows + 1), cols = rate_col, gridExpand = TRUE)
  }

  # Conditional formatting: highlight must-have items
  must_have_col <- which(names(output_df) == "Is_Must_Have")
  if (length(must_have_col) > 0) {
    openxlsx::conditionalFormatting(
      wb, "ANCHOR_ANALYSIS",
      cols = must_have_col,
      rows = 2:(n_rows + 1),
      rule = '=="TRUE"',
      style = openxlsx::createStyle(fgFill = "#d5f5e3", fontColour = "#1e8449")
    )
    openxlsx::conditionalFormatting(
      wb, "ANCHOR_ANALYSIS",
      cols = must_have_col,
      rows = 2:(n_rows + 1),
      rule = '=="Yes"',
      style = openxlsx::createStyle(fgFill = "#d5f5e3", fontColour = "#1e8449")
    )
  }

  # Column widths
  openxlsx::setColWidths(wb, "ANCHOR_ANALYSIS", cols = 1:ncol(output_df),
                        widths = "auto")
  if ("Item_Label" %in% names(output_df)) {
    label_col <- which(names(output_df) == "Item_Label")
    openxlsx::setColWidths(wb, "ANCHOR_ANALYSIS", cols = label_col, widths = 40)
  }

  # Freeze header
  openxlsx::freezePane(wb, "ANCHOR_ANALYSIS", firstRow = TRUE)
}


# ==============================================================================
# ITEM_DISCRIMINATION SHEET
# ==============================================================================

#' Write ITEM_DISCRIMINATION sheet
#'
#' Writes item discrimination classification data.
#'
#' @param wb Workbook object
#' @param results List. Analysis results containing discrimination_data
#' @param config List. Configuration object
#' @param styles List. Output styles
#' @keywords internal
write_item_discrimination_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "ITEM_DISCRIMINATION")

  disc <- results$discrimination_data

  if (is.null(disc) || nrow(disc) == 0) {
    openxlsx::writeData(wb, "ITEM_DISCRIMINATION",
                       "No item discrimination data available",
                       startRow = 1, startCol = 1)
    return()
  }

  # Escape user-sourced text (formula injection protection)
  disc <- maxdiff_escape_df(disc)

  # Write all columns (include all classification columns)
  openxlsx::writeData(wb, "ITEM_DISCRIMINATION", disc, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)

  n_rows <- nrow(disc)
  n_cols <- ncol(disc)

  # Apply number formats to numeric columns
  for (col_idx in seq_len(n_cols)) {
    col_name <- names(disc)[col_idx]
    col_vals <- disc[[col_idx]]

    if (is.numeric(col_vals)) {
      # Detect if likely a percentage (name contains Pct or Rate)
      if (grepl("Pct|Rate|Percent|Proportion", col_name, ignore.case = TRUE)) {
        openxlsx::addStyle(wb, "ITEM_DISCRIMINATION", styles$percent_display,
                          rows = 2:(n_rows + 1), cols = col_idx, gridExpand = TRUE)
      } else if (grepl("Count|Freq|N$|_N_", col_name, ignore.case = TRUE)) {
        openxlsx::addStyle(wb, "ITEM_DISCRIMINATION", styles$count,
                          rows = 2:(n_rows + 1), cols = col_idx, gridExpand = TRUE)
      } else {
        openxlsx::addStyle(wb, "ITEM_DISCRIMINATION", styles$score_3dp,
                          rows = 2:(n_rows + 1), cols = col_idx, gridExpand = TRUE)
      }
    }
  }

  # Conditional formatting: highlight "Good" classification values
  for (col_idx in seq_len(n_cols)) {
    if (is.character(disc[[col_idx]]) || is.factor(disc[[col_idx]])) {
      vals <- as.character(disc[[col_idx]])
      if (any(grepl("Good", vals, ignore.case = TRUE))) {
        openxlsx::conditionalFormatting(
          wb, "ITEM_DISCRIMINATION",
          cols = col_idx,
          rows = 2:(n_rows + 1),
          rule = '=="Good"',
          style = openxlsx::createStyle(fgFill = "#d5f5e3", fontColour = "#1e8449")
        )
      }
    }
  }

  # Column widths
  openxlsx::setColWidths(wb, "ITEM_DISCRIMINATION", cols = 1:n_cols,
                        widths = "auto")
  if ("Item_Label" %in% names(disc)) {
    label_col <- which(names(disc) == "Item_Label")
    openxlsx::setColWidths(wb, "ITEM_DISCRIMINATION", cols = label_col, widths = 40)
  }

  # Freeze header
  openxlsx::freezePane(wb, "ITEM_DISCRIMINATION", firstRow = TRUE)
}


# ==============================================================================
# RUN_STATUS SHEET
# ==============================================================================

#' Write Run_Status sheet
#'
#' Writes a TRS-compliant run status sheet with module metadata,
#' timing, status, and any warnings/events from the run.
#'
#' @param wb Workbook object
#' @param run_result List. TRS run result with status, timing, events
#' @param styles List. Output styles
#' @keywords internal
write_run_status_sheet <- function(wb, run_result, styles) {

  openxlsx::addWorksheet(wb, "Run_Status")

  # Build status data
  status_data <- data.frame(
    Field = c(
      "Module",
      "Version",
      "Start_Time",
      "End_Time",
      "Duration_Seconds",
      "Status"
    ),
    Value = c(
      run_result$module %||% "MaxDiff",
      run_result$version %||% OUTPUT_VERSION,
      as.character(run_result$start_time %||% ""),
      as.character(run_result$end_time %||% ""),
      as.character(round(
        as.numeric(difftime(
          run_result$end_time %||% Sys.time(),
          run_result$start_time %||% Sys.time(),
          units = "secs"
        )), 2
      )),
      run_result$status %||% "UNKNOWN"
    ),
    stringsAsFactors = FALSE
  )

  # Write status info
  openxlsx::writeData(wb, "Run_Status", "RUN STATUS", startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, "Run_Status", styles$header,
                    rows = 1, cols = 1:2, gridExpand = TRUE)
  openxlsx::writeData(wb, "Run_Status", status_data, startRow = 2, startCol = 1,
                     colNames = TRUE, headerStyle = styles$subheader)

  # Conditional formatting: colour the status value
  status_row <- which(status_data$Field == "Status") + 2  # +1 header, +1 for writeData header
  status_val <- run_result$status %||% ""

  if (status_val == "PASS") {
    openxlsx::addStyle(wb, "Run_Status",
                      openxlsx::createStyle(fgFill = "#d5f5e3", fontColour = "#1e8449"),
                      rows = status_row, cols = 2)
  } else if (status_val == "PARTIAL") {
    openxlsx::addStyle(wb, "Run_Status",
                      openxlsx::createStyle(fgFill = "#fef9e7", fontColour = "#b7950b"),
                      rows = status_row, cols = 2)
  } else if (status_val == "REFUSED") {
    openxlsx::addStyle(wb, "Run_Status",
                      openxlsx::createStyle(fgFill = "#fdedec", fontColour = "#e74c3c"),
                      rows = status_row, cols = 2)
  }

  # Write warnings/events if present
  current_row <- nrow(status_data) + 5

  warnings_list <- run_result$warnings %||% run_result$events %||% NULL
  if (!is.null(warnings_list) && length(warnings_list) > 0) {
    openxlsx::writeData(wb, "Run_Status", "WARNINGS / EVENTS",
                       startRow = current_row, startCol = 1)
    openxlsx::addStyle(wb, "Run_Status", styles$header,
                      rows = current_row, cols = 1:2, gridExpand = TRUE)

    if (is.data.frame(warnings_list)) {
      openxlsx::writeData(wb, "Run_Status", warnings_list,
                         startRow = current_row + 1, startCol = 1,
                         colNames = TRUE, headerStyle = styles$subheader)
    } else {
      # Convert character vector to data frame
      events_df <- data.frame(
        Event = seq_along(warnings_list),
        Message = as.character(warnings_list),
        stringsAsFactors = FALSE
      )
      openxlsx::writeData(wb, "Run_Status", events_df,
                         startRow = current_row + 1, startCol = 1,
                         colNames = TRUE, headerStyle = styles$subheader)
    }
  }

  # Column widths
  openxlsx::setColWidths(wb, "Run_Status", cols = 1:2, widths = c(25, 40))

  # Freeze header row (of the status table, row 2)
  openxlsx::freezePane(wb, "Run_Status", firstRow = TRUE)
}


# ==============================================================================
# DESIGN SHEETS
# ==============================================================================

#' Write DESIGN sheets
#' @keywords internal
write_design_sheets <- function(wb, results, config, styles) {

  design_result <- results$design_result

  # DESIGN sheet
  openxlsx::addWorksheet(wb, "DESIGN")
  openxlsx::writeData(wb, "DESIGN", design_result$design, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)
  openxlsx::setColWidths(wb, "DESIGN", cols = 1:ncol(design_result$design),
                        widths = "auto")
  openxlsx::freezePane(wb, "DESIGN", firstRow = TRUE)

  # DESIGN_SUMMARY sheet
  openxlsx::addWorksheet(wb, "DESIGN_SUMMARY")

  design_summary <- summarize_design(design_result)

  openxlsx::writeData(wb, "DESIGN_SUMMARY", "Design Summary",
                     startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, "DESIGN_SUMMARY", styles$header,
                    rows = 1, cols = 1:2, gridExpand = TRUE)
  openxlsx::writeData(wb, "DESIGN_SUMMARY", design_summary$summary,
                     startRow = 2, startCol = 1,
                     colNames = TRUE, headerStyle = styles$subheader)

  openxlsx::writeData(wb, "DESIGN_SUMMARY", "Item Frequencies",
                     startRow = nrow(design_summary$summary) + 5, startCol = 1)
  openxlsx::writeData(wb, "DESIGN_SUMMARY", design_summary$item_frequencies,
                     startRow = nrow(design_summary$summary) + 6, startCol = 1,
                     colNames = TRUE, headerStyle = styles$subheader)

  openxlsx::setColWidths(wb, "DESIGN_SUMMARY", cols = 1:3, widths = c(25, 15, 15))
}


# ==============================================================================
# DESIGN-ONLY OUTPUT
# ==============================================================================

#' Generate design-only Excel output
#'
#' @param design_result List. Output from generate_maxdiff_design
#' @param config List. Configuration object
#' @param verbose Logical. Print messages
#'
#' @return Character. Path to output file
#' @export
generate_design_output <- function(design_result, config, verbose = TRUE) {

  if (verbose) log_message("Generating design output file...", "INFO", verbose)

  # Check openxlsx
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    maxdiff_refuse(
      code = "PKG_OPENXLSX_MISSING",
      title = "Required Package Not Installed",
      problem = "Package 'openxlsx' is required but not installed",
      why_it_matters = "Excel output generation depends on the openxlsx package",
      how_to_fix = "Install the openxlsx package: install.packages('openxlsx')"
    )
  }

  # Determine output path
  output_folder <- config$project_settings$Output_Folder
  project_name <- config$project_settings$Project_Name

  if (is.null(output_folder) || !nzchar(output_folder)) {
    output_folder <- config$project_root
  }

  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
  }

  output_filename <- sprintf("%s_MaxDiff_Design.xlsx", project_name)
  output_path <- file.path(output_folder, output_filename)

  # Create workbook
  wb <- openxlsx::createWorkbook()
  styles <- create_output_styles()

  # DESIGN sheet
  openxlsx::addWorksheet(wb, "DESIGN")
  openxlsx::writeData(wb, "DESIGN", design_result$design, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)
  openxlsx::setColWidths(wb, "DESIGN", cols = 1:ncol(design_result$design),
                        widths = "auto")
  openxlsx::freezePane(wb, "DESIGN", firstRow = TRUE)

  # DESIGN_SUMMARY sheet
  openxlsx::addWorksheet(wb, "DESIGN_SUMMARY")
  design_summary <- summarize_design(design_result)

  openxlsx::writeData(wb, "DESIGN_SUMMARY", design_summary$summary,
                     startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)

  openxlsx::writeData(wb, "DESIGN_SUMMARY", "Item Frequencies",
                     startRow = nrow(design_summary$summary) + 3, startCol = 1)
  openxlsx::writeData(wb, "DESIGN_SUMMARY", design_summary$item_frequencies,
                     startRow = nrow(design_summary$summary) + 4, startCol = 1,
                     colNames = TRUE, headerStyle = styles$subheader)

  # Save (TRS v1.0: Use atomic save if available)
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_path, module = "MAXD")
    if (!save_result$success) {
      maxdiff_refuse(
        code = "IO_DESIGN_FILE_SAVE_FAILED",
        title = "Design File Save Failed",
        problem = sprintf("Failed to save design Excel file: %s", save_result$error),
        why_it_matters = "Design file cannot be saved for use in survey or analysis",
        how_to_fix = c(
          "Check that output folder has write permissions",
          "Ensure output file is not open in Excel",
          "Verify sufficient disk space available"
        ),
        details = sprintf("Path: %s\nError: %s", output_path, save_result$error)
      )
    }
  } else {
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  }

  if (verbose) {
    log_message(sprintf("Design saved: %s", output_path), "INFO", verbose)
  }

  return(output_path)
}


# ==============================================================================
# NULL COALESCE
# ==============================================================================

#' @keywords internal
`%||%` <- function(x, y) if (is.null(x)) y else x


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff output module loaded (v%s)", OUTPUT_VERSION))
