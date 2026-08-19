# vas_wallet_location.R
# ------------------------------------------------------------------------------
# Where the wallet is spent, and where its transactions happen: the month's
# total split across six places, in rand and in transactions.
#
# Duncan, 19 Aug 2026: "drop physical vs digital and rather show VAS wallet
# spend by location - Bank, Retailer, Mobile Network Provider, Spaza Shop,
# Other - show Actual rand spend and % distribution", then "make a new category
# for convenience store - everything else to other", then "we have distribution
# and details on spend here can we add a new batch of questions on number of
# transactions too".
#
# Every purchase occasion asks which channel the respondent uses MOST OFTEN.
# That answer places the whole of that occasion's month - its money and its
# transactions - at one location:
#
#   WalletLoc     the month's rand, six rows
#   WalletLocTxn  the month's transactions, six rows
#
# ONE QUESTION EACH, NOT SIX (Duncan, 19 Aug: "can we have all the walletloc_
# and wallettxnloc_ questions combined into 1 question?"). They are declared as
# Variable_Type = "Allocation", the tabs engine's constant-sum type: one
# numeric column per option, one table, one mean row per option. The six rows
# add up to the total above them, so the split reads off the table.
#
# WHAT THAT COST. An allocation table has no ratio row, so the "share of all
# wallet rand" line the six separate questions carried is gone. The six means
# still sum to the published total, so the share is a division away, but it is
# no longer printed.
#
# The six locations are:
#
#   1 Bank                 ATM, bank app, bank website, bank USSD
#   2 Retailer             till point, money counter, retailer app and website
#   3 Mobile Network Provider  the mobile network's app
#   4 Spaza Shop           spaza shop / kiosk
#   5 Convenience store    convenience store
#   6 Other                everything else, and any occasion with no channel
#                          answer
#
# Each six add up to their published total for every respondent - spend to
# TotalValueTransacted, transactions to TotalTxnTransacted - and the build
# REFUSES if they ever do not. That is the whole point: a split that does not
# reconcile to the published total is worse than no split.
#
# WHAT IS IN THE TOTALS. Consumption, obligation and transfer-sent - the same
# classes as TotalValueTransacted, which is the wallet plus money sent. Money
# received is not spend and is not here. Imputed travel costs are in it, at
# their monthly equivalent, because that is how they reach the wallet.
#
# A SPLIT CATEGORY IS RECONSTRUCTED from its own and other sides rather than
# read off the _Total_ column. One respondent (583) gave a don't-know for the
# municipal amount on one side and R300 on the other: the Total column is
# missing for them and the engine's own class-sum keeps the R300. Reading the
# Total column would lose it and the reconciliation would fail by R300. The
# transaction columns have no such hole today, but they take the same path so
# the two measures cannot drift apart.
# ------------------------------------------------------------------------------

# The locations, in the order they read. "label" is the short name a table
# header wants; "phrase" is the same thing inside a sentence. Shared with
# vas_channel_location.R, which folds each section's channel tables the same
# way, so a location means one thing across the whole report.
VAS_LOCATIONS <- data.frame(
  key = c("Bank", "Retailer", "MNO", "Spaza", "Convenience", "Other"),
  label = c("Bank", "Retailer", "Mobile Network Provider", "Spaza Shop",
            "Convenience store", "Other"),
  phrase = c("a bank", "a retailer", "a mobile network provider",
             "a spaza shop", "a convenience store", "somewhere else"),
  stringsAsFactors = FALSE
)
VAS_LOCATION_OTHER <- "Other"

# Raw survey channel value -> location. Every value the study offers that is
# not named here falls to Other, and so does a missing answer, so a channel
# added in a later wave lands somewhere sane rather than being dropped.
VAS_CHANNEL_LOCATION <- c(
  "Bank ATM" = "Bank", "Bank App" = "Bank", "Banking App" = "Bank",
  "Bank Website" = "Bank", "Bank USSD" = "Bank",
  "Retailer tillpoint cash" = "Retailer", "Retailer tillpoint card" = "Retailer",
  "Retailer money counter" = "Retailer", "Retailer App" = "Retailer",
  "Retailer website" = "Retailer",
  "Retailer: Till point" = "Retailer",
  "Retailer: Till point (e.g. Pick n Pay or Shoprite teller)" = "Retailer",
  "MNO App" = "MNO",
  "Spaza Shop / Kiosk" = "Spaza", "Spaza shop / kiosks" = "Spaza",
  "Convenience store" = "Convenience"
)

