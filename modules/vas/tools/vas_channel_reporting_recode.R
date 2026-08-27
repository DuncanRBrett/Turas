#!/usr/bin/env Rscript
# Recode channel-option reporting values across all channel questions of a survey.
#   Rscript modules/vas/tools/vas_channel_reporting_recode.R <survey_id> <preview|apply>
# preview = read-only (no writes), reports what WOULD change.
# apply   = writes each changed option's `value`, then read-back-verifies with retry.
# Mapping (12 channels) -> custom code; every other option -> its own label (as-is).
#
# General Alchemer tool - it takes the survey id as an argument and hardcodes
# nothing. The API driver lives in main(); the mapping and the decision logic
# are plain functions, tested network-free in test-vas_channel_recode.R.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

VAS_CHANNEL_RECODE_MAP <- list(
 "bank: atm"="Bank ATM",
 "bank: on their website"="Bank Website",
 "bank: app on your mobile phone"="Bank App",
 "bank: short codes / ussd (e.g. *130*567# on your phone)"="Bank USSD",
 "retailer: till point (e.g. pick n pay or shoprite teller) using a card"="Retailer tillpoint card",
 "retailer: till point (e.g. pick n pay or shoprite teller) using cash"="Retailer tillpoint cash",
 "retailer: money market counter"="Retailer money counter",
 "retailer: app on your mobile phone (e.g. takealot, clicks app, pnp app, mrprice app, etc.)"="Retailer App",
 "retailer: on their website"="Retailer website",
 "mobile network provider: app on phone (e.g. mtn, vodacom, cell-c, telkom mobile)"="MNO App",
 "spaza shop / kiosk"="Spaza Shop / Kiosk",
 "other (please specify)"="Other",
 # short-distance-bus abbreviated wording -> same codes (confirmed with Duncan)
 "retail : till points using a card"="Retailer tillpoint card",
 "retail: till points using cash"="Retailer tillpoint cash",
 "retail : money market counters"="Retailer money counter",
 "spaza shop / kiosks"="Spaza Shop / Kiosk"
)

flat <- function(x) if (is.list(x)) x[[1]] else x

#' Strip HTML and collapse whitespace out of an Alchemer title or value
strip_title <- function(s) {
  s <- flat(s) %||% ""
  s <- gsub("<[^>]*>", " ", s)
  s <- gsub("&nbsp;", " ", s)
  s <- gsub("\u00a0", " ", s)  # Alchemer titles carry literal non-breaking spaces
  trimws(gsub("[[:space:]]+", " ", s))
}

#' The matching key for an option title: stripped and lower-cased
norm_title <- function(s) tolower(strip_title(s))

#' Decide the reporting value an option should carry
#'
#' A title in the channel map gets its code; any other option gets its own
#' cleaned label, unchanged.
#'
#' @param title The option title as the API returns it.
#'
#' @return A list: \code{target} (the value the option should have) and
#'   \code{mapped} (TRUE when the title is one of the 12 channels).
recode_target <- function(title) {
  key <- norm_title(title)
  mapped <- !is.null(VAS_CHANNEL_RECODE_MAP[[key]])
  target <- if (mapped) VAS_CHANNEL_RECODE_MAP[[key]] else strip_title(title)
  return(list(target = target, mapped = mapped, key = key))
}

