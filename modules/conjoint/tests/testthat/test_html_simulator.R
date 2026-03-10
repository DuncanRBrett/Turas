# ==============================================================================
# TESTS: HTML SIMULATOR (lib/html_simulator/)
# ==============================================================================

fixture_path <- file.path(
  dirname(dirname(testthat::test_path())),
  "fixtures", "synthetic_data", "generate_conjoint_test_data.R"
)
if (file.exists(fixture_path)) source(fixture_path, local = TRUE)


test_that("simulator guard validates utilities", {
  if (!exists("validate_simulator_inputs", mode = "function")) skip("validate_simulator_inputs not loaded")

  valid_utils <- generate_utilities_df()
  config <- list(attribute_levels = list(
    Brand = c("Alpha", "Beta", "Gamma"),
    Size  = c("Small", "Medium", "Large"),
    Price = c("$10", "$20", "$30")
  ))

  result <- validate_simulator_inputs(valid_utils, config)
  expect_true(result$valid)

  # Invalid: missing columns
  bad_utils <- data.frame(x = 1, y = 2)
  result2 <- validate_simulator_inputs(bad_utils, config)
  expect_false(result2$valid)
})


test_that("simulator data transformer builds JSON-ready structure", {
  if (!exists("build_simulator_data", mode = "function")) skip("build_simulator_data not loaded")

  utils <- generate_utilities_df(with_price = TRUE)
  importance <- generate_importance_df(with_price = TRUE)
  config <- list(
    project_name = "Test",
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size  = c("Small", "Medium", "Large"),
      Price = c("$10", "$20", "$30")
    ),
    simulation_method = "logit"
  )

  sim_data <- build_simulator_data(utils, importance, model_result = NULL, config)

  expect_is(sim_data, "list")
  expect_true("attributes" %in% names(sim_data))
  expect_true("utilities" %in% names(sim_data))
  expect_true(length(sim_data$attributes) > 0)
})


test_that("simulator generates valid HTML file", {
  if (!exists("generate_conjoint_html_simulator", mode = "function")) skip("generate_conjoint_html_simulator not loaded")

  utils <- generate_utilities_df(with_price = TRUE)
  importance <- generate_importance_df(with_price = TRUE)
  config <- list(
    project_name = "Test Simulator",
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size  = c("Small", "Medium", "Large"),
      Price = c("$10", "$20", "$30")
    ),
    simulation_method = "logit",
    brand_colour = "#2563eb"
  )

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  result <- generate_conjoint_html_simulator(utils, importance, NULL, config, tmp_path)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp_path))

  # Check HTML structure
  html <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("<!DOCTYPE html>", html, fixed = TRUE))
  expect_true(grepl("sim-data", html, fixed = TRUE))  # JSON data container
  expect_true(grepl("SimEngine", html, fixed = TRUE))  # JS engine
  expect_true(grepl("</html>", html, fixed = TRUE))
})


test_that("simulator JS files have valid syntax", {
  js_dir <- file.path(
    dirname(dirname(dirname(testthat::test_path()))),
    "lib", "html_simulator", "js"
  )

  if (!dir.exists(js_dir)) skip("JS directory not found")

  js_files <- list.files(js_dir, pattern = "\\.js$", full.names = TRUE)
  if (length(js_files) == 0) skip("No JS files found")

  node_path <- "/usr/local/bin/node"
  if (!file.exists(node_path)) skip("node not found at /usr/local/bin/node")

  for (f in js_files) {
    result <- system2(node_path, args = c("--check", f), stdout = TRUE, stderr = TRUE)
    exit_code <- attr(result, "status") %||% 0L
    expect_equal(exit_code, 0L, info = sprintf("JS syntax error in %s: %s", basename(f), paste(result, collapse = "\n")))
  }
})
