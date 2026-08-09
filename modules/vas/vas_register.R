# vas_register.R
# ------------------------------------------------------------------------------
# The report register - the human gate between the raw export and everything
# downstream. One row per response. The pipeline refreshes the identity
# columns and the automatic flags on every run; Duncan owns Disposition and
# Reason, and those two columns survive every refresh (the same contract as
# the VAS QC Log).
#
#   Disposition = Include   flows into the derived numbers and the Turas dataset
#   Disposition = Review    flows into the derived numbers (monitoring stays
#                           complete) but blocks the Turas dataset until decided
#   Disposition = Exclude   dropped from everything downstream
#
# A new response defaults to Include, or to Review when an automatic flag
# fires. The refresh NEVER changes an existing Disposition or Reason.
# ------------------------------------------------------------------------------

VAS_REGISTER_DISPOSITIONS <- c("Include", "Review", "Exclude")
VAS_REGISTER_SHEET <- "Register"
VAS_REGISTER_KEY <- "Response ID"

# Words in a respondent or interviewer name that mark a test interview.
# "duncan" is the researcher testing his own survey, not a respondent.
VAS_REGISTER_TEST_WORDS <- c("test", "duncan")

#' Read a column from the source if it exists, NA otherwise
#'
#' The admin columns are not part of the category map, so their absence must
#' not stop a run.
#'
#' @param source A vas_source object.
#' @param name The column name.
#'
#' @return A character vector, one element per respondent.
source_column_or_na <- function(source, name) {
  if (!name %in% names(source$data)) {
    return(rep(NA_character_, length(source$response_id)))
  }
  return(as.character(source$data[[name]]))
}

#' Describe why a response looks like a test interview, if it does
#'
#' Three signals, each explained in the returned text: a test word in the
#' respondent or interviewer name, a cell number that is not a plausible South
#' African mobile number (10 digits starting 0), and an interview submitted
#' before the field start date.
#'
#' @param respondent,interviewer,cell,submitted Character vectors.
#' @param field_start A "YYYY-MM-DD" string, or NA when fieldwork has no
#'   declared start yet.
#'
#' @return A character vector: the reasons, "; "-joined, "" when clean.
describe_test_pattern <- function(respondent, interviewer, cell, submitted,
                                  field_start = NA) {
  has_test_word <- function(name) {
    !is.na(name) & Reduce(`|`, lapply(VAS_REGISTER_TEST_WORDS, function(word) {
      grepl(word, tolower(name), fixed = TRUE)
    }))
  }
  digits <- gsub("[^0-9]", "", ifelse(is.na(cell), "", cell))
  implausible_cell <- !is.na(cell) & !grepl("^0[0-9]{9}$", digits)

  before_start <- rep(FALSE, length(submitted))
  if (!is.na(field_start)) {
    submitted_date <- as.Date(strptime(submitted, "%d %B %Y %H:%M:%S"))
    before_start <- !is.na(submitted_date) & submitted_date < as.Date(field_start)
  }

  reasons <- cbind(
    ifelse(has_test_word(respondent) | has_test_word(interviewer), "test name", NA),
    ifelse(implausible_cell, "implausible cell number", NA),
    ifelse(before_start, "before field start", NA)
  )
  return(apply(reasons, 1, function(r) paste(stats::na.omit(r), collapse = "; ")))
}

#' Build the automatic register rows from a source
#'
#' @param source A vas_source object.
#' @param field_start Passed to \code{describe_test_pattern()}.
#'
#' @return A data frame, one row per respondent, no dispositions yet.
build_register_rows <- function(source, field_start = NA) {
  respondent <- source_column_or_na(source, "Respondent")
  interviewer <- source_column_or_na(source, "Interviewer")
  cell <- source_column_or_na(source, "RespCell")
  submitted <- source_column_or_na(source, "Date Submitted")

  digits <- gsub("[^0-9]", "", ifelse(is.na(cell), "", cell))
  plausible <- grepl("^0[0-9]{9}$", digits)
  duplicate <- plausible & (duplicated(digits) | duplicated(digits, fromLast = TRUE))

  frame <- data.frame(
    check.names = FALSE, stringsAsFactors = FALSE,
    `Response ID` = as.character(source$response_id),
    Disposition = NA_character_,
    Reason = NA_character_,
    `Test pattern` = describe_test_pattern(respondent, interviewer, cell,
                                           submitted, field_start),
    `Duplicate cell` = ifelse(duplicate, "duplicate", ""),
    `QC status` = "",
    `Outlier flag` = "",
    `Share of wallet` = "",
    `Date submitted` = submitted,
    Status = as.character(source$status),
    Interviewer = interviewer,
    Supervisor = source_column_or_na(source, "Supervisor"),
    Respondent = respondent,
    `Cell number` = cell
  )
  return(frame)
}