#' The location a raw channel answer belongs to
#'
#' An UNLISTED channel is always Other - that is what Other means. A MISSING
#' answer is a separate thing and the caller says what it is: the wallet split
#' wants Other, because money was spent and it has to go somewhere, while a
#' section's "which location most often" table wants NA, because a respondent
#' who was never asked has no answer to show.
#'
#' @param values A character vector of raw channel answers.
#' @param missing What a blank or NA resolves to.
#'
#' @return A character vector of location keys.
vas_location_of <- function(values, missing = VAS_LOCATION_OTHER) {
  values <- as.character(values)
  blank <- is.na(values) | !nzchar(trimws(values))
  where <- unname(VAS_CHANNEL_LOCATION[trimws(values)])
  where[is.na(where)] <- VAS_LOCATION_OTHER
  where[blank] <- missing
  return(where)
}

# Which categories each channel question speaks for. A channel is asked ONCE
# per occasion, not per category: all 14 bill types answer BillChannelMain, the
# 6 event types answer EventChannelMain, and both flight categories answer
# FlightChannelMain.
#
# THIS LIST IS DUPLICATED in build_vas_reporting_layer.py (OCCASION), which
# uses it for the channel pages. Keep the two in step. Nothing here can drift
# silently, though: wallet_location_columns() refuses on any category in the
# wallet total that this list does not place.
VAS_WALLET_OCCASION <- list(
  PPUChannelMain      = "PrepaidElectricity",
  AirtimeChannelMain  = "Airtime",
  DataChannelMain     = "Data",
  VoucherChannelMain  = "DigitalVouchers",
  BillChannelMain     = c("BillTraffic", "BillClothing", "BillFurniture",
                          "BillEducation", "BillHealth", "BillRetail",
                          "BillDSTV", "BillMunicipal", "BillTelkom",
                          "BillInsurance", "BillInternet", "BillVehicle",
                          "BillTVLicence", "BillOther"),
  DomSendChannelMain  = "DomSend",
  DomRcvChannelMain   = "DomRcv",
  IntlSendChannelMain = "IntlSend",
  LottoChannelMain    = "Lotto",
  BetChannelMain      = "Betting",
  FlightChannelMain   = c("FlightDomestic", "FlightInternational"),
  LDBusChannelMain    = "LongDistanceBus",
  SDBusChannelMain    = "ShortDistanceBus",
  EventChannelMain    = c("EventSportWatch", "EventSportPlay", "EventConcert",
                          "EventCultural", "EventTheatre", "EventOther")
)

# The spend classes the wallet totals are built from.
VAS_WALLET_CLASSES <- c("consumption", "obligation", "transfer")

# The two measures, and everything that differs between them. One code path
# builds both, so the money split and the transaction split cannot drift.
#   suffix  the per-category column ending, own / oth / total
#   prefix  what the new columns are called
#   total   the published column the six must add up to
#   per100  a hundredth of that total. It exists only so the report can print
#           the share as a percentage: the tabs ratio row is
#           Sum(numerator) / Sum(denominator), so dividing by a hundredth of
#           the total gives 0-100 rather than 0-1
#   percent when TRUE the column is that location's share of the respondent's
#           OWN total, 0-100, and the table reads as the average person's
#           split. That is NOT the same number as the location's share of all
#           the rand in the study - on the live data banks take 64% of the rand
#           but the average person puts 58% of their own wallet through one.
#           Both are true and they answer different questions, so each carries
#           its own wording.
VAS_WALLET_MEASURES <- list(
  spend = list(
    suffix = "MonthlySpend", code = "WalletLoc",
    total = "TotalValueTransacted",
    text = "VAS wallet spend a month, by where it happens"),
  spend_pct = list(
    suffix = "MonthlySpend", code = "WalletLocPct", percent = TRUE,
    total = "TotalValueTransacted",
    text = paste0("VAS wallet spend by where it happens - each person's own ",
                  "split, averaged (%)")),
  txn = list(
    suffix = "TxnPerMonth", code = "WalletLocTxn",
    total = "TotalTxnTransacted",
    text = "VAS wallet transactions a month, by where they happen"),
  txn_pct = list(
    suffix = "TxnPerMonth", code = "WalletLocTxnPct", percent = TRUE,
    total = "TotalTxnTransacted",
    text = paste0("VAS wallet transactions by where they happen - each ",
                  "person's own split, averaged (%)"))
)

