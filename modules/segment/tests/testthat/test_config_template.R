# ==============================================================================
# SEGMENT MODULE TESTS - CONFIG TEMPLATE GENERATION
# ==============================================================================

test_that("generate_segment_config_template creates valid Excel file", {
  skip_if_not_installed("openxlsx")

  output_path <- file.path(tempdir(), "test_config_template.xlsx")
  on.exit(unlink(output_path), add = TRUE)

  result <- generate_segment_config_template(output_path)

  expect_true(file.exists(output_path))
  expect_true(file.size(output_path) > 1000)

  # Read back and verify structure
  df <- openxlsx::read.xlsx(output_path, sheet = "Config")
  expect_true("Setting" %in% names(df))
  expect_true("Value" %in% names(df))
  expect_true("Description" %in% names(df))

  # Verify key parameters are present
  settings <- df$Setting
  expect_true("data_file" %in% settings)
  expect_true("id_variable" %in% settings)
  expect_true("clustering_vars" %in% settings)
  expect_true("method" %in% settings)
  expect_true("k_fixed" %in% settings)
  expect_true("html_report" %in% settings)
  expect_true("brand_colour" %in% settings)
})

test_that("generate_segment_config_template includes all parameter categories", {
  skip_if_not_installed("openxlsx")

  output_path <- file.path(tempdir(), "test_config_cats.xlsx")
  on.exit(unlink(output_path), add = TRUE)

  generate_segment_config_template(output_path)
  df <- openxlsx::read.xlsx(output_path, sheet = "Config")
  settings <- df$Setting

  # Data source
  expect_true("data_file" %in% settings)
  expect_true("data_sheet" %in% settings)

  # Clustering method
  expect_true("method" %in% settings)
  expect_true("linkage_method" %in% settings)

  # K parameters
  expect_true("k_min" %in% settings)
  expect_true("k_max" %in% settings)
  expect_true("nstart" %in% settings)

  # Data handling
  expect_true("missing_data" %in% settings)
  expect_true("standardize" %in% settings)

  # Outliers
  expect_true("outlier_detection" %in% settings)
  expect_true("outlier_method" %in% settings)

  # Output
  expect_true("output_folder" %in% settings)
  expect_true("save_model" %in% settings)

  # HTML report
  expect_true("html_report" %in% settings)
  expect_true("brand_colour" %in% settings)
  expect_true("accent_colour" %in% settings)

  # Enhanced features
  expect_true("generate_rules" %in% settings)
  expect_true("generate_action_cards" %in% settings)

  # Metadata
  expect_true("project_name" %in% settings)
  expect_true("description" %in% settings)
})

test_that("seg_write_xlsx creates branded Excel file", {
  skip_if_not_installed("openxlsx")

  output_path <- file.path(tempdir(), "test_branded_output.xlsx")
  on.exit(unlink(output_path), add = TRUE)

  sheets <- list(
    "Summary" = data.frame(Metric = c("A", "B"), Value = c(1, 2)),
    "Details" = data.frame(X = 1:5, Y = letters[1:5])
  )

  seg_write_xlsx(sheets, output_path)

  expect_true(file.exists(output_path))
  expect_true(file.size(output_path) > 500)

  # Verify sheets
  sheet_names <- openxlsx::getSheetNames(output_path)
  expect_true("Summary" %in% sheet_names)
  expect_true("Details" %in% sheet_names)

  # Read back data
  summary_df <- openxlsx::read.xlsx(output_path, sheet = "Summary")
  expect_equal(nrow(summary_df), 2)
  expect_equal(summary_df$Metric, c("A", "B"))
})
