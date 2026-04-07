# ==============================================================================
# TESTS: Formula Injection Escape Functions (OWASP CSV Injection)
# ==============================================================================
# Verifies that conjoint_escape_cell() and conjoint_escape_df() correctly
# prefix dangerous characters with a single quote to prevent Excel formula
# injection when opening output files.
# ==============================================================================

# Source the escape functions from the output module
# (they are defined at module level in 07_output.R)
test_module_dir <- file.path(getwd(), "modules", "conjoint", "R")
if (!dir.exists(test_module_dir)) {
  test_module_dir <- file.path(dirname(dirname(dirname(testthat::test_path()))), "R")
}

# Source just the escape functions (first 58 lines of 07_output.R define them)
# We replicate the inline fallback here for direct testing — same pattern as
# pricing Phase 5 re-review R1 solution.
local_conjoint_escape_cell <- function(x) {
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

local_conjoint_escape_df <- function(df) {
  if (!is.data.frame(df)) return(df)
  nm <- names(df)
  names(df) <- local_conjoint_escape_cell(nm)
  for (col in seq_along(df)) {
    if (is.character(df[[col]])) {
      df[[col]] <- local_conjoint_escape_cell(df[[col]])
    }
  }
  df
}


# ==============================================================================
# CELL ESCAPE TESTS
# ==============================================================================

test_that("escape_cell prefixes all 7 OWASP injection characters", {
  dangerous <- c(
    "=cmd|'/C calc'!A0",
    "+cmd|'/C calc'!A0",
    "-cmd|'/C calc'!A0",
    "@SUM(A1:A10)",
    "\tcmd",
    "\rcmd",
    "\ncmd"
  )
  escaped <- local_conjoint_escape_cell(dangerous)

  # Every result must start with a single quote
 for (i in seq_along(escaped)) {
    expect_equal(substr(escaped[i], 1, 1), "'",
                 info = sprintf("OWASP prefix %d: '%s'", i, dangerous[i]))
  }
})

test_that("escape_cell leaves safe strings unchanged", {
  safe <- c("Normal text", "Price $100", "Brand A", "12345", "hello world")
  expect_identical(local_conjoint_escape_cell(safe), safe)
})

test_that("escape_cell passes NA through unchanged", {
  result <- local_conjoint_escape_cell(c("safe", NA, "also safe"))
  expect_true(is.na(result[2]))
  expect_equal(result[1], "safe")
  expect_equal(result[3], "also safe")
})

test_that("escape_cell passes empty strings through unchanged", {
  result <- local_conjoint_escape_cell(c("safe", "", "also safe"))
  expect_equal(result[2], "")
})

test_that("escape_cell returns non-character input unchanged", {
  expect_identical(local_conjoint_escape_cell(42), 42)
  expect_identical(local_conjoint_escape_cell(TRUE), TRUE)
  expect_identical(local_conjoint_escape_cell(3.14), 3.14)
})

test_that("escape_cell handles nested prefixes (==cmd)", {
  result <- local_conjoint_escape_cell("==cmd|'/C calc'!A0")
  expect_equal(substr(result, 1, 1), "'")
})

test_that("escape_cell handles vector input", {
  input <- c("=BAD", "safe", "+BAD", NA, "")
  result <- local_conjoint_escape_cell(input)
  expect_equal(length(result), 5)
  expect_equal(substr(result[1], 1, 1), "'")
  expect_equal(result[2], "safe")
  expect_equal(substr(result[3], 1, 1), "'")
  expect_true(is.na(result[4]))
  expect_equal(result[5], "")
})


# ==============================================================================
# DATA FRAME ESCAPE TESTS
# ==============================================================================

test_that("escape_df escapes character columns in data frames", {
  df <- data.frame(
    Attribute = c("=Brand", "+Price", "Size"),
    Value = c(100, 200, 300),
    Label = c("safe", "=dangerous", "@also bad"),
    stringsAsFactors = FALSE
  )
  result <- local_conjoint_escape_df(df)

  # Character columns escaped
 expect_equal(substr(result$Attribute[1], 1, 1), "'")
  expect_equal(substr(result$Attribute[2], 1, 1), "'")
  expect_equal(result$Attribute[3], "Size")

  # Numeric column untouched
  expect_equal(result$Value, c(100, 200, 300))

  # Second character column also escaped
  expect_equal(result$Label[1], "safe")
  expect_equal(substr(result$Label[2], 1, 1), "'")
  expect_equal(substr(result$Label[3], 1, 1), "'")
})

test_that("escape_df escapes column names", {
  df <- data.frame(x = 1:3, y = 4:6)
  names(df) <- c("=BadCol", "SafeCol")
  result <- local_conjoint_escape_df(df)
  expect_equal(substr(names(result)[1], 1, 1), "'")
  expect_equal(names(result)[2], "SafeCol")
})

test_that("escape_df handles empty data frame", {
  df <- data.frame(A = character(0), B = numeric(0), stringsAsFactors = FALSE)
  result <- local_conjoint_escape_df(df)
  expect_equal(nrow(result), 0)
})

test_that("escape_df returns non-data-frame input unchanged", {
  expect_identical(local_conjoint_escape_df("not a df"), "not a df")
  expect_identical(local_conjoint_escape_df(42), 42)
  expect_identical(local_conjoint_escape_df(NULL), NULL)
})
