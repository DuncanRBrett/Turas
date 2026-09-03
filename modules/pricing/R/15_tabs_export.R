# ==============================================================================
# PRICING - TABS EXPORT (the Gabor-Granger acceptance grid, per respondent)
# ==============================================================================
#
# Module: Pricing - contribution to the tabs module
# Purpose: Write each respondent's answers in the shape the tabs module reads,
#          so pricing acceptance can be crosstabbed, weighted and
#          significance-tested by banner in the client's own report. This is
#          the filterable half of the pricing lift; the v2 island
#          (14_v2_island.R) is the frozen half.
#
# WHAT TRAVELS, AND WHY ONLY THIS:
#   The Gabor-Granger acceptance grid is already a respondent-level 0/1 answer
#   per rung, which is exactly a tabs Multi_Mention question. Willingness to
#   pay is one derived number per respondent, which is a Numeric question, and
#   it is opt-in because it is derived rather than asked.
#
#   The Van Westendorp four questions and the monadic cell and intent are
#   ALREADY tabs-native survey columns. Pricing exports nothing for them: the
#   analyst points a QuestionMap row at the original column. The
#   QUESTIONMAP_SNIPPET sheet writes those rows out as documentation so nobody
#   has to work out the wording.
#
#   Nothing model-derived is exported. Price points, demand curves and the
#   recommendation are estimated once on the whole sample; crosstabbing them
#   by banner would produce differences of exactly zero (programme decision
#   D5, and the same gate the maxdiff and conjoint exports apply).
#
# THE BASE:
#   `pricing_valid` reproduces the module's own analysed base, so a tabs table
#   whose base differs from the pricing report can be reconciled instead of
#   argued about.
#
# ==============================================================================

PRICING_TABS_EXPORT_VERSION <- "1.0.0"


