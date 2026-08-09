# test-vas_composites.R
# The 23 July additions: bill presence via the checkbox, per-spend-class amount
# ranges, outlier flags (flag, never cap) and the composite scores.

# ---- presence via the bill checkbox ------------------------------------------

presence_map_row <- function(base = "Own") {
  fixture_map_row(
    category = "BillDSTV", label = "DSTV", base = base,
    amount_alias = "BillDSTVOwnAmount", amount_basis = "monthly",
    presence_alias = "BillOwnWhich", presence_option = "Multi-choice / DSTV",
    assumed_cadence = "monthly", spend_class = "obligation"
  )
}

test_that("a bill ticked but with no amount is amount_missing, not a zero", {
  source_data <- fixture_source(
    `Multi-choice / DSTV:BillOwnWhich` = c("Multi-choice / DSTV", "Multi-choice / DSTV", NA),
    BillDSTVOwnAmount = c("R199", NA, NA)
  )
  frame <- derive_category_base(source_data, presence_map_row(), VAS_CONFIG)

  # ticked and costed
  expect_equal(frame$status[1], "ok")
  expect_equal(frame$monthly_spend[1], 199)
  expect_equal(frame$txn_per_month[1], 1)

  # ticked, no amount: the respondent PAYS this bill - the figure is missing
  expect_equal(frame$status[2], "amount_missing")
  expect_true(is.na(frame$monthly_spend[2]))
  expect_equal(frame$txn_per_month[2], 1)

  # not ticked: routed past, a genuine zero
  expect_equal(frame$status[3], "not_asked")
  expect_equal(frame$monthly_spend[3], 0)
  expect_equal(frame$txn_per_month[3], 0)
})

test_that("the real map carries a presence alias for every no-frequency bill", {
  map <- fixture_real_map()
  no_frequency_bills <- map[is.na(map$freq1) & is.na(map$count_alias), ]
  expect_true(all(!is.na(no_frequency_bills$presence_alias)))
  expect_true(all(!is.na(no_frequency_bills$presence_option)))
})

# ---- per-spend-class amount ranges -------------------------------------------

test_that("a transfer parses at R1,000,000 while consumption still rejects it", {
  transfer_config <- config_for_spend_class(VAS_CONFIG, "transfer")
  expect_equal(parse_amount_scalar("R1,000,000", transfer_config)$status, "ok")
  expect_equal(parse_amount_scalar("R1,000,000", transfer_config)$value, 1000000)
  expect_equal(parse_amount_scalar("R1,000,001", transfer_config)$status, "out_of_range")

  consumption_config <- config_for_spend_class(VAS_CONFIG, "consumption")
  expect_equal(parse_amount_scalar("R1,000,000", consumption_config)$status, "out_of_range")

  # a class with no override, and a missing class, leave the config unchanged
  expect_equal(config_for_spend_class(VAS_CONFIG, "obligation")$amount_max,
               VAS_CONFIG$amount_max)
  expect_equal(config_for_spend_class(VAS_CONFIG, NA_character_)$amount_max,
               VAS_CONFIG$amount_max)
})

# ---- outlier flags -----------------------------------------------------------

outlier_map_row <- function() {
  fixture_map_row(
    category = "BillTraffic", label = "Traffic fines", base = "Own",
    freq1 = "F1", freq2 = "F2", freq3 = "F3", freq4 = "F4",
    amount_alias = "Amt", amount_basis = "last_occasion",
    spend_class = "obligation"
  )
}

test_that("an implausible frequency is flagged and the numbers are unchanged", {
  # respondent 1: 5x a week on a traffic fine - the real 8912114 failure case
  source_data <- fixture_source(
    F1 = c("Once a week or more often", "Once per month"),
    F2 = c("5", NA), F3 = c(NA, NA), F4 = c(NA, NA),
    Amt = c("R500", "R500")
  )
  frame <- derive_category_base(source_data, outlier_map_row(), VAS_CONFIG)

  expect_true(frame$outlier[1])                     # 21.7 bills a month, flagged
  expect_false(frame$outlier[2])                    # 1 a month, fine
  expect_equal(frame$txn_per_month[1], 5 * 52 / 12) # the figure is NOT capped
  expect_equal(frame$monthly_spend[1], 5 * 52 / 12 * 500)
})

