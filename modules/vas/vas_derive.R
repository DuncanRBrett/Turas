# vas_derive.R
# ------------------------------------------------------------------------------
# Roll the per-category results up to one row per respondent.
#
#   Own + Oth      -> a true Total per category, for the 19 categories where the
#                     survey collects both sides
#   Total          -> taken as collected, for the 14 categories where the survey
#                     asks a single combined question
#   spend classes  -> TotalValueTransacted, TotalConsumptionSpend, ValueReceived
#   wallet         -> TotalWalletSpend (consumption + obligation; transfers out),
#                     its self side, and the gambling break-out
#   income band    -> midpoint and upper boundary, and share of wallet on each
#
# Money received is never added to a spend total. It is reported on its own.
# ------------------------------------------------------------------------------

# The banded household income question. Not a category, so it is not in the map.
VAS_INCOME_ALIAS <- "Income"

# Statuses that mean "this respondent buys the category but a figure is missing".
VAS_INCOMPLETE_STATUSES <- c("freq_missing", "amount_missing")

#' Sum across columns, keeping NA only where every value is missing
#'
#' A respondent routed past a category contributes a real zero, so totals are
#' built from what is present. A respondent with nothing present at all stays
#' missing rather than becoming a false zero.
#'
#' @param values A numeric matrix or data frame.
#'
#' @return A numeric vector, one element per row.
sum_available <- function(values) {
  matrix_values <- as.matrix(values)
  if (!ncol(matrix_values)) {
    return(rep(NA_real_, nrow(matrix_values)))
  }
  totals <- rowSums(matrix_values, na.rm = TRUE)
  totals[rowSums(!is.na(matrix_values)) == 0L] <- NA_real_
  return(totals)
}

#' Combine the Own and Oth sides of a category into its Total
#'
#' Spend per transaction is taken as total spend over total transactions, so it
#' stays a true weighted figure rather than the mean of the two sides.
#'
#' @param own A data frame from \code{derive_category_base()}.
#' @param oth A data frame from \code{derive_category_base()}.
#'
#' @return A data frame in the same shape, holding the combined figures.
combine_bases_to_total <- function(own, oth) {
  txn <- sum_available(cbind(own$txn_per_month, oth$txn_per_month))
  spend <- sum_available(cbind(own$monthly_spend, oth$monthly_spend))
  per_txn <- ifelse(is.na(txn) | txn == 0, NA_real_, spend / txn)
  status <- ifelse(own$status %in% VAS_INCOMPLETE_STATUSES |
                     oth$status %in% VAS_INCOMPLETE_STATUSES, "partial",
                   ifelse(own$status == "not_asked" & oth$status == "not_asked",
                          "not_asked", "ok"))
  return(data.frame(txn_per_month = txn, monthly_spend = spend,
                    spend_per_txn = per_txn,
                    # NA throughout for a split category: only the count-based
                    # travel ones carry legs, and those are collected as a Total
                    trips_per_year = sum_available(cbind(own$trips_per_year,
                                                         oth$trips_per_year)),
                    status = status,
                    amount_unknown = own$status %in% "amount_missing" |
                      oth$status %in% "amount_missing",
                    # a total built on a flagged side is itself suspect
                    outlier = own$outlier | oth$outlier,
                    stringsAsFactors = FALSE))
}

#' Run every row of the category map
#'
#' @param source A vas_source object.
#' @param category_map The category map data frame.
#' @param config The VAS_CONFIG list.
#'
#' @return A named list of data frames, keyed "<category>|<base>", with a
#'   derived "<category>|Total" added for every category that has both sides.
derive_all_categories <- function(source, category_map, config) {
  derived <- list()
  for (i in seq_len(nrow(category_map))) {
    row <- category_map[i, ]
    derived[[paste0(row$category, "|", row$base)]] <-
      derive_category_base(source, row, config)
  }
  for (category in unique(category_map$category)) {
    own_key <- paste0(category, "|Own")
    oth_key <- paste0(category, "|Oth")
    if (own_key %in% names(derived) && oth_key %in% names(derived)) {
      derived[[paste0(category, "|Total")]] <-
        combine_bases_to_total(derived[[own_key]], derived[[oth_key]])
    }
  }
  return(derived)
}

