# test-vas_frequency.R
# Known-answer tests for the frequency cascade. Each expected value follows
# directly from the conversion table in VAS_DERIVED_VARIABLES_PLAN.md section 2.

test_that("weekly buyers are converted at 52/12 weeks per month", {
  expect_equal(VAS_CONFIG$weeks_per_month, 52 / 12)
  result <- frequency_to_txn_scalar("Once a week or more often", "2", NA, NA, VAS_CONFIG)
  expect_equal(result$txn_per_month, 2 * 52 / 12)
  expect_equal(result$status, "ok")
})

test_that("a flat four-week month can be configured instead", {
  flat_config <- VAS_CONFIG
  flat_config$weeks_per_month <- 4
  result <- frequency_to_txn_scalar("Once a week or more often", "2", NA, NA, flat_config)
  expect_equal(result$txn_per_month, 8)
})

test_that("a few times a month is taken as given", {
  result <- frequency_to_txn_scalar("A few times in a month", NA, "3", NA, VAS_CONFIG)
  expect_equal(result$txn_per_month, 3)
  expect_equal(result$status, "ok")
})

test_that("once per month is one, with no follow-up question", {
  result <- frequency_to_txn_scalar("Once per month", NA, NA, NA, VAS_CONFIG)
  expect_equal(result$txn_per_month, 1)
  expect_equal(result$status, "ok")
})

test_that("an annual count divides by twelve", {
  # NOTE: VAS_DERIVED_VARIABLES_PLAN.md section 2 states the formula as
  # "Freq4 / 12" but then gives the worked example "4 a year -> 0.25". Those
  # two disagree: 4 / 12 is 0.333. The formula is implemented, because it is
  # unambiguous and matches config$months_per_year. 0.25 a month would be
  # THREE times a year, i.e. once every four months.
  expect_equal(frequency_to_txn_scalar("Less than once per month", NA, NA, "4",
                                       VAS_CONFIG)$txn_per_month, 4 / 12)
  expect_equal(frequency_to_txn_scalar("Less than once per month", NA, NA, "3",
                                       VAS_CONFIG)$txn_per_month, 0.25)
  expect_equal(frequency_to_txn_scalar("Less than once per month", NA, NA, "12",
                                       VAS_CONFIG)$txn_per_month, 1)
})

test_that("don't know on the annual count leaves the respondent missing", {
  expect_equal(VAS_CONFIG$dont_know_rule, "missing")
  result <- frequency_to_txn_scalar("Less than once per month", NA, NA, "Don't know", VAS_CONFIG)
  expect_true(is.na(result$txn_per_month))
  expect_equal(result$status, "dont_know")
})

test_that("a blank follow-up is missing rather than zero", {
  result <- frequency_to_txn_scalar("A few times in a month", NA, NA, NA, VAS_CONFIG)
  expect_true(is.na(result$txn_per_month))
  expect_equal(result$status, "dont_know")
})

test_that("a blank Freq1 means the respondent was never asked", {
  result <- frequency_to_txn_scalar(NA, NA, NA, NA, VAS_CONFIG)
  expect_true(is.na(result$txn_per_month))
  expect_equal(result$status, "not_asked")
  expect_equal(frequency_to_txn_scalar("", NA, NA, NA, VAS_CONFIG)$status, "not_asked")
})

test_that("an answer outside the four known options is flagged, not guessed", {
  result <- frequency_to_txn_scalar("Weekly", "2", NA, NA, VAS_CONFIG)
  expect_true(is.na(result$txn_per_month))
  expect_equal(result$status, "unrecognised")
})

test_that("the four Freq1 options match the survey exactly", {
  expect_equal(VAS_FREQ1_LEVELS, c(
    "Once a week or more often", "A few times in a month",
    "Once per month", "Less than once per month"
  ))
})

test_that("the vectorised converter returns one row per respondent", {
  result <- frequency_to_txn_per_month(
    freq1 = c("Once per month", "Less than once per month", NA),
    freq2 = c(NA, NA, NA), freq3 = c(NA, NA, NA), freq4 = c(NA, "6", NA),
    config = VAS_CONFIG
  )
  expect_equal(nrow(result), 3L)
  expect_equal(result$txn_per_month, c(1, 0.5, NA))
  expect_equal(result$status, c("ok", "ok", "not_asked"))
})

test_that("mismatched input lengths throw a typed error", {
  expect_error(
    frequency_to_txn_per_month(c("Once per month", "Once per month"), NA, NA, NA, VAS_CONFIG),
    class = "vas_length_mismatch"
  )
})

test_that("an empty input returns an empty frame", {
  result <- frequency_to_txn_per_month(character(0), character(0), character(0),
                                       character(0), VAS_CONFIG)
  expect_equal(nrow(result), 0L)
})

test_that("follow-up counts are read as numbers", {
  expect_equal(parse_frequency_count("7"), 7)
  expect_true(is.na(parse_frequency_count("Don't know")))
  expect_true(is.na(parse_frequency_count(NA)))
  expect_true(is.na(parse_frequency_count("")))
})