#' Export Pricing Answers For Tabs
#'
#' Writes `{output}_tabs_pricing.xlsx` with three sheets: DATA (respondent id,
#' the acceptance grid, the validity flag and optionally WTP),
#' QUESTIONMAP_SNIPPET (the rows to paste into a tabs config) and METHOD (what
#' the numbers are and how they were derived).
#'
#' @param results A list with `gabor_granger` (the engine's result, which
#'   carries the coded `gg_data`), `van_westendorp`, `validation` (from
#'   `validate_pricing_data()`), `data` (the analysis data frame as loaded)
#'   and `output_path`.
#' @param config The loaded pricing configuration.
#' @param output_file Path for the workbook. Defaults to the main output's
#'   name with `_tabs_pricing.xlsx` in place of `.xlsx`.
#' @param verbose Logical, print progress.
#'
#' @return A list with structure:
#'   \item{status}{"PASS"}
#'   \item{output_file}{Path written}
#'   \item{n_exported}{Respondents written}
#'   \item{question_code}{The QuestionCode used for the grid}
#'   \item{columns}{The DATA sheet's column names}
#'   Refuses (TRS) without an ID variable, or with nothing to export.
#'
#' @export
export_pricing_for_tabs <- function(results, config, output_file = NULL,
                                    verbose = TRUE) {

  data <- results$data
  validation <- results$validation
  gg <- results$gabor_granger
  vw <- results$van_westendorp
  export_wtp <- isTRUE(config$export_wtp)

  # --- Gate 1: an ID variable, always -----------------------------------------
  # Row order is fine for a curve and useless for a join. A tabs run reads the
  # survey file and this export side by side; without a shared id there is
  # nothing to join on, and a silent row-order match would line the wrong
  # answers up against the wrong respondents.
  id_var <- config$id_var %||% NA_character_
  if (is.na(id_var) || !nzchar(as.character(id_var))) {
    pricing_refuse(
      code = "CFG_TABS_EXPORT_NO_ID",
      title = "The Tabs Export Needs An ID Variable",
      problem = "Generate_Tabs_Export is Y and ID_Variable is not set on the Settings sheet.",
      why_it_matters = paste0(
        "Tabs joins this export to the survey file by respondent id. Without ",
        "one the only match available is row order, which lines answers up ",
        "against whichever respondent happens to sit in the same row."),
      how_to_fix = "Set ID_Variable on the Settings sheet to the respondent id column in the data file."
    )
  }
  id_var <- as.character(id_var)
  if (!is.data.frame(data) || !id_var %in% names(data)) {
    pricing_refuse(
      code = "DATA_TABS_EXPORT_ID_MISSING",
      title = "The ID Variable Is Not In The Data",
      problem = sprintf("ID_Variable is '%s' and the data file has no such column.", id_var),
      why_it_matters = "The export cannot be joined to anything.",
      how_to_fix = sprintf("Check the spelling against the data file's headers. Columns read: %s",
                           paste(utils::head(names(data), 12), collapse = ", "))
    )
  }

  ids <- as.character(data[[id_var]])
  if (any(is.na(ids) | !nzchar(ids)) || anyDuplicated(ids) > 0) {
    dupes <- unique(ids[duplicated(ids)])
    pricing_refuse(
      code = "DATA_TABS_EXPORT_ID_NOT_UNIQUE",
      title = "The ID Variable Does Not Identify Respondents",
      problem = sprintf("Column '%s' has %d missing and %d repeated values.",
                        id_var, sum(is.na(ids) | !nzchar(ids)), sum(duplicated(ids))),
      why_it_matters = "A join on a repeated id multiplies rows and a join on a blank one drops them.",
      how_to_fix = paste0("Give every respondent one unique id. Repeated values include: ",
                          paste(utils::head(dupes, 5), collapse = ", "))
    )
  }

  # --- Gate 2: something to export --------------------------------------------
  has_grid <- !is.null(gg) && is.data.frame(gg$gg_data) && nrow(gg$gg_data) > 0
  if (!has_grid && !export_wtp) {
    pricing_refuse(
      code = "DATA_TABS_EXPORT_NOTHING",
      title = "Nothing To Export To Tabs",
      problem = "This run has no Gabor-Granger grid and Export_WTP is N.",
      why_it_matters = paste0(
        "The Van Westendorp questions and the monadic cell are already columns ",
        "in the survey file; tabs reads them directly through a QuestionMap ",
        "row, so the pricing module writes nothing for them."),
      how_to_fix = c(
        "Run a Gabor-Granger method, or set Export_WTP = Y to export willingness to pay.",
        "For the Van Westendorp and monadic questions, use the QUESTIONMAP_SNIPPET rows on a run that produces this file."
      )
    )
  }

  question_code <- .pricing_tabs_question_code(config)
  out <- data.frame(.id = ids, stringsAsFactors = FALSE)
  names(out) <- id_var

  # --- The acceptance grid ------------------------------------------------------
  currency <- as.character(config$currency_symbol %||% "")
  grid_prices <- numeric(0)
  grid_labels <- character(0)
  rung_answered <- integer(0)
  if (has_grid) {
    grid <- .pricing_tabs_grid(gg$gg_data, ids, id_var, currency)
    grid_prices <- grid$prices
    grid_labels <- grid$labels
    rung_answered <- grid$answered
    for (i in seq_along(grid_prices)) {
      out[[paste0(question_code, "_", i)]] <- grid$values[, i]
    }
    if (any(rung_answered < length(ids))) {
      cat(sprintf(paste0(
        "   [NOTE] Some rungs were not answered by everyone (bases %s of %d). ",
        "Tabs reports over the banner base, so those rungs read lower there ",
        "than in the pricing report. The METHOD sheet says so.\n"),
        paste(rung_answered, collapse = " / "), length(ids)))
    }
  }

  # --- The module's own analysed base -------------------------------------------
  out$pricing_valid <- .pricing_tabs_valid_flag(validation, nrow(data))

  # --- Willingness to pay, opt-in ------------------------------------------------
  wtp_col <- NULL
  wtp_source <- NULL
  wtp_censored_at <- NA_real_
  if (export_wtp) {
    wtp <- .pricing_tabs_wtp(results, config, ids, id_var)
    wtp_col <- paste0(question_code, "_WTP")
    out[[wtp_col]] <- wtp$values
    wtp_source <- wtp$source
    wtp_censored_at <- wtp$censored_at
  }

  # --- Sheets ---------------------------------------------------------------------
  coding_note <- if (has_grid) {
    gg$diagnostics$response_coding %||% gg_response_coding_note(config$gabor_granger)
  } else NA_character_

  questionmap <- .pricing_tabs_questionmap(
    question_code = question_code, prices = grid_prices, currency = currency,
    wtp_col = wtp_col, wtp_values = if (!is.null(wtp_col)) out[[wtp_col]] else NULL,
    config = config)
  options_sheet <- .pricing_tabs_options(question_code, grid_prices, currency)
  method_sheet <- .pricing_tabs_method_sheet(
    config = config, results = results, question_code = question_code,
    prices = grid_prices, currency = currency, coding_note = coding_note,
    id_var = id_var, n_exported = nrow(out), validation = validation,
    wtp_col = wtp_col, wtp_source = wtp_source, wtp_censored_at = wtp_censored_at,
    rung_answered = rung_answered, labels = grid_labels)

  # --- Write -----------------------------------------------------------------------
  if (is.null(output_file)) {
    base <- results$output_path %||% "pricing_results.xlsx"
    output_file <- sub("[.]xlsx$", "_tabs_pricing.xlsx", base)
    if (identical(output_file, base)) output_file <- paste0(base, "_tabs_pricing.xlsx")
  }
  out_dir <- dirname(output_file)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  wb <- openxlsx::createWorkbook()
  header_style <- openxlsx::createStyle(textDecoration = "bold")

  openxlsx::addWorksheet(wb, "DATA")
  openxlsx::writeData(wb, "DATA", out, headerStyle = header_style)

  openxlsx::addWorksheet(wb, "QUESTIONMAP_SNIPPET")
  openxlsx::writeData(wb, "QUESTIONMAP_SNIPPET",
                      "Paste these rows into your tabs QuestionMap sheet:",
                      startRow = 1, startCol = 1)
  openxlsx::writeData(wb, "QUESTIONMAP_SNIPPET", questionmap,
                      startRow = 2, headerStyle = header_style)
  opt_start <- nrow(questionmap) + 5
  openxlsx::writeData(wb, "QUESTIONMAP_SNIPPET",
                      "...and these rows into your Options sheet:",
                      startRow = opt_start - 1, startCol = 1)
  openxlsx::writeData(wb, "QUESTIONMAP_SNIPPET", options_sheet,
                      startRow = opt_start, headerStyle = header_style)
  openxlsx::setColWidths(wb, "QUESTIONMAP_SNIPPET", cols = 1:6,
                         widths = c(20, 62, 16, 10, 14, 60))

  openxlsx::addWorksheet(wb, "METHOD")
  openxlsx::writeData(wb, "METHOD", method_sheet, headerStyle = header_style)
  openxlsx::setColWidths(wb, "METHOD", cols = 1:2, widths = c(34, 90))

  saver <- if (exists("turas_saveWorkbook", mode = "function")) {
    turas_saveWorkbook
  } else {
    function(wb, file, overwrite = TRUE) openxlsx::saveWorkbook(wb, file, overwrite = overwrite)
  }
  saver(wb, output_file, overwrite = TRUE)

  if (verbose) {
    cat(sprintf("  Tabs export: %s (%d respondents, %d rung%s%s)\n",
                basename(output_file), nrow(out), length(grid_prices),
                if (length(grid_prices) == 1) "" else "s",
                if (!is.null(wtp_col)) ", plus WTP" else ""))
  }

  list(
    status = "PASS",
    output_file = output_file,
    n_exported = nrow(out),
    question_code = question_code,
    prices = grid_prices,
    columns = names(out),
    questionmap = questionmap,
    options = options_sheet
  )
}