#' Look the income band up in the config table
#'
#' @param source A vas_source object.
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame of \code{IncomeBand}, \code{IncomeMidpoint} and
#'   \code{IncomeUpper}.
derive_income <- function(source, config) {
  band <- source_scalar(source, VAS_INCOME_ALIAS)
  position <- match(band, config$income_bands$label)
  return(data.frame(
    IncomeBand = band,
    IncomeMidpoint = config$income_bands$midpoint[position],
    IncomeUpper = config$income_bands$upper[position],
    stringsAsFactors = FALSE
  ))
}

#' Total the Total-base monthly spend across a set of spend classes
#'
#' @param derived The list from \code{derive_all_categories()}.
#' @param category_map The category map data frame.
#' @param classes A character vector of spend classes to include.
#'
#' @return A numeric vector, one element per respondent.
total_spend_for_classes <- function(derived, category_map, classes) {
  return(total_measure_for_classes(derived, category_map, classes, "monthly_spend"))
}

#' Total one measure's Total-base column across a set of spend classes
#'
#' @param derived The list from \code{derive_all_categories()}.
#' @param category_map The category map data frame.
#' @param classes A character vector of spend classes to include.
#' @param measure "monthly_spend" or "txn_per_month".
#'
#' @return A numeric vector, one element per respondent.
total_measure_for_classes <- function(derived, category_map, classes, measure) {
  categories <- unique(category_map$category[category_map$spend_class %in% classes])
  keys <- paste0(categories, "|Total")
  keys <- keys[keys %in% names(derived)]
  if (!length(keys)) {
    return(rep(NA_real_, nrow(derived[[1]])))
  }
  return(sum_available(do.call(cbind, lapply(keys, function(k) derived[[k]][[measure]]))))
}

#' Total one measure's Total-base column across a set of named categories
#'
#' The class helpers slice by spend class; this slices by category name, for
#' the lines (gambling) that cut across a class rather than covering it.
#'
#' @param derived The list from \code{derive_all_categories()}.
#' @param categories A character vector of category names.
#' @param measure "monthly_spend" or "txn_per_month".
#'
#' @return A numeric vector, one element per respondent.
total_measure_for_categories <- function(derived, categories, measure) {
  keys <- paste0(categories, "|Total")
  keys <- keys[keys %in% names(derived)]
  if (!length(keys)) {
    return(rep(NA_real_, nrow(derived[[1]])))
  }
  return(sum_available(do.call(cbind, lapply(keys, function(k) derived[[k]][[measure]]))))
}

#' Total one measure over the self side of a set of spend classes
#'
#' A split category contributes its Own side. A category collected as a single
#' combined question has no split, so its Total counts as self - the survey
#' cannot attribute it to anyone else, and the dictionary states the rule.
#'
#' @param derived The list from \code{derive_all_categories()}.
#' @param category_map The category map data frame.
#' @param classes A character vector of spend classes to include.
#' @param measure "monthly_spend" or "txn_per_month".
#'
#' @return A numeric vector, one element per respondent.
total_measure_for_self <- function(derived, category_map, classes, measure) {
  categories <- unique(category_map$category[category_map$spend_class %in% classes])
  own_keys <- paste0(categories, "|Own")
  own_keys <- own_keys[own_keys %in% names(derived)]
  split_categories <- sub("\\|Own$", "", own_keys)
  total_keys <- paste0(setdiff(categories, split_categories), "|Total")
  total_keys <- total_keys[total_keys %in% names(derived)]
  keys <- c(own_keys, total_keys)
  if (!length(keys)) {
    return(rep(NA_real_, nrow(derived[[1]])))
  }
  return(sum_available(do.call(cbind, lapply(keys, function(k) derived[[k]][[measure]]))))
}

