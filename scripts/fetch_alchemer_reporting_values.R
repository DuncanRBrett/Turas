# scripts/fetch_alchemer_reporting_values.R
#
# Fetch reporting values & aliases for any Alchemer survey via the v5 REST API.
# One row per option: question_id, option_value (reporting code), option_title (alias).
#
# ------------------------------------------------------------------------------
# Auth
# ------------------------------------------------------------------------------
# Set credentials as environment variables (recommended):
#   ALCHEMER_API_TOKEN
#   ALCHEMER_API_SECRET
# Add them to ~/.Renviron and restart R, or pass them explicitly to the function.
#
# ------------------------------------------------------------------------------
# Usage from R
# ------------------------------------------------------------------------------
#   source("scripts/fetch_alchemer_reporting_values.R")
#   df <- fetch_alchemer_reporting_values(survey_id = 8822527)
#   data.table::fwrite(df, "alchemer_8822527_reporting_values.csv")
#
# ------------------------------------------------------------------------------
# Usage from the command line
# ------------------------------------------------------------------------------
#   Rscript scripts/fetch_alchemer_reporting_values.R 8822527
#   Rscript scripts/fetch_alchemer_reporting_values.R 8822527 my_output.csv
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(httr)
  library(data.table)
})

ALCHEMER_BASE_URL          <- "https://api.alchemer.com/v5"
ALCHEMER_RESULTS_PER_PAGE  <- 500L
ALCHEMER_TIMEOUT_SECONDS   <- 60L

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# ---- credentials -------------------------------------------------------------

.alchemer_credentials <- function(api_token = NULL, api_secret = NULL) {
  token  <- api_token  %||% Sys.getenv("ALCHEMER_API_TOKEN",  unset = "")
  secret <- api_secret %||% Sys.getenv("ALCHEMER_API_SECRET", unset = "")
  if (!nzchar(token) || !nzchar(secret)) {
    stop(
      "Alchemer credentials missing.\n",
      "  Set ALCHEMER_API_TOKEN and ALCHEMER_API_SECRET in ~/.Renviron and ",
      "restart R, or pass api_token / api_secret to the function directly.",
      call. = FALSE
    )
  }
  list(token = token, secret = secret)
}

# ---- HTTP --------------------------------------------------------------------

.alchemer_get <- function(path, query, creds) {
  query$api_token        <- creds$token
  query$api_token_secret <- creds$secret
  resp <- httr::GET(
    paste0(ALCHEMER_BASE_URL, path),
    query = query,
    httr::timeout(ALCHEMER_TIMEOUT_SECONDS)
  )
  if (httr::http_error(resp)) {
    stop(sprintf(
      "Alchemer API error: GET %s -- HTTP %d. %s",
      path,
      httr::status_code(resp),
      httr::content(resp, as = "text", encoding = "UTF-8")
    ), call. = FALSE)
  }
  body <- httr::content(resp, as = "parsed", type = "application/json")
  if (isFALSE(body$result_ok)) {
    stop(sprintf(
      "Alchemer API result_ok = FALSE for GET %s: %s",
      path, body$message %||% "(no message)"
    ), call. = FALSE)
  }
  body
}

.alchemer_get_paginated <- function(path, creds) {
  page <- 1L
  out  <- list()
  repeat {
    body <- .alchemer_get(
      path,
      query = list(resultsperpage = ALCHEMER_RESULTS_PER_PAGE, page = page),
      creds = creds
    )
    out  <- c(out, body$data %||% list())
    total_pages <- as.integer(body$total_pages %||% 1L)
    if (page >= total_pages) break
    page <- page + 1L
  }
  out
}

# ---- field flattening --------------------------------------------------------

# Alchemer text fields can arrive as a string OR a named list keyed by language
# (e.g. list(English = "...", Spanish = "...")). Normalise to a single string.
.flatten_text <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  if (is.character(x) && length(x) == 1) return(x)
  if (is.list(x)) {
    if (!is.null(x$English) && nzchar(x$English)) return(as.character(x$English))
    vals <- unlist(x, use.names = FALSE)
    vals <- vals[!is.na(vals) & nzchar(vals)]
    if (length(vals) > 0) return(as.character(vals[[1]]))
  }
  NA_character_
}

.option_to_row <- function(option, question_meta) {
  data.table::data.table(
    survey_id          = question_meta$survey_id,
    question_id        = question_meta$question_id,
    question_shortname = question_meta$question_shortname,
    question_title     = question_meta$question_title,
    question_type      = question_meta$question_type,
    option_id          = as.character(option$id    %||% NA_character_),
    option_sku         = as.character(option$sku   %||% NA_character_),
    option_value       = as.character(option$value %||% NA_character_),
    option_title       = .flatten_text(option$title)
  )
}

.question_meta <- function(question, survey_id) {
  list(
    survey_id          = survey_id,
    question_id        = as.character(question$id %||% NA_character_),
    question_shortname = as.character(question$shortname %||% NA_character_),
    question_title     = .flatten_text(question$title),
    question_type      = as.character(question$`_type` %||% question$type %||% NA_character_)
  )
}

.empty_row <- function(question_meta) {
  data.table::data.table(
    survey_id          = question_meta$survey_id,
    question_id        = question_meta$question_id,
    question_shortname = question_meta$question_shortname,
    question_title     = question_meta$question_title,
    question_type      = question_meta$question_type,
    option_id          = NA_character_,
    option_sku         = NA_character_,
    option_value       = NA_character_,
    option_title       = NA_character_
  )
}

# ---- main --------------------------------------------------------------------

