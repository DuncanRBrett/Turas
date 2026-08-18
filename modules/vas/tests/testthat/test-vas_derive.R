# test-vas_derive.R
# Known-answer tests for the respondent-level roll-up: Own + Oth into Total,
# the two headline totals, value received, and share of wallet.

test_that("sum_available treats an all-missing row as missing, not zero", {
  values <- cbind(c(1, NA, 5), c(2, NA, NA))
  expect_equal(sum_available(values), c(3, NA, 5))
})

test_that("Own and Oth combine into a weighted Total", {
  own <- data.frame(txn_per_month = 4, monthly_spend = 200, spend_per_txn = 50,
                    trips_per_year = NA_real_, status = "ok", outlier = FALSE, stringsAsFactors = FALSE)
  oth <- data.frame(txn_per_month = 2, monthly_spend = 100, spend_per_txn = 50,
                    trips_per_year = NA_real_, status = "ok", outlier = FALSE, stringsAsFactors = FALSE)
  result <- combine_bases_to_total(own, oth)
  expect_equal(result$txn_per_month, 6)
  expect_equal(result$monthly_spend, 300)
  # a true weighted figure: 300 / 6, not the mean of the two sides
  expect_equal(result$spend_per_txn, 50)
})

test_that("the Total spend per transaction is weighted, not averaged", {
  # R300 over 3 own purchases and R100 over 1 other purchase is R100 a purchase,
  # not the mean of R100 and R100... so use unequal rates to prove the point
  own <- data.frame(txn_per_month = 3, monthly_spend = 300, spend_per_txn = 100,
                    trips_per_year = NA_real_, status = "ok", outlier = FALSE, stringsAsFactors = FALSE)
  oth <- data.frame(txn_per_month = 1, monthly_spend = 20, spend_per_txn = 20,
                    trips_per_year = NA_real_, status = "ok", outlier = FALSE, stringsAsFactors = FALSE)
  result <- combine_bases_to_total(own, oth)
  expect_equal(result$spend_per_txn, 320 / 4)  # 80, not (100 + 20) / 2 = 60
})

test_that("a Total with no transactions has no per-transaction figure", {
  zero <- data.frame(txn_per_month = 0, monthly_spend = 0, spend_per_txn = NA_real_,
                     trips_per_year = NA_real_, status = "not_asked", outlier = FALSE, stringsAsFactors = FALSE)
  result <- combine_bases_to_total(zero, zero)
  expect_equal(result$txn_per_month, 0)
  expect_true(is.na(result$spend_per_txn))
  expect_equal(result$status, "not_asked")
})

test_that("income bands map to their configured midpoint and upper boundary", {
  source <- fixture_source(Income = c("R8,000 to R21,999", "More than R75,000",
                                      "Decline to answer", NA_character_))
  result <- derive_income(source, VAS_CONFIG)
  expect_equal(result$IncomeMidpoint, c(15000, 100000, NA, NA))
  expect_equal(result$IncomeUpper, c(21999, 100000, NA, NA))
})

test_that("the headline totals separate consumption, transfer and receipt", {
  result <- derive_vas(fixture_totals_source(), fixture_totals_map(), VAS_CONFIG)$wide
  # respondent 1: airtime R50 + R30 = R80 consumption, R500 sent, R200 received
  expect_equal(result$TotalConsumptionSpend[1], 80)
  expect_equal(result$TotalValueTransacted[1], 580)
  expect_equal(result$ValueReceived[1], 200)
  # money received is never folded into either spend total
  expect_false(result$TotalValueTransacted[1] == 780)
})

test_that("transactions are counted across every category including receipts", {
  result <- derive_vas(fixture_totals_source(), fixture_totals_map(), VAS_CONFIG)$wide
  # airtime Total 2, domestic send 1, domestic receive 1
  expect_equal(result$TotalTxnPerMonth[1], 4)
})

test_that("share of wallet is produced on both income bases and both totals", {
  result <- derive_vas(fixture_totals_source(), fixture_totals_map(), VAS_CONFIG)$wide
  expect_equal(result$ShareOfWallet_Transacted_Midpoint[1], 580 / 15000)
  expect_equal(result$ShareOfWallet_Transacted_Upper[1], 580 / 21999)
  expect_equal(result$ShareOfWallet_Consumption_Midpoint[1], 80 / 15000)
  expect_equal(result$ShareOfWallet_Consumption_Upper[1], 80 / 21999)
})

test_that("a respondent declining to give income gets no share of wallet", {
  result <- derive_vas(fixture_totals_source(), fixture_totals_map(), VAS_CONFIG)$wide
  expect_true(is.na(result$ShareOfWallet_Transacted_Midpoint[2]))
  expect_true(is.na(result$ShareOfWallet_Transacted_Upper[2]))
})

