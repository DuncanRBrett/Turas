# test-vas_derive_category.R
# Known-answer tests for the per-category engine, one test per structural group
# in VAS_DERIVED_VARIABLES_PLAN.md section 3. Every expected number is
# hand-calculable from the fixture.

test_that("per-transaction basis multiplies the amount by the monthly count", {
  # 4 purchases a month at R50 each = R200 a month
  source <- fixture_source(
    AirtimeOwnFreq1 = "A few times in a month", AirtimeOwnFreq2 = NA_character_,
    AirtimeOwnFreq3 = "4", AirtimeOwnFreq4 = NA_character_,
    AirtimeOwnAmount = "R50"
  )
  row <- fixture_map_row(
    category = "Airtime", freq1 = "AirtimeOwnFreq1", freq2 = "AirtimeOwnFreq2",
    freq3 = "AirtimeOwnFreq3", freq4 = "AirtimeOwnFreq4",
    amount_alias = "AirtimeOwnAmount", amount_basis = "per_txn"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$txn_per_month, 4)
  expect_equal(result$monthly_spend, 200)
  expect_equal(result$spend_per_txn, 50)
  expect_equal(result$status, "ok")
})

test_that("monthly basis divides the amount by the monthly count", {
  # R400 a month over 2 x 52/12 = 8.6667 purchases = R46.15 a purchase
  source <- fixture_source(
    PPUOwnFreq1 = "Once a week or more often", PPUOwnFreq2 = "2",
    PPUOwnFreq3 = NA_character_, PPUOwnFreq4 = NA_character_,
    PPUOwnAmount = "400"
  )
  row <- fixture_map_row(
    category = "PrepaidElectricity", freq1 = "PPUOwnFreq1", freq2 = "PPUOwnFreq2",
    freq3 = "PPUOwnFreq3", freq4 = "PPUOwnFreq4",
    amount_alias = "PPUOwnAmount", amount_basis = "monthly"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$txn_per_month, 2 * 52 / 12)
  expect_equal(result$monthly_spend, 400)
  expect_equal(result$spend_per_txn, 400 / (2 * 52 / 12))
})

test_that("last-occasion basis is treated as a per-transaction amount", {
  # a fine paid 3 times a year at R750 = 0.25 a month, R187.50 a month
  source <- fixture_source(
    BillTrafficOwnFreq1 = "Less than once per month", BillTrafficOwnFreq2 = NA_character_,
    BillTrafficOwnFreq3 = NA_character_, BillTrafficOwnFreq4 = "3",
    BillTrafficOwnAmount = "750"
  )
  row <- fixture_map_row(
    category = "BillTraffic", freq1 = "BillTrafficOwnFreq1", freq2 = "BillTrafficOwnFreq2",
    freq3 = "BillTrafficOwnFreq3", freq4 = "BillTrafficOwnFreq4",
    amount_alias = "BillTrafficOwnAmount", amount_basis = "last_occasion",
    spend_class = "obligation"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$txn_per_month, 0.25)
  expect_equal(result$monthly_spend, 187.5)
  expect_equal(result$spend_per_txn, 750)
})

test_that("a monthly bill with no frequency question is one transaction a month", {
  source <- fixture_source(BillDSTVOwnAmount = c("450", NA_character_))
  row <- fixture_map_row(
    category = "BillDSTV", amount_alias = "BillDSTVOwnAmount",
    amount_basis = "monthly", assumed_cadence = "monthly", spend_class = "obligation"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$txn_per_month, c(1, 0))
  expect_equal(result$monthly_spend, c(450, 0))
  expect_equal(result$spend_per_txn, c(450, NA))
  expect_equal(result$status, c("ok", "not_asked"))
})

test_that("an annual bill is a twelfth of a transaction a month", {
  # R600 once a year = R50 a month, still R600 a transaction
  source <- fixture_source(BillVehicleOwnAmount = "600")
  row <- fixture_map_row(
    category = "BillVehicle", amount_alias = "BillVehicleOwnAmount",
    amount_basis = "last_occasion", assumed_cadence = "annual", spend_class = "obligation"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$txn_per_month, 1 / 12)
  expect_equal(result$monthly_spend, 50)
  expect_equal(result$spend_per_txn, 600)
})

test_that("the TV licence fee is imputed from the bill checkbox", {
  # R265 a year = R22.08 a month; the second respondent did not tick it
  source <- fixture_source(`TV License:BillOwnWhich` = c("TV License", NA_character_))
  row <- fixture_map_row(
    category = "BillTVLicence", amount_basis = "imputed",
    presence_alias = "BillOwnWhich", presence_option = "TV License",
    assumed_cadence = "annual", spend_class = "obligation"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$txn_per_month, c(1 / 12, 0))
  expect_equal(result$monthly_spend, c(265 / 12, 0))
  expect_equal(result$spend_per_txn, c(265, NA))
})