# ==============================================================================
# INTERNALS
# ==============================================================================

#' The QuestionCode this export uses
#'
#' Tabs question codes are letters, digits and underscores; anything else in
#' the configured value is replaced so the column names stay valid.
#' @keywords internal
.pricing_tabs_question_code <- function(config) {
  code <- config$tabs_question_code %||% "GGACC"
  code <- trimws(as.character(code))
  if (!nzchar(code) || is.na(code)) code <- "GGACC"
  code <- gsub("[^A-Za-z0-9_]", "_", code)
  if (grepl("^[0-9]", code)) code <- paste0("Q", code)
  code
}


#' The acceptance grid as a respondent-by-rung matrix of option labels
#'
#' Built from the coded long data the engine analysed, so what is exported is
#' what was reported, imputation included.
#'
#' THE CELL HOLDS THE RUNG'S LABEL, NOT A 1. A tabs Multi_Mention counts a
#' mention by comparing the cell to the option's OptionText
#' (`calculate_row_counts()` in `modules/tabs/lib/cell_calculator.R`), so a
#' grid of 0/1 flags counts zero mentions at every rung and the whole question
#' reports 0%. Verified by execution against that function.
#'
#' Refuses when the long data's respondent ids are not the study's ids: a
#' silent row-order match here would hand tabs the wrong respondent's answers.
#'
#' @keywords internal
.pricing_tabs_grid <- function(gg_data, ids, id_var, currency = "") {
  prices <- sort(unique(gg_data$price))
  labels <- paste0(currency, formatC(prices, format = "f", digits = 2))
  long_ids <- as.character(gg_data$respondent_id)

  if (!all(long_ids %in% ids)) {
    unknown <- unique(long_ids[!long_ids %in% ids])
    pricing_refuse(
      code = "DATA_TABS_EXPORT_ID_MISMATCH",
      title = "The Gabor-Granger Ids Are Not The Study's Ids",
      problem = sprintf(paste0(
        "%d of the ladder's respondent ids are not values of '%s' (for example: %s)."),
        length(unknown), id_var, paste(utils::head(unknown, 5), collapse = ", ")),
      why_it_matters = paste0(
        "The export is joined to the survey file on the study's id. If the ",
        "ladder is keyed on something else the two would be matched by ",
        "accident or not at all."),
      how_to_fix = paste0(
        "Set Respondent_Column on the GaborGranger sheet to the same column as ",
        "ID_Variable on the Settings sheet, or leave it blank so the study's ",
        "id is used.")
    )
  }

  coded <- matrix(NA_real_, nrow = length(ids), ncol = length(prices),
                  dimnames = list(NULL, as.character(prices)))
  row_of <- match(long_ids, ids)
  col_of <- match(gg_data$price, prices)
  coded[cbind(row_of, col_of)] <- as.numeric(gg_data$response)

  # A cell is the rung's label where the respondent would buy, and missing
  # everywhere else: both "would not" and "did not answer" are absent from a
  # multi-mention, which is what tabs reads.
  values <- matrix(NA_character_, nrow = nrow(coded), ncol = ncol(coded))
  for (j in seq_along(prices)) {
    values[!is.na(coded[, j]) & coded[, j] > 0, j] <- labels[j]
  }

  list(prices = prices, labels = labels, values = values,
       answered = apply(coded, 2, function(x) sum(!is.na(x))))
}