test_that("a derived Total inherits its sides' outlier flags", {
  own <- data.frame(txn_per_month = c(30, 1), monthly_spend = c(15000, 100),
                    spend_per_txn = c(500, 100), status = c("ok", "ok"),
                    outlier = c(TRUE, FALSE), stringsAsFactors = FALSE)
  oth <- data.frame(txn_per_month = c(0, 1), monthly_spend = c(0, 100),
                    spend_per_txn = c(NA, 100), status = c("not_asked", "ok"),
                    outlier = c(FALSE, FALSE), stringsAsFactors = FALSE)
  total <- combine_bases_to_total(own, oth)
  expect_equal(total$outlier, c(TRUE, FALSE))
})

test_that("a spend class with no configured ceiling is never flagged", {
  config <- VAS_CONFIG
  config$outlier_txn_per_month <- list()
  config$outlier_monthly_spend <- list()
  expect_equal(category_outlier_flags(c(1000, NA), c(1e7, NA), "obligation", config),
               c(FALSE, FALSE))
})

# ---- composites through derive_vas -------------------------------------------

test_that("the composites carry the worked example through derive_vas", {
  result <- derive_vas(fixture_totals_source(), fixture_totals_map(), VAS_CONFIG)$wide

  # respondent 1: airtime 1x R50 own + 1x R30 oth, sends R500, receives R200
  expect_equal(result$TotalValueTransacted[1], 580)   # 80 airtime + 500 sent
  expect_equal(result$TotalConsumptionSpend[1], 80)
  expect_equal(result$TotalTransferSent[1], 500)
  expect_true(is.na(result$TotalBillSpend[1]))        # no obligation category in this map
  expect_equal(result$ValueReceived[1], 200)

  expect_equal(result$TotalTxnTransacted[1], 3)       # excludes the receipt
  expect_equal(result$TotalTxnPerMonth[1], 4)         # includes the receipt
  expect_equal(result$AvgSpendPerTxn[1], 580 / 3)

  expect_equal(result$TotalSpendForOthers[1], 30)
  expect_equal(result$TotalTxnForOthers[1], 1)
  expect_equal(result$ShareForOthers[1], 30 / 80)
  expect_true(result$BuysForOthers[1])

  expect_equal(result$CategoriesPurchased[1], 3)      # airtime, send, receive
  expect_true(result$Airtime_Purchased[1])
  expect_true(result$DomSend_Purchased[1])
  expect_true(result$DomRcv_Purchased[1])

  # respondent 2: routed past everything - zeros and FALSE, not missing
  expect_equal(result$CategoriesPurchased[2], 0)
  expect_false(result$Airtime_Purchased[2])
  expect_equal(result$TotalSpendForOthers[2], 0)
  expect_false(result$BuysForOthers[2])
  expect_true(is.na(result$ShareForOthers[2]))        # no spend to take a share of
  expect_equal(result$OutlierCells[2], 0)
  expect_false(result$OutlierFlag[2])
})

test_that("buys-but-unmeasured counts as purchased", {
  source_data <- fixture_source(
    Income = c("R3,500 to R7,999"),
    `Multi-choice / DSTV:BillOwnWhich` = c("Multi-choice / DSTV"),
    BillDSTVOwnAmount = c(NA_character_)
  )
  result <- derive_vas(source_data, presence_map_row(), VAS_CONFIG)$wide
  expect_true(result$BillDSTV_Purchased[1])
  expect_equal(result$CategoriesPurchased[1], 1)
})

test_that("the audit table carries the outlier flag", {
  source_data <- fixture_source(
    Income = c("R3,500 to R7,999"),
    F1 = c("Once a week or more often"), F2 = c("5"), F3 = c(NA_character_),
    F4 = c(NA_character_), Amt = c("R500")
  )
  audit <- derive_vas(source_data, outlier_map_row(), VAS_CONFIG)$audit
  expect_true("Outlier" %in% names(audit))
  expect_true(audit$Outlier[audit$Base == "Own"])
})