# What these two questions replaced on 19 Aug: one numeric question per
# location, each carrying a ratio row for its share. The migration script has
# to take them out of the kept pair, or it would declare columns the build no
# longer produces.
VAS_WALLET_SUPERSEDED <- c(
  paste0("WalletLoc_", c("Bank", "Retailer", "MNO", "Spaza", "Convenience",
                         "Other", "Per100")),
  paste0("WalletLocTxn_", c("Bank", "Retailer", "MNO", "Spaza", "Convenience",
                            "Other", "Per100")))

# The wallet total in rand, named once. vas_wallet_section.R reconciles to the
# same column, so the two splits of the wallet cannot be against different
# denominators.
VAS_WALLET_TOTAL_COLUMN <- VAS_WALLET_MEASURES$spend$total

#' The measure spec for a name, refusing an unknown one outright
#'
#' @param measure "spend" or "txn".
#'
#' @return The list from \code{VAS_WALLET_MEASURES}.
wallet_measure <- function(measure) {
  if (!measure %in% names(VAS_WALLET_MEASURES)) {
    stop(sprintf("Unknown wallet measure '%s'. Use one of: %s.", measure,
                 paste(names(VAS_WALLET_MEASURES), collapse = ", ")))
  }
  return(VAS_WALLET_MEASURES[[measure]])
}

#' The member column name for one location and measure
#'
#' An Allocation question stores its options across \code{{code}_1 ...
#' {code}_N}, in the Options sheet's own order - so the column is named by
#' POSITION, not by the location's key.
#'
#' @param key A key from \code{VAS_LOCATIONS}.
#' @param measure "spend" or "txn".
#'
#' @return The data column name.
wallet_location_column <- function(key, measure = "spend") {
  at <- match(key, VAS_LOCATIONS$key)
  if (is.na(at)) stop(sprintf("Unknown location '%s'.", key))
  return(sprintf("%s_%d", wallet_measure(measure)$code, at))
}

#' One category's month on one measure, own and other sides reconstructed
#'
#' @param data The assembled data frame.
#' @param category The category stem.
#' @param suffix The column ending - "MonthlySpend" or "TxnPerMonth".
#'
#' @return A numeric vector, zero where the respondent did nothing.
wallet_category_value <- function(data, category, suffix) {
  zero <- rep(0, nrow(data))
  take <- function(name) {
    if (!name %in% names(data)) return(NULL)
    v <- suppressWarnings(as.numeric(data[[name]]))
    v[is.na(v)] <- 0
    return(v)
  }
  own <- take(sprintf("%s_Own_%s", category, suffix))
  oth <- take(sprintf("%s_Oth_%s", category, suffix))
  if (!is.null(own) || !is.null(oth)) {
    return((if (is.null(own)) zero else own) + (if (is.null(oth)) zero else oth))
  }
  total <- take(sprintf("%s_Total_%s", category, suffix))
  return(if (is.null(total)) zero else total)
}

