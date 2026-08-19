# test-vas_wallet_section.R
# The wallet split by report section. Two invariants: the sections add up to the
# published wallet total in RAND before anything becomes a percentage, and every
# category in the wallet total belongs to exactly one section.

ws_map <- function() {
  data.frame(
    category = c("PrepaidElectricity", "Airtime", "BillMunicipal", "BillDSTV",
                 "DomSend", "DomRcv", "EventConcert"),
    spend_class = c("consumption", "consumption", "obligation", "obligation",
                    "transfer", "received", "consumption"),
    stringsAsFactors = FALSE)
}

# Three respondents:
#   1  spends across four sections
#   2  bills only
#   3  nothing at all - no split to report
ws_data <- function() {
  d <- data.frame(
    ResponseID = as.character(1:3),
    PrepaidElectricity_Own_MonthlySpend = c(200, 0, 0),
    PrepaidElectricity_Oth_MonthlySpend = c(0, 0, 0),
    Airtime_Total_MonthlySpend = c(100, 0, 0),
    BillMunicipal_Total_MonthlySpend = c(500, 400, 0),
    BillDSTV_Total_MonthlySpend = c(0, 100, 0),
    DomSend_Total_MonthlySpend = c(200, 0, 0),
    DomRcv_Total_MonthlySpend = c(9999, 9999, 9999),
    EventConcert_Total_MonthlySpend = c(0, 0, 0),
    stringsAsFactors = FALSE)
  d$TotalValueTransacted <- c(1000, 500, 0)
  d
}

ws_structure <- function() {
  list(questions = data.frame(
         QuestionCode = c("TotalValueTransacted", "Gender"),
         QuestionText = c("Total value transacted", "Gender"),
         Variable_Type = c("Numeric", "Single_Response"),
         Columns = c(1L, 1L),
         Category = c("VAS wallet", "Demographics"),
         MeanLabel = NA_character_, stringsAsFactors = FALSE),
       options = data.frame(
         QuestionCode = "Gender", OptionText = c("Male", "Female"),
         DisplayText = c("Male", "Female"), DisplayOrder = 1:2,
         ShowInOutput = "Y", stringsAsFactors = FALSE))
}

ws_at <- function(label) {
  match(label, vapply(VAS_WALLET_SECTIONS, function(s) s$label, character(1)))
}

test_that("a prefix section picks up every category the study has", {
  members <- wallet_section_members(ws_map())

  expect_setequal(members[["Bills"]], c("BillMunicipal", "BillDSTV"))
  expect_equal(members[["Prepaid electricity"]], "PrepaidElectricity")
  expect_equal(members[["Domestic money sent"]], "DomSend")
})

test_that("money received belongs to no section, by design", {
  members <- wallet_section_members(ws_map())

  expect_false("DomRcv" %in% unlist(members, use.names = FALSE))
})

test_that("a category in the wallet total with no section is refused", {
  map <- rbind(ws_map(),
               data.frame(category = "SomethingNew", spend_class = "consumption",
                          stringsAsFactors = FALSE))
  expect_error(wallet_section_members(map), class = "vas_wallet_section_unplaced")
})

test_that("each section is that person's own share of their own wallet", {
  cols <- wallet_section_columns(ws_data(), ws_map())

  # respondent 1: 200 electricity, 100 airtime, 500 bills, 200 sent, of 1000
  expect_equal(cols[[sprintf("WalletSectionPct_%d", ws_at("Prepaid electricity"))]][1], 20)
  expect_equal(cols[[sprintf("WalletSectionPct_%d", ws_at("Prepaid airtime"))]][1], 10)
  expect_equal(cols[[sprintf("WalletSectionPct_%d", ws_at("Bills"))]][1], 50)
  expect_equal(cols[[sprintf("WalletSectionPct_%d", ws_at("Domestic money sent"))]][1], 20)
  # respondent 2 is bills only
  expect_equal(cols[[sprintf("WalletSectionPct_%d", ws_at("Bills"))]][2], 100)
})

test_that("someone with nothing in their wallet has no split, not thirteen zeros", {
  cols <- wallet_section_columns(ws_data(), ws_map())
  third <- vapply(cols, function(v) v[3], numeric(1))

  expect_true(all(is.na(third)))
})

test_that("the shares add up to 100 for everyone who has a wallet", {
  cols <- wallet_section_columns(ws_data(), ws_map())
  total <- Reduce(`+`, cols)

  expect_equal(total[1:2], c(100, 100))
})

test_that("a section quietly missing a category is refused, in rand not percent", {
  data <- ws_data()
  data$TotalValueTransacted[1] <- 1200      # the engine says 1200, the parts say 1000

  expect_error(wallet_section_columns(data, ws_map()),
               class = "vas_wallet_section_does_not_reconcile")
})

test_that("it is ONE Allocation question with one option per section", {
  rows <- wallet_section_structure_rows()

  expect_equal(nrow(rows$questions), 1L)
  expect_equal(rows$questions$Variable_Type, "Allocation")
  expect_equal(rows$questions$Columns, length(VAS_WALLET_SECTIONS))
  expect_equal(nrow(rows$options), length(VAS_WALLET_SECTIONS))
  expect_equal(rows$options$DisplayOrder, seq_along(VAS_WALLET_SECTIONS))
  expect_false("Domestic money received" %in% rows$options$OptionText)
})

test_that("add_wallet_section widens the data and the structure together, once", {
  built <- add_wallet_section(ws_data(), ws_structure(), ws_map())

  expect_true(VAS_WALLET_SECTION_CODE %in% built$questions$QuestionCode)
  expect_equal(sum(built$options$QuestionCode == VAS_WALLET_SECTION_CODE),
               length(VAS_WALLET_SECTIONS))
  expect_true(match(VAS_WALLET_SECTION_CODE, built$questions$QuestionCode) >
                match("TotalValueTransacted", built$questions$QuestionCode))
  # the structure's own columns survive the splice
  expect_true(all(names(ws_structure()$questions) %in% names(built$questions)))

  expect_error(add_wallet_section(built$data,
                                  list(questions = built$questions,
                                       options = built$options), ws_map()),
               class = "vas_wallet_section_already_added")
})

test_that("a study with no wallet total is left exactly as it was", {
  data <- ws_data()
  data$TotalValueTransacted <- NULL
  built <- add_wallet_section(data, ws_structure(), ws_map())

  expect_equal(built$data, data)
  expect_equal(built$questions, ws_structure()$questions)
})
