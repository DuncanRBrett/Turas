# helper-vas_fixtures.R
# Shared literal fixtures for the VAS derived-variable tests. Everything here is
# hand-written data - no randomness, no network, no dependence on the survey.

VAS_PROJECT_ROOT <- normalizePath(file.path("..", ".."), mustWork = TRUE)

for (script in c("vas_derived_config.R", "vas_amount_parser.R", "vas_frequency.R",
                 "vas_read_source.R", "vas_derive_category.R", "vas_derive.R",
                 "vas_sense_check.R", "vas_pipeline.R", "vas_data_dictionary.R",
                 "vas_data_dictionary_headline.R", "vas_write_excel.R",
                 "vas_register.R", "vas_turas_plan.R", "vas_turas_structure.R",
                 "vas_turas_build.R")) {
  source(file.path(VAS_PROJECT_ROOT, script))
}

#' Build a vas_source from literal columns, for tests
#'
#' @param ... Named character vectors, one per column, all the same length.
#'
#' @return A vas_source object with sequential response ids.
fixture_source <- function(...) {
  columns <- list(...)
  n <- length(columns[[1]])
  return(new_vas_source(
    origin = "fixture",
    response_id = as.character(seq_len(n)),
    status = rep("Complete", n),
    columns = columns
  ))
}

#' Build one category-map row from named values, for tests
#'
#' Every column of the real map is present, so a fixture row can be passed
#' straight to the engine.
#'
#' @param ... Named values overriding the empty defaults.
#'
#' @return A one-row data frame.
fixture_map_row <- function(...) {
  defaults <- list(
    category = "TestCategory", label = "Test category", base = "Own",
    freq1 = NA_character_, freq2 = NA_character_, freq3 = NA_character_,
    freq4 = NA_character_, amount_alias = NA_character_,
    amount_basis = NA_character_, count_alias = NA_character_,
    legs_alias = NA_character_, presence_alias = NA_character_,
    presence_option = NA_character_, assumed_cadence = NA_character_,
    spend_class = "consumption", aliases_missing = ""
  )
  overrides <- list(...)
  defaults[names(overrides)] <- overrides
  return(as.data.frame(defaults, stringsAsFactors = FALSE))
}

#' Read the real category map from the project root
#'
#' @return The category map data frame, empty cells as NA.
fixture_real_map <- function() {
  return(utils::read.csv(file.path(VAS_PROJECT_ROOT, "vas_category_map.csv"),
                         stringsAsFactors = FALSE, na.strings = ""))
}

#' A source carrying every column a map needs, all answers blank
#'
#' Used to exercise the full column set without depending on live data.
#'
#' @param category_map The category map data frame.
#' @param n How many respondents.
#'
#' @return A vas_source object.
fixture_blank_source <- function(category_map, n = 2L) {
  alias_columns <- c("freq1", "freq2", "freq3", "freq4", "amount_alias",
                     "count_alias", "legs_alias")
  aliases <- unique(stats::na.omit(unlist(category_map[, alias_columns])))
  presence_rows <- category_map[!is.na(category_map$presence_alias), ]
  names_needed <- c(aliases,
                    paste0(presence_rows$presence_option, ":", presence_rows$presence_alias),
                    "Income")
  columns <- stats::setNames(
    rep(list(rep(NA_character_, n)), length(names_needed)), names_needed)
  return(new_vas_source("fixture", as.character(seq_len(n)),
                        rep("Complete", n), columns))
}

#' A two-respondent source spanning a split category, a transfer and a receipt
#'
#' Respondent 1 buys everything once a month; respondent 2 was routed past it
#' all and declined to give an income band.
#'
#' @return A vas_source object.
fixture_totals_source <- function() {
  return(fixture_source(
    Income = c("R8,000 to R21,999", "Decline to answer"),
    AirtimeOwnFreq1 = c("Once per month", NA), AirtimeOwnFreq2 = c(NA, NA),
    AirtimeOwnFreq3 = c(NA, NA), AirtimeOwnFreq4 = c(NA, NA),
    AirtimeOwnAmount = c("R50", NA),
    AirtimeOthFreq1 = c("Once per month", NA), AirtimeOthFreq2 = c(NA, NA),
    AirtimeOthFreq3 = c(NA, NA), AirtimeOthFreq4 = c(NA, NA),
    AirtimeOthAmount = c("R30", NA),
    DomSendFreq1 = c("Once per month", NA), DomSendFreq2 = c(NA, NA),
    DomSendFreq3 = c(NA, NA), DomSendFreq4 = c(NA, NA),
    DomSendAmount = c("R500", NA),
    DomRcvFreq1 = c("Once per month", NA), DomRcvFreq2 = c(NA, NA),
    DomRcvFreq3 = c(NA, NA), DomRcvFreq4 = c(NA, NA),
    DomRcvAmount = c("R200", NA)
  ))
}

