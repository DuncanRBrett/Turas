# ==============================================================================
# UNIT TESTS - CODE GENERATION (05_generate_codes.R)
# ==============================================================================

# --- generate_base_code ---

test_that("generate_base_code pads correctly with 2 digits", {
  expect_equal(generate_base_code("1", 2), "Q01")
  expect_equal(generate_base_code("9", 2), "Q09")
  expect_equal(generate_base_code("10", 2), "Q10")
  expect_equal(generate_base_code("99", 2), "Q99")
})

test_that("generate_base_code pads correctly with 3 digits", {
  expect_equal(generate_base_code("1", 3), "Q001")
  expect_equal(generate_base_code("42", 3), "Q042")
  expect_equal(generate_base_code("100", 3), "Q100")
})

# --- is_other_field ---

test_that("is_other_field detects common other patterns", {
  expect_true(is_other_field("Other - Write In (Required)"))
  expect_true(is_other_field("Other (please specify)"))
  expect_true(is_other_field("Other"))
  expect_true(is_other_field("other - write in"))
  expect_true(is_other_field("Please specify"))
})

test_that("is_other_field rejects non-other options", {
  expect_false(is_other_field("Male"))
  expect_false(is_other_field("Satisfied"))
  expect_false(is_other_field("Neither agree nor disagree"))
  expect_false(is_other_field(NA))
})

# --- generate_single_mention_codes ---

test_that("generate_single_mention_codes handles simple single column", {
  cols <- list(
    list(row_label = "Option A")
  )
  result <- generate_single_mention_codes("Q01", cols)
  expect_equal(result, "Q01")
})

test_that("generate_single_mention_codes detects othermention from duplicate labels", {
  # "Other - Write In" matches the othermention pattern on first occurrence
  # The duplicate also matches, so both get othermention suffix
  cols <- list(
    list(row_label = "Option A"),
    list(row_label = "Other - Write In"),
    list(row_label = "Other - Write In")  # duplicate = also othertext
  )
  result <- generate_single_mention_codes("Q01", cols)
  expect_equal(result[1], "Q01")
  expect_equal(result[2], "Q01_othermention")  # first "other" detected by pattern
  expect_equal(result[3], "Q01_othermention")  # duplicate also detected
})

# --- generate_multi_mention_codes_sequential ---

test_that("generate_multi_mention_codes_sequential numbers sequentially", {
  cols <- list(
    list(row_label = "Brand A"),
    list(row_label = "Brand B"),
    list(row_label = "Brand C")
  )
  result <- generate_multi_mention_codes_sequential("Q04", cols)
  expect_equal(result, c("Q04_1", "Q04_2", "Q04_3"))
})

test_that("generate_multi_mention_codes_sequential handles othertext field", {
  # "Other - Write In (Required)" matches the othertext pattern on first occurrence
  # The duplicate also matches
  cols <- list(
    list(row_label = "Brand A"),
    list(row_label = "Brand B"),
    list(row_label = "Other - Write In (Required)"),
    list(row_label = "Other - Write In (Required)")  # duplicate = also othertext
  )
  result <- generate_multi_mention_codes_sequential("Q04", cols)
  expect_equal(result[1], "Q04_1")
  expect_equal(result[2], "Q04_2")
  expect_equal(result[3], "Q04_2othertext")  # first "other" detected by pattern
  expect_equal(result[4], "Q04_2othertext")  # duplicate also detected
})

# --- generate_multi_mention_codes ---

test_that("generate_multi_mention_codes creates sequential codes from labels", {
  result <- generate_multi_mention_codes("Q02a", c("ColA", "ColB", "ColC"))
  expect_equal(result, c("Q02a_1", "Q02a_2", "Q02a_3"))
})

# --- text_similarity ---

test_that("text_similarity returns 1 for identical texts", {
  result <- text_similarity("customer satisfaction survey", "customer satisfaction survey")
  expect_equal(result, 1)
})

test_that("text_similarity returns 0 for completely different texts", {
  result <- text_similarity("apple banana cherry", "dog elephant fox")
  expect_equal(result, 0)
})

test_that("text_similarity handles empty strings", {
  result <- text_similarity("", "some text")
  expect_equal(result, 0)
})

test_that("text_similarity ignores stop words", {
  # "the" and "a" are stop words, so "big dog" vs "big dog" after filtering
  result <- text_similarity("the big dog", "a big dog")
  expect_equal(result, 1)
})

# --- validate_parsing ---

test_that("validate_parsing flags Single_Response with no options", {
  questions <- list(
    "1" = list(
      q_num = "1", q_id = "2", q_code = "Q01",
      question_text = "Gender", variable_type = "Single_Response",
      is_grid = FALSE, n_columns = 1, options = list(),
      columns = list()
    )
  )
  translation_data <- list(questions = list(), options = list())
  word_hints <- list()

  result <- validate_parsing(questions, translation_data, word_hints)
  issues <- sapply(result$flags, function(f) f$issue)
  expect_true("NO_OPTIONS_FOUND" %in% issues)
})

test_that("validate_parsing flags grid options generic fallback", {
  questions <- list(
    "5" = list(
      q_num = "5", q_id = "7", q_code = "Q05",
      is_grid = TRUE, grid_type = "radio_grid",
      grid_options_source = "generic_fallback",
      sub_questions = list()
    )
  )
  translation_data <- list(questions = list(), options = list())
  word_hints <- list()

  result <- validate_parsing(questions, translation_data, word_hints)
  issues <- sapply(result$flags, function(f) f$issue)
  expect_true("GRID_OPTIONS_GENERIC_FALLBACK" %in% issues)
})

test_that("validate_parsing flags unexpected header format", {
  questions <- list(
    "3" = list(
      q_num = "3", q_id = "4", q_code = "Q03",
      is_grid = FALSE, n_columns = 1,
      variable_type = "Single_Response",
      options = list(list(code = "1", text = "Yes", key = "q-4-o-1")),
      columns = list(
        list(col_index = 5, format_flag = "Unexpected 6-part header format")
      )
    )
  )
  translation_data <- list(questions = list("4" = "Question 3 text"), options = list())
  word_hints <- list()

  result <- validate_parsing(questions, translation_data, word_hints)
  issues <- sapply(result$flags, function(f) f$issue)
  expect_true("UNEXPECTED_HEADER_FORMAT" %in% issues)
})