#' Total one measure across every collected cell of one base
#'
#' Only the categories where the survey splits self from someone-else carry an
#' Own or an Oth side, so this sums the for-others (or for-self) picture over
#' exactly those categories.
#'
#' @param derived The list from \code{derive_all_categories()}.
#' @param base "Own" or "Oth".
#' @param measure "monthly_spend" or "txn_per_month".
#'
#' @return A numeric vector, one element per respondent.
total_measure_for_base <- function(derived, base, measure) {
  keys <- names(derived)[endsWith(names(derived), paste0("|", base))]
  if (!length(keys)) {
    return(rep(NA_real_, nrow(derived[[1]])))
  }
  return(sum_available(do.call(cbind, lapply(keys, function(k) derived[[k]][[measure]]))))
}

#' Decide, per respondent, whether a category is purchased at all
#'
#' Purchased means the respondent transacts in the category: their derived
#' transactions per month are above zero, or their status says they buy but a
#' figure is missing. Routed past ("not_asked") and a zero count are both
#' genuinely not purchased.
#'
#' @param frame A per-category data frame (the category's Total).
#'
#' @return A logical vector, one element per respondent, never NA.
category_purchased <- function(frame) {
  transacts <- !is.na(frame$txn_per_month) & frame$txn_per_month > 0
  buys_but_unmeasured <- frame$status %in% c(VAS_INCOMPLETE_STATUSES, "partial")
  return(transacts | buys_but_unmeasured)
}

#' Lay the per-category purchased flags out as one column per category
#'
#' @param derived The list from \code{derive_all_categories()}.
#' @param category_map The category map data frame.
#'
#' @return A data frame of one TRUE/FALSE column per category.
build_purchased_columns <- function(derived, category_map) {
  columns <- list()
  for (category in unique(category_map$category)) {
    key <- paste0(category, "|Total")
    if (!key %in% names(derived)) {
      # a category collected on one side only has no Total; use what was collected
      key <- paste0(category, "|", category_map$base[category_map$category == category][1])
    }
    columns[[paste0(category, "_Purchased")]] <- category_purchased(derived[[key]])
  }
  return(as.data.frame(columns, stringsAsFactors = FALSE, check.names = FALSE))
}

#' Count, per respondent, the category cells that are incomplete
#'
#' Counts the collected Own / Oth / Total cells - not the Totals this script
#' derives, which would double-count.
#'
#' @param derived The list from \code{derive_all_categories()}.
#' @param category_map The category map data frame.
#'
#' @return A data frame of \code{CategoriesAsked} and \code{CategoriesIncomplete}.
count_completeness <- function(derived, category_map) {
  keys <- paste0(category_map$category, "|", category_map$base)
  statuses <- do.call(cbind, lapply(keys, function(k) derived[[k]]$status))
  return(data.frame(
    CategoriesAsked = rowSums(statuses != "not_asked"),
    CategoriesIncomplete = rowSums(matrix(statuses %in% VAS_INCOMPLETE_STATUSES,
                                          nrow = nrow(statuses))),
    stringsAsFactors = FALSE
  ))
}

#' Count, per respondent, the collected cells flagged as outliers
#'
#' Counts the collected Own / Oth / Total cells only - the Totals this script
#' derives inherit their sides' flags and would double-count.
#'
#' @param derived The list from \code{derive_all_categories()}.
#' @param category_map The category map data frame.
#'
#' @return An integer vector, one element per respondent.
count_outlier_cells <- function(derived, category_map) {
  keys <- paste0(category_map$category, "|", category_map$base)
  flags <- do.call(cbind, lapply(keys, function(k) derived[[k]]$outlier))
  return(rowSums(matrix(flags, nrow = nrow(derived[[keys[1]]]))))
}

#' Does this category and base count travel legs?
#'
#' Only the count-based travel categories do: the survey asks them how many
#' flights or tickets they bought in the past 12 months and whether that number
#' is one-way or return.
#'
#' @param category_map The category map data frame.
#' @param category The category name.
#' @param base "Own", "Oth" or "Total".
#'
#' @return TRUE when the map row for this category and base has a count alias.
category_counts_legs <- function(category_map, category, base) {
  if (!"count_alias" %in% names(category_map)) {
    return(FALSE)
  }
  row <- category_map[category_map$category == category & category_map$base == base, ]
  return(nrow(row) == 1L && !is.na(row$count_alias))
}

