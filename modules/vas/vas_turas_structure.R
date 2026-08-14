# vas_turas_structure.R
# ------------------------------------------------------------------------------
# Generate the Turas configuration for the VAS dataset: the Survey_Structure
# workbook (Project / Questions / Options) and the Crosstab_Config workbook
# (Settings / Selection).
#
# Everything is generated from the same inputs the data is built from - the
# survey snapshot, the column plan and the derived-variable dictionary - so
# the configuration cannot drift from the data. OptionText carries the option
# VALUE (what the export writes into a cell); DisplayText carries the option
# title (what a reader should see).
# ------------------------------------------------------------------------------

# The starter banner set. Duncan curates the Selection sheet afterwards; these
# are only sensible defaults so the first run renders a real report.
VAS_TURAS_BANNERS <- c("Province", "AreaType", "Gender", "Race", "IncomeBand")

#' Read every question's options out of the survey snapshot
#'
#' @param snapshot_json_path The alch_snapshot JSON path.
#'
#' @return A data frame: alias, position, value, title.
read_snapshot_options <- function(snapshot_json_path) {
  snapshot <- jsonlite::fromJSON(snapshot_json_path, simplifyVector = FALSE)
  rows <- list()
  for (page in snapshot$pages) {
    for (question in page$questions) {
      alias <- question$shortname
      if (is.null(alias) || !nzchar(alias)) {
        next
      }
      for (i in seq_along(question$options)) {
        option <- question$options[[i]]
        rows[[length(rows) + 1L]] <- data.frame(
          alias = alias, position = i,
          value = as.character(option$value %||% ""),
          title = as.character(option$title$English %||% option$value %||% ""),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  return(do.call(rbind, rows))
}

#' The Questions and Options rows for the kept survey content
#'
#' @param plan The column plan data frame.
#' @param index The survey index data frame.
#' @param options The data frame from \code{read_snapshot_options()}.
#' @param town_values Observed Town values, for the merged Town question.
#'
#' @return A list of \code{questions} and \code{options} data frames.
content_structure_rows <- function(plan, index, options, town_values) {
  questions <- list()
  option_rows <- list()
  add_question <- function(code, text, type, columns) {
    questions[[length(questions) + 1L]] <<- data.frame(
      QuestionCode = code, QuestionText = text, Variable_Type = type,
      Columns = columns, stringsAsFactors = FALSE)
  }
  add_option <- function(code, value, title, order) {
    option_rows[[length(option_rows) + 1L]] <<- data.frame(
      QuestionCode = code, OptionText = value, DisplayText = title,
      DisplayOrder = order, stringsAsFactors = FALSE)
  }

  question_text <- function(alias) {
    text <- index$q_title[match(alias, index$alias)]
    return(if (length(text) != 1L || is.na(text)) alias else text)
  }

  for (alias in unique(plan$alias[plan$action == "keep" & plan$export_header != "Status"])) {
    alias_options <- options[options$alias == alias, , drop = FALSE]
    if (nrow(alias_options)) {
      add_question(alias, question_text(alias), "Single_Response", 1L)
      for (i in seq_len(nrow(alias_options))) {
        add_option(alias, alias_options$value[i], alias_options$title[i], i)
      }
    } else {
      add_question(alias, question_text(alias), "Open_End", 1L)
    }
  }

  for (alias in unique(plan$alias[plan$action == "multi"])) {
    alias_options <- options[options$alias == alias, , drop = FALSE]
    add_question(alias, question_text(alias), "Multi_Mention", nrow(alias_options))
    for (i in seq_len(nrow(alias_options))) {
      add_option(sprintf("%s_%d", alias, i), alias_options$value[i],
                 alias_options$title[i], i)
    }
  }

  if (any(plan$action == "merge_town")) {
    add_question("Town", "Town (coalesced from the nine per-province questions)",
                 "Single_Response", 1L)
    for (i in seq_along(town_values)) {
      add_option("Town", town_values[i], town_values[i], i)
    }
  }
  add_question("ResponseStatus", "Alchemer interview status", "Single_Response", 1L)
  add_option("ResponseStatus", "Complete", "Complete", 1L)
  add_option("ResponseStatus", "Partial", "Partial", 2L)

  return(list(questions = do.call(rbind, questions),
              options = do.call(rbind, option_rows)))
}

#' The Questions and Options rows for the derived columns
#'
#' TRUE/FALSE columns ride in as Yes/No Single_Response questions; IncomeBand
#' keeps its bands; everything else is Numeric, with binning left to Options
#' rows Duncan can add in Turas once distributions have settled.
#'
#' @param dictionary The generated data dictionary.
#' @param config The VAS_CONFIG list.
#'
#' @return A list of \code{questions} and \code{options} data frames.
derived_structure_rows <- function(dictionary, config) {
  derived <- dictionary[!dictionary$column %in% c("ResponseID", "ResponseStatus"), ]
  yes_no <- derived$column[derived$unit == "TRUE/FALSE"]
  questions <- data.frame(
    QuestionCode = derived$column,
    QuestionText = derived$description,
    Variable_Type = ifelse(derived$column %in% yes_no, "Single_Response",
                           ifelse(derived$column == "IncomeBand",
                                  "Single_Response", "Numeric")),
    Columns = 1L, stringsAsFactors = FALSE)

  option_rows <- list()
  for (code in yes_no) {
    option_rows[[length(option_rows) + 1L]] <- data.frame(
      QuestionCode = code, OptionText = c("Yes", "No"),
      DisplayText = c("Yes", "No"), DisplayOrder = 1:2, stringsAsFactors = FALSE)
  }
  bands <- config$income_bands$label
  option_rows[[length(option_rows) + 1L]] <- data.frame(
    QuestionCode = "IncomeBand", OptionText = bands, DisplayText = bands,
    DisplayOrder = seq_along(bands), stringsAsFactors = FALSE)

  return(list(questions = questions, options = do.call(rbind, option_rows)))
}

#' Write the Survey_Structure workbook
#'
#' @param questions,options The combined structure data frames.
#' @param data_file_name The data workbook's file name (same folder).
#' @param path Where to write.
#'
#' @return The path, invisibly.
write_turas_structure <- function(questions, options, data_file_name, path) {
  project <- data.frame(
    Setting = c("project_name", "client_name", "study_type", "data_file", "notes"),
    Value = c("Electrum VAS 2026", "Electrum", "Payment channel study",
              data_file_name,
              "Generated by vas_turas_build.R - regenerate rather than hand-edit; the column plan and the derived dictionary are the sources of truth."),
    stringsAsFactors = FALSE)
  wb <- openxlsx::createWorkbook()
  for (sheet in c("Project", "Questions", "Options")) {
    openxlsx::addWorksheet(wb, sheet)
  }
  openxlsx::writeData(wb, "Project", project, headerStyle = excel_header_style())
  openxlsx::writeData(wb, "Questions", questions, headerStyle = excel_header_style())
  openxlsx::writeData(wb, "Options", options, headerStyle = excel_header_style())
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  return(invisible(path))
}

#' Write the Crosstab_Config workbook
#'
#' @param questions The combined Questions data frame, for the Selection sheet.
#' @param structure_file_name The structure workbook's file name (same folder).
#' @param path Where to write.
#' @param hide_codes Questions that start unselected even though they are
#'   perfectly good closed questions - the raw "where else" channel questions,
#'   whose total-used and also-used replacements say the same thing without
#'   double-counting the channel used most often.
#'
#' @return The path, invisibly.
write_turas_config <- function(questions, structure_file_name, path,
                               hide_codes = character(0)) {
  settings <- data.frame(
    Setting = c("structure_file", "output_filename", "html_report_v2",
                "show_numeric_median", "enable_significance_testing",
                "apply_weighting", "project_title", "client_name"),
    Value = c(structure_file_name, "VAS_Crosstabs.xlsx", "TRUE", "TRUE", "TRUE",
              "FALSE", "Electrum VAS 2026", "Electrum"),
    stringsAsFactors = FALSE)

  selection <- data.frame(
    QuestionCode = questions$QuestionCode,
    # open text produces empty crosstab tables, so it starts unselected
    Include = ifelse(questions$Variable_Type == "Open_End" |
                       questions$QuestionCode %in% hide_codes, "N", "Y"),
    UseBanner = ifelse(questions$QuestionCode %in% VAS_TURAS_BANNERS, "Y", "N"),
    BannerLabel = ifelse(questions$QuestionCode %in% VAS_TURAS_BANNERS,
                         questions$QuestionCode, ""),
    QuestionText = questions$QuestionText,
    stringsAsFactors = FALSE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::addWorksheet(wb, "Selection")
  openxlsx::writeData(wb, "Settings", settings, headerStyle = excel_header_style())
  openxlsx::writeData(wb, "Selection", selection, headerStyle = excel_header_style())
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  return(invisible(path))
}


#' Apply the reporting label overrides
#'
#' The question text a reader sees comes from two places, neither of which was
#' written for them: an asked question carries its Alchemer title, which is
#' phrased for the respondent ("Have you bought prepaid electricity in the last
#' 12 months, either for your own household or someone else's? (Select all that
#' apply)"), and a derived column carries its dictionary description, which is
#' phrased for documentation ("Whether the respondent purchases Prepaid
#' electricity at all."). Both are correct and neither belongs on a crosstab.
#'
#' \code{vas_report_labels.xlsx} is where a reporting label is written instead.
#' Two columns, \code{question_code} and \code{question_text}; one row per
#' question you want to reword. Any other columns are ignored, so a notes column
#' is free. It survives every rebuild, which hand-editing the generated
#' structure workbook does not.
#'
#' A code that matches nothing is refused rather than ignored. A typo that
#' silently does nothing is the worst outcome here: the run succeeds, the label
#' does not change, and there is no reason on the screen to look at the file.
#'
#' @param questions The combined Questions data frame.
#' @param code_dir The directory holding vas_report_labels.xlsx. A missing file
#'   means no overrides, which is a valid state.
#'
#' @return The Questions data frame with QuestionText replaced where a code matched.
apply_report_labels <- function(questions, code_dir = ".") {
  labels_path <- file.path(path.expand(code_dir), VAS_REPORT_LABELS_FILE)
  if (!file.exists(labels_path)) {
    return(questions)
  }

  # openxlsx, like every other Excel read in this module — readxl is not part of
  # the VAS module's dependency set.
  labels <- openxlsx::read.xlsx(labels_path, sheet = 1)
  labels[] <- lapply(labels, as.character)

  required <- c("question_code", "question_text")
  missing_cols <- setdiff(required, names(labels))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "%s must have columns %s. Missing: %s",
      basename(labels_path), paste(required, collapse = " and "),
      paste(missing_cols, collapse = ", ")), call. = FALSE)
  }

  labels$question_code <- trimws(labels$question_code)
  labels$question_text <- trimws(labels$question_text)
  labels <- labels[nzchar(labels$question_code) & nzchar(labels$question_text), ,
                   drop = FALSE]
  if (nrow(labels) == 0) {
    return(questions)
  }

  dups <- unique(labels$question_code[duplicated(labels$question_code)])
  if (length(dups) > 0) {
    stop(sprintf("%s lists %s more than once. One label per question.",
                 basename(labels_path), paste(dups, collapse = ", ")),
         call. = FALSE)
  }

  unknown <- setdiff(labels$question_code, questions$QuestionCode)
  if (length(unknown) > 0) {
    stop(sprintf(
      paste0("%s names %d question code(s) that do not exist in this study: %s\n",
             "  Nothing was relabelled. Check the spelling against the ",
             "QuestionCode column of the generated structure workbook."),
      basename(labels_path), length(unknown),
      paste(unknown, collapse = ", ")), call. = FALSE)
  }

  idx <- match(questions$QuestionCode, labels$question_code)
  hit <- !is.na(idx)
  questions$QuestionText[hit] <- labels$question_text[idx[hit]]

  cat(sprintf("Reporting labels: %d question(s) relabelled from %s\n",
              sum(hit), basename(labels_path)))

  return(questions)
}
