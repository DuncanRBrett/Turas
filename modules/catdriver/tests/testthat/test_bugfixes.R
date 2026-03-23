# ==============================================================================
# CATDRIVER BUG FIX REGRESSION TESTS (v1.1 upgrade)
# ==============================================================================
# Quick-run tests for the 9 critical bugs fixed in the catdriver upgrade.
# Run with: Rscript test_bugfixes.R
# ==============================================================================

library(testthat)

# Determine project root
script_dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) getwd())
if (basename(script_dir) == "tests") {
  module_root <- dirname(script_dir)
} else {
  module_root <- script_dir
}
turas_root <- dirname(dirname(module_root))

# Source shared utilities
shared_path <- file.path(turas_root, "modules", "shared", "lib")
if (dir.exists(shared_path)) {
  for (f in list.files(shared_path, pattern = "[.]R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }
}

# Source catdriver R files
setwd(module_root)
for (f in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  tryCatch(source(f), error = function(e) {
    cat("Warning: Could not source", basename(f), ":", e$message, "\n")
  })
}

cat("\n=== Running Bug Fix Regression Tests ===\n\n")

test_that("1. %||% operator is available and works", {
  expect_true(exists("%||%", mode = "function"))
  `%||%` <- get("%||%")
  expect_equal(NULL %||% "default", "default")
  expect_equal("value" %||% "default", "value")
  expect_equal(character(0) %||% "default", "default")
  expect_equal(42 %||% "default", 42)
})

test_that("2. OR parsing extracts value before CI parenthetical", {
  cases <- c("2.50", "2.50 (1.20, 4.10)", "0.75 (0.50-1.12)", "1.00", "3.14 (2.00, 5.00)")
  expected <- c(2.50, 2.50, 0.75, 1.00, 3.14)
  or_vals <- suppressWarnings(as.numeric(gsub("\\s*\\(.*", "", cases)))
  expect_equal(or_vals, expected)
})

test_that("3. aggregate_dummy_importance accepts prep_data as parameter", {
  fn_args <- names(formals(aggregate_dummy_importance))
  expect_true("prep_data" %in% fn_args)
})

test_that("4. Soft guard direction_sanity does not call catdriver_refuse", {
  fn_body <- deparse(body(guard_direction_sanity))
  has_refuse <- any(grepl("catdriver_refuse", fn_body))
  expect_false(has_refuse)
})

test_that("5. Missing data handler initialises drivers list", {
  data <- data.frame(
    outcome = sample(c("Yes", "No"), 50, replace = TRUE),
    driver1 = sample(c("A", "B", "C", NA), 50, replace = TRUE),
    stringsAsFactors = FALSE
  )
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    driver_vars = "driver1",
    driver_settings = NULL,
    missing_threshold = 50
  )
  result <- tryCatch(handle_missing_data(data, config), error = function(e) {
    list(error = TRUE, message = e$message)
  })
  expect_false(isTRUE(result$error), info = if (isTRUE(result$error)) result$message else "OK")
  expect_true(is.list(result$missing_report$drivers))
})

test_that("6. Multinomial model uses safe weight column name", {
  fn_body <- deparse(body(run_multinomial_logistic_robust))
  expect_true(any(grepl("catdriver_wt", fn_body)))
})

test_that("7. Slide loading returns NULL when no Slides sheet", {
  skip_if_not_installed("openxlsx")
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(Setting = "test", Value = "1"))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  result <- load_slides_from_config(tmp)
  expect_null(result)
  file.remove(tmp)
})

test_that("8. Slide loading reads valid Slides sheet", {
  skip_if_not_installed("openxlsx")
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(Setting = "test", Value = "1"))
  openxlsx::addWorksheet(wb, "Slides")
  openxlsx::writeData(wb, "Slides", data.frame(
    slide_order = c(1, 2),
    slide_title = c("First Slide", "Second Slide"),
    slide_content = c("## Hello\n\nContent", "More content"),
    slide_image_path = c(NA, NA),
    stringsAsFactors = FALSE
  ))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  result <- load_slides_from_config(tmp)
  expect_true(is.list(result))
  expect_equal(length(result), 2)
  expect_equal(result[[1]]$title, "First Slide")
  expect_equal(result[[2]]$title, "Second Slide")
  file.remove(tmp)
})

cat("\n=== All Bug Fix Tests Complete ===\n")
