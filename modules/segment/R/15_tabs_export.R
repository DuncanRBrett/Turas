# ==============================================================================
# SEGMENT -> TABS BANNER EXPORT
# ==============================================================================
# export_segment_assignments()'s docstring has described its output as "the
# join table that feeds the segment-as-banner workflow in tabs" since it was
# written, and nothing implemented that workflow: the review found zero
# consumers of the file outside this module. Duncan merged the column into his
# survey file by hand and declared the banner by hand, every time.
#
# This is that bridge. It does the join, refuses rather than guessing when the
# join is not clean, and writes the rows tabs needs in order to treat the
# segment column as a banner.
#
# The honesty rules it keeps (V2 lift D5, and the segment review's section 8):
#   - segment membership is a MODEL-DERIVED grouping from unweighted
#     clustering, and the stub says so where a reader will see it;
#   - significance tests across segments ON THE CLUSTERING VARIABLES are
#     in-sample and flattering, and the stub says that too;
#   - GMM membership probabilities are estimates and never enter the survey
#     file, where they would be one join away from being used as weights.
# ==============================================================================

#' The wording tabs readers see about where this banner came from
#' @keywords internal
SEGMENT_BANNER_PROVENANCE <- paste(
  "Model-derived grouping from unweighted clustering.",
  "Significance tests across these segments on the clustering variables",
  "themselves are in-sample and will flatter the solution.",
  "Segment sizes under a weighted tabs run will differ from the",
  "segmentation report, which is unweighted."
)

#' Columns that must never travel into the survey file
#' @keywords internal
SEGMENT_EXPORT_BLOCKED <- c("^prob_", "^max_probability$", "^uncertainty$",
                            "^outlier_flag$", "^segment_id$")


