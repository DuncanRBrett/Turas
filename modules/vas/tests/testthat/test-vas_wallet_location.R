# test-vas_wallet_location.R
# Where the wallet is spent, and where its transactions happen. The invariant
# that matters is that the six location columns add up to the published total
# for every respondent - a split that does not reconcile must not be reported.

location_fixture_map <- function() {
  data.frame(
    category = c("PrepaidElectricity", "BillMunicipal", "BillDSTV", "DomSend",
                 "DomRcv"),
    spend_class = c("consumption", "obligation", "obligation", "transfer",
                    "received"),
    stringsAsFactors = FALSE
  )
}

# Five respondents, one per case worth getting wrong:
#   1  bank for electricity, retailer for both bills, spaza for the transfer
#   2  a channel the location table does not name (falls to Other)
#   3  no channel answer at all on a paid occasion (also Other)
#   4  a split category with a don't-know on one side - the known side counts
#   5  did nothing
location_fixture_data <- function() {
  d <- data.frame(
    ResponseID = as.character(1:5),
    PrepaidElectricity_Own_MonthlySpend = c(500, 300, 200, NA, 0),
    PrepaidElectricity_Oth_MonthlySpend = c(0, 0, 0, 250, 0),
    PrepaidElectricity_Total_MonthlySpend = c(500, 300, 200, NA, 0),
    PrepaidElectricity_Own_TxnPerMonth = c(4, 2, 1, NA, 0),
    PrepaidElectricity_Oth_TxnPerMonth = c(0, 0, 0, 2, 0),
    PrepaidElectricity_Total_TxnPerMonth = c(4, 2, 1, NA, 0),
    BillMunicipal_Total_MonthlySpend = c(400, 0, 0, 0, 0),
    BillMunicipal_Total_TxnPerMonth = c(1, 0, 0, 0, 0),
    BillDSTV_Total_MonthlySpend = c(100, 0, 0, 0, 0),
    BillDSTV_Total_TxnPerMonth = c(1, 0, 0, 0, 0),
    DomSend_Total_MonthlySpend = c(50, 0, 0, 0, 0),
    DomSend_Total_TxnPerMonth = c(0.5, 0, 0, 0, 0),
    DomRcv_Total_MonthlySpend = c(9999, 9999, 9999, 9999, 9999),
    DomRcv_Total_TxnPerMonth = c(9, 9, 9, 9, 9),
    PPUChannelMain = c("Bank App", "Bus station kiosks", NA, "Convenience store", NA),
    BillChannelMain = c("Retailer tillpoint cash", NA, NA, NA, NA),
    DomSendChannelMain = c("Spaza Shop / Kiosk", NA, NA, NA, NA),
    stringsAsFactors = FALSE
  )
  # what the engine publishes: consumption + obligation + transfer sent, with
  # the split category reconstructed from its two sides
  d$TotalValueTransacted <- c(500 + 400 + 100 + 50, 300, 200, 250, 0)
  d$TotalTxnTransacted <- c(4 + 1 + 1 + 0.5, 2, 1, 2, 0)
  return(d)
}

# The structure this runs against in a real build is WIDE: it has been through
# rbind_widened() with the derived rows, so it carries MeanLabel, the ratio
# pairing, Category and the rest, while a freshly built block carries four
# columns. A fixture as narrow as the block hides that - the first live build
# refused with "numbers of columns of arguments do not match" while every test
# here passed. So the fixture is wide on purpose.
location_fixture_structure <- function() {
  list(questions = data.frame(
         QuestionCode = c("TotalValueTransacted", "TotalTxnTransacted", "Gender"),
         QuestionText = c("Total value transacted", "Total transactions", "Gender"),
         Variable_Type = c("Numeric", "Numeric", "Single_Response"),
         Columns = c(1L, 1L, 1L),
         Category = c("VAS wallet", "VAS wallet", "Demographics"),
         MeanLabel = NA_character_, RatioNumerator = NA_character_,
         RatioDenominator = NA_character_, RatioLabel = NA_character_,
         Notes = NA_character_, stringsAsFactors = FALSE),
       options = data.frame(
         QuestionCode = "Gender", OptionText = c("Male", "Female"),
         DisplayText = c("Male", "Female"), DisplayOrder = 1:2,
         ShowInOutput = "Y", Min = NA_real_, Max = NA_real_,
         stringsAsFactors = FALSE))
}

