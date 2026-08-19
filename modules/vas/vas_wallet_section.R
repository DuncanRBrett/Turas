# vas_wallet_section.R
# ------------------------------------------------------------------------------
# What share of a person's wallet goes on each part of the report.
#
# Duncan, 19 Aug 2026: "can we have a question that shows % of wallet by section
# but split domestic send and receive."
#
#   WalletSectionPct  one Allocation question, thirteen rows, each the share of
#                     that respondent's own wallet
#
# The thirteen are the report's own sections, so the table and the report agree
# about what a section is:
#
#   Prepaid electricity, Prepaid airtime, Prepaid data, Digital vouchers,
#   Bills, Domestic money sent, International money sent, Lotto, Betting,
#   Flights, Long distance bus, Short distance bus, Events
#
# They add up to TotalValueTransacted for every respondent, and the build
# REFUSES if they ever do not.
#
# MONEY RECEIVED IS NOT ONE OF THEM, and that is a decision, not an oversight.
# Duncan asked for domestic send and receive split, and they are - as two report
# sections, and as two lines everywhere else. But received money is money IN.
# It is not spend, it is not in the wallet, and the 13 Aug rules say it is never
# added to a spend total. A row for it here would either stop the shares summing
# to 100 or quietly change what the denominator means. Duncan's call, 19 Aug:
# keep it out, report it on its own. On the live data it is R358,805 a month
# against R348,017 sent, so it is a big number and it deserves its own reading
# rather than a share of somebody else's denominator.
#
# WHAT THE NUMBER MEANS. Each respondent's own split, averaged. That is NOT the
# section's share of all the rand in the study: bills take 36% of every rand
# but only 27% of the average person's wallet, because the people who pay big
# bills are not the average person. Both are true; the wording says which.
# ------------------------------------------------------------------------------

VAS_WALLET_SECTION_CODE <- "WalletSectionPct"

# The sections, in the order they read. "categories" names them outright;
# "prefix" takes every category in the map whose code starts with it, so the
# fourteen bill types and the six event types cannot fall out of step with the
# study.
VAS_WALLET_SECTIONS <- list(
  list(label = "Prepaid electricity",      categories = "PrepaidElectricity"),
  list(label = "Prepaid airtime",          categories = "Airtime"),
  list(label = "Prepaid data",             categories = "Data"),
  list(label = "Digital vouchers",         categories = "DigitalVouchers"),
  list(label = "Bills",                    prefix = "Bill"),
  list(label = "Domestic money sent",      categories = "DomSend"),
  list(label = "International money sent", categories = "IntlSend"),
  list(label = "Lotto",                    categories = "Lotto"),
  list(label = "Betting",                  categories = "Betting"),
  list(label = "Flights",                  categories = c("FlightDomestic",
                                                          "FlightInternational")),
  list(label = "Long distance bus",        categories = "LongDistanceBus"),
  list(label = "Short distance bus",       categories = "ShortDistanceBus"),
  list(label = "Events",                   prefix = "Event")
)

#' Which categories each section holds, resolved against the study
#'
#' @param category_map The category map.
#'
#' @return A list of character vectors, named by section label, holding only
#'   categories that are in the wallet total.
#'
#' @throws Stops with class "vas_wallet_section_unplaced" when a category in
#'   the wallet total belongs to no section.
wallet_section_members <- function(category_map) {
  in_total <- unique(category_map$category[
    category_map$spend_class %in% VAS_WALLET_CLASSES])
  out <- lapply(VAS_WALLET_SECTIONS, function(section) {
    if (!is.null(section$prefix)) {
      return(in_total[startsWith(in_total, section$prefix)])
    }
    intersect(section$categories, in_total)
  })
  names(out) <- vapply(VAS_WALLET_SECTIONS, function(s) s$label, character(1))

  unplaced <- setdiff(in_total, unlist(out, use.names = FALSE))
  if (length(unplaced)) {
    stop(structure(class = c("vas_wallet_section_unplaced", "error", "condition"), list(
      message = sprintf(paste0(
        "%d categor(y/ies) in the wallet total belong to no section: %s\n\n",
        "The section shares would not add up to 100%%. Add the category to ",
        "VAS_WALLET_SECTIONS\nin vas_wallet_section.R, under the section a ",
        "reader would look for it in."),
        length(unplaced), paste(unplaced, collapse = ", ")), call = NULL)))
  }
  return(out)
}

