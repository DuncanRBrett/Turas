# ==============================================================================
# TESTS: SHARED MINIMUM BASE / DISCLOSURE GATE
# ==============================================================================
#
# The rule is not new — every site compared a base against
# significance_min_base inline. This pins the boundary and the edge cases the
# inline form got wrong, so a migrating module can gate at analysis, render and
# export with the same predicate instead of three near-copies.
# ==============================================================================

root <- Sys.getenv("TURAS_ROOT", unset = "")
if (!nzchar(root)) {
  dir <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in 1:8) {
    if (file.exists(file.path(dir, "modules", "shared", "lib", "disclosure_gate.R"))) {
      root <- dir
      break
    }
    parent <- dirname(dir)
    if (parent == dir) break
    dir <- parent
  }
}
source(file.path(root, "modules", "shared", "lib", "disclosure_gate.R"), local = TRUE)

test_that("the boundary is inclusive: a base equal to the threshold passes", {
  expect_false(meets_min_base(29))
  expect_true(meets_min_base(30))
  expect_true(meets_min_base(31))
})

test_that("the threshold is configurable", {
  expect_false(meets_min_base(50, min_base = 100))
  expect_true(meets_min_base(100, min_base = 100))
  expect_true(meets_min_base(1, min_base = 1))
})

test_that("it is vectorised over base", {
  expect_equal(meets_min_base(c(10, 29, 30, 500)),
               c(FALSE, FALSE, TRUE, TRUE))
  expect_length(meets_min_base(numeric(0)), 0)
})

test_that("a missing or non-finite base does not pass", {
  # The inline form (n < min_base) returns NA here, and if (NA) is an error —
  # the old guards silently relied on their inputs never being absent.
  expect_false(meets_min_base(NA))
  expect_false(meets_min_base(NA_real_))
  expect_false(meets_min_base(NaN))
  expect_false(meets_min_base(Inf))
  expect_false(meets_min_base(-Inf))
  expect_equal(meets_min_base(c(30, NA, 40)), c(TRUE, FALSE, TRUE))
})

test_that("a negative or zero base does not pass", {
  expect_false(meets_min_base(0))
  expect_false(meets_min_base(-5))
})

test_that("it agrees with the inline comparison it replaces on ordinary input", {
  set.seed(3)
  bases <- c(0, 1, 29, 30, 31, sample(1:500, 200, replace = TRUE))
  for (mb in c(1, 30, 50, 100)) {
    expect_equal(meets_min_base(bases, mb), bases >= mb, info = paste("min_base", mb))
  }
})

test_that("a nonsense threshold is refused rather than silently accepted", {
  expect_error(meets_min_base(50, min_base = c(10, 20)))
  expect_error(meets_min_base(50, min_base = NA))
  expect_error(meets_min_base(50, min_base = "thirty"))
})

test_that("the tabs significance tests use the shared predicate", {
  src <- paste(readLines(file.path(root, "modules", "tabs", "lib", "weighting.R"),
                         warn = FALSE), collapse = "\n")
  expect_true(grepl("meets_min_base(c(n1, n2), min_base)", src, fixed = TRUE))
  expect_true(grepl("meets_min_base(c(eff_n1, eff_n2), min_base)", src, fixed = TRUE))
  expect_false(grepl("if (n1 < min_base || n2 < min_base)", src, fixed = TRUE))
})