#' Join Segment Membership onto the Survey File for Tabs
#'
#' @param assignments Data frame with the id variable and segment_name
#' @param survey_file Path to the survey data file
#' @param survey_sheet Sheet name within the survey file
#' @param id_variable The respondent key, which must be in BOTH files
#' @param output_file Where to write the joined survey file
#' @param allow_partial_join TRUE to permit rows with no segment
#' @param verbose Print progress
#' @return A list with status ("PASS" or "PARTIAL"), the counts and the paths
#' @export
segment_export_for_tabs <- function(assignments,
                                    survey_file,
                                    survey_sheet,
                                    id_variable,
                                    output_file,
                                    allow_partial_join = FALSE,
                                    verbose = TRUE) {

  if (verbose) cat("\n  Building the tabs banner export...\n")

  # --- the survey file -------------------------------------------------------
  if (!file.exists(survey_file)) {
    segment_refuse(
      code = "IO_SURVEY_FILE_MISSING",
      title = "Survey File Not Found",
      problem = sprintf("The survey file was not found: %s", survey_file),
      why_it_matters = "The segment column has to be joined onto the survey file tabs will read.",
      how_to_fix = c("Check data_file in the config.",
                     "Run the export from the project folder the config points at."),
      observed = survey_file
    )
  }

  survey <- .segment_read_survey(survey_file, survey_sheet)

  # --- the key ---------------------------------------------------------------
  missing_in <- c(
    if (!id_variable %in% names(survey)) "the survey file",
    if (!id_variable %in% names(assignments)) "the segment assignments"
  )
  if (length(missing_in) > 0) {
    segment_refuse(
      code = "DATA_ID_NOT_FOUND",
      title = "ID Variable Not in Both Files",
      problem = sprintf("'%s' is missing from %s.", id_variable,
                        paste(missing_in, collapse = " and ")),
      why_it_matters = paste(
        "The join is by respondent. Without the same key in both files there",
        "is no way to say which respondent is in which segment, and a",
        "positional guess would silently mislabel people."
      ),
      how_to_fix = c(
        sprintf("Check id_variable in the config. It is currently '%s'.", id_variable),
        "Check the spelling and case against the survey file's header row."
      ),
      expected = id_variable,
      observed = paste(utils::head(names(survey), 12), collapse = ", ")
    )
  }

  survey_ids <- as.character(survey[[id_variable]])
  assign_ids <- as.character(assignments[[id_variable]])

  # --- uniqueness ------------------------------------------------------------
  for (side in list(list(ids = assign_ids, what = "segment assignments"),
                    list(ids = survey_ids, what = "survey file"))) {
    dups <- unique(side$ids[duplicated(side$ids)])
    if (length(dups) > 0) {
      segment_refuse(
        code = "DATA_DUPLICATE_IDS",
        title = "Duplicate Respondent IDs",
        problem = sprintf(
          "The %s has %d duplicate value(s) of '%s', for example: %s.",
          side$what, length(dups), id_variable,
          paste(utils::head(dups, 5), collapse = ", ")),
        why_it_matters = paste(
          "A duplicate key turns a join into a multiplication: rows would be",
          "repeated and the banner's bases would be larger than the study."
        ),
        how_to_fix = c(
          "De-duplicate the file on the ID variable.",
          "Or pick an ID variable that really is one row per respondent."
        ),
        observed = paste(utils::head(dups, 5), collapse = ", ")
      )
    }
  }

  # --- the join --------------------------------------------------------------
  # match() rather than merge(): merge reorders, and tabs matches rows by
  # position in several places, so a reordered file is a different study.
  idx <- match(survey_ids, assign_ids)
  n_matched <- sum(!is.na(idx))
  n_unmatched <- length(survey_ids) - n_matched

  segment_col <- rep(NA_character_, length(survey_ids))
  segment_col[!is.na(idx)] <- as.character(assignments$segment_name[idx[!is.na(idx)]])
  # An outlier carries no segment, and so does an unmatched row. Both read as
  # "Unassigned" in the banner, which is the same word 09_output.R uses.
  segment_col[is.na(segment_col)] <- "Unassigned"

  if (n_unmatched > 0) {
    pct <- 100 * n_unmatched / length(survey_ids)
    if (!isTRUE(allow_partial_join)) {
      segment_refuse(
        code = "DATA_PARTIAL_JOIN",
        title = "Not Every Respondent Got a Segment",
        problem = sprintf(
          "%d of %d survey rows (%.1f%%) have no segment: their '%s' is not in the assignments.",
          n_unmatched, length(survey_ids), pct, id_variable),
        why_it_matters = paste(
          "Those rows would become an 'Unassigned' banner column that reads",
          "like a finding about people, when it is really a record of what the",
          "join lost. Nothing downstream can tell the two apart."
        ),
        how_to_fix = c(
          "Check that the segmentation ran on this same survey file.",
          "Check the ID variable matches in type and formatting, for example leading zeros.",
          "If the gap is real and expected, such as respondents excluded by missing data, set allow_partial_join = YES in the config."
        ),
        expected = sprintf("%d matched", length(survey_ids)),
        observed = sprintf("%d matched, %d not", n_matched, n_unmatched)
      )
    }
    if (verbose) {
      cat(sprintf("  [SEGMENT] Partial join allowed: %d of %d rows (%.1f%%) are Unassigned.\n",
                  n_unmatched, length(survey_ids), pct))
    }
  }

  # --- write the joined survey file -----------------------------------------
  # Nothing but the segment name travels. GMM probabilities, the outlier flag
  # and the numeric segment id stay in segment_assignments.xlsx (C-3).
  out <- survey
  out$segment_name <- segment_col

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, survey_sheet)
  openxlsx::writeData(wb, survey_sheet, out,
                      headerStyle = openxlsx::createStyle(textDecoration = "bold"))
  .segment_save_workbook(wb, output_file)

  if (verbose) {
    cat(sprintf("  Joined survey file: %s\n", basename(output_file)))
    cat(sprintf("    %d rows, %d matched, %d unassigned\n",
                nrow(out), n_matched, n_unmatched))
  }

  list(
    status = if (n_unmatched > 0) "PARTIAL" else "PASS",
    output_file = output_file,
    n_rows = nrow(out),
    n_matched = n_matched,
    n_unmatched = n_unmatched,
    segment_column = "segment_name",
    segments = sort(unique(segment_col))
  )
}


