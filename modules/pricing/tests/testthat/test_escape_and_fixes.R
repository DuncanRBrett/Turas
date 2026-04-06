# ==============================================================================
# Tests for Phase 5 fix code: formula injection escape + demand curve rename
# ==============================================================================

# The escape functions are defined inside write_pricing_output() so we
# replicate the inline fallback here for direct testing, matching the
# exact implementation in 06_output.R.

local_pricing_escape_cell <- function(x) {
  if (!is.character(x)) return(x)
  vapply(x, function(val) {
    if (is.na(val) || nchar(val) == 0L) return(val)
    first_char <- substr(val, 1, 1)
    if (first_char %in% c("=", "+", "-", "@", "\t", "\r", "\n")) {
      paste0("'", val)
    } else {
      val
    }
  }, character(1), USE.NAMES = FALSE)
}

local_pricing_escape_df <- function(df) {
  if (!is.data.frame(df)) return(df)
  nm <- names(df)
  names(df) <- local_pricing_escape_cell(nm)
  for (col in seq_along(df)) {
    if (is.character(df[[col]])) {
      df[[col]] <- local_pricing_escape_cell(df[[col]])
    }
  }
  df
}

# ==============================================================================
# pricing_escape_cell tests
# ==============================================================================

test_that("pricing_escape_cell prefixes injection characters with quote", {
  # OWASP CSV injection vectors
  expect_equal(local_pricing_escape_cell("=cmd|'/C calc'!A0"), "'=cmd|'/C calc'!A0")
  expect_equal(local_pricing_escape_cell("+cmd|'/C calc'!A0"), "'+cmd|'/C calc'!A0")
  expect_equal(local_pricing_escape_cell("-cmd|'/C calc'!A0"), "'-cmd|'/C calc'!A0")
  expect_equal(local_pricing_escape_cell("@SUM(A1:A10)"), "'@SUM(A1:A10)")
  expect_equal(local_pricing_escape_cell("\tcmd"), "'\tcmd")
  expect_equal(local_pricing_escape_cell("\rcmd"), "'\rcmd")
  expect_equal(local_pricing_escape_cell("\ncmd"), "'\ncmd")
})

test_that("pricing_escape_cell leaves safe strings unchanged", {
  expect_equal(local_pricing_escape_cell("Normal text"), "Normal text")
  expect_equal(local_pricing_escape_cell("$49.99"), "$49.99")
  expect_equal(local_pricing_escape_cell("100"), "100")
  expect_equal(local_pricing_escape_cell("Van Westendorp"), "Van Westendorp")
})

test_that("pricing_escape_cell handles NA and empty strings", {
  expect_true(is.na(local_pricing_escape_cell(NA_character_)))
  expect_equal(local_pricing_escape_cell(""), "")
})

test_that("pricing_escape_cell handles vectors", {
  input <- c("safe", "=IMPORTXML()", NA, "+SUM(A1)", "also safe")
  result <- local_pricing_escape_cell(input)
  expect_equal(result[1], "safe")
  expect_equal(result[2], "'=IMPORTXML()")
  expect_true(is.na(result[3]))
  expect_equal(result[4], "'+SUM(A1)")
  expect_equal(result[5], "also safe")
})

test_that("pricing_escape_cell passes through non-character types", {
  expect_equal(local_pricing_escape_cell(42), 42)
  expect_equal(local_pricing_escape_cell(TRUE), TRUE)
  expect_equal(local_pricing_escape_cell(3.14), 3.14)
})

# ==============================================================================
# pricing_escape_df tests
# ==============================================================================

test_that("pricing_escape_df escapes character column values", {
  df <- data.frame(
    metric = c("Revenue", "=SUM(A1)"),
    value = c(100, 200),
    stringsAsFactors = FALSE
  )
  result <- local_pricing_escape_df(df)
  expect_equal(result$metric[1], "Revenue")
  expect_equal(result$metric[2], "'=SUM(A1)")
  # Numeric column untouched
  expect_equal(result$value, c(100, 200))
})

test_that("pricing_escape_df escapes column names", {
  df <- data.frame(x = 1, y = 2)
  names(df) <- c("safe_name", "=bad_name")
  result <- local_pricing_escape_df(df)
  expect_equal(names(result)[1], "safe_name")
  expect_equal(names(result)[2], "'=bad_name")
})

test_that("pricing_escape_df handles empty data frame", {
  df <- data.frame(a = character(0), b = numeric(0))
  result <- local_pricing_escape_df(df)
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("a", "b"))
})

# ==============================================================================
# calculate_demand_curve column name test
# ==============================================================================

test_that("calculate_demand_curve output has weighted_n column (not effective_n)", {
  # Create minimal GG long-format data
  gg_data <- data.frame(
    respondent_id = rep(1:30, each = 3),
    price = rep(c(10, 20, 30), 30),
    response = c(rep(1, 30), rep(1, 20), rep(0, 10), rep(1, 10), rep(0, 20)),
    weight = rep(1, 90),
    stringsAsFactors = FALSE
  )

  result <- calculate_demand_curve(gg_data)

  expect_true("weighted_n" %in% names(result))
  expect_false("effective_n" %in% names(result))
  expect_equal(nrow(result), 3)
  # All weights are 1, so weighted_n should equal n_respondents
  expect_equal(result$weighted_n, result$n_respondents)
})
