# ==============================================================================
# TESTS: HTML report tables tolerate non-integer diagnostic values
# ==============================================================================
# Regression cover for a defect seen on a real run (Electrum VAS 2024, n = 1101,
# effective N = 1097.59): the summary and diagnostics tables used sprintf("%d")
# for effective N, which is a fractional double. R's sprintf errors on that, the
# tryCatch around each table swallowed it, and the run reported PASS while the
# HTML file shipped without those tables.
# ==============================================================================

# Weights whose effective N is deliberately NOT a whole number.
fractional_eff_n_weights <- function() {
  c(rep(0.7881, 200), rep(1.0, 700), rep(1.2251, 201))
}

test_that("diagnose_weights really does return a fractional effective N", {
  skip_if(!exists("diagnose_weights", mode = "function"),
          "diagnose_weights not available")

  diag <- diagnose_weights(fractional_eff_n_weights(), label = "w1", verbose = FALSE)
  eff_n <- diag$effective_sample$effective_n

  # If this ever becomes a whole number the tests below stop testing anything.
  expect_false(eff_n == round(eff_n))
})

test_that("build_summary_table renders with a fractional effective N", {
  skip_if(!exists("build_summary_table", mode = "function"),
          "build_summary_table not available")
  skip_if(!exists("diagnose_weights", mode = "function"),
          "diagnose_weights not available")

  diag <- diagnose_weights(fractional_eff_n_weights(), label = "w1", verbose = FALSE)
  details <- list(list(weight_name = "w1", method = "rim", diagnostics = diag))

  html <- build_summary_table(details)

  expect_type(html, "character")
  expect_true(nzchar(html))
  expect_true(grepl("<table", html, fixed = TRUE))
  # The row must be present, not an empty tbody from a swallowed error.
  expect_true(grepl("w1", html, fixed = TRUE))
  expect_true(grepl(as.character(round(diag$effective_sample$effective_n)),
                    html, fixed = TRUE))
})

test_that("build_diagnostics_table renders with a fractional effective N", {
  skip_if(!exists("build_diagnostics_table", mode = "function"),
          "build_diagnostics_table not available")
  skip_if(!exists("diagnose_weights", mode = "function"),
          "diagnose_weights not available")

  diag <- diagnose_weights(fractional_eff_n_weights(), label = "w1", verbose = FALSE)

  html <- build_diagnostics_table(diag)

  expect_type(html, "character")
  expect_true(nzchar(html))
  expect_true(grepl("Effective N", html, fixed = TRUE))
  expect_true(grepl(as.character(round(diag$effective_sample$effective_n)),
                    html, fixed = TRUE))
})

test_that("both tables survive a design effect of exactly 1 (all weights equal)", {
  skip_if(!exists("build_summary_table", mode = "function"),
          "build_summary_table not available")
  skip_if(!exists("diagnose_weights", mode = "function"),
          "diagnose_weights not available")

  diag <- diagnose_weights(rep(1, 500), label = "flat", verbose = FALSE)
  details <- list(list(weight_name = "flat", method = "rim", diagnostics = diag))

  expect_true(nzchar(build_summary_table(details)))
  expect_true(nzchar(build_diagnostics_table(diag)))
})

test_that("a failed table makes the report PARTIAL, not a silent PASS", {
  skip_if(!exists("generate_weighting_html_report", mode = "function"),
          "generate_weighting_html_report not available")
  skip_if_not_installed("htmltools")

  # Shadow one table builder so it fails, the way the sprintf defect did.
  original <- get("build_summary_table", envir = .GlobalEnv)
  assign("build_summary_table",
         function(...) stop("simulated table build failure"),
         envir = .GlobalEnv)
  on.exit(assign("build_summary_table", original, envir = .GlobalEnv), add = TRUE)

  n <- 100
  w <- runif(n, 0.5, 2)
  results <- list(
    data = data.frame(id = seq_len(n), w1 = w),
    weight_names = "w1",
    weight_results = list(w1 = list(
      weights = w,
      diagnostics = diagnose_weights(w, label = "w1", verbose = FALSE)
    )),
    config = list(
      general = list(project_name = "Partial Test"),
      weight_specifications = data.frame(weight_name = "w1", method = "rim",
                                         stringsAsFactors = FALSE)
    )
  )

  out <- file.path(tempdir(), "test_partial_report.html")
  on.exit(unlink(out), add = TRUE)

  res <- generate_weighting_html_report(results, out, config = list())

  expect_equal(res$status, "PARTIAL")
  expect_true(length(res$table_failures) >= 1)
  expect_true(any(grepl("simulated table build failure", res$table_failures)))
  # The file is still written, and the caller is still told where it is.
  expect_true(file.exists(out))
  expect_equal(res$output_file, out)
})

test_that("a clean report reports PASS with no table failures", {
  skip_if(!exists("generate_weighting_html_report", mode = "function"),
          "generate_weighting_html_report not available")
  skip_if_not_installed("htmltools")

  n <- 100
  w <- runif(n, 0.5, 2)
  results <- list(
    data = data.frame(id = seq_len(n), w1 = w),
    weight_names = "w1",
    weight_results = list(w1 = list(
      weights = w,
      diagnostics = diagnose_weights(w, label = "w1", verbose = FALSE)
    )),
    config = list(
      general = list(project_name = "Clean Test"),
      weight_specifications = data.frame(weight_name = "w1", method = "rim",
                                         stringsAsFactors = FALSE)
    )
  )

  out <- file.path(tempdir(), "test_clean_report.html")
  on.exit(unlink(out), add = TRUE)

  res <- generate_weighting_html_report(results, out, config = list())

  expect_equal(res$status, "PASS")
  expect_length(res$table_failures, 0)
})

test_that("build_summary_table skips weights with no diagnostics without erroring", {
  skip_if(!exists("build_summary_table", mode = "function"),
          "build_summary_table not available")

  html <- build_summary_table(list(list(weight_name = "w1", method = "rim",
                                        diagnostics = NULL)))

  expect_type(html, "character")
  expect_true(grepl("<table", html, fixed = TRUE))
})
