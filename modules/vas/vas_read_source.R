# vas_read_source.R
# ------------------------------------------------------------------------------
# The I/O boundary for the VAS derived-variable calculation.
#
# Two readers - the Alchemer API and the Alchemer Excel export - both produce
# the same object, so the calculation engine never knows or cares which was
# used. That also makes the two sources cross-checkable against each other.
#
# The common shape ("vas_source"):
#   origin       "api" or "export"
#   response_id  character vector, one element per respondent
#   status       character vector, Alchemer's Complete / Partial
#   data         data frame of character columns, one row per respondent
#
# Column naming in $data follows the export's own convention, because the
# export headers are already the question aliases:
#   "PPUOwnFreq1"              a scalar question, named by its alias
#   "TV License:BillOwnWhich"  one checkbox option, "<option>:<alias>"
# ------------------------------------------------------------------------------

# The export writes each "specify" write-in as its own column beside the parent
# question, and stores this value in the parent when the write-in was used.
VAS_SPECIFY_SENTINEL <- "12+"
VAS_SPECIFY_PREFIX <- "12+ (Specify):"

# Headers that must appear in a genuine export of this survey. Checked before
# anything else, so a workbook that merely has the right FILE NAME - a sample
# frame, a checklist - fails with a message that says what it is, rather than
# with a list of two hundred missing columns.
VAS_EXPORT_SENTINELS <- c("Response ID", "Income", "PPUOwnFreq1", "AirtimeOwnAmount")

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

