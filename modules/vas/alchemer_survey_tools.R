# alchemer_survey_tools.R
#
# Read/write helpers for the Alchemer v5 REST API, used for maintaining the
# 2026 VAS Survey (8912114) and its copies.
#
# Auth comes from ~/.Renviron:
#   ALCHEMER_API_TOKEN
#   ALCHEMER_API_SECRET
#
# Usage:
#   source("alchemer_survey_tools.R")
#   snap  <- alch_snapshot(8912114)            # full JSON -> backups/, index -> CSV
#   idx   <- alch_index(8912114)               # page/question index as data frame
#   q     <- alch_get_question(8912114, 10, 45) # one question, full detail

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
})

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

.alch_creds <- function() {
  tok <- Sys.getenv("ALCHEMER_API_TOKEN")
  sec <- Sys.getenv("ALCHEMER_API_SECRET")
  if (!nzchar(tok) || !nzchar(sec)) {
    stop("ALCHEMER_API_TOKEN / ALCHEMER_API_SECRET not set in ~/.Renviron")
  }
  list(api_token = tok, api_token_secret = sec)
}

.alch_base <- "https://api.alchemer.com/v5"

# ---- core request -------------------------------------------------------------
# Alchemer v5 takes the HTTP verb as a query parameter (_method) for PUT/DELETE
# in some client setups; we use real verbs, which the API accepts.
alch_request <- function(path, method = "GET", query = list(), body = NULL,
                         verbose = FALSE) {
  url <- paste0(.alch_base, "/", sub("^/", "", path))
  q   <- c(.alch_creds(), query)

  fn <- switch(toupper(method),
    GET    = httr::GET,
    POST   = httr::POST,
    PUT    = httr::PUT,
    DELETE = httr::DELETE,
    stop("Unsupported method: ", method)
  )

  args <- list(url, query = q)
  # Large payloads (e.g. creating a response with hundreds of answers) blow the
  # URL length limit, and Alchemer then returns an HTML error page rather than
  # JSON. Send those as a form-encoded body instead.
  if (!is.null(body)) { args$body <- body; args$encode <- "form" }
  if (verbose) args$config <- httr::verbose()

  resp <- do.call(fn, args)
  txt <- httr::content(resp, as = "text", encoding = "UTF-8")
  if (!grepl("^\\s*[\\{\\[]", txt)) {
    return(list(status = httr::status_code(resp), ok = FALSE,
                message = sprintf("non-JSON response (%d bytes) - likely URL too long or a server error",
                                  nchar(txt)),
                data = NULL, raw = substr(txt, 1, 400)))
  }
  parsed <- jsonlite::fromJSON(txt, simplifyVector = FALSE)

  list(
    status  = httr::status_code(resp),
    ok      = isTRUE(parsed$result_ok),
    message = parsed$message %||% NA_character_,
    data    = parsed$data,
    raw     = parsed
  )
}

# ---- survey structure ---------------------------------------------------------
alch_get_survey <- function(survey_id) {
  r <- alch_request(sprintf("survey/%s", survey_id))
  if (!r$ok) stop(sprintf("Survey fetch failed (%s): %s", r$status, r$message))
  r$data
}

# One flat row per question, with page context.
alch_index <- function(survey_id, survey = NULL) {
  d <- survey %||% alch_get_survey(survey_id)
  rows <- list()
  for (pi in seq_along(d$pages)) {
    p <- d$pages[[pi]]
    qs <- p$questions %||% list()
    if (length(qs) == 0L) {
      rows[[length(rows) + 1L]] <- data.frame(
        page_pos = pi, page_id = p$id %||% NA, page_title = .flat(p$title),
        q_pos = NA_integer_, q_id = NA, alias = NA_character_,
        type = NA_character_, subtype = NA_character_,
        required = NA, n_options = NA_integer_, q_title = NA_character_,
        stringsAsFactors = FALSE
      )
      next
    }
    for (qi in seq_along(qs)) {
      q <- qs[[qi]]
      rows[[length(rows) + 1L]] <- data.frame(
        page_pos   = pi,
        page_id    = p$id %||% NA,
        page_title = .flat(p$title),
        q_pos      = qi,
        q_id       = q$id %||% NA,
        alias      = q$shortname %||% NA_character_,
        type       = q$`_type` %||% q$type %||% NA_character_,
        subtype    = q$`_subtype` %||% NA_character_,
        required   = isTRUE(q$properties$required),
        n_options  = length(q$options %||% list()),
        q_title    = .flat(q$title),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

.flat <- function(x) {
  if (is.null(x)) return(NA_character_)
  if (is.list(x)) x <- x$English %||% unlist(x)[1]
  x <- as.character(x)[1]
  x <- gsub("<[^>]+>", " ", x)          # strip html
  x <- gsub("&nbsp;", " ", x, fixed = TRUE)
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

# ---- snapshot (backup before edits) -------------------------------------------
alch_snapshot <- function(survey_id, dir = "backups", stamp = NULL) {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  stamp <- stamp %||% format(Sys.time(), "%Y%m%d_%H%M%S")

  d <- alch_get_survey(survey_id)

  json_path <- file.path(dir, sprintf("survey_%s_%s.json", survey_id, stamp))
  writeLines(jsonlite::toJSON(d, auto_unbox = TRUE, pretty = TRUE, null = "null"),
             json_path)

  idx <- alch_index(survey_id, survey = d)
  csv_path <- file.path(dir, sprintf("survey_%s_%s_index.csv", survey_id, stamp))
  utils::write.csv(idx, csv_path, row.names = FALSE, na = "")

  message(sprintf("Snapshot saved:\n  %s\n  %s", json_path, csv_path))
  invisible(list(survey = d, index = idx, json = json_path, csv = csv_path))
}

# ---- single question ----------------------------------------------------------
alch_get_question <- function(survey_id, page_id, question_id) {
  r <- alch_request(sprintf("survey/%s/surveypage/%s/surveyquestion/%s",
                            survey_id, page_id, question_id))
  if (!r$ok) stop(sprintf("Question fetch failed (%s): %s", r$status, r$message))
  r$data
}

alch_get_options <- function(survey_id, page_id, question_id) {
  r <- alch_request(sprintf("survey/%s/surveypage/%s/surveyquestion/%s/surveyoption",
                            survey_id, page_id, question_id),
                    query = list(resultsperpage = 200))
  if (!r$ok) stop(sprintf("Option fetch failed (%s): %s", r$status, r$message))
  r$data
}
