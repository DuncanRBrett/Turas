# ==============================================================================
# MAXDIFF - TABS EXPORT (per-respondent preference shares as an Allocation)
# ==============================================================================
#
# Module: MaxDiff - contribution to the tabs module
# Purpose: Write each respondent's preference shares in the shape the tabs
#          module reads as an Allocation question ({QCode}_1 .. {QCode}_k, one
#          numeric column per item, summing to 100 per respondent), so MaxDiff
#          results can be crosstabbed, weighted and significance-tested by
#          banner in the client's own report.
#
# THE HONEST-SIG GATE (programme decision D5, handover B2 locked decision 4):
#   Tabs would crosstab and significance-test whatever it is given. Shares are
#   only worth that treatment when they come from genuinely respondent-level
#   estimates. Two things refuse here:
#     - no individual utilities at all (Generate_HB_Model = NO): there is
#       nothing per respondent to export;
#     - the empirical-Bayes fallback (cmdstanr absent): those "utilities" are
#       shrunken count scores, not posterior estimates. The export refuses by
#       default. Allow_Approx_Utilities_Export = YES overrides, and then the
#       QuestionText and the METHOD sheet both carry the approximation stamp
#       so the label follows the numbers into the crosstab.
#
# This is the maxdiff twin of modules/conjoint/R/16_tabs_export.R, and the
# two share the DATA / QUESTIONMAP_SNIPPET / METHOD layout so an operator who
# has used one recognises the other.
#
# ==============================================================================

MAXDIFF_TABS_EXPORT_VERSION <- "1.0.0"

# Estimators whose individual utilities are respondent-level estimates.
MAXDIFF_RESPONDENT_LEVEL_METHODS <- c("cmdstanr")

