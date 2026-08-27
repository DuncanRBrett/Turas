# ==============================================================================
# CONJOINT ANALYSIS - TABS EXPORT
# ==============================================================================
#
# Module: Conjoint Analysis - Attribute Importance Export for the tabs module
# Purpose: Write per-respondent attribute importance in the shape tabs reads as
#          an Allocation question, so conjoint results can be crosstabbed
#          against any banner in the client's own report.
#
# WHY IMPORTANCE, AND NOT UTILITIES:
#   Attribute importance shares sum to 100 per respondent by construction,
#   which is exactly the contract tabs' Allocation processor expects
#   (modules/tabs/lib/allocation_processor.R). Part-worth utilities do not:
#   they are a scale with an arbitrary origin, and averaging them across a
#   banner segment mixes scale with preference. Per-level part-worths as
#   Numeric columns are a deferred extension, not an oversight — see the
#   extension point at the foot of this file.
#
# WHAT THIS CANNOT EXPORT:
#   Simulator preference shares (scenario-dependent), WTP, optimiser output and
#   model diagnostics all stay in the conjoint deliverables. None of them is a
#   per-respondent quantity, so none can be crosstabbed.
#
# HONEST SIGNIFICANCE:
#   Only genuine respondent-level estimates are exportable. Under
#   estimation_method = "auto", "mlogit" or "clogit" there is one pooled model
#   and no per-respondent anything, so the export refuses rather than inventing
#   a respondent-level number for tabs to significance-test.
#
# ==============================================================================

CONJOINT_TABS_EXPORT_VERSION <- "1.0.0"

# Methods that produce genuine per-respondent estimates.
CONJOINT_RESPONDENT_LEVEL_METHODS <- c("hierarchical_bayes", "latent_class")


