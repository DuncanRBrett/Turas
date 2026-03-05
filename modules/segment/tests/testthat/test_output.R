# Tests for Excel output functions
# Part of Turas Segment Module v11.0 test suite

# =============================================================================
# TEST SETUP
# =============================================================================

create_output_test_data <- function() {
  set.seed(42)
  n <- 50

  data <- data.frame(
    respondent_id = paste0("R", sprintf("%04d", 1:n)),
    q1 = rnorm(n, 5, 1),
    q2 = rnorm(n, 5, 1),
    q3 = rnorm(n, 5, 1),
    stringsAsFactors = FALSE
  )

  clusters <- sample(1:3, n, replace = TRUE)
  segment_names <- c("Segment 1", "Segment 2", "Segment 3")

  list(
    data = data,
    clusters = clusters,
    segment_names = segment_names,
    id_var = "respondent_id",
    n = n
  )
}


# =============================================================================
# TEST: export_segment_assignments creates an Excel file
# =============================================================================

test_that("export_segment_assignments creates an Excel file", {
  td <- create_output_test_data()

  output_dir <- tempdir()
  output_path <- file.path(output_dir, "test_assignments.xlsx")

  # Clean up after test
  on.exit(unlink(output_path), add = TRUE)

  export_segment_assignments(
    data = td$data,
    clusters = td$clusters,
    segment_names = td$segment_names,
    id_var = td$id_var,
    output_path = output_path
  )

  expect_true(file.exists(output_path))
})


# =============================================================================
# TEST: exported file contains correct columns
# =============================================================================

test_that("exported file contains correct columns (id, segment_id, segment_name)", {
  skip_if_not_installed("readxl")

  td <- create_output_test_data()

  output_dir <- tempdir()
  output_path <- file.path(output_dir, "test_assignments_cols.xlsx")
  on.exit(unlink(output_path), add = TRUE)

  export_segment_assignments(
    data = td$data,
    clusters = td$clusters,
    segment_names = td$segment_names,
    id_var = td$id_var,
    output_path = output_path
  )

  # Read back the file
  result_df <- readxl::read_xlsx(output_path)

  expect_true(td$id_var %in% names(result_df))
  expect_true("segment_id" %in% names(result_df))
  expect_true("segment_name" %in% names(result_df))
})


# =============================================================================
# TEST: correct number of rows in exported file
# =============================================================================

test_that("exported file has correct number of rows", {
  skip_if_not_installed("readxl")

  td <- create_output_test_data()

  output_dir <- tempdir()
  output_path <- file.path(output_dir, "test_assignments_rows.xlsx")
  on.exit(unlink(output_path), add = TRUE)

  export_segment_assignments(
    data = td$data,
    clusters = td$clusters,
    segment_names = td$segment_names,
    id_var = td$id_var,
    output_path = output_path
  )

  result_df <- readxl::read_xlsx(output_path)
  expect_equal(nrow(result_df), td$n)
})


# =============================================================================
# TEST: probabilities add additional columns when provided
# =============================================================================

test_that("probabilities add additional columns when provided", {
  skip_if_not_installed("readxl")

  td <- create_output_test_data()

  # Create fake probability matrix
  k <- 3
  probs <- matrix(runif(td$n * k), nrow = td$n, ncol = k)
  # Normalize rows to sum to 1
  probs <- probs / rowSums(probs)

  output_dir <- tempdir()
  output_path <- file.path(output_dir, "test_assignments_probs.xlsx")
  on.exit(unlink(output_path), add = TRUE)

  export_segment_assignments(
    data = td$data,
    clusters = td$clusters,
    segment_names = td$segment_names,
    id_var = td$id_var,
    output_path = output_path,
    probabilities = probs
  )

  result_df <- readxl::read_xlsx(output_path)

  # Should have probability columns
  prob_cols <- grep("^prob_", names(result_df), value = TRUE)
  expect_equal(length(prob_cols), k)

  # Should have max_probability and uncertainty columns
  expect_true("max_probability" %in% names(result_df))
  expect_true("uncertainty" %in% names(result_df))

  # Total columns: id + segment_id + segment_name + 3 prob + max_prob + uncertainty = 8
  expect_equal(ncol(result_df), 8)
})


# =============================================================================
# TEST: create_output_folder creates directory correctly
# =============================================================================

test_that("create_output_folder creates directory correctly", {
  base_dir <- file.path(tempdir(), "test_output_folder_creation")
  on.exit(unlink(base_dir, recursive = TRUE), add = TRUE)

  # Ensure it does not exist
  if (dir.exists(base_dir)) {
    unlink(base_dir, recursive = TRUE)
  }

  result_path <- create_output_folder(base_dir, create_dated_folder = FALSE)

  expect_true(dir.exists(result_path))
  expect_equal(result_path, base_dir)
})


# =============================================================================
# TEST: create_output_folder with dated folder creates date subfolder
# =============================================================================

test_that("create_output_folder with dated folder creates date subfolder", {
  base_dir <- file.path(tempdir(), "test_output_dated_folder")
  on.exit(unlink(base_dir, recursive = TRUE), add = TRUE)

  # Ensure it does not exist
  if (dir.exists(base_dir)) {
    unlink(base_dir, recursive = TRUE)
  }

  result_path <- create_output_folder(base_dir, create_dated_folder = TRUE)

  expect_true(dir.exists(result_path))

  # Should contain today's date in the path
  date_str <- format(Sys.Date(), "%Y-%m-%d")
  expect_true(grepl(date_str, result_path))

  # The result path should be a subdirectory of base_dir
  expect_true(startsWith(result_path, base_dir))
})


# =============================================================================
# TEST: export_segment_assignments with outlier flags
# =============================================================================

test_that("export_segment_assignments includes outlier flags when provided", {
  skip_if_not_installed("readxl")

  td <- create_output_test_data()

  # Create outlier flags
  outlier_flags <- rep(FALSE, td$n)
  outlier_flags[c(1, 5, 10)] <- TRUE

  output_dir <- tempdir()
  output_path <- file.path(output_dir, "test_assignments_outliers.xlsx")
  on.exit(unlink(output_path), add = TRUE)

  export_segment_assignments(
    data = td$data,
    clusters = td$clusters,
    segment_names = td$segment_names,
    id_var = td$id_var,
    output_path = output_path,
    outlier_flags = outlier_flags
  )

  result_df <- readxl::read_xlsx(output_path)

  expect_true("outlier_flag" %in% names(result_df))
  expect_equal(sum(result_df$outlier_flag), 3)
})


# =============================================================================
# TEST: create_output_folder is idempotent
# =============================================================================

test_that("create_output_folder does not error if directory already exists", {
  base_dir <- file.path(tempdir(), "test_output_idempotent")
  on.exit(unlink(base_dir, recursive = TRUE), add = TRUE)

  # Create once
  result1 <- create_output_folder(base_dir, create_dated_folder = FALSE)
  expect_true(dir.exists(result1))

  # Create again - should not error
  result2 <- create_output_folder(base_dir, create_dated_folder = FALSE)
  expect_true(dir.exists(result2))
  expect_equal(result1, result2)
})