#' Each respondent's wallet, split across the sections as percentages
#'
#' @param data The assembled data frame.
#' @param category_map The category map.
#'
#' @return A named list of numeric vectors, one per section.
#'
#' @throws Stops with class "vas_wallet_section_does_not_reconcile" when the
#'   sections do not add up.
wallet_section_columns <- function(data, category_map) {
  members <- wallet_section_members(category_map)
  n <- nrow(data)
  rand <- lapply(members, function(categories) {
    if (!length(categories)) return(rep(0, n))
    Reduce(`+`, lapply(categories, function(c) {
      wallet_category_value(data, c, "MonthlySpend")
    }))
  })

  total <- if (VAS_WALLET_TOTAL_COLUMN %in% names(data)) {
    v <- suppressWarnings(as.numeric(data[[VAS_WALLET_TOTAL_COLUMN]]))
    v[is.na(v)] <- 0
    v
  } else {
    Reduce(`+`, rand)
  }

  # In rand first, against the published total: that is the check worth having,
  # because a section quietly missing a category would still make percentages
  # that sum to 100.
  off <- which(abs(Reduce(`+`, rand) - total) > 0.005)
  if (length(off)) {
    who <- if ("ResponseID" %in% names(data)) {
      paste(utils::head(data$ResponseID[off], 6), collapse = ", ")
    } else {
      paste(utils::head(off, 6), collapse = ", ")
    }
    stop(structure(class = c("vas_wallet_section_does_not_reconcile", "error", "condition"), list(
      message = sprintf(paste0(
        "The section columns do not add up to %s for %d respondent(s).\n",
        "  respondent(s): %s\n  biggest gap:   %.2f\n\n",
        "A split that does not reconcile to the published total must not be ",
        "reported."),
        VAS_WALLET_TOTAL_COLUMN, length(off), who,
        max(abs(Reduce(`+`, rand) - total))), call = NULL)))
  }

  has_wallet <- total > 0
  out <- list()
  for (i in seq_along(rand)) {
    out[[sprintf("%s_%d", VAS_WALLET_SECTION_CODE, i)]] <-
      ifelse(has_wallet, 100 * rand[[i]] / ifelse(has_wallet, total, 1), NA_real_)
  }
  return(out)
}

#' The Questions and Options rows for the section table
#'
#' @return A list of \code{questions} and \code{options} data frames, plus
#'   \code{after} - the question the block belongs behind.
wallet_section_structure_rows <- function() {
  labels <- vapply(VAS_WALLET_SECTIONS, function(s) s$label, character(1))
  questions <- data.frame(
    QuestionCode = VAS_WALLET_SECTION_CODE,
    QuestionText = paste0("Share of the VAS wallet by section - each person's ",
                          "own split, averaged (%)"),
    Variable_Type = "Allocation",
    Columns = length(labels),
    after = VAS_WALLET_TOTAL_COLUMN, stringsAsFactors = FALSE)
  options <- data.frame(
    QuestionCode = VAS_WALLET_SECTION_CODE,
    OptionText = labels, DisplayText = labels,
    DisplayOrder = seq_along(labels),
    after = VAS_WALLET_TOTAL_COLUMN, stringsAsFactors = FALSE)
  return(list(questions = questions, options = options))
}

#' Add the section table to a structure and its data
#'
#' @param data The assembled data frame.
#' @param structure A list of \code{questions} and \code{options}.
#' @param category_map The category map.
#'
#' @return A list of \code{data}, \code{questions} and \code{options}.
add_wallet_section <- function(data, structure, category_map) {
  if (!VAS_WALLET_TOTAL_COLUMN %in% names(data)) {
    return(list(data = data, questions = structure$questions,
                options = structure$options))
  }
  if (VAS_WALLET_SECTION_CODE %in% structure$questions$QuestionCode) {
    stop(structure(class = c("vas_wallet_section_already_added", "error", "condition"), list(
      message = sprintf(paste0(
        "The section question %s is already in this structure.\n",
        "add_wallet_section() builds it from the categories and must run once."),
        VAS_WALLET_SECTION_CODE), call = NULL)))
  }

  columns <- wallet_section_columns(data, category_map)
  for (name in names(columns)) {
    data[[name]] <- columns[[name]]
  }

  rows <- wallet_section_structure_rows()
  questions <- splice_after(structure$questions, rows$questions,
                            function(base, a) match(a, base$QuestionCode))
  options <- splice_after(structure$options, rows$options, function(base, a) {
    hits <- which(base$QuestionCode == a)
    if (length(hits)) max(hits) else nrow(base)
  })

  share <- vapply(columns, function(v) mean(v, na.rm = TRUE), numeric(1))
  labels <- vapply(VAS_WALLET_SECTIONS, function(s) s$label, character(1))
  top <- order(share, decreasing = TRUE)[1:3]
  cat(sprintf("Wallet section: %d column(s); biggest %s\n", length(columns),
              paste(sprintf("%s %.0f%%", labels[top], share[top]), collapse = ", ")))
  return(list(data = data, questions = questions, options = options))
}