test_that("a return flight counts two legs and is priced per leg", {
  # 4 return domestic trips a year: 0.3333 a month, R3,000 a trip, R1,000 a month
  source <- fixture_source(FlightDomCount = "4", FlightDomReturn = "Return")
  row <- fixture_map_row(
    category = "FlightDomestic", base = "Total", amount_basis = "imputed",
    count_alias = "FlightDomCount", legs_alias = "FlightDomReturn"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$txn_per_month, 4 / 12)
  expect_equal(result$spend_per_txn, 3000)
  expect_equal(result$monthly_spend, 1000)
})

test_that("a one-way trip counts a single leg", {
  # 6 one-way bus tickets a year at R750 = 0.5 a month, R375 a month
  source <- fixture_source(LDBusCount = "6", LDBusReturn = "One way")
  row <- fixture_map_row(
    category = "LongDistanceBus", base = "Total", amount_basis = "imputed",
    count_alias = "LDBusCount", legs_alias = "LDBusReturn"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$txn_per_month, 0.5)
  expect_equal(result$spend_per_txn, 750)
  expect_equal(result$monthly_spend, 375)
})

test_that("a blank one-way/return answer falls back to the configured default", {
  expect_equal(VAS_CONFIG$legs_default, 1)
  source <- fixture_source(FlightIntlCount = "12", FlightIntlReturn = NA_character_)
  row <- fixture_map_row(
    category = "FlightInternational", base = "Total", amount_basis = "imputed",
    count_alias = "FlightIntlCount", legs_alias = "FlightIntlReturn"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$spend_per_txn, 7500)
  expect_equal(result$monthly_spend, 7500)
})

test_that("a zero count spends nothing and has no per-transaction figure", {
  source <- fixture_source(FlightDomCount = "0", FlightDomReturn = NA_character_)
  row <- fixture_map_row(
    category = "FlightDomestic", base = "Total", amount_basis = "imputed",
    count_alias = "FlightDomCount", legs_alias = "FlightDomReturn"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$txn_per_month, 0)
  expect_equal(result$monthly_spend, 0)
  expect_true(is.na(result$spend_per_txn))
})

test_that("a respondent routed past a category is a real zero", {
  source <- fixture_source(
    AirtimeOwnFreq1 = NA_character_, AirtimeOwnFreq2 = NA_character_,
    AirtimeOwnFreq3 = NA_character_, AirtimeOwnFreq4 = NA_character_,
    AirtimeOwnAmount = NA_character_
  )
  row <- fixture_map_row(
    category = "Airtime", freq1 = "AirtimeOwnFreq1", freq2 = "AirtimeOwnFreq2",
    freq3 = "AirtimeOwnFreq3", freq4 = "AirtimeOwnFreq4",
    amount_alias = "AirtimeOwnAmount", amount_basis = "per_txn"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$txn_per_month, 0)
  expect_equal(result$monthly_spend, 0)
  expect_true(is.na(result$spend_per_txn))
  expect_equal(result$status, "not_asked")
})

test_that("a buyer with an unreadable amount is missing, not zero", {
  source <- fixture_source(
    AirtimeOwnFreq1 = "Once per month", AirtimeOwnFreq2 = NA_character_,
    AirtimeOwnFreq3 = NA_character_, AirtimeOwnFreq4 = NA_character_,
    AirtimeOwnAmount = "dont know"
  )
  row <- fixture_map_row(
    category = "Airtime", freq1 = "AirtimeOwnFreq1", freq2 = "AirtimeOwnFreq2",
    freq3 = "AirtimeOwnFreq3", freq4 = "AirtimeOwnFreq4",
    amount_alias = "AirtimeOwnAmount", amount_basis = "per_txn"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$txn_per_month, 1)
  expect_true(is.na(result$monthly_spend))
  expect_equal(result$status, "amount_missing")
})