#' Read an existing register workbook
#'
#' The workbook carries a title and an instruction line above the header, so
#' the header row is found by looking for the key column.
#'
#' @param path The register's path.
#'
#' @return A data frame, or NULL when there is no register yet.
read_report_register <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }
  raw <- openxlsx::read.xlsx(path, sheet = VAS_REGISTER_SHEET, colNames = FALSE,
                             skipEmptyRows = FALSE, skipEmptyCols = FALSE)
  header_row <- which(trimws(as.character(raw[[1]])) == VAS_REGISTER_KEY)[1]
  if (is.na(header_row)) {
    stop(structure(class = c("vas_register_unreadable", "error", "condition"), list(
      message = sprintf("No '%s' header row was found in '%s'. If the register is damaged, delete it and run again - dispositions will be lost.",
                        VAS_REGISTER_KEY, basename(path)), call = NULL)))
  }
  frame <- raw[-seq_len(header_row), , drop = FALSE]
  names(frame) <- trimws(as.character(unlist(raw[header_row, ])))
  frame <- frame[!is.na(frame[[VAS_REGISTER_KEY]]), , drop = FALSE]
  frame[] <- lapply(frame, as.character)
  return(frame)
}

#' Merge the fresh automatic rows with the existing dispositions
#'
#' Existing Disposition and Reason values are carried over by Response ID and
#' never changed. A response that has left the export (Alchemer deletion)
#' stays in the register, marked in Test pattern, so a disposition is never
#' silently lost.
#'
#' @param fresh From \code{build_register_rows()}.
#' @param existing From \code{read_report_register()}, may be NULL.
#'
#' @return The merged register data frame.
merge_register <- function(fresh, existing) {
  if (is.null(existing)) {
    return(fresh)
  }
  position <- match(fresh[[VAS_REGISTER_KEY]], existing[[VAS_REGISTER_KEY]])
  for (owned in c("Disposition", "Reason")) {
    if (owned %in% names(existing)) {
      carried <- existing[[owned]][position]
      fresh[[owned]] <- ifelse(is.na(carried) | !nzchar(carried),
                               fresh[[owned]], carried)
    }
  }
  vanished <- existing[!existing[[VAS_REGISTER_KEY]] %in% fresh[[VAS_REGISTER_KEY]], ,
                       drop = FALSE]
  if (nrow(vanished)) {
    vanished <- vanished[, intersect(names(fresh), names(vanished)), drop = FALSE]
    for (column in setdiff(names(fresh), names(vanished))) {
      vanished[[column]] <- NA_character_
    }
    vanished$`Test pattern` <- "no longer in the export"
    fresh <- rbind(fresh, vanished[, names(fresh)])
  }
  return(fresh)
}

#' Join the QC log's status onto the register
#'
#' Every sheet of the log is read, not just the first. Since 2026-07-27 the
#' log is written on two sheets - "Open queries" and "Closed and settled" -
#' and reading only sheet 1 would silently lose the status of every query
#' that has been checked off, which is exactly the status the register most
#' needs. A one-sheet log from before that change reads the same way.
#'
#' @param register The register data frame.
#' @param qc_log_path Path to "VAS QC Log.xlsx"; silently skipped when absent.
#'
#' @return The register with its `QC status` column filled.
join_qc_status <- function(register, qc_log_path) {
  if (!file.exists(qc_log_path)) {
    return(register)
  }
  frames <- list()
  for (sheet in openxlsx::getSheetNames(qc_log_path)) {
    raw <- openxlsx::read.xlsx(qc_log_path, sheet = sheet, colNames = FALSE,
                               skipEmptyRows = FALSE, skipEmptyCols = FALSE)
    if (is.null(raw) || nrow(raw) == 0L) {
      next
    }
    header_row <- which(trimws(as.character(raw[[1]])) == "Response ID")[1]
    if (is.na(header_row)) {
      next          # a sheet that holds no query table, e.g. a lookup
    }
    frame <- raw[-seq_len(header_row), , drop = FALSE]
    names(frame) <- trimws(as.character(unlist(raw[header_row, ])))
    frames[[length(frames) + 1L]] <- frame[, c("Response ID", "Status"),
                                           drop = FALSE]
  }
  if (length(frames) == 0L) {
    return(register)
  }
  # the open sheet is written first, so it wins if an ID somehow sits on both
  frame <- do.call(rbind, frames)
  frame <- frame[!duplicated(as.character(frame[["Response ID"]])), ,
                 drop = FALSE]
  position <- match(register[[VAS_REGISTER_KEY]], as.character(frame[["Response ID"]]))
  status <- as.character(frame[["Status"]])[position]
  register$`QC status` <- ifelse(is.na(status), register$`QC status`, status)
  return(register)
}

