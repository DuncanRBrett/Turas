# test-vas_amount_parser.R
# Known-answer tests for the free-text amount parser. Every expected value is
# hand-calculable from the input string.

test_that("a plain number parses to itself", {
  result <- parse_amount_scalar("150", VAS_CONFIG)
  expect_equal(result$value, 150)
  expect_equal(result$status, "ok")
})

test_that("the rand symbol is stripped in its usual forms", {
  expect_equal(parse_amount_scalar("R150", VAS_CONFIG)$value, 150)
  expect_equal(parse_amount_scalar("r 150", VAS_CONFIG)$value, 150)
  expect_equal(parse_amount_scalar("R.150", VAS_CONFIG)$value, 150)
  expect_equal(parse_amount_scalar("ZAR 150", VAS_CONFIG)$value, 150)
  expect_equal(parse_amount_scalar("150 rand", VAS_CONFIG)$value, 150)
})

test_that("a comma followed by two digits is a decimal mark", {
  # "150,00" is one hundred and fifty rand, not fifteen thousand
  expect_equal(parse_amount_scalar("150,00", VAS_CONFIG)$value, 150)
  expect_equal(parse_amount_scalar("1,50", VAS_CONFIG)$value, 1.5)
})

test_that("a separator followed by three digits is a thousands mark", {
  # rand amounts carry two decimals, so three trailing digits means thousands
  expect_equal(parse_amount_scalar("1,500", VAS_CONFIG)$value, 1500)
  expect_equal(parse_amount_scalar("1.500", VAS_CONFIG)$value, 1500)
  expect_equal(parse_amount_scalar("1 500", VAS_CONFIG)$value, 1500)
})

test_that("when both marks appear the last one is the decimal", {
  expect_equal(parse_amount_scalar("1,500.75", VAS_CONFIG)$value, 1500.75)
  expect_equal(parse_amount_scalar("1.500,75", VAS_CONFIG)$value, 1500.75)
  expect_equal(parse_amount_scalar("R1 234,56", VAS_CONFIG)$value, 1234.56)
})

test_that("repeated separators are thousands marks", {
  expect_equal(parse_amount_scalar("12.345.678", VAS_CONFIG)$status, "out_of_range")
  expect_equal(parse_amount_scalar("1,234,567", VAS_CONFIG)$status, "out_of_range")
})

test_that("surrounding words are ignored", {
  expect_equal(parse_amount_scalar("about 200", VAS_CONFIG)$value, 200)
  expect_equal(parse_amount_scalar("R200 approx", VAS_CONFIG)$value, 200)
  expect_equal(parse_amount_scalar("more or less 200", VAS_CONFIG)$value, 200)
})

test_that("a range collapses to its midpoint under the default rule", {
  expect_equal(VAS_CONFIG$range_rule, "midpoint")
  result <- parse_amount_scalar("150-200", VAS_CONFIG)
  expect_equal(result$value, 175)
  expect_equal(result$status, "range")
  expect_equal(parse_amount_scalar("150 to 200", VAS_CONFIG)$value, 175)
  expect_equal(parse_amount_scalar("R150 - R200", VAS_CONFIG)$value, 175)
})

test_that("the range rule is honoured when it is changed", {
  lower_config <- VAS_CONFIG
  lower_config$range_rule <- "lower"
  expect_equal(parse_amount_scalar("150-200", lower_config)$value, 150)

  upper_config <- VAS_CONFIG
  upper_config$range_rule <- "upper"
  expect_equal(parse_amount_scalar("150-200", upper_config)$value, 200)

  reject_config <- VAS_CONFIG
  reject_config$range_rule <- "reject"
  expect_equal(parse_amount_scalar("150-200", reject_config)$status, "unparseable")
})

test_that("a range given in the wrong order still reads correctly", {
  expect_equal(parse_amount_scalar("200-150", VAS_CONFIG)$value, 175)
})

test_that("blank answers are blank, not zero", {
  expect_equal(parse_amount_scalar(NA_character_, VAS_CONFIG)$status, "blank")
  expect_equal(parse_amount_scalar("", VAS_CONFIG)$status, "blank")
  expect_equal(parse_amount_scalar("   ", VAS_CONFIG)$status, "blank")
  expect_true(is.na(parse_amount_scalar("", VAS_CONFIG)$value))
})

