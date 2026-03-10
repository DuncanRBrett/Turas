# ==============================================================================
# TESTS: HTML REPORT (lib/html_report/)
# ==============================================================================

fixture_path <- file.path(
  dirname(dirname(testthat::test_path())),
  "fixtures", "synthetic_data", "generate_conjoint_test_data.R"
)
if (file.exists(fixture_path)) source(fixture_path, local = TRUE)


test_that("html guard validates conjoint_results structure", {
  if (!exists("validate_conjoint_html_inputs", mode = "function")) skip("validate_conjoint_html_inputs not loaded")

  # Valid input
  valid <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df()
  )
  result <- validate_conjoint_html_inputs(valid)
  expect_true(result$valid)

  # Invalid: not a list
  result2 <- validate_conjoint_html_inputs("not a list")
  expect_false(result2$valid)

  # Invalid: missing both utilities and importance
  result3 <- validate_conjoint_html_inputs(list(other = 1))
  expect_false(result3$valid)
})


test_that("html guard validates colour codes", {
  if (!exists("validate_conjoint_html_inputs", mode = "function")) skip("validate_conjoint_html_inputs not loaded")

  valid_input <- list(utilities = generate_utilities_df())

  # Valid colour
  result <- validate_conjoint_html_inputs(valid_input, list(brand_colour = "#1a2b3c"))
  expect_true(result$valid)

  # Invalid colour
  result2 <- validate_conjoint_html_inputs(valid_input, list(brand_colour = "red"))
  expect_false(result2$valid)

  # Invalid: too short
  result3 <- validate_conjoint_html_inputs(valid_input, list(brand_colour = "#abc"))
  expect_false(result3$valid)
})


test_that("html report generates valid HTML file", {
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  conjoint_results <- list(
    utilities  = generate_utilities_df(),
    importance = generate_importance_df(),
    model_fit  = list(
      method = "mlogit",
      mcfadden_r2 = 0.35,
      aic = 1234,
      bic = 1280,
      n_obs = 600,
      n_respondents = 100
    )
  )
  config <- list(
    project_name = "Test Project",
    brand_colour = "#2563eb",
    accent_colour = "#f59e0b"
  )

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  result <- generate_conjoint_html_report(conjoint_results, config, tmp_path)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp_path))

  # Check HTML structure
  html <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("<!DOCTYPE html>", html, fixed = TRUE))
  expect_true(grepl('turas-report-type.*conjoint', html))
  expect_true(grepl("</html>", html, fixed = TRUE))
})