#' Copy the derived outlier and share-of-wallet flags onto the register
#'
#' @param register The register data frame.
#' @param wide The wide table from \code{derive_vas()}; excluded respondents
#'   are simply not in it and keep blank flags.
#'
#' @return The register with `Outlier flag` and `Share of wallet` filled.
annotate_register_flags <- function(register, wide) {
  position <- match(register[[VAS_REGISTER_KEY]], as.character(wide$ResponseID))
  outlier <- wide$OutlierFlag[position]
  share <- wide$ShareOfWallet_Transacted_Midpoint[position]
  register$`Outlier flag` <- ifelse(!is.na(outlier) & outlier, "outlier answer", "")
  register$`Share of wallet` <- ifelse(is.na(share), "",
                                       sprintf("%.0f%%", 100 * share))
  # a share of wallet beyond income is itself worth a look
  register$`Outlier flag` <- ifelse(
    !is.na(share) & share > 1,
    trimws(paste(register$`Outlier flag`, "share of wallet over 100%", sep = "; ")),
    register$`Outlier flag`)
  register$`Outlier flag` <- sub("^; ", "", register$`Outlier flag`)
  return(register)
}

#' Give every undecided row its default disposition
#'
#' @param register The register data frame, flags already filled.
#'
#' @return The register with no blank dispositions left.
apply_default_dispositions <- function(register) {
  has_text <- function(values) !is.na(values) & nzchar(values)
  flagged <- has_text(register$`Test pattern`) | has_text(register$`Duplicate cell`) |
    has_text(register$`Outlier flag`)
  undecided <- !has_text(register$Disposition)
  register$Disposition[undecided] <- ifelse(flagged[undecided], "Review", "Include")
  return(register)
}

#' Drop the excluded respondents from a source
#'
#' @param source A vas_source object.
#' @param register The register data frame.
#'
#' @return A list: \code{source} (filtered), \code{excluded} (character vector
#'   of the Response IDs dropped).
filter_source_by_register <- function(source, register) {
  disposition <- register$Disposition[match(as.character(source$response_id),
                                            register[[VAS_REGISTER_KEY]])]
  drop <- !is.na(disposition) & tolower(trimws(disposition)) == "exclude"
  filtered <- new_vas_source(
    origin = source$origin,
    response_id = source$response_id[!drop],
    status = source$status[!drop],
    columns = lapply(source$data, function(column) column[!drop])
  )
  return(list(source = filtered, excluded = source$response_id[drop]))
}

#' Write the register workbook
#'
#' Mirrors the QC log's layout: a title, the working instruction, then the
#' table, with a dropdown on Disposition.
#'
#' @param register The register data frame.
#' @param path Where to write it.
#'
#' @return The path, invisibly.
write_report_register <- function(register, path) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, VAS_REGISTER_SHEET)
  openxlsx::writeData(wb, VAS_REGISTER_SHEET,
                      "VAS 2026 - report register (the human gate)", startRow = 1)
  openxlsx::writeData(wb, VAS_REGISTER_SHEET, paste(
    "Set Disposition per response: Include / Review / Exclude, with a Reason.",
    "Those two columns survive every refresh; everything else is rebuilt.",
    sprintf("Refreshed %s.", format(Sys.time(), "%d %B %Y %H:%M"))), startRow = 2)
  openxlsx::writeData(wb, VAS_REGISTER_SHEET, register, startRow = 4,
                      headerStyle = excel_header_style())
  openxlsx::dataValidation(wb, VAS_REGISTER_SHEET,
                           cols = which(names(register) == "Disposition"),
                           rows = 4L + seq_len(nrow(register)), type = "list",
                           value = sprintf('"%s"', paste(VAS_REGISTER_DISPOSITIONS,
                                                         collapse = ",")))
  openxlsx::freezePane(wb, VAS_REGISTER_SHEET, firstActiveRow = 5L)
  openxlsx::setColWidths(wb, VAS_REGISTER_SHEET,
                         cols = seq_len(ncol(register)), widths = "auto")
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  return(invisible(path))
}

#' Refresh the register from a source and decide who flows downstream
#'
#' The one call the runners use. Reads the existing register, rebuilds the
#' automatic columns, carries the dispositions, joins the QC log, and returns
#' everything the caller needs; the caller writes the register back after
#' annotating the derived flags.
#'
#' @param source A vas_source object.
#' @param register_path Where the register lives.
#' @param qc_log_path Path to the QC log; skipped when absent.
#' @param field_start "YYYY-MM-DD" or NA.
#'
#' @return A list: \code{register}, \code{new_count} (rows with no prior
#'   disposition), \code{filtered} (from \code{filter_source_by_register}).
refresh_report_register <- function(source, register_path, qc_log_path,
                                    field_start = NA) {
  existing <- read_report_register(register_path)
  register <- merge_register(build_register_rows(source, field_start), existing)
  register <- join_qc_status(register, qc_log_path)
  new_count <- sum(is.na(register$Disposition) | !nzchar(register$Disposition))
  filtered <- filter_source_by_register(source, register)
  return(list(register = register, new_count = new_count, filtered = filtered))
}