#' Fetch reporting values & aliases for an Alchemer survey
#'
#' Pulls every question and option from the v5 API and returns a tidy table
#' mapping each option's reporting value to its display title (alias).
#'
#' @param survey_id  Integer or character Alchemer survey ID.
#' @param api_token  Optional API token. Defaults to env var ALCHEMER_API_TOKEN.
#' @param api_secret Optional API secret. Defaults to env var ALCHEMER_API_SECRET.
#' @return A data.table with one row per option:
#'   survey_id, question_id, question_shortname, question_title, question_type,
#'   option_id, option_sku, option_value (the reporting value),
#'   option_title (the alias / display label).
#'   Questions with no options (open text, etc.) appear once with NA option fields.
#' @export
fetch_alchemer_reporting_values <- function(survey_id,
                                            api_token  = NULL,
                                            api_secret = NULL) {
  if (missing(survey_id) || is.null(survey_id) || is.na(survey_id) ||
      !nzchar(as.character(survey_id))) {
    stop("survey_id is required (numeric or character).", call. = FALSE)
  }
  survey_id <- as.character(survey_id)
  creds     <- .alchemer_credentials(api_token, api_secret)

  questions <- .alchemer_get_paginated(
    sprintf("/survey/%s/surveyquestion", survey_id),
    creds = creds
  )
  if (length(questions) == 0) {
    stop(sprintf("Survey %s returned no questions.", survey_id), call. = FALSE)
  }

  rows <- vector("list", length(questions))
  for (i in seq_along(questions)) {
    qmeta <- .question_meta(questions[[i]], survey_id)
    opts  <- questions[[i]]$options
    if (is.null(opts) || length(opts) == 0) {
      rows[[i]] <- .empty_row(qmeta)
    } else {
      rows[[i]] <- data.table::rbindlist(
        lapply(opts, .option_to_row, question_meta = qmeta),
        use.names = TRUE,
        fill      = TRUE
      )
    }
  }
  data.table::rbindlist(rows, use.names = TRUE, fill = TRUE)
}

# Pick a writer based on the output file extension. xlsx and tsv avoid CSV
# comma-quoting headaches when question text contains commas.
.write_table_by_extension <- function(data, output_path) {
  ext <- tolower(tools::file_ext(output_path))
  switch(ext,
    "xlsx" = {
      if (!requireNamespace("openxlsx", quietly = TRUE)) {
        stop(
          "Writing .xlsx requires the openxlsx package. ",
          "Install it with install.packages(\"openxlsx\"), or use a .csv / .tsv path instead.",
          call. = FALSE
        )
      }
      openxlsx::write.xlsx(data, output_path, overwrite = TRUE)
    },
    "tsv" = {
      data.table::fwrite(data, output_path, sep = "\t", quote = FALSE)
    },
    "csv" = {
      # Force quoting on every field so commas, quotes and newlines inside
      # question text never break the file open in Excel or other tools.
      data.table::fwrite(data, output_path, quote = TRUE)
    },
    stop(sprintf(
      "Unsupported output extension '.%s'. Use .csv, .tsv or .xlsx.",
      ext
    ), call. = FALSE)
  )
}

#' Fetch and save reporting values & aliases to a file
#'
#' Convenience wrapper around fetch_alchemer_reporting_values() that writes
#' the result to disk and prints the absolute path of the saved file.
#' The file format is chosen from the output_path extension:
#'   .xlsx -> Excel workbook (recommended if your text contains commas)
#'   .tsv  -> tab-separated values (also commas-safe)
#'   .csv  -> comma-separated, with every field quoted
#'
#' @param survey_id   Integer or character Alchemer survey ID.
#' @param output_path Character path ending in .csv, .tsv or .xlsx. Can be
#'   relative (resolved against getwd()) or absolute. Parent directory must exist.
#' @param api_token   Optional API token. Defaults to env ALCHEMER_API_TOKEN.
#' @param api_secret  Optional API secret. Defaults to env ALCHEMER_API_SECRET.
#' @return The data.table that was written (invisibly).
#' @export
save_alchemer_reporting_values <- function(survey_id,
                                           output_path,
                                           api_token  = NULL,
                                           api_secret = NULL) {
  if (missing(output_path) || !is.character(output_path) ||
      length(output_path) != 1L || !nzchar(output_path)) {
    stop("output_path is required (single non-empty character).", call. = FALSE)
  }
  output_path <- path.expand(output_path)
  parent_dir  <- dirname(output_path)
  if (!dir.exists(parent_dir)) {
    stop(sprintf(
      "Parent directory does not exist: %s\n  Create it first, e.g. dir.create(\"%s\", recursive = TRUE)",
      parent_dir, parent_dir
    ), call. = FALSE)
  }

  result <- fetch_alchemer_reporting_values(
    survey_id  = survey_id,
    api_token  = api_token,
    api_secret = api_secret
  )
  .write_table_by_extension(result, output_path)

  abs_path <- normalizePath(output_path, mustWork = TRUE)
  cat(sprintf(
    "Wrote %d rows (%d questions) to:\n  %s\n",
    nrow(result),
    length(unique(result$question_id)),
    abs_path
  ))
  invisible(result)
}

# ---- CLI entry point ---------------------------------------------------------

if (sys.nframe() == 0L && !interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1L) {
    stop(
      "Usage: Rscript fetch_alchemer_reporting_values.R <survey_id> [output.csv]",
      call. = FALSE
    )
  }
  survey_id_arg <- args[[1L]]
  output_path   <- if (length(args) >= 2L) args[[2L]] else
    sprintf("alchemer_%s_reporting_values.csv", survey_id_arg)

  result <- fetch_alchemer_reporting_values(survey_id_arg)
  data.table::fwrite(result, output_path)
  cat(sprintf(
    "Wrote %d rows (%d questions) to %s\n",
    nrow(result),
    length(unique(result$question_id)),
    output_path
  ))
}