test_that("a raw channel answer resolves to its location, and anything else to Other", {
  expect_equal(vas_location_of(c("Bank App", "Retailer money counter", "MNO App",
                                 "Spaza Shop / Kiosk", "Convenience store")),
               c("Bank", "Retailer", "MNO", "Spaza", "Convenience"))
  # an unlisted channel, a blank and a missing answer all read the same
  expect_equal(vas_location_of(c("Bus station kiosks", "", NA)),
               rep("Other", 3))
})

test_that("each occasion's spend lands at the channel it is bought through", {
  cols <- wallet_location_columns(location_fixture_data(), location_fixture_map())

  expect_equal(cols$WalletLoc_1, c(500, 0, 0, 0, 0))
  expect_equal(cols$WalletLoc_2, c(500, 0, 0, 0, 0))   # both bill types
  expect_equal(cols$WalletLoc_4, c(50, 0, 0, 0, 0))
  expect_equal(cols$WalletLoc_5, c(0, 0, 0, 250, 0))
  expect_equal(cols$WalletLoc_3, rep(0, 5))
  # 2 bought through a bus-station kiosk, 3 named no channel at all
  expect_equal(cols$WalletLoc_6, c(0, 300, 200, 0, 0))
})

test_that("transactions split the same way, off the same channel answers", {
  cols <- wallet_location_columns(location_fixture_data(), location_fixture_map(),
                                  measure = "txn")

  expect_equal(cols$WalletLocTxn_1, c(4, 0, 0, 0, 0))
  expect_equal(cols$WalletLocTxn_2, c(2, 0, 0, 0, 0))  # both bill types
  expect_equal(cols$WalletLocTxn_4, c(0.5, 0, 0, 0, 0))
  expect_equal(cols$WalletLocTxn_5, c(0, 0, 0, 2, 0))
  expect_equal(cols$WalletLocTxn_6, c(0, 2, 1, 0, 0))
})

test_that("money received is not spend and never reaches a location", {
  for (measure in c("spend", "txn")) {
    cols <- wallet_location_columns(location_fixture_data(), location_fixture_map(),
                                    measure = measure)
    keys <- vapply(VAS_LOCATIONS$key, wallet_location_column, character(1),
                   measure = measure)
    placed <- Reduce(`+`, cols[keys])
    expect_equal(placed,
                 location_fixture_data()[[wallet_measure(measure)$total]],
                 info = measure)
  }
})

test_that("a split category is reconstructed from its sides, past a don't-know", {
  spend <- wallet_location_columns(location_fixture_data(), location_fixture_map())
  txn <- wallet_location_columns(location_fixture_data(), location_fixture_map(),
                                 measure = "txn")

  # respondent 4 has no Total (one side is a don't-know) and a value on the other
  expect_equal(spend$WalletLoc_5[4], 250)
  expect_equal(txn$WalletLocTxn_5[4], 2)
})

test_that("a split that does not add up to the published total is refused", {
  broken <- location_fixture_data()
  broken$TotalValueTransacted[2] <- broken$TotalValueTransacted[2] + 1
  expect_error(wallet_location_columns(broken, location_fixture_map()),
               class = "vas_wallet_location_does_not_reconcile")

  broken2 <- location_fixture_data()
  broken2$TotalTxnTransacted[2] <- broken2$TotalTxnTransacted[2] + 1
  expect_error(wallet_location_columns(broken2, location_fixture_map(),
                                       measure = "txn"),
               class = "vas_wallet_location_does_not_reconcile")
})

