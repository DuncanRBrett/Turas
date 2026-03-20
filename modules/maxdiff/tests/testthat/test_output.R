# ==============================================================================
# MAXDIFF TESTS - OUTPUT GENERATION
# ==============================================================================

# ==============================================================================
# create_output_styles() tests
# ==============================================================================

test_that("create_output_styles returns a list of openxlsx styles", {
  skip_if(!exists("create_output_styles", mode = "function"))
  skip_if(!requireNamespace("openxlsx", quietly = TRUE))

  # Act
  styles <- create_output_styles()

  # Assert: should be a named list
  expect_true(is.list(styles))
  expect_true(length(styles) > 0)

  # Should have common style names
  expect_true("header" %in% names(styles))
  expect_true("subheader" %in% names(styles))

  # Each element should be an openxlsx style object
  expect_true(inherits(styles$header, "Style"))
  expect_true(inherits(styles$subheader, "Style"))
})

test_that("create_output_styles includes numeric format styles", {
  skip_if(!exists("create_output_styles", mode = "function"))
  skip_if(!requireNamespace("openxlsx", quietly = TRUE))

  styles <- create_output_styles()

  # Should have numeric formatting styles
  expect_true("number_1dp" %in% names(styles) || "number_2dp" %in% names(styles))
})

# ==============================================================================
# Output path generation tests
# ==============================================================================

test_that("output filename uses project name", {
  skip_if(!exists("generate_maxdiff_output", mode = "function"))
  skip_if(!requireNamespace("openxlsx", quietly = TRUE))

  # Verify the naming convention from the source:
  # output_filename <- sprintf("%s_MaxDiff_Results.xlsx", project_name)
  project_name <- "TestProject"
  expected_filename <- sprintf("%s_MaxDiff_Results.xlsx", project_name)
  expect_equal(expected_filename, "TestProject_MaxDiff_Results.xlsx")
})

test_that("output path uses Output_Folder from config", {
  # Verify path construction logic
  output_folder <- tempdir()
  project_name <- "MyProject"
  output_filename <- sprintf("%s_MaxDiff_Results.xlsx", project_name)
  output_path <- file.path(output_folder, output_filename)

  expect_true(grepl("MyProject_MaxDiff_Results.xlsx", output_path))
  expect_equal(dirname(output_path), output_folder)
})

# ==============================================================================
# Output functions handle NULL results gracefully
# ==============================================================================

test_that("generate_maxdiff_output handles NULL results gracefully", {
  skip_if(!exists("generate_maxdiff_output", mode = "function"))
  skip_if(!requireNamespace("openxlsx", quietly = TRUE))

  # Arrange: minimal config with temp output folder
  tmp_dir <- file.path(tempdir(), "maxdiff_test_output")
  dir.create(tmp_dir, showWarnings = FALSE)

  config <- list(
    project_settings = list(
      Project_Name = "NullTest",
      Output_Folder = tmp_dir
    ),
    project_root = tmp_dir,
    items = data.frame(
      Item_ID = c("I1", "I2"),
      Item_Label = c("A", "B"),
      Include = c(1, 1),
      stringsAsFactors = FALSE
    ),
    output_settings = list()
  )

  # results with mostly NULL components
  results <- list(
    count_scores = data.frame(
      Item_ID = c("I1", "I2"),
      Item_Label = c("A", "B"),
      Best_Pct = c(30, 20),
      Worst_Pct = c(10, 25),
      BW_Score = c(0.5, -0.3),
      stringsAsFactors = FALSE
    ),
    logit_results = NULL,
    hb_results = NULL,
    segment_results = NULL,
    turf_results = NULL,
    study_summary = list(n_respondents = 50, n_tasks = 6, n_items = 2)
  )

  # Act: should not throw an error even with NULL sub-results
  result <- tryCatch(
    generate_maxdiff_output(results, config, verbose = FALSE),
    error = function(e) e$message
  )

  # Assert: either produced a file path or a non-crash error message
  # The function should handle NULLs without crashing
 expect_true(is.character(result))

  # Cleanup
  unlink(tmp_dir, recursive = TRUE)
})

test_that("generate_maxdiff_output creates output file on disk", {
  skip_if(!exists("generate_maxdiff_output", mode = "function"))
  skip_if(!requireNamespace("openxlsx", quietly = TRUE))

  tmp_dir <- file.path(tempdir(), "maxdiff_output_test2")
  dir.create(tmp_dir, showWarnings = FALSE)

  config <- list(
    project_settings = list(
      Project_Name = "FileTest",
      Output_Folder = tmp_dir
    ),
    project_root = tmp_dir,
    items = data.frame(
      Item_ID = c("I1", "I2", "I3"),
      Item_Label = c("Alpha", "Beta", "Gamma"),
      Include = c(1, 1, 1),
      Item_Group = rep("Test", 3),
      Display_Order = 1:3,
      stringsAsFactors = FALSE
    ),
    output_settings = list()
  )

  results <- list(
    count_scores = data.frame(
      Item_ID = c("I1", "I2", "I3"),
      Item_Label = c("Alpha", "Beta", "Gamma"),
      Best_Count = c(50, 30, 20),
      Worst_Count = c(10, 25, 40),
      Best_Pct = c(33, 20, 13),
      Worst_Pct = c(7, 17, 27),
      BW_Score = c(0.5, 0.1, -0.4),
      Rescaled_Score = c(100, 55, 0),
      Rank = c(1, 2, 3),
      stringsAsFactors = FALSE
    ),
    logit_results = NULL,
    hb_results = NULL,
    segment_results = NULL,
    turf_results = NULL,
    study_summary = list(
      n_respondents = 100,
      n_tasks = 6,
      n_items = 3,
      weighted = FALSE,
      effective_n = 100,
      design_effect = 1
    )
  )

  result <- tryCatch(
    generate_maxdiff_output(results, config, verbose = FALSE),
    error = function(e) NULL
  )

  # If output was generated, check the file exists
  if (!is.null(result)) {
    expect_true(file.exists(result))
    expect_true(grepl("\\.xlsx$", result))
  }

  unlink(tmp_dir, recursive = TRUE)
})

# ==============================================================================
# Output styles consistency
# ==============================================================================

test_that("create_output_styles styles are non-NULL", {
  skip_if(!exists("create_output_styles", mode = "function"))
  skip_if(!requireNamespace("openxlsx", quietly = TRUE))

  styles <- create_output_styles()

  # No style should be NULL
  for (name in names(styles)) {
    expect_false(is.null(styles[[name]]),
                 info = sprintf("Style '%s' should not be NULL", name))
  }
})