#' The module's analysed base as a 0/1 column, in data row order
#' @keywords internal
.pricing_tabs_valid_flag <- function(validation, n_rows) {
  mask <- validation$exclusion_mask
  if (is.null(mask) || length(mask) != n_rows) return(rep(1L, n_rows))
  as.integer(!mask)
}


#' Willingness to pay, one number per respondent, in data row order
#'
#' Gabor-Granger when the ladder ran (the highest rung the respondent accepted,
#' right-censored at the top of the ladder), otherwise the Van Westendorp
#' midpoint of cheap and expensive. Which one it was is stamped on METHOD.
#'
#' @keywords internal
.pricing_tabs_wtp <- function(results, config, ids, id_var) {
  gg <- results$gabor_granger
  out <- rep(NA_real_, length(ids))

  if (!is.null(gg) && is.data.frame(gg$gg_data) && nrow(gg$gg_data) > 0) {
    df <- tryCatch(extract_wtp_gg(gg$gg_data, config), error = function(e) NULL)
    top <- max(gg$gg_data$price, na.rm = TRUE)
    if (is.data.frame(df) && nrow(df) > 0) {
      out[match(as.character(df$id), ids)] <- as.numeric(df$wtp)
    }
    return(list(values = out, source = "gabor_granger", censored_at = top))
  }

  if (!is.null(results$van_westendorp) && is.data.frame(results$data)) {
    df <- tryCatch(extract_wtp_vw(results$data, config), error = function(e) NULL)
    if (is.data.frame(df) && nrow(df) > 0) {
      out[match(as.character(df$id), ids)] <- as.numeric(df$wtp)
    }
    return(list(values = out, source = "van_westendorp", censored_at = NA_real_))
  }

  list(values = out, source = "none", censored_at = NA_real_)
}