test_that("a category in the total that no channel question covers is refused", {
  map <- rbind(location_fixture_map(),
               data.frame(category = "SomethingNew", spend_class = "consumption",
                          stringsAsFactors = FALSE))
  expect_error(wallet_location_columns(location_fixture_data(), map),
               class = "vas_wallet_category_unplaced")
})

test_that("the member columns are named by POSITION, as an Allocation question needs", {
  # the tabs Allocation processor reads {code}_1 ... {code}_N in the Options
  # sheet's own order, so a location's column is its row number, not its key
  expect_equal(wallet_location_column("Bank"), "WalletLoc_1")
  expect_equal(wallet_location_column("Other"), "WalletLoc_6")
  expect_equal(wallet_location_column("Bank", "txn"), "WalletLocTxn_1")
  expect_error(wallet_location_column("Post office"), "Unknown location")

  cols <- wallet_location_columns(location_fixture_data(), location_fixture_map())
  expect_equal(names(cols), sprintf("WalletLoc_%d", 1:6))
})

test_that("an unknown measure is refused rather than guessed at", {
  expect_error(wallet_measure("rand"), "Unknown wallet measure")
})

test_that("each measure is ONE Allocation question with one option per location", {
  for (measure in c("spend", "txn")) {
    spec <- wallet_measure(measure)
    rows <- wallet_location_structure_rows(measure)
    expect_equal(nrow(rows$questions), 1L, info = measure)
    expect_equal(rows$questions$QuestionCode, spec$code)
    expect_equal(rows$questions$Variable_Type, "Allocation")
    expect_equal(rows$questions$Columns, nrow(VAS_LOCATIONS))
    # the Options sheet's order IS the column order, so it must be the
    # locations in their own order
    expect_equal(rows$options$OptionText, VAS_LOCATIONS$label, info = measure)
    expect_equal(rows$options$DisplayOrder, seq_len(nrow(VAS_LOCATIONS)))
  }
})

test_that("add_wallet_location builds both measures, once", {
  built <- add_wallet_location(location_fixture_data(),
                               location_fixture_structure(),
                               location_fixture_map())

  for (measure in c("spend", "txn")) {
    spec <- wallet_measure(measure)
    keys <- vapply(VAS_LOCATIONS$key, wallet_location_column, character(1),
                   measure = measure)
    expect_true(all(keys %in% names(built$data)), info = measure)
    # spliced in behind the total it adds up to, question AND options
    expect_true(match(spec$code, built$questions$QuestionCode) >
                  match(spec$total, built$questions$QuestionCode))
    expect_equal(sum(built$options$QuestionCode == spec$code),
                 nrow(VAS_LOCATIONS), info = measure)
  }

  expect_error(add_wallet_location(built$data,
                                   list(questions = built$questions,
                                        options = built$options),
                                   location_fixture_map()),
               class = "vas_wallet_location_already_added")
})

test_that("the spliced rows keep every column the structure already had", {
  built <- add_wallet_location(location_fixture_data(),
                               location_fixture_structure(),
                               location_fixture_map())
  was <- location_fixture_structure()

  expect_true(all(names(was$questions) %in% names(built$questions)))
  expect_true(all(names(was$options) %in% names(built$options)))
  # the columns the block does not carry come back empty, not dropped
  at <- match("WalletLoc", built$questions$QuestionCode)
  expect_true(is.na(built$questions$Category[at]) ||
                !nzchar(as.character(built$questions$Category[at])))
  # and the questions that were already there keep their own values
  gender <- built$questions[built$questions$QuestionCode == "Gender", ]
  expect_equal(gender$Category, "Demographics")
})

test_that("a study with neither total is left exactly as it was", {
  data <- location_fixture_data()
  data$TotalValueTransacted <- NULL
  data$TotalTxnTransacted <- NULL
  structure <- location_fixture_structure()

  built <- add_wallet_location(data, structure, location_fixture_map())
  expect_equal(built$data, data)
  expect_equal(built$questions, structure$questions)
})