test_that("a don't-know answer is missing, not zero", {
  for (text in c("dont know", "don't know", "Not Sure", "cant remember", "refused")) {
    result <- parse_amount_scalar(text, VAS_CONFIG)
    expect_equal(result$status, "unknown_word")
    expect_true(is.na(result$value))
  }
})

test_that("a word meaning nothing is a real zero", {
  for (text in c("none", "nothing", "nil", "Zero")) {
    result <- parse_amount_scalar(text, VAS_CONFIG)
    expect_equal(result$status, "zero_word")
    expect_equal(result$value, 0)
  }
})

test_that("a typed zero is this study's don't-know, not a zero spend", {
  # Interviewers are briefed to enter 0 when the respondent cannot put a
  # figure on the amount, so the number must not reach any mean.
  for (text in c("0", "R0", "0,00", "0.00", " 0 ")) {
    result <- parse_amount_scalar(text, VAS_CONFIG)
    expect_equal(result$status, "zero_dk")
    expect_true(is.na(result$value))
  }
})

test_that("a typed zero is a real zero when the study says so", {
  config <- VAS_CONFIG
  config$zero_amount_is_dont_know <- FALSE
  result <- parse_amount_scalar("0", config)
  expect_equal(result$status, "ok")
  expect_equal(result$value, 0)
})

test_that("reading a typed zero as don't-know leaves other amounts alone", {
  # The sentinel rule must not touch a real number, a range, or a word zero.
  expect_equal(parse_amount_scalar("150", VAS_CONFIG)$value, 150)
  expect_equal(parse_amount_scalar("0-200", VAS_CONFIG)$status, "range")
  expect_equal(parse_amount_scalar("none", VAS_CONFIG)$value, 0)
  expect_equal(parse_amount_scalar("R100,50", VAS_CONFIG)$value, 100.50)
})

test_that("a word answer is only recognised when no digits are present", {
  # "none" alone is zero, but "none, about 200" holds a real number
  expect_equal(parse_amount_scalar("none, about 200", VAS_CONFIG)$value, 200)
})

test_that("text with no number at all is flagged, not guessed", {
  result <- parse_amount_scalar("whatever it costs", VAS_CONFIG)
  expect_equal(result$status, "unparseable")
  expect_true(is.na(result$value))
})

test_that("values outside the configured range are rejected", {
  expect_equal(VAS_CONFIG$amount_max, 200000)
  result <- parse_amount_scalar("999999", VAS_CONFIG)
  expect_equal(result$status, "out_of_range")
  expect_true(is.na(result$value))
  expect_equal(parse_amount_scalar("200000", VAS_CONFIG)$status, "ok")
})

test_that("zero typed as a digit is governed by the study setting", {
  # Changed 23 July 2026. This engine used to read a typed 0 as a real zero
  # spend. VAS 2026 interviewers are briefed to enter 0 when the respondent
  # cannot put a figure on the amount, so on this study it means don't-know.
  # The behaviour is a named setting rather than a hard rule, because a study
  # without that briefing needs the old reading.
  expect_true(VAS_CONFIG$zero_amount_is_dont_know)
  expect_true(is.na(parse_amount_scalar("0", VAS_CONFIG)$value))

  other_study <- VAS_CONFIG
  other_study$zero_amount_is_dont_know <- FALSE
  expect_equal(parse_amount_scalar("0", other_study)$value, 0)
})

test_that("the vectorised wrapper returns one row per input", {
  result <- parse_amount(c("R150", "dont know", "", "150-200"), VAS_CONFIG)
  expect_equal(nrow(result), 4L)
  expect_equal(result$value, c(150, NA, NA, 175))
  expect_equal(result$status, c("ok", "unknown_word", "blank", "range"))
})

test_that("the vectorised wrapper handles an empty input", {
  result <- parse_amount(character(0), VAS_CONFIG)
  expect_equal(nrow(result), 0L)
  expect_equal(names(result), c("value", "status"))
})

test_that("separator resolution is exercised directly", {
  expect_equal(resolve_amount_separators("1500"), 1500)
  expect_equal(resolve_amount_separators("1,500"), 1500)
  expect_equal(resolve_amount_separators("150,00"), 150)
  expect_true(is.na(resolve_amount_separators(NA_character_)))
})
