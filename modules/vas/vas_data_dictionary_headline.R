# vas_data_dictionary_headline.R
# ------------------------------------------------------------------------------
# Documentation for the respondent-level columns - the identifiers, the income
# variables, the two headline totals, value received, share of wallet and the
# completeness flags - plus the assembler that puts the whole dictionary
# together.
#
# The category lists inside each total are read from the map's spend_class
# column, so they stay correct if a category is reclassified.
# ------------------------------------------------------------------------------

# How many terms of a summed formula to put on one line before wrapping.
VAS_FORMULA_TERMS_PER_LINE <- 3L

#' Join summed terms across several lines, so a long total stays readable
#'
#' @param terms A character vector of column names.
#'
#' @return A single character value, "+"-joined and wrapped.
join_summed_terms <- function(terms) {
  groups <- split(terms, ceiling(seq_along(terms) / VAS_FORMULA_TERMS_PER_LINE))
  lines <- vapply(groups, function(g) paste(g, collapse = " + "), character(1))
  return(paste(lines, collapse = "\n  + "))
}

#' List the categories rolling into a set of spend classes
#'
#' @param category_map The category map data frame.
#' @param classes A character vector of spend classes.
#'
#' @return A single character value: the contributing Total column names.
categories_in_classes <- function(category_map, classes) {
  categories <- unique(category_map$category[category_map$spend_class %in% classes])
  return(join_summed_terms(sprintf("%s_Total_MonthlySpend", categories)))
}

#' Render the income band lookup as text
#'
#' @param config The VAS_CONFIG list.
#' @param which_bound "midpoint" or "upper".
#'
#' @return A single multi-line character value.
describe_income_lookup <- function(config, which_bound) {
  bands <- config$income_bands
  values <- bands[[which_bound]]
  lines <- sprintf('"%s" -> %s', bands$label,
                   ifelse(is.na(values), "missing (no share of wallet)",
                          format(values, big.mark = ",", trim = TRUE)))
  return(paste(c("Lookup on the Income question:", lines), collapse = "\n"))
}

#' Document the identifier and income columns
#'
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame of dictionary rows.
dictionary_identity_rows <- function(config) {
  return(rbind(
    dictionary_row("ResponseID", "Identity", NA, NA, NA, "id",
                   "Alchemer's response id.",
                   'Taken as collected: the "Response ID" column in the export, or the response id from the API.',
                   "Response ID", "Never missing."),
    dictionary_row("ResponseStatus", "Identity", NA, NA, NA, "text",
                   "Whether Alchemer recorded the interview as Complete or Partial.",
                   "Taken as collected.", "Status",
                   "A Partial reached fewer categories, and every category it never reached counts as a real zero. Use CategoriesAsked before comparing Partials with Completes."),
    dictionary_row("IncomeBand", "Income", NA, NA, NA, "text",
                   "The banded monthly household income answer, verbatim.",
                   "Taken as collected.", "Income",
                   "Missing when the question was not answered."),
    dictionary_row("IncomeMidpoint", "Income", NA, NA, NA, "rand per month",
                   "The band's midpoint, for share of wallet.",
                   describe_income_lookup(config, "midpoint"), "Income",
                   'Missing for "Decline to answer" and for a blank. NOTE: the bottom band\'s midpoint is set to its own ceiling, so share of wallet is understated for the lowest earners.'),
    dictionary_row("IncomeUpper", "Income", NA, NA, NA, "rand per month",
                   "The band's upper boundary, the alternative share-of-wallet base.",
                   describe_income_lookup(config, "upper"), "Income",
                   'Missing for "Decline to answer" and for a blank. The open-ended top band has no upper bound, so it carries the same value as its midpoint.')
  ))
}