test_that("a respondent who buys nothing totals zero rather than missing", {
  result <- derive_vas(fixture_totals_source(), fixture_totals_map(), VAS_CONFIG)$wide
  expect_equal(result$TotalValueTransacted[2], 0)
  expect_equal(result$TotalConsumptionSpend[2], 0)
  expect_equal(result$CategoriesAsked[2], 0)
  expect_false(result$Incomplete[2])
})

test_that("the wide table carries three measures per category and base", {
  result <- derive_vas(fixture_totals_source(), fixture_totals_map(), VAS_CONFIG)$wide
  for (column in c("Airtime_Own_TxnPerMonth", "Airtime_Own_MonthlySpend",
                   "Airtime_Own_SpendPerTxn", "Airtime_Oth_TxnPerMonth",
                   "Airtime_Total_TxnPerMonth", "Airtime_Total_MonthlySpend",
                   "Airtime_Total_SpendPerTxn", "DomSend_Total_MonthlySpend")) {
    expect_true(column %in% names(result), info = column)
  }
  # a single-cascade category gets no invented Own or Oth split
  expect_false("DomSend_Own_TxnPerMonth" %in% names(result))
  expect_equal(result$Airtime_Total_MonthlySpend[1], 80)
})

test_that("incomplete respondents are counted and flagged", {
  source <- fixture_totals_source()
  source$data$AirtimeOwnAmount[1] <- "dont know"
  result <- derive_vas(source, fixture_totals_map(), VAS_CONFIG)$wide
  expect_equal(result$CategoriesIncomplete[1], 1)
  expect_true(result$Incomplete[1])
  # the total is still built from what is present: R30 other + R500 sent
  expect_equal(result$TotalValueTransacted[1], 530)
})

test_that("the audit table carries one row per respondent, category and base", {
  result <- derive_vas(fixture_totals_source(), fixture_totals_map(), VAS_CONFIG)
  # 4 collected rows plus the derived Airtime Total, over 2 respondents
  expect_equal(nrow(result$audit), 10L)
  expect_equal(sort(unique(result$audit$Base)), c("Oth", "Own", "Total"))
})

test_that("a source missing a mapped column fails loudly before calculating", {
  source <- fixture_totals_source()
  source$data$AirtimeOwnAmount <- NULL
  expect_error(derive_vas(source, fixture_totals_map(), VAS_CONFIG),
               class = "vas_missing_column")
})

test_that("the real category map is well formed", {
  map <- fixture_real_map()
  expect_equal(nrow(map), 52L)
  expect_equal(as.integer(table(map$base)[c("Own", "Oth", "Total")]), c(19L, 19L, 14L))
  expect_true(all(map$spend_class %in%
                    c("consumption", "obligation", "transfer", "received")))
  # every row must offer some way of establishing a frequency
  derivable <- !is.na(map$freq1) | !is.na(map$assumed_cadence) | !is.na(map$count_alias)
  expect_true(all(derivable))
  # every row must offer some way of establishing an amount
  priced <- !is.na(map$amount_alias) | map$amount_basis == "imputed"
  expect_true(all(priced))
})

# ==============================================================================
# THE SCREENER DECIDES, AND A DON'T-KNOW AMOUNT IS NOT A ZERO
# ==============================================================================
# Duncan, 2026-08-07: "don't know counts as a buyer but not included in mean
# amount and medians; screener is the decide."

test_that("a don't-know amount leaves the published Total spend blank", {
  own <- data.frame(txn_per_month = 2, monthly_spend = NA_real_,
                    spend_per_txn = NA_real_, trips_per_year = NA_real_,
                    status = "amount_missing",
                    outlier = FALSE, stringsAsFactors = FALSE)
  oth <- data.frame(txn_per_month = 0, monthly_spend = 0,
                    spend_per_txn = NA_real_, trips_per_year = NA_real_,
                    status = "not_asked",
                    outlier = FALSE, stringsAsFactors = FALSE)
  total <- combine_bases_to_total(own, oth)
  # the internal frame still carries what is present - the wallet totals are
  # deliberately built from that
  expect_equal(total$monthly_spend, 0)
  expect_true(total$amount_unknown)

  # but the PUBLISHED column blanks it: they stay a buyer with their
  # transactions, and leave the amount means and medians
  derived <- list("Cat|Own" = own, "Cat|Oth" = oth, "Cat|Total" = total)
  map <- data.frame(category = "Cat", base = c("Own", "Oth"),
                    stringsAsFactors = FALSE)
  cols <- build_category_columns(derived, map)
  expect_true(is.na(cols$Cat_Total_MonthlySpend))
  expect_true(is.na(cols$Cat_Total_SpendPerTxn))
  expect_equal(cols$Cat_Total_TxnPerMonth, 2)   # still a buyer, still counted
})