#' Split every respondent's month across the six locations
#'
#' @param data The assembled data frame.
#' @param category_map The category map, for each category's spend class.
#' @param measure "spend" or "txn".
#'
#' @return A named list of numeric vectors, one per location plus the
#'   percentage helper.
#'
#' @throws Stops with class "vas_wallet_category_unplaced" when a category in
#'   the wallet total belongs to no channel question, and with class
#'   "vas_wallet_location_does_not_reconcile" when the six do not add up.
wallet_location_columns <- function(data, category_map, measure = "spend") {
  spec <- wallet_measure(measure)
  in_total <- unique(category_map$category[
    category_map$spend_class %in% VAS_WALLET_CLASSES])
  placed <- unique(unlist(VAS_WALLET_OCCASION, use.names = FALSE))
  unplaced <- setdiff(in_total, placed)
  if (length(unplaced)) {
    stop(structure(class = c("vas_wallet_category_unplaced", "error", "condition"), list(
      message = sprintf(paste0(
        "%d categor(y/ies) in the wallet total belong to no channel question: %s\n\n",
        "Their month could not be placed anywhere, so the six location columns ",
        "would not add\nup to %s. Add the category to VAS_WALLET_OCCASION in ",
        "vas_wallet_location.R, under\nthe channel question its buyers answer."),
        length(unplaced), paste(unplaced, collapse = ", "), spec$total),
      call = NULL)))
  }

  n <- nrow(data)
  out <- lapply(VAS_LOCATIONS$key, function(k) rep(0, n))
  names(out) <- VAS_LOCATIONS$key

  for (question in names(VAS_WALLET_OCCASION)) {
    categories <- intersect(VAS_WALLET_OCCASION[[question]], in_total)
    if (!length(categories)) next
    value <- Reduce(`+`, lapply(categories, function(c) {
      wallet_category_value(data, c, spec$suffix)
    }))
    if (all(value == 0)) next
    where <- vas_location_of(if (question %in% names(data)) data[[question]]
                             else rep(NA_character_, n))
    for (k in VAS_LOCATIONS$key) {
      out[[k]] <- out[[k]] + ifelse(where == k, value, 0)
    }
  }

  # A percentage column is that location's share of the respondent's OWN total.
  # Someone with nothing in their wallet has no split to report, so they are NA
  # and out of the base rather than six zeros.
  if (isTRUE(spec$percent) && spec$total %in% names(data)) {
    total <- suppressWarnings(as.numeric(data[[spec$total]]))
    total[is.na(total)] <- 0
    has_wallet <- total > 0
    for (k in VAS_LOCATIONS$key) {
      out[[k]] <- ifelse(has_wallet, 100 * out[[k]] / ifelse(has_wallet, total, 1),
                         NA_real_)
    }
  }

  # The reconciliation. Checked against the engine's own published total, not
  # against a second sum of the same numbers, so a fault in either shows. A
  # percentage split is checked against 100 instead, on whoever has a wallet.
  if (isTRUE(spec$percent)) {
    total <- suppressWarnings(as.numeric(data[[spec$total]]))
    total[is.na(total)] <- 0
    live <- which(total > 0)
    split_total <- Reduce(`+`, out)
    off <- live[abs(split_total[live] - 100) > 0.005]
    if (length(off)) {
      who <- if ("ResponseID" %in% names(data)) {
        paste(utils::head(data$ResponseID[off], 6), collapse = ", ")
      } else {
        paste(utils::head(off, 6), collapse = ", ")
      }
      stop(structure(class = c("vas_wallet_location_does_not_reconcile", "error", "condition"), list(
        message = sprintf(paste0(
          "The six %s location shares do not add up to 100%% for %d ",
          "respondent(s).\n  respondent(s): %s\n  biggest gap:   %.4f\n\n",
          "A split that does not reconcile must not be reported."),
          measure, length(off), who,
          max(abs(split_total[live] - 100))), call = NULL)))
    }
  } else if (spec$total %in% names(data)) {
    total <- suppressWarnings(as.numeric(data[[spec$total]]))
    total[is.na(total)] <- 0
    split_total <- Reduce(`+`, out)
    off <- which(abs(split_total - total) > 0.005)
    if (length(off)) {
      who <- if ("ResponseID" %in% names(data)) {
        paste(utils::head(data$ResponseID[off], 6), collapse = ", ")
      } else {
        paste(utils::head(off, 6), collapse = ", ")
      }
      stop(structure(class = c("vas_wallet_location_does_not_reconcile", "error", "condition"), list(
        message = sprintf(paste0(
          "The six %s location columns do not add up to %s for %d respondent(s).\n",
          "  respondent(s): %s\n",
          "  biggest gap:   %.4f\n\n",
          "A split that does not reconcile to the published total must not be ",
          "reported. Check\nVAS_WALLET_OCCASION against the category map's ",
          "spend classes."),
          measure, spec$total, length(off), who,
          max(abs(split_total - total))), call = NULL)))
    }
  }

  return(stats::setNames(out, vapply(names(out), wallet_location_column,
                                     character(1), measure = measure)))
}