#' Document the headline totals and value received
#'
#' @param category_map The category map data frame.
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame of dictionary rows.
dictionary_total_rows <- function(category_map, config) {
  all_totals <- join_summed_terms(sprintf("%s_Total_TxnPerMonth",
                                          unique(category_map$category)))
  return(rbind(
    dictionary_row("TotalTxnPerMonth", "Headline", NA, "Total", "TxnPerMonth",
                   "transactions per month",
                   "Every VAS transaction the respondent makes in a month, across all categories.",
                   all_totals,
                   "all category Total transaction columns",
                   "Money received is COUNTED here, because a receipt is still a transaction. It is not counted in either spend total."),
    dictionary_row("TotalValueTransacted", "Headline", NA, "Total", "MonthlySpend",
                   "rand per month",
                   sprintf("Everything at face value: what share of income flows through these rails. Spend classes %s.",
                           paste(config$total_value_transacted, collapse = " + ")),
                   categories_in_classes(category_map, config$total_value_transacted),
                   "all category Total spend columns in those classes",
                   "Built from what is present, so a respondent with one unreadable amount still gets a total. Incomplete says whose total is understated."),
    dictionary_row("TotalConsumptionSpend", "Headline", NA, "Total", "MonthlySpend",
                   "rand per month",
                   sprintf("Spend on the services themselves, excluding transfers and bill obligations. Spend class %s only.",
                           paste(config$total_consumption_spend, collapse = " + ")),
                   categories_in_classes(category_map, config$total_consumption_spend),
                   "all category Total spend columns in that class",
                   "Built from what is present. Typically an order of magnitude smaller than TotalValueTransacted."),
    dictionary_row("TotalBillSpend", "Headline", NA, "Total", "MonthlySpend",
                   "rand per month",
                   sprintf("Bill payments only. Spend class %s. TotalValueTransacted = TotalConsumptionSpend + TotalBillSpend + TotalTransferSent.",
                           paste(config$total_bill_spend, collapse = " + ")),
                   categories_in_classes(category_map, config$total_bill_spend),
                   "all category Total spend columns in that class",
                   "Built from what is present, like every total."),
    dictionary_row("TotalTransferSent", "Headline", NA, "Total", "MonthlySpend",
                   "rand per month",
                   sprintf("Money sent to other people, at face value. Spend class %s.",
                           paste(config$total_transfer_sent, collapse = " + ")),
                   categories_in_classes(category_map, config$total_transfer_sent),
                   "all category Total spend columns in that class",
                   "Built from what is present, like every total."),
    dictionary_row("ValueReceived", "Headline", NA, "Total", "MonthlySpend",
                   "rand per month",
                   "Money coming IN. Reported on its own and never added to a spend total.",
                   categories_in_classes(category_map, config$reported_separately),
                   "all category Total spend columns in the received class",
                   "0 when the respondent receives nothing. The transactions still count in TotalTxnPerMonth.")
  ))
}