#' The QuestionMap rows: what this export writes, and what tabs reads directly
#' @keywords internal
.pricing_tabs_questionmap <- function(question_code, prices, currency, wtp_col,
                                      wtp_values, config) {
  rows <- list()
  add <- function(code, text, type, columns, source, note) {
    rows[[length(rows) + 1]] <<- data.frame(
      QuestionCode = code, QuestionText = text, Variable_Type = type,
      Columns = columns, Data_Source = source, Note = note,
      stringsAsFactors = FALSE)
  }

  if (length(prices) > 0) {
    add(question_code,
        sprintf("Would buy at each price (Gabor-Granger, %d rungs)", length(prices)),
        "Multi_Mention", length(prices), "This export's DATA sheet",
        "Observed acceptance, one 0/1 column per rung in ascending price order.")
  }

  if (!is.null(wtp_col)) {
    rng <- if (length(wtp_values) && any(is.finite(wtp_values))) {
      sprintf("Suggested bins: %s to %s.",
              paste0(currency, format(round(min(wtp_values, na.rm = TRUE), 2), trim = TRUE)),
              paste0(currency, format(round(max(wtp_values, na.rm = TRUE), 2), trim = TRUE)))
    } else "No observed values to suggest bins from."
    add(wtp_col, "Willingness to pay (derived)", "Numeric", 1,
        "This export's DATA sheet",
        paste("Derived, not asked. See the METHOD sheet for how.", rng))
  }

  # Documentation rows. Pricing exports nothing for these: they are already
  # columns in the survey file and tabs reads them from there.
  vw <- config$van_westendorp
  vw_cols <- c(vw$col_too_cheap, vw$col_cheap, vw$col_expensive, vw$col_too_expensive)
  vw_text <- c("Price at which it is too cheap to be good quality",
               "Price at which it is a bargain",
               "Price at which it starts to feel expensive",
               "Price at which it is too expensive to consider")
  for (i in seq_along(vw_cols)) {
    if (is.null(vw_cols[i]) || is.na(vw_cols[i]) || !nzchar(vw_cols[i])) next
    add(vw_cols[i], vw_text[i], "Numeric", 1, "The survey data file, directly",
        "Documentation row. This export writes nothing for it; point the QuestionMap at the survey column.")
  }
  mon <- config$monadic
  if (!is.null(mon$price_column) && !is.na(mon$price_column) && nzchar(mon$price_column)) {
    add(mon$price_column, "Price shown to this respondent (monadic cell)", "Single_Response", 1,
        "The survey data file, directly",
        "Documentation row. Use it as a banner or a filter; the cell is the design, not an answer.")
  }
  if (!is.null(mon$intent_column) && !is.na(mon$intent_column) && nzchar(mon$intent_column)) {
    add(mon$intent_column, "Would buy at the price shown (monadic)", "Single_Response", 1,
        "The survey data file, directly",
        "Documentation row. This export writes nothing for it.")
  }

  if (length(rows) == 0) {
    return(data.frame(QuestionCode = character(0), QuestionText = character(0),
                      Variable_Type = character(0), Columns = numeric(0),
                      Data_Source = character(0), Note = character(0),
                      stringsAsFactors = FALSE))
  }
  do.call(rbind, rows)
}


#' The Options rows: one per rung, carrying the price with its currency
#'
#' KEYED BY COLUMN, NOT BY QUESTION. A tabs Multi_Mention looks its options up
#' with `^{code}_[0-9]+$` against the Options sheet's QuestionCode
#' (`question_orchestrator.R`), so each rung's row is keyed `GGACC_1`,
#' `GGACC_2` and so on. Rows keyed by the bare question code, which is the
#' Allocation convention, match nothing: every answer is then reported as an
#' unmatched value and the question is dropped from the report. Found by
#' running the integrated demo.
#'
#' @keywords internal
.pricing_tabs_options <- function(question_code, prices, currency) {
  cols <- c("QuestionCode", "OptionText", "DisplayText", "ShowInOutput", "DisplayOrder")
  if (length(prices) == 0) {
    empty <- as.data.frame(setNames(rep(list(character(0)), length(cols)), cols),
                           stringsAsFactors = FALSE)
    return(empty)
  }
  labels <- paste0(currency, formatC(prices, format = "f", digits = 2))
  data.frame(
    QuestionCode = paste0(question_code, "_", seq_along(prices)),
    OptionText = labels,
    DisplayText = labels,
    ShowInOutput = "Y",
    DisplayOrder = seq_along(prices),
    stringsAsFactors = FALSE
  )
}