#' Export MaxDiff Preference Shares For Tabs
#'
#' Writes `{output}_tabs_shares.xlsx` with three sheets: DATA (respondent id
#' plus one share column per item), QUESTIONMAP_SNIPPET (the QuestionMap and
#' Options rows to paste into a tabs config) and METHOD (what the numbers are).
#'
#' @param results The results list from `run_maxdiff_generate_outputs()`
#'   (needs `hb_results$individual_utilities` and `output_path`).
#' @param config The loaded maxdiff configuration.
#' @param output_file Path for the workbook. Defaults to the main output's name
#'   with `_tabs_shares.xlsx` in place of `.xlsx`.
#' @param verbose Logical, print progress.
#'
#' @return A list with structure:
#'   \item{status}{"PASS" or "PARTIAL"}
#'   \item{output_file}{Path written}
#'   \item{n_exported}{Respondents written}
#'   \item{question_code}{The QuestionCode used}
#'   \item{approximate}{TRUE when the override let EB shares through}
#'   Refuses (TRS) when there is nothing respondent-level to export.
#'
#' @export
export_maxdiff_shares_for_tabs <- function(results, config, output_file = NULL,
                                           verbose = TRUE) {

  hb <- results$hb_results
  indiv <- hb$individual_utilities

  # --- Gate 1: something respondent-level must exist -------------------------
  if (is.null(indiv) || !is.data.frame(indiv) || nrow(indiv) == 0) {
    maxdiff_refuse(
      code = "MODEL_NO_RESPONDENT_UTILITIES",
      title = "No Respondent-Level Utilities To Export",
      problem = paste0(
        "The run produced no individual utilities, so there are no ",
        "per-respondent preference shares to hand to tabs."
      ),
      why_it_matters = paste0(
        "Tabs crosstabs and significance-tests what it is given. Count scores ",
        "or an aggregate logit are one number per item for the whole sample; ",
        "repeated for every respondent they would produce banner differences ",
        "of exactly zero."
      ),
      how_to_fix = c(
        "Set Generate_HB_Model = YES in OUTPUT_SETTINGS and re-run.",
        "Individual utilities need respondents who each answered several tasks; check the design."
      )
    )
  }

  # --- Gate 2: honest-sig (D5) ----------------------------------------------
  method <- hb$model_fit$method %||% hb$diagnostics$method %||% "unknown"
  is_respondent_level <- method %in% MAXDIFF_RESPONDENT_LEVEL_METHODS
  allow_approx <- isTRUE(config$output_settings$Allow_Approx_Utilities_Export)

  if (!is_respondent_level && !allow_approx) {
    maxdiff_refuse(
      code = "MODEL_APPROX_UTILITIES",
      title = "Approximate Utilities Are Not Exported To Tabs By Default",
      problem = sprintf(paste0(
        "The individual utilities come from '%s', the count-based ",
        "empirical-Bayes fallback that runs when cmdstanr is not installed. ",
        "They are shrunken best-minus-worst counts, not posterior estimates."),
        method),
      why_it_matters = paste0(
        "Once inside a crosstab they would be weighted and significance-tested ",
        "as though they were model estimates, and nothing in the table would ",
        "say otherwise."
      ),
      how_to_fix = c(
        "Install cmdstanr and CmdStan so Generate_HB_Model = YES fits the Stan model; the export then proceeds unstamped.",
        "Or set Allow_Approx_Utilities_Export = YES in OUTPUT_SETTINGS. The export then proceeds and the QuestionText and METHOD sheet carry an 'approximate: count-based' stamp."
      )
    )
  }
  approximate <- !is_respondent_level

  # --- Shares -----------------------------------------------------------------
  # Items in the configured order, so the Options rows and the columns agree.
  items <- config$items
  included <- items[items$Include == 1, , drop = FALSE]
  if ("Display_Order" %in% names(included)) {
    included <- included[order(included$Display_Order), , drop = FALSE]
  }
  item_ids <- as.character(included$Item_ID)
  item_labels <- as.character(included$Item_Label %||% included$Item_ID)

  utils_mat <- as.matrix(strip_respondent_id_cols(indiv))
  have <- intersect(item_ids, colnames(utils_mat))
  if (length(have) < 2) {
    maxdiff_refuse(
      code = "MODEL_NO_RESPONDENT_UTILITIES",
      title = "Individual Utilities Do Not Match The Items",
      problem = sprintf(
        "Only %d of the %d included items have a utility column (%s).",
        length(have), length(item_ids), paste(head(colnames(utils_mat), 6), collapse = ", ")),
      why_it_matters = "Shares over fewer than two items are not a preference profile.",
      how_to_fix = "Check the ITEMS sheet against the design file; item ids must match."
    )
  }
  keep <- item_ids %in% have
  item_ids <- item_ids[keep]
  item_labels <- item_labels[keep]
  utils_mat <- utils_mat[, item_ids, drop = FALSE]

  resp_ids <- .maxdiff_export_respondent_ids(indiv, results)

  # Softmax per respondent, in percent. The same arithmetic as
  # compute_preference_shares(), kept per row instead of averaged.
  shares <- t(apply(utils_mat, 1, function(u) {
    if (all(is.na(u))) return(rep(NA_real_, length(u)))
    e <- exp(u - max(u, na.rm = TRUE))
    100 * e / sum(e, na.rm = TRUE)
  }))
  colnames(shares) <- item_ids

  usable <- is.finite(rowSums(shares)) & abs(rowSums(shares) - 100) < 1e-6
  n_excluded <- sum(!usable)
  shares <- shares[usable, , drop = FALSE]
  resp_ids <- resp_ids[usable]
  n_exported <- nrow(shares)

  if (n_exported == 0) {
    maxdiff_refuse(
      code = "MODEL_NO_RESPONDENT_UTILITIES",
      title = "No Respondent Has A Usable Share Profile",
      problem = "Every respondent's utilities are missing, so no share row sums to 100.",
      why_it_matters = "There is nothing to export.",
      how_to_fix = "Check the INDIVIDUAL_UTILS sheet of the main output for the missing values."
    )
  }
  if (n_excluded > 0) {
    cat(sprintf(
      "[TRS INFO] MAXD_TABS_EXPORT_EXCLUDED: %d of %d respondents excluded from the tabs export (missing utilities, no share profile).\n",
      n_excluded, n_excluded + n_exported))
  }

  # --- Sheets -------------------------------------------------------------------
  question_code <- .maxdiff_tabs_question_code(config)
  id_col <- config$project_settings$Respondent_ID_Variable %||% "RespID"
  k <- length(item_ids)

  data_sheet <- data.frame(.id = resp_ids, stringsAsFactors = FALSE)
  names(data_sheet) <- id_col
  for (i in seq_len(k)) {
    data_sheet[[paste0(question_code, "_", i)]] <- unname(shares[, i])
  }

  method_label <- .maxdiff_tabs_method_label(method)
  stamp <- if (approximate) " (approximate: count-based)" else ""
  questionmap <- data.frame(
    QuestionCode = question_code,
    QuestionText = sprintf("MaxDiff preference shares (model-derived, %s)%s",
                           method_label, stamp),
    Variable_Type = "Allocation",
    Columns = k,
    stringsAsFactors = FALSE
  )
  options_sheet <- data.frame(
    QuestionCode = question_code,
    OptionCode = seq_len(k),
    OptionText = item_labels,
    stringsAsFactors = FALSE
  )
  method_sheet <- .maxdiff_tabs_method_sheet(
    config = config, hb = hb, method = method, method_label = method_label,
    approximate = approximate, question_code = question_code,
    n_exported = n_exported, n_excluded = n_excluded, item_labels = item_labels
  )

  # --- Write ---------------------------------------------------------------------
  if (is.null(output_file)) {
    base <- results$output_path %||% file.path(
      config$project_settings$Output_Folder %||% ".",
      paste0(config$project_settings$Project_Name %||% "maxdiff", "_MaxDiff_Results.xlsx"))
    output_file <- sub("[.]xlsx$", "_tabs_shares.xlsx", base)
    if (identical(output_file, base)) output_file <- paste0(base, "_tabs_shares.xlsx")
  }
  out_dir <- dirname(output_file)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  wb <- openxlsx::createWorkbook()
  header_style <- openxlsx::createStyle(textDecoration = "bold")

  openxlsx::addWorksheet(wb, "DATA")
  openxlsx::writeData(wb, "DATA", data_sheet, headerStyle = header_style)

  openxlsx::addWorksheet(wb, "QUESTIONMAP_SNIPPET")
  openxlsx::writeData(wb, "QUESTIONMAP_SNIPPET",
                      "Paste this row into your tabs QuestionMap sheet:",
                      startRow = 1, startCol = 1)
  openxlsx::writeData(wb, "QUESTIONMAP_SNIPPET", questionmap,
                      startRow = 2, headerStyle = header_style)
  openxlsx::writeData(wb, "QUESTIONMAP_SNIPPET",
                      "...and these rows into your Options sheet:",
                      startRow = 5, startCol = 1)
  openxlsx::writeData(wb, "QUESTIONMAP_SNIPPET", options_sheet,
                      startRow = 6, headerStyle = header_style)
  openxlsx::setColWidths(wb, "QUESTIONMAP_SNIPPET", cols = 1:4,
                         widths = c(18, 70, 16, 12))

  openxlsx::addWorksheet(wb, "METHOD")
  openxlsx::writeData(wb, "METHOD", method_sheet, headerStyle = header_style)
  openxlsx::setColWidths(wb, "METHOD", cols = 1:2, widths = c(34, 80))

  saver <- if (exists("turas_saveWorkbook", mode = "function")) {
    turas_saveWorkbook
  } else {
    function(wb, file, overwrite = TRUE) openxlsx::saveWorkbook(wb, file, overwrite = overwrite)
  }
  saver(wb, output_file, overwrite = TRUE)

  if (verbose) {
    cat(sprintf("  Tabs export: %s (%d respondents, %d items%s)\n",
                basename(output_file), n_exported, k,
                if (approximate) ", STAMPED approximate" else ""))
  }

  list(
    status = if (n_excluded > 0) "PARTIAL" else "PASS",
    output_file = output_file,
    n_exported = n_exported,
    n_excluded = n_excluded,
    question_code = question_code,
    item_ids = item_ids,
    approximate = approximate,
    questionmap = questionmap,
    options = options_sheet
  )
}


