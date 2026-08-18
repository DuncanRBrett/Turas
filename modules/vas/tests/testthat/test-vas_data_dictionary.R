# test-vas_data_dictionary.R
# The dictionary must describe exactly the columns the engine produces, and its
# numbers must come from the config rather than being written in by hand.

test_that("the dictionary documents every real output column and no others", {
  map <- fixture_real_map()
  dictionary <- build_data_dictionary(map, VAS_CONFIG)
  columns <- names(derive_vas(fixture_blank_source(map), map, VAS_CONFIG)$wide)
  expect_equal(setdiff(columns, dictionary$column), character(0))
  expect_equal(setdiff(dictionary$column, columns), character(0))
})

test_that("the dictionary has one row per column, in output order", {
  map <- fixture_real_map()
  dictionary <- build_data_dictionary(map, VAS_CONFIG)
  # 279: the three travel legs-a-year columns replace the three imputed
  # value-per-transaction ones, one for one (Aug 2026)
  expect_equal(nrow(dictionary), 279L)
  expect_equal(anyDuplicated(dictionary$column), 0L)
  expect_equal(names(dictionary), VAS_DICTIONARY_COLUMNS)
})

test_that("every row is fully populated", {
  dictionary <- build_data_dictionary(fixture_real_map(), VAS_CONFIG)
  for (column in c("column", "group", "unit", "description", "calculation",
                   "source_questions", "missing_rule")) {
    expect_true(all(nzchar(dictionary[[column]])), info = column)
    expect_false(any(is.na(dictionary[[column]])), info = column)
  }
})

test_that("the weeks-per-month factor is read from the config, not hard-coded", {
  map <- fixture_real_map()
  default <- build_data_dictionary(map, VAS_CONFIG)
  entry <- default$calculation[default$column == "Airtime_Own_TxnPerMonth"]
  expect_true(grepl("4.33333", entry, fixed = TRUE))

  flat_config <- VAS_CONFIG
  flat_config$weeks_per_month <- 4
  changed <- build_data_dictionary(map, flat_config)
  changed_entry <- changed$calculation[changed$column == "Airtime_Own_TxnPerMonth"]
  expect_true(grepl("AirtimeOwnFreq2 x 4\n", changed_entry, fixed = TRUE))
  expect_false(grepl("4.33333", changed_entry, fixed = TRUE))
})

test_that("imputed rates are read from the config", {
  map <- fixture_real_map()
  dictionary <- build_data_dictionary(map, VAS_CONFIG)
  # the travel three publish no per-transaction column, so the rate is named on
  # monthly spend and on legs a year instead
  flight <- dictionary$calculation[dictionary$column == "FlightDomestic_Total_MonthlySpend"]
  expect_true(grepl("R1,500 per leg", flight, fixed = TRUE))
  expect_equal(sum(dictionary$column == "FlightDomestic_Total_SpendPerTxn"), 0L)
  licence <- dictionary$calculation[dictionary$column == "BillTVLicence_Own_SpendPerTxn"]
  expect_true(grepl("R265", licence, fixed = TRUE))
})

test_that("income band values come from the config table", {
  dictionary <- build_data_dictionary(fixture_real_map(), VAS_CONFIG)
  midpoint <- dictionary$calculation[dictionary$column == "IncomeMidpoint"]
  expect_true(grepl('"R8,000 to R21,999" -> 15,000', midpoint, fixed = TRUE))
  expect_true(grepl('"Decline to answer" -> missing', midpoint, fixed = TRUE))
  upper <- dictionary$calculation[dictionary$column == "IncomeUpper"]
  expect_true(grepl('"R8,000 to R21,999" -> 21,999', upper, fixed = TRUE))
})

test_that("a category with no frequency question is not described as having one", {
  dictionary <- build_data_dictionary(fixture_real_map(), VAS_CONFIG)
  vehicle <- dictionary[dictionary$column == "BillVehicle_Own_TxnPerMonth", ]
  expect_true(grepl("cadence is assumed annual", vehicle$calculation, fixed = TRUE))
  expect_true(grepl("NEVER missing", vehicle$missing_rule, fixed = TRUE))
  expect_false(grepl("Don't know", vehicle$missing_rule, fixed = TRUE))
})

