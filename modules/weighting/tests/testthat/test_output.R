# ==============================================================================
# TESTS: Output Functions (output.R)
# ==============================================================================

test_that("write_weighted_data writes CSV correctly", {
  data <- create_simple_survey(n = 50)
  data$weight <- runif(50, 0.5, 2.0)

  output_file <- file.path(tempdir(), "test_weighted.csv")
  on.exit(unlink(output_file))

  write_weighted_data(data, output_file, verbose = FALSE)

  expect_true(file.exists(output_file))

  reloaded <- read.csv(output_file)
  expect_equal(nrow(reloaded), 50)
  expect_true("weight" %in% names(reloaded))
})

test_that("write_weighted_data writes XLSX correctly", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 50)
  data$weight <- runif(50, 0.5, 2.0)

  output_file <- file.path(tempdir(), "test_weighted.xlsx")
  on.exit(unlink(output_file))

  write_weighted_data(data, output_file, verbose = FALSE)

  expect_true(file.exists(output_file))
})

test_that("write_weighted_data handles NULL path", {
  data <- create_simple_survey(n = 10)
  result <- write_weighted_data(data, NULL, verbose = FALSE)
  expect_null(result)
})

test_that("write_weighted_data rejects unsupported format", {
  data <- create_simple_survey(n = 10)
  expect_error(
    write_weighted_data(data, "test.json", verbose = FALSE),
    class = "turas_refusal"
  )
})

test_that("generate_weighting_report creates text report", {
  data <- create_simple_survey(n = 100)
  data$w1 <- runif(100, 0.5, 2.0)

  results <- list(
    data = data,
    config = list(
      general = list(project_name = "Test", data_file = "test.csv"),
      config_file = "test_config.xlsx",
      weight_specifications = data.frame(
        weight_name = "w1", method = "design",
        stringsAsFactors = FALSE
      )
    ),
    weight_names = "w1",
    weight_results = list(
      w1 = list(
        weights = data$w1,
        diagnostics = diagnose_weights(data$w1, "w1", verbose = FALSE)
      )
    )
  )

  output_file <- file.path(tempdir(), "test_report.txt")
  on.exit(unlink(output_file))

  generate_weighting_report(results, output_file, verbose = FALSE)
  expect_true(file.exists(output_file))

  content <- readLines(output_file)
  expect_true(any(grepl("TURAS WEIGHTING MODULE", content)))
})

test_that("generate_weighting_report creates Excel report", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 100)
  data$w1 <- runif(100, 0.5, 2.0)

  results <- list(
    data = data,
    config = list(
      general = list(project_name = "Test", data_file = "test.csv"),
      config_file = "test_config.xlsx",
      weight_specifications = data.frame(
        weight_name = "w1", method = "design",
        stringsAsFactors = FALSE
      )
    ),
    weight_names = "w1",
    weight_results = list(
      w1 = list(
        weights = data$w1,
        diagnostics = diagnose_weights(data$w1, "w1", verbose = FALSE)
      )
    )
  )

  output_file <- file.path(tempdir(), "test_report.xlsx")
  on.exit(unlink(output_file))

  generate_weighting_report(results, output_file, verbose = FALSE)
  expect_true(file.exists(output_file))
})

test_that("create_weight_summary_df returns correct structure", {
  data <- create_simple_survey(n = 100)
  data$w1 <- runif(100, 0.5, 2.0)

  results <- list(
    config = list(
      weight_specifications = data.frame(
        weight_name = "w1", method = "design",
        stringsAsFactors = FALSE
      )
    ),
    weight_names = "w1",
    weight_results = list(
      w1 = list(
        diagnostics = diagnose_weights(data$w1, "w1", verbose = FALSE)
      )
    )
  )

  summary_df <- create_weight_summary_df(results)

  expect_true(is.data.frame(summary_df))
  expect_equal(nrow(summary_df), 1)
  expect_true("weight_name" %in% names(summary_df))
  expect_true("effective_n" %in% names(summary_df))
  expect_true("design_effect" %in% names(summary_df))
})

test_that("print_run_summary runs without error", {
  data <- create_simple_survey(n = 50)
  data$w1 <- runif(50, 0.5, 2.0)

  results <- list(
    data = data,
    config = list(
      general = list(project_name = "Test"),
      weight_specifications = data.frame(
        weight_name = "w1", method = "rim",
        stringsAsFactors = FALSE
      )
    ),
    weight_names = "w1",
    weight_results = list(
      w1 = list(
        diagnostics = diagnose_weights(data$w1, "w1", verbose = FALSE)
      )
    ),
    output_file = NULL,
    diagnostics_file = NULL
  )

  expect_no_error(capture.output(print_run_summary(results)))
})