#' Export Per-Respondent Attribute Importance for the Tabs Module
#'
#' Writes a workbook tabs can read as an Allocation question: one row per
#' respondent, one column per attribute, values summing to 100.
#'
#' @param results The list returned by `run_conjoint_analysis()` (or any list
#'   carrying `respondent_importance`, `model_result` and `config`).
#' @param output_file Path for the workbook. Defaults to the main output file's
#'   name with `_tabs_importance.xlsx` in place of `.xlsx`.
#' @param verbose Logical, print progress.
#'
#' @return A list with:
#'   \item{status}{"PASS" or "PARTIAL"}
#'   \item{output_file}{Path written}
#'   \item{n_exported}{Respondents written}
#'   \item{n_excluded}{Respondents dropped for zero importance range}
#'   \item{question_code}{The QuestionCode used}
#'
#' @examples
#' \dontrun{
#'   results <- run_conjoint_analysis("config.xlsx")
#'   export_conjoint_importance_for_tabs(results)
#' }
#'
#' @export
export_conjoint_importance_for_tabs <- function(results,
                                                output_file = NULL,
                                                verbose = TRUE) {

  config <- results$config
  model_result <- results$model_result

  # --- Gate: respondent-level estimates only --------------------------------
  method <- model_result$method %||% "unknown"

  if (!method %in% CONJOINT_RESPONDENT_LEVEL_METHODS) {
    conjoint_refuse(
      code = "CALC_NO_RESPONDENT_UTILITIES",
      title = "No Respondent-Level Estimates To Export",
      problem = sprintf(
        paste0("The model was estimated with method '%s', which fits one ",
               "pooled model for the whole sample. There are no per-respondent ",
               "importances to export."),
        method
      ),
      why_it_matters = paste0(
        "Tabs would crosstab and significance-test whatever it was given. A ",
        "single pooled estimate repeated for every respondent would produce ",
        "banner differences of exactly zero and significance tests on a ",
        "constant — results that look like findings and are not."
      ),
      how_to_fix = c(
        "Set estimation_method = 'hb' in the Settings sheet and re-run. Hierarchical Bayes estimates each respondent's own part-worths, which is what makes them crosstabbable.",
        "estimation_method = 'latent_class' also works, and additionally gives you class membership as a segment.",
        "If the study is not large enough for HB, the aggregate importance table in the Excel output is the honest deliverable — it just cannot be broken by banner."
      )
    )
  }

  # --- Input ----------------------------------------------------------------
  resp_importance <- results$respondent_importance

  if (is.null(resp_importance) || !is.matrix(resp_importance) ||
      nrow(resp_importance) == 0) {
    conjoint_refuse(
      code = "CALC_NO_RESPONDENT_UTILITIES",
      title = "Respondent Importance Matrix Is Missing",
      problem = paste0(
        "The analysis result carries no per-respondent importance matrix, ",
        "although the estimation method should have produced one."
      ),
      why_it_matters = "There is nothing to export.",
      how_to_fix = c(
        "Re-run the analysis; the matrix is produced during importance calculation.",
        "If this persists it is a bug — report it with the console output."
      )
    )
  }

  question_code <- .conjoint_tabs_question_code(config)
  resp_col <- config$respondent_id_column %||% "resp_id"
  attributes <- colnames(resp_importance)
  k <- length(attributes)

  log_verbose(sprintf("Exporting attribute importance for tabs (%d attributes)...", k),
              verbose)

  # --- Exclude respondents whose importances do not sum to 100 --------------
  # A respondent with completely flat part-worths has a total range of zero and
  # stays at zero importance. Those rows are not an allocation and would drag
  # every banner mean toward zero if they were exported as one.
  row_totals <- rowSums(resp_importance, na.rm = TRUE)
  usable <- is.finite(row_totals) & abs(row_totals - 100) < 1e-6

  n_excluded <- sum(!usable)
  export_matrix <- resp_importance[usable, , drop = FALSE]
  n_exported <- nrow(export_matrix)

  if (n_exported == 0) {
    conjoint_refuse(
      code = "CALC_NO_EXPORTABLE_RESPONDENTS",
      title = "No Respondent Has A Usable Importance Profile",
      problem = sprintf(
        "All %d respondents have flat part-worths, so none has an importance profile that sums to 100.",
        length(row_totals)
      ),
      why_it_matters = paste0(
        "An importance of zero on every attribute is not a preference; it is ",
        "the absence of one. Exporting those rows would put zeros into the ",
        "client's crosstabs as though they were answers."
      ),
      how_to_fix = c(
        "Check that the model converged — the console will have said so.",
        "Check the RLH quality figures in the Excel output: a sample of respondents who did not engage with the exercise produces exactly this."
      )
    )
  }

  if (n_excluded > 0) {
    cat(sprintf(
      "[TRS INFO] CONJ_TABS_EXPORT_EXCLUDED: %d of %d respondents excluded from the tabs export — flat part-worths, no importance profile.\n",
      n_excluded, length(row_totals)
    ))
  }

  # --- Build the DATA sheet -------------------------------------------------
  respondent_ids <- rownames(export_matrix)
  if (is.null(respondent_ids)) respondent_ids <- seq_len(n_exported)

  data_sheet <- data.frame(
    .id = respondent_ids,
    stringsAsFactors = FALSE
  )
  names(data_sheet) <- resp_col

  for (i in seq_len(k)) {
    data_sheet[[paste0(question_code, "_", i)]] <- unname(export_matrix[, i])
  }

  # --- Build the QuestionMap snippet ---------------------------------------
  method_label <- .conjoint_tabs_method_label(model_result)

  questionmap <- data.frame(
    QuestionCode = question_code,
    QuestionText = sprintf("Conjoint attribute importance (model-derived, %s)",
                           method_label),
    Variable_Type = "Allocation",
    Columns = k,
    stringsAsFactors = FALSE
  )

  options_sheet <- data.frame(
    QuestionCode = question_code,
    OptionCode = seq_len(k),
    OptionText = attributes,
    stringsAsFactors = FALSE
  )

  # --- Build the METHOD sheet ----------------------------------------------
  method_sheet <- .conjoint_tabs_method_sheet(
    model_result = model_result,
    config = config,
    question_code = question_code,
    n_exported = n_exported,
    n_excluded = n_excluded,
    attributes = attributes
  )

  # --- Write ----------------------------------------------------------------
  if (is.null(output_file)) {
    base <- config$output_file %||% "conjoint_results.xlsx"
    output_file <- sub("[.]xlsx$", "_tabs_importance.xlsx", base)
    if (identical(output_file, base)) {
      output_file <- paste0(base, "_tabs_importance.xlsx")
    }
  }

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
                         widths = c(18, 62, 16, 12))

  openxlsx::addWorksheet(wb, "METHOD")
  openxlsx::writeData(wb, "METHOD", method_sheet, headerStyle = header_style)
  openxlsx::setColWidths(wb, "METHOD", cols = 1:2, widths = c(34, 76))

  saver <- if (exists("turas_saveWorkbook", mode = "function")) {
    turas_saveWorkbook
  } else {
    function(wb, file, overwrite = TRUE) {
      openxlsx::saveWorkbook(wb, file, overwrite = overwrite)
    }
  }
  saver(wb, output_file, overwrite = TRUE)

  log_verbose(sprintf("  ✓ Tabs export: %s (%d respondents, %d attributes)",
                      basename(output_file), n_exported, k), verbose)

  list(
    status = if (n_excluded > 0) "PARTIAL" else "PASS",
    output_file = output_file,
    n_exported = n_exported,
    n_excluded = n_excluded,
    question_code = question_code,
    attributes = attributes,
    questionmap = questionmap,
    options = options_sheet
  )
}


