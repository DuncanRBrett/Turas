# vas_derive_category.R
# ------------------------------------------------------------------------------
# The per-category calculation: one row of vas_category_map.csv at a time.
#
# Everything that differs between categories is read from the map row and the
# config - which frequency questions to use, whether the amount is a monthly, a
# per-transaction or a last-occasion figure, and whether the spend is imputed.
# Nothing about a specific category is written into this code.
#
# Three measures come out, per respondent:
#   txn_per_month   transactions per month
#   monthly_spend   rand per month
#   spend_per_txn   rand per transaction
#
# and a status saying how each respondent was treated:
#   not_asked       routed past this category - a genuine zero, not a gap
#   ok              all three measures derived
#   freq_missing    the respondent buys, but the count is unusable
#   amount_missing  the respondent buys, but the amount is unusable
# ------------------------------------------------------------------------------

VAS_CATEGORY_STATUS <- c("not_asked", "ok", "freq_missing", "amount_missing")

#' Decide which respondents were asked about a category at all
#'
#' Presence is read in whichever way the map row supports, in this order:
#' an explicit presence option on another question (the bill checkboxes); the
#' frequency cascade having been shown; the count question having been shown;
#' otherwise the amount question having been shown. A blank throughout means
#' the respondent was routed past the category, which is a real zero.
#'
#' @param source A vas_source object.
#' @param row One row of the category map.
#'
#' @return A logical vector, one element per respondent.
category_presence <- function(source, row) {
  if (!is.na(row$presence_alias)) {
    return(source_option(source, row$presence_alias, row$presence_option))
  }
  probe_alias <- if (!is.na(row$freq1)) {
    row$freq1
  } else if (!is.na(row$count_alias)) {
    row$count_alias
  } else {
    row$amount_alias
  }
  return(!is.na(source_scalar(source, probe_alias)))
}

#' Read a count question's top code at its lower bound
#'
#' The count questions cap at "12+" with a free-text specify box beside them,
#' and that box collects a reason as often as a number. Reading "12+" as
#' unusable left a real buyer with no trips and no spend, so the top code is
#' taken as the number it names - a floor, and the honest one, because the
#' alternative is discarding the answer entirely.
#'
#' @param answer A character vector of count answers.
#' @param config The VAS_CONFIG list.
#'
#' @return The same vector with any "<n>+" replaced by "<n>".
resolve_count_top_code <- function(answer, config) {
  if (!isTRUE(config$count_top_code_at_lower_bound)) {
    return(answer)
  }
  top <- !is.na(answer) & grepl("^\\s*[0-9]+\\s*\\+\\s*$", answer)
  answer[top] <- sub("^\\s*([0-9]+)\\s*\\+\\s*$", "\\1", answer[top])
  return(answer)
}

#' Read a travel count question and convert it to transactions per month
#'
#' The count questions ask how many tickets were bought in the past 12 months,
#' so a transaction is a ticket purchase and the monthly rate is count / 12.
#'
#' @param source A vas_source object.
#' @param row One row of the category map.
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame of \code{txn_per_month} and \code{status}.
count_to_txn_per_month <- function(source, row, config) {
  raw <- source_scalar(source, row$count_alias)
  # the zero test and the not-asked test stay on the RAW answer: only the
  # numeric reading is relaxed
  numeric_count <- suppressWarnings(as.numeric(resolve_count_top_code(raw, config)))
  numeric_count[!is.na(raw) & raw %in% config$count_zero_values] <- 0
  status <- ifelse(is.na(raw), "not_asked",
                   ifelse(is.na(numeric_count), "freq_missing", "ok"))
  return(data.frame(
    txn_per_month = numeric_count / config$months_per_year,
    status = status,
    stringsAsFactors = FALSE
  ))
}