#' Read a Survey File, Whatever Extension It Has
#' @keywords internal
.segment_read_survey <- function(path, sheet = NULL) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("xlsx", "xlsm")) {
    sheets <- openxlsx::getSheetNames(path)
    use <- if (!is.null(sheet) && nzchar(sheet) && sheet %in% sheets) sheet else sheets[1]
    # skipEmptyRows = FALSE always: the default compacts blank rows and shifts
    # every row index, which would silently re-key the join (project CLAUDE.md).
    openxlsx::read.xlsx(path, sheet = use, skipEmptyRows = FALSE)
  } else if (ext == "csv") {
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    segment_refuse(
      code = "IO_UNSUPPORTED_FORMAT",
      title = "Unsupported Survey File Format",
      problem = sprintf("The survey file is a .%s, which this export cannot read.", ext),
      why_it_matters = "The segment column has to be written back into a file tabs can read.",
      how_to_fix = "Save the survey data as .xlsx or .csv.",
      observed = ext
    )
  }
}


#' Save a Workbook Through the Shared Saver
#' @keywords internal
.segment_save_workbook <- function(wb, path) {
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    res <- turas_save_workbook_atomic(wb, path, module = "SEGMENT")
    if (!isTRUE(res$success)) {
      segment_refuse(
        code = "IO_WRITE_FAILED",
        title = "Could Not Write the Export",
        problem = sprintf("Writing %s failed: %s", basename(path), res$error %||% "unknown"),
        why_it_matters = "Without the file there is no banner to declare.",
        how_to_fix = c("Close the file if it is open in Excel.",
                       "Check the output folder exists and is writable.")
      )
    }
  } else {
    cat("[TRS WARNING] Saving without part reconciliation: ",
        "modules/shared/lib/import_all.R is not loaded, so Excel may ",
        "report a problem with this file and offer to repair it.\n", sep = "")
    openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  }
  invisible(path)
}