#' The QuestionCode This Export Uses
#'
#' @param config Configuration list.
#' @return Character, a valid tabs question code.
#' @keywords internal
.conjoint_tabs_question_code <- function(config) {
  code <- config$tabs_question_code %||% "CJIMP"
  code <- toupper(trimws(as.character(code)))

  if (!nzchar(code) || !grepl("^[A-Z][A-Z0-9_]*$", code)) {
    conjoint_refuse(
      code = "CFG_TABS_QUESTION_CODE_INVALID",
      title = "Invalid Tabs Question Code",
      problem = sprintf("tabs_question_code = '%s' is not a usable question code.",
                        config$tabs_question_code %||% ""),
      why_it_matters = paste0(
        "The code becomes the column-name stem in the exported data and the ",
        "QuestionCode in your tabs QuestionMap. Tabs matches them by exact ",
        "name, so anything unusual silently fails to join."
      ),
      how_to_fix = c(
        "Use letters, digits and underscores, starting with a letter — for example CJIMP.",
        "Leave tabs_question_code blank to accept the default, CJIMP."
      )
    )
  }

  code
}


#' Human-Readable Estimator Label
#'
#' @keywords internal
.conjoint_tabs_method_label <- function(model_result) {
  switch(
    model_result$method %||% "",
    "hierarchical_bayes" = "hierarchical Bayes",
    "latent_class" = "latent class",
    model_result$method %||% "unknown"
  )
}