#' Derive transactions per month for one category and base
#'
#' Dispatches on what the map row provides: a frequency cascade, an assumed
#' cadence for the questions that never ask a frequency, or a 12-month count.
#'
#' @param source A vas_source object.
#' @param row One row of the category map.
#' @param present Logical vector from \code{category_presence()}.
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame of \code{txn_per_month} and \code{status}.
#'
#' @throws Stops with class "vas_map_incomplete" when a row offers no way of
#'   establishing a frequency.
category_txn_per_month <- function(source, row, present, config) {
  derived <- if (!is.na(row$freq1)) {
    frequency <- frequency_to_txn_per_month(
      source_scalar(source, row$freq1), source_scalar(source, row$freq2),
      source_scalar(source, row$freq3), source_scalar(source, row$freq4), config
    )
    data.frame(
      txn_per_month = frequency$txn_per_month,
      status = ifelse(frequency$status == "ok", "ok",
                      ifelse(frequency$status == "not_asked", "not_asked", "freq_missing")),
      stringsAsFactors = FALSE
    )
  } else if (!is.na(row$assumed_cadence)) {
    rate <- config$cadence_txn_per_month[[row$assumed_cadence]]
    if (is.null(rate)) {
      stop(structure(class = c("vas_map_incomplete", "error", "condition"), list(
        message = sprintf("Category '%s' (%s) has assumed_cadence '%s', which is not in config$cadence_txn_per_month.",
                          row$category, row$base, row$assumed_cadence), call = NULL)))
    }
    data.frame(txn_per_month = rep(rate, length(present)),
               status = rep("ok", length(present)), stringsAsFactors = FALSE)
  } else if (!is.na(row$count_alias)) {
    count_to_txn_per_month(source, row, config)
  } else {
    stop(structure(class = c("vas_map_incomplete", "error", "condition"), list(
      message = sprintf("Category '%s' (%s) has no freq1, no assumed_cadence and no count_alias, so transactions per month cannot be derived.",
                        row$category, row$base), call = NULL)))
  }

  derived$txn_per_month[!present] <- 0
  derived$status[!present] <- "not_asked"
  return(derived)
}

#' Read how many legs each of a respondent's trips is worth
#'
#' The count questions ask how many flights or bus tickets were bought, and a
#' companion question asks whether that number is of one-way or return trips.
#' A return trip is therefore two legs. A blank answer falls back to
#' \code{config$legs_default}.
#'
#' @param source A vas_source object.
#' @param row One row of the category map.
#' @param config The VAS_CONFIG list.
#'
#' @return A numeric vector of legs per trip, one element per respondent.
travel_legs_per_trip <- function(source, row, config) {
  legs_answer <- source_scalar(source, row$legs_alias)
  return(vapply(legs_answer, function(answer) {
    if (is.na(answer)) return(as.numeric(config$legs_default))
    matched <- config$legs_per_trip[[answer]]
    if (is.null(matched)) as.numeric(config$legs_default) else as.numeric(matched)
  }, numeric(1), USE.NAMES = FALSE))
}

#' Read the imputed spend per transaction for a count-based travel category
#'
#' The survey asks whether the respondent's count refers to one-way or return
#' trips, so a trip is converted to legs first and priced per leg.
#'
#' @param source A vas_source object.
#' @param row One row of the category map.
#' @param config The VAS_CONFIG list.
#'
#' @return A numeric vector of rand per transaction.
#'
#' @throws Stops with class "vas_map_incomplete" when no per-leg rate is set.
imputed_travel_spend_per_txn <- function(source, row, config) {
  rate <- config$imputed_spend_per_leg[[row$category]]
  if (is.null(rate)) {
    stop(structure(class = c("vas_map_incomplete", "error", "condition"), list(
      message = sprintf("Category '%s' has an imputed amount basis but no entry in config$imputed_spend_per_leg.",
                        row$category), call = NULL)))
  }
  return(travel_legs_per_trip(source, row, config) * rate)
}

#' Derive legs a year for a count-based travel category
#'
#' The reportable travel figure is legs a year, not transactions a month: every
#' respondent in these categories buys less than monthly, so a monthly rate puts
#' the whole base in one band and says nothing. A return trip counts twice,
#' which is also what the imputed price is charged on, so this column and
#' MonthlySpend describe the same journeys.
#'
#' Categories that are not count-based get NA - they have no leg to count.
#'
#' @param source A vas_source object.
#' @param row One row of the category map.
#' @param txn A data frame from \code{category_txn_per_month()}.
#' @param config The VAS_CONFIG list.
#'
#' @return A numeric vector, one element per respondent.
category_trips_per_year <- function(source, row, txn, config) {
  if (is.na(row$count_alias)) {
    return(rep(NA_real_, nrow(txn)))
  }
  legs <- travel_legs_per_trip(source, row, config)
  return(txn$txn_per_month * config$months_per_year * legs)
}

