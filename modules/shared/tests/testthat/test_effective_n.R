# ==============================================================================
# GOLDEN TESTS: SHARED KISH EFFECTIVE SAMPLE SIZE
# ==============================================================================
#
# n_eff feeds standard errors, degrees of freedom and minimum-base gates. Four
# modules used to carry their own copy and three behaved differently, so two
# modules could disagree about how much information the same weighted sample
# carries. These tests pin the consolidated behaviour.
#
# The values below were computed from the canonical tabs implementation BEFORE
# consolidation. If a change moves any of them, it has moved a client number.
# ==============================================================================

root <- Sys.getenv("TURAS_ROOT", unset = "")
if (!nzchar(root)) {
  dir <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in 1:8) {
    if (file.exists(file.path(dir, "modules", "shared", "lib", "effective_n.R"))) {
      root <- dir
      break
    }
    parent <- dirname(dir)
    if (parent == dir) break
    dir <- parent
  }
}
source(file.path(root, "modules", "shared", "lib", "effective_n.R"), local = TRUE)

test_that("golden: fractional n_eff matches the pre-consolidation canonical values", {
  expect_equal(calculate_effective_n(c(1, 1, 3)), 25 / 11)
  expect_equal(calculate_effective_n(c(1, 1, 3)), 2.27272727272727, tolerance = 1e-12)
  expect_equal(calculate_effective_n(c(0.5, 1, 1.5, 2, 3)), 3.87878787878788, tolerance = 1e-12)
})

test_that("golden: integer n_eff matches what the confidence module used to return", {
  expect_identical(calculate_effective_n_int(c(1, 1, 3)), 2L)
  expect_identical(calculate_effective_n_int(c(0.5, 1, 1.5, 2, 3)), 4L)
  expect_identical(calculate_effective_n_int(numeric(0)), 0L)
  expect_identical(calculate_effective_n_int(rep(1, 40)), 40L)
})

test_that("unweighted samples lose nothing", {
  expect_equal(calculate_effective_n(rep(1, 40)), 40)
  expect_equal(calculate_effective_n(rep(1, 1)), 1)
})

test_that("the statistic is scale-invariant", {
  w <- c(0.5, 1, 1.5, 2, 3)
  expect_equal(calculate_effective_n(w), calculate_effective_n(w * 1000))
  expect_equal(calculate_effective_n(w), calculate_effective_n(w / 7))
})

test_that("n_eff never exceeds n, and equals n only when weights are equal", {
  set.seed(11)
  for (i in 1:20) {
    w <- runif(sample(5:200, 1), 0.1, 5)
    expect_lte(calculate_effective_n(w), length(w))
  }
  expect_equal(calculate_effective_n(rep(2.5, 30)), 30)
})

test_that("unusable weights are dropped, not counted", {
  # NA, infinite, zero and negative weights describe no respondent.
  expect_equal(calculate_effective_n(c(1, 1, 3, NA)), calculate_effective_n(c(1, 1, 3)))
  expect_equal(calculate_effective_n(c(1, 1, 3, 0)), calculate_effective_n(c(1, 1, 3)))
  expect_equal(calculate_effective_n(c(1, 1, 3, -2)), calculate_effective_n(c(1, 1, 3)))
  expect_equal(calculate_effective_n(c(1, 1, 3, Inf)), calculate_effective_n(c(1, 1, 3)))
  expect_equal(calculate_effective_n(numeric(0)), 0)
  expect_equal(calculate_effective_n(c(NA, NA)), 0)
})

test_that("very large weights do not overflow to NaN", {
  # maxdiff's own copy squared the raw weights and returned NaN here.
  expect_equal(calculate_effective_n(c(1e200, 2e200, 3e200)),
               calculate_effective_n(c(1, 2, 3)))
  expect_false(is.nan(calculate_effective_n(c(1e200, 2e200, 3e200))))
})

test_that("the integer form is the rounded fractional form", {
  set.seed(12)
  for (i in 1:20) {
    w <- runif(sample(5:100, 1), 0.2, 4)
    expect_identical(calculate_effective_n_int(w),
                     as.integer(round(calculate_effective_n(w))))
  }
})

# ---------------------------------------------------------------------------
# The modules must all resolve to this one implementation.
# ---------------------------------------------------------------------------

test_that("tabs, confidence and maxdiff all agree with the shared helper", {
  probe <- c(0.4, 0.9, 1.1, 1.6, 2.2, 3.3)
  expected_frac <- calculate_effective_n(probe)
  expected_int <- calculate_effective_n_int(probe)

  for (spec in list(
    list(file = file.path(root, "modules", "tabs", "lib", "weighting.R"),
         fn = "calculate_effective_n", want = expected_frac),
    list(file = file.path(root, "modules", "confidence", "R", "03_study_level.R"),
         fn = "calculate_effective_n_int", want = expected_int),
    list(file = file.path(root, "modules", "maxdiff", "R", "utils.R"),
         fn = "calculate_effective_n", want = expected_frac)
  )) {
    if (!file.exists(spec$file)) next
    env <- new.env(parent = globalenv())
    suppressWarnings(suppressMessages(
      try(sys.source(spec$file, envir = env), silent = TRUE)
    ))
    if (!exists(spec$fn, envir = env, inherits = TRUE)) next
    got <- get(spec$fn, envir = env)(probe)
    expect_equal(got, spec$want, info = basename(spec$file))
  }
})

test_that("no module still carries its own copy of the body", {
  copies <- c(
    file.path(root, "modules", "tabs", "lib", "weighting.R"),
    file.path(root, "modules", "confidence", "R", "03_study_level.R"),
    file.path(root, "modules", "maxdiff", "R", "utils.R")
  )
  for (f in copies) {
    if (!file.exists(f)) next
    src <- paste(readLines(f, warn = FALSE), collapse = "\n")
    expect_false(grepl("calculate_effective_n <- function(weights) {", src, fixed = TRUE),
                 info = basename(f))
  }
})
