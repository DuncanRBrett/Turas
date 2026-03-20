# ==============================================================================
# UNIT TESTS - DATA EXPORT MAP PARSING (01_parse_data_map.R)
# ==============================================================================

test_that("extract_leading_number extracts digits before colon", {
  expect_equal(extract_leading_number("1: Question text"), "1")
  expect_equal(extract_leading_number("23: Another question"), "23")
  expect_equal(extract_leading_number("100: Big number"), "100")
})

test_that("extract_leading_number returns NA for invalid input", {
  expect_true(is.na(extract_leading_number(NA)))
  expect_true(is.na(extract_leading_number("")))
  expect_true(is.na(extract_leading_number("No colon here")))
  expect_true(is.na(extract_leading_number("abc: text")))
})

test_that("parse_column_header handles ResponseID", {
  result <- parse_column_header("Response ID", "Response ID", 1)
  expect_equal(result$q_num, "ResponseID")
  expect_equal(result$structure, "system")
  expect_true(result$is_system)
})

test_that("parse_column_header handles simple 2-part headers", {
  result <- parse_column_header("1: What is your age?", "2: What is your age?", 2)
  expect_equal(result$q_num, "1")
  expect_equal(result$q_id, "2")
  expect_equal(result$structure, "simple")
  expect_equal(result$question_text, "What is your age?")
  expect_true(is.na(result$row_label))
  expect_true(is.na(result$col_label))
})

test_that("parse_column_header handles 3-part grid/multi headers", {
  result <- parse_column_header("5: Option A:Which brands?", "7: Option A:Which brands?", 3)
  expect_equal(result$q_num, "5")
  expect_equal(result$structure, "grid_or_multi")
  expect_equal(result$row_label, "Option A")
  expect_equal(result$question_text, "Which brands?")
})

test_that("parse_column_header handles 4-part checkbox grid headers", {
  result <- parse_column_header("10: ColA:RowB:Grid question", "12: ColA:RowB:Grid question", 4)
  expect_equal(result$q_num, "10")
  expect_equal(result$structure, "checkbox_grid")
  expect_equal(result$col_label, "ColA")
  expect_equal(result$row_label, "RowB")
  expect_equal(result$question_text, "Grid question")
})

test_that("parse_column_header flags unexpected formats with format_flag", {
  result <- parse_column_header("1: a:b:c:d:extra", "2: a:b:c:d:extra", 5)
  expect_equal(result$structure, "simple")
  expect_false(is.null(result$format_flag))
  expect_true(grepl("Unexpected", result$format_flag))
})

test_that("group_columns_by_question groups by q_num", {
  cols <- list(
    list(q_num = "1", q_id = "2", question_text = "Q1", col_index = 1,
         structure = "simple", row_label = NA, col_label = NA),
    list(q_num = "1", q_id = "2", question_text = "Q1", col_index = 2,
         structure = "grid_or_multi", row_label = "A", col_label = NA),
    list(q_num = "2", q_id = "5", question_text = "Q2", col_index = 3,
         structure = "simple", row_label = NA, col_label = NA)
  )
  result <- group_columns_by_question(cols)
  expect_equal(length(result), 2)
  expect_equal(length(result[["1"]]$columns), 2)
  expect_equal(length(result[["2"]]$columns), 1)
})

test_that("group_columns_by_question skips columns with NA q_num and records them", {
  cols <- list(
    list(q_num = "1", q_id = "2", question_text = "Q1", col_index = 1,
         structure = "simple", row_label = NA, col_label = NA),
    list(q_num = NA, q_id = NA, question_text = NA, col_index = 2,
         structure = "simple", row_label = NA, col_label = NA)
  )
  result <- group_columns_by_question(cols)
  expect_equal(length(result), 1)
  expect_equal(attr(result, "skipped_columns"), 2L)
})

test_that("detect_grid_type returns 'single' for single-column questions", {
  q <- list(columns = list(list(row_label = NA, col_label = NA)))
  expect_equal(detect_grid_type(q), "single")
})

test_that("detect_grid_type_with_hints uses () brackets for radio grid", {
  cols <- list(
    list(row_label = "Item A", col_label = NA, structure = "grid_or_multi"),
    list(row_label = "Item B", col_label = NA, structure = "grid_or_multi")
  )
  q <- list(columns = cols)
  hints <- list(brackets = "()")
  expect_equal(detect_grid_type_with_hints(q, hints), "radio_grid")
})

test_that("detect_grid_type_with_hints uses [] brackets for multi_column", {
  cols <- list(
    list(row_label = "Option 1", col_label = NA, structure = "grid_or_multi"),
    list(row_label = "Option 2", col_label = NA, structure = "grid_or_multi")
  )
  q <- list(columns = cols)
  hints <- list(brackets = "[]")
  expect_equal(detect_grid_type_with_hints(q, hints), "multi_column")
})

test_that("detect_grid_type_with_hints detects checkbox_grid with [] and col_labels", {
  cols <- list(
    list(row_label = "Row1", col_label = "ColA", structure = "checkbox_grid"),
    list(row_label = "Row1", col_label = "ColB", structure = "checkbox_grid"),
    list(row_label = "Row2", col_label = "ColA", structure = "checkbox_grid"),
    list(row_label = "Row2", col_label = "ColB", structure = "checkbox_grid")
  )
  q <- list(columns = cols)
  hints <- list(brackets = "[]")
  expect_equal(detect_grid_type_with_hints(q, hints), "checkbox_grid")
})

test_that("detect_grid_type_with_hints detects star_rating_grid from numeric labels", {
  cols <- list(
    list(row_label = "1", col_label = NA, structure = "grid_or_multi"),
    list(row_label = "2", col_label = NA, structure = "grid_or_multi"),
    list(row_label = "3", col_label = NA, structure = "grid_or_multi")
  )
  q <- list(columns = cols)
  hints <- list(brackets = "()")
  expect_equal(detect_grid_type_with_hints(q, hints), "star_rating_grid")
})