#' Respondent ids in the row order of the individual utilities
#' @keywords internal
.maxdiff_export_respondent_ids <- function(indiv, results) {
  id_cols <- intersect(c("resp_id", "respondent_id"), names(indiv))
  if (length(id_cols) > 0) return(as.character(indiv[[id_cols[1]]]))
  if (!is.null(results$hb_results$respondent_ids)) {
    return(as.character(results$hb_results$respondent_ids))
  }
  as.character(seq_len(nrow(indiv)))
}


#' The QuestionCode this export uses
#'
#' Tabs question codes are letters, digits and underscores; anything else in
#' the configured value is replaced so the column names stay valid.
#' @keywords internal
.maxdiff_tabs_question_code <- function(config) {
  code <- config$output_settings$Tabs_Question_Code %||% "MDSHARE"
  code <- trimws(as.character(code))
  if (!nzchar(code)) code <- "MDSHARE"
  code <- gsub("[^A-Za-z0-9_]", "_", code)
  if (grepl("^[0-9]", code)) code <- paste0("Q", code)
  code
}


#' @keywords internal
.maxdiff_tabs_method_label <- function(method) {
  switch(
    method,
    "cmdstanr" = "Stan hierarchical Bayes",
    "empirical_bayes_shrinkage" = "empirical Bayes fallback",
    "empirical_bayes" = "empirical Bayes fallback",
    method
  )
}


