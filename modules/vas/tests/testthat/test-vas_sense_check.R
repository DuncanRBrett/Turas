# test-vas_sense_check.R
# Tests for the reporting layer, including a regression test for the crash that
# occurred the first time the sense check met a respondent with no income band.

test_that("agrees_within treats missing as equal to missing", {
  expect_equal(agrees_within(c(1, NA, 2), c(1, NA, 3)), c(TRUE, TRUE, FALSE))
  expect_equal(agrees_within(c(1, NA), c(NA, 1)), c(FALSE, FALSE))
})

test_that("agrees_within honours the tolerance", {
  expect_true(agrees_within(1, 1 + 1e-12))
  expect_false(agrees_within(1, 1.01))
})

test_that("a frequency table with a missing level does not crash", {
  # REGRESSION: table(useNA = "ifany") names the missing level NA, and NA
  # cannot be used as a subscript. The export held 6 respondents with no
  # income band and the report died on them.
  expect_output(print_frequency_table(c("a", "b", NA, NA)), "\\(not answered\\)")
  expect_output(print_frequency_table(c(NA, NA)), "2")
  expect_output(print_frequency_table(c("a", "a", "b")), "a\\s+2")
})

test_that("the missing label can be changed", {
  expect_output(print_frequency_table(c("Complete", NA), missing_label = "(none recorded)"),
                "none recorded")
})

test_that("the consistency check passes on a well-formed result", {
  result <- derive_vas(fixture_totals_source(), fixture_totals_map(), VAS_CONFIG)
  failures <- expect_output(check_internal_consistency(result$wide, result$audit))
  expect_equal(length(failures), 0L)
})

test_that("the consistency check catches a broken Total", {
  result <- derive_vas(fixture_totals_source(), fixture_totals_map(), VAS_CONFIG)
  result$wide$Airtime_Total_MonthlySpend[1] <- 999
  failures <- expect_output(check_internal_consistency(result$wide, result$audit))
  expect_true(any(grepl("Airtime_Total_MonthlySpend", failures)))
})

test_that("the consistency check catches a negative value", {
  result <- derive_vas(fixture_totals_source(), fixture_totals_map(), VAS_CONFIG)
  result$wide$TotalValueTransacted[1] <- -1
  failures <- expect_output(check_internal_consistency(result$wide, result$audit))
  expect_true(any(grepl("negative values", failures)))
})

test_that("the consistency check catches a broken spend identity", {
  result <- derive_vas(fixture_totals_source(), fixture_totals_map(), VAS_CONFIG)
  result$audit$MonthlySpend[result$audit$Status == "ok"][1] <- 12345
  failures <- expect_output(check_internal_consistency(result$wide, result$audit))
  expect_true(any(grepl("does not equal transactions", failures)))
})