#' Build a vas_source object from named column vectors
#'
#' @param origin "api" or "export".
#' @param response_id Character vector of response ids.
#' @param status Character vector of response statuses.
#' @param columns A named list of character vectors, all the same length as
#'   \code{response_id}.
#'
#' @return A vas_source list.
new_vas_source <- function(origin, response_id, status, columns) {
  n <- length(response_id)
  ragged <- names(columns)[vapply(columns, length, integer(1)) != n]
  if (length(ragged)) {
    stop(structure(
      class = c("vas_source_ragged", "error", "condition"),
      list(message = sprintf(
        "Columns do not have one value per respondent (n=%d): %s.",
        n, paste(head(ragged, 10), collapse = ", ")
      ), call = NULL)
    ))
  }
  frame <- if (length(columns)) {
    as.data.frame(columns, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    data.frame(row.names = seq_len(n))
  }
  return(structure(
    list(origin = origin, response_id = as.character(response_id),
         status = as.character(status), data = frame),
    class = "vas_source"
  ))
}

#' Read one scalar question's answers from a source
#'
#' @param source A vas_source object.
#' @param alias The question alias.
#'
#' @return A character vector, one element per respondent. Absent or empty
#'   answers come back as NA.
#'
#' @throws Stops with class "vas_missing_column" when the alias is not present.
source_scalar <- function(source, alias) {
  if (is.na(alias) || !nzchar(alias)) {
    return(rep(NA_character_, length(source$response_id)))
  }
  if (!alias %in% names(source$data)) {
    stop(structure(
      class = c("vas_missing_column", "error", "condition"),
      list(message = sprintf(
        "Alias '%s' is not present in the %s source. Check vas_category_map.csv against the survey.",
        alias, source$origin
      ), call = NULL)
    ))
  }
  values <- as.character(source$data[[alias]])
  values[!is.na(values) & !nzchar(trimws(values))] <- NA_character_
  return(values)
}

#' Test whether a checkbox option was selected
#'
#' @param source A vas_source object.
#' @param alias The checkbox question's alias.
#' @param option The option label, exactly as it appears in the survey.
#'
#' @return A logical vector, one element per respondent.
#'
#' @throws Stops with class "vas_missing_column" when the option column is
#'   absent.
source_option <- function(source, alias, option) {
  column <- paste0(option, ":", alias)
  if (!column %in% names(source$data)) {
    stop(structure(
      class = c("vas_missing_column", "error", "condition"),
      list(message = sprintf(
        "Option column '%s' is not present in the %s source.", column, source$origin
      ), call = NULL)
    ))
  }
  values <- as.character(source$data[[column]])
  return(!is.na(values) & nzchar(trimws(values)))
}

#' Check that a source carries every column the category map needs
#'
#' Accumulates every missing column and reports them together, rather than
#' failing on the first one.
#'
#' @param source A vas_source object.
#' @param category_map The category map data frame.
#'
#' @return The source, invisibly, when everything is present.
#'
#' @throws Stops with class "vas_missing_column" listing every absent column.
validate_source_columns <- function(source, category_map) {
  alias_columns <- c("freq1", "freq2", "freq3", "freq4", "amount_alias",
                     "count_alias", "legs_alias")
  needed <- unique(stats::na.omit(unlist(category_map[, alias_columns])))
  presence_rows <- category_map[!is.na(category_map$presence_alias), ]
  if (nrow(presence_rows)) {
    needed <- c(needed, paste0(presence_rows$presence_option, ":",
                               presence_rows$presence_alias))
  }
  missing <- setdiff(needed, names(source$data))
  if (length(missing)) {
    stop(structure(
      class = c("vas_missing_column", "error", "condition"),
      list(message = sprintf(
        "%d column(s) required by the category map are absent from the %s source:\n  %s",
        length(missing), source$origin, paste(missing, collapse = "\n  ")
      ), call = NULL)
    ))
  }
  return(invisible(source))
}

# ---- Alchemer API reader -------------------------------------------------------

#' Fetch every response for a survey, following pagination
#'
#' @param survey_id The Alchemer survey id.
#' @param per_page Records per request.
#'
#' @return A list of response objects.
fetch_all_responses <- function(survey_id, per_page = 500) {
  collected <- list()
  page <- 1L
  repeat {
    response <- alch_request(
      sprintf("survey/%s/surveyresponse", survey_id),
      query = list(resultsperpage = per_page, page = page)
    )
    if (!isTRUE(response$ok)) {
      stop(structure(
        class = c("vas_api_error", "error", "condition"),
        list(message = sprintf("Alchemer response fetch failed on page %d (HTTP %s): %s",
                               page, response$status, response$message), call = NULL)
      ))
    }
    collected <- c(collected, response$data)
    total_pages <- suppressWarnings(as.integer(response$raw$total_pages %||% 1L))
    if (is.na(total_pages) || page >= total_pages || !length(response$data)) {
      break
    }
    page <- page + 1L
  }
  return(collected)
}

#' Flatten one response's survey_data into named cells
#'
#' @param survey_data The response's survey_data list.
#' @param alias_of A named character vector mapping question id to alias.
#'
#' @return A named character vector of cell values.
flatten_response <- function(survey_data, alias_of) {
  cells <- character(0)
  for (key in names(survey_data)) {
    entry <- survey_data[[key]]
    question_id <- as.character(entry$id %||% key)
    # the payload carries questions that are not in the survey index, so
    # membership is tested before subsetting rather than after
    alias <- if (question_id %in% names(alias_of)) alias_of[[question_id]] else NA_character_
    if (is.na(alias) || !nzchar(alias)) {
      next
    }
    answer <- trimws(paste(unlist(entry$answer %||% ""), collapse = ""))
    if (nzchar(answer)) {
      cells[[alias]] <- answer
    }
    for (option in (entry$options %||% list())) {
      option_answer <- trimws(paste(unlist(option$answer %||% ""), collapse = ""))
      if (nzchar(option_answer)) {
        cells[[paste0(option$option, ":", alias)]] <- option_answer
      }
    }
  }
  return(cells)
}

#' Read VAS responses from the Alchemer API
#'
#' Requires \code{alchemer_survey_tools.R} to have been sourced, and the
#' ALCHEMER_API_TOKEN / ALCHEMER_API_SECRET pair in ~/.Renviron.
#'
#' @param survey_id The Alchemer survey id.
#' @param index_path Path to a survey index CSV produced by
#'   \code{alch_snapshot()}; defaults to the most recent one in backups/.
#'
#' @return A vas_source object.
read_vas_api <- function(survey_id,
                         index_path = tail(sort(Sys.glob("backups/survey_*_index.csv")), 1)) {
  index <- utils::read.csv(index_path, stringsAsFactors = FALSE)
  index <- index[!is.na(index$q_id) & !is.na(index$alias) & nzchar(index$alias), ]
  alias_of <- stats::setNames(index$alias, as.character(index$q_id))

  responses <- fetch_all_responses(survey_id)
  if (!length(responses)) {
    stop(structure(
      class = c("vas_no_responses", "error", "condition"),
      list(message = sprintf("Survey %s returned no responses.", survey_id), call = NULL)
    ))
  }

  flattened <- lapply(responses, function(r) flatten_response(r$survey_data, alias_of))
  all_names <- unique(unlist(lapply(flattened, names)))
  # align every respondent to the full column set in one pass; match() yields NA
  # for a column that respondent never reached, which is what we want
  cell_matrix <- vapply(flattened, function(cells) {
    unname(cells[match(all_names, names(cells))])
  }, character(length(all_names)))
  columns <- lapply(stats::setNames(seq_along(all_names), all_names),
                    function(i) cell_matrix[i, ])

  return(new_vas_source(
    origin = "api",
    response_id = vapply(responses, function(r) as.character(r$id), character(1)),
    status = vapply(responses, function(r) as.character(r$status %||% NA), character(1)),
    columns = columns
  ))
}

# ---- Alchemer export reader ----------------------------------------------------

#' Clean an Alchemer export header row
#'
#' The first cell arrives with a byte-order mark and literal quote characters.
#'
#' @param header A character vector of raw header cells.
#'
#' @return A character vector of cleaned names.
clean_export_headers <- function(header) {
  cleaned <- as.character(header)
  cleaned <- gsub("^﻿", "", cleaned)
  cleaned <- gsub('^"|"$', "", cleaned)
  return(trimws(cleaned))
}

#' Fold each "12+ (Specify)" write-in column into its parent count column
#'
#' @param frame The export data frame, character columns, original names.
#'
#' @return The frame with parent count columns carrying the write-in values.
merge_specify_writeins <- function(frame) {
  specify_columns <- grep(VAS_SPECIFY_PREFIX, names(frame), fixed = TRUE, value = TRUE)
  for (column in specify_columns) {
    parent <- sub(VAS_SPECIFY_PREFIX, "", column, fixed = TRUE)
    if (!parent %in% names(frame)) {
      next
    }
    write_in <- trimws(as.character(frame[[column]]))
    uses_write_in <- !is.na(write_in) & nzchar(write_in) &
      trimws(as.character(frame[[parent]])) %in% VAS_SPECIFY_SENTINEL
    frame[[parent]][uses_write_in] <- write_in[uses_write_in]
  }
  return(frame)
}

#' Refuse a workbook that is not an Alchemer export of this survey
#'
#' A fieldwork folder holds checklists and sample frames as well as exports.
#' Checking a few known headers first means the wrong workbook is named as such,
#' rather than producing a list of two hundred missing columns.
#'
#' @param header The cleaned header row.
#' @param path The workbook's path, for the message.
#'
#' @return Nothing, called for its side effect.
#'
#' @throws Stops with class "vas_not_an_export" when a sentinel header is
#'   absent.
stop_unless_alchemer_export <- function(header, path) {
  found <- intersect(VAS_EXPORT_SENTINELS, header)
  if (length(found) == length(VAS_EXPORT_SENTINELS)) {
    return(invisible(NULL))
  }
  stop(structure(
    class = c("vas_not_an_export", "error", "condition"),
    list(message = sprintf(
      "'%s' does not look like an Alchemer export of this survey.\nExpected to find these headers: %s\nOnly found: %s\n\nIt has %d columns. Check you saved the SURVEY EXPORT and not another workbook.",
      basename(path), paste(VAS_EXPORT_SENTINELS, collapse = ", "),
      if (length(found)) paste(found, collapse = ", ") else "none of them",
      length(header)), call = NULL)
  ))
}

#' Read VAS responses from an Alchemer Excel export
#'
#' The export's own headers are used unchanged: scalar questions are headed by
#' their alias, checkbox options by "<option>:<alias>". Duplicate headers are
#' tolerated unless the calculation needs one of them, in which case the read
#' fails loudly rather than binding to the wrong column.
#'
#' @param path Path to the .xlsx export.
#' @param sheet Sheet index or name.
#'
#' @return A vas_source object.
#'
#' @throws Stops with class "vas_export_unreadable" when the file is missing,
#'   or "vas_duplicate_column" when a needed header appears more than once.
read_vas_export <- function(path, sheet = 1) {
  path <- path.expand(path)
  if (!file.exists(path)) {
    stop(structure(
      class = c("vas_export_unreadable", "error", "condition"),
      list(message = sprintf("Export not found at '%s'.", path), call = NULL)
    ))
  }
  raw <- openxlsx::read.xlsx(path, sheet = sheet, colNames = FALSE,
                             skipEmptyRows = FALSE, skipEmptyCols = FALSE)
  if (nrow(raw) < 2L) {
    stop(structure(
      class = c("vas_export_unreadable", "error", "condition"),
      list(message = sprintf("Export '%s' has a header row but no data rows.", path),
           call = NULL)
    ))
  }

  header <- clean_export_headers(unlist(raw[1, ]))
  stop_unless_alchemer_export(header, path)
  body <- raw[-1, , drop = FALSE]
  frame <- as.data.frame(lapply(body, function(col) {
    values <- trimws(as.character(col))
    values[!is.na(values) & !nzchar(values)] <- NA_character_
    values
  }), stringsAsFactors = FALSE)
  names(frame) <- header
  frame <- merge_specify_writeins(frame)

  id_column <- if ("Response ID" %in% header) "Response ID" else header[1]
  status_column <- if ("Status" %in% header) "Status" else NA_character_

  duplicated_names <- unique(header[duplicated(header)])
  keep <- !duplicated(header) | !(header %in% duplicated_names)
  columns <- as.list(frame[, keep, drop = FALSE])
  names(columns) <- header[keep]
  attr(columns, "duplicated_headers") <- duplicated_names

  source <- new_vas_source(
    origin = "export",
    response_id = as.character(frame[[which(header == id_column)[1]]]),
    status = if (is.na(status_column)) rep(NA_character_, nrow(frame))
             else as.character(frame[[which(header == status_column)[1]]]),
    columns = columns
  )
  source$duplicated_headers <- duplicated_names
  return(source)
}