#' The METHOD Sheet
#'
#' Everything a reader needs to judge what these numbers are, in the workbook
#' that carries them rather than in a document beside it.
#'
#' @keywords internal
.conjoint_tabs_method_sheet <- function(model_result, config, question_code,
                                        n_exported, n_excluded, attributes) {

  add <- function(df, item, value) {
    rbind(df, data.frame(Item = item, Value = as.character(value),
                         stringsAsFactors = FALSE))
  }

  out <- data.frame(Item = character(0), Value = character(0),
                    stringsAsFactors = FALSE)

  out <- add(out, "Produced by", sprintf("Turas conjoint tabs export v%s",
                                         CONJOINT_TABS_EXPORT_VERSION))
  out <- add(out, "Question code", question_code)
  out <- add(out, "Variable type", "Allocation (values sum to 100 per respondent)")
  out <- add(out, "Attributes", paste(attributes, collapse = ", "))
  out <- add(out, "Estimator", .conjoint_tabs_method_label(model_result))

  if (identical(model_result$method, "hierarchical_bayes")) {
    hb <- model_result$hb_settings %||% list()
    out <- add(out, "MCMC iterations", hb$iterations %||% "unknown")
    out <- add(out, "Burn-in", hb$burnin %||% "unknown")
    out <- add(out, "Thinning", hb$thin %||% "unknown")
    out <- add(out, "Draws retained", hb$n_draws_retained %||% "unknown")
    conv <- model_result$convergence %||% list()
    out <- add(out, "Convergence",
               if (isTRUE(conv$converged)) "Converged" else "NOT converged — treat with caution")
  }

  if (identical(model_result$method, "latent_class")) {
    lc <- model_result$latent_class %||% list()
    out <- add(out, "Classes", lc$optimal_k %||% "unknown")
    out <- add(out, "Entropy R-squared", .fmt_or(lc$entropy_r2, "%.3f"))
  }

  quality <- model_result$respondent_quality %||% NULL
  if (!is.null(quality)) {
    out <- add(out, "Mean RLH", .fmt_or(quality$mean_rlh, "%.3f"))
    out <- add(out, "Chance RLH", .fmt_or(quality$chance_rlh, "%.3f"))
    out <- add(out, "Respondents flagged for low RLH",
               sprintf("%s (RLH below %s)",
                       quality$n_flagged %||% "unknown",
                       .fmt_or(quality$quality_threshold, "%.3f")))
    out <- add(out, "Note on flagged respondents",
               paste0("They are INCLUDED in this export. Filter them in tabs ",
                      "if you want them out — the decision is yours, and it ",
                      "should be a stated one."))
  }

  out <- add(out, "Respondents exported", n_exported)
  out <- add(out, "Respondents excluded", sprintf(
    "%d (flat part-worths — no importance profile to allocate)", n_excluded))

  out <- add(out, "Weighting", paste0(
    "The conjoint model is estimated UNWEIGHTED. Tabs applies the study's ",
    "weights when it reports these columns, so the crosstab is weighted and ",
    "the estimation behind it is not. Say so when you present it."))

  out <- add(out, "What these numbers are", paste0(
    "Each respondent's attributes ranked by how much the part-worth range of ",
    "that attribute drove their choices, expressed as a share of 100. They are ",
    "model output, not answers a respondent gave."))

  out <- add(out, "Significance testing", paste0(
    "Tabs will significance-test these columns like any Allocation question. ",
    "The test is valid on the estimates; it does not carry the model's own ",
    "uncertainty, which is in the conjoint report."))

  out
}


#' Format a Number, or Say It Is Missing
#'
#' @keywords internal
.fmt_or <- function(x, fmt, missing = "unknown") {
  if (is.null(x) || length(x) != 1 || !is.finite(suppressWarnings(as.numeric(x)))) {
    return(missing)
  }
  sprintf(fmt, as.numeric(x))
}


# ==============================================================================
# EXTENSION POINT — per-level part-worths as Numeric columns
# ==============================================================================
#
# Deferred by decision, not omitted by accident. Exporting each LEVEL's
# part-worth as its own Numeric column would let tabs report "mean utility of
# Brand = Alpha" by banner. Two things must be settled first:
#
#   1. The zero-centring convention. Part-worths must be centred within
#      attribute PER RESPONDENT before export, or a banner mean mixes each
#      respondent's scale origin with their preference and the column means
#      nothing.
#   2. The baseline level. It is 0 by construction and must be written as a
#      real 0 column, not omitted, or the attribute's levels do not add up.
#
# Until both are agreed, only importance ships. See the conjoint review §8.2.
#
# ==============================================================================

message(sprintf("TURAS>Conjoint tabs export loaded (v%s)", CONJOINT_TABS_EXPORT_VERSION))
