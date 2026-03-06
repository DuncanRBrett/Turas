# ==============================================================================
# TESTS: Config Loader (config_loader.R)
# ==============================================================================

test_that("load_weighting_config loads valid design config", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey()
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_design_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  expect_true(is.list(config))
  expect_true("general" %in% names(config))
  expect_true("weight_specifications" %in% names(config))
  expect_equal(config$general$project_name, "Test Design Weights")
})

test_that("load_weighting_config loads valid rim config", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey()
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_rim_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  expect_true(is.list(config))
  expect_true("rim_targets" %in% names(config))
})

test_that("load_weighting_config loads combined config", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey()
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_combined_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  expect_true(!is.null(config$design_targets))
  expect_true(!is.null(config$rim_targets))
  expect_equal(nrow(config$weight_specifications), 2)
})

test_that("load_weighting_config rejects missing config file", {
  expect_error(
    load_weighting_config("/nonexistent/config.xlsx", verbose = FALSE),
    class = "turas_refusal"
  )
})

test_that("load_weighting_config rejects config missing Weight_Specifications", {
  skip_if_not_installed("openxlsx")

  config_path <- create_bad_config_missing_sheet()
  on.exit(unlink(config_path))

  expect_error(
    load_weighting_config(config_path, verbose = FALSE),
    class = "turas_refusal"
  )
})

test_that("config resolves relative data file paths", {
  skip_if_not_installed("openxlsx")

  # Create data in same directory as config
  tmp_dir <- tempdir()
  data <- create_simple_survey()
  data_path <- file.path(tmp_dir, "survey_data.csv")
  write.csv(data, data_path, row.names = FALSE)
  on.exit(unlink(data_path))

  config_path <- create_design_weight_config(
    data_path = "survey_data.csv",  # relative path
    output_dir = tmp_dir
  )
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  expect_true(!is.null(config$general$data_file_resolved))
  expect_true(file.exists(config$general$data_file_resolved))
})

test_that("config parses weight specifications correctly", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey()
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_design_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  specs <- config$weight_specifications
  expect_true(is.data.frame(specs))
  expect_true("weight_name" %in% names(specs))
  expect_true("method" %in% names(specs))
  expect_equal(specs$weight_name[1], "design_weight")
  expect_equal(tolower(specs$method[1]), "design")
})

test_that("config stores config file path", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey()
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_design_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  expect_true(!is.null(config$config_file))
})

test_that("get_advanced_setting returns defaults for missing settings", {
  skip_if(!exists("get_advanced_setting", mode = "function"),
          "get_advanced_setting not available")

  # With NULL config$advanced_settings, should return default
  empty_config <- list(advanced_settings = NULL)
  result <- get_advanced_setting(empty_config, "w1", "max_iterations", default = 500)
  expect_equal(result, 500)
})

test_that("load_weighting_config parses Notes sheet", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 100)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_config_with_notes(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  expect_true(!is.null(config$notes))
  expect_true(is.data.frame(config$notes))
  expect_equal(nrow(config$notes), 4)
  expect_true("Section" %in% names(config$notes))
  expect_true("Note" %in% names(config$notes))
  expect_true("Assumptions" %in% config$notes$Section)
  expect_true("Methodology" %in% config$notes$Section)
})

test_that("config without Notes sheet has NULL notes", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 100)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_design_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  expect_null(config$notes)
})

test_that("load_weighting_config loads cell weight config with Cell_Targets", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_cell_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  expect_true(is.list(config))
  expect_true(!is.null(config$cell_targets))
  expect_true(is.data.frame(config$cell_targets))
  expect_true("target_percent" %in% names(config$cell_targets))
  expect_true("Gender" %in% names(config$cell_targets))
  expect_true("Age" %in% names(config$cell_targets))
  expect_equal(nrow(config$cell_targets), 6)
})

test_that("cell weight config has correct method in specifications", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_cell_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  specs <- config$weight_specifications
  expect_true(any(tolower(specs$method) == "cell"))
  expect_equal(specs$weight_name[tolower(specs$method) == "cell"], "cell_weight")
})

test_that("config without Cell_Targets sheet has NULL cell_targets", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 100)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_rim_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  expect_null(config$cell_targets)
})

test_that("config parses html_report settings", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 100)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  # Create config with html_report = Y
  config_path <- file.path(tempdir(), "test_html_config.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "General")
  openxlsx::writeData(wb, "General", data.frame(
    Setting = c("project_name", "data_file", "save_diagnostics",
                "html_report", "html_report_file"),
    Value = c("Test HTML", data_path, "N", "Y", "output/report.html"),
    stringsAsFactors = FALSE
  ))
  openxlsx::addWorksheet(wb, "Weight_Specifications")
  openxlsx::writeData(wb, "Weight_Specifications", data.frame(
    weight_name = "design_weight", method = "design",
    description = "Test", apply_trimming = "N",
    trim_method = NA, trim_value = NA,
    stringsAsFactors = FALSE
  ))
  openxlsx::addWorksheet(wb, "Design_Targets")
  openxlsx::writeData(wb, "Design_Targets", data.frame(
    weight_name = rep("design_weight", 3),
    stratum_variable = rep("Age", 3),
    stratum_category = c("18-34", "35-54", "55+"),
    population_size = c(30000, 40000, 30000),
    stringsAsFactors = FALSE
  ))
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  expect_true(config$general$html_report)
})