#' Lay the per-category results out as one wide row per respondent
#'
#' @param derived The list from \code{derive_all_categories()}.
#' @param category_map The category map data frame.
#'
#' @return A data frame of three columns per category and base.
build_category_columns <- function(derived, category_map) {
  columns <- list()
  for (category in unique(category_map$category)) {
    for (base in c("Own", "Oth", "Total")) {
      key <- paste0(category, "|", base)
      if (!key %in% names(derived)) {
        next
      }
      stem <- paste0(category, "_", base, "_")
      frame <- derived[[key]]
      # A don't-know amount is not a zero. The Own side already blanks it, but
      # the Total is a SUM, and sum_available keeps NA only where every side is
      # missing - so an unknown own amount plus a genuine zero for others came
      # out as zero and published the respondent as spending nothing, dragging
      # every mean and median down. They stay a buyer and keep their
      # transactions; only the money leaves the amount statistics.
      # The internal frame is left alone: the wallet totals are deliberately
      # built from what IS present (see test-vas_derive.R "incomplete
      # respondents are counted and flagged").
      amount_unknown <- frame$amount_unknown
      spend <- frame$monthly_spend
      per_txn <- frame$spend_per_txn
      spend[amount_unknown] <- NA_real_
      per_txn[amount_unknown] <- NA_real_
      columns[[paste0(stem, "TxnPerMonth")]] <- frame$txn_per_month
      columns[[paste0(stem, "MonthlySpend")]] <- spend
      columns[[paste0(stem, "SpendPerTxn")]] <- per_txn
      # Legs a year exists only where the survey asked a 12-month count and a
      # one-way/return question - the travel categories. Emitting it everywhere
      # would publish a column of NA for every other category.
      if (category_counts_legs(category_map, category, base)) {
        columns[[paste0(stem, "TripsPerYear")]] <- frame$trips_per_year
      }
    }
  }
  return(as.data.frame(columns, stringsAsFactors = FALSE, check.names = FALSE))
}

#' Assemble the headline totals, the composites and share of wallet
#'
#' @param derived The list from \code{derive_all_categories()}.
#' @param category_map The category map data frame.
#' @param income A data frame from \code{derive_income()}.
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame of the headline columns.
build_headline_columns <- function(derived, category_map, income, config) {
  total_keys <- paste0(unique(category_map$category), "|Total")
  total_keys <- total_keys[total_keys %in% names(derived)]
  transacted <- total_spend_for_classes(derived, category_map, config$total_value_transacted)
  consumption <- total_spend_for_classes(derived, category_map, config$total_consumption_spend)
  txn_transacted <- total_measure_for_classes(derived, category_map,
                                              config$total_value_transacted, "txn_per_month")
  oth_spend <- total_measure_for_base(derived, "Oth", "monthly_spend")
  oth_txn <- total_measure_for_base(derived, "Oth", "txn_per_month")
  split_spend <- sum_available(cbind(total_measure_for_base(derived, "Own", "monthly_spend"),
                                     oth_spend))
  # The wallet excludes both transfer classes, so TotalSpendForOthers (whose
  # split categories all sit inside the wallet classes) is also the wallet's
  # for-others side; self is built directly rather than by subtraction so the
  # missing-data semantics stay sum_available's.
  wallet_spend <- total_spend_for_classes(derived, category_map, config$total_wallet_spend)
  wallet_txn <- total_measure_for_classes(derived, category_map,
                                          config$total_wallet_spend, "txn_per_month")
  return(data.frame(
    TotalTxnPerMonth = if (length(total_keys)) {
      sum_available(do.call(cbind, lapply(total_keys, function(k) derived[[k]]$txn_per_month)))
    } else {
      rep(NA_real_, nrow(income))
    },
    TotalValueTransacted = transacted,
    TotalConsumptionSpend = consumption,
    TotalBillSpend = total_spend_for_classes(derived, category_map, config$total_bill_spend),
    TotalTransferSent = total_spend_for_classes(derived, category_map, config$total_transfer_sent),
    ValueReceived = total_spend_for_classes(derived, category_map, config$reported_separately),
    TotalWalletSpend = wallet_spend,
    TotalWalletTxn = wallet_txn,
    TotalWalletSpendSelf = total_measure_for_self(derived, category_map,
                                                  config$total_wallet_spend, "monthly_spend"),
    TotalWalletTxnSelf = total_measure_for_self(derived, category_map,
                                                config$total_wallet_spend, "txn_per_month"),
    TotalGamblingSpend = total_measure_for_categories(derived, config$gambling_categories,
                                                      "monthly_spend"),
    TotalGamblingTxn = total_measure_for_categories(derived, config$gambling_categories,
                                                    "txn_per_month"),
    TotalTxnTransacted = txn_transacted,
    AvgSpendPerTxn = ifelse(is.na(txn_transacted) | txn_transacted == 0,
                            NA_real_, transacted / txn_transacted),
    TotalSpendForOthers = oth_spend,
    TotalTxnForOthers = oth_txn,
    ShareForOthers = ifelse(is.na(split_spend) | split_spend == 0,
                            NA_real_, oth_spend / split_spend),
    BuysForOthers = ifelse(is.na(oth_txn), NA, oth_txn > 0),
    ShareOfWallet_Transacted_Midpoint = transacted / income$IncomeMidpoint,
    ShareOfWallet_Transacted_Upper = transacted / income$IncomeUpper,
    ShareOfWallet_Consumption_Midpoint = consumption / income$IncomeMidpoint,
    ShareOfWallet_Consumption_Upper = consumption / income$IncomeUpper,
    stringsAsFactors = FALSE
  ))
}

