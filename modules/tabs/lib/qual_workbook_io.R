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
  # Integrity first: "verbatim column ambiguous" is a far more actionable
  # message than "no questions found" when the ambiguity is why a sheet skipped.
  qual_check_workbook_integrity(path, parsed, module)
  if (!length(parsed$questions)) {
    qual_refuse_no_questions(path, sheets, module)
  }
  qual_log_workbook_summary(path, parsed$questions, parsed$skipped)
  list(status = "PASS", path = path, n_sheets = length(sheets),
       questions = parsed$questions, skipped = parsed$skipped)
}

#' Enforce workbook integrity (production review 2026-08, I17/I18).
#'
#' Refuses on: a sheet whose verbatim column could not be told apart from a
#' second prose column (the reader used to GUESS — an analyst's notes column
#' could ship as respondent quotes); blank ResponseIDs on rows that carry text
#' (later stages silently drop them, comments vanish); duplicated ResponseIDs
#' within one sheet (reader marks collide, bases inflate); and hide-LIKE markers
#' that are not exact hide tokens ("hide!" used to make a comment MORE visible).
#' Unrecognised noteworthy markers are reported (tier-1 catch-all is documented
#' behaviour), and the hide-marked counts are stated per sheet.
#'
#' @param path Workbook path (for messages).
#' @param parsed The qual_classify_all_sheets() result.
#' @param module Module label for refusal display.
#' @return Invisibly NULL; refuses on integrity failures.
qual_check_workbook_integrity <- function(path, parsed, module = "TABS") {
  amb <- Filter(function(s) identical(s$reason, "verbatim_ambiguous"), parsed$skipped)
  if (length(amb)) {
    detail <- vapply(amb, function(s) {
      sprintf("%s (candidate columns: %s)", s$sheet,
              paste(s$ambiguous_columns, collapse = " / "))
    }, character(1))
    turas_refuse(
      code = "DATA_QUAL_VERBATIM_AMBIGUOUS", title = "Verbatim column is ambiguous",
      problem = sprintf("Sheet(s) in '%s' have more than one prose-length column and no 'Comment' header: %s",
                        basename(path), paste(detail, collapse = "; ")),
      why_it_matters = paste("The reader would have to GUESS which column holds the respondent",
                             "verbatims - guessing wrong ships an analyst's working notes as quotes."),
      how_to_fix = c("Name the verbatim column 'Comment' (or 'Verbatim') on those sheets.",
                     "Move analyst working-notes columns to the LEFT of the ID column or delete them."),
      module = module
    )
  }

  for (q in parsed$questions) {
    integ <- q$integrity
    if (is.null(integ)) next
    if (length(integ$hide_like_markers)) {
      turas_refuse(
        code = "DATA_QUAL_HIDE_MARKER_INVALID", title = "Hide marker not recognised",
        problem = sprintf("Sheet '%s' has noteworthy marks that LOOK like hide but are not exact: %s",
                          q$sheet, paste(sQuote(integ$hide_like_markers), collapse = ", ")),
        why_it_matters = paste("Only 'hide'/'hidden' withhold a verbatim. Anything else is promoted",
                               "to noteworthy - the report would SHIP the exact comments the analyst",
                               "meant to suppress."),
        how_to_fix = c("Change those cells to exactly 'hide' (or 'hidden').",
                       "Valid marks: hide, n (noteworthy), m (must-read), p (priority)."),
        module = module
      )
    }
    if (length(integ$blank_id_rows)) {
      turas_refuse(
        code = "DATA_QUAL_BLANK_ID", title = "Comment row without a ResponseID",
        problem = sprintf("Sheet '%s' has %d comment row(s) with text but no ID (row %s)",
                          q$sheet, length(integ$blank_id_rows),
                          paste(integ$blank_id_rows, collapse = ", ")),
        why_it_matters = paste("A row without an ID cannot join the survey and is silently dropped",
                               "from every output - including any priority comment on it."),
        how_to_fix = c("Restore the ResponseID on those rows (check against the export),",
                       "or delete the rows if they are not respondent comments."),
        module = module
      )
    }
    if (length(integ$dup_ids)) {
      turas_refuse(
        code = "DATA_QUAL_DUPLICATE_ID", title = "Duplicated ResponseID in one sheet",
        problem = sprintf("Sheet '%s' repeats ResponseID(s): %s",
                          q$sheet, paste(integ$dup_ids, collapse = ", ")),
        why_it_matters = paste("Duplicates share one internal index: bases inflate, and a reader's",
                               "shortlist or highlight lands on the OTHER duplicate's text."),
        how_to_fix = c("Keep one row per respondent per sheet (merge or delete the duplicate).",
                       "If two comments are genuine, combine them into one cell."),
        module = module
      )
    }
    if (length(integ$unrecognised_markers)) {
      um <- integ$unrecognised_markers
      cat(sprintf("[TABS/qual] %s: unrecognised noteworthy mark(s) treated as tier-1 noteworthy: %s\n",
                  q$sheet,
                  paste(sprintf("'%s' x%d", names(um), as.integer(um)), collapse = ", ")))
    }
    if (isTRUE(integ$n_hidden > 0)) {
      cat(sprintf("[TABS/qual] %s: %d comment(s) hide-marked - counted, text withheld.\n",
                  q$sheet, integ$n_hidden))
    }
  }
  invisible(NULL)
}