#' Document the composite scores
#'
#' @param category_map The category map data frame.
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame of dictionary rows.
dictionary_composite_rows <- function(category_map, config) {
  split_categories <- unique(category_map$category[category_map$base == "Own"])
  oth_terms <- join_summed_terms(sprintf("%s_Oth_MonthlySpend", split_categories))
  oth_txn_terms <- join_summed_terms(sprintf("%s_Oth_TxnPerMonth", split_categories))
  split_note <- sprintf(
    "Only the %d categories where the survey splits self from someone-else are covered; the single-question categories cannot be attributed to either side and are excluded.",
    length(split_categories))
  return(rbind(
    dictionary_row("TotalTxnTransacted", "Composite", NA, "Total", "TxnPerMonth",
                   "transactions per month",
                   sprintf("Transactions per month over the spend classes that make up TotalValueTransacted (%s) - the denominator of AvgSpendPerTxn. Excludes money received.",
                           paste(config$total_value_transacted, collapse = " + ")),
                   join_summed_terms(sprintf("%s_Total_TxnPerMonth",
                                             unique(category_map$category[category_map$spend_class %in% config$total_value_transacted]))),
                   "all category Total transaction columns in those classes",
                   "Built from what is present, like every total."),
    dictionary_row("AvgSpendPerTxn", "Composite", NA, "Total", "SpendPerTxn",
                   "rand per transaction",
                   "The respondent's overall ticket size across everything they pay for.",
                   "TotalValueTransacted / TotalTxnTransacted",
                   "TotalValueTransacted, TotalTxnTransacted",
                   "Missing when there are no transactions, or when either term is missing."),
    dictionary_row("TotalSpendForOthers", "Composite", NA, "Oth", "MonthlySpend",
                   "rand per month",
                   paste("Monthly spend on behalf of someone else.", split_note),
                   oth_terms, "all category Oth spend columns",
                   "0 when the respondent buys nothing for others; missing when every Oth cell is missing."),
    dictionary_row("TotalTxnForOthers", "Composite", NA, "Oth", "TxnPerMonth",
                   "transactions per month",
                   paste("Transactions per month on behalf of someone else.", split_note),
                   oth_txn_terms, "all category Oth transaction columns",
                   "0 when the respondent buys nothing for others; missing when every Oth cell is missing."),
    dictionary_row("ShareForOthers", "Composite", NA, NA, NA,
                   "proportion of split-category spend",
                   paste("What share of the respondent's spend goes on other people.", split_note),
                   "TotalSpendForOthers / (own-side spend + TotalSpendForOthers), summed over the split categories",
                   "all category Own and Oth spend columns",
                   "Missing when the split-category spend is zero or missing."),
    dictionary_row("BuysForOthers", "Composite", NA, NA, NA, "TRUE/FALSE",
                   "Whether the respondent transacts on behalf of anyone else at all.",
                   "TotalTxnForOthers > 0",
                   "TotalTxnForOthers",
                   "Missing only when every Oth cell is missing."),
    dictionary_row("CategoriesPurchased", "Composite", NA, NA, NA, "count",
                   "How many of the categories this respondent purchases - the row-count of the Purchased flags.",
                   "Count of the per-category Purchased columns that are TRUE.",
                   "every category's Purchased flag",
                   "Never missing. Routed-past categories count as not purchased.")
  ))
}

#' Document the four share-of-wallet columns
#'
#' @return A data frame of dictionary rows.
dictionary_share_rows <- function() {
  caveat <- "Missing when no income band was given. The income question asks about the HOUSEHOLD while several spend questions are personal, so this is personal spend over household income."
  # the stem is stated rather than derived from the total's name, so this cannot
  # drift from build_headline_columns() in vas_derive.R
  build <- function(stem, total, income_base) {
    dictionary_row(sprintf("ShareOfWallet_%s_%s", stem, income_base),
                   "Share of wallet", NA, NA, NA, "proportion of income",
                   sprintf("%s as a share of income, on the band %s.", total, tolower(income_base)),
                   sprintf("%s / Income%s", total, income_base),
                   sprintf("%s, Income%s", total, income_base),
                   caveat)
  }
  return(rbind(
    build("Transacted", "TotalValueTransacted", "Midpoint"),
    build("Transacted", "TotalValueTransacted", "Upper"),
    build("Consumption", "TotalConsumptionSpend", "Midpoint"),
    build("Consumption", "TotalConsumptionSpend", "Upper")
  ))
}