#' The METHOD sheet: what the numbers are, in the operator's hands
#' @keywords internal
.pricing_tabs_method_sheet <- function(config, results, question_code, prices,
                                       currency, coding_note, id_var, n_exported,
                                       validation, wtp_col, wtp_source,
                                       wtp_censored_at, rung_answered, labels) {
  add <- function(df, item, value) {
    rbind(df, data.frame(Item = item, Value = as.character(value),
                         stringsAsFactors = FALSE))
  }
  df <- data.frame(Item = character(0), Value = character(0), stringsAsFactors = FALSE)

  df <- add(df, "What this is", paste0(
    "Respondent-level pricing answers in the shape tabs reads. Nothing here is ",
    "model-derived: the acceptance grid is what respondents said, and the ",
    "willingness-to-pay column, when present, is arithmetic on what they said."))

  if (length(prices) > 0) {
    df <- add(df, "Acceptance grid", sprintf(
      "%s_1 .. %s_%d, one column per rung in ascending price order (%s).",
      question_code, question_code, length(prices), paste(labels, collapse = ", ")))
    df <- add(df, "Cell contract", paste0(
      "A cell holds the rung's own label where the respondent said they would ",
      "buy, and is empty otherwise. That is what a tabs Multi_Mention counts: ",
      "it compares each cell to the option's OptionText, so a grid of 0s and 1s ",
      "would report zero at every price. The Options rows below carry exactly ",
      "these labels, and each is keyed by its COLUMN name (", question_code,
      "_1 and so on), which is how a Multi_Mention looks its options up. Keyed ",
      "by the bare question code they would match nothing."))
    df <- add(df, "Coding rule", coding_note)
    gg_diag <- results$gabor_granger$diagnostics %||% list()
    imputation <- as.character(gg_diag$imputation %||% "none")
    df <- add(df, "Stop-early imputation", if (identical(imputation, "none")) {
      "None. Every exported cell is an answer the respondent gave."
    } else {
      paste0(imputation, ". Those rungs are exported as 'would not buy', the ",
             "same as the analysis used.")
    })
    df <- add(df, "Variable type in tabs",
              "Multi_Mention. Tabs reports the share who would buy at each price, over whatever base the banner defines.")
    if (length(rung_answered) == length(prices)) {
      df <- add(df, "Per-rung answered base", paste0(
        paste(rung_answered, collapse = " / "),
        ". The pricing report divides by these; tabs divides by the banner base. ",
        "Where they differ, a rung with unanswered cells reads lower in tabs. ",
        "Filter on pricing_valid, and read this row, before reconciling the two."))
    }
  }

  if (!is.null(wtp_col)) {
    how <- switch(wtp_source,
      "gabor_granger" = paste0(
        "The highest rung the respondent said they would buy at. ",
        "RIGHT-CENSORED at ", currency,
        formatC(wtp_censored_at, format = "f", digits = 2),
        ": a respondent who accepted the top rung would pay at least that, and ",
        "the ladder cannot say how much more. Treat the mean as a lower bound."),
      "van_westendorp" = paste0(
        "The midpoint of the respondent's own 'bargain' and 'expensive' prices. ",
        "It is a derived indifference point, not an answer, and it exists for ",
        "every respondent who answered both questions."),
      "No willingness-to-pay source was available on this run.")
    df <- add(df, "Willingness to pay", paste0(wtp_col, ". ", how))
  }

  n_valid <- validation$n_valid %||% NA_integer_
  df <- add(df, "pricing_valid", paste0(
    "1 for the respondents the pricing module analysed, 0 for those its ",
    "validation excluded (", format(validation$n_excluded %||% 0L),
    " of ", format(validation$n_total %||% n_exported),
    "). Filter on it to reproduce the pricing report's base; leave it out and ",
    "a tabs base will be larger."))
  df <- add(df, "Respondents exported", n_exported)
  df <- add(df, "Analysed base in the pricing report", n_valid)
  df <- add(df, "Id column", paste0(
    id_var, ". One row per respondent, joined to the survey file on this column."))

  weight_var <- config$weight_var %||% NA_character_
  df <- add(df, "Weighting", if (is.na(weight_var) || !nzchar(as.character(weight_var))) {
    paste0("The pricing estimates are unweighted. Tabs applies its own weights, ",
           "if any, when it reports these columns.")
  } else {
    paste0("The pricing report's estimates are weighted by ", as.character(weight_var),
           ". The columns in this export are raw answers, not weighted values; ",
           "tabs weights them again at reporting time. Two weighted numbers can ",
           "still differ if the tabs weight is not this one.")
  })
  df <- add(df, "What is NOT here", paste0(
    "The Van Westendorp price points, the demand and revenue curves and the ",
    "recommended price. Those are estimated once on the whole sample, so a ",
    "banner break of them would show differences of exactly zero. They are on ",
    "the Pricing tab of the report and in the Excel deliverable."))
  df <- add(df, "Module", sprintf("Turas Pricing %s, tabs export %s",
                                  if (exists("PRICING_VERSION")) PRICING_VERSION else "?",
                                  PRICING_TABS_EXPORT_VERSION))
  df <- add(df, "Generated", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  df
}