#' The Questions and Options rows for one measure's location table
#'
#' One Allocation question with one option per location, not six numeric
#' questions - see the file header for what that changed.
#'
#' @param measure "spend" or "txn".
#'
#' @return A list of \code{questions} and \code{options} data frames, plus
#'   \code{after} - the question the block belongs behind.
wallet_location_structure_rows <- function(measure = "spend") {
  spec <- wallet_measure(measure)
  questions <- data.frame(
    QuestionCode = spec$code,
    QuestionText = spec$text,
    Variable_Type = "Allocation",
    Columns = nrow(VAS_LOCATIONS),
    after = spec$total, stringsAsFactors = FALSE)
  options <- data.frame(
    QuestionCode = spec$code,
    OptionText = VAS_LOCATIONS$label,
    DisplayText = VAS_LOCATIONS$label,
    DisplayOrder = seq_len(nrow(VAS_LOCATIONS)),
    after = spec$total, stringsAsFactors = FALSE)
  return(list(questions = questions, options = options))
}

#' Add both measures' location columns to a structure and its data
#'
#' @param data The assembled data frame.
#' @param structure A list of \code{questions} and \code{options}.
#' @param category_map The category map.
#'
#' @return A list of \code{data}, \code{questions} and \code{options}.
add_wallet_location <- function(data, structure, category_map) {
  questions <- structure$questions
  options <- structure$options
  for (measure in names(VAS_WALLET_MEASURES)) {
    spec <- wallet_measure(measure)
    if (!spec$total %in% names(data)) next

    rows <- wallet_location_structure_rows(measure)
    already <- intersect(rows$questions$QuestionCode, questions$QuestionCode)
    if (length(already)) {
      stop(structure(class = c("vas_wallet_location_already_added", "error", "condition"), list(
        message = sprintf(paste0(
          "The wallet-location question(s) %s are already in this structure.\n",
          "add_wallet_location() builds them from the asked channels and must run once."),
          paste(utils::head(already, 4), collapse = ", ")), call = NULL)))
    }

    columns <- wallet_location_columns(data, category_map, measure)
    for (name in names(columns)) {
      data[[name]] <- columns[[name]]
    }

    # splice_after() reconciles the two frames' columns itself; the wallet
    # rows join a structure that has already been widened by the derived rows.
    questions <- splice_after(questions, rows$questions,
                              function(base, a) match(a, base$QuestionCode))
    options <- splice_after(options, rows$options, function(base, a) {
      hits <- which(base$QuestionCode == a)
      if (length(hits)) max(hits) else nrow(base)
    })

    # A percentage measure is already a share, so it is averaged rather than
    # divided by its own total - which would divide 100 by 100.
    share <- vapply(VAS_LOCATIONS$key, function(k) {
      v <- columns[[wallet_location_column(k, measure)]]
      if (isTRUE(spec$percent)) mean(v, na.rm = TRUE) else sum(v)
    }, numeric(1))
    if (!isTRUE(spec$percent)) share <- 100 * share / sum(share)
    cat(sprintf("Wallet location (%s): %d column(s); %s\n", measure,
                length(columns),
                paste(sprintf("%s %.0f%%", VAS_LOCATIONS$label, share),
                      collapse = ", ")))
  }
  return(list(data = data, questions = questions, options = options))
}
