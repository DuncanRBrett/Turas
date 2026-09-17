# ==============================================================================
# KEYDRIVER - NECESSARY CONDITION ANALYSIS (review H7)
# ==============================================================================
# The July review marked this SUSPECTED because the package was assumed absent
# and the code was only read. It is installed, so this file executes it.
#
# The call was NCA::nca_analysis(d[[drv]], d[[outcome_var]], ...). The package's
# signature is nca_analysis(data, x, y, ...), so those two vectors bound to
# `data` and `x` with no `y`, and the call failed for every driver on every run.
# The tryCatch turned each failure into NA, the classifier read NA as
# not-significant, and every driver in every study came back "Not Necessary"
# under a clean PASS.
# ==============================================================================

skip_if_not(file.exists(file.path(module_dir, "R", "10_nca.R")), "10_nca.R not present")
skip_if_not_installed("NCA")
suppressWarnings(try(source(file.path(module_dir, "R", "10_nca.R")), silent = TRUE))
skip_if(!exists("run_nca_analysis", mode = "function"), "NCA runner not loaded")

# A driver with a genuine ceiling: Y can never exceed Need by much, so a high Y
# requires a high Need. That is what necessity means.
nca_fixture <- function(n = 150, seed = 4) {
  set.seed(seed)
  d <- data.frame(Need = runif(n, 1, 7))
  d$Y <- pmin(d$Need + runif(n, -1, 3), 7)
  d
}

test_that("the old positional call cannot work (H7)", {
  d <- nca_fixture(n = 60)
  # Kept so the reason this file exists cannot be lost: the first two
  # positional arguments are data and x, so the outcome landed in x and y was
  # never supplied.
  expect_equal(names(formals(NCA::nca_analysis))[1:3], c("data", "x", "y"))
  err <- tryCatch({
    suppressWarnings(NCA::nca_analysis(d[["Need"]], d[["Y"]], ceilings = "ce_fdh"))
    "NO ERROR"
  }, error = function(e) conditionMessage(e))
  expect_false(identical(err, "NO ERROR"))
})

test_that("a driver with a real ceiling is found necessary (H7)", {
  d <- nca_fixture()
  cfg <- list(outcome_var = "Y", driver_vars = "Need",
              settings = list(nca_test_reps = 30))
  invisible(capture.output(r <- suppressWarnings(run_nca_analysis(d, cfg))))
  expect_equal(r$status, "PASS")
  s <- r$result$nca_summary
  expect_equal(nrow(s), 1)
  # Before the fix every one of these was NA or the fallback constant.
  expect_false(is.na(s$NCA_Effect_Size[1]))
  expect_gt(s$NCA_Effect_Size[1], 0)
  expect_false(is.na(s$NCA_p_value[1]))
  expect_true(s$Is_Necessary[1])
  expect_equal(s$Classification[1], "Necessary Condition")
  expect_equal(r$result$test_replications, 30L)
})

test_that("without a permutation test the column says so, rather than Not Necessary (H7)", {
  d <- nca_fixture()
  cfg <- list(outcome_var = "Y", driver_vars = "Need",
              settings = list(nca_test_reps = 0))
  invisible(capture.output(r <- suppressWarnings(run_nca_analysis(d, cfg))))
  s <- r$result$nca_summary
  expect_false(is.na(s$NCA_Effect_Size[1]))
  expect_false(s$Is_Necessary[1])
  # "Not Necessary" would be a finding. There was no test, so it is not one.
  expect_equal(s$Classification[1], "No significance test")
})

test_that("a driver the package cannot analyse degrades the run (H7)", {
  # Pure noise against the outcome makes NCA's own ceiling routine fail with
  # a subscript error. That is a driver not analysed, not a finding of no
  # necessity, so the run is PARTIAL and names it.
  set.seed(4)
  n <- 150
  d <- data.frame(Need = runif(n, 1, 7), Noise = runif(n, 1, 7))
  d$Y <- pmin(d$Need + runif(n, -1, 3), 7)
  cfg <- list(outcome_var = "Y", driver_vars = c("Need", "Noise"),
              settings = list(nca_test_reps = 20))
  invisible(capture.output(r <- suppressWarnings(run_nca_analysis(d, cfg))))
  expect_equal(r$status, "PARTIAL")
  expect_true("Noise" %in% r$result$drivers_failed)
  expect_equal(r$result$n_analysed, 1)
  expect_match(r$result$message %||% r$message, "could not be analysed")
  # The failed driver is reported as not analysed, not as not necessary.
  s <- r$result$nca_summary
  expect_equal(s$Classification[s$Driver == "Noise"], "Not analysed")
})

test_that("bottleneck levels are asked of the right function (H7)", {
  src <- readLines(file.path(module_dir, "R", "10_nca.R"))
  # nca_output() has no bottleneck.y parameter; nca_analysis() does. The old
  # code passed it to the former, so every bottleneck came back NA.
  expect_false(any(grepl("nca_output(nca_out, bottleneck.y", src, fixed = TRUE)))
  expect_false("bottleneck.y" %in% names(formals(NCA::nca_output)))
  expect_true("bottleneck.y" %in% names(formals(NCA::nca_analysis)))
  expect_true(any(grepl("bottleneck.y = \"percentage.range\"", src, fixed = TRUE)))
})