#' The METHOD sheet: what the numbers are, in the operator's hands
#' @keywords internal
.maxdiff_tabs_method_sheet <- function(config, hb, method, method_label,
                                       approximate, question_code,
                                       n_exported, n_excluded, item_labels) {
  ps <- config$project_settings
  os <- config$output_settings
  add <- function(df, item, value) {
    rbind(df, data.frame(Item = item, Value = as.character(value),
                         stringsAsFactors = FALSE))
  }
  df <- data.frame(Item = character(0), Value = character(0),
                   stringsAsFactors = FALSE)

  df <- add(df, "What this is",
            paste0("Each respondent's preference share across the MaxDiff items: ",
                   "a softmax of that respondent's utilities, in percent, summing ",
                   "to 100. Exported as a tabs Allocation question."))
  df <- add(df, "Estimator", method_label)
  if (approximate) {
    df <- add(df, "APPROXIMATE",
              paste0("The utilities are the count-based empirical-Bayes fallback ",
                     "(cmdstanr was not available), not posterior estimates. ",
                     "Exported under Allow_Approx_Utilities_Export = YES. The ",
                     "QuestionText carries the same stamp."))
  } else {
    df <- add(df, "HB chains / iterations / warmup",
              sprintf("%s / %s / %s", os$HB_Chains %||% "?", os$HB_Iterations %||% "?",
                      os$HB_Warmup %||% "?"))
    if (!is.null(hb$diagnostics$mean_rhat)) {
      df <- add(df, "Mean R-hat", sprintf("%.3f", hb$diagnostics$mean_rhat))
    }
  }
  df <- add(df, "Respondents exported", n_exported)
  df <- add(df, "Respondents excluded", n_excluded)
  df <- add(df, "Filter applied",
            if (!is.null(ps$Filter_Expression) && nzchar(ps$Filter_Expression)) {
              paste0(ps$Filter_Expression,
                     ". The export covers the filtered respondents only; a tabs ",
                     "base built from the whole data file will differ.")
            } else "None")
  df <- add(df, "Weighting",
            paste0("The MaxDiff utilities are estimated unweighted, per respondent. ",
                   if (!is.null(ps$Weight_Variable) && nzchar(ps$Weight_Variable)) {
                     sprintf("The study's weight variable (%s) is applied by tabs when it reports these shares, not here.",
                             ps$Weight_Variable)
                   } else {
                     "Tabs applies its own weights, if any, when it reports these shares."
                   }))
  df <- add(df, "Column contract",
            sprintf("%s_1 .. %s_%d, one column per item in the order of the Options rows; row id column = %s.",
                    question_code, question_code, length(item_labels),
                    ps$Respondent_ID_Variable %||% "RespID"))
  df <- add(df, "Items", paste(item_labels, collapse = " | "))
  df <- add(df, "Module", sprintf("Turas MaxDiff %s, tabs export %s",
                                  if (exists("MAXDIFF_VERSION")) MAXDIFF_VERSION else "?",
                                  MAXDIFF_TABS_EXPORT_VERSION))
  df <- add(df, "Generated", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  df
}
