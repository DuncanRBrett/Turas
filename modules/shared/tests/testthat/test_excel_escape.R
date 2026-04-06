# ==============================================================================
# TESTS: turas_excel_escape (Formula Injection Protection)
# ==============================================================================
# Covers the shared turas_excel_escape.R and the inline fallback regex
# used in keydriver/R/04_output.R and catdriver/R/06_output.R.
#
# Reference: OWASP CSV Injection Prevention Cheat Sheet
# ==============================================================================

# Source the shared escape utility
local({
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) {
    # Try to find it relative to test file location
    possible_roots <- c(
      file.path(getwd(), "..", "..", "..", ".."),
      file.path(getwd(), "..", ".."),
      getwd()
    )
    for (root in possible_roots) {
      escape_path <- file.path(root, "modules", "shared", "lib", "turas_excel_escape.R")
      if (file.exists(escape_path)) {
        source(escape_path)
        return(invisible(NULL))
      }
    }
  } else {
    source(file.path(turas_root, "modules", "shared", "lib", "turas_excel_escape.R"))
  }
})


# ==============================================================================
# INLINE FALLBACK (must match shared function for all OWASP vectors)
# ==============================================================================
# This is the exact regex from keydriver/R/04_output.R and catdriver/R/06_output.R.
# Tests ensure it stays in sync with the shared function.

.inline_fallback_escape <- function(x) {
  if (!is.character(x)) return(x)
  dangerous <- c("=", "+", "-", "@", "\t", "\r", "\n")
  vapply(x, function(v) {
    if (is.na(v) || nchar(v) == 0) return(v)
    if (substr(v, 1, 1) %in% dangerous) paste0("'", v) else v
  }, character(1), USE.NAMES = FALSE)
}


# ==============================================================================
# SHARED FUNCTION: turas_excel_escape
# ==============================================================================

test_that("turas_excel_escape prefixes = with single quote", {
  expect_equal(turas_excel_escape("=SUM(A1:A10)"), "'=SUM(A1:A10)")
  expect_equal(turas_excel_escape("=cmd|'/C calc'!A0"), "'=cmd|'/C calc'!A0")
  expect_equal(turas_excel_escape("=IMPORTXML(...)"), "'=IMPORTXML(...)")
})

test_that("turas_excel_escape prefixes + with single quote", {
  expect_equal(turas_excel_escape("+1-2"), "'+1-2")
  expect_equal(turas_excel_escape("+cmd|'/C calc'!A0"), "'+cmd|'/C calc'!A0")
})

test_that("turas_excel_escape prefixes - with single quote", {
  expect_equal(turas_excel_escape("-1+2"), "'-1+2")
  expect_equal(turas_excel_escape("-cmd|'/C calc'!A0"), "'-cmd|'/C calc'!A0")
})

test_that("turas_excel_escape prefixes @ with single quote", {
  expect_equal(turas_excel_escape("@SUM(A1:A10)"), "'@SUM(A1:A10)")
})

test_that("turas_excel_escape prefixes tab with single quote", {
  expect_equal(turas_excel_escape("\t=SUM(A1)"), "'\t=SUM(A1)")
  expect_equal(turas_excel_escape("\tAnything"), "'\tAnything")
})

test_that("turas_excel_escape prefixes CR with single quote", {
  expect_equal(turas_excel_escape("\r=SUM(A1)"), "'\r=SUM(A1)")
})

test_that("turas_excel_escape prefixes LF with single quote", {
  expect_equal(turas_excel_escape("\n=SUM(A1)"), "'\n=SUM(A1)")
  expect_equal(turas_excel_escape("\n+cmd|'/C calc'!A0"), "'\n+cmd|'/C calc'!A0")
})

test_that("turas_excel_escape leaves safe strings unchanged", {
  expect_equal(turas_excel_escape("Normal text"), "Normal text")
  expect_equal(turas_excel_escape("Hello world"), "Hello world")
  expect_equal(turas_excel_escape("Q1_satisfaction"), "Q1_satisfaction")
  expect_equal(turas_excel_escape("123abc"), "123abc")
  expect_equal(turas_excel_escape(""), "")
})

test_that("turas_excel_escape passes through non-character types", {
  expect_equal(turas_excel_escape(42), 42)
  expect_equal(turas_excel_escape(3.14), 3.14)
  expect_equal(turas_excel_escape(TRUE), TRUE)
  expect_equal(turas_excel_escape(NULL), NULL)
})

test_that("turas_excel_escape handles NA values", {
  expect_true(is.na(turas_excel_escape(NA_character_)))
})

test_that("turas_excel_escape is vectorized", {
  input <- c("=SUM(A1)", "Normal", "+cmd", NA, "@test")
  result <- turas_excel_escape(input)
  expect_equal(result[1], "'=SUM(A1)")
  expect_equal(result[2], "Normal")
  expect_equal(result[3], "'+cmd")
  expect_true(is.na(result[4]))
  expect_equal(result[5], "'@test")
})

test_that("turas_excel_escape handles empty vector", {
  expect_equal(turas_excel_escape(character(0)), character(0))
})