#' A wallet-shaped source: split consumption, split obligation, unsplit
#' gambling, a transfer and a receipt
#'
#' Respondent 1 buys everything once a month (Lotto twice); respondent 2 was
#' routed past it all. Wallet arithmetic on respondent 1:
#'   wallet spend 50 + 30 + 100 + 40 + 20 = 240, self 170, for others 70,
#'   gambling 20; sent 500 and received 200 stay outside the wallet.
#'
#' @return A vas_source object.
fixture_wallet_source <- function() {
  return(fixture_source(
    Income = c("R8,000 to R21,999", "Decline to answer"),
    AirtimeOwnFreq1 = c("Once per month", NA), AirtimeOwnFreq2 = c(NA, NA),
    AirtimeOwnFreq3 = c(NA, NA), AirtimeOwnFreq4 = c(NA, NA),
    AirtimeOwnAmount = c("R50", NA),
    AirtimeOthFreq1 = c("Once per month", NA), AirtimeOthFreq2 = c(NA, NA),
    AirtimeOthFreq3 = c(NA, NA), AirtimeOthFreq4 = c(NA, NA),
    AirtimeOthAmount = c("R30", NA),
    BillMunOwnFreq1 = c("Once per month", NA), BillMunOwnFreq2 = c(NA, NA),
    BillMunOwnFreq3 = c(NA, NA), BillMunOwnFreq4 = c(NA, NA),
    BillMunOwnAmount = c("R100", NA),
    BillMunOthFreq1 = c("Once per month", NA), BillMunOthFreq2 = c(NA, NA),
    BillMunOthFreq3 = c(NA, NA), BillMunOthFreq4 = c(NA, NA),
    BillMunOthAmount = c("R40", NA),
    LottoFreq1 = c("A few times in a month", NA), LottoFreq2 = c(NA, NA),
    LottoFreq3 = c("2", NA), LottoFreq4 = c(NA, NA),
    LottoAmount = c("R10", NA),
    DomSendFreq1 = c("Once per month", NA), DomSendFreq2 = c(NA, NA),
    DomSendFreq3 = c(NA, NA), DomSendFreq4 = c(NA, NA),
    DomSendAmount = c("R500", NA),
    DomRcvFreq1 = c("Once per month", NA), DomRcvFreq2 = c(NA, NA),
    DomRcvFreq3 = c(NA, NA), DomRcvFreq4 = c(NA, NA),
    DomRcvAmount = c("R200", NA)
  ))
}

#' The seven-row category map matching \code{fixture_wallet_source()}
#'
#' @return A category map data frame.
fixture_wallet_map <- function() {
  cascade <- function(category, base, stem, amount, spend_class) {
    fixture_map_row(
      category = category, base = base, freq1 = paste0(stem, "1"),
      freq2 = paste0(stem, "2"), freq3 = paste0(stem, "3"), freq4 = paste0(stem, "4"),
      amount_alias = amount, amount_basis = "per_txn", spend_class = spend_class
    )
  }
  return(rbind(
    cascade("Airtime", "Own", "AirtimeOwnFreq", "AirtimeOwnAmount", "consumption"),
    cascade("Airtime", "Oth", "AirtimeOthFreq", "AirtimeOthAmount", "consumption"),
    cascade("BillMunicipal", "Own", "BillMunOwnFreq", "BillMunOwnAmount", "obligation"),
    cascade("BillMunicipal", "Oth", "BillMunOthFreq", "BillMunOthAmount", "obligation"),
    cascade("Lotto", "Total", "LottoFreq", "LottoAmount", "consumption"),
    cascade("DomSend", "Total", "DomSendFreq", "DomSendAmount", "transfer"),
    cascade("DomRcv", "Total", "DomRcvFreq", "DomRcvAmount", "received")
  ))
}

#' The four-row category map matching \code{fixture_totals_source()}
#'
#' @return A category map data frame.
fixture_totals_map <- function() {
  cascade <- function(category, base, stem, amount, spend_class) {
    fixture_map_row(
      category = category, base = base, freq1 = paste0(stem, "1"),
      freq2 = paste0(stem, "2"), freq3 = paste0(stem, "3"), freq4 = paste0(stem, "4"),
      amount_alias = amount, amount_basis = "per_txn", spend_class = spend_class
    )
  }
  return(rbind(
    cascade("Airtime", "Own", "AirtimeOwnFreq", "AirtimeOwnAmount", "consumption"),
    cascade("Airtime", "Oth", "AirtimeOthFreq", "AirtimeOthAmount", "consumption"),
    cascade("DomSend", "Total", "DomSendFreq", "DomSendAmount", "transfer"),
    cascade("DomRcv", "Total", "DomRcvFreq", "DomRcvAmount", "received")
  ))
}
