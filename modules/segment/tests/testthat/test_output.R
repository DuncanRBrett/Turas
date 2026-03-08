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


# =============================================================================
# TEST: Run_Status Sheet (TRS v1.0)
# =============================================================================

test_that("add_segment_run_status_sheet creates Run_Status sheet in workbook", {
  wb <- openxlsx::createWorkbook()

  add_segment_run_status_sheet(wb, run_status = "PASS")

  expect_true("Run_Status" %in% names(wb))
})

test_that("add_segment_run_status_sheet writes PASS status correctly", {
  wb <- openxlsx::createWorkbook()

  add_segment_run_status_sheet(wb, run_status = "PASS", degraded = FALSE)

  # Save and read back
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Run_Status", colNames = FALSE)

  # Title should be first
  expect_true(any(grepl("SEGMENT RUN STATUS", df[[1]])))
  # Status should contain PASS
  status_row <- which(df[[1]] == "run_status:")
  expect_true(length(status_row) > 0)
  expect_equal(df[[2]][status_row], "PASS")
})

test_that("add_segment_run_status_sheet writes PARTIAL with degraded reasons", {
  wb <- openxlsx::createWorkbook()

  add_segment_run_status_sheet(wb,
    run_status = "PARTIAL",
    degraded = TRUE,
    degraded_reasons = c("Variables dropped", "Low silhouette"),
    affected_outputs = c("cluster_centers", "segment_interpretability")
  )

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Run_Status", colNames = FALSE)

  # Should contain PARTIAL status
  status_row <- which(df[[1]] == "run_status:")
  expect_equal(df[[2]][status_row], "PARTIAL")

  # Should contain degraded = TRUE
  degraded_row <- which(df[[1]] == "degraded:")
  expect_equal(df[[2]][degraded_row], "TRUE")

  # Should contain degraded reasons
  expect_true(any(grepl("Variables dropped", df[[1]])))
  expect_true(any(grepl("Low silhouette", df[[1]])))

  # Should contain affected outputs
  expect_true(any(grepl("cluster_centers", df[[1]])))
})

test_that("add_segment_run_status_sheet includes guard summary warnings", {
  wb <- openxlsx::createWorkbook()

  guard_summary <- list(
    warnings = c("Variable q1 has low variance", "5 outliers removed"),
    stability_flags = c("Low silhouette score")
  )

  add_segment_run_status_sheet(wb,
    run_status = "PARTIAL",
    degraded = TRUE,
    degraded_reasons = "Low quality",
    guard_summary = guard_summary
  )

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Run_Status", colNames = FALSE)

  # Should contain warnings and stability flags
  expect_true(any(grepl("low variance", df[[1]], ignore.case = TRUE)))
  expect_true(any(grepl("outliers removed", df[[1]], ignore.case = TRUE)))
  expect_true(any(grepl("silhouette", df[[1]], ignore.case = TRUE)))
})


# =============================================================================
# TEST: create_segment_output_styles()
# =============================================================================

test_that("create_segment_output_styles returns expected style list", {
  wb <- openxlsx::createWorkbook()
  styles <- create_segment_output_styles(wb)

  expect_true(is.list(styles))
  expect_true("header" %in% names(styles))
  expect_true("title" %in% names(styles))
  expect_true("section" %in% names(styles))
  expect_true("normal" %in% names(styles))
  expect_true("success" %in% names(styles))
  expect_true("warning" %in% names(styles))
  expect_true("error" %in% names(styles))
})


# =============================================================================
# TEST: write_sheets_to_workbook()
# =============================================================================

test_that("write_sheets_to_workbook writes multiple sheets", {
  wb <- openxlsx::createWorkbook()
  styles <- create_segment_output_styles(wb)

  sheets <- list(
    Sheet1 = data.frame(A = 1:5, B = letters[1:5]),
    Sheet2 = data.frame(X = rnorm(3), Y = runif(3))
  )

  write_sheets_to_workbook(wb, sheets, styles)

  expect_true("Sheet1" %in% names(wb))
  expect_true("Sheet2" %in% names(wb))
})

test_that("write_sheets_to_workbook skips empty data frames", {
  wb <- openxlsx::createWorkbook()
  styles <- create_segment_output_styles(wb)

  sheets <- list(
    Populated = data.frame(A = 1:3),
    Empty = data.frame()
  )

  write_sheets_to_workbook(wb, sheets, styles)

  expect_true("Populated" %in% names(wb))
  expect_false("Empty" %in% names(wb))
})


# =============================================================================
# TEST: save_workbook_safe()
# =============================================================================

test_that("save_workbook_safe creates Excel file", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Test")
  openxlsx::writeData(wb, "Test", data.frame(A = 1:3))

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  save_workbook_safe(wb, tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
})