#' Derive monthly spend and spend per transaction for one category and base
#'
#' @param source A vas_source object.
#' @param row One row of the category map.
#' @param txn A data frame from \code{category_txn_per_month()}.
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame of \code{monthly_spend}, \code{spend_per_txn} and
#'   \code{amount_ok} (logical: an amount was available for this respondent).
category_spend <- function(source, row, txn, config) {
  n <- nrow(txn)
  if (identical(row$amount_basis, "imputed")) {
    per_txn <- if (!is.na(row$count_alias)) {
      imputed_travel_spend_per_txn(source, row, config)
    } else {
      rep(as.numeric(config$imputed_annual_fee[[row$category]]), n)
    }
    return(data.frame(monthly_spend = txn$txn_per_month * per_txn,
                      spend_per_txn = per_txn, amount_ok = rep(TRUE, n),
                      stringsAsFactors = FALSE))
  }

  amount <- parse_amount(source_scalar(source, row$amount_alias),
                         config_for_spend_class(config, row$spend_class))
  amount_ok <- !is.na(amount$value)

  if (identical(row$amount_basis, "monthly")) {
    monthly_spend <- amount$value
    spend_per_txn <- ifelse(is.na(txn$txn_per_month) | txn$txn_per_month == 0,
                            NA_real_, monthly_spend / txn$txn_per_month)
  } else {
    # per_txn and last_occasion both give a per-transaction figure
    monthly_spend <- txn$txn_per_month * amount$value
    spend_per_txn <- amount$value
  }
  return(data.frame(monthly_spend = monthly_spend, spend_per_txn = spend_per_txn,
                    amount_ok = amount_ok, stringsAsFactors = FALSE))
}

#' Flag the cells whose figures breach the spend class's plausibility ceiling
#'
#' A flag NEVER changes a number. It marks a collected answer whose derived
#' transactions per month or monthly spend exceeds the configured ceiling for
#' its spend class, so it can be reviewed and, where needed, excluded in
#' reporting. A class with no ceiling configured is never flagged.
#'
#' @param txn_per_month Numeric vector of derived transactions per month.
#' @param monthly_spend Numeric vector of derived monthly spend.
#' @param spend_class The map row's spend class.
#' @param config The VAS_CONFIG list.
#'
#' @return A logical vector, one element per respondent, never NA.
category_outlier_flags <- function(txn_per_month, monthly_spend, spend_class, config) {
  over <- function(values, ceiling_table) {
    ceiling_value <- if (is.null(ceiling_table)) NULL else ceiling_table[[spend_class]]
    if (is.null(ceiling_value)) {
      return(rep(FALSE, length(values)))
    }
    return(!is.na(values) & values > ceiling_value)
  }
  return(over(txn_per_month, config$outlier_txn_per_month) |
           over(monthly_spend, config$outlier_monthly_spend))
}

#' Derive every measure for one category and base
#'
#' @param source A vas_source object.
#' @param row One row of the category map.
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame with one row per respondent: \code{txn_per_month},
#'   \code{monthly_spend}, \code{spend_per_txn}, \code{trips_per_year},
#'   \code{status}, \code{outlier}.
derive_category_base <- function(source, row, config) {
  present <- category_presence(source, row)
  txn <- category_txn_per_month(source, row, present, config)
  spend <- category_spend(source, row, txn, config)
  trips_per_year <- category_trips_per_year(source, row, txn, config)

  status <- txn$status
  status[status == "ok" & !spend$amount_ok] <- "amount_missing"

  monthly_spend <- spend$monthly_spend
  spend_per_txn <- spend$spend_per_txn

  # a respondent routed past the category spends nothing, and has no
  # per-transaction figure because there were no transactions
  monthly_spend[!present] <- 0
  spend_per_txn[!present] <- NA_real_
  spend_per_txn[!is.na(txn$txn_per_month) & txn$txn_per_month == 0] <- NA_real_
  monthly_spend[status == "amount_missing"] <- NA_real_
  # legs a year needs no zeroing of its own: transactions per month is already
  # 0 for a respondent routed past, and NA where the count could not be read

  return(data.frame(
    txn_per_month = txn$txn_per_month, monthly_spend = monthly_spend,
    spend_per_txn = spend_per_txn, trips_per_year = trips_per_year,
    status = status,
    # the amount specifically is unusable - distinct from a missing FREQUENCY,
    # which also lands in the combined "partial" status but leaves a known
    # amount perfectly reportable
    amount_unknown = status %in% "amount_missing",
    outlier = category_outlier_flags(txn$txn_per_month, monthly_spend,
                                     row$spend_class, config),
    stringsAsFactors = FALSE
  ))
}