test_that("a missing FREQUENCY does not blank a known amount", {
  own <- data.frame(txn_per_month = NA_real_, monthly_spend = 300,
                    spend_per_txn = NA_real_, trips_per_year = NA_real_,
                    status = "freq_missing",
                    outlier = FALSE, stringsAsFactors = FALSE)
  oth <- data.frame(txn_per_month = 0, monthly_spend = 0,
                    spend_per_txn = NA_real_, trips_per_year = NA_real_,
                    status = "not_asked",
                    outlier = FALSE, stringsAsFactors = FALSE)
  total <- combine_bases_to_total(own, oth)
  expect_false(total$amount_unknown)
  derived <- list("Cat|Own" = own, "Cat|Oth" = oth, "Cat|Total" = total)
  map <- data.frame(category = "Cat", base = c("Own", "Oth"),
                    stringsAsFactors = FALSE)
  cols <- build_category_columns(derived, map)
  expect_equal(cols$Cat_Total_MonthlySpend, 300)
})

test_that("the category map makes the screener authoritative for the four multis", {
  map <- read_category_map("../..")
  for (cat in c("PrepaidElectricity", "Airtime", "Data", "DigitalVouchers")) {
    rows <- map[map$category == cat, ]
    expect_equal(nrow(rows), 2L, info = cat)
    expect_true(all(nzchar(rows$presence_alias) & !is.na(rows$presence_alias)),
                info = cat)
    expect_true(all(nzchar(rows$presence_option) & !is.na(rows$presence_option)),
                info = cat)
  }
  # the wording is NOT uniform - electricity says "Your own household" where the
  # others say "Myself", and guessing would silently zero a whole category
  ppu <- map[map$category == "PrepaidElectricity" & map$base == "Own", ]
  expect_equal(ppu$presence_option, "Your own household")
  air <- map[map$category == "Airtime" & map$base == "Own", ]
  expect_equal(air$presence_option, "Myself")
})

test_that("the wallet excludes money sent and received, in rand and in transactions", {
  result <- derive_vas(fixture_wallet_source(), fixture_wallet_map(), VAS_CONFIG)$wide
  # airtime 50 + 30, municipal bill 100 + 40, lotto 2 x R10; sent 500 and
  # received 200 stay out
  expect_equal(result$TotalWalletSpend[1], 240)
  expect_equal(result$TotalValueTransacted[1], 740)
  # transactions: airtime 2 + bill 2 + lotto 2; send and receive count only in
  # the all-category TotalTxnPerMonth
  expect_equal(result$TotalWalletTxn[1], 6)
  expect_equal(result$TotalTxnPerMonth[1], 8)
})

test_that("the wallet's self side plus the for-others side equals the wallet", {
  result <- derive_vas(fixture_wallet_source(), fixture_wallet_map(), VAS_CONFIG)$wide
  # self = airtime own 50 + bill own 100 + lotto 20 (unsplit counts as self)
  expect_equal(result$TotalWalletSpendSelf[1], 170)
  expect_equal(result$TotalSpendForOthers[1], 70)
  expect_equal(result$TotalWalletSpendSelf[1] + result$TotalSpendForOthers[1],
               result$TotalWalletSpend[1])
  expect_equal(result$TotalWalletTxnSelf[1], 4)
})

test_that("the gambling line is a subset of the wallet, at face value", {
  result <- derive_vas(fixture_wallet_source(), fixture_wallet_map(), VAS_CONFIG)$wide
  expect_equal(result$TotalGamblingSpend[1], 20)
  expect_equal(result$TotalGamblingTxn[1], 2)
  expect_true(result$TotalGamblingSpend[1] <= result$TotalWalletSpend[1])
})

test_that("a respondent routed past everything gets a zero wallet, not missing", {
  result <- derive_vas(fixture_wallet_source(), fixture_wallet_map(), VAS_CONFIG)$wide
  expect_equal(result$TotalWalletSpend[2], 0)
  expect_equal(result$TotalWalletSpendSelf[2], 0)
  expect_equal(result$TotalGamblingSpend[2], 0)
})

test_that("a don't-know amount leaves the wallet built from what is present", {
  source <- fixture_wallet_source()
  source$data$AirtimeOwnAmount[1] <- "dont know"
  result <- derive_vas(source, fixture_wallet_map(), VAS_CONFIG)$wide
  expect_equal(result$TotalWalletSpend[1], 190)
  expect_true(result$Incomplete[1])
})

test_that("every split category sits inside the wallet classes", {
  # TotalSpendForOthers doubles as the wallet's for-others side. That is only
  # true while every category with an Own/Oth split is in a wallet spend class,
  # so a reclassification that breaks the identity must fail here.
  map <- fixture_real_map()
  split_classes <- unique(map$spend_class[map$base %in% c("Own", "Oth")])
  expect_true(all(split_classes %in% VAS_CONFIG$total_wallet_spend))
})

test_that("the gambling categories exist in the real map, inside the wallet", {
  map <- fixture_real_map()
  for (category in VAS_CONFIG$gambling_categories) {
    expect_true(category %in% map$category, info = category)
    expect_true(all(map$spend_class[map$category == category] %in%
                      VAS_CONFIG$total_wallet_spend), info = category)
  }
})