test_that("an imputed category is not described as having an amount to parse", {
  dictionary <- build_data_dictionary(fixture_real_map(), VAS_CONFIG)
  licence <- dictionary[dictionary$column == "BillTVLicence_Own_MonthlySpend", ]
  expect_true(grepl("imputed from the config", licence$missing_rule, fixed = TRUE))
  expect_false(grepl("cannot be read", licence$missing_rule, fixed = TRUE))
})

test_that("a monthly-basis spend per transaction is flagged as derived", {
  dictionary <- build_data_dictionary(fixture_real_map(), VAS_CONFIG)
  entry <- dictionary$calculation[dictionary$column == "PrepaidElectricity_Own_SpendPerTxn"]
  expect_true(grepl("DERIVED, not reported", entry, fixed = TRUE))
})

test_that("a derived Total is described as the sum of its two sides", {
  dictionary <- build_data_dictionary(fixture_real_map(), VAS_CONFIG)
  expect_equal(dictionary$calculation[dictionary$column == "Airtime_Total_MonthlySpend"],
               "Airtime_Own_MonthlySpend + Airtime_Oth_MonthlySpend")
  weighted <- dictionary$calculation[dictionary$column == "Airtime_Total_SpendPerTxn"]
  expect_true(grepl("NOT the mean", weighted, fixed = TRUE))
})

test_that("the headline totals name the categories that feed them", {
  map <- fixture_real_map()
  dictionary <- build_data_dictionary(map, VAS_CONFIG)
  transacted <- dictionary$calculation[dictionary$column == "TotalValueTransacted"]
  consumption <- dictionary$calculation[dictionary$column == "TotalConsumptionSpend"]
  received <- dictionary$calculation[dictionary$column == "ValueReceived"]
  # money received appears only in its own column, never in a spend total
  expect_true(grepl("DomRcv_Total_MonthlySpend", received, fixed = TRUE))
  expect_false(grepl("DomRcv", transacted, fixed = TRUE))
  expect_false(grepl("DomRcv", consumption, fixed = TRUE))
  # transfers count as value transacted but not as consumption
  expect_true(grepl("DomSend_Total_MonthlySpend", transacted, fixed = TRUE))
  expect_false(grepl("DomSend", consumption, fixed = TRUE))
})

test_that("reclassifying a category moves it between the totals", {
  map <- fixture_real_map()
  map$spend_class[map$category == "Lotto"] <- "obligation"
  dictionary <- build_data_dictionary(map, VAS_CONFIG)
  expect_false(grepl("Lotto", dictionary$calculation[dictionary$column == "TotalConsumptionSpend"]))
  expect_true(grepl("Lotto", dictionary$calculation[dictionary$column == "TotalValueTransacted"]))
})

test_that("the workbook writer refuses a dictionary that does not match", {
  map <- fixture_totals_map()
  result <- derive_vas(fixture_totals_source(), map, VAS_CONFIG)
  dictionary <- build_data_dictionary(map, VAS_CONFIG)
  dictionary$column[1] <- "NotAColumn"
  expect_error(
    write_vas_workbook(result, dictionary, VAS_CONFIG, "fixture",
                       file.path(tempdir(), "mismatch.xlsx")),
    class = "vas_dictionary_mismatch"
  )
})

test_that("the workbook is written with all four sheets", {
  map <- fixture_totals_map()
  result <- derive_vas(fixture_totals_source(), map, VAS_CONFIG)
  dictionary <- build_data_dictionary(map, VAS_CONFIG)
  path <- file.path(tempdir(), "vas_test_workbook.xlsx")
  write_vas_workbook(result, dictionary, VAS_CONFIG, "fixture", path)
  expect_true(file.exists(path))
  expect_equal(openxlsx::getSheetNames(path),
               c("Derived", "Dictionary", "Settings", "Audit"))
  written <- openxlsx::read.xlsx(path, sheet = "Derived")
  expect_equal(nrow(written), nrow(result$wide))
  expect_equal(written$TotalValueTransacted, result$wide$TotalValueTransacted)
})

test_that("the config is flattened without losing the nested settings", {
  flattened <- flatten_config(VAS_CONFIG)
  expect_true("income_bands" %in% flattened$setting)
  bands <- flattened$value[flattened$setting == "income_bands"]
  expect_true(grepl("R8,000 to R21,999", bands, fixed = TRUE))
  legs <- flattened$value[flattened$setting == "imputed_spend_per_leg"]
  expect_true(grepl("FlightInternational = 7500", legs, fixed = TRUE))
})
