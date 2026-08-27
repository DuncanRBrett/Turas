# test-vas_structure.R
# The structure gate, wired into the suite: no gated file over 300 active
# lines, no function over 50. The same check runs standalone as
#   Rscript modules/vas/check_vas_structure.R
# Sourcing the script defines the functions only - main() is guarded by
# sys.nframe(), so nothing runs and nothing quits the suite.

source(file.path(VAS_PROJECT_ROOT, "check_vas_structure.R"))

test_that("count_active_lines ignores blanks, comments and closing braces", {
  lines <- c("x <- 1", "", "# a comment", "}", "})", "y <- 2  # trailing comment counts")
  expect_equal(count_active_lines(lines), 2L)
})

test_that("measure_functions finds top-level functions and sizes them", {
  lines <- c(
    "first <- function(x) {",
    "  a <- 1",
    "  b <- 2",
    "}",
    "",
    "second <- function(y) {",
    "  y",
    "}"
  )
  measured <- measure_functions(lines)
  expect_equal(measured$name, c("first", "second"))
  expect_equal(measured$active_lines, c(3L, 2L))
})

test_that("every gated file is under the limits", {
  breaches <- check_vas_structure(VAS_PROJECT_ROOT, quiet = TRUE)
  expect_equal(breaches, character(0))
})