# ==============================================================================
# SHARED FUNCTION: turas_excel_is_dangerous
# ==============================================================================

test_that("turas_excel_is_dangerous detects all prefix characters", {
  expect_true(turas_excel_is_dangerous("=SUM(A1)"))
  expect_true(turas_excel_is_dangerous("+1"))
  expect_true(turas_excel_is_dangerous("-1"))
  expect_true(turas_excel_is_dangerous("@test"))
  expect_true(turas_excel_is_dangerous("\ttab"))
  expect_true(turas_excel_is_dangerous("\rcr"))
  expect_true(turas_excel_is_dangerous("\nlf"))
})

test_that("turas_excel_is_dangerous returns FALSE for safe values", {
  expect_false(turas_excel_is_dangerous("Normal"))
  expect_false(turas_excel_is_dangerous(""))
  expect_false(turas_excel_is_dangerous(42))
  expect_false(turas_excel_is_dangerous(NA))
  expect_false(turas_excel_is_dangerous(NULL))
})


# ==============================================================================
# SHARED FUNCTION: turas_excel_escape_df
# ==============================================================================

test_that("turas_excel_escape_df escapes character columns in a data frame", {
  df <- data.frame(
    name = c("Alice", "=cmd|'/C calc'!A0", "Bob"),
    value = c(1, 2, 3),
    note = c("safe", "+danger", "safe"),
    stringsAsFactors = FALSE
  )

  result <- turas_excel_escape_df(df)

  expect_equal(result$name[1], "Alice")
  expect_equal(result$name[2], "'=cmd|'/C calc'!A0")
  expect_equal(result$name[3], "Bob")
  expect_equal(result$note[2], "'+danger")
  # Numeric column unchanged
  expect_equal(result$value, c(1, 2, 3))
})

test_that("turas_excel_escape_df respects column filter", {
  df <- data.frame(
    name = c("=evil"),
    note = c("=also_evil"),
    stringsAsFactors = FALSE
  )

  result <- turas_excel_escape_df(df, columns = "name")
  expect_equal(result$name, "'=evil")
  expect_equal(result$note, "=also_evil")  # not in column filter
})

test_that("turas_excel_escape_df handles empty data frame", {
  df <- data.frame(x = character(0), stringsAsFactors = FALSE)
  result <- turas_excel_escape_df(df)
  expect_equal(nrow(result), 0)
})


# ==============================================================================
# INLINE FALLBACK: consistency with shared function
# ==============================================================================

test_that("inline fallback matches shared function for all OWASP vectors", {
  # All dangerous prefixes from .EXCEL_FORMULA_PREFIXES
  dangerous_inputs <- c(
    "=SUM(A1:A10)",
    "+cmd|'/C calc'!A0",
    "-1+2",
    "@SUM(A1)",
    "\t=SUM(A1)",
    "\r=SUM(A1)",
    "\n=SUM(A1)"
  )

  for (input in dangerous_inputs) {
    shared_result <- turas_excel_escape(input)
    fallback_result <- .inline_fallback_escape(input)
    expect_equal(
      fallback_result, shared_result,
      info = sprintf("Mismatch for input starting with '%s'",
                     chartr("\t\r\n", "TRN", substr(input, 1, 1)))
    )
  }
})

test_that("inline fallback leaves safe strings unchanged", {
  safe_inputs <- c("Normal text", "Q1_satisfaction", "123", "", "Hello world")
  for (input in safe_inputs) {
    expect_equal(.inline_fallback_escape(input), input, info = input)
  }
})

test_that("inline fallback passes through non-character types", {
  expect_equal(.inline_fallback_escape(42), 42)
  expect_equal(.inline_fallback_escape(3.14), 3.14)
  expect_equal(.inline_fallback_escape(TRUE), TRUE)
})

test_that("inline fallback is vectorized", {
  input <- c("=evil", "safe", "+danger")
  result <- .inline_fallback_escape(input)
  expect_equal(result, c("'=evil", "safe", "'+danger"))
})

test_that("inline fallback handles newline injection vector", {
  # The re-review R3 finding: \n must be escaped
  input <- "\n=cmd|'/C calc'!A0"
  result <- .inline_fallback_escape(input)
  expect_true(startsWith(result, "'"))
  expect_equal(result, turas_excel_escape(input))
})


# ==============================================================================
# turas_write_data_safe (safe writeData wrapper)
# ==============================================================================

test_that("turas_write_data_safe escapes data frame before writing", {
  skip_if_not_installed("openxlsx")

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Test")

  df <- data.frame(
    driver = c("=IMPORTXML()", "safe_driver"),
    value = c(1.5, 2.5),
    stringsAsFactors = FALSE
  )

  turas_write_data_safe(wb, "Test", df)

  # Read back the data
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- openxlsx::read.xlsx(tmp, sheet = "Test")
  # The escaped value should have a leading single quote
  expect_true(startsWith(result$driver[1], "'"))
  expect_equal(result$driver[2], "safe_driver")
})