main <- function() {
  suppressPackageStartupMessages(library(httr))
  args <- commandArgs(trailingOnly = TRUE)
  SID  <- args[1]
  MODE <- if (length(args) >= 2) args[2] else "preview"
  creds <- list(api_token = Sys.getenv("ALCHEMER_API_TOKEN"),
                api_token_secret = Sys.getenv("ALCHEMER_API_SECRET"))
  get <- function(path, q = list()) {
    r <- httr::GET(paste0("https://api.alchemer.com/v5", path), query = c(q, creds), httr::timeout(60))
    if (httr::http_error(r)) return(NULL)
    httr::content(r, as = "parsed", type = "application/json")
  }
  post <- function(path, q = list()) {
    r <- httr::POST(paste0("https://api.alchemer.com/v5", path), query = c(q, creds), httr::timeout(60))
    httr::content(r, as = "parsed", type = "application/json")
  }

  # collect channel questions (those with at least two mapped channel options)
  qs <- list()
  for (pg in 1:8) {
    b <- get(sprintf("/survey/%s/surveyquestion", SID), list(resultsperpage = 500, page = pg))
    if (is.null(b$data)) break
    for (q in b$data) {
      ts <- vapply(q$options %||% list(), function(o) norm_title(o$title), "")
      if (sum(ts %in% names(VAS_CHANNEL_RECODE_MAP)) >= 2) qs[[length(qs) + 1]] <- q
    }
    if (pg >= as.integer(b$total_pages %||% 1)) break
  }

  cat("survey", SID, "| MODE:", MODE, "| channel questions:", length(qs), "\n\n")
  n_map <- 0; n_extra <- 0; n_change <- 0; n_skip <- 0; n_fail <- 0
  matched_keys <- c(); extras <- c(); fails <- c()
  for (q in qs) {
    qid <- q$id
    changes <- list()  # oid(char) -> target value
    for (o in q$options %||% list()) {
      oid <- as.character(o$id)
      decision <- recode_target(o$title)
      cur <- strip_title(o$value)
      if (decision$mapped) { n_map <- n_map + 1; matched_keys <- c(matched_keys, decision$key) }
      else { n_extra <- n_extra + 1; extras <- c(extras, decision$target) }
      if (identical(cur, decision$target)) { n_skip <- n_skip + 1 } else { changes[[oid]] <- decision$target }
    }
    if (length(changes) == 0) next
    if (MODE != "apply") { n_change <- n_change + length(changes); next }
    # round-based write + read-back-verify (resilient to write-lag)
    pending <- changes
    for (round in 1:6) {
      for (oid in names(pending)) {
        post(sprintf("/survey/%s/surveyquestion/%s/surveyoption/%s", SID, qid, oid),
             list(`_method` = "POST", value = pending[[oid]]))
        Sys.sleep(0.25)
      }
      Sys.sleep(2)
      q2 <- get(sprintf("/survey/%s/surveyquestion/%s", SID, qid))
      still <- list()
      for (oid in names(pending)) {
        o2 <- Filter(function(o) as.character(o$id) == oid, q2$data$options %||% list())
        val <- if (length(o2)) strip_title(o2[[1]]$value) else NA_character_
        if (!identical(val, pending[[oid]])) still[[oid]] <- pending[[oid]]
      }
      pending <- still
      if (length(pending) == 0) break
    }
    n_change <- n_change + (length(changes) - length(pending))
    if (length(pending) > 0) {
      for (oid in names(pending)) {
        n_fail <- n_fail + 1
        fails <- c(fails, sprintf("qid%s opt%s -> %s", qid, oid, pending[[oid]]))
      }
    }
    cat("  qid", qid, "(", q$shortname %||% "?", "):", length(changes) - length(pending),
        "changed,", length(pending), "failed\n")
  }
  cat("--- SUMMARY (", MODE, ") ---\n")
  cat("options mapped to a code:", n_map,
      " (", length(unique(matched_keys)), "of 12 distinct channels seen)\n")
  cat("options set to own label (extras):", n_extra, "\n")
  cat(if (MODE == "apply") "changed + verified:" else "WOULD change:", n_change,
      " | already correct (skipped):", n_skip, "\n")
  if (MODE == "apply") cat("FAILED to verify:", n_fail, "\n")
  if (length(fails)) { cat("\nFAILURES:\n"); for (f in fails) cat("  ", f, "\n") }
  miss <- setdiff(names(VAS_CHANNEL_RECODE_MAP), unique(matched_keys))
  if (length(miss)) {
    cat("\n[!] mapping keys never matched any option (check wording):\n")
    for (m in miss) cat("   -", m, "\n")
  }
  cat("\ndistinct EXTRA labels (each becomes its own reporting value):\n")
  for (x in sort(unique(extras))) cat("   ", x, "\n")
}

if (sys.nframe() == 0L && !interactive()) {
  main()
}
