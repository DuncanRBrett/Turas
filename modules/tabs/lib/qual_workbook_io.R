# ==============================================================================
# TABS MODULE — QUALITATIVE WORKBOOK I/O (openxlsx reader + TRS refusals)
# ==============================================================================
#
# The I/O boundary for the qualitative reader: opens a coded-comment workbook,
# normalises each sheet to character rows, and runs the pure per-sheet classifier
# (qual_workbook_reader.R). Hard failures (missing/unreadable file, no usable
# open-end question) raise TRS refusals that print to the Shiny console; a single
# unreadable sheet is logged and skipped, never aborting the whole workbook.
#
# Depends on (sourced by the pipeline): qual_workbook_reader.R, trs_refusal.R.
#
# Run the tests with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_workbook_io.R")
# ==============================================================================

#' Read one worksheet into a list of normalised character rows.
#'
#' Reads the full used range (preamble + header + data) with no header inference,
#' so the pure classifier can locate the floating header itself.
#' @param path Path to the .xlsx workbook.
#' @param sheet Sheet name.
#' @return A list of normalised character vectors (one per row); empty list when blank.
qual_read_sheet_rows <- function(path, sheet) {
  df <- suppressWarnings(openxlsx::read.xlsx(
    path, sheet = sheet, colNames = FALSE,
    skipEmptyRows = FALSE, skipEmptyCols = FALSE, detectDates = FALSE
  ))
  if (is.null(df) || !nrow(df)) return(list())
  grid <- as.matrix(df)
  lapply(seq_len(nrow(grid)), function(i) qual_norm_cells(grid[i, ]))
}

#' Classify every sheet of a workbook, partitioning into usable questions and skips.
#' @param path Path to the workbook.
#' @param sheets Character vector of sheet names.
#' @return list(questions, skipped) — `skipped` entries carry `sheet` and `reason`.
qual_classify_all_sheets <- function(path, sheets) {
  questions <- list()
  skipped <- list()
  for (sheet in sheets) {
    rows <- tryCatch(qual_read_sheet_rows(path, sheet),
                     error = function(e) NULL)
    if (is.null(rows)) {
      skipped[[length(skipped) + 1L]] <- list(sheet = sheet, reason = "read_error")
      next
    }
    question <- qual_classify_sheet(rows, sheet)
    if (isTRUE(question$skip)) {
      skipped[[length(skipped) + 1L]] <- list(sheet = sheet, reason = question$reason)
    } else {
      questions[[length(questions) + 1L]] <- question
    }
  }
  list(questions = questions, skipped = skipped)
}

#' Print a one-line console summary of what was read (Shiny visibility).
#' @param path Workbook path.
#' @param questions List of usable questions.
#' @param skipped List of skipped sheets.
#' @return Invisibly NULL.
qual_log_workbook_summary <- function(path, questions, skipped) {
  themed <- sum(vapply(questions, function(q) identical(q$type, "themed"), logical(1)))
  cat(sprintf("[TABS/qual] %s: %d question(s) (%d themed, %d raw), %d sheet(s) skipped.\n",
              basename(path), length(questions), themed,
              length(questions) - themed, length(skipped)))
  invisible(NULL)
}

# ---- TRS refusals (one per hard failure; each always throws) ------------------

#' Refuse: the configured qual workbook does not exist.
qual_refuse_file_missing <- function(path, module) {
  shown <- if (is.null(path) || !nzchar(path)) "(none)" else path
  turas_refuse(
    code = "IO_QUAL_FILE_MISSING", title = "Qualitative workbook not found",
    problem = sprintf("The coded-comment workbook '%s' does not exist.", shown),
    why_it_matters = paste("Without the comment workbook the Qualitative tab has no",
                           "data, so the report would silently omit the open-ends."),
    how_to_fix = c("Check the qual_workbook path in the crosstab Settings sheet.",
                   "Confirm the file exists and is an .xlsx workbook."),
    module = module
  )
}

#' Refuse: the workbook could not be opened / has no worksheets.
qual_refuse_unreadable <- function(path, module) {
  turas_refuse(
    code = "IO_QUAL_UNREADABLE", title = "Qualitative workbook unreadable",
    problem = sprintf("Could not read any worksheets from '%s'.", path),
    why_it_matters = paste("An unreadable or empty workbook means no comments can be",
                           "presented; proceeding would hide a data problem."),
    how_to_fix = c("Open the file in Excel to confirm it is a valid .xlsx with worksheets.",
                   "Re-export the comment workbook if it is corrupt."),
    module = module
  )
}

#' Refuse: no sheet looked like a coded-comment question.
qual_refuse_no_questions <- function(path, sheets, module) {
  turas_refuse(
    code = "DATA_QUAL_NO_QUESTIONS", title = "No open-end questions found",
    problem = sprintf("None of the %d sheets in '%s' looked like a coded-comment question.",
                      length(sheets), basename(path)),
    why_it_matters = paste("If no sheet has an ID-anchored header and a verbatim column,",
                           "the workbook is not in the expected shape and the tab would be empty."),
    how_to_fix = c(paste("Confirm each question sheet has a header row beginning with",
                         "'ID' or 'Response ID' and a comment/verbatim column."),
                   "See modules/tabs/docs/QUALITATIVE_TAB_BUILD_NOTES.md for the expected structure."),
    observed = sheets, module = module
  )
}

#' Read and classify a coded-comment workbook into qual questions.
#'
#' Opens the workbook, classifies every sheet, and returns the usable open-end
#' questions plus a log of skipped sheets. Raises a TRS refusal when the file is
#' missing or unreadable, or when no sheet yields a usable open-end question.
#'
#' @param path Path to the .xlsx workbook.
#' @param module Module label for refusal display.
#' @return list(status = "PASS", path, n_sheets, questions, skipped).
#' @examples
#' \dontrun{
#'   res <- with_refusal_handler(qual_read_workbook("comments.xlsx"))
#'   if (!is_refusal(res)) length(res$questions)
#' }
qual_read_workbook <- function(path, module = "TABS") {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) {
    qual_refuse_file_missing(path, module)
  }
  sheets <- tryCatch(openxlsx::getSheetNames(path), error = function(e) NULL)
  if (is.null(sheets) || !length(sheets)) {
    qual_refuse_unreadable(path, module)
  }
  parsed <- qual_classify_all_sheets(path, sheets)
  if (!length(parsed$questions)) {
    qual_refuse_no_questions(path, sheets, module)
  }
  qual_log_workbook_summary(path, parsed$questions, parsed$skipped)
  list(status = "PASS", path = path, n_sheets = length(sheets),
       questions = parsed$questions, skipped = parsed$skipped)
}