#' Write the Rows Tabs Needs to Treat the Segment Column as a Banner
#'
#' Three sheets, one per place the rows have to be pasted, plus a sheet saying
#' where each goes. The shapes follow `examples/tabs/basic/Survey_Structure.xlsx`
#' and the Selection sheet of its `tabs_config.xlsx`.
#'
#' @param segments The segment names exactly as they appear in the data
#' @param column_name The column the segment names were written to
#' @param output_file Where to write the stub
#' @param banner_label Header shown above the banner columns
#' @param display_order Position among the banners, a single digit
#' @param verbose Print progress
#' @return invisible(output_file)
#' @export
segment_write_banner_stub <- function(segments,
                                      column_name = "segment_name",
                                      output_file,
                                      banner_label = "Segments",
                                      display_order = 1,
                                      verbose = TRUE) {

  segments <- unique(as.character(segments))
  segments <- segments[!is.na(segments) & nzchar(segments)]

  if (length(segments) == 0) {
    segment_refuse(
      code = "DATA_NO_SEGMENTS",
      title = "No Segments to Declare",
      problem = "The banner stub was asked for with no segment names.",
      why_it_matters = "A banner with no columns is not a banner.",
      how_to_fix = "Run the segmentation first, then export."
    )
  }

  # DisplayOrder is sorted as TEXT in modules/tabs/lib/banner.R, so 10 would
  # come before 2. Single digit only, and say why rather than truncating.
  if (nchar(as.character(display_order)) > 1) {
    segment_refuse(
      code = "CFG_DISPLAY_ORDER_TOO_LONG",
      title = "Banner DisplayOrder Must Be a Single Digit",
      problem = sprintf("display_order is %s.", display_order),
      why_it_matters = paste(
        "Tabs sorts banner DisplayOrder as text, so 10 sorts before 2 and the",
        "banners come out in an order nobody chose."
      ),
      how_to_fix = "Use a single digit, 1 to 9.",
      expected = "1 to 9",
      observed = as.character(display_order)
    )
  }

  questions <- data.frame(
    QuestionCode = column_name,
    QuestionText = banner_label,
    Variable_Type = "Single_Response",
    Columns = 1L,
    Notes = SEGMENT_BANNER_PROVENANCE,
    stringsAsFactors = FALSE
  )

  # OptionText must be the EXACT value in the data file, case and spacing
  # included: tabs matches on it literally, and a near-miss silently drops the
  # column from the banner.
  options_df <- data.frame(
    QuestionCode = column_name,
    OptionText = segments,
    DisplayText = segments,
    DisplayOrder = seq_along(segments),
    ShowInOutput = "Y",
    stringsAsFactors = FALSE
  )

  # Column order and names follow the Selection sheet of a real tabs config
  # (examples/tabs/basic/tabs_config.xlsx), so these paste in line for line.
  #
  # BannerBoxCategory is NOT optional padding. process_banner_question() reads
  # it as `!is.na(x) && x == "Y"`, so a missing column makes that NA and the
  # whole banner build dies on "missing value where TRUE/FALSE needed". Found
  # by feeding this stub to tabs' own banner builder.
  selection <- data.frame(
    QuestionCode = column_name,
    Include = "N",
    UseBanner = "Y",
    BannerBoxCategory = "N",
    BannerLabel = banner_label,
    DisplayOrder = as.integer(display_order),
    CreateIndex = "N",
    stringsAsFactors = FALSE
  )

  how_to <- data.frame(
    Sheet = c("Questions", "Options", "Selection"),
    Paste_into = c(
      "Survey_Structure.xlsx, the Questions sheet",
      "Survey_Structure.xlsx, the Options sheet",
      "Your tabs config workbook, the Selection sheet"
    ),
    Note = c(
      "One row. Variable_Type is Single_Response because each respondent is in exactly one segment.",
      "One row per segment. OptionText must stay exactly as written here: tabs matches it against the data literally.",
      "One row. Include is N because the segment column is a banner, not a question to tabulate. Set Include to Y as well if you also want it as a stub."
    ),
    stringsAsFactors = FALSE
  )

  provenance <- data.frame(
    About = c("Where this came from", "What to be careful of", "Weighting"),
    Detail = c(
      "The segment column was written by the Turas segment module and joined onto the survey file by respondent ID.",
      paste("Segment membership is a model-derived grouping, not something a respondent answered.",
            "Significance tests across segments on the clustering variables themselves are in-sample and will flatter the solution."),
      "Clustering is unweighted. A weighted tabs run will show different segment sizes from the segmentation report."
    ),
    stringsAsFactors = FALSE
  )

  wb <- openxlsx::createWorkbook()
  header <- openxlsx::createStyle(textDecoration = "bold")
  for (nm in c("How_to_use", "Questions", "Options", "Selection", "Provenance")) {
    openxlsx::addWorksheet(wb, nm)
  }
  openxlsx::writeData(wb, "How_to_use", how_to, headerStyle = header)
  openxlsx::writeData(wb, "Questions", questions, headerStyle = header)
  openxlsx::writeData(wb, "Options", options_df, headerStyle = header)
  openxlsx::writeData(wb, "Selection", selection, headerStyle = header)
  openxlsx::writeData(wb, "Provenance", provenance, headerStyle = header)
  openxlsx::setColWidths(wb, "How_to_use", cols = 1:3, widths = c(14, 46, 90))
  openxlsx::setColWidths(wb, "Questions", cols = 1:5, widths = c(18, 22, 18, 10, 100))
  openxlsx::setColWidths(wb, "Options", cols = 1:5, widths = c(18, 26, 26, 14, 14))
  openxlsx::setColWidths(wb, "Selection", cols = 1:7, widths = c(18, 10, 12, 20, 18, 14, 14))
  openxlsx::setColWidths(wb, "Provenance", cols = 1:2, widths = c(24, 100))

  .segment_save_workbook(wb, output_file)
  if (verbose) cat(sprintf("  Banner stub: %s (%d segments)\n",
                           basename(output_file), length(segments)))
  invisible(output_file)
}