#' Document the outlier flags
#'
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame of dictionary rows.
dictionary_outlier_rows <- function(config) {
  describe_ceilings <- function(table, unit) {
    paste(sprintf("%s: over %s %s", names(table),
                  format(unlist(table), big.mark = ",", trim = TRUE), unit),
          collapse = "\n")
  }
  ceilings <- paste("A collected cell is flagged when it exceeds its spend class's ceiling.",
                    "Transactions per month:", describe_ceilings(config$outlier_txn_per_month, "per month"),
                    "Monthly spend:", describe_ceilings(config$outlier_monthly_spend, "rand"),
                    sep = "\n")
  return(rbind(
    dictionary_row("OutlierCells", "Outliers", NA, NA, NA, "count",
                   "How many of this respondent's collected cells carry an implausibly large figure.",
                   ceilings, "every collected category cell",
                   "Never missing. A flag NEVER changes a number - review the Audit sheet rows marked Outlier and decide whether to exclude the respondent in reporting."),
    dictionary_row("OutlierFlag", "Outliers", NA, NA, NA, "TRUE/FALSE",
                   "Whether any of this respondent's answers were flagged as implausible.",
                   "OutlierCells > 0", "OutlierCells",
                   "Never missing. The respondent's numbers are UNCHANGED; the flag lets reporting exclude them from means.")
  ))
}

#' Document the per-category purchased flags
#'
#' @param category_map The category map data frame.
#'
#' @return A data frame of dictionary rows.
dictionary_purchased_rows <- function(category_map) {
  rows <- lapply(unique(category_map$category), function(category) {
    label <- category_map$label[category_map$category == category][1]
    dictionary_row(paste0(category, "_Purchased"), "Purchased", category, "Total", NA,
                   "TRUE/FALSE",
                   sprintf("Buy %s at all in last 12 months?", label),
                   sprintf("%s_Total_TxnPerMonth > 0, OR the status says they buy but a figure is missing (freq_missing / amount_missing / partial).",
                           category),
                   sprintf("the %s frequency and amount questions", label),
                   "Never missing. Routed past, or a zero count, is FALSE - genuinely not purchased.")
  })
  return(do.call(rbind, rows))
}

#' Document the completeness flags
#'
#' @return A data frame of dictionary rows.
dictionary_completeness_rows <- function() {
  return(rbind(
    dictionary_row("CategoriesAsked", "Completeness", NA, NA, NA, "count",
                   "How many of the collected category cells this respondent actually reached.",
                   "Count of the collected Own / Oth / Total cells whose status is not not_asked.\nThe derived Totals are excluded, so nothing is double-counted.",
                   "all category statuses",
                   "Never missing. A low count on a Partial means most of that respondent's zeros are simply unanswered."),
    dictionary_row("CategoriesIncomplete", "Completeness", NA, NA, NA, "count",
                   "How many cells the respondent buys but could not be costed.",
                   'Count of cells with status "freq_missing" or "amount_missing".',
                   "all category statuses",
                   "Never missing. Zero is the normal case."),
    dictionary_row("Incomplete", "Completeness", NA, NA, NA, "TRUE/FALSE",
                   "Whether this respondent's totals understate their real spend.",
                   "CategoriesIncomplete > 0",
                   "CategoriesIncomplete",
                   "Never missing. Exclude these respondents from share-of-wallet means if you want a clean base.")
  ))
}

#' Build the whole data dictionary
#'
#' @param category_map The category map data frame.
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame with one row per output column, in output column order.
build_data_dictionary <- function(category_map, config) {
  rows <- list(dictionary_identity_rows(config),
               dictionary_total_rows(category_map, config),
               dictionary_composite_rows(category_map, config),
               dictionary_share_rows(),
               dictionary_completeness_rows(),
               dictionary_outlier_rows(config),
               dictionary_purchased_rows(category_map))

  for (category in unique(category_map$category)) {
    category_rows <- category_map[category_map$category == category, ]
    for (base in c("Own", "Oth", "Total")) {
      map_row <- category_rows[category_rows$base == base, ]
      if (nrow(map_row)) {
        rows[[length(rows) + 1L]] <- dictionary_for_map_row(map_row, config)
      } else if (identical(base, "Total") && nrow(category_rows) > 1L) {
        rows[[length(rows) + 1L]] <-
          dictionary_for_derived_total(
            category, category_rows$label[1],
            asm = category_assumptions(category_rows[1, ]))
      }
    }
  }
  return(do.call(rbind, rows))
}