#' Produce the derived-variable table for a whole survey
#'
#' @param source A vas_source object from \code{read_vas_api()} or
#'   \code{read_vas_export()}.
#' @param category_map The category map data frame.
#' @param config The VAS_CONFIG list.
#'
#' @return A list with \code{wide} (one row per respondent) and \code{audit}
#'   (one row per respondent, category and base, carrying the status).
#'
#' @examples
#' \dontrun{
#'   source("vas_derived_config.R")
#'   src <- read_vas_api(8912114)
#'   out <- derive_vas(src, read.csv("vas_category_map.csv", na.strings = ""), VAS_CONFIG)
#' }
derive_vas <- function(source, category_map, config) {
  validate_source_columns(source, category_map)
  derived <- derive_all_categories(source, category_map, config)
  income <- derive_income(source, config)
  completeness <- count_completeness(derived, category_map)
  purchased <- build_purchased_columns(derived, category_map)
  outlier_cells <- count_outlier_cells(derived, category_map)

  wide <- cbind(
    data.frame(ResponseID = source$response_id, ResponseStatus = source$status,
               stringsAsFactors = FALSE),
    income,
    build_headline_columns(derived, category_map, income, config),
    data.frame(CategoriesPurchased = rowSums(purchased),
               CategoriesAsked = completeness$CategoriesAsked,
               CategoriesIncomplete = completeness$CategoriesIncomplete,
               Incomplete = completeness$CategoriesIncomplete > 0L,
               OutlierCells = outlier_cells,
               OutlierFlag = outlier_cells > 0L,
               stringsAsFactors = FALSE),
    build_category_columns(derived, category_map),
    purchased
  )
  return(list(wide = wide, audit = build_audit_table(derived, source$response_id)))
}

#' Lay the per-category results out long, for checking
#'
#' @param derived The list from \code{derive_all_categories()}.
#' @param response_id The vector of response ids.
#'
#' @return A data frame with one row per respondent, category and base.
build_audit_table <- function(derived, response_id) {
  rows <- lapply(names(derived), function(key) {
    parts <- strsplit(key, "|", fixed = TRUE)[[1]]
    frame <- derived[[key]]
    data.frame(ResponseID = response_id, Category = parts[1], Base = parts[2],
               TxnPerMonth = frame$txn_per_month, MonthlySpend = frame$monthly_spend,
               SpendPerTxn = frame$spend_per_txn, Status = frame$status,
               # carried so the consistency check can tell a deliberately blank
               # published Total from a broken one
               AmountUnknown = frame$amount_unknown,
               Outlier = frame$outlier, stringsAsFactors = FALSE)
  })
  return(do.call(rbind, rows))
}
