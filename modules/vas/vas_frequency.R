# vas_frequency.R
# ------------------------------------------------------------------------------
# Convert the VAS frequency cascade to transactions per month.
#
# All 35 cascade questions in survey 8912114 share one option set, verified
# against the survey structure on 22 July 2026:
#
#   Freq1  "Once a week or more often" -> Freq2, a count 1-7 per week
#          "A few times in a month"    -> Freq3, a count 1-4 per month
#          "Once per month"            -> no follow-up question by design
#          "Less than once per month"  -> Freq4, a count 1-11 per year, or
#                                          "Don't know"
#
# Freq1 has no "never" option: a respondent who does not buy the category is
# routed past the whole cascade, so a blank Freq1 means "not asked" and is the
# caller's cue to record a genuine zero rather than a missing value.
#
# Pure logic only: strings in, numbers out, no I/O.
# ------------------------------------------------------------------------------

# The four Freq1 answers, exactly as they are stored as reporting values.
VAS_FREQ1_WEEKLY <- "Once a week or more often"
VAS_FREQ1_FEW_PER_MONTH <- "A few times in a month"
VAS_FREQ1_MONTHLY <- "Once per month"
VAS_FREQ1_LESS_THAN_MONTHLY <- "Less than once per month"

VAS_FREQ1_LEVELS <- c(
  VAS_FREQ1_WEEKLY, VAS_FREQ1_FEW_PER_MONTH,
  VAS_FREQ1_MONTHLY, VAS_FREQ1_LESS_THAN_MONTHLY
)

# Statuses returned alongside the count.
VAS_FREQ_STATUS <- c(
  "not_asked",    # blank Freq1 - routed past the category, so a genuine zero
  "ok",           # a transactions-per-month figure was derived
  "dont_know",    # Freq4 = "Don't know", or the follow-up was left blank
  "unrecognised"  # Freq1 held something that is not one of the four options
)

#' Coerce a follow-up count answer to a number
#'
#' Freq2, Freq3 and Freq4 are radio questions whose reporting values are the
#' digits themselves, plus "Don't know" on Freq4.
#'
#' @param value A single character answer.
#'
#' @return A single numeric value, or NA_real_ when the answer is blank,
#'   "Don't know", or anything else non-numeric.
parse_frequency_count <- function(value) {
  if (is.na(value)) {
    return(NA_real_)
  }
  trimmed <- trimws(as.character(value))
  if (!nzchar(trimmed)) {
    return(NA_real_)
  }
  return(suppressWarnings(as.numeric(trimmed)))
}

#' Convert one respondent's frequency cascade to transactions per month
#'
#' @param freq1 The Freq1 answer (character, may be NA).
#' @param freq2 The weekly count answer (character, may be NA).
#' @param freq3 The per-month count answer (character, may be NA).
#' @param freq4 The annual count answer (character, may be NA).
#' @param config The VAS_CONFIG list.
#'
#' @return A list with \code{txn_per_month} (numeric, NA when unusable) and
#'   \code{status} (one of \code{VAS_FREQ_STATUS}).
#'
#' @examples
#' \dontrun{
#'   # four times a year -> 0.25 transactions per month
#'   frequency_to_txn_scalar("Less than once per month", NA, NA, "4", VAS_CONFIG)
#' }
frequency_to_txn_scalar <- function(freq1, freq2, freq3, freq4, config) {
  answer <- if (is.na(freq1)) "" else trimws(as.character(freq1))
  if (!nzchar(answer)) {
    return(list(txn_per_month = NA_real_, status = "not_asked"))
  }
  if (!answer %in% VAS_FREQ1_LEVELS) {
    return(list(txn_per_month = NA_real_, status = "unrecognised"))
  }

  txn <- switch(answer,
    `Once a week or more often` = parse_frequency_count(freq2) * config$weeks_per_month,
    `A few times in a month`    = parse_frequency_count(freq3),
    `Once per month`            = config$once_per_month_value,
    `Less than once per month`  = parse_frequency_count(freq4) / config$months_per_year
  )

  if (is.na(txn)) {
    return(list(txn_per_month = NA_real_, status = "dont_know"))
  }
  return(list(txn_per_month = txn, status = "ok"))
}

#' Convert frequency cascades to transactions per month, vectorised
#'
#' @param freq1,freq2,freq3,freq4 Character vectors of equal length holding the
#'   four cascade answers, one element per respondent.
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame with one row per respondent: \code{txn_per_month}
#'   (numeric) and \code{status} (character).
#'
#' @throws Stops with class "vas_length_mismatch" when the four inputs differ
#'   in length.
frequency_to_txn_per_month <- function(freq1, freq2, freq3, freq4, config) {
  lengths_seen <- c(length(freq1), length(freq2), length(freq3), length(freq4))
  if (length(unique(lengths_seen)) != 1L) {
    stop(structure(
      class = c("vas_length_mismatch", "error", "condition"),
      list(
        message = sprintf(
          "Frequency inputs differ in length: freq1=%d, freq2=%d, freq3=%d, freq4=%d. All four must be one element per respondent.",
          lengths_seen[1], lengths_seen[2], lengths_seen[3], lengths_seen[4]
        ),
        call = NULL
      )
    ))
  }
  if (!lengths_seen[1]) {
    return(data.frame(txn_per_month = numeric(0), status = character(0),
                      stringsAsFactors = FALSE))
  }

  derived <- lapply(seq_along(freq1), function(i) {
    frequency_to_txn_scalar(freq1[i], freq2[i], freq3[i], freq4[i], config)
  })
  return(data.frame(
    txn_per_month = vapply(derived, function(d) d$txn_per_month, numeric(1)),
    status        = vapply(derived, function(d) d$status, character(1)),
    stringsAsFactors = FALSE
  ))
}
