# ==============================================================================
# TESTS: ERROR HANDLING & EDGE CASES
# ==============================================================================

# --- Data Export Map Error Handling ---

test_that("parse_data_export_map refuses on non-existent file", {
  expect_error(
    parse_data_export_map("/nonexistent/file.xlsx"),
    "IO_FILE_NOT_FOUND"
  )
})

test_that("parse_column_header handles unexpected header formats gracefully", {
  # 5-part header (unexpected)
  result <- parse_column_header("1:A:B:C:D", "1:E", 1)
  expect_equal(result$structure, "simple")
  expect_true(!is.null(result$format_flag))
})

test_that("parse_column_header handles ResponseID", {
  result <- parse_column_header("Response ID", "ResponseID", 1)
  expect_equal(result$q_num, "ResponseID")
  expect_true(result$is_system)
})

test_that("extract_leading_number handles various inputs", {
  expect_equal(extract_leading_number("1: Question text"), "1")
  expect_equal(extract_leading_number("42: Question text"), "42")
  expect_true(is.na(extract_leading_number("")))
  expect_true(is.na(extract_leading_number(NA)))
  expect_true(is.na(extract_leading_number("No number here")))
})

test_that("group_columns_by_question handles empty input", {
  result <- group_columns_by_question(list())
  expect_equal(length(result), 0)
})

test_that("group_columns_by_question groups columns correctly", {
  cols <- list(
    list(q_num = "1", q_id = "10", col_index = 1, question_text = "Q1",
         structure = "simple", row_label = NA, col_label = NA),
    list(q_num = "1", q_id = "10", col_index = 2, question_text = "Q1",
         structure = "grid_or_multi", row_label = "Option A", col_label = NA),
    list(q_num = "2", q_id = "20", col_index = 3, question_text = "Q2",
         structure = "simple", row_label = NA, col_label = NA)
  )
  result <- group_columns_by_question(cols)
  expect_equal(length(result), 2)
  expect_equal(length(result[["1"]]$columns), 2)
  expect_equal(length(result[["2"]]$columns), 1)
})

# --- Word Doc Error Handling ---

test_that("parse_word_questionnaire refuses on non-existent file", {
  expect_error(
    parse_word_questionnaire("/nonexistent/file.docx"),
    "IO_FILE_NOT_FOUND"
  )
})

test_that("get_hint_for_question returns empty hint for missing Q", {
  hints <- list("1" = list(question_text = "Test", brackets = "()",
                            type = NA, has_rank_keyword = FALSE,
                            has_routing_hint = FALSE))
  result <- get_hint_for_question("99", hints)
  expect_true(is.na(result$question_text))
  expect_true(is.na(result$brackets))
  expect_false(result$has_rank_keyword)
  expect_false(result$has_routing_hint)
})

test_that("get_hint_for_question returns correct hint for existing Q", {
  hints <- list("5" = list(question_text = "Test Q", brackets = "[]",
                            type = "slider", has_rank_keyword = TRUE,
                            has_routing_hint = FALSE))
  result <- get_hint_for_question("5", hints)
  expect_equal(result$question_text, "Test Q")
  expect_equal(result$brackets, "[]")
  expect_equal(result$type, "slider")
  expect_true(result$has_rank_keyword)
})

# --- Grid Type Detection ---

test_that("detect_grid_type returns 'single' for single-column question", {
  q <- list(columns = list(
    list(structure = "simple", row_label = NA, col_label = NA)
  ))
  expect_equal(detect_grid_type(q), "single")
})

test_that("detect_grid_type_with_hints uses brackets for classification", {
  cols <- list(
    list(structure = "checkbox_grid", row_label = "Row1", col_label = "Col1"),
    list(structure = "checkbox_grid", row_label = "Row1", col_label = "Col2"),
    list(structure = "checkbox_grid", row_label = "Row2", col_label = "Col1"),
    list(structure = "checkbox_grid", row_label = "Row2", col_label = "Col2")
  )
  q <- list(columns = cols)

  # With () brackets -> radio_grid
  result_radio <- detect_grid_type_with_hints(q, list(brackets = "()"))
  expect_equal(result_radio, "radio_grid")

  # With [] brackets and col_labels -> checkbox_grid
  result_checkbox <- detect_grid_type_with_hints(q, list(brackets = "[]"))
  expect_equal(result_checkbox, "checkbox_grid")
})