test_that("a buyer who cannot recall how often still yields a per-transaction figure", {
  source <- fixture_source(
    AirtimeOwnFreq1 = "Less than once per month", AirtimeOwnFreq2 = NA_character_,
    AirtimeOwnFreq3 = NA_character_, AirtimeOwnFreq4 = "Don't know",
    AirtimeOwnAmount = "R80"
  )
  row <- fixture_map_row(
    category = "Airtime", freq1 = "AirtimeOwnFreq1", freq2 = "AirtimeOwnFreq2",
    freq3 = "AirtimeOwnFreq3", freq4 = "AirtimeOwnFreq4",
    amount_alias = "AirtimeOwnAmount", amount_basis = "per_txn"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_true(is.na(result$txn_per_month))
  expect_true(is.na(result$monthly_spend))
  expect_equal(result$spend_per_txn, 80)
  expect_equal(result$status, "freq_missing")
})

test_that("a map row with no way to derive a frequency throws a typed error", {
  source <- fixture_source(SomeAmount = "100")
  row <- fixture_map_row(amount_alias = "SomeAmount", amount_basis = "per_txn")
  expect_error(derive_category_base(source, row, VAS_CONFIG), class = "vas_map_incomplete")
})

test_that("an unknown assumed cadence throws rather than defaulting", {
  source <- fixture_source(SomeAmount = "100")
  row <- fixture_map_row(amount_alias = "SomeAmount", amount_basis = "monthly",
                         assumed_cadence = "fortnightly")
  expect_error(derive_category_base(source, row, VAS_CONFIG), class = "vas_map_incomplete")
})

test_that("an alias absent from the source throws rather than returning NULL", {
  source <- fixture_source(SomethingElse = "100")
  row <- fixture_map_row(amount_alias = "MissingAmount", amount_basis = "monthly",
                         assumed_cadence = "monthly")
  expect_error(derive_category_base(source, row, VAS_CONFIG), class = "vas_missing_column")
})

test_that("a don't-know zero keeps the buyer and their frequency, loses the value", {
  # Duncan's rule for this study: the respondent still counts in incidence and
  # in the frequency mean; only the rand figures leave.
  source <- fixture_source(
    PPUOwnFreq1 = "A few times in a month", PPUOwnFreq2 = NA_character_,
    PPUOwnFreq3 = "3", PPUOwnFreq4 = NA_character_,
    PPUOwnAmount = "0"
  )
  row <- fixture_map_row(
    category = "PrepaidElectricity", freq1 = "PPUOwnFreq1", freq2 = "PPUOwnFreq2",
    freq3 = "PPUOwnFreq3", freq4 = "PPUOwnFreq4",
    amount_alias = "PPUOwnAmount", amount_basis = "per_txn"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)

  expect_equal(result$txn_per_month, 3)             # still a buyer, 3 a month
  expect_true(is.na(result$monthly_spend))          # no rand figure
  expect_true(is.na(result$spend_per_txn))
  expect_equal(result$status, "amount_missing")     # so the record is flagged
  expect_true(result$status %in% VAS_INCOMPLETE_STATUSES)
})

test_that("a don't-know zero on a monthly basis behaves the same way", {
  source <- fixture_source(
    PPUOwnFreq1 = "Once per month", PPUOwnFreq2 = NA_character_,
    PPUOwnFreq3 = NA_character_, PPUOwnFreq4 = NA_character_,
    PPUOwnAmount = "0"
  )
  row <- fixture_map_row(
    category = "PrepaidElectricity", freq1 = "PPUOwnFreq1", freq2 = "PPUOwnFreq2",
    freq3 = "PPUOwnFreq3", freq4 = "PPUOwnFreq4",
    amount_alias = "PPUOwnAmount", amount_basis = "monthly"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$txn_per_month, VAS_CONFIG$once_per_month_value)
  expect_true(is.na(result$monthly_spend))
  expect_true(is.na(result$spend_per_txn))
  expect_equal(result$status, "amount_missing")
})

test_that("a respondent routed past a category is still a genuine zero", {
  # The sentinel rule must not turn a real non-buyer into a missing value.
  source <- fixture_source(
    PPUOwnFreq1 = NA_character_, PPUOwnFreq2 = NA_character_,
    PPUOwnFreq3 = NA_character_, PPUOwnFreq4 = NA_character_,
    PPUOwnAmount = NA_character_
  )
  row <- fixture_map_row(
    category = "PrepaidElectricity", freq1 = "PPUOwnFreq1", freq2 = "PPUOwnFreq2",
    freq3 = "PPUOwnFreq3", freq4 = "PPUOwnFreq4",
    amount_alias = "PPUOwnAmount", amount_basis = "per_txn"
  )
  result <- derive_category_base(source, row, VAS_CONFIG)
  expect_equal(result$monthly_spend, 0)
  expect_equal(result$status, "not_asked")
  expect_false(result$status %in% VAS_INCOMPLETE_STATUSES)
})
